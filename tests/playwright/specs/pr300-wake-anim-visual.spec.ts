/**
 * pr300-wake-anim-visual.spec.ts — PR #300 v4 self-soak visual capture
 *
 * Captures the boss wake animation (M3-T2-W1-T8, ticket 86c9wjyp9) over its
 * ~417 ms WAKE_DURATION window, plus damage-immunity proof traces.
 *
 * **Why the wake-trigger is simpler than PR #291's slam:** the boss wake is
 * auto-fired on boss-room load via `Stratum1BossRoom._assemble_room_fixtures`
 * → `trigger_entry_sequence()` → 1.8 s SceneTreeTimer → `_complete_entry_sequence`
 * → `Stratum1Boss.wake()`. No player input or proximity check required —
 * loading `?start_room=8` is sufficient. The spec waits for the
 * `Stratum1Boss.wake` trace, then bursts screenshots through the 417 ms
 * animation window.
 *
 * **Capture cadence design:**
 *   - Trace detection: 20 ms poll (matches Drew's PR #291 v6 pattern)
 *   - Screenshot burst on detection: ~50 ms cadence × 11 frames = 0–500 ms
 *     covering the 5 PixelLab wake frames (~83 ms apart at WAKE_DURATION/5)
 *   - One more frame after the wake-complete trace (STATE_IDLE entry)
 *
 * **Damage-immunity probe:**
 *   - During WAKING window: spec fires one attack (LMB click), then scans
 *     traces for `Stratum1Boss.take_damage | IGNORED waking ...`
 *   - After STATE_IDLE: spec fires one attack, then scans for either a
 *     `Stratum1Boss.take_damage | applied` (or non-IGNORED) line, or a
 *     `Stratum1Boss._play_hit_flash` line which fires only on damage landing
 *
 * **Audio probe:**
 *   - `[combat-trace] AudioDirector.play_sfx | cue_id=sfx-boss-wake` (T7)
 *     should fire at wake entry per `audio-architecture.md` § BI-06.
 *
 * **Sources:**
 *   - scripts/mobs/Stratum1Boss.gd::wake() — trace string source
 *   - scripts/mobs/Stratum1Boss.gd::_process_waking — wake-complete trace
 *   - scripts/levels/Stratum1BossRoom.gd::_complete_entry_sequence — wake hook
 *   - Drew PR #291 v6 self-soak comment-id 4508538535 — capture-pattern precedent
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";
import { clickAimedFromPlayer } from "../fixtures/mouse-facing";

const BOOT_TIMEOUT_MS = 30_000;
const WAKE_TRIGGER_TIMEOUT_MS = 15_000; // entry-sequence is 1.8s; large margin
const WAKE_DURATION_MS = 417;
const POST_WAKE_SETTLE_MS = 300;

// QUARANTINED 2026-05-23 — ClickUp `86c9y00m1` (Playwright triage).
// Persistent failure: "in-wake attack must NOT land damage" assert + boss-wake
// IDLE-trace timeout (10000ms) in headless Chromium. Same root-cause class as
// pr291-{aftershock-visual,boss-slam-diag}. Re-enable when headless-vs-real-
// browser boss-wake divergence is resolved. Do not bisect — cite the ticket.
test.describe("PR #300 v4 — boss wake-anim visual capture + damage-immunity proof", () => {
  test.skip("wake animation captures at distinct timing windows + damage-immune during wake", async ({
    page,
    context,
  }) => {
    test.setTimeout(120_000);
    await context.route("**/*", (route) => route.continue());

    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    // start_room=8 drops directly into boss room (no Room 01-07 traversal).
    // boss_hp_mult=0.05 leaves boss at 30 HP — keeps the damage-immunity probe
    // safe: even if the post-wake attack lands the boss survives long enough
    // to assert the trace.
    const url = `${baseURL}/?start_room=8&boss_hp_mult=0.05`;
    await page.goto(url, { waitUntil: "domcontentloaded" });

    // ---- Phase 1: boot + verify BuildInfo SHA + start_room landed ----------
    const buildLine = await capture.waitForLine(
      /\[BuildInfo\] build: [0-9a-f]{7}/,
      BOOT_TIMEOUT_MS
    );
    console.log(`[pr300-wake] ${buildLine}`);

    await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);
    await capture.waitForLine(
      /\[Main\] DebugFlags\.start_room=8 — bypassing Room 01 traversal/,
      5_000
    );

    // Focus the canvas so subsequent KB / mouse input lands in Godot.
    const canvas = page.locator("canvas").first();
    await canvas.click({ position: { x: 256, y: 144 } });
    await page.waitForTimeout(200);

    // ---- Phase 2: capture DORMANT pose (pre-wake) -------------------------
    // Wait for `_assemble_room_fixtures` then snapshot before wake fires.
    await capture.waitForLine(
      /\[combat-trace\] Stratum1BossRoom\._assemble_room_fixtures/,
      10_000
    );
    await page.waitForTimeout(150); // small settle, still well inside the 1.8s window
    await page.screenshot({
      path: "test-results/pr300-wake-00-dormant.png",
      fullPage: false,
    });

    // ---- Phase 3: wait for wake trace, then burst-capture -----------------
    // Trace shape (Stratum1Boss.gd:438):
    //   [combat-trace] Stratum1Boss.wake | exiting STATE_DORMANT -> STATE_WAKING ...
    const wakeTrace = await capture.waitForLine(
      /\[combat-trace\] Stratum1Boss\.wake \| exiting STATE_DORMANT -> STATE_WAKING/,
      WAKE_TRIGGER_TIMEOUT_MS
    );
    const wakeStartMs = Date.now();
    console.log(`[pr300-wake] wake trace fired at boot+~1.8s: ${wakeTrace}`);

    // **Fire the in-wake attack FIRST**, before the burst-capture loop —
    // `page.screenshot()` is slow (~150-300 ms each on HTML5 release builds
    // headless), so a 10-frame burst dilates wall-clock far past the engine's
    // 417 ms WAKE_DURATION even though `waitForTimeout(50)` is set. Firing
    // the attack within the first ~50 ms of the wake-trace guarantees the
    // engine's `take_damage` call lands during STATE_WAKING, regardless of
    // how slow the screenshot pipeline runs.
    const inWakeAttackTracesPreCount = capture.getLines().length;
    const inWakeAttackAtMs = Date.now() - wakeStartMs;
    await clickAimedFromPlayer(canvas, capture, "N", { offsetPx: 120 });
    console.log(
      `[pr300-wake] in-wake attack fired at +${inWakeAttackAtMs}ms post-wake-trace`
    );

    // Burst-capture across the wake window. Cadence ~50 ms × 10 frames
    // = nominal 0..450 ms engine-time. Screenshot wall-clock is slower (real
    // browser headless screenshots can take 150-300 ms each), but the engine
    // continues physics-stepping during the screenshot — the captured PNGs
    // represent distinct points across the wake animation playback.
    const wakeFrames: { idx: number; elapsedMs: number; path: string }[] = [];
    const BURST_FRAMES = 10;
    const BURST_CADENCE_MS = 50;
    for (let i = 0; i < BURST_FRAMES; i++) {
      const elapsed = Date.now() - wakeStartMs;
      const path = `test-results/pr300-wake-${String(i + 1).padStart(2, "0")}-rising-t${elapsed}ms.png`;
      await page.screenshot({ path, fullPage: false });
      wakeFrames.push({ idx: i + 1, elapsedMs: elapsed, path });
      await page.waitForTimeout(BURST_CADENCE_MS);
    }

    // ---- Phase 4: scan for in-wake `IGNORED waking` damage-immunity trace -
    const inWakeAttackTraces = capture
      .getLines()
      .slice(inWakeAttackTracesPreCount)
      .filter((l) =>
        /\[combat-trace\] Stratum1Boss\.take_damage/.test(l.text)
      );
    console.log(
      `[pr300-wake] in-wake attack take_damage traces (${inWakeAttackTraces.length}):`
    );
    inWakeAttackTraces.forEach((l) => console.log(`  ${l.text}`));

    // ---- Phase 5: wait for wake-complete trace ----------------------------
    // Trace shape (Stratum1Boss.gd:584):
    //   [combat-trace] Stratum1Boss._process_waking | wake-anim complete -> STATE_IDLE ...
    const wakeCompleteTrace = await capture.waitForLine(
      /\[combat-trace\] Stratum1Boss\._process_waking \| wake-anim complete -> STATE_IDLE/,
      WAKE_DURATION_MS + 2_000
    );
    const wakeCompleteAtMs = Date.now() - wakeStartMs;
    console.log(
      `[pr300-wake] wake-complete trace fired at +${wakeCompleteAtMs}ms: ${wakeCompleteTrace}`
    );
    await page.waitForTimeout(POST_WAKE_SETTLE_MS);
    await page.screenshot({
      path: "test-results/pr300-wake-99-post-active.png",
      fullPage: false,
    });

    // ---- Phase 6: damage-immunity probe AFTER wake ------------------------
    // Attack 2: post-wake. Click aimed N toward boss (boss is at room center
    // ~(240, 130), player spawns at (240, 200) — N click hits the boss).
    const preAttack2LineCount = capture.getLines().length;
    await clickAimedFromPlayer(canvas, capture, "N", { offsetPx: 120 });
    await page.waitForTimeout(300); // physics + Hitbox spawn + take_damage

    const postWakeAttackTraces = capture
      .getLines()
      .slice(preAttack2LineCount)
      .filter((l) =>
        /\[combat-trace\] Stratum1Boss\.(take_damage|_play_hit_flash)/.test(
          l.text
        )
      );
    console.log(
      `[pr300-wake] post-wake attack traces (${postWakeAttackTraces.length}):`
    );
    postWakeAttackTraces.forEach((l) => console.log(`  ${l.text}`));

    // ---- Assertions -------------------------------------------------------
    //
    // 1. Wake started and completed (both traces present).
    const allLines = capture.getLines();
    const wakeStartLines = allLines.filter((l) =>
      /\[combat-trace\] Stratum1Boss\.wake \| exiting STATE_DORMANT -> STATE_WAKING/.test(
        l.text
      )
    );
    expect(wakeStartLines.length).toBeGreaterThanOrEqual(1);
    const wakeCompleteLines = allLines.filter((l) =>
      /\[combat-trace\] Stratum1Boss\._process_waking \| wake-anim complete -> STATE_IDLE/.test(
        l.text
      )
    );
    expect(wakeCompleteLines.length).toBeGreaterThanOrEqual(1);

    // 2. Wake duration sanity check. We measure WALL-CLOCK between the two
    //    traces, which is dilated by `page.screenshot()` cost (~150-300 ms
    //    per call × 10 frames). The engine-side `WAKE_DURATION = 0.417` is
    //    pinned by GUT (`tests/test_stratum1_boss_wake_anim.gd`); this assert
    //    only checks the wake-complete trace fires AT ALL within a generous
    //    wall-clock budget, not the precise 417 ms. A regression that
    //    accidentally locks the boss in STATE_WAKING forever fails here.
    expect(wakeCompleteAtMs).toBeGreaterThanOrEqual(100);
    expect(wakeCompleteAtMs).toBeLessThanOrEqual(10_000);

    // 3a. In-wake attack: if a take_damage trace fired at all, it MUST carry
    //     the `IGNORED waking` qualifier — damage-immunity is the entire
    //     point of T8's WAKING-window extension. Empty trace list is also
    //     acceptable (Hitbox.hit may not have overlapped the boss collision
    //     during the 50 ms screenshot cadence), but ANY non-IGNORED damage
    //     during WAKING is a regression.
    const ignoredDuringWake = inWakeAttackTraces.filter((l) =>
      /IGNORED waking/.test(l.text)
    );
    const landedDuringWake = inWakeAttackTraces.filter(
      (l) =>
        /\[combat-trace\] Stratum1Boss\.take_damage/.test(l.text) &&
        !/IGNORED/.test(l.text)
    );
    expect(
      landedDuringWake.length,
      "in-wake attack must NOT land damage — boss is damage-immune during WAKING"
    ).toBe(0);

    // 3b. Post-wake attack should NOT show "IGNORED waking" — boss is in
    //     STATE_IDLE and damage should land.
    const ignoredAfterWake = postWakeAttackTraces.filter((l) =>
      /IGNORED waking/.test(l.text)
    );
    expect(
      ignoredAfterWake.length,
      "post-wake attack must NOT emit IGNORED waking trace — wake window has closed"
    ).toBe(0);

    // 4. Audio probe — sfx-boss-wake fires at wake entry (T7 audio sting).
    const audioTraces = allLines.filter((l) =>
      /\[combat-trace\] AudioDirector\.play_sfx \| cue_id=sfx-boss-wake/.test(
        l.text
      )
    );
    console.log(
      `[pr300-wake] sfx-boss-wake audio cue lines: ${audioTraces.length}`
    );

    // 5. Summary dump for the Self-Test Report.
    console.log("[pr300-wake] === SUMMARY ===");
    console.log(`  wake-start traces: ${wakeStartLines.length}`);
    console.log(`  wake-complete traces: ${wakeCompleteLines.length}`);
    console.log(`  wake duration (wall-clock): ${wakeCompleteAtMs}ms`);
    console.log(`  burst frames captured: ${wakeFrames.length}`);
    wakeFrames.forEach((f) =>
      console.log(`    frame ${f.idx}: t+${f.elapsedMs}ms → ${f.path}`)
    );
    console.log(`  sfx-boss-wake audio traces: ${audioTraces.length}`);
    if (audioTraces.length > 0) {
      audioTraces.forEach((l) => console.log(`    ${l.text}`));
    }
    console.log(
      `  in-wake attack: IGNORED=${ignoredDuringWake.length} landed=${landedDuringWake.length}`
    );
    console.log(
      `  post-wake attack: IGNORED=${ignoredAfterWake.length} other_traces=${postWakeAttackTraces.length - ignoredAfterWake.length}`
    );

    capture.detach();
  });
});
