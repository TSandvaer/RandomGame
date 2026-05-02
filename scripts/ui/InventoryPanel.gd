class_name InventoryPanel
extends CanvasLayer
## Inventory + Stats panel — opens on Tab (`toggle_inventory` action), shows
## the equipped slots, the 8x3 inventory grid, the character stats column,
## and an item tooltip on hover. Slows world time to 10% while open per
## Uma's `team/uma-ux/inventory-stats-panel.md` §"Time-slow behavior on open".
##
## **Architecture:** the panel is a pure view — it reads from the Inventory
## autoload (item list + equipped map), Levels (level / xp), PlayerStats
## (V/F/E + unspent), and Player (HP, derived). It writes via Inventory's
## equip / unequip / remove APIs. No gameplay state lives on this scene.
##
## **Open / close:**
##   - Tab (`toggle_inventory`) toggles open/close.
##   - Esc closes immediately (Uma IS-02).
##   - On open: snapshot Engine.time_scale, set to TIME_SLOW_FACTOR (0.10),
##     refresh views.
##   - On close: restore Engine.time_scale.
##
## **Click model on grid cells:**
##   - Left-click inventory cell with item -> equip into the def's slot
##     (Uma IS-15). Empty cell click is a no-op.
##   - Right-click inventory cell with item -> drop (M1: just remove; no
##     ground spawn).
##   - Left-click equipped slot with item -> unequip back to inventory
##     (Uma IS-16).
##
## **Tooltip:** ItemTooltip overlay subscribes to mouse-enter / mouse-exit
## on every cell. Renders base stats + rolled affixes via
## `ItemInstance.get_base_stats_display_lines()` and
## `get_affix_display_lines()` (Drew's API).

# ---- Signals ----------------------------------------------------------

signal panel_opened()
signal panel_closed()

# ---- Tuning -----------------------------------------------------------

## Per Uma `inventory-stats-panel.md` §"Time-slow behavior on open":
## "the world keeps running at ~10% time".
const TIME_SLOW_FACTOR: float = 0.10

## Layer above HUD (mirrors StatAllocationPanel.PANEL_LAYER).
const PANEL_LAYER: int = 80

const SAVE_SLOT: int = 0

# Input action — `toggle_inventory` is mapped to Tab in project.godot.
const ACTION_TOGGLE: StringName = &"toggle_inventory"

# Grid sizing — Uma's spec.
const GRID_COLS: int = 8
const GRID_ROWS: int = 3

# Slot order in the equipped row (left to right).
const EQUIPPED_SLOT_ORDER: Array[StringName] = [
	&"weapon", &"armor", &"off_hand", &"trinket", &"relic",
]

# ---- Palette (Uma `palette.md`) -------------------------------------

const COLOR_PANEL_BG: Color = Color(0.10588235, 0.10196078, 0.12156863, 0.92)  # #1B1A1F @92%
const COLOR_PANEL_BORDER: Color = Color(0.18431373, 0.16470588, 0.2, 1.0)      # #2F2A33
const COLOR_EMBER: Color = Color(1.0, 0.4156862745, 0.1647058824, 1.0)         # #FF6A2A
const COLOR_BODY: Color = Color(0.9098, 0.8941, 0.8392, 1.0)                   # #E8E4D6
const COLOR_HINT: Color = Color(0.7215686275, 0.6745098039, 0.5568627451, 1.0) # #B8AC8E
const COLOR_DISABLED: Color = Color(0.3764705882, 0.3607843137, 0.3137254902, 1.0)  # #605C50
const COLOR_CELL_EMPTY: Color = Color(0.2274509804, 0.2078431373, 0.2509803922, 0.4)  # #3A3540 @40%

# Tier colors (Uma palette.md).
const TIER_COLORS: Dictionary = {
	0: Color(0.788, 0.760, 0.698, 1.0),  # T1 #C9C2B2
	1: Color(0.710, 0.525, 0.341, 1.0),  # T2 #B58657
	2: Color(0.353, 0.561, 0.722, 1.0),  # T3 #5A8FB8
	3: Color(0.545, 0.357, 0.831, 1.0),  # T4 #8B5BD4
	4: Color(0.878, 0.690, 0.251, 1.0),  # T5 #E0B040
	5: Color(1.0, 0.416, 0.165, 1.0),    # T6 #FF6A2A
}

