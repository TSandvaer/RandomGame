/**
 * debug-chunked-copy-log.spec.ts
 *
 * Verifies the CHUNKED copy path added to the `?debug=1` Copy-log overlay in
 * `export_presets.cfg` `html/head_include` (branch tess/chunked-log-copy).
 *
 * Problem solved: the full in-memory trace buffer routinely exceeds the
 * ~50000-char chat-paste cap, so pasting a soak log truncates the diagnostic
 * tail (the bug usually happens at the end). The overlay now copies in
 * sequential LINE-BOUNDARY chunks each <= SAFE_CHUNK_CAP (40000 chars), shows
 * `Copy log (chunk X/N)`, advances+wraps on each click, and offers a `Tail`
 * button that copies the last <=cap chars directly.
 *
 * Why this is the test surface (NOT GUT): the chunking logic lives entirely in
 * the JS `head_include` IIFE — Godot 4.3 GDScript has no clipboard API in
 * HTML5 (html5-export.md §"Debug-tooling via head_include"), so there is no
 * GDScript code path for GUT to exercise. The pure chunking helpers are
 * therefore exposed on `window.__embergraveCopyLog` and unit-tested here via
 * page.evaluate (no Godot boot needed for the logic tier), plus an
 * integration tier that drives the actual overlay buttons + clipboard.
 *
 * Coverage:
 *   LOGIC TIER (pure functions on window.__embergraveCopyLog):
 *     - SAFE_CHUNK_CAP is 40000 and < 50000 chat cap
 *     - chunkLines: <=cap invariant per chunk, no line lost/reordered,
 *       no mid-line split, reassembly == full buffer, oversized-line handling
 *     - tailLines: <=cap, exact suffix, ends on last line
 *     - header format
 *   INTEGRATION TIER (real overlay):
 *     - both buttons attach under ?debug=1
 *     - main button label shows `Copy log (chunk X/N)`
 *     - clicking copies a chunk <= cap with a `=== log chunk X/N ... ===`
 *       self-labeling header onto the clipboard, and advances the label
 *     - Tail button copies a `[TAIL]`-labelled chunk <= cap
 *     - no buttons without ?debug=1
 *
 * References:
 *   - export_presets.cfg `html/head_include` — the injected script block
 *   - .claude/docs/html5-export.md §"Debug-tooling via head_include"
 *   - tests/playwright/specs/debug-copy-log-overlay.spec.ts — the pre-chunking
 *     baseline spec this extends
 */

import { test, expect } from "../fixtures/test-base";

const COPY_SELECTOR = "#embergrave-debug-copy-log";
const TAIL_SELECTOR = "#embergrave-debug-copy-tail";
const SAFE_CHUNK_CAP = 40000;
const CHAT_PASTE_CAP = 50000;

function baseURL(): string {
  return process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
}

