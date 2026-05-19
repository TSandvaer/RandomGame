/**
 * player-walk-feel-decouple.spec.ts
 *
 * **Ticket 86c9va3f3 — M3W-2 walk-feel decouple regression spec (PR #274).**
 *
 * PR #274 shipped TWO parallel fixes to the Sponsor 2026-05-18 soak finding
 * "character looks at mouse cursor while walking":
 *
 *   1. **Fix #1 — `_resolve_anim_dir`** (`scripts/player/Player.gd:1672`).
 *      WALK / IDLE animation-name selection routes by movement-velocity
 *      octant, NOT by `_facing` (cursor / aim). Movement state animation
 *      keys use the velocity vector to pick `walk_<dir>` / `idle_<dir>`;
 *      ATTACK / DODGE / HIT / DIE continue to use mouse-derived `_facing`.
 *
 *   2. **Fix #2 — `_update_sprite_rotation`** (`scripts/player/Player.gd:1201`).
 *      The Sprite child (AnimatedSprite2D) `rotation` property is PINNED at
 *      0.0 in all states — directional frames carry the orientation, the
 *      node transform must stay identity. Pre-fix, the node was rotated to
 *      `_facing.angle()` (legacy from the symmetric-square ColorRect
 *      placeholder), which produced a "double-rotation that reads as 'the
 *      sprite is looking at the mouse cursor'" against the new directional
 *      art.
 *
 * **Why a Playwright spec is needed** (beyond the existing GUT pins —
 * `tests/test_player_mouse_facing.gd::test_sprite_rotation_stays_zero_across_facing`
 * + `tests/test_player_animation_wire.gd::test_walk_anim_velocity_octant_for_all_8_directions`):
 * the GUT side covers the helper math and the per-call wiring. What it
 * cannot cover is "the actual HTML5 release-build, with real keyboard input
 * driven through the browser canvas, behaves correctly across the
 * boot + walk + direction-change loop." Either fix surface could silently
 * re-couple to `_facing`:
 *
 *   - Fix #1 regression: someone restores `dir_suffix_for_facing(_facing)`
 *     for the WALK/IDLE branch of `_resolve_anim_dir`. Headless GUT spec
 *     `test_walk_anim_velocity_octant_for_all_8_directions` would catch it,
 *     but only if the test author remembers it exists. Browser-side, the
 *     released build would walk-east while WASD pointed north — caught
 *     here by parsing `[combat-trace] Player._play_anim | PLAY anim=walk_<dir>`
 *     lines.
 *
 *   - Fix #2 regression: someone deletes the `rotation = 0.0` pin or
 *     re-introduces a `rotation = _facing.angle()` setter elsewhere (e.g.
 *     in `_physics_process`, `_on_state_changed`, or a future
 *     state-machine refactor). Headless GUT spec
 *     `test_sprite_rotation_stays_zero_across_facing` covers the helper,
 *     but a regression at a DIFFERENT call site (or in `Player.tscn`'s
 *     scene-level rotation) would slip past. Browser-side, the sprite would
 *     visibly track the cursor mid-walk — caught here by parsing the
 *     `sprite_rot=` field in `[combat-trace] Player.pos` lines (added in
 *     this same PR to `Player._physics_process` for harness observability,
 *     analogous to the pre-existing `pos=(x,y)` field).
 *
 * **Spec strategy.** Both fixes are exercised under the same condition: the
 * player walks ONE direction (WASD) while the cursor points a DIFFERENT
 * direction (mouse aim). Pre-fix, animation name would track the cursor and
 * sprite rotation would track the cursor. Post-fix, animation name tracks
 * the velocity octant and sprite rotation stays 0.
 *
 *   - **Test 1 — north-walk-with-east-cursor.** Mouse pinned EAST
 *     (large offset, well outside the 8 px dead-zone). Press W (north).
 *     Walk for ~1.5 s. Assert:
 *       - `Player._play_anim | PLAY anim=walk_n` fires at least once.
 *       - NO `Player._play_anim | PLAY anim=walk_e`, `walk_ne`, or `walk_se`
 *         line emits during the walk (those would indicate Fix #1 regression).
 *       - Every `Player.pos | ... sprite_rot=<r>` line during the walk
 *         window has `|r| < 0.001` rad (those would indicate Fix #2 regression).
 *
 *   - **Test 2 — multi-direction sweep with stuck cursor.** Mouse pinned
 *     EAST throughout. Walk N, S, W in sequence (each ~1 s). Assert
 *     `walk_n`, `walk_s`, `walk_w` each appear at the appropriate phase,
 *     proving the anim-name resolver follows velocity not cursor across
 *     ALL cardinal-direction movement transitions. `sprite_rot=` stays
 *     ~0 throughout.
 *
 *   - **Test 3 — idle-with-cursor-rotation.** No WASD pressed. Mouse moves
 *     from EAST to SOUTH to WEST to NORTH (each 200 ms hold). Sprite
 *     rotation must remain ~0 — `_facing` changes (mouse-derived) but
 *     `_update_sprite_rotation` keeps the node transform identity. This
 *     pins Fix #2 against a regression that only manifests outside the
 *     WALK state (e.g. `_update_sprite_rotation` setting rotation =
 *     `_facing.angle()` while idle).
 *
 * **Sample-size discipline.** Each walk phase samples N ≥ 4 `Player.pos`
 * traces (every 0.25 s for ≥ 1 s of walking → 4 samples per phase, 12+
 * total across the multi-direction sweep). The anim-name check is binary
 * presence/absence per phase; on a regression the wrong-name line fires
 * within the first ~100 ms of velocity change because `_drive_walk_anim_if_moving`
 * runs every physics tick. No flake risk on N ≥ 4 sprite_rot samples — the
 * pin is mechanically deterministic (a single line that sets to 0 in
 * `_update_sprite_rotation`); any leak emits non-zero on the first frame.
 *
 * **Verification-via-revert** (per ticket AC#4, documented in the PR body's
 * Self-Test Report comment): both regressions were verified to flip this
 * spec RED by reverting Fix #1 and Fix #2 separately on a throwaway local
 * branch, then re-running the spec against a release-build of the reverted
 * code. The spec caught both reverts with clear failure messages naming
 * the regressed surface. Details in the Self-Test Report.
 *
 * References:
 *   - ClickUp 86c9va3f3 (this ticket)
 *   - PR #274 — the M3W-2 Player AnimatedSprite2D wiring (both fixes)
 *   - `.claude/docs/combat-architecture.md` §"Sprite-node topology, Seam 2:
 *     Player aim-rotation" — Resolution (PR #274, 2026-05-18)
 *   - `tests/test_player_mouse_facing.gd::test_sprite_rotation_stays_zero_across_facing` —
 *     GUT pin for Fix #2 (helper logic)
 *   - `tests/test_player_animation_wire.gd::test_walk_anim_velocity_octant_for_all_8_directions` —
 *     GUT pin for Fix #1 (anim-name resolver)
 *   - `tests/playwright/fixtures/mouse-facing.ts` — drift-pin convention for
 *     mouse-derived facing in Playwright specs; this spec follows the same
 *     "click-relative-to-player" rule
 */

