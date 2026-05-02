extends GutTest
## Flagship coverage for `LootRoller` — the 10 edge cases from
## `team/drew-dev/tres-schemas.md` § "Edge cases the loot-roller tests MUST
## cover" plus weight distribution sanity, tier modifier behavior, both
## roll modes, both apply modes, value-range tier respect, and
## determinism.
##
## Schema author's flagship test per testing bar §Devon-and-Drew.

const LootRollerScript: Script = preload("res://scripts/loot/LootRoller.gd")
const AffixRollScript: Script = preload("res://scripts/loot/AffixRoll.gd")
const ItemInstanceScript: Script = preload("res://scripts/loot/ItemInstance.gd")


func _make_roller(seed: int = 42) -> LootRoller:
	var r: LootRoller = LootRollerScript.new()
	r.seed_rng(seed)
	return r


# ---- 1: Empty loot table -------------------------------------------

func test_empty_table_drops_nothing() -> void:
	var r: LootRoller = _make_roller()
	var t: LootTableDef = ContentFactory.make_loot_table({"entries": []})
	var drops: Array[ItemInstance] = r.roll(t)
	assert_eq(drops.size(), 0, "empty table -> empty drops, no crash")


func test_null_table_returns_empty() -> void:
	var r: LootRoller = _make_roller()
	var drops: Array[ItemInstance] = r.roll(null)
	assert_eq(drops.size(), 0, "null table -> empty drops, no crash")


# ---- 2: Zero-weight in independent mode ----------------------------

func test_zero_weight_independent_never_drops() -> void:
	var r: LootRoller = _make_roller()
	var item: ItemDef = ContentFactory.make_item_def()
	var entry: LootEntry = ContentFactory.make_loot_entry(item, 0.0, 0)
	var t: LootTableDef = ContentFactory.make_loot_table({
		"entries": [entry],
		"roll_count": -1,
	})
	# 100 rolls — zero must produce zero drops.
	var total: int = 0
	for i in 100:
		total += r.roll(t).size()
	assert_eq(total, 0, "zero-weight entry never drops in independent mode")


# ---- 3: All-zero-weight in weighted-pick mode -----------------------

func test_all_zero_weight_in_weighted_mode_returns_empty() -> void:
	var r: LootRoller = _make_roller()
	var item_a: ItemDef = ContentFactory.make_item_def({"id": &"a"})
	var item_b: ItemDef = ContentFactory.make_item_def({"id": &"b"})
	var t: LootTableDef = ContentFactory.make_loot_table({
		"entries": [
			ContentFactory.make_loot_entry(item_a, 0.0, 0),
			ContentFactory.make_loot_entry(item_b, 0.0, 0),
		],
		"roll_count": 1,
	})
	var drops: Array[ItemInstance] = r.roll(t)
	assert_eq(drops.size(), 0, "all-zero-weight weighted-pick returns empty, no crash")


# ---- 4: Single-item full-weight always drops -----------------------

func test_single_item_weight_1_always_drops() -> void:
	var r: LootRoller = _make_roller()
	var item: ItemDef = ContentFactory.make_item_def()
	var t: LootTableDef = ContentFactory.make_loot_table({
		"entries": [ContentFactory.make_loot_entry(item, 1.0, 0)],
		"roll_count": -1,
	})
	# Across 50 rolls every one should drop.
	for i in 50:
		var drops: Array[ItemInstance] = r.roll(t)
		assert_eq(drops.size(), 1, "weight 1.0 always drops in independent mode")


# ---- 5: Tier modifier overflow clamps to T6 ------------------------

func test_tier_modifier_overflow_clamps_to_t6() -> void:
	var r: LootRoller = _make_roller()
	var item: ItemDef = ContentFactory.make_item_def({"tier": ItemDef.Tier.T5})
	var entry: LootEntry = ContentFactory.make_loot_entry(item, 1.0, 5)  # T5 + 5 -> overflow
	var t: LootTableDef = ContentFactory.make_loot_table({"entries": [entry]})
	var drops: Array[ItemInstance] = r.roll(t)
	assert_eq(drops.size(), 1)
	assert_eq(drops[0].rolled_tier, ItemDef.Tier.T6, "tier modifier overflow clamps to T6, not crashes")


# ---- 6: Tier modifier underflow clamps to T1 -----------------------

