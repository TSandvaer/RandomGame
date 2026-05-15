extends GutTest
## Integration tests for Stratum-2 rooms 02..03 — verifies each room loads,
## assembles via `LevelAssembler`, spawns the right mob mix, and that the
## chunk graph carries the boss_door port handoff downstream of room 03.
##
## Mirrors the 17-test pattern from `tests/test_stratum1_rooms.gd` for the
## S1 rooms (load + assemble + spawn-count + port-validation + mob-mix per
## room). Paired with the W3-T1 dispatch creating
## `resources/level_chunks/s2_room0{2,3}.tres` +
## `scenes/levels/Stratum2Room0{2,3}.tscn`.
##
## Tess (W3-T2 acceptance plan) may extend this with stubs in
## `test_stratum2_rooms_v2.gd` — keep the file structure compatible.

const MultiMobRoomScript: Script = preload("res://scripts/levels/MultiMobRoom.gd")
const GruntScript: Script = preload("res://scripts/mobs/Grunt.gd")
const ChargerScript: Script = preload("res://scripts/mobs/Charger.gd")
const ShooterScript: Script = preload("res://scripts/mobs/Shooter.gd")

const ROOM_SCENES: Dictionary = {
	&"s2_room02": "res://scenes/levels/Stratum2Room02.tscn",
	&"s2_room03": "res://scenes/levels/Stratum2Room03.tscn",
}

const CHUNK_TRES: Dictionary = {
	&"s2_room02": "res://resources/level_chunks/s2_room02.tres",
	&"s2_room03": "res://resources/level_chunks/s2_room03.tres",
}

# Authoritative expected mob counts — keep in sync with the .tres files.
const EXPECTED_MOB_COUNTS: Dictionary = {
	&"s2_room02": 3,  # 2 Stokers + 1 Charger
	&"s2_room03": 3,  # 1 Stoker + 1 Charger + 1 Shooter
}


# ---- Helpers ---------------------------------------------------------

func _load_room(scene_path: String) -> MultiMobRoom:
	var packed: PackedScene = load(scene_path)
	assert_not_null(packed, "scene must load: %s" % scene_path)
	var room: MultiMobRoom = packed.instantiate()
	add_child_autofree(room)
	return room


