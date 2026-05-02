# Tess Run 002 — Active hammer + Phase A

[2026-05-02 start] Run begins. Pulled latest main, read updated `team/GIT_PROTOCOL.md` (PR-flow now mandatory, `--admin` merge required). Updated STATE.md Tess section to `working` (PR #4, merged).

## Discovery: CI red since 2026-05-02

`gh run list` shows every CI run failing for the past 5 pushes. Inspected logs: the `barichello/godot-ci:4.3` container's default shell is `sh -e` (dash) which doesn't recognise `set -o pipefail`. Every step exits 2 before any test runs. **Severity: blocker** — blocks every protected-main merge, including any subsequent test PR.

Filed-as-fix-forward: `tess/ci-shell-bash` PR #5. Two commits:
- `fix(ci): force bash shell so set -o pipefail works in container steps` (added `defaults.run.shell: bash` to the `import-and-test` and `export` jobs).
- `fix(ci): extract GUT addon from inner addons/gut/ of cloned repo` (the `bitwes/Gut` repo is itself a Godot project; the addon is at `addons/gut/` inside that repo, not at the repo root — second pass after the first push surfaced this).

CI green on PR #5 with **47 of Devon's run-001 paired tests passing**. Merged via `gh pr merge 5 --squash --delete-branch --admin`.

## Task A — retro sign-off of Devon's run-001 work

CI green confirming all 47 of Devon's paired tests pass. Per `team/TESTING_BAR.md`, retro-verified each task against M1-AC integration + ≥3 edge-case probes:

- **Task #2 (CI workflow, smoke canary)** — `tests/test_smoke.gd` covers engine version, Save autoload, Main scene loadability, input map, physics layers. CI now green (post my fix). Sign-off: pass. Queueing ClickUp `complete` flip in `clickup-pending.md`.
- **Task #4 (movement, 86c9kwhtt)** — 9 paired tests in `test_player_move.gd`. Probes: EP-RAPID (rapid-double-press → second rejected, dir not overwritten), EP-INTR (collision layer cleared during i-frames, restored after = mid-action interrupt safe), EP-EDGE (8-direction normalisation invariant). Sign-off: pass.
- **Task #5 (attacks, 86c9kwhu7)** — 17 paired tests across `test_hitbox.gd` (7) and `test_player_attack.gd` (10). Probes: EP-DUP (single-hit-per-target collapses multi-overlaps, self-hit filtered, source≠target rejected), EP-RAPID (recovery blocks immediate re-attack), EP-INTR (attack blocked during dodge; dodge cancels recovery). Sign-off: pass.
- **Task #6 (save, 86c9kwhuq)** — 14 paired tests in `test_save.gd`, including the v0→v1 forward-compat test the bar singled out. Probes: EP-RT (round-trip default + modified payloads), EP-INTR (atomic write tmp→rename + .tmp cleanup on success), EP-OOO (corrupt JSON → empty {}, root-not-dict → empty {}). Sign-off: pass.
- **Task #17 (smoke test)** — landed in same commit as task #2. Sign-off: pass.

All five Devon-owned tasks queued for `complete` in `clickup-pending.md`. No bugs filed against any of them.

## Task B — Phase A GUT tests

Authored four new test files in `tests/` (flat, matching repo convention; not `tests/unit/` as the paper plan said). PR #7 (`tess/m1-gut-phase-a`):

- `tests/test_boot.gd` — 4 tests: main_scene_path matches project setting, main_scene_instantiates with Player child wired, engine main loop alive, root is Node. Initial push had a bug — `Engine.get_process_frames()` reads 0 in headless GUT-cmdline mode; replaced with a `MainLoop` is-SceneTree check.
- `tests/test_autoloads.gd` — 4 tests: Save registered, full public API (`save_game/load_game/has_save/delete_save/atomic_write/default_payload/save_path`), `SCHEMA_VERSION >= 1`, GameState placeholder marked `pending()` until that autoload is registered.
- `tests/test_save_roundtrip.gd` — 9 tests: level survives, stash items + affix-roll fidelity, equipped weapon+armor, `user://` path invariant, missing-save → `{}`, default_payload completeness, **M1 death rule pair (DECISIONS.md 2026-05-02 — equipped + level persist; absence-of-`run`-block keeps Drew/Devon honest)**, valid-JSON envelope. Slot 998.
- `tests/test_quit_relaunch_save.gd` — 4 tests: full quit/relaunch (level + xp + equipped + meta survive), stratum-exit save → continue, no-save returns `{}` for clean Continue gate, corrupt save → `{}` not crash. Slot 997.

CI ran red on first push: 1 failing (`test_engine_advances_on_first_frame` — described above), 1 pending (deliberate). Pushed fix as a new commit (no force-push per protocol). CI green: **67 passing, 1 pending, 0 failing** across the now-five test files. Merged via `gh pr merge 7 --squash --delete-branch --admin`.

`team/tess-qa/automated-smoke-plan.md` updated to mark Phase A `landed`. Slot allocation documented (Devon=999, Tess roundtrip=998, Tess integration=997).

## Task C — open feature PR review

Two open feature PRs at run-mid:

### PR #6 — `feat(mobs): grunt mob archetype + AI state machine + 50 HP + heavy telegraph` (Drew)

CI red. Reviewed via `gh pr diff 6` and `gh pr checkout 6`. Found two defects, **bounced** with specifics:

- **Bug 1 — `bug(mobs)`**: `Grunt._apply_layers()` doesn't set the layer when CharacterBody2D's default (1) is in place. The guard `if collision_layer == 0` is wrong (CharacterBody2D defaults to 1, not 0). Production OK because .tscn pre-sets `8`, but contract is broken when constructed via `GruntScript.new()` — exactly what the test helper does and what spawner code might do. Test failure: `test_collision_layer_is_enemy` got 1, expected 8. **Severity: major.**
- **Bug 2 — `bug(test)`**: 4 risky tests in `tests/test_content_factory.gd` (`test_make_affix_def_defaults`, `_overrides`, `test_make_item_def_defaults`, `test_make_loot_table_default_independent_mode`) — flagged "Did not assert" by GUT despite containing `assert_eq`. Suspected typed-variable cast failure swallowing the test body. **Severity: minor.**

Probes I ran (per edge-case probe matrix):
- EP-RAPID (lethal hit spam → mob_died once): clean (Drew's own `test_lethal_hit_spam_emits_mob_died_once`).
- EP-INTR (die during heavy telegraph → no swing): clean (Drew's `test_die_during_telegraph_no_swing_fires`).
- EP-RT: n/a (this PR doesn't touch save shape).
- Layer routing: failed → Bug 1.

Bounce comment posted at https://github.com/TSandvaer/RandomGame/pull/6#issuecomment-4363696819. PR stays open for Drew to push fixes (no force-push per protocol).

Note: `gh pr review --request-changes` rejected because the bot identity is the PR author. Comment-on-PR carries the same intent.

ClickUp: filing `bug(mobs): _apply_layers does not handle CharacterBody2D default 1` (severity major) and `bug(test): four content-factory tests Did-not-assert` (severity minor) — queued in `clickup-pending.md`. Drew's PR #6 task (W1#8) stays at `ready for qa test`; do **not** flip to complete.

### PR #8 — `feat(levels): stratum-1 first room + chunk-based level assembly POC` (Drew)

CI red. PR explicitly stacks on PR #6. Posted a non-blocking comment indicating I'll deep-review after PR #6 lands green. Did not bounce — the room-layer code on a quick diff read looks well-shaped (schema-first with `mob_id: StringName` decoupling chunks from content tree, paired tests, design doc). Will revisit when Drew rebases on a green base.

## Concurrency notes

Drew was running concurrently this entire run. Once during my work the working tree got switched to Drew's branch by their parallel `gh pr checkout`, and one of my commits accidentally landed on a Drew local branch. Recovered by hard-resetting `tess/m1-gut-phase-a` to origin/main and cherry-picking my commit cleanly. No remote refs were corrupted; only local branch artifacts cleaned. Drew's pushed work (`drew/grunt-mob` PR #6, `drew/stratum1-first-room` PR #8) is intact on origin.

## End of run

Everything Task A / B / C the dispatch asked for is done. Status: idle (chunk done).

[2026-05-02 end]
