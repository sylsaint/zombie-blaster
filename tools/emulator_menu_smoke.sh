#!/usr/bin/env bash
# Install the CI-only x86_64 smoke APK on the booted emulator, screenshot the
# menu, tap 开始 then 第 1 关, and screenshot level 1.
# This is not the phone package. The arm64 release APK is a different artifact.
# Runs under reactivecircus/android-emulator-runner (adb is already on PATH).
# Godot draws UI in its own GL surface, so uiautomator has no button nodes.
# Coordinates are the 1080x1920 viewport rects of %Play and %Level1.
set -euo pipefail

ROOT="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
out="$ROOT/build/emulator"
mkdir -p "$out"

apk="$(find "$ROOT/dist" -type f -name '*-android-smoke-x86_64.apk' | head -n 1)"
if [[ -z "$apk" ]]; then
  echo "No *-android-smoke-x86_64.apk under $ROOT/dist" >&2
  exit 1
fi

package="com.zombieblaster.game"
# Viewport centers: %Play is (112, 1628) size 856x140; %Level1 is (112, 316) size 856x120.
play_x=540
play_y=1698
level_x=540
level_y=376
design_w=1080
design_h=1920

note() {
  printf '%s\n' "$*"
}

note "Installing $(basename "$apk")"
adb wait-for-device
if ! adb install -r "$apk"; then
  note "ABI list: $(adb shell getprop ro.product.cpu.abilist | tr -d '\r')"
  note "arm64 translation: $(adb shell getprop ro.dalvik.vm.isa.arm64 | tr -d '\r')"
  exit 1
fi
device_abi="$(adb shell getprop ro.product.cpu.abi | tr -d '\r')"
note "device abi: ${device_abi}"
# awk exiting on the first match closes a live adb pipe and pipefail turns that
# SIGPIPE into exit 141. Read the whole dump first.
adb shell dumpsys package "$package" | tr -d '\r' > "$out/package-dump.txt"
package_abi="$(awk '/primaryCpuAbi/{print; exit}' "$out/package-dump.txt")"
rm -f "$out/package-dump.txt"
note "package abi: ${package_abi:-missing}"
printf 'device abi: %s\npackage abi: %s\n' "$device_abi" "${package_abi:-missing}" > "$out/abi.txt"
if [[ "$package_abi" != *x86_64* || "$package_abi" == *arm64* ]]; then
  echo "Smoke APK is not running as x86_64 (${package_abi:-missing}). ARM translation would hide the canvas." >&2
  exit 1
fi

# Pixel 2 is already 1080x1920. Forcing wm size or density relaunches the
# activity while Godot is still creating the GL context, and the process dies.
size_text="$(adb shell wm size | tr -d '\r')"
note "$size_text"
screen_w=""
screen_h=""
if [[ "$size_text" =~ Override\ size:\ ([0-9]+)x([0-9]+) ]]; then
  screen_w="${BASH_REMATCH[1]}"
  screen_h="${BASH_REMATCH[2]}"
elif [[ "$size_text" =~ Physical\ size:\ ([0-9]+)x([0-9]+) ]]; then
  screen_w="${BASH_REMATCH[1]}"
  screen_h="${BASH_REMATCH[2]}"
fi
if [[ -z "$screen_w" || -z "$screen_h" ]]; then
  echo "Could not read the emulator resolution" >&2
  exit 1
fi

# keep_width: scale from the design width and center the extra vertical space.
map_tap() {
  python3 -c "
design_w, design_h = $design_w, $design_h
screen_w, screen_h = $screen_w, $screen_h
dx, dy = $1, $2
scale = screen_w / design_w
offset_y = (screen_h - design_h * scale) / 2.0
x = max(0, min(screen_w - 1, int(round(dx * scale))))
y = max(0, min(screen_h - 1, int(round(offset_y + dy * scale))))
print(x, y)
"
}

read -r tap_play_x tap_play_y < <(map_tap "$play_x" "$play_y")
read -r tap_level_x tap_level_y < <(map_tap "$level_x" "$level_y")
note "Tap 开始 at ${tap_play_x},${tap_play_y} and 第 1 关 at ${tap_level_x},${tap_level_y}"

# The first launch after install can get CONFIG_ASSETS_PATHS (0x80000000) while
# swangle is still creating the GL context. Godot then hits !_start_success,
# prints "Engine already initialized", and force-quits. A later start, after
# the package paths have settled, does not get that relaunch.
launch_app() {
  adb logcat -b all -c || true
  adb shell am start -n "${package}/com.godot.game.GodotAppLauncher"
}