# ---- Runtime ---------------------------------------------------------

var _open: bool = false
var _previous_time_scale: float = 1.0

# Built-up node refs (created in _build_ui).
var _bg_panel: ColorRect = null
var _stats_label: RichTextLabel = null
var _xp_label: Label = null
var _capacity_label: Label = null
var _grid: GridContainer = null  # the 8x3 inventory cells container
var _inventory_cells: Array[Button] = []  # cell index -> button (24 entries)
var _equipped_cells: Dictionary = {}  # StringName slot -> Button
var _tooltip: ItemTooltip = null


func _ready() -> void:
	layer = PANEL_LAYER
	_build_ui()
	# Subscribe to Inventory autoload changes so the view refreshes after
	# pickups / equips happen outside the panel UI flow.
	var inv: Node = _inventory_node()
	if inv != null:
		if inv.has_signal("inventory_changed"):
			inv.connect("inventory_changed", _on_inventory_changed)
		if inv.has_signal("item_equipped"):
			inv.connect("item_equipped", _on_equipped_changed)
		if inv.has_signal("item_unequipped"):
			inv.connect("item_unequipped", _on_equipped_changed)
	# Hidden by default — Tab reveals.
	visible = false


# ---- Public API -------------------------------------------------------

func is_open() -> bool:
	return _open


## Returns the time-slow factor used on open. Tests assert Uma's 10% spec.
func get_time_slow_factor() -> float:
	return TIME_SLOW_FACTOR


## Open the panel. Slows time, refreshes views, makes visible. Idempotent.
func open() -> void:
	if _open:
		return
	_open = true
	_previous_time_scale = Engine.time_scale
	Engine.time_scale = TIME_SLOW_FACTOR
	visible = true
	_refresh_all()
	panel_opened.emit()


## Close the panel. Restores time scale.
func close() -> void:
	if not _open:
		return
	_open = false
	Engine.time_scale = _previous_time_scale
	visible = false
	if _tooltip != null:
		_tooltip.hide_tooltip()
	panel_closed.emit()


## Test-only helper for click simulation. Mirrors the live click handler;
## tests use this to drive the click flow without raising real input
## events.
func force_click_inventory_index_for_test(index: int, button: int = MOUSE_BUTTON_LEFT) -> void:
	_handle_inventory_click(index, button)


## Test-only helper — simulate clicking an equipped slot.
func force_click_equipped_for_test(slot: StringName, button: int = MOUSE_BUTTON_LEFT) -> void:
	_handle_equipped_click(slot, button)


## Test-only — simulate hovering an inventory cell. Pops the tooltip if
## there's an item there.
func force_hover_inventory_for_test(index: int) -> void:
	_handle_inventory_hover(index, true)


# ---- Input -----------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# Tab toggles regardless of open state. Esc only closes when open.
	if event.is_action_pressed(ACTION_TOGGLE):
		get_viewport().set_input_as_handled()
		if _open:
			close()
		else:
			open()
		return
	if not _open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var ke: InputEventKey = event as InputEventKey
		if ke.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()


# ---- View refresh ---------------------------------------------------

func _refresh_all() -> void:
	_refresh_stats()
	_refresh_equipped_row()
	_refresh_grid()
	_refresh_capacity()


