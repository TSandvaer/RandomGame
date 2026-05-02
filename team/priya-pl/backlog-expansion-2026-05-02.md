# Backlog Expansion — 2026-05-02 (envelope-fill while Sponsor OUT)

**Owner:** Priya · **Tick:** 2026-05-02 (post-22:33 heartbeat — `main` tip `353f914` — Sponsor OUT, M1 gated on his interactive 30-min soak) · **Status:** DRAFT — orchestrator decides which P0s actually dispatch this session.

This doc is generated to **fill the dispatch envelope**. The user's standing instruction is "keep dispatching until you hit a real blocker requiring user input." The previously-identified ticket envelope (Half-A close, Half-B design, M1-residual fixes, M2 week-1 backlog draft, T12 acceptance plan, S3-S8 palette refinement) is **all closed on `main`**. Without new ticket-shapes, the team idles. This doc surfaces 8 new ticket-shapes that genuinely don't need Sponsor sign-off.

## TL;DR (5 lines)

1. **Tickets proposed:** 8 new ticket-shapes (3 P0, 4 P1, 1 P2). All genuinely dispatchable without Sponsor input — pure design / planning / doc / ops / fixtures-for-locked-designs / postmortem.
2. **Expected throughput value:** if all 3 P0s dispatch this session, ~4–6 hours of orchestrated work absorbed; team stays productive instead of idling.
3. **Sponsor-gating verdict:** zero blocking pre-conditions on any of the 8 tickets. Two carry "Sponsor may revise post-soak" caveats (T-EXP-1 M2 week-2 backlog, T-EXP-7 sponsor-soak prep) — both are anticipatory drafts, revisable in-place.
4. **Top 3 highest-leverage:** T-EXP-3 (risk register refresh — 1 tick, unblocks PL situational awareness), T-EXP-1 (M2 week-2 backlog — extends planning runway by another week), T-EXP-2 (performance budget spec — gates M2 regressions before they happen).
5. **ClickUp side-effect:** create the 3 P0 tasks in list `901523123922` via live MCP. Don't pre-create P1/P2 — those wait for orchestrator's "yes, dispatch."

---

## Source of truth (what was read to scope this)

Every ticket-shape below derives from a direct read of an existing artifact, per `agent-verify-evidence.md`. The reads:

