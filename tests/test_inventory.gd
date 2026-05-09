extends GutTest
## Tests for the Inventory autoload (carried items + equipped slots,
## save round-trip, M1 death rule).
##
## Per Devon run-007 dispatch:
##   1. Empty inventory at fresh start.
##   2. add(item) increments count, item visible at index 0.
##   3. equip(item, "weapon") equips and removes from inventory grid.
##   4. unequip(slot) returns item to inventory.
##   5. equip same item twice -> second is no-op.
##   6. Inventory respects 8x3 = 24 capacity (overflow rejected with warning).
##   7. Save round-trip preserves inventory + equipped state.
##   8. M1 death rule: clear unequipped on death; preserve equipped + level.

const TEST_SLOT: int = 985


func _inv() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("Inventory")
	assert_not_null(n, "Inventory autoload must be registered in project.godot")
	return n


func _save() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("Save")
	assert_not_null(n, "Save autoload must be registered")
	return n


func _make_weapon_item(id: StringName = &"test_weapon") -> ItemInstance:
	var def: ItemDef = ContentFactory.make_item_def({"id": id, "slot": ItemDef.Slot.WEAPON})
	return ItemInstance.new(def, ItemDef.Tier.T1)


func _make_armor_item(id: StringName = &"test_armor") -> ItemInstance:
	var def: ItemDef = ContentFactory.make_item_def({
		"id": id,
		"slot": ItemDef.Slot.ARMOR,
		"base_stats": ContentFactory.make_item_base_stats({"armor": 4}),
	})
	return ItemInstance.new(def, ItemDef.Tier.T1)


func before_each() -> void:
	_inv().reset()
	if _save().has_save(TEST_SLOT):
		_save().delete_save(TEST_SLOT)


func after_each() -> void:
	_inv().reset()
	if _save().has_save(TEST_SLOT):
		_save().delete_save(TEST_SLOT)


# =======================================================================
# Test 1 — Empty inventory at fresh start
# =======================================================================

func test_empty_at_fresh_start() -> void:
	assert_eq(_inv().get_items().size(), 0, "no carried items at start")
	assert_false(_inv().is_full(), "fresh inventory not full")
	assert_eq(_inv().get_capacity(), 24, "capacity is 24 = 8x3")
	assert_null(_inv().get_equipped(&"weapon"), "weapon slot empty")
	assert_null(_inv().get_equipped(&"armor"), "armor slot empty")


# =======================================================================
# Test 2 — add(item) increments count, visible at index 0
# =======================================================================

func test_add_increments_and_visible_at_index_0() -> void:
	var item: ItemInstance = _make_weapon_item()
	watch_signals(_inv())
	assert_true(_inv().add(item), "add returns true on success")
	assert_eq(_inv().get_items().size(), 1, "count is 1 after add")
	assert_eq(_inv().get_items()[0], item, "item at index 0")
	assert_signal_emitted(_inv(), "item_added")
	assert_signal_emitted(_inv(), "inventory_changed")


# =======================================================================
# Test 3 — equip(item, "weapon") equips and removes from grid
# =======================================================================

func test_equip_moves_from_inventory_to_slot() -> void:
	var item: ItemInstance = _make_weapon_item()
	_inv().add(item)
	watch_signals(_inv())
	assert_true(_inv().equip(item, &"weapon"), "equip succeeds")
	assert_eq(_inv().get_items().size(), 0, "item removed from inventory grid")
	assert_eq(_inv().get_equipped(&"weapon"), item, "item now in weapon slot")
	assert_signal_emitted(_inv(), "item_equipped")


# =======================================================================
# Test 4 — unequip(slot) returns item to inventory
# =======================================================================

func test_unequip_returns_item_to_inventory() -> void:
	var item: ItemInstance = _make_weapon_item()
	_inv().add(item)
	_inv().equip(item, &"weapon")
	watch_signals(_inv())
	var unequipped: ItemInstance = _inv().unequip(&"weapon")
	assert_eq(unequipped, item, "unequip returns the unequipped item")
	assert_eq(_inv().get_items().size(), 1, "item back in inventory")
	assert_eq(_inv().get_items()[0], item, "item at first empty slot")
	assert_null(_inv().get_equipped(&"weapon"), "weapon slot now empty")
	assert_signal_emitted(_inv(), "item_unequipped")


# =======================================================================
# Test 5 — equipping the same item twice -> second is no-op
# =======================================================================

