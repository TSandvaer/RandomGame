/**
 * descent-portal-open-map-click.spec.ts
 *
 * **Ticket W2-T5 fix (`86c9y10fv`)** — Sponsor RC soak P0 regression-pin.
 *
 * The pre-fix bug: Sponsor clicked the DescendScreen "Open Map" button and
 * saw nothing happen. The `pressed` signal WAS firing; the handler WAS
 * instantiating a WorldMapPanel; the panel WAS being added to the tree.
 * But the panel mounted at `layer=70` while DescendScreen sits at
 * `layer=100` with a **100%-opaque full-rect BG ColorRect** — so the
 * panel was structurally hidden behind the descend chrome. Sponsor's
 * trace stream had ZERO lines from the click handler (no diagnostic
 * was instrumented), making the bug invisible to anything except code
 * inspection.
 *
 * The pre-fix Playwright coverage (`world-map-panel-render.spec.ts`)
 * only tested boot-smoke — it verified the panel script parses and the
 * discovery hook fires. It did NOT exercise the BUTTON-CLICK path, so
 * the layer-ordering visibility regression was invisible to the suite.
 *
 * **What this spec checks (end-to-end button-click → panel-open path):**
 *
 *   1. Open the build with `?force_descend=1` URL param — Main boots,
 *      autoloads wire, Room 01 loads, then DescendScreen auto-opens via
 *      `force_descend_for_test`. (The URL-param is the W2-T5-fix-added
 *      hook so we don't need to play through 8 rooms + boss-kill.)
 *
 *   2. Wait for the DescendScreen to appear in the console
 *      (`[Main] DebugFlags.force_descend=true` boot-line + DescendScreen
 *      construction).
 *
 *   3. Click the "Open Map" button via Playwright canvas-click at the
 *      authored button position.
 *
 *   4. Assert TWO `[combat-trace]` lines fire from the click path:
 *        a. `DescendScreen._on_open_map_pressed` — proves the button
 *           signal wired into the handler.
 *        b. `DescendScreen.world_map_mounted | layer=<N>` — proves the
 *           panel was instantiated, mounted, AND elevated above
 *           DescendScreen's own layer (the regression-pin).
 *
 *   5. Assert a `WorldMapPanel.opened` trace fires from the panel's
 *      `_emit_open_trace` (`scripts/ui/WorldMapPanel.gd:_emit_open_trace`)
 *      — proves the panel reached its `_ready` (not stuck on parse-time
 *      error or autoload mis-resolution).
 *
 *   6. **Regression-pin for the layer-ordering visibility bug:** parse
 *      the `world_map_mounted` trace's `layer=<N>` payload and assert
 *      `layer > 100`. This is the load-bearing assertion — without it,
 *      a future refactor that drops the `_world_map_panel.layer =
 *      layer + 1` override at `DescendScreen._on_open_map_pressed`
 *      would silently regress visibility while every other assertion
 *      green-passes.
 *
 * **Bug class this catches:** "click-path render-only specs are
 * insufficient when production-active surface goes through a user-input
 * path." See `.claude/docs/test-conventions.md` §
 * "Button-click vs render-only spec discipline gap" (to be added by
 * doc-update line in the final report).
 *
 * **HTML5 visual-verification escape clause** — this spec verifies the
 * trace-observable contract (click → handler → mount → layer override).
 * It does NOT screenshot the visual render of the panel; Sponsor's
 * interactive soak remains the gate of record for "the parchment
 * actually reads" per the
 * `playwright-headless-vs-real-browser-perception` rule.
 *
 * Pattern source: `dialogue-hub-town.spec.ts` (trace-driven UI specs)
 * + `world-map-panel-render.spec.ts` (W2-T5 boot-smoke baseline).
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";

const BOOT_TIMEOUT_MS = 30_000;
const POST_CLICK_TRACE_WAIT_MS = 5_000;

test.describe(
  "DescendScreen Open Map button → WorldMapPanel mount path (W2-T5 fix / 86c9y10fv)",
  () => {
    test("click handler fires + panel mounts ABOVE DescendScreen layer", async ({
      page,
      context,
    }) => {
      await context.route("**/*", (route) => route.continue());
      const capture = new ConsoleCapture(page);
      capture.attach();

      const baseURL =
        process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
      // `?force_descend=1` opens the DescendScreen immediately after Room 01
      // boots — added by this PR's DebugFlags hook so Playwright doesn't
      // have to traverse 8 rooms + boss-kill to reach the descend surface.
      await page.goto(`${baseURL}/?force_descend=1`, {
        waitUntil: "domcontentloaded",
      });

      // 1. Wait for canonical Main-ready sentinel.
      await capture.waitForLine(
        /\[Main\] M1 play-loop ready/,
        BOOT_TIMEOUT_MS,
      );

      // 2. Confirm the force_descend hook fired (boot-line emitted from
      //    Main._ready). If this line is missing, the URL param didn't
      //    parse OR DebugFlags didn't read it — diagnose before the click
      //    assertions below add their own ambiguity.
      const forceLine = await capture
        .waitForLine(
          /\[Main\] DebugFlags\.force_descend=true/,
          BOOT_TIMEOUT_MS,
        )
        .catch(() => null);
      if (forceLine === null) {
        const recent = capture
          .getLines()
          .filter((l) => l.text.includes("[DebugFlags]"))
          .slice(-10)
          .map((l) => l.text)
          .join("\n");
        console.log(
          "[descent-portal-open-map-click] force_descend hook did NOT fire. " +
            "Recent [DebugFlags] lines:\n" +
            (recent || "(none)"),
        );
      }
      expect(forceLine).not.toBeNull();

      // 3. Settle one render frame so DescendScreen is in the tree + ready.
      //    The build also reports DebugFlags state line — we wait for the
      //    HTML5-only [combat-trace] to assert force-descend has taken effect.
      await page.waitForTimeout(500);

      // 4. Click the "Open Map" button. The button sits at offset_top=-180
      //    / offset_bottom=-148 against CENTER_BOTTOM anchor + offset_left
      //    =-80 / right=+80. On the 1280x720 canvas:
      //      - CENTER_BOTTOM x ≈ 640
      //      - CENTER_BOTTOM y ≈ 720
      //      - Button center ≈ (640, 720 - (180+148)/2) = (640, 720-164) = (640, 556)
      //
      //    Canvas-click via Playwright at that position. The
      //    DescendScreen's full-rect BG `mouse_filter = STOP` makes the
      //    button receive the click correctly.
      const canvas = await page.locator("canvas").first();
      await canvas.click({ position: { x: 640, y: 556 } });

      // 5. Assert the click-path entry trace fires. This is the load-
      //    bearing diagnostic that was MISSING pre-fix — Sponsor's RC
      //    soak had zero `[combat-trace] DescendScreen._on_open_map_pressed`
      //    lines, making the click path empirically invisible. Adding
      //    the trace + asserting it here pins the diagnostic contract.
      const clickTrace = await capture
        .waitForLine(
          /\[combat-trace\] DescendScreen\._on_open_map_pressed/,
          POST_CLICK_TRACE_WAIT_MS,
        )
        .catch(() => null);
      if (clickTrace === null) {
        const recent = capture
          .getLines()
          .filter((l) => l.text.includes("[combat-trace]"))
          .slice(-20)
          .map((l) => l.text)
          .join("\n");
        console.log(
          "[descent-portal-open-map-click] click-handler trace did NOT fire. " +
            "Recent [combat-trace] lines:\n" +
            (recent || "(none)"),
        );
      }
      expect(clickTrace).not.toBeNull();

      // 6. Assert the mount trace fires + extract the layer payload.
      //    Format: `[combat-trace] DescendScreen.world_map_mounted | layer=101`
      const mountTrace = await capture
        .waitForLine(
          /\[combat-trace\] DescendScreen\.world_map_mounted \| layer=\d+/,
          POST_CLICK_TRACE_WAIT_MS,
        )
        .catch(() => null);
      if (mountTrace === null) {
        const recent = capture
          .getLines()
          .filter((l) => l.text.includes("[combat-trace]"))
          .slice(-20)
          .map((l) => l.text)
          .join("\n");
        console.log(
          "[descent-portal-open-map-click] panel-mount trace did NOT fire. " +
            "Recent [combat-trace] lines:\n" +
            (recent || "(none)"),
        );
      }
      expect(mountTrace).not.toBeNull();

      // 7. REGRESSION PIN — assert the panel's runtime layer is ABOVE
      //    DescendScreen's authored layer (100). This is the structural
      //    pin for the Sponsor RC soak P0 bug class: "panel exists in
      //    tree but is rendered below the opaque host."
      const layerMatch = mountTrace?.text.match(/layer=(\d+)/);
      expect(layerMatch).not.toBeNull();
      const panelLayer = layerMatch ? parseInt(layerMatch[1], 10) : 0;
      expect(panelLayer).toBeGreaterThan(100);

      // 8. Assert the panel's own open trace fires — proves the panel
      //    reached _ready (not stuck on parse-time error or
      //    autoload mis-resolution). Same trace as
      //    world-map-panel-render.spec.ts's smoke step but here exercised
      //    via the click-driven mount path.
      const panelOpenTrace = await capture
        .waitForLine(
          /\[combat-trace\] WorldMapPanel\.opened/,
          POST_CLICK_TRACE_WAIT_MS,
        )
        .catch(() => null);
      if (panelOpenTrace === null) {
        const recent = capture
          .getLines()
          .filter((l) => l.text.includes("[combat-trace]"))
          .slice(-20)
          .map((l) => l.text)
          .join("\n");
        console.log(
          "[descent-portal-open-map-click] WorldMapPanel.opened did NOT " +
            "fire. Recent [combat-trace] lines:\n" +
            (recent || "(none)"),
        );
      }
      expect(panelOpenTrace).not.toBeNull();

      capture.detach();
    });
  },
);
