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
 * **CURRENT END-TO-END STATUS (origin/main `339a189`, PR #183 merged):**
 * Rooms 01, 02, 03 clear + traverse end-to-end (PR #183 fixed the Room 02
 * gate-registration blocker — verified). The spec then fails at **Room 04**
 * — the only PURE-Shooter room. `clearRoomMobs` assumes mobs chase into
 * melee; the Shooter KITES instead, so the near-spawn click-spam never
 * lands a hit. See the `test.fail()` block's STATUS comment for the full
 * analysis. The spec stays `test.fail()` until a Shooter-specific
 * chase-then-return sub-helper is added (AC4 residue, ticket 86c9qckrd).
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

import { test, expect } from "@playwright/test";
import { ConsoleCapture } from "../fixtures/console-capture";
import { gateTraversalWalk } from "../fixtures/gate-traversal";
import { chaseAndClearKitingMobs } from "../fixtures/kiting-mob-chase";
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
  // **STATUS: still test.fail() — but the blocker has MOVED AGAIN. The
  // Room 02 gate bug (PR #183) AND the Room 04 pure-Shooter kiting wall
  // (PR #186, this branch) are both FIXED; the current blocker is now
  // Room 05. Re-armed against origin/main `8885473` + this branch's
  // chase-helper commits.**
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
  // ---- The CURRENT blocker: Room 05 ----
  //
  // With Rooms 01–04 clearing deterministically, the spec now fails at
  // **Room 05** (2 grunts + 1 charger). This is a pre-existing failure
  // unmasked by #186's progress — NOT introduced by the chase helper
  // (Room 05 has `ROOM_SHOOTER_COUNTS[5] == 0`, so the chase pre-pass
  // does not even run for it). It is tracked separately as AC4 residue
  // under ticket **86c9u05d7** and is out of scope for PR #186, which
  // only owns getting the spec PAST Room 04.
  //
  // ---- Why this spec STAYS test.fail() (not split into test()) ----
  //
  // The spec is a single monolithic sequential test (cold-boot → Room 01
  // → ... → Room 08 → Boss). It cannot be cleanly split into a passing
  // `test()` half and a failing `test.fail()` half — Room 05 is step 5 of
  // 8 and everything after it depends on traversing it. Extracting
  // "Rooms 01-04 pass" into its own `test()` would require a second cold
  // boot and a partial-run harness the spec doesn't have. So the spec
  // stays `test.fail()`, but the comment now accurately names the CURRENT
  // blocker (Room 05, ticket 86c9u05d7) so the next person to fix it
  // flips the spec green knowingly — and no FIXED bug (#183's Room 02
  // gate, #186's Room 04 Shooter wall) is masked behind a stale
  // annotation.
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
      // range — the near-spawn N+E click-spam below kills them without the
      // player wandering. **The Shooter does NOT chase — it KITES** (walks
      // AWAY when the player closes below KITE_RANGE; see
      // `scripts/mobs/Shooter.gd` § "Distance bands"). This helper therefore
      // CANNOT clear a pure-Shooter room — most notably **Room 04**, whose
      // only mob is one Shooter. Rooms 05-08 contain Shooters too, but their
      // Grunts/Chargers keep the player engaged near spawn while the Shooter
      // is incidentally caught in the wedge. Room 04 is the spec's current
      // hard wall (see the `test.fail()` STATUS comment); fixing it needs a
      // Shooter-specific chase-then-return sub-helper (AC4 residue,
      // ticket 86c9qckrd).
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
        const result = await gateTraversalWalk(
          page,
          canvas,
          capture,
          roomLabel,
          { expectedSpawn: [240, 200] }
        );

        // Devon PR #171 load-bearing positive signal: _on_body_entered must
        // have fired during phase 3 to prove the trigger was reached. This
        // is the assertion that distinguishes "harness drifted away from
        // spawn" from "state-machine regression".
        expect(
          result.bodyEnteredFiredOnPhase3,
          `${roomLabel}: gateTraversalWalk should have fired ` +
            `RoomGate._on_body_entered during phase 3 (load-bearing positive ` +
            `signal that the trigger rect was reached). If false, prior ` +
            `combat likely drifted player away from DEFAULT_PLAYER_SPAWN.`
        ).toBe(true);

        // Causality assertion: gate_unlocked + gate_traversed both observed.
        expect(
          result.gateUnlocked,
          `${roomLabel}: gateTraversalWalk should have fired gate_unlocked ` +
            `during phase 3 (body_entered #1).`
        ).toBe(true);
        expect(
          result.gateTraversed,
          `${roomLabel}: gateTraversalWalk should have fired gate_traversed ` +
            `during phase 5 (body_entered #2).`
        ).toBe(true);

        // body_entered must have fired AT LEAST twice during this room's
        // traversal (phase 3 lock-and-unlock + phase 5 traverse). The exact
        // count depends on whether the player crossed the trigger boundary
        // during phase 4's east-walk-out; >= 2 is the load-bearing invariant.
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
