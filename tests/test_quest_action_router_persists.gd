extends GutTest
## Tests for QuestActionRouter persistence wiring (W2-T6 extension of the
## PR #347 listener stub). Ticket `86c9y7ydg`.
##
## The W2-T2 stub recorded payloads + echoed signals; W2-T6 adds the
## persistence path:
##
##   - `accept_bounty:<npc_id>` → write QuestState to Player.active_bounty,
##     emit `quest_accepted`. Rejects if already-active.
##   - `complete_bounty:<npc_id>` → append quest_id to Player.completed_bounties,
##     clear Player.active_bounty, emit `quest_completed`. Rejects if
##     active.quest_id doesn't match.
##
## The router resolves Player via the `&"player"` group. These tests stage
## a stand-in Node in the group (bare-instanced Player is heavy and pulls
## CharacterBody2D + scene-tree wiring). The stand-in just exposes
## `active_bounty` + `completed_bounties` fields the router writes to.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")
const TreeScript: Script = preload("res://scripts/dialogue/DialogueTreeDef.gd")
const BranchScript: Script = preload("res://scripts/dialogue/DialogueBranch.gd")
const ResponseScript: Script = preload(
	"res://scripts/dialogue/DialogueResponse.gd")
const QuestStateScript: Script = preload("res://scripts/quests/QuestState.gd")

var _warn_guard: NoWarningGuard
var _player_stub: Node = null
var _quest_accepted_log: Array = []
var _quest_completed_log: Array = []


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()
	_quest_accepted_log.clear()
	_quest_completed_log.clear()
	# Force-close any leaked active dialogue from a prior test.
	var dc: Node = _controller()
	if dc != null and dc.has_method("is_active") and dc.is_active():
		dc.close()
	var router: Node = _router()
	if router != null and router.has_method("clear"):
		router.clear()
	# Stage a Player-shaped stub in the `&"player"` group so the router can
	# resolve it. Stand-in (not bare Player) keeps tests light + avoids
	# CharacterBody2D wiring that has nothing to do with quest persistence.
	_player_stub = Node.new()
	_player_stub.name = "PlayerStubForQuestRouterTests"
	# Initial state matches the W2-T6 Player defaults.
	_player_stub.set("active_bounty", null)
	_player_stub.set("completed_bounties", [])
	_player_stub.add_to_group("player")
	add_child_autofree(_player_stub)
	# Subscribe to W2-T6 signals.
	if router != null:
		router.quest_accepted.connect(_on_quest_accepted)
		router.quest_completed.connect(_on_quest_completed)


func after_each() -> void:
	var router: Node = _router()
	if router != null:
		if router.quest_accepted.is_connected(_on_quest_accepted):
			router.quest_accepted.disconnect(_on_quest_accepted)
		if router.quest_completed.is_connected(_on_quest_completed):
			router.quest_completed.disconnect(_on_quest_completed)
	var dc: Node = _controller()
	if dc != null and dc.has_method("close"):
		dc.close()
	if router != null and router.has_method("clear"):
		router.clear()
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null
	_player_stub = null


# ---- AC1: accept_bounty writes Player.active_bounty -------------------

func test_accept_bounty_writes_active_bounty_and_emits_signal() -> void:
	# Fire the Sister-Ennick accept-bounty action via a dialogue tree —
	# end-to-end through the controller's quest_action_invoked signal.
	var tree: DialogueTreeDef = _make_sister_ennick_accept_tree()
	var dc: Node = _controller()
	dc.open(tree, &"pre_quest")
	dc.advance_line()
	dc.select_response(0)  # accept_bounty:hub_sister_ennick
	# Player.active_bounty was written.
	var ab: Variant = _player_stub.get("active_bounty")
	assert_true(ab is QuestState,
		"active_bounty is a QuestState after accept")
	var qs: QuestState = ab as QuestState
	assert_eq(qs.quest_id, &"s1_recover_stoker_proof",
		"active_bounty.quest_id matches NPC's offered quest")
	assert_eq(qs.state, &"quest_active",
		"freshly-accepted bounty state is quest_active")
	assert_true(qs.accepted_at_tick > 0,
		"accepted_at_tick stamped from Time.get_ticks_msec()")
	assert_eq(qs.completion_progress.size(), 0,
		"completion_progress starts empty")
	# Signal fired.
	assert_eq(_quest_accepted_log.size(), 1,
		"quest_accepted signal fired exactly once")
	assert_eq(_quest_accepted_log[0], &"s1_recover_stoker_proof",
		"quest_accepted carries the quest_id")


# ---- AC2: accept_bounty rejects when active_bounty is non-null --------

