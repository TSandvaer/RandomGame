# Risk Register — Embergrave M1

Owner: Priya. Tick: 2026-05-02 (end of week 1). Rolling document — risks added, retired, and re-scored as M1 progresses.

## Format

Each risk: short ID (`R1`–`R5`), name, **probability** (low / med / high), **impact** (low / med / high), **mitigation**, **trigger / signal** (what tells us the risk is materializing), **owner**. Rated against M1 ship date (~end of week 4).

Top 5 are the active set tracked in heartbeat ticks. New risks land here as they surface; resolved risks move to "Retired" at the bottom.

---

## R1 — Save migration breakage between schema versions

- **Probability:** med
- **Impact:** high
- **Why it's the top risk:** Save/load is the single highest-coupling system in M1 (per `TESTING_BAR.md` §Devon-and-Drew). Every feature that adds a field to the save shape risks orphaning previous saves. Sponsor's first hour of playtesting is exactly the window when a broken migration shows up.
- **Mitigation:**
    - `save_version` field already shipped in week-1 #6.
    - Forward-compat fixture test (`tests/fixtures/save_v0.json`) authored as a week-2 buffer ticket (B-equivalent — see `qa(integration)` ticket).
    - Every PR that touches the save schema MUST include either a migration step + migration test OR an explicit "no schema change" note in the commit body. Priya enforces in PR review.
    - DECISIONS.md log every schema-shape change so the migration test can be re-checked against the historical sequence.
- **Trigger / signal:** any save-touching PR that ships without a migration test; any Tess soak run where reload doesn't preserve a known field.
- **Owner:** Devon (implements migration), Tess (validates), Priya (enforces gate).

## R2 — Tess sign-off becomes the bottleneck

- **Probability:** high
- **Impact:** med
- **Why:** Testing bar gates every feature on Tess sign-off. Five active devs / designers can fan out work faster than a single Tess agent can review, especially when soak runs and bug bashes pull her away from the QA queue.
- **Mitigation:**
    - Heartbeat queue-depth rule: orchestrator dispatches Tess back-to-back when `ready for qa test` queue ≥3 (per `TESTING_BAR.md` §orchestrator).
    - Tess writes integration tests as part of her week-2 buffer (qa(integration) ticket) — automation eats the regression-pass workload, leaving her tick budget for genuinely new features.
    - Devs run their paired GUT tests locally before pushing — failed tests don't reach Tess (testing bar §Devon-and-Drew).
    - Priya splits feature tickets where the feature is large enough to amortize sign-off latency (e.g. boss is a single ticket, not three).
- **Trigger / signal:** queue depth ≥4 sustained across two heartbeat ticks; week-2 close shows ≥3 features still in `ready for qa test` past planned sign-off date.
- **Owner:** Tess (executes), orchestrator (queue-watch), Priya (scope sizing).

## R3 — Godot HTML5 export regression mid-build

