class_name QuestState
extends Resource
## QuestState — runtime instance of a quest accepted by the player.
##
## **Ticket W2-T6 (`86c9y7ydg`)** — M3 Tier 3 W2 QuestState model + save
## integration. The persisted-instance counterpart to QuestDef (the
## authoring-side template).
##
## ## Lifecycle
##
##   1. Player picks a `accept_bounty:<npc_id>` response in dialogue.
##   2. `DialogueController.quest_action_invoked` fires.
##   3. `QuestActionRouter._on_quest_action_invoked` resolves the NPC's
##      offered quest_id via QuestStateResolver, loads the QuestDef,
##      instantiates a fresh QuestState (this class), writes it to
##      `Player.active_bounty`.
##   4. Bounty progresses — Track 3 W3 reward-pipeline writes to
##      `completion_progress` (e.g. `{"kills_remaining": 3}`).
##   5. Player picks `complete_bounty:<npc_id>` response.
##   6. Router verifies state matches expected quest, moves quest_id onto
##      `Player.completed_bounties`, clears `Player.active_bounty`.
##
## ## Save round-trip
##
## Serialised via `to_dict()` into `data.character.active_bounty` (or
## `null` when no bounty active). Restored via `from_dict()` on save load.
## **Additive schema** — uses the v5 `has()`-guard backfill in Save.gd's
## `_migrate_v4_to_v5` (extended in W2-T6 to seed `active_bounty=null` +
## `completed_bounties=[]` for legacy v4 characters).
##
## ## Why a Resource (vs a plain Dictionary)
##
## Typing the runtime state lets the inspector author test fixtures, lets
## `@export var` fields catch typos at parse time, and lets GUT tests
## smoke-load `.tres` fixtures without staging a full save layer. The
## persistence layer (`to_dict`/`from_dict`) keeps the on-disk format
## compatible with JSON (no custom Resource serialisation in save files).
##
## ## Single-active-bounty structural lock (W2-T7 §9 v6 trigger guard)
##
## Per W2-T7 v6 trigger guard addendum, Player owns at most ONE active
## QuestState. Multi-concurrent-bounty is deferred to v6. Router REJECTS
## `accept_bounty` when `Player.active_bounty != null` and emits a
## `WarningBus.warn(..., "quest")` — the rejection is structural, not a
## bug.

## Quest identifier — matches `QuestDef.quest_id`. Used by the router to
## verify a `complete_bounty:<npc_id>` matches the current active bounty.
@export var quest_id: StringName = &""

## Tick value at which the bounty was accepted. Stored for future "time
## to complete" telemetry surfaces (W4+). The router writes
## `Time.get_ticks_msec()` at accept time. NOT consumed by the W2-T6
## acceptance criteria; persisted for forward-compat.
@export var accepted_at_tick: int = 0

## Per-objective progress counters. Shape varies per quest archetype:
##   - "kill N of mob X"   → `{"kills_remaining": int}`
##   - "find item Y"        → `{"found": bool}`
##   - "explore zone Z"     → `{"visited": bool}`
## **Permissive at this layer** — the schema lives in the quest archetype
## consumer. Router does NOT validate the shape on accept; it only checks
## that `completion_progress` meets the QuestDef's criteria on
## `complete_bounty` (validation deferred to W3+ reward-pipeline).
@export var completion_progress: Dictionary = {}

## State label mirroring the DialogueTreeDef branch-key convention:
##   - &"pre_quest"        (the quest is offered but not yet accepted — not
##                          a valid QuestState state because we don't
##                          instantiate QuestState until accept)
##   - &"quest_active"     (bounty in progress)
##   - &"quest_completed"  (bounty turned in — at this point the QuestState
##                          has already moved off `active_bounty` into the
##                          `completed_bounties[]` array, so this label is
##                          only briefly observed during the turn-in path)
##   - &"quest_failed"     (M4+ surface; reserved)
## See `.claude/docs/dialogue-system.md` § "Branch resolution rule".
@export var state: StringName = &"quest_active"


# ---- Serialisation ----------------------------------------------------

## Serialise to a JSON-safe Dictionary for `data.character.active_bounty`.
## Returns a flat-keyed Dict — StringName fields stringified (Godot's JSON
## serialises StringName as String, matching the convention in v4's
## ember_bags + the dialogue-spike's per-NPC keys).
##
## **Symmetric with `from_dict`**: `from_dict(to_dict()) == this`.
func to_dict() -> Dictionary:
	return {
		"quest_id": String(quest_id),
		"accepted_at_tick": accepted_at_tick,
		"completion_progress": completion_progress.duplicate(true),
		"state": String(state),
	}


## Deserialise from a `data.character.active_bounty` Dictionary. Tolerates
## missing sub-keys (defaults to QuestState's @export defaults). Returns a
## fresh QuestState — caller decides whether to write to Player.
##
## Returns `null` only if `payload` itself is null OR missing the `quest_id`
## key (the load-bearing identifier). A malformed payload with `quest_id`
## present but other fields missing returns a best-effort QuestState — the
## load layer is "never lose data, surface gaps as defaults" per the v4
## migration convention.
static func from_dict(payload: Variant) -> QuestState:
	if payload == null:
		return null
	if not (payload is Dictionary):
		return null
	var d: Dictionary = payload
	if not d.has("quest_id"):
		return null
	var qid: StringName = StringName(String(d.get("quest_id", "")))
	if qid == &"":
		return null
	var qs: QuestState = QuestState.new()
	qs.quest_id = qid
	qs.accepted_at_tick = int(d.get("accepted_at_tick", 0))
	var prog: Variant = d.get("completion_progress", {})
	if prog is Dictionary:
		qs.completion_progress = (prog as Dictionary).duplicate(true)
	else:
		qs.completion_progress = {}
	qs.state = StringName(String(d.get("state", "quest_active")))
	return qs
