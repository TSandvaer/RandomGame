extends GutTest
## W3-T7 Stage 4 — S2 chunk + zone wiring smoke test (ticket 86c9y7ygj
## Part F).
##
## Scope: boot each of the 4 S2 ZoneDefs via FloorAssembler, assert no
## USER WARNING:, bounding_box_px computed, port_mating_errors empty, and
## every mob_id appearing in any placed-chunk's mob_spawns resolves via
## MobRegistry. The dispatch brief codifies these as the Stage 4 acceptance
## per ticket §F.
##
## Per `test-conventions.md` § "preload of .tres can bind to null at
## parse-time" (PR #357 lesson), route .tres loads through runtime
## `load(...)` rather than top-of-file `const PRELOAD := preload(...)`.
## ZoneDefs with nested scripted sub-resources (ZoneAnchor entries) are
## the empirical failure shape for the trap.
##
## Cross-references:
##   resources/level_chunks/s2_room01..s2_room08.tres
##   resources/level/zones/s2_z1_entry_hall.tres .. s2_z4_inner_sanctum.tres
##   scripts/levels/FloorAssembler.gd
##   .claude/docs/procgen-pipeline.md § "Port-mating: record-not-raise"
##   .claude/docs/test-conventions.md § "Universal warning gate"

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")
const FloorAssemblerScript: Script = preload("res://scripts/levels/FloorAssembler.gd")
const AssembledFloorScript: Script = preload("res://resources/level/AssembledFloor.gd")
const ZoneDefScript: Script = preload("res://resources/level/ZoneDef.gd")

# Per `test-conventions.md` § "preload of .tres can bind to null at
# parse-time" — route .tres loads through helper functions, NOT
# top-of-file `const PRELOAD := preload(...)`. ZoneDefs with nested
# scripted sub-resources are an empirical case of the trap.
func _load_zone_entry_hall() -> ZoneDef:
	return load("res://resources/level/zones/s2_z1_entry_hall.tres")


func _load_zone_reading_chamber() -> ZoneDef:
	return load("res://resources/level/zones/s2_z2_reading_chamber.tres")


func _load_zone_archive_vault() -> ZoneDef:
	return load("res://resources/level/zones/s2_z3_archive_vault.tres")


func _load_zone_inner_sanctum() -> ZoneDef:
	return load("res://resources/level/zones/s2_z4_inner_sanctum.tres")


# Test seed — fixed so determinism is preserved across CI runs. Per
# FloorAssembler's seed-cascade contract, same (zone_def, seed) → same
# AssembledFloor. The number itself is not load-bearing; pick any int.
const TEST_SEED: int = 0xC1DEDDED  # arbitrary fixed seed; not load-bearing

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- Per-zone assemble smoke ---------------------------------------


func test_s2_z1_entry_hall_assembles_clean() -> void:
	var zone: ZoneDef = _load_zone_entry_hall()
	assert_not_null(zone, "s2_z1_entry_hall.tres must load as ZoneDef")
	var validate_errors: Array[String] = zone.validate()
	assert_eq(
		validate_errors.size(),
		0,
		"ZoneDef.validate() must return empty: %s" % str(validate_errors)
	)

	var asm: FloorAssembler = FloorAssemblerScript.new()
	var floor: AssembledFloor = asm.assemble_floor(zone, TEST_SEED)
	assert_not_null(floor, "assemble_floor must return non-null AssembledFloor")
	assert_false(floor.is_empty(), "AssembledFloor.placed_chunks must be non-empty")
	assert_true(floor.is_well_mated(), "port_mating_errors must be empty: %s" % str(floor.port_mating_errors))
	assert_gt(floor.bounding_box_px.size.x, 0.0, "bounding_box width > 0")
	assert_gt(floor.bounding_box_px.size.y, 0.0, "bounding_box height > 0")
	assert_eq(floor.zone_id, &"s2_z1_entry_hall", "AssembledFloor.zone_id matches")
	assert_eq(floor.anchor_count(), 2, "zone has 2 anchors (entry + exit)")