func _refresh_stats() -> void:
	if _stats_label == null:
		return
	var ps: Node = _player_stats_node()
	var lvls: Node = _levels_node()
	var lvl: int = 1
	var xp: int = 0
	var xp_to_next: int = 100
	if lvls != null:
		if lvls.has_method("current_level"):
			lvl = int(lvls.current_level())
		if lvls.has_method("current_xp"):
			xp = int(lvls.current_xp())
		if lvls.has_method("xp_to_next"):
			xp_to_next = int(lvls.xp_to_next())
	var v: int = 0
	var f: int = 0
	var e: int = 0
	var unspent: int = 0
	if ps != null:
		if ps.has_method("get_stat"):
			v = int(ps.get_stat(&"vigor"))
			f = int(ps.get_stat(&"focus"))
			e = int(ps.get_stat(&"edge"))
		if ps.has_method("get_unspent_points"):
			unspent = int(ps.get_unspent_points())
	# HP — derived from Player if available, else placeholders.
	var hp_cur: int = 100
	var hp_max: int = 100
	var player: Node = _player_node()
	if player != null:
		if "hp_current" in player:
			hp_cur = int(player.hp_current)
		if "hp_max" in player:
			hp_max = int(player.hp_max)
	# Build a single rich-text block for stats. BBCode mirrors the mockup
	# section ordering: primary stats, then derived.
	var bbc: String = ""
	bbc += "[color=#FF6A2A]EMBER-KNIGHT  ·  LV %d[/color]\n\n" % lvl
	bbc += "[color=#FF6A2A]STATS[/color]\n"
	bbc += "Vigor      %d\n" % v
	bbc += "Focus      %d\n" % f
	bbc += "Edge       %d\n" % e
	bbc += "\n"
	bbc += "HP        %d / %d\n" % [hp_cur, hp_max]
	bbc += "Damage    --\n"
	bbc += "Defense   --\n"
	bbc += "Crit      --\n"
	bbc += "\n"
	if unspent > 0:
		bbc += "[color=#FF6A2A]STAT POINTS UNSPENT: %d[/color]\n" % unspent
	_stats_label.bbcode_enabled = true
	_stats_label.text = bbc
	if _xp_label != null:
		if xp_to_next > 0:
			_xp_label.text = "XP   %d / %d" % [xp, xp + xp_to_next]
		else:
			_xp_label.text = "XP   max"


func _refresh_equipped_row() -> void:
	var inv: Node = _inventory_node()
	if inv == null:
		return
	for slot_v: Variant in EQUIPPED_SLOT_ORDER:
		var slot: StringName = slot_v
		var btn: Button = _equipped_cells.get(slot, null) as Button
		if btn == null:
			continue
		var item: ItemInstance = null
		if inv.has_method("get_equipped"):
			item = inv.get_equipped(slot) as ItemInstance
		_render_cell(btn, item, slot in [&"weapon", &"armor"])


func _refresh_grid() -> void:
	var inv: Node = _inventory_node()
	if inv == null:
		return
	var items: Array = []
	if inv.has_method("get_items"):
		items = inv.get_items()
	for i in _inventory_cells.size():
		var cell: Button = _inventory_cells[i]
		var item: ItemInstance = null
		if i < items.size():
			item = items[i] as ItemInstance
		_render_cell(cell, item, true)


func _refresh_capacity() -> void:
	if _capacity_label == null:
		return
	var inv: Node = _inventory_node()
	var n: int = 0
	var cap: int = GRID_COLS * GRID_ROWS
	if inv != null:
		if inv.has_method("get_items"):
			n = inv.get_items().size()
		if inv.has_method("get_capacity"):
			cap = int(inv.get_capacity())
	_capacity_label.text = "Capacity: %d / %d" % [n, cap]


func _render_cell(btn: Button, item: ItemInstance, interactive: bool) -> void:
	if btn == null:
		return
	if item == null or item.def == null:
		btn.text = ""
		btn.add_theme_color_override("font_color", COLOR_DISABLED if not interactive else COLOR_HINT)
		btn.tooltip_text = ""
	else:
		var name: String = item.get_display_name()
		btn.text = name
		var tier_idx: int = int(item.rolled_tier)
		var color: Color = TIER_COLORS.get(tier_idx, COLOR_BODY)
		btn.add_theme_color_override("font_color", color)
		# Native Godot tooltip is a fallback; the rich ItemTooltip overlay
		# is preferred. Set a basic hint so headless tests can read it.
		btn.tooltip_text = name
	btn.disabled = not interactive
	if not interactive:
		btn.modulate = Color(1, 1, 1, 0.4)
	else:
		btn.modulate = Color(1, 1, 1, 1.0)


# ---- Click handlers --------------------------------------------------

func _handle_inventory_click(index: int, button: int) -> void:
	var inv: Node = _inventory_node()
	if inv == null:
		return
	var items: Array = inv.get_items()
	if index < 0 or index >= items.size():
		# Empty cell click — Uma "Click empty slot -> no-op" (test 4).
		return
	var item: ItemInstance = items[index] as ItemInstance
	if item == null or item.def == null:
		return
	match button:
		MOUSE_BUTTON_LEFT:
			# Equip into the def's slot (only WEAPON / ARMOR in M1).
			var target: StringName = _slot_for_def(item.def)
			if target == &"":
				return
			inv.equip(item, target)
		MOUSE_BUTTON_RIGHT:
			# Drop — for M1 just remove.
			inv.remove(item)


