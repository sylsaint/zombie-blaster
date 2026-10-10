#!/usr/bin/env bash
# Install each CI-only x86_64 presentation APK, capture the menu two ways,
# and tap 开始 then 第 1 关 on the baseline package.
# This is not the phone package. The arm64 release APK is a different artifact.
# Runs under reactivecircus/android-emulator-runner (adb is already on PATH).
# Godot draws UI in its own GL surface, so uiautomator has no button nodes.
# Coordinates are the 1080x1920 viewport rects of %Play and %Level1.
set -euo pipefail

ROOT="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
out="$ROOT/build/emulator"
mkdir -p "$out"

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

# baseline is the unpatched export. The rest are patched copies.
variant_apk() {
  local name="$1"
  local pattern
  if [[ "$name" == "baseline" ]]; then
    pattern='*-android-smoke-x86_64.apk'
  else
    pattern="*-android-smoke-x86_64-${name}.apk"
  fi
  # -quit avoids a pipe to head. pipefail turns that SIGPIPE into exit 141.
  find "$ROOT/dist" -type f -name "$pattern" -print -quit
}

variants=(baseline swappy vsync gles threads nosafe edge)
for variant in "${variants[@]}"; do
  if [[ -z "$(variant_apk "$variant")" ]]; then
    echo "Missing smoke APK for ${variant} under $ROOT/dist" >&2
    find "$ROOT/dist" -type f -name '*.apk' -print >&2 || true
    exit 1
  fi
done

adb wait-for-device

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

refresh_log() {
  adb logcat -d -b main -v time -s godot:I Godot:V > "$out/logcat-live.txt" || true
}

# First launch still compiles shaders. Give it a couple of minutes.
# grep -q on a live adb pipe trips pipefail (adb dies with SIGPIPE), so save the slice first.
wait_for_menu() {
  launch_app
  ready=0
  restarts=0
  seen_pid=0
  for i in $(seq 1 75); do
    refresh_log
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
    if [[ "$died" -eq 1 && "$restarts" -ge 2 ]]; then
      note "Godot exited during startup after ${restarts} restarts"
      break
    fi
    if (( i % 15 == 0 )); then
      note "still waiting for MENU_READY after $((i * 2))s pid=${pid_now:-missing} restarts=${restarts}"
      tail -n 20 "$out/logcat-live.txt" || true
    fi
    sleep 2
  done
}

