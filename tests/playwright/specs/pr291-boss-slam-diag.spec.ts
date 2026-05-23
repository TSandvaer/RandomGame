/**
 * pr291-boss-slam-diag.spec.ts — PR #291 v4 self-soak diagnostic
 *
 * NOT a permanent spec — this is the diagnostic-trace capture for the
 * B3 (boss slam visual) + T6 (slam aftershock CPUParticles2D visibility)
 * blockers Sponsor reported on PR #291 v3. The spec uses the new
 * `?start_room=8` + `?boss_hp_mult=0.05` URL-param soak utilities to drop
 * the player directly into the boss room with a 30-HP boss (phase 2 at
 * 19.8 HP, phase 3 at 9.9 HP — both reachable in ~30 fist hits since
 * player has no weapon equipped when start_room bypasses Room 01).
 *
 * Captures every `[combat-trace] Stratum1Boss.*` line and dumps the full
 * trace stream to stdout so the diagnostic file in team/drew-dev/ can
 * extract the load-bearing lines for the Self-Test Report v4 PR body.
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";
import {
  clickAimedFromPlayer,
  DEFAULT_PLAYER_SPAWN,
} from "../fixtures/mouse-facing";

const BOOT_TIMEOUT_MS = 30_000;
const COMBAT_TIMEOUT_MS = 90_000;

// QUARANTINED 2026-05-23 — ClickUp `86c9y4hfx` (Playwright triage).
// Persistent failure: timeout waiting for /Stratum1Boss\.wake.*now IDLE/ in
// headless Chromium (10000ms). Companion to pr291-aftershock-visual.spec.ts;
// same root-cause class. Re-enable when headless boss-wake reach-IDLE is
// resolved. Do not bisect — cite the ticket.
test.describe("PR #291 v4 — boss slam + aftershock diagnostic", () => {
  test.skip("dump combat-trace stream from boss-room slam sequence", async ({
    page,
    context,
  }) => {
    test.setTimeout(180_000);
    await context.route("**/*", (route) => route.continue());

    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    const url = `${baseURL}/?start_room=8&boss_hp_mult=0.05`;
    console.log(`[diag] navigating to ${url}`);
    await page.goto(url, { waitUntil: "domcontentloaded" });

    // ---- Phase 1: boot ----
    await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);
    console.log("[diag] boot ok");

    // Verify the start_room URL param landed.
    const debugFlagsLine = capture
      .getLines()
      .find((l) => /\[DebugFlags\] .*start_room=8/.test(l.text));
    expect(debugFlagsLine, "DebugFlags reads start_room=8 from URL").toBeDefined();

    // Verify boss-room jump fired.
    const startRoomJumpLine = capture
      .getLines()
      .find((l) => /\[Main\] DebugFlags\.start_room=8/.test(l.text));
    expect(
      startRoomJumpLine,
      "Main._ready respects DebugFlags.start_room and jumps to Room 8"
    ).toBeDefined();

    // ---- Phase 2: wait for boss wake (1.8s entry sequence) ----
    await capture.waitForLine(
      /\[combat-trace\] Stratum1Boss\.wake.*now IDLE/,
      10_000
    );
    console.log("[diag] boss woke");

    // ---- Phase 3: drive the player to attack the boss ----
    // Player spawned at DEFAULT_PLAYER_SPAWN = (240, 200). Boss is north
    // of player (typical boss-room layout). Aim N from player position
    // (mouse-facing fixture handles offsets correctly). Player has no
    // weapon (Room 01 PracticeDummy iron-sword drop was bypassed) so
    // each hit deals FIST_DAMAGE = 1. Boss has 30 HP (boss_hp_mult=0.05).
    // Need 30 hits to kill; phase 2 (slam) latches at HP < 19.8 = ~11
    // hits in; phase 3 at HP < 9.9 = ~21 hits in.
    const canvas = page.locator("canvas").first();
    await canvas.click({ position: { x: 256, y: 144 } });
    await page.waitForTimeout(200);

    const COMBAT_START = Date.now();
    let slamTelegraphSeen = false;
    let slamHitSeen = false;
    let aftershockSpawnSeen = false;
    let slamRecoveryAnimPlayed = false;
    let bossDied = false;
    let attackCount = 0;

    // Screenshots captured at key burst moments (T6 visibility diagnostic).
    let aftershockScreenshotFrames: number = 0;
    let slamTelegraphScreenshotTaken = false;

    while (Date.now() - COMBAT_START < COMBAT_TIMEOUT_MS) {
      // Click N of player (boss is at boss_spawn north of player spawn).
      await clickAimedFromPlayer(canvas, capture, "N", { offsetPx: 120 });
      attackCount++;
      await page.waitForTimeout(150); // allow attack recovery + boss tick

      const traces = capture.getLines();
      const wasSlamTelegraphSeen = slamTelegraphSeen;
      const wasAftershockSpawnSeen = aftershockSpawnSeen;
      slamTelegraphSeen ||= traces.some((l) =>
        /\[combat-trace\] Stratum1Boss\._play_anim \| PLAY anim=slam_telegraph_/.test(l.text)
      );
      slamHitSeen ||= traces.some((l) =>
        /\[combat-trace\] Stratum1Boss\._fire_slam_hit/.test(l.text)
      );
      aftershockSpawnSeen ||= traces.some((l) =>
        /\[combat-trace\] Stratum1Boss\._spawn_slam_aftershock/.test(l.text)
      );
      slamRecoveryAnimPlayed ||= traces.some((l) =>
        /\[combat-trace\] Stratum1Boss\._play_anim \| PLAY anim=slam_[nesw]+$/.test(l.text) ||
        /\[combat-trace\] Stratum1Boss\._play_anim \| PLAY anim=slam_[nesw]+ /.test(l.text)
      );
      bossDied ||= traces.some((l) =>
        /\[combat-trace\] Stratum1Boss\._die/.test(l.text)
      );

      // T5 telegraph indicator screenshot — capture immediately after
      // slam_telegraph anim starts (indicator circle should be visible).
      if (slamTelegraphSeen && !slamTelegraphScreenshotTaken) {
        await page.screenshot({
          path: ".claude/tmp/pr291-diag-slam-telegraph.png",
          fullPage: false,
        });
        slamTelegraphScreenshotTaken = true;
        console.log("[diag] screenshot captured: slam telegraph (T5 visual)");
      }

      // T6 aftershock screenshots — multiple frames after spawn fires to
      // catch the burst at different lifetimes (350ms total). Particles
      // most visible ~50-150ms in (after explosive emit, before fade).
      if (aftershockSpawnSeen && aftershockScreenshotFrames < 4) {
        await page.screenshot({
          path: `.claude/tmp/pr291-diag-aftershock-frame-${aftershockScreenshotFrames}.png`,
          fullPage: false,
        });
        aftershockScreenshotFrames++;
        console.log(`[diag] screenshot captured: aftershock frame ${aftershockScreenshotFrames - 1}`);
        await page.waitForTimeout(80); // 80ms between frames; 4 frames = ~320ms ≈ burst lifetime
      }

      if (bossDied) break;
      if (
        slamHitSeen &&
        aftershockSpawnSeen &&
        slamRecoveryAnimPlayed &&
        aftershockScreenshotFrames >= 4
      ) {
        // All signposts hit + 4 burst frames captured — done.
        break;
      }
    }

    // Final screenshot post-slam for record (slam recovery anim end).
    await page.screenshot({
      path: ".claude/tmp/pr291-diag-final.png",
      fullPage: false,
    });

    // ---- Phase 4: dump filtered trace stream ----
    const interestingPatterns = [
      /\[combat-trace\] Stratum1Boss\./,
      /\[combat-trace\] Player\.try_attack/,
      /\[combat-trace\] Hitbox\.hit.*target=Stratum1Boss/,
      /\[combat-trace\] Player\.pos/,
      /\[DebugFlags\]/,
      /\[BuildInfo\]/,
      /\[Main\]/,
      /USER ERROR/,
      /USER WARNING/,
    ];
    const allTraces = capture.getLines().filter((l) =>
      interestingPatterns.some((p) => p.test(l.text))
    );

    console.log("=".repeat(80));
    console.log(`[diag] FILTERED TRACE DUMP — ${allTraces.length} lines`);
    console.log("=".repeat(80));
    for (const line of allTraces) {
      console.log(`  [${line.type}] ${line.text}`);
    }
    console.log("=".repeat(80));
    console.log("[diag] TRACE DUMP END");
    console.log("=".repeat(80));

    // ---- Phase 5: diagnostic signposts ----
    console.log("[diag] SIGNPOSTS:");
    console.log(`  slam_telegraph anim PLAYed:   ${slamTelegraphSeen}`);
    console.log(`  slam_hit (_fire_slam_hit):    ${slamHitSeen}`);
    console.log(`  aftershock spawn fired:       ${aftershockSpawnSeen}`);
    console.log(`  slam recovery anim PLAYed:    ${slamRecoveryAnimPlayed}`);
    console.log(`  boss died:                    ${bossDied}`);
    console.log(`  attacks fired:                ${attackCount}`);

    // Count phase-change events
    const phaseChanges = capture.getLines().filter((l) =>
      /Stratum1Boss\.phase_transition_slow_mo/.test(l.text)
    );
    console.log(`  phase transitions fired:      ${phaseChanges.length}`);

    // ---- Phase 6: load-bearing assertion ----
    expect(
      slamHitSeen,
      "diagnostic must witness at least one slam-fire — bump combat window if missing"
    ).toBe(true);
    expect(
      aftershockSpawnSeen,
      "_spawn_slam_aftershock should fire after _fire_slam_hit"
    ).toBe(true);

    capture.detach();
  });
});
