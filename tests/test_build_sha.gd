extends GutTest
## Tests for Hook 1 — Build SHA in main menu.
##
## Verifies the BuildInfo autoload's source-priority ladder:
##   1. `res://build_info.txt` (CI-written) wins,
##   2. otherwise `GITHUB_SHA` env var,
##   3. otherwise the literal "dev-local" fallback.
##
## And that the rendered display string is the 7-char short SHA prefixed
## with "build: " — the format Tess records in `team/tess-qa/m1-test-plan.md`
## §"Build identification".
##
## Implementation note: BuildInfo runs once at autoload time, so we have to
## inject test fixtures (write build_info.txt or set env) and call
## `reload_for_test()` to re-resolve. The fixtures use the canonical
## res:// path; tests clean up after themselves.

const FIXTURE_PATH: String = "res://build_info.txt"


func _build_info() -> Node:
	var bi: Node = Engine.get_main_loop().root.get_node_or_null("BuildInfo")
	assert_not_null(bi, "BuildInfo autoload must be registered in project.godot")
	return bi


func before_each() -> void:
	# Clean any leftover fixture from a crashed prior test, and clear env.
	if FileAccess.file_exists(FIXTURE_PATH):
		DirAccess.remove_absolute(FIXTURE_PATH)
	# OS.set_environment is process-scoped; clearing protects later tests.
	OS.set_environment("GITHUB_SHA", "")


func after_each() -> void:
	if FileAccess.file_exists(FIXTURE_PATH):
		DirAccess.remove_absolute(FIXTURE_PATH)
	OS.set_environment("GITHUB_SHA", "")
	# Re-resolve so the autoload state isn't poisoned for the next test.
	_build_info().reload_for_test()


# --- Source priority -----------------------------------------------------

func test_dev_local_when_no_file_no_env() -> void:
	_build_info().reload_for_test()
	assert_eq(_build_info().sha, "dev-local")
	assert_eq(_build_info().short_sha, "dev-local")
	assert_eq(_build_info().display_label, "build: dev-local")


func test_uses_build_info_file_when_present() -> void:
	# Hand-author the CI artifact.
	var f: FileAccess = FileAccess.open(FIXTURE_PATH, FileAccess.WRITE)
	f.store_string("abcdef1234567")
	f.close()

	_build_info().reload_for_test()
	assert_eq(_build_info().sha, "abcdef1234567")
	# Short form is 7 chars regardless of input length.
	assert_eq(_build_info().short_sha, "abcdef1")
	assert_eq(_build_info().display_label, "build: abcdef1")


func test_strips_trailing_newline_from_file() -> void:
	# CI's `echo` may leave a newline; BuildInfo must strip it.
	var f: FileAccess = FileAccess.open(FIXTURE_PATH, FileAccess.WRITE)
	f.store_string("deadbee\n")
	f.close()

	_build_info().reload_for_test()
	assert_eq(_build_info().sha, "deadbee", "trailing newline must be stripped")
	assert_eq(_build_info().display_label, "build: deadbee")


func test_env_var_used_when_no_file() -> void:
	OS.set_environment("GITHUB_SHA", "0123456789abcdef")
	_build_info().reload_for_test()
	assert_eq(_build_info().sha, "0123456789abcdef")
	assert_eq(_build_info().short_sha, "0123456")
	assert_eq(_build_info().display_label, "build: 0123456")


func test_file_takes_priority_over_env() -> void:
	# Both set: file wins (CI is the authoritative source).
	var f: FileAccess = FileAccess.open(FIXTURE_PATH, FileAccess.WRITE)
	f.store_string("fileSha")
	f.close()
	OS.set_environment("GITHUB_SHA", "envSha999999")

	_build_info().reload_for_test()
	assert_eq(_build_info().sha, "fileSha", "build_info.txt overrides GITHUB_SHA env")


# --- Display formatting --------------------------------------------------

func test_short_sha_left_alone_if_already_under_7() -> void:
	# Defensive: a hand-written short SHA shouldn't be re-truncated.
	var f: FileAccess = FileAccess.open(FIXTURE_PATH, FileAccess.WRITE)
	f.store_string("abc12")
	f.close()

	_build_info().reload_for_test()
	assert_eq(_build_info().sha, "abc12")
	assert_eq(_build_info().short_sha, "abc12")
	assert_eq(_build_info().display_label, "build: abc12")


func test_empty_file_falls_through_to_dev_local() -> void:
	# An empty CI artifact (broken `echo`) must not produce "build: " (no SHA).
	var f: FileAccess = FileAccess.open(FIXTURE_PATH, FileAccess.WRITE)
	f.store_string("")
	f.close()

	_build_info().reload_for_test()
	assert_eq(_build_info().sha, "dev-local", "empty file -> fall through")
	assert_eq(_build_info().display_label, "build: dev-local")


# --- Main scene wiring ---------------------------------------------------

func test_main_scene_mounts_build_label_at_runtime() -> void:
	# Per `feat(integration)` run-013: Main.tscn no longer carries authored
	# child nodes — `Main.gd::_ready` now constructs the HUD CanvasLayer (with
	# its `BuildLabel` child) at runtime. We verify the runtime construction
	# by adding the scene to the tree and asserting the HUD child appears.
	var packed: PackedScene = load("res://scenes/Main.tscn")
	assert_not_null(packed)
	var instance: Node = packed.instantiate()
	# Reset autoloads so this test doesn't pick up state from siblings.
	var save_node: Node = Engine.get_main_loop().root.get_node_or_null("Save")
	if save_node != null and save_node.has_save(0):
		save_node.delete_save(0)
	# Adding to the tree fires _ready, which builds the HUD.
	add_child_autofree(instance)
	# The HUD CanvasLayer is named "HUD"; its BuildLabel child renders the
	# `BuildInfo.display_label` value.
	var hud: Node = instance.find_child("HUD", true, false)
	assert_not_null(hud, "Main runtime mounts a HUD CanvasLayer")
	var label: Node = hud.find_child("BuildLabel", true, false)
	assert_not_null(label, "HUD mounts a BuildLabel child at _ready")
	assert_true(label is Label, "BuildLabel must be a Label node")
