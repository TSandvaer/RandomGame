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

# Test-only input action — mapped to F9 in project.godot. Drives
# `force_close_for_test()` from the Playwright harness. See that method's
# docstring for why a dedicated `_input()`-handled action is required (the
# Godot GUI system consumes BOTH `Tab` and `Escape` when a focusable Control
# holds keyboard focus, so neither reliably closes the panel from a spec).
const ACTION_TEST_FORCE_CLOSE: StringName = &"test_force_close_inventory"

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

## Shared "positive-affirmation green" — first use site for the palette.md
## "Heal popup (M2+)" reservation. Used for the equipped-row outline + the
## EQUIPPED badge plate. Single source of truth so SaveToast can read the
## same hex (see `team/uma-ux/m2-w1-ux-polish-design.md` § "Shared vocabulary").
## All channels strictly sub-1.0 — HTML5 HDR-clamp safe.
const COLOR_EQUIPPED_INDICATOR: Color = Color(0.478, 0.780, 0.451, 1.0)  # #7AC773
const COLOR_EQUIPPED_BADGE_PLATE: Color = Color(0.478, 0.780, 0.451, 0.92)  # #7AC773 @92%
const COLOR_EQUIPPED_BADGE_TEXT: Color = Color(0.10588235, 0.10196078, 0.12156863, 1.0)  # #1B1A1F
# Horizontal padding (px) added on each side of the badge content to derive
# the BadgePlate WIDTH. Width is the axis that overflowed in PR #179 — it is
# derived from the label's measured minimum WIDTH + checkmark area + this pad,
# so it can never drift out of sync with the font / string (ticket 86c9qah1q).
const BADGE_PLATE_H_PADDING: float = 4.0
# Fixed plate HEIGHT (px). NOT derived from `Label.get_minimum_size().y`:
# that returns the font's full line-box height (~27 px for the default theme
# font at size 9 — ascent + descent + leading), which would make the plate
# absurdly tall and push it down into the centered item-name text. The visible
# glyph cap-height at font size 9 is far smaller; the pre-`✓` `main` build
# shipped a 12 px plate that rendered "EQUIPPED" cleanly (vertical_alignment
# CENTER draws the glyphs centred regardless of the line-box metric). 14 px
# keeps that proven fit and gives the 9 px checkmark shape breathing room.
const BADGE_PLATE_HEIGHT: float = 14.0
# The checkmark secondary cue is drawn as a SHAPE (two rotated ColorRect
# strokes), not a font glyph — the Godot 4.3 `gl_compatibility` (HTML5)
# default font has no U+2713 "✓" glyph and renders it as notdef "tofu".
# BADGE_CHECK_SIZE is the checkmark's bounding box; BADGE_CHECK_STROKE its
# stroke thickness; BADGE_CHECK_TEXT_GAP the gap between the checkmark and
# the "EQUIPPED" label.
const BADGE_CHECK_SIZE: Vector2 = Vector2(9, 9)
const BADGE_CHECK_STROKE: float = 2.0
const BADGE_CHECK_TEXT_GAP: float = 3.0

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


## Safety guard: if the panel is freed while still open (scene reload,
## HTML5 tab-blur path), restore Engine.time_scale so the world doesn't
## stay at 0.10 forever. Idempotent w.r.t. close() — once `_open` is false
## (normal close path already restored), this is a no-op. Per Tess's
## `team/tess-qa/html5-rc-audit-591bcc8.md` §4 CR-1.
func _exit_tree() -> void:
	if _open:
		Engine.time_scale = _previous_time_scale
		_open = false


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


