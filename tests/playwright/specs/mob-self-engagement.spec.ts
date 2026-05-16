/**
 * mob-self-engagement.spec.ts
 *
 * **Passive-player mob self-engagement spec class — Sponsor M2 RC soak
 * meta-finding (2026-05-15), ticket 86c9uerk8 / W3-T13.**
 *
 * Sponsor directive: "the tester should be able to test what I found."
 *
 * The four Sponsor soak findings all slipped past the harness because of
 * coverage gaps. THIS spec closes the most load-bearing gap: every existing
 * AC4 / room-traversal spec DRIVES the player toward the mob (via the
 * `chaseAndClearKitingMobs`, `chaseAndClearMultiChaserRoom`, or fixed-position
 * click-spam loops). That means mob-self-engagement bugs — "the mob always
 * flees, never engages" — are INVISIBLE to those specs by construction. The
 * Room 04 Shooter AI bug (`86c9uehaq` — Shooter only flees, cornered=idle,
 * out-of-range=no-pursuit) shipped to Sponsor in the M2 RC because the AC4
 * spec drove the player AT the Shooter and cornered it; the bug only
 * surfaced when Sponsor manually walked into Room 04 and stood still.
 *
 * **The spec pattern:**
 *
 *   1. Boot, drive normally through prior rooms to land in the target room.
 *   2. Player STANDS STILL at `DEFAULT_PLAYER_SPAWN = (240, 200)` — no
 *      movement, no attack, no key presses after the room loads.
 *   3. Wait for the engagement window (~10s melee, ~15s kite-then-shoot,
 *      ~5s boss).
 *   4. Assert: at least one `[combat-trace] Hitbox.hit | team=mob
 *      target=Player damage=N` line fires within the window — i.e. some mob
 *      reached the passive player and landed a hit on them.
 *
 * **Why `team=mob target=Player` is the load-bearing signal:** the
 * `Hitbox.gd::_try_apply_hit` shim emits the trace AFTER the hitbox
 * Area2D-overlapped the target AND the target's `take_damage()` accepted the
 * call. A `team=mob target=Player` line therefore proves both that (a) the
 * mob's spatial AI brought it into the player's hit-rect (so engagement
 * succeeded mechanically) AND (b) the mob's combat-loop actually fired its
 * attack (so the AI wasn't stuck idle / fleeing-only). A
 * `team=mob target=Player damage=0` line would still satisfy the
 * engagement-window assertion at the Hitbox layer — but `Player.take_damage`
 * early-returns on `_is_invulnerable` BEFORE the trace fires, and a player
 * who's not been hit yet has `_is_invulnerable = false`, so the first hit
 * always lands and emits the trace. The post-hit 0.25s iframes (`Player.gd
 * HIT_IFRAMES_SECS`) are not the issue: the spec only needs the FIRST
 * `team=mob target=Player` line, and iframes only cap repeated hits.
 *
 * **Per-room engagement windows** (median + 50% headroom from Sponsor's
 * informal soak observations + the `scripts/mobs/*.gd` distance bands):
 *
 *   - Pure-melee rooms (Rooms 02, 03, 05, 08-chasers): ~10s. A Grunt at
 *     `move_speed = 60 px/s` covers the ~140-200 px room-spawn distance to
 *     player in ~2.5-3.5 s; first hit lands when the Grunt enters the
 *     player's `take_damage` collision rect. With 50% headroom, 10s is
 *     comfortable but tight enough that an always-flee bug fails clearly.
 *
 *   - Kite-then-shoot rooms (Rooms 04, 06, 07, 08-shooters): ~15s. A
 *     Shooter at distance > AIM_RANGE (300px) walks IN to the sweet spot
 *     (120-300px) and fires a projectile. The projectile travels at the
 *     production speed; first hit lands when the projectile's `Hitbox`
 *     overlaps the player. Room 04 spec spawn is 178 px from player —
 *     INSIDE the sweet spot already, so the Shooter should stand still and
 *     fire immediately. The fact that Sponsor reported "Shooter never
 *     engages in Room 04" means either (a) the Shooter is not in fact
 *     standing-and-firing — it's fleeing on first-tick — or (b) the
 *     Shooter is firing but its hitbox is not reaching the player. Either
 *     case fails this assertion correctly.
 *
 *   - Stratum-1 boss: ~5s. The boss's entry sequence takes 1.8s
 *     (`Stratum1BossRoom._trigger_entry_sequence` → 1.8s wait → boss IDLE
 *     → CHASING). The boss closes from spawn (~150 px) at production
 *     speed; first hit lands when its swing wedge overlaps the player.
 *     5s = 1.8s entry + 3.2s engage window with headroom.
 *
 * **Sponsor's note on rooms that "play OK manually" (Rooms 02, 03, 05, 06,
 * 07, 08):** Sponsor's soak found the bug in Room 04 specifically. The
 * other rooms' mobs engaged correctly during manual play, so this spec
 * EXPECTS them to pass on first run. If any of those rooms flips RED on
 * first run, that surfaces a FRESH bug — file it as it appears.
 *
 * **Per-room test.fail() disposition (this PR — initial scaffold):**
 *
 *   - **Room 02** — `test()`. Implemented end-to-end (the only room
 *     reachable via the already-exported `clearRoom01Dummy` helper without
 *     replicating the AC4 spec's multi-room traversal chain). Expected to
 *     pass on first run. If RED on first run: FRESH bug — file as a
 *     `bug(combat)` ticket against the room's mob roster.
 *
 *   - **Rooms 03, 04, 05, 06, 07, 08, S1 Boss** — `test.fail()`. The
 *     navigation-to-room helper (`traverseToRoom(N)` — drive all prior rooms
 *     to completion without engaging in the target room) hasn't been
 *     extracted yet — the AC4 spec carries its own inline `clearRoomMobs`
 *     closure that is not currently exported. Lifting it into a shared
 *     fixture is a follow-up extraction (filed as the post-merge TODO on
 *     ticket 86c9uerk8). When the helper lands:
 *       - Room 04 will FLIP after Drew's `86c9uehaq` Shooter AI fix —
 *         Sponsor flagged this room specifically.
 *       - All other rooms expected to flip green on first try (Sponsor
 *         said they play OK manually).
 *     Until the helper lands, each room's `test.fail()` block carries the
 *     full assertion logic ready for flip — the only thing missing is the
 *     pre-room navigation drive.
 *
 * **Pairs with:** `.claude/docs/combat-architecture.md` § "Harness coverage
 * gap — player-driven helpers don't validate mob self-engagement" — Sponsor
 * authored that doc section in this turn and it lands in a separate commit;
 * this spec references it forward-looking. Once the doc lands the cross-ref
 * is bi-directional.
 *
 * References:
 *   - team/tess-qa/playwright-harness-design.md § (Tess's harness design)
 *   - scripts/combat/Hitbox.gd::_try_apply_hit — emits the team/target trace
 *   - scripts/player/Player.gd::take_damage — receives the mob's hit
 *   - scripts/mobs/Shooter.gd — distance-band kite/aim/pursue logic
 *   - scripts/mobs/Grunt.gd / Charger.gd — chase-into-melee behavior
 *   - scripts/mobs/Stratum1Boss.gd — boss AI (engagement post-entry-sequence)
 *   - tests/playwright/specs/ac4-boss-clear.spec.ts — the AC4 spec the
 *     coverage gap was discovered against
 *   - tests/playwright/fixtures/room01-traversal.ts — clearRoom01Dummy
 *   - ClickUp 86c9uehaq — Room 04 Shooter AI bug (the Sponsor finding)
 *   - ClickUp 86c9uerk8 — this ticket (W3-T13 scaffold)
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";
import {
  clearRoom01Dummy,
  waitForRoom02Load,
} from "../fixtures/room01-traversal";

const BOOT_TIMEOUT_MS = 30_000;
const ROOM01_CLEAR_TIMEOUT_MS = 90_000;

/**
 * The combat-trace signature for "a mob's hitbox just landed on the
 * passive player." This is the load-bearing assertion across every test in
 * this spec class — see the file-level docstring for the rationale.
 */
