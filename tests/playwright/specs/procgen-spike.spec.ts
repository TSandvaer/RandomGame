/**
 * procgen-spike.spec.ts
 *
 * **Ticket `86c9xub9p` — M3 Tier 3 W1 spike (procgen `FloorAssembler` +
 * `AssembledFloor`).**
 *
 * Verifies the spike scene `scenes/spike/ProcgenSpikeScene.tscn` boots
 * cleanly under HTML5 `gl_compatibility` and emits the expected
 * `[procgen-spike] ready` line + `[procgen-spike] assemble | placement=...`
 * determinism line + (expected pre-W2) `[procgen-spike] port_mating_errors`
 * line surfacing the R-PROCGEN.b finding.
 *
 * ## Activation gate — spike-class spec, NOT auto-active in CI
 *
 * Same shape as `camera-scroll-spike.spec.ts` — this spec runs only
 * against an HTML5 artifact whose `project.godot::run/main_scene` has
 * been temporarily swapped to `res://scenes/spike/ProcgenSpikeScene.tscn`.
 * The production artifact (Main.tscn as main scene) skips this spec
 * cleanly via the boot-line detection.
 *
 * **Why this shape (diag-build pattern, not CI-active):**
 * Adding a `?spike=procgen` URL hook in Main.gd would couple the
 * production play-loop to the spike. The diag-build pattern (per
 * `.claude/docs/html5-export.md` § "Diagnostic-build pattern") is the
 * established Embergrave shape for this class.
 *
 * **How to soak this spec manually:**
 *
 *   1. Branch: `git checkout -b diag/procgen-spike-soak`.
 *   2. Edit `project.godot`:
 *        run/main_scene="res://scenes/spike/ProcgenSpikeScene.tscn"
 *   3. `git commit -m "[diag-only] swap main_scene to procgen-spike — TEMPORARY (DO NOT MERGE)"`
 *   4. `gh workflow run release-github.yml --ref diag/procgen-spike-soak`
 *   5. Extract artifact + serve via `python -m http.server 8000`.
 *   6. Run this spec: `npx playwright test procgen-spike.spec.ts`.
 *   7. `git push origin --delete diag/procgen-spike-soak` when done.
 *
 * ## What this spec PROVES (when active)
 *
 *   - Spike scene boots without `USER WARNING:` / `USER ERROR:` console
 *     lines that aren't deliberately expected (universal warning gate via
 *     test-base.ts). The R-PROCGEN.b empirical port-mating finding fires
 *     as a `print` line via `[procgen-spike] port_mating_errors`, NOT as
 *     a `push_warning` — the assembler records-not-raises by design.
 *   - `[procgen-spike] ready` line fires with `world_seed`, chunk count,
 *     bounds, and mating-error count matching the spike's tuning constants.
 *   - `[procgen-spike] assemble | placement=...` line fires — the
 *     determinism diff vector that a re-soak with the same seed can
 *     compare against.
 *   - **Determinism assertion**: TWO separate boots (`page.goto` twice)
 *     emit IDENTICAL `[procgen-spike] assemble | placement=...` strings.
 *     This is the spec-side proof that the seed → placement pipeline
 *     is deterministic across browser sessions.
 *   - No "Can't change this state while flushing queries" panic — the
 *     ProcgenSpike's `_ready` mutations (ColorRect adds for floor chunks,
 *     CameraDirector follow_target / set_world_bounds) don't violate
 *     the Godot 4 physics-flush rule on boot.
 *
 * ## What this spec does NOT cover
 *
 *   - Visual chunk-floor rendering correctness — `gl_compatibility`
 *     chunk-seam z-index, tile-gap absence, HUD anchoring during scroll.
 *     Those are human-perception assertions that require Sponsor /
 *     author manual soak per `html5-visual-verification-gate` (PR #291
 *     v6→v7 finding: Playwright headless screenshot evidence is NOT a
 *     substitute for real-browser interactive perception). The
 *     Self-Test Report covers those probe targets explicitly.
 *
 * ## Cross-references
 *
 *   - `scripts/spike/ProcgenSpike.gd` — the spike scene under test
 *   - `scripts/levels/FloorAssembler.gd` — Part A producer
 *   - `tests/test_floor_assembler.gd` — Part A GUT pins
 *   - `tests/test_world_seed_persists_across_save_load.gd` — Part B pin
 *   - `.claude/docs/html5-export.md` § "Diagnostic-build pattern"
 *   - `.claude/docs/test-conventions.md` § "Spike-class specs"
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";

const BOOT_TIMEOUT_MS = 30_000;
const SPIKE_BOOT_REGEX = /\[procgen-spike\] ready/;
const MAIN_BOOT_REGEX = /\[Main\] M1 play-loop ready/;

// The fixed world_seed pinned by ProcgenSpike.gd::SPIKE_WORLD_SEED (0xC10157E5).
// If a future refactor changes the constant, this spec's exact-match
// regex must be updated in lockstep.
const SPIKE_WORLD_SEED = 0xc10157e5; // 3238090725 (verified against Godot %d output)
const SPIKE_ZONE_ID = "s1_z1_outer_cloister";

test.describe("ProcgenSpike — M3-T3-W1 procgen visual proof scene", () => {
  test("spike scene boots cleanly and emits assemble line", async ({
    page,
    context,
  }) => {
    test.setTimeout(60_000);
    await context.route("**/*", (route) => route.continue());

    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(baseURL, { waitUntil: "domcontentloaded" });

    // Race: spike boot line OR Main boot line.
    await Promise.race([
      capture.waitForLine(SPIKE_BOOT_REGEX, BOOT_TIMEOUT_MS),
      capture.waitForLine(MAIN_BOOT_REGEX, BOOT_TIMEOUT_MS),
    ]);

    const spikeBootLine = capture
      .getLines()
      .find((l) => SPIKE_BOOT_REGEX.test(l.text));

    test.skip(
      spikeBootLine === undefined,
      "Production artifact (Main.tscn) loaded — procgen spike scene not active. " +
        "To activate: see file header for the diag-build workflow."
    );

    // 1. Spike boot line carries the expected world_seed + zone_id.
    expect(spikeBootLine!.text).toContain(`zone=${SPIKE_ZONE_ID}`);
    expect(spikeBootLine!.text).toContain(
      `world_seed=${SPIKE_WORLD_SEED}`
    );
    // chunks=N where N ∈ [9, 17] — the worked-example zone has 5 anchors
    // + 4 gaps × [1, 3] slots = total ∈ [9, 17].
    const chunksMatch = spikeBootLine!.text.match(/chunks=(\d+)/);
    expect(chunksMatch, "boot line carries parseable chunks=N").not.toBeNull();
    const chunkCount = parseInt(chunksMatch![1], 10);
    expect(
      chunkCount,
      `assembled chunk count ${chunkCount} in expected range [9, 17]`
    ).toBeGreaterThanOrEqual(9);
    expect(chunkCount).toBeLessThanOrEqual(17);

    // 2. Determinism diff line fires (`[procgen-spike] assemble |
    //    placement=...`).
    const assembleLine = capture
      .getLines()
      .find((l) => /\[procgen-spike\] assemble \| placement=/.test(l.text));
    expect(
      assembleLine,
      "[procgen-spike] assemble | placement=... line fires (determinism diff)"
    ).toBeDefined();

    // 3. R-PROCGEN.b empirical state: the worked-example zone currently
    //    has 1 known port-mating error (s1_room01 east seam — the
    //    production chunk lacks an EAST exit port). Pinned by
    //    test_assemble_authored_s1_z1_records_s1_room01_east_seam_finding
    //    in test_floor_assembler.gd. Until the W2 retrofit fixes
    //    s1_room01, the spike scene surfaces this error count as
    //    PROOF Q2 data, not a regression.
    const matingLine = capture
      .getLines()
      .find((l) =>
        /\[procgen-spike\] port_mating_errors \| count=(\d+) first=/.test(
          l.text
        )
      );
    if (matingLine !== undefined) {
      const countMatch = matingLine.text.match(/count=(\d+)/);
      expect(countMatch, "port_mating_errors line has parseable count").not.toBeNull();
      const count = parseInt(countMatch![1], 10);
      // Expect 1 at spike-time (R-PROCGEN.b empirical). If the W2
      // retrofit lands and this drops to 0, the line will be absent
      // entirely (ProcgenSpike.gd only prints when errors.size() > 0).
      expect(
        count,
        `R-PROCGEN.b: at spike time, expect exactly 1 mating error (got ${count})`
      ).toBe(1);
    }
    // If matingLine is undefined, the W2 retrofit has landed and the
    // worked-example zone is well-mated — that's the win-state for SI-8.

    // 4. CameraDirector boot line still emits — autoload not broken by
    //    the spike scene's API calls.
    const cameraBootLine = capture
      .getLines()
      .find((l) =>
        /\[CameraDirector\] ready normalized_zoom=1\.000/.test(l.text)
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

    // 6. No physics-flush panic on _ready mutations (ColorRect adds for
    //    floor chunks, follow_target / set_world_bounds engages).
    const panicLine = capture.findUnexpectedLine(
      /Can't change this state while flushing queries/
    );
    expect(
      panicLine,
      "no physics-flush panic on ProcgenSpike _ready mutations"
    ).toBeNull();

    capture.detach();
  });

  test("two consecutive boots emit identical placement vector (determinism)", async ({
    page,
    context,
  }) => {
    test.setTimeout(120_000);
    await context.route("**/*", (route) => route.continue());

    // Boot 1.
    const capture1 = new ConsoleCapture(page);
    capture1.attach();
    const baseURL = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(baseURL, { waitUntil: "domcontentloaded" });

    await Promise.race([
      capture1.waitForLine(SPIKE_BOOT_REGEX, BOOT_TIMEOUT_MS),
      capture1.waitForLine(MAIN_BOOT_REGEX, BOOT_TIMEOUT_MS),
    ]);

    const spikeBootLine1 = capture1
      .getLines()
      .find((l) => SPIKE_BOOT_REGEX.test(l.text));
    test.skip(
      spikeBootLine1 === undefined,
      "Production artifact (Main.tscn) loaded — procgen spike scene not active."
    );

    const assembleLine1 = capture1
      .getLines()
      .find((l) => /\[procgen-spike\] assemble \| placement=/.test(l.text));
    expect(assembleLine1, "boot 1 emits assemble line").toBeDefined();
    const placement1 = assembleLine1!.text.replace(
      /.*placement=/,
      ""
    );
    capture1.detach();

    // Boot 2 — fresh navigation, fresh capture.
    const capture2 = new ConsoleCapture(page);
    capture2.attach();
    await page.goto(baseURL, { waitUntil: "domcontentloaded" });

    await Promise.race([
      capture2.waitForLine(SPIKE_BOOT_REGEX, BOOT_TIMEOUT_MS),
      capture2.waitForLine(MAIN_BOOT_REGEX, BOOT_TIMEOUT_MS),
    ]);

    const assembleLine2 = capture2
      .getLines()
      .find((l) => /\[procgen-spike\] assemble \| placement=/.test(l.text));
    expect(assembleLine2, "boot 2 emits assemble line").toBeDefined();
    const placement2 = assembleLine2!.text.replace(
      /.*placement=/,
      ""
    );
    capture2.detach();

    expect(
      placement2,
      `placement is identical across two boots — deterministic on world_seed (boot1=${placement1.substring(0, 80)}..., boot2=${placement2.substring(0, 80)}...)`
    ).toBe(placement1);
  });
});
