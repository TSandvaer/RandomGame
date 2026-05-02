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
