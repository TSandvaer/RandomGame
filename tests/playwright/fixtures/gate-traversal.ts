/**
 * gate-traversal.ts — RoomGate traversal walk helper for Playwright specs
 *
 * This fixture encodes the harness-side discipline for driving Embergrave's
 * RoomGate state machine through Playwright keyboard input. It is the load-
 * bearing helper that lets specs traverse Rooms 02..08 (which all use a
 * RoomGate at world-position (48, 144) with size (48, 80)) end-to-end.
 *
 * Why this helper exists (the two failure modes it fixes):
 *
 * 1. **Gate trigger Y-band misses player spawn Y.**
 *    `RoomGate._ensure_collision_shape` constructs a `RectangleShape2D` with
 *    `size = trigger_size` centred on the gate node's position. With
 *    `room_gate_position = (48, 144)` and `room_gate_size = (48, 80)`, the
 *    trigger occupies world-coords `X ∈ [24, 72]` and `Y ∈ [104, 184]`.
 *    The Player spawns at `DEFAULT_PLAYER_SPAWN = (240, 200)` — 16px SOUTH
 *    of the band and 168px EAST of the X range. A pure-west walk from spawn
 *    NEVER intersects the trigger because the spawn Y=200 is below the band.
 *    The player must walk **diagonally NW** (north + west) for both axes to
 *    enter the rectangle.
 *
 * 2. **`RoomGate` state machine requires TWO distinct `body_entered` events.**
 *    State chain (see `scripts/levels/RoomGate.gd`):
 *
 *        OPEN
 *         │  body_entered #1 (CharacterBody2D inside trigger rect)
 *         ▼
 *        LOCKED      ── all mobs dead → DEATH_TWEEN_WAIT_SECS (0.65s) ──┐
 *                                                                       │
 *                                                                       ▼
 *                                                                  UNLOCKED
 *                                                                       │
 *                                                                       │  body_entered #2
 *                                                                       ▼
 *                                                                  gate_traversed
 *
 *    In Godot 4, `body_entered` is a **non-overlap → overlap transition
 *    event**. A continuous walk through the trigger fires `body_entered`
 *    EXACTLY ONCE — not on every physics tick the body remains inside.
 *    To produce two separate events the player must either (a) exit the
 *    trigger between the two entries, or (b) approach the trigger fresh
 *    for the second event after a clean room reload.
 *
 *    **The spec must drive the body OUT (`body_exited`) before re-entering
 *    for the second event.** This is the "two-part walk" pattern below.
 *
 * The two-part walk pattern (kill-first variant — preferred for Playwright
 * because mobs are NE of player spawn, so combat happens away from the
 * gate trigger):
 *
 *   Phase 1 (combat — gate stays OPEN):
 *     Stand near DEFAULT_PLAYER_SPAWN attacking NE; gate is OPEN with
 *     `mobs_alive == N`. No body_entered fires because we never enter the
 *     trigger rect during combat.
 *
 *   Phase 2 (after last mob dies — gate is still OPEN, mobs_alive == 0):
 *     The death-counter logic only runs when state == LOCKED, so dying
 *     mobs while OPEN do NOT advance state. The state chain pivots
 *     differently here — `lock()` short-circuits to `_unlock()` when
 *     entered with mobs_alive==0, but ONLY when triggered by body_entered
 *     transitioning OPEN → LOCKED. So we still need to walk into the
 *     trigger to LOCK + immediately UNLOCK in one event, then walk out
 *     and back in for the gate_traversed event.
 *
 *   Phase 3 (walk-in #1 — fires body_entered #1):
 *     Walk NW from spawn into the gate trigger. `_on_body_entered` sees
 *     state == OPEN, calls `lock()`. `lock()` sees `_mobs_alive <= 0` and
 *     immediately calls `_unlock()` synchronously — state becomes UNLOCKED
 *     and `gate_unlocked` emits. (No DEATH_TWEEN_WAIT delay because mobs
 *     died while in OPEN state — the timer only arms during LOCKED→UNLOCKED.)
 *
 *   Phase 4 (walk-out — fires body_exited):
 *     Walk SE back to spawn area. `body_exited` fires (a no-op on the
 *     gate's signal handlers — but it lets the next body_entered fire).
 *
 *   Phase 5 (walk-in #2 — fires body_entered #2 → gate_traversed):
 *     Walk NW back into the gate trigger. `_on_body_entered` sees state
 *     == UNLOCKED, fires `gate_traversed` exactly once (idempotent guard
 *     `_traversed_emitted`). MultiMobRoom listens here and emits
 *     `room_cleared` → Main loads the next room → player teleported back
 *     to DEFAULT_PLAYER_SPAWN in the new room.
 *
 * **Why kill-first instead of lock-first?** Either order produces a valid
 * traversal (lock → kill → unlock-via-death-wait → traverse OR open →
 * kill → walk-in-locks-and-unlocks-immediately → exit → walk-in-traverses).
 * Kill-first is simpler from a spec perspective:
 *   - Combat happens around spawn position; we don't have to navigate the
 *     player to the gate first while mobs are still attacking.
 *   - We avoid the 650ms DEATH_TWEEN_WAIT delay between gate_unlocked and
 *     traversal-readiness — the gate is already UNLOCKED by the time we
 *     walk in for the second body_entered.
 *   - The negative-assertion sweep (gate_traversed must come after
 *     gate_unlocked) is preserved: the unlock fires on body_entered #1, the
 *     traversal fires on body_entered #2, in correct causal order.
 *
 * Geometry (DEFAULT_PLAYER_SPAWN → gate trigger center):
 *   Player at (240, 200), trigger center at (48, 144). Distance:
 *     dx = -192 (west), dy = -56 (north). Diagonal magnitude ≈ 200px.
 *   Walk speed = 120 px/s (Player.WALK_SPEED). Diagonal walk normalized:
 *     vx = vy = 120 / sqrt(2) ≈ 84.85 px/s on each axis.
 *   Time to traverse 200px diagonal ≈ 200 / 120 ≈ 1.67s.
 *   We use 2400ms (2.4s) to ensure we land deep inside the trigger rect
 *   and don't graze the edge — gives a 730ms safety margin against velocity
 *   loss from wall-sliding or input-lag jitter.
 *
 * References:
 *   - scripts/levels/RoomGate.gd — state machine
 *   - scripts/levels/MultiMobRoom.gd — gate wiring (gate_unlocked → no-op,
 *     gate_traversed → room_cleared.emit())
 *   - scenes/Main.gd:83 — DEFAULT_PLAYER_SPAWN constant
 *   - .claude/docs/combat-architecture.md §"State-change signals vs.
 *     progression triggers"
 */

