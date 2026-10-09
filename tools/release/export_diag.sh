#!/usr/bin/env bash
# Build three debug-template, debug-signed diagnostic APKs.
# Reuses the JDK / Android SDK / Godot setup from export_android.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=common.sh
source "$ROOT/tools/release/common.sh"

if [[ -z "${JAVA_HOME:-}" ]]; then
  echo "JAVA_HOME is required (JDK 17)." >&2
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
overlay_dest="$ROOT/scripts/diag_overlay.gd"
preset_bak="$ROOT/build/export_presets.cfg.diag.bak"
project_bak="$ROOT/build/project.godot.diag.bak"

cp "$preset" "$preset_bak"
cp "$project" "$project_bak"

restore_tree() {
  if [[ -f "$preset_bak" ]]; then
    cp "$preset_bak" "$preset"
  fi
  if [[ -f "$project_bak" ]]; then
    cp "$project_bak" "$project"
  fi
  rm -f "$overlay_dest"
}
trap restore_tree EXIT

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

ensure_godot

# ensure_godot wipes editor config. Point the exporter at this JDK and SDK.
mkdir -p "$XDG_CONFIG_HOME/godot"
for settings_name in editor_settings-4.7.tres editor_settings-4.tres; do
  cat > "$XDG_CONFIG_HOME/godot/$settings_name" << EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$ANDROID_HOME"
export/android/java_sdk_path = "$JAVA_HOME"
export/android/debug_keystore = "$debug_ks"
export/android/debug_keystore_user = "$debug_alias"
export/android/debug_keystore_pass = "$debug_pass"
EOF
done

note "Importing project"
"$GODOT_BIN" --headless --path "$ROOT" --import

write_overlay_script() {
  cat > "$overlay_dest" << 'EOF'
extends CanvasLayer
## Diagnostic overlay. Explicit engine fallback font, no project theme.


var _label: Label


func _init() -> void:
	layer = 128


func _ready() -> void:
	layer = 128
	var font: Font = ThemeDB.fallback_font
	var settings := LabelSettings.new()
	settings.font = font
	settings.font_size = 28
	settings.font_color = Color.WHITE
	settings.outline_size = 6
	settings.outline_color = Color.BLACK
	var blank := Theme.new()
	blank.default_font = font
	blank.default_font_size = 28
	_label = Label.new()
	_label.theme = blank
	_label.label_settings = settings
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 16.0
	_label.offset_top = 16.0
	_label.offset_right = -16.0
	_label.offset_bottom = -16.0
	add_child(_label)
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.timeout.connect(_refresh)
	add_child(timer)
	timer.start()
	_refresh()


func _refresh() -> void:
	var win := DisplayServer.window_get_size()
	var visible_rect := get_viewport().get_visible_rect()
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.window_get_current_screen()
	var scale := DisplayServer.screen_get_scale(screen)
	var adapter := RenderingServer.get_video_adapter_name()
	var menu := get_tree().root.find_child("MainMenu", true, false) as Control
	var menu_line := "main_menu: missing"
	if menu != null:
		menu_line = "main_menu global_rect=%s visible=%s modulate=%s" % [menu.get_global_rect(), menu.visible, menu.modulate]
	var log_text := _log_tail()
	_label.text = "window=%s\nvisible_rect=%s\nsafe_area=%s\nscreen_scale=%s\nadapter=%s\n%s\n--- user://logs/godot.log ---\n%s" % [win, visible_rect, safe, scale, adapter, menu_line, log_text]


func _log_tail() -> String:
	var path := "user://logs/godot.log"
	if not FileAccess.file_exists(path):
		return "(no log yet)"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "(open failed: %s)" % error_string(FileAccess.get_open_error())
	var lines: PackedStringArray = PackedStringArray()
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty() and file.eof_reached():
			break
		lines.append(line)
	file.close()
	var start := maxi(0, lines.size() - 15)
	var chunk: PackedStringArray = PackedStringArray()
	for i in range(start, lines.size()):
		chunk.append(lines[i])
	if chunk.is_empty():
		return "(empty)"
	return "\n".join(chunk)
EOF
}