wait_for_marker() {
  local pattern="$1"
  local i
  for i in $(seq 1 90); do
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

report_capture() {
  local kind="$1"
  local name="$2"
  local file="$3"
  local line="missing"
  if [[ -s "$file" ]]; then
    line="$(python3 "$ROOT/tools/release/check_menu_screenshot.py" --report "$file" 2>&1 || true)"
  fi
  note "${kind} ${name}: ${line}"
  printf '%s %s %s\n' "$kind" "$name" "$line" >> "$out/ratios.txt"
}

is_png() {
  python3 -c 'import sys; raise SystemExit(0 if open(sys.argv[1],"rb").read(8).startswith(b"\x89PNG") else 1)' "$1"
}

# adb exec-out screencap is binary, but some adb builds still mangle 0x0d.
# A device-side file plus adb pull is the fallback when the stream is not a PNG.
capture_screen() {
  local dest="$1"
  adb exec-out screencap -p > "$dest" || true
  if is_png "$dest"; then
    return 0
  fi
  note "exec-out screencap for $(basename "$dest") was not a PNG ($(wc -c < "$dest" | tr -d ' ') bytes); pulling a device-side capture"
  python3 -c 'import sys; d=open(sys.argv[1],"rb").read(24); print(d.hex())' "$dest" || true
  adb shell screencap -p /sdcard/zb_smoke.png
  adb pull /sdcard/zb_smoke.png "$dest"
  adb shell rm -f /sdcard/zb_smoke.png
  is_png "$dest"
}

# Host-side composited frame. The emulator writes the PNG on the machine that
# runs it, not on the guest. screencap stays the strict check.
capture_emu() {
  local dest="$1"
  local dir="$2"
  mkdir -p "$dir"
  if adb emu screenrecord screenshot "$dir" > "$dir/cmd.txt" 2>&1; then
    :
  fi
  local png=""
  png="$(find "$dir" -type f -name '*.png' -print -quit)"
  if [[ -n "$png" ]] && is_png "$png"; then
    cp "$png" "$dest"
    return 0
  fi
  if adb emu screenrecord screenshot "$dest" > "$dir/cmd-file.txt" 2>&1 && is_png "$dest"; then
    return 0
  fi
  note "emu screenshot for $(basename "$dest") failed: $(tr '\n' ' ' < "$dir/cmd.txt" | head -c 240)"
  return 1
}

install_apk() {
  local apk="$1"
  note "Installing $(basename "$apk")"
  adb shell am force-stop "$package" || true
  if ! adb install -r "$apk"; then
    note "ABI list: $(adb shell getprop ro.product.cpu.abilist | tr -d '\r')"
    return 1
  fi
  return 0
}

: > "$out/ratios.txt"
: > "$out/logcat.txt"
baseline_ready=0
baseline_screencap_ok=0
script_error=0

for variant in "${variants[@]}"; do
  apk="$(variant_apk "$variant")"
  if ! install_apk "$apk"; then
    printf 'variant %s install=failed\n' "$variant" >> "$out/ratios.txt"
    continue
  fi
  if [[ "$variant" == "baseline" ]]; then
    device_abi="$(adb shell getprop ro.product.cpu.abi | tr -d '\r')"
    adb shell dumpsys package "$package" | tr -d '\r' > "$out/package-dump.txt"
    package_abi="$(awk '/primaryCpuAbi/{print; exit}' "$out/package-dump.txt")"
    rm -f "$out/package-dump.txt"
    note "device abi: ${device_abi} package abi: ${package_abi:-missing}"
    printf 'device abi: %s\npackage abi: %s\n' "$device_abi" "${package_abi:-missing}" > "$out/abi.txt"
    if [[ "$package_abi" != *x86_64* || "$package_abi" == *arm64* ]]; then
      echo "Smoke APK is not running as x86_64 (${package_abi:-missing}). ARM translation would hide the canvas." >&2
      exit 1
    fi
  fi

  wait_for_menu
  if [[ "$ready" -ne 1 ]]; then
    note "${variant}: MENU_READY missing"
    printf 'variant %s menu_ready=missing\n' "$variant" >> "$out/ratios.txt"
  elif [[ "$variant" == "baseline" ]]; then
    baseline_ready=1
  fi

  if [[ "$ready" -ne 1 ]]; then
    printf 'engine %s missing\n' "$variant" >> "$out/ratios.txt"
  elif ! wait_for_marker "MENU_ENGINE name=${variant} "; then
    printf 'engine %s missing\n' "$variant" >> "$out/ratios.txt"
  else
    ratio="$(engine_field "$variant" ratio)"
    play="$(engine_field "$variant" play)"
    note "engine ${variant}: ratio=${ratio:-missing} play=${play:-missing}"
    printf 'engine %s ratio=%s play=%s\n' "$variant" "${ratio:-missing}" "${play:-missing}" >> "$out/ratios.txt"
  fi
  if grep -a 'MENU_PRESENT\|MENU_SETTINGS\|MENU_CMDLINE' "$out/logcat-live.txt" | tail -n 3; then
    grep -a 'MENU_SETTINGS\|MENU_CMDLINE' "$out/logcat-live.txt" | tail -n 2 >> "$out/ratios.txt" || true
  fi

  capture_screen "$out/${variant}-screencap.png" || true
  report_capture screencap "$variant" "$out/${variant}-screencap.png"
  if python3 "$ROOT/tools/release/check_menu_screenshot.py" "$out/${variant}-screencap.png"; then
    note "${variant}: screencap shows the menu"
    if [[ "$variant" == "baseline" ]]; then
      baseline_screencap_ok=1
    fi
  fi
  capture_emu "$out/${variant}-emu.png" "$out/emu-${variant}" || true
  report_capture emu "$variant" "$out/${variant}-emu.png"

  if [[ "$variant" == "baseline" && "$ready" -eq 1 ]]; then
    cp "$out/baseline-screencap.png" "$out/menu.png" || true
    if wait_for_marker "MENU_CANVAS_DONE"; then
      note "baseline canvas probe finished"
    fi
    adb shell input tap "$tap_play_x" "$tap_play_y"
    sleep 2
    adb shell input tap "$tap_level_x" "$tap_level_y"
    sleep 15
    capture_screen "$out/level1.png" || true
  elif [[ "$variant" == "baseline" ]]; then
    cp "$out/baseline-screencap.png" "$out/menu.png" 2>/dev/null || true
  fi

  refresh_log
  cp "$out/logcat-live.txt" "$out/logcat-${variant}.txt" || true
  {
    echo "---- ${variant} ----"
    cat "$out/logcat-${variant}.txt"
  } >> "$out/logcat.txt"
  if grep -a -E 'SCRIPT ERROR' "$out/logcat-${variant}.txt"; then
    echo "${variant} logcat contains SCRIPT ERROR" >&2
    script_error=1
  fi
  if grep -a -E 'FATAL|Fatal signal|Force quitting Godot' "$out/logcat-${variant}.txt"; then
    echo "${variant} logcat contains a native abort" >&2
    printf 'variant %s native_abort=1\n' "$variant" >> "$out/ratios.txt"
  fi
  adb shell am force-stop "$package" || true
done

adb logcat -d -b crash -v time | tr -d '\r' > "$out/crash.txt" || true

{
  echo "variant screencap_ratio emu_ratio engine_ratio"
  for variant in "${variants[@]}"; do
    screen_ratio="$(awk -v n="$variant" '$1=="screencap" && $2==n { if (match($0, /menu_ratio=[0-9.]+/)) { print substr($0, RSTART+11, RLENGTH-11); exit } }' "$out/ratios.txt")"
    emu_ratio="$(awk -v n="$variant" '$1=="emu" && $2==n { if (match($0, /menu_ratio=[0-9.]+/)) { print substr($0, RSTART+11, RLENGTH-11); exit } }' "$out/ratios.txt")"
    engine_ratio="$(awk -v n="$variant" '$1=="engine" && $2==n { if (match($0, /ratio=[0-9.]+/)) { print substr($0, RSTART+6, RLENGTH-6); exit } }' "$out/ratios.txt")"
    printf '%s %s %s %s\n' "$variant" "${screen_ratio:-missing}" "${emu_ratio:-missing}" "${engine_ratio:-missing}"
  done
} | tee "$out/table.txt" | tee -a "$out/ratios.txt"

status=0
if [[ "$baseline_ready" -ne 1 ]]; then
  echo "MENU_READY was not printed for the baseline smoke APK" >&2
  status=1
fi
if ! grep -a -q 'engine baseline ratio=' "$out/ratios.txt"; then
  echo "baseline engine menu_ratio was not printed" >&2
  status=1
fi
# The baseline smoke APK uses the phone preset. A patched variant passing is
# not enough: the package that ships has to show the menu in screencap.
if [[ "$baseline_screencap_ok" -ne 1 ]]; then
  echo "baseline screencap did not show the menu" >&2
  if ! python3 "$ROOT/tools/release/check_menu_screenshot.py" "$out/baseline-screencap.png"; then
    :
  fi
  status=1
fi
if [[ "$script_error" -ne 0 ]]; then
  echo "a variant log contains SCRIPT ERROR" >&2
  status=1
fi
if grep -a -E 'zombieblaster|godot|Godot' "$out/crash.txt"; then
  echo "crash buffer names the app (recorded; screencap is still the pass/fail check)" >&2
  printf 'crash_buffer names the app\n' >> "$out/ratios.txt"
fi
exit "$status"
