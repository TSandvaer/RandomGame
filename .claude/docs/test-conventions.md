# Test Conventions

What this doc covers: the cross-layer test conventions for Embergrave's two test surfaces — GUT (headless Godot, runs in CI on every push/PR) and Playwright (browser-driven, runs against the HTML5 release-build artifact). Topic-specific tests still live in `team/tess-qa/` (acceptance plans, journey-probe procedure, soak rituals); this doc is the **load-bearing framework conventions** that every test author needs to know.

## Universal warning gate (ticket `86c9uf0mm`)

The Sponsor M2 RC soak meta-finding (2026-05-15) was that **3 of 4 user-visible findings would have been caught by a universal console-warning zero-assertion** — `leather_vest` unknown-id, DirAccess HTML5 recursion warnings, save-schema migration warnings. The fix shipped as a two-surface gate: Playwright Phase 1 (Tess, PR #217 — merged) covers HTML5 console; GUT Half B (Devon, this PR) covers headless engine.

### GUT side — `NoWarningGuard` + `WarningBus`

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

**Workflow shape:**

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
