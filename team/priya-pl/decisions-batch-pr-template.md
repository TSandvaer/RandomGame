# Decisions Batch-PR Template

Priya opens one PR per week (Mondays) collecting all `Decision draft:` lines from merged PRs since the last batch. This template defines the shape.

## PR title format

```
pm(decisions): weekly batch — YYYY-MM-DD
```

Use the Monday date (the batch date, not individual decision dates).

## PR body format

```markdown
## Decisions batch — YYYY-MM-DD

Collecting `Decision draft:` lines from PRs merged between YYYY-MM-DD and YYYY-MM-DD.

### YYYY-MM-DD

- **<short title>** — <1-3 line decision summary lifted from the draft>
  - Decided by: <role>
  - Why: <load-bearing reason from the draft>
  - Reversibility: <reversible | one-way>
  - Affects: <roles or systems>
  - Source: PR #NNN

<!-- Repeat one block per decision, grouped by the date of the originating PR. -->

## Self-Test

No functional code touched. Diffed all draft lines against source PRs — no fabrication. Confirmed DECISIONS.md header block intact.
```

## Cadence

- **One PR per week, opened on Mondays.**
- If no drafts accumulated during the week, skip — do not open an empty batch PR.
- If an urgent cross-role or Sponsor decision fires mid-week (orchestrator-escalated), it may land via a separate `docs(decisions): urgent — <topic>` PR. It is still Priya or orchestrator only — never another role.

## How to find pending drafts

Run this after each weekly merge window closes (Sunday night / Monday morning):

```bash
# 1. List PRs merged since last Monday (adjust date):
gh search prs --repo TSandvaer/RandomGame --merged --merged-since "YYYY-MM-DD" --json number,title,body --limit 50 > /tmp/merged-prs.json

# 2. Grep for Decision draft lines:
grep -i "Decision draft" /tmp/merged-prs.json

# 3. Or use gh pr list for individual PR bodies:
gh pr view <PR#> --json body -q '.body' | grep -A3 "Decision draft"
```

Alternatively, scan PR comments (decision drafts may appear in the final-report comment, not the PR body):

```bash
gh api repos/TSandvaer/RandomGame/pulls/<PR#>/comments --jq '.[].body' | grep -A3 "Decision draft"
```

Collect all hits. Group by date. Draft the batch entry. Open PR against `main`.

## ClickUp

Pair the batch PR open with a ClickUp status move for the tracking ticket (if one exists for the current batch cycle). Title the ticket: `pm(decisions): weekly batch — YYYY-MM-DD`.
