# Risk Register — Embergrave M1

Owner: Priya. Tick: 2026-05-03 (M1-soak refresh). Rolling document — risks added, retired, and re-scored as M1 progresses.

**M1-soak refresh summary (2026-05-03):** Sponsor began interactive soak on the M1 RC after PR #107 (`feat(integration): wire M1 play loop into Main.tscn`) merged at `4484196`. Two M1-soak-blockers surfaced inside the first 10 minutes of play: **combat hits don't land** (Devon fixing as `86c9m36zh`) and **combat is invisible** even after the hit-land fix (Uma designing as `86c9m37q9`, Drew + Devon will implement). These are concrete R6 evidence — the prior forecast of "high probability, med impact" underweighted impact. Combat-not-landing was a **soak-stopper**, not a polish fix. Plus: the M1 integration miss (Main.tscn shipped as week-1 boot stub through ~30 PRs of "feature-complete" claims) is a class of risk the register did not previously cover — added as **R11**. Plus: the orchestrator-bottleneck-on-dispatch pattern (user has had to override "continue / get to work / we need progress / always parallel" multiple times today) is added as **R12**.

**This update's moves:**

- **Closed:** R3 (HTML5 export regression — Tess W3-A5 audit closed all three CR-1/CR-2/CR-3 findings on `main`; HTML5 RC residual queue empty). R5 (concurrent-agent collisions — W3-A7 option A worktree isolation v3 holding across 30+ PRs with zero HEAD-pinning incidents). R7 (affix balance hand-tuning sinkhole — `affix-balance-pin.md` resolved before Drew picked up `86c9kxx61`; balance pass was paper-trivial).
- **Demoted to watch-list:** none this update (closed three; promoted two new).
- **Escalated:** R6 (Sponsor-found-bugs flood) impact bumped med → **high** with concrete soak evidence (combat-not-landing was a soak-stopper). Probability stays **high** — actually firing right now.
- **New:** R11 (integration-stub-shipped-as-feature-complete) — class of risk the register did not previously cover. R12 (orchestrator-bottleneck-on-dispatch) — user repeatedly overrode under-dispatch today.
- **Held:** R1 (save migration — held through five schema bumps, will face sixth at v3→v4 in M2). R2 (Tess bottleneck — currently inverted, queue at 0; held as a structural risk). R4 (scope creep — clean week 3, M1 ACs frozen; held).

See `team/priya-pl/week-2-retro-and-week-3-scope.md` for the prior retro narrative; this refresh supersedes the mid-week-2 top-5 with M1-soak-grade evidence.

## Format

Each risk: short ID (`R1`–`R12`), name, **probability** (low / med / high), **impact** (low / med / high), **mitigation**, **trigger / signal** (what tells us the risk is materializing), **evidence** (what we have actually observed), **owner**. Rated against M1 ship date (now imminent — Sponsor soak in flight) and early M2 (week-1 backlog drafted in `m2-week-1-backlog.md`).

Top 5 are the active set tracked in heartbeat ticks. New risks land here as they surface; resolved risks move to "Retired" at the bottom.

---

## Risk-by-risk update table (2026-05-03 refresh)

