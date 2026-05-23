extends GutTest
## Drew-nit Part D read-order pin (ticket W2-T2 `86c9y0zyv` — folds the
## PR #320 review-nit routing from `team/priya-pl/post-wave3-sequencing.md`
## v1.2 §5.1).
##
## ## The discipline pinned
##
## Drew's PR #320 review (comment id 4519855248) flagged two engine
## surfaces the save-schema-v5-tier3 survey doc had paper-shaped
## incorrectly:
##
##   - **Nit 1** — `DialogueController.dialogue_closed` is single-arg
##     `(npc_id: StringName)`. Survey had `(npc_id, branch_key)`.
##   - **Nit 2** — `DialogueController.close()` is no-args. Survey had
##     `close(npc_id, branch_key)`.
##
## The load-bearing consequence is the **read-order discipline** for any
## listener that needs the branch_key alongside the npc_id when a dialogue
## closes: it MUST be captured BEFORE `close()` clears state, because
## `DialogueController.close()` calls `_reset_state()` (which clears
## `_branch_key` to `&""`) BEFORE emitting `dialogue_closed`. So a listener
## that reads `DialogueController.current_branch_key()` from inside its
## `_on_dialogue_closed` handler gets `&""` every time — silent regression.
##
## ## The two pins
##
## This file ships TWO independent pins so the discipline survives any
## refactor that touches QuestActionRouter or DialogueController internals:
##
##   1. **Behavioural pin** — open dialogue → fire a quest_action mid-session
##      → close dialogue → assert `QuestActionRouter.last_branch_key()`
##      reflects the originating branch (NOT `&""`). A regression where the
##      router reads branch_key from `_on_dialogue_closed` would fail this
##      pin.
##
##   2. **Source-scan structural pin** (per `.claude/docs/test-conventions.md`
##      § "Source-scan structural pins") — read `QuestActionRouter.gd` as a
##      string and assert that `current_branch_key()` does NOT appear inside
##      the `_on_dialogue_closed` handler body. The handler MUST be
##      mirror-only (no controller state-read). A future refactor adding a
##      `current_branch_key()` call into the closed-handler body would fail
##      this pin LOUDLY, surfacing the invariant for re-review.
##
## Together these pins protect against three distinct regression classes:
##   - Engine-side: the controller's reset-order changes (e.g. clearing
##     branch_key AFTER emitting dialogue_closed) — behavioural pin still
##     passes; source-scan would too (the discipline is still correct, just
##     less fragile). No false alarm.
##   - Router-side: a future contributor reads `current_branch_key()` from
##     `_on_dialogue_closed` to "simplify the wiring" — source-scan fails
##     LOUDLY before the behavioural pin catches it at runtime.
##   - Spec-side: the dispatch brief author paper-shapes a bad listener
##     contract (e.g. assumes two-arg `dialogue_closed`) — the behavioural
##     pin's assertion text names the invariant explicitly, so the contract
##     is documented at the test-name level.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")
const TreeScript: Script = preload("res://scripts/dialogue/DialogueTreeDef.gd")
const BranchScript: Script = preload("res://scripts/dialogue/DialogueBranch.gd")
const ResponseScript: Script = preload("res://scripts/dialogue/DialogueResponse.gd")

const ROUTER_SOURCE_PATH := "res://scripts/quests/QuestActionRouter.gd"

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()
	var dc: Node = _controller()
	if dc != null and dc.has_method("is_active") and dc.is_active():
		dc.close()
	var router: Node = _router()
	if router != null and router.has_method("clear"):
		router.clear()


func after_each() -> void:
	var dc: Node = _controller()
	if dc != null and dc.has_method("close"):
		dc.close()
	var router: Node = _router()
	if router != null and router.has_method("clear"):
		router.clear()
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- Pin 1: behavioural — branch_key survives close ---------------------

