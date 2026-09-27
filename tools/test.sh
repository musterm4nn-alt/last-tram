#!/usr/bin/env bash
# Runs the tests headless (faster than tools/check.sh, which also re-imports).
# After ADDING new .gd files, run tools/check.sh instead so Godot learns the new class names.
# Usage: tools/test.sh [--filter=text]   (only tests whose "file :: name" contains text)
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
mkdir -p out
if [ ! -f .godot/global_script_class_cache.cfg ]; then
	"$GODOT" --headless --path . --import > out/import.log 2>&1
fi
"$GODOT" --headless --path . --script res://tests/runner.gd -- "$@" > out/test.log 2>&1
grep -v -E "^Godot Engine v|^$" out/test.log
if grep -q "^LAST_TRAM_TESTS: PASSED" out/test.log; then
	exit 0
fi
echo "TESTS FAILED (full output: out/test.log)"
exit 1
