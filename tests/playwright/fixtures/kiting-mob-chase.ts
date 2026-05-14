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
 *     *AWAY* from the player at `move_speed` (60 px/s) until distance is
 *     restored above `KITE_RANGE + 16`.
 *   - `KITE_RANGE .. AIM_RANGE` (120..300 px) → the "sweet spot": the
 *     Shooter STANDS STILL and shoots — it does NOT close the gap.
 *   - `dist > AIM_RANGE` (300 px) → the Shooter walks *toward* the player
 *     to re-enter the sweet spot.
 *
 * Room 04 is the only pure-Shooter room. Its single Shooter spawns at tile
 * (12, 3) = world (384, 96) — 144 px east + 104 px north of player spawn
 * (240, 200), i.e. ~178 px away: squarely inside the sweet spot. So the
 * Shooter stands at (384, 96) shooting, never closes, and the player's
 * near-spawn click-spam (swing reach ≈ 46 px) never lands a hit. The AC4
 * spec stalls at "killed 0/1 in 90s".
 *
 * Rooms 05–08 pass only *incidentally*: their Grunts/Chargers keep the
 * player engaged near spawn, and the Shooter gets caught in the swing wedge
 * by luck of geometry as the chasers crowd in. Room 04 has no chaser to
 * provide that cover, so the harness gap is exposed.
 *
 * **The fix — pursue the kiter, pin it against a wall:**
 *
 * The player walks at `WALK_SPEED = 120 px/s` — exactly 2× the Shooter's
 * 60 px/s kite speed — so a pursuit always closes the gap. But Playwright
 * `canvas.click()` stabilization interferes with simultaneously-held
 * movement keys (documented in `ac4-boss-clear.spec.ts` Room 01 notes), so
 * walk and attack cannot be reliably combined. The helper therefore
 * *alternates* short pursuit bursts with short attack bursts:
 *
 *   1. **Pursuit burst** — hold the pursuit direction key(s) for a short
 *      window to close the gap toward the kiter.
 *   2. **Attack burst** — release movement, set facing toward the kiter,
 *      click-spam a few swings.
 *   3. Repeat until the kiter's `_die` trace fires (or the budget expires).
 *
 * **Why pursuit works against a kiter:** every Shooter in Stratum 1 spawns
 * in the EAST half of the room (tile X ≥ 11; room is 15 tiles wide). When
 * the player closes from the west and crosses `KITE_RANGE`, the Shooter
 * kites *directly away* — i.e. EAST — toward the east wall. A
 * `CharacterBody2D` cannot pass the wall, so the kiter gets pinned: it can
 * no longer open distance, the player (2× faster) closes the final gap,
 * and the swing wedge connects. The pursuit is east-dominant with an
 * alternating north/south probe so it covers Shooters that spawn above or
 * below the player's spawn Y.
 *
 * **Generality:** the helper is parameterised by a `pursueKeys` direction
 * and a death-trace `mobPattern` — it handles *any* kiting mob, not just
 * Room 04's Shooter. It is invoked by `clearRoomMobs` for every room whose
 * composition includes a Shooter (Rooms 04, 06, 07, 08).
 *
 * **Chase-then-return:** after the kiter dies, the helper walks the player
 * back WEST toward `DEFAULT_PLAYER_SPAWN` for `returnMs`. This is
 * load-bearing — the subsequent `gateTraversalWalk` assumes the player is
 * within ~50 px of spawn (see `gate-traversal.ts` preconditions). Without
 * the return leg, the pursuit would leave the player pinned against the
 * EAST wall and the gate-traversal W→N walk would start from the wrong
 * geometry and miss the trigger rect entirely.
 *
 * References:
 *   - scripts/mobs/Shooter.gd — KITE_RANGE / AIM_RANGE / move_speed bands
 *   - tests/playwright/specs/ac4-boss-clear.spec.ts — the calling spec
 *   - tests/playwright/fixtures/gate-traversal.ts — the post-combat walk
 *     that depends on the player being near spawn (chase-then-return)
 *   - .claude/docs/combat-architecture.md §"body_entered semantics"
 */

import type { Locator, Page } from "@playwright/test";
import type { ConsoleCapture } from "./console-capture";

/** Click cadence between swings — matches `ac4-boss-clear.spec.ts`. */
const ATTACK_INTERVAL_MS = 220;

