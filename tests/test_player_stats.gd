extends GutTest
## Tests for the PlayerStats autoload (V/F/E character stats + banked
## level-up points).
##
## Per testing-bar: paired with feat(progression) — covers fresh-start
## defaults, add_stat increment, negative-input rejection, save round-
## trip, and the v2 -> v3 migration that backfills `character.stats`
## with default {0, 0, 0}.

const TEST_SLOT: int = 988


func _ps() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("PlayerStats")
	assert_not_null(n, "PlayerStats autoload must be registered in project.godot")
	return n


func _save() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("Save")
	assert_not_null(n, "Save autoload must be registered")
	return n


func before_each() -> void:
	_ps().reset()
	if _save().has_save(TEST_SLOT):
		_save().delete_save(TEST_SLOT)


func after_each() -> void:
	_ps().reset()
	if _save().has_save(TEST_SLOT):
		_save().delete_save(TEST_SLOT)


# --- Fresh-start defaults ----------------------------------------------

func test_default_stats_are_zero() -> void:
	# Per Uma + decision: 0/0/0 at fresh start, 0 unspent.
	assert_eq(_ps().get_stat(&"vigor"), 0, "vigor defaults to 0")
	assert_eq(_ps().get_stat(&"focus"), 0, "focus defaults to 0")
	assert_eq(_ps().get_stat(&"edge"), 0, "edge defaults to 0")
	assert_eq(_ps().get_unspent_points(), 0, "unspent defaults to 0")


# --- add_stat correctness ----------------------------------------------

func test_add_stat_increments_correctly() -> void:
	watch_signals(_ps())
	assert_true(_ps().add_stat(&"vigor", 1))
	assert_eq(_ps().get_stat(&"vigor"), 1, "vigor incremented by 1")
	assert_eq(_ps().get_stat(&"focus"), 0, "focus unchanged")
	assert_eq(_ps().get_stat(&"edge"), 0, "edge unchanged")
	assert_signal_emit_count(_ps(), "stat_changed", 1)
	# Multi-increment.
	_ps().add_stat(&"vigor", 4)
	assert_eq(_ps().get_stat(&"vigor"), 5, "vigor +1 then +4 = 5")


func test_add_stat_focus_only_changes_focus() -> void:
	_ps().add_stat(&"focus", 3)
	assert_eq(_ps().get_stat(&"focus"), 3)
	assert_eq(_ps().get_stat(&"vigor"), 0)
	assert_eq(_ps().get_stat(&"edge"), 0)


func test_add_stat_edge_only_changes_edge() -> void:
	_ps().add_stat(&"edge", 7)
	assert_eq(_ps().get_stat(&"edge"), 7)
	assert_eq(_ps().get_stat(&"vigor"), 0)
	assert_eq(_ps().get_stat(&"focus"), 0)


func test_add_stat_zero_is_silent_noop() -> void:
	watch_signals(_ps())
	assert_true(_ps().add_stat(&"vigor", 0))
	assert_eq(_ps().get_stat(&"vigor"), 0)
	assert_signal_emit_count(_ps(), "stat_changed", 0,
		"add_stat(0) must NOT fire stat_changed")


# --- Negative inputs rejected ------------------------------------------

func test_negative_add_is_rejected() -> void:
	watch_signals(_ps())
	_ps().add_stat(&"vigor", 5)
	var ok: bool = _ps().add_stat(&"vigor", -3)
	assert_false(ok, "add_stat with negative returns false")
	assert_eq(_ps().get_stat(&"vigor"), 5,
		"negative add must NOT decrement the stat")
	# Only the positive add fired stat_changed.
	assert_signal_emit_count(_ps(), "stat_changed", 1)


func test_unknown_stat_is_rejected() -> void:
	var ok: bool = _ps().add_stat(&"luck", 1)
	assert_false(ok, "unknown stat is rejected")
	# Reads on unknown stat return 0.
	assert_eq(_ps().get_stat(&"luck"), 0)


# --- Unspent points bank -----------------------------------------------

func test_add_unspent_points_increments() -> void:
	watch_signals(_ps())
	_ps().add_unspent_points(2)
	assert_eq(_ps().get_unspent_points(), 2)
	_ps().add_unspent_points(1)
	assert_eq(_ps().get_unspent_points(), 3)
	assert_signal_emit_count(_ps(), "unspent_points_changed", 2)


func test_spend_unspent_point_decrements_and_gates() -> void:
	_ps().add_unspent_points(2)
	assert_true(_ps().spend_unspent_point(), "spend succeeds when bank > 0")
	assert_eq(_ps().get_unspent_points(), 1)
	assert_true(_ps().spend_unspent_point())
	assert_eq(_ps().get_unspent_points(), 0)
	# Empty bank rejects further spends.
	assert_false(_ps().spend_unspent_point(),
		"spend returns false when bank is empty")


func test_negative_unspent_add_rejected() -> void:
	_ps().add_unspent_points(-2)
	assert_eq(_ps().get_unspent_points(), 0,
		"negative add_unspent_points doesn't subtract from bank")


# --- Save round-trip ----------------------------------------------------

func test_snapshot_to_character_writes_stats_block() -> void:
	_ps().add_stat(&"vigor", 3)
	_ps().add_stat(&"focus", 1)
	_ps().add_stat(&"edge", 5)
	_ps().add_unspent_points(2)
	var character: Dictionary = {}
	_ps().snapshot_to_character(character)
	assert_true(character.has("stats"))
	assert_eq(character["stats"]["vigor"], 3)
	assert_eq(character["stats"]["focus"], 1)
	assert_eq(character["stats"]["edge"], 5)
	assert_eq(character["unspent_stat_points"], 2)


