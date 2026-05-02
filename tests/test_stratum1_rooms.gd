extends GutTest
## Integration tests for Stratum-1 rooms 02..08 — verifies each room loads,
## assembles via `LevelAssembler`, spawns the right mob mix, and that the
## chunk graph stitches Room 1 -> Room 8 with continuous ports.
##
## Paired with `scripts/levels/Stratum1MultiMobRoom.gd` and the seven
## `resources/level_chunks/s1_room0N.tres` files. Per testing-bar §integration
## check.

const Stratum1MultiMobRoomScript: Script = preload("res://scripts/levels/Stratum1MultiMobRoom.gd")
const GruntScript: Script = preload("res://scripts/mobs/Grunt.gd")
const ChargerScript: Script = preload("res://scripts/mobs/Charger.gd")
const ShooterScript: Script = preload("res://scripts/mobs/Shooter.gd")

const ROOM_SCENES: Dictionary = {
	&"s1_room02": "res://scenes/levels/Stratum1Room02.tscn",
	&"s1_room03": "res://scenes/levels/Stratum1Room03.tscn",
	&"s1_room04": "res://scenes/levels/Stratum1Room04.tscn",
	&"s1_room05": "res://scenes/levels/Stratum1Room05.tscn",
	&"s1_room06": "res://scenes/levels/Stratum1Room06.tscn",
	&"s1_room07": "res://scenes/levels/Stratum1Room07.tscn",
	&"s1_room08": "res://scenes/levels/Stratum1Room08.tscn",
}

const CHUNK_TRES: Dictionary = {
	&"s1_room02": "res://resources/level_chunks/s1_room02.tres",
	&"s1_room03": "res://resources/level_chunks/s1_room03.tres",
	&"s1_room04": "res://resources/level_chunks/s1_room04.tres",
	&"s1_room05": "res://resources/level_chunks/s1_room05.tres",
	&"s1_room06": "res://resources/level_chunks/s1_room06.tres",
	&"s1_room07": "res://resources/level_chunks/s1_room07.tres",
	&"s1_room08": "res://resources/level_chunks/s1_room08.tres",
}

# Authoritative expected mob counts — keep in sync with the .tres files.
const EXPECTED_MOB_COUNTS: Dictionary = {
	&"s1_room02": 2,
	&"s1_room03": 2,
	&"s1_room04": 1,
	&"s1_room05": 3,
	&"s1_room06": 3,
	&"s1_room07": 4,
	&"s1_room08": 4,
}


# ---- Helpers ---------------------------------------------------------

func _load_room(scene_path: String) -> Stratum1MultiMobRoom:
	var packed: PackedScene = load(scene_path)
	assert_not_null(packed, "scene must load: %s" % scene_path)
	var room: Stratum1MultiMobRoom = packed.instantiate()
	add_child_autofree(room)
	return room


# ---- 1. Each room loads cleanly -------------------------------------

func test_room02_scene_loads() -> void:
	var room: Stratum1MultiMobRoom = _load_room(ROOM_SCENES[&"s1_room02"])
	assert_not_null(room.chunk_def, "chunk_def assigned")
	assert_eq(room.chunk_def.id, &"s1_room02")
	assert_not_null(room.get_assembly(), "assembled on _ready")


func test_room03_scene_loads() -> void:
	var room: Stratum1MultiMobRoom = _load_room(ROOM_SCENES[&"s1_room03"])
	assert_eq(room.chunk_def.id, &"s1_room03")
	assert_not_null(room.get_assembly())


func test_room04_scene_loads() -> void:
	var room: Stratum1MultiMobRoom = _load_room(ROOM_SCENES[&"s1_room04"])
	assert_eq(room.chunk_def.id, &"s1_room04")
	assert_not_null(room.get_assembly())


func test_room05_scene_loads() -> void:
	var room: Stratum1MultiMobRoom = _load_room(ROOM_SCENES[&"s1_room05"])
	assert_eq(room.chunk_def.id, &"s1_room05")
	assert_not_null(room.get_assembly())


func test_room06_scene_loads() -> void:
	var room: Stratum1MultiMobRoom = _load_room(ROOM_SCENES[&"s1_room06"])
	assert_eq(room.chunk_def.id, &"s1_room06")
	assert_not_null(room.get_assembly())


func test_room07_scene_loads() -> void:
	var room: Stratum1MultiMobRoom = _load_room(ROOM_SCENES[&"s1_room07"])
	assert_eq(room.chunk_def.id, &"s1_room07")
	assert_not_null(room.get_assembly())


func test_room08_scene_loads() -> void:
	var room: Stratum1MultiMobRoom = _load_room(ROOM_SCENES[&"s1_room08"])
	assert_eq(room.chunk_def.id, &"s1_room08")
	assert_not_null(room.get_assembly())


# ---- 2. Mob spawn points populate correctly per LevelChunkDef -------

