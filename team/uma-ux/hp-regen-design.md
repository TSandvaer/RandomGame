# HP Regen — Out-of-Combat Health Regeneration Design Spec

**Owner:** Uma (UX / design specs) · **Phase:** M1 RC unblocker · **ClickUp:** `86c9q7pgc`
**Drives:** Devon's implementation PR · **Status:** locked for Devon hand-off

---

## Intent

Sponsor's M1 RC soak hit a balance wall: the trade math across 8 rooms is unsurvivable without
any health-recovery resource between fights. Sponsor explicitly chose out-of-combat passive
regeneration — NOT room-transition full-heal — so that active disengagement (kiting, dodging
through attacks, finding a moment of safety) directly rewards the player with restored HP. This
is the correct design vocabulary for Embergrave: regen makes "running away to breathe" a
strategic act, not a consolation. The mechanic is additive and scope-isolated — it touches
neither Damage.gd formulas nor mob stat values. It is the minimum viable safety net that
unlocks the intended play loop without rebalancing anything else.

---

## Activation rule

**Out-of-combat** is defined as:

```
time_since_last_damage_taken_secs > 3.0
  AND
time_since_last_hit_landed_secs > 3.0
```

Both timers run independently and both must exceed their threshold before regen activates.

**Values chosen:** 3.0 seconds each.

**Justification:**

- `damage_taken > 3.0s` — ensures the player is genuinely out of incoming fire, not just
  momentarily between hits. A grunt swings roughly every 1.0–1.5 s when in melee range; 3 s
  gives a clean two-swing gap before regen kicks in. A 2 s threshold would trigger mid-skirmish
  if the player kites one step back; 4 s would feel unresponsive and punish cautious play.
- `hit_landed > 3.0s` — the player can't sustain DPS output AND recover simultaneously. If
  they're still attacking, they are still in combat. 3 s means one attack burst is safe to
  finish before the regen timer starts ticking. This prevents "attack one grunt, retreat, attack
  another, regen throughout" — the player must fully disengage.
- Both at 3.0 s keeps the rule simple and symmetrical. Devon exports both as tunables
  (`REGEN_DAMAGE_COOLDOWN_SECS` and `REGEN_ATTACK_COOLDOWN_SECS`) so balance-pass tweaks are
  one-line changes.

**Implementation note for Devon:** both timers should be `float` counters that increment with
`delta` each `_physics_process` frame and reset to `0.0` on the relevant event (damage taken /
hit landed). Regen activates when both exceed their threshold simultaneously.

---

## Regen rate

**Rate: 2.0 HP/sec when out-of-combat.**

**Trade math (verified against `resources/mobs/grunt.tres`):**

From `grunt.tres`:
- `hp_base = 50`
- `damage_base = 5`

Player stats (from M1 integration decisions):
- Player `HP_MAX = 100` (from `scripts/player/Player.gd` / M1 integration spec)
- Player starts fistless: `FIST_DAMAGE = 1` per `combat-architecture.md`
- A grunt deals 5 damage per hit

Encounter cost model:
- Clearing a single grunt fistless: 50 swings to kill (at 1 dmg/swing). A grunt landing 2 hits
  during that window = 10 HP lost. With a weapon (T1 item), player might deal 5–8 dmg/swing,
  killing a grunt in ~7 hits while eating 1–2 hits = 5–10 HP lost.
- Stratum 1 has 8 rooms. Rooms 1–7 each contain mobs; Room 8 is the boss. Conservatively: 2
  mobs per room average × 7 rooms = 14 mob encounters. At 5–10 HP lost per encounter, worst-
  case total damage to boss room = 70–140 HP = 0.7–1.4× the player's entire HP pool. Without
  any recovery, the Sponsor's reported inability to reach Room 8 is entirely consistent.

Regen rate math:
- At **1.0 HP/s**: recovering from 30 HP deficit takes 30 seconds of standing still between
  rooms. That is too slow — the player spends more time idling than playing. Regen feels like a
  chore, not a reward.
- At **2.0 HP/s**: recovering from 30 HP deficit takes 15 seconds. That is one natural "catch
  your breath" pause between room clears. Regen feels meaningful and is noticeable within a
  single inter-room transition window (which typically takes 5–10 seconds of walking to the
  next room). Partial regen during traversal is the intended feel.
- At **5.0 HP/s**: recovering 30 HP takes 6 seconds — too fast. Encounters become consequence-
  free. Boss difficulty collapses.

