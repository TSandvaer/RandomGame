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
5. **Tess signs off** — Tess (or her agent on the next heartbeat) flips the task from `ready for qa test` to `complete`. Devs do **not** flip their own features to `complete`. The status flow is mandatory: `to do` → `in progress` → `ready for qa test` → `complete`. Skipping `ready for qa test` is forbidden for feature work.
6. **Self-Test Report posted (UX-visible PRs)** — for any PR touching a player-visible surface (scene tree, UI, visual feedback, audio cue, input affordance, save format, level content), the **author posts a Self-Test Report comment on the PR before Tess's review begins**. Tess's review starts from the report, not from a cold-read of the diff. If the report is missing on a UX-visible PR, Tess bounces it immediately — don't burn review budget cold-reading a UX diff. Categories that REQUIRE the report: `feat(integration|ui|combat|level|audio|progression|gear)`, `fix(ui|combat|level|audio|integration)`, `design(spec)` when consumed by an in-flight `feat` PR. Format + headless fallback in `team/GIT_PROTOCOL.md` § "Self-Test Report (UX-visible PRs)" and orchestrator memory `self-test-report-gate.md`. Categories that do NOT require it (CI green is sufficient): `chore(ci|repo|build|state|orchestrator|planning)`, `docs(team|scope)`, `test(...)`, `.tres`-only data refactors.
7. **Edge cases probed** — Tess explicitly tests at least three failure modes per feature (rapid input, mid-action interrupt, save/load round-trip across the feature's state, OS-level interruption like tab-blur for HTML5). Findings either land as a fix in the same task or as a follow-up `bug(...)` task with severity.

Exempt from #2, #4, #5, #6: pure documentation tasks (`docs(...)`, `design(spec): ...` not consumed by an in-flight feat). They still need #1 and #3.

---

## Product completeness ≠ component completeness

Component-level test coverage and CI-green status are NOT proof the product is shippable. A feature is not "complete" until it is **instantiated in the entry-scene's runtime tree** and reachable through the same path the player uses.

- **CI green + paired tests** = component-complete. The unit/integration tests prove the system works in isolation.
- **Component instantiated in the play surface** (entry scene loads it; it appears in the runnable build artifact) = product-complete.
- **Sponsor sign-off requires product-complete**, not component-complete.

**Practical applications:**

1. Treat any agent report of "feature-complete" as **component-complete only** until you have independently verified the integration surface — read the entry-scene file (`scenes/Main.tscn` or whatever `run/main_scene` points at) and confirm the new system is instantiated there or in a scene that Main.tscn loads.
2. Watch for "(Note, not blocking)" or similar throwaway flags in QA reports. If any reviewer writes "X is not yet wired into Main.tscn" or "Main.tscn is still a stub," that is a P0 flag, not a side note. Elevate to a gating ticket.
3. Don't dispatch features faster than you integrate them. If 5 subsystems land but `Main.tscn` hasn't been touched in those 5 PRs, you are accumulating integration debt. Stop feature dispatch and dispatch an integration pass before claiming any milestone-level "complete."
4. For HTML5/web specifically: **the build artifact is the truth.** Don't claim "shippable" until you (or an agent) has triggered a release build, downloaded the artifact, extracted it, and either visually inspected the entry scene or driven an end-to-end integration test through the same path the player uses.
5. Tickets that say "implement the panel" are NOT the same as "wire the panel into the game." Make wiring explicit on every UI/system ticket — in the dispatch brief, in the acceptance criteria, in the Done clause.

**Backstory:** the M1 Main.tscn-stub miss — ~30+ PRs of "feature-complete" claims while the runnable build was a week-1 boot stub — is the cautionary tale. CI passed; tests passed; the artifact was a player square on a black banner. The Sponsor's first 2-minute soak exposed the gap. See orchestrator memory `product-vs-component-completeness.md` for the full incident write-up.

**Mantra:** components pass tests. Products integrate. Don't conflate them.

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
