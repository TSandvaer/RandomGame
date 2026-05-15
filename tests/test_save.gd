extends GutTest
## Tests for Save autoload — JSON round-trip, schema migration,
## crash-safe write, and the forward-compat invariants the testing
## bar singles out as the highest-risk M1 system.
##
## We exercise the autoload directly via the Engine.get_main_loop tree.
## All tests use slot 999 (cleaned up on each test) so we never collide
## with a real save in dev environments.

const TEST_SLOT: int = 999
const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")


# ---- Universal-warning gate (ticket 86c9uf0mm Half B) ----------------
##
## Save is the load-bearing surface the M2 RC soak meta-finding singled
## out — schema-newer-than-runtime + per-item migration warnings flow
## through Save.gd. Every test here gets the guard attached; tests that
## DELIBERATELY exercise a warning path must `expect_warning(pattern)`.

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()
	# Clean slate per test.
	if _save().has_save(TEST_SLOT):
		_save().delete_save(TEST_SLOT)
	# Also clean any leftover .tmp from a crashed prior test.
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
	# Get the autoload by name — it's registered as `Save` in project.godot.
	var save: Node = Engine.get_main_loop().root.get_node_or_null("Save")
	assert_not_null(save, "Save autoload must be registered")
	return save


# --- Round-trip ----------------------------------------------------------

func test_save_then_load_round_trips_default_payload() -> void:
	var ok: bool = _save().save_game(TEST_SLOT)
	assert_true(ok, "save_game must succeed with default payload")
	assert_true(_save().has_save(TEST_SLOT), "has_save returns true after save")

	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_false(loaded.is_empty(), "loaded dict not empty")
	assert_eq(loaded["character"]["level"], 1, "default level is 1")
	assert_eq(loaded["character"]["name"], "Ember-Knight")
	assert_eq(loaded["meta"]["deepest_stratum"], 1)


func test_save_then_load_round_trips_modified_payload() -> void:
	var data: Dictionary = _save().default_payload()
	data["character"]["level"] = 4
	data["character"]["xp"] = 1234
	data["character"]["vigor"] = 3
	data["stash"] = [
		{"id": "weapon_iron_sword", "tier": 2, "rolled_affixes": [{"affix_id": "swift", "value": 0.08}], "stack_count": 1},
	]
	data["meta"]["runs_completed"] = 7
	data["meta"]["deepest_stratum"] = 3

	assert_true(_save().save_game(TEST_SLOT, data))

	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_eq(loaded["character"]["level"], 4)
	assert_eq(loaded["character"]["xp"], 1234)
	assert_eq(loaded["character"]["vigor"], 3)
	assert_eq(loaded["stash"].size(), 1)
	assert_eq(loaded["stash"][0]["id"], "weapon_iron_sword")
	assert_eq(loaded["stash"][0]["rolled_affixes"][0]["affix_id"], "swift")
	assert_almost_eq(float(loaded["stash"][0]["rolled_affixes"][0]["value"]), 0.08, 1e-6)
	assert_eq(loaded["meta"]["runs_completed"], 7)
	assert_eq(loaded["meta"]["deepest_stratum"], 3)


func test_load_returns_empty_when_no_save() -> void:
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_true(loaded.is_empty(), "missing save -> {} (caller decides new-game vs error)")


func test_has_save_false_initially() -> void:
	assert_false(_save().has_save(TEST_SLOT))


func test_delete_save_removes_file() -> void:
	_save().save_game(TEST_SLOT)
	assert_true(_save().has_save(TEST_SLOT))
	assert_true(_save().delete_save(TEST_SLOT))
	assert_false(_save().has_save(TEST_SLOT))
	# Deleting a non-existent slot returns false (idempotent-but-honest).
	assert_false(_save().delete_save(TEST_SLOT))


# --- Schema versioning ---------------------------------------------------

func test_envelope_carries_schema_version_and_saved_at() -> void:
	_save().save_game(TEST_SLOT)
	var path: String = _save().save_path(TEST_SLOT)
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var raw: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	assert_true(parsed is Dictionary)
	# Schema is at v3 as of 2026-05-02 (added stats / unspent / first_level_up_seen).
	assert_eq(int(parsed["schema_version"]), 3, "envelope contains schema_version=3")
	assert_true(parsed.has("saved_at"))
	assert_true(parsed.has("data"))


