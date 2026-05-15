/**
 * room-traversal-smoke.spec.ts
 *
 * Room traversal smoke — Room 1 dummy poof and auto-advance to Room 2
 *
 * Drives the player through Room 01 (Stage 2b PR #169 — 1 PracticeDummy
 * instead of 2 grunts) and verifies Room 02 loads.
 *
 * Verifies:
 *   1. Boot completes cleanly (player boots FISTLESS — the PR #146 boot-equip
 *      bandaid is retired, ticket 86c9qbb3k).
 *   2. Room 01 combat is FISTLESS (`Hitbox.hit | team=player ... damage=1`) —
 *      the dummy poofs in 3 FIST_DAMAGE swings.
 *   3. `[combat-trace] PracticeDummy._die | starting death sequence` (death
 *      pipeline works for the new tutorial entity).
 *   4. The dummy-dropped iron_sword Pickup is collected + auto-equipped
 *      (`[combat-trace] Inventory.equip | source=auto_pickup`) — the
 *      `clearRoom01Dummy` helper handles the walk-onto-pickup step.
 *   5. Room 02 loads after the pickup-equip releases the Room01 onboarding
 *      gate (`Main._on_room01_mob_died` holds the advance while fistless).
 *   6. Room 02 combat is WEAPON-SCALED (`damage>=2`) — the player is now
 *      equipped with the iron_sword picked up in Room 01.
 *
 * **Stage 2b roster (PR #169) + onboarding (ticket 86c9qbb3k):** Room 01's
 * `s1_room01.tres` ships 1 PracticeDummy at world (~368, 144). HP=3, no
 * damage output, no chase. On death it drops a guaranteed iron_sword Pickup;
 * the player walks onto it and `Inventory.on_pickup_collected` auto-equips it
 * (auto-equip-first-weapon-on-pickup — the design-correct onboarding path
 * that retired PR #146's boot-equip bandaid). The Room 01 → Room 02 advance
 * is GATED on that equip.
 *
 * **Why we walk-NE-then-attack-sweep:** the dummy doesn't chase, so the
 * player has to close the 140px diagonal gap manually. The `clearRoom01Dummy`
 * helper encapsulates the kill + pickup-collection pattern.
 *
 * Room 01 → Room 02 transition mechanism: Room 01 uses
 * `Main._install_room01_clear_listener`, NOT a RoomGate. When the dummy dies
 * AND the player is equipped (via the pickup), Main calls `_on_room_cleared()`
 * deferred → `_load_room_at_index(1)`. Auto-advances WITHOUT any door-walk.
 *
 * Combat trace line formats:
 *   "[combat-trace] Hitbox.hit | team=player target=<node_name> damage=6"
 *   "[combat-trace] PracticeDummy._die | starting death sequence"
 *   (target is the Godot node auto-name e.g. "@CharacterBody2D@7", not always class name)
 *
 * References:
 *   - scripts/combat/Hitbox.gd — emits "[combat-trace] Hitbox.hit | ..."
 *   - scripts/mobs/PracticeDummy.gd (PR #169) — emits "[combat-trace] PracticeDummy._die | ..."
 *   - scenes/Main.gd — _install_room01_clear_listener, _load_room_at_index
 *   - resources/level_chunks/s1_room01.tres — Stage 2b dummy spawn position
 *   - tests/playwright/fixtures/room01-traversal.ts — clearRoom01Dummy helper
 */

import { test, expect } from "@playwright/test";
import { ConsoleCapture } from "../fixtures/console-capture";
import {
  clearRoom01Dummy,
  waitForRoom02Load,
} from "../fixtures/room01-traversal";

const BOOT_TIMEOUT_MS = 30_000;
/** How long to wait for the dummy to die (Stage 2b). */
const ROOM01_CLEAR_TIMEOUT_MS = 90_000;
/**
 * Attack interval. Must be > LIGHT_RECOVERY (0.18s) + one Godot physics frame
 * (~17ms). 220ms = 180ms recovery + 40ms margin.
 */
const ATTACK_INTERVAL_MS = 220;

// launchOptions and contextOptions (cache mitigation) are set globally in playwright.config.ts.

