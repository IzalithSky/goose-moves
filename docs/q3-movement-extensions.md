# Q3 Movement — Extensions over VQ3 (CPMA, QC, slides)

Extends [q3-movement.md](q3-movement.md). Everything here is framed as **how each mode layers over or replaces a specific VQ3 math piece** — nothing throws the VQ3 core away.

**Confidence:** VQ3 pieces are source-verified (see base doc). CPM's air-control operator and constants, plus Warsow's autojump, ramp launch/double jump, crouch slide, and wall jump, are source-verified against **Warsow/qfusion** at `references/warsow` revision `cc22b709` (CPMA itself is closed-source). QC is **behavioral inference** (closed-source; community-reported, patch-sensitive). Q4/QC slide behavior is from docs + community, not code. Treat CPM/QC numbers as canonical-reimplementation values, not ground truth.

## The VQ3 pieces you extend

From the base doc, the swappable surface is small:

- **`Friction`** — ground only, scale-toward-zero with the stopspeed floor.
- **`A` = Accelerate** — the projection accelerate (`bg_pmove.c:240`).
- **Dispatch** — picks accel/friction per tick from state. VQ3 *already* varies accel by state (`:772`), so extending it is a generalization, not a bolt-on.

Gravity and the ground trace remain shared. Warsow's optional ramp launch extends collision slide/step handling by preserving the upward velocity created when clipping into a steep plane.

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

Slides live on the **ground path**, so they primarily extend `Friction`. Q4 and QC illustrate the coast-vs-air-rules split; Warsow's implementation below is a separate controlled-ground variant.

