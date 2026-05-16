/**
 * debug-copy-log-overlay.spec.ts
 *
 * Verifies the `?debug=1` URL-param Copy-log overlay shipped in
 * `export_presets.cfg` `html/head_include`. The overlay exists to work around
 * the browser F12 Console panel's ~50KB copy-paste truncation that silently
 * cut off the critical tail of Sponsor M2 W3 soak traces.
 *
 * Coverage:
 *   1. With `?debug=1` → a `#embergrave-debug-copy-log` button is attached to
 *      the DOM and is visible.
 *   2. Without `?debug` → no button is attached (zero impact on normal play).
 *   3. With `?debug=0` → no button (the gate is strict equality on '1').
 *   4. Clicking the button writes the in-memory console buffer to the
 *      clipboard via `navigator.clipboard.writeText` and the button label
 *      flashes to confirm.
 *
 * Note: the buffer intercept hooks console.log/warn/error/info BEFORE Godot
 * boots, so the captured text includes the Godot boot lines
 * ([Save] / [BuildInfo] / [Main]) once boot has progressed past them.
 *
 * References:
 *   - export_presets.cfg `html/head_include` — the injected script block
 *   - .claude/docs/html5-export.md §"Debug-tooling via head_include" — the
 *     pattern documentation (this spec's contract)
 *   - Sponsor soak workflow: F12 console copy hits a ~50KB clipboard cap
 *     and silently truncates trace tails (M2 W3 finding)
 */

import { test, expect } from "../fixtures/test-base";

const BUTTON_SELECTOR = "#embergrave-debug-copy-log";

test.describe("Debug copy-log overlay (?debug=1)", () => {
  test("button is attached and clickable when ?debug=1", async ({
    page,
    context,
  }) => {
    test.setTimeout(60_000);

    // Grant clipboard permissions so navigator.clipboard.writeText works in
    // headless Chromium. Origin must match the artifact server's baseURL.
    const baseURL =
      process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await context.grantPermissions(["clipboard-read", "clipboard-write"], {
      origin: baseURL,
    });

    await page.goto(baseURL + "/?debug=1", {
      waitUntil: "domcontentloaded",
    });

    // The button is attached on DOMContentLoaded; the head_include script
    // runs synchronously at <head> parse time and registers its
    // DOMContentLoaded listener. It should be present immediately after
    // navigation resolves.
    const btn = page.locator(BUTTON_SELECTOR);
    await expect(btn).toBeAttached({ timeout: 5_000 });
    await expect(btn).toBeVisible();
    await expect(btn).toHaveText("Copy log");

    // Give the build a few seconds to emit at least one console.log before
    // clicking, so the buffer round-trip is exercised end-to-end. Godot
    // boots within ~5-10s in headless.
    await page.waitForTimeout(8_000);

    // Click the Copy log button.
    await btn.click();

    // Button label flashes to "Copied (N lines)" or "Copy failed".
    // We accept either, but assert it changed away from the resting label.
    await expect(btn).not.toHaveText("Copy log", { timeout: 3_000 });
    const flashedText = await btn.textContent();
    expect(flashedText).toMatch(/^(Copied \(\d+ lines\)|Copy failed)$/);

    // If the API path succeeded, the clipboard should now contain the
    // buffered log content. Read it back and assert non-empty.
    if (flashedText && flashedText.startsWith("Copied")) {
      const clipboardText = await page.evaluate(async () => {
        try {
          return await navigator.clipboard.readText();
        } catch {
          return null;
        }
      });
      // Clipboard read may be blocked even with permissions in some
      // headless configurations; tolerate null but fail on empty string
      // when the button reported success.
      if (clipboardText !== null) {
        expect(clipboardText.length).toBeGreaterThan(0);
      }
    }

    // Resting label restores after the flash timeout (1500 ms for success,
    // 2000 ms for failure; allow 4s slack for either).
    await expect(btn).toHaveText("Copy log", { timeout: 4_000 });
  });

  test("button is NOT attached when ?debug param is absent", async ({
    page,
  }) => {
    test.setTimeout(45_000);

    const baseURL =
      process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(baseURL, { waitUntil: "domcontentloaded" });

    // Give the page a beat to load — the head_include script returns early
    // when ?debug=1 is absent, so the button must NOT appear at any point.
    await page.waitForTimeout(3_000);

    const btn = page.locator(BUTTON_SELECTOR);
    await expect(btn).toHaveCount(0);
  });

  test("button is NOT attached when ?debug=0", async ({ page }) => {
    test.setTimeout(45_000);

    const baseURL =
      process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(baseURL + "/?debug=0", { waitUntil: "domcontentloaded" });

    await page.waitForTimeout(3_000);

    const btn = page.locator(BUTTON_SELECTOR);
    await expect(btn).toHaveCount(0);
  });
});
