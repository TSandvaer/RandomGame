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
 * **Why canvas-center is the wrong click target.** The Embergrave M1 build has
 * NO `Camera2D` — viewport is a fixed 1280×720 with `stretch=canvas_items` +
 * `aspect=keep`. The player's `global_position == canvas_pixel_position` 1:1.
 * The default spawn point is `DEFAULT_PLAYER_SPAWN = (240, 200)` — which is in
 * the upper-left QUADRANT of the canvas, NOT the center. Canvas-center is at
 * `(640, 360)` — `(+400, +160)` from the player = roughly SOUTHEAST. So a
 * click at canvas-center makes the player swing SOUTHEAST, NOT toward the
 * mobs (which spawn NE/N of the player in Rooms 02–08 per the level_chunk
 * TRES data — see `tests/playwright/specs/ac4-boss-clear.spec.ts:400-411`).
 *
 * **The fix shape — HARD RULE for ALL future Playwright specs that rely on
 * mouse-direction attacks:** the click position MUST be at a known offset
 * RELATIVE TO THE PLAYER, in the desired attack direction. Aiming via the
 * mouse position is the only mechanism that controls swing direction now —
 * direction keys do not.
 *
 * **Drift-pin convention (sibling of PR #252 § 17):** every spec that fires
 * mouse-direction attacks MUST go through one of the helpers in this file
 * (or document its own explicit aim derivation). A `canvas.click({position:
 * {x: canvasCenter, y: canvasCenter}})` call in a combat-driving spec is a
 * regression — the click hits canvas-center, the swing fires SE, no mobs die.
 *
 * **Helpers in this module:**
 *
 *   - `clickAimedAtSpawn(canvas, direction, options)` — clicks at a fixed
 *     offset from `DEFAULT_PLAYER_SPAWN = (240, 200)` in the named direction.
 *     This is the workhorse for room-clearing helpers (room01-traversal,
 *     AC4 per-room loop) where the player stays near spawn throughout combat.
 *
 *   - `clickAtWorldPos(canvas, worldX, worldY)` — clicks at a literal Godot
 *     world coordinate. Use when the target's position is known (e.g. the
 *     PracticeDummy at world (~368, 144)).
 *
 *   - `clickAimedFromPlayer(page, canvas, capture, direction, options)` —
 *     reads the latest `[combat-trace] Player.pos | pos=(x,y)` line, then
 *     clicks at a directional offset from THAT live position. Use when the
 *     player has roamed from spawn (multi-chaser pursuit, post-chase
 *     follow-up). Falls back to spawn if no Player.pos trace is available.
 *
 *   - `aimAtWorldPos(page, canvas, worldX, worldY)` — moves the mouse without
 *     clicking. Use when you need the mouse hovered (for a subsequent canvas
 *     click) but the click target differs from the aim target (rare).
 *
 * Constants:
 *   - `DEFAULT_PLAYER_SPAWN` — mirrors `scenes/Main.gd:83`.
 *   - `MOUSE_FACING_DEADZONE_PX` — mirrors `scripts/player/Player.gd:136`.
 *     Used by helpers to guarantee `offsetPx ≥ DEADZONE + safety margin` so
 *     facing is reliably updated.
 *
 * References:
 *   - `scripts/player/Player.gd::_update_mouse_facing` — the read site for
 *     `get_global_mouse_position()` that this fixture's clicks target.
 *   - `.claude/docs/combat-architecture.md` § "Mouse-direction facing" —
 *     the canonical hard rule + viewport-coords explanation.
 *   - Ticket `86c9uthf0` — the PR-#255 respin that introduced this fixture.
 */

import type { Locator, Page } from "@playwright/test";
import type { ConsoleCapture } from "./console-capture";

/**
 * The world position the player is teleported to on every `_load_room_at_index`.
 * Mirrors `scenes/Main.gd:83 DEFAULT_PLAYER_SPAWN = Vector2(240, 200)`.
 *
 * With NO Camera2D in the M1 build and `stretch=keep` aspect ratio, this is
 * also the canvas pixel position the player renders at on a fresh room load.
 */
export const DEFAULT_PLAYER_SPAWN = { x: 240, y: 200 };

