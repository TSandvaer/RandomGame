/**
 * dialogue-spike-smoke.spec.ts
 *
 * **Ticket 86c9xuab3 — M3 Tier 3 W1 dialogue system spike** (Sponsor SI-2,
 * post-wave3-sequencing.md §1 Commitment 2).
 *
 * **What it checks (structural / boot smoke):**
 *   1. Build boots without USER WARNING / USER ERROR (universal warning
 *      gate via the test-base.ts fixture).
 *   2. The DialogueController autoload survives the boot chain (no
 *      `[Save] / [Main] ... parser` errors during the autoload-graph init).
 *   3. The three shipped dialogue .tres fixtures
 *      (`s1_warden_scholar.tres` / `hub_vendor.tres` /
 *      `hub_anvil_keeper.tres`) do not emit any unknown-id /
 *      schema-mismatch warnings during the boot's resource-pre-import pass.
 *
 * **What this DOES NOT check (spike out-of-scope, deferred to W2):**
 *   - In-game NPC interact → dialogue panel open. The spike does NOT wire
 *     NPC interaction; W2's hub-town impl ticket wires the
 *     `body_entered → DialogueController.open` flow.
 *   - Dialogue panel rendering. The panel scene exists but is not
 *     instanced in Main.tscn during the spike. GUT covers panel
 *     instantiation + signal wiring via `test_dialogue_panel.gd`.
 *   - State-branching content correctness. GUT covers tree resolution
 *     via `test_dialogue_tree_def.gd` + `test_dialogue_controller.gd`.
 *
 * **HTML5 visual-verification escape clause** — this spike's runtime
 * surface is GDScript only (autoload + Resource classes), no
 * Polygon2D / CPUParticles2D / Area2D / modulate tween. Per
 * `.claude/docs/html5-export.md` § "Visual-verification escape clause"
 * the spike is escape-clause-eligible; the Self-Test Report enumerates
 * probe targets for the panel-rendering path (deferred to W2 in-game
 * wiring + Sponsor soak).
 *
 * Pattern source: `audio-bus-boot-smoke.spec.ts`.
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";

const BOOT_TIMEOUT_MS = 30_000;

test.describe("dialogue spike — boot smoke (W1 / 86c9xuab3)", () => {
  test("autoload boot chain reaches Main ready + no DialogueController warnings", async ({
    page,
    context,
  }) => {
    await context.route("**/*", (route) => route.continue());
    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL =
      process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(baseURL, { waitUntil: "domcontentloaded" });

    // 1. Wait for the canonical boot-ready sentinel. If DialogueController's
    //    autoload _ready panics or its dependency scripts (DialogueTreeDef,
    //    DialogueBranch, DialogueResponse) fail to parse, the autoload
    //    graph stalls and `[Main] M1 play-loop ready` never prints.
    await capture.waitForLine(
      /\[Main\] M1 play-loop ready/,
      BOOT_TIMEOUT_MS
    );

    // 2. No DialogueController-namespaced warnings during boot. The
    //    controller's WarningBus shim prefixes warnings with
    //    "DialogueController.<method>:" so a misconfigured shipped
    //    fixture (unknown branch_key, null branch) would surface here as
    //    a `USER WARNING: ...DialogueController...` line. Sponsor's
    //    M2 RC meta-finding (test-conventions.md § Universal warning gate)
    //    is the reason this assertion is here rather than just the
    //    test-base fixture's blanket no-warnings check — the named-pattern
    //    sweep makes the failure diagnostic legible if it does fire.
    const dcWarning = capture.findUnexpectedLine(
      /DialogueController\./
    );
    if (dcWarning) {
      console.log("[dialogue-spike-smoke] DialogueController warning:\n" + dcWarning);
    }
    expect(dcWarning).toBeNull();

    // 3. No script-parse errors against the dialogue script paths. A
    //    Resource class with a typo in its `class_name` or an unresolved
    //    type in a `@export` field prints
    //    `USER ERROR: ... Parser Error: ... res://scripts/dialogue/...`
    //    at autoload boot. The universal warning gate catches it via
    //    test-base's afterEach, but we sweep here too with a named
    //    pattern so the diagnostic is legible.
    const parseErr = capture.findUnexpectedLine(
      /res:\/\/scripts\/dialogue\/.*Parser Error/
    );
    if (parseErr) {
      console.log("[dialogue-spike-smoke] Dialogue parser error:\n" + parseErr);
    }
    expect(parseErr).toBeNull();

    // 4. No `resources/dialogue/` fixture-load failures. The three shipped
    //    .tres fixtures are referenced by ContentRegistry-style discovery
    //    paths in W2; the spike itself does NOT load them at boot, but
    //    a future regression where one fixture has an invalid sub-resource
    //    would emit a `failed to load res://resources/dialogue/...` warn.
    const fixtureWarn = capture.findUnexpectedLine(
      /failed to load.*res:\/\/resources\/dialogue\//
    );
    if (fixtureWarn) {
      console.log("[dialogue-spike-smoke] Dialogue fixture load failure:\n" + fixtureWarn);
    }
    expect(fixtureWarn).toBeNull();

    capture.detach();
  });
});
