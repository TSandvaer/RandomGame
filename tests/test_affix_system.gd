extends GutTest
## Paired tests for the affix system per ticket `86c9kxx5p`.
##
## Covers the 10 task-spec coverage points (some interpreted to match the
## existing affix-count-by-tier contract from `team/drew-dev/tres-schemas.md`,
## which is T1=0, T2=1, T3=1–2 — see `team/drew-dev/affix-application.md`
## §"Affix-count-by-tier" reconciliation note).
##
## Coverage map (task spec -> test method):
##   1. Affix rolls deterministic with fixed seed
##      -> test_affix_rolls_deterministic_with_seed
##   2. T1/T2/T3 affix counts (per existing schema, NOT 1/2/3)
##      -> test_t1_t2_t3_affix_counts
##   3. Affix value falls within AffixValueRange for the rolled tier
##      -> test_affix_rolls_within_value_range
##   4. ADD mode: stat increases by `value` exactly
##      -> test_apply_affix_modifier_add_mode
##   5. MUL mode: stat scales by `(1 + value)` correctly
##      -> test_apply_affix_modifier_mul_mode
##   6. Equipping item applies all its affixes; unequipping reverses
##      -> test_equip_applies_all_affixes
##      -> test_unequip_reverses_all_affixes
##   7. Multiple items with overlapping affixes stack correctly
##      -> test_multiple_items_with_overlapping_affixes_stack
##   8. Edge: negative affix value (debuff future) handled
##      -> test_negative_affix_value_handled
##   9. Edge: equip same item twice -> only applies once
##      -> test_equip_same_instance_twice_idempotent
##   10. Edge: unequip item not currently equipped -> no-op
##      -> test_unequip_empty_slot_is_noop
##
## Plus: move_speed bonus on Player applies, unknown stat warns/ignores.

const LootRollerScript: Script = preload("res://scripts/loot/LootRoller.gd")
const AffixRollScript: Script = preload("res://scripts/loot/AffixRoll.gd")
const ItemInstanceScript: Script = preload("res://scripts/loot/ItemInstance.gd")
const PlayerScript: Script = preload("res://scripts/player/Player.gd")


# ---- Helpers ----------------------------------------------------------

func _ps() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("PlayerStats")
	assert_not_null(n, "PlayerStats autoload must be registered")
	return n


func _make_roller(seed: int = 42) -> LootRoller:
	var r: LootRoller = LootRollerScript.new()
	r.seed_rng(seed)
	return r


func _make_player() -> Player:
	var p: Player = PlayerScript.new()
	add_child_autofree(p)
	return p


# Build a vigor ADD affix matching the M1 vital ranges.
func _make_vital_affix() -> AffixDef:
	return ContentFactory.make_affix_def({
		"id": &"vital_t",
		"name": "of Vitality",
		"stat_modified": &"vigor",
		"apply_mode": AffixDef.ApplyMode.ADD,
		"value_ranges": [
			ContentFactory.make_affix_value_range(5.0, 15.0),   # T1
			ContentFactory.make_affix_value_range(15.0, 25.0),  # T2
			ContentFactory.make_affix_value_range(25.0, 40.0),  # T3
		],
	})


# Build an edge ADD affix matching the M1 keen ranges.
func _make_keen_affix() -> AffixDef:
	return ContentFactory.make_affix_def({
		"id": &"keen_t",
		"name": "Keen",
		"stat_modified": &"edge",
		"apply_mode": AffixDef.ApplyMode.ADD,
		"value_ranges": [
			ContentFactory.make_affix_value_range(1.0, 3.0),
			ContentFactory.make_affix_value_range(3.0, 6.0),
			ContentFactory.make_affix_value_range(6.0, 10.0),
		],
	})


# Build a move_speed ADD affix matching M1 swift.
func _make_swift_affix() -> AffixDef:
	return ContentFactory.make_affix_def({
		"id": &"swift_t",
		"name": "Swift",
		"stat_modified": &"move_speed",
		"apply_mode": AffixDef.ApplyMode.ADD,
		"value_ranges": [
			ContentFactory.make_affix_value_range(2.0, 5.0),
			ContentFactory.make_affix_value_range(5.0, 9.0),
			ContentFactory.make_affix_value_range(9.0, 14.0),
		],
	})