**2.0 HP/s is the pick.** Devon exports this as `REGEN_RATE_HP_PER_SEC` (float, tuneable).

---

## Cap and interrupt behavior

- **Cap:** regen halts when `hp_current >= hp_max`. No overheal. HP is clamped at `HP_MAX` on
  every regen tick (the `hp_current = min(hp_current + regen_amount, hp_max)` pattern).
- **Interrupt on damage taken:** any `take_damage(amount)` call resets `time_since_damage` to
  `0.0`, immediately canceling active regen. Regen does not resume until 3.0 s have passed with
  no further damage.
- **Interrupt on hit landed:** any successful hit landing on a mob (the moment the Hitbox
  resolves a `_try_apply_hit` success) resets `time_since_hit_landed` to `0.0`, immediately
  canceling active regen.
- **No regen during dodge:** the dodge roll's i-frame window is short enough (500 ms default)
  that it cannot satisfy the 3.0 s damage-quiet threshold on its own. No special-case handling
  needed — the timers handle this implicitly.
- **Regen during room traversal corridors:** regen can activate in the inter-room transition
  area if neither condition was triggered for 3.0 s. This is intentional — the traversal moment
  IS the "running away" moment Sponsor wants rewarded.

---

## Visual cue

### Primary: HP bar shimmer on the regen-active region

When regen is active, the HP bar foreground region that represents the regenerating portion gets
a warm-amber alpha-pulse — a subtle "breathing light" shimmer on the filled segment of the HP
bar. This communicates "healing" without crowding the playfield.

**Implementation spec for Devon:**

- The shimmer is an animated modulate on the HP bar's `ColorRect` foreground node (the warm-red
  `#D24A3C` fill bar from `team/uma-ux/hud.md`). Do NOT modulate the parent HUD node or the
  full HP bar container — modulate cascades multiplicatively and would interfere with the ghost-
  damage layer beneath (see combat-architecture.md Mob hit-flash section for the cascade rule).
- Tween the foreground ColorRect's `modulate` between:
  - **Rest (regen inactive):** `Color(1.0, 1.0, 1.0, 1.0)` (default, no shimmer)
  - **Shimmer peak:** `Color(1.0, 0.85, 0.55, 1.0)` — warm amber tint, all channels strictly
    sub-1.0 per the HTML5 HDR-clamp rule. The amber shifts the red foreground to an ember-warm
    glow that reads as "recovery" without leaving the Embergrave palette.
  - **Shimmer trough:** `Color(0.85, 0.75, 0.75, 0.85)` — slight desaturation + alpha dip,
    creates a "breathing" oscillation.
- Tween cycle: 0.8 s peak-to-trough-to-peak (looping), using `Tween.TRANS_SINE /
  EASE_IN_OUT`. Starts when regen activates; killed and reset to rest-color when regen
  deactivates.

**Why this cue, not others:**
- Tweening the parent CharacterBody2D / full HUD modulate would cascade into the XP bar, HP
  background, and ghost-damage layer — a multiplicative no-op or visual corruption depending on
  existing modulate values. This is the PR #115/#122 cautionary tale.
- Polygon2D overlay on the HP bar was considered and rejected: Polygon2D has renderer divergence
  in `gl_compatibility` (HTML5). ColorRect tween is renderer-safe.
- A particle burst or full-screen overlay would be too noisy for a passive, continuous state.
  The shimmer is ambient, not an event.

### Secondary (optional, low-priority): small green `+` text popup

If Devon has time: every 5 HP recovered, spawn a small `+5` gold-tinted text popup (same
system as existing XP-gain popups, color `#A8D860` — a muted green that does not conflict with
the ember palette). This is entirely optional for M1 — the shimmer is sufficient. Flag as
M2-polish if not implemented now.

---

## Audio cue

**M1 ships silent (BB-8 audio stub scope).** No audio cue for regen in M1.

Stub acknowledgement: the regen activation event (`regen_started` signal, if Devon emits one)
is the correct hook for an M2 heartbeat-recovery hum. Flag this for Devon: emit the signal even
if no audio bus listens in M1, so M2 audio work can wire in without touching Player.gd logic.

---

## No-mod scope

Regen does NOT touch:

- `Damage.gd` formulas (locked per DECISIONS.md 2026-05-02)
- `grunt.tres`, `charger.tres`, `shooter.tres`, `stratum1_boss.tres` HP or damage values
- `s1_room01.tres` spawn counts or placement
- `Stats.gd` or any level-progression numbers
- Any other existing mechanic

