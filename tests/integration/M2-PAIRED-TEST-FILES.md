# M2 Week-1 Paired Test Files — index

**Owner:** Tess (QA) · **Phase:** anticipatory (drafted before M2 implementation begins) · **Drives:** Tess's parallel acceptance scaffold per Priya's `team/priya-pl/m2-week-1-backlog.md` T12 + the testing-bar paired-test rule.

This file is a **planning index, not test code.** Each row below describes the paired GUT test file Tess will author once the corresponding T-ticket lands a PR. **Tess writes these files only after the production code under test exists** — nothing here authors tests against vapor; the implementation lands first, then the paired test file lands as a sign-off gate (per W3-A3 / W3-A5 idiom).

5 paired test files for M2 week-1. Each row: file path · purpose · T-tickets covered · approximate test-method count + key assertions · authoring trigger.

---

## File 1 — `tests/test_save_migration_v3_to_v4.gd`

- **Purpose:** Pin INV-1..INV-8 round-trip invariants from `team/devon-dev/save-schema-v4-plan.md §5`. Drive the six fixtures from `tests/fixtures/m2-week-1-fixtures.md` through the migration chain. Assert M1 contract holds (no v3 field drift on the v4 bump).
- **Covers:** **T1** (`feat(save): v3→v4 migration impl`) + **T2** (`feat(save): SaveSchema.gd autoload`).
- **Test-method count:** **~14–18 tests** (8 INV-N pinning tests + 4–6 fixture-specific edge tests + ~2–4 SaveSchema tests).
- **Key assertions:**
  - `test_inv1_v3_save_loads_clean_under_v4_runtime` — load `save_v3_baseline.json`; assert non-empty Dictionary; `character` block intact.
  - `test_inv2_v3_to_v4_backfills_empty_stash` — post-load, `loaded["character"]["stash"]` is Array, `size() == 0`.
  - `test_inv3_v3_to_v4_backfills_empty_ember_bags` — post-load, `loaded["character"]["ember_bags"]` is Dictionary, `is_empty() == true`.
  - `test_inv4_v3_to_v4_backfills_stash_ui_state_with_room_unseen` — `loaded["character"]["stash_ui_state"]["stash_room_seen"] == false`.
  - `test_inv5_v3_field_preservation` — every v3 field bit-identical post-migration (uses `save_v3_baseline.json` + `save_v3_full_inventory.json` + `save_v3_max_level.json`).
  - `test_inv6_v0_to_v4_chain_through_full_history` — v0 fixture migrates v0→v1→v2→v3→v4; ends at same level/xp/V/F/E as direct-v4 baseline.
  - `test_inv7_v3_to_v4_idempotent_on_already_v4` — load `save_v4_baseline.json`; save; load; save; load — bit-identical, schema_version stays 4.
  - `test_inv8_v4_envelope_schema_version_on_disk` — after `save_game`, on-disk envelope `schema_version == 4`.
  - `test_partial_corruption_no_crash` — load `save_v3_partial_corruption.json` (missing `unspent_stat_points`); migration completes without error; v4 fields backfilled; v3 `stats` block preserved.
  - `test_save_schema_default_value_for_known_path` — `SaveSchema.default_value("character.level")` returns `1`; `default_value("character.stash_ui_state.stash_room_seen")` returns `false`.
  - `test_save_schema_default_value_for_unknown_path` — `default_value("nonsense.path")` returns `null`.
  - `test_save_schema_is_canonical` — `is_canonical("character.level")` is `true`; `is_canonical("nonsense")` is `false`.
- **Authoring trigger:** when T1 PR lands `Save.SCHEMA_VERSION = 4` + `_migrate_v3_to_v4` impl, AND T2 PR lands `SaveSchema.gd` autoload. The two T-tickets are likely on a single branch / sibling PRs per Priya's backlog.
- **Owner:** Tess writes; existing `tests/test_save_migration.gd` is the sibling pattern (idiom-match).

---

## File 2 — `tests/test_stash_panel.gd`

