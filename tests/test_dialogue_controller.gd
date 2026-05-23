extends GutTest
## Tests for the DialogueController autoload (ticket `86c9xuab3` — M3 Tier 3
## W1 dialogue system spike).
##
## Invariants covered (5 minimum per dispatch brief):
##   1. State-machine lifecycle pin — start → line-advance → response →
##      navigate → close.
##   2. Branch resolution — open() resolves quest_state branch when present,
##      falls back to default_branch_key when absent.
##   3. quest_action side-effect channel — picking a response with
##      `quest_action != &""` emits `quest_action_invoked` BEFORE navigation.
##   4. Choice-index bounds — negative + out-of-range indices rejected with
##      WarningBus warn (not panic).
##   5. is_active() input-gating invariant — true after open, false after
##      close, false initially. Drives Player.gd attack-input gate.
##   6. Single-session guard — second open() rejected when one already
##      active.
##   7. Unknown-branch navigation — response navigating to a branch_key not
##      in tree closes dialogue + emits WarningBus warn.
##   8. Empty-lines branch — branch with no lines but with responses presents
##      responses immediately on open.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

const TreeScript: Script = preload("res://scripts/dialogue/DialogueTreeDef.gd")
const BranchScript: Script = preload("res://scripts/dialogue/DialogueBranch.gd")
const ResponseScript: Script = preload("res://scripts/dialogue/DialogueResponse.gd")

var _warn_guard: NoWarningGuard
# Signal capture for the active test — reset in before_each.
var _branch_opened_log: Array = []
var _line_displayed_log: Array = []
var _responses_presented_log: Array = []
var _response_selected_log: Array = []
var _quest_action_log: Array = []
var _dialogue_closed_log: Array = []


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()
	_branch_opened_log.clear()
	_line_displayed_log.clear()
	_responses_presented_log.clear()
	_response_selected_log.clear()
	_quest_action_log.clear()
	_dialogue_closed_log.clear()
	# Ensure controller is idle at start (a prior test may have left it open
	# if an assertion failed before close()). Belt-and-braces.
	var dc: Node = _controller()
	if dc != null and dc.has_method("is_active") and dc.is_active():
		dc.close()
	_connect_signals()


func after_each() -> void:
	_disconnect_signals()
	# Force-close so a failing test mid-session doesn't leak `_active=true`
	# into the next test.
	var dc: Node = _controller()
	if dc != null and dc.has_method("close"):
		dc.close()
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- AC1: state-machine lifecycle pin -------------------------------


func test_lifecycle_open_advance_select_close() -> void:
	var tree: DialogueTreeDef = _make_two_branch_tree_with_responses()
	var dc: Node = _controller()
	assert_not_null(dc, "DialogueController autoload registered")
	# open
	var opened: bool = dc.open(tree, &"flavor")
	assert_true(opened, "open() returns true on success")
	assert_true(dc.is_active(), "is_active() true after open")
	assert_eq(_branch_opened_log.size(), 1, "branch_opened fired once")
	assert_eq(_branch_opened_log[0]["branch_key"], &"flavor", "branch_key is flavor")
	# Line 0 auto-displayed on open
	assert_eq(_line_displayed_log.size(), 1, "line_displayed fired for line 0")
	assert_eq(_line_displayed_log[0]["index"], 0, "first line is index 0")
	# advance to line 1
	dc.advance_line()
	assert_eq(_line_displayed_log.size(), 2, "line_displayed fired for line 1")
	assert_eq(_line_displayed_log[1]["index"], 1, "second line is index 1")
	# advance past last line → responses present
	dc.advance_line()
	assert_eq(_responses_presented_log.size(), 1, "responses_presented fired")
	# select response 0 (navigates to "quest_active" branch)
	dc.select_response(0)
	assert_eq(_response_selected_log.size(), 1, "response_selected fired")
	# branch_opened fired again for the new branch
	assert_eq(_branch_opened_log.size(), 2, "branch_opened fired for navigation")
	assert_eq(
		_branch_opened_log[1]["branch_key"], &"quest_active", "navigated to quest_active branch"
	)
	# quest_active branch has 1 line + 0 responses → advance closes
	dc.advance_line()
	assert_false(dc.is_active(), "is_active() false after close")
	assert_eq(_dialogue_closed_log.size(), 1, "dialogue_closed fired once")


