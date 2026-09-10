#!/bin/zsh
# Builds the app against a local Flutter engine and toggles native fullscreen
# every 2.5 s for DURATION seconds, capturing engine stderr.
#
#   ./run_repro.sh <engine/src path> [variant=host_debug_unopt_arm64] [duration=300]
#
# Grep the log for:
#   "The texture and its descriptor disagree about its size."  (Impeller validation, debug engine)
#   "Could not wrap embedder supplied Metal render texture"      (fixed engine: layer skipped, no crash)
set -euo pipefail
ENGINE_SRC=${1:?engine/src path}
VARIANT=${2:-host_debug_unopt_arm64}
DURATION=${3:-300}
FLUTTER="$ENGINE_SRC/../../bin/flutter"
LOG="logs/run_$(date +%Y%m%d_%H%M%S).txt"
mkdir -p logs
"$FLUTTER" build macos --debug --local-engine="$VARIANT" --local-engine-host="$VARIANT" --local-engine-src-path "$ENGINE_SRC"
APP=build/macos/Build/Products/Debug/fullscreen_repro.app/Contents/MacOS/fullscreen_repro
"$APP" > "$LOG" 2>&1 &
PID=$!
sleep "$DURATION"
if kill -0 "$PID" 2>/dev/null; then ALIVE=yes; else ALIVE=no; fi
kill "$PID" 2>/dev/null || true
sleep 2
echo "log: $LOG"
echo "toggles: $(grep -c 'REPRO toggleFullScreen' "$LOG")"
echo "size-mismatch validation lines: $(grep -c 'disagree about its size' "$LOG")"
echo "graceful skips (fixed engine): $(grep -c 'Could not wrap embedder supplied Metal render texture' "$LOG")"
if [ "$ALIVE" = yes ]; then echo "app still running at kill time (no crash)"; else echo "app exited before kill (check ~/Library/Logs/DiagnosticReports)"; fi
