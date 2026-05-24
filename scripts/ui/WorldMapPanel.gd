class_name WorldMapPanel
extends CanvasLayer
## Minimal world-map UI — per-stratum parchment overlay with zone-state
## markers. M3 Tier 3 W2-T5 ship-floor (ticket `86c9y10fv`).
##
## ## Architecture
##
## Pure view. Reads `Player.discovered_zones` + the `ZoneDef.tres` registry
## under `res://resources/level/zones/` + `meta.deepest_stratum` for the
## stratum-unlock state. Does NOT write player/save state — the discovery
## hook lives in `Main._load_room_at_index` (ticket Part D).
##
## All UI is built procedurally in `_ready` (consistent with InventoryPanel
## + DialoguePanel + DescendScreen patterns) so the `.tscn` is a single
## CanvasLayer node — no editor-authored Control hierarchy to maintain.
##
## ## Visual primitives (renderer-safety) — per `.claude/docs/html5-export.md`
##
## All visible elements are `Label` / `Button` / `ColorRect`. No Polygon2D
## (PR #137 gl_compatibility risk), no CPUParticles2D, no Area2D, no
## negative z_index. Zone-state markers are rendered as **geometry, not
## Unicode glyphs** (per `html5-export.md` § "Default-font glyph coverage"
## — U+2713 `✓` renders as tofu in HTML5; PR #179 cautionary tale + Uma
## world-map-direction.md §6 directive).
##
## Per the escape-clause eligibility rules in html5-export.md §
## "Visual-verification escape clause", this panel is escape-clause-
## eligible — Self-Test Report enumerates probe targets for the
## descent-portal-open path; author self-soak per the
## `html5-visual-gated-author-self-soak` rule is mandatory regardless.
##
## ## Input model
##
##   - `Esc` closes the panel via the `close_requested` signal (host
##     decides whether to free or hide; DescendScreen frees its child
##     instance after each open).
##
## Number-key / arrow-key navigation across stratum + zone lists is
## **out-of-scope** for W2-T5 (M4 polish per Uma's world-map-direction.md
## §5). Default-selection mouse-click is the only interactive path.
##
## ## Color palette (Uma `palette.md` / `world-map-direction.md` §2)
##
## All channels strictly sub-1.0 — HTML5 HDR-clamp safe.

# ---- Signals ---------------------------------------------------------

## Player pressed Esc OR clicked the close affordance. Owning host
## (DescendScreen / hub-town wiring) decides whether to free or hide.
signal close_requested

# ---- Tuning ----------------------------------------------------------

## Layer between InventoryPanel (80) and DialoguePanel (90). Per
## `.claude/docs/dialogue-system.md` § "CanvasLayer + PANEL_LAYER ordering"
## — DialoguePanel sits above WorldMap so a future "dialogue while map open"
## interaction renders correctly. InventoryPanel sits below so an inventory
## toggle while the map is open renders inventory under the map (rare path;
## single-session controllers prevent it today, but layer ordering future-
## proofs).
const PANEL_LAYER: int = 70

## Input actions (Godot built-ins). `ui_cancel` = Escape.
const ACTION_CANCEL: StringName = &"ui_cancel"

# ---- Palette (Uma `palette.md`) -------------------------------------

