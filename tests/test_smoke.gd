extends GutTest
## Canary smoke test — proves the GUT runner, the project, and CI are
## wired together. If this ever goes red without an obvious cause,
## something is wrong with the test harness itself, not the gameplay.
##
## Per the testing bar: every push must be green; this is the floor.


func test_engine_version_is_godot_4() -> void:
	var info: Dictionary = Engine.get_version_info()
	assert_eq(info["major"], 4, "Embergrave is pinned to Godot 4.x — got %s" % info["string"])


func test_save_autoload_is_registered() -> void:
	# The Save autoload is referenced by `project.godot` and required by
	# downstream tasks (#6, plus anything that persists state). If it's
	# missing, save/load is broken before it starts.
	var save_node: Node = Engine.get_main_loop().root.get_node_or_null("Save")
	assert_not_null(save_node, "Save autoload must be registered in project.godot")
	assert_true(save_node.has_method("save_game"), "Save autoload must expose save_game()")
	assert_true(save_node.has_method("load_game"), "Save autoload must expose load_game()")
	assert_true(save_node.has_method("has_save"), "Save autoload must expose has_save()")


func test_main_scene_loads() -> void:
	# The boot scene defined as run/main_scene must be loadable. If the .tscn
	# breaks, headless --import passes but the game won't actually start.
	var packed: PackedScene = load("res://scenes/Main.tscn")
	assert_not_null(packed, "Main.tscn must load")
	var instance: Node = packed.instantiate()
	assert_not_null(instance, "Main.tscn must instantiate")
	instance.free()


func test_input_actions_exist() -> void:
	# Devon's stack call: these input actions are part of the project contract.
	# Drew and Uma both wire UI/AI to these names, so any rename must be
	# explicit and tracked.
	var required_actions: Array[String] = [
		"move_up", "move_down", "move_left", "move_right",
		"dodge", "sprint",
		"attack_light", "attack_heavy",
		"toggle_inventory",
	]
	for action: String in required_actions:
		assert_true(InputMap.has_action(action), "Input action '%s' must be defined in project.godot" % action)


func test_physics_layers_named() -> void:
	# Layer reservation is a DECISIONS.md entry; tests prove it survives
	# accidental edits to project.godot.
	var expected: Dictionary = {
		1: "world",
		2: "player",
		3: "player_hitbox",
		4: "enemy",
		5: "enemy_hitbox",
		6: "pickups",
	}
	for layer: int in expected:
		var got: String = ProjectSettings.get_setting("layer_names/2d_physics/layer_%d" % layer, "")
		assert_eq(got, expected[layer], "Physics layer %d must be named '%s'" % [layer, expected[layer]])
