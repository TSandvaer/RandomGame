extends GutTest
## Pair test for `[combat-trace] Main.apply_death_rule` (ticket 86c9u397c,
## Drew, 2026-05-15). Pairs with `tests/test_player_die_combat_trace.gd`
## (Player._die trace) — together the two lines make the Player-death +
## room-reload sequence unambiguous in the trace stream so future "mob
## freeze" investigations don't waste a release-build cycle on a non-bug.
##
## See `tests/test_player_die_combat_trace.gd` header for the full
## misdiagnosis-class context (the 86c9u397c brief is the precedent).
##
## Slot 989 — first integration-test slot below the M1-loop test (994); free
## per `tests/integration/test_*.gd::TEST_SLOT` audit at file-creation time.

const PHYS_DELTA: float = 1.0 / 60.0
const TEST_SLOT: int = 989


# ---- CombatTraceSpy infra (mirrors test_grunt.gd) ---------------------

class CombatTraceSpy:
	extends Node
	var calls: Array = []  # Array of [tag, msg]
	func combat_trace(tag: String, msg: String = "") -> void:
		calls.append([tag, msg])
	func has_tag(tag: String) -> bool:
		for c: Array in calls:
			if c[0] == tag:
				return true
		return false
	func msg_for(tag: String) -> String:
		for c: Array in calls:
			if c[0] == tag:
				return c[1]
		return ""


func _install_combat_trace_spy() -> CombatTraceSpy:
	var root: Node = get_tree().root
	var real: Node = root.get_node_or_null("DebugFlags")
	assert_not_null(real, "DebugFlags autoload must exist to swap for the spy")
	real.name = "DebugFlags__real_parked_apply_death_rule"
	var spy: CombatTraceSpy = CombatTraceSpy.new()
	spy.name = "DebugFlags"
	root.add_child(spy)
	return spy


func _restore_debug_flags(spy: CombatTraceSpy) -> void:
	var root: Node = get_tree().root
	root.remove_child(spy)
	spy.free()
	var parked: Node = root.get_node_or_null("DebugFlags__real_parked_apply_death_rule")
	if parked != null:
		parked.name = "DebugFlags"


# ---- Main scaffolding -------------------------------------------------

func _instantiate_main() -> Node:
	var packed: PackedScene = load("res://scenes/Main.tscn")
	assert_not_null(packed, "Main.tscn must load")
	var main: Node = packed.instantiate()
	_reset_autoloads()
	var save_node: Node = _save()
	if save_node != null and save_node.has_method("has_save") and save_node.has_save(TEST_SLOT):
		save_node.delete_save(TEST_SLOT)
	add_child_autofree(main)
	return main


func _reset_autoloads() -> void:
	var l: Node = _levels()
	if l != null and l.has_method("reset"):
		l.reset()
	var s: Node = _stratum()
	if s != null and s.has_method("reset"):
		s.reset()
	var i: Node = _inventory()
	if i != null and i.has_method("reset"):
		i.reset()


func _save() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Save")


func _levels() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Levels")


func _stratum() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("StratumProgression")


func _inventory() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Inventory")


# ---- Test --------------------------------------------------------------

func test_apply_death_rule_emits_combat_trace_line() -> void:
	# Mirror what `Main._on_player_died → call_deferred("apply_death_rule")`
	# does in production: call apply_death_rule directly on a real Main, assert
	# the diagnostic trace fires. Without this trace, the Player-death + room-
	# reload sequence is invisible in the trace stream — see header for context.
	var main: Node = _instantiate_main()
	await get_tree().process_frame
	var spy: CombatTraceSpy = _install_combat_trace_spy()
	main.apply_death_rule()
	await get_tree().process_frame
	var emitted: bool = spy.has_tag("Main.apply_death_rule")
	var msg: String = spy.msg_for("Main.apply_death_rule")
	_restore_debug_flags(spy)
	assert_true(emitted,
		"REGRESSION-86c9u397c: Main.apply_death_rule must emit a [combat-trace] " +
		"line. Pairs with Player._die trace — together they disambiguate a " +
		"Player-death-driven mob disappearance from a sibling-mob _physics_process " +
		"freeze in the harness trace stream. Without both, the 86c9u397c-class " +
		"misdiagnosis re-occurs.")
	assert_string_contains(msg, "Room 01",
		"Main.apply_death_rule payload must mention 'Room 01' so the trace " +
		"reader knows the room target of the respawn (the room counter wraps " +
		"to 0 on every Player death per the M1 death rule)")
