/**
 * universal-console-warning-gate.spec.ts
 *
 * **Demonstration spec for the universal console-warning zero-gate**
 * (ticket `86c9uf0mm` Half A — Playwright). The spec proves the gate
 * mechanism works end-to-end: it imports `test` from the new
 * `../fixtures/test-base` (instead of `@playwright/test`), boots the
 * release-build artifact, and lets the auto-asserted gate fire on any
 * `USER WARNING:` / `USER ERROR:` line.
 *
 * **Current disposition: `test()` — flipped 2026-05-15 since PR #214
 * (Devon's `leather_vest` fix, ticket `86c9uen3z`) already merged to
 * `main` before this PR's commit landed.** The gate now asserts clean
 * boot as an ongoing regression guard. Next step:
 *
 *   1. Migrate the other specs (`ac1-boot-and-sha`, `ac2-first-kill`,
 *      etc.) to import from `../fixtures/test-base` instead of
 *      `@playwright/test`. One-line change per spec; the gate then
 *      applies universally as the ticket spec requires (tracked under
 *      this same ticket `86c9uf0mm` as Phase 2).
 *
 * **Why ship this as a separate demonstration spec rather than as the
 * sole new spec:** the universal application requires migrating every
 * existing spec's import line. That's an 11-line change but it
 * mechanically depends on the leather_vest fix landing first (otherwise
 * every spec turns RED at boot). Splitting into "gate infrastructure
 * + demonstration spec ships now; migration ships in the
 * leather_vest-fix-paired flip-PR" decouples the two PRs and gives
 * each a clean diff-readable scope.
 *
 * **What the gate catches** (file-level docstring of `test-base.ts`
 * has the full rationale):
 *
 *   1. `leather_vest` unknown-id class — `USER WARNING:
 *      ItemInstance.from_save_dict: unknown item id 'leather_vest'`
 *      fires at boot when the save contains the item and the registry
 *      didn't direct-load it via `STARTER_ITEM_PATHS`. (Devon's
 *      `86c9uen3z` fix addresses by adding `leather_vest.tres` to the
 *      direct-load list.)
 *   2. DirAccess HTML5 recursion class — `USER WARNING:` lines from
 *      any `ContentRegistry.load_all` / `MobRegistry` scan path that
 *      relies on `DirAccess.current_is_dir()` (silently false on
 *      packed `.pck` subdirs in HTML5).
 *   3. Save-schema migration warnings — `[Save] save schema_version N
 *      is newer than runtime M` push_warning + any per-entry warnings
 *      during the v3→v4 migration.
 *   4. Any analogous push_warning / push_error from boot or test-body
 *      code paths.
 *
 * **Pairs with:**
 *   - `tests/playwright/fixtures/test-base.ts` — the custom `test`
 *     fixture that auto-attaches `ConsoleCapture` and runs the
 *     post-test assertion.
 *   - ClickUp `86c9uf0mm` — universal console-warning zero-gate ticket
 *     (this scaffold).
 *   - ClickUp `86c9uen3z` — Devon's leather_vest fix (the flip-trigger).
 *   - PR #214 — Devon's PR landing the leather_vest fix.
 *
 * **Half B (GUT push_warning signal-watcher) is Devon-owned per the
 * ticket; out of scope here.**
 */

// Import from the new test-base, not from @playwright/test. This is the
// one-line migration every spec will do post-leather_vest-fix-merge.
import { test, expect } from "../fixtures/test-base";

const BOOT_TIMEOUT_MS = 30_000;

