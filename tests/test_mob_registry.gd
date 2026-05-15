extends GutTest
## Tests for MobRegistry autoload — paired with W3-T5
## (`feat(content): MobRegistry autoload — stratum-aware mob lookup +
## scaling`) which authors `scripts/content/MobRegistry.gd` and refactors
## `MultiMobRoom._spawn_mob` from a match-block to registry-driven dispatch.
##
## **Scaffold-only**: This file ships with `pending()` stubs that compile so
## CI's GUT step doesn't trip on parse errors. Tess fills in each test with
## real assertions when Devon's W3-T5 PR lands. Mirrors the W1-T12 / W2-T10
## parallel-acceptance pattern.
##
## See `team/tess-qa/m2-acceptance-plan-week-3.md` § W3-T5 for the
## acceptance criteria this file pins (W3-T5-AC1..AC5).
##
## NOTE — quick check at dispatch time per Priya §W3-T5 risk note: if M2 W1
## T6's Stoker PR folded MobRegistry already (vs. continued match-block
## dispatch), W3-T5 may retire and these stubs need re-pointing at the
## actual surface. Tess re-evaluates when W3-T5 dispatch lands.


# ---- W3-T5-AC1 — Autoload registers ----------------------------------

func test_mob_registry_autoload_registered() -> void:
	pending("awaiting W3-T5 — Engine.get_main_loop().root.get_node('/root/MobRegistry') resolves")


func test_mob_registry_autoload_no_errors_on_boot() -> void:
	pending("awaiting W3-T5 — project loads cleanly with the new autoload entry in project.godot")


# ---- W3-T5-AC2 — Round-trip: register + retrieve ---------------------
##
## All M1 + M2 mobs register at autoload boot. The registry maps
## `mob_id: StringName → MobDef + MobScene`.

func test_get_mob_def_returns_grunt_def_for_grunt_id() -> void:
	pending("awaiting W3-T5 — MobRegistry.get_mob_def(&\"grunt\") returns Grunt MobDef")


func test_get_mob_def_returns_charger_def_for_charger_id() -> void:
	pending("awaiting W3-T5 — MobRegistry.get_mob_def(&\"charger\") returns Charger MobDef")


func test_get_mob_def_returns_shooter_def_for_shooter_id() -> void:
	pending("awaiting W3-T5 — MobRegistry.get_mob_def(&\"shooter\") returns Shooter MobDef")


func test_get_mob_def_returns_stoker_def_for_stoker_id() -> void:
	pending("awaiting W3-T5 — MobRegistry.get_mob_def(&\"stoker\") returns Stoker MobDef")


func test_get_mob_scene_returns_correct_packed_scene() -> void:
	pending("awaiting W3-T5 — MobRegistry.get_mob_scene(&\"grunt\") returns Grunt PackedScene")


func test_get_mob_def_returns_null_for_unknown_id_no_crash() -> void:
	pending("awaiting W3-T5 — MobRegistry.get_mob_def(&\"unknown_mob\") returns null without panic")


# ---- W3-T5-AC3 — Stratum-scaling math correct ------------------------
##
## S1 baseline: HP × 1.0 / dmg × 1.0.
## S2 scaling: HP × 1.2 / dmg × 1.15 (per mvp-scope.md §M2).

func test_apply_stratum_scaling_s1_returns_baseline_values() -> void:
	pending("awaiting W3-T5 — apply_stratum_scaling(grunt_def, &\"s1\") returns HP × 1.0 / dmg × 1.0")


func test_apply_stratum_scaling_s2_returns_scaled_hp_1_2x() -> void:
	pending("awaiting W3-T5 — apply_stratum_scaling(grunt_def, &\"s2\") returns HP × 1.2")


func test_apply_stratum_scaling_s2_returns_scaled_damage_1_15x() -> void:
	pending("awaiting W3-T5 — apply_stratum_scaling(grunt_def, &\"s2\") returns dmg × 1.15")


# ---- W3-T5-AC4 — Scaling-doesn't-mutate-source invariant ------------

func test_apply_stratum_scaling_returns_new_instance_not_source() -> void:
	pending("awaiting W3-T5 — apply_stratum_scaling result is NEW MobDef; source unmutated")


func test_apply_stratum_scaling_twice_does_not_compound() -> void:
	## EP-DUP edge probe from W3 acceptance plan §W3-T5.
	## Calling apply_stratum_scaling(def, &"s2") twice returns a new def
	## with the SAME values (1.2x, not 1.2 × 1.2 = 1.44x — that's a bug).
	pending("awaiting W3-T5 — second apply_stratum_scaling call doesn't compound HP/dmg multipliers")


# ---- W3-T5-AC5 — Refactor regression (MultiMobRoom._spawn_mob) -----
##
## The MultiMobRoom refactor (match-block → registry-driven dispatch)
## must not regress any M1 + M2 mob-spawn integration test. These two
## tests are smoke-coverage that the refactor is correct; the real
## regression coverage runs in test_stratum1_rooms.gd and
## test_stratum2_rooms_v2.gd (full pass post-refactor).

func test_multi_mob_room_spawn_via_registry_returns_correct_mob_type() -> void:
	pending("awaiting W3-T5 — MultiMobRoom.spawn(&\"grunt\", Vector2.ZERO, room) returns a Grunt instance")


func test_multi_mob_room_spawn_handles_unknown_id_gracefully() -> void:
	pending("awaiting W3-T5 — MultiMobRoom.spawn(&\"unknown\", ...) push_warnings + returns null (no crash)")


# ---- EP-OOO — autoload-order independence ---------------------------

func test_get_mob_def_before_ready_returns_correct_def() -> void:
	## EP-OOO edge probe — module-scope constants make autoload-order
	## irrelevant. This is a defensive assertion that get_mob_def works
	## before MobRegistry._ready completes (e.g., if another autoload's
	## _ready calls into the registry).
	pending("awaiting W3-T5 — get_mob_def is autoload-order-independent (module-scope dict)")
