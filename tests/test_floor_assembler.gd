extends GutTest
## Tests for `FloorAssembler.assemble_floor(zone_def, seed)` (M3 Tier 3 W1
## procgen spike Part A, ticket `86c9xub9p`).
##
## Coverage:
##   - Determinism — same (zone_def, seed) → identical AssembledFloor.
##   - Variance    — different seeds → meaningfully different placements
##                   (slot counts or chunk picks or both).
##   - Bounds      — slot counts stay within
##                   [min_slots_between_anchors, max_slots_between_anchors]
##                   per gap, for arbitrary seeds.
##   - Port mating — assembling the worked-example S1 zone produces zero
##                   port-mating errors (R-PROCGEN.b mitigation).
##   - Anchor invariants — anchor count matches input zone_def.anchors,
##                   anchor placements in input order, anchor_room_id
##                   preserved.
##   - Bounding box — equals sum of placed-chunk widths × max height.
##   - Edge cases  — null zone_def, invalid zone_def, unresolvable chunk_id,
##                   single-anchor zone (no gaps), zero-fill zone.
##   - Seed derivation — derive_stratum_seed + derive_zone_seed are
##                   deterministic + symmetric.
##
## Cross-references:
##   team/drew-dev/level-chunks.md § "Zone schema"
##   scripts/levels/FloorAssembler.gd
##   resources/level/AssembledFloor.gd
##   Ticket 86c9xub9p

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

const FloorAssemblerScript: Script = preload("res://scripts/levels/FloorAssembler.gd")
const AssembledFloorScript: Script = preload("res://resources/level/AssembledFloor.gd")
const ZoneDefScript: Script = preload("res://resources/level/ZoneDef.gd")
const ZoneAnchorScript: Script = preload("res://resources/level/ZoneAnchor.gd")
const LevelChunkDefScript: Script = preload("res://scripts/levels/LevelChunkDef.gd")
const ChunkPortScript: Script = preload("res://scripts/levels/ChunkPort.gd")
const MobSpawnPointScript: Script = preload("res://scripts/levels/MobSpawnPoint.gd")

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# -----------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------


## Build a minimal well-formed chunk with WEST entry + EAST exit ports on
## row y=4, 15×8 tiles at 32 px. Matches the S1 chunk shape exactly so
## fixture chunks mate cleanly out of the box.
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


## Build a fixture chunk with only a WEST entry port (entry-anchor shape —
## matches s1_room01.tres).
func _make_chunk_entry_only(id: StringName) -> LevelChunkDef:
	var c: LevelChunkDef = LevelChunkDefScript.new()
	c.id = id
	c.size_tiles = Vector2i(15, 8)
	c.tile_size_px = 32
	var west_port: ChunkPort = ChunkPortScript.new()
	west_port.position_tiles = Vector2i(2, 4)
	west_port.direction = ChunkPort.Direction.WEST
	west_port.tag = &"entry"
	c.ports = [west_port]
	return c


## Build an entry-only chunk that ALSO has an EAST exit port so it can
## mate as the leftmost chunk in a multi-chunk floor. Used to swap in
## for the s1_room01 chunk shape when we want clean mating in a fixture
## (the production s1_room01 chunk doesn't have an east exit because in
## M1 it's a single-room intro, but the procgen spike treats it as the
## entry anchor at the start of a multi-anchor zone).
func _make_chunk_entry_plus_east(id: StringName) -> LevelChunkDef:
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
	east_port.tag = &"exit"
	c.ports = [west_port, east_port]
	return c


func _make_anchor(
	room_id: StringName,
	chunk_id: StringName,
	anchor_kind: StringName,
	target_zone_id: StringName = &""
) -> ZoneAnchor:
	var a: ZoneAnchor = ZoneAnchorScript.new()
	a.room_id = room_id
	a.chunk_id = chunk_id
	a.anchor_kind = anchor_kind
	a.target_zone_id = target_zone_id
	return a


## Build a fixture zone with 3 anchors (entry / quest / exit), pool of
## two procedural chunks, fill range [1, 3], 32px tiles. Matches the S1
## zone shape but smaller for determinism testing.
func _make_fixture_zone() -> Dictionary:
	var zone: ZoneDef = ZoneDefScript.new()
	zone.zone_id = &"test_fixture_zone"
	zone.display_name = "Fixture Zone"
	zone.stratum_id = 1
	zone.anchors = [
		_make_anchor(&"r_entry", &"fx_entry", &"entry"),
		_make_anchor(&"r_quest", &"fx_quest", &"quest_target"),
		_make_anchor(&"r_exit", &"fx_exit", &"exit"),
	]
	zone.procedural_slot_pool = [&"fx_pool_a", &"fx_pool_b"]
	zone.min_slots_between_anchors = 1
	zone.max_slots_between_anchors = 3

	var chunks: Dictionary = {
		&"fx_entry": _make_chunk_entry_plus_east(&"fx_entry"),
		&"fx_quest": _make_chunk(&"fx_quest"),
		&"fx_exit": _make_chunk(&"fx_exit"),
		&"fx_pool_a": _make_chunk(&"fx_pool_a"),
		&"fx_pool_b": _make_chunk(&"fx_pool_b"),
	}
	return {"zone": zone, "chunks": chunks}


