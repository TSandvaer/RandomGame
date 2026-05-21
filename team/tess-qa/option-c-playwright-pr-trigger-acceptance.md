# Option C — Playwright auto-trigger on PR — acceptance plan

**Branch:** `tess/playwright-pr-trigger`
**Sponsor decision (2026-05-21):** Option C picked over A (push trigger) and B (manual-kick status quo).
**Predecessor:** PR #293 re-QA flagged the manual-kick gap; this PR closes it.

## What changes

1. `.github/workflows/release-github.yml` — adds `pull_request: branches: [main]` to the existing `workflow_dispatch` + `push: tags` trigger set.
2. `.github/workflows/playwright-e2e.yml` — adds `pull_request: branches: [main]` trigger AND a new `resolve_via_pr_sha` path in the `Resolve artifact run ID + expected SHA` step that polls release-github.yml for a successful run on the PR head SHA.

Existing triggers preserved: `workflow_run` chain (post-release-build on main), `workflow_dispatch` (manual with SHA-pin contract), `push: tags`.

## Expected behaviour on PR open / sync

| Event | release-github.yml | playwright-e2e.yml |
|---|---|---|
| PR opened against `main` | Fires; builds HTML5 artifact `embergrave-html5-<sha>` | Fires; resolve step polls release-github.yml for ≤20 min until its run on the PR head SHA concludes; on success, downloads artifact + runs suite |
| PR synced (new commit pushed) | Fires on new HEAD SHA | Fires on new HEAD SHA; previous in-flight runs may be cancelled by GitHub's PR-replace semantics |
| PR closed without merge | No effect | No effect |
| PR merged to main | `push: branches: main` trigger fires → release-github.yml runs → `workflow_run` chain fires Playwright on main (existing behaviour, unchanged) | (chain via workflow_run unchanged) |

## Manual verification post-merge

Confirm both workflows are registered as PR triggers:

```bash
gh workflow list
# Expect both:
#   Release to GitHub (M1 RC build)   active   <id>
#   Playwright E2E (HTML5 artifact)   active   <id>
```

Open a small no-op PR (e.g. comment edit on a docs file) and confirm:

1. release-github.yml run appears within ~30 s of PR open
2. playwright-e2e.yml run appears within ~30 s of PR open
3. playwright-e2e.yml's resolve step shows `[attempt N/40] release-github.yml status=...` lines while waiting
4. playwright-e2e.yml resolves to the same SHA as release-github.yml's run
5. SHA-pin verification step in playwright-e2e.yml succeeds

## SHA-pin discipline preserved

The new `pull_request` resolution path uses the same downstream:

- `steps.resolve_run.outputs.run_id` + `expected_sha`
- `Verify downloaded artifact carries expected SHA` step
- `actions/github-script` SHA-bound fallback in the wildcard-download branch

If a release-github.yml run for the PR's SHA concludes failure (e.g. export error), the poll detects `status=completed conclusion=failure` and the Playwright job fails fast with a clear error — never runs against a missing or wrong-SHA artifact.

## Polling budget

- Max 40 attempts × 30 s sleep = ~20 min total wait window
- release-github.yml typical wall-time: 3-6 min (cold-cache: up to 10 min on GH runner queue load)
- 20 min budget covers worst-case cold runs + queue wait
- Timeout failure message is itself signal — a release-build that takes >20 min warrants its own investigation

## Cost estimate

~600-1000 GH Actions min/month at the current PR cadence (4-8 PRs/week × ~5-10 min per Playwright run + ~3-6 min per release-build). Fits in the GitHub free-tier 2000-min/month limit on private repos, or near the boundary depending on M3 PR volume.

## Out-of-scope follow-ups

1. **10/10 recent Playwright runs FAILURE** — separate investigation ticket. Flagged in PR body.
2. **`.claude/docs/test-conventions.md` § "Playwright e2e CI does NOT auto-trigger" supersession** — that section partially obsolete post-merge. Update via follow-up doc edit; not in this PR per dispatch brief.
3. **Concurrency cancellation** — release-github.yml has no `concurrency` block today. If PR-sync churn becomes expensive, add `concurrency: group: release-pr-${{ github.ref }}` with `cancel-in-progress: true` (excluding main). Defer until cost-data justifies.

## Path A vs Path B rationale

Chose Path A (explicit `pull_request` triggers on both) over Path B (remove `branches: main` filter from `workflow_run`) because:

- Path B's unfiltered `workflow_run` fires for fork PRs too, which is a token-leak class risk per GitHub's documented `pull_request_target` advisory. Embergrave is currently a private repo with no fork PRs, but Path A keeps the surface explicit.
- Path A's behaviour is greppable from the workflow file alone — Path B requires reading the `workflow_run` semantics + branch-filter rules to predict triggering.
- Path A composes naturally with future per-event customisation (e.g. dropping the GH Release attach step on `pull_request` runs).

Trade-off: Path A is more code (the polling resolve step) than Path B. Polling is ~50 lines of well-commented bash; the explicit SHA-pin discipline carries over without modification.
