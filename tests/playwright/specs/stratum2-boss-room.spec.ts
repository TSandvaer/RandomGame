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

test.describe("Stratum2BossRoom production wiring (W3-T7 Stage 6)", () => {
  test("?start_room=9 boots into the S2 boss room; continuous-scroll engages; Sentinel wakes; no warnings", async ({
    page,
    context,
  }) => {
    test.setTimeout(60_000);
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
