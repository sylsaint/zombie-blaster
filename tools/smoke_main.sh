#!/usr/bin/env bash
# Boot the main scene headless and fail if Godot reports an error or warning.
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

"$GODOT_BIN" --headless --path "$ROOT" --import

FRAMES="${FRAMES:-30}"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

set +e
"$GODOT_BIN" --headless --audio-driver Dummy --path "$ROOT" --quit-after "$FRAMES" >"$LOG" 2>&1
status=$?
set -e

cat "$LOG"

if [[ "$status" -ne 0 ]]; then
  echo "Main scene exited with status $status" >&2
  exit "$status"
fi

if grep -E "ERROR:|WARNING:|SCRIPT ERROR:" "$LOG"; then
  echo "Main scene reported errors or warnings." >&2
  exit 1
fi

echo "Main scene ran ${FRAMES} frames with no errors or warnings."
