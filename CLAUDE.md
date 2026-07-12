# Agent notes

Godot binary: `$GODOT_BIN`.

Run scenes headlessly to surface diagnostics: `HOME=/tmp XDG_DATA_HOME=/tmp "$GODOT_BIN" --headless --path . --scene res://scenes/<scene>.tscn --quit-after 2`.

Run tests with `tests/run.sh` (headless; see `docs/testing.md`). Run them after touching movement code.

Read `README.md` first. Then list `docs/`, `scripts/`, `scenes/`, `tests/` before touching code. These directories are flat by convention — no subdirectories.

Prefer `grep` for `@export`, `const`, and method signatures over reading whole files. Read full file bodies only when the signatures aren't enough.

Be as concise as possible.