func test_router_last_branch_key_survives_close_after_quest_action() -> void:
	# The integration scenario: player picks an accept-bounty response in
	# the `pre_quest` branch → controller emits quest_action_invoked →
	# router captures (action_id, npc_id, branch_key=pre_quest) → controller
	# navigates to `accepted` branch → player walks away (close fires).
	# After close, the router MUST still report `last_branch_key() ==
	# &"pre_quest"` — the originating branch the action was selected FROM,
	# not the destination branch and not the post-close `&""` state.
	#
	# This pins the discipline that the survey-doc Nit-routing called out:
	# capture the branch_key BEFORE close clears state. Capture happens via
	# `branch_opened` subscription during the active session; the
	# `_on_dialogue_closed` handler is mirror-only.
	var tree: DialogueTreeDef = _make_accept_then_close_tree()
	var dc: Node = _controller()
	var router: Node = _router()
	assert_not_null(router, "QuestActionRouter autoload registered")
	# Open on pre_quest (originating branch for the quest_action).
	dc.open(tree, &"pre_quest")
	dc.advance_line()  # into responses
	dc.select_response(0)  # accept_bounty → navigates to `accepted`
	# Router captured the pre_quest branch_key at quest_action_invoked time.
	assert_eq(router.last_branch_key(), &"pre_quest",
		"router captured originating branch_key (pre_quest) at quest_action time")
	# Close — controller's _reset_state clears its internal branch_key to &""
	# BEFORE emitting dialogue_closed.
	dc.close()
	# Behavioural pin: the router's stored branch_key SURVIVES close. If a
	# future refactor moved the branch_key capture into _on_dialogue_closed,
	# the controller's current_branch_key() would return &"" by then and
	# this assertion would fail loudly.
	assert_eq(router.last_branch_key(), &"pre_quest",
		"router last_branch_key() preserves originating branch after close — " +
		"NOT &\"\" (the controller's post-close state)")
	# Sanity — controller IS reset to &"" after close (engine surface check).
	assert_eq(dc.current_branch_key(), &"",
		"DialogueController.current_branch_key() IS &\"\" after close — " +
		"confirming the discipline matters (read-after-close is unsafe)")


# ---- Pin 2: source-scan — _on_dialogue_closed does NOT read controller --

func test_router_source_does_not_call_current_branch_key_in_dialogue_closed_handler() -> void:
	# Per `.claude/docs/test-conventions.md` § "Source-scan structural pins":
	# some invariants are about CODE-ORDERING inside a function, not about
	# externally-observable behaviour. This is one of them — a future
	# contributor "simplifying" QuestActionRouter by reading
	# `DialogueController.current_branch_key()` from `_on_dialogue_closed`
	# would re-introduce the silent-regression class without breaking any
	# behavioural test in normal operation (the controller's reset order
	# would have to also change for the behavioural pin to catch it).
	#
	# We read the file as a string + assert the named call does NOT appear
	# inside the `_on_dialogue_closed` function body.
	var source: String = FileAccess.get_file_as_string(ROUTER_SOURCE_PATH)
	assert_gt(source.length(), 0,
		"QuestActionRouter.gd readable as resource")
	# Find the `_on_dialogue_closed` function definition.
	var fn_start: int = source.find("func _on_dialogue_closed(")
	assert_gt(fn_start, -1,
		"QuestActionRouter.gd defines _on_dialogue_closed function")
	# Find the start of the NEXT top-level function (or end of file) so we
	# scope the search to the handler's body. GDScript top-level functions
	# start at column 0 with `func `.
	var fn_body_start: int = source.find("\n", fn_start)
	var next_fn: int = source.find("\nfunc ", fn_body_start)
	var fn_end: int = next_fn if next_fn > -1 else source.length()
	var fn_body: String = source.substr(fn_body_start, fn_end - fn_body_start)
	# The handler body must NOT call current_branch_key() — that's the
	# read-after-close trap Drew's nit pinned. Same forbidden-call class:
	# DialogueController.current_branch_key(), self.current_branch_key(),
	# or a bare current_branch_key() reference.
	assert_eq(fn_body.find("current_branch_key("), -1,
		"_on_dialogue_closed does NOT call current_branch_key() — " +
		"branch_key must be captured during active session (via branch_opened " +
		"or quest_action_invoked), NOT read post-close from the controller " +
		"(which has already reset to &\"\"). Drew nit 1+2 routing pin.")


