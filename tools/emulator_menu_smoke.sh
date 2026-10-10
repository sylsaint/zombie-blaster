#!/usr/bin/env bash
# Install the CI-only x86_64 smoke APK and check the screen phones get:
# edge_to_edge on, immersive mode off. That package is the unsuffixed
# *-android-smoke-x86_64.apk. The patched presentation copies are not installed.
# This is not the phone package. The arm64 release APK is a different artifact.
# Runs under reactivecircus/android-emulator-runner (adb is already on PATH).
# Godot draws UI in its own GL surface, so uiautomator has no button nodes.
# Tap centers come from MENU_LAYOUT / MENU_SELECT (viewport coords). The
# fallbacks are the 1080x1920 centers of %Play and %Level1.
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

# -quit avoids a pipe to head. pipefail turns that SIGPIPE into exit 141.
# The suffixed presentation APKs end in -swappy.apk and so on, so this name
# matches only the unpatched export.
smoke_apk="$(find "$ROOT/dist" -type f -name '*-android-smoke-x86_64.apk' -print -quit)"
if [[ -z "$smoke_apk" ]]; then
  echo "Missing the unsuffixed x86_64 smoke APK under $ROOT/dist" >&2
  find "$ROOT/dist" -type f -name '*.apk' -print >&2 || true
  exit 1
fi

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
note "Fallback taps: 开始 at ${tap_play_x},${tap_play_y} and 第 1 关 at ${tap_level_x},${tap_level_y}"

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
  local limit="${2:-90}"
  local i
  for i in $(seq 1 "$limit"); do
    refresh_log
    if grep -a -q "$pattern" "$out/logcat-live.txt"; then
      return 0
    fi
    sleep 1
  done
  echo "timed out waiting for $pattern" >&2
  return 1
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

apply_layout_tap() {
  local kind="$1"
  local fallback_x="$2"
  local fallback_y="$3"
  local center
  center="$(python3 - "$out/logcat-live.txt" "$kind" "$fallback_x" "$fallback_y" << 'PY'
import re
import sys
path, kind, fallback_x, fallback_y = sys.argv[1:]
text = open(path, encoding="utf-8", errors="replace").read()
if kind == "play":
    match = re.search(r"play_x=([0-9.]+) play_y=([0-9.]+) play_w=([0-9.]+) play_h=([0-9.]+)", text)
else:
    match = re.search(r"level_x=([0-9.]+) level_y=([0-9.]+) level_w=([0-9.]+) level_h=([0-9.]+)", text)
if match is None:
    print(fallback_x, fallback_y, "fallback")
    raise SystemExit(0)
x, y, w, h = (float(part) for part in match.groups())
if w < 8.0 or h < 8.0:
    print(fallback_x, fallback_y, "fallback")
else:
    print(x + w / 2.0, y + h / 2.0, "layout")
PY
)"
  local dx dy source
  read -r dx dy source <<<"$center"
  local tx ty
  read -r tx ty < <(map_tap "$dx" "$dy")
  note "Tap ${kind} (${source} ${dx},${dy}) at ${tx},${ty}"
  adb shell input tap "$tx" "$ty"
}

note "Installing $(basename "$smoke_apk")"
adb shell am force-stop "$package" || true
if ! adb install -r "$smoke_apk"; then
  note "ABI list: $(adb shell getprop ro.product.cpu.abilist | tr -d '\r')"
  exit 1
fi

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

menu_ready=0
menu_screencap_ok=0
script_error=0
safe_ok=0
level_ok=0

wait_for_menu
if [[ "$ready" -ne 1 ]]; then
  note "MENU_READY missing"
else
  menu_ready=1
fi

if [[ "$menu_ready" -eq 1 ]]; then
  wait_for_marker "MENU_ENGINE name=edge " || true
  wait_for_marker "MENU_SAFE " 15 || true
  wait_for_marker "MENU_TOP " 15 || true
fi

capture_screen "$out/edge-menu.png" || true
if [[ -s "$out/edge-menu.png" ]]; then
  python3 "$ROOT/tools/release/check_menu_screenshot.py" --report "$out/edge-menu.png" | tee "$out/edge-menu.txt" || true
