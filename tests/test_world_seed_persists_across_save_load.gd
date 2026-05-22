extends GutTest
## Per-character `world_seed` save/load round-trip — M3 Tier 3 W1 procgen
## spike Part B (ticket `86c9xub9p`).
##
## **Bug class this catches:** any future refactor that drops `world_seed`
## from the save schema, fails to roll it on new-character creation, or
## fails to deep-copy it through the save round-trip would silently break
## `FloorAssembler.derive_zone_seed(world_seed, ...)` — every character
## would assemble against the migration sentinel `0` and see the same
## "boring" map. The user-visible symptom would be invisible (the map
## still renders), but the Diablo-shape per-character-variance promise
## (per `m3-diablo-shape-directive` memory) would silently regress.
##
## **Coverage shape:**
##   1. Fresh `default_payload()` rolls a non-zero `world_seed`.
##   2. Save + load + re-save + load round-trip preserves the seed
##      bit-identically (no float drift, no string-coercion drift).
##   3. Two consecutive `default_payload()` calls roll DIFFERENT seeds
##      (sanity check on the RNG — if randi() returned a constant, the
##      Diablo-shape variance is silently dead).
##   4. The `_migrate_v3_to_v4` back-fill lands `world_seed=0` on a
##      hand-authored v3 fixture, and the post-migration value is
##      stable through subsequent save/load cycles.
##   5. **The brief's invariant** — same world_seed → same
##      `AssembledFloor` output across the save round-trip. Exercises the
##      whole pipeline end-to-end:
##        roll → save → reload → FloorAssembler.assemble_floor(...) ==
##        original FloorAssembler.assemble_floor(...).
##
## Cross-references:
##   tests/test_save.gd               — sibling save-schema round-trip tests
##   tests/test_floor_assembler.gd    — Part A's determinism pins
##   scripts/save/Save.gd             — DEFAULT_PAYLOAD + _migrate_v3_to_v4
##   scripts/levels/FloorAssembler.gd — consumer of world_seed via derive_zone_seed
##   team/devon-dev/save-schema-v5-plan.md — additive doctrine source

const TEST_SLOT: int = 998
const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")
const FloorAssemblerScript: Script = preload("res://scripts/levels/FloorAssembler.gd")
const AssembledFloorScript: Script = preload("res://resources/level/AssembledFloor.gd")
const ZoneDefScript: Script = preload("res://resources/level/ZoneDef.gd")
const ZoneAnchorScript: Script = preload("res://resources/level/ZoneAnchor.gd")
const LevelChunkDefScript: Script = preload("res://scripts/levels/LevelChunkDef.gd")
const ChunkPortScript: Script = preload("res://scripts/levels/ChunkPort.gd")


var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()
	if _save().has_save(TEST_SLOT):
		_save().delete_save(TEST_SLOT)
	var tmp: String = _save().save_path(TEST_SLOT) + ".tmp"
	if FileAccess.file_exists(tmp):
		DirAccess.remove_absolute(tmp)


func after_each() -> void:
	if _save().has_save(TEST_SLOT):
		_save().delete_save(TEST_SLOT)
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


func _save() -> Node:
	var save: Node = Engine.get_main_loop().root.get_node_or_null("Save")
	assert_not_null(save, "Save autoload must be registered")
	return save


# -----------------------------------------------------------------------
# Coverage 1 — default_payload() rolls a non-zero world_seed
# -----------------------------------------------------------------------


func test_default_payload_rolls_non_zero_world_seed() -> void:
	var payload: Dictionary = _save().default_payload()
	assert_true(payload["character"].has("world_seed"),
		"default character payload includes world_seed field")
	# randi() returns [0, 2^32); probability of hitting exactly 0 is 1/2^32.
	# Treating this as a contract: a new character's seed is non-zero.
	assert_ne(int(payload["character"]["world_seed"]), 0,
		"default_payload() rolls a non-zero world_seed (sentinel `0` is migration-only)")


# -----------------------------------------------------------------------
# Coverage 2 — round-trip preserves the seed
# -----------------------------------------------------------------------


