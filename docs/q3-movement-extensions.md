# Q3 Movement — Extensions over VQ3 (CPMA, QC, slides)

Extends [q3-movement.md](q3-movement.md). Everything here is framed as **how each mode layers over or replaces a specific VQ3 math piece** — nothing throws the VQ3 core away.

**Confidence:** VQ3 pieces are source-verified (see base doc). CPM's air-control operator and constants are source-verified against the **Warsow/qfusion `GS_CLASSICBUNNY` reimplementation** at `references/warsow` revision `cc22b709` (CPMA itself is closed-source). QC is **behavioral inference** (closed-source; community-reported, patch-sensitive). Slide behavior is from Q4/QC docs + community, not code. Treat CPM/QC numbers as canonical-reimplementation values, not ground truth.

## The VQ3 pieces you extend

From the base doc, the swappable surface is small:

- **`Friction`** — ground only, scale-toward-zero with the stopspeed floor.
- **`A` = Accelerate** — the projection accelerate (`bg_pmove.c:240`).
- **Dispatch** — picks accel/friction per tick from state. VQ3 *already* varies accel by state (`:772`), so extending it is a generalization, not a bolt-on.

Gravity, slide/step (`PM_StepSlideMove`), and the ground trace are **unchanged in every mode below** — none of these extensions touch them.

## Two operators

**`A` — Accelerate (KEEP in all modes; verified VQ3).** Grows |v| *along* ŵ, capped by the projection deficit:
```
A(v, ŵ, s, a):
  add = s − dot(v, ŵ)
  if add <= 0: return
  v += min(a·dt·s, add) · ŵ        # changes the LENGTH of v
```

**`R` — Air-control rotation (LAYER ON; CPM reimpl).** Pivots horizontal v toward ŵ at **constant magnitude** — redirects, adds no speed:
```
R(v, ŵ, κ):
  z = v.z; v.z = 0
  speed = |v|; if speed == 0: v.z = z; return
  v̂ = v / speed;  d = dot(v̂, ŵ)
  if d > 0:                                   # can't steer while braking
    k = 32·κ·d²·dt
    v = normalize(v̂·speed + ŵ·k) · speed      # |v| preserved → pure rotation
  v.z = z
```

`A` changes the vector's length; `R` changes its direction. **VQ3 = `A` only** → weak turning → you make the ŵ–v angle manually with strafe keys. Adding `R` is what unlocks sharp air-steering.

Warsow gates `R` outside the operator: side input must be zero and forward/back input must be nonzero. Thus forward-only **or backward-only** can rotate; forward+strafe and strafe-only cannot. The `d > 0` test additionally prevents rotation while moving against the requested direction (`gs_pmove.cpp:641`).

## Airborne skeleton (all modes)

```
ŵ, s = wishdir/speed(input)          # forward·fmove + right·smove, normalized
a = ACCEL(ŵ, v, fmove, smove)        # mode-defined  (VQ3: constant 1)
s = CAP(s, fmove, smove)             # mode-defined  (VQ3: ≤ 320)
v = A(v, ŵ, s, a)                    # SAME VQ3 op
v = R(v, ŵ, KAPPA(fmove, smove))     # LAYERED ON    (VQ3: κ=0 ⇒ no-op)
```

| knob | **VQ3** ✔ | **CPMA** (reimpl) | **QC** (inferred) |
|---|---|---|---|
| `ACCEL` | const `1` | `dot(ŵ,v)<0 → 2.0`; strafe-only `→ 70`; else `1` | same shape, forward-friendly |
| `CAP` | `≤ 320` | strafe-only `→ 30`; else 320 | relaxed so forward-only keeps headroom |
| `KAPPA` (R) | `0` | `150` when `fmove≠0, smove=0` | `>0`, **active on forward** |

## CPMA — layer/replace map

Warsow does not call this path "CPM". `GS_CLASSICBUNNY` clears `PMFEAT_FWDBUNNY`; with the default `PMFEAT_AIRCONTROL` still set, that selects the CPM-like branch (`gs_public.h:235`, `client.cpp:1086`, `gs_pmove.cpp:825`). `GS_NEWBUNNY` instead enables Warsow's separate forward-bunny integrator.

- **REPLACE `ACCEL`**: constant → input-conditional — air-stop `2.0` when `dot(ŵ,v)<0`, strafe-accel `70` when strafe-only (`smove≠0, fmove=0`), else `1` (`gs_pmove.cpp:83`).
- **REPLACE `CAP`**: clamp to `~30` in the strafe-only branch (else 320).
- **LAYER ON `R`**: run after `A`, gated on forward/back-only input, `κ=150`. Any side input makes `R` return immediately (`gs_pmove.cpp:641`).
- **REPLACE ground acceleration coefficient**: `10 → 12`; the `A` operator itself is unchanged.
- **REPLACE ground friction parameters**: coefficient `6 → 8` and control floor `100 → 12`. The scale-toward-zero operator is unchanged, but this is not merely a coefficient swap (`gs_pmove.cpp:498`).
- KEEP everything else.

