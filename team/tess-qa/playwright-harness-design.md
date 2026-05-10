# Playwright Harness Design — Embergrave HTML5 End-to-End Tests

**Owner:** Tess (QA) · **Status:** design only (no code) · **Phase:** M2 Week 1 (skeleton) + follow-up PRs  
**ClickUp ticket:** `86c9q7wc7` · **Drafted:** 2026-05-09  
**Self-Test:** read existing `team/tess-qa/*.md` docs for tone consistency; cross-checked against `team/uma-ux/sponsor-soak-checklist-v2.md` AC list; confirmed harness scope aligns with `team/TESTING_BAR.md` § product-vs-component framing.

---

## Why this exists

Sponsor said (2026-05-09): *"why is the tester not running this and doing these tests? im doing it now but cant a tester not really spin it up and use playwright? i want this, so i dont have to test so much."*

Three M1 RC integration regressions reached Sponsor's manual soak instead of being caught earlier:

- **PR #115 / #122** — white-on-white tween cascade; HTML5-renderer-specific no-op. Headless GUT asserted `tween_valid=true`; nobody confirmed pixels changed in real Chrome.
- **PR #145** — stub-Node tests silently skipped `Player.equip_item`; inventory state passed; integration broke. Sponsor found `damage=1` in console after the first swing.
- **PR #146** — `Save` autoload boot-order clobbered seeded sword three lines after seed. Boot prints said "auto-equipped"; the actual game state was fistless.

All three would have been caught by a harness that runs the actual HTML5 artifact in real Chrome, reads real `[combat-trace]` console output, and drives real input events. This design doc specifies that harness.

---

## 1. Goal + non-goal

**Goal.** Provide a real-browser end-to-end test harness that automatically exercises the M1 RC acceptance criteria against a live HTML5 artifact in Chromium, using real keyboard/mouse events, reading real DevTools console output (including `[combat-trace]` lines), and uploading screenshots + full console dumps on failure. The harness is the **complement** to GUT, not its replacement. GUT covers Godot-engine internals — unit-level logic, state-machine transitions, save/load math — in headless mode where it excels. The Playwright harness covers what GUT structurally cannot: the HTML5 renderer running under `gl_compatibility`, the service-worker cache state, the actual game canvas as Chromium paints it, the `[combat-trace]` signal stream that Sponsor has been reading by hand. Where GUT proves that the component works in isolation, this harness proves that the product works in the artifact Sponsor downloads. The two layers are load-bearing in different failure-mode families and neither replaces the other.

