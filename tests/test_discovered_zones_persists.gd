extends GutTest
## Round-trip test for `Player.discovered_zones` + `Player.discovered_waypoints`
## (M3 Tier 3 W2-T5, ticket `86c9y10fv`, paired test E3).
##
## **What this pins:**
##
##   1. `to_save_dict()` serialises `discovered_zones` + `discovered_waypoints`
##      as JSON-safe `Dictionary[String, bool]` (StringName keys stringified).
##   2. `restore_from_save_dict()` reads back String keys + normalises to
##      StringName for in-memory canonicalisation.
##   3. The backfill path in `Save._backfill_v5_tier3_quest_fields` (renamed
##      docstring) defaults missing fields to `{}` — tier-3-naive v5 saves
##      load cleanly with empty discovery.
##   4. `Player.mark_zone_discovered(zone_id)` is idempotent — first call on
##      a zone returns true (new discovery), subsequent calls return false
##      (re-entry).
##
## **Cross-references:**
##   - `team/devon-dev/save-schema-v5-tier3-additions.md §2.2 + §2.3` —
##     authoritative shape lock for the two fields.
##   - `tests/test_save_migrate_quest_fields_backfill.gd` — sibling
##     round-trip test for `active_bounty` + `completed_bounties`. This
##     test is the world-map analogue.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

const PlayerScript: Script = preload("res://scripts/player/Player.gd")
const SaveScript: Script = preload("res://scripts/save/Save.gd")

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- Symmetric serialise / deserialise -----------------------------


func test_to_save_dict_stringifies_discovered_zones_keys() -> void:
	# StringName keys must round-trip via String — JSON has no StringName,
	# so unstringified writes would coerce non-explicitly. Explicit
	# stringification keeps the on-disk shape diagnosable.
	var p: Node = PlayerScript.new()
	add_child_autofree(p)
	(
		p
		. set(
			"discovered_zones",
			{
				&"s1_z1_outer_cloister": true,
				&"s2_z3_sunken_library": true,
			}
		)
	)
	var snap: Dictionary = p.call("to_save_dict")
	assert_true(snap.has("discovered_zones"))
	var serialised: Variant = snap["discovered_zones"]
	assert_true(serialised is Dictionary)
	var d: Dictionary = serialised as Dictionary
	assert_eq(d.size(), 2)
	# Every key in the serialised dict is a plain String, not StringName.
	for k in d.keys():
		assert_typeof(k, TYPE_STRING, "serialised key is String, not StringName")
	# Spot-check values.
	assert_true(d.has("s1_z1_outer_cloister"))
	assert_true(bool(d["s1_z1_outer_cloister"]))


func test_restore_from_save_dict_normalises_keys_for_stringname_lookup() -> void:
	# Mirror of above — reading back String-keyed JSON yields a dict
	# reachable via StringName lookups (the production access shape).
	#
	# **Key-shape contract under Godot 4.3:** lookup-equivalence, NOT
	# typeof-equivalence. Godot 4.3 lacks typed `Dictionary[K, V]` syntax,
	# so an untyped Dictionary canonicalizes StringName↔String keys to
	# TYPE_STRING on insert regardless of which form was passed in. The
	# `_normalise_dict_keys_to_stringname` helper wraps every key as
	# `StringName(String(k))` at insert time for the canonical access
	# shape; lookups via `&"..."` (StringName literal) and via `"..."`
	# (String literal) both hit. See helper docstring + .claude/docs/
	# test-conventions.md § "Godot 4.3 untyped-Dictionary key
	# canonicalization" for the full rationale.
	var p: Node = PlayerScript.new()
	add_child_autofree(p)
	var character: Dictionary = {
		"active_bounty": null,
		"completed_bounties": [],
		"discovered_zones":
		{
			"s1_z1_outer_cloister": true,
			"s2_z3_sunken_library": true,
		},
		"discovered_waypoints":
		{
			"s1_z1_threshold": true,
		},
	}
	p.call("restore_from_save_dict", character)
	var restored_zones: Dictionary = p.get("discovered_zones")
	assert_eq(restored_zones.size(), 2)
	# Lookup by StringName must hit — this is the contract (production reads
	# via StringName-keyed lookups).
	assert_true(
		restored_zones.has(&"s1_z1_outer_cloister"),
		"StringName lookup hits after restore",
	)
	assert_true(
		restored_zones.has(&"s2_z3_sunken_library"),
		"StringName lookup hits after restore",
	)
	# Lookup by String form also hits (Godot 4.3 lookup is StringName↔String-
	# equivalent under untyped-Dict semantics).
	assert_true(restored_zones.has("s1_z1_outer_cloister"), "String lookup also hits")
	# Values are coerced to bool (defensive — JSON may round-trip as 1/0).
	assert_true(restored_zones[&"s1_z1_outer_cloister"], "value reachable via StringName key")
	var restored_waypoints: Dictionary = p.get("discovered_waypoints")
	assert_eq(restored_waypoints.size(), 1)
	assert_true(restored_waypoints.has(&"s1_z1_threshold"))


