class_name DialogueBranch
extends Resource
## A single branch of an NPC dialogue tree — a sequence of `lines` followed by
## an optional list of player `responses`.
##
## **Spike scope — ticket `86c9xuab3` (M3 Tier 3 W1 dialogue system spike).**
## See `.claude/docs/dialogue-system.md` for the full architecture.
##
## ## Lifecycle inside the controller
##
##   1. `DialogueController.open(tree, quest_state)` resolves a branch and
##      calls its `start_node_id`-equivalent entry — the branch's first line
##      (`lines[0]`).
##   2. Pressing `E` (handled by `DialoguePanel`) calls
##      `DialogueController.advance_line()`. If there are more lines, the
##      next line displays. If we've reached the last line:
##        - `responses.is_empty()` → controller closes the dialogue.
##        - `responses.size() > 0` → panel renders the response buttons.
##   3. Picking a response routes to `next_branch_key` or closes.
##
## ## Why a Resource, not a Dictionary
##
## Resource-typing lets the inspector author trees visually, lets `@export
## var` typed fields catch field-name typos at parse time, and lets the GUT
## test smoke-load fixtures from `.tres` paths to verify the schema can
## round-trip from disk.

## Sequential dialogue lines rendered one-at-a-time. May be empty — a branch
## with no lines + non-empty `responses` is a pure choice prompt (e.g. the
## flavor-branch landing).
@export var lines: Array[String] = []

## Player choice options shown after the last line. May be empty — empty
## responses + non-empty lines is a "monologue branch" (controller closes
## dialogue after the last line advance).
@export var responses: Array[DialogueResponse] = []
