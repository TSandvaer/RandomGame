/**
 * ac4-boss-clear.spec.ts
 *
 * AC4 — Stratum-1 boss reach + clear in ≤10 min from cold start
 *
 * Verifies the M1 RC soak checklist v2 §5 AC4 — the climax of the M1
 * play-loop. Walks through Rooms 1-7 killing all mobs, enters Boss Room
 * (Room 8 in the BOSS_ROOM_INDEX layout per scenes/Main.gd:60), waits for
 * the 1.8 s entry sequence, then attacks the boss until boss_died emits.
 *
 * **Harness-drift root cause + fix (PR #171 Devon investigation, ticket
 * 86c9qbhm5):** The prior `test.fail()` block was hypothesised on
 * "body_entered does not fire under Playwright + Chromium HTML5". Devon's
 * regression canary (`tests/playwright/specs/room-gate-body-entered-
 * regression.spec.ts`) overturned that — body_entered fires reliably
 * (5/5 runs) when the player walks from `DEFAULT_PLAYER_SPAWN = (240, 200)`
 * via the two-segment walk pattern. The actual blocker was **player drift
 * during long combat in this spec's `clearRoomMobs`** — the prior
 * implementation cycled through 8 aim directions every 8 attacks, and
 * combined with knockback feedback this accumulated 100+px of westward
 * + northward displacement before the gate-traversal walk. From the
 * drifted position the helper's W→N pattern landed against the room
 * west/north wall outside the trigger rect and the body_entered never
 * fired.
 *
 * Reproducible signature observed: ~6-15s combat = walk succeeds; ~21s
 * combat = walk fails. Drift scales with combat duration (the longer
 * the cycle, the more knockback ticks accumulate).
 *
 * **The harness-side fix (this PR):**
 *
 *   1. `clearRoomMobs` is rewritten to use NE-facing-only + click-only.
 *      No aim-sweep. Mobs in Rooms 02-08 spawn NE/N of player per the
 *      `chunk_def` TRES files (verified — even the few "south of player"
 *      spawns are 8px south of Y=200 and chase the player up). A single
 *      NE facing covers them all without requiring the player to wander.
 *
 *   2. `gateTraversalWalk` accepts an optional `expectedSpawn` parameter
 *      that propagates into the failure message when `_on_body_entered`
 *      doesn't fire — drift-related failures self-document.
 *
 *   3. Per-room assertion that `[combat-trace] RoomGate._on_body_entered`
 *      fires before `gate_traversed` is checked. Devon PR #171 added the
 *      explicit trace line at function entry to distinguish "gate never
 *      reached" from "gate reached but state-machine wrong" failures.
 *
 * Two original spec-mechanics bugs that the helper still handles
 * correctly (kept in `gateTraversalWalk` since pre-PR-#170):
 *
 *   - Gate trigger Y-band misses player spawn Y (need diagonal-or-segmented
 *     walk-in to satisfy X∈[24,72] AND Y∈[104,184] simultaneously).
 *   - RoomGate state machine requires TWO distinct body_entered events
 *     (Godot 4 `body_entered` fires once per non-overlap → overlap
 *     transition; helper drives walk-in → walk-out → walk-in pattern).
 *
 * Per-room navigation strategy:
 *   - Room 01 (no gate): the PR #169 practice_dummy auto-advances the room
 *     counter on death via `_install_room01_clear_listener` (Main.gd).
 *     Walk-NE then 4-direction attack-sweep until PracticeDummy._die.
 *   - Rooms 02-08 (RoomGate at (48,144), size (48,80)):
 *       a. Combat — kill all mobs via NE-facing click-spam. NO aim-sweep,
 *          NO direction-key holds, NO repositioning. Player stays within
 *          ~50px of `DEFAULT_PLAYER_SPAWN` so the gate-traversal walk has
 *          predictable geometry.
 *       b. Traversal — call gateTraversalWalk(...) with `expectedSpawn:
 *          [240, 200]` to drive the two-part walk pattern (NW-in → SE-out
 *          → NW-in) producing the body_entered #1 (gate_unlocked) and
 *          body_entered #2 (gate_traversed) events.
 *   - Boss Room (after Room 08 traversal): player spawns at (240,200);
 *     Stratum1BossRoom._ready auto-fires the entry sequence; boss wakes
 *     after 1.8 s; spam attacks until boss_died emits.
 *
 * **CURRENT END-TO-END STATUS (PR #198, ticket 86c9u05d7):**
 * Rooms 01–04 clear + traverse end-to-end on every release-build run
 * (PR #183 fixed the Room 02 gate-registration blocker; PR #186 added the
 * kiting-Shooter chase that clears Room 04). PR #198 generalised the
 * position-steered pursuit to multi-chaser rooms — `clearRoomMobs` routes
 * the 3-chaser Room 05 through `chaseAndClearMultiChaserRoom` — which fixed
 * the HARNESS-STEERING half of the Room 05 blocker. But PR #198's
 * release-build characterisation then uncovered a GAME-side bug: a
 * death-path physics-flush freeze that stops the surviving sibling mobs'
 * `_physics_process` ~1–2 frames after a concurrent sibling's `_die`. The
 * spec stays `test.fail()` blocked at Room 05 on that game-side freeze
 * (out of harness scope — needs a Drew fix). See the `test.fail()` block's
 * STATUS comment for the full characterisation.
 *
 * Mob composition per room (from resources/level_chunks/s1_room0N.tres):
 *   Room 01: 2 grunts
 *   Room 02: 2 grunts
 *   Room 03: 1 grunt + 1 charger
 *   Room 04: 1 shooter
 *   Room 05: 2 grunts + 1 charger
 *   Room 06: 2 chargers + 1 shooter
 *   Room 07: 2 chargers + 2 shooters
 *   Room 08: 1 grunt + 1 charger + 2 shooters
 *
 * Each gate traversal emits a deterministic trace pair:
 *   `[combat-trace] RoomGate._unlock | gate_unlocked emitting...`
 *   `[combat-trace] RoomGate.gate_traversed | player walked through open door...`
 *
 * Negative-assertion sweep (per dispatch §5 + combat-architecture.md
 * §"State-change signals vs. progression triggers"):
 *   For each room transition: assert `gate_unlocked` fires BEFORE
 *   `gate_traversed` and that the room counter does NOT advance until
 *   `gate_traversed` fires (PR #155 cautionary tale).
 *
 * References:
 *   - team/uma-ux/sponsor-soak-checklist-v2.md §5 AC4
 *   - team/tess-qa/playwright-harness-design.md §5 deferred AC4
 *   - .claude/docs/combat-architecture.md §"State-change signals vs. progression triggers"
 *   - tests/playwright/fixtures/gate-traversal.ts (the gateTraversalWalk helper)
 *   - scripts/mobs/Stratum1Boss.gd (boss controller — phase transitions, wake)
 *   - scripts/levels/Stratum1BossRoom.gd (entry sequence, door trigger)
 *   - scripts/levels/RoomGate.gd (gate state machine)
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";
import { gateTraversalWalk } from "../fixtures/gate-traversal";
import {
  chaseAndClearKitingMobs,
  chaseAndClearMultiChaserRoom,
  returnPlayerToSpawn,
} from "../fixtures/kiting-mob-chase";
import { clearRoom01Dummy } from "../fixtures/room01-traversal";

const BOOT_TIMEOUT_MS = 30_000;
/** Per-room combat budget — enough to kill 4 mobs at production HP. */
const PER_ROOM_TIMEOUT_MS = 90_000;
/** Boss-room entry + clear budget. Boss has 600 HP; production 60-90s. */
const BOSS_CLEAR_TIMEOUT_MS = 240_000;
/** Click cadence */
const ATTACK_INTERVAL_MS = 220;
/** Boss room entry-sequence is 1.8 s. We give it 3.0 s headroom. */
const BOSS_WAKE_GRACE_MS = 3_000;

