extends GutTest
## Unit tests for the `StratumProgression` autoload — paired with
## `scripts/progression/StratumProgression.gd`. Covers the four points from
## the dispatch spec:
##   1. Empty progression on fresh start.
##   2. Marking a room cleared persists across save/load (uses Save autoload).
##   3. Run reset (player death) clears progression.
##   4. Descend preserves progression.

const TEST_SLOT: int = 998


func before_each() -> void:
	# Always start each test with empty in-memory progression.
	_sp().reset()
	# And no on-disk save in our test slot, so save/load round-trips don't
	# pick up state from a prior test or dev save.
	if _save().has_save(TEST_SLOT):
		_save().delete_save(TEST_SLOT)


func after_each() -> void:
	_sp().reset()
	if _save().has_save(TEST_SLOT):
		_save().delete_save(TEST_SLOT)


# ---- Autoload accessors --------------------------------------------

func _sp() -> Node:
	var sp: Node = Engine.get_main_loop().root.get_node_or_null("StratumProgression")
	assert_not_null(sp, "StratumProgression autoload must be registered")
	return sp


func _save() -> Node:
	var s: Node = Engine.get_main_loop().root.get_node_or_null("Save")
	assert_not_null(s, "Save autoload must be registered")
	return s


# ---- 1. Empty progression on fresh start ---------------------------

func test_empty_on_fresh_start() -> void:
	# After before_each().reset(), nothing should be cleared.
	assert_eq(_sp().call("cleared_count"), 0, "no rooms cleared at start")
	assert_false(_sp().call("is_cleared", &"s1_room02"), "room02 not cleared at start")
	assert_eq((_sp().call("cleared_room_ids") as Array).size(), 0)


func test_empty_string_room_id_rejected() -> void:
	_sp().call("mark_cleared", &"")
	assert_eq(_sp().call("cleared_count"), 0, "empty room_id is a no-op")


# ---- General API behavior -----------------------------------------

func test_mark_cleared_records_room() -> void:
	_sp().call("mark_cleared", &"s1_room02")
	assert_true(_sp().call("is_cleared", &"s1_room02"))
	assert_eq(_sp().call("cleared_count"), 1)


func test_mark_cleared_is_idempotent() -> void:
	_sp().call("mark_cleared", &"s1_room02")
	_sp().call("mark_cleared", &"s1_room02")
	_sp().call("mark_cleared", &"s1_room02")
	assert_eq(_sp().call("cleared_count"), 1, "duplicate marks counted once")


func test_room_cleared_signal_fires_on_first_mark() -> void:
	watch_signals(_sp())
	_sp().call("mark_cleared", &"s1_room03")
	_sp().call("mark_cleared", &"s1_room03")  # idempotent, no second emit
	assert_signal_emit_count(_sp(), "room_cleared", 1, "fires exactly once per unique room_id")


func test_cleared_room_ids_returns_full_set() -> void:
	_sp().call("mark_cleared", &"s1_room02")
	_sp().call("mark_cleared", &"s1_room04")
	_sp().call("mark_cleared", &"s1_room07")
	var ids: Array[StringName] = _sp().call("cleared_room_ids") as Array[StringName]
	assert_eq(ids.size(), 3)
	assert_true(&"s1_room02" in ids)
	assert_true(&"s1_room04" in ids)
	assert_true(&"s1_room07" in ids)


# ---- 2. Persistence across save/load (Save.gd round-trip) ----------

func test_progression_round_trips_through_save() -> void:
	# Mark a few rooms in this run.
	_sp().call("mark_cleared", &"s1_room02")
	_sp().call("mark_cleared", &"s1_room03")
	_sp().call("mark_cleared", &"s1_room04")
	# Snapshot into the save payload.
	var data: Dictionary = _save().call("default_payload")
	_sp().call("snapshot_to_save_data", data)
	# Persist + reload via the Save autoload — exercises the JSON path.
	assert_true(_save().call("save_game", TEST_SLOT, data), "save_game succeeds")
	var loaded: Dictionary = _save().call("load_game", TEST_SLOT)
	assert_false(loaded.is_empty(), "load_game returns non-empty dict")
	# Wipe in-memory progression then restore from the loaded dict.
	_sp().call("reset")
	assert_eq(_sp().call("cleared_count"), 0)
	_sp().call("restore_from_save_data", loaded)
	# Same three rooms should be back.
	assert_eq(_sp().call("cleared_count"), 3, "round-tripped room count matches")
	assert_true(_sp().call("is_cleared", &"s1_room02"))
	assert_true(_sp().call("is_cleared", &"s1_room03"))
	assert_true(_sp().call("is_cleared", &"s1_room04"))
	assert_false(_sp().call("is_cleared", &"s1_room05"), "untouched room stays uncleared")


