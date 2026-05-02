class_name LootTableDef
extends Resource
## Designer-authored loot table. Drives mob drops and chest pulls.
## See `team/drew-dev/tres-schemas.md`.

## All possible drops. Each entry is rolled per kill in independent mode, or
## participates in a single weighted pick in weighted-pick mode.
@export var entries: Array[LootEntry] = []

## How many entries to roll.
##   -1 (default) — independent-roll mode: every entry rolls separately,
##     `LootEntry.weight` is interpreted as a 0..1 drop chance. A mob can drop
##     0..N items per kill. Simpler to reason about and debug.
##   N >= 0 — weighted-pick mode: pick exactly N entries from the table by
##     `weight` (relative). Used for "guaranteed pick one" fixed pulls. N may
##     legitimately exceed entries.size(); the roller picks with replacement.
@export var roll_count: int = -1

@export var id: StringName = &""
