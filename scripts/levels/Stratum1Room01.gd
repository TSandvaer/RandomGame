class_name Stratum1Room01
extends Node2D
## Stratum-1, room 01 — the player's first encounter with Embergrave's
## combat loop. Single-chunk room loaded via `LevelAssembler`. Spawns the
## chunk's authored mobs and positions the camera at the entry.
##
## M1 acceptance criteria touched here:
##   - AC2 ("player can engage one grunt in stratum 1's first room")
##   - AC4 (combat math vs grunt — covered indirectly via spawned grunt)
##
## See `team/drew-dev/level-chunks.md` and Uma's `visual-direction.md`
## (480x270 internal canvas).

## The chunk this room loads. Either set in the .tscn at author time or
## injected at runtime by tests.
@export var chunk_def: LevelChunkDef

## res:// path to the Grunt scene. Indirected via export so tests can swap
## in a marker fake without coupling the assembler to Grunt's spec.
@export_file("*.tscn") var grunt_scene_path: String = "res://scenes/mobs/Grunt.tscn"

# Cached load to avoid re-parsing the scene per spawn.
var _grunt_scene_cache: PackedScene = null

# The assembled result, exposed for tests / save code that wants to
# enumerate spawned mobs after `_ready`.
var _assembly: LevelAssembler.AssemblyResult = null


func _ready() -> void:
	if chunk_def == null:
		# Fallback: try the canonical M1 chunk. Logged so a missing assignment
		# surfaces loudly.
		chunk_def = load("res://resources/level_chunks/s1_room01.tres") as LevelChunkDef
	if chunk_def == null:
		push_error("Stratum1Room01: no chunk_def assigned and fallback load failed")
		return
	_build()


func _build() -> void:
	var assembler: LevelAssembler = LevelAssembler.new()
	var spawner: Callable = Callable(self, "_spawn_mob")
	_assembly = assembler.assemble_single(chunk_def, spawner)
	if _assembly == null:
		return
	add_child(_assembly.root)


# ---- Public API -------------------------------------------------------

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


# ---- Spawner ----------------------------------------------------------

func _spawn_mob(mob_id: StringName, _world_pos: Vector2) -> Node:
	# M1 only knows about &"grunt". Future archetypes expand the if-ladder
	# OR (preferred for M2) a real MobRegistry replaces this.
	if mob_id == &"grunt":
		var scene: PackedScene = _get_grunt_scene()
		if scene == null:
			push_warning("Stratum1Room01: grunt scene failed to load at '%s'" % grunt_scene_path)
			return null
		var node: Node = scene.instantiate()
		# Resolve the player at runtime via group lookup. The Grunt's own
		# `_resolve_player` does this on _ready, but we set it explicitly
		# here too for headless tests where _ready may have already fired.
		return node
	push_warning("Stratum1Room01: unknown mob_id '%s' — no factory entry" % mob_id)
	return null


func _get_grunt_scene() -> PackedScene:
	if _grunt_scene_cache != null:
		return _grunt_scene_cache
	if grunt_scene_path == "":
		return null
	_grunt_scene_cache = load(grunt_scene_path) as PackedScene
	return _grunt_scene_cache
