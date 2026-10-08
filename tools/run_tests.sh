#!/usr/bin/env bash
# Import the project and run GUT headless. Exits 0 only when every test passes.
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

echo "Using $GODOT_BIN"
"$GODOT_BIN" --version

"$GODOT_BIN" --headless --path "$ROOT" --import
"$GODOT_BIN" --headless --audio-driver Dummy --path "$ROOT" \
  -s res://addons/gut/gut_cmdln.gd -gexit -gdisable_colors
