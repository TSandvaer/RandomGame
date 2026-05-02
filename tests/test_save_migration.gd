extends GutTest
## Forward-compat migration test from v0 → v1 fixtures (ClickUp 86c9kxx73).
##
## Per `team/TESTING_BAR.md` §Devon-and-Drew: "every save-shape change needs a
## forward-compat test (old save → new schema → load works or migrates
## cleanly)". This file pins the v0→v1 boundary against hand-authored
## fixtures. When Devon (or anyone) bumps SCHEMA_VERSION to v2 (level/XP
## additions, run state, etc), they MUST author fresh v1 fixtures and add
## a v1→v2 case here — see `team/tess-qa/save-migration-fixtures.md` for
## the format.
##
## Why fixture-based and not in-line dictionaries: the fixtures preserve
## the on-disk JSON shape verbatim (whitespace, key order, missing keys).
## A migration test that builds its v0 dict in-memory can drift away from
## what was actually written by an old build. Hand-authored JSON locks
## that contract.
##
## Edge probes per ticket:
##   1. Empty-inventory v0 → migrates without throwing.
##   2. Malformed-item v0 → loader does not crash; migration tolerates.
##   3. Double-migration (v1 → v1) → no-op, no double-bump.
##   4. Round-trip after migration: migrated v1 saves & reloads cleanly.

const TEST_SLOT: int = 990
const FIXTURE_DIR: String = "res://tests/fixtures/"
const FIXTURE_V0: String = "save_v0_pre_migration.json"
const FIXTURE_V0_EMPTY: String = "save_v0_empty_inventory.json"
const FIXTURE_V0_MALFORMED: String = "save_v0_malformed_item.json"


func _save() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Save")


func _read_fixture(name: String) -> String:
	# Fixtures are committed to res://tests/fixtures/ so headless GUT
	# (which boots from res://) can read them with FileAccess.
	var path: String = FIXTURE_DIR + name
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(f, "fixture %s must exist (was a fresh fixture not authored?)" % path)
	var raw: String = f.get_as_text()
	f.close()
	return raw


func _install_fixture_at_slot(name: String, slot: int) -> void:
	# Copy fixture text verbatim into the slot's save path. Save.load_game
	# will then read it as if a real game had written it.
	var raw: String = _read_fixture(name)
	var path: String = _save().save_path(slot)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(raw)
	f.close()


func before_each() -> void:
	if _save().has_save(TEST_SLOT):
		_save().delete_save(TEST_SLOT)
	var tmp: String = _save().save_path(TEST_SLOT) + ".tmp"
	if FileAccess.file_exists(tmp):
		DirAccess.remove_absolute(tmp)


func after_each() -> void:
	if _save().has_save(TEST_SLOT):
		_save().delete_save(TEST_SLOT)


# =====================================================================
# Core migration: v0 fixture → load → migrated v1
# =====================================================================

func test_v0_fixture_loads_via_load_game() -> void:
	# Sanity: the fixture exists, is valid JSON, and is consumed by Save.gd.
	_install_fixture_at_slot(FIXTURE_V0, TEST_SLOT)
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_false(loaded.is_empty(),
		"v0 fixture must load (envelope.data carried through migration)")


func test_v0_to_v1_preserves_all_v0_data() -> void:
	# The migration must NEVER drop a v0 field. Devon's _migrate_v0_to_v1
	# only adds defaults for missing fields; existing fields pass through.
	_install_fixture_at_slot(FIXTURE_V0, TEST_SLOT)
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	# Character: every field from the fixture survives.
	assert_eq(loaded["character"]["name"], "Old-Knight", "v0 name preserved")
	assert_eq(loaded["character"]["level"], 4, "v0 level preserved")
	assert_eq(loaded["character"]["xp"], 1850, "v0 xp preserved")
	assert_eq(loaded["character"]["vigor"], 2)
	assert_eq(loaded["character"]["focus"], 1)
	assert_eq(loaded["character"]["edge"], 0)
	assert_eq(loaded["character"]["hp_current"], 95)
	assert_eq(loaded["character"]["hp_max"], 110)
	# Stash: items survive with affix rolls intact.
	assert_eq(loaded["stash"].size(), 2, "v0 stash items count preserved")
	assert_eq(loaded["stash"][0]["id"], "weapon_iron_sword")
	assert_eq(loaded["stash"][0]["tier"], 2)
	assert_almost_eq(
		float(loaded["stash"][0]["rolled_affixes"][0]["value"]), 0.075, 1e-6,
		"affix rolled_value survives JSON parse + migration"
	)
	assert_eq(loaded["stash"][1]["id"], "armor_leather")


