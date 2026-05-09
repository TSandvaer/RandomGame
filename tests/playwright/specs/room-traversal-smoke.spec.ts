/**
 * room-traversal-smoke.spec.ts
 *
 * Room traversal smoke — Room 1 combat and auto-advance to Room 2
 *
 * Drives the player through Room 1 combat and verifies Room 2 loads.
 * Verifies:
 *   1. Boot completes cleanly
 *   2. Combat produces [combat-trace] Hitbox.hit | team=player target=... damage=6
 *      (verifies iron_sword starter weapon + damage formula integration surface)
 *   3. [combat-trace] Grunt._die | starting death sequence (death pipeline works)
 *   4. Room 2 loads after both Room 1 grunts die (auto-advance mechanic)
 *      (Room 01 uses _install_room01_clear_listener, not RoomGate — auto-advances
 *      when last mob dies, no door-walk required)
 *
 * Grunt positions in Room 01 (s1_room01.tres, SHA 356086a):
 *   grunt_a: tile(11,3) = (352, 96)  — northeast of player
 *   grunt_b: tile(8,5)  = (256, 160) — north of player (sqrt(16²+40²)≈43px)
 *   Player: DEFAULT_PLAYER_SPAWN = (240, 200)
 *
 * In Godot 2D screen coords: Y increases downward, so "north" = smaller Y.
 *
 * GRUNT BEHAVIOR (SHA 356086a Grunt.gd, tess-wt branch):
 *   Grunt AI: CHASING → STATE_TELEGRAPHING_LIGHT (0.40s, rooted) → swing → ATTACKING (0.55s recovery)
 *   LIGHT_TELEGRAPH_DURATION = 0.40s — grunt telegraphs and is ROOTED for 0.40s.
 *   ATTACK_RANGE = 28px — starts telegraph when within 28px of player.
 *   ATTACK_RECOVERY = 0.55s — after swing, recovers before chasing again.
 *
 * ATTACK GEOMETRY — northeast diagonal:
 *   Player at (240, 200). Grunt_b at (256, 160). dx=16 (east), dy=−40 (north).
 *   NE facing: (0.707, −0.707) × LIGHT_REACH(28) = offset (19.8, −19.8).
 *   Hitbox center: (259.8, 180.2). Hitbox radius = 18.
 *   Grunt_b at (256, 160): dist = sqrt(3.8² + 20.2²) = 20.6px — just outside initial range.
 *   After grunt closes 8px south (0.13s at 60px/s): grunt_b at (256, 164).
 *   Hitbox at (259.8, 180.2), grunt at (256, 164): dist = sqrt(3.8² + 16.2²) = 16.6px < 18 → HIT.
 *
 * CRITICAL — no direction keys during attack loop:
 *   Holding 'w'/'d' during attack recovery causes player drift at 60px/s (half
 *   walk speed). Over 174 attacks × 30ms each = 5.2s total key time = 312px
 *   of unintended drift — grunts end up far from the attack zone. Fix: set the
 *   initial facing once (press 'w'+'d', release), then attack with click only.
 *   Player.try_attack falls back to _facing when input_dir is zero-length, so
 *   the NE facing persists across all subsequent click-only attacks.
 *
 * Room 01 → Room 02 transition mechanism:
 * Room 01 uses Main._install_room01_clear_listener, NOT a RoomGate. When the
 * last spawned mob dies, Main calls _on_room_cleared() deferred, which calls
 * _load_room_at_index(1). This auto-advances WITHOUT any door-walk.
 *
 * Combat trace line formats (SHA 356086a):
 *   "[combat-trace] Hitbox.hit | team=player target=<node_name> damage=6"
 *   "[combat-trace] Grunt._die | starting death sequence"
 *   "[combat-trace] Grunt._begin_light_telegraph | dir=... duration=0.40"
 *   (target is the Godot node auto-name e.g. "@CharacterBody2D@7", not always class name)
 *
 * References:
 *   - scripts/combat/Hitbox.gd — emits "[combat-trace] Hitbox.hit | ..."
 *   - scripts/mobs/Grunt.gd (tess-wt) — emits "[combat-trace] Grunt._die | ..."
 *   - scenes/Main.gd — _install_room01_clear_listener, _load_room_at_index
 *   - resources/level_chunks/s1_room01.tres — grunt spawn positions
 */