func test_world_seed_persists_through_save_load_round_trip() -> void:
	var original: Dictionary = _save().default_payload()
	var seed_before: int = int(original["character"]["world_seed"])
	assert_ne(seed_before, 0, "preflight: rolled seed is non-zero")

	# Save and reload.
	assert_true(_save().save_game(TEST_SLOT, original),
		"save_game succeeds with rolled-seed payload")
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_false(loaded.is_empty(), "loaded payload is non-empty")
	assert_true(loaded["character"].has("world_seed"),
		"loaded character payload preserves world_seed key")
	assert_eq(int(loaded["character"]["world_seed"]), seed_before,
		"world_seed round-trips bit-identically through save → load")


func test_world_seed_persists_through_double_round_trip() -> void:
	# Save → load → save again → load again. Catches drift introduced
	# during the second save (e.g. a re-roll regression on save_game).
	var original: Dictionary = _save().default_payload()
	var seed_before: int = int(original["character"]["world_seed"])

	assert_true(_save().save_game(TEST_SLOT, original))
	var loaded_once: Dictionary = _save().load_game(TEST_SLOT)
	assert_eq(int(loaded_once["character"]["world_seed"]), seed_before,
		"world_seed survives first round-trip")

	assert_true(_save().save_game(TEST_SLOT, loaded_once))
	var loaded_twice: Dictionary = _save().load_game(TEST_SLOT)
	assert_eq(int(loaded_twice["character"]["world_seed"]), seed_before,
		"world_seed survives second round-trip (idempotent on re-save)")


# -----------------------------------------------------------------------
# Coverage 3 — two consecutive default_payload() rolls differ
# -----------------------------------------------------------------------


func test_two_consecutive_default_payloads_roll_different_world_seeds() -> void:
	# If randi() returned a constant (RNG mis-seed regression), the
	# Diablo-shape per-character-variance promise silently dies — every
	# character would see the same map. This assertion is the canary.
	#
	# Tiny false-positive risk: probability of two randi() calls returning
	# identical 32-bit values is ~2^-32 ≈ 2e-10. Negligible across thousands
	# of CI runs. If this ever fails legitimately, run twice — the second
	# run will pass.
	var a: Dictionary = _save().default_payload()
	var b: Dictionary = _save().default_payload()
	assert_ne(int(a["character"]["world_seed"]), int(b["character"]["world_seed"]),
		"two consecutive default_payload() calls roll different world_seeds")


# -----------------------------------------------------------------------
# Coverage 4 — _migrate_v3_to_v4 back-fills world_seed to 0
# -----------------------------------------------------------------------


func test_v3_migration_backfills_world_seed_to_zero_sentinel() -> void:
	# Hand-author a v3 save (no world_seed, no first_boss_kill_seen).
	var v3_envelope: Dictionary = {
		"schema_version": 3,
		"saved_at": "2026-05-02T10:00:00",
		"data": {
			"character": {
				"name": "Ember-Knight",
				"level": 2,
				"xp": 100,
				"xp_to_next": 282,
				"vigor": 0, "focus": 0, "edge": 0,
				"stats": {"vigor": 0, "focus": 0, "edge": 0},
				"unspent_stat_points": 0,
				"first_level_up_seen": false,
				"hp_current": 100, "hp_max": 100,
			},
			"stash": [],
			"equipped": {},
			"meta": {"runs_completed": 0, "deepest_stratum": 1, "total_playtime_sec": 0.0},
		},
	}
	var f: FileAccess = FileAccess.open(_save().save_path(TEST_SLOT), FileAccess.WRITE)
	f.store_string(JSON.stringify(v3_envelope))
	f.close()

	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_true(loaded["character"].has("world_seed"),
		"v3 → v4 migration backfills character.world_seed")
	assert_eq(int(loaded["character"]["world_seed"]), 0,
		"backfill default is 0 (sentinel — fresh new-character flow re-rolls)")
	# Subsequent save/load preserves the sentinel.
	assert_true(_save().save_game(TEST_SLOT, loaded))
	var reloaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_eq(int(reloaded["character"]["world_seed"]), 0,
		"world_seed sentinel stable across re-save (no random re-roll on existing characters)")


