extends GutTest
## Dedicated v3-migrate backfill pin for W2-T6 quest fields (ticket
## `86c9y7ydg`). Per the dispatch brief Part C:
##
##   "Save migration test: tests/test_save_migrate_quest_fields_backfill.gd
##    — load v3 save → assert active_bounty defaults to null +
##    completed_bounties defaults to []."
##
## Sibling to test_quest_state_save_roundtrip.gd's Case 2; this file pins
## the v3-specific path (legacy save predates Tier 3 entirely). The
## broader round-trip + Case 3 idempotence pin lives in the sibling.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

const TEST_SLOT: int = 997

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


# ---- v3 → v5+Tier-3 backfill pin --------------------------------------

func test_v3_save_backfills_quest_fields_to_defaults() -> void:
	# A v3-shaped envelope on disk lacks every Tier 3 field. Loading
	# routes through the full chain (v3 → v4 → v5 + backfill_v5_tier3_quest_fields).
	# The end state MUST have active_bounty == null + completed_bounties == [].
	var v3_envelope: Dictionary = {
		"schema_version": 3,
		"saved_at": "2026-05-23T08:00:00",
		"data": {
			"character": {
				"name": "Legacy-v3-Knight",
				"level": 5,
				"xp": 1500,
				"xp_to_next": 800,
				"vigor": 2,
				"focus": 1,
				"edge": 1,
				"stats": {"vigor": 2, "focus": 1, "edge": 1},
				"unspent_stat_points": 0,
				"first_level_up_seen": true,
				"hp_current": 110,
				"hp_max": 110,
			},
			"stash": [
				{
					"id": "iron_sword",
					"tier": 2,
					"rolled_affixes": [],
					"stack_count": 1,
				},
			],
			"equipped": {},
			"meta": {"runs_completed": 1, "deepest_stratum": 1, "total_playtime_sec": 600.0},
		},
	}
	var f: FileAccess = FileAccess.open(
		_save().save_path(TEST_SLOT), FileAccess.WRITE)
	f.store_string(JSON.stringify(v3_envelope))
	f.close()
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	# Tier 3 backfill: active_bounty key present + null.
	assert_true(loaded["character"].has("active_bounty"),
		"backfill adds active_bounty key to legacy v3 save")
	assert_eq(loaded["character"]["active_bounty"], null,
		"active_bounty defaults to null for Tier-3-naive v3 character")
	# Tier 3 backfill: completed_bounties key present + empty.
	assert_true(loaded["character"].has("completed_bounties"),
		"backfill adds completed_bounties key to legacy v3 save")
	var completed: Array = loaded["character"]["completed_bounties"]
	assert_true(completed is Array,
		"completed_bounties typed as Array")
	assert_eq(completed.size(), 0,
		"completed_bounties defaults to empty Array")
	# Sanity — earlier-chain fields landed correctly through the
	# v3 → v4 → v5 chain (the world_seed re-roll, etc).
	assert_true(loaded["character"].has("first_boss_kill_seen"),
		"v3 → v4 also backfilled first_boss_kill_seen")
	assert_false(bool(loaded["character"]["first_boss_kill_seen"]))
	assert_ne(int(loaded["character"]["world_seed"]), 0,
		"v3 → v5 chain re-rolled the world_seed sentinel")
	# Re-save and verify on-disk schema is v5 (no v6 bump).
	_save().save_game(TEST_SLOT, loaded)
	var path: String = _save().save_path(TEST_SLOT)
	var f2: FileAccess = FileAccess.open(path, FileAccess.READ)
	var raw2: String = f2.get_as_text()
	f2.close()
	var parsed: Dictionary = JSON.parse_string(raw2)
	assert_eq(int(parsed["schema_version"]), 5,
		"schema stays v5 across Tier 3 backfill (no v6 trigger)")


func test_v4_save_also_backfills_quest_fields() -> void:
	# A v4-shaped save (intermediate; first_boss_kill_seen + world_seed
	# present, but no Tier 3 fields) routes through the v4 -> v5 step
	# plus the unconditional Tier 3 backfill.
	var v4_envelope: Dictionary = {
		"schema_version": 4,
		"saved_at": "2026-05-22T11:00:00",
		"data": {
			"character": {
				"name": "Mid-v4-Knight",
				"level": 7,
				"xp": 3000,
				"xp_to_next": 0,
				"vigor": 2,
				"focus": 2,
				"edge": 1,
				"stats": {"vigor": 2, "focus": 2, "edge": 1},
				"unspent_stat_points": 1,
				"first_level_up_seen": true,
				"first_boss_kill_seen": true,
				"world_seed": 0xFEEDFACE,
				"hp_current": 130,
				"hp_max": 130,
			},
			"stash": [],
			"equipped": {},
			"meta": {"runs_completed": 3, "deepest_stratum": 2, "total_playtime_sec": 3600.0},
		},
	}
	var f: FileAccess = FileAccess.open(
		_save().save_path(TEST_SLOT), FileAccess.WRITE)
	f.store_string(JSON.stringify(v4_envelope))
	f.close()
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	# Tier 3 backfill landed.
	assert_eq(loaded["character"]["active_bounty"], null)
	assert_eq((loaded["character"]["completed_bounties"] as Array).size(), 0)
	# v4 → v5 step did NOT re-roll the existing non-zero world_seed
	# (immutability post-roll).
	assert_eq(int(loaded["character"]["world_seed"]), 0xFEEDFACE,
		"non-zero world_seed preserved through v4 → v5 step")
	# v3-era field preserved.
	assert_true(bool(loaded["character"]["first_boss_kill_seen"]))