/**
 * Duration of one pursuit burst (movement-key hold). At WALK_SPEED 120 px/s
 * a 350 ms burst covers ~42 px on the held axis. Short enough that we
 * re-evaluate (and re-attack) frequently as the kiter repositions; long
 * enough to make real ground against the 60 px/s kite speed.
 */
const PURSUIT_BURST_MS = 350;

/** Settle after a pursuit burst before attacking (lets STATE_ATTACK clear). */
const PURSUIT_SETTLE_MS = 90;

/** Swings per attack burst before the next pursuit burst. */
const ATTACKS_PER_BURST = 3;

/** How long to hold a facing key before an attack burst (facing register). */
const FACING_HOLD_MS = 30;

/**
 * Result of a `chaseAndClearKitingMobs` invocation.
 */
export interface KitingChaseResult {
  /** Whether every expected mob's `_die` trace fired within the budget. */
  cleared: boolean;
  /** Count of matching `_die` traces observed during the chase. */
  kills: number;
  /** Wall-clock duration of the helper invocation, in ms. */
  durationMs: number;
}

/**
 * Options for `chaseAndClearKitingMobs`.
 */
export interface KitingChaseOptions {
  /**
   * Movement keys to hold during a pursuit burst, toward the kiter's spawn
   * region. Every Stratum-1 Shooter spawns EAST of player spawn, so the
   * default is east-dominant. The helper alternates a N/S probe automatically
   * (see `verticalProbe`) so callers normally only need the horizontal key.
   * Default: `["d"]` (pure east).
   */
  pursueKeys?: string[];
  /**
   * If true (default), the pursuit alternates a brief north / south key
   * press between horizontal bursts so the chase covers Shooters that spawn
   * above OR below the player's spawn Y. Set false for a kiter whose Y is
   * known to match spawn.
   */
  verticalProbe?: boolean;
  /**
   * How long (ms) to walk WEST back toward `DEFAULT_PLAYER_SPAWN` after the
   * last kiter dies. Load-bearing for the subsequent `gateTraversalWalk`,
   * which assumes the player is near spawn. Default: 1800 ms (~216 px at
   * WALK_SPEED — enough to undo a full-room east pursuit; the room west
   * wall clamps any overshoot).
   */
  returnMs?: number;
  /** Per-room combat budget in ms. Default: 90_000 (matches the spec). */
  budgetMs?: number;
}

/**
 * Pursues and kills one or more kiting mobs (Shooters), then walks the
 * player back toward `DEFAULT_PLAYER_SPAWN`.
 *
 * Unlike a fixed-position click-spam, this helper *chases* the kiter:
 * alternating pursuit bursts (close the gap) with attack bursts (swing).
 * Because the kiter retreats toward the wall it spawned near, the pursuit
 * pins it and the swing wedge eventually connects.
 *
 * Preconditions:
 *   - Player is at (or near) `DEFAULT_PLAYER_SPAWN = (240, 200)`.
 *   - Canvas has keyboard focus (a prior `canvas.click()` was issued).
 *   - No movement keys are currently held.
 *
 * Postconditions:
 *   - `expectedMobs` matching `<Mob>._die` traces observed (or the helper
 *     throws with the last 30 trace lines on budget exhaustion).
 *   - Player has been walked WEST back toward spawn (`returnMs`), so the
 *     caller's `gateTraversalWalk` starts from predictable geometry.
 *
 * @param page          Playwright page.
 * @param canvas        The game canvas locator.
 * @param capture       ConsoleCapture instance (already attached).
 * @param roomLabel     Log prefix, e.g. "Room 04".
 * @param expectedMobs  Number of kiting mobs to clear in this room.
 * @param clickX        Canvas-relative click X (swing origin).
 * @param clickY        Canvas-relative click Y (swing origin).
 * @param mobPattern    Regex matching the kiter's `_die` trace line.
 * @param options       Pursuit / return tuning (see KitingChaseOptions).
 */
