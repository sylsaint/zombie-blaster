#!/usr/bin/env bash
# Run the crowd stress scene headless for N frames and fail on errors,
# a missing stats line, or draw batches that grow from 50 to 300 enemies.
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

FRAMES="${FRAMES:-120}"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

set +e
"$GODOT_BIN" --headless --audio-driver Dummy --path "$ROOT" \
  res://scenes/debug/stress_test.tscn -- --frames="$FRAMES" >"$LOG" 2>&1
status=$?
set -e

cat "$LOG"

if [[ "$status" -ne 0 ]]; then
  echo "Stress scene exited with status $status" >&2
  exit "$status"
fi

if grep -E "ERROR:|WARNING:|SCRIPT ERROR:" "$LOG"; then
  echo "Stress scene reported errors or warnings." >&2
  exit 1
fi

stats="$(grep -E '^STRESS_STATS ' "$LOG" | tail -1 || true)"
if [[ -z "$stats" ]]; then
  echo "Stress scene did not print STRESS_STATS." >&2
  exit 1
fi

value() {
  sed -n "s/.*$1=\\([0-9.][0-9.]*\\).*/\\1/p" <<<"$stats"
}

batches_50="$(value batches_50)"
batches_300="$(value batches_300)"
instances_50="$(value instances_50)"
instances_300="$(value instances_300)"
enemies="$(value enemies)"

if [[ -z "$batches_50" || -z "$batches_300" || "$batches_50" == "0" || "$batches_50" != "$batches_300" ]]; then
  echo "Draw batches are not stable across 50 and 300 enemies: $stats" >&2
  exit 1
fi

gpu_50="$(value gpu_draw_50)"
gpu_300="$(value gpu_draw_300)"
# Headless dummy renderer reports 0 for both, so that path stays unchecked.
# A real GL device draws the low-poly MultiMeshes only once the crowd exceeds
# the nearest-100 budget, which is a fixed +2, not a per-enemy climb.
if [[ -n "$gpu_50" && -n "$gpu_300" && "$gpu_50" != "0" && "$gpu_300" != "0" ]]; then
  python3 - "$gpu_50" "$gpu_300" <<'PY'
import sys
a, b = float(sys.argv[1]), float(sys.argv[2])
if abs(b - a) > 8:
    raise SystemExit("GPU draw calls grew by more than 8 from 50 to 300 enemies: %s vs %s" % (sys.argv[1], sys.argv[2]))
PY
fi

python3 - "$instances_50" "$instances_300" "$enemies" <<'PY'
import sys
i50, i300, enemies = (float(v) for v in sys.argv[1:4])
if i300 <= i50:
    raise SystemExit("visible instances did not grow from 50 to 300")
if enemies != 304:
    raise SystemExit("expected 304 active enemies, got %s" % enemies)
PY

logic_avg="$(value logic_avg_ms)"
# Packed-grid combat on this project is about 1 ms/frame headless.
# 20 ms still catches a multi-times regression and leaves room for a slow CI host.
if [[ -z "$logic_avg" ]]; then
  echo "Stress scene did not report logic_avg_ms: $stats" >&2
  exit 1
fi
python3 - "$logic_avg" <<'PY'
import sys
ms = float(sys.argv[1])
if ms > 20.0:
    raise SystemExit("headless logic_avg_ms %.3f exceeds 20" % ms)
PY

echo "Stress scene ran ${FRAMES} benchmark frames. ${stats}"
