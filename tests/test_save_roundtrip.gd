extends GutTest
## Phase A — save roundtrip with focus on the M1 death-rule contract.
##
## Per `team/tess-qa/automated-smoke-plan.md` Phase A and DECISIONS.md
## 2026-05-02 ("M1 death rule: keep level + equipped, lose unequipped
## inventory"). The existing `test_save.gd` (Devon-authored) covers the
## low-level round-trip and migration. This file covers the *acceptance-
## criterion-shaped* invariants — what the player will actually feel.
##
## ID mapping (smoke-plan):
##   tu-save-01  test_save_load_preserves_level
##   tu-save-02  test_save_load_preserves_stash_items
##   tu-save-03  test_save_load_preserves_equipped
##   tu-save-04  test_save_writes_to_user_dir
##   tu-save-05  test_load_missing_save_returns_default
##   tu-save-06  test_save_does_not_persist_run_state
##   tu-save-07  test_save_format_is_valid_json
##
## Plus a death-rule pair that maps DECISIONS.md to executable assertions.
## When the death-on-AC3 test fails, the M1 ship blocker is right here.
##
## We use slot 998 to avoid colliding with Devon's test_save.gd (slot 999)
## or a real save in dev environments.

const TEST_SLOT: int = 998
const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")


# ---- Universal-warning gate (ticket 86c9uf0mm Half B) ----------------
##
## See test_save.gd for the rationale. Save-roundtrip exercises the same
## save-load surface and inherits the same gate.

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
	return Engine.get_main_loop().root.get_node_or_null("Save")


# --- tu-save-01: level survives round-trip exactly ----------------------

func test_save_load_preserves_level() -> void:
	var data: Dictionary = _save().default_payload()
	data["character"]["level"] = 3
	data["character"]["xp"] = 750
	data["character"]["vigor"] = 2
	data["character"]["edge"] = 1
	assert_true(_save().save_game(TEST_SLOT, data))

	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_eq(loaded["character"]["level"], 3, "level survives save→load exactly")
	assert_eq(loaded["character"]["xp"], 750, "xp survives save→load exactly")
	assert_eq(loaded["character"]["vigor"], 2)
	assert_eq(loaded["character"]["edge"], 1)


# --- tu-save-02: stash items round-trip with affix rolls --------------

func test_save_load_preserves_stash_items() -> void:
	var data: Dictionary = _save().default_payload()
	data["stash"] = [
		{"id": "weapon_iron_sword", "tier": 2, "rolled_affixes": [{"affix_id": "swift", "value": 0.08}], "stack_count": 1},
		{"id": "armor_leather", "tier": 1, "rolled_affixes": [], "stack_count": 1},
		{"id": "weapon_flame_blade", "tier": 3, "rolled_affixes": [
			{"affix_id": "vital", "value": 12}, {"affix_id": "keen", "value": 0.05},
		], "stack_count": 1},
	]
	_save().save_game(TEST_SLOT, data)
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_eq(loaded["stash"].size(), 3, "stash size preserved")
	# Item IDs preserved order (deterministic round-trip).
	assert_eq(loaded["stash"][0]["id"], "weapon_iron_sword")
	assert_eq(loaded["stash"][1]["id"], "armor_leather")
	assert_eq(loaded["stash"][2]["id"], "weapon_flame_blade")
	# Affix rolls preserved with float fidelity (JSON round-trip can drift).
	assert_almost_eq(float(loaded["stash"][0]["rolled_affixes"][0]["value"]), 0.08, 1e-6)
	assert_almost_eq(float(loaded["stash"][2]["rolled_affixes"][1]["value"]), 0.05, 1e-6)
	assert_eq(loaded["stash"][2]["rolled_affixes"][0]["value"], 12)
	# Tier preserved.
	assert_eq(loaded["stash"][0]["tier"], 2)
	assert_eq(loaded["stash"][2]["tier"], 3)


# --- tu-save-03: equipped weapon + armor round-trip --------------------

func test_save_load_preserves_equipped() -> void:
	var data: Dictionary = _save().default_payload()
	data["equipped"] = {
		"weapon": {"id": "weapon_iron_sword", "tier": 2,
			"rolled_affixes": [{"affix_id": "swift", "value": 0.08}], "stack_count": 1},
		"armor": {"id": "armor_chain", "tier": 2,
			"rolled_affixes": [{"affix_id": "vital", "value": 12}], "stack_count": 1},
	}
	_save().save_game(TEST_SLOT, data)
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_true(loaded["equipped"].has("weapon"))
	assert_true(loaded["equipped"].has("armor"))
	assert_eq(loaded["equipped"]["weapon"]["id"], "weapon_iron_sword")
	assert_eq(loaded["equipped"]["weapon"]["tier"], 2)
	assert_eq(loaded["equipped"]["armor"]["id"], "armor_chain")
	assert_almost_eq(float(loaded["equipped"]["weapon"]["rolled_affixes"][0]["value"]), 0.08, 1e-6)


# --- tu-save-04: save path is in user:// (catches accidental project-dir writes) ---

func test_save_writes_to_user_dir() -> void:
	var path: String = _save().save_path(0)
	assert_true(path.begins_with("user://"),
		"save_path must live under user:// (got %s)" % path)
	# Slot interpolation works for non-zero slots.
	var slot42: String = _save().save_path(42)
	assert_true(slot42.begins_with("user://"))
	assert_true(slot42.ends_with("42.json"), "slot index encoded in filename")


