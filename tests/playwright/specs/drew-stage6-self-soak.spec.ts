/**
 * Drew Stage 6 author-self-soak — W3-T7 Stage 6 (ticket `86c9y7ygj`).
 *
 * SUPERSEDES `drew-stage5-self-soak.spec.ts`. Stage 5's self-soak booted a
 * diag-build whose `main_scene` was swapped to `Stratum2BossRoom.tscn`
 * STANDALONE — which spawned NO Player, so `CameraDirector.follow_target`
 * soft-failed on the empty player group, the camera defaulted to (0,0), and
 * the Sentinel ColorRect at plinth (512,384) fell OUTSIDE the captured frame.
 * That was Stage-5 NIT #2 (Tess PR #374 review).
 *
 * Stage 6 wires the boss room into the production load path, so the self-soak
 * now boots via the PRODUCTION artifact with `?start_room=9`:
 *   - Main spawns the Player + re-parents it into the boss room.
 *   - The boss room's `_engage_camera_for_boss_room` follows the live Player.
 *   - The camera centers on the Player (placed at a plinth-relative spawn),
 *     so the Sentinel ColorRect renders IN-FRAME in the captured screenshot.
 *
 * This is the author-self-soak gate per `html5-visual-gated-author-self-soak`
 * — boss room = full visual gate (NOT escape-clause-eligible per the dispatch
 * brief). It runs against the PRODUCTION release-build artifact (no diag
 * main_scene swap needed anymore — the boss room is reachable in production).
 *
 * Run locally:
 *   RELEASE_BUILD_ARTIFACT_PATH=/tmp/embergrave-stage6-soak \
 *     npx playwright test drew-stage6-self-soak.spec.ts
 *
 * OUTSIDE the regular CI run set (long-ish boot + screenshot capture; the
 * mechanical assertions live in `stratum2-boss-room.spec.ts`). Checked in so
 * the soak procedure is auditable + re-runnable by Tess.
 */

import { test, expect } from "../fixtures/test-base";

// The Sentinel sits at plinth (512,384). To put it in-frame we place the
// player NEAR the plinth so the continuous-scroll camera centers there. The
// production Main teleports the player to DEFAULT_PLAYER_SPAWN (240,200) on
// room load; we then WASD-walk the player toward the plinth so the camera
// scrolls the Sentinel into the captured viewport. (The 1024×768 arena is
// wider than the viewport, so the camera genuinely scrolls — unlike the S1
// viewport-native rooms.)
const WALK_TOWARD_PLINTH_MS = 1800;

// `test.skip(...)` keeps this author-only visual soak CI-inert by default
// (matches the `pr291-aftershock-visual.spec.ts` convention for heavy
// screenshot-capture soaks). The author flips `test.skip` → `test` locally
// to run it against a downloaded release-build artifact. The mechanical
// assertions for CI live in `stratum2-boss-room.spec.ts`.
test.skip("Stratum2BossRoom production boot (?start_room=9): Player + Sentinel render in-frame; state machine + camera traces fire", async ({
  page,
}) => {
  const traceLogs: string[] = [];
  const allConsole: string[] = [];

  page.on("console", (msg) => {
    const text = msg.text();
    allConsole.push(text);
    if (text.includes("[combat-trace]")) {
      traceLogs.push(text);
    }
  });

  // Production path — ?start_room=9 drops into the S2 boss room AFTER the
  // normal Room 01 boot, with a real Player spawned + re-parented.
  await page.goto("/?start_room=9");

  // Wait for boot.
  await expect(async () => {
    expect(allConsole.some((l) => l.includes("[BuildInfo]"))).toBe(true);
  }).toPass({ timeout: 30_000 });

  // Reached the S2 boss room via production load.
  await expect(async () => {
    expect(
      allConsole.some((l) => l.includes("DebugFlags.start_room=9"))
    ).toBe(true);
  }).toPass({ timeout: 10_000 });

  // Boss-room deferred fixture pass ran (door trigger built + monitoring).
  await expect(async () => {
    expect(
      traceLogs.some((l) =>
        l.includes("Stratum2BossRoom._assemble_room_fixtures")
      )
    ).toBe(true);
  }).toPass({ timeout: 10_000 });

  // Continuous-scroll follow engaged against the live Player (NOT soft-failed
  // on an empty group — the Stage-5 NIT #2 root cause). The Player exists in
  // the production path.
  await expect(async () => {
    expect(
      traceLogs.some((l) =>
        /CameraDirector\.follow_target \| target=Player/.test(l)
      )
    ).toBe(true);
  }).toPass({ timeout: 10_000 });

  // Boss wakes after the 1.8 s entry sequence.
  await expect(async () => {
    expect(traceLogs.some((l) => l.includes("ArchiveSentinel.wake"))).toBe(true);
  }).toPass({ timeout: 8_000 });

  // Walk the player toward the plinth so the camera scrolls the Sentinel into
  // the captured viewport. Focus the canvas so keyboard routes to Godot.
  const canvas = page.locator("canvas").first();
  await canvas.focus();
  // From spawn (240,200) the plinth (512,384) is to the SE — walk D + S.
  await page.keyboard.down("d");
  await page.keyboard.down("s");
  await page.waitForTimeout(WALK_TOWARD_PLINTH_MS);
  await page.keyboard.up("d");
  await page.keyboard.up("s");
  await page.waitForTimeout(600); // settle camera

  // Capture the arena with the Player walked toward the plinth — the Sentinel
  // ColorRect should now be IN the captured frame (Stage-5 NIT #2 fixed).
  await page.screenshot({
    path: "/tmp/embergrave-stage6-soak-arena.png",
    fullPage: false,
  });

  // No physics-flush panic across the whole soak.
  expect(
    allConsole.some((l) => l.includes("Can't change this state while flushing queries"))
  ).toBe(false);

  // Print captured traces for the Self-Test Report.
  console.log("\n=== Stratum2BossRoom (production ?start_room=9) traces ===");
  for (const line of traceLogs) {
    console.log(line);
  }
});
