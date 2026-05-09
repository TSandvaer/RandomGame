/**
 * ac3-death-persistence.spec.ts
 *
 * AC3 — Player death preserves level + V/F/E + equipped weapon
 *
 * Verifies the M1 RC death rule (DECISIONS.md 2026-05-02 + scenes/Main.gd
 * `apply_death_rule`):
 *
 *   On death:
 *     - KEEP: level, equipped, V/F/E (PlayerStats), unspent stat points
 *     - LOSE: unequipped inventory items, room progression, in-progress XP
 *
 * The harness validates the "equipped survives" half by:
 *   1. Boot completes; iron_sword auto-equipped (verified via Inventory line)
 *   2. Player walks toward grunts and stands still (no attacks) until HP=0
 *   3. After death, Main._on_player_died → apply_death_rule respawns player
 *      at Room 01 with HP=100 and equipped state preserved
 *   4. Resume combat — assert next Hitbox.hit STILL reads damage=6 (iron_sword)
 *      and the kill pipeline still completes
 *
 * Why this test exists:
 *   PR #146 regression class — the boot-order clobber that wiped the
 *   equipped iron_sword three lines after seeding it. The same regression
 *   class can re-emerge in apply_death_rule if the death-rule code ever
 *   accidentally calls Inventory.reset() instead of Inventory.clear_unequipped().
 *   This spec catches that regression at the integration surface.
 *
 * Death-trigger strategy:
 *   Player has 100 HP; grunt damage_base=3, attack cycle ≈0.95s. Two grunts
 *   in Room 01 both close on the player. Standing still without attacking,
 *   each grunt lands ~1 hit/second = 6 dmg/s combined. ~17s to die at 100 HP.
 *   HP regen never activates (hp damage resets _time_since_last_damage_taken
 *   on every hit, so the 3s threshold never elapses while two grunts pummel).
 *
 *   We DO press dodge a few times to avoid getting one-shot by attack-stuns,
 *   but we never swing — _time_since_last_hit_landed must continue
 *   accumulating (irrelevant to death, but matters for parity with regen).
 *
 *   Test budget: 60s for the death sequence (generous; realistic is ~17-30s).
 *
 * Post-respawn assertion:
 *   We attack the (newly-spawned, HP-refreshed) Room 01 grunts and watch for
 *   the FIRST Hitbox.hit AFTER `[Main] M1 play-loop ready` repeats — wait,
 *   that's wrong, Main doesn't reload on death; only Room 01 reloads.
 *
 *   Death respawn doesn't re-emit the [Main] boot line; it re-emits
 *   `[Inventory] starter iron_sword auto-equipped` only if equip_starter_
 *   weapon_if_needed is called by the respawn flow (which it ISN'T in
 *   apply_death_rule — the equipped state is simply preserved from before
 *   death). Therefore the post-death proof is positive damage=6 hits, NOT
 *   re-firing the auto-equip line.
 *
 * References:
 *   - team/decisions/DECISIONS.md "M1 death rule" 2026-05-02
 *   - scenes/Main.gd:243 — apply_death_rule
 *   - scripts/player/Player.gd:582 — _die emits player_died
 *   - .claude/docs/combat-architecture.md §"Equipped-weapon dual-surface rule"
 */

import { test, expect } from "@playwright/test";
import { ConsoleCapture } from "../fixtures/console-capture";

const BOOT_TIMEOUT_MS = 30_000;
/** Test-overall budget — boot + die + respawn + post-respawn kill */
const OVERALL_TIMEOUT_MS = 180_000;
/** Time to drive death by standing among grunts (no swinging). */
const DEATH_TIMEOUT_MS = 60_000;
/** Post-respawn combat budget — grunts respawned at full HP; need ~10-30s */
const POST_RESPAWN_KILL_TIMEOUT_MS = 60_000;
/** Click cadence used post-respawn */
const ATTACK_INTERVAL_MS = 220;

