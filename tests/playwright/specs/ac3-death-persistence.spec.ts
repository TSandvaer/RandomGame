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
 * **Stage 2b rescope (PR #169 + this PR):** Pre-PR-#169, AC3 used Room01's
 * 2 grunts as the damage source — stand still, eat hits, die. PR #169
 * swapped Room01's roster to a single non-threatening PracticeDummy that
 * deals zero damage. The dummy CANNOT kill the player, so AC3 now must
 * advance through Room01 first (kill the dummy → auto-load Room02), THEN
 * stand still in Room02's two grunts to die.
 *
 * The harness validates the "equipped survives" half by:
 *   1. Boot completes; the player is FISTLESS (the PR #146 boot-equip bandaid
 *      is retired — ticket 86c9qbb3k).
 *   2. Player kills the Room01 PracticeDummy (3 fistless swings) and walks
 *      onto the dummy-dropped iron_sword Pickup — `Inventory.on_pickup_collected`
 *      auto-equips it (`source=auto_pickup`). The Room01 → Room02 advance is
 *      gated on that equip. The `clearRoom01Dummy` helper handles all of this.
 *   3. Player walks toward Room02 grunts and stands still (no attacks) until HP=0
 *   4. After death, Main._on_player_died → apply_death_rule respawns player
 *      at Room 01 with HP=100 and **equipped state preserved** (the M1 death
 *      rule keeps the equipped iron_sword).
 *   5. Player kills the (re-spawned) Room01 PracticeDummy AGAIN. This time the
 *      player is ALREADY equipped (death rule preserved the iron_sword), so
 *      the kill is weapon-scaled (damage=6) and the Room01 → Room02 advance is
 *      NOT gated (immediate-advance path). The fresh dummy still drops an
 *      iron_sword Pickup, but the player already has a weapon so it does NOT
 *      auto-swap (first-weapon-only rule) — the helper detects the
 *      already-equipped case and skips its pickup-collection phase.
 *   6. Resume combat — assert next Hitbox.hit STILL reads damage=6 (iron_sword)
 *      and the kill pipeline still completes against a Room02 grunt
 *
 * Why this test exists:
 *   PR #146 regression class — the boot-order clobber that wiped the
 *   equipped iron_sword three lines after seeding it. The same regression
 *   class can re-emerge in apply_death_rule if the death-rule code ever
 *   accidentally calls Inventory.reset() instead of Inventory.clear_unequipped().
 *   This spec catches that regression at the integration surface.
 *
 * Death-trigger strategy (Stage 2b):
 *   Player has 100 HP; grunt damage_base=3, attack cycle ≈0.95s. Two grunts
 *   in Room 02 both close on the player. Standing still without attacking,
 *   each grunt lands ~1 hit/second = 6 dmg/s combined. ~17s to die at 100 HP.
 *   HP regen never activates (hp damage resets _time_since_last_damage_taken
 *   on every hit, so the 3s threshold never elapses while two grunts pummel).
 *
 *   We don't swing in Room02 — we want clean death. The Room01 dummy clear
 *   does swing (necessary), but those swings finish before Room02 entry.
 *
 *   Test budget: 60s for the Room02 death window (generous; realistic ~17-30s).
 *
 * Post-respawn assertion (Stage 2b):
 *   apply_death_rule respawns the player back at Room 01 with the dummy
 *   re-instantiated. We MUST clear the dummy AGAIN to get back to Room02
 *   for the post-respawn damage=6 assertion. The post-respawn dummy poof
 *   itself ALSO produces a Hitbox.hit damage=N line — that's a valid place
 *   to assert "damage survived the respawn." Whichever swing lands first
 *   (dummy hit OR grunt hit) is the load-bearing post-respawn assertion.
 *
 *   Death respawn doesn't re-emit the [Main] boot line, and apply_death_rule
 *   does NOT re-equip anything — the equipped iron_sword is simply PRESERVED
 *   from before death (M1 death rule). Therefore the post-death proof is
 *   positive damage=6 hits, NOT an equip trace.
 *
 * **Onboarding flow (ticket 86c9qbb3k — bandaid retired):** the player drops
 * in fistless; the Room01 dummy poofs in 3 FIST_DAMAGE=1 swings and drops an
 * iron_sword Pickup the player walks onto to auto-equip. The first
 * `clearRoom01Dummy` call (Phase 2a) does the full kill + pickup-collection.
 * The SECOND call (Phase 3, post-respawn) sees an already-equipped player
 * (death rule preserved the iron_sword) — the helper detects that via the
 * weapon-scaled kill-sweep damage and skips its pickup phase, so this spec
 * works on BOTH the fistless-first-clear and the equipped-respawn-clear.
 *
 * References:
 *   - team/decisions/DECISIONS.md "M1 death rule" 2026-05-02
 *   - team/uma-ux/player-journey.md Beats 4-5 (Stage 2b)
 *   - scenes/Main.gd:243 — apply_death_rule
 *   - scripts/player/Player.gd:582 — _die emits player_died
 *   - resources/level_chunks/s1_room02.tres — 2 grunts (damage source)
 *   - .claude/docs/combat-architecture.md §"Equipped-weapon dual-surface rule"
 *   - tests/playwright/fixtures/room01-traversal.ts — clearRoom01Dummy
 */

import { test, expect } from "@playwright/test";
import { ConsoleCapture } from "../fixtures/console-capture";
import {
  clearRoom01Dummy,
  waitForRoom02Load,
} from "../fixtures/room01-traversal";

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
    // The player boots FISTLESS (the PR #146 boot-equip bandaid is retired,
    // ticket 86c9qbb3k) — there is no `[Inventory] starter iron_sword
    // auto-equipped` line. The player equips by picking up the dummy's drop
    // in Phase 2a below.
    await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);

    const canvas = page.locator("canvas").first();
    await canvas.click();
    await page.waitForTimeout(500);

    const canvasBB = await canvas.boundingBox();
    const clickX = (canvasBB?.x ?? 0) + (canvasBB?.width ?? 1280) / 2;
    const clickY = (canvasBB?.y ?? 0) + (canvasBB?.height ?? 720) / 2;

    // ---- Phase 2a: Clear Room01 dummy (Stage 2b) ----
    //
    // Pre-PR-#169, Room01 had 2 grunts that could kill the standing-still
    // player. Stage 2b's PracticeDummy deals zero damage, so we MUST advance
    // to Room02 first to find a damage source. The helper handles the
    // walk-NE-then-attack-sweep discipline.
    console.log(
      "[ac3-death] Phase 2a: Clearing Room01 dummy + collecting iron_sword Pickup..."
    );
    const room01ClearResult = await clearRoom01Dummy(
      page,
      canvas,
      capture,
      clickX,
      clickY,
      { budgetMs: 40_000 }
    );
    expect(
      room01ClearResult.dummyKilled,
      "Stage 2b: Room01 PracticeDummy must die for the player to reach Room02 " +
        "grunts (the only damage source post-PR-#169). The death-rule test " +
        "depends on Room02 entry."
    ).toBe(true);
    expect(
      room01ClearResult.pickupEquipped,
      "Ticket 86c9qbb3k: the player must collect + auto-equip the dummy-dropped " +
        "iron_sword. The Room01 → Room02 advance is gated on this equip; the " +
        "whole death-rule test depends on the player being equipped so the " +
        "post-respawn damage=6 assertion is meaningful."
    ).toBe(true);
    await waitForRoom02Load(page, 1500);

    // ---- Phase 2b: Drive player death in Room02 ----
    //
    // Walk north toward Room02 grunts and stand still in their attack zone.
    // Don't swing — the integration-surface bug we're hunting is on the
    // death-rule RESPAWN side. We need clean death first.
    //
    // We DO walk to position ourselves between both grunts; their
    // chase-and-attack-cycle does the rest.
    console.log("[ac3-death] Phase 2b: Walking into Room02 grunt attack zone (no swinging)...");
    await page.keyboard.down("w");
    await page.waitForTimeout(2_500); // Walk well into grunts' attack range
    await page.keyboard.up("w");

    // Wait for player_died signal evidence. The Player emits player_died and
    // Main._on_player_died defers apply_death_rule. apply_death_rule reloads
    // Room 01 — the room load is observable via the re-spawned dummy.
    //
    // Console signals we can watch for:
    //   - The HUD HP-bar updates flow through Main._on_player_hp_changed but
    //     don't print to console.
    //   - Player.player_died is a Godot signal, NOT a print line.
    //   - apply_death_rule does NOT print either.
    //   - HOWEVER — `Grunt._die` only fires on mob death.
    //   - The cleanest tell: the room reloads + a fresh PracticeDummy is
    //     re-instantiated. We confirm respawn by attempting Room01 dummy
    //     clear AGAIN below — if the dummy is gone post-respawn (still dead),
    //     either the room didn't reload or the player is somewhere else.
    //
    // Instead, we poll for a state where:
    //   1. Some pre-death enemy hits were observed
    //   2. After ~17-30s, the player has died (no observable trace) and
    //      respawn has fired (player at (240,200), Room 01 reloaded, dummy
    //      respawned at full HP=3)
    //
    // The most robust signal: after the death window elapses, the player can
    // SWING again and the next damage=6 hit lands. If the equipped weapon was
    // wiped by a buggy apply_death_rule, damage=N would be 1.

    const deathWindowStart = Date.now();
    let preDeathEnemyHits = 0;

    // Stand still. Don't swing.
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
        "AC3 setup failed: zero enemy hits received during Room02 death-window. " +
          "Either Room01 dummy clear failed (Room02 not reached) or Room02 grunts " +
          "never reached the player. Check spawn positions / canvas focus."
      );
    }
    console.log(
      `[ac3-death] Pre-death enemy hits absorbed: ${preDeathEnemyHits}. ` +
        `Player should now be dead and respawned to Room01.`
    );

    // ---- Phase 3: Post-respawn — assert equipped weapon survived ----
    //
    // Post-death, the player is back at Room01 with a freshly-instantiated
    // PracticeDummy AND the iron_sword still equipped (the M1 death rule
    // preserves equipped state). We re-run the Room01 dummy-clear helper: the
    // player is ALREADY equipped, so the kill-sweep hits are weapon-scaled
    // (damage=6), the Room01 → Room02 advance is NOT gated (immediate-advance
    // path), and the helper detects the already-equipped case and skips its
    // pickup-collection phase. We extract the first damage=N value from the
    // Hitbox.hit traces during the sweep — it MUST be >=2 (proves the
    // iron_sword survived apply_death_rule). A damage=1 result would mean the
    // death rule wiped the equipped weapon.

    // Mark our place in the buffer; post-respawn evidence is everything after
    // this point.
    const preRespawnLineCount = capture.getLines().length;

    const postRespawnClearResult = await clearRoom01Dummy(
      page,
      canvas,
      capture,
      clickX,
      clickY,
      { budgetMs: POST_RESPAWN_KILL_TIMEOUT_MS }
    );
    expect(
      postRespawnClearResult.dummyKilled,
      "Post-respawn: Room01 PracticeDummy must die again. The dummy was " +
        "re-instantiated by apply_death_rule's Room01 reload. If the kill " +
        "doesn't land at all, the room didn't reload (apply_death_rule " +
        "regression). NOTE: the load-bearing death-rule assertion is the " +
        "post-respawn damage value below — if the death rule WIPED the " +
        "equipped weapon, the kill-sweep hits drop to damage=1 (and the " +
        "damage>=2 assertion fails) even though the helper would still " +
        "complete by re-equipping via the re-dropped Pickup."
    ).toBe(true);

    // Find the first Hitbox.hit team=player line AFTER preRespawnLineCount.
    const postRespawnHitObserved = capture
      .getLines()
      .slice(preRespawnLineCount)
      .find((l) => /\[combat-trace\] Hitbox\.hit \| team=player/.test(l.text))
      ?.text ?? null;

    expect(
      postRespawnHitObserved,
      `Post-respawn: no Hitbox.hit|team=player after ${postRespawnClearResult.attacksFired} ` +
        `attacks over ${POST_RESPAWN_KILL_TIMEOUT_MS}ms. The dummy-clear helper ` +
        `reported dummyKilled=${postRespawnClearResult.dummyKilled} but no ` +
        `Hitbox.hit fired. Either:\n` +
        ` (1) the Hitbox combat-trace shim regressed (dummy died but no trace), or\n` +
        ` (2) the dummy was killed by an unrelated source (impossible by design — ` +
        `   the dummy is rooted and deals zero damage; only player swings hit).`
    ).not.toBeNull();

    // The MAIN ASSERTION: post-respawn damage MUST be weapon-scaled (>=2),
    // proving the iron_sword survived apply_death_rule.
    const damageMatch = postRespawnHitObserved!.match(/damage=(\d+)/);
    expect(damageMatch).not.toBeNull();
    const postRespawnDamage = parseInt(damageMatch![1], 10);

    console.log(
      `[ac3-death] Post-respawn first hit: damage=${postRespawnDamage} ` +
        `(${postRespawnClearResult.attacksFired} attacks fired, ` +
        `${postRespawnClearResult.durationMs}ms helper duration). ` +
        `Expected: 6 (iron_sword).`
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
