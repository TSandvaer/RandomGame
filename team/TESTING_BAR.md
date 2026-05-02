# Testing Bar

**Sponsor directive (2026-05-02):** "I want you to use a lot of time testing, I don't want to debug and return findings all the time."

Translation: by the time anything reaches the Sponsor for sign-off, it must already have been hammered thoroughly. Sponsor's role is **acceptance**, not bug-finding. If the Sponsor finds a bug during sign-off, the team failed its testing bar.

This document is binding on every role. Everyone reads it. Tess enforces it.

---

## Definition of Done (DoD) — applies to every feature task

A task is **not** "complete" until ALL of the following:

1. **Code or content lands** — feature works end-to-end on the developer's machine (or in CI for headless features).
2. **Unit tests exist** — for any system with non-trivial logic (state machines, save/load, combat math, loot rolling, level progression). Use GUT in Godot, run via `--script gut/cmdline.gd` headless. Aim for **the meaningful behaviors** to be tested, not 100% line coverage. If a feature genuinely cannot be unit-tested (pure visual / scene composition), say so explicitly in the commit message.
3. **CI green** — GitHub Actions workflow passes on the commit. No "I'll fix CI later." No skipping flaky tests — fix or quarantine with a follow-up ClickUp task.
4. **Integration check vs. M1 acceptance criteria** — if the feature touches one of the 7 M1 acceptance criteria in `team/priya-pl/mvp-scope.md`, the corresponding test from Tess's plan (`team/tess-qa/m1-test-plan.md`) must pass. Run it. Document the result in the ClickUp task description before flipping to `ready for qa test`.
5. **Tess signs off** — Tess (or her agent on the next heartbeat) flips the task from `ready for qa test` to `complete`. Devs do **not** flip their own features to `complete`. The status flow is mandatory: `to do` → `in progress` (if available) → `ready for qa test` → `complete`. Skipping `ready for qa test` is forbidden for feature work.
6. **Edge cases probed** — Tess explicitly tests at least three failure modes per feature (rapid input, mid-action interrupt, save/load round-trip across the feature's state, OS-level interruption like tab-blur for HTML5). Findings either land as a fix in the same task or as a follow-up `bug(...)` task with severity.

Exempt from #2, #4, #5: pure documentation tasks (`docs(...)`, `design(spec): ...`). They still need #1 and #3.

---

## What changes for each role

### Tess

- **Promoted from "writer of plans" to "active hammer."** Each heartbeat tick where there's a feature in `ready for qa test`, Tess runs that feature against the test plan and either signs off, files bugs, or dispatches them back to the dev with specific repro steps.
- **Author tests, don't just describe them.** When Devon's scaffold lands, write the GUT smoke tests (`tests/test_*.gd`) yourself — don't wait for the devs to write them.
- **Bug bashes are scheduled work.** At the end of each milestone (M1 in week 4-ish), schedule a 1-tick bug bash where Tess does nothing but exploratory testing. File everything found.
- **Severity discipline**: `blocker` (M1 cannot ship), `major` (M1 ships impaired, must fix in M2), `minor` (M1 ships, fix when convenient). Use the discipline.

### Devon and Drew

- **Tests-with-features, not after.** Every feature commit includes its tests in the same commit (or a tightly-paired follow-up commit if the test must be in a different file). PRs (or pushes) that introduce logic without tests get reverted by the next dispatched dev or by Tess.
- **Run tests locally before pushing.** If Godot isn't installed locally, write the test code, push, and let CI exercise it — but **don't push and walk away if CI is red**. Watch the workflow result; fix forward in the next push.
- **Save/load is the highest-risk system in M1** — it gets the deepest test coverage. Every save-shape change needs a forward-compat test (old save → new schema → load works or migrates cleanly).

### Uma

- **Design docs are testable.** Every UX surface in Uma's docs gets a test ID in Tess's plan ("does HUD show stratum number when player enters Stratum 1?"). Write design docs precisely enough that Tess can build a yes/no checklist from them.

### Priya

- **Owns the testing-bar enforcement.** If a dev pushes a feature without tests, Priya files a `tech-debt(...)` ClickUp task immediately and parks the feature in `to do` until the test lands. No exceptions for "just this once."
- **Buffer in the schedule.** Week-1 backlog assumed a baseline of testing; with this directive, plan **20% buffer** in week 2's backlog for test backfill, bug bashes, and CI hardening.

### Orchestrator

- **Heartbeat checks `ready for qa test` queue depth.** If 3+ items sit in `ready for qa test` between ticks, dispatch Tess immediately rather than waiting for her normal cadence.
- **Sponsor sign-off gate**: before any sign-off ping reaches the Sponsor, the orchestrator confirms the current build has passed Tess's full M1 test plan with zero `blocker` and zero `major` open bugs.

---

## Test inventory targets for M1

By M1 sign-off candidate, the test inventory should cover:

- **Unit tests (GUT)**: ~20–30 tests covering save/load, combat damage math, loot rolling, level-up math, dodge i-frames, mob AI state transitions.
- **Integration tests (GUT scene tests or HTML5 Playwright if cheap)**: ~10–15 covering M1 acceptance scenarios end-to-end.
- **Manual test cases (Tess's plan)**: ~30–50 cases across all 7 acceptance criteria + regression sweep.
- **CI**: green on every push, build artifact (HTML5 export) attached to every release tag.
- **Soak**: at least one 30-minute uninterrupted play session per release candidate, by Tess. Document what happened in `team/tess-qa/soak-<date>.md`.

If the team is hitting these targets, Sponsor's directive is being honored.
