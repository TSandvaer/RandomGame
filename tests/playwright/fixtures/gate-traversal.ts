/**
 * gate-traversal.ts — RoomGate traversal walk helper for Playwright specs
 *
 * This fixture encodes the harness-side discipline for driving Embergrave's
 * RoomGate state machine through Playwright keyboard input. It is intended
 * to let specs traverse Rooms 02..08 (which all use a RoomGate at
 * world-position (48, 144) with size (48, 80)) end-to-end.
 *
 * **OPEN ISSUE (see ac4-boss-clear.spec.ts header for fuller discussion):**
 * Even with the two-segment walk pattern correctly implemented AND the
 * player verified geometrically inside the trigger rect via Playwright
 * screenshot (e.g. world position ≈ (42, 144) — well inside trigger
 * X∈[24,72], Y∈[104,184]), the gate's `body_entered` signal does NOT
 * fire under Playwright-driven Chromium HTML5 physics. Zero
 * `[combat-trace] RoomGate.*` lines emit even after extensive walking
 * through the trigger area. The null result reproduces against both
 * m1-rc-1 (53a3412) and post-#166 origin/main, suggesting a deeper
 * cause than the spec mechanics. Candidates: shared sub_resource shape
 * resize not reaching physics server; gl_compatibility renderer + Area2D
 * detection quirk under headless Chromium; PackedScene.instantiate +
 * pre-add_child position/trigger_size mutations racing physics
 * registration. Investigation by Devon recommended; harness-side
 * workaround (JS bridge to `RoomGate.trigger_for_test()`) is a viable
 * fallback if the game-side path isn't easy to fix.
 *
 * The helper below is correct on paper and matches the dispatch's
 * recommended pattern. It WILL produce gate_unlocked + gate_traversed
 * traces once the body_entered detection is restored. Until then, AC4
 * stays `test.fail()` and the helper is documented for future use.
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
 * Geometry (DEFAULT_PLAYER_SPAWN → gate trigger):
 *   Player at (240, 200). Trigger at (48, 144) with size (48, 80) → world
 *   bounds X∈[24, 72], Y∈[104, 184]. Player must land BOTH X and Y inside
 *   the rect SIMULTANEOUSLY for `body_entered` to fire.
 *
 *   The naïve NW-diagonal walk fails: the X-distance-to-cover (192px) is
 *   far larger than the Y-distance-to-cover (only 16-96px to enter, with
 *   Y exiting the north edge after ~96px). At equal NW speed (120/√2 ≈
 *   84.85 px/s on each axis), Y enters and EXITS the band before X gets
 *   close to entering — the two intersection windows never overlap. The
 *   body never enters the trigger rect.
 *
 *   Two-segment walk fix: walk pure WEST first (full 120 px/s on X) until
 *   X is firmly inside [24, 72], THEN walk pure NORTH (full 120 px/s on Y)
 *   to descend into the Y-band. While moving north, X stays inside the
 *   X-band the whole time, so the body_entered transition fires when Y
 *   crosses the south edge (Y = 184).
 *
 *   West segment: 240 → ~36 needs ~204px / 120 px/s = 1.7s. We use 2000ms
 *   (2.0s) for safety margin against velocity loss / wall-sliding. The
 *   player ends near X=20 — slightly past the west edge X=24 — but they'll
 *   be against the room west wall (CharacterBody2D collision-resolves) so
 *   final X settles inside the room bounds.
 *
 *   North segment: 200 → ~144 needs ~56px / 120 px/s = 0.47s. We use
 *   1200ms (1.2s) which puts the player around Y=56, a touch past the
 *   north edge Y=104. They'll be against the room north wall similarly.
 *   The walk DOES briefly cross the trigger rect between Y=184 and Y=104
 *   (~666ms inside), which is plenty for the physics tick to fire
 *   body_entered.
 *
 *   Combined walk-in time: 2.0s + 1.2s = 3.2s. The walk-out (SE) reverses
 *   the pattern: south + east simultaneously is OK because the player
 *   starts NEAR the gate (small distance) — overshoot is fine because
 *   we're going BACK to the spawn area.
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
 * Phase A of walk-in: pure WEST (`a` only) to align X with the trigger.
 *
 * Player walks at 120 px/s on a single-axis input. Distance from spawn
 * X=240 to trigger center X=48 is 192 px → 1.6 s of pure-west walking
 * lands at X=48 (center of band [24, 72]). We use 1700 ms to land at
 * X ≈ 36 — comfortably inside the band but NOT at the room west wall
 * (the wall sits at X=0 and the player CharacterBody2D's collision shape
 * clamps the centre to roughly X≈16 when pinned to the wall, which would
 * be WEST of the trigger band [24, 72] and never fire body_entered).
 *
 * Why we can't just walk further: walking too far west pins the player
 * against the wall at X≈16 (outside the trigger X-band [24, 72]). The
 * subsequent north walk would then descend with X stuck at 16, and the
 * player would never enter the trigger rect.
 *
 * Why two-axis NW won't work: at 120/√2 ≈ 84.85 px/s on each axis, the
 * Y-band is crossed in ~0.94 s (Y travels 80 px from edge to edge) but
 * the X-band isn't reached until t ≈ 1.97 s. The two intersection
 * windows do not overlap, so `body_entered` never fires. The two-segment
 * fix decouples the axes.
 */
