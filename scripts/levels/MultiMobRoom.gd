class_name MultiMobRoom
extends Node2D
## Generic multi-mob room script. Mirrors the assembly pattern from
## `Stratum1Room01.gd` but supports a configurable mob roster plus optional
## healing-fountain placement and a `RoomGate` that locks behind the player
## on entry. M1 ships this driving stratum-1 rooms 02..08 with the
## grunt / charger / shooter mob set; M2+ strata reuse the exact same
## mechanism with a different `chunk_def` and the same scene-path exports
## pointing at stratum-N mob scenes.
##
## Why one script for 7 rooms (instead of one-per-room like Room01):
##   - Behavior is identical room-to-room — only the chunk_def's mob spawn
##     list and ports differ.
##   - Reduces drift risk across 7 nearly-identical files.
##   - The chunk TRES authors the variation; the script provides the
##     mechanism. Same data-driven spirit as `LevelChunkDef`.
##
## Each Room02..Room08 .tscn instances this script and points its
## `chunk_def` export at the matching `s1_roomNN.tres`. M2 stratum-2
## rooms will follow the same pattern with `s2_roomNN.tres` chunks.
##
## Renamed 2026-05-02 from `Stratum1MultiMobRoom` (W3-B2 multi-stratum
## scaffold). Body has zero S1-specific assumptions — the mob_id list
## (`grunt` / `charger` / `shooter`) is M1 *content* served via the
## `MobRegistry` autoload, not a class-name contract. M2+ implementers
## register new mob_ids in `MobRegistry._REGISTRATIONS` (W3-T5 refactor,
## ticket #86c9ue1up) — `MultiMobRoom._spawn_mob` requires no edits when a
## new mob class lands. Pre-W3-T5 this dispatch was a per-mob match-block
## of `@export_file` paths + lazy-load helpers; that surface collapsed into
## a single `MobRegistry.spawn(...)` call with bit-identical runtime
## behaviour (refactor pinned by `tests/test_stratum1_rooms.gd` +
## `tests/test_stratum2_rooms.gd` regression sweep, and
## `tests/test_mob_registry.gd::test_multi_mob_room_spawn_via_registry_returns_correct_mob_type`).
##
## Acceptance criteria touched:
##   - AC2 (player encounters varying mobs across the stratum).
##   - AC4 (combat math vs each archetype — covered indirectly via spawned
##     mobs picking up the existing damage formula).
##
## Optional features:
##   - `place_healing_fountain` — spawns a `HealingFountain` at
##     `healing_fountain_position` (Room 06 default).
##   - `room_gate_position` — if non-zero, instantiates a `RoomGate` and
##     registers every spawned mob with it. The gate auto-locks on player
##     entry and unlocks on full clear.

# ---- Signals ----------------------------------------------------------

## Emitted when the room's RoomGate flips to UNLOCKED — i.e. all mobs are
## dead. The Main / level-flow controller listens to this to mark the room
## cleared in StratumProgression and to unblock the exit port.
signal room_cleared()

# ---- Inspector -------------------------------------------------------

## The chunk this room loads. Set in the .tscn at author time.
@export var chunk_def: LevelChunkDef

## res:// paths to the mob scenes.
##
## **W3-T5 / #86c9ue1up — legacy export, no longer load-bearing.** Pre-W3-T5
## these path exports drove `_spawn_mob`'s match-block dispatch. The
## refactor moved dispatch to `MobRegistry.spawn(mob_id, ...)`, which
## resolves mob_id → PackedScene + MobDef via the autoload's
## `_REGISTRATIONS` table. These exports remain ONLY so existing
## `scenes/levels/Stratum1Room0N.tscn` (which set them at author-time) can
## continue to load without breaking. They are NOT read by `_spawn_mob` —
## the registry is the source of truth. To swap a scene for a test, register
## a fake in MobRegistry (or extend the registry with an injectable
## override) instead of overriding these exports.
@export_file("*.tscn") var grunt_scene_path: String = "res://scenes/mobs/Grunt.tscn"
@export_file("*.tscn") var charger_scene_path: String = "res://scenes/mobs/Charger.tscn"
@export_file("*.tscn") var shooter_scene_path: String = "res://scenes/mobs/Shooter.tscn"

## res:// paths to the mob MobDef TRES files. Legacy — see comment on
## scene-path exports above. The MobRegistry is the source of truth.
@export_file("*.tres") var grunt_mob_def_path: String = "res://resources/mobs/grunt.tres"
@export_file("*.tres") var charger_mob_def_path: String = "res://resources/mobs/charger.tres"
@export_file("*.tres") var shooter_mob_def_path: String = "res://resources/mobs/shooter.tres"

