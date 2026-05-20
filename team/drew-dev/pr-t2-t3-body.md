# M3 Tier 2 Wave 1 — T2 (hit-pause) + T3 (phase-transition slow-mo)

**Tickets:** `86c9wjy1t` (T2 hit-pause) + `86c9wjy46` (T3 phase-transition slow-mo).
**Foundation:** consumes `TimeScaleDirector` (T11 / PR #285 / merge commit `9efcfc8`).
**Owners:** Drew (combat lane).

## Scope

T2 and T3 are the **visceral payoff of T11**. Hit-pause is the "world flinches" beat on every player→boss damage landing; the final-freeze is the "world stops" beat on lethal hit; phase-transition slow-mo is the cinematic phase-break punch. Get the feel right and the boss intro reads correctly.

Both consume the same TimeScaleDirector API surface (`request` / `freeze` / `release`) and naturally batch in one PR — same file (`Stratum1Boss.gd`), same patterns, same test scaffolding. Two commits would have been ceremony.

## What landed

### T2 — hit-pause + final-freeze (`Stratum1Boss.gd`)

- **Non-fatal player→boss hit** (`take_damage` clean_amount > 0, non-fatal) fires `TimeScaleDirector.freeze(duration, "boss_hit_pause")`:
  - Light swing → 60 ms freeze (Priya AC).
  - Heavy swing → 100 ms freeze (Priya AC + VD-07 budget).
  - Swing kind discovered via duck-typed `source.get_current_attack_kind()` (new accessor on Player.gd that exposes the existing `_current_attack_kind` private var).
  - Null source / missing accessor → defaults to light duration (bare-instance test path).
- **Lethal hit** routes through `_die()` — which fires the **300 ms final-freeze** AFTER `boss_died.emit(...)` returns. Per Uma BI-23 + F1 + Priya AC.
  - Order is load-bearing: subscribers (MobLootSpawner, BossRoom signal chain, Main `_on_mob_died → auto_collect_pickups`) run at scale=1.0 on the death frame; the freeze lands on the next frame and auto-releases at wall-clock per the director's `ignore_time_scale=true` SceneTreeTimer.
  - The micro hit-pause is NOT additionally fired on the lethal blow — final-freeze subsumes it.
- **Suppression** is automatic via the existing `take_damage` early-returns (STATE_DORMANT, STATE_PHASE_TRANSITION, STATE_DEAD all reject the hit before reaching the hit-pause branch).

### T3 — phase-transition slow-mo (`Stratum1Boss.gd`)

- `_begin_phase_transition(target_phase)` fires `TimeScaleDirector.request("boss_phase_transition", 0.3, 0.6, PRIORITY_NARRATIVE)`:
  - Scale 0.3 for 0.6 s wall-clock auto-release.
  - PRIORITY_NARRATIVE so a concurrent T2 hit-pause (PRIORITY_FREEZE) still trumps this — structural-correctness only because phase-transition is itself damage-immune, so no hit can land during the window.
- **Idempotent** via the upstream `_phase_2_latched` / `_phase_3_latched` guards — rapid hit-spam straddling the boundary fires the slow-mo request exactly once.
- **No 0.2 s ramp-back** modeled. The director resolves by step-function; Priya's AC accepts snap-back as the Tier 2 shape. A ramp-back tween would require a sub-request interpolation; deferred to a polish follow-up if Sponsor flags the snap during soak. Documented in the constant block.

### API surface added

- `Player.get_current_attack_kind() -> StringName` — public accessor for `_current_attack_kind`. Used by `Stratum1Boss._request_hit_pause_for(source)` for duck-typed swing-kind dispatch. Compatible with bare-instance tests (null-source fallback).

### Constants (single source of truth at script scope)

```gdscript
const HIT_PAUSE_LIGHT_DURATION: float = 0.060
const HIT_PAUSE_HEAVY_DURATION: float = 0.100
const FINAL_FREEZE_DURATION: float = 0.300
const PHASE_TRANSITION_SCALE: float = 0.3
const PHASE_TRANSITION_SLOW_MO_DURATION: float = 0.60

const TSD_REASON_HIT_PAUSE: String = "boss_hit_pause"
const TSD_REASON_FINAL_FREEZE: String = "boss_final_freeze"
const TSD_REASON_PHASE_TRANSITION: String = "boss_phase_transition"
```

Constants are pinned by a constant-identity test in the new GUT file so Priya / Sponsor AC numbers can't drift silently.

## Tests

### New — `tests/test_stratum1_boss_hit_pause_and_slow_mo.gd` (paired GUT)

14 tests covering both feature surfaces + adversarial probes:

**T2 — hit-pause + final-freeze**

1. Non-fatal light hit fires hit-pause freeze (scale 0.0).
2. Non-fatal heavy hit fires hit-pause freeze.
3. Null source → light duration fallback.
4. Phase-transition-state hit MUST NOT fire hit-pause (state-filter).
5. Dormant-state hit MUST NOT fire hit-pause (intro fairness).
6. Already-dead hit MUST NOT fire hit-pause or re-fire final-freeze.
7. Zero-damage hit MUST NOT fire hit-pause.
8. Lethal hit fires 300 ms final-freeze and does NOT also fire micro hit-pause (final-freeze subsumes).
9. Final-freeze `request_changed` "added" event fires inside `_die()`.

**T3 — phase-transition slow-mo**

10. PHASE_2 boundary fires slow-mo request at scale 0.3.
11. PHASE_3 boundary fires slow-mo request at scale 0.3.
12. Idempotent under hit-spam — exactly one request per boundary (latch guard).

**Adversarial probes**

13. Concurrent hit-pause + phase-transition → director resolution (PRIORITY_FREEZE > PRIORITY_NARRATIVE → scale 0.0 wins). Structural-correctness only.
14. Constant identity pins — every AC number is asserted exact-match against Priya's AC + Uma's BI numbers.

### Updated — `tests/test_player_attack.gd`

Two new tests for `Player.get_current_attack_kind()`:
- Defaults to light before any swing.
- Reflects the most-recent try_attack kind.

### Test-isolation hardening

Stratum1Boss now mutates `Engine.time_scale` via TimeScaleDirector. Existing test files that drive boss damage / death / phase-transition would leak director state into subsequent tests in the suite (scale 0.0 sticky between tests). Added `before_each` / `after_each` (or `_reset_autoloads()` extension) to:

- `tests/test_stratum1_boss.gd`
- `tests/test_stratum1_boss_room.gd`
- `tests/integration/test_boss_loot_integration.gd`
- `tests/integration/test_boss_wakes_and_engages.gd`
- `tests/integration/test_m1_play_loop.gd`

Each resets the director and pins `Engine.time_scale = 1.0` between tests.

## Self-Test Report

See dedicated comment below (per the Self-Test Report gate).

## Cross-lane integration check (PR #216 process gates)

- **`[combat-trace] Stratum1Boss.hit_pause`** / `final_freeze` / `phase_transition_slow_mo` lines added — Playwright specs that scan for boss-side trace lines see additional `Stratum1Boss.*` lines they previously did not; none of the existing regex patterns in `ac4-boss-clear.spec.ts` or `boss-room-smoke.spec.ts` match these new tags (verified by grep — patterns key on `Stratum1Boss.take_damage` / `Stratum1Boss._die` / `Stratum1Boss._spawn_hitbox` / `Stratum1Boss._set_state`).
- **Mob.pos trace contract** unchanged — no `Stratum1Boss._physics_process` trace modifications.
- **Player iframes / Damage formula constants** untouched.
- **RoomGate signal chain** untouched. Boss `_die` still emits `boss_died` at frame-0 of the death sequence; the freeze fires AFTER the emit returns so `MobLootSpawner.on_mob_died` / Main `_on_mob_died` run at scale=1.0 on the same frame.
- **Adjacent specs probed**:
  - `tests/test_stratum1_boss.gd` — added before_each/after_each; existing tests unchanged.
  - `tests/test_stratum1_boss_room.gd` — added before_each/after_each.
  - `tests/integration/test_boss_loot_integration.gd` — `_reset_autoloads()` extended to reset director.
  - `tests/integration/test_boss_wakes_and_engages.gd` — added before_each/after_each.
  - `tests/integration/test_m1_play_loop.gd` — `_reset_autoloads()` extended to reset director.

## Regression guard

The new GUT test file pins:

- Constants drift (light/heavy/final/phase-transition durations + scale + reason keys).
- Filter-class correctness — every `take_damage` early-return MUST NOT fire hit-pause. A future refactor that accidentally re-orders the early-returns past the hit-pause branch fails the dormant / phase-transition / dead / zero-damage tests.
- Source-kind dispatch correctness — the duck-typed `get_current_attack_kind()` lookup is exercised on both light and heavy probes and a null-fallback probe.
- Idempotence — boundary-crossing hit-spam fires phase-transition slow-mo exactly once per boundary.
- Lethal-hit subsumption — final-freeze fires AND hit-pause does NOT fire on the same lethal hit.

## Non-obvious findings (doc-update flag)

1. **Test-isolation cascade.** Any future T11-consumer ticket (T16 / other Tier 2 PRs) that touches `Engine.time_scale` via TimeScaleDirector will need the same `_director.reset()` discipline in tests that drive the consumer. Worth a single line in `.claude/docs/test-conventions.md` under a "Engine.time_scale leak" subsection — every test that triggers a director request must reset on teardown or downstream tests in the same suite poison silently with scale 0.0 between tests.

2. **Lethal-hit-subsumes-hit-pause as a contract.** The decision to NOT also fire hit-pause on the lethal blow is design intent (final-freeze covers the same window), not an accident. A future refactor that moves the hit-pause call BEFORE the `_die()` branch would silently re-introduce the double-pause. Pinned by `test_lethal_hit_fires_final_freeze_300ms` which asserts hit-pause is NOT active alongside final-freeze.

3. **Constant block per consumer.** Each T11 consumer (T2 here, T16 future) ships its own `TSD_REASON_*` constants. Worth canonicalizing in `.claude/docs/time-scale-director.md` that consumer-side reason keys are namespaced (`boss_hit_pause` / `boss_final_freeze` / `boss_phase_transition` here) and re-using the same key across consumers is the idempotent-refresh idiom, not a clobber.

## References

- `team/priya-pl/m3-tier2-boss-room-polish-scope.md` §3 T2 + T3 + T11 AC
- `team/uma-ux/boss-intro.md` BI-16, BI-17, BI-18 (phase transition), BI-23, F1 (final freeze)
- `.claude/docs/time-scale-director.md` (director contract + migration policy)
- `scripts/combat/TimeScaleDirector.gd` (T11 / PR #285)
