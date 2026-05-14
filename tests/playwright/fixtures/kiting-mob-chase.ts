/**
 * kiting-mob-chase.ts — Shooter-aware "chase-then-return" combat sub-helper
 *
 * **Why this fixture exists (AC4 Room 04 blocker, ticket 86c9tz7zg):**
 *
 * The AC4 spec's `clearRoomMobs` helper is built on one premise — "all mobs
 * chase the player into melee, so click-spamming near `DEFAULT_PLAYER_SPAWN`
 * eventually lands every hit." That premise holds for **Grunt** and
 * **Charger** (both close distance toward the player), but it is FALSE for
 * the **Shooter**.
 *
 * The Shooter is a ranged kiter (`scripts/mobs/Shooter.gd`, `ai_behavior_tag
 * = &"ranged_kiter"`). Its distance bands:
 *
 *   - `dist < KITE_RANGE` (120 px) → `STATE_KITING`: the Shooter walks
 *     *directly away from the player* at `move_speed` (60 px/s) until
 *     distance is restored above `KITE_RANGE + 16`.
 *   - `KITE_RANGE .. AIM_RANGE` (120..300 px) → the "sweet spot": the
 *     Shooter STANDS STILL and shoots — it does NOT close the gap.
 *   - `dist > AIM_RANGE` (300 px) → the Shooter walks *toward* the player
 *     to re-enter the sweet spot.
 *
 * Room 04 is the only pure-Shooter room. Its single Shooter spawns at tile
 * (12, 3) = world (384, 96) — ~178 px from player spawn (240, 200), inside
 * the sweet spot. So the Shooter stands there shooting, never closes, and
 * the player's near-spawn click-spam (swing reach ≈ 46 px) never lands a
 * hit. The AC4 spec stalls at "killed 0/1 in 90s".
 *
 * Rooms 05–08 pass only *incidentally*: their Grunts/Chargers keep the
 * player engaged near spawn, and the Shooter gets caught in the swing wedge
 * by luck of geometry as the chasers crowd in. Room 04 has no chaser to
 * provide that cover, so the harness gap is exposed.
 *
 * **Why a blind directional pursuit does NOT work:**
 *
 * The Shooter does not retreat to a *fixed* corner — it kites *directly
 * away from the player's current position*, dynamically. A "just walk NE"
 * pursuit was empirically observed (diag build, `diag/shooter-chase-
 * positions`) to overshoot: the player jammed into the NE corner at
 * (438, 42) while the Shooter — now SOUTH of the player — calmly kited to
 * (364, 180) and sat there at full HP. The pursuit direction has to TRACK
 * the Shooter, which means the harness needs to know where the Shooter
 * actually is.
 *
 * **The fix — position-steered pursuit (`Player.pos` + `Shooter.pos`):**
 *
 * `Player.gd` and `Shooter.gd` now emit a throttled, HTML5-only
 * `[combat-trace] <Node>.pos | pos=(x,y) ...` line every 0.25 s (the
 * Playwright harness has no JS bridge into Godot — this trace is the only
 * way a browser-driven spec can read world-coords). This helper:
 *
 *   1. Parses the latest `Player.pos` and `Shooter.pos` from the capture
 *      buffer.
 *   2. Computes the vector player→Shooter and picks the 1–2 WASD keys that
 *      best match it.
 *   3. **Pursuit burst** — holds those keys to close the gap (player
 *      120 px/s vs Shooter 60 px/s kite, so the gap always shrinks; held
 *      input also overrides projectile knockback every tick).
 *   4. When the Shooter trace reports `dist_to_player` within
 *      `ENGAGE_RANGE`, **engage burst** — hold the steer keys (jamming the
 *      player onto the Shooter, facing it) WHILE click-spamming.
 *   5. Re-reads positions every cycle and re-steers — so when the Shooter
 *      kites to a new heading, the pursuit follows.
 *
 * The pursuit converges because the room is a closed 416×192 box and the
 * player is 2× faster: the Shooter cannot open distance indefinitely, and
 * a player that always steers at the Shooter's *current* position closes
 * in regardless of which way it flees.
 *
 * **Generality:** parameterised by the mob's `posPattern` / `deathPattern`
 * regexes — it handles *any* mob that emits a `.pos` trace, not just Room
 * 04's Shooter. It is invoked by `clearRoomMobs` for every room whose
 * composition includes a Shooter (Rooms 04, 06, 07, 08).
 *
 * **Chase-then-return:** after the kiter dies, the helper walks the player
 * back toward `DEFAULT_PLAYER_SPAWN` — position-steered, same as the
 * pursuit — so the subsequent `gateTraversalWalk` starts from the
 * predictable near-spawn geometry it assumes (see `gate-traversal.ts`
 * preconditions). Without the return leg the player would be left
 * wherever the kill happened and the gate walk would miss the trigger.
 *
 * References:
 *   - scripts/mobs/Shooter.gd — KITE_RANGE / AIM_RANGE / move_speed bands
 *     + the `Shooter.pos` harness trace
 *   - scripts/player/Player.gd — the `Player.pos` harness trace
 *   - tests/playwright/specs/ac4-boss-clear.spec.ts — the calling spec
 *   - tests/playwright/fixtures/gate-traversal.ts — the post-combat walk
 *     that depends on the player being near spawn (chase-then-return)
 *   - .claude/docs/combat-architecture.md §"[combat-trace] diagnostic shim"
 */