func test_v3_migration_preserves_non_default_character_fields() -> void:
	# Belt-and-suspenders: confirm the v3→v4 chain doesn't stomp the
	# character's other fields when adding world_seed.
	var v3_envelope: Dictionary = {
		"schema_version": 3,
		"saved_at": "2026-05-02T10:00:00",
		"data": {
			"character": {
				"name": "Devon-Test",
				"level": 4,
				"xp": 999,
				"xp_to_next": 800,
				"vigor": 3, "focus": 1, "edge": 2,
				"stats": {"vigor": 3, "focus": 1, "edge": 2},
				"unspent_stat_points": 1,
				"first_level_up_seen": true,
				"hp_current": 75, "hp_max": 100,
			},
			"stash": [{"id": "weapon_iron_sword", "tier": 2, "rolled_affixes": [], "stack_count": 1}],
			"equipped": {},
			"meta": {"runs_completed": 3, "deepest_stratum": 2, "total_playtime_sec": 1234.5},
		},
	}
	var f: FileAccess = FileAccess.open(_save().save_path(TEST_SLOT), FileAccess.WRITE)
	f.store_string(JSON.stringify(v3_envelope))
	f.close()

	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	# world_seed added.
	assert_true(loaded["character"].has("world_seed"))
	assert_eq(int(loaded["character"]["world_seed"]), 0)
	# Other fields preserved.
	assert_eq(loaded["character"]["name"], "Devon-Test")
	assert_eq(loaded["character"]["level"], 4)
	assert_eq(loaded["character"]["xp"], 999)
	assert_eq(loaded["character"]["unspent_stat_points"], 1)
	assert_eq(loaded["character"]["first_level_up_seen"], true)
	# v3 → v4 also backfills first_boss_kill_seen.
	assert_eq(loaded["character"]["first_boss_kill_seen"], false)
	# Untouched stash + meta.
	assert_eq(loaded["stash"].size(), 1)
	assert_eq(loaded["meta"]["runs_completed"], 3)


# -----------------------------------------------------------------------
# Coverage 5 — end-to-end: same world_seed → same AssembledFloor across save round-trip
# -----------------------------------------------------------------------


## Build a minimal well-formed chunk with WEST entry + EAST exit ports on
## row y=4, 15×8 tiles at 32 px. Mirrors test_floor_assembler.gd's
## _make_chunk helper — purposely duplicated rather than shared so the
## end-to-end pipeline test owns its fixtures.
func _make_chunk(id: StringName, exit_tag: StringName = &"exit") -> LevelChunkDef:
	var c: LevelChunkDef = LevelChunkDefScript.new()
	c.id = id
	c.size_tiles = Vector2i(15, 8)
	c.tile_size_px = 32
	var west_port: ChunkPort = ChunkPortScript.new()
	west_port.position_tiles = Vector2i(0, 4)
	west_port.direction = ChunkPort.Direction.WEST
	west_port.tag = &"entry"
	var east_port: ChunkPort = ChunkPortScript.new()
	east_port.position_tiles = Vector2i(14, 4)
	east_port.direction = ChunkPort.Direction.EAST
	east_port.tag = exit_tag
	c.ports = [west_port, east_port]
	return c


## Build a fixture zone with 3 anchors + 2 pool chunks — small enough to
## assemble cheaply, large enough to exercise per-zone variance.
func _make_zone() -> ZoneDef:
	var z: ZoneDef = ZoneDefScript.new()
	z.zone_id = &"test_world_seed_zone"
	z.display_name = "World-Seed Round-Trip Test Zone"
	z.stratum_id = 1
	z.min_slots_between_anchors = 1
	z.max_slots_between_anchors = 2
	z.procedural_slot_pool = [&"pool_a", &"pool_b"]
	var anchor_in: ZoneAnchor = ZoneAnchorScript.new()
	anchor_in.room_id = &"entry_room"
	anchor_in.chunk_id = &"chunk_in"
	anchor_in.anchor_kind = &"entry"
	var anchor_mid: ZoneAnchor = ZoneAnchorScript.new()
	anchor_mid.room_id = &"mid_room"
	anchor_mid.chunk_id = &"chunk_mid"
	anchor_mid.anchor_kind = &"npc_room"
	var anchor_out: ZoneAnchor = ZoneAnchorScript.new()
	anchor_out.room_id = &"exit_room"
	anchor_out.chunk_id = &"chunk_out"
	anchor_out.anchor_kind = &"exit"
	z.anchors = [anchor_in, anchor_mid, anchor_out]
	return z


