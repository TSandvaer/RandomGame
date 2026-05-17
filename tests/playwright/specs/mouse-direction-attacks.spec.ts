/**
 * mouse-direction-attacks.spec.ts
 *
 * Ticket 86c9uthf0 — Sponsor request 2026-05-17: player attacks fire in the
 * direction of the mouse cursor (Hades/Diablo convention), not the keyboard
 * facing. LMB melee + RMB heavy. The Player sprite also rotates to face the
 * cursor (visually subtle today — the M1 placeholder sprite is a symmetric
 * 16×16 ColorRect — but the rotation is mechanically observable via the
 * `Player.try_attack | FIRED facing=(x,y)` trace).
 *
 * **What this spec pins:**
 *
 *   1. With the mouse positioned EAST of the PLAYER, a LMB click fires a
 *      `Player.try_attack | FIRED kind=light facing=(+x,~0)` line.
 *   2. With the mouse positioned NORTH of the player, facing is `(~0,-y)`.
 *   3. RMB heavy with mouse WEST of the player → `(~-x, ~0)`.
 *
 * **Coordinate-model correction (PR #255 respin — Tess CHANGES_REQUESTED
 * finding, 2026-05-17).** The original spec assumed canvas-center is "on the
 * player" because a camera tracks the player. **That assumption was wrong:**
 * the M1 build has NO `Camera2D` — viewport is fixed 1280×720 with
 * `stretch=canvas_items` + `aspect=keep`, so the player's `global_position`
 * == its canvas pixel position 1:1. The player at `DEFAULT_PLAYER_SPAWN =
 * (240, 200)` renders at canvas pixel (240, 200), which is in the upper-LEFT
 * QUADRANT of the canvas — NOT the center. Canvas-center is at (640, 360),
 * which is (+400, +160) from the player — strongly SOUTHEAST.
 *
 * Pre-fix: the spec moved the mouse to `canvas-center + offset` and asserted
 * facing matched the offset direction. With canvas-center east-and-south of
 * the player, the dominant component of the player→mouse vector was always
 * east; only the LMB-east test passed (by lucky additive geometry), while
 * LMB-north and RMB-west failed with facing pointing east (`facing.x = 0.9`
 * and `+0.7` respectively — observed in Tess's PR run 25986831195).
 *
 * **Post-fix:** mouse position is derived from the PLAYER'S WORLD POSITION
 * (parsed from the latest `[combat-trace] Player.pos | pos=(x,y)` trace —
 * 1:1 with canvas-pixel coords because no camera) + a direction offset large
 * enough to clear the 8px dead-zone. Now every test asserts the facing for
 * the RIGHT reason, not by accidental geometry.
 *
 * **Why a Playwright spec is needed here:** the GUT side validates the math
 * (pure helper) and the state gate (no mid-swing drift). What it cannot
 * cover is "the actual mouse event reaches Godot's `get_global_mouse_position`
 * in the HTML5 build." Playwright's `page.mouse.move()` drives the real
 * browser cursor over the canvas, the same way Sponsor's manual play would.
 *
 * **What this spec deliberately does NOT cover:**
 *
 *   - Sprite-rotation visual rendering. The sprite is a 16×16 ColorRect —
 *     rotation is mathematically observable on the node but visually
 *     undetectable in a screenshot (a rotated square is still a square).
 *     The GUT side `test_sprite_rotation_updates_when_present` pins the
 *     wiring; an HTML5 visual check is documented in the Self-Test Report.
 *   - Dead-zone (mouse on top of player). The GUT side covers it
 *     mechanically (`test_mouse_inside_deadzone_keeps_last_facing`); the
 *     browser-coord precision needed to land exactly within 8px of the
 *     player's render position is brittle and adds no signal over the GUT
 *     coverage.
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";
import { latestPlayerPos, DEFAULT_PLAYER_SPAWN } from "../fixtures/mouse-facing";

const BOOT_TIMEOUT_MS = 30_000;

/**
 * Offset (px) used to position the mouse relative to the player along the
 * target direction. Well above `MOUSE_FACING_DEADZONE_PX = 8` so a few px of
 * imprecision in the trace-read or render-coords never collapses the delta
 * into the dead-zone.
 */
const AIM_OFFSET_PX = 200;

/**
 * Walks the boot sequence common to all three cases — focus the canvas,
 * settle the boot trace, then return the live player position from the
 * latest Player.pos trace. Falls back to DEFAULT_PLAYER_SPAWN if no trace
 * has emitted yet (extremely rare — the Player emits .pos every 0.25 s and
 * we wait ~500 ms after focus).
 */
