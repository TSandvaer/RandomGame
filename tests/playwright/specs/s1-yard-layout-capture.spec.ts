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

    // Spawn is left-edge, vertical-center (~world 24, 384). Drive N toward the chapel
    // (footprint x0-7,y0-2 → base ~y96): the camera clamps to the top floor bound, framing
    // the chapel + bell-tower at the NW spawn shoulder.
    await drive(page, "KeyW", 1600);
    await shot(page, "b1_chapel_belltower");

    // Back to center then S toward the dormitory ruins (footprint x0-14,y21-23, S edge).
    await drive(page, "KeyS", 2400);
    await shot(page, "b2_dormitory_ruins");

    // E a little + stay low → the WELL (tile 12,17 → world ~400,560) + spring + garden.
    await drive(page, "KeyD", 1300);
    await shot(page, "b3_well_focal");

    // Up to the central building (footprint x26-29,y0-3 → world ~896,64) via E then N. The
    // lit ember SOUTH window faces the approach (canvas-S of the structure).
    await drive(page, "KeyD", 2600);
    await drive(page, "KeyW", 1500);
    await shot(page, "b4_central_lit_window");

    // Far E + N to the outbuilding (footprint x38-39,y2-3 → world ~1248,80) on the east horizon.
    await drive(page, "KeyD", 2600);
    await shot(page, "b5_far_outbuilding");

    // Wide overview: drop to mid-yard (the fork/spine + well + central silhouette together).
    await drive(page, "KeyA", 1400);
    await drive(page, "KeyS", 700);
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