## res:// paths to the optional dressing scenes.
@export_file("*.tscn") var room_gate_scene_path: String = "res://scenes/levels/RoomGate.tscn"
@export_file("*.tscn") var healing_fountain_scene_path: String = "res://scenes/levels/HealingFountain.tscn"

## If non-zero, spawn a RoomGate at this world position. Vector2.ZERO means
## "no gate" — used by the boss-room handoff or by test scaffolding.
@export var room_gate_position: Vector2 = Vector2.ZERO
@export var room_gate_size: Vector2 = Vector2(48.0, 16.0)

## If true, drop a HealingFountain at `healing_fountain_position` after
## assembly. Room 06 sets this true.
@export var place_healing_fountain: bool = false
@export var healing_fountain_position: Vector2 = Vector2(240.0, 135.0)

# ---- Runtime ---------------------------------------------------------

# Pre-W3-T5 this carried per-mob PackedScene + MobDef caches. The
# MobRegistry autoload now owns the cache (id -> resource) — see
# `scripts/content/MobRegistry.gd::get_mob_scene` / `get_mob_def`.

var _assembly: LevelAssembler.AssemblyResult = null
var _room_gate: RoomGate = null
var _healing_fountain: HealingFountain = null


func _ready() -> void:
	if chunk_def == null:
		push_error("MultiMobRoom: no chunk_def assigned")
		return
	# `_build()` stays synchronous: it instantiates the chunk geometry +
	# every mob CharacterBody2D and splices them into this room's tree, so
	# `get_spawned_mobs()` / `get_bounds_px()` / the perimeter-wall geometry
	# are all live the same tick the room is added — `Main._wire_room_signals`
	# (and `test_room_boundary_walls.gd`) rely on that synchronous contract.
	#
	# This `_build()` `add_child` is physics-flush-safe ONLY because the
	# next-room load no longer runs inside a physics-flush window — see the
	# `CONNECT_DEFERRED` on `gate_traversed` in `_spawn_room_gate()` (ticket
	# 86c9u1cx1). With that deferral, `Main._on_room_cleared → _load_room_at_index
	# → _world.add_child(room) → MultiMobRoom._ready()` runs at end-of-frame,
	# OUTSIDE `PhysicsServer2D.flush_queries()`, so the mob CharacterBody2D +
	# CollisionShape2D inserts here land on a clean tick. Were `_build()` to
	# run inside a flush, those inserts would panic with `USER ERROR: Can't
	# change this state while flushing queries` (`body_set_shape_disabled` /
	# `body_set_shape_as_one_way_collision`) and leave the mobs' shapes
	# unregistered → un-hittable → room unbeatable (the Room 05 freeze).
	_build()
	# Defer the Area2D-fixture pass (RoomGate + HealingFountain spawn) AND
	# `_register_mobs_with_gate` out of the physics-flush window.
	#
	# Root cause (ticket 86c9tqvxx): `_spawn_room_gate()` does an `add_child`
	# of a `RoomGate` Area2D + activates its monitoring. Even with the
	# `gate_traversed` `CONNECT_DEFERRED` above making the *next-room* load
	# flush-safe, deferring this pass is kept belt-and-suspenders: it also
	# covers the FIRST room's load and mirrors the
	# `Stratum1Room01._ready → call_deferred("_wire_tutorial_flow")` and
	# `Stratum1BossRoom._ready → call_deferred("trigger_entry_sequence")`
	# precedents. `_spawn_healing_fountain` is folded in because it too does
	# an `add_child` of a fixture node.
	call_deferred("_assemble_room_fixtures")


## Deferred fixture pass — runs one frame after `_ready`. Spawns the RoomGate
## + HealingFountain Area2D-derived fixtures and registers every spawned mob
## with the gate. Idempotent-safe: if the room is freed before the deferred
## call lands, the `is_inside_tree` guard bails cleanly.
func _assemble_room_fixtures() -> void:
	if not is_inside_tree():
		return
	_spawn_room_gate()
	_spawn_healing_fountain()
	_register_mobs_with_gate()


# ---- Public API ------------------------------------------------------

func get_assembly() -> LevelAssembler.AssemblyResult:
	return _assembly


func get_bounds_px() -> Rect2:
	if _assembly == null:
		return Rect2()
	return _assembly.bounds_px


func get_spawned_mobs() -> Array[Node]:
	if _assembly == null:
		return []
	return _assembly.mobs


