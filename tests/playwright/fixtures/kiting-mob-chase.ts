/**
 * kiting-mob-chase.ts — Shooter-aware combat sub-helper
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
 *     *directly away from the player's current position* at `move_speed`
 *     (60 px/s) until distance is restored above `KITE_RANGE + 16`.
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
 * **Why the pursuit must be POSITION-STEERED:**
 *
 * The Shooter does not retreat to a *fixed* corner — it kites *directly
 * away from the player's current position*, dynamically. A blind "walk NE"
 * pursuit was empirically observed (diag build, `diag/shooter-chase-
 * positions`) to overshoot: the player jammed into one corner while the
 * Shooter calmly kited to the opposite side of the room at full HP. The
 * pursuit has to TRACK the Shooter, which means the harness must know where
 * the Shooter actually is — and the Playwright harness has no JS bridge into
 * Godot. So `Player.gd` and `Shooter.gd` emit a throttled, HTML5-only
 * `[combat-trace] <Node>.pos | pos=(x,y) ...` line every 0.25 s. This helper
 * parses those, computes the vector player→Shooter, picks the WASD keys
 * that match it, and steers AT the kiter's *live* position — closing in
 * because the room is a closed box and the player (120 px/s) is 2× the
 * Shooter's kite speed.
 *
 * **Why the chase TRAVERSES the gate (and why that is correct):**
 *
 * A kiting Shooter retreats *wherever* the player is not — including into
 * the room's west end, right through the RoomGate trigger rect. The chase
 * therefore *cannot* avoid the gate region: cornering the Shooter often
 * means following it there. Empirically the Shooter will wall-pin itself
 * inside the gate trigger if the player only ever approaches from the east.
 *
 * So the chase does NOT try to dodge the gate. It pursues the Shooter
 * freely, and as the player moves through the room — entering the room
 * (locks the gate), killing the Shooter (the gate auto-unlocks: it was
 * LOCKED and `mobs_alive` hit 0), and walking back out — it naturally
 * drives the gate's full `OPEN → LOCKED → UNLOCKED → traversed` sequence.
 * That is a *valid, causally-ordered* traversal — exactly what a real
 * player does in a Shooter room: kill the kiter while roaming, then walk
 * out the door. The helper detects whether `gate_traversed` fired during
 * the chase and reports it in `KitingChaseResult.gateTraversed`; the
 * calling spec (`ac4-boss-clear.spec.ts`) uses that to SKIP its own
 * `gateTraversalWalk` for the room — the chase already did it — while
 * still asserting the chase produced the correct gate trace sequence.
 *
 * If the chase happens to clear the Shooter *without* ever entering the
 * gate trigger, `gateTraversed` is false and the spec falls back to the
 * normal `gateTraversalWalk` (the gate is still OPEN with `mobs_alive == 0`
 * — the kill-first precondition that helper expects).
 *
 * **Post-chase gate resolution (ticket 86c9u1cy2 — Room 04 determinism):**
 *
 * PR #186 added the chase but left the gate in an indeterminate state, and
 * Room 04 (the only PURE-Shooter room — it has no chaser pre-pass keeping
 * the player near spawn) was ~50% flaky as a direct result. The root cause
 * is that cornering a kiting Shooter routinely walks the player THROUGH the
 * RoomGate trigger while the kiter is alive — so when the chase finishes,
 * the gate is rarely still OPEN. After the kill loop the gate is in exactly
 * one of three states, and pre-fix the helper handled none of them:
 *
 *   A. Already TRAVERSED — `gate_traversed` fired during the chase. (But
 *      the kill loop exits the INSTANT the kiter's `_die` trace appears,
 *      and `_unlock` + `gate_traversed` land several frames LATER via the
 *      deferred `mob_died` decrement — so sampling `gateTraversed`
 *      immediately RACED the state machine. Fix: a bounded
 *      `GATE_SETTLE_WINDOW_MS` poll after the kill loop, before sampling —
 *      early-exits the moment `gate_traversed` is seen.)
 *
 *   B. UNLOCKED but not traversed — the chase entered the trigger, the
 *      kiter died, the gate auto-unlocked, but the player's kill-site
 *      position didn't re-cross the trigger to fire `gate_traversed`. The
 *      caller's fallback `gateTraversalWalk` CANNOT finish this — that
 *      helper is built for an OPEN gate and asserts `gate_unlocked` fires
 *      during its walk-in (against an UNLOCKED gate the walk-in fires
 *      `gate_traversed` straight away and the `gate_unlocked` assertion
 *      throws — this was the exact Room 04 failure shape). Fix:
 *      `finishTraversalFromUnlocked` steers the player just EAST of the
 *      trigger then walks WEST across it, firing the single `body_entered`
 *      the UNLOCKED gate needs for `gate_traversed`.
 *
 *   C. Still OPEN — the chase cleared the kiter WITHOUT ever entering the
 *      trigger. The caller's `gateTraversalWalk` handles this, but it has a
 *      hard precondition: the player is near `DEFAULT_PLAYER_SPAWN =
 *      (240, 200)` (its two-segment W→N walk geometry is computed from that
 *      point — see `fixtures/gate-traversal.ts` header). The chase roamed
 *      the player all over the room. Fix: `returnToSpawn` position-steers
 *      the player back to spawn so the fallback walk is deterministic.
 *
 * All three branches reuse the chase's own `Player.pos`-trace-driven
 * steering (`steerToPoint`). The net contract: `chaseAndClearKitingMobs`
 * always leaves the room in a clean, deterministic state — either
 * `gateTraversed = true` (caller skips `gateTraversalWalk`) or
 * `gateTraversed = false` with the gate OPEN and the player at spawn
 * (caller runs `gateTraversalWalk` from its required position).
 *
 * **Generality:** parameterised by the mob's `posPattern` / `deathPattern`
 * regexes — it handles *any* mob that emits a `.pos` trace, not just Room
 * 04's Shooter. It is invoked by `clearRoomMobs` for every room whose
 * composition includes a Shooter (Rooms 04, 06, 07, 08).
 *
 * References:
 *   - scripts/mobs/Shooter.gd — KITE_RANGE / AIM_RANGE / move_speed bands
 *     + the `Shooter.pos` harness trace
 *   - scripts/player/Player.gd — the `Player.pos` harness trace
 *   - scripts/levels/RoomGate.gd — the gate state machine the chase drives
 *   - tests/playwright/specs/ac4-boss-clear.spec.ts — the calling spec
 *   - tests/playwright/fixtures/gate-traversal.ts — the fallback walk
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
 * 350 ms hold covers ~42 px (single axis) / ~30 px per axis (diagonal).
 * Short enough to re-read positions and re-steer often as the Shooter
 * kites; long enough to make real ground against the 60 px/s kite speed.
 */
const PURSUIT_BURST_MS = 350;

/** Settle after a movement burst (lets STATE_ATTACK / velocity clear). */
const SETTLE_MS = 80;

/**
 * Swings per engage burst. The Shooter has 40 HP and the iron sword deals
 * 6/hit → ~7 connecting swings kill it. 4 swings/burst plus the re-steer
 * loop means a Shooter is typically down in ~2-3 engage bursts, and the
 * burst stays short enough (~0.9 s) that the helper re-reads the kiter's
 * position frequently as it repositions.
 */