# ---- AC2: branch resolution + default fallback ------------------


func test_open_resolves_quest_state_branch() -> void:
	var tree: DialogueTreeDef = _make_two_branch_tree_with_responses()
	var dc: Node = _controller()
	dc.open(tree, &"quest_active")
	assert_eq(
		_branch_opened_log[0]["branch_key"],
		&"quest_active",
		"opened with quest_active resolved to quest_active branch"
	)


func test_open_falls_back_to_default_branch() -> void:
	var tree: DialogueTreeDef = _make_two_branch_tree_with_responses()
	var dc: Node = _controller()
	# Tree has no quest_completed branch — should fall back to default (flavor).
	dc.open(tree, &"quest_completed")
	assert_eq(
		_branch_opened_log[0]["branch_key"], &"flavor", "fell back to default_branch_key (flavor)"
	)


# ---- AC3: quest_action side-effect channel --------------------


func test_quest_action_emits_before_navigation() -> void:
	var tree: DialogueTreeDef = _make_tree_with_quest_action_response()
	var dc: Node = _controller()
	dc.open(tree, &"pre_quest")
	# Advance past the single line into responses.
	dc.advance_line()
	# Select the response with quest_action = &"accept_bounty:test"
	dc.select_response(0)
	assert_eq(_quest_action_log.size(), 1, "quest_action_invoked fired once")
	assert_eq(
		_quest_action_log[0]["action_id"],
		&"accept_bounty:test",
		"quest_action_invoked carries the action id verbatim"
	)
	assert_eq(
		_quest_action_log[0]["npc_id"],
		&"action_test_npc",
		"quest_action_invoked carries the npc_id"
	)
	# Pin firing order: quest_action emits BEFORE branch_opened (navigation).
	# response_selected also fires; both fire before navigation's branch_opened.
	# So branch_opened count post-select = 2 (the initial open + the
	# response-navigation one).
	assert_eq(_branch_opened_log.size(), 2, "branch_opened fired again after select (navigation)")


# ---- AC4: choice-index bounds rejection -------------------


func test_select_response_negative_index_rejected() -> void:
	var tree: DialogueTreeDef = _make_tree_with_quest_action_response()
	var dc: Node = _controller()
	dc.open(tree, &"pre_quest")
	dc.advance_line()  # advance into responses
	# Negative index — must reject with WarningBus warn, not panic, not navigate.
	_warn_guard.expect_warning("out of range")
	dc.select_response(-1)
	assert_eq(_response_selected_log.size(), 0, "negative idx does NOT fire response_selected")
	assert_true(dc.is_active(), "negative idx does NOT close dialogue")


func test_select_response_out_of_range_index_rejected() -> void:
	var tree: DialogueTreeDef = _make_tree_with_quest_action_response()
	var dc: Node = _controller()
	dc.open(tree, &"pre_quest")
	dc.advance_line()
	# tree has 1 response — idx 1 is out of range (only 0 valid).
	_warn_guard.expect_warning("out of range")
	dc.select_response(1)
	assert_eq(_response_selected_log.size(), 0, "out-of-range idx does NOT fire response_selected")
	assert_true(dc.is_active(), "out-of-range idx does NOT close dialogue")


# ---- AC5: is_active() drives Player attack-input gate ----------


func test_is_active_initially_false() -> void:
	var dc: Node = _controller()
	# Force-closed in before_each. Pin the idle state.
	assert_false(dc.is_active(), "is_active() false when no session open")


func test_is_active_true_after_open_false_after_close() -> void:
	var tree: DialogueTreeDef = _make_two_branch_tree_with_responses()
	var dc: Node = _controller()
	dc.open(tree, &"flavor")
	assert_true(dc.is_active(), "true while session open")
	dc.close()
	assert_false(dc.is_active(), "false after close")