import type { Locator, Page } from "@playwright/test";
import type { ConsoleCapture } from "./console-capture";

/** Click cadence between swings — matches `ac4-boss-clear.spec.ts`. */
const ATTACK_INTERVAL_MS = 220;

/**
 * Distance (px) at or below which the helper switches from pure pursuit to
 * the engage burst (hold-toward-mob + click-spam). The player's light-swing
 * reach is ~46 px (LIGHT_REACH 28 + LIGHT_HITBOX_RADIUS 18); 70 px gives
 * margin so the engage burst starts while the player is still closing and
 * the first swings land as the gap shuts to melee.
 */
const ENGAGE_RANGE = 70;

/**
 * Duration of one pursuit-burst movement-key hold. At WALK_SPEED 120 px/s a
 * 450 ms hold covers ~54 px (single axis) / ~38 px per axis (diagonal).
 * Short enough to re-read positions and re-steer often as the Shooter
 * kites; long enough to make real ground against the 60 px/s kite speed.
 */
const PURSUIT_BURST_MS = 450;

/** Settle after a movement burst (lets STATE_ATTACK / velocity clear). */
const SETTLE_MS = 90;

/**
 * Swings per engage burst. The Shooter has 40 HP and the iron sword deals
 * 6/hit → ~7 connecting swings kill it. 5 swings/burst plus the re-steer
 * loop means a Shooter is typically down in 2 engage bursts.
 */
const ENGAGE_SWINGS = 5;

/**
 * Max wall-clock for the post-clear return-to-spawn walk. The return is
 * position-steered and exits early once the player is within
 * `RETURN_ARRIVE_RANGE` of spawn; this cap stops a stuck-against-wall
 * player from burning the rest of the room budget.
 */
const RETURN_MAX_MS = 6_000;

/** Distance (px) from spawn at which the return walk is "close enough". */
const RETURN_ARRIVE_RANGE = 60;

/**
 * Result of a `chaseAndClearKitingMobs` invocation.
 */
export interface KitingChaseResult {
  /** Whether every expected mob's death trace fired within the budget. */
  cleared: boolean;
  /** Count of matching death traces observed during the chase. */
  kills: number;
  /** Wall-clock duration of the helper invocation, in ms. */
  durationMs: number;
}

/**
 * Options for `chaseAndClearKitingMobs`.
 */
export interface KitingChaseOptions {
  /**
   * Regex matching the kiting mob's throttled position trace. Must capture
   * `pos=(x,y)` and (for the kiter) `dist_to_player=N`. Default matches
   * `[combat-trace] Shooter.pos | pos=(x,y) ... dist_to_player=N`.
   */
  posPattern?: RegExp;
  /**
   * Regex matching the kiting mob's death trace. Default matches
   * `[combat-trace] Shooter._die`.
   */
  deathPattern?: RegExp;
  /**
   * Player-position trace regex (must capture `pos=(x,y)`). Default matches
   * `[combat-trace] Player.pos | pos=(x,y) ...`.
   */
  playerPosPattern?: RegExp;
  /**
   * Where to walk the player back to after the last kiter dies — the
   * caller's `gateTraversalWalk` assumes the player is near here. Default:
   * `[240, 200]` (`DEFAULT_PLAYER_SPAWN`).
   */
  returnTo?: [number, number];
  /** Per-room combat budget in ms. Default: 90_000 (matches the spec). */
  budgetMs?: number;
}

/** A parsed `pos=(x,y)` reading from a position trace line. */
interface PosReading {
  x: number;
  y: number;
  /** `dist_to_player` if the line carried it (mob traces), else null. */
  dist: number | null;
}

/** Parse the most recent position trace matching `pattern`, or null. */
function latestPos(
  capture: ConsoleCapture,
  pattern: RegExp
): PosReading | null {
  const lines = capture.getLines();
  for (let i = lines.length - 1; i >= 0; i--) {
    const t = lines[i].text;
    if (!pattern.test(t)) continue;
    const posM = t.match(/pos=\(\s*(-?\d+)\s*,\s*(-?\d+)\s*\)/);
    if (!posM) continue;
    const distM = t.match(/dist_to_player=(-?\d+)/);
    return {
      x: parseInt(posM[1], 10),
      y: parseInt(posM[2], 10),
      dist: distM ? parseInt(distM[1], 10) : null,
    };
  }
  return null;
}

