#!/usr/bin/env bash
# Install arm64 release APKs on the arm64 emulator and keep the logs.
# LAUNCH_MODE=published installs the GitHub Release APKs (v0.1.1 fresh, then
# v0.1.0, tap 开始, upgrade to v0.1.1). LAUNCH_MODE=variants installs the
# three control packages. An app crash is a result, not a harness failure.
# A missing APK, a failed fresh install, or a missing log file fails the job.
set -uo pipefail

ROOT="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
API="${EMULATOR_API:-unknown}"
MODE="${LAUNCH_MODE:-all}"
out="$ROOT/build/arm64-launch/api${API}-${MODE}"
mkdir -p "$out"
harness_fail=0

note() {
  printf '%s\n' "$*"
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    printf '%s\n' "$*" >> "$GITHUB_STEP_SUMMARY"
  fi
}

fail_harness() {
  note "HARNESS $*"
  printf '%s\n' "$*" >&2
  harness_fail=1
}

require_file() {
  local path="$1"
  if [[ ! -s "$path" ]]; then
    fail_harness "missing $path"
  fi
}

sha256_file() {
  python3 -c 'import hashlib, pathlib, sys; p = pathlib.Path(sys.argv[1]); print(hashlib.sha256(p.read_bytes()).hexdigest(), p.name)' "$1"
}

# macOS find has no -quit, and head on a live find pipe trips pipefail.
find_apk() {
  python3 -c 'import pathlib, sys
root, pattern = sys.argv[1], sys.argv[2]
base = pathlib.Path(root)
if not base.exists():
    raise SystemExit(0)
for path in base.rglob(pattern):
    if path.is_file():
        print(path)
        break
' "$1" "$2"
}

tool_path() {
  local name="$1"
  if [[ -n "${ANDROID_HOME:-}" && -d "$ANDROID_HOME/build-tools" ]]; then
    find "$ANDROID_HOME/build-tools" -type f -name "$name" | sort | tail -n 1
  fi
}

write_excerpt() {
  local dir="$1"
  python3 - "$dir" << 'PY'
import pathlib, sys
directory = pathlib.Path(sys.argv[1])
crash = directory.joinpath("logcat-crash.txt").read_text(errors="replace") if directory.joinpath("logcat-crash.txt").is_file() else ""
main = directory.joinpath("logcat-all.txt").read_text(errors="replace") if directory.joinpath("logcat-all.txt").is_file() else ""
lines = main.splitlines()
keys = (
    "FATAL EXCEPTION",
    "Fatal signal",
    "backtrace",
    "DEBUG   ",
    "beginning of crash",
    "Force quitting Godot",
    "!_start_success",
    "MENU_READY",
    "MENU_NO_SQUAD",
    "SAVE_SKIPPED",
    "InitEngine",
    "SIGSEGV",
    "SIGABRT",
    "AndroidRuntime",
    "libc    : Fatal",
)
picked = []
i = 0
while i < len(lines):
    line = lines[i]
    hit = any(key in line for key in keys)
    if hit:
        start = i
        end = min(len(lines), i + 80)
        # Keep a crash block together. Marker lines stay as a single line.
        if not any(token in line for token in ("Fatal signal", "FATAL EXCEPTION", "backtrace", "beginning of crash", "DEBUG")):
            end = i + 1
        block = lines[start:end]
        picked.extend(block)
        if end > i + 1:
            picked.append("")
        i = end
        continue
    i += 1
tomb_lines = []
for path in sorted(directory.rglob("tombstone*")):
    if not path.is_file() or "tombstone-pull" not in path.parts:
        continue
    text = path.read_text(errors="replace")
    tomb_lines.append(f"===== {path.name} =====")
    tomb_lines.append(text[:20000])
parts = ["===== logcat -b crash =====", crash.rstrip(), ""]
if picked:
    parts.append("===== logcat excerpt =====")
    parts.extend(picked)
else:
    parts.append("===== logcat excerpt =====")
    parts.append("(no Fatal signal, Java exception, or menu marker in the main log)")
if tomb_lines:
    parts.append("")
    parts.extend(tomb_lines)
directory.joinpath("crash-excerpt.txt").write_text("\n".join(parts) + "\n")
PY
}

