extends GutTest
## Phase A — quit-relaunch integration. Simulates the AC6 user flow:
##   play → save → quit → relaunch → load → state matches.
##
## Per `team/tess-qa/automated-smoke-plan.md`:
##   ti-save-01  test_full_quit_relaunch_continues_state
##   ti-save-02  test_save_on_stratum_exit_then_continue
##
## What "quit and relaunch" means in a headless test: we cannot really
## terminate the engine and reboot it inside one GUT run. Instead we
## simulate the lifecycle that matters: write to disk via the autoload,
## then re-read via the autoload after clearing any in-memory references
## the system might be holding. Save.gd has no in-memory cache (it reads
## from disk on every load_game), so a successful disk-only round-trip
## *is* the same behaviour as a real quit/relaunch. The contract here is
## that no field of the saved data is held only in RAM.
##
## We use slot 997 to keep these isolated from test_save.gd (999) and
## test_save_roundtrip.gd (998).

const TEST_SLOT: int = 997


func before_each() -> void:
	if _save().has_save(TEST_SLOT):
		_save().delete_save(TEST_SLOT)
	var tmp: String = _save().save_path(TEST_SLOT) + ".tmp"
	if FileAccess.file_exists(tmp):
		DirAccess.remove_absolute(tmp)


func after_each() -> void:
	if _save().has_save(TEST_SLOT):
		_save().delete_save(TEST_SLOT)


func _save() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Save")


# Forces the in-memory view of "the player loaded their save" to evaporate.
# In a real relaunch there's nothing in RAM yet — we explicitly drop our
# local handle and re-load to assert no implicit RAM caching is happening.
func _simulate_relaunch_then_load() -> Dictionary:
	# (Save autoload is engine-lifetime, but it does not cache load results.
	# Calling load_game twice with no save in between is a no-op for state.)
	return _save().load_game(TEST_SLOT)


# --- ti-save-01: full quit-relaunch round-trip ---------------------------

func test_full_quit_relaunch_continues_state() -> void:
	# 1. Active session — player levels up, equips gear, fills meta.
	var session: Dictionary = _save().default_payload()
	session["character"]["level"] = 2
	session["character"]["xp"] = 320
	session["character"]["vigor"] = 1
	session["equipped"]["weapon"] = {
		"id": "weapon_iron_sword", "tier": 1, "rolled_affixes": [], "stack_count": 1,
	}
	session["meta"]["runs_completed"] = 1
	session["meta"]["deepest_stratum"] = 1
	# 2. Save (auto-save tick, stratum exit, or menu Quit→Save).
	assert_true(_save().save_game(TEST_SLOT, session), "save before quit must succeed")
	assert_true(_save().has_save(TEST_SLOT), "save file present on disk before relaunch")
	# 3. The "session" Dictionary represents in-RAM state. Drop it.
	session.clear()
	# 4. Relaunch — Continue from main menu calls Save.load_game().
	var continued: Dictionary = _simulate_relaunch_then_load()
	# 5. Verify everything came back exactly.
	assert_eq(continued["character"]["level"], 2, "level survives quit/relaunch (AC6)")
	assert_eq(continued["character"]["xp"], 320, "xp survives quit/relaunch")
	assert_eq(continued["character"]["vigor"], 1, "stat point survives quit/relaunch")
	assert_eq(continued["equipped"]["weapon"]["id"], "weapon_iron_sword",
		"equipped item survives quit/relaunch (AC6)")
	assert_eq(continued["meta"]["runs_completed"], 1)
	assert_eq(continued["meta"]["deepest_stratum"], 1)


# --- ti-save-02: stratum-exit save → quit → continue ---------------------

func test_save_on_stratum_exit_then_continue() -> void:
	# Per M1 spec (mvp-scope.md): auto-save fires on stratum exit.
	# Simulate: player pre-exit state (level 2, killed several mobs, xp = 750).
	# Save tick fires. Then they alt-F4 / close tab.
	var pre_exit: Dictionary = _save().default_payload()
	pre_exit["character"]["level"] = 2
	pre_exit["character"]["xp"] = 750
	pre_exit["meta"]["runs_completed"] = 0
	pre_exit["meta"]["deepest_stratum"] = 1
	pre_exit["meta"]["total_playtime_sec"] = 412.5
	# Stratum exit save.
	assert_true(_save().save_game(TEST_SLOT, pre_exit))
	# Player closes the game.
	pre_exit.clear()
	# Re-launch + Continue.
	var post_relaunch: Dictionary = _simulate_relaunch_then_load()
	assert_eq(post_relaunch["character"]["xp"], 750)
	assert_eq(post_relaunch["meta"]["deepest_stratum"], 1)
	assert_almost_eq(float(post_relaunch["meta"]["total_playtime_sec"]), 412.5, 0.001)


# --- bonus: relaunch into a missing save shows a clean new-game path ----

func test_relaunch_with_no_save_returns_empty() -> void:
	# Maps to AC6-T05 (clear cache and revisit URL): the load surface
	# returns {} so the title screen can offer "New Game" instead of
	# "Continue". A non-{} return here would mean the autoload is silently
	# inventing a save file.
	assert_false(_save().has_save(TEST_SLOT))
	var result: Dictionary = _save().load_game(TEST_SLOT)
	assert_true(result.is_empty(), "no save file -> {} (UI gates Continue on this)")


# --- bonus: corrupt-save resilience (full integration shape) ------------

func test_relaunch_with_corrupt_save_does_not_crash() -> void:
	# AC5 (no hard crashes): a corrupt save on relaunch must not take down
	# the title screen. Save.gd's contract is to log an error and return {}.
	var f: FileAccess = FileAccess.open(_save().save_path(TEST_SLOT), FileAccess.WRITE)
	f.store_string("{ this is not [valid json")
	f.close()
	# Disable the push_error logging in test output for this case — we
	# expect the error and don't want it to noise up the run report.
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_true(loaded.is_empty(), "corrupt save -> {} not crash; UI shows New Game")
