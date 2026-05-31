/**
 * stratum2-boss-room.spec.ts
 *
 * **W3-T7 Stage 6 (ticket `86c9y7ygj`) — Stratum2BossRoom production wiring.**
 *
 * Through Stages 1-5 the Stratum2BossRoom was authored standalone with NO
 * `Main._load_room_at_index` consumer — unreachable in production play, only
 * bootable via a diag-build `main_scene` swap (no Player → camera couldn't
 * follow → Sentinel out of frame). Stage 6 wires it as the terminal index
 * `Main.S2_BOSS_ROOM_INDEX = 9`, reachable via the production room-load path
 * and the `?start_room=9` debug hook (`DebugFlags.START_ROOM_MAX` raised 8→9).
 *
 * This spec boots into the boss room via the PRODUCTION path — `?start_room=9`
 * against the production Main.tscn artifact — so a real Player spawns and is
 * re-parented into the boss room. That makes the boss room's continuous-scroll
 * camera engage actually follow the player (and renders the Sentinel in-frame,
 * fixing the Stage-5 NIT #2 diag-soak out-of-viewport artifact).
 *
 * ## What this spec PROVES (when active)
 *
 *   1. Boot reaches the S2 boss room via production load (`?start_room=9`) —
 *      the `[Main] DebugFlags.start_room=9 — bypassing Room 01 traversal` line.
 *   2. Continuous-scroll camera engages against the 1024×768 arena bounds —
 *      `[combat-trace] CameraDirector.set_world_bounds | pos=(0,0) size=(1024,768)`
 *      (wider than the S1 480×270; the bounds-clamp takes the FOLLOW branch,
 *      not the centered-hold branch — the camera actually scrolls).
 *   3. Continuous-scroll follow engages with the authored (40,24) deadzone —
 *      `[combat-trace] CameraDirector.follow_target | target=Player deadzone=(40.0,24.0)`.
 *   4. The boss wakes — `[combat-trace] ArchiveSentinel.wake` fires after the
 *      1.8 s entry sequence elapses (the deferred fixture pass auto-fires the
 *      sequence; production load teleports the player in without a physics
 *      overlap so the auto-fire is the wake path).
 *   5. The universal console-warning gate is satisfied — NO `USER WARNING:` /
 *      `USER ERROR:` lines (test-base.ts teardown enforces this). The new
 *      Main wiring + nameplate spawn introduce no warning leaks.
 *   6. No physics-flush panic — the boss room's deferred fixture pass keeps
 *      the Area2D inserts out of the flush window.
 *
 * ## Activation gate
 *
 * Skips cleanly if the artifact is a diag-build with a swapped main_scene
 * (the production boot line `[Main] M1 play-loop ready` is absent) — mirrors
 * `camera-scroll-production.spec.ts`'s race-then-skip pattern so the same
 * suite runs against both production and diag artifacts without false fails.
 *
 * ## What this spec does NOT cover
 *
 *   - Visual rendering correctness in real interactive Chromium (slam-AOE
 *     telegraph arc, hit-flash modulate, death-burst particles). Per
 *     `test-conventions.md` § "Playwright headless ≠ real-browser perception"
 *     those require the author/Sponsor interactive soak — the Self-Test
 *     Report covers those probe targets against the same `?start_room=9`
 *     production build.
 *   - Full boss kill-to-descend flow (the Sentinel is a 700-HP 2-phase boss;
 *     a kill-through spec belongs with a future S2 AC spec, not this smoke).
 *
 * ## Cross-references
 *   - `scenes/Main.gd` — `ROOM_SCENE_PATHS[9]` + shared boss-room branch
 *   - `scripts/levels/Stratum2BossRoom.gd` — `_engage_camera_for_boss_room`
 *   - `tests/test_main_s2_boss_room_wiring.gd` — paired GUT pin
 *   - `.claude/docs/camera-scroll.md` § "Production wiring"
 *   - ClickUp `86c9y7ygj` (W3-T7 Stage 6)
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";

const BOOT_TIMEOUT_MS = 30_000;
const MAIN_BOOT_REGEX = /\[Main\] M1 play-loop ready/;
const SPIKE_BOOT_REGEX = /\[CameraScrollSpike\] ready/;
const PROCGEN_SPIKE_BOOT_REGEX = /\[ProcgenSpike\] ready/;

// `?start_room=9` bypass line (HTML5-only; DebugFlags reads the URL param).
const START_ROOM_9_REGEX = /\[Main\] DebugFlags\.start_room=9 — bypassing Room 01 traversal/;

// Boss-room camera engage traces. Bounds are the 1024×768 arena (WIDER than
// the S1 480×270 viewport-native rooms), so the bounds-clamp takes the follow
// branch — the camera scrolls rather than centering+holding.
const ARENA_BOUNDS_TRACE = /\[combat-trace\] CameraDirector\.set_world_bounds \| pos=\(0,0\) size=\(1024,768\)/;
const FOLLOW_TRACE = /\[combat-trace\] CameraDirector\.follow_target \| target=Player deadzone=\(40\.0,24\.0\)/;
const SENTINEL_WAKE_TRACE = /\[combat-trace\] ArchiveSentinel\.wake/;

// Cast attack traces. `_fire_cast` is the DAMAGE event (a bare invisible
// Area2D hitbox); `_spawn_cast_bolt` is the concurrent VISIBLE attack-visual
// node. The regression these guard against: damage landing with NO visible
// attack (Sponsor re-soak 2026-05-29 — "HP just drops, nothing visible").
const CAST_FIRE_TRACE = /\[combat-trace\] ArchiveSentinel\._fire_cast \|/;
const CAST_BOLT_TRACE = /\[combat-trace\] ArchiveSentinel\._spawn_cast_bolt \| visible cast bolt/;

// Renderer-observable visibility trace emitted from the bolt's OWN _ready (after
// the deferred add lands — modulate / z / visible are on-screen truth, NOT
// spawn-intent). `visible=true alpha>0 z>=0 color_rect=true` is the assertable
// "the attack node is actually visible at the moment the cast lands" signal.
// This is STRONGER than the spawn-trace implication: it proves not just that a
// node was spawned, but that the spawned node is in a renderable state.
const CAST_BOLT_VISIBLE_TRACE =
  /\[combat-trace\] ArchiveSentinelCastBolt\._ready \| VISIBLE bolt pos=\([-\d]+,[-\d]+\) visible=true alpha=([\d.]+) z=(\d+) color_rect=true/;

// Phase-2 slam-telegraph trace. `_begin_slam_telegraph` spawns the renderer-safe
// `draw_arc` AOE indicator (`_spawn_slam_indicator`). Slam is phase-2-only
// (HP ≤ 50%) + requires the player within SLAM_HITBOX_RADIUS, so a passive
// `?start_room=9` boot does NOT reach it — this implication guard only fires IF
// a slam telegraph occurs (defends against a future invisible-slam regression
// without fabricating a phase-2 harness drive; phase-2 render is proven by the
// GUT pin + the author self-soak screenshot). `_fire_slam_hit` is the damage;
// `_spawn_slam_indicator` is the visible telegraph that MUST precede it.
const SLAM_FIRE_TRACE = /\[combat-trace\] ArchiveSentinel\._fire_slam_hit \|/;
const SLAM_INDICATOR_TRACE = /\[combat-trace\] ArchiveSentinel\._spawn_slam_indicator \| radius=/;

// Phase-blink reposition traces (W3-T7 Stage 6 — Uma §5.5a; RETUNE `d101b83`
// 2026-05-31). The Sentinel blinks (instant reposition + VFX) at the tail of a
// completed cast volley, gated post-retune by THREE conditions: the phase floor
// (5.0s P1 / 3.5s P2), the every-N-volleys cadence (every-2nd P1 / every P2), AND
// `BLINK_DEFENSIVE_RANGE=160` (blink fires ONLY when the player has closed inside
// 160 px). A passive `?start_room=9` boot leaves the Player at spawn (240,200),
// ~328 px from the plinth (512,384) — OUTSIDE the defensive range — so the boss
// CORRECTLY stays planted and does NOT blink (the intended no-forever-chase
// behavior; step 4e asserts this suppression). `_fire_blink` is the reposition
// decision; `ArchiveSentinelBlinkVfx._ready | VISIBLE` is the renderer-observable
// VFX-node-mounted signal (same shape as the cast-bolt visibility trace). The
// implication guard remains: IF a blink ever fires, the VFX node must mount
// visible (a no-VFX teleport would read as a generic-teleport bug per Uma §5.5a).
const BLINK_FIRE_TRACE =
  /\[combat-trace\] ArchiveSentinel\._fire_blink \| depart_idx=\d+ depart=\([-\d]+,[-\d]+\) -> target_idx=(\d+) arrival=\([-\d]+,[-\d]+\)/;
const BLINK_VFX_VISIBLE_TRACE =
  /\[combat-trace\] ArchiveSentinelBlinkVfx\._ready \| VISIBLE blink depart=\([-\d]+,[-\d]+\) arrival=\([-\d]+,[-\d]+\) z=(\d+) preglow=true/;

test.describe("Stratum2BossRoom production wiring (W3-T7 Stage 6)", () => {
  test("?start_room=9 boots into the S2 boss room; continuous-scroll engages; Sentinel wakes; no warnings", async ({
    page,
    context,
  }) => {
    // 90 s budget: boot (~30 s worst-case) + cast/wake/visibility toPass windows
    // + the 14 s blink-suppression observation window (step 4e, RETUNE d101b83).
    test.setTimeout(90_000);
    await context.route("**/*", (route) => route.continue());

    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    // `?start_room=9` drops directly into the S2 boss room AFTER the normal
    // Room 01 boot (production load path — real Player spawned + re-parented).
    await page.goto(`${baseURL}/?start_room=9`, { waitUntil: "domcontentloaded" });

    // Race: production boot line OR a diag boot line. Skip if diag.
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
      "Non-production artifact (diag main_scene swap) loaded — this spec " +
        "activates only against Main.tscn with the ?start_room=9 hook."
    );

    // ---- Production artifact IS active. ----

    // 1. start_room=9 bypass fired — reached the S2 boss room via production load.
    await expect(async () => {
      const bypassLine = capture.getLines().find((l) => START_ROOM_9_REGEX.test(l.text));
      expect(
        bypassLine,
        "Main._ready honored ?start_room=9 and jumped to the S2 boss room"
      ).toBeDefined();
    }).toPass({ timeout: 10_000 });

    // 2. Continuous-scroll bounds engage against the 1024×768 arena. The
    //    boss room's _engage_camera_for_boss_room sets these via CameraDirector.
    //    1024×768 > viewport (480×270) → the camera actually follows.
    await expect(async () => {
      const boundsTrace = capture.getLines().find((l) => ARENA_BOUNDS_TRACE.test(l.text));
      expect(
        boundsTrace,
        "Stratum2BossRoom engaged CameraDirector.set_world_bounds at 1024×768 arena bounds"
      ).toBeDefined();
    }).toPass({ timeout: 10_000 });

    // 3. Continuous-scroll follow engages with the authored (40,24) deadzone,
    //    target = the production Player (proves the player was re-parented in
    //    and the group lookup resolved — the Stage-5 NIT #2 root cause).
    const followTrace = capture.getLines().find((l) => FOLLOW_TRACE.test(l.text));
    expect(
      followTrace,
      "Stratum2BossRoom engaged CameraDirector.follow_target(Player, (40,24)) — " +
        "the Player exists in the production path (Stage-5 diag-soak had none)"
    ).toBeDefined();

    // 4. Sentinel wakes after the 1.8 s entry sequence auto-fires.
    await expect(async () => {
      const wakeTrace = capture.getLines().find((l) => SENTINEL_WAKE_TRACE.test(l.text));
      expect(
        wakeTrace,
        "ArchiveSentinel.wake fired — entry sequence auto-fired + boss woke"
      ).toBeDefined();
    }).toPass({ timeout: 8_000 });

    // 4b. CAST IS VISIBLE — damage never lands without a concurrent visible
    //     attack-visual node. The boss wakes with the Player inside AGGRO_RADIUS
    //     (640 px; plinth↔spawn ~327 px) so it auto-casts without player input.
    //     `_fire_cast` is the (invisible) damage event; `_spawn_cast_bolt` is the
    //     visible bolt spawned in the SAME _fire_cast call. The original bug
    //     (ticket 86c9y7ygj re-soak) was `_fire_cast` firing with NO visible
    //     node — this assertion would have caught it.
    await expect(async () => {
      const fireLine = capture.getLines().find((l) => CAST_FIRE_TRACE.test(l.text));
      expect(
        fireLine,
        "ArchiveSentinel cast fired (damage event) — boss engaged the player"
      ).toBeDefined();
    }).toPass({ timeout: 15_000 });

    // The visible bolt MUST be present once a cast has fired. If `_fire_cast`
    // appears in the stream but `_spawn_cast_bolt` does not, the cast dealt
    // invisible damage — the exact Sponsor-reported regression.
    const castFired = capture.getLines().some((l) => CAST_FIRE_TRACE.test(l.text));
    const boltSpawned = capture.getLines().some((l) => CAST_BOLT_TRACE.test(l.text));
    expect(
      !castFired || boltSpawned,
      "cast damage never lands without a concurrent visible cast-bolt node " +
        "(_fire_cast present ⟹ _spawn_cast_bolt present)"
    ).toBe(true);

    // 4c. RENDERER-OBSERVABLE VISIBILITY — the spawned bolt is NOT just present
    //     but actually in a renderable state at mount (visible==true, alpha>0,
    //     z>=0, ColorRect body). This is the brief-mandated assertion that the
    //     attack-visual node is visible at the moment player damage applies. The
    //     spawn-presence guard above proves the node exists; THIS proves it
    //     renders. The bolt's own _ready emits the trace after the deferred add,
    //     so the values are on-screen truth.
    await expect(async () => {
      const visibleLine = capture
        .getLines()
        .find((l) => CAST_BOLT_VISIBLE_TRACE.test(l.text));
      expect(
        visibleLine,
        "ArchiveSentinelCastBolt rendered visible (visible=true, alpha>0, z>=0, " +
          "ColorRect body) — the attack-visual node is renderable, not just spawned"
      ).toBeDefined();
      // Pin alpha > 0 from the captured group so a 0.00 alpha (invisible) fails.
      const m = visibleLine?.text.match(CAST_BOLT_VISIBLE_TRACE);
      const alpha = m ? parseFloat(m[1]) : 0;
      expect(alpha, "cast bolt on-screen alpha is > 0 (not fully transparent)").toBeGreaterThan(0);
    }).toPass({ timeout: 15_000 });

    // 4d. PHASE-2 SLAM TELEGRAPH IS VISIBLE (implication guard). Slam is
    //     phase-2-only (HP ≤ 50%) + requires the player within 96 px, so this
    //     passive boot does NOT reach it — but IF a slam ever fires in this
    //     stream, the visible draw_arc telegraph indicator MUST have been
    //     spawned. Guards a future invisible-slam regression WITHOUT fabricating
    //     a phase-2 harness drive (no-silent-harness-compensation). Phase-2
    //     render is positively proven by the GUT pin + the author self-soak
    //     screenshot; this is the cheap regression backstop in the smoke path.
    const slamFired = capture.getLines().some((l) => SLAM_FIRE_TRACE.test(l.text));
    const slamTelegraphed = capture.getLines().some((l) => SLAM_INDICATOR_TRACE.test(l.text));
    expect(
      !slamFired || slamTelegraphed,
      "slam damage never lands without a preceding visible draw_arc telegraph " +
        "(_fire_slam_hit present ⟹ _spawn_slam_indicator present)"
    ).toBe(true);

    // 4e. PHASE-BLINK IS DEFENSIVE-RANGE-SUPPRESSED FOR A PASSIVE FAR PLAYER
    //     (RETUNE, Sponsor re-soak `d101b83` 2026-05-31 — "moves around too much,
    //     didn't reach phase 2/3"). PRE-retune the blink fired at the tail of EVERY
    //     cast volley gated only by a ~2.5s floor + suppress-at-max-range, so a
    //     passive far-standing player still provoked blinks in this boot window —
    //     the original assertion required `_fire_blink` within 20s. The retune
    //     added `BLINK_DEFENSIVE_RANGE=160`: the construct now blinks ONLY when the
    //     player has CLOSED inside 160 px (an attacking player gets repositioned-
    //     away → the clear window); a ranged / distant player leaves the construct
    //     PLANTED (no forever-chase). The `?start_room=9` boot teleports the Player
    //     to DEFAULT_PLAYER_SPAWN=(240,200); the plinth is (512,384), ~328 px away
    //     — well OUTSIDE the 160 px defensive range. A passive player standing
    //     there therefore CORRECTLY does NOT trigger a blink. This is the TRUE
    //     current intended behavior: the construct stays planted vs a non-pressing
    //     player. (Floors 5.0/3.5 + every-N-volleys cadence are pinned at the GUT
    //     layer — B9–B13 in tests/test_archive_sentinel.gd.)
    //
    //     We assert SUPPRESSION positively: give the boss a generous window in
    //     which it demonstrably casts (4b proved ≥1 cast fired) and confirm NO
    //     `_fire_blink` occurred while the passive player stayed beyond defensive
    //     range. Driving the Player to within 160 px to provoke a blink would be
    //     harness-compensation for a passive-player smoke (per
    //     combat-architecture.md § "Harness coverage gap"); the FIRES-when-close
    //     path is covered by the GUT production-path drive
    //     (test_phase1_blinks_on_second_volley_not_first).
    //
    //     Wait long enough that, were the old every-volley-no-defensive-gate
    //     cadence still in effect, a blink WOULD have fired (≥2 volleys ≈ 5.6 s +
    //     the 5.0 s floor → a pre-retune build blinks well inside 14 s). Then
    //     assert it did NOT.
    await page.waitForTimeout(14_000);
    const blinkFired = capture.getLines().some((l) => BLINK_FIRE_TRACE.test(l.text));
    expect(
      blinkFired,
      "phase-blink is SUPPRESSED for a passive player beyond BLINK_DEFENSIVE_RANGE " +
        "(160 px) — the construct stays planted vs a non-pressing player " +
        "(RETUNE d101b83). DEFAULT_PLAYER_SPAWN (240,200) is ~328 px from the " +
        "plinth (512,384), outside defensive range, so no blink should fire."
    ).toBe(false);

    // Implication guard retained: IF a blink ever fires in this stream (e.g. a
    // future build moves the player or changes spawn so it closes inside range),
    // the visible traversal VFX MUST mount — a reposition with no VFX would read
    // as a generic teleport (Uma §5.5a). Vacuously true while suppressed.
    const blinkVfxVisible = capture.getLines().some((l) => BLINK_VFX_VISIBLE_TRACE.test(l.text));
    expect(
      !blinkFired || blinkVfxVisible,
      "phase-blink never repositions the body without a visible traversal VFX " +
        "(_fire_blink present ⟹ ArchiveSentinelBlinkVfx mounted visible) — reads " +
        "as a phase-shift, not a generic teleport (Uma §5.5a)"
    ).toBe(true);

    // 5. No physics-flush panic during the boss-room deferred fixture pass.
    const panicLine = capture.findUnexpectedLine(
      /Can't change this state while flushing queries/
    );
    expect(panicLine, "no physics-flush panic on S2 boss-room load").toBeNull();

    // 6. BuildInfo SHA emits — overall boot chain intact.
    const buildLine = capture
      .getLines()
      .find((l) => /\[BuildInfo\] build: [0-9a-f]{7}/.test(l.text));
    expect(buildLine, "BuildInfo SHA emits — boot chain unbroken").toBeDefined();

    // (Universal console-warning gate — no USER WARNING: / USER ERROR: — is
    // enforced by test-base.ts teardown; no explicit assertion needed here.)

    capture.detach();
  });
});
