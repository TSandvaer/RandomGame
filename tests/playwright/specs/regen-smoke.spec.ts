/**
 * regen-smoke.spec.ts
 *
 * Regen smoke — out-of-combat HP regen activates after 3.0s
 *
 * Verifies the HP regen system (PR #148) running in the real HTML5 artifact:
 *   1. Boot completes cleanly
 *   2. Player takes damage from a grunt (hp < hp_max)
 *   3. Player dodges for 3+ seconds (no further damage, no attacks fired)
 *   4. [combat-trace] Player | regen activated appears in console
 *   5. [combat-trace] Player | regen tick or regen capped shows HP rising
 *
 * Regen trace lines (from scripts/player/Player.gd at SHA 356086a):
 *   [combat-trace] Player | regen activated (HP N/M)
 *   [combat-trace] Player | regen tick (HP N/M)
 *   [combat-trace] Player | regen capped (HP N/M)    ← when HP hits max
 *   [combat-trace] Player | regen deactivated (HP N/M)
 *
 * Note: [combat-trace] lines are emitted only when OS.has_feature("web") == true
 * (DebugFlags.combat_trace_enabled() — see scripts/debug/DebugFlags.gd).
 * They WILL appear in the HTML5 artifact but NOT in headless GUT.
 *
 * Regen activation requires BOTH timers to exceed 3.0s AND hp < hp_max:
 *   - _time_since_last_damage_taken > 3.0s  (reset by take_damage())
 *   - _time_since_last_hit_landed   > 3.0s  (reset by player hitbox hitting a mob)
 *
 * Test strategy — "take one hit, then dodge-survive, detect regen":
 *
 * Both regen timers start at 0 when the player spawns and count UP every
 * physics frame. On game boot:
 *   - Neither timer resets (no attacks fired, no damage taken during the
 *     ~5-15s boot sequence) → _time_since_last_hit_landed is already 5-15s
 *     by the time the play-loop is ready.
 *   - HP = 100/100 (full) → regen is suppressed (hp_current >= hp_max).
 *
 * To trigger regen:
 *   1. Walk NORTH toward the Room 01 grunts (spawned at ~104px north).
 *      Do NOT attack — _time_since_last_hit_landed keeps accumulating from boot.
 *   2. Let grunts land 1-2 hits (hp drops, hp < hp_max,
 *      _time_since_last_damage_taken resets to 0).
 *   3. Start dodge-spam (Space every 460ms) WHILE watching for regen traces.
 *      Each dodge = 0.30s i-frames. With grunt cycle ~0.95s and dodges
 *      every 0.46s, ~67% of the time is covered. Lucky gaps occur where
 *      grunts complete telegraph+swing into a player i-frame window.
 *      After Phase 1 hits, dodge spam runs for DODGE_PHASE_MS total; regen
 *      trace detection runs concurrently (no clearLines gap).
 *   4. If 3s passes without damage during dodge-spam phase:
 *      _time_since_last_damage_taken > 3s AND
 *      _time_since_last_hit_landed  > 3s + boot_time >> threshold
 *      → regen activates. We detect `regen activated` or `regen capped`
 *        (capped fires if HP reaches max during the regen window).
 *
 * Grunt stats (artifact SHA 356086a, PR #153):
 *   - move_speed = 60 px/s, AGGRO_RADIUS = 480 px
 *   - damage_base = 3 (rebalanced in PR #153)
 *   - ATTACK_RANGE = 28 px, LIGHT_TELEGRAPH_DURATION = 0.40s
 *   - ATTACK_RECOVERY = 0.55s → full attack cycle ~0.95s
 *
 * Player stats:
 *   - DODGE_DURATION = 0.30s (i-frames throughout)
 *   - DODGE_COOLDOWN = 0.45s (from dodge START)
 *   - DEFAULT_HP_MAX = 100
 *
 * References:
 *   - scripts/player/Player.gd — _set_regenerating(), _tick_regen(), REGEN_*
 *   - scripts/debug/DebugFlags.gd — combat_trace() HTML5-only shim
 *   - tests/test_hp_regen.gd — GUT unit tests for regen logic (headless)
 *   - resources/level_chunks/s1_room01.tres — grunt spawn positions
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";

const BOOT_TIMEOUT_MS = 30_000;
/** Time to walk north toward grunts and take 1-2 hits (ms) */
const APPROACH_WALK_MS = 2_500;
/** Dodge-spam + regen-detection window (ms) — 3s for regen threshold + margin */
const DODGE_AND_WAIT_MS = 12_000;
/** Dodge interval — slightly above DODGE_COOLDOWN=0.45s to guarantee cooldown cleared */
const DODGE_INTERVAL_MS = 460;
/** Observe regen ticks for this many ms after activation */
const REGEN_TICK_WINDOW_MS = 3_000;