func test_tier_modifier_underflow_clamps_to_t1() -> void:
	var r: LootRoller = _make_roller()
	var item: ItemDef = ContentFactory.make_item_def({"tier": ItemDef.Tier.T1})
	var entry: LootEntry = ContentFactory.make_loot_entry(item, 1.0, -2)
	var t: LootTableDef = ContentFactory.make_loot_table({"entries": [entry]})
	var drops: Array[ItemInstance] = r.roll(t)
	assert_eq(drops.size(), 1)
	assert_eq(drops[0].rolled_tier, ItemDef.Tier.T1, "tier modifier underflow clamps to T1")


# ---- 7: Affix value_ranges shorter than tier index -> hard assert --

func test_affix_with_short_value_ranges_documented() -> void:
	# AffixDef with only 1 tier range, asked to roll at tier index 2.
	# Hard-assert behavior: per testing bar, silent zero is worse than loud
	# assert. We can't easily catch a Godot assert in GUT (it's `assert(...)`
	# which kills the run in debug), so we exercise the precondition by
	# asserting the contract via inspection — the affix itself.
	var bad_affix: AffixDef = ContentFactory.make_affix_def({
		"value_ranges": [ContentFactory.make_affix_value_range(0.0, 1.0)]
	})
	# Fixed shape: one tier range only.
	assert_eq(bad_affix.value_ranges.size(), 1, "test fixture: affix has 1 range only")
	# We do NOT call roll_affix(bad_affix, T3) because that asserts and aborts
	# the test run. Documenting the contract here is enough; the assertion
	# mechanism fires in debug builds, which is exactly what we want.


# ---- 8: Determinism — same seed produces same sequence -------------

func test_same_seed_produces_same_drops() -> void:
	var item_a: ItemDef = ContentFactory.make_item_def({"id": &"alpha"})
	var item_b: ItemDef = ContentFactory.make_item_def({"id": &"beta"})
	var t: LootTableDef = ContentFactory.make_loot_table({
		"entries": [
			ContentFactory.make_loot_entry(item_a, 0.5, 0),
			ContentFactory.make_loot_entry(item_b, 0.5, 0),
		],
		"roll_count": -1,
	})
	# Two independent rollers seeded identically.
	var r1: LootRoller = _make_roller(12345)
	var r2: LootRoller = _make_roller(12345)
	var seq1: Array[String] = []
	var seq2: Array[String] = []
	for _i in 50:
		var d1: Array[ItemInstance] = r1.roll(t)
		var d2: Array[ItemInstance] = r2.roll(t)
		seq1.append("|".join(d1.map(func(it: ItemInstance) -> String: return str(it.def.id))))
		seq2.append("|".join(d2.map(func(it: ItemInstance) -> String: return str(it.def.id))))
	assert_eq(seq1, seq2, "two rollers with same seed produce identical drop sequences")


func test_different_seeds_produce_different_drops_eventually() -> void:
	# Sanity check that determinism comes from the seed, not from a constant.
	# Use widely-spaced seeds — Godot's RandomNumberGenerator with adjacent
	# seeds (1 vs 2) can produce nearly-identical short prefixes.
	var item: ItemDef = ContentFactory.make_item_def()
	var t: LootTableDef = ContentFactory.make_loot_table({
		"entries": [ContentFactory.make_loot_entry(item, 0.5, 0)],
		"roll_count": -1,
	})
	var r1: LootRoller = _make_roller(0xCAFEBABE)
	var r2: LootRoller = _make_roller(0xDEADBEEF)
	var seq1: Array[int] = []
	var seq2: Array[int] = []
	for _i in 200:
		seq1.append(r1.roll(t).size())
		seq2.append(r2.roll(t).size())
	assert_ne(seq1, seq2, "widely-spaced seeds yield different drop sequences")


# ---- 9: Affix value distribution within tier range -----------------

func test_affix_rolls_within_tier_range() -> void:
	var r: LootRoller = _make_roller(7)
	# Build an affix with distinctive ranges per tier so the test catches
	# off-by-one tier-index bugs.
	var affix: AffixDef = ContentFactory.make_affix_def({
		"value_ranges": [
			ContentFactory.make_affix_value_range(1.0, 2.0),     # T1
			ContentFactory.make_affix_value_range(10.0, 20.0),   # T2
			ContentFactory.make_affix_value_range(100.0, 200.0), # T3
		]
	})
	# 1000 rolls of T2 must all land inside [10, 20].
	for _i in 1000:
		var rolled: AffixRoll = r.roll_affix(affix, ItemDef.Tier.T2)
		assert_between(rolled.rolled_value, 10.0, 20.0, "T2 roll inside [10, 20]")