# -----------------------------------------------------------------------
# Determinism
# -----------------------------------------------------------------------


func test_assemble_same_seed_yields_identical_placement() -> void:
	# The load-bearing R-PROCGEN.a invariant: same (zone_def, seed) → same
	# AssembledFloor. If this fails, per-character maps would drift across
	# saves → save-corruption class.
	var fx: Dictionary = _make_fixture_zone()
	var asm: FloorAssembler = FloorAssemblerScript.new()
	var a: AssembledFloor = asm.assemble_floor(fx["zone"], 0xDEADBEEF, fx["chunks"])
	var b: AssembledFloor = asm.assemble_floor(fx["zone"], 0xDEADBEEF, fx["chunks"])

	assert_eq(a.chunk_count(), b.chunk_count(), "chunk count identical")
	for i: int in range(a.chunk_count()):
		assert_eq(
			a.placed_chunks[i].chunk_id, b.placed_chunks[i].chunk_id, "chunk[%d] id identical" % i
		)
		assert_eq(a.placed_chunks[i].kind, b.placed_chunks[i].kind, "chunk[%d] kind identical" % i)
		assert_eq(
			a.placed_chunks[i].position_px,
			b.placed_chunks[i].position_px,
			"chunk[%d] position identical" % i
		)
		assert_eq(
			a.placed_chunks[i].anchor_room_id,
			b.placed_chunks[i].anchor_room_id,
			"chunk[%d] anchor_room_id identical" % i
		)
	assert_eq(a.bounding_box_px, b.bounding_box_px, "bounding box identical")
	assert_eq(a.seed, b.seed, "seed field identical")


func test_assemble_different_seeds_produce_different_placements() -> void:
	# Variance check — the assembler must produce meaningfully different
	# outputs for different seeds (otherwise it's not really procedural).
	# Compare 8 seeds; assert that at least two of them differ in chunk
	# count OR in chunk-id sequence. Using N=8 keeps the false-negative
	# rate negligible — the seeded RNG would have to land on the exact
	# same draw sequence 8 times in a row.
	var fx: Dictionary = _make_fixture_zone()
	var asm: FloorAssembler = FloorAssemblerScript.new()
	var signatures: Dictionary = {}
	for s: int in [1, 2, 3, 7, 13, 42, 100, 999]:
		var f: AssembledFloor = asm.assemble_floor(fx["zone"], s, fx["chunks"])
		var sig_parts: Array[String] = []
		sig_parts.append(str(f.chunk_count()))
		for pc: PlacedChunk in f.placed_chunks:
			sig_parts.append(String(pc.chunk_id))
		signatures[s] = "|".join(sig_parts)
	# At least two distinct signatures among 8 seeds.
	var unique: Dictionary = {}
	for v: String in signatures.values():
		unique[v] = true
	assert_gt(
		unique.size(), 1, "8 distinct seeds produced only one placement signature — seeded RNG dead"
	)


# -----------------------------------------------------------------------
# Slot-count invariant
# -----------------------------------------------------------------------


func test_slot_count_between_anchors_within_bounds() -> void:
	# For 8 arbitrary seeds, every gap between consecutive anchors must
	# have a procedural-fill slot count within
	# [min_slots_between_anchors, max_slots_between_anchors] inclusive.
	var fx: Dictionary = _make_fixture_zone()
	var min_s: int = fx["zone"].min_slots_between_anchors
	var max_s: int = fx["zone"].max_slots_between_anchors
	var asm: FloorAssembler = FloorAssemblerScript.new()
	for s: int in [1, 2, 3, 7, 13, 42, 100, 999]:
		var f: AssembledFloor = asm.assemble_floor(fx["zone"], s, fx["chunks"])
		# Count procedural runs between each anchor pair.
		var anchor_indices: Array[int] = []
		for i: int in range(f.placed_chunks.size()):
			if f.placed_chunks[i].kind == &"anchor":
				anchor_indices.append(i)
		assert_eq(
			anchor_indices.size(),
			fx["zone"].anchors.size(),
			"anchor count must equal input (seed=%d)" % s
		)
		for gap: int in range(anchor_indices.size() - 1):
			var run: int = anchor_indices[gap + 1] - anchor_indices[gap] - 1
			assert_true(
				run >= min_s and run <= max_s,
				(
					"gap[%d] for seed=%d had %d procedural slots, expected [%d, %d]"
					% [gap, s, run, min_s, max_s]
				)
			)


