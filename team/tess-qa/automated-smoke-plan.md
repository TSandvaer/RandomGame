# Automated Test Plan — Embergrave M1

Owner: Tess (QA). Per `team/TESTING_BAR.md`, Tess **authors** these tests herself — does not wait for the devs to write them. Status: **paper inventory** until Devon's Godot scaffold + GUT integration commits land; then Tess writes the `.gd` files in priority order below.

## Targets (binding from `TESTING_BAR.md`)

- **Unit tests (GUT, headless):** 20–30 by M1 sign-off.
- **Integration tests (GUT scene-runner or scripted):** 10–15 by M1 sign-off.
- **CI:** green on every push. Red CI blocks all merges.

## Why GUT, why now

- **GUT** (Godot Unit Test) is in the tech-stack pick (`team/priya-pl/tech-stack.md`). It runs in `--headless` mode in CI on every PR. That's our cheapest defense: no merge can land if these tests fail.
- The bar is **not** "smoke only." Per Sponsor's directive, we hammer the systems with non-trivial logic (combat math, loot rolling, save/load, level-up, dodge i-frames, mob AI state transitions).
- Each test is small (≤30 lines), fast (<1s), and runs every PR.

## Prerequisites (one-time, blocks Tess from starting)

These must land before Tess writes the actual `.gd` files:

