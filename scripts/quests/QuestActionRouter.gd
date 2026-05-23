extends Node
## QuestActionRouter autoload — listener + persistence wiring for the
## dialogue-system `quest_action_invoked` + `dialogue_closed` signals.
##
## **Ticket W2-T2 (`86c9y0zyv`)** introduced the listener stub: subscribe
## to DialogueController signals, record the most-recent payload, emit
## `quest_action_received` for test verification.
##
## **Ticket W2-T6 (`86c9y7ydg`)** extends the stub with PERSISTENCE wiring:
## the router now mutates `Player.active_bounty` and `Player.completed_bounties`
## in response to `accept_bounty:<npc_id>` and `complete_bounty:<npc_id>`
## verbs, drives the QuestStateResolver-based npc→quest lookup, and emits
## `quest_accepted` / `quest_completed` for downstream consumers (reward
## pipeline, world-map UI quest-target zones, future BountyController).
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
## ## W2-T6 persistence wiring (this PR)
##
##   - **`accept_bounty:<npc_id>`** — look up the NPC's offered quest via
##     `QuestStateResolver.NPC_OFFERED_QUEST`. If the NPC offers no quest
##     OR the player already has an active bounty, REJECT via
##     `WarningBus.warn(..., "quest")` (single-active-bounty lock per
##     W2-T7 §9 v6 trigger guard). Otherwise instantiate a fresh
##     `QuestState`, write to `Player.active_bounty`, emit `quest_accepted`.
##
##   - **`complete_bounty:<npc_id>`** — verify `Player.active_bounty.quest_id`
##     matches the NPC's offered quest_id (defensive — catches a future
##     content regression where Sister Ennick's complete-verb references
##     a different quest than her offer-verb). On match, append to
##     `Player.completed_bounties`, clear `Player.active_bounty`, emit
##     `quest_completed`. On mismatch / no active bounty, REJECT via
##     `WarningBus.warn(..., "quest")`.
##
##   - **`open_vendor:<npc_id>` + `reforge:<slot>` + `abandon_bounty`** stay
##     as no-op — those are W3+ consumer scope.
##
## ## Player lookup is defensive
##
## The router resolves Player via the `&"player"` group at action-handle
## time. If no Player is in the tree (autoload-bare GUT test context, or
## the brief window during Main scene transitions when the Player has been
## freed but a dialogue is somehow still alive — should not happen in
## practice because `Player._die` doesn't trigger dialogue), the
## persistence path is a no-op. The listener-stub state (echo signals,
## `_last_quest_action`) still populates so tests can verify wiring
## without staging a Player.
##
## ## Public API (W2-T2 stub + W2-T6 persistence)
##
##   QuestActionRouter.last_quest_action() -> StringName        # stub
##   QuestActionRouter.last_npc_id() -> StringName              # stub
##   QuestActionRouter.last_branch_key() -> StringName          # stub
##   QuestActionRouter.has_received_quest_action() -> bool      # stub
##   QuestActionRouter.clear() -> void                          # stub
##
## ## Signals
##
##   quest_action_received(action_id, npc_id, branch_key)
##     -> Listener-stub echo (W2-T2): fires on every `quest_action_invoked`
##        emit. Carries the ORIGINATING branch_key.
##
##   dialogue_closed_observed(npc_id)
##     -> Listener-stub echo (W2-T2): fires on every `dialogue_closed` emit.
##
##   quest_accepted(quest_id: StringName)
##     -> W2-T6 NEW: fires when `accept_bounty:<npc_id>` successfully
##        instantiates a QuestState and writes to `Player.active_bounty`.
##        Does NOT fire on rejection (already-active bounty, unknown NPC,
##        no Player in tree).
##
##   quest_completed(quest_id: StringName)
##     -> W2-T6 NEW: fires when `complete_bounty:<npc_id>` successfully
##        appends to `Player.completed_bounties` and clears active_bounty.
##        Does NOT fire on rejection.