func test_zero_max_slots_produces_anchor_only_floor() -> void:
	# Edge case: zone with min=max=0 → no procedural fill → output equals
	# the anchor list exactly. Pool may be empty (legal per
	# ZoneDef.validate when max_slots == 0).
	var zone: ZoneDef = ZoneDefScript.new()
	zone.zone_id = &"anchor_only_zone"
	zone.display_name = "Anchor Only"
	zone.stratum_id = 1
	zone.anchors = [
		_make_anchor(&"r_a", &"fx_a", &"entry"),
		_make_anchor(&"r_b", &"fx_b", &"exit"),
	]
	zone.procedural_slot_pool = []
	zone.min_slots_between_anchors = 0
	zone.max_slots_between_anchors = 0
	var chunks: Dictionary = {
		&"fx_a": _make_chunk_entry_plus_east(&"fx_a"),
		&"fx_b": _make_chunk(&"fx_b"),
	}
	var asm: FloorAssembler = FloorAssemblerScript.new()
	var f: AssembledFloor = asm.assemble_floor(zone, 42, chunks)
	assert_eq(f.chunk_count(), 2, "no procedural fill → only the 2 anchors")
	assert_eq(f.placed_chunks[0].kind, &"anchor")
	assert_eq(f.placed_chunks[1].kind, &"anchor")
	assert_eq(f.anchor_count(), 2)
	assert_eq(f.procedural_count(), 0)


# -----------------------------------------------------------------------
# Anchor invariants
# -----------------------------------------------------------------------


func test_anchors_placed_in_input_order_with_room_ids_preserved() -> void:
	# Anchor placements must appear in the same order as
	# zone_def.anchors[], and each placement's anchor_room_id must equal
	# the input anchor's room_id. Quest content + save schema key on this.
	var fx: Dictionary = _make_fixture_zone()
	var asm: FloorAssembler = FloorAssemblerScript.new()
	var f: AssembledFloor = asm.assemble_floor(fx["zone"], 12345, fx["chunks"])
	var anchor_room_ids: Array[StringName] = []
	for pc: PlacedChunk in f.placed_chunks:
		if pc.kind == &"anchor":
			anchor_room_ids.append(pc.anchor_room_id)
	var expected: Array[StringName] = []
	for a: ZoneAnchor in fx["zone"].anchors:
		expected.append(a.room_id)
	assert_eq(
		anchor_room_ids, expected, "anchor order + room_ids must mirror input zone_def.anchors"
	)


# -----------------------------------------------------------------------
# Bounding box
# -----------------------------------------------------------------------


func test_bounding_box_spans_full_floor() -> void:
	# Bounding box position = (0, 0); size.x = sum of placed-chunk widths;
	# size.y = max placed-chunk height (single-row layout).
	var fx: Dictionary = _make_fixture_zone()
	var asm: FloorAssembler = FloorAssemblerScript.new()
	var f: AssembledFloor = asm.assemble_floor(fx["zone"], 1, fx["chunks"])
	var expected_w: float = 0.0
	var expected_h: float = 0.0
	for pc: PlacedChunk in f.placed_chunks:
		expected_w += float(pc.size_px.x)
		expected_h = max(expected_h, float(pc.size_px.y))
	assert_eq(f.bounding_box_px.position, Vector2.ZERO, "bbox starts at floor-local origin")
	assert_eq(f.bounding_box_px.size.x, expected_w, "bbox width = sum of chunk widths")
	assert_eq(f.bounding_box_px.size.y, expected_h, "bbox height = max chunk height")


func test_chunks_laid_out_left_to_right_no_overlap() -> void:
	# Every placement's position.x must equal the previous placement's
	# (position.x + size_px.x). No overlaps; no gaps. Test pin for the
	# layout-sweep invariant that adjacent chunks share their seam edge.
	var fx: Dictionary = _make_fixture_zone()
	var asm: FloorAssembler = FloorAssemblerScript.new()
	var f: AssembledFloor = asm.assemble_floor(fx["zone"], 1, fx["chunks"])
	for i: int in range(f.placed_chunks.size() - 1):
		var left: PlacedChunk = f.placed_chunks[i]
		var right: PlacedChunk = f.placed_chunks[i + 1]
		var left_right_edge: float = left.position_px.x + float(left.size_px.x)
		assert_eq(
			right.position_px.x,
			left_right_edge,
			"chunk[%d].right_edge == chunk[%d].left_edge (no overlap, no gap)" % [i, i + 1]
		)


# -----------------------------------------------------------------------
# Port-mating contract (R-PROCGEN.b mitigation)
# -----------------------------------------------------------------------


func test_fixture_zone_has_zero_port_mating_errors() -> void:
	# Fixture chunks all have matching WEST/EAST seam-row ports. Test
	# across 8 seeds — the seam discipline must hold regardless of which
	# procedural chunk gets picked.
	var fx: Dictionary = _make_fixture_zone()
	var asm: FloorAssembler = FloorAssemblerScript.new()
	for s: int in [1, 2, 3, 7, 13, 42, 100, 999]:
		var f: AssembledFloor = asm.assemble_floor(fx["zone"], s, fx["chunks"])
		assert_true(
			f.is_well_mated(), "seed=%d produced mating errors: %s" % [s, str(f.port_mating_errors)]
		)


