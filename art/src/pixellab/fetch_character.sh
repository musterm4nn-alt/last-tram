#!/usr/bin/env bash
# PixelLab test: downloads a finished PixelLab character (rotations, walk, idle) into
# art/src/pixellab/raw/<name>/ as <dir>_<n>.png (walk), <dir>_idle_<n>.png and <dir>_rot.png.
#   art/src/pixellab/fetch_character.sh <character id> <name>
set -euo pipefail
cd "$(dirname "$0")"
ID="$1"; NAME="$2"
TMP="$(mktemp -d)"
curl -sfL -o "$TMP/c.zip" "https://api.pixellab.ai/mcp/characters/$ID/download"
unzip -q -o "$TMP/c.zip" -d "$TMP/c"
OUT="raw/$NAME"; mkdir -p "$OUT"
STATE="$(find "$TMP/c" -mindepth 1 -maxdepth 1 -type d | head -1)"
for d in south east north west; do
	cp "$STATE/rotations/$d.png" "$OUT/${d}_rot.png"
	for f in 0 1 2 3; do
		[ -f "$STATE/animations/walk/$d/frame_00$f.png" ] && cp "$STATE/animations/walk/$d/frame_00$f.png" "$OUT/${d}_$f.png"
		[ -f "$STATE/animations/idle/$d/frame_00$f.png" ] && cp "$STATE/animations/idle/$d/frame_00$f.png" "$OUT/${d}_idle_$f.png"
	done
done
cp "$STATE/../metadata.json" "$OUT/metadata.json" 2>/dev/null || true
rm -rf "$TMP"
ls "$OUT" | wc -l