/**
 * Pick the 1–2 WASD keys whose combined direction best matches the vector
 * (dx, dy) in Godot screen-space (x → east, y → SOUTH). Returns `[]` when
 * the vector is ~zero.
 *
 * A key is included when its axis component is a meaningful fraction of the
 * dominant axis — so a near-cardinal vector yields one key and a near-
 * diagonal yields two. This keeps the player steering AT the mob rather
 * than along a fixed 8-way rose.
 */
function keysToward(dx: number, dy: number): string[] {
  const keys: string[] = [];
  const ax = Math.abs(dx);
  const ay = Math.abs(dy);
  if (ax < 4 && ay < 4) return keys;
  const major = Math.max(ax, ay);
  // Include the horizontal key if x is at least ~40% of the dominant axis.
  if (ax >= major * 0.4) keys.push(dx > 0 ? "d" : "a");
  // Include the vertical key if y is at least ~40% of the dominant axis.
  // Godot screen-space: +y is SOUTH ("s"), -y is NORTH ("w").
  if (ay >= major * 0.4) keys.push(dy > 0 ? "s" : "w");
  return keys;
}

/** Hold a set of keys for `ms`, then release them in reverse order. */
async function holdKeys(
  page: Page,
  keys: string[],
  ms: number
): Promise<void> {
  if (keys.length === 0) {
    await page.waitForTimeout(ms);
    return;
  }
  for (const k of keys) await page.keyboard.down(k);
  await page.waitForTimeout(ms);
  for (const k of [...keys].reverse()) await page.keyboard.up(k);
}

/**
 * Pursues and kills one or more kiting mobs (Shooters) by position-steered
 * pursuit, then walks the player back toward `DEFAULT_PLAYER_SPAWN`.
 *
 * Unlike a fixed-position click-spam, this helper reads the mob's throttled
 * `.pos` trace each cycle and steers the player AT the mob's current
 * location — so it converges on a kiter no matter which way it flees.
 *
 * Preconditions:
 *   - Player is at (or near) `DEFAULT_PLAYER_SPAWN = (240, 200)`.
 *   - Canvas has keyboard focus (a prior `canvas.click()` was issued).
 *   - No movement keys are currently held.
 *   - The build emits `Player.pos` / `Shooter.pos` traces (HTML5 release
 *     build — they are no-ops in headless GUT).
 *
 * Postconditions:
 *   - `expectedMobs` matching death traces observed (or the helper throws
 *     with the last 30 trace lines on budget exhaustion).
 *   - Player has been walked back toward `returnTo`, so the caller's
 *     `gateTraversalWalk` starts from predictable geometry.
 *
 * @param page          Playwright page.
 * @param canvas        The game canvas locator.
 * @param capture       ConsoleCapture instance (already attached).
 * @param roomLabel     Log prefix, e.g. "Room 04".
 * @param expectedMobs  Number of kiting mobs to clear in this room.
 * @param clickX        Canvas-relative click X (swing origin).
 * @param clickY        Canvas-relative click Y (swing origin).
 * @param options       Pattern / return / budget tuning.
 */