## Modal background — `#1B1A1F` at 92% (matches inventory-panel chrome).
const COLOR_MODAL_BG: Color = Color(0.10588235, 0.10196078, 0.12156863, 0.92)
## Parchment substrate — `#D7C68F` Outer Cloister accent.
const COLOR_PARCHMENT: Color = Color(0.84313725, 0.77647059, 0.56078431, 1.0)
## Ember accent — `#FF6A2A`. Stratum-list selection highlight + quest-target
## marker color.
const COLOR_EMBER: Color = Color(1.0, 0.41568627, 0.16470588, 1.0)
## HUD body text — `#E8E4D6`.
const COLOR_BODY: Color = Color(0.9098, 0.8941, 0.8392, 1.0)
## Muted parchment — `#B8AC8E`. Subtitle / undiscovered-zone label color.
const COLOR_MUTED: Color = Color(0.72156863, 0.6745098, 0.55686275, 1.0)
## Dark ink — `#1B1A1F`. Used for zone-marker outlines, the cleared-X cross,
## and edge-line strokes against the parchment substrate.
const COLOR_INK: Color = Color(0.10588235, 0.10196078, 0.12156863, 1.0)
## Boss-room marker — `#7A2A26` mob-HP-foreground (reads as "danger here").
## Reserved color discipline: NOT ember-orange (ember-orange is the
## quest-target stamp; conflating would dilute the signal).
const COLOR_BOSS: Color = Color(0.47843137, 0.16470588, 0.14901961, 1.0)
## Stratum-locked label — `#3A363D` cell-empty-border slate (the strata the
## player has not yet unlocked).
const COLOR_LOCKED: Color = Color(0.22745098, 0.21176471, 0.23921569, 1.0)

# ---- Layout (px, on a 1280x720 viewport) -----------------------------

const MODAL_WIDTH: float = 960.0
const MODAL_HEIGHT: float = 540.0
const PARCHMENT_INSET: float = 32.0
const STRATUM_LIST_WIDTH: float = 240.0
const STRATUM_ROW_HEIGHT: float = 40.0
const ZONE_ROW_HEIGHT: float = 32.0
const ZONE_MARKER_SIZE: float = 16.0
const ZONE_MARKER_LABEL_GAP: float = 12.0
const HEADER_HEIGHT: float = 56.0
const ZONE_LIST_TOP_PADDING: float = 16.0

## Default zone-registry root scanned at boot. The single shipped S1 zone
## (`s1_z1_outer_cloister.tres`) is the only authored zone at W2-T5 time;
## additional zones (S2+, S1 expansion) drop in by adding `.tres` files
## here — no panel code edit. Scanned via `DirAccess` recursion at
## `_ready` so the panel discovers zones by directory convention rather
## than a registry autoload (lower risk surface: missing dir = empty
## panel instead of a missing-autoload crash on bare-test surfaces).
const ZONE_REGISTRY_ROOT: String = "res://resources/level/zones"

# ---- Runtime ---------------------------------------------------------

var _open: bool = false
var _selected_stratum: int = 1
var _zones_by_stratum: Dictionary = {}  # int -> Array[ZoneDef]
var _deepest_stratum: int = 1

# Built-up node refs (procedural UI; tests can verify via these accessors).
var _modal_bg: ColorRect = null
var _parchment: ColorRect = null
var _header_label: Label = null
var _close_hint: Label = null
var _stratum_list_container: VBoxContainer = null
var _zone_list_container: VBoxContainer = null
var _stratum_buttons: Array[Button] = []
var _zone_rows: Array[Control] = []

# ---- Lifecycle ------------------------------------------------------


func _ready() -> void:
	layer = PANEL_LAYER
	_load_zone_registry()
	_resolve_deepest_stratum()
	_build_ui()
	_render_stratum_list()
	_render_zone_list()
	_emit_open_trace()


func _exit_tree() -> void:
	# Defensive — if the panel is freed mid-open, host listeners get the
	# close signal so they can release any modal-open input gate. Mirrors
	# DialoguePanel._exit_tree's safety.
	if _open:
		_open = false


# ---- Public API ----------------------------------------------------


func is_open() -> bool:
	return _open


## Returns the number of stratum-row Buttons currently rendered. Tests
## use this to pin the stratum-list-render contract.
func stratum_button_count() -> int:
	return _stratum_buttons.size()


## Returns the number of zone-row Controls currently rendered. Tests use
## this to pin the per-stratum zone-list-render contract.
func zone_row_count() -> int:
	return _zone_rows.size()


## Returns the integer stratum id currently selected (drives the zone-list
## pane). 1 by default. Tests + DescendScreen integration read this.
func get_selected_stratum() -> int:
	return _selected_stratum