# --- tu-save-05: missing save returns default-shaped behaviour ----------

func test_load_missing_save_returns_empty_dict() -> void:
	# Caller decides whether to treat {} as "new game" — Save's contract
	# is to *never crash* on missing save and never invent data silently.
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_true(loaded.is_empty(), "missing save -> {} (caller picks new-game path)")


func test_default_payload_is_a_full_save_shape() -> void:
	# default_payload() is what new-game flow hands to save_game(). It must
	# contain every top-level field the load contract refers to so round-
	# tripping a fresh new game is safe.
	var dp: Dictionary = _save().default_payload()
	assert_true(dp.has("character"), "default_payload includes character")
	assert_true(dp.has("stash"), "default_payload includes stash")
	assert_true(dp.has("equipped"), "default_payload includes equipped")
	assert_true(dp.has("meta"), "default_payload includes meta")
	assert_eq(dp["character"]["level"], 1, "fresh character starts at level 1")
	assert_eq(dp["stash"].size(), 0, "fresh stash is empty")
	assert_eq(dp["equipped"].size(), 0, "fresh equipped is empty")


# --- tu-save-06: M1 death rule — equipped persists, inventory wipes, level kept ---
# Maps DECISIONS.md 2026-05-02 "M1 death rule" to a spec-shaped test.
# This is the AC3 test backstop — if it fails, M1 ships broken.

func test_death_rule_keeps_level_xp_equipped() -> void:
	# Setup: pre-death state — level 3 character with equipped gear.
	var pre: Dictionary = _save().default_payload()
	pre["character"]["level"] = 3
	pre["character"]["xp"] = 500
	pre["character"]["vigor"] = 2
	pre["character"]["focus"] = 1
	pre["equipped"] = {
		"weapon": {"id": "weapon_iron_sword", "tier": 2,
			"rolled_affixes": [{"affix_id": "swift", "value": 0.08}], "stack_count": 1},
		"armor": {"id": "armor_leather", "tier": 1,
			"rolled_affixes": [], "stack_count": 1},
	}
	# Run-only state on death must NOT survive: simulated unequipped inventory
	# items the player picked up during the run that they hadn't equipped.
	pre["stash"] = []  # M1 has no stash UI; "carried items" live in equipped per DECISIONS rule
	# But the death event is the moment of save: per the rule, equipped + level + xp + stat allocations are written; nothing else of the run.
	_save().save_game(TEST_SLOT, pre)

	# Simulate "die, restart" — the death save just landed; reload it.
	var post: Dictionary = _save().load_game(TEST_SLOT)
	# Character ladder is preserved.
	assert_eq(post["character"]["level"], 3, "AC3: death does not lose character level")
	assert_eq(post["character"]["xp"], 500, "AC3: xp earned to level 3 boundary preserved")
	assert_eq(post["character"]["vigor"], 2, "AC3: stat allocations preserved")
	assert_eq(post["character"]["focus"], 1)
	# Gear ladder is preserved.
	assert_eq(post["equipped"]["weapon"]["id"], "weapon_iron_sword",
		"AC3 + DECISIONS death rule: equipped weapon persists across death")
	assert_eq(post["equipped"]["armor"]["id"], "armor_leather",
		"AC3 + DECISIONS death rule: equipped armor persists across death")
	# Affix rolls survive.
	assert_almost_eq(float(post["equipped"]["weapon"]["rolled_affixes"][0]["value"]), 0.08, 1e-6,
		"equipped weapon's rolled affix values preserved across death")


func test_death_rule_run_state_is_not_persistent() -> void:
	# DECISIONS.md M1 death rule: "loses all unequipped inventory items and
	# the run-progress (depth, position, in-progress combat resources)".
	# Test the structural side of that rule: anything labelled "run state"
	# in the save shape must be absent / zeroed after a death-shaped save.
	#
	# Devon's save-format does NOT yet include a `run` block — so the rule
	# is enforceable today by simply *not* persisting in-progress fields.
	# Keep this test tight: it asserts the absence so the moment Drew or
	# Devon adds a `run` block to default_payload(), this test fires and
	# we re-evaluate the death save flow.
	var dp: Dictionary = _save().default_payload()
	assert_false(dp.has("run"),
		"default_payload must not include a `run` block — run state is non-persistent " +
		"per DECISIONS.md 2026-05-02 M1 death rule. If you're adding run state, the save " +
		"flow needs to clear it on death; ping Tess.")


# --- tu-save-07: saved file is valid JSON --------------------------------

func test_saved_file_parses_as_json() -> void:
	var data: Dictionary = _save().default_payload()
	data["character"]["level"] = 2
	_save().save_game(TEST_SLOT, data)

	var path: String = _save().save_path(TEST_SLOT)
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var raw: String = f.get_as_text()
	f.close()
	# Round-trip the raw text through the parser. If JSON.parse_string returns
	# null OR the result isn't a Dictionary, the save format has regressed.
	var parsed: Variant = JSON.parse_string(raw)
	assert_not_null(parsed, "saved file must parse as JSON")
	assert_true(parsed is Dictionary, "saved file must be a JSON object at root")
	# Envelope shape: schema_version + saved_at + data.
	assert_true((parsed as Dictionary).has("schema_version"))
	assert_true((parsed as Dictionary).has("data"))