# --- Forward-compat migration: v1 -> v2 ---------------------------------

func test_migrate_v1_save_to_v2_adds_xp_to_next() -> void:
	# Hand-author a v1 save: character has level/xp but no xp_to_next.
	var v1_envelope: Dictionary = {
		"schema_version": 1,
		"saved_at": "2026-05-02T10:00:00",
		"data": {
			"character": {
				"name": "Ember-Knight",
				"level": 3,
				"xp": 200,
				"vigor": 0, "focus": 0, "edge": 0,
				"hp_current": 100, "hp_max": 100,
			},
			"stash": [],
			"equipped": {},
			"meta": {"runs_completed": 0, "deepest_stratum": 1, "total_playtime_sec": 0.0},
		},
	}
	var f: FileAccess = FileAccess.open(_save().save_path(TEST_SLOT), FileAccess.WRITE)
	f.store_string(JSON.stringify(v1_envelope))
	f.close()

	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_true(loaded.has("character"))
	assert_true(loaded["character"].has("xp_to_next"),
		"v1 -> v2 migration adds xp_to_next to character")
	# Curve mirror in Save.gd: floor(100 * L^1.5) — at L=3, 519.
	assert_eq(loaded["character"]["xp_to_next"], 519)
	# Untouched fields preserved.
	assert_eq(loaded["character"]["level"], 3)
	assert_eq(loaded["character"]["xp"], 200)


func test_migrate_v0_save_chains_through_v2() -> void:
	# A v0 file (no schema_version, no meta) must end up at v2 — both
	# migrations chain. xp_to_next must be present after the chain.
	var v0_envelope: Dictionary = {
		"data": {
			"character": {"level": 2, "xp": 50},
		},
	}
	var f: FileAccess = FileAccess.open(_save().save_path(TEST_SLOT), FileAccess.WRITE)
	f.store_string(JSON.stringify(v0_envelope))
	f.close()
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	# v0 -> v1 added meta + equipped.
	assert_true(loaded.has("meta"))
	assert_true(loaded.has("equipped"))
	# v1 -> v2 added xp_to_next.
	assert_true(loaded["character"].has("xp_to_next"))
	# At L=2, xp_to_next = floor(100 * 2^1.5) = 282.
	assert_eq(loaded["character"]["xp_to_next"], 282)


# --- Forward-compat migration: v0 -> v1 ---------------------------------

func test_migrate_v0_save_to_v1_adds_meta_block() -> void:
	# Hand-author a pre-v1 file: no meta, no equipped, no schema_version.
	var v0_envelope: Dictionary = {
		"data": {
			"character": {"level": 3, "xp": 500},
			"stash": [{"id": "weapon_x", "tier": 1, "rolled_affixes": [], "stack_count": 1}],
		},
	}
	var f: FileAccess = FileAccess.open(_save().save_path(TEST_SLOT), FileAccess.WRITE)
	f.store_string(JSON.stringify(v0_envelope))
	f.close()

	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	# Migration must have added meta and equipped.
	assert_true(loaded.has("meta"), "v0 -> v1 migration adds 'meta' block")
	assert_eq(loaded["meta"]["deepest_stratum"], 1, "default deepest_stratum=1")
	assert_eq(loaded["meta"]["runs_completed"], 0)
	assert_true(loaded.has("equipped"), "v0 -> v1 migration adds 'equipped' map")
	# Untouched fields preserved.
	assert_eq(loaded["character"]["level"], 3)
	assert_eq(loaded["stash"].size(), 1)


func test_migrate_preserves_existing_fields() -> void:
	# v1 save reloaded — migration must be a no-op.
	var data: Dictionary = _save().default_payload()
	data["character"]["level"] = 5
	data["meta"]["runs_completed"] = 12
	_save().save_game(TEST_SLOT, data)
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_eq(loaded["character"]["level"], 5)
	assert_eq(loaded["meta"]["runs_completed"], 12)


