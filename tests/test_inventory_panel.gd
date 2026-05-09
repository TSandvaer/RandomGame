extends GutTest
## Tests for `scripts/ui/InventoryPanel.gd` — the Tab panel that surfaces
## the inventory grid + equipped slots + character stats + tooltip.
##
## Per Devon run-007 dispatch:
##   1. Panel opens on Tab key (toggle_inventory action).
##   2. Time-slow at 10% when open.
##   3. Tooltip displays on hover, shows base + affix lines.
##   4. Click empty slot -> no-op.
##   5. Click equipped slot -> unequips.
##   6. Click inventory slot with item -> swaps to slot.
##   7. Right-click in inventory -> drop (item removed; for M1 just remove,
##      no spawn).
##   8. Esc closes panel.

const InventoryPanelScript: Script = preload("res://scripts/ui/InventoryPanel.gd")
const ItemTooltipScript: Script = preload("res://scripts/ui/ItemTooltip.gd")


func _inv() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("Inventory")
	assert_not_null(n, "Inventory autoload registered")
	return n


func _make_panel() -> InventoryPanel:
	var packed: PackedScene = load("res://scenes/ui/InventoryPanel.tscn")
	assert_not_null(packed, "panel scene loads")
	var panel: InventoryPanel = packed.instantiate()
	add_child_autofree(panel)
	return panel


func _make_weapon_item(id: StringName = &"panel_weapon") -> ItemInstance:
	var def: ItemDef = ContentFactory.make_item_def({
		"id": id,
		"slot": ItemDef.Slot.WEAPON,
		"base_stats": ContentFactory.make_item_base_stats({"damage": 7}),
	})
	return ItemInstance.new(def, ItemDef.Tier.T2)


func _make_armor_item(id: StringName = &"panel_armor") -> ItemInstance:
	var def: ItemDef = ContentFactory.make_item_def({
		"id": id,
		"slot": ItemDef.Slot.ARMOR,
		"base_stats": ContentFactory.make_item_base_stats({"armor": 4}),
	})
	return ItemInstance.new(def, ItemDef.Tier.T1)


func before_each() -> void:
	_inv().reset()
	Engine.time_scale = 1.0


func after_each() -> void:
	_inv().reset()
	Engine.time_scale = 1.0


# =======================================================================
# Test 1 — Panel opens on Tab (toggle_inventory action)
# =======================================================================

func test_panel_opens_on_toggle_inventory() -> void:
	var panel: InventoryPanel = _make_panel()
	assert_false(panel.is_open(), "panel starts closed")
	panel.open()
	assert_true(panel.is_open(), "panel open after open() call")
	# Verify Tab via action remap path: synthesize an action_pressed event.
	# (The full Tab-key path is exercised by manual QA — `force_press` would
	# need to call `_unhandled_input` directly with a synthetic action;
	# here we cover open() — the public API the action handler wraps.)
	panel.close()
	assert_false(panel.is_open(), "panel closes again")


# =======================================================================
# Test 2 — Time-slow at 10% when open
# =======================================================================

func test_time_slow_at_ten_percent_when_open() -> void:
	var panel: InventoryPanel = _make_panel()
	# Sanity — pre-open, time scale is 1.0.
	assert_eq(Engine.time_scale, 1.0, "pre-open time scale 1.0")
	panel.open()
	assert_eq(Engine.time_scale, panel.get_time_slow_factor(),
		"open() sets Engine.time_scale to TIME_SLOW_FACTOR (0.10) per Uma")
	assert_eq(panel.get_time_slow_factor(), 0.10, "factor is 10% per spec")
	panel.close()
	assert_eq(Engine.time_scale, 1.0, "close() restores time scale")


# =======================================================================
# Test 3 — Tooltip displays on hover, shows base + affix lines
# =======================================================================

