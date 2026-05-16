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
 *     While Room 01 is the live room (which auto-advances via
 *     `_install_room01_clear_listener`, NOT a RoomGate), zero
 *     `[combat-trace] RoomGate.*` traces should fire. Stratum1Room01 has
 *     no RoomGate — see `scenes/Main.gd::_wire_room_signals` ("Room01 ...
 *     does NOT emit room_cleared — it has no RoomGate in its .tscn"). If a
 *     gate trace appears while Room01 is live, room loading
 *     mis-instantiated a gate — a misconfiguration symptom.
 *
 *     **Stage 2b update (PR #169):** Room01's mob roster swapped from
 *     "2 grunts that chase" to "1 PracticeDummy that doesn't chase." The
 *     test now expects exactly 1 `PracticeDummy._die` trace. The
 *     no-RoomGate invariant is unchanged — Room01 still uses
 *     `_install_room01_clear_listener` to auto-advance on the dummy's
 *     death.
 *
 *     **Buffer-scope fix (ticket 86c9tqrt7):** the dummy's death triggers
 *     the Room02 load, and Room02 IS a MultiMobRoom with a RoomGate that
 *     registers its grunts. Because `clearRoom01Dummy`'s attack-sweep and
 *     Main's deferred `_on_room_cleared` race, Room02's
 *     `RoomGate.register_mob | mob=Grunt` traces land in the same console
 *     buffer. The negative assertion (and the no-Grunt-deaths assertion)
 *     are therefore scoped to the window strictly BEFORE the first
 *     `PracticeDummy._die` trace — the unambiguous end of "Room01 is the
 *     live room." A whole-buffer count mis-attributes Room02's gate to
 *     Room01 (this spec went RED on origin/main, run 25852576132, for
 *     exactly that reason).
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

import { test, expect } from "../fixtures/test-base";
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

    // Negative assertion: the retired PR #146 boot-equip bandaid must NOT
    // fire at all (ticket 86c9qbb3k). There is no `[Inventory] starter
    // iron_sword auto-equipped` line any more, and no boot-window
    // Inventory.equip trace of any source — the player boots fistless and
    // equips by picking up the Room01 dummy drop.
    const autoEquipLines = capture
      .getLines()
      .filter((l) =>
        /\[Inventory\] starter iron_sword auto-equipped/.test(l.text)
      );
    expect(
      autoEquipLines.length,
      `The retired PR #146 boot-equip line must NEVER fire (ticket 86c9qbb3k). ` +
        `Got ${autoEquipLines.length} occurrence(s) of ` +
        `'[Inventory] starter iron_sword auto-equipped'.`
    ).toBe(0);
    const bootEquipTraces = capture
      .getLines()
      .filter((l) => /\[combat-trace\] Inventory\.equip \|/.test(l.text));
    expect(
      bootEquipTraces.length,
      `No Inventory.equip trace of any source should fire during the cold-boot ` +
        `window — nothing equips until the player picks up the dummy drop ` +
        `(ticket 86c9qbb3k). Got ${bootEquipTraces.length}:\n` +
        bootEquipTraces.map((l) => `  ${l.text}`).join("\n")
    ).toBe(0);

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

    const canvas = page.locator("canvas").first();
    await canvas.click();
    await page.waitForTimeout(500);

    const canvasBB = await canvas.boundingBox();
    const clickX = (canvasBB?.x ?? 0) + (canvasBB?.width ?? 1280) / 2;
    const clickY = (canvasBB?.y ?? 0) + (canvasBB?.height ?? 720) / 2;

    // Stage 2b (PR #169): Room01 has 1 PracticeDummy at world (~368, 144),
    // not 2 grunts. The helper walk-NE-then-attack-sweeps to kill it, then
    // walks the player onto the dummy-dropped iron_sword Pickup (ticket
    // 86c9qbb3k — the Room01 → Room02 advance is gated on the pickup-equip).
    // Auto-advance to Room02 is via _install_room01_clear_listener (no
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
    expect(
      result.pickupEquipped,
      `The dummy-dropped iron_sword Pickup must be collected + auto-equipped — ` +
        `the Room01 → Room02 advance is gated on it (ticket 86c9qbb3k).`
    ).toBe(true);

    // Snapshot the full set of mob-death traces observed during Room01 life.
    // Stage 2b expectation: exactly 1 PracticeDummy._die, 0 Grunt._die,
    // 0 Charger._die, 0 Shooter._die.
    const dummyDeaths = capture
      .getLines()
      .filter((l) => /\[combat-trace\] PracticeDummy\._die/.test(l.text)).length;
    expect(
      dummyDeaths,
      `Stage 2b Room01: expected exactly 1 PracticeDummy._die trace; got ` +
        `${dummyDeaths}. Either the chunk_def reverted to grunts (regression) ` +
        `or the dummy didn't die (helper failure).`
    ).toBe(1);

    // ---- Buffer-scope boundary: the Room01→Room02 handoff ----
    // The dummy's death is what triggers the Room02 load: PracticeDummy._die
    // → mob_died → Main._on_room01_mob_died → call_deferred("_on_room_cleared")
    // → _load_room_at_index(1). So the FIRST `PracticeDummy._die` timestamp is
    // the unambiguous end of "Room01 is the live room." Room02 is a
    // MultiMobRoom: its _ready calls RoomGate.register_mob for its grunts,
    // which fires `[combat-trace] RoomGate.register_mob | mob=Grunt ...`
    // milliseconds later. clearRoom01Dummy()'s 8-direction attack-sweep keeps
    // running (and the deferred room-load races) past the dummy's death, so by
    // the time this spec snapshots the buffer, Room02's gate traces are
    // already in it. Counting `RoomGate.*` or `Grunt._die` across the WHOLE
    // buffer therefore mis-attributes Room02 activity to Room01 — the bug that
    // surfaced this spec RED on origin/main (run 25852576132). Scope every
    // Room01-invariant assertion to the pre-handoff window.
    const room01Lines = capture.getLines();
    const firstDummyDeath = room01Lines.find((l) =>
      /\[combat-trace\] PracticeDummy\._die/.test(l.text)
    );
    // dummyDeaths === 1 was asserted above, so firstDummyDeath is defined; the
    // guard keeps TS happy and degrades gracefully (no boundary → empty window).
    const handoffTs = firstDummyDeath
      ? firstDummyDeath.timestamp
      : -Infinity;

    const gruntDeaths = room01Lines.filter(
      (l) =>
        /\[combat-trace\] Grunt\._die/.test(l.text) &&
        l.timestamp < handoffTs
    ).length;
    expect(
      gruntDeaths,
      `Stage 2b Room01: expected 0 Grunt._die traces BEFORE the dummy-poof ` +
        `handoff (t=${handoffTs}); got ${gruntDeaths}. Room01's chunk_def ` +
        `must NOT spawn grunts (PR #169). Any Grunt._die at-or-after the ` +
        `handoff belongs to Room02 and is correctly excluded by the scope ` +
        `boundary.`
    ).toBe(0);

    // ---- THE NEGATIVE ASSERTION ----
    // Stratum1Room01 has no RoomGate (scenes/Main.gd _wire_room_signals
    // comment; .tscn ships no RoomGate child). While Room01 is the live room
    // — i.e. strictly BEFORE the dummy-poof handoff timestamp — ZERO
    // RoomGate.* traces should appear. If they do, room loading
    // mis-instantiated a gate. Room02's RoomGate.register_mob traces (which
    // fire after the handoff) are correctly excluded by the scope boundary.
    const gateTraces = room01Lines.filter(
      (l) =>
        /\[combat-trace\] RoomGate\./.test(l.text) &&
        l.timestamp < handoffTs
    );

    expect(
      gateTraces.length,
      `Stratum1Room01 has no RoomGate (scenes/Main.gd _wire_room_signals). ` +
        `If a [combat-trace] RoomGate.* line fires BEFORE the dummy-poof ` +
        `handoff (t=${handoffTs}), room loading mis-instantiated a gate. ` +
        `Got ${gateTraces.length} pre-handoff gate traces:\n` +
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
    // No `[Inventory] starter iron_sword auto-equipped` line — the boot-equip
    // bandaid is retired (ticket 86c9qbb3k). This test only asserts the
    // STATIC gate-causality invariant, which holds regardless of whether the
    // player is equipped, so the fistless start is fine here.

    const canvas = page.locator("canvas").first();
    await canvas.click();
    await page.waitForTimeout(500);

    const canvasBB = await canvas.boundingBox();
    const clickX = (canvasBB?.x ?? 0) + (canvasBB?.width ?? 1280) / 2;
    const clickY = (canvasBB?.y ?? 0) + (canvasBB?.height ?? 720) / 2;

    // Drive a longer combat sequence — the static causality assertion below
    // holds regardless of how far we get (and regardless of whether the
    // player is equipped — a fistless player still kills the dummy in 3
    // FIST_DAMAGE swings).
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
