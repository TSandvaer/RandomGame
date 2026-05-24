# gdlint:disable=max-public-methods
# GUT test class — high test_* count IS the design (one test per scenario).
extends GutTest
## Tests for `ZoneDef` + `ZoneAnchor` + the worked-example
## `s1_z1_outer_cloister.tres` (M3 Tier 3 W1 zone-schema spike, ticket
## 86c9xuap4).
##
## Scope per the spike ticket: Resource-load smoke + field-read +
## `validate()` invariants. The procgen runtime (`assemble_floor`) lands
## in sibling ticket 86c9xub9p and adds its own integration tests; this
## file pins the data-shape contract only.
##
## Cross-references:
##   team/drew-dev/level-chunks.md § "Zone schema"
##   team/priya-pl/post-wave3-sequencing.md v1.1 §1 Commitments 3 + 5

const ZoneDefScript: Script = preload("res://resources/level/ZoneDef.gd")
const ZoneAnchorScript: Script = preload("res://resources/level/ZoneAnchor.gd")


# `.tres` files containing nested scripted sub-resources (9 ZoneAnchor
# sub-resources here) fail to resolve via parse-time `preload(...)` — the
# const binds to null. Route through runtime `load(...)` via this helper
# instead. See `.claude/docs/test-conventions.md` § "preload of .tres with
# nested scripted sub-resources fails at parse-time (PR #357 lesson)".
func _load_outer_cloister_zone() -> ZoneDef:
	return load("res://resources/level/zones/s1_z1_outer_cloister.tres")

# ---- Helpers ---------------------------------------------------------


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


func _make_zone(
	zone_id: StringName = &"s1_z1_test", display_name: String = "Test Zone", stratum_id: int = 1
) -> ZoneDef:
	var z: ZoneDef = ZoneDefScript.new()
	z.zone_id = zone_id
	z.display_name = display_name
	z.stratum_id = stratum_id
	return z


func _well_formed_anchors() -> Array[ZoneAnchor]:
	var entry: ZoneAnchor = _make_anchor(&"r_entry", &"s1_room01", &"entry")
	var exit: ZoneAnchor = _make_anchor(&"r_exit", &"s1_room08", &"exit")
	var out: Array[ZoneAnchor] = []
	out.append(entry)
	out.append(exit)
	return out


# ---- ZoneAnchor shape -----------------------------------------------


func test_anchor_known_kinds_round_trip() -> void:
	# Class-doc taxonomy is exhaustive — pin every kind round-trips.
	for kind: StringName in ZoneAnchorScript.KINDS:
		assert_true(
			ZoneAnchorScript.is_known_kind(kind), "%s must be in ZoneAnchor.KINDS" % str(kind)
		)
	# Random unknown kind rejected.
	assert_false(
		ZoneAnchorScript.is_known_kind(&"not_a_real_kind"), "unknown kind must be rejected"
	)


func test_anchor_validate_passes_on_well_formed() -> void:
	var a: ZoneAnchor = _make_anchor(&"r_x", &"s1_room01", &"entry")
	var errors: Array[String] = a.validate()
	assert_eq(errors.size(), 0, "well-formed anchor yields zero errors: %s" % str(errors))


func test_anchor_validate_catches_empty_room_id() -> void:
	var a: ZoneAnchor = _make_anchor(&"", &"s1_room01", &"entry")
	var errors: Array[String] = a.validate()
	assert_gt(errors.size(), 0, "empty room_id must error")


func test_anchor_validate_catches_empty_chunk_id() -> void:
	var a: ZoneAnchor = _make_anchor(&"r_x", &"", &"entry")
	var errors: Array[String] = a.validate()
	assert_gt(errors.size(), 0, "empty chunk_id must error")


func test_anchor_validate_catches_unknown_kind() -> void:
	var a: ZoneAnchor = _make_anchor(&"r_x", &"s1_room01", &"bogus_kind")
	var errors: Array[String] = a.validate()
	assert_gt(errors.size(), 0, "unknown anchor_kind must error")


func test_anchor_validate_catches_target_zone_on_non_exit() -> void:
	# target_zone_id is meaningful only on exit anchors; setting it on
	# (e.g.) an npc_room is almost certainly a typo and must be caught.
	var a: ZoneAnchor = _make_anchor(&"r_x", &"s1_room02", &"npc_room", &"s2_z1_somewhere")
	var errors: Array[String] = a.validate()
	assert_gt(errors.size(), 0, "target_zone_id on non-exit must error")


# ---- ZoneDef shape --------------------------------------------------


func test_zone_validate_passes_on_well_formed() -> void:
	var z: ZoneDef = _make_zone()
	z.anchors = _well_formed_anchors()
	z.procedural_slot_pool = [&"s1_room03"]
	var errors: Array[String] = z.validate()
	assert_eq(errors.size(), 0, "well-formed zone yields zero errors: %s" % str(errors))