const ENGAGE_SWINGS = 4;

/**
 * `Main.gd:83 DEFAULT_PLAYER_SPAWN` — the world position the player is
 * teleported to on every `_load_room_at_index`, and the position
 * `gateTraversalWalk` assumes the player starts from. The post-chase
 * return step steers the player back to within
 * `RETURN_TO_SPAWN_TOLERANCE_PX` of this point so the caller's
 * `gateTraversalWalk` has deterministic W→N walk geometry (ticket
 * 86c9u1cy2).
 */
const DEFAULT_PLAYER_SPAWN = { x: 240, y: 200 };

/**
 * The return-to-spawn step stops once the player is within this many px of
 * `DEFAULT_PLAYER_SPAWN`. `gateTraversalWalk`'s own header documents a
 * ~50px drift tolerance for the W→N walk; 40px gives margin inside that.
 */
const RETURN_TO_SPAWN_TOLERANCE_PX = 40;

/**
 * Hard cap on the return-to-spawn step. The player walks at 120 px/s and
 * the room is a closed box ~320px across — even a worst-case corner-to-
 * spawn return is well under 4s of walking. 8s of wall-clock budget
 * (pursuit bursts + position re-reads + settle) is generous headroom; if
 * the step can't converge in 8s something is wrong (no `Player.pos` trace,
 * player wedged) and the helper logs + returns rather than hanging the
 * spec's 90s room budget.
 */
const RETURN_TO_SPAWN_BUDGET_MS = 8_000;

/**
 * One return-to-spawn movement-burst hold. Shorter than `PURSUIT_BURST_MS`
 * (350ms) because the target (spawn) is stationary — frequent re-reads
 * keep the approach from overshooting a fixed point. 250ms at 120px/s
 * covers ~30px single-axis / ~21px per axis diagonal.
 */
const RETURN_BURST_MS = 250;

/**
 * Window the helper waits AFTER the kill loop for the gate state machine to
 * finish reacting (ticket 86c9u1cy2). The kill loop exits the instant the
 * kiter's `_die` trace appears — but at that moment the gate is typically
 * still LOCKED (the chase walked the player through the trigger while the
 * kiter was alive) with `_mobs_alive` about to hit 0. The deferred
 * `mob_died` decrement, the `_unlock` (`gate_unlocked`), and — because the
 * chase usually leaves the player inside/near the now-unlocked trigger —
 * the `gate_traversed` emission all land over the NEXT several frames.
 *
 * Without this settle window, `gateTraversed` was sampled too early and
 * read `false` even when the gate was about to traverse on its own;
 * `returnToSpawn` then walked the player around while `gate_traversed`
 * fired underneath it, advancing the room counter to the NEXT room and
 * leaving the caller's `gateTraversalWalk` operating on the wrong gate.
 * 2.5s comfortably covers the 0.65s DEATH_TWEEN_WAIT + the deferred
 * decrement + a player-still-coasting re-cross of the trigger; the poll
 * early-exits the moment `gate_traversed` is observed, so a chase that
 * cleanly traversed pays only a few ms here.
 */
const GATE_SETTLE_WINDOW_MS = 2_500;

/** Poll cadence while waiting out `GATE_SETTLE_WINDOW_MS`. */
const GATE_SETTLE_POLL_MS = 100;

/**
 * RoomGate trigger geometry for Rooms 02..08 (world coords). The gate node
 * sits at `(48, 144)` with `trigger_size = (48, 80)` (see
 * `MultiMobRoom.room_gate_position` / `room_gate_size` and the
 * `fixtures/gate-traversal.ts` header) → the RectangleShape2D occupies
 * `X ∈ [24, 72]`, `Y ∈ [104, 184]`. The finish-traversal step steers the
 * player to a staging point just EAST of the rect, then walks WEST into it
 * to fire the single `body_entered` the UNLOCKED gate needs for
 * `gate_traversed`.
 */
const GATE_TRIGGER = { xMin: 24, xMax: 72, yMin: 104, yMax: 184 };

/**
 * Staging point for the finish-traversal step: just EAST of the trigger
 * rect, vertically centred in the Y-band. The player is steered here first
 * (guarantees they are OUTSIDE the trigger so the subsequent west walk
 * produces a fresh non-overlap → overlap `body_entered` transition), then
 * walks pure-west across the rect. X=120 is ~48px east of the rect's east
 * edge (72) — comfortably outside — and Y=144 is the rect's vertical
 * centre.
 */
const FINISH_TRAVERSAL_STAGE = { x: 120, y: 144 };

/** Tolerance (px) for "reached the finish-traversal staging point". */
const FINISH_STAGE_TOLERANCE_PX = 28;

/**
 * Budget for steering the player to `FINISH_TRAVERSAL_STAGE`. Same
 * reasoning as `RETURN_TO_SPAWN_BUDGET_MS` — a closed ~320px room, 120px/s
 * walk; 6s is generous headroom.
 */
const FINISH_STAGE_BUDGET_MS = 6_000;

/**
 * Pure-west walk duration for the finish-traversal re-entry. From the
 * staging X≈120, walking west at 120px/s for 1100ms covers ~132px — the
 * player crosses the trigger's east edge (X=72) at ~t=400ms (firing
 * `body_entered` → `gate_traversed` on the UNLOCKED gate) and ends pinned
 * against the room west wall. Mirrors `gate-traversal.ts`
 * `WALK_WEST_BACK_INTO_GATE_MS`.
 */
const FINISH_TRAVERSAL_WALK_WEST_MS = 1_100;

/**
 * Result of a `chaseAndClearKitingMobs` invocation.
 */
export interface KitingChaseResult {
  /** Whether every expected mob's death trace fired within the budget. */
  cleared: boolean;
  /** Count of matching death traces observed during the chase. */
  kills: number;
  /**
   * Whether the room's `RoomGate` reached `gate_traversed` by the time the
   * helper returned. The chase roams the room freely to corner the kiter,
   * which routinely drives the gate's `OPEN→LOCKED→UNLOCKED` sequence; the
   * helper then finishes the traversal itself when the gate is left
   * UNLOCKED-but-not-traversed (see the "Post-chase gate resolution" note in
   * the module header — ticket 86c9u1cy2). So this is `true` whenever the
   * chase touched the gate at all. When `true`, the calling spec SKIPS its
   * own `gateTraversalWalk` for the room (the gate is already traversed and
   * the room counter has advanced) — see `ac4-boss-clear.spec.ts`. When
   * `false`, the chase never entered the gate, it is still OPEN with
   * `mobs_alive == 0`, and the player has been steered back to
   * `DEFAULT_PLAYER_SPAWN` so the caller's `gateTraversalWalk` runs from its
   * required position.
   */
  gateTraversed: boolean;
  /**
   * Whether a `RoomGate._unlock | gate_unlocked` trace fired during the
   * chase. Always true alongside `gateTraversed` (the gate auto-unlocks
   * when the last registered mob dies while LOCKED); exposed separately so
   * the spec can assert the causal ordering `gate_unlocked` → `gate_traversed`.
   */
  gateUnlocked: boolean;
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
  /** Per-room combat budget in ms. Default: 90_000 (matches the spec). */
  budgetMs?: number;
}