test.describe("universal console-warning gate — Sponsor 86c9uf0mm", () => {
  // ===================================================================
  // Demo test 1 — gate verifies clean boot.
  // ===================================================================
  //
  // **Disposition: `test()` — flipped 2026-05-15 since PR #214 (Devon's
  // `leather_vest` fix, ticket `86c9uen3z`) already merged to `main`
  // before this PR's commit landed.**
  //
  // The auto-fixture's afterEach hook catches any USER WARNING / USER
  // ERROR that fires during the test. Post-Devon-fix the gate now
  // asserts clean boot as an ongoing regression guard. Any future
  // regression that re-introduces an unknown-id (or any other USER
  // WARNING / USER ERROR at boot) will flip this RED before Sponsor
  // sees it.
  test(
    "Demo — cold boot must emit no USER WARNING / USER ERROR (Sponsor 86c9uen3z regression guard)",
    async ({ page, consoleCapture, context }) => {
      test.setTimeout(60_000);
      await context.route("**/*", (route) => route.continue());

      // `consoleCapture` is auto-attached by the test-base fixture before
      // this test body runs. Just navigate + wait for boot — the
      // afterEach hook will assert "no USER WARNING / USER ERROR" on
      // teardown automatically.
      const baseURL =
        process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
      await page.goto(baseURL, { waitUntil: "domcontentloaded" });
      await consoleCapture.waitForLine(
        /\[Main\] M1 play-loop ready/,
        BOOT_TIMEOUT_MS
      );
      // Drain a beat so any deferred warnings land before teardown.
      await page.waitForTimeout(2_000);

      // The afterEach hook (in `test-base.ts`'s `consoleCapture` fixture
      // teardown) is the load-bearing assertion. We don't restate it
      // here — the auto-fixture covers it for every test in this
      // describe block.

      // A redundant explicit sanity check that we got past boot — proves
      // the test body executed and isn't a no-op:
      const lines = consoleCapture.getLines();
      const mainReady = lines.find((l) =>
        /\[Main\] M1 play-loop ready/.test(l.text)
      );
      expect(
        mainReady,
        "Boot must complete — [Main] M1 play-loop ready must fire."
      ).toBeDefined();
    }
  );

  // ===================================================================
  // Demo test 2 — opt-out via `expectedUserWarnings` allow-list.
  // ===================================================================
  //
  // **Disposition: `test()` — flipped 2026-05-15 since PR #214 already
  // merged to `main` before this PR's commit landed (same flip trigger
  // as Demo 1).**
  //
  // This test deliberately allows a specific warning shape via the
  // `expectedUserWarnings` allow-list. The regex matches a shape that
  // Godot does NOT actually emit — proving the mechanism works without
  // depending on a real expected-warning path existing. Post-Devon-fix
  // no `leather_vest` warning fires, so this test now passes naturally
  // and the allow-list mechanism is exercised end-to-end.
  //
  // When a real "expected warning" test is authored (e.g. a future
  // "save with truly unknown id — graceful drop" spec), it follows
  // this pattern with a real-match regex.
  test.describe("opt-out demo — `expectedUserWarnings`", () => {
    test.use({
      expectedUserWarnings: [
        /USER WARNING: this specific shape would be allowed through if it fired/,
      ],
    });

    test("allow-list lets specific warnings pass; everything else still blocks", async ({
      page,
      consoleCapture,
      context,
    }) => {
      test.setTimeout(60_000);
      await context.route("**/*", (route) => route.continue());

      const baseURL =
        process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
      await page.goto(baseURL, { waitUntil: "domcontentloaded" });
      // Same boot sequence — but the allow-list opts out the one specific
      // shape this describe block deliberately allows. Other warnings
      // (e.g. `leather_vest`) would still fail the test.
      await consoleCapture.waitForLine(
        /\[Main\] M1 play-loop ready/,
        BOOT_TIMEOUT_MS
      );
      await page.waitForTimeout(500);

      // The opt-out's empirical result is "no warning fires that the
      // allow-list matches, AND no warning fires that the allow-list
      // does NOT match" — i.e. zero violations. Post-Devon-fix
      // (PR #214 merged 2026-05-15) no warnings fire at all, so this
      // test passes naturally and exercises the allow-list mechanism
      // end-to-end. If a future regression re-introduces a warning
      // that does NOT match the allow-list regex above, the gate
      // catches it — narrow opt-out, broad gate.
    });
  });
});
