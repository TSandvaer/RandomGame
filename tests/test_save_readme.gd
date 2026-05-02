extends GutTest
## Tests for Hook 3 — save-dir README writer.
##
## Verifies that `Save.save_game()` writes a one-liner README to
## `user://README.txt` on every successful save. Tess uses this README to
## locate save files for AC3-T03 (death-rule) and AC6 (run-summary) manual
## test setup.
##
## Slot 996 chosen to avoid collisions with:
##   999 (Devon's `tests/test_save.gd`),
##   998 (Tess's roundtrip test slot),
##   997 (Tess's integration test slot).

const TEST_SLOT: int = 996
const README_PATH: String = "user://README.txt"


func _save() -> Node:
	var save: Node = Engine.get_main_loop().root.get_node_or_null("Save")
	assert_not_null(save, "Save autoload must be registered")
	return save


func before_each() -> void:
	# Clean slate: remove the test save AND any leftover README from a
	# crashed prior test. README must be re-created by save_game; we don't
	# want a stale one giving a false positive.
	if _save().has_save(TEST_SLOT):
		_save().delete_save(TEST_SLOT)
	if FileAccess.file_exists(README_PATH):
		DirAccess.remove_absolute(README_PATH)


func after_each() -> void:
	if _save().has_save(TEST_SLOT):
		_save().delete_save(TEST_SLOT)
	# Leave the README in place — it's expected to exist after any save in
	# normal gameplay. Cleaning it would mask test failures from later
	# tests that rely on it.


# --- README creation -----------------------------------------------------

func test_first_save_writes_readme() -> void:
	assert_false(FileAccess.file_exists(README_PATH), "no README before first save")
	assert_true(_save().save_game(TEST_SLOT))
	assert_true(FileAccess.file_exists(README_PATH), "README created on first save")


func test_readme_mentions_schema_version() -> void:
	_save().save_game(TEST_SLOT)
	var f: FileAccess = FileAccess.open(README_PATH, FileAccess.READ)
	assert_not_null(f)
	var contents: String = f.get_as_text()
	f.close()
	# The README must call out the running schema_version so a tester
	# inspecting the dir knows whether the save is migrate-safe.
	assert_true(
		contents.contains("schema_version=%d" % _save().SCHEMA_VERSION),
		"README must mention schema_version=%d" % _save().SCHEMA_VERSION
	)


func test_readme_documents_clear_procedure() -> void:
	_save().save_game(TEST_SLOT)
	var f: FileAccess = FileAccess.open(README_PATH, FileAccess.READ)
	var contents: String = f.get_as_text()
	f.close()
	# Must tell the tester how to clear saves for a fresh run.
	assert_true(contents.to_lower().contains("delete"),
		"README must explain how to delete saves")
	assert_true(contents.contains("save_*.json") or contents.contains("save_<slot>.json"),
		"README must point at the actual save filename pattern")


func test_readme_documents_save_location() -> void:
	_save().save_game(TEST_SLOT)
	var f: FileAccess = FileAccess.open(README_PATH, FileAccess.READ)
	var contents: String = f.get_as_text()
	f.close()
	# Must include the resolved user:// path so testers don't have to
	# guess where Godot put it on their OS.
	var resolved: String = ProjectSettings.globalize_path("user://")
	assert_true(contents.contains(resolved),
		"README must include the resolved user:// path (got: %s)" % resolved.left(80))


# --- Idempotency / overwrite --------------------------------------------

func test_repeated_saves_do_not_corrupt_readme() -> void:
	# Three saves in a row; README must remain valid on the third.
	_save().save_game(TEST_SLOT)
	_save().save_game(TEST_SLOT)
	_save().save_game(TEST_SLOT)
	var f: FileAccess = FileAccess.open(README_PATH, FileAccess.READ)
	var contents: String = f.get_as_text()
	f.close()
	# Same invariants hold after multiple writes.
	assert_true(contents.contains("schema_version=%d" % _save().SCHEMA_VERSION))
	assert_true(contents.length() > 100, "README should have non-trivial content")


func test_readme_path_constant_matches_save_dir() -> void:
	# Defensive: if Save.SAVE_DIR ever changes, README_PATH must follow.
	var dir: String = _save().SAVE_DIR
	var readme: String = _save().README_PATH
	assert_true(readme.begins_with(dir),
		"README_PATH (%s) must live under SAVE_DIR (%s)" % [readme, dir])
