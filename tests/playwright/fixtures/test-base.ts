/**
 * test-base.ts — Playwright `test` fixture extended with auto-attached
 * ConsoleCapture + universal USER WARNING / USER ERROR zero-assertion.
 *
 * **Ticket 86c9uf0mm — universal console-warning zero-gate.**
 *
 * Sponsor M2 RC soak meta-finding (2026-05-15): 3 of 4 Sponsor findings
 * would have been caught (or had higher caught-by-harness leverage) by a
 * universal console-warning zero-assertion. `ConsoleCapture.
 * getLinesByType("warn")` has existed in `console-capture.ts:83-86`
 * since the harness landed, but is NEVER called for the "warn" type
 * anywhere in the spec corpus. Every spec rolls its own
 * `findFirstError()` for `console.error` lines, but `console.warn`
 * lines (Godot `push_warning` → `USER WARNING:` prefix) sail past.
 *
 * **Three bug classes this gate catches:**
 *
 *   1. `leather_vest` unknown-id class (Sponsor finding #3, ticket
 *      `86c9uen3z`). Fires at boot via
 *      `ItemInstance.from_save_dict:103 push_warning("ItemInstance.
 *      from_save_dict: unknown item id 'leather_vest'")`. Would have
 *      flipped RED on the first release-build spec run post-bug.
 *
 *   2. DirAccess HTML5 recursion class (Class B-3 from the
 *      `investigate` skill consolidator output). HTML5 export's
 *      `DirAccess.current_is_dir()` returns false on subdirs of packed
 *      `.pck` resources — recursive scans silently skip subdirs.
 *      ContentRegistry.load_all and the new MobRegistry have latent
 *      surfaces here. When any current-or-future scan tries to load a
 *      resource from a skipped subdir and `push_warning`s the failure,
 *      this gate catches it.
 *
 *   3. Save-schema migration warnings (Class B-5). If the v3→v4
 *      migration ever silently no-ops and a save loads as v3 with an
 *      unrecognised v4-shape entry, the
 *      `push_warning("[Save] save schema_version %d is newer than
 *      runtime %d")` shim or any of the per-entry warnings fire here.
 *
 * **Why a custom `test` fixture (not a global afterEach in
 * playwright.config.ts):** Playwright's `playwright.config.ts` doesn't
 * support test-level `afterEach` hooks at the config layer — those are
 * authored in `describe` blocks inside specs. The cleanest way to apply
 * a hook to every spec is to extend the base `test` export with a
 * fixture that auto-attaches the capture AND auto-asserts on teardown.
 * Specs migrate by changing one import line.
 *
 * **Opt-out semantics.** A spec that DELIBERATELY exercises a warning
 * path (e.g. a future "save with truly unknown id — graceful drop"
 * test) can opt out by passing `test.use({ allowUserWarnings: true })`
 * at the `describe` level, OR by passing a regex array via
 * `expectedUserWarnings: [/specifically allowed warning/]`. The
 * opt-out is documented in the fixture's `allowUserWarnings` and
 * `expectedUserWarnings` options.
 *
 * **Rollout plan (this PR is Phase 1 of 3):**
 *
 *   Phase 1 (this PR — `86c9uf0mm` Half A scaffold):
 *     - Land the fixture under `fixtures/test-base.ts`.
 *     - Author ONE demonstration spec
 *       (`universal-console-warning-gate.spec.ts`) that imports the new
 *       `test` and uses the auto-asserted gate. Marked `test.fail()`
 *       until Devon's `86c9uen3z` (leather_vest) fix lands.
 *     - Existing specs UNCHANGED — still import from
 *       `@playwright/test` and run unaffected.
 *
 *   Phase 2 (flip — happens AFTER Devon's leather_vest fix merges):
 *     - Flip the demonstration spec from `test.fail()` to `test()`.
 *     - Migrate existing specs to the new `test` import — one-line
 *       change per spec. CI catches any latent warnings each spec
 *       boots; either fix the underlying bug or add an
 *       `expectedUserWarnings` allow-list.
 *
 *   Phase 3 (`86c9uf0mm` Half B — Devon-owned):
 *     - GUT-side `push_warning` signal-watcher for save-load +
 *       ItemRegistry + MobRegistry tests. Out of this PR's scope.
 *
 * **Usage in specs:**
 *
 *   import { test, expect } from "../fixtures/test-base";
 *
 *   test.describe("my feature", () => {
 *     test("my test", async ({ page, consoleCapture, context }) => {
 *       // consoleCapture is auto-attached BEFORE page.goto runs, so
 *       // boot-time lines are captured.
 *       await page.goto(...);
 *       // ... assertions ...
 *       // afterEach auto-asserts no USER WARNING / USER ERROR fired.
 *     });
 *
 *     // Opt-out (whole describe block):
 *     test.use({ allowUserWarnings: true });
 *     // Or scoped allow-list:
 *     test.use({ expectedUserWarnings: [/known warning shape/] });
 *   });
 *
 * References:
 *   - ClickUp 86c9uf0mm (this ticket)
 *   - ClickUp 86c9uen3z (Devon's leather_vest fix — flip trigger)
 *   - tests/playwright/fixtures/console-capture.ts — the ConsoleCapture
 *     class this fixture auto-attaches
 *   - .claude/docs/combat-architecture.md § "Harness coverage gap"
 *     (Sponsor-authored, pending commit)
 */