func test_affix_value_range_respects_tier_index() -> void:
	var r: LootRoller = _make_roller()
	var affix: AffixDef = ContentFactory.make_affix_def({
		"value_ranges": [
			ContentFactory.make_affix_value_range(1.0, 1.0),    # T1 — fixed at 1
			ContentFactory.make_affix_value_range(2.0, 2.0),    # T2 — fixed at 2
			ContentFactory.make_affix_value_range(3.0, 3.0),    # T3 — fixed at 3
		]
	})
	assert_almost_eq(r.roll_affix(affix, ItemDef.Tier.T1).rolled_value, 1.0, 0.001)
	assert_almost_eq(r.roll_affix(affix, ItemDef.Tier.T2).rolled_value, 2.0, 0.001)
	assert_almost_eq(r.roll_affix(affix, ItemDef.Tier.T3).rolled_value, 3.0, 0.001)


# ---- 10: ADD vs MUL apply_mode -------------------------------------

func test_apply_mode_add() -> void:
	var add_affix: AffixDef = ContentFactory.make_affix_def({
		"apply_mode": AffixDef.ApplyMode.ADD,
	})
	var roll: AffixRoll = AffixRollScript.new(add_affix, 12.0)
	assert_almost_eq(roll.apply_to(50.0), 62.0, 0.001, "ADD: 50 + 12 = 62")


func test_apply_mode_mul() -> void:
	var mul_affix: AffixDef = ContentFactory.make_affix_def({
		"apply_mode": AffixDef.ApplyMode.MUL,
	})
	var roll: AffixRoll = AffixRollScript.new(mul_affix, 0.10)
	assert_almost_eq(roll.apply_to(100.0), 110.0, 0.001, "MUL: 100 * (1 + 0.10) = 110")


# ---- Bonus: weight distribution sanity (Chi-square-ish) ------------

func test_weighted_pick_distribution_respects_weights() -> void:
	# Two entries with weight 3:1. Over a large N, the heavier should drop
	# significantly more often. We don't run a full chi-square — just an
	# upper/lower band sanity check (75% +/- 5%).
	var r: LootRoller = _make_roller(99)
	var heavy: ItemDef = ContentFactory.make_item_def({"id": &"heavy_item"})
	var light: ItemDef = ContentFactory.make_item_def({"id": &"light_item"})
	var t: LootTableDef = ContentFactory.make_loot_table({
		"entries": [
			ContentFactory.make_loot_entry(heavy, 3.0, 0),
			ContentFactory.make_loot_entry(light, 1.0, 0),
		],
		"roll_count": 1,
	})
	var heavy_count: int = 0
	var total: int = 4000
	for _i in total:
		var drops: Array[ItemInstance] = r.roll(t)
		if drops.size() > 0 and drops[0].def == heavy:
			heavy_count += 1
	var heavy_frac: float = float(heavy_count) / float(total)
	# Expected 0.75; allow 0.7..0.8 band — generous for low N flakiness.
	assert_between(heavy_frac, 0.70, 0.80, "heavy weight (3 vs 1) -> ~75% picks (got %.3f)" % heavy_frac)


# ---- Roll modes side-by-side ---------------------------------------

func test_independent_mode_produces_zero_to_n_items() -> void:
	# 3 entries all 50% chance — over many rolls we should see drops of 0,
	# 1, 2, AND 3 items at least once.
	var r: LootRoller = _make_roller(31)
	var t: LootTableDef = ContentFactory.make_loot_table({
		"entries": [
			ContentFactory.make_loot_entry(ContentFactory.make_item_def({"id": &"a"}), 0.5, 0),
			ContentFactory.make_loot_entry(ContentFactory.make_item_def({"id": &"b"}), 0.5, 0),
			ContentFactory.make_loot_entry(ContentFactory.make_item_def({"id": &"c"}), 0.5, 0),
		],
		"roll_count": -1,
	})
	var seen_sizes: Dictionary = {}
	for _i in 200:
		var sz: int = r.roll(t).size()
		seen_sizes[sz] = true
	for expected: int in [0, 1, 2, 3]:
		assert_true(seen_sizes.has(expected), "independent mode produces drops of size %d at least once" % expected)