# ---- Pin 3: dialogue_closed payload contract -----------------------

func test_dialogue_closed_signal_is_single_arg() -> void:
	# Drew nit 1: `dialogue_closed(npc_id)` is SINGLE-arg. If a future
	# refactor adds a second arg (e.g. `dialogue_closed(npc_id, branch_key)`
	# as the survey paper-shaped), this assertion fails. The signal-shape
	# pin protects the router's `_on_dialogue_closed(npc_id)` handler
	# signature from becoming a silent connect-with-wrong-arity warning.
	var dc: Node = _controller()
	assert_not_null(dc, "DialogueController autoload reachable")
	var sig_list: Array = dc.get_signal_list()
	var found: Dictionary = {}
	for sig: Dictionary in sig_list:
		if String(sig.get("name", "")) == "dialogue_closed":
			found = sig
			break
	assert_true(not found.is_empty(),
		"DialogueController exposes dialogue_closed signal")
	var args: Array = found.get("args", [])
	assert_eq(args.size(), 1,
		"dialogue_closed is single-arg (npc_id); two-arg would be Drew nit 1 regression")
	assert_eq(String(args[0].get("name", "")), "npc_id",
		"dialogue_closed single arg is npc_id")


# ---- Pin 4: close() is no-arg ----------------------------------------

func test_controller_close_is_no_arg() -> void:
	# Drew nit 2: `close() -> void` takes no args. The survey paper-shaped
	# `close(npc_id, branch_key)`. Source-scan pin via method introspection:
	# the engine surface MUST stay single-arg-free so internal callers
	# (DialoguePanel._exit_tree, response navigation) compile cleanly.
	var dc: Node = _controller()
	var method_list: Array = dc.get_method_list()
	var found: Dictionary = {}
	for m: Dictionary in method_list:
		if String(m.get("name", "")) == "close":
			found = m
			break
	assert_true(not found.is_empty(),
		"DialogueController exposes close() method")
	var args: Array = found.get("args", [])
	assert_eq(args.size(), 0,
		"close() is no-arg; (npc_id, branch_key) form would be Drew nit 2 regression")


# ---- Helpers --------------------------------------------------------

func _controller() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("DialogueController")


func _router() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("QuestActionRouter")


# A tree that exercises the quest_action emit + close sequence cleanly:
# pre_quest branch has 1 line + 1 response (Accept → quest_action +
# navigates to `accepted`); `accepted` has 1 line + 0 responses → advance
# closes the dialogue. So the full lifecycle in the test is:
#   open(pre_quest) → advance_line → select_response(0) [quest_action fires] →
#   branch_opened(accepted) → close() [external] → dialogue_closed fires.
func _make_accept_then_close_tree() -> DialogueTreeDef:
	var accept: DialogueResponse = ResponseScript.new()
	accept.text = "Accept"
	accept.next_branch_key = &"accepted"
	accept.quest_action = &"accept_bounty:pin_test"
	var pre_quest: DialogueBranch = BranchScript.new()
	pre_quest.lines = ["Will you accept?"]
	pre_quest.responses = [accept]
	var accepted: DialogueBranch = BranchScript.new()
	accepted.lines = ["Walk well."]
	accepted.responses = []
	var tree: DialogueTreeDef = TreeScript.new()
	tree.npc_id = &"pin_test_npc"
	tree.display_name = "Pin Test NPC"
	tree.branches = {
		&"pre_quest": pre_quest,
		&"accepted": accepted,
	}
	tree.default_branch_key = &"pre_quest"
	return tree