## Build the chunks_by_id override mapping for the fixture zone.
func _make_chunks() -> Dictionary:
	return {
		&"chunk_in": _make_chunk(&"chunk_in"),
		&"chunk_mid": _make_chunk(&"chunk_mid"),
		&"chunk_out": _make_chunk(&"chunk_out"),
		&"pool_a": _make_chunk(&"pool_a"),
		&"pool_b": _make_chunk(&"pool_b"),
	}


## Deep-equal helper for AssembledFloor — compares the load-bearing fields
## bit-by-bit. Two floors are equal iff zone_id, seed, port_mating_errors,
## bounding_box_px, and every PlacedChunk (chunk_id, position_px, size_px,
## kind, anchor_room_id) match. Used by the end-to-end pipeline test.
func _floors_equal(a: AssembledFloor, b: AssembledFloor) -> bool:
	if a.zone_id != b.zone_id:
		return false
	if a.seed != b.seed:
		return false
	if a.bounding_box_px != b.bounding_box_px:
		return false
	if a.port_mating_errors.size() != b.port_mating_errors.size():
		return false
	for i: int in range(a.port_mating_errors.size()):
		if a.port_mating_errors[i] != b.port_mating_errors[i]:
			return false
	if a.placed_chunks.size() != b.placed_chunks.size():
		return false
	for i: int in range(a.placed_chunks.size()):
		var pa: PlacedChunk = a.placed_chunks[i]
		var pb: PlacedChunk = b.placed_chunks[i]
		if pa.chunk_id != pb.chunk_id:
			return false
		if pa.position_px != pb.position_px:
			return false
		if pa.size_px != pb.size_px:
			return false
		if pa.kind != pb.kind:
			return false
		if pa.anchor_room_id != pb.anchor_room_id:
			return false
	return true


func test_world_seed_drives_identical_assemble_across_save_load() -> void:
	# THIS IS THE LOAD-BEARING INVARIANT FROM THE BRIEF:
	#
	#   "create character → roll seed → save → reload → assert same seed
	#    → call FloorAssembler.assemble_floor(zone_def,
	#      derive_zone_seed(world_seed, zone_id)) → assert same
	#      AssembledFloor output across the round-trip."
	#
	# This is the regression guard for "world_seed silently dropped from
	# the save schema" AND "FloorAssembler became non-deterministic on
	# seed." If either failure mode lands in main, this test catches it.
	var original: Dictionary = _save().default_payload()
	var world_seed: int = int(original["character"]["world_seed"])
	assert_ne(world_seed, 0, "preflight: rolled seed is non-zero")

	# Save + reload.
	assert_true(_save().save_game(TEST_SLOT, original))
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	var seed_after_round_trip: int = int(loaded["character"]["world_seed"])
	assert_eq(seed_after_round_trip, world_seed,
		"world_seed survives save/load round-trip (precondition for assemble-equality)")

	# Derive zone seed both before AND after the round-trip; they must
	# match because derive_zone_seed is pure on (world_seed, zone_id).
	var zone: ZoneDef = _make_zone()
	var chunks: Dictionary = _make_chunks()
	var zone_seed_before: int = FloorAssembler.derive_zone_seed(
		FloorAssembler.derive_stratum_seed(world_seed, zone.stratum_id),
		zone.zone_id)
	var zone_seed_after: int = FloorAssembler.derive_zone_seed(
		FloorAssembler.derive_stratum_seed(seed_after_round_trip, zone.stratum_id),
		zone.zone_id)
	assert_eq(zone_seed_before, zone_seed_after,
		"derive_zone_seed cascade is deterministic on round-tripped world_seed")

	# Assemble twice (once with pre-save seed, once with post-load seed)
	# — the floors MUST be deep-equal.
	var assembler: FloorAssembler = FloorAssembler.new()
	var floor_before: AssembledFloor = assembler.assemble_floor(zone, zone_seed_before, chunks)
	var floor_after: AssembledFloor = assembler.assemble_floor(zone, zone_seed_after, chunks)

	assert_false(floor_before.is_empty(),
		"assemble produced a non-empty floor (preflight — chunks resolved)")
	assert_true(_floors_equal(floor_before, floor_after),
		"AssembledFloor is identical pre-save vs post-load — same world_seed → same map")