# ---- Signals ---------------------------------------------------------

signal quest_action_received(action_id: StringName, npc_id: StringName, branch_key: StringName)
signal dialogue_closed_observed(npc_id: StringName)
signal quest_accepted(quest_id: StringName)
signal quest_completed(quest_id: StringName)

# ---- Verb constants --------------------------------------------------

## Verb prefixes parsed from `<verb>:<target>` quest_action StringNames.
## Split on the FIRST `:` only (per dialogue-system.md authoring convention).
const VERB_ACCEPT_BOUNTY: String = "accept_bounty"
const VERB_COMPLETE_BOUNTY: String = "complete_bounty"
const VERB_OPEN_VENDOR: String = "open_vendor"
const VERB_REFORGE: String = "reforge"
const VERB_ABANDON_BOUNTY: String = "abandon_bounty"

# ---- Last-event state (W2-T2 listener stub) --------------------------

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


# ---- Public API (W2-T2 stub) -----------------------------------------


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
##
## **W2-T6 note**: `clear()` only resets the listener-stub state (echo
## payload). It does NOT clear `Player.active_bounty` / `Player.completed_bounties`
## — those are persistent player state, owned by the Player node and
## restored from save. Tests that need to reset Player bounty state must
## do so on the Player instance directly.
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
## payload + emits the test-friendly echo signal `quest_action_received`,
## then dispatches the verb to the appropriate persistence handler
## (W2-T6 extension).
##
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
	# ---- W2-T6 persistence dispatch ---------------------------------
	# Split on the FIRST `:` only — a future target containing `:` (e.g.
	# `reforge:weapon:tier_2`) still resolves cleanly. The verb is the
	# substring BEFORE the first colon; the target is everything after.
	var raw: String = String(action_id)
	var verb: String = raw
	var _target: String = ""
	var colon: int = raw.find(":")
	if colon >= 0:
		verb = raw.substr(0, colon)
		_target = raw.substr(colon + 1)
	match verb:
		VERB_ACCEPT_BOUNTY:
			_handle_accept_bounty(npc_id)
		VERB_COMPLETE_BOUNTY:
			_handle_complete_bounty(npc_id)
		_:
			# open_vendor / reforge / abandon_bounty + any future verb stays
			# as listener-only no-op for W2-T6. Track 3 W3+ wires the
			# remaining handlers.
			pass


## Fires on every controller `dialogue_closed` emit. DO NOT read
## `DialogueController.current_branch_key()` here — `close()` calls
## `_reset_state` BEFORE emitting `dialogue_closed`, so the controller's
## branch_key is already `&""`. The branch_key for the most recent
## quest_action is preserved in `_last_branch_key` from the earlier
## `branch_opened` capture; this handler is mirror-only (no state read
## from the controller).
func _on_dialogue_closed(npc_id: StringName) -> void:
	dialogue_closed_observed.emit(npc_id)


# ---- W2-T6 persistence handlers -------------------------------------

