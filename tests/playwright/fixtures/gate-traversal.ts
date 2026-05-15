/**
 * gate-traversal.ts — RoomGate traversal walk helper for Playwright specs
 *
 * This fixture encodes the harness-side discipline for driving Embergrave's
 * RoomGate state machine through Playwright keyboard input. It is intended
 * to let specs traverse Rooms 02..08 (which all use a RoomGate at
 * world-position (48, 144) with size (48, 80)) end-to-end.
 *
 * **HARNESS COVERAGE GAP — phase boundaries vs gameplay event ordering
 * (ticket 86c9ugfzv, PR #221's surfacing finding):** prior to this fix, the
 * helper assumed the gate was always OPEN with `mobs_alive == 0` when invoked
 * — phase 3's walk-in would fire `body_entered #1` → `lock()` →
 * `_unlock()` synchronously (because `_mobs_alive == 0` triggers the
 * short-circuit). That precondition holds for the "kill mobs first AT spawn,
 * THEN walk to gate" pattern.
 *
 * **It does NOT hold when combat happens NEAR the gate trigger.** In Room 03
 * (the Grunt + Charger chase-combat room), the player drifts INTO the
 * trigger BEFORE the last mob dies. The 86c9ugfzv 8-run sweep empirically
 * confirmed the sequence (every Room 03 trace shows `state=locked` on the
 * very first `_on_mob_died` line — i.e. `lock()` ran before any decrement):
 *   1. **During the room-load / settle window (between Room N-1's
 *      `gate_traversed` and Room N's first `clearRoomMobs` call):** Room N
 *      loads, mobs spawn near the gate, the player's teleport-to-spawn
 *      combined with chase-knockback drifts the player INTO the trigger
 *      → `body_entered #1` fires → state OPEN → `lock()` → state LOCKED
 *      (mobs_alive>0, no unlock yet).
 *   2. Mobs die one-by-one via the deferred `_on_mob_died` decrement chain.
 *   3. When the last mob's decrement lands and `_mobs_alive == 0` with state
 *      == LOCKED, the gate starts its 650ms DEATH_TWEEN_WAIT and then fires
 *      `_unlock()` → state UNLOCKED, `gate_unlocked` emits.
 *   4. `gateTraversalWalk` is then invoked from the spec, but its phase-3
 *      logic assumes the gate is OPEN — it walks into the trigger, sees no
 *      new `gate_unlocked` event (already fired at step 3), and throws.
 *
 * **Symptom:** misleading error "phase 3 fired _on_body_entered but
 * gate_unlocked did NOT follow" — the body_entered seen is actually Room
 * 04's gate firing on the newly-spawned Shooter (because Room 03's gate
 * actually traversed silently when phase 4's east-walk produced a re-entry
 * into the still-UNLOCKED trigger). Not a state-machine regression — the
 * helper just doesn't account for cross-phase `_unlock` events that landed
 * during the spec's preceding combat phase.
 *
 * **The fix (this PR — Drew, ticket 86c9ugfzv):** accept an optional
 * `preRoomLineCount` snapshot from the caller (line count BEFORE
 * clearRoomMobs began) and resolve the room's gate state by scanning the
 * combat-phase trace lines for `_unlock` / `gate_traversed` events. Three
 * outcomes mirror the kiting-mob-chase fixture's case A/B/C resolution:
 *   - Case A: `gate_traversed` already fired during combat → return early
 *     (room counter has advanced; the spec MUST NOT call this helper again
 *     for the same room).
 *   - Case B: `gate_unlocked` fired but no `gate_traversed` → steer
 *     EAST-of-trigger, then walk pure-WEST to fire body_entered →
 *     gate_traversed. Skip the lock-induction phase entirely.
 *   - Case C: neither fired → existing phase 3-5 walk (the open-gate path).
 * See `.claude/docs/combat-architecture.md § "Harness coverage gap —
 * phase boundaries vs gameplay event ordering"` for the broader pattern.
 *
 * **HISTORY — body_entered hypothesis was overturned by Devon's investigation
 * (PR #171, ticket 86c9qbhm5):** Tess PR #170 conjectured that body_entered
 * was not firing under Playwright + Chromium HTML5. Devon's regression canary
 * `tests/playwright/specs/room-gate-body-entered-regression.spec.ts` proved
 * 5/5 reliable firing when the player walks from `DEFAULT_PLAYER_SPAWN =
 * (240, 200)` into Room02's gate via `W 2000ms then N 1500ms`. The real root
 * cause of the AC4 spec's null result was **player drift during long combat
 * in Rooms 02-08** — the prior `clearRoomMobs` helper used an aim-sweep
 * (cycling through 8 directions) plus knockback feedback, which accumulated
 * 100+px of westward+northward displacement before the gate-traversal walk.
 * From the drifted position, the helper's W→N pattern landed against the
 * north/west wall *outside* the trigger rect.
 *
 * **Harness rule that flowed out of the investigation:** combat that
 * precedes a precise spawn-relative walk (like the gate traversal) MUST
 * stay tight — NE-facing only, no aim-sweep — so the player remains within
 * a small radius of `DEFAULT_PLAYER_SPAWN`. AC4's `clearRoomMobs` was
 * updated accordingly. The `gateTraversalWalk` helper now also accepts an
 * optional `expectedSpawn` parameter so the spec can assert "we are still
 * near spawn" via the `[combat-trace] RoomGate._on_body_entered` line — if
 * the body_entered fails to fire, we throw with explicit drift diagnostics
 * instead of silently failing on the gate_unlocked check.
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
  /**
   * Whether a `gate_unlocked` trace was observed for this room's gate. This
   * is `true` if the unlock landed EITHER during the prior combat phase
   * (case A/B — observed in the `preRoomLineCount..helper-entry` slice) OR
   * during the helper's phase-3 walk-in (case C — observed in the
   * phase3Lines slice). Specs asserting causal ordering should compare this
   * against `gateTraversed` AND check the room-scoped trace order via
   * `preRoomUnlockedCount` / `preRoomTraversedCount`.
   */
  gateUnlocked: boolean;
  /** Whether a `gate_traversed` trace was observed for this room's gate. */
  gateTraversed: boolean;
  /**
   * Whether the `RoomGate._on_body_entered` trace fired during phase 3.
   * Devon (PR #171) added this trace at function entry to distinguish
   * "gate never reached" from "gate reached but state-machine wrong"
   * failures. If false, the prior combat phase likely drifted the player
   * away from `DEFAULT_PLAYER_SPAWN` so the W→N walk missed the trigger.
   *
   * Case A/B (cross-phase _unlock detected) callers should NOT assert this
   * is true — the helper short-circuits before phase 3 runs in those cases.
   * Use `resolutionCase` to discriminate.
   */
  bodyEnteredFiredOnPhase3: boolean;
  /**
   * Which case the helper resolved to (ticket 86c9ugfzv):
   *   - `"already-traversed"` (case A): combat-phase auto-unlock AND
   *     auto-traversal observed; helper returned without walking.
   *   - `"unlocked-finish"` (case B): combat-phase auto-unlock observed,
   *     helper steered EAST-of-trigger then walked west to traverse.
   *   - `"open-walk"` (case C): no combat-phase auto-unlock; helper ran
   *     the normal phase 3-5 two-part walk.
   * Defaults to `"open-walk"` when the caller omits `preRoomLineCount`
   * (legacy spec compatibility — see the GateTraversalOptions docstring).
   */
  resolutionCase: "already-traversed" | "unlocked-finish" | "open-walk";
  /** Total wall-clock duration of the helper invocation, in ms. */
  durationMs: number;
}