summarize() {
  local name="$1"
  local dir="$out/$name"
  local crash="no" ready="no" nosquad="no" skipped="no"
  if [[ -f "$dir/logcat-all.txt" ]] && grep -a -q -E 'Fatal signal|FATAL EXCEPTION' "$dir/logcat-all.txt"; then
    crash="yes"
  fi
  if [[ -f "$dir/logcat-crash.txt" ]] && grep -a -q -E 'Fatal signal|FATAL EXCEPTION|DEBUG' "$dir/logcat-crash.txt"; then
    crash="yes"
  fi
  if [[ -f "$dir/logcat-all.txt" ]] && grep -a -q 'MENU_READY' "$dir/logcat-all.txt"; then
    ready="yes"
  fi
  if [[ -f "$dir/logcat-all.txt" ]] && grep -a -q 'MENU_NO_SQUAD' "$dir/logcat-all.txt"; then
    nosquad="yes"
  fi
  if [[ -f "$dir/logcat-all.txt" ]] && grep -a -q 'SAVE_SKIPPED' "$dir/logcat-all.txt"; then
    skipped="yes"
  fi
  local retry="no"
  if [[ -f "$dir/crash-excerpt-attempt1.txt" ]]; then
    retry="yes"
  fi
  local line="${name}: ready=${ready} crash=${crash} menu_no_squad=${nosquad} save_skipped=${skipped} retried=${retry}"
  printf '%s\n' "$line" >> "$out/summary.txt"
  note "$line"
}

dump_capture() {
  local dir="$1"
  adb logcat -d -b all -v threadtime > "$dir/logcat-all.txt" || true
  adb logcat -d -b crash -v threadtime > "$dir/logcat-crash.txt" || true
  if [[ ! -s "$dir/logcat-crash.txt" ]]; then
    printf '%s\n' "(crash buffer empty)" > "$dir/logcat-crash.txt"
  fi
  adb exec-out screencap -p > "$dir/screen.png" || true
  adb shell 'ls -l /data/tombstones 2>/dev/null || echo NO_TOMBSTONES' > "$dir/tombstones.txt" || true
  mkdir -p "$dir/tombstone-pull"
  adb pull /data/tombstones "$dir/tombstone-pull" >/dev/null 2>&1 || true
  write_excerpt "$dir"
}

wait_session() {
  local pkg="$1" dir="$2" marker="$3"
  local i pid seen=0 stable=0 ready=0 died=0 flake=0
  : > "$dir/poll-crash.txt"
  : > "$dir/poll-godot.txt"
  for i in $(seq 1 40); do
    adb logcat -d -b crash -v time > "$dir/poll-crash.txt" || true
    adb logcat -d -v time -s godot:V Godot:V AndroidRuntime:E libc:F DEBUG:I > "$dir/poll-godot.txt" || true
    if [[ -n "$marker" ]] && grep -a -F -q "$marker" "$dir/poll-godot.txt"; then
      ready=1
      break
    fi
    if grep -a -q -E 'Fatal signal|FATAL EXCEPTION' "$dir/poll-crash.txt"; then
      died=1
      break
    fi
    if grep -a -q -E 'Fatal signal|FATAL EXCEPTION' "$dir/poll-godot.txt"; then
      died=1
      break
    fi
    pid="$(adb shell pidof "$pkg" 2>/dev/null | tr -d '\r' || true)"
    if [[ -n "$pid" ]]; then
      seen=1
      stable=$((stable + 1))
    elif [[ "$seen" -eq 1 ]]; then
      died=1
      if grep -a -q -E 'Force quitting Godot|!_start_success|CONFIG_ASSETS_PATHS' "$dir/poll-godot.txt"; then
        flake=1
      fi
      break
    fi
    if [[ -z "$marker" && "$stable" -ge 6 ]]; then
      ready=1
      break
    fi
    sleep 2
  done
  printf 'ready=%s died=%s flake=%s stable=%s\n' "$ready" "$died" "$flake" "$stable" > "$dir/wait.txt"
}

launch_package() {
  local name="$1" pkg="$2" marker="$3"
  local dir="$out/$name"
  mkdir -p "$dir"
  local attempt
  for attempt in 1 2; do
    adb shell am force-stop "$pkg" >/dev/null 2>&1 || true
    sleep 1
    adb logcat -b all -c >/dev/null 2>&1 || true
    adb shell am start -n "${pkg}/com.godot.game.GodotAppLauncher" > "$dir/am-start.txt" 2>&1 || true
    wait_session "$pkg" "$dir" "$marker"
    dump_capture "$dir"
    local flake="0" died="0"
    if [[ -f "$dir/wait.txt" ]]; then
      flake="$(sed -n 's/.*flake=\([0-9]\).*/\1/p' "$dir/wait.txt")"
      died="$(sed -n 's/.*died=\([0-9]\).*/\1/p' "$dir/wait.txt")"
    fi
    if [[ "$attempt" -eq 1 && "$died" == "1" && "$flake" == "1" ]]; then
      note "$name startup flake; keeping attempt 1 and launching once more"
      cp "$dir/logcat-all.txt" "$dir/logcat-all-attempt1.txt" || true
      cp "$dir/logcat-crash.txt" "$dir/logcat-crash-attempt1.txt" || true
      cp "$dir/screen.png" "$dir/screen-attempt1.png" || true
      cp "$dir/crash-excerpt.txt" "$dir/crash-excerpt-attempt1.txt" || true
      continue
    fi
    break
  done
  require_file "$dir/logcat-all.txt"
  require_file "$dir/logcat-crash.txt"
  require_file "$dir/crash-excerpt.txt"
  if [[ ! -s "$dir/screen.png" ]]; then
    fail_harness "$name screenshot is empty"
  fi
  summarize "$name"
}

