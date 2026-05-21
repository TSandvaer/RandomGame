/**
 * pr291-aftershock-visual.spec.ts — PR #291 v4 self-soak visual-capture
 *
 * Companion to `pr291-boss-slam-diag.spec.ts`. The diag spec confirmed that
 * `_spawn_slam_aftershock` fires correctly with sane particle params. This
 * spec captures a screenshot sequence during the slam-fire window so we can
 * eyeball whether the 12-particle CPUParticles2D burst is actually visible
 * on the HTML5 canvas.
 *
 * Strategy:
 *  - Same boot path (`?start_room=8&boss_hp_mult=0.05`).
 *  - Drive player attacks until phase 2 (slam) latches.
 *  - On the very next `_spawn_slam_aftershock` console line, kick off a
 *    100ms screenshot cadence for ~600ms (covers the 350ms particle
 *    lifetime + before/after frames).
 *  - Save each frame as `test-results/pr291-aftershock-NNN.png` for visual
 *    inspection.
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";
import {
  clickAimedFromPlayer,
} from "../fixtures/mouse-facing";

const BOOT_TIMEOUT_MS = 30_000;
const COMBAT_TIMEOUT_MS = 90_000;
const AFTERSHOCK_CAPTURE_WINDOW_MS = 700; // covers 350ms lifetime + slack

test.describe("PR #291 v4 — aftershock visual capture", () => {
  test("screenshot sequence across slam-aftershock window", async ({
    page,
    context,
  }) => {
    test.setTimeout(180_000);
    await context.route("**/*", (route) => route.continue());

    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    const url = `${baseURL}/?start_room=8&boss_hp_mult=0.05`;
    await page.goto(url, { waitUntil: "domcontentloaded" });

    await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);
    await capture.waitForLine(
      /\[combat-trace\] Stratum1Boss\.wake.*now IDLE/,
      10_000
    );

    const canvas = page.locator("canvas").first();
    await canvas.click({ position: { x: 256, y: 144 } });
    await page.waitForTimeout(200);

    const COMBAT_START = Date.now();
    let aftershockFired = false;

    while (Date.now() - COMBAT_START < COMBAT_TIMEOUT_MS) {
      await clickAimedFromPlayer(canvas, capture, "N", { offsetPx: 120 });
      await page.waitForTimeout(120);

      const traces = capture.getLines();
      aftershockFired = traces.some((l) =>
        /\[combat-trace\] Stratum1Boss\._spawn_slam_aftershock/.test(l.text)
      );

      if (aftershockFired) {
        console.log(`[diag] aftershock fired at t+${Date.now() - COMBAT_START}ms — starting capture`);
        // Kick off the screenshot cadence IMMEDIATELY (don't wait for next
        // tick — the burst is already 1-2 frames in by the time we see the
        // console line, but at 0.35s lifetime we still have ~300ms left).
        const captureStart = Date.now();
        let frameIdx = 0;
        while (Date.now() - captureStart < AFTERSHOCK_CAPTURE_WINDOW_MS) {
          const ts = Date.now() - captureStart;
          await page.screenshot({
            path: `test-results/pr291-aftershock-${String(frameIdx).padStart(3, "0")}-t${ts}ms.png`,
            fullPage: false,
          });
          frameIdx++;
          await page.waitForTimeout(50);
        }
        console.log(`[diag] captured ${frameIdx} aftershock frames`);
        break;
      }
    }

    expect(aftershockFired, "aftershock must fire to capture visual evidence").toBe(true);

    capture.detach();
  });
});
