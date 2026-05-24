# Playwright Chronic Main-Baseline Triage (ticket `86c9y7ymm`)

**Owner:** Tess (QA) | **Status:** Initial dispatch — Part A (enumeration) + Part B (classification) + Part C (initial round) complete. Part D (main-green verification) tracked under this ticket; iterative bucket-a un-skip work tracked under sibling ticket `86c9y4hfx`. Methodology amended 2026-05-24 (fix-stack-stale-sample exclusion + triage anti-patterns + pre-classification checklist); see "Triage anti-patterns" + "Pre-classification triage checklist" sections.

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

### Fix-stack-stale-sample exclusion (load-bearing — amended 2026-05-24 post PR #356)

**Sampling rule:** a spec is classifiable as "chronic regression" (bucket-b) only if it appears in ≥3 of 5 sampled main runs **AND those 3+ runs are all post-most-recent-fix-touching-the-spec**. If the spec's regression-class ticket has a closing PR landed between samples, runs predating that PR must be EXCLUDED from the chronic-classification count.

**Why this rule exists.** The chronic-baseline 5-run sample window is a rolling snapshot, not a "since last fix" cohort. When a fix-stack lands mid-window, the older runs are stale relative to current code — counting them as chronic-failure evidence is a classification-shape error, not a regression. The bucket-b call must be made against runs the current code has had a chance to express in.

**Operationalisation — before filing a bucket-b ticket:**

1. Identify the most recent PR that touches the spec OR the underlying engine surface the spec asserts. `gh pr list --search "<spec-name> OR <engine-symbol>" --state merged --limit 5` is the canonical query shape.
2. Cross-reference the merge timestamp against each sampled run's `createdAt` (via `gh run view <run-id> --json createdAt,headSha`).
3. **Exclude runs that predate the merge.** The chronic-classification count is over post-fix samples only. If post-fix samples < 3, the spec is NOT bucket-b classifiable from this window — it's "below sample threshold; defer to next window."
4. If a sample window straddles a fix-stack and the post-fix runs are GREEN, the spec is GREEN — not bucket-b, not chronic, not regression. The pre-fix failures are historical, not current.

**Sample-size implication.** A 5-run window straddling a fix-stack may produce a too-small post-fix sample. Two correct responses: (a) defer the bucket-b call to the next window (wait for ≥3 post-fix runs to accumulate), OR (b) widen the window to 10 runs so post-fix sample size recovers. Do NOT silently apply the ≥3-of-5 threshold against the mixed sample — that's the misclassification this rule prevents.

## Triage anti-patterns

Two recurring anti-patterns have surfaced during chronic-baseline triage and merge-gate review since this doc's initial dispatch. Both are silent failure modes — the classification reads correct at first glance, but the conclusion is wrong. Cite each in PR review when the shape is observed.

### Anti-pattern 1 — glyph-misread

**Shape:** counting `✘ [<spec>]` glyphs in `gh run view --log` output as the failure tally. Playwright renders `test.fail()` blocks that throw a placeholder error as `✘ [<spec>]`, but the run summary's `N failed` line counts them as PASS (fail-as-expected). Conflating the two surfaces produces a fabricated failure cluster.

**Empirical case.** Morning Tess investigation of P0 `86c9xw8xd` (2026-05-22) produced a "9-failure cluster" framing built from ✘-glyph counts. Devon's later investigation against the `N failed` summary revealed the true `1 failed` count was a different spec entirely. Cost: one dispatch cycle of phantom triage before Devon's `N failed` discipline corrected the framing.

**Correct triage.** Bisect by spec-name from the `N failed` summary line, NOT by counting `✘` glyphs in the text output. See `.claude/docs/test-conventions.md` § "Special handling for `test.fail()` glyphs" + memory `triage-from-authoritative-summary-not-display`. The worked examples in this doc's "Glyph-misread examples surfaced during triage" subsection (run summary tally section above) are the canonical reference shape.

### Anti-pattern 2 — fix-stack-stale-sample

**Shape:** classifying a spec as bucket-b "chronic regression" when ALL sampled failing runs predate a fix-stack that landed mid-sample-window. The ≥3-of-5 threshold reads green on the count, but the count is over stale baseline runs the current code never executed against.