## QC — layer/replace map

- **LAYER ON `R`**: active on forward/single-key input, tuned strong.
- **RELAX `CAP`**: so forward-only doesn't saturate → you can *accelerate with just W* (the QC quirk; VQ3/CPMA only *maintain* speed on forward-only).
- Net effect: the "create an angle between ŵ and v" job moves **off the strafe keys and onto `R` + mouselook**. That's why holding W while turning keeps accelerating in QC but not VQ3.
- Caveat: forward+strafe *together* degrades air control; release forward for sharp side turns.

## Crouch slide / skating — a GROUND extension

Slides live on the **ground path**, so they extend `Friction`, not the air accel — but the trick is to *run air rules while grounded*.

- **REPLACE ground `Friction`**: coefficient → `~0` (or a low `slideFriction`) while in the slide state. This is the whole point — momentum stops bleeding.
- **REPLACE `CAP`**: a low speed cap so any speed above it is preserved, not accelerated to (mirrors air's low effective cap).
- **Enable gravity-along-slope**: so downhill surfaces *add* speed (component along the plane) — the slide-specific gain.
- **Entry/exit**: gate on crouch + grounded + enough speed; add a timer/decay so flat slides die.

Two flavors (same friction-off core, differ on whether `A`/`R` stay live):

| | ground `Friction` | `A` / `R` live? | feel |
|---|---|---|---|
| **Q4 coast** | → ~0 | **off** (direction locked) | pure momentum coast |
| **QC Slash** | → ~0 | **on** (`A`+`R` run) | air-strafe on the ground: steer + gain |

So a Slash-style slide is literally *"call the airborne skeleton while `grounded`, with friction ≈ 0."* A Q4-style slide keeps friction ≈ 0 but suppresses the accelerate — you carry the velocity you entered with.

## Friction is its own axis

Same `Friction` operator everywhere: `drop = max(speed, controlFloor)·coefficient·dt`, then scale velocity toward zero. Both parameters can move: VQ3 uses coefficient `6`, floor `100`; current Warsow classic movement uses coefficient `8`, floor `12`; a slide drives the coefficient toward `0`.

## Autojump / continuous jump — an INPUT extension

Warsow's `PMFEAT_CONTINOUSJUMP` does not add a landing detector or a second jump path. `PM_CheckJump` checks held jump every tick and merely bypasses the `PMF_JUMP_HELD` release latch; the existing normal-state, water, grounded, and jump-enabled gates still decide whether the surface is jumpable (`gs_pmove.cpp:1126`). Because jump checking precedes friction (`gs_pmove.cpp:2021`), a held jump fires on the first grounded tick without losing speed to ground friction. The controller profile exposes the same behavior as **Autojump**, off by default to preserve VQ3 input behavior.

## Minimal implementation surface

One integrator (`A`, `R`, `Friction`, dispatch) stays fixed; a `MovementMode` supplies:

```
accel(ŵ, v, fmove, smove)        # replaces VQ3's constant airaccelerate
wishspeedCap(fmove, smove)       # replaces/relaxes the 320 cap
aircontrolK(fmove, smove)        # 0 ⇒ R off (VQ3); >0 ⇒ CPM/QC
groundFrictionCoef(state)        # ~0 while sliding
groundControlFloor(state)        # VQ3 100; Warsow classic 12
groundAccelCoef(state)           # VQ3 10; Warsow classic 12
slideActive(state)               # crouch+grounded+speed predicate
jumpRequested(input, autojump)   # just-pressed normally; held with autojump
```

Switching VQ3 ↔ CPMA ↔ QC ↔ slide = swapping this struct. No branches in the mover.

## Layer-vs-replace summary

| VQ3 piece | CPMA | QC | Crouch-slide |
|---|---|---|---|
| `A` accelerate | **keep** | keep | keep (Slash) / **off** (Q4) |
| `accel` value | **replace** (3-way) | tune | n/a |
| `wishspeed` cap | **replace** (30 strafe) | **relax** | **replace** (low) |
| `R` air-control | **add** (fwd) | **add** (fwd) | add (Slash) |
| ground accel value | **replace** (12) | tune | tune |
| ground `Friction` | **replace** (coef 8, floor 12) | tune | **replace** (~0 coef) |
| jump input gate | optional held autojump | optional held autojump | optional held autojump |
| gravity / slide / step / trace | unchanged | unchanged | +slope-gravity |