func test_equip_same_item_twice_is_noop() -> void:
	var item: ItemInstance = _make_weapon_item()
	_inv().add(item)
	assert_true(_inv().equip(item, &"weapon"))
	# Second call: item is no longer in inventory (it's in the slot), so
	# equip should reject. But even if it weren't, the same-instance idempotency
	# rule handles it.
	assert_false(_inv().equip(item, &"weapon"),
		"second equip of the same instance is a no-op")
	# Slot still occupied with the same item.
	assert_eq(_inv().get_equipped(&"weapon"), item,
		"slot still has the original item after no-op")


# =======================================================================
# Test 6 — Capacity respected, overflow rejected with warning
# =======================================================================

func test_capacity_overflow_rejected() -> void:
	for i in 24:
		var it: ItemInstance = _make_weapon_item(StringName("item_%d" % i))
		assert_true(_inv().add(it), "fill slot %d" % i)
	assert_true(_inv().is_full(), "inventory full at 24")
	# 25th add should be rejected.
	var overflow: ItemInstance = _make_weapon_item(&"overflow")
	watch_signals(_inv())
	assert_false(_inv().add(overflow), "add past capacity returns false")
	assert_eq(_inv().get_items().size(), 24, "size still 24, overflow not stored")
	assert_signal_emitted(_inv(), "add_rejected")


# =======================================================================
# Test 7 — Save round-trip preserves inventory + equipped state
# =======================================================================

func test_save_round_trip_preserves_state() -> void:
	var weapon: ItemInstance = _make_weapon_item(&"sword_a")
	var armor: ItemInstance = _make_armor_item(&"hide_a")
	var backup: ItemInstance = _make_weapon_item(&"sword_b")
	_inv().add(weapon)
	_inv().add(armor)
	_inv().add(backup)
	_inv().equip(weapon, &"weapon")
	_inv().equip(armor, &"armor")

	# Snapshot to a save dict.
	var data: Dictionary = _save().default_payload()
	_inv().snapshot_to_save(data)
	# Verify the dict shape Drew authored.
	assert_true(data["stash"] is Array)
	assert_true(data["equipped"] is Dictionary)
	assert_eq(data["stash"].size(), 1, "one unequipped item in stash")
	assert_true(data["equipped"].has("weapon"), "weapon slot in equipped")
	assert_true(data["equipped"].has("armor"), "armor slot in equipped")

	# Persist + reload via Save autoload to exercise full atomic_write path.
	_save().save_game(TEST_SLOT, data)
	var reloaded: Dictionary = _save().load_game(TEST_SLOT)
	# Resolvers map id -> Resource.
	var by_id: Dictionary = {
		StringName(weapon.def.id): weapon.def,
		StringName(armor.def.id): armor.def,
		StringName(backup.def.id): backup.def,
	}
	var item_resolver: Callable = func(id: StringName) -> Resource:
		return by_id.get(id, null)
	var affix_resolver: Callable = func(_id: StringName) -> Resource:
		return null
	# Reset Inventory then restore from the reloaded save.
	_inv().reset()
	_inv().restore_from_save(reloaded, item_resolver, affix_resolver)
	assert_eq(_inv().get_items().size(), 1, "1 unequipped item restored")
	assert_eq((_inv().get_items()[0] as ItemInstance).def.id, backup.def.id,
		"backup sword restored to inventory")
	assert_eq((_inv().get_equipped(&"weapon") as ItemInstance).def.id, weapon.def.id,
		"weapon equipped state preserved")
	assert_eq((_inv().get_equipped(&"armor") as ItemInstance).def.id, armor.def.id,
		"armor equipped state preserved")


# =======================================================================
# Test 8 — M1 death rule: clear_unequipped wipes inventory but keeps slots
# =======================================================================

func test_m1_death_rule_clears_unequipped_only() -> void:
	var weapon: ItemInstance = _make_weapon_item(&"sword_x")
	var dropped_a: ItemInstance = _make_weapon_item(&"sword_y")
	var dropped_b: ItemInstance = _make_armor_item(&"hide_y")
	_inv().add(weapon)
	_inv().add(dropped_a)
	_inv().add(dropped_b)
	_inv().equip(weapon, &"weapon")
	# Pre-condition: 2 items in inventory, 1 equipped.
	assert_eq(_inv().get_items().size(), 2)
	assert_eq(_inv().get_equipped(&"weapon"), weapon)
	# Death.
	_inv().clear_unequipped()
	# Inventory wiped; equipped preserved.
	assert_eq(_inv().get_items().size(), 0, "unequipped cleared on death")
	assert_eq(_inv().get_equipped(&"weapon"), weapon,
		"equipped weapon preserved through death (M1 rule)")


