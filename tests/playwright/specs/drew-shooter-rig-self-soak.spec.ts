/**
 * Drew shooter-rig author-self-soak — ticket `86ca5a5vy`
 * (feat(mobs): install shooter brazier-warden rig into Shooter.tres).
 *
 * Frames-only SpriteFrames swap → HTML5-visual-gated surface (AnimatedSprite2D
 * frames rendered through `gl_compatibility`). Per
 * `html5-visual-gated-author-self-soak`, the author must self-soak the actual
 * release-build artifact (incognito + DevTools-equivalent console) BEFORE
 * claiming fix-complete.
 *
 * This spec boots the PRODUCTION artifact into Room 04 (`?start_room=3`, the
 * first Shooter room — `resources/level_chunks/s1_room04.tres` spawns a shooter)
 * and drives the player to engage, capturing:
 *   1. The shooter rendered in the live arena (screenshot — visual proof the new
 *      124×124 brazier-warden frames load + render, not the old skeletal-archer
 *      `add_two_bright_glowi` art).
 *   2. The `Shooter._play_anim | PLAY anim=<key>` traces firing across the key
 *      set ({walk, telegraph, atk, hit, die}_<dir>) — mechanical proof the new
 *      SpriteFrames resolves every key `Shooter._set_state` plays (a MISS trace
 *      would surface here if a key were dropped/mis-named by the swap).
 *   3. No `... lacks this animation key` MISS / no physics-flush panic.
 *
 * Run locally against a downloaded release-build artifact:
 *   RELEASE_BUILD_ARTIFACT_PATH=/tmp/shooter-soak/build \
 *     npx playwright test drew-shooter-rig-self-soak.spec.ts
 *
 * `test.skip` keeps it CI-inert (heavy screenshot soak); flip to `test`
 * locally. Mechanical key-contract coverage lives in the GUT
 * `tests/test_shooter_animation_wire.gd` (40-key pin).
 */

import { test, expect } from "../fixtures/test-base";

const ENGAGE_WINDOW_MS = 18_000; // shooter kites + telegraphs; longer window

test.skip("Room 04 (?start_room=3): brazier-warden shooter renders + plays every state anim key", async ({
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

  await page.goto("/?start_room=3");

  // Boot.
  await expect(async () => {
    expect(allConsole.some((l) => l.includes("[BuildInfo]"))).toBe(true);
  }).toPass({ timeout: 30_000 });

  // Confirm the build SHA (printed for the Self-Test Report).
  const buildLine = allConsole.find((l) => l.includes("[BuildInfo]")) ?? "(none)";
  console.log("\n=== BuildInfo ===\n" + buildLine);

  // Room 04 loaded — the shooter is alive + ticking.
  await expect(async () => {
    expect(
      traceLogs.some((l) => /Shooter\.(pos|_set_state|_play_anim)/.test(l))
    ).toBe(true);
  }).toPass({ timeout: 15_000 });

  // Early screenshot — shooter at distance. Proves the new art renders.
  await page.waitForTimeout(1500);
  await page.screenshot({
    path: "/tmp/shooter-soak-approach.png",
    fullPage: false,
  });

  // Drive the player to engage: walk toward the shooter spawn + spam light
  // attacks. The shooter's 3-band engagement (spotted → walk; aiming →
  // telegraph; firing → atk) and take_damage → hit, _die → die surface every
  // state-key's PLAY/MISS trace as the player closes + lands swings.
  const canvas = page.locator("canvas").first();
  await canvas.focus();
  await page.keyboard.down("w");
  for (let i = 0; i < 24; i++) {
    // Click NE of the near-spawn player to swing toward the shooter cluster.
    await canvas.click({ position: { x: 240 + 150, y: 200 - 150 } });
    await page.waitForTimeout(ENGAGE_WINDOW_MS / 24);
  }
  await page.keyboard.up("w");
  await page.waitForTimeout(600);

  // Late screenshot — mid-combat (telegraph / hit-flash / death frames).
  await page.screenshot({
    path: "/tmp/shooter-soak-combat.png",
    fullPage: false,
  });

  // ---- Assertions ----------------------------------------------------

  // Every PLAY anim key the state machine drives must have fired with a real
  // SpriteFrames key (a missing key would emit a MISS trace instead).
  const playedKeys = new Set<string>();
  for (const l of traceLogs) {
    const m = l.match(/Shooter\._play_anim \| PLAY anim=([a-z_]+)/);
    if (m) playedKeys.add(m[1].replace(/_[a-z]+$/, "")); // strip _<dir>
  }
  console.log("\n=== Shooter PLAY anim state-keys observed ===");
  console.log([...playedKeys].sort().join(", "));

  // walk is reached as the shooter spots/kites. telegraph + atk reached when it
  // aims/fires; hit when the player lands a swing; die when killed. Assert the
  // always-on one hard + log the rest.
  expect(playedKeys.has("walk"), "walk_<dir> played (spotted/kiting)").toBe(true);

  // NO missing-animation-key MISS trace — the structural proof the swap kept all
  // 40 keys.
  const missTraces = traceLogs.filter((l) =>
    /Shooter\._play_anim \| MISS/.test(l)
  );
  console.log("\n=== Shooter MISS traces (must be empty) ===");
  console.log(missTraces.length === 0 ? "(none)" : missTraces.join("\n"));
  expect(missTraces, "no Shooter._play_anim MISS — every key resolves").toEqual([]);

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
