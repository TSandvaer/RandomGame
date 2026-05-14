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
 * Result of a `chaseAndClearKitingMobs` invocation.
 */
export interface KitingChaseResult {
  /** Whether every expected mob's death trace fired within the budget. */
  cleared: boolean;
  /** Count of matching death traces observed during the chase. */
  kills: number;
  /**
   * Whether a `RoomGate.gate_traversed` trace fired during the chase. The
   * chase roams the room freely to corner the kiter, which routinely drives
   * the gate's full OPEN→LOCKED→UNLOCKED→traversed sequence. When true, the
   * calling spec SKIPS its own `gateTraversalWalk` for the room (the chase
   * already traversed it) — see `ac4-boss-clear.spec.ts`.
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
 * Postconditions:
 *   - `expectedMobs` matching death traces observed (or the helper throws
 *     with the last 30 trace lines on budget exhaustion).
 *   - `KitingChaseResult.gateTraversed` reflects whether the chase drove
 *     the room's gate all the way to `gate_traversed`.
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

  // ---- Detect whether the chase drove the room's gate to traversal ----
  //
  // Cornering a kiting Shooter routinely means following it through the
  // RoomGate trigger rect — which locks the gate (player entered the room),
  // and once the Shooter dies while LOCKED the gate auto-unlocks. If the
  // player then crosses the trigger again it fires `gate_traversed`. That
  // is a valid traversal; the caller skips its own `gateTraversalWalk` when
  // this is true. If the chase cleared the kiter without ever entering the
  // trigger, the gate is still OPEN with `mobs_alive == 0` and the caller
  // falls back to the normal walk.
  const gateTraversed =
    countLines(capture, GATE_TRAVERSED_PATTERN) > preTraversedCount;
  const gateUnlocked =
    countLines(capture, GATE_UNLOCKED_PATTERN) > preUnlockedCount;

  console.log(
    `[kiting-chase] ${roomLabel}: cleared ${kills}/${expectedMobs} kiting ` +
      `mob(s) at t=${Date.now() - t0}ms after ${cycle} cycle(s) ` +
      `(gateUnlocked=${gateUnlocked}, gateTraversed=${gateTraversed}).`
  );

  return {
    cleared: true,
    kills,
    gateTraversed,
    gateUnlocked,
    durationMs: Date.now() - t0,
  };
}

// ===========================================================================
// Drift-recovery for CHASER rooms (ticket 86c9u05d7 — Room 05 blocker)
// ===========================================================================
//
// **Why this exists:** the AC4 spec's `clearRoomMobs` chaser path parks the
// player at a fixed canvas position and click-spams a N/E facing cycle. That
// premise — "every chaser closes into the swing wedge and stays there" — holds
// for a 1–2 chaser room but is fragile for **Room 05** (2 Grunts + 1 Charger):
// with 3 bodies converging, one routinely overshoots the player, circles, or
// gets knocked past the wedge and never re-enters it. The fixed-position spam
// then kills 2/3 and burns the whole 90 s budget on the third —
// `[ac4-boss] Room 05: only killed 2/3 chaser mob(s) in 90000ms`.
//
// **The fix mirrors the kiting-Shooter chase above:** when the chaser loop
// detects a stall (no new kill within a window), it calls
// `recloseToNearestChaser`, which reads the throttled `Grunt.pos` /
// `Charger.pos` traces (added game-side alongside this helper), finds the
// nearest *live, drifted* chaser, and position-steers the player back onto it
// — exactly the `keysToward` pursuit the kiting helper uses, just triggered
// reactively instead of as a pre-pass. A chaser that walks toward the player
// but overshoots/circles gets re-closed rather than abandoned.

/** Max age (ms) for a `<Mob>.pos` reading to count as "this mob is alive". */
const CHASER_POS_FRESH_MS = 700;

/**
 * Duration of one drift-recovery movement-key hold. Matches the kiting
 * helper's `PURSUIT_BURST_MS` rationale — long enough to make ground at
 * WALK_SPEED 120 px/s, short enough to re-read positions and re-steer.
 */
const RECLOSE_BURST_MS = 300;

/** Settle after a recovery burst (lets STATE_ATTACK / velocity clear). */
const RECLOSE_SETTLE_MS = 70;

/** A live-chaser position reading with its parsed source line index + time. */
interface ChaserReading {
  x: number;
  y: number;
  dist: number;
  /** Capture-buffer timestamp of the line this reading came from. */
  timestamp: number;
  /** "Grunt" | "Charger" — for log readability only. */
  kind: string;
}

const CHASER_POS_PATTERN =
  /\[combat-trace\] (Grunt|Charger)\.pos \| pos=\(\s*(-?\d+)\s*,\s*(-?\d+)\s*\).*?dist_to_player=(-?\d+)/;

/**
 * Scan the capture buffer for every `Grunt.pos` / `Charger.pos` reading newer
 * than `CHASER_POS_FRESH_MS`. A dead mob stops emitting its throttled trace,
 * so a *fresh* reading is a reliable "this body is still alive" signal. There
 * is no per-mob instance id in the trace, so readings are de-duplicated by
 * rounded position — two distinct chasers a few px apart still register as
 * two, and the same chaser's repeated readings collapse to its latest.
 */
function freshChaserReadings(capture: ConsoleCapture): ChaserReading[] {
  const now = Date.now();
  const lines = capture.getLines();
  // Map keyed by a coarse position bucket → latest reading in that bucket.
  const byBucket = new Map<string, ChaserReading>();
  for (let i = lines.length - 1; i >= 0; i--) {
    const line = lines[i];
    if (now - line.timestamp > CHASER_POS_FRESH_MS) break; // buffer is time-ordered
    const m = line.text.match(CHASER_POS_PATTERN);
    if (!m) continue;
    const x = parseInt(m[2], 10);
    const y = parseInt(m[3], 10);
    // 24 px bucket ≈ one mob body diameter — keeps two real chasers distinct
    // while collapsing one chaser's jittering readings.
    const bucket = `${Math.round(x / 24)},${Math.round(y / 24)}`;
    if (byBucket.has(bucket)) continue; // already have this bucket's latest
    byBucket.set(bucket, {
      x,
      y,
      dist: parseInt(m[4], 10),
      timestamp: line.timestamp,
      kind: m[1],
    });
  }
  return [...byBucket.values()];
}

/**
 * Result of one `recloseToNearestChaser` invocation.
 */
export interface RecloseResult {
  /** True if a drifted chaser was found and pursued. */
  pursued: boolean;
  /** True if, after the recovery bursts, a chaser is within `engageRange`. */
  inRange: boolean;
  /** The post-recovery distance to the targeted chaser, or -1 if none found. */
  finalDist: number;
  /** Count of chaser death traces observed DURING this recovery pass. */
  killsDuringRecovery: number;
}

/**
 * Reactive drift-recovery step for the chaser-clearing path. Reads the fresh
 * `Grunt.pos` / `Charger.pos` traces, picks the **nearest live chaser that is
 * outside `engageRange`** (the one the fixed-position click-spam is failing to
 * reach — and the cheapest to re-close), position-steers the player onto its
 * live position, then jams onto it with held steer keys + click-spam (the same
 * pursue-then-engage shape as `chaseAndClearKitingMobs`). Loops until a chaser
 * is killed during the pass, all live chasers are back within `engageRange`,
 * or the burst budget is spent.
 *
 * It deliberately targets the *nearest* drifted chaser rather than the
 * furthest: re-closing the nearest one fastest restores the "chaser crowds the
 * player" geometry that lets the normal click-spam finish the rest. The
 * held-steer engage burst keeps the player pressed against the chaser AND
 * keeps `_facing` pointed at it, so the swings land regardless of the caller's
 * N/E facing cycle.
 *
 * Preconditions:
 *   - Canvas has keyboard focus; no movement keys currently held.
 *   - The build emits `Player.pos` + `Grunt.pos` / `Charger.pos` traces (HTML5
 *     release build — no-ops in headless GUT).
 *
 * Postconditions:
 *   - Player has been steered toward (and, when reached, swung at) the
 *     targeted chaser. Movement keys are released on return.
 *   - `RecloseResult` reports whether a chaser is now in range and how many
 *     chaser kills landed during the pass — the caller resumes its click-spam
 *     either way; an unconverged recovery just means the next stall triggers
 *     another recovery pass.
 *
 * @param page         Playwright page.
 * @param canvas       The game canvas locator (swing-click target).
 * @param capture      ConsoleCapture instance (already attached).
 * @param roomLabel    Log prefix, e.g. "Room 05".
 * @param clickX       Canvas-relative click X (swing origin).
 * @param clickY       Canvas-relative click Y (swing origin).
 * @param engageRange  Distance (px) at/below which a chaser is "reachable" by
 *                     click-spam — drifted chasers are those beyond it.
 * @param maxBursts    Burst budget for one recovery pass (caps wall-clock).
 */
export async function recloseToNearestChaser(
  page: Page,
  canvas: Locator,
  capture: ConsoleCapture,
  roomLabel: string,
  clickX: number,
  clickY: number,
  engageRange: number = ENGAGE_RANGE,
  maxBursts: number = 10
): Promise<RecloseResult> {
  const playerPosPattern = /\[combat-trace\] Player\.pos /;
  const chaserDeathPattern =
    /\[combat-trace\] (Grunt|Charger)\._die/;

  const preDeathCount = countLines(capture, chaserDeathPattern);
  const killsDuringRecovery = (): number =>
    countLines(capture, chaserDeathPattern) - preDeathCount;

  let lastDist = -1;
  let pursued = false;

  for (let burst = 0; burst < maxBursts; burst++) {
    if (killsDuringRecovery() > 0) {
      // A kill landed — the drift is resolved (or at least progress is
      // unblocked). Hand back to the caller's click-spam loop.
      break;
    }

    const chasers = freshChaserReadings(capture);
    const player = latestPos(capture, playerPosPattern);

    if (chasers.length === 0 || player === null) {
      // No fresh chaser trace (all dead, or none emitted yet) / no player
      // trace — nothing to recover toward.
      break;
    }

    // Nearest chaser that is OUTSIDE engage range — the one click-spam is
    // failing to reach. If every live chaser is already in range, the stall
    // is not a drift problem; let the caller's click-spam continue.
    const drifted = chasers
      .filter((c) => c.dist > engageRange)
      .sort((a, b) => a.dist - b.dist)[0];

    if (drifted === undefined) {
      const nearest = chasers.sort((a, b) => a.dist - b.dist)[0];
      lastDist = nearest ? nearest.dist : -1;
      break;
    }

    pursued = true;
    lastDist = drifted.dist;

    const dx = drifted.x - player.x;
    const dy = drifted.y - player.y;
    const steerKeys = keysToward(dx, dy);

    console.log(
      `[chaser-recover] ${roomLabel}: burst ${burst + 1}/${maxBursts} ` +
        `player=(${player.x},${player.y}) ${drifted.kind}=(${drifted.x},` +
        `${drifted.y}) dist=${drifted.dist} steer=[${steerKeys.join("+")}] ` +
        `liveChasers=${chasers.length}`
    );

    if (drifted.dist > engageRange) {
      // ---- Pursuit burst — close the gap toward the chaser's position ----
      await holdKeys(page, steerKeys, RECLOSE_BURST_MS);
      await page.waitForTimeout(RECLOSE_SETTLE_MS);
    }

    // ---- Engage burst — jam onto the chaser (held steer keys keep the
    // player pressed against it AND keep `_facing` pointed at it) while
    // click-spamming. Even if the pursuit burst above didn't fully close the
    // gap, a couple of swings here are cheap and land the moment the chaser
    // (which is ALSO closing — it chases) crosses into wedge range.
    for (const k of steerKeys) await page.keyboard.down(k);
    for (let s = 0; s < ENGAGE_SWINGS; s++) {
      await canvas.click({ position: { x: clickX, y: clickY } });
      await page.waitForTimeout(ATTACK_INTERVAL_MS);
      if (killsDuringRecovery() > 0) break;
    }
    for (const k of [...steerKeys].reverse()) await page.keyboard.up(k);
    await page.waitForTimeout(RECLOSE_SETTLE_MS);

    // Re-read: where is the nearest live chaser now?
    const after = freshChaserReadings(capture);
    const nearestAfter = after.sort((a, b) => a.dist - b.dist)[0];
    if (nearestAfter !== undefined) {
      lastDist = nearestAfter.dist;
      if (nearestAfter.dist <= engageRange) {
        console.log(
          `[chaser-recover] ${roomLabel}: chaser back in range ` +
            `(dist=${nearestAfter.dist}) after ${burst + 1} burst(s).`
        );
        return {
          pursued,
          inRange: true,
          finalDist: nearestAfter.dist,
          killsDuringRecovery: killsDuringRecovery(),
        };
      }
    }
  }

  return {
    pursued,
    inRange: lastDist >= 0 && lastDist <= engageRange,
    finalDist: lastDist,
    killsDuringRecovery: killsDuringRecovery(),
  };
}
