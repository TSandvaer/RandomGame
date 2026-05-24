/**
 * world-map-panel-render.spec.ts
 *
 * **Ticket W2-T5 (`86c9y10fv`)** — M3 Tier 3 W2 world-map UI minimal +
 * descent-portal integration + discovery write hook + paired tests.
 *
 * **What this checks (HTML5 boot smoke):**
 *
 *   1. Build boots without USER WARNING / USER ERROR (universal warning
 *      gate via the test-base.ts fixture). Catches:
 *       - WorldMapPanel script parse-time regressions (any typo in
 *         scripts/ui/WorldMapPanel.gd surfaces as a USER ERROR).
 *       - DescendScreen "Open Map" button wiring regressions (the
 *         button is built procedurally; a typo'd scene path
 *         constant would push_warning at click time).
 *       - Save migration regressions (W2-T5 added the discovered_zones
 *         backfill — a missing key in DEFAULT_PAYLOAD would push_warning
 *         on save-write).
 *
 *   2. `[combat-trace] Main.discover_zone` line fires on the FIRST room
 *      load (boot → Room 01 instantiated → discovery hook writes
 *      `s1_z1_outer_cloister`). The `new=true` flag distinguishes first
 *      discovery from re-entry. Headless GUT can't observe the
 *      combat-trace shim (HTML5-only via DebugFlags.combat_trace_enabled);
 *      this Playwright spec is the only automated coverage for the trace
 *      empirically firing in the production HTML5 build.
 *
 *   3. No `WorldMapPanel.*` warnings on boot. The panel is NOT shown at
 *      boot (it's lazy-instantiated by DescendScreen's "Open Map" click),
 *      but if Main.gd ever auto-instantiated it pre-gesture and the panel
 *      crashed, this catches it.
 *
 * **What this DOES NOT check (deferred):**
 *
 *   - End-to-end "descent portal → click Open Map → panel renders →
 *     close." That requires reaching the boss room first; the M3 player
 *     can't reach it via Playwright without the `?start_room=8` debug
 *     flag + boss-kill traversal. Sponsor self-soak covers the integrated
 *     surface end-to-end.
 *
 *   - Visual rendering of the parchment + zone markers. This is escape-
 *     clause eligible per .claude/docs/html5-export.md (Label + ColorRect
 *     + Button primitives are renderer-safe) but Sponsor's interactive
 *     soak is the gate of record per the html5-visual-gated-author-self-soak
 *     rule + the playwright-headless-vs-real-browser perception rule.
 *
 * **HTML5 visual-verification escape clause** — this spec's surface is
 * boot smoke + trace verification. The WorldMapPanel's modulate / zone-
 * marker geometry / X-cross strokes are NOT exercised by Playwright
 * (panel is not opened); the visual gate routes to Sponsor soak per the
 * Self-Test Report probe targets.
 *
 * Pattern source: `dialogue-hub-town.spec.ts` (W2-T2) +
 * `quest-state-boot.spec.ts` (W2-T6).
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";

const BOOT_TIMEOUT_MS = 30_000;

test.describe("world-map panel render — boot smoke (W2-T5 / 86c9y10fv)", () => {
  test("boot → Main ready + no WorldMapPanel-namespaced warnings", async ({
    page,
    context,
  }) => {
    await context.route("**/*", (route) => route.continue());
    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL =
      process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(baseURL, { waitUntil: "domcontentloaded" });

    // 1. Wait for canonical Main-ready sentinel. If WorldMapPanel.gd
    //    has a parse-time error, OR DescendScreen.gd's edits introduce
    //    a script-load failure, OR Save.gd's backfill function refactor
    //    breaks the autoload boot chain, this line never prints.
    await capture.waitForLine(
      /\[Main\] M1 play-loop ready/,
      BOOT_TIMEOUT_MS
    );

    // 2. No WorldMapPanel-namespaced warnings on boot. The panel is NOT
    //    rendered at boot (lazy-instantiated by DescendScreen), but any
    //    script-load warning from preload chains would surface here.
    const panelWarning = capture.findUnexpectedLine(/WorldMapPanel\./);
    if (panelWarning) {
      console.log(
        "[world-map-panel-render] WorldMapPanel warning:\n" + panelWarning
      );
    }
    expect(panelWarning).toBeNull();

    // 3. No script-parse errors against ui or screens or save paths.
    //    A typo'd export in any of these scripts surfaces at autoload
    //    boot as `USER ERROR: ... Parser Error: ... res://scripts/...`.
    const parseErr = capture.findUnexpectedLine(
      /res:\/\/scripts\/(ui|screens|save|player)\/.*Parser Error/
    );
    if (parseErr) {
      console.log(
        "[world-map-panel-render] UI/screens/save/player parser error:\n" +
          parseErr
      );
    }
    expect(parseErr).toBeNull();

    // 4. No fixture-load failures against `resources/level/zones/`.
    //    The single shipped zone fixture (`s1_z1_outer_cloister.tres`)
    //    is consumed by the panel's _load_zone_registry() at instantiation
    //    time. A regression that broke the .tres would surface here only
    //    if the panel WAS instantiated at boot — which it isn't, but the
    //    pattern matches dialogue-hub-town.spec.ts's defensive sweep for
    //    future-proofing.
    const zoneWarn = capture.findUnexpectedLine(
      /failed to load.*res:\/\/resources\/level\/zones\//
    );
    if (zoneWarn) {
      console.log(
        "[world-map-panel-render] Zone fixture load failure:\n" + zoneWarn
      );
    }
    expect(zoneWarn).toBeNull();

    // 5. Discovery hook fired on boot — Room 01 load wrote
    //    `discovered_zones[s1_z1_outer_cloister] = true` and the
    //    `[combat-trace] Main.discover_zone | zone_id=s1_z1_outer_cloister
    //    new=true` line emitted. This is the structural pin for the
    //    discovery hook actually wiring up in production (vs the GUT
    //    surface which mocks the Player via stubs).
    //
    //    Use waitForLine (the canonical positive-assertion shape on
    //    ConsoleCapture) — the trace fires from Main._load_room_at_index
    //    which runs synchronously inside Main._ready, but the trace
    //    line lands in Playwright's console event stream a few ms after
    //    the [Main] M1 play-loop ready sentinel above, so we need a
    //    short bounded wait, not an instant findUnexpectedLine snapshot.
    const discoveryTrace = await capture
      .waitForLine(
        /\[combat-trace\] Main\.discover_zone \| zone_id=s1_z1_outer_cloister new=true/,
        5_000
      )
      .catch(() => null);
    if (discoveryTrace === null) {
      const recent = capture
        .getLines()
        .filter((l) => l.text.includes("[combat-trace]"))
        .slice(-20)
        .map((l) => l.text)
        .join("\n");
      console.log(
        "[world-map-panel-render] Discovery hook did NOT fire on first room load. " +
          "Recent [combat-trace] lines:\n" +
          (recent || "(none)")
      );
    }
    expect(discoveryTrace).not.toBeNull();

    capture.detach();
  });
});
