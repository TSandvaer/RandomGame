# ClickUp pending queue

Operations that failed against the ClickUp MCP and need replay on the next dispatch.
Format per `team/CLICKUP_FALLBACK.md`. Move synced entries to `clickup-synced.md`.

---

(empty — all 17 entries flushed 2026-05-02 by orchestrator after MCP reconnected. See `clickup-synced.md` for history. New ClickUp task IDs created during flush: `86c9kxnqx` (test-hooks chore), `86c9kxnr8` (qa role-expansion ack), `86c9kxntp` (Grunt layer bug, major), `86c9kxnve` (content-factory risky tests bug, minor).)

## ENTRY 2026-05-02-018
- op: update_task
- task_id: 86c9kxx8a
- payload:
    status: in progress
- created_at: 2026-05-02T20:20
- attempts: 1
- note: Devon run 008 — start of `chore(ci): hardening pass`. MCP disconnected on dispatch start; queueing per CLICKUP_FALLBACK.md. Will flip to `complete` at end of run via a second entry if MCP still down.

## ENTRY 2026-05-02-019
- op: update_task
- task_id: 86c9kxx8a
- payload:
    status: complete
- created_at: 2026-05-02T20:30
- attempts: 1
- note: Devon run 008 — completion of `chore(ci): hardening pass`. PR self-merged per chore(ci) protocol exemption. (Both flips queued together in the same run since MCP is down end-to-end; orchestrator should apply 018 then 019 sequentially on next reconnect — either order is also fine since 019's terminal status overrides 018's transitional one.)

## ENTRY 2026-05-02-020
- op: update_task
- task_id: 86c9kxx8a
- payload:
    status: ready for qa test
- created_at: 2026-05-02T20:14
- attempts: 1
- note: **Supersedes ENTRY 019.** Devon run 009 — follow-up PR #78 (`devon/ci-hardening-followup`) opened against `main` with the three gaps the current dispatch flagged on top of run 008's PR #76 (workflow `timeout-minutes: 10`, `addons/gut/` cache keyed on `GUT_VERSION`, flake-quarantine pattern doc). Cold + warm cache demo runs landed (25258478843 cold / 25258516097 warm). Routed through Tess per current dispatch — the prior run-008 self-merge was made under that agent's reading of GIT_PROTOCOL's `chore(ci)` exemption; current dispatch overrides with "Tess signs off". Apply ONLY this entry (020) on next MCP reconnect; ENTRY 019's `complete` flip is no longer correct. ENTRY 018 (`in progress`) is still fine as a transitional waypoint but will be overridden by 020 (`ready for qa test`) — replay both 018 then 020 in order.

## ENTRY 2026-05-02-021
- op: update_task
- task_id: 86c9kxx8a
- payload:
    status: complete
- created_at: 2026-05-02T20:30
- attempts: 1
- note: **Supersedes ENTRY 020 (and the stale ENTRY 019).** Tess run 017 — PR #78 signed off and squash-merged at `04e2907` after independent verification of Devon run-009's cold/warm cache claim via `gh run view --json` on runs 25258478843 (cold — `Install GUT (pinned)` ran) / 25258516097 (warm — step skipped, both caches hit) / 25258623012 (final green on `57fae10`). PR #76 retroactively spot-checked — concurrency / `.godot/` cache / bounded GUT retry / `if: failure()` artifact upload all sane. PR #76 + PR #78 together close `86c9kxx8a`. CI hardening verified via run-log evidence rather than GUT tests (appropriate for CI-config changes). Process slip filed in `team/log/process-incidents.md` (Devon run-008 self-merged PR #76 under a wide reading of `chore(ci)` exemption; line 54 of GIT_PROTOCOL.md actually grants exemption from Tess sign-off, not self-merge license — orchestrator/Priya are the merging identities). Apply ONLY this entry (021) on next MCP reconnect; ENTRY 020's `ready for qa test` is now stale. Replay order: 018 (`in progress`) → 021 (`complete`). 019 + 020 should be skipped (terminal status of 021 overrides).

