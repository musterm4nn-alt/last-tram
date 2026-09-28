#!/usr/bin/env bash
# Replays a bug report folder headless and checks it reproduces the end save exactly.
#   tools/replay.sh <folder with start.json, commands.json, end.json>
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p out
FOLDER="${1:-}"
if [ -n "$FOLDER" ] && [ -d "$FOLDER" ]; then
	FOLDER="$(cd "$FOLDER" && pwd)"
fi
"${GODOT:-godot}" --headless --path . --script res://tools/replay.gd -- "$FOLDER" > out/replay.log 2>&1
grep -v -E "^Godot Engine v|^$" out/replay.log
grep -q "^LAST_TRAM_REPLAY: OK" out/replay.log