// Universal-warning-gate import (per .claude/docs/test-conventions.md).
// The auto-attached fixture asserts no USER WARNING / USER ERROR on teardown.
import { test, expect } from "../fixtures/test-base";
import {
  AIM_OFFSET_MIN_PX,
  DEFAULT_PLAYER_SPAWN,
} from "../fixtures/mouse-facing";

const BOOT_TIMEOUT_MS = 30_000;

/**
 * Offset (px) used to pin the mouse aim relative to the player. Well above
 * `MOUSE_FACING_DEADZONE_PX = 8` and `AIM_OFFSET_MIN_PX = 100` so the
 * mouse-derived facing is reliably non-zero in the target direction.
 */
const AIM_OFFSET_PX = 250;

/**
 * Tolerance (rad) for the sprite-rotation assertion. `_update_sprite_rotation`
 * sets `sprite.rotation = 0.0` exactly — anything above floating-point noise
 * is a regression. The Player.pos trace emits sprite_rot with %.6f format,
 * so a regression of `rotation = _facing.angle()` (Fix #2 pre-state) would
 * show values in `[-π, π]` — orders of magnitude above this tolerance.
 */
const SPRITE_ROT_EPSILON_RAD = 1e-3;

/**
 * Parse all `[combat-trace] Player._play_anim | PLAY anim=<name>` lines
 * from the capture buffer, returning the resolved anim-name strings in
 * order. Skips the trailing "(walk-dir-change)" annotation so e.g.
 * `walk_e` and `walk_e (walk-dir-change)` both surface as `walk_e`.
 */
