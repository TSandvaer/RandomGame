class_name QuestDef
extends Resource
## QuestDef — authoring-side definition of a single quest offered by an NPC.
##
## **Ticket W2-T6 (`86c9y7ydg`)** — M3 Tier 3 W2 QuestState model + save
## integration. Builds on PR #347 (W2-T2 listener stub) by adding the
## persistence model behind the `quest_action_invoked` signal channel.
##
## ## Authoring contract
##
## One QuestDef per offered quest. Authored as a `.tres` resource under
## `resources/quests/` (e.g. `resources/quests/s1_recover_stoker_proof.tres`).
## The QuestStateResolver's NPC→quest map (in QuestStateResolver.gd) maps a
## dialogue NPC's `npc_id` to a `quest_id` it offers; the runtime then
## resolves `quest_id` → QuestDef via `ContentRegistry`-style direct-load.
##
## ## Spike vs production scope
##
## **In scope (W2-T6):**
##   - `quest_id` + `display_name` + `accept_branch_quote` + `complete_branch_quote`
##   - `reward_payload` Dictionary (additive shape — keys interpreted by
##     Track 3 W3 reward-pipeline ticket).
##
## **Deferred (W3+ consumer scope):**
##   - Objective schema enforcement (kill-N, find-item-Y, escort-Z) — for
##     W2-T6 the `completion_progress` Dictionary on QuestState is permissive;
##     the QuestActionRouter only verifies `active_bounty.quest_id` matches
##     the incoming `complete_bounty:<npc_id>` resolution. Objective
##     enforcement lands when the per-archetype subclassing is needed.
##   - Reward dispatch — QuestDef ships the payload Dictionary; the actual
##     XP/gold/item grant happens in a Track 3 W3 reward-pipeline ticket
##     that subscribes to `QuestActionRouter.quest_completed`.

## Stable StringName id — e.g. `&"s1_recover_stoker_proof"`. Used as the
## `Player.active_bounty.quest_id` field, the `Player.completed_bounties[]`
## element value, and the lookup key for the QuestStateResolver's npc→quest
## map. **Must be stable across patches** (renaming a shipped quest_id
## orphans saves per `m3-design-seeds.md §3.9`).
@export var quest_id: StringName = &""

## Player-facing display name — e.g. "Recover the Stoker's Proof". Used by
## future quest-log / map-UI surfaces; NOT consumed by the W2-T6 router or
## resolver (the lookup keys are StringName, not display strings).
@export var display_name: String = ""

## NPC accept-branch quote — quoted for downstream content tooling /
## quest-log UI. Authoring convenience only; the W2-T6 router does NOT
## render these — the actual dialogue line lives in the `DialogueBranch.lines[]`
## of the NPC's `accepted_briefing` branch. Stored here so a single
## `.tres` per quest is the canonical source-of-truth for quest content.
@export var accept_branch_quote: String = ""

## NPC complete-branch quote — same shape as `accept_branch_quote`. The
## actual rendered dialogue line lives in `DialogueBranch.lines[]` of the
## NPC's `completed_thanks` branch.
@export var complete_branch_quote: String = ""

## Reward payload — additive Dictionary the Track 3 W3 reward-pipeline ticket
## interprets. Example shape: `{ "xp": 250, "gold": 50, "items": [...] }`.
## **Permissive at this layer**: QuestDef does NOT validate the keys; the
## consumer system owns its schema. Keep the Dictionary flat
## (1-level deep, primitive values) to stay friendly to save round-trips
## if a future ticket persists partial-reward state.
@export var reward_payload: Dictionary = {}