fi
if python3 "$ROOT/tools/release/check_menu_screenshot.py" "$out/edge-menu.png"; then
  note "edge-menu.png shows the menu"
  menu_screencap_ok=1
else
  note "edge-menu.png did not show the menu"
fi

if [[ "$menu_ready" -eq 1 ]]; then
  if wait_for_marker "MENU_CANVAS_DONE"; then
    note "canvas probe finished"
  fi
  apply_layout_tap play "$play_x" "$play_y"
  if ! wait_for_marker "MENU_SELECT " 8; then
    note "level select did not open; tapping 开始 again"
    apply_layout_tap play "$play_x" "$play_y"
    wait_for_marker "MENU_SELECT " 8 || true
  fi
  sleep 1
  apply_layout_tap level "$level_x" "$level_y"
  note "waiting 15s for level 1"
  sleep 15
fi

capture_screen "$out/edge-level1.png" || true
refresh_log
cp "$out/logcat-live.txt" "$out/logcat.txt" || true

{
  echo "---- logcat priority E ----"
  adb logcat -d -b main -b crash -v time '*:E' || true
  echo "---- app lines ----"
  grep -a -E 'SCRIPT ERROR|ERROR:|Fatal signal|AndroidRuntime|Exception|Force quitting Godot' "$out/logcat-live.txt" || true
} > "$out/logcat-errors.txt"

python3 - "$out/logcat-live.txt" "$out/safe-area.txt" << 'PY'
import re
import sys
from pathlib import Path

log_path, dest = sys.argv[1], sys.argv[2]
text = Path(log_path).read_text(encoding="utf-8", errors="replace") if Path(log_path).exists() else ""

def last(pattern: str):
    found = re.findall(pattern, text)
    return found[-1] if found else None

safe = last(r"MENU_SAFE safe_x=(-?\d+) safe_y=(-?\d+) safe_w=(-?\d+) safe_h=(-?\d+) cutouts=(\d+) window=(\d+)x(\d+) screen=(\d+)x(\d+)")
top = last(r"MENU_TOP name=(\S+) y=([0-9.]+) h=([0-9.]+) x=([0-9.]+) w=([0-9.]+)")
title = last(r"MENU_TITLE name=(\S+) y=([0-9.]+) h=([0-9.]+)")
cutouts = re.findall(r"cutout\d+=(-?\d+),(-?\d+),(-?\d+),(-?\d+)", text)
lines = []
if safe is None:
    lines.append("safe=missing")
else:
    keys = ("safe_x", "safe_y", "safe_w", "safe_h", "cutouts", "window_w", "window_h", "screen_w", "screen_h")
    for key, value in zip(keys, safe):
        lines.append(f"{key}={value}")
if top is None:
    lines.append("top=missing")
else:
    lines.append(f"top_name={top[0]}")
    lines.append(f"top_y={top[1]}")
    lines.append(f"top_h={top[2]}")
    lines.append(f"top_x={top[3]}")
    lines.append(f"top_w={top[4]}")
if title is None:
    lines.append("title=missing")
else:
    lines.append(f"title_name={title[0]}")
    lines.append(f"title_y={title[1]}")
    lines.append(f"title_h={title[2]}")
for index, rect in enumerate(cutouts):
    lines.append("cutout%d=%s" % (index, ",".join(rect)))

under = "missing"
window_matches = "missing"
if safe is not None:
    window_w, window_h = int(safe[5]), int(safe[6])
    screen_w, screen_h = int(safe[7]), int(safe[8])
    if window_w <= 0 or screen_w <= 0:
        window_matches = "unknown"
    elif window_w == screen_w and window_h == screen_h:
        window_matches = "yes"
    else:
        window_matches = "no"