func test_port_mismatch_recorded_not_raised() -> void:
	# Inject a chunk with NO east port → mating between (broken_left,
	# anything_right) must record an error string but still place both
	# chunks (the assembler doesn't bail on a mating gap — visual proof
	# scene gets to show the regression).
	var zone: ZoneDef = ZoneDefScript.new()
	zone.zone_id = &"broken_mating_zone"
	zone.display_name = "Broken Mating Zone"
	zone.stratum_id = 1
	zone.anchors = [
		_make_anchor(&"r_a", &"fx_no_east", &"entry"),
		_make_anchor(&"r_b", &"fx_b", &"exit"),
	]
	zone.procedural_slot_pool = []
	zone.min_slots_between_anchors = 0
	zone.max_slots_between_anchors = 0
	var chunks: Dictionary = {
		&"fx_no_east": _make_chunk_entry_only(&"fx_no_east"),
		&"fx_b": _make_chunk(&"fx_b"),
	}
	var asm: FloorAssembler = FloorAssemblerScript.new()
	var f: AssembledFloor = asm.assemble_floor(zone, 1, chunks)
	assert_eq(f.chunk_count(), 2, "both chunks still placed despite mating gap")
	assert_false(f.is_well_mated(), "mating error must be recorded")
	assert_eq(
		f.port_mating_errors.size(),
		1,
		"expected exactly 1 mating error, got: %s" % str(f.port_mating_errors)
	)


# -----------------------------------------------------------------------
# Edge cases
# -----------------------------------------------------------------------


func test_null_zone_def_returns_empty_floor() -> void:
	# Defensive — null input must not crash. Returns an empty
	# AssembledFloor that the caller can detect via is_empty().
	# Note: assembler emits via push_error (native Godot logger),
	# bypassing WarningBus — NoWarningGuard doesn't capture it.
	var asm: FloorAssembler = FloorAssemblerScript.new()
	var f: AssembledFloor = asm.assemble_floor(null, 1)
	assert_not_null(f, "must return an AssembledFloor, not null")
	assert_true(f.is_empty(), "empty placement list")


func test_invalid_zone_def_returns_empty_floor() -> void:
	# Zone with no entry anchor → validate() fails → assembler bails.
	var zone: ZoneDef = ZoneDefScript.new()
	zone.zone_id = &"bad"
	zone.display_name = "Bad"
	zone.stratum_id = 1
	zone.anchors = [_make_anchor(&"r_exit_only", &"fx_b", &"exit")]
	zone.procedural_slot_pool = [&"fx_b"]
	var chunks: Dictionary = {&"fx_b": _make_chunk(&"fx_b")}
	var asm: FloorAssembler = FloorAssemblerScript.new()
	var f: AssembledFloor = asm.assemble_floor(zone, 1, chunks)
	assert_true(f.is_empty(), "invalid zone → empty floor")


func test_unresolvable_chunk_id_returns_empty_floor() -> void:
	# Zone references a chunk id whose .tres doesn't exist AND isn't in
	# the override → assembler bails before placing.
	var zone: ZoneDef = ZoneDefScript.new()
	zone.zone_id = &"unresolvable_zone"
	zone.display_name = "Unresolvable"
	zone.stratum_id = 1
	zone.anchors = [
		_make_anchor(&"r_a", &"does_not_exist_a", &"entry"),
		_make_anchor(&"r_b", &"does_not_exist_b", &"exit"),
	]
	zone.procedural_slot_pool = [&"does_not_exist_p"]
	var asm: FloorAssembler = FloorAssemblerScript.new()
	# Empty override forces production load() path; production has no
	# chunks named "does_not_exist_*".
	var f: AssembledFloor = asm.assemble_floor(zone, 1, {})
	assert_true(f.is_empty(), "unresolvable chunk id → empty floor")


# -----------------------------------------------------------------------
# Seed derivation
# -----------------------------------------------------------------------


func test_derive_stratum_seed_is_deterministic() -> void:
	# Same inputs → same output. Different inputs → different outputs
	# (with overwhelming probability; we just assert any-two of three
	# inputs differ to avoid accidental hash collisions in the test).
	var a: int = FloorAssemblerScript.derive_stratum_seed(0xC001D00D, 1)
	var b: int = FloorAssemblerScript.derive_stratum_seed(0xC001D00D, 1)
	assert_eq(a, b, "same world_seed + stratum_id → same stratum_seed")

	var c: int = FloorAssemblerScript.derive_stratum_seed(0xC001D00D, 2)
	var d: int = FloorAssemblerScript.derive_stratum_seed(0xDEADBEEF, 1)
	assert_true(
		a != c or a != d,
		"different (world_seed, stratum_id) must produce at least one differing stratum_seed"
	)


