/**
 * mouse-facing.ts — Mouse-direction attack helpers (ticket 86c9uthf0)
 *
 * **Why this fixture exists.** PR #255 introduced mouse-direction attacks
 * (Sponsor 2026-05-17): the player's `_facing` is now continuously derived
 * from `get_global_mouse_position() - Player.global_position`, gated by a
 * `MOUSE_FACING_DEADZONE_PX = 8.0` (px) threshold. WASD movement is DECOUPLED
 * from facing entirely — the prior `clearRoom01Dummy.attackSweep` /
 * `ac4-boss-clear.clearRoomMobs` pattern of "hold direction key + click at
 * canvas-center" no longer works, because:
 *
 *   1. The direction key NO LONGER sets `_facing`.
 *   2. The click sends `canvas.click({position: {x, y}})` which BOTH moves the
 *      mouse to that position AND clicks — so the mouse settles at the click
 *      position, and `_facing` is the vector from the player to that position.
 *
 * **Coordinate-model migration — POST-T9 (PR #293; ticket `86c9wjyf3`).**
 *
 * Pre-T9, the Embergrave M1 build had NO Camera2D — the 1280×720 viewport
 * used `stretch=canvas_items` + `aspect=keep` to stretch the 480×270 logical
 * world to fill the screen, and `player.global_position == canvas_pixel
 * 1:1`. This fixture's helpers all assumed that 1:1 mapping.
 *
 * **Post-T9 the assumption breaks.** `CameraDirector` is an autoload that
 * owns a `Camera2D` snap-following the player at `BASELINE_ZOOM = 2.6667`.
 * `Camera2D` applies a transform to `Viewport.canvas_transform` such that:
 *
 *     world = camera.global_position + (canvas_pixel - viewport_center) / zoom
 *     canvas_pixel = (world - camera.global_position) * zoom + viewport_center
 *
 * where `viewport_center = (640, 360)` and `zoom` is the engine-units Camera2D
 * zoom (= `BASELINE_ZOOM * normalized_request`; at default 1.0× request the
 * engine zoom is `2.6667`).
 *
 * **The Tess-PR-#293 regression.** Tests 21/23/25 of `mouse-direction-attacks.spec.ts`
 * regressed because they computed `targetX = playerX + AIM_OFFSET_PX` on the
 * raw world coord and passed THAT as a canvas-pixel position. With the camera
 * now centering the player at canvas (640, 360), canvas (440, 200) does NOT
 * map to "200 px east of the player in world space" — it maps to world
 * (165, 140), which is SW of the player at (240, 200). The fix is to translate
 * the desired WORLD target through the camera transform BEFORE clicking.
 *
 * **The fix shape — HARD RULE for ALL future Playwright specs that rely on
 * mouse-direction attacks:**
 *
 *   - Helpers in this module compute click positions in WORLD coords, then
 *     apply `worldToCanvas(...)` using the latest `[combat-trace]
 *     CameraDirector.state | zoom=<v> pos=(<x>,<y>)` line.
 *   - Specs that want a particular swing direction PASS A `ConsoleCapture`
 *     to the helper so the live camera state can be read.
 *   - Direct `canvas.click({position: {x, y}})` calls with raw world coords
 *     are a regression — the click hits the wrong canvas pixel, swing fires
 *     in a direction unrelated to the spec's intent.
 *
 * **Helpers in this module:**
 *
 *   - `clickAimedAtSpawn(canvas, capture, direction, options)` — clicks at a
 *     fixed WORLD offset from `DEFAULT_PLAYER_SPAWN = (240, 200)` in the named
 *     direction, then translates through the camera transform. Workhorse for
 *     room-clearing helpers (room01-traversal, AC4 per-room loop) where the
 *     player stays near spawn throughout combat.
 *
 *   - `clickAtWorldPos(canvas, capture, worldX, worldY)` — clicks at a literal
 *     Godot world coordinate, translated through the camera transform. Use
 *     when the target's world position is known (e.g. PracticeDummy).
 *
 *   - `clickAimedFromPlayer(canvas, capture, direction, options)` — reads the
 *     latest `[combat-trace] Player.pos | pos=(x,y)` line, then clicks at a
 *     directional WORLD offset from THAT live position. Use when the player
 *     has roamed from spawn (multi-chaser pursuit, post-chase follow-up).
 *     Falls back to spawn if no Player.pos trace is available.
 *
 *   - `aimAtWorldPos(page, canvas, capture, worldX, worldY)` — moves the
 *     mouse without clicking. Use when you need the mouse hovered (for a
 *     subsequent canvas click) but the click target differs from the aim
 *     target (rare).
 *
 *   - `worldToCanvas(world, cam)` — the low-level transform. Exported for
 *     custom-aim specs that compute their own world target.
 *
 *   - `latestCameraState(capture)` — parses the latest CameraDirector.state
 *     trace line. Returns null if the trace hasn't fired yet (pre-boot).
 *     Helpers internally fall back to default-camera-at-spawn if null.
 *
 *   - `latestPlayerPos(capture)` — parses the latest Player.pos line.
 *
 * Constants:
 *   - `DEFAULT_PLAYER_SPAWN` — world coord; mirrors `scenes/Main.gd:83`.
 *   - `MOUSE_FACING_DEADZONE_PX` — world-units; mirrors `Player.gd:136`.
 *   - `VIEWPORT_CENTER` — canvas pixel center used by the camera transform.
 *   - `DEFAULT_ENGINE_ZOOM` — fallback engine zoom (matches BASELINE_ZOOM)
 *     used when no camera-state trace has fired yet.
 *
 * Checklist for new mouse-input specs (post-T9):
 *   1. Compute the desired aim target in WORLD coords (relative to spawn,
 *      to the player, or to a known mob).
 *   2. Pass a `ConsoleCapture` to the helper. The fixture handles the
 *      world→canvas transform internally.
 *   3. If the spec sets up its own canvas click, call `worldToCanvas` and
 *      pass the result as `{position: {x, y}}`. Never click raw world coords.
 *   4. Allow ~500 ms post-canvas-focus before reading camera state — the
 *      state trace emits at 0.25 s cadence (`STATE_TRACE_INTERVAL` in
 *      `CameraDirector.gd`).
 *
 * References:
 *   - `scripts/player/Player.gd::_update_mouse_facing` — read site for
 *     `get_global_mouse_position()` that this fixture's clicks target.
 *   - `scripts/camera/CameraDirector.gd::_emit_state_trace` — origin of the
 *     `CameraDirector.state` trace line.
 *   - `.claude/docs/camera-layer.md` § "Playwright-harness implication" —
 *     the canonical hard rule + world↔canvas math.
 *   - `.claude/docs/combat-architecture.md` § "Mouse-direction facing" —
 *     the original PR #255 motivation.
 *   - Tickets `86c9uthf0` (PR #255 respin) + `86c9wjyf3` (T9 camera).
 */

