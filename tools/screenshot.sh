#!/usr/bin/env bash
# Renders the game in a window, saves a PNG, and quits. Use it to SHOW that visual work
# looks right (open the PNG and look at it). Needs a display: it does not work headless.
#   tools/screenshot.sh                                   -> out/screenshot.png
#   tools/screenshot.sh out/walk.png --walk=1,0 --frames=90 --debug
# Game options (after the file name) are listed at the top of game/main.gd.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT="out/screenshot.png"
if [ $# -gt 0 ] && [[ "$1" != --* ]]; then
	OUT="$1"
	shift
fi
mkdir -p "$(dirname "$OUT")"
ABS="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"
rm -f "$ABS"
"$GODOT" --path . --resolution 1280x720 -- --screenshot="$ABS" "$@" > out/screenshot.log 2>&1
grep -E "SCRIPT ERROR|^ERROR" out/screenshot.log | head -10
if [ -f "$ABS" ]; then
	echo "Saved $OUT"
else
	echo "Screenshot failed (full output: out/screenshot.log)"
	exit 1
fi
