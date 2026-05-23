# Playwright Chronic Main-Baseline Triage (ticket `86c9y7ymm`)

**Owner:** Tess (QA) | **Status:** Initial dispatch — Part A (enumeration) + Part B (classification) + Part C (initial round) complete. Part D (main-green verification) tracked under this ticket; iterative bucket-a un-skip work tracked under sibling ticket `86c9y4hfx`.

## Why this exists

Per memory `main-playwright-chronic-baseline` (2026-05-23): the last 5 main Playwright runs (2026-05-16 → 2026-05-22) all concluded `failure`. Devon's PR #348 rerun-on-same-SHA passed (definitive flake per memory `flake-vs-regression-triage`). Structural noise floor distorts every PR's merge-gate. This doc enumerates the chronic-failure set, classifies each entry, and tracks remediation routing.

## Methodology

### Data source

Last 5 main Playwright runs (sourced via `gh run list --workflow=playwright-e2e.yml --branch main --limit 5`):

| Run ID | Date | HEAD SHA | Conclusion |
|---|---|---|---|
| `26294689527` | 2026-05-22 | `615be229` | failure |
| `26187844079` | 2026-05-20 | `2435669c` | failure |
| `26099336967` | 2026-05-19 | `33d96910` | failure |
| `25986375819` | 2026-05-17 | `1e0ac257` | failure |
| `25959887237` | 2026-05-16 | `fcc7d135` | failure |

### Bisect-by-`N failed` discipline

Per `.claude/docs/test-conventions.md` § "Special handling for `test.fail()` glyphs" + memory `triage-from-authoritative-summary-not-display`, **the `✘` glyph in `gh run view --log` output is NOT a reliable signal**. Playwright renders `test.fail()` blocks that throw a placeholder error as `✘ [<spec>]`, but the run summary's `N failed` line counts them as PASS (fail-as-expected).

Authoritative metric: the trailing `N failed` line in the test runner summary, cross-referenced against `test-failed-1.png`-only entries (NOT `-retry1.png`, which represents retry-pass-on-second-attempt = flake, not failure).

### Run summary tally (authoritative)

| Run | Failed | Skipped | Passed | Real failed specs |
|---|---|---|---|---|
| `26294689527` (5-22) | **4** | 5 | 36 | pr291-aftershock, pr291-slam-diag, pr300-wake, t16-cinematic |
| `26187844079` (5-20) | **1** | 5 | 33 | equip-flow Phase 2.5 |
| `26099336967` (5-19) | **1** | 5 | 30 | equip-flow Phase 2.5 |
| `25986375819` (5-17) | **2** | 5 | 21 | equip-flow Phase 2.5 + (mob-self-engagement Room 02 OR ac2-first-kill — same root cluster) |
| `25959887237` (5-16) | **2** | 5 | 23 | mob-self-engagement Room 02 + soak-narrative (no retry-green that day) |

**Glyph-misread examples surfaced during triage:**
- `ac4-boss-clear.spec.ts:366` — `test.fail()` block; ✘ glyph in every run; counted as PASS by `N failed` in every run.
- `mob-self-engagement.spec.ts:549–637` — 7 × `test.fail()` blocks (Rooms 03-08 + S1 Boss Room); ✘ glyph in every run; counted as PASS.
- `audio-bus-boot-smoke.spec.ts:41` — `test-failed-1.png` present in Runs 1+2 but the retry passed, so the run summary did NOT count it as a failure on those dates (was a flake).

### Chronic-spec threshold

A spec is "chronic" if it appears in the `N failed` count (NOT the `✘` glyph stream, NOT the retry-passed flakes) in ≥3 of the 5 sampled main runs.

## Triage table

### Bucket-b: REGRESSION (real bug under noise floor)

| Spec | Failures | Evidence (run-id × 3+) | Routing |
|---|---|---|---|
| `equip-flow.spec.ts:142` Phase 2.5 LMB-equip | 3/5 | `26187844079`, `26099336967`, `25986375819` — all show same error: `Phase 2.5 LMB-equip dual-surface assertion: post-equip damage=1 (expected 6). If <2 (fistless), Player._equipped_weapon is null — the LMB-click path mutated Inventory but skipped Player. P0 86c9q96m8 regression class.` | New ticket `86c9y8fqw` — route to Drew (Player._equipped_weapon writeback in `Inventory._handle_equip_lmb_click`) |

**Why bucket-b not bucket-a:** the failure message is deterministic, identical across 3 runs, and explicitly cites P0 `86c9q96m8` regression class (a closed game-side ticket). This is the SAME bug the spec was authored to catch resurfacing — the spec is healthy, the game-side equip-flow is regressed. Remediation = file fix ticket, NOT skip the spec.

### Bucket-a: FLAKE (already-quarantined ahead of this dispatch)

All 6 specs below were quarantined via `test.skip` in PR #330 (merge commit `9c32956`, ticket `86c9y4hfx`) one day before this triage dispatch. They are listed for completeness and to document that the bucket-a remediation surface for this triage round is ALREADY EXECUTED.

