/**
 * s1-yard-slice-render.spec.ts
 *
 * S1 open cloister-YARD first-slice render smoke (ticket 86ca5erzk, S1-YARD T4).
 *
 * Boots the release artifact with `?s1_assembler=1` so Main boots the Stratum-1
 * floor through the FloorAssembler path (`_load_s1_zone(S1_ZONE_ID)`), which now
 * resolves the open cloister-YARD first slice (`s1_z1_yard_slice` → the big
 * walkable 40x24 open-cobble expanse + a 6x24 east descent cap). This is the
 * HTML5 / gl_compatibility-side gate for the yard render path, complementing the
 * GUT side (tests/test_s1_yard_slice.gd).
 *
 * Verifies (per the two-surface bar):
 *   1. The build boots cleanly with the assembler flag set ([BuildInfo] SHA).
 *   2. The S1 floor loads via the assembler path — the `[combat-trace]
 *      Main.load_s1_zone` line fires with chunks=2 (yard + descent) and a
 *      bounding box WIDER than 480 px (the two-axis scroll bounds).
 *   3. ZERO USER WARNING / USER ERROR (universal warning gate) — catches a
 *      missing cobble/wall texture, a bad atlas coord, a chunk-load failure, a
 *      port-mating regression, or an unknown mob_id from the yard content.
 *   4. No console.error during boot.
 *   5. No significant 404s (the yard tileset + carried-forward prop PNGs must
 *      resolve in the .pck).
 *
 * NOTE on perception: per html5-export.md § "Playwright headless ≠ real-browser
 * perception", this headless spec proves the yard render path LOADS + is
 * WARNING-CLEAN under the assembler flag, NOT that a human perceives the open
 * yard. The visual-of-record is the author in-engine render (Self-Test Report)
 * + Sponsor soak on the "entering a big open world" FEEL.
 *
 * References:
 *   - scenes/levels/chunks/s1_yard_slice_chunk.tscn — the open-yard chunk
 *   - scripts/levels/S1YardChunk.gd — cobble/brick/decoration painter (_ready)
 *   - resources/level/zones/s1_z1_yard_slice.tres — the yard ZoneDef
 *   - scenes/Main.gd § "S1 assembler retrofit" — _load_s1_zone path
 *   - scripts/debug/DebugFlags.gd § _resolve_s1_assembler — the ?s1_assembler=1 flag
 *   - tests/playwright/fixtures/test-base.ts — universal USER WARNING gate
 *   - .claude/docs/html5-export.md § "HTML5 visual-verification gate"
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";

/** Godot WASM + OPFS init can take 10s+ */
const BOOT_TIMEOUT_MS = 30_000;
const SMOKE_LINE_TIMEOUT_MS = 15_000;

// The viewport width the yard bounds must exceed (480 px viewport-native).
const VIEWPORT_W = 480;

test.describe("S1 yard-slice render smoke — open cloister yard on the assembler path", () => {
  test("S1 yard-slice render smoke — ?s1_assembler=1 boots the open yard clean", async ({
    page,
    context,
  }) => {
    await context.route("**/*", (route) => route.continue());

    const capture = new ConsoleCapture(page);
    capture.attach();

    // Track 404s — the yard tileset + prop PNGs must resolve from the .pck.
    const notFoundUrls: string[] = [];
    page.on("response", (response) => {
      if (response.status() === 404) {
        notFoundUrls.push(response.url());
      }
    });

    const baseURL = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    // The assembler-path soak flag — boots S1 through FloorAssembler into the yard.
    await page.goto(`${baseURL}?s1_assembler=1`, {
      waitUntil: "domcontentloaded",
    });

    // 1. BuildInfo SHA present (7 hex chars, not dev-local).
    const buildInfoLine = await capture.waitForLine(
      /\[BuildInfo\] build: [0-9a-f]{7}/,
      SMOKE_LINE_TIMEOUT_MS,
    );
    expect(buildInfoLine).toMatch(/\[BuildInfo\] build: [0-9a-f]{7}/);
    expect(buildInfoLine).not.toContain("dev-local");

    // 2. The S1 floor loaded via the assembler path. The trace line carries
    //    zone_id, chunk count, and the assembled bounds — assert the yard slice
    //    booted (chunks=2: yard + descent) with a wider-than-viewport bounds.
    const loadLine = await capture.waitForLine(
      /\[combat-trace\] Main\.load_s1_zone \|.*zone_id=s1_z1_yard_slice/,
      BOOT_TIMEOUT_MS,
    );
    expect(loadLine).toContain("chunks=2");

    // Parse the bounding box width from `bounds=[P: (x, y), S: (w, h)]` and assert
    // it exceeds the viewport (the two-axis scroll bounds — the "big" read).
    const boundsMatch = loadLine.match(/bounds=\[P: \([^)]*\), S: \(([\d.]+),/);
    expect(
      boundsMatch,
      `could not parse bounds from trace line: ${loadLine}`,
    ).not.toBeNull();
    if (boundsMatch) {
      const boundsWidth = parseFloat(boundsMatch[1]);
      expect(
        boundsWidth,
        "assembled yard bounds must be WIDER than the 480px viewport (camera scroll)",
      ).toBeGreaterThan(VIEWPORT_W);
    }

    // 3. Universal warning gate. Assert here too so the failure message names the
    //    yard render surface explicitly.
    const userWarnings = capture
      .getLines()
      .filter(
        (l) => /USER WARNING:/.test(l.text) || /USER ERROR:/.test(l.text),
      );
    if (userWarnings.length > 0) {
      console.log(
        "[s1-yard-slice] USER WARNING/ERROR lines (yard render path):\n" +
          userWarnings.map((l) => l.text).join("\n"),
      );
    }
    expect(
      userWarnings.length,
      "S1 yard render path must be USER WARNING / USER ERROR clean — a missing " +
        "cobble/wall texture, bad atlas coord, chunk-load failure, port-mating " +
        "regression, or unknown mob_id would surface here (ticket 86ca5erzk).",
    ).toBe(0);

    // 4. No console.error during boot.
    const firstError = capture.findFirstError();
    if (firstError) {
      console.log("[s1-yard-slice] FULL CONSOLE DUMP:\n" + capture.dump());
    }
    expect(firstError).toBeNull();

    // 5. No significant 404s (yard tileset + prop PNGs resolve in the .pck).
    const significantNotFound = notFoundUrls.filter(
      (url) => !url.includes("favicon.ico"),
    );
    if (significantNotFound.length > 0) {
      console.log(
        "[s1-yard-slice] 404 URLs:\n" + significantNotFound.join("\n"),
      );
    }
    expect(significantNotFound).toHaveLength(0);

    capture.detach();
  });
});