The regen mechanic is a pure additive `_physics_process` delta accumulator on `Player.gd` (or
wherever Devon structures it). Three exported constants, one tween on the HP bar foreground, no
other surface touched.

---

## Acceptance criteria

Devon's paired tests MUST assert all of the following:

**AC-1: Regen activates after thresholds are met.**
After `REGEN_DAMAGE_COOLDOWN_SECS` (3.0 s) with no `take_damage` call AND
`REGEN_ATTACK_COOLDOWN_SECS` (3.0 s) with no hit-landed event, `player.is_regenerating == true`
and `player.hp_current` is increasing each tick.

**AC-2: Regen stops immediately on damage; damage timer resets.**
While regen is active, calling `take_damage(5)` sets `player.is_regenerating == false` and
resets the damage-quiet timer to 0. HP does not increase on the next tick. (Timer restart must
also be asserted: after the `take_damage` call, simulating 2.9 s without damage does NOT resume
regen.)

**AC-3: Regen stops immediately on hit-landed; attack timer resets.**
While regen is active, landing a hit (simulated via Hitbox success or direct `_on_hit_landed()`
call if Devon exposes one) sets `player.is_regenerating == false` and resets the attack-quiet
timer to 0. Regen does not resume until both timers again exceed their thresholds.

**AC-4: Regen rate is exactly `REGEN_RATE_HP_PER_SEC` (2.0 HP/sec).**
Over a simulated 5-second regen window (both timers pre-satisfied, starting HP = 50), assert
`player.hp_current >= 59.0` and `player.hp_current <= 61.0` (10 HP ± 1 for float precision
across 5 s of delta accumulation). Do NOT assert exactly 60 — float accumulation across frames
will drift slightly.

**AC-5: Regen caps at HP_MAX; no overheal.**
Starting at `HP_MAX - 1`, simulate 5 s of regen. Assert `player.hp_current == player.hp_max`.
Assert `player.hp_current` never exceeds `player.hp_max` at any intermediate tick.

**AC-6: Integration — player can complete Room 1 transition with regen active between
encounters.**
GUT integration test: spawn Player in Room 1 equivalent, clear all mobs (simulate via direct
HP-zero calls), wait 3.5 s (simulated delta) with no attack/damage, assert regen is active,
assert HP has increased. This is the integration surface that proves the mechanic materializes
for Sponsor's play loop. This AC maps to the `test_m1_play_loop.gd` integration suite pattern.

**AC-7 (HTML5 gate): HP bar foreground modulate produces observable delta when regen is active.**
The shimmer tween must produce `hp_bar_foreground.modulate != Color(1,1,1,1)` when
`player.is_regenerating == true`. This is a Tier 1 visual-primitive invariant — assert the
color delta directly, not just `tween.is_valid() == true`. See Visual-primitive test bar section
below.

---

## Visual-primitive test bar (mandatory for Devon's Self-Test)

Per `team/TESTING_BAR.md` and `team/orchestrator/dispatch-template.md` § "Visual-primitive
test bar":

**Visual-primitive test bar (load-bearing for tween / modulate / color-anim / particle PRs):**

- **Tier 1 (mandatory):** paired test asserts `target != rest` for any tweened visual property.
  `assert_ne(target_color, Color(1,1,1,1))`. White-on-white tweens are the cautionary tale —
  `tween.is_valid() == true` is necessary but insufficient.
