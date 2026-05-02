class_name ItemTooltip
extends Control
## Tooltip overlay for hovered items. Renders Uma's `inventory-stats-panel.md`
## §"Item tooltip spec" layout: header (item name in tier color + tier
## label), sub-header (slot type), base stats (white), affixes (each on
## its own line, prefixed `+` or `-`, in ember-orange), action-keys footer.
##
## Reads from the item's `ItemInstance.get_base_stats_display_lines()` and
## `get_affix_display_lines()` (Drew's `team/drew-dev/affix-application.md`
## API). The tooltip is layout-only — no logic about the item's behavior
## lives here.
##
## **Position:** anchored upper-right of the screen by default. Caller can
## override via `set_anchor_point` (M2 stretch — compare-mode places the
## second tooltip beside the first).

# ---- Palette (Uma `palette.md`) -------------------------------------

const COLOR_PANEL_BG: Color = Color(0.10588235, 0.10196078, 0.12156863, 0.92)  # #1B1A1F @92%
const COLOR_PANEL_BORDER: Color = Color(0.18431373, 0.16470588, 0.2, 1.0)      # #2F2A33
const COLOR_EMBER: Color = Color(1.0, 0.4156862745, 0.1647058824, 1.0)         # #FF6A2A
const COLOR_BODY: Color = Color(0.9098, 0.8941, 0.8392, 1.0)                   # #E8E4D6
const COLOR_HINT: Color = Color(0.7215686275, 0.6745098039, 0.5568627451, 1.0) # #B8AC8E
const COLOR_BONE_WHITE: Color = Color(0.788, 0.760, 0.698, 1.0)                # #C9C2B2

const TIER_COLORS: Dictionary = {
	0: Color(0.788, 0.760, 0.698, 1.0),  # T1 #C9C2B2
	1: Color(0.710, 0.525, 0.341, 1.0),  # T2 #B58657
	2: Color(0.353, 0.561, 0.722, 1.0),  # T3 #5A8FB8
	3: Color(0.545, 0.357, 0.831, 1.0),  # T4 #8B5BD4
	4: Color(0.878, 0.690, 0.251, 1.0),  # T5 #E0B040
	5: Color(1.0, 0.416, 0.165, 1.0),    # T6 #FF6A2A
}

const TIER_LABELS: Dictionary = {
	0: "Worn",
	1: "Common",
	2: "Fine",
	3: "Rare",
	4: "Heroic",
	5: "Mythic",
}

# ---- Runtime ---------------------------------------------------------

var _bg: ColorRect = null
var _label: RichTextLabel = null
var _current_item: ItemInstance = null


func _ready() -> void:
	_build_ui()
	visible = false


# ---- Public API ------------------------------------------------------

## Show the tooltip for `item`. Updates content + positions to upper-right.
## Call `hide_tooltip()` (or pass null) to hide.
func show_for_item(item: ItemInstance) -> void:
	if item == null or item.def == null:
		hide_tooltip()
		return
	_current_item = item
	_label.text = _build_bbcode(item)
	visible = true


func hide_tooltip() -> void:
	_current_item = null
	visible = false


## Returns the BBCode content currently rendered, useful for tests.
func get_rendered_text() -> String:
	if _label == null:
		return ""
	return _label.text


## Returns the item currently displayed, or null if hidden.
func get_current_item() -> ItemInstance:
	return _current_item


# ---- BBCode build ---------------------------------------------------

static func _build_bbcode(item: ItemInstance) -> String:
	var def: ItemDef = item.def
	var tier_idx: int = int(item.rolled_tier)
	var tier_color: Color = TIER_COLORS.get(tier_idx, COLOR_BODY)
	var tier_label: String = String(TIER_LABELS.get(tier_idx, "?"))

	var out: String = ""
	# Header — name in tier color, tier label in bone-white.
	var hex_tier: String = _color_to_hex(tier_color)
	var hex_bone: String = _color_to_hex(COLOR_BONE_WHITE)
	var hex_ember: String = _color_to_hex(COLOR_EMBER)
	var hex_body: String = _color_to_hex(COLOR_BODY)
	var hex_hint: String = _color_to_hex(COLOR_HINT)

	out += "[color=%s]%s[/color]   [color=%s]T%d %s[/color]\n" % [
		hex_tier, item.get_display_name(), hex_bone, tier_idx + 1, tier_label,
	]
	# Sub-header — slot · type.
	var slot_name: String = _slot_label(def.slot)
	out += "[color=%s][i]%s[/i][/color]\n" % [hex_hint, slot_name]
	out += "\n"
	# Base stats — white.
	var base_lines: Array[String] = []
	if item.has_method("get_base_stats_display_lines"):
		base_lines = item.get_base_stats_display_lines()
	for line: String in base_lines:
		out += "[color=%s]%s[/color]\n" % [hex_body, line]
	# Affixes — ember-orange.
	var affix_lines: Array[String] = []
	if item.has_method("get_affix_display_lines"):
		affix_lines = item.get_affix_display_lines()
	if not affix_lines.is_empty():
		out += "\n"
		for line: String in affix_lines:
			# Drew's lines come back as `Name: +X stat` — normalize to `+ Name…`
			# for the affix-coloring rule per Uma. We keep Drew's text but
			# prepend a `+` and color in ember.
			var prefix: String = "+ " if not line.begins_with("+") and not line.begins_with("-") else ""
			out += "[color=%s]%s%s[/color]\n" % [hex_ember, prefix, line]
	out += "\n"
	out += "[color=%s][LMB equip]  [RMB drop][/color]" % hex_hint
	return out


static func _slot_label(slot: int) -> String:
	match slot:
		ItemDef.Slot.WEAPON:
			return "weapon"
		ItemDef.Slot.ARMOR:
			return "armor"
		ItemDef.Slot.OFF_HAND:
			return "off-hand"
		ItemDef.Slot.TRINKET:
			return "trinket"
		ItemDef.Slot.RELIC:
			return "relic"
		_:
			return "?"


static func _color_to_hex(c: Color) -> String:
	return "#" + c.to_html(false)


# ---- UI build -------------------------------------------------------

func _build_ui() -> void:
	# Anchor upper-right of the parent canvas.
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -360.0
	offset_top = 32.0
	offset_right = -32.0
	offset_bottom = 320.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_bg = ColorRect.new()
	_bg.name = "Background"
	_bg.color = COLOR_PANEL_BG
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# 1 px ember-orange top edge.
	var top_bar: ColorRect = ColorRect.new()
	top_bar.name = "TopEdgeBar"
	top_bar.color = COLOR_EMBER
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_top = 0.0
	top_bar.offset_bottom = 1.0
	_bg.add_child(top_bar)

	_label = RichTextLabel.new()
	_label.name = "Body"
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 12.0
	_label.offset_top = 12.0
	_label.offset_right = -12.0
	_label.offset_bottom = -12.0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("default_color", COLOR_BODY)
	_label.add_theme_font_size_override("normal_font_size", 12)
	_bg.add_child(_label)
