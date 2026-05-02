class_name Stratum1MultiMobRoom
extends Node2D
## Shared room script for Stratum-1 rooms 02..08. Mirrors the assembly
## pattern from `Stratum1Room01.gd` but supports the full M1 mob roster
## (grunt / charger / shooter) plus optional healing fountain placement
## and a `RoomGate` that locks behind the player on entry.
##
## Why one script for 7 rooms (instead of one-per-room like Room01):
##   - Behavior is identical room-to-room — only the chunk_def's mob spawn
##     list and ports differ.
##   - Reduces drift risk across 7 nearly-identical files.
##   - The chunk TRES authors the variation; the script provides the
##     mechanism. Same data-driven spirit as `LevelChunkDef`.
##
## Each Room02..Room08 .tscn instances this script and points its
## `chunk_def` export at the matching `s1_roomNN.tres`.
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

# Cached scene loads to avoid re-parsing per spawn.
var _grunt_scene_cache: PackedScene = null
var _charger_scene_cache: PackedScene = null
var _shooter_scene_cache: PackedScene = null

var _assembly: LevelAssembler.AssemblyResult = null
var _room_gate: RoomGate = null
var _healing_fountain: HealingFountain = null


func _ready() -> void:
	if chunk_def == null:
		push_error("Stratum1MultiMobRoom: no chunk_def assigned")
		return
	_build()
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
		push_warning("Stratum1MultiMobRoom: gate scene failed to load at '%s'" % room_gate_scene_path)
		return
	var node: Node = packed.instantiate()
	if not node is RoomGate:
		push_error("Stratum1MultiMobRoom: gate scene root is not RoomGate")
		node.free()
		return
	_room_gate = node
	# Set position + trigger_size BEFORE add_child so _ready() picks up the
	# room-specific values rather than the scene defaults.
	_room_gate.position = room_gate_position
	_room_gate.trigger_size = room_gate_size
	add_child(_room_gate)
	_room_gate.gate_unlocked.connect(_on_room_gate_unlocked)


func _spawn_healing_fountain() -> void:
	if not place_healing_fountain:
		return
	if healing_fountain_scene_path == "":
		return
	var packed: PackedScene = load(healing_fountain_scene_path) as PackedScene
	if packed == null:
		push_warning("Stratum1MultiMobRoom: fountain scene failed to load")
		return
	var node: Node = packed.instantiate()
	if not node is HealingFountain:
		push_error("Stratum1MultiMobRoom: fountain scene root is not HealingFountain")
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
	match mob_id:
		&"grunt":
			scene = _get_grunt_scene()
		&"charger":
			scene = _get_charger_scene()
		&"shooter":
			scene = _get_shooter_scene()
		_:
			push_warning("Stratum1MultiMobRoom: unknown mob_id '%s'" % mob_id)
			return null
	if scene == null:
		push_warning("Stratum1MultiMobRoom: scene cache miss for mob_id '%s'" % mob_id)
		return null
	return scene.instantiate()


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


# ---- Internal -------------------------------------------------------

func _on_room_gate_unlocked() -> void:
	# Mark the room cleared in the global progression tracker. The
	# StratumProgression autoload is registered in project.godot, so it's
	# always reachable via the get_node path.
	var sp: Node = _get_stratum_progression()
	if sp != null and chunk_def != null:
		sp.call("mark_cleared", chunk_def.id)
	room_cleared.emit()


func _get_stratum_progression() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("StratumProgression")