## Test-only — reliably close the panel and restore `Engine.time_scale`,
## sidestepping the entire focus-consumption problem class.
##
## **Why this exists (ticket 86c9qb7f3 / 86c9qah0f).** The Playwright harness
## drives the HTML5 build with real keyboard/mouse events and cannot call
## GDScript methods directly. The equip-flow spec's Phase 2.5 clicks an
## inventory grid cell — a `Button` with the default `focus_mode = FOCUS_ALL`
## — which grabs keyboard focus. From that point Godot's GUI input system
## **consumes both `Tab` and `Escape`** before they reach
## `_unhandled_input`: `Tab` is the focus-traversal key, and `Escape` is
## bound to the built-in `ui_cancel` GUI action. Neither keypress closes the
## panel, so `Engine.time_scale` stays pinned at `TIME_SLOW_FACTOR (0.10)`
## and every subsequent spec action runs at 1/10th game speed. Swapping one
## focus-consumed key for another (the rejected PR #187 round-1 approach)
## does not fix it.
##
## The reliable fix is a direct-close hook reachable from a spec. It is wired
## to the `test_force_close_inventory` action (F9 in project.godot) which is
## handled in `_input()` — `_input()` runs BEFORE the GUI focus system, so a
## focused Button cannot swallow it — gated behind `OS.has_feature("web")`
## (true only in the HTML5 export the harness runs against; desktop and
## headless GUT never wire the action, mirroring the `combat_trace` gate in
## `DebugFlags.gd`). Emits a `[combat-trace]` confirmation line carrying the
## restored `Engine.time_scale` so the spec can positively assert the panel
## actually closed. Idempotent — a no-op if already closed.
func force_close_for_test() -> void:
	close()
	# Confirmation trace — the spec asserts on this line to prove the panel
	# actually closed AND time-scale was restored (HTML5-only; quiet on
	# desktop/headless via the combat_trace gate).
	var df: Node = _debug_flags_node()
	if df != null and df.has_method("combat_trace"):
		df.combat_trace(
			"InventoryPanel.force_close_for_test",
			"open=%s time_scale=%s" % [_open, Engine.time_scale]
		)


# ---- Input -----------------------------------------------------------

## Handled BEFORE the GUI focus system (unlike `_unhandled_input`), so the
## test-only force-close action reaches the panel even when a focusable grid
## `Button` holds keyboard focus. Gated on `OS.has_feature("web")` — the
## action is only ever acted on in the HTML5 export the Playwright harness
## drives; desktop / headless GUT ignore it entirely (the F9 binding is inert
## there). This mirrors the `DebugFlags.combat_trace` web-only gate.
##
## Matches the F9 key by `physical_keycode` directly (the proven pattern in
## `DebugFlags._input` for Ctrl+Shift+X) rather than via `is_action_pressed`
## — this removes the dependency on the `test_force_close_inventory` action
## being present in the exported `project.godot`, so the hook works even if
## the action map is stripped or the export preset filters it.
func _input(event: InputEvent) -> void:
	if not OS.has_feature("web"):
		return
	if not (event is InputEventKey):
		return
	var ke: InputEventKey = event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if ke.physical_keycode == KEY_F9 or event.is_action_pressed(ACTION_TEST_FORCE_CLOSE):
		get_viewport().set_input_as_handled()
		force_close_for_test()


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
	# Damage / Defense lines read the equipped-Inventory surface — NOT the
	# Player surface (per `.claude/docs/combat-architecture.md` §
	# "Equipped-weapon dual-surface rule"). The panel is a faithful reporter
	# of Inventory state; combat reads Player state. The two are kept in
	# lockstep via `Inventory.equip()` → `_apply_equip_to_player()`.
	bbc += _build_damage_line()
	bbc += _build_defense_line()
	# Crit is M2+ scope — `Damage.compute_player_damage` doesn't roll crit in
	# M1. Forward-compat tag so the `--` is not ambiguous.
	bbc += "Crit      --  [color=#B8AC8E](M2)[/color]\n"
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


## Build the BBCode "Damage" line for `_refresh_stats`. Reads from
## `Inventory.get_equipped(&"weapon")`. Fistless = `1` (FIST_DAMAGE) with a
## muted-parchment `(fists)` tag so the `1` is unambiguous (per Uma's design
## doc § Ticket 1 — `(fists)` clarifies that 1 is a real value, not a
## placeholder). Reuses the constant from `scripts/combat/Damage.gd` so the
## displayed value matches what the next swing actually deals (Inventory
## surface only — combat-reads-Player; see combat-architecture.md §
## "Equipped-weapon dual-surface rule").
func _build_damage_line() -> String:
	const DamageScript: Script = preload("res://scripts/combat/Damage.gd")
	var inv: Node = _inventory_node()
	var weapon: ItemInstance = null
	if inv != null and inv.has_method("get_equipped"):
		weapon = inv.get_equipped(&"weapon") as ItemInstance
	if weapon != null and weapon.def != null and weapon.def.base_stats != null:
		return "Damage    %d\n" % int(weapon.def.base_stats.damage)
	# Fistless fallback — FIST_DAMAGE is the constant the actual swing uses.
	return "Damage    %d  [color=#B8AC8E](fists)[/color]\n" % int(DamageScript.FIST_DAMAGE)