## Test seam — inject a mocked `Player.discovered_zones` dict so GUT tests
## can verify per-zone-state rendering without booting Main's full save
## stack. The setter forces a zone-list re-render. Production callers
## should NOT use this; production reads from the live Player node.
func set_discovered_zones_for_test(d: Dictionary) -> void:
	if _player_node() != null:
		(_player_node() as Node).set("discovered_zones", d)
	_render_zone_list()


## Test seam — inject a mocked `meta.deepest_stratum` so GUT tests can
## verify locked-stratum styling without booting the full save stack.
func set_deepest_stratum_for_test(value: int) -> void:
	_deepest_stratum = max(1, value)
	_render_stratum_list()


# ---- Input ----------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if not (event is InputEventKey):
		return
	var ke: InputEventKey = event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if event.is_action_pressed(ACTION_CANCEL):
		get_viewport().set_input_as_handled()
		_emit_close()
		return


# ---- Registry load --------------------------------------------------


func _load_zone_registry() -> void:
	# Scan ZONE_REGISTRY_ROOT for .tres files; load each as ZoneDef. Errors
	# are swallowed (push_warning'd via WarningBus per .claude/docs/
	# test-conventions.md § "Universal warning gate") so a malformed zone
	# does not crash the panel — it just doesn't render. Three-pronged
	# fallback shape per html5-export.md § "Resource enumeration on packed
	# .pck resources" — we explicitly tolerate empty DirAccess output here
	# rather than panicking.
	_zones_by_stratum.clear()
	var dir: DirAccess = DirAccess.open(ZONE_REGISTRY_ROOT)
	if dir == null:
		# Empty registry — panel renders with no zones. Tests that bare-
		# instance the panel without a content tree land here.
		return
	dir.list_dir_begin()
	while true:
		var fname: String = dir.get_next()
		if fname == "":
			break
		if dir.current_is_dir():
			continue
		if not fname.ends_with(".tres"):
			continue
		var path: String = ZONE_REGISTRY_ROOT + "/" + fname
		var res: Resource = load(path)
		if res == null:
			continue
		if not (res is ZoneDef):
			continue
		var zd: ZoneDef = res as ZoneDef
		if zd.zone_id == &"":
			continue
		var s: int = zd.stratum_id
		if not _zones_by_stratum.has(s):
			_zones_by_stratum[s] = []
		(_zones_by_stratum[s] as Array).append(zd)
	dir.list_dir_end()


func _resolve_deepest_stratum() -> void:
	# Read `meta.deepest_stratum` via the Save autoload's in-memory payload
	# OR the StratumProgression autoload. Falls back to 1 if neither is
	# reachable (bare-test surface).
	var sp: Node = _stratum_progression()
	if sp != null and sp.has_method("get_deepest_stratum"):
		var deep: Variant = sp.call("get_deepest_stratum")
		if deep is int:
			_deepest_stratum = max(1, int(deep))
			return
	_deepest_stratum = 1


# ---- Render: stratum list ------------------------------------------