- **Probability:** med
- **Impact:** high
- **Why:** itch.io HTML5 is the Sponsor's playtest channel (per `team/priya-pl/tech-stack.md`). Godot's HTML5 export has known sharp edges — audio context, file system (OPFS vs localStorage), tab-blur behavior, console-error visibility. A regression that only manifests in HTML5 (not desktop dev runs) can hide for ticks.
- **Mitigation:**
    - Butler upload pipeline (week-1 #3, in QA as `86c9kwhte`) wires HTML5 export into CI on every main push.
    - Build-SHA footer (Devon's testability hook #1) makes "which build is the Sponsor playing" answerable.
    - Tess's testability-hook verification (`team/devon-dev/debug-flags.md`) includes the HTML5 console-error round-trip per the testing bar §HTML5 console errors.
    - Tab-blur edge-case probe is mandated on every save/movement/dodge feature (`TESTING_BAR.md` per-feature edge cases).
    - Soak runs (B2 buffer ticket) run on the HTML5 build, not desktop, when feasible.
- **Trigger / signal:** any HTML5 build that boots on desktop dev but breaks on the itch URL; tab-blur edge probe failures; OPFS / localStorage save mismatch.
- **Owner:** Devon (export presets, CI), Tess (HTML5-specific test cases).

## R4 — Scope creep into M1 from "just one more thing"

- **Probability:** high
- **Impact:** med
- **Why:** M1 acceptance criteria are seven items in `mvp-scope.md`. Easy to look at the build at week 3 and want to add the off-hand slot, the second affix tier above T3, or the audio score from M2. Each addition pushes M1 ship date.
- **Mitigation:**
    - mvp-scope.md is **v1-frozen** as of 2026-05-02. Changes go in a `## Changes` section with rationale, not silent edits.
    - All M2 / M3 features explicitly enumerated in mvp-scope.md as "deferred"; Priya can quote the doc in any scope-debate.
    - Week-2 retro (B6-equivalent ticket) is the pressure-release valve — that's where genuine "this needs to be in M1" arguments get heard, not in the middle of a sprint.
    - Decisions log captures any approved scope changes, so we never re-litigate.
- **Trigger / signal:** any ClickUp ticket created with `week-2`/`week-3` tag whose description references off-hand/trinket/relic, audio score, or T4+ tiers — auto-pushback unless DECISIONS.md entry justifies it.
- **Owner:** Priya (gatekeeper), Sponsor (final word on scope changes via decision-log directives).

## R5 — Concurrent-agent merge collisions wasting time

- **Probability:** med
- **Impact:** low-med
- **Why:** 5 named roles dispatched in parallel against the same repo. Worktree isolation (per DECISIONS.md 2026-05-02) reduces working-directory collisions but rebase conflicts on shared files (STATE.md, DECISIONS.md, log files) still cost tick budget.
- **Mitigation:**
    - Worktree isolation (already adopted) — kills the working-directory class of bugs.
    - Per-role section ownership in STATE.md — only your own role's section.
    - DECISIONS.md is append-only — Priya owns; orchestrator may append cross-role.
    - `git pull --rebase` mandatory immediately before editing STATE.md / DECISIONS.md (`team/GIT_PROTOCOL.md`).
    - Conflict pattern on `team/log/clickup-pending.md` — taking main's version is the default per dispatch instruction.
    - Push by explicit refspec (`git push origin HEAD:<branch>`) so destination branch is correct regardless of local HEAD.
- **Trigger / signal:** ≥2 rebase conflicts in a single Priya tick; an agent's STATE.md edit overwriting another's; PR re-pushes due to merge-conflict resolution.
- **Owner:** orchestrator (dispatch shape), every agent (per-role discipline), Priya (file ownership conventions in `GIT_PROTOCOL.md`).

---

## Watch-list (not in top 5 but tracked)

- **W1 — Art bottleneck on Uma:** Uma is a single role; week-2 has two design-spec tickets (level-up panel, boss treatment) plus follow-up microcopy passes. If Drew's content authoring outpaces Uma's specs, Drew either improvises (risk to visual-direction lock) or stalls (risk to schedule). Mitigation: Priya prioritizes Uma's tickets over Priya's own non-blocking work; Drew authors against the visual-direction one-pager + palette as fallback.
- **W2 — Affix balance hand-tuning sinkhole:** N8 (T1→T3 ranges) is a balance ticket that could swallow more tick budget than allocated. Mitigation: ship stub T1 values first via N7, balance pass is reversible until M1 sign-off (per week-2 backlog risk #3).
- **W3 — Boss state-machine complexity:** N6 (stratum-1 boss) is the single most complex week-2 ticket. Mitigation: paired GUT for state transitions catches regressions early; Tess edge-probes specifically target combat edge cases the state machine exposes.
- **W4 — Sponsor finds bug at sign-off:** the testing-bar exists to prevent this, but the residual probability is non-zero. Mitigation: the bar itself, plus the orchestrator gate that Sponsor sign-off pings only fire when zero blockers + zero majors are open.

---

## Retired risks

(none yet — list is born this tick.)

---

## How this register is used

- Heartbeat ticks: orchestrator scans for any new `bug(...)` task with `blocker` severity → cross-reference to a risk here, escalate the risk's probability if pattern matches.
- Week-boundary retro: Priya re-scores top 5; promotes from watch-list as needed.
- DECISIONS.md cross-link: any decision that resolves a risk should reference the risk ID in the `Affects` field.
