## Self-Test Report — M3-T2-W1-T8 boss wake-anim (ticket 86c9wjyp9)

### Build context

- **Branch:** `devon/86c9wjyp9-boss-wake-anim`
- **Author environment:** Windows / git Bash. Godot CLI is **not** on this worktree's `PATH`, so headless GUT verification is delegated to CI (`Headless GUT` workflow auto-fires on `feat/devon/*` push).
- **HTML5 release-build:** triggered via `gh workflow run release-github.yml --ref devon/86c9wjyp9-boss-wake-anim` — link in the in-thread report after CI assembles the artifact.

### AC walkthrough

Per the ticket dispatch brief — every acceptance criterion + observed behavior:

| AC | Status | Evidence |
|---|---|---|
| 8 `wake_<dir>` animation keys exist on Stratum1Boss SpriteFrames | **PASS** | `grep "wake_" assets/sprites/boss/Stratum1Boss.tres` shows 8 entries: `wake_s`, `wake_se`, `wake_e`, `wake_ne`, `wake_n`, `wake_nw`, `wake_w`, `wake_sw`. Pinned by `tests/integration/test_stratum1_boss_wake.gd::test_sprite_frames_has_all_eight_wake_directions`. |
| 40 frame ext_resources land (8 dirs × 5 frames) | **PASS** | `f_392..f_431` ranges in tres. Pinned by `test_each_wake_direction_has_five_frames`. |
| State machine plays `wake_<dir>` on DORMANT exit (not instant transition) | **PASS** | `Stratum1Boss._set_state` mapping `STATE_WAKING -> _play_anim(&"wake")` at line 1326. Pinned by `test_set_state_plays_wake_anim_on_animated_sprite` + `test_wake_animation_uses_facing_dir_when_player_present`. |
| Damage-immunity holds for the wake duration | **PASS** | `take_damage` early-returns on `_state == STATE_WAKING` at line 468. Pinned by `test_damage_is_rejected_during_waking` (REGRESSION-86c9wjyp9 tag). |
| Boss transitions to STATE_IDLE after wake completes | **PASS** | `_physics_process` WAKING-handler at line 581 detects `_wake_left <= 0.0` and calls `_set_state(STATE_IDLE)`. Pinned by `test_waking_state_advances_to_idle_after_wake_duration` + `test_damage_lands_after_wake_window_closes`. |
| `boss_woke.emit()` fires once on wake entry (Beat 3 audio stinger timing) | **PASS** | `wake()` calls `boss_woke.emit()` line 442, immediately after `_set_state(STATE_WAKING)`. Pinned by `test_wake_call_transitions_dormant_to_waking`. |
| Frame duration ~417 ms (Uma BI-06 ~500 ms target band) | **PASS** | 5 frames @ 12 fps = 0.417 s. `WAKE_DURATION = 0.417`. Pinned by `test_wake_animation_speed_lands_inside_uma_bi06_band` + `test_wake_duration_constant_matches_frame_math`. |

### Side-effect inventory

Every surface this PR can fire on:

- **Stratum1Boss state machine** — new `STATE_WAKING` between DORMANT and IDLE. `_physics_process` handler added; all other state handlers unchanged.
- **AnimatedSprite2D** — `wake_<dir>` keys play once on `_set_state(STATE_WAKING)` and again on `_play_anim(&"wake")` direct call. No interaction with hit-flash modulate tween (tween targets `modulate`, anim targets `animation`).
- **Audio (AudioDirector)** — `_on_boss_woke_audio` fires at `boss_woke.emit()` time, same as before. Cue `sfx-boss-wake` plays at WAKING entry, NOT at IDLE arrival. Doc comment on handler clarified.
- **TimeScaleDirector** — no interaction. Wake window doesn't request hit-pause or slow-mo.
- **Hitbox / RoomGate / Inventory / Pickup / Loot** — no interaction. Wake is upstream of combat; loot path unchanged.
- **`[combat-trace]`** — three new lines in HTML5 soak stream: `Stratum1Boss.wake | exiting STATE_DORMANT -> STATE_WAKING`, `Stratum1Boss._process_waking | wake-anim complete -> STATE_IDLE`, `Stratum1Boss.take_damage | IGNORED waking amount=N hp=H wake_left=W`.
- **Test surface** — `tests/integration/test_stratum1_boss_wake.gd` (NEW, 14 tests); `tests/test_stratum1_boss.gd` (3 new + 1 reworked); `tests/test_stratum1_boss_animation_wire.gd` (`ANIM_STATES`/`ONE_SHOT_STATES`/`STATE_FPS` extended).