const MOB_HIT_PLAYER_TRACE_RE =
  /\[combat-trace\] Hitbox\.hit \| team=mob target=Player damage=\d+/;

/**
 * Per-room engagement-window expectations. These windows include 50%
 * headroom against the median observed in Sponsor's M2 RC soak and the
 * production mob `move_speed` × room-spawn-distance math. A flake-cushion
 * lives ON TOP of the window inside each test as the Playwright
 * `setTimeout` budget — the WINDOW itself stays tight so an always-flee
 * bug fails clearly rather than silently passing on the back of a 60-s
 * test timeout.
 */
interface RoomEngagementSpec {
  /** Room label (used in log lines + assertion failure messages). */
  label: string;
  /** Mob composition from `resources/level_chunks/s1_room0N.tres`. */
  mobs: string;
  /**
   * Max time (ms) for the FIRST mob hit on the passive player after the
   * room loads + player teleport settles.
   */
  engagementWindowMs: number;
  /**
   * Why this window — short prose for failure-message context. The window
   * derivation lives in the file-level docstring; this is just the
   * one-liner the failure message embeds.
   */
  rationale: string;
}

const ROOM_SPECS: Record<string, RoomEngagementSpec> = {
  room02: {
    label: "Room 02",
    mobs: "2 grunts",
    engagementWindowMs: 10_000,
    rationale:
      "pure-melee Grunts at 60 px/s cover the ~140px room-spawn distance " +
      "in ~2.3s; first hit lands when they enter the Player rect",
  },
  room03: {
    label: "Room 03",
    mobs: "1 grunt + 1 charger",
    engagementWindowMs: 10_000,
    rationale:
      "pure-melee Grunt + Charger; Charger telegraph + charge cycle is " +
      "faster than Grunt walk-in. First hit by ~3-5s in manual play",
  },
  room04: {
    label: "Room 04",
    mobs: "1 shooter",
    engagementWindowMs: 15_000,
    rationale:
      "Sponsor flag — the BLOCKER. Shooter spawns 178 px from player " +
      "(INSIDE 120-300px sweet spot) so it should stand still and fire " +
      "the projectile immediately. Bug: never engages",
  },
  room05: {
    label: "Room 05",
    mobs: "2 grunts + 1 charger",
    engagementWindowMs: 10_000,
    rationale:
      "3-chaser room; even passive player should see the first hit within " +
      "~4-6s (3 mobs ⇒ at least one reaches the player fast)",
  },
  room06: {
    label: "Room 06",
    mobs: "2 chargers + 1 shooter",
    engagementWindowMs: 15_000,
    rationale:
      "kite-then-shoot — Shooter fires from sweet spot OR Chargers close. " +
      "Either landing satisfies engagement (passive player just needs ANY mob hit)",
  },
  room07: {
    label: "Room 07",
    mobs: "2 chargers + 2 shooters",
    engagementWindowMs: 15_000,
    rationale:
      "kite-then-shoot — 4 mobs ⇒ at least one Charger or Shooter projectile " +
      "should land within the window",
  },
  room08: {
    label: "Room 08",
    mobs: "1 grunt + 1 charger + 2 shooters",
    engagementWindowMs: 15_000,
    rationale:
      "kite-then-shoot — mixed roster, expect first hit from one of the " +
      "chaser pair or a Shooter projectile",
  },
  bossRoom: {
    label: "S1 Boss Room",
    mobs: "Stratum1Boss",
    engagementWindowMs: 5_000,
    rationale:
      "boss entry sequence (1.8s) + boss-engage cycle. Boss closes from " +
      "spawn at production speed; first hit by ~3-4s post-entry",
  },
};