func get_room_gate() -> RoomGate:
	return _room_gate


func get_healing_fountain() -> HealingFountain:
	return _healing_fountain


func get_room_id() -> StringName:
	if chunk_def == null:
		return &""
	return chunk_def.id


# ---- Build ---------------------------------------------------------

## Construct the chunk assembly (geometry + mob CharacterBody2Ds) and splice
## it into this room's tree. Synchronous by design — `Main._wire_room_signals`
## and `test_room_boundary_walls.gd` read `get_spawned_mobs()` / the perimeter
## geometry the same tick the room is added. This `add_child(_assembly.root)`
## is physics-flush-safe ONLY because the next-room load is deferred out of
## the flush via the `gate_traversed` `CONNECT_DEFERRED` (ticket 86c9u1cx1) —
## see `_ready()` for the full rationale.
func _build() -> void:
	var assembler: LevelAssembler = LevelAssembler.new()
	var spawner: Callable = Callable(self, "_spawn_mob")
	_assembly = assembler.assemble_single(chunk_def, spawner)
	if _assembly == null:
		return
	add_child(_assembly.root)


func _spawn_room_gate() -> void:
	if room_gate_position == Vector2.ZERO:
		return
	if room_gate_scene_path == "":
		return
	var packed: PackedScene = load(room_gate_scene_path) as PackedScene
	if packed == null:
		push_warning("MultiMobRoom: gate scene failed to load at '%s'" % room_gate_scene_path)
		return
	var node: Node = packed.instantiate()
	if not node is RoomGate:
		push_error("MultiMobRoom: gate scene root is not RoomGate")
		node.free()
		return
	_room_gate = node
	# Set position + trigger_size BEFORE add_child so _ready() picks up the
	# room-specific values rather than the scene defaults.
	_room_gate.position = room_gate_position
	_room_gate.trigger_size = room_gate_size
	add_child(_room_gate)
	# Position B contract (ticket 86c9q94fg): gate_unlocked fires when the door
	# visual opens (after DEATH_TWEEN_WAIT_SECS delay). That is purely a visual
	# event. room_cleared (which triggers Main._on_room_cleared → load next room)
	# must NOT fire on gate_unlocked. It fires on gate_traversed — the signal
	# that emits when the player CharacterBody2D walks through the now-open door.
	# Disconnecting the old gate_unlocked → room_cleared path and replacing it
	# with gate_traversed → room_cleared is the entire P0 #1 fix.
	_room_gate.gate_unlocked.connect(_on_room_gate_unlocked)
	# CONNECT_DEFERRED (ticket 86c9u1cx1 — load-bearing): `gate_traversed` is
	# emitted from `RoomGate._on_body_entered`, a `body_entered` physics
	# callback that runs synchronously inside `PhysicsServer2D.flush_queries()`.
	# A SYNCHRONOUS connection would run `_on_room_gate_traversed → room_cleared
	# → Main._on_room_cleared → _load_room_at_index` entirely inside that flush
	# window — and `_load_room_at_index` does `_world.add_child(next_room)` +
	# `next_room.add_child(_player)`, splicing CharacterBody2D + CollisionShape2D
	# subtrees into the physics server mid-flush. That panics with `USER ERROR:
	# Can't change this state while flushing queries` (`body_set_shape_disabled`
	# / `body_set_shape_as_one_way_collision`), leaving the next room's mobs'
	# collision shapes UNREGISTERED — the mobs render + AI-tick but are
	# un-hittable, never die, and the room can never clear. This was the Room 05
	# 3-concurrent-chaser freeze. CONNECT_DEFERRED queues the entire next-room
	# load to end-of-frame, OUTSIDE the flush, so every body/shape splice in the
	# load chain runs on a clean tick. Mirrors PR #173's `mob_died`
	# CONNECT_DEFERRED on RoomGate.register_mob (same physics-flush race class).
	# See `.claude/docs/combat-architecture.md` § "Physics-flush rule".
	_room_gate.gate_traversed.connect(_on_room_gate_traversed, CONNECT_DEFERRED)


func _spawn_healing_fountain() -> void:
	if not place_healing_fountain:
		return
	if healing_fountain_scene_path == "":
		return
	var packed: PackedScene = load(healing_fountain_scene_path) as PackedScene
	if packed == null:
		push_warning("MultiMobRoom: fountain scene failed to load")
		return
	var node: Node = packed.instantiate()
	if not node is HealingFountain:
		push_error("MultiMobRoom: fountain scene root is not HealingFountain")
		node.free()
		return
	_healing_fountain = node
	_healing_fountain.position = healing_fountain_position
	add_child(_healing_fountain)