test.describe("Debug chunked copy-log overlay (?debug=1)", () => {
  // ----------------------------------------------------------------------
  // LOGIC TIER — pure chunking helpers on window.__embergraveCopyLog.
  // Does not require Godot to finish booting; the head_include IIFE runs at
  // <head> parse time and exposes the helpers synchronously.
  // ----------------------------------------------------------------------
  test("pure chunking helpers satisfy the chat-paste-cap invariants", async ({
    page,
  }) => {
    test.setTimeout(45_000);
    await page.goto(baseURL() + "/?debug=1", { waitUntil: "domcontentloaded" });

    // The helpers are attached synchronously by the head_include IIFE.
    await page.waitForFunction(() => !!(window as any).__embergraveCopyLog, null, {
      timeout: 10_000,
    });

    const result = await page.evaluate(
      ({ cap }) => {
        const api = (window as any).__embergraveCopyLog;
        const mk = (n: number, len: number) => {
          const a: string[] = [];
          for (let i = 0; i < n; i++) a.push("x".repeat(len) + "#" + i);
          return a;
        };
        const out: Record<string, unknown> = {};
        out.capValue = api.SAFE_CHUNK_CAP;

        // ~45500 chars of content -> forces >= 2 chunks at cap 40000
        const many = mk(500, 90);
        const chunks: string[][] = api.chunkLines(many, cap);
        out.numChunks = chunks.length;
        out.everyChunkUnderCap = chunks.every(
          (c: string[]) => c.join("\n").length <= cap
        );

        // line-boundary: flatten and compare to original (no loss/reorder/split)
        const flat: string[] = [];
        for (const c of chunks) for (const ln of c) flat.push(ln);
        out.noLineLoss = flat.length === many.length;
        out.orderPreserved = flat.every((ln, i) => ln === many[i]);

        // reassembly round-trips the full buffer
        out.reassembles =
          chunks.map((c: string[]) => c.join("\n")).join("\n") ===
          many.join("\n");

        // tail: <=cap, exact suffix, ends on last line
        const tail: string[] = api.tailLines(many, cap);
        out.tailUnderCap = tail.join("\n").length <= cap;
        const suffix = many.slice(many.length - tail.length);
        out.tailIsSuffix = JSON.stringify(suffix) === JSON.stringify(tail);
        out.tailEndsLast = tail[tail.length - 1] === many[many.length - 1];

        // empty buffer
        out.emptyChunks = api.chunkLines([], cap).length;
        out.emptyTail = api.tailLines([], cap).length;

        // oversized single line cannot be split mid-line -> emitted alone
        const big = ["y".repeat(cap + 5000)];
        const bigChunks: string[][] = api.chunkLines(big, cap);
        out.oversizedNotSplit =
          bigChunks.length === 1 &&
          bigChunks[0].length === 1 &&
          bigChunks[0][0] === big[0];

        // chunk-count math: at least ceil(content / cap)
        const contentLen = many.join("\n").length;
        out.countAtLeastCeil = chunks.length >= Math.ceil(contentLen / cap);

        // header format
        out.header = api.header(2, 5, "abc1234");
        return out;
      },
      { cap: SAFE_CHUNK_CAP }
    );

    expect(result.capValue).toBe(SAFE_CHUNK_CAP);
    expect(SAFE_CHUNK_CAP).toBeLessThan(CHAT_PASTE_CAP);
    expect(result.numChunks as number).toBeGreaterThanOrEqual(2);
    expect(result.everyChunkUnderCap).toBe(true);
    expect(result.noLineLoss).toBe(true);
    expect(result.orderPreserved).toBe(true);
    expect(result.reassembles).toBe(true);
    expect(result.tailUnderCap).toBe(true);
    expect(result.tailIsSuffix).toBe(true);
    expect(result.tailEndsLast).toBe(true);
    expect(result.emptyChunks).toBe(0);
    expect(result.emptyTail).toBe(0);
    expect(result.oversizedNotSplit).toBe(true);
    expect(result.countAtLeastCeil).toBe(true);
    expect(result.header).toBe("=== log chunk 2/5 (build abc1234) ===");
  });

  // ----------------------------------------------------------------------
  // INTEGRATION TIER — the actual overlay buttons + clipboard round-trip.
  // ----------------------------------------------------------------------
  test("both overlay buttons attach and copy chunked content under the cap", async ({
    page,
    context,
  }) => {
    test.setTimeout(60_000);

    await context.grantPermissions(["clipboard-read", "clipboard-write"], {
      origin: baseURL(),
    });

    await page.goto(baseURL() + "/?debug=1", { waitUntil: "domcontentloaded" });

    const copyBtn = page.locator(COPY_SELECTOR);
    const tailBtn = page.locator(TAIL_SELECTOR);
    await expect(copyBtn).toBeAttached({ timeout: 5_000 });
    await expect(tailBtn).toBeAttached();
    await expect(copyBtn).toBeVisible();
    await expect(tailBtn).toBeVisible();

    // Resting label is the chunked form: "Copy log (chunk X/N)".
    await expect(copyBtn).toHaveText(/^Copy log \(chunk \d+\/\d+\)$/);
    await expect(tailBtn).toHaveText("Tail");

    // Let Godot emit some console lines so the buffer is non-trivial.
    await page.waitForTimeout(8_000);

    // --- main chunked copy ---
    await copyBtn.click();
    await expect(copyBtn).toHaveText(/^Copied chunk \d+\/\d+ \(\d+ ch\)$/, {
      timeout: 3_000,
    });

    const chunkText = await page.evaluate(async () => {
      try {
        return await navigator.clipboard.readText();
      } catch {
        return null;
      }
    });
    if (chunkText !== null) {
      expect(chunkText.length).toBeLessThanOrEqual(SAFE_CHUNK_CAP + 80); // +header
      expect(chunkText).toMatch(/^=== log chunk \d+\/\d+ \(build .+\) ===/);
    }

    // label restores to the chunked resting form
    await expect(copyBtn).toHaveText(/^Copy log \(chunk \d+\/\d+\)$/, {
      timeout: 4_000,
    });

    // --- tail copy ---
    await tailBtn.click();
    await expect(tailBtn).toHaveText(/^Tail copied \(\d+ ch\)$/, {
      timeout: 3_000,
    });

    const tailText = await page.evaluate(async () => {
      try {
        return await navigator.clipboard.readText();
      } catch {
        return null;
      }
    });
    if (tailText !== null) {
      expect(tailText.length).toBeLessThanOrEqual(SAFE_CHUNK_CAP + 80);
      expect(tailText).toMatch(/^=== log chunk \d+\/\d+ \(build .+\) === \[TAIL\]/);
    }

    await expect(tailBtn).toHaveText("Tail", { timeout: 4_000 });
  });

  test("clicking the chunk button advances + wraps the X/N label", async ({
    page,
    context,
  }) => {
    test.setTimeout(60_000);
    await context.grantPermissions(["clipboard-read", "clipboard-write"], {
      origin: baseURL(),
    });
    await page.goto(baseURL() + "/?debug=1", { waitUntil: "domcontentloaded" });

    // Inject a large synthetic buffer so N >= 2 deterministically, independent
    // of how much Godot has logged. We push lines through the hooked console so
    // they land in the same buffer the overlay reads.
    await page.waitForFunction(() => !!(window as any).__embergraveCopyLog, null, {
      timeout: 10_000,
    });
    await page.evaluate((cap) => {
      // ~2.2 chunks worth of content
      const target = cap * 2 + 5000;
      let written = 0;
      let i = 0;
      while (written < target) {
        const line = "synthetic-trace-line-" + i + "-" + "z".repeat(80);
        console.log(line);
        written += line.length + 1;
        i++;
      }
    }, SAFE_CHUNK_CAP);

    const copyBtn = page.locator(COPY_SELECTOR);
    // After the injection, refreshLabel only re-runs on the next label refresh;
    // force a refresh by reading the computed N via the API and the label.
    const total = await page.evaluate((cap) => {
      const api = (window as any).__embergraveCopyLog;
      return api.chunkLines(api.buffer(), cap).length;
    }, SAFE_CHUNK_CAP);
    expect(total).toBeGreaterThanOrEqual(2);

    // Click N times and confirm the "Copied chunk i/N" advances 1..N then wraps.
    for (let i = 1; i <= total; i++) {
      await copyBtn.click();
      await expect(copyBtn).toHaveText(
        new RegExp("^Copied chunk " + i + "/" + total + " \\(\\d+ ch\\)$"),
        { timeout: 3_000 }
      );
      await expect(copyBtn).toHaveText(/^Copy log \(chunk \d+\/\d+\)$/, {
        timeout: 4_000,
      });
    }
    // One more click wraps back to chunk 1.
    await copyBtn.click();
    await expect(copyBtn).toHaveText(
      new RegExp("^Copied chunk 1/" + total + " \\(\\d+ ch\\)$"),
      { timeout: 3_000 }
    );
  });

  test("no overlay buttons without ?debug=1", async ({ page }) => {
    test.setTimeout(45_000);
    await page.goto(baseURL(), { waitUntil: "domcontentloaded" });
    await page.waitForTimeout(3_000);
    await expect(page.locator(COPY_SELECTOR)).toHaveCount(0);
    await expect(page.locator(TAIL_SELECTOR)).toHaveCount(0);
  });
});
