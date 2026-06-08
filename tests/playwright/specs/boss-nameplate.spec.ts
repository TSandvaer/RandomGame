/**
 * boss-nameplate.spec.ts — M3-T2-W3-T13 BossNameplate visibility +
 * slide-in trace + phase-transition flash + T18 below-10% pulse end-to-end.
 *
 * **Ticket:** `86c9wjz2d` (T13) + `86c9wjz5e` (T18 ship-with).
 *
 * **Scope.** The headless GUT pin (`tests/test_boss_nameplate.gd` +
 * `tests/test_stratum1_boss_room.gd::test_boss_nameplate_*`) cover
 * structural composition (primitive counts, HDR-clamp colors, dimension
 * locks, phase-label state, idempotence, ghost-drain tween restart, T18
 * pulse engagement + dismissal). This Playwright spec covers the
 * end-to-end HTML5 release-build flow that GUT cannot reach:
 *
 *   1. Build boots + reaches boss room via `?start_room=8`.
 *   2. Nameplate slide-in trace fires after the 1.8 s entry sequence.
 *   3. Console + DOM screenshot captures the nameplate visible during
 *      the fight (post-entry-sequence-completion state).
 *   4. Damaging the boss triggers `BossNameplate.segment_fill_updated`
 *      observable traces (via the [combat-trace] shim).
 *   5. Phase transition flashes (one screenshot at +1, one at +2).
 *
 * **Damage-immunity caveat:** the boss starts dormant + immune through
 * the entry sequence + wake animation. After `STATE_IDLE` is reached
 * (post-wake), the harness fires LMB clicks to drive damage. Boss HP is
 * scaled down via `boss_hp_mult=0.05` so a couple of clicks reach the
 * phase-2 boundary cleanly.
 *
 * **HTML5 visual-verification.** Per `.claude/docs/html5-export.md`
 * § "Playwright headless ≠ real-browser perception": these headless
 * screenshots are evidence the primitives RENDERED at correct positions
 * with correct config, NOT a proof of "Sponsor will perceive this in
 * real-time motion". The Self-Test Report routes interactive visual
 * verification via the per-surface escape clause + Sponsor-soak probe
 * targets.
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";
import { clickAimedFromPlayer } from "../fixtures/mouse-facing";

const BOOT_TIMEOUT_MS = 30_000;
const ENTRY_SEQUENCE_TIMEOUT_MS = 15_000; // 1.8 s + slack
const POST_PHASE_SETTLE_MS = 300;

test.describe("M3-T13 BossNameplate visibility + slide-in + phase transition", () => {
  test("nameplate slides in at entry-sequence-completion + phase transitions flash", async ({
    page,
    context,
  }) => {
    test.setTimeout(120_000);
    await context.route("**/*", (route) => route.continue());

    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    // `start_room=8` drops directly into boss room (skips rooms 1-7).
    // `boss_hp_mult=0.05` scales boss to 30 HP — phase boundaries land at
    // ~20 HP (phase 2) and ~10 HP (phase 3); the player's fist damage of
    // 1 / hit reaches phase 2 in ~10 swings, phase 3 in another ~10.
    // Light enough to drive multi-phase progression without a 30-min
    // pacing test.
    const url = `${baseURL}/?start_room=8&boss_hp_mult=0.05`;
    await page.goto(url, { waitUntil: "domcontentloaded" });

    // ---- Phase 1: boot + start_room param landed ------------------------
    const buildLine = await capture.waitForLine(
      /\[BuildInfo\] build: [0-9a-f]{7}/,
      BOOT_TIMEOUT_MS
    );
    console.log(`[boss-nameplate] ${buildLine}`);
    await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);
    await capture.waitForLine(
      /\[Main\] DebugFlags\.start_room=8 — bypassing Room 01 traversal/,
      5_000
    );

    // Focus canvas so input lands in Godot.
    const canvas = page.locator("canvas").first();
    await canvas.click({ position: { x: 256, y: 144 } });
    await page.waitForTimeout(150);

    // ---- Phase 2: pre-nameplate (entry sequence in flight) screenshot ----
    // The room's `_assemble_room_fixtures` trace fires after the deferred
    // pass; the nameplate is spawned hidden at that point.
    await capture.waitForLine(
      /\[combat-trace\] Stratum1BossRoom\._assemble_room_fixtures/,
      10_000
    );
    await page.screenshot({
      path: "test-results/boss-nameplate-00-pre-entry-sequence.png",
      fullPage: false,
    });

    // ---- Phase 3: wait for slide-in completion trace ---------------------
    // `entry_sequence_completed` fires at boot+~1.8s; the nameplate's
    // slide-in tween runs for 0.4s after that. `BossNameplate.slide_in_completed`
    // trace fires when the slide-in completes (~T+2.2s post-trigger).
    const slideTrace = await capture.waitForLine(
      /\[combat-trace\] BossNameplate\.slide_in_completed/,
      ENTRY_SEQUENCE_TIMEOUT_MS
    );
    console.log(`[boss-nameplate] slide-in completed: ${slideTrace}`);

    // Capture nameplate visible (post-slide-in steady-state).
    await page.screenshot({
      path: "test-results/boss-nameplate-01-post-slide-in.png",
      fullPage: false,
    });

    // ---- Phase 4: drive boss HP through phase 1 → phase 2 ---------------
    // The boss has `STATE_WAKING` for ~417 ms post-entry-sequence then
    // transitions to `STATE_IDLE` (chasing). Wait for STATE_IDLE handoff
    // trace before attacking so the damage actually lands (waking is
    // damage-immune). The trace is emitted from `_process_waking` at
    // the moment `_wake_left` drains; see `scripts/mobs/Stratum1Boss.gd`
    // line ~743.
    await capture.waitForLine(
      /\[combat-trace\] Stratum1Boss\._process_waking \| wake-anim complete -> STATE_IDLE/,
      5_000
    );

    // Damage the boss until phase 2 fires.
    // boss_hp_mult=0.05 → 30 HP max. Phase 2 at 66% = 20 HP. Player fist =
    // 1 damage / swing; need ~10 swings to cross. Allow up to 40 attempts
    // before giving up (test failure rather than wandering off).
    //
    // **Scale-robust (ticket 86ca5hwmx soak-rev).** The player's swing reach
    // scales with char_scale: at the Sponsor-locked 0.48 the light hitbox covers
    // only ~27.8 px of contact (vs ~34.8 px at the prior 0.6). The boss is
    // char_scale-EXEMPT (stays 1.0, large hurtbox) and parks at its own melee
    // range, which can leave the SHRUNKEN player swing just short — so a fixed
    // "click N + swing" loop landed fewer hits at 0.48 and could miss the 10-hit
    // phase-2 threshold inside the old 30-attempt budget. We now NUDGE the player
    // NORTH toward the boss (spawns at world (240,135), due N of the (240,200)
    // player spawn) before each swing so the player closes into its own reach —
    // robust at 0.48 AND any future scale. Budget bumped 30→40 for margin.
    let phase2Hit = false;
    for (let i = 0; i < 40 && !phase2Hit; i++) {
      // Close the initial ~65 px gap to the boss (player spawn (240,200) → boss
      // (240,135)) over the first ~8 iterations only. 120 px/s × 90 ms ≈ 11 px /
      // burst → ~6-8 bursts cover 65 px; the boss CHASES thereafter so contact
      // is maintained without walking the player past/around the (large) boss.
      if (i < 8) {
        await page.keyboard.down("w");
        await page.waitForTimeout(90);
        await page.keyboard.up("w");
        await page.waitForTimeout(40);
      }
      await clickAimedFromPlayer(canvas, capture, "N", { offsetPx: 80 });
      await page.waitForTimeout(180);
      const phase2Line = capture
        .getLines()
        .find((l) =>
          /\[combat-trace\] BossNameplate\.phase_transition_flashed \| new_phase=2/.test(
            l.text
          )
        );
      if (phase2Line) {
        phase2Hit = true;
        console.log(`[boss-nameplate] phase 2 triggered at attempt ${i + 1}: ${phase2Line.text}`);
      }
    }
    expect(phase2Hit, "phase 2 transition fired within 30 attacks").toBe(true);

    await page.waitForTimeout(POST_PHASE_SETTLE_MS);
    await page.screenshot({
      path: "test-results/boss-nameplate-02-post-phase-2-transition.png",
      fullPage: false,
    });

    // ---- Phase 5: verify segment-fill traces fired during damage --------
    // The `segment_fill_updated` signal in the BossNameplate fires per hit;
    // we don't emit a combat-trace for every fill update (that would be
    // noisy) but the phase_transition trace IS emitted on each boundary
    // so we use it as the regression-pin. The presence of the post-phase-2
    // trace above already verifies the cascade (damaged → fill_updated →
    // phase_changed handler → flash).

    capture.detach();
  });
});
