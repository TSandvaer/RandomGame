/**
 * s2-zone-advance-gate.spec.ts
 *
 * **Ticket `86ca3amyb`** — gate S2 zone-advance on chunk-clear (OOS gap (b)
 * from PR #391). Before this PR, S2 zones AUTO-ADVANCED ~one frame after load:
 * descending whisked the player z1 → z2 → z3 → boss room in ~3 consecutive
 * frames with no combat pacing. This PR GATES the advance on every spawned mob
 * in the current zone being defeated (`_s2_mobs_remaining == 0`).
 *
 * **What this spec checks (end-to-end HTML5 boot → descend → S2 zone load):**
 *
 *   1. Boot the release build with `?force_descend=1` ALONE (NOT combined with
 *      `?start_room=9` — html5-export.md § DebugFlags mutual-exclusivity; that
 *      collision burned a soak cycle on #391). Opens the DescendScreen after
 *      Room 01 boots.
 *
 *   2. Click "Return to Stratum 1" → `restart_run` → `_begin_stratum_2` →
 *      `_load_s2_zone(0)` assembles + renders the FIRST S2 zone
 *      (`s2_z1_entry_hall`) with its authored mob spawns.
 *
 *   3. **The gate-holds assertion (the headline of this ticket):** after the
 *      click, EXACTLY ONE `Main.load_s2_zone` trace fires (z1 only) within a
 *      generous observation window, and the player does NOT skip to z2 / z3 /
 *      the boss room on the first frame. In the PRE-GATE (broken) state, three
 *      `Main.load_s2_zone` traces (z1, z2, z3) fired within ~3 frames — that
 *      cascade is the exact regression this spec catches.
 *
 *   4. The single z1 load deterministically carries `mobs>=1` (the gate has
 *      something to hold on) — `mobs=0` would mean the floor would advance
 *      immediately (empty-zone branch) and the gate would never engage, which
 *      for z1 is itself a regression (z1 must spawn mobs).
 *
 *   5. No `USER WARNING:` / `USER ERROR:` and no physics-flush panic across the
 *      gate wiring (the CONNECT_DEFERRED mob_died hook runs outside the flush).
 *
 * **Why a no-cascade negative is the right shape.** A CLI-agent Playwright
 * session cannot interactively defeat the spawned mobs to drive the full
 * z1→z2→z3→boss traversal (multi-room melee). The gate's CORRECTNESS is the
 * NEGATIVE — "the floor holds at z1, no auto-skip" — which IS observable from
 * the trace stream: one load_s2_zone, no cascade. The positive "advance fires
 * on clear" is pinned by the paired GUT test
 * (`test_descend_reaches_s2_boss_room_after_clearing_each_zone`), which CAN
 * lethal-damage the mobs in a headless harness.
 *
 * Pattern source: s2-mob-spawns.spec.ts (force_descend boot + DescendScreen
 * canvas-click + [combat-trace] Main.load_s2_zone assertion).
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";

const BOOT_TIMEOUT_MS = 30_000;
const POST_CLICK_TRACE_WAIT_MS = 10_000;
// Generous window for the gate to (NOT) cascade. In the pre-gate state all
// three zones load within ~3 frames (<200ms); 5s is far past any auto-advance.
const GATE_HOLD_OBSERVE_MS = 5_000;

test.describe("S2 zone-advance chunk-clear gate (86ca3amyb)", () => {
  test("descend → z1 holds, no first-frame auto-skip to z2/z3/boss", async ({
    page,
    context,
  }) => {
    await context.route("**/*", (route) => route.continue());
    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    // `?force_descend=1` ALONE — NEVER with start_room=9 (DebugFlags
    // mutual-exclusivity, html5-export.md § DebugFlags; that combo burned a
    // soak cycle on #391).
    await page.goto(`${baseURL}/?force_descend=1`, {
      waitUntil: "domcontentloaded",
    });

    // 1. Main-ready sentinel.
    await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);

    // 2. force_descend hook fired.
    const forceLine = await capture
      .waitForLine(/\[Main\] DebugFlags\.force_descend=true/, BOOT_TIMEOUT_MS)
      .catch(() => null);
    expect(forceLine).not.toBeNull();

    // 3. Settle a frame so the DescendScreen is in the tree + the return button
    //    has grabbed focus on fade-complete.
    await page.waitForTimeout(800);

    // 4. Click the "Return to Stratum 1" button (CENTER_BOTTOM anchor, ~640,620
    //    on the 1280x720 canvas — same target as s2-mob-spawns.spec.ts).
    const canvas = await page.locator("canvas").first();
    await canvas.click({ position: { x: 640, y: 620 } });

    // 5. Wait for the z1 zone-load trace.
    const loadTrace = await capture
      .waitForLine(
        /\[combat-trace\] Main\.load_s2_zone \|.*mobs=\d+/,
        POST_CLICK_TRACE_WAIT_MS,
      )
      .catch(() => null);
    if (loadTrace === null) {
      const recent = capture
        .getLines()
        .filter((l) => l.text.includes("[combat-trace]"))
        .slice(-20)
        .map((l) => l.text)
        .join("\n");
      console.log(
        "[s2-zone-advance-gate] Main.load_s2_zone trace did NOT fire. " +
          "Recent [combat-trace] lines:\n" +
          (recent || "(none)"),
      );
    }
    expect(loadTrace).not.toBeNull();

    // 6. Let the gate (NOT) cascade. In the pre-gate state z2 + z3 would load
    //    within a few frames; hold the observation window well past that.
    await page.waitForTimeout(GATE_HOLD_OBSERVE_MS);

    // 7. THE GATE-HOLDS ASSERTION. Collect every Main.load_s2_zone trace. With
    //    the gate, EXACTLY ONE fires (z1). Pre-gate, three fired (z1/z2/z3).
    const zoneLoads = capture
      .getLines()
      .map((l) => l.text)
      .filter((t) => /\[combat-trace\] Main\.load_s2_zone \|/.test(t));

    expect(
      zoneLoads.length,
      `GATE REGRESSION: expected exactly 1 zone load (z1 holds), got ${zoneLoads.length}:\n${zoneLoads.join("\n")}`,
    ).toBe(1);

    // 8. The single load is z1 with mobs>=1 (the gate has something to hold on).
    const z1Load = zoneLoads[0];
    expect(/zone_id=s2_z1_entry_hall/.test(z1Load)).toBe(true);
    const mobsMatch = z1Load.match(/mobs=(\d+)/);
    expect(mobsMatch).not.toBeNull();
    const mobCount = mobsMatch ? parseInt(mobsMatch[1], 10) : 0;
    expect(
      mobCount,
      "z1 must spawn >=1 mob for the gate to engage (mobs=0 → empty-zone immediate advance)",
    ).toBeGreaterThanOrEqual(1);

    // 9. Explicit no-skip-to-later-zones negative.
    expect(
      zoneLoads.some((t) => /zone_id=s2_z2/.test(t)),
      "GATE: z2 must NOT load while z1 mobs are alive",
    ).toBe(false);
    expect(
      zoneLoads.some((t) => /zone_id=s2_z3/.test(t)),
      "GATE: z3 must NOT load while z1 mobs are alive",
    ).toBe(false);

    // 10. No physics-flush panic across the gate wiring.
    expect(
      capture
        .getLines()
        .some((l) =>
          l.text.includes("Can't change this state while flushing queries"),
        ),
    ).toBe(false);

    // 11. No USER WARNING / USER ERROR (also gated by test-base.ts teardown).
    const userWarnings = capture
      .getLines()
      .filter(
        (l) =>
          l.text.includes("USER WARNING:") || l.text.includes("USER ERROR:"),
      )
      .map((l) => l.text);
    expect(
      userWarnings,
      `unexpected USER WARNING/ERROR:\n${userWarnings.join("\n")}`,
    ).toEqual([]);

    capture.detach();
  });
});
