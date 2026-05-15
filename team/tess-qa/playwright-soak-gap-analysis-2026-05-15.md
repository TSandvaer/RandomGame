# Playwright Soak-Gap Analysis — 2026-05-15

**Why did the 2026-05-15 Sponsor soak surface bugs that pre-merge CI missed?**

Drew's PR #230 (two game-side P0 fixes) and Uma's PR #228 (modal-pause fix) diagnosed three real bugs from the Sponsor's soak across Rooms 1-6. Tess's PR #229 created `test.fixme` regression specs. This document is the meta-investigation: for each bug, where was the coverage gap, and what harness change prevents recurrence?

---

## 1. Executive Summary

**Bug 1 — Room 01 respawn pickup race.** No existing spec exercises the post-death-respawn path through Room01. The only integration test (`test_stage_2b_tutorial_traversal.gd`) and all Playwright specs exercise the fistless cold-boot path only. The already-equipped path short-circuited to `call_deferred("_on_room_cleared")` before the dropped Pickup could be collected; no test ever checked "does Room01 advance WAIT for the pickup when the player is already equipped?" The harness fix is a new integration test (now paired with PR #230 as `test_respawn_path_gates_on_pickup_add_before_advancing`) and a Playwright spec asserting that after `apply_death_rule` the Room01 clear does not fire `gate_traversed` / room-advance before an `item_added` trace appears.

**Bug 2 — RoomGate knockback-overlap stuck gate (Rooms 02 and 06).** Existing specs asserting `gate_unlocked emitting` and `gate_traversed` only covered the harness-controlled two-part walk, which deliberately avoids the gate trigger during combat (NE-facing only, player stays near spawn). No spec drove knockback into the gate trigger while mobs were still alive, leaving `body_entered`-while-locked → unlock-while-inside → no re-emit the untested path. The `room-gate-body-entered-regression.spec.ts` confirmed `body_entered` fires reliably but only tests the OPEN-gate path, not the LOCKED-then-UNLOCKED-while-inside path. The harness fix is a new spec exercising the "player walks into gate during live-mob combat → last mob dies → assert gate traverses WITHOUT a manual exit-and-reentry."

**Bug 3 — StatAllocationPanel `Engine.time_scale = 0.10` movement freeze.** The existing `test_stat_allocation.gd` fully tests `time_slow_applied_while_panel_open` and asserts `Engine.time_scale == 0.10` — but the test never checks `CharacterBody2D.move_and_slide()` behavior under that time_scale. Playwright has no spec that reaches Room 05 (Level 2 XP threshold) and opens the level-up panel. The `Engine.time_scale` interaction with physics delta is invisible to GUT (headless, no physics server ticking realistically). Harness fix: a Playwright spec that drives to Room 05, triggers level-up, and asserts player velocity is zero (via absence of `Hitbox.hit | team=mob` during 1.5s panel-open window, or directly via the `Player.velocity == Vector2.ZERO` JS-bridge hook Uma adds in PR #228).

---

## 2. Per-Bug Deep Dive

### Bug 1 — Room 01 Respawn Pickup Race

**Code path:**
`Main._on_room01_mob_died` → check `_player_has_weapon_equipped()` → if `true`, `call_deferred("_on_room_cleared")` → Room01 freed → `PracticeDummy._spawn_iron_sword_pickup`'s deferred `add_child` lands on an already-freed tree → Pickup destroyed before player reaches it.

The fix path (`_room01_already_equipped_awaiting_add`) is in `scenes/Main.gd` lines 517-565.

**Existing specs analyzed:**

| File | What it asserts | Covers the respawn path? |
|---|---|---|
| `tests/integration/test_stage_2b_tutorial_traversal.gd::test_full_tutorial_traversal_walks_onto_pickup_and_lands_room02_equipped` | Player boots fistless, kills dummy, walks onto Pickup, Room01 advances after auto-equip | No — always boots cold (fistless path only) |
| `tests/playwright/specs/room-traversal-smoke.spec.ts` | Room01 dummy poof + auto-advance to Room02, fistless kill | No — cold boot only |
| `tests/playwright/specs/equip-flow.spec.ts` | Equip survival across F5 reload + LMB-click equip path | Partially: Phase 4 post-reload exercises the already-equipped path via `clearRoom01Dummy`, but does NOT assert that Room01 waits for the Pickup to be added to inventory before advancing. It asserts only that the dummy dies and no `source=auto_pickup` fires. |
| `tests/playwright/specs/ac3-death-persistence.spec.ts` | Post-death-respawn damage=6 | Closest: exercises the already-equipped respawn path via `clearRoom01Dummy`. But `clearRoom01Dummy` detects `killSweepWasWeaponScaled` and skips the pickup-collection phase — it never asserts "Pickup landed in inventory" vs "Room01 advanced before Pickup could be collected." |

**Root cause of the gap:**

Three factors combined:

1. **Happy-path bias.** Every test that exercises the "already-equipped on Room01 entry" case (F5 reload in `equip-flow.spec.ts`, post-death-respawn in `ac3-death-persistence.spec.ts`) uses `clearRoom01Dummy` with its `skipPickup`-when-already-equipped logic. That helper correctly skips the pickup walk — because from the harness's perspective the gate releases immediately. It just never noticed that the gate was releasing one frame too early (before the Pickup was added to inventory), because `Inventory.get_equipped(&"weapon")` was non-null from the prior run regardless.

2. **Missing invariant.** No test asserted "after dummy dies with player equipped, `Inventory.items` count increases before Room01 advances." The only observable difference between the buggy and correct behavior is that the Pickup either does or doesn't land in the inventory grid — not visible from existing assertions (which only check equipped slot, not grid contents).

3. **GUT isolation.** `test_stage_2b_tutorial_traversal.gd` explicitly resets the Inventory in `before_each()` and always exercises the fistless path. The respawn-carry scenario (player has `iron_sword` in equipped slot from death-rule carry) was never exercised.

**Harness-improvement proposal:**

- **New GUT test:** `test_respawn_path_gates_on_pickup_add_before_advancing` in `tests/integration/test_stage_2b_tutorial_traversal.gd` (already paired with PR #230). Asserts `room_index == 0` after dummy death when player is pre-equipped, then drains frames while player is pinned to the drop position, and asserts `room_index == 1` only after `item_added` fires.

- **New Playwright spec:** `room1-respawn-pickup-gate` in `soak-narrative-regression.spec.ts` (stub exists as `test.fixme` finding #2). After `apply_death_rule` fires (observed via `[combat-trace] Main.apply_death_rule`), re-run `clearRoom01Dummy`; assert `Inventory.items.size() > 0 OR Inventory.get_equipped_weapon() != null AND item_added trace fired` — i.e. the Pickup made it into the inventory, not just the equipped slot.

- **Invariant for future:** any test that exercises the "already-equipped on Room01 entry" path MUST assert that `item_added` fires BEFORE `gate_traversed` / room-advance. This is the structural guard for the `_room01_already_equipped_awaiting_add` pattern.

---

### Bug 2 — RoomGate Knockback-Overlap Stuck Gate

**Code path:**

Godot 4 `body_entered` is a non-overlap → overlap TRANSITION event only. If the player enters the gate trigger while mobs are alive (`body_entered` fires → `lock()`), and the last mob dies while the player is still inside the trigger (`_unlock()` fires → state UNLOCKED, `gate_unlocked` emits), no second `body_entered` ever fires. The gate is UNLOCKED but `gate_traversed` never emits. Rooms 02 and 06 are both affected; Room 02 from Charger/Grunt knockback pushing the player west into the gate, Room 06 from a similar long-combat drift.

**Existing specs analyzed:**

| File | What it asserts | Covers knockback-into-gate? |
|---|---|---|
| `tests/playwright/specs/room-gate-body-entered-regression.spec.ts` | `body_entered` fires when player walks from spawn into Room02 gate (OPEN gate, no mobs killed) | No — explicitly skips Room02 combat. Only proves body_entered fires for OPEN gate. |
| `tests/playwright/fixtures/gate-traversal.ts::gateTraversalWalk` | Phase 3-5 two-part walk: walk in (lock→unlock immediately), walk out, walk back in (traverse) | No — the harness's combat discipline is NE-facing only, no knockback drift, player stays near spawn. The helper was designed to AVOID this scenario. |
| `tests/playwright/fixtures/gate-traversal.ts` case A/B/C resolution | Case B handles "gate unlocked during combat before helper runs" | Yes — case B detects the gate was already unlocked by a pre-helper `body_entered` event and steers to finish the traversal. BUT: case B is a harness workaround for the locked-then-unlocked scenario; it doesn't test that the game-side fix (the `get_overlapping_bodies()` re-check in `_unlock()`) fires correctly. |
| `tests/test_room_gate.gd` | All GUT unit tests: lock/unlock state machine, zero-mob auto-unlock, CONNECT_DEFERRED decrement, 3-mob concurrent death | No — uses `trigger_for_test()` which places the gate in a known state without any physics simulation. Never simulates "player is inside trigger when `_unlock()` fires." |
| `tests/integration/test_room_gate_two_grunts_decrement.gd` | Two grunts die, gate decrements correctly | No — integration context, but exercises the decrement path only, not the "player already inside when unlock fires" path. |
| `tests/playwright/specs/ac4-boss-clear.spec.ts` | Full Rooms 01-08 traversal | No — uses `gateTraversalWalk` case A/B/C resolution which PAPERS OVER this exact bug rather than failing on it. |

**Root cause of the gap:**

Two compounding factors:

1. **Harness combat discipline hides the bug class.** The NE-facing-only combat discipline (introduced specifically to prevent player drift into the gate trigger during combat) was the right fix for a harness reliability problem but had the side effect of making the knockback-into-gate scenario unreachable in CI. The harness's case A/B/C resolution in `gate-traversal.ts` was then added as a belt-and-suspenders measure that handles this scenario from the harness side — but by fixing the harness rather than detecting the game-side bug, it turned a would-be test failure into a silent pass.

2. **GUT trigger_for_test isolation.** `test_room_gate.gd` uses `g.trigger_for_test(null)` which skips the physics-server `body_entered` pathway entirely. The "player inside trigger when `_unlock()` fires" path requires a live `CharacterBody2D` inside a live `Area2D`'s collision shape — not simulatable in headless GUT without a full physics world. The unit tests cover the STATE transitions correctly but cannot cover the transition-event re-emission contract.

3. **Case B is a harness workaround, not a game-side detector.** `gateTraversalWalk`'s case B logic handles the stuck-unlocked gate from the harness side by steering the player out and back in manually. This makes AC4 green even when the game-side `_unlock()` has no re-emit logic. The game bug only manifested for MANUAL players (Sponsor) who don't have the harness's steering logic.

**Harness-improvement proposal:**

- **New Playwright spec:** `room2-gate-traversal-stickiness` in `soak-narrative-regression.spec.ts` (stub exists as `test.fixme` finding #3). Drives Room 02 combat WITH player allowed to drift into the gate trigger (remove the NE-lock constraint for this spec only), kills all mobs, and asserts `gate_traversed` fires within 5s WITHOUT a manual exit-and-reenter. This is the definitive test that gate B is gone: the game re-emits `gate_traversed` automatically.

- **New GUT invariant:** a test in `test_room_gate.gd` named `test_unlock_with_body_already_inside_fires_traversal` that uses `trigger_for_test` to lock the gate, then `_fire_traversal_if_unlocked()` to simulate the unlock-while-body-inside path, and asserts `gate_traversed` fires without a second `trigger_for_test`. This is the unit-level pin for Drew's `_fire_traversal_if_unlocked()` helper (PR #230 adds 3 such tests for the helper).

- **Drop the case B harness workaround or convert it to a failure.** Once the game-side fix is in, `gateTraversalWalk` case B should `fail()` rather than silently steer. If the game correctly emits `gate_traversed` when the player is inside the trigger at unlock time, the spec should NEVER need case B from the body-inside path — only from the historical "player drifted in BEFORE the unlock" path. A case B detection that still resolves silently masks any regression of the `_fire_traversal_if_unlocked()` logic.

---

### Bug 3 — StatAllocationPanel `Engine.time_scale = 0.10` Player Movement Freeze

**Code path:**

`StatAllocationPanel.open()` sets `Engine.time_scale = 0.10`. `CharacterBody2D.move_and_slide()` internally scales its physics step by `Engine.time_scale`, so player movement velocity is applied at 10% magnitude per frame. Player appears to move "insanely slow" — reads as frozen to most users.

**Existing specs analyzed:**

| File | What it asserts | Covers time_scale × movement? |
|---|---|---|
| `tests/test_stat_allocation.gd::test_time_slow_applied_while_panel_open` | `Engine.time_scale == 0.10` while open, `1.0` on close | No — asserts the time_scale VALUE, not its effect on `CharacterBody2D.move_and_slide()`. Actually PASSES for both the buggy (time_scale=0.10) and the fixed (modal-pause) behaviors. |
| `tests/test_stat_allocation.gd::test_time_slow_factor_is_uma_10_percent` | `StatAllocationPanel.TIME_SLOW_FACTOR == 0.10` | No — this was asserting the CORRECT value of the constant, which made the bug invisible (the constant was correct; the consequence was wrong). |
| `tests/playwright/specs/equip-flow.spec.ts` Phase 2.5 | Tests `Engine.time_scale` restored after `force_close_for_test` | Adjacently relevant — asserts time_scale is 1.0 AFTER close. But the spec force-closes the panel before doing any movement; it never observes movement while panel is open. |
| All other Playwright specs | None reach Room 05 (Level 2 XP threshold) | No — AC4 terminates at Room 08 (boss clear), but no spec checks for the level-up event triggering the panel auto-open. |

**Root cause of the gap:**

Two independent gaps:

1. **Wrong invariant tested.** `test_time_slow_applied_while_panel_open` asserted `Engine.time_scale == 0.10` — which was the INTENDED behavior per Uma Beat 2. The test confirmed the implementation matched the spec. The spec was wrong (the UX was wrong), not the implementation. This is the hardest class of gap to catch with tests: when the spec itself has a UX-incorrect assumption. The Playwright harness would have caught it only if a spec had asserted "player cannot move during panel open" — but no such assertion existed because the spec said "world slows to 10%" not "player stops."

2. **No Playwright path reaches Room 05 level-up.** The AC4 spec traverses Rooms 01-08 but does not pause to open the inventory or assert the level-up panel during the run. The level-up event in Room 05 (during the 3-chaser combat, when the player kills enough mobs to hit L2 threshold) was observable only to Sponsor because Sponsor naturally slowed down in Room 05 — making the slow movement perceptible. CI's AC4 spec killed the mobs as fast as possible and moved on, never pausing long enough to notice the panel was open and movement was slow.

3. **`Engine.time_scale` not observable from Playwright without a bridge.** Unlike `[combat-trace]` lines, `Engine.time_scale` doesn't emit any console output. The proxy (player velocity zero → no `Hitbox.hit | team=mob target=Player` in 1.5s) is indirect. Uma's PR #228 changes this by switching to `PROCESS_MODE_DISABLED` — which is observable via the player literally not moving (no `Player.pos` trace updates), so the new test in PR #229 (`room5-level-up-movement-blocked`) uses that approach.

**Harness-improvement proposal:**

- **Update existing GUT test:** `test_time_slow_applied_while_panel_open` is now **wrong** (PR #228 removes `Engine.time_scale` mutation entirely). It must be updated to assert `Engine.time_scale == 1.0` while open AND `Player.process_mode == PROCESS_MODE_DISABLED`. Uma's PR #228 already updates `test_stat_allocation.gd` accordingly.

- **New Playwright spec:** `room5-level-up-movement-blocked` in `soak-narrative-regression.spec.ts` (stub exists as `test.fixme` finding #4). Drives to Room 05, triggers the level-up panel auto-open, holds movement keys for 1.5s, asserts NO `Player.pos` trace updates during that window (player stopped → `PROCESS_MODE_DISABLED` working). Flip trigger: Uma's modal-pause fix PR (#228) merging.

- **New harness invariant:** any spec testing a UI modal that blocks gameplay MUST assert a gameplay observable (no movement, no damage, no velocity) not just a state variable (`Engine.time_scale` value). The `time_scale == 0.10` assertion was a false positive — it confirmed the implementation, not the UX.

- **Consider a "level-up smoke" spec:** a standalone spec that reaches Room 05 with fast-XP debug enabled (`OS.has_feature("test_mode")` → `fast_xp = true`), kills one mob to trigger L2, and asserts the level-up panel opens (`[StatAllocationPanel] panel_opened` print line) + player movement is blocked. This would have caught Bug 3 in CI before the soak.

---

## 3. Cross-Reference Table: PR #229 Coverage vs Residual Gaps

| Bug ID | Bug description | PR #229 covers? | Coverage status |
|---|---|---|---|
| Bug 1 | Room01 respawn pickup race | `test.fixme` finding #2 — `room1-gate-unlocks-on-mobs-cleared` stubs the assertion | Partial: assertion body is present but incorrect (tests "gate unlocks after mob death" not "gate does NOT advance before pickup collected"). The respawn-specific invariant ("item_added fires before room-advance") is NOT in #229 — it was added to the GUT side by PR #230. A Playwright spec for the respawn-path pickup-add gate remains a residual gap. |
| Bug 2 | RoomGate knockback-overlap stuck gate | `test.fixme` finding #3 — `room2-gate-traversal-stickiness` and finding #5 `room6-gate-unlocks-on-mobs-cleared` | Covered for Room 02 (finding #3 asserts `gate_traversed` fires after mob-clear without manual reentry) and Room 06 (finding #5 asserts gate unlock). Residual gap: the "player inside trigger AT THE MOMENT OF unlock" specific scenario is not distinguishable from the normal unlock-then-walk scenario in the spec. Game-side unit test in PR #230 closes this. |
| Bug 3 | StatAllocationPanel time_scale movement | `test.fixme` finding #4 — `room5-level-up-movement-blocked` stubs the assertion | Covered: spec asserts player stops during panel-open via absence of mob-hit or `Player.pos` update. Residual gap: the spec requires a traverseToRoom(4) helper that does not yet exist; the stub has a TODO. Getting to Room 05 in CI requires either fast-XP or playing through Rooms 01-04 with mobs, which is the AC4 full-run path (slow). A "fast-XP level-up smoke spec" is the cleaner solution and is a residual gap. |

**PR #229 net coverage:** 3/3 bugs have at least a stub spec. 0/3 have a fully green live assertion yet (all are `test.fixme` gated on Drew's PR #230 and Uma's PR #228). Residual gaps are the respawn-specific GUT pin (closed by PR #230) and the fast-XP level-up smoke spec (open, not yet filed).

---

## 4. Recommended Next-Quarter Harness Investments

1. **"Already-equipped" respawn-path Playwright spec.** Drive Room01 with `apply_death_rule` path, assert `item_added` trace fires before `Main._on_room_cleared` equivalent. Closes the respawn-pickup-race class permanently at the Playwright layer. File as a follow-up to PR #229 findings.

2. **Game-side knockback-drift combat spec.** Remove the NE-lock constraint for ONE dedicated spec (or per-room gate-traversal test) and verify `gate_traversed` fires even when the player drifts into the gate trigger during combat. Convert `gateTraversalWalk` case B from a silent workaround to an explicit failure once PR #230's `_fire_traversal_if_unlocked` is in main. This catches any future regression of the deferred-body-entered-re-emit logic.

3. **Fast-XP level-up smoke spec.** A Playwright spec that boots with `?fast_xp=true` (or the equivalent debug-flag URL parameter), kills one mob in Room 02 to trigger L2, and asserts the level-up panel opens + player movement stops. This is the CI gate that would have caught Bug 3 before the Sponsor soak.

4. **`Engine.time_scale` universally observable invariant.** Any spec that opens a modal UI (inventory panel, level-up panel) MUST assert a gameplay observable during the open window — not just a GDScript state variable. Codify this as a harness convention in `team/tess-qa/playwright-harness-design.md` § "Modal UI spec discipline."

5. **Phase 2A: migrate all 11 existing specs to `test-base` import.** Once the universal warning gate Phase 2A migration lands (tracked by ticket `86c9uf0mm`), ALL console warnings from any of the three bugs' code paths would have failed CI via the `afterEach` gate — even for paths not explicitly asserted. This is the highest-leverage single investment: it turns all unasserted warning paths into free CI failures.
