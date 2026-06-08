/**
 * s1-yard-layout-capture.spec.ts
 *
 * S1 yard APPROVED-LAYOUT in-game GPU capture (ticket 86ca5hwmx, PR #426).
 *
 * The VISUAL-VERIFICATION-GATE capture for the Sponsor-approved s1-yard-layout-
 * design.md layout: boots the release artifact with `?s1_assembler=1` so Main
 * loads the yard through the FloorAssembler path, then drives the player WEST→EAST
 * (and a SOUTH detour to the well) capturing IN-GAME GPU screenshots of the key
 * layout beats:
 *   1. spawn vista (chapel + bell-tower NW, the lane leading east)
 *   2. the upper-center rise + the FORK at the central building
 *   3. the WELL focal landmark (south detour) + spring + garden
 *   4. the central building's lit south window facing the approach
 *   5. the east descent approach
 *
 * Per the HARD verification gate (orch dispatch): this is an IN-GAME GPU
 * screenshot — NEVER a standalone render tool (the render tool diverged from the
 * game and caused the S1-saga false approvals). The captures are the author
 * self-soak evidence attached to the Self-Test Report + PR body.
 *
 * Per html5-export.md § "Playwright headless ≠ real-browser perception", these
 * captures prove the layout RENDERS in-engine (buildings/spine/well/grunts in the
 * right places, warning-clean) — Sponsor's interactive soak remains the FEEL gate
 * of record.
 *
 * References:
 *   - team/uma-ux/s1-yard-layout-design.md — the APPROVED coordinate layout
 *   - team/uma-ux/s1-yard-building-assets.md — the iso building-sprite spec
 *   - scenes/levels/chunks/s1_yard_slice_chunk.tscn — building sprites + props
 *   - scripts/levels/S1YardChunk.gd — lane router + collision + well/spring/garden
 *   - tests/playwright/fixtures/test-base.ts — universal USER WARNING gate
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

/** Hold a key for `ms` to drive the player (camera follows). */
async function drive(
  page: import("@playwright/test").Page,
  key: string,
  ms: number,
): Promise<void> {
  await page.keyboard.down(key);
  await page.waitForTimeout(ms);
  await page.keyboard.up(key);
  await page.waitForTimeout(250); // settle a frame for the camera + render
}

test.describe("S1 yard APPROVED-LAYOUT in-game GPU capture", () => {
  test("captures the layout beats on the assembler path", async ({ page, context }) => {
    await context.route("**/*", (route) => route.continue());
    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(`${baseURL}?s1_assembler=1`, { waitUntil: "domcontentloaded" });

    // Confirm the build + assembler-path load (the render is meaningful only if the
    // yard actually loaded through the assembler).
    await capture.waitForLine(/\[BuildInfo\] build: [0-9a-f]{7}/, SMOKE_LINE_TIMEOUT_MS);
    const loadLine = await capture.waitForLine(
      /\[combat-trace\] Main\.load_s1_zone \|.*zone_id=s1_z1_yard_slice/,
      BOOT_TIMEOUT_MS,
    );
    expect(loadLine).toContain("chunks=2");

    const canvas = page.locator("canvas");
    await canvas.focus().catch(() => {});
    await page.waitForTimeout(600); // let the first frame settle

    // 1. SPAWN VISTA — chapel + bell-tower NW, the lane leading east.
    await shot(page, "01_spawn_vista");

    // 2. THE RISE + FORK — drive east along the upper-center spine toward the central
    //    building / fork. Several east bursts move the camera across the yard.
    await drive(page, "KeyD", 1400);
    await shot(page, "02_rise_east");
    await drive(page, "KeyD", 1400);
    await shot(page, "03_fork_central");

    // 3. THE WELL — detour SOUTH toward the south-center well + spring + garden.
    await drive(page, "KeyS", 1100);
    await shot(page, "04_well_south");

    // 4. CONTINUE EAST — central building lit-S-window face + east approach.
    await drive(page, "KeyW", 900);
    await drive(page, "KeyD", 1600);
    await shot(page, "05_central_window");
    await drive(page, "KeyD", 1600);
    await shot(page, "06_east_descent");

    // Universal warning gate — the capture run must also be USER WARNING / ERROR clean.
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