export async function chaseAndClearKitingMobs(
  page: Page,
  canvas: Locator,
  capture: ConsoleCapture,
  roomLabel: string,
  expectedMobs: number,
  clickX: number,
  clickY: number,
  mobPattern: RegExp,
  options: KitingChaseOptions = {}
): Promise<KitingChaseResult> {
  const t0 = Date.now();
  const pursueKeys = options.pursueKeys ?? ["d"];
  const verticalProbe = options.verticalProbe ?? true;
  const returnMs = options.returnMs ?? 1_800;
  const budgetMs = options.budgetMs ?? 90_000;

  // Count any matching _die traces already in the buffer so we only credit
  // kills that happen during THIS room's chase.
  const preDeathCount = capture
    .getLines()
    .filter((l) => mobPattern.test(l.text)).length;

  const killsSoFar = (): number =>
    capture.getLines().filter((l) => mobPattern.test(l.text)).length -
    preDeathCount;

  console.log(
    `[kiting-chase] ${roomLabel}: pursuing ${expectedMobs} kiting mob(s) ` +
      `(pursue=${pursueKeys.join("+")}, verticalProbe=${verticalProbe}).`
  );

  // North/south probe alternates each pursuit cycle so the chase covers
  // Shooters spawned above OR below the player. Pure-horizontal pursuit
  // alone still closes distance (every Shooter is east of spawn) but the
  // probe lets the swing wedge line up vertically too.
  const V_PROBE: string[] = ["w", "s"];
  let cycle = 0;

  while (Date.now() - t0 < budgetMs) {
    // ---- Pursuit burst — close the gap toward the kiter ----
    for (const k of pursueKeys) await page.keyboard.down(k);
    let vProbeKey: string | null = null;
    if (verticalProbe) {
      vProbeKey = V_PROBE[cycle % V_PROBE.length];
      await page.keyboard.down(vProbeKey);
    }
    await page.waitForTimeout(PURSUIT_BURST_MS);
    if (vProbeKey) await page.keyboard.up(vProbeKey);
    for (const k of [...pursueKeys].reverse()) await page.keyboard.up(k);
    await page.waitForTimeout(PURSUIT_SETTLE_MS);
    cycle++;

    if (killsSoFar() >= expectedMobs) break;

    // ---- Attack burst — set facing toward the kiter, click-spam ----
    // Facing is set by a brief pursuit-direction key tap so the swing wedge
    // points at the kiter (east, plus the current vertical probe).
    const facingKeys = vProbeKey ? [...pursueKeys, vProbeKey] : pursueKeys;
    for (const k of facingKeys) await page.keyboard.down(k);
    await page.waitForTimeout(FACING_HOLD_MS);
    for (const k of [...facingKeys].reverse()) await page.keyboard.up(k);
    await page.waitForTimeout(40);

    for (let a = 0; a < ATTACKS_PER_BURST; a++) {
      await canvas.click({ position: { x: clickX, y: clickY } });
      await page.waitForTimeout(ATTACK_INTERVAL_MS);
      if (killsSoFar() >= expectedMobs) break;
    }

    if (killsSoFar() >= expectedMobs) break;
  }

  const kills = killsSoFar();
  if (kills < expectedMobs) {
    // Budget exhausted — surface a meaningful failure with trace context.
    const recent = capture
      .getLines()
      .slice(-30)
      .map((l) => `  ${l.text}`)
      .join("\n");
    throw new Error(
      `[kiting-chase] ${roomLabel}: only killed ${kills}/${expectedMobs} ` +
        `kiting mob(s) in ${budgetMs}ms. The chase-then-return pursuit did ` +
        `not pin the kiter against a wall — check whether the Shooter spawn ` +
        `is east of player spawn (pursueKeys may need adjusting) or whether ` +
        `KITE_RANGE / move_speed changed in scripts/mobs/Shooter.gd.\n` +
        `Last 30 trace lines:\n${recent}`
    );
  }

  console.log(
    `[kiting-chase] ${roomLabel}: cleared ${kills}/${expectedMobs} kiting ` +
      `mob(s) at t=${Date.now() - t0}ms. Returning WEST toward spawn ` +
      `(${returnMs}ms) for the gate-traversal walk.`
  );

  // ---- Chase-then-RETURN — walk back toward DEFAULT_PLAYER_SPAWN ----
  // The pursuit left the player deep in the room's east half (pinned near
  // the kiter against the east wall). gateTraversalWalk assumes the player
  // is near spawn (240, 200) — walk WEST to restore that precondition. The
  // room west wall clamps any overshoot, and gateTraversalWalk's own phase
  // 3a west-walk has ~50px tolerance, so exact landing isn't required.
  await page.keyboard.down("a");
  await page.waitForTimeout(returnMs);
  await page.keyboard.up("a");
  await page.waitForTimeout(150);

  return {
    cleared: true,
    kills,
    durationMs: Date.now() - t0,
  };
}
