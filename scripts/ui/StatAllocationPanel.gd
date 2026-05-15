class_name StatAllocationPanel
extends CanvasLayer
## Bottom-anchored level-up panel. Player allocates banked stat points to
## Vigor / Focus / Edge by pressing 1 / 2 / 3 (immediate-allocate path) or
## the equivalent +1 buttons. Enter confirms-and-closes; Esc banks the
## remaining points.
##
## Implements Uma's `team/uma-ux/level-up-panel.md` spec — bottom-anchored
## band on the 480x270 internal canvas, three stat tiles, Uma's palette
## hex codes from `team/uma-ux/palette.md`.
##
## **Auto-open rule (LU-05/LU-06):** Level 2 (first ever level-up) auto-
## opens the panel; Levels 3+ surface only the [+1 STAT] HUD pip and the
## player presses P to open. The first-level-up flag persists in save so
## auto-open never repeats for the same character.
##
## **Non-modal overlay (LU-09 revised — Sponsor redirect 2026-05-15):** the
## panel is a purely cosmetic overlay. `Engine.time_scale` stays at 1.0.
## Player process_mode is NOT changed — the player keeps moving and attacking
## at full speed while picking a talent at leisure. No state changes to
## Player, Engine, or scene on open or close. This replaces both the original
## "World time slows to 10%" spec AND the subsequent "modal pause via
## PROCESS_MODE_DISABLED" attempt — Sponsor's verbatim redirect (Room 5,
## 2026-05-15): "i shouldnt be slowed when level up panel appears, im in
## the middle of a fight." Panel responsibility: render, accept talent
## input, close on selection. That is its full scope.
##
## **Multi-level catch-up (LU-23):** if the player banks 2+ points before
## opening, the header shows N and the panel stays open until N=0 (or the
## player Esc-banks).
##
## **Allocations are saved (LU-25):** on every spend, the panel writes the
## new V/F/E to `Save.save_game(SLOT)` so a quit-mid-allocation doesn't
## lose progress. Banked points likewise persist via the save.
##
## ## Signals
##   panel_opened()
##   panel_closed(banked_points: int)
##   point_allocated(stat: StringName, new_value: int)
##
## ## Test surface
##   `open()` / `close(bank)` are public so tests can drive without raising
##   real input events. `is_open()`, `get_time_slow_factor()`,
##   `force_press_for_test(StringName)` for deterministic key probes,
##   `force_p_keypress_for_test()` for the BB-4 P-key toggle path.
##   Non-modal: tests assert player process_mode and Engine.time_scale are
##   UNCHANGED by the panel (neither is touched on open or close).

# ---- Signals ---------------------------------------------------------

signal panel_opened()
signal panel_closed(banked_points: int)
signal point_allocated(stat: StringName, new_value: int)

# ---- Tuning constants ------------------------------------------------

## Retained for backward-compat with test helpers that call
## `get_time_slow_factor()`. The panel has never applied this value since
## the Sponsor redirect (2026-05-15, ticket 86c9ujerz). Records the
## original spec value; the constant itself has no runtime effect.
const TIME_SLOW_FACTOR: float = 0.10

## Layer above HUD layers (mirrors DescendScreen).
const PANEL_LAYER: int = 80

## Default save slot the panel uses for allocation persistence.
const SAVE_SLOT: int = 0

# ---- Palette (Uma `palette.md`) -------------------------------------

const COLOR_PANEL_BG: Color = Color(0.10588235, 0.10196078, 0.12156863, 0.92)  # #1B1A1F @92%
const COLOR_PANEL_BORDER: Color = Color(0.18431373, 0.16470588, 0.2, 1.0)      # #2F2A33
const COLOR_EMBER: Color = Color(1.0, 0.4156862745, 0.1647058824, 1.0)         # #FF6A2A
const COLOR_EMBER_LIGHT: Color = Color(1.0, 0.69019608, 0.4, 1.0)              # #FFB066
const COLOR_BODY: Color = Color(0.9098, 0.8941, 0.8392, 1.0)                   # #E8E4D6
const COLOR_HINT: Color = Color(0.7215686275, 0.6745098039, 0.5568627451, 1.0) # #B8AC8E

