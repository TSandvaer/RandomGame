## Summary

Bundled PR: retro on PR #327 (the W2 pre-shape post-W1 audit pass) + codification of the new `per-class-retro-trigger-convention` (locked this session) into `team/ROLES.md`. **First firing** of the convention — this PR is itself a process-incident-class trigger (orch-docs / convention codification), and the convention dispatched Priya for the retro at PR #327's merge-pair moment.

## Two artifacts

1. **`team/priya-pl/pr-327-w2-pre-shape-retro.md`** (NEW) — structured-digest retro on PR #327 per `retrospective-reporting-convention` memory.
2. **`team/ROLES.md`** (subsection added) — codifies the four retro-trigger classes + retro report shape so future readers can find the source-of-truth without grepping memory entries.

## Retro highlights — PR #327 W2 pre-shape pass

**Grade: B.** Honest middle. The pre-shape pass itself was correct and dispatch-ready (5/7 keep-as-is verdict survived the audit; 2/7 amend was already paper-shaped in v1.2 §5.1; 0/7 net-new). Calendar honesty held. **Where the grade slips below A:** ClickUp MCP disconnected mid-dispatch, so the W2-T2 + W2-T4 ticket-body audit could only be paper-shaped, not actually applied via `clickup_update_task`. Audit is COMPLETE-IN-PAPER and INCOMPLETE-IN-ACT.

**Sharpest patterns:**

1. **ClickUp MCP disconnect — three-occurrence pattern this session.** Devon hit it (procgen Part A dispatch); orch hit it (auto-status pulse showed stale board); Priya hit it (this dispatch — could not run `clickup_update_task` on W2-T2 + W2-T4). Three-in-one-session is a pattern, not a transient blip. **Decision-surface item for Sponsor.**
2. **Resume from prior-session WIP was clean.** Worktree had uncommitted v1.3 amendment draft from prior session; no manual recovery needed. The amendment-block convention (v1.0 → v1.1 → v1.2 → v1.3 stacked) absorbed the new lift naturally.
3. **W1 ticket audit verdict held without surprises.** 5 keep-as-is / 2 amend / 0 new is exactly the verdict shape a well-formed pre-shape pass should produce when the prior author did their job. The 2 amend items were Drew-nit routings I had already paper-shaped in v1.2 §5.1 — meaning v1.2's discipline of routing nits inline (vs. queueing for a separate ticket) paid off.

**Hypothesis-verdict:** 4/5 v1.1 predictions held. The miss was "Tess scaffold lands Day-1 W1" — Tess single-tenancy under in-flight QA was under-budgeted. Mitigation: future Day-1 dispatch briefs targeting Tess should explicitly check Tess in-flight QA state.

**Mitigations:**
1. MCP-disconnect detection at session-start (recommend orchestrator pings each MCP server at session-start; fail-fast > fail-mid-dispatch).
2. Promote v1.3 + v1.2 amendments to "current shape" summary at end-of-W2 (consolidate at SI-8 lock moment).
3. Tess scaffold dispatch checks in-flight QA state at brief-time.
4. W1 mid-retro checklist additions (Tess scaffold status + PixelLab batch wave 1 visibility).
5. `per-class-retro-trigger-convention` codification (this PR).

**Cadence:** W3 pre-shape happens at W2 mid-retro (NOT W2 end). Rationale + bundling shape in retro §6.

**Bundled meta-retro flag:** session has fired 5+ retro triggers (PR #314 spike, PR #315 wave-completion, PR #316 process-incident, PR #319 spike, PR #323 multi-iteration, PR #325 process-incident, PR #326 process-incident, PR #327 process-incident). Per the codified convention, this warrants a single-paragraph bundled meta-retro in the session-save state file at save-session time — NOT a separate dispatch. The MCP-disconnect three-occurrence pattern is exactly the cross-cutting finding individual retros could not have surfaced alone.

## `team/ROLES.md` diff summary

Added two sections after the existing "ClickUp board" / "Naming convention" content:

### Priya — Project Leader responsibilities

Captures Priya's standing responsibilities: backlog + ticket authorship, sequencing + scope, risk register, `team/DECISIONS.md` weekly batch PR (Mondays — Priya-only), retros.

### Retro authorship triggers

Codifies the four trigger classes verbatim from the new memory entry:

1. Wave-completion PR (closes W1/W2/W3)
2. Spike PR (`spike(...)` prefix or `spike` ticket-tag)
3. Process-incident PR (orch-hooks / orch-docs / convention / hook / skill changes)
4. Multi-iteration PR (≥3 reviewer round-trips before merge)

Routine impl PRs do NOT trigger retros. Sponsor can ask ad-hoc.

Cross-links the memory entry name verbatim: `per-class-retro-trigger-convention` (locked 2026-05-23, first-firing on PR #327).

## Cross-references

- Memory entry: `per-class-retro-trigger-convention` (locked this session 2026-05-23, first-firing on PR #327)
- Memory entry: `retrospective-reporting-convention` — structured-digest format the retro follows
- Memory entry: `tess-cant-self-qa-peer-review` — softer for retros (this is a self-retro; meta-honesty noted)
- PR #327 — the artifact being retro'd (W2 pre-shape post-W1 audit pass, merged `d5f92eb`)
- PR #315 — predecessor retro (M3 retrospective pass 1, Tier 2 close + Tier 3 W1 in-flight)
- PR #316 — M3 retro mitigations 1+2+3 (tightened-final-report contract amendment)
- `team/priya-pl/post-wave3-sequencing.md` v1.3 amendment — the planning artifact PR #327 landed

## Doc updates

- `team/priya-pl/pr-327-w2-pre-shape-retro.md` (new) — structured-digest retro file
- `team/ROLES.md` (subsection added) — Priya responsibilities + retro-trigger codification

## Blockers

None.

## Decision draft (for next Priya weekly DECISIONS.md batch)

> Decision draft: `per-class-retro-trigger-convention` locked 2026-05-23 — Priya is canonical retro author when ANY of four PR-merge classes fires (wave-completion / spike / process-incident / multi-iteration with ≥3 reviewer round-trips); routine impl PRs do NOT trigger; bundled meta-retro at session-save if 3+ triggers fire in one session. Codified in `team/ROLES.md`; first-firing on PR #327.
