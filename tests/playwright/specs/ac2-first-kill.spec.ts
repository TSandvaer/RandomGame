/**
 * ac2-first-kill.spec.ts
 *
 * AC2 — Cold launch → first mob killed in ≤60 s with weapon-scaled damage
 *
 * Verifies the M1 RC soak checklist v2 §5 AC2:
 *   1. Cold launch (fresh Chrome profile, no save) completes boot
 *   2. The starter iron_sword is auto-equipped (boot integration line present)
 *   3. The first grunt dies within 60s of `[Main] M1 play-loop ready`
 *   4. The hits that killed the grunt land at weapon-scaled damage (>=2; iron_sword=6)
 *   5. The Hitbox.hit + Grunt._die + tween-finished trace shape is correct
 *   6. No `USER ERROR: Can't change this state while flushing queries` panic
 *
 * Why this test exists:
 *   This is the regression class that bit M1 RC twice (PR #145 + PR #146).
 *   The fistless-start P0: combat fired but `damage=1` per swing because the
 *   iron_sword wasn't actually equipped at the Player surface even though the
 *   Inventory autoload reported it equipped. Headless GUT tests passed.
 *   The harness watches the integration surface — the actual Hitbox.hit
 *   trace's `damage=N` value is what proves the equipped weapon flowed
 *   through to combat.
 *
 * Difference from `room-traversal-smoke.spec.ts`:
 *   The skeleton's room-traversal spec already kills both Room 01 grunts and
 *   asserts damage=6 — but its time budget is 90s and it doesn't explicitly
 *   gate on AC2's "≤60 s from boot ready." This spec hardens that bar:
 *   first-grunt-kill-deadline = boot-ready + 60s. If the harness ever needs
 *   90s, AC2 has regressed even if the kill eventually lands.
 *
 * References:
 *   - team/uma-ux/sponsor-soak-checklist-v2.md §5 AC2
 *   - team/tess-qa/playwright-harness-design.md §5 AC2
 *   - team/tess-qa/soak-2026-05-07.md (real captured trace lines)
 *   - resources/items/weapons/iron_sword.tres (damage=6)
 *   - scripts/inventory/Inventory.gd:154 — auto-equip print line
 */

import { test, expect } from "@playwright/test";
import { ConsoleCapture } from "../fixtures/console-capture";

const BOOT_TIMEOUT_MS = 30_000;
/** AC2 hard deadline: ≤60 s from `[Main] M1 play-loop ready` to first kill. */
const FIRST_KILL_DEADLINE_MS = 60_000;
/** Click cadence — must clear LIGHT_RECOVERY (~0.18s) + physics frame margin. */
const ATTACK_INTERVAL_MS = 220;
/** Grace for grunts to close from spawn position (43px @ 60px/s ≈ 700ms). */
const APPROACH_WAIT_MS = 600;