# ---- Strings ---------------------------------------------------------

## Path to the StatStrings resource (Uma's 12 canonical tooltip strings).
## Per spec: "Do not inline strings in the panel scene". Loaded once at
## _ready, cached on the panel.
const STAT_STRINGS_PATH: String = "res://content/ui/stat_strings.tres"

const HEADER_TEXT_SINGLE: String = "LEVEL UP — Spend 1 stat point"
const HEADER_TEXT_MULTI_FMT: String = "LEVEL UP — Spend %d stat points"
const HINT_TEXT: String = "<1/2/3> pick   <Enter> confirm   <Esc> close (point banked)"

# ---- Stat IDs (mirror PlayerStats) -----------------------------------

const STAT_VIGOR: StringName = &"vigor"
const STAT_FOCUS: StringName = &"focus"
const STAT_EDGE: StringName = &"edge"

# ---- Runtime ----------------------------------------------------------

var _open: bool = false
var _bg_panel: ColorRect = null
var _header_label: Label = null
var _hint_label: Label = null
var _tiles: Dictionary = {}  # stat_id -> Dictionary { panel, name_label, value_label, ... }
var _stat_strings: StatStrings = null


func _ready() -> void:
	layer = PANEL_LAYER
	_load_strings()
	_build_ui()
	# Subscribe to Levels.level_up so we auto-open on first level-up.
	# Tests that don't want this subscription instantiate the panel with
	# the autoload absent (or call _ready manually); we tolerate a missing
	# Levels autoload defensively.
	var levels: Node = _levels()
	if levels != null and levels.has_signal("level_up"):
		var err: int = levels.connect("level_up", _on_level_up)
		if err != OK:
			push_warning("[StatAllocationPanel] failed to connect to Levels.level_up (err=%d)" % err)
	# Hidden by default — level_up signal or manual open() reveals.
	visible = false


# ---- Public API -------------------------------------------------------

func is_open() -> bool:
	return _open


## Returns the time-scale constant (retained for test API compat). The panel
## does NOT apply this to Engine.time_scale — Sponsor redirect 2026-05-15.
func get_time_slow_factor() -> float:
	return TIME_SLOW_FACTOR


## Open the panel. Makes the panel visible, refreshes the tile values from
## PlayerStats. Idempotent — already-open is a no-op.
##
## Non-modal design (Sponsor redirect 2026-05-15): NO Engine.time_scale
## change, NO Player.process_mode change. Combat continues at full speed
## while the panel is visible. Panel is a purely cosmetic overlay.
##
## `auto_opened`: true when triggered by the Level-2-first-time-only
## auto-open rule; false for manual P-key open. Currently informational
## (logged only) but reserved for the "first_levelup_subtle_hint" copy
## variant.
func open(_auto_opened: bool = false) -> void:
	if _open:
		return
	_open = true
	visible = true
	_refresh_tiles()
	_refresh_header()
	panel_opened.emit()


## Close the panel. If banked > 0, the unspent points stay in
## PlayerStats. Non-modal: no game-state restoration needed on close.
func close(_emit: bool = true) -> void:
	if not _open:
		return
	_open = false
	visible = false
	if _emit:
		panel_closed.emit(_get_unspent())


## Safety guard: if the panel is freed while still open (scene reload,
## HTML5 tab-blur path), mark closed. Non-modal — no state to restore.
## Per Tess's `team/tess-qa/html5-rc-audit-591bcc8.md` §4 CR-2.
func _exit_tree() -> void:
	if _open:
		_open = false


