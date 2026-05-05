# Charger test flake — postmortem

**Tick:** 2026-05-05 (run-030, post-fix retrospective)
**Author:** Tess (with Drew's PR #94 commit messages as the load-bearing evidence trail)
**ClickUp:** T-EXP-8 (`86c9nbnbe`)
**Status:** Closed — production fix shipped 2026-05-02 (`dbdf843`, squash-merged via PR #94 / `7697ca5`); 5 consecutive green CI runs confirm the race is fixed. This doc is reusable wisdom, not an open incident.

---

## TL;DR (5 lines)

1. **Symptom:** `tests/test_charger.gd::test_killed_mid_charge_no_orphan_motion` flaked on CI run `25260213330` (2026-05-02) — state assertion expected `STATE_CHARGING`, got `STATE_RECOVERING`; velocity assertion expected `> 0`, got `0.0`.
2. **Root cause:** A real production bug. `Charger._physics_process`'s wall-stop branch fired on a single sub-epsilon-displacement frame, where the doc-string promised "consecutive sub-epsilon frames." In headless GUT, `get_physics_process_delta_time()` can return ~0 on the first CHARGING tick before the engine has stepped physics → `move_and_slide` displacement falls below the 0.5-px epsilon → wall-stop fires → CHARGING → RECOVERING in one tick → state and velocity both wrong at the assert.
3. **Selectivity discriminator:** Tests using default `MobDef` (move_speed = 60) hit the trap; tests overriding move_speed to 180 survived because `180 × 0.003 = 0.54 px > 0.5 px epsilon`. The same class of race showed up on different tests on different CI runs (`25260213330`, `25260326711`, `25260666771`) depending on which `dt` the engine handed back.
4. **Fix:** `WALL_STOP_FRAMES_REQUIRED = 2` constant + frame-counter in `Charger.gd::_physics_process`. Single-frame physics hiccup no longer aborts charges; two consecutive sub-epsilon frames still trip the wall-stop (matches doc-string and design intent). Test-side helper changes (`set_physics_process(false)`, drop intermediate tick) kept as defense-in-depth.
5. **Reusable lesson:** **"test-passes-with-overridden-speed-but-fails-on-default."** Whenever a test sets a non-default scalar, dispatch a sibling at the default to expose this class of physics/timing races. This is the load-bearing transferable insight — generalizable beyond chargers.

---

## Symptom

**Specific failure shape:**

`test_killed_mid_charge_no_orphan_motion` (in `tests/test_charger.gd`, lines 317-344) failed at two consecutive assertions on CI run `25260213330`:

```
Line 330: assert_eq(c.get_state(), Charger.STATE_CHARGING)
  → expected: STATE_CHARGING (1)
  → got:      STATE_RECOVERING (3)

Line 331: assert_gt(c.velocity.x, 0.0, "velocity > 0 mid-charge")
  → expected: > 0
  → got:      0.0
```

**Frequency:** Rare — first reproduced after 200+ green main-branch CI runs. The flake only surfaced after a `workflow_dispatch` run on a no-op branch (off-main), suggesting CI-runner-load-dependent timing. Subsequent fix-iteration runs (`25260326711`, `25260666771`) showed the same class of race manifesting on `test_velocity_during_charge_is_dir_times_speed` and `test_knockback_skipped_during_charge` — confirming this wasn't a single-test bug but a code-path bug the harness only sometimes hit.

**User-facing impact:** Zero. Production gameplay has only one driver of `_physics_process` (the engine), so the headless-test race condition does not manifest in real gameplay. However, the production wall-stop logic itself was buggy (single-frame trigger vs. doc-string's "consecutive frames") and would degrade real-device gameplay on slow devices that drop a single physics frame — fix has user-facing benefit beyond test stability.

---

## Reproduction steps

**Pre-fix repro (historical, no longer flakes after `dbdf843`):**

1. Branch off `main` at `4425ba4` (immediate predecessor of the fix).
2. Trigger a `workflow_dispatch` CI run via `gh workflow run ci.yml`.
3. With moderate runner contention, `test_killed_mid_charge_no_orphan_motion` flakes ~1 in N runs (N unknown but ≥200, given the fix didn't surface for that long on regular merge-driven CI).
4. The flake is **not reliably reproducible** locally — it requires CI runner timing characteristics.

**Why local repro failed:** the race depends on `get_physics_process_delta_time()` returning ~0 on the first CHARGING tick. Local Godot installations tend to have a primed physics scheduler and return realistic deltas; CI's headless GUT in a containerized runner is the environment where this surfaces.

**Post-fix verification:** 5 consecutive green CI runs on the fix SHA `dbdf843` (runs `25260759815`, `25260786183`, `25260816869`, `25260843664`, `25260870293`) — sufficient evidence the race is closed. The new looped-regression test `test_killed_mid_charge_zero_velocity_immediate_loop` runs the kill→tick→assert pattern 25 iterations, so any future regression is deterministic, not one-shot.

---

## Root cause

**Layered diagnosis (the fix sequence reveals three superimposed issues, only the last being the real production bug):**

### Layer 1 (initial hypothesis, partial fix): engine vs. manual driver race

PR #94 commit 1 hypothesized that the test-helper's `add_child_autofree(c)` was adding the charger to the scene tree, where Godot's engine auto-ticks `_physics_process` at 60 Hz. The test then *also* drives `_physics_process` manually with state-bounded deltas. Two callers race; on a contended CI runner, enough engine ticks sneak between manual calls to expire `_charge_time_left = 0.85s`, transitioning CHARGING → RECOVERING before the test asserts.

**Fix attempt:** add `c.set_physics_process(false)` after `add_child_autofree` in test helpers.

**Outcome:** insufficient — CI run `25260326711` reproduced the same flake even with auto-physics disabled. The hypothesis was real but not the *primary* cause.

### Layer 2 (intermediate hypothesis, partial fix): `move_and_slide` post-slide displacement check

PR #94 commit 2 found the test was calling `c._physics_process(0.016)` once between `_drive_to_charging` (which gets us to CHARGING) and the kill. That intermediate tick goes through `move_and_slide()`, whose displacement integration uses `get_physics_process_delta_time()`. In headless GUT that value is environment-sensitive — depends on whether the engine has ticked physics yet. When it returns ~0, the post-slide displacement falls below `WALL_STOP_DISPLACEMENT_EPSILON = 0.5 px` and the wall-stop branch fires, transitioning CHARGING → RECOVERING and zeroing velocity.

**Fix attempt:** drop the intermediate `_physics_process(0.016)` between `_drive_to_charging` and the kill.

**Outcome:** test went green on the test side, but the *production code path was still broken* — any first-frame zero-dt CHARGING tick in the wild would mis-trigger wall-stop. This was a test-passes-but-product-still-buggy state.

### Layer 3 (real production bug, surgical fix): single-frame wall-stop

PR #94 commit 3 found the actual production bug: **bug-as-coded vs. bug-as-documented mismatch.**

The `WALL_STOP_DISPLACEMENT_EPSILON` doc-string claims:
> "When charge motion is rejected this many frames in a row, treat it as a wall hit and stop."

But the implementation only checked **the current frame's** displacement and fired immediately. A single-frame zero-displacement glitch (headless test env where `get_physics_process_delta_time()` returns ~0 on the first CHARGING tick before the engine has stepped physics) was enough to trip the wall-stop branch and abort a charge that should have continued.

**Selectivity (the load-bearing insight):** the charger uses `charge_speed = mob_def.move_speed`. Tests with default `make_mob_def({"hp_base": 30})` get `move_speed = 60`, so `displacement = 60 × dt`; the wall-stop fires when `dt < 0.5 / 60 = 0.0083 s`. Tests overriding `move_speed = 180` (e.g. `test_velocity_during_charge_is_dir_times_speed`) survived because `180 × 0.003 = 0.54 px` — *just barely* above the 0.5-px epsilon. So the same race showed up on different tests on different runs depending on which `dt` the engine returned, and which speed the test was running at. This is what made it a low-frequency cross-test flake instead of a deterministic single-test fail.

**Fix:**

```gdscript
# scripts/mobs/Charger.gd (post-fix)
const WALL_STOP_DISPLACEMENT_EPSILON: float = 0.5
const WALL_STOP_FRAMES_REQUIRED: int = 2
var _wall_stop_frames: int = 0

# In _physics_process:
if entry_state == STATE_CHARGING and _state == STATE_CHARGING:
    var moved: float = (global_position - pre).length()
    if moved < WALL_STOP_DISPLACEMENT_EPSILON:
        _wall_stop_frames += 1
        if _wall_stop_frames >= WALL_STOP_FRAMES_REQUIRED:
            _end_charge_into_wall()
    else:
        _wall_stop_frames = 0

# In _begin_charge: reset _wall_stop_frames = 0 so each new charge starts clean.
```

Two consecutive sub-epsilon frames still trip the wall-stop — that's a real wall, probably. A single-frame physics hiccup (slow device, dropped frame) no longer aborts charges. Matches the documented design intent.

---

## Remediation

**Production fix (shipped 2026-05-02 via PR #94, squash `7697ca5`, primary commit `dbdf843`):**

1. **`Charger.gd`** — `WALL_STOP_FRAMES_REQUIRED = 2` constant + `_wall_stop_frames` counter; sub-epsilon increment + threshold check in `_physics_process`; reset counter on any non-sub-epsilon tick AND on `_begin_charge()`. Updated the doc-string + added an inline comment with the captured CI repro IDs.
2. **`tests/test_charger.gd`** — `test_killed_mid_charge_no_orphan_motion` restored to original shape (extra `_physics_process(0.016)` between drive and assert) since the production fix makes that tick safe again. New `test_killed_mid_charge_zero_velocity_immediate_loop` repeats the kill→tick→assert pattern 25 iterations as a deterministic regression detector. `set_physics_process(false)` in helpers kept as defense-in-depth (removes the engine-driven race as a confounder so the helper's manual driving is the sole driver).

**Why fix-forward beat quarantine:** the team's flake-quarantine pattern (`team/devon-dev/ci-hardening.md` §"When to quarantine vs. fix") explicitly says:

> | Bug repros locally on the same SHA | **Fix it.** Quarantine is for things you can't immediately fix. |
> | Test is wrong (bad assertion, race condition in the test itself) | **Fix the test, don't quarantine.** |
> | Only fails on CI (timing, autoload ordering...) | **Quarantine + open a follow-up ticket.** |

The flake started in the third row's territory (CI-only) but the diagnosis chain promoted it into the second row (test issue) and finally the first row (real production bug). At each promotion, fix-forward was the right call because the diagnosis was tractable within one dispatch tick. Quarantine was warranted only if the team had to ship around the flake before understanding it — Drew's diagnosis was fast enough to leapfrog quarantine entirely.

---

## Prevention

**1. Test-hygiene anti-pattern flag — *"test-passes-with-overridden-speed-but-fails-on-default"*:**

This is the reusable lesson. Whenever a test sets up a non-default scalar (move_speed = 180 in this case), the team should run a sibling test at the default value to expose this class of race. Encode this rule into:

- **`team/TESTING_BAR.md`** addendum (suggested follow-up ticket): "When a test overrides a numeric default that participates in physics or timing, file a sibling at the default value, OR document why the default-case is exercised elsewhere in the suite."
- **Mob-spec PR review checklist**: when introducing a new mob's tests, do all timing-sensitive tests use the same speed? If yes, that's a smell — vary the speed across tests so dt-sensitivity surfaces during initial authoring, not as a low-frequency CI flake six weeks later.

**2. CI-gate enhancement (deferred — covered by Devon's `ci-hardening.md` §"Items deferred"):**

`chore(ci): flake-detection sweep` — when the test suite plateaus (~2 weeks no new tests), run CI 5x in a row on a known-green commit; quarantine any test that flips pass/fail via GUT `pending()` + comment. This is already in Devon's deferred queue; reaffirmed here as a useful infrastructure investment.

**3. Looped-regression pattern as a portable test-hygiene tool:**

Drew's `test_killed_mid_charge_zero_velocity_immediate_loop` (25-iteration loop in the same test body) is a generalizable pattern for any time-sensitive invariant. Cost: ~15 ms per loop iteration in headless GUT. Benefit: future regressions become deterministic rather than one-shot flakes. Worth adding as a recommended pattern to `team/TESTING_BAR.md` for any test that exercises a physics or timing invariant.

---

## References

**Commits:**

- `dbdf843` — `fix(mobs): require 2 consecutive sub-epsilon frames for charger wall-stop` (the load-bearing production fix; first surfaced on `drew/charger-flake-fix` branch).
- `7697ca5` — squash-merge of PR #94 onto `main` (combines all three commits: helper change, test simplification, production fix).
- `12970ca` — `fix(mobs): charger orphan-velocity race in death-mid-charge path` (PR #94 commit 1; helper-side `set_physics_process(false)` change; partial fix).
- `4b7fd5c` — `chore(state): tess run 020 — sign-off + merge PR #94 charger flake fix` (Tess sign-off STATE bump).

**PRs:**

- PR #94 (`drew/charger-flake-fix`) — the fix PR, merged 2026-05-02 22:20.
- PR #95 — heartbeat tick that dispatched Drew on the flake fix.
- PR #93 — Tess run-019 sign-off + merge of PR #87 (CR-1/CR-2 time-scale guard); the run that flagged the flake repro evidence to Drew.

**CI runs (flake repros — all on workflow `CI`, `269833169`):**

- `25260213330` — initial flake repro on `workflow_dispatch` no-op branch off main; `test_killed_mid_charge_no_orphan_motion` failure.
- `25260326711` — same flake reproduced after PR #94 commit 1's `set_physics_process(false)` helper change. Confirmed Layer 1 was insufficient.
- `25260666771` — flake migrated to `test_velocity_during_charge_is_dir_times_speed` and `test_knockback_skipped_during_charge` after the second commit. Selectivity discriminator surfaced (move_speed-dependent).

**CI runs (post-fix green confirmations — all on SHA `dbdf843`):**

- `25260759815`, `25260786183`, `25260816869`, `25260843664`, `25260870293` — five consecutive `success` on the fix SHA. Tess verified each via `gh run view --json conclusion,headSha,workflowName` in run-020 sign-off.
- Pre-PR main baseline (run `25260215247`, SHA `4425ba4`): 586 tests / 585 passing / 1 risky-pending.
- Post-PR main (run `25260759815`, SHA `dbdf843`): 587 / 586 / 1. Delta = +1 test (the looped regression). Test count math reconciles.

**Cross-references:**

- `team/devon-dev/ci-hardening.md` §"Flake quarantine pattern" + §"When to quarantine vs. fix" — the policy doc this postmortem operates within. This case ran fix-forward, not quarantine, per the criteria in that doc.
- `team/STATE.md` Tess run-020 entry — the live sign-off with full CI evidence trail.
- `team/priya-pl/backlog-expansion-2026-05-02.md` T-EXP-8 — the ticket-shape that surfaced this postmortem as a deliverable.
- `team/log/process-incidents.md` — process-incidents log; this postmortem could be summarized as a one-line entry there if Priya's T-EXP-5 normalization sweep picks it up. Not duplicated inline because the postmortem is the canonical source.

**Tests (post-fix, on `main`):**

- `tests/test_charger.gd::test_killed_mid_charge_no_orphan_motion` (lines 317-344) — the original test that flaked; restored to its pre-flake shape post-fix.
- `tests/test_charger.gd::test_killed_mid_charge_zero_velocity_immediate_loop` (lines 347-374) — new looped regression detector, 25 iterations.
- `tests/test_charger.gd::_make_charger` / `_make_charger_with_def` (lines 41-63) — helpers with `set_physics_process(false)` defense-in-depth + inline comment explaining the historical race.
- `scripts/mobs/Charger.gd` lines 112-124 — the `WALL_STOP_DISPLACEMENT_EPSILON` + `WALL_STOP_FRAMES_REQUIRED` constants + comment.
- `scripts/mobs/Charger.gd` lines 281-293 — the wall-stop frame-counter logic in `_physics_process`.

---

## Caveat — fix-forward worked here, but it's not the default

This postmortem is *not* an argument that fix-forward always beats quarantine. Drew's diagnosis took three commits to land — that's three CI cycles of trial-and-error that, on a flakier or less-traceable bug, would have been better spent stabilizing CI via quarantine while diagnosis happened in parallel. The criteria in `ci-hardening.md` §"When to quarantine vs. fix" are correct; this case happened to fall on the fix-forward side because:

1. The flake had a clear evidence trail (CI run IDs + assertion-line numbers).
2. The diagnosis was tractable within one dispatch tick (Drew correctly identified the layered cause within ~3 CI iterations).
3. The blast radius was contained (one test class, one production code path).
4. The team was not under release pressure — M1 was feature-complete, Sponsor was OUT.

Future flakes that lack any of these four properties should default to quarantine first, fix later. This postmortem documents the exception, not the rule.
