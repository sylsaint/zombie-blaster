#!/usr/bin/env bash
# Windowed OpenGL capture of level 1 after the menu is tapped through.
# Headless GUT does not draw the crowd, so this run needs a display.
# xvfb-run is used when DISPLAY is unset.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -n "${GODOT:-}" ]]; then
  GODOT_BIN="$GODOT"
elif command -v godot >/dev/null 2>&1; then
  GODOT_BIN="$(command -v godot)"
elif command -v godot4 >/dev/null 2>&1; then
  GODOT_BIN="$(command -v godot4)"
else
  echo "Godot 4.7.2 not found. Install it and set GODOT=/path/to/godot." >&2
  exit 127
fi

OUT="${1:-$ROOT/docs/qa/screens/level1.png}"
mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

godot_cmd=(
  "$GODOT_BIN" --path "$ROOT" --rendering-method gl_compatibility
  --display-driver x11 --audio-driver Dummy
  -- --level1-shot="$OUT"
)

set +e
if [[ -n "${DISPLAY:-}" ]]; then
  "${godot_cmd[@]}" >"$LOG" 2>&1
else
  xvfb-run -a -s "-screen 0 540x960x24" "${godot_cmd[@]}" >"$LOG" 2>&1
fi
status=$?
set -e

cat "$LOG"

if [[ "$status" -ne 0 ]]; then
  echo "Level 1 capture exited with status $status" >&2
  exit "$status"
fi

# llvmpipe under xvfb cannot change V-Sync. That driver note is not a game fault.
if grep -E "ERROR:|WARNING:|SCRIPT ERROR:" "$LOG" | grep -v "Could not set V-Sync mode"; then
  echo "Level 1 capture reported errors or warnings." >&2
  exit 1
fi

if ! grep -q "^LEVEL1_SHOT " "$LOG"; then
  echo "Level 1 capture did not print LEVEL1_SHOT." >&2
  exit 1
fi

if [[ ! -s "$OUT" ]]; then
  echo "Screenshot was not written to $OUT" >&2
  exit 1
fi

echo "Wrote $OUT"
