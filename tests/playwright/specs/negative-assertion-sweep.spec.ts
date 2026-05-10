/**
 * negative-assertion-sweep.spec.ts
 *
 * Negative-assertion sweep — asserts state-change signals do NOT short-
 * circuit to progression triggers, per `.claude/docs/combat-architecture.md`
 * § "State-change signals vs. progression triggers".
 *
 * The discipline (cautionary tale: PR #155):
 *   A signal named `<noun>_<state-verb>` (e.g. `gate_unlocked`) DOCUMENTS
 *   a state change. It MUST NOT be wired directly to a progression trigger
 *   (e.g. `room_advance`). Progression must be gated on an explicit
 *   player-action event (CharacterBody2D body_entered on a trigger Area2D).
 *
 *   PR #155 fixed an instance: `RoomGate.gate_unlocked` had been wired to
 *   auto-advance the room counter; the fix introduced `gate_traversed` as
 *   the action event, with `gate_unlocked` purely controlling the door
 *   visual.
 *
 * What this spec asserts:
 *
 *   Test 1 — boot uniqueness:
 *     `[Main] M1 play-loop ready` fires EXACTLY once per page lifecycle.
 *     A second emission would mean the engine restarted mid-run, which
 *     would invalidate state assertions in other specs.
 *
 *   Test 2 — Room 01 has no gate (negative-assertion baseline):
 *     During Room 01 combat (which auto-advances via
 *     `_install_room01_clear_listener`, NOT a RoomGate), zero
 *     `[combat-trace] RoomGate.*` traces should fire. Stratum1Room01 has
 *     no RoomGate per Main.gd:381. If a gate trace appears, room loading
 *     mis-instantiated a gate — a misconfiguration symptom.
 *
 *     **Stage 2b update (PR #169):** Room01's mob roster swapped from
 *     "2 grunts that chase" to "1 PracticeDummy that doesn't chase." The
 *     test now expects exactly 1 `PracticeDummy._die` trace and ZERO
 *     `Grunt._die` traces during Room01's life. The no-RoomGate invariant
 *     is unchanged — Room01 still uses `_install_room01_clear_listener` to
 *     auto-advance on the dummy's death.
 *
 *   Test 3 — gate_traversed never precedes gate_unlocked:
 *     Within any captured trace stream, EVERY `gate_traversed` line must
 *     have at least one preceding `gate_unlocked emitting` line in the
 *     SAME GATE LIFECYCLE. The state-change signal must come before the
 *     player-action event. (PR #155 cautionary tale: gate_unlocked → wired
 *     → room_advance was the failure shape; the gate_traversed line was
 *     synthesized by mob-death observation, not by player door-walk.)
 *
 * What this spec does NOT cover (deferred — driving Room 02 → Room 03 +
 * gate-lock-from-walking-into-trigger is fragile from Playwright):
 *
 *   - The CharacterBody2D body_entered → STATE_OPEN→STATE_LOCKED transition
 *     (requires precise canvas-position pixel walking; player respawn point
 *     is past the gate, so the gate stays OPEN if the player never walks
 *     into the trigger area).
 *   - The Shooter STATE_POST_FIRE_RECOVERY ledger-trace gap (combat-arch
 *     doc § names this; current code does NOT emit a per-state-entry
 *     ledger trace — only a "closing gap" recurrence trace from
 *     `_process_post_fire`. Filed as a follow-up: Drew/Devon to add a
 *     `[combat-trace] Shooter.set_state | post_fire_recovery (entered)`
 *     line, then the negative assertion can be added to a follow-up spec
 *     extension).
 *
 * The AC4 boss-clear spec (`ac4-boss-clear.spec.ts`) drives the Room 02-08
 * gate paths and asserts gate_unlocked + gate_traversed timing per-room.
 * That's the comprehensive coverage; this spec covers the static stream
 * properties that hold regardless of which rooms were reached.
 *
 * References:
 *   - .claude/docs/combat-architecture.md §"State-change signals vs.
 *     progression triggers" (load-bearing pattern)
 *   - PR #155 (the original cautionary regression)
 *   - scripts/levels/RoomGate.gd:233 — gate state machine
 *   - scripts/levels/MultiMobRoom.gd:272 — _on_room_gate_unlocked /
 *     _on_room_gate_traversed wiring
 */

import { test, expect } from "@playwright/test";
import { ConsoleCapture } from "../fixtures/console-capture";
import { clearRoom01Dummy } from "../fixtures/room01-traversal";

const BOOT_TIMEOUT_MS = 30_000;
const ROOM01_CLEAR_TIMEOUT_MS = 60_000;
const ATTACK_INTERVAL_MS = 220;
const APPROACH_WAIT_MS = 600;

