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
 * **Status: test.fail() — but the two underlying P0s are FIXED in PR
 * `drew/m2-w1-boss-damage-attack-p0`:**
 *   - 86c9q96fv (boss damage broken)        — FIXED via Stratum1BossRoom auto-trigger
 *   - 86c9q96ht (boss attack broken)        — FIXED via same root cause
 *
 * Root cause of the original P0s (single, both bugs collapsed): boss spawned
 * in STATE_DORMANT and only woke when the player crossed the boss-room door-
 * trigger Area2D at (240, 250). But `Main._load_room_at_index` teleports the
 * player to (240, 200) — ABOVE the trigger — and never fires `body_entered`.
 * With the boss stuck dormant, `take_damage` was rejected (Stratum1Boss.gd:332)
 * AND `_physics_process` skipped all AI (Stratum1Boss.gd:361-365).
 *
 * Fix: `Stratum1BossRoom._ready` now `call_deferred("trigger_entry_sequence")`,
 * so the entry sequence auto-fires on room load. The 1.8 s narrative beat
 * + door-trigger fallback are preserved (idempotent guards).
 *
 * **Why this spec is still `test.fail()` after the P0 fix:** the original AC4
 * spec authored in PR #156 has separate, pre-existing room-traversal bugs
 * unrelated to the boss P0s — specifically, the gate trigger Area2D at
 * y=[104,184] doesn't intersect the player's spawn Y=200, and the
 * RoomGate.gd state machine requires two distinct body_entered events
 * (lock → unlock → traverse) which the spec's keyboard-driven walk pattern
 * doesn't reliably produce. These bugs were masked by `test.fail()` since
 * the spec was always failing on either the room-traversal step or the
 * boss-broken step.
 *
 * Verification of the P0 fix is via the new GUT integration tests in
 * `tests/integration/test_boss_wakes_and_engages.gd` (real Hitbox spawn +
 * real CharacterBody2D Player). The end-to-end browser-soak verification
 * is gated on a follow-up Tess dispatch to fix the spec's gate-traversal
 * mechanics. Sponsor's manual M1 RC re-soak 6 will validate the boss
 * fix in the actual play loop independently of this spec.
 *
 * Diagnostic-build env-var hook (proposed, NOT yet implemented):
 *   The boss has 600 HP. iron_sword does 6 damage/swing → 100 swings ≈ 22 s
 *   at 220ms cadence (theoretical floor). Realistic with telegraphs +
 *   movement: 60-90 s in production. AC4's hard ceiling is 10 minutes.
 *   If the test budget needs further compression, propose adding to
 *   scripts/mobs/Stratum1Boss.gd:
 *     ```
 *     # In _ready (after _apply_mob_def call):
 *     if OS.has_feature("web") and OS.has_environment("EMBERGRAVE_DIAG_BOSS_HP"):
 *         var diag_hp := OS.get_environment("EMBERGRAVE_DIAG_BOSS_HP").to_int()
 *         if diag_hp > 0:
 *             hp_max = diag_hp
 *             hp_current = diag_hp
 *             print("[Stratum1Boss] DIAG override hp_max=%d" % diag_hp)
 *     ```
 *   This is a game-script change — orchestrator approval required before
 *   landing. Currently the spec runs at production HP with a 9-minute budget
 *   (well under the 10-min AC ceiling, leaves room for harness overhead).
 *
 * Per-room navigation strategy:
 *   - Room 01 (no gate): both grunts auto-advance the room counter on death.
 *     Player.facing NE, click-spam until 2 Grunt._die.
 *   - Room 02-07 (RoomGate at (48,144)): kill all mobs, walk WEST through
 *     gate. Player spawn (240,200) → walk to gate at (48,144) requires
 *     pressing 'a' (west) for ~3.3s at 120 px/s walk speed.
 *   - Room 08 (last gate): same pattern, exits to Boss Room.
 *   - Boss Room: enter — player spawns at (240,200). Boss is at (240,135),
 *     ~65px north. Door trigger at (240,250) is south of spawn. Walking
 *     toward boss = north (w). 1.8s entry sequence runs, then boss wakes.
 *
 * Mob composition per room (from resources/level_chunks/s1_room0N.tres):
 *   Room 02: 2 grunts
 *   Room 03: 1 grunt + 1 charger
 *   Room 04: 1 shooter
 *   Room 05: 2 grunts + 1 charger
 *   Room 06: 2 chargers + 1 shooter
 *   Room 07: 2 chargers + 2 shooters
 *   Room 08: 1 grunt + 1 charger + 2 shooters
 *
 * Each room has its own gate-traversed signature in the trace stream:
 *   `[combat-trace] RoomGate._unlock | gate_unlocked emitting...`
 *   `[combat-trace] RoomGate.gate_traversed | player walked through open door...`
 *
 * Negative-assertion sweep (per dispatch §5 + combat-architecture.md
 * §"State-change signals vs. progression triggers"):
 *   For each room transition: assert `gate_unlocked` fires BEFORE
 *   `gate_traversed` and that the room counter does NOT advance until
 *   `gate_traversed` fires.
 *
 * References:
 *   - team/uma-ux/sponsor-soak-checklist-v2.md §5 AC4
 *   - team/tess-qa/playwright-harness-design.md §5 deferred AC4
 *   - .claude/docs/combat-architecture.md §"State-change signals vs. progression triggers"
 *   - scripts/mobs/Stratum1Boss.gd (boss controller — phase transitions, wake)
 *   - scripts/levels/Stratum1BossRoom.gd (entry sequence, door trigger)
 *   - scripts/levels/RoomGate.gd (gate state machine)
 */

