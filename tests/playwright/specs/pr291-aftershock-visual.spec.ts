/**
 * pr291-aftershock-visual.spec.ts — PR #291 v5 self-soak visual-capture
 *
 * Companion to `pr291-boss-slam-diag.spec.ts`. The diag spec confirmed that
 * `_spawn_slam_aftershock` fires correctly with sane particle params. This
 * spec captures a screenshot sequence INTERLEAVED WITH combat attacks so we
 * catch the burst visually even if the slam-damage kills the player.
 *
 * **v5 lesson learned (Drew, 2026-05-21):** the v4 version of this spec waited
 * for `_spawn_slam_aftershock` trace BEFORE starting the screenshot cadence —
 * but at boss_hp_mult=0.05 the boss's slam damage (17) lands at low player HP
 * and kills the player, triggering `apply_death_rule | reloading Room 01`
 * BEFORE the screenshot loop could fire. Result: 2 screenshots of Room 01
 * (after respawn), not the aftershock burst in the boss room.
 *
 * **Fix:** take a screenshot on EVERY attack iteration. The aftershock
 * lifetime is 350 ms — at ~150 ms per iteration we get 2-3 frames covering
 * the burst. Screenshots labeled by elapsed-from-aftershock-fire-trace so
 * post-hoc analysis can pick the right frame.
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";
import {
  clickAimedFromPlayer,
} from "../fixtures/mouse-facing";

const BOOT_TIMEOUT_MS = 30_000;
const COMBAT_TIMEOUT_MS = 150_000;
const POST_AFTERSHOCK_CAPTURE_FRAMES = 8;

test.describe("PR #291 v5 — aftershock visual capture", () => {
  test("interleaved screenshot capture during slam-aftershock window", async ({
    page,
    context,
  }) => {
    test.setTimeout(240_000);
    await context.route("**/*", (route) => route.continue());

    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    // boss_hp_mult=0.05 → 30 HP boss. Phase 2 (slam) latches at HP < 60% × 30 = 18.
    // Player at 100 HP, fist deals 1 dmg, boss melee deals ~12 — player survives
    // 8 boss swings. At ~7 player hits/sec we reach 18 HP boss in ~12 player
    // attacks, well before player dies. v4 diag spec validated this exact value.
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
    let aftershockFiredAt: number = -1;
    let postAftershockFrameCount = 0;
    let frameIdx = 0;
    let bossDied = false;

    while (Date.now() - COMBAT_START < COMBAT_TIMEOUT_MS) {
      await clickAimedFromPlayer(canvas, capture, "N", { offsetPx: 120 });

      // Screenshot EVERY iteration so we don't miss the burst window.
      const elapsed = Date.now() - COMBAT_START;
      const elapsedFromAftershock =
        aftershockFiredAt > 0 ? Date.now() - aftershockFiredAt : -1;
      const filename =
        aftershockFiredAt > 0
          ? `test-results/pr291-v5-aftershock-${String(frameIdx).padStart(3, "0")}-post${elapsedFromAftershock}ms.png`
          : `test-results/pr291-v5-pre-${String(frameIdx).padStart(3, "0")}-t${elapsed}ms.png`;
      await page.screenshot({ path: filename, fullPage: false });
      frameIdx++;

      await page.waitForTimeout(120);

      const traces = capture.getLines();
      if (aftershockFiredAt < 0) {
        const aftershockTrace = traces.find((l) =>
          /\[combat-trace\] Stratum1Boss\._spawn_slam_aftershock/.test(l.text)
        );
        if (aftershockTrace) {
          aftershockFiredAt = Date.now();
          console.log(
            `[diag] aftershock fired at t+${aftershockFiredAt - COMBAT_START}ms — interleaved capture continues`
          );
          console.log(`  trace: ${aftershockTrace.text}`);
        }
      } else {
        postAftershockFrameCount++;
        if (postAftershockFrameCount >= POST_AFTERSHOCK_CAPTURE_FRAMES) {
          console.log(
            `[diag] captured ${postAftershockFrameCount} post-aftershock frames`
          );
          break;
        }
      }

      bossDied = traces.some((l) =>
        /\[combat-trace\] Stratum1Boss\._die/.test(l.text)
      );
      if (bossDied) {
        console.log("[diag] boss died — stopping capture");
        break;
      }
    }

    expect(
      aftershockFiredAt,
      "aftershock must fire during the window — bump combat_timeout if absent"
    ).toBeGreaterThan(0);

    capture.detach();
  });
});