func test_restore_from_save_with_no_progression_key_is_safe() -> void:
	# Older saves don't have the "stratum_progression" key. Restore should
	# yield empty progression (and not crash).
	var legacy_data: Dictionary = _save().call("default_payload")
	# legacy_data has no "stratum_progression" entry.
	_sp().call("restore_from_save_data", legacy_data)
	assert_eq(_sp().call("cleared_count"), 0, "legacy save loads as empty progression")


func test_restore_from_save_tolerates_garbage() -> void:
	var bad: Dictionary = {"stratum_progression": "not a dict"}
	# Should not crash, should not modify state.
	_sp().call("restore_from_save_data", bad)
	assert_eq(_sp().call("cleared_count"), 0)


# ---- 3. Run reset (player death) clears progression ----------------

func test_reset_clears_progression() -> void:
	_sp().call("mark_cleared", &"s1_room02")
	_sp().call("mark_cleared", &"s1_room03")
	assert_eq(_sp().call("cleared_count"), 2)
	_sp().call("reset")
	assert_eq(_sp().call("cleared_count"), 0, "reset wipes all clears")
	assert_false(_sp().call("is_cleared", &"s1_room02"))


func test_reset_emits_progression_reset_signal() -> void:
	_sp().call("mark_cleared", &"s1_room02")
	watch_signals(_sp())
	_sp().call("reset")
	assert_signal_emitted(_sp(), "progression_reset")


func test_reset_idempotent() -> void:
	# Reset on already-empty progression: no crash, signal still fires
	# (so listeners can refresh UI deterministically).
	watch_signals(_sp())
	_sp().call("reset")
	assert_signal_emit_count(_sp(), "progression_reset", 1)


# ---- 4. Descend preserves progression ------------------------------

func test_descend_preserves_progression() -> void:
	# In M1 there's only one stratum so "descend" is a logical marker rather
	# than a floor change, but the contract is forward-compatible: when the
	# player descends, progression is NOT wiped.
	_sp().call("mark_cleared", &"s1_room02")
	_sp().call("mark_cleared", &"s1_room07")
	_sp().call("preserve_for_descend")
	# State is unchanged.
	assert_eq(_sp().call("cleared_count"), 2)
	assert_true(_sp().call("is_cleared", &"s1_room02"))
	assert_true(_sp().call("is_cleared", &"s1_room07"))


func test_descend_then_reset_distinguishes_correctly() -> void:
	# Sanity: descend + reset are independent ops. Descend keeps state;
	# reset wipes it. A run where the player descends then dies should
	# show exactly the post-reset shape (empty), proving reset overrides
	# preserve_for_descend's no-op.
	_sp().call("mark_cleared", &"s1_room02")
	_sp().call("preserve_for_descend")
	assert_eq(_sp().call("cleared_count"), 1)
	_sp().call("reset")
	assert_eq(_sp().call("cleared_count"), 0)


# ---- Cross-cut: round-trip survives a reset -----------------------

func test_save_then_reset_then_load_restores_state() -> void:
	# Walk the full lifecycle: clear, save, reset (sim death wipe), load
	# back, and confirm pre-reset state is restored. Pinning this protects
	# against a future mistake where reset() also clears the on-disk save.
	_sp().call("mark_cleared", &"s1_room02")
	_sp().call("mark_cleared", &"s1_room05")
	var data: Dictionary = _save().call("default_payload")
	_sp().call("snapshot_to_save_data", data)
	_save().call("save_game", TEST_SLOT, data)
	_sp().call("reset")
	assert_eq(_sp().call("cleared_count"), 0)
	var loaded: Dictionary = _save().call("load_game", TEST_SLOT)
	_sp().call("restore_from_save_data", loaded)
	assert_eq(_sp().call("cleared_count"), 2, "save persists across in-memory reset")
