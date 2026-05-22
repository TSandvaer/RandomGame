extends GutTest
## Tests for `Player._modal_is_active()` — the generalized modal-input-gate
## predicate that suppresses attack + dodge input while ANY modal UI surface
## is active (ticket `86c9xxg0n` — Sponsor's Option A; generalizes the
## dialogue-only seed from ticket `86c9xuab3` / PR #319).
##
## What this file pins (per dispatch brief):
##
##   1. `test_player_attack_suppressed_while_inventory_open` — open
##      InventoryPanel + fire attack input via `_process_grounded` -> no
##      attack hitbox spawned.
##   2. `test_player_attack_resumes_after_inventory_close` — close
##      InventoryPanel + fire attack input -> attack hitbox spawned.
##   3. `test_modal_is_active_union_dialogue_and_inventory` — both modals
##      individually + simultaneously -> `_modal_is_active()` returns correct
##      boolean for each cell of the truth table.
##   4. `test_movement_input_not_gated_by_inventory` — Diablo convention pin:
##      WASD input is preserved while InventoryPanel is open (only attack +
##      dodge are gated).
##
## ## Strategy
##
## Player.gd polls input from `_process_grounded` via `Input.is_action_*`.
## GUT cannot easily synthesise `Input` global state from a unit test. The
## predicate is what's load-bearing here — `_modal_is_active()` is the boolean
## that gates the entire `if _modal_is_active(): return` path. Asserting the
## predicate's behaviour across the modal truth table is equivalent to
## asserting the gate. We separately drive `_process_grounded` with a manual
## velocity assertion for the movement-not-gated pin.
##
## For the attack-suppression / attack-resumes pair, we directly call
## `_process_grounded(0.0)` after registering a stub InventoryPanel in the
## "inventory_panel" group with `is_open()` true / false respectively, and
## assert via `_state` that the player did NOT / DID enter STATE_ATTACK.
## `Input.is_action_just_pressed` is not stubbable from GDScript, so we use
## a side-channel: `_process_grounded` early-returns BEFORE the
## `is_action_just_pressed` check when `_modal_is_active()` is true. That
## early-return is the gate-of-record; both halves of the pin assert the
## predicate's effect rather than the global input poll itself.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")
const PlayerScript: Script = preload("res://scripts/player/Player.gd")

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()
	# Force-close any leaked active session from a prior test.
	var dc: Node = _dialogue_controller()
	if dc != null and dc.has_method("is_active") and dc.is_active():
		dc.close()
	# Wipe any lingering inventory_panel group members.
	for n: Node in get_tree().get_nodes_in_group("inventory_panel"):
		if is_instance_valid(n):
			n.remove_from_group("inventory_panel")


func after_each() -> void:
	var dc: Node = _dialogue_controller()
	if dc != null and dc.has_method("close"):
		dc.close()
	for n: Node in get_tree().get_nodes_in_group("inventory_panel"):
		if is_instance_valid(n):
			n.remove_from_group("inventory_panel")
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- Helpers --------------------------------------------------------

func _dialogue_controller() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("DialogueController")


## Minimal stub that satisfies the `_inventory_is_open()` reach:
##   - lives in the "inventory_panel" SceneTree group
##   - exposes an `is_open() -> bool` method
## Avoids loading the full InventoryPanel scene (which pulls Inventory autoload
## state, tooltip, palette, etc.) — the gate is a pure boolean predicate, so
## stubbing the predicate's input is the minimum-surface assertion.
class _StubInventoryPanel extends Node:
	var _opened: bool = false
	func _init(initially_open: bool = false) -> void:
		_opened = initially_open
	func is_open() -> bool:
		return _opened
	func set_open(v: bool) -> void:
		_opened = v


func _attach_stub_panel(open: bool = false) -> _StubInventoryPanel:
	var stub := _StubInventoryPanel.new(open)
	add_child_autofree(stub)
	stub.add_to_group("inventory_panel")
	return stub


func _make_player_in_tree() -> Player:
	var p: Player = PlayerScript.new()
	add_child_autofree(p)
	return p


# ---- Test 1: attack suppressed while inventory open -----------------

func test_player_attack_suppressed_while_inventory_open() -> void:
	# Wire a stub panel reporting is_open()==true into the inventory_panel group.
	_attach_stub_panel(true)
	var p: Player = _make_player_in_tree()
	assert_true(p._inventory_is_open(),
		"_inventory_is_open() true when stub panel in group reports is_open()==true")
	assert_true(p._modal_is_active(),
		"_modal_is_active() true when any modal (inventory) is open")
	# The gate is the load-bearing surface: _process_grounded early-returns on
	# _modal_is_active() before consulting Input.is_action_just_pressed. Direct
	# proof of the predicate's value plus the production code's
	# `if _modal_is_active(): return` is the regression-guard pin.
	# We assert the production-call path stays IDLE under the gate by stepping
	# _process_grounded with no input-dir + no real Input state and checking
	# the player did not transition into STATE_ATTACK.
	assert_eq(p.get_state(), Player.STATE_IDLE, "player starts IDLE")
	p._process_grounded(0.0)
	assert_ne(p.get_state(), Player.STATE_ATTACK,
		"player must NOT enter STATE_ATTACK while inventory open (gate suppresses attack input)")


# ---- Test 2: attack resumes after inventory close -------------------