/**
 * Optional invocation options for `gateTraversalWalk`. Defaults preserve the
 * pre-PR-#171 behaviour; opt-in fields provide defensive coverage against
 * regressions in the calling spec's combat phase.
 */
export interface GateTraversalOptions {
  /**
   * If set, the helper will warn (not fail) if the prior combat phase has
   * pushed the player far from this position. Currently unused at runtime
   * because Playwright cannot read Godot world-coords without a JS bridge —
   * but the parameter is propagated to log lines and the failure message
   * for `_on_body_entered` so failures correlate cleanly back to drift.
   *
   * Format: `Vector2`-style `[x, y]` tuple matching `DEFAULT_PLAYER_SPAWN
   * = (240, 200)`. Pass this from the spec to make drift-related failures
   * self-explanatory; omit for legacy callers.
   */
  expectedSpawn?: [number, number];
  /**
   * Trace-buffer line count BEFORE the room's combat phase began (i.e.
   * before `clearRoomMobs` was called for this room). When provided, the
   * helper scans the slice `[preRoomLineCount, preHelperLineCount)` for
   * `[combat-trace] RoomGate._unlock | gate_unlocked emitting` and
   * `[combat-trace] RoomGate.gate_traversed` events that fired during
   * combat — and routes to one of three cases (A/B/C — see
   * `GateTraversalResult.resolutionCase`).
   *
   * **When to pass this:** rooms where combat happens close enough to the
   * gate trigger that knockback / chase paths can push the player into the
   * trigger zone DURING combat — Room 03 (Grunt + Charger near-spawn melee
   * combat, chaser knockback drifts west into trigger), and defensively
   * any chase-combat room. Pass the spec's `preRoomLineCount` snapshot
   * (captured before `clearRoomMobs` call) and the helper does the rest.
   *
   * **When to omit:** rooms where the combat phase is far from the gate
   * trigger AND can never approach it. The omitted value defaults the
   * helper to its pre-86c9ugfzv behavior (resolutionCase = "open-walk")
   * which assumes case C unconditionally. Legacy callers (pre-86c9ugfzv)
   * keep working without modification.
   *
   * Ticket: 86c9ugfzv (Drew, M2 W3 — AC4 white-whale closer).
   */
  preRoomLineCount?: number;
}