// Mob counts authored in resources/level_chunks/s1_roomNN.tres.
//
// Room 01 changed in PR #169 (Stage 2b tutorial): 2 grunts → 1 practice_dummy.
// The dummy spawns at world (368, 144) — far NE of player spawn (240, 200) —
// so the spec must walk NE while attacking to reach it (`clearRoom01Dummy`
// below). All other rooms still spawn Grunt/Charger/Shooter.
const ROOM_MOB_COUNTS = [
  1, // Room 01 (PR #169: 1 practice_dummy)
  2, // Room 02
  2, // Room 03 (grunt + charger)
  1, // Room 04 (shooter)
  3, // Room 05
  3, // Room 06
  4, // Room 07
  4, // Room 08
];
// Total for Rooms 02-08 only (those drive the gate-traversal flow); Room 01's
// dummy is counted separately because it does not contribute to the gate
// causality sweep (no RoomGate in Room 01).
const TOTAL_GATED_MOBS = ROOM_MOB_COUNTS.slice(1).reduce((a, b) => a + b, 0);
const TOTAL_PRE_BOSS_MOBS =
  TOTAL_GATED_MOBS + ROOM_MOB_COUNTS[0];

// Shooter count per room (authored in resources/level_chunks/s1_roomNN.tres).
// The Shooter is a ranged KITER — it walks AWAY from the player rather than
// chasing into melee (scripts/mobs/Shooter.gd § "Distance bands"). The
// default near-spawn click-spam in `clearRoomMobs` cannot land a hit on a
// kiter, so any room with a Shooter > 0 routes its Shooter kills through the
// `chaseAndClearKitingMobs` pursuit sub-helper instead.
//
// Room 04 is the only PURE-Shooter room — it is the AC4 hard wall the
// chase-then-return sub-helper exists to fix (ticket 86c9tz7zg). Rooms 06-08
// also contain Shooters; routing their Shooters through the same pursuit
// helper makes their clear deterministic rather than relying on the
// incidental "Grunt/Charger crowds the player so the Shooter is caught in
// the wedge by luck" behaviour that passed pre-fix.
const ROOM_SHOOTER_COUNTS = [
  0, // Room 01 (practice_dummy)
  0, // Room 02 (2 grunts)
  0, // Room 03 (grunt + charger)
  1, // Room 04 (1 shooter — PURE Shooter room)
  0, // Room 05 (2 grunts + charger)
  1, // Room 06 (2 chargers + 1 shooter)
  2, // Room 07 (2 chargers + 2 shooters)
  2, // Room 08 (grunt + charger + 2 shooters)
];

