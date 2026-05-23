class_name QuestStateResolver
extends RefCounted
## QuestStateResolver — pure stateless logic for resolving (npc_id, player
## bounty state) into a DialogueTreeDef branch_key.
##
## **Ticket W2-T6 (`86c9y7ydg`)** — M3 Tier 3 W2 QuestState model + save
## integration.
##
## ## What this class is
##
## A side-effect-free resolver: given an NPC id, the player's current
## `active_bounty` (QuestState or null), and the player's
## `completed_bounties` (Array[StringName]), return the StringName
## branch_key that `DialogueController.open(tree, branch_key)` should
## navigate to.
##
## **Why a separate class** — keeps the branch-resolution matrix observable
## without staging the full Player + Save layer in tests. Per the W2-T6
## ticket Part D: "isolates the branch-key resolution logic from the
## controller" so a paired GUT test can pin the 4-state matrix cheaply.
##
## ## NPC → offered-quest mapping
##
## A small const Dictionary maps a hub/stratum NPC's `npc_id` to the
## `quest_id` they OFFER. W2-T6 only ships the Sister Ennick → Stoker
## bounty pair (the listener stub origin in PR #347). Track 3 W3 quest
## content expands the map as more bounty-givers ship.
##
## **Why a const Dictionary (vs a separate .tres registry)** — the map is
## currently 1 entry. A `.tres` registry adds load-order complexity (need
## to defer until ContentRegistry boots) for negligible authoring win.
## When the map reaches ~5-10 entries OR when Sponsor signals a multi-
## stratum quest expansion, lift to a `.tres` registry under
## `resources/quests/` with the same shape (npc_id → quest_id).
##
## ## Branch resolution matrix
##
## | Player state | Branch returned |
## |---|---|
## | No active bounty AND NPC's quest not in completed_bounties | `&"pre_quest"` |
## | active_bounty.quest_id == NPC's offered quest_id | `&"quest_active"` |
## | NPC's offered quest_id in completed_bounties | `&"quest_completed"` |
## | NPC offers no quest (vendor/lore NPC) | `&"flavor"` |
## | active_bounty for a DIFFERENT NPC's quest | `&"flavor"` (NPC has no business with the active bounty) |
##
## The `quest_failed` state is M4+ (per `.claude/docs/dialogue-system.md`
## § "Branch resolution rule"); W2-T6 does NOT emit it.
##
## ## Composition with DialogueTreeDef.resolve_branch
##
## Caller pattern:
##
##   var key: StringName = QuestStateResolver.resolve_branch_key(
##       npc_id, player.active_bounty, player.completed_bounties)
##   DialogueController.open(tree, key)
##
## DialogueController then walks `tree.branches.has(key)` → falls back to
## `tree.default_branch_key` if the NPC's tree lacks the resolved key (e.g.
## a flavor-only NPC with no `pre_quest` branch). The resolver and the
## controller's fallback are layered — resolver picks the *ideal* key, the
## controller's resolution rule handles missing keys.

## NPC → offered-quest map. **Stable across patches** — once an NPC's
## quest_id is shipped, renaming would orphan player saves (their
## `completed_bounties` reference the old id). Add new entries; never
## rename existing entries without a save-migration step.
##
## **W2-T6 shipped entry:** Sister Ennick (`hub_sister_ennick`) offers
## the Stoker bounty (`s1_recover_stoker_proof`). This matches the
## `accept_bounty:s1_recover_stoker_proof` / `complete_bounty:s1_recover_stoker_proof`
## quest_actions authored in
## `resources/dialogue/hub_town/sister_ennick_storyteller.tres`.
const NPC_OFFERED_QUEST: Dictionary = {
	&"hub_sister_ennick": &"s1_recover_stoker_proof",
}


## Resolve the branch_key DialogueController should open for the given
## NPC + player bounty state.
##
## **Pure / side-effect-free** — no Engine.get_main_loop calls, no Player
## lookups, no autoload access. Tests pass in the (npc_id, active_bounty,
## completed_bounties) tuple directly.
##
## **Type tolerance** — `active_bounty` is typed `Variant` to admit both
## `QuestState` instances (production runtime) and `null` (no active
## bounty). Strict typing as `QuestState` rejects the null case at the
## GDScript parser; Variant + runtime `is QuestState` check is the
## conventional shape for nullable-Resource params in Godot 4.
static func resolve_branch_key(
		npc_id: StringName,
		active_bounty: Variant,
		completed_bounties: Array) -> StringName:
	# Look up the NPC's offered quest. If the NPC doesn't offer a quest,
	# they're a flavor/vendor NPC — always return &"flavor". DialogueController
	# falls back to `default_branch_key` if the tree lacks `&"flavor"`.
	if not NPC_OFFERED_QUEST.has(npc_id):
		return &"flavor"
	var offered_quest_id: StringName = NPC_OFFERED_QUEST[npc_id]
	# Is the NPC's offered quest already completed? Check FIRST (a player
	# who completed and then re-talks should NOT see pre_quest, even if
	# they currently have no active bounty).
	if _completed_contains(completed_bounties, offered_quest_id):
		return &"quest_completed"
	# Is the player currently on this NPC's bounty? `active_bounty` may be
	# null (no active bounty) or a QuestState for ANOTHER NPC's quest.
	var bounty: QuestState = active_bounty if active_bounty is QuestState else null
	if bounty != null and bounty.quest_id == offered_quest_id:
		return &"quest_active"
	# NPC offers a quest, player has not completed it, player is not on
	# it — pre_quest is the offer state.
	#
	# Note: a player carrying ANOTHER NPC's active bounty still sees the
	# offer-prompt here, which is by design (the NPC's tree can choose
	# to gate "I see you walk with a bounty already" via its pre_quest
	# branch text — content decision, not engine decision). Single-active-
	# bounty rejection happens in the router's accept path, not here.
	return &"pre_quest"


## Returns true iff `completed_bounties` contains `quest_id`. Tolerates
## the JSON-load shape where StringName values come back as String — the
## comparison stringifies both sides.
##
## The save layer JSON-serialises `Array[StringName]` as `Array[String]`;
## the load layer hands back `Array[String]` typed as `Array` (untyped).
## This helper makes the comparison robust to either shape.
static func _completed_contains(completed: Array, quest_id: StringName) -> bool:
	var needle: String = String(quest_id)
	for entry in completed:
		if String(entry) == needle:
			return true
	return false
