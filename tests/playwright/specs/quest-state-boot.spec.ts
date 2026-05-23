/**
 * quest-state-boot.spec.ts
 *
 * **Ticket W2-T6 (`86c9y7ydg`)** — M3 Tier 3 W2 QuestState model + save
 * integration. Boot-smoke check that the new W2-T6 surfaces
 * (`QuestActionRouter` persistence wiring + `QuestStateResolver` static
 * class + Player.active_bounty/completed_bounties fields + Save.gd
 * additive backfill) all parse cleanly and don't taint the autoload-graph
 * boot chain.
 *
 * **What this checks (boot-smoke / structural):**
 *
 *   1. Build boots without USER WARNING / USER ERROR (universal warning
 *      gate via the test-base.ts fixture).
 *   2. The autoload chain reaches `[Main] M1 play-loop ready`. If any of
 *      the new W2-T6 scripts (`scripts/quests/{QuestDef,QuestState,QuestStateResolver}.gd`
 *      or the extended `QuestActionRouter.gd`) has a parser error, the
 *      autoload graph stalls and this sentinel never prints.
 *   3. No `USER WARNING:` or `USER ERROR:` lines naming QuestActionRouter /
 *      QuestStateResolver / QuestDef / QuestState during boot.
 *   4. No `Parser Error` against `res://scripts/quests/` (catches a
 *      regression where one of the new typed Resources has an unresolved
 *      `@export` type / typo).
 *
 * **What this DOES NOT check (deferred to W3 / Track 3):**
 *
 *   - End-to-end NPC interact → quest accept → save → reload. There are
 *     no NPC scenes in the production play loop that fire
 *     `accept_bounty` actions yet (W3 sub-track 5b hub-town impl wires
 *     NPCs to invoke DialogueController.open + responses to fire
 *     quest_action_invoked). GUT covers the router persistence via
 *     `test_quest_action_router_persists.gd`.
 *   - Save round-trip across page reload. Save persistence lives in
 *     HTML5 OPFS; reload+restore is part of a wider Save round-trip
 *     surface covered by Tess's M3 Tier 3 acceptance plan.
 *
 * **HTML5 visual-verification escape clause** — W2-T6 ships zero new
 * visual surface (model + save + signal wiring only). No Polygon2D /
 * CPUParticles2D / Area2D / modulate tween. Per
 * `.claude/docs/html5-export.md` § "Visual-verification escape clause"
 * the ticket is escape-clause-eligible boot-class; the Self-Test Report
 * enumerates probe targets (none required, full escape).
 *
 * Pattern source: `dialogue-spike-smoke.spec.ts` + `dialogue-hub-town.spec.ts`.
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";

const BOOT_TIMEOUT_MS = 30_000;

test.describe("quest-state model + save integration — boot smoke (W2-T6 / 86c9y7ydg)", () => {
  test("autoload chain + quest scripts + save backfill — no boot warnings", async ({
    page,
    context,
  }) => {
    await context.route("**/*", (route) => route.continue());
    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL =
      process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(baseURL, { waitUntil: "domcontentloaded" });

    // 1. Wait for canonical Main-ready sentinel. If any new W2-T6 script
    //    has a parser error or one of the autoloads panics during _ready
    //    (e.g. QuestActionRouter's extended dispatch handler) the chain
    //    stalls and this sentinel never prints.
    await capture.waitForLine(
      /\[Main\] M1 play-loop ready/,
      BOOT_TIMEOUT_MS
    );

    // 2. No QuestActionRouter-namespaced warnings during boot. The router's
    //    WarningBus shim prefixes warnings with "QuestActionRouter.<method>:"
    //    so a misconfigured persistence wiring (e.g. unknown NPC offering a
    //    bounty, single-active-bounty rejection on a boot-time stale state)
    //    would surface here as a `USER WARNING: ...QuestActionRouter...` line.
    //    None should fire on a clean boot — no NPC interact happens during
    //    autoload init.
    const routerWarning = capture.findUnexpectedLine(
      /QuestActionRouter\./
    );
    if (routerWarning) {
      console.log(
        "[quest-state-boot] QuestActionRouter warning:\n" + routerWarning
      );
    }
    expect(routerWarning).toBeNull();

    // 3. No QuestStateResolver-namespaced warnings. The resolver is a
    //    pure static class with no warning paths in W2-T6 — any
    //    USER WARNING citing it would be a regression introduced by a
    //    future refactor.
    const resolverWarning = capture.findUnexpectedLine(
      /QuestStateResolver\./
    );
    if (resolverWarning) {
      console.log(
        "[quest-state-boot] QuestStateResolver warning:\n" + resolverWarning
      );
    }
    expect(resolverWarning).toBeNull();

    // 4. No parser errors against the new quest scripts. A typo in an
    //    @export type, an unresolved class_name reference, or a missing
    //    `extends` line would print
    //    `USER ERROR: ... Parser Error: ... res://scripts/quests/...`
    //    at autoload boot. The universal warning gate catches it via
    //    test-base's afterEach, but we sweep here too with a named
    //    pattern so the diagnostic is legible.
    const parseErr = capture.findUnexpectedLine(
      /res:\/\/scripts\/quests\/.*Parser Error/
    );
    if (parseErr) {
      console.log("[quest-state-boot] quests/ parser error:\n" + parseErr);
    }
    expect(parseErr).toBeNull();

    // 5. No save-migration warnings during the autoload init's
    //    Save.gd path. If a v4 → v5 quest backfill went wrong (e.g. a
    //    legacy save loads with a malformed active_bounty payload), the
    //    Save autoload would route the warning through WarningBus, prefixing
    //    with "[Save]" or category "save". On a fresh HTML5 build with no
    //    save on disk, Save.load_game is not invoked during boot, but a
    //    Sponsor soak with an existing save WOULD exercise this — pin
    //    here defensively for the case where a Tess fixture seeds OPFS.
    const saveWarn = capture.findUnexpectedLine(/USER WARNING:.*\[Save\]/);
    if (saveWarn) {
      console.log("[quest-state-boot] Save autoload warning:\n" + saveWarn);
    }
    expect(saveWarn).toBeNull();

    capture.detach();
  });
});