- **Purpose:** Pin ST-04..ST-10 hooks from `team/uma-ux/stash-ui-v1.md §6`. Cover the 12×6 grid rendering + Tab+B coexistence + `Engine.time_scale` invariant + LMB swap-pool + drag-and-drop + discard semantics.
- **Covers:** **T3** (`feat(ui): stash UI implementation`).
- **Test-method count:** **~10–14 tests.**
- **Key assertions:**
  - `test_stash_grid_is_exactly_72_cells` — load StashPanel.tscn; cell count = 72; arrangement is 12 cols × 6 rows.
  - `test_stash_grid_uses_inventory_cell_scene` — verify cells are `InventoryCell.tscn` instances (no fork).
  - `test_b_key_opens_stash_in_stash_room` — sim `Levels.entered_stash_room`; press B; panel `_open == true`. ST-03.
  - `test_b_key_does_nothing_outside_stash_room` — `Levels.in_stash_room == false`; press B; panel `_open == false`. ST-03.
  - `test_tab_and_b_coexist_in_stash_room` — press B; press Tab; both inventory + stash panels `_open == true`. ST-05.
  - `test_engine_time_scale_holds_at_1_in_stash_room` — open + close stash + inventory in stash room; assert `Engine.time_scale == 1.0` throughout. ST-06.
  - `test_lmb_inventory_cell_with_stash_open_moves_to_first_empty_stash` — populate inventory; open stash; LMB inv cell; item moves to `character.stash[0]`. ST-07.
  - `test_lmb_stash_cell_with_inventory_open_moves_to_first_empty_inventory` — populate stash; open inventory; LMB stash cell; item moves to first empty inventory cell. ST-08.
  - `test_drag_from_stash_to_equipped_slot_equips_directly` — drag stash[0] sword onto weapon slot; equipped slot populated; stash[0] empty; inventory not touched. ST-09.
  - `test_t1_discard_immediate_with_undo` — T1 stash item; discard input; item removed; undo toast surfaces. ST-10.
  - `test_t2_plus_discard_prompts_confirm` — T2 stash item; discard input; confirm prompt surfaces. ST-10.
  - `test_stash_panel_exit_tree_does_not_corrupt_time_scale` — TI-14 from M2 acceptance plan §"M2 RC build verification"; mirror of TI-6 / TI-7 idiom from W3-A5 audit.
- **Authoring trigger:** when T3 PR lands `scenes/ui/StashPanel.tscn` + `scripts/ui/StashPanel.gd` + Inventory autoload extensions.
- **Owner:** Tess writes; existing `tests/test_inventory_panel.gd` is the sibling pattern.

---

## File 3 — `tests/integration/test_stratum_2_room01.gd`

