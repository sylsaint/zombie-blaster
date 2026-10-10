#!/usr/bin/env bash
# Arm64 release-template controls for the v0.1.1 launch crash.
# Three packages, so they can sit next to com.zombieblaster.game:
#   nosquad   — menu does not build CrowdView, so the walker VAT stays unloaded
#   immersive — immersive on, edge-to-edge off, menu squad still built
#   nosave    — skip user://save.json and start from a fresh profile
# The committed export preset is restored on exit. Phone package id stays
# com.zombieblaster.game. These APKs are CI artifacts, not a GitHub Release.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=common.sh
source "$ROOT/tools/release/common.sh"

if [[ -z "${JAVA_HOME:-}" ]]; then
  echo "JAVA_HOME is required (JDK 17). The Android exporter looks up bin/java and bin/keytool there." >&2
  exit 1
fi
if [[ -z "${ANDROID_HOME:-}" ]]; then
  echo "ANDROID_HOME is required. It must contain platform-tools/ and build-tools/." >&2
  exit 1
fi
if [[ ! -x "$JAVA_HOME/bin/keytool" ]]; then
  echo "keytool not found at $JAVA_HOME/bin/keytool" >&2
  exit 1
fi

tag="$(resolve_artifact_tag)"
out_dir="$ROOT/build/launch-variants"
sign_dir="$ROOT/build/signing"
mkdir -p "$out_dir" "$sign_dir"
preset="$ROOT/export_presets.cfg"
backup="$ROOT/build/export_presets.cfg.launch.bak"
cp "$preset" "$backup"
restore_preset() {
  if [[ -f "$backup" ]]; then
    cp "$backup" "$preset"
  fi
}
trap restore_preset EXIT

debug_ks="$sign_dir/debug.keystore"
debug_alias="androiddebugkey"
debug_pass="android"
if [[ ! -f "$debug_ks" ]]; then
  note "Generating a debug keystore"
  keytool -genkeypair -keystore "$debug_ks" \
    -storepass "$debug_pass" -keypass "$debug_pass" \
    -alias "$debug_alias" \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=Android Debug, OU=Zombie Blaster CI, O=Zombie Blaster, C=US" >/dev/null
fi
release_ks="$debug_ks"
release_alias="$debug_alias"
release_pass="$debug_pass"
note "Launch-crash controls are signed with the generated debug keystore. They are not the Play package."
release_ks="$(cd "$(dirname "$release_ks")" && pwd)/$(basename "$release_ks")"

ensure_godot
note "Importing project"
"$GODOT_BIN" --headless --path "$ROOT" --import

aapt="$(find "$ANDROID_HOME/build-tools" -type f -name aapt | sort | tail -n 1)"
apksigner="$(find "$ANDROID_HOME/build-tools" -type f -name apksigner | sort | tail -n 1)"
zipalign="$(find "$ANDROID_HOME/build-tools" -type f -name zipalign | sort | tail -n 1)"
if [[ -z "$aapt" || -z "$apksigner" || -z "$zipalign" ]]; then
  echo "aapt, apksigner, or zipalign is missing under $ANDROID_HOME/build-tools" >&2
  exit 1
fi

strip_baseline_profile() {
  local apk="$1"
  local work aligned
  work="$(mktemp -d)"
  aligned="$work/aligned.apk"
  note "Removing baseline profile from $(basename "$apk")"
  python3 "$ROOT/tools/release/strip_baseline_profile.py" "$apk" "$work/stripped.apk"
  local align_help
  align_help="$("$zipalign" -h 2>&1 || true)"
  if grep -q -- '-P ' <<<"$align_help"; then
    "$zipalign" -P 16 -f 4 "$work/stripped.apk" "$aligned"
  else
    "$zipalign" -f -p 4 "$work/stripped.apk" "$aligned"
  fi
  APKSIGNER_PASS="$release_pass" "$apksigner" sign \
    --ks "$release_ks" \
    --ks-key-alias "$release_alias" \
    --ks-pass env:APKSIGNER_PASS \
    --key-pass env:APKSIGNER_PASS \
    --out "$work/signed.apk" \
    "$aligned"
  mv "$work/signed.apk" "$apk"
  rm -rf "$work"
  if zipinfo -1 "$apk" | grep -E '(^|/)(baseline|startup)\.profm?$'; then
    echo "$apk still contains a baseline profile after stripping" >&2
    exit 1
  fi
}