func before_each() -> void:
	_ps().reset()


func after_each() -> void:
	_ps().reset()


# =======================================================================
# 1. Affix rolls deterministic with fixed seed
# =======================================================================

func test_affix_rolls_deterministic_with_seed() -> void:
	var affix: AffixDef = _make_vital_affix()
	var r1: LootRoller = _make_roller(98765)
	var r2: LootRoller = _make_roller(98765)
	var values_a: Array[float] = []
	var values_b: Array[float] = []
	for _i in 50:
		values_a.append(r1.roll_affix(affix, ItemDef.Tier.T2).rolled_value)
		values_b.append(r2.roll_affix(affix, ItemDef.Tier.T2).rolled_value)
	assert_eq(values_a, values_b, "two rollers, same seed -> identical affix value sequences")


func test_affix_rolls_with_different_seeds_differ() -> void:
	# Sanity: determinism is from the seed, not a constant.
	var affix: AffixDef = _make_vital_affix()
	var r1: LootRoller = _make_roller(1111)
	var r2: LootRoller = _make_roller(2222)
	var seq1: Array[float] = []
	var seq2: Array[float] = []
	for _i in 50:
		seq1.append(r1.roll_affix(affix, ItemDef.Tier.T2).rolled_value)
		seq2.append(r2.roll_affix(affix, ItemDef.Tier.T2).rolled_value)
	assert_ne(seq1, seq2, "different seeds yield different affix value sequences")


# =======================================================================
# 2. T1/T2/T3 affix counts (per schema doc T1=0, T2=1, T3=1-2)
# =======================================================================

func test_t1_t2_t3_affix_counts() -> void:
	# Per `team/drew-dev/tres-schemas.md` § "Affix count by tier" and
	# `LootRoller.affix_count_for_tier`. The ticket sketched 1/2/3; we
	# honor the existing schema (T1=0/T2=1/T3=1or2) — see
	# `team/drew-dev/affix-application.md` for the reconciliation.
	var r: LootRoller = _make_roller(7)
	var pool: Array[AffixDef] = [_make_vital_affix(), _make_keen_affix(), _make_swift_affix()]

	# T1 -> 0 affixes
	var t1: ItemDef = ContentFactory.make_item_def({
		"tier": ItemDef.Tier.T1,
		"affix_pool": pool,
	})
	for _i in 10:
		var entry: LootEntry = ContentFactory.make_loot_entry(t1, 1.0, 0)
		var table: LootTableDef = ContentFactory.make_loot_table({"entries": [entry]})
		var drops: Array[ItemInstance] = r.roll(table)
		assert_eq(drops[0].rolled_affixes.size(), 0, "T1 rolls 0 affixes")

	# T2 -> exactly 1
	var t2: ItemDef = ContentFactory.make_item_def({
		"tier": ItemDef.Tier.T2,
		"affix_pool": pool,
	})
	for _i in 10:
		var entry: LootEntry = ContentFactory.make_loot_entry(t2, 1.0, 0)
		var table: LootTableDef = ContentFactory.make_loot_table({"entries": [entry]})
		var drops: Array[ItemInstance] = r.roll(table)
		assert_eq(drops[0].rolled_affixes.size(), 1, "T2 rolls exactly 1 affix")

	# T3 -> 1 or 2
	var t3: ItemDef = ContentFactory.make_item_def({
		"tier": ItemDef.Tier.T3,
		"affix_pool": pool,
	})
	for _i in 30:
		var entry: LootEntry = ContentFactory.make_loot_entry(t3, 1.0, 0)
		var table: LootTableDef = ContentFactory.make_loot_table({"entries": [entry]})
		var drops: Array[ItemInstance] = r.roll(table)
		var n: int = drops[0].rolled_affixes.size()
		assert_between(n, 1, 2, "T3 rolls 1 or 2 affixes")


# =======================================================================
# 3. Affix value falls within AffixValueRange for the rolled tier
# =======================================================================

