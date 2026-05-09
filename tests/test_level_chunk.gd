extends GutTest
## Tests for `LevelChunkDef`, `MobSpawnPoint`, `ChunkPort`, and
## `LevelAssembler`. Per the testing bar: chunk loads, has expected
## entry/exit ports, mob spawn points are valid.
##
## Architectural reminder: chunks declare `mob_id` (StringName), the
## assembler's `mob_factory` callable resolves them to actual nodes. Tests
## inject a recording fake so we can assert on what the assembler asked for
## without coupling to Grunt.gd.

const LevelChunkDefScript: Script = preload("res://scripts/levels/LevelChunkDef.gd")
const MobSpawnPointScript: Script = preload("res://scripts/levels/MobSpawnPoint.gd")
const ChunkPortScript: Script = preload("res://scripts/levels/ChunkPort.gd")
const LevelAssemblerScript: Script = preload("res://scripts/levels/LevelAssembler.gd")


# ---- Helpers ---------------------------------------------------------

func _make_chunk(
	id: StringName = &"test_chunk",
	size: Vector2i = Vector2i(15, 8),
	tile_size: int = 32
) -> LevelChunkDef:
	var c: LevelChunkDef = LevelChunkDefScript.new()
	c.id = id
	c.size_tiles = size
	c.tile_size_px = tile_size
	return c


func _make_spawn(pos: Vector2i, mob_id: StringName = &"grunt") -> MobSpawnPoint:
	var s: MobSpawnPoint = MobSpawnPointScript.new()
	s.position_tiles = pos
	s.mob_id = mob_id
	return s


func _make_port(pos: Vector2i, dir: int, tag: StringName = &"exit") -> ChunkPort:
	var p: ChunkPort = ChunkPortScript.new()
	p.position_tiles = pos
	p.direction = dir
	p.tag = tag
	return p


# Recording mob factory — returns a Node2D marker so we can inspect spawn
# arguments without coupling to Grunt.gd.
class RecordingFactory:
	extends RefCounted
	var calls: Array[Dictionary] = []
	func make(mob_id: StringName, world_pos: Vector2) -> Node:
		calls.append({"mob_id": mob_id, "world_pos": world_pos})
		var n: Node2D = Node2D.new()
		n.name = "FakeMob_%s" % mob_id
		return n


# ---- LevelChunkDef shape ---------------------------------------------

func test_size_px_is_size_tiles_times_tile_size() -> void:
	var c: LevelChunkDef = _make_chunk(&"sz", Vector2i(15, 8), 32)
	assert_eq(c.size_px(), Vector2i(480, 256), "15*32 x 8*32")


func test_contains_tile_inside_bounds() -> void:
	var c: LevelChunkDef = _make_chunk(&"ct", Vector2i(15, 8))
	assert_true(c.contains_tile(Vector2i(0, 0)))
	assert_true(c.contains_tile(Vector2i(14, 7)))
	assert_false(c.contains_tile(Vector2i(15, 7)), "x bound is exclusive")
	assert_false(c.contains_tile(Vector2i(0, 8)), "y bound is exclusive")
	assert_false(c.contains_tile(Vector2i(-1, 0)), "negative rejected")


func test_validate_passes_on_well_formed_chunk() -> void:
	var c: LevelChunkDef = _make_chunk(&"good")
	c.mob_spawns = [_make_spawn(Vector2i(5, 4))]
	c.ports = [_make_port(Vector2i(0, 4), ChunkPort.Direction.WEST, &"entry")]
	var errors: Array[String] = c.validate()
	assert_eq(errors.size(), 0, "well-formed chunk yields zero errors: %s" % str(errors))


func test_validate_catches_empty_id() -> void:
	var c: LevelChunkDef = _make_chunk(&"")
	var errors: Array[String] = c.validate()
	assert_gt(errors.size(), 0, "empty id should yield an error")


func test_validate_catches_out_of_bounds_spawn() -> void:
	var c: LevelChunkDef = _make_chunk(&"oob", Vector2i(10, 10))
	c.mob_spawns = [_make_spawn(Vector2i(20, 20))]  # outside 10x10
	var errors: Array[String] = c.validate()
	assert_gt(errors.size(), 0, "out-of-bounds spawn must error")


