class_name AffixDef
extends Resource
## Designer-authored affix definition. Immutable at runtime — `LootRoller`
## copies values from this template into a per-instance `AffixRoll`.
## See `team/drew-dev/tres-schemas.md`.

## ApplyMode determines how the rolled value mutates the target stat.
##   ADD: stat += rolled_value  (e.g. +12 max_hp)
##   MUL: stat *= (1.0 + rolled_value)  (e.g. +0.08 move_speed_pct)
enum ApplyMode { ADD, MUL }

## Stable identifier (snake_case, unique). E.g. &"swift", &"vital", &"keen".
@export var id: StringName = &""

## Player-visible name. Used in tooltip prefix/suffix construction. en-source
## for M1; localization key migration is M2.
@export var name: String = ""

## Which character/item stat this affix modifies. Devon's stat system owns
## the canonical StringName list. Examples: &"max_hp", &"move_speed_pct",
## &"crit_chance", &"damage_flat", &"damage_pct".
@export var stat_modified: StringName = &""

## Rolled value range per item-tier. Index 0 = T1, 1 = T2, 2 = T3.
## Length is enforced to 3 for M1 (will grow to 6 when T4–T6 ship in M2/M3).
## Designers can hand-tune a non-multiplicative curve here (e.g. T3 jumps
## for crit affixes).
@export var value_ranges: Array[AffixValueRange] = []

@export var apply_mode: ApplyMode = ApplyMode.ADD
