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
 *   1. With the mouse positioned EAST of the player canvas-center, a LMB
 *      click fires a `Player.try_attack | FIRED kind=light facing=(+x,~0)`
 *      line — facing.x positive, facing.y ~zero.
 *   2. With the mouse positioned NORTH, the resulting `facing=` is `(~0,-y)`.
 *   3. RMB heavy uses the same mouse-derived facing — `kind=heavy
 *      facing=(...)` matches the mouse position.
 *   4. Mouse on top of player (dead-zone) does NOT update facing — but this
 *      is harder to assert in browser because of canvas-coord vs world-coord
 *      mismatch; the GUT side (`test_player_mouse_facing.gd`) covers this
 *      mechanically. The Playwright spec focuses on the directional-quadrant
 *      assertions where browser coords map cleanly.
 *
 * **Why a Playwright spec is needed here:** the GUT side validates the math
 * (pure helper) and the state gate (no mid-swing drift). What it cannot
 * cover is "the actual mouse event reaches Godot's `get_global_mouse_position`
 * in the HTML5 build." Playwright's `page.mouse.move()` drives the real
 * browser cursor over the canvas, the same way Sponsor's manual play would
 * — so a regression where Godot stops receiving mouse events on HTML5
 * (e.g. a future input-handling change that breaks the canvas focus / event
 * binding) fails this spec.
 *
 * **What this spec deliberately does NOT cover:**
 *
 *   - Sprite-rotation visual rendering. The sprite is a 16×16 ColorRect —
 *     rotation is mathematically observable on the node but visually
 *     undetectable in a screenshot (a rotated square is still a square).
 *     The GUT side `test_sprite_rotation_updates_when_present` pins the
 *     wiring; an HTML5 visual check is documented in the Self-Test Report.
 *   - AC4 / room-traversal regression sweep. The mouse-direction change DOES
 *     affect every existing spec that uses `canvas.click({position: center})`
 *     (the click now sets the attack direction toward canvas-center, which
 *     is approximately ON the player → dead-zone → keep-last-facing). Tess
 *     covers the harness migration in a follow-up.
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";

const BOOT_TIMEOUT_MS = 30_000;

