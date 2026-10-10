#!/usr/bin/env bash
# Export arm64-v8a release and debug APKs, plus an arm64 profile APK.
# Also export a CI-only x86_64 release APK for the emulator job. That file is
# not the phone package: build/release stays arm64-only.
# Release and profile use the release export template. Without the three
# release keystore secrets, those APKs are signed with a generated debug
# keystore so they can be installed. When all three secrets are set, they
# use that keystore instead. The debug APK always uses the debug keystore.
# The profile APK is a separate package and is not a Play release.
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
if [[ ! -d "$ANDROID_HOME/platform-tools" || ! -d "$ANDROID_HOME/build-tools" ]]; then
  echo "ANDROID_HOME ($ANDROID_HOME) is missing platform-tools or build-tools." >&2
  exit 1
fi

tag="$(resolve_artifact_tag)"
out_dir="$ROOT/build/release"
sign_dir="$ROOT/build/signing"
mkdir -p "$out_dir" "$sign_dir"
preset="$ROOT/export_presets.cfg"
backup="$ROOT/build/export_presets.cfg.bak"
cp "$preset" "$backup"
restore_preset() {
  if [[ -f "$backup" ]]; then
    cp "$backup" "$preset"
  fi
}
trap restore_preset EXIT
apply_tag_version

release_apk="$out_dir/zombie-blaster-${tag}-android-release.apk"
debug_apk="$out_dir/zombie-blaster-${tag}-android-debug.apk"

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

has_ks="${ANDROID_KEYSTORE_BASE64:-}"
has_pass="${ANDROID_KEYSTORE_PASSWORD:-}"
has_alias="${ANDROID_KEY_ALIAS:-}"
if [[ -n "$has_ks" || -n "$has_pass" || -n "$has_alias" ]]; then
  if [[ -z "$has_ks" || -z "$has_pass" || -z "$has_alias" ]]; then
    echo "Android release signing is partial. Set all of ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, and ANDROID_KEY_ALIAS, or none of them." >&2
    exit 1
  fi
  release_ks="$sign_dir/release.keystore"
  printf '%s' "$ANDROID_KEYSTORE_BASE64" | decode_base64_to "$release_ks"
  release_alias="$ANDROID_KEY_ALIAS"
  release_pass="$ANDROID_KEYSTORE_PASSWORD"
  if ! keytool -list -keystore "$release_ks" -storepass "$release_pass" -alias "$release_alias" >/dev/null; then
    echo "Release keystore could not be read with ANDROID_KEY_ALIAS. Godot also requires the key password to match ANDROID_KEYSTORE_PASSWORD." >&2
    exit 1
  fi
  note "Release APK will be signed with the keystore from ANDROID_KEYSTORE_BASE64."
else
  release_ks="$debug_ks"
  release_alias="$debug_alias"
  release_pass="$debug_pass"
  note "ANDROID_KEYSTORE_BASE64 / ANDROID_KEYSTORE_PASSWORD / ANDROID_KEY_ALIAS are unset. Signing the release APK with the generated debug keystore."
fi

# Absolute paths. Godot does not resolve a relative keystore from the project.
release_ks="$(cd "$(dirname "$release_ks")" && pwd)/$(basename "$release_ks")"
debug_ks="$(cd "$(dirname "$debug_ks")" && pwd)/$(basename "$debug_ks")"

ensure_godot

note "Importing project"
"$GODOT_BIN" --headless --path "$ROOT" --import

export_one() {
  local mode="$1" preset_name="$2" apk="$3" ks="$4" alias="$5" pass="$6"
  local path_var user_var pass_var
  if [[ "$mode" == "release" ]]; then
    path_var="GODOT_ANDROID_KEYSTORE_RELEASE_PATH"
    user_var="GODOT_ANDROID_KEYSTORE_RELEASE_USER"
    pass_var="GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"
    unset GODOT_ANDROID_KEYSTORE_DEBUG_PATH GODOT_ANDROID_KEYSTORE_DEBUG_USER GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD || true
  else
    path_var="GODOT_ANDROID_KEYSTORE_DEBUG_PATH"
    user_var="GODOT_ANDROID_KEYSTORE_DEBUG_USER"
    pass_var="GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD"
    unset GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD || true
  fi
  export "$path_var=$ks" "$user_var=$alias" "$pass_var=$pass"
  note "Exporting $mode APK ($preset_name) -> $(basename "$apk")"
  if [[ "$mode" == "release" ]]; then
    "$GODOT_BIN" --headless --audio-driver Dummy --path "$ROOT" \
      --export-release "$preset_name" "$apk"
  else
    "$GODOT_BIN" --headless --audio-driver Dummy --path "$ROOT" \
      --export-debug "$preset_name" "$apk"
  fi
  unset "$path_var" "$user_var" "$pass_var"
  if [[ ! -s "$apk" ]]; then
    echo "Export did not produce $apk" >&2
    exit 1
  fi
}

