/**
 * cache-mitigation.ts — Chromium launch options for service-worker cache isolation
 *
 * The Godot HTML5 export registers a service worker that aggressively caches
 * index.js / index.wasm / asset bundle. Without mitigation, switching between
 * artifacts on the same localhost URL serves stale assets from a prior test run
 * even after a normal F5 refresh — including across browser sessions.
 *
 * This fixture provides Playwright browser context options that bypass the
 * cache trap entirely. Apply these options when creating browser contexts in
 * spec files.
 *
 * See memory rule: html5-service-worker-cache-trap
 * See doc: .claude/docs/html5-export.md § "Service-worker cache trap"
 *
 * Why each option matters:
 *
 * 1. userDataDir (isolated profile):
 *    Each test run uses a fresh temporary Chrome profile directory. An isolated
 *    profile has no service worker registrations from any prior run — equivalent
 *    to Sponsor's "open in incognito" ritual. This is the primary mitigation.
 *
 * 2. --disable-cache launch arg:
 *    Disables the Chromium HTTP disk cache (separate from service workers).
 *    Ensures that even if a service worker manages to activate, it cannot pull
 *    from a stale disk-cache entry. Belt-and-suspenders with the isolated profile.
 *
 * 3. --disable-application-cache launch arg:
 *    Disables the legacy AppCache API (HTML5 manifest-based cache). Godot may
 *    register AppCache entries on some export configurations — disabling prevents
 *    any AppCache from interfering with fresh-artifact serving.
 *
 * 4. serviceWorkers: "block" context option:
 *    Playwright 1.32+ supports blocking service worker registration at the
 *    browser context level. This is the cleanest mitigation — the service worker
 *    never registers, so it cannot cache or intercept any requests. Takes
 *    precedence over --disable-service-workers-networking where available.
 *
 * 5. Fresh extract per run (CI workflow + local convention):
 *    The artifact-server fixture always extracts to a fresh temp directory,
 *    not overlaying on a prior extract. This mirrors the manual ritual
 *    ("extract the new zip to a fresh empty folder").
 *
 * References:
 *   - team/uma-ux/sponsor-soak-checklist-v2.md §1.2 "Local serve"
 *   - .claude/docs/html5-export.md §"Service-worker cache trap"
 *   - memory: html5-service-worker-cache-trap.md
 */

import * as os from "os";
import * as path from "path";
import * as fs from "fs";

/**
 * Returns a fresh temporary directory path for an isolated Chrome user data dir.
 * Call once per test suite run (not per test — we want isolation between runs,
 * not between individual tests in the same run which share the server).
 */
export function freshUserDataDir(): string {
  const dir = path.join(
    os.tmpdir(),
    `embergrave-chrome-profile-${Date.now()}-${process.pid}`
  );
  fs.mkdirSync(dir, { recursive: true });
  return dir;
}

/**
 * Playwright browser launch options that mitigate the Godot service-worker
 * cache trap. Merge these into your playwright.config.ts launchOptions or
 * use them per-test in browser.newContext({ ... }).
 */
export const CACHE_MITIGATION_LAUNCH_ARGS: string[] = [
  // Disable HTTP disk cache (primary mitigation against stale network responses)
  "--disable-cache",
  // Disable legacy AppCache (belt-and-suspenders)
  "--disable-application-cache",
  // Disable offline load from stale cache (prevents cache-first loading)
  "--disable-offline-load-stale-cache",
];

/**
 * Playwright browser context options for service-worker isolation.
 * Pass to browser.newContext(CACHE_MITIGATION_CONTEXT_OPTIONS) or merge
 * into playwright.config.ts use.contextOptions.
 */
export const CACHE_MITIGATION_CONTEXT_OPTIONS = {
  // Block service worker registration at the context level — cleanest mitigation.
  // The service worker never registers, so it cannot cache or intercept requests.
  serviceWorkers: "block" as const,

  // Ignore HTTPS errors from localhost self-signed certs (rare but defensive)
  ignoreHTTPSErrors: true,
};

/**
 * Cleanup helper — removes a temporary Chrome profile directory.
 * Call in afterAll / globalTeardown if using freshUserDataDir().
 */
export function removeTempDir(dir: string): void {
  try {
    fs.rmSync(dir, { recursive: true, force: true });
  } catch {
    // Best-effort cleanup — non-fatal if the dir is locked (Windows)
  }
}