func test_each_room_spawn_count_matches_chunk_def() -> void:
	for room_id: StringName in ROOM_SCENES.keys():
		var room: Stratum1MultiMobRoom = _load_room(ROOM_SCENES[room_id])
		var expected: int = int(EXPECTED_MOB_COUNTS[room_id])
		var actual: int = room.get_spawned_mobs().size()
		assert_eq(actual, expected, "%s mob count" % String(room_id))
		# Cross-check: chunk_def.mob_spawns.size() also matches.
		assert_eq(room.chunk_def.mob_spawns.size(), expected, "%s chunk_def mob_spawns" % String(room_id))


func test_room02_spawns_two_grunts() -> void:
	var room: Stratum1MultiMobRoom = _load_room(ROOM_SCENES[&"s1_room02"])
	var mobs: Array[Node] = room.get_spawned_mobs()
	assert_eq(mobs.size(), 2)
	for m: Node in mobs:
		assert_true(m is Grunt, "room02 spawns Grunts only")


func test_room03_mixes_grunt_and_charger() -> void:
	var room: Stratum1MultiMobRoom = _load_room(ROOM_SCENES[&"s1_room03"])
	var mobs: Array[Node] = room.get_spawned_mobs()
	assert_eq(mobs.size(), 2)
	var has_grunt: bool = false
	var has_charger: bool = false
	for m: Node in mobs:
		if m is Grunt:
			has_grunt = true
		elif m is Charger:
			has_charger = true
	assert_true(has_grunt, "room03 includes a Grunt")
	assert_true(has_charger, "room03 includes a Charger")


func test_room04_is_lone_shooter() -> void:
	var room: Stratum1MultiMobRoom = _load_room(ROOM_SCENES[&"s1_room04"])
	var mobs: Array[Node] = room.get_spawned_mobs()
	assert_eq(mobs.size(), 1)
	assert_true(mobs[0] is Shooter, "room04 is a single-shooter intro")


func test_room06_includes_healing_fountain() -> void:
	var room: Stratum1MultiMobRoom = _load_room(ROOM_SCENES[&"s1_room06"])
	assert_not_null(room.get_healing_fountain(), "room06 places a healing fountain (mid-stratum reward)")


func test_room08_pre_boss_density() -> void:
	# Final pre-boss arena: 1 grunt + 1 charger + 2 shooters = 4 total per spec.
	var room: Stratum1MultiMobRoom = _load_room(ROOM_SCENES[&"s1_room08"])
	var mobs: Array[Node] = room.get_spawned_mobs()
	assert_eq(mobs.size(), 4)
	var grunt_count: int = 0
	var charger_count: int = 0
	var shooter_count: int = 0
	for m: Node in mobs:
		if m is Grunt:
			grunt_count += 1
		elif m is Charger:
			charger_count += 1
		elif m is Shooter:
			shooter_count += 1
	assert_eq(grunt_count, 1, "room08 has exactly 1 grunt")
	assert_eq(charger_count, 1, "room08 has exactly 1 charger")
	assert_eq(shooter_count, 2, "room08 has exactly 2 shooters")


func test_each_chunk_def_validates_cleanly() -> void:
	for room_id: StringName in CHUNK_TRES.keys():
		var c: LevelChunkDef = load(CHUNK_TRES[room_id]) as LevelChunkDef
		assert_not_null(c, "chunk loads: %s" % String(room_id))
		var errors: Array[String] = c.validate()
		assert_eq(errors.size(), 0, "%s chunk validates: %s" % [String(room_id), str(errors)])


func test_each_chunk_uses_uma_canvas_constraints() -> void:
	for room_id: StringName in CHUNK_TRES.keys():
		var c: LevelChunkDef = load(CHUNK_TRES[room_id]) as LevelChunkDef
		assert_eq(c.tile_size_px, 32, "%s 32 px tile lock" % String(room_id))
		var size_px: Vector2i = c.size_px()
		assert_lte(size_px.x, 480, "%s width fits 480" % String(room_id))
		assert_lte(size_px.y, 270, "%s height fits 270" % String(room_id))


func test_mobs_positioned_inside_bounds() -> void:
	for room_id: StringName in ROOM_SCENES.keys():
		var room: Stratum1MultiMobRoom = _load_room(ROOM_SCENES[room_id])
		var bounds: Rect2 = room.get_bounds_px()
		for m: Node in room.get_spawned_mobs():
			var n: Node2D = m
			assert_true(bounds.has_point(n.position),
				"%s mob at %s inside bounds %s" % [String(room_id), str(n.position), str(bounds)])


# ---- 3. Total mob count across rooms 2-8 within bounds --------------

func test_total_mob_count_in_reasonable_bounds() -> void:
	# Per dispatch: 14-30 mobs total across rooms 2-8. Authored count is
	# 19 which fits comfortably. This test pins the upper+lower bands so
	# a future content edit doesn't accidentally spike or zero the curve.
	var total: int = 0
	for room_id: StringName in CHUNK_TRES.keys():
		var c: LevelChunkDef = load(CHUNK_TRES[room_id]) as LevelChunkDef
		total += c.mob_spawns.size()
	assert_gte(total, 14, "total mob count >= 14 (room curve floor)")
	assert_lte(total, 30, "total mob count <= 30 (room curve ceiling)")