if safe is not None and top is not None:
    safe_y = int(safe[1])
    safe_h = int(safe[3])
    top_y = float(top[1])
    top_x = float(top[3])
    top_w = float(top[4])
    top_h = float(top[2])
    # Viewport y and the safe-area y are the same pixels when the window fills the screen.
    if safe_h <= 0 or window_matches != "yes":
        under = "unknown"
    else:
        # y grows downward. A control whose top is above safe_y is in the status-bar inset.
        overlaps_inset = top_y < safe_y
        overlaps_cutout = False
        for left, top_px, width, height in cutouts:
            cx, cy, cw, ch = (int(part) for part in (left, top_px, width, height))
            if top_x < cx + cw and top_x + top_w > cx and top_y < cy + ch and top_y + top_h > cy:
                overlaps_cutout = True
        under = "yes" if overlaps_inset or overlaps_cutout else "no"
lines.append(f"window_matches_screen={window_matches}")
lines.append("compare=viewport_y_against_safe_area_screen_y")
lines.append(f"menu_under_status_bar_or_cutout={under}")
Path(dest).write_text("\n".join(lines) + "\n", encoding="utf-8")
print("\n".join(lines))
PY

if grep -a -q 'MENU_SAFE safe_x=' "$out/logcat-live.txt" && grep -a -q 'MENU_TOP name=' "$out/logcat-live.txt"; then
  safe_ok=1
fi

if [[ -s "$out/edge-level1.png" ]] && python3 "$ROOT/tools/release/check_menu_screenshot.py" "$out/edge-level1.png"; then
  note "edge-level1.png is still the main menu"
elif [[ ! -s "$out/edge-level1.png" ]]; then
  note "edge-level1.png is missing"
else
  note "edge-level1.png is not the main menu"
fi

census_ok=0
if python3 - "$out/logcat-live.txt" << 'PY'
import re
import sys
text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
rows = re.findall(r"LEVEL1_CENSUS soldiers=(\d+) walkers=(\d+) gates=(\d+) time=([0-9.]+)", text)
if not rows:
    print("LEVEL1_CENSUS missing")
    raise SystemExit(1)
soldiers, walkers, gates, when = rows[-1]
print(f"LEVEL1_CENSUS last soldiers={soldiers} walkers={walkers} gates={gates} time={when}")
raise SystemExit(0 if int(soldiers) > 0 and int(walkers) > 0 and int(gates) > 0 else 1)
PY
then
  census_ok=1
fi

# Gameplay must replace the menu, and the census is the spawn count behind that frame.
if [[ "$census_ok" -eq 1 ]] && is_png "$out/edge-level1.png" && ! python3 "$ROOT/tools/release/check_menu_screenshot.py" "$out/edge-level1.png"; then
  level_ok=1
fi

if grep -a -E 'SCRIPT ERROR' "$out/logcat-live.txt"; then
  echo "logcat contains SCRIPT ERROR" >&2
  script_error=1
fi

adb logcat -d -b crash -v time | tr -d '\r' > "$out/crash.txt" || true
adb shell am force-stop "$package" || true

status=0
if [[ "$menu_ready" -ne 1 ]]; then
  echo "MENU_READY was not printed for the shipped-preset smoke APK" >&2
  status=1
fi
if ! grep -a -q 'MENU_ENGINE name=edge ' "$out/logcat-live.txt"; then
  echo "edge engine menu capture was not printed" >&2
  status=1
fi
if [[ "$menu_screencap_ok" -ne 1 ]]; then
  echo "edge-menu.png did not show the menu" >&2
  python3 "$ROOT/tools/release/check_menu_screenshot.py" "$out/edge-menu.png" || true
  status=1
fi
if [[ "$safe_ok" -ne 1 ]]; then
  echo "MENU_SAFE or MENU_TOP was not printed" >&2
  status=1
fi
if [[ "$level_ok" -ne 1 ]]; then
  echo "edge-level1.png did not show a started level (menu still up, or soldiers/walkers/gates missing)" >&2
  status=1
fi
if [[ "$script_error" -ne 0 ]]; then
  echo "logcat contains SCRIPT ERROR" >&2
  status=1
fi
if grep -a -E 'zombieblaster|godot|Godot' "$out/crash.txt"; then
  echo "crash buffer names the app (recorded; screencap is still the pass/fail check)" >&2
fi
exit "$status"