func _render_stratum_list() -> void:
	# Tear down + rebuild. Cheap for ≤8 strata. See `_render_zone_list` for
	# the remove_child-before-queue_free rationale (Godot's auto-rename on
	# name-collision with not-yet-removed siblings; PR #362 fix).
	for btn: Button in _stratum_buttons:
		if is_instance_valid(btn):
			if btn.get_parent() != null:
				btn.get_parent().remove_child(btn)
			btn.queue_free()
	_stratum_buttons.clear()
	# Determine all known strata (from registry + deepest_stratum). Always
	# show at least up to deepest_stratum even if no zone is authored yet
	# in that stratum — keeps the count diegetic ("you've been to S2, even
	# if the map for S2 is blank").
	var strata_set: Dictionary = {}
	for s in _zones_by_stratum.keys():
		strata_set[int(s)] = true
	for i in range(1, _deepest_stratum + 1):
		strata_set[i] = true
	# Sort ascending so S1 renders first.
	var strata_list: Array = strata_set.keys()
	strata_list.sort()
	for s_int in strata_list:
		var s: int = int(s_int)
		var btn: Button = Button.new()
		btn.name = "StratumBtn_%d" % s
		btn.text = "Stratum %d" % s
		btn.custom_minimum_size = Vector2(STRATUM_LIST_WIDTH - 16, STRATUM_ROW_HEIGHT)
		btn.focus_mode = Control.FOCUS_ALL
		# Locked strata render in muted slate + disabled (can't click).
		# Unlocked strata render in body text (or ember if selected).
		var is_locked: bool = s > _deepest_stratum
		var is_selected: bool = s == _selected_stratum and not is_locked
		var fg: Color = COLOR_LOCKED
		if not is_locked:
			fg = COLOR_EMBER if is_selected else COLOR_BODY
		btn.add_theme_color_override("font_color", fg)
		btn.add_theme_font_size_override("font_size", 16)
		btn.disabled = is_locked
		if not is_locked:
			btn.pressed.connect(_on_stratum_pressed.bind(s))
		_stratum_list_container.add_child(btn)
		_stratum_buttons.append(btn)


func _on_stratum_pressed(s: int) -> void:
	if s == _selected_stratum:
		return
	_selected_stratum = s
	_render_stratum_list()
	_render_zone_list()


# ---- Render: zone list (per selected stratum) ---------------------


func _render_zone_list() -> void:
	# IMPORTANT — remove_child BEFORE queue_free. `queue_free()` alone leaves
	# the node in the parent until the next process_frame, so a subsequent
	# `add_child` of a new node with the same name (e.g. `ZoneRow_<zone_id>`)
	# triggers Godot's auto-rename (`@ZoneRow_...@N`) and breaks
	# `find_child("ZoneRow_<zone_id>", true, false)` lookups in tests + the
	# discovery-state setter re-render path. Explicit remove_child detaches
	# the doomed node from the parent IMMEDIATELY so names are free to reuse.
	# (PR #362 regression-fix; ticket `86c9y10fv` Tess QA failure 2 + 3.)
	for row: Control in _zone_rows:
		if is_instance_valid(row):
			if row.get_parent() != null:
				row.get_parent().remove_child(row)
			row.queue_free()
	_zone_rows.clear()
	var zones: Array = _zones_by_stratum.get(_selected_stratum, [])
	if zones.is_empty():
		# Empty stratum — render a single muted label rather than nothing
		# so the player sees diegetic "nothing mapped yet" rather than a
		# silent blank pane.
		var lbl: Label = Label.new()
		lbl.name = "EmptyStratumLabel"
		lbl.text = "Nothing mapped yet."
		lbl.add_theme_color_override("font_color", COLOR_MUTED)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.custom_minimum_size = Vector2(0, ZONE_ROW_HEIGHT)
		_zone_list_container.add_child(lbl)
		_zone_rows.append(lbl)
		return
	var discovered: Dictionary = _resolve_discovered_zones()
	for zd_variant in zones:
		var zd: ZoneDef = zd_variant as ZoneDef
		if zd == null:
			continue
		var row: HBoxContainer = _build_zone_row(zd, discovered)
		_zone_list_container.add_child(row)
		_zone_rows.append(row)