## Build the BBCode "Defense" line for `_refresh_stats`. Reads from
## `Inventory.get_equipped(&"armor")`. No-armor fallback shows `0` without a
## parenthetical — `0` is unambiguously "no reduction" (per Uma's design
## doc § Ticket 1).
func _build_defense_line() -> String:
	var inv: Node = _inventory_node()
	var armor: ItemInstance = null
	if inv != null and inv.has_method("get_equipped"):
		armor = inv.get_equipped(&"armor") as ItemInstance
	if armor != null and armor.def != null and armor.def.base_stats != null:
		return "Defense   %d\n" % int(armor.def.base_stats.armor)
	return "Defense   0\n"


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
		# Equipped-state visual distinction (Ticket 3 — `86c9q7p48`). Show
		# the green outline + EQUIPPED badge iff the slot has an item. The
		# indicator nodes were built in `_build_equipped_row`; this just
		# flips visibility — pure projection of `Inventory._equipped[slot]`,
		# stateless across F5-reload.
		_set_equipped_indicator(btn, item != null)


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
		# Equipped-state indicators (Ticket 3 — `86c9q7p48`). 4 outline
		# ColorRects + 1 EQUIPPED badge (ColorRect plate + checkmark-shape +
		# Label text). All default-hidden; `_set_equipped_indicator` flips
		# them on when the slot has an item. Per Uma's design § "Visual spec":
		#   - 2 px green outline on all 4 sides, color #7AC773
		#   - "EQUIPPED" badge at top-left, font color #1B1A1F on #7AC773
		#     plate, with a checkmark SHAPE (two rotated ColorRect strokes,
		#     ticket 86c9qah1q) as the color-blind secondary cue. The plate
		#     is auto-sized to the checkmark area + the label's measured
		#     minimum size + padding so the content always fits — no
		#     hardcoded size. The "✓" is a shape, NOT a font glyph: the
		#     HTML5 default font has no U+2713 and rendered it as tofu.
		# All ColorRects + Label render identically in `gl_compatibility`
		# (HTML5) and `forward_plus` (desktop) — zero Polygon2D, all colors
		# strictly sub-1.0 per channel.
		_build_equipped_indicators_for_slot(btn)