## Handle `accept_bounty:<npc_id>` — look up the NPC's offered quest via
## QuestStateResolver, instantiate a QuestState, write to Player. Rejects
## with a WarningBus.warn(..., "quest") on:
##   - No Player in tree (defensive — tests / pre-Player-spawn windows).
##   - Player already has an active bounty (single-active-bounty lock).
##   - NPC offers no quest (would mean a content authoring error where a
##     vendor / lore NPC has an `accept_bounty` response).
func _handle_accept_bounty(npc_id: StringName) -> void:
	var player: Node = _player_node()
	if player == null:
		# No Player in tree — autoload-bare GUT test context or pre-spawn
		# window. The listener-stub state still records the event so tests
		# can verify wiring; we don't WarningBus.warn here because that
		# would taint NoWarningGuard on every test that bare-instantiates.
		return
	# NPC → quest_id lookup. The resolver class owns the canonical map.
	if not QuestStateResolver.NPC_OFFERED_QUEST.has(npc_id):
		_warn(("QuestActionRouter.accept_bounty: NPC %s offers no quest" +
				" — dropping accept_bounty action") % str(npc_id))
		return
	# Single-active-bounty lock. Multi-concurrent-bounty is v6 trigger
	# territory per W2-T7 §9.
	var existing: Variant = player.get("active_bounty")
	if existing is QuestState:
		_warn(("QuestActionRouter.accept_bounty: rejected — player already" +
				" has an active bounty (quest_id=%s); single-active-bounty lock") %
				str((existing as QuestState).quest_id))
		return
	# Instantiate a fresh QuestState.
	var quest_id: StringName = QuestStateResolver.NPC_OFFERED_QUEST[npc_id]
	var qs: QuestState = QuestState.new()
	qs.quest_id = quest_id
	qs.accepted_at_tick = Time.get_ticks_msec()
	qs.completion_progress = {}
	qs.state = &"quest_active"
	player.set("active_bounty", qs)
	quest_accepted.emit(quest_id)


## Handle `complete_bounty:<npc_id>` — verify the active bounty matches
## the NPC's offered quest, move quest_id onto completed_bounties, clear
## active_bounty, emit quest_completed. Rejects with WarningBus.warn(...,
## "quest") on:
##   - No Player in tree (defensive).
##   - No active bounty (defensive — caught by content authoring should
##     prevent this, but we surface for diagnostic).
##   - active_bounty.quest_id mismatches the NPC's offered quest_id
##     (defensive — surfaces a content-vs-engine drift class).
func _handle_complete_bounty(npc_id: StringName) -> void:
	var player: Node = _player_node()
	if player == null:
		return
	if not QuestStateResolver.NPC_OFFERED_QUEST.has(npc_id):
		_warn(("QuestActionRouter.complete_bounty: NPC %s offers no quest" +
				" — dropping complete_bounty action") % str(npc_id))
		return
	var existing: Variant = player.get("active_bounty")
	if not (existing is QuestState):
		_warn(("QuestActionRouter.complete_bounty: rejected — player has" +
				" no active bounty (npc=%s)") % str(npc_id))
		return
	var active: QuestState = existing
	var expected_quest_id: StringName = QuestStateResolver.NPC_OFFERED_QUEST[npc_id]
	if active.quest_id != expected_quest_id:
		_warn(("QuestActionRouter.complete_bounty: rejected — active bounty" +
				" quest_id=%s does NOT match NPC %s's offered quest_id=%s") %
				[str(active.quest_id), str(npc_id), str(expected_quest_id)])
		return
	# Append to completed_bounties + clear active_bounty.
	var completed: Variant = player.get("completed_bounties")
	var completed_arr: Array = completed if completed is Array else []
	completed_arr.append(active.quest_id)
	player.set("completed_bounties", completed_arr)
	player.set("active_bounty", null)
	quest_completed.emit(active.quest_id)


# ---- Helpers ---------------------------------------------------------


func _controller_node() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null("DialogueController")


## Resolve Player via the `&"player"` group (per Player._ready() — the
## node adds itself to the group at boot). Returns null if no Player is in
## the tree — defensive for autoload-bare GUT contexts.
func _player_node() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	# get_nodes_in_group returns Array[Node] — Godot 4. Empty array if
	# the group has no members.
	var players: Array = loop.get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0] as Node


## Route warnings through WarningBus so NoWarningGuard catches quest-action
## regressions in headless GUT per `.claude/docs/test-conventions.md`
## § Universal warning gate. Falls back to push_warning when the bus is
## not registered (autoload-stripped test context).
func _warn(text: String) -> void:
	var bus: Node = _warning_bus()
	if bus != null and bus.has_method("warn"):
		bus.warn(text, "quest")
	else:
		push_warning(text)


func _warning_bus() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null("WarningBus")