- **REPLACE ground `Friction`**: coefficient → `~0` (or a low `slideFriction`) while in the slide state. This is the whole point — momentum stops bleeding.
- **REPLACE `CAP`**: a low speed cap so any speed above it is preserved, not accelerated to (mirrors air's low effective cap).
- **Optionally enable gravity-along-slope**: Q4/QC-style downhill surfaces can *add* speed (component along the plane); Warsow does not add this operator.
- **Entry/exit**: commonly gate on crouch + grounded + enough speed and add a timer/decay; Warsow instead arms its slide while airborne for the next landing.

Two flavors (same friction-off core, differ on whether `A`/`R` stay live):

| | ground `Friction` | `A` / `R` live? | feel |
|---|---|---|---|
| **Q4 coast** | → ~0 | **off** (direction locked) | pure momentum coast |
| **QC Slash** | → ~0 | **on** (`A`+`R` run) | air-strafe on the ground: steer + gain |
| **Warsow** | `0`, then fade to `8` | ground `A ×3`; `R` off | landing-armed controlled slide |

So a Slash-style slide is literally *"call the airborne skeleton while `grounded`, with friction ≈ 0."* A Q4-style slide keeps friction ≈ 0 but suppresses the accelerate — you carry the velocity you entered with.

### Warsow crouch slide — landing-armed ground control

Warsow has a third flavor, gated by `PMFEAT_CROUCHSLIDING` and explicitly excluded from `PMFEAT_DEFAULT` (`gs_public.h:581`). It is supported by the mover but **off in the default game feature set**.

The project exposes this implementation as the **Crouch slide** controller-profile toggle, also off by default.

- **ARM IN AIR**: crouch held + horizontal speed above `maxWalkSpeed` (default `160`) + no cooldown. The check refuses to start while already grounded; it sets the slide flag airborne so the slide takes effect on landing (`gs_pmove.cpp:1401`).
- **ZERO-THEN-FADE FRICTION**: a nominal `1500 ms` zero-friction phase followed by a `500 ms` square-root fade back to normal friction. The timer starts when armed, so airtime consumes part of it. Releasing crouch or falling below the speed threshold clamps immediately to the fade; completion starts a `700 ms` cooldown (`q_comref.h:159`, `gs_pmove.cpp:522`, `gs_pmove.cpp:1926`).
- **GROUND `A` STAYS LIVE**: ordinary ground acceleration runs with acceleration amount multiplied by `3`, but the result is clamped so it cannot exceed `max(wishspeed, entrySpeed)` (`gs_pmove.cpp:571`). This makes it a steerable, strongly controlled ground slide—not Q4's direction-locked coast and not Slash's airborne skeleton on ground.
- **NO SPECIAL SLOPE GRAVITY**: the normal grounded movement path remains in use; the slide itself adds no downhill gravity operator.

## Friction is its own axis

Same `Friction` operator everywhere: `drop = max(speed, controlFloor)·coefficient·dt`, then scale velocity toward zero. Both parameters can move: VQ3 uses coefficient `6`, floor `100`; current Warsow classic movement uses coefficient `8`, floor `12`; a slide drives the coefficient toward `0`.

## Autojump / continuous jump — an INPUT extension

Warsow's `PMFEAT_CONTINOUSJUMP` does not add a landing detector or a second jump path. `PM_CheckJump` checks held jump every tick and merely bypasses the `PMF_JUMP_HELD` release latch; the existing normal-state, water, grounded, and jump-enabled gates still decide whether the surface is jumpable (`gs_pmove.cpp:1126`). Because jump checking precedes friction (`gs_pmove.cpp:2021`), a held jump fires on the first grounded tick without losing speed to ground friction. The controller profile exposes the same behavior as **Autojump**, off by default to preserve VQ3 input behavior.

## Ramp / ledge double jump — grounded vertical carry

Warsow has no coyote-time or post-ledge jump: `PM_CheckJump` still returns immediately when `groundentity == -1`. Its "double jump" is instead a **grounded upward-momentum boost**:

```
if grounded:
  if v.z > 0: v.z += jumpSpeed
  else:       v.z  = jumpSpeed
```

The ground categorizer permits the 0.25-unit ground trace while `v.z ≤ 180`; above `180` it forces airborne. Any positive grounded `v.z` is therefore preserved and added to, while `v.z > 100` also emits the named `EV_DOUBLEJUMP` event (`gs_pmove.cpp:1030`, `gs_pmove.cpp:1151`, `gs_pmove.cpp:1171`). With the default `jumpSpeed=280`, the named ramp/ledge window produces roughly `381–460 u/s` upward. There is no explicit ledge detector—the effect emerges when a ramp, step, or edge leaves positive vertical velocity while the ground probe still hits.

## Steep-ramp launch — collision vertical carry

Yes: the related Warsow technique is commonly called a **ramp slide** or **ramp jump**. A plane is walkable only at `normal.z ≥ 0.7`; a contacted plane below that threshold is not ground. `PM_SlideMove` still clips velocity along it with overbounce `1.01`, which turns part of horizontal velocity into upward velocity on a rising steep ramp (`gs_public.h:188`, `gs_pmove.cpp:320`, `gs_pmove.cpp:359`, `gs_slidebox.cpp:41`). `PM_StepSlideMove` then explicitly copies the clipped vertical result, with the source comment: “The following line is what produces the ramp sliding” (`gs_pmove.cpp:486`).

The project exposes this as the independent **Steep-ramp launch** profile toggle, off by default. Contacts with upward-facing non-walkable slopes preserve the Warsow-clipped vertical velocity; near-vertical walls (`normal.y < 0.05`) and walkable floors are excluded. It is collision-driven rather than jump-input-driven, matching the source: jumping is a common way to enter the ramp contact, not an additional condition in `PM_SlideMove`.

At the default `45.572996°` maximum walkable angle, a qualifying ramp is steeper than `45.572996°` but no steeper than `acos(0.05) ≈ 87.13°`. Changing **Max slope angle** changes the lower bound. To try it, start the test level, open **Character Settings → Q3**, enable **Steep-ramp launch**, then run and jump uphill into the labeled **55° STEEP-RAMP LAUNCH** fixture in the north-side slope row. Enough into-ramp speed is required for a noticeable launch.

## Wall jump — a CONTACT extension

Yes. `PMFEAT_WALLJUMP` is included in Warsow's default feature set. The shared **Dash/Walljump** special button triggers it while airborne, subject to a release latch and a `1300 ms` cooldown (`gs_pmove.cpp:1279`).

- **CONTACT**: probes nearby directions for a wall, excluding sky, `SURF_NOWALLJUMP`, players, and surfaces with `|normal.z| ≥ 0.3` (`gs_pmove.cpp:124`, `gs_pmove.cpp:1335`).
- **NEAR-GROUND GUARD**: within one `18 u` step of walkable ground, it requires jump held (or dash-speed upward travel); away from ground, special alone is enough.
- **HORIZONTAL RESPONSE**: clip velocity against the wall, add `0.3·normal` bounce bias, normalize, then preserve horizontal speed with a minimum of `(walkSpeed + maxSpeed)/2`—`240 u/s` at defaults.
- **VERTICAL RESPONSE**: set `v.z = max(old v.z, 330·gravityScale)`, clear dash, and temporarily suppress normal air-control handling (`gs_pmove.cpp:1343`).

## Minimal implementation surface

One integrator (`A`, `R`, `Friction`, dispatch) stays fixed; a `MovementMode` supplies:

```
accel(ŵ, v, fmove, smove)        # replaces VQ3's constant airaccelerate
wishspeedCap(fmove, smove)       # replaces/relaxes the 320 cap
aircontrolK(fmove, smove)        # 0 ⇒ R off (VQ3); >0 ⇒ CPM/QC
groundFrictionCoef(state)        # ~0 while sliding
groundControlFloor(state)        # VQ3 100; Warsow classic 12
groundAccelCoef(state)           # VQ3 10; Warsow classic 12
slideActive(state)               # mode-defined; Warsow arms airborne for landing
jumpRequested(input, autojump)   # just-pressed normally; held with autojump
verticalJumpResponse(state)      # reset in VQ3; add on Warsow's grounded upslope window
wallJumpResponse(contact, state) # optional contact-triggered velocity redirect
rampClipResponse(contact, state) # optional steep-plane vertical preservation
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
| steep-plane collision | optional ramp launch | tune | tune |
| gravity / ground trace | unchanged | unchanged | +slope-gravity |
