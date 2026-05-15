class_name ItemInstance
extends RefCounted
## A rolled item — what the player picks up, what the inventory holds, what
## save serializes. Carries a reference to the immutable `ItemDef` template
## plus the per-drop rolled tier and rolled affixes.
##
## Per the TRES schema doc: `ItemDef` never changes; `ItemInstance` is
## per-drop.
##
## **Save shape** (per `team/devon-dev/save-format.md` §"stash"):
##   {
##     "id": "<itemdef_id>",
##     "tier": <int>,
##     "rolled_affixes": [
##       {"affix_id": "<affixdef_id>", "value": <float>},
##       ...
##     ],
##     "stack_count": 1
##   }
##
## `to_save_dict()` produces this shape; `from_save_dict()` rebuilds an
## `ItemInstance` given a resolver that maps `id -> ItemDef` and `affix_id
## -> AffixDef`. The resolver pattern keeps `ItemInstance` decoupled from
## the content registry — tests inject their own resolver.

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


# ---- Save serialization ------------------------------------------------

## Serialize to a Dictionary matching the save-format.md §"stash" shape.
## Returns {} if the item has no def (defensive — a corrupt instance can't
## round-trip, and we don't want to write bogus data into the save).
func to_save_dict() -> Dictionary:
	if def == null:
		return {}
	var affixes: Array = []
	for a: AffixRoll in rolled_affixes:
		if a == null or a.def == null:
			continue
		affixes.append({
			"affix_id": String(a.def.id),
			"value": a.rolled_value,
		})
	return {
		"id": String(def.id),
		"tier": int(rolled_tier),
		"rolled_affixes": affixes,
		"stack_count": 1,
	}


## Rebuild an ItemInstance from a save-shaped dict. The `item_resolver`
## callable maps a StringName id to an `ItemDef` (or null). The
## `affix_resolver` callable maps a StringName id to an `AffixDef` (or
## null). Affixes whose ids resolve to null are skipped (defensive — a
## save authored against a no-longer-shipping affix shouldn't crash load).
##
## Returns null if `data` is missing critical fields or if the item id
## doesn't resolve. Caller treats null as "drop this stash entry, log a
## warning."
##
## Resolver signature (Callable):
##   func resolve(id: StringName) -> Resource:  # ItemDef or AffixDef
static func from_save_dict(data: Dictionary, item_resolver: Callable, affix_resolver: Callable) -> ItemInstance:
	if data == null or data.is_empty():
		return null
	var item_id_v: Variant = data.get("id", "")
	if item_id_v == null or String(item_id_v) == "":
		return null
	var item_id: StringName = StringName(String(item_id_v))
	var item_def: ItemDef = item_resolver.call(item_id) as ItemDef
	if item_def == null:
		# Routed through WarningBus so the universal-warning gate (ticket
		# 86c9uf0mm Half B) catches this in GUT tests. Direct `push_warning`
		# is invisible to NoWarningGuard. The native `push_warning` is still
		# fired inside WarningBus.warn — console / HTML5 console.warn /
		# stderr surfaces are unchanged.
		_emit_warning("ItemInstance.from_save_dict: unknown item id '%s'" % item_id,
			"unknown_item_id")
		return null
	var tier_int: int = int(data.get("tier", int(item_def.tier)))
	var inst: ItemInstance = ItemInstance.new(item_def, tier_int)
	var affix_dicts: Variant = data.get("rolled_affixes", [])
	if affix_dicts is Array:
		var rolls: Array[AffixRoll] = []
		for entry_v in affix_dicts:
			if not (entry_v is Dictionary):
				continue
			var entry: Dictionary = entry_v
			var aff_id_v: Variant = entry.get("affix_id", "")
			if aff_id_v == null or String(aff_id_v) == "":
				continue
			var aff_id: StringName = StringName(String(aff_id_v))
			var aff_def: AffixDef = affix_resolver.call(aff_id) as AffixDef
			if aff_def == null:
				_emit_warning("ItemInstance.from_save_dict: unknown affix id '%s' on item '%s'" % [aff_id, item_id],
					"unknown_affix_id")
				continue
			var v: float = float(entry.get("value", 0.0))
			rolls.append(AffixRoll.new(aff_def, v))
		inst.rolled_affixes = rolls
	return inst


# ---- Display data for hover tooltips -----------------------------------

## Returns one human-readable line per affix for inventory hover display.
## Devon's UI work will wire this; for M1 we just expose the strings.
##
## Format: "<affix_name>: +<value> <stat>" or "<affix_name>: +<pct>% <stat>"
## depending on apply_mode.
func get_affix_display_lines() -> Array[String]:
	var lines: Array[String] = []
	for a: AffixRoll in rolled_affixes:
		if a == null or a.def == null:
			continue
		var stat_label: String = String(a.def.stat_modified)
		var name_label: String = a.def.name if a.def.name != "" else String(a.def.id)
		match a.def.apply_mode:
			AffixDef.ApplyMode.ADD:
				lines.append("%s: +%s %s" % [name_label, _fmt_number(a.rolled_value), stat_label])
			AffixDef.ApplyMode.MUL:
				var pct: float = a.rolled_value * 100.0
				lines.append("%s: +%s%% %s" % [name_label, _fmt_number(pct), stat_label])
			_:
				lines.append("%s: %s %s" % [name_label, _fmt_number(a.rolled_value), stat_label])
	return lines


## Returns base-stats display lines for hover display. Excludes zero values
## to avoid noise.
func get_base_stats_display_lines() -> Array[String]:
	var lines: Array[String] = []
	if def == null or def.base_stats == null:
		return lines
	var bs: ItemBaseStats = def.base_stats
	if bs.damage > 0:
		lines.append("Damage: %d" % bs.damage)
	if bs.armor > 0:
		lines.append("Armor: %d" % bs.armor)
	if bs.max_hp_bonus > 0:
		lines.append("Max HP: +%d" % bs.max_hp_bonus)
	if bs.crit_chance_bonus > 0.0:
		lines.append("Crit Chance: +%s%%" % _fmt_number(bs.crit_chance_bonus * 100.0))
	return lines


# Format a float for display: integer if it's a whole number, else 2 decimals.
static func _fmt_number(v: float) -> String:
	if absf(v - roundf(v)) < 0.005:
		return "%d" % int(roundf(v))
	return "%.2f" % v


# Route a warning through WarningBus when the autoload is available, so the
# universal-warning gate (ticket 86c9uf0mm Half B) catches it in GUT tests.
# Falls back to direct `push_warning` if the autoload is missing (defensive
# — only matters in test contexts where the autoload didn't boot).
#
# Static because `from_save_dict` is static. Autoload globals are accessible
# from static methods (they live on the SceneTree root, not the class).
static func _emit_warning(text: String, category: String = "") -> void:
	var main_loop := Engine.get_main_loop() as SceneTree
	if main_loop != null:
		var bus: Node = main_loop.root.get_node_or_null("WarningBus")
		if bus != null and bus.has_method("warn"):
			bus.warn(text, category)
			return
	# Fallback: native push_warning preserves the console / stderr surface.
	push_warning(text)