aapt="$(find "$ANDROID_HOME/build-tools" -type f -name aapt | sort | tail -n 1)"
apksigner="$(find "$ANDROID_HOME/build-tools" -type f -name apksigner | sort | tail -n 1)"
zipalign="$(find "$ANDROID_HOME/build-tools" -type f -name zipalign | sort | tail -n 1)"
if [[ -z "$aapt" || -z "$apksigner" || -z "$zipalign" ]]; then
  echo "aapt, apksigner, or zipalign is missing under $ANDROID_HOME/build-tools" >&2
  exit 1
fi

# The release template's baseline profile is the only extra payload versus the
# debug APK besides libgodot_android.so. ART applies it on non-debuggable
# installs. Strip it from every release-template APK and sign again.
strip_baseline_profile() {
  local apk="$1" ks="$2" alias="$3" pass="$4"
  local work aligned
  work="$(mktemp -d)"
  aligned="$work/aligned.apk"
  note "Removing baseline profile from $(basename "$apk")"
  python3 "$ROOT/tools/release/strip_baseline_profile.py" "$apk" "$work/stripped.apk"
  # -P 16 keeps uncompressed .so files loadable on 16 KB page devices (Android 15+).
  # Build-tools 35+ reject combining -P with -p. -h is not a real flag, so read the
  # usage text from the error output instead of treating a non-zero status as failure.
  local align_help
  align_help="$("$zipalign" -h 2>&1 || true)"
  if grep -q -- '-P ' <<<"$align_help"; then
    "$zipalign" -P 16 -f 4 "$work/stripped.apk" "$aligned"
  else
    "$zipalign" -f -p 4 "$work/stripped.apk" "$aligned"
  fi
  APKSIGNER_PASS="$pass" "$apksigner" sign \
    --ks "$ks" \
    --ks-key-alias "$alias" \
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

export_one release "Android" "$release_apk" "$release_ks" "$release_alias" "$release_pass"
export_one debug "Android" "$debug_apk" "$debug_ks" "$debug_alias" "$debug_pass"
strip_baseline_profile "$release_apk" "$release_ks" "$release_alias" "$release_pass"

profile_apk="$ROOT/build/profile/zombie-blaster-${tag}-android-profile.apk"
mkdir -p "$(dirname "$profile_apk")"
# Release template, not debug, so on-device frame times match the 30 fps target.
export_one release "Android Profile" "$profile_apk" "$release_ks" "$release_alias" "$release_pass"
strip_baseline_profile "$profile_apk" "$release_ks" "$release_alias" "$release_pass"

# Same Android preset, keystore, and baseline strip as the phone APK. The only
# difference is the architecture, and that edit stays in this working copy.
# The EXIT trap restores export_presets.cfg, so the committed preset stays arm64.
smoke_apk="$ROOT/build/smoke/zombie-blaster-${tag}-android-smoke-x86_64.apk"
mkdir -p "$(dirname "$smoke_apk")"
python3 - "$preset" << 'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()
start = text.find("[preset.0.options]")
if start < 0:
    raise SystemExit("export_presets.cfg is missing [preset.0.options]")
end = text.find("\n[preset.", start + 1)
if end < 0:
    raise SystemExit("export_presets.cfg has no section after [preset.0.options]")
section = text[start:end]

def set_arch(body: str, name: str, value: str) -> str:
    pattern = rf"(?m)^architectures/{re.escape(name)}=.*$"
    updated, count = re.subn(pattern, f"architectures/{name}={value}", body, count=1)
    if count != 1:
        raise SystemExit(f"Android preset is missing architectures/{name}")
    return updated

def set_line(body: str, key: str, value: str) -> str:
    pattern = rf"(?m)^{re.escape(key)}=.*$"
    updated, count = re.subn(pattern, f"{key}={value}", body, count=1)
    if count != 1:
        raise SystemExit(f"Android preset is missing {key}")
    return updated

section = set_arch(section, "armeabi-v7a", "false")
section = set_arch(section, "arm64-v8a", "false")
section = set_arch(section, "x86", "false")
section = set_arch(section, "x86_64", "true")
# User args, so the phone preset's command_line/extra_args stays empty.
# Screen flags stay on the phone preset: edge-to-edge on, immersive off.
# --smoke-present=edge only names the one menu capture. It does not change
# those flags. The presentation copies are separate files.
if "screen/immersive_mode=false" not in section or "screen/edge_to_edge=true" not in section:
    raise SystemExit("x86_64 smoke export is not using the phone screen preset")
if "screen/immersive_mode=true" in section:
    raise SystemExit("x86_64 smoke export turned immersive mode back on")
section = set_line(section, "command_line/extra_args", '"-- --smoke-canvas --smoke-present=edge"')
path.write_text(text[:start] + section + text[end:])
rest = text[end:]
if "architectures/arm64-v8a=true" not in rest or "architectures/x86_64=false" not in rest:
    raise SystemExit("Refusing to export the smoke APK: the profile preset is no longer arm64-only")
PY
note "Exporting the CI-only x86_64 smoke APK. build/release stays arm64-only."
export_one release "Android" "$smoke_apk" "$release_ks" "$release_alias" "$release_pass"
strip_baseline_profile "$smoke_apk" "$release_ks" "$release_alias" "$release_pass"

align_and_sign() {
  local src="$1" dest="$2" ks="$3" alias="$4" pass="$5"
  local work aligned
  work="$(mktemp -d)"
  aligned="$work/aligned.apk"
  local align_help
  align_help="$("$zipalign" -h 2>&1 || true)"
  if grep -q -- '-P ' <<<"$align_help"; then
    "$zipalign" -P 16 -f 4 "$src" "$aligned"
  else
    "$zipalign" -f -p 4 "$src" "$aligned"
  fi
  APKSIGNER_PASS="$pass" "$apksigner" sign \
    --ks "$ks" \
    --ks-key-alias "$alias" \
    --ks-pass env:APKSIGNER_PASS \
    --key-pass env:APKSIGNER_PASS \
    --out "$dest" \
    "$aligned"
  rm -rf "$work"
}

# Same x86_64 library and resources. Each copy changes project.binary and/or
# _cl_ so the emulator can compare presentation settings. These files stay in
# build/smoke and are not the phone APK.
encoded_settings="$ROOT/build/smoke/present-settings.binary"
note "Encoding presentation settings for the smoke variants"
"$GODOT_BIN" --headless --path "$ROOT" --script "$ROOT/tools/release/encode_present_settings.gd" -- \
  --out="$encoded_settings" \
  --set=display/window/frame_pacing/android/enable_frame_pacing=bool:false \
  --set=display/window/vsync/vsync_mode=int:0 \
  --set=rendering/gl_compatibility/driver=string:opengl3_es \
  --set=rendering/gl_compatibility/driver.android=string:opengl3_es \
  --set=rendering/gl_compatibility/fallback_to_angle=bool:false \
  --set=rendering/gl_compatibility/fallback_to_gles=bool:false \
  --set=rendering/gl_compatibility/fallback_to_native=bool:false \
  --set=rendering/driver/threads/thread_model=int:2
mapfile -t unsigned_variants < <(python3 "$ROOT/tools/release/patch_present_apks.py" \
  --apk "$smoke_apk" \
  --encoded "$encoded_settings" \
  --out-dir "$(dirname "$smoke_apk")")
smoke_variants=()
for unsigned in "${unsigned_variants[@]}"; do
  if [[ -z "$unsigned" ]]; then
    continue
  fi
  final="${unsigned%.unsigned.apk}.apk"
  note "Signing presentation variant $(basename "$final")"
  align_and_sign "$unsigned" "$final" "$release_ks" "$release_alias" "$release_pass"
  rm -f "$unsigned"
  smoke_variants+=("$final")
done
if [[ "${#smoke_variants[@]}" -ne 6 ]]; then
  echo "expected 6 presentation variants, got ${#smoke_variants[@]}" >&2
  exit 1
fi

verify_apk() {
  local apk="$1"
  local package="$2"
  local badging
  badging="$("$aapt" dump badging "$apk")"
  printf '%s\n' "$badging" | awk 'NR<=20 { print }'
  case "$badging" in
    *"package: name='${package}'"*) ;;
    *) echo "$apk package name is not ${package}" >&2; exit 1 ;;
  esac
  local abi="${3:-arm64}"
  if [[ "$abi" == "arm64" ]]; then
    case "$badging" in
      *"native-code: 'arm64-v8a'"*) ;;
      *) echo "$apk is not arm64-v8a only" >&2; exit 1 ;;
    esac
    if [[ "$badging" == *x86_64* || "$badging" == *armeabi* || "$badging" == *"'x86'"* ]]; then
      echo "$apk contains an ABI other than arm64-v8a" >&2
      exit 1
    fi
  elif [[ "$abi" == "x86_64" ]]; then
    case "$badging" in
      *"native-code: 'x86_64'"*) ;;
      *) echo "$apk is not x86_64 only" >&2; exit 1 ;;
    esac
    if [[ "$badging" == *arm64* || "$badging" == *armeabi* || "$badging" == *"'x86'"* ]]; then
      echo "$apk smoke build contains an ABI other than x86_64" >&2
      exit 1
    fi
  else
    echo "unknown abi check '$abi'" >&2
    exit 1
  fi
  case "$badging" in
    *armeabi-v7a*)
      echo "$apk contains armeabi-v7a; the preset does not enable it." >&2
      exit 1
      ;;
  esac
  "$apksigner" verify --print-certs "$apk"
  note "$(basename "$apk"): $(wc -c < "$apk" | tr -d ' ') bytes"
}

