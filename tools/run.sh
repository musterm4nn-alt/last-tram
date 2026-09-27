#!/usr/bin/env bash
# Starts the game in a window. Game options go after it, for example:
#   tools/run.sh --seed=7 --debug
# (All options are listed at the top of game/main.gd.)
cd "$(dirname "$0")/.."
exec "${GODOT:-godot}" --path . -- "$@"