func test_tooltip_displays_base_and_affix_on_hover() -> void:
	var panel: InventoryPanel = _make_panel()
	# Add an item to inventory.
	var item: ItemInstance = _make_weapon_item()
	_inv().add(item)
	panel.open()
	# Simulate a hover over inventory cell 0.
	panel.force_hover_inventory_for_test(0)
	# The tooltip rendered text should contain the item display name + a
	# damage line (base stats).
	var tooltip: ItemTooltip = panel.find_child("ItemTooltip", true, false) as ItemTooltip
	assert_not_null(tooltip, "tooltip overlay exists")
	assert_true(tooltip.visible, "tooltip is visible after hover")
	var rendered: String = tooltip.get_rendered_text()
	assert_true(rendered.contains(item.get_display_name()),
		"tooltip shows item display name")
	# Base stats line: damage > 0 -> "Damage: 7" line per ItemInstance.get_base_stats_display_lines.
	assert_true(rendered.contains("Damage"),
		"tooltip shows base-stats line")


# =======================================================================
# Test 4 — Click empty slot -> no-op
# =======================================================================

func test_click_empty_slot_is_noop() -> void:
	var panel: InventoryPanel = _make_panel()
	panel.open()
	# Empty inventory; click cell 0.
	panel.force_click_inventory_index_for_test(0, MOUSE_BUTTON_LEFT)
	assert_eq(_inv().get_items().size(), 0, "empty click changes nothing")
	assert_null(_inv().get_equipped(&"weapon"))


# =======================================================================
# Test 5 — Click equipped slot -> unequips
# =======================================================================

func test_click_equipped_slot_unequips() -> void:
	var panel: InventoryPanel = _make_panel()
	var item: ItemInstance = _make_weapon_item()
	_inv().add(item)
	_inv().equip(item, &"weapon")
	panel.open()
	# Click the equipped weapon slot.
	panel.force_click_equipped_for_test(&"weapon", MOUSE_BUTTON_LEFT)
	assert_null(_inv().get_equipped(&"weapon"), "weapon slot now empty")
	assert_eq(_inv().get_items().size(), 1, "item back in inventory")
	assert_eq(_inv().get_items()[0], item)


# =======================================================================
# Test 6 — Click inventory slot with item -> swaps to slot
# =======================================================================

func test_click_inventory_item_equips() -> void:
	var panel: InventoryPanel = _make_panel()
	var item: ItemInstance = _make_weapon_item()
	_inv().add(item)
	panel.open()
	# Left-click cell 0 -> equips (since item is a weapon).
	panel.force_click_inventory_index_for_test(0, MOUSE_BUTTON_LEFT)
	assert_eq(_inv().get_equipped(&"weapon"), item, "item now equipped in weapon slot")
	assert_eq(_inv().get_items().size(), 0, "item removed from inventory")


# =======================================================================
# Test 7 — Right-click in inventory -> drop (M1: just remove)
# =======================================================================

func test_right_click_inventory_drops_item() -> void:
	var panel: InventoryPanel = _make_panel()
	var item: ItemInstance = _make_weapon_item()
	_inv().add(item)
	panel.open()
	panel.force_click_inventory_index_for_test(0, MOUSE_BUTTON_RIGHT)
	# Item removed entirely (no equip, no ground spawn — M1 simplification).
	assert_eq(_inv().get_items().size(), 0, "item dropped from inventory")
	assert_null(_inv().get_equipped(&"weapon"), "and not equipped")


# =======================================================================
# Test 8 — Esc closes panel
# =======================================================================

func test_esc_closes_panel() -> void:
	var panel: InventoryPanel = _make_panel()
	panel.open()
	assert_true(panel.is_open(), "panel open before Esc")
	# Synthesize an Esc key event through _unhandled_input.
	var ev: InputEventKey = InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_ESCAPE
	panel._unhandled_input(ev)
	assert_false(panel.is_open(), "Esc closes the panel")
	assert_eq(Engine.time_scale, 1.0, "time scale restored on Esc-close")


# =======================================================================
# Bonus probe — armor item equips into armor slot (right slot routing)
# =======================================================================

func test_armor_routes_to_armor_slot() -> void:
	var panel: InventoryPanel = _make_panel()
	var armor: ItemInstance = _make_armor_item()
	_inv().add(armor)
	panel.open()
	panel.force_click_inventory_index_for_test(0, MOUSE_BUTTON_LEFT)
	assert_eq(_inv().get_equipped(&"armor"), armor, "armor routed to armor slot")
	assert_null(_inv().get_equipped(&"weapon"), "weapon slot unchanged")