install_apk() {
  local apk="$1" log="$2"
  if adb install -r "$apk" >"$log" 2>&1; then
    printf '\nINSTALL_OK\n' >> "$log"
    return 0
  fi
  printf '\nINSTALL_FAIL\n' >> "$log"
  return 1
}

list_files() {
  local pkg="$1" dir="$2"
  adb shell "ls -laR /data/data/${pkg}/files /data/data/${pkg}/cache" > "$dir/files.txt" 2>&1 || true
  adb pull "/data/data/${pkg}/files/save.json" "$dir/save.json" >/dev/null 2>&1 || true
}

map_taps() {
  local size_text screen_w="" screen_h=""
  size_text="$(adb shell wm size | tr -d '\r')"
  printf '%s\n' "$size_text" > "$out/wm-size.txt"
  if [[ "$size_text" =~ Override\ size:\ ([0-9]+)x([0-9]+) ]]; then
    screen_w="${BASH_REMATCH[1]}"
    screen_h="${BASH_REMATCH[2]}"
  elif [[ "$size_text" =~ Physical\ size:\ ([0-9]+)x([0-9]+) ]]; then
    screen_w="${BASH_REMATCH[1]}"
    screen_h="${BASH_REMATCH[2]}"
  fi
  if [[ -z "$screen_w" || -z "$screen_h" ]]; then
    fail_harness "could not read emulator resolution"
    tap_play_x=540
    tap_play_y=1698
    return
  fi
  read -r tap_play_x tap_play_y < <(python3 -c "
design_w, design_h = 1080, 1920
screen_w, screen_h = $screen_w, $screen_h
dx, dy = 540, 1698
scale = screen_w / design_w
offset_y = (screen_h - design_h * scale) / 2.0
x = max(0, min(screen_w - 1, int(round(dx * scale))))
y = max(0, min(screen_h - 1, int(round(offset_y + dy * scale))))
print(x, y)
")
  note "开始 tap ${tap_play_x},${tap_play_y} on ${screen_w}x${screen_h}"
}

run_published() {
  local releases="$ROOT/dist/releases"
  local v011 v010
  v011="$(find_apk "$releases" 'zombie-blaster-v0.1.1-android-release.apk')"
  v010="$(find_apk "$releases" 'zombie-blaster-v0.1.0-android-release.apk')"
  if [[ -z "$v011" || -z "$v010" ]]; then
    fail_harness "published release APKs are missing under dist/releases"
    return
  fi
  {
    sha256_file "$v011"
    sha256_file "$v010"
  } > "$out/apk-sha256.txt"
  note "v0.1.1 $(sed -n '1p' "$out/apk-sha256.txt")"
  note "v0.1.0 $(sed -n '2p' "$out/apk-sha256.txt")"
  local expect_v011="2a5406b26cbe5b294a0601bd7a9a651a2aa0804ea0ceefe086e8821d8ed2d029"
  if [[ "$(awk 'NR==1 { print $1 }' "$out/apk-sha256.txt")" != "$expect_v011" ]]; then
    fail_harness "v0.1.1 APK sha256 does not match the published release asset"
  fi
  local aapt apksigner
  aapt="$(tool_path aapt || true)"
  apksigner="$(tool_path apksigner || true)"
  if [[ -n "$aapt" ]]; then
    "$aapt" dump badging "$v010" > "$out/badging-v010.txt" || true
    "$aapt" dump badging "$v011" > "$out/badging-v011.txt" || true
  fi
  if [[ -n "$apksigner" ]]; then
    {
      echo "===== v0.1.0 ====="
      "$apksigner" verify --print-certs "$v010" || true
      echo "===== v0.1.1 ====="
      "$apksigner" verify --print-certs "$v011" || true
    } > "$out/certs.txt"
  fi

  local pkg="com.zombieblaster.game"
  adb uninstall "$pkg" > "$out/uninstall-before-fresh.txt" 2>&1 || true
  mkdir -p "$out/a-fresh-v011"
  if install_apk "$v011" "$out/a-fresh-v011/install.txt"; then
    launch_package a-fresh-v011 "$pkg" "MENU_READY"
    list_files "$pkg" "$out/a-fresh-v011"
  else
    fail_harness "fresh install of v0.1.1 failed"
  fi

  adb uninstall "$pkg" > "$out/uninstall-before-v010.txt" 2>&1 || true
  mkdir -p "$out/b-v010-menu"
  if install_apk "$v010" "$out/b-v010-menu/install.txt"; then
    launch_package b-v010-menu "$pkg" ""
    if [[ -f "$out/b-v010-menu/wait.txt" ]] && grep -q 'died=0' "$out/b-v010-menu/wait.txt"; then
      adb shell input tap "$tap_play_x" "$tap_play_y" || true
      sleep 6
      adb exec-out screencap -p > "$out/b-v010-menu/screen-after-play.png" || true
      adb logcat -d -b all -v threadtime > "$out/b-v010-menu/logcat-after-play.txt" || true
    else
      note "b-v010-menu was not alive, so 开始 was not tapped"
    fi
    list_files "$pkg" "$out/b-v010-menu"
    adb shell am force-stop "$pkg" >/dev/null 2>&1 || true
  else
    fail_harness "install of v0.1.0 failed"
  fi

  mkdir -p "$out/b-upgrade-v011"
  if install_apk "$v011" "$out/b-upgrade-v011/install.txt"; then
    note "upgrade install of v0.1.1 succeeded"
  else
    note "upgrade install of v0.1.1 failed; launching whatever package is still installed"
  fi
  launch_package b-upgrade-v011 "$pkg" "MENU_READY"
  list_files "$pkg" "$out/b-upgrade-v011"
}

run_variants() {
  local id apk pkg
  for id in nosquad immersive nosave; do
    apk="$(find_apk "$ROOT/dist/variants" "*-android-${id}.apk")"
    pkg="com.zombieblaster.game.${id}"
    local dir="$out/c-${id}"
    if [[ "$id" == "immersive" ]]; then
      dir="$out/d-immersive"
    elif [[ "$id" == "nosave" ]]; then
      dir="$out/e-nosave"
    fi
    mkdir -p "$dir"
    if [[ -z "$apk" ]]; then
      fail_harness "missing ${id} variant APK"
      continue
    fi
    sha256_file "$apk" > "$dir/apk-sha256.txt"
    note "${id} $(cat "$dir/apk-sha256.txt")"
    adb uninstall "$pkg" > "$dir/uninstall.txt" 2>&1 || true
    if install_apk "$apk" "$dir/install.txt"; then
      local name
      name="$(basename "$dir")"
      launch_package "$name" "$pkg" "MENU_READY"
      list_files "$pkg" "$dir"
    else
      fail_harness "install of ${id} failed"
    fi
  done
}

note "arm64 launch smoke api=${API} mode=${MODE}"
adb wait-for-device
adb root > "$out/adb-root.txt" 2>&1 || true
sleep 2
adb wait-for-device
{
  echo "sdk=$(adb shell getprop ro.build.version.sdk | tr -d '\r')"
  echo "release=$(adb shell getprop ro.build.version.release | tr -d '\r')"
  echo "abi=$(adb shell getprop ro.product.cpu.abi | tr -d '\r')"
  echo "model=$(adb shell getprop ro.product.model | tr -d '\r')"
} > "$out/device.txt"
note "$(tr '\n' ' ' < "$out/device.txt")"
if ! grep -q 'abi=arm64-v8a' "$out/device.txt"; then
  fail_harness "emulator abi is not arm64-v8a"
fi

tap_play_x=540
tap_play_y=1698
map_taps

case "$MODE" in
  published) run_published ;;
  variants) run_variants ;;
  all) run_published; run_variants ;;
  *) fail_harness "unknown LAUNCH_MODE=$MODE" ;;
esac

if [[ -f "$out/summary.txt" ]]; then
  note "----- summary -----"
  while IFS= read -r line; do
    note "$line"
  done < "$out/summary.txt"
fi

if [[ "$harness_fail" -ne 0 ]]; then
  note "harness failed"
  exit 1
fi
note "harness finished. An app crash is in summary.txt and does not fail this step."
