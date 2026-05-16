/**
 * room-gate-body-entered-regression.spec.ts
 *
 * Permanent regression test arising from ticket 86c9qbhm5 — confirms that
 * `RoomGate._on_body_entered` fires reliably under Playwright + Chromium HTML5
 * when the player walks from a known starting position into the trigger.
 *
 * **Backstory:** Tess's PR #170 investigation flagged that AC4 boss-clear
 * spec saw zero `[combat-trace] RoomGate.*` lines during gate traversal,
 * suggesting body_entered might not fire under Playwright's headless cadence
 * (hypothesis 1 in the ticket). Devon's investigation (ticket 86c9qbhm5)
 * disproved that hypothesis: body_entered fires reliably 5/5 runs when the
 * player walks from `DEFAULT_PLAYER_SPAWN = (240, 200)` into the Room02 gate
 * via the `W 2000ms then N 1500ms` two-segment walk pattern.
 *
 * The AC4 spec failure was instead a player-drift issue — extended Room02
 * combat with knockback + aim-cycle direction sweep moved the player far
 * from spawn, so the helper's W+N walk pattern no longer intersected the
 * trigger geometry. Fix lives in the harness (`tests/playwright/fixtures/
 * gate-traversal.ts` + AC4 spec combat loop) — keep combat tight (no aim
 * sweep, NE facing only) so the player stays near spawn before traversal.
 *
 * **What this spec asserts:**
 *   1. Boot completes (player boots fistless — bandaid retired, 86c9qbb3k).
 *   2. Room01 PracticeDummy killed + the dummy-dropped iron_sword Pickup
 *      collected/auto-equipped (the `clearRoom01Dummy` helper handles both;
 *      the Room01 → Room02 advance is gated on the pickup-equip).
 *   3. SKIP Room02 combat — gate stays OPEN with mobs_alive=2
 *   4. From spawn (240, 200), walk WEST 2000ms then NORTH 1500ms
 *   5. **Assert** at least one `[combat-trace] RoomGate._on_body_entered`
 *      line appears in the capture buffer (any state, any body class — the
 *      gate's overlap detection is the only invariant).
 *
 * **Stage 2b update (PR #169):** Room01 now spawns 1 PracticeDummy at world
 * (~368, 144) instead of 2 grunts. The dummy doesn't chase, so the player
 * must walk NE and attack-sweep to kill it. Helper at
 * `fixtures/room01-traversal.ts` encapsulates the discipline. The Room02-side
 * body_entered assertion is unchanged — that's the load-bearing invariant
 * this spec exists to canary.
 *
 * If this spec ever fails, the body_entered signal IS regressing under
 * Playwright. Investigate Godot 4.x version changes, gl_compatibility
 * physics-server behavior, or service-worker timing interference.
 *
 * **What this spec does NOT cover:**
 *   - Full gate traversal (lock → unlock → traverse) — that's AC4's job
 *   - Mob death propagation — `room-traversal-smoke.spec.ts` covers Room 01,
 *     and AC4 covers Rooms 02-08 once its drift fix lands
 *   - Player drift handling — that's harness-layer logic in the helper
 *
 * References:
 *   - Ticket 86c9qbhm5 (this investigation)
 *   - .claude/docs/combat-architecture.md §"body_entered semantics" (updated
 *     with the resolved root cause)
 *   - tests/playwright/fixtures/gate-traversal.ts (helper that consumes this)
 *   - scripts/levels/RoomGate.gd (the gate state machine under test)
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";
import { clearRoom01Dummy } from "../fixtures/room01-traversal";

const BOOT_TIMEOUT_MS = 30_000;
const ROOM_KILL_TIMEOUT_MS = 90_000;
const ATTACK_INTERVAL_MS = 220;

test.describe("RoomGate body_entered fires under Playwright (regression — 86c9qbhm5)", () => {
  test("walking from spawn into Room02 gate fires body_entered", async ({
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

    // No `[Inventory] starter iron_sword auto-equipped` line — the PR #146
    // boot-equip bandaid is retired (ticket 86c9qbb3k). The player boots
    // fistless; `clearRoom01Dummy` below handles the kill + pickup-equip.
    await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);

    const canvas = page.locator("canvas").first();
    await canvas.click();
    await page.waitForTimeout(500);
    const canvasBB = await canvas.boundingBox();
    const clickX = (canvasBB?.x ?? 0) + (canvasBB?.width ?? 1280) / 2;
    const clickY = (canvasBB?.y ?? 0) + (canvasBB?.height ?? 720) / 2;

    // ---- Phase 1: clear Room01 (Stage 2b PR #169 — 1 PracticeDummy) ----
    // Room01 has no RoomGate; killing the dummy auto-advances to Room02 via
    // `_install_room01_clear_listener`. The dummy doesn't chase, so we walk
    // NE and attack-sweep to reach + kill it (helper encapsulates pattern).
    const result = await clearRoom01Dummy(
      page,
      canvas,
      capture,
      clickX,
      clickY,
      { budgetMs: ROOM_KILL_TIMEOUT_MS }
    );
    expect(
      result.dummyKilled,
      "Room01 PracticeDummy must die for Room02 to load (canary depends on " +
        "reaching Room02's gate, which only exists after Room01 advances)."
    ).toBe(true);
    expect(
      result.pickupEquipped,
      "Room01 iron_sword Pickup must be collected + auto-equipped — the " +
        "Room01 → Room02 advance is gated on it (ticket 86c9qbb3k). Without " +
        "the pickup-equip, Room02 never loads and there is no gate to canary."
    ).toBe(true);

    // ---- Phase 2: settle for Room02 player respawn at DEFAULT_PLAYER_SPAWN ----
    // Player is teleported to (240, 200) on every _load_room_at_index. Wait
    // 2 seconds so post-attack physics settle and STATE_ATTACK recovery clears
    // (LIGHT_RECOVERY = 0.18s). Otherwise the next walk runs at half walk speed.
    await page.waitForTimeout(2000);

    const preWalkLineCount = capture.getLines().length;

    // ---- Phase 3: walk WEST 2000ms then NORTH 1500ms — no Room02 combat ----
    // Room02 mobs stay alive (mobs_alive=2). Gate is OPEN. Player walks from
    // spawn (240, 200) into the trigger. body_entered fires when the body
    // crosses the trigger's south edge at Y=184 with X inside [24, 72].
    //
    // From (240, 200), W at 120px/s for 2000ms → (0, 200) but wall-clamped at X≈16.
    // Then N at 120px/s for 1500ms → Y descends through [104, 184]. Body radius
    // is 10px so Y=190 already overlaps trigger at Y=184. body_entered fires
    // mid-walk.
    await page.keyboard.down("a");
    await page.waitForTimeout(2000);
    await page.keyboard.up("a");
    await page.waitForTimeout(300);

    await page.keyboard.down("w");
    await page.waitForTimeout(1500);
    await page.keyboard.up("w");
    await page.waitForTimeout(800);

    // ---- Phase 4: assert body_entered fired at least once ----
    const postWalkLines = capture.getLines().slice(preWalkLineCount);
    const bodyEnteredLines = postWalkLines.filter((l) =>
      /\[combat-trace\] RoomGate\._on_body_entered/.test(l.text)
    );

    if (bodyEnteredLines.length === 0) {
      console.log("[room-gate-regression] No body_entered traces. Last 30 lines:");
      for (const l of capture.getLines().slice(-30)) {
        console.log(`  ${l.text}`);
      }
    }
    expect(
      bodyEnteredLines.length,
      "body_entered must fire when player walks from spawn into Room02 gate"
    ).toBeGreaterThanOrEqual(1);

    capture.detach();
  });
});
