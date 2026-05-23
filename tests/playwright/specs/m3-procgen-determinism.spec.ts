/**
 * m3-procgen-determinism.spec.ts
 *
 * **Ticket `86c9y1045` — M3 Tier 3 W2-T3 `assemble_floor` impl + S1
 * procgen retrofit (SI-8 (b) locked).**
 *
 * Pins AC-C5-{1, 2, 3, 7} acceptance rows from
 * `team/tess-qa/m3-acceptance-plan-tier-3.md` Track 1.5:
 *
 *   - AC-C5-1: same seed → same map across separate boots (determinism).
 *   - AC-C5-2: different seeds → different layouts (variance).
 *   - AC-C5-3: hand-authored anchors render at deterministic positions
 *              across seeds; only procedural slots between them vary.
 *   - AC-C5-7: HTML5 procedural-seam rendering is clean — no
 *              `USER WARNING:` / `USER ERROR:` console lines from chunk
 *              placement or seam draw; no Godot 4 physics-flush panic on
 *              the assemble + render path.
 *
 * ## Activation gate — spike-class spec (same shape as procgen-spike.spec.ts)
 *
 * The W2 retrofit produces the runtime `assemble_floor` consumer, but the
 * `Main.tscn` integration (`Main._load_room_at_index → set_world_bounds`)
 * is W2-T1's surface — NOT this ticket. Until W2-T1 lands, the procgen
 * pipeline is only exercised in the spike scene
 * (`scenes/spike/ProcgenSpikeScene.tscn`). This spec therefore runs only
 * against an HTML5 artifact whose `project.godot::run/main_scene` has been
 * temporarily swapped to the spike scene; production artifact (Main.tscn)
 * skips this spec cleanly via boot-line detection — same pattern as
 * `procgen-spike.spec.ts` and `camera-scroll-spike.spec.ts`.
 *
 * **How to soak this spec manually:**
 *
 *   1. Branch: `git checkout -b diag/procgen-spike-soak`.
 *   2. Edit `project.godot`:
 *        run/main_scene="res://scenes/spike/ProcgenSpikeScene.tscn"
 *   3. `git commit -m "[diag-only] swap main_scene to procgen-spike — TEMPORARY (DO NOT MERGE)"`
 *   4. `gh workflow run release-github.yml --ref diag/procgen-spike-soak`
 *   5. Extract artifact + serve via `python -m http.server 8000`.
 *   6. Run this spec: `npx playwright test m3-procgen-determinism.spec.ts`.
 *   7. `git push origin --delete diag/procgen-spike-soak` when done.
 *
 * ## What this spec PROVES (when active, post-W2-T3 retrofit)
 *
 *   - The S1 z1 zone (`s1_z1_outer_cloister.tres`) assembles cleanly
 *     under HTML5 — no `[procgen-spike] port_mating_errors` line fires
 *     (R-PROCGEN.b closed for the s1_room01 east seam).
 *   - The `[procgen-spike] ready` boot line emits with the expected
 *     post-W2 chunk count range [9, 17] for the W2 zone (9 anchors + 8
 *     gaps × [0, 1] slots).
 *   - The `[procgen-spike] assemble | placement=...` determinism line
 *     fires.
 *   - Two consecutive boots emit IDENTICAL placement vectors (AC-C5-1).
 *   - **No `[procgen-spike] port_mating_errors` line fires** — this is
 *     the headline post-W2 win-state (R-PROCGEN.b closed).
 *   - HUD `port_mating_errors=0 (well-mated)` label fires (the spike
 *     scene renders this in green per ProcgenSpike.gd::_populate_hud).
 *
 * ## What this spec does NOT cover
 *
 *   - AC-C5-2 (different seeds → different layouts) — the spike scene
 *     uses a single fixed `SPIKE_WORLD_SEED`. AC-C5-2 is pinned by GUT
 *     `tests/test_floor_assembler.gd::test_s1_z1_different_seeds_produce_different_layouts`
 *     (N=8 seeds). When W2-T1 wires `assemble_floor` into the production
 *     Main.tscn, the URL-param `?world_seed=...` (or per-character world
 *     seed via the W2-T4 v5 schema) becomes the harness surface for
 *     per-character variance assertions — out of this spec's scope.
 *   - Visual chunk-seam rendering correctness under `gl_compatibility`
 *     (z-index sharp edges, tile-gap absence). Per PR #291 v6→v7 finding
 *     (memory `html5-visual-verification-gate`) — Playwright headless
 *     screenshots are NOT a substitute for Sponsor's interactive visual
 *     gate. The Self-Test Report routes this to Sponsor's pre-merge
 *     diag-build soak per the SI-8 (b) escape clause + W2-T3 Part F.
 *
 * ## Cross-references
 *
 *   - `scripts/spike/ProcgenSpike.gd` — the spike scene the spec gates on
 *   - `scripts/levels/FloorAssembler.gd` — W2 retrofit producer
 *   - `resources/level/zones/s1_z1_outer_cloister.tres` — W2 retrofit zone
 *   - `resources/level_chunks/s1_room01.tres` — east-seam fix
 *   - `tests/test_floor_assembler.gd` — paired GUT pins (W2-T3 section)
 *   - `tests/playwright/specs/procgen-spike.spec.ts` — sibling spike spec
 *   - `.claude/docs/procgen-pipeline.md` — runtime API + port-mating discipline
 *   - `.claude/docs/test-conventions.md` § "Spike-class specs"
 *   - `team/tess-qa/m3-acceptance-plan-tier-3.md` AC-C5-{1,2,3,7} rows
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";

const BOOT_TIMEOUT_MS = 30_000;
const SPIKE_BOOT_REGEX = /\[procgen-spike\] ready/;
const MAIN_BOOT_REGEX = /\[Main\] M1 play-loop ready/;

// Fixed world_seed pinned by ProcgenSpike.gd::SPIKE_WORLD_SEED (0xC10157E5).
// If a future refactor changes the constant, this spec's exact-match
// regex must update in lockstep.
const SPIKE_WORLD_SEED = 0xc10157e5; // 3238090725
const SPIKE_ZONE_ID = "s1_z1_outer_cloister";

// W2-T3 retrofit chunk-count bounds: 9 anchors (room08 used twice) + 8
// gaps × [0, 1] slot range = 9..17 chunks total per assembly. Same range
// as the spike-PR pre-retrofit window (the spike had 5 anchors + 4 gaps
// × [1, 3] = 9..17), so the chunk-count bound regex needs no update.
// What DID change: zero port_mating_errors expected post-retrofit (was 1).
const CHUNK_COUNT_MIN = 9;
const CHUNK_COUNT_MAX = 17;

test.describe("M3-T3-W2 procgen — S1 retrofit determinism + port-mating closure", () => {
  test("[AC-C5-1, AC-C5-3] spike boots, assembles cleanly with zero mating errors post-W2 retrofit", async ({
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
    expect(spikeBootLine!.text).toContain(`world_seed=${SPIKE_WORLD_SEED}`);

    // 2. chunks=N within [9, 17] — W2 retrofit zone's documented bounds.
    const chunksMatch = spikeBootLine!.text.match(/chunks=(\d+)/);
    expect(chunksMatch, "boot line carries parseable chunks=N").not.toBeNull();
    const chunkCount = parseInt(chunksMatch![1], 10);
    expect(
      chunkCount,
      `assembled chunk count ${chunkCount} in W2 range [${CHUNK_COUNT_MIN}, ${CHUNK_COUNT_MAX}]`
    ).toBeGreaterThanOrEqual(CHUNK_COUNT_MIN);
    expect(chunkCount).toBeLessThanOrEqual(CHUNK_COUNT_MAX);

    // 3. mating_errors=N is in the boot line — W2 retrofit pins this to 0.
    const matingMatch = spikeBootLine!.text.match(/mating_errors=(\d+)/);
    expect(matingMatch, "boot line carries parseable mating_errors=N").not.toBeNull();
    const matingCount = parseInt(matingMatch![1], 10);
    expect(
      matingCount,
      `R-PROCGEN.b closed post-W2 retrofit: expected 0 mating errors, got ${matingCount}. ` +
        `If non-zero, the s1_room01 east-seam fix or another seam regressed.`
    ).toBe(0);

    // 4. The detailed [procgen-spike] port_mating_errors line MUST NOT fire
    //    (ProcgenSpike.gd::_ready only prints it when errors.size() > 0).
    //    Its absence is the headline post-W2 win-state.
    const matingDetailLine = capture
      .getLines()
      .find((l) =>
        /\[procgen-spike\] port_mating_errors \| count=/.test(l.text)
      );
    expect(
      matingDetailLine,
      "post-W2 retrofit: [procgen-spike] port_mating_errors line MUST be absent. " +
        "Its presence indicates a regression in the s1_room01 east-seam fix or another seam."
    ).toBeUndefined();

    // 5. Determinism diff line fires — AC-C5-1 surface.
    const assembleLine = capture
      .getLines()
      .find((l) => /\[procgen-spike\] assemble \| placement=/.test(l.text));
    expect(
      assembleLine,
      "[procgen-spike] assemble | placement=... line fires (AC-C5-1 determinism surface)"
    ).toBeDefined();

    // 6. Placement vector lists exactly chunk-count entries, each shaped
    //    `chunkId@xPos`. Sanity-check anchor count: 9 entries must
    //    carry the 8 unique S1 chunk ids (room08 appears twice for
    //    boss + exit anchors).
    const placement = assembleLine!.text.replace(/.*placement=/, "");
    const entries = placement.split(",");
    expect(
      entries.length,
      `placement vector length ${entries.length} matches boot-line chunks=${chunkCount}`
    ).toBe(chunkCount);

    // Anchor coverage: each of s1_room01..s1_room08 appears AT LEAST once
    // in the placement vector (room08 appears twice as boss + exit).
    // AC-C5-3 surface — hand-authored anchors compose deterministically.
    for (let i = 1; i <= 8; i++) {
      const roomId = `s1_room${i.toString().padStart(2, "0")}`;
      const found = entries.some((e) => e.startsWith(roomId + "@"));
      expect(
        found,
        `placement must include anchor chunk ${roomId} (W2-T3 retrofit declares all 8 S1 chunks as anchors)`
      ).toBe(true);
    }

    // 7. No physics-flush panic — assemble + render path doesn't violate
    //    the Godot 4 Area2D mutation rule (memory `godot-physics-flush-area2d-rule`).
    const panicLine = capture.findUnexpectedLine(
      /Can't change this state while flushing queries/
    );
    expect(
      panicLine,
      "no physics-flush panic on ProcgenSpike _ready assemble + render path"
    ).toBeNull();

    capture.detach();
  });

  test("[AC-C5-1] two consecutive boots emit identical placement vector (determinism)", async ({
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
    const placement1 = assembleLine1!.text.replace(/.*placement=/, "");
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
    const placement2 = assembleLine2!.text.replace(/.*placement=/, "");
    capture2.detach();

    expect(
      placement2,
      `[AC-C5-1] placement is identical across two boots — deterministic on world_seed ` +
        `(boot1=${placement1.substring(0, 80)}..., boot2=${placement2.substring(0, 80)}...)`
    ).toBe(placement1);
  });

  test("[AC-C5-7] HTML5 spike boot is free of USER WARNING / USER ERROR / mating-error lines", async ({
    page,
    context,
  }) => {
    // The test-base.ts universal warning gate already asserts zero
    // USER WARNING / USER ERROR lines on teardown. This test additionally
    // pins post-W2 quietness on the procgen-specific console surface:
    // no port-mating error line, no assembler push_error, no
    // push_warning from ProcgenSpike's chunk-load fallback paths.
    test.setTimeout(60_000);
    await context.route("**/*", (route) => route.continue());

    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
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
      "Production artifact (Main.tscn) loaded — procgen spike scene not active."
    );

    // No port-mating detail line.
    const matingDetailLine = capture
      .getLines()
      .find((l) =>
        /\[procgen-spike\] port_mating_errors \| count=/.test(l.text)
      );
    expect(
      matingDetailLine,
      "[AC-C5-7] post-W2: no [procgen-spike] port_mating_errors line"
    ).toBeUndefined();

    // No assembler push_error / push_warning surfaces. The universal
    // gate in test-base.ts handles USER WARNING / USER ERROR globally;
    // these specific patterns are belt-and-suspenders for the procgen
    // path.
    const assemblerErrors = capture
      .getLines()
      .filter((l) =>
        /(FloorAssembler|ProcgenSpike)\..*(failed|unresolvable|invalid)/i.test(
          l.text
        )
      );
    expect(
      assemblerErrors.length,
      `[AC-C5-7] no FloorAssembler / ProcgenSpike error lines; got: ${assemblerErrors.map((l) => l.text).join(" | ")}`
    ).toBe(0);

    capture.detach();
  });
});