import type { Locator, Page } from "@playwright/test";
import type { ConsoleCapture } from "./console-capture";

/**
 * How long the player holds the NW (`w` + `a`) keys to walk from
 * DEFAULT_PLAYER_SPAWN deep into the gate trigger rectangle. At 120px/s
 * walk speed the diagonal distance to the trigger center is ~1.67s; 2400ms
 * gives a 730ms margin against velocity loss / input-lag.
 */
export const NW_WALK_INTO_GATE_MS = 2_400;

/**
 * How long the player holds the SE (`s` + `d`) keys to walk back out of
 * the gate trigger and re-establish a non-overlap state, so the next
 * NW walk fires `body_entered` again.
 */
export const SE_WALK_OUT_OF_GATE_MS = 1_200;

/**
 * Settle delay after `body_entered` fires, before driving the next phase.
 * Lets Godot complete the physics-tick deferred frees + signal handlers.
 */
export const PHASE_SETTLE_MS = 200;

/**
 * Result of a `gateTraversalWalk` invocation. Specs typically don't need
 * to inspect this — the helper handles its own internal assertions/logs —
 * but it's returned for advanced use (timing analysis, retry logic).
 */
export interface GateTraversalResult {
  /** Whether the gate_unlocked trace was observed during the walk. */
  gateUnlocked: boolean;
  /** Whether the gate_traversed trace was observed during the walk. */
  gateTraversed: boolean;
  /** Total wall-clock duration of the helper invocation, in ms. */
  durationMs: number;
}

/**
 * Walks the player through a RoomGate using the two-part walk pattern.
 *
 * Preconditions:
 *   - Player is at DEFAULT_PLAYER_SPAWN = (240, 200) (i.e. just after a
 *     room load — Main.gd:377 teleports here on every `_load_room_at_index`).
 *   - All mobs in the room are dead (`mobs_alive == 0` on the gate). Walking
 *     into the trigger before mobs die would lock the gate and require the
 *     650ms DEATH_TWEEN_WAIT before unlock — handle-able but more fragile.
 *   - Canvas has keyboard focus (a prior `canvas.click()` was issued).
 *   - No other movement keys are currently held.
 *
 * Postconditions:
 *   - `gate_unlocked` trace observed in the capture buffer (added during
 *     phase 3's body_entered #1).
 *   - `gate_traversed` trace observed in the capture buffer (added during
 *     phase 5's body_entered #2).
 *   - Room counter has advanced; player will be teleported to spawn in
 *     the next room on the deferred frame following gate_traversed.
 *
 * If the walk does not produce a `gate_traversed` trace within the
 * combined timeout, the helper logs the last 30 trace lines and throws
 * — failure to traverse is a hard test failure, not a soft skip.
 *
 * Helper is parameterized by `roomLabel` (e.g. "Room 02") for log prefixes
 * so multi-room specs can correlate failures back to the room.
 */