func test_s2_z2_reading_chamber_assembles_clean() -> void:
	var zone: ZoneDef = _load_zone_reading_chamber()
	assert_not_null(zone, "s2_z2_reading_chamber.tres must load as ZoneDef")
	var validate_errors: Array[String] = zone.validate()
	assert_eq(
		validate_errors.size(),
		0,
		"ZoneDef.validate() must return empty: %s" % str(validate_errors)
	)

	var asm: FloorAssembler = FloorAssemblerScript.new()
	var floor: AssembledFloor = asm.assemble_floor(zone, TEST_SEED)
	assert_false(floor.is_empty(), "AssembledFloor.placed_chunks must be non-empty")
	assert_true(floor.is_well_mated(), "port_mating_errors must be empty: %s" % str(floor.port_mating_errors))
	assert_gt(floor.bounding_box_px.size.x, 0.0, "bounding_box width > 0")
	assert_eq(floor.zone_id, &"s2_z2_reading_chamber", "AssembledFloor.zone_id matches")
	assert_eq(floor.anchor_count(), 3, "zone has 3 anchors (entry + npc + exit)")


func test_s2_z3_archive_vault_assembles_clean() -> void:
	var zone: ZoneDef = _load_zone_archive_vault()
	assert_not_null(zone, "s2_z3_archive_vault.tres must load as ZoneDef")
	var validate_errors: Array[String] = zone.validate()
	assert_eq(
		validate_errors.size(),
		0,
		"ZoneDef.validate() must return empty: %s" % str(validate_errors)
	)

	var asm: FloorAssembler = FloorAssemblerScript.new()
	var floor: AssembledFloor = asm.assemble_floor(zone, TEST_SEED)
	assert_false(floor.is_empty(), "AssembledFloor.placed_chunks must be non-empty")
	assert_true(floor.is_well_mated(), "port_mating_errors must be empty: %s" % str(floor.port_mating_errors))
	assert_gt(floor.bounding_box_px.size.x, 0.0, "bounding_box width > 0")
	assert_eq(floor.zone_id, &"s2_z3_archive_vault", "AssembledFloor.zone_id matches")
	assert_eq(floor.anchor_count(), 3, "zone has 3 anchors (entry + quest + exit)")


func test_s2_z4_inner_sanctum_assembles_clean() -> void:
	var zone: ZoneDef = _load_zone_inner_sanctum()
	assert_not_null(zone, "s2_z4_inner_sanctum.tres must load as ZoneDef")
	var validate_errors: Array[String] = zone.validate()
	assert_eq(
		validate_errors.size(),
		0,
		"ZoneDef.validate() must return empty: %s" % str(validate_errors)
	)

	var asm: FloorAssembler = FloorAssemblerScript.new()
	var floor: AssembledFloor = asm.assemble_floor(zone, TEST_SEED)
	assert_false(floor.is_empty(), "AssembledFloor.placed_chunks must be non-empty")
	assert_true(floor.is_well_mated(), "port_mating_errors must be empty: %s" % str(floor.port_mating_errors))
	assert_gt(floor.bounding_box_px.size.x, 0.0, "bounding_box width > 0")
	assert_eq(floor.zone_id, &"s2_z4_inner_sanctum", "AssembledFloor.zone_id matches")
	assert_eq(floor.anchor_count(), 3, "zone has 3 anchors (entry + boss_room + exit)")


# ---- Sample-size discipline (N≥8 per Drew persona memory) ---------


func test_s2_z1_clean_mating_across_8_seeds() -> void:
	# Cross-seed mating discipline: per FloorAssembler doc + R-PROCGEN.b
	# mitigation, NO seed should produce mating errors against authored
	# chunks. N=8 per Drew persona's sample-size rule.
	var zone: ZoneDef = _load_zone_entry_hall()
	var asm: FloorAssembler = FloorAssemblerScript.new()
	for s: int in [1, 7, 42, 99, 12345, 67890, 0xDEADBEEF, 0xC1DEDDED]:
		var floor: AssembledFloor = asm.assemble_floor(zone, s)
		assert_true(
			floor.is_well_mated(),
			"seed %d: port_mating_errors=%s" % [s, str(floor.port_mating_errors)]
		)
		assert_false(floor.is_empty(), "seed %d: placed_chunks must be non-empty" % s)