func _build_zone_row(zd: ZoneDef, discovered: Dictionary) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ZoneRow_%s" % str(zd.zone_id)
	row.custom_minimum_size = Vector2(0, ZONE_ROW_HEIGHT)
	row.add_theme_constant_override("separation", int(ZONE_MARKER_LABEL_GAP))
	# Zone-state marker — geometry, NOT Unicode glyph (per html5-export.md
	# § "Default-font glyph coverage"). Marker shape encodes state:
	#   undiscovered  → small dim slate square
	#   discovered    → larger parchment square outlined in ink
	#   cleared       → parchment-square + two rotated ColorRect strokes
	#                   forming an X-cross (the cloister tally)
	#   boss room     → darker red square (always shown if stratum reached)
	# Quest-target overlay (ember-orange `!` Label) is composed on top of
	# whichever marker is at the active-quest zone. M3 W2 has no active-
	# quest data yet (Track 3 lands in W3); the panel reads
	# `Player.active_bounty.zone_id` defensively and skips the overlay if
	# null.
	var is_discovered: bool = bool(discovered.get(zd.zone_id, false))
	var is_boss: bool = _zone_has_boss_room(zd)
	# For W2-T5 ship-floor, "cleared" is conservatively `is_discovered`
	# (we have no per-zone cleared-state flag yet — that's Drew's W2-T3+
	# AssembledFloor / cleared_condition surface). The panel will pick up
	# the cleared flag when it lands without re-shipping; for now,
	# discovery is the highest state the panel renders below "boss room
	# defeated" which itself requires `meta.deepest_stratum > stratum_id`
	# (proxy: you got past this stratum's boss).
	var is_cleared: bool = is_discovered and _stratum_cleared(zd.stratum_id)
	var marker: Control = _build_zone_marker(is_discovered, is_cleared, is_boss)
	row.add_child(marker)
	var lbl: Label = Label.new()
	lbl.name = "ZoneLabel"
	lbl.text = zd.display_name if zd.display_name != "" else String(zd.zone_id)
	# Discovered = body color; undiscovered = muted; boss-cleared = ember
	# (the player has completed the deepest thing in this stratum, render
	# the row prominently). The ember override only applies when cleared
	# AND boss to keep the visual hierarchy stable.
	var fg: Color = COLOR_MUTED
	if is_discovered:
		fg = COLOR_EMBER if (is_cleared and is_boss) else COLOR_BODY
	lbl.add_theme_color_override("font_color", fg)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	return row


func _build_zone_marker(is_discovered: bool, is_cleared: bool, is_boss: bool) -> Control:
	# Use a parent Control with manual children so we can compose geometry
	# (e.g. cleared X-cross strokes on top of the base square). HBoxContainer
	# expects predictable sizing — pin a custom_minimum_size on the container.
	var holder: Control = Control.new()
	holder.name = "ZoneMarker"
	holder.custom_minimum_size = Vector2(ZONE_MARKER_SIZE, ZONE_MARKER_SIZE)
	# Base square. Color depends on state.
	var base: ColorRect = ColorRect.new()
	base.name = "MarkerBase"
	base.color = _resolve_marker_base_color(is_discovered, is_cleared, is_boss)
	base.size = Vector2(ZONE_MARKER_SIZE, ZONE_MARKER_SIZE)
	base.position = Vector2.ZERO
	holder.add_child(base)
	# Outline — 1 px ink border around the square for non-undiscovered
	# states (gives the marker visual weight against the parchment).
	if is_discovered:
		var outline: ColorRect = ColorRect.new()
		outline.name = "MarkerOutline"
		# 4 thin ColorRects forming a rectangle outline. Cheap and renderer-
		# safe; an actual Border node would route through theme-stylebox
		# code paths we don't need here.
		var thickness: float = 1.0
		var top_edge: ColorRect = ColorRect.new()
		top_edge.color = COLOR_INK
		top_edge.size = Vector2(ZONE_MARKER_SIZE, thickness)
		top_edge.position = Vector2(0, 0)
		holder.add_child(top_edge)
		var bot_edge: ColorRect = ColorRect.new()
		bot_edge.color = COLOR_INK
		bot_edge.size = Vector2(ZONE_MARKER_SIZE, thickness)
		bot_edge.position = Vector2(0, ZONE_MARKER_SIZE - thickness)
		holder.add_child(bot_edge)
		var left_edge: ColorRect = ColorRect.new()
		left_edge.color = COLOR_INK
		left_edge.size = Vector2(thickness, ZONE_MARKER_SIZE)
		left_edge.position = Vector2(0, 0)
		holder.add_child(left_edge)
		var right_edge: ColorRect = ColorRect.new()
		right_edge.color = COLOR_INK
		right_edge.size = Vector2(thickness, ZONE_MARKER_SIZE)
		right_edge.position = Vector2(ZONE_MARKER_SIZE - thickness, 0)
		holder.add_child(right_edge)
	# Cleared-state X-cross: two rotated ColorRect strokes forming a tally.
	# Per html5-export.md default-font-glyph rule + Uma world-map-direction
	# §6 primitive 4 — NEVER use `✓` Unicode here. Two rotated 2x10
	# ColorRects render identically across all renderers.
	if is_cleared:
		var stroke_a: ColorRect = ColorRect.new()
		stroke_a.name = "ClearedStrokeA"
		stroke_a.color = COLOR_INK
		# Stroke length sized to span most of the marker; width 2 px.
		var stroke_len: float = ZONE_MARKER_SIZE * 0.9
		stroke_a.size = Vector2(stroke_len, 2.0)
		# Rotate around center: position the rect so its center sits at
		# the marker center, then apply rotation around its pivot.
		stroke_a.pivot_offset = Vector2(stroke_len * 0.5, 1.0)
		stroke_a.position = Vector2(
			(ZONE_MARKER_SIZE - stroke_len) * 0.5,
			ZONE_MARKER_SIZE * 0.5 - 1.0,
		)
		stroke_a.rotation = deg_to_rad(45.0)
		holder.add_child(stroke_a)
		var stroke_b: ColorRect = ColorRect.new()
		stroke_b.name = "ClearedStrokeB"
		stroke_b.color = COLOR_INK
		stroke_b.size = Vector2(stroke_len, 2.0)
		stroke_b.pivot_offset = Vector2(stroke_len * 0.5, 1.0)
		stroke_b.position = Vector2(
			(ZONE_MARKER_SIZE - stroke_len) * 0.5,
			ZONE_MARKER_SIZE * 0.5 - 1.0,
		)
		stroke_b.rotation = deg_to_rad(-45.0)
		holder.add_child(stroke_b)
	return holder


