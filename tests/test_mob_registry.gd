extends GutTest
## Tests for MobRegistry autoload — paired with W3-T5
## (`feat(content): MobRegistry autoload — stratum-aware mob lookup +
## scaling`, ticket #86c9ue1up) which authors `scripts/content/MobRegistry.gd`
## and refactors `MultiMobRoom._spawn_mob` from a match-block to
## registry-driven dispatch.
##
## Acceptance criteria from `team/tess-qa/m2-acceptance-plan-week-3.md` §W3-T5:
##   AC1 — Autoload registers.
##   AC2 — Round-trip register + retrieve (grunt/charger/shooter/unknown).
##   AC3 — Stratum-scaling math: S1 baseline; S2 +20% HP / +15% dmg.
##   AC4 — Scaling-doesn't-mutate-source invariant.
##   AC5 — MultiMobRoom refactor regression (covered separately in
##         `tests/test_stratum1_rooms.gd` + `tests/test_stratum2_rooms.gd`;
##         smoke-coverage here via the registry-direct spawn test).
## Edge probes:
##   EP-OOO — autoload-order independence.
##   EP-DUP — apply_stratum_scaling twice does not compound.
##
## Stoker (mob_id `&"stoker"`) is NOT yet shipped — the stub
## `test_get_mob_def_returns_stoker_def_for_stoker_id` stays `pending()`
## until the W3-T3/T4 Stoker scene + TRES land and the registry is extended
## to register them.

const _MobDef: Script = preload("res://scripts/content/MobDef.gd")
const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")


# ---- Universal-warning gate (ticket 86c9uf0mm Half B) ----------------
##
## Every test in this file gets a NoWarningGuard attached in before_each.
## Tests that DELIBERATELY exercise a `push_warning` path (unknown id,
## unknown stratum, null mob_def) must call `_warn_guard.expect_warning(
## pattern)` BEFORE the path is exercised so the guard's `assert_clean`
## in after_each doesn't flag it as a violation.

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


# ---- W3-T5-AC1 — Autoload registers ----------------------------------

func test_mob_registry_autoload_registered() -> void:
	var reg: Node = _registry()
	assert_not_null(reg, "MobRegistry autoload must be registered at /root/MobRegistry")


func test_mob_registry_autoload_no_errors_on_boot() -> void:
	# If `project.godot`'s autoload entry pointed at a script with a parse
	# error, the autoload would either fail to instantiate or push errors
	# into the console at boot. The fact that this test file loaded + ran
	# means project boot completed clean — but assert the API is present as
	# a defense in depth (a missing method here would point at silent autoload
	# failure mode).
	var reg: Node = _registry()
	assert_not_null(reg)
	for method: String in ["get_mob_def", "get_mob_scene", "has_mob", "apply_stratum_scaling", "spawn", "registered_ids"]:
		assert_true(reg.has_method(method), "MobRegistry must expose %s()" % method)


# ---- W3-T5-AC2 — Round-trip: register + retrieve ---------------------

func test_get_mob_def_returns_grunt_def_for_grunt_id() -> void:
	var reg: Node = _registry()
	var def: MobDef = reg.get_mob_def(&"grunt")
	assert_not_null(def, "grunt MobDef must resolve")
	assert_eq(def.id, &"grunt", "grunt MobDef has correct id")


func test_get_mob_def_returns_charger_def_for_charger_id() -> void:
	var reg: Node = _registry()
	var def: MobDef = reg.get_mob_def(&"charger")
	assert_not_null(def, "charger MobDef must resolve")
	assert_eq(def.id, &"charger", "charger MobDef has correct id")


func test_get_mob_def_returns_shooter_def_for_shooter_id() -> void:
	var reg: Node = _registry()
	var def: MobDef = reg.get_mob_def(&"shooter")
	assert_not_null(def, "shooter MobDef must resolve")
	assert_eq(def.id, &"shooter", "shooter MobDef has correct id")


