# Retro — PR #327 W2 pre-shape (post-Wave-3 sequencing v1.3 amendment)

**Author:** Priya · **Date:** 2026-05-23 · **PR:** [#327](https://github.com/sandvaer/RandomGame/pull/327) (merged `d5f92eb`, 2026-05-22T22:57:54Z) · **Class:** process-incident-class (per the brand-new `per-class-retro-trigger-convention`, codified in `team/ROLES.md` Priya §Retro-authorship triggers in the same PR as this retro)

## Meta — self-retro caveat

This retro is on my own pre-shape work — the same author reflecting on the same artifact. Per `tess-cant-self-qa-peer-review` memory, the QA-side principle is "no agent reviews their own work"; for retros the discipline is softer (retros are reflective by nature; honest self-grading + structural findings still have value). I am noting the tension up front so the grade below is not over-trusted on its own. Where I find myself wanting to sandbag or sugar-coat, I will say so inline.

---

## §1 — Grade: **B**

Honest middle. The pre-shape pass itself was correct and dispatch-ready (5/7 keep-as-is verdict survived the audit; 2/7 amend was already paper-shaped in v1.2 §5.1; 0/7 net-new). Calendar honesty held — Tier 3 stays at 7-10 weeks; W1 grade reaffirmed at B+. **Where the grade slips below A:** ClickUp MCP disconnected mid-dispatch, so the W2-T2 + W2-T4 ticket-body audit could only be paper-shaped, not actually applied via `clickup_update_task`. The audit is COMPLETE-IN-PAPER and INCOMPLETE-IN-ACT — I documented the gap explicitly in PR body + v1.3 §B + final-report Blockers, and recommended the next-session action (run `clickup_get_task` on W2-T2 + W2-T4 once MCP reconnected). That's the right disposition but it's still an open thread that an A-grade pass would have closed.

I am explicitly NOT grading higher because the work was fast — fast doesn't beat closed-loop. I am explicitly NOT grading lower because the MCP disconnect was infrastructure-class (not author negligence), and the paper-shape ticket-body verdict is canonical and load-bearing for the next session.

If this dispatch had landed in the same session as a working MCP, grade would be A-. If it had missed the ticket-body verdict entirely (just landed v1.3 amendment without auditing the ticket family at all), grade would be C+.

---

## §2 — Patterns

### What worked

1. **Resume from prior-session WIP was clean.** Prior session ended with uncommitted edits to `post-wave3-sequencing.md` (v1.3 amendment in flight). Worktree state at session-start was the v1.3 draft pre-commit; no manual recovery needed. Wave-3-sequencing.md's amendment-block convention (v1.0 → v1.1 → v1.2 → v1.3 stacked, historical record below) absorbed the v1.3 lift naturally.
2. **W1 ticket audit verdict held without surprises.** 5 keep-as-is / 2 amend / 0 new is exactly the verdict shape a well-formed pre-shape pass should produce when the prior author (also me, in v1.2) did their job. The 2 amend items were both Drew-nit routings I had already paper-shaped in v1.2 §5.1 — meaning v1.2's discipline of routing nits inline at the time they were caught (vs. queueing them for a separate ticket) paid off. The audit pass was confirmation, not re-discovery.
3. **`gh pr view`-based ticket roster reconstruction worked.** With ClickUp MCP down, I used `gh pr list --state merged --limit 12` + the v1.2 §5 ticket-roster table in `post-wave3-sequencing.md` to reconstruct ticket IDs and infer current state. This is the right fallback shape: GitHub data is authoritative for merged PRs; the v1.2 ticket-roster table is canonical for ticket IDs the orchestrator filed. No fabrication, no guessing.
4. **The "ticket bodies may already be inlined" hedge in §B verdict.** I explicitly stated that the amend verdict is conditional on the actual ticket-body state, which I could not verify. This is the right shape per `never fabricate, never guess` — saying "if the bodies already inline v1.2 §5.1 then verdict collapses to keep-as-is" preserves the next session's option to do the verify-then-act path without me having pre-committed to an action that may not be needed.

### What didn't

1. **ClickUp MCP disconnected mid-dispatch — three-occurrence pattern within a single session.** This is the load-bearing finding. Devon hit it first (saw it as a hard error in his procgen Part A dispatch when he tried to update ticket status). Orch hit it next (auto-status pulse showed ticket-board state as stale; could not flip statuses). Priya (this dispatch) hit it third — could not run `clickup_update_task` on W2-T2 + W2-T4 to inline Part D acceptance criteria. Three-in-one-session is a pattern, not a transient blip. **Mitigation needed:** either (a) MCP reconnect ritual at session-start (orchestrator pings each MCP server, fails fast if disconnected, surfaces to Sponsor for re-auth), or (b) durable fallback shape where ticket updates queue to a delta file and the next session-start tick applies them (similar to `decisions-batch-pr-template.md` pattern). Recommending Sponsor pick at §5 decision-surface.
2. **Tess `86c9xucuc` scaffold ticket pending state was discovered, not prevented.** Per v1.3 §A, the Tess M3 Tier 3 acceptance plan scaffold was a Day-1 W1 dispatch in `m3-tier3-w1-tickets.md` but I could not verify its status because (a) MCP down and (b) no recent Tess-authored PR mentions it. I flagged it as a W2-Day-1 escalation target. This is right, but the pre-shape pass should ideally have caught Tess scaffold drift earlier — at W1 mid-retro or end-of-W1, not at W2 pre-shape. **Mitigation:** add "Tess acceptance-plan scaffold ticket status" to the W1 mid-retro checklist (already a part of standard retro shape — flag if not yet started).
3. **The v1.3 amendment block keeps getting longer.** v1.0 was the initial sequencing doc; v1.1 was Sponsor SI-1..SI-5 + the Diablo-shape directive; v1.2 was W2 ticket family + Drew nit routing; v1.3 is W2 audit + S2 gap callout. Four amendment blocks stacked on top of v1.0 means future readers must trace through ~25k tokens of amendment context to reconstruct current state. **Mitigation:** consider promoting v1.3 + v1.2 deltas to a fresh top-level summary at end-of-W2 (collapse the amendment chain into "current shape" once the SI-8 lock cements the Tier 3 shape). This is the standard documentation pattern — amend in flight, consolidate at milestone boundaries.

---

## §3 — Hypothesis-verdict (v1.1 predictions for W1 outcomes)

When I authored v1.1 of `post-wave3-sequencing.md` on 2026-05-22 (same day as Sponsor signed SI-1..SI-5 + Commitment 5 procgen), I made implicit predictions about W1. v1.3 §A is the receipt; let me grade my own predictions explicitly.

| Prediction | Actual | Verdict |
|---|---|---|
| **W1 = 3 spikes + Sub-track 5a PixelLab batch wave 1 + Sponsor signs SI-8** (v1.1 §3 Week 1) | 5 spikes landed (camera + dialogue + zone-schema + save-survey + world-map direction); procgen spike in flight (PR not yet open); SI-8 NOT signed yet (gated on procgen-spike PR); PixelLab batch wave 1 visibility low | **3/5 right.** Overshot on spike count (5 not 3 — I underestimated team parallel velocity); undershot on SI-8 closure (procgen spike L-XL surface needed more time than I budgeted in Week 1) |
| **Tier 3 calendar = 7-10 weeks honest middle** (v1.1 §3 widening) | Holding at 7-10 weeks; procgen ~1-2 day slip absorbed inside W1 buffer | **Right.** Calendar honesty held; the widening was the right call |
| **R-PROCGEN is the dominant new risk** (v1.1 §7) | R-PROCGEN held at med probability post-W1; R-SCROLL + R-DIALOGUE demoted off top-5 | **Right.** The three sub-risks (R-PROCGEN.a seed-binding / R-PROCGEN.b mating / R-PROCGEN.c HTML5 seam) all in flight in the procgen spike; verdict pending at PR merge |
| **W2 ticket family = ~30-45 ticks across 7 dispatch surfaces** (v1.2 §5) | W2 ticket family stable in v1.3 audit; 5 keep-as-is / 2 amend / 0 new | **Right.** No re-scoping needed; the v1.2 pre-shape held under audit |
| **Tess scaffold lands Day-1 W1** (m3-tier3-w1-tickets.md) | Tess scaffold pending state discovered at W2 pre-shape; in-flight QA at W1 Day-1 likely consumed Tess bandwidth | **Wrong.** I should have pre-shaped the Tess scaffold dispatch with a contingency for in-flight QA collision. Tess single-tenancy is a known constraint; bundling scaffold into Day-1 dispatch alongside ongoing QA work over-allocates Tess. **Mitigation:** future Day-1 dispatch briefs that target Tess should explicitly check Tess in-flight QA state and stage the scaffold dispatch later if needed |

**Overall hypothesis-verdict: 4/5 predictions held.** The Tess-scaffold-on-Day-1 prediction was the miss; the W1 outcome shape (5 spikes, procgen slip, SI-8 deferral) was correctly anticipated in v1.1's general framing even where specific Week-1 quantities undershot.

---

## §4 — Mitigations

Ordered by leverage (high → low):

1. **MCP-disconnect detection at session-start.** Three-occurrence pattern within one session is structural, not transient. Recommend orchestrator adds an MCP-health ping to the session-start hook: ping `clickup`, `pixellab`, `pixel-mcp` MCP servers; if any are disconnected, surface to user immediately with re-auth instructions. Fail-fast > fail-mid-dispatch. (See §5 — Sponsor-decision-surface item 1.)
2. **Promote v1.3 + v1.2 amendments to a "current shape" summary at end-of-W2.** The amendment-block-stack convention is correct for in-flight authoring but expensive for new readers. Once SI-8 locks at procgen-spike PR-merge moment, v1.3 + v1.2 should consolidate into a fresh top-level section, with the v1.0 + v1.1 + v1.2 + v1.3 amendments preserved below as historical record. Schedule this as a W2 end-of-wave doc task.
3. **Tess scaffold dispatch should check in-flight QA state at brief-time.** Future dispatch briefs targeting Tess for scaffold work (acceptance plans, omnibus QA passes) should explicitly check whether Tess is mid-PR-review or mid-spec-authoring before scheduling. The orchestrator already does this for Devon-wt single-tenancy; extend to Tess-wt by convention.
4. **W1 mid-retro checklist additions.** Add "Tess scaffold ticket status" and "Sub-track 5a PixelLab batch wave 1 visibility" to the W1 mid-retro checklist (which fires before W1 end). Both are structural gaps that surfaced at W2 pre-shape and should have surfaced earlier.
5. **`per-class-retro-trigger-convention` codification.** This dispatch IS the first firing of the convention. The retro itself + the `team/ROLES.md` codification are the structural mitigation — future PRs in the four trigger classes (wave-completion / spike / process-incident / multi-iteration) auto-route to a Priya retro dispatch without orchestrator needing to decide each time. Memory entry name: `per-class-retro-trigger-convention`. (See cross-reference at top of this retro.)

---

## §5 — Decision-surface (for Sponsor)

1. **MCP-disconnect-detection ritual.** Three-occurrence pattern this session is high signal. Options:
   - **(a)** Add session-start MCP-health ping to the orchestrator hook. Pro: fail-fast; Con: latency at session-start (3-5 ping round-trips before user can act).
   - **(b)** Defer to user-side detection ("user notices ClickUp is down and re-auths"). Pro: no orchestrator overhead; Con: user surface bears the cost; current state.
   - **(c)** Durable fallback — ticket updates queue to a delta file, applied at next session-start. Pro: zero in-session loss; Con: implementation cost; per-tool MCP queue design.
   - **Recommended:** (a). The fail-fast pattern is consistent with `claude-mcp-add-user-scope-on-windows` discipline; the session-start latency is acceptable (~2s) for the trust gain.
2. **Amendment-block consolidation cadence.** v1.3 stacks atop v1.2 atop v1.1 atop v1.0. When should we collapse?
   - **(a)** At each milestone boundary (M3 Tier 3 close → consolidate).
   - **(b)** At each major Sponsor sign-off (SI-8 lock → consolidate).
   - **(c)** Never — historical record is the canonical shape.
   - **Recommended:** (b). SI-8 lock at procgen-spike PR-merge is the natural consolidation point for the procgen scope; collapse v1.1 procgen amendments + v1.2 W2 ticket family + v1.3 audit into "current Tier 3 shape" at that moment.

Neither is blocking. Both are process-tuning calls.

---

## §6 — Cadence

Should W3 pre-shape happen earlier? Later? Bundled differently?

**Recommendation: W3 pre-shape happens at W2 mid-retro, NOT at W2 end.**

Rationale:
- This dispatch (W2 pre-shape) happened at W1 end, which was the right cadence — the W2 ticket family was already paper-shaped in v1.2 during the W1 dispatch, and the W1 end audit confirmed it. Net new work was an audit pass + gap callout, not from-scratch authoring.
- W3 pre-shape will be different — the W2 amend tickets (T2 + T4) will be in flight, the procgen spike PR will have merged (SI-8 locked), and the W2 T3 procgen impl will be dispatched with a known scope option. W3 pre-shape needs SI-8 lock data and W2 T3 dispatch experience.
- **W2 mid-retro is the right gate** because it lands after SI-8 locks but before W2 end — early enough to shape W3 tickets ahead of W2 dispatch close, late enough to incorporate procgen spike findings + W2 T3 dispatch experience.

**Bundling shape for W3 pre-shape dispatch:**

1. W3 ticket pre-shape (similar shape to v1.2 §5 W2 ticket family)
2. R-PROCGEN re-score (post-procgen-PR-merge data)
3. v1.4 amendment to `post-wave3-sequencing.md` capturing the W3 shape + R-PROCGEN delta
4. Optional consolidation pass if Sponsor signed §5 decision-2 (a/b/c) above

**Anti-pattern to avoid:** doing W3 pre-shape AT W2 end. That puts it on the critical path of W3 Day-1 dispatch (orchestrator waiting on pre-shape to dispatch) and over-allocates Priya's worktree at W2 close when ticket-board audits are heavier.

---

## §7 — Three-+-triggers-in-session bundled meta-retro check

Per the `per-class-retro-trigger-convention` codification: three+ retro triggers in a single session warrants a bundled meta-retro at session-save.

**This session's retro triggers (in chronological order):**
1. PR #314 — spike(camera) — Spike PR class (camera-scroll spike). **Triggered? No.** Retro was not dispatched at PR #314 merge time; the trigger convention had not yet been locked. PR #315 (M3 retrospective pass 1) absorbed the W1 retro shape instead.
2. PR #315 — M3 retrospective pass 1 — Wave-completion PR class (closes M3 Tier 2 + opens Tier 3 W1). **Triggered? Yes, retro was the PR itself.**
3. PR #316 — M3 retro mitigations 1+2+3 — process-incident PR class (lands the tightened-final-report contract amendment). **Triggered? Implicit — PR #315 retro AUTHORED the mitigations PR #316 lands.**
4. PR #319 — spike(dialogue) — Spike PR class. **Triggered? No.** Same reason as PR #314.
5. PR #320 — design(save) save-schema v5 — neither spike nor wave-completion (it's a paper-only survey landing in the W1 wave). **Triggered? No.** Routine W1 deliverable.
6. PR #323 — feat(input|ui) InventoryPanel modal-input-gate — Multi-iteration PR class (3+ reviewer round-trips: Sponsor Option A → Drew peer review → Tess QA → merge). **Triggered? Borderline.** Not formally retroed; absorbed into PR #324 session-closure captures.
7. PR #325 — docs(orch) post-W1 captures — process-incident PR class (orch-docs). **Triggered? Borderline.** Self-contained doc capture; no retro authored.
8. PR #326 — chore(orch-hooks) maintain-docs Stop hook — process-incident PR class (orch-hooks change). **Triggered? No.** Shell-only PR; the convention codification (this dispatch) is the retroactive trigger-firing.
9. PR #327 — docs(orch) M3 Tier 3 W2 pre-shape — process-incident PR class (planning artifact). **Triggered? YES — THIS RETRO.**

**Tally:** at least 3 formal retro-trigger PRs in this session (#314, #315, #319 by spike-class alone; #316, #325, #326, #327 by process-incident class; #323 by multi-iteration class). Conservatively 5+ triggers fired.

**Verdict:** session does warrant a bundled meta-retro at session-save. The shape: collapse common patterns across the 5+ triggers into a single end-of-session retro digest. Recommend this for the orchestrator's next save-session pass — not a separate dispatch.

**Why not a separate retro dispatch:** per-PR retros captured the specifics already (PR #315 wave retro + PR #324 session-closure captures + this retro). The bundled meta-retro adds value only if it surfaces a CROSS-CUTTING pattern none of the individual retros saw. The three-occurrence MCP-disconnect pattern (this retro §2.1) is exactly that shape — it surfaced HERE, not in any earlier retro, because each individual occurrence felt transient at the time. The cross-cutting pattern only emerges from the third occurrence backward-glancing at the prior two.

The bundled meta-retro should be ONE additional paragraph in the session-save state file, not a new PR. The PR-shaped artifact is THIS retro file.

---

## Cross-references

- `team/ROLES.md` § Priya — Retro authorship triggers (same PR adds this codification; this retro is the first firing)
- `team/priya-pl/post-wave3-sequencing.md` v1.3 amendment (PR #327, merged `d5f92eb`)
- Memory entry: `per-class-retro-trigger-convention` (locked 2026-05-23 — this session)
- Memory entry: `retrospective-reporting-convention` — every retro surfaces to Sponsor as a structured digest (this retro follows that shape)
- Memory entry: `tess-cant-self-qa-peer-review` — softer for retros; meta-honesty about self-retro tension noted in §Meta above
- PR #315 — M3 retrospective pass 1 (predecessor retro covering Tier 2 close + Tier 3 W1 in-flight)
- PR #316 — M3 retro mitigations 1+2+3 (tightened-final-report contract amendment + claim-fidelity + return-timing)
- `m3-tier3-w1-tickets.md` — W1 dispatch roster (referenced for Tess scaffold dispatch order)