**Non-goal.** This harness does not replace GUT unit/integration tests, does not add a framebuffer pixel-diff lane (that is Devon's deferred renderer-painting CI lane from the postmortem), does not test the Windows or macOS export, and does not cover audio (no browser-driven audio verification in v1). It also does not cover AC4 (boss clear) or AC7 (gear drops with distinct affixes) in the skeleton PR — those require multi-minute test budgets and RNG-seed fixtures respectively, and are explicitly deferred to follow-up tickets.

---

## 2. Architecture choice — TypeScript Playwright (Option A)

**Decision: TypeScript Playwright.**

**Rationale.** Playwright's TypeScript variant is the right call for this harness for four compounding reasons:

1. **Browser control is the primary job.** Playwright gives first-class Chromium control: launch flags, service-worker bypass, `--disable-cache`, isolated browser contexts per test, `page.on("console", ...)` for real-time console capture, and `page.keyboard` / `page.mouse` for real input events on the canvas element. This is the exact failure surface that let PR #115's white-on-white bug ship — none of those failure modes exist in headless GUT.

2. **GitHub Actions integration is turnkey.** The `microsoft/playwright-github-action` setup step installs browser binaries; the `playwright test` command outputs JUnit XML + HTML report out of the box. No custom CI scaffolding needed; the standard Playwright CI recipe is a three-liner.

3. **TypeScript semantics fit the async test shape.** Console-line watching is inherently async (wait for a specific `[combat-trace]` pattern to appear within a timeout). Playwright's `Promise`-based API with `waitForFunction`, `waitForConsoleMessage`, and `page.evaluate` maps directly onto this model. The alternative (Python + CDP / pyppeteer) would require the same async reasoning but with a thinner ecosystem, less-maintained typings, and less sample code for canvas-based games.

4. **Ecosystem depth.** Playwright's `@playwright/test` runner ships retries, parallel workers, built-in screenshot-on-failure, video recording, and trace files. All are useful here and all require no additional libraries.

**Option B (Python + CDP) rejected.** The argument for Python is that the same runtime that runs Godot headless (`godot --headless`) could theoretically orchestrate the browser too. In practice this doesn't hold: the Playwright Python bindings (`playwright-python`) are a thin wrapper around the same Node.js service process — you get the Python API but you still depend on Node. The ecosystem (sample code, Stack Overflow surface, Playwright release notes) is TypeScript-first. Rejected.

**Option C (other)** not considered — no compelling reason to leave the Playwright ecosystem.

---

## 3. Repo layout

The harness lives **inside this repo** at `tests/playwright/`. Keeping it in the same repo couples version control, PR gating, and CI configuration — no separate sync problem when the game's `[combat-trace]` API changes.

```
tests/playwright/
  package.json             # dependencies: @playwright/test, ts-node, @types/node
  tsconfig.json            # target: ES2020, moduleResolution: node
  playwright.config.ts     # single project (Chromium), baseURL, globalSetup, reporter config

  fixtures/
    artifact-server.ts     # globalSetup: unzip artifact, spawn python -m http.server, discover port
    chrome-launch.ts       # shared browserContextOptions: isolated profile, no-cache headers

  helpers/
    trace-matcher.ts       # waitForConsoleLine(page, pattern, timeoutMs): Promise<RegExpMatchArray>
                           # assertConsoleSequence(page, patterns[], timeoutMs): Promise<void>
                           # captureConsoleLog(page): ConsoleCapture (start/stop/dump)

  specs/
    ac1-build-reachable.spec.ts    # skeleton PR: build boots + footer SHA + no 404s + boot smoke lines
    ac1-cache-mitigation.spec.ts   # skeleton PR: service-worker bypass + stale-artifact negative test
    hp-regen-smoke.spec.ts         # skeleton PR: warm-amber shimmer + HP refill rate + reset on damage
    ac2-first-kill.spec.ts         # follow-up PR 1
    ac3-death-preservation.spec.ts # follow-up PR 1
    ac5-console-silence.spec.ts    # follow-up PR 2
    ac6-quit-relaunch.spec.ts      # follow-up PR 2
```

The `specs/` directory is organized by AC group so that each follow-up PR adds a file without touching existing specs. The `fixtures/` and `helpers/` directories are shared across all specs and evolve incrementally.

---

## 4. Artifact + serve mechanism

### Passing the artifact into the harness

CI passes the artifact path via environment variable:

```
RELEASE_BUILD_ARTIFACT_PATH=/path/to/embergrave-html5-<sha>.zip
```

The variable is set by the upstream workflow step that downloads the artifact before invoking `npx playwright test`. In local development, the tester exports the same variable pointing to a locally-downloaded zip.

**Why an env var instead of a config file.** The artifact path changes on every build (it includes the commit SHA). An env var is the cleanest interface between the release-build workflow and the harness — no config file to commit and no hardcoded path.

### Unzip + serve (globalSetup)

`fixtures/artifact-server.ts` runs as Playwright's `globalSetup` hook:

1. Reads `RELEASE_BUILD_ARTIFACT_PATH`. If absent, throws with a clear message ("set RELEASE_BUILD_ARTIFACT_PATH to the artifact zip path").
2. Extracts the zip to a temp directory (`os.tmpdir()/embergrave-html5-<timestamp>/`). Fresh directory every run — no overlay-on-prior-extract trap.
3. Spawns `python -m http.server 0` (port `0` = OS assigns an ephemeral port; reads the actual port from the process output). Stores the base URL in `process.env.PLAYWRIGHT_BASE_URL` so `playwright.config.ts` picks it up.
4. Returns a teardown function that kills the `python` process and removes the temp directory.

**Why `python -m http.server`.** It is already the team's established artifact-serve pattern (per `.claude/docs/html5-export.md` and `team/uma-ux/sponsor-soak-checklist-v2.md`). No new dependency introduced.

### Cache mitigation

The service-worker cache trap is the primary reason the M1 RC soak pattern required incognito windows and fresh extract folders. The harness mitigates this in two ways:

1. **Isolated Chrome profile per test run.** `chrome-launch.ts` sets `userDataDir` to a fresh temp directory for each test suite run. An isolated profile means no service worker from a prior run survives into this one. This is the harness-level equivalent of Sponsor's "open in incognito" ritual.

2. **`--disable-cache` launch flag.** Playwright `launchOptions.args` includes `--disable-cache`. This disables the HTTP disk cache in addition to the per-origin cache; combined with the isolated profile it is belt-and-suspenders against the service-worker pattern described in the memory rule `html5-service-worker-cache-trap.md`.

3. **Negative test in `ac1-cache-mitigation.spec.ts`.** The skeleton PR ships a test that confirms the harness's cache-bypass is working: it launches twice against the same served URL and asserts the second boot log reports the same SHA as the first, not a stale prior SHA. This is a self-test for the harness infrastructure rather than a game correctness test, but it is load-bearing for trust in the harness.

---

## 5. AC coverage matrix

The source of truth for each AC is `team/uma-ux/sponsor-soak-checklist-v2.md` § 5. The harness maps each to a spec file with concrete boot preconditions, input sequences, trace assertions, and failure modes.

The `trace-matcher.ts` helper is the shared primitive: it attaches a `page.on("console", ...)` listener from the moment Playwright navigates to the served URL, buffers every console message, and exposes `waitForConsoleLine(pattern, timeoutMs)` (returns the first matching line within the budget) and `assertConsoleSequence(patterns[])` (asserts the lines appear in order, not necessarily contiguous). All trace assertions in this matrix use these two functions.

---

### AC1 — Build reachable + footer SHA + boot OK + no 404s

**Spec file:** `specs/ac1-build-reachable.spec.ts` (skeleton PR)

**Boot precondition.** Navigation completes, canvas element is present (`canvas#canvas` or the Godot-exported canvas selector), the page does not redirect to an error.

**Input sequence.** None — AC1 is a passive boot-observation test. The harness navigates to the served URL and waits.

**Trace assertions.**

| Assertion | Console line pattern | Timeout |
|---|---|---|
| Schema version ready | `/\[Save\] autoload ready \(schema v[0-9]+\)/` | 10 000 ms |
| BuildInfo SHA present and not dev-local | `/\[BuildInfo\] build: [0-9a-f]{7}/` | 10 000 ms |
| DebugFlags web=true | `/\[DebugFlags\].*web=true/` | 10 000 ms |
| No push_error in boot window | Negative: no `console.error` match in first 15 s | 15 000 ms |
| No network 404s | Playwright network intercept: zero 404 responses during page load | n/a |

The SHA captured from the `[BuildInfo]` line is cross-checked against the artifact filename (extracted from `RELEASE_BUILD_ARTIFACT_PATH`). If they don't match, the test fails with a message distinguishing "game is on stale cache" from "artifact mismatch."

**Failure mode.** On any assertion failure: `page.screenshot({ path: "artifacts/ac1-boot-failure.png" })` + `consoleCapture.dump("artifacts/ac1-console.txt")`. Both uploaded as GitHub Actions artifacts.

---

### AC2 — Cold launch → first mob killed in ≤60 s with weapon-scaled damage

**Spec file:** `specs/ac2-first-kill.spec.ts` (follow-up PR 1)

**Boot precondition.** AC1 passes (all boot smoke lines present). Additionally: `waitForConsoleLine(/\[Inventory\] starter iron_sword auto-equipped \(weapon slot\)/)` within 15 s — this is the integration proof that PR #146's boot-order fix is live. If this line is absent, the test fails early with "weapon seeding did not complete — check Main._ready boot order" before any combat input is sent.

The iron_sword auto-equip line is load-bearing here because it is exactly the surface that PR #145 / #146 regressions broke. The `damage=1` symptom is detectable in the trace; this precondition surfaces the root cause rather than the symptom.

**Input sequence.** After boot, the canvas has focus. The harness uses `page.mouse.click(canvasCenterX, canvasCenterY)` to ensure canvas focus, then begins simulated combat:

1. Move toward the first grunt: `page.keyboard.down("S")` for 500 ms (walk toward grunt — Room01 spawn geometry places grunt slightly south of player start).
2. Begin LMB attack loop: `page.mouse.click(canvasCenterX, canvasCenterY)` every 600 ms (slightly faster than the light-attack cooldown to sustain hits).
3. Continue until `waitForConsoleLine(/Grunt\._die\b/)` or 60 000 ms timeout.

**Trace assertions.**

| Assertion | Console line pattern | Notes |
|---|---|---|
| Weapon-scaled damage per swing | `/Player\.try_attack.*damage=[2-9][0-9]*/` | Asserts damage > 1 (weapon-scaled, not fist). Any value ≥ 2 passes; exact value is balance-dependent. |
| At least one hit landed | `/Hitbox\.hit.*team=player/` | Confirms hitbox collision is working. |
| Grunt kill registered | `/Grunt\._die\b/` | Must appear within the 60 s budget. |
| Death tween reached | `/Grunt\._on_death_tween_finished/` | Confirms the PR #136 safety-net or tween-complete path ran. |
| No physics panic | Negative: no `/USER ERROR: Can't change this state while flushing queries/` | Regression guard for PR #142 / #143. |

**Failure mode.** Screenshot + console dump + `page.evaluate(() => console.log("[harness] DUMP_REQUESTED"))` to flush any buffered Godot prints. Named `ac2-first-kill-failure.*` in artifacts.

---

### AC3 — Death preserves level + V/F/E + equipped

**Spec file:** `specs/ac3-death-preservation.spec.ts` (follow-up PR 1)

**Boot precondition.** AC1 boot smoke + `[Inventory] starter iron_sword auto-equipped` line. Additionally, the harness captures the player's starting level from the boot window: `waitForConsoleLine(/\[Player\] level=[0-9]+/)` (exact pattern TBD based on actual boot print — if this print doesn't exist, a tab-to-inventory read may be substituted; implementation agent confirms at time of coding).