func test_accept_bounty_rejected_when_active_bounty_already_set() -> void:
	# Seed an existing active bounty + fire accept-bounty for the SAME NPC.
	# Single-active-bounty lock should reject with a WarningBus.warn(...,
	# "quest"); _player_stub.active_bounty stays unchanged.
	var seeded: QuestState = QuestStateScript.new()
	seeded.quest_id = &"existing_quest"
	seeded.state = &"quest_active"
	_player_stub.set("active_bounty", seeded)
	_warn_guard.expect_warning("rejected")  # single-active-bounty lock
	# Fire accept.
	var tree: DialogueTreeDef = _make_sister_ennick_accept_tree()
	var dc: Node = _controller()
	dc.open(tree, &"pre_quest")
	dc.advance_line()
	dc.select_response(0)
	# active_bounty unchanged.
	var ab: Variant = _player_stub.get("active_bounty")
	assert_true(ab is QuestState)
	assert_eq((ab as QuestState).quest_id, &"existing_quest",
		"existing active_bounty preserved on rejected accept")
	# No signal.
	assert_eq(_quest_accepted_log.size(), 0,
		"quest_accepted did NOT fire on rejection")


# ---- AC3: complete_bounty moves quest_id to completed + clears active --

func test_complete_bounty_appends_to_completed_and_clears_active() -> void:
	# Seed an active bounty matching Sister Ennick's offered quest, then
	# fire complete_bounty.
	var active: QuestState = QuestStateScript.new()
	active.quest_id = &"s1_recover_stoker_proof"
	active.state = &"quest_active"
	_player_stub.set("active_bounty", active)
	var tree: DialogueTreeDef = _make_sister_ennick_complete_tree()
	var dc: Node = _controller()
	dc.open(tree, &"quest_active")
	dc.advance_line()
	dc.select_response(0)  # complete_bounty:hub_sister_ennick
	# Player.active_bounty is cleared.
	assert_eq(_player_stub.get("active_bounty"), null,
		"active_bounty cleared on complete")
	# completed_bounties contains the quest_id.
	var completed: Array = _player_stub.get("completed_bounties")
	assert_eq(completed.size(), 1,
		"completed_bounties has one entry after complete")
	assert_eq(String(completed[0]), "s1_recover_stoker_proof",
		"completed_bounties entry matches the completed quest_id")
	# Signal fired.
	assert_eq(_quest_completed_log.size(), 1,
		"quest_completed signal fired exactly once")
	assert_eq(_quest_completed_log[0], &"s1_recover_stoker_proof")


# ---- AC4: complete_bounty rejects when no active bounty --------------

func test_complete_bounty_rejected_when_no_active_bounty() -> void:
	# Player has no active bounty — fire complete-bounty. Router should
	# WarningBus.warn(..., "quest") and NOT mutate state.
	_warn_guard.expect_warning("rejected")
	var tree: DialogueTreeDef = _make_sister_ennick_complete_tree()
	var dc: Node = _controller()
	dc.open(tree, &"quest_active")
	dc.advance_line()
	dc.select_response(0)
	assert_eq(_player_stub.get("active_bounty"), null,
		"active_bounty unchanged on rejected complete")
	var completed: Array = _player_stub.get("completed_bounties")
	assert_eq(completed.size(), 0,
		"completed_bounties unchanged on rejected complete")
	assert_eq(_quest_completed_log.size(), 0,
		"quest_completed did NOT fire on rejection")


# ---- AC5: complete_bounty rejects when active quest_id mismatches ----

func test_complete_bounty_rejected_when_active_quest_id_mismatches() -> void:
	# Active bounty has a different quest_id than the NPC's offered quest.
	# Defensive against content-vs-engine drift.
	var mismatch: QuestState = QuestStateScript.new()
	mismatch.quest_id = &"some_other_quest"  # NOT s1_recover_stoker_proof
	_player_stub.set("active_bounty", mismatch)
	_warn_guard.expect_warning("does NOT match")
	var tree: DialogueTreeDef = _make_sister_ennick_complete_tree()
	var dc: Node = _controller()
	dc.open(tree, &"quest_active")
	dc.advance_line()
	dc.select_response(0)
	# active_bounty untouched.
	var ab: Variant = _player_stub.get("active_bounty")
	assert_true(ab is QuestState)
	assert_eq((ab as QuestState).quest_id, &"some_other_quest",
		"mismatched active_bounty preserved on rejected complete")
	var completed: Array = _player_stub.get("completed_bounties")
	assert_eq(completed.size(), 0)


# ---- AC6: open_vendor / reforge are no-op (verb dispatch test) -------