1. Godot 4.3 project scaffold committed (week-1 task #1).
2. GUT plugin installed (per Devon's decision: CI clones `bitwes/Gut` v9.3.0 at workflow time; local devs install via Godot AssetLib).
3. GitHub Actions workflow that runs `godot --headless --import` then `gut_cmdln.gd` and fails the build on any test failure.
4. Autoloads registered (at minimum: `GameState`, `SaveSystem` — names confirmed via Devon's decision log).
5. JSON save schema landed (week-1 task #6).
6. Player scene with input handling (week-1 task #4).
7. Grunt mob scene + collision/damage hookup (week-1 tasks #5, #8).
8. Drew's TRES schema (`MobDef`, `ItemDef`, `AffixDef`, `LootTableDef`) committed (week-1 task #7).

Tess writes Phase A (boot/save) once 1–5 land; Phase B (combat/loot) once 6–8 land.

## Test inventory

Test ID format: `tu-<area>-<NN>` (unit) or `ti-<area>-<NN>` (integration). One file per area, multiple `func test_*` cases per file.

### Phase A — boot & save (writes first; ~6 unit + 2 integration)

#### `tests/unit/test_boot.gd` — game boots without errors

| ID            | Test                                       | What it asserts                                                                  |
|---------------|--------------------------------------------|----------------------------------------------------------------------------------|
| `tu-boot-01`  | `test_main_scene_instantiates`             | `load("res://scenes/main.tscn").instantiate()` is non-null and parse-error-free.  |
| `tu-boot-02`  | `test_no_orphan_errors_on_first_frame`     | After 1 process frame, no `push_error` was logged. `Engine.get_frames_drawn() > 0`. |

#### `tests/unit/test_autoloads.gd` — singletons register

| ID                 | Test                                   | What it asserts                                                              |
|--------------------|----------------------------------------|------------------------------------------------------------------------------|
| `tu-autoload-01`   | `test_gamestate_present`               | `GameState` autoload exists and is the expected class.                       |
| `tu-autoload-02`   | `test_savesystem_present_and_api`      | `SaveSystem` exists; has `save_game()` and `load_game()` methods (signature). |

#### `tests/unit/test_save_roundtrip.gd` — JSON save/load preserves persistent data

The most fragile shared surface in M1. Deepest coverage.

| ID               | Test                                            | What it asserts                                                              |
|------------------|-------------------------------------------------|------------------------------------------------------------------------------|
| `tu-save-01`     | `test_save_load_preserves_level`                | `character_level=3` survives a save→clear→load cycle.                         |
| `tu-save-02`     | `test_save_load_preserves_stash_items`          | Stash array (item IDs + affix rolls) survives round-trip exactly.            |
| `tu-save-03`     | `test_save_load_preserves_equipped`             | Equipped weapon+armor survives round-trip.                                   |
| `tu-save-04`     | `test_save_writes_to_user_dir`                  | Save path starts with `user://`. (Catches accidental project-dir saves.)    |
| `tu-save-05`     | `test_load_missing_save_returns_default`        | No save file → `load_game()` returns a fresh state, no crash.                |
| `tu-save-06`     | `test_save_does_not_persist_run_state`          | Per AC3: after death, run-XP / run-room may reset, but `level` + `stash` do not. |
| `tu-save-07`     | `test_save_format_is_valid_json`                | Saved file parses with `JSON.parse()`. Catches accidental binary writes.     |

#### `tests/integration/test_quit_relaunch_save.gd` — full quit→relaunch flow (AC6)

| ID            | Test                                                  | What it asserts                                                              |
|---------------|-------------------------------------------------------|------------------------------------------------------------------------------|
| `ti-save-01`  | `test_full_quit_relaunch_continues_state`             | Boot, set state, save, free scene tree, re-instantiate, load → state matches.|
| `ti-save-02`  | `test_save_on_stratum_exit_then_continue`             | Trigger stratum-exit save tick, simulate quit, reload → continues at expected point. |

### Phase B — player & combat (writes after Phase A; ~10 unit + 5 integration)

#### `tests/unit/test_player_movement.gd` — input → motion

| ID                | Test                                            | What it asserts                                                              |
|-------------------|-------------------------------------------------|------------------------------------------------------------------------------|
| `tu-player-01`    | `test_player_moves_right_on_d`                  | `move_right` action for one physics frame → x increased.                     |
| `tu-player-02`    | `test_player_moves_diagonally_on_w_d`           | Both axes increased; speed normalized (no faster diagonal).                  |
| `tu-player-03`    | `test_player_velocity_zero_on_no_input`         | No input → no motion.                                                        |
| `tu-player-04`    | `test_player_8_directions`                      | All 8 cardinal+diagonal inputs produce motion in expected direction.         |

#### `tests/unit/test_dodge.gd` — dodge-roll + i-frames

| ID                | Test                                            | What it asserts                                                              |
|-------------------|-------------------------------------------------|------------------------------------------------------------------------------|
| `tu-dodge-01`     | `test_dodge_grants_iframes_for_window`          | During dodge duration, `is_invulnerable() == true`.                          |
| `tu-dodge-02`     | `test_iframes_end_after_window`                 | Past dodge duration, `is_invulnerable() == false`.                           |
| `tu-dodge-03`     | `test_dodge_during_dodge_ignored_or_queued`     | Per Devon's decision: rapid double-dodge is either ignored or queued — assert the chosen behavior. |

#### `tests/unit/test_combat_math.gd` — damage calc

| ID                | Test                                            | What it asserts                                                              |
|-------------------|-------------------------------------------------|------------------------------------------------------------------------------|
| `tu-combat-01`    | `test_light_attack_damage_baseline`             | Base weapon, base stats → expected damage value.                             |
| `tu-combat-02`    | `test_heavy_attack_higher_than_light`           | Same weapon → heavy > light, by the design's ratio.                          |
| `tu-combat-03`    | `test_edge_affix_increases_crit_chance`         | Equipping `keen` affix raises crit rate by the expected delta.              |

#### `tests/unit/test_loot_roll.gd` — affix rolling

| ID                | Test                                            | What it asserts                                                              |
|-------------------|-------------------------------------------------|------------------------------------------------------------------------------|
| `tu-loot-01`     | `test_t1_drops_zero_affixes`                    | Per tech-stack tier table: T1 has 0 affixes.                                 |
| `tu-loot-02`     | `test_t2_drops_one_affix`                       | T2 always rolls exactly 1 affix.                                             |
| `tu-loot-03`     | `test_t3_drops_one_or_two_affixes`              | T3 rolls 1 or 2; verify both possible across N seeds.                        |
| `tu-loot-04`     | `test_affix_pool_distribution_over_N_rolls`     | Across 1000 seeded rolls: each of the 3 M1 affixes appears at least once. (AC7 backstop.) |
| `tu-loot-05`     | `test_loot_rolls_are_seeded`                    | Same seed → same roll. (Lets manual testing reproduce.)                      |

#### `tests/unit/test_levelup.gd` — XP & level-up math

| ID                | Test                                            | What it asserts                                                              |
|-------------------|-------------------------------------------------|------------------------------------------------------------------------------|
| `tu-levelup-01`  | `test_xp_threshold_curve_to_level_5`            | XP-to-next-level matches the design curve for levels 1→5.                    |
| `tu-levelup-02`  | `test_levelup_grants_one_stat_point`            | Each level gives exactly +1 stat point.                                      |
| `tu-levelup-03`  | `test_level_5_caps_in_m1`                       | Per `mvp-scope.md`: level 5 is the cap; XP overflow does not push to 6.      |

#### `tests/unit/test_mob_ai.gd` — grunt state machine

| ID                | Test                                            | What it asserts                                                              |
|-------------------|-------------------------------------------------|------------------------------------------------------------------------------|
| `tu-mob-01`       | `test_grunt_idle_to_chase_on_player_in_range`   | Grunt in idle, player enters detection radius → state = chase.               |
| `tu-mob-02`       | `test_grunt_chase_to_attack_on_melee_range`     | Chase → melee range → state = attack.                                         |
| `tu-mob-03`       | `test_grunt_dies_at_zero_hp`                    | HP set to 0 → next physics tick: state = dead, queue_free called.            |

#### `tests/integration/test_hit_on_grunt.gd` — combat loop end-to-end

| ID            | Test                                              | What it asserts                                                              |
|---------------|---------------------------------------------------|------------------------------------------------------------------------------|
| `ti-combat-01`| `test_light_attack_damages_grunt`                 | Spawn grunt + player adjacent. Trigger light attack. After hitbox lifetime: `grunt.hp` decreased by expected amount. |
| `ti-combat-02`| `test_grunt_drops_loot_on_death`                  | Kill grunt. At least one drop spawned per loot table (per week-1 #10).       |
| `ti-combat-03`| `test_dodge_iframes_prevent_grunt_damage`         | Player in dodge during grunt's attack hit-frame → no HP loss.                |

#### `tests/integration/test_inventory_equip.gd` — equip propagates to stats

| ID            | Test                                              | What it asserts                                                              |
|---------------|---------------------------------------------------|------------------------------------------------------------------------------|
| `ti-inv-01`   | `test_equip_weapon_changes_player_damage`         | Pre-equip damage X. Equip a weapon. Post-equip damage = X + weapon's contribution. |
| `ti-inv-02`   | `test_equip_hp_affix_changes_max_hp`              | Equip armor with `+12 max HP` affix → max HP increases by 12.                |

### Phase C — fills (writes if time allows; ~5 more unit + 3 integration)

| ID                  | What                                                   |
|---------------------|--------------------------------------------------------|
| `tu-stat-01`        | Vigor stat → +HP per point matches design.             |
| `tu-stat-02`        | Focus stat → +stamina/cooldown matches design.         |
| `tu-stat-03`        | Edge stat → +damage matches design.                    |
| `tu-room-01`        | Stratum-1 chunk assembly produces 8 rooms (counts).    |
| `tu-room-02`        | Boss room is always last in the room order.            |
| `ti-stratum-01`     | Walking through all 8 rooms without combat does not crash. |
| `ti-deathrestart-01`| Player HP→0 → death screen → restart → fresh stratum-1 spawn, level/stash preserved. |
| `ti-bossfight-01`   | Headless boss fight: player dummy with infinite HP DPS-checks the boss to a clean death. (Validates boss death handling.) |

### Inventory totals

| Phase  | Unit | Integration |
|--------|------|-------------|
| A      | 9    | 2           |
| B      | 16   | 5           |
| C (fill)| 5   | 3           |
| **Total**| **30** | **10**  |

Lands inside the 20–30 unit and 10–15 integration `TESTING_BAR.md` window.

## What automation does NOT cover (manual only)

- **Combat balance / DPS curves** → manual `m1-test-plan.md` AC4.
- **Browser HTML5-specific** runtime issues → manual environment matrix in `test-environments.md`.
- **UI layouts / Uma's mockups** → GUT can't see pixels meaningfully. Visual regression manual.
- **Save file backwards compatibility across schema versions** → post-M1 concern.
- **Player feel** → manual soak sessions.

## CI gate

GitHub Actions workflow (Devon owns) runs `gut_cmdln.gd` and **fails the build** on any test failure. No PR merges to `main` without green CI. Per `TESTING_BAR.md`: a flaky test is fixed or quarantined within 24 hours of first flake.

## Maintenance discipline

- One test file per system. No 500-line god-test files.
- Every test names a single behavior. If the test name needs "and", split it.
- A failing test gets fixed before any new feature lands. Tess pings the owning role and pauses other QA work to triage.
- Flaky tests are removed within 24 hours of the first flake. Flakiness in the test layer is poison.

## Tess execution order

When the prerequisites land:

1. Phase A (~9 unit + 2 integration) — single tick of focused authoring.
2. Verify CI runs green.
3. Phase B (~16 unit + 5 integration) — across 2–3 ticks as the underlying features land.
4. Phase C as time permits before M1 sign-off.
5. Update this doc per test as `landed` (commit shows in `tests/`).
