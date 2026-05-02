class_name ItemDef
extends Resource
## Designer-authored item template. Immutable at runtime — `LootRoller`
## produces an `ItemInstance` from this def with rolled tier/affixes.
## See `team/drew-dev/tres-schemas.md`.

## Equipment slot the item fits. M1 only uses WEAPON and ARMOR.
enum Slot { WEAPON, ARMOR, OFF_HAND, TRINKET, RELIC }

## Tier — drives drop level, base-stat magnitude, affix count, and color in
## UI. Per game-concept.md: T1 worn (0 affixes), T2 common (1), T3 fine (1–2),
## T4 rare (2–3), T5 heroic (3), T6 mythic (3 + set). M1 ships T1–T3 only.
enum Tier { T1, T2, T3, T4, T5, T6 }

## Stable identifier (snake_case, unique).
@export var id: StringName = &""

@export var display_name: String = ""

@export var slot: Slot = Slot.WEAPON

@export var tier: Tier = Tier.T1

@export_file("*.png") var icon_path: String = ""

## Wrapped in a sub-resource for inspector grouping + future-proofing.
@export var base_stats: ItemBaseStats

## Allowed affixes for this item. The roller picks N from this pool with no
## duplicates per item. Empty for T1 (0 affixes by spec).
@export var affix_pool: Array[AffixDef] = []