/** A parsed `pos=(x,y)` reading from a position trace line. */
interface PosReading {
  x: number;
  y: number;
  /** `dist_to_player` if the line carried it (mob traces), else null. */
  dist: number | null;
  /** `Date.now()` capture timestamp of the trace line this reading came from. */
  timestamp: number;
}

/**
 * Parse the most recent position trace matching `pattern`, or null.
 *
 * `maxAgeMs` (optional) rejects a reading older than that many ms — a
 * **staleness guard**. A live mob emits its `.pos` trace every
 * `POS_TRACE_INTERVAL` (0.25s); a dead mob's `_physics_process`
 * early-returns on `_is_dead` and stops emitting. Without the guard,
 * `latestPos` keeps returning a DEAD mob's last `.pos` line — frozen at
 * its death position — long after it died, so a multi-mob pursuit would
 * steer at a corpse forever instead of the live mob. With the guard, a
 * stale channel returns null and the caller falls through to a still-live
 * channel (or, if every channel is stale, nudges with a click-spam until a
 * fresh trace lands). Omit `maxAgeMs` for the single-mob kiting chase,
 * where there is only ever one tracked mob and "latest" is unambiguous.
 */
function latestPos(
  capture: ConsoleCapture,
  pattern: RegExp,
  maxAgeMs?: number
): PosReading | null {
  const lines = capture.getLines();
  const now = Date.now();
  for (let i = lines.length - 1; i >= 0; i--) {
    const line = lines[i];
    const t = line.text;
    if (!pattern.test(t)) continue;
    if (maxAgeMs !== undefined && now - line.timestamp > maxAgeMs) {
      // The newest matching line is already older than the staleness
      // window — every earlier line is older still, so bail.
      return null;
    }
    const posM = t.match(/pos=\(\s*(-?\d+)\s*,\s*(-?\d+)\s*\)/);
    if (!posM) continue;
    const distM = t.match(/dist_to_player=(-?\d+)/);
    return {
      x: parseInt(posM[1], 10),
      y: parseInt(posM[2], 10),
      dist: distM ? parseInt(distM[1], 10) : null,
      timestamp: line.timestamp,
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
  // Include the horizontal key if x is at least ~35% of the dominant axis.
  if (ax >= major * 0.35) keys.push(dx > 0 ? "d" : "a");
  // Include the vertical key if y is at least ~35% of the dominant axis.
  // Godot screen-space: +y is SOUTH ("s"), -y is NORTH ("w").
  if (ay >= major * 0.35) keys.push(dy > 0 ? "s" : "w");
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

/** Count capture-buffer lines matching `pattern`. */
function countLines(capture: ConsoleCapture, pattern: RegExp): number {
  return capture.getLines().filter((l) => pattern.test(l.text)).length;
}

const GATE_TRAVERSED_PATTERN = /\[combat-trace\] RoomGate\.gate_traversed/;
const GATE_UNLOCKED_PATTERN =
  /\[combat-trace\] RoomGate\._unlock \| gate_unlocked emitting/;

/**
 * Position-steers the player toward a fixed world point using the same
 * `Player.pos`-trace-driven steering the chase uses. Stops once within
 * `tolerancePx` of the target or `budgetMs` elapses.
 *
 * Best-effort: if no `Player.pos` trace is available or the budget expires
 * before convergence, it logs the shortfall and returns rather than
 * throwing — a slightly-off position still beats a fully-random one, and
 * every caller has its own downstream hard assertion.
 *
 * Returns the final measured distance to the target (px), or `null` if no
 * `Player.pos` reading was ever available.
 */
async function steerToPoint(
  page: Page,
  capture: ConsoleCapture,
  roomLabel: string,
  playerPosPattern: RegExp,
  target: { x: number; y: number },
  tolerancePx: number,
  budgetMs: number,
  burstMs: number,
  label: string
): Promise<number | null> {
  const t0 = Date.now();
  let lastDist: number | null = null;
  let cycle = 0;

  while (Date.now() - t0 < budgetMs) {
    cycle++;
    const player = latestPos(capture, playerPosPattern);
    if (player === null) {
      // No fresh Player.pos trace yet — give the throttled trace (0.25s
      // cadence) a beat to land.
      await page.waitForTimeout(ATTACK_INTERVAL_MS);
      continue;
    }

    const dx = target.x - player.x;
    const dy = target.y - player.y;
    const dist = Math.round(Math.hypot(dx, dy));
    lastDist = dist;

    if (dist <= tolerancePx) {
      console.log(
        `[kiting-chase] ${roomLabel}: ${label} — reached target ` +
          `(${target.x},${target.y}) dist=${dist}px <= ${tolerancePx}px ` +
          `tolerance at t=${Date.now() - t0}ms after ${cycle} cycle(s).`
      );
      return dist;
    }

    // Steer toward the target. `keysToward` returns [] for a ~zero vector,
    // but the tolerance check above catches "close enough" first.
    const steerKeys = keysToward(dx, dy);
    await holdKeys(page, steerKeys, burstMs);
    await page.waitForTimeout(SETTLE_MS);
  }

  // Budget exhausted without converging — best-effort, do not throw.
  console.warn(
    `[kiting-chase] ${roomLabel}: ${label} — did not converge on ` +
      `(${target.x},${target.y}) within ${budgetMs}ms (last dist=` +
      `${lastDist ?? "unknown"}px, ${cycle} cycle(s)). Proceeding anyway — ` +
      `the caller's own assertion is the hard gate. Check that the build ` +
      `emits '${playerPosPattern}' (HTML5 release build required).`
  );
  return lastDist;
}

/**
 * Steers the player back to within `RETURN_TO_SPAWN_TOLERANCE_PX` of
 * `DEFAULT_PLAYER_SPAWN`. Called after the chase clears every mob but the
 * gate was never entered (still OPEN) — so the caller's fallback
 * `gateTraversalWalk` starts from its required spawn-relative position
 * (ticket 86c9u1cy2 — Room 04 determinism).
 */
async function returnToSpawn(
  page: Page,
  capture: ConsoleCapture,
  roomLabel: string,
  playerPosPattern: RegExp
): Promise<number | null> {
  return steerToPoint(
    page,
    capture,
    roomLabel,
    playerPosPattern,
    DEFAULT_PLAYER_SPAWN,
    RETURN_TO_SPAWN_TOLERANCE_PX,
    RETURN_TO_SPAWN_BUDGET_MS,
    RETURN_BURST_MS,
    "return-to-spawn"
  );
}

/**
 * Finishes a traversal on an already-UNLOCKED gate (ticket 86c9u1cy2).
 *
 * **Why this is needed.** Cornering a kiting Shooter routinely walks the
 * player THROUGH the RoomGate trigger while the kiter is alive: the gate
 * goes `OPEN → LOCKED`, and once the kiter dies the gate auto-unlocks
 * (`LOCKED → UNLOCKED`). So when the chase finishes, the gate is frequently
 * already UNLOCKED — it just needs ONE more `body_entered` transition to
 * fire `gate_traversed` (`RoomGate._on_body_entered` emits `gate_traversed`
 * on a single body_entered when `_state == STATE_UNLOCKED`). But the chase's
 * kill-site position rarely lands the player back across the trigger on its
 * own, so `gate_traversed` doesn't fire.
 *
 * The caller's fallback `gateTraversalWalk` CANNOT finish it either — that
 * helper is built for an OPEN gate (its phase-3 asserts `gate_unlocked`
 * fires during the walk-in; against an already-UNLOCKED gate the walk-in
 * fires `gate_traversed` straight away and the `gate_unlocked` assertion
 * throws). So the chase must finish its own traversal.
 *
 * **What it does:** steer the player to `FINISH_TRAVERSAL_STAGE` (just EAST
 * of the trigger rect — guarantees they are OUTSIDE it so the next walk
 * produces a fresh non-overlap → overlap transition), then walk pure-WEST
 * across the rect. `body_entered` fires as the player crosses the east
 * edge → the UNLOCKED gate emits `gate_traversed`.
 *
 * Returns `true` if `gate_traversed` was observed, `false` otherwise. The
 * caller treats a `false` here the same as any other non-traversal — but in
 * practice the staging walk reliably crosses the trigger.
 */
async function finishTraversalFromUnlocked(
  page: Page,
  capture: ConsoleCapture,
  roomLabel: string,
  playerPosPattern: RegExp,
  preTraversedCount: number
): Promise<boolean> {
  console.log(
    `[kiting-chase] ${roomLabel}: gate is UNLOCKED but not yet traversed — ` +
      `finishing the traversal (steer EAST of trigger, then walk WEST in).`
  );

  // Step 1: steer to the staging point just east of the trigger rect.
  await steerToPoint(
    page,
    capture,
    roomLabel,
    playerPosPattern,
    FINISH_TRAVERSAL_STAGE,
    FINISH_STAGE_TOLERANCE_PX,
    FINISH_STAGE_BUDGET_MS,
    RETURN_BURST_MS,
    "finish-traversal staging"
  );
  await page.waitForTimeout(SETTLE_MS);

  // Step 2: walk pure-WEST across the trigger rect — body_entered fires as
  // the player crosses the east edge (X=72), and the UNLOCKED gate emits
  // gate_traversed on that single transition.
  console.log(
    `[kiting-chase] ${roomLabel}: finish-traversal — walk WEST ` +
      `(${FINISH_TRAVERSAL_WALK_WEST_MS}ms) across trigger east edge ` +
      `(X=${GATE_TRIGGER.xMax}) to fire body_entered → gate_traversed.`
  );
  await page.keyboard.down("a");
  await page.waitForTimeout(FINISH_TRAVERSAL_WALK_WEST_MS);
  await page.keyboard.up("a");

  // Wait for the gate_traversed trace (room_cleared fires on it → Main
  // loads the next room). Typical observed latency: 50-200ms after the
  // walk completes.
  let traversed = false;
  try {
    await capture.waitForLine(GATE_TRAVERSED_PATTERN, 5_000);
    traversed = countLines(capture, GATE_TRAVERSED_PATTERN) > preTraversedCount;
  } catch {
    traversed = false;
  }

  if (traversed) {
    console.log(
      `[kiting-chase] ${roomLabel}: finish-traversal complete — ` +
        `gate_traversed observed.`
    );
  } else {
    console.warn(
      `[kiting-chase] ${roomLabel}: finish-traversal walk did NOT produce a ` +
        `gate_traversed trace within 5s. The caller will fall back to ` +
        `gateTraversalWalk — but note that helper expects an OPEN gate, not ` +
        `an UNLOCKED one, so the fallback may also fail. Check the gate ` +
        `trigger geometry constants against scripts/levels/RoomGate.gd.`
    );
  }
  return traversed;
}

/**
 * Pursues and kills one or more kiting mobs (Shooters) by position-steered
 * pursuit. Roams the room freely — cornering a kiter routinely means
 * following it through the RoomGate trigger, which drives the gate's
 * OPEN→LOCKED→UNLOCKED→traversed sequence; the helper detects that and
 * reports it (see `KitingChaseResult.gateTraversed`) so the caller can
 * skip a redundant `gateTraversalWalk`.
 *
 * Preconditions:
 *   - Canvas has keyboard focus (a prior `canvas.click()` was issued).
 *   - No movement keys are currently held.
 *   - The build emits `Player.pos` / `Shooter.pos` traces (HTML5 release
 *     build — they are no-ops in headless GUT).
 *
 * Postconditions (the helper always leaves the room in a deterministic
 * state — see the "Post-chase gate resolution" note in the module header,
 * ticket 86c9u1cy2):
 *   - `expectedMobs` matching death traces observed (or the helper throws
 *     with the last 30 trace lines on budget exhaustion).
 *   - `KitingChaseResult.gateTraversed == true` — the gate is fully
 *     traversed (the chase drove it, or `finishTraversalFromUnlocked`
 *     finished it), the room counter has advanced, and the player is at
 *     the NEXT room's spawn. The caller skips `gateTraversalWalk`.
 *   - `KitingChaseResult.gateTraversed == false` — the chase never entered
 *     the gate; it is still OPEN with `mobs_alive == 0` and the player has
 *     been steered back to within `RETURN_TO_SPAWN_TOLERANCE_PX` of
 *     `DEFAULT_PLAYER_SPAWN`. The caller runs `gateTraversalWalk` from its
 *     required position.
 *
 * @param page          Playwright page.
 * @param canvas        The game canvas locator.
 * @param capture       ConsoleCapture instance (already attached).
 * @param roomLabel     Log prefix, e.g. "Room 04".
 * @param expectedMobs  Number of kiting mobs to clear in this room.
 * @param clickX        Canvas-relative click X (swing origin).
 * @param clickY        Canvas-relative click Y (swing origin).
 * @param options       Pattern / budget tuning.
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
  const budgetMs = options.budgetMs ?? 90_000;

  // Snapshot trace counts so we only credit kills + gate events that happen
  // during THIS room's chase.
  const preDeathCount = countLines(capture, deathPattern);
  const preTraversedCount = countLines(capture, GATE_TRAVERSED_PATTERN);
  const preUnlockedCount = countLines(capture, GATE_UNLOCKED_PATTERN);
  const killsSoFar = (): number =>
    countLines(capture, deathPattern) - preDeathCount;

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

    if (cycle === 1 || cycle % 8 === 0) {
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

  // ---- Gate-settle window — let the gate state machine finish reacting ----
  //
  // The kill loop above exits the INSTANT the kiter's `_die` trace appears.
  // But cornering a kiting Shooter routinely means the chase already walked
  // the player THROUGH the RoomGate trigger while the kiter was still alive
  // — so at kill time the gate is typically LOCKED with `_mobs_alive` about
  // to hit 0. The deferred `mob_died` decrement, the `_unlock`
  // (`gate_unlocked`), and — because the chase usually leaves the player
  // inside/near the now-unlocked trigger — the `gate_traversed` emission
  // all land over the NEXT several frames, AFTER the kill loop has exited.
  //
  // Sampling `gateTraversed` immediately (the pre-fix behaviour) therefore
  // RACES the gate: it could read `false` while `gate_traversed` was a few
  // frames away from firing on its own. The fix waits out a bounded settle
  // window, polling for `gate_traversed`; the wait early-exits the moment
  // the trace is observed, so a clean chase-driven traversal costs only a
  // few ms here. THEN `gateTraversed` is sampled — authoritatively.
  const settleStart = Date.now();
  while (Date.now() - settleStart < GATE_SETTLE_WINDOW_MS) {
    if (countLines(capture, GATE_TRAVERSED_PATTERN) > preTraversedCount) {
      break; // gate traversed on its own — no need to wait the full window
    }
    await page.waitForTimeout(GATE_SETTLE_POLL_MS);
  }

  // ---- Detect the gate's post-chase state, then resolve it ----
  //
  // Cornering a kiting Shooter routinely means following it through the
  // RoomGate trigger rect — which locks the gate (`OPEN → LOCKED`), and once
  // the Shooter dies while LOCKED the gate auto-unlocks (`LOCKED →
  // UNLOCKED`). After the settle window above, the gate is in exactly one
  // of three states; each needs different handling so the caller is left
  // with a clean, deterministic situation (ticket 86c9u1cy2):
  //
  //   A. Already TRAVERSED — `gate_traversed` fired during the chase /
  //      settle. The room counter advanced, the player was teleported to
  //      the NEXT room's spawn. Nothing to do; caller skips gateTraversalWalk.
  //
  //   B. UNLOCKED but not traversed — the chase entered the trigger and the
  //      kiter died, so the gate auto-unlocked, but the player's kill-site
  //      position didn't re-cross the trigger to fire `gate_traversed`.
  //      `gateTraversalWalk` CANNOT finish this — it is built for an OPEN
  //      gate and asserts `gate_unlocked` fires during its walk-in (against
  //      an UNLOCKED gate the walk-in fires `gate_traversed` straight away
  //      and that assertion throws). So the chase finishes its own
  //      traversal: `finishTraversalFromUnlocked` steers east of the
  //      trigger, then walks west across it to fire the single body_entered
  //      the UNLOCKED gate needs. This flips the result to traversed and
  //      the caller skips gateTraversalWalk.
  //
  //   C. Still OPEN — the chase cleared the kiter WITHOUT ever entering the
  //      trigger (`mobs_alive == 0`, state OPEN). The caller's fallback
  //      `gateTraversalWalk` handles this correctly, but it has a hard
  //      precondition: the player is near `DEFAULT_PLAYER_SPAWN = (240,200)`
  //      (its W→N walk geometry is computed from that point). The chase
  //      roamed the player all over the room, so `returnToSpawn` steers
  //      them back before the caller runs gateTraversalWalk.
  //
  // Pre-fix, `chaseAndClearKitingMobs` did NONE of this — it sampled
  // gateTraversed immediately (racing case A vs B) and never repositioned
  // the player (case C ran gateTraversalWalk from a random spot). Room 04
  // (the only pure-Shooter room — it has no chaser pre-pass to keep the
  // player near spawn) was ~50% flaky as the direct result.
  let gateTraversed =
    countLines(capture, GATE_TRAVERSED_PATTERN) > preTraversedCount;
  const gateUnlocked =
    countLines(capture, GATE_UNLOCKED_PATTERN) > preUnlockedCount;

  console.log(
    `[kiting-chase] ${roomLabel}: cleared ${kills}/${expectedMobs} kiting ` +
      `mob(s) at t=${Date.now() - t0}ms after ${cycle} cycle(s) ` +
      `(gateUnlocked=${gateUnlocked}, gateTraversed=${gateTraversed}).`
  );

  if (gateTraversed) {
    // Case A — nothing to do.
  } else if (gateUnlocked) {
    // Case B — gate is UNLOCKED; finish the traversal ourselves.
    gateTraversed = await finishTraversalFromUnlocked(
      page,
      capture,
      roomLabel,
      playerPosPattern,
      preTraversedCount
    );
  } else {
    // Case C — gate still OPEN; reposition the player at spawn so the
    // caller's gateTraversalWalk has deterministic geometry.
    await returnToSpawn(page, capture, roomLabel, playerPosPattern);
  }

  return {
    cleared: true,
    kills,
    gateTraversed,
    gateUnlocked,
    durationMs: Date.now() - t0,
  };
}

// ===========================================================================
// Multi-chaser clear — position-steered pursuit for 3-mob chaser rooms
// (ticket 86c9u05d7 — Room 05+ deterministic clear)
// ===========================================================================
//
// **Why this exists.** `ac4-boss-clear.spec.ts`'s `clearRoomMobs` originally
// cleared chaser rooms (Grunt / Charger) by click-spamming from a FIXED
// position near `DEFAULT_PLAYER_SPAWN` while alternating N/E facing. That
// works for the 2-mob rooms (02, 03) — both chasers crowd the player and sit
// inside the swing wedge. It does NOT work reliably for the 3-mob rooms
// (05–08): with three concurrent chasers, one routinely drifts out of the
// fixed wedge's coverage — knockback from the player's own swings shoves
// mobs apart, the Charger's telegraph→charge cycle parks it outside melee,
// and a Grunt circling to the player's flank is never faced. Tess
// characterised Room 05's clear at 0/3–2/3 across runs via the fixed-position
// path — never a deterministic 3/3.
//
// The fix is the SAME position-steered pursuit `chaseAndClearKitingMobs`
// uses for kiting Shooters, generalised: instead of click-spamming from a
// fixed point, the helper reads every chaser's throttled `.pos` trace
// (`Grunt.pos` / `Charger.pos`, added alongside `Shooter.pos` for this
// ticket) and steers the player AT whichever chaser is currently out of
// swing range — so a drifting mob is pursued and cornered rather than left
// to wander outside the wedge.
//
// **Distinguishing mobs of the same type.** The `.pos` trace carries no
// unique per-instance id — Room 05 has two Grunts emitting the identical
// `Grunt.pos` tag. The helper does NOT try to track individual instances.
// Each cycle it samples the *latest* `Grunt.pos` and the *latest*
// `Charger.pos` line; whichever the engine emitted most recently is, by the
// 0.25s throttle, a live mob (a dead mob's `_physics_process` early-returns
// on `_is_dead` and stops emitting). The helper steers toward the FARTHEST
// live reading (the one drifting out of wedge range — the close ones get
// caught in the wedge during the engage burst anyway) until something is
// within `ENGAGE_RANGE`, then engage-bursts. Kills are counted off the
// uniform `<Mob>._die` death traces, exactly like the spec's own loop. When
// the last chaser dies its `.pos` emissions stop; the loop exits on the
// death-count, not on position.
//
// **Gate handling.** Unlike a kiting Shooter, chasers do NOT retreat through
// the RoomGate trigger — they close toward the player. Pursuit of a chaser
// therefore rarely walks the player through the gate, so this helper does
// NOT drive the gate sequence itself. After the kill loop it position-steers
// the player back to `DEFAULT_PLAYER_SPAWN` (reusing `returnToSpawn`) so the
// caller's `gateTraversalWalk` runs from its required geometry — the gate is
// left OPEN with `mobs_alive == 0`, the kill-first precondition that helper
// expects. The result's `gateTraversed` is therefore always `false` (the
// caller always runs `gateTraversalWalk`); it is kept in the result shape
// for symmetry with `KitingChaseResult` so `clearRoomMobs` can treat both
// helpers uniformly. If a future chaser AI starts retreating through the
// gate, the same case A/B/C resolution as `chaseAndClearKitingMobs` would
// need porting here — for now chasers never do, so the simple
// return-to-spawn is correct and deterministic.

/**
 * Soft staleness signal (ms) for a chaser's `.pos` reading. **Not used to
 * reject readings** — the multi-chaser pursuit identifies the live mob by
 * picking the FRESHEST reading across channels (a corpse never emits again,
 * so it can only fall further behind), which is frame-rate-independent.
 * This constant exists only so the helper can LOG when every channel's
 * latest reading looks old (a useful "is the build emitting `.pos` at all?"
 * tell). A live mob emits `.pos` every `POS_TRACE_INTERVAL` (0.25 *game*-
 * seconds); under Playwright the Godot HTML5 build's physics step runs well
 * below 60Hz during heavy combat, so in WALL-CLOCK time that cadence
 * stretches unpredictably — which is exactly why a fixed rejection window
 * was abandoned (it false-rejected live mobs and stalled combat).
 */
const CHASER_POS_STALENESS_MS = 4_000;

/**
 * Timestamp tie-window (ms) for "freshest reading" target selection. The
 * multi-chaser pursuit targets the chaser whose `.pos` line is newest (a
 * live mob — see the target-selection comment), but two live mobs that both
 * emitted within the same throttle tick have near-equal timestamps. Any
 * reading within `POS_FRESH_TIE_MS` of the newest is treated as an equally-
 * fresh candidate, and the tie is broken toward the CLOSEST — so the helper
 * round-robins facing across all live chasers (newest-emitter first) while
 * still preferring a mob already in melee. 600ms comfortably spans one
 * throttle tick even at a low-but-not-pathological frame rate, without being
 * so wide that a genuine corpse reading (seconds stale) sneaks into the tie.
 */
const POS_FRESH_TIE_MS = 600;

/**
 * Distance (px) beyond which the multi-chaser helper does a hold-burst
 * pursuit toward the closest chaser instead of the stationary facing-tap +
 * click-spam engage. Chasers advance on the player on their own, so this is
 * only hit on a cold-load far spawn or a wall-pinned far cluster — a
 * stationary player would otherwise wait out the budget for a chaser stuck
 * against the opposite wall. 130px is roughly half the room's playable
 * width: a chaser closer than that reliably crowds into a stationary
 * player's wedge within a cycle or two; one farther genuinely needs the
 * player to step toward it. Deliberately well above `ENGAGE_RANGE` (70) so
 * the common case stays stationary (chasers come to you) and the pursuit
 * burst is the rare exception, not the default — holding steer keys at a
 * chaser is what wall-pins the player (see the engage-branch comment).
 */
const MULTI_CHASER_PURSUIT_RANGE = 130;

/**
 * Facing-tap duration (ms) for the multi-chaser stationary engage. 30ms is
 * ~2 physics ticks at 60Hz — long enough to register on the player's
 * `input_dir` for a `_facing` update, short enough that at WALK_SPEED
 * 120px/s the player drifts only ~3.6px (single axis). The player thus
 * holds station while the chasers crowd into the swing wedge. Mirrors the
 * 30ms facing tap the spec's own fixed-position `clearRoomMobs` loop uses.
 */
const CHASER_FACING_TAP_MS = 30;

/**
 * Click-spam swings per multi-chaser engage cycle. Matches the spec's
 * fixed-position `clearRoomMobs` loop (`ATTACKS_PER_FACING = 6`) so the hit
 * cadence is as dense — the helper only changes WHICH way the player faces
 * between bursts, not how often it swings. 6 swings × `ATTACK_INTERVAL_MS`
 * ≈ 1.3s per cycle, then a re-read re-targets the now-closest chaser.
 */
const ENGAGE_SWINGS_CHASER = 6;

/** Default `.pos` / `._die` patterns for the two chaser mob types. */
const GRUNT_POS_PATTERN = /\[combat-trace\] Grunt\.pos /;
const GRUNT_DEATH_PATTERN = /\[combat-trace\] Grunt\._die/;
const CHARGER_POS_PATTERN = /\[combat-trace\] Charger\.pos /;
const CHARGER_DEATH_PATTERN = /\[combat-trace\] Charger\._die/;

/**
 * Options for `chaseAndClearMultiChaserRoom`.
 */
export interface MultiChaserOptions {
  /**
   * Position-trace regexes for every chaser mob type present in the room.
   * Default: `[Grunt.pos, Charger.pos]` — covers Rooms 05–08's chaser
   * composition. Each must capture `pos=(x,y)` and `dist_to_player=N`.
   */
  posPatterns?: RegExp[];
  /**
   * Death-trace regexes for every chaser mob type present in the room.
   * Default: `[Grunt._die, Charger._die]`. Kills are counted off the union
   * of these patterns.
   */
  deathPatterns?: RegExp[];
  /** Player-position trace regex (must capture `pos=(x,y)`). */
  playerPosPattern?: RegExp;
  /** Per-room combat budget in ms. Default: 90_000 (matches the spec). */
  budgetMs?: number;
}

/**
 * Pursues and kills every chaser mob in a multi-chaser room (Rooms 05–08)
 * by position-steered pursuit — the same technique `chaseAndClearKitingMobs`
 * uses for kiting Shooters, generalised to chasers so a chaser that drifts
 * out of the player's fixed swing wedge is pursued and cornered rather than
 * left to wander (ticket 86c9u05d7).
 *
 * Preconditions:
 *   - Canvas has keyboard focus (a prior `canvas.click()` was issued).
 *   - No movement keys are currently held.
 *   - The build emits `Player.pos` + the chasers' `.pos` traces (HTML5
 *     release build — they are no-ops in headless GUT).
 *
 * Postconditions:
 *   - `expectedMobs` matching chaser death traces observed (or the helper
 *     throws with the last 30 trace lines on budget exhaustion).
 *   - The player has been steered back to within
 *     `RETURN_TO_SPAWN_TOLERANCE_PX` of `DEFAULT_PLAYER_SPAWN`, so the
 *     caller's `gateTraversalWalk` runs from its required position.
 *   - `KitingChaseResult.gateTraversed` is always `false` — chasers do not
 *     retreat through the gate, so this helper never drives the gate
 *     sequence; the caller always runs `gateTraversalWalk`. (`gateUnlocked`
 *     is likewise `false`.)
 *
 * @param page          Playwright page.
 * @param canvas        The game canvas locator.
 * @param capture       ConsoleCapture instance (already attached).
 * @param roomLabel     Log prefix, e.g. "Room 05".
 * @param expectedMobs  Number of chaser mobs to clear in this room.
 * @param clickX        Canvas-relative click X (swing origin).
 * @param clickY        Canvas-relative click Y (swing origin).
 * @param options       Pattern / budget tuning.
 */
export async function chaseAndClearMultiChaserRoom(
  page: Page,
  canvas: Locator,
  capture: ConsoleCapture,
  roomLabel: string,
  expectedMobs: number,
  clickX: number,
  clickY: number,
  options: MultiChaserOptions = {}
): Promise<KitingChaseResult> {
  const t0 = Date.now();
  const posPatterns =
    options.posPatterns ?? [GRUNT_POS_PATTERN, CHARGER_POS_PATTERN];
  const deathPatterns =
    options.deathPatterns ?? [GRUNT_DEATH_PATTERN, CHARGER_DEATH_PATTERN];
  const playerPosPattern =
    options.playerPosPattern ?? /\[combat-trace\] Player\.pos /;
  const budgetMs = options.budgetMs ?? 90_000;

  // Snapshot death + gate counts so we only credit kills / gate events that
  // happen during THIS room's chase. `killsSoFar` sums across every chaser
  // death pattern; the gate counts feed the post-chase A/B/C resolution.
  const preDeathCounts = deathPatterns.map((p) => countLines(capture, p));
  const preTraversedCount = countLines(capture, GATE_TRAVERSED_PATTERN);
  const preUnlockedCount = countLines(capture, GATE_UNLOCKED_PATTERN);
  const killsSoFar = (): number =>
    deathPatterns.reduce(
      (sum, p, i) => sum + (countLines(capture, p) - preDeathCounts[i]),
      0
    );

  console.log(
    `[multi-chaser] ${roomLabel}: position-steered pursuit of ` +
      `${expectedMobs} chaser mob(s).`
  );

  let cycle = 0;
  let lastDist = -1;

  while (Date.now() - t0 < budgetMs && killsSoFar() < expectedMobs) {
    cycle++;

    // ---- Read each chaser type's latest position, pick a target ----
    //
    // **Freshness, not a staleness window, identifies the live mob.** A dead
    // mob's `_physics_process` early-returns on `_is_dead` and stops emitting
    // `.pos` — but its last line lingers in the capture buffer frozen at its
    // death position. The earlier approach rejected any reading older than a
    // fixed wall-clock window, but the Godot HTML5 build under Playwright
    // runs the physics step well below 60Hz under a heavy 3-mob load (Room
    // 05's 90s budget saw only ~190 chaser `.pos` traces — effective ~10Hz
    // or worse), so `.pos` cadence stretches unpredictably in WALL-CLOCK
    // time and ANY fixed window either false-rejects live mobs (combat
    // stalls — the helper never re-faces) or admits corpses.
    //
    // Instead: gather the latest reading from EVERY channel regardless of
    // age, but tag each with its capture timestamp. Among them, the reading
    // with the MOST RECENT timestamp is — by construction — a LIVE mob (a
    // corpse never emits again, so a corpse's timestamp can only ever fall
    // further behind a live mob's). Steering toward the freshest reading is
    // therefore always steering toward a live mob, at any frame rate. The
    // staleness window survives only as a soft signal (`CHASER_POS_STALENESS_MS`)
    // to LOG when every channel looks old, never to reject.
    const player = latestPos(capture, playerPosPattern);
    const mobReadings: PosReading[] = [];
    for (const p of posPatterns) {
      const r = latestPos(capture, p);
      if (r !== null) mobReadings.push(r);
    }

    if (player === null || mobReadings.length === 0) {
      // No position trace at all yet — give the build a beat to emit one,
      // and nudge with a short click-spam in case a mob is already adjacent.
      await canvas.click({ position: { x: clickX, y: clickY } });
      await page.waitForTimeout(ATTACK_INTERVAL_MS);
      continue;
    }

    // Distance for each reading: prefer the trace's own dist_to_player
    // (authoritative — the mob computed it against the player's live
    // position at emit time), fall back to the computed gap.
    const withDist = mobReadings.map((m) => {
      const computed = Math.round(
        Math.hypot(m.x - player.x, m.y - player.y)
      );
      const dist =
        m.dist !== null && m.dist >= 0 ? m.dist : computed;
      return { ...m, effDist: dist };
    });

    // Target = the FRESHEST reading (guaranteed a live mob — see above);
    // ties broken toward the CLOSEST. The fixed-position `clearRoomMobs`
    // loop cycled a fixed N→E facing rose, so a chaser that drifted to the
    // player's W or S was never inside the swing wedge; driving facing off
    // the freshest live position fixes exactly that. Re-facing the freshest
    // mob each cycle also naturally round-robins attention across all live
    // chasers — whichever emitted last gets faced next — so no single
    // chaser sits untouched at full HP while the others are whittled (the
    // failure mode of pure target-closest: a 3rd mob never became "closest"
    // and never got hit).
    const newestTs = withDist.reduce(
      (m, r) => Math.max(m, r.timestamp),
      0
    );
    const freshReadings = withDist.filter(
      (r) => newestTs - r.timestamp <= POS_FRESH_TIE_MS
    );
    const target = freshReadings.reduce((a, b) =>
      b.effDist < a.effDist ? b : a
    );

    const dx = target.x - player.x;
    const dy = target.y - player.y;
    const dist = target.effDist;
    lastDist = dist;
    const steerKeys = keysToward(dx, dy);

    if (cycle === 1 || cycle % 8 === 0) {
      const targetAgeMs = Date.now() - target.timestamp;
      const staleNote =
        targetAgeMs > CHASER_POS_STALENESS_MS
          ? ` [WARN target reading ${targetAgeMs}ms old — build emitting .pos?]`
          : "";
      console.log(
        `[multi-chaser] ${roomLabel}: cycle ${cycle} t=${Date.now() - t0}ms ` +
          `player=(${player.x},${player.y}) target=(${target.x},${target.y}) ` +
          `dist=${dist} steer=[${steerKeys.join("+")}] ` +
          `seen=${withDist.length} kills=${killsSoFar()}${staleNote}`
      );
    }

    if (dist > MULTI_CHASER_PURSUIT_RANGE) {
      // ---- Pursuit burst — the closest chaser is genuinely far (the room
      // just loaded, or every chaser is pinned against the far wall). Close
      // the gap with ONE bounded hold-burst toward it, then re-read. This
      // is rare for chasers (they advance on their own); it exists only so
      // a cold-load far spawn or a wall-pinned cluster still gets reached.
      await holdKeys(page, steerKeys, PURSUIT_BURST_MS);
      await page.waitForTimeout(SETTLE_MS);
    } else {
      // ---- Engage — STATIONARY facing-tap + click-spam ----
      //
      // The player stays put and lets the chasers crowd in — exactly what
      // the spec's own fixed-position `clearRoomMobs` loop does for the
      // 2-mob rooms (which it clears in ~10s). The ONLY thing that loop got
      // wrong for a 3-mob room is FACING: it cycled a fixed N→E facing
      // rose, so a chaser that drifted to the player's W or S was never
      // inside the swing wedge. This helper fixes precisely that — and
      // nothing else — by tapping the steer keys toward the *closest* live
      // chaser (read off its `.pos` trace) before each click-spam burst, so
      // the wedge always points at a real mob.
      //
      // Why a short TAP, not held keys: holding steer-toward-mob keys
      // through the burst makes the player chase the mob across the room
      // (the mob backs off on knockback, the player follows, repeat) —
      // observed to roam the player 200+px and either wall-pin it or
      // stretch combat past the 90s budget. A 30ms tap (~2 physics ticks)
      // only updates `_facing`; at WALK_SPEED 120px/s it drifts the player
      // ~3.6px, so the player effectively holds station and the chasers do
      // the closing. `ENGAGE_SWINGS_CHASER` click-spams per cycle keeps the
      // hit cadence as dense as the fixed-position loop's; a second chaser
      // crowding the same wedge is caught by the same swings, and the next
      // cycle re-targets whichever chaser is now closest.
      if (steerKeys.length > 0) {
        for (const k of steerKeys) await page.keyboard.down(k);
        await page.waitForTimeout(CHASER_FACING_TAP_MS);
        for (const k of [...steerKeys].reverse()) await page.keyboard.up(k);
      }
      for (let s = 0; s < ENGAGE_SWINGS_CHASER; s++) {
        await canvas.click({ position: { x: clickX, y: clickY } });
        await page.waitForTimeout(ATTACK_INTERVAL_MS);
        if (killsSoFar() >= expectedMobs) break;
        if (Date.now() - t0 >= budgetMs) break;
      }
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
    // Mob-trace tail — filtered so a flood of Player.pos / swing lines does
    // not push every mob trace out of the 30-line window. Distinguishes
    // "the chasers stopped emitting (froze / never spawned)" from "the
    // chasers are alive and emitting but the pursuit can't reach them".
    const mobTraceTail = capture
      .getLines()
      .filter((l) =>
        /\[combat-trace\] (Grunt|Charger)\.(pos|take_damage|_die)/.test(l.text)
      )
      .slice(-20)
      .map((l) => `  ${l.text}`)
      .join("\n");
    const mobPosCount = posPatterns.reduce(
      (sum, p) => sum + countLines(capture, p),
      0
    );
    // Continuity probe: how many chaser `.pos` traces landed in the LAST
    // 10s of the chase. If kills < expected (a live mob remains) but this
    // is ~0, the surviving mob STOPPED emitting `.pos` — i.e. its
    // `_physics_process` stopped running. That is a GAME-side freeze, not a
    // harness-steering failure (a live mob's `_physics_process` emits `.pos`
    // every 0.25 game-seconds unconditionally). Time-since-last is the
    // age of the newest chaser `.pos` line.
    const nowTs = Date.now();
    const chaserPosLines = capture
      .getLines()
      .filter((l) => /\[combat-trace\] (Grunt|Charger)\.pos /.test(l.text));
    const mobPosLast10s = chaserPosLines.filter(
      (l) => nowTs - l.timestamp <= 10_000
    ).length;
    const newestMobPosAgeMs =
      chaserPosLines.length > 0
        ? nowTs - chaserPosLines[chaserPosLines.length - 1].timestamp
        : -1;
    throw new Error(
      `[multi-chaser] ${roomLabel}: only killed ${kills}/${expectedMobs} ` +
        `chaser mob(s) in ${budgetMs}ms (last measured dist=${lastDist}, ` +
        `${cycle} cycles, ${mobPosCount} total chaser '.pos' traces seen; ` +
        `${mobPosLast10s} in the last 10s; newest chaser '.pos' is ` +
        `${newestMobPosAgeMs}ms old). ` +
        (kills > 0 && mobPosLast10s === 0
          ? `>>> A live mob remains but NO chaser '.pos' traces in the last ` +
            `10s — the surviving mob's _physics_process STOPPED. This is a ` +
            `GAME-side freeze (a live mob emits '.pos' every 0.25 game-sec ` +
            `unconditionally), not a harness-steering failure. <<<\n`
          : "") +
        `The position-steered pursuit did not converge — check that the ` +
        `build emits the chaser '.pos' traces (Grunt.pos / Charger.pos) and ` +
        `'${playerPosPattern}' (HTML5 release build required).\n` +
        `Last 20 chaser mob traces (empty → mobs froze or never spawned):\n` +
        `${mobTraceTail || "  (none)"}\n` +
        `Last 30 trace lines (all tags):\n${recent}`
    );
  }

  console.log(
    `[multi-chaser] ${roomLabel}: cleared ${kills}/${expectedMobs} chaser ` +
      `mob(s) at t=${Date.now() - t0}ms after ${cycle} cycle(s).`
  );

  // ---- Gate-settle window + post-chase gate resolution ----
  //
  // The original assumption — "chasers don't retreat through the gate, so
  // the gate is left OPEN" — is WRONG. Two things drive the gate during a
  // multi-chaser clear: (1) the PLAYER drifts during the engage (facing
  // taps + knockback move it a few px/cycle, and chasers spawning W of
  // spawn pull the engage westward toward the gate), and (2) the gate
  // auto-unlocks (`LOCKED → UNLOCKED`) the instant the last registered mob
  // dies while the player is inside the trigger region. Observed in Room
  // 05: the player drifted west into the trigger during combat, so when the
  // 3rd chaser died the gate went straight to UNLOCKED — and the caller's
  // `gateTraversalWalk` (built for an OPEN gate) then failed phase 3.
  //
  // So the multi-chaser helper resolves the gate exactly like the
  // kiting-Shooter chase does (the same case A/B/C the module header
  // documents) — reusing the very same `finishTraversalFromUnlocked` /
  // `returnToSpawn` steps so the caller is always left with a clean,
  // deterministic situation:
  //
  //   A. Already TRAVERSED — `gate_traversed` fired during the chase /
  //      settle. Nothing to do; caller skips `gateTraversalWalk`.
  //   B. UNLOCKED but not traversed — finish the traversal ourselves
  //      (`finishTraversalFromUnlocked`); flips the result to traversed.
  //   C. Still OPEN — steer the player back to spawn so the caller's
  //      `gateTraversalWalk` has deterministic W→N geometry.
  //
  // The kill loop exits the instant the last `_die` trace appears, but the
  // deferred `mob_died` decrement + `_unlock` + a possible `gate_traversed`
  // land over the next several frames — so poll a bounded settle window
  // before sampling the gate state (early-exits the moment `gate_traversed`
  // is seen).
  const settleStart = Date.now();
  while (Date.now() - settleStart < GATE_SETTLE_WINDOW_MS) {
    if (countLines(capture, GATE_TRAVERSED_PATTERN) > preTraversedCount) {
      break;
    }
    await page.waitForTimeout(GATE_SETTLE_POLL_MS);
  }

  let gateTraversed =
    countLines(capture, GATE_TRAVERSED_PATTERN) > preTraversedCount;
  const gateUnlocked =
    countLines(capture, GATE_UNLOCKED_PATTERN) > preUnlockedCount;

  console.log(
    `[multi-chaser] ${roomLabel}: gate state after settle — ` +
      `gateUnlocked=${gateUnlocked}, gateTraversed=${gateTraversed}.`
  );

  if (gateTraversed) {
    // Case A — nothing to do.
  } else if (gateUnlocked) {
    // Case B — gate is UNLOCKED; finish the traversal ourselves.
    gateTraversed = await finishTraversalFromUnlocked(
      page,
      capture,
      roomLabel,
      playerPosPattern,
      preTraversedCount
    );
  } else {
    // Case C — gate still OPEN; reposition the player at spawn so the
    // caller's gateTraversalWalk has deterministic geometry.
    await returnToSpawn(page, capture, roomLabel, playerPosPattern);
  }

  return {
    cleared: true,
    kills,
    gateTraversed,
    gateUnlocked,
    durationMs: Date.now() - t0,
  };
}