export async function chaseAndClearKitingMobs(
  page: Page,
  canvas: Locator,
  capture: ConsoleCapture,
  roomLabel: string,
  expectedMobs: number,
  clickX: number,
  clickY: number,
  options: KitingChaseOptions = {}
): Promise<KitingChaseResult> {
  const t0 = Date.now();
  const posPattern = options.posPattern ?? /\[combat-trace\] Shooter\.pos /;
  const deathPattern = options.deathPattern ?? /\[combat-trace\] Shooter\._die/;
  const playerPosPattern =
    options.playerPosPattern ?? /\[combat-trace\] Player\.pos /;
  const returnTo = options.returnTo ?? [240, 200];
  const budgetMs = options.budgetMs ?? 90_000;

  // Count any matching death traces already in the buffer so we only credit
  // kills that happen during THIS room's chase.
  const preDeathCount = capture
    .getLines()
    .filter((l) => deathPattern.test(l.text)).length;
  const killsSoFar = (): number =>
    capture.getLines().filter((l) => deathPattern.test(l.text)).length -
    preDeathCount;

  console.log(
    `[kiting-chase] ${roomLabel}: position-steered pursuit of ` +
      `${expectedMobs} kiting mob(s).`
  );

  let cycle = 0;
  let lastDist = -1;

  while (Date.now() - t0 < budgetMs && killsSoFar() < expectedMobs) {
    cycle++;

    // ---- Read positions, steer toward the (live) kiter ----
    const mob = latestPos(capture, posPattern);
    const player = latestPos(capture, playerPosPattern);

    if (mob === null || player === null) {
      // No fresh position trace yet — give the build a beat to emit one,
      // and nudge with a short click-spam in case a mob is already adjacent.
      await canvas.click({ position: { x: clickX, y: clickY } });
      await page.waitForTimeout(ATTACK_INTERVAL_MS);
      continue;
    }

    const dx = mob.x - player.x;
    const dy = mob.y - player.y;
    // Prefer the kiter trace's own dist_to_player (authoritative); fall back
    // to the computed distance between the two latest readings.
    const dist =
      mob.dist !== null && mob.dist >= 0
        ? mob.dist
        : Math.round(Math.hypot(dx, dy));
    lastDist = dist;
    const steerKeys = keysToward(dx, dy);

    if (cycle === 1 || cycle % 6 === 0) {
      console.log(
        `[kiting-chase] ${roomLabel}: cycle ${cycle} t=${Date.now() - t0}ms ` +
          `player=(${player.x},${player.y}) mob=(${mob.x},${mob.y}) ` +
          `dist=${dist} steer=[${steerKeys.join("+")}] kills=${killsSoFar()}`
      );
    }

    if (dist > ENGAGE_RANGE) {
      // ---- Pursuit burst — close the gap toward the kiter's position ----
      await holdKeys(page, steerKeys, PURSUIT_BURST_MS);
      await page.waitForTimeout(SETTLE_MS);
    } else {
      // ---- Engage burst — jam onto the kiter (held steer keys keep the
      // player pressed against it AND keep `_facing` pointed at it) while
      // click-spamming. Held input overrides projectile knockback so the
      // player stays in swing range for the whole burst.
      for (const k of steerKeys) await page.keyboard.down(k);
      for (let s = 0; s < ENGAGE_SWINGS; s++) {
        await canvas.click({ position: { x: clickX, y: clickY } });
        await page.waitForTimeout(ATTACK_INTERVAL_MS);
        if (killsSoFar() >= expectedMobs) break;
        if (Date.now() - t0 >= budgetMs) break;
      }
      for (const k of [...steerKeys].reverse()) await page.keyboard.up(k);
      await page.waitForTimeout(SETTLE_MS);
    }
  }

  const kills = killsSoFar();
  if (kills < expectedMobs) {
    const recent = capture
      .getLines()
      .slice(-30)
      .map((l) => `  ${l.text}`)
      .join("\n");
    throw new Error(
      `[kiting-chase] ${roomLabel}: only killed ${kills}/${expectedMobs} ` +
        `kiting mob(s) in ${budgetMs}ms (last measured dist=${lastDist}). ` +
        `The position-steered pursuit did not converge — check that the ` +
        `build emits '${posPattern}' / '${playerPosPattern}' traces (HTML5 ` +
        `release build required) and that KITE_RANGE / move_speed in ` +
        `scripts/mobs/Shooter.gd are unchanged.\n` +
        `Last 30 trace lines:\n${recent}`
    );
  }

  console.log(
    `[kiting-chase] ${roomLabel}: cleared ${kills}/${expectedMobs} kiting ` +
      `mob(s) at t=${Date.now() - t0}ms after ${cycle} cycle(s). ` +
      `Returning toward spawn (${returnTo[0]},${returnTo[1]}) for the ` +
      `gate-traversal walk.`
  );

  // ---- Chase-then-RETURN — position-steered walk back toward spawn ----
  // The pursuit left the player wherever the kill happened.
  // gateTraversalWalk assumes the player is near DEFAULT_PLAYER_SPAWN — walk
  // back, steering by the same `Player.pos` trace, exiting early once close.
  const returnStart = Date.now();
  while (Date.now() - returnStart < RETURN_MAX_MS) {
    const player = latestPos(capture, playerPosPattern);
    if (player === null) {
      await page.waitForTimeout(150);
      continue;
    }
    const dx = returnTo[0] - player.x;
    const dy = returnTo[1] - player.y;
    const dist = Math.round(Math.hypot(dx, dy));
    if (dist <= RETURN_ARRIVE_RANGE) {
      console.log(
        `[kiting-chase] ${roomLabel}: back near spawn ` +
          `(player=(${player.x},${player.y}), dist=${dist}).`
      );
      break;
    }
    await holdKeys(page, keysToward(dx, dy), PURSUIT_BURST_MS);
    await page.waitForTimeout(SETTLE_MS);
  }

  return {
    cleared: true,
    kills,
    durationMs: Date.now() - t0,
  };
}
