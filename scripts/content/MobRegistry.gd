extends Node
## MobRegistry autoload — stratum-aware mob lookup + scaling.
##
## **Purpose (W3-T5 / #86c9ue1up):** centralize mob-id → MobDef + PackedScene
## dispatch so `MultiMobRoom._spawn_mob` (and any future spawner) calls into a
## single registry instead of carrying its own match-block of per-mob TRES +
## scene paths. As of W3 the M1 mob roster is grunt / charger / shooter; M2
## widens this to include stoker (heat-blasted grunt variant — W2 T6
## planning surface; not yet shipped in main, so deliberately NOT registered
## here). Future M2+ mob ids register by appending to `_REGISTRATIONS`.
##
## **Why an autoload:** `MultiMobRoom._spawn_mob` runs from
## `LevelAssembler.assemble_single` during `MultiMobRoom._build`, which itself
## runs synchronously from `_ready`. Looking up the spawner via
## `/root/MobRegistry` avoids passing the registry through the assembler
## callable chain. The autoload is also the natural home for stratum-scaling
## multipliers (`apply_stratum_scaling`), which need to be in scope for any
## future loot-table seed pass / boss-room build that wants stratum-aware
## stat values.
##
## **Method surface (W3-T5 acceptance):**
##   get_mob_def(mob_id: StringName) -> MobDef
##     - Returns the registered MobDef. `null` on unknown id (graceful — no
##       crash, paired test pins this).
##   get_mob_scene(mob_id: StringName) -> PackedScene
##     - Returns the registered PackedScene. `null` on unknown id.
##   apply_stratum_scaling(mob_def: MobDef, stratum_id: StringName) -> MobDef
##     - Returns a NEW MobDef instance with hp_base / damage_base scaled per
##       stratum. `s1` is baseline 1.0x; `s2` is +20% HP / +15% dmg per
##       `mvp-scope.md §M2`. Source MobDef is NEVER mutated (paired-test
##       invariant — calling twice doesn't compound).
##   spawn(mob_id: StringName, world_position: Vector2, room_node: Node) -> Node
##     - Unified entry-point. Instantiates the registered scene, applies the
##       registered MobDef, sets position, parents under `room_node`, returns
##       the spawned mob. Returns `null` on unknown id (push_warning'd).
##
## **Lifecycle.** Registry construction is module-scope (the `_REGISTRATIONS`
## const + `_load_def` / `_load_scene` lazy-cache fields) so callers can call
## `get_mob_def` / `get_mob_scene` BEFORE the autoload's `_ready` completes —
## autoload-order-independent (paired-test EP-OOO probe pins this).
##
## **Scaling-doesn't-mutate-source invariant.** `apply_stratum_scaling`
## allocates a fresh MobDef (via `_MobDef.new()`) and copies every field
## from the source, then applies the stratum multipliers on the COPY. Source
## stays untouched, so calling twice with `&"s2"` returns a NEW def with the
## same `hp_base × 1.2` value — NOT `hp_base × 1.2 × 1.2 = 1.44x` (would be a
## compounding bug). Tess's `test_apply_stratum_scaling_twice_does_not_compound`
## probe (EP-DUP) pins this. Integer scaling uses `roundi` so multiplier
## fractions don't silently truncate.
##
## **No behavior change for existing rooms.** `MultiMobRoom.spawn` calls into
## `MobRegistry.spawn` after this PR; the production code path goes through
## the same `MobDef` / `PackedScene` instances the old match-block resolved,
## so M1 / M2 mob-spawn behaviour is bit-identical pre-/post-refactor.
## `apply_stratum_scaling` is NOT invoked from the spawn path in this PR —
## scaling is exposed via the API and will be wired into MultiMobRoom in a
## follow-up (W3-T1 AC4 balance pass / M2 W3+ when stratum-aware spawning is
## desired).
##
## See `team/priya-pl/m2-week-3-backlog.md` §W3-T5 for the dispatch + scope,
## `team/tess-qa/m2-acceptance-plan-week-3.md` §W3-T5 (AC1..AC5 + EP-OOO/EP-DUP)
## for the acceptance contract this autoload satisfies.

const _MobDef: Script = preload("res://scripts/content/MobDef.gd")

# ---- Stratum scaling table (mvp-scope.md §M2) -----------------------
##
## `&"s1"` is the baseline — multipliers 1.0 / 1.0. `&"s2"` lifts HP by 20%
## and damage by 15%. Future strata (s3 .. s8) extend this table. Unknown
## stratum ids fall back to baseline (1.0 / 1.0) with a push_warning so a
## typo'd id surfaces in console without crashing.
const _STRATUM_SCALING: Dictionary = {
	&"s1": {"hp": 1.0, "damage": 1.0},
	&"s2": {"hp": 1.2, "damage": 1.15},
}

# ---- Mob registrations -----------------------------------------------
##
## Map of `mob_id: StringName -> {"def": <res://...>, "scene": <res://...>}`.
## Constants point at the production TRES + .tscn paths so the registry mirrors
## what `MultiMobRoom` resolved by hand pre-refactor. Append a new entry when
## a new mob class lands (e.g. Stoker — when its TRES + scene ship as part of
## the W3-T3 retint / W3-T4 boss-room work, register here so MultiMobRoom can
## simply spawn `&"stoker"`).
const _REGISTRATIONS: Dictionary = {
	&"grunt": {
		"def": "res://resources/mobs/grunt.tres",
		"scene": "res://scenes/mobs/Grunt.tscn",
	},
	&"charger": {
		"def": "res://resources/mobs/charger.tres",
		"scene": "res://scenes/mobs/Charger.tscn",
	},
	&"shooter": {
		"def": "res://resources/mobs/shooter.tres",
		"scene": "res://scenes/mobs/Shooter.tscn",
	},
}