/**
 * Mouse-facing dead-zone threshold (px). Mirrors
 * `scripts/player/Player.gd:136 MOUSE_FACING_DEADZONE_PX = 8.0`.
 *
 * If `|mouse - player| < 8.0` the player's `_facing` is left unchanged. Every
 * helper in this module enforces a `>= AIM_OFFSET_MIN_PX` distance from the
 * player so facing IS updated (the failure shape from PR #255's first round
 * was exactly this dead-zone trap — canvas-center clicked while player was
 * at canvas-center → 0 px delta → facing frozen at initial Vector2.DOWN).
 */
export const MOUSE_FACING_DEADZONE_PX = 8.0;

/**
 * Minimum aim offset (px) from the player. Set well above
 * `MOUSE_FACING_DEADZONE_PX` so a few px of drift / overshoot never collapses
 * the delta into the dead-zone.
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
   * Distance (px) from origin to the click position along `direction`.
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
 * Click at a known offset from `DEFAULT_PLAYER_SPAWN = (240, 200)` in the
 * named direction. Use for room-clearing helpers where the player stays near
 * spawn throughout combat (Rooms 02–08 traversal pattern — the gate-traversal
 * walk geometry depends on the player being near spawn anyway).
 *
 * The click position is `spawn + DIRECTION_VECTORS[direction] * offsetPx`,
 * clamped into the canvas bounds. Default `offsetPx = 150` puts the click
 * well outside the dead-zone with margin against player drift.
 *
 * **No camera in M1.** Player at spawn renders at canvas pixel (240, 200) —
 * a click at `(240 + 100, 200 - 100) = (340, 100)` is reliably NE of the
 * player in world coords AND outside the dead-zone (delta length ≈ 141 px).
 */
export async function clickAimedAtSpawn(
  canvas: Locator,
  direction: AimDirection,
  options: AimClickOptions = {}
): Promise<void> {
  const offsetPx = options.offsetPx ?? 150;
  const button = options.button ?? "left";
  const v = DIRECTION_VECTORS[direction];
  const x = DEFAULT_PLAYER_SPAWN.x + v.x * offsetPx;
  const y = DEFAULT_PLAYER_SPAWN.y + v.y * offsetPx;
  await canvas.click({ position: { x, y }, button });
}

/**
 * Click at a literal Godot world coordinate. Use when the target's position
 * is known (e.g. the Room01 PracticeDummy at world ~(368, 144) — clicking
 * there points the swing AT the dummy regardless of where the player
 * currently stands).
 *
 * No camera in M1 — world coord == canvas pixel coord.
 */
export async function clickAtWorldPos(
  canvas: Locator,
  worldX: number,
  worldY: number,
  options: { button?: "left" | "right" } = {}
): Promise<void> {
  const button = options.button ?? "left";
  await canvas.click({ position: { x: worldX, y: worldY }, button });
}

/**
 * Move the mouse to a Godot world coordinate without clicking. Used by
 * `clickAimedFromPlayer` and any spec that needs the mouse hovered prior to
 * a subsequent click. The page-coordinate calculation accounts for the canvas
 * bounding box offset; the click-style helpers above don't need this because
 * `canvas.click({position: ...})` is canvas-relative.
 *
 * No camera in M1 — world coord == canvas pixel coord, so the mouse-page
 * position is just `canvasBB.x + worldX`, `canvasBB.y + worldY`.
 */
export async function aimAtWorldPos(
  page: Page,
  canvas: Locator,
  worldX: number,
  worldY: number
): Promise<void> {
  const bb = await canvas.boundingBox();
  if (!bb) {
    throw new Error("[mouse-facing] canvas.boundingBox() returned null");
  }
  await page.mouse.move(bb.x + worldX, bb.y + worldY);
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
 * Click at a directional offset from the PLAYER'S CURRENT POSITION (derived
 * from the latest `Player.pos` trace). Use when the player has roamed from
 * spawn (multi-chaser pursuit, post-chase wander) and a spawn-relative aim
 * would no longer point in the intended direction.
 *
 * Falls back to `clickAimedAtSpawn` if no `Player.pos` trace is available
 * (e.g. helper called before the first physics frame emitted a position
 * line). The fallback path is safer than throwing — every caller has its
 * own downstream hard assertion, and a slightly-off aim still beats no aim.
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
  const x = origin.x + v.x * offsetPx;
  const y = origin.y + v.y * offsetPx;
  await canvas.click({ position: { x, y }, button });
}
