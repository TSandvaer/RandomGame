/**
 * room-traversal-smoke.spec.ts
 *
 * Room traversal smoke — Room 1 dummy poof and auto-advance to Room 2
 *
 * Drives the player through Room 01 (Stage 2b PR #169 — 1 PracticeDummy
 * instead of 2 grunts) and verifies Room 02 loads.
 *
 * Verifies:
 *   1. Boot completes cleanly
 *   2. Combat produces `[combat-trace] Hitbox.hit | team=player ... damage=N`
 *      (verifies iron_sword starter weapon + damage formula integration
 *      surface; with PR #146 bandaid active damage=6, post-bandaid damage=1)
 *   3. `[combat-trace] PracticeDummy._die | starting death sequence` (death
 *      pipeline works for the new tutorial entity)
 *   4. Room 02 loads after the dummy poofs (auto-advance via
 *      `_install_room01_clear_listener` — no RoomGate, no door-walk)
 *
 * **Stage 2b roster (PR #169):** Room 01's `s1_room01.tres` now ships:
 *   - 1 PracticeDummy at chunk-local (352, 128) → world (~368, 144)
 *     — far NE of `DEFAULT_PLAYER_SPAWN = (240, 200)`.
 *   - HP=3, no damage output, no chase.
 *   - Drops a guaranteed iron_sword pickup on death (lands in inventory grid
 *     via `Inventory.on_pickup_collected` → `add(item)` — does NOT auto-equip;
 *     the pickup-equip-on-empty-slot is a future feature, not this PR's flow).
 *
 * **Why we walk-NE-then-attack-sweep:** the dummy doesn't chase, so the
 * player has to close the 140px diagonal gap manually. Per the AC4-spec
 * Room01 phase (PR #170/#172) and the empirical screenshot diagnosis behind
 * `tests/playwright/fixtures/room01-traversal.ts`, separate-axis walks (pure
 * N then pure E) are more predictable than diagonal walks. The
 * `clearRoom01Dummy` helper encapsulates the pattern.
 *
 * **iron_sword bandaid coexistence:** PR #146 auto-equips iron_sword at
 * boot (damage=6 vs dummy HP=3 → 1 hit kill). Retirement ticket 86c9qbb3k
 * is filed but not yet shipped. The current spec works in BOTH world states:
 *   - bandaid active (today): dummy dies in 1 swing.
 *   - bandaid retired: player drops in fistless (damage=1), dummy dies in
 *     3 swings. The helper's per-direction `attacksPerDir = 3` covers both.
 *
 * Room 01 → Room 02 transition mechanism (unchanged from pre-Stage-2b):
 * Room 01 uses `Main._install_room01_clear_listener`, NOT a RoomGate. When
 * the last spawned mob (now the dummy) dies, Main calls `_on_room_cleared()`
 * deferred, which calls `_load_room_at_index(1)`. Auto-advances WITHOUT any
 * door-walk. The Hitbox damage value is asserted INSIDE Room 01 (the dummy
 * hits prove iron_sword is equipped).
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

      // ---- Phase 1: clear Room 01 dummy via the helper ----
      //
      // Stage 2b (PR #169): the helper walks the player NE then attack-sweeps
      // the dummy at world (~368, 144). On the iron_sword bandaid path
      // (PR #146 active) damage=6 → 1 swing kills. On the post-bandaid path
      // damage=1 → 3 swings kill (helper's `attacksPerDir = 3` covers both).
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
          `(${result.attacksFired} attacks, ${result.durationMs}ms helper duration). ` +
          `Room02 cannot load until the dummy dies — _install_room01_clear_listener ` +
          `gates the auto-advance.`
      ).toBe(true);

      console.log(
        `[room-traversal] Dummy poofed in ${result.durationMs}ms ` +
          `(${result.attacksFired} attacks fired).`
      );

      // ---- Assert combat evidence ----

      // 1. At least one Hitbox.hit with team=player. The dummy mob class
      // identity is "PracticeDummy" but Hitbox.hit emits target=<node_name>
      // which may be the class name or a Godot auto-name (e.g.
      // "@CharacterBody2D@7"). We match team=player only.
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

      // 2. Verify damage value. Two acceptable values during the bandaid
      // co-existence window:
      //   - damage=6: bandaid active (PR #146 auto-equips iron_sword at boot).
      //     This is the current state on origin/main.
      //   - damage=1: bandaid retired (ticket 86c9qbb3k). Player drops in
      //     fistless; FIST_DAMAGE = 1. Update the assertion to require
      //     damage=1 (with a `pre-equip swing` comment) when this lands.
      //
      // Either way, damage=1 with the bandaid active would be the load-bearing
      // regression we still want to catch (iron_sword not equipped). The check
      // below is `damage >= 1` which always passes — the SPECIFIC iron_sword
      // assertion is on the value=6 branch below, with the bandaid-retirement
      // value=1 branch documented for the future.
      const damageValues = hitLines
        .map((l) => {
          const m = l.text.match(/damage=(\d+)/);
          return m ? parseInt(m[1], 10) : null;
        })
        .filter((v): v is number => v !== null);
      expect(damageValues.length).toBeGreaterThan(0);
      const distinctDamages = [...new Set(damageValues)].sort();
      console.log(
        `[room-traversal] Damage values observed: [${distinctDamages.join(", ")}]. ` +
          `Bandaid-active expected: [6]. Bandaid-retired expected: [1].`
      );
      // Bandaid-active assertion: at least one damage>=2 hit (iron_sword
      // equipped). When the bandaid retires, change this to `damageValues
      // .every(d => d === 1)` to assert fistless start.
      const weaponScaledHits = damageValues.filter((d) => d >= 2).length;
      expect(
        weaponScaledHits,
        `Expected at least one weapon-scaled hit (damage>=2) with the iron_sword ` +
          `bandaid active (PR #146). Got distinct damage values: ` +
          `[${distinctDamages.join(", ")}]. If all hits are damage=1, either ` +
          `(a) the bandaid retired (ticket 86c9qbb3k) and this assertion needs ` +
          `flipping, OR (b) the auto-equip regressed (PR #145/#146 integration ` +
          `regression class).`
      ).toBeGreaterThan(0);

      // 3. At least one PracticeDummy._die | starting death sequence
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
      const room2Hits = room2Lines.filter((l) =>
        /\[combat-trace\] Hitbox\.hit/.test(l.text)
      ).length;
      const room2Attacks = room2Lines.filter((l) =>
        /Player\.try_attack \| FIRED/.test(l.text)
      ).length;

      console.log(
        `[room-traversal] Room 02 check: ${room2Attacks} attacks, ${room2Hits} hits.`
      );

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
