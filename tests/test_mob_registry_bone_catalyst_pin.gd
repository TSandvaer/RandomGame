extends GutTest
## Pin: MobRegistry registers `&"bone_catalyst"` per W3-T7 Stage 3
## (ticket `86c9y7ygj`). Mirrors `tests/test_mob_registry_sunken_scholar_pin.gd`
## shape for the new S2 melee mob.
##
## Why a separate file (not append to test_mob_registry.gd or the
## sunken_scholar pin file):
##   - Stage 5 (Archive Sentinel boss) will register into the same
##     _REGISTRATIONS. Keeping per-mob pins as separate test files makes the
##     "did this stage register cleanly?" CI signal scoped — bisects failures
##     faster than one large file.
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


func test_has_mob_returns_true_for_bone_catalyst_id() -> void:
	var reg: Node = _registry()
	assert_true(reg.has_mob(&"bone_catalyst"), "bone_catalyst registered")


func test_get_mob_def_returns_bone_catalyst_def_for_bone_catalyst_id() -> void:
	var reg: Node = _registry()
	var def: MobDef = reg.get_mob_def(&"bone_catalyst")
	assert_not_null(def, "bone_catalyst MobDef must resolve")
	assert_eq(def.id, &"bone_catalyst", "MobDef carries correct id")


# ---- 2: MobDef field pins (drift-detector for runtime tunables) -------


func test_bone_catalyst_def_carries_expected_fields() -> void:
	var reg: Node = _registry()
	var def: MobDef = reg.get_mob_def(&"bone_catalyst")
	assert_not_null(def)
	# Stage-3 ship balance — see BoneCatalyst.gd runtime declarations for
	# rationale. Field drift surfaces here before runtime divergence bites.
	assert_eq(def.display_name, "Bone Catalyst")
	assert_eq(def.hp_base, 70)
	assert_eq(def.damage_base, 5)
	assert_almost_eq(def.move_speed, 50.0, 0.001)
	assert_eq(def.ai_behavior_tag, &"melee_bruiser")
	assert_eq(def.xp_reward, 22)


# ---- 3: scene resolves ------------------------------------------------


func test_get_mob_scene_returns_bone_catalyst_scene_for_bone_catalyst_id() -> void:
	var reg: Node = _registry()
	var scene: PackedScene = reg.get_mob_scene(&"bone_catalyst")
	assert_not_null(scene, "BoneCatalyst PackedScene must resolve")


# ---- 4: registered_ids enumeration includes bone_catalyst ------------


func test_registered_ids_includes_bone_catalyst() -> void:
	var reg: Node = _registry()
	var ids: Array = reg.registered_ids()
	assert_true(
		ids.has(&"bone_catalyst"),
		"registered_ids() enumeration must include bone_catalyst"
	)


# ---- 5: spawn() unified entry-point smoke ----------------------------


func test_spawn_bone_catalyst_returns_node_with_mob_def_applied() -> void:
	var reg: Node = _registry()
	var room: Node = autofree(Node.new())
	add_child(room)
	var node: Node = reg.spawn(&"bone_catalyst", Vector2(200.0, 60.0), room)
	assert_not_null(node, "spawn returns a BoneCatalyst node")
	assert_eq(node.name, "BoneCatalyst", "scene root name preserved")
	assert_true(node is BoneCatalyst, "scene resolves to the BoneCatalyst script class")
	# MobDef applied so kill → mob_died → loot/XP pipelines see non-null payload.
	assert_not_null(node.mob_def, "MobDef applied at spawn")
	assert_eq(node.mob_def.id, &"bone_catalyst")
	# Position applied.
	assert_almost_eq((node as Node2D).position.x, 200.0, 0.001)
	assert_almost_eq((node as Node2D).position.y, 60.0, 0.001)


# ---- 6: stratum-scaling math against bone_catalyst def --------------


func test_apply_stratum_scaling_s2_multiplies_bone_catalyst_correctly() -> void:
	# S2 baseline: hp ×1.2, damage ×1.15 per palette-stratum-2.md +
	# `MobRegistry._STRATUM_SCALING`. Pinned here as a smoke that the registry
	# scaling path applies cleanly to the new mob def — not just grunt/charger/
	# sunken_scholar.
	var reg: Node = _registry()
	var def: MobDef = reg.get_mob_def(&"bone_catalyst")
	var scaled: MobDef = reg.apply_stratum_scaling(def, &"s2")
	assert_not_null(scaled)
	# Scaled values: 70 * 1.2 = 84 → roundi=84; 5 * 1.15 = 5.75 → roundi=6.
	assert_eq(scaled.hp_base, 84, "S2 HP scaling: 70 × 1.2 = 84")
	assert_eq(scaled.damage_base, 6, "S2 dmg scaling: 5 × 1.15 = 5.75 → 6 (roundi)")
	# Source NOT mutated (scaling-doesn't-mutate-source invariant).
	assert_eq(def.hp_base, 70, "source mob_def unchanged")
	assert_eq(def.damage_base, 5, "source mob_def unchanged")
