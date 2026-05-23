extends GutTest
## Tests for the QuestActionRouter autoload listener stub (ticket W2-T2
## `86c9y0zyv`).
##
## The router subscribes to DialogueController.quest_action_invoked +
## branch_opened + dialogue_closed and records the most-recent payload for
## paired-test verification. Full Track 3 W2 BountyController state mutation
## is out-of-scope.
##
## Invariants covered:
##   1. Autoload registered + reachable at boot.
##   2. Initial state — last_quest_action() == &"", has_received_quest_action()
##      false.
##   3. quest_action_invoked → router records action_id + npc_id + branch_key,
##      emits `quest_action_received` echo with the same payload.
##   4. dialogue_closed → router emits `dialogue_closed_observed` echo.
##   5. clear() resets all last_* fields + has_received flag.
##   6. Multiple quest_actions in sequence — router records the MOST RECENT.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")
const TreeScript: Script = preload("res://scripts/dialogue/DialogueTreeDef.gd")
const BranchScript: Script = preload("res://scripts/dialogue/DialogueBranch.gd")
const ResponseScript: Script = preload("res://scripts/dialogue/DialogueResponse.gd")

var _warn_guard: NoWarningGuard
var _quest_action_received_log: Array = []
var _dialogue_closed_observed_log: Array = []


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()
	_quest_action_received_log.clear()
	_dialogue_closed_observed_log.clear()
	# Force-close any leaked active session from a prior test.
	var dc: Node = _controller()
	if dc != null and dc.has_method("is_active") and dc.is_active():
		dc.close()
	# Reset router state before each test.
	var router: Node = _router()
	if router != null and router.has_method("clear"):
		router.clear()
	_connect_router_signals()


func after_each() -> void:
	_disconnect_router_signals()
	var dc: Node = _controller()
	if dc != null and dc.has_method("close"):
		dc.close()
	var router: Node = _router()
	if router != null and router.has_method("clear"):
		router.clear()
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- AC1: autoload registered + reachable -----------------------------

func test_router_autoload_registered() -> void:
	var router: Node = _router()
	assert_not_null(router, "QuestActionRouter autoload registered")
	assert_true(router.has_method("last_quest_action"),
		"router exposes last_quest_action()")
	assert_true(router.has_method("last_npc_id"),
		"router exposes last_npc_id()")
	assert_true(router.has_method("last_branch_key"),
		"router exposes last_branch_key()")
	assert_true(router.has_method("has_received_quest_action"),
		"router exposes has_received_quest_action()")
	assert_true(router.has_method("clear"),
		"router exposes clear()")
	assert_true(router.has_signal("quest_action_received"),
		"router exposes quest_action_received signal")
	assert_true(router.has_signal("dialogue_closed_observed"),
		"router exposes dialogue_closed_observed signal")


# ---- AC2: initial state ---------------------------------------------

func test_initial_state_is_empty() -> void:
	var router: Node = _router()
	assert_eq(router.last_quest_action(), &"",
		"last_quest_action() is empty StringName initially")
	assert_eq(router.last_npc_id(), &"",
		"last_npc_id() is empty StringName initially")
	assert_eq(router.last_branch_key(), &"",
		"last_branch_key() is empty StringName initially")
	assert_false(router.has_received_quest_action(),
		"has_received_quest_action() false initially")


# ---- AC3: quest_action_invoked → record + echo ----------------------

func test_quest_action_recorded_and_echoed() -> void:
	var tree: DialogueTreeDef = _make_tree_with_quest_action()
	var dc: Node = _controller()
	var router: Node = _router()
	dc.open(tree, &"pre_quest")
	dc.advance_line()  # advance into responses
	dc.select_response(0)  # picks the accept-bounty response
	assert_true(router.has_received_quest_action(),
		"has_received_quest_action() true after select")
	assert_eq(router.last_quest_action(), &"accept_bounty:test_target",
		"last_quest_action() records the action id verbatim")
	assert_eq(router.last_npc_id(), &"router_test_npc",
		"last_npc_id() records the originating NPC")
	# branch_key is captured from branch_opened during the active session;
	# at quest_action_invoked-time the controller is still on `pre_quest`
	# (emit fires BEFORE navigation per dialogue-system.md).
	assert_eq(router.last_branch_key(), &"pre_quest",
		"last_branch_key() is the ORIGINATING branch at quest_action time")
	# Echo signal fired with same payload.
	assert_eq(_quest_action_received_log.size(), 1,
		"quest_action_received echo fired exactly once")
	assert_eq(_quest_action_received_log[0]["action_id"],
		&"accept_bounty:test_target",
		"echo carries action_id")
	assert_eq(_quest_action_received_log[0]["npc_id"], &"router_test_npc",
		"echo carries npc_id")
	assert_eq(_quest_action_received_log[0]["branch_key"], &"pre_quest",
		"echo carries originating branch_key")


# ---- AC4: dialogue_closed → echo ------------------------------------

func test_dialogue_closed_observed_echo() -> void:
	var tree: DialogueTreeDef = _make_simple_closeable_tree()
	var dc: Node = _controller()
	dc.open(tree, &"flavor")
	dc.close()
	assert_eq(_dialogue_closed_observed_log.size(), 1,
		"dialogue_closed_observed echo fired once")
	assert_eq(_dialogue_closed_observed_log[0]["npc_id"],
		&"closeable_npc",
		"echo carries npc_id matching the closed session")


# ---- AC5: clear() resets state --------------------------------------