func test_zone_validate_catches_empty_zone_id() -> void:
	var z: ZoneDef = _make_zone(&"")
	z.anchors = _well_formed_anchors()
	z.procedural_slot_pool = [&"s1_room03"]
	assert_gt(z.validate().size(), 0, "empty zone_id must error")


func test_zone_validate_catches_empty_display_name() -> void:
	var z: ZoneDef = _make_zone(&"s1_z_x", "")
	z.anchors = _well_formed_anchors()
	z.procedural_slot_pool = [&"s1_room03"]
	assert_gt(z.validate().size(), 0, "empty display_name must error")


func test_zone_validate_catches_out_of_range_stratum() -> void:
	var z: ZoneDef = _make_zone(&"s9_z_x", "Test", 9)
	z.anchors = _well_formed_anchors()
	z.procedural_slot_pool = [&"s1_room03"]
	assert_gt(z.validate().size(), 0, "stratum_id > 8 must error")


func test_zone_validate_requires_exactly_one_entry_anchor() -> void:
	var z: ZoneDef = _make_zone()
	# Two entries → error.
	z.anchors = [
		_make_anchor(&"r_a", &"s1_room01", &"entry"),
		_make_anchor(&"r_b", &"s1_room02", &"entry"),
		_make_anchor(&"r_c", &"s1_room08", &"exit"),
	]
	z.procedural_slot_pool = [&"s1_room03"]
	assert_gt(z.validate().size(), 0, "two entry anchors must error")
	# Zero entries → error.
	z.anchors = [_make_anchor(&"r_c", &"s1_room08", &"exit")]
	assert_gt(z.validate().size(), 0, "zero entry anchors must error")


func test_zone_validate_requires_at_least_one_exit_anchor() -> void:
	var z: ZoneDef = _make_zone()
	z.anchors = [_make_anchor(&"r_a", &"s1_room01", &"entry")]
	z.procedural_slot_pool = [&"s1_room03"]
	assert_gt(z.validate().size(), 0, "zero exit anchors must error")


func test_zone_validate_catches_duplicate_room_id() -> void:
	var z: ZoneDef = _make_zone()
	z.anchors = [
		_make_anchor(&"r_dup", &"s1_room01", &"entry"),
		_make_anchor(&"r_dup", &"s1_room08", &"exit"),
	]
	z.procedural_slot_pool = [&"s1_room03"]
	assert_gt(z.validate().size(), 0, "duplicate room_id must error")


func test_zone_validate_catches_exit_self_loop() -> void:
	var z: ZoneDef = _make_zone(&"s1_z_self")
	z.anchors = [
		_make_anchor(&"r_a", &"s1_room01", &"entry"),
		_make_anchor(&"r_b", &"s1_room08", &"exit", &"s1_z_self"),
	]
	z.procedural_slot_pool = [&"s1_room03"]
	assert_gt(z.validate().size(), 0, "exit target_zone_id self-loop must error")


func test_zone_validate_catches_slot_range_inversion() -> void:
	var z: ZoneDef = _make_zone()
	z.anchors = _well_formed_anchors()
	z.procedural_slot_pool = [&"s1_room03"]
	z.min_slots_between_anchors = 3
	z.max_slots_between_anchors = 1
	assert_gt(z.validate().size(), 0, "max < min must error")


func test_zone_validate_catches_empty_pool_when_max_nonzero() -> void:
	var z: ZoneDef = _make_zone()
	z.anchors = _well_formed_anchors()
	z.procedural_slot_pool = []
	z.min_slots_between_anchors = 1
	z.max_slots_between_anchors = 3
	assert_gt(
		z.validate().size(),
		0,
		"empty pool with max_slots > 0 must error (assembler has nothing to draw)"
	)


func test_zone_validate_accepts_empty_pool_when_max_zero() -> void:
	# All-hand-authored zone (no procedural fill) — empty pool is legal.
	var z: ZoneDef = _make_zone()
	z.anchors = _well_formed_anchors()
	z.procedural_slot_pool = []
	z.min_slots_between_anchors = 0
	z.max_slots_between_anchors = 0
	assert_eq(z.validate().size(), 0, "empty pool with max=0 is legal: %s" % str(z.validate()))


# ---- ZoneDef helpers ------------------------------------------------


func test_zone_get_anchors_of_kind_filters() -> void:
	var z: ZoneDef = _make_zone()
	z.anchors = [
		_make_anchor(&"r_a", &"s1_room01", &"entry"),
		_make_anchor(&"r_b", &"s1_room02", &"npc_room"),
		_make_anchor(&"r_c", &"s1_room04", &"npc_room"),
		_make_anchor(&"r_d", &"s1_room08", &"exit"),
	]
	assert_eq(z.get_anchors_of_kind(&"entry").size(), 1)
	assert_eq(z.get_anchors_of_kind(&"npc_room").size(), 2)
	assert_eq(z.get_anchors_of_kind(&"boss_room").size(), 0)


func test_zone_get_entry_anchor_returns_first_entry() -> void:
	var z: ZoneDef = _make_zone()
	var entry: ZoneAnchor = _make_anchor(&"r_a", &"s1_room01", &"entry")
	z.anchors = [entry, _make_anchor(&"r_c", &"s1_room08", &"exit")]
	assert_eq(z.get_entry_anchor(), entry)