func test_v0_to_v1_backfills_required_v1_fields_with_defaults() -> void:
	# v1 introduced (a) `meta` block, (b) `equipped` map. v0 fixtures
	# lack both. Migration must backfill with sensible defaults so the
	# downstream code that reads `loaded["meta"]["deepest_stratum"]` (UI,
	# load screen) doesn't NPE on an old save.
	_install_fixture_at_slot(FIXTURE_V0, TEST_SLOT)
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	# `meta` block backfilled with default values per Save.DEFAULT_PAYLOAD.
	assert_true(loaded.has("meta"), "v1 `meta` block backfilled")
	assert_eq(loaded["meta"]["runs_completed"], 0,
		"v1 meta.runs_completed defaults to 0 for migrated v0 saves")
	assert_eq(loaded["meta"]["deepest_stratum"], 1,
		"v1 meta.deepest_stratum defaults to 1 (player has at least started s1)")
	assert_almost_eq(float(loaded["meta"]["total_playtime_sec"]), 0.0, 1e-6,
		"v1 meta.total_playtime_sec defaults to 0.0")
	# `equipped` map backfilled empty (no auto-equipment guess).
	assert_true(loaded.has("equipped"), "v1 `equipped` map backfilled")
	assert_eq(loaded["equipped"].size(), 0,
		"backfilled `equipped` is empty — migration never invents gear")


# =====================================================================
# Round-trip after migration — migrated save reloads cleanly
# =====================================================================

func test_save_migrated_v0_then_reload_round_trips() -> void:
	# After loading a v0, the next save call writes back at the current
	# SCHEMA_VERSION (v2 as of 2026-05-02). Reload that and the
	# schema_version on disk MUST match SCHEMA_VERSION — we never re-emit
	# an old version from a current runtime.
	_install_fixture_at_slot(FIXTURE_V0, TEST_SLOT)
	var loaded_v0: Dictionary = _save().load_game(TEST_SLOT)
	# Save it back without modification.
	assert_true(_save().save_game(TEST_SLOT, loaded_v0))
	# Read raw to verify the new envelope.
	var path: String = _save().save_path(TEST_SLOT)
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var raw: String = f.get_as_text()
	f.close()
	var parsed: Dictionary = JSON.parse_string(raw)
	# Schema bumped to 2 on 2026-05-02 (added xp_to_next to character).
	# When SCHEMA_VERSION bumps, update this number AND add the new
	# migration test in test_save.gd.
	assert_eq(int(parsed["schema_version"]), 2,
		"on-disk envelope upgraded to current schema (v2) after migration + save")
	# And reload one more time — fields are stable.
	var reloaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_eq(reloaded["character"]["level"], 4, "level stable across v0 → migrate → save → reload")
	assert_eq(reloaded["character"]["xp"], 1850)
	assert_eq(reloaded["stash"].size(), 2)


# =====================================================================
# Edge-probe #1: empty-inventory v0 fixture
# =====================================================================

func test_v0_with_empty_inventory_migrates_without_throwing() -> void:
	# The empty-inventory fixture has only `character` — no stash, no
	# equipped, no meta. _migrate_v0_to_v1 must backfill ALL three.
	_install_fixture_at_slot(FIXTURE_V0_EMPTY, TEST_SLOT)
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_false(loaded.is_empty(), "empty-inventory v0 still loads")
	assert_true(loaded.has("character"), "character preserved")
	assert_true(loaded.has("stash"), "stash backfilled (default empty)")
	assert_eq(loaded["stash"].size(), 0, "stash backfilled to []")
	assert_true(loaded.has("equipped"), "equipped backfilled (default empty)")
	assert_eq(loaded["equipped"].size(), 0, "equipped backfilled to {}")
	assert_true(loaded.has("meta"), "meta backfilled")
	assert_eq(loaded["meta"]["runs_completed"], 0)


# =====================================================================
# Edge-probe #2: malformed-item v0 fixture — loader doesn't crash
# =====================================================================

