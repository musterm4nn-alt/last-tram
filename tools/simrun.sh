#!/usr/bin/env bash
# Runs the simulation headless (no graphics) and prints a report. Examples:
#   tools/simrun.sh --days=1 --seed=1
#   tools/simrun.sh --minutes=90 --walk=1,0 --report-every=10
#   tools/simrun.sh --days=3                 # needs summary + action counts, free will on
#   tools/simrun.sh --days=1 --no-free-will  # contrast: needs fall with free will off
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p out
"${GODOT:-godot}" --headless --path . --script res://tools/sim_runner.gd -- "$@" > out/simrun.log 2>&1
grep -v -E "^Godot Engine v|^$" out/simrun.log
grep -q "^LAST_TRAM_SIMRUN: OK" out/simrun.log