# ---- Caches ---------------------------------------------------------
##
## Lazy-loaded per id. `load()` reads from the resource cache, so repeated
## lookups are O(1) hash + dict access. Caching here keeps the spawn-hot-path
## allocation-free past the first lookup per mob_id per run.
var _def_cache: Dictionary = {}     # StringName -> MobDef
var _scene_cache: Dictionary = {}   # StringName -> PackedScene


# ---- Public API -----------------------------------------------------

## Returns the registered MobDef for `mob_id`. `null` on unknown id (caller
## logs / pushes warning).
func get_mob_def(mob_id: StringName) -> MobDef:
	if not _REGISTRATIONS.has(mob_id):
		return null
	if not _def_cache.has(mob_id):
		var path: String = _REGISTRATIONS[mob_id]["def"]
		var def: MobDef = load(path) as MobDef
		if def == null:
			push_warning("[MobRegistry] failed to load MobDef at %s for id '%s'" % [path, String(mob_id)])
			return null
		_def_cache[mob_id] = def
	return _def_cache[mob_id]


## Returns the registered PackedScene for `mob_id`. `null` on unknown id.
func get_mob_scene(mob_id: StringName) -> PackedScene:
	if not _REGISTRATIONS.has(mob_id):
		return null
	if not _scene_cache.has(mob_id):
		var path: String = _REGISTRATIONS[mob_id]["scene"]
		var scene: PackedScene = load(path) as PackedScene
		if scene == null:
			push_warning("[MobRegistry] failed to load PackedScene at %s for id '%s'" % [path, String(mob_id)])
			return null
		_scene_cache[mob_id] = scene
	return _scene_cache[mob_id]


## Returns true if `mob_id` is registered (synonym for "non-null get_mob_def"
## without forcing a TRES load — useful in unit tests).
func has_mob(mob_id: StringName) -> bool:
	return _REGISTRATIONS.has(mob_id)


## Returns a NEW MobDef with `hp_base` and `damage_base` scaled per stratum.
## Source `mob_def` is NEVER mutated — calling twice with the same stratum
## returns a new def with the SAME values (does NOT compound multipliers).
##
## Unknown `stratum_id` falls back to baseline (1.0 / 1.0) with a push_warning
## so a typo'd id surfaces in console.
func apply_stratum_scaling(mob_def: MobDef, stratum_id: StringName) -> MobDef:
	if mob_def == null:
		push_warning("[MobRegistry] apply_stratum_scaling called with null mob_def")
		return null
	var multipliers: Dictionary = _STRATUM_SCALING.get(stratum_id, {"hp": 1.0, "damage": 1.0})
	if not _STRATUM_SCALING.has(stratum_id):
		push_warning("[MobRegistry] unknown stratum_id '%s' — using baseline 1.0/1.0" % String(stratum_id))
	# Allocate a fresh MobDef and copy every field from the source. We do NOT
	# mutate `mob_def` itself — calling this twice on the same source returns
	# a new def with the SAME scaled values, NOT compounded values. Tess's
	# EP-DUP edge probe pins this (`test_apply_stratum_scaling_twice_does_not_compound`).
	var scaled: MobDef = _MobDef.new()
	scaled.id = mob_def.id
	scaled.display_name = mob_def.display_name
	scaled.sprite_path = mob_def.sprite_path
	scaled.hp_base = roundi(float(mob_def.hp_base) * float(multipliers["hp"]))
	scaled.damage_base = roundi(float(mob_def.damage_base) * float(multipliers["damage"]))
	scaled.move_speed = mob_def.move_speed
	scaled.ai_behavior_tag = mob_def.ai_behavior_tag
	scaled.loot_table = mob_def.loot_table
	scaled.xp_reward = mob_def.xp_reward
	return scaled


## Unified spawn entry-point. Instantiates the registered scene for `mob_id`,
## applies its MobDef, sets position, parents under `room_node`, returns the
## spawned mob. Returns `null` on unknown id (push_warning'd by `get_mob_*`).
##
## **Stratum scaling NOT applied in this PR.** This method preserves M1/M2
## existing spawn behaviour (refactor is bit-identical pre-/post). A future
## variant (`spawn_scaled(mob_id, position, room, stratum_id)`) will layer
## stratum scaling once the AC4 balance pass / W3-T1 settles which spawn
## sites should apply it.
func spawn(mob_id: StringName, world_position: Vector2, room_node: Node) -> Node:
	var scene: PackedScene = get_mob_scene(mob_id)
	if scene == null:
		push_warning("[MobRegistry] spawn: unknown mob_id '%s'" % String(mob_id))
		return null
	var def: MobDef = get_mob_def(mob_id)
	var node: Node = scene.instantiate()
	# Apply the MobDef so kill -> mob_died -> XP/loot pipelines see a non-null
	# mob_def payload (otherwise both pipelines silently no-op). Matches the
	# pre-refactor `MultiMobRoom._spawn_mob` behaviour exactly.
	if def != null and "mob_def" in node:
		node.mob_def = def
	if node is Node2D:
		(node as Node2D).position = world_position
	if room_node != null:
		room_node.add_child(node)
	return node


## Returns an Array[StringName] of every registered mob_id, for diagnostics
## and test parameterization. Order is undefined (Dictionary key order in
## Godot 4 is insertion-stable but callers should not depend on it).
func registered_ids() -> Array:
	return _REGISTRATIONS.keys()
