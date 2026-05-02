class_name ItemInstance
extends RefCounted
## A rolled item — what the player picks up, what the inventory holds, what
## save serializes. Carries a reference to the immutable `ItemDef` template
## plus the per-drop rolled tier and rolled affixes.
##
## Per the TRES schema doc: `ItemDef` never changes; `ItemInstance` is
## per-drop.

var def: ItemDef = null
var rolled_tier: ItemDef.Tier = ItemDef.Tier.T1
var rolled_affixes: Array[AffixRoll] = []
var unique_id: String = ""


func _init(p_def: ItemDef = null, p_rolled_tier: ItemDef.Tier = ItemDef.Tier.T1) -> void:
	def = p_def
	rolled_tier = p_rolled_tier
	rolled_affixes = []
	# Use a stable unique id derived from object id + tick count. Save code
	# may overwrite for deterministic test seeds.
	unique_id = "%d_%d" % [Time.get_ticks_usec(), get_instance_id()]


## Returns the item's display name suffixed/prefixed with affix names.
## M1 keeps it simple — appended after the base name.
func get_display_name() -> String:
	if def == null:
		return "<unknown>"
	if rolled_affixes.is_empty():
		return def.display_name
	var prefix: String = ""
	for a: AffixRoll in rolled_affixes:
		if a.def != null and a.def.name != "":
			if prefix == "":
				prefix = a.def.name
			else:
				prefix += " " + a.def.name
	return "%s %s" % [prefix, def.display_name]
