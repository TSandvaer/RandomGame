/**
 * ac1-boot-and-sha.spec.ts
 *
 * AC1 — Build boots cleanly and HUD shows correct SHA
 *
 * Verifies that the HTML5 artifact:
 *   1. Loads in Chromium without console.error lines during boot
 *   2. Emits [BuildInfo] build: <7-char sha> matching the artifact name
 *   3. Emits the expected boot smoke lines ([Save], [DebugFlags], [Main])
 *   4. Has zero 404 network requests after load
 *
 * Boot sentinel used: "[Main] M1 play-loop ready — Room 01 loaded, autoloads wired"
 * This is the last print in Main._ready() and confirms the full autoload chain
 * wired correctly (Save → ContentRegistry → Player spawn → room load → HUD).
 *
 * Note: The design doc referenced "[Inventory] starter iron_sword auto-equipped
 * (weapon slot)" as the boot sentinel, but that line does NOT exist in the
 * codebase (verified by reading scripts/inventory/Inventory.gd and scenes/Main.gd).
 * "[Main] M1 play-loop ready..." is the correct production sentinel.
 *
 * SHA assertion: cross-checks the [BuildInfo] SHA against RELEASE_BUILD_ARTIFACT_PATH.
 * The artifact directory name (from CI: embergrave-html5-<sha>) encodes the SHA.
 * If the env var is set to a path ending in the sha directory, we extract it.
 * If not parseable, the assertion checks only that the SHA is 7 hex chars
 * (not "dev-local").
 *
 * References:
 *   - scripts/debug/BuildInfo.gd — emits "[BuildInfo] build: <sha>"
 *   - scripts/debug/DebugFlags.gd — emits "[DebugFlags] debug_build=... web=true"
 *   - scripts/save/Save.gd — emits "[Save] autoload ready (schema vN)"
 *   - scenes/Main.gd — emits "[Main] M1 play-loop ready..."
 *   - .claude/docs/html5-export.md §"BuildInfo SHA verification"
 */

import { test, expect } from "../fixtures/test-base";
import * as path from "path";
import { ConsoleCapture } from "../fixtures/console-capture";

/** Timeout for boot-ready sentinel — Godot WASM + OPFS init can take 10s+ */
const BOOT_TIMEOUT_MS = 30_000;
/** Timeout for individual boot smoke lines */
const SMOKE_LINE_TIMEOUT_MS = 15_000;

// launchOptions and contextOptions are set globally in playwright.config.ts.
// Cache-mitigation args (--disable-cache, etc.) are included in the global config.
// serviceWorkers:"block" is set via contextOptions in the global config.

test.describe("AC1 — build boots cleanly and HUD shows correct SHA", () => {
  test("AC1 — build boots cleanly and HUD shows correct SHA", async ({
    page,
    context,
  }) => {
    // Block service workers at context level (cache mitigation)
    await context.route("**/*", (route) => route.continue());

    const capture = new ConsoleCapture(page);
    capture.attach();

    // Track 404s
    const notFoundUrls: string[] = [];
    page.on("response", (response) => {
      if (response.status() === 404) {
        notFoundUrls.push(response.url());
      }
    });

    // Navigate to the served artifact
    // PLAYWRIGHT_BASE_URL is set by artifact-server globalSetup (127.0.0.1:<port>)
    const baseURL =
      process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(baseURL, { waitUntil: "domcontentloaded" });

    // ---- Boot smoke line assertions ----

    // 1. Save autoload ready
    const saveReadyLine = await capture.waitForLine(
      /\[Save\] autoload ready \(schema v\d+\)/,
      SMOKE_LINE_TIMEOUT_MS
    );
    expect(saveReadyLine).toMatch(/\[Save\] autoload ready/);

    // 2. BuildInfo SHA — must be 7 hex chars, NOT "dev-local"
    const buildInfoLine = await capture.waitForLine(
      /\[BuildInfo\] build: [0-9a-f]{7}/,
      SMOKE_LINE_TIMEOUT_MS
    );
    expect(buildInfoLine).toMatch(/\[BuildInfo\] build: [0-9a-f]{7}/);
    expect(buildInfoLine).not.toContain("dev-local");

    // Extract the SHA from the console line
    const shaMatch = buildInfoLine.match(/\[BuildInfo\] build: ([0-9a-f]{7})/);
    expect(shaMatch).not.toBeNull();
    const runtimeSha = shaMatch![1];

    // Cross-check: if RELEASE_BUILD_ARTIFACT_PATH encodes the SHA in the
    // directory name (e.g. /path/to/embergrave-html5-356086a), verify they match.
    const artifactPath = process.env.RELEASE_BUILD_ARTIFACT_PATH;
    if (artifactPath) {
      const dirName = path.basename(path.resolve(artifactPath));
      // Artifact dir format: embergrave-html5-<sha> or similar
      const artifactShaMatch = dirName.match(/([0-9a-f]{7})$/);
      if (artifactShaMatch) {
        const artifactSha = artifactShaMatch[1];
        expect(runtimeSha).toBe(artifactSha);
      }
    }

    // 3. DebugFlags — web=true confirms we're in HTML5 runtime mode
    const debugFlagsLine = await capture.waitForLine(
      /\[DebugFlags\].*web=true/,
      SMOKE_LINE_TIMEOUT_MS
    );
    expect(debugFlagsLine).toMatch(/web=true/);

    // 4. Main boot ready — confirms full autoload chain wired
    await capture.waitForLine(
      /\[Main\] M1 play-loop ready/,
      BOOT_TIMEOUT_MS
    );

    // ---- Error assertions ----

    // No console.error lines during boot (Godot push_error → console.error)
    const firstError = capture.findFirstError();
    if (firstError) {
      // Dump full capture for CI artifact debugging
      console.log("[ac1-boot-and-sha] FULL CONSOLE DUMP:\n" + capture.dump());
    }
    expect(firstError).toBeNull();

    // No 404s
    if (notFoundUrls.length > 0) {
      console.log(
        "[ac1-boot-and-sha] 404 URLs:\n" + notFoundUrls.join("\n")
      );
    }
    // Filter out favicon.ico 404s (Chrome auto-requests this; Godot exports don't include it)
    const significantNotFound = notFoundUrls.filter(
      (url) => !url.includes("favicon.ico")
    );
    expect(significantNotFound).toHaveLength(0);

    capture.detach();
  });
});