| ID | Name | Prior P/I | New P/I | Move | Evidence delta |
|----|------|-----------|---------|------|----------------|
| R1 | Save migration breakage | med / high | med / high | Held | Five M1 schema bumps shipped clean; sixth (v3→v4) deferred to M2 per `save-schema-v4-plan.md`. No regression observed. Pattern is robust. |
| R2 | Tess bottleneck | high / med | med / med | Held (probability ↓) | Queue depth held at 0–2 throughout week 3 close-out. Tess wrote integration test `test_m1_play_loop.gd` herself per W3-A7 parallel scaffolding. No active stall. Probability lowered; structural risk remains. |
| R3 | HTML5 export regression | high / high | — | **Closed** | Tess's W3-A5 audit (`html5-rc-audit-591bcc8.md`) closed all three CR-1/CR-2/CR-3 findings on `main` (CR-1/CR-2 at squash `98a344e` run 019, CR-3 at `b704345` run 022). M1 HTML5 RC residual queue is empty. M2 re-introduces six new HTML5 surfaces — register opens **R3-M2** at M2 dispatch. |
| R4 | Scope creep | high / med | med / med | Held (probability ↓) | M1 ACs frozen at week-2 retro; week-3 close held to scope; integration ticket (`86c9m2jgu`) was a gap-fill, not scope creep. M2 week-1 backlog draft pre-enumerated to prevent drift. |
| R5 | Concurrent-agent collisions | med / low-med | — | **Closed** | W3-A7 option A worktree isolation v3 has held across 30+ PRs across week 3 + close-out. Zero HEAD-pinning incidents. Push-by-refspec discipline is reliable. Per-role section ownership in STATE.md no overwrites observed. |
| R6 | Sponsor-found-bugs flood | high / med | high / **high** | **Escalated (impact ↑)** | M1 soak surfaced 2 P0 blockers in <10 min: combat-not-landing (`86c9m36zh`) was soak-stopper; combat-invisible (`86c9m37q9`) is fix-forward. Forecast underweighted impact — combat-not-landing is not "polish," it's "can't play the game." |
| R7 | Affix balance hand-tuning | high / med-high | — | **Closed** | `affix-balance-pin.md` shipped before Drew picked up `86c9kxx61`. Balance pass became paper-trivial: zero affix-tres edits, one `grunt_drops.tres` edit per pin §3, ticket closed. Tess's `86c9kyntj` follow-up resolved as "no change" via the pin's analysis. |
| R8 | Stash UI complexity (M2) | high / med-high | high / med-high | Held (M2-only) | Imported from `m2-week-1-backlog.md`; not active during M1 finish-line but tracked for M2 dispatch. T3 stub-PR-then-interactive-PR split planned. |
| R9 | Stratum-2 content triple-stack (M2) | high / med | high / med | Held (M2-only) | Imported from `m2-week-1-backlog.md`; not active during M1 finish-line but tracked for M2 dispatch. T4 soft-retints deferrable, T5 placeholder-hex fallback, T6 SFX-placeholder fallback. |
| R10 | Audio sourcing latency (M2) | med / low | med / low | Held (M2-only) | Imported from `m2-week-1-backlog.md`; T10 P1 with explicit placeholder-loop fallback. Not blocking. |
| R11 | Integration-stub shipped as feature-complete | — | high / **high** | **New** | M1 ran ~30 PRs of "feature-complete" claims while `Main.tscn` was a week-1 boot stub. Sponsor's first soak download exposed it in 2 minutes. The flag was raised twice in writing (Tess run-013, Priya W3-A1) and treated as "(Note, not blocking)." |
| R12 | Orchestrator-bottleneck-on-dispatch | — | high / med | **New** | User overrode the orchestrator multiple times today: "continue" / "get to work" / "we need progress" / "always parallel." Pattern: orchestrator under-dispatching when team has capacity. Two ClickUp tickets created today without same-tick dispatch. |

---

## Top 5 active risks for "M1 close + early M2" (re-ranked 2026-05-03)

1. **R6** (Sponsor-found-bugs flood) — high / **high** — actively firing; combat-not-landing is a soak-stopper.
2. **R11** (Integration-stub shipped as feature-complete) — high / high — class of risk just realized; mitigation discipline is new.
3. **R12** (Orchestrator-bottleneck-on-dispatch) — high / med — actively firing today; cron-prompt fix in progress.
4. **R1** (Save migration breakage) — med / high — held; sixth schema bump (v3→v4) lands in M2 week 1.
5. **R8** (Stash UI complexity, M2) — high / med-high — pre-positioned for M2 week 1 dispatch.

R2 and R4 drop off the top-5 (probability lowered to med, no active firing). R3, R5, R7 closed.

---

## R1 — Save migration breakage between schema versions