func test_derive_zone_seed_is_deterministic() -> void:
	var a: int = FloorAssemblerScript.derive_zone_seed(0xBEEF, &"s1_z1_outer_cloister")
	var b: int = FloorAssemblerScript.derive_zone_seed(0xBEEF, &"s1_z1_outer_cloister")
	assert_eq(a, b, "same (stratum_seed, zone_id) → same zone_seed")

	var c: int = FloorAssemblerScript.derive_zone_seed(0xBEEF, &"s1_z2_other")
	var d: int = FloorAssemblerScript.derive_zone_seed(0xCAFE, &"s1_z1_outer_cloister")
	assert_true(
		a != c or a != d,
		"different (stratum_seed, zone_id) must produce at least one differing zone_seed"
	)


# -----------------------------------------------------------------------
# Worked-example round-trip — the actual S1 z1 zone .tres
# -----------------------------------------------------------------------


func test_assemble_authored_s1_z1_outer_cloister_round_trip() -> void:
	# W2-T3 retrofit (`86c9y1045`) — the production S1 zone is now the full
	# 9-anchor (8 unique chunks; room08 used for boss + exit per spike
	# convention) Stratum-1 narrative arc with a [0, 1]-slot procedural fill
	# pool of size 3. Demonstrates the full pipeline: ZoneDef.tres +
	# LevelChunkDef.tres files → AssembledFloor with deterministic placement.
	var zone: ZoneDef = load("res://resources/level/zones/s1_z1_outer_cloister.tres") as ZoneDef
	assert_not_null(zone, "s1_z1_outer_cloister.tres must load as ZoneDef")
	var asm: FloorAssembler = FloorAssemblerScript.new()
	var seed: int = FloorAssemblerScript.derive_zone_seed(
		FloorAssemblerScript.derive_stratum_seed(0xC001D00D, 1), zone.zone_id
	)
	var f: AssembledFloor = asm.assemble_floor(zone, seed)
	assert_false(f.is_empty(), "production zone must assemble: %s" % str(f.port_mating_errors))
	assert_eq(f.anchor_count(), 9, "S1 z1 has 9 anchors (8 unique chunks; room08 boss + exit)")
	# Procedural count is between (n-1)*min and (n-1)*max = 8*0=0..8*1=8.
	assert_true(
		f.procedural_count() >= 0 and f.procedural_count() <= 8,
		"S1 z1 procedural count %d out of [0, 8]" % f.procedural_count()
	)


func test_assemble_authored_s1_z1_same_seed_identical_across_runs() -> void:
	# Same character + same zone → same map across save/load (R-PROCGEN.a).
	# This is the spike's headline proof for the seed round-trip
	# question, exercising the real production .tres files.
	var zone: ZoneDef = load("res://resources/level/zones/s1_z1_outer_cloister.tres") as ZoneDef
	var asm: FloorAssembler = FloorAssemblerScript.new()
	var seed: int = 0xC0FFEE
	var a: AssembledFloor = asm.assemble_floor(zone, seed)
	var b: AssembledFloor = asm.assemble_floor(zone, seed)
	assert_eq(a.chunk_count(), b.chunk_count())
	for i: int in range(a.chunk_count()):
		assert_eq(a.placed_chunks[i].chunk_id, b.placed_chunks[i].chunk_id)
		assert_eq(a.placed_chunks[i].position_px, b.placed_chunks[i].position_px)


func test_assemble_authored_s1_z1_room01_east_seam_now_mates() -> void:
	# W2-T3 retrofit (`86c9y1045`) — R-PROCGEN.b closed for s1_room01.
	#
	# **Pre-W2 history:** s1_room01.tres declared only a WEST entry port
	# (M1-era single-room intro chunk), so its EAST seam was open and the
	# assembler recorded a mating error at the s1_room01 → first-procedural
	# seam. The spike PR's `test_assemble_authored_s1_z1_records_s1_room01_east_seam_finding`
	# pinned that empirical state.
	#
	# **Post-W2 state (this PR):** s1_room01.tres now carries an EAST
	# &"exit" port at position_tiles=(14, 4) (the canonical row-4 seam
	# shape shared by all S1 chunks). The W2 retrofit also expanded the
	# S1 z1 ZoneDef to declare ALL 8 S1 chunks as anchors with a small
	# procedural pool drawn from rooms 03/05/07 — every adjacent seam now
	# mates cleanly.
	#
	# Pin: production S1 z1 zone assembles with ZERO port-mating errors;
	# specifically, no error mentions s1_room01.
	var zone: ZoneDef = load("res://resources/level/zones/s1_z1_outer_cloister.tres") as ZoneDef
	var asm: FloorAssembler = FloorAssemblerScript.new()
	var f: AssembledFloor = asm.assemble_floor(zone, 1)
	assert_true(
		f.is_well_mated(),
		(
			"production S1 z1 zone must mate cleanly after W2 retrofit, got: %s"
			% str(f.port_mating_errors)
		)
	)
	for err: String in f.port_mating_errors:
		assert_false(
			err.find("s1_room01") >= 0,
			"unexpected s1_room01 mating finding after W2 east-seam fix: %s" % err
		)