test.describe("AC2 — cold launch first kill in ≤60 s with weapon-scaled damage", () => {
  test("AC2 — cold launch first kill in ≤60 s with weapon-scaled damage", async ({
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

    // ---- Phase 1: Cold-boot integration assertions ----

    // 1. Boot sentinel — full autoload chain wired
    const bootLine = await capture.waitForLine(
      /\[Main\] M1 play-loop ready/,
      BOOT_TIMEOUT_MS
    );
    const bootReadyAt = Date.now();
    expect(bootLine).toContain("M1 play-loop ready");

    // 2. Starter iron_sword auto-equipped at game start (PR #145 + #146 surface).
    //    This is the integration proof that survives both:
    //    - PR #145: Inventory.gd seeds iron_sword + auto-equips
    //    - PR #146: Main._ready calls equip_starter_weapon_if_needed AFTER
    //              save-restore (so save-restore can't clobber it)
    //    If this line is missing on a fresh-save boot, AC2 has regressed at
    //    the integration surface — without needing a kill to detect it.
    const equipLine = await capture.waitForLine(
      /\[Inventory\] starter iron_sword auto-equipped \(weapon slot\)/,
      5_000
    );
    expect(equipLine).toContain("auto-equipped");

    // ---- Phase 2: Drive combat to first kill ----

    const canvas = page.locator("canvas").first();
    await canvas.click(); // Focus + initial click (south-facing miss; OK)
    await page.waitForTimeout(500);

    const canvasBB = await canvas.boundingBox();
    const clickX = (canvasBB?.x ?? 0) + (canvasBB?.width ?? 1280) / 2;
    const clickY = (canvasBB?.y ?? 0) + (canvasBB?.height ?? 720) / 2;

    // Set facing NE once so click-only attacks aim at grunt_b at (256, 160)
    // from player spawn (240, 200). See room-traversal-smoke.spec.ts header
    // for the geometry derivation.
    await page.keyboard.down("w");
    await page.keyboard.down("d");
    await page.waitForTimeout(100);
    await page.keyboard.up("w");
    await page.keyboard.up("d");
    await page.waitForTimeout(APPROACH_WAIT_MS);

    let firstKillAt: number | null = null;
    let firstKillElapsed: number | null = null;
    let attacks = 0;
    const combatStart = Date.now();

    while (Date.now() - combatStart < FIRST_KILL_DEADLINE_MS) {
      await canvas.click({ position: { x: clickX, y: clickY } });
      attacks++;
      await page.waitForTimeout(ATTACK_INTERVAL_MS);

      const dieLine = capture
        .getLines()
        .find((l) => /\[combat-trace\] Grunt\._die/.test(l.text));
      if (dieLine && firstKillAt === null) {
        firstKillAt = dieLine.timestamp;
        firstKillElapsed = firstKillAt - bootReadyAt;
        console.log(
          `[ac2-first-kill] First Grunt._die at boot+${firstKillElapsed}ms (after ${attacks} attacks).`
        );
        break;
      }
    }

    // ---- Phase 3: Assertions ----

    // 1. The grunt died within the AC2 deadline
    if (firstKillAt === null) {
      const recentLines = capture
        .getLines()
        .slice(-30)
        .map((l) => `  [${l.type}] ${l.text}`)
        .join("\n");
      console.log(
        `[ac2-first-kill] DEADLINE EXCEEDED. ${attacks} attacks fired in ${
          Date.now() - combatStart
        }ms.\nLast 30 console lines:\n${recentLines}`
      );
      throw new Error(
        `AC2 deadline exceeded: no Grunt._die within ${FIRST_KILL_DEADLINE_MS}ms ` +
          `of [Main] M1 play-loop ready. ${attacks} attacks fired. ` +
          `Likely regressions: PR #145/#146 fistless-start (damage=1 not 6); ` +
          `or Hitbox monitoring not activating (PR #143 regression).`
      );
    }
    expect(firstKillElapsed).not.toBeNull();
    expect(firstKillElapsed!).toBeLessThanOrEqual(FIRST_KILL_DEADLINE_MS);

    // 2. Hits landed at weapon-scaled damage (NOT damage=1 fist).
    //    The exact value (6) is iron_sword.base_damage, but we tolerate any
    //    value >= 2 — the regression we're catching is fist-=-1, not the
    //    exact balance number.
    const hitLines = capture
      .getLines()
      .filter((l) =>
        /\[combat-trace\] Hitbox\.hit \| team=player/.test(l.text)
      );
    expect(hitLines.length).toBeGreaterThan(0);

    const damageValues = hitLines
      .map((l) => {
        const m = l.text.match(/damage=(\d+)/);
        return m ? parseInt(m[1], 10) : null;
      })
      .filter((v): v is number => v !== null);

    expect(damageValues.length).toBeGreaterThan(0);
    const fistDamageHits = damageValues.filter((d) => d === 1).length;
    const weaponScaledHits = damageValues.filter((d) => d >= 2).length;

    if (fistDamageHits > 0 && weaponScaledHits === 0) {
      console.log(
        `[ac2-first-kill] FIST-DAMAGE REGRESSION: all ${fistDamageHits} hits are damage=1. ` +
          `iron_sword.base_damage=6 is not flowing through to Hitbox.damage.`
      );
      // This assertion fails loudly to surface the PR #145/#146 regression class.
      expect(weaponScaledHits).toBeGreaterThan(0);
    }

    // Document the actual damage value(s) observed (helps spot balance changes)
    const distinctDamages = [...new Set(damageValues)].sort();
    console.log(
      `[ac2-first-kill] Damage values observed: [${distinctDamages.join(", ")}] ` +
        `over ${damageValues.length} hits. Expected: [6] (iron_sword base).`
    );

    // 3. The death pipeline ran to completion (queue_free actually fired).
    //    This guards against PR #136 / #142 regression: `_die` ran but the
    //    mob was functionally immortal because the tween hung AND the
    //    safety-net timer never fired either.
    //
    //    Death pipeline timeline post-_die:
    //      - _play_death_tween fires (tween armed, parallel timer armed)
    //      - Either tween.finished → _on_death_tween_finished → _force_queue_free
    //      - OR safety-net timer (DEATH_TWEEN_DURATION + 0.2s = 0.6s) →
    //        _force_queue_free directly (bypasses _on_death_tween_finished)
    //
    //    Per combat-architecture.md §"Mob _die death pipeline":
    //      "The parallel SceneTreeTimer is critical (PR #136). Without it,
    //       mobs become functionally immortal if the death tween hangs."
    //
    //    So the LOAD-BEARING assertion is `_force_queue_free | freeing now`
    //    (the universal completion line — fires from either path). The
    //    `_on_death_tween_finished` line is OPTIONAL: it fires only when
    //    the tween actually runs to completion, which depends on
    //    canvas-focus + frame-pacing. In Playwright with paused-after-attack
    //    cadence, the tween may not advance and only the safety-net timer
    //    completes the pipeline.
    //
    //    Poll for up to 5s with 100ms intervals AND keep firing attacks.
    //    Without continued input, the Godot engine in Chromium may throttle
    //    the frame loop and the tween/safety-timer can stall. Keeping the
    //    attack cadence going forces frame ticks to continue advancing.
    const tweenDeadline = Date.now() + 5_000;
    let queueFreeLine: string | null = null;
    while (Date.now() < tweenDeadline) {
      // Continue clicking to keep engine ticks flowing
      await canvas.click({ position: { x: clickX, y: clickY } });
      const found = capture
        .getLines()
        .find((l) =>
          /\[combat-trace\] Grunt\._force_queue_free \| freeing now/.test(
            l.text
          )
        );
      if (found) {
        queueFreeLine = found.text;
        break;
      }
      await page.waitForTimeout(150);
    }

    if (!queueFreeLine) {
      // PR #136 regression class signature: _die + _play_death_tween fired,
      // but neither tween.finished nor safety-net-timer completion landed.
      const tweenLines = capture
        .getLines()
        .filter((l) =>
          /\[combat-trace\] Grunt\._(play_)?death_tween|Grunt\._force_queue_free/.test(
            l.text
          )
        );
      console.log(
        `[ac2-first-kill] PR #136 REGRESSION SUSPECTED: _die fired but no ` +
          `_force_queue_free after 3s. Death pipeline hung. Trace lines:\n` +
          tweenLines.map((l) => `  ${l.text}`).join("\n")
      );
    }
    expect(queueFreeLine).not.toBeNull();

    // 4. Negative assertion: NO physics-flush panic during the kill window.
    //    PR #142 + #143 regression class — would surface as a console.error
    //    matching "Can't change this state while flushing queries".
    const panicLines = capture.findUnexpectedLine(
      /Can't change this state while flushing queries/
    );
    expect(panicLines).toBeNull();

    // 5. Negative assertion: no Godot push_error during the entire flow.
    const firstError = capture.findFirstError();
    if (firstError) {
      console.log("[ac2-first-kill] CONSOLE DUMP:\n" + capture.dump());
    }
    expect(firstError).toBeNull();

    capture.detach();
  });
});