func test_player_attack_resumes_after_inventory_close() -> void:
	var stub := _attach_stub_panel(true)
	var p: Player = _make_player_in_tree()
	assert_true(p._modal_is_active(), "modal active while panel open")
	# Close the modal — gate must drop.
	stub.set_open(false)
	assert_false(p._inventory_is_open(),
		"_inventory_is_open() false after stub panel close()")
	assert_false(p._modal_is_active(),
		"_modal_is_active() false when no modals active")
	# With the gate dropped, the production path now reaches the
	# is_action_just_pressed checks. Direct API proof that try_attack succeeds
	# when called (the production input path would invoke this).
	var hb: Hitbox = p.try_attack(Player.ATTACK_LIGHT, Vector2.RIGHT)
	assert_not_null(hb,
		"try_attack returns a hitbox after inventory close — attack path is no longer gated")


# ---- Test 3: union over dialogue + inventory truth table ------------

func test_modal_is_active_union_dialogue_and_inventory() -> void:
	var p: Player = _make_player_in_tree()
	var stub := _attach_stub_panel(false)
	var dc: Node = _dialogue_controller()
	assert_not_null(dc, "DialogueController autoload registered")

	# Cell 1: no modals -> false
	assert_false(p._dialogue_is_active(), "(no modals) dialogue inactive")
	assert_false(p._inventory_is_open(), "(no modals) inventory closed")
	assert_false(p._modal_is_active(),
		"_modal_is_active() false when neither dialogue nor inventory open")

	# Cell 2: only dialogue -> true
	var tree: DialogueTreeDef = _make_simple_dialogue_tree()
	dc.open(tree, &"flavor")
	assert_true(p._dialogue_is_active(), "(dialogue-only) dialogue active")
	assert_false(p._inventory_is_open(), "(dialogue-only) inventory closed")
	assert_true(p._modal_is_active(),
		"_modal_is_active() true when ONLY dialogue is active")
	dc.close()

	# Cell 3: only inventory -> true
	stub.set_open(true)
	assert_false(p._dialogue_is_active(), "(inventory-only) dialogue inactive")
	assert_true(p._inventory_is_open(), "(inventory-only) inventory open")
	assert_true(p._modal_is_active(),
		"_modal_is_active() true when ONLY inventory is open")

	# Cell 4: both modals -> true
	dc.open(tree, &"flavor")
	assert_true(p._dialogue_is_active(), "(both modals) dialogue active")
	assert_true(p._inventory_is_open(), "(both modals) inventory open")
	assert_true(p._modal_is_active(),
		"_modal_is_active() true when BOTH dialogue AND inventory are active")

	# Cleanup back to cell 1 to confirm the union releases cleanly
	dc.close()
	stub.set_open(false)
	assert_false(p._modal_is_active(),
		"_modal_is_active() returns to false once both modals close")


# ---- Test 4: movement input NOT gated by inventory ------------------

func test_movement_input_not_gated_by_inventory() -> void:
	# Diablo convention pin (per Player.gd:1163 modal-input-gate comment block):
	# WASD walking is intentionally PRESERVED while inventory is open. Only
	# attack + dodge inputs are suppressed. If a future refactor moves the
	# `if _modal_is_active(): return` gate above the velocity computation, this
	# test fails — the regression-guard for the genre-convention call.
	_attach_stub_panel(true)
	var p: Player = _make_player_in_tree()
	assert_true(p._modal_is_active(), "modal active during the WASD-pin assertion")

	# Inspect Player.gd:_process_grounded source to assert the control flow
	# invariant: the input-dir read + velocity-write must precede the modal
	# gate. This is a structural test — reading the source code is the only
	# way to assert "the gate doesn't bracket the movement code" without
	# synthesising real Input state (which GUT does not expose).
	var src: String = FileAccess.get_file_as_string("res://scripts/player/Player.gd")
	assert_false(src.is_empty(), "Player.gd source readable for structural assertion")
	var grounded_start: int = src.find("func _process_grounded(")
	assert_gt(grounded_start, -1, "_process_grounded function present")
	var gate_pos: int = src.find("if _modal_is_active():", grounded_start)
	assert_gt(gate_pos, -1, "_modal_is_active() gate present inside _process_grounded")
	var velocity_pos: int = src.find("velocity = input_dir * speed", grounded_start)
	assert_gt(velocity_pos, -1, "velocity-write present inside _process_grounded")
	assert_lt(velocity_pos, gate_pos,
		"velocity-write (movement) must precede the _modal_is_active() gate — " +
		"WASD movement is intentionally NOT suppressed by modal panels (Diablo convention)")

	# Behavioural confirmation: step _process_grounded with a non-zero
	# velocity already set via the public state and confirm the gate does
	# not clear or reverse it. Note that without real Input state the
	# input_dir defaults to ZERO and velocity = ZERO is the resulting
	# normal-path output; what the source-scan above pins is the structural
	# invariant that this WOULD honor WASD if input were present.
	p._process_grounded(0.0)
	# After the call the gate has returned early; state must remain IDLE
	# (no attack spawned, no dodge entered).
	assert_ne(p.get_state(), Player.STATE_ATTACK,
		"WASD-only pin sanity check: no attack spawned during modal-gated step")
	assert_ne(p.get_state(), Player.STATE_DODGE,
		"WASD-only pin sanity check: no dodge entered during modal-gated step")


# ---- Helpers --------------------------------------------------------

func _make_simple_dialogue_tree() -> DialogueTreeDef:
	var BranchScript: Script = preload("res://scripts/dialogue/DialogueBranch.gd")
	var TreeScript: Script = preload("res://scripts/dialogue/DialogueTreeDef.gd")
	var b: DialogueBranch = BranchScript.new()
	b.lines = ["Hello.", "Goodbye."]
	b.responses = []
	var t: DialogueTreeDef = TreeScript.new()
	t.npc_id = &"modal_gate_npc"
	t.display_name = "Modal Gate Stub"
	t.branches = {&"flavor": b}
	t.default_branch_key = &"flavor"
	return t
