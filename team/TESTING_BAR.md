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

## Visual primitives — observable delta required

When a test exercises a tween, modulate change, color/alpha animation, particle burst, or any other visual primitive, asserting `tween.is_valid()` / `tween.is_running()` / "the tween fires" is **necessary but insufficient**. A passing tween-liveness assertion can mask a no-op visual. The test MUST also assert one or more of the following, at the strongest tier feasible for the primitive under test:

1. **Tier 1 (mandatory, cheapest) — target ≠ rest.** Assert that the tween's target value is materially different from the rest/start value. For modulate flashes: `assert_ne(target_color, rest_color)`. For scale tweens: `assert_ne(target_scale, rest_scale)`. White → white is a tween, but it is not a *visible flash*. A one-liner that catches the entire class of white-on-white / no-op-target bugs.

2. **Tier 2 (mandatory for parented modulate / cascading visual properties) — applied to the visible-draw node.** Modulate cascades multiplicatively (`rendered = child.modulate × parent.modulate × ...`). For modulate tweens on parented nodes: the test must verify the modulate is applied to the *visible-draw* node (the Sprite2D / ColorRect / Polygon2D that actually paints), not to a parent CharacterBody2D / Node2D whose draw is nominal and whose child has its own non-white modulate. If the spec says "flash the mob white" and the implementation tweens the parent body's modulate while the child sprite has modulate `Color(0.8, 0.5, 0.3, 1)`, the cascade produces `0.8 × 1.0 = 0.8` on the red channel — barely a flash. Pin the modulate-target assertion to the actual visible-draw node.

3. **Tier 3 (aspirational, where feasible) — framebuffer pixel-delta.** Sample the rendered framebuffer at the affected region (`Viewport.get_texture().get_image()`) and compare pixel deltas across the tween window. The strongest assertion class: pixels actually changed where the spec says they should. **Caveat — headless rendering does not paint the framebuffer.** Godot's `--headless` flag (the default in our GUT CI) skips the renderer entirely; pixel-delta tests run under `--headless` will trivially "pass" with all-zero pixels. For framebuffer assertions to be meaningful, the test must run under `--rendering-driver opengl3` headed mode (e.g. via xvfb on Linux runners). This is non-trivial CI work; until a renderer-painting lane lands, framebuffer assertions are deferred and the Tier 1 + Tier 2 assertions are the binding floor.

4. **HTML5-specific — pair with the HTML5 visual-verification gate.** Tweens, modulates, Polygon2D, and CPUParticles2D PRs are subject to the pre-existing HTML5 visual-verification rule (orchestrator memory `html5-visual-verification-gate.md`). Headless GUT tests are insufficient to catch renderer-specific failure modes (HDR clamp on `gl_compatibility`, Polygon2D z-index drift, etc.). The Self-Test Report must capture an actual HTML5 export soak before Tess approves; merging a tween/modulate PR on headless-CI-green alone is not within the bar.

**Why this rule exists:** PR #115 (mob hit-flash) and PR #122 (player swing-wedge + ember-flash) both shipped tween-based visual feedback whose paired tests asserted `tween_valid == true`, constant equality, and tween-end behavior — all green. None asserted observable color delta or visible-draw-target landing. **The mob hit-flash tween was a literal no-op** (white target on white rest, applied to a parent CharacterBody2D whose child Sprite has a non-white modulate that cascades the flash away). The bug shipped 2026-05-03 and was only caught 2026-05-06 by Sponsor's HTML5 `[combat-trace]` soak — three days of "feature-complete" status while the on-screen reality was that combat had no visual feedback at all.

**Concrete examples — Tier 1 one-liner additions:**

```gdscript
# In test_combat_visuals.gd (Drew's lane, applies to mob hit-flash):
func test_grunt_hit_flash_target_color_differs_from_rest():
    var g = _spawn_grunt()
    var rest = g.modulate
    var target = Grunt.HIT_FLASH_TARGET_COLOR  # the new constant Drew exposes for the fix
    assert_ne(target, rest, "hit-flash target color must differ from rest — white-on-white is a no-op")

# In test_player_visual_feedback.gd (Devon's lane, applies to player ember-flash):
func test_player_ember_flash_target_tint_differs_from_rest():
    var p = _spawn_player()
    var rest = p.modulate
    var target = Player.EMBER_FLASH_TINT  # Color(1.4, 1.0, 0.7, 1) on desktop, sub-1.0-clamped fallback on web
    assert_ne(target, rest, "ember-flash target tint must differ from rest — clamp-to-rest is a no-op")
```

**Concrete examples — Tier 2 visible-draw-target check:**

```gdscript
# In test_combat_visuals.gd:
func test_grunt_hit_flash_applied_to_visible_sprite_not_parent_body():
    var g = _spawn_grunt()
    g.take_damage(1, Vector2.ZERO, null)
    # The visible-draw target is the child Sprite2D / ColorRect, not the CharacterBody2D itself.
    var visible_target = g.get_node("VisibleSprite")  # whatever the project convention is
    assert_eq(visible_target.modulate, Grunt.HIT_FLASH_TARGET_COLOR,
        "hit-flash modulate must land on the visible-draw node; parent-only is cascade-trapped")
```

**What this rule does NOT require:**

- It does not require Tier 3 (framebuffer-pixel-delta) on every visual test today. Tier 3 is aspirational pending a renderer-painting CI lane.
- It does not require retro-fitting already-merged tests. Existing `test_combat_visuals.gd` and `test_player_visual_feedback.gd` are owned by Drew's `86c9ncd9g` fix PR + Devon's HDR/Polygon2D fix PRs respectively — they will land the Tier 1 + Tier 2 assertions in the same PR as their functional fix, per `tests-with-features` rule above.
- It does not block `chore` / `docs` / `test`-only PRs that don't introduce new visual primitives.

**See also:**

- `team/log/2026-05-html5-visual-feedback-no-op-postmortem.md` — full incident write-up.
- `team/log/process-incidents.md` — pattern-watch entry for this incident.
- Orchestrator memory `html5-visual-verification-gate.md` — the renderer-side complement to this rule.

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