/**
 * Walks the player through a RoomGate using the two-part walk pattern.
 *
 * Preconditions:
 *   - Player is at (or very near) DEFAULT_PLAYER_SPAWN = (240, 200) (i.e.
 *     just after a room load — Main.gd:377 teleports here on every
 *     `_load_room_at_index`). **Devon PR #171 finding:** the calling spec
 *     MUST keep combat tight (NE facing only, no aim-sweep) so the player
 *     stays within ~50px of spawn before invoking this helper. Combat
 *     loops that aim-cycle through 8 directions accumulate 100+px drift
 *     over a 21s clear and the W→N walk lands outside the trigger rect.
 *   - All mobs in the room are dead (`mobs_alive == 0` on the gate). Walking
 *     into the trigger before mobs die would lock the gate and require the
 *     650ms DEATH_TWEEN_WAIT before unlock — handle-able but more fragile.
 *   - Canvas has keyboard focus (a prior `canvas.click()` was issued).
 *   - No other movement keys are currently held.
 *
 * Postconditions:
 *   - `RoomGate._on_body_entered` trace observed during phase 3 (added
 *     by Devon PR #171 at function entry — load-bearing positive signal
 *     that the trigger was reached).
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
  roomLabel: string,
  options: GateTraversalOptions = {}
): Promise<GateTraversalResult> {
  const t0 = Date.now();

  // Snapshot the trace buffer position so we only consider lines emitted
  // by THIS gate's traversal (not stale lines from a prior room).
  const preLineCount = capture.getLines().length;

  // ---- Case A/B/C resolution (ticket 86c9ugfzv) ----
  //
  // When the caller passed `preRoomLineCount`, scan the room-scoped slice
  // for cross-phase `_unlock` / `gate_traversed` events. Three outcomes:
  //
  //   A. Already TRAVERSED — `gate_traversed` fired before the helper was
  //      called. Return immediately. The spec MUST guard against
  //      double-traversal (the room counter has advanced; calling this
  //      helper would operate on the NEXT room's still-LOCKED gate).
  //   B. UNLOCKED but not traversed — `gate_unlocked` fired before the
  //      helper was called but no `gate_traversed`. Steer EAST-of-trigger
  //      (the player may be inside the trigger right now, or anywhere — we
  //      normalise position via key bursts), then walk pure-west to fire
  //      body_entered → gate_traversed on the UNLOCKED gate.
  //   C. Still OPEN — neither fired before the helper. Take the existing
  //      phase 3-5 walk (the open-gate path).
  //
  // **Scan-start computation (ticket 86c9ugfzv N=2 sweep finding):** the
  // first cut of this resolution used `[preRoomLineCount, preLineCount)`
  // — i.e. only events emitted during `clearRoomMobs`. That MISSED gate
  // events that fire BETWEEN the previous room's `gate_traversed` and the
  // current room-loop iteration start (e.g. the 800ms settle window
  // between iterations, during which Room N+1's `_assemble_room_fixtures`
  // runs and the player can drift into the new gate's trigger from the
  // teleport-to-spawn). For Room 03 specifically, every observed run in
  // the first 8-run sweep showed `_on_mob_died` traces with the gate
  // already in `state=locked` at the first mob death — proving
  // `_on_body_entered → lock()` fired BEFORE `preRoomLineCount`. So we
  // expand the scan slice: scan from `[previousRoomGateTraversedIndex+1,
  // preLineCount)` — i.e. everything since the previous gate's traversal
  // (or from 0 if there was no previous gate). That captures the load /
  // settle window AND combat.
  //
  // **Why this resolution lives in the helper, not the spec:** the helper is
  // the single point of truth for "how to make Room N traverse." Every
  // future spec that drives Rooms 02..08 inherits the fix transparently.
  // Putting case resolution at the spec level would require every future
  // AC spec to re-implement the same A/B/C ladder. See the module header
  // for rationale.
  //
  // **Compatibility:** when `preRoomLineCount` is omitted (legacy callers),
  // the resolution scan is skipped and the helper falls through to the
  // existing phase 3-5 path — preserving pre-86c9ugfzv behavior for any
  // spec that hasn't been migrated.
  if (options.preRoomLineCount !== undefined) {
    // Find the most recent `gate_traversed` event STRICTLY before the
    // caller's `preRoomLineCount`. Any `gate_traversed` at-or-after that
    // index would be for THIS room's gate (which is what we're trying to
    // fire) — we don't want to count those.
    const allLines = capture.getLines();
    let lastPreviousTraversedIndex = -1;
    for (let i = options.preRoomLineCount - 1; i >= 0; i--) {
      if (/\[combat-trace\] RoomGate\.gate_traversed/.test(allLines[i].text)) {
        lastPreviousTraversedIndex = i;
        break;
      }
    }
    // Scan from one past the previous traversal (or 0 if no previous gate)
    // through the helper-entry point. This window covers both the
    // room-load / settle period AND `clearRoomMobs`.
    const scanStart = lastPreviousTraversedIndex + 1;
    const combatPhaseSlice = allLines.slice(scanStart, preLineCount);
    console.log(
      `[gate-traversal] ${roomLabel}: scanning slice ` +
        `[${scanStart}, ${preLineCount}) for combat-phase gate events ` +
        `(previous gate_traversed at index ${lastPreviousTraversedIndex}, ` +
        `caller preRoomLineCount=${options.preRoomLineCount}).`
    );
    const combatPhaseUnlocked = combatPhaseSlice.some((l) =>
      /\[combat-trace\] RoomGate\._unlock \| gate_unlocked emitting/.test(
        l.text
      )
    );
    const combatPhaseTraversed = combatPhaseSlice.some((l) =>
      /\[combat-trace\] RoomGate\.gate_traversed/.test(l.text)
    );

    if (combatPhaseTraversed) {
      // ---- Case A: already-traversed ----
      // The chase / knockback path drove the player through the trigger
      // BOTH lock-and-unlock AND traverse during combat. Room counter has
      // advanced. Return immediately so the spec can `continue` its loop.
      console.log(
        `[gate-traversal] ${roomLabel}: case A — gate_unlocked + ` +
          `gate_traversed both fired during combat phase. Room counter ` +
          `has advanced. Returning early (no walk required).`
      );
      return {
        gateUnlocked: true,
        gateTraversed: true,
        bodyEnteredFiredOnPhase3: false,
        resolutionCase: "already-traversed",
        durationMs: Date.now() - t0,
      };
    }

    if (combatPhaseUnlocked) {
      // ---- Case B: unlocked-finish ----
      // Gate is UNLOCKED but not traversed — typically because player
      // drifted into the trigger during combat (firing body_entered #1 →
      // lock()), the last mob died while LOCKED (firing _unlock 650ms
      // later), and the player either stayed inside the trigger or
      // wandered out without re-crossing it. The helper's phase 3 path
      // (assumes OPEN gate, asserts gate_unlocked fires during walk-in)
      // would throw against this state. Instead, steer EAST-of-trigger
      // then walk pure-west across to fire body_entered → gate_traversed.
      //
      // Diagnostic: log the count of gate transitions in the scan slice
      // so future failures can correlate state-machine activity against
      // the chosen resolution case.
      const gateTraceCount = combatPhaseSlice.filter((l) =>
        /\[combat-trace\] RoomGate\./.test(l.text)
      ).length;
      console.log(
        `[gate-traversal] ${roomLabel}: case B — gate_unlocked fired ` +
          `before helper entry but gate_traversed did NOT. ` +
          `${gateTraceCount} RoomGate.* trace(s) in scan slice. ` +
          `Steering EAST-of-trigger then walking WEST in to finish traversal.`
      );
      const traversed = await finishTraversalFromUnlocked(
        page,
        capture,
        roomLabel
      );
      return {
        gateUnlocked: true,
        gateTraversed: traversed,
        bodyEnteredFiredOnPhase3: false,
        resolutionCase: "unlocked-finish",
        durationMs: Date.now() - t0,
      };
    }

    // Fall through to case C: no combat-phase unlock observed.
    console.log(
      `[gate-traversal] ${roomLabel}: case C — no combat-phase ` +
        `gate_unlocked observed. Running the normal phase 3-5 two-part walk.`
    );
  }

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

  // Devon PR #171 added an explicit `_on_body_entered` trace at function
  // entry. It is the load-bearing positive signal that the trigger rect was
  // reached at all. Distinguish three cases:
  //   1. _on_body_entered fired AND gate_unlocked fired → success path.
  //   2. _on_body_entered fired but gate_unlocked didn't → state-machine
  //      regression (gate didn't see mobs_alive==0, or stuck in OPEN).
  //   3. Neither fired → walk didn't reach the trigger. Most common cause
  //      since PR #171: prior combat drifted the player far from spawn.
  const phase3Lines = capture.getLines().slice(preLineCount);
  const bodyEnteredFiredOnPhase3 = phase3Lines.some((l) =>
    /\[combat-trace\] RoomGate\._on_body_entered/.test(l.text)
  );
  const gateUnlocked = phase3Lines.some((l) =>
    /\[combat-trace\] RoomGate\._unlock \| gate_unlocked emitting/.test(l.text)
  );

  if (!bodyEnteredFiredOnPhase3) {
    // The walk didn't reach the trigger at all. Most common cause is player
    // drift from prior combat — the calling spec's combat loop pushed the
    // player far from `DEFAULT_PLAYER_SPAWN` (240, 200) so the W→N walk
    // pattern landed against the room west/north wall outside the trigger.
    //
    // Fix discipline (Devon PR #171 finding 3): combat that precedes a
    // precise spawn-relative walk MUST stay tight — NE-facing only, no
    // aim-sweep — so the player remains near spawn before traversal.
    const recent = capture
      .getLines()
      .slice(-30)
      .map((l) => `  ${l.text}`)
      .join("\n");
    const spawnHint = options.expectedSpawn
      ? ` Helper expected player near spawn ${options.expectedSpawn[0]},${options.expectedSpawn[1]}.`
      : "";
    throw new Error(
      `[gate-traversal] ${roomLabel}: phase 3 walk-in did NOT fire ` +
        `RoomGate._on_body_entered. The player did not reach the gate ` +
        `trigger rect (X∈[24,72], Y∈[104,184]).${spawnHint} ` +
        `\n\n**Most likely cause: player drift during prior combat.** ` +
        `Per Devon's investigation (PR #171), aim-sweep + knockback during ` +
        `extended combat (~21s) accumulates 100+px westward+northward drift, ` +
        `so the W→N walk-in pattern lands against the wall outside the ` +
        `trigger. Devon's regression canary ` +
        `(room-gate-body-entered-regression.spec.ts) confirms body_entered ` +
        `DOES fire reliably (5/5 runs) when the player walks from spawn ` +
        `WITHOUT prior drift. Fix discipline: keep combat tight in the ` +
        `calling spec's clearRoomMobs — NE-facing only, no aim-sweep, ` +
        `click-only — so the player stays within ~50px of spawn.` +
        `\n\nLast 30 trace lines:\n${recent}`
    );
  }

  if (!gateUnlocked) {
    // body_entered fired but the gate didn't unlock. State-machine
    // regression — the gate saw the player but didn't see mobs_alive==0,
    // or got stuck in OPEN with the lock() call short-circuiting wrong.
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
      `[gate-traversal] ${roomLabel}: phase 3 fired _on_body_entered but ` +
        `gate_unlocked did NOT follow. State-machine regression — the gate ` +
        `saw the player but did not transition OPEN → LOCKED → UNLOCKED. ` +
        `Possible causes: mobs_alive>0 (mobs not properly registered or not ` +
        `dying), trigger fired on a non-CharacterBody2D body that bypassed ` +
        `the lock() call, or RoomGate.lock() short-circuit logic regressed.` +
        `\n\nAll RoomGate.* trace lines in buffer:\n${allGateLines || "  (none)"}` +
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
      `(body_entered=${bodyEnteredFiredOnPhase3}, ` +
      `gate_unlocked=${gateUnlocked}, gate_traversed=${gateTraversed}).`
  );

  return {
    gateUnlocked,
    gateTraversed,
    bodyEnteredFiredOnPhase3,
    resolutionCase: "open-walk",
    durationMs,
  };
}

// ---- Case B helper: finish traversal on already-UNLOCKED gate ----
//
// Mirrors `kiting-mob-chase.ts`'s `finishTraversalFromUnlocked` but inlined
// here so this fixture is self-contained and the kiting-chase fixture stays
// private. The behaviour is intentionally identical — the staging point,
// walk geometry, and timeout match — so the two fixtures resolve the same
// state in the same way, just from different invocation contexts.
//
// **Geometry recap** (matches the module header's gate trigger description):
//   - Gate trigger: world `X ∈ [24, 72]`, `Y ∈ [104, 184]`.
//   - Staging point: `(120, 144)` — 48px east of the trigger east edge,
//     vertically centred in the Y-band. Far enough outside the trigger
//     that the player is GUARANTEED to be in the non-overlap state before
//     the walk begins (so `body_entered` fires fresh on the next entry).
//   - Walk: pure WEST for 1100ms → covers ~132px → player crosses the
//     trigger east edge (X=72) at ~t=400ms, firing body_entered →
//     gate_traversed on the UNLOCKED gate.
//
// **Why we don't use position-steering from kiting-mob-chase.ts:** that
// helper needs `Player.pos` traces (HTML5-only, throttled at 0.25s). For
// this case-B path we can rely on a simpler east-walk burst because the
// player's starting position is unknown but bounded — they're somewhere
// in/near the trigger after combat-phase drift. A pure-east burst with
// generous duration drives them past the staging X regardless of starting
// position, and any wall collision pins them against the room east wall
// (X ≈ 304) — well outside the trigger, ready for the pure-west walk-in.

/**
 * East-walk duration to clear the player out of the trigger rect before the
 * traversal walk-in. Generous overshoot: 1500ms at 120px/s = 180px, more
 * than the full ~48-72px westward distance the player could be from the
 * room's east wall after combat. Walls clamp the position so overshoot is
 * harmless (the player ends pinned against X≈304 either way). Mirrors the
 * `WALK_EAST_OUT_OF_GATE_MS` constant in spirit (also east-walk to clear
 * the trigger) but longer because the starting X is less predictable.
 */
