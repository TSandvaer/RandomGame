/**
 * s2-mob-spawns.spec.ts
 *
 * **Ticket `86ca3amgt`** — S2 mob-spawn runtime consumer (OOS gap (a) from
 * PR #391). `Main._render_assembled_floor` now reads each placed chunk's
 * `LevelChunkDef.mob_spawns` and instantiates live mobs via the MobRegistry.
 * Before this PR, S2 zones rendered geometry but spawned ZERO mobs.
 *
 * **What this spec checks (end-to-end HTML5 boot → descend → S2 zone load):**
 *
 *   1. Boot the release build with `?force_descend=1` (the W2-T5 hook that
 *      auto-opens the DescendScreen after Room 01 — no 8-room + boss-kill
 *      traversal needed). Per the dispatch brief + html5-export.md § DebugFlags
 *      mutual-exclusivity, `force_descend` is used ALONE (NOT combined with
 *      `start_room`).
 *
 *   2. Click the "Return to Stratum 1" button — this fires `restart_run` →
 *      `Main._on_descend_restart_run` → `_begin_stratum_2` → `_load_s2_zone(0)`,
 *      assembling + rendering the first S2 zone (`s2_z1_entry_hall`).
 *
 *   3. Assert the `[combat-trace] Main.load_s2_zone | ... mobs=N` line fires
 *      with N >= 1 — the first authored S2 zone deterministically carries a
 *      sunken_scholar spawn (s2_room01.tres). `mobs=0` would mean the consumer
 *      did not fire (the pre-PR empty-skeleton state) → regression.
 *
 *   4. Assert NO `USER WARNING:` / `USER ERROR:` console line — covered both by
 *      the explicit check here AND by the test-base.ts fixture teardown gate.
 *      An unknown mob_id would surface as `USER WARNING:` (WarningBus route);
 *      a physics-flush mutation would surface as
 *      `Can't change this state while flushing queries`.
 *
 * **HTML5 visual-verification gate** — mob instantiation is an Area2D/hitbox-
 * bearing combat surface. This spec verifies the trace-observable spawn
 * contract; the author HTML5 self-soak (Self-Test Report) carries the
 * screenshot evidence of mobs rendered on-screen. Per
 * `playwright-headless-vs-real-browser-perception`, headless trace + the author
 * self-soak together are the gate; Sponsor soak remains gate-of-record for
 * subjective feel.
 *
 * Pattern source: descent-portal-open-map-click.spec.ts (force_descend boot +
 * DescendScreen canvas-click + [combat-trace] assertion).
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";

const BOOT_TIMEOUT_MS = 30_000;
const POST_CLICK_TRACE_WAIT_MS = 10_000;

test.describe("S2 mob spawning from FloorAssembler mob_spawns (86ca3amgt)", () => {
  test("descend → S2 zone load spawns >=1 mob, no USER WARNING", async ({
    page,
    context,
  }) => {
    await context.route("**/*", (route) => route.continue());
    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    // `?force_descend=1` ALONE — not combined with start_room (DebugFlags
    // mutual-exclusivity, html5-export.md). Opens the DescendScreen after
    // Room 01 boots.
    await page.goto(`${baseURL}/?force_descend=1`, {
      waitUntil: "domcontentloaded",
    });

    // 1. Main-ready sentinel.
    await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);

    // 2. force_descend hook fired.
    const forceLine = await capture
      .waitForLine(/\[Main\] DebugFlags\.force_descend=true/, BOOT_TIMEOUT_MS)
      .catch(() => null);
    expect(forceLine).not.toBeNull();

    // 3. Settle a frame so DescendScreen is in the tree + ready (return button
    //    grabs focus on fade-complete).
    await page.waitForTimeout(800);

    // 4. Click the "Return to Stratum 1" button. Authored at CENTER_BOTTOM
    //    anchor, offset_top=-120 / offset_bottom=-80, offset_left=-120 /
    //    right=+120 (DescendScreen.gd _build_ui). On the 1280x720 canvas:
    //      - CENTER_BOTTOM x ~ 640, y ~ 720
    //      - Button center y ~ 720 - (120+80)/2 = 720 - 100 = 620
    const canvas = await page.locator("canvas").first();
    await canvas.click({ position: { x: 640, y: 620 } });

    // 5. Assert the S2 zone-load trace fires with a mob count >= 1.
    //    Format: `[combat-trace] Main.load_s2_zone | zone_id=s2_z1_entry_hall
    //              seed=<n> chunks=<n> mobs=<n> bounds=...`
    const loadTrace = await capture
      .waitForLine(
        /\[combat-trace\] Main\.load_s2_zone \|.*mobs=\d+/,
        POST_CLICK_TRACE_WAIT_MS,
      )
      .catch(() => null);
    if (loadTrace === null) {
      const recent = capture
        .getLines()
        .filter((l) => l.text.includes("[combat-trace]"))
        .slice(-20)
        .map((l) => l.text)
        .join("\n");
      console.log(
        "[s2-mob-spawns] Main.load_s2_zone trace did NOT fire. " +
          "Recent [combat-trace] lines:\n" +
          (recent || "(none)"),
      );
    }
    expect(loadTrace).not.toBeNull();

    // Parse the mobs=<N> payload from the FIRST zone-load trace (z1 entry hall)
    // and assert >= 1. mobs=0 = the pre-PR empty-skeleton regression.
    const firstZoneLoad = capture
      .getLines()
      .map((l) => l.text)
      .find((t) => /Main\.load_s2_zone \|.*mobs=\d+/.test(t));
    expect(firstZoneLoad).toBeTruthy();
    const mobsMatch = firstZoneLoad!.match(/mobs=(\d+)/);
    expect(mobsMatch).not.toBeNull();
    const mobCount = mobsMatch ? parseInt(mobsMatch[1], 10) : 0;
    expect(mobCount).toBeGreaterThanOrEqual(1);

    // Also confirm the z1 zone_id is the Sponsor-locked entry hall.
    expect(/zone_id=s2_z1_entry_hall/.test(firstZoneLoad!)).toBe(true);

    // 6. No physics-flush panic across the spawn.
    expect(
      capture
        .getLines()
        .some((l) =>
          l.text.includes("Can't change this state while flushing queries"),
        ),
    ).toBe(false);

    // 7. No USER WARNING / USER ERROR (also gated by test-base.ts teardown).
    const userWarnings = capture
      .getLines()
      .filter(
        (l) =>
          l.text.includes("USER WARNING:") || l.text.includes("USER ERROR:"),
      )
      .map((l) => l.text);
    expect(userWarnings, `unexpected USER WARNING/ERROR:\n${userWarnings.join("\n")}`).toEqual(
      [],
    );

    capture.detach();
  });
});