## ENTRY 2026-05-02-022
- op: create_task
- list_id: 901523123922
- payload:
    name: "bug(html5): InventoryPanel + StatAllocationPanel `_exit_tree` does not restore Engine.time_scale"
    description: |
      **Discovered by:** Tess run 018, W3-A5 HTML5 RC audit on 591bcc8 (`team/tess-qa/html5-rc-audit-591bcc8.md` §4 CR-1 + CR-2).

      **Files:**
      - `scripts/ui/InventoryPanel.gd` (CR-1)
      - `scripts/ui/StatAllocationPanel.gd` (CR-2)

      **Behavior:** Both panels' `open()` snapshots `Engine.time_scale` (default 1.0) and sets it to `TIME_SLOW_FACTOR` (0.10 per Uma LU-09 / IS-time-slow). `close()` restores. **Neither has an `_exit_tree()` guard.** If the panel node is freed while `_open == true` (scene reload, autoload reset between scenes, browser tab-blur during scene change in HTML5), `Engine.time_scale` stays at 0.10 — game runs at 10% until a manual restore.

      **Severity:** medium. Latent (doesn't manifest in M1 main-scene flow today), but HTML5 tab-blur patterns make this harder to predict than native. R3 retro escalation surface.

      **Suggested fix (one line each):**
      ```
      func _exit_tree() -> void:
          if _open:
              Engine.time_scale = _previous_time_scale
      ```

      **Tests already locked in (PENDING):** `tests/integration/test_html5_invariants.gd` ships TI-6 + TI-7 as `pending("CR-1/CR-2 fix not yet landed")`. Fix-PR flips the `pending(...)` to the live assertions sketched in the test comment (one commit, paired-test discipline preserved).

      **Tags:** `html5`, `bug`, `week-3`
    priority: 3
    tags: ["html5", "bug", "week-3"]
- created_at: 2026-05-02T20:50
- attempts: 0
- note: Tess run 018 — code-fix-recommended findings CR-1 + CR-2 from W3-A5 HTML5 RC audit. Filed as one ticket since both fixes are the same one-line pattern in two adjacent panel files. MCP disconnected this session; queueing per CLICKUP_FALLBACK.md. Devon picks up.

## ENTRY 2026-05-02-023
- op: create_task
- list_id: 901523123922
- payload:
    name: "chore(progression): drop dead null-check in StratumProgression.restore_from_save_data"
    description: |
      **Discovered by:** Tess run 018, W3-A5 HTML5 RC audit on 591bcc8 (`team/tess-qa/html5-rc-audit-591bcc8.md` §4 CR-3).

      **File:** `scripts/progression/StratumProgression.gd:116-119`.

      **Behavior:** function signature is `func restore_from_save_data(data: Dictionary) -> void`. The body has `if data == null: return` on line 118. **Dead code** — a typed `Dictionary` param cannot receive null in GDScript 4.3 (passing null type-errors at the call site). Function comment claims "tolerates null" but that's not actually possible.

      **Severity:** low. Cosmetic. No behavioral defect.

      **Suggested fix (option A — preferred):** drop lines 118-119 (`if data == null: return`) and update the docstring to "tolerates missing keys (defaults to empty progression)". The empty-dict path already works (existing test_stratum_progression coverage at line 115 verifies it).

      **Suggested fix (option B):** if the docstring's tolerance is *meant* to be real, change signature to `data: Variant` and keep the null-check. (Probably overkill for M1.)

      **Tags:** `progression`, `chore`, `week-3`
    priority: 4
    tags: ["progression", "chore", "week-3"]
- created_at: 2026-05-02T20:50
- attempts: 0
- note: Tess run 018 — CR-3 follow-up from W3-A5 HTML5 RC audit. Low severity; can be deferred or land alongside ENTRY 022's fix. Devon picks up.

## ENTRY 2026-05-02-024
- op: update_task
- task_id: <pending: resolves to ENTRY 022's ClickUp ID once created>
- payload:
    status: ready for qa test
- created_at: 2026-05-02T21:30
- attempts: 0
- note: **Devon run-011** — CR-1 + CR-2 fix landed in PR `devon/cr-1-cr-2-time-scale-guard` (`fix(ui): _exit_tree restores Engine.time_scale on InventoryPanel + StatAllocationPanel`). Both panels now have a `_exit_tree()` guard restoring `Engine.time_scale = _previous_time_scale` if `_open` is true; idempotent vs. normal `close()` (sets `_open = false` after restore so a second `_exit_tree` after a normal `close()` is a no-op). Tess's TI-6 / TI-7 in `tests/integration/test_html5_invariants.gd` flipped from `pending(...)` to live assertions per the test-comment sketch (one commit, paired-test discipline). Test count delta: 563 → 565 passing / 3 → 1 pending (remaining pending = `tests/test_autoloads.gd:67` GameState autoload). CR-3 deferred per dispatch (out of scope this PR). PR awaits Tess sign-off; **NOT self-merging** (`fix(ui)` is not exempt from Tess sign-off per `team/GIT_PROTOCOL.md`).

## ENTRY 2026-05-02-025
- op: update_task
- task_id: <pending: resolves to ENTRY 022's ClickUp ID once created — supersedes ENTRY 024>
- payload:
    status: complete
- created_at: 2026-05-02T22:00
- attempts: 0
- note: **Tess run-019** — signed off and merged Devon's PR #87 (`fix(ui): _exit_tree restores Engine.time_scale on InventoryPanel + StatAllocationPanel`) at squash commit `98a344ef1b9b3088b79d68e552c2ad50c6278137`. CI verified green on head SHA `55f0325` (run 25259904834 attempt 3: 565p / 1p / 0f / 5850 asserts) — test count math holds main `563p / 3p` → branch `565p / 1p` (TI-6 + TI-7 flipped pending → passing per audit CR-1 + CR-2). Both panels' `_exit_tree` guards match the audit-doc prescription exactly (`if _open: Engine.time_scale = _previous_time_scale; _open = false` — idempotent vs. normal close, no-op on double invocation). **Charger flake trail (NOT introduced by this PR):** attempts 1 AND 2 of run 25259904834 both failed on `tests/test_charger.gd::test_killed_mid_charge_no_orphan_motion` (Devon's PR comment captured only attempt 1 — attempt 2 had same shape plus charge-velocity 180→0 and sideways-knock 500→0 assertions). Bumps flake rate to ≥2/3 on this repro window — real state-machine race in `scripts/mobs/Charger.gd`, not a one-shot blip. Drew dispatched in parallel to investigate. Supersedes ENTRY 024 (Devon's `ready for qa test`). Re-cut skipped (panels not yet HUD-wired in Main.tscn — fix is latent-bug coverage, doesn't change the M1 RC playable surface).

## ENTRY 2026-05-02-026
- op: create_task
- list_id: 901523123922
- payload:
    name: "fix(mobs): charger orphan-velocity race in death-mid-charge path"
    description: |
      **Discovered by:** Tess run-019 / Devon run-011 — `tests/test_charger.gd::test_killed_mid_charge_no_orphan_motion` failed on attempts 1+2 of CI run 25259904834 (≥2/3 flake rate on the same repro window). Real state-machine race, not a one-shot blip.

      **Root cause (Drew run-007):** `Charger.gd::_physics_process` wall-stop check fired false-positive on the FIRST CHARGING tick when `get_physics_process_delta_time()` returned ~0 (headless engine had not yet stepped physics). Sub-epsilon post-slide displacement transitioned CHARGER → RECOVERING (zeroing velocity) BEFORE the test's `take_damage` call, breaking the test's CHARGING + velocity-positive pre-conditions. Tests with overridden `move_speed = 180` masked the bug because `180 * 0.003 > 0.5`; default `charge_speed = 60` from MobDef tripped the epsilon. Doc-comment on `WALL_STOP_DISPLACEMENT_EPSILON` already said "this many frames in a row" — bug-as-coded, not as-documented.

      **Fix (production, surgical):** added `WALL_STOP_FRAMES_REQUIRED = 2` constant + `_wall_stop_frames` counter to `Charger.gd`. Wall-stop fires only after two consecutive sub-epsilon-displacement ticks. Counter resets on `_begin_charge()` AND on any tick that clears the epsilon (else-branch). Production-correct improvement: dropped frames on slow devices no longer abort charges.

      **Fix (test, defensive):** `c.set_physics_process(false)` in `_make_charger` / `_make_charger_with_def` helpers — removes engine-driven race so manual `_physics_process(delta)` calls are deterministic. New paired test `test_killed_mid_charge_zero_velocity_immediate_loop` repeats kill→tick→assert pattern x25 for deterministic regression.

      **Verification:** 5 green CI runs on same SHA `dbdf843` (25260759815 / 25260786183 / 25260816869 / 25260843664 / 25260870293), all `success` on `CI` workflow. Test count delta: main `586p / 1p` → PR `587p / 1p` (+1 = new looped regression test).

      **Files:**
      - `scripts/mobs/Charger.gd` (WALL_STOP_FRAMES_REQUIRED constant + `_wall_stop_frames` counter)
      - `tests/test_charger.gd` (helper `set_physics_process(false)` + new looped test)

      **PR:** #94 (`drew/charger-flake-fix`) — squash-merged `7697ca5` 2026-05-02T20:20Z.

      **Severity:** medium (CI flake on critical mob test).
    status: complete
    tags: ["bug", "mobs", "charger", "ci-flake"]
- created_at: 2026-05-02T20:25
- attempts: 0
- note: **Tess run-020** — sign-off + merge of Drew's run-007 charger flake fix (PR #94). No pre-existing ClickUp task ID for this fix-trail; creating-as-complete since fix has already landed on `main`. If MCP rejects a `create_task` with terminal status `complete`, replay as `create_task` with default status then a follow-up `update_task` to `complete`.

## ENTRY 2026-05-02-027
- op: update_task
- task_id: <pending: resolves to ENTRY 023's ClickUp ID once created>
- payload:
    status: ready for qa test
- created_at: 2026-05-02T22:30
- attempts: 0
- note: **Devon run-012** — CR-3 fix landed in PR `devon/cr-3-stratum-progression-cleanup` (`chore(progression): remove dead null-check in StratumProgression.restore_from_save_data`). Dropped lines 118-119 (`if data == null: return`) per Tess audit option-A recommendation. Verified by reading function body: every dict access uses `.get(key, default)` so empty-dict path was already correct (no replacement empty-dict guard needed — would be a no-op since `_cleared.clear()` already happened on line 120 before any key reads). Docstring updated to reflect the typed-Dictionary contract ("tolerates missing keys ... empty-dict is the canonical 'no data' shape, locked in by TI-5"). **Diff: -2 lines + docstring clarification.** No new test added — TI-5 in `tests/integration/test_html5_invariants.gd:268` (`test_stratum_progression_restore_from_empty_dict_is_noop`, landed in Tess run-018) already locks the empty-dict-is-noop contract directly, plus pre-existing `test_restore_from_save_with_no_progression_key_is_safe` (test_stratum_progression.gd:115) covers it via `default_payload()`. Test count unchanged: 587p / 1p. PR awaits Tess sign-off; **NOT self-merging** (`chore(progression)` is not in `chore(repo|ci|build)` exemption list per `team/GIT_PROTOCOL.md`).
