#!/usr/bin/env bash
# Build debug-signed diagnostic arm64 APKs.
# Reuses the JDK / Android SDK / Godot setup from export_android.sh.
#
#   export_diag.sh            debug template, the original three UI variants
#   export_diag.sh release    release template (--export-release), debug keystore
#                             used as the release key:
#                             relnoprof (baseline.prof* removed), relov, relplain
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
    "relnoprof": ("com.zombieblaster.diag.relnoprof", "打僵尸-R无prof"),
    "relov": ("com.zombieblaster.diag.relov", "打僵尸-R诊断"),
    "relplain": ("com.zombieblaster.diag.relplain", "打僵尸-R原样"),
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
elif variant in ("overlay", "relov"):
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

find_sdk_tool() {
  local name="$1" tool
  tool="$(find "$ANDROID_HOME/build-tools" -type f -name "$name" | sort | tail -n 1)"
  if [[ -z "$tool" ]]; then
    echo "$name is missing under $ANDROID_HOME/build-tools" >&2
    exit 1
  fi
  printf '%s' "$tool"
}

export_apk() {
  local mode="$1"
  local apk="$2"
  if [[ "$mode" == "release" ]]; then
    # Debug keystore is the release key. Godot's release export reads these.
    export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$debug_ks"
    export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$debug_alias"
    export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$debug_pass"
    unset GODOT_ANDROID_KEYSTORE_DEBUG_PATH GODOT_ANDROID_KEYSTORE_DEBUG_USER GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD || true
    note "Exporting release APK -> $(basename "$apk")"
    "$GODOT_BIN" --headless --audio-driver Dummy --path "$ROOT" \
      --export-release "Android" "$apk"
    unset GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
  else
    export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$debug_ks"
    export GODOT_ANDROID_KEYSTORE_DEBUG_USER="$debug_alias"
    export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="$debug_pass"
    unset GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD || true
    note "Exporting debug APK -> $(basename "$apk")"
    "$GODOT_BIN" --headless --audio-driver Dummy --path "$ROOT" \
      --export-debug "Android" "$apk"
    unset GODOT_ANDROID_KEYSTORE_DEBUG_PATH GODOT_ANDROID_KEYSTORE_DEBUG_USER GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD
  fi
  if [[ ! -s "$apk" ]]; then
    echo "Export did not produce $apk" >&2
    exit 1
  fi
}