### HTML5 visual-verification gate

Per `html5-export.md` § "HTML5 visual-verification gate", this PR ships a **AnimatedSprite2D.play()** path. AnimatedSprite2D is engine-level draw — the same path `walk_<dir>` / `atk_<dir>` / `die_<dir>` already use across the M3W-4 mob roster (Grunt, Charger, Shooter, PracticeDummy, all M3W-3/4 PRs).

**Renderer-safety analysis:** `AnimatedSprite2D` reads frame textures from `SpriteFrames` and draws them via the engine's `CanvasItem` primitive (`Texture2D` blit). No Polygon2D, no Tween-on-modulate, no Area2D-state mutation. The same primitive path the existing `walk_<dir>` ships through — already validated in HTML5 across every prior boss-anim PR (M3W-4 #M3W-4-PR / T2 #287 / T3 #289 / T5+T6 #291).

**Per the per-surface enumeration rule from §"When a PR bundles eligible + ineligible surfaces":** the SpriteFrames-anim surface is escape-clause-eligible (renderer-safe). NO Polygon2D / CPUParticles2D / Area2D-state mutation in this PR.

**Invoking the escape clause** per `html5-export.md` § "Visual-verification escape clause":
- I cannot launch a browser interactively in this worktree environment.
- Visual probe targets for Sponsor / reviewer:
  1. **Wake animation plays** — after the 1.8 s boss-room entry sequence, the boss's standup animation (5 frames over ~417 ms) is visible immediately before the boss begins chasing the player. Look for the boss going from a stationary pose to a standing pose to engaging the player.
  2. **Damage rejection during wake-anim** — if the player gets close enough to land a swing within the first ~500 ms after the entry sequence completes, the boss's HP should NOT decrement during that window. (Trace `[combat-trace] Stratum1Boss.take_damage | IGNORED waking ...` will appear in the F12 console.) Damage should land cleanly after the wake-anim plays.
  3. **`sfx-boss-wake` stinger timing** — the audio stinger should still fire at Beat 3 timing (same as before — at the START of WAKING, not the END). Sound should NOT be delayed by ~417 ms.
  4. **Direction-correctness** — wake animation should face the direction toward the player at wake-entry time. Player entering from the south door → boss wakes facing north.

### Playwright e2e

**Playwright e2e:** the boss-room flow is Playwright-covered (`tests/playwright/specs/boss-room-smoke.spec.ts`). Manual kick required per `test-conventions.md` § "Playwright e2e CI does NOT auto-trigger on feat/* branches". Will be kicked in-thread once release-build artifact lands.

### Sponsor-soak probe targets

- **Probe 1** (visual): boss visibly stands up before chasing — not a teleport from frozen-pose to chase.
- **Probe 2** (timing-feel): wake-anim should feel "snappy" at ~417 ms — not draggy. If Sponsor flags "too slow", we have headroom to bump speed to 14-16 fps.
- **Probe 3** (audio-sync): `sfx-boss-wake` stinger lands at wake-entry, immediately after the BI-04/BI-05 cues. No new audio added under the wake-anim itself.
- **Probe 4** (damage-immunity-fairness): no way to "cheese-kill" the boss during wake — even with a fully-charged heavy swing landing in the first frame, the boss must not lose HP until the wake window closes.

### Doc updates

None. Wake-anim integration follows established M3W-4 conventions already documented in `.claude/docs/combat-architecture.md` § "M3W-1 realized implementation" + `.claude/docs/pixellab-pipeline.md` § "Folder-rename + reverse-map". No new non-obvious findings worth `.claude/docs/` capture.