- **Probability:** med
- **Impact:** high
- **Why it's still tracked:** Save/load is the single highest-coupling system in M1 (per `TESTING_BAR.md` §Devon-and-Drew). Every feature that adds a field to the save shape risks orphaning previous saves. Sponsor's first hour of M2 playtesting is exactly the window when a broken migration shows up. M2 week 1 brings the v3→v4 bump (stash + ember-bags + stash_ui_state).
- **Mitigation:**
    - `save_version` field already shipped in week-1 #6.
    - Forward-compat fixture test (`tests/fixtures/save_v0.json`) authored as a week-2 buffer ticket.
    - Every PR that touches the save schema MUST include either a migration step + migration test OR an explicit "no schema change" note in the commit body. Priya enforces in PR review.
    - DECISIONS.md log every schema-shape change so the migration test can be re-checked against the historical sequence.
    - `save-schema-v4-plan.md` pre-pins the v3→v4 shape with `_migrate_v3_to_v4` idempotent has()-guarded backfill + 8 round-trip invariants (Devon's M2 T1).
- **Trigger / signal:** any save-touching PR that ships without a migration test; any Tess soak run where reload doesn't preserve a known field.
- **Evidence:** Five M1 schema bumps shipped clean across week 1–3. No regression observed. Pattern is robust.
- **Owner:** Devon (implements migration), Tess (validates), Priya (enforces gate).

## R2 — Tess sign-off becomes the bottleneck

- **Probability:** med (lowered from high)
- **Impact:** med
- **Why:** Testing bar gates every feature on Tess sign-off. Five active devs / designers can fan out work faster than a single Tess agent can review. Held as structural risk even though it has not fired during M1 close-out.
- **Mitigation:**
    - Heartbeat queue-depth rule: orchestrator dispatches Tess back-to-back when `ready for qa test` queue ≥3.
    - Tess wrote integration tests during week 3 close-out (T12 / `test_m1_play_loop.gd`) — automation eats the regression-pass workload.
    - Devs run their paired GUT tests locally before pushing.
    - Priya splits feature tickets where the feature is large enough to amortize sign-off latency.
- **Trigger / signal:** queue depth ≥4 sustained across two heartbeat ticks.
- **Evidence:** Queue depth held at 0–2 throughout week 3 close-out. Tess authored `test_m1_play_loop.gd` herself in run-023. No active stall.
- **Owner:** Tess (executes), orchestrator (queue-watch), Priya (scope sizing).

## R4 — Scope creep into M1 from "just one more thing"

- **Probability:** med (lowered from high)
- **Impact:** med
- **Why:** M1 acceptance criteria are seven items in `mvp-scope.md`. Easy to look at the build at week 3 and want to add the off-hand slot, the second affix tier above T3, or the audio score from M2.
- **Mitigation:**
    - mvp-scope.md is **v1-frozen** as of 2026-05-02. Changes go in a `## Changes` section with rationale.
    - All M2 / M3 features explicitly enumerated in mvp-scope.md as "deferred"; Priya can quote the doc in any scope-debate.
    - Decisions log captures any approved scope changes.
    - M2 week-1 backlog draft (`m2-week-1-backlog.md`) pre-enumerated to prevent drift on M2 entry.
- **Trigger / signal:** any ClickUp ticket created with M1-coded tag whose description references off-hand/trinket/relic, audio score, or T4+ tiers — auto-pushback unless DECISIONS.md entry justifies it.
- **Evidence:** M1 ACs held to scope through week 3. Integration ticket (`86c9m2jgu`) was a gap-fill on existing AC, not scope creep. Combat-feedback ticket (`86c9m37q9`) is polish on existing AC, not new scope.
- **Owner:** Priya (gatekeeper), Sponsor (final word on scope changes via decision-log directives).

## R6 — Sponsor-found-bugs flood when soak resumes (escalated impact 2026-05-03)

- **Probability:** high
- **Impact:** **high** (escalated from med — combat-not-landing was a soak-stopper, not polish)
- **Why:** M1 soak just confirmed the prior forecast as understated. Sponsor's interactive run on the M1 RC `embergrave-html5-4484196` surfaced **two P0 blockers in the first 10 minutes**: (a) combat hits don't land when spam-clicking left mouse on overlapping grunts (Devon fixing as `86c9m36zh`); (b) combat is visually invisible even after the hit-land fix — no swing animation, no hit-flash, no death feedback (Uma designing as `86c9m37q9`, Drew + Devon implement). The first issue prevented further play; the second blocks the player's mental model of what's happening on screen. Both are real, both are P0, both were missed by 587 passing tests.
- **Mitigation:**
    - Reserve buffer dev ticks for the post-soak fix-forward loop. Don't load week / phase to capacity.
    - First dispatch when Sponsor's bug list lands: **Tess** runs her own bug-bash on the same build to confirm/disprove each filed issue, *then* Devon/Drew fix-forward. Protects against false-positives during the human soak.
    - Tess maintains the bug template + severity convention so the in-flow is structured, not free-form.
    - **NEW (post-2026-05-03):** combat-feedback design pattern (Uma `86c9m37q9`) becomes a reference for "feel" P0s — not just "does it work" but "does the player perceive it working."
    - **NEW:** every M2 feature ticket adds an explicit "feel" acceptance criterion alongside the technical AC, where applicable.
- **Trigger / signal:** Sponsor returns and files ≥1 P0 in any single soak session (lowered from "≥3 issues" — one P0 is enough); cluster of issues all hitting the same subsystem indicates a deeper root-cause that should be fixed at the root.
- **Evidence:** **2026-05-03 M1 soak — 2 P0 blockers in <10 minutes of play.** Combat-not-landing (`86c9m36zh`) + combat-invisible (`86c9m37q9`). Combat-not-landing was a soak-stopper. Forecast was high-probability/med-impact; reality is high-probability/**high-impact**.
- **Owner:** Tess (triage + confirm), Devon/Drew (fix-forward), Uma (feel-design when needed), Priya (severity calls), orchestrator (capacity protection in next phase).

## R8 — Stash UI complexity (M2; imported 2026-05-03)

- **Probability:** high
- **Impact:** med-high
- **Why:** M2 week-1 T3 is L-sized (6–10 ticks). Three distinct skill domains stacked on one ticket (engine extension + UI scene authoring + save-schema integration). Single owner (Devon). Largest M2 week-1 ticket. If T3 slips, T7 (ember-bag pickup) + T8 (death-recovery) + T9 (stash room) all chain on it; chain-failure cost is multi-day.
- **Mitigation:** pre-pin the cell layout in a screenshot before the PR opens (Uma assists via T8 hand-off). Devon scopes a **stub UI** first PR (panel renders empty stash, B-binding works, no item-move logic) and a follow-up **interactive** PR if size balloons. Tab+B coexistence (open question 8 in `stash-ui-v1.md` §7) is the Uma-flagged edge case — Devon's PR includes a manual test for this regardless. T2 (SaveSchema autoload) lands first to remove default-value-sourcing rework.
- **Trigger / signal:** T3 in flight for >5 ticks without a sign-off; multiple "split into smaller PRs" flips on the ticket; Tess flagging the panel surface as "feels incomplete" without specific failures.
- **Evidence:** Carried from `m2-week-1-backlog.md`. Pre-positioned for M2 dispatch — not yet active.
- **Owner:** Devon (implement), Uma (UX hand-off + visual sign-off), Priya (size sentinel).

## R11 — Integration stub shipped as feature-complete (NEW 2026-05-03)

- **Probability:** high
- **Impact:** high
- **Why:** M1 surfaced a class of risk the register did not previously cover. The team shipped ~30+ PRs of subsystems (grunts, charger, shooter, boss, rooms 1-8, RoomGate, StratumProgression, level-up math, damage formula, affix system, inventory panel, stat-allocation panel, save migration) each with paired tests + green CI + Tess sign-off — and `scenes/Main.tscn` remained the week-1 boot stub. **587 passing tests + 30+ "feature-complete" claims hid the gap until Sponsor downloaded the build.** Tess run-013 noted "InventoryPanel.tscn is not yet instantiated in scenes/Main.tscn" and treated it as "(Note, not blocking)." Priya W3-A1 said "must both be instantiated in Main.tscn ... Not done = ticket not done" but Devon's run-009 was different scope; W3-A1 was never explicitly closed. Two written flags, both ignored. Recovery cost: full integration ticket (`86c9m2jgu`) dispatched as substantial new work after weeks of "complete" claims.
- **Mitigation:**
    - **NEW orchestrator memory:** `product-vs-component-completeness.md` codifies the lesson — "components pass tests; products integrate; don't conflate them."
    - Every UI/system ticket's Done clause explicitly includes "instantiated in the play surface" — not just "component implemented + tested."
    - Carry-over visibility: when a ticket's flagged carry-over (W3-A1) is unresolved at next dispatch, that's a P0 escalation, not a side note.
    - Heartbeat tick: orchestrator periodically reads the entry-point scene file (`scenes/Main.tscn` or whatever `run/main_scene` points at) and confirms the latest claimed-shipped subsystems are wired into it. Treat any throwaway "Main.tscn is still a stub" flag from QA as a gating ticket, immediately.
    - For HTML5/web games: build artifact is the truth. Don't claim a milestone "shippable" until an agent has triggered a release build, downloaded the artifact, and either visually inspected the entry-scene or driven an end-to-end integration test that loads Main through the player's path.
    - Don't dispatch features faster than they integrate. If 5 subsystems land but Main.tscn hasn't been touched in those 5 PRs, integration debt is accumulating — pause feature dispatch and run an integration pass.
- **Trigger / signal:** any QA report with "(Note, not blocking)" framing on a wiring observation; any stretch of ≥5 subsystem PRs without a Main.tscn touch; carry-over W3-A1-class items unresolved past one dispatch.
- **Evidence:** **2026-05-03 M1 integration miss.** PR #107 fixed it; integration test `tests/integration/test_m1_play_loop.gd` (488 lines, 11 funcs, AC1-AC10) is the gating contract going forward. Devon also surfaced + fixed an inline integration bug in the same PR: `Stratum1Room01` and `MultiMobRoom` were spawning mobs without applying `mob_def`, so per-mob unit tests passed but room-spawned mobs silently no-op'd `Levels.subscribe_to_mob` and `MobLootSpawner.on_mob_died`. **Same bug class:** unit tests set the field; integration code didn't; only end-to-end coverage caught it.
- **Owner:** orchestrator (integration discipline + carry-over visibility), Priya (Done-clause wording in every ticket), Tess (integration test authoring + flag-elevation discipline), Devon (Main.tscn ownership when in scope).

## R12 — Orchestrator-bottleneck-on-dispatch (NEW 2026-05-03)

- **Probability:** high
- **Impact:** med
- **Why:** User has overridden the orchestrator multiple times today: "continue" / "get to work" / "we need progress" / "always parallel." Pattern: orchestrator under-dispatching when the team has capacity. Earlier today the orchestrator created two ClickUp tickets (`86c9m37n9` Tess bug-bash, `86c9m37q9` Uma visual feedback design) and started writing user-facing summaries WITHOUT dispatching the agents in the same response. From the user's view, nothing was happening. Same shape as the earlier 22:03 + 22:33 "soft-blocker: envelope exhausted" pattern — orchestrator concluding "nothing to dispatch" while Priya-backlog-expansion / Tess-acceptance-plan / Uma-S3-S8-palette were always dispatchable. The user shouldn't be the heartbeat.
- **Mitigation:**
    - **NEW orchestrator memory:** `always-parallel-dispatch.md` codifies "tickets ≠ progress; dispatches = progress; default to 3-5 agents in flight."
    - Heartbeat tick rule: every tick MANDATES parallel dispatch unless one of the narrow blockers fires (Sponsor-input-required / auto-mode-permission-denied / agent-reports-contract-conflict / user-says-stop).
    - "All Half-A items closed" is NOT a blocker — Half-B-design + anticipatory + cross-role planning are always dispatchable. Priya's `backlog-expansion-2026-05-02.md` and `m2-week-1-backlog.md` enumerate these.
    - Cron prompt updated: when tick concludes "nothing to dispatch," the orchestrator must either dispatch Priya to expand the backlog OR explicitly justify the soft-blocker against the four narrow blockers above.
    - When orchestrator creates a ClickUp ticket as part of dispatch prep, the dispatch should be in the SAME response or the next one — not deferred behind a user-facing summary.
- **Trigger / signal:** user explicitly says "continue" / "keep dispatching" / "we need progress" / "always parallel" — that's the under-dispatch signal firing in real-time. Two consecutive heartbeat ticks with <2 agents in flight without explicit blocker logged. ClickUp tickets created without same-tick dispatch.
- **Evidence:** **2026-05-03 — multiple user overrides today.** Two tickets created (`86c9m37n9`, `86c9m37q9`) without same-response dispatch. Recurrence of the 22:03 / 22:33 envelope-exhausted pattern from prior session. Memory `always-parallel-dispatch.md` written today.
- **Owner:** orchestrator (heartbeat discipline), Priya (envelope-fill backlog so "nothing to dispatch" is rarely true), user (cron-prompt revision).

---

## Watch-list (not in top 5 but tracked)

- **W1 — Art bottleneck on Uma:** Uma is a single role; week-3 had multiple design-spec tickets (palette-S3-S8, audio nudges, microcopy passes). If content authoring outpaces Uma's specs, the dev shifts to fallbacks. Mitigation: Priya prioritizes Uma's tickets over Priya's own non-blocking work; Drew authors against the visual-direction one-pager + palette as fallback. **Held** — no active firing in week 3.
- **W3 — Boss state-machine complexity:** N6 (stratum-1 boss) is the most complex week-2 ticket. Mitigation: paired GUT for state transitions catches regressions early; Tess edge-probes specifically target combat edge cases the state machine exposes. **Held** — closed clean in week 2 + week 3.
- **W4 — Sponsor finds bug at sign-off:** the testing-bar exists to prevent this, but residual probability is non-zero. **Subsumed by R6 escalation** — see R6.
- **W9 — M2 stash UI complexity:** **Promoted to R8 on 2026-05-03.** Watch-list entry retained as a back-reference; do not double-count.

---

## Retired risks

- **R3 — Godot HTML5 export regression mid-build (closed 2026-05-03)**
    - **Why closed:** Tess's W3-A5 audit (`team/tess-qa/html5-rc-audit-591bcc8.md`) closed all three CR-1/CR-2/CR-3 findings on `main`. CR-1 (`InventoryPanel._exit_tree`) + CR-2 (`StatAllocationPanel._exit_tree`) at squash `98a344e` (run 019). CR-3 (`StratumProgression` dead null-check) at `b704345` (run 022). M1 HTML5 RC residual queue is empty.
    - **Re-open trigger:** M2 dispatch — six new HTML5 surfaces (v4 save with Dictionary-of-Dictionary OPFS roundtrip, stash UI 12×6 cell rendering, ember-bag pickup with sprite anim + audio, stratum-2 entry with ambient tint, Stoker cone-fire-breath telegraph, audio sourcing pass) re-introduce the risk class. Will open as **R3-M2** at M2 dispatch entry.
- **R5 — Concurrent-agent merge collisions (closed 2026-05-03)**
    - **Why closed:** W3-A7 option A worktree isolation v3 has held across 30+ PRs across week 3 + close-out. Zero HEAD-pinning incidents. Push-by-refspec discipline is reliable. Per-role section ownership in STATE.md — no overwrites observed.
    - **Re-open trigger:** any rebase conflict pattern that re-emerges, or a new role added to the team that doesn't get a worktree on day 1.
- **R7 — Affix balance hand-tuning sinkhole (closed 2026-05-02)**
    - **Why closed:** Priya's `affix-balance-pin.md` shipped before Drew picked up `86c9kxx61`. Balance pass became paper-trivial: zero affix-tres edits, one `grunt_drops.tres` edit per pin §3, ticket closed. Tess's `86c9kyntj` follow-up resolved as "no change" via the pin's analysis.
    - **Re-open trigger:** M2 introduces T4+ tiers (deferred to M3 per `mvp-scope.md`) — a new balance pin would be needed.

---

## How this register is used

- Heartbeat ticks: orchestrator scans for any new `bug(...)` task with `blocker` severity → cross-reference to a risk here, escalate the risk's probability if pattern matches.
- Phase-boundary retro: Priya re-scores top 5; promotes from watch-list as needed; closes risks with concrete evidence + lists re-open triggers.
- DECISIONS.md cross-link: any decision that resolves a risk should reference the risk ID in the `Affects` field.
- **NEW (2026-05-03):** when a Sponsor-soak surfaces a P0 within the first 30 min of play, that's a real-time R6 escalation signal — re-score impact immediately, not at next retro. The combat-not-landing miss is the calibration data for "P0 in first 10 min = high impact, not med."
- **NEW (2026-05-03):** R11 (integration-stub) and R12 (orchestrator-bottleneck) are process risks, not product risks. Their evidence column is the record of orchestrator behavior over heartbeat ticks — not just product bugs. Priya's risk-register refresh is the place to log the pattern, even when the immediate product harm is small.