func test_s2_z2_clean_mating_across_8_seeds() -> void:
	var zone: ZoneDef = _load_zone_reading_chamber()
	var asm: FloorAssembler = FloorAssemblerScript.new()
	for s: int in [1, 7, 42, 99, 12345, 67890, 0xDEADBEEF, 0xC1DEDDED]:
		var floor: AssembledFloor = asm.assemble_floor(zone, s)
		assert_true(
			floor.is_well_mated(),
			"seed %d: port_mating_errors=%s" % [s, str(floor.port_mating_errors)]
		)


func test_s2_z3_clean_mating_across_8_seeds() -> void:
	var zone: ZoneDef = _load_zone_archive_vault()
	var asm: FloorAssembler = FloorAssemblerScript.new()
	for s: int in [1, 7, 42, 99, 12345, 67890, 0xDEADBEEF, 0xC1DEDDED]:
		var floor: AssembledFloor = asm.assemble_floor(zone, s)
		assert_true(
			floor.is_well_mated(),
			"seed %d: port_mating_errors=%s" % [s, str(floor.port_mating_errors)]
		)


func test_s2_z4_clean_mating_across_8_seeds() -> void:
	var zone: ZoneDef = _load_zone_inner_sanctum()
	var asm: FloorAssembler = FloorAssemblerScript.new()
	for s: int in [1, 7, 42, 99, 12345, 67890, 0xDEADBEEF, 0xC1DEDDED]:
		var floor: AssembledFloor = asm.assemble_floor(zone, s)
		assert_true(
			floor.is_well_mated(),
			"seed %d: port_mating_errors=%s" % [s, str(floor.port_mating_errors)]
		)


# ---- Mob-spawn mob_id resolves via MobRegistry --------------------


func _load_chunk(chunk_id: StringName) -> LevelChunkDef:
	# PlacedChunk carries chunk_id only (no chunk_def slot); resolve the
	# def via the standard res:// path convention per FloorAssembler.gd
	# `DEFAULT_CHUNK_ROOT = "res://resources/level_chunks/"`.
	return load("res://resources/level_chunks/%s.tres" % String(chunk_id))


func test_all_s2_chunk_mob_spawns_resolve_via_mob_registry() -> void:
	# Per ticket §F: "mob_spawn mob_ids resolve (MobRegistry.get_def(spawn.mob_id)
	# returns non-null for all spawns in S2 chunks)".
	# This walks the AssembledFloor of every S2 zone (assembled once each)
	# and asserts MobRegistry can resolve every mob_id in every placed
	# chunk's mob_spawns.
	var mob_registry: Node = get_tree().root.get_node_or_null("MobRegistry")
	assert_not_null(mob_registry, "MobRegistry autoload must be available")

	var zones: Array[ZoneDef] = [
		_load_zone_entry_hall(),
		_load_zone_reading_chamber(),
		_load_zone_archive_vault(),
		_load_zone_inner_sanctum(),
	]
	var asm: FloorAssembler = FloorAssemblerScript.new()

	for zone: ZoneDef in zones:
		var floor: AssembledFloor = asm.assemble_floor(zone, TEST_SEED)
		assert_false(floor.is_empty(), "zone %s: floor must be non-empty" % str(zone.zone_id))
		for placed: PlacedChunk in floor.placed_chunks:
			var chunk: LevelChunkDef = _load_chunk(placed.chunk_id)
			assert_not_null(
				chunk,
				"chunk %s must load from resources/level_chunks/" % str(placed.chunk_id)
			)
			for spawn: MobSpawnPoint in chunk.mob_spawns:
				assert_ne(spawn.mob_id, &"", "spawn.mob_id non-empty")
				assert_true(
					mob_registry.has_mob(spawn.mob_id),
					(
						"zone %s, chunk %s, spawn.mob_id %s: MobRegistry.has_mob must return true"
						% [str(zone.zone_id), str(chunk.id), str(spawn.mob_id)]
					)
				)
				var mob_def: MobDef = mob_registry.get_mob_def(spawn.mob_id)
				assert_not_null(
					mob_def,
					(
						"zone %s, chunk %s, spawn.mob_id %s: MobRegistry.get_mob_def must return non-null"
						% [str(zone.zone_id), str(chunk.id), str(spawn.mob_id)]
					)
				)