export async function gateTraversalWalk(
  page: Page,
  canvas: Locator,
  capture: ConsoleCapture,
  roomLabel: string
): Promise<GateTraversalResult> {
  const t0 = Date.now();

  // Snapshot the trace buffer position so we only consider lines emitted
  // by THIS gate's traversal (not stale lines from a prior room).
  const preLineCount = capture.getLines().length;

  // ---- Phase 3: walk NW into gate trigger (body_entered #1) ----
  //
  // Press 'w' + 'a' simultaneously for a NW walk. Player.gd's input handler
  // normalizes the direction vector, so the walk is a true diagonal.
  console.log(
    `[gate-traversal] ${roomLabel}: phase 3 — walk NW into gate trigger ` +
      `(${NW_WALK_INTO_GATE_MS}ms at 120px/s = ~${Math.round(
        NW_WALK_INTO_GATE_MS / 1000 * 120 / Math.SQRT2
      )}px diagonal travel).`
  );
  await page.keyboard.down("w");
  await page.keyboard.down("a");
  await page.waitForTimeout(NW_WALK_INTO_GATE_MS);
  await page.keyboard.up("w");
  await page.keyboard.up("a");
  await page.waitForTimeout(PHASE_SETTLE_MS);

  // Verify gate_unlocked trace fired (synchronous on body_entered #1 when
  // mobs_alive==0). If not, the walk didn't reach the trigger.
  const phase3Lines = capture.getLines().slice(preLineCount);
  const gateUnlocked = phase3Lines.some((l) =>
    /\[combat-trace\] RoomGate\._unlock \| gate_unlocked emitting/.test(l.text)
  );

  if (!gateUnlocked) {
    const recent = capture.getLines().slice(-30).map((l) => `  ${l.text}`).join("\n");
    throw new Error(
      `[gate-traversal] ${roomLabel}: phase 3 walk-in failed to fire ` +
        `gate_unlocked trace. The player likely didn't reach the gate trigger ` +
        `rect (X∈[24,72], Y∈[104,184]). Either the walk distance is too short ` +
        `or the player got stuck on a wall. Last 30 trace lines:\n${recent}`
    );
  }

  // ---- Phase 4: walk SE out of gate trigger (body_exited) ----
  //
  // Walk back south-east to clear the trigger rect so the next body_entered
  // event can fire. Godot 4: body_entered is a non-overlap → overlap
  // transition; we MUST exit the rect first to re-enter for the second event.
  console.log(
    `[gate-traversal] ${roomLabel}: phase 4 — walk SE out of gate ` +
      `(${SE_WALK_OUT_OF_GATE_MS}ms) to satisfy Godot 4 body_entered ` +
      `non-overlap → overlap semantics.`
  );
  await page.keyboard.down("s");
  await page.keyboard.down("d");
  await page.waitForTimeout(SE_WALK_OUT_OF_GATE_MS);
  await page.keyboard.up("s");
  await page.keyboard.up("d");
  await page.waitForTimeout(PHASE_SETTLE_MS);

  // ---- Phase 5: walk NW back into gate trigger (body_entered #2) ----
  //
  // Second walk-in. Gate state == UNLOCKED, so this fires gate_traversed.
  console.log(
    `[gate-traversal] ${roomLabel}: phase 5 — walk NW back into gate ` +
      `for body_entered #2 → gate_traversed.`
  );
  await page.keyboard.down("w");
  await page.keyboard.down("a");
  await page.waitForTimeout(NW_WALK_INTO_GATE_MS);
  await page.keyboard.up("w");
  await page.keyboard.up("a");

  // Wait for gate_traversed trace (room_cleared fires on this signal,
  // which triggers Main._on_room_cleared → _load_room_at_index(next)).
  // We give it 5s — typical observed: 50-200ms after walk completes.
  let gateTraversed = false;
  try {
    await capture.waitForLine(
      /\[combat-trace\] RoomGate\.gate_traversed/,
      5_000
    );
    gateTraversed = true;
  } catch (e) {
    const recent = capture.getLines().slice(-30).map((l) => `  ${l.text}`).join("\n");
    throw new Error(
      `[gate-traversal] ${roomLabel}: phase 5 walk-in did NOT produce a ` +
        `gate_traversed trace within 5s. Either body_entered #2 didn't fire ` +
        `(player stuck against west wall, never crossed back into trigger) ` +
        `or RoomGate state machine regressed. Last 30 trace lines:\n${recent}`
    );
  }

  const durationMs = Date.now() - t0;
  console.log(
    `[gate-traversal] ${roomLabel}: traversal complete in ${durationMs}ms ` +
      `(gate_unlocked=${gateUnlocked}, gate_traversed=${gateTraversed}).`
  );

  return { gateUnlocked, gateTraversed, durationMs };
}
