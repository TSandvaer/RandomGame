extends Node
## DialogueController autoload — owns the active dialogue session.
##
## **Spike scope — ticket `86c9xuab3` (M3 Tier 3 W1 dialogue system spike).**
## See `.claude/docs/dialogue-system.md` for the full architecture.
##
## ## Responsibilities
##
## 1. **Session state** — at most ONE dialogue may be active at a time. `open()`
##    on top of an open session is rejected (push_warning); caller must
##    `close()` first. This guard is deliberate — the spike does NOT model a
##    queue of pending dialogues; that complexity belongs in a later milestone
##    if the design ever needs it.
##
## 2. **Branch resolution** — given a `DialogueTreeDef` + a `quest_state`
##    StringName, walks the tree's branches map (with `default_branch_key`
##    fallback) and emits `branch_opened(npc_id, branch_key)`. If the tree has
##    no resolvable branch, opens NOTHING and emits a WarningBus warning — the
##    panel never appears, so the player is never trapped in a soft-locked UI
##    state.
##
## 3. **Line advance + response selection** — `advance_line()` walks `lines[]`
##    sequentially; when past the last line, either presents responses (via
##    `responses_presented`) or closes (if `responses.is_empty()`).
##    `select_response(idx)` routes to the next branch or closes if
##    `next_branch_key == &""`. Out-of-range indices are rejected (warning).
##
## 4. **Quest-action side-effect channel** — emitting `quest_action_invoked`
##    when a response with a non-empty `quest_action` is picked. The spike does
##    NOT execute the action; W2 wires bounty-state mutations to this signal.
##
## 5. **Input gating** — exposes `is_active()` for `Player.gd` to gate attack
##    input while a dialogue is open. This is the pre-emptive convention seed
##    flagged in ticket `86c9xwxhu` (InventoryPanel input-leak) — DialoguePanel
##    establishes the pattern that Sponsor's larger design call will then apply
##    to inventory.
##
## ## What the spike does NOT do
##
##   - **No TimeScaleDirector integration.** Per ticket out-of-scope —
##     dialogue does NOT slow-mo the world. Sponsor's SI-2 left the time-scale
##     call open; the spike defers to a follow-up so we don't accidentally
##     pin a tonal decision that should be a Uma call. If a future ticket
##     wants slow-mo, register a `TimeScaleDirector` request in `open()` and
##     release it in `close()` — `TimeScaleDirector.freeze()` is the wrong
##     primitive (UI-blocked freeze ≠ cinematic freeze).
##
##   - **No save persistence.** The active-dialogue session is transient — if
##     the player F5-saves mid-dialogue, the session resets on load. Bounty
##     state (the persisted side of dialogue) flows through Save via the
##     bounty system, not via DialogueController. Spike-scope acceptable
##     because no playable content depends on mid-dialogue save resume.
##
##   - **No portrait/audio routing.** Portrait is a placeholder ColorRect in
##     the panel; no audio cue fires on line-advance or response-select. Uma
##     owns the cue authoring; the spike's `branch_opened` /
##     `line_displayed` / `response_selected` / `quest_action_invoked`
##     signals are the hook surface those cues subscribe to in W2.
##
## ## Why an autoload
##
## Every NPC interact point + the panel both need to reach the active session
## without coupling to a specific scene. Following the AudioDirector /
## TimeScaleDirector precedent — single global owner of a shared runtime
## resource, autoload-registered in `project.godot`.
##
## ## Public API
##
##   open(tree: DialogueTreeDef, quest_state: StringName = &"flavor") -> bool
##   advance_line() -> void
##   select_response(idx: int) -> void
##   close() -> void
##   is_active() -> bool
##   current_branch_key() -> StringName
##   current_line_index() -> int
##   current_line_text() -> String
##   current_responses() -> Array[DialogueResponse]
##   current_npc_id() -> StringName
##   current_display_name() -> String
##
## ## Signals (in firing order over a typical session)
##
##   branch_opened(npc_id, branch_key)
##     -> fires once per `open()` AND once per `select_response()` that
##        navigates to a new branch.
##
##   line_displayed(line_index, line_text)
##     -> fires once per `open()` (line 0 of the resolved branch) AND once
##        per `advance_line()` that lands on a new line.
##
##   responses_presented(responses)
##     -> fires when `advance_line()` passes the last line AND
##        `responses.size() > 0`. Panel listens to render the response
##        buttons.
##
##   response_selected(idx, response)
##     -> fires per `select_response(idx)` invocation, BEFORE the controller
##        navigates to `next_branch_key` / closes. Useful for the panel to
##        dismiss the response buttons before the next branch renders.
##
##   quest_action_invoked(action_id, npc_id)
##     -> fires per `select_response` whose `response.quest_action != &""`.
##        Spike emits only; W2's bounty system subscribes here.
##
##   dialogue_closed(npc_id)
##     -> fires per `close()` that transitions from active → idle. Idempotent
##        close is a no-op + no emit (so panel doesn't double-render).