func _handle_equipped_click(slot: StringName, button: int) -> void:
	var inv: Node = _inventory_node()
	if inv == null:
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	# Only WEAPON / ARMOR are interactive in M1.
	if not (slot in [&"weapon", &"armor"]):
		return
	if inv.get_equipped(slot) == null:
		return
	inv.unequip(slot)


func _handle_inventory_hover(index: int, entered: bool) -> void:
	if _tooltip == null:
		return
	var inv: Node = _inventory_node()
	if inv == null:
		return
	if not entered:
		_tooltip.hide_tooltip()
		return
	var items: Array = inv.get_items()
	if index < 0 or index >= items.size():
		_tooltip.hide_tooltip()
		return
	var item: ItemInstance = items[index] as ItemInstance
	if item == null:
		_tooltip.hide_tooltip()
		return
	_tooltip.show_for_item(item)


# ---- Inventory autoload signal handlers -----------------------------

func _on_inventory_changed(_items: Array) -> void:
	if not _open:
		return
	_refresh_grid()
	_refresh_capacity()


func _on_equipped_changed(_item: ItemInstance, _slot: StringName) -> void:
	if not _open:
		return
	_refresh_equipped_row()
	_refresh_grid()
	_refresh_capacity()
	_refresh_stats()


# ---- UI build --------------------------------------------------------

func _build_ui() -> void:
	# Background — full-canvas dark slate at 92%.
	_bg_panel = ColorRect.new()
	_bg_panel.name = "Background"
	_bg_panel.color = COLOR_PANEL_BG
	_bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg_panel)

	# 1 px ember top edge.
	var top_bar: ColorRect = ColorRect.new()
	top_bar.name = "TopEdgeBar"
	top_bar.color = COLOR_EMBER
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_top = 0.0
	top_bar.offset_bottom = 1.0
	_bg_panel.add_child(top_bar)

	# Stats column (left third, RichTextLabel for BBCode).
	_stats_label = RichTextLabel.new()
	_stats_label.name = "StatsLabel"
	_stats_label.bbcode_enabled = true
	_stats_label.fit_content = true
	_stats_label.scroll_active = false
	_stats_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_stats_label.offset_left = 32.0
	_stats_label.offset_top = 32.0
	_stats_label.offset_right = 360.0
	_stats_label.offset_bottom = 540.0
	_stats_label.add_theme_color_override("default_color", COLOR_BODY)
	_stats_label.add_theme_font_size_override("normal_font_size", 14)
	_bg_panel.add_child(_stats_label)

	# XP label below stats column.
	_xp_label = Label.new()
	_xp_label.name = "XpLabel"
	_xp_label.add_theme_color_override("font_color", COLOR_BODY)
	_xp_label.add_theme_font_size_override("font_size", 12)
	_xp_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_xp_label.offset_left = 32.0
	_xp_label.offset_top = 560.0
	_xp_label.offset_right = 360.0
	_xp_label.offset_bottom = 580.0
	_bg_panel.add_child(_xp_label)

	# Capacity label (under inventory grid).
	_capacity_label = Label.new()
	_capacity_label.name = "CapacityLabel"
	_capacity_label.add_theme_color_override("font_color", COLOR_HINT)
	_capacity_label.add_theme_font_size_override("font_size", 12)
	_capacity_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_capacity_label.offset_left = 380.0
	_capacity_label.offset_top = 560.0
	_capacity_label.offset_right = 700.0
	_capacity_label.offset_bottom = 580.0
	_bg_panel.add_child(_capacity_label)

	_build_equipped_row()
	_build_inventory_grid()
	_build_footer_hint()
	_build_tooltip()