| Spec | Failures (raw `✘`) | Real failures (post-bisect) | Quarantine cite | Re-enable gate |
|---|---|---|---|---|
| `pr291-aftershock-visual.spec.ts:33` | 1/5 (Run1 only) | 1/5 | PR #330 (`9c32956`), spec file line 32 | Headless boss-wake state-machine determinism OR URL-param activation trigger |
| `pr291-boss-slam-diag.spec.ts:28` | 1/5 (Run1) | 1/5 | PR #330 (`9c32956`), spec file line 27 | Same as pr291-aftershock |
| `pr300-wake-anim-visual.spec.ts:49` | 1/5 (Run1) | 1/5 | PR #330 (`9c32956`), spec file line 48 | Same class — boss-wake IDLE-state determinism |
| `t16-cinematic-climax.spec.ts:42` | 1/5 (Run1) | 1/5 | PR #330 (`9c32956`), spec file line 41 | Identify warning source, route through `WarningBus.warn` or add `expectedUserWarnings` allow-list |
| `audio-bus-boot-smoke.spec.ts:41` | 2/5 (Runs 1+2) | 0/5 — flake passes on retry | PR #330 (`9c32956`), spec file line 40 | AudioContext race determinism investigation |
| `soak-narrative-regression.spec.ts:268` | 5/5 (all runs) | 1/5 (Runs 4+5 only — Run4 retry passed, Run5 retry failed) | PR #330 (`9c32956`), spec file line 267 | Room 02 boot determinism (spawn timing, walk duration) |

**Per skip-discipline gate (this triage ticket `86c9y7ymm`):** every quarantine in PR #330 already cites ticket `86c9y4hfx` and references the N≥8 re-enable contract. No additional skip-block PR is required from this dispatch — the bucket-a remediation surface is already covered.

### Bucket-c: GENUINE MAIN BREAKAGE (high-impact)

**None identified.** No spec in the 5-run sample exhibits the bucket-c signature (sudden regression, P0 production-blocking class, broad surface impact). The equip-flow Phase 2.5 failure is P0-class in surface but is contained (single spec, single path, well-isolated by the spec's own assertion shape). Routed as bucket-b.

### Sub-chronic (≥2 but <3 of 5) — noted for next-dispatch surveillance

| Spec | Failures | Notes |
|---|---|---|
| `mob-self-engagement.spec.ts:284/291` Room 02 (real failure, NOT the `test.fail()` blocks at 549+) | 2/5 (Runs 4+5) | Currently `test()` (not `.fail()`). The Sponsor manual-play note (line 288) says Room 02 engages correctly — recurring failure here would be a regression. Trend across the most-recent 5 runs after the PR #330 quarantine settles is the right next-dispatch read. **Surveillance ticket NOT filed** (sub-chronic threshold). |
| `ac2-first-kill.spec.ts`, `ac3-death-persistence.spec.ts`, `negative-assertion-sweep.spec.ts` Test 2, `room-gate-body-entered-regression.spec.ts`, `room-traversal-smoke.spec.ts` | 1/5 each (all Run4 cluster) | These all failed in Run4 (`25986375819` on `1e0ac257`) but not in adjacent runs — looks like a same-SHA timing-class cluster on that specific build. **Not chronic.** Pre-PR-#212 (return-to-spawn harness fix) era; later runs greened them. |

## Part C: this dispatch's deliverable

| Action | Status | Cite |
|---|---|---|
| Triage doc enumeration (this file) | DONE | `tests/playwright/CHRONIC_BASELINE_TRIAGE.md` |
| Classification (a/b/c) | DONE | This file's triage table |
| Bucket-a skip-block PR | **N/A — already executed via PR #330** | Merge commit `9c32956` (ticket `86c9y4hfx`) |
| Bucket-b/c child tickets | Filed via ClickUp (1 ticket — equip-flow regression `86c9y8fqw`) | See "Bucket-b" row above |

## Part D: main-green verification (deferred to follow-up dispatches)

The N≥8 re-enable contract per ticket `86c9y4hfx` governs un-skip + verify cycles for the 6 already-quarantined specs. This triage ticket (`86c9y7ymm`) closes when:

1. The bucket-b equip-flow regression ticket (`86c9y8fqw`) is fixed AND main Playwright shows equip-flow green across N≥8 main-trigger Playwright runs.
2. The 6 bucket-a quarantined specs land back to `test()` via `86c9y4hfx` re-enable PRs (out-of-scope for this ticket — sibling).
3. 5 consecutive main Playwright runs conclude `success` (NOT `failure`) — the structural verification that the noise floor has been cleared.

Per `.claude/docs/test-conventions.md` § "Manual SHA-pin sequence", main Playwright is NOT auto-triggered on main pushes — verification requires manual `gh workflow run release-github.yml --ref main` to fire the release-build → `workflow_run` → Playwright chain.

## Methodology cite-of-record

This triage applied the techniques codified in `.claude/docs/test-conventions.md`:

- § "Playwright e2e CI auto-triggers on every PR — but author + orchestrator must still verify" (PR #299 corrected stale convention).
- § "Control-comparison technique" (PR #317 finding) — disambiguates pre-existing vs new across stale-base PRs.
- § "Special handling for `test.fail()` glyphs" — bisect by `N failed` summary, NOT by `✘` glyph count.
- Memory `flake-vs-regression-triage` — rerun-same-SHA validation (Devon's PR #348 precedent).
- Memory `triage-from-authoritative-summary-not-display` — Playwright `✘` glyph trap.
- Memory `main-playwright-chronic-baseline` — the chronic-baseline finding this ticket addresses.

## Cross-references

- **Sibling ticket `86c9y4hfx`** — owns the iterative bucket-a un-skip + N≥8 re-enable verification for the 6 quarantined specs.
- **New ticket `86c9y8fqw`** — owns the bucket-b equip-flow Phase 2.5 P0 regression.
- `tests/playwright/README.md` § "Quarantined specs" — quarantine table (mirror of this doc's bucket-a section).
- PR #330 (`9c32956`) — the quarantine landing PR that anticipated 4 of the 6 bucket-a specs documented here.
- PR #348 — the flake-vs-regression-triage precedent (rerun-same-SHA passed = definitive flake).

## Append-only update log

| Date | Update | Cite |
|---|---|---|
| 2026-05-24 | Initial triage authored (Tess, ticket `86c9y7ymm`) | This PR |