func test_round_trip_preserves_discovered_zones_set() -> void:
	# Full symmetric round-trip: write → serialise → fresh node → restore →
	# assert in-memory state matches the original write.
	var p1: Node = PlayerScript.new()
	add_child_autofree(p1)
	(
		p1
		. set(
			"discovered_zones",
			{
				&"s1_z1_outer_cloister": true,
				&"s2_z1_sunken_entrance": true,
				&"s3_z2_vault_descent": true,
			}
		)
	)
	(
		p1
		. set(
			"discovered_waypoints",
			{
				&"s1_z1_threshold": true,
				&"s2_z1_descent": true,
			}
		)
	)
	var snap: Dictionary = p1.call("to_save_dict")
	# Fresh node, restore.
	var p2: Node = PlayerScript.new()
	add_child_autofree(p2)
	p2.call("restore_from_save_dict", snap)
	# Assert restored state.
	var restored_zones: Dictionary = p2.get("discovered_zones")
	assert_eq(restored_zones.size(), 3)
	assert_true(restored_zones.has(&"s1_z1_outer_cloister"))
	assert_true(restored_zones.has(&"s2_z1_sunken_entrance"))
	assert_true(restored_zones.has(&"s3_z2_vault_descent"))
	var restored_waypoints: Dictionary = p2.get("discovered_waypoints")
	assert_eq(restored_waypoints.size(), 2)


# ---- mark_zone_discovered idempotence ---------------------------


func test_mark_zone_discovered_first_call_returns_true() -> void:
	var p: Node = PlayerScript.new()
	add_child_autofree(p)
	var was_new: bool = p.call("mark_zone_discovered", &"s1_z1_outer_cloister")
	assert_true(was_new, "first call on new zone returns true (new discovery)")
	var d: Dictionary = p.get("discovered_zones")
	assert_true(d.has(&"s1_z1_outer_cloister"))


func test_mark_zone_discovered_idempotent_on_reentry() -> void:
	var p: Node = PlayerScript.new()
	add_child_autofree(p)
	p.call("mark_zone_discovered", &"s1_z1_outer_cloister")
	# Second call on already-discovered zone returns false.
	var was_new: bool = p.call("mark_zone_discovered", &"s1_z1_outer_cloister")
	assert_false(was_new, "subsequent call on same zone returns false (no-op)")
	# State unchanged.
	var d: Dictionary = p.get("discovered_zones")
	assert_eq(d.size(), 1)


func test_mark_zone_discovered_rejects_empty_id() -> void:
	# Defensive — empty StringName should be a no-op (a real consumer
	# would never pass &"", but this is the kind of edge a future refactor
	# could regress).
	var p: Node = PlayerScript.new()
	add_child_autofree(p)
	var was_new: bool = p.call("mark_zone_discovered", &"")
	assert_false(was_new, "empty zone_id rejected")
	var d: Dictionary = p.get("discovered_zones")
	assert_eq(d.size(), 0, "empty zone_id not written to dict")