# The smoke APK may add the canvas probe. Every other baked argument, including
# --edge_to_edge and the absence of --fullscreen, has to match the arm64 release.
assert_same_screen_preset() {
  python3 - "$1" "$2" << 'PY'
import struct
import sys
import zipfile

release_apk, smoke_apk = sys.argv[1], sys.argv[2]
SMOKE_ONLY = ("--", "--smoke-canvas", "--smoke-present=edge")

def command_line(path: str) -> list[str]:
    with zipfile.ZipFile(path) as apk:
        data = apk.read("assets/_cl_")
    count = struct.unpack_from("<I", data, 0)[0]
    pos = 4
    args = []
    for _ in range(count):
        length = struct.unpack_from("<I", data, pos)[0]
        pos += 4
        args.append(data[pos:pos + length].decode("utf-8"))
        pos += length
    if pos != len(data):
        raise SystemExit(f"{path} assets/_cl_ has trailing bytes")
    return args

release_args = command_line(release_apk)
smoke_args = command_line(smoke_apk)
print("release _cl_", " ".join(release_args))
print("smoke _cl_", " ".join(smoke_args))
for label, args in (("release", release_args), ("smoke", smoke_args)):
    if "--edge_to_edge" not in args:
        raise SystemExit(f"{label} APK is missing --edge_to_edge")
    if "--fullscreen" in args:
        raise SystemExit(f"{label} APK still has --fullscreen (immersive mode)")
if "--smoke-canvas" not in smoke_args or "--smoke-present=edge" not in smoke_args:
    raise SystemExit("smoke APK is missing the canvas probe args")
smoke_rest = [arg for arg in smoke_args if arg not in SMOKE_ONLY]
if smoke_rest != release_args:
    raise SystemExit(
        "smoke APK screen command line does not match the arm64 release: "
        + " ".join(smoke_rest)
    )
PY
}

assert_same_screen_preset "$release_apk" "$smoke_apk"
verify_apk "$release_apk" "com.zombieblaster.game" arm64
verify_apk "$debug_apk" "com.zombieblaster.game" arm64
verify_apk "$profile_apk" "com.zombieblaster.game.profile" arm64
verify_apk "$smoke_apk" "com.zombieblaster.game" x86_64
for variant_apk in "${smoke_variants[@]}"; do
  verify_apk "$variant_apk" "com.zombieblaster.game" x86_64
done
assert_project_data_packed "$release_apk" game
assert_project_data_packed "$debug_apk" game
assert_project_data_packed "$profile_apk" profile
assert_project_data_packed "$smoke_apk" game
for variant_apk in "${smoke_variants[@]}"; do
  assert_project_data_packed "$variant_apk" game
done
note "Android export finished: $release_apk"
note "Android export finished: $debug_apk"
note "Android export finished: $profile_apk"
note "Android export finished: $smoke_apk"
for variant_apk in "${smoke_variants[@]}"; do
  note "Android export finished: $variant_apk"
done
