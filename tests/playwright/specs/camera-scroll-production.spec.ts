/**
 * camera-scroll-production.spec.ts
 *
 * **Ticket `86c9y0zmg` — M3 Tier 3 W2-T1 (continuous-scroll integration +
 * S1 light retrofit).**
 *
 * Sibling of `camera-scroll-spike.spec.ts` (which exercises the spike scene
 * `scenes/spike/CameraScrollSpike.tscn`). This spec activates against the
 * PRODUCTION artifact (Main.tscn) and verifies the W2-T1 wiring lands:
 *
 *   - Main._load_room_at_index engages `CameraDirector.follow_target`
 *     against the player with the authored `(40, 24)` deadzone.
 *   - Main._load_room_at_index engages `CameraDirector.set_world_bounds`
 *     with the authored `Rect2(0, 0, 480, 270)` rect.
 *   - HUD remains pixel-anchored across camera motion (per the structural
 *     CanvasLayer-immunity guarantee — the W1 spike unit-pin
 *     `test_hud_canvaslayer_unaffected_by_continuous_scroll` proves the
 *     math; this spec confirms the production path engages the API at all).
 *   - Player walk emits `[combat-trace] CameraDirector.state` lines that
 *     reflect the live camera state (HUD-anchored consumers depend on the
 *     trace cadence).
 *
 * ## Activation gate
 *
 * Unlike `camera-scroll-spike.spec.ts`, this spec WAITS for the production
 * boot line `[Main] M1 play-loop ready` and SKIPS cleanly if the artifact
 * is a diag-build with a swapped main_scene (spike, boss-room-direct,
 * etc.). The skip lets the same Playwright suite run against both production
 * and diag artifacts without false failures.
 *
 * ## Why this spec exists (W2-T1 acceptance criterion)
 *
 * The W1 spike (PR #314) proved the deadzone-follow + bounds-clamp math
 * under HTML5 against a hand-stitched 3-chunk test scene. W2-T1 wires the
 * production play-loop to consume the same API on every room load. Without
 * this spec, the wiring could silently regress to "production never engages
 * the API" — the spike's smoke spec would stay green (it runs against the
 * spike scene), CI would be green, and the only failure surface would be
 * Sponsor manual soak.
 *
 * ## What this spec PROVES (when active)
 *
 *   - Production artifact boots cleanly (universal warning gate satisfied
 *     via test-base.ts) — no W2-T1 wiring regression introduced
 *     `USER WARNING:` / `USER ERROR:` console lines.
 *   - `[combat-trace] CameraDirector.follow_target` fires from Main with
 *     `target=Player deadzone=(40.0,24.0)` — production engages the API
 *     with the authored deadzone.
 *   - `[combat-trace] CameraDirector.set_world_bounds` fires from Main
 *     with `pos=(0,0) size=(480,270)` — production engages the API with
 *     the authored bounds.
 *   - No "Can't change this state while flushing queries" panic — the
 *     engage call is in a non-physics-flush path (post-player-re-parent,
 *     pre-_wire_room_signals). If a future refactor moved it into a
 *     physics-flush callback, this would catch it.
 *   - WASD walk emits additional `[combat-trace] CameraDirector.state`
 *     lines (cadence 0.25 s mirrors the Player.pos cadence). For the
 *     viewport-native S1 rooms (bounds.size = viewport_world at default
 *     zoom), the camera position stays at the bounds center across
 *     player motion (per `_clamp_to_world_bounds`'s
 *     "narrower than viewport" branch) — pre-T9-visual preservation.
 *
 * ## What this spec does NOT cover
 *
 *   - Visual rendering correctness in real interactive Chromium (HDR
 *     clamp, z-index, chunk-seam continuity). Per `test-conventions.md`
 *     § "Playwright headless ≠ real-browser perception", those require
 *     Sponsor / author interactive soak. The Self-Test Report covers
 *     those probe targets.
 *   - Wide-room camera motion. Current S1 rooms are viewport-native
 *     480×270; bounds-clamp branch keeps the camera centered. When
 *     W2-T3 procgen / a future room-widening ticket ships, this spec
 *     should be extended with an "actual camera motion" assertion
 *     (analogous to `camera-scroll-spike.spec.ts`'s WASD-walk test).
 *
 * ## Cross-references
 *
 *   - `scenes/Main.gd` — `_engage_camera_for_room` helper + room-load call
 *   - `scripts/levels/Stratum1BossRoom.gd` — `_engage_camera_for_boss_room`
 *     helper + deferred-fixture-pass call
 *   - `tests/test_main_camera_wiring.gd` — paired GUT pin for the wiring
 *   - `tests/test_camera_director.gd` — W1 spike unit pin
 *     `test_hud_canvaslayer_unaffected_by_continuous_scroll`
 *   - `.claude/docs/camera-scroll.md` § "Production wiring"
 *   - ClickUp `86c9y0zmg`
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";

const BOOT_TIMEOUT_MS = 30_000;
const MAIN_BOOT_REGEX = /\[Main\] M1 play-loop ready/;
const SPIKE_BOOT_REGEX = /\[CameraScrollSpike\] ready/;
const PROCGEN_SPIKE_BOOT_REGEX = /\[ProcgenSpike\] ready/;

// Authored constants — keep in sync with `Main.CAMERA_FOLLOW_DEADZONE`
// (`Vector2(40, 24)`) and `Main.S1_ROOM_BOUNDS` (`Rect2(0, 0, 480, 270)`).
// The GUT pin `test_main_engage_camera_helper_calls_follow_target_and_set_world_bounds`
// asserts source-side that the Main helper passes these constants.
const EXPECTED_FOLLOW_TRACE = /\[combat-trace\] CameraDirector\.follow_target \| target=Player deadzone=\(40\.0,24\.0\)/;
const EXPECTED_BOUNDS_TRACE = /\[combat-trace\] CameraDirector\.set_world_bounds \| pos=\(0,0\) size=\(480,270\)/;
const STATE_TRACE_REGEX = /\[combat-trace\] CameraDirector\.state \| zoom=[\d.]+ pos=\(\d+,\d+\)/;

test.describe("CameraDirector production wiring (M3-T3-W2-T1)", () => {
  test("Main.tscn boot engages follow_target + set_world_bounds with authored constants", async ({
    page,
    context,
  }) => {
    test.setTimeout(60_000);
    await context.route("**/*", (route) => route.continue());

    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(baseURL, { waitUntil: "domcontentloaded" });

    // Race: wait for EITHER the production boot line OR any known diag
    // boot line. If a diag boot line wins, skip cleanly so the spec
    // doesn't fail against a spike artifact.
    await Promise.race([
      capture.waitForLine(MAIN_BOOT_REGEX, BOOT_TIMEOUT_MS),
      capture.waitForLine(SPIKE_BOOT_REGEX, BOOT_TIMEOUT_MS),
      capture.waitForLine(PROCGEN_SPIKE_BOOT_REGEX, BOOT_TIMEOUT_MS),
    ]);

    const mainBootLine = capture
      .getLines()
      .find((l) => MAIN_BOOT_REGEX.test(l.text));

    test.skip(
      mainBootLine === undefined,
      "Non-production artifact (spike scene) loaded — this spec activates only against Main.tscn. " +
        "Run camera-scroll-spike.spec.ts / m3-procgen-determinism.spec.ts for diag artifacts."
    );

    // ---- Production artifact IS active — exercise assertions. ----

    // 1. CameraDirector.follow_target trace fires with the Player target +
    //    authored (40, 24) deadzone. The trace string format is fixed by
    //    `CameraDirector.follow_target`'s `df.combat_trace(...)` call;
    //    if Main wires the wrong deadzone (e.g. drift to (50, 30)),
    //    this regex fails LOUDLY.
    const followTrace = capture
      .getLines()
      .find((l) => EXPECTED_FOLLOW_TRACE.test(l.text));
    expect(
      followTrace,
      "Main._engage_camera_for_room fired CameraDirector.follow_target " +
        "with target=Player + (40.0,24.0) deadzone (authored W2-T1 contract)"
    ).toBeDefined();

    // 2. CameraDirector.set_world_bounds trace fires with the authored
    //    Rect2(0, 0, 480, 270). Mismatch would indicate Main passed a
    //    different rect (e.g. AssembledFloor.bounding_box_px swap before
    //    W2-T1 wiring expected — sequencing bug).
    const boundsTrace = capture
      .getLines()
      .find((l) => EXPECTED_BOUNDS_TRACE.test(l.text));
    expect(
      boundsTrace,
      "Main._engage_camera_for_room fired CameraDirector.set_world_bounds " +
        "with pos=(0,0) size=(480,270) (authored S1 room bounds)"
    ).toBeDefined();

    // 3. No physics-flush panic — engage call sits in a non-flush path.
    //    A future refactor moving the call into _wire_room_signals (which
    //    runs from a room_cleared callback chain that originates in a
    //    body_entered physics callback) would surface this panic.
    const panicLine = capture.findUnexpectedLine(
      /Can't change this state while flushing queries/
    );
    expect(
      panicLine,
      "no physics-flush panic on Main._engage_camera_for_room"
    ).toBeNull();

    // 4. BuildInfo SHA still emits — overall boot chain intact.
    const buildLine = capture
      .getLines()
      .find((l) => /\[BuildInfo\] build: [0-9a-f]{7}/.test(l.text));
    expect(
      buildLine,
      "BuildInfo SHA still emits — overall boot chain unbroken"
    ).toBeDefined();

    // 5. CameraDirector autoload boot line still emits — Main wiring did
    //    not break the autoload's own _ready.
    const cameraBootLine = capture
      .getLines()
      .find((l) =>
        /\[CameraDirector\] ready normalized_zoom=1\.000 baseline=\(2\.6667,2\.6667\)/.test(
          l.text
        )
      );
    expect(
      cameraBootLine,
      "CameraDirector autoload boot line still emits — autoload not broken " +
        "by Main's engage call"
    ).toBeDefined();

    capture.detach();
  });

  test("WASD walk emits CameraDirector.state traces; viewport-native room holds camera at bounds center", async ({
    page,
    context,
  }) => {
    test.setTimeout(60_000);
    await context.route("**/*", (route) => route.continue());

    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(baseURL, { waitUntil: "domcontentloaded" });

    await Promise.race([
      capture.waitForLine(MAIN_BOOT_REGEX, BOOT_TIMEOUT_MS),
      capture.waitForLine(SPIKE_BOOT_REGEX, BOOT_TIMEOUT_MS),
      capture.waitForLine(PROCGEN_SPIKE_BOOT_REGEX, BOOT_TIMEOUT_MS),
    ]);

    const mainBootLine = capture
      .getLines()
      .find((l) => MAIN_BOOT_REGEX.test(l.text));

    test.skip(
      mainBootLine === undefined,
      "Non-production artifact — skipping WASD-walk camera probe."
    );

    // Focus the canvas so keyboard events route to Godot.
    const canvas = page.locator("canvas").first();
    await canvas.focus();
    await page.waitForTimeout(800); // settle — at least one state-trace cadence (0.25 s)

    // Snapshot camera state pre-walk.
    const stateBefore = capture
      .getLines()
      .filter((l) => STATE_TRACE_REGEX.test(l.text));
    expect(
      stateBefore.length,
      "at least one CameraDirector.state trace fired pre-walk"
    ).toBeGreaterThan(0);
    const initialStateText = stateBefore[stateBefore.length - 1].text;
    const initialPosMatch = initialStateText.match(/pos=\((\d+),(\d+)\)/);
    expect(initialPosMatch, "initial state has parseable pos").not.toBeNull();
    const initialX = parseInt(initialPosMatch![1], 10);
    const initialY = parseInt(initialPosMatch![2], 10);

    // Walk right for 2 seconds. In Room 01 the player walks at 180 px/s
    // unimpeded, traveling ~360 px from spawn — well past the 40 px
    // deadzone. In a wide-bounds room the camera would shift; in S1's
    // viewport-native 480×270 room the bounds-clamp's "narrower than
    // viewport" branch holds the camera at bounds-center every tick.
    await page.keyboard.down("d");
    await page.waitForTimeout(2_000);
    await page.keyboard.up("d");
    await page.waitForTimeout(500);

    const stateAfter = capture
      .getLines()
      .filter((l) => STATE_TRACE_REGEX.test(l.text));
    expect(
      stateAfter.length,
      "additional CameraDirector.state traces fired post-walk"
    ).toBeGreaterThan(stateBefore.length);
    const finalStateText = stateAfter[stateAfter.length - 1].text;
    const finalPosMatch = finalStateText.match(/pos=\((\d+),(\d+)\)/);
    expect(finalPosMatch, "final state has parseable pos").not.toBeNull();
    const finalX = parseInt(finalPosMatch![1], 10);
    const finalY = parseInt(finalPosMatch![2], 10);

    // Camera HOLDS at bounds-center on viewport-native bounds.
    // bounds.size.x = 480; viewport_world.x at zoom 2.6667 = 480.
    // The "<=" branch in `_clamp_to_world_bounds` fires: camera.x =
    // bounds.position.x + bounds.size.x * 0.5 = 0 + 240 = 240.
    // Same for Y: 0 + 135 = 135.
    //
    // Tolerance: ±2 px for float rounding / per-tick precision drift.
    expect(
      Math.abs(finalX - 240),
      `viewport-native S1 room: camera.x stays at bounds center (240) — ` +
        `pre-T9 visual preservation. Got initialX=${initialX} finalX=${finalX}`
    ).toBeLessThanOrEqual(2);
    expect(
      Math.abs(finalY - 135),
      `viewport-native S1 room: camera.y stays at bounds center (135) — ` +
        `pre-T9 visual preservation. Got initialY=${initialY} finalY=${finalY}`
    ).toBeLessThanOrEqual(2);

    // No physics-flush panic during the walk + camera ticks.
    const panicLine = capture.findUnexpectedLine(
      /Can't change this state while flushing queries/
    );
    expect(
      panicLine,
      "no physics-flush panic during WASD walk + camera ticks"
    ).toBeNull();

    capture.detach();
  });
});