## Spend 1 unspent point on the given stat. Updates PlayerStats, persists
## via Save.save_game, refreshes tile values, fires `point_allocated`.
## Returns true on success. Returns false (no-op) if no points are banked
## or the stat id is unknown.
func allocate(stat_id: StringName) -> bool:
	if not _is_known_stat(stat_id):
		push_warning("StatAllocationPanel.allocate: unknown stat '%s'" % stat_id)
		return false
	var ps: Node = _player_stats()
	if ps == null:
		push_warning("StatAllocationPanel.allocate: PlayerStats autoload missing")
		return false
	# Gate on banked-point availability.
	if not ps.spend_unspent_point():
		return false
	if not ps.add_stat(stat_id, 1):
		# Couldn't apply — refund the point so we don't leak.
		ps.add_unspent_points(1)
		return false
	point_allocated.emit(stat_id, ps.get_stat(stat_id))
	# Persist immediately — testing-bar §6 edge probe (mid-allocation quit).
	_persist_to_save()
	# Refresh visible counters.
	_refresh_tiles()
	_refresh_header()
	# Auto-dismiss when the bank empties (Uma LU-24).
	if ps.get_unspent_points() <= 0:
		close()
	return true


## Test-only — simulate the player pressing one of the stat keys. Maps
## "1" -> vigor, "2" -> focus, "3" -> edge, &"enter" -> close-confirm,
## &"esc" -> close-bank. Mirrors the live `_unhandled_input` paths.
func force_press_for_test(key: StringName) -> void:
	match key:
		&"1", STAT_VIGOR:
			allocate(STAT_VIGOR)
		&"2", STAT_FOCUS:
			allocate(STAT_FOCUS)
		&"3", STAT_EDGE:
			allocate(STAT_EDGE)
		&"enter":
			# Confirm + close. Any remaining banked points stay banked
			# (matches LU-22 - Esc semantics; M1 doesn't differentiate
			# Enter-with-N>0 from Esc-with-N>0 since the speedrun flow
			# auto-dismisses at N=0).
			close()
		&"esc":
			close()


# ---- Input -----------------------------------------------------------

## Modal-stacking rule (BB-4 `86c9m395d`):
##
##   P key opens the panel ONLY when:
##     1. The panel is currently closed (toggle behavior — pressing P while
##        open closes it, mirroring InventoryPanel's Tab toggle pattern).
##     2. PlayerStats has unspent points to spend (per Tess's bug-bash
##        `team/tess-qa/m1-bugbash-4484196.md` §BB-4 "don't open an empty
##        panel"). Banking 0 points is a UX dead-end — the HUD pip is
##        already hidden in that case (`Main._on_unspent_points_changed`),
##        so the keybinding follows suit.
##
##   We do NOT inspect other modals (InventoryPanel, DescendScreen) here.
##   Each modal is a CanvasLayer with its own `_unhandled_input`, and Godot
##   delivers `_unhandled_input` to higher CanvasLayer.layer values first.
##   InventoryPanel + StatAllocationPanel both use `PANEL_LAYER = 80`;
##   DescendScreen uses 100. As long as one of them calls
##   `get_viewport().set_input_as_handled()` on its consumed events
##   (which they do — see InventoryPanel `_unhandled_input` Tab branch),
##   the other won't see the event. The only case where both could fire
##   simultaneously is two panels open with the same hotkey — but P and
##   Tab don't collide and the Esc paths each call set_input_as_handled.
##
##   Edge probe — pause / cutscene: Engine.time_scale tweaks alone don't
##   pause `_unhandled_input` delivery. If a future cutscene system needs
##   to lock input, it should pause via `get_tree().paused = true` plus
##   `process_mode = Node.PROCESS_MODE_PAUSABLE` on this CanvasLayer
##   (default). That's a separate cutscene-controller concern; this
##   handler stays simple.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key_event: InputEventKey = event as InputEventKey
	# Use physical_keycode so layout doesn't matter (matches DebugFlags
	# convention).
	var pk: int = key_event.physical_keycode
	# P-key path is handled regardless of `_open` — it's the toggle entry-
	# point that the BB-4 bug fix wires (docstring + HUD pip cue both
	# advertise it).
	if pk == KEY_P:
		get_viewport().set_input_as_handled()
		_handle_toggle_keypress()
		return
	if not _open:
		return
	match pk:
		KEY_1, KEY_KP_1:
			get_viewport().set_input_as_handled()
			allocate(STAT_VIGOR)
		KEY_2, KEY_KP_2:
			get_viewport().set_input_as_handled()
			allocate(STAT_FOCUS)
		KEY_3, KEY_KP_3:
			get_viewport().set_input_as_handled()
			allocate(STAT_EDGE)
		KEY_ENTER, KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			close()
		KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()


