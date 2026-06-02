/**
 * s1-env-art-render.spec.ts
 *
 * S1 "Outer Cloister" env-art render smoke (ticket 86ca3h8hn).
 *
 * The chunk scene s1_room01_chunk.tscn swapped its flat Floor ColorRect for a
 * TileMapLayer painted from resources/tilesets/s1_cloister.tres, swapped the
 * four wall ColorRect sprites for a wall-tile perimeter band, and added prop
 * Sprite2D nodes at z_index=+1. Rooms 01-08 all instance this one chunk scene,
 * so booting into Room 01 exercises the whole env-art render path.
 *
 * This spec is the HTML5 / gl_compatibility-side gate for the TileMap render
 * path. It verifies (per the two-surface bar, complementing the GUT side):
 *   1. The build boots cleanly into Room 01 (the new chunk loads without
 *      error — a broken TileSet ref or painter crash would fail boot).
 *   2. [BuildInfo] SHA is present (7 hex chars, not dev-local).
 *   3. ZERO USER WARNING / USER ERROR lines (universal warning gate via
 *      test-base fixture) — catches a missing-texture / bad-atlas-coord /
 *      TileSet-load warning from the env-art swap.
 *   4. No console.error during boot.
 *   5. No significant 404s (the tileset/prop PNGs must resolve in the .pck).
 *
 * NOTE on perception: per html5-export.md § "Playwright headless ≠ real-browser
 * perception", this headless spec proves the render path LOADS + is WARNING-
 * CLEAN, not that a human perceives the textured floor. The visual-of-record
 * is the author HTML5 self-soak screenshot + Sponsor soak (Self-Test Report).
 *
 * References:
 *   - scenes/levels/chunks/s1_room01_chunk.tscn — the env-art chunk
 *   - scripts/levels/S1CloisterChunk.gd — TileMapLayer painter (_ready)
 *   - resources/tilesets/s1_cloister.tres — floor + wall TileSet
 *   - tests/playwright/fixtures/test-base.ts — universal USER WARNING gate
 *   - .claude/docs/html5-export.md § "HTML5 visual-verification gate"
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";

/** Godot WASM + OPFS init can take 10s+ */
const BOOT_TIMEOUT_MS = 30_000;
const SMOKE_LINE_TIMEOUT_MS = 15_000;

// launchOptions / contextOptions (cache mitigation, serviceWorkers:"block")
// are set globally in playwright.config.ts.

test.describe("S1 env-art render smoke — Outer Cloister TileMap chunk", () => {
  test("S1 env-art render smoke — Outer Cloister TileMap chunk", async ({
    page,
    context,
  }) => {
    await context.route("**/*", (route) => route.continue());

    const capture = new ConsoleCapture(page);
    capture.attach();

    // Track 404s — the tileset + prop PNGs must resolve from the .pck.
    const notFoundUrls: string[] = [];
    page.on("response", (response) => {
      if (response.status() === 404) {
        notFoundUrls.push(response.url());
      }
    });

    const baseURL =
      process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(baseURL, { waitUntil: "domcontentloaded" });

    // 1. BuildInfo SHA present (7 hex chars, not dev-local).
    const buildInfoLine = await capture.waitForLine(
      /\[BuildInfo\] build: [0-9a-f]{7}/,
      SMOKE_LINE_TIMEOUT_MS
    );
    expect(buildInfoLine).toMatch(/\[BuildInfo\] build: [0-9a-f]{7}/);
    expect(buildInfoLine).not.toContain("dev-local");

    // 2. Boot completes into Room 01 — the new env-art chunk loaded without
    //    crashing the play-loop wiring. A broken TileSet ExtResource or a
    //    painter exception would prevent this sentinel from ever printing.
    await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);

    // 3. Universal warning gate is enforced by the test-base teardown
    //    (fails on any USER WARNING: / USER ERROR: line). Assert here too so
    //    the failure message names the env-art surface explicitly.
    const userWarnings = capture
      .getLines()
      .filter(
        (l) =>
          /USER WARNING:/.test(l.text) || /USER ERROR:/.test(l.text)
      );
    if (userWarnings.length > 0) {
      console.log(
        "[s1-env-art] USER WARNING/ERROR lines (env-art render path):\n" +
          userWarnings.map((l) => l.text).join("\n")
      );
    }
    expect(
      userWarnings.length,
      "S1 env-art render path must be USER WARNING / USER ERROR clean — a " +
        "missing tileset texture, bad atlas coord, or painter crash would " +
        "surface here (ticket 86ca3h8hn)."
    ).toBe(0);

    // 4. No console.error during boot.
    const firstError = capture.findFirstError();
    if (firstError) {
      console.log("[s1-env-art] FULL CONSOLE DUMP:\n" + capture.dump());
    }
    expect(firstError).toBeNull();

    // 5. No significant 404s (tileset + prop PNGs resolve in the .pck).
    const significantNotFound = notFoundUrls.filter(
      (url) => !url.includes("favicon.ico")
    );
    if (significantNotFound.length > 0) {
      console.log(
        "[s1-env-art] 404 URLs:\n" + significantNotFound.join("\n")
      );
    }
    expect(significantNotFound).toHaveLength(0);

    capture.detach();
  });
});
