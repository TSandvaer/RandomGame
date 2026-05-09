/**
 * room-gate-diag.spec.ts
 *
 * DIAGNOSTIC spec for ticket 86c9qbhm5 — RoomGate body_entered investigation.
 *
 * NOT a permanent test. Drops in alongside the diag/ instrumentation in
 * scripts/levels/RoomGate.gd. Captures every [RoomGate-diag] and
 * [combat-trace] RoomGate.* line during a Room02 traversal attempt and
 * reports observed behavior.
 *
 * Goal: discriminate Case A (body_entered fires, downstream issue) vs
 * Case B (body_entered does NOT fire) per dispatch brief.
 *
 * Test flow:
 *   1. Boot. Wait for Main + iron_sword auto-equip.
 *   2. Kill both Room01 grunts (auto-advance to Room02).
 *   3. Confirm Room02 loaded (RoomGate._ready diag log appears).
 *   4. Walk WEST (a) for 2.0s — should land X≈40 (inside trigger X-band [24,72]).
 *      Player Y stays at 200, OUTSIDE trigger Y-band [104,184] — body_entered
 *      should NOT fire here. Diag confirms walk completed.
 *   5. Walk NORTH (w) for 1.0s — should land Y≈140 (inside trigger Y-band).
 *      Body crosses trigger south edge at Y=184 → body_entered SHOULD fire if
 *      physics is working. Capture every RoomGate-diag line.
 *   6. Continue walking N for another 0.5s to ensure overlap window.
 *   7. Stop. Wait. Walk back SE briefly. Walk back NW.
 *   8. Report all RoomGate-diag lines + post-test analysis.
 *
 * Even if AC4 is test.fail() because body_entered doesn't fire, this spec
 * is allowed to PASS regardless — the value is the captured trace data,
 * not a green/red signal. We just report findings.
 */

import { test, expect } from "@playwright/test";
import { ConsoleCapture } from "../fixtures/console-capture";

