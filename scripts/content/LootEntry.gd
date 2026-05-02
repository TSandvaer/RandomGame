class_name LootEntry
extends Resource
## One row in a loot table. The roller produces 0 or 1 `ItemInstance` per
## entry (independent-roll mode) or 0..1 across the whole table (weighted-pick
## mode). See `team/drew-dev/tres-schemas.md`.

## The item that may drop. Roller instantiates an `ItemInstance` from this
## def, applying tier_modifier and affix rolls.
@export var item_def: ItemDef

## Dual interpretation depending on the parent `LootTableDef.roll_count`:
##   - independent mode (roll_count == -1): weight is interpreted as 0.0–1.0
##     drop chance (clamped). 1.0 = always drops.
##   - weighted-pick mode (roll_count >= 0): weight is relative weight in a
##     weighted random pick. 0.0 = never picked.
## Documented redundantly because this is the most likely footgun for
## content authors.
@export_range(0.0, 100.0, 0.01) var weight: float = 1.0

## Adjusts the tier of the rolled item relative to ItemDef.tier.
##   Example: ItemDef is T2, tier_modifier = 1 → rolled item is T3.
## Clamped to T1..T6 by the roller. Lets one ItemDef ("Iron Sword") drop as
## T1/T2/T3 from different mobs without three separate ItemDefs.
@export_range(-2, 2, 1) var tier_modifier: int = 0