func test_zone_has_anchor_finds_by_room_id() -> void:
	var z: ZoneDef = _make_zone()
	z.anchors = _well_formed_anchors()
	assert_true(z.has_anchor(&"r_entry"))
	assert_true(z.has_anchor(&"r_exit"))
	assert_false(z.has_anchor(&"r_missing"))


# ---- Worked-example .tres round-trip -------------------------------


func test_authored_s1_z1_outer_cloister_loads() -> void:
	var z: ZoneDef = _load_outer_cloister_zone()
	assert_not_null(z, "s1_z1_outer_cloister.tres must load as ZoneDef")
	assert_eq(z.zone_id, &"s1_z1_outer_cloister")
	assert_eq(z.display_name, "Outer Cloister")
	assert_eq(z.stratum_id, 1)


func test_authored_s1_z1_outer_cloister_validates() -> void:
	var z: ZoneDef = _load_outer_cloister_zone()
	var errors: Array[String] = z.validate()
	assert_eq(errors.size(), 0, "s1_z1_outer_cloister.tres must validate cleanly: %s" % str(errors))


func test_authored_s1_z1_outer_cloister_has_nine_anchors() -> void:
	# W2-T3 retrofit (`86c9y1045`) — the production S1 zone now declares
	# all 8 S1 chunks (room08 used twice: boss_room + exit) for a total
	# of 9 anchors. The spike's original 5-anchor count is preserved in
	# git history as the pre-retrofit shape.
	var z: ZoneDef = _load_outer_cloister_zone()
	assert_eq(
		z.anchors.size(),
		9,
		"W2-T3 retrofit pins 9 anchors (8 unique chunks; room08 used for boss + exit)"
	)
	# Kind tallies per the (b)-lock narrative arc.
	assert_eq(z.get_anchors_of_kind(&"entry").size(), 1, "exactly 1 entry anchor")
	assert_eq(
		z.get_anchors_of_kind(&"npc_room").size(),
		2,
		"2 npc_room anchors (Antechamber + Hallowed Spring)"
	)
	assert_eq(
		z.get_anchors_of_kind(&"story_beat").size(),
		3,
		"3 story_beat anchors (Charger's Run / Crossfire / Pincer)"
	)
	assert_eq(
		z.get_anchors_of_kind(&"quest_target").size(), 1, "1 quest_target anchor (Marksman's Perch)"
	)
	assert_eq(z.get_anchors_of_kind(&"boss_room").size(), 1, "1 boss_room anchor")
	assert_eq(z.get_anchors_of_kind(&"exit").size(), 1, "1 exit anchor")


func test_authored_s1_z1_outer_cloister_anchor_chunks_resolve() -> void:
	# Each anchor's chunk_id must reference a real LevelChunkDef under
	# resources/level_chunks/. Acts as a content cross-check + catches
	# typos in the worked example.
	var z: ZoneDef = _load_outer_cloister_zone()
	for a: ZoneAnchor in z.anchors:
		var path: String = "res://resources/level_chunks/%s.tres" % str(a.chunk_id)
		var chunk: Resource = load(path)
		assert_not_null(
			chunk,
			"anchor %s chunk_id %s must resolve to %s" % [str(a.room_id), str(a.chunk_id), path]
		)


func test_authored_s1_z1_outer_cloister_pool_chunks_resolve() -> void:
	# Each procedural_slot_pool entry must reference a real chunk too.
	# W2-T3 retrofit (`86c9y1045`) — pool shrank from 4 to 3 per the SI-8
	# (b) "light procedural fill" commitment (smaller pool + slot range
	# [0,1] vs spike's [1,3]).
	var z: ZoneDef = _load_outer_cloister_zone()
	assert_eq(
		z.procedural_slot_pool.size(),
		3,
		"W2-T3 retrofit pins 3-chunk procedural pool (rooms 03/05/07)"
	)
	for chunk_id: StringName in z.procedural_slot_pool:
		var path: String = "res://resources/level_chunks/%s.tres" % str(chunk_id)
		var chunk: Resource = load(path)
		assert_not_null(
			chunk, "procedural_slot_pool entry %s must resolve to %s" % [str(chunk_id), path]
		)


func test_authored_s1_z1_outer_cloister_exit_targets_s2() -> void:
	# Cross-zone transition: exit anchor declares target_zone_id pointing
	# at S2's first zone. Until S2 zones land in W3, the assembler treats
	# unresolved target_zone_ids as terminal exits (documented in
	# level-chunks.md § "Cross-zone transitions").
	var z: ZoneDef = _load_outer_cloister_zone()
	var exits: Array[ZoneAnchor] = z.get_anchors_of_kind(&"exit")
	assert_eq(exits.size(), 1)
	assert_eq(
		exits[0].target_zone_id,
		&"s2_z1_sunken_entrance",
		"S1 z1 exit must declare cross-zone target into S2"
	)