func test_affix_rolls_within_value_range() -> void:
	var r: LootRoller = _make_roller(123)
	var vital: AffixDef = _make_vital_affix()
	var keen: AffixDef = _make_keen_affix()
	# 200 rolls per tier per affix — every roll lands inside the band.
	for _i in 200:
		var v_t1: float = r.roll_affix(vital, ItemDef.Tier.T1).rolled_value
		assert_between(v_t1, 5.0, 15.0, "vital T1 in [5,15]")
		var v_t2: float = r.roll_affix(vital, ItemDef.Tier.T2).rolled_value
		assert_between(v_t2, 15.0, 25.0, "vital T2 in [15,25]")
		var v_t3: float = r.roll_affix(vital, ItemDef.Tier.T3).rolled_value
		assert_between(v_t3, 25.0, 40.0, "vital T3 in [25,40]")
		var k_t1: float = r.roll_affix(keen, ItemDef.Tier.T1).rolled_value
		assert_between(k_t1, 1.0, 3.0, "keen T1 in [1,3]")


# =======================================================================
# 4. ADD mode: stat increases by `value` exactly
# =======================================================================

func test_apply_affix_modifier_add_mode() -> void:
	# Allocate base vigor 10. Apply ADD +7. Effective = 17.
	_ps().add_stat(&"vigor", 10)
	assert_eq(_ps().get_stat(&"vigor"), 10, "base vigor 10")
	_ps().apply_affix_modifier(&"vigor", 7.0, AffixDef.ApplyMode.ADD)
	assert_eq(_ps().get_stat(&"vigor"), 17, "ADD +7 on base 10 -> 17")
	# Base unchanged.
	assert_eq(_ps().get_base_stat(&"vigor"), 10, "base stat unchanged by modifier")
	# Reverse -> back to 10.
	_ps().clear_affix_modifier(&"vigor", 7.0, AffixDef.ApplyMode.ADD)
	assert_eq(_ps().get_stat(&"vigor"), 10, "clear ADD -> back to base")


func test_apply_add_mode_clamps_negative_to_zero() -> void:
	# Base vigor 3. Apply ADD -10 (debuff). Effective = max(0, 3 - 10) = 0.
	_ps().add_stat(&"vigor", 3)
	_ps().apply_affix_modifier(&"vigor", -10.0, AffixDef.ApplyMode.ADD)
	assert_eq(_ps().get_stat(&"vigor"), 0, "negative ADD clamps effective stat to 0")


# =======================================================================
# 5. MUL mode: stat scales by (1 + value)
# =======================================================================

func test_apply_affix_modifier_mul_mode() -> void:
	# Base edge 10. Apply MUL +0.20 -> effective = 10 * 1.20 = 12.
	_ps().add_stat(&"edge", 10)
	_ps().apply_affix_modifier(&"edge", 0.20, AffixDef.ApplyMode.MUL)
	assert_eq(_ps().get_stat(&"edge"), 12, "MUL +0.20 on base 10 -> 12")
	# Reverse.
	_ps().clear_affix_modifier(&"edge", 0.20, AffixDef.ApplyMode.MUL)
	assert_eq(_ps().get_stat(&"edge"), 10, "clear MUL -> back to base")


func test_mul_combines_with_add_correctly() -> void:
	# (base + add) * (1 + mul). 10 + 4 = 14, * 1.5 = 21.
	_ps().add_stat(&"edge", 10)
	_ps().apply_affix_modifier(&"edge", 4.0, AffixDef.ApplyMode.ADD)
	_ps().apply_affix_modifier(&"edge", 0.5, AffixDef.ApplyMode.MUL)
	assert_eq(_ps().get_stat(&"edge"), 21, "(10+4) * 1.5 = 21")


# =======================================================================
# 6. Equipping item applies all its affixes; unequipping reverses
# =======================================================================

func test_equip_applies_all_affixes() -> void:
	var p: Player = _make_player()
	# Build a T2 weapon with two affixes (vital + keen) at fixed values.
	var item: ItemDef = ContentFactory.make_item_def({
		"id": &"affix_test_sword",
		"slot": ItemDef.Slot.WEAPON,
		"tier": ItemDef.Tier.T2,
	})
	var instance: ItemInstance = ItemInstanceScript.new(item, ItemDef.Tier.T2)
	instance.rolled_affixes = [
		AffixRollScript.new(_make_vital_affix(), 12.0),  # +12 vigor
		AffixRollScript.new(_make_keen_affix(), 4.0),    # +4 edge
	]
	# Pre-equip baseline.
	assert_eq(_ps().get_stat(&"vigor"), 0)
	assert_eq(_ps().get_stat(&"edge"), 0)
	# Equip — both affixes apply.
	assert_true(p.equip_item(instance))
	assert_eq(_ps().get_stat(&"vigor"), 12, "vital affix +12 applied on equip")
	assert_eq(_ps().get_stat(&"edge"), 4, "keen affix +4 applied on equip")
	assert_eq(p.get_equipped_weapon(), item, "weapon ref mirrored to ItemDef pointer")