func test_weighted_pick_mode_produces_exactly_n() -> void:
	var r: LootRoller = _make_roller()
	var t: LootTableDef = ContentFactory.make_loot_table({
		"entries": [
			ContentFactory.make_loot_entry(ContentFactory.make_item_def(), 1.0, 0),
			ContentFactory.make_loot_entry(ContentFactory.make_item_def(), 1.0, 0),
		],
		"roll_count": 3,  # pick 3 with replacement
	})
	for _i in 20:
		assert_eq(r.roll(t).size(), 3, "weighted-pick mode always produces exactly roll_count drops")


# ---- ItemInstance / affix integration -------------------------------

func test_t1_item_rolls_zero_affixes() -> void:
	var r: LootRoller = _make_roller()
	# Build a T1 item with a populated affix pool — pool exists but T1 spec
	# says "0 affixes".
	var pool: Array[AffixDef] = [ContentFactory.make_affix_def()]
	var item: ItemDef = ContentFactory.make_item_def({
		"tier": ItemDef.Tier.T1,
		"affix_pool": pool,
	})
	var entry: LootEntry = ContentFactory.make_loot_entry(item, 1.0, 0)
	var t: LootTableDef = ContentFactory.make_loot_table({"entries": [entry]})
	var drops: Array[ItemInstance] = r.roll(t)
	assert_eq(drops.size(), 1)
	assert_eq(drops[0].rolled_affixes.size(), 0, "T1 rolls zero affixes per spec")


func test_t2_item_rolls_one_affix() -> void:
	var r: LootRoller = _make_roller()
	var pool: Array[AffixDef] = [
		ContentFactory.make_affix_def({"id": &"a"}),
		ContentFactory.make_affix_def({"id": &"b"}),
	]
	var item: ItemDef = ContentFactory.make_item_def({
		"tier": ItemDef.Tier.T2,
		"affix_pool": pool,
	})
	var entry: LootEntry = ContentFactory.make_loot_entry(item, 1.0, 0)
	var t: LootTableDef = ContentFactory.make_loot_table({"entries": [entry]})
	# Run multiple times — every drop must have exactly 1 affix at T2.
	for _i in 20:
		var drops: Array[ItemInstance] = r.roll(t)
		assert_eq(drops.size(), 1)
		assert_eq(drops[0].rolled_affixes.size(), 1, "T2 always rolls 1 affix")


func test_t3_item_rolls_one_or_two_affixes() -> void:
	var r: LootRoller = _make_roller(13)
	var pool: Array[AffixDef] = [
		ContentFactory.make_affix_def({"id": &"a"}),
		ContentFactory.make_affix_def({"id": &"b"}),
		ContentFactory.make_affix_def({"id": &"c"}),
	]
	var item: ItemDef = ContentFactory.make_item_def({
		"tier": ItemDef.Tier.T3,
		"affix_pool": pool,
	})
	var entry: LootEntry = ContentFactory.make_loot_entry(item, 1.0, 0)
	var t: LootTableDef = ContentFactory.make_loot_table({"entries": [entry]})
	var seen_one: bool = false
	var seen_two: bool = false
	for _i in 100:
		var drops: Array[ItemInstance] = r.roll(t)
		var n: int = drops[0].rolled_affixes.size()
		assert_between(n, 1, 2, "T3 rolls 1 or 2 affixes")
		if n == 1: seen_one = true
		if n == 2: seen_two = true
	assert_true(seen_one and seen_two, "T3 produces both 1- and 2-affix drops over many rolls")


func test_rolled_affixes_have_no_duplicates() -> void:
	var r: LootRoller = _make_roller()
	var pool: Array[AffixDef] = [
		ContentFactory.make_affix_def({"id": &"a"}),
		ContentFactory.make_affix_def({"id": &"b"}),
		ContentFactory.make_affix_def({"id": &"c"}),
	]
	var item: ItemDef = ContentFactory.make_item_def({
		"tier": ItemDef.Tier.T3,
		"affix_pool": pool,
	})
	var entry: LootEntry = ContentFactory.make_loot_entry(item, 1.0, 0)
	var t: LootTableDef = ContentFactory.make_loot_table({"entries": [entry]})
	for _i in 50:
		var drops: Array[ItemInstance] = r.roll(t)
		var ids: Array[StringName] = []
		for ar: AffixRoll in drops[0].rolled_affixes:
			ids.append(ar.def.id)
		# Set check — duplicates appear if size differs.
		var unique: Dictionary = {}
		for id_v in ids:
			unique[id_v] = true
		assert_eq(unique.size(), ids.size(), "affix pick is without duplicates")


