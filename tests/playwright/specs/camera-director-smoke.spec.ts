/**
 * camera-director-smoke.spec.ts
 *
 * **Ticket `86c9wjyf3` — M3 Tier 2 Wave 2 T9 (CameraDirector autoload).**
 *
 * Verifies the Camera2D autoload lands cleanly in the HTML5 release build
 * without:
 *   - Regressing the boot sequence (`[Main] M1 play-loop ready` line still fires).
 *   - Surfacing `USER WARNING:` / `USER ERROR:` lines from the camera path
 *     (caught by the universal warning gate via `test-base.ts`).
 *   - Triggering any "Can't change this state while flushing queries" panic
 *     (Camera2D + Viewport interactions on the boot tick).
 *   - Producing renderer console errors specific to `gl_compatibility` +
 *     Camera2D zoom (z-index / canvas_transform issues from `html5-export.md`).
 *
 * **What's NOT covered here** (intentional):
 *   - Audible / visual confirmation of zoom transitions at non-default scales.
 *     T9 ships at default 1.0× zoom — no zoom-in tween fires on boot. T16's
 *     ember-rise + 1.5× ease-in is the layer that exercises non-default zoom.
 *     T9 boot-soak only proves the camera is structurally present + non-disruptive.
 *   - Player-follow tracking. Headless GUT (`test_camera_director.gd`) covers
 *     the snap-follow contract; HTML5 spec would need a way to read `Camera2D.global_position`
 *     from JS which Godot doesn't expose. Sponsor-soak is the visual gate.
 *
 * **Trace observability:** if a follow-up PR adds a `request_zoom` debug
 * trigger (e.g. `?camera=1.5` URL-param), a future spec can probe the
 * `[combat-trace] CameraDirector.request_zoom` line. Today no boot path
 * fires `request_zoom`, so this spec only confirms the boot-time print
 * statement.
 *
 * **Why this spec is part of T9's PR:** the HTML5 visual-verification gate
 * (`.claude/docs/html5-export.md`) applies to any Camera2D PR. Headless GUT
 * cannot exercise the gl_compatibility renderer; this spec is the
 * complementary Playwright surface that catches HTML5-specific divergence.
 *
 * **Cross-references:**
 *   - `scripts/camera/CameraDirector.gd` — the autoload under test
 *   - `tests/test_camera_director.gd` — GUT-side paired tests
 *   - `team/devon-dev/camera2d-spike.md` — spike doc + design rationale
 *   - `.claude/docs/html5-export.md` — visual-verification gate
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";

const BOOT_TIMEOUT_MS = 30_000;

test.describe("CameraDirector boot smoke (M3-T2-W2-T9)", () => {
  test("build boots cleanly with CameraDirector autoload active", async ({ page, context }) => {
    test.setTimeout(60_000);
    await context.route("**/*", (route) => route.continue());

    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(baseURL, { waitUntil: "domcontentloaded" });

    // Boot path must complete cleanly. If the CameraDirector autoload
    // crashes during _ready, this never fires.
    await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);

    // CameraDirector emits a single boot-time line confirming it initialized
    // with the calibrated baseline (normalized 1.0 == BASELINE_ZOOM 2.6667).
    const cameraBootLine = capture
      .getLines()
      .find((l) => /\[CameraDirector\] ready normalized_zoom=1\.000 baseline=\(2\.6667,2\.6667\)/.test(l.text));
    expect(cameraBootLine, "CameraDirector boot line present with calibrated baseline").toBeDefined();

    // No Camera2D + physics-flush class panic. The autoload's `_ready`
    // calls `Camera2D.make_current()` which writes to the viewport's
    // canvas_transform — if this happened from a physics tick path, Godot
    // would raise "Can't change this state while flushing queries." It
    // doesn't, because `_ready` runs at idle time, but the assertion
    // pins the contract.
    const panicLine = capture.findUnexpectedLine(
      /Can't change this state while flushing queries/
    );
    expect(panicLine, "no physics-flush panic on Camera2D init").toBeNull();

    // BuildInfo SHA still emits — overall boot chain intact.
    const buildLine = capture
      .getLines()
      .find((l) => /\[BuildInfo\] build: [0-9a-f]{7}/.test(l.text));
    expect(buildLine, "BuildInfo SHA still emits — overall boot chain unbroken").toBeDefined();

    // No `request_zoom` calls fired on boot — the default 1.0× state is
    // applied directly via Camera2D.zoom = BASELINE_ZOOM in _ready, not
    // via the request_zoom path. A trace line here would mean some other
    // code path silently kicked off a zoom (unexpected).
    const unexpectedTrace = capture
      .getLines()
      .find((l) => /\[combat-trace\] CameraDirector\.request_zoom/.test(l.text));
    expect(unexpectedTrace, "no spurious request_zoom call on boot").toBeUndefined();

    capture.detach();
  });
});
