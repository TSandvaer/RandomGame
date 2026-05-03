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

## res:// path to the Grunt MobDef. Applied to each spawned grunt so its
## `mob_def` reference is set (HP/damage/xp_reward/loot_table all flow from
## here). Without this the mob_died signal carries `mob_def == null`, which
## makes the Levels.subscribe_to_mob and MobLootSpawner pipelines silently
## no-op on the kill — caught at integration time by
## `tests/integration/test_m1_play_loop.gd::test_first_kill_grants_xp_and_loot_into_inventory`.
@export_file("*.tres") var grunt_mob_def_path: String = "res://resources/mobs/grunt.tres"

# Cached loads to avoid re-parsing the scene / TRES per spawn.
var _grunt_scene_cache: PackedScene = null
var _grunt_def_cache: MobDef = null

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
		# Apply the grunt MobDef so HP/damage/xp_reward/loot_table flow from
		# the authored .tres. Without this, `mob_def` stays null and the
		# Levels + loot pipelines silently no-op on kill (the mob_died signal
		# carries mob_def=null).
		var def: MobDef = _get_grunt_def()
		if def != null:
			(node as Grunt).mob_def = def
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


func _get_grunt_def() -> MobDef:
	if _grunt_def_cache != null:
		return _grunt_def_cache
	if grunt_mob_def_path == "":
		return null
	_grunt_def_cache = load(grunt_mob_def_path) as MobDef
	return _grunt_def_cache