func _resolve_marker_base_color(is_discovered: bool, _is_cleared: bool, is_boss: bool) -> Color:
	if not is_discovered:
		return COLOR_LOCKED
	if is_boss:
		return COLOR_BOSS
	return COLOR_PARCHMENT


func _zone_has_boss_room(zd: ZoneDef) -> bool:
	# Heuristic: a zone has a boss room if any anchor's kind is &"boss_room".
	for a in zd.anchors:
		if a == null:
			continue
		if a.anchor_kind == &"boss_room":
			return true
	return false


func _stratum_cleared(stratum_id: int) -> bool:
	# Proxy for "this stratum's boss has been defeated" — `deepest_stratum`
	# advances past `stratum_id` after the descend trigger fires. The proxy
	# is conservative: a player who killed the S1 boss and pressed Return
	# in the DescendScreen now has `deepest_stratum >= 2`, so S1 reads as
	# cleared. Players who killed the boss but quit before the descend
	# screen are NOT cleared by this proxy — same edge case as
	# StratumProgression's bookkeeping. Tighten in W3+ if needed.
	return _deepest_stratum > stratum_id


# ---- Discovery-state resolution -----------------------------------


func _resolve_discovered_zones() -> Dictionary:
	# Single source: the live Player node's `discovered_zones` field. Falls
	# back to empty dict on bare-test surfaces with no Player in the tree.
	var p: Node = _player_node()
	if p == null:
		return {}
	var d: Variant = p.get("discovered_zones")
	if not (d is Dictionary):
		return {}
	return d


# ---- UI build ------------------------------------------------------