import { test as base, expect } from "@playwright/test";
import { ConsoleCapture } from "./console-capture";

/**
 * Test-level options that opt out of (or constrain) the auto-asserted
 * universal USER WARNING / USER ERROR gate. Both default to OFF (full
 * strict gate enabled).
 */
interface GateOptions {
  /**
   * If true, the auto-asserted gate is fully disabled for tests in this
   * `describe` block. Use sparingly — the gate exists precisely to catch
   * warnings, so opting out should be deliberate + documented inline.
   *
   * Typical legitimate use: a test that deliberately exercises a
   * warning path (e.g. "load save with unknown id — assert graceful
   * drop") where the warning is the assertion target.
   */
  allowUserWarnings: boolean;

  /**
   * Allow-list of regex patterns. If set, USER WARNING / USER ERROR
   * lines matching ANY of these patterns are NOT counted as gate
   * violations. Lines NOT matching are still violations.
   *
   * Use when a test should produce a specific known warning but the
   * test should still catch ANY OTHER unexpected warnings — narrower
   * than `allowUserWarnings: true`.
   *
   * Example:
   *   test.use({
   *     expectedUserWarnings: [
   *       /USER WARNING: ItemInstance.from_save_dict: unknown item id 'definitely_not_real'/
   *     ]
   *   });
   */
  expectedUserWarnings: RegExp[];
}

/**
 * Custom Playwright `test` export with:
 *
 *   - `consoleCapture` auto-fixture — a `ConsoleCapture` instance
 *     attached to the page BEFORE the test body runs, so boot-time
 *     console lines are captured from the first frame.
 *
 *   - `afterEach`-style auto-assertion — after the test body completes
 *     (regardless of pass/fail), the fixture scans the capture buffer
 *     for `USER WARNING:` / `USER ERROR:` lines (Godot HTML5's
 *     `push_warning` / `push_error` shape) and fails the test if any
 *     are present.
 *
 *   - `allowUserWarnings` + `expectedUserWarnings` opt-out knobs (see
 *     `GateOptions` above).
 *
 * Specs adopt this gate by changing their import line from
 * `import { test, expect } from "@playwright/test"` to
 * `import { test, expect } from "../fixtures/test-base"`. Nothing
 * else in the spec needs to change.
 */
export const test = base.extend<
  GateOptions & { consoleCapture: ConsoleCapture }
