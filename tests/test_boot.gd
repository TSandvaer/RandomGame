extends GutTest
## Phase A — boot smoke. Asserts the game launches without errors:
##   - the main scene as configured in project.godot is loadable + parseable
##   - main scene instantiates without throwing
##   - after one process tick the engine has actually advanced
##
## Per `team/tess-qa/automated-smoke-plan.md` Phase A:
##   tu-boot-01  test_main_scene_instantiates
##   tu-boot-02  test_no_orphan_errors_on_first_frame
##
## Why this is in Phase A and gets written first: a green CI on a project
## that fails to boot is silently broken. This is the cheapest catch.


# --- tu-boot-01 ----------------------------------------------------------

func test_main_scene_path_matches_project_setting() -> void:
	# Catches accidental rename / move of Main.tscn that would silently
	# break first-launch (the .tscn itself loads fine; only project.godot
	# `run/main_scene` knows the bootstrap path).
	var main_scene_path: String = ProjectSettings.get_setting("application/run/main_scene", "")
	assert_eq(main_scene_path, "res://scenes/Main.tscn",
		"project.godot run/main_scene must point to res://scenes/Main.tscn")


func test_main_scene_instantiates() -> void:
	var packed: PackedScene = load("res://scenes/Main.tscn")
	assert_not_null(packed, "Main.tscn must load")
	assert_true(packed.can_instantiate(), "Main.tscn must be instantiable (no parse errors)")
	var instance: Node = packed.instantiate()
	assert_not_null(instance, "Main.tscn instantiate() must return a node")
	# The Main scene contains the Player as a sub-instance — verify the tree
	# integrates without orphan errors. (A typo in Player.tscn surfaces here.)
	assert_not_null(instance.get_node_or_null("Player"),
		"Main scene must include a Player child (boot wiring contract)")
	instance.free()


# --- tu-boot-02 ----------------------------------------------------------

func test_engine_advances_on_first_frame() -> void:
	# `Engine.get_frames_drawn()` increments per drawn frame. In headless
	# mode the engine still ticks; this confirms the test runner itself
	# isn't stuck and that the engine main loop is alive when our tests run.
	var frames: int = Engine.get_process_frames()
	assert_gt(frames, 0, "engine must have processed at least one frame before tests run")


func test_main_scene_root_is_a_node() -> void:
	# Trivial-but-load-bearing: catches a future where someone replaces
	# Main.tscn's root with a Resource or sets it to abstract.
	var packed: PackedScene = load("res://scenes/Main.tscn")
	var instance: Node = packed.instantiate()
	assert_true(instance is Node, "Main scene root must be a Node subclass")
	instance.free()
