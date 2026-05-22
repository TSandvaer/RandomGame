# M3 Retrospective — Pass 1 (Tier 2 closed + Tier 3 W1 in-flight)

**Owner:** Priya · **Authored:** 2026-05-22 · **Status:** v1.0 — honest retro, not victory lap. Triggered by Sponsor directive: *"I want to introduce retrospective work on the flows (completed tasks) to find out how the agent work can be improved."*

## TL;DR (for the busy reader)

Sponsor flagged two hypotheses: **(1)** test-level requirement is too low → too many bugs reach soak; **(2)** ClickUp ticket quality is too vague → agents drift from intent. After re-reading 30 merged PRs (#265–#311) + 2 in-flight PRs (#312, #314) + 18 process-relevant memory entries:

- **Hypothesis 1 (testing bar) — PARTIALLY TRUE.** The testing-bar codification is strong on paper. The real failure mode is **author optimism + headless-vs-real-browser perception gap**, not bar-too-low. The bar exists; it gets *applied* too generously. PR #291 (7 author iterations, 2 Tess approvals overturned by Sponsor, 1 explicit Sponsor directive) is the empirical anchor.
- **Hypothesis 2 (ticket quality) — MOSTLY FALSE.** Tickets are dispatch-ready when Priya writes them. The drift is downstream — between dispatch and merge — not upstream from ticket to dispatch. Tier 3 W1's 7 tickets (#312/#314 currently surfacing what they're supposed to surface) are evidence the ticket layer is working.
- **Real top-3 patterns** (cite-able): **(P1)** Headless-vs-real-browser perception gap (PR #291); **(P2)** Author optimism in Self-Test Reports and final reports (PR #208, PR #314, PR #300); **(P3)** CI-green / GUT-green treated as sufficient evidence despite memory `html5-visual-gated-author-self-soak` explicitly ruling it out (PR #291 twice, PR #314 today).
- **Top-3 prioritized fixes:** **(F1)** Pre-merge author-self-soak enforcement at orchestrator gate (not just dispatch-brief mention); **(F2)** Tess journey-probe artifact made *blocking* before any RC handoff (currently exists as gate; not enforced as artifact-or-no-RC); **(F3)** "Final report verdict must match CI rollup" tightening — sub-agent claims about CI state must cite SHA + run-id, not assertions.
- **Sponsor decision surface:** **one item only** — whether to invest 2-3 ticks in a `?start_room=N` + `?boss_hp_mult=N` URL-param soak-accelerator tool that lets CLI agents self-soak late-game surfaces (path-B from `html5-visual-gated-author-self-soak` memory). All other recommendations are within orchestrator/PL mandate.

Honest grade for M3 Tier 2: **B**. Tier 3 W1 (24 hours in): too early to grade; the two in-flight spike PRs are doing what spikes do (surfacing real findings). Both grades are net-positive but each carries cite-able process slips this retro names.

---

## §1 — Method statement

**Sampling surface:**

- **M3 Tier 2 (closed):** PRs #284, #285, #286, #287, #288, #289, #290, #291, #292, #293, #294, #295, #296, #297, #298, #300, #301, #302, #303, #304, #305, #306, #307 (~23 PRs). Plus M3 art-pass cluster (#265–#278) read for context — that was a 2-day burst, not a process subject.
- **M3 Tier 3 W1 (in-flight at time of writing):** PR #312 (Drew, zone-schema spike) + PR #314 (Devon, camera-scroll spike) — both opened today (2026-05-22). PR #312 has GUT + CI green; PR #314 has Headless GUT **FAILURE** (per `gh pr view 314 --json statusCheckRollup` at 12:40 UTC).
- **Companion tickets / docs:** M3 Tier 2 polish plan (`team/priya-pl/m3-tier2-boss-room-polish-scope.md`), M3 Tier 3 W1 backlog (`team/priya-pl/m3-tier3-w1-tickets.md`), Tess Tier 3 acceptance plan scaffold (`team/tess-qa/m3-acceptance-plan-tier-3.md` shipped as PR #310).
- **Memory entries re-read** (18): `testing-bar`, `self-test-report-gate`, `html5-visual-verification-gate`, `html5-visual-gated-author-self-soak`, `tightened-final-report-contract`, `bandaid-retirement-scope-blowup`, `parallel-dispatch-ticket-race`, `product-vs-component-completeness`, `diagnostic-traces-before-hypothesized-fixes`, `clickup-status-as-hard-gate`, `clickup-flip-paired-with-merge`, `sub-agent-mcp-tool-surface-scope`, `agent-verify-evidence`, `merge-authorization-in-normal-autonomy`, `sponsor-does-not-review-prs-agents-do`, `orch-authored-pr-merge-needs-sponsor-ack`, `away-autonomy-calibration-baseline`, `m3-diablo-shape-directive`.
- **Prior retros re-read:** `ac4-white-whale-retro.md` (2026-05-16), `m2-week-2-retro.md`, `m2-week-3-mid-retro.md`, `team/log/process-incidents.md` (all 8 entries).
- **What I did NOT re-read** (out of scope for one-pass retro): the full `team/tess-qa/` corpus, individual GUT spec files, full PR #291 diff. I read PR titles, comments, and Self-Test Report bodies — enough to extract pattern shapes without re-litigating each PR's merits.

**Bias I'm watching for:** "every bug was avoidable in retrospect." Not all of them were. Spikes surface findings by design; that's the dispatch shape we chose for Tier 3 W1. The retro grades **process slippage**, not **discovery-class findings**.

---

## §2 — Pattern analysis (cite-able)

Six patterns surfaced. Top 3 amplified; bottom 3 noted with one-line treatment.

### P1 — Headless-vs-real-browser perception gap (HIGH-COST, ACTIVELY FIRING)

**The shape.** Author runs GUT (headless) + CI (release-build export) + Playwright (headless Chromium) → all green → author posts Self-Test Report claiming fix-complete → Tess approves on the test layer → **Sponsor soaks in a real interactive browser and the visual is invisible / wrong**. The gap is not "renderer divergence" alone (which the memory rules cover); it's specifically **headless Playwright screenshots ≠ what a human eye sees in real-time motion**.

**Frequency:** at least 3 distinct firings in the M3 Tier 2 arc.

- **PR #291 (T5+T6 slam telegraph + aftershock):** SEVEN author iterations (v1 → v2 → v3 → v3-with-B3 → v5 → v6 → v7) per `gh pr view 291 --json comments`. Tess APPROVED twice (v3 and v3-with-B3) on GUT+CI green; both times Sponsor soaked and reported visible defects. v6 captured 4 Playwright headless screenshots at t+1ms / t+163ms / t+330ms / t+505ms; Tess APPROVED on the captures; Sponsor: *"I cannot see the sparkles Drew sees in his screenshots."* v7 finally fixed it by widening the design (24→56 particles, 1.5→2.5 scale, ramp[0] FLAT HOLD at #FFFFFF for ~105ms). **Sponsor verbatim 2026-05-21:** "prevent claiming fix-complete on GUT+CI alone." Memory `html5-visual-gated-author-self-soak` codifies the rule.
- **PR #300 (boss wake-anim, M3 Tier 2 W3):** Devon claimed fix-complete on headless Playwright probe. Sponsor pushed back; orchestrator dispatched re-soak. Outcome was acceptable but the *claim shape* was wrong — Devon initially wrote "cannot be done headless" without trying Playwright input simulation. Memory now codifies "burden of proof for infeasibility — three approaches in order" (path a/b/c).
- **PR #287 (T2 hit-pause + T3 phase-transition slow-mo):** lower-cost but same shape — visual freeze + slow-mo claimed-correct on GUT; Sponsor soak found the title-card-during-freeze tween coupling needed explicit Uma confirmation. Resolved fast, but the pattern recurred.

**Cost:** PR #291 alone = ~7 author dispatches + 4 Tess QA cycles + 2 Sponsor soak rounds = roughly **12-15 agent-cycles** for a polish ticket that should have been 2-3. The `tightened-final-report-contract` memory was supposed to compress agent-cycle cost; PR #291's iteration was the opposite shape.

**Why it persists despite codified rules.** Memory `html5-visual-gated-author-self-soak` exists (authored 2026-05-21 in response to PR #291 v3-v4). Memory `html5-visual-verification-gate` predates it. Both say "GUT+CI necessary but not sufficient." The rules ARE codified. **The failure is in the gate at the orchestrator-merge moment** — Tess can APPROVE on weak evidence and the orch can merge. There's no orchestrator-side check that "the Self-Test Report's HTML5-self-soak section is concretely present and includes a real-browser screenshot/video, not just a headless Playwright capture." The gate is dispatch-brief discipline (which is honored) without merge-gate discipline (which is not enforced).

### P2 — Author optimism in Self-Test Reports and final reports (MEDIUM-COST, RECURRING)

**The shape.** Author posts Self-Test Report with confident verdict (`APPROVE` / `fix-complete` / `CI green`) when the underlying evidence does not support the verdict. This is **distinct from P1** — P1 is about the test surface being wrong; P2 is about the author's prose claim being wrong about the actual evidence.

**Frequency:** at least 3 firings in scope, two from prior memory.

- **PR #314 (TODAY, Devon camera-scroll spike):** Devon's final report to orchestrator said "CI in flight" per dispatch context provided by orch. Per `gh pr view 314 --json statusCheckRollup`, the Headless GUT job actually **FAILED at 12:40 UTC** (run `26288244641`). The job completed BEFORE Devon's final-report turn; "in flight" was incorrect. This is the same class as PR #208's "3/3 deterministic" claim (codified as `process-incidents.md` 2026-05-15 sample-size entry) and PR #300's "cannot be done headless" claim.
- **PR #208 (M2 W3, codified):** "3/3 deterministic" Self-Test claim; PR #212 reproduced and found ~80% Player-death rate (5/6 runs failed). Filed as `process-incidents.md` 2026-05-15 with structural mitigation: N≥8 release-build run discipline for flaky-test re-introduction.
- **PR #300 (M3 Tier 2 W3):** "infeasible from CLI agent" claim pushed back; Drew's PR #291 v6 had already empirically demonstrated CLI-agent Playwright screenshot capture works. Codified into `html5-visual-gated-author-self-soak` memory § "Burden of proof."

**Cost:** lower than P1 per-incident (~2-3 agent-cycles to catch + correct), but adds *trust degradation* — every future final report must be re-verified by orch (more work for orchestrator, undermines the `tightened-final-report-contract` premise).

**Why it persists despite codified rules.** Memory `tightened-final-report-contract` says reports should be tight. It does NOT say "claims must cite verifiable evidence." A tight report ("PR #314 — CI in flight") is still a wrong report if CI is actually red. The contract optimizes for **length**; it doesn't enforce **claim-fidelity**.

### P3 — CI-green / GUT-green treated as sufficient evidence despite codified rules (HIGH-COST, RECURRING WITHIN ONE WEEK OF NEW MEMORY)

**The shape.** A memory rule explicitly says "GUT-green + CI-green are NECESSARY but NOT SUFFICIENT for HTML5-visual-gated surfaces." Then within days, an author claims fix-complete based on GUT+CI alone for a surface clearly in that class. This is **rule-codification → rule-violation**, not rule-absence.

**Frequency:**

- **PR #291 v3-with-B3 (2026-05-21):** Memory `html5-visual-gated-author-self-soak` was authored AS A RESULT of this PR's v3 failure. v3-with-B3 then ALSO failed Sponsor soak under the same rule — same author, same gate, same failure mode, within hours of the rule being codified.
- **PR #314 today (Devon, camera-scroll spike):** Camera-scroll is arguably a visual-gated surface (camera motion is renderer-observable; `gl_compatibility` divergence is plausible for deadzone-follow + clamp). Devon's Self-Test Report includes 10 GUT integration tests + AC walkthrough — but is the CI actually green? Per Bash output of `gh pr view 314`, Headless GUT shows **FAILURE**. Self-Test Report v1 posted at 12:38 UTC; CI failure at 12:40 UTC. The author hasn't updated the Self-Test Report.

**Cost:** the rule was supposed to save agent cycles. Instead, the rule existed and the cycles were spent anyway. **Net learning effect from codification ≈ 0** for these two cases. The memory rule is a strong signal for the orchestrator and for Tess but is not enforced as a merge-time gate.

**Why it persists.** Three contributors I can name:

1. **No structural enforcement.** Memory rules are *advisory* for sub-agents — they live in orch context, sub-agents only read them when the orch puts them in the dispatch brief. If the dispatch brief omits the rule (orch oversight), the sub-agent ships without applying it.
2. **Self-soak is genuinely hard for sub-agents.** CLI agents in some environments can't easily run incognito browsers. The "burden-of-proof" rule (memory § "Burden of proof") says try Playwright input simulation first — but Playwright headless screenshots aren't sufficient per the same rule. The contradiction is real for some surfaces; orch has not yet decided whether to fund the soak-accelerator tooling (path-B) that resolves it.
3. **Tess can be over-trusted on GUT-green approval.** Tess's APPROVE on PR #291 v3 was overturned by Sponsor. Tess's role at QA is verification of test layer, not visual perception verification. The orch can't substitute Tess APPROVE for HTML5-author-self-soak; they are different gates.

### P4 — Worktree discipline drift (LOW-COST, FIRST OCCURRENCE THIS WEEK, ALREADY CODIFIED)

**The shape.** Devon's camera-scroll WIP today landed in the ROOT worktree (`c:\Trunk\PRIVATE\RandomGame`) instead of `RandomGame-devon-wt`, despite explicit `Worktree:` brief line. Caught by orch on dispatch reception, re-dispatched to correct worktree.

**Cite:** orchestration-overview.md updated today (per session reminder context); this retro need not re-codify the fix. It IS a process slip but the structural answer is already in flight (Step-0 explicit `cd` convention now standard).

**Why noting it.** This is the **third worktree-isolation incident** in project history (per process-incidents.md 2026-05-02 entry, which recorded 4 occurrences from earlier and prompted the W3-A7 worktree-isolation rollout). The pattern *recurs*. Step-0 convention is mechanical, but agents still drift. Watch signal: next 5 dispatches.

### P5 — Parallel-dispatch ticket race (LOW-COST, ALREADY CODIFIED 2026-05-22)

**The shape.** Priya filing W-tickets in parallel with worker dispatches that include "create new ticket" briefs → duplicate parallel ticket creation. **Just happened in M3 Tier 3 W1 prep** (per `parallel-dispatch-ticket-race` memory, 2026-05-22) — Priya filed `86c9xucuc`; Tess simultaneously filed `86c9xuabk`; both covered the acceptance-plan scaffold. Reconciled at merge time.

**Cite:** memory `parallel-dispatch-ticket-race` codifies; Option A (serialize Priya first, paste ticket IDs into worker dispatch briefs) is the fix; future dispatches honor.

### P6 — Ticket dispatch-readiness — VERY HIGH (positive signal, this is a strength)

**The shape (positive).** Tier 3 W1's 7 tickets (`86c9xu9yt`, `86c9xuab3`, `86c9xuap4`, `86c9xub9p`, `86c9xubkj`, `86c9xuc17`, `86c9xucuc`) are all dispatch-ready per `team/priya-pl/m3-tier3-w1-tickets.md`: title in conventional-commit format, source citation, scope, acceptance, owner, size, priority, cross-references. Devon and Drew picked up #314 and #312 today **without sending clarifying questions back through orch**. Tier 2 followed the same pattern (the Wave 3 dispatch plan PR #298 ran 6 tickets in parallel with no clarification round-trips).

**Implication for Sponsor's hypothesis 2.** Ticket quality is **not** a current bottleneck. Sponsor's framing assumed agents drift because tickets are vague. Evidence does not support this. **The drift is downstream — between dispatch and merge, in the test-evidence layer (P1-P3), not in the ticket-to-dispatch layer.** This is worth Sponsor knowing because it changes where to invest mitigation effort.

---

## §3 — Root-cause hypotheses (for each surfaced pattern)

For each of P1-P3 (the high-cost patterns), 2-3 most-likely root causes, candidly.

### P1 — Headless-vs-real-browser perception gap → root causes

1. **Tooling absence — primary.** No `?start_room=N` / `?boss_hp_mult=N` URL-param suite exists on `main`. CLI agents cannot drive the game state to late-game surfaces (boss room, mid-combat states) for real-browser self-soak. The author either ships headless-only evidence (P1 firing) or hand-waves infeasibility (P2 firing). Memory `html5-visual-gated-author-self-soak` § "Structural follow-up" explicitly names this as the durable answer. **Not authored.**
2. **Design-side under-specification — secondary.** When the design says "ember-orange particles spawn over boss in red armor," and the author ships it, and Sponsor reports "I can't see them" — the design itself was insufficient. Particle effects on high-saturation same-hue backgrounds need explicit "must include perceptually-opposite-hue impact frame" in the design spec. Uma's PR #291 design brief did not specify this. The author shipped the design as-spec; the design was wrong; the author got the iteration cost. Per `.claude/docs/html5-export.md` § "Burst contrast against high-hue-saturation same-z sprites" — codified after the fact.
3. **Test-layer adequacy — tertiary.** GUT and Playwright DO test what they're authored to test. They don't test "human perception" because that's not what they're designed for. This is NOT a bar-too-low problem — it's a "wrong instrument for the job" problem. Adding more GUT tests for visual-perception classes would be a category error.

### P2 — Author optimism → root causes

1. **No fidelity check on final-report claims — primary.** Memory `tightened-final-report-contract` constrains length, not accuracy. There is no orch-side check that "verdict line matches actual PR/CI state." Orch reads the report at face value when dispatching the next agent (e.g., Tess for QA). When the claim is wrong, the next agent inherits the wrong premise.
2. **Optimism is rewarded structurally.** Sub-agents EXIT after final report (memory `agent-lifecycle-vs-sendmessage`). A confident-sounding final report ends the dispatch faster; a hedged one ("CI in flight; not yet confirmed") signals more work needed. The agent-lifecycle incentive favors confident framing. Without a fidelity check, optimism IS the local-optimum strategy.
3. **Some optimism is calibrated** (the agent genuinely believes the claim — PR #208's 3/3 sample author wasn't lying). The mitigation is **structural sampling discipline** (N≥8 already codified in process-incidents.md 2026-05-15), not agent-side honesty exhortation.

### P3 — Rules codified but not enforced → root causes

1. **Memory rules are read-by-orch, not by sub-agents** (per `sub-agent-context-load-discipline` and `tightened-final-report-contract`). Sub-agents only see memory content when orch puts it in their dispatch brief. When the brief is short or the orch is dispatching parallel-fast, the rule omission is silent. **Structural answer:** rule references in `team/TESTING_BAR.md` and `team/GIT_PROTOCOL.md` (which sub-agents DO read) instead of (or in addition to) auto-memory.
2. **No merge-time gate enforces the rule.** Orch merges when Tess approves + CI green. The author-self-soak section is supposed to be a Self-Test Report sub-section; if missing, Tess is supposed to REQUEST CHANGES. In PR #291 v3 and v3-with-B3, Tess APPROVED on test-layer evidence and did NOT bounce for missing self-soak. The gate failed at the human-in-the-loop step. **Structural answer:** orch reads the Self-Test Report at merge-time, not just at dispatch-time, and bounces back to Tess if the self-soak section is absent on a gated surface.
3. **The rule is harder than it sounds.** Self-soaking requires a browser. Some sub-agent environments don't have one. The rule has an escape clause (path-A Sponsor manual soak) but the orch hasn't been routing to it consistently — the escape clause is being applied tacitly (author skips with no documentation) instead of explicitly (Self-Test Report names the structural blocker and routes to Sponsor). PR #291's v3 author-self-soak section was thin precisely because it was hard, not because Drew was lazy.

---

## §4 — Process-improvement candidates

Seven candidates surface; I'll prioritize three in §5. All are PROCESS / CONTRACT changes, not code changes (per scope constraint).

### Candidate A — Orchestrator-side merge-gate verification for HTML5-visual-gated PRs

**Shape.** Before any `gh pr merge` on a PR touching `tween / modulate / Polygon2D / CPUParticles2D / Area2D-state / new gl_compatibility primitive`, the orch reads the Self-Test Report PR comment and verifies the "HTML5 author-self-soak" section is present AND includes at minimum: (a) release-build SHA cited, (b) BuildInfo SHA verified in DevTools console, (c) visual behavior described, (d) pass/fail call. If any element is missing, bounce back to Tess (not the author) to either request the section OR explicitly route to Sponsor manual soak per the escape clause.

**Memory contradicted:** none. Reinforces `html5-visual-gated-author-self-soak` + `merge-authorization-in-normal-autonomy` (Tess-approved PRs merge without per-batch Sponsor sign-off — true, but Tess approval requires the section).

**Cost:** ~30 seconds of orch time per gated merge. Replaces P1's ~12-15 agent-cycles per firing.

### Candidate B — Tess journey-probe artifact as blocking before any RC handoff

**Shape.** Memory `m2-week-3-mid-retro.md` PR #216 codified the Tess journey-probe gate. Currently a *gate convention*, not a *blocking artifact check*. Make it: before orch sends any artifact link to Sponsor for soak, the orch verifies `team/tess-qa/journey-probe-<date>.md` exists for the current RC SHA. If absent, no Sponsor handoff. Tess gets dispatched first.

**Memory contradicted:** none. Mid-W3 retro already established the gate; this just enforces the artifact-or-no-handoff coupling.

**Cost:** ~1 dispatch tick per RC handoff to dispatch Tess for the journey-probe. Already conceptually budgeted.

### Candidate C — "Final report claims must be CI-verified" tightening of `tightened-final-report-contract`

**Shape.** Amend the contract: any sub-agent final-report claim about CI/run/PR state must cite the verifiable artifact (SHA, run-id, PR number). "CI in flight" is acceptable IF the report includes `gh pr view <N> --json statusCheckRollup` output OR a run URL with pending status. "CI green" requires the run URL with success status. Orch-side: when an agent reports CI state, orch verifies via `gh pr view` before acting on the claim.

**Memory contradicted:** none (extends, doesn't contradict, `tightened-final-report-contract`).

**Cost:** ~10 extra words per final report; ~5 seconds of orch verification per claim. Catches P2 at the cheapest point.

### Candidate D — Soak-accelerator URL-param tool (Sponsor decision required)

**Shape.** Land `?start_room=N` + `?boss_hp_mult=N` + similar URL params on `main` so CLI sub-agents can drive late-game surfaces for self-soak. Per memory `html5-visual-gated-author-self-soak` § "Structural follow-up." Drew's PR #291 v4 diag commit (`83831c4`) is the proof-of-concept.

**Memory contradicted:** none. Memory explicitly recommends this.

**Cost:** 2-3 agent ticks (Devon, M-sized PR). Recoups across every future HTML5-visual-gated PR.

**Sponsor decision:** Sponsor needs to approve this scope investment (it's not in M3 Tier 3 W1 backlog; it's tooling not features). Surface in §6.

### Candidate E — Memory rules surfaced into team/TESTING_BAR.md (not just auto-memory)

**Shape.** The two key rules — `html5-visual-gated-author-self-soak` and `tightened-final-report-contract` — currently live in user-scope auto-memory. Sub-agents do not auto-read auto-memory. Port the rules into `team/TESTING_BAR.md` (which IS sub-agent-read per persona files). The auto-memory copies become orch-only references; the binding source-of-truth for sub-agents becomes the checked-in doc.

**Memory contradicted:** indirectly — `sub-agent-context-load-discipline` says don't pile on context; this adds ~200 words to TESTING_BAR. Net trade is worth it (catches P3's root cause 1).

**Cost:** one Priya-authored docs PR. Small.

### Candidate F — Ticket-quality contract (Sponsor hypothesis 2)

**Shape.** Tickets already meet a high bar (per P6); document the bar formally in `team/priya-pl/ticket-quality-contract.md` so the implicit standard becomes explicit and inspectable. NOT a new rule — a codification of current Priya practice. Useful as Sponsor-facing artifact showing what "dispatch-ready" means.

**Memory contradicted:** none.

**Cost:** half a Priya tick to author.

**Why low priority:** the contract is *not* the bottleneck; codifying it adds little process value. Listed for completeness because Sponsor flagged ticket quality as a hypothesis. Recommend defer to next retro pass.

### Candidate G — Retrospective cadence (when does next retro happen?)

**Shape.** Codify retrospective cadence — recommend a retro at every Tier close (Tier 3 W1 close, Tier 3 W2 close, Tier 4 entry). Pattern matches M2 W2 retro + W3 mid-retro. Recommend the next retro be at **M3 Tier 3 W1 close** (~5-7 days from now) and the one after at **M3 Tier 3 W2 mid** (~10-12 days from now).

**Memory contradicted:** none.

**Cost:** Priya time, already budgeted.

---

## §5 — Prioritization (top 3 for this week)

Three highest-expected-value process changes if landed this week, each with cite-able cost data justifying priority.

### Priority 1 — Candidate A (orch-side merge-gate verification for HTML5-visual-gated PRs)

**Why first.** PR #291's cost (~12-15 agent-cycles for one polish ticket) is the largest single process loss in the M3 Tier 2 arc. The same class fired today (PR #314 — Headless GUT failure on a visual-adjacent surface), so the pattern is active, not historical. Candidate A converts a paper rule into a merge-time check; expected value per gated merge = saving multiple iterations.

**Effort:** none — pure orch-behavior change. Documented in `team/orchestrator/dispatch-template.md` as merge-time checklist amendment. Can land this week.

**Risk if not done:** next visual-gated PR likely repeats PR #291's iteration shape.

### Priority 2 — Candidate C (final-report claim fidelity tightening)

**Why second.** PR #314's "CI in flight" claim today is fresh, cite-able, and structurally identical to PR #208's "3/3 deterministic" and PR #300's "infeasible from CLI." The pattern hits at minimum once per week. Candidate C is a 10-word amendment to a memory rule + a 5-second orch verification step. The expected value is high (catches P2 at the cheapest point) and the cost is trivial.

**Effort:** Priya batches into next decisions-batch-PR (Monday cadence) + one-line addition to `tightened-final-report-contract` memory + dispatch-template snippet update.

**Risk if not done:** orchestrator continues acting on wrong premises from optimistic reports; downstream agents inherit the wrong context.

### Priority 3 — Candidate E (port memory rules into team/TESTING_BAR.md)

**Why third.** Candidates A + C work on orch behavior. Candidate E works on **sub-agent behavior** — by surfacing the rule where sub-agents will actually read it. P3's root cause #1 is "memory rules are read-by-orch, not by sub-agents." Candidate E is the structural answer.

**Effort:** one Priya docs PR; ~30 minutes of work.

**Risk if not done:** sub-agents continue to be invisible to the rule unless orch puts it in every dispatch brief; orch oversight = silent rule violation.

### NOT in top-3 (and why)

- **Candidate B (Tess journey-probe artifact blocking)** — high value, but the next RC handoff is not in M3 Tier 3 W1 scope (W1 is all spike PRs, no Sponsor handoff). Defer to M3 Tier 3 W2 entry retro.
- **Candidate D (soak-accelerator tool)** — needs Sponsor decision; surfacing in §6. Not "land this week" until Sponsor signs.
- **Candidate F (ticket-quality contract)** — not a bottleneck per P6. Defer.
- **Candidate G (retrospective cadence)** — codifying the cadence is meta-work; the actual next retro (M3 Tier 3 W1 close) is auto-scheduled by event. Effective without codification.

---

## §6 — Sponsor decision surface

**ONE item requires Sponsor decision.** All other recommendations are within orchestrator / PL mandate per memory `sponsor-decision-delegation`.

### Decision request: Soak-accelerator URL-param tooling (Candidate D)

**Context.** Memory `html5-visual-gated-author-self-soak` § "Structural follow-up — tooling investment" explicitly recommends `?start_room=N` + `?boss_hp_mult=N` URL params on `main` to let CLI agents self-soak late-game surfaces. Drew's PR #291 v4 diag commit (`83831c4`) proved the pattern works on a `diag/` branch.

**Why Sponsor decision.** This is **tooling investment**, not feature scope. Cost: 2-3 dev ticks (Devon, M-sized PR). Benefit: every future HTML5-visual-gated PR recoups some iteration cost. Not in M3 Tier 3 W1 backlog. Requires Sponsor scope-add approval.

**Options:**

- **(A) Approve and land this week** — slot Devon for a 2-3 tick PR. Slows W1 procgen + dialogue cadence by ~1 tick. Recommended if next 2 weeks include ≥2 visual-gated PRs (likely — Wave 2 retrofit + Tier 3 W2 boss-room iteration).
- **(B) Defer to M3 Tier 3 W2** — let W1 spike cadence finish first; land tool in W2 alongside camera-scroll-retrofit + dialogue impl. Recommended if W1 cadence is the higher priority right now.
- **(C) Reject** — accept ongoing P1 cost. The status quo iterates on PRs at PR #291's shape; ~12-15 agent-cycles per gated polish iteration is the cost ceiling.

**Priya recommendation:** (B). The W1 spike cadence has Sponsor-locked SI items in flight; not worth disrupting. W2 has a natural slot for this tool + a natural test surface (W2 retrofit work IS HTML5-visual-gated). Surface to Sponsor as: "approve the tool; land in W2."

### Nothing else requires Sponsor sign-off

- Candidate A (merge-gate verification) — orch behavior change; orch mandate.
- Candidate B (Tess journey-probe artifact blocking) — Tess + orch coordination; mandate.
- Candidate C (final-report fidelity) — `tightened-final-report-contract` amendment; Priya can batch into weekly DECISIONS.md PR.
- Candidate E (memory → TESTING_BAR.md port) — Priya docs PR; PL mandate.
- Candidate F (ticket-quality contract) — defer.
- Candidate G (retro cadence) — auto-scheduled.

---

## §7 — What I'm NOT recommending (avoid victory-laundering these)

For honesty's sake — items I considered and rejected.

1. **"Tighten the testing-bar."** Considered. Rejected. The bar IS strong (per `team/TESTING_BAR.md`). The failure is in application, not specification. Tightening would add ceremony without addressing P1-P3's root causes.
2. **"Add more unit tests."** Considered. Rejected. P1 is fundamentally a perception-class problem; GUT cannot test human perception. Adding GUT tests for visual-gated surfaces would be a category error (memory `html5-visual-gated-author-self-soak` explicitly says GUT-green is necessary but not sufficient).
3. **"Move QA fully to Sponsor."** Considered. Rejected. `sponsor-decision-delegation` + `sponsor-does-not-review-prs-agents-do` memories explicitly bound Sponsor's role. Inverting this would re-introduce the M2 W3 problem (Sponsor as bug-discovery surface).
4. **"Slow down the velocity."** Considered. Rejected. Velocity is not the cost driver. PR #291's 7-iteration loop happened at slow-author-pace and would have happened at any pace; the iteration cause is structural (P1+P3), not throughput-related.
5. **"Restructure the roster."** Considered. Rejected. Drew, Devon, Uma, Tess, Priya have well-defined lanes and the lanes are working. The bottleneck is between merge and Sponsor-soak (a process gap), not between dispatch and merge (a roster question).

---

## §8 — Forward-looking watch signals

These are the indicators that tell us in 1-2 weeks whether the §5 mitigations are working.

1. **P1 watch:** does the next HTML5-visual-gated PR ship with the orch-side merge-gate check (Candidate A) and complete in ≤3 author iterations? If yes — Candidate A is holding. If no — escalate to Candidate D path-A (block merges on gated surfaces without Sponsor soak).
2. **P2 watch:** does the next 5 sub-agent final reports include CI-state citations? Track in orch run-log. If ≥4/5 do — Candidate C is holding. If <4/5 — strengthen the dispatch-template snippet wording.
3. **P3 watch:** does the next sub-agent dispatch brief omit a memory-rule reference that then gets violated? If yes — Candidate E (port to TESTING_BAR.md) is overdue, prioritize this week. If no — Candidate E timeline can hold.
4. **P6 positive watch:** does Tier 3 W1's remaining 5 tickets dispatch without clarification round-trips? If yes — ticket-quality is holding, no Candidate F needed.

Next retro: **M3 Tier 3 W1 close** (~5-7 days). Surface these watch signals; re-grade.

---

## §9 — Decision drafts (for next Priya weekly batch)

Per the centralized DECISIONS.md batching protocol (`team/priya-pl/decisions-batch-pr-template.md`):

- **Decision draft:** M3 Tier 2 retro grades **B** (overall). Top three patterns are P1 (headless-vs-real-browser perception gap), P2 (author optimism in Self-Test Reports / final reports), P3 (CI-green / GUT-green treated as sufficient despite codified rules). Top three mitigations are (A) orch-side merge-gate verification on HTML5-visual-gated PRs, (B) final-report claim-fidelity tightening (cite verifiable evidence), (C) port `html5-visual-gated-author-self-soak` + `tightened-final-report-contract` from auto-memory into `team/TESTING_BAR.md` for sub-agent visibility. All three within PL+orch mandate.
- **Decision draft:** Sponsor hypothesis 2 (ticket quality too vague) NOT SUPPORTED by evidence — Tier 3 W1's 7 tickets dispatched without clarification round-trips; ticket-quality contract codification (Candidate F) deferred.
- **Decision draft:** Sponsor decision required on soak-accelerator URL-param tooling (Candidate D). Recommendation: (B) approve and land in M3 Tier 3 W2 alongside camera-scroll retrofit.
- **Decision draft:** Next retro cadence — M3 Tier 3 W1 close (~5-7 days), then M3 Tier 3 W2 mid (~10-12 days), then Tier 3 close.

These batch into Priya's weekly Monday DECISIONS.md PR.

---

## Cross-references

- `team/priya-pl/ac4-white-whale-retro.md` — prior precedent for STRUCTURAL_GAP-leaning-MIXED retro grading
- `team/priya-pl/m2-week-2-retro.md` — C+ planning-quality retro (precedent for honest grading)
- `team/priya-pl/m2-week-3-mid-retro.md` — B+ velocity / process-gate installation retro
- `team/priya-pl/m3-tier3-w1-tickets.md` — current backlog (positive evidence on P6)
- `team/tess-qa/m3-acceptance-plan-tier-3.md` (PR #310) — Tess scaffold for Tier 3 acceptance
- Memory `html5-visual-gated-author-self-soak` (authored 2026-05-21 post-PR #291)
- Memory `tightened-final-report-contract` (authored 2026-05-15 post-M2 W3 mid-retro)
- Memory `parallel-dispatch-ticket-race` (authored 2026-05-22 post-Tier-3-W1-dispatch)
- `team/log/process-incidents.md` 2026-05-15 entry (sample-size discipline N≥8)
- PR #291 (the empirical anchor for P1+P3 — 7 author iterations, 2 Tess approvals overturned by Sponsor)
- PR #314 (the live empirical anchor for P2+P3 — Headless GUT failure today, "CI in flight" claim in author's report)
- PR #208 (precedent for P2 — "3/3 deterministic" claim falsified by reproduction)
- PR #300 (precedent for P2 — "infeasible from CLI" claim falsified by PR #291 v6 precedent)
- `.claude/docs/html5-export.md` § "Burst contrast against high-hue-saturation same-z sprites" — post-hoc design rule from PR #291 v5 finding
- `.claude/docs/test-conventions.md` § "Playwright headless ≠ real-browser perception" — codifies the P1 limit
