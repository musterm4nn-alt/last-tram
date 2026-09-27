#!/usr/bin/env bash
# Creates tests/fixtures/saves/<name>.json with the current save version.
# Usage: tools/make_fixture_save.sh [name]     (default: v<SAVE_VERSION>_basic)
set -uo pipefail
cd "$(dirname "$0")/.."
ARGS=()
if [ $# -gt 0 ]; then ARGS+=("--name=$1"); fi
"${GODOT:-godot}" --headless --path . --script res://tools/make_fixture_save.gd -- "${ARGS[@]+"${ARGS[@]}"}" 2>&1 | grep -v "^Godot Engine"