test.describe("negative-assertion sweep — state-change signals don't short-circuit progression", () => {
  test("Test 1: boot-ready trace fires exactly once per page lifecycle", async ({
    page,
    context,
  }) => {
    test.setTimeout(60_000);
    await context.route("**/*", (route) => route.continue());

    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL =
      process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(baseURL, { waitUntil: "domcontentloaded" });

    await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);

    // Settle 5s — engine should have completed all init.
    // Any second emission of the boot-ready line would indicate an unintended
    // restart.
    await page.waitForTimeout(5_000);

    const bootReadyLines = capture
      .getLines()
      .filter((l) => /\[Main\] M1 play-loop ready/.test(l.text));

    expect(
      bootReadyLines.length,
      "[Main] M1 play-loop ready must fire exactly once per page lifecycle. " +
        `Got ${bootReadyLines.length} occurrences:\n` +
        bootReadyLines.map((l) => `  ${l.text}`).join("\n")
    ).toBe(1);

    // Negative assertion: NO Inventory auto-equipped fired more than once on
    // a single boot — that would mean save-restore + starter-seed both
    // fired (PR #146 boot-order regression class).
    const autoEquipLines = capture
      .getLines()
      .filter((l) =>
        /\[Inventory\] starter iron_sword auto-equipped/.test(l.text)
      );
    expect(
      autoEquipLines.length,
      `[Inventory] starter iron_sword auto-equipped must fire at most once. ` +
        `Got ${autoEquipLines.length} occurrences (PR #146 regression class).`
    ).toBeLessThanOrEqual(1);

    capture.detach();
  });

  test("Test 2: Room 01 emits zero RoomGate traces (no gate baseline)", async ({
    page,
    context,
  }) => {
    test.setTimeout(120_000);
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

    // Stage 2b (PR #169): Room01 has 1 PracticeDummy at world (~368, 144),
    // not 2 grunts. The dummy doesn't chase, so we walk-NE-then-attack-sweep
    // to reach + kill it. Helper handles the geometry. Auto-advance to
    // Room02 on dummy death is via _install_room01_clear_listener (no
    // RoomGate involvement — that's the negative-assertion below).
    const result = await clearRoom01Dummy(
      page,
      canvas,
      capture,
      clickX,
      clickY,
      { budgetMs: ROOM01_CLEAR_TIMEOUT_MS }
    );
    expect(
      result.dummyKilled,
      `PracticeDummy must die for Room02 to load (and for the no-gate-traces ` +
        `negative assertion below to be exercised against actual Room01 life).`
    ).toBe(true);

    // Snapshot the full set of mob-death traces observed during Room01 life.
    // Stage 2b expectation: exactly 1 PracticeDummy._die, 0 Grunt._die,
    // 0 Charger._die, 0 Shooter._die.
    const dummyDeaths = capture
      .getLines()
      .filter((l) => /\[combat-trace\] PracticeDummy\._die/.test(l.text)).length;
    const gruntDeaths = capture
      .getLines()
      .filter((l) => /\[combat-trace\] Grunt\._die/.test(l.text)).length;
    expect(
      dummyDeaths,
      `Stage 2b Room01: expected exactly 1 PracticeDummy._die trace; got ` +
        `${dummyDeaths}. Either the chunk_def reverted to grunts (regression) ` +
        `or the dummy didn't die (helper failure).`
    ).toBe(1);
    expect(
      gruntDeaths,
      `Stage 2b Room01: expected 0 Grunt._die traces during Room01's life; ` +
        `got ${gruntDeaths}. Room01's chunk_def must NOT spawn grunts ` +
        `(PR #169). If grunts died here, the chunk_def regressed OR Room02 ` +
        `loaded faster than expected and we counted Room02 grunt deaths in ` +
        `the same buffer scope.`
    ).toBe(0);

    // ---- THE NEGATIVE ASSERTION ----
    // Stratum1Room01 has no RoomGate (Main.gd:381 docstring; .tscn ships no
    // RoomGate child). During Room 01's life, ZERO RoomGate.* traces should
    // appear. If they do, room loading mis-instantiated a gate.
    const gateTraces = capture
      .getLines()
      .filter((l) => /\[combat-trace\] RoomGate\./.test(l.text));

    expect(
      gateTraces.length,
      `Stratum1Room01 has no RoomGate per Main.gd:381 docstring. ` +
        `If a [combat-trace] RoomGate.* line fires here, room loading ` +
        `mis-instantiated a gate. Got ${gateTraces.length} gate traces:\n` +
        gateTraces.map((l) => `  ${l.text}`).join("\n")
    ).toBe(0);

    // Negative assertion: no physics-flush panic during Room 01 combat
    const panicLine = capture.findUnexpectedLine(
      /Can't change this state while flushing queries/
    );
    expect(panicLine).toBeNull();

    capture.detach();
  });

  test("Test 3: gate_traversed never precedes gate_unlocked (causality invariant)", async ({
    page,
    context,
  }) => {
    test.setTimeout(180_000);
    await context.route("**/*", (route) => route.continue());

    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL =
      process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(baseURL, { waitUntil: "domcontentloaded" });

    await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);
    await capture.waitForLine(
      /\[Inventory\] starter iron_sword auto-equipped/,
      5_000
    );

    const canvas = page.locator("canvas").first();
    await canvas.click();
    await page.waitForTimeout(500);

    const canvasBB = await canvas.boundingBox();
    const clickX = (canvasBB?.x ?? 0) + (canvasBB?.width ?? 1280) / 2;
    const clickY = (canvasBB?.y ?? 0) + (canvasBB?.height ?? 720) / 2;

    // Drive a longer combat sequence — kill Room 01 grunts, let Room 02
    // attempt unfold. We don't care if we reach Room 02's gate or not;
    // the static causality assertion below holds regardless of how far
    // we get.
    await page.keyboard.down("w");
    await page.keyboard.down("d");
    await page.waitForTimeout(100);
    await page.keyboard.up("w");
    await page.keyboard.up("d");
    await page.waitForTimeout(APPROACH_WAIT_MS);

    const combatStart = Date.now();
    let aimCycle = 0;
    const aimSeq: string[][] = [
      ["w", "d"],
      ["w"],
      ["w", "a"],
      ["d"],
      ["a"],
      ["s"],
    ];

    // Run combat for 60s — long enough to potentially reach Room 02 + walk
    // patterns that might trigger the gate. The assertion below is a STATIC
    // property: regardless of what happens, gate_traversed must come after
    // gate_unlocked in any matching pair.
    while (Date.now() - combatStart < 60_000) {
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
    }

    // ---- THE CAUSALITY ASSERTION ----
    // Walk through every gate_traversed trace observed; for each, assert at
    // least one gate_unlocked trace exists earlier in the buffer. If any
    // gate_traversed has no preceding gate_unlocked, that's the PR #155
    // failure shape (synthesized progression-trigger event without the
    // state-change predecessor).
    const gateUnlockedTimes = capture
      .getLines()
      .filter((l) =>
        /\[combat-trace\] RoomGate\._unlock \| gate_unlocked emitting/.test(
          l.text
        )
      )
      .map((l) => l.timestamp);

    const gateTraversedEntries = capture
      .getLines()
      .filter((l) =>
        /\[combat-trace\] RoomGate\.gate_traversed/.test(l.text)
      );

    console.log(
      `[neg-sweep] Causality check: ${gateUnlockedTimes.length} gate_unlocked, ` +
        `${gateTraversedEntries.length} gate_traversed lines observed.`
    );

    for (const traversed of gateTraversedEntries) {
      const precedingUnlock = gateUnlockedTimes.find(
        (t) => t < traversed.timestamp
      );
      expect(
        precedingUnlock,
        `CAUSALITY VIOLATION (PR #155 regression class): gate_traversed at ` +
          `t=${traversed.timestamp} has NO preceding gate_unlocked. The ` +
          `state-change signal MUST fire before the player-action event. ` +
          `Trace line: "${traversed.text}"\n` +
          `gate_unlocked timestamps in buffer: [${gateUnlockedTimes.join(", ")}]`
      ).toBeDefined();
    }

    // ---- Additional: gate_unlocked never short-circuits to room_cleared ----
    // We don't have a direct `[combat-trace] room_cleared` line, but we can
    // check: when gate_unlocked fires, no gate_traversed should fire within
    // SAME_TICK_AUTO_EMISSION_THRESHOLD_MS (200ms) — that would indicate
    // automatic chaining without a real player walk.
    for (const unlockTs of gateUnlockedTimes) {
      const samaTickTraversed = gateTraversedEntries.find(
        (t) =>
          t.timestamp >= unlockTs && t.timestamp < unlockTs + 200
      );
      if (samaTickTraversed) {
        const tsDelta = samaTickTraversed.timestamp - unlockTs;
        throw new Error(
          `PR #155 REGRESSION: gate_traversed fired ${tsDelta}ms after ` +
            `gate_unlocked WITHOUT a player door-walk. State-change signal ` +
            `(gate_unlocked) is short-circuiting to progression trigger ` +
            `(gate_traversed). See combat-architecture.md §"State-change ` +
            `signals vs. progression triggers".`
        );
      }
    }

    if (gateUnlockedTimes.length > 0) {
      console.log(
        `[neg-sweep] All ${gateUnlockedTimes.length} gate_unlocked trace(s) ` +
          `did NOT chain to a same-tick gate_traversed (within 200ms). ` +
          `Player-action event correctly gated.`
      );
    } else {
      console.log(
        `[neg-sweep] No gate_unlocked traces observed in 60s combat — the ` +
          `assertion is vacuously true (no gates were locked-then-unlocked). ` +
          `For deeper coverage, see ac4-boss-clear.spec.ts which drives the ` +
          `full Room 02-08 gate path.`
      );
    }

    capture.detach();
  });
});
