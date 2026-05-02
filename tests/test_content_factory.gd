extends GutTest
## Smoke tests for `tests/factories/content_factory.gd` and the TRES schema
## scripts in `scripts/content/`. Catches field drift before it cascades
## into N broken downstream tests.
##
## Per `team/drew-dev/tres-schemas.md` § "Sign-off checklist" — exercises
## every `make_*` factory once.

func test_make_affix_value_range_defaults() -> void:
	var r: AffixValueRange = ContentFactory.make_affix_value_range()
	assert_eq(r.min_value, 1.0)
	assert_eq(r.max_value, 5.0)


func test_make_affix_value_range_overrides() -> void:
	var r: AffixValueRange = ContentFactory.make_affix_value_range(0.5, 2.5)
	assert_eq(r.min_value, 0.5)
	assert_eq(r.max_value, 2.5)


func test_make_affix_def_defaults() -> void:
	var a: AffixDef = ContentFactory.make_affix_def()
	assert_eq(a.id, &"test_swift")
	assert_eq(a.stat_modified, &"move_speed_pct")
	assert_eq(a.apply_mode, AffixDef.ApplyMode.MUL)
	assert_eq(a.value_ranges.size(), 3, "default has 3 tier ranges")


func test_make_affix_def_overrides() -> void:
	var a: AffixDef = ContentFactory.make_affix_def({
		"id": &"custom_keen",
		"apply_mode": AffixDef.ApplyMode.ADD,
	})
	assert_eq(a.id, &"custom_keen")
	assert_eq(a.apply_mode, AffixDef.ApplyMode.ADD)


func test_make_item_base_stats_defaults_zero() -> void:
	var s: ItemBaseStats = ContentFactory.make_item_base_stats()
	assert_eq(s.damage, 0)
	assert_eq(s.armor, 0)
	assert_eq(s.max_hp_bonus, 0)
	assert_eq(s.crit_chance_bonus, 0.0)


func test_make_item_def_defaults() -> void:
	var i: ItemDef = ContentFactory.make_item_def()
	assert_eq(i.id, &"test_iron_sword")
	assert_eq(i.slot, ItemDef.Slot.WEAPON)
	assert_eq(i.tier, ItemDef.Tier.T1)
	assert_not_null(i.base_stats)
	assert_eq(i.base_stats.damage, 5, "default factory item has damage 5 base")
	assert_eq(i.affix_pool.size(), 0)


func test_make_loot_entry_carries_item_and_weight() -> void:
	var item: ItemDef = ContentFactory.make_item_def()
	var e: LootEntry = ContentFactory.make_loot_entry(item, 0.42, 1)
	assert_eq(e.item_def, item)
	assert_eq(e.weight, 0.42)
	assert_eq(e.tier_modifier, 1)


func test_make_loot_table_default_independent_mode() -> void:
	var t: LootTableDef = ContentFactory.make_loot_table()
	assert_eq(t.roll_count, -1, "default factory uses independent-roll mode")
	assert_eq(t.entries.size(), 1)


func test_make_mob_def_defaults_align_with_grunt_spec() -> void:
	var m: MobDef = ContentFactory.make_mob_def()
	assert_eq(m.hp_base, 50, "M1 grunt = 50 HP per spec")
	assert_eq(m.damage_base, 5, "M1 grunt = 5 base dmg per spec")
	assert_eq(m.ai_behavior_tag, &"melee_chaser")


func test_make_mob_def_with_loot_table() -> void:
	var table: LootTableDef = ContentFactory.make_loot_table()
	var m: MobDef = ContentFactory.make_mob_def({"loot_table": table})
	assert_eq(m.loot_table, table)


# ---- Authored TRES round-trip ----------------------------------------

func test_authored_grunt_tres_loads() -> void:
	# Per sign-off checklist: load the authored grunt.tres, assert types
	# resolve, fields match the spec.
	var def: MobDef = load("res://resources/mobs/grunt.tres") as MobDef
	assert_not_null(def, "grunt.tres loads as MobDef")
	assert_eq(def.id, &"grunt")
	assert_eq(def.hp_base, 50)
	assert_eq(def.damage_base, 5)
	assert_eq(def.ai_behavior_tag, &"melee_chaser")
	assert_not_null(def.loot_table, "grunt has a loot table")


func test_authored_affixes_each_have_three_tiers() -> void:
	# M1 spec: 3 affixes total, each with 3 tier ranges (T1/T2/T3).
	var ids: Array[String] = ["swift", "vital", "keen"]
	for id_str: String in ids:
		var a: AffixDef = load("res://resources/affixes/%s.tres" % id_str) as AffixDef
		assert_not_null(a, "affix %s.tres loads" % id_str)
		assert_eq(a.value_ranges.size(), 3, "affix %s has 3 tier ranges (T1/T2/T3)" % id_str)
		# Monotone check (soft — schema doc says values may vary, but
		# sanity check on shipped data).
		for i in 3:
			var rng: AffixValueRange = a.value_ranges[i]
			assert_lte(rng.min_value, rng.max_value, "%s tier %d: min <= max" % [id_str, i])


func test_authored_iron_sword_tres_loads() -> void:
	var item: ItemDef = load("res://resources/items/weapons/iron_sword.tres") as ItemDef
	assert_not_null(item)
	assert_eq(item.id, &"iron_sword")
	assert_eq(item.slot, ItemDef.Slot.WEAPON)
	assert_not_null(item.base_stats)
	assert_eq(item.affix_pool.size(), 3, "iron sword has full M1 affix pool")


func test_authored_grunt_drops_loot_table_loads() -> void:
	var table: LootTableDef = load("res://resources/loot_tables/grunt_drops.tres") as LootTableDef
	assert_not_null(table)
	assert_eq(table.roll_count, -1, "grunt drops use independent-roll mode")
	assert_eq(table.entries.size(), 2, "drops one of: iron_sword, leather_vest")