async function bootAndReadPlayerPos(
  page: import("@playwright/test").Page,
  capture: ConsoleCapture
): Promise<{ canvas: import("@playwright/test").Locator; playerX: number; playerY: number }> {
  const baseURL = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
  await page.goto(baseURL, { waitUntil: "domcontentloaded" });
  await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);
  const canvas = page.locator("canvas").first();
  await canvas.click(); // Focus + AudioContext unlock.
  await page.waitForTimeout(500); // Let _physics_process tick at least 2 Player.pos throttle intervals.
  const player = latestPlayerPos(capture) ?? DEFAULT_PLAYER_SPAWN;
  return { canvas, playerX: player.x, playerY: player.y };
}

test.describe("Mouse-direction attacks (ticket 86c9uthf0)", () => {
  test("LMB attack direction = mouse-east → facing.x positive", async ({
    page,
    context,
  }) => {
    test.setTimeout(60_000);
    await context.route("**/*", (route) => route.continue());

    const capture = new ConsoleCapture(page);
    capture.attach();

    const { canvas, playerX, playerY } = await bootAndReadPlayerPos(page, capture);
    const canvasBB = await canvas.boundingBox();
    expect(canvasBB).not.toBeNull();

    // Target mouse position: EAST of the player. No Camera2D, so world
    // coord == canvas-pixel coord. A click at (playerX + AIM_OFFSET_PX, playerY)
    // places the mouse 200 px east of the player → delta ~(+200, 0), normalized
    // → (1.0, 0.0) → facing.x ≈ 1.0.
    const targetX = playerX + AIM_OFFSET_PX;
    const targetY = playerY;

    const preTryAttackLines = capture
      .getLines()
      .filter((l) => /\[combat-trace\] Player\.try_attack \| FIRED/.test(l.text)).length;

    // Hover the mouse to let _update_mouse_facing land at least one physics
    // frame BEFORE the click (canvas.click moves+clicks atomically, but the
    // separate hover ensures the dead-zone check has fired against the new
    // position even if the engine throttles between the click's move and its
    // press event).
    await page.mouse.move(canvasBB!.x + targetX, canvasBB!.y + targetY);
    await page.waitForTimeout(200);
    await canvas.click({ position: { x: targetX, y: targetY } });
    await page.waitForTimeout(400);

    const fireLines = capture
      .getLines()
      .filter((l) => /\[combat-trace\] Player\.try_attack \| FIRED/.test(l.text))
      .slice(preTryAttackLines);
    expect(
      fireLines.length,
      `Expected at least one Player.try_attack FIRED line after mouse-east + LMB click. ` +
        `Player at (${playerX}, ${playerY}), mouse at (${targetX}, ${targetY}). ` +
        `Got ${fireLines.length}. Last 15 trace lines:\n` +
        capture.getLines().slice(-15).map((l) => `  ${l.text}`).join("\n")
    ).toBeGreaterThanOrEqual(1);

    const firstFire = fireLines[0].text;
    const match = firstFire.match(/facing=\(([-\d.]+),([-\d.]+)\)/);
    expect(
      match,
      `try_attack FIRED line missing facing=(x,y) payload: "${firstFire}"`
    ).not.toBeNull();
    const fx = parseFloat(match![1]);
    const fy = parseFloat(match![2]);
    expect(
      fx,
      `Mouse-east click: expected facing.x > 0.5 (pointing east). ` +
        `Player at (${playerX}, ${playerY}), mouse aim at (${targetX}, ${targetY}), ` +
        `got facing=(${fx}, ${fy}). Full line: "${firstFire}"`
    ).toBeGreaterThan(0.5);
    expect(
      Math.abs(fy),
      `Mouse-east click: expected |facing.y| < 0.3 (horizontal-ish). ` +
        `Player at (${playerX}, ${playerY}), mouse aim at (${targetX}, ${targetY}), ` +
        `got facing=(${fx}, ${fy}). Full line: "${firstFire}"`
    ).toBeLessThan(0.3);
  });

  test("LMB attack direction = mouse-north → facing.y negative", async ({
    page,
    context,
  }) => {
    test.setTimeout(60_000);
    await context.route("**/*", (route) => route.continue());

    const capture = new ConsoleCapture(page);
    capture.attach();

    const { canvas, playerX, playerY } = await bootAndReadPlayerPos(page, capture);
    const canvasBB = await canvas.boundingBox();
    expect(canvasBB).not.toBeNull();

    // Target mouse position: NORTH of the player (Godot Y is +DOWN, so
    // smaller Y = north). At (playerX, playerY - AIM_OFFSET_PX) the delta is
    // (0, -200) → facing.y ≈ -1.0.
    //
    // **Camera-clamp safety.** The player at spawn is at Y=200; mouse target
    // Y=0 is within canvas bounds (0..720) so the move is safe. If a future
    // refactor changes the spawn Y high enough that AIM_OFFSET_PX would push
    // the target negative, we'd clamp here — but with spawn at (240, 200)
    // and offset 200, target is (240, 0), exactly at the canvas top edge.
    const targetX = playerX;
    const targetY = Math.max(0, playerY - AIM_OFFSET_PX);

    const preTryAttackLines = capture
      .getLines()
      .filter((l) => /\[combat-trace\] Player\.try_attack \| FIRED/.test(l.text)).length;

    await page.mouse.move(canvasBB!.x + targetX, canvasBB!.y + targetY);
    await page.waitForTimeout(200);
    await canvas.click({ position: { x: targetX, y: targetY } });
    await page.waitForTimeout(400);

    const fireLines = capture
      .getLines()
      .filter((l) => /\[combat-trace\] Player\.try_attack \| FIRED/.test(l.text))
      .slice(preTryAttackLines);
    expect(
      fireLines.length,
      `Expected at least one Player.try_attack FIRED line after mouse-north + LMB click. ` +
        `Player at (${playerX}, ${playerY}), mouse at (${targetX}, ${targetY}). ` +
        `Got ${fireLines.length}.`
    ).toBeGreaterThanOrEqual(1);
    const match = fireLines[0].text.match(/facing=\(([-\d.]+),([-\d.]+)\)/);
    expect(match).not.toBeNull();
    const fx = parseFloat(match![1]);
    const fy = parseFloat(match![2]);
    expect(
      Math.abs(fx),
      `Mouse-north click: expected |facing.x| < 0.3. ` +
        `Player at (${playerX}, ${playerY}), mouse aim at (${targetX}, ${targetY}), ` +
        `got facing=(${fx}, ${fy}).`
    ).toBeLessThan(0.3);
    expect(
      fy,
      `Mouse-north click: expected facing.y < -0.5 (pointing north). ` +
        `Player at (${playerX}, ${playerY}), mouse aim at (${targetX}, ${targetY}), ` +
        `got facing=(${fx}, ${fy}).`
    ).toBeLessThan(-0.5);
  });

  test("RMB heavy attack direction also uses mouse-derived facing", async ({
    page,
    context,
  }) => {
    test.setTimeout(60_000);
    await context.route("**/*", (route) => route.continue());

    const capture = new ConsoleCapture(page);
    capture.attach();

    const { canvas, playerX, playerY } = await bootAndReadPlayerPos(page, capture);
    const canvasBB = await canvas.boundingBox();
    expect(canvasBB).not.toBeNull();

    // Target mouse position: WEST of the player. At (playerX - AIM_OFFSET_PX,
    // playerY) the delta is (-200, 0) → facing.x ≈ -1.0.
    //
    // **Room boundary safety.** Player spawn X=240; AIM_OFFSET_PX=200 puts
    // target at X=40, comfortably within canvas (0..1280). Clamp to 0 for
    // safety if a future spawn shift would push below.
    const targetX = Math.max(0, playerX - AIM_OFFSET_PX);
    const targetY = playerY;

    const preTryAttackLines = capture
      .getLines()
      .filter((l) =>
        /\[combat-trace\] Player\.try_attack \| FIRED kind=heavy/.test(l.text)
      ).length;

    // RMB is fired by page.mouse.click(..., {button: "right"}); canvas.click
    // with button:right also works, but page.mouse.click takes absolute page
    // coords (canvas bbox offset + target) — match the original spec shape.
    await page.mouse.move(canvasBB!.x + targetX, canvasBB!.y + targetY);
    await page.waitForTimeout(200);
    await page.mouse.click(canvasBB!.x + targetX, canvasBB!.y + targetY, {
      button: "right",
    });
    await page.waitForTimeout(400);

    const fireLines = capture
      .getLines()
      .filter((l) =>
        /\[combat-trace\] Player\.try_attack \| FIRED kind=heavy/.test(l.text)
      )
      .slice(preTryAttackLines);
    expect(
      fireLines.length,
      `Expected at least one Player.try_attack FIRED kind=heavy line after mouse-west + RMB click. ` +
        `Player at (${playerX}, ${playerY}), mouse at (${targetX}, ${targetY}). ` +
        `Got ${fireLines.length}.`
    ).toBeGreaterThanOrEqual(1);
    const match = fireLines[0].text.match(/facing=\(([-\d.]+),([-\d.]+)\)/);
    expect(match).not.toBeNull();
    const fx = parseFloat(match![1]);
    const fy = parseFloat(match![2]);
    expect(
      fx,
      `Mouse-west RMB: expected facing.x < -0.5 (pointing west). ` +
        `Player at (${playerX}, ${playerY}), mouse aim at (${targetX}, ${targetY}), ` +
        `got facing=(${fx}, ${fy}).`
    ).toBeLessThan(-0.5);
    expect(
      Math.abs(fy),
      `Mouse-west RMB: expected |facing.y| < 0.3 (horizontal-ish). ` +
        `Player at (${playerX}, ${playerY}), mouse aim at (${targetX}, ${targetY}), ` +
        `got facing=(${fx}, ${fy}).`
    ).toBeLessThan(0.3);
  });
});
