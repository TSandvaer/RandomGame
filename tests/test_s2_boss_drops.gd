extends GutTest
## Paired test for s2_boss_drops.tres — ticket 86ca1m0e6
## (Archive Sentinel / Stratum-2 boss loot table).
##
## Coverage:
##   1. archive_sentinel.tres references s2_boss_drops.tres — NOT the S1
##      boss_drops.tres placeholder (the reference swap is the load-bearing
##      AC; a future revert surfaces in CI).
##   2. s2_boss_drops.tres loads as a LootTableDef with the expected id +
##      shape (2 entries, roll_count = -1, both weight 1.0).
##   3. The pool yields VALID drops (non-null ItemInstances) — both items
##      drop every roll (guaranteed-drop, mirroring S1 boss).
##   4. S2 tier-flavor: iron_sword rolls T3, leather_vest rolls T3 (the S2
##      progression bump — S1 boss dropped the vest at T2).
##   5. Drop-rate aggregate is sane: over N rolls in independent mode with
##      weight 1.0, every roll produces exactly entries.size() drops.
##   6. Every rolled affix resolves to a REGISTERED AffixDef (swift / vital /
##      keen) with a valid value inside its tier band — pins the
##      "registered affix IDs only" ticket flag (Devon's concurrent
##      unknown-affix-id save bug class is avoided by construction here).
##   7. No USER WARNING from loading the table / mob / rolling drops
##      (universal warning gate per .claude/docs/test-conventions.md).

const LootRollerScript: Script = preload("res://scripts/loot/LootRoller.gd")
const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

const S2_TABLE_PATH: String = "res://resources/loot_tables/s2_boss_drops.tres"
const S1_TABLE_PATH: String = "res://resources/loot_tables/boss_drops.tres"
const SENTINEL_PATH: String = "res://resources/mobs/archive_sentinel.tres"

# Registered M1/M2 affixes (the only affix pool iron_sword + leather_vest carry).
const REGISTERED_AFFIX_IDS: Array = [&"swift", &"vital", &"keen"]

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- 1: reference swap — sentinel points at S2 pool, not S1 ----------


func test_archive_sentinel_references_s2_boss_drops_not_s1() -> void:
	var def: MobDef = load(SENTINEL_PATH) as MobDef
	assert_not_null(def, "archive_sentinel.tres loads")
	assert_not_null(def.loot_table, "archive_sentinel has a loot_table wired")
	assert_eq(
		def.loot_table.id,
		&"s2_boss_drops",
		"archive_sentinel.tres now points at the S2 pool (ticket 86ca1m0e6)"
	)
	assert_ne(
		def.loot_table.id,
		&"boss_drops",
		"archive_sentinel.tres no longer reuses the S1 boss_drops placeholder"
	)
	# Same-instance identity: the wired table is the on-disk s2 table.
	var s2_table: LootTableDef = load(S2_TABLE_PATH) as LootTableDef
	assert_eq(def.loot_table, s2_table, "wired loot_table IS s2_boss_drops.tres (resource cache)")


func test_s1_boss_still_references_s1_boss_drops_untouched() -> void:
	# OOS guard: the S1 boss must keep its own S1 pool (ticket OOS — S1
	# boss_drops.tres untouched).
	var s1_boss: MobDef = load("res://resources/mobs/stratum1_boss.tres") as MobDef
	assert_not_null(s1_boss, "stratum1_boss.tres loads")
	assert_eq(s1_boss.loot_table.id, &"boss_drops", "S1 boss still uses the S1 pool (OOS untouched)")


# ---- 2: S2 table loads + shape --------------------------------------


func test_s2_boss_drops_loads_with_expected_shape() -> void:
	var table: LootTableDef = load(S2_TABLE_PATH) as LootTableDef
	assert_not_null(table, "s2_boss_drops.tres loads as a LootTableDef")
	assert_eq(table.id, &"s2_boss_drops", "table id is s2_boss_drops")
	assert_eq(table.entries.size(), 2, "two entries (iron_sword + leather_vest), mirrors S1 shape")
	assert_eq(table.roll_count, -1, "independent-roll mode (guaranteed-drop), mirrors S1 shape")
	for entry: LootEntry in table.entries:
		assert_not_null(entry, "no null entries")
		assert_not_null(entry.item_def, "every entry has an item_def")
		assert_almost_eq(entry.weight, 1.0, 0.0001, "weight 1.0 = guaranteed drop (boss floor reward)")