test.describe("Mouse-direction attacks (ticket 86c9uthf0)", () => {
  test("LMB attack direction = mouse-east → facing.x positive", async ({
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
    const canvas = page.locator("canvas").first();
    await canvas.click(); // Focus + AudioContext unlock.
    await page.waitForTimeout(500);

    const canvasBB = await canvas.boundingBox();
    expect(canvasBB).not.toBeNull();
    const cx = canvasBB!.x + canvasBB!.width / 2;
    const cy = canvasBB!.y + canvasBB!.height / 2;

    // Move mouse EAST of canvas-center. The player is camera-centered in the
    // canvas (camera follows player → player at ~canvas-center). A mouse at
    // canvas-center + (300, 0) is reliably EAST of the player in world coords
    // regardless of camera tracking.
    const preTryAttackLines = capture
      .getLines()
      .filter((l) => /\[combat-trace\] Player\.try_attack \| FIRED/.test(l.text)).length;
    await page.mouse.move(cx + 300, cy);
    await page.waitForTimeout(200); // Let _physics_process tick + _update_mouse_facing land.
    // Click — Playwright's canvas.click drives at the current mouse position
    // when no `position` is passed. Pass explicit position to be deterministic.
    await canvas.click({ position: { x: canvasBB!.width / 2 + 300, y: canvasBB!.height / 2 } });
    await page.waitForTimeout(400);

    const fireLines = capture
      .getLines()
      .filter((l) => /\[combat-trace\] Player\.try_attack \| FIRED/.test(l.text))
      .slice(preTryAttackLines);
    expect(
      fireLines.length,
      `Expected at least one Player.try_attack FIRED line after mouse-east + LMB click. ` +
        `Got ${fireLines.length}. Last 15 trace lines:\n` +
        capture.getLines().slice(-15).map((l) => `  ${l.text}`).join("\n")
    ).toBeGreaterThanOrEqual(1);

    const firstFire = fireLines[0].text;
    // Parse "facing=(x.x,y.y)" — the Player.gd trace format is %.1f precision.
    const match = firstFire.match(/facing=\(([-\d.]+),([-\d.]+)\)/);
    expect(
      match,
      `try_attack FIRED line missing facing=(x,y) payload: "${firstFire}"`
    ).not.toBeNull();
    const fx = parseFloat(match![1]);
    const fy = parseFloat(match![2]);
    expect(
      fx,
      `Mouse-east click: expected facing.x > 0.5 (pointing east), got ${fx}. ` +
        `Full line: "${firstFire}"`
    ).toBeGreaterThan(0.5);
    expect(
      Math.abs(fy),
      `Mouse-east click: expected |facing.y| < 0.3 (horizontal-ish), got ${fy}. ` +
        `Full line: "${firstFire}"`
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

    const baseURL =
      process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(baseURL, { waitUntil: "domcontentloaded" });

    await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);
    const canvas = page.locator("canvas").first();
    await canvas.click();
    await page.waitForTimeout(500);

    const canvasBB = await canvas.boundingBox();
    expect(canvasBB).not.toBeNull();
    const cx = canvasBB!.x + canvasBB!.width / 2;
    const cy = canvasBB!.y + canvasBB!.height / 2;

    const preTryAttackLines = capture
      .getLines()
      .filter((l) => /\[combat-trace\] Player\.try_attack \| FIRED/.test(l.text)).length;
    // Mouse 300px ABOVE canvas-center (Y-down in canvas coords → smaller Y).
    await page.mouse.move(cx, cy - 300);
    await page.waitForTimeout(200);
    await canvas.click({ position: { x: canvasBB!.width / 2, y: canvasBB!.height / 2 - 300 } });
    await page.waitForTimeout(400);

    const fireLines = capture
      .getLines()
      .filter((l) => /\[combat-trace\] Player\.try_attack \| FIRED/.test(l.text))
      .slice(preTryAttackLines);
    expect(fireLines.length).toBeGreaterThanOrEqual(1);
    const match = fireLines[0].text.match(/facing=\(([-\d.]+),([-\d.]+)\)/);
    expect(match).not.toBeNull();
    const fx = parseFloat(match![1]);
    const fy = parseFloat(match![2]);
    expect(
      Math.abs(fx),
      `Mouse-north click: expected |facing.x| < 0.3, got ${fx}`
    ).toBeLessThan(0.3);
    expect(
      fy,
      `Mouse-north click: expected facing.y < -0.5 (pointing north / negative Y in Godot screen coords), got ${fy}`
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

    const baseURL =
      process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(baseURL, { waitUntil: "domcontentloaded" });

    await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);
    const canvas = page.locator("canvas").first();
    await canvas.click();
    await page.waitForTimeout(500);

    const canvasBB = await canvas.boundingBox();
    expect(canvasBB).not.toBeNull();
    const cx = canvasBB!.x + canvasBB!.width / 2;
    const cy = canvasBB!.y + canvasBB!.height / 2;

    const preTryAttackLines = capture
      .getLines()
      .filter((l) => /\[combat-trace\] Player\.try_attack \| FIRED kind=heavy/.test(l.text)).length;
    // Mouse 250 px WEST of canvas-center.
    await page.mouse.move(cx - 250, cy);
    await page.waitForTimeout(200);
    // page.mouse.click with button=right fires RMB.
    await page.mouse.click(cx - 250, cy, { button: "right" });
    await page.waitForTimeout(400);

    const fireLines = capture
      .getLines()
      .filter((l) => /\[combat-trace\] Player\.try_attack \| FIRED kind=heavy/.test(l.text))
      .slice(preTryAttackLines);
    expect(
      fireLines.length,
      `Expected at least one Player.try_attack FIRED kind=heavy line after mouse-west + RMB click. ` +
        `Got ${fireLines.length}.`
    ).toBeGreaterThanOrEqual(1);
    const match = fireLines[0].text.match(/facing=\(([-\d.]+),([-\d.]+)\)/);
    expect(match).not.toBeNull();
    const fx = parseFloat(match![1]);
    const fy = parseFloat(match![2]);
    expect(
      fx,
      `Mouse-west RMB: expected facing.x < -0.5 (pointing west), got ${fx}`
    ).toBeLessThan(-0.5);
    expect(
      Math.abs(fy),
      `Mouse-west RMB: expected |facing.y| < 0.3 (horizontal-ish), got ${fy}`
    ).toBeLessThan(0.3);
  });
});