- **Purpose:** Pin S2-PL-15 (subjective transition reads as new) via integration scene-load + S2 R1 specific assertions. Mirror `test_stratum1_rooms.gd`'s 17-test pattern, scaled to first-room S2 surface. Stratum namespace conformance (Drew's W3-B2 `Stratum` namespace + `MultiMobRoom` rename).
- **Covers:** **T5** (`feat(level): stratum-2 first room (s2_room01)`). Smoke-references **T4** sprites (room won't render correctly without them; Drew's hex-block-fallback is the partial-pass path per Priya's R3 mitigation).
- **Test-method count:** **~10–14 tests.**
- **Key assertions:**
  - `test_s2_room01_chunk_def_loads` — `resources/level_chunks/s2_room01.tres` loads as `LevelChunkDef`; `chunk_id == "s2_room01"`.
  - `test_s2_room01_scene_instantiates` — `scenes/levels/Stratum2Room01.tscn` instantiates without error.
  - `test_s2_room01_uses_multi_mob_room` — root node is `MultiMobRoom` (renamed in W3-B2 scaffold), not a re-rolled type.
  - `test_s2_room01_assemble_via_level_assembler` — `LevelAssembler.assemble_single` builds the assembly without error.
  - `test_s2_grunt_spawns_inside_chunk_bounds` — instantiate room; sim spawn ticks; spawned mob position is inside room rect. (Mirrors `test_stratum1_rooms.gd::test_grunt_spawn_inside_room`.)
  - `test_s2_room01_uses_stratum_namespace` — assert `Stratum.STRATUM_2` (or whatever the namespace constant is) is referenced; folder layout uses `resources/mobs/s2/`.
  - `test_s2_room01_canvas_layer_ambient_overlay` — assert `CanvasLayer` + `ColorRect` ambient overlay present with multiply blend; modulate alpha ≈ 0.08; color ≈ `#FF5A1A`.
  - `test_s2_room01_vignette_deepens_to_40pct` — assert vignette `ColorRect` color ≈ `#0A0404` and alpha ≈ 0.40.
  - `test_s2_room01_no_light2d_used` — assert `Light2D` count in scene == 0 (palette-stratum-2.md §4 contract: vein pulse via sprite anim, not Light2D).
  - `test_s1_to_s2_descent_lands_in_s2_room01` — sim S1 descent portal trigger; player ends inside `Stratum2Room01.tscn` bounds.
  - `test_s2_room01_save_load_round_trip` — clear room mid-state; save; quit; load; room state restored.
- **Authoring trigger:** when T5 PR lands `Stratum2Room01.tscn` + `s2_room01.tres`. T4 sprites can be hex-block placeholders for the initial test pass; full sprite verification awaits T4 closure.
- **Owner:** Tess writes; existing `tests/test_stratum1_rooms.gd` is the canonical pattern (17 tests).

---

## File 4 — `tests/test_stoker_mob.gd`

- **Purpose:** Pin Stoker state machine + damage pipeline + drop pipeline. Mirror `test_grunt.gd` / `test_shooter.gd` patterns. Cover the 5 state transitions (idle→aggro / aggro→telegraph / telegraph→attack / attack→cooldown / hit→die).
- **Covers:** **T6** (`feat(mobs): stratum-2 mob v1 — Stoker`).
- **Test-method count:** **~14–18 tests.**
- **Key assertions:**
  - `test_stoker_loads_from_tres` — `resources/mobs/s2/stoker.tres` loads cleanly.
  - `test_stoker_scene_instantiates` — `scenes/mobs/Stoker.tscn` instantiates; root script is `Stoker.gd`.
  - `test_stoker_starts_idle` — fresh Stoker is in `IDLE` state.
  - `test_stoker_idle_to_aggro_on_player_in_range` — sim player approach within aggro radius; state transitions to `AGGRO`.
  - `test_stoker_aggro_to_telegraph_starts_windup` — in `AGGRO` with player in attack range, transitions to `TELEGRAPH`; `telegraph_started_at` timestamp set.
  - `test_stoker_telegraph_lasts_1_second` — sim 1.0 s; transitions to `ATTACK`. (Telegraph wind-up = 1.0 s per Priya's backlog T6 scope.)
  - `test_stoker_attack_lasts_2_seconds` — in `ATTACK`, sim 2.0 s; transitions to `COOLDOWN`.
  - `test_stoker_cooldown_lasts_1_5_seconds` — in `COOLDOWN`, sim 1.5 s; transitions back to `AGGRO` (or `IDLE` if player out of range).
  - `test_stoker_cone_fire_breath_damages_player_in_cone` — in `ATTACK` state, player inside cone geometry takes contact + DoT damage.
  - `test_stoker_cone_fire_breath_does_not_damage_player_outside_cone` — player outside cone takes 0 damage.
  - `test_stoker_dies_on_lethal_hit` — apply lethal damage; state transitions to `DIE`; mob_died signal fires.
  - `test_stoker_drops_loot_on_death` — kill Stoker; LootRoller fires; ≥0 loot drops conform to S2 mob drop tables.
  - `test_stoker_telegraph_canceled_on_hit_during_windup` (or `_committed_on_hit_during_windup`) — pin Drew's design call; one or the other but not undefined.
  - `test_stoker_dies_mid_attack_no_orphan_hitbox` — kill mid-`ATTACK`; cone fire breath particle/anim aborts cleanly; no orphan damage hitbox.
  - `test_stoker_state_after_save_load_round_trip` — Stoker state survives save/load via existing mob-snapshot pattern.
- **Authoring trigger:** when T6 PR lands `scripts/mobs/Stoker.gd` + `scenes/mobs/Stoker.tscn` + `resources/mobs/s2/stoker.tres`.
- **Owner:** Tess writes; existing `tests/test_grunt.gd` + `tests/test_shooter.gd` are the canonical patterns. **Stoker is the third archetype in the family**, so the test idiom is well-established.

---

## File 5 — `tests/integration/test_ember_bag_pickup.gd`

- **Purpose:** Pin ST-11..ST-25 hooks (the ember-bag + death-recovery contract) from `team/uma-ux/stash-ui-v1.md §6`. Atomic-save-before-summary, the six edge cases from §2, recovery flow, run-summary EMBER BAG section render.
- **Covers:** **T7** (`feat(progression): ember-bag pickup-at-death-location impl`) + **T8** (`feat(ui): death-recovery flow screens`).
- **Test-method count:** **~16–20 tests.**
- **Key assertions:**
  - `test_ember_bag_packs_unequipped_inventory_on_death` — die with N unequipped items; bag created with all N items at death tile. ST-11.
  - `test_equipped_items_never_in_ember_bag` — die with equipped weapon + armor + N inventory items; bag has N items, equipped persist on character. ST-12.
  - `test_atomic_save_fires_before_run_summary` — sim death; assert `Save.save_game()` called synchronously before run-summary screen displays. **Regression gate** — save-schema-v4-plan.md §7.3.
  - `test_dead_in_nonexistent_room_falls_back_to_stash_room` — die in procedural room; next run, room doesn't exist; bag spawns in stratum-entry stash room. ST-23.
  - `test_dead_in_boss_room_spawns_at_boss_arena_entry` — die in boss room; bag spawns at boss-arena entry, not on boss arena. ST-24.
  - `test_same_tile_second_death_replaces_first_bag` — die at tile T; die at tile T again before recovery; second bag replaces first; first bag's items lost. ST-20.
  - `test_recovery_overflows_to_stash_when_inventory_full` — recover bag with full inventory; items overflow to stash. ST-18.
  - `test_recovery_partial_when_stash_also_full` — recover bag with full inventory + full stash; bag stays in-world; partial recovery. ST-19.
  - `test_bag_with_deleted_item_id_drops_with_warning` — bag has item id no longer in TRES; load triggers `push_warning`; bag survives without that entry; character not nuked.
  - `test_cross_stratum_bags_independent` — bag pending in S1; die in S2; both bags exist; cap = 8. ST-21.
  - `test_recovery_audio_and_toast_fire` — walk over bag; audio cue plays; toast `Ember Bag recovered · N items returned` surfaces. ST-17.
  - `test_summary_screen_shows_ember_bag_section_when_items_packed` — die with items; run-summary has EMBER BAG section. ST-13.
  - `test_summary_screen_omits_ember_bag_section_when_empty` — die with no unequipped items; section omitted entirely. ST-14.
  - `test_stratum_entry_banner_displays_when_bag_pending` — re-enter stratum with pending bag; banner slides in for 2 s. ST-15.
  - `test_hud_pip_pulses_in_bag_stratum` — pip displays at 50% opacity; in-stratum 1 s cycle; in-room 0.5 s cycle with `#FFB066` color shift. ST-16.
  - `test_m1_contract_holds_with_bag_present` — die with bag; level + xp + equipped persist. ST-25.
  - `test_bag_save_load_round_trip` — die with bag; save; quit; load; bag survives. ST-22.
  - `test_recovery_save_load_round_trip` — recover bag; save; quit; load; items in inventory; bag entity gone.
- **Authoring trigger:** when T7 PR lands `scenes/objects/EmberBag.tscn` + StratumProgression extensions + `pack_bag_on_death`/`recover_bag` methods, AND T8 PR lands run-summary EMBER BAG section + stratum-entry banner + HUD pip. Likely sibling PRs.
- **Owner:** Tess writes; existing `tests/integration/test_ac3_combat_loop.gd` is the closest sibling pattern (combat-loop integration).

---

## Authoring order + parallelism

When M2 dispatch begins, paired test files land in this rough order (driven by which T-ticket lands first):

1. **File 1** (T1 + T2) — first to land, since T1 is the gate for everything else.
2. **File 3** (T5) — independent of save chain; lands when T4+T5 are green.
3. **File 4** (T6) — independent of save chain + content chain; lands when T6 is green.
4. **File 2** (T3) — gates on T1+T2 (schema needs `character.stash`); lands when T3 ships.
5. **File 5** (T7+T8) — last; gates on T1+T2+T3+T9; the most integration-heavy file.

T9 (stash room scene) is covered as cross-references inside File 2 + File 5 (signal contract + first-visit gate are smaller surfaces folded into the larger files); a dedicated `tests/test_stash_room.gd` is **not** in the index — Tess can split if File 2 grows too large at impl time.

T11 (M2 RC build pipeline) extends `tests/integration/test_html5_invariants.gd` with TI-10..TI-15 per the M2 acceptance plan §"M2 RC build verification" — those are extensions to an EXISTING file, not new file authoring. Same for any audit-doc deliverable (`html5-rc-audit-m2-rc1.md`).

---

## Hand-off

- **Tess (M2 week-1 dispatch):** author each file above when its trigger fires. Each file lands as a PR alongside or immediately after the implementation PR it pairs with. Per testing-bar §Tess, `ready for qa test` → `complete` flips on (a) implementation PR's CI green + (b) paired test PR's CI green + (c) edge probes documented + (d) optional 5-min freeplay clean.
- **Devon / Drew / Uma:** surface PR opens at `ready for qa test` is the trigger. PR body documents which T-AC rows the impl pins (cross-ref to `team/tess-qa/m2-acceptance-plan-week-1.md`).
- **Priya:** monitors capacity guardrails. R2 (Tess bottleneck) mitigation = this index (paired-test plans pre-authored, sign-off becomes "PR's tests pass + no edge regression"). R8 (stash UI complexity) mitigation = File 2's split-into-smaller-files option.
