#!/usr/bin/env bash
# Three debug-signed arm64 APKs with distinct package ids so they install side by side.
# notheme: project GUI theme cleared.
# nosafe: feature diag_nosafe (skip screen-fit) and screen/edge_to_edge=true.
# overlay: feature diag_overlay (top CanvasLayer diagnostic).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=common.sh
source "$ROOT/tools/release/common.sh"

if [[ -z "${JAVA_HOME:-}" ]]; then
  echo "JAVA_HOME is required." >&2
  exit 1
fi
if [[ -z "${ANDROID_HOME:-}" ]]; then
  echo "ANDROID_HOME is required." >&2
  exit 1
fi

out_dir="$ROOT/build/diag"
sign_dir="$ROOT/build/signing"
mkdir -p "$out_dir" "$sign_dir"
preset="$ROOT/export_presets.cfg"
project="$ROOT/project.godot"
preset_orig="$out_dir/export_presets.cfg.orig"
project_orig="$out_dir/project.godot.orig"
cp "$preset" "$preset_orig"
cp "$project" "$project_orig"

restore_sources() {
  if [[ -f "$preset_orig" ]]; then
    cp "$preset_orig" "$preset"
  fi
  if [[ -f "$project_orig" ]]; then
    cp "$project_orig" "$project"
  fi
}
trap restore_sources EXIT

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
debug_ks="$(cd "$(dirname "$debug_ks")" && pwd)/$(basename "$debug_ks")"

AAPT="$(find "$ANDROID_HOME/build-tools" -name aapt -type f | sort | tail -n 1)"
APKSIGNER="$(find "$ANDROID_HOME/build-tools" -name apksigner -type f | sort | tail -n 1)"
if [[ -z "$AAPT" || ! -x "$AAPT" ]]; then
  echo "aapt not found under $ANDROID_HOME/build-tools" >&2
  exit 1
fi

ensure_godot
note "Importing project"
"$GODOT_BIN" --headless --path "$ROOT" --import

apply_variant() {
  local variant="$1" name="$2" package="$3" feature="$4" clear_theme="$5" edge="$6"
  cp "$project_orig" "$project"
  cp "$preset_orig" "$preset"
  python3 - "$project" "$preset" "$variant" "$name" "$package" "$feature" "$clear_theme" "$edge" << 'PY'
import pathlib, sys
project_path, preset_path, variant, app_name, package, feature, clear_theme, edge = sys.argv[1:]
project = pathlib.Path(project_path).read_text(encoding="utf-8")
old_name = 'config/name="高速打僵尸"'
if old_name not in project:
    raise SystemExit("project.godot is missing config/name")
project = project.replace(old_name, 'config/name="%s"' % app_name, 1)
if clear_theme == "1":
    old_theme = 'theme/custom="res://assets/ui/game_theme.tres"'
    if old_theme not in project:
        raise SystemExit("project.godot is missing the game theme line")
    project = project.replace(old_theme, 'theme/custom=""', 1)
# config/description is a real project setting, so it survives into project.binary.
# The launcher label stays config/name. This tag is only for the packed-apk check.
name_line = 'config/name="%s"\n' % app_name
if name_line not in project:
    raise SystemExit("renamed config/name did not land")
project = project.replace(name_line, name_line + 'config/description="diag-%s"\n' % variant, 1)
pathlib.Path(project_path).write_text(project, encoding="utf-8")

preset = pathlib.Path(preset_path).read_text(encoding="utf-8")
head, sep, tail = preset.partition("\n[preset.1]")
if not sep:
    raise SystemExit("export_presets.cfg is missing [preset.1]")

def repl(text, old, new, label):
    if old not in text:
        raise SystemExit("Android preset is missing %s" % label)
    return text.replace(old, new, 1)

head = repl(head, 'custom_features=""', 'custom_features="%s"' % feature, "custom_features")
head = repl(head, 'package/unique_name="com.zombieblaster.game"', 'package/unique_name="%s"' % package, "unique_name")
head = repl(head, 'package/name="高速打僵尸"', 'package/name="%s"' % app_name, "package/name")
if edge == "1":
    head = repl(head, "screen/edge_to_edge=false", "screen/edge_to_edge=true", "edge_to_edge")
pathlib.Path(preset_path).write_text(head + sep + tail, encoding="utf-8")
print("variant %s package=%s feature=%s theme_cleared=%s edge_to_edge=%s" % (app_name, package, feature or "-", clear_theme, edge))
PY
}

