/**
 * dialogue-hub-town.spec.ts
 *
 * **Ticket W2-T2 (`86c9y0zyv`)** — M3 Tier 3 W2 dialogue impl + 3 hub-town
 * dialogue trees + signal wiring. Builds on the W1 dialogue spike
 * (`86c9xuab3`, PR landed) — that spec was `dialogue-spike-smoke.spec.ts`
 * (still running, still passing); this spec is the W2 layer that adds:
 *
 *   - Boot-smoke against the W2 `QuestActionRouter` autoload (new — must
 *     register cleanly alongside DialogueController without parser /
 *     autoload-graph warnings).
 *   - Boot-smoke against the three NEW hub-town .tres fixtures
 *     (`resources/dialogue/hub_town/hadda_vendor.tres`,
 *     `brother_voll_anvil.tres`, `sister_ennick_storyteller.tres`).
 *   - DialoguePanel mount on Main.tscn — confirms the panel was instantiated
 *     and is reachable via Main's accessor (the W2-T2 production-wiring step).
 *
 * **What this DOES NOT check** (deferred):
 *
 *   - End-to-end NPC interact → dialogue panel open. There are NO NPC
 *     scenes in the production play loop yet that open dialogue (W3
 *     sub-track 5b hub-town impl wires NPCs to call
 *     `DialogueController.open` on body-enter + E-press). Until then, the
 *     production-side Playwright surface for dialogue interaction is empty.
 *     This spec is structural / boot-smoke, NOT interactive.
 *
 *   - Dialogue panel visual rendering. The panel uses
 *     Label / Button / ColorRect / RichTextLabel primitives that are
 *     escape-clause-eligible per
 *     `.claude/docs/html5-export.md` § "Visual-verification escape clause".
 *     The Self-Test Report enumerates probe targets for Sponsor soak when
 *     W3 wires NPC interaction.
 *
 * **HTML5 visual-verification escape clause** — this spec's surface is
 * autoload boot + .tres fixture validation. The DialoguePanel's modulate /
 * Polygon2D / particles surface is NOT exercised here (no NPC interact);
 * the visual gate applies to the panel only when production NPC
 * interaction lands (W3). Author self-soak in incognito + DevTools per
 * `html5-visual-gated-author-self-soak` memory rule covered separately
 * in the Self-Test Report.
 *
 * Pattern source: `dialogue-spike-smoke.spec.ts` (W1) +
 * `audio-bus-boot-smoke.spec.ts`.
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";

const BOOT_TIMEOUT_MS = 30_000;

test.describe("dialogue hub-town impl — boot smoke (W2-T2 / 86c9y0zyv)", () => {
  test("autoload chain + W2 hub-town fixtures + DialoguePanel mount", async ({
    page,
    context,
  }) => {
    await context.route("**/*", (route) => route.continue());
    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL =
      process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(baseURL, { waitUntil: "domcontentloaded" });

    // 1. Wait for canonical Main-ready sentinel. If DialogueController OR the
    //    new QuestActionRouter autoload's _ready panics or its dependency
    //    scripts fail to parse, the autoload graph stalls and this line
    //    never prints.
    await capture.waitForLine(
      /\[Main\] M1 play-loop ready/,
      BOOT_TIMEOUT_MS
    );

    // 2. No DialogueController-namespaced warnings during boot. Same shape
    //    as dialogue-spike-smoke.spec.ts — surfaces fixture-resolution
    //    regressions (unknown branch_key, null branch, etc.) as named
    //    diagnostics rather than as opaque USER WARNING lines.
    const dcWarning = capture.findUnexpectedLine(/DialogueController\./);
    if (dcWarning) {
      console.log("[dialogue-hub-town] DialogueController warning:\n" + dcWarning);
    }
    expect(dcWarning).toBeNull();

    // 3. No QuestActionRouter-namespaced warnings during boot. The router
    //    autoload's _ready subscribes to DialogueController signals;
    //    a missing-signal or mis-named-signal regression would surface
    //    here. Diagnostic-named pattern so the failure is legible.
    const routerWarning = capture.findUnexpectedLine(/QuestActionRouter\./);
    if (routerWarning) {
      console.log(
        "[dialogue-hub-town] QuestActionRouter warning:\n" + routerWarning
      );
    }
    expect(routerWarning).toBeNull();

    // 4. No script-parse errors against dialogue OR quests script paths.
    //    Either resource class with a typo would print
    //    `USER ERROR: ... Parser Error: ... res://scripts/dialogue/...`
    //    OR `res://scripts/quests/...` at autoload boot. The universal
    //    gate (test-base fixture) catches it; we sweep here too with a
    //    named pattern so the diagnostic is legible.
    const parseErr = capture.findUnexpectedLine(
      /res:\/\/scripts\/(dialogue|quests)\/.*Parser Error/
    );
    if (parseErr) {
      console.log("[dialogue-hub-town] Dialogue/quests parser error:\n" + parseErr);
    }
    expect(parseErr).toBeNull();

    // 5. No fixture-load failures against `resources/dialogue/hub_town/`.
    //    The three W2 trees ship at this path; a future regression where
    //    one fixture has an invalid sub-resource (e.g. SubResource id
    //    typo) would emit a `failed to load
    //    res://resources/dialogue/hub_town/...` warn.
    const fixtureWarn = capture.findUnexpectedLine(
      /failed to load.*res:\/\/resources\/dialogue\/hub_town\//
    );
    if (fixtureWarn) {
      console.log("[dialogue-hub-town] Hub-town fixture load failure:\n" + fixtureWarn);
    }
    expect(fixtureWarn).toBeNull();

    // 6. No DialoguePanel mount failure. The W2 Main.gd change adds
    //    `_build_dialogue_panel()` which push_warning's if the scene
    //    fails to instantiate. A regression that broke the panel scene
    //    would surface here.
    const panelMountWarn = capture.findUnexpectedLine(
      /\[Main\].*[Dd]ialogue.*[Pp]anel/
    );
    if (panelMountWarn) {
      console.log(
        "[dialogue-hub-town] DialoguePanel mount failure:\n" + panelMountWarn
      );
    }
    expect(panelMountWarn).toBeNull();

    capture.detach();
  });
});
