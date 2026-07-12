#!/usr/bin/env bash
# Headless test runner: every tests/test_*.tscn is one suite (see docs/testing.md).
# Requires $GODOT_BIN (see CLAUDE.md). Exits non-zero if any suite fails.
set -u
cd "$(dirname "$0")/.."
status=0
for scene in tests/test_*.tscn; do
	echo "=== ${scene}"
	HOME=/tmp XDG_DATA_HOME=/tmp "${GODOT_BIN:?GODOT_BIN is not set}" \
		--headless --path . --scene "res://${scene}" --quit-after 4000 || status=1
done
exit ${status}
