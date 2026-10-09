#!/usr/bin/env bash
# Export the Android preset to a pck and boot it headless.
# Asserts the main menu is visible and level 1 spawns soldiers and walkers.
# This checks the packed project. It does not execute libgodot_android.so.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=release/common.sh
source "$ROOT/tools/release/common.sh"

ensure_godot

out="$ROOT/build/smoke"
mkdir -p "$out"
pck="$out/game.pck"
rm -f "$pck"

note "Exporting Android preset to $pck"
"$GODOT_BIN" --headless --path "$ROOT" --export-pack "Android" "$pck"
if [[ ! -s "$pck" ]]; then
  echo "Export did not produce $pck" >&2
  exit 1
fi
assert_project_data_packed "$pck" game

log="$(mktemp)"
trap 'rm -f "$log"' EXIT
set +e
"$GODOT_BIN" --headless --audio-driver Dummy --main-pack "$pck" -- --smoke-exported >"$log" 2>&1
status=$?
set -e
cat "$log"

if [[ "$status" -ne 0 ]]; then
  echo "Exported pack exited with status $status" >&2
  exit "$status"
fi

if grep -E "ERROR:|WARNING:|SCRIPT ERROR:" "$log"; then
  echo "Exported pack reported errors or warnings." >&2
  exit 1
fi

if ! grep -q "^SMOKE_MENU_OK$" "$log"; then
  echo "Exported pack did not show the main menu." >&2
  exit 1
fi

if ! grep -q "^SMOKE_LEVEL1_OK$" "$log"; then
  echo "Exported pack did not spawn level 1." >&2
  exit 1
fi

note "Exported pack showed the menu and spawned level 1."
