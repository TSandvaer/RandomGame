## Summary

M3-T2-W1-T8 (ticket [86c9wjyp9](https://app.clickup.com/t/86c9wjyp9)) — Stratum1Boss wake animation. PixelLab `getting-up` template, 8 directions × 5 frames = 40 frames, ~417 ms at 12 fps (Uma BI-06 ~500 ms target band).

Adds a new `STATE_WAKING` to the boss state machine that bridges `DORMANT → IDLE`:
- `wake()` now transitions `DORMANT → WAKING` (not direct to IDLE) and plays `wake_<dir>` on the AnimatedSprite2D.
- `boss_woke.emit()` still fires at the START of WAKING — BI-06 Beat-3 audio stinger timing preserved.
- Damage-immunity extended to cover the WAKING window. A player swing landing in the first frame after `wake()` can no longer kill the boss before it stands up.
- After `WAKE_DURATION` (~417 ms) drains via `_process_waking`, the boss auto-advances to `STATE_IDLE` — combat becomes available.

## Files touched

- `assets/sprites/boss/_pixellab_anims/Stratum1Boss/animations/wake/<dir>/frame_NNN.png` — 40 new frames (8 dirs × 5).
- `assets/sprites/boss/Stratum1Boss.tres` — 40 new `ext_resource` lines (`f_392..f_431`) + 8 new `wake_<dir>` animation entries (`loop=false`, `speed=12.0`). `load_steps=393 -> 433`.
- `scripts/mobs/Stratum1Boss.gd` — `STATE_WAKING` constant; `WAKE_DURATION = 0.417`; `_wake_left` timer; `is_waking()` public accessor; `wake()` revised; `take_damage` immunity gate extended; `_physics_process` WAKING handler; `_tick_timers` drain; `_set_state` mapping for `_play_anim(&"wake")`; `complete_wake_for_test()` test-only fast-forward.
- `scripts/levels/Stratum1BossRoom.gd` — `complete_entry_sequence_for_test()` chains into `_boss.complete_wake_for_test()` so existing room-based integration tests (8+ tests across `test_boss_wakes_and_engages`, `test_boss_loot_integration`, etc.) keep landing in `STATE_IDLE` without per-test wake-tick simulation.
- `tests/integration/test_stratum1_boss_wake.gd` — **NEW** paired GUT test (14 tests across SpriteFrames-asset / state-machine / damage-immunity / room-integration groups). Tagged REGRESSION-86c9wjyp9 against "wake-anim window forgot to extend immunity".
- `tests/test_stratum1_boss.gd` — updated `test_wake_transitions_to_idle` → `test_wake_transitions_to_waking_then_idle`; reworked `test_wake_is_idempotent` for the new state shape; added 3 new tests: `test_take_damage_during_waking_is_ignored`, `test_take_damage_lands_after_wake_window_closes`, `test_complete_wake_for_test_helper_advances_to_idle`.
- `tests/test_stratum1_boss_animation_wire.gd` — `ANIM_STATES` + `ONE_SHOT_STATES` extended with `wake`; new `STATE_FPS` per-state speed map (8 fps for legacy / 12 fps for wake); renamed `test_sprite_frames_fps_is_8_across_all_anims` → `test_sprite_frames_fps_matches_state_fps_map`.

## Doctrine-lock path

Per Drew's PR #291 empirical shortcut (`pixellab-pipeline.md` § "Doctrine palette compliance") — existing Stratum1Boss assets ship raw un-doctrine-locked PixelLab. The wake frames share `character_id 80a555b9-a2cc-4b81-b66b-f9de61415e4c` (same eye-variant boss) so palette parity is assumed.

Empirical spot-check (`.devon-tmp/palette_spotcheck.py`): wake palette 42 distinct hexes vs the existing on-disk slam+atk+die+walk reference 71 hexes — 23 intersect, 19 novel-in-wake. Novel hexes audited:
- All in the boss's color family (red glows `#F1373C`/`#D01F0C`, dark reds `#5C2C38`/`#794650`, sun-warmed skins `#ECB06B`, hood interior darks `#300305`)
- ZERO out-of-family colors (no blues, greens, purples)
- Consistent with PixelLab generating mid-tone interpolation pixels at the silhouette edge

Verdict: parity confirmed, no pixel-mcp orchestrator round-trip needed.

## Regression guard

The load-bearing structural test pinning the bug class this PR fixes is:

> `tests/integration/test_stratum1_boss_wake.gd::test_damage_is_rejected_during_waking`

Tagged `REGRESSION-86c9wjyp9`. Catches "wake-anim window forgot to extend immunity" — if a future refactor adds `STATE_WAKING` to the state enum but forgets to extend the `take_damage` guard, a player attack landing in the first frame after `wake()` would kill the boss prematurely. The complement `test_damage_lands_after_wake_window_closes` catches the inverse over-extension regression (immunity never released).

## Cross-lane integration check

Surfaces audited for ripple effects:

- **Audio** (`audio-architecture.md`) — `boss_woke.emit()` still fires on `DORMANT → WAKING` (now Beat 3 START rather than Beat 3 of the old direct DORMANT→IDLE), so `AudioDirector.play_sfx(&"sfx-boss-wake")` timing is preserved. Stratum1Boss.gd:1144 `_on_boss_woke_audio` handler unchanged. Doc comment on the handler updated.
- **Boss-room** (`Stratum1BossRoom.complete_entry_sequence_for_test`) — chained to fast-forward through both the 1.8 s entry sequence AND the 417 ms wake-anim. All 17 downstream `complete_entry_sequence_for_test()` callers across 7 test files keep landing in `STATE_IDLE` without per-test changes.
- **Inventory + Pickup + Loot** (`combat-architecture.md` § "Single MobLootSpawner per mob death") — boss-die path unchanged. Wake-anim is upstream of combat, has no interaction with loot drops. Confirmed by reading `_die`/`_spawn_death_particles`/`MobLootSpawner.on_mob_died` — no wake-state checks.
- **Mob registry / spawning** — wake is per-boss only; Grunt/Charger/Shooter/PracticeDummy have no wake animation and skip the gate. No registry surface touched.
- **`[combat-trace]`** — new `Stratum1Boss.wake` trace lines printed in HTML5 (gated on existing `_combat_trace` shim — no new gate). New trace lines: `wake -> STATE_WAKING (damage-immune wake-anim window, 0.417s)`, `_process_waking | wake-anim complete -> STATE_IDLE`, `take_damage | IGNORED waking amount=N hp=H wake_left=W`. Discoverable from soak streams.
- **Existing GUT tests** — three tests with hard `STATE_IDLE` post-`wake()` assertions migrated (see § "Files touched"). The chained `complete_entry_sequence_for_test()` keeps 17 downstream integration callers green.

## Self-Test Report

See PR comment below — author Self-Test Report posted before requesting Tess review per `self-test-report-gate`.

## Doc updates

None warranted this PR. The animation/state-machine shape follows established M3W-4 conventions already captured in `.claude/docs/combat-architecture.md` § "M3W-1 realized implementation" + `.claude/docs/pixellab-pipeline.md` § "Folder-rename + reverse-map". The wake addition is mechanically the same pattern.

Closes [#86c9wjyp9](https://app.clickup.com/t/86c9wjyp9).
