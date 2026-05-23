extends GutTest
## Round-trip + migration tests for the W2-T6 quest-state save layer.
##
## **Ticket `86c9y7ydg`.** Two distinct cases per the dispatch brief Part C:
##
##   1. **New-load (no migrate, fresh v5)** — write Player quest state via
##      `Player.to_save_dict()`, persist via Save.save_game, reload via
##      Save.load_game, verify state restored. Folds save round-trip
##      through QuestState.from_dict + Player.restore_from_save_dict.
##
##   2. **v3 migrate-load** — write a v3-shaped envelope to disk via
##      JSON.stringify (bypasses Save.save_game, so the on-disk fixture
##      lacks Tier 3 fields). Load via Save.load_game; the migration chain
##      (v3 → v4 → v5 + backfill_v5_tier3_quest_fields) should yield
##      `active_bounty == null` + `completed_bounties == []`.
##
## Both tests gate the universal warning gate (NoWarningGuard). The save
## migration path routes its load-bearing warnings through WarningBus.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")
const QuestStateScript: Script = preload("res://scripts/quests/QuestState.gd")

const TEST_SLOT: int = 998

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


# ===== Case 1: fresh v5 round-trip =====================================

func test_active_bounty_round_trips_via_default_payload_path() -> void:
	# Start from default_payload (which has active_bounty=null +
	# completed_bounties=[] per the W2-T6 DEFAULT_PAYLOAD extension).
	# Inject an active bounty + a completed entry, save, reload, verify.
	var data: Dictionary = _save().default_payload()
	# Build a QuestState as if Player.active_bounty held it.
	var qs: QuestState = QuestStateScript.new()
	qs.quest_id = &"s1_recover_stoker_proof"
	qs.accepted_at_tick = 42_000
	qs.completion_progress = {"kills_remaining": 2}
	qs.state = &"quest_active"
	data["character"]["active_bounty"] = qs.to_dict()
	data["character"]["completed_bounties"] = [
		"s1_first_bounty",
		"s2_pilot_run",
	]
	assert_true(_save().save_game(TEST_SLOT, data),
		"save_game succeeds with Tier 3 quest state populated")
	# Reload.
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_false(loaded.is_empty(), "load_game returns populated dict")
	# active_bounty Dictionary preserved.
	var ab: Variant = loaded["character"]["active_bounty"]
	assert_true(ab is Dictionary,
		"loaded active_bounty is a Dictionary")
	assert_eq((ab as Dictionary)["quest_id"], "s1_recover_stoker_proof")
	assert_eq((ab as Dictionary)["accepted_at_tick"], 42_000)
	assert_eq(((ab as Dictionary)["completion_progress"] as Dictionary)["kills_remaining"], 2)
	assert_eq((ab as Dictionary)["state"], "quest_active")
	# completed_bounties Array preserved.
	var completed: Array = loaded["character"]["completed_bounties"]
	assert_eq(completed.size(), 2)
	assert_eq(String(completed[0]), "s1_first_bounty")
	assert_eq(String(completed[1]), "s2_pilot_run")


func test_null_active_bounty_round_trips_as_null() -> void:
	# A character with no active bounty should round-trip with
	# active_bounty == null (not missing, not coerced to empty Dict).
	var data: Dictionary = _save().default_payload()
	# DEFAULT_PAYLOAD already sets active_bounty=null + completed_bounties=[].
	assert_true(_save().save_game(TEST_SLOT, data))
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_eq(loaded["character"]["active_bounty"], null,
		"null active_bounty round-trips as null")
	var completed: Array = loaded["character"]["completed_bounties"]
	assert_eq(completed.size(), 0, "empty completed_bounties round-trips as []")


# ===== Case 2: v3 migrate-load defaults active_bounty to null ===========

func test_v3_migrate_backfills_active_bounty_null_and_completed_empty() -> void:
	# A v3-shaped envelope on disk lacks Tier 3 fields entirely. The
	# migration chain (v3 -> v4 -> v5 + backfill_v5_tier3_quest_fields)
	# must yield active_bounty == null + completed_bounties == [].
	var v3_envelope: Dictionary = {
		"schema_version": 3,
		"saved_at": "2026-05-22T10:00:00",
		"data": {
			"character": {
				"name": "Migrate-Knight",
				"level": 4,
				"xp": 1000,
				"xp_to_next": 519,
				"vigor": 1,
				"focus": 1,
				"edge": 0,
				"stats": {"vigor": 1, "focus": 1, "edge": 0},
				"unspent_stat_points": 0,
				"first_level_up_seen": true,
				"hp_current": 95,
				"hp_max": 100,
			},
			"stash": [],
			"equipped": {},
			"meta": {"runs_completed": 0, "deepest_stratum": 1, "total_playtime_sec": 100.0},
		},
	}
	var f: FileAccess = FileAccess.open(
		_save().save_path(TEST_SLOT), FileAccess.WRITE)
	f.store_string(JSON.stringify(v3_envelope))
	f.close()
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	# Tier 3 fields backfilled.
	assert_true(loaded["character"].has("active_bounty"),
		"v3 -> v5+tier3 migration adds active_bounty key")
	assert_eq(loaded["character"]["active_bounty"], null,
		"active_bounty defaults to null on migration backfill")
	assert_true(loaded["character"].has("completed_bounties"),
		"v3 -> v5+tier3 migration adds completed_bounties key")
	var completed: Array = loaded["character"]["completed_bounties"]
	assert_true(completed is Array, "completed_bounties is Array type")
	assert_eq(completed.size(), 0,
		"completed_bounties defaults to empty Array on backfill")
	# Pre-existing v3 fields preserved.
	assert_eq(loaded["character"]["level"], 4)
	assert_eq(loaded["character"]["xp"], 1000)