## P-key toggle behavior. Open if closed-and-bank>0; close if currently open.
## Public so tests can drive without raising real input events (mirrors
## `force_press_for_test` for the in-panel keys).
func force_p_keypress_for_test() -> void:
	_handle_toggle_keypress()


func _handle_toggle_keypress() -> void:
	if _open:
		# Toggle close — banks any remaining points (LU-22 / Esc-equivalent).
		close()
		return
	# Closed — only open if there are points to spend. An empty bank means
	# the HUD pip is hidden anyway and there's nothing for the player to do.
	if _get_unspent() <= 0:
		return
	open(false)


# ---- Auto-open (LU-05) -----------------------------------------------

## Internal handler for `Levels.level_up`. Increments banked points (the
## level-up grants +1 stat point per level) and opens the panel on the
## first ever level-up for this character (LU-05). Subsequent level-ups
## just bump the banked count — the HUD pip cues the player to press P.
func _on_level_up(_new_level: int) -> void:
	var ps: Node = _player_stats()
	if ps == null:
		return
	ps.add_unspent_points(1)
	if not _has_seen_first_level_up():
		_mark_first_level_up_seen()
		open(true)
	else:
		# If the panel is already open (mid-multi-level catch-up), refresh
		# the header to show the new bank count.
		if _open:
			_refresh_header()


# ---- UI build --------------------------------------------------------

func _build_ui() -> void:
	# Background band — bottom-anchored, full canvas width. Uma spec ~280
	# px tall on the 1280x720 reference; on the 480x270 internal canvas
	# the equivalent ratio is ~105 px. We anchor with PRESET_BOTTOM_WIDE
	# so it adapts to whatever output viewport Devon's Main scene has.
	_bg_panel = ColorRect.new()
	_bg_panel.name = "BandBackground"
	_bg_panel.color = COLOR_PANEL_BG
	_bg_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bg_panel.offset_top = -280.0
	_bg_panel.offset_bottom = 0.0
	_bg_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg_panel)

	# 1 px ember-orange top edge — Uma "1 px ember-orange top-edge bar".
	var top_bar: ColorRect = ColorRect.new()
	top_bar.name = "TopEdgeBar"
	top_bar.color = COLOR_EMBER
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_top = 0.0
	top_bar.offset_bottom = 1.0
	_bg_panel.add_child(top_bar)

	# Header label — "LEVEL UP — Spend N stat points".
	_header_label = Label.new()
	_header_label.name = "HeaderLabel"
	_header_label.text = HEADER_TEXT_SINGLE
	_header_label.add_theme_color_override("font_color", COLOR_EMBER)
	_header_label.add_theme_font_size_override("font_size", 18)
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_header_label.offset_left = -300.0
	_header_label.offset_right = 300.0
	_header_label.offset_top = 16.0
	_header_label.offset_bottom = 44.0
	_bg_panel.add_child(_header_label)

	# Three tiles — VIGOR / FOCUS / EDGE.
	_build_tile(STAT_VIGOR, -260)
	_build_tile(STAT_FOCUS,    0)
	_build_tile(STAT_EDGE,   260)

	# Hint label at the bottom edge.
	_hint_label = Label.new()
	_hint_label.name = "HintLabel"
	_hint_label.text = HINT_TEXT
	_hint_label.add_theme_color_override("font_color", COLOR_HINT)
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_label.offset_left = -360.0
	_hint_label.offset_right = 360.0
	_hint_label.offset_top = -28.0
	_hint_label.offset_bottom = -8.0
	_bg_panel.add_child(_hint_label)


