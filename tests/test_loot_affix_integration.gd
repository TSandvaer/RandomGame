extends GutTest
## Integration tests for the loot pipeline + affix rolls + save round-trip.
##
## Per ticket `86c9kxx5p` paired-tests bar:
##   1. Mob death -> loot drop -> ItemInstance has affixes per tier
##   2. Save round-trip preserves rolled affixes (no schema bump — v3
##      already names rolled_affixes in the stash entry shape)
##
## Plus: ItemInstance.to_save_dict / from_save_dict round-trip via
## explicit resolvers (the contract tests/factories use).

const LootRollerScript: Script = preload("res://scripts/loot/LootRoller.gd")
const AffixRollScript: Script = preload("res://scripts/loot/AffixRoll.gd")
const ItemInstanceScript: Script = preload("res://scripts/loot/ItemInstance.gd")
const MobLootSpawnerScript: Script = preload("res://scripts/loot/MobLootSpawner.gd")

const TEST_SLOT: int = 977


func _save() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Save")


func before_each() -> void:
	if _save() != null and _save().has_save(TEST_SLOT):
		_save().delete_save(TEST_SLOT)


func after_each() -> void:
	if _save() != null and _save().has_save(TEST_SLOT):
		_save().delete_save(TEST_SLOT)


# =======================================================================
# 1. Mob death -> loot drop -> ItemInstance has affixes per tier
# =======================================================================

func test_authored_grunt_drop_produces_affixes() -> void:
	# Grunt's authored loot table drops iron_sword and leather_vest. Both
	# point at the M1 affix pool. Roll many times; T2/T3 drops carry
	# rolled affixes; T1 drops have none.
	var roller: LootRoller = LootRollerScript.new()
	roller.seed_rng(11)
	var grunt_def: MobDef = load("res://resources/mobs/grunt.tres") as MobDef
	assert_not_null(grunt_def)
	assert_not_null(grunt_def.loot_table)

	var saw_t2_with_affix: bool = false
	var saw_t1_no_affix: bool = false
	for _i in 200:
		var drops: Array[ItemInstance] = roller.roll(grunt_def.loot_table)
		for inst: ItemInstance in drops:
			if inst.rolled_tier == ItemDef.Tier.T1:
				assert_eq(inst.rolled_affixes.size(), 0, "T1 drops have 0 affixes")
				saw_t1_no_affix = true
			elif inst.rolled_tier == ItemDef.Tier.T2:
				assert_eq(inst.rolled_affixes.size(), 1, "T2 drops have 1 affix")
				# Affix must be a known M1 affix and use a known stat.
				var aff: AffixRoll = inst.rolled_affixes[0]
				assert_not_null(aff.def)
				var known_stats: Array = [&"vigor", &"focus", &"edge", &"move_speed"]
				assert_true(aff.def.stat_modified in known_stats,
					"affix stat is one of M1 vital/keen/swift; got %s" % aff.def.stat_modified)
				saw_t2_with_affix = true
			elif inst.rolled_tier == ItemDef.Tier.T3:
				var n: int = inst.rolled_affixes.size()
				assert_between(n, 1, 2, "T3 has 1 or 2 affixes")
	# Grunt's loot table is iron_sword (T1) + leather_vest (T1); both T1.
	# So we expect saw_t1_no_affix true; saw_t2 may stay false unless a
	# tier_modifier promoted them. The grunt_drops table doesn't promote,
	# so we assert only the T1 path; the boss table covers the T2/T3 path.
	assert_true(saw_t1_no_affix, "grunt table drops T1 items with 0 affixes")


func test_boss_drop_produces_higher_tier_affixes() -> void:
	# boss_drops.tres ships iron_sword tier_modifier=2 (-> T3) and
	# leather_vest tier_modifier=1 (-> T2). Both should roll affixes.
	var boss_table: LootTableDef = load("res://resources/loot_tables/boss_drops.tres") as LootTableDef
	assert_not_null(boss_table)
	var roller: LootRoller = LootRollerScript.new()
	roller.seed_rng(42)
	# In independent-roll mode with weight 1.0, both items always drop.
	var drops: Array[ItemInstance] = roller.roll(boss_table)
	assert_eq(drops.size(), 2, "boss table guaranteed-drops both items")
	for inst: ItemInstance in drops:
		# T2 -> 1 affix, T3 -> 1 or 2 affixes.
		match inst.rolled_tier:
			ItemDef.Tier.T2:
				assert_eq(inst.rolled_affixes.size(), 1, "boss T2 drop has 1 affix")
			ItemDef.Tier.T3:
				assert_between(inst.rolled_affixes.size(), 1, 2, "boss T3 drop has 1-2 affixes")
			_:
				fail_test("unexpected tier %d for boss drop" % inst.rolled_tier)
		# Each affix value must be inside its tier's range.
		for ar: AffixRoll in inst.rolled_affixes:
			var tier_idx: int = int(inst.rolled_tier)
			assert_lt(tier_idx, ar.def.value_ranges.size(),
				"affix has a value_range for the rolled tier")
			var rng_band: AffixValueRange = ar.def.value_ranges[tier_idx]
			assert_between(ar.rolled_value, rng_band.min_value, rng_band.max_value,
				"rolled value %.4f in [%.4f, %.4f] for affix '%s'" % [
					ar.rolled_value, rng_band.min_value, rng_band.max_value, ar.def.id
				])


# =======================================================================
# 2. Save round-trip preserves rolled affixes
# =======================================================================