**Input sequence.** To trigger death deterministically without relying on getting killed by grunts (which is timing-dependent), the harness uses the following approach:

1. Confirm boot complete.
2. Do NOT attack. Walk into grunt range and stand still: `page.keyboard.down("S")` for 2 000 ms, then release. Player takes grunt damage.
3. Wait for `waitForConsoleLine(/Player.*hp=[0-9]+->0/)` or equivalent death signal within 120 000 ms. If combat is too slow to kill player this way, the diagnostic-build pattern (lower player HP via a diag branch) is the lever — implementation agent makes this call.
4. After death line: wait 3 000 ms (death screen transition), then simulate restart: `page.keyboard.press("Enter")` or equivalent (confirm restart key in `project.godot` input map at implementation time).
5. Wait for re-spawn boot lines.

**Trace assertions (post-death, post-restart).**

| Assertion | What to check | Notes |
|---|---|---|
| Level preserved | Boot print after restart shows same level as pre-death | `[Player] level=N` must match N from before death |
| Equipped preserved | `[Inventory] starter iron_sword auto-equipped` fires again OR post-restart damage is weapon-scaled | Either trace proves equip survives |
| Run-XP reset | If XP is printed on respawn, it reads 0 (or starting value) | AC3 death rule: mid-XP resets |
| No save-restore panic | Negative: no `push_error` in the restart boot window | Guards against PR #146 regression class |

**Failure mode.** Screenshot at pre-death, post-death, post-restart. Console dump. Named `ac3-death-preservation-failure.*`.

---

### AC5 — No `push_error` / `push_warning` for N-second window

**Spec file:** `specs/ac5-console-silence.spec.ts` (follow-up PR 2)

**Boot precondition.** AC1 boot smoke complete.

**Input sequence.** After boot, the harness drives a minimal gameplay sequence (boot → move → attack a few times → stand idle) for 120 s. No specific combat goal; the purpose is ambient error-signal coverage over a sustained window.

**Trace assertions.** The `captureConsoleLog` helper records every `console.error` (Godot `push_error` maps to browser `console.error`) and `console.warn` (Godot `push_warning` maps to `console.warn`) over the entire 120 s window. At end of test, assert:

- Zero `console.error` entries.
- Zero `console.warn` entries matching the two known-noisy patterns: `/\[Save\] save_game\(0\) failed at atomic_write/` and `/ItemInstance\.from_save_dict: unknown item id/`.

The Chrome perf violation `requestAnimationFrame handler took Nms` is not a Godot error — filtered out of the assertion scope (it is a Chromium-internal timing note, not a Godot push_error/warning).

**Failure mode.** Full console dump from the capture buffer. Screenshot at the point the first unexpected error appeared (if timestamp is available). Named `ac5-console-silence-failure.*`.

---

### AC6 — F5 quit-relaunch + close-tab quit-relaunch state preservation

**Spec file:** `specs/ac6-quit-relaunch.spec.ts` (follow-up PR 2)

**Boot precondition.** AC1 boot smoke. Additionally, a usable save state must be established before the reload test. The harness drives a brief play session (boot, move, make at least one attack, wait for XP — or if quicker: just boot and let the save auto-tick on the exit-portal save pattern).

**Input sequences.** Two sub-tests:

1. **F5 relaunch:** `page.keyboard.press("F5")` (or `page.reload()`). Wait for boot smoke lines to reappear. Assert player state is preserved (level matches, equipped matches, mid-XP reset per AC3 rule).

2. **Close-tab relaunch:** `await page.close()` → open a new page at the same URL in the same browser context. Assert boot smoke lines + state preservation.