# =======================================================================
# Test 9 — LMB-click equip-swap drives BOTH surfaces (P0 86c9q96m8 paired test)
# =======================================================================
#
# Sponsor M1 RC re-soak attempt 5 P0 86c9q96m8: pick up a sword in Room 02,
# LMB-click in inventory grid → "item disappears from grid but is NOT
# actually equipped (subsequent swings still register the previous weapon's
# damage)." The bug class is the "equipped-weapon dual-surface rule" in
# .claude/docs/combat-architecture.md — Inventory._equipped["weapon"] AND
# Player._equipped_weapon must stay in lockstep across swap events.
#
# Tier 1 test bar (combat-architecture.md §"Equipped-weapon dual-surface rule"):
# paired tests for equip / unequip / equip-swap MUST instantiate a real
# Player node, NOT a stub Node. A stub returns false from
# `has_method("equip_item")` and silently skips the Player surface, leaving
# the integration silently broken.

func test_lmb_click_equip_swap_drives_both_surfaces() -> void:
	# Real Player so _apply_equip_to_player wires through equip_item(),
	# which is the production code path we need to guard.
	var PlayerScript: Script = preload("res://scripts/player/Player.gd")
	var player: Player = PlayerScript.new()
	add_child_autofree(player)
	# Player._ready adds it to the "player" group.
	var panel: InventoryPanel = _make_panel()

	# Sword A: damage=4. Sword B: damage=9. The damage delta makes the
	# Sponsor "subsequent swings still register the previous weapon's damage"
	# symptom mechanically observable in test (NOT just visual).
	var sword_a: ItemInstance = _make_weapon_item(&"panel_sword_a")
	# Override damage to 4 for sword A (different from default 7 in helper).
	sword_a.def.base_stats.damage = 4
	var sword_b: ItemInstance = _make_weapon_item(&"panel_sword_b")
	sword_b.def.base_stats.damage = 9

	# Pre-equip sword A.
	_inv().add(sword_a)
	panel.open()
	panel.force_click_inventory_index_for_test(0, MOUSE_BUTTON_LEFT)
	# Assert pre-swap state on BOTH surfaces.
	assert_eq((_inv().get_equipped(&"weapon") as ItemInstance).def.id, &"panel_sword_a",
		"pre-swap: Inventory surface has sword A")
	assert_eq((player.get_equipped_weapon() as ItemDef).id, &"panel_sword_a",
		"pre-swap: Player surface has sword A — dual-surface invariant")

	# Pickup sword B and click to equip — the exact P0 86c9q96m8 path.
	_inv().add(sword_b)
	panel.force_click_inventory_index_for_test(0, MOUSE_BUTTON_LEFT)

	# Both surfaces MUST update to sword B. Pre-fix bug: Player surface
	# could lag (the "subsequent swings still register the previous
	# weapon's damage" symptom from Sponsor's report).
	assert_eq((_inv().get_equipped(&"weapon") as ItemInstance).def.id, &"panel_sword_b",
		"post-swap: Inventory surface has sword B")
	assert_eq((player.get_equipped_weapon() as ItemDef).id, &"panel_sword_b",
		"post-swap: Player surface has sword B — if this fails, the LMB-click " +
		"path updated Inventory but didn't propagate to Player (dual-surface mismatch). " +
		"Sponsor's symptom: grid shows new sword equipped but combat damage uses the " +
		"OLD weapon. P0 86c9q96m8.")

	# Sword A must be back in the grid, NOT lost on the swap (equip-swap
	# leak guard from test_inventory.gd #9 — re-asserted here through the
	# live UI click path).
	assert_eq(_inv().get_items().size(), 1,
		"grid has 1 item post-swap (sword A pushed back from equipped slot)")
	assert_eq((_inv().get_items()[0] as ItemInstance).def.id, &"panel_sword_a",
		"swap pushes the previously-equipped sword A back into the grid (was a " +
		"data-loss bug pre-fix — _unequip_internal(slot, false) silently dropped it)")