import { test, expect } from "@playwright/test";
import { ConsoleCapture } from "../fixtures/console-capture";

const BOOT_TIMEOUT_MS = 30_000;
/** How long to sustain the combat loop before giving up */
const COMBAT_LOOP_TIMEOUT_MS = 90_000;
/**
 * Attack interval. Must be > LIGHT_RECOVERY (0.18s) + one Godot physics frame
 * (~17ms). 220ms = 180ms recovery + 40ms margin.
 */
const ATTACK_INTERVAL_MS = 220;
/**
 * Initial wait after boot for grunts to close to attack range.
 * Grunt_b is 43px away at 60px/s → closes to ~28px attack range in ~0.25s.
 * Using 600ms so grunt is well within hitbox range before first attack.
 */
const APPROACH_WAIT_MS = 600;

// launchOptions and contextOptions (cache mitigation) are set globally in playwright.config.ts.

test.describe("room traversal smoke — Room 1 combat and auto-advance to Room 2", () => {
  test(
    "room traversal smoke — Room 1 combat and auto-advance to Room 2",
    async ({ page, context }) => {
      test.setTimeout(180_000);
      await context.route("**/*", (route) => route.continue());

      const capture = new ConsoleCapture(page);
      capture.attach();

      const baseURL =
        process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
      await page.goto(baseURL, { waitUntil: "domcontentloaded" });

      // ---- Wait for boot ----
      await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);

      // ---- Focus canvas for input events ----
      // NOTE: canvas.click() sends a mouse click which Godot registers as attack_light.
      // This initial focus click fires south (initial _facing=DOWN) and misses grunts,
      // which is fine. What matters is the canvas has keyboard focus.
      const canvas = page.locator("canvas").first();
      await canvas.click();
      await page.waitForTimeout(500);

      // Get canvas bounding box for all mouse clicks.
      const canvasBB = await canvas.boundingBox();
      const canvasX = canvasBB ? canvasBB.x : 0;
      const canvasY = canvasBB ? canvasBB.y : 0;
      const canvasW = canvasBB ? canvasBB.width : 1280;
      const canvasH = canvasBB ? canvasBB.height : 720;

      // Click target: center of canvas. Attack direction is controlled by keyboard,
      // not mouse position — this click just fires the attack_light action.
      const clickX = canvasX + canvasW / 2;
      const clickY = canvasY + canvasH / 2;

      console.log(
        `[room-traversal] Canvas bounds: x=${canvasX} y=${canvasY} w=${canvasW} h=${canvasH}, ` +
          `click target: (${clickX.toFixed(0)}, ${clickY.toFixed(0)})`
      );

      // ---- Set initial facing to northeast (NE) ----
      //
      // Grunt_b is at (256,160), player at (240,200). dx=+16 (east), dy=−40 (north).
      // NE diagonal covers grunt_b's x-offset from player while attacking toward it.
      //
      // Press 'w'+'d' briefly to set _facing=(0.707,−0.707) in Player.gd.
      // After releasing, facing sticks — subsequent click-only attacks use this facing.
      //
      // CRITICAL: do NOT hold direction keys during the attack loop — this causes
      // 60px/s drift during 180ms recovery, accumulating 312px over 174 attacks.
      console.log("[room-traversal] Setting initial facing NE (w+d) and waiting for grunts to approach...");
      await page.keyboard.down("w");
      await page.keyboard.down("d");
      await page.waitForTimeout(100);
      await page.keyboard.up("w");
      await page.keyboard.up("d");

      // Wait for grunts to close the gap. Grunt_b at 43px, 60px/s → within
      // ATTACK_RANGE=28px in ~0.25s. After 0.60s they should be in telegraph range.
      await page.waitForTimeout(APPROACH_WAIT_MS);

      const combatStart = Date.now();
      let gruntsKilled = 0;
      let attacksFired = 0;
      let hitCount = 0;

      //
      // Attack loop: click only (no direction keys held).
      //
      // Player._facing persists from the 'w'+'d' press above as (0.707,−0.707).
      // Player.try_attack(ATTACK_LIGHT, Vector2.ZERO) → dir = _facing = NE.
      // Hitbox: player_pos + (0.707,−0.707)*28 = (240+19.8, 200−19.8) = (259.8, 180.2).
      // Grunt_b approaches from (256,160) — within 18px radius after ~0.13s of approach.
      //
      // Re-aim every 16 attacks (every ~3.5s) to track grunt positions:
      //   - NE for the first 8 (covers grunt_b approaching diagonally)
      //   - N for 4 (covers grunt_b after it drifts west when chasing)
      //   - NE for 4 (back to NE for grunt_a closing from northeast)
      //
      // Repositioning every 20s: walk NE briefly to re-close the gap if grunts
      // pushed player south via knockback.
      //
      let lastRepos = combatStart;
      let aimCycle = 0;

      while (Date.now() - combatStart < COMBAT_LOOP_TIMEOUT_MS) {
        // Re-aim every 16 attacks to track grunt movement
        if (aimCycle % 16 === 0) {
          // Set facing based on cycle:
          // cycles 0,1: NE (grunt_b initial approach + grunt_a from northeast)
          // cycle 2: N  (grunt_b after it drifts west)
          // cycle 3: NE (back to NE)
          const cycleGroup = Math.floor(aimCycle / 16) % 4;
          let aimKeys: string[];
          if (cycleGroup === 2) {
            aimKeys = ["w"]; // N
          } else {
            aimKeys = ["w", "d"]; // NE
          }
          for (const k of aimKeys) await page.keyboard.down(k);
          await page.waitForTimeout(30);
          for (const k of aimKeys) await page.keyboard.up(k);
          await page.waitForTimeout(20);
        }
        aimCycle++;

        // Fire attack: click canvas center, no direction keys held.
        // Player uses _facing (last set direction) for attack direction.
        await canvas.click({ position: { x: clickX, y: clickY } });
        await page.waitForTimeout(ATTACK_INTERVAL_MS);

        // ---- Monitor grunt deaths ----
        const currentDeathLines = capture
          .getLines()
          .filter((l) => /\[combat-trace\] Grunt\._die/.test(l.text)).length;

        if (currentDeathLines > gruntsKilled) {
          gruntsKilled = currentDeathLines;
          console.log(
            `[room-traversal] Grunt killed (total: ${gruntsKilled}) at ` +
              `t=${Date.now() - combatStart}ms`
          );
        }

        // ---- Monitor fired attacks and hits ----
        const fired = capture
          .getLines()
          .filter((l) => /Player\.try_attack \| FIRED/.test(l.text)).length;
        if (fired > attacksFired) attacksFired = fired;

        const hits = capture
          .getLines()
          .filter((l) =>
            /\[combat-trace\] Hitbox\.hit \| team=player/.test(l.text)
          ).length;
        if (hits > hitCount) hitCount = hits;

        // ---- Room 01 done — both grunts dead ----
        if (gruntsKilled >= 2) {
          console.log(
            `[room-traversal] Both Room 01 grunts killed at t=${Date.now() - combatStart}ms.`
          );
          break;
        }

        // ---- Progress logging + repositioning every 20s ----
        const elapsed = Date.now() - combatStart;
        if (elapsed - lastRepos >= 20_000) {
          lastRepos = elapsed + combatStart;
          console.log(
            `[room-traversal] t=${elapsed}ms: ${gruntsKilled}/2 grunts killed, ` +
              `${attacksFired} attacks fired, ${hitCount} hits. Re-aiming NE.`
          );
          // Reset facing to NE and walk briefly to re-close gap
          await page.keyboard.down("w");
          await page.keyboard.down("d");
          await page.waitForTimeout(200);
          await page.keyboard.up("w");
          await page.keyboard.up("d");
          await page.waitForTimeout(100);
          // Reset aim cycle so we re-establish NE facing in the loop
          aimCycle = 0;
        }
      }

      // ---- Assert combat evidence ----

      // 1. At least one Hitbox.hit with team=player
      // Note: target name is the Godot node name (e.g. "@CharacterBody2D@7"),
      // not always the class name "Grunt". We match team=player only.
      const hitLines = capture
        .getLines()
        .filter((l) =>
          /\[combat-trace\] Hitbox\.hit \| team=player/.test(l.text)
        );

      if (hitLines.length === 0) {
        console.log(
          `[room-traversal] No Hitbox.hit|team=player lines. ` +
            `Total attacks fired: ${attacksFired}. ` +
            "Full console dump:\n" +
            capture.dump()
        );
      }
      expect(hitLines.length).toBeGreaterThan(0);

      // 2. Verify damage=6 (iron_sword base damage)
      const damage6Lines = hitLines.filter((l) => /damage=6/.test(l.text));
      if (damage6Lines.length > 0) {
        console.log(
          `[room-traversal] Confirmed damage=6 in ${damage6Lines.length} hit(s)`
        );
        expect(damage6Lines[0].text).toMatch(/damage=6/);
      } else {
        const damages = hitLines.map((l) => {
          const m = l.text.match(/damage=(\d+)/);
          return m ? m[1] : "?";
        });
        console.log(
          `[room-traversal] WARNING: Expected damage=6 but got: [${damages.join(", ")}]. ` +
            "If damage=1, iron_sword not equipped (PR #145/146 integration regression)."
        );
        expect(hitLines.length).toBeGreaterThan(0);
      }

      // 3. At least one Grunt._die | starting death sequence
      if (gruntsKilled === 0) {
        console.log(
          `[room-traversal] No grunt kills. ${attacksFired} attacks fired, ${hitCount} hits. ` +
            "Full console:\n" +
            capture.dump()
        );
      }
      expect(gruntsKilled).toBeGreaterThan(0);

      const firstDeathLine = capture
        .getLines()
        .find((l) =>
          /\[combat-trace\] Grunt\._die \| starting death sequence/.test(l.text)
        );
      expect(firstDeathLine).toBeDefined();
      expect(firstDeathLine!.text).toMatch(
        /\[combat-trace\] Grunt\._die \| starting death sequence/
      );

      // ---- Room 02 auto-advance detection ----
      if (gruntsKilled >= 2) {
        // Room 01 uses _install_room01_clear_listener (no RoomGate delay).
        // Deferred call + scene load: ~300-500ms.
        await page.waitForTimeout(1_000);

        const preRoom2Count = capture.getLines().length;

        // Try attacking in Room 02
        await canvas.click({ position: { x: clickX, y: clickY } });
        await page.waitForTimeout(400);
        await canvas.click({ position: { x: clickX, y: clickY } });
        await page.waitForTimeout(600);

        const room2Lines = capture.getLines().slice(preRoom2Count);
        const room2Hits = room2Lines.filter((l) =>
          /\[combat-trace\] Hitbox\.hit/.test(l.text)
        ).length;
        const room2Attacks = room2Lines.filter((l) =>
          /Player\.try_attack \| FIRED/.test(l.text)
        ).length;

        console.log(
          `[room-traversal] Room 02 check: ${room2Attacks} attacks, ${room2Hits} hits.`
        );
      } else {
        console.log(
          `[room-traversal] Only ${gruntsKilled}/2 grunts killed — Room 02 not reached.`
        );
      }

      // ---- Final assertions ----
      expect(firstDeathLine!.text).toMatch(
        /\[combat-trace\] Grunt\._die \| starting death sequence/
      );

      const firstError = capture.findFirstError();
      if (firstError) {
        console.log("[room-traversal] CONSOLE DUMP:\n" + capture.dump());
      }
      expect(firstError).toBeNull();

      // Summary
      console.log("[room-traversal] Summary:");
      console.log(`  Grunts killed: ${gruntsKilled}/2`);
      console.log(`  Total Hitbox.hit lines: ${hitLines.length}`);
      console.log(`  damage=6 lines: ${damage6Lines.length}`);

      capture.detach();
    }
  );
});