# ---- Player round-trip via to_save_dict / restore_from_save_dict -----

func test_player_restore_from_save_dict_round_trips_active_bounty() -> void:
	# Player.to_save_dict / Player.restore_from_save_dict symmetry pin —
	# the methods called by Main's save-restore path. We bare-instantiate
	# a Node and drive the methods via duck-typed access, mirroring
	# the router test pattern (avoids the heavy CharacterBody2D bare-
	# instance cost).
	#
	# This is a CONTRACT pin for the symmetric serialise→deserialise
	# property — not an integration test against the Save autoload. The
	# Save round-trip is covered in test_quest_state_save_roundtrip.gd.
	var PlayerScript: Script = preload("res://scripts/player/Player.gd")
	var p: Node = PlayerScript.new()
	add_child_autofree(p)
	# Seed Player runtime state.
	var QSScript: Script = preload("res://scripts/quests/QuestState.gd")
	var qs: QuestState = QSScript.new()
	qs.quest_id = &"s1_recover_stoker_proof"
	qs.accepted_at_tick = 50_000
	qs.completion_progress = {"kills_remaining": 3}
	qs.state = &"quest_active"
	p.set("active_bounty", qs)
	p.set("completed_bounties", [&"s1_first_bounty", &"s2_pilot_run"])
	# Snapshot.
	var snap: Dictionary = p.call("to_save_dict")
	assert_true(snap is Dictionary)
	# Snapshot shape contract.
	assert_true(snap["active_bounty"] is Dictionary,
		"to_save_dict serialises active_bounty as Dictionary")
	assert_eq((snap["active_bounty"] as Dictionary)["quest_id"],
		"s1_recover_stoker_proof")
	assert_true(snap["completed_bounties"] is Array,
		"completed_bounties serialised as Array")
	# Note: in-memory entries are StringName but to_save_dict stringifies.
	assert_eq(String((snap["completed_bounties"] as Array)[0]),
		"s1_first_bounty")
	# Restore into a fresh node.
	var q: Node = PlayerScript.new()
	add_child_autofree(q)
	# restore_from_save_dict reads a `character` block — wrap the snapshot
	# into a character-block shape.
	var character: Dictionary = snap.duplicate(true)
	q.call("restore_from_save_dict", character)
	# Verify restored state.
	var restored_ab: Variant = q.get("active_bounty")
	assert_true(restored_ab is QuestState,
		"restored active_bounty is a QuestState")
	assert_eq((restored_ab as QuestState).quest_id,
		&"s1_recover_stoker_proof")
	var restored_completed: Array = q.get("completed_bounties")
	assert_eq(restored_completed.size(), 2)
	assert_eq(String(restored_completed[0]), "s1_first_bounty")


func test_player_restore_from_null_active_bounty_clears_field() -> void:
	# Restoring a character block with active_bounty=null sets Player.active_bounty
	# to null (clean reset path; matches the migrated-from-v3 case).
	var PlayerScript: Script = preload("res://scripts/player/Player.gd")
	var p: Node = PlayerScript.new()
	add_child_autofree(p)
	# Seed with a non-null bounty, then restore from a null-bounty snapshot.
	var QSScript: Script = preload("res://scripts/quests/QuestState.gd")
	var qs: QuestState = QSScript.new()
	qs.quest_id = &"stale_bounty"
	p.set("active_bounty", qs)
	p.set("completed_bounties", [&"stale_completion"])
	p.call("restore_from_save_dict", {
		"active_bounty": null,
		"completed_bounties": [],
	})
	assert_eq(p.get("active_bounty"), null,
		"null active_bounty in save dict clears Player.active_bounty")
	var completed: Array = p.get("completed_bounties")
	assert_eq(completed.size(), 0,
		"empty completed_bounties in save dict clears Player.completed_bounties")


func test_player_restore_tolerates_missing_quest_keys() -> void:
	# A character block lacking both keys (e.g. a pre-W2-T6 save loaded
	# before backfill — defensive belt-and-suspenders) restores to default
	# state (null + []).
	var PlayerScript: Script = preload("res://scripts/player/Player.gd")
	var p: Node = PlayerScript.new()
	add_child_autofree(p)
	# Seed with non-default state.
	var QSScript: Script = preload("res://scripts/quests/QuestState.gd")
	var qs: QuestState = QSScript.new()
	qs.quest_id = &"stale_bounty"
	p.set("active_bounty", qs)
	# Restore from a character block missing the quest keys entirely.
	p.call("restore_from_save_dict", {"level": 1})
	assert_eq(p.get("active_bounty"), null,
		"missing active_bounty key defaults to null")
	assert_eq((p.get("completed_bounties") as Array).size(), 0,
		"missing completed_bounties key defaults to []")
