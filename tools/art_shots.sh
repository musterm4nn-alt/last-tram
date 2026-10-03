#!/usr/bin/env bash
# Shoots the art gate's scene (the Altmarkt and Haus 12) at noon and at 22:00, from the same
# camera every time, drawn with one art set, so sets can be compared side by side (T-0084).
#   tools/art_shots.sh placeholder        -> out/art/placeholder/{noon,night,noon-close,night-close}.png
#   tools/art_shots.sh kenney out/try     -> out/try/...
# "placeholder" (or any set without a data/art2d file) draws the placeholders.
set -uo pipefail
cd "$(dirname "$0")/.."
SET="${1:?usage: tools/art_shots.sh <set> [out_dir]}"
OUT="${2:-out/art/$SET}"
# A new game starts on Monday at 08:00 (SimFactory), so:
NOON=$((12 * 60 - 8 * 60))
NIGHT=$((22 * 60 - 8 * 60))
echo "noon: --advance=$NOON, night: --advance=$NIGHT"
ART=(--art=placeholder)
if [ -f "data/art2d/$SET.json" ]; then
	ART=(--art="$SET")
fi
COMMON=(--seed=1 --hide-hud --paused --frames=30)
status=0
shoot() {
	tools/screenshot.sh "$OUT/$1.png" "${COMMON[@]}" ${ART[@]+"${ART[@]}"} --advance="$2" --look-at="$3" --zoom="$4" || status=1
}
shoot noon "$NOON" 40,26 1
shoot night "$NIGHT" 40,26 1
shoot noon-close "$NOON" 52,28 2
shoot night-close "$NIGHT" 52,28 2
exit $status