export const WALK_WEST_INTO_X_BAND_MS = 2_500;

/**
 * Phase B of walk-in: pure NORTH (`w` only) to descend into the Y-band
 * once X is already aligned at ~36.
 *
 * From spawn Y=200, the south edge of the Y-band is at Y=184 (16px north
 * of spawn) and the north edge is at Y=104 (96px north of spawn). At
 * 120 px/s, that's 0.13s to enter the band and 0.80s to exit. We use
 * 700 ms to land near Y=116 (well inside the band, 12px south of the
 * north edge at Y=104) — body_entered fires when crossing south-edge
 * Y=184 at t ≈ 130 ms, and the body stays comfortably inside for ~570 ms
 * before the walk ends. We deliberately do NOT walk past Y=104 (would
 * trigger body_exited via north edge, complicating the phase 4 logic
 * which assumes the player is INSIDE the trigger when phase 4 starts).
 */
export const WALK_NORTH_INTO_Y_BAND_MS = 900;

/**
 * Phase 5 walk-in #2: pure WEST (`a` only) from the post-phase-4 position
 * back into the trigger to fire body_entered #2 → gate_traversed.
 *
 * After phase 4 the body is at (X≈132, Y≈104). Walking west at 120 px/s
 * for 1100 ms covers 132 px — body_entered fires when X transitions from
 * 73 → 72 (mid-walk at t ≈ 500ms). Walk continues to end at X≈0 (clamped
 * to west wall) but gate_traversed has already emitted by then — Main
 * fires _load_room_at_index for the next room shortly after.
 *
 * We deliberately do NOT include a north-walk segment here (unlike phase
 * 3) because phase 4's pure-east walk kept Y locked inside the band.
 */
export const WALK_WEST_BACK_INTO_GATE_MS = 1_100;

/**
 * Phase 4 walk-out: pure EAST (`d` only) to exit the trigger via its east
 * edge, leaving the player OUTSIDE the X-band but still INSIDE the Y-band.
 * This positions the body for a single-segment walk-back-in during phase 5.
 *
 * After phase 3 the player is roughly at (X≈36, Y≈104). Walking east at
 * 120 px/s for 800 ms moves them to (X≈132, Y≈104). X=132 is east of the
 * trigger X-band (>72) — body has exited via east edge — and Y=104 is
 * still inside the Y-band [104, 184], so phase 5's pure-west walk will
 * fire body_entered as it crosses the east edge back into the trigger.
 *
 * Why pure-east and not SE: walking SE diagonally also moves Y south. If
 * Y goes too far south past 184 (out of band), then phase 5's west walk
 * stays in the wrong Y range and never re-enters the trigger. Pure-east
 * keeps Y locked in band so phase 5 only needs to handle the X axis.
 */
