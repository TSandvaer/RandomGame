import { defineConfig, devices } from "@playwright/test";
import path from "path";

/**
 * Embergrave Playwright E2E Configuration
 *
 * Chromium-only for v1 (per playwright-harness-design.md §9 Q2 — multi-browser deferred).
 * Headed mode controlled by HEADED env var for local debugging.
 *
 * Artifact path: set RELEASE_BUILD_ARTIFACT_PATH to the unzipped HTML5 directory
 * (post-PR-#152 single-unzip format). The artifact-server fixture reads this env var
 * and spawns a local HTTP server on an ephemeral port.
 *
 * CI: triggered by playwright-e2e.yml after release-github.yml completes.
 * Local: RELEASE_BUILD_ARTIFACT_PATH=/path/to/unzipped/html5 npm test
 */

export default defineConfig({
  testDir: "./specs",
  /* Run tests in files in parallel */
  fullyParallel: false, // Godot HTML5 is single-instance — run serially to avoid port conflicts
  /* Fail the build on CI if you accidentally left test.only in the source code. */
  forbidOnly: !!process.env.CI,
  /* Retry on CI only */
  retries: process.env.CI ? 1 : 0,
  /* Single worker — each test boots a fresh Godot instance; parallelism causes port conflicts */
  workers: 1,
  /* Reporter to use */
  reporter: [
    ["html", { outputFolder: "playwright-report", open: "never" }],
    ["list"],
  ],

  /* Shared settings for all the projects below */
  use: {
    /* Base URL set by artifact-server fixture at runtime.
     * Using 127.0.0.1 explicitly to avoid IPv6 resolution on Windows
     * (localhost may resolve to ::1 while server binds to 127.0.0.1). */
    baseURL: process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000",

    /* Collect trace when retrying the failed test */
    trace: "on-first-retry",

    /* Screenshot on failure */
    screenshot: "only-on-failure",

    /* Video on failure */
    video: "on-first-retry",

    /* Global action timeout — Godot canvas input events may be slow to register */
    actionTimeout: 10_000,

    /* Navigation timeout — Godot WASM load can take 5-10s on cold boot */
    navigationTimeout: 30_000,
  },

  /* Output directory for test artifacts (screenshots, traces, videos) */
  outputDir: "test-results",

  /* Global timeout per test — combat sequences can run 30+ seconds */
  timeout: 120_000,

  /* Configure projects for Chromium only */
  projects: [
    {
      name: "chromium",
      use: {
        ...devices["Desktop Chrome"],
        /* Clean browser context per test — service-worker isolation.
         * See: html5-service-worker-cache-trap memory rule. */
        storageState: undefined,
        launchOptions: {
          args: [
            "--disable-cache",
            "--disable-application-cache",
            "--disable-offline-load-stale-cache",
            /* Service workers are blocked at the context level via serviceWorkers:"block"
             * (see contextOptions below). These args are belt-and-suspenders for cache. */
          ],
          /* Headed mode for local debugging: HEADED=1 npm test */
          headless: !process.env.HEADED,
        },
        /* Isolated browser context per test run (no shared cookies/service workers).
         * serviceWorkers:"block" is the primary service-worker cache mitigation —
         * prevents the Godot service worker from caching assets between runs.
         * See: .claude/docs/html5-export.md §"Service-worker cache trap" */
        contextOptions: {
          ignoreHTTPSErrors: true,
          serviceWorkers: "block" as const,
        },
      },
    },
  ],

  /* Global setup — starts the artifact HTTP server before any tests run.
   * Teardown is registered inside the setup function via the process event
   * and also by playwright-e2e.yml's CI step cleanup.
   * Note: globalTeardown omitted because artifact-server.ts default-exports
   * the setup function; a separate teardown would need its own default export.
   * The HTTP server is killed via SIGTERM on process exit automatically. */
  globalSetup: path.resolve(__dirname, "fixtures/artifact-server.ts"),
});
