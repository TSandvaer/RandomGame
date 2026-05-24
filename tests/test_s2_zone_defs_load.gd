extends GutTest
## W3-T7 Stage 1 — smoke tests for the 4 S2 ZoneDef.tres files authored
## per ticket `86c9y7ygj` Part A.
##
## Scope: Resource-load smoke + field-read + universal-warning-gate
## compliance. The 4 zone shells declare `zone_id` / `display_name` /
## `stratum_id` ONLY — `anchors` + `procedural_slot_pool` are intentionally
## empty pending Part C (chunk authoring); calling `validate()` would
## flag the missing entry/exit anchors, so we explicitly do NOT call
## `validate()` here. The brief's "smoke that each new ZoneDef.tres
## loads" is the contract — Part C ships the test pin that loads them
## via `validate()` once anchors are populated.
##
## Cross-references:
##   team/drew-dev/level-chunks.md § "S2 zone roster"
##   resources/level/ZoneDef.gd
##   .claude/docs/test-conventions.md § "Universal warning gate"

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

# Per the `preload`-of-.tres-with-scripted-resources trap documented in
# `.claude/docs/test-conventions.md` § "preload of .tres can bind to null
# at parse-time" (PR #357 lesson), route .tres loads through runtime
# `load(...)` rather than top-of-file `const PRELOAD := preload(...)`.
# These ZoneDef shells have NO scripted sub-resources (empty anchors
# array), so they are probably hoist-safe — but the trap mechanism is
# uninvestigated, so we follow the safe pattern by default.
const S2_ZONE_PATHS: Array[String] = [
	"res://resources/level/zones/s2_z1_entry_hall.tres",
	"res://resources/level/zones/s2_z2_reading_chamber.tres",
	"res://resources/level/zones/s2_z3_archive_vault.tres",
	"res://resources/level/zones/s2_z4_inner_sanctum.tres",
]

const S2_ZONE_EXPECTED: Array = [
	{"path": "res://resources/level/zones/s2_z1_entry_hall.tres",
		"zone_id": &"s2_z1_entry_hall", "display_name": "Entry Hall of the Archive"},
	{"path": "res://resources/level/zones/s2_z2_reading_chamber.tres",
		"zone_id": &"s2_z2_reading_chamber", "display_name": "Sunken Reading Chamber"},
	{"path": "res://resources/level/zones/s2_z3_archive_vault.tres",
		"zone_id": &"s2_z3_archive_vault", "display_name": "Archive Vault"},
	{"path": "res://resources/level/zones/s2_z4_inner_sanctum.tres",
		"zone_id": &"s2_z4_inner_sanctum", "display_name": "Inner Sanctum"},
]

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- Per-zone load smoke -------------------------------------------------


func test_s2_z1_entry_hall_loads_clean() -> void:
	var z: ZoneDef = load("res://resources/level/zones/s2_z1_entry_hall.tres")
	assert_not_null(z, "s2_z1_entry_hall.tres must load as ZoneDef")
	assert_eq(z.zone_id, &"s2_z1_entry_hall", "zone_id matches filename slug")
	assert_eq(z.display_name, "Entry Hall of the Archive", "display_name set")
	assert_ne(z.display_name, "", "display_name non-empty")
	assert_eq(z.stratum_id, 2, "stratum_id == 2 (S2)")


func test_s2_z2_reading_chamber_loads_clean() -> void:
	var z: ZoneDef = load("res://resources/level/zones/s2_z2_reading_chamber.tres")
	assert_not_null(z, "s2_z2_reading_chamber.tres must load as ZoneDef")
	assert_eq(z.zone_id, &"s2_z2_reading_chamber", "zone_id matches filename slug")
	assert_eq(z.display_name, "Sunken Reading Chamber", "display_name set")
	assert_ne(z.display_name, "", "display_name non-empty")
	assert_eq(z.stratum_id, 2, "stratum_id == 2 (S2)")


func test_s2_z3_archive_vault_loads_clean() -> void:
	var z: ZoneDef = load("res://resources/level/zones/s2_z3_archive_vault.tres")
	assert_not_null(z, "s2_z3_archive_vault.tres must load as ZoneDef")
	assert_eq(z.zone_id, &"s2_z3_archive_vault", "zone_id matches filename slug")
	assert_eq(z.display_name, "Archive Vault", "display_name set")
	assert_ne(z.display_name, "", "display_name non-empty")
	assert_eq(z.stratum_id, 2, "stratum_id == 2 (S2)")


func test_s2_z4_inner_sanctum_loads_clean() -> void:
	var z: ZoneDef = load("res://resources/level/zones/s2_z4_inner_sanctum.tres")
	assert_not_null(z, "s2_z4_inner_sanctum.tres must load as ZoneDef")
	assert_eq(z.zone_id, &"s2_z4_inner_sanctum", "zone_id matches filename slug")
	assert_eq(z.display_name, "Inner Sanctum", "display_name set")
	assert_ne(z.display_name, "", "display_name non-empty")
	assert_eq(z.stratum_id, 2, "stratum_id == 2 (S2)")


# ---- Cross-zone roster invariants ---------------------------------------


func test_all_s2_zone_ids_are_unique() -> void:
	# Roster sanity: a typo where two shells share a zone_id would silently
	# collide downstream in any zone_id → ZoneDef lookup map. Pin uniqueness
	# at the smoke layer.
	var seen: Dictionary = {}
	for entry in S2_ZONE_EXPECTED:
		var z: ZoneDef = load(entry["path"])
		assert_not_null(z, "%s must load" % entry["path"])
		assert_false(
			seen.has(z.zone_id),
			"duplicate zone_id %s across S2 zone shells" % str(z.zone_id)
		)
		seen[z.zone_id] = true
	assert_eq(seen.size(), S2_ZONE_EXPECTED.size(), "every S2 zone has a unique id")


func test_all_s2_zones_have_stratum_2() -> void:
	# Drift detector: a S2 shell with `stratum_id != 2` would be silently
	# placed in the wrong stratum_seed bucket by FloorAssembler.
	for entry in S2_ZONE_EXPECTED:
		var z: ZoneDef = load(entry["path"])
		assert_eq(z.stratum_id, 2, "%s must declare stratum_id == 2" % entry["path"])


func test_all_s2_zones_have_nonempty_display_name() -> void:
	# Map UI + quest log read display_name; empty would render blank cells.
	for entry in S2_ZONE_EXPECTED:
		var z: ZoneDef = load(entry["path"])
		assert_ne(z.display_name, "", "%s must have non-empty display_name" % entry["path"])


func test_all_s2_zone_ids_match_filename_slug() -> void:
	# Convention check: zone_id should match the filename slug per the
	# `s{stratum}_z{ordinal}_{slug}` convention in ZoneDef.gd docstring.
	# A drift here would mean save schema / quest .tres reference a key
	# that doesn't match the file on disk.
	for entry in S2_ZONE_EXPECTED:
		var z: ZoneDef = load(entry["path"])
		assert_eq(
			z.zone_id,
			entry["zone_id"],
			"%s zone_id must equal expected slug %s" % [entry["path"], str(entry["zone_id"])]
		)