func test_validate_catches_empty_mob_id() -> void:
	var c: LevelChunkDef = _make_chunk(&"emp")
	c.mob_spawns = [_make_spawn(Vector2i(5, 5), &"")]
	var errors: Array[String] = c.validate()
	assert_gt(errors.size(), 0, "empty mob_id must error")


func test_validate_catches_out_of_bounds_port() -> void:
	var c: LevelChunkDef = _make_chunk(&"port_oob", Vector2i(10, 10))
	c.ports = [_make_port(Vector2i(99, 99), ChunkPort.Direction.NORTH)]
	var errors: Array[String] = c.validate()
	assert_gt(errors.size(), 0, "out-of-bounds port must error")


# ---- ChunkPort + tag helpers -----------------------------------------

func test_ports_with_tag_filters_correctly() -> void:
	var c: LevelChunkDef = _make_chunk(&"tag")
	c.ports = [
		_make_port(Vector2i(0, 4), ChunkPort.Direction.WEST, &"entry"),
		_make_port(Vector2i(14, 4), ChunkPort.Direction.EAST, &"exit"),
		_make_port(Vector2i(7, 0), ChunkPort.Direction.NORTH, &"exit"),
	]
	assert_eq(c.ports_with_tag(&"entry").size(), 1)
	assert_eq(c.ports_with_tag(&"exit").size(), 2)
	assert_eq(c.ports_with_tag(&"locked").size(), 0)


func test_get_entry_port_returns_first_entry() -> void:
	var c: LevelChunkDef = _make_chunk(&"ent")
	var entry: ChunkPort = _make_port(Vector2i(0, 4), ChunkPort.Direction.WEST, &"entry")
	c.ports = [entry]
	assert_eq(c.get_entry_port(), entry)


func test_get_entry_port_returns_null_when_none() -> void:
	var c: LevelChunkDef = _make_chunk(&"no_ent")
	c.ports = [_make_port(Vector2i(14, 4), ChunkPort.Direction.EAST, &"exit")]
	assert_null(c.get_entry_port())


# ---- LevelAssembler.assemble_single ----------------------------------

func test_assemble_single_returns_null_for_invalid_chunk() -> void:
	var asm: LevelAssembler = LevelAssemblerScript.new()
	# Empty id chunk fails validation.
	var bad: LevelChunkDef = _make_chunk(&"")
	var result: LevelAssembler.AssemblyResult = asm.assemble_single(bad, Callable())
	assert_null(result, "invalid chunk yields null result")


func test_assemble_single_returns_null_for_null_chunk() -> void:
	var asm: LevelAssembler = LevelAssemblerScript.new()
	var result: LevelAssembler.AssemblyResult = asm.assemble_single(null, Callable())
	assert_null(result)


func test_assemble_single_produces_root_node_and_bounds() -> void:
	var asm: LevelAssembler = LevelAssemblerScript.new()
	var c: LevelChunkDef = _make_chunk(&"mini", Vector2i(15, 8), 32)
	var result: LevelAssembler.AssemblyResult = asm.assemble_single(c, Callable())
	assert_not_null(result)
	assert_not_null(result.root, "assembly root must exist")
	assert_eq(result.bounds_px, Rect2(Vector2.ZERO, Vector2(480.0, 256.0)))
	assert_eq(result.chunk_def, c, "result carries chunk_def reference")
	# Free the constructed root so we don't leak.
	result.root.queue_free()


func test_assemble_single_calls_factory_for_each_spawn() -> void:
	var asm: LevelAssembler = LevelAssemblerScript.new()
	var c: LevelChunkDef = _make_chunk(&"factories")
	c.mob_spawns = [
		_make_spawn(Vector2i(3, 3), &"grunt"),
		_make_spawn(Vector2i(8, 5), &"grunt"),
	]
	var rec: RecordingFactory = RecordingFactory.new()
	var result: LevelAssembler.AssemblyResult = asm.assemble_single(c, Callable(rec, "make"))
	assert_not_null(result)
	assert_eq(rec.calls.size(), 2, "factory called once per spawn point")
	# Tile (3,3) at 32 px -> world centre (3*32+16, 3*32+16) = (112, 112).
	assert_almost_eq(rec.calls[0]["world_pos"].x, 112.0, 0.001)
	assert_almost_eq(rec.calls[0]["world_pos"].y, 112.0, 0.001)
	assert_eq(result.mobs.size(), 2)
	# Both mob nodes parented under root.
	assert_eq(result.mobs[0].get_parent(), result.root)
	result.root.queue_free()


