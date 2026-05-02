class_name AffixValueRange
extends Resource
## Min/max range for an affix roll at a given tier. One sub-resource per
## tier slot in `AffixDef.value_ranges`. See `team/drew-dev/tres-schemas.md`.

@export var min_value: float = 0.0
@export var max_value: float = 0.0