func test_unequip_reverses_all_affixes() -> void:
	var p: Player = _make_player()
	var item: ItemDef = ContentFactory.make_item_def({
		"slot": ItemDef.Slot.WEAPON, "tier": ItemDef.Tier.T2,
	})
	var instance: ItemInstance = ItemInstanceScript.new(item, ItemDef.Tier.T2)
	instance.rolled_affixes = [
		AffixRollScript.new(_make_vital_affix(), 12.0),
		AffixRollScript.new(_make_keen_affix(), 4.0),
	]
	p.equip_item(instance)
	assert_eq(_ps().get_stat(&"vigor"), 12)
	# Unequip -> both affixes reverse.
	var unequipped: ItemInstance = p.unequip_item(Player.SLOT_WEAPON)
	assert_eq(unequipped, instance, "unequip returns the unequipped instance")
	assert_eq(_ps().get_stat(&"vigor"), 0, "vigor returns to base after unequip")
	assert_eq(_ps().get_stat(&"edge"), 0, "edge returns to base after unequip")
	assert_null(p.get_equipped_weapon(), "weapon ref cleared after unequip")


func test_equip_replaces_previous_in_same_slot() -> void:
	var p: Player = _make_player()
	# First weapon: +10 vigor.
	var item_a: ItemDef = ContentFactory.make_item_def({
		"id": &"sword_a", "slot": ItemDef.Slot.WEAPON, "tier": ItemDef.Tier.T2,
	})
	var inst_a: ItemInstance = ItemInstanceScript.new(item_a, ItemDef.Tier.T2)
	inst_a.rolled_affixes = [AffixRollScript.new(_make_vital_affix(), 10.0)]
	p.equip_item(inst_a)
	assert_eq(_ps().get_stat(&"vigor"), 10, "first weapon +10 vigor applied")
	# Second weapon: +5 edge. Replaces the first in the weapon slot.
	var item_b: ItemDef = ContentFactory.make_item_def({
		"id": &"sword_b", "slot": ItemDef.Slot.WEAPON, "tier": ItemDef.Tier.T2,
	})
	var inst_b: ItemInstance = ItemInstanceScript.new(item_b, ItemDef.Tier.T2)
	inst_b.rolled_affixes = [AffixRollScript.new(_make_keen_affix(), 5.0)]
	p.equip_item(inst_b)
	assert_eq(_ps().get_stat(&"vigor"), 0, "first weapon's vigor reversed on swap")
	assert_eq(_ps().get_stat(&"edge"), 5, "second weapon's edge applied on swap")
	assert_eq(p.get_equipped_item(Player.SLOT_WEAPON), inst_b)


# =======================================================================
# 7. Multiple items with overlapping affixes stack correctly
# =======================================================================

func test_multiple_items_with_overlapping_affixes_stack() -> void:
	var p: Player = _make_player()
	# Weapon: +10 vigor. Armor: +8 vigor. Total +18.
	var weapon: ItemDef = ContentFactory.make_item_def({
		"id": &"sword", "slot": ItemDef.Slot.WEAPON, "tier": ItemDef.Tier.T2,
	})
	var armor: ItemDef = ContentFactory.make_item_def({
		"id": &"vest", "slot": ItemDef.Slot.ARMOR, "tier": ItemDef.Tier.T2,
	})
	var inst_weapon: ItemInstance = ItemInstanceScript.new(weapon, ItemDef.Tier.T2)
	inst_weapon.rolled_affixes = [AffixRollScript.new(_make_vital_affix(), 10.0)]
	var inst_armor: ItemInstance = ItemInstanceScript.new(armor, ItemDef.Tier.T2)
	inst_armor.rolled_affixes = [AffixRollScript.new(_make_vital_affix(), 8.0)]
	p.equip_item(inst_weapon)
	p.equip_item(inst_armor)
	assert_eq(_ps().get_stat(&"vigor"), 18, "weapon +10 + armor +8 -> +18 vigor")
	# Unequip weapon -> back to 8.
	p.unequip_item(Player.SLOT_WEAPON)
	assert_eq(_ps().get_stat(&"vigor"), 8, "armor still contributes +8 vigor")
	# Unequip armor -> 0.
	p.unequip_item(Player.SLOT_ARMOR)
	assert_eq(_ps().get_stat(&"vigor"), 0, "all sources removed -> 0 vigor")


