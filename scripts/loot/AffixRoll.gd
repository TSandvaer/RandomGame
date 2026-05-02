class_name AffixRoll
extends RefCounted
## A single affix roll on an `ItemInstance`. Carries the def + the rolled
## value. Per the TRES schema doc: AffixDef is immutable; rolled values
## live on instances.

var def: AffixDef = null
var rolled_value: float = 0.0


func _init(p_def: AffixDef = null, p_rolled_value: float = 0.0) -> void:
	def = p_def
	rolled_value = p_rolled_value


## Applies this affix's roll to a base value, respecting `apply_mode`.
##   ADD: returns base + rolled_value
##   MUL: returns base * (1.0 + rolled_value)
func apply_to(base: float) -> float:
	if def == null:
		return base
	match def.apply_mode:
		AffixDef.ApplyMode.ADD:
			return base + rolled_value
		AffixDef.ApplyMode.MUL:
			return base * (1.0 + rolled_value)
		_:
			push_warning("AffixRoll.apply_to: unknown apply_mode %d" % def.apply_mode)
			return base