# ---- AC6: single-session guard ------------------------------


func test_second_open_rejected_when_session_active() -> void:
	var tree: DialogueTreeDef = _make_two_branch_tree_with_responses()
	var dc: Node = _controller()
	assert_true(dc.open(tree, &"flavor"), "first open succeeds")
	_warn_guard.expect_warning("already active")
	var second: bool = dc.open(tree, &"quest_active")
	assert_false(second, "second open returns false")
	# branch_opened only fired ONCE — second was rejected.
	assert_eq(_branch_opened_log.size(), 1, "branch_opened fired exactly once")


# ---- AC7: unknown-branch navigation closes + warns ----------


func test_unknown_next_branch_key_closes_with_warning() -> void:
	var tree: DialogueTreeDef = _make_tree_with_bad_next_branch()
	var dc: Node = _controller()
	dc.open(tree, &"start")
	dc.advance_line()  # advance into responses
	_warn_guard.expect_warning("unknown branch_key")
	dc.select_response(0)  # this response points to a branch that doesn't exist
	assert_false(dc.is_active(), "unknown-branch navigation closes dialogue")
	assert_eq(_dialogue_closed_log.size(), 1, "dialogue_closed fired on unknown-branch close")


# ---- AC8: empty-lines + responses-only branch presents immediately ----


func test_branch_with_no_lines_presents_responses_immediately() -> void:
	var choice_only: DialogueBranch = BranchScript.new()
	choice_only.lines = []
	var resp: DialogueResponse = ResponseScript.new()
	resp.text = "OK"
	resp.next_branch_key = &""
	choice_only.responses = [resp]
	var tree: DialogueTreeDef = TreeScript.new()
	tree.npc_id = &"choice_npc"
	tree.display_name = "Choice NPC"
	tree.branches = {&"flavor": choice_only}
	tree.default_branch_key = &"flavor"
	var dc: Node = _controller()
	dc.open(tree, &"flavor")
	assert_eq(_line_displayed_log.size(), 0, "no line_displayed on empty-lines branch")
	assert_eq(
		_responses_presented_log.size(),
		1,
		"responses_presented fired immediately on open of empty-lines branch"
	)


# ---- Open with null tree rejected ---------------------------


func test_open_with_null_tree_rejected() -> void:
	var dc: Node = _controller()
	_warn_guard.expect_warning("null tree")
	var ok: bool = dc.open(null, &"flavor")
	assert_false(ok, "open(null) returns false")
	assert_false(dc.is_active(), "is_active stays false after null-tree open")


# ---- Open with unresolvable branch rejected -----------------


func test_open_with_unresolvable_branch_rejected() -> void:
	var tree: DialogueTreeDef = TreeScript.new()
	tree.npc_id = &"empty_npc"
	tree.default_branch_key = &"nonexistent"
	tree.branches = {}
	var dc: Node = _controller()
	_warn_guard.expect_warning("no branch for quest_state")
	var ok: bool = dc.open(tree, &"flavor")
	assert_false(ok, "open() returns false when no branch resolves")
	assert_false(dc.is_active(), "is_active stays false")


# ---- Helpers --------------------------------------------------------


func _controller() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("DialogueController")


func _connect_signals() -> void:
	var dc: Node = _controller()
	if dc == null:
		return
	dc.branch_opened.connect(_on_branch_opened)
	dc.line_displayed.connect(_on_line_displayed)
	dc.responses_presented.connect(_on_responses_presented)
	dc.response_selected.connect(_on_response_selected)
	dc.quest_action_invoked.connect(_on_quest_action_invoked)
	dc.dialogue_closed.connect(_on_dialogue_closed)