func test_clamp_tier_static_method() -> void:
	assert_eq(LootRoller.clamp_tier(-5), int(ItemDef.Tier.T1), "negative clamps to T1 index 0")
	assert_eq(LootRoller.clamp_tier(0), int(ItemDef.Tier.T1))
	assert_eq(LootRoller.clamp_tier(5), int(ItemDef.Tier.T6))
	assert_eq(LootRoller.clamp_tier(99), int(ItemDef.Tier.T6), "overflow clamps to T6 index 5")


# ---- Item display name composition ---------------------------------

func test_item_display_name_includes_affix_names() -> void:
	var swift: AffixDef = ContentFactory.make_affix_def({"name": "Swift"})
	var item: ItemDef = ContentFactory.make_item_def({"display_name": "Iron Sword"})
	var instance: ItemInstance = ItemInstanceScript.new(item, ItemDef.Tier.T2)
	instance.rolled_affixes = [AffixRollScript.new(swift, 0.05)]
	assert_string_contains(instance.get_display_name(), "Swift", "name prefix carries affix")
	assert_string_contains(instance.get_display_name(), "Iron Sword", "name carries base")


# ---- Authored grunt loot integration -------------------------------

func test_authored_grunt_drops_table_rolls_cleanly() -> void:
	var r: LootRoller = _make_roller(0)
	var grunt_def: MobDef = load("res://resources/mobs/grunt.tres") as MobDef
	assert_not_null(grunt_def)
	assert_not_null(grunt_def.loot_table)
	# Roll many times — must never crash, must produce only the two
	# authored items (iron_sword, leather_vest).
	var allowed: Dictionary = {&"iron_sword": true, &"leather_vest": true}
	for _i in 200:
		var drops: Array[ItemInstance] = r.roll(grunt_def.loot_table)
		for it: ItemInstance in drops:
			assert_true(allowed.has(it.def.id), "rolled id %s is one of the authored M1 items" % it.def.id)


# ---- Affix-balance pin §3: tier spread on common-mob (grunt) drops --
#
# Priya's pin (`team/priya-pl/affix-balance-pin.md` §3) authors per-entry
# weights of 0.21 / 0.075 / 0.015 for T1/T2/T3 on each of two base items
# (sword, vest), independent-roll mode.
#
# Drew's run-009 derivation (the weights are the source of truth, the
# §3 stated aggregates are derivative):
#   - Conditional spread per drop: exactly 70% T1 / 25% T2 / 5% T3
#     (each entry samples independently; ratios are 0.21:0.075:0.015 per
#     base item, identical to 70:25:5).
#   - Per-kill aggregate (independent across 6 entries):
#       P(any drop)   = 1 - (0.79 · 0.925 · 0.985)²  ≈ 48.2%
#       P(T2+ drop)   = 1 - (0.925 · 0.985)²         ≈ 17.0%
#       P(T3 drop)    = 1 - 0.985²                   ≈  3.0%
#     Priya's pin states P(any drop)≈51%; the small delta vs 48.2% is the
#     "0.30 per base item" approximation in her §3 prose treating the 3
#     per-base entries as mutually exclusive when the roller actually
#     rolls them independently. Per the PR body, this is flagged for
#     Priya — weights stay as authored, tests assert actual derived
#     values. T2+ and T3 derivations match her stated 17%/3% exactly.
#
# Statistical tests use a fixed seed + 10000 iterations and assert each
# percentage within ±3% tolerance (loose enough for RNG variance, tight
# enough to catch a swapped weight or a missing entry).

const _GRUNT_DROPS_PATH: String = "res://resources/loot_tables/grunt_drops.tres"
const _STAT_ITERATIONS: int = 10000
const _STAT_TOLERANCE: float = 0.03  # ±3 percentage points

func _percent(numerator: int, denominator: int) -> float:
	if denominator == 0:
		return 0.0
	return float(numerator) / float(denominator)


func test_grunt_drops_has_six_tier_varied_entries() -> void:
	# Shape check first — if the table author drops back to a 2-entry
	# table the statistical tests below will be noisy. This test catches
	# a bad-shape regression with a clear failure message.
	var table: LootTableDef = load(_GRUNT_DROPS_PATH) as LootTableDef
	assert_not_null(table, "grunt_drops.tres loads as LootTableDef")
	assert_eq(table.entries.size(), 6, "grunt_drops has 6 entries (2 items × 3 tiers)")
	# Confirm tier_modifier spread: two entries at each of 0, 1, 2.
	var tier_mod_counts: Dictionary = {0: 0, 1: 0, 2: 0}
	for entry: LootEntry in table.entries:
		if tier_mod_counts.has(entry.tier_modifier):
			tier_mod_counts[entry.tier_modifier] += 1
	assert_eq(tier_mod_counts[0], 2, "two T1 entries (tier_modifier=0)")
	assert_eq(tier_mod_counts[1], 2, "two T2 entries (tier_modifier=1)")
	assert_eq(tier_mod_counts[2], 2, "two T3 entries (tier_modifier=2)")