function getPlayAnimNames(
  lines: { text: string }[]
): string[] {
  const out: string[] = [];
  for (const l of lines) {
    const m = l.text.match(
      /\[combat-trace\] Player\._play_anim \| PLAY anim=([a-z_]+)/
    );
    if (m) out.push(m[1]);
  }
  return out;
}

/**
 * Parse all `[combat-trace] Player.pos | ... sprite_rot=<float>` lines from
 * the capture buffer, returning the rotation values (rad) in order.
 *
 * Pre-PR #86c9va3f3 builds emit `Player.pos` WITHOUT the `sprite_rot=` field
 * — the regex returns no matches and the test surfaces a clean "the trace
 * field is missing" error rather than silently passing.
 */
function getSpriteRotations(
  lines: { text: string }[]
): { text: string; rot: number }[] {
  const out: { text: string; rot: number }[] = [];
  for (const l of lines) {
    const m = l.text.match(
      /\[combat-trace\] Player\.pos \|.*sprite_rot=(-?\d+\.\d+)/
    );
    if (m) out.push({ text: l.text, rot: parseFloat(m[1]) });
  }
  return out;
}

test.describe("Player walk-feel decouple regression (PR #274, ticket 86c9va3f3)", () => {
  test("north-walk-with-east-cursor: anim follows velocity, sprite rotation pinned at 0", async ({
    page,
    consoleCapture,
    context,
  }) => {
    test.setTimeout(60_000);
    await context.route("**/*", (route) => route.continue());

    const baseURL = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(baseURL, { waitUntil: "domcontentloaded" });
    await consoleCapture.waitForLine(
      /\[Main\] M1 play-loop ready/,
      BOOT_TIMEOUT_MS
    );

    const canvas = page.locator("canvas").first();
    const canvasBB = await canvas.boundingBox();
    expect(canvasBB).not.toBeNull();
    await canvas.click(); // Focus + AudioContext unlock.
    await page.waitForTimeout(500); // Allow Player.pos to emit at least once.

    // ---- Pin mouse aim EAST of player (well outside dead-zone) -----------
    // No Camera2D in M1 — world coord == canvas pixel coord. Player spawns
    // at DEFAULT_PLAYER_SPAWN = (240, 200). Mouse at (240 + 250, 200) is
    // strongly east of player; |delta| = 250 px ≫ dead-zone 8 px so
    // `_facing` settles to (1, 0).
    const aimX = DEFAULT_PLAYER_SPAWN.x + AIM_OFFSET_PX;
    const aimY = DEFAULT_PLAYER_SPAWN.y;
    await page.mouse.move(canvasBB!.x + aimX, canvasBB!.y + aimY);
    await page.waitForTimeout(200); // Let _update_mouse_facing land at least one frame.

    // ---- Snapshot pre-walk line count ------------------------------------
    // We assert against lines emitted AFTER this point so boot-phase noise
    // (initial idle anim, pre-focus rotation jitter) doesn't pollute the
    // walk-phase observations.
    const preWalkLineCount = consoleCapture.getLines().length;

    // ---- Walk NORTH for 1.5 s --------------------------------------------
    // 1.5 s @ 0.25 s Player.pos throttle → ≥ 6 sprite_rot samples in the
    // walk window. 1.5 s is also long enough for the WALK state to settle
    // and `_drive_walk_anim_if_moving` to emit at least one `walk_n`.
    await page.keyboard.down("w");
    await page.waitForTimeout(1500);
    await page.keyboard.up("w");
    await page.waitForTimeout(200); // Catch the final Player.pos emit.

    // ---- Assertions ------------------------------------------------------
    const walkLines = consoleCapture.getLines().slice(preWalkLineCount);
    const animNames = getPlayAnimNames(walkLines);
    const rotations = getSpriteRotations(walkLines);

    // Surface 1 — anim follows velocity (north), NOT cursor (east).
    expect(
      animNames,
      `Expected at least one 'walk_n' anim during 1.5 s of W-key hold. ` +
        `Got anim names: ${JSON.stringify(animNames)}. ` +
        `Last 20 trace lines:\n${walkLines
          .slice(-20)
          .map((l) => `  ${l.text}`)
          .join("\n")}`
    ).toContain("walk_n");

    // The forbidden set: any anim name implying the cursor (east) won —
    // walk_e, walk_ne, walk_se are all east-leaning octants from the mouse
    // direction. Pre-Fix #1 the resolver would pick `walk_e` because
    // `_facing = (1, 0)`. Post-fix it picks `walk_n` from velocity.
    const forbidden = ["walk_e", "walk_ne", "walk_se"];
    for (const bad of forbidden) {
      expect(
        animNames,
        `Surface 1 regression: anim '${bad}' fired during W-key (north) ` +
          `walk while mouse was pinned EAST. Pre-Fix #1 (PR #274), the ` +
          `WALK branch of _resolve_anim_dir used _facing instead of ` +
          `velocity — cursor would win and east-leaning anims would play. ` +
          `Got anim names: ${JSON.stringify(animNames)}`
      ).not.toContain(bad);
    }

    // Surface 2 — sprite_rot stays ~0 across all walk-phase Player.pos lines.
    expect(
      rotations.length,
      `Expected ≥ 4 sprite_rot samples during 1.5 s walk @ 0.25 s ` +
        `Player.pos throttle. Got ${rotations.length}. If 0, the ` +
        `Player.pos trace probably did not pick up the sprite_rot= field — ` +
        `verify Player.gd:~458 still emits sprite_rot=%.6f. Walk-phase ` +
        `lines (last 20):\n${walkLines
          .slice(-20)
          .map((l) => `  ${l.text}`)
          .join("\n")}`
    ).toBeGreaterThanOrEqual(4);
    for (const sample of rotations) {
      expect(
        Math.abs(sample.rot),
        `Surface 2 regression: Sprite-node rotation ${sample.rot.toFixed(6)} ` +
          `exceeds tolerance ${SPRITE_ROT_EPSILON_RAD} rad. Pre-Fix #2 (PR #274), ` +
          `_update_sprite_rotation set rotation = _facing.angle() — mouse-east ` +
          `would produce sprite_rot ≈ 0 (atan2(0,1)=0), but ANY non-cardinal ` +
          `mouse position would leak. Spec runs with mouse EAST (atan2 ≈ 0); ` +
          `the multi-direction-sweep test exercises non-zero angles. Trace: ` +
          `"${sample.text}"`
      ).toBeLessThan(SPRITE_ROT_EPSILON_RAD);
    }
  });

  test("multi-direction sweep with stuck-east cursor: anim follows each WASD direction, sprite rotation never leaks", async ({
    page,
    consoleCapture,
    context,
  }) => {
    test.setTimeout(60_000);
    await context.route("**/*", (route) => route.continue());

    const baseURL = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(baseURL, { waitUntil: "domcontentloaded" });
    await consoleCapture.waitForLine(
      /\[Main\] M1 play-loop ready/,
      BOOT_TIMEOUT_MS
    );

    const canvas = page.locator("canvas").first();
    const canvasBB = await canvas.boundingBox();
    expect(canvasBB).not.toBeNull();
    await canvas.click();
    await page.waitForTimeout(500);

    // Pin mouse aim at SOUTHEAST of player — well off the cardinal axes so
    // a Fix #2 regression (`rotation = _facing.angle()`) would emit a
    // sprite_rot ≈ atan2(0.707, 0.707) ≈ 0.785 rad, easily over the epsilon.
    const aimX = DEFAULT_PLAYER_SPAWN.x + AIM_OFFSET_PX;
    const aimY = DEFAULT_PLAYER_SPAWN.y + AIM_OFFSET_PX;
    await page.mouse.move(canvasBB!.x + aimX, canvasBB!.y + aimY);
    await page.waitForTimeout(200);

    // Each phase: press key, walk 1 s, release, snapshot phase-anim-names.
    // We collect per-phase to assert ordering, not just presence — the
    // direction-key change must redirect anim within the same physics-frame
    // cadence (_drive_walk_anim_if_moving runs every tick).
    type Phase = { key: string; expectedAnim: string; label: string };
    const phases: Phase[] = [
      { key: "w", expectedAnim: "walk_n", label: "north (W)" },
      { key: "s", expectedAnim: "walk_s", label: "south (S)" },
      { key: "a", expectedAnim: "walk_w", label: "west (A)" },
    ];
    const phaseAnimResults: { label: string; names: string[] }[] = [];
    const allWalkLines: { text: string }[] = [];

    for (const phase of phases) {
      const preLineCount = consoleCapture.getLines().length;
      await page.keyboard.down(phase.key);
      await page.waitForTimeout(1000);
      await page.keyboard.up(phase.key);
      await page.waitForTimeout(300); // Catch the final Player.pos emit AND drain in-flight anim line.

      const phaseLines = consoleCapture.getLines().slice(preLineCount);
      const phaseAnims = getPlayAnimNames(phaseLines);
      phaseAnimResults.push({ label: phase.label, names: phaseAnims });
      allWalkLines.push(...phaseLines);
    }

    // Per-phase assertion — the expected anim must appear in its own phase.
    for (let i = 0; i < phases.length; i++) {
      const phase = phases[i];
      const got = phaseAnimResults[i].names;
      expect(
        got,
        `Phase ${i + 1} (${phase.label}): expected '${phase.expectedAnim}' ` +
          `during 1 s of '${phase.key}' key. Got anim names: ${JSON.stringify(got)}. ` +
          `Surface 1 regression: anim resolver may be using _facing (SE cursor) ` +
          `instead of velocity (${phase.label}).`
      ).toContain(phase.expectedAnim);
    }

    // Cross-phase forbidden — east-leaning anims should NEVER appear
    // during W/S/A (which respectively go N, S, W). If any phase produces
    // a `walk_se` / `walk_e`, Surface 1 is regressed.
    const sweepForbidden = ["walk_e", "walk_ne", "walk_se"];
    for (let i = 0; i < phases.length; i++) {
      const got = phaseAnimResults[i].names;
      for (const bad of sweepForbidden) {
        expect(
          got,
          `Phase ${i + 1} (${phases[i].label}): forbidden anim '${bad}' fired. ` +
            `Mouse pinned SE; expected anim '${phases[i].expectedAnim}'. ` +
            `Got: ${JSON.stringify(got)}. Surface 1 regression — see PR #274 fix #1.`
        ).not.toContain(bad);
      }
    }

    // Sprite rotation must stay ~0 across ALL phases (Surface 2). With
    // mouse aim at SE (angle ≈ +0.785 rad), a Fix #2 regression would emit
    // sprite_rot ≈ 0.785 on every Player.pos line — orders of magnitude
    // above SPRITE_ROT_EPSILON_RAD. Walking N/S/W doesn't matter — the
    // facing-derived rotation depends only on the cursor.
    const allRotations = getSpriteRotations(allWalkLines);
    expect(
      allRotations.length,
      `Expected ≥ 8 sprite_rot samples across 3 walk phases @ 0.25 s ` +
        `throttle. Got ${allRotations.length}. If 0, Player.pos may not be ` +
        `emitting sprite_rot= — verify Player.gd ~ line 458.`
    ).toBeGreaterThanOrEqual(8);
    for (const sample of allRotations) {
      expect(
        Math.abs(sample.rot),
        `Surface 2 regression: sprite_rot ${sample.rot.toFixed(6)} > ` +
          `epsilon ${SPRITE_ROT_EPSILON_RAD}. Mouse pinned SE during entire sweep. ` +
          `Pre-Fix #2, _update_sprite_rotation would set rotation = ` +
          `_facing.angle() ≈ +0.785 rad — flag any leak above epsilon. ` +
          `Trace: "${sample.text}"`
      ).toBeLessThan(SPRITE_ROT_EPSILON_RAD);
    }
  });

  test("idle-with-cursor-rotation: sprite rotation pinned at 0 even as cursor sweeps cardinals", async ({
    page,
    consoleCapture,
    context,
  }) => {
    test.setTimeout(60_000);
    await context.route("**/*", (route) => route.continue());

    const baseURL = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(baseURL, { waitUntil: "domcontentloaded" });
    await consoleCapture.waitForLine(
      /\[Main\] M1 play-loop ready/,
      BOOT_TIMEOUT_MS
    );

    const canvas = page.locator("canvas").first();
    const canvasBB = await canvas.boundingBox();
    expect(canvasBB).not.toBeNull();
    await canvas.click();
    await page.waitForTimeout(500);

    // Move the mouse through all 4 cardinals — `_facing` will track each
    // one (_update_mouse_facing is called every physics frame in IDLE).
    // _update_sprite_rotation must still pin rotation to 0 even though
    // `_facing` is changing. This pins Fix #2 against a regression that
    // only manifests in idle state — e.g. someone refactors
    // `_update_sprite_rotation` to set rotation = `_facing.angle()` for
    // the idle branch only (the WALK branch keeping 0 by accident).
    const aimPoints = [
      {
        x: DEFAULT_PLAYER_SPAWN.x + AIM_OFFSET_PX,
        y: DEFAULT_PLAYER_SPAWN.y,
        label: "E (facing.angle ≈ 0)",
      }, // East
      {
        x: DEFAULT_PLAYER_SPAWN.x,
        y: DEFAULT_PLAYER_SPAWN.y + AIM_OFFSET_PX,
        label: "S (facing.angle ≈ +π/2)",
      }, // South
      {
        x: Math.max(0, DEFAULT_PLAYER_SPAWN.x - AIM_OFFSET_PX),
        y: DEFAULT_PLAYER_SPAWN.y,
        label: "W (facing.angle ≈ ±π)",
      }, // West
      {
        x: DEFAULT_PLAYER_SPAWN.x,
        y: Math.max(0, DEFAULT_PLAYER_SPAWN.y - AIM_OFFSET_PX),
        label: "N (facing.angle ≈ -π/2)",
      }, // North
    ];

    const preLineCount = consoleCapture.getLines().length;
    for (const aim of aimPoints) {
      await page.mouse.move(canvasBB!.x + aim.x, canvasBB!.y + aim.y);
      await page.waitForTimeout(400); // ≥ 0.25 s so at least one Player.pos emits per aim.
    }
    const sweepLines = consoleCapture.getLines().slice(preLineCount);
    const rotations = getSpriteRotations(sweepLines);

    expect(
      rotations.length,
      `Expected ≥ 4 sprite_rot samples across cursor-sweep (4 cardinals @ ` +
        `0.4 s each = 1.6 s, ≥ 6 samples @ 0.25 s throttle). Got ${rotations.length}.`
    ).toBeGreaterThanOrEqual(4);
    for (const sample of rotations) {
      expect(
        Math.abs(sample.rot),
        `Surface 2 idle-regression: sprite_rot ${sample.rot.toFixed(6)} > ` +
          `epsilon ${SPRITE_ROT_EPSILON_RAD} while idle. Cursor swept E→S→W→N, ` +
          `each producing a distinct _facing.angle(). A regression where ` +
          `_update_sprite_rotation sets rotation = _facing.angle() (legacy ` +
          `pre-PR-#274 behavior) would surface a non-zero rotation at S, W, ` +
          `or N. Trace: "${sample.text}"`
      ).toBeLessThan(SPRITE_ROT_EPSILON_RAD);
    }
  });
});
