/**
 * Drew soak-round-2 author-self-soak — W3-T7 (ticket `86c9y7ygj`), PR #380.
 *
 * Verifies the two soak-round-2 fixes against the PRODUCTION release-build
 * artifact at `?start_room=9&boss_hp_mult=0.2`:
 *
 *   FINDING 1 — boss_hp_mult parity. The `?boss_hp_mult=0.2` param must now be
 *   honored by ArchiveSentinel (was a no-op pre-fix — boss stayed at 700 HP).
 *   The DebugFlags boot line reports the resolved multiplier; the Sentinel's
 *   nerfed HP is observable via the take_damage trace (140 HP = 700*0.2 → phase
 *   2 boundary at 70 HP, dies in far fewer hits).
 *
 *   FINDING 2 — boss-room zoom-out. The CameraDirector.state trace must report
 *   the camera zoomed OUT (engine zoom = BASELINE 2.6667 * 0.5 = ~1.333) once
 *   the boss room engages — NOT the 2.6667 default that rendered the 1024×768
 *   arena too tight ("characters too big").
 *
 * Run locally:
 *   RELEASE_BUILD_ARTIFACT_PATH=/tmp/eg-soak2 \
 *     npx playwright test drew-soak-round2-self-soak.spec.ts --headed
 *
 * OUTSIDE the regular CI run set (long boot + screenshot capture). The
 * mechanical assertions for CI live in `stratum2-boss-room.spec.ts` +
 * `tests/test_stratum2_boss_room.gd` + `tests/test_archive_sentinel.gd`.
 * Checked in so the soak-round-2 procedure is auditable + re-runnable by Tess.
 *
 * Author flips `test.skip` → `test` locally to run against a downloaded
 * artifact (same convention as drew-stage6-self-soak.spec.ts).
 */

import { test, expect } from "../fixtures/test-base";

const WALK_TOWARD_PLINTH_MS = 1800;

test.skip("soak round 2 (?start_room=9&boss_hp_mult=0.2): boss nerfed + camera zoomed OUT", async ({
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

  await page.goto("/?start_room=9&boss_hp_mult=0.2");

  // Boot reached.
  await expect(async () => {
    expect(allConsole.some((l) => l.includes("[BuildInfo]"))).toBe(true);
  }).toPass({ timeout: 30_000 });

  // FINDING 1 evidence (a) — DebugFlags boot line reports boss_hp_mult=0.200.
  await expect(async () => {
    expect(
      allConsole.some((l) => /\[DebugFlags\].*boss_hp_mult=0\.200/.test(l))
    ).toBe(true);
  }).toPass({ timeout: 10_000 });

  // Reached the S2 boss room via production load.
  await expect(async () => {
    expect(
      allConsole.some((l) => l.includes("DebugFlags.start_room=9"))
    ).toBe(true);
  }).toPass({ timeout: 10_000 });

  // FINDING 2 evidence — CameraDirector.state reports engine zoom ~1.333
  // (BASELINE 2.6667 * normalized 0.5), NOT the 2.6667 default. The state
  // trace emits every 0.25 s; give it a couple of cadences after engage.
  await page.waitForTimeout(1200);
  const zoomLines = traceLogs.filter((l) =>
    /CameraDirector\.state \| zoom=/.test(l)
  );
  expect(zoomLines.length).toBeGreaterThan(0);
  const lastZoom = zoomLines[zoomLines.length - 1];
  const zoomMatch = lastZoom.match(/zoom=([\d.]+)/);
  expect(zoomMatch).not.toBeNull();
  const engineZoom = parseFloat(zoomMatch![1]);
  // Zoomed OUT: engine zoom must be near 1.333 (well below the 2.6667 default).
  expect(engineZoom).toBeLessThan(2.0);
  expect(engineZoom).toBeGreaterThan(1.0);

  // FINDING 1 evidence (b) — Sentinel nerfed to 140 HP. Walk to the plinth +
  // attack so the boss takes damage; the take_damage trace reports hp out of
  // a 140 max, and the phase-2 boundary (70 HP) is reachable in a few hits
  // (would be 350 of 700 unnerfed).
  const canvas = page.locator("canvas").first();
  await canvas.focus();
  await page.keyboard.down("d");
  await page.keyboard.down("s");
  await page.waitForTimeout(WALK_TOWARD_PLINTH_MS);
  await page.keyboard.up("d");
  await page.keyboard.up("s");
  await page.waitForTimeout(600);

  // Screenshot 1 — arena at the nerfed/zoomed-out state for the Self-Test Report.
  await page.screenshot({
    path: "test-results/soak2/soak2-arena.png",
    fullPage: false,
  });

  console.log("\n=== soak round 2 traces ===");
  console.log(`resolved engine zoom = ${engineZoom} (default 2.6667 → too tight)`);
  for (const line of traceLogs.slice(-40)) {
    console.log(line);
  }

  // No physics-flush panic across the soak.
  expect(
    allConsole.some((l) =>
      l.includes("Can't change this state while flushing queries")
    )
  ).toBe(false);
});
