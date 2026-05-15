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

---

## 2026-05-02 — Worktree-isolation v3 — 4-occurrence shared-HEAD friction pattern

- Filed by: Priya (run 013, normalization sweep — covers 4 in-session occurrences originally surfaced by Orchestrator W3-A7 proposal)
- Severity: medium (pure friction tax — no defect, but recurred 4× in a single session)
- Repeat?: 4th occurrence (consolidated; threshold for protocol-clarification action met)
- What happened: Across one session, four agents had `.git/HEAD` flipped under them mid-tool-call by parallel dispatches sharing the orchestrator-class checkout `c:\Trunk\PRIVATE\RandomGame`. (i) Uma run-002 — `git checkout -b` landed Uma's HEAD on `devon/levelup-math` instead of newly-created `uma/audio-direction`; recovered via cherry-pick + `git branch -f`. (ii) Uma run-003 — same root cause during audio-direction work; cherry-pick recovery again. (iii) Priya run-004 — HEAD shifted to `tess/run-012-state-v2` mid-tool-call during mid-week-2 retro; one stash-pop conflict cost. (iv) Tess run-018 — main checkout was on `uma/stash-ui-v1-design` mid-Tess-run when Uma's parallel W3-B1 dispatch landed PR #82 on `origin/main`; recovered via stash → checkout `tess/w3-a5-html5-audit` → fast-forward rebase onto `c8a6b69` → pop. Each occurrence cost 1-3 tool turns of recovery.
- Why it didn't cause a defect: All four recovered cleanly without rewriting anyone else's history; no merged-PR mistakes, no data loss, no production-side incidents.
- Protocol clarification: `team/orchestrator/dispatch-template.md` and `team/GIT_PROTOCOL.md` were updated by W3-A7 v3 to mandate per-role persistent worktrees (`RandomGame-<role>-wt`) with a brief-template snippet pinning `cd <worktree> && git fetch origin && git checkout -B <role>/<task-name> origin/main` at run-start. Codification source: `team/log/w3-a7-worktree-isolation-proposal.md` §2 (Option A.1).
- Action taken: clarification PR filed (W3-A7 v3 dispatch-template + GIT_PROTOCOL worktree section landed pre-PR-#127). Pattern is now expected to be eliminated; this entry exists for retroactive log completeness and pattern-watch — if a 5th occurrence lands AFTER worktree-v3 brief is in place, escalate to Devon for harness-side `WorktreeCreate` hook (option B in the proposal).

---

## 2026-05-02 — Spec-sketch vs. ticket-implementation drift (N7 affix-count)

- Filed by: Priya (run 013, normalization sweep — pattern surfaced during N7 affix work)
- Severity: low
- Repeat?: first occurrence (logged for pattern-watch)
- What happened: Drew's N7 affix implementation kept the existing affix-schema (count + ranges per rarity) rather than the count specifically sketched in the N7 ticket body. Drew's implementation is sound and matches the prior balance-pin doc; the ticket sketch's count was a casual estimate, not a balance decision. Tess flagged the mismatch during review; Priya confirmed the existing schema as source-of-truth.
- Why it didn't cause a defect: existing balance-pin (`team/priya-pl/affix-balance-pin.md`) is the actual decision record; ticket sketches are working notes. Drew's read of "follow the pin, not the ticket sketch" was the correct call. PR landed without revision needed.
- Protocol clarification: ticket bodies sometimes contain quick-sketch numbers that contradict pinned design docs. Convention: when a ticket sketch and a design pin disagree, the design pin wins; the implementer should call out the discrepancy in the PR body (one-liner: "Ticket sketch said X, balance-pin says Y, kept Y — flagging for Priya"). Suggested addition to `team/orchestrator/dispatch-template.md` "Scoped contract" block: "Ticket-body numbers are sketches unless explicitly cited from a design pin. When in doubt, pinned design > ticket sketch; flag the discrepancy in PR body."
- Action taken: log only — first occurrence. If pattern recurs (≥3 occurrences), file a `docs(team)` PR adding the convention to `dispatch-template.md`.

---

## 2026-05-02 — `clickup-pending.md` parallel-edit conflict pattern (default-to-main resolution)

- Filed by: Priya (run 013, normalization sweep)
- Severity: low
- Repeat?: 2nd occurrence (logged for pattern-watch)
- What happened: `team/log/clickup-pending.md` was edited by two agents in parallel ticks across separate dispatches; merge surfaced a textual conflict on the queue rows. Both agents' adds were valid (different ticket IDs, same file region). Resolver defaulted to `main`'s version and re-appended the local add as a fresh row, rather than attempting a hand-merge that risked losing either side's intent.
- Why it didn't cause a defect: queue rows are append-only metadata; no row was actually lost. The "default to main + re-append local" strategy preserves both sides' intent and is reversible if either entry was already processed.
- Protocol clarification: `clickup-pending.md` is a hot-spot for parallel edits because every dispatch pairs ClickUp queue actions with a same-tick log line. Convention now in use: on conflict, prefer `main`'s version and re-append local adds at the bottom of the queue section. Codified in `team/orchestrator/dispatch-template.md` "Scoped contract" / conflict-rule block (PR #127 added the Scoped-contract block; the file-conflict line is implicit in "preempts blind-resolve into another role's lane" — explicit codification deferred unless this hits a 3rd occurrence).
- Action taken: log only. Pattern-watch: if a 3rd parallel-edit conflict lands on this file, file an explicit `docs(team)` clarification adding "default-to-main + re-append" verbatim to `dispatch-template.md`.

---

## 2026-05-03 — PR-body test-count drift (Drew run-012)

- Filed by: Priya (run 013, normalization sweep — pattern surfaced during Drew run-012 review)
- Severity: low
- Repeat?: first occurrence (logged for pattern-watch)
- What happened: Drew run-012 PR body claimed "30 tests added" while the actual diff added 28. The 2-test gap came from two test cases that were drafted in the working branch but consolidated into existing parametric cases before push; the PR body was authored before the consolidation and not updated. Tess caught the drift on review and confirmed the actual count was correct.
- Why it didn't cause a defect: the test suite is correct; only the PR body was stale. CI green on the actual 28; no test was missing.
- Protocol clarification: PR-body claims about test counts (and other concrete numbers — file counts, line deltas, AC checkbox states) drift if authored pre-final-push. Convention reminder: re-read your own diff after final `git push` and reconcile any concrete numerical claims in the PR body. `team/TESTING_BAR.md` Self-Test Report DoD (added in PR #127) implicitly captures this for UX-visible PRs; for non-UX-visible PRs, the discipline is informal.
- Action taken: log only — first occurrence. If pattern recurs, consider extending the Self-Test Report convention to all PRs with a "test-count line in PR body must match diff" check.

---

## 2026-05-04 — Harness-identity self-approval pattern (cross-run)

- Filed by: Priya (run 013, normalization sweep — pattern surfaced across runs 010-022)
- Severity: low
- Repeat?: Nth occurrence (logged once retroactively — recurs every time a docs/chore PR opens because GitHub blocks self-review by the same identity)
- What happened: Across runs 010 through 022, multiple agents attempted `gh pr review --approve` on PRs they had themselves opened. GitHub's API correctly rejects with "can not approve your own pull request" because the harness-bound identity `RandomGame Orchestrator` is the author of every commit and every PR opened by every agent in the system. The agents' intent was sometimes to record a "self-test passed, ready for Tess" signal; the rejection surfaced repeatedly because no agent's local memory carried the prior occurrence.
- Why it didn't cause a defect: GitHub blocks the action server-side; nothing merged through self-approval. Agents fell back to PR-body Self-Test Reports or comments instead.
- Protocol clarification: harness-identity is shared across all five named agents and the orchestrator (single GitHub identity `RandomGame Orchestrator`). "Self-approval" can never succeed and should not be attempted. The Self-Test Report convention added to `team/GIT_PROTOCOL.md` and `team/TESTING_BAR.md` in PR #127 is the canonical channel for "author-side green" signal, replacing any past attempt to use `gh pr review --approve` on own PR. Reviewer-identity authority belongs to Tess (or orchestrator for `docs(team)` / `chore(ci|repo|build)` exemptions); self-approval is structurally impossible in this team's harness.
- Action taken: log only (retroactive, consolidated across N occurrences). Pattern is now structurally addressed by the Self-Test Report convention; future occurrences should be near-zero. If an agent still attempts self-approval after PR #127's conventions land, treat as a brief-comprehension miss and reinforce the dispatch template wording.

---

## 2026-05-06 — HTML5 visual-feedback no-op (white-on-white modulate cascade) — latent since PR #115

- Filed by: Tess (run 032)
- Severity: high
- Repeat?: first occurrence (logged + pattern-watched)
- What happened: Sponsor's HTML5 `[combat-trace]` soak on RC `f62991f` (2026-05-06) confirmed three independent visual-feedback bugs that had shipped clean through Tess's PR #115 + #122 sign-offs and stayed latent on production for ~3 days. (1) **Mob hit-flash white-on-white modulate cascade** — PR #115 tweens parent `CharacterBody2D.modulate` from `Color(1,1,1,1)` to `Color(1,1,1,1)` and back; zero delta, and the multiplicative cascade onto a child Sprite with non-white modulate would have killed any notional delta anyway. **Platform-agnostic** — broken on desktop too, but masked because Sponsor's pre-PR-#136 desktop sessions were short. (2) **Player ember-flash HDR clamp** — `Color(1.4, 1.0, 0.7, 1)` clamps to `Color(1.0, 1.0, 0.7, 1)` on `gl_compatibility` HTML5; Devon's lane. (3) **Polygon2D swing-wedge invisibility** on `gl_compatibility` HTML5 web export; Devon's lane. The headless GUT suite asserted `tween.is_valid()`, `tween.is_running()`, constant equality (`HIT_FLASH_HOLD == 0.020`), and the load-bearing `mob_died`-fires-at-frame-1 contract — all green. None asserted observable color delta or that the modulate landed on the visible-draw target.
- Why it didn't cause a permanent defect: Drew's PR #136 functional safety-net (parallel `SceneTreeTimer` decoupled from death-tween) prevents combat from softlocking even with broken visuals; mobs still die and rooms still clear. Sponsor caught it on the diagnostic soak before Tess's RC1-soak ticket ran on the broken artifact.
- Protocol clarification: the existing test bar (paired GUT + Self-Test Report + HTML5 visual-verification gate per `html5-visual-verification-gate.md`) was insufficient — it permitted "tween fires" assertions without "tween fires AND target ≠ rest AND lands on visible-draw target." This PR adds the **"Visual primitives — observable delta required"** section to `team/TESTING_BAR.md` codifying Tier 1 (target ≠ rest, mandatory) + Tier 2 (visible-draw-target landing for cascading modulate, mandatory) + Tier 3 (framebuffer pixel-delta, aspirational pending headed-CI-renderer lane) as the floor for visual-primitive tests. Future visual-feedback PRs that ship without these assertions get bounced.
- Action taken: clarification PR filed (this PR — `qa(test-framework): require observable color delta in visual-primitive tests`). Full postmortem in `team/log/2026-05-html5-visual-feedback-no-op-postmortem.md`. Drew owns the white-on-white functional fix on `86c9ncd9g`; Devon owns the HDR + Polygon2D HTML5 fixes (separate ticket / dispatch). Pattern-watch: if a 2nd visual-feedback no-op surfaces post-policy-merge, escalate to Devon for a renderer-painting CI lane (`--rendering-driver opengl3` headed mode in xvfb on Linux runners) so Tier 3 framebuffer assertions become enforceable rather than aspirational.

---

## 2026-05-15 — Sample-size discipline for re-introducing flaky tests

- Filed by: Tess (M2 W3 owed-doc-updates pass)
- Severity: medium (a lucky-roll N=3 sign-off shipped on PR #208 and concealed a still-live engage-lethality bug — caught post-merge by PR #212's N=6 release-build re-run, but the merge gate failed to block it)
- Repeat?: first occurrence (logged + structural mitigation proposed)
- What happened: PR #208 (`fix(harness|level): Room 05 gate unlock — dismiss auto-opened level-up panel + paired GUT pin (#86c9u6uhg)`) shipped with a Self-Test Report claiming "3/3 deterministic" runs against the release artifact. Post-merge, Drew's PR #212 (`fix(harness): Room 06 multi-mob return-to-spawn — extend PR #190 pattern to chase + chaser-clear chain (#86c9u9neq)`) ran 6 release-build AC4 runs against PR #208's baseline artifact during the multi-chaser pattern's empirical verification — **5 of 6 ended with `Player._die` in Room 05 mid-multi-chaser-engage**, with the underlying engage-lethality issue persisting (filed as ticket `86c9uf1x8`). PR #208's "3/3 deterministic" sample was a lucky-roll outlier. Drew's follow-up PR #221 (`fix(combat): Room 04 Shooter AI engagement — diagnose-via-trace + fix broken transitions (#86c9uehaq)`) explicitly applied an **N≥8 sample-size discipline** (8/8 Playwright runs to claim determinism) as the corrective baseline.
- Why it didn't cause a permanent defect: PR #212's release-build re-run caught the regression before AC4 was claimed clear; the engage-lethality bug is now a known open ticket (`86c9uf1x8`) rather than a silent shipped defect. The orchestrator's M2 W3 multi-PR cycle absorbed the lucky-roll without milestone slip.
- Protocol clarification: the existing testing bar (`team/TESTING_BAR.md` § DoD + § Self-Test Report) does not pin a **minimum sample size** for Self-Test Reports of flaky-test re-introduction. PR #208's "3/3 deterministic" claim was within the literal letter of the bar — the gap is that **N=3 is not a determinism claim when the prior failure rate is unknown**. The standard "you saw 3 greens, the next one is a coin-flip" sampling-statistics intuition was not encoded anywhere reviewers were forced to read. **Recommended structural fix:** amend `team/TESTING_BAR.md` § DoD #6 (Self-Test Report) with a flaky-test-reintroduction clause requiring **N≥8 successful runs against the release-build artifact** for any PR that re-enables a previously-flaky spec, removes a `test.fail()` / `test.skip()` annotation, or claims determinism on a path that has bounced in prior soaks. Mirror the clause into `team/orchestrator/dispatch-template.md` § Self-Test Report so dispatch briefs surface the expectation up-front. PR #221's `8/8 release-build Playwright runs` Self-Test Report shape is the canonical template; reviewers (Tess + peer) ding any "3/3" claim on flaky-reintroduction PRs.
- Cross-reference: PR #208 (lucky-roll source), PR #212 (5/6 reproduction that invalidated #208's claim), PR #221 (N≥8 corrective baseline), ticket `86c9uf1x8` (persisting engage-lethality issue this incident surfaced).
- Action taken: log + structural-mitigation PR queued (this PR is doc-only — process-incident entry + harness-design convention; the paired `team/TESTING_BAR.md` + `dispatch-template.md` amendment lands as a separate `docs(team)` PR after orchestrator/Priya routes the clause wording). Pattern-watch: if a second "deterministic" claim with N<8 ships on a flaky-reintroduction path post-amendment, escalate to a hard CI-gate (release-build re-run loop enforced by workflow, not by reviewer discipline).