apply_variant() {
  local id="$1"
  python3 - "$ROOT" "$id" << 'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1])
variant = sys.argv[2]
project_path = root / "project.godot"
preset_path = root / "export_presets.cfg"
project = project_path.read_text()
preset = preset_path.read_text()

def replace_first(text, old, new, what):
    i = text.find(old)
    if i < 0:
        raise SystemExit(f"missing {what}: {old}")
    return text[:i] + new + text[i + len(old):]

def noop_safe_area_scripts(project_root: pathlib.Path) -> None:
    """Turn safe-area / screen-fit functions into a full-rect no-op."""
    markers = ("get_display_safe_area", "get_window_safe_area", "safe_area", "screen_fit", "ScreenFit")
    for path in (project_root / "scripts").glob("*.gd"):
        text = path.read_text()
        if not any(marker in text for marker in markers):
            continue
        path.write_text(_noop_functions(text, markers))

def _noop_functions(text: str, markers: tuple) -> str:
    lines = text.splitlines(keepends=True)
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.lstrip()
        if stripped.startswith("func ") and stripped.rstrip().endswith(":"):
            indent = line[: len(line) - len(stripped)]
            j = i + 1
            body = []
            while j < len(lines):
                nxt = lines[j]
                if nxt.strip() == "":
                    body.append(nxt)
                    j += 1
                    continue
                nxt_indent = len(nxt) - len(nxt.lstrip())
                if nxt_indent <= len(indent) and nxt.strip():
                    break
                body.append(nxt)
                j += 1
            blob = "".join(body)
            if any(marker in stripped or marker in blob for marker in markers):
                out.append(line)
                out.append(f"{indent}\tset_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)\n")
                out.append(f"{indent}\treturn\n")
                i = j
                continue
        out.append(line)
        i += 1
    return "".join(out)


packages = {
    "notheme": ("com.zombieblaster.diag.notheme", "打僵尸-无主题"),
    "nosafe": ("com.zombieblaster.diag.nosafe", "打僵尸-无安全区"),
    "overlay": ("com.zombieblaster.diag.overlay", "打僵尸-诊断"),
}
package, label = packages[variant]

preset = replace_first(
    preset,
    'package/unique_name="com.zombieblaster.game"',
    f'package/unique_name="{package}"',
    "package id",
)
preset = replace_first(
    preset,
    'package/name="高速打僵尸"',
    f'package/name="{label}"',
    "package name",
)

if variant == "notheme":
    project = replace_first(
        project,
        'theme/custom="res://assets/ui/game_theme.tres"',
        'theme/custom=""',
        "gui/theme/custom",
    )
elif variant == "nosafe":
    # No game script reads the display safe area or fits the UI to a screen
    # inset. The Android preset's screen fit is edge-to-edge off, which lets
    # the system inset the window. Turn that fit off so the UI keeps the full rect.
    preset = replace_first(
        preset,
        "screen/edge_to_edge=false",
        "screen/edge_to_edge=true",
        "edge_to_edge",
    )
    noop_safe_area_scripts(root)
elif variant == "overlay":
    if 'DiagOverlay="*res://scripts/diag_overlay.gd"' not in project:
        needle = 'ProfileBoot="*res://scripts/profile_boot.gd"\n'
        project = replace_first(
            project,
            needle,
            needle + 'DiagOverlay="*res://scripts/diag_overlay.gd"\n',
            "autoload",
        )
    if "[debug]" not in project:
        project = project.rstrip() + "\n\n[debug]\n\nfile_logging/enable_file_logging=true\nfile_logging/log_path=\"user://logs/godot.log\"\n"
    else:
        if "file_logging/enable_file_logging=true" not in project:
            project = project.rstrip() + "\nfile_logging/enable_file_logging=true\nfile_logging/log_path=\"user://logs/godot.log\"\n"

project_path.write_text(project)
preset_path.write_text(preset)
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
  unset GODOT_ANDROID_KEYSTORE_DEBUG_PATH GODOT_ANDROID_KEYSTORE_DEBUG_USER GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD
  if [[ ! -s "$apk" ]]; then
    echo "Export did not produce $apk" >&2
    exit 1
  fi
}

export_variant() {
  local id="$1"
  local package="$2"
  local apk="$out_dir/zombie-blaster-diag-${id}.apk"
  rm -f "$overlay_dest"
  cp "$preset_bak" "$preset"
  cp "$project_bak" "$project"
  if [[ "$id" == "overlay" ]]; then
    write_overlay_script
  fi
  apply_variant "$id"
  export_debug "$apk"
  verify_apk "$apk" "$package"
  assert_project_data_packed "$apk" game
  note "Built $apk"
}

verify_apk() {
  local apk="$1"
  local package="$2"
  local aapt apksigner badging
  aapt="$(find "$ANDROID_HOME/build-tools" -type f -name aapt | sort | tail -n 1)"
  apksigner="$(find "$ANDROID_HOME/build-tools" -type f -name apksigner | sort | tail -n 1)"
  badging="$("$aapt" dump badging "$apk")"
  printf '%s\n' "$badging" | awk 'NR<=12 { print }'
  case "$badging" in
    *"package: name='${package}'"*) ;;
    *) echo "$apk package name is not ${package}" >&2; exit 1 ;;
  esac
  case "$badging" in
    *"native-code: 'arm64-v8a'"*) ;;
    *) echo "$apk is not arm64-v8a" >&2; exit 1 ;;
  esac
  "$apksigner" verify --print-certs "$apk" >/dev/null
  note "$(basename "$apk"): $(wc -c < "$apk" | tr -d ' ') bytes, package ${package}"
}

export_variant notheme "com.zombieblaster.diag.notheme"
export_variant nosafe "com.zombieblaster.diag.nosafe"
export_variant overlay "com.zombieblaster.diag.overlay"
note "Diagnostic APKs are in $out_dir"