func test_assemble_authored_s1_z1_boss_door_mates_cleanly() -> void:
	# Sub-pin of the finding above — `boss_door` tag is in OPEN_PORT_TAGS,
	# so the s1_room08 ↔ s1_room08 boss/exit pair (the only place the
	# boss_door tag appears in the worked example) MUST NOT produce a
	# mating error. If a future refactor accidentally drops boss_door
	# from OPEN_PORT_TAGS, this test surfaces it.
	var zone: ZoneDef = load("res://resources/level/zones/s1_z1_outer_cloister.tres") as ZoneDef
	var asm: FloorAssembler = FloorAssemblerScript.new()
	# Use a small seed so we have predictable output; assert no error
	# mentions s1_room08 (the boss_door chunk) at the boss/exit seam.
	var f: AssembledFloor = asm.assemble_floor(zone, 42)
	for err: String in f.port_mating_errors:
		assert_false(
			err.find("s1_room08") >= 0 and err.find("no shared seam row") >= 0,
			"boss_door tag must mate cleanly; unexpected s1_room08 seam-row error: %s" % err
		)


# -----------------------------------------------------------------------
# W2-T3 (86c9y1045) — S1 procgen retrofit acceptance pins
# -----------------------------------------------------------------------
#
# Per the SI-8 (b) lock + AC-C5-{1,3,4,5} acceptance rows in
# `team/tess-qa/m3-acceptance-plan-tier-3.md` Track 1.5. Sample-size
# discipline N≥8 per the AC4-retro Gap 1 lesson + dispatch brief.


func test_s1_z1_clean_mating_across_8_seeds() -> void:
	# R-PROCGEN.b closure pin — across N=8 release-quality seeds, the
	# post-retrofit S1 z1 zone must produce zero port-mating errors. If
	# any seed surfaces an error, either a procedural-pool chunk lacks
	# the canonical row-4 seam OR an anchor seam regressed.
	var zone: ZoneDef = load("res://resources/level/zones/s1_z1_outer_cloister.tres") as ZoneDef
	var asm: FloorAssembler = FloorAssemblerScript.new()
	for s: int in [1, 2, 3, 7, 13, 42, 100, 999]:
		var f: AssembledFloor = asm.assemble_floor(zone, s)
		assert_true(
			f.is_well_mated(),
			"seed=%d produced mating errors after W2 retrofit: %s" % [s, str(f.port_mating_errors)]
		)


func test_s1_z1_all_8_unique_chunks_referenced() -> void:
	# Coverage pin — the W2 retrofit declares all 8 S1 hand-authored chunks
	# (s1_room01 .. s1_room08) as anchors in the zone. Without this pin a
	# silent drop of one room would be caught only by a content review.
	var zone: ZoneDef = load("res://resources/level/zones/s1_z1_outer_cloister.tres") as ZoneDef
	var anchor_chunk_ids: Dictionary = {}
	for a: ZoneAnchor in zone.anchors:
		anchor_chunk_ids[a.chunk_id] = true
	for i: int in range(1, 9):
		var expected: StringName = StringName("s1_room%02d" % i)
		assert_true(
			anchor_chunk_ids.has(expected),
			(
				"S1 z1 must declare %s as an anchor chunk_id (got anchors %s)"
				% [str(expected), str(anchor_chunk_ids.keys())]
			)
		)


func test_s1_z1_anchors_have_deterministic_relative_order_across_seeds() -> void:
	# AC-C5-3 — hand-authored anchors compose at deterministic positions
	# (NOT seed-dependent); only the procedural slots between them vary by
	# seed. Across N=8 seeds, the ORDERED LIST of anchor room_ids must be
	# identical (only procedural-fill chunk_ids may differ).
	var zone: ZoneDef = load("res://resources/level/zones/s1_z1_outer_cloister.tres") as ZoneDef
	var expected_room_ids: Array[StringName] = []
	for a: ZoneAnchor in zone.anchors:
		expected_room_ids.append(a.room_id)
	var asm: FloorAssembler = FloorAssemblerScript.new()
	for s: int in [1, 2, 3, 7, 13, 42, 100, 999]:
		var f: AssembledFloor = asm.assemble_floor(zone, s)
		var observed: Array[StringName] = []
		for pc: PlacedChunk in f.placed_chunks:
			if pc.kind == &"anchor":
				observed.append(pc.anchor_room_id)
		assert_eq(
			observed,
			expected_room_ids,
			(
				"seed=%d anchor order must match input zone_def.anchors (got %s, want %s)"
				% [s, str(observed), str(expected_room_ids)]
			)
		)


