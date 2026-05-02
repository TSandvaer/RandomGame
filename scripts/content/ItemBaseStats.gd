class_name ItemBaseStats
extends Resource
## Pre-affix stats granted by an item. Wrapped in a sub-resource so Godot
## inspector groups them, the inventory UI can render the block as one unit,
## and save serialization pickles them as one nested object.
## See `team/drew-dev/tres-schemas.md`.

## Weapon damage. Flat, pre-affix. Currently single-channel in M1; M2 may
## split into physical/elemental.
@export_range(0, 999, 1) var damage: int = 0

## Armor / damage reduction. Flat int in M1; M2 may split by damage type.
@export_range(0, 999, 1) var armor: int = 0

## Universal stat bonuses an item grants when equipped, before any affixes.
@export_range(0, 999, 1) var max_hp_bonus: int = 0
@export_range(0.0, 1.0, 0.01) var crit_chance_bonus: float = 0.0