## Builds the 4 outline ColorRects + 1 badge (ColorRect plate + Label) as
## children of the equipped-slot Button. All start hidden — `_set_equipped_indicator`
## flips them on when the slot has an item. Names are stable so tests can
## look them up via `find_child` (or via the public `get_equipped_indicator_*`
## accessors) and assert visibility / color.
##
## Layout (per Uma's `m2-w1-ux-polish-design.md` § Ticket 3 visual spec):
##   - top    edge: ColorRect at (0, -2)   size (96, 2)
##   - bottom edge: ColorRect at (0, 96)   size (96, 2)
##   - left   edge: ColorRect at (-2, -2)  size (2, 100)
##   - right  edge: ColorRect at (96, -2)  size (2, 100)
##   - badge  plate: ColorRect at (2, 2)  size = check area + label min size + padding
##   - badge  check: Control "BadgeCheck" — 2 rotated ColorRect strokes, the
##                   CVD secondary cue drawn as a SHAPE (no font glyph)
##   - badge  text:  Label  text="EQUIPPED" positioned right of the checkmark
##
## All children have `mouse_filter = MOUSE_FILTER_IGNORE` so they don't
## intercept clicks on the Button. Default `z_index = 0`; the Button paints
## first, then children paint on top in tree order — outline + badge sit
## visually above the button surface (which is what we want).
func _build_equipped_indicators_for_slot(btn: Button) -> void:
	if btn == null:
		return
	# Top edge
	var top_edge: ColorRect = _make_outline_edge(Vector2(0, -2), Vector2(96, 2))
	top_edge.name = "OutlineTop"
	btn.add_child(top_edge)
	# Bottom edge
	var bottom_edge: ColorRect = _make_outline_edge(Vector2(0, 96), Vector2(96, 2))
	bottom_edge.name = "OutlineBottom"
	btn.add_child(bottom_edge)
	# Left edge
	var left_edge: ColorRect = _make_outline_edge(Vector2(-2, -2), Vector2(2, 100))
	left_edge.name = "OutlineLeft"
	btn.add_child(left_edge)
	# Right edge
	var right_edge: ColorRect = _make_outline_edge(Vector2(96, -2), Vector2(2, 100))
	right_edge.name = "OutlineRight"
	btn.add_child(right_edge)
	# Badge plate. Size is computed from the label's real minimum size + the
	# checkmark-glyph area below (NOT a hardcoded constant) — see the sizing
	# block after the children are built. Position stays pinned at top-left.
	var plate: ColorRect = ColorRect.new()
	plate.name = "BadgePlate"
	plate.color = COLOR_EQUIPPED_BADGE_PLATE
	plate.position = Vector2(2, 2)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.visible = false
	btn.add_child(plate)
	# Color-blind secondary cue (ticket `86c9qah1q`): a checkmark SHAPE that
	# survives all CVD types + monochrome. Drawn from two rotated ColorRect
	# strokes — NOT a font glyph. PR #179's first cut used the U+2713 "✓"
	# character; the Godot 4.3 `gl_compatibility` (HTML5) default font has no
	# glyph for it, so it rendered as a notdef "tofu" box in the release build
	# (visible in Tess's pr179 captures as a boxed "27" — 0x2713's codepoint).
	# ColorRect strokes render identically on `gl_compatibility` (HTML5) and
	# `forward_plus` (desktop) with zero font dependency — the docs' "prefer
	# ColorRect for simple shapes" rule (see .claude/docs/html5-export.md).
	var check: Control = _make_badge_checkmark()
	check.name = "BadgeCheck"
	check.position = Vector2(BADGE_PLATE_H_PADDING, 0)  # vertical centre set after plate sized
	plate.add_child(check)
	# Badge text — Label child of the plate so it scrolls with the plate if
	# layout ever shifts. Reads plain "EQUIPPED" (font-safe ASCII — always
	# renders); the checkmark SHAPE to its left is the CVD cue, not a glyph
	# inside the text run.
	var badge_label: Label = Label.new()
	badge_label.name = "BadgeLabel"
	badge_label.text = "EQUIPPED"
	badge_label.add_theme_color_override("font_color", COLOR_EQUIPPED_BADGE_TEXT)
	badge_label.add_theme_font_size_override("font_size", 9)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(badge_label)
	# Size the plate. WIDTH is derived from the label's *actual* rendered
	# minimum width + the fixed checkmark area + horizontal padding — PR #179's
	# 72 px hardcode was too narrow for "✓ EQUIPPED" at font size 9 and the
	# label content overflowed + clipped against the dark cell. Deriving the
	# width from `get_minimum_size().x` makes the horizontal fit correct by
	# construction across every font, with no magic number to drift out of
	# sync. `get_minimum_size()` resolves here because `_build_equipped_row`
	# runs from `_ready` with the panel already in the tree, so the Label has
	# a resolved theme + font. HEIGHT is the fixed BADGE_PLATE_HEIGHT — see
	# that constant for why `get_minimum_size().y` is the WRONG height source
	# (it returns the ~27 px full line box, not the visible glyph height).
	var label_min: Vector2 = badge_label.get_minimum_size()
	plate.size = Vector2(
		BADGE_PLATE_H_PADDING          # left pad
		+ BADGE_CHECK_SIZE.x           # checkmark shape area
		+ BADGE_CHECK_TEXT_GAP         # gap between check and text
		+ ceil(label_min.x)            # measured label width
		+ BADGE_PLATE_H_PADDING,       # right pad
		BADGE_PLATE_HEIGHT)
	# Position the label after the checkmark area; give it the plate's height
	# so its own vertical-centre alignment draws the glyphs centred.
	badge_label.position = Vector2(
		BADGE_PLATE_H_PADDING + BADGE_CHECK_SIZE.x + BADGE_CHECK_TEXT_GAP,
		0)
	badge_label.size = Vector2(ceil(label_min.x), plate.size.y)
	# Centre the checkmark vertically within the plate.
	check.position.y = (plate.size.y - BADGE_CHECK_SIZE.y) * 0.5


