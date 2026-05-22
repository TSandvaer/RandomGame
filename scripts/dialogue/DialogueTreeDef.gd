class_name DialogueTreeDef
extends Resource
## NPC dialogue tree definition — the top-level Resource that authors edit.
##
## **Spike scope — ticket `86c9xuab3` (M3 Tier 3 W1 dialogue system spike).**
## See `.claude/docs/dialogue-system.md` for the full architecture; this class
## is the on-disk schema that authors fill in (`.tres` files under
## `resources/dialogue/`).
##
## Per Priya's `team/priya-pl/post-wave3-sequencing.md` §1 Commitment 2 +
## Sponsor SI-2 (full state-branching, 2026-05-22), every tree supports the
## four quest-state branches plus a `flavor` fallback:
##
##   - `&"pre_quest"`       — player has not yet accepted the NPC's bounty
##   - `&"quest_active"`    — player has accepted; bounty in progress
##   - `&"quest_completed"` — player has turned in the bounty
##   - `&"quest_failed"`    — player failed the bounty (M4+ surface; reserved)
##   - `&"flavor"`          — default fallback / non-quest NPC content
##
## ## Branch resolution rule (read by `DialogueController.open`)
##
##   1. If `branches` contains `quest_state`, use that branch.
##   2. Else if `branches` contains `default_branch_key`, use that branch.
##   3. Else push_warning via WarningBus + return null (controller refuses to
##      open the dialogue — better than panicking on an empty tree).
##
## The resolution rule lets a vendor NPC ship a `&"flavor"`-only tree
## (no quest involvement) without authoring empty `pre_quest`/`quest_active`
## stubs — `default_branch_key = &"flavor"` covers every quest_state value.
##
## ## State-branching primitives (spike-level)
##
## **Read side** — branch resolution reads `quest_state` from the controller
## caller (`DialogueController.open(tree, quest_state)`). The spike does NOT
## inspect Player.active_bounty / Player.completed_bounties directly; the
## resolution is `quest_state`-driven so the test surface is observable
## without staging a full bounty-state graph. W2 wires the
## `Player.active_bounty` → `quest_state` mapping in `Main` / `BountyController`.
##
## **Write side** — `DialogueResponse.quest_action` is the side-effect channel.
## When a response is picked, the controller emits
## `quest_action_invoked(action_id, npc_id)`. The spike emits only — it does
## NOT execute the action. W2's bounty system subscribes and translates the
## action string (`&"accept_bounty:s1_wounded_scholar"`) into a Player /
## Inventory mutation.

## NPC identifier — references the stratum NPC the dialogue belongs to. Used
## for tracing and for the W2 NPC ↔ tree lookup table.
## Examples: `&"s1_warden_scholar"`, `&"hub_vendor"`, `&"hub_anvil_keeper"`.
@export var npc_id: StringName = &""

## Display name shown in the panel header (e.g. "Hadda the Anvil-Keeper").
## Decoupled from `npc_id` so the player-facing name can change without
## rippling through bounty-state keys.
@export var display_name: String = ""

## Branch lookup — quest-state key → `DialogueBranch` body.
##
## **Authoring note:** the inspector renders `Dictionary` (typed) cleanly in
## Godot 4.3, but typed `Dictionary[StringName, DialogueBranch]` had editor
## quirks in the 4.3 GA build — using untyped Dictionary here and validating
## entries at controller-resolve time. Drift-pin: `test_branches_must_be_dialogue_branches`
## asserts every value `is DialogueBranch`.
@export var branches: Dictionary = {}

## Fallback branch key when `quest_state` is absent from `branches`. Typical
## value: `&"flavor"`. If `default_branch_key` ALSO is not in `branches`,
## controller refuses to open and emits a `WarningBus.warn`.
@export var default_branch_key: StringName = &"flavor"


## Resolve which branch to play for the given `quest_state`. Returns null if
## neither the state nor the default key are present in `branches` — caller
## (controller) is responsible for the WarningBus emission to keep this method
## allocation-free + side-effect-free for tests.
func resolve_branch(quest_state: StringName) -> DialogueBranch:
	if branches.has(quest_state):
		return branches[quest_state] as DialogueBranch
	if branches.has(default_branch_key):
		return branches[default_branch_key] as DialogueBranch
	return null