func _build_tile(stat_id: StringName, x_offset: float) -> void:
	# Each tile is a PanelContainer with a 1 px ember outline; children are
	# name + current->next labels + +1 button.
	var tile: PanelContainer = PanelContainer.new()
	tile.name = "Tile_%s" % str(stat_id)
	tile.set_anchors_preset(Control.PRESET_CENTER)
	tile.offset_left = x_offset - 110.0
	tile.offset_right = x_offset + 110.0
	tile.offset_top = -60.0
	tile.offset_bottom = 60.0
	# A StyleBoxFlat for the panel border; pulls Uma's palette.
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(COLOR_PANEL_BG.r, COLOR_PANEL_BG.g, COLOR_PANEL_BG.b, 1.0)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = COLOR_PANEL_BORDER
	tile.add_theme_stylebox_override("panel", sb)
	_bg_panel.add_child(tile)

	# Vertical layout inside the tile.
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	tile.add_child(vbox)

	# Name (VIGOR / FOCUS / EDGE) — pulled from StatStrings at refresh time.
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", COLOR_EMBER)
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)

	# Sub-header (italic muted parchment vibe phrase).
	var sub_label: Label = Label.new()
	sub_label.name = "SubHeaderLabel"
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_color_override("font_color", COLOR_HINT)
	sub_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(sub_label)

	# Current -> next preview (e.g., "0 -> 1" — load-bearing data).
	var value_label: Label = Label.new()
	value_label.name = "ValueLabel"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_color_override("font_color", COLOR_BODY)
	value_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(value_label)

	# Tooltip body — multi-line "+5 max HP per point" style.
	var body_label: Label = Label.new()
	body_label.name = "BodyLabel"
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.add_theme_color_override("font_color", COLOR_BODY)
	body_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(body_label)

	# +1 button — clicking allocates immediately (mouse-equivalent of 1/2/3).
	var alloc_button: Button = Button.new()
	alloc_button.name = "AllocButton"
	alloc_button.text = "+ 1"
	alloc_button.custom_minimum_size = Vector2(80, 24)
	alloc_button.add_theme_color_override("font_color", COLOR_BODY)
	alloc_button.pressed.connect(_on_alloc_button_pressed.bind(stat_id))
	vbox.add_child(alloc_button)

	# Keybind hint (1 / 2 / 3) at the bottom of the tile.
	var keybind_label: Label = Label.new()
	keybind_label.name = "KeybindLabel"
	var keybind_text: String = ""
	match stat_id:
		STAT_VIGOR: keybind_text = "<1>"
		STAT_FOCUS: keybind_text = "<2>"
		STAT_EDGE:  keybind_text = "<3>"
	keybind_label.text = keybind_text
	keybind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keybind_label.add_theme_color_override("font_color", COLOR_HINT)
	keybind_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(keybind_label)

	# Cache the per-tile node refs so refresh is O(1).
	_tiles[stat_id] = {
		"panel": tile,
		"name_label": name_label,
		"sub_label": sub_label,
		"value_label": value_label,
		"body_label": body_label,
		"alloc_button": alloc_button,
		"keybind_label": keybind_label,
	}


func _refresh_tiles() -> void:
	if _stat_strings == null:
		return
	for stat_id_v: Variant in _tiles.keys():
		var stat_id: StringName = stat_id_v
		var tile: Dictionary = _tiles[stat_id]
		var current: int = _get_stat(stat_id)
		var nxt: int = current + 1
		(tile["name_label"] as Label).text = _stat_strings.get_header(stat_id)
		(tile["sub_label"] as Label).text = _stat_strings.get_sub_header(stat_id)
		(tile["value_label"] as Label).text = "%d -> %d" % [current, nxt]
		(tile["body_label"] as Label).text = _stat_strings.get_body(stat_id)


