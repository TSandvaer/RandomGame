## Summary

T11 — **TimeScaleDirector** autoload: stacked, reason-keyed ownership of `Engine.time_scale` so concurrent slow-mo / hit-pause / freeze requesters never clobber each other. Lands as Wave 1 foundational per `team/priya-pl/m3-tier2-boss-room-polish-scope.md` §3 T11.

This PR ships the director + paired tests only. T2 (hit-pause), T3 (phase-transition slow), and T16 (boss-defeated freeze) — its downstream consumers — adopt the director in their own PRs in this same wave.

## Acceptance criteria (per Priya §3 T11)

- [x] `TimeScaleDirector` registered in `project.godot` `[autoload]` section.
- [x] API: `request(reason, scale, duration, priority := 0)`, `release(reason)`, `freeze(duration, reason := "freeze")`, plus `reset()` / `current_scale()` / `active_reasons()` / `is_active(reason)` introspection helpers.
- [x] Stack semantics: highest-priority bucket wins; within bucket, lowest-scale (most restrictive) wins; empty stack → 1.0.
- [x] Auto-release on duration expiry via SceneTreeTimer; idempotent on double-release.
- [x] Paired GUT tests (`tests/test_time_scale_director.gd`) cover single-request lifecycle, multi-request stacking, priority dominance, expiry, re-request replace, reset, freeze sugar, misuse warning routing, signal emission shape, and the T2-vs-T3 conflict-resolution contract.

## Design calls (under-specified in AC, decided here)

1. **Priority field on top of "lowest-scale-wins".** Priya's AC says "lowest-scale-among-active-requests wins" AND (in T3 AC) "phase-transition wins over hit-pause." These conflict at face value because hit-pause's natural scale (0.0 / near-freeze) is LOWER than phase-transition's 0.3. Resolution: add an integer `priority` parameter (default 0). Highest priority bucket dominates regardless of scale; within bucket, lowest scale wins. Documented constants: `PRIORITY_DEFAULT=0` (hit-pause / ephemeral), `PRIORITY_NARRATIVE=1` (phase-transition / level-up slow), `PRIORITY_FREEZE=2` (final-hit / modal). T2's hit-pause uses default; T3's phase-transition uses NARRATIVE; T16's freeze uses FREEZE. The "lowest-scale among PEERS" rule is preserved within each priority bucket; the explicit priority handles the cross-class case Priya named.

2. **Hit-pause scale floor + `freeze()` sugar.** Direct `request(reason, 0.0, ...)` would be ambiguous between "a true freeze" and "a misuse of request." Resolution: `request` clamps scale to `[0.01, 1.0]` and emits a `WarningBus` warning on clamp; callers wanting a true 0.0 stop go through `freeze(duration, reason)`, which uses `PRIORITY_FREEZE` (priority 2) by default. This makes intent structural: misuse is loud + the "is this a freeze" classification is in the API surface, not in scale-value detection.

3. **Real-time SceneTreeTimer for auto-release.** Created with `process_always = true` so the timer ticks in real seconds regardless of `Engine.time_scale`. Critical for `freeze(duration)`: a scaled timer scheduled while the engine is at 0.0 would never tick out, leaking the freeze forever. Verified by `test_freeze_auto_release_works_despite_scale_0` — the bug class this guards.

4. **Re-request replaces prior entry + cancels stale timer via generation token.** A re-request for the same `reason` (e.g. extending a freeze) replaces the prior Dictionary; the OLD timer's `_on_auto_release` callback receives the OLD entry instance as a "generation" bind argument. If the live `_requests[reason]` is a DIFFERENT Dictionary instance, the stale timer no-ops. Verified by `test_rerequest_cancels_prior_auto_release_timer`. (SceneTreeTimer has no `cancel()` method; this is the only correct way to invalidate a pending timer in Godot 4.3.)

5. **InventoryPanel + GUT test plumbing NOT migrated in this PR.** `scripts/ui/InventoryPanel.gd` continues to write `Engine.time_scale` directly via its snapshot-and-restore pattern. Migration is a follow-up — flagging here so a future writer landing alongside InventoryPanel can route through the director and Tess can pick up the conflict-test pattern. Acceptable for now because InventoryPanel is the sole non-director writer; a second-writer landing is the trigger for migration. `tests/integration/*.gd` defensive `Engine.time_scale = 1.0` resets remain (they reset by writing past the director, which is fine for test plumbing — production code must not).

## Regression guard

Two test methods structurally pin the contract:

- `test_t2_t3_conflict_phase_transition_wins_over_hit_pause` — exact instance of Priya's T3 AC "phase-transition wins over hit-pause." If a future refactor inverts priority resolution, this fails loud with the product-level intent it broke in the message.
- `test_freeze_auto_release_works_despite_scale_0` — pins the real-time-timer choice. A regression to scaled timers (the seductive default) leaks freeze duration forever; this catches it.

If `TimeScaleDirector` itself is removed / refactored away, every test in `tests/test_time_scale_director.gd` fails before downstream T2/T3/T16 tests run — the autoload contract is the early gate.

## Cross-lane integration check

- **Combat** — Hitbox / Boss / Player damage pipeline: no surface touched in this PR. T2 hit-pause + T3 phase-transition slow + T16 boss-defeated freeze are downstream PRs that adopt the director on top.
- **Inventory** — `InventoryPanel.open() / close() / _exit_tree()` still writes `Engine.time_scale` directly (TIME_SLOW_FACTOR = 0.10). Director state and panel state are independent today; migration deferred per design call #5. NoWarningGuard catches misuse paths on this director surface; existing inventory tests untouched.
- **Level / RoomGate** — no time-scale interaction; rooms don't pause time. Stratum1BossRoom signals (`entry_sequence_started/completed/boss_defeated`) are not subscribed by this PR.
- **Audio** — AudioDirector is independent; the director does not pause/duck audio. Future cross-coordination (e.g. duck SFX during a freeze) is out of scope.
- **Loot** — boss-died loot pipeline runs at frame 0 BEFORE any T2/T16 freeze request fires (T2 AC explicitly preserves this; the director's freeze request would land AFTER `boss_died` signal handlers complete). No PR-level risk in this scope.
- **Save** — director state is in-memory autoload only; not persisted across saves (intentional — time-scale is ephemeral combat state, not run state).

## Self-Test Report

Posted as a PR comment per `self-test-report-gate` memory.

## Doc updates

Flagging `.claude/docs/time-scale-director.md` for the maintain-docs Stop hook to author from this PR — Priya's scope §5 finding 2 explicitly calls out "capture in fresh `.claude/docs/time-scale-director.md` when T11 lands." The director's API contract + stack semantics + priority resolution + real-time-timer pattern + InventoryPanel-migration-policy footnote are the load-bearing cross-system contract future combat-feel work (all-mob hit-pause, level-up time-slow, modal-pause) will adopt.

## Test plan

- [x] GUT paired tests pass headless on CI (`tests/test_time_scale_director.gd`)
- [x] No-warning-guard catches misuse paths (empty reason, out-of-range scale)
- [x] Signal emission verified (`scale_changed` fires only on actual change; `request_changed` op strings stable)
- [x] HTML5 release-build smoke check — `Engine.time_scale` plumbing behaves identically vs desktop (per Self-Test Report)
- [ ] Tess QA sign-off

🤖 Generated with [Claude Code](https://claude.com/claude-code)