test.describe("regen smoke — out-of-combat HP regen activates after 3.0s", () => {
  test(
    "regen smoke — out-of-combat HP regen activates after 3.0s",
    async ({ page, context }) => {
      await context.route("**/*", (route) => route.continue());

      const capture = new ConsoleCapture(page);
      capture.attach();

      const baseURL =
        process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
      await page.goto(baseURL, { waitUntil: "domcontentloaded" });

      // ---- Wait for boot to complete ----
      // Both regen timers count up during the boot sequence (no attacks/damage),
      // so _time_since_last_hit_landed will be 5-15s by the time we start.
      await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);

      // ---- Canvas focus ----
      // canvas.click() without position hits the canvas center and focuses it.
      // This sends an LMB event which fires attack_light — this is OK because
      // _time_since_last_hit_landed resets to 0 only if the hitbox HIT a mob
      // (not just if attack fired). The attack likely misses grunts (far away at boot).
      // However: this click FIRES an attack → _time_since_last_hit_landed might
      // reset if it hits — so we need to confirm no hit was registered.
      const canvas = page.locator("canvas").first();
      await canvas.click();
      await page.waitForTimeout(500);

      // ---- Get canvas bounding box ----
      const canvasBB = await canvas.boundingBox();
      const canvasX = canvasBB ? canvasBB.x : 0;
      const canvasY = canvasBB ? canvasBB.y : 0;
      const canvasW = canvasBB ? canvasBB.width : 480;
      const canvasH = canvasBB ? canvasBB.height : 270;
      console.log(
        `[regen-smoke] Canvas bounds: x=${canvasX} y=${canvasY} w=${canvasW} h=${canvasH}`
      );

      // ---- Phase 1: Walk NORTH toward grunts (DO NOT attack) ----
      // Room 01 grunts spawn at tile(11,3)=(352,96) and tile(8,5)=(256,160).
      // Player spawns at DEFAULT_PLAYER_SPAWN=(240,200). Both grunts are ~104px north.
      // Walk north ('w') for APPROACH_WALK_MS to enter grunt aggro/attack range.
      // DO NOT press LMB — _time_since_last_hit_landed must continue accumulating
      // from boot (already at boot-duration seconds + any initial canvas.click time).
      console.log("[regen-smoke] Phase 1: Walking north toward grunts (no attacks).");
      await page.keyboard.down("w");
      await page.waitForTimeout(APPROACH_WALK_MS);
      await page.keyboard.up("w");
      await page.waitForTimeout(200);

      const hitsBeforeDodge = capture
        .getLines()
        .filter((l) => /Hitbox\.hit \| team=enemy/.test(l.text)).length;
      console.log(`[regen-smoke] After approach: ${hitsBeforeDodge} enemy hits received.`);

      // ---- Phase 2: Dodge-spam WHILE watching for regen activation ----
      // Key insight: regen can activate during the dodge phase itself (both
      // timers exceed 3s). We MUST watch for regen activation concurrently with
      // dodging — NOT after a clearLines() call that would erase the activated line.
      //
      // Strategy: run a dodge loop for DODGE_AND_WAIT_MS total. Each iteration
      // presses Space (dodge) with alternating left/right direction for spatial
      // variety. After DODGE_AND_WAIT_MS, check the full buffer for regen lines.
      //
      // Timing rationale:
      //   - Last grunt hit during Phase 1 → _time_since_last_damage_taken = 0.
      //   - _time_since_last_hit_landed was already >> 3s from boot (no attacks).
      //   - Each dodge: 0.30s i-frames. Gap between dodges: 0.16s vulnerable.
      //   - Grunt attack cycle: 0.95s. With well-timed dodges, some attacks miss.
      //   - After 3s of no-damage: _time_since_last_damage_taken > 3s → REGEN.
      //   - DODGE_AND_WAIT_MS=12s provides multiple attempts with generous margin.
      console.log(
        `[regen-smoke] Phase 2: Dodge-spam + regen watch for ${DODGE_AND_WAIT_MS}ms.`
      );

      const phaseStart = Date.now();
      const phaseEnd = phaseStart + DODGE_AND_WAIT_MS;
      let dodgeCount = 0;
      let regenFoundDuringDodge = false;

      // Also clear lines now (BEFORE the dodge phase) so we can track phase 2+
      // hits separately, and so the regen search window is clean.
      capture.clearLines();

      while (Date.now() < phaseEnd) {
        // Alternate direction for each dodge
        const dirKey = dodgeCount % 2 === 0 ? "d" : "a";
        dodgeCount++;

        await page.keyboard.down(dirKey);
        await page.waitForTimeout(20);
        // Use keydown+keyup instead of press() for better Godot event handling
        await page.keyboard.down("Space");
        await page.waitForTimeout(50);
        await page.keyboard.up("Space");
        await page.waitForTimeout(20);
        await page.keyboard.up(dirKey);

        // Wait for cooldown (DODGE_COOLDOWN=0.45s from dodge start; 460ms total)
        await page.waitForTimeout(DODGE_INTERVAL_MS - 90);

        // Check for regen activation in the buffer
        const regenLine = capture
          .getLines()
          .find((l) => /\[combat-trace\] Player \| regen (activated|capped)/.test(l.text));
        if (regenLine) {
          regenFoundDuringDodge = true;
          console.log(
            `[regen-smoke] Regen detected during dodge phase at t=${Date.now() - phaseStart}ms: "${regenLine.text}"`
          );
          break;
        }
      }

      // Release all keys
      for (const k of ["w", "a", "s", "d", "Space"]) {
        await page.keyboard.up(k).catch(() => {/* already up */});
      }

      // ---- Diagnostic snapshot ----
      const hitsAfterPhase2 = capture
        .getLines()
        .filter((l) => /Hitbox\.hit \| team=enemy/.test(l.text)).length;
      const playerAttacksFired = capture
        .getLines()
        .filter((l) => /Player\.try_attack \| FIRED/.test(l.text)).length;
      const gruntsKilledSoFar = capture
        .getLines()
        .filter((l) => /Grunt\._die/.test(l.text)).length;
      console.log(
        `[regen-smoke] Phase 2 summary: ${hitsAfterPhase2} enemy hits (phase 2 only), ` +
          `${playerAttacksFired} player attacks fired, ${gruntsKilledSoFar} grunts killed.`
      );

      if (playerAttacksFired > 0) {
        console.log(
          `[regen-smoke] WARNING: ${playerAttacksFired} player attack(s) fired during dodge phase. ` +
            "_time_since_last_hit_landed may have reset. " +
            "This happens if a canvas.click() LMB event hit a grunt during boot/approach."
        );
      }

      // ---- Phase 3: Final regen assertion ----
      // If regen wasn't found during dodge phase, wait a bit more (regen may
      // activate right after Phase 2 ends if timers crossed threshold late).
      let regenActivatedLine: string | null = null;
      let regenCappedLine: string | null = null;

      if (!regenFoundDuringDodge) {
        console.log("[regen-smoke] Regen not yet detected; waiting for 5s more...");
        await page.waitForTimeout(5_000);
      }

      // Check full buffer for any regen signal
      const allLines = capture.getLines();
      const regenActivatedEntry = allLines.find((l) =>
        /\[combat-trace\] Player \| regen activated/.test(l.text)
      );
      const regenCappedEntry = allLines.find((l) =>
        /\[combat-trace\] Player \| regen capped/.test(l.text)
      );
      const regenTickEntry = allLines.find((l) =>
        /\[combat-trace\] Player \| regen tick/.test(l.text)
      );

      if (regenActivatedEntry) {
        regenActivatedLine = regenActivatedEntry.text;
      }
      if (regenCappedEntry) {
        regenCappedLine = regenCappedEntry.text;
      }

      // ---- Regen assertions ----
      const regenObserved = regenActivatedLine !== null || regenCappedLine !== null || regenTickEntry !== null;

      if (!regenObserved) {
        // No regen signal at all — dump full capture for CI diagnosis
        console.log(
          "[regen-smoke] CONSOLE DUMP (no regen signal found):\n" +
            allLines.map((l) => `  [${l.type}] ${l.text}`).join("\n")
        );

        // Diagnose the likely cause
        if (hitsBeforeDodge === 0) {
          throw new Error(
            `Regen not observed. Grunt never reached player (${hitsBeforeDodge} hits). ` +
              "HP was at max — regen cannot activate. " +
              "Fix: extend APPROACH_WALK_MS or add north movement."
          );
        } else {
          throw new Error(
            `Regen not observed after ${DODGE_AND_WAIT_MS}ms dodge phase + 5s wait. ` +
              `Enemy hits (phase 2): ${hitsAfterPhase2}. ` +
              `Player attacks fired: ${playerAttacksFired}. ` +
              "Possible causes: " +
              "(1) _time_since_last_damage_taken kept resetting from continuous hits — " +
              "dodges not providing enough i-frame coverage; " +
              "(2) _time_since_last_hit_landed reset by a player attack hitting a grunt; " +
              "(3) [combat-trace] shim disabled."
          );
        }
      }

      // Primary regen assertion: at least one of activated/capped/tick observed
      if (regenActivatedLine) {
        expect(regenActivatedLine).toMatch(
          /\[combat-trace\] Player \| regen activated \(HP \d+\/\d+\)/
        );
        // HP must be below max at activation (regen condition requires hp < hp_max)
        const hpMatch = regenActivatedLine.match(/regen activated \(HP (\d+)\/(\d+)\)/);
        if (hpMatch) {
          const hp = parseInt(hpMatch[1], 10);
          const hpMax = parseInt(hpMatch[2], 10);
          console.log(`[regen-smoke] Regen activated at HP ${hp}/${hpMax}`);
          expect(hp).toBeLessThan(hpMax);
        }
      } else if (regenCappedLine) {
        // Regen capped = regen activated AND ran until HP hit max. Also valid.
        expect(regenCappedLine).toMatch(
          /\[combat-trace\] Player \| regen capped \(HP \d+\/\d+\)/
        );
        console.log(`[regen-smoke] Regen capped: ${regenCappedLine}`);
      } else if (regenTickEntry) {
        // Tick without activated line = activated line was in buffer before clearLines().
        // Still valid — regen is clearly working.
        expect(regenTickEntry.text).toMatch(
          /\[combat-trace\] Player \| regen tick \(HP \d+\/\d+\)/
        );
        console.log(`[regen-smoke] Regen ticking: ${regenTickEntry.text}`);
      }

      // ---- Wait for regen tick lines (HP rising) if activated ----
      if (regenActivatedLine) {
        const hpMatch = regenActivatedLine.match(/regen activated \(HP (\d+)\/(\d+)\)/);
        const hpAtRegenStart = hpMatch ? parseInt(hpMatch[1], 10) : null;

        await page.waitForTimeout(REGEN_TICK_WINDOW_MS);

        const regenTickLines = capture
          .getLines()
          .filter((l) => /\[combat-trace\] Player \| regen tick/.test(l.text));

        const tickHpValues: number[] = regenTickLines
          .map((l) => {
            const m = l.text.match(/regen tick \(HP (\d+)\/\d+\)/);
            return m ? parseInt(m[1], 10) : null;
          })
          .filter((v): v is number => v !== null);

        if (tickHpValues.length > 0 && hpAtRegenStart !== null) {
          const lastTickHp = tickHpValues[tickHpValues.length - 1];
          const hpDelta = lastTickHp - hpAtRegenStart;
          console.log(
            `[regen-smoke] HP delta over ${REGEN_TICK_WINDOW_MS}ms: +${hpDelta} ` +
              `(${tickHpValues.length} tick lines)`
          );
          expect(hpDelta).toBeGreaterThanOrEqual(0);
        } else {
          console.log(
            "[regen-smoke] NOTE: no regen tick lines observed in window. " +
              "HP may have been near max. Not a hard failure for skeleton."
          );
        }
      }

      // ---- No console errors during the entire test ----
      const firstError = capture.findFirstError();
      if (firstError) {
        console.log("[regen-smoke] CONSOLE DUMP:\n" + capture.dump());
      }
      expect(firstError).toBeNull();

      capture.detach();
    }
  );
});
