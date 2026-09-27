#!/usr/bin/env bash
# THE check. Must pass before every commit (the git pre-commit hook runs it).
#   1. Imports the project: refreshes Godot's class cache and creates .uid files for new
#      scripts (commit those .uid files too).
#   2. Runs every test, including the lint tests that guard the architecture rules.
# Usage: tools/check.sh [--filter=text]
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
mkdir -p out
if ! "$GODOT" --headless --path . --import > out/import.log 2>&1; then
	echo "check: Godot import failed. Last lines of out/import.log:"
	tail -20 out/import.log
	exit 1
fi
exec tools/test.sh "$@"