/**
 * Wait for the first MOB_HIT_PLAYER_TRACE_RE line to appear after the
 * given baseline line-count, with a hard wall-clock deadline. Returns the
 * matched line (with its capture-buffer index) on success, or null on
 * timeout.
 *
 * The baseline-count approach lets the caller scope the assertion to
 * "lines emitted AFTER the room loaded" — without it, an earlier room's
 * mob-hits-Player trace from the traversal phase would falsely satisfy
 * the assertion.
 */
async function waitForFirstMobHitOnPlayer(
  capture: ConsoleCapture,
  baselineLineCount: number,
  budgetMs: number
): Promise<{ index: number; text: string } | null> {
  const deadline = Date.now() + budgetMs;
  while (Date.now() < deadline) {
    const lines = capture.getLines();
    for (let i = baselineLineCount; i < lines.length; i++) {
      if (MOB_HIT_PLAYER_TRACE_RE.test(lines[i].text)) {
        return { index: i, text: lines[i].text };
      }
    }
    // Poll cadence: 250ms is fast enough that the WINDOW expectations
    // (5-15s) aren't materially affected, slow enough that we don't melt
    // the CPU during a 15s budget. Playwright's setTimeout is wall-clock,
    // so this is a real-time poll.
    await new Promise((r) => setTimeout(r, 250));
  }
  return null;
}