import { test, expect } from "@playwright/test";
import { ConsoleCapture } from "../fixtures/console-capture";

const BOOT_TIMEOUT_MS = 30_000;
/** Per-room combat budget — enough for 4 mobs + walk to gate + traversal. */
const PER_ROOM_TIMEOUT_MS = 90_000;
/** Boss-room entry + clear budget. Boss has 600 HP; production 60-90s. */
const BOSS_CLEAR_TIMEOUT_MS = 240_000;
/** Click cadence */
const ATTACK_INTERVAL_MS = 220;
/** How long to walk west toward the gate after a room is cleared. */
const WALK_TO_GATE_MS = 4_000;
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
  // The two boss P0s (damage + attack) are FIXED in PR
  // drew/m2-w1-boss-damage-attack-p0 — Stratum1BossRoom._ready auto-fires
  // the entry sequence so the boss reliably wakes regardless of how the
  // player arrived. However, this spec still has separate pre-existing
  // room-traversal bugs (gate Y-band miss, single-vs-double body_entered)
  // that prevent it from running green end-to-end. Those need a follow-up
  // Tess dispatch to fix; this spec stays `test.fail()` for now. The
  // boss-fix verification is the new GUT integration tests +
  // Sponsor's manual M1 RC re-soak 6.
  test.fail(
    "AC4 — Stratum-1 boss reach + clear (boss P0s FIXED; gate-traversal bugs remain)",
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

      // ---- Helper: clear current room by spam-attacking, then walk west ----
      const clearAndAdvance = async (
        roomIdx: number,
        expectedMobs: number
      ): Promise<void> => {
        console.log(
          `[ac4-boss] Room ${roomIdx + 1}: clearing ${expectedMobs} mobs...`
        );


        // Set facing NE for first attack (Room 01 grunt geometry); other rooms
        // we'll spam in 4 directions so something connects.
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
              `[ac4-boss] Room ${roomIdx + 1}: cleared ${roomKills}/${expectedMobs} ` +
                `at t=${Date.now() - roomStart}ms.`
            );
            break;
          }
        }

        // ---- Negative-assertion sweep — gate signals ----
        // For Rooms 02-08 (with RoomGate), assert that gate_unlocked fires
        // BEFORE gate_traversed, and that the gate_traversed line is what
        // we'll observe AFTER the player walks west.
        if (roomIdx >= 1) {
          const gateUnlockedLine = capture
            .getLines()
            .reverse()
            .find((l) =>
              /\[combat-trace\] RoomGate\._unlock \| gate_unlocked emitting/.test(
                l.text
              )
            );
          expect(
            gateUnlockedLine,
            `Room ${roomIdx + 1}: expected gate_unlocked trace after killing ` +
              `all mobs. Last 20 trace lines:\n` +
              capture
                .getLines()
                .slice(-20)
                .map((l) => `  ${l.text}`)
                .join("\n")
          ).toBeDefined();

          // Negative assertion: gate_traversed has NOT yet fired (we haven't
          // walked through the gate yet). PR #155 cautionary tale — if it
          // fires now, the gate_unlocked → gate_traversed plumbing has
          // re-collapsed.
          const traversedTooEarly = capture
            .getLines()
            .reverse()
            .find((l) =>
              /\[combat-trace\] RoomGate\.gate_traversed/.test(l.text) &&
              l.timestamp > gateUnlockedLine!.timestamp - 100
            );
          if (traversedTooEarly) {
            // Verify it's BEFORE we walk; record the unlock timestamp.
            const tsDelta =
              traversedTooEarly.timestamp - gateUnlockedLine!.timestamp;
            expect(
              tsDelta < 100,
              `PR #155 regression: gate_traversed fired ${tsDelta}ms after ` +
                `gate_unlocked WITHOUT a player door-walk. State-change signal ` +
                `(gate_unlocked) is short-circuiting to progression trigger ` +
                `(gate_traversed). See combat-architecture.md §"State-change ` +
                `signals vs. progression triggers".`
            ).toBe(false);
          }
        }

        // ---- Walk west through gate ----
        if (roomIdx >= 1) {
          // Rooms 02-08: walk west to gate at (48, 144); player spawn (240, 200)
          // → distance ~192px NW. Walking 'a' (west) for WALK_TO_GATE_MS at
          // 120 px/s = 480px (overshoots; player will hit room west wall).
          // The walk crosses the gate Area2D triggers gate_traversed.
          await page.keyboard.down("a");
          await page.waitForTimeout(WALK_TO_GATE_MS);
          await page.keyboard.up("a");

          // Confirm gate_traversed trace fired
          await capture.waitForLine(
            /\[combat-trace\] RoomGate\.gate_traversed/,
            5_000
          );
        }
        // For Room 01: the auto-advance fires on last grunt death; nothing
        // to walk through (Stratum1Room01 has no RoomGate per Main.gd:381).
      };

      // ---- Drive Rooms 1 through 8 ----
      for (let i = 0; i < 8; i++) {
        await clearAndAdvance(i, ROOM_MOB_COUNTS[i]);
        // Settle frame for room load + player respawn at DEFAULT_PLAYER_SPAWN
        await page.waitForTimeout(800);
      }

      // ---- Boss Room: entry sequence + boss kill ----
      console.log("[ac4-boss] Entered Boss Room. Waiting for 1.8s entry sequence + boss wake...");

      // Walk north a bit to ensure we cross the boss room door-trigger
      // (player respawns at (240,200), trigger at (240,250) is SOUTH so we
      // need to walk south briefly OR just wait — the player path through
      // Room 08's gate puts us in the boss room near the entry point).
      // Actually: Boss Room replaces the room; player is placed at
      // DEFAULT_PLAYER_SPAWN=(240,200). Door trigger is at (240,250) — which
      // is SOUTH. Walking south for 800ms crosses it.
      //
      // POST-FIX (PR drew/m2-w1-boss-damage-attack-p0): Stratum1BossRoom._ready
      // now auto-fires the entry sequence on room load, so this walk is
      // belt-and-suspenders only.
      await page.keyboard.down("s");
      await page.waitForTimeout(800);
      await page.keyboard.up("s");

      // Now wait the 1.8s entry sequence + grace
      await page.waitForTimeout(BOSS_WAKE_GRACE_MS);

      // Move toward boss (boss at (240,135), player at (240,200) → walk N)
      await page.keyboard.down("w");
      await page.waitForTimeout(600);
      await page.keyboard.up("w");

      // Spam attacks to kill boss. Boss P0s fixed in
      // PR drew/m2-w1-boss-damage-attack-p0; this should run green once
      // the spec's room-traversal mechanics are fixed in a follow-up Tess
      // dispatch (currently still test.fail()).
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
      // The MAIN ASSERTION: the boss died. Currently fails per pre-existing
      // gate-traversal bugs in this spec. Boss P0s themselves are fixed in
      // PR drew/m2-w1-boss-damage-attack-p0 (verified by GUT integration
      // tests in tests/integration/test_boss_wakes_and_engages.gd).
      expect(
        bossDied,
        `Boss did not die within ${BOSS_CLEAR_TIMEOUT_MS}ms. Open follow-up:\n` +
          ` - this spec needs Tess to fix room-traversal mechanics (gate Y-band miss + lock/traverse double-crossing)\n` +
          ` - the boss P0s themselves are fixed (see GUT test_boss_wakes_and_engages.gd)`
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

      capture.detach();
    }
  );
});
