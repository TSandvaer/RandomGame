extends GutTest
## Phase A — boot smoke. Asserts the game launches without errors:
##   - the main scene as configured in project.godot is loadable + parseable
##   - main scene instantiates without throwing
##   - the engine main loop is alive (catches harness-level regressions)
##
## Per `team/tess-qa/automated-smoke-plan.md` Phase A:
##   tu-boot-01  test_main_scene_instantiates
##   tu-boot-02  test_engine_main_loop_is_alive
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
	# Per `feat(integration)` run-013: Main.tscn is now an empty Node2D
	# carrying `Main.gd`. `_ready` (fired when the scene is added to the
	# tree) builds the world / HUD / Player / panels at runtime. We verify
	# both that the .tscn loads (no parse errors) AND that the runtime
	# scaffolding spawns a Player node when `_ready` fires.
	var packed: PackedScene = load("res://scenes/Main.tscn")
	assert_not_null(packed, "Main.tscn must load")
	assert_true(packed.can_instantiate(), "Main.tscn must be instantiable (no parse errors)")
	var instance: Node = packed.instantiate()
	assert_not_null(instance, "Main.tscn instantiate() must return a node")
	# Reset save slot so the test runs clean across siblings.
	var save_node: Node = Engine.get_main_loop().root.get_node_or_null("Save")
	if save_node != null and save_node.has_save(0):
		save_node.delete_save(0)
	add_child_autofree(instance)
	# After _ready, Main has spawned the Player as a child of its World root.
	# Walk the tree to find it (it lives under World, not directly under Main).
	var player: Node = instance.find_child("Player", true, false)
	assert_not_null(player, "Main runtime must spawn a Player node (boot wiring contract)")


# --- tu-boot-02 ----------------------------------------------------------

func test_engine_main_loop_is_alive() -> void:
	# In a GUT cmdline run the engine's main loop is the SceneTree wrapping
	# this test execution. If it's gone, we wouldn't be running. Asserting
	# its presence still has value: a future test harness that swaps the
	# main loop will flag here, before silently breaking other tests.
	# (Replaces the original frames-counter check, which reads 0 in headless
	# mode at GUT-test time because no _process tick has fired yet.)
	var ml: MainLoop = Engine.get_main_loop()
	assert_not_null(ml, "engine main loop must exist while tests run")
	assert_true(ml is SceneTree, "main loop is a SceneTree (GUT runs in scene-tree mode)")


func test_main_scene_root_is_a_node() -> void:
	# Trivial-but-load-bearing: catches a future where someone replaces
	# Main.tscn's root with a Resource or sets it to abstract.
	var packed: PackedScene = load("res://scenes/Main.tscn")
	var instance: Node = packed.instantiate()
	assert_true(instance is Node, "Main scene root must be a Node subclass")
	instance.free()