# ---- Signals ---------------------------------------------------------

signal branch_opened(npc_id: StringName, branch_key: StringName)
signal line_displayed(line_index: int, line_text: String)
signal responses_presented(responses: Array)
signal response_selected(idx: int, response: DialogueResponse)
signal quest_action_invoked(action_id: StringName, npc_id: StringName)
signal dialogue_closed(npc_id: StringName)

# ---- Active session state -------------------------------------------

var _active: bool = false
var _tree: DialogueTreeDef = null
var _branch: DialogueBranch = null
var _branch_key: StringName = &""
var _line_index: int = -1

# ---- Public API -----------------------------------------------------


## Open a new dialogue session with the given tree. Returns true on success,
## false if rejected (already-active OR unresolvable branch). The spike does
## NOT queue dialogues — if a session is already active, callers must `close()`
## first or accept the rejection.
##
## `quest_state` defaults to `&"flavor"` so vendor / no-quest NPCs can omit
## the parameter. Branch resolution falls back to `tree.default_branch_key`
## (typically `&"flavor"`) when `quest_state` is not in `tree.branches`.
func open(tree: DialogueTreeDef, quest_state: StringName = &"flavor") -> bool:
	if _active:
		_warn(
			(
				"DialogueController.open: rejected — session already active for npc=%s"
				% str(_npc_id_or_unknown())
			)
		)
		return false
	if tree == null:
		_warn("DialogueController.open: rejected — null tree")
		return false
	var branch: DialogueBranch = tree.resolve_branch(quest_state)
	if branch == null:
		_warn(
			(
				(
					"DialogueController.open: rejected — npc=%s has no branch for"
					+ " quest_state=%s and no default"
				)
				% [str(tree.npc_id), str(quest_state)]
			)
		)
		return false
	# Latch session state.
	_active = true
	_tree = tree
	_branch = branch
	# Resolve which branch_key was selected (quest_state if present, else
	# default_branch_key). Used for tracing + the branch_opened signal.
	_branch_key = quest_state if tree.branches.has(quest_state) else tree.default_branch_key
	_line_index = 0
	_combat_trace(
		"DialogueController.open",
		(
			"npc=%s state=%s branch=%s lines=%d"
			% [
				str(tree.npc_id),
				str(quest_state),
				str(_branch_key),
				_branch.lines.size(),
			]
		)
	)
	branch_opened.emit(tree.npc_id, _branch_key)
	# Auto-display line 0 if any lines exist. A branch with empty lines +
	# non-empty responses is a pure choice prompt — present responses
	# immediately.
	if _branch.lines.size() > 0:
		line_displayed.emit(_line_index, _branch.lines[_line_index])
	else:
		_present_responses_or_close()
	return true


## Advance to the next line in the active branch. If past the last line,
## either presents responses (if any) or closes the dialogue (if none).
## No-op when no session is active (warning).
func advance_line() -> void:
	if not _active:
		_warn("DialogueController.advance_line: no active session")
		return
	if _branch == null:
		_warn("DialogueController.advance_line: active session has null branch")
		return
	_line_index += 1
	if _line_index < _branch.lines.size():
		line_displayed.emit(_line_index, _branch.lines[_line_index])
		return
	_present_responses_or_close()


## Select a response by zero-based index. Out-of-range indices are rejected
## with a WarningBus warning (no panic). Picking a response with
## `quest_action != &""` emits `quest_action_invoked` BEFORE navigation.
## Picking a response with `next_branch_key == &""` closes the dialogue.
## No-op when no session is active OR when responses aren't currently
## presented (warning).
func select_response(idx: int) -> void:
	if not _active:
		_warn("DialogueController.select_response: no active session")
		return
	if _branch == null or _branch.responses.is_empty():
		_warn("DialogueController.select_response: no responses presented (idx=%d)" % idx)
		return
	if idx < 0 or idx >= _branch.responses.size():
		_warn(
			(
				"DialogueController.select_response: idx %d out of range [0,%d)"
				% [idx, _branch.responses.size()]
			)
		)
		return
	var response: DialogueResponse = _branch.responses[idx] as DialogueResponse
	if response == null:
		_warn("DialogueController.select_response: response at idx %d is null" % idx)
		return
	response_selected.emit(idx, response)
	# Side-effect channel — emit BEFORE navigation so W2 listeners run with
	# the originating branch context intact, not the destination branch.
	if response.quest_action != &"":
		_combat_trace(
			"DialogueController.quest_action",
			"action=%s npc=%s" % [str(response.quest_action), str(_tree.npc_id)]
		)
		quest_action_invoked.emit(response.quest_action, _tree.npc_id)
	# Navigation.
	if response.next_branch_key == &"":
		close()
		return
	_navigate_to_branch(response.next_branch_key)