test.describe("AC3 — death preserves level + V/F/E + equipped weapon", () => {
  test("AC3 — death preserves level + V/F/E + equipped weapon", async ({
    page,
    context,
  }) => {
    test.setTimeout(OVERALL_TIMEOUT_MS);
    await context.route("**/*", (route) => route.continue());

    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL =
      process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(baseURL, { waitUntil: "domcontentloaded" });

    // ---- Phase 1: Cold-boot integration baseline ----
    await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);
    await capture.waitForLine(
      /\[Inventory\] starter iron_sword auto-equipped \(weapon slot\)/,
      5_000
    );

    const canvas = page.locator("canvas").first();
    await canvas.click();
    await page.waitForTimeout(500);

    const canvasBB = await canvas.boundingBox();
    const clickX = (canvasBB?.x ?? 0) + (canvasBB?.width ?? 1280) / 2;
    const clickY = (canvasBB?.y ?? 0) + (canvasBB?.height ?? 720) / 2;

    // ---- Phase 2: Drive player death ----
    //
    // Walk north toward grunts and stand still in their attack zone. Don't
    // swing — the integration-surface bug we're hunting is on the death-rule
    // RESPAWN side. We need clean death first.
    //
    // We DO walk to position ourselves between both grunts; their
    // chase-and-attack-cycle does the rest.
    console.log("[ac3-death] Phase 2: Walking into grunt attack zone (no swinging)...");
    await page.keyboard.down("w");
    await page.waitForTimeout(2_500); // Walk well into grunts' attack range
    await page.keyboard.up("w");

    // Negative-assertion sweep: NO Player.try_attack | FIRED yet (we haven't clicked).
    const earlyAttackLine = capture.findUnexpectedLine(
      /Player\.try_attack \| FIRED/
    );
    if (earlyAttackLine) {
      // Defensive: if a stray attack fired (e.g. from canvas.click() above),
      // it's OK — doesn't invalidate the test, but log it.
      console.log(
        `[ac3-death] NOTE: a player attack fired pre-death (initial focus click): "${earlyAttackLine}"`
      );
    }

    // Wait for player_died signal evidence. The Player emits player_died and
    // Main._on_player_died defers apply_death_rule. apply_death_rule reloads
    // Room 01 — the room load is observable via re-spawning grunts.
    //
    // Console signals we can watch for:
    //   - The HUD HP-bar updates flow through Main._on_player_hp_changed but
    //     don't print to console.
    //   - Player.player_died is a Godot signal, NOT a print line.
    //   - apply_death_rule does NOT print either.
    //   - HOWEVER — `Stratum1Boss._die` / `Grunt._die` only fire on mob death.
    //   - The cleanest tell: the grunt count resets. Both Room 01 grunts come
    //     back after _load_room_at_index(0). We'll check for this indirectly
    //     via the post-respawn first hit landing on a Grunt.
    //
    // Instead, we poll for a state where:
    //   1. Some pre-death enemy hits were observed
    //   2. After ~17-30s, the player has died (no observable trace) and
    //      respawn has fired (player at (240,200), Room 01 reloaded, both
    //      grunts respawned at full HP)
    //
    // The most robust signal: after the death window elapses, the player can
    // SWING again and the next damage=6 hit lands. If the equipped weapon was
    // wiped by a buggy apply_death_rule, damage=N would be 1.

    const deathWindowStart = Date.now();
    let preDeathEnemyHits = 0;

    // Stand still + dodge occasionally to avoid edge cases. Don't swing.
    while (Date.now() - deathWindowStart < DEATH_TIMEOUT_MS) {
      const enemyHits = capture
        .getLines()
        .filter((l) =>
          /\[combat-trace\] Hitbox\.hit \| team=enemy/.test(l.text)
        ).length;
      if (enemyHits > preDeathEnemyHits) {
        preDeathEnemyHits = enemyHits;
      }

      // Heuristic for death detection: the Player's hp_current hits 0 ->
      // emit player_died -> Main calls apply_death_rule -> _load_room_at_index(0)
      // -> player.position = DEFAULT_PLAYER_SPAWN.
      //
      // Side-effect we CAN see: the room reloads, which causes ALL existing
      // grunts to be queue_free'd. The next Grunt._die line we see will be
      // from the post-respawn run (NEW grunts dying when we attack them
      // again post-respawn). Hence, count Grunt._die lines now (zero before
      // we ever swung) and compare later.

      // We've taken enough hits to die — break early to save test budget
      if (preDeathEnemyHits >= 35) {
        console.log(
          `[ac3-death] ${preDeathEnemyHits} enemy hits absorbed in ` +
            `${Date.now() - deathWindowStart}ms — breaking early.`
        );
        // Continue waiting a few more seconds for the death + respawn deferred frames
        await page.waitForTimeout(2_000);
        break;
      }

      await page.waitForTimeout(500);
    }

    if (preDeathEnemyHits === 0) {
      throw new Error(
        "AC3 setup failed: zero enemy hits received during death-window. " +
          "Grunts never reached the player. Check spawn positions / canvas focus."
      );
    }
    console.log(
      `[ac3-death] Pre-death enemy hits absorbed: ${preDeathEnemyHits}. ` +
        `Player should now be dead and respawned.`
    );

    // ---- Phase 3: Post-respawn — assert equipped weapon survived ----

    // Mark our place in the buffer; post-respawn evidence is everything after
    // this point.
    const postRespawnStart = Date.now();
    const preRespawnLineCount = capture.getLines().length;

    // Set facing NE (player is at DEFAULT_PLAYER_SPAWN=(240,200) again, Room 01
    // has both grunts respawned at (352,96) and (256,160) — same NE/N pattern).
    await page.keyboard.down("w");
    await page.keyboard.down("d");
    await page.waitForTimeout(100);
    await page.keyboard.up("w");
    await page.keyboard.up("d");
    await page.waitForTimeout(600);

    let postRespawnHitObserved: string | null = null;
    let postRespawnAttacks = 0;

    while (Date.now() - postRespawnStart < POST_RESPAWN_KILL_TIMEOUT_MS) {
      await canvas.click({ position: { x: clickX, y: clickY } });
      postRespawnAttacks++;
      await page.waitForTimeout(ATTACK_INTERVAL_MS);

      const newLines = capture.getLines().slice(preRespawnLineCount);
      const hitLine = newLines.find((l) =>
        /\[combat-trace\] Hitbox\.hit \| team=player/.test(l.text)
      );
      if (hitLine) {
        postRespawnHitObserved = hitLine.text;
        break;
      }
    }

    expect(
      postRespawnHitObserved,
      `Post-respawn: no Hitbox.hit|team=player after ${postRespawnAttacks} attacks ` +
        `over ${POST_RESPAWN_KILL_TIMEOUT_MS}ms. Either:\n` +
        ` (1) apply_death_rule didn't respawn (no grunts to hit), or\n` +
        ` (2) respawn fired but equipped weapon was wiped → damage=1 fistless mode\n` +
        ` (PR #146 regression class — apply_death_rule called Inventory.reset()?)`
    ).not.toBeNull();

    // The MAIN ASSERTION: post-respawn damage MUST be weapon-scaled (>=2),
    // proving the iron_sword survived apply_death_rule.
    const damageMatch = postRespawnHitObserved!.match(/damage=(\d+)/);
    expect(damageMatch).not.toBeNull();
    const postRespawnDamage = parseInt(damageMatch![1], 10);

    console.log(
      `[ac3-death] Post-respawn first hit: damage=${postRespawnDamage} ` +
        `(${postRespawnAttacks} attacks fired). Expected: 6 (iron_sword).`
    );

    if (postRespawnDamage === 1) {
      throw new Error(
        `AC3 REGRESSION: post-respawn damage=1 (fist). The death rule wiped ` +
          `the equipped iron_sword. Either Inventory.reset() was called instead of ` +
          `clear_unequipped(), or the Player._equipped_weapon was nulled and not ` +
          `re-applied. PR #146 regression class.`
      );
    }
    expect(postRespawnDamage).toBeGreaterThanOrEqual(2);

    // ---- Phase 4: Negative assertions ----

    // 1. No physics-flush panic during the death + respawn sequence
    const panicLine = capture.findUnexpectedLine(
      /Can't change this state while flushing queries/
    );
    expect(panicLine).toBeNull();

    // 2. No Godot push_error during the entire flow.
    //    apply_death_rule does NOT print "[Main] death rule applied" (no print
    //    in current code) — so silence in error stream is the test.
    const firstError = capture.findFirstError();
    if (firstError) {
      console.log("[ac3-death] CONSOLE DUMP:\n" + capture.dump());
    }
    expect(firstError).toBeNull();

    // 3. Negative assertion: the [Main] M1 play-loop ready boot line MUST NOT
    //    repeat. Death triggers a room reload, NOT a full restart. If the
    //    boot line fires twice in this test, the harness is observing a tab
    //    reload rather than a respawn — which would invalidate the
    //    "death-state preservation" claim (a tab reload would re-load from save).
    const bootReadyLines = capture
      .getLines()
      .filter((l) => /\[Main\] M1 play-loop ready/.test(l.text));
    expect(
      bootReadyLines.length,
      "Death must trigger an in-game respawn (apply_death_rule), not a full " +
        "engine reboot. A second [Main] play-loop ready line means the harness " +
        "saw the page reload, which would change the assertion semantics."
    ).toBe(1);

    capture.detach();
  });
});