# ---- 3 + 4: pool yields valid drops + S2 tier flavor -----------------


func test_s2_pool_yields_both_items_at_t3() -> void:
	var table: LootTableDef = load(S2_TABLE_PATH) as LootTableDef
	var roller: LootRoller = LootRollerScript.new()
	roller.seed_rng(7)
	var drops: Array[ItemInstance] = roller.roll(table)
	assert_eq(drops.size(), 2, "S2 boss guaranteed-drops both items (weight 1.0, independent mode)")

	var saw_sword_t3: bool = false
	var saw_vest_t3: bool = false
	for inst: ItemInstance in drops:
		assert_not_null(inst, "drop is a valid ItemInstance")
		assert_not_null(inst.def, "drop has a resolved ItemDef")
		match inst.def.id:
			&"iron_sword":
				assert_eq(
					inst.rolled_tier, ItemDef.Tier.T3, "iron_sword rolls T3 (tier_modifier=2 on T1 base)"
				)
				saw_sword_t3 = true
			&"leather_vest":
				assert_eq(
					inst.rolled_tier,
					ItemDef.Tier.T3,
					"leather_vest rolls T3 — the S2 progression bump (S1 boss dropped it at T2)"
				)
				saw_vest_t3 = true
			_:
				fail_test("unexpected item id in S2 boss pool: %s" % inst.def.id)
	assert_true(saw_sword_t3, "iron_sword T3 present")
	assert_true(saw_vest_t3, "leather_vest T3 present")


# ---- 5: drop-rate aggregate sane over many rolls ---------------------


func test_s2_drop_rate_aggregate_is_sane() -> void:
	# Independent mode + weight 1.0 ⟹ every roll drops EXACTLY entries.size()
	# items. Roll many times; the per-roll count must be invariant (no empty
	# boss kill, no over-drop). This is the drop-rate sanity floor.
	var table: LootTableDef = load(S2_TABLE_PATH) as LootTableDef
	var roller: LootRoller = LootRollerScript.new()
	roller.seed_rng(123)
	var expected: int = table.entries.size()
	var total_drops: int = 0
	const N: int = 200
	for _i in N:
		var drops: Array[ItemInstance] = roller.roll(table)
		assert_eq(
			drops.size(), expected, "every roll drops exactly %d items (guaranteed)" % expected
		)
		total_drops += drops.size()
	assert_eq(total_drops, N * expected, "aggregate drop count matches guaranteed-drop contract")


# ---- 6: every rolled affix resolves to a REGISTERED affix ------------


func test_s2_drops_only_reference_registered_affixes() -> void:
	# The ticket flags "use only registered affix IDs" (Devon's concurrent
	# unknown-affix-id save-bug class). The S2 table references ITEMS, not
	# affixes — affixes are pulled from each ItemDef.affix_pool at roll time.
	# Verify every affix that lands on an S2 boss drop is one of the three
	# registered M1/M2 affixes, with a value inside the rolled tier's band.
	var table: LootTableDef = load(S2_TABLE_PATH) as LootTableDef
	var roller: LootRoller = LootRollerScript.new()
	roller.seed_rng(55)
	var saw_any_affix: bool = false
	for _i in 200:
		var drops: Array[ItemInstance] = roller.roll(table)
		for inst: ItemInstance in drops:
			for ar: AffixRoll in inst.rolled_affixes:
				assert_not_null(ar.def, "rolled affix resolves to a non-null AffixDef")
				assert_true(
					ar.def.id in REGISTERED_AFFIX_IDS,
					"affix '%s' is a registered M1/M2 affix (swift/vital/keen)" % ar.def.id
				)
				var tier_idx: int = int(inst.rolled_tier)
				assert_lt(
					tier_idx,
					ar.def.value_ranges.size(),
					"affix '%s' has a value_range for the rolled tier" % ar.def.id
				)
				var band: AffixValueRange = ar.def.value_ranges[tier_idx]
				assert_between(
					ar.rolled_value,
					band.min_value,
					band.max_value,
					"affix '%s' value in tier band" % ar.def.id
				)
				saw_any_affix = true
	# T3 drops always roll 1-2 affixes; over 200 rolls we MUST have seen some.
	assert_true(saw_any_affix, "T3 S2 boss drops carry rolled affixes (sanity — pool not empty)")
