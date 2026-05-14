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
## (`grunt` / `charger` / `shooter`) is M1 *content* served via export
## paths, not a class-name contract. M2 implementers extend the
## `_spawn_mob` match block with new mob_ids as needed.
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

## res:// paths to the mob scenes. Indirected via export so tests can swap
## in fakes without coupling the assembler to production scenes.
@export_file("*.tscn") var grunt_scene_path: String = "res://scenes/mobs/Grunt.tscn"
@export_file("*.tscn") var charger_scene_path: String = "res://scenes/mobs/Charger.tscn"
@export_file("*.tscn") var shooter_scene_path: String = "res://scenes/mobs/Shooter.tscn"

## res:// paths to the mob MobDef TRES files. Applied to each spawned mob
## so its `mob_def` reference is set (HP/damage/xp_reward/loot_table flow
## from here). Without this, `mob_def` stays null and the Levels/loot
## pipelines silently no-op on kill — same fix as Stratum1Room01.
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

# Cached scene + def loads to avoid re-parsing per spawn.
var _grunt_scene_cache: PackedScene = null
var _charger_scene_cache: PackedScene = null
var _shooter_scene_cache: PackedScene = null
var _grunt_def_cache: MobDef = null
var _charger_def_cache: MobDef = null
var _shooter_def_cache: MobDef = null

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

func _spawn_mob(mob_id: StringName, _world_pos: Vector2) -> Node:
	var scene: PackedScene = null
	var def: MobDef = null
	match mob_id:
		&"grunt":
			scene = _get_grunt_scene()
			def = _get_grunt_def()
		&"charger":
			scene = _get_charger_scene()
			def = _get_charger_def()
		&"shooter":
			scene = _get_shooter_scene()
			def = _get_shooter_def()
		_:
			push_warning("MultiMobRoom: unknown mob_id '%s'" % mob_id)
			return null
	if scene == null:
		push_warning("MultiMobRoom: scene cache miss for mob_id '%s'" % mob_id)
		return null
	var node: Node = scene.instantiate()
	# Apply the MobDef so kill -> mob_died -> XP/loot pipelines see a non-null
	# mob_def payload (otherwise both pipelines silently no-op).
	if def != null and "mob_def" in node:
		node.mob_def = def
	return node


func _get_grunt_scene() -> PackedScene:
	if _grunt_scene_cache == null and grunt_scene_path != "":
		_grunt_scene_cache = load(grunt_scene_path) as PackedScene
	return _grunt_scene_cache


func _get_charger_scene() -> PackedScene:
	if _charger_scene_cache == null and charger_scene_path != "":
		_charger_scene_cache = load(charger_scene_path) as PackedScene
	return _charger_scene_cache


func _get_shooter_scene() -> PackedScene:
	if _shooter_scene_cache == null and shooter_scene_path != "":
		_shooter_scene_cache = load(shooter_scene_path) as PackedScene
	return _shooter_scene_cache


func _get_grunt_def() -> MobDef:
	if _grunt_def_cache == null and grunt_mob_def_path != "":
		_grunt_def_cache = load(grunt_mob_def_path) as MobDef
	return _grunt_def_cache


func _get_charger_def() -> MobDef:
	if _charger_def_cache == null and charger_mob_def_path != "":
		_charger_def_cache = load(charger_mob_def_path) as MobDef
	return _charger_def_cache


func _get_shooter_def() -> MobDef:
	if _shooter_def_cache == null and shooter_mob_def_path != "":
		_shooter_def_cache = load(shooter_mob_def_path) as MobDef
	return _shooter_def_cache


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
