extends GutTest
## Tests for DialoguePanel + the Player attack-input gating invariant (ticket
## `86c9xuab3` — M3 Tier 3 W1 dialogue system spike).
##
## Two surfaces under test:
##
##   1. **Panel ↔ Controller signal wiring** — the panel renders in response
##      to controller signals (branch_opened / line_displayed /
##      responses_presented / dialogue_closed) and routes input back through
##      the controller (advance_line / select_response / close).
##
##   2. **Player attack-input gating** — when DialogueController.is_active()
##      is true, Player._dialogue_is_active() returns true. This is the gate
##      `_process_grounded` reads to suppress attack + dodge input during a
##      dialogue session (pre-empts InventoryPanel input-leak class ticket
##      `86c9xwxhu`).

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

const TreeScript: Script = preload("res://scripts/dialogue/DialogueTreeDef.gd")
const BranchScript: Script = preload("res://scripts/dialogue/DialogueBranch.gd")
const ResponseScript: Script = preload("res://scripts/dialogue/DialogueResponse.gd")
const PanelScene: PackedScene = preload("res://scenes/ui/DialoguePanel.tscn")
const PlayerScript: Script = preload("res://scripts/player/Player.gd")

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()
	# Force-close any leaked active session from a prior test.
	var dc: Node = _controller()
	if dc != null and dc.has_method("is_active") and dc.is_active():
		dc.close()


func after_each() -> void:
	var dc: Node = _controller()
	if dc != null and dc.has_method("close"):
		dc.close()
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- AC1: panel scene loads + instantiates ------------------------

func test_panel_scene_loads_and_instantiates() -> void:
	var panel: DialoguePanel = PanelScene.instantiate()
	assert_not_null(panel, "DialoguePanel instantiates")
	add_child_autofree(panel)
	# Awaiting one frame lets _ready run + signal connections install.
	await get_tree().process_frame
	assert_false(panel.is_open(), "panel is closed by default")
	assert_false(panel.visible, "panel is hidden by default")


# ---- AC2: panel becomes visible when controller opens session ---

func test_panel_opens_on_controller_open_signal() -> void:
	var panel: DialoguePanel = PanelScene.instantiate()
	add_child_autofree(panel)
	await get_tree().process_frame
	var tree: DialogueTreeDef = _make_simple_tree()
	var dc: Node = _controller()
	dc.open(tree, &"flavor")
	await get_tree().process_frame
	assert_true(panel.is_open(), "panel is_open() true after controller.open()")
	assert_true(panel.visible, "panel visible after controller.open()")


# ---- AC3: panel hides when controller closes session ------------

func test_panel_closes_on_controller_close_signal() -> void:
	var panel: DialoguePanel = PanelScene.instantiate()
	add_child_autofree(panel)
	await get_tree().process_frame
	var tree: DialogueTreeDef = _make_simple_tree()
	var dc: Node = _controller()
	dc.open(tree, &"flavor")
	await get_tree().process_frame
	dc.close()
	await get_tree().process_frame
	assert_false(panel.is_open(), "panel is_open() false after controller.close()")
	assert_false(panel.visible, "panel hidden after controller.close()")


# ---- AC4: panel _exit_tree safety closes active session ---------

func test_panel_exit_tree_closes_active_dialogue() -> void:
	# Safety guard parallel to InventoryPanel._exit_tree's Engine.time_scale
	# restore: if the panel is freed mid-session (scene reload, HTML5 tab-blur),
	# the controller must not stay stuck at is_active() == true (which would
	# permanently gate Player input).
	var panel: DialoguePanel = PanelScene.instantiate()
	add_child(panel)  # NOT autofree — we free explicitly below
	await get_tree().process_frame
	var tree: DialogueTreeDef = _make_simple_tree()
	var dc: Node = _controller()
	dc.open(tree, &"flavor")
	await get_tree().process_frame
	assert_true(dc.is_active(), "session active before panel free")
	panel.queue_free()
	# Awaiting two frames so _exit_tree fires + signal propagates.
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(dc.is_active(),
		"controller is_active() false after panel free — Player input never permanently gated")


# ---- AC5: Player attack-input gate reads DialogueController.is_active() ----

func test_player_dialogue_is_active_returns_false_when_no_session() -> void:
	var player: Player = PlayerScript.new()
	add_child_autofree(player)
	assert_false(player._dialogue_is_active(),
		"_dialogue_is_active() false when no dialogue session open")


func test_player_dialogue_is_active_returns_true_during_session() -> void:
	var player: Player = PlayerScript.new()
	add_child_autofree(player)
	var tree: DialogueTreeDef = _make_simple_tree()
	var dc: Node = _controller()
	dc.open(tree, &"flavor")
	assert_true(player._dialogue_is_active(),
		"_dialogue_is_active() true while dialogue session open")
	dc.close()
	assert_false(player._dialogue_is_active(),
		"_dialogue_is_active() false after close")


# ---- AC6: panel renders response buttons when responses presented ----

func test_panel_renders_response_buttons_on_responses_presented() -> void:
	var panel: DialoguePanel = PanelScene.instantiate()
	add_child_autofree(panel)
	await get_tree().process_frame
	var tree: DialogueTreeDef = _make_tree_with_responses()
	var dc: Node = _controller()
	dc.open(tree, &"flavor")
	await get_tree().process_frame
	# Advance past the only line → responses presented.
	dc.advance_line()
	await get_tree().process_frame
	# Two responses authored → two buttons rendered.
	var container: VBoxContainer = panel.get_node_or_null(
		"Background/ResponseContainer") as VBoxContainer
	assert_not_null(container, "response container exists")
	var button_count: int = 0
	for child in container.get_children():
		if child is Button:
			button_count += 1
	assert_eq(button_count, 2, "two response buttons rendered for two-response branch")


# ---- Helpers --------------------------------------------------------

func _controller() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("DialogueController")


func _make_simple_tree() -> DialogueTreeDef:
	var b: DialogueBranch = BranchScript.new()
	b.lines = ["Line one.", "Line two."]
	b.responses = []
	var t: DialogueTreeDef = TreeScript.new()
	t.npc_id = &"simple_npc"
	t.display_name = "Simple"
	t.branches = {&"flavor": b}
	t.default_branch_key = &"flavor"
	return t


func _make_tree_with_responses() -> DialogueTreeDef:
	var r1: DialogueResponse = ResponseScript.new()
	r1.text = "Yes"
	r1.next_branch_key = &""
	var r2: DialogueResponse = ResponseScript.new()
	r2.text = "No"
	r2.next_branch_key = &""
	var b: DialogueBranch = BranchScript.new()
	b.lines = ["Choose."]
	b.responses = [r1, r2]
	var t: DialogueTreeDef = TreeScript.new()
	t.npc_id = &"choice_npc"
	t.display_name = "Choice"
	t.branches = {&"flavor": b}
	t.default_branch_key = &"flavor"
	return t
