/**
 * s1-room02-colonnade.spec.ts
 *
 * S1 tile-quality rework + lined-hall colonnade (ticket 86ca44p4j).
 *
 * Boots into widened Room 02 (`?start_room=1`) — the proof room reworked by
 * this PR — and verifies the HTML5 / gl_compatibility render path for:
 *   1. Build boots cleanly into Room 02 (the reworked chunk + 4×4 atlas-window
 *      floor painter + 14 new solid-prop StaticBody2D nodes load without error).
 *   2. [BuildInfo] SHA present (7 hex chars, not dev-local).
 *   3. Room 02 actually loaded + mobs are ticking — first `Grunt.pos` trace line
 *      is the Room-02 load sentinel (no [Main] _load_room_at_index line exists;
 *      per test-conventions.md § "Room 02 load sentinel").
 *   4. ZERO USER WARNING / USER ERROR (universal warning gate) — a missing
 *      texture, bad atlas coord, or painter crash from the rework surfaces here.
 *   5. No console.error during boot.
 *   6. No significant 404s (tileset + all prop PNGs — pillar / brazier_cold /
 *      banner — resolve from the .pck).
 *   7. A screenshot of the booted room for the crafted-floor + colonnade
 *      read evidence (Self-Test Report attachment).
 *
 * PASSIVE-OBSERVER DISCIPLINE: this spec does NOT drive the player to a mob
 * (per .claude/docs/combat-architecture.md § "Harness coverage gap" — a helper
 * that steers the player would mask a mob-self-engagement bug). It observes the
 * boot + a passive `Grunt.pos` window only. Mob-reaches-player navigability is
 * pinned by the GUT BFS test (test_s1_room02_colonnade.gd
 * test_room_clearable_and_every_spawn_reaches_player), NOT by this spec.
 *
 * NOTE on perception: per html5-export.md § "Playwright headless ≠ real-browser
 * perception", this headless spec proves the render path LOADS + is WARNING-
 * CLEAN, not that a human perceives the crafted floor / colonnade. The visual-
 * of-record is the author HTML5 self-soak screenshot + Sponsor soak.
 *
 * References:
 *   - scenes/levels/chunks/s1_room02_wide_chunk.tscn — the reworked chunk
 *   - scripts/levels/S1CloisterChunk.gd — 4×4 atlas-window painter
 *   - resources/tilesets/s1_cloister.tres — floor + wall TileSet
 *   - team/uma-ux/s1-tile-rework.md — Uma direction spec
 *   - tests/playwright/fixtures/test-base.ts — universal USER WARNING gate
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";

/** Godot WASM + OPFS init can take 10s+ */
const BOOT_TIMEOUT_MS = 30_000;
const SMOKE_LINE_TIMEOUT_MS = 15_000;
/** Room 02 has 4 grunts; first Grunt.pos fires once a mob is alive + ticking. */
const ROOM_SENTINEL_TIMEOUT_MS = 20_000;

test.describe("S1 Room 02 colonnade render smoke — tile-rework + lined hall", () => {
  test("S1 Room 02 colonnade render smoke", async ({ page, context }) => {
    await context.route("**/*", (route) => route.continue());

    const capture = new ConsoleCapture(page);
    capture.attach();

    const notFoundUrls: string[] = [];
    page.on("response", (response) => {
      if (response.status() === 404) {
        notFoundUrls.push(response.url());
      }
    });

    const baseURL = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    // Boot directly into widened Room 02 (the reworked proof room).
    await page.goto(`${baseURL}/?start_room=1`, {
      waitUntil: "domcontentloaded",
    });

    // 1. BuildInfo SHA present (7 hex chars, not dev-local).
    const buildInfoLine = await capture.waitForLine(
      /\[BuildInfo\] build: [0-9a-f]{7}/,
      SMOKE_LINE_TIMEOUT_MS
    );
    expect(buildInfoLine).toMatch(/\[BuildInfo\] build: [0-9a-f]{7}/);
    expect(buildInfoLine).not.toContain("dev-local");

    // 2. Boot completes (play-loop wired — a TileSet/painter/prop crash would
    //    block this).
    await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);

    // 3. Room 02 load sentinel — first Grunt.pos line proves Room 02 finished
    //    loading + its mobs are alive + ticking (the reworked chunk drives the
    //    same spawn path).
    const gruntLine = await capture.waitForLine(
      /\[combat-trace\] Grunt\.pos/,
      ROOM_SENTINEL_TIMEOUT_MS
    );
    expect(gruntLine).toMatch(/Grunt\.pos/);

    // Let a passive observation window elapse so the room is fully alive when
    // we screenshot (NO player-steering — passive observer per the discipline
    // note above).
    await page.waitForTimeout(800);

    // 7. Screenshot for the crafted-floor + colonnade read (Self-Test Report).
    await page.screenshot({
      path: "test-results/s1-room02-colonnade.png",
    });

    // 4. Universal warning gate (also enforced by test-base teardown).
    const userWarnings = capture
      .getLines()
      .filter(
        (l) => /USER WARNING:/.test(l.text) || /USER ERROR:/.test(l.text)
      );
    if (userWarnings.length > 0) {
      console.log(
        "[s1-room02-colonnade] USER WARNING/ERROR lines:\n" +
          userWarnings.map((l) => l.text).join("\n")
      );
    }
    expect(
      userWarnings.length,
      "S1 Room 02 rework render path must be USER WARNING / USER ERROR clean — " +
        "a missing prop/tileset texture, bad atlas coord, or painter/collision " +
        "crash would surface here (ticket 86ca44p4j)."
    ).toBe(0);

    // 5. No console.error during boot.
    const firstError = capture.findFirstError();
    if (firstError) {
      console.log(
        "[s1-room02-colonnade] FULL CONSOLE DUMP:\n" + capture.dump()
      );
    }
    expect(firstError).toBeNull();

    // 6. No significant 404s — tileset + every prop PNG (pillar / brazier_lit /
    //    brazier_cold / banner_worn / moss / parchment / rubble) resolve.
    const significantNotFound = notFoundUrls.filter(
      (url) => !url.includes("favicon.ico")
    );
    if (significantNotFound.length > 0) {
      console.log(
        "[s1-room02-colonnade] 404 URLs:\n" + significantNotFound.join("\n")
      );
    }
    expect(significantNotFound).toHaveLength(0);

    capture.detach();
  });
});