export_variant() {
  local id="$1"
  local apk="$out_dir/zombie-blaster-${tag}-android-${id}.apk"
  cp "$backup" "$preset"
  python3 - "$preset" "$id" << 'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
variant = sys.argv[2]
text = path.read_text()
start = text.find("[preset.0.options]")
if start < 0:
    raise SystemExit("export_presets.cfg is missing [preset.0.options]")
end = text.find("\n[preset.", start + 1)
if end < 0:
    raise SystemExit("export_presets.cfg has no section after [preset.0.options]")
section = text[start:end]
specs = {
    "nosquad": {
        "package": "com.zombieblaster.game.nosquad",
        "label": "高速打僵尸 nosquad",
        "extra": '"-- --menu-no-squad"',
        "immersive": "false",
        "edge": "true",
    },
    "immersive": {
        "package": "com.zombieblaster.game.immersive",
        "label": "高速打僵尸 immersive",
        "extra": '""',
        "immersive": "true",
        "edge": "false",
    },
    "nosave": {
        "package": "com.zombieblaster.game.nosave",
        "label": "高速打僵尸 nosave",
        "extra": '"-- --skip-save"',
        "immersive": "false",
        "edge": "true",
    },
}
if variant not in specs:
    raise SystemExit(f"unknown variant {variant}")
spec = specs[variant]

def set_line(body: str, key: str, value: str) -> str:
    pattern = rf"(?m)^{re.escape(key)}=.*$"
    updated, count = re.subn(pattern, f"{key}={value}", body, count=1)
    if count != 1:
        raise SystemExit(f"Android preset is missing {key}")
    return updated

section = set_line(section, "package/unique_name", f'"{spec["package"]}"')
section = set_line(section, "package/name", f'"{spec["label"]}"')
section = set_line(section, "command_line/extra_args", spec["extra"])
section = set_line(section, "screen/immersive_mode", spec["immersive"])
section = set_line(section, "screen/edge_to_edge", spec["edge"])
section = set_line(section, "version/name", '"0.1.1"')
section = set_line(section, "version/code", "101")
section = set_line(section, "architectures/arm64-v8a", "true")
section = set_line(section, "architectures/armeabi-v7a", "false")
section = set_line(section, "architectures/x86", "false")
section = set_line(section, "architectures/x86_64", "false")
path.write_text(text[:start] + section + text[end:])
PY
  export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$release_ks"
  export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$release_alias"
  export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$release_pass"
  unset GODOT_ANDROID_KEYSTORE_DEBUG_PATH GODOT_ANDROID_KEYSTORE_DEBUG_USER GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD || true
  note "Exporting $id -> $(basename "$apk")"
  "$GODOT_BIN" --headless --audio-driver Dummy --path "$ROOT" \
    --export-release "Android" "$apk"
  unset GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
  if [[ ! -s "$apk" ]]; then
    echo "Export did not produce $apk" >&2
    exit 1
  fi
  strip_baseline_profile "$apk"
  python3 - "$apk" "$id" << 'PY'
import struct
import sys
import zipfile

apk, variant = sys.argv[1], sys.argv[2]
expect = {
    "nosquad": {
        "need": ["--menu-no-squad", "--edge_to_edge"],
        "forbid": ["--fullscreen", "--skip-save"],
    },
    "immersive": {
        "need": ["--fullscreen"],
        "forbid": ["--edge_to_edge", "--menu-no-squad", "--skip-save"],
    },
    "nosave": {
        "need": ["--skip-save", "--edge_to_edge"],
        "forbid": ["--fullscreen", "--menu-no-squad"],
    },
}[variant]
with zipfile.ZipFile(apk) as zf:
    data = zf.read("assets/_cl_")
    libs = [name for name in zf.namelist() if name.startswith("lib/") and name.endswith(".so")]
count = struct.unpack_from("<I", data, 0)[0]
pos = 4
args = []
for _ in range(count):
    length = struct.unpack_from("<I", data, pos)[0]
    pos += 4
    args.append(data[pos:pos + length].decode("utf-8"))
    pos += length
print(variant, "_cl_", " ".join(args))
print(variant, "libs", " ".join(libs))
for arg in expect["need"]:
    if arg not in args:
        raise SystemExit(f"{variant} is missing {arg}")
for arg in expect["forbid"]:
    if arg in args:
        raise SystemExit(f"{variant} should not bake {arg}")
if libs != ["lib/arm64-v8a/libc++_shared.so", "lib/arm64-v8a/libgodot_android.so"] and sorted(libs) != [
    "lib/arm64-v8a/libc++_shared.so",
    "lib/arm64-v8a/libgodot_android.so",
]:
    raise SystemExit(f"{variant} native libs are not arm64-only: {libs}")
PY
  local badging package
  badging="$("$aapt" dump badging "$apk")"
  package="com.zombieblaster.game.${id}"
  case "$badging" in
    *"package: name='${package}'"*) ;;
    *) echo "$apk package name is not ${package}" >&2; exit 1 ;;
  esac
  case "$badging" in
    *"native-code: 'arm64-v8a'"*) ;;
    *) echo "$apk is not arm64-v8a" >&2; exit 1 ;;
  esac
  case "$badging" in
    *"versionCode='101'"*) ;;
    *) echo "$apk versionCode is not 101" >&2; exit 1 ;;
  esac
  "$apksigner" verify --print-certs "$apk" >/dev/null
  assert_project_data_packed "$apk" game
  note "$(basename "$apk"): $(wc -c < "$apk" | tr -d ' ') bytes, package ${package}"
}

export_variant nosquad
export_variant immersive
export_variant nosave
note "Launch-crash control APKs are in $out_dir"
