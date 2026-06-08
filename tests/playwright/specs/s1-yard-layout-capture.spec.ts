/**
 * s1-yard-layout-capture.spec.ts
 *
 * S1 yard APPROVED-LAYOUT in-game GPU capture (ticket 86ca5hwmx, PR #426).
 *
 * The VISUAL-VERIFICATION-GATE capture for the Sponsor-approved s1-yard-layout-
 * design.md layout: boots the release artifact with `?s1_assembler=1`, then drives
 * the player to FRAME each building landmark (the camera follows + clamps to the
 * assembled-floor bounds) and captures IN-GAME GPU screenshots:
 *   - chapel + bell-tower (NW spawn shoulder; drive N from spawn)
 *   - dormitory ruins LEFT + RIGHT (S edge; drive S)
 *   - the WELL focal landmark + spring seep + garden (south-center)
 *   - central cloister building w/ the lit ember south-window (drive E+N)
 *   - far outbuilding (east horizon; drive far E)
 *   - a wide-as-possible overview framing spine/fork + multiple silhouettes
 *
 * Per the HARD gate (orch dispatch): IN-GAME GPU screenshot — NEVER a standalone
 * render tool (the render-tool divergence caused the S1-saga false approvals).
 *
 * v2 (orch black-square + landmark-framing re-judge 2026-06-08): the first 6 shots
 * were ground-centric (player spawns vertical-CENTER at tile y12; the chapel at
 * y0-2 sits ABOVE the viewport, so the spawn vista never framed it). This pass
 * DRIVES the player TO each building so the camera centers it. The black-square
 * artifact (the opaque spring ColorRect, diagnosed via [prop-trace]) is fixed —
 * the damp seep is now semi-transparent.
 *
 * Per html5-export.md § "Playwright headless ≠ real-browser perception", these
 * captures prove the layout RENDERS in-engine; Sponsor's interactive soak remains
 * the FEEL gate of record.
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";
import * as fs from "fs";
import * as path from "path";

const BOOT_TIMEOUT_MS = 30_000;
const SMOKE_LINE_TIMEOUT_MS = 15_000;

const SHOT_DIR = path.resolve(__dirname, "../../../team/drew-dev/_yard-layout-shots");

async function shot(page: import("@playwright/test").Page, name: string): Promise<void> {
  if (!fs.existsSync(SHOT_DIR)) fs.mkdirSync(SHOT_DIR, { recursive: true });
  await page.screenshot({ path: path.join(SHOT_DIR, `${name}.png`) });
}

/** Hold a key for `ms` to drive the player (camera follows + clamps to floor bounds). */
async function drive(
  page: import("@playwright/test").Page,
  key: string,
  ms: number,
): Promise<void> {
  await page.keyboard.down(key);
  await page.waitForTimeout(ms);
  await page.keyboard.up(key);
  await page.waitForTimeout(300); // settle a frame for the camera + render
}

/** Latest player world position from the throttled `[combat-trace] Player.pos` line. */
function latestPlayerPos(capture: ConsoleCapture): { x: number; y: number } | null {
  const lines = capture.getLines();
  for (let i = lines.length - 1; i >= 0; i--) {
    const m = lines[i].text.match(/Player\.pos \| pos=\(([-\d.]+),([-\d.]+)\)/);
    if (m) return { x: parseFloat(m[1]), y: parseFloat(m[2]) };
  }
  return null;
}

/**
 * Drive `key` in bursts until the player's `axis` ("x"|"y") reaches `target`
 * (`dir` = +1 toward larger, -1 toward smaller), reading the Player.pos trace
 * between bursts. Position-VERIFIED (not dead-reckoned) — walk speed is 120 px/s
 * so dead-reckoning over the 1280px yard accumulates error + stalls on collision.
 */