func _register_mobs_with_gate() -> void:
	if _room_gate == null:
		return
	for m: Node in get_spawned_mobs():
		_room_gate.register_mob(m)


# ---- Spawner -------------------------------------------------------

## Mob spawn dispatch. **W3-T5 / #86c9ue1up — refactored from match-block to
## MobRegistry.** Pre-refactor: this function carried a per-mob match-block
## that pulled scenes + defs from `@export_file` paths and `_get_*` cache
## helpers. Post-refactor: every `mob_id` resolves through
## `MobRegistry.get_mob_scene` / `get_mob_def`, with the autoload owning the
## cache. Adding a new mob class (e.g. Stoker — W3-T3/T4 surface) is now a
## one-line append to `MobRegistry._REGISTRATIONS` with zero edits here.
##
## Behaviour is bit-identical pre-/post-refactor:
##   - same PackedScene instance returned (resource cache),
##   - same MobDef applied to `node.mob_def`,
##   - same push_warning shape on unknown id.
##
## **Position handling note.** The world-position argument is intentionally
## ignored here — `LevelAssembler` is responsible for positioning every
## spawned mob via the chunk's `MobSpawnPoint.position_tiles` × tile_size.
## `MobRegistry.spawn(mob_id, position, room)` IS position-aware but only
## the unified callers (not the assembler-callable contract) use that
## variant; the assembler is a black box that calls
## `factory.call(mob_id, world_pos)` and then sets the mob's position from
## its own bookkeeping. To preserve that contract we route through
## `_instantiate_from_registry` (which mirrors the registry's `spawn` but
## skips the position-set + parent-add) rather than `MobRegistry.spawn`.
func _spawn_mob(mob_id: StringName, _world_pos: Vector2) -> Node:
	return _instantiate_from_registry(mob_id)


## Instantiate a mob via MobRegistry WITHOUT setting position / parenting.
## Mirrors `MobRegistry.spawn`'s scene-instantiate + mob_def-apply path so
## the assembler-callable contract (returns a free-floating Node the
## assembler then positions + parents) is preserved.
func _instantiate_from_registry(mob_id: StringName) -> Node:
	var registry: Node = _get_mob_registry()
	if registry == null:
		push_warning("MultiMobRoom: MobRegistry autoload not found at /root/MobRegistry")
		return null
	var scene: PackedScene = registry.get_mob_scene(mob_id)
	if scene == null:
		push_warning("MultiMobRoom: unknown mob_id '%s' (not in MobRegistry)" % mob_id)
		return null
	var node: Node = scene.instantiate()
	var def: MobDef = registry.get_mob_def(mob_id)
	# Apply the MobDef so kill -> mob_died -> XP/loot pipelines see a non-null
	# mob_def payload (otherwise both pipelines silently no-op).
	if def != null and "mob_def" in node:
		node.mob_def = def
	return node


func _get_mob_registry() -> Node:
	if not is_inside_tree():
		# Tree-detached construction (rare — most tests autofree the room
		# into a tree). Fall back to the main loop root if available.
		var loop: SceneTree = Engine.get_main_loop() as SceneTree
		if loop == null:
			return null
		return loop.root.get_node_or_null("MobRegistry")
	return get_tree().root.get_node_or_null("MobRegistry")


# ---- Internal -------------------------------------------------------

func _on_room_gate_unlocked() -> void:
	# Position B contract (ticket 86c9q94fg): gate_unlocked means the door
	# VISUAL has opened (mobs are all dead, death-tween wait has elapsed).
	# We do NOT advance the room counter here. room_cleared fires only when
	# the player walks through the open door (see _on_room_gate_traversed).
	# This handler is kept for potential future audio/visual hooks on door-open
	# (e.g. door-grind SFX, camera cue) without coupling it to room advancement.
	# [combat-trace] logging via RoomGate._unlock already emits a trace line.
	pass


func _on_room_gate_traversed() -> void:
	# Player walked through the open door — NOW advance the room counter.
	# [combat-trace] RoomGate.gate_traversed trace line fires just before this.
	# Mark cleared in StratumProgression so re-enter doesn't re-spawn mobs.
	var sp: Node = _get_stratum_progression()
	if sp != null and chunk_def != null:
		sp.call("mark_cleared", chunk_def.id)
	room_cleared.emit()


func _get_stratum_progression() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("StratumProgression")