# First launch still compiles shaders. Give it a couple of minutes.
# grep -q on a live adb pipe trips pipefail (adb dies with SIGPIPE), so save the slice first.
wait_for_menu() {
  launch_app
  ready=0
  restarts=0
  seen_pid=0
  for i in $(seq 1 75); do
    adb logcat -d -b main -v time -s godot:I Godot:V > "$out/logcat-live.txt" || true
    if grep -a -q 'MENU_READY' "$out/logcat-live.txt"; then
      ready=1
      break
    fi
    pid_now="$(adb shell pidof "$package" 2>/dev/null | tr -d '\r' || true)"
    if [[ -n "$pid_now" ]]; then
      seen_pid=1
    fi
    died=0
    if grep -a -q -E 'Force quitting Godot|!_start_success' "$out/logcat-live.txt"; then
      died=1
    fi
    if [[ "$seen_pid" -eq 1 && -z "$pid_now" ]]; then
      died=1
    fi
    if [[ "$died" -eq 1 && "$restarts" -lt 2 ]]; then
      restarts=$((restarts + 1))
      note "Godot exited during startup (restart ${restarts}); waiting for the package to settle"
      tail -n 15 "$out/logcat-live.txt" || true
      adb shell am force-stop "$package" || true
      sleep 3
      seen_pid=0
      launch_app
      sleep 2
      continue
    fi
    if (( i % 15 == 0 )); then
      note "still waiting for MENU_READY after $((i * 2))s pid=${pid_now:-missing} restarts=${restarts}"
      tail -n 20 "$out/logcat-live.txt" || true
    fi
    sleep 2
  done
}

wait_for_menu
release_ready="$ready"

refresh_log() {
  adb logcat -d -b main -v time -s godot:I Godot:V > "$out/logcat-live.txt" || true
}

wait_for_marker() {
  local pattern="$1"
  local i
  for i in $(seq 1 180); do
    refresh_log
    if grep -a -q "$pattern" "$out/logcat-live.txt"; then
      return 0
    fi
    sleep 1
  done
  echo "timed out waiting for $pattern" >&2
  return 1
}

engine_field() {
  local name="$1"
  local key="$2"
  awk -v n="$name" -v key="$key" '
    index($0, "MENU_ENGINE name=" n " ") {
      for (i = 1; i <= NF; i++) {
        if (index($i, key "=") == 1) {
          print substr($i, length(key) + 2)
          exit
        }
      }
    }
  ' "$out/logcat-live.txt"
}

report_screencap() {
  local name="$1"
  local file="$2"
  local line="missing"
  if [[ -s "$file" ]]; then
    line="$(python3 "$ROOT/tools/release/check_menu_screenshot.py" --report "$file" 2>&1 || true)"
  fi
  note "screencap ${name}: ${line}"
  printf 'screencap %s %s\n' "$name" "$line" >> "$out/ratios.txt"
}

is_png() {
  python3 -c 'import sys; raise SystemExit(0 if open(sys.argv[1],"rb").read(8).startswith(b"\x89PNG") else 1)' "$1"
}

pull_engine_png() {
  local name="$1"
  local dest="$2"
  local remote
  remote="$(engine_field "$name" file)"
  if [[ -z "$remote" ]]; then
    note "no engine file path for ${name}"
    return 1
  fi
  local base
  base="$(basename "$remote")"
  : > "$dest"
  if adb exec-out run-as "$package" cat "files/${base}" > "$dest" 2>"$out/run-as-${name}.txt"; then
    if is_png "$dest"; then
      note "pulled ${base} via run-as"
      return 0
    fi
  fi
  note "run-as did not return ${base} ($(tr -d '\r' < "$out/run-as-${name}.txt" | head -n 1))"
  if [[ "${adb_rooted:-0}" -ne 1 ]]; then
    adb root >/dev/null 2>&1 || true
    adb wait-for-device
    sleep 2
    adb_rooted=1
  fi
  if adb pull "$remote" "$dest" >/dev/null && is_png "$dest"; then
    note "pulled ${base} via adb root"
    return 0
  fi
  note "could not pull ${remote}"
  return 1
}