async function driveUntil(
  page: import("@playwright/test").Page,
  capture: ConsoleCapture,
  key: string,
  axis: "x" | "y",
  target: number,
  dir: 1 | -1,
  maxBursts = 12,
): Promise<void> {
  for (let i = 0; i < maxBursts; i++) {
    const p = latestPlayerPos(capture);
    if (p) {
      const v = axis === "x" ? p.x : p.y;
      if (dir === 1 ? v >= target : v <= target) return;
    }
    await drive(page, key, 600); // 600ms ≈ 72px/burst; the Player.pos trace throttles at 0.25s
  }
}

test.describe("S1 yard APPROVED-LAYOUT in-game GPU capture", () => {
  test("frames each building landmark on the assembler path", async ({ page, context }) => {
    await context.route("**/*", (route) => route.continue());
    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(`${baseURL}?s1_assembler=1`, { waitUntil: "domcontentloaded" });

    await capture.waitForLine(/\[BuildInfo\] build: [0-9a-f]{7}/, SMOKE_LINE_TIMEOUT_MS);
    const loadLine = await capture.waitForLine(
      /\[combat-trace\] Main\.load_s1_zone \|.*zone_id=s1_z1_yard_slice/,
      BOOT_TIMEOUT_MS,
    );
    expect(loadLine).toContain("chunks=2");

    const canvas = page.locator("canvas");
    await canvas.focus().catch(() => {});
    await page.waitForTimeout(600);

    // Walk speed is 120 px/s; the camera follows the player + clamps to the floor bounds
    // [0,1280]x[0,768]. Framing uses position-VERIFIED drives (driveUntil reads Player.pos)
    // for mid-field targets, and hard edge-clamp drives for corner buildings (the camera
    // pins to the corner so the corner building is deterministically framed).

    // 1. CHAPEL — NW corner. Drive N to the top edge (camera clamps top) → chapel framed.
    await driveUntil(page, capture, "KeyW", "y", 130, -1);
    await shot(page, "b1_chapel_belltower");

    // 2. DORMITORY RUINS — SW (footprint x0-14, y21-23). Drive S to the bottom edge + stay W.
    await driveUntil(page, capture, "KeyS", "y", 650, 1);
    await driveUntil(page, capture, "KeyD", "x", 160, 1);
    await shot(page, "b2_dormitory_ruins");

    // 3. WELL focal — tile (12,17) → world ~(400,560). Position-verify x then y.
    await driveUntil(page, capture, "KeyD", "x", 360, 1);
    await driveUntil(page, capture, "KeyW", "y", 520, -1);
    await shot(page, "b3_well_focal");

    // 4. CENTRAL building — footprint x26-29,y0-3 → world ~(896,64), lit ember S window faces
    //    the approach. Position-verify x to ~880, then drive N to the top edge.
    await driveUntil(page, capture, "KeyD", "x", 880, 1);
    await driveUntil(page, capture, "KeyW", "y", 150, -1);
    await shot(page, "b4_central_lit_window");

    // 5. FAR OUTBUILDING — NE (footprint x38-39,y2-3). Drive E to the right edge (camera clamps
    //    east) + stay N → the outbuilding on the east horizon.
    await driveUntil(page, capture, "KeyD", "x", 1240, 1);
    await shot(page, "b5_far_outbuilding");

    // 6. OVERVIEW — mid-yard vantage (~tile 20,12 → world ~640,384): the spine/fork + central
    //    silhouette + the open lanes share one frame.
    await driveUntil(page, capture, "KeyA", "x", 660, -1);
    await driveUntil(page, capture, "KeyS", "y", 360, 1);
    await shot(page, "b6_overview_spine_fork");

    // Universal warning gate.
    const warns = capture
      .getLines()
      .filter((l) => /USER WARNING:/.test(l.text) || /USER ERROR:/.test(l.text));
    if (warns.length > 0) {
      console.log("[yard-layout-capture] USER WARNING/ERROR:\n" + warns.map((l) => l.text).join("\n"));
    }
    expect(warns.length, "yard layout capture must be USER WARNING / ERROR clean").toBe(0);

    capture.detach();
  });
});