## Close the active dialogue session. Idempotent — no-op + no signal emit when
## already closed (panel doesn't double-render).
func close() -> void:
	if not _active:
		return
	var npc_id: StringName = _tree.npc_id if _tree != null else &""
	_combat_trace("DialogueController.close", "npc=%s" % str(npc_id))
	_reset_state()
	dialogue_closed.emit(npc_id)


## Returns true while a dialogue session is open. `Player.gd` reads this to
## gate attack input — pre-emptive convention seed per ticket `86c9xwxhu`
## (InventoryPanel input-leak) Sponsor design call.
func is_active() -> bool:
	return _active


## Active branch key (e.g. `&"pre_quest"`, `&"flavor"`). `&""` when idle.
func current_branch_key() -> StringName:
	return _branch_key


## Zero-based index of the line currently displayed. `-1` when idle.
func current_line_index() -> int:
	return _line_index


## Text of the line currently displayed. `""` when idle OR when the branch has
## advanced past `lines.size()` (response-prompt phase).
func current_line_text() -> String:
	if not _active or _branch == null:
		return ""
	if _line_index < 0 or _line_index >= _branch.lines.size():
		return ""
	return _branch.lines[_line_index]


## Returns the response list currently presented, or an empty array when no
## responses are presented (mid-line or idle). The returned array is a
## reference into the active branch — panels must NOT mutate it.
func current_responses() -> Array:
	if not _active or _branch == null:
		return []
	# Responses are "presented" only when we've passed the last line.
	if _line_index < _branch.lines.size():
		return []
	return _branch.responses


## NPC id of the active session, `&""` when idle.
func current_npc_id() -> StringName:
	if not _active or _tree == null:
		return &""
	return _tree.npc_id


## Display name of the active session's NPC, `""` when idle.
func current_display_name() -> String:
	if not _active or _tree == null:
		return ""
	return _tree.display_name


# ---- Internals ------------------------------------------------------


func _present_responses_or_close() -> void:
	if _branch == null:
		close()
		return
	if _branch.responses.is_empty():
		close()
		return
	responses_presented.emit(_branch.responses)


func _navigate_to_branch(branch_key: StringName) -> void:
	if _tree == null:
		_warn("DialogueController._navigate_to_branch: null tree")
		close()
		return
	if not _tree.branches.has(branch_key):
		_warn(
			(
				(
					"DialogueController._navigate_to_branch: unknown branch_key=%s on"
					+ " npc=%s — closing dialogue"
				)
				% [str(branch_key), str(_tree.npc_id)]
			)
		)
		close()
		return
	var next_branch: DialogueBranch = _tree.branches[branch_key] as DialogueBranch
	if next_branch == null:
		_warn(
			(
				(
					"DialogueController._navigate_to_branch: branch_key=%s resolved to"
					+ " null on npc=%s — closing"
				)
				% [str(branch_key), str(_tree.npc_id)]
			)
		)
		close()
		return
	_branch = next_branch
	_branch_key = branch_key
	_line_index = 0
	_combat_trace(
		"DialogueController.navigate",
		"npc=%s branch=%s lines=%d" % [str(_tree.npc_id), str(_branch_key), _branch.lines.size()]
	)
	branch_opened.emit(_tree.npc_id, _branch_key)
	if _branch.lines.size() > 0:
		line_displayed.emit(_line_index, _branch.lines[_line_index])
	else:
		_present_responses_or_close()


func _reset_state() -> void:
	_active = false
	_tree = null
	_branch = null
	_branch_key = &""
	_line_index = -1


func _npc_id_or_unknown() -> StringName:
	if _tree == null:
		return &"<unknown>"
	return _tree.npc_id


## Route warnings through `WarningBus` so `NoWarningGuard` catches dialogue-
## resolution regressions in headless GUT per `.claude/docs/test-conventions.md`
## § Universal warning gate.
func _warn(text: String) -> void:
	var bus: Node = _warning_bus()
	if bus != null and bus.has_method("warn"):
		bus.warn(text, "dialogue")
	else:
		# Bus not registered (autoload-stripped test context) — fall through to
		# raw push_warning so the message still surfaces.
		push_warning(text)


func _warning_bus() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null("WarningBus")


## Combat-trace shim — HTML5-only per `DebugFlags.combat_trace_enabled()`.
## Quiet on desktop / headless GUT so test logs don't fill with chatter.
func _combat_trace(tag: String, msg: String = "") -> void:
	var df: Node = _debug_flags()
	if df != null and df.has_method("combat_trace"):
		df.combat_trace(tag, msg)


func _debug_flags() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null("DebugFlags")