func _build_ui() -> void:
	# Modal background.
	_modal_bg = ColorRect.new()
	_modal_bg.name = "ModalBackground"
	_modal_bg.color = COLOR_MODAL_BG
	_modal_bg.set_anchors_preset(Control.PRESET_CENTER)
	_modal_bg.offset_left = -MODAL_WIDTH * 0.5
	_modal_bg.offset_right = MODAL_WIDTH * 0.5
	_modal_bg.offset_top = -MODAL_HEIGHT * 0.5
	_modal_bg.offset_bottom = MODAL_HEIGHT * 0.5
	_modal_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_modal_bg)
	# Parchment substrate — sits inside the modal, with PARCHMENT_INSET
	# padding so the ember-orange chrome border (per Uma direction) reads
	# around the parchment.
	_parchment = ColorRect.new()
	_parchment.name = "Parchment"
	_parchment.color = COLOR_PARCHMENT
	_parchment.set_anchors_preset(Control.PRESET_FULL_RECT)
	_parchment.offset_left = PARCHMENT_INSET
	_parchment.offset_top = PARCHMENT_INSET
	_parchment.offset_right = -PARCHMENT_INSET
	_parchment.offset_bottom = -PARCHMENT_INSET
	_parchment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_bg.add_child(_parchment)
	# Header — "World Map" + close hint.
	_header_label = Label.new()
	_header_label.name = "HeaderLabel"
	_header_label.text = "World Map"
	_header_label.add_theme_color_override("font_color", COLOR_INK)
	_header_label.add_theme_font_size_override("font_size", 28)
	_header_label.position = Vector2(16, 8)
	_header_label.size = Vector2(MODAL_WIDTH - PARCHMENT_INSET * 2 - 32, HEADER_HEIGHT - 16)
	_header_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_parchment.add_child(_header_label)
	# Close hint — bottom-right of parchment.
	_close_hint = Label.new()
	_close_hint.name = "CloseHint"
	_close_hint.text = "[Esc] close"
	_close_hint.add_theme_color_override("font_color", COLOR_MUTED)
	_close_hint.add_theme_font_size_override("font_size", 12)
	_close_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_close_hint.offset_left = -120
	_close_hint.offset_top = -24
	_close_hint.offset_right = -16
	_close_hint.offset_bottom = -8
	_close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_close_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_parchment.add_child(_close_hint)
	# Stratum list container — left pane.
	_stratum_list_container = VBoxContainer.new()
	_stratum_list_container.name = "StratumListContainer"
	_stratum_list_container.add_theme_constant_override("separation", 4)
	_stratum_list_container.position = Vector2(16, HEADER_HEIGHT + 8)
	_stratum_list_container.size = Vector2(
		STRATUM_LIST_WIDTH,
		MODAL_HEIGHT - PARCHMENT_INSET * 2 - HEADER_HEIGHT - 24,
	)
	_parchment.add_child(_stratum_list_container)
	# Zone list container — right pane.
	_zone_list_container = VBoxContainer.new()
	_zone_list_container.name = "ZoneListContainer"
	_zone_list_container.add_theme_constant_override("separation", 4)
	_zone_list_container.position = Vector2(
		STRATUM_LIST_WIDTH + 32,
		HEADER_HEIGHT + 8 + ZONE_LIST_TOP_PADDING,
	)
	_zone_list_container.size = Vector2(
		MODAL_WIDTH - PARCHMENT_INSET * 2 - STRATUM_LIST_WIDTH - 48,
		MODAL_HEIGHT - PARCHMENT_INSET * 2 - HEADER_HEIGHT - 24 - ZONE_LIST_TOP_PADDING,
	)
	_parchment.add_child(_zone_list_container)
	_open = true
	visible = true


# ---- Internal helpers ---------------------------------------------


func _player_node() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	var nodes: Array = loop.get_nodes_in_group("player")
	if nodes.is_empty():
		return null
	var n: Node = nodes[0]
	if not is_instance_valid(n):
		return null
	return n


func _stratum_progression() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null("StratumProgression")


func _emit_open_trace() -> void:
	var df: Node = _debug_flags()
	if df == null:
		return
	if not df.has_method("combat_trace"):
		return
	df.combat_trace(
		"WorldMapPanel.opened",
		(
			"selected_stratum=%d strata=%d zones=%d"
			% [_selected_stratum, _stratum_buttons.size(), _zone_rows.size()]
		)
	)


func _debug_flags() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null("DebugFlags")


func _emit_close() -> void:
	_open = false
	close_requested.emit()