func test_clear_resets_router_state() -> void:
	var tree: DialogueTreeDef = _make_tree_with_quest_action()
	var dc: Node = _controller()
	var router: Node = _router()
	dc.open(tree, &"pre_quest")
	dc.advance_line()
	dc.select_response(0)
	# Confirm state populated.
	assert_true(router.has_received_quest_action())
	# Close + clear.
	dc.close()
	router.clear()
	assert_eq(router.last_quest_action(), &"",
		"last_quest_action() reset to empty after clear()")
	assert_eq(router.last_npc_id(), &"",
		"last_npc_id() reset to empty after clear()")
	assert_eq(router.last_branch_key(), &"",
		"last_branch_key() reset to empty after clear()")
	assert_false(router.has_received_quest_action(),
		"has_received_quest_action() false after clear()")


# ---- AC6: most-recent wins on multiple quest_actions ----------------

func test_multiple_quest_actions_router_records_most_recent() -> void:
	# A tree where the first response navigates to a second branch which
	# also has a quest_action response. Two sequential select_response calls
	# fire two quest_action_invoked emits — router stores the second one.
	var tree: DialogueTreeDef = _make_two_action_tree()
	var dc: Node = _controller()
	var router: Node = _router()
	dc.open(tree, &"start")
	dc.advance_line()  # advance into first responses
	dc.select_response(0)  # first action
	# Now on second branch — advance + pick second action.
	dc.advance_line()
	dc.select_response(0)  # second action
	assert_eq(router.last_quest_action(), &"second_action:second_target",
		"last_quest_action is the MOST RECENT, not the first")
	assert_eq(_quest_action_received_log.size(), 2,
		"echo fired twice (once per quest_action_invoked)")


# ---- Helpers --------------------------------------------------------

func _controller() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("DialogueController")


func _router() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("QuestActionRouter")


func _connect_router_signals() -> void:
	var router: Node = _router()
	if router == null:
		return
	router.quest_action_received.connect(_on_quest_action_received)
	router.dialogue_closed_observed.connect(_on_dialogue_closed_observed)


func _disconnect_router_signals() -> void:
	var router: Node = _router()
	if router == null:
		return
	if router.quest_action_received.is_connected(_on_quest_action_received):
		router.quest_action_received.disconnect(_on_quest_action_received)
	if router.dialogue_closed_observed.is_connected(_on_dialogue_closed_observed):
		router.dialogue_closed_observed.disconnect(_on_dialogue_closed_observed)


func _on_quest_action_received(
		action_id: StringName,
		npc_id: StringName,
		branch_key: StringName) -> void:
	_quest_action_received_log.append({
		"action_id": action_id,
		"npc_id": npc_id,
		"branch_key": branch_key,
	})


func _on_dialogue_closed_observed(npc_id: StringName) -> void:
	_dialogue_closed_observed_log.append({"npc_id": npc_id})


# Tree factories -----------------------------------------------------

func _make_tree_with_quest_action() -> DialogueTreeDef:
	var accept: DialogueResponse = ResponseScript.new()
	accept.text = "Accept"
	accept.next_branch_key = &"accepted"
	accept.quest_action = &"accept_bounty:test_target"
	var pre_quest: DialogueBranch = BranchScript.new()
	pre_quest.lines = ["Will you take it?"]
	pre_quest.responses = [accept]
	var accepted: DialogueBranch = BranchScript.new()
	accepted.lines = ["Good."]
	accepted.responses = []
	var tree: DialogueTreeDef = TreeScript.new()
	tree.npc_id = &"router_test_npc"
	tree.display_name = "Router Test NPC"
	tree.branches = {
		&"pre_quest": pre_quest,
		&"accepted": accepted,
	}
	tree.default_branch_key = &"pre_quest"
	return tree


func _make_simple_closeable_tree() -> DialogueTreeDef:
	var b: DialogueBranch = BranchScript.new()
	b.lines = ["Just one line."]
	b.responses = []
	var t: DialogueTreeDef = TreeScript.new()
	t.npc_id = &"closeable_npc"
	t.display_name = "Closeable NPC"
	t.branches = {&"flavor": b}
	t.default_branch_key = &"flavor"
	return t


func _make_two_action_tree() -> DialogueTreeDef:
	# start: line + 1 response → quest_action `first_action:first_target` →
	#   navigates to `mid` branch
	# mid: line + 1 response → quest_action `second_action:second_target` →
	#   navigates to `end` (closes)
	# end: 1 line, 0 responses → closes on advance
	var first: DialogueResponse = ResponseScript.new()
	first.text = "First"
	first.next_branch_key = &"mid"
	first.quest_action = &"first_action:first_target"
	var second: DialogueResponse = ResponseScript.new()
	second.text = "Second"
	second.next_branch_key = &"end"
	second.quest_action = &"second_action:second_target"
	var start: DialogueBranch = BranchScript.new()
	start.lines = ["Pick first."]
	start.responses = [first]
	var mid: DialogueBranch = BranchScript.new()
	mid.lines = ["Pick second."]
	mid.responses = [second]
	var endb: DialogueBranch = BranchScript.new()
	endb.lines = ["End."]
	endb.responses = []
	var tree: DialogueTreeDef = TreeScript.new()
	tree.npc_id = &"two_action_npc"
	tree.display_name = "Two Action NPC"
	tree.branches = {
		&"start": start,
		&"mid": mid,
		&"end": endb,
	}
	tree.default_branch_key = &"start"
	return tree