test.describe("mob self-engagement — passive player, mob must reach + land hit", () => {
  // ===================================================================
  // ROOM 02 — `test()` — fully implemented, expected to pass on first run
  // ===================================================================
  //
  // Room 02 ships 2 Grunts at world (272, 112) and (336, 176) per
  // `resources/level_chunks/s1_room02.tres`. Both are NE of player spawn
  // (240, 200) at distances ~98px and ~99px respectively. Grunts at
  // `move_speed = 60 px/s` reach the player in ~1.6-1.7s after the room
  // settles. With the production Grunt collision rect + Player rect, first
  // contact-frame fires `Hitbox.hit | team=mob target=Player` within
  // ~2.5-3s. Engagement window: 10s (3-4x headroom).
  //
  // **Sponsor manual-play observation:** Room 02 chasers engage correctly.
  // If this test flips RED on first run, that's a fresh bug (likely a
  // regression in Grunt chase AI or the Mob → Player collision rect).
  test(
    "Room 02 — passive player: 2 grunts must reach and land a hit",
    async ({ page, context }) => {
      test.setTimeout(120_000);
      await context.route("**/*", (route) => route.continue());

      const capture = new ConsoleCapture(page);
      capture.attach();

      const baseURL =
        process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
      await page.goto(baseURL, { waitUntil: "domcontentloaded" });

      // ---- Boot ----
      await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);

      const canvas = page.locator("canvas").first();
      await canvas.click();
      await page.waitForTimeout(500);

      const canvasBB = await canvas.boundingBox();
      const clickX = (canvasBB?.x ?? 0) + (canvasBB?.width ?? 1280) / 2;
      const clickY = (canvasBB?.y ?? 0) + (canvasBB?.height ?? 720) / 2;

      // ---- Drive Room 01 (PR #169 tutorial dummy + pickup-equip) ----
      // We MUST clear Room 01 normally — the PracticeDummy doesn't engage
      // (HP=3, no damage output, no chase). Room 01's purpose in THIS spec
      // is purely "advance the room counter so the player lands in Room 02
      // at DEFAULT_PLAYER_SPAWN ready to stand still." The iron_sword equip
      // is a side-effect of the standard onboarding; it doesn't change the
      // Room 02 engagement test (the player won't be attacking).
      const room01Result = await clearRoom01Dummy(
        page,
        canvas,
        capture,
        clickX,
        clickY,
        { budgetMs: ROOM01_CLEAR_TIMEOUT_MS }
      );
      expect(
        room01Result.dummyKilled,
        "Room 01 PracticeDummy must die — required to advance to Room 02 " +
          `(${room01Result.attacksFired} attacks fired).`
      ).toBe(true);
      expect(
        room01Result.pickupEquipped,
        "Room 01 iron_sword Pickup must be collected + auto-equipped — the " +
          "Room 01 → Room 02 advance is GATED on this equip (86c9qbb3k)."
      ).toBe(true);

      // ---- Wait for Room 02 load + player teleport settle ----
      await waitForRoom02Load(page, 1500);

      // Defensive: release any held keys from the Room 01 helper. We're
      // about to assert "passive player" — no key may be held.
      for (const k of ["w", "a", "s", "d"] as const) {
        await page.keyboard.up(k);
      }

      // Snapshot baseline count AFTER Room 02 has loaded — every Hitbox.hit
      // line from THIS point forward is scoped to Room 02 only. A pre-existing
      // `team=mob` line from Room 01 (the dummy doesn't damage, so this is
      // defensive) would otherwise satisfy the assertion falsely.
      const baselineCount = capture.getLines().length;

      // Per-room window from ROOM_SPECS (10s for pure-melee Grunt room).
      const spec = ROOM_SPECS.room02;
      console.log(
        `[mob-engagement] ${spec.label}: passive player stands at spawn ` +
          `(no movement, no attack). Expecting first mob-hit-on-player ` +
          `within ${spec.engagementWindowMs}ms. Roster: ${spec.mobs}. ` +
          `Rationale: ${spec.rationale}.`
      );

      // ---- The engagement-window assertion ----
      const startEngage = Date.now();
      const firstHit = await waitForFirstMobHitOnPlayer(
        capture,
        baselineCount,
        spec.engagementWindowMs
      );
      const engageDurationMs = Date.now() - startEngage;

      if (firstHit === null) {
        // No mob hit landed within the window. Dump diagnostic context.
        const room02Lines = capture.getLines().slice(baselineCount);
        const playerPosLines = room02Lines.filter((l) =>
          /\[combat-trace\] Player\.pos/.test(l.text)
        );
        const mobPosLines = room02Lines.filter((l) =>
          /\[combat-trace\] (Grunt|Charger|Shooter)\.pos/.test(l.text)
        );
        const anyHitboxLines = room02Lines.filter((l) =>
          /\[combat-trace\] Hitbox\.hit/.test(l.text)
        );

        console.log(
          `[mob-engagement] ${spec.label} ENGAGEMENT FAILURE — ` +
            `${spec.engagementWindowMs}ms window expired with no mob hit. ` +
            `Diagnostics: ${playerPosLines.length} Player.pos traces, ` +
            `${mobPosLines.length} Mob.pos traces, ${anyHitboxLines.length} ` +
            `Hitbox.hit lines (any team).`
        );
        if (mobPosLines.length > 0) {
          console.log(
            `[mob-engagement] last 5 Mob.pos lines:\n` +
              mobPosLines
                .slice(-5)
                .map((l) => `  ${l.text}`)
                .join("\n")
          );
        }
        if (anyHitboxLines.length > 0) {
          console.log(
            `[mob-engagement] all Hitbox.hit lines (any team):\n` +
              anyHitboxLines.map((l) => `  ${l.text}`).join("\n")
          );
        }
      }

      expect(
        firstHit,
        `${spec.label}: passive player at DEFAULT_PLAYER_SPAWN must be ` +
          `hit by a mob within ${spec.engagementWindowMs}ms. No ` +
          `[combat-trace] Hitbox.hit | team=mob target=Player line ` +
          `observed in the window (${engageDurationMs}ms elapsed). ` +
          `Rationale: ${spec.rationale}. Roster: ${spec.mobs}. ` +
          `An always-flee / cornered-idle bug would produce this signature.`
      ).not.toBeNull();

      console.log(
        `[mob-engagement] ${spec.label}: first mob hit at ` +
          `t=${engageDurationMs}ms — "${firstHit!.text}".`
      );

      // ---- Negative-assertion sweep: no panic during the passive wait ----
      const panicLine = capture.findUnexpectedLine(
        /Can't change this state while flushing queries/
      );
      expect(
        panicLine,
        `${spec.label}: physics-flush panic during passive-player wait. ` +
          "An Area2D mutation from a physics-tick path leaked through. " +
          `Panic line: ${panicLine}`
      ).toBeNull();

      capture.detach();
    }
  );

  // ===================================================================
  // ROOMS 03–08 + S1 Boss — `test.fail()` — scaffold-only until the
  // `traverseToRoom(N)` helper extraction lands (post-merge follow-up).
  // ===================================================================
  //
  // Each test below carries the FULL assertion logic ready for flip. The
  // only piece missing is the navigation drive that gets the player into
  // the target room without engaging combat there. Lifting the AC4 spec's
  // inline `clearRoomMobs` closure into a shared fixture (e.g.
  // `tests/playwright/fixtures/multi-room-traversal.ts`) and adding a
  // `traverseToRoom(page, canvas, capture, targetIndex, clickX, clickY)`
  // export is filed as the post-merge TODO on ticket 86c9uerk8.
  //
  // **Flip-trigger per room:**
  //   - Room 04 — flip after Drew's `86c9uehaq` Shooter AI fix.
  //   - Rooms 03, 05, 06, 07, 08, S1 Boss — flip when the traverseToRoom
  //     helper extraction lands. Expected to pass on first try (Sponsor
  //     said they play OK manually). If any flips RED on first run after
  //     the helper lands, that's a FRESH bug — file as it appears.

  /**
   * Per-room body shared by every `test.fail()` block below. Encapsulates
   * the "passive player at spawn, wait for first mob-hit" assertion. The
   * traversal-to-room phase is a placeholder until the helper lands.
   */
  const buildPassivePlayerTest = (
    specKey: keyof typeof ROOM_SPECS,
    targetRoomIndex: number,
    plannedTraversalPath: string
  ) => {
    const spec = ROOM_SPECS[specKey];
    return async ({
      page,
      context,
    }: {
      page: import("@playwright/test").Page;
      context: import("@playwright/test").BrowserContext;
    }) => {
      test.setTimeout(900_000); // 15-min ceiling for multi-room traversal + passive window
      await context.route("**/*", (route) => route.continue());

      const capture = new ConsoleCapture(page);
      capture.attach();

      const baseURL =
        process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
      await page.goto(baseURL, { waitUntil: "domcontentloaded" });
      await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);

      const canvas = page.locator("canvas").first();
      await canvas.click();
      await page.waitForTimeout(500);

      // TODO (ticket 86c9uerk8 follow-up): replace this throw with
      //   await traverseToRoom(page, canvas, capture, targetRoomIndex, ...)
      // once the multi-room traversal helper is extracted from
      // `tests/playwright/specs/ac4-boss-clear.spec.ts`'s inline
      // `clearRoomMobs` closure. The planned traversal path for this room
      // is: `${plannedTraversalPath}`.
      //
      // The throw below is what keeps the test.fail() block honest — it
      // makes Playwright record this as "fail-as-expected" instead of
      // silently green-on-no-op. When the helper lands, replace the throw
      // with the helper call and the body below runs the real assertion.
      throw new Error(
        `[mob-engagement] ${spec.label}: traverseToRoom(${targetRoomIndex}) ` +
          `helper not yet extracted (planned path: ${plannedTraversalPath}). ` +
          `Ticket 86c9uerk8 follow-up. Roster=${spec.mobs}, ` +
          `window=${spec.engagementWindowMs}ms.`
      );

      // ---- Post-helper-extraction body (kept here for diff-readability
      //      when the flip lands) ----
      //
      // Defensive: release any held keys from the traversal helper.
      // for (const k of ["w", "a", "s", "d"] as const) {
      //   await page.keyboard.up(k);
      // }
      // const baselineCount = capture.getLines().length;
      // console.log(
      //   `[mob-engagement] ${spec.label}: passive player stands at spawn. ` +
      //     `Window=${spec.engagementWindowMs}ms, roster=${spec.mobs}.`
      // );
      // const startEngage = Date.now();
      // const firstHit = await waitForFirstMobHitOnPlayer(
      //   capture,
      //   baselineCount,
      //   spec.engagementWindowMs
      // );
      // const engageDurationMs = Date.now() - startEngage;
      // expect(
      //   firstHit,
      //   `${spec.label}: passive player must be hit by a mob within ` +
      //     `${spec.engagementWindowMs}ms. Rationale: ${spec.rationale}.`
      // ).not.toBeNull();
      // console.log(
      //   `[mob-engagement] ${spec.label}: first mob hit at ` +
      //     `t=${engageDurationMs}ms — "${firstHit!.text}".`
      // );
      // const panicLine = capture.findUnexpectedLine(
      //   /Can't change this state while flushing queries/
      // );
      // expect(panicLine).toBeNull();
      // capture.detach();
    };
  };

  // ---- Room 03 — `test.fail()` until traverseToRoom helper lands -----
  test.fail(
    "Room 03 — passive player: 1 grunt + 1 charger must reach and land a hit",
    buildPassivePlayerTest(
      "room03",
      2,
      "boot → clearRoom01Dummy → clearRoom02 (combat + gate) → arrive in Room 03"
    )
  );

  // ---- Room 04 — `test.fail()` — flip after Drew's 86c9uehaq Shooter
  //      AI fix. THIS is the load-bearing test for the Sponsor finding. --
  //
  // **Sponsor's Room 04 finding (ticket 86c9uehaq):** the single Shooter
  // spawns at world (400, 96) — 178 px from player spawn (240, 200), well
  // INSIDE the Shooter's 120-300px AIM/sweet-spot band. Per
  // `scripts/mobs/Shooter.gd § "Distance bands"`, a Shooter inside the
  // sweet spot should STAND STILL and fire its projectile. Sponsor reports
  // it doesn't — the Shooter only flees, never engages. When cornered
  // (player chases) it goes idle; when out of range it does NOT pursue.
  //
  // The PASSIVE-player assertion here is the cleanest possible probe: if
  // the Shooter is healthy, it fires within ~1-2s of room load and the
  // projectile reaches the player in another ~1-2s. 15s window has 4-5x
  // headroom. If Drew's fix lands and the test still fails, that surfaces
  // additional Shooter AI gaps (e.g. projectile-spawn but no flight, or
  // hitbox-overlap but no take_damage call) — file each as it appears.
  test.fail(
    "Room 04 — passive player: single Shooter must reach and land a hit (Sponsor 86c9uehaq)",
    buildPassivePlayerTest(
      "room04",
      3,
      "boot → clearRoom01Dummy → clearRoom02 → clearRoom03 → arrive in Room 04"
    )
  );

  // ---- Room 05 — `test.fail()` until traverseToRoom helper lands -----
  test.fail(
    "Room 05 — passive player: 2 grunts + 1 charger must reach and land a hit",
    buildPassivePlayerTest(
      "room05",
      4,
      "boot → R01..R04 traversal → arrive in Room 05"
    )
  );

  // ---- Room 06 — `test.fail()` until traverseToRoom helper lands -----
  //
  // **Sponsor noted this room plays OK manually.** Once the helper lands
  // and this test flips test(), it should pass on first run. If RED on
  // first run, that's a fresh bug.
  test.fail(
    "Room 06 — passive player: 2 chargers + 1 shooter must reach and land a hit",
    buildPassivePlayerTest(
      "room06",
      5,
      "boot → R01..R05 traversal → arrive in Room 06"
    )
  );

  // ---- Room 07 — `test.fail()` until traverseToRoom helper lands -----
  test.fail(
    "Room 07 — passive player: 2 chargers + 2 shooters must reach and land a hit",
    buildPassivePlayerTest(
      "room07",
      6,
      "boot → R01..R06 traversal → arrive in Room 07"
    )
  );

  // ---- Room 08 — `test.fail()` until traverseToRoom helper lands -----
  test.fail(
    "Room 08 — passive player: 1 grunt + 1 charger + 2 shooters must reach and land a hit",
    buildPassivePlayerTest(
      "room08",
      7,
      "boot → R01..R07 traversal → arrive in Room 08"
    )
  );

  // ---- S1 Boss Room — `test.fail()` until traverseToRoom helper lands -
  //
  // The boss has its own entry sequence (1.8s wait → IDLE → CHASING). The
  // engagement window includes that entry time + the close-from-spawn-to-
  // melee distance. Boss closes at production speed; first swing-wedge hit
  // on the passive player by ~3-4s post-entry. 5s window is tight but
  // healthy — a stuck-in-IDLE or never-CHASING boss fails clearly. The
  // boss's swing wedge fires through the same `Hitbox.hit` shim as mob
  // hits, so `team=mob target=Player` covers the assertion identically.
  test.fail(
    "S1 Boss Room — passive player: Stratum1Boss must reach and land a hit",
    buildPassivePlayerTest(
      "bossRoom",
      8,
      "boot → R01..R08 traversal + gate → arrive in S1 Boss Room"
    )
  );
});