func test_assemble_single_skips_when_factory_returns_null() -> void:
	var asm: LevelAssembler = LevelAssemblerScript.new()
	var c: LevelChunkDef = _make_chunk(&"null_factory")
	c.mob_spawns = [_make_spawn(Vector2i(3, 3), &"grunt")]
	var null_factory: Callable = func(_id: StringName, _pos: Vector2) -> Node:
		return null
	var result: LevelAssembler.AssemblyResult = asm.assemble_single(c, null_factory)
	assert_not_null(result)
	assert_eq(result.mobs.size(), 0, "null mobs are skipped, not crashed on")
	result.root.queue_free()


func test_assemble_single_uses_entry_port_for_world_pos() -> void:
	var asm: LevelAssembler = LevelAssemblerScript.new()
	var c: LevelChunkDef = _make_chunk(&"entry_pos", Vector2i(15, 8), 32)
	c.ports = [_make_port(Vector2i(2, 4), ChunkPort.Direction.WEST, &"entry")]
	var result: LevelAssembler.AssemblyResult = asm.assemble_single(c, Callable())
	# entry tile (2,4) at 32 px -> world centre (2*32+16, 4*32+16) = (80, 144).
	assert_almost_eq(result.entry_world_pos.x, 80.0, 0.001)
	assert_almost_eq(result.entry_world_pos.y, 144.0, 0.001)
	result.root.queue_free()


func test_assemble_single_falls_back_to_chunk_centre_without_entry_port() -> void:
	var asm: LevelAssembler = LevelAssemblerScript.new()
	var c: LevelChunkDef = _make_chunk(&"no_entry", Vector2i(10, 6), 32)
	var result: LevelAssembler.AssemblyResult = asm.assemble_single(c, Callable())
	# 10*32/2, 6*32/2 = 160, 96
	assert_almost_eq(result.entry_world_pos.x, 160.0, 0.001)
	assert_almost_eq(result.entry_world_pos.y, 96.0, 0.001)
	result.root.queue_free()


# ---- Authored s1_room01.tres round-trip ------------------------------

func test_authored_s1_room01_chunk_loads() -> void:
	var c: LevelChunkDef = load("res://resources/level_chunks/s1_room01.tres") as LevelChunkDef
	assert_not_null(c, "s1_room01.tres must load as LevelChunkDef")
	assert_eq(c.id, &"s1_room01")
	# Must validate cleanly per testing bar.
	var errors: Array[String] = c.validate()
	assert_eq(errors.size(), 0, "s1_room01 must validate: %s" % str(errors))
	# Must have at least one mob spawn (Stage 2b: a single PracticeDummy
	# tutorial entity per Uma's player-journey Beats 4-5).
	assert_gt(c.mob_spawns.size(), 0, "s1_room01 has at least one mob")
	# Must have an entry port.
	assert_not_null(c.get_entry_port(), "s1_room01 has an entry port")


func test_authored_s1_room01_uses_uma_canvas_constraints() -> void:
	# Per Uma's visual-direction.md (DECISIONS.md 2026-05-02):
	#   - 32 px internal tile size.
	#   - 480x270 internal canvas — chunks stay <= 480 wide and <= 270 tall.
	var c: LevelChunkDef = load("res://resources/level_chunks/s1_room01.tres") as LevelChunkDef
	assert_eq(c.tile_size_px, 32, "Uma's 32 px internal tile lock")
	var size_px: Vector2i = c.size_px()
	assert_lte(size_px.x, 480, "chunk width fits the 480 px logical canvas")
	assert_lte(size_px.y, 270, "chunk height fits the 270 px logical canvas")


func test_authored_s1_room01_spawns_practice_dummy_only() -> void:
	# Stage 2b (ticket `86c9qaj3u`): Room01 ships a single PracticeDummy
	# tutorial entity per Uma's player-journey Beats 4-5. The grunt fight
	# moved to Room02 onward. Any other mob_id in this chunk is a content
	# regression — practice_dummy is the only valid Room01 entity at M2 W1.
	var c: LevelChunkDef = load("res://resources/level_chunks/s1_room01.tres") as LevelChunkDef
	for ms: MobSpawnPoint in c.mob_spawns:
		assert_eq(ms.mob_id, &"practice_dummy",
			"Stage 2b: Room01 spawns only practice_dummy (was: grunt)")
