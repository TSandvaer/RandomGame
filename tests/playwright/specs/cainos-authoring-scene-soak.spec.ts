/**
 * Cainos authoring-scene in-game capture — ticket `86ca64xzb`
 * (feat(level): paintable Godot setup from Cainos tileset).
 *
 * This is the IN-GAME visual gate for the paintable S1 setup: it boots the
 * authoring scene in the ACTUAL running HTML5 build and screenshots the Cainos
 * tiles rendering through `gl_compatibility`. Per the FINAL-pivot lesson in
 * `art-direction.md` ("verify against the running game, not a proxy that can
 * diverge" — the offline render-tool false-approval), this NEVER uses an offline
 * render tool; it captures the live game canvas.
 *
 * The production `Main.tscn` boots the normal game, NOT the authoring scene, so
 * this spec runs against a DIAG build whose `application/run/main_scene` is
 * swapped to `s1_yard_authored.tscn` (branch `diag/cainos-authored-soak`, per the
 * diag-build spike pattern in `html5-export.md` § "Diagnostic-build pattern").
 * The PRODUCTION PR artifact will NOT boot this scene — soak/capture MUST use the
 * diag artifact.
 *
 * Run locally against the downloaded DIAG artifact:
 *   RELEASE_BUILD_ARTIFACT_PATH=/tmp/cainos-diag/build \
 *     npx playwright test cainos-authoring-scene-soak.spec.ts --grep @capture
 *
 * `test.skip` keeps it CI-inert (heavy screenshot soak, diag-build-gated).
 */

import { test, expect } from "../fixtures/test-base";

test.skip("@capture authoring scene boots + renders Cainos tiles in the live build", async ({
  page,
}) => {
  const allConsole: string[] = [];
  page.on("console", (msg) => allConsole.push(msg.text()));

  await page.goto("/");

  // Boot.
  await expect(async () => {
    expect(allConsole.some((l) => l.includes("[BuildInfo]"))).toBe(true);
  }).toPass({ timeout: 30_000 });

  const buildLine = allConsole.find((l) => l.includes("[BuildInfo]")) ?? "(none)";
  console.log("\n=== BuildInfo ===\n" + buildLine);

  // The authoring scene's _ready prints its banner — proves S1YardAuthored is
  // the active scene (not Main.tscn) and the follow-camera attached.
  await expect(async () => {
    expect(allConsole.some((l) => l.includes("[S1YardAuthored] ready"))).toBe(true);
  }).toPass({ timeout: 15_000 });
  console.log(
    "\n=== authoring banner ===\n" +
      (allConsole.find((l) => l.includes("[S1YardAuthored]")) ?? "(none)")
  );

  // Let the starter ground patch render + camera settle.
  await page.waitForTimeout(2000);

  // Capture the live canvas — the Cainos grass↔stone-path autotiled starter
  // patch must be visible (warm-grey cobble strip blended into olive grass).
  await page.screenshot({
    path: "/tmp/cainos-authoring-spawn.png",
    fullPage: false,
  });

  // Walk a little so the camera scrolls + we see more of the painted ground.
  const canvas = page.locator("canvas").first();
  await canvas.focus();
  await page.keyboard.down("d");
  await page.waitForTimeout(800);
  await page.keyboard.up("d");
  await page.keyboard.down("s");
  await page.waitForTimeout(600);
  await page.keyboard.up("s");
  await page.waitForTimeout(400);

  await page.screenshot({
    path: "/tmp/cainos-authoring-walked.png",
    fullPage: false,
  });

  // No physics-flush panic / no script error across the boot+walk.
  expect(
    allConsole.some((l) =>
      l.includes("Can't change this state while flushing queries")
    ),
    "no physics-flush panic"
  ).toBe(false);
  expect(
    allConsole.some((l) => l.includes("SCRIPT ERROR")),
    "no script error"
  ).toBe(false);

  console.log("\n=== console tail (last 30) ===");
  for (const line of allConsole.slice(-30)) console.log(line);
});
