extends GutTest
## Pin: MobRegistry registers `&"sunken_scholar"` per W3-T7 Stage 2
## (ticket `86c9y7ygj`). Mirrors `tests/test_mob_registry.gd` AC2 shape for
## the new S2 ranged mob.
##
## Why a separate file (not append to test_mob_registry.gd):
##   - Stage 3 (Bone-Catalyst) + Stage 5 (Archive Sentinel) each register
##     into the same _REGISTRATIONS. Keeping per-mob pins as separate test
##     files makes the "did this stage register cleanly?" CI signal scoped —
##     bisects failures faster than one large file.
##   - The roster-swap audit gate (`orchestration-overview.md`) explicitly
##     wants per-mob trace assertions; separate pin files map 1:1.

const _MobDef: Script = preload("res://scripts/content/MobDef.gd")
const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

# ---- Universal-warning gate ------------------------------------------

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- Helpers ----------------------------------------------------------


func _registry() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("MobRegistry")


# ---- 1: has_mob + get_mob_def round-trip ------------------------------


func test_has_mob_returns_true_for_sunken_scholar_id() -> void:
	var reg: Node = _registry()
	assert_true(reg.has_mob(&"sunken_scholar"), "sunken_scholar registered")


func test_get_mob_def_returns_sunken_scholar_def_for_sunken_scholar_id() -> void:
	var reg: Node = _registry()
	var def: MobDef = reg.get_mob_def(&"sunken_scholar")
	assert_not_null(def, "sunken_scholar MobDef must resolve")
	assert_eq(def.id, &"sunken_scholar", "MobDef carries correct id")


# ---- 2: MobDef field pins (drift-detector for runtime tunables) -------


func test_sunken_scholar_def_carries_expected_fields() -> void:
	var reg: Node = _registry()
	var def: MobDef = reg.get_mob_def(&"sunken_scholar")
	assert_not_null(def)
	# Stage-2 ship balance — see SunkenScholar.gd runtime declarations for
	# rationale. Field drift surfaces here before runtime divergence bites.
	assert_eq(def.display_name, "Sunken Scholar")
	assert_eq(def.hp_base, 50)
	assert_eq(def.damage_base, 6)
	assert_almost_eq(def.move_speed, 60.0, 0.001)
	assert_eq(def.ai_behavior_tag, &"ranged_kiter")
	assert_eq(def.xp_reward, 18)


# ---- 3: scene resolves ------------------------------------------------


func test_get_mob_scene_returns_sunken_scholar_scene_for_sunken_scholar_id() -> void:
	var reg: Node = _registry()
	var scene: PackedScene = reg.get_mob_scene(&"sunken_scholar")
	assert_not_null(scene, "SunkenScholar PackedScene must resolve")


# ---- 4: registered_ids enumeration includes sunken_scholar -----------


func test_registered_ids_includes_sunken_scholar() -> void:
	var reg: Node = _registry()
	var ids: Array = reg.registered_ids()
	assert_true(
		ids.has(&"sunken_scholar"),
		"registered_ids() enumeration must include sunken_scholar"
	)


# ---- 5: spawn() unified entry-point smoke ----------------------------


func test_spawn_sunken_scholar_returns_node_with_mob_def_applied() -> void:
	var reg: Node = _registry()
	var room: Node = autofree(Node.new())
	add_child(room)
	var node: Node = reg.spawn(&"sunken_scholar", Vector2(100.0, 50.0), room)
	assert_not_null(node, "spawn returns a SunkenScholar node")
	assert_eq(node.name, "SunkenScholar", "scene root name preserved")
	assert_true(node is SunkenScholar, "scene resolves to the SunkenScholar script class")
	# MobDef applied so kill → mob_died → loot/XP pipelines see non-null payload.
	assert_not_null(node.mob_def, "MobDef applied at spawn")
	assert_eq(node.mob_def.id, &"sunken_scholar")
	# Position applied.
	assert_almost_eq((node as Node2D).position.x, 100.0, 0.001)
	assert_almost_eq((node as Node2D).position.y, 50.0, 0.001)


# ---- 6: stratum-scaling math against sunken_scholar def --------------


func test_apply_stratum_scaling_s2_multiplies_sunken_scholar_correctly() -> void:
	# S2 baseline: hp ×1.2, damage ×1.15 per palette-stratum-2.md +
	# `MobRegistry._STRATUM_SCALING`. Pinned here as a smoke that the registry
	# scaling path applies cleanly to the new mob def — not just grunt/charger.
	var reg: Node = _registry()
	var def: MobDef = reg.get_mob_def(&"sunken_scholar")
	var scaled: MobDef = reg.apply_stratum_scaling(def, &"s2")
	assert_not_null(scaled)
	# Scaled values: 50 * 1.2 = 60.0 → roundi=60; 6 * 1.15 = 6.9 → roundi=7.
	assert_eq(scaled.hp_base, 60, "S2 HP scaling: 50 × 1.2 = 60")
	assert_eq(scaled.damage_base, 7, "S2 dmg scaling: 6 × 1.15 = 6.9 → 7 (roundi)")
	# Source NOT mutated (scaling-doesn't-mutate-source invariant).
	assert_eq(def.hp_base, 50, "source mob_def unchanged")
	assert_eq(def.damage_base, 6, "source mob_def unchanged")
