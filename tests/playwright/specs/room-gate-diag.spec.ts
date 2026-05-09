/**
 * room-gate-diag.spec.ts
 *
 * DIAGNOSTIC spec for ticket 86c9qbhm5 — RoomGate body_entered investigation.
 *
 * NOT a permanent test. Captures every [RoomGate-diag] and
 * [combat-trace] RoomGate.* line during a Room02 traversal attempt and
 * reports observed behavior.
 *
 * Refined v2: minimize player wandering during combat (set NE facing once,
 * click only). Then explicitly drive in→out→in walk.
 */

import { test, expect } from "@playwright/test";
import { ConsoleCapture } from "../fixtures/console-capture";

const BOOT_TIMEOUT_MS = 30_000;
const ROOM_KILL_TIMEOUT_MS = 90_000;
const ATTACK_INTERVAL_MS = 220;

test.describe("RoomGate body_entered diagnostic (ticket 86c9qbhm5)", () => {
  test("RoomGate body_entered diagnostic — Room02 walk attempt", async ({
    page,
    context,
  }) => {
    test.setTimeout(300_000);
    await context.route("**/*", (route) => route.continue());

    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL =
      process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(baseURL, { waitUntil: "domcontentloaded" });

    // ---- Phase 1: Boot ----
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

    // ---- Helper: kill N mobs without wandering (NE facing, click only) ----
    const killMobs = async (label: string, expected: number) => {
      console.log(`[gate-diag] ${label}: kill ${expected} mobs (NE facing, click only)`);
      // Set NE facing
      await page.keyboard.down("w");
      await page.keyboard.down("d");
      await page.waitForTimeout(100);
      await page.keyboard.up("w");
      await page.keyboard.up("d");
      await page.waitForTimeout(400);

      const preDeaths = capture
        .getLines()
        .filter((l) => /\[combat-trace\] (Grunt|Charger|Shooter)\._die/.test(l.text))
        .length;
      const t0 = Date.now();
      let kills = 0;
      while (Date.now() - t0 < ROOM_KILL_TIMEOUT_MS && kills < expected) {
        await canvas.click({ position: { x: clickX, y: clickY } });
        await page.waitForTimeout(ATTACK_INTERVAL_MS);
        kills =
          capture
            .getLines()
            .filter((l) => /\[combat-trace\] (Grunt|Charger|Shooter)\._die/.test(l.text))
            .length - preDeaths;
        // Re-aim NE every 20 attacks (knockback may rotate _facing)
        if (kills < expected && Math.floor((Date.now() - t0) / 4400) > Math.floor((Date.now() - t0 - ATTACK_INTERVAL_MS) / 4400)) {
          await page.keyboard.down("w");
          await page.keyboard.down("d");
          await page.waitForTimeout(50);
          await page.keyboard.up("w");
          await page.keyboard.up("d");
        }
      }
      console.log(`[gate-diag] ${label}: ${kills}/${expected} killed at t=${Date.now() - t0}ms`);
      return kills;
    };

    // ---- Room01 → Room02 ----
    const r1Kills = await killMobs("Room01", 2);
    expect(r1Kills).toBeGreaterThanOrEqual(2);

    await capture.waitForLine(/\[RoomGate-diag\] _ready \|/, 10_000);
    const room02ReadyLine = capture
      .getLines()
      .find((l) => /\[RoomGate-diag\] _ready \|/.test(l.text));
    console.log(`[gate-diag] Room02 RoomGate: ${room02ReadyLine?.text}`);

    // Settle for player respawn at (240, 200).
    await page.waitForTimeout(1500);

    const preWalkLineCount = capture.getLines().length;

    // ---- Room02: kill mobs WITHOUT wandering ----
    const r2Kills = await killMobs("Room02", 2);
    console.log(`[gate-diag] Room02 kills: ${r2Kills}/2`);

    // Wait for any pending death-tween + unlock timer (0.65s + slack)
    await page.waitForTimeout(1500);

    // Snapshot what fired during Room02 combat (BEFORE we walk).
    const duringCombatLines = capture
      .getLines()
      .slice(preWalkLineCount)
      .filter((l) => /\[RoomGate-diag\]|\[combat-trace\] RoomGate\./.test(l.text));
    console.log("");
    console.log("=".repeat(80));
    console.log("[gate-diag] === DURING-COMBAT RoomGate observations (Room02) ===");
    for (const l of duringCombatLines) {
      console.log(`  ${l.text}`);
    }
    console.log("=".repeat(80));

    const preTraversalLineCount = capture.getLines().length;

    // ---- Phase 5: Two-part walk pattern ----
    // After mobs die, gate should be UNLOCKED (or LOCKED waiting for traversal).
    // Walk in, exit, walk back in to fire body_entered #2 → gate_traversed.
    console.log("[gate-diag] Phase 5a: walk WEST for 2000ms");
    await page.keyboard.down("a");
    await page.waitForTimeout(2000);
    await page.keyboard.up("a");
    await page.waitForTimeout(300);

    console.log("[gate-diag] Phase 5b: walk NORTH for 1500ms");
    await page.keyboard.down("w");
    await page.waitForTimeout(1500);
    await page.keyboard.up("w");
    await page.waitForTimeout(500);

    console.log("[gate-diag] Phase 6a: walk EAST for 800ms");
    await page.keyboard.down("d");
    await page.waitForTimeout(800);
    await page.keyboard.up("d");
    await page.waitForTimeout(300);

    console.log("[gate-diag] Phase 6b: walk WEST for 1100ms");
    await page.keyboard.down("a");
    await page.waitForTimeout(1100);
    await page.keyboard.up("a");
    await page.waitForTimeout(2000);

    // ---- Phase 7: Final report ----
    const allLines = capture.getLines();
    const traversalLines = allLines
      .slice(preTraversalLineCount)
      .filter((l) => /\[RoomGate-diag\]|\[combat-trace\] RoomGate\./.test(l.text));

    console.log("");
    console.log("=".repeat(80));
    console.log("[gate-diag] === DURING-TRAVERSAL RoomGate observations ===");
    for (const l of traversalLines) {
      console.log(`  ${l.text}`);
    }
    console.log("=".repeat(80));
    console.log("");

    // ---- Aggregate stats ----
    const allRoomGate = allLines.filter((l) =>
      /\[RoomGate-diag\]|\[combat-trace\] RoomGate\./.test(l.text)
    );
    const entryLines = allRoomGate.filter((l) => /_on_body_entered ENTRY/.test(l.text));
    const mobDiedLines = allRoomGate.filter((l) => /_on_mob_died/.test(l.text));
    const startWaitLines = allRoomGate.filter((l) => /_start_death_wait/.test(l.text));
    const unlockLines = allRoomGate.filter((l) => /_unlock|gate_unlocked emitting/.test(l.text));
    const traversedLines = allRoomGate.filter((l) => /gate_traversed/.test(l.text));

    console.log("[gate-diag] === STATS ===");
    console.log(`  body_entered ENTRY: ${entryLines.length}`);
    console.log(`  _on_mob_died:       ${mobDiedLines.length}`);
    console.log(`  _start_death_wait:  ${startWaitLines.length}`);
    console.log(`  _unlock:            ${unlockLines.length}`);
    console.log(`  gate_traversed:     ${traversedLines.length}`);
    console.log("");

    if (entryLines.length === 0) {
      console.log("[gate-diag] *** CASE B: body_entered did NOT fire under Playwright ***");
    } else {
      console.log(`[gate-diag] *** CASE A: body_entered fired ${entryLines.length}× — investigate downstream ***`);
    }
    console.log("=".repeat(80));

    expect(room02ReadyLine).toBeDefined();
    capture.detach();
  });
});