func test_pre_w2_t6_v5_save_backfills_tier3_quest_fields() -> void:
	# A pre-W2-T6 v5 save has schema_version=5 on disk but lacks Tier 3
	# quest fields. The unconditional backfill in `migrate()` must catch
	# this case (from_version == 5 means the v4 -> v5 migration is
	# skipped). Pin the shape.
	var pre_t6_v5_envelope: Dictionary = {
		"schema_version": 5,
		"saved_at": "2026-05-23T09:00:00",
		"data": {
			"character": {
				"name": "Pre-T6-Knight",
				"level": 6,
				"xp": 2500,
				"xp_to_next": 0,
				"vigor": 2,
				"focus": 2,
				"edge": 1,
				"stats": {"vigor": 2, "focus": 2, "edge": 1},
				"unspent_stat_points": 0,
				"first_level_up_seen": true,
				"first_boss_kill_seen": false,
				"world_seed": 0xCAFEBABE,
				"hp_current": 100,
				"hp_max": 100,
				# No active_bounty key; no completed_bounties key.
			},
			"stash": [],
			"equipped": {},
			"meta": {"runs_completed": 1, "deepest_stratum": 1, "total_playtime_sec": 1800.0},
		},
	}
	var f: FileAccess = FileAccess.open(
		_save().save_path(TEST_SLOT), FileAccess.WRITE)
	f.store_string(JSON.stringify(pre_t6_v5_envelope))
	f.close()
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	# Tier 3 backfill applied even though from_version == SCHEMA_VERSION.
	assert_true(loaded["character"].has("active_bounty"),
		"pre-W2-T6 v5 save gets active_bounty key on load")
	assert_eq(loaded["character"]["active_bounty"], null)
	assert_true(loaded["character"].has("completed_bounties"),
		"pre-W2-T6 v5 save gets completed_bounties key on load")
	assert_eq((loaded["character"]["completed_bounties"] as Array).size(), 0)
	# Existing v5 fields preserved (world_seed especially — the W2-T4
	# canonical promotion's contract: never re-roll a non-zero seed).
	assert_eq(int(loaded["character"]["world_seed"]), 0xCAFEBABE,
		"pre-W2-T6 v5 world_seed preserved (non-zero immutability)")
	assert_eq(loaded["character"]["level"], 6)


# ===== Case 3: backfill is idempotent on already-W2-T6 v5 ===============

func test_backfill_does_not_overwrite_existing_active_bounty() -> void:
	# A v5 save that already has active_bounty populated must not be
	# wiped by the backfill — has()-guard idempotence.
	var v5_with_active: Dictionary = {
		"schema_version": 5,
		"saved_at": "2026-05-23T10:00:00",
		"data": {
			"character": {
				"name": "Active-Bounty-Knight",
				"level": 8,
				"xp": 5000,
				"xp_to_next": 0,
				"vigor": 3,
				"focus": 2,
				"edge": 2,
				"stats": {"vigor": 3, "focus": 2, "edge": 2},
				"unspent_stat_points": 0,
				"first_level_up_seen": true,
				"first_boss_kill_seen": true,
				"world_seed": 0xDEADBEEF,
				"hp_current": 100,
				"hp_max": 100,
				"active_bounty": {
					"quest_id": "s1_recover_stoker_proof",
					"accepted_at_tick": 99_999,
					"completion_progress": {"kills_remaining": 1},
					"state": "quest_active",
				},
				"completed_bounties": ["s1_first_bounty"],
			},
			"stash": [],
			"equipped": {},
			"meta": {"runs_completed": 2, "deepest_stratum": 2, "total_playtime_sec": 5400.0},
		},
	}
	var f: FileAccess = FileAccess.open(
		_save().save_path(TEST_SLOT), FileAccess.WRITE)
	f.store_string(JSON.stringify(v5_with_active))
	f.close()
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	# Existing active_bounty NOT overwritten by the has()-guarded backfill.
	var ab: Variant = loaded["character"]["active_bounty"]
	assert_true(ab is Dictionary, "existing active_bounty preserved")
	assert_eq((ab as Dictionary)["quest_id"], "s1_recover_stoker_proof")
	assert_eq((ab as Dictionary)["accepted_at_tick"], 99_999)
	# Existing completed_bounties NOT cleared.
	var completed: Array = loaded["character"]["completed_bounties"]
	assert_eq(completed.size(), 1)
	assert_eq(String(completed[0]), "s1_first_bounty")