# adb exec-out screencap is binary, but some adb builds still mangle 0x0d.
# A device-side file plus adb pull is the fallback when the stream is not a PNG.
capture_screen() {
  local dest="$1"
  adb exec-out screencap -p > "$dest" || true
  if python3 -c 'import sys; raise SystemExit(0 if open(sys.argv[1],"rb").read(8).startswith(b"\x89PNG") else 1)' "$dest"; then
    return 0
  fi
  note "exec-out screencap for $(basename "$dest") was not a PNG ($(wc -c < "$dest" | tr -d ' ') bytes); pulling a device-side capture"
  python3 -c 'import sys; d=open(sys.argv[1],"rb").read(24); print(d.hex())' "$dest" || true
  adb shell screencap -p /sdcard/zb_smoke.png
  adb pull /sdcard/zb_smoke.png "$dest"
  adb shell rm -f /sdcard/zb_smoke.png
}

: > "$out/ratios.txt"
adb_rooted=0
for variant in menu no3d plain; do
  if ! wait_for_marker "MENU_ENGINE name=${variant} "; then
    printf 'engine %s missing\n' "$variant" >> "$out/ratios.txt"
    continue
  fi
  ratio="$(engine_field "$variant" ratio)"
  play="$(engine_field "$variant" play)"
  note "engine ${variant}: ratio=${ratio:-missing} play=${play:-missing}"
  printf 'engine %s ratio=%s play=%s\n' "$variant" "${ratio:-missing}" "${play:-missing}" >> "$out/ratios.txt"
  if [[ "$variant" == "menu" ]]; then
    capture_screen "$out/menu.png"
    report_screencap menu "$out/menu.png"
  else
    capture_screen "$out/menu-${variant}.png"
    report_screencap "$variant" "$out/menu-${variant}.png"
  fi
done
if [[ ! -s "$out/menu.png" ]]; then
  capture_screen "$out/menu.png" || true
fi
if wait_for_marker "MENU_CANVAS_DONE"; then
  note "canvas probe finished"
else
  echo "MENU_CANVAS_DONE was not printed" >&2
fi
refresh_log
if grep -a 'MENU_SETTINGS' "$out/logcat-live.txt" | tail -n 1; then
  grep -a 'MENU_SETTINGS' "$out/logcat-live.txt" | tail -n 1 >> "$out/ratios.txt"
fi

adb shell input tap "$tap_play_x" "$tap_play_y"
sleep 2
adb shell input tap "$tap_level_x" "$tap_level_y"
sleep 15
capture_screen "$out/level1.png"

pid="$(adb shell pidof "$package" 2>/dev/null | tr -d '\r' || true)"
{
  echo "pid=${pid:-missing}"
  if [[ -n "$pid" ]]; then
    # pidof can return more than one pid. logcat --pid takes one.
    adb logcat -d -v time --pid="${pid%% *}" || true
  fi
  echo "---- package and godot ----"
  adb logcat -d -b all -v time | tr -d '\r' | grep -a -E 'godot|Godot|com\.zombieblaster\.game|SCRIPT ERROR' || true
} > "$out/logcat.txt"
adb logcat -d -b crash -v time | tr -d '\r' > "$out/crash.txt" || true
refresh_log
for variant in menu no3d plain; do
  if [[ "$variant" == "menu" ]]; then
    engine_png="$out/menu-engine.png"
  else
    engine_png="$out/menu-engine-${variant}.png"
  fi
  if pull_engine_png "$variant" "$engine_png"; then
    file_line="$(python3 "$ROOT/tools/release/check_menu_screenshot.py" --report "$engine_png" 2>&1 || true)"
    note "engine-file ${variant}: ${file_line}"
    printf 'engine-file %s %s\n' "$variant" "$file_line" >> "$out/ratios.txt"
  else
    printf 'engine-file %s missing\n' "$variant" >> "$out/ratios.txt"
  fi
done

status=0
if [[ "$release_ready" -ne 1 ]]; then
  echo "MENU_READY was not printed" >&2
  status=1
fi
if ! grep -a -q 'engine menu ratio=' "$out/ratios.txt" \
  || ! grep -a -q 'engine no3d ratio=' "$out/ratios.txt" \
  || ! grep -a -q 'engine plain ratio=' "$out/ratios.txt"; then
  echo "an engine menu_ratio was not printed" >&2
  status=1
fi
if ! python3 "$ROOT/tools/release/check_menu_screenshot.py" "$out/menu.png"; then
  status=1
fi
if grep -a -E 'SCRIPT ERROR|FATAL|Fatal signal' "$out/logcat.txt"; then
  echo "logcat contains SCRIPT ERROR or FATAL" >&2
  status=1
fi
if grep -a -E 'zombieblaster|godot|Godot' "$out/crash.txt"; then
  echo "crash buffer names the app" >&2
  status=1
fi
exit "$status"