import type { Locator, Page } from "@playwright/test";
import type { ConsoleCapture } from "./console-capture";

/**
 * The world position the player is teleported to on every `_load_room_at_index`.
 * Mirrors `scenes/Main.gd:83 DEFAULT_PLAYER_SPAWN = Vector2(240, 200)`.
 *
 * Post-T9 (CameraDirector landed) this is a WORLD coord, NOT a canvas pixel.
 * The camera snap-follows the player so player-at-spawn renders at the
 * canvas-pixel `VIEWPORT_CENTER = (640, 360)`.
 */
export const DEFAULT_PLAYER_SPAWN = { x: 240, y: 200 };

/**
 * Canvas-pixel viewport center. Mirrors `project.godot [display]
 * window/size = (1280, 720)`. Constant under the M1 viewport size.
 */
export const VIEWPORT_CENTER = { x: 640, y: 360 };

/**
 * Default engine-units Camera2D zoom. Mirrors `CameraDirector.BASELINE_ZOOM
 * = Vector2(2.6667, 2.6667)`. Used as the fallback when no camera-state
 * trace has fired yet (extremely rare — emitted every 0.25 s post-boot).
 */
export const DEFAULT_ENGINE_ZOOM = 2.6667;

/**
 * Mouse-facing dead-zone threshold (px, WORLD units). Mirrors
 * `scripts/player/Player.gd:136 MOUSE_FACING_DEADZONE_PX = 8.0`.
 *
 * If `|mouse_world - player_world| < 8.0` the player's `_facing` is left
 * unchanged. Helpers enforce a world-offset distance `>= AIM_OFFSET_MIN_PX`
 * so facing IS updated.
 */
export const MOUSE_FACING_DEADZONE_PX = 8.0;

/**
 * Minimum aim offset (world px) from the player. Set well above
 * `MOUSE_FACING_DEADZONE_PX` so a few px of drift / overshoot never
 * collapses the delta into the dead-zone.
 */
export const AIM_OFFSET_MIN_PX = 100;