func test_s1_z1_total_chunk_count_in_documented_bounds() -> void:
	# Bounds pin — per the .tres docstring, the W2 retrofit zone produces
	# 9 (anchors-only) .. 17 (max procedural fill) chunks per assembly.
	# Anchors=9, gaps=8, slots-per-gap=[0,1] → procedural ∈ [0, 8] →
	# total ∈ [9, 17].
	var zone: ZoneDef = load("res://resources/level/zones/s1_z1_outer_cloister.tres") as ZoneDef
	var asm: FloorAssembler = FloorAssemblerScript.new()
	for s: int in [1, 2, 3, 7, 13, 42, 100, 999]:
		var f: AssembledFloor = asm.assemble_floor(zone, s)
		assert_true(
			f.chunk_count() >= 9 and f.chunk_count() <= 17,
			"seed=%d total chunk count %d outside documented [9, 17]" % [s, f.chunk_count()]
		)
		assert_eq(f.anchor_count(), 9, "seed=%d anchor count must equal 9" % s)


func test_s1_z1_same_seed_bit_identical_across_runs() -> void:
	# AC-C5-1 — same character + same zone → same map across save/load.
	# The headline determinism pin for the production zone. Asserts the
	# full placement vector (chunk_id + position + kind + anchor_room_id)
	# is bit-identical across two assemble calls with the same seed.
	var zone: ZoneDef = load("res://resources/level/zones/s1_z1_outer_cloister.tres") as ZoneDef
	var asm: FloorAssembler = FloorAssemblerScript.new()
	var seed: int = 0xCAFEBABE
	var a: AssembledFloor = asm.assemble_floor(zone, seed)
	var b: AssembledFloor = asm.assemble_floor(zone, seed)
	assert_eq(a.chunk_count(), b.chunk_count())
	for i: int in range(a.chunk_count()):
		assert_eq(
			a.placed_chunks[i].chunk_id,
			b.placed_chunks[i].chunk_id,
			"chunk[%d] chunk_id identical" % i
		)
		assert_eq(
			a.placed_chunks[i].position_px,
			b.placed_chunks[i].position_px,
			"chunk[%d] position identical" % i
		)
		assert_eq(a.placed_chunks[i].kind, b.placed_chunks[i].kind, "chunk[%d] kind identical" % i)
		assert_eq(
			a.placed_chunks[i].anchor_room_id,
			b.placed_chunks[i].anchor_room_id,
			"chunk[%d] anchor_room_id identical" % i
		)


func test_s1_z1_per_stratum_seed_isolation() -> void:
	# AC-C5-4 — re-rolling S1 layout does NOT leak into S2 layout for the
	# same character (and vice versa). `stratum_seed = hash(world_seed,
	# stratum_id)` — two stratum_ids must produce DIFFERENT derived seeds
	# from the same world_seed.
	var world_seed: int = 0xC001D00D
	var s1_seed: int = FloorAssemblerScript.derive_stratum_seed(world_seed, 1)
	var s2_seed: int = FloorAssemblerScript.derive_stratum_seed(world_seed, 2)
	assert_ne(
		s1_seed,
		s2_seed,
		(
			"S1 and S2 stratum_seeds must differ for the same world_seed (got %d == %d)"
			% [s1_seed, s2_seed]
		)
	)
	# And the same stratum_id with the same world_seed must be stable
	# (already pinned by test_derive_stratum_seed_is_deterministic above,
	# repeated here for the per-zone-impl narrative).
	var s1_seed_b: int = FloorAssemblerScript.derive_stratum_seed(world_seed, 1)
	assert_eq(
		s1_seed, s1_seed_b, "S1 stratum_seed must be stable for the same (world_seed, stratum_id)"
	)


func test_s1_z1_per_zone_seed_isolation() -> void:
	# AC-C5-5 — re-entering a zone within a run produces the same layout
	# (no re-roll on zone-load); a different zone produces independent
	# layout. `zone_seed = hash(stratum_seed, zone_id)` — two zone_ids
	# under the same stratum_seed must produce DIFFERENT derived seeds.
	var stratum_seed: int = FloorAssemblerScript.derive_stratum_seed(0xC001D00D, 1)
	var z1_seed: int = FloorAssemblerScript.derive_zone_seed(stratum_seed, &"s1_z1_outer_cloister")
	var z2_seed: int = FloorAssemblerScript.derive_zone_seed(stratum_seed, &"s1_z2_inner_cloister")
	assert_ne(
		z1_seed,
		z2_seed,
		(
			"Different zone_ids must produce different zone_seeds under the same stratum_seed (got %d == %d)"
			% [z1_seed, z2_seed]
		)
	)
	var z1_seed_b: int = FloorAssemblerScript.derive_zone_seed(
		stratum_seed, &"s1_z1_outer_cloister"
	)
	assert_eq(
		z1_seed,
		z1_seed_b,
		"Same zone_id must produce the same zone_seed under the same stratum_seed"
	)


