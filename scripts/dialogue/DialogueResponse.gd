class_name DialogueResponse
extends Resource
## A player choice option presented at the end of a `DialogueBranch`.
##
## **Spike scope — ticket `86c9xuab3` (M3 Tier 3 W1 dialogue system spike).**
## See `.claude/docs/dialogue-system.md` for the full architecture; this class
## is the leaf "what does picking this option do" record.
##
## Per Priya's `team/priya-pl/post-wave3-sequencing.md` §1 Commitment 2 +
## Sponsor SI-2 sign-off (full state-branching dialogue, 2026-05-22) the spike
## proves the data shape — implementation impl (3 hub + 3 stratum trees) lands
## in W2.
##
## ## Fields
##   - `text` — the option label rendered in the panel.
##   - `next_branch_key` — the `DialogueBranch` key in `DialogueTreeDef.branches`
##     to navigate to when this option is picked. `&""` (empty StringName) means
##     "close the dialogue" — the controller routes that to `close()`.
##   - `quest_action` — optional side-effect identifier the controller emits via
##     `quest_action_invoked(action_id, npc_id)` when this option is picked. The
##     spike does NOT execute the side effect; it just makes the intent visible
##     for W2's bounty-system wiring. Example values per ticket brief:
##         `&"accept_bounty:s1_wounded_scholar"`
##         `&"complete_bounty:s1_wounded_scholar"`
##         `&"open_vendor"`  (hub vendor opens shop UI)
##     `&""` means "no side effect — purely a tree-navigation choice".

## Player option label rendered in the panel button.
@export var text: String = ""

## Next branch key to navigate to when this response is selected. `&""` closes
## the dialogue. Must reference a key in the owning `DialogueTreeDef.branches`
## (or `&""`); the controller push_warning's via `WarningBus` on unknown keys.
@export var next_branch_key: StringName = &""

## Optional side-effect identifier — controller emits `quest_action_invoked`
## when picked. `&""` means no side effect.
@export var quest_action: StringName = &""