# =======================================================================
# Bonus probe — non-M1 slots are non-interactive (defensive)
# =======================================================================

func test_off_hand_slot_rejected_in_m1() -> void:
	var item: ItemInstance = _make_weapon_item()
	_inv().add(item)
	# off_hand is locked in M1 — equip must reject.
	assert_false(_inv().equip(item, &"off_hand"), "off-hand locked in M1")
	assert_eq(_inv().get_items().size(), 1, "item still in inventory after rejection")


# =======================================================================
# Test 9 — Equip-swap preserves the previously-equipped item (P0 86c9q96m8)
# =======================================================================
#
# Sponsor M1 RC re-soak attempt 5: pick up a sword in Room 02, click to
# equip; new sword "disappears from grid but is NOT actually equipped"
# (re-clicking does nothing). Root cause class: the swap path was passing
# `push_back_to_inventory=false` to `_unequip_internal`, silently leaking
# the previously-equipped item. Pre-fix: after a swap, both swords were
# gone from the visible grid AND from `_equipped`. Post-fix: the old
# weapon lands in the grid where the new weapon used to be.
#
# This test must pass with either order of operations as long as the
# load-bearing invariant holds: NO item is silently lost on swap.

func test_equip_swap_preserves_previously_equipped_item() -> void:
	# Pre-equip sword A.
	var sword_a: ItemInstance = _make_weapon_item(&"sword_a_swap")
	_inv().add(sword_a)
	assert_true(_inv().equip(sword_a, &"weapon"), "precondition: sword A equipped")
	assert_eq(_inv().get_equipped(&"weapon"), sword_a)
	assert_eq(_inv().get_items().size(), 0, "grid empty after first equip")

	# Pick up sword B (loot from a kill, etc.).
	var sword_b: ItemInstance = _make_weapon_item(&"sword_b_swap")
	_inv().add(sword_b)
	assert_eq(_inv().get_items().size(), 1, "grid has sword B after pickup")

	# Now swap: equip sword B. Sword A must end up in the grid, NOT lost.
	watch_signals(_inv())
	assert_true(_inv().equip(sword_b, &"weapon"), "swap equip succeeds")
	assert_eq(_inv().get_equipped(&"weapon"), sword_b,
		"sword B is now equipped")
	assert_eq(_inv().get_items().size(), 1,
		"grid still has 1 item (sword A pushed back from equipped slot)")
	assert_eq(_inv().get_items()[0], sword_a,
		"the item in the grid is the previously-equipped sword A — equip-swap " +
		"P0 86c9q96m8 fix: pre-fix this assertion failed because sword A " +
		"was silently dropped on the floor by _unequip_internal(slot, false)")
	# Both sides of the swap must be observable via signals.
	assert_signal_emitted(_inv(), "item_unequipped")
	assert_signal_emitted(_inv(), "item_equipped")


func test_equip_swap_with_full_grid_preserves_item() -> void:
	# Edge case: the grid is FULL (24 items including the new weapon).
	# When the player swaps, the previously-equipped item must STILL land
	# back in the grid because we erase the new item first (freeing a slot).
	# Pre-fix this would fail because _unequip_internal(slot, true) would
	# refuse the push_back when the grid was at capacity AT THE TIME of the
	# unequip call. Post-fix: _items.erase(item) runs first, freeing 1 slot.
	var equipped_weapon: ItemInstance = _make_weapon_item(&"equipped_full")
	_inv().add(equipped_weapon)
	assert_true(_inv().equip(equipped_weapon, &"weapon"))
	# Fill grid to capacity (24 items).
	for i in 24:
		var it: ItemInstance = _make_weapon_item(StringName("filler_%d" % i))
		assert_true(_inv().add(it), "grid fill slot %d" % i)
	assert_true(_inv().is_full(), "grid is full at 24")
	# Pick the last filler as the swap target.
	var new_weapon: ItemInstance = _inv().get_items()[23] as ItemInstance
	assert_true(_inv().equip(new_weapon, &"weapon"),
		"swap equip from a full grid must succeed (new item erased first frees a slot)")
	# Old weapon now in grid where the new weapon was.
	assert_eq(_inv().get_equipped(&"weapon"), new_weapon,
		"new_weapon now equipped")
	assert_eq(_inv().get_items().size(), 24,
		"grid still at 24 — new item slot is now occupied by previously-equipped weapon")
	assert_true(_inv().get_items().has(equipped_weapon),
		"previously-equipped weapon lands back in the grid even when full at swap time")
	assert_false(_inv().get_items().has(new_weapon),
		"new weapon no longer in grid (it's equipped)")