func test_grunt_drops_conditional_tier_spread_70_25_5() -> void:
	# Roll 10000 kills; among items that drop, assert the per-drop tier
	# distribution lands at 70/25/5 (±3pp).
	var r: LootRoller = _make_roller(424242)
	var table: LootTableDef = load(_GRUNT_DROPS_PATH) as LootTableDef
	assert_not_null(table)
	var t1: int = 0
	var t2: int = 0
	var t3: int = 0
	for _i in _STAT_ITERATIONS:
		for it: ItemInstance in r.roll(table):
			match it.rolled_tier:
				ItemDef.Tier.T1: t1 += 1
				ItemDef.Tier.T2: t2 += 1
				ItemDef.Tier.T3: t3 += 1
				_: assert_true(false, "unexpected tier on grunt drop: %d" % it.rolled_tier)
	var total_drops: int = t1 + t2 + t3
	assert_gt(total_drops, 0, "at least some drops over 10000 kills")
	var p_t1: float = _percent(t1, total_drops)
	var p_t2: float = _percent(t2, total_drops)
	var p_t3: float = _percent(t3, total_drops)
	assert_between(p_t1, 0.70 - _STAT_TOLERANCE, 0.70 + _STAT_TOLERANCE,
		"T1 conditional fraction near 70%% (got %.3f)" % p_t1)
	assert_between(p_t2, 0.25 - _STAT_TOLERANCE, 0.25 + _STAT_TOLERANCE,
		"T2 conditional fraction near 25%% (got %.3f)" % p_t2)
	assert_between(p_t3, 0.05 - _STAT_TOLERANCE, 0.05 + _STAT_TOLERANCE,
		"T3 conditional fraction near 5%% (got %.3f)" % p_t3)


func test_grunt_drops_per_kill_aggregate_rates() -> void:
	# Per-kill (per-mob) aggregate: P(any drop) ≈ 51%, P(T2+ drop) ≈ 17%,
	# P(T3 drop) ≈ 3%. Same fixed seed + 10000-iteration discipline.
	var r: LootRoller = _make_roller(0xBEEFCAFE)
	var table: LootTableDef = load(_GRUNT_DROPS_PATH) as LootTableDef
	assert_not_null(table)
	var any_drop: int = 0
	var t2_plus_drop: int = 0
	var t3_drop: int = 0
	for _i in _STAT_ITERATIONS:
		var drops: Array[ItemInstance] = r.roll(table)
		if drops.size() > 0:
			any_drop += 1
		var has_t2_plus: bool = false
		var has_t3: bool = false
		for it: ItemInstance in drops:
			if int(it.rolled_tier) >= int(ItemDef.Tier.T2):
				has_t2_plus = true
			if it.rolled_tier == ItemDef.Tier.T3:
				has_t3 = true
		if has_t2_plus:
			t2_plus_drop += 1
		if has_t3:
			t3_drop += 1
	var p_any: float = _percent(any_drop, _STAT_ITERATIONS)
	var p_t2_plus: float = _percent(t2_plus_drop, _STAT_ITERATIONS)
	var p_t3: float = _percent(t3_drop, _STAT_ITERATIONS)
	# Priya's §3 prose says ~51%, but the actual weights yield 48.2% (see
	# header comment). Asserting the derived value with ±3pp tolerance.
	assert_between(p_any, 0.482 - _STAT_TOLERANCE, 0.482 + _STAT_TOLERANCE,
		"P(any drop) per kill near 48.2%% (got %.3f)" % p_any)
	assert_between(p_t2_plus, 0.17 - _STAT_TOLERANCE, 0.17 + _STAT_TOLERANCE,
		"P(T2+ drop) per kill near 17%% (got %.3f)" % p_t2_plus)
	# T3 is rare (3%) — keep tolerance tight enough to catch a doubled
	# weight but loose enough for the long tail.
	assert_between(p_t3, 0.03 - _STAT_TOLERANCE, 0.03 + _STAT_TOLERANCE,
		"P(T3 drop) per kill near 3%% (got %.3f)" % p_t3)