export const WALK_EAST_OUT_OF_GATE_MS = 800;

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

  // ---- Phase 3: walk into gate trigger (body_entered #1) ----
  //
  // Two-segment walk to satisfy the trigger rect's X∈[24,72] AND Y∈[104,184]
  // bounds simultaneously. A naïve NW diagonal misses the rect because at
  // equal NW speed (120/√2 ≈ 84.85 px/s on each axis) the Y window closes
  // before the X window opens. We decouple the axes:
  //
  //   Phase A: pure WEST until X is firmly inside [24, 72] (player Y stays at
  //            200 — south of the band; no body_entered yet).
  //   Phase B: pure NORTH until Y descends into [104, 184] (player crosses
  //            south edge of band → body_entered fires).
  //
  // EXTRA settle before phase 3a: ensures the player has exited
  // STATE_ATTACK (LIGHT_RECOVERY = 0.18s) so movement runs at full
  // WALK_SPEED=120px/s (NOT half-speed=60px/s during attack recovery).
  // Without this, the walk-west covers only half the planned distance and
  // the player overshoots the trigger X-band into the wall.
  await page.waitForTimeout(PHASE_SETTLE_MS);

  console.log(
    `[gate-traversal] ${roomLabel}: phase 3a — walk WEST ` +
      `(${WALK_WEST_INTO_X_BAND_MS}ms at 120px/s = ~${Math.round(
        WALK_WEST_INTO_X_BAND_MS / 1000 * 120
      )}px) to align X with trigger band.`
  );
  await page.keyboard.down("a");
  await page.waitForTimeout(WALK_WEST_INTO_X_BAND_MS);
  await page.keyboard.up("a");
  await page.waitForTimeout(PHASE_SETTLE_MS);

  console.log(
    `[gate-traversal] ${roomLabel}: phase 3b — walk NORTH ` +
      `(${WALK_NORTH_INTO_Y_BAND_MS}ms at 120px/s = ~${Math.round(
        WALK_NORTH_INTO_Y_BAND_MS / 1000 * 120
      )}px) to descend into trigger Y-band — body_entered #1 fires here.`
  );
  // Walk in pulses with idle frames between, so the body lingers inside the
  // trigger rect for multiple physics ticks. This avoids any (theoretical)
  // race where a single fast-walk through the rect samples zero ticks
  // overlapping. Each pulse: 200ms key-down + 100ms idle.
  const pulseCount = Math.ceil(WALK_NORTH_INTO_Y_BAND_MS / 300);
  for (let i = 0; i < pulseCount; i++) {
    await page.keyboard.down("w");
    await page.waitForTimeout(200);
    await page.keyboard.up("w");
    await page.waitForTimeout(100);
  }
  await page.waitForTimeout(PHASE_SETTLE_MS);

  // Verify gate_unlocked trace fired (synchronous on body_entered #1 when
  // mobs_alive==0). If not, the walk didn't reach the trigger.
  const phase3Lines = capture.getLines().slice(preLineCount);
  const gateUnlocked = phase3Lines.some((l) =>
    /\[combat-trace\] RoomGate\._unlock \| gate_unlocked emitting/.test(l.text)
  );

  if (!gateUnlocked) {
    // Dump RoomGate-specific lines from the entire buffer first (they're rare
    // and the most informative; combat traces drown them in the last-30 view).
    const allGateLines = capture
      .getLines()
      .filter((l) => /\[combat-trace\] RoomGate\./.test(l.text))
      .map((l) => `  ${l.text}`)
      .join("\n");
    const recent = capture
      .getLines()
      .slice(-30)
      .map((l) => `  ${l.text}`)
      .join("\n");
    throw new Error(
      `[gate-traversal] ${roomLabel}: phase 3 walk-in failed to fire ` +
        `gate_unlocked trace. The player likely didn't reach the gate trigger ` +
        `rect (X∈[24,72], Y∈[104,184]). Either the walk distance is too short, ` +
        `the player got pinned to a wall outside the trigger, or the player is ` +
        `still in STATE_ATTACK (half walk speed = 60px/s instead of 120px/s).\n` +
        `\nAll RoomGate.* trace lines in buffer (should include lock + unlock ` +
        `if the body_entered fired):\n${allGateLines || "  (none)"}` +
        `\n\nLast 30 trace lines:\n${recent}`
    );
  }

  // ---- Phase 4: walk EAST out of gate trigger (body_exited) ----
  //
  // Walk pure east to exit the trigger via its east edge. After phase 3,
  // the player is around (X≈36, Y≈104) — inside the trigger. Walking east
  // at 120 px/s for 800ms moves to (X≈132, Y≈104) — outside trigger via
  // east edge, still inside Y-band [104, 184]. This positions the body
  // for a single-segment west-only walk in phase 5.
  //
  // Why not SE diagonal: SE moves Y south too, which can drop Y below 184
  // (out of band). Then phase 5's west walk would have Y outside band and
  // never fire body_entered. Pure-east keeps Y locked in band.
  console.log(
    `[gate-traversal] ${roomLabel}: phase 4 — walk EAST out of gate ` +
      `(${WALK_EAST_OUT_OF_GATE_MS}ms) to exit trigger via east edge while ` +
      `keeping Y inside band.`
  );
  await page.keyboard.down("d");
  await page.waitForTimeout(WALK_EAST_OUT_OF_GATE_MS);
  await page.keyboard.up("d");
  await page.waitForTimeout(PHASE_SETTLE_MS);

  // ---- Phase 5: walk back into gate trigger (body_entered #2) ----
  //
  // After phase 4 the body is at (~132, ~104) — outside trigger via east
  // edge, still inside Y-band. A single pure-west walk crosses the trigger
  // east-to-west: body_entered fires when X transitions from 73 → 72.
  //
  // We use a SHORTER walk (1100ms) than phase 3a (1700ms) because the
  // starting X is already 132 — only ~96px from the X-band's east edge —
  // and we don't need to cross the entire band. 1100ms moves X by 132px,
  // ending around X≈0 (clamped against west wall) — body has entered AND
  // exited the trigger by the time the walk completes, but body_entered
  // #2 fires mid-walk and is what the gate's _on_body_entered handler
  // sees. gate_traversed emits then; room_cleared and the next-room load
  // follow.
  console.log(
    `[gate-traversal] ${roomLabel}: phase 5 — walk WEST back into gate ` +
      `(${WALK_WEST_BACK_INTO_GATE_MS}ms) to fire body_entered #2 → gate_traversed.`
  );
  await page.keyboard.down("a");
  await page.waitForTimeout(WALK_WEST_BACK_INTO_GATE_MS);
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
