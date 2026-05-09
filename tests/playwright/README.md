# Embergrave Playwright E2E Harness

**Owner:** Tess (QA) | **Status:** skeleton (M1 RC sign-off gate) | **Phase:** M1 RC

End-to-end test harness for the Embergrave HTML5 build. Runs the actual artifact in Chromium, reads real `[combat-trace]` console output, and drives real DOM input events on the game canvas.

## Why this exists

Three M1 RC integration regressions reached Sponsor's manual soak before being caught:
- PR #115/#122 — white-on-white tween; GUT asserted `tween_valid=true` but pixels didn't change in real Chrome
- PR #145 — stub-Node test silently skipped `Player.equip_item`; integration broke; Sponsor saw `damage=1`
- PR #146 — boot-order clobber seeded iron_sword then wiped it three lines later; boot prints lied

This harness catches all three classes. See `team/tess-qa/playwright-harness-design.md` for the full design rationale.

---

## Quick start

### Requirements

- **Node.js 20+** (also powers the artifact HTTP server — no Python required)
- **Embergrave HTML5 artifact** — download from the GitHub Actions release-build run

### Install

```bash
cd tests/playwright
npm install
npx playwright install chromium
```

### Run (local)

```bash
# 1. Download the artifact zip from GitHub Actions
#    e.g. https://github.com/TSandvaer/RandomGame/actions/runs/25596999719
# 2. Unzip once to get the HTML5 directory:
unzip embergrave-html5-356086a-manual.zip -d ./html5-build
# 3. Run the harness:
RELEASE_BUILD_ARTIFACT_PATH=./html5-build npm test
```

### Run in headed mode (local debugging)

```bash
RELEASE_BUILD_ARTIFACT_PATH=./html5-build HEADED=1 npm test
```

### Run with UI explorer

```bash
RELEASE_BUILD_ARTIFACT_PATH=./html5-build npm run test:ui
```

---

## Specs

### `ac1-boot-and-sha.spec.ts`

**Test name:** `AC1 — build boots cleanly and HUD shows correct SHA`

**What it checks:**
- Build loads in Chromium without `console.error` lines during boot
- `[BuildInfo] build: <7-char sha>` console line present and matches artifact name
- `[Save] autoload ready (schema vN)` confirms save system wired
- `[DebugFlags] ... web=true` confirms HTML5 runtime mode active
- `[Main] M1 play-loop ready — Room 01 loaded, autoloads wired` confirms full boot
- Zero 404 network requests (favicon.ico exempt — Chrome auto-requests, not a Godot file)

**Why the boot sentinel is `[Main] M1 play-loop ready`:** This is the last `print()` in `Main._ready()` (scenes/Main.gd:147), confirming the full autoload chain completed. The design doc referenced `[Inventory] starter iron_sword auto-equipped` but that line does not exist in the codebase.

---

### `regen-smoke.spec.ts`

**Test name:** `regen smoke — out-of-combat HP regen activates after 3.0s`

**What it checks:**
- After 3.0s of idle (no damage, no attacks), regen activates
- `[combat-trace] Player | regen activated (HP N/M)` console line appears
- HP rises over 5s window (regen tick lines visible)
- After an attack, `[combat-trace] Player | regen deactivated` appears (timer reset)
- No `console.error` during the sequence

**Regen trace lines** (from `scripts/player/Player.gd:_set_regenerating()`):
```
[combat-trace] Player | regen activated (HP N/M)
[combat-trace] Player | regen tick (HP N/M)
[combat-trace] Player | regen deactivated (HP N/M)
[combat-trace] Player | regen capped (HP N/M)
```

**Note:** `[combat-trace]` lines only appear in HTML5 builds (`OS.has_feature("web") == true`). They will NOT appear in headless GUT test output.

---

### `room-traversal-smoke.spec.ts`

**Test name:** `room traversal smoke — Room 1 clear-and-walk advances to Room 2`

**What it checks:**
- Canvas focus works for keyboard/mouse events
- Combat produces `[combat-trace] Hitbox.hit | team=player target=Grunt damage=6` (iron_sword + rebalance)
- `[combat-trace] Grunt._die | starting death sequence` confirms death pipeline
- Walk south through door trigger after clear → Room 2 evidence observed
- Room counter advances after door-walk (NOT immediately on kill — Position B gate)
- No `console.error` during traversal

**Known gap (skeleton):** Room transition detection relies on console-trace evidence and attack attempts in Room 2. The Godot CanvasLayer HUD (`STRATUM 1 · ROOM 2/8`) is not DOM-addressable by Playwright — pixel-diff or a Godot JS bridge endpoint would be needed for exact HUD assertion. Deferred to follow-up.

---

## Fixtures

### `artifact-server.ts`

Playwright `globalSetup` — reads `RELEASE_BUILD_ARTIFACT_PATH`, spawns `python -m http.server 0` (ephemeral port), writes `PLAYWRIGHT_BASE_URL` to environment. Tears down on exit.

### `console-capture.ts`

Wraps `page.on("console", ...)`. Provides:
- `capture.attach()` — start capturing (call before `page.goto()`)
- `capture.waitForLine(pattern, timeoutMs)` — wait for matching console line
- `capture.getLines()` — all captured lines
- `capture.clearLines()` — reset buffer
- `capture.findFirstError()` — first `console.error` (Godot `push_error`)
- `capture.dump()` — full text dump for CI artifacts

### `cache-mitigation.ts`

Chromium launch options and context options that bypass the Godot service-worker cache trap. See `.claude/docs/html5-export.md` § "Service-worker cache trap".

Key mitigations:
1. `serviceWorkers: "block"` — blocks SW registration entirely at context level
2. `--disable-cache` — disables HTTP disk cache
3. `--disable-application-cache` — disables legacy AppCache

---

## CI integration

The harness runs via `.github/workflows/playwright-e2e.yml`:
- **Primary trigger:** after `Release to GitHub (M1 RC build)` completes successfully on `main`
- **Manual trigger:** `workflow_dispatch` with optional `artifact_run_id`
- **Artifacts on failure:** `playwright-report-<run_id>` (HTML report) + `playwright-test-results-<run_id>`

---

## Known gaps (follow-up PRs)

| Gap | Follow-up |
|---|---|
| AC2 cold first-kill in 60s | Follow-up PR 1 |
| AC3 death preservation | Follow-up PR 1 |
| AC5 full 30-min console silence | Follow-up PR 2 |
| AC6 F5 / close-tab quit-relaunch | Follow-up PR 2 |
| AC4 boss clear | Deferred (separate ticket, diagnostic-build approach) |
| AC7 gear drops with affixes | Deferred (RNG-seed injection design needed) |
| Exact HUD room counter assertion | Needs Godot JS bridge or pixel-diff (Tier 3 deferred) |
| Canvas-focus reliability on different viewports | Verify in CI; may need `page.locator('canvas').click()` |

---

## Environment variables

| Var | Required | Description |
|---|---|---|
| `RELEASE_BUILD_ARTIFACT_PATH` | **Yes** | Path to the unzipped HTML5 directory (`index.html` must be inside) |
| `HEADED` | No | Set to `1` to run Chromium in headed mode (local debugging) |
| `PLAYWRIGHT_BASE_URL` | No | Override base URL (default: set by artifact-server from ephemeral port) |
| `CI` | No | Set by GitHub Actions; enables retries and forbids `test.only` |
