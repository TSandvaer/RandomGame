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
 *   - Room 01 (no gate): both grunts auto-advance the room counter on death
 *     via `_install_room01_clear_listener` (Main.gd). Player.facing NE,
 *     click-spam until 2 Grunt._die.
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

test.describe("AC4 — Stratum-1 boss reach + clear", () => {
  // **STATUS: still test.fail() pending a new game-side investigation.**
  //
  // PR `tess/m2-w1-ac4-drift-fix` landed all the harness-drift fixes that
  // Devon's PR #171 investigation prescribed:
  //   - clearRoomMobs uses tight N+E facing alternation (no aim-sweep,
  //     minimal direction-key holds) keeping the player near
  //     DEFAULT_PLAYER_SPAWN.
  //   - gateTraversalWalk accepts an `expectedSpawn` parameter and
  //     asserts on `RoomGate._on_body_entered` (load-bearing positive
  //     signal Devon added in PR #171) before checking gate_unlocked.
  //   - Room01 phase walks NE then E then sweeps to kill the
  //     PR #169 tutorial practice_dummy at world (368, 144).
  //
  // Empirical run on origin/main 1c2438e (post-PR-#171) demonstrates the
  // harness drift fix works as designed: Room01 dummy dies in ~12s,
  // Room02 grunts die (cleared 2/2), and the gate's `_on_body_entered`
  // trace fires reliably when the player walks from spawn-area into
  // the trigger rect.
  //
  // **NEW BLOCKER (out of scope for this PR — needs game-side dispatch):**
  // After clearing Room02, the gate's `_mobs_alive` counter shows 1, not
  // 0. Trace evidence from the empirical run:
  //   `[combat-trace] RoomGate._on_body_entered | body=CharacterBody2D
  //    state=open mobs_alive=1`
  // This blocks `lock()` from auto-unlocking (mobs_alive>0 keeps state
  // LOCKED awaiting a mob_died decrement). The player walked into the
  // trigger from drift-near-spawn (helper's discipline worked); both
  // grunts emitted `Grunt._die` (clearRoomMobs's death counter saw 2/2);
  // but the gate's count is desync'd at 1.
  //
  // Possible game-side root causes (Devon investigation candidates):
  //   - One grunt's `mob_died` signal didn't connect to the gate's
  //     `_on_mob_died` handler (race during MultiMobRoom's
  //     `_register_mobs_with_gate` call order).
  //   - The grunt got knocked into a wall corner where its `_die` chain
  //     completed but `mob_died.emit` was queued AFTER node freeing.
  //   - LevelAssembler.assemble_single appends mobs to `result.mobs`
  //     AFTER `add_child`; if `_ready` synchronously fires anything
  //     observable, registration timing could be off-by-one.
  //
  // Until that's investigated and patched, this spec stays test.fail().
  // The harness-side improvements are still landed because they are
  // necessary regardless — the helper's failure messages now correctly
  // distinguish "drift" (no body_entered) from "state-machine" (body_entered
  // but no gate_unlocked) failures, which is what surfaced this game-side
  // bug in the first place.
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
      await capture.waitForLine(
        /\[Inventory\] starter iron_sword auto-equipped \(weapon slot\)/,
        5_000
      );

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
      // All mobs chase, so even south/west spawns close to melee range.
      // Cycling between N and NE facing covers mobs approaching from
      // either direction without inducing significant player drift (the
      // direction key for facing is held only ~80ms per cycle).
      const clearRoomMobs = async (
        roomLabel: string,
        expectedMobs: number
      ): Promise<void> => {
        console.log(
          `[ac4-boss] ${roomLabel}: clearing ${expectedMobs} mobs ` +
            `(N + NE alternating facing, click-only, NO walk).`
        );

        const preDeathLines = capture
          .getLines()
          .filter((l) =>
            /\[combat-trace\] (Grunt|Charger|Shooter)\._die/.test(l.text)
          ).length;

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
            if (roomKills >= expectedMobs) {
              console.log(
                `[ac4-boss] ${roomLabel}: cleared ${roomKills}/${expectedMobs} ` +
                  `at t=${Date.now() - roomStart}ms.`
              );
              return;
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
          `[ac4-boss] ${roomLabel}: only killed ${finalKills}/${expectedMobs} ` +
            `mobs in ${PER_ROOM_TIMEOUT_MS}ms. Combat broke down — last 30 ` +
            `trace lines:\n` +
            capture
              .getLines()
              .slice(-30)
              .map((l) => `  ${l.text}`)
              .join("\n")
        );
      };

      // ---- Drive Room 01 (PR #169 tutorial dummy at far-NE of spawn) ----
      //
      // Room 01 changed in PR #169 from 2 grunts to 1 practice_dummy. The
      // dummy spawns at world (368, 144), which is 128px east + 56px north
      // of player spawn (240, 200) — well outside attack range. Unlike the
      // grunt scenario, the dummy doesn't chase, so the player MUST walk
      // up to the dummy and stop alongside it before attacking.
      //
      // Pattern (validated via screenshot diagnosis of prior failure runs):
      //   Phase A: walk-burst NE for ~1.7s (no clicks) — covers the ~140px
      //     NE distance from spawn at full WALK_SPEED=120px/s × NE-component
      //     0.707 = 85px/s/axis × 1.7s ≈ 144px on each axis. Lands player
      //     near the dummy.
      //   Phase B: attack-spam in 4 directions (NE, E, N, NW). Player's
      //     swing reach is 28px + radius 18 = 46px effective hit range.
      //     The dummy could be on any side relative to where the walk
      //     ended (overshoot/undershoot), so cycling through 4 directions
      //     guarantees the swing wedge overlaps the dummy. Each direction
      //     click-spammed for 4 attacks (HP=3, damage=6 → 1 hit kills).
      //   Phase C: if not dead, walk a small correction burst SW briefly
      //     (in case we overshot too far NE), then re-attack. Safety net.
      //
      // Why we can't combine walk + attack: holding w+d + clicking at the
      // same time empirically does not produce net player displacement
      // (Playwright canvas.click stabilization may interfere with held
      // keys). Splitting into pure-walk and pure-attack phases produces
      // observable progress.
      //
      // Detection: PR #169 emits `[combat-trace] PracticeDummy._die |
      // starting death sequence` on death. Main._install_room01_clear_listener
      // hooks the `mob_died` signal and auto-loads Room 02 on death — no
      // RoomGate involvement, no body_entered required.
      const ROOM01_BUDGET_MS = 90_000;
      console.log(
        "[ac4-boss] Room 01 — walk-NE then 4-direction attack-sweep to " +
          "kill practice_dummy at world (368, 144)."
      );

      const room01Start = Date.now();
      const preRoom01DummyDeaths = capture
        .getLines()
        .filter((l) => /\[combat-trace\] PracticeDummy\._die/.test(l.text))
        .length;
      let dummyKilled = false;

      const checkDummyDead = () =>
        capture
          .getLines()
          .filter((l) => /\[combat-trace\] PracticeDummy\._die/.test(l.text))
          .length > preRoom01DummyDeaths;

      // Attack-sweep helper for Room 01 only — cycles through 4 directions
      // and click-spams each. Local to Room 01 because Rooms 02-08 use the
      // tight NE-only clearRoomMobs (chasing mobs handle the geometry).
      const attackSweep = async (
        directions: { keys: string[]; label: string }[],
        attacksPerDir: number
      ): Promise<boolean> => {
        for (const dir of directions) {
          // Set facing via direction-key chord (release in reverse order
          // so the final input_dir tick is the chord, not a single key).
          for (const k of dir.keys) await page.keyboard.down(k);
          await page.waitForTimeout(80);
          for (const k of [...dir.keys].reverse()) await page.keyboard.up(k);
          await page.waitForTimeout(80);

          for (let a = 0; a < attacksPerDir; a++) {
            await canvas.click({ position: { x: clickX, y: clickY } });
            await page.waitForTimeout(ATTACK_INTERVAL_MS);
            if (checkDummyDead()) return true;
          }
        }
        return false;
      };

      // Geometry plan: From spawn (240, 200) → dummy (368, 144).
      // Distance = 128 east + 56 north = 140px on the diagonal. At
      // WALK_SPEED=120px/s pure-axis, separate-axis walks land precisely:
      //   - Pure N for 56/120 = 0.47s → Y reaches 144.
      //   - Pure E for 128/120 = 1.07s → X reaches 368.
      // Walking N first then E lands player at (368, 144) — same tile as
      // dummy. Body radius = 10, hitbox radius = 18, dummy body radius
      // ≈ 10 → swing wedge always overlaps dummy regardless of facing.
      //
      // We use slightly-longer durations (700ms N, 1300ms E) for safety
      // against any ticks that don't register movement. The room walls
      // clamp overshoots, so even if we walk past target, we end up
      // adjacent to the wall near the dummy's tile column / row.
      //
      // Why separate axes (not diagonal): empirical evidence from prior
      // runs (screenshot inspection) showed diagonal walks land the
      // player wildly past the dummy due to walk-speed × diagonal
      // overshoot. Pure-axis walks are easier to predict.
      const SWEEP_DIRECTIONS: { keys: string[]; label: string }[] = [
        { keys: ["w"], label: "N" },
        { keys: ["w", "d"], label: "NE" },
        { keys: ["d"], label: "E" },
        { keys: ["s", "d"], label: "SE" },
        { keys: ["s"], label: "S" },
        { keys: ["s", "a"], label: "SW" },
        { keys: ["a"], label: "W" },
        { keys: ["w", "a"], label: "NW" },
      ];

      // ---- Phase A: walk pure N for 700ms ----
      console.log("[ac4-boss] Room 01: phase A — walk pure N (700ms).");
      await page.keyboard.down("w");
      await page.waitForTimeout(700);
      await page.keyboard.up("w");
      await page.waitForTimeout(150);

      if (checkDummyDead()) dummyKilled = true;

      // ---- Phase B: walk pure E for 1300ms ----
      if (!dummyKilled) {
        console.log("[ac4-boss] Room 01: phase B — walk pure E (1300ms).");
        await page.keyboard.down("d");
        await page.waitForTimeout(1300);
        await page.keyboard.up("d");
        await page.waitForTimeout(150);
        if (checkDummyDead()) dummyKilled = true;
      }

      // ---- Phase C: 8-direction sweep, 3 attacks each ----
      if (!dummyKilled) {
        console.log("[ac4-boss] Room 01: phase C — 8-dir sweep × 3 attacks.");
        dummyKilled = await attackSweep(SWEEP_DIRECTIONS, 3);
      }

      // ---- Phase D: small position correction + retry sweep (in case
      // walls clamped player far from dummy) ----
      if (!dummyKilled && Date.now() - room01Start < ROOM01_BUDGET_MS - 8_000) {
        console.log(
          "[ac4-boss] Room 01: phase D — small SW correction + sweep retry."
        );
        // 200ms SW = ~17px on each axis. Nudges player slightly off any wall
        // they may be pinned against.
        await page.keyboard.down("s");
        await page.keyboard.down("a");
        await page.waitForTimeout(200);
        await page.keyboard.up("a");
        await page.keyboard.up("s");
        await page.waitForTimeout(150);

        dummyKilled = await attackSweep(SWEEP_DIRECTIONS, 3);
      }

      // ---- Phase E: walk back N+E in case phase B didn't register ----
      if (!dummyKilled && Date.now() - room01Start < ROOM01_BUDGET_MS - 8_000) {
        console.log(
          "[ac4-boss] Room 01: phase E — extra E+N walk + sweep retry."
        );
        await page.keyboard.down("w");
        await page.waitForTimeout(500);
        await page.keyboard.up("w");
        await page.waitForTimeout(100);
        await page.keyboard.down("d");
        await page.waitForTimeout(800);
        await page.keyboard.up("d");
        await page.waitForTimeout(150);

        dummyKilled = await attackSweep(SWEEP_DIRECTIONS, 3);
      }

      if (dummyKilled) {
        console.log(
          `[ac4-boss] Room 01: practice_dummy killed at t=${Date.now() - room01Start}ms.`
        );
      }

      if (!dummyKilled) {
        throw new Error(
          `[ac4-boss] Room 01: practice_dummy did not die within ` +
            `${ROOM01_BUDGET_MS}ms across phases A-E. Player likely never ` +
            `reached the dummy at world (368, 144). Check screenshot for ` +
            `player position. Last 30 trace lines:\n` +
            capture
              .getLines()
              .slice(-30)
              .map((l) => `  ${l.text}`)
              .join("\n")
        );
      }

      // Settle frame for room load + player respawn at DEFAULT_PLAYER_SPAWN.
      // 1500ms covers Main._on_room_cleared deferred call + room scene load
      // + player teleport + STATE_ATTACK recovery clear (LIGHT_RECOVERY=0.18s).
      await page.waitForTimeout(1500);

      // ---- Drive Rooms 02-08 (RoomGate two-part walk pattern) ----
      for (let i = 1; i < 8; i++) {
        const roomLabel = `Room 0${i + 1}`;

        // Phase 1+2: clear all mobs (gate stays OPEN with mobs_alive==0).
        // Combat is tight (NE-facing only, click-only, no aim-sweep) so the
        // player stays near DEFAULT_PLAYER_SPAWN for the gate walk below.
        await clearRoomMobs(roomLabel, ROOM_MOB_COUNTS[i]);

        // Negative-assertion (PR #155 cautionary tale): gate_traversed must
        // NOT have fired yet — we haven't walked into the gate trigger. If
        // it has fired, the state-change signal is short-circuiting to the
        // progression trigger. Snapshot trace count BEFORE the helper drives
        // the walk, so we can scope the assertion to the right window.
        const preWalkTraversedCount = capture
          .getLines()
          .filter((l) =>
            /\[combat-trace\] RoomGate\.gate_traversed/.test(l.text)
          ).length;
        const preWalkBodyEnteredCount = capture
          .getLines()
          .filter((l) =>
            /\[combat-trace\] RoomGate\._on_body_entered/.test(l.text)
          ).length;

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