# =======================================================================
# Test 10 — Equip-swap drives BOTH surfaces of the dual-surface rule
# (real Player instance — paired test per combat-architecture.md
# §"Equipped-weapon dual-surface rule" Tier 1)
# =======================================================================

func test_equip_swap_updates_both_inventory_and_player_surfaces() -> void:
	# Per combat-architecture.md "Equipped-weapon dual-surface rule":
	# equipped state lives on Inventory._equipped["weapon"] AND
	# Player._equipped_weapon. Both MUST stay in lockstep across an
	# equip-swap, OR the symptom is "Tab UI shows weapon X but combat
	# uses weapon Y" (Sponsor's M1 RC re-soak attempt 5 pattern).
	#
	# Tier 1 (mandatory) test bar: paired tests for equip / unequip /
	# equip-swap MUST instantiate a real Player node (NOT a stub Node)
	# because `_apply_equip_to_player(target)` checks
	# `target.has_method("equip_item")` — a stub Node returns false and
	# silently skips the Player surface. PR #145's stub-Node test was
	# the original cautionary tale.
	var PlayerScript: Script = preload("res://scripts/player/Player.gd")
	var player: Player = PlayerScript.new()
	add_child_autofree(player)
	# Player._ready adds it to the "player" group; _find_player picks it up.

	# Build sword A with a known damage stat via ContentFactory so we can
	# distinguish it from sword B in the Player surface check.
	var sword_a_def: ItemDef = ContentFactory.make_item_def({
		"id": &"sword_a_dual",
		"slot": ItemDef.Slot.WEAPON,
		"base_stats": ContentFactory.make_item_base_stats({"damage": 4}),
	})
	var sword_a: ItemInstance = ItemInstance.new(sword_a_def, ItemDef.Tier.T1)
	var sword_b_def: ItemDef = ContentFactory.make_item_def({
		"id": &"sword_b_dual",
		"slot": ItemDef.Slot.WEAPON,
		"base_stats": ContentFactory.make_item_base_stats({"damage": 9}),
	})
	var sword_b: ItemInstance = ItemInstance.new(sword_b_def, ItemDef.Tier.T1)

	# Equip sword A first.
	_inv().add(sword_a)
	assert_true(_inv().equip(sword_a, &"weapon"))
	# BOTH surfaces post-equip-A:
	assert_eq((_inv().get_equipped(&"weapon") as ItemInstance).def.id, &"sword_a_dual",
		"Inventory surface: sword A in weapon slot")
	assert_eq((player.get_equipped_weapon() as ItemDef).id, &"sword_a_dual",
		"Player surface: _equipped_weapon points to sword A — dual-surface invariant")

	# Now swap to sword B (the failure case from Sponsor soak attempt 5).
	_inv().add(sword_b)
	assert_true(_inv().equip(sword_b, &"weapon"), "swap equip succeeds")

	# BOTH surfaces post-swap MUST point to sword B (NOT sword A) — this is
	# the load-bearing dual-surface invariant. Pre-fix to P0 86c9q96m8: the
	# equip-swap path could leak surfaces (one updated, one stale), producing
	# Sponsor's "subsequent swings still register the previous weapon's
	# damage" symptom.
	assert_eq((_inv().get_equipped(&"weapon") as ItemInstance).def.id, &"sword_b_dual",
		"Inventory surface: sword B in weapon slot post-swap")
	assert_eq((player.get_equipped_weapon() as ItemDef).id, &"sword_b_dual",
		"Player surface: _equipped_weapon points to sword B post-swap (the bug class — " +
		"if this fails, Inventory updated but Player.equip_item didn't fire / Player " +
		"didn't hear the swap; Sponsor would see: grid empties, but swing damage stays " +
		"the OLD weapon's value)")

	# Sword A must be back in the grid (not lost on swap — equip-swap leak fix).
	assert_eq(_inv().get_items().size(), 1, "grid has 1 item post-swap")
	assert_eq((_inv().get_items()[0] as ItemInstance).def.id, &"sword_a_dual",
		"sword A pushed back to grid on swap (equip-swap leak fix — pre-fix this was lost)")
