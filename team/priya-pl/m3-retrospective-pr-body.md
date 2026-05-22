# pm(m3): M3 retrospective pass 1 — Tier 2 closed + Tier 3 W1 in-flight

## Summary

Process retrospective on M3 Tier 2 (~23 merged PRs across Waves 1-3) + M3 Tier 3 W1 in-flight state (PR #312, #314 open). Authored in response to Sponsor directive 2026-05-22: *"I want to introduce retrospective work on the flows (completed tasks) to find out how the agent work can be improved."*

Sponsor flagged two hypothesis classes for the retro to examine:

1. **Test-level requirement is too low → too many bugs reach soak**
2. **ClickUp ticket quality is too vague → agents drift from intent**

Empirically tested both against ~30 PRs + 18 memory entries + 3 prior retros + the process-incident log.

## Verdict

- **Hypothesis 1 (testing-bar) — PARTIALLY TRUE.** The codified bar is strong. The failure mode is **rule-applied-too-generously**, not bar-too-low. PR #291 (7 author iterations; Tess approved twice on GUT+CI green; Sponsor overturned both times) is the empirical anchor.
- **Hypothesis 2 (ticket quality) — MOSTLY FALSE.** Tier 3 W1's 7 tickets dispatched without clarification round-trips. The drift is downstream of dispatch, not upstream from ticket.

## Three patterns surfaced (cite-able)

| Pattern | Cost | Active? | Anchor PRs |
|---|---|---|---|
| **P1** Headless-vs-real-browser perception gap | HIGH (PR #291 = ~12-15 agent-cycles for one polish ticket) | YES | #291, #300, #287 |
| **P2** Author optimism in Self-Test Reports / final reports | MEDIUM | YES (PR #314 fired today) | #314 (today), #208, #300 |
| **P3** CI-green / GUT-green treated as sufficient despite codified rules | HIGH | YES (within one week of new memory `html5-visual-gated-author-self-soak`) | #291 v3 + v3-with-B3, #314 today |

Three lower-cost patterns also documented: P4 (worktree discipline drift), P5 (parallel-dispatch ticket race), P6 (ticket dispatch-readiness — positive signal, this is a strength).

## Three prioritized mitigations (for this week)

| Priority | Candidate | Mandate | Effort |
|---|---|---|---|
| **1** | Orch-side merge-gate verification on HTML5-visual-gated PRs | Orch (no new code) | Dispatch-template + GIT_PROTOCOL.md amendment |
| **2** | Final-report claim-fidelity tightening (`tightened-final-report-contract` amendment — claims must cite verifiable evidence) | PL via DECISIONS.md batch | 10-word memory amendment + dispatch-template snippet |
| **3** | Port `html5-visual-gated-author-self-soak` + `tightened-final-report-contract` from auto-memory into `team/TESTING_BAR.md` (sub-agent-readable) | PL docs PR | ~30 min Priya work |

All three within PL+orch mandate; no Sponsor sign-off required.

## Sponsor decision surface (one item only)

**Approve soak-accelerator URL-param tooling** (`?start_room=N` + `?boss_hp_mult=N` on `main`) — per memory `html5-visual-gated-author-self-soak` § "Structural follow-up." Cost: 2-3 dev ticks (Devon, M PR). Benefit: every future HTML5-visual-gated PR recoups iteration cost.

**Priya recommendation:** approve and land in **M3 Tier 3 W2** (option B) — keeps W1 spike cadence undisrupted; W2's camera-scroll retrofit is the natural test surface.

## Artifacts in this PR

- `team/priya-pl/m3-retrospective.md` — full retro doc (~2,800 words)
  - §1 Method statement
  - §2 Pattern analysis (P1-P6, each cite-able)
  - §3 Root-cause hypotheses (P1-P3)
  - §4 Process-improvement candidates (A-G)
  - §5 Prioritization (top 3 for this week)
  - §6 Sponsor decision surface (1 item)
  - §7 What I'm NOT recommending (rejected items, candidly)
  - §8 Forward-looking watch signals
  - §9 Decision drafts for next weekly batch
- `team/priya-pl/m3-retrospective-pr-body.md` — this body

## Sponsor-input items per section

- **§6:** 1 decision request — soak-accelerator tool scope-add approval.
- **No other Sponsor-input items.** All other recommendations are within PL+orch mandate.

## Non-obvious findings (for maintain-docs Stop-hook capture)

1. **Memory rule codification → ~0 net learning effect when sub-agents don't auto-read the memory.** `html5-visual-gated-author-self-soak` (authored 2026-05-21) saved zero agent-cycles in the 24 hours after authoring; PR #291 v3-with-B3 violated it within hours, and PR #314 today is structurally adjacent. The structural answer is porting load-bearing rules into `team/TESTING_BAR.md` (sub-agent-readable) — auto-memory is for orch persistence across sessions, not for sub-agent guidance.
2. **`tightened-final-report-contract` constrains length but not claim-fidelity.** A confident-sounding final report ends the dispatch faster; the agent-lifecycle incentive structurally favors optimism. Without a fidelity check, optimism IS the local-optimum strategy for sub-agents.
3. **Sponsor's hypothesis 2 (ticket quality) is provably falsified by Tier 3 W1's clean dispatch.** Worth surfacing because the framing assumes drift origin is at ticket → dispatch; evidence shows drift origin is at dispatch → merge.

## Final report fields (this PR)

- **PR URL:** (filled at PR creation)
- **Verdict:** dispatch-ready retro — pure docs, no code, no Tess required (per `team/TESTING_BAR.md` exempt categories for `pm(...)` / `docs(team)` PRs)
- **Doc updates:** `team/priya-pl/m3-retrospective.md` (new) + `team/priya-pl/m3-retrospective-pr-body.md` (new)
- **Decision draft (for next Priya weekly batch):** see retro §9 — 4 decision drafts (retro grade, hypothesis-2-falsified, Sponsor-decision-routing, retro-cadence)

## Cross-references

- Companion: `team/priya-pl/ac4-white-whale-retro.md` (precedent for STRUCTURAL_GAP-leaning-MIXED grading)
- Companion: `team/priya-pl/m2-week-2-retro.md` (C+ grade precedent)
- Companion: `team/priya-pl/m2-week-3-mid-retro.md` (B+ grade precedent, process-gate installation)
- Memory: `html5-visual-gated-author-self-soak`, `tightened-final-report-contract`, `parallel-dispatch-ticket-race`
- ClickUp ticket: filed at PR-open time (see dispatch flow)