func test_restore_from_character_loads_stats() -> void:
	var character: Dictionary = {
		"stats": {"vigor": 4, "focus": 2, "edge": 6},
		"unspent_stat_points": 3,
	}
	_ps().restore_from_character(character)
	assert_eq(_ps().get_stat(&"vigor"), 4)
	assert_eq(_ps().get_stat(&"focus"), 2)
	assert_eq(_ps().get_stat(&"edge"), 6)
	assert_eq(_ps().get_unspent_points(), 3)


func test_restore_handles_missing_stats_block() -> void:
	# Defensive — a partially-formed save must not crash; defaults to 0.
	_ps().restore_from_character({})
	assert_eq(_ps().get_stat(&"vigor"), 0)
	assert_eq(_ps().get_unspent_points(), 0)


func test_save_round_trip_preserves_values() -> void:
	# Fresh PS, allocate, snapshot into save, save_game, load_game,
	# restore — expect the same values back.
	_ps().add_stat(&"vigor", 2)
	_ps().add_stat(&"edge", 7)
	_ps().add_unspent_points(1)
	var data: Dictionary = _save().default_payload()
	_ps().snapshot_to_character(data["character"])
	assert_true(_save().save_game(TEST_SLOT, data))
	# Drop runtime state, reload from disk, restore back.
	_ps().reset()
	assert_eq(_ps().get_stat(&"vigor"), 0)
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	_ps().restore_from_character(loaded["character"])
	assert_eq(_ps().get_stat(&"vigor"), 2,
		"save round-trip preserves vigor")
	assert_eq(_ps().get_stat(&"edge"), 7,
		"save round-trip preserves edge")
	assert_eq(_ps().get_unspent_points(), 1,
		"save round-trip preserves banked points")


# --- v2 -> v3 migration -------------------------------------------------

func test_v2_to_v3_migration_adds_stats_field_with_defaults() -> void:
	# Build a v2-shaped character block (no `stats`, no `unspent_stat_points`,
	# but with the v2 flat vigor/focus/edge fields).
	var v2_data: Dictionary = {
		"character": {
			"name": "Old-Knight",
			"level": 3,
			"xp": 100,
			"xp_to_next": 519,
			"vigor": 2,
			"focus": 1,
			"edge": 0,
			"hp_current": 95,
			"hp_max": 110,
		},
		"stash": [],
		"equipped": {},
		"meta": {"runs_completed": 0, "deepest_stratum": 1, "total_playtime_sec": 0.0},
	}
	# Migrate v2 -> current.
	var migrated: Dictionary = _save().migrate(v2_data, 2)
	# `stats` block must be present, defaults 0/0/0 unless v2 flat fields lift in.
	assert_true(migrated["character"].has("stats"))
	assert_eq(migrated["character"]["stats"]["vigor"], 2,
		"v2 flat vigor lifts into stats.vigor")
	assert_eq(migrated["character"]["stats"]["focus"], 1)
	assert_eq(migrated["character"]["stats"]["edge"], 0)
	# Unspent points default to 0.
	assert_true(migrated["character"].has("unspent_stat_points"))
	assert_eq(migrated["character"]["unspent_stat_points"], 0)
	# first_level_up_seen defaults false.
	assert_eq(migrated["character"]["first_level_up_seen"], false)


func test_v2_to_v3_with_no_flat_fields_defaults_to_zero() -> void:
	# A v2 save that somehow didn't have the flat vigor/focus/edge (rare;
	# they were in DEFAULT_PAYLOAD since v0). Migration must default to 0.
	var v2_data: Dictionary = {
		"character": {
			"name": "Edge-Case-Knight",
			"level": 1,
			"xp": 0,
			"xp_to_next": 100,
			"hp_current": 100,
			"hp_max": 100,
		},
	}
	var migrated: Dictionary = _save().migrate(v2_data, 2)
	assert_eq(migrated["character"]["stats"]["vigor"], 0)
	assert_eq(migrated["character"]["stats"]["focus"], 0)
	assert_eq(migrated["character"]["stats"]["edge"], 0)
	assert_eq(migrated["character"]["unspent_stat_points"], 0)


func test_v0_migration_chains_through_to_v3() -> void:
	# A v0 save (pre-meta) must chain through v0->v1->v2->v3 cleanly. The
	# v0->v1 step backfills meta/equipped/stash/character; v1->v2 backfills
	# xp_to_next; v2->v3 backfills stats/unspent.
	var v0_data: Dictionary = {
		"character": {"name": "Ancient", "level": 2, "xp": 50, "vigor": 1, "focus": 0, "edge": 0, "hp_current": 80, "hp_max": 105},
	}
	var migrated: Dictionary = _save().migrate(v0_data, 0)
	assert_true(migrated.has("meta"), "v0->v1 backfilled meta")
	assert_true(migrated["character"].has("xp_to_next"), "v1->v2 backfilled xp_to_next")
	assert_true(migrated["character"].has("stats"), "v2->v3 backfilled stats")
	assert_eq(migrated["character"]["stats"]["vigor"], 1,
		"v0 flat vigor=1 chained through to v3 stats.vigor")