# ---- Save.gd backfill round-trip --------------------------------


func test_save_backfill_defaults_discovered_zones_to_empty_dict() -> void:
	# Tier-3-naive v5 save (lacks discovered_zones). Backfill must produce
	# `{}` so the panel renders all-undiscovered cleanly without a missing-
	# key crash.
	var save_node: Node = SaveScript.new()
	add_child_autofree(save_node)
	var data_block: Dictionary = {
		"character":
		{
			"level": 1,
			"xp": 0,
			# Note: no discovered_zones / discovered_waypoints keys.
		},
		"meta": {"runs_completed": 0, "deepest_stratum": 1, "total_playtime_sec": 0.0},
	}
	var migrated_data: Dictionary = save_node.migrate(data_block, 5)
	assert_true(
		migrated_data["character"].has("discovered_zones"), "backfill adds discovered_zones key"
	)
	assert_true(
		migrated_data["character"].has("discovered_waypoints"),
		"backfill adds discovered_waypoints key"
	)
	assert_eq(
		(migrated_data["character"]["discovered_zones"] as Dictionary).size(),
		0,
		"backfill default is empty dict"
	)


func test_save_backfill_preserves_existing_discovered_zones() -> void:
	# A v5 save that ALREADY has discovered_zones (post-W2-T5 ship) must
	# preserve them — backfill is `has()`-guarded, so the existing value
	# survives. Idempotence pin.
	var save_node: Node = SaveScript.new()
	add_child_autofree(save_node)
	var data_block: Dictionary = {
		"character":
		{
			"level": 1,
			"xp": 0,
			"discovered_zones": {"s1_z1_outer_cloister": true},
			"discovered_waypoints": {"s1_z1_threshold": true},
		},
		"meta": {"runs_completed": 0, "deepest_stratum": 1, "total_playtime_sec": 0.0},
	}
	var migrated_data: Dictionary = save_node.migrate(data_block, 5)
	var dz: Dictionary = migrated_data["character"]["discovered_zones"]
	assert_eq(dz.size(), 1, "existing discovered_zones preserved through migrate")
	assert_true(dz.has("s1_z1_outer_cloister"))


# ---- Full save → load round-trip ------------------------------


func test_full_save_load_round_trip_preserves_discovery_state() -> void:
	# Write a player payload via to_save_dict, persist, load back via Save
	# migration, restore into a fresh player. Assert equal in-memory shape.
	var save_node: Node = SaveScript.new()
	add_child_autofree(save_node)
	# Seed.
	var p1: Node = PlayerScript.new()
	add_child_autofree(p1)
	p1.call("mark_zone_discovered", &"s1_z1_outer_cloister")
	p1.call("mark_zone_discovered", &"s2_z1_sunken_entrance")
	p1.call("mark_waypoint_discovered", &"s1_z1_threshold")
	var snap: Dictionary = p1.call("to_save_dict")
	# Build the payload envelope shape Save.gd would migrate.
	var data_block: Dictionary = save_node.default_payload()
	var character: Dictionary = data_block["character"]
	for k in snap.keys():
		character[k] = snap[k]
	# Migrate (no-op at v5; verifies the backfill doesn't overwrite).
	var migrated: Dictionary = save_node.migrate(data_block, 5)
	# Restore.
	var p2: Node = PlayerScript.new()
	add_child_autofree(p2)
	p2.call("restore_from_save_dict", migrated["character"])
	var dz: Dictionary = p2.get("discovered_zones")
	assert_eq(dz.size(), 2, "two zones round-tripped")
	assert_true(dz.has(&"s1_z1_outer_cloister"))
	assert_true(dz.has(&"s2_z1_sunken_entrance"))
	var dw: Dictionary = p2.get("discovered_waypoints")
	assert_eq(dw.size(), 1)
	assert_true(dw.has(&"s1_z1_threshold"))