func _build_equipped_row() -> void:
	# A horizontal HBox of 5 slot buttons spanning the right two-thirds top.
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.name = "EquippedRow"
	hbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hbox.offset_left = 380.0
	hbox.offset_top = 32.0
	hbox.offset_right = 1240.0
	hbox.offset_bottom = 130.0
	hbox.add_theme_constant_override("separation", 8)
	_bg_panel.add_child(hbox)

	for slot_v: Variant in EQUIPPED_SLOT_ORDER:
		var slot: StringName = slot_v
		var btn: Button = Button.new()
		btn.name = "Equipped_%s" % str(slot)
		btn.custom_minimum_size = Vector2(96, 96)
		btn.text = ""
		var interactive: bool = slot in [&"weapon", &"armor"]
		# Caption label for the disabled M2 slots.
		if not interactive:
			btn.text = "Unlocks at M2"
			btn.disabled = true
			btn.modulate = Color(1, 1, 1, 0.4)
		btn.add_theme_color_override("font_color", COLOR_BODY)
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(_on_equipped_btn_pressed.bind(slot, MOUSE_BUTTON_LEFT))
		btn.gui_input.connect(_on_equipped_btn_gui_input.bind(slot))
		hbox.add_child(btn)
		_equipped_cells[slot] = btn


func _build_inventory_grid() -> void:
	_grid = GridContainer.new()
	_grid.name = "InventoryGrid"
	_grid.columns = GRID_COLS
	_grid.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_grid.offset_left = 380.0
	_grid.offset_top = 160.0
	_grid.offset_right = 1240.0
	_grid.offset_bottom = 540.0
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	_bg_panel.add_child(_grid)

	for i in GRID_COLS * GRID_ROWS:
		var btn: Button = Button.new()
		btn.name = "Cell_%d" % i
		btn.custom_minimum_size = Vector2(96, 96)
		btn.text = ""
		btn.add_theme_color_override("font_color", COLOR_HINT)
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(_on_grid_btn_pressed.bind(i, MOUSE_BUTTON_LEFT))
		btn.gui_input.connect(_on_grid_btn_gui_input.bind(i))
		btn.mouse_entered.connect(_on_grid_hover.bind(i, true))
		btn.mouse_exited.connect(_on_grid_hover.bind(i, false))
		_grid.add_child(btn)
		_inventory_cells.append(btn)


func _build_footer_hint() -> void:
	var hint: Label = Label.new()
	hint.name = "FooterHint"
	hint.text = "[Tab] close   [LMB] equip/unequip   [RMB] drop   [Esc] quick close"
	hint.add_theme_color_override("font_color", COLOR_HINT)
	hint.add_theme_font_size_override("font_size", 10)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_left = 32.0
	hint.offset_top = -28.0
	hint.offset_bottom = -8.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bg_panel.add_child(hint)


func _build_tooltip() -> void:
	_tooltip = ItemTooltip.new()
	_tooltip.name = "ItemTooltip"
	add_child(_tooltip)


# ---- Button signal adapters -----------------------------------------

func _on_grid_btn_pressed(index: int, button: int) -> void:
	# Default-button signal only fires for left mouse — we still route via
	# _handle_inventory_click to keep the test-only force_click path
	# identical.
	_handle_inventory_click(index, button)


func _on_grid_btn_gui_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed:
		return
	# Left clicks are also delivered via `pressed` — handle right-click here.
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		_handle_inventory_click(index, MOUSE_BUTTON_RIGHT)


func _on_grid_hover(index: int, entered: bool) -> void:
	_handle_inventory_hover(index, entered)


func _on_equipped_btn_pressed(slot: StringName, button: int) -> void:
	_handle_equipped_click(slot, button)


func _on_equipped_btn_gui_input(event: InputEvent, slot: StringName) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		_handle_equipped_click(slot, MOUSE_BUTTON_RIGHT)


# ---- Helpers ---------------------------------------------------------

func _slot_for_def(def: ItemDef) -> StringName:
	if def == null:
		return &""
	match def.slot:
		ItemDef.Slot.WEAPON:
			return &"weapon"
		ItemDef.Slot.ARMOR:
			return &"armor"
		_:
			return &""


func _inventory_node() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null("Inventory")


func _player_stats_node() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null("PlayerStats")


func _levels_node() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null("Levels")


func _player_node() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	var nodes: Array = loop.get_nodes_in_group("player")
	if nodes.is_empty():
		return null
	return nodes[0] as Node
