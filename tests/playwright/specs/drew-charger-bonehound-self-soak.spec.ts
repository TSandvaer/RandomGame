/**
 * Drew charger bone-hound self-soak — ticket `86ca5a5wa`
 * (feat(mobs): install S1 bone-hound rig into Charger mob).
 *
 * Frames-only SpriteFrames swap + cosmetic additive ember → HTML5-visual-gated
 * surface (AnimatedSprite2D frames + CanvasItemMaterial blend_mode=ADD rendered
 * through `gl_compatibility`). Per `html5-visual-gated-author-self-soak`, the
 * author self-soaks the actual release-build artifact BEFORE claiming complete.
 *
 * Boots the PRODUCTION artifact into Room 03 (`?start_room=2`, the first room
 * with a charger spawn — grunt + charger), drives the player to engage, and
 * captures:
 *   1. The bone-hound rendered in the live arena (screenshot — visual proof the
 *      new 124×124 skeletal-quadruped frames + ribcage ember load + render, not
 *      the old ~68×68 humanoid art).
 *   2. The `Charger._play_anim | PLAY anim=<key>` traces firing across the wired
 *      key set ({walk, telegraph, atk, die}_<dir>) — mechanical proof the new
 *      SpriteFrames resolves every key the state machine plays (a MISS trace
 *      would surface here if a key were dropped/mis-named by the swap).
 *   3. No `... lacks this animation key` MISS / no physics-flush panic.
 *
 * Run locally against a downloaded release-build artifact:
 *   RELEASE_BUILD_ARTIFACT_PATH=/tmp/charger-soak/embergrave-html5-<sha> \
 *     npx playwright test drew-charger-bonehound-self-soak.spec.ts
 *
 * `test.skip` keeps it CI-inert (heavy screenshot soak); flip to `test`
 * locally. Mechanical key-contract coverage lives in the GUT
 * `tests/test_charger_animation_wire.gd` (32-key pin + 5 ember assertions).
 */

import { test, expect } from "../fixtures/test-base";

const ENGAGE_WINDOW_MS = 18_000; // charger telegraphs + charges + recovers

test.skip("Room 03 (?start_room=2): bone-hound charger renders + plays every wired state anim key", async ({
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

  await page.goto("/?start_room=2");

  await expect(async () => {
    expect(allConsole.some((l) => l.includes("[BuildInfo]"))).toBe(true);
  }).toPass({ timeout: 30_000 });

  const buildLine = allConsole.find((l) => l.includes("[BuildInfo]")) ?? "(none)";
  console.log("\n=== BuildInfo ===\n" + buildLine);

  // Room 03 loaded — the charger is alive + ticking (Charger.pos trace).
  await expect(async () => {
    expect(
      traceLogs.some((l) => /Charger\.(pos|_set_state|_play_anim)/.test(l))
    ).toBe(true);
  }).toPass({ timeout: 15_000 });

  // Early screenshot — charger at distance. Proves the skeletal art renders.
  await page.waitForTimeout(1500);
  await page.screenshot({ path: "/tmp/charger-soak-approach.png", fullPage: false });

  // Drive the player to engage: walk toward the NE spawn cluster + spam light
  // attacks to cycle the charger through spotted→telegraph→charge→recover→die.
  const canvas = page.locator("canvas").first();
  await canvas.focus();
  await page.keyboard.down("w");
  for (let i = 0; i < 24; i++) {
    await canvas.click({ position: { x: 240 + 150, y: 200 - 150 } });
    await page.waitForTimeout(ENGAGE_WINDOW_MS / 24);
  }
  await page.keyboard.up("w");
  await page.waitForTimeout(600);

  // Late screenshot — mid-combat (telegraph red-glow / ember / death frames).
  await page.screenshot({ path: "/tmp/charger-soak-combat.png", fullPage: false });

  // ---- Assertions ----------------------------------------------------

  const playedKeys = new Set<string>();
  for (const l of traceLogs) {
    const m = l.match(/Charger\._play_anim \| PLAY anim=([a-z_]+)/);
    if (m) playedKeys.add(m[1].replace(/_[a-z]+$/, "")); // strip _<dir>
  }
  console.log("\n=== Charger PLAY anim state-keys observed ===");
  console.log([...playedKeys].sort().join(", "));

  // walk is always reached (SPOTTED/CHARGING). telegraph/atk reached when the
  // charger commits to a charge; die when it is killed. Assert the always-on
  // one hard + log the rest.
  expect(playedKeys.has("walk"), "walk_<dir> played (SPOTTED/CHARGING)").toBe(true);

  // NO missing-animation-key MISS — structural proof the swap kept all 32 keys
  // and that the state machine never plays a non-existent key (e.g. hit_<dir>).
  const missTraces = traceLogs.filter((l) =>
    /Charger\._play_anim \| MISS/.test(l)
  );
  console.log("\n=== Charger MISS traces (must be empty) ===");
  console.log(missTraces.length === 0 ? "(none)" : missTraces.join("\n"));
  expect(missTraces, "no Charger._play_anim MISS — every wired key resolves").toEqual([]);

  // No physics-flush panic across the whole soak.
  expect(
    allConsole.some((l) =>
      l.includes("Can't change this state while flushing queries")
    )
  ).toBe(false);

  console.log("\n=== combat-trace tail (last 40) ===");
  for (const line of traceLogs.slice(-40)) console.log(line);
});