func test_open_vendor_action_is_noop_on_persistence_layer() -> void:
	# open_vendor:<npc_id> is W3+ scope — router echoes via listener-stub
	# state but does NOT mutate Player.
	var tree: DialogueTreeDef = _make_open_vendor_tree()
	var dc: Node = _controller()
	dc.open(tree, &"flavor")
	dc.advance_line()
	dc.select_response(0)
	# Listener-stub state populated.
	var router: Node = _router()
	assert_eq(router.last_quest_action(), &"open_vendor:hub_hadda",
		"router records the open_vendor verb in listener-stub state")
	# Persistence unchanged.
	assert_eq(_player_stub.get("active_bounty"), null,
		"open_vendor does NOT mutate active_bounty")
	var completed: Array = _player_stub.get("completed_bounties")
	assert_eq(completed.size(), 0,
		"open_vendor does NOT mutate completed_bounties")


# ---- AC7: accept → complete full flow (integration) ------------------

func test_full_accept_then_complete_flow() -> void:
	# Compound scenario: accept the bounty, then complete it. Both phases
	# should land cleanly + emit their respective signals.
	#
	# Phase 1: accept.
	var accept_tree: DialogueTreeDef = _make_sister_ennick_accept_tree()
	var dc: Node = _controller()
	dc.open(accept_tree, &"pre_quest")
	dc.advance_line()
	dc.select_response(0)
	dc.close()
	# Verify accept landed.
	var ab: Variant = _player_stub.get("active_bounty")
	assert_true(ab is QuestState, "accept landed: active_bounty set")
	assert_eq((ab as QuestState).quest_id, &"s1_recover_stoker_proof")
	# Phase 2: complete.
	var complete_tree: DialogueTreeDef = _make_sister_ennick_complete_tree()
	dc.open(complete_tree, &"quest_active")
	dc.advance_line()
	dc.select_response(0)
	# Verify complete landed.
	assert_eq(_player_stub.get("active_bounty"), null,
		"complete cleared active_bounty")
	var completed: Array = _player_stub.get("completed_bounties")
	assert_eq(completed.size(), 1)
	assert_eq(String(completed[0]), "s1_recover_stoker_proof")
	# Both signals fired.
	assert_eq(_quest_accepted_log.size(), 1)
	assert_eq(_quest_completed_log.size(), 1)


# ---- Helpers ---------------------------------------------------------

func _controller() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("DialogueController")


func _router() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("QuestActionRouter")


func _on_quest_accepted(quest_id: StringName) -> void:
	_quest_accepted_log.append(quest_id)


func _on_quest_completed(quest_id: StringName) -> void:
	_quest_completed_log.append(quest_id)


# Tree factories (Sister-Ennick-shaped + open_vendor flavor) -----------

func _make_sister_ennick_accept_tree() -> DialogueTreeDef:
	var accept: DialogueResponse = ResponseScript.new()
	accept.text = "I will bring you proof."
	accept.next_branch_key = &"accepted"
	accept.quest_action = &"accept_bounty:hub_sister_ennick"
	var pre_quest: DialogueBranch = BranchScript.new()
	pre_quest.lines = ["Will you take it?"]
	pre_quest.responses = [accept]
	var accepted: DialogueBranch = BranchScript.new()
	accepted.lines = ["Walk well."]
	accepted.responses = []
	var tree: DialogueTreeDef = TreeScript.new()
	tree.npc_id = &"hub_sister_ennick"
	tree.display_name = "Sister Ennick Test Tree"
	tree.branches = {
		&"pre_quest": pre_quest,
		&"accepted": accepted,
	}
	tree.default_branch_key = &"pre_quest"
	return tree


func _make_sister_ennick_complete_tree() -> DialogueTreeDef:
	var turnin: DialogueResponse = ResponseScript.new()
	turnin.text = "Here is the proof."
	turnin.next_branch_key = &"thanks"
	turnin.quest_action = &"complete_bounty:hub_sister_ennick"
	var quest_active: DialogueBranch = BranchScript.new()
	quest_active.lines = ["Did you bring it?"]
	quest_active.responses = [turnin]
	var thanks: DialogueBranch = BranchScript.new()
	thanks.lines = ["The cloister sleeps quieter."]
	thanks.responses = []
	var tree: DialogueTreeDef = TreeScript.new()
	tree.npc_id = &"hub_sister_ennick"
	tree.display_name = "Sister Ennick Complete Tree"
	tree.branches = {
		&"quest_active": quest_active,
		&"thanks": thanks,
	}
	tree.default_branch_key = &"quest_active"
	return tree


func _make_open_vendor_tree() -> DialogueTreeDef:
	var browse: DialogueResponse = ResponseScript.new()
	browse.text = "Show me what you have."
	browse.next_branch_key = &""
	browse.quest_action = &"open_vendor:hub_hadda"
	var flavor: DialogueBranch = BranchScript.new()
	flavor.lines = ["Welcome."]
	flavor.responses = [browse]
	var tree: DialogueTreeDef = TreeScript.new()
	tree.npc_id = &"hub_hadda"
	tree.display_name = "Vendor Test"
	tree.branches = {&"flavor": flavor}
	tree.default_branch_key = &"flavor"
	return tree