func test_s1_z1_different_seeds_produce_different_layouts() -> void:
	# AC-C5-2 — different characters in same save produce different maps.
	# Surveys 8 distinct seeds and asserts at least 2 produce distinct
	# placement signatures. With pool size 3 × [0, 1] slots per 8 gaps,
	# variance is significant — accidental seed collisions across 8 seeds
	# are negligibly improbable.
	var zone: ZoneDef = load("res://resources/level/zones/s1_z1_outer_cloister.tres") as ZoneDef
	var asm: FloorAssembler = FloorAssemblerScript.new()
	var signatures: Dictionary = {}
	for s: int in [12345, 67890, 11111, 22222, 33333, 44444, 55555, 66666]:
		var f: AssembledFloor = asm.assemble_floor(zone, s)
		var sig_parts: Array[String] = []
		sig_parts.append(str(f.chunk_count()))
		for pc: PlacedChunk in f.placed_chunks:
			sig_parts.append(String(pc.chunk_id))
		signatures[s] = "|".join(sig_parts)
	var unique: Dictionary = {}
	for v: String in signatures.values():
		unique[v] = true
	assert_gt(
		unique.size(),
		1,
		"8 distinct seeds against S1 z1 produced only one placement signature — variance dead"
	)


func test_s1_z1_procedural_pool_chunks_resolve_via_load() -> void:
	# Content-integrity pin — every chunk_id in the procedural_slot_pool
	# resolves to an actual LevelChunkDef on disk. A typo in the .tres
	# would fail loudly here instead of surfacing as an unresolvable-id
	# error at assemble-time on a player's machine.
	var zone: ZoneDef = load("res://resources/level/zones/s1_z1_outer_cloister.tres") as ZoneDef
	for chunk_id: StringName in zone.procedural_slot_pool:
		var path: String = "res://resources/level_chunks/%s.tres" % String(chunk_id)
		var res: Resource = load(path)
		assert_not_null(
			res, "procedural pool chunk_id %s must resolve at %s" % [str(chunk_id), path]
		)
		assert_true(
			res is LevelChunkDef,
			"procedural pool chunk_id %s at %s must be a LevelChunkDef" % [str(chunk_id), path]
		)


func test_s1_z1_all_anchor_chunk_ids_resolve_via_load() -> void:
	# Sibling pin — every anchor.chunk_id resolves on disk. The eight
	# unique S1 chunks (s1_room01 .. s1_room08) must all load.
	var zone: ZoneDef = load("res://resources/level/zones/s1_z1_outer_cloister.tres") as ZoneDef
	var seen: Dictionary = {}
	for a: ZoneAnchor in zone.anchors:
		if seen.has(a.chunk_id):
			continue
		seen[a.chunk_id] = true
		var path: String = "res://resources/level_chunks/%s.tres" % String(a.chunk_id)
		var res: Resource = load(path)
		assert_not_null(res, "anchor chunk_id %s must resolve at %s" % [str(a.chunk_id), path])
		assert_true(
			res is LevelChunkDef,
			"anchor chunk_id %s at %s must be a LevelChunkDef" % [str(a.chunk_id), path]
		)


func test_s1_room01_now_has_east_exit_port() -> void:
	# W2-T3 Part B — direct chunk-level pin on the s1_room01 east-seam fix.
	# After the W2 retrofit s1_room01.tres carries:
	#   - WEST entry port (original M1 spawn point)
	#   - EAST exit port at position_tiles=(14, 4) (NEW)
	# This is the root-cause fix for R-PROCGEN.b's s1_room01 finding.
	var chunk: LevelChunkDef = load("res://resources/level_chunks/s1_room01.tres") as LevelChunkDef
	assert_not_null(chunk, "s1_room01.tres must load")
	var has_east_exit: bool = false
	for p: ChunkPort in chunk.ports:
		if int(p.direction) == ChunkPort.Direction.EAST and p.tag == &"exit":
			has_east_exit = true
			assert_eq(
				p.position_tiles,
				Vector2i(14, 4),
				"s1_room01 EAST exit port must sit at (14, 4) per W2 fix shape"
			)
	assert_true(has_east_exit, 's1_room01 must declare an EAST &"exit" port (W2-T3 east-seam fix)')


func test_s1_z1_zone_def_validates_cleanly() -> void:
	# Hygiene pin — the production zone .tres must validate cleanly. A
	# typo, duplicate room_id, or missing entry/exit anchor would surface
	# at GUT time instead of at the first player's run.
	var zone: ZoneDef = load("res://resources/level/zones/s1_z1_outer_cloister.tres") as ZoneDef
	var errors: Array[String] = zone.validate()
	assert_true(
		errors.is_empty(),
		"production S1 z1 ZoneDef.validate() must return empty array; got: %s" % str(errors)
	)