>({
  allowUserWarnings: [false, { option: true }],
  expectedUserWarnings: [[], { option: true }],

  /**
   * Auto-attached ConsoleCapture. The fixture function is `async`
   * + awaits `use(capture)` — anything before `use` runs as setup
   * (attach the listener), anything after runs as teardown (assert
   * + detach).
   *
   * The fixture is `{ auto: true }` so it runs even for tests that
   * don't explicitly request `consoleCapture` in their destructure.
   * This is what makes the gate UNIVERSAL — every spec gets it for
   * free once the import line migrates.
   */
  consoleCapture: [
    async (
      { page, allowUserWarnings, expectedUserWarnings },
      use
    ) => {
      const capture = new ConsoleCapture(page);
      capture.attach();

      // Run the test body. The capture stays attached across the entire
      // test lifecycle, including page.goto() and any subsequent
      // navigations.
      await use(capture);

      // ---- Teardown: assert no unexpected USER WARNING / USER ERROR --
      //
      // We run this AFTER `use(capture)` so it executes regardless of
      // whether the test body passed or failed. Playwright records this
      // as a teardown failure on top of any test-body failure, so the
      // test report distinguishes "test body failed" from "no warnings"
      // failures.
      const allLines = capture.getLines();
      const violations = allLines.filter((l) => {
        // CRITICAL: Playwright's ConsoleMessage.type() returns "warning"
        // (not "warn") for console.warn() calls — verified empirically
        // 2026-05-16 against Playwright 1.49 + Chromium. The full enum
        // is `"log" | "debug" | "info" | "error" | "warning" | "dir" |
        // "dirxml" | "table" | "trace" | "clear" | "startGroup" |
        // "startGroupCollapsed" | "endGroup" | "assert" | "profile" |
        // "profileEnd" | "count" | "time" | "timeEnd"`. The original
        // check (`l.type !== "warn"`) silently filtered out every
        // `USER WARNING:` line — gate was a no-op for warnings since
        // shipped (PR #217); the canary at universal-console-warning-
        // gate.spec.ts:205 surfaced it via "Expected to fail, but
        // passed" (ticket 86c9upfex). Accept BOTH "warning" (current
        // Playwright API) AND "warn" (defensive against future API
        // renames / CDP variations).
        if (l.type !== "warning" && l.type !== "warn" && l.type !== "error")
          return false;
        const isUserWarning = /^USER WARNING:/.test(l.text);
        const isUserError = /^USER ERROR:/.test(l.text);
        if (!isUserWarning && !isUserError) return false;
        // Pass through the allow-list filter.
        if (expectedUserWarnings.some((re) => re.test(l.text))) {
          return false;
        }
        return true;
      });

      // Always detach, even if the assertion below throws — ConsoleCapture
      // uses page.off() to release the listener and prevents Playwright's
      // page-close from triggering a "listener attached during dispose"
      // warning.
      capture.detach();

      if (!allowUserWarnings && violations.length > 0) {
        const violationDump = violations
          .map((l) => `  [${l.type}] ${l.text}`)
          .join("\n");
        // expect(...).toEqual([]) gives the cleanest failure message
        // shape (lists the array contents in the diff) but we want a
        // richer prose message — use a direct throw via expect.fail-
        // style assertion.
        expect.soft(
          violations.length,
          `Universal console-warning gate (ticket 86c9uf0mm): the test ` +
            `body completed but its console produced ${violations.length} ` +
            `unexpected USER WARNING / USER ERROR line(s). The gate exists ` +
            `to catch (a) save-load unknown-id warnings (leather_vest ` +
            `class — Sponsor finding 86c9uen3z), (b) DirAccess HTML5 ` +
            `recursion warnings (Class B-3), (c) save-schema migration ` +
            `warnings (Class B-5), and any analogous push_warning / ` +
            `push_error lines emitted by the boot or test-body code paths. ` +
            `\n\nViolations:\n${violationDump}\n\nTo intentionally allow ` +
            `a specific warning shape, use:\n  test.use({ ` +
            `expectedUserWarnings: [/your regex/] });\n\nTo fully disable ` +
            `the gate for a describe block (last resort), use:\n  ` +
            `test.use({ allowUserWarnings: true });`
        ).toBe(0);
        // Hard throw so the test is marked failed (not just soft-flagged).
        throw new Error(
          `Universal console-warning gate: ${violations.length} ` +
            `USER WARNING/ERROR line(s). See test output for details.`
        );
      }
    },
    { auto: true },
  ],
});

export { expect };