/** Cardinal aim directions used by combat-driving specs. */
export type AimDirection =
  | "N"
  | "NE"
  | "E"
  | "SE"
  | "S"
  | "SW"
  | "W"
  | "NW";

/**
 * Unit-vector lookup for the 8 cardinal/intercardinal directions. Y is +DOWN
 * (Godot screen-space). Diagonals are normalized to length 1.
 */
const DIRECTION_VECTORS: Record<AimDirection, { x: number; y: number }> = {
  N: { x: 0, y: -1 },
  NE: { x: 0.707, y: -0.707 },
  E: { x: 1, y: 0 },
  SE: { x: 0.707, y: 0.707 },
  S: { x: 0, y: 1 },
  SW: { x: -0.707, y: 0.707 },
  W: { x: -1, y: 0 },
  NW: { x: -0.707, y: -0.707 },
};

export interface AimClickOptions {
  /**
   * Distance (world px) from origin to the click position along `direction`.
   * Default 150 — well above `MOUSE_FACING_DEADZONE_PX = 8` so facing
   * updates reliably even if the player has drifted a few px from origin.
   */
  offsetPx?: number;
  /**
   * Mouse button. Default "left" (LMB → light attack). Pass "right" for RMB
   * (heavy attack).
   */
  button?: "left" | "right";
}

/**
 * Live Camera2D state derived from a `[combat-trace] CameraDirector.state`
 * line. `zoom` is the engine-units zoom (NOT normalized).
 */
export interface CameraState {
  zoom: number;
  posX: number;
  posY: number;
}

/**
 * Parse the latest `[combat-trace] CameraDirector.state | zoom=<v> pos=(x,y)`
 * reading from the capture buffer. Returns null if no trace is available
 * (e.g. helper called pre-boot, or in a build that disables combat_trace).
 *
 * The emission cadence is `CameraDirector.STATE_TRACE_INTERVAL = 0.25 s`,
 * so any helper invoked ≥ 500 ms after canvas focus reliably finds a fresh
 * datapoint. Callers MUST guarantee a settle window — the spec's own
 * `await page.waitForTimeout(500)` between canvas focus and the first
 * helper call is the convention.
 */
export function latestCameraState(
  capture: ConsoleCapture
): CameraState | null {
  const lines = capture.getLines();
  for (let i = lines.length - 1; i >= 0; i--) {
    const t = lines[i].text;
    if (!/\[combat-trace\] CameraDirector\.state \|/.test(t)) continue;
    const m = t.match(/zoom=([-\d.]+) pos=\(\s*(-?\d+)\s*,\s*(-?\d+)\s*\)/);
    if (!m) continue;
    return {
      zoom: parseFloat(m[1]),
      posX: parseInt(m[2], 10),
      posY: parseInt(m[3], 10),
    };
  }
  return null;
}

/**
 * Translate a world coord to its canvas-pixel position under the live
 * Camera2D transform:
 *
 *   canvas_pixel = (world - camera.global_position) * camera.zoom + viewport_center
 *
 * If `cam` is null (no state trace yet), assumes the camera is at
 * `DEFAULT_PLAYER_SPAWN` with `DEFAULT_ENGINE_ZOOM` (boot defaults).
 *
 * Result is clamped into canvas bounds [0..1280, 0..720] — out-of-bounds
 * clicks land at the canvas edge but stay reachable.
 */
export function worldToCanvas(
  worldX: number,
  worldY: number,
  cam: CameraState | null
): { x: number; y: number } {
  const camX = cam ? cam.posX : DEFAULT_PLAYER_SPAWN.x;
  const camY = cam ? cam.posY : DEFAULT_PLAYER_SPAWN.y;
  const z = cam ? cam.zoom : DEFAULT_ENGINE_ZOOM;
  const cx = (worldX - camX) * z + VIEWPORT_CENTER.x;
  const cy = (worldY - camY) * z + VIEWPORT_CENTER.y;
  return {
    x: Math.max(0, Math.min(1280, cx)),
    y: Math.max(0, Math.min(720, cy)),
  };
}

/**
 * Click at a known WORLD offset from `DEFAULT_PLAYER_SPAWN = (240, 200)` in
 * the named direction, then translate through the live camera transform.
 * Use for room-clearing helpers where the player stays near spawn throughout
 * combat (Rooms 02–08 traversal pattern).
 *
 * The world click position is `spawn + DIRECTION_VECTORS[direction] * offsetPx`.
 * Default `offsetPx = 150` puts the click well outside the dead-zone with
 * margin against player drift.
 *
 * Post-T9: pass `capture` so the helper reads live camera state. Calling
 * without `capture` falls back to default-camera-at-spawn (the boot state),
 * which is correct on a freshly-loaded room where the player hasn't moved.
 */
