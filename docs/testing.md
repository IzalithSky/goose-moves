# Testing Strategy

Headless, assertion-based test scenes under `tests/` (flat, one scene per
suite). The suite keeps the port honest along three axes: our math against the
Q3 source, the engine behaviors that math is built on, and the emergent
behavior of the assembled controller.

## Run

```sh
tests/run.sh        # all suites; exit 0 only if everything passes
HOME=/tmp XDG_DATA_HOME=/tmp "$GODOT_BIN" --headless --path . \
  --scene res://tests/test_q3_math.tscn --quit-after 4000   # one suite
```

Each suite prints one `ok` / `FAIL` / `xfail` line per check and quits with a
non-zero exit code on failure. `HOME=/tmp` keeps user config out of the run
(same convention as `CLAUDE.md`).

## Layers

| Suite | Layer | Breaks when |
|---|---|---|
| `test_q3_math.tscn` | Controller functions vs source-verified `bg_pmove.c` formulas and constants (no physics frames run) | movement math or unit conversion edited |
| `test_engine_assumptions.tscn` | Pins the `CharacterBody3D` facts the controller depends on (Godot 4.6.1 + Jolt), using a bare body — no controller code | a Godot upgrade changes `move_and_slide` / `apply_floor_snap` semantics |
| `test_controller_behavior.tscn` | The real controller scene on built fixtures, scripted input, multi-frame assertions | regressions in the per-frame pipeline |
| `test_platformer_math.tscn` | Polar math, action momentum, surface classes, unit conversion, and swim constants vs the reference | platformer math or unit conversion edited |
| `test_platformer_behavior.tscn` | Live platformer running, jump/landing, lava boost, and water transitions | platformer action pipeline regressions |
| `test_platformer_configuration.tscn` | Controller selection, independent settings/bindings/profiles, and playable fixtures | platformer integration or persistence regressions |

### Engine facts pinned by `test_engine_assumptions`

1. Grounded `move_and_slide()` **flattens `velocity.y`** whenever the body ends
   the call on the floor without moving up. With a renormalizing *pre-move*
   projection this costs exactly cos(slope) per frame — which is why the
   controller projects *after* `move_and_slide` using the pre-move magnitude.
2. `move_and_slide()` applies **no gravity, friction, or damping** of its own.
3. `apply_floor_snap()` grounds a *falling* body from anywhere within
   `floor_snap_length` **without clipping velocity** — followed by a
   renormalizing projection this converts fall speed into horizontal speed
   (the pre-fix landing-boost bug, kept pinned as a hazard).
4. A real-collision landing inside `move_and_slide()` clips velocity Q3-style
   (into-plane component removed, no renormalize).

## Known deviations (strict xfail)

`check_known_deviation()` marks Q3-correct assertions the port knowingly
fails. Strict semantics: when the deviation gets fixed the check XPASSes and
**fails the suite** until promoted to a hard `check()` — deviations can
neither linger silently nor get fixed silently.

There are currently no known deviations.

## Writing a test

- Extend `res://tests/q3_test.gd` (path-based `extends` — reliable headless),
  override `step()` (runs once per physics frame), call `finish()` when done.
- One scene per suite, named `tests/test_<name>.tscn`, script on the root
  node; the runner globs `tests/test_*.tscn`.
- Assert with `check` / `check_approx` / `check_vec3` /
  `check_known_deviation`. The base times out (and fails) after 900 physics
  frames.
- Build geometry in `_ready` via `add_static_box` (pass `slick = true` for ice)
  and `add_probe_body` for a bare controller-shaped body.
- Determinism rules: no rendering dependence, default 60 Hz physics, fixed
  fixture coordinates, drive input only via `Input.action_press/release`.

### Frame model (empirical, matters for sequencing)

- The test root is the controller's parent, so the test's `_physics_process`
  runs **before** the controller's each frame: velocity/position injected in
  `step()` are seen by the controller the same frame.
- `Input.action_press` updates `get_action_strength`/`is_action_pressed`
  immediately, but `is_action_just_pressed` fires on the **next** physics
  frame: press on frame N → the controller jumps on N+1 → assert on N+2.
  One grounded friction tick before a bhop jump is therefore harness latency,
  not controller behavior (the suite asserts it explicitly).

## Gaps / roadmap

- Water: level sampling, swim friction/accel, sink, water-jump arc (needs
  `Area3D` volume fixtures on collision layer 2; also pin that real Q3 applies
  gravity *twice* during a water jump — this port applies it once).
- Underwater slope walking still loses speed to the engine y-flatten (the
  water path has no post-move re-projection).
- Step-up geometry: partial steps under low ceilings, no air-stepping, the
  full-height pre-raise.
- CPM/extension modes once implemented (`q3-movement-extensions.md`).