func test_item_instance_save_roundtrip_preserves_affixes() -> void:
	# Build an ItemInstance with two rolled affixes; serialize; rebuild
	# via from_save_dict using explicit resolvers; assert fields match.
	var item: ItemDef = ContentFactory.make_item_def({
		"id": &"rt_sword",
		"slot": ItemDef.Slot.WEAPON,
		"tier": ItemDef.Tier.T2,
	})
	var vital: AffixDef = ContentFactory.make_affix_def({
		"id": &"rt_vital",
		"stat_modified": &"vigor",
		"apply_mode": AffixDef.ApplyMode.ADD,
	})
	var keen: AffixDef = ContentFactory.make_affix_def({
		"id": &"rt_keen",
		"stat_modified": &"edge",
		"apply_mode": AffixDef.ApplyMode.ADD,
	})
	var instance: ItemInstance = ItemInstanceScript.new(item, ItemDef.Tier.T2)
	instance.rolled_affixes = [
		AffixRollScript.new(vital, 12.0),
		AffixRollScript.new(keen, 4.5),
	]

	var serialized: Dictionary = instance.to_save_dict()
	assert_eq(serialized["id"], "rt_sword")
	assert_eq(serialized["tier"], int(ItemDef.Tier.T2))
	assert_eq((serialized["rolled_affixes"] as Array).size(), 2)
	assert_eq(serialized["rolled_affixes"][0]["affix_id"], "rt_vital")
	assert_almost_eq(float(serialized["rolled_affixes"][0]["value"]), 12.0, 0.0001)
	assert_eq(serialized["rolled_affixes"][1]["affix_id"], "rt_keen")
	assert_almost_eq(float(serialized["rolled_affixes"][1]["value"]), 4.5, 0.0001)

	# Build resolvers — closure-style.
	var item_lookup: Dictionary = {&"rt_sword": item}
	var affix_lookup: Dictionary = {&"rt_vital": vital, &"rt_keen": keen}
	var item_resolver: Callable = func(id: StringName) -> Resource: return item_lookup.get(id, null)
	var affix_resolver: Callable = func(id: StringName) -> Resource: return affix_lookup.get(id, null)

	var rebuilt: ItemInstance = ItemInstanceScript.from_save_dict(serialized, item_resolver, affix_resolver)
	assert_not_null(rebuilt, "rebuild succeeds")
	assert_eq(rebuilt.def, item)
	assert_eq(rebuilt.rolled_tier, ItemDef.Tier.T2)
	assert_eq(rebuilt.rolled_affixes.size(), 2)
	assert_eq(rebuilt.rolled_affixes[0].def, vital)
	assert_almost_eq(rebuilt.rolled_affixes[0].rolled_value, 12.0, 0.0001)
	assert_eq(rebuilt.rolled_affixes[1].def, keen)
	assert_almost_eq(rebuilt.rolled_affixes[1].rolled_value, 4.5, 0.0001)


func test_save_envelope_round_trip_preserves_affix_values() -> void:
	# Full Save autoload round-trip: save_game -> load_game -> read stash.
	# We use the on-disk save format (v3 stash entry) which already names
	# rolled_affixes; no schema bump needed.
	var data: Dictionary = _save().default_payload()
	data["stash"] = [
		{
			"id": "iron_sword",
			"tier": int(ItemDef.Tier.T2),
			"rolled_affixes": [
				{"affix_id": "vital", "value": 12.0},
				{"affix_id": "keen", "value": 4.5},
			],
			"stack_count": 1,
		},
	]
	assert_true(_save().save_game(TEST_SLOT, data))
	var loaded: Dictionary = _save().load_game(TEST_SLOT)
	assert_eq(loaded["stash"].size(), 1)
	var stash_entry: Dictionary = loaded["stash"][0]
	assert_eq(stash_entry["id"], "iron_sword")
	assert_eq(stash_entry["tier"], int(ItemDef.Tier.T2))
	assert_eq((stash_entry["rolled_affixes"] as Array).size(), 2)
	assert_eq(stash_entry["rolled_affixes"][0]["affix_id"], "vital")
	assert_almost_eq(float(stash_entry["rolled_affixes"][0]["value"]), 12.0, 1e-6)
	assert_almost_eq(float(stash_entry["rolled_affixes"][1]["value"]), 4.5, 1e-6)


func test_from_save_dict_skips_unknown_affix_id() -> void:
	# Defensive: a save authored against a no-longer-shipping affix
	# shouldn't crash load — just drop the unknown affix line.
	var item: ItemDef = ContentFactory.make_item_def({"id": &"rt_sword2"})
	var keen: AffixDef = ContentFactory.make_affix_def({"id": &"rt_keen2"})
	var data: Dictionary = {
		"id": "rt_sword2",
		"tier": int(ItemDef.Tier.T2),
		"rolled_affixes": [
			{"affix_id": "rt_keen2", "value": 3.0},
			{"affix_id": "ghost_affix", "value": 99.0},  # unknown
		],
		"stack_count": 1,
	}
	var item_resolver: Callable = func(id: StringName) -> Resource:
		return item if id == &"rt_sword2" else null
	var affix_resolver: Callable = func(id: StringName) -> Resource:
		return keen if id == &"rt_keen2" else null
	var rebuilt: ItemInstance = ItemInstanceScript.from_save_dict(data, item_resolver, affix_resolver)
	assert_not_null(rebuilt, "load tolerates unknown affix id")
	assert_eq(rebuilt.rolled_affixes.size(), 1, "unknown affix is dropped, known affix retained")


func test_from_save_dict_returns_null_for_unknown_item() -> void:
	var item_resolver: Callable = func(_id: StringName) -> Resource: return null
	var affix_resolver: Callable = func(_id: StringName) -> Resource: return null
	var data: Dictionary = {"id": "ghost_item", "tier": 0, "rolled_affixes": []}
	var result: ItemInstance = ItemInstanceScript.from_save_dict(data, item_resolver, affix_resolver)
	assert_null(result, "unknown item id -> null (caller drops the stash entry)")