func test_s2_z3_archive_vault_introduces_bone_catalyst_mob_id() -> void:
	# Drift detector: per palette-stratum-2.md §1.6 + ticket Part C, the
	# Sponsor-locked Bone-Catalyst archetype MUST appear in s2_z3 (the
	# mid-zone where it's introduced). If the zone's pool gets refactored
	# to drop bone_catalyst-bearing chunks, this fails LOUDLY rather than
	# the archetype going missing silently.
	#
	# We assemble across multiple seeds and assert AT LEAST ONE seed lands
	# a bone_catalyst spawn — robust against the [0, 1] fill randomness
	# (some seeds may pick zero procedural fill, but s2_room06 in the
	# anchor IS guaranteed to carry bone_catalyst regardless of pool).
	var zone: ZoneDef = _load_zone_archive_vault()
	var asm: FloorAssembler = FloorAssemblerScript.new()
	var found_bone_catalyst: bool = false
	for s: int in [1, 7, 42, 99, 12345, 67890, 0xDEADBEEF, 0xC1DEDDED]:
		var floor: AssembledFloor = asm.assemble_floor(zone, s)
		for placed: PlacedChunk in floor.placed_chunks:
			var chunk: LevelChunkDef = _load_chunk(placed.chunk_id)
			for spawn: MobSpawnPoint in chunk.mob_spawns:
				if spawn.mob_id == &"bone_catalyst":
					found_bone_catalyst = true
					break
			if found_bone_catalyst:
				break
		if found_bone_catalyst:
			break
	assert_true(
		found_bone_catalyst,
		"s2_z3 must surface bone_catalyst across N=8 seeds (Stage 3 archetype binding)"
	)


func test_s2_z2_reading_chamber_introduces_sunken_scholar_mob_id() -> void:
	# Sibling drift detector for the Sunken-Scholar archetype binding in
	# z2 (the zone where it's introduced per palette-stratum-2.md §1.6 +
	# Stage 2 PR #364).
	var zone: ZoneDef = _load_zone_reading_chamber()
	var asm: FloorAssembler = FloorAssemblerScript.new()
	var found_scholar: bool = false
	for s: int in [1, 7, 42, 99, 12345, 67890, 0xDEADBEEF, 0xC1DEDDED]:
		var floor: AssembledFloor = asm.assemble_floor(zone, s)
		for placed: PlacedChunk in floor.placed_chunks:
			var chunk: LevelChunkDef = _load_chunk(placed.chunk_id)
			for spawn: MobSpawnPoint in chunk.mob_spawns:
				if spawn.mob_id == &"sunken_scholar":
					found_scholar = true
					break
			if found_scholar:
				break
		if found_scholar:
			break
	assert_true(
		found_scholar,
		"s2_z2 must surface sunken_scholar across N=8 seeds (Stage 2 archetype binding)"
	)


# ---- s1_z1 → s2_z1 exit-anchor mismatch fix pin ---------------------


func test_s1_z1_exit_target_zone_id_matches_s2_z1_entry_hall() -> void:
	# Stage 4 dispatch-brief checklist: resolve the s1_z1_outer_cloister
	# exit-anchor `target_zone_id` drift. Pre-Stage-4, s1_z1's exit
	# pointed at the pre-lock slug &"s2_z1_sunken_entrance"; post-fix,
	# it must point at the Sponsor-locked &"s2_z1_entry_hall".
	# This pins the fix against future regression — anyone re-naming
	# s2_z1 must update both sides + see this fail.
	var s1z1: ZoneDef = load("res://resources/level/zones/s1_z1_outer_cloister.tres")
	assert_not_null(s1z1, "s1_z1_outer_cloister.tres must load")
	var exit_anchors: Array[ZoneAnchor] = s1z1.get_anchors_of_kind(&"exit")
	assert_gt(exit_anchors.size(), 0, "s1_z1 must have ≥1 exit anchor")
	# The exit with a non-empty target_zone_id is the cross-stratum one.
	var found_cross_stratum_target: bool = false
	for ea: ZoneAnchor in exit_anchors:
		if ea.target_zone_id != &"":
			found_cross_stratum_target = true
			assert_eq(
				ea.target_zone_id,
				&"s2_z1_entry_hall",
				"s1_z1 cross-stratum exit must point at &\"s2_z1_entry_hall\" (Sponsor-locked S2 z1 slug)"
			)
	assert_true(
		found_cross_stratum_target,
		"s1_z1 must declare ≥1 exit anchor with cross-stratum target_zone_id"
	)