func test_get_mob_def_returns_stoker_def_for_stoker_id() -> void:
	# Stoker mob is NOT yet shipped (deferred to W3-T3/T4 — heat-blasted
	# Grunt variant). Until the Stoker TRES + scene land, this test stays
	# pending. When Stoker ships, register it in
	# `MobRegistry._REGISTRATIONS` and flip this assertion to:
	#   var def: MobDef = _registry().get_mob_def(&"stoker")
	#   assert_not_null(def); assert_eq(def.id, &"stoker")
	pending("Stoker mob TRES + scene not yet shipped (deferred to W3-T3/T4)")


func test_get_mob_scene_returns_correct_packed_scene() -> void:
	var reg: Node = _registry()
	var scene: PackedScene = reg.get_mob_scene(&"grunt")
	assert_not_null(scene, "grunt PackedScene must resolve")
	# Instantiate-once to verify the scene root extends Grunt — guards
	# against a future MobDef-vs-Scene mismatch in the registry.
	var node: Node = scene.instantiate()
	assert_true(node is Grunt, "grunt scene root must be a Grunt CharacterBody2D")
	node.free()


func test_get_mob_def_returns_null_for_unknown_id_no_crash() -> void:
	var reg: Node = _registry()
	# Both lookup paths must gracefully return null on unknown id — no
	# crash, no exception. push_warnings are accepted at this surface
	# (regression check: the warning lives in MobRegistry, not in the
	# call site, so callers don't need to guard).
	#
	# Unknown-id paths in get_mob_def / get_mob_scene return null EARLY
	# without push_warning (registration table miss path). It's the
	# spawn() path that warns. has_mob has no warning either. So no
	# expect_warning is needed here — pinning that contract is part of
	# the test: if a future refactor moves the warning earlier, this
	# test will flip RED via the universal-warning gate.
	var def: MobDef = reg.get_mob_def(&"definitely_not_a_real_mob_id_zzzz")
	assert_null(def, "unknown mob_id returns null from get_mob_def")
	var scene: PackedScene = reg.get_mob_scene(&"definitely_not_a_real_mob_id_zzzz")
	assert_null(scene, "unknown mob_id returns null from get_mob_scene")
	# has_mob is the cheap path — must return false on unknown id.
	assert_false(reg.has_mob(&"definitely_not_a_real_mob_id_zzzz"))


# ---- W3-T5-AC3 — Stratum-scaling math correct ------------------------
##
## S1 baseline: HP × 1.0 / dmg × 1.0.
## S2 scaling: HP × 1.2 / dmg × 1.15 (per mvp-scope.md §M2).

func test_apply_stratum_scaling_s1_returns_baseline_values() -> void:
	var reg: Node = _registry()
	# Build a deterministic source MobDef so the test doesn't depend on
	# whatever `resources/mobs/grunt.tres` happens to be balanced at.
	var src: MobDef = ContentFactory.make_mob_def({"hp_base": 50, "damage_base": 4})
	var scaled: MobDef = reg.apply_stratum_scaling(src, &"s1")
	assert_not_null(scaled, "s1 scaling produces a MobDef")
	assert_eq(scaled.hp_base, 50, "s1 hp_base × 1.0 == src")
	assert_eq(scaled.damage_base, 4, "s1 damage_base × 1.0 == src")


func test_apply_stratum_scaling_s2_returns_scaled_hp_1_2x() -> void:
	var reg: Node = _registry()
	var src: MobDef = ContentFactory.make_mob_def({"hp_base": 50, "damage_base": 4})
	var scaled: MobDef = reg.apply_stratum_scaling(src, &"s2")
	assert_not_null(scaled)
	# 50 × 1.20 = 60.0; roundi(60.0) == 60.
	assert_eq(scaled.hp_base, 60, "s2 hp_base = src × 1.20 = 60")


func test_apply_stratum_scaling_s2_returns_scaled_damage_1_15x() -> void:
	var reg: Node = _registry()
	var src: MobDef = ContentFactory.make_mob_def({"hp_base": 50, "damage_base": 20})
	var scaled: MobDef = reg.apply_stratum_scaling(src, &"s2")
	assert_not_null(scaled)
	# 20 × 1.15 = 23.0; roundi(23.0) == 23. Picking damage_base=20 gives a
	# clean integer; using damage_base=4 would round to roundi(4.6)=5 which
	# is also correct but less clearly the 1.15x multiplier.
	assert_eq(scaled.damage_base, 23, "s2 damage_base = src × 1.15 = 23")