**Empirical case (worked example — PR #356 refutation of bucket-b equip-flow classification).** This triage doc's initial dispatch (2026-05-24) filed ticket `86c9y8fqw` as a bucket-b regression on `equip-flow.spec.ts:142` Phase 2.5 LMB-equip, citing three failing runs:

| Run ID | Date | HEAD SHA | Conclusion |
|---|---|---|---|
| `26187844079` | 2026-05-20 | `2435669c1edb61b19c4d55cd589e53625eb2a6dd` | failure |
| `26099336967` | 2026-05-19 | `33d96910553bf12727e6947bdccacb35ccc7f4d2` | failure |
| `25986375819` | 2026-05-17 | `1e0ac2574fe847875db46a1eb62d6f58e9094e01` | failure |

All three runs predate the 2026-05-22 fix-stack:

- **PR #317** (merge commit `7e122bd2404f8767d21fe4b942ca8d42e3da6745`, merged 2026-05-22T14:37:53Z) — spec-side anchor fix on `Hitbox.hit` search.
- **PR #323** (merge commit `27796472cf6b1d7dd72c5a52c2b0b904adc7f3c1`, merged 2026-05-22T16:01:40Z) — engine-side `Player._modal_is_active()` predicate that suppressed the leaked-fistless attack class at root.

The fifth run in the same window — `26294689527` (2026-05-22, post-fix) — was GREEN on equip-flow. Drew's PR #356 diagnostic refutation (merge commit `532990febc1909a316f74b04f7d3ca83397f4a5d`, 2026-05-23) confirmed via trace-line evidence that the cited runs already showed `damage_after=6` in the `Inventory.equip` trace (proof the dual-surface writeback DID fire) — the spec's `find()` was hitting a spurious fistless-leak `Hitbox.hit` line from a different source.

**The classification miss.** ≥3 of 5 was satisfied by the count, but ALL 3 failing samples were pre-fix-stack stale. The single post-fix run was GREEN. Correct classification under the amended rule above: spec is GREEN; pre-fix runs are historical, not chronic; bucket-b call rescinded.

**Correct triage.** Before filing bucket-b, run the fix-stack exclusion check (see "Fix-stack-stale-sample exclusion" subsection above). If the spec's regression-class ticket has a closing PR mid-window, exclude the pre-PR runs from the count. PR #356 ships a GUT regression-guard (`tests/test_inventory_equip_lmb_click_writes_player.gd`) covering the original P0 invariant — that's the right end-state for a fix-stack-stale-sample finding (close the ticket via regression-guard, NOT via engine-side rework).

## Pre-classification triage checklist

Apply this checklist **before** classifying any spec as bucket-b. Failing any check routes the spec to a different bucket (or defers classification entirely).

1. **Deterministic failure message across samples?** Compare the `Error:` lines / assertion shapes across the cited failing runs. If the messages differ in non-trivial ways (different assertion bound, different element-not-found target, different timing window expired), this is bucket-a flake territory, NOT bucket-b regression. Per `.claude/docs/test-conventions.md` § "Spec-string-vs-engine-emit drift" — a deterministic message is a load-bearing signal for "real bug" vs "timing flake".

2. **Spec's regression-class ticket already closed by a PR landed mid-window?** If yes, exclude pre-PR runs from the chronic count per the fix-stack-stale-sample exclusion rule above. Verify via:
   ```bash
   gh pr list --search "<spec-name> OR <engine-symbol>" --state merged --limit 5
   gh run view <run-id> --json createdAt,headSha   # per-sample timestamp
   gh pr view <pr-num> --json mergeCommit,mergedAt # per-fix-stack timestamp
   ```
   Pre-fix samples are stale; only post-fix samples count toward the ≥3 threshold.

3. **Post-fix sample size ≥3?** If only 1–2 runs are post-fix, defer classification to the next sampling window OR widen the window to 10 runs. Do NOT apply the ≥3-of-5 threshold against a mixed pre/post-fix sample.

4. **Most-recent run conclusion = `success`?** If the latest sampled run is GREEN (regardless of older failures), this is the strongest single signal that the spec is NOT currently regressed. Older failures still warrant investigation (was the spec authored to catch a class of bugs that's now closed by a fix-stack?), but the bucket-b "current regression" call is empirically refuted by the green tail.

5. **Trace evidence supports the hypothesized failure mode?** Pull the trace lines from a failing run. If the failure mode in the spec's assertion can be empirically refuted by trace data already in the log (e.g. the assertion says "Player._equipped_weapon is null" but the `[combat-trace] Inventory.equip | ... damage_after=6` line proves the writeback fired), the hypothesis is wrong even when the assertion fails. Route to spec-authoring fix, NOT engine-side fix. Per memory `diagnostic-traces-before-hypothesized-fixes`.

If checks 1–5 all pass: bucket-b classification is supported; file the regression ticket per the triage table format. If any check fails: route per the matching alternative bucket or defer classification.

## Triage table

### Bucket-b: REGRESSION (real bug under noise floor)

| Spec | Failures | Evidence (run-id × 3+) | Routing |
|---|---|---|---|
| ~~`equip-flow.spec.ts:142` Phase 2.5 LMB-equip~~ **RESCINDED — see fix-stack-stale-sample worked example below** | ~~3/5~~ | ~~`26187844079`, `26099336967`, `25986375819`~~ — all 3 cited runs predate PR #317 + PR #323 (5-22 fix-stack); post-fix run `26294689527` was GREEN | Ticket `86c9y8fqw` reclassified — Drew's PR #356 shipped a GUT regression-guard (`tests/test_inventory_equip_lmb_click_writes_player.gd`); no engine fix warranted |

**Why bucket-b not bucket-a:** ~~the failure message is deterministic, identical across 3 runs, and explicitly cites P0 `86c9q96m8` regression class (a closed game-side ticket). This is the SAME bug the spec was authored to catch resurfacing — the spec is healthy, the game-side equip-flow is regressed. Remediation = file fix ticket, NOT skip the spec.~~

**Bucket-b classification RESCINDED (2026-05-24 amendment).** The original triage applied the ≥3-of-5 threshold without the fix-stack-stale-sample exclusion. All 3 cited failing runs (5-17, 5-19, 5-20) predate the 5-22 fix-stack (PR #317 + PR #323); the single post-fix sample (`26294689527`, 5-22) was GREEN. Drew's PR #356 diagnostic refutation traced the original failure to a spec-side `find()` hit on a spurious leaked-fistless `Hitbox.hit` line — engine-side equip-flow was healthy throughout. **See § "Anti-pattern 2 — fix-stack-stale-sample" below for the full worked example.** This row is preserved (struck-through) to retain the triage history; the fix-stack-stale-sample rule above governs future bucket-b filings.

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
| 2026-05-24 | Methodology amendment — fix-stack-stale-sample exclusion + triage anti-patterns + pre-classification checklist; bucket-b equip-flow classification RESCINDED post Drew's PR #356 refutation (ticket `86c9y7ymm`, branch `tess/triage-methodology-fix-stack-stale-sample`) | This PR |
