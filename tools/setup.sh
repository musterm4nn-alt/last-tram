#!/usr/bin/env bash
# One-time setup after cloning: enables the pre-commit hook and builds Godot's cache.
set -uo pipefail
cd "$(dirname "$0")/.."
git config core.hooksPath .githooks
mkdir -p out
"${GODOT:-godot}" --headless --path . --import > out/import.log 2>&1
echo "Setup done: pre-commit hook enabled, Godot cache built. Try: tools/check.sh"