func test_difficulty_curve_roughly_increases() -> void:
	# Per dispatch difficulty guidance, mob-count by room is roughly:
	#   r02=2, r03=2, r04=1 (intro shooter), r05=3, r06=3, r07=4, r08=4.
	# The tail (rooms 5-8) must be >= the head (rooms 2-4). This is a soft
	# lint, not an exact-equals — content authors are free to tweak so long
	# as the second half doesn't end up *easier* than the first.
	var head: int = 0
	for rid: StringName in [&"s1_room02", &"s1_room03", &"s1_room04"]:
		head += int(EXPECTED_MOB_COUNTS[rid])
	var tail: int = 0
	for rid: StringName in [&"s1_room05", &"s1_room06", &"s1_room07", &"s1_room08"]:
		tail += int(EXPECTED_MOB_COUNTS[rid])
	assert_gt(tail, head, "rooms 5-8 (tail) must be denser than rooms 2-4 (head)")


# ---- 4. Connectivity: Room 1 -> ... -> Room 8 has continuous ports --

func test_room_chain_has_continuous_ports() -> void:
	# Each room (except r01 which is the entry-only chunk) must have an
	# entry port to receive the player from the previous room AND an exit
	# port to hand off to the next. r08's exit is the boss-room handoff
	# (`boss_door` tag) — the boss room itself has its own door trigger.
	#
	# Full chain: r01 (entry only) -> r02 -> r03 -> r04 -> r05 -> r06
	#          -> r07 -> r08 (exit tag = boss_door) -> Stratum1BossRoom.
	#
	# We verify each chunk has the right port shape; physical assembly
	# (placing rooms next to each other in world space) is M2 — for now
	# the existence of the ports is the contract.
	var chain: Array[StringName] = [&"s1_room02", &"s1_room03", &"s1_room04", &"s1_room05",
		&"s1_room06", &"s1_room07", &"s1_room08"]
	for room_id: StringName in chain:
		var c: LevelChunkDef = load(CHUNK_TRES[room_id]) as LevelChunkDef
		assert_not_null(c.get_entry_port(), "%s has an entry port" % String(room_id))
		# Exit (rooms 2-7) or boss_door (room 8) — at least one non-entry port.
		var non_entry: int = 0
		for p: ChunkPort in c.ports:
			if p.tag != &"entry":
				non_entry += 1
		assert_gt(non_entry, 0, "%s has at least one outgoing port" % String(room_id))


func test_room08_terminal_port_is_boss_door() -> void:
	# Final room before the boss arena must mark its exit with the
	# `boss_door` tag so the level-flow controller knows to swap to
	# Stratum1BossRoom.tscn rather than another generic room scene.
	var c: LevelChunkDef = load(CHUNK_TRES[&"s1_room08"]) as LevelChunkDef
	var boss_doors: Array[ChunkPort] = c.ports_with_tag(&"boss_door")
	assert_gt(boss_doors.size(), 0, "room08 has at least one boss_door tagged port")


func test_entry_and_exit_ports_align_along_main_axis() -> void:
	# Sanity: entries on west edge, exits/boss-doors on east edge — that's
	# the M1 left-to-right traversal axis. If a future content author moves
	# a port to north/south for puzzle reasons, this test will fail loudly
	# and force a discussion (probably worth bumping to a "main axis" tag).
	var chain: Array[StringName] = [&"s1_room02", &"s1_room03", &"s1_room04", &"s1_room05",
		&"s1_room06", &"s1_room07", &"s1_room08"]
	for room_id: StringName in chain:
		var c: LevelChunkDef = load(CHUNK_TRES[room_id]) as LevelChunkDef
		for p: ChunkPort in c.ports:
			if p.tag == &"entry":
				assert_eq(p.direction, ChunkPort.Direction.WEST,
					"%s entry on WEST edge" % String(room_id))
			elif p.tag == &"exit" or p.tag == &"boss_door":
				assert_eq(p.direction, ChunkPort.Direction.EAST,
					"%s outgoing port on EAST edge" % String(room_id))


# ---- Mob archetype mix -------------------------------------------

func test_mob_archetypes_used_across_stratum() -> void:
	# Sponsor wants varied mob mixes — this test pins that all three
	# archetypes (grunt + charger + shooter) appear somewhere in rooms 2-8.
	var seen_ids: Dictionary = {}
	for room_id: StringName in CHUNK_TRES.keys():
		var c: LevelChunkDef = load(CHUNK_TRES[room_id]) as LevelChunkDef
		for ms: MobSpawnPoint in c.mob_spawns:
			seen_ids[ms.mob_id] = true
	assert_true(seen_ids.has(&"grunt"), "grunt archetype used in stratum 1")
	assert_true(seen_ids.has(&"charger"), "charger archetype used in stratum 1")
	assert_true(seen_ids.has(&"shooter"), "shooter archetype used in stratum 1")