**Trace assertions.** Same level / equipped checks as AC3. Additionally: zero `push_warning` for `[Save] save_game(0) failed at atomic_write` — OPFS write failure is the browser-side storage regression class.

**Failure mode.** Screenshot + console dump at both pre-reload and post-reload steps. Named `ac6-quit-relaunch-failure.*`.

---

### HP Regen (PR #148 smoke probe)

**Spec file:** `specs/hp-regen-smoke.spec.ts` (skeleton PR)

This probe is in the skeleton because it was explicitly mentioned as a new feature (PR #148) and is a good candidate for harness-infrastructure validation — it requires timing, console-line reading, and passive observation without complex combat input.

**Boot precondition.** AC1 boot smoke complete + `[Inventory] starter iron_sword auto-equipped`.

**Input sequence.**

1. Boot complete. Stand still (no input) for 5 000 ms to ensure regen timer starts from idle state.
2. Assert warm-amber shimmer activation (see trace assertion below).
3. At t=5 000 ms, read HP from console if printed (`/Player.*hp=[0-9]+/`) or infer from the regen trace.
4. Stand still for another 10 000 ms.
5. Assert HP increased since the t=5 000 ms sample.
6. Issue one LMB attack: `page.mouse.click(canvasCenterX, canvasCenterY)`.
7. Assert that the next regen-activation trace resets — the regen timer restarts after damage dealt.

**Trace assertions.**

| Assertion | Console line pattern | Timeout |
|---|---|---|
| Regen shimmer activates after inactivity | `/\[regen\].*shimmer=true/` or equivalent PR #148 trace | 5 000 ms after last input |
| HP refill rate approximately 2 HP/s | Two consecutive HP readings 5 s apart differ by approximately 10 HP (2/s × 5 s) — allow ±3 HP tolerance | 15 000 ms window |
| Damage input resets timer | After attack: shimmer deactivates (trace line shows `shimmer=false`) within 500 ms | 2 000 ms post-attack |

**Note for implementation agent.** The exact trace line format for PR #148 is specified by Devon/Drew at the time of implementation. If the PR does not emit a `[regen]` console trace, coordinate with Devon to add one — the harness depends on console-readable state, not pixel-sampled HP bar. The HP-bar is not addressable by Playwright without pixel-diff (deferred) or a Godot-side debug endpoint.

**Failure mode.** Screenshot at each HP-sample point. Full console dump. Named `hp-regen-smoke-failure.*`.

---

### Deferred ACs (noted in spec, not implemented in skeleton or follow-up PRs 1–2)

**AC4 — Stratum-1 boss clear in ≤10 min.** Requires a multi-minute test budget (the boss fight alone, plus navigation through 8 rooms, exceeds practical per-PR CI time). Recommend a separate ClickUp ticket for a `tests/playwright/specs/ac4-boss-clear.spec.ts` using the diagnostic-build pattern (low boss HP) to make the scenario tractable. Assign to Devon (combat trace shape) + Tess (harness authoring).

**AC7 — Two distinct gear drops with visibly different affixes.** Requires either RNG-seed fixing (Godot's random seed injectable via URL param or boot flag — implementation TBD) or a retry-with-assertion pattern that is inherently flaky. Recommend a separate ticket after the RNG-seed injection mechanism is designed. Flag for Priya to scope.

**30-minute full soak (AC5 stress).** The full 30-min duration is impractical for per-PR CI (wall-clock cost). The 120-second partial window in `ac5-console-silence.spec.ts` is the CI-practical coverage. For M2 RC milestone gates, a `workflow_dispatch` with a `LONG_SOAK=true` flag can extend the window — design the environment variable hook in the skeleton so the follow-up can add it without changing the test file shape.

---

## 6. Skeleton vs. follow-up landing plan

### Skeleton PR scope (proves the harness works end-to-end)

The skeleton PR delivers the harness infrastructure and the two simplest specs. Nothing in the skeleton requires complex input sequences or multi-step combat.

**Delivers:**

- `tests/playwright/package.json` + `playwright.config.ts` + `tsconfig.json` — harness bootstrap.
- `tests/playwright/fixtures/artifact-server.ts` — unzip + serve + teardown.
- `tests/playwright/fixtures/chrome-launch.ts` — isolated profile + `--disable-cache`.
- `tests/playwright/helpers/trace-matcher.ts` — `waitForConsoleLine`, `assertConsoleSequence`, `captureConsoleLog`.
- `specs/ac1-build-reachable.spec.ts` — proves the harness boots the game and reads console output.
- `specs/ac1-cache-mitigation.spec.ts` — proves the service-worker bypass works; negative test for stale-artifact scenario.
- `specs/hp-regen-smoke.spec.ts` — first real-feature probe; validates timing + console-line assertions work against game state.
- CI wiring (`.github/workflows/playwright.yml` or an addition to the existing release workflow) — runs after release-build green on `main` + on `workflow_dispatch`.

**Does NOT deliver:** AC2, AC3, AC5, AC6, AC4, AC7.

**Merge identity.** `feat(ci): Playwright harness skeleton — AC1 boot probe + HP-regen smoke` — Tess authors, Devon pairs on `[combat-trace]` / PR #148 trace shape, orchestrator merges.

### Follow-up PR 1 — combat coverage

- `specs/ac2-first-kill.spec.ts` (weapon-scaled damage + first kill in ≤60 s)
- `specs/ac3-death-preservation.spec.ts` (death preserves level + equipped)
- Extends `helpers/trace-matcher.ts` with any combat-trace helpers discovered during AC2 implementation.

**Merge identity.** `feat(ci): Playwright harness — AC2 combat first-kill + AC3 death-preservation`

### Follow-up PR 2 — console silence + quit-relaunch

- `specs/ac5-console-silence.spec.ts` (120 s console-error / push_warning watch)
- `specs/ac6-quit-relaunch.spec.ts` (F5 + close-tab state preservation)

**Merge identity.** `feat(ci): Playwright harness — AC5 console silence + AC6 quit-relaunch`

### Deferred (separate tickets, not this design's scope)

- AC4 boss clear — new ticket; diagnostic-build approach recommended.
- AC7 gear drops — new ticket pending RNG-seed injection design.
- 30-min soak extension — bolt-on `LONG_SOAK=true` env var flag.

---

## 7. CI integration

### When does the harness run?

**Primary trigger:** after every successful release-build on `main`. The existing `release-github.yml` workflow already produces the HTML5 artifact; the Playwright workflow runs as a downstream job that depends on `release-github.yml` completing green. It downloads the artifact, sets `RELEASE_BUILD_ARTIFACT_PATH`, and runs `npx playwright test`.

**Secondary trigger:** `workflow_dispatch` with an optional `ARTIFACT_PATH` input, allowing Tess or the orchestrator to run the harness against any specific artifact (including a `diag/` branch artifact or a PR-branch artifact before merge).

**Does not run:** on every feature PR push (too expensive; GUT handles per-PR gates). The Playwright harness runs after a full release build, which is already a milestone gate rather than a per-commit gate.

### Does it block PR merge?

**Skeleton PR and AC1 + HP-regen smoke: YES.** Once the skeleton lands, `ac1-build-reachable.spec.ts` and `hp-regen-smoke.spec.ts` block any release-build sign-off that doesn't pass these two specs. These are the cheapest tests (no combat input, pure observation) and any failure indicates a fundamental regression in the boot/serve/trace pipeline.

**AC2 + AC3 + AC5 + AC6: tentatively YES after coverage stabilizes.** Coverage stabilization means two consecutive clean runs on `main` without harness-internal flakiness. Until that bar is met, the specs run in `--reporter=html` mode (results visible but not blocking merge). The orchestrator makes the call to flip from non-blocking to blocking per follow-up PR; document the decision in `team/decisions/DECISIONS.md`.

**AC4 + AC7: NO.** Deferred; not in the merge gate.

### Test artifacts on failure

On any spec failure, Playwright uploads to the GitHub Actions run:

- `playwright-report/` — HTML report with trace viewer (Playwright built-in).
- `test-results/*/` — per-spec screenshot + console dump + Playwright trace file.
- The harness names files `<spec-name>-failure-<timestamp>.*` so they are distinguishable when multiple specs fail in the same run.

These artifacts replace the need for Sponsor to read raw DevTools console output; the failure report gives the same `[combat-trace]` evidence in a structured form.

---

## 8. Implementation owner + cadence

**Skeleton PR: Tess** authors the harness infrastructure, AC1 specs, and HP-regen smoke. **Devon pairs** on the `[combat-trace]` line shapes (confirming exact patterns for the trace-matcher), on the PR #148 regen trace format, and on the CI wiring (the release-build downstream-job dependency requires editing Devon's `release-github.yml`). **Estimated effort: 1–2 days** for one focused agent dispatch.

**Follow-up PR 1 (AC2 + AC3): Tess** authors specs. Devon pairs on combat-trace shape for AC2 first-kill + death trace for AC3. The death-triggering input sequence (stand-in-grunt-range vs. diagnostic-build) is the implementation decision Devon confirms at dispatch time. **Estimated effort: 1–2 days.**

**Follow-up PR 2 (AC5 + AC6): Tess** authors specs. No Devon pairing required (console-silence and quit-relaunch are observation tests with no combat-trace dependency). **Estimated effort: ~1 day.**

**Total to "pretty good" (AC1 + AC2 + AC3 + AC5 + AC6 + HP-regen): ~1 week** for one focused agent pair (Tess primary, Devon supporting).

**AC4 + AC7 effort: TBD** at separate dispatch; estimate 1–2 additional days each after the prerequisite work (diagnostic-build harness integration, RNG-seed injection) is designed.

---

## 9. Open questions for orchestrator + Sponsor

**Q1 — M1 RC scope or M2 Week 1?**

The harness does not need to exist before M1 RC signs off. Sponsor's `deb0d21` verdict (or equivalent post-PR-#146 soak sign-off) is the M1 RC gate; the harness is what prevents the *next* RC from requiring the same manual effort. **Recommendation: M2 Week 1 skeleton, parallel to other M2 work.** Confirm with Sponsor that the intent is "I don't want to test the M2 RC the way I tested M1 RC" — if so, the skeleton must land before M2 RC is cut.

**Q2 — Multi-browser testing?**

M1 ships Chrome-default. Playwright supports Chromium, Firefox, and WebKit (Safari). Running all three triples test time and introduces harness-internal flakiness on Firefox/WebKit edge cases that are not Godot bugs. **Recommendation: Chrome-only for v1.** If M2 adds Firefox/Safari as explicit support targets, add a second Playwright project config at that time. Sponsor should confirm whether the M2 RC soak target is Chrome-only or multi-browser.

**Q3 — Specific AC priorities from Sponsor?**

The skeleton covers AC1 + HP-regen as the minimal proof-of-harness. The ordering (AC2 → AC3 → AC5 → AC6) in the follow-up PRs was chosen by coverage-per-effort. If Sponsor wants AC6 (quit-relaunch) moved up to the skeleton (because that was the PR #146 regression class), the orchestrator should adjust the skeleton scope before dispatch. **Ask Sponsor:** which AC, if broken in the M2 RC, would most surprise you to have caught only by hand?

**Q4 — PR #148 regen trace format.**

The HP-regen smoke probe depends on a `[regen]` console trace line from PR #148. If PR #148 has not merged or does not include a `[combat-trace]`-style line for regen shimmer and timer-reset events, the smoke probe cannot be written as designed. **Devon or Drew must confirm the trace format at skeleton dispatch time.** If no trace exists, the implementation agent adds one to PR #148 or files a follow-up to add it.

---

*This document is paste-ready for a future Tess (or Devon) implementation dispatch. The architecture, repo layout, artifact-serve mechanism, AC matrix, CI integration, and ownership are all first-cut decisions with explicit rationale. The implementation agent should treat the AC coverage matrix's console line patterns as approximate — confirm the exact format by reading the `[combat-trace]` lines in `team/tess-qa/soak-2026-05-07.md` (which has real captured lines) before hardcoding patterns.*

---

## 10. Skeleton landed — 2026-05-09 (run 033, PR #150)

**Status:** Skeleton implementation complete. PR open against `main` on branch `tess/playwright-harness-skeleton`.

### Files shipped

```
tests/playwright/
  package.json            — @playwright/test ^1.49, typescript ^5.7, @types/node ^22
  tsconfig.json           — ES2020, commonjs, strict
  playwright.config.ts    — Chromium-only, headless/headed toggle, globalSetup wired
  README.md               — local run instructions + spec coverage table + env vars

  fixtures/
    artifact-server.ts    — RELEASE_BUILD_ARTIFACT_PATH → python http.server → PLAYWRIGHT_BASE_URL
    console-capture.ts    — page.on("console") wrapper; waitForLine/getLines/clearLines/dump APIs
    cache-mitigation.ts   — serviceWorkers:"block" + --disable-cache + --disable-application-cache

  specs/
    ac1-boot-and-sha.spec.ts       — boot sentinel, [BuildInfo] SHA cross-check, no errors, no 404s
    regen-smoke.spec.ts            — [combat-trace] Player | regen activated, HP rising, deactivate on attack
    room-traversal-smoke.spec.ts   — Hitbox.hit damage=6, Grunt._die, door-walk → Room 2

.github/workflows/playwright-e2e.yml — workflow_run trigger + workflow_dispatch + artifact upload on failure
```

### Evidence-verified implementation decisions

All decisions grounded in this-session live reads (per `agent-verify-evidence.md`):

**Boot sentinel:** `[Main] M1 play-loop ready — Room 01 loaded, autoloads wired` (scenes/Main.gd:147). The design doc (§5 AC2 precondition) referenced `[Inventory] starter iron_sword auto-equipped (weapon slot)` — that line does not exist in the codebase. `Main._ready()` does not print it; `Inventory._ready()` only prints `[Inventory] autoload ready (capacity=N)`.

**Regen trace lines:** `[combat-trace] Player | regen activated (HP N/M)` / `regen tick (HP N/M)` / `regen deactivated (HP N/M)` / `regen capped (HP N/M)` — all from `Player._set_regenerating()` and `_tick_regen()` (scripts/player/Player.gd:835–843, 826–829). Q4 from §9 ("Devon must confirm trace format") is resolved: the traces exist already via the `[combat-trace]` shim that fires only in HTML5.

**iron_sword damage:** `damage=6` (resources/items/weapons/iron_sword.tres:11 `damage = 6`). Room traversal spec asserts this specifically.

**Hitbox.hit format:** `[combat-trace] Hitbox.hit | team=player target=Grunt damage=6` (scripts/combat/Hitbox.gd:196). Room traversal spec matches on `team=player.*Grunt`.

**Grunt._die format:** `[combat-trace] Grunt._die | starting death sequence` (scripts/mobs/Grunt.gd:394). Exact string in spec.

**Room label format:** `STRATUM 1 · ROOM N/8` (scenes/Main.gd:904). Not DOM-accessible from Playwright (rendered on Godot CanvasLayer canvas), so room transition detection uses console-trace evidence in the skeleton. Noted as a known gap.

**Artifact format (post-PR-#152):** `actions/download-artifact@v4` downloads artifact named `embergrave-html5-<sha>` containing `embergrave-html5-<sha>-<label>.zip`. CI workflow unzips this once with `unzip` to get the HTML5 directory. `RELEASE_BUILD_ARTIFACT_PATH` points to the unzipped directory.

### Known gaps surfaced by skeleton

- **Room counter detection:** Godot CanvasLayer label is not DOM-addressable. Exact `STRATUM 1 · ROOM 2/8` assertion deferred. Follow-up: Godot JS bridge endpoint or pixel-diff Tier 3 lane (Devon's deferred renderer-painting CI lane).
- **Regen smoke precondition:** If player starts with full HP (hp_current == hp_max), regen suppresses correctly but the test loses coverage. Follow-up: add a controlled damage step via DevTools `eval` or a test-mode flag that exposes HP state.
- **Room 01 grunt kill timing:** Room 01 may have 1 or more grunts at variable positions. The traversal spec uses a timed combat loop (up to 60s) — reliable for this room but fragile if spawn positions change. Follow-up: read grunt count from a console print or use a diagnostic-build with lowered grunt HP.
- **Canvas-focus on CI (headless):** `canvas.click()` should focus the canvas in headless Chromium; verified pattern from design doc. If CI shows "no combat hits" on first run, the fix is `page.locator('canvas').focus()` before input events.

### Follow-up PRs

- **PR 1:** AC2 (cold first-kill ≤60s) + AC3 (death preservation)
- **PR 2:** AC5 (120s console silence) + AC6 (quit-relaunch)
- **Separate tickets:** AC4 boss clear (diagnostic-build); AC7 gear drops (RNG-seed injection design)

---

## 11. M2 W1 expansion landed — 2026-05-09 (ticket `86c9q9de8`)

**Status:** Expanded harness shipped. Single PR delivers AC2 + AC3 + AC4 (`test.fail()`) + equip-flow + negative-assertion sweep. The follow-up plan in §6 is reorganized: PR 1's AC2+AC3 are collapsed into this PR; AC4 lands now as a `test.fail()` placeholder rather than waiting on diagnostic-build. PR 2 (AC5 + AC6) and AC7 remain on the schedule.

### Specs added

| Spec | Status against m1-rc-1 | Notes |
|---|---|---|
| `ac2-first-kill.spec.ts` | green | Asserts ≤60s first-kill + weapon-scaled damage; runs death-pipeline assertion via `_force_queue_free` (the universal completion line — works for both tween-finished and safety-net-timer paths) |
| `ac3-death-persistence.spec.ts` | green | 35 grunt hits → death → respawn → post-respawn damage=6 (proves equipped iron_sword survives `apply_death_rule`) |
| `ac4-boss-clear.spec.ts` | `test.fail()` (failing as expected) | Drives Rooms 1-7 + boss room. Two open P0s (86c9q96fv boss damage, 86c9q96ht boss attack) make boss currently un-killable. When fixed, removes `.fail()` annotation. |
| `equip-flow.spec.ts` | green | F5-reload survival via damage=6 round-trip. Filters known m1-rc-1 push_warning `ItemInstance.from_save_dict: unknown item id 'iron_sword'` (separate ticket-worthy, not equip-flow's concern) |
| `negative-assertion-sweep.spec.ts` | green (3 tests) | Boot uniqueness + Room 01 no-gate + gate causality invariant |

Total: 10 tests across 8 spec files (3 skeleton + 5 expansion). Two consecutive green local runs against `embergrave-html5-53a3412-m1-rc-1.zip`.

### Coverage gaps documented (deferred to follow-ups)

- **Equip-via-LMB-click** (P0 86c9q96m8 — "equipping an item makes equipped slot disappear"): Tab inventory panel renders on Godot CanvasLayer, not DOM-addressable from Playwright. Needs either a Godot JS bridge or a `[combat-trace] Inventory.equip` console line addition.
- **Shooter STATE_POST_FIRE_RECOVERY ledger trace**: per dispatch §5, the negative-assertion sweep was supposed to assert this exists. Current code does NOT emit a per-state-entry ledger trace — only a `_process_post_fire | closing gap` recurrence trace. Adding the explicit `[combat-trace] Shooter.set_state | post_fire_recovery (entered)` trace is a recommended follow-up for Drew/Devon; a fourth negative-assertion test can land as a follow-up.
- **AC4 boss-HP diagnostic env-var hook** (`EMBERGRAVE_DIAG_BOSS_HP=N`): proposed but NOT implemented. Requires orchestrator approval for game-script change before landing. Documented in `ac4-boss-clear.spec.ts` header + `tests/playwright/README.md` env vars table.

### Engineering notes from the run

1. **Death-pipeline tween non-determinism on Playwright cadence.** When AC2's combat loop stops attacking after the first kill, the Godot engine in Chromium can throttle frame-rate, stalling the death tween AND the safety-net SceneTreeTimer. Fix: keep firing canvas clicks during the wait window so frame ticks continue advancing. This pattern (continued-input-while-polling) is a useful primitive — likely belongs in `helpers/` for future specs that need to observe deferred trace lines after a one-shot event.

2. **RoomGate state machine + player respawn point.** Player spawns at `DEFAULT_PLAYER_SPAWN=(240,200)` on every room load, BUT the gate at `(48, 144)` is to the WEST. Gate stays in `STATE_OPEN` unless the player CharacterBody2D crosses the gate trigger area first. Without that, mob deaths never trigger `_unlock` (which only fires when `_state == STATE_LOCKED`). This invariant is significant for any spec wanting to assert gate behaviour — naive "kill mobs and expect gate trace" patterns silently fail. Documented in `negative-assertion-sweep.spec.ts` Test 3 comment block.

3. **Equip-flow's m1-rc-1 push_warning filter.** Save-restore in m1-rc-1 emits `USER WARNING: ItemInstance.from_save_dict: unknown item id 'iron_sword'`. The warning maps to `console.error` in HTML5 (Godot push_warning → console.error). This is an actual bug in the save-restore round-trip path — the ContentRegistry resolver isn't yet ready by the time `Inventory.restore_from_save` runs. Side-effect-free for equip flow because `equip_starter_weapon_if_needed` re-equips post-restore, but the warning is independently ticket-worthy.

---

## 12. AC4 harness-drift fix landed — 2026-05-10 (PR `tess/m2-w1-ac4-drift-fix`, ticket `86c9qahku`)

**Status:** Harness-drift fix landed (drift discipline + `expectedSpawn` parameter + `_on_body_entered` assertion + Room01 PR #169 dummy support). AC4 spec stays `test.fail()` because a NEW game-side blocker surfaced during empirical verification: after clearRoomMobs reports 2/2 grunts dead, the gate's `_mobs_alive` counter shows 1 not 0, blocking `lock()` → `_unlock()` auto-transition. The "body_entered does not fire under Playwright" hypothesis (PR #170) was overturned by Devon's PR #171 investigation (ticket 86c9qbhm5). The drift root cause was real and is now fixed; the mobs_alive desync is a separate, downstream finding.

### Fixture-discipline pattern: stay near spawn during combat

The recurring footgun (Devon's PR #171 finding 3) is that **post-combat walks that depend on a known starting position will silently fail when prior combat drifts the player**. Knockback feedback over a 21s clear with an 8-direction aim sweep accumulated 100+px of westward+northward displacement; the gate-traversal helper's W→N walk pattern then started from the drifted position and landed against the room west/north wall outside the trigger rect. No body_entered fired. No gate_unlocked fired. The spec timed out on the gate_traversed wait, with no clear signal pointing back to "you drifted away from spawn."

**Mitigation pattern (apply to any spec that walks a precise spawn-relative path post-combat):**

1. **No aim-sweep.** Set facing once at room start (`w+d` briefly for NE) and click-only after that. `Player._facing` persists across click-only attacks.
2. **No direction-key holds during combat.** Holding direction keys during attack-recovery causes 60px/s drift (half walk speed during STATE_ATTACK).
3. **No repositioning loops.** Don't periodically walk-to-close-gap; let mobs chase the player via their AI.
4. **Use a single direction that matches mob spawn geometry.** All Stratum-1 Room01..Room08 mob spawns are NE/N of `DEFAULT_PLAYER_SPAWN=(240,200)` (verified against `resources/level_chunks/s1_room0N.tres` × `tile_size_px=32`). NE facing covers the geometric majority; chasing AI handles edge cases.

### `gateTraversalWalk` defensive `expectedSpawn` parameter

The helper now accepts an optional `expectedSpawn: [x, y]` tuple in its options bag. The value is propagated to log lines and the failure message when `RoomGate._on_body_entered` does NOT fire — making drift-related failures self-documenting rather than presenting as "gate_unlocked never fired" with no indication that the player wasn't even at the trigger.

The runtime value isn't used to assert position (Playwright cannot read Godot world-coords without a JS bridge), but the parameter establishes a contract: spec authors who pass `expectedSpawn` are documenting their assumption that the calling combat phase kept the player near that point, and any future failure mode can blame the contract rather than guess.

### Per-room `_on_body_entered` assertion

Devon PR #171 added an explicit `_combat_trace("RoomGate._on_body_entered", "body=... state=... mobs_alive=...")` line at function entry in `RoomGate.gd`. The AC4 spec asserts this trace fires per gate. It is the load-bearing positive signal that the trigger rect was reached at all — distinguishes "gate never reached" (drift) from "gate reached but state-machine wrong" (regression).

### Regression canary

`tests/playwright/specs/room-gate-body-entered-regression.spec.ts` (Devon PR #171) is now the permanent canary for the body_entered signal itself. It skips Room02 combat entirely, walks from spawn into the gate via the documented W→N pattern, asserts body_entered fires. Any future failure of this canary indicates the signal IS regressing — investigate Godot 4.x version bumps, gl_compatibility physics-server changes, or service-worker timing interference. AC4's harness-drift fix does NOT touch the canary's spawn-position walk path.

---

## 13. Roster-swap regression discipline — 2026-05-10 (PR `tess/m2-w1-spec-roster-swap-fix`, ticket `86c9qcfck`)

**Status:** 6 specs updated to traverse Stage 2b's Room01 (1 PracticeDummy instead of 2 grunts). Helper at `tests/playwright/fixtures/room01-traversal.ts` extracts the walk-NE-then-attack-sweep pattern that AC4's PR #172 first encoded. All 6 specs pass against `origin/main` post-PR-#172. Full harness state: 12/12 (AC4 still `test.fail()` pending the `_mobs_alive` desync game-side investigation).

### The discipline (applies to any future PR that changes a level chunk's mob roster)

**Rule:** any PR that mutates a `resources/level_chunks/*.tres` file's `mob_spawns` array (count, type, or position) MUST audit every harness spec that traverses that level. Six specs (AC2, AC3, equip-flow, room-traversal-smoke, negative-assertion-sweep Test 2, room-gate-body-entered-regression) all assumed Room01 had 2 grunts; PR #169 silently broke them by swapping to 1 PracticeDummy. They went red-on-main for ~24h before being noticed.

**Audit checklist (paste into the roster-swap PR's Self-Test Report):**

1. **Trace patterns:** does any spec match on `Grunt._die`, `Charger._die`, `Shooter._die`, etc., for the room being changed? If the new roster removes that mob class, those matchers become vacuous and silently pass (or fail if a count assertion is paired). Search the harness for the affected mob class name.
2. **Combat budget:** does any spec depend on the room's mob HP / damage rates for timing (e.g. "die in 17 seconds because 2 grunts deal 6 dmg/s")? PR #169's PracticeDummy deals zero damage, so AC3's death-trigger pattern broke immediately.
3. **Auto-advance vs RoomGate:** does the room use `_install_room01_clear_listener` (Room01 only) or a RoomGate (Room02-08)? Roster swaps don't usually break this surface, but worth verifying the new mob class still emits `mob_died` (the dummy does, by design — see `scripts/mobs/PracticeDummy.gd` signal contract).
4. **Walk-to-mob discipline:** does the new mob CHASE? PR #169's PracticeDummy is rooted-by-design — every spec that previously relied on grunts closing to attack range now needs a walk-NE-then-attack-sweep pattern. Use `clearRoom01Dummy` as the canonical reference.
5. **Pickup side-effects:** does the new mob drop something? PR #169's dummy drops a guaranteed iron_sword pickup (which lands in the inventory grid via `Inventory.add` — NOT `equip()`, so no `[combat-trace] Inventory.equip` line fires from the pickup). Specs that count `Inventory.equip` traces or rely on inventory grid state need to account for the auto-pickup-on-walk behavior.

### Centralized helper pattern

Multi-spec traversal patterns live in `tests/playwright/fixtures/`, not duplicated per spec. The roster-swap PR found six specs that needed nearly-identical Room01 traversal logic; centralizing in `room01-traversal.ts` means a future Stage 2c or PR-#146-bandaid retirement edits one file. Same pattern as `gate-traversal.ts` (PR #170/#171/#172).

When a per-spec `clearXMobs` helper grows past ~50 lines AND is duplicated across 2+ specs, factor it into a fixture. The factored helper should:

1. Accept the canvas `Locator`, `ConsoleCapture`, click coords, and an options bag with a `budgetMs` knob.
2. Document its preconditions (player position, canvas focus, no held keys) and postconditions (trace lines that should be in the buffer after success).
3. Throw with a useful failure message including the last 30 trace lines on budget exhaustion.
4. Return a result object with `dummyKilled` / `gateTraversed` / `attacksFired` / `durationMs` for spec-side instrumentation.

### Bandaid coexistence as a first-class concern

Specs that depend on PR #146's `equip_starter_weapon_if_needed` boot-time auto-equip (i.e. damage=6 from swing 1) MUST document the bandaid-retired path in their header. The retirement ticket is `86c9qbb3k`; when it ships, a paired spec-update PR will need to:

1. Insert a Tab→click-grid-cell flow between the Room01 dummy poof and the Room02 entry (to equip the dropped iron_sword).
2. Update the `damage>=2` assertions to `damage===1` (FIST_DAMAGE) until the equip step.
3. Adjust per-direction `attacksPerDir` if needed (dummy still dies in 3 swings at FIST_DAMAGE=1, which fits the helper's current budget without change).

The header documentation makes this PR cheap to write — every affected spec already cites the retirement ticket and the change shape. Don't make the future spec-update PR re-discover the constraints.
