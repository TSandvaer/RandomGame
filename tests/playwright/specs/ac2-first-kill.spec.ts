/**
 * ac2-first-kill.spec.ts
 *
 * AC2 — Cold launch → first Room02 grunt killed in ≤60 s with weapon-scaled
 * damage
 *
 * **Stage 2b rescope (PR #169 + this PR):** Pre-PR-#169, AC2's "first kill"
 * targeted the Room01 grunts (the same room the player drops in to). PR #169
 * swapped Room01's roster from "2 grunts that chase" to "1 PracticeDummy
 * that doesn't chase" — the dummy isn't a meaningful "first kill" benchmark
 * for combat performance because it has HP=3, deals zero damage, and dies in
 * one hit on the bandaid path (PR #146 still active). AC2's metric stays
 * "first MOB kill within 60 s of boot," but the target is now the **first
 * Room02 grunt** (the first real combat encounter).
 *
 * Verifies the M1 RC soak checklist v2 §5 AC2 (re-scoped for Stage 2b):
 *   1. Cold launch (fresh Chrome profile, no save) completes boot.
 *   2. The starter iron_sword is auto-equipped (boot integration line present).
 *   3. The PracticeDummy poofs in Room01 (`PracticeDummy._die`) — proves the
 *      tutorial path works.
 *   4. The first Room02 grunt dies within 60s of `[Main] M1 play-loop ready`
 *      (re-scoped AC2 deadline).
 *   5. The hits that killed the grunt land at weapon-scaled damage (>=2;
 *      iron_sword=6).
 *   6. The Grunt `_die` + `_force_queue_free` trace shape is correct.
 *   7. No `USER ERROR: Can't change this state while flushing queries` panic.
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
 * **iron_sword bandaid coexistence (PR #146 retirement ticket 86c9qbb3k):**
 * The bandaid auto-equips iron_sword at boot, so Player damage = 6 on every
 * hit (dummy and grunts alike). When the bandaid retires, the player drops
 * in fistless and the Room01 dummy poofs at FIST_DAMAGE=1 (3 hits) — but
 * the dummy still drops an iron_sword pickup that lands in the inventory
 * grid (NOT auto-equipped — pickup → `Inventory.add(item)`, not
 * `Inventory.equip()`). On the post-bandaid path the player will need a Tab
 * → click-grid-cell flow to actually equip the dropped sword before Room02
 * combat. This spec works in the bandaid-active world today; when 86c9qbb3k
 * ships, the spec needs an explicit Tab→click step BETWEEN the dummy poof
 * and the Room02 entry, and the assertion below for damage>=2 in Room02
 * stays valid because by then the player has equipped the dropped sword.
 *
 * Difference from `room-traversal-smoke.spec.ts`:
 *   The traversal spec covers Room01 dummy poof + Room02 entry but does not
 *   gate on AC2's "≤60 s from boot ready" timing. This spec hardens that
 *   bar: first-Room02-kill-deadline = boot-ready + 60s. If the harness ever
 *   needs more than 60s to reach that point, AC2 has regressed even if the
 *   kill eventually lands.
 *
 * References:
 *   - team/uma-ux/sponsor-soak-checklist-v2.md §5 AC2
 *   - team/uma-ux/player-journey.md Beats 4-5 (Stage 2b spec)
 *   - team/tess-qa/playwright-harness-design.md §5 AC2
 *   - team/tess-qa/soak-2026-05-07.md (real captured trace lines)
 *   - resources/items/weapons/iron_sword.tres (damage=6)
 *   - resources/level_chunks/s1_room01.tres (Stage 2b dummy)
 *   - resources/level_chunks/s1_room02.tres (2 grunts NE of spawn)
 *   - scripts/inventory/Inventory.gd:167 — auto-equip print line
 *   - tests/playwright/fixtures/room01-traversal.ts — clearRoom01Dummy
 */

import { test, expect } from "@playwright/test";
import { ConsoleCapture } from "../fixtures/console-capture";
import {
  clearRoom01Dummy,
  waitForRoom02Load,
} from "../fixtures/room01-traversal";

