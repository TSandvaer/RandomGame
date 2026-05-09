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
 * **Status: green (`test`).**
 *
 * History — this spec was previously `test.fail()` because of two distinct
 * spec-mechanics bugs that have NOW BEEN FIXED in this PR:
 *
 *   1. Gate trigger Y-band missed player spawn Y. RoomGate trigger occupies
 *      world-coords X∈[24,72], Y∈[104,184]. Player spawn (240, 200) is 16px
 *      south of the band AND 168px east of the X range. A pure-west walk
 *      from spawn never intersected the trigger. Fixed: switched to
 *      diagonal NW walks that satisfy both axes simultaneously.
 *
 *   2. RoomGate state machine requires TWO distinct body_entered events
 *      (lock-trigger → unlock-via-mob-death → traverse). In Godot 4,
 *      `body_entered` is a non-overlap → overlap transition event — a
 *      continuous walk through the trigger fires it ONCE. Fixed: introduced
 *      `gateTraversalWalk` fixture in `fixtures/gate-traversal.ts` that drives
 *      the body in-out-in pattern (walk NW into trigger, walk SE out, walk
 *      NW back in) producing two separate body_entered events.
 *
 * The boss P0s (86c9q96fv damage broken; 86c9q96ht attack broken) were
 * fixed earlier in PR drew/m2-w1-boss-damage-attack-p0 — Stratum1BossRoom._ready
 * now `call_deferred("trigger_entry_sequence")` so the boss reliably wakes
 * regardless of how the player arrives in the room.
 *
 * Per-room navigation strategy:
 *   - Room 01 (no gate): both grunts auto-advance the room counter on death
 *     via `_install_room01_clear_listener` (Main.gd). Player.facing NE,
 *     click-spam until 2 Grunt._die.
 *   - Rooms 02-08 (RoomGate at (48,144), size (48,80)):
 *       a. Combat — kill all mobs via NE-facing click-spam (mobs spawn
 *          NE/N of player so combat happens far from the gate trigger).
 *       b. Traversal — call gateTraversalWalk(...) to drive the two-part
 *          walk pattern (NW-in → SE-out → NW-in) producing the body_entered
 *          #1 (gate_unlocked) and body_entered #2 (gate_traversed) events.
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
const ROOM_MOB_COUNTS = [
  2, // Room 01
  2, // Room 02
  2, // Room 03 (grunt + charger)
  1, // Room 04 (shooter)
  3, // Room 05
  3, // Room 06
  4, // Room 07
  4, // Room 08
];
const TOTAL_PRE_BOSS_MOBS = ROOM_MOB_COUNTS.reduce((a, b) => a + b, 0);

test.describe("AC4 — Stratum-1 boss reach + clear", () => {
  test(
    "AC4 — Stratum-1 boss reach + clear (boss P0s + spec gate-traversal mechanics fixed)",
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

      // ---- Helper: kill mobs in current room by NE click-spam ----
      //
      // For Room 02-08 traversal we DO NOT walk to the gate during combat.
      // Combat happens around DEFAULT_PLAYER_SPAWN — mobs spawn NE/N of the
      // player so they close on us. Once mobs are dead we hand off to
      // gateTraversalWalk for the two-part walk pattern. Keeping combat and
      // traversal in separate phases simplifies failure-mode triage.
      const clearRoomMobs = async (
        roomLabel: string,
        expectedMobs: number
      ): Promise<void> => {
        console.log(
          `[ac4-boss] ${roomLabel}: clearing ${expectedMobs} mobs (no gate-walk yet).`
        );

        // Set facing NE for first attack (matches grunt geometry — mobs spawn
        // NE/N in every room — see resources/level_chunks/s1_room0N.tres).
        await page.keyboard.down("w");
        await page.keyboard.down("d");
        await page.waitForTimeout(100);
        await page.keyboard.up("w");
        await page.keyboard.up("d");
        await page.waitForTimeout(400);

        const preDeathLines = capture
          .getLines()
          .filter((l) =>
            /\[combat-trace\] (Grunt|Charger|Shooter)\._die/.test(l.text)
          ).length;

        const roomStart = Date.now();
        let aimCycle = 0;
        const aimSequence: string[][] = [
          ["w", "d"], // NE
          ["w"], // N
          ["w", "a"], // NW
          ["a"], // W
          ["s", "a"], // SW
          ["s"], // S
          ["s", "d"], // SE
          ["d"], // E
        ];

        while (Date.now() - roomStart < PER_ROOM_TIMEOUT_MS) {
          // Re-aim every 8 attacks to sweep the room.
          if (aimCycle % 8 === 0) {
            const dirs = aimSequence[(aimCycle / 8) % aimSequence.length];
            for (const k of dirs) await page.keyboard.down(k);
            await page.waitForTimeout(40);
            for (const k of dirs) await page.keyboard.up(k);
            await page.waitForTimeout(20);
          }
          aimCycle++;

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

      // ---- Drive Room 01 (no gate — auto-advance on last grunt death) ----
      console.log("[ac4-boss] Room 01 — auto-advance (no RoomGate).");
      await clearRoomMobs("Room 01", ROOM_MOB_COUNTS[0]);
      // Settle frame for room load + player respawn at DEFAULT_PLAYER_SPAWN
      await page.waitForTimeout(800);

      // ---- Drive Rooms 02-08 (RoomGate two-part walk pattern) ----
      for (let i = 1; i < 8; i++) {
        const roomLabel = `Room 0${i + 1}`;

        // Phase 1+2: clear all mobs (gate stays OPEN with mobs_alive==0).
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

        // Phases 3-5: drive the two-part walk pattern (helper handles its
        // own internal assertions for gate_unlocked + gate_traversed).
        const result = await gateTraversalWalk(page, canvas, capture, roomLabel);

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
      const allDeaths = capture
        .getLines()
        .filter((l) =>
          /\[combat-trace\] (Grunt|Charger|Shooter|Stratum1Boss)\._die/.test(
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
