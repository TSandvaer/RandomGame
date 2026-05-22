/**
 * camera-scroll-spike.spec.ts
 *
 * **Ticket `86c9xu9yt` — M3 Tier 3 W1 spike (continuous-scroll camera).**
 *
 * Verifies the spike scene `scenes/spike/CameraScrollSpike.tscn` boots
 * cleanly under HTML5 `gl_compatibility` and emits the expected
 * `[CameraScrollSpike] ready` line + `CameraDirector.follow_target` +
 * `CameraDirector.set_world_bounds` trace lines.
 *
 * ## Activation gate — spike-class spec, NOT auto-active in CI
 *
 * This spec runs only against an HTML5 artifact whose `project.godot::
 * run/main_scene` has been temporarily swapped to
 * `res://scenes/spike/CameraScrollSpike.tscn`. The production artifact
 * (Main.tscn as main scene) skips this spec cleanly via the boot-line
 * detection.
 *
 * **Why this shape (diag-build pattern, not CI-active):**
 * Per the W1 brief, the spike is intentionally lower blast-radius —
 * adding a `?spike=camera-scroll` URL hook in Main.gd would couple the
 * production play-loop to the spike. The diag-build pattern
 * (per `.claude/docs/html5-export.md` § "Diagnostic-build pattern")
 * is the established Embergrave shape for this class — author a `diag/*`
 * branch with `project.godot` main_scene swapped to the spike, trigger
 * release-build against the diag branch, run this spec against the
 * artifact, NEVER merge the diag branch.
 *
 * **How to soak this spec manually:**
 *
 *   1. Branch: `git checkout -b diag/camera-scroll-spike-soak`.
 *   2. Edit `project.godot`:
 *        run/main_scene="res://scenes/spike/CameraScrollSpike.tscn"
 *   3. `git commit -m "[diag-only] swap main_scene to camera-scroll-spike — TEMPORARY (DO NOT MERGE)"`
 *   4. `gh workflow run release-github.yml --ref diag/camera-scroll-spike-soak`
 *   5. Extract artifact + serve via `python -m http.server 8000`.
 *   6. Run this spec: `npx playwright test camera-scroll-spike.spec.ts`.
 *   7. `git push origin --delete diag/camera-scroll-spike-soak` when done.
 *
 * ## What this spec PROVES (when active)
 *
 *   - Spike scene boots without `USER WARNING:` / `USER ERROR:` console
 *     lines (universal warning gate via test-base.ts).
 *   - `[CameraScrollSpike] ready` line fires with spawn / deadzone /
 *     bounds matching the spike scene's tuning constants.
 *   - `[combat-trace] CameraDirector.follow_target` fires confirming the
 *     follow API was invoked with the PlayerMarker + (40, 24) deadzone.
 *   - `[combat-trace] CameraDirector.set_world_bounds` fires confirming
 *     the (0, 0, 1440, 270) clamp was set.
 *   - No "Can't change this state while flushing queries" panic — the
 *     CameraDirector's new mutation paths don't violate the Godot 4
 *     physics-flush rule on boot (per `godot-physics-flush-area2d-rule`).
 *
 * ## What this spec does NOT cover
 *
 *   - Visual scroll-rendering correctness — `gl_compatibility` chunk-seam
 *     z-index, tile-gap absence, HUD anchoring during scroll. Those are
 *     human-perception assertions that require Sponsor / author manual
 *     soak per `html5-visual-verification-gate` (PR #291 v6→v7 finding:
 *     Playwright headless screenshot evidence is NOT a substitute for
 *     real-browser interactive perception). The Self-Test Report covers
 *     those probe targets explicitly.
 *
 * ## Cross-references
 *
 *   - `scripts/spike/CameraScrollSpike.gd` — the spike scene under test
 *   - `tests/test_camera_director.gd` — GUT pins for follow + bounds math
 *   - `.claude/docs/html5-export.md` § "Diagnostic-build pattern"
 *   - `.claude/docs/test-conventions.md` § "Playwright headless ≠ real-browser perception"
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";

const BOOT_TIMEOUT_MS = 30_000;
const SPIKE_BOOT_REGEX = /\[CameraScrollSpike\] ready/;
const MAIN_BOOT_REGEX = /\[Main\] M1 play-loop ready/;

test.describe("CameraScrollSpike — M3-T3-W1 continuous-scroll spike", () => {
  test("spike scene boots cleanly with follow_target + world_bounds engaged", async ({
    page,
    context,
  }) => {
    test.setTimeout(60_000);
    await context.route("**/*", (route) => route.continue());

    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL =
      process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(baseURL, { waitUntil: "domcontentloaded" });

    // Race: wait for EITHER the spike boot line OR the Main boot line.
    // If Main boots, the artifact is production — skip cleanly.
    await Promise.race([
      capture.waitForLine(SPIKE_BOOT_REGEX, BOOT_TIMEOUT_MS),
      capture.waitForLine(MAIN_BOOT_REGEX, BOOT_TIMEOUT_MS),
    ]);

    const spikeBootLine = capture
      .getLines()
      .find((l) => SPIKE_BOOT_REGEX.test(l.text));

    test.skip(
      spikeBootLine === undefined,
      "Production artifact (Main.tscn) loaded — spike scene not active. " +
        "To activate: see file header for the diag-build workflow."
    );

    // ---- Spike scene IS active — exercise the assertions. ----

    // 1. Spike boot line carries expected configuration.
    expect(spikeBootLine!.text).toMatch(
      /spawn=\(240,135\) deadzone=\(40,24\) bounds=\(0,0,1440,270\)/
    );

    // 2. CameraDirector.follow_target trace fires confirming API invocation.
    const followTraceLine = capture
      .getLines()
      .find((l) =>
        /\[combat-trace\] CameraDirector\.follow_target \| target=PlayerMarker deadzone=\(40\.0,24\.0\)/.test(
          l.text
        )
      );
    expect(
      followTraceLine,
      "CameraDirector.follow_target trace fired with PlayerMarker target + (40, 24) deadzone"
    ).toBeDefined();

    // 3. CameraDirector.set_world_bounds trace fires confirming clamp set.
    const boundsTraceLine = capture
      .getLines()
      .find((l) =>
        /\[combat-trace\] CameraDirector\.set_world_bounds \| pos=\(0,0\) size=\(1440,270\)/.test(
          l.text
        )
      );
    expect(
      boundsTraceLine,
      "CameraDirector.set_world_bounds trace fired with (0,0,1440,270) bounds"
    ).toBeDefined();

    // 4. CameraDirector boot line still emits — autoload not broken by the
    //    spike scene's API calls.
    const cameraBootLine = capture
      .getLines()
      .find((l) =>
        /\[CameraDirector\] ready normalized_zoom=1\.000 baseline=\(2\.6667,2\.6667\)/.test(
          l.text
        )
      );
    expect(
      cameraBootLine,
      "CameraDirector boot line present — autoload survived spike scene boot"
    ).toBeDefined();

    // 5. BuildInfo SHA still emits — overall boot chain intact.
    const buildLine = capture
      .getLines()
      .find((l) => /\[BuildInfo\] build: [0-9a-f]{7}/.test(l.text));
    expect(
      buildLine,
      "BuildInfo SHA still emits — overall boot chain unbroken"
    ).toBeDefined();

    // 6. No physics-flush panic — follow_target / set_world_bounds run from
    //    _ready, idle time. If a future refactor pushed them into a physics
    //    tick callback (e.g. set on collision-detected), this would catch it.
    const panicLine = capture.findUnexpectedLine(
      /Can't change this state while flushing queries/
    );
    expect(
      panicLine,
      "no physics-flush panic on CameraDirector follow_target / set_world_bounds calls"
    ).toBeNull();

    capture.detach();
  });

  test("WASD walk emits CameraDirector.state trace with shifting position", async ({
    page,
    context,
  }) => {
    test.setTimeout(60_000);
    await context.route("**/*", (route) => route.continue());

    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL =
      process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(baseURL, { waitUntil: "domcontentloaded" });

    await Promise.race([
      capture.waitForLine(SPIKE_BOOT_REGEX, BOOT_TIMEOUT_MS),
      capture.waitForLine(MAIN_BOOT_REGEX, BOOT_TIMEOUT_MS),
    ]);

    const spikeBootLine = capture
      .getLines()
      .find((l) => SPIKE_BOOT_REGEX.test(l.text));

    test.skip(
      spikeBootLine === undefined,
      "Production artifact (Main.tscn) loaded — spike scene not active. " +
        "Skipping WASD-walk probe."
    );

    // Focus the canvas so keyboard events route to Godot.
    const canvas = page.locator("canvas").first();
    await canvas.focus();
    await page.waitForTimeout(500); // settle

    // Snapshot camera state before walking.
    const stateBefore = capture
      .getLines()
      .filter((l) =>
        /\[combat-trace\] CameraDirector\.state \| zoom=[\d.]+ pos=\(\d+,\d+\)/.test(
          l.text
        )
      );
    expect(
      stateBefore.length,
      "at least one CameraDirector.state trace fired pre-walk"
    ).toBeGreaterThan(0);
    const initialStateText = stateBefore[stateBefore.length - 1].text;
    const initialPosMatch = initialStateText.match(/pos=\((\d+),(\d+)\)/);
    expect(initialPosMatch, "initial state has parseable pos").not.toBeNull();
    const initialX = parseInt(initialPosMatch![1], 10);

    // Press D (move_right) for 3 seconds. The marker walks at 180 px/s
    // unimpeded, traveling ~540 px from spawn (240) — past x=520 (chunk1→2 seam)
    // AND past the deadzone, so the camera MUST shift right.
    await page.keyboard.down("KeyD");
    await page.waitForTimeout(3_000);
    await page.keyboard.up("KeyD");
    await page.waitForTimeout(500);

    const stateAfter = capture
      .getLines()
      .filter((l) =>
        /\[combat-trace\] CameraDirector\.state \| zoom=[\d.]+ pos=\(\d+,\d+\)/.test(
          l.text
        )
      );
    expect(
      stateAfter.length,
      "additional CameraDirector.state traces fired post-walk"
    ).toBeGreaterThan(stateBefore.length);
    const finalStateText = stateAfter[stateAfter.length - 1].text;
    const finalPosMatch = finalStateText.match(/pos=\((\d+),(\d+)\)/);
    const finalX = parseInt(finalPosMatch![1], 10);

    // Camera should have advanced past initial X. (Generous lower-bound:
    // even with browser-throttled keyboard repeat, 3 seconds of D-press
    // moves the camera at minimum 200 px from spawn — and the camera
    // tracks the marker minus the 40-px deadzone half-extent.)
    expect(
      finalX,
      `camera x advanced from ${initialX} → ${finalX} after WASD walk-right`
    ).toBeGreaterThan(initialX + 100);

    // Camera should NOT have advanced past the right-edge clamp.
    // Bounds 1440 wide, viewport at zoom 2.6667 = 480 wide, half = 240.
    // Max cam.x = 1440 - 240 = 1200. Tolerance: ±5 for float.
    expect(
      finalX,
      `camera x clamped at right world edge (max=1200, got ${finalX})`
    ).toBeLessThanOrEqual(1205);

    capture.detach();
  });
});