- **Tier 2 (mandatory for cascading modulate on parented nodes):** paired test asserts the
  modulate is applied to the **visible-draw node** (the HP bar's foreground ColorRect), NOT to
  a parent HUD Node2D or CanvasLayer whose child has its own non-white modulate. Modulate
  cascades multiplicatively; shimmer on the wrong node is a no-op or corruption.
- **Tier 3 (aspirational):** framebuffer pixel-delta sample at the HP bar region. Deferred
  until a `--rendering-driver opengl3` headed CI lane lands; Tier 1 + Tier 2 are the binding
  floor.
- **HTML5 verification:** the regen shimmer tween is a `modulate` animation on a ColorRect node.
  `ColorRect.color` renders identically across `gl_compatibility` (HTML5) and `forward_plus`
  (desktop) — it is NOT a Polygon2D and NOT a modulate on a CharacterBody2D, so it is exempt
  from the HTML5 visual-verification hard gate per `.claude/docs/html5-export.md` §
  "HTML5 visual-verification gate" (platform-agnostic fixes are exempt). However, Devon's
  Self-Test Report MUST confirm this in the PR comment — Tess will verify the exemption claim.
- **Reference:** `team/log/2026-05-html5-visual-feedback-no-op-postmortem.md` — PR #115/#122
  cautionary tale (tween fires ≠ visual changes; shipped to production for ~3 days before soak
  caught it).

---

## HTML5 verification gate note

The regen shimmer is a `ColorRect.color`/`modulate` tween. `ColorRect` renders identically
across `gl_compatibility` and `forward_plus` — it is exempt from the HTML5 visual-verification
hard gate (per `.claude/docs/html5-export.md`). Devon's Self-Test Report must explicitly state
this exemption claim and confirm the shimmer node is a ColorRect (not a Polygon2D substitute).

If Devon places the shimmer on any Polygon2D-based node, the HTML5 gate becomes mandatory and
the PR needs an explicit HTML5 build artifact + Sponsor verification before merge.

---

## Open questions / parking lot

1. **HP_MAX value:** this spec assumes `HP_MAX = 100` based on M1 integration context. Devon
   should confirm the actual exported constant name and value in `Player.gd` and ensure the
   regen cap references it (not a hardcoded `100`).

2. **Hit-landed signal surface:** the "hit landed" event currently resolves inside
   `Hitbox._try_apply_hit`. Devon needs to decide how to expose this to the regen timer — either
   a `Player.on_hit_landed()` method that Hitbox calls back, or a signal Player emits when
   the Hitbox reports a successful hit. Either is fine; the AC-3 test needs a hookpoint.

3. **Boss encounter:** the boss room likely has much faster incoming damage. The 3.0 s cooldown
   means regen will almost never activate during a boss fight — this is by design. If Drew's
   boss-damage tuning changes significantly, revisit the threshold values. Flag for Drew as a
   M2 balance note: if regen makes stratum-1 encounters too trivial, boss damage scaling (not
   regen disabling) is the correct lever.

4. **Charger / Shooter edge case:** Charger hits in a burst; Shooter fires projectiles at range.
   The `time_since_last_damage_taken` timer correctly handles both (any hit resets it). No
   special-casing needed. Devon should confirm the projectile's `take_damage` call flows through
   the same path as melee.

5. **Audio stub signal:** if Devon emits a `regen_started` / `regen_stopped` signal, this
   creates the M2 audio hook. Optional for M1 but worth 2 lines if natural to the implementation.

6. **Regen during stagger / death:** if the Player has a stagger state, regen should not
   activate during it (stagger implies recent damage). The `time_since_last_damage_taken` timer
   handles this implicitly if stagger is triggered by `take_damage`. Devon should confirm the
   stagger path flows through `take_damage`. Death interrupt is implicit — Player is dead, no
   ticks run.

---

## Self-Test (design-only dispatch)

**Self-Test:** read existing `team/uma-ux/*.md` docs for tone/structure consistency;
cross-checked regen rate against grunt HP/damage in `resources/mobs/grunt.tres`
(confirmed `hp_base = 50`, `damage_base = 5`); no contradictions with `combat-architecture.md`
or `DECISIONS.md` damage formula lock; visual cue targets ColorRect foreground (not
CharacterBody2D parent modulate), consistent with hit-flash post-mortem lessons.

---

## Hand-off checklist for Devon

- [ ] Implement `REGEN_DAMAGE_COOLDOWN_SECS = 3.0`, `REGEN_ATTACK_COOLDOWN_SECS = 3.0`,
      `REGEN_RATE_HP_PER_SEC = 2.0` as exported tunables in `Player.gd` (or equivalent)
- [ ] Add `_physics_process` delta accumulation for both timers; reset on damage / hit-landed
- [ ] Add regen HP tick: `hp_current = min(hp_current + REGEN_RATE_HP_PER_SEC * delta, hp_max)`
- [ ] Add shimmer tween on HP bar foreground ColorRect: `Color(1.0, 0.85, 0.55, 1.0)` peak,
      0.8 s SINE cycle, kill on deactivate
- [ ] Expose `is_regenerating: bool` property (read-only; for tests)
- [ ] Paired GUT tests covering AC-1 through AC-7
- [ ] Self-Test Report comment on PR before Tess review (per `team/TESTING_BAR.md`)
- [ ] Self-Test Report must claim ColorRect exemption from HTML5 gate OR trigger HTML5 build if
      Polygon2D is used instead
- [ ] ClickUp `86c9q7pgc` flip to `ready for qa test` on PR open