# =======================================================================
# 8. Edge: negative affix value (debuff future) handled
# =======================================================================

func test_negative_affix_value_handled() -> void:
	# Apply a -5 vigor affix (a future debuff). Then a +12 affix.
	# Result: max(0, 0 + (-5) + 12) = 7.
	_ps().apply_affix_modifier(&"vigor", -5.0, AffixDef.ApplyMode.ADD)
	_ps().apply_affix_modifier(&"vigor", 12.0, AffixDef.ApplyMode.ADD)
	assert_eq(_ps().get_stat(&"vigor"), 7, "negative + positive ADD modifiers stack")
	# Reverse just the positive — back to the debuff.
	_ps().clear_affix_modifier(&"vigor", 12.0, AffixDef.ApplyMode.ADD)
	assert_eq(_ps().get_stat(&"vigor"), 0, "max(0, 0-5) clamps to 0")


# =======================================================================
# 9. Edge: equip same item twice -> only applies once
# =======================================================================

func test_equip_same_instance_twice_idempotent() -> void:
	var p: Player = _make_player()
	var item: ItemDef = ContentFactory.make_item_def({
		"slot": ItemDef.Slot.WEAPON, "tier": ItemDef.Tier.T2,
	})
	var instance: ItemInstance = ItemInstanceScript.new(item, ItemDef.Tier.T2)
	instance.rolled_affixes = [AffixRollScript.new(_make_keen_affix(), 5.0)]
	# Equip once -> +5 edge.
	p.equip_item(instance)
	assert_eq(_ps().get_stat(&"edge"), 5)
	# Equip same instance again -> still +5, NOT +10.
	p.equip_item(instance)
	assert_eq(_ps().get_stat(&"edge"), 5,
		"re-equipping the same instance is a no-op (no double-apply)")


# =======================================================================
# 10. Edge: unequip item not currently equipped -> no-op
# =======================================================================

func test_unequip_empty_slot_is_noop() -> void:
	var p: Player = _make_player()
	# Nothing equipped — unequip returns null and doesn't crash.
	var result: ItemInstance = p.unequip_item(Player.SLOT_WEAPON)
	assert_null(result, "unequipping an empty slot returns null")
	assert_eq(_ps().get_stat(&"vigor"), 0, "no stat side-effects from no-op unequip")
	# After equip-then-unequip, second unequip is also a no-op.
	var item: ItemDef = ContentFactory.make_item_def({
		"slot": ItemDef.Slot.WEAPON, "tier": ItemDef.Tier.T2,
	})
	var instance: ItemInstance = ItemInstanceScript.new(item, ItemDef.Tier.T2)
	instance.rolled_affixes = [AffixRollScript.new(_make_keen_affix(), 3.0)]
	p.equip_item(instance)
	p.unequip_item(Player.SLOT_WEAPON)
	assert_eq(_ps().get_stat(&"edge"), 0)
	assert_null(p.unequip_item(Player.SLOT_WEAPON), "second unequip is no-op")


# =======================================================================
# Bonus: move_speed affix flows to Player._move_speed_bonus
# =======================================================================