## Helper — build one outline-edge ColorRect at the given position/size with
## the shared positive-green color, default-hidden. Mouse filter ignore so
## the strip doesn't eat clicks on the Button.
func _make_outline_edge(pos: Vector2, sz: Vector2) -> ColorRect:
	var edge: ColorRect = ColorRect.new()
	edge.color = COLOR_EQUIPPED_INDICATOR
	edge.position = pos
	edge.size = sz
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.visible = false
	return edge


## Helper — build the color-blind secondary-cue checkmark as a SHAPE (ticket
## `86c9qah1q`). Returns a `BADGE_CHECK_SIZE`-sized Control containing two
## rotated ColorRect strokes that together read as a "✓": a short stroke from
## the lower-left descending to the bottom vertex, and a longer stroke rising
## from that vertex to the upper-right.
##
## Why a shape and not the U+2713 character: the Godot 4.3 `gl_compatibility`
## (HTML5) default font has no glyph for "✓" and renders it as a notdef
## "tofu" box (Tess's pr179 captures showed a boxed "27" — 0x2713's codepoint
## digits). ColorRect strokes are font-independent and render identically on
## `gl_compatibility` (HTML5) and `forward_plus` (desktop). Strokes use the
## same dark badge-text color as the "EQUIPPED" label for a unified high-
## contrast cue on the green plate. `pivot_offset = (0,0)` so `rotation`
## pivots about each stroke's top-left corner — positions are computed for
## that pivot.
func _make_badge_checkmark() -> Control:
	var root: Control = Control.new()
	root.custom_minimum_size = BADGE_CHECK_SIZE
	root.size = BADGE_CHECK_SIZE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w: float = BADGE_CHECK_SIZE.x
	var h: float = BADGE_CHECK_SIZE.y
	var t: float = BADGE_CHECK_STROKE
	# Short stroke: from ~(0.10w, 0.50h) down-right to the bottom vertex
	# ~(0.40w, 0.82h). Length + angle from that delta.
	var short_start: Vector2 = Vector2(w * 0.10, h * 0.50)
	var bottom_vertex: Vector2 = Vector2(w * 0.40, h * 0.82)
	var short_vec: Vector2 = bottom_vertex - short_start
	var short_stroke: ColorRect = ColorRect.new()
	short_stroke.color = COLOR_EQUIPPED_BADGE_TEXT
	short_stroke.mouse_filter = Control.MOUSE_FILTER_IGNORE
	short_stroke.size = Vector2(short_vec.length() + t * 0.5, t)
	short_stroke.position = short_start - Vector2(0, t * 0.5)
	short_stroke.pivot_offset = Vector2.ZERO
	short_stroke.rotation = short_vec.angle()
	root.add_child(short_stroke)
	# Long stroke: from the bottom vertex up-right to ~(0.92w, 0.16h).
	var long_end: Vector2 = Vector2(w * 0.92, h * 0.16)
	var long_vec: Vector2 = long_end - bottom_vertex
	var long_stroke: ColorRect = ColorRect.new()
	long_stroke.color = COLOR_EQUIPPED_BADGE_TEXT
	long_stroke.mouse_filter = Control.MOUSE_FILTER_IGNORE
	long_stroke.size = Vector2(long_vec.length() + t * 0.5, t)
	long_stroke.position = bottom_vertex - Vector2(0, t * 0.5)
	long_stroke.pivot_offset = Vector2.ZERO
	long_stroke.rotation = long_vec.angle()
	root.add_child(long_stroke)
	return root


## Toggle visibility of the 4 outline ColorRects + badge plate on the given
## equipped-slot Button. Invoked from `_refresh_equipped_row` whenever the
## equipped-row signal fires (or on panel `open()`). Stateless projection of
## `Inventory.get_equipped(slot) != null`.
func _set_equipped_indicator(btn: Button, has_item: bool) -> void:
	if btn == null:
		return
	for child_name in ["OutlineTop", "OutlineBottom", "OutlineLeft", "OutlineRight", "BadgePlate"]:
		var node: Node = btn.get_node_or_null(child_name)
		if node is CanvasItem:
			(node as CanvasItem).visible = has_item


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


## DebugFlags autoload — used by `force_close_for_test` to emit the HTML5
## `[combat-trace]` confirmation line. Returns null if the autoload is absent
## (bare-instanced panel tests); callers must null-check.
func _debug_flags_node() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null("DebugFlags")