export_debug() {
  local apk="$1"
  export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$debug_ks"
  export GODOT_ANDROID_KEYSTORE_DEBUG_USER="$debug_alias"
  export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="$debug_pass"
  unset GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD || true
  note "Exporting debug APK -> $(basename "$apk")"
  "$GODOT_BIN" --headless --audio-driver Dummy --path "$ROOT" \
    --export-debug "Android" "$apk"
  if [[ ! -s "$apk" ]]; then
    echo "Export did not produce $apk" >&2
    exit 1
  fi
}

verify_apk() {
  local apk="$1" package="$2" label="$3" want_theme="$4" variant="$5" want_edge="$6"
  local badging
  badging="$("$AAPT" dump badging "$apk")"
  if ! grep -q "package: name='$package'" <<<"$badging"; then
    echo "badging package mismatch for $apk" >&2
    echo "$badging" | head -n 20 >&2
    exit 1
  fi
  if ! grep -q "application-label:'$label'" <<<"$badging"; then
    echo "badging label mismatch for $apk (wanted $label)" >&2
    echo "$badging" | grep application-label >&2 || true
    exit 1
  fi
  if ! grep -q "native-code: 'arm64-v8a'" <<<"$badging"; then
    echo "$apk is not arm64-v8a" >&2
    echo "$badging" | grep native-code >&2 || true
    exit 1
  fi
  if grep -q "x86_64" <<<"$badging"; then
    echo "$apk contains x86_64" >&2
    exit 1
  fi
  if [[ -n "$APKSIGNER" ]]; then
    "$APKSIGNER" verify "$apk"
  fi
  python3 - "$apk" "$want_theme" "$variant" << 'PY'
import sys, zipfile
apk, want_theme, variant = sys.argv[1:]
with zipfile.ZipFile(apk) as zf:
    names = [name for name in zf.namelist() if name.endswith("project.binary")]
    blobs = [zf.read(name) for name in names]
if not blobs:
    raise SystemExit("APK has no project.binary")
raw = b"".join(blobs)
has_theme = b"game_theme.tres" in raw
if want_theme == "1" and not has_theme:
    raise SystemExit("project.binary lost game_theme.tres")
if want_theme == "0" and has_theme:
    raise SystemExit("empty-theme project.binary still points at game_theme.tres")
marker = ("diag-%s" % variant).encode()
if marker not in raw:
    raise SystemExit("project.binary is missing diag variant %s" % variant)
print("project.binary theme_ok want=%s variant=%s" % (want_theme, variant))
PY
  if [[ "$want_edge" == "1" ]]; then
    "$AAPT" dump xmltree "$apk" AndroidManifest.xml > "$out_dir/$(basename "$apk").xmltree"
  fi
  note "verified $(basename "$apk") $package"
}

notheme_apk="$out_dir/zombie-blaster-diag-notheme.apk"
nosafe_apk="$out_dir/zombie-blaster-diag-nosafe.apk"
overlay_apk="$out_dir/zombie-blaster-diag-overlay.apk"
rm -f "$notheme_apk" "$nosafe_apk" "$overlay_apk"

apply_variant "notheme" "打僵尸-无主题" "com.zombieblaster.diag.notheme" "" 1 0
export_debug "$notheme_apk"
verify_apk "$notheme_apk" "com.zombieblaster.diag.notheme" "打僵尸-无主题" 0 "notheme" 0

apply_variant "nosafe" "打僵尸-无安全区" "com.zombieblaster.diag.nosafe" "diag_nosafe" 0 1
export_debug "$nosafe_apk"
verify_apk "$nosafe_apk" "com.zombieblaster.diag.nosafe" "打僵尸-无安全区" 1 "nosafe" 1

apply_variant "overlay" "打僵尸-诊断" "com.zombieblaster.diag.overlay" "diag_overlay" 0 0
export_debug "$overlay_apk"
verify_apk "$overlay_apk" "com.zombieblaster.diag.overlay" "打僵尸-诊断" 1 "overlay" 0

# Godot 4.7 writes screen/edge_to_edge into assets/_cl_ as --edge_to_edge.
python3 - "$notheme_apk" "$nosafe_apk" "$overlay_apk" << 'PY'
import sys, zipfile
notheme, nosafe, overlay = sys.argv[1:]

def cmdline(path):
    with zipfile.ZipFile(path) as zf:
        if "assets/_cl_" not in zf.namelist():
            raise SystemExit("%s has no assets/_cl_" % path)
        return zf.read("assets/_cl_")

for path, want in ((notheme, False), (nosafe, True), (overlay, False)):
    raw = cmdline(path)
    has = b"--edge_to_edge" in raw
    print(path, "edge_to_edge", has)
    if has != want:
        raise SystemExit("unexpected --edge_to_edge in %s" % path)
PY

note "diag APKs:"
note "$notheme_apk"
note "$nosafe_apk"
note "$overlay_apk"
