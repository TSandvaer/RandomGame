# Doc-drift audit — 2026-05-03

**Author:** Tess (run 025) — T-EXP-4 (ClickUp `86c9kzp45`).
**Scope:** read-only audit of cross-role + orchestrator-owned docs against current `main` (tip `4e0f27c`). Findings + suggested edits + severity. **No edits made in this PR** — fix-actions are filed as separate ClickUp tickets per "separate the audit from the fix" instruction.
**Method:** every drift call below is grounded in a direct read this session of (a) the doc as currently on `main`, and (b) the current state-of-truth artifact (STATE.md, DECISIONS.md, orchestrator memory, project files, recent PR history). Per `agent-verify-evidence.md` — no claim is from priors.

---

## TL;DR

- **Total drift findings:** 22 across 8 docs.
- **By severity:** 7 P0 (actively misleading agents), 9 P1 (stale but not dangerous), 6 P2 (cosmetic / outdated reference).
- **Top-3 highest-priority edits:**
  1. **`team/RESUME.md` — entire doc is M1-pre-integration** (stop point dated 2026-05-02 19:58, claims M1 "fully shipped" while the actual M1 finish line landed 2026-05-03 in PR #107 + bug-bash surfaced 8 bugs after that). **P0** — anyone reading this on resume gets a wrong picture.
  2. **`team/GIT_PROTOCOL.md` line 54 + Tess sign-off block** — the `chore(ci|build|repo)` self-merge ambiguity that triggered `team/log/process-incidents.md` 2026-05-02 entry is still in the doc unchanged. The doc also has zero mention of the new ClickUp-status-as-hard-gate rule and zero mention of the Self-Test Report gate. **P0** — directly contradicts orchestrator memory rules adopted today.
  3. **`team/orchestrator/dispatch-template.md` — missing Self-Test Report block + ClickUp lifecycle block** that the dispatch brief actually used to land this audit references. The template predates both rules. **P0** — every future dispatch lacks load-bearing context unless the orchestrator hand-authors them.

---

## Per-doc audit

### 1. `team/STATE.md`

| # | Section / Claim | Actual | Suggested edit | Severity |
|---|---|---|---|---|
| S-01 | Phase block (line 14): "Week 1 of M1. Project is **Embergrave**... Week-1 backlog of 20 tasks is live in ClickUp." | Project is post-M1-integration (PR #107 landed 2026-05-03), Sponsor M1 soak surfaced 2 P0 bugs (`86c9m36zh` combat-not-landing, `86c9m37q9` combat-invisible). M2 week-1 backlog already drafted (PR #97). Phase line is from week 1. | Update Phase to: `Phase 1 — M1 RC sign-off + bug-fix sweep` with current cycle (Sponsor soak ⟷ combat-fix dispatch ⟷ re-soak). | **P0** |
| S-02 | Tess section (line 81): `Last updated: 2026-05-02 (run 024)` and Status references run-024 bug-bash. | Run 024 was the bug-bash. This audit is run 025; STATE.md will be bumped this PR. (Self-call — flagging to verify the bump lands cleanly.) | (No edit needed in this audit — Tess section gets bumped to run-025 in this same PR per dispatch protocol.) | (own — no severity) |
| S-03 | Devon section (line 49): `run 013` listed as latest. Status: "PR open... awaiting Tess sign-off." | PR #107 (run 013's M1 integration) was MERGED by Tess in run 023 at squash `4484196` (verified `git log` line 5). Devon is currently in flight on `86c9m36zh` (combat-not-landing fix per orchestrator memory). | Devon section needs to reflect: PR #107 merged; current dispatch is `86c9m36zh` combat-fix (which bumps Devon to run 014 or 015). Devon owns the bump. | **P0** |
| S-04 | Drew section (line 65): `run 007` charger flake fix — "PR open... Tess sign-off required." | Drew run-007's PR #94 was MERGED by Tess in run 020 at squash `7697ca5` (verified `git log`). Drew is currently idle. | Drew section needs run 008 bump showing run-007 closed + idle. Drew owns the bump. | **P1** |
| S-05 | Uma section: run 008 listed as combat-visual-feedback. Status "PR open." | PR `uma/combat-visual-feedback` MERGED at squash `d006592` per `git log`. Uma is idle post-merge. | Uma section needs run 009 bump showing run-008 closed + idle. Uma owns the bump. | **P1** |
| S-06 | Priya section: run 008 risk-register-refresh listed as PR open. | PR `priya/risk-register-refresh-2026-05-03` MERGED at squash `0f8fcb8` per `git log`. Priya is idle post-merge. | Priya section needs run 009 bump showing run-008 closed + idle. Priya owns the bump. | **P1** |
| S-07 | "Open decisions awaiting orchestrator" (line 196): "(none — Uma's two pending cross-role calls resolved by orchestrator on resume 2026-05-02; see `DECISIONS.md`...)" | Stale — references resume of 2026-05-02. The current open-decision list is unknown but should at minimum reflect M1 Sponsor soak status + 2 P0 bugs in flight. | Refresh this block; current state likely = "Sponsor M1 soak in second pass post-combat-fix." | **P1** |
| S-08 | "Sponsor sign-off queue" (line 200): "(empty — next entry will be M1 First Playable build.)" | M1 RC has been delivered to Sponsor, soak cycle is iterating. Queue should reflect `M1 RC awaiting re-soak after combat-fix dispatch`. | Update to current cycle. | **P1** |

**Note on STATE.md drift class:** several role sections are stale because they show "PR open / awaiting sign-off" for PRs that have actually merged. This is a **systemic** issue — agents bump their own section on dispatch but don't bump it again at merge-confirm. The merger (Tess for feat/fix, orchestrator for chore/docs/design) doesn't currently touch the originating role's section. Suggest adding to dispatch template: "On merge, the merger flips the originating role's section status from 'PR open' to 'merged at <SHA>'" — or equivalent; would close S-03/S-04/S-05/S-06 class systemically.

### 2. `team/DECISIONS.md`

| # | Entry / Claim | Actual | Suggested edit | Severity |
|---|---|---|---|---|
| D-01 | Latest 2026-05-03 entry chain looks consistent: M1 integration → combat visual feedback → risk register refresh. | All three match `git log`. No drift. | None. | — |
| D-02 | 2026-05-02 entries (~36 of them — high density) — spot-check verified line 363 `2026-05-03 — M1 play loop integrated...` correctly cites PR `devon/m1-integration` + ClickUp `86c9m2jgu`. | Matches main. | None. | — |
| D-03 | Most 2026-05-02 entries should arguably be re-titled to reflect the actual landing date. Several were CREATED 2026-05-02 but the WORK LANDED 2026-05-03 (e.g., `Backlog expansion proposed` line 361 was authored 2026-05-02 but the audit itself is happening 2026-05-03). | Append-only log convention — entries are dated when authored, not when consumed. So the dates are fine. | No edit. (P2 — purely a "could be tidier" call; entries should stay as-is per append-only.) | **P2** |
| D-04 | Missing entries for M1 soak findings: 2 P0 bugs filed today (`86c9m36zh` combat-not-landing, `86c9m37q9` combat-invisible), and the bug-bash 8-finding output (`m1-bugbash-4484196.md`). DECISIONS.md doesn't carry decisions about these. | Decisions vs. ticket-creation are different things — these are bugs, not design decisions. Per the doc's intent (decision audit trail), the absence is correct. | No edit needed. Cited as a clarity check. | — |
| D-05 | Several recent entries (line 357 M2 week-1 backlog, line 361 backlog expansion) are anticipatory drafts rather than locked decisions — consistent with the doc's reversibility column. No drift. | OK as-is. | None. | — |

**DECISIONS.md verdict:** clean. Append-only discipline is holding. The only real concern is whether to add an entry today (2026-05-03) noting that **M1 RC discovery surfaced bugs that re-opened the soak loop** — but that's a status fact, not a decision, so probably belongs in STATE.md not DECISIONS.md.

### 3. `team/GIT_PROTOCOL.md`

| # | Section / Claim | Actual | Suggested edit | Severity |
|---|---|---|---|---|
| G-01 | Line 54: `Pure docs / chore(repo|ci|build) / design(spec) PRs — Tess sign-off is **not** required. The orchestrator (or Priya for chore(triage) / docs(team)) may merge directly.` | This wording allowed Devon run-008 to read it as a self-merge license (per `team/log/process-incidents.md` 2026-05-02). The clarification was logged but **the doc was never updated** with the suggested tightening. | Apply the tightening already drafted in `process-incidents.md`: `Tess sign-off is not required, but the merging identity must still be the orchestrator (or Priya for chore(triage) / docs(team)). Devs do not self-merge their own PRs in any category.` | **P0** |
| G-02 | Doc has **zero mention** of the `clickup-status-as-hard-gate` rule — every dispatch / PR-open / merge MUST be paired with the corresponding ClickUp status update in the same tool round. | This rule was adopted from MARIAN-TUTOR and is now in orchestrator memory. The protocol doc — the canonical "how do we work" reference for every role — is silent. | Add a new section "ClickUp lifecycle as hard gate" with the status-flip table (to do → in progress → ready for qa test → complete) tied to the workflow events (dispatch, PR open, merge, bounce). | **P0** |
| G-03 | Doc has **zero mention** of the Self-Test Report gate for UX-visible PRs. | Adopted from MARIAN-TUTOR after the Main.tscn-stub miss. The memory file (`self-test-report-gate.md`) explicitly says "Update GIT_PROTOCOL.md to add the gate to the Tess sign-off section." Not done. | Add a new section "Self-Test Report (UX-visible PRs)" with the comment template + the category-by-category gate (REQUIRED for `feat(integration|ui|combat|level|audio|progression|gear)`, `fix(ui|combat|level|audio|integration)`, certain `design(spec)`; NOT REQUIRED for `chore(ci|repo|build)`, `docs(team|scope)`, `chore(state|orchestrator|planning)`). | **P0** |
| G-04 | "On task start — mandatory ClickUp visibility flip" (line 8-11) — describes the `to do → in progress` flip but is silent on the `ready for qa test` and `complete` flips that the orchestrator memory now mandates as paired-with-PR-action. | Doc covers the front of the lifecycle, not the back. | Extend the flip rules to cover the full lifecycle (PR-open and merge) — mostly redundant with G-02 fix. | **P1** |
| G-05 | Worktree section (line 56-101) accurately describes W3-A7 option A role-persistent worktrees. | Verified against current branch + worktree state — section is fresh. | None. | — |
| G-06 | "Tess sign-off via PR" section (line 44-54) describes Tess approval+merge via `gh pr review --approve` then `gh pr merge --admin`. | Reality: harness denies self-approval (`gh pr review --approve` returns "can not approve your own pull request" — author identity matches). Tess delivers approval via `gh pr comment` instead, then merges. This is documented in `team/orchestrator/dispatch-template.md` "Self-merge denials" (line 71-75) but is NOT documented here in GIT_PROTOCOL. | Either link to dispatch-template.md's section or reproduce the workaround here. | **P1** |
| G-07 | Branch-naming examples (line 124-131) include `tess/m1-gut-phase-a` and `priya/week-2-backlog-promote` etc. — concrete examples. | Examples are dated (`week-2`) but representative. | No drift. | — |

### 4. `team/ROLES.md`

| # | Section / Claim | Actual | Suggested edit | Severity |
|---|---|---|---|---|
| R-01 | Tag list (line 35): includes `week-1, week-2, ...; combat, loot, ux, audio, ci, engine, ...`. | Per `team/log/clickup-pending.md` 2026-05-02 22:30 flush: tags `mobs, charger, ci-flake, html5, progression` are NOT existing tags in the ClickUp space. Only `bug, chore, week-3, design` are recognized. Doc lists tags as if all categories exist. | Update to reflect actual recognized tags + add a note that new tag categories require Sponsor / Priya space-level addition. | **P1** |
| R-02 | "Sponsor's hands-off rules" (line 17): "Orchestrator (this conversation) makes any cross-role call the PL escalates." | Per `sponsor-decision-delegation.md` orchestrator memory ("Sponsor delegates all team decisions") — Sponsor only signs off big deliveries; orchestrator makes recommended calls without escalation. The current ROLES wording implies escalation back to PL; the memory makes orchestrator + PL in fact the same decision-maker. | Tighten: orchestrator + PL together hold all team-call authority; sign-off is the only Sponsor moment. | **P2** |
| R-03 | Status flow (line 37): `to do → in progress (if available) → ready for qa test → complete`. "(if available)" qualifier predates the time when `in progress` became the status the team uses universally. | All four states are now in active use; "(if available)" is misleading. | Drop "(if available)". | **P2** |
| R-04 | Role table (line 7-11) — Priya described as owning "Backlog, ClickUp board, scope, schedule, tech-stack call, sign-off." | Per `backlog-expansion-2026-05-02.md` and the risk-register refresh, Priya does substantially more anticipatory backlog + risk register work than the original ROLES described. | Add "anticipatory backlog drafting (M2+, M3+) + risk register refresh + process-incidents log" to Priya's owned column. | **P2** |
| R-05 | Tess role line: "Test plans, manual + automated tests, bug reports, sign-off readiness." | Tess now also writes integration test code herself (`test_m1_play_loop.gd` — not authored by Devon; Tess wrote the catch-up acceptance plan + fixture catalog + paired-test index). The "writer of plans" → "active hammer" transition described in `TESTING_BAR.md` should also be reflected in ROLES.md. | Add "active integration test authoring + sign-off + product-vs-component verification" to Tess's owned column. | **P2** |

### 5. `team/RESUME.md`

| # | Section / Claim | Actual | Suggested edit | Severity |
|---|---|---|---|---|
| RE-01 | Title: "Resume Note — orchestrator stopped 2026-05-02 (third stop, M1 complete)." | The doc is dated 2026-05-02 19:58 and pre-dates the M1 integration miss + the entire integration discovery work that happened 2026-05-03. Sponsor's first soak surfaced the Main.tscn stub gap; the doc reads as if M1 was fully shippable + already verified. | Either rewrite for the current resume point OR add a "SUPERSEDED 2026-05-03" header at top with a forwarding note pointing at the most recent state file. | **P0** |
| RE-02 | "M1 acceptance criteria: 7 of 7 shipped + signed off + integration-tested. The build is end-to-end runnable + soak-ready." (line 9) | False as authored. The M1 build was a week-1 boot stub for ~30 PRs of "feature-complete" claims. PR #107 (2026-05-03) wired Main.tscn for the first time; bug-bash run 024 surfaced 8 more bugs (2 P0). | Strike this claim entirely OR rewrite to reflect that integration landed 2026-05-03 and is now in second soak cycle. | **P0** |
| RE-03 | "Test inventory: 557 GUT tests" (line 10). | Current count is 598 passing / 1 pending after PR #107 (per Tess run 023 verification). | Update to 598. | **P1** |
| RE-04 | "Repo... Tip: `8ed4da0` (Devon run-008 state). 77+ PRs merged this session." (line 8) | Tip is `4e0f27c` (per `git rev-parse origin/main`). 113+ PRs merged. | Update tip + count, OR rewrite the doc as suggested in RE-01. | **P1** |
| RE-05 | "Loose ends" line 37: "PR #78 — `chore(ci): hardening — cache + timeout + quarantine doc` ... CI hasn't run on the branch... **Do this on resume.**" | PR #78 was MERGED by Tess in run 017 at squash `04e290767...`. The "do this on resume" instruction is stale. | Strike. | **P0** |
| RE-06 | "Agent status at stop" (line 27-33) — every agent listed as `idle (run-N done)` with N from 2-3 days ago. | Agents have done many runs since (Devon at run 013, Drew at run 007, Tess at run 024, Priya at run 008, Uma at run 008). | Strike + redirect to STATE.md. | **P1** |
| RE-07 | "Operational learnings" (line 71) is largely correct except item 5 mentions "fresh Drew agent confidently refused a real bug" — a learning that's now in `agent-verify-evidence.md` orchestrator memory. The newer memories (`orchestrator-never-codes`, `always-parallel-dispatch`, `clickup-status-as-hard-gate`, `self-test-report-gate`, `product-vs-component-completeness`) aren't reflected here. | Doc predates these memories. | Either rewrite or add a "see orchestrator memory at C:/Users/538252/.claude/projects/.../memory/" reference. | **P1** |

**RESUME.md verdict:** **The doc as a whole is the single biggest drift artifact in the team folder.** It accurately describes a stop point that no longer represents reality. Rather than try to update each line, recommend either (a) wholesale rewrite to current state, or (b) deprecate and replace with a pointer to the live STATE.md + most recent session state-file.

### 6. `team/TESTING_BAR.md`

| # | Section / Claim | Actual | Suggested edit | Severity |
|---|---|---|---|---|
| T-01 | DoD #5 (line 19): "**Tess signs off** — Tess (or her agent on the next heartbeat) flips the task from `ready for qa test` to `complete`. Devs do **not** flip their own features to `complete`." | Aligned with `clickup-status-as-hard-gate.md` orchestrator memory. Holds. | None. | — |
| T-02 | DoD does NOT mention the **Self-Test Report** gate (UX-visible PRs require an author Self-Test Report comment before Tess reviews). | This is a new gate adopted today (`self-test-report-gate.md`). The TESTING_BAR is THE doc that should encode it. | Add a new DoD item #6.5 or expand #5 with: "For UX-visible PRs (per `self-test-report-gate.md` categories), the author posts a Self-Test Report comment **before** Tess's review begins. Tess bounces immediately if it's missing — don't burn review budget cold-reading a UX diff." | **P0** |
| T-03 | DoD does NOT mention the **product-vs-component-completeness** rule. | Adopted from the M1 Main.tscn-stub miss. TESTING_BAR is silent on "feature-complete = component-complete" vs. "feature-complete = wired into the play surface." | Add a new section: "Product completeness (per `product-vs-component-completeness.md`): a feature is not 'complete' until instantiated in the entry-scene's runtime tree. CI green + paired tests = component-complete. Sponsor sign-off requires product-complete." | **P0** |
| T-04 | "Tess: **Promoted from 'writer of plans' to 'active hammer.'**" (line 30) — accurate for the current world. | Holds. | None. | — |
| T-05 | "Test inventory targets for M1" (line 57): "Unit tests (GUT): ~20–30 tests..." | Current real M1 inventory is 598 tests / 1 pending — well above the target. The targets are met but the doc reads aspirational. | Update target line to reflect actual M1 outcome ("M1 closed at 598 tests / 5418 asserts; targets exceeded"). Or add a "M1 retrospective" footnote. | **P2** |
| T-06 | "Soak: at least one 30-minute uninterrupted play session per release candidate, by Tess." (line 65) | In practice, Sponsor does the M1 soak — Tess does code-audit + paired-test invariants for HTML5 (per `html5-rc-audit-591bcc8.md`) since Tess agents have no browser binary. | Reflect the actual operating pattern: Tess covers the audit + invariant tests, Sponsor does the interactive soak. | **P1** |

### 7. `team/CLICKUP_FALLBACK.md`

| # | Section / Claim | Actual | Suggested edit | Severity |
|---|---|---|---|---|
| C-01 | Whole doc is short (25 lines) and describes the queue → flush → sync flow accurately. | The 22:30 flush yesterday (per `clickup-pending.md`) followed this pattern exactly. Format spec matches what's in `clickup-synced.md`. | None. | — |
| C-02 | Pending queue format example (line 12-25) shows full YAML-style payload. | Actual usage in `clickup-pending.md` uses a simpler `ENTRY NNN: <ticket_id> -> <new_status>` form per `team/orchestrator/dispatch-template.md` line 67. **The two formats are inconsistent.** | Reconcile: either update CLICKUP_FALLBACK.md to show the simpler ENTRY format that's actually in use, OR update dispatch-template.md to require the YAML format. The simpler form has been working in practice — recommend updating fallback.md to match. | **P1** |
| C-03 | Tag-recognition warning is missing (only `bug, chore, week-3, design` are recognized; tags like `html5, progression, mobs, charger, ci-flake` are silently dropped on create). | Discovered during 22:30 flush. This is a real gotcha for any future create_task fallback. | Add a "Tag recognition" caveat section. | **P1** |

### 8. `team/orchestrator/dispatch-template.md`

| # | Section / Claim | Actual | Suggested edit | Severity |
|---|---|---|---|---|
| DT-01 | "Worktree state" + "Lesson reminder" + "Merge identity" + "STATE.md update" + "Done clause" + "ClickUp queue" sections — all present. | Verified — these are all in use in current dispatches (this audit's brief used them). | None. | — |
| DT-02 | **No `Self-Test Report required` block.** | Per `self-test-report-gate.md` orchestrator memory: "Update agent dispatch briefs for `feat(...)`, `fix(ui/integration/combat)`, `design(spec)` (when spec implies a buildable surface): include a 'Self-Test Report required' section in the Done clause." Not done. | Add a new section "Self-Test Report (UX-visible PRs)" with the template comment + categories. Cross-link to orchestrator memory. | **P0** |
| DT-03 | **No `ClickUp lifecycle` paired-flip block.** | Per `clickup-status-as-hard-gate.md` memory: dispatch and PR-open should be paired-flip operations. The dispatch-template only covers "queue when MCP is down" (line 62-69) but not the routine status-flips that happen even when MCP is up. | Add a new section "ClickUp lifecycle (in same tool round as dispatch action)" with the dispatch / PR-open / merge / bounce table. | **P0** |
| DT-04 | "Self-merge denials" section (line 71-75) describes the harness "cannot approve your own PR" workaround. | Verified — this pattern is in active use (every Tess sign-off run 010+ uses it). | None — accurate. | — |
| DT-05 | "Worktree cleanup" section (line 77-84) describes the local-branch-delete-fail-due-to-worktree-conflict pattern. | Verified — this pattern is in active use. | None. | — |
| DT-06 | "Merge identity" block (line 35-40) carefully enumerates which categories require Tess sign-off. | Aligned with corrected reading of GIT_PROTOCOL line 54 (per `process-incidents.md` 2026-05-02). | None — accurate (and ahead of GIT_PROTOCOL.md on this point — hence G-01). | — |
| DT-07 | "Lesson reminder" block (line 30) only cites `agent-verify-evidence.md`. | Several other memories now in active use (`orchestrator-never-codes`, `product-vs-component-completeness`, `always-parallel-dispatch`) aren't surfaced as load-bearing reminders. | Either rotate the reminder to current-most-relevant memory, or expand to cite the full memory directory. (Probably keep narrow — bloating defeats the "load-bearing" framing.) | **P2** |

---

## Recommended edit dispatches

| Doc | Owner suggestion | Estimated size | Trigger | Notes |
|---|---|---|---|---|
| `team/RESUME.md` | Orchestrator | M | Immediate | Wholesale rewrite or deprecate-with-pointer. The single biggest drift artifact. |
| `team/GIT_PROTOCOL.md` | Orchestrator (or Priya for `docs(team)`) | M | Immediate | Three P0 changes: G-01 self-merge tightening, G-02 ClickUp-lifecycle section, G-03 Self-Test Report section. |
| `team/orchestrator/dispatch-template.md` | Orchestrator | S | Immediate | Two P0 additions: DT-02 Self-Test Report block, DT-03 ClickUp lifecycle block. |
| `team/TESTING_BAR.md` | Tess | S | Soon | Two P0 additions: T-02 Self-Test Report DoD addendum, T-03 product-completeness rule. |
| `team/STATE.md` | Each role + orchestrator | S | Per-role bumps | S-01 Phase update (orchestrator); S-03/S-04/S-05/S-06 per-role bumps; S-07/S-08 Open-decisions + sponsor-queue refresh (orchestrator). Most should land naturally with each role's next dispatch. |
| `team/ROLES.md` | Priya | S | When dispatched | R-01 tag-list update is real; R-02/R-03 are tightening calls. R-04/R-05 reflect actual scope drift. |
| `team/CLICKUP_FALLBACK.md` | Orchestrator | XS | Soon | C-02 reconcile ENTRY-format with dispatch-template.md; C-03 add tag-recognition caveat. |
| `team/DECISIONS.md` | (no edit) | — | — | Clean — no drift found. |

**Suggested dispatch sequencing:**
1. **First wave (P0, parallel):** orchestrator dispatches itself to fix RESUME.md + GIT_PROTOCOL.md + dispatch-template.md + TESTING_BAR.md (the three orchestrator-owned docs land in one PR; Tess takes TESTING_BAR.md in a separate PR).
2. **Second wave (P1, parallel):** Priya for ROLES.md; orchestrator for CLICKUP_FALLBACK.md; per-role STATE.md bumps land naturally over the next few ticks.
3. **No third wave needed** — P2 items can rolled into the second-wave PRs at editor's discretion.

---

## Carry-forward (deferred to separate tickets)

- **STATE.md merger-side bump rule** (the systemic fix referenced in S-03/S-04/S-05/S-06): worth surfacing as a `docs(team): mergers update originating role's STATE on merge` PR — but isn't blocking and is a process refinement rather than a doc fix. **Not a P0**; defer to next process-incidents review.
- **Heartbeat ticks log + cron prompt update** for `dispatch-cadence-after-override.md` memory rule: the heartbeat mechanism isn't in any of the audited docs; that's an orchestrator-owned cron-prompt change, out of audit scope.
- **`team/log/process-incidents.md` extension** for the 5 process-incident classes hinted in `team/priya-pl/backlog-expansion-2026-05-02.md` T-EXP-5: separate ticket, separate PR.

---

## ClickUp tickets created from P0 drift

For each P0 finding (or P0 cluster), a `docs(team)` follow-up ticket has been filed in list `901523123922` per the dispatch instruction. See report for IDs.

---

## Methodology + verification trail

Per `agent-verify-evidence.md`: every drift call above is grounded in:
- A direct read of the cited doc on `main` tip `4e0f27c` THIS session via Read or Grep tools.
- A cross-check against current state-of-truth (STATE.md role sections, DECISIONS.md latest entries, `git log` on `main`, orchestrator memory at `C:/Users/538252/.claude/projects/c--Trunk-PRIVATE-RandomGame/memory/`, `team/log/process-incidents.md`, `team/log/clickup-pending.md`, `team/log/clickup-synced.md`).
- No claim derived from priors. Where I couldn't verify, the row is marked "(no severity)" or moved to carry-forward.

**Files NOT audited per dispatch scope:**
- `team/uma-ux/*`, `team/devon-dev/*`, `team/drew-dev/*`, `team/priya-pl/*`, `team/tess-qa/*` (per-role design docs — out of scope; too many).
- `team/tess-qa/m1-bugbash-4484196.md` (just landed; my own output).
- `team/log/heartbeats.md`, `team/log/w3-a7-worktree-isolation-proposal.md`, run-logs (out of scope).

**Self-call (Tess STATE section):** S-02 — flagged my own STATE.md section will be bumped to run-025 in this PR. Honest disclosure per dispatch: "Particularly: Devon, Drew, Uma, Priya, Tess (your own — be honest)."