func test_migrate_handles_save_from_future_schema() -> void:
	# Hand-author a save with schema_version=999. Should warn-and-pass-through.
	# The "schema_version is newer than runtime" warning is DELIBERATE on this
	# path (Save.migrate routes it through WarningBus per ticket 86c9uf0mm
	# Half B); opt the universal-warning gate out for this specific pattern.
	_warn_guard.expect_warning("is newer than runtime")
	var future_envelope: Dictionary = {
		"schema_version": 999,
		"saved_at": "2099-01-01T00:00:00",
		"data": {
			"character": {"level": 99, "xp": 1, "vigor": 1, "focus": 1, "edge": 1, "hp_current": 1, "hp_max": 1, "name": "Future"},
			"stash": [],
			"equipped": {},
			"meta": {"runs_completed": 1, "deepest_stratum": 8, "total_playtime_sec": 0.0},
			"unknown_future_field": ["lorem", "ipsum"],
		},
	}
	var f: FileAccess = FileAccess.open(_save().save_path(TEST_SLOT), FileAccess.WRITE)
	f.store_string(JSON.stringify(future_envelope))
	f.close()
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_eq(loaded["character"]["level"], 99)
	# Unknown field passes through, never crashes.
	assert_true(loaded.has("unknown_future_field"))


# --- Corruption resilience -----------------------------------------------

func test_load_returns_empty_on_corrupt_json() -> void:
	# Write garbage to the save path.
	var f: FileAccess = FileAccess.open(_save().save_path(TEST_SLOT), FileAccess.WRITE)
	f.store_string("{ this is not [valid json")
	f.close()
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_true(loaded.is_empty(), "corrupt JSON -> {}, never crash")


func test_load_returns_empty_on_root_not_dictionary() -> void:
	var f: FileAccess = FileAccess.open(_save().save_path(TEST_SLOT), FileAccess.WRITE)
	f.store_string("[1, 2, 3]")
	f.close()
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_true(loaded.is_empty())


# --- Atomic write --------------------------------------------------------

func test_atomic_write_overwrites_existing_file() -> void:
	var path: String = _save().save_path(TEST_SLOT)
	# First write.
	assert_true(_save().atomic_write(path, "first"))
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_eq(f.get_as_text(), "first")
	f.close()
	# Overwrite.
	assert_true(_save().atomic_write(path, "second"))
	f = FileAccess.open(path, FileAccess.READ)
	assert_eq(f.get_as_text(), "second")
	f.close()


func test_atomic_write_does_not_leave_tmp_on_success() -> void:
	var path: String = _save().save_path(TEST_SLOT)
	_save().atomic_write(path, "hello")
	var tmp: String = path + ".tmp"
	assert_false(FileAccess.file_exists(tmp), ".tmp must be renamed away on success")


# --- Default payload integrity -------------------------------------------

func test_default_payload_returns_independent_copies() -> void:
	# Mutating one default_payload() result must not affect a subsequent call.
	var a: Dictionary = _save().default_payload()
	a["character"]["level"] = 99
	a["stash"].append("contamination")
	var b: Dictionary = _save().default_payload()
	assert_eq(b["character"]["level"], 1, "default_payload deep-copies — level untouched")
	assert_eq(b["stash"].size(), 0, "default_payload deep-copies — stash untouched")


# --- Persistence roundtrip with deep nesting (regression for shallow copy bugs) ---

func test_deeply_nested_data_round_trips_exactly() -> void:
	var data: Dictionary = _save().default_payload()
	data["equipped"]["weapon"] = {
		"id": "weapon_flame_blade",
		"tier": 3,
		"rolled_affixes": [
			{"affix_id": "swift", "value": 0.12},
			{"affix_id": "burn", "value": 5},
		],
		"stack_count": 1,
	}
	_save().save_game(TEST_SLOT, data)
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_eq(loaded["equipped"]["weapon"]["id"], "weapon_flame_blade")
	assert_eq(loaded["equipped"]["weapon"]["tier"], 3)
	assert_eq(loaded["equipped"]["weapon"]["rolled_affixes"].size(), 2)
	assert_eq(loaded["equipped"]["weapon"]["rolled_affixes"][1]["affix_id"], "burn")
	assert_eq(loaded["equipped"]["weapon"]["rolled_affixes"][1]["value"], 5)
