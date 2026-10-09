#!/usr/bin/env bash
# Install the exported release APK on the booted emulator, screenshot the menu,
# tap 开始 then 第 1 关, and screenshot level 1.
# Runs under reactivecircus/android-emulator-runner (adb is already on PATH).
# Godot draws UI in its own GL surface, so uiautomator has no button nodes.
# Coordinates are the 1080x1920 viewport rects of %Play and %Level1.
set -euo pipefail

ROOT="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
out="$ROOT/build/emulator"
mkdir -p "$out"

apk="$(find "$ROOT/dist" -type f -name '*-android-release.apk' | head -n 1)"
if [[ -z "$apk" ]]; then
  echo "No *-android-release.apk under $ROOT/dist" >&2
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

adb shell wm size 1080x1920 || true
adb shell wm density 420 || true
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

adb logcat -b all -c || true
adb shell am start -n "${package}/com.godot.game.GodotAppLauncher"
ready=0
# First launch translates the arm64 libgodot_android.so. Give it a couple of minutes.
# grep -q on a live adb pipe trips pipefail (adb dies with SIGPIPE), so save the slice first.
for i in $(seq 1 60); do
  adb logcat -d -b main -v time -s godot:I Godot:V > "$out/logcat-live.txt" || true
  if grep -a -q 'MENU_READY' "$out/logcat-live.txt"; then
    ready=1
    break
  fi
  if (( i % 15 == 0 )); then
    pid_now="$(adb shell pidof "$package" 2>/dev/null | tr -d '\r' || true)"
    note "still waiting for MENU_READY after $((i * 2))s pid=${pid_now:-missing}"
    adb logcat -d -b all -t 40 -v time | tr -d '\r' | grep -a -E 'godot|Godot|zombieblaster|SCRIPT ERROR|FATAL|Fatal signal' | tail -n 20 || true
  fi
  sleep 2
done
# Let the GL surface present the canvas after the scene is ready.
if [[ "$ready" -eq 1 ]]; then
  sleep 3
fi

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

capture_screen "$out/menu.png"

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

status=0
if [[ "$ready" -ne 1 ]]; then
  echo "MENU_READY was not printed" >&2
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