const BOOT_TIMEOUT_MS = 30_000;
/** AC2 hard deadline: ≤60 s from `[Main] M1 play-loop ready` to first Room02 kill. */
const FIRST_KILL_DEADLINE_MS = 60_000;
/** Click cadence — must clear LIGHT_RECOVERY (~0.18s) + physics frame margin. */
const ATTACK_INTERVAL_MS = 220;
/** Grace for Room02 grunts to close from spawn position (~50px @ 60px/s ≈ 850ms). */
const APPROACH_WAIT_MS = 600;

test.describe("AC2 — cold launch first Room02 kill in ≤60 s with weapon-scaled damage", () => {
  test("AC2 — cold launch first Room02 kill in ≤60 s with weapon-scaled damage", async ({
    page,
    context,
  }) => {
    test.setTimeout(180_000);
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
    //
    //    NOTE on the bandaid retirement (ticket 86c9qbb3k): when this line
    //    no longer fires on cold boot (because the bandaid retired), the
    //    test needs a paired Tab→click flow after the dummy-drop to equip
    //    the dropped iron_sword before the Room02 grunt encounter. See
    //    spec header for full bandaid-coexistence rationale.
    const equipLine = await capture.waitForLine(
      /\[Inventory\] starter iron_sword auto-equipped \(weapon slot\)/,
      5_000
    );
    expect(equipLine).toContain("auto-equipped");

    const canvas = page.locator("canvas").first();
    await canvas.click(); // Focus + initial click (south-facing miss; OK)
    await page.waitForTimeout(500);

    const canvasBB = await canvas.boundingBox();
    const clickX = (canvasBB?.x ?? 0) + (canvasBB?.width ?? 1280) / 2;
    const clickY = (canvasBB?.y ?? 0) + (canvasBB?.height ?? 720) / 2;

    // ---- Phase 2: Clear Room 01 dummy (Stage 2b PR #169) ----
    // The helper walks NE and attack-sweeps to kill the PracticeDummy at
    // world (~368, 144). Auto-advance to Room02 fires via
    // _install_room01_clear_listener on dummy death.
    const room01Result = await clearRoom01Dummy(
      page,
      canvas,
      capture,
      clickX,
      clickY,
      { budgetMs: 30_000 }
    );
    expect(
      room01Result.dummyKilled,
      "Room01 PracticeDummy must die for Room02 to load. The dummy poof is " +
        "the path to the AC2 first-kill target (a Room02 grunt)."
    ).toBe(true);
    console.log(
      `[ac2-first-kill] Room01 dummy poofed in ${room01Result.durationMs}ms ` +
        `(${room01Result.attacksFired} attacks).`
    );

    // Settle for Room02 load + player teleport to DEFAULT_PLAYER_SPAWN.
    await waitForRoom02Load(page, 1500);

    // ---- Phase 3: Drive combat to first Room02 grunt kill ----

    // Set facing NE — Room02 grunts spawn at chunk-local (256, 96) and
    // (320, 160), both NE of the player spawn (240, 200). NE-facing
    // click-only attacks land on either (Player.try_attack falls back to
    // _facing when input_dir is zero-length, so the NE facing persists
    // across all subsequent click-only attacks).
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
    // The Room02 first-kill must happen WITHIN 60s of boot (the AC2 metric).
    // Time remaining = 60s - (already elapsed since boot).
    const remainingDeadlineMs =
      FIRST_KILL_DEADLINE_MS - (Date.now() - bootReadyAt);
    expect(
      remainingDeadlineMs,
      `Room01 dummy clear took ${
        Date.now() - bootReadyAt
      }ms — leaving < 0ms of the 60s AC2 budget for the Room02 kill. The ` +
        `dummy-clear helper has regressed (was ~5-12s pre-bandaid-retirement).`
    ).toBeGreaterThan(5_000); // Need at least 5s to land a grunt kill.

    while (Date.now() - combatStart < remainingDeadlineMs) {
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
          `[ac2-first-kill] First Grunt._die at boot+${firstKillElapsed}ms (after ${attacks} attacks in Room02).`
        );
        break;
      }
    }

    // ---- Phase 4: Assertions ----

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
          `of [Main] M1 play-loop ready. ${attacks} attacks fired in Room02. ` +
          `Likely regressions: PR #145/#146 fistless-start (damage=1 not 6); ` +
          `or Hitbox monitoring not activating (PR #143 regression); ` +
          `or Stage 2b Room01 dummy clear taking too long (helper drift).`
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