func test_swift_affix_increases_walk_speed() -> void:
	var p: Player = _make_player()
	var base: float = p.get_walk_speed()
	assert_eq(base, Player.WALK_SPEED, "no affix -> walk_speed == WALK_SPEED")
	var item: ItemDef = ContentFactory.make_item_def({
		"slot": ItemDef.Slot.WEAPON, "tier": ItemDef.Tier.T1,
	})
	var instance: ItemInstance = ItemInstanceScript.new(item, ItemDef.Tier.T1)
	instance.rolled_affixes = [AffixRollScript.new(_make_swift_affix(), 4.0)]
	p.equip_item(instance)
	assert_almost_eq(p.get_walk_speed(), Player.WALK_SPEED + 4.0, 0.001,
		"swift +4 -> walk_speed += 4")
	p.unequip_item(Player.SLOT_WEAPON)
	assert_almost_eq(p.get_walk_speed(), Player.WALK_SPEED, 0.001,
		"unequip reverses move_speed bonus")


# =======================================================================
# Bonus: AffixRoll.apply_to math (ADD vs MUL on a base scalar)
# =======================================================================

func test_affix_roll_apply_to_math() -> void:
	var add_affix: AffixDef = ContentFactory.make_affix_def({
		"apply_mode": AffixDef.ApplyMode.ADD,
	})
	var add_roll: AffixRoll = AffixRollScript.new(add_affix, 12.0)
	assert_almost_eq(add_roll.apply_to(50.0), 62.0, 0.001, "ADD: 50 + 12 = 62")

	var mul_affix: AffixDef = ContentFactory.make_affix_def({
		"apply_mode": AffixDef.ApplyMode.MUL,
	})
	var mul_roll: AffixRoll = AffixRollScript.new(mul_affix, 0.10)
	assert_almost_eq(mul_roll.apply_to(100.0), 110.0, 0.001, "MUL: 100*(1+0.10) = 110")


# =======================================================================
# Bonus: authored TRES affixes use M1 stats (vigor/edge/move_speed)
# =======================================================================

func test_authored_swift_affix_uses_move_speed() -> void:
	var swift: AffixDef = load("res://resources/affixes/swift.tres") as AffixDef
	assert_not_null(swift, "swift.tres loads as AffixDef")
	assert_eq(swift.stat_modified, &"move_speed",
		"swift affix targets move_speed (M1 task spec)")
	assert_eq(swift.apply_mode, AffixDef.ApplyMode.ADD, "swift is ADD mode")
	assert_eq(swift.value_ranges.size(), 3, "swift has T1/T2/T3 ranges")


func test_authored_vital_affix_uses_vigor() -> void:
	var vital: AffixDef = load("res://resources/affixes/vital.tres") as AffixDef
	assert_not_null(vital)
	assert_eq(vital.stat_modified, &"vigor",
		"vital affix targets vigor (M1 task spec)")
	assert_eq(vital.apply_mode, AffixDef.ApplyMode.ADD)


func test_authored_keen_affix_uses_edge() -> void:
	var keen: AffixDef = load("res://resources/affixes/keen.tres") as AffixDef
	assert_not_null(keen)
	assert_eq(keen.stat_modified, &"edge",
		"keen affix targets edge (M1 task spec)")
	assert_eq(keen.apply_mode, AffixDef.ApplyMode.ADD)


# =======================================================================
# Bonus: PlayerStats unknown stat warns, returns 0
# =======================================================================

func test_apply_affix_to_unknown_stat_is_rejected() -> void:
	var ok: bool = _ps().apply_affix_modifier(&"bogus_stat", 10.0, AffixDef.ApplyMode.ADD)
	assert_false(ok, "unknown stat ID rejected with false")


# =======================================================================
# Bonus: hover-display lines (Uma's mockup data hookup)
# =======================================================================

func test_item_instance_exposes_affix_display_lines() -> void:
	var item: ItemDef = ContentFactory.make_item_def({
		"slot": ItemDef.Slot.WEAPON, "tier": ItemDef.Tier.T2,
	})
	var instance: ItemInstance = ItemInstanceScript.new(item, ItemDef.Tier.T2)
	instance.rolled_affixes = [
		AffixRollScript.new(_make_vital_affix(), 12.0),
		AffixRollScript.new(_make_keen_affix(), 5.0),
	]
	var lines: Array[String] = instance.get_affix_display_lines()
	assert_eq(lines.size(), 2)
	# The vital affix line should mention "+12" and "vigor".
	assert_string_contains(lines[0], "12")
	assert_string_contains(lines[0], "vigor")
	# The keen affix line should mention "+5" and "edge".
	assert_string_contains(lines[1], "5")
	assert_string_contains(lines[1], "edge")