test.describe("room traversal smoke — Room 1 dummy poof and auto-advance to Room 2", () => {
  test(
    "room traversal smoke — Room 1 dummy poof and auto-advance to Room 2",
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
      // NOTE: canvas.click() sends a mouse click which Godot registers as
      // attack_light. This initial focus click fires south (initial
      // _facing=DOWN) and lands on nothing — the dummy is far NE. What
      // matters is the canvas has keyboard focus for the helper.
      const canvas = page.locator("canvas").first();
      await canvas.click();
      await page.waitForTimeout(500);

      // Get canvas bounding box for all mouse clicks.
      const canvasBB = await canvas.boundingBox();
      const canvasX = canvasBB ? canvasBB.x : 0;
      const canvasY = canvasBB ? canvasBB.y : 0;
      const canvasW = canvasBB ? canvasBB.width : 1280;
      const canvasH = canvasBB ? canvasBB.height : 720;

      // Click target: center of canvas. Attack direction is controlled by
      // keyboard / facing, not mouse position — this click just fires the
      // attack_light action.
      const clickX = canvasX + canvasW / 2;
      const clickY = canvasY + canvasH / 2;

      console.log(
        `[room-traversal] Canvas bounds: x=${canvasX} y=${canvasY} w=${canvasW} h=${canvasH}, ` +
          `click target: (${clickX.toFixed(0)}, ${clickY.toFixed(0)})`
      );

      // ---- Phase 1: clear Room 01 dummy + collect the iron_sword Pickup ----
      //
      // Ticket 86c9qbb3k: the player drops in FISTLESS. The helper walks NE,
      // attack-sweeps the dummy at world (~368, 144) — 3 FIST_DAMAGE=1 swings
      // poof it (HP=3) — then walks the player onto the dummy-dropped
      // iron_sword Pickup. `Inventory.on_pickup_collected` auto-equips it; the
      // Room01 → Room02 advance is GATED on that equip, so `pickupEquipped`
      // must be true.
      const result = await clearRoom01Dummy(
        page,
        canvas,
        capture,
        clickX,
        clickY,
        { budgetMs: ROOM01_CLEAR_TIMEOUT_MS }
      );
      expect(
        result.dummyKilled,
        `Room 01 PracticeDummy did not die within ${ROOM01_CLEAR_TIMEOUT_MS}ms ` +
          `(${result.attacksFired} attacks, ${result.durationMs}ms helper duration).`
      ).toBe(true);
      expect(
        result.pickupEquipped,
        `Room 01 iron_sword Pickup must be collected + auto-equipped. The ` +
          `Room01 → Room02 advance is GATED on this equip — without it Room02 ` +
          `never loads (ticket 86c9qbb3k).`
      ).toBe(true);

      console.log(
        `[room-traversal] Dummy poofed + iron_sword equipped in ` +
          `${result.durationMs}ms (${result.attacksFired} attacks fired).`
      );

      // ---- Assert combat evidence ----

      // 1. At least one Hitbox.hit with team=player. The dummy mob class
      // identity is "PracticeDummy" but Hitbox.hit emits target=<node_name>
      // which may be the class name or a Godot auto-name. We match team=player.
      const hitLines = capture
        .getLines()
        .filter((l) =>
          /\[combat-trace\] Hitbox\.hit \| team=player/.test(l.text)
        );

      if (hitLines.length === 0) {
        console.log(
          `[room-traversal] No Hitbox.hit|team=player lines. ` +
            `Helper attacks: ${result.attacksFired}. ` +
            "Full console dump:\n" +
            capture.dump()
        );
      }
      expect(hitLines.length).toBeGreaterThan(0);

      // 2. Room 01 combat is FISTLESS. The player has not picked up the
      // iron_sword YET when the kill-sweep hits land — they are FIST_DAMAGE=1
      // hits. (The pickup-equip happens AFTER the dummy dies, in the helper's
      // Phase F.) So every Room 01 Hitbox.hit must be damage=1 — a damage>=2
      // hit here would mean the player was somehow pre-equipped (the exact
      // regression class the boot-equip-bandaid retirement removed).
      const damageValues = hitLines
        .map((l) => {
          const m = l.text.match(/damage=(\d+)/);
          return m ? parseInt(m[1], 10) : null;
        })
        .filter((v): v is number => v !== null);
      expect(damageValues.length).toBeGreaterThan(0);
      const distinctDamages = [...new Set(damageValues)].sort();
      console.log(
        `[room-traversal] Room 01 damage values observed: ` +
          `[${distinctDamages.join(", ")}] (expected all = 1, fistless).`
      );
      const weaponScaledHits = damageValues.filter((d) => d >= 2).length;
      expect(
        weaponScaledHits,
        `Room 01 combat must be FISTLESS (all hits damage=1) — the player ` +
          `picks up + equips the iron_sword AFTER the dummy dies, not before. ` +
          `Got distinct damage values [${distinctDamages.join(", ")}] with ` +
          `${weaponScaledHits} weapon-scaled hit(s). A damage>=2 hit in Room 01 ` +
          `means the player was pre-equipped — the boot-equip bandaid that ` +
          `caused that is retired (ticket 86c9qbb3k).`
      ).toBe(0);

      // 3. The dummy-dropped iron_sword Pickup auto-equipped on collection.
      const autoPickupLine = capture
        .getLines()
        .find((l) =>
          /\[combat-trace\] Inventory\.equip \| .*source=auto_pickup/.test(
            l.text
          )
        );
      expect(
        autoPickupLine,
        "Expected a [combat-trace] Inventory.equip | source=auto_pickup line — " +
          "the player walked onto the dummy-dropped iron_sword Pickup and it " +
          "auto-equipped (ticket 86c9qbb3k onboarding path)."
      ).toBeDefined();
      expect(autoPickupLine!.text).toContain("item=iron_sword");
      expect(autoPickupLine!.text).toContain("slot=weapon");

      // 4. At least one PracticeDummy._die | starting death sequence
      const firstDeathLine = capture
        .getLines()
        .find((l) =>
          /\[combat-trace\] PracticeDummy\._die \| starting death sequence/.test(
            l.text
          )
        );
      expect(
        firstDeathLine,
        "Expected at least one [combat-trace] PracticeDummy._die line " +
          "(Stage 2b PR #169 dummy class)."
      ).toBeDefined();

      // 4. Negative assertion: no Grunt._die in Room 01 (Stage 2b roster
      // changed grunts → dummy). If we see a Grunt._die before the Room02
      // load completes, the chunk_def regressed.
      const gruntDeathsBeforeRoom02 = capture
        .getLines()
        .filter((l) => /\[combat-trace\] Grunt\._die/.test(l.text)).length;
      expect(
        gruntDeathsBeforeRoom02,
        `Stage 2b expectation: no Grunt._die during Room 01 — Room 01 ships ` +
          `1 PracticeDummy now, not 2 grunts. Got ${gruntDeathsBeforeRoom02} ` +
          `Grunt._die traces before Room02 load. Check resources/level_chunks/` +
          `s1_room01.tres mob_spawns.`
      ).toBe(0);

      // ---- Room 02 auto-advance detection ----
      // Room 01 uses _install_room01_clear_listener (no RoomGate delay).
      // Deferred call + scene load: ~600-1000ms.
      await waitForRoom02Load(page, 1500);

      const preRoom2Count = capture.getLines().length;

      // Try attacking in Room 02 (player at DEFAULT_PLAYER_SPAWN again, two
      // grunts spawned at NE). Set facing NE first.
      await page.keyboard.down("w");
      await page.keyboard.down("d");
      await page.waitForTimeout(100);
      await page.keyboard.up("w");
      await page.keyboard.up("d");
      await page.waitForTimeout(400);

      await canvas.click({ position: { x: clickX, y: clickY } });
      await page.waitForTimeout(400);
      await canvas.click({ position: { x: clickX, y: clickY } });
      await page.waitForTimeout(600);

      const room2Lines = capture.getLines().slice(preRoom2Count);
      const room2HitLines = room2Lines.filter((l) =>
        /\[combat-trace\] Hitbox\.hit \| team=player/.test(l.text)
      );
      const room2Hits = room2HitLines.length;
      const room2Attacks = room2Lines.filter((l) =>
        /Player\.try_attack \| FIRED/.test(l.text)
      ).length;

      console.log(
        `[room-traversal] Room 02 check: ${room2Attacks} attacks, ${room2Hits} hits.`
      );

      // If a Room 02 swing DID land, it MUST be weapon-scaled (damage>=2) —
      // the player picked up + equipped the iron_sword in Room 01, so combat
      // is no longer fistless. (Soft: the 2-click Room 02 probe may not land a
      // hit at all if the grunts haven't closed yet — that's not a failure.
      // But a damage=1 hit here WOULD be a regression: it would mean the
      // Room 01 pickup-equip didn't propagate to the Player combat surface.)
      const room2Damages = room2HitLines
        .map((l) => {
          const m = l.text.match(/damage=(\d+)/);
          return m ? parseInt(m[1], 10) : null;
        })
        .filter((v): v is number => v !== null);
      if (room2Damages.length > 0) {
        const room2FistHits = room2Damages.filter((d) => d === 1).length;
        expect(
          room2FistHits,
          `Room 02 combat must be weapon-scaled — the player equipped the ` +
            `iron_sword via the Room 01 dummy-drop pickup. Got Room 02 damage ` +
            `values [${[...new Set(room2Damages)].sort().join(", ")}] with ` +
            `${room2FistHits} fistless (damage=1) hit(s). A fistless hit here ` +
            `means the auto-equip-on-pickup didn't reach the Player combat ` +
            `surface (dual-surface regression).`
        ).toBe(0);
      }

      // ---- Final assertions ----
      const firstError = capture.findFirstError();
      if (firstError) {
        console.log("[room-traversal] CONSOLE DUMP:\n" + capture.dump());
      }
      expect(firstError).toBeNull();

      // Summary
      console.log("[room-traversal] Summary:");
      console.log(`  Dummy poofed: ${result.dummyKilled}`);
      console.log(`  Total Hitbox.hit lines: ${hitLines.length}`);
      console.log(`  Distinct damage values: [${distinctDamages.join(", ")}]`);

      capture.detach();
    }
  );
});
