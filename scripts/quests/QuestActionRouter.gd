extends Node
## QuestActionRouter autoload — listener stub for the dialogue-system
## `quest_action_invoked` + `dialogue_closed` signals.
##
## **Ticket W2-T2 (`86c9y0zyv`)** — production wiring layer for the W1 dialogue
## spike (`86c9xuab3`). This autoload is the spike-scope listener stub Track 3
## W2 (BountyController) will subsume; for W2-T2 it ONLY records the most
## recent `quest_action_invoked` payload + emits a `quest_action_received` echo
## signal so paired GUT tests can pin the wiring without staging a full
## BountyController graph.
##
## ## Part D — Drew nit fold (PR #320 review)
##
## Drew's PR #320 review flagged two engine surfaces that the survey doc
## (`team/devon-dev/save-schema-v5-tier3-additions.md`) had paper-shaped
## incorrectly:
##
##   - **Nit 1** — `DialogueController.dialogue_closed` is single-arg
##     `(npc_id: StringName)`, NOT two-arg `(npc_id, branch_key)`. Survey
##     §2.4 said two-arg; the engine ships single-arg. This file's listener
##     handlers reflect the engine truth.
##
##   - **Nit 2** — `DialogueController.close()` is no-args `close() -> void`,
##     NOT `close(npc_id, branch_key)`. The controller reads
##     `_tree.npc_id` internally to populate the `dialogue_closed` payload.
##
## **Read-order discipline (load-bearing).** Because `dialogue_closed` is
## single-arg, any listener that needs the branch_key for write-side bounty
## state mutation MUST capture it BEFORE `close()` clears state. The
## controller's `close()` calls `_reset_state()` (clearing `_branch_key` to
## `&""`) BEFORE emitting `dialogue_closed`. So this listener captures the
## branch_key from `branch_opened` + `quest_action_invoked` during the
## active session and stores it locally; it does NOT call
## `DialogueController.current_branch_key()` inside `_on_dialogue_closed`
## (that would return `&""` every time — silent regression class).
##
## The discipline is pinned by:
##   - `tests/test_quest_action_listener_reads_branch_key_before_close.gd`
##     (behaviour pin: stored branch_key matches the originating branch, not `&""`)
##   - Source-scan pin in the same test asserting this file does NOT contain
##     `current_branch_key()` inside `_on_dialogue_closed` (positional invariant
##     per `.claude/docs/test-conventions.md` § Source-scan structural pins).
##
## ## What this autoload does NOT do (deferred to W2-T6 / Track 3 W2)
##
##   - **No actual bounty-state mutation.** This is a listener STUB — it
##     records the most recent `quest_action_invoked` payload and echoes it
##     via `quest_action_received` for test verification. Full
##     `BountyController.handle_quest_action(action_id, npc_id)` (which
##     mutates `Player.active_bounty` / `Player.completed_bounties` /
##     `Player.quest_progress`) lands in Track 3 W2 quest-content.
##
##   - **No save persistence.** The recorded last-event is transient — wiped
##     by `clear()` or session restart. Bounty state writes through Save via
##     Track 3 W2, not via this router.
##
##   - **No verb registry.** The `quest_action` StringName is recorded
##     verbatim (e.g. `&"accept_bounty:s1_warden_scholar"`); Track 3 W2 owns
##     the action-id verb-parsing + target-resolution layer.
##
## ## Public API
##
##   QuestActionRouter.last_quest_action() -> StringName
##   QuestActionRouter.last_npc_id() -> StringName
##   QuestActionRouter.last_branch_key() -> StringName
##   QuestActionRouter.has_received_quest_action() -> bool
##   QuestActionRouter.clear() -> void
##
## ## Signals
##
##   quest_action_received(action_id: StringName, npc_id: StringName,
##                          branch_key: StringName)
##     -> fires on every `DialogueController.quest_action_invoked` emit. The
##        echo signal carries the branch_key the action was selected FROM
##        (the originating branch context per Drew nit read-order), NOT the
##        destination branch.
##
##   dialogue_closed_observed(npc_id: StringName)
##     -> fires on every `DialogueController.dialogue_closed` emit. Mirrors
##        the upstream signal — exists so tests can assert subscription
##        wiring without lifting a separate dependency on the controller.

# ---- Signals ---------------------------------------------------------

signal quest_action_received(action_id: StringName, npc_id: StringName, branch_key: StringName)
signal dialogue_closed_observed(npc_id: StringName)

# ---- Last-event state ------------------------------------------------

## Most-recently-opened branch key — updated on every `branch_opened` emit.
## Transient — not the public-API value. Snapshotted into `_action_branch_key`
## at quest_action_invoked time so the public API reflects the ORIGINATING
## branch of the action, not the destination branch (controller emits
## quest_action BEFORE navigation, so this value is correct at snapshot time).
var _current_branch_key: StringName = &""

## Originating branch key of the most-recent quest_action_invoked. Public API
## `last_branch_key()` returns this. Captured from `_current_branch_key` at
## quest_action emit time so a subsequent navigation's `branch_opened` does
## NOT overwrite the recorded action context (per Drew nit read-order
## discipline — `_action_branch_key` survives the controller's post-emit
## navigation AND survives `close()`'s `_reset_state` because the value is
## stored in this autoload, NOT read from the controller post-close).
var _action_branch_key: StringName = &""

var _last_quest_action: StringName = &""
var _last_npc_id: StringName = &""
var _has_received: bool = false

# ---- Lifecycle -------------------------------------------------------


