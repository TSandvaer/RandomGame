class_name LevelAssembler
extends RefCounted
## Stitches one or more `LevelChunkDef`s into a single playable room.
##
## M1 only ever calls `assemble_single` — one chunk per room — but the data
## shape supports multi-chunk stitching (M2 procedural floors, M3 wider
## strata). Mob spawning is delegated via `mob_factory`: a callable that
## takes a mob_id (StringName) + world position (Vector2) and returns a
## CharacterBody2D ready to be parented under the room root.
##
## Why a Callable for spawning? Decouples the assembler from `MobRegistry`
## (which doesn't exist yet) and from the production Grunt scene path —
## tests inject a fake spawner that produces marker nodes for assertion.

## Result of an assembly call. Carries the room root, the chunk's world
## bounds, and all spawned mob nodes for downstream tests/code.
class AssemblyResult:
	extends RefCounted
	var root: Node2D = null
	var bounds_px: Rect2 = Rect2()
	var mobs: Array[Node] = []
	var entry_world_pos: Vector2 = Vector2.ZERO
	var chunk_def: LevelChunkDef = null


## Build a single-chunk room. The chunk is placed at world origin (0,0).
## `mob_factory` is `func(mob_id: StringName, world_pos: Vector2) -> Node`.
## If null, mobs are not spawned (useful for headless tests of geometry).
##
## Returns null on validation failure (caller's responsibility to check
## `chunk_def.validate()` first if it cares about diagnostics).
func assemble_single(chunk_def: LevelChunkDef, mob_factory: Callable = Callable()) -> AssemblyResult:
	if chunk_def == null:
		push_error("LevelAssembler: chunk_def is null")
		return null
	var errors: Array[String] = chunk_def.validate()
	if not errors.is_empty():
		push_error("LevelAssembler: chunk_def invalid: %s" % str(errors))
		return null

	var result: AssemblyResult = AssemblyResult.new()
	result.chunk_def = chunk_def
	result.root = Node2D.new()
	result.root.name = "RoomRoot_%s" % chunk_def.id

	var size_px: Vector2i = chunk_def.size_px()
	result.bounds_px = Rect2(Vector2.ZERO, size_px)

	# Instantiate the authored chunk geometry scene, if any. This is what
	# carries the floor sprite + perimeter wall StaticBody2Ds that prevent
	# the player from walking off the room edge into the void (BB-3 fix —
	# `86c9m393a`). Prior to this, `scene_path` was declared on the chunk
	# def but never loaded, so rooms shipped with no floor or walls at
	# runtime.
	if chunk_def.scene_path != "":
		var packed: PackedScene = load(chunk_def.scene_path) as PackedScene
		if packed != null:
			var geometry: Node = packed.instantiate()
			if geometry != null:
				result.root.add_child(geometry)
		else:
			push_warning(
				"LevelAssembler: chunk_def.scene_path '%s' failed to load (geometry skipped)"
					% chunk_def.scene_path
			)

	# Entry world position — for M1 single-chunk rooms, it's the entry
	# port if defined, else the chunk's center.
	var entry_port: ChunkPort = chunk_def.get_entry_port()
	if entry_port != null:
		result.entry_world_pos = Vector2(entry_port.position_tiles * chunk_def.tile_size_px) + Vector2(
			float(chunk_def.tile_size_px) * 0.5,
			float(chunk_def.tile_size_px) * 0.5,
		)
	else:
		result.entry_world_pos = Vector2(size_px) * 0.5

	# Spawn mobs.
	if not mob_factory.is_null():
		for ms: MobSpawnPoint in chunk_def.mob_spawns:
			var world_pos: Vector2 = _tile_to_world(ms.position_tiles, chunk_def.tile_size_px)
			var mob: Node = mob_factory.call(ms.mob_id, world_pos)
			if mob == null:
				push_warning(
					"LevelAssembler: mob_factory returned null for id '%s' — skipped" % ms.mob_id
				)
				continue
			if mob is Node2D:
				(mob as Node2D).position = world_pos
			result.root.add_child(mob)
			result.mobs.append(mob)

	return result


## Tile -> world position (centered on the tile).
static func _tile_to_world(tile_pos: Vector2i, tile_size_px: int) -> Vector2:
	return Vector2(tile_pos * tile_size_px) + Vector2(
		float(tile_size_px) * 0.5,
		float(tile_size_px) * 0.5,
	)
