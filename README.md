# goose-moves

Godot project for comparing and tuning action-game movement mechanics — arena-shooter-style (VQ3/CPMA) and collectathon-platformer-style, and others — side by side, with an eye toward combining the best pieces into one controller.

Development is AI-assisted.

## License

This project is licensed under the GNU General Public License version 3 only (`GPL-3.0-only`). See [LICENSE](LICENSE).

## Layout

- `docs/` — movement research notes (source-verified where possible) and the testing strategy
- `scripts/` — GDScript
- `scenes/` — Godot scenes
- `tests/` — headless regression tests; run with `tests/run.sh` (see `docs/testing.md`)
- `references/` — cloned upstream open-source engines/decompilations used for research; gitignored and Godot-ignored; for reading only, not part of the build

Project directories are kept flat — no subdirectories inside `docs/`, `scripts/`, `scenes/`, or `tests/`.
