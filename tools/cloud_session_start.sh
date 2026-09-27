#!/usr/bin/env bash
# Claude Code SessionStart hook (see .claude/settings.json). Cloud sessions start from a
# fresh clone, so this runs tools/setup.sh there to switch the pre-commit check back on.
# Does nothing on your own machine, where you run tools/setup.sh once after cloning.
set -uo pipefail
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
	exit 0
fi
cd "$(dirname "$0")/.."
if command -v "${GODOT:-godot}" > /dev/null; then
	tools/setup.sh
else
	# No Godot yet (the environment's setup script installs it): still enable the hook.
	git config core.hooksPath .githooks
	echo "cloud_session_start: pre-commit hook enabled, but Godot is missing (tools/check.sh won't run)."
fi
exit 0