test.describe("AC4 — Stratum-1 boss reach + clear", () => {
  // **STATUS: still test.fail(). Rooms 02-05 clear + traverse end-to-end
  // deterministically after PR #207 + PR #208 + PR #212 + PR #224 +
  // PR (this) Room 03 case B-OUTSIDE finish-traversal (ticket 86c9utcb7).
  //
  // **What this PR (ticket 86c9utcb7) fixes — Room 03 case B-OUTSIDE:** PR
  // #251 diagnostic traces empirically showed that Charger knockback in
  // Room 03 deterministically drifts the player 10–20 px east of the gate
  // trigger east edge (X=72) at unlock instant. The game-side
  // `_fire_traversal_if_unlocked` (PR #230) cannot help because
  // `get_overlapping_bodies()` is empty at that moment — the gate correctly
  // emits `gate_unlocked` and waits for the player to walk back in. PR #239
  // had retired case B as a regression detector (correct for the B-INSIDE
  // sub-case PR #230 addresses), but that retirement was empirically too
  // aggressive for the B-OUTSIDE sub-case which is legitimate game-mechanic-
  // driven multi-outcome (per `team/tess-qa/playwright-harness-design.md`
  // §15 "Out of scope: game-mechanic-driven multi-outcome resolution",
  // directly analogous to Consumer 1 case B kept in `kiting-mob-chase.ts`).
  // This PR re-introduces a SPLIT case B in `gate-traversal.ts`:
  //   - B-INSIDE (player overlapping at unlock) → STILL throws (PR #230
  //     regression detector preserved)
  //   - B-OUTSIDE (player NOT overlapping at unlock) → staged-east +
  //     walk-west finish traversal (legitimate multi-outcome resolution)
  // The discriminator reads the Player.pos trace closest to the `_unlock`
  // line in the combat-phase slice. Room 03 is now deterministic on the
  // empirical N=2 PR #251 evidence; the Self-Test Report pins N=8/8.
  //
  // **What PR #212 (ticket 86c9u9neq) fixed:** the Room 06 harness blocker
  // (Shooter chase pre-pass roams player 100+px from spawn → 2-Charger
  // fixed-position click-spam misses). Added `returnPlayerToSpawn` between
  // the Shooter pre-pass and the chaser loop for all mixed Shooter+Chaser
  // rooms (06/07/08). Room 06 chaser-clear is now deterministic.
  //
  // **What this PR (ticket 86c9ujf5v) fixes — GAME-SIDE gate-unlock overlap:**
  // when combat knockback pushes the player INTO the gate trigger while mobs
  // are alive, `body_entered` fires the lock. If the player is still inside
  // the trigger when the last mob dies and `_unlock()` runs, Godot will NOT
  // re-emit `body_entered` — the gate is UNLOCKED but `gate_traversed` never
  // fires and the room counter never advances. `RoomGate._unlock` now calls
  // `get_overlapping_bodies()` after emitting `gate_unlocked`; if the player
  // is already inside, it defers `_fire_traversal_if_unlocked` to emit
  // `gate_traversed`. This is the Sponsor M2 W3 manual-soak "gate stuck after
  // mob clear" finding for Rooms 02, 06 — reproduced via the knockback-overlap
  // code path. The Playwright harness already handled this via preLineCount
  // case A/B/C (ticket 86c9ugfzv) — this fixes the game-side UX gap.
  //
  // **Remaining unknown:** whether Rooms 06-08 pass end-to-end on N≥8
  // release-build Playwright runs with both fixes in place. test.fail()
  // stays until N≥8 characterisation confirms it. See ticket 86c9ujf5v.**
  //
  // ---- What PR #183 fixed (verified — no longer the blocker) ----
  //
  // An earlier `test.fail()` comment described a Room 02 blocker: the
  // gate's `_mobs_alive` counter showed 1 after 2/2 grunt deaths, so
  // `lock()` never auto-unlocked. Root cause turned out to be
  // `MultiMobRoom._spawn_room_gate()` doing a synchronous Area2D
  // `add_child` from `_ready()` INSIDE a physics-flush window (Rooms
  // 02..08 are loaded from the prior room's `gate_traversed` → ... →
  // `_load_room_at_index` chain, rooted in a `body_entered` physics
  // callback). The Area2D add panicked (`USER ERROR: Can't change this
  // state while flushing queries`), the C++ early-returned, and the gate
  // was left improperly inserted — `is_inside_tree()` false, monitoring
  // never activated, zero `RoomGate.register_mob` traces. PR #183
  // (`d640330`, ticket 86c9tqvxx) deferred the Area2D-fixture pass
  // (`_spawn_room_gate` + `_spawn_healing_fountain` +
  // `_register_mobs_with_gate`) to
  // `call_deferred("_assemble_room_fixtures")`, landing it after the
  // flush. Rooms 02 + 03 (both chase-mob rooms) have traversed
  // end-to-end since #183 merged.
  //
  // ---- What PR #186 fixed (this branch — no longer the blocker) ----
  //
  // The PRIOR `test.fail()` comment named **Room 04** as the blocker: the
  // spec's `clearRoomMobs` helper was built on the premise "all mobs
  // chase, so even south/west spawns close to melee range" — true for
  // Grunt and Charger, but the **Shooter actively KITES**: it walks AWAY
  // from the player when the player closes below `KITE_RANGE` (see
  // `scripts/mobs/Shooter.gd` § "Distance bands"). Room 04's only mob is
  // a single Shooter, so near-spawn NE-facing click-spam never landed a
  // hit — `[ac4-boss] Room 04: only killed 0/1 mobs in 90000ms`.
  //
  // PR #186 (ticket 86c9tz7zg, this branch) adds the
  // `chaseAndClearKitingMobs` sub-helper (`tests/playwright/fixtures/
  // kiting-mob-chase.ts`): for any room with `ROOM_SHOOTER_COUNTS[i] > 0`
  // it reads the throttled `Player.pos` / `Shooter.pos` traces and steers
  // the player AT the kiter's live position until in swing range, then
  // click-spams the kill. `clearRoomMobs` now returns
  // `{ chaseTraversedGate }` — because a kiting Shooter retreats
  // *through* the RoomGate trigger rect, the pursuit routinely drives the
  // gate's full OPEN→LOCKED→UNLOCKED→traversed sequence as an emergent
  // consequence of cornering the kiter; when that happens the per-room
  // loop skips its own `gateTraversalWalk` and asserts the chase-driven
  // gate sequence instead. Room 04 (the only PURE-Shooter room) now
  // clears end-to-end.
  //
  // ---- What PR #198 fixed (this branch — the harness side of Room 05) --
  //
  // Ticket 86c9u05d7 was filed as a HARNESS problem: even with the Room 05
  // 3-concurrent-chaser room-LOAD freeze fixed (PR #191), the spec's
  // `clearRoomMobs` could not reliably clear a 3-mob room — its
  // fixed-position click-spam cleared Room 05 only 0/3–2/3 because one of
  // three concurrent chasers always drifted out of the fixed swing wedge.
  // PR #198 generalised the position-steered pursuit (built for kiting
  // Shooters in #186/#190) to chasers: `Grunt.gd`/`Charger.gd` now emit a
  // throttled `<Mob>.pos` trace, and `chaseAndClearMultiChaserRoom` reads
  // them to keep the player's facing locked on a live chaser. That harness
  // mechanism is correct and ready — but see the next section.
  //
  // ---- What PR #207 fixed (this branch, ticket 86c9u6uhg) ----
  //
  // Devon's PR #206 (AC4 balance pass — chaser damage trim + player iframes-
  // on-hit) made the player SURVIVE Room 05 deterministically. Pre-PR-#206
  // the player died inside Room 05 and the M1 death rule reloaded to Room 01
  // — which masked a SECOND, pre-existing bug:
  //
  // **The `StatAllocationPanel` auto-opens on the FIRST EVER `Levels.level_up`
  // signal (LU-05 in `team/uma-ux/level-up-panel.md`) and sets
  // `Engine.time_scale = 0.10` for the duration the panel is visible.** It
  // stays open until the player presses Enter / Esc / 1 / 2 / 3.
  //
  // In a release-build AC4 run the player crosses the L1→L2 threshold
  // (100 XP) precisely on the 3rd Room 05 chaser kill:
  //   Room 02:  2 grunts × 10 XP        =  20  →  20
  //   Room 03:  1 grunt + 1 charger     =  28  →  48
  //   Room 04:  1 shooter × 14          =  14  →  62
  //   Room 05:  +10 + +18 (mid-clear)  =  90
  //   Room 05:  3rd kill (+10)          = 100  → **L1→L2, panel auto-opens**
  //
  // From that frame on, `Engine.time_scale = 0.10` — every engine-time
  // clock, including `RoomGate._start_death_wait`'s 0.65 s timer and the
  // player's WALK_SPEED-driven movement, runs at 10× wall-time. The 0.65 s
  // gate-unlock takes 6.5 s wall to fire (well past the 2.5 s
  // `GATE_SETTLE_WINDOW_MS`), and every subsequent `gateTraversalWalk`
  // key-down at fixed wall-ms covers 10× less ground in game space, so
  // the player never reaches the trigger.
  //
  // The Playwright harness has no concept of "allocate a stat point," so
  // the panel stayed open for the rest of the test — exactly the
  // `gateUnlocked=false, gateTraversed=false` signature Devon characterised
  // 8/8 times in PR #206.
  //
  // **The fix (this PR):** the multi-chaser helper, the kiting Shooter
  // chase helper, AND the AC4 spec's fixed-position chaser loop now press
  // Escape 4× after the kill loop exits. KEY_ESCAPE is handled by
  // `StatAllocationPanel._unhandled_input` and closes the panel (banking
  // any unspent points). When no panel is open it's a no-op. This is
  // applied in three places for defensive coverage of any room that
  // might auto-open a panel:
  //   - `chaseAndClearKitingMobs` (Room 04 Shooter clear + Room 06-08
  //     Shooter pre-pass)
  //   - `chaseAndClearMultiChaserRoom` (Room 05 — where the bug surfaces
  //     today)
  //   - the AC4 spec's `clearRoomMobs` fixed-position chaser loop
  //     (Rooms 02-03, and the chaser portion of Rooms 06-08)
  //
  // Result: Rooms 02-05 now clear + traverse end-to-end deterministically
  // across release-build Playwright runs. **Note the dispatch's original
  // diagnosis ("RoomGate decrement chain bug, physics-flush family") was
  // wrong** — the gate's state machine works correctly under the time-
  // scaled clock; it's just slow. The harness-side panel-dismiss makes
  // the engine clock match the harness's wall-clock expectations.
  //
  // **Game-side hardening (also this PR, defensive):** the `RoomGate`
  // death-wait Timer was changed to `process_callback = TIMER_PROCESS_IDLE`
  // already, and a regression-pin GUT test (`test_room_gate_3mob_concurrent
  // _death_unlock`) pins that the gate unlocks correctly when 3 mobs die
  // in the same frame — even though that scenario was never the actual
  // failure mode. The pin guards against any future regression that
  // dropped one of three deferred decrements.
  //
  // ---- Why this spec STILL stays test.fail() ----
  //
  // Rooms 06-08 have not yet been verified N≥8 on a release build with both
  // PR #212 (return-to-spawn harness fix) and this PR's RoomGate overlap fix
  // in place. The game-side knockback-overlap bug fix (`RoomGate._unlock` →
  // `get_overlapping_bodies` → deferred `_fire_traversal_if_unlocked`) is
  // new in this PR — its effect on the Playwright trace sequence (case A/B/C
  // resolution) is not yet characterized empirically. test.fail() stays until
  // N≥8 release-build runs confirm Rooms 06-08 all traverse end-to-end.
  // Tracked by ticket 86c9ujf5v.
  test.fail(
    "AC4 — Stratum-1 boss reach + clear in ≤10min from cold start",
    async ({ page, context }) => {
      test.setTimeout(900_000); // 15 minutes — generous for full traversal + boss
      await context.route("**/*", (route) => route.continue());

      const capture = new ConsoleCapture(page);
      capture.attach();

      const baseURL =
        process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
      await page.goto(baseURL, { waitUntil: "domcontentloaded" });

      await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);
      // No `[Inventory] starter iron_sword auto-equipped` line — the PR #146
      // boot-equip bandaid is retired (ticket 86c9qbb3k). The player boots
      // fistless and equips by picking up the Room 01 dummy drop; the Room 01
      // phase below uses `clearRoom01Dummy` which handles the kill + pickup.

      const canvas = page.locator("canvas").first();
      await canvas.click();
      await page.waitForTimeout(500);

      const canvasBB = await canvas.boundingBox();
      const clickX = (canvasBB?.x ?? 0) + (canvasBB?.width ?? 1280) / 2;
      const clickY = (canvasBB?.y ?? 0) + (canvasBB?.height ?? 720) / 2;

      // ---- Helper: kill mobs in current room by N + NE click-spam ----
      //
      // **CRITICAL — KEEP COMBAT TIGHT (PR #171 finding 3):** This helper
      // is invoked from a context where the player MUST stay near
      // `DEFAULT_PLAYER_SPAWN = (240, 200)` so the subsequent
      // `gateTraversalWalk` has predictable W→N walk geometry. The prior
      // implementation cycled through 8 aim directions every 8 attacks and
      // accumulated 100+px of drift over a 21s clear.
      //
      // Mob spawn geometry (resources/level_chunks/s1_room0N.tres × tile_size_px=32):
      //   Room02 grunts at (272,112), (336,176)               — both NE/N of spawn
      //   Room03 grunt + charger at (240,112), (368,176)      — N/NE of spawn
      //   Room04 shooter at (400,112)                          — NE of spawn
      //   Room05 grunts + charger at (208,80), (240,208), (368,144)
      //                                                        — N, S, NE
      //   Room06 chargers + shooter at (208,80), (272,208), (400,144)
      //                                                        — N/NW, S, NE
      //   Room07 chargers + shooters at (176,112), (208,176), (368,80), (400,208)
      //                                                        — N/NW, N/W, NE, SE
      //   Room08 grunt + charger + shooters at (176,144), (240,80), (368,112), (400,208)
      //                                                        — W, N, NE, SE
      //
      // Grunt and Charger CHASE, so even south/west spawns close to melee
      // range. **The Shooter does NOT chase — it KITES** (walks AWAY when
      // the player closes below KITE_RANGE; see `scripts/mobs/Shooter.gd`
      // § "Distance bands") — so any room with Shooters routes its Shooter
      // kills through `chaseAndClearKitingMobs` (PR #186, ticket 86c9tz7zg).
      //
      // The fixed-position N+E click-spam below reliably clears the 2-mob
      // rooms (02, 03): both chasers crowd the player and sit in the swing
      // wedge. It does NOT reliably clear 3-mob rooms (05–08) — with 2+
      // concurrent chasers one routinely drifts out of the fixed wedge's
      // coverage (Room 05 cleared only 0/3–2/3 via this path). So for 2+
      // remaining chasers, `clearRoomMobs` routes them through
      // `chaseAndClearMultiChaserRoom` instead — the same position-steered
      // pursuit generalised to chasers (PR #198, ticket 86c9u05d7). The
      // fixed-position loop below is now only the path for ≤1 remaining
      // chaser.
      //
      // Cycling between N and NE facing covers mobs approaching from
      // either direction without inducing significant player drift (the
      // direction key for facing is held only ~80ms per cycle).
      // Result of `clearRoomMobs`. `chaseTraversedGate` is true when the
      // Shooter chase sub-helper roamed through the RoomGate trigger and
      // drove the gate all the way to `gate_traversed` — in which case the
      // per-room loop SKIPS its own `gateTraversalWalk` (the room counter
      // has already advanced).
      type ClearRoomResult = { chaseTraversedGate: boolean };

      const clearRoomMobs = async (
        roomLabel: string,
        expectedMobs: number,
        shooterCount: number = 0
      ): Promise<ClearRoomResult> => {
        console.log(
          `[ac4-boss] ${roomLabel}: clearing ${expectedMobs} mobs ` +
            `(${shooterCount} kiting Shooter(s) via chase sub-helper, ` +
            `rest via N + E alternating click-spam).`
        );

        // ---- Shooter-aware pre-pass: pursue + kill kiting mobs first ----
        //
        // The Shooter does NOT chase — it KITES (walks directly away from
        // the player's live position when the player closes below
        // KITE_RANGE; scripts/mobs/Shooter.gd § "Distance bands"). The
        // near-spawn click-spam loop below can never land a hit on a kiter,
        // so any room with shooterCount > 0 routes its Shooter kills through
        // chaseAndClearKitingMobs FIRST. That sub-helper reads the throttled
        // `Player.pos` / `Shooter.pos` traces and steers the player AT the
        // kiter's live position until in swing range, then click-spams the
        // kill (ticket 86c9tz7zg).
        //
        // A kiting Shooter retreats *wherever the player is not* — routinely
        // into the room's west end, through the RoomGate trigger rect. The
        // chase therefore CANNOT avoid the gate region; cornering the kiter
        // often means following it there, which drives the gate's full
        // OPEN→LOCKED→UNLOCKED→traversed sequence (a valid traversal — kill
        // the kiter while roaming, walk out the door). The helper reports
        // whether `gate_traversed` fired; when it did, this room's gate is
        // already done and the per-room loop skips `gateTraversalWalk`.
        let chaseTraversedGate = false;
        if (shooterCount > 0) {
          const chaseResult = await chaseAndClearKitingMobs(
            page,
            canvas,
            capture,
            roomLabel,
            shooterCount,
            clickX,
            clickY
          );
          chaseTraversedGate = chaseResult.gateTraversed;
        }

        const preDeathLines = capture
          .getLines()
          .filter((l) =>
            /\[combat-trace\] (Grunt|Charger|Shooter)\._die/.test(l.text)
          ).length;

        // If the room is pure-Shooter (e.g. Room 04), the chase pre-pass has
        // already cleared everything — skip the chase-mob click-spam loop.
        if (shooterCount >= expectedMobs) {
          console.log(
            `[ac4-boss] ${roomLabel}: all ${expectedMobs} mob(s) were ` +
              `kiting Shooters — cleared by the chase sub-helper ` +
              `(chaseTraversedGate=${chaseTraversedGate}).`
          );
          return { chaseTraversedGate };
        }

        // Chasers still to kill = total minus the Shooters the pre-pass
        // already cleared. `preDeathLines` snapshotted AFTER the chase
        // pre-pass, so `deathsNow - preDeathLines` below counts only NEW
        // (chaser) deaths — compare it against `chaserMobs`, not the full
        // `expectedMobs`, or a room with Shooters would never satisfy the
        // exit condition.
        const chaserMobs = expectedMobs - shooterCount;

        // ---- Return-to-spawn between chase pre-pass and chaser loop ----
        //
        // Ticket 86c9u9neq: in mixed Shooter+Chaser rooms (Room 06: 1
        // Shooter + 2 Chargers, Room 07: 2+2, Room 08: 1+1+2 grunt+charger
        // mix), the kiting-Shooter chase pre-pass roams the player wherever
        // the Shooter retreats — frequently ending in a corner 100+px from
        // `DEFAULT_PLAYER_SPAWN`. The fixed-position chaser loop below
        // assumes the player is near spawn so the click-spam wedge covers
        // the chargers as they crowd in; from a drifted corner position the
        // chargers' spawn locations (Room 06: (208,80), (272,208)) sit
        // OUTSIDE the player's swing wedge for the entire 90s budget,
        // producing the 0/2 chargers-killed failure shape the ticket
        // describes.
        //
        // **Extends PR #190's `chaseAndClearKitingMobs` return-to-spawn
        // pattern** to the SPEC's follow-on phase. The chase helper's own
        // case C `returnToSpawn` already fires when the chase did not drive
        // the gate — which is the always-taken branch in mixed rooms with
        // chargers alive (chargers register with the RoomGate and keep it
        // LOCKED through the Shooter kill until all chargers die). So this
        // spec-level call is normally idempotent. But it is belt-and-
        // suspenders coverage against any future chase path that bypasses
        // case C (e.g. case A / case B in a hypothetical mix where the gate
        // unexpectedly resolves while chasers are alive); the redundant
        // call costs only a few ms when the player is already at spawn.
        //
        // We also reset the player's facing by issuing the same N + E key
        // cycle the chaser loop expects — `returnPlayerToSpawn` ends with
        // movement keys released, which is exactly the precondition the
        // chaser loop's `page.keyboard.down(facing.key)` requires.
        //
        // Why only on `chaseTraversedGate === false`: when the chase DID
        // drive the gate, the room counter has advanced and the player has
        // been teleported to the next room's spawn — there's nothing to
        // return. (Also, in that branch the caller returns above without
        // running the chaser loop anyway.)
        if (shooterCount > 0 && !chaseTraversedGate) {
          console.log(
            `[ac4-boss] ${roomLabel}: returning player to spawn after ` +
              `Shooter chase pre-pass (Option A — ticket 86c9u9neq).`
          );
          await returnPlayerToSpawn(page, capture, roomLabel);
        }

        // ---- 3-chaser rooms: position-steered pursuit (ticket 86c9u05d7) --
        //
        // The fixed-position N/E click-spam loop below clears the 2-chaser
        // rooms (02, 03, and the chaser portion of 06–08) reliably — two
        // chasers crowd the player and sit in the swing wedge. It does NOT
        // reliably clear a 3-CHASER room: with 3 concurrent chasers, one
        // routinely drifts out of the fixed wedge's coverage (swing knockback
        // shoves mobs apart, the Charger's telegraph→charge cycle parks it
        // outside melee, a Grunt circling to the flank is never faced). Tess
        // characterised Room 05 (2 grunts + 1 charger — the ONLY 3-chaser
        // room) at 0/3–2/3 via the fixed-position path, never a deterministic
        // 3/3.
        //
        // For 3+ remaining chasers, route them through the SAME
        // position-steered pursuit the kiting-Shooter helper uses, now
        // generalised to chasers: it reads each chaser's `.pos` trace
        // (Grunt.pos / Charger.pos) and steers the player AT whichever
        // chaser is out of swing range, so a drifter is cornered rather than
        // left to wander. The helper steers the player back to spawn when
        // done, so the gateTraversalWalk below runs from its required
        // geometry. Chasers don't retreat through the gate, so this never
        // drives the gate sequence — the normal two-part walk still runs.
        //
        // The threshold is `>= 3`, not `>= 2`, deliberately: the
        // fixed-position path is PROVEN for the 2-chaser rooms (02, 03 have
        // traversed end-to-end since PR #183), and the multi-chaser helper
        // roams the player around the room — re-using it for a 2-chaser room
        // would trade a proven path for an unproven one with no determinism
        // gain (2 chasers reliably crowd the wedge). Only the genuine
        // 3-chaser case (Room 05) needs pursuit.
        if (chaserMobs >= 3) {
          const multiResult = await chaseAndClearMultiChaserRoom(
            page,
            canvas,
            capture,
            roomLabel,
            chaserMobs,
            clickX,
            clickY
          );
          // The multi-chaser pursuit roams the player enough that it can
          // drive the gate to `gate_traversed` itself (the player drifts
          // into the trigger during the engage, the gate auto-unlocks on
          // the last kill, and the helper's case-B finishTraversalFromUnlocked
          // completes the traversal). When that happens, propagate it so the
          // per-room loop SKIPS its own gateTraversalWalk — exactly like the
          // kiting-Shooter chase path.
          chaseTraversedGate = multiResult.gateTraversed;
          console.log(
            `[ac4-boss] ${roomLabel}: cleared ${chaserMobs} chaser mob(s) ` +
              `via position-steered multi-chaser pursuit ` +
              `(+${shooterCount} Shooter(s) cleared by chase pre-pass; ` +
              `chaseTraversedGate=${chaseTraversedGate}).`
          );
          return { chaseTraversedGate };
        }

        const roomStart = Date.now();
        // Cycle facing through N → E (single-key presses produce clean
        // single-direction facing; chord presses are unreliable across
        // Playwright key release ordering). 6 attacks per facing change
        // ≈ 1.3s per facing. Direction keys held only 100ms per cycle,
        // contributing ≤6px of drift per cycle — far below the ~50px
        // tolerance needed for the post-combat gate-traversal walk.
        //
        // N covers grunts approaching from north (Room02-08 all spawn
        // mobs north of player). E covers any mob that drifts east during
        // combat (e.g. knockback). Two facings is enough.
        let cycle = 0;
        const FACINGS: { key: string; label: string }[] = [
          { key: "w", label: "N" },
          { key: "d", label: "E" },
        ];
        const ATTACKS_PER_FACING = 6;

        while (Date.now() - roomStart < PER_ROOM_TIMEOUT_MS) {
          // Set facing for this cycle. Hold the direction key for 30ms
          // (~2 physics ticks at 60Hz) — long enough to register on
          // input_dir for a tick + facing update, short enough to
          // contribute negligible drift (30ms × 60px/s during STATE_ATTACK
          // ≈ 1.8px per cycle; 30 cycles = 54px tolerable for the gate
          // walk). Alternatives: each cycle could include a "walk back
          // toward spawn" correction, but the helper's gate-walk has its
          // own 50px tolerance built in.
          const facing = FACINGS[cycle % FACINGS.length];
          await page.keyboard.down(facing.key);
          await page.waitForTimeout(30);
          await page.keyboard.up(facing.key);
          await page.waitForTimeout(40);
          cycle++;

          for (let a = 0; a < ATTACKS_PER_FACING; a++) {
            await canvas.click({ position: { x: clickX, y: clickY } });
            await page.waitForTimeout(ATTACK_INTERVAL_MS);

            const deathsNow = capture
              .getLines()
              .filter((l) =>
                /\[combat-trace\] (Grunt|Charger|Shooter)\._die/.test(l.text)
              ).length;
            const roomKills = deathsNow - preDeathLines;
            if (roomKills >= chaserMobs) {
              // Dismiss any auto-opened panel (level-up auto-open pins
              // Engine.time_scale = 0.10 → gateTraversalWalk's key-down
              // walks cover 10× less ground → never reach the trigger).
              // Defensive: 4× Escape is cheap (~200 ms) and idempotent
              // when no panel is open. See ticket 86c9u6uhg — root cause
              // surfaced by PR #206's iframes-on-hit balance (player now
              // survives long enough to cross the L1→L2 XP threshold
              // mid-Room-05 instead of dying first).
              for (let p = 0; p < 4; p++) {
                await page.keyboard.press("Escape");
                await page.waitForTimeout(50);
              }
              console.log(
                `[ac4-boss] ${roomLabel}: cleared ${roomKills}/${chaserMobs} ` +
                  `chaser mob(s) at t=${Date.now() - roomStart}ms ` +
                  `(+${shooterCount} Shooter(s) cleared by chase pre-pass).`
              );
              return { chaseTraversedGate };
            }
          }
        }

        // Combat budget exhausted — record a meaningful failure.
        const deathsFinal = capture
          .getLines()
          .filter((l) =>
            /\[combat-trace\] (Grunt|Charger|Shooter)\._die/.test(l.text)
          ).length;
        const finalKills = deathsFinal - preDeathLines;
        throw new Error(
          `[ac4-boss] ${roomLabel}: only killed ${finalKills}/${chaserMobs} ` +
            `chaser mob(s) in ${PER_ROOM_TIMEOUT_MS}ms ` +
            `(${shooterCount} Shooter(s) handled separately by the chase ` +
            `pre-pass). Combat broke down — last 30 trace lines:\n` +
            capture
              .getLines()
              .slice(-30)
              .map((l) => `  ${l.text}`)
              .join("\n")
        );
      };

      // ---- Drive Room 01 (PR #169 tutorial dummy + iron_sword pickup) ----
      //
      // Room 01 ships 1 PracticeDummy at world (~368, 144). Ticket 86c9qbb3k:
      // the player boots FISTLESS. The clearRoom01Dummy helper walks the
      // player NE, attack-sweeps the dummy (3 FIST_DAMAGE=1 swings poof it),
      // THEN walks the player onto the dummy-dropped iron_sword Pickup.
      // Inventory.on_pickup_collected auto-equips it; the Room 01 -> Room 02
      // advance is GATED on that pickup-equip (Main._on_room01_mob_died holds
      // the advance while the player is fistless), so pickupEquipped must be
      // true before Room 02 loads -- and the player carries the iron_sword
      // into the rest of the boss-clear run.
      console.log(
        "[ac4-boss] Room 01 -- clearRoom01Dummy: kill the practice_dummy + " +
          "collect the dropped iron_sword Pickup (fistless onboarding)."
      );
      const room01Result = await clearRoom01Dummy(
        page,
        canvas,
        capture,
        clickX,
        clickY,
        { budgetMs: 90_000 }
      );
      expect(
        room01Result.dummyKilled,
        "[ac4-boss] Room 01: practice_dummy must die (3 fistless swings)."
      ).toBe(true);
      expect(
        room01Result.pickupEquipped,
        "[ac4-boss] Room 01: the dummy-dropped iron_sword Pickup must be " +
          "collected + auto-equipped. The Room 01 -> Room 02 advance is GATED " +
          "on this equip (ticket 86c9qbb3k) -- and every subsequent room of " +
          "the boss-clear run depends on the player being equipped."
      ).toBe(true);
      console.log(
        `[ac4-boss] Room 01: dummy killed + iron_sword equipped in ` +
          `${room01Result.durationMs}ms (${room01Result.attacksFired} attacks).`
      );

      // Settle frame for room load + player respawn at DEFAULT_PLAYER_SPAWN.
      // 1500ms covers Main._on_room_cleared deferred call + room scene load
      // + player teleport + STATE_ATTACK recovery clear (LIGHT_RECOVERY=0.18s).
      await page.waitForTimeout(1500);

      // ---- Drive Rooms 02-08 (RoomGate two-part walk pattern) ----
      for (let i = 1; i < 8; i++) {
        const roomLabel = `Room 0${i + 1}`;

        // Snapshot the FULL trace-buffer line count BEFORE the room's
        // combat phase begins. Passed to `gateTraversalWalk` as
        // `preRoomLineCount` so the helper can detect cross-phase gate
        // events (Case A/B/C resolution — ticket 86c9ugfzv). This solves
        // the Room 03 race where chaser knockback drifts the player into
        // the gate trigger DURING combat: the gate locks-and-unlocks
        // before the helper is called, and the helper's phase-3 assertion
        // (gate_unlocked must fire during walk-in) would otherwise throw.
        const preRoomLineCount = capture.getLines().length;

        // Snapshot gate-trace counts BEFORE clearing the room, so the
        // post-clear assertions are scoped to THIS room's gate lifecycle.
        const preRoomTraversedCount = capture
          .getLines()
          .filter((l) =>
            /\[combat-trace\] RoomGate\.gate_traversed/.test(l.text)
          ).length;
        const preRoomBodyEnteredCount = capture
          .getLines()
          .filter((l) =>
            /\[combat-trace\] RoomGate\._on_body_entered/.test(l.text)
          ).length;
        const preRoomUnlockedCount = capture
          .getLines()
          .filter((l) =>
            /\[combat-trace\] RoomGate\._unlock \| gate_unlocked emitting/.test(
              l.text
            )
          ).length;

        // Phase 1+2: clear all mobs. Chaser mobs (Grunt/Charger) are cleared
        // via tight near-spawn click-spam. Kiting Shooters
        // (ROOM_SHOOTER_COUNTS) are pursued by the chaseAndClearKitingMobs
        // sub-helper, which roams the room freely tracking the kiter — and
        // because a kiting Shooter retreats *through* the RoomGate trigger,
        // that pursuit routinely drives the gate's full
        // OPEN→LOCKED→UNLOCKED→traversed sequence as an emergent consequence
        // of cornering the kiter. `clearRoomMobs` surfaces that via
        // `chaseTraversedGate`.
        const { chaseTraversedGate } = await clearRoomMobs(
          roomLabel,
          ROOM_MOB_COUNTS[i],
          ROOM_SHOOTER_COUNTS[i]
        );

        if (chaseTraversedGate) {
          // ---- Gate was traversed by the chase itself ----
          //
          // The Shooter chase roamed through the gate trigger and drove the
          // gate to `gate_traversed` while cornering the kiter — a valid,
          // causally-ordered traversal (the gate auto-unlocks when the last
          // registered mob dies while LOCKED, then the player crossing the
          // trigger again fires `gate_traversed`). The room counter has
          // already advanced, so we MUST NOT call `gateTraversalWalk` (it
          // would operate on the NEXT room's still-locked gate). Instead,
          // assert the chase produced the correct gate trace sequence.
          console.log(
            `[ac4-boss] ${roomLabel}: gate traversed by the Shooter chase ` +
              `itself — skipping gateTraversalWalk, asserting gate sequence.`
          );

          const unlockedDelta =
            capture
              .getLines()
              .filter((l) =>
                /\[combat-trace\] RoomGate\._unlock \| gate_unlocked emitting/.test(
                  l.text
                )
              ).length - preRoomUnlockedCount;
          const traversedDelta =
            capture
              .getLines()
              .filter((l) =>
                /\[combat-trace\] RoomGate\.gate_traversed/.test(l.text)
              ).length - preRoomTraversedCount;

          expect(
            unlockedDelta,
            `${roomLabel}: chase-driven traversal must include exactly 1 ` +
              `gate_unlocked trace; got ${unlockedDelta}.`
          ).toBe(1);
          expect(
            traversedDelta,
            `${roomLabel}: chase-driven traversal must include exactly 1 ` +
              `gate_traversed trace (idempotency invariant — RoomGate.` +
              `_traversed_emitted guard); got ${traversedDelta}.`
          ).toBe(1);

          // Causality: gate_unlocked must precede gate_traversed (combat-
          // architecture.md §"State-change signals vs. progression triggers").
          const unlockTs = capture
            .getLines()
            .filter((l) =>
              /\[combat-trace\] RoomGate\._unlock \| gate_unlocked emitting/.test(
                l.text
              )
            )
            .map((l) => l.timestamp)
            .slice(-1)[0];
          const traversedTs = capture
            .getLines()
            .filter((l) =>
              /\[combat-trace\] RoomGate\.gate_traversed/.test(l.text)
            )
            .map((l) => l.timestamp)
            .slice(-1)[0];
          expect(
            unlockTs <= traversedTs,
            `${roomLabel}: gate_unlocked (${unlockTs}) must precede ` +
              `gate_traversed (${traversedTs}) even on a chase-driven ` +
              `traversal (causality invariant).`
          ).toBe(true);

          // Settle frame for room load + player respawn.
          await page.waitForTimeout(800);
          continue;
        }

        // ---- Normal path: drive the two-part gate-traversal walk ----
        //
        // The chase did not traverse the gate (chaser-only room, or the
        // Shooter chase happened to clear the kiter without crossing the
        // trigger). The gate is OPEN with `mobs_alive == 0` — the kill-first
        // precondition gateTraversalWalk expects.
        //
        // Negative-assertion (PR #155 cautionary tale): gate_traversed must
        // NOT have fired yet — we haven't walked into the gate trigger. If
        // it has fired, the state-change signal is short-circuiting to the
        // progression trigger.
        const preWalkTraversedCount = preRoomTraversedCount;
        const preWalkBodyEnteredCount = preRoomBodyEnteredCount;

        // Phases 3-5: drive the two-part walk pattern. Helper handles its
        // own internal assertions for _on_body_entered + gate_unlocked +
        // gate_traversed and throws with explicit drift diagnostics if the
        // walk fails to reach the trigger.
        //
        // **Case A/C resolution (ticket 86c9ugfzv, case B retired
        // 2026-05-16):** the helper accepts a `preRoomLineCount` snapshot
        // and resolves the gate's state by scanning the combat-phase slice.
        // Two outcomes:
        //   - Case A: gate auto-traversed during combat (chase + knockback
        //     drove the player through the trigger; OR PR #230's game-side
        //     `_fire_traversal_if_unlocked` deferred re-emit fired after the
        //     last mob death). Helper returns early; the spec asserts the
        //     causal sequence + skips the two-part walk.
        //   - Case C: neither `gate_unlocked` nor `gate_traversed` fired in
        //     the combat-phase slice — normal phase 3-5 two-part walk.
        //
        // **Case B retired** per the harness workaround convention
        // (PR #231 §4 #4 → `team/tess-qa/playwright-harness-design.md`
        // §15). The original case B silently steered the player to finish
        // a traversal `RoomGate._unlock()` had not auto-emitted; PR #230
        // (Drew, 86c9ujg8c) made the game emit `gate_traversed` deferred
        // from `_unlock()` when the player is overlapping. The case-B
        // preconditions now throw rather than silently resolve — fail
        // surfaces the regression instead of hiding it. The
        // `bodyEnteredFiredOnPhase3` assertion still applies only to
        // case C (case A short-circuits before phase 3).
        const result = await gateTraversalWalk(
          page,
          canvas,
          capture,
          roomLabel,
          { expectedSpawn: [240, 200], preRoomLineCount }
        );

        console.log(
          `[ac4-boss] ${roomLabel}: gateTraversalWalk resolved as ` +
            `case "${result.resolutionCase}" (gateUnlocked=${result.gateUnlocked}, ` +
            `gateTraversed=${result.gateTraversed}).`
        );

        // Devon PR #171 load-bearing positive signal: _on_body_entered must
        // have fired during phase 3 to prove the trigger was reached —
        // but only in case C ("open-walk"). Case A short-circuits before
        // phase 3 because the gate was already fully resolved during combat
        // (or via PR #230's deferred re-emit). Case B-INSIDE throws before
        // reaching this assertion. Case B-OUTSIDE ("unlocked-outside-finish")
        // does its own staged finish-traversal walk (no phase-3 path).
        if (result.resolutionCase === "open-walk") {
          expect(
            result.bodyEnteredFiredOnPhase3,
            `${roomLabel}: gateTraversalWalk should have fired ` +
              `RoomGate._on_body_entered during phase 3 (load-bearing positive ` +
              `signal that the trigger rect was reached). If false, prior ` +
              `combat likely drifted player away from DEFAULT_PLAYER_SPAWN.`
          ).toBe(true);
        }

        // Causality assertion: gate_unlocked + gate_traversed both observed.
        // (Applies to all three resolved cases — case A observed both events
        // during combat; case C observes them via phase 3 + phase 5;
        // case B-OUTSIDE observed gate_unlocked during combat and emits
        // gate_traversed via the staged finish-traversal walk.
        // Case B-INSIDE throws before reaching this assertion.)
        expect(
          result.gateUnlocked,
          `${roomLabel}: gateTraversalWalk should have observed gate_unlocked ` +
            `for this room's gate (case ${result.resolutionCase}).`
        ).toBe(true);
        expect(
          result.gateTraversed,
          `${roomLabel}: gateTraversalWalk should have observed gate_traversed ` +
            `for this room's gate (case ${result.resolutionCase}).`
        ).toBe(true);

        // body_entered count assertion: applies only to the normal
        // open-walk path (case C). The original purpose was to assert "the
        // player crossed the trigger twice — phase 3 lock + phase 5
        // traverse." Case A observed `gate_unlocked` + `gate_traversed`
        // empirically (the helper's `gateUnlocked` + `gateTraversed` checks
        // gate that), which independently proves the gate transitioned
        // LOCKED→UNLOCKED→TRAVERSED. The body_entered count is redundant
        // proof for case A.
        //
        // **Why we don't assert >= 2 across all cases (ticket 86c9ugfzv
        // N=2 sweep finding — original analysis pre-dated PR #230 + case B
        // retirement):** the `_on_body_entered → lock()` event can fire
        // DURING the room-load / settle window between the previous room's
        // `gate_traversed` and this room's `preRoomBodyEnteredCount`
        // snapshot — i.e. BEFORE the spec's count baseline. So the
        // body_entered count delta measured from `preRoomBodyEnteredCount`
        // → `postWalkBodyEnteredCount` is legitimately 0 even when the
        // gate fully transitioned (the trace exists, but is in `[0,
        // preRoomBodyEnteredCount)`, not in the measured window). The
        // `result.gateUnlocked` + `result.gateTraversed` assertions above
        // already prove the transition occurred; the body_entered count
        // assertion is redundant for case A.
        if (result.resolutionCase === "open-walk") {
          const postWalkBodyEnteredCount = capture
            .getLines()
            .filter((l) =>
              /\[combat-trace\] RoomGate\._on_body_entered/.test(l.text)
            ).length;
          const bodyEnteredDelta =
            postWalkBodyEnteredCount - preWalkBodyEnteredCount;
          expect(
            bodyEnteredDelta,
            `${roomLabel}: expected at least 2 _on_body_entered traces ` +
              `(phase 3 #1 + phase 5 #2); got ${bodyEnteredDelta}. ` +
              `If less than 2, the two-part walk pattern is breaking down.`
          ).toBeGreaterThanOrEqual(2);
        }

        // Negative assertion: gate_traversed count increased by exactly 1
        // (idempotency invariant — RoomGate._traversed_emitted guards
        // against double-emission).
        const postWalkTraversedCount = capture
          .getLines()
          .filter((l) =>
            /\[combat-trace\] RoomGate\.gate_traversed/.test(l.text)
          ).length;
        const traversedDelta = postWalkTraversedCount - preWalkTraversedCount;
        expect(
          traversedDelta,
          `${roomLabel}: expected exactly 1 new gate_traversed trace; got ` +
            `${traversedDelta}. Idempotency invariant violated (RoomGate.` +
            `_traversed_emitted guard regressed?).`
        ).toBe(1);

        // Settle frame for room load + player respawn at DEFAULT_PLAYER_SPAWN.
        await page.waitForTimeout(800);
      }

      // ---- Boss Room: entry sequence + boss kill ----
      console.log(
        "[ac4-boss] Entered Boss Room. Waiting for 1.8s entry sequence + boss wake..."
      );

      // POST-FIX (PR drew/m2-w1-boss-damage-attack-p0): Stratum1BossRoom._ready
      // now auto-fires the entry sequence on room load, so we don't need to
      // walk into the door trigger. Just wait the entry-sequence duration.
      await page.waitForTimeout(BOSS_WAKE_GRACE_MS);

      // Move toward boss (boss at (240,135), player at (240,200) → walk N)
      await page.keyboard.down("w");
      await page.waitForTimeout(600);
      await page.keyboard.up("w");

      // Spam attacks to kill boss.
      const bossStart = Date.now();
      let bossDied = false;

      while (Date.now() - bossStart < BOSS_CLEAR_TIMEOUT_MS) {
        await canvas.click({ position: { x: clickX, y: clickY } });
        await page.waitForTimeout(ATTACK_INTERVAL_MS);

        const bossDeathLine = capture
          .getLines()
          .find((l) =>
            /\[combat-trace\] Stratum1Boss\._force_queue_free \| freeing now/.test(
              l.text
            )
          );
        if (bossDeathLine) {
          bossDied = true;
          console.log(
            `[ac4-boss] Boss died at t=${Date.now() - bossStart}ms after entering boss room.`
          );
          break;
        }
      }

      // ---- Final assertions ----
      expect(
        bossDied,
        `Boss did not die within ${BOSS_CLEAR_TIMEOUT_MS}ms. The boss-fix ` +
          `code paths (PR drew/m2-w1-boss-damage-attack-p0) should have woken ` +
          `the boss on Stratum1BossRoom._ready's auto-trigger. Last 30 trace ` +
          `lines:\n` +
          capture
            .getLines()
            .slice(-30)
            .map((l) => `  ${l.text}`)
            .join("\n")
      ).toBe(true);

      // Negative assertion: zero physics-flush panics during the entire
      // 8-room run. PR #142/#143 regression class.
      const panicLine = capture.findUnexpectedLine(
        /Can't change this state while flushing queries/
      );
      expect(panicLine).toBeNull();

      // Total mob deaths should match TOTAL_PRE_BOSS_MOBS + 1 (boss).
      // Include PracticeDummy (Room 01 PR #169) in the death-trace pattern.
      const allDeaths = capture
        .getLines()
        .filter((l) =>
          /\[combat-trace\] (Grunt|Charger|Shooter|PracticeDummy|Stratum1Boss)\._die/.test(
            l.text
          )
        ).length;
      expect(allDeaths).toBeGreaterThanOrEqual(TOTAL_PRE_BOSS_MOBS);
      console.log(
        `[ac4-boss] Total mob deaths observed: ${allDeaths}/${TOTAL_PRE_BOSS_MOBS + 1} ` +
          `(${TOTAL_PRE_BOSS_MOBS} pre-boss + 1 boss).`
      );

      // Causality sweep across all rooms: every gate_traversed in the buffer
      // must have a preceding gate_unlocked in the same gate's lifecycle. We
      // assert pairs in observed order, since each room's gate is a fresh
      // instance (new node spawned on _load_room_at_index).
      const gateUnlockedTimes = capture
        .getLines()
        .filter((l) =>
          /\[combat-trace\] RoomGate\._unlock \| gate_unlocked emitting/.test(
            l.text
          )
        )
        .map((l) => l.timestamp);
      const gateTraversedTimes = capture
        .getLines()
        .filter((l) =>
          /\[combat-trace\] RoomGate\.gate_traversed/.test(l.text)
        )
        .map((l) => l.timestamp);

      // Rooms 02-08 = 7 gate traversals expected.
      expect(
        gateUnlockedTimes.length,
        `Expected 7 gate_unlocked traces (Rooms 02-08); got ${gateUnlockedTimes.length}.`
      ).toBe(7);
      expect(
        gateTraversedTimes.length,
        `Expected 7 gate_traversed traces (Rooms 02-08); got ${gateTraversedTimes.length}.`
      ).toBe(7);

      // For each gate_traversed, the matching gate_unlocked must precede it.
      for (let i = 0; i < gateTraversedTimes.length; i++) {
        const traversedTs = gateTraversedTimes[i];
        const unlockTs = gateUnlockedTimes[i];
        expect(
          unlockTs < traversedTs,
          `Gate ${i + 1}: gate_unlocked timestamp ${unlockTs} must precede ` +
            `gate_traversed timestamp ${traversedTs} (causality invariant — ` +
            `combat-architecture.md §"State-change signals vs. progression triggers").`
        ).toBe(true);
      }

      capture.detach();
    }
  );
});
