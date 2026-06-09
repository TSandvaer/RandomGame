# Test Conventions

What this doc covers: the cross-layer test conventions for Embergrave's two test surfaces — GUT (headless Godot, runs in CI on every push/PR) and Playwright (browser-driven, runs against the HTML5 release-build artifact). Topic-specific tests still live in `team/tess-qa/` (acceptance plans, journey-probe procedure, soak rituals); this doc is the **load-bearing framework conventions** that every test author needs to know.

## Universal warning gate (ticket `86c9uf0mm`)

The Sponsor M2 RC soak meta-finding (2026-05-15) was that **3 of 4 user-visible findings would have been caught by a universal console-warning zero-assertion** — `leather_vest` unknown-id, DirAccess HTML5 recursion warnings, save-schema migration warnings. The fix shipped as a two-surface gate: Playwright Phase 1 (Tess, PR #217 — merged) covers HTML5 console; GUT Half B (Devon, this PR) covers headless engine.

### GUT side — `NoWarningGuard` + `WarningBus`

> **86ca65gyv migration note (4.3 → 4.6, 2026-06-08):** the limitation below was true on 4.3 and motivated the WarningBus call-site-shim design, which stays in use. Separately, GUT 9.6.0 (the 4.6-compatible GUT pin) ADDED its own engine-error capture (`addons/gut/error_tracker.gd` + `gut_tracked_error.gd`) that auto-fails a test on any unexpected engine `push_error` / `ERROR:` during its body. This is INDEPENDENT of WarningBus and bit the migration: every deliberate-negative-path test (bad-JSON save load, invalid ZoneDef, null chunk) that correctly `push_error`s now trips GUT's capture and must opt-in via GUT's `assert_push_error` / error-expectation API (the GUT-side analog of `WarningBus.expect_warning`). Tracked in the migration breakage inventory.

**The Godot 4.3 limitation that shapes this design.** Godot 4.3's GDScript API does NOT expose any way to install a custom logger or intercept `push_warning` / `push_error` calls from within the GDScript process. Verified surfaces:

- `OS.add_logger()` — C++ only, no GDScript binding.
- `Engine.set_print_error_messages()` — boolean toggle (mute / unmute); no hook callback.
- `EngineDebugger.register_message_capture()` — captures debugger-protocol messages, not engine warnings.
- No signal fires on `push_warning`; no `_log_message` virtual.

So the only GDScript-accessible path is **wrap `push_warning` at the call site** with a tiny shim that BOTH calls the real `push_warning` (so the warning still surfaces in Godot's console, HTML5's `console.warn`, and CI's stderr) AND records the event into an observable signal that tests can subscribe to.

**Components:**

- **`scripts/debug/WarningBus.gd`** — autoload registered as `WarningBus`. Exposes `warn(text, category)` and `error(text, category)`. Each call invokes the native `push_warning` / `push_error` AND emits a corresponding signal (`warning_emitted` / `error_emitted`).
- **`tests/test_helpers/no_warning_guard.gd`** — GUT helper class. Subscribes to the bus signals on `attach()`, asserts zero captured emissions on `assert_clean(self)`, supports `expect_warning(pattern)` opt-out for tests that deliberately exercise a warning path.

**Usage pattern (every save-load / content-resolution / mob-registry GUT test):**

```gdscript
const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

var _warn_guard: NoWarningGuard

func before_each() -> void:
    _warn_guard = NoWarningGuard.new()
    _warn_guard.attach()

func after_each() -> void:
    _warn_guard.assert_clean(self)
    _warn_guard.detach()
    _warn_guard = null

func test_some_path_that_deliberately_warns() -> void:
    _warn_guard.expect_warning("substring of the expected warning text")
    # ... exercise the code path that emits the warning ...
```

`expect_warning(pattern)` is a per-emission opt-out — registering one pattern consumes one matching warning. Two matching warnings with one expectation = one violation. The substring match is intentionally simple (case-sensitive substring) — tests express intent inline rather than building regex matchers.

**Migration policy.** Source-side migration of `push_warning` → `WarningBus.warn` is targeted, not blanket. The **load-bearing surfaces** are migrated:

- `scripts/loot/ItemInstance.gd::from_save_dict` — unknown item id + unknown affix id paths
- `scripts/content/MobRegistry.gd` — load failures, null mob_def, unknown stratum, unknown mob_id (spawn path)
- `scripts/save/Save.gd::migrate` — schema-newer-than-runtime path

Other call sites (audio, level assembler, mob telemetry) remain on direct `push_warning` until / unless a future ticket reveals an analogous gap. **Adding a new save-load / content-resolution surface? Route warnings through `WarningBus.warn(...)` from day one** so the guard catches regressions automatically.

**Wired GUT test files** (every save-load + content-resolution surface):

- `tests/test_save.gd` — round-trip + migration
- `tests/test_save_roundtrip.gd` — death-rule + AC-shaped invariants
- `tests/test_save_migration.gd` — v0→v3 fixtures
- `tests/test_save_restore_resolver_ready.gd` — iron_sword resolver ready-ness
- `tests/test_mob_registry.gd` — mob registry surface + scaling
- `tests/test_content_factory.gd` — factory smoke + drift

**Paired test for the guard itself.** `tests/test_no_warning_guard.gd` pins:

1. `WarningBus` autoload is registered (boot-time).
2. The guard catches a deliberate `WarningBus.warn(...)`.
3. `expect_warning(pattern)` lets a matching warning pass.
4. The guard catches a deliberate `WarningBus.error(...)`.
5. A mismatched `expect_warning` pattern does NOT consume a real warning.
6. `detach()` is idempotent and clears state.
7. Multiple `expect_warning` patterns each consume one warning.
8. One `expect_warning` does NOT swallow two matching warnings.
9. An unattached guard captures nothing (no silent passes).

If the guard quietly stops working (e.g. a future refactor breaks the signal wiring), this file fails first — the canary that protects the gate.

### Playwright side — `test-base.ts` fixture

See `tests/playwright/fixtures/test-base.ts` for the Playwright-side gate. The TypeScript fixture extends Playwright's base `test` with an auto-attached `ConsoleCapture` and a teardown assertion that fails on `USER WARNING:` / `USER ERROR:` console lines (Godot HTML5's `push_warning` / `push_error` prefix shape).

**Playwright `ConsoleMessage.type()` returns `"warning"` (NOT `"warn"`) for `console.warn()` calls.** Verified empirically 2026-05-16 against Playwright 1.49 + Chromium (ticket `86c9upfex`). The original test-base.ts filter checked only for `"warn"`, which silently let every `USER WARNING:` line through — the gate was a no-op for warnings from PR #217 (ship) through PR #244 (Phase 2A migration). The negative-control canary at `universal-console-warning-gate.spec.ts:205` surfaced it via "Expected to fail, but passed" within hours of Phase 2A landing. **Filter rule: accept BOTH `"warning"` (current Playwright API) AND `"warn"` (defensive against future API / CDP renames).** Authors building helper code on top of `ConsoleCapture.getLinesByType(...)` should pass `"warning"`, not `"warn"`. Full enum: `"log" | "debug" | "info" | "error" | "warning" | "dir" | "dirxml" | "table" | "trace" | "clear" | "startGroup" | "startGroupCollapsed" | "endGroup" | "assert" | "profile" | "profileEnd" | "count" | "time" | "timeEnd"`.

Specs adopt the gate by changing one import line:

```diff
- import { test, expect } from "@playwright/test";
+ import { test, expect } from "../fixtures/test-base";
```

Opt-out semantics mirror the GUT side: `test.use({ expectedUserWarnings: [/regex/] })` for an allow-list, `test.use({ allowUserWarnings: true })` for whole-describe-block opt-out (last resort).

**Spec migration status (2026-05-15).** Phase 1 (Tess, PR #217) shipped the fixture infrastructure + one demonstration spec. Phase 2A (migrate the 11 existing specs to the new import) is a mechanical follow-up tracked separately — once the leather_vest fix landed (PR #214) and Devon's Half B GUT side ships, Tess picks up Phase 2A. Until then, existing specs still import from `@playwright/test` and run unaffected.

### The two surfaces complement each other

- **GUT** covers headless engine behavior: save-load round-trips, registry resolution, scaling math, AI state machines. Fast feedback (~1m20s in CI), but cannot exercise the WebGL2 renderer or browser-level concerns.
- **Playwright** covers the HTML5 release-build artifact: actual `gl_compatibility` rendering, service-worker cache behavior, real input events, canvas-to-DOM coordination. Slower (release-build + browser boot per spec), but the only surface that catches HTML5-specific divergences.

**A bug class is "covered" only when BOTH surfaces have a test for it** when the bug class can manifest in either lane. The Sponsor M2 RC meta-finding was that headless GUT and the Playwright suite both shipped green for 24 hours while the Sponsor's manual soak found three production warnings — every test path was scoped, none was universal. The two-surface warning gate is the structural answer.

## Playwright CI mechanics (auto-trigger / classification / failure-list triage)

The sections below cover **CI mechanics** — when Playwright fires, how to verify status, how to classify failures, how the orchestrator gates merges. For **renderer-perception mechanics** (`gl_compatibility` divergence, headless-vs-real-browser visibility, author HTML5 self-soak), scroll down past these sections to § "Author HTML5 self-soak" + § "Playwright headless ≠ real-browser perception". The two doc clusters are intentionally separate but co-located. If you're authoring a PR: start here for the auto-trigger contract. If you're verifying visual perception: scroll down.

### Playwright e2e CI auto-triggers on every PR — but author + orchestrator must still verify (PR #299, corrects PR #293)

**Updated 2026-05-22** during P0 ticket `86c9xw8xd` (Playwright-red on main 7 days) investigation chain. Earlier convention (PR #293 era) said Playwright was `workflow_dispatch`-only and required manual kicks on `feat/*` branches. **That is now stale.** As of PR #299 (commit `9773250`, 2026-05-21), `playwright-e2e.yml` has a `pull_request` trigger that **auto-fires on every PR push** — all branch prefixes (`feat/*`, `fix/*`, `docs/*`, `spike/*`). The two-surface gate (GUT + Playwright) is now structurally two-surface from the moment a PR opens.

**This DOES NOT mean authors can ignore Playwright on their PRs.** Main was Playwright-red for 7 days (2026-05-15 → 2026-05-22, parent ticket `86c9xw8xd`) precisely because authors merged on `gh pr merge --admin` while Playwright was red on the merge SHA. Admin-merge bypasses GitHub's Required-Checks gate. **Verification is now the author's + orchestrator's responsibility, not GitHub's.**

**Author convention** — any PR (regardless of branch prefix) MUST verify Playwright check status before claiming ready-for-QA in the Self-Test Report. Silence on Playwright is now read as "didn't check," not "didn't need to."

**Self-Test Report line to include (UPDATED):**

> **Playwright e2e:** auto-fired at SHA `<sha>` — run `<url>` — verdict: green / red-but-pre-existing-on-main (cite parent run) / red-new (BLOCKER) / N/A (no Playwright-covered surface)

If Playwright is red on the PR's HEAD, the author MUST classify:

- **red-but-pre-existing-on-main**: cite the matching main red run (`gh run list --workflow=playwright-e2e.yml --branch=main --limit 5`) showing the same failure set. Apples-to-apples comparison required.
- **red-new**: BLOCKER. PR introduces the regression; do not claim ready-for-QA.

### Control-comparison technique — disambiguate "mine vs pre-existing" via a same-base docs-only PR (PR #317 finding)

**The trap.** When classifying Playwright failures as pre-existing vs new, the obvious approach is `gh run list --workflow=playwright-e2e.yml --branch=main --limit 5` to pull the latest main red run and compare its failure set to the PR's failure set. **This breaks when the PR base predates the latest main red run** — failure-list specs may have been added or renamed between the PR's base and the main run, producing false-positive "new" classifications.

**Empirical case (Tess PR #317 QA, 2026-05-22):** Tess was QA'ing Devon's equip-flow fix on `eb6714e`. Latest main Playwright (`26187844079` on `2435669c`, 2026-05-20) predated four of the now-failing specs (`pr291` × 2, `pr300` × 2, `t16`). A naive apples-to-apples vs that baseline would have flagged all four as "new" — they weren't; they'd just been added after that baseline.

**Disambiguator — same-base docs-only PR as control.** Pick a CONCURRENT docs-only PR with the same merge-base as the PR under review. Pull its Playwright run. Compare failure sets: anything in both = pre-existing; anything only in the PR under review = new. Tess used PR #316 (Priya's 3-mitigation orch-docs PR, docs-only, same merge-base era) as the control for #317.

**Why docs-only specifically:** A docs-only PR is GUARANTEED not to introduce gameplay regressions — its Playwright failures are 100% pre-existing-on-main. That makes it the cleanest control for "what failures are baseline right now?"

**Workflow shape** — the `gh run view <id> --log | grep "✘ \[" | sort -u` filter is the canonical Playwright-triage shorthand. Bookmark it; every failure-list comparison uses some shape of this command.

```bash
# 1. Pull failure list from PR under review
gh run view <pr_run_id> --log | grep "✘ \[" | sort -u > /tmp/pr-fails.txt

# 2. Pull failure list from concurrent docs-only PR (same merge-base era)
gh run view <docs_pr_run_id> --log | grep "✘ \[" | sort -u > /tmp/docs-fails.txt

# 3. Diff — anything only in PR under review = NEW regression
diff /tmp/pr-fails.txt /tmp/docs-fails.txt
```

If diff is empty → all PR failures are pre-existing → classify red-but-pre-existing-on-main → merge eligible per Mitigation 1.
If diff shows additions → PR introduced new regressions → classify red-new → REQUEST CHANGES.

**Special handling for `test.fail()` glyphs.** Playwright renders `test.fail()` blocks that throw a placeholder error as `✘ [<spec>]` in the text output, but the run summary's `N failed` line counts them as PASS (fail-as-expected). When triaging failures, **bisect by spec-name from the `N failed` summary line, NOT by counting `✘` glyphs in the text output**. The morning Tess investigation of P0 `86c9xw8xd` initially conflated these two surfaces and produced a fabricated "9-failure cluster" framing; Devon's later investigation revealed the true `1 failed` count was a different spec entirely.

### Shell-only / orch-tooling PRs — skip the sibling control, diff against prior PR's Playwright run (PR #326 finding)

**When the sibling-control technique is overkill.** The docs-only sibling approach above is designed for game-side code PRs where you need to isolate "did my change add a regression?" When the PR under review is itself **mechanically incapable of affecting game-side Playwright** — i.e. it touches only shell hooks, `.claude/` tooling files, workflow YAML, or pure markdown docs — no sibling control is needed. A shell-only PR's Playwright failures are 100% pre-existing by definition; the only remaining question is which prior run to diff against.

**Why `gh run list --commit <main-HEAD-SHA>` returns `[]` — and why that's the signal.** `playwright-e2e.yml` fires on `pull_request` open/sync, `workflow_dispatch`, and release-tag pushes — but NOT on plain main pushes. So querying by the most recent main HEAD commit:

```bash
gh run list --workflow=playwright-e2e.yml --commit <main-HEAD-SHA>
```

returns `[]`. That empty result is NOT an error — it is the confirming signal that Playwright didn't fire on that commit. Reach for the most recent Playwright run from any earlier merged PR as the baseline.

**Workflow shape:**

```bash
# 1. Confirm Playwright didn't fire on main HEAD (empty = expected, not an error)
gh run list --workflow=playwright-e2e.yml --commit <main-head-sha>
# → [] : correct, proceed to step 2

# 2. Pull the last merged-PR Playwright run from main branch
gh run list --workflow=playwright-e2e.yml --branch main --limit 5 \
  --json databaseId,headSha,createdAt,conclusion \
  --jq '.[] | select(.conclusion != null)'
# Pick the most recent completed run — this is the correct prior-PR baseline

# 3. Diff failure sets
gh run view <pr_run_id> --log-failed | grep "✘" | sort -u > /tmp/pr-fails.txt
gh run view <baseline_run_id> --log-failed | grep "✘" | sort -u > /tmp/base-fails.txt
diff /tmp/base-fails.txt /tmp/pr-fails.txt
```

**Interpretation:**
- `[]` from step 1 is expected, not an error — it confirms Playwright doesn't auto-fire on main pushes.
- Diff empty (or delta is a known persistent flake) → all PR failures are pre-existing → classify red-but-pre-existing-on-main → merge eligible.
- Diff shows any failure NOT in the persistent-flake set → treat as red-new (BLOCKER) even for a shell-only PR — something upstream changed.

**Saves the 17-minute rerun cost.** The instinct when session notes say "Playwright yellow" is to `gh run rerun --failed`. For a shell-only PR, that rerun produces the same failure set — the failures are pre-existing flakes, not regressions. The `[]`-from-main-commit + prior-PR-diff short-circuits the wait entirely.

**Empirical case (PR #326, 2026-05-22):** PR was a shell-only `maintain-docs-stop.sh` change (orch-tooling). `gh run list --commit abd1182` returned `[]`. Located baseline via `gh run list --branch main` filtered to Playwright → run `26294689527` on SHA `615be229`. Delta: only `ac2-first-kill` in PR #326 not in baseline — confirmed persistent flake. Net new regressions: zero. Merged without rerun.

**Summary decision tree:**
- PR touches game-side code (`scripts/`, `scenes/`, `resources/`, `assets/`, `tests/`) → use the docs-only sibling control technique (§ above).
- PR is shell-only / orch-tooling / docs-only (`.claude/`, `team/`, `docs/`, shell scripts, pure markdown) → query main HEAD commit → get `[]` → diff directly against most recent prior PR Playwright run → no rerun needed.

### CI race — initial PR push may show empty checks until rebase re-triggers (PR #318 finding)

**The trap.** Occasionally a brand-new PR will show NO check-runs at all in `gh pr checks <num>` and `gh api repos/<org>/<repo>/commits/<sha>/check-runs` returns `{"total_count": 0}` — even though `playwright-e2e.yml` and `ci.yml` both have `pull_request` triggers configured. The workflows simply did not register against that initial push.

**Suspected cause:** race between GitHub's webhook-event registration and the workflow-trigger evaluation when the PR base is stale relative to current main (PR branch created off local main that was N commits behind origin/main).

**Workaround that works reliably:** rebase the PR branch onto current origin/main + force-push. The fresh push event re-triggers the workflows. Empirically validated on PR #318 (Drew peer-review caught the empty-checks anomaly; orchestrator rebased + force-pushed; CI immediately fired on the rebased commit).

**Adjacent benefit:** rebasing also resolves any stale-base diff noise (per `rebase-before-merging-stale-base-pr` memory). Two birds, one rebase.

### Manual SHA-pin sequence (still relevant for out-of-band runs)

Useful when running Playwright against an out-of-band release-build, e.g. diag-build soak or manually-triggered main verification:

```bash
# 1. Trigger release-build for the PR head SHA (if not auto-built via release-github.yml chain)
gh workflow run release-github.yml --ref <branch>

# 2. Wait for artifact (query by --commit <sha>, NOT --branch --limit 1 — race)
gh run list --workflow=release-github.yml --commit <sha>

# 3. Kick Playwright against same SHA (only needed if auto-fire didn't catch this SHA)
gh workflow run playwright-e2e.yml --ref <branch>

# 4. Confirm both runs reference the same SHA before pasting links
```

See memory `gh-run-list-race-on-just-pushed` for why `--commit <sha>` is mandatory over `--branch --limit 1` when polling the just-pushed run. See `.claude/docs/html5-export.md` § "Release-build trigger and artifact handoff" for the matching artifact-link pattern.

**Note — `release-github.yml` does NOT auto-fire on main pushes** (only `workflow_dispatch` + release tag pushes + PR open/sync). To verify a post-merge main green-flip (e.g. closing a Playwright-red parent ticket after the fix PR merges), the orchestrator MUST manually run `gh workflow run release-github.yml --ref main` to fire the release-build → `workflow_run` chain → Playwright. Empirical case: P0 `86c9xw8xd` closure on 2026-05-22 required manual trigger of run `26294618225`.

### Orchestrator merge-gate cross-reference

**Per `team/GIT_PROTOCOL.md` § "Orchestrator merge-gate verification" (landed PR #316 Mitigation 1, merged `55679077`):** orchestrator MUST verify Playwright check status on the PR's HEAD SHA before `gh pr merge --admin`. If red, classify per the three-way bucket above using the control-comparison technique. Cite the run-id URL + classification in the merge comment. This is the structural fix for the 7-day silent main-red break (`86c9xw8xd`).

### Historical context

Pre-PR #299, `playwright-e2e.yml` was `workflow_dispatch`-only and authors manually kicked it per a separate convention (the "Playwright e2e CI does NOT auto-trigger" rule, original heading on this section). PR #293 was that era's precedent. PR #299 added the `pull_request` trigger but `test-conventions.md` was not updated until the 7-day silent break (`86c9xw8xd`) surfaced the stale-doc gap.

### Author HTML5 self-soak — mandatory before claiming fix-complete on visual-gated surfaces (PR #291 v3 two-iteration failure)

**The bar:** for any PR touching an HTML5-visual-gated surface (CPUParticles2D, tween modulate, Polygon2D, ColorRect with HDR colors, Area2D state mutations, z-index ordering, shape outlines via `_draw()`, any new `gl_compatibility`-rendered primitive), the **authoring agent MUST self-soak the actual HTML5 release-build in an incognito browser with DevTools F12 console open** before posting the Self-Test Report and claiming fix-complete.

**Why:** GUT-green + CI-green are *necessary but not sufficient*. They exercise the engine's headless paths only, not the `gl_compatibility` WebGL2 pipeline. Bugs that manifest only on gl_compatibility (HDR clamp, Polygon2D quirks, z=0 same-z occlusion, shader compat, particle emission semantics) are invisible to those two surfaces.

**Empirical precedent — PR #291 (2026-05-21):** Drew authored T5+T6+B3+B4 fixes. Two consecutive iterations (SHA `3f3e9a7` v3 → SHA `670769f` v3-with-B3) were both Tess-APPROVED on GUT-green + CI-green. Both were Sponsor-soaked in HTML5 incognito — and both reported that T6 aftershock was invisible AND B3 slam-animation was still kicking. The gl_compatibility-runtime divergence bit twice in a row because the author never opened a browser. The Sponsor on the second failure said verbatim: **"prevent claiming fix-complete on GUT+CI alone."**

**Author Self-Test Report MUST include an "HTML5 author-self-soak" section** with:

1. Release artifact link (the exact build the author soaked)
2. BuildInfo SHA verification line from the DevTools console
3. The visual behavior observed (screenshot or text description of what the author saw in browser)
4. Trace excerpts from DevTools console if any `[combat-trace]` lines were emitted during the test interaction
5. Pass/fail call: did the visual match the design intent in the actual browser?

Without that section, the PR is treated as **not yet at "ready for QA"** regardless of GUT/CI status — Tess will REQUEST CHANGES asking for the section.

**For the orchestrator dispatching such work** — every dispatch brief targeting an HTML5-visual-gated surface must include the author-self-soak step explicitly in the agent's task list. Example brief language: "Build the release artifact, extract, serve locally, open incognito + DevTools, verify the visual matches in browser. THIS IS MANDATORY — do not post the Self-Test Report claiming fix-complete on GUT-green + CI-green alone."

**Composition with the per-surface escape clause** (`html5-export.md` § HTML5 visual-verification gate): the escape clause governs whether a Sponsor pre-merge soak is required. The author-self-soak requirement applies regardless — even on escape-clause-eligible surfaces (SpriteFrames-anim drop-ins on the established mob-roster path, Label-text changes), the author must still self-soak before claiming fix-complete. The escape clause waives the Sponsor gate, not the author gate.

**What this rule does NOT cover:** pure code refactors that change no visual surface; backend / save / inventory / data-model changes without a visual; audio-only changes. For those classes, GUT-green + CI-green remain sufficient per the existing testing-bar.

### Edge case — CLI-agent unsoakable surfaces (PR #300 finding)

Sub-agents in CLI environments (no GUI browser, no input devices) **cannot interactively drive the game** through multi-room traversal to reach late-game surfaces. PR #300 (boss wake-anim) surfaced this: Devon could verify the build LOADS and `[BuildInfo]` SHA was correct in headless Playwright probe, but could NOT visually verify the wake animation — that required interactive play through 7 rooms.

**Resolution pattern:**

1. **Author posts the structural blocker explicitly.** Self-Test Report includes "Structural soak blocker" section listing what could not be verified and why. Partial evidence (build loads, SHA verified, console clean, automated Playwright probes) is captured.
2. **Author proposes ONE of three paths to orchestrator** rather than fabricating a pass:
   - **(A) Sponsor manual soak** — interactive verification by Sponsor.
   - **(B) Follow-up tooling PR** — land a soak-acceleration tool (e.g. `?start_room=N` URL param, like Drew's PR #291 v4 diag commit) so future CLI agents can bypass traversal. Re-soak with the tool.
   - **(C) Renderer-safety escape clause** — for surfaces where the analysis is empirically sound (e.g. SpriteFrames-anim drops through the same engine path as the entire mob roster's walk/atk/die anims — empirically renderer-safe), the author argues the rule's spirit (catch gl_compatibility divergence) doesn't apply to this specific surface class.
3. **Orchestrator surfaces the choice to Sponsor.** Any relaxation of the rule needs explicit Sponsor sign-off — orchestrator does NOT decide.

**Why this isn't a rule-breaker:** the author-self-soak rule's spirit is "no fabrication of evidence; what the author CAN verify, they must." Structural unsoakability is not the author choosing to skip; it's the surface being out of reach. The rule still bites — author MUST enumerate what they couldn't soak and route the merge decision to Sponsor.

**Burden of proof — "cannot be done headless" requires concrete failure evidence (PR #300 push-back, 2026-05-21).** Hand-waved infeasibility claims are not acceptable. Drew's PR #291 v6 captured 4 screenshots from a CLI-agent Playwright session at distinct timing windows (t+1ms / t+163ms / t+330ms / t+505ms via a 20ms-cadence local spec) — empirically proving HTML5-class surfaces ARE Playwright-screenshot-capturable from a CLI agent on this codebase. **Before claiming infeasibility, the author MUST demonstrate failure of three approaches in order:**

1. **(a) Playwright input simulation** — drive the game state via `page.keyboard.press()` / `page.mouse.click()`. Highest evidence fidelity; closest to a real player session.
2. **(b) Existing test-only hook** — grep for `[combat-trace]` near the visual trigger; check for a debug-only direct invocation (hotkey, JS-bridge call). Zero-marginal-cost if the hook exists.
3. **(c) New debug-flag URL param** — add a small, debug-only URL param (e.g. `?force_wake_on_load=true`) that bypasses the natural trigger condition. Smaller code surface than (a) for complex triggers (multi-frame state machines, proximity-based AI), but only when (a) and (b) fail. Skipping straight to (c) creates per-PR-tool drift.

If all three fail with concrete documented failure modes (specific Playwright error, code-path absence, build break), THEN "infeasible" becomes an acceptable claim and the merge routes to path A (Sponsor manual soak). Without that evidence, "cannot be done" is not acceptable — Drew's precedent disproves it as a blanket statement.

### Playwright screenshot-burst timing — wall-clock dilation gotcha (PR #300 finding)

When using Playwright `page.screenshot()` for author-self-soak screenshot captures against an HTML5 release headless build: **each `page.screenshot()` call dilates browser wall-clock by ~200 ms.** This was empirically discovered on PR #300 wake-anim self-soak: a 10-frame burst with `waitForTimeout(50)` between calls expected ~500 ms of wall-clock but consumed >2 seconds — long enough that an interleaved attack inside the burst was firing past `WAKE_DURATION=417ms` and missing the window the author was trying to assert against.

**Rule — fire timing-sensitive engine interactions BEFORE the screenshot burst, not inside it.** The burst-capture pattern shape:

```typescript
// CORRECT — engine interaction first, then capture
await triggerSlam(page);                     // fires the engine event we want to capture
await waitForTraceLine(page, "_spawn_slam_aftershock");
const startMs = Date.now();
for (let i = 0; i < 12; i++) {
  await page.screenshot({ path: `burst-${i.toString().padStart(2,"0")}.png` });
  await page.waitForTimeout(20);             // ~20ms cadence + ~200ms dilation = ~220ms real per frame
}

// WRONG — engine interaction interleaved with screenshots
for (let i = 0; i < 12; i++) {
  if (i === 5) await firePlayerAttack(page); // attack fires too late due to dilation
  await page.screenshot({ path: `burst-${i}.png` });
}
```

**Wall-clock duration assertions must be loose** — if your spec asserts "wake completes within X ms," allow generous slack (3-5×) or rely on the `[combat-trace]` line for timing-of-record rather than the test runner's wall-clock. The engine continues stepping during `page.screenshot()` (the burst captures distinct anim frames even while wall-clock is dilated), so the trace remains accurate even when wall-clock isn't.

**Why this matters for self-soak specs:** Drew's PR #291 burst-capture spec works because the slam aftershock is a one-shot fire event with no further engine interaction needed during the capture window. Devon's PR #300 wake-anim spec hit this gotcha because wake animation has internal state transitions (DORMANT → WAKING → ACTIVE) that the author may want to verify mid-capture; trying to interleave attack-during-wake into the burst was the failure shape. Fire the interaction first, capture from there.

### Playwright headless ≠ real-browser perception (PR #291 v6→v7 finding)

**Critical gap in the author-self-soak rule discovered 2026-05-21:** Playwright headless screenshot captures are NOT a sufficient gate for visibility-of-effect claims. They prove "particles spawned at the right position with the right config," not "a human will see them in real-time motion."

**The empirical case:** Drew's PR #291 v6 captured 4 screenshots from Playwright headless at distinct timing windows (t+1ms / t+163ms / t+330ms / t+505ms) showing the slam aftershock burst. Tess APPROVED the test layer on this evidence. **Sponsor then soaked the same build in a real interactive incognito browser and reported "I cannot see the sparkles Drew sees in his screenshots."** Two failure modes are possible (any combination):

- **(A) Sub-perceptual frames** — Playwright captures arbitrary timing windows (t+1ms etc.) that the human eye, sampling at ~60 Hz with motion-blur and attention drift, never actually resolves. A bright frame at t=1ms is rendered but invisible to perception.
- **(B) Headless-vs-interactive rendering divergence** — `gl_compatibility` may render CPUParticles2D ramp/alpha/scale differently in headless Chromium (no full GPU compositor pipeline) than in interactive Chrome. Less well-empirically-confirmed than (A) but plausible.
- **(C) Sprite occlusion + dispersion timing** — particles spawning at boss position are partially hidden behind the boss sprite at t=0; by the time they disperse out of occlusion (~50-100ms), the ramp[0] flash has decayed. The screenshot at t=1ms catches them still bundled at center; the eye in real-time only sees the late-ember tail outside the sprite.

**Rule — Playwright headless is for trace + config verification, NOT for "this is visible" claims.** Author self-soak via Playwright remains MANDATORY (the new burden-of-proof rule above) — but the Self-Test Report MUST NOT claim "PASS — Sponsor will see it" from headless screenshot evidence alone. The honest claim shape: "trace + spawn position + ramp config + particle count all match v<N> design intent; visual-of-record verification deferred to Sponsor interactive soak per html5-visual-verification-gate."

**For the orchestrator gating merges:** when an author's Self-Test Report cites Playwright screenshots as the visibility-of-effect proof, treat that as INCOMPLETE evidence. Sponsor's interactive soak remains the gate of record for CPUParticles2D / tween modulate / Polygon2D class. The author-self-soak rule is about *due diligence + trace verification*; it does NOT replace the Sponsor visual gate.

**For the AUTHOR — implications for designing effects:** if Playwright-captured frames show the effect clearly but real-browser perception doesn't, the effect is too brief, too small, or too occluded for human real-time perception. Make it longer (clamp the bright ramp window for ~80-100ms, not just t=0), wider (more particles, larger scale, escape-velocity outward to clear sprite occlusion), or louder (brighter contrast or supplemental sprite-modulate flash). The fix is in the design, not the Playwright cadence.

**Structural follow-up:** path (B) is the durable answer. A `?start_room=N` + `?boss_hp_mult=N` URL-param suite on `main` would let all future visual-gated PRs self-soak from a CLI agent (build → curl → headless-browser Playwright probe with screenshots → confirm visual). Without such tooling, late-game-state surfaces will keep falling to path (A), which doesn't scale.

**Open follow-up (Sponsor-class decision, queued separately):** wire `playwright-e2e.yml` to auto-trigger on `feat/*` push, matching Headless GUT. Until then the manual-kick convention is the gap-closer. PR #293 (Tess re-QA flag) is the precedent. **Update 2026-05-21:** Sponsor picked option C — `pull_request: branches: [main]` triggers on both workflows. Implementation in flight via PR #299 (see SHA-semantics section below for the foot-gun caught during the meta-self-test).

### Chained-workflow SHA-pin on `pull_request` events (PR #299 Devon-caught bug)

**The trap.** When chaining workflows via `workflow_run` AND adding a `pull_request` trigger, `GITHUB_SHA` semantics differ between event types:

| Event type | `GITHUB_SHA` value | Visible in `gh pr view --json headRefOid`? | Suitable for SHA-pin? |
|---|---|---|---|
| `push` / `workflow_run` (chain trigger) | commit SHA at branch tip | yes | yes |
| `pull_request` | synthetic merge commit (`refs/pull/N/merge`, 2-parent) | no — exists only inside GitHub Actions runner | NO — fails fast on any downstream SHA-pin that uses `pull_request.head.sha` |

`github.event.pull_request.head.sha` is the branch tip — same value as `gh pr view --json headRefOid`, same value humans soak against in DevTools `[BuildInfo]`.

**Why this matters.** If `release-github.yml` stamps `GITHUB_SHA` into the artifact name on `pull_request` events, the artifact gets named after the synthetic merge commit. Downstream `playwright-e2e.yml`'s `resolve_via_pr_sha` then reads `pull_request.head.sha` (branch tip) and the W3-T11 SHA-pin verifier fails — refusing to run tests against an artifact whose SHA doesn't match. **This is the fail-fast contract working as designed**, but it means the chained CI silently never passes until the SHAs agree.

**Resolution convention — stamp `pull_request.head.sha` on PR events.** In the upstream workflow that produces the SHA-pinned artifact:

```yaml
- name: Compute artifact SHA
  run: |
    if [ "${{ github.event_name }}" = "pull_request" ]; then
      SHORT_SHA="${{ github.event.pull_request.head.sha }}"
    else
      SHORT_SHA="${{ github.sha }}"
    fi
    echo "SHORT_SHA=${SHORT_SHA:0:7}" >> $GITHUB_ENV
```

This keeps the artifact name and the downstream pin both anchored to the **human-visible branch-tip SHA**, preserving the Sponsor-soak ritual where the HUD `[BuildInfo]` SHA equals `gh pr view`'s `headRefOid` equals the artifact filename suffix.

**Validation pattern — the meta-self-test.** A PR that *changes* CI workflow triggers should itself fire those triggers on PR-open. PR #299 did exactly this: opening the PR auto-launched both workflows on the PR HEAD, and the SHA-pin verifier caught the GITHUB_SHA vs `pull_request.head.sha` mismatch immediately. **For any CI workflow change, the PR opening the change IS the first end-to-end live test** — review the resulting workflow runs as part of peer-review before merging.

## Spec-string-vs-engine-emit drift (ticket `86c9upffv`)

**The trap.** Playwright specs assert against `[combat-trace]` line shapes via regex. The trace strings are interpolated from engine-side `StringName` constants (e.g. `Hitbox.TEAM_PLAYER = &"player"` / `Hitbox.TEAM_ENEMY = &"enemy"`). A spec author who guesses the string from intuition rather than reading the constant ships a regex that **never matches a real production trace** — but Playwright reports "assertion failed" the same way as a real engine bug, so the misdiagnosis class is open.

**The PR #215 cautionary tale.** `mob-self-engagement.spec.ts` was authored with `team=mob target=Player` — a string that has never existed in the codebase (Hitbox.gd has only `&"player"` and `&"enemy"`, no `&"mob"`). The spec failed for Room 02 + every `test.fail()` block on every CI run since merge, hidden among other CI bounces until PR #244 Phase 2A migration surfaced it as a named failure cluster (`86c9upffv`). `soak-narrative-regression.spec.ts` had the same defect in its OR-branch (dead code, latent landmine).

**Pre-existing vs migration-induced — the diagnostic shape.** When a Playwright spec failure-list spikes after a fixture-level refactor (test-base.ts, console-capture.ts, etc.), the first triage question is always: **did the spec EVER pass before the refactor?** Pull the same spec's run on the merge-base SHA via `gh run view <run-id> --log | grep <spec-name>`. If the spec was already failing on the merge-base, the refactor is not the cause — it surfaced a pre-existing defect that other failures previously hid. The post-migration triage stays under one full reading of the CI log this way: empirically verify before hypothesising harness-side causes.

**The drift-pin pattern (`test_team_constants_match_trace_string_contract`).** Every engine-side constant that feeds a trace string a Playwright spec depends on needs a GUT test pinning its value:

```gdscript
func test_team_constants_match_trace_string_contract() -> void:
    assert_eq(String(Hitbox.TEAM_ENEMY), "enemy", "...")
    assert_eq(String(Hitbox.TEAM_PLAYER), "player", "...")
```

If a future refactor renames the constant value (`&"mob"`, `&"hero"`, etc.), the GUT pin fails in headless CI BEFORE the Playwright spec gets a chance to drift silently green-on-no-match. The pin is the structural answer to the "spec author guessed wrong" failure class — it makes the engine ↔ spec contract explicit.

**Apply this pattern whenever** a Playwright spec regex captures an interpolated `StringName` / `String` value from an engine `const`. Other live surfaces: `Mob._set_state` state names (`STATE_IDLE`, `STATE_CHASING`, `STATE_KITING`, `STATE_AIMING`, `STATE_POST_FIRE_RECOVERY`, `STATE_DEAD`), `Shooter._set_state` band labels, `TutorialEventBus.request_beat` beat ids. Each should have a pinned-constant GUT test if a Playwright regex matches against it.

## Adversarial off-cardinal probe values for decoupling specs (PR #282)

**The trap.** A spec asserting "system follows X, NOT Y" (a decoupling regression) can pass vacuously on a regression if the probe input sits on a degenerate value where both the coupled and decoupled implementations return the same output. The canonical case is cardinal-axis values for angle-based decouples: `atan2(0, 1) = 0` exactly. A regression re-coupling to Y still produces 0 → assertion passes silently.

**The fix — adversarial off-cardinal probes.** Choose probe values where `f(coupled_input) ≠ f(decoupled_input)` and neither is the additive identity for the assertion. For angle-based probes, a 45° diagonal eliminates the 0-symmetry trap because both `sin` and `cos` are non-zero.

**PR #282 example (walk-feel decouple spec):** testing "sprite rotation follows movement-velocity, not cursor `_facing`":

| Cursor probe | `_facing.angle()` | Result |
|---|---|---|
| Cardinal-east `Vector2(1, 0)` | `atan2(0, 1) = 0` | Silent pass — cursor-coupled regression still asserts `sprite_rot == 0` |
| **SE-diagonal `Vector2(1, 1)`** | `atan2(1, 1) ≈ 0.785` | Loud fail — cursor-coupled regression emits non-zero `sprite_rot` |

**Validation method — revert-hack.** Temporarily revert the fix under test on a throwaway branch, run the spec, confirm it fails on each surface independently. If a cardinal-pin alternative would not have failed on the revert, the probe is degenerate. Document the revert-result PR ID + run ID in the PR body — PR #282 cites runs `26099417065` (Fix #2 revert) and `26099635330` (Fix #1 revert).

**Apply when:** any spec whose core assertion is "behavior follows A, not B" — anim-source decoupling, signal-source decoupling, physics-parameter decoupling. The adversarial probe is the structural answer to the silent-symmetry failure class.

## Pre-DCL false-green — post-`waitForSelector` probes have no teeth for DOMContentLoaded-deferral regressions (ticket `86ca2561j`, pending PR #390)

**The trap.** A Playwright regression guard that dispatches its probe event AFTER `await page.waitForSelector("#canvas")` (or any other post-interactive sentinel) + `page.evaluate(...)` is a **false-green** for any regression class where the fix must be active *before* `DOMContentLoaded`. On a fast headless load, DCL has already fired by the time `waitForSelector` resolves — so a regression that defers the fix to DCL (e.g. a contextmenu suppressor that attaches its `preventDefault` listener on `DOMContentLoaded` instead of synchronously at head-parse) **still passes**. The spec exercises the right surface but is vacuously true against the exact regression it was written to catch. Sibling of the adversarial-off-cardinal trap above and the passive-damage-window trap below: all three are "looks covered, no teeth."

**Empirical case (ticket `86ca2561j`, pending PR #390 merge).** The pre-hardened `contextmenu-suppress.spec.ts` test 5 dispatched its `contextmenu` after `waitForSelector("#canvas")`. A revert to the old DCL-deferred suppressor form still passed it (the listener was already attached by then). Flagged non-blocking during PR #386 QA (`team/tess-qa/_pr386-approve.md`: old test passed 8/8 on a hand-reverted DCL-deferred build).

**Why the class is broad — not contextmenu-specific.** Any spec asserting "this fix is active from the very first interaction, including before/during bootstrap" hits this trap. Surfaces: event-suppression handlers (contextmenu, keydown, beforeunload) that must apply from first render; console-override patches that must precede any DCL handler; input-capture layers that must register before any gesture. Whenever the fix's root cause was "listener registered too late," the guard must probe the pre-DCL window.

**Fix — fire the probe during `document.readyState === "loading"`.** Two validated mechanisms:

1. **`page.route` HTML splice (preferred — deterministic).** Intercept the served `index.html`, splice a probe `<script>` immediately before `</head>` (after the real `head_include` suppressor). The spliced script fires the event synchronously during head-parse, while `readyState === "loading"`, and records `defaultPrevented` + the readyState to a `window.__*` global the test reads back.
2. **`addInitScript` + a slow-loading asset** to widen the `loading` window. Simpler but timing-fragile (the asset-delay must straddle the probe dispatch); prefer Mechanism 1.

**Three mandatory anti-vacuousness guards** (all required — each closes a silent-pass hole):
1. **Assert the spliced HTML was actually served** (e.g. `expect(body).toContain("</head>")` in the route handler, or verify a marker post-load). A `replace` no-op or route-pattern mismatch otherwise yields a vacuous pass.
2. **Assert `document.readyState === "loading"` at probe time** (captured inside the spliced script, asserted from the test). If it's `"interactive"`/`"complete"`, the probe fired too late and has no discriminating power.
3. **Include a plain-`click` negative control** — confirms the suppressor selectively catches `contextmenu`, not all events (rules out "something swallows everything").

**Empirical discriminator (pending PR #390 merge):** HARDENED build (suppressor at head-parse) = 5 passed / 0 failed; REVERTED build (DCL-deferred) = 1 failed (exactly the pre-DCL probe test) / 4 passed. Clean red-on-revert / green-on-main — the spec has teeth.

**What this does NOT cover.** If the fix is DCL-or-later *by design* ("attach listener after canvas ready"), a post-`waitForSelector` guard is correct. The pre-DCL trap fires only when the invariant is specifically "active before DCL" — verify the fix's intended timing before choosing the probe window.

**Cite shape.** Ticket `86ca2561j` (Tess contextmenu-suppress harden). Spec `tests/playwright/specs/contextmenu-suppress.spec.ts` "pre-DCL window" test (pending PR #390 merge — per unmerged-defer rule, the line ref firms up on merge). Suppressor feature context: `.claude/docs/html5-export.md` § "Browser-native event leakage".

## Passive-damage Playwright probe windows (PR #281)

**Minimum window: 15 s** at default game speed for Room 01 mob density. An 8 s window is insufficient — Grunts at distance 27–28 tiles take 10–12 s to close to melee range and land their first hit. The probe closes before any damage events occur and the negative assertion is vacuously true.

**Rule:** any spec asserting "player takes N hits in observation window" or "cue X does NOT fire during N seconds of passive damage" must use `PASSIVE_DAMAGE_WINDOW_MS ≥ 15_000`. Count `Player.take_damage` trace events as a positive confirmation that damage actually occurred during the window — a zero-cue negative is only meaningful if damage events are present.

```typescript
// Grunts at 27-28 tiles need ~10-12s to close + land first hit; 15s gives safety margin.
const PASSIVE_DAMAGE_WINDOW_MS = 15_000;
```

**Room 02 load sentinel.** There is no `[combat-trace] Main._load_room_at_index` line. When a spec needs to wait for Room 02 to finish loading, use the first `Grunt.pos` or `Grunt._set_state` line in the console as the sentinel — that line fires from `_physics_process` once the room's first mob is alive and ticking.

## Visual primitives — see `team/TESTING_BAR.md` § "Visual primitives"

Tier 1 (mandatory): target color ≠ rest color (`assert_ne`). Tier 2 (mandatory for parented modulate cascades): assertion lands on the visible-draw node, not the parent CharacterBody2D. Tier 3 (aspirational): framebuffer pixel-delta — deferred pending a renderer-painting CI lane. Full detail + rationale in `team/TESTING_BAR.md`.

## `preload` of `.tres` can bind to `null` at parse-time — exact differentiator unknown (PR #357 lesson)

**What it is.** Hoisting a `load("res://...zone.tres")` call to a top-of-file `const FOO := preload("res://...zone.tres")` declaration is the canonical `gdlint duplicated-load` fix shape. But it does NOT work uniformly: at least one observed `.tres` file (`resources/level/zones/s1_z1_outer_cloister.tres`) silently binds to `null` when consumed via `preload`. Every test that reads the const crashes with "must load as <ResourceClass>" assertion failures.

**The known-failing case.** `resources/level/zones/s1_z1_outer_cloister.tres` — contains 9 `ZoneAnchor` sub-resources (each with its own `script = ExtResource(...)` pointing to `scripts/level/ZoneAnchor.gd`). When hoisted as `const OUTER_CLOISTER_ZONE := preload(...)`, the const binds to `null`. PR #357 attempted this hoist at `tests/test_zone_def.gd:247` + `tests/test_floor_assembler.gd:493` — 4 GUT tests cascade-failed.

**The mechanism is NOT well understood.** The intuitive hypothesis ("`preload` fails on `.tres` with nested scripted sub-resources, succeeds on flat scripted `.tres`") does NOT hold empirically — at least `resources/level_chunks/s1_room01.tres` has nested scripted sub-resources but hoists cleanly elsewhere in the test suite. The actual differentiator between hoist-safe and hoist-trapped `.tres` is currently unknown. Candidate factors not yet ruled out: ZoneAnchor's specific script ordering, ExtResource count thresholds, sub-resource-to-script-path mapping shape, Godot 4.3-specific loader-cache state at parse-time. **Treat the trap as empirical-only until / unless a future investigation tickets the mechanism.**

**The honest detection signal.** Before committing a `preload(...)` hoist of a `.tres` to a `const`, write a one-line GUT smoke test that asserts the const is non-null:

```gdscript
func test_const_resolves_at_parse_time() -> void:
    assert_not_null(MY_RESOURCE_CONST, "Hoist binds to null — use load(...) instead per test-conventions § preload trap")
```

Run the test once locally. If it passes, the hoist is safe for this file. If it fails, the const binds to null and the hoist must be reverted regardless of why.

**Fix shape — two options.**

1. **Per-site `# gdlint:disable=duplicated-load` opt-out** at the test's `load(...)` call site:
   ```gdscript
   # gdlint:disable=duplicated-load
   var zone: ZoneDef = load("res://resources/level/zones/s1_z1_outer_cloister.tres")
   # gdlint:enable=duplicated-load
   ```
   Keeps the runtime `load`; suppresses the gdlint finding locally. Use for 1-2 sites per file.

2. **Helper-function wrapper** — promote the load into a small `_load_<zone>() -> ZoneDef` helper near top-of-file:
   ```gdscript
   func _load_outer_cloister_zone() -> ZoneDef:
       return load("res://resources/level/zones/s1_z1_outer_cloister.tres")
   ```
   Use when 3+ sites need the same load — the helper deduplicates without triggering `duplicated-load` (the lint rule keys on identical `preload(...)` / `load(...)` literal strings; a single function call site is the only literal).

**When to choose which.** Per-site opt-out is the minimal-surgery choice. Helper-function wrapper is the right call when the file already has clusters of identical loads (3+ sites) — the helper improves readability anyway. Both are equally valid; pick by surface scope.

**CI failure signature.** When the trap triggers, GUT logs `Expected [<null>] to be anything but NULL: <path-to-tres> must load as <ResourceClass>` on tests that read the hoisted const. Cascades to multiple test files if the const is consumed widely. Treat this as the canonical "I hoisted a `.tres` that fails the trap" signal — but do NOT rely on structural inspection of the `.tres` to predict the trap pre-hoist (Priya's PR #358 review empirically refuted the "nested-scripted" predictor).

**Cite shape.** PR #357 (Devon's `duplicated-load` Stage-2 sweep, ticket `86c9y58pf`) attempted to hoist `OUTER_CLOISTER_ZONE := preload(...)` in `tests/test_zone_def.gd:247` + `tests/test_floor_assembler.gd:493`. Drew's PR review caught the GUT regression (4 failing tests, 5 risky-siblings). The `.tres` itself (`s1_z1_outer_cloister.tres`) shipped via PR #344 (W2-T3 S1 procgen retrofit, merge `ed8ae26`). The trap appears to be structural to Godot 4.3's `preload` semantics but the exact mechanism is uninvestigated — Priya's PR #358 peer-review empirically refuted the "nested-scripted sub-resources" hypothesis (siblings with same structure hoist fine). Future Stage-2 lint sweeps must run the per-file null-check smoke (above) before committing hoists.

## gdlint pragma scopes — inline / file-top / global, and when to use which (PR #365 lesson)

**Three pragma shapes ship with `gdtoolkit/linter`. Each has a distinct scope.**

```gdscript
# Shape 1 — inline RANGE (next-line through matching `enable`):
# gdlint:disable=duplicated-load
var zone: ZoneDef = load("res://...")
# gdlint:enable=duplicated-load

# Shape 2 — FILE-TOP (above `extends` / `class_name`, no `enable` needed):
# gdlint:disable=max-public-methods
# rationale: Director-pattern autoload; high method count IS the design
extends Node
class_name AudioDirector

# Shape 3 — global GDLINT-RC disable (applies repo-wide, per `gdlintrc`):
# (in gdlintrc, NOT in source files)
disable:
- class-definitions-order
```

**Shape 1 (inline range)** — `# gdlint:disable=<rule>` paired with `# gdlint:enable=<rule>`. Disables the rule only between the two markers. Use for 1-2 sites per file where you want the rest of the file to keep enforcing the rule. The `duplicated-load` section above is the worked example.

**Shape 2 (file-top, no `enable`)** — `# gdlint:disable=<rule>` placed ABOVE `extends` / `class_name` disables the rule from that point through EOF. The gdtoolkit regex (`gdtoolkit/linter/__init__.py:188-202`) treats a `disable` without a paired `enable` as range-to-EOF. Use when every public method in the file (or every reasonable instance of the rule's trigger) is intentional — Director-pattern autoloads, UI panels, GUT test fixture classes. Pair with a one-line rationale comment so future readers know why the file-scope disable is justified.

**Shape 3 (global gdlintrc disable)** — adds the rule name to the `disable:` list in `gdlintrc`. Applies repo-wide; no per-file pragma needed. Use when the rule's spirit doesn't fit the project's design grammar at all (`class-definitions-order` is the current precedent — Godot's `@onready`-then-`func` ordering is intentional and would trip the rule on every Godot file).

**Decision rubric — when to pick which:**

| Situation | Shape | Why |
|---|---|---|
| 1-2 lines in an otherwise-conforming file need the exception | Inline range | Surgical; rest of file keeps enforcement |
| Every instance of the rule in this file is intentional (e.g. an autoload's API breadth) | File-top + rationale | One disable + one rationale comment per file; rationale lives near the code |
| The rule's spirit doesn't fit the project's design grammar at all | Global `gdlintrc` | Repo-wide; avoid per-file pragma churn on every analogous file |

**Threshold heuristic between file-top and global:** if 100% of the rule's findings across the repo are intentional (`class-definitions-order` was the canonical case), prefer global. If most are intentional but a few are genuine refactor candidates (Devon's max-public-methods sweep classification: 23 of 25 were intentional + 2 ambiguous), prefer file-top — keeps the rationale-cite per file and leaves the rule active for future-file analysis.

**Cite shape.** PR #365 (Devon's Stage-2 max-public-methods sweep, ticket `86c9y58vn`, commit `0248bd7`) — 25 file-top pragmas added across `scripts/audio/AudioDirector.gd` + `scripts/player/Player.gd` + 23 GUT test classes; zero refactor candidates. The gdtoolkit regex semantics that govern file-top scope-to-EOF live at `gdtoolkit/linter/__init__.py:188-202` (empirically verified pre-commit; cite class is "build-tool mechanics," not project-pinned). The existing `class-definitions-order` global-disable precedent lives at `gdlintrc:21-30` and is the worked example of Shape 3.

## Bare-test deferred-fixture auto-fire trap (PR #306 lesson)

**What it is.** A GUT test instantiates `Stratum1BossRoom` (or any room with a `_ready` that does `call_deferred("_assemble_room_fixtures")`) directly, awaits a frame for the deferred call to drain, and then asserts on `_entry_sequence_active` state — but the test fails because `_assemble_room_fixtures()` auto-fires `trigger_entry_sequence()` **after one frame** when `_boss != null`. The bare-test premise (no boss should mean no auto-fire) collides with the production code's "if you brought a boss, kick the sequence off" convenience.

**Why it bites bare tests specifically:** the GUT bare-test surface deliberately instantiates the room scene without the surrounding `Main.tscn` orchestration. The room's `_ready` runs anyway, and `call_deferred("_assemble_room_fixtures")` queues a frame-deferred call that the test's `await get_tree().process_frame` then services. By the time the test asserts on entry-sequence state, the auto-fire has already armed it.

**Codified fix shape (PR #306, validated by Tess re-review):**

```gdscript
var room = preload("res://scenes/levels/Stratum1BossRoom.tscn").instantiate()
room.boss_scene_path = ""    # <-- BEFORE add_child_autofree; closes the gate at Stratum1BossRoom.gd:358
add_child_autofree(room)
await _drain_fixture_pass() # process_frame drain still safe — auto-fire gate now closed
```

The gate at `Stratum1BossRoom.gd:358` (currently — verify line if refactored) checks `if _boss != null:` before auto-firing `trigger_entry_sequence()`. Setting `boss_scene_path = ""` before child-add closes the gate indirectly: `_spawn_boss()` (around `:485`) calls `load(boss_scene_path)`, which returns null on the empty path → `push_error` + early return → `_boss` stays null → the `_boss != null` gate fails → no auto-fire.

**Order matters:** `boss_scene_path = ""` must be set **before** `add_child_autofree(room)`. Setting it after means `_ready` has already queued the deferred call against the original `boss_scene_path` value.

**Scope of the pattern:** applies to ANY test instantiating a room/level scene whose `_ready` queues deferred fixture-pass / auto-fire logic. The same fix shape works for any scene that exposes the "if asset path is empty, skip the auto-fire" convention. When authoring a new room with auto-fire convenience, expose an `@export var <feature>_path: String` (default `""` or a real path) and gate the auto-fire on `path != ""` — that's the contract bare tests can rely on.

**Symptom to recognize:** test premise reads "no boss should mean no entry-sequence-active" yet GUT log shows the entry sequence engaging anyway after a frame-drain await. The deferred-call resolution is the culprit, not the test order.

## Timing assertions — signal-await vs fixed-timer floor (PR #357 follow-up)

**The anti-pattern.** A GUT test wants to assert "this completes within X ms," so it writes:

```gdscript
var start_ms: int = Time.get_ticks_msec()
trigger_thing()
await get_tree().create_timer(0.8).timeout      # ← THE TRAP
var elapsed_ms: int = Time.get_ticks_msec() - start_ms
assert_lt(elapsed_ms, 800, "thing completes under 800 ms")
```

**Why it's structurally broken.** The `create_timer(0.8).timeout` await is ITSELF the measurement floor. The assertion `assert_lt(elapsed_ms, 800)` then races the timer-driven floor against the assertion bound — zero margin. Worked example: `tests/test_first_boss_kill_skip.gd::test_skip_collapses_intro_timing_to_about_half_a_second` (pre-fix) passed on main for weeks by 1-5 ms of luck. PR #357's preload-hoist work perturbed CI variance enough to tip the at-bound assertion (812 ms / 812 ms on rerun-same-SHA — definitively not flake; the test was always fragile).

**The fix — await the actual completion signal.** Production code that emits a `<thing>_completed` signal IS already the right oracle. Subscribe + await directly:

```gdscript
var start_ms: int = Time.get_ticks_msec()
trigger_thing()
if not subject.is_thing_completed():
    await subject.thing_completed
var elapsed_ms: int = Time.get_ticks_msec() - start_ms
assert_lt(elapsed_ms, 700, "thing completes under 700 ms")
```

This measures actual signal-fire time with frame-period precision (~16 ms at 60 Hz, the GUT runner's typical frame budget). The assertion bound is now a real behavioral bound on the system-under-test, NOT a race against a fixture-side timer.

**Pre-fire guard against signal-race.** If the production code can complete BEFORE the test's `await` line executes (e.g. the `trigger_*` call synchronously fires the signal), the bare `await` would hang. Guard with `if not subject.is_*_completed(): await subject.<signal>` — checks the post-condition first, awaits only if not yet completed. This is the canonical shape; see the worked example at `tests/test_first_boss_kill_skip.gd:359-360`.

**Bound headroom.** Pick the assertion bound by considering signal-fire-time + frame-period overhead. For 60Hz GUT the headroom should be ≥ ~50 ms for safety margin. The PR #357 fix tightened from 800 ms (at-bound) to 700 ms (signal-fire-bound with ~16 ms headroom against the empirically-observed ~684 ms mean). Don't bound TOO loosely — a 1500 ms bound on a 700 ms behavior won't catch a regression that doubled the runway.

**When the anti-pattern is acceptable.** Only when there is genuinely no production signal to await (extremely rare for any system with completion-state — most GUT-tested subjects emit a `<state>_completed` or similar). If you find yourself unable to identify the natural completion signal, that's a code-smell on the production code, not a justification for the timer-await pattern. File a follow-up to add the signal.

**Surfaces this trap repeats on.** Sequence-collapse tests (boss intro skip), freeze-recovery tests (time-scale unwind), animation-completion tests (tween-driven HUD reveal), hit-pause tests (TimeScaleDirector.freeze duration). Audit any GUT test with `await create_timer(N).timeout` followed by `assert_lt(elapsed_ms, ~N*1000)` — the timer-floor-IS-the-bound trap is the same shape.

**Cite shape.** PR #357 (ticket `86c9y58pf`, merge `1aabfce`) — commit `36ccf12` (Devon's follow-up) refactored `tests/test_first_boss_kill_skip.gd:319-374` from the timer-await pattern to the signal-await pattern. Tess's PR #357 final-review noted that the underlying test had been passing by 1-5 ms of luck for weeks; Drew initially classified the failure as a flake until rerun-same-SHA failed twice. The trap is structural, not specific to that test.

## Test stubs — script-typed `extends Node` required for `Object.set` writes (PR #352 lesson)

**What it is.** A GUT test wants a lightweight stub for a real game object (e.g. `Player`), so it instantiates `Node.new()` and seeds fields via `Object.set("active_bounty", QuestState.new())`. Every assertion against the stub then fails with bizarre shapes — `active_bounty is null` when it was just `set` to a value, `Trying to assign value of type 'Nil' to a variable of type 'Array'` when reading a Variant field.

**Root cause.** Godot 4 GDScript's `Object.set(name, value)` **silently drops the write when the property does not exist on the receiver**. A bare `Node.new()` has only the base `Node` API surface — no `active_bounty`, no `completed_bounties` — so every stub-seeding write becomes a no-op. The next `Object.get(...)` returns `null` (or the type-default for typed reads), and downstream code that expects a real value crashes or asserts incorrectly.

**Why GDScript silently drops, not warns.** `Object.set` is the engine's generic mutator (same surface scripts use for runtime-typed property access via `tween_property` etc.). The engine cannot distinguish "intentional dynamic-property write" from "typo of an existing property" — so it silently accepts the write into a property bag that subsequent reads ignore. No warning is emitted; no `push_warning` fires. The failure surfaces only at the consumer site.

**Fix shape (PR #352, ticket `86c9y7ydg`).** Declare a script-typed stub that explicitly enumerates every field the system-under-test will `set` or `get`:

```gdscript
# tests/test_helpers/player_stub_for_quest_router.gd
extends Node

var active_bounty: Variant = null         # explicit declaration — `set("active_bounty", x)` now sticks
var completed_bounties: Array = []        # typed default — read returns [] not null
```

Then in the test:

```gdscript
const PlayerStubScript := preload("res://tests/test_helpers/player_stub_for_quest_router.gd")

func before_each() -> void:
    _player_stub = PlayerStubScript.new()   # NOT Node.new()
    _player_stub.active_bounty = quest_state  # direct assignment OR Object.set both work now
```

**When to use this pattern.** Any GUT test that:
- Instantiates a bare-Node stub instead of the real production class
- Calls `Object.set(stub, "<field>", value)` to seed state
- Reads the same field back via `Object.get` or direct dot-access

If the test exists, the pattern applies. The cost is one ~20-line helper script per stub-shape; the benefit is reads/writes behave as the test author expects.

**Alternative considered (rejected):** instantiating the real `Player.new()` instead of a stub. Rejected because `Player` carries the full scene/input/audio/animation dependency surface — instantiation pulls in dozens of unrelated subsystems, and any one of them warning during test setup pollutes `NoWarningGuard`. The narrow-stub pattern is the right granularity.

**Cite shape.** PR #352 / commit `4e33717` introduced this pattern; helper file lives at `tests/test_helpers/player_stub_for_quest_router.gd`. The same shape applies to any future test that needs a Player-stand-in or any other game-object stub.

## Typed `Dictionary[K, V]` is Godot 4.4+ — assert lookup-equivalence, not typeof (PR #362 lesson)

**What it is.** A GUT test wants to pin "this Dictionary uses `StringName` keys, not `String` keys" and reaches for the typed-collection syntax — `var d: Dictionary[StringName, bool] = {}` — OR asserts `typeof(k) == TYPE_STRING_NAME` over the keys. Both shapes CI-parse-error on Godot 4.3 with `Only arrays can specify collection element types.` The fix is not to retype the contract; it's to assert the property the production code actually depends on: **lookup-equivalence**.

**Root cause.** Godot 4.3's GDScript parser supports typed Arrays (`Array[Foo]`) but NOT typed Dictionaries (`Dictionary[K, V]`). Typed Dictionaries were added in Godot 4.4. Any source file that includes the syntax — including inline-`source_code`-via-`GDScript.new()` test stubs — fails to compile on 4.3. Likewise the `typeof(k) == TYPE_STRING_NAME` equivalence test is a fragile proxy: a Dictionary keyed with `String` literals that happen to round-trip via `StringName(s)` lookups is functionally equivalent for the consumer's purpose, so a typeof-equivalence assertion is testing the wrong invariant.

**Fix shape — assert what the consumer actually does.** Production code reads the Dictionary via `dict.has(StringName(zone_id))` (or `dict[StringName(zone_id)]`). The test contract is therefore: **given the keys supplied, does the consumer's `StringName`-coerced lookup find them?** Pin the lookup directly:

```gdscript
# WRONG — typed-collection syntax fails to parse on Godot 4.3
var discovered: Dictionary[StringName, bool] = {}
assert_true(typeof(discovered.keys()[0]) == TYPE_STRING_NAME)

# RIGHT — assert the lookup the production code performs
var discovered: Dictionary = {}
discovered[StringName("s1_z1_outer_cloister")] = true
assert_true(discovered.has(StringName("s1_z1_outer_cloister")),
    "panel.has(StringName(zone_id)) must find the discovered key")
```

**Adjacent foot-gun — typed loop variables ARE supported in 4.3.** `for btn: Button in _stratum_buttons:` parses and runs fine on Godot 4.3; only `Dictionary[K, V]` is the gap. Don't reach for an untyped `for x in ...` workaround when the loop-variable type-annotation works — it's just the typed-collection-literal syntax that's 4.4+.

**Forward-compat property.** The lookup-equivalence pattern works UNCHANGED on Godot 4.4 once typed Dictionaries land. The consumer-of-record assertion (`dict.has(StringName(s))`) is correct regardless of whether the Dictionary's keys are statically typed `StringName` or dynamically typed Variant-holding-StringName. No sunset action needed when the engine upgrades — the test stays accurate.

**Apply when.** Any GUT test pinning a `Dictionary` contract on a panel / controller / save-payload surface where the producer writes `StringName` keys and the consumer reads via `dict.has(StringName(x))`. Other live surfaces: discovered-zones / discovered-waypoints maps, dialogue branch-key dictionaries, quest-state action payloads.

**Cite shape.** PR #362 (Devon's world-map UI minimal, ticket `86c9y10fv`, respin SHA `a8eae88`). Tess's QA-iteration hypothesised typed-Dict as the contract fix; CI rejected it with the parse-error. Devon's actual fix landed on lookup-equivalence assertions (test renamed from `..._normalises_string_keys_to_stringname` → `..._normalises_keys_for_stringname_lookup` to match the actual Godot 4.3 contract).

## `queue_free` + same-name re-`add_child` auto-renames the new node — `remove_child` first (PR #362 lesson)

**What it is.** A UI panel rebuilds its child list on state-change by calling `queue_free()` on the old children and `add_child()`-ing new ones with the same names in the same frame. Tests that `find_child("ZoneRow_<id>", true, false)` against the panel return `null`, even though the panel renders correctly to the screen. The new children silently received auto-renamed identities — `@ZoneRow_<id>@N` — because `queue_free()` defers the actual removal to the next process-frame, and Godot's `add_child` collision-avoidance renames the new node when a sibling with the same name still exists in the tree.

**Root cause.** `queue_free()` does NOT remove the node from its parent immediately. It schedules the node for destruction at the next idle frame. Between the `queue_free()` call and the actual removal, the node is STILL a child of the parent — so `add_child(new_node_with_same_name)` collides with the doomed-but-still-attached sibling. Godot's collision-avoidance kicks in and auto-renames the new node to `@<original_name>@N` (the `@`-prefix convention for engine-assigned names). The panel renders fine because draw order doesn't care about names; tests break because `find_child` lookups are name-keyed.

**False-confidence cliff.** Headless renderer-check tests pass (the visible output is correct), the panel SHIPS, and the lookup-keyed regression tests fail in CI with cryptic null-returns from `find_child`. Author reads "panel renders fine" + "find_child returns null" and reaches for a Playwright-perception explanation when the actual cause is in-frame name collision. Recognize the signature: `find_child("<exact_known_name>", true, false) == null` against a panel that visually renders the row.

**Fix shape — `remove_child` synchronously before `queue_free`.**

```gdscript
# WRONG — queue_free alone leaves the node attached for one frame
for row: Control in _zone_rows:
    if is_instance_valid(row):
        row.queue_free()       # node stays as child until next idle frame
_zone_rows.clear()
# subsequent add_child with same name auto-renames to @ZoneRow_...@N

# RIGHT — detach synchronously, then queue for destruction
for row: Control in _zone_rows:
    if is_instance_valid(row):
        if row.get_parent() != null:
            row.get_parent().remove_child(row)
        row.queue_free()
_zone_rows.clear()
# add_child with same name now succeeds — sibling name is free
```

`remove_child(child)` returns synchronously and detaches `child` from the parent's child list immediately; `child.queue_free()` then schedules destruction of the detached node. The name is freed the instant `remove_child` returns, so the subsequent `add_child(new_child)` with the same name has no collision.

**Scope — affects both GUT lookup-keyed tests AND Playwright trace-line tests that read child names.** GUT `find_child` and Playwright `[combat-trace]` lines that interpolate child node-names both fail silently on the auto-rename. The visible draw output is correct, so no human-soak surface catches it; the failure mode is test-layer-only.

**Apply when.** Any UI rebuild path that:
- Iterates children for tear-down with `queue_free()` only
- Then immediately `add_child()`s replacement nodes with the SAME names in the SAME frame
- Is consumed by tests that lookup children by name (`find_child`, `get_node`, name-pattern asserts)

The fix is mechanical and always-safe: pair every `queue_free()` of a soon-to-be-replaced child with a synchronous `remove_child()` before it. Treat as a per-tear-down-block invariant.

**Cite shape.** PR #362 (Devon's world-map UI minimal, ticket `86c9y10fv`, respin SHA `a8eae88`) at `scripts/ui/WorldMapPanel.gd::_render_stratum_list` and `::_render_zone_list`. Both functions originally shipped with `queue_free`-only; Tess QA iterations 2 + 3 surfaced the `find_child` regression with cryptic null-returns; Devon's respin paired each `queue_free` with a synchronous `remove_child` first. *Note: file lives on PR #362's branch (`devon/w2-t5-world-map-ui-minimal`) at this writing; lands on main at the same path post-merge.*

## Playwright specs must exercise user-input paths, not just render-when-instantiated (PR #362 Sponsor-soak regression)

**The trap.** A Playwright spec that boots the panel directly (via debug entry-point / autoload / scene-instance) and asserts the panel renders correctly is a **render-when-instantiated** test — it verifies "if the panel opens, it looks right." Such a spec passes even if **nothing in production actually opens the panel**. When a user-facing button is the canonical production entry point, a render-only spec cannot catch a missing / broken / disconnected signal handler on that button.

**Empirical case — PR #362 → 2026-05-24 Sponsor soak.** Devon's W2-T5 World-Map UI (PR #362, merged `3af355e`, ticket `86c9y10fv`) shipped with:

- `tests/playwright/specs/world-map-panel-render.spec.ts` — verified panel renders correctly when instantiated. GREEN.
- `tests/test_world_map_panel_renders_stratum_list.gd` — GUT spec verified panel-when-mocked. GREEN.
- `tests/test_world_map_panel_geometry_glyphs_no_unicode.gd` — geometry-marker regression-guard. GREEN.

All three specs passed; CI green on all 3 lanes; Tess APPROVED. Ticket flipped `ready for qa test`. Sponsor pulled the release-build artifact for `0ae625c`, played to the descent screen, clicked the "Open Map" button on `DescendScreen` — and **nothing happened**. The soak log (run page `26358134724`, build SHA `0ae625c`) shows ZERO trace lines from any click handler, `WorldMapPanel.open`, or `DescendScreen._on_open_map_pressed`; only the open-game-world `[combat-trace] CameraDirector.state / Player.pos / Player.coll_diag` heartbeat ticking behind the descent-screen overlay.

Empirical conclusion: the Open Map button's `pressed` signal was **either unconnected, connected to an empty handler, or silently no-op**. Render-only Playwright + GUT coverage missed it because none of the three specs exercised the BUTTON-CLICK → panel-open path end-to-end.

**Rule — for any UI surface gated by user input (button press, hotkey, menu item, drag-drop):**

The Playwright spec MUST simulate the actual user input and assert the side-effect, not just verify the panel renders correctly when externally instantiated. Two specs are NOT redundant — they cover orthogonal failure modes:

1. **Render-when-instantiated spec** — boots the panel via test entry-point, asserts visual primitives (no Polygon2D, no Unicode glyphs, correct PANEL_LAYER, etc.). Catches the panel-implementation defects.
2. **User-input-path spec** — drives the game to the surface that gates the panel (descent screen / inventory key / menu), simulates the input (`page.click('button:has-text("Open Map")')`), then asserts the panel-open side-effect fires (panel visible, side-effect trace line emitted, expected layout). Catches the wiring defects.

**Detection signature.** A render-only spec passing while the production user-input path is broken produces a specific failure mode: tests green, CI green, Tess approves on mechanical correctness, **but Sponsor's first soak surfaces "nothing happens when I click X."** When a Playwright spec for a UI panel exists but its name is `*-render.spec.ts` (rendering only), pair-check that a `*-click.spec.ts` OR `*-flow.spec.ts` (user-input path) also exists for any button / hotkey / menu entry that opens it in production.

**For the orchestrator (review-time discipline).** When reviewing a PR that adds a user-facing button / hotkey, grep the PR diff for two patterns: (a) a click-handler or signal-connect site, AND (b) a Playwright spec that simulates the user input. If only one exists, request the other before merge. Devon's PR #362 had (a) — but (a) was broken — and was missing (b) entirely; this is the gap class.

**Test-author defensive layer (suggested addition).** A trace emit in every click handler — `[combat-trace] DescendScreen._on_open_map_pressed | <state>` — makes the failure debugger-visible: empty trace on Sponsor soak immediately localizes the bug to the click-handler layer, not the panel-render layer. Future Sponsor-soak logs become diagnostic.

**Cite shape.** PR #362 (Devon's W2-T5 World-Map UI, merged commit `3af355e`, ticket `86c9y10fv`). Sponsor's 2026-05-24 soak log on artifact `https://github.com/TSandvaer/RandomGame/actions/runs/26358134724/artifacts/7184200637` (build SHA `0ae625c`) is the empirical evidence. The fix PR is in flight at this writing under branch `devon/w2-t5-open-map-button-fix` and will add (i) the wiring fix on `scripts/screens/DescendScreen.gd`, (ii) the trace emit on the click handler, AND (iii) the user-input-path Playwright spec that pins the regression structurally.

## Spike-class specs — diag-build-gated activation pattern (PR #314 finding)

**Context.** M3 Tier 3 W1 (PR #314, commit `e695bd9`) shipped a continuous-scroll camera spike that lives in `scenes/spike/CameraScrollSpike.tscn` — a hand-stitched 3-chunk test scene, NOT a feature of the production play loop. The matching Playwright spec `tests/playwright/specs/camera-scroll-spike.spec.ts` lives in `tests/playwright/specs/` (auto-discovered by Playwright) and runs on every CI Playwright lane, but it must NOT fail against the production artifact where `run/main_scene = Main.tscn`. The diag-build pattern (per `html5-export.md` § "Diagnostic-build pattern") flips the spike to active only on a transient `diag/*` branch with `project.godot::run/main_scene` swapped to the spike scene.

**The two-step engage pattern.** Race the spike's boot line against the production boot line; skip cleanly if production wins.

```typescript
const SPIKE_BOOT_REGEX = /\[CameraScrollSpike\] ready/;
const MAIN_BOOT_REGEX = /\[Main\] M1 play-loop ready/;

await Promise.race([
  capture.waitForLine(SPIKE_BOOT_REGEX, BOOT_TIMEOUT_MS),
  capture.waitForLine(MAIN_BOOT_REGEX, BOOT_TIMEOUT_MS),
]);

const spikeBootLine = capture.getLines().find((l) => SPIKE_BOOT_REGEX.test(l.text));

test.skip(
  spikeBootLine === undefined,
  "Production artifact (Main.tscn) loaded — spike scene not active. " +
    "To activate: see file header for the diag-build workflow."
);

// ... spike-only assertions below ...
```

**Why race-then-skip rather than a static `test.describe.skip`:** the spec needs to determine activation **at runtime by reading the boot console**, not from a static config. A static skip flag would require diag-build authors to also flip a spec-side switch (drift risk). The race pattern is self-configuring — flip `run/main_scene` in `project.godot`, the spec auto-activates against the resulting artifact. Production runs see `[Main] M1 play-loop ready` first, `spikeBootLine === undefined`, `test.skip(...)` fires → 1 skipped, 0 failed.

**What this pattern PROVES (when active):**

- Spike scene boots without `USER WARNING:` / `USER ERROR:` (universal warning gate still on per test-base.ts fixture).
- `[combat-trace]` trace lines fire confirming API invocation (e.g. `CameraDirector.follow_target | target=PlayerMarker deadzone=(40,24)`).
- No physics-flush panic from new mutation paths (per `godot-physics-flush-area2d-rule`).
- BuildInfo SHA still emits (overall boot chain intact).

**What it does NOT cover:** human-perception assertions (chunk-seam z-index, tile gaps, HUD anchoring during scroll). Per the `Playwright headless ≠ real-browser perception` section above, those require Sponsor / author interactive soak via the diag-build workflow. Trace + config verification is the spec's job; visibility-of-effect is the soak's job.

**Apply this shape whenever** a Playwright spec targets a non-production scene only reachable via the diag-build pattern. Examples: future room-boundary spikes, isolated boss-test scenes, perf-stress spikes. The cite-of-record is PR #314 commit `e695bd9` + `tests/playwright/specs/camera-scroll-spike.spec.ts:80-110` (the activation race + skip block).

## Forward-compat spike specs + spike-spec inventory

### Forward-compat property — spike specs activate without rewrite when production wiring lands

A spike-class spec authored using the race-then-skip pattern (§ above) is inherently **forward-compatible with production wiring**. When the production play loop is later updated to invoke the spike feature (e.g. `Main._load_room_at_index → assemble_floor → set_world_bounds`), the same spec auto-activates against the production artifact **without any spec rewrite**.

**Mechanism.** The race tests for the spike scene's boot line vs the production `[Main]` boot line. Once the production play loop emits the feature's trace lines alongside `[Main] M1 play-loop ready`, the race resolves to production boot first, but the subsequent trace-assertion block matches against the feature's trace lines from the production context. The spec body asserts the feature in production without branching or conditional test logic.

**Design rule for spike spec authors:**

1. Boot-race + skip (standard pattern — see § above) handles the "wrong artifact" case.
2. Within the active path, gate additional assertion blocks on a **production-wiring sentinel** (a distinct console line that only fires when the feature is live in the prod play loop — e.g. `[FloorAssembler] assemble_floor | zone_id=s1_z1`).
3. Against the diag artifact, the production-wiring sentinel is absent → run the spike-proof assertions. Against a future prod artifact, the sentinel fires → run the full production assertion set.

Write the spec body to assert the feature's observable trace lines (not the spike scene's private state). If the trace lines are identical whether the feature runs from the spike scene or the production play loop, the spec needs no changes when production wiring lands.

### Spike-spec inventory (W2, 2026-05-23)

Live diag-build-gated spike-class specs in `tests/playwright/specs/`:

| Spec | Feature | Paired `diag/*` branch | Shipped via | Status |
|---|---|---|---|---|
| `camera-scroll-spike.spec.ts` | W1 continuous-scroll camera spike | `diag/camera-scroll-spike-soak` | PR #314 | Merged |
| `procgen-spike.spec.ts` | W1 FloorAssembler proof | `diag/procgen-spike-soak` | PR #328 | Merged |
| `m3-procgen-determinism.spec.ts` | W2 S1 retrofit + ZoneDef expansion (AC-C5-{1,2,3,7}) | `diag/procgen-spike-soak` | PR #344 | Merged (`ed8ae26`) |

**Update policy:** when a new spike-class spec merges, add a row. Include the paired diag branch so the pairing is explicit.

### Do NOT prune "always-skipping" spike specs

As spike specs accumulate, a future tooling pass or refactor agent may flag them as "dead specs" (always-skip against production, never-assert) and propose removal. **Do NOT prune spike-class specs.** Each is the activation harness for its spike feature's eventual production wiring — removing it means the production wiring would ship without its Playwright test layer until someone re-authors the spec. The "always-skipping" behavior is expected and correct; it is the production-safety posture for an unactivated spike, not evidence the spec is dead.

**How to distinguish dead specs from spike-class specs:** a dead spec has no boot-race skip block and fails consistently or is `test.describe.skip`-flagged statically; a spike-class spec has an explicit `test.skip(spikeBootLine === undefined, ...)` and produces clean skips against production. Any spec matching the race-then-skip pattern is a spike-class spec — treat as load-bearing until the spike is either promoted to production (spec activates automatically) or the spike is formally retired (then the spec may be deleted).

## Source-scan structural pins — code-ordering invariants no behavioural test can pin (PR #323 finding)

**The trap.** Some invariants are about **code ordering inside a single function**, not about externally-observable behaviour. Example from PR #323: the gate-check `if _modal_is_active(): return` in `Player._process_grounded` must sit AFTER the velocity-write (`velocity = input_dir * speed`) but BEFORE the attack/dodge input-polls. A future refactor moving the gate above the velocity-write would break movement-while-modal-open without breaking ANY behavioural test — bare-instanced GUT tests can't synthesise `Input.is_action_*` global state in Godot 4 GDScript, so they can't directly observe the input-polling output.

**The pattern — read the source file and assert positional relationships.**

```gdscript
const PLAYER_SOURCE_PATH := "res://scripts/Player.gd"

func test_movement_input_not_gated_by_inventory() -> void:
    var source := FileAccess.get_file_as_string(PLAYER_SOURCE_PATH)
    assert_gt(source.length(), 0, "Player.gd readable as resource")

    var velocity_pos := source.find("velocity = input_dir * speed")
    var gate_pos := source.find("if _modal_is_active():\n\t\treturn")

    assert_gt(velocity_pos, -1, "velocity-write line present")
    assert_gt(gate_pos, -1, "modal-gate line present")
    assert_lt(velocity_pos, gate_pos,
        "velocity-write must precede modal-gate (movement not gated by modals)")
```

**Why this isn't fragile.** The needle strings are full-line idioms unique to the file. A whitespace-only refactor (single-line → wrapped) breaks the find, but produces a LOUD assertion failure ("velocity-write line present"), not a silent miss. A semantic refactor that legitimately reshapes the function must update the pin in the same PR — surfacing the invariant for re-review.

**Why this isn't a code-style pin.** The assertion does NOT check formatting, brace style, or comment presence. It checks **the relative position of two semantic load-bearing lines** — a contract no `assert_eq(behaviour, expected)` can express because the failure mode (modal-open suppresses movement) requires player input the test environment cannot synthesise.

**Apply this pattern when:**

- An ordering invariant exists between two statements inside one function.
- No behavioural shim is available to assert the invariant directly (Godot 4 GDScript can't stub `Input.is_action_pressed`, can't intercept input-poll return values, can't stub the global engine input state).
- A refactor reshaping the function would be load-bearing — silent reversal would be a real regression.

**Cite shape.** PR #323 introduced this pattern in `tests/test_player_modal_input_gate.gd:194` (commit `2779647`, ticket `86c9xxg0n`). The same shape can pin any "this line must come before / after that line" invariant — `Mob._die` cleanup ordering, save-migration step ordering, resource-load-vs-init ordering. Use sparingly; behavioural tests remain the default. Source-scan pins exist for invariants the behavioural surface cannot reach.

### Additional exemplar — autoload state lifecycle across signal-handler boundaries (PR #347 / W2-T2)

A sibling source-scan pin from PR #347 (`tests/test_quest_action_listener_reads_branch_key_before_close.gd`) enforces a different invariant class: **state lifecycle across signal-handler boundaries**. The `QuestActionRouter` listener autoload must snapshot `DialogueController.current_branch_key()` synchronously BEFORE `DialogueController.close()` clears the controller's state. If a refactor moves the snapshot AFTER the close, the read returns empty string — silently breaking any downstream quest-state logic that depends on the branch key.

The pin source-scans `QuestActionRouter.gd` and asserts:

- The autoload's `_action_branch_key` field exists (snapshot location is autoload state, NOT controller state — so it survives both controller navigation and `close()`).
- The snapshot read site precedes the `close()` call site within the listener's signal handler.

The complementary half of the invariant — that `DialogueController.current_branch_key()` actually exists as a callable surface — is checked via **runtime introspection** (autoload-instance `has_method(...)` lookup), NOT source-scan. This is the hybrid shape worth naming explicitly.

**Why this differs from the PR #323 pattern.** PR #323 pins one-function relative ordering (two lines inside `Player._process_grounded`) — pure source-scan. This W2-T2 pin is a **hybrid**: one file source-scanned (the autoload — `FileAccess.get_file_as_string` + `.find` + `assert_lt`) AND the cross-autoload surface checked via runtime introspection (`autoload.has_method("current_branch_key")`). **Apply this hybrid variant whenever a signal-handler's correctness depends on temporally-ordered reads/writes against a different autoload's API** — the source-scan side pins the read-order invariant inside the observer; the introspection side pins that the observed surface still exists. Controllers that emit `<thing>_closed` signals AND clear state in the same call are the most common shape.

**Cite shape.** PR #347 introduced this pattern in `tests/test_quest_action_listener_reads_branch_key_before_close.gd` (merge commit `12916d9`, ticket `86c9y0zyv`). The pattern was flagged as a new exemplar in Devon's W2-T2 dispatch final report.

## Cross-references

- `team/TESTING_BAR.md` — Definition-of-Done, visual-primitive tiers, role-specific obligations
- `team/tess-qa/playwright-harness-design.md` — full Playwright harness design + spec authoring conventions
- `team/tess-qa/m2-acceptance-plan-week-3.md` — W3 acceptance plan, including the migration ticket scope
- `.claude/docs/combat-architecture.md` — combat-side testing patterns (hit-flash modulate, death tween, `[combat-trace]` shim)
- `.claude/docs/html5-export.md` — HTML5-specific failure modes that the Playwright surface is positioned to catch
- ClickUp `#86c9uf0mm` — the universal-warning gate ticket (Half A + Half B)
- PR #217 — Tess's Playwright Phase 1 scaffold (merged)

## Playwright-spec orphan-ref class — GUT test-name drift (PR #280)

**What it is.** A Playwright spec that references a GUT `test_*` function name as a string literal (in `waitForConsole` / `expect_trace` patterns or in coverage-asserting comments) becomes an orphan when the GUT test is renamed or deleted. No CI failure at the drift point — the spec passes silently against a non-existent test name.

**Two root causes observed in PR #280:**

1. **Rename drift** — a GUT test is legitimately deleted during a fix (e.g. `test_sprite_rotation_updates_when_present` removed in PR #274 fix #2 commit `d22a87f`); the Playwright spec referencing it was not updated in the same PR.
2. **Author-typo orphan** — `test_room_gate_3mob_concurrent_death_unlock` (never existed); the real GUT function is `test_3mob_concurrent_death_with_death_wait_unlocks` in `tests/test_room_gate.gd:244`.

Both cause the same silent-failure class: the Playwright spec asserts coverage that doesn't exist.

**Structural lint opportunity (not yet implemented, tooling backlog):** a CI lint that greps every `test_*` token in `tests/playwright/specs/**/*.ts` and cross-checks against the GUT test catalogue (output of `godot --headless --path . -s addons/gut/gut_cmdln.gd --list-tests`) would catch both causes structurally at PR time.

**Author checklist until lint lands:**

1. When adding a Playwright spec comment or assertion referencing a GUT `test_*` function, copy the name **character-for-character** from the `.gd` file (never from memory).
2. Grep the repo (`grep -r "<name>" tests/`) to confirm the test exists before merging.
3. After any GUT test rename or deletion, grep `tests/playwright/specs/` for the old name in the same PR.