func _refresh_header() -> void:
	if _header_label == null:
		return
	var n: int = _get_unspent()
	if n <= 1:
		_header_label.text = HEADER_TEXT_SINGLE
	else:
		_header_label.text = HEADER_TEXT_MULTI_FMT % n


func _on_alloc_button_pressed(stat_id: StringName) -> void:
	allocate(stat_id)


# ---- Helpers ----------------------------------------------------------

func _is_known_stat(stat_id: StringName) -> bool:
	return stat_id == STAT_VIGOR or stat_id == STAT_FOCUS or stat_id == STAT_EDGE


func _load_strings() -> void:
	var res: Resource = load(STAT_STRINGS_PATH)
	if res != null and res is StatStrings:
		_stat_strings = res
	else:
		# Fallback to a fresh StatStrings instance with the defaults baked
		# into the @export defaults of the script. Keeps the panel from
		# crashing if the .tres is missing (e.g. a hot-reload race).
		push_warning("[StatAllocationPanel] could not load %s — using defaults" % STAT_STRINGS_PATH)
		_stat_strings = StatStrings.new()


func _player_stats() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null("PlayerStats")


func _levels() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null("Levels")


func _save_node() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null("Save")


func _get_stat(stat_id: StringName) -> int:
	var ps: Node = _player_stats()
	if ps == null:
		return 0
	return int(ps.get_stat(stat_id))


func _get_unspent() -> int:
	var ps: Node = _player_stats()
	if ps == null:
		return 0
	return int(ps.get_unspent_points())


# ---- First-level-up persistence (LU-05 / LU-06) ----------------------

## Returns true if the player has already seen their first level-up. The
## flag lives on the save file's character block so it survives quit-and-
## relaunch but resets on a fresh new-character flow.
func _has_seen_first_level_up() -> bool:
	var save_node: Node = _save_node()
	if save_node == null:
		return false
	var data: Dictionary = save_node.load_game(SAVE_SLOT)
	if data.is_empty():
		return false
	var character: Variant = data.get("character", null)
	if not (character is Dictionary):
		return false
	return bool((character as Dictionary).get("first_level_up_seen", false))


func _mark_first_level_up_seen() -> void:
	var save_node: Node = _save_node()
	if save_node == null:
		return
	var data: Dictionary = save_node.load_game(SAVE_SLOT)
	if data.is_empty():
		data = save_node.default_payload()
	if not (data.get("character", null) is Dictionary):
		data["character"] = save_node.default_payload()["character"]
	(data["character"] as Dictionary)["first_level_up_seen"] = true
	# Snapshot current PlayerStats / Levels into the save dict so we don't
	# clobber other live state with the default payload's zero values.
	_snapshot_runtime_into(data)
	save_node.save_game(SAVE_SLOT, data)


func _persist_to_save() -> void:
	var save_node: Node = _save_node()
	if save_node == null:
		return
	var data: Dictionary = save_node.load_game(SAVE_SLOT)
	if data.is_empty():
		data = save_node.default_payload()
	_snapshot_runtime_into(data)
	save_node.save_game(SAVE_SLOT, data)


func _snapshot_runtime_into(data: Dictionary) -> void:
	if not (data.get("character", null) is Dictionary):
		var save_node: Node = _save_node()
		data["character"] = save_node.default_payload()["character"] if save_node != null else {}
	var character: Dictionary = data["character"]
	# Pull V/F/E and unspent into character.stats / character.unspent_stat_points.
	var ps: Node = _player_stats()
	if ps != null and ps.has_method("snapshot_to_character"):
		ps.snapshot_to_character(character)
	# Also snapshot Levels state so we don't reset level/xp on a save called
	# mid-allocation.
	var lv: Node = _levels()
	if lv != null and lv.has_method("snapshot_to_character"):
		lv.snapshot_to_character(character)