# ---- W3-T5-AC4 — Scaling-doesn't-mutate-source invariant ------------

func test_apply_stratum_scaling_returns_new_instance_not_source() -> void:
	var reg: Node = _registry()
	var src: MobDef = ContentFactory.make_mob_def({"hp_base": 50, "damage_base": 4})
	var scaled: MobDef = reg.apply_stratum_scaling(src, &"s2")
	# Reference inequality: the returned def is a fresh instance, not
	# the same MobDef object the caller passed in.
	assert_ne(scaled.get_instance_id(), src.get_instance_id(),
		"apply_stratum_scaling must allocate a NEW MobDef, not mutate the source")
	# Source remains at its original values.
	assert_eq(src.hp_base, 50, "source hp_base unmodified after scaling")
	assert_eq(src.damage_base, 4, "source damage_base unmodified after scaling")


func test_apply_stratum_scaling_twice_does_not_compound() -> void:
	# EP-DUP edge probe from W3 acceptance plan §W3-T5.
	# Calling apply_stratum_scaling(def, &"s2") twice returns a new def
	# with the SAME values (1.2x, not 1.2 × 1.2 = 1.44x — that's a bug).
	var reg: Node = _registry()
	var src: MobDef = ContentFactory.make_mob_def({"hp_base": 50, "damage_base": 20})
	var first: MobDef = reg.apply_stratum_scaling(src, &"s2")
	var second: MobDef = reg.apply_stratum_scaling(src, &"s2")
	assert_eq(first.hp_base, second.hp_base,
		"twice-scaled hp_base must equal once-scaled (no compounding)")
	assert_eq(first.damage_base, second.damage_base,
		"twice-scaled damage_base must equal once-scaled (no compounding)")
	# Hard pin on the 1.44× / 1.32× bug — if the source had been mutated
	# in the first call, the second call would see hp_base=60 and produce
	# 60 × 1.2 = 72. Verify that DID NOT happen.
	assert_ne(second.hp_base, 72,
		"compounded scaling (1.44x = 72) is a bug — second call must NOT see mutated source")


# ---- W3-T5-AC5 — Refactor regression (MultiMobRoom._spawn_mob) -----
##
## Real refactor regression coverage runs in `tests/test_stratum1_rooms.gd`
## + `tests/test_stratum2_rooms.gd` (every existing M1/M2 mob-spawn test
## must stay green post-refactor). These two tests are smoke-coverage that
## the registry surface alone produces the right node types.

func test_multi_mob_room_spawn_via_registry_returns_correct_mob_type() -> void:
	var reg: Node = _registry()
	# Call MobRegistry.spawn directly — proves the unified entry point
	# instantiates the right scene and parents under the supplied room.
	var room: Node2D = Node2D.new()
	add_child_autofree(room)
	var node: Node = reg.spawn(&"grunt", Vector2(123, 45), room)
	assert_not_null(node, "spawn(&\"grunt\", ...) returns a node")
	assert_true(node is Grunt, "spawn returns a Grunt instance")
	assert_eq(node.get_parent(), room, "spawned mob is parented under the supplied room")
	assert_eq((node as Node2D).position, Vector2(123, 45), "position applied to spawned mob")
	# The MobDef must be set so kill -> XP / loot pipelines have a payload.
	assert_not_null(node.mob_def, "spawned mob has mob_def applied")
	assert_eq((node.mob_def as MobDef).id, &"grunt", "applied MobDef.id matches the requested mob_id")


func test_multi_mob_room_spawn_handles_unknown_id_gracefully() -> void:
	# spawn() DELIBERATELY emits a WarningBus warning on unknown id. Opt
	# the guard out for this specific pattern so after_each.assert_clean
	# doesn't flag it.
	_warn_guard.expect_warning("[MobRegistry] spawn: unknown mob_id")
	var reg: Node = _registry()
	var room: Node2D = Node2D.new()
	add_child_autofree(room)
	var node: Node = reg.spawn(&"definitely_not_a_real_mob_id_zzzz", Vector2.ZERO, room)
	assert_null(node, "unknown mob_id returns null from spawn (WarningBus.warn'd)")
	assert_eq(room.get_child_count(), 0, "no node parented under room for unknown id")