## Same as `_load_room` but also drains process frames so the deferred
## `_assemble_room_fixtures` pass (RoomGate + HealingFountain spawn + gate
## registration — ticket 86c9tqvxx) has run. Use this when the test needs
## to inspect `get_room_gate()`; `_load_room` alone is sufficient for
## `get_spawned_mobs()` (populated synchronously in `_ready` by `_build`).
func _load_room_with_fixtures(scene_path: String) -> MultiMobRoom:
	var room: MultiMobRoom = _load_room(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	return room


# ---- 1. Each room loads cleanly -------------------------------------

func test_room02_scene_loads() -> void:
	var room: MultiMobRoom = _load_room(ROOM_SCENES[&"s2_room02"])
	assert_not_null(room.chunk_def, "chunk_def assigned")
	assert_eq(room.chunk_def.id, &"s2_room02")
	assert_not_null(room.get_assembly(), "assembled on _ready")


func test_room03_scene_loads() -> void:
	var room: MultiMobRoom = _load_room(ROOM_SCENES[&"s2_room03"])
	assert_eq(room.chunk_def.id, &"s2_room03")
	assert_not_null(room.get_assembly())


# ---- 2. Mob spawn counts populate correctly per LevelChunkDef -------

func test_each_room_spawn_count_matches_chunk_def() -> void:
	for room_id: StringName in ROOM_SCENES.keys():
		var room: MultiMobRoom = _load_room(ROOM_SCENES[room_id])
		var expected: int = int(EXPECTED_MOB_COUNTS[room_id])
		var actual: int = room.get_spawned_mobs().size()
		assert_eq(actual, expected, "%s mob count" % String(room_id))
		assert_eq(room.chunk_def.mob_spawns.size(), expected, "%s chunk_def mob_spawns" % String(room_id))


func test_room02_spawns_two_stokers_and_one_charger() -> void:
	# Stokers are heat-blasted Grunt variants (W3-T3 retint pass — same
	# class, different sprite). Until W3-T3 lands, mob_id stays `&"grunt"`
	# and the spawned class is Grunt.
	var room: MultiMobRoom = _load_room(ROOM_SCENES[&"s2_room02"])
	var mobs: Array[Node] = room.get_spawned_mobs()
	assert_eq(mobs.size(), 3)
	var grunt_count: int = 0
	var charger_count: int = 0
	for m: Node in mobs:
		if m is Grunt:
			grunt_count += 1
		elif m is Charger:
			charger_count += 1
	assert_eq(grunt_count, 2, "room02 has 2 Stokers (Grunt class)")
	assert_eq(charger_count, 1, "room02 has 1 Charger")


func test_room03_mixes_stoker_charger_shooter() -> void:
	var room: MultiMobRoom = _load_room(ROOM_SCENES[&"s2_room03"])
	var mobs: Array[Node] = room.get_spawned_mobs()
	assert_eq(mobs.size(), 3)
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
	assert_eq(grunt_count, 1, "room03 has 1 Stoker (Grunt class)")
	assert_eq(charger_count, 1, "room03 has 1 Charger")
	assert_eq(shooter_count, 1, "room03 has 1 Shooter")


# ---- 2b. RoomGate registration -------------------------------------

func test_each_room_gate_registers_full_mob_roster() -> void:
	# Mirrors test_stratum1_rooms.gd::test_all_gated_rooms_register_full_mob_roster
	# — every spawned mob must end up registered with the RoomGate so the
	# gate's mobs_alive() == spawned mob count after the deferred pass.
	for room_id: StringName in ROOM_SCENES.keys():
		var room: MultiMobRoom = await _load_room_with_fixtures(ROOM_SCENES[room_id])
		var gate: RoomGate = room.get_room_gate()
		assert_not_null(gate, "%s spawns a RoomGate" % String(room_id))
		var expected: int = int(EXPECTED_MOB_COUNTS[room_id])
		assert_eq(gate.mobs_alive(), expected,
			"%s gate registered all %d spawned mobs" % [String(room_id), expected])


# ---- 3. Chunk validation + canvas constraints -----------------------

func test_each_chunk_def_validates_cleanly() -> void:
	for room_id: StringName in CHUNK_TRES.keys():
		var c: LevelChunkDef = load(CHUNK_TRES[room_id]) as LevelChunkDef
		assert_not_null(c, "chunk loads: %s" % String(room_id))
		var errors: Array[String] = c.validate()
		assert_eq(errors.size(), 0, "%s chunk validates: %s" % [String(room_id), str(errors)])


func test_each_chunk_uses_uma_canvas_constraints() -> void:
	# 480x270 internal canvas (15x8.4 tiles at 32 px). All S2 chunks must
	# fit one screen — no scrolling in M2 W3 yet.
	for room_id: StringName in CHUNK_TRES.keys():
		var c: LevelChunkDef = load(CHUNK_TRES[room_id]) as LevelChunkDef
		assert_eq(c.tile_size_px, 32, "%s 32 px tile lock" % String(room_id))
		var size_px: Vector2i = c.size_px()
		assert_lte(size_px.x, 480, "%s width fits 480" % String(room_id))
		assert_lte(size_px.y, 270, "%s height fits 270" % String(room_id))


func test_mobs_positioned_inside_bounds() -> void:
	for room_id: StringName in ROOM_SCENES.keys():
		var room: MultiMobRoom = _load_room(ROOM_SCENES[room_id])
		var bounds: Rect2 = room.get_bounds_px()
		for m: Node in room.get_spawned_mobs():
			var n: Node2D = m
			assert_true(bounds.has_point(n.position),
				"%s mob at %s inside bounds %s" % [String(room_id), str(n.position), str(bounds)])


# ---- 4. Port validation: WEST entry / EAST exit + boss_door handoff -

func test_room_chain_has_continuous_ports() -> void:
	# Both S2 rooms must have a WEST entry. Room02 has a generic EAST exit;
	# Room03 has the boss_door tagged EAST exit (downstream W3-T4 picks up).
	for room_id: StringName in CHUNK_TRES.keys():
		var c: LevelChunkDef = load(CHUNK_TRES[room_id]) as LevelChunkDef
		assert_not_null(c.get_entry_port(), "%s has an entry port" % String(room_id))
		var non_entry: int = 0
		for p: ChunkPort in c.ports:
			if p.tag != &"entry":
				non_entry += 1
		assert_gt(non_entry, 0, "%s has at least one outgoing port" % String(room_id))


func test_room03_terminal_port_is_boss_door() -> void:
	# Final S2 pre-boss room must mark its EAST exit with `boss_door` so the
	# downstream W3-T4 boss-room handoff picks it up. Mirrors
	# test_stratum1_rooms.gd::test_room08_terminal_port_is_boss_door.
	var c: LevelChunkDef = load(CHUNK_TRES[&"s2_room03"]) as LevelChunkDef
	var boss_doors: Array[ChunkPort] = c.ports_with_tag(&"boss_door")
	assert_gt(boss_doors.size(), 0, "s2_room03 has at least one boss_door tagged port")


func test_entry_and_exit_ports_align_along_main_axis() -> void:
	# Sanity: entries on WEST edge, exits/boss-doors on EAST edge — same
	# left-to-right traversal axis as S1.
	for room_id: StringName in CHUNK_TRES.keys():
		var c: LevelChunkDef = load(CHUNK_TRES[room_id]) as LevelChunkDef
		for p: ChunkPort in c.ports:
			if p.tag == &"entry":
				assert_eq(p.direction, ChunkPort.Direction.WEST,
					"%s entry on WEST edge" % String(room_id))
			elif p.tag == &"exit" or p.tag == &"boss_door":
				assert_eq(p.direction, ChunkPort.Direction.EAST,
					"%s outgoing port on EAST edge" % String(room_id))


# ---- 5. Mob archetype mix -------------------------------------------

func test_mob_archetypes_used_across_stratum() -> void:
	# All three M1 archetypes (grunt/Stoker, charger, shooter) appear
	# somewhere in S2 W3 R02-R03. Tightens the mob-mix variety SLA.
	var seen_ids: Dictionary = {}
	for room_id: StringName in CHUNK_TRES.keys():
		var c: LevelChunkDef = load(CHUNK_TRES[room_id]) as LevelChunkDef
		for ms: MobSpawnPoint in c.mob_spawns:
			seen_ids[ms.mob_id] = true
	assert_true(seen_ids.has(&"grunt"), "Stoker (grunt class) used in stratum 2")
	assert_true(seen_ids.has(&"charger"), "Charger used in stratum 2")
	assert_true(seen_ids.has(&"shooter"), "Shooter used in stratum 2")


# ---- 6. Stratum namespace round-trip --------------------------------

func test_chunk_ids_round_trip_through_stratum_namespace() -> void:
	# Pin the contract that Stratum.id_from_chunk_id parses our s2_* chunk
	# ids correctly. If a future namespace edit breaks this, S2 saves /
	# stratum-aware loot scaling silently regress.
	for room_id: StringName in CHUNK_TRES.keys():
		var sid: int = Stratum.id_from_chunk_id(room_id)
		assert_eq(sid, Stratum.Id.S2,
			"%s parses to Stratum.Id.S2 (got %d)" % [String(room_id), sid])


# ---- 7. Total mob count + difficulty curve -------------------------

func test_total_mob_count_in_reasonable_bounds() -> void:
	# 6 total mobs across S2 R02-R03 (3+3). Pin the band so a future
	# content edit doesn't accidentally spike or zero the curve.
	var total: int = 0
	for room_id: StringName in CHUNK_TRES.keys():
		var c: LevelChunkDef = load(CHUNK_TRES[room_id]) as LevelChunkDef
		total += c.mob_spawns.size()
	assert_gte(total, 4, "S2 W3 R02-R03 mob count >= 4 floor")
	assert_lte(total, 12, "S2 W3 R02-R03 mob count <= 12 ceiling")


# ---- 8. Re-entry cleanliness (edge probe) -------------------------

func test_room_reentered_after_free_reregisters_cleanly() -> void:
	# Edge probe (per testing bar): a room re-entered after being cleared.
	# Production frees the old room node and instantiates a fresh one on
	# re-entry (Main._load_room_at_index queue_frees the prior room). The
	# fresh instance must run its own deferred fixture pass and register
	# its own mob roster from scratch — no stale state. Mirrors
	# test_stratum1_rooms.gd::test_room_reentered_after_free_reregisters_cleanly.
	var first: MultiMobRoom = await _load_room_with_fixtures(ROOM_SCENES[&"s2_room02"])
	var expected: int = int(EXPECTED_MOB_COUNTS[&"s2_room02"])
	assert_eq(first.get_room_gate().mobs_alive(), expected,
		"first Room02 instance registered %d mobs" % expected)
	first.queue_free()
	await get_tree().process_frame

	var second: MultiMobRoom = await _load_room_with_fixtures(ROOM_SCENES[&"s2_room02"])
	var gate2: RoomGate = second.get_room_gate()
	assert_not_null(gate2, "re-entered Room02 spawns its own fresh RoomGate")
	assert_eq(gate2.mobs_alive(), expected,
		"re-entered Room02 instance registered its own %d mobs cleanly (no stale state)" % expected)


func test_room03_mixed_roster_gate_registers_all_archetypes() -> void:
	# Edge probe: Room03's roster is a MIXED-archetype set (grunt + charger
	# + shooter). All three archetypes emit `mob_died` and must be tracked
	# by the gate equally — a type-specific registration bug would surface
	# as a short count here. Mirrors
	# test_stratum1_rooms.gd::test_room08_gate_registers_mixed_mob_types.
	var room: MultiMobRoom = await _load_room_with_fixtures(ROOM_SCENES[&"s2_room03"])
	var gate: RoomGate = room.get_room_gate()
	assert_not_null(gate, "Room03 spawns a RoomGate")

	var mobs: Array[Node] = room.get_spawned_mobs()
	assert_eq(mobs.size(), 3, "Room03 spawned its 3 mixed mobs")
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
	assert_eq(grunt_count, 1, "Room03 roster includes 1 Stoker")
	assert_eq(charger_count, 1, "Room03 roster includes 1 Charger")
	assert_eq(shooter_count, 1, "Room03 roster includes 1 Shooter")
	assert_eq(gate.mobs_alive(), 3,
		"RoomGate tracked all 3 mixed-archetype mobs (grunt + charger + shooter)")