const FINISH_STAGE_EAST_WALK_MS = 1_500;

/**
 * Pure-west walk duration for the finish-traversal re-entry. From the
 * staging area (X≈120-304), walking west at 120px/s for 1500ms covers
 * ~180px — the player crosses the trigger's east edge (X=72) en route to
 * X≈0 (clamped against west wall). `body_entered` fires mid-walk →
 * `gate_traversed` emits on the UNLOCKED gate.
 *
 * We deliberately use a generous duration here vs. the
 * `WALK_WEST_BACK_INTO_GATE_MS = 1100ms` from phase 5: phase 5 starts from
 * the helper-controlled (X≈132, Y≈104) position; case B starts from
 * wherever the spec's combat phase left the player, so we need more
 * margin to guarantee crossing the trigger east edge regardless of
 * starting X.
 */
const FINISH_STAGE_WEST_WALK_MS = 1_500;

/**
 * Brief settle between the east-burst and the west-walk. Lets the player's
 * STATE_ATTACK recovery (if any) clear and the body_exited signal land
 * before the next body_entered transition.
 */
const FINISH_STAGE_SETTLE_MS = 300;

async function finishTraversalFromUnlocked(
  page: Page,
  capture: ConsoleCapture,
  roomLabel: string
): Promise<boolean> {
  // Step 1: clear the player OUT of the trigger to the east. Generous
  // overshoot is fine — the room east wall pins the player at X≈304.
  console.log(
    `[gate-traversal] ${roomLabel}: case B step 1 — walk EAST ` +
      `(${FINISH_STAGE_EAST_WALK_MS}ms) to clear player out of trigger ` +
      `before re-entry. Wall-pinning at X≈304 is expected.`
  );
  await page.keyboard.down("d");
  await page.waitForTimeout(FINISH_STAGE_EAST_WALK_MS);
  await page.keyboard.up("d");
  await page.waitForTimeout(FINISH_STAGE_SETTLE_MS);

  // Step 2: pure-WEST walk into trigger. body_entered fires when the player
  // crosses the trigger east edge (X=72). The UNLOCKED gate emits
  // gate_traversed on this single transition (no need for a second walk).
  console.log(
    `[gate-traversal] ${roomLabel}: case B step 2 — walk WEST ` +
      `(${FINISH_STAGE_WEST_WALK_MS}ms) across trigger east edge to fire ` +
      `body_entered → gate_traversed on UNLOCKED gate.`
  );
  await page.keyboard.down("a");
  await page.waitForTimeout(FINISH_STAGE_WEST_WALK_MS);
  await page.keyboard.up("a");

  // Wait for gate_traversed trace. Typical observed latency: 50-200ms
  // after the walk completes.
  try {
    await capture.waitForLine(
      /\[combat-trace\] RoomGate\.gate_traversed/,
      5_000
    );
    console.log(
      `[gate-traversal] ${roomLabel}: case B complete — gate_traversed observed.`
    );
    return true;
  } catch {
    const recent = capture
      .getLines()
      .slice(-30)
      .map((l) => `  ${l.text}`)
      .join("\n");
    console.warn(
      `[gate-traversal] ${roomLabel}: case B finish-traversal did NOT produce ` +
        `a gate_traversed trace within 5s. The east-walk-then-west pattern ` +
        `should reliably cross the trigger. Possible causes: wall geometry ` +
        `regressed, gate state machine regressed, or the player was already ` +
        `past the trigger west edge before the west-walk began.\n\n` +
        `Last 30 trace lines:\n${recent}`
    );
    return false;
  }
}