# ---- EP-OOO — autoload-order independence ---------------------------

func test_get_mob_def_before_ready_returns_correct_def() -> void:
	# EP-OOO edge probe — module-scope constants make autoload-order
	# irrelevant. Construct a fresh MobRegistry instance OUTSIDE the
	# autoload (so it has not run _ready) and verify get_mob_def resolves
	# correctly. Module-scope `_REGISTRATIONS` + lazy load() in get_mob_def
	# means the call is autoload-order-independent — even another autoload's
	# _ready calling into MobRegistry before MobRegistry's own _ready runs
	# must work.
	var MobRegistryScript: Script = preload("res://scripts/content/MobRegistry.gd")
	var fresh: Node = MobRegistryScript.new()
	# Do NOT add_child — keep it out of the tree so _ready does NOT fire.
	# Use a manual free at the end since add_child_autofree requires tree.
	var def: MobDef = fresh.get_mob_def(&"grunt")
	assert_not_null(def, "get_mob_def works before _ready (module-scope dict)")
	assert_eq(def.id, &"grunt")
	fresh.free()


# ---- EP-OOO bonus — registered_ids is stable ------------------------
##
## Bonus coverage: confirm the registry advertises every mob id documented
## above. This catches a future regression where someone removes a
## `_REGISTRATIONS` entry without auditing callers.

func test_registered_ids_includes_grunt_charger_shooter() -> void:
	var reg: Node = _registry()
	var ids: Array = reg.registered_ids()
	assert_true(&"grunt" in ids, "grunt is registered")
	assert_true(&"charger" in ids, "charger is registered")
	assert_true(&"shooter" in ids, "shooter is registered")


# ---- has_mob negative path -----------------------------------------
##
## Bonus coverage: `has_mob` is the cheap allocation-free check; verify it
## stays in lockstep with get_mob_def's null result.

func test_has_mob_returns_true_for_registered_and_false_for_unknown() -> void:
	var reg: Node = _registry()
	assert_true(reg.has_mob(&"grunt"))
	assert_true(reg.has_mob(&"charger"))
	assert_true(reg.has_mob(&"shooter"))
	assert_false(reg.has_mob(&"definitely_not_a_real_mob_id_zzzz"))


# ---- Unknown stratum fallback --------------------------------------
##
## Bonus coverage: unknown stratum_id falls back to baseline 1.0/1.0 with a
## push_warning. Verifies the safety net for a typo'd stratum id.

func test_apply_stratum_scaling_unknown_stratum_falls_back_to_baseline() -> void:
	# Unknown-stratum DELIBERATELY emits a WarningBus warning. Opt the
	# guard out for this specific pattern.
	_warn_guard.expect_warning("unknown stratum_id")
	var reg: Node = _registry()
	var src: MobDef = ContentFactory.make_mob_def({"hp_base": 50, "damage_base": 4})
	var scaled: MobDef = reg.apply_stratum_scaling(src, &"definitely_not_a_real_stratum_id_zzzz")
	assert_not_null(scaled, "unknown stratum still returns a MobDef (baseline fallback)")
	assert_eq(scaled.hp_base, 50, "unknown stratum -> 1.0x hp")
	assert_eq(scaled.damage_base, 4, "unknown stratum -> 1.0x damage")


# ---- Null MobDef defense ----------------------------------------
##
## Bonus coverage: apply_stratum_scaling(null, ...) must NOT crash. Returns
## null and push_warnings.

func test_apply_stratum_scaling_null_def_returns_null_no_crash() -> void:
	# Null-MobDef DELIBERATELY emits a WarningBus warning. Opt the guard
	# out for this specific pattern.
	_warn_guard.expect_warning("apply_stratum_scaling called with null mob_def")
	var reg: Node = _registry()
	var scaled: MobDef = reg.apply_stratum_scaling(null, &"s2")
	assert_null(scaled, "null mob_def in -> null out (graceful)")
