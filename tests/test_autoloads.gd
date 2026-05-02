extends GutTest
## Phase A — autoloads. Confirms the engine-level singletons that downstream
## code can rely on are registered and expose their public API.
##
## Per `team/tess-qa/automated-smoke-plan.md` Phase A:
##   tu-autoload-01  test_gamestate_present
##   tu-autoload-02  test_savesystem_present_and_api
##
## Note: the smoke-plan paper assumed both `GameState` and `Save` autoloads.
## As of run-002 only `Save` is registered (per project.godot autoload
## section); `GameState` is in the inventory for a future task. We assert
## what's actually there and document the gap so it's caught when GameState
## lands. The intent of this test file is the *contract* — when GameState
## goes in, an additional `func test_gamestate_present` lands here in the
## same commit.


# --- tu-autoload-02: Save autoload contract ------------------------------
# (canonical home for the Save-API contract; test_smoke.gd has a thinner
# "is registered" canary which we keep for fast-fail on autoload removal.)

func test_save_autoload_registered() -> void:
	var save: Node = Engine.get_main_loop().root.get_node_or_null("Save")
	assert_not_null(save, "Save must be registered as autoload (project.godot [autoload])")


func test_save_autoload_exposes_full_public_api() -> void:
	var save: Node = Engine.get_main_loop().root.get_node_or_null("Save")
	# Per `team/devon-dev/save-format.md` and Save.gd top-comment:
	#   save_game(slot, data) -> bool
	#   load_game(slot)       -> Dictionary
	#   has_save(slot)        -> bool
	#   delete_save(slot)     -> bool
	#   atomic_write(path, s) -> bool
	#   default_payload()     -> Dictionary
	#   save_path(slot)       -> String
	for method: String in ["save_game", "load_game", "has_save", "delete_save",
			"atomic_write", "default_payload", "save_path"]:
		assert_true(save.has_method(method),
			"Save autoload must expose %s() (save-format.md contract)" % method)


func test_save_schema_version_constant_is_positive_int() -> void:
	# Schema versioning is the central invariant of forward-compat. If
	# someone resets it to 0 or below, migration logic breaks silently.
	var save: Node = Engine.get_main_loop().root.get_node_or_null("Save")
	# The constant is exposed via reflection — Save.SCHEMA_VERSION.
	# Accessing via get_script() so this test stays decoupled from class_name.
	var script: Script = save.get_script()
	var const_map: Dictionary = script.get_script_constant_map()
	assert_true(const_map.has("SCHEMA_VERSION"),
		"Save script must declare SCHEMA_VERSION constant")
	var v: int = int(const_map["SCHEMA_VERSION"])
	assert_gt(v, 0, "SCHEMA_VERSION must be >= 1 (current: %d)" % v)


# --- tu-autoload-01: GameState autoload (deferred until task lands) -----

func test_gamestate_autoload_when_present() -> void:
	# Tess deliberately leaves this as a passing-no-op until the GameState
	# autoload task lands. The moment GameState is added to project.godot,
	# this test should be tightened to assert the same surface as Save.
	var gs: Node = Engine.get_main_loop().root.get_node_or_null("GameState")
	if gs == null:
		# Pre-GameState world: this test is a deliberate placeholder.
		# Mark the test file itself as documenting a known gap.
		pending("GameState autoload not yet registered — see automated-smoke-plan.md tu-autoload-01")
		return
	assert_not_null(gs, "GameState autoload registered")