export async function clickAimedAtSpawn(
  canvas: Locator,
  capture: ConsoleCapture | null,
  direction: AimDirection,
  options: AimClickOptions = {}
): Promise<void> {
  const offsetPx = options.offsetPx ?? 150;
  const button = options.button ?? "left";
  const v = DIRECTION_VECTORS[direction];
  const worldX = DEFAULT_PLAYER_SPAWN.x + v.x * offsetPx;
  const worldY = DEFAULT_PLAYER_SPAWN.y + v.y * offsetPx;
  const cam = capture ? latestCameraState(capture) : null;
  const c = worldToCanvas(worldX, worldY, cam);
  await canvas.click({ position: { x: c.x, y: c.y }, button });
}

/**
 * Click at a literal Godot world coordinate, translated through the live
 * camera transform. Use when the target's world position is known (e.g.
 * Room01 PracticeDummy at world ~(368, 144)).
 */
export async function clickAtWorldPos(
  canvas: Locator,
  capture: ConsoleCapture | null,
  worldX: number,
  worldY: number,
  options: { button?: "left" | "right" } = {}
): Promise<void> {
  const button = options.button ?? "left";
  const cam = capture ? latestCameraState(capture) : null;
  const c = worldToCanvas(worldX, worldY, cam);
  await canvas.click({ position: { x: c.x, y: c.y }, button });
}

/**
 * Move the mouse to a Godot world coordinate (no click), translated through
 * the live camera transform. Used by `clickAimedFromPlayer` and any spec
 * that needs the mouse hovered prior to a subsequent click.
 *
 * The page-coordinate calculation accounts for the canvas bounding box
 * offset; the click-style helpers above don't need this because
 * `canvas.click({position: ...})` is canvas-relative.
 */
export async function aimAtWorldPos(
  page: Page,
  canvas: Locator,
  capture: ConsoleCapture | null,
  worldX: number,
  worldY: number
): Promise<void> {
  const bb = await canvas.boundingBox();
  if (!bb) {
    throw new Error("[mouse-facing] canvas.boundingBox() returned null");
  }
  const cam = capture ? latestCameraState(capture) : null;
  const c = worldToCanvas(worldX, worldY, cam);
  await page.mouse.move(bb.x + c.x, bb.y + c.y);
}

/**
 * Parse the latest `[combat-trace] Player.pos | pos=(x,y)` reading from the
 * capture buffer. Returns null if no trace is available (e.g. the helper is
 * called pre-boot).
 */
export function latestPlayerPos(
  capture: ConsoleCapture
): { x: number; y: number } | null {
  const lines = capture.getLines();
  for (let i = lines.length - 1; i >= 0; i--) {
    const t = lines[i].text;
    if (!/\[combat-trace\] Player\.pos \|/.test(t)) continue;
    const m = t.match(/pos=\(\s*(-?\d+)\s*,\s*(-?\d+)\s*\)/);
    if (!m) continue;
    return { x: parseInt(m[1], 10), y: parseInt(m[2], 10) };
  }
  return null;
}

/**
 * Click at a directional WORLD offset from the PLAYER'S CURRENT POSITION
 * (derived from the latest `Player.pos` trace), then translate through the
 * live camera transform. Use when the player has roamed from spawn
 * (multi-chaser pursuit, post-chase wander).
 *
 * Falls back to spawn-relative aim if no `Player.pos` trace is available
 * (e.g. helper called before the first physics frame emitted a position
 * line). The fallback path is safer than throwing — every caller has its
 * own downstream hard assertion.
 */
export async function clickAimedFromPlayer(
  canvas: Locator,
  capture: ConsoleCapture,
  direction: AimDirection,
  options: AimClickOptions = {}
): Promise<void> {
  const offsetPx = options.offsetPx ?? 150;
  const button = options.button ?? "left";
  const player = latestPlayerPos(capture);
  const origin = player ?? DEFAULT_PLAYER_SPAWN;
  const v = DIRECTION_VECTORS[direction];
  const worldX = origin.x + v.x * offsetPx;
  const worldY = origin.y + v.y * offsetPx;
  const cam = latestCameraState(capture);
  const c = worldToCanvas(worldX, worldY, cam);
  await canvas.click({ position: { x: c.x, y: c.y }, button });
}