func _ready() -> void:
	# Subscribe to DialogueController at autoload-ready time. The controller
	# is also an autoload — it's already in the tree by the time any
	# autoload's `_ready` fires, so the lookup is safe. Defensive guard for
	# bare-instanced test contexts where the controller may not exist.
	var dc: Node = _controller_node()
	if dc == null:
		# Controller missing — test/bare-instance context. Stay quiet (no
		# WarningBus.warn) because autoload-stripped GUT runs are a valid
		# context and we don't want to taint NoWarningGuard.
		return
	if dc.has_signal("quest_action_invoked"):
		dc.connect("quest_action_invoked", _on_quest_action_invoked)
	if dc.has_signal("branch_opened"):
		# Capture the branch_key at branch-open time so it's available for
		# the quest_action_invoked emit (per Drew nit read-order discipline).
		dc.connect("branch_opened", _on_branch_opened)
	if dc.has_signal("dialogue_closed"):
		dc.connect("dialogue_closed", _on_dialogue_closed)


# ---- Public API ------------------------------------------------------


## Most-recent quest_action StringName, or `&""` if none received this session.
func last_quest_action() -> StringName:
	return _last_quest_action


## Most-recent npc_id associated with the last quest_action_invoked emit.
func last_npc_id() -> StringName:
	return _last_npc_id


## Most-recent branch_key the quest_action was selected FROM. This is the
## originating branch context (per the dialogue-spike's quest_action_invoked
## firing-order — emits BEFORE controller navigates). Snapshotted at
## quest_action_invoked time from `_current_branch_key` (which tracks the
## controller via `branch_opened`); preserved even when the controller
## subsequently navigates to the destination branch AND when `close()`
## clears the controller's internal `_branch_key` to `&""`. This is the
## Drew-nit-1+2 read-order discipline pinned in
## `tests/test_quest_action_listener_reads_branch_key_before_close.gd`.
func last_branch_key() -> StringName:
	return _action_branch_key


## True iff at least one `quest_action_invoked` has been observed since the
## last `clear()`. Useful for tests / future BountyController consumer to
## distinguish "no quest_action yet" from "last quest_action was &"" (which
## would never happen — controller only emits quest_action_invoked when the
## response's quest_action is non-empty)."
func has_received_quest_action() -> bool:
	return _has_received


## Reset the last-event state. Tests call this in `before_each` to avoid
## state bleed between tests. Production code does NOT need to call this —
## the router is durable for the session lifetime.
func clear() -> void:
	_last_quest_action = &""
	_last_npc_id = &""
	_action_branch_key = &""
	_current_branch_key = &""
	_has_received = false


# ---- DialogueController signal handlers -----------------------------


## **Read-order pin** — `branch_opened` fires when the controller opens a
## new branch (open() AND select_response → navigate). Capture the
## branch_key HERE during the active session — DO NOT read it from inside
## `_on_dialogue_closed` (the controller clears `_branch_key` in
## `_reset_state` BEFORE emitting `dialogue_closed`).
func _on_branch_opened(_npc_id: StringName, branch_key: StringName) -> void:
	# Track the controller's current branch so we can snapshot it into
	# `_action_branch_key` when a quest_action fires. This handler runs on
	# EVERY branch_opened (open() AND navigation), so this field is the
	# transient "what branch is the controller on right now" mirror, NOT
	# the public-API value. Public `last_branch_key()` returns
	# `_action_branch_key`, which is only updated at quest_action time.
	#
	# Per-Drew-nit read-order discipline: the originating-branch capture
	# must happen BEFORE navigation (`quest_action_invoked` emits BEFORE
	# the controller navigates per `.claude/docs/dialogue-system.md`
	# § "Signal surface"). The snapshot lives in `_on_quest_action_invoked`
	# below — when that fires, `_current_branch_key` is still the
	# originating branch because navigation hasn't started yet.
	_current_branch_key = branch_key


## Fires on every controller `quest_action_invoked` emit. Records the
## payload + emits the test-friendly echo signal `quest_action_received`.
## Order-of-operations: `quest_action_invoked` fires BEFORE controller
## navigation (per dialogue-system.md § "Signal surface"), so
## `_current_branch_key` is still the originating branch at snapshot
## time — exactly what downstream consumers want.
func _on_quest_action_invoked(action_id: StringName, npc_id: StringName) -> void:
	_last_quest_action = action_id
	_last_npc_id = npc_id
	# Snapshot the originating branch at action-emit time. `_current_branch_key`
	# is still the branch the action was selected FROM because the controller
	# emits `quest_action_invoked` BEFORE navigation per dialogue-system.md
	# § "Signal surface". Saving it into a separate `_action_branch_key`
	# slot preserves it across the subsequent `branch_opened` (navigation
	# destination) AND across `close()` (`_reset_state` doesn't touch this
	# autoload's state — only the controller's internal state).
	_action_branch_key = _current_branch_key
	_has_received = true
	quest_action_received.emit(action_id, npc_id, _action_branch_key)


## Fires on every controller `dialogue_closed` emit. DO NOT read
## `DialogueController.current_branch_key()` here — `close()` calls
## `_reset_state` BEFORE emitting `dialogue_closed`, so the controller's
## branch_key is already `&""`. The branch_key for the most recent
## quest_action is preserved in `_last_branch_key` from the earlier
## `branch_opened` capture; this handler is mirror-only (no state read
## from the controller).
func _on_dialogue_closed(npc_id: StringName) -> void:
	dialogue_closed_observed.emit(npc_id)


# ---- Helpers ---------------------------------------------------------


func _controller_node() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null("DialogueController")
