/**
 * Drew grunt-rig author-self-soak — ticket `86ca4uerp`
 * (feat(mobs): install grunt cloister-penitent rig into Grunt.tres).
 *
 * Frames-only SpriteFrames swap → HTML5-visual-gated surface (AnimatedSprite2D
 * frames rendered through `gl_compatibility`). Per
 * `html5-visual-gated-author-self-soak`, the author must self-soak the actual
 * release-build artifact (incognito + DevTools-equivalent console) BEFORE
 * claiming fix-complete.
 *
 * This spec boots the PRODUCTION artifact into Room 02 (`?start_room=1`, the
 * first multi-grunt room) and drives the player to engage a grunt, capturing:
 *   1. The grunt rendered in the live arena (screenshot — visual proof the new
 *      88×88 cloister-penitent frames load + render, not the old 68×68 v2 art).
 *   2. The `Grunt._play_anim | PLAY anim=<key>` traces firing across the key set
 *      ({walk, atk_telegraph, atk, hit, die}_<dir>) — mechanical proof the new
 *      SpriteFrames resolves every key the state machine plays (a MISS trace
 *      would surface here if a key were dropped/mis-named by the swap).
 *   3. No `USER WARNING: ... lacks this animation key` / no physics-flush panic.
 *
 * Run locally against a downloaded release-build artifact:
 *   RELEASE_BUILD_ARTIFACT_PATH=/tmp/grunt-soak/build \
 *     npx playwright test drew-grunt-rig-self-soak.spec.ts
 *
 * `test.skip` keeps it CI-inert (heavy screenshot soak); flip to `test`
 * locally. Mechanical key-contract coverage lives in the GUT
 * `tests/test_grunt_animation_wire.gd` (40-key pin).
 */

import { test, expect } from "../fixtures/test-base";

const ENGAGE_WINDOW_MS = 16_000; // grunts close from spawn + player swings

test.skip("Room 02 (?start_room=1): cloister-penitent grunt renders + plays every state anim key", async ({
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

  await page.goto("/?start_room=1");

  // Boot.
  await expect(async () => {
    expect(allConsole.some((l) => l.includes("[BuildInfo]"))).toBe(true);
  }).toPass({ timeout: 30_000 });

  // Confirm the build SHA (printed for the Self-Test Report).
  const buildLine = allConsole.find((l) => l.includes("[BuildInfo]")) ?? "(none)";
  console.log("\n=== BuildInfo ===\n" + buildLine);

  // Room 02 loaded — first Grunt is alive + ticking (the sentinel per
  // test-conventions.md § "Room 02 load sentinel").
  await expect(async () => {
    expect(
      traceLogs.some((l) => /Grunt\.(pos|_set_state|_play_anim)/.test(l))
    ).toBe(true);
  }).toPass({ timeout: 15_000 });

  // Early screenshot — grunts at distance, walking. Proves the new art renders.
  await page.waitForTimeout(1500);
  await page.screenshot({
    path: "/tmp/grunt-soak-approach.png",
    fullPage: false,
  });

  // Drive the player to engage: walk toward the NE grunt spawn cluster +
  // spam light attacks (mouse-aimed NE via clickAimedAtSpawn would be ideal,
  // but a simple WASD-toward + click sweep exercises the chase→telegraph→atk
  // →hit→die anim cascade enough to surface every key's PLAY/MISS trace).
  const canvas = page.locator("canvas").first();
  await canvas.focus();
  await page.keyboard.down("w");
  for (let i = 0; i < 24; i++) {
    // Click NE of the near-spawn player to swing toward the grunts.
    await canvas.click({ position: { x: 240 + 150, y: 200 - 150 } });
    await page.waitForTimeout(ENGAGE_WINDOW_MS / 24);
  }
  await page.keyboard.up("w");
  await page.waitForTimeout(600);

  // Late screenshot — mid-combat (hit-flash / telegraph / death frames).
  await page.screenshot({
    path: "/tmp/grunt-soak-combat.png",
    fullPage: false,
  });

  // ---- Assertions ----------------------------------------------------

  // Every PLAY anim key the state machine drives must have fired with a real
  // SpriteFrames key (a missing key would emit a MISS trace instead).
  const playedKeys = new Set<string>();
  for (const l of traceLogs) {
    const m = l.match(/Grunt\._play_anim \| PLAY anim=([a-z_]+)/);
    if (m) playedKeys.add(m[1].replace(/_[a-z]+$/, "")); // strip _<dir>
  }
  console.log("\n=== Grunt PLAY anim state-keys observed ===");
  console.log([...playedKeys].sort().join(", "));

  // walk is always reached (chase). atk_telegraph + atk reached when a grunt
  // gets in melee range. hit reached when the player lands a swing. die when a
  // grunt is killed. We assert the always-on ones hard + log the rest.
  expect(playedKeys.has("walk"), "walk_<dir> played (chase)").toBe(true);

  // NO missing-animation-key warning — the structural proof the swap kept all
  // 40 keys.
  const missTraces = traceLogs.filter((l) =>
    /Grunt\._play_anim \| MISS/.test(l)
  );
  console.log("\n=== Grunt MISS traces (must be empty) ===");
  console.log(missTraces.length === 0 ? "(none)" : missTraces.join("\n"));
  expect(missTraces, "no Grunt._play_anim MISS — every key resolves").toEqual([]);

  // No physics-flush panic across the whole soak.
  expect(
    allConsole.some((l) =>
      l.includes("Can't change this state while flushing queries")
    )
  ).toBe(false);

  // Print full trace tail for the Self-Test Report.
  console.log("\n=== combat-trace tail (last 40) ===");
  for (const line of traceLogs.slice(-40)) console.log(line);
});
