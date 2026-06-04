/**
 * Drew monk-rig-install author-self-soak — feat(player): install new monk
 * sprite rig (8-dir, 6 anims).
 *
 * The Player sprite swap is a RENDER-PATH change (new SpriteFrames frames on
 * the production AnimatedSprite2D), so it is subject to the HTML5
 * visual-verification gate (`.claude/docs/html5-export.md`). This soak boots
 * the PRODUCTION release-build artifact in real (headless) Chromium with the
 * COOP/COEP server, drives the monk through walk / light-attack / heavy-attack
 * in Room 01, and captures screenshots so the new hero is confirmed to render
 * + animate in WebGL2 (`gl_compatibility`).
 *
 * Mechanical assertions: the `[combat-trace] Player._play_anim | PLAY
 * anim=<state>_<dir>` lines fire for walk + attack across the swap — proving
 * the new SpriteFrames keys resolve + play in production. The screenshots are
 * the human-perception evidence (the bald/pale/blue-eyed monk) per the
 * Self-Test Report.
 *
 * Run locally:
 *   RELEASE_BUILD_ARTIFACT_PATH=/tmp/html5-build \
 *     npx playwright test drew-monk-rig-self-soak.spec.ts
 *
 * OUTSIDE the regular CI run set (long-ish boot + screenshot capture; the
 * mechanical anim-wiring assertions live in `tests/test_player_animation_wire.gd`
 * + `tests/test_player_monk_rig.gd`). Checked in so the soak is auditable +
 * re-runnable by Tess. `test.skip` keeps it CI-inert by default (matches the
 * `drew-stage6-self-soak.spec.ts` convention); flip `test.skip` → `test` to run.
 */

import { test, expect } from "../fixtures/test-base";
import { clickAtWorldPos } from "../fixtures/mouse-facing";

// Room01 PracticeDummy world position (per combat-architecture.md ~ (368, 144)).
const DUMMY_WORLD = { x: 368, y: 144 };

test.skip("monk rig: production boot, walk + attack anims play, monk renders in WebGL2", async ({
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

  await page.goto("/");

  // Wait for boot.
  await expect(async () => {
    expect(allConsole.some((l) => l.includes("[BuildInfo]"))).toBe(true);
  }).toPass({ timeout: 30_000 });

  // Confirm the SpriteFrames seed anim fired (the monk's first rest pose).
  // _ready seeds walk_s frame 0 (default IDLE + facing south).
  await expect(async () => {
    expect(
      traceLogs.some((l) => /Player\._play_anim \| PLAY anim=walk_s/.test(l))
    ).toBe(true);
  }).toPass({ timeout: 10_000 });

  const canvas = page.locator("canvas").first();
  await canvas.focus();

  // Capture the monk at rest (idle = walk frame 0 hold). Bald/pale/blue-eye
  // check is on this frame.
  await page.screenshot({ path: "/tmp/monk-soak-idle.png", fullPage: false });

  // ---- Walk the monk in 4 directions; assert walk_<dir> anim plays. ----
  const walkCases: Array<[string, string]> = [
    ["d", "walk_e"],
    ["s", "walk_s"],
    ["a", "walk_w"],
    ["w", "walk_n"],
  ];
  for (const [key, expectedAnim] of walkCases) {
    await page.keyboard.down(key);
    await page.waitForTimeout(450);
    await page.keyboard.up(key);
    await page.waitForTimeout(150);
    expect(
      traceLogs.some((l) =>
        new RegExp(`Player\\._play_anim \\| PLAY anim=${expectedAnim}`).test(l)
      ),
      `walk anim ${expectedAnim} played (key ${key})`
    ).toBe(true);
  }
  await page.screenshot({ path: "/tmp/monk-soak-walked.png", fullPage: false });

  // ---- Light attack toward the dummy — assert attack_light_<dir> plays. ----
  await clickAtWorldPos(canvas, null, DUMMY_WORLD.x, DUMMY_WORLD.y, {
    button: "left",
  });
  await page.waitForTimeout(300);
  expect(
    traceLogs.some((l) =>
      /Player\._play_anim \| PLAY anim=attack_light_/.test(l)
    ),
    "attack_light anim played"
  ).toBe(true);

  // ---- Heavy attack — assert attack_heavy_<dir> plays. ----
  await clickAtWorldPos(canvas, null, DUMMY_WORLD.x, DUMMY_WORLD.y, {
    button: "right",
  });
  await page.waitForTimeout(300);
  expect(
    traceLogs.some((l) =>
      /Player\._play_anim \| PLAY anim=attack_heavy_/.test(l)
    ),
    "attack_heavy anim played"
  ).toBe(true);

  await page.screenshot({ path: "/tmp/monk-soak-attack.png", fullPage: false });

  // No MISS traces — every state the soak exercised resolved a real
  // SpriteFrames key (the swap did not drop any consumed anim key).
  expect(
    traceLogs.some((l) => /Player\._play_anim \| MISS/.test(l)),
    "no Player._play_anim MISS across walk + attack states"
  ).toBe(false);

  // No physics-flush panic across the soak.
  expect(
    allConsole.some((l) =>
      l.includes("Can't change this state while flushing queries")
    )
  ).toBe(false);

  console.log("\n=== monk-rig soak Player._play_anim traces ===");
  for (const line of traceLogs.filter((l) => l.includes("Player._play_anim"))) {
    console.log(line);
  }
});
