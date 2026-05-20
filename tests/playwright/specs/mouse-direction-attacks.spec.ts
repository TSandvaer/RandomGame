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
 * **Coordinate-model correction history.**
 *
 * **PR #255 respin (2026-05-17).** Pre-T9: spec moved mouse to canvas-center
 * + offset and asserted facing matched the offset direction. With canvas-center
 * SE of the player (no Camera2D era — player at world (240, 200) rendered at
 * canvas (240, 200), upper-left quadrant), the spec was broken — only the
 * LMB-east case passed by lucky additive geometry. Fix: derive mouse position
 * from the player's WORLD position via `Player.pos` trace + direction offset.
 *
 * **PR #293 respin (T9 CameraDirector landing, 2026-05-20).** The PR #255
 * fix baked in a different broken assumption: `world coord == canvas pixel
 * coord` (line comment "1:1 with canvas-pixel coords because no camera").
 * T9 introduced a CameraDirector autoload owning a Camera2D snap-following
 * the player at `BASELINE_ZOOM = 2.6667`. Post-T9, the camera transforms
 * canvas pixels to world coords as `world = camera.global_position +
 * (canvas_pixel - viewport_center) / zoom`. A click at canvas (440, 200)
 * (intended "200 px east of player") now maps to world (165, 140) — SW of
 * the player — and `facing=(-0.8, -0.6)` instead of the expected (+1.0, 0.0).
 *
 * **Post-T9 fix:** compute the desired aim target in WORLD coords, then
 * translate through the camera transform via `worldToCanvas(worldX, worldY,
 * cameraState)` from `mouse-facing.ts`. The helper reads the live camera
 * state from the `[combat-trace] CameraDirector.state | zoom=<v> pos=(x,y)`
 * trace (emitted every 0.25 s from `CameraDirector._emit_state_trace`).
 *
 * **Why a Playwright spec is needed here:** the GUT side validates the math
 * (pure helper) and the state gate (no mid-swing drift). What it cannot
 * cover is "the actual mouse event reaches Godot's `get_global_mouse_position`
 * in the HTML5 build." Playwright's `page.mouse.move()` drives the real
 * browser cursor over the canvas, the same way Sponsor's manual play would.
 *
 * **What this spec deliberately does NOT cover:**
 *
 *   - Sprite-rotation visual rendering. Post-M3W-2 the AnimatedSprite2D
 *     carries direction via per-frame art, so the Sprite node's `.rotation`
 *     is pinned to 0 across all `_facing` angles. The GUT side
 *     `test_sprite_rotation_stays_zero_across_facing` pins that invariance;
 *     an HTML5 visual check is documented in the Self-Test Report.
 *   - Dead-zone (mouse on top of player). The GUT side covers it
 *     mechanically (`test_mouse_inside_deadzone_keeps_last_facing`); the
 *     browser-coord precision needed to land exactly within 8px of the
 *     player's render position is brittle and adds no signal over the GUT
 *     coverage.
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";
import {
  latestPlayerPos,
  latestCameraState,
  worldToCanvas,
  DEFAULT_PLAYER_SPAWN,
} from "../fixtures/mouse-facing";

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

    // Target mouse position: EAST of the player. POST-T9: the Camera2D
    // transforms canvas pixels to world coords, so we compute the desired
    // WORLD target then translate through the camera transform via
    // `worldToCanvas` (see `mouse-facing.ts` for the math). A click at
    // canvas-pixel(worldToCanvas(playerX + 200, playerY)) puts the mouse
    // 200 world-px east of the player → delta ~(+200, 0) → facing.x ≈ 1.0.
    const worldTargetX = playerX + AIM_OFFSET_PX;
    const worldTargetY = playerY;
    const cam = latestCameraState(capture);
    const target = worldToCanvas(worldTargetX, worldTargetY, cam);

    const preTryAttackLines = capture
      .getLines()
      .filter((l) => /\[combat-trace\] Player\.try_attack \| FIRED/.test(l.text)).length;

    // Hover the mouse to let _update_mouse_facing land at least one physics
    // frame BEFORE the click (canvas.click moves+clicks atomically, but the
    // separate hover ensures the dead-zone check has fired against the new
    // position even if the engine throttles between the click's move and its
    // press event).
    await page.mouse.move(canvasBB!.x + target.x, canvasBB!.y + target.y);
    await page.waitForTimeout(200);
    await canvas.click({ position: { x: target.x, y: target.y } });
    await page.waitForTimeout(400);

    const fireLines = capture
      .getLines()
      .filter((l) => /\[combat-trace\] Player\.try_attack \| FIRED/.test(l.text))
      .slice(preTryAttackLines);
    expect(
      fireLines.length,
      `Expected at least one Player.try_attack FIRED line after mouse-east + LMB click. ` +
        `Player at world (${playerX}, ${playerY}), world target (${worldTargetX}, ${worldTargetY}), ` +
        `canvas click (${target.x.toFixed(0)}, ${target.y.toFixed(0)}). ` +
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
        `Player at world (${playerX}, ${playerY}), world target (${worldTargetX}, ${worldTargetY}), ` +
        `canvas click (${target.x.toFixed(0)}, ${target.y.toFixed(0)}), ` +
        `got facing=(${fx}, ${fy}). Full line: "${firstFire}"`
    ).toBeGreaterThan(0.5);
    expect(
      Math.abs(fy),
      `Mouse-east click: expected |facing.y| < 0.3 (horizontal-ish). ` +
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
    // smaller Y = north). World target at (playerX, playerY - 200), delta
    // (0, -200) → facing.y ≈ -1.0. Translated through the camera transform
    // via `worldToCanvas` — at default zoom 2.6667 with camera at player,
    // the canvas click lands at viewport_center.y - 200*2.6667 ≈ -173, which
    // the `worldToCanvas` clamp pulls to the canvas-top edge (y=0). The
    // dead-zone is on the WORLD-delta (200 px); the canvas clamp doesn't
    // affect facing math because `get_global_mouse_position` always inverts
    // the clamped canvas pixel back through the same camera transform.
    const worldTargetX = playerX;
    const worldTargetY = playerY - AIM_OFFSET_PX;
    const cam = latestCameraState(capture);
    const target = worldToCanvas(worldTargetX, worldTargetY, cam);

    const preTryAttackLines = capture
      .getLines()
      .filter((l) => /\[combat-trace\] Player\.try_attack \| FIRED/.test(l.text)).length;

    await page.mouse.move(canvasBB!.x + target.x, canvasBB!.y + target.y);
    await page.waitForTimeout(200);
    await canvas.click({ position: { x: target.x, y: target.y } });
    await page.waitForTimeout(400);

    const fireLines = capture
      .getLines()
      .filter((l) => /\[combat-trace\] Player\.try_attack \| FIRED/.test(l.text))
      .slice(preTryAttackLines);
    expect(
      fireLines.length,
      `Expected at least one Player.try_attack FIRED line after mouse-north + LMB click. ` +
        `Player at world (${playerX}, ${playerY}), world target (${worldTargetX}, ${worldTargetY}), ` +
        `canvas click (${target.x.toFixed(0)}, ${target.y.toFixed(0)}). Got ${fireLines.length}.`
    ).toBeGreaterThanOrEqual(1);
    const match = fireLines[0].text.match(/facing=\(([-\d.]+),([-\d.]+)\)/);
    expect(match).not.toBeNull();
    const fx = parseFloat(match![1]);
    const fy = parseFloat(match![2]);
    expect(
      Math.abs(fx),
      `Mouse-north click: expected |facing.x| < 0.3. got facing=(${fx}, ${fy}).`
    ).toBeLessThan(0.3);
    expect(
      fy,
      `Mouse-north click: expected facing.y < -0.5 (pointing north). got facing=(${fx}, ${fy}).`
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

    // Target mouse position: WEST of the player. World target at (playerX -
    // 200, playerY), delta (-200, 0) → facing.x ≈ -1.0. Translated through
    // the camera transform via `worldToCanvas` — at default zoom 2.6667 with
    // camera at player at world (240, 200), the canvas click lands at
    // viewport_center.x - 200*2.6667 ≈ 107, well within canvas bounds.
    const worldTargetX = playerX - AIM_OFFSET_PX;
    const worldTargetY = playerY;
    const cam = latestCameraState(capture);
    const target = worldToCanvas(worldTargetX, worldTargetY, cam);

    const preTryAttackLines = capture
      .getLines()
      .filter((l) =>
        /\[combat-trace\] Player\.try_attack \| FIRED kind=heavy/.test(l.text)
      ).length;

    // RMB is fired by page.mouse.click(..., {button: "right"}); canvas.click
    // with button:right also works, but page.mouse.click takes absolute page
    // coords (canvas bbox offset + target) — match the original spec shape.
    await page.mouse.move(canvasBB!.x + target.x, canvasBB!.y + target.y);
    await page.waitForTimeout(200);
    await page.mouse.click(canvasBB!.x + target.x, canvasBB!.y + target.y, {
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
        `Player at world (${playerX}, ${playerY}), world target (${worldTargetX}, ${worldTargetY}), ` +
        `canvas click (${target.x.toFixed(0)}, ${target.y.toFixed(0)}). Got ${fireLines.length}.`
    ).toBeGreaterThanOrEqual(1);
    const match = fireLines[0].text.match(/facing=\(([-\d.]+),([-\d.]+)\)/);
    expect(match).not.toBeNull();
    const fx = parseFloat(match![1]);
    const fy = parseFloat(match![2]);
    expect(
      fx,
      `Mouse-west RMB: expected facing.x < -0.5 (pointing west). got facing=(${fx}, ${fy}).`
    ).toBeLessThan(-0.5);
    expect(
      Math.abs(fy),
      `Mouse-west RMB: expected |facing.y| < 0.3 (horizontal-ish). got facing=(${fx}, ${fy}).`
    ).toBeLessThan(0.3);
  });
});