const BOOT_TIMEOUT_MS = 30_000;
const ROOM01_KILL_TIMEOUT_MS = 90_000;
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

    // ---- Phase 2: Kill Room01 grunts to auto-advance to Room02 ----
    console.log("[gate-diag] Phase 2: kill Room01 grunts to auto-advance.");

    // Set facing NE (mobs are NE of player).
    await page.keyboard.down("w");
    await page.keyboard.down("d");
    await page.waitForTimeout(100);
    await page.keyboard.up("w");
    await page.keyboard.up("d");
    await page.waitForTimeout(600);

    const room1Start = Date.now();
    let killsRoom1 = 0;
    while (
      Date.now() - room1Start < ROOM01_KILL_TIMEOUT_MS &&
      killsRoom1 < 2
    ) {
      await canvas.click({ position: { x: clickX, y: clickY } });
      await page.waitForTimeout(ATTACK_INTERVAL_MS);
      killsRoom1 = capture
        .getLines()
        .filter((l) => /\[combat-trace\] Grunt\._die/.test(l.text)).length;
    }
    console.log(
      `[gate-diag] Phase 2 done: ${killsRoom1}/2 grunts killed at t=${Date.now() - room1Start}ms`
    );
    expect(killsRoom1).toBeGreaterThanOrEqual(2);

    // ---- Phase 3: Wait for Room02 load ----
    // RoomGate._ready diag log emits on Room02 load.
    console.log("[gate-diag] Phase 3: wait for Room02 RoomGate._ready diag.");
    await capture.waitForLine(
      /\[RoomGate-diag\] _ready \|/,
      10_000
    );
    const roomGateReadyLine = capture
      .getLines()
      .find((l) => /\[RoomGate-diag\] _ready \|/.test(l.text));
    console.log(`[gate-diag] RoomGate._ready: ${roomGateReadyLine?.text}`);

    // Settle for Room02 player respawn at DEFAULT_PLAYER_SPAWN.
    await page.waitForTimeout(1500);

    // Snapshot trace count BEFORE walking — so we can see what fires from the walk.
    const preWalkLineCount = capture.getLines().length;

    // ---- Phase 4: kill Room02 grunts so gate_unlocked path fires when body_entered fires ----
    // Room02 grunts at NE same as Room01.
    console.log("[gate-diag] Phase 4: kill Room02 grunts.");
    const r2Start = Date.now();
    const r2PreKills = capture
      .getLines()
      .filter((l) => /\[combat-trace\] Grunt\._die/.test(l.text)).length;
    let killsRoom2 = 0;
    let aimCycle = 0;
    const aimSeq: string[][] = [["w", "d"], ["w"], ["w", "a"], ["d"]];
    while (Date.now() - r2Start < 90_000 && killsRoom2 < 2) {
      if (aimCycle % 8 === 0) {
        const dirs = aimSeq[(aimCycle / 8) % aimSeq.length];
        for (const k of dirs) await page.keyboard.down(k);
        await page.waitForTimeout(40);
        for (const k of dirs) await page.keyboard.up(k);
        await page.waitForTimeout(20);
      }
      aimCycle++;
      await canvas.click({ position: { x: clickX, y: clickY } });
      await page.waitForTimeout(ATTACK_INTERVAL_MS);
      killsRoom2 =
        capture
          .getLines()
          .filter((l) => /\[combat-trace\] Grunt\._die/.test(l.text)).length -
        r2PreKills;
    }
    console.log(
      `[gate-diag] Phase 4 done: ${killsRoom2}/2 Room02 grunts killed at t=${Date.now() - r2Start}ms`
    );

    // ---- Phase 5: Walk WEST for 2.0s, then NORTH for 1.0s ----
    // Goal: cross the trigger south edge at Y=184. body_entered SHOULD fire.
    await page.waitForTimeout(500);
    console.log("[gate-diag] Phase 5a: walk WEST for 2000ms (X-axis align).");
    await page.keyboard.down("a");
    await page.waitForTimeout(2000);
    await page.keyboard.up("a");
    await page.waitForTimeout(300);

    console.log("[gate-diag] Phase 5b: walk NORTH for 1500ms (descend into trigger Y-band).");
    await page.keyboard.down("w");
    await page.waitForTimeout(1500);
    await page.keyboard.up("w");
    await page.waitForTimeout(500);

    // ---- Phase 6: Walk back SE briefly (exit trigger), then NW (re-enter) ----
    console.log("[gate-diag] Phase 6a: walk EAST for 800ms (exit trigger east edge).");
    await page.keyboard.down("d");
    await page.waitForTimeout(800);
    await page.keyboard.up("d");
    await page.waitForTimeout(300);

    console.log("[gate-diag] Phase 6b: walk WEST for 1100ms (re-enter from east).");
    await page.keyboard.down("a");
    await page.waitForTimeout(1100);
    await page.keyboard.up("a");
    await page.waitForTimeout(1500);

    // ---- Phase 7: Report all RoomGate-diag and combat-trace RoomGate lines ----
    const allLines = capture.getLines();
    const postWalkLines = allLines.slice(preWalkLineCount);
    const gateDiagLines = allLines.filter((l) =>
      /\[RoomGate-diag\]/.test(l.text)
    );
    const gateCombatTraceLines = allLines.filter((l) =>
      /\[combat-trace\] RoomGate\./.test(l.text)
    );

    console.log("");
    console.log("=".repeat(80));
    console.log("[gate-diag] === DIAGNOSTIC REPORT ===");
    console.log("=".repeat(80));
    console.log(`[gate-diag] Total console lines: ${allLines.length}`);
    console.log(`[gate-diag] [RoomGate-diag] lines: ${gateDiagLines.length}`);
    console.log(`[gate-diag] [combat-trace] RoomGate lines: ${gateCombatTraceLines.length}`);
    console.log("");
    console.log("[gate-diag] All [RoomGate-diag] lines:");
    for (const l of gateDiagLines) {
      console.log(`  ${l.text}`);
    }
    console.log("");
    console.log("[gate-diag] All [combat-trace] RoomGate lines:");
    for (const l of gateCombatTraceLines) {
      console.log(`  ${l.text}`);
    }
    console.log("");

    // Check for body_entered ENTRY trace (the discriminator).
    const entryLines = gateDiagLines.filter((l) =>
      /_on_body_entered ENTRY/.test(l.text)
    );
    console.log(
      `[gate-diag] _on_body_entered ENTRY count: ${entryLines.length}`
    );
    if (entryLines.length === 0) {
      console.log(
        "[gate-diag] *** CASE B CONFIRMED: body_entered did NOT fire under Playwright ***"
      );
    } else {
      console.log(
        "[gate-diag] *** CASE A: body_entered DID fire — investigate downstream ***"
      );
      for (const l of entryLines) {
        console.log(`  ${l.text}`);
      }
    }
    console.log("=".repeat(80));

    // We do not assert pass/fail on body_entered firing — the value is the trace data.
    // We only assert that boot + Room01->Room02 transition happened (sanity check).
    expect(roomGateReadyLine).toBeDefined();

    capture.detach();
  });
});
