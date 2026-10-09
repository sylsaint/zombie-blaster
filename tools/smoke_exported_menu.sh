#!/usr/bin/env bash
# Export the Android preset to a pck (same filters as the release APK) and
# boot that pack, not the project folder. Fail unless the main menu is
# visible with a non-zero rect. This is the check the project-folder smoke
# missed: a theme that loads but draws nothing, or a menu laid out at 0x0.
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

PACK="$ROOT/build/exported-menu.pck"
LOG="$(mktemp)"
mkdir -p "$ROOT/build"
rm -f "$PACK"
trap 'rm -f "$LOG"' EXIT

"$GODOT_BIN" --headless --path "$ROOT" --import
"$GODOT_BIN" --headless --path "$ROOT" --export-pack "Android" "$PACK"

if [[ ! -s "$PACK" ]]; then
  echo "Android export-pack did not produce $PACK" >&2
  exit 1
fi

set +e
"$GODOT_BIN" --headless --audio-driver Dummy \
  --resolution 1080x1920 \
  --main-pack "$PACK" \
  -s "$ROOT/tools/check_exported_menu.gd" >"$LOG" 2>&1
status=$?
set -e

cat "$LOG"

if [[ "$status" -ne 0 ]]; then
  echo "Exported pack exited with status $status" >&2
  exit "$status"
fi

if ! grep -q "EXPORTED_MENU_OK" "$LOG"; then
  echo "Exported pack did not report EXPORTED_MENU_OK" >&2
  exit 1
fi

if ! grep -q "UI_VIS fallback=false" "$LOG"; then
  echo "Exported pack fell back off the project theme, or did not log UI_VIS." >&2
  exit 1
fi

if grep -E "ERROR:|WARNING:|SCRIPT ERROR:" "$LOG"; then
  echo "Exported pack reported errors or warnings." >&2
  exit 1
fi

echo "Exported Android pack showed the main menu."