func _disconnect_signals() -> void:
	var dc: Node = _controller()
	if dc == null:
		return
	if dc.branch_opened.is_connected(_on_branch_opened):
		dc.branch_opened.disconnect(_on_branch_opened)
	if dc.line_displayed.is_connected(_on_line_displayed):
		dc.line_displayed.disconnect(_on_line_displayed)
	if dc.responses_presented.is_connected(_on_responses_presented):
		dc.responses_presented.disconnect(_on_responses_presented)
	if dc.response_selected.is_connected(_on_response_selected):
		dc.response_selected.disconnect(_on_response_selected)
	if dc.quest_action_invoked.is_connected(_on_quest_action_invoked):
		dc.quest_action_invoked.disconnect(_on_quest_action_invoked)
	if dc.dialogue_closed.is_connected(_on_dialogue_closed):
		dc.dialogue_closed.disconnect(_on_dialogue_closed)


func _on_branch_opened(npc_id: StringName, branch_key: StringName) -> void:
	_branch_opened_log.append({"npc_id": npc_id, "branch_key": branch_key})


func _on_line_displayed(line_index: int, line_text: String) -> void:
	_line_displayed_log.append({"index": line_index, "text": line_text})


func _on_responses_presented(responses: Array) -> void:
	_responses_presented_log.append({"count": responses.size()})


func _on_response_selected(idx: int, response: DialogueResponse) -> void:
	_response_selected_log.append({"idx": idx, "response": response})


func _on_quest_action_invoked(action_id: StringName, npc_id: StringName) -> void:
	_quest_action_log.append({"action_id": action_id, "npc_id": npc_id})


func _on_dialogue_closed(npc_id: StringName) -> void:
	_dialogue_closed_log.append({"npc_id": npc_id})


# Tree factories -------------------------------------------------------


## Two branches: flavor (2 lines, 1 response → navigates to quest_active),
## quest_active (1 line, 0 responses → closes on advance).
func _make_two_branch_tree_with_responses() -> DialogueTreeDef:
	var nav_response: DialogueResponse = ResponseScript.new()
	nav_response.text = "Continue"
	nav_response.next_branch_key = &"quest_active"
	var flavor: DialogueBranch = BranchScript.new()
	flavor.lines = ["line zero", "line one"]
	flavor.responses = [nav_response]
	var active: DialogueBranch = BranchScript.new()
	active.lines = ["active line"]
	active.responses = []
	var tree: DialogueTreeDef = TreeScript.new()
	tree.npc_id = &"test_npc"
	tree.display_name = "Test NPC"
	tree.branches = {
		&"flavor": flavor,
		&"quest_active": active,
	}
	tree.default_branch_key = &"flavor"
	return tree


## Tree with one branch + one response carrying a quest_action. Used for the
## quest_action side-effect test.
func _make_tree_with_quest_action_response() -> DialogueTreeDef:
	var action_response: DialogueResponse = ResponseScript.new()
	action_response.text = "Accept"
	action_response.next_branch_key = &"accepted"
	action_response.quest_action = &"accept_bounty:test"
	var pre_quest: DialogueBranch = BranchScript.new()
	pre_quest.lines = ["Will you take the bounty?"]
	pre_quest.responses = [action_response]
	var accepted: DialogueBranch = BranchScript.new()
	accepted.lines = ["Good."]
	accepted.responses = []
	var tree: DialogueTreeDef = TreeScript.new()
	tree.npc_id = &"action_test_npc"
	tree.display_name = "Action Test NPC"
	tree.branches = {
		&"pre_quest": pre_quest,
		&"accepted": accepted,
	}
	tree.default_branch_key = &"pre_quest"
	return tree


## Tree where the only response's next_branch_key points to a non-existent
## branch — exercises the unknown-branch-close-with-warning path.
func _make_tree_with_bad_next_branch() -> DialogueTreeDef:
	var bad_response: DialogueResponse = ResponseScript.new()
	bad_response.text = "Go to nowhere"
	bad_response.next_branch_key = &"nonexistent_branch"
	var start: DialogueBranch = BranchScript.new()
	start.lines = ["A choice."]
	start.responses = [bad_response]
	var tree: DialogueTreeDef = TreeScript.new()
	tree.npc_id = &"bad_nav_npc"
	tree.display_name = "Bad Nav NPC"
	tree.branches = {&"start": start}
	tree.default_branch_key = &"start"
	return tree
