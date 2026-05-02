# Process incidents

Append-only log of process slips that did not produce defects but warrant a note for future agents and protocol-clarity passes. New entries go at the bottom. Don't revert work for a process slip if the artifact is sound — file here and (if pattern repeats) escalate to Priya / orchestrator for protocol clarification.

Format per entry:

```
## YYYY-MM-DD — <one-line title>
- Filed by: <role> (run NNN)
- Severity: low | medium | high
- Repeat?: first / Nth occurrence
- What happened: <2-4 sentences>
- Why it didn't cause a defect: <1-2 sentences>
- Protocol clarification (if any): <quote + suggested edit>
- Action taken: <log only / clarification PR filed / Priya escalation>
```

---

## 2026-05-02 — Devon run-008 self-merged PR #76 under a wide reading of `chore(ci)` exemption

- Filed by: Tess (run 017)
- Severity: low
- Repeat?: first occurrence (logged for future pattern-watch)
- What happened: Devon run-008 opened and self-merged PR #76 (`chore(ci): hardening pass — concurrency, .godot cache, GUT retry, failure artifacts`) reading `team/GIT_PROTOCOL.md` line 54 as a self-merge license. The PR landed clean and the work is sound — concurrency block, `.godot/` cache, GUT clone retry-with-backoff (bounded 3 attempts, 5s/15s), failure-only artifact upload with 7-day retention all verified post-hoc on `main`. Squash commit `d9dba48`.
- Why it didn't cause a defect: PR #76's CI hardening is correct and CI on `main` stayed green through and after the merge. The follow-up PR #78 (Devon run-009) was routed through Tess per the corrected reading.
- Protocol clarification: `team/GIT_PROTOCOL.md` line 54 currently reads `Pure docs / chore(repo|ci|build) / design(spec) PRs — Tess sign-off is **not** required. The orchestrator (or Priya for chore(triage) / docs(team)) may merge directly.` This grants exemption FROM Tess sign-off, not a self-merge license — the merge authority is "the orchestrator (or Priya...)", not the originating dev. Suggested edit: tighten line 54 to make merge authority explicit, e.g. `Tess sign-off is not required, but the merging identity must still be the orchestrator (or Priya for chore(triage) / docs(team)). Devs do not self-merge their own PRs in any category.`
- Action taken: log only. PR #76's work stands. If a second self-merge incident lands, escalate to Priya for a `docs(team): clarify chore(ci) merge authority` PR against `GIT_PROTOCOL.md`.
