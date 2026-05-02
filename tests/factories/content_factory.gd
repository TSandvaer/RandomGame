class_name ContentFactory
## Static test data factories for the TRES content schema. Each Resource
## class in `scripts/content/` has a paired `make_*(overrides: Dictionary)`
## method here. Tests own their inputs deterministically — a balance pass to
## an authored .tres should never break a roller test.
##
## See `team/drew-dev/tres-schemas.md` § "Test data factories" for rationale.

const _AffixValueRange: Script = preload("res://scripts/content/AffixValueRange.gd")
const _AffixDef: Script = preload("res://scripts/content/AffixDef.gd")
const _ItemBaseStats: Script = preload("res://scripts/content/ItemBaseStats.gd")
const _ItemDef: Script = preload("res://scripts/content/ItemDef.gd")
const _LootEntry: Script = preload("res://scripts/content/LootEntry.gd")
const _LootTableDef: Script = preload("res://scripts/content/LootTableDef.gd")
const _MobDef: Script = preload("res://scripts/content/MobDef.gd")


static func make_affix_value_range(min_v: float = 1.0, max_v: float = 5.0) -> AffixValueRange:
	var r: AffixValueRange = _AffixValueRange.new()
	r.min_value = min_v
	r.max_value = max_v
	return r


static func make_affix_def(overrides: Dictionary = {}) -> AffixDef:
	var a: AffixDef = _AffixDef.new()
	a.id = overrides.get("id", &"test_swift")
	a.name = overrides.get("name", "Swift")
	a.stat_modified = overrides.get("stat_modified", &"move_speed_pct")
	a.apply_mode = overrides.get("apply_mode", AffixDef.ApplyMode.MUL)
	# value_ranges must be Array[AffixValueRange] — untyped Array literals
	# from Dictionary.get() can't be assigned directly to a typed-array
	# property in Godot 4. Build a fresh typed array and copy.
	var ranges: Array[AffixValueRange] = []
	if overrides.has("value_ranges"):
		for r in overrides["value_ranges"]:
			ranges.append(r)
	else:
		ranges.append(make_affix_value_range(0.02, 0.04))  # T1
		ranges.append(make_affix_value_range(0.04, 0.08))  # T2
		ranges.append(make_affix_value_range(0.08, 0.12))  # T3
	a.value_ranges = ranges
	return a


static func make_item_base_stats(overrides: Dictionary = {}) -> ItemBaseStats:
	var s: ItemBaseStats = _ItemBaseStats.new()
	s.damage = overrides.get("damage", 0)
	s.armor = overrides.get("armor", 0)
	s.max_hp_bonus = overrides.get("max_hp_bonus", 0)
	s.crit_chance_bonus = overrides.get("crit_chance_bonus", 0.0)
	return s


static func make_item_def(overrides: Dictionary = {}) -> ItemDef:
	var i: ItemDef = _ItemDef.new()
	i.id = overrides.get("id", &"test_iron_sword")
	i.display_name = overrides.get("display_name", "Iron Sword")
	i.slot = overrides.get("slot", ItemDef.Slot.WEAPON)
	i.tier = overrides.get("tier", ItemDef.Tier.T1)
	i.icon_path = overrides.get("icon_path", "")
	i.base_stats = overrides.get("base_stats", make_item_base_stats({"damage": 5}))
	# Typed-array copy (Array[AffixDef]).
	var pool: Array[AffixDef] = []
	if overrides.has("affix_pool"):
		for p in overrides["affix_pool"]:
			pool.append(p)
	i.affix_pool = pool
	return i


static func make_loot_entry(item: ItemDef, weight: float = 1.0, tier_mod: int = 0) -> LootEntry:
	var e: LootEntry = _LootEntry.new()
	e.item_def = item
	e.weight = weight
	e.tier_modifier = tier_mod
	return e


static func make_loot_table(overrides: Dictionary = {}) -> LootTableDef:
	var t: LootTableDef = _LootTableDef.new()
	t.id = overrides.get("id", &"test_loot_table")
	# Typed-array copy (Array[LootEntry]).
	var entries: Array[LootEntry] = []
	if overrides.has("entries"):
		for e in overrides["entries"]:
			entries.append(e)
	else:
		entries.append(make_loot_entry(make_item_def(), 1.0, 0))
	t.entries = entries
	t.roll_count = overrides.get("roll_count", -1)
	return t


static func make_mob_def(overrides: Dictionary = {}) -> MobDef:
	var m: MobDef = _MobDef.new()
	m.id = overrides.get("id", &"test_grunt")
	m.display_name = overrides.get("display_name", "Test Grunt")
	m.sprite_path = overrides.get("sprite_path", "")
	m.hp_base = overrides.get("hp_base", 50)
	m.damage_base = overrides.get("damage_base", 5)
	m.move_speed = overrides.get("move_speed", 60.0)
	m.ai_behavior_tag = overrides.get("ai_behavior_tag", &"melee_chaser")
	m.loot_table = overrides.get("loot_table", null)
	m.xp_reward = overrides.get("xp_reward", 10)
	return m