1. **`team/STATE.md`** (run-022 Tess tip) — confirms M1 RC `embergrave-html5-ceb6430` is the latest playable, all CR-1/CR-2/CR-3 closed, charger flake closed, soak-target unchanged. Confirms zero open dispatch envelope: every named role's "Next" is contingent on Sponsor M1 sign-off OR on already-shipped Half-B docs.
2. **`team/DECISIONS.md`** (357 lines, last entry: M2 week-1 backlog drafted 2026-05-02) — confirms decisions land at the rate of one per design dispatch; no audio-aesthetic / 5-bus / OGG / cue-ID decisions formally appended yet (Uma carry-forward).
3. **`team/priya-pl/risk-register.md`** — last refresh was mid-week-2 retro. Several R-rows are stale: R3 status post-W3-A5 closure, R7 status post-affix-balance-pin, R6 disposition while Sponsor OUT. R8 / R9 / R10 (NEW M2 risks) live in `m2-week-1-backlog.md` but not synced into the register doc itself.
4. **`team/priya-pl/m2-week-1-backlog.md`** — confirms shape and depth conventions for an anticipatory week backlog. T-EXP-1 mirrors this template one week further out.
5. **`team/log/process-incidents.md`** (1 entry — Devon PR #76 self-merge, 2026-05-02) — only one logged incident. The run-22:33 heartbeat note ("4 worktree-isolation incidents") suggests other patterns may not have been individually logged.
6. **`team/log/clickup-pending.md`** — recognized space tags audit (only `bug`, `chore`, `week-3`, `feat`, `qa`, `design` accepted at space-level; `mobs`, `charger`, `ci-flake`, `html5`, `progression` rejected on creation). Authoritative tag list for new ticket creation.
7. **`team/uma-ux/audio-direction.md`** (234 lines, 60+ cue rows). Confirms Uma's audio-sourcing pipeline is doc-anchored but operationally unspecified — cue rows say "freesound" or "hand-composed" or "AI-curated" but no flow doc says how those routes actually decide.
8. **`team/devon-dev/ci-hardening.md`** (254 lines). Confirms CI hardening v1 landed cleanly (cache + concurrency + timeout + GUT retry + flake-quarantine doc) but explicitly defers per-test runtime profiling, docker-image cache, automated coverage reports as v2 follow-ups.

---

## Per-category survey

### Category A — Forward planning (M2 week-2, M3 framing)

**Gap:** week-1 M2 backlog landed; week 2 is silent. M3 framing has zero design surface (`mvp-scope.md` enumerates M3 as "deferred" — no shape).

**Worth filling now?** Yes. M2 week-2 mirrors week-1 in shape; risk of going stale is symmetric and revisable in-place. M3 framing is more speculative — defer until week-1 actual ships. **Pick: T-EXP-1 (M2 week-2 backlog, P1).**

### Category B — Risk + register refresh

**Gap:** risk register was last touched mid-week-2 retro; R3 / R6 / R7 are all materially stale. R8 / R9 / R10 (the NEW M2 risks) live in `m2-week-1-backlog.md` only. PL situational-awareness erodes if the register doesn't get refreshed.

**Worth filling now?** Yes — single tick, high leverage. **Pick: T-EXP-3 (risk register refresh, P0).**

### Category C — Performance + telemetry spec

**Gap:** no FPS / memory / draw-call targets formalized. M1 hits some real numbers (497–586-test suite, ~1m20s CI, 8.49 MB HTML5 build) but those aren't *budgets*. M2 introduces six new HTML5 surfaces (R3 escalation); without budgets, regressions slip in unnoticed.

**Telemetry separately:** no analytics scaffold. Sponsor's only signal today is interactive-soak. If M2 introduces stash + recovery loops, instrumented telemetry would be cheap-to-instrument vs. expensive-to-playtest.

**Worth filling now?** Performance budget — yes (gates M2 regressions). Telemetry — defer to M3 (premature instrumentation per `mvp-scope.md` discipline). **Pick: T-EXP-2 (performance budget spec, P0).**

### Category D — Documentation gap audit

**Gap:** STATE.md, DECISIONS.md, ROLES.md, GIT_PROTOCOL.md may have drifted. W3-A7 just rewrote worktree-isolation language; other sections untouched recently. ROLES.md hasn't been re-read this milestone.

**Worth filling now?** Yes — single tick, low risk, surface drift before M2 onset. **Pick: T-EXP-4 (doc audit pass, P0).**

### Category E — Cross-role process surfaces

**Gap:** `process-incidents.md` has 1 entry. The W3-A7 4-occurrence pattern was captured in `w3-a7-worktree-isolation-proposal.md` but not normalized into incident format. Other slips (e.g., the affix-count spec deviation in N7, the PR-body test-count drift in run-012, the file-conflict pattern on `clickup-pending.md`) are scattered across STATE.md retros but not centralized.

**Worth filling now?** Lower leverage than risk register. Defer. **Pick: T-EXP-5 (process-incidents normalization, P1).**

### Category F — Sponsor-soak prep

**Gap:** Sponsor's "first hour" Sponsor experience could be smoother. Tess's `m2-acceptance-plan-week-1.md` §"Sponsor probe targets" is a start (M2-specific). M1 has no equivalent. Pre-soak actions could include: a probe-target checklist, a "questions to ask after each death" prompt, an explicit "what's still placeholder" note.

**Worth filling now?** Speculative — Sponsor may sign off cleanly without needing this. But it's cheap to author and lands as evergreen wisdom. **Pick: T-EXP-7 (sponsor-soak prep checklist, P1).**

### Category G — Audio sourcing pipeline

**Gap:** `audio-direction.md` has 60+ cue rows tagged "freesound" / "hand-composed" / "AI-curated" but no flow doc says which route decides for which cue or how the actual sourcing-action happens. Uma's M2 week-1 ticket (T10) is "sourcing or placeholder" — operationally vague.

**Worth filling now?** Yes — operationally unblocking. Uma needs this to dispatch effectively when M2 audio rows fire. **Pick: T-EXP-6 (audio sourcing operations doc, P1).**

### Category H — Build pipeline hardening v2

**Gap:** Devon's `ci-hardening.md` explicitly enumerates deferred follow-ups (docker-image cache, per-test runtime profiling, automated coverage reports). All are still open.

**Worth filling now?** Lower leverage than the gaps above. CI is healthy at ~1m20s; runtime budget enforcement is premature per Devon's own §"Items deferred". Defer to a later expansion. **Skip.**

### Category I — Worktree v2 cleanup / charger flake postmortem

**Worktree v2 cleanup:** stale ephemeral worktrees may exist (`RandomGame-uma-stratum-2`, etc.). One-tick housekeeping. **Skip — low value, no real signal that they're causing harm.**

**Charger flake postmortem:** Drew's PR #94 fix shipped but the lesson ("test-passes-with-overridden-speed-but-fails-on-default") is reusable. Worth writing up but lower leverage than the items above. **Pick: T-EXP-8 (charger flake postmortem, P2).**

### Category J — Localization / accessibility scaffold

**Gap:** `palette.md` mentions accessibility forecasts per stratum. No localization scaffold anywhere. Both eventually needed.

**Worth filling now?** No — too speculative; M2 doesn't need it. **Skip — re-evaluate at M3 framing.**

---

## Tickets — backlog expansion (8 new ticket-shapes)

Each row: working title (`<conv-commit>: <scope>`), owner, dependencies, size (S/M/L), priority (P0/P1/P2), 3–5 acceptance criteria, why-now-vs-defer.

### T-EXP-1 — `chore(planning): M2 week-2 backlog draft (anticipatory)`

- **Working title:** `chore(planning): M2 week-2 backlog draft (anticipatory)`
- **Owner:** Priya
- **Dependencies:** none. M2 week-1 backlog as design template (`team/priya-pl/m2-week-1-backlog.md`).
- **Size:** M (3–5 ticks)
- **Priority:** **P1** (anticipatory; defer until P0s placed)
- **Acceptance criteria:**
  1. New doc `team/priya-pl/m2-week-2-backlog.md` modeled on week-1 (TL;DR + source-of-truth + tickets + risks + capacity + open questions).
  2. ~10–14 tickets covering soft-retint sprite work (Charger / Shooter / Pickup / Ember-bag / Stash chest deferred from T4), S2 second room (s2_room02), S2 boss room substitute (or pure-S2-room descent terminator), MobRegistry refactor (deferred from T6 stretch), audio sourcing close-out, M2 polish bug-bash equivalent.
  3. Critical chain identified, owners assigned.
  4. DECISIONS.md one-line append.
- **Why now (vs. defer):** week-1 backlog could land in dispatch immediately when Sponsor signs off; week-2 silence creates a planning gap if week-1 finishes faster than expected. Anticipatory drafts are explicitly precedented (week-1 backlog itself was anticipatory).

### T-EXP-2 — `design(spec): performance budget — FPS / memory / draw-call targets for HTML5`

- **Working title:** `design(spec): performance budget for HTML5 build`
- **Owner:** Devon (primary; Tess assists on measurement methodology)
- **Dependencies:** existing M1 RC `ceb6430` build artifact (8.49 MB HTML5) as baseline reference.
- **Size:** M (3–5 ticks)
- **Priority:** **P0**
- **Acceptance criteria:**
  1. New doc `team/devon-dev/performance-budget.md` codifying HTML5 targets — minimum FPS (e.g., 60 / 30 / 20 thresholds), max heap memory, max draw-calls per frame, max audio-decode latency on stratum entry, max CI test runtime, max HTML5 build size MB.
  2. Per-target measurement methodology (browser DevTools Performance panel for FPS / heap, GUT timing for CI, `gh release view` for build size).
  3. Per-target action thresholds (warn / fail) — what triggers a regression dispatch vs. an FYI note.
  4. M1 baseline numbers populated for each target (current state as the floor).
  5. M2 fail-fast gates identified — at least one budget tied to T11 M2 RC build pipeline as automated regression check.
- **Why now (vs. defer):** R3 escalation flagged six new HTML5 surfaces in M2 week 1. Without a performance budget, regressions slip in silently and only surface on Sponsor's next soak. Codifying budgets now is cheap; codifying after a regression is expensive (incident-driven, with Sponsor signal already lost).

### T-EXP-3 — `chore(risk): risk register refresh — post-W3 close + M2-onset re-score`

- **Working title:** `chore(risk): risk register refresh post-W3 close`
- **Owner:** Priya
- **Dependencies:** none.
- **Size:** S (1–2 ticks)
- **Priority:** **P0**
- **Acceptance criteria:**
  1. Edit `team/priya-pl/risk-register.md` reflecting current state: R3 (W3-A5 audit closed by `b704345`; CR-1/CR-2/CR-3 all resolved — re-score to held-but-watching for M2 escalation), R6 (Sponsor still OUT — held; re-promote when soak fires), R7 (resolved by affix-balance-pin — move to Retired with link), R5 (W3-A7 v3 worktree-isolation live — re-score to low/low).
  2. R8 / R9 / R10 (M2 risks living in `m2-week-1-backlog.md`) synced into the central register doc so PL has a single source.
  3. New "Retired" section populated (R7 first entry).
  4. Top-3 active risks for M2-onset re-stated in §1 mid-document summary.
  5. Doc tick-stamp updated to 2026-05-02 (M1-feature-complete, Sponsor OUT, pre-M2-dispatch).
- **Why now (vs. defer):** PL situational awareness depends on this doc being current. Two milestones' risks are now mixed; refresh costs 1 tick and leaves the register clean for M2 dispatch decisions.

### T-EXP-4 — `docs(team): documentation gap audit — STATE / DECISIONS / ROLES / GIT_PROTOCOL drift check`

- **Working title:** `docs(team): doc-drift audit pass`
- **Owner:** Priya (or orchestrator — single-tick repo-wide read)
- **Dependencies:** none.
- **Size:** S (1–2 ticks)
- **Priority:** **P0**
- **Acceptance criteria:**
  1. Read all four docs end-to-end: `team/ROLES.md`, `team/GIT_PROTOCOL.md`, `team/STATE.md` boilerplate (lines 1–17), `team/DECISIONS.md` header.
  2. Cross-check against current operative reality: 5-named-agent roster (correct), worktree pattern v3 (`GIT_PROTOCOL.md` lines 56–101 — recently updated, spot-check vs. STATE.md role rows), Tess-sign-off matrix (current process-incidents 1-row evidence), append-only DECISIONS conventions.
  3. File a list of drifts found (or "no drifts found" — also valid output).
  4. Patch any drift inline as part of this PR (fix-forward; if drift requires Sponsor input, file as Open Question and exit cleanly).
  5. New doc `team/log/doc-audit-2026-05-02.md` capturing the audit results (or in-place STATE.md note if drift count is zero).
- **Why now (vs. defer):** W3-A7 just rewrote worktree-isolation language. Other sections may have drifted in parallel. Cheaper to audit before M2 dispatch than to discover drift mid-M2 (where it would slow agents).

### T-EXP-5 — `docs(team): process-incidents normalization — log scattered slips into central format`

- **Working title:** `docs(team): process-incidents log normalization`
- **Owner:** Priya
- **Dependencies:** existing `team/log/process-incidents.md` (1 entry) as template; `team/log/w3-a7-worktree-isolation-proposal.md` as evidence source.
- **Size:** S (1–2 ticks)
- **Priority:** **P1**
- **Acceptance criteria:**
  1. Add 3–5 new entries to `process-incidents.md` covering: (a) the W3-A7 4-occurrence shared-HEAD pattern (Uma run-002, Uma run-003, Priya run-004, Tess run-018) — one consolidated entry referencing the proposal doc as evidence source; (b) the affix-count spec deviation pattern (N7 Drew kept existing schema vs. ticket sketch — pattern for "spec sketch vs. ticket implementation drift"); (c) the file-conflict pattern on `clickup-pending.md` ("default to main's version" decision); (d) the PR-body test-count drift (Drew run-012 PR body claimed 30, actual 28); (e) the harness-identity self-approval pattern ("can not approve your own pull request" across runs 010-022).
  2. Each entry follows the format header (filed-by / severity / repeat / what-happened / why-no-defect / protocol-clarification / action-taken).
  3. Pattern-watch column populated — if any pattern hits ≥3 occurrences, escalate suggestion noted.
- **Why now (vs. defer):** The W3-A7 4-occurrence pattern is explicitly precedented as worth documenting. Other patterns may quietly recur if not surfaced. Lower-leverage than register/audit but higher-leverage than postmortem-of-one.

### T-EXP-6 — `docs(audio): audio sourcing operations pipeline — flow doc for cue routes`

- **Working title:** `docs(audio): audio sourcing operations doc`
- **Owner:** Uma
- **Dependencies:** existing `team/uma-ux/audio-direction.md` (60+ cue rows, source-of-truth flow §4 — but operationally vague).
- **Size:** M (3–5 ticks)
- **Priority:** **P1**
- **Acceptance criteria:**
  1. New doc `team/uma-ux/audio-sourcing-operations.md` covering the 4 sourcing routes — freesound / hand-Foley / AI-curated / hand-composed.
  2. Per-route flow: (a) when does this route apply (which cue categories — SFX vs. music vs. ambient), (b) sourcing action sequence (freesound search → license check → q5/q7 OGG re-encode), (c) approximate latency per route (freesound: ~5 min/cue; hand-Foley: ~30 min/cue; AI-curated: ~10 min + 20 min curation; hand-composed: 1–4 hours/cue), (d) commit pattern (where the source file lives, where the q5/q7 export lives).
  3. Decision tree: given a cue row, which route do we pick? (e.g., "if hand-composed cycle time > 1 tick, fall back to placeholder loop per audio-direction.md §4.")
  4. Tooling list: licenses Uma uses (freesound CC0/CC-BY tracking), tools (DAW for hand-composed, Foley setup for hand-Foley).
  5. Cue-list cross-reference: every existing `audio-direction.md` row tagged with sourcing route + estimated cycle time.
- **Why now (vs. defer):** Uma's M2 T10 ticket is "sourcing or placeholder" — operationally vague. Shipping operational docs now de-risks Uma's M2 throughput. Lower-leverage than budget/register but operationally specific.

### T-EXP-7 — `chore(planning): sponsor-soak prep checklist — pre-soak actions + post-death prompts`

- **Working title:** `chore(planning): sponsor-soak prep checklist`
- **Owner:** Tess (primary; Uma assists on copy)
- **Dependencies:** existing `team/tess-qa/m2-acceptance-plan-week-1.md` §"Sponsor probe targets" as M2 template; `team/tess-qa/soak-template.md` as soak-shape source.
- **Size:** S (1–2 ticks)
- **Priority:** **P1**
- **Acceptance criteria:**
  1. New doc `team/tess-qa/sponsor-soak-prep-m1.md` (or extend `soak-2026-05-02.md` with a §"Pre-soak" section) covering: (a) pre-soak actions the team can take to smooth the first hour (e.g., a 60-second scripted playthrough video showing the first-mob → first-loot → first-equip → first-affix-roll → first-death loop, or a "what's still placeholder" note for cues that haven't shipped); (b) probe-target checklist mirroring T12's M2 §"Sponsor probe targets" but for M1 ACs (#1 starts → #7 acceptance gates); (c) post-death prompts — questions Sponsor can ask himself after each death ("did the death feel fair?", "did I understand why I died?", "did the run-summary read?"), or that Tess can ask post-soak.
  2. Doc cross-references `team/tess-qa/m1-test-plan.md` for AC-coverage.
  3. Caveat: this doc is for Sponsor's *next* soak (post-M1 if he hasn't signed off; post-M2-RC otherwise). Revisable.
- **Why now (vs. defer):** Speculative leverage — Sponsor may sign off cleanly without needing prep. But the doc is evergreen wisdom that lands as a transferrable asset (M2 RC soak benefits, M3 soak benefits). Cheap to author.

### T-EXP-8 — `docs(drew-dev): charger flake postmortem — wall-stop-epsilon race learning`

- **Working title:** `docs(drew-dev): charger flake postmortem`
- **Owner:** Drew (primary; Tess assists on the CI evidence trail)
- **Dependencies:** Drew's PR #94 fix as evidence (`drew/charger-flake-fix`, merged at `7697ca5`); Tess run-019/020 audit trail.
- **Size:** S (1–2 ticks)
- **Priority:** **P2**
- **Acceptance criteria:**
  1. New doc `team/drew-dev/postmortem-charger-flake-2026-05-02.md` capturing: (a) symptom (CI run 25260213330 attempts 1+2 failed on `test_killed_mid_charge_no_orphan_motion`; rare flake — first repro after triggering workflow_dispatch runs); (b) root cause (`Charger._physics_process` wall-stop check fired false-positive on first CHARGING tick when `get_physics_process_delta_time() ≈ 0`); (c) why it took 200+ green main runs to surface (test only failed at low charge_speed = 60 from default MobDef; tests overriding move_speed to 180 survived); (d) fix shape (`WALL_STOP_FRAMES_REQUIRED = 2` constant + frame-counter); (e) reusable lesson — **"test-passes-with-overridden-speed-but-fails-on-default"** is a generalizable test-hygiene anti-pattern; whenever a test sets up a non-default value, run a sibling at the default to expose this class of races.
  2. Cross-link to `team/devon-dev/ci-hardening.md` flake-quarantine pattern (this fix landed without quarantine — fix-forward path; the postmortem documents when fix-forward is preferred over quarantine).
- **Why now (vs. defer):** Lower leverage than the items above. Reusable wisdom only. **P2** — defer indefinitely if higher-leverage tickets fill the envelope.

---

## Capacity check

**Remaining session budget:** Sponsor OUT, no return time. Conservatively assume ~4–6 hours available before harness reset / next Sponsor signal.

**Dispatch order recommendation (highest leverage first):**

1. **T-EXP-3 (risk register refresh, P0, S)** — single tick, highest leverage. Dispatch first.
2. **T-EXP-4 (doc audit pass, P0, S)** — single tick, parallels T-EXP-3 (different file scope; can dispatch concurrently).
3. **T-EXP-2 (performance budget spec, P0, M)** — Devon-owned; M2 R3 mitigation; can run in parallel with Priya's two S-tickets above.
4. **T-EXP-1 (M2 week-2 backlog draft, P1, M)** — defer until P0s land. Dispatch as second-wave once orchestrator confirms envelope still empty.

**P1/P2 (don't pre-create in ClickUp; orchestrator dispatches if envelope still empty after P0s land):**
- T-EXP-5 (process-incidents normalization, P1, S)
- T-EXP-6 (audio sourcing operations doc, P1, M)
- T-EXP-7 (sponsor-soak prep checklist, P1, S)
- T-EXP-8 (charger flake postmortem, P2, S)

**Total proposed parallel dispatch:** 3 P0s in parallel (T-EXP-3 Priya, T-EXP-4 Priya/orch, T-EXP-2 Devon) — same heartbeat tick, three different worktrees, zero scope overlap.

**Capacity by owner (if all 8 dispatched):**
- Priya: T-EXP-1, T-EXP-3, T-EXP-4 (likely), T-EXP-5 — 4 tickets, 1×M + 3×S = ~6–9 ticks. Well within Priya's typical run cadence.
- Devon: T-EXP-2 — 1 ticket, M = ~3–5 ticks. Fits in Devon's lane.
- Uma: T-EXP-6 — 1 ticket, M = ~3–5 ticks. Operationally specific to Uma.
- Drew: T-EXP-8 — 1 ticket, S = ~1–2 ticks. Very light.
- Tess: T-EXP-7 — 1 ticket, S = ~1–2 ticks. Very light.
- Orchestrator: T-EXP-4 (alternative owner if Priya at capacity).

**Buffer:** if Sponsor returns mid-session, dispatched-but-unfinished P1/P2 tickets are revisable / pause-able without harm (all are doc/spec work, no half-shipped state).

---

## Open questions (parking lot for Sponsor when he returns)

The tickets above are scoped to be dispatchable without Sponsor input. Items that *DO* need Sponsor input are listed here so they don't get conflated with the dispatch envelope:

1. **M3 framing — multi-character, hub-town, persistent meta-progression.** Pure design / scoping question. Open question 4 from `stash-ui-v1.md` (hub-town). Sponsor's call on whether M3 is multi-character (per `save-schema-v4-plan.md §2.5` Devon hint) or single-character with persistent meta. Defer to post-M1-sign-off conversation — not dispatchable without his shape preference.
2. **Telemetry / analytics scaffold.** Sponsor's call on whether M2 / M3 should ship with instrumentation (e.g., death-location heatmap, time-per-room median, drop-rate empirical). Adds dependencies (analytics SDK or self-rolled JSON-POST) that have privacy implications for itch-deployed builds. Defer until Sponsor expresses interest.
3. **Localization / accessibility scope.** Sponsor's call on whether M2 / M3 ship with i18n scaffold or hold for M4. Mostly latency cost (every UI string becomes a key), low M1/M2 value if game is English-first. Defer.
4. **Bug-bash `86c9kxx7h` reservation policy.** Currently reserved for post-Sponsor. If Sponsor's soak surfaces nothing, what happens to the reservation — does the team self-bug-bash, or close the ticket? Sponsor's call (or Priya's call, framed for Sponsor approval). Defer until M1 sign-off conversation.

None of these block the 8 ticket-shapes above. All are speculatively useful when Sponsor returns.

---

## Caveat — this is a draft, not a contract

This doc is **anticipatory planning**, identical in disposition to `m2-week-1-backlog.md`. Revisions land if:

- Sponsor's M1 soak surfaces blockers/majors that adjust priorities (e.g., a discovered bug claims dev capacity, displacing T-EXP-2).
- Orchestrator decides a different cut of the envelope (e.g., "skip T-EXP-1, prioritize T-EXP-7 instead because Sponsor return is imminent").
- New ticket-shapes surface during dispatch that supersede listed P1/P2 (always welcome — this doc isn't exhaustive).

**This expansion is the path of least resistance from "envelope exhausted" → "team productive." It is not the only path.**