# zip -d, then zipalign, then apksigner. The debug keystore signs the result.
strip_baseline_profiles() {
  local apk="$1"
  local aligned signed zipalign apksigner
  local -a profs
  mapfile -t profs < <(unzip -Z1 "$apk" | grep -E '(^|/)baseline\.prof' || true)
  if (( ${#profs[@]} == 0 )); then
    echo "release APK has no baseline.prof* entry: $apk" >&2
    exit 1
  fi
  note "Removing ${profs[*]} from $(basename "$apk")"
  zip -d "$apk" "${profs[@]}"
  zipalign="$(find_sdk_tool zipalign)"
  apksigner="$(find_sdk_tool apksigner)"
  aligned="${apk}.aligned"
  signed="${apk}.signed"
  "$zipalign" -f -p 4 "$apk" "$aligned"
  "$apksigner" sign \
    --ks "$debug_ks" \
    --ks-key-alias "$debug_alias" \
    --ks-pass "pass:$debug_pass" \
    --key-pass "pass:$debug_pass" \
    --v4-signing-enabled false \
    --out "$signed" \
    "$aligned"
  mv "$signed" "$apk"
  rm -f "$aligned" "${apk}.idsig" "${signed}.idsig"
  if unzip -Z1 "$apk" | grep -E '(^|/)baseline\.prof' >/dev/null; then
    echo "baseline.prof* still present in $apk" >&2
    exit 1
  fi
}

assert_has_baseline() {
  local apk="$1"
  if ! unzip -Z1 "$apk" | grep -E '(^|/)baseline\.prof' >/dev/null; then
    echo "$apk is missing baseline.prof*" >&2
    exit 1
  fi
  note "$(basename "$apk") still contains baseline.prof*"
}

export_variant() {
  local mode="$1"
  local id="$2"
  local package="$3"
  local label="${4:-}"
  local apk="$out_dir/zombie-blaster-diag-${id}.apk"
  rm -f "$overlay_dest"
  cp "$preset_bak" "$preset"
  cp "$project_bak" "$project"
  if [[ "$id" == "overlay" || "$id" == "relov" ]]; then
    write_overlay_script
  fi
  apply_variant "$id"
  export_apk "$mode" "$apk"
  if [[ "$id" == "relnoprof" ]]; then
    strip_baseline_profiles "$apk"
  elif [[ "$mode" == "release" ]]; then
    assert_has_baseline "$apk"
  fi
  verify_apk "$apk" "$package" "$label"
  assert_project_data_packed "$apk" game
  note "Built $apk"
}

verify_apk() {
  local apk="$1"
  local package="$2"
  local label="${3:-}"
  local aapt apksigner badging
  aapt="$(find_sdk_tool aapt)"
  apksigner="$(find_sdk_tool apksigner)"
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
  if [[ -n "$label" ]]; then
    case "$badging" in
      *"application-label:'${label}'"*) ;;
      *) echo "$apk launcher name is not ${label}" >&2; exit 1 ;;
    esac
  fi
  "$apksigner" verify --print-certs "$apk" >/dev/null
  note "$(basename "$apk"): $(wc -c < "$apk" | tr -d ' ') bytes, package ${package}"
}

# Release-export the overlay project, run that pck with the Linux release
# template, and save a viewport screenshot. The screenshot hook is appended
# after the APK export, so it is not in the APK.
run_release_pck_on_desktop() {
  rm -f "$overlay_dest"
  cp "$preset_bak" "$preset"
  cp "$project_bak" "$project"
  write_overlay_script
  apply_variant relov
  cat >> "$overlay_dest" << 'EOF'

var _desktop_proof_from := 0

func _process(_delta: float) -> void:
	if _desktop_proof_from == 0:
		_desktop_proof_from = Time.get_ticks_msec()
		return
	if Time.get_ticks_msec() - _desktop_proof_from < 2500:
		return
	set_process(false)
	_capture_desktop_proof()

func _capture_desktop_proof() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := OS.get_environment("DIAG_OVERLAY_PNG")
	if path.is_empty():
		path = "user://diag_overlay_desktop.png"
	var err := image.save_png(path)
	print("DIAG_LABEL_TEXT_BEGIN")
	print(_label.text)
	print("DIAG_LABEL_TEXT_END")
	print("DIAG_LABEL_RECT ", _label.get_global_rect(), " size ", image.get_size(), " save ", err)
	get_tree().quit()
EOF
  if ! grep -q 'name="Linux"' "$preset"; then
    cat >> "$preset" << 'EOF'

[preset.3]

name="Linux"
platform="Linux"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="tests/*, addons/gut/*, scenes/debug/*"
export_path=""
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.3.options]

custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=1
binary_format/embed_pck=false
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
shader_baker/enabled=false
binary_format/architecture="x86_64"
EOF
  fi
  local desk="$out_dir/desktop-relov"
  mkdir -p "$desk"
  local bin="$desk/diag-relov.x86_64"
  note "Exporting release pck for the desktop overlay check"
  "$GODOT_BIN" --headless --audio-driver Dummy --path "$ROOT" \
    --export-release "Linux" "$bin"
  local pck="$desk/diag-relov.pck"
  if [[ ! -s "$pck" ]]; then
    echo "Release export did not write $pck" >&2
    ls -la "$desk" >&2 || true
    exit 1
  fi
  chmod +x "$bin"
  local png="$desk/overlay.png"
  local log="$desk/run.log"
  rm -f "$png"
  note "Running the release pck on desktop"
  set +e
  DIAG_OVERLAY_PNG="$png" timeout 120 xvfb-run -a -s "-screen 0 1080x1920x24 +extension GLX +render" \
    "$bin" --display-driver x11 --rendering-driver opengl3 --rendering-method gl_compatibility --audio-driver Dummy >"$log" 2>&1
  local rc=$?
  set -e
  note "Desktop run exit=$rc (log $log)"
  if [[ ! -s "$png" ]]; then
    echo "Desktop run did not write $png" >&2
    tail -n 80 "$log" >&2 || true
    exit 1
  fi
  note "Desktop overlay screenshot: $png"
}

mode="${1:-debug}"
case "$mode" in
  debug)
    export_variant debug notheme "com.zombieblaster.diag.notheme"
    export_variant debug nosafe "com.zombieblaster.diag.nosafe"
    export_variant debug overlay "com.zombieblaster.diag.overlay"
    ;;
  release)
    export_variant release relnoprof "com.zombieblaster.diag.relnoprof" "打僵尸-R无prof"
    export_variant release relov "com.zombieblaster.diag.relov" "打僵尸-R诊断"
    export_variant release relplain "com.zombieblaster.diag.relplain" "打僵尸-R原样"
    if [[ "${DIAG_SKIP_DESKTOP:-}" != "1" ]]; then
      run_release_pck_on_desktop
    fi
    ;;
  desktop)
    run_release_pck_on_desktop
    ;;
  *)
    echo "Usage: $0 [debug|release]" >&2
    exit 1
    ;;
esac
note "Diagnostic APKs are in $out_dir"