func test_v0_with_malformed_item_does_not_crash_loader() -> void:
	# The fixture has a stash with a non-Dictionary entry (a bare string)
	# and a half-formed item (missing fields). load_game's contract is
	# "never crash" — it MUST return either {} (full corruption) or a
	# best-effort migrated dict.
	#
	# Save.gd's _migrate_v0_to_v1 doesn't introspect stash entries, so it
	# passes them through. The downstream consumer (inventory UI) is the
	# one that would skip malformed entries — but the LOADER must not
	# refuse the whole save just because one item is bad.
	_install_fixture_at_slot(FIXTURE_V0_MALFORMED, TEST_SLOT)
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_false(loaded.is_empty(),
		"malformed-item save still loads (the good fields survive)")
	assert_eq(loaded["character"]["name"], "Curious-Knight")
	assert_eq(loaded["character"]["level"], 2)
	# Stash carried through verbatim — the malformed entry is the consumer's
	# problem, not the loader's.
	assert_eq(loaded["stash"].size(), 3, "all 3 entries preserved (consumer filters)")


# =====================================================================
# Edge-probe #3: double-migration is a no-op
# =====================================================================

func test_already_v1_save_does_not_double_migrate() -> void:
	# Save a v1, reload, save again, reload again. Nothing should change
	# — no field gets re-defaulted, no key gets duplicated, schema stays 1.
	var data: Dictionary = _save().default_payload()
	data["character"]["level"] = 8
	data["meta"]["runs_completed"] = 3
	data["meta"]["deepest_stratum"] = 2
	data["equipped"] = {
		"weapon": {"id": "weapon_iron_sword", "tier": 2, "rolled_affixes": [], "stack_count": 1}
	}
	_save().save_game(TEST_SLOT, data)
	# First reload — already v1, migration is no-op.
	var loaded_a: Dictionary = _save().load_game(TEST_SLOT)
	# Save and reload one more time.
	_save().save_game(TEST_SLOT, loaded_a)
	var loaded_b: Dictionary = _save().load_game(TEST_SLOT)
	# Every field unchanged across the two cycles.
	assert_eq(loaded_b["character"]["level"], 8)
	assert_eq(loaded_b["meta"]["runs_completed"], 3,
		"double-migration didn't reset runs_completed to 0")
	assert_eq(loaded_b["meta"]["deepest_stratum"], 2)
	assert_eq(loaded_b["equipped"]["weapon"]["id"], "weapon_iron_sword",
		"equipped weapon survives the no-op double-migrate cycle")


# =====================================================================
# Schema-version envelope assertions on migrated files
# =====================================================================

func test_migration_leaves_envelope_schema_version_intact_on_disk_until_save() -> void:
	# Load-only does NOT rewrite the file. The on-disk file remains v0
	# (no schema_version key) until the next save_game call, at which
	# point it gets the v1 envelope. This decoupling prevents read-only
	# load surfaces (browse-saves UI) from silently mutating user data.
	_install_fixture_at_slot(FIXTURE_V0, TEST_SLOT)
	# Load (in-memory migration only).
	var _ignored: Dictionary = _save().load_game(TEST_SLOT)
	# On-disk file is still v0-shaped (no schema_version).
	var path: String = _save().save_path(TEST_SLOT)
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var raw: String = f.get_as_text()
	f.close()
	var parsed: Dictionary = JSON.parse_string(raw)
	assert_false(parsed.has("schema_version"),
		"load-only does not rewrite the on-disk envelope — v0 stays v0 until save")


# =====================================================================
# Migration covers AC #6 — save survives quit-and-relaunch
# =====================================================================

func test_v0_save_survives_simulated_quit_and_relaunch() -> void:
	# AC #6 wedge: a player who saved before the v1 schema landed must be
	# able to relaunch into the new build and continue. This is the AC
	# integration shape — fixture installed, fixture loaded, fixture saved
	# back, fixture reloaded across a "drop in-memory state" boundary.
	_install_fixture_at_slot(FIXTURE_V0, TEST_SLOT)
	var session: Dictionary = _save().load_game(TEST_SLOT)
	# "Player saw their character on the title screen" — write back to
	# disk so the next launch sees a v1 envelope.
	_save().save_game(TEST_SLOT, session)
	# Drop the in-memory dict (simulated quit).
	session.clear()
	# Relaunch — a fresh Save.load_game call.
	var continued: Dictionary = _save().load_game(TEST_SLOT)
	# Verify the v0 character data is fully recovered + v1 fields are present.
	assert_eq(continued["character"]["level"], 4, "v0 level survives quit-and-relaunch (AC6)")
	assert_eq(continued["character"]["xp"], 1850)
	assert_true(continued.has("meta"), "v1 meta block present after migration cycle")
	assert_true(continued.has("equipped"))
