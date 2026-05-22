class_name DialoguePanel
extends CanvasLayer
## Modal dialogue UI — subscribes to `DialogueController` signals and renders
## the active session: NPC name + placeholder portrait, current line, response
## buttons (when presented).
##
## **Spike scope — ticket `86c9xuab3` (M3 Tier 3 W1 dialogue system spike).**
## See `.claude/docs/dialogue-system.md` for the full architecture.
##
## ## Architecture
##
## Pure view. The controller owns session state; the panel reads from the
## controller and writes via `advance_line` / `select_response` / `close`.
## All UI is built procedurally in `_ready` so the .tscn is a single
## CanvasLayer node (consistent with the InventoryPanel pattern).
##
## ## Input model (per Uma `visual-direction.md` keyboard-first rule)
##
##   - `E` advances to the next line. Handled in `_input()` (BEFORE Godot's
##     GUI focus system) so a focused response Button can't swallow it.
##     Per `.claude/docs/html5-export.md` § "Godot input handling order":
##     Tab is the canonical example of why UI-shortcut bindings must use
##     `_input()`, not `_unhandled_input()`. `E` shares the trap class
##     when a Button has focus during the response-prompt phase.
##   - `Esc` closes immediately.
##   - Arrow Up / Down cycle focus across response buttons.
##   - `Enter` / `Space` activate the focused button (Godot default —
##     `ui_accept` action).
##   - Number keys 1-4 quick-select the corresponding response (gameplay
##     convention; faster than arrow-cycling for short lists).
##
## ## Color palette (mirrors InventoryPanel for tonal consistency)
##
## Uma `palette.md`. All channels strictly sub-1.0 — HTML5 HDR-clamp safe.
##
## ## Renderer-safety notes (per `.claude/docs/html5-export.md`)
##
## All visible elements are `Label` / `Button` / `ColorRect` / `RichTextLabel`.
## No Polygon2D, CPUParticles2D, Area2D, modulate-on-leaf-Control tween,
## negative z_index, or U+2713-class non-ASCII glyphs. Per the escape-clause
## eligibility rules in html5-export.md § "Visual-verification escape clause",
## this panel is escape-clause-eligible — release-build HTML5 verification
## is documented in the Self-Test Report (probe targets listed) and routed
## to Sponsor soak rather than blocking on local renderer access.

# ---- Signals ---------------------------------------------------------

signal panel_opened()
signal panel_closed()

# ---- Tuning ----------------------------------------------------------

## Layer above HUD + InventoryPanel (PANEL_LAYER = 80). DialoguePanel sits
## above inventory so a future "dialogue-during-inventory" path renders
## correctly (not in spike scope — controller's single-session guard
## prevents it, but the layer ordering future-proofs).
const PANEL_LAYER: int = 90

## Input actions (Godot built-ins). `ui_accept` = Enter/Space; `ui_cancel`
## = Escape. `E` is matched by physical_keycode (no project action — mirrors
## DebugFlags.gd's chord-by-physical_keycode pattern; works regardless of
## keyboard layout).
const ACTION_CANCEL: StringName = &"ui_cancel"
const ACTION_UP: StringName = &"ui_up"
const ACTION_DOWN: StringName = &"ui_down"

# ---- Palette (Uma `palette.md`) -------------------------------------

const COLOR_PANEL_BG: Color = Color(0.10588235, 0.10196078, 0.12156863, 0.92)
const COLOR_PANEL_BORDER: Color = Color(0.18431373, 0.16470588, 0.2, 1.0)
const COLOR_EMBER: Color = Color(1.0, 0.4156862745, 0.1647058824, 1.0)
const COLOR_BODY: Color = Color(0.9098, 0.8941, 0.8392, 1.0)
const COLOR_HINT: Color = Color(0.7215686275, 0.6745098039, 0.5568627451, 1.0)
const COLOR_PORTRAIT_PLACEHOLDER: Color = Color(0.3, 0.27, 0.32, 1.0)

# ---- Layout (px, on a 1280x720 viewport) -----------------------------

const PANEL_WIDTH: float = 960.0
const PANEL_HEIGHT: float = 280.0
const PORTRAIT_SIZE: Vector2 = Vector2(96, 96)
const RESPONSE_BUTTON_MIN_HEIGHT: float = 32.0
const NUMBER_PREFIX_FMT: String = "%d. "

# ---- Runtime ---------------------------------------------------------

var _open: bool = false

# Built-up node refs.
var _bg_panel: ColorRect = null
var _border_top: ColorRect = null
var _portrait: ColorRect = null
var _name_label: Label = null
var _line_label: RichTextLabel = null
var _continue_hint: Label = null
var _response_container: VBoxContainer = null
var _response_buttons: Array[Button] = []


# ---- Lifecycle ------------------------------------------------------

func _ready() -> void:
	layer = PANEL_LAYER
	_build_ui()
	visible = false
	# Subscribe to DialogueController signals — opens / line-advances / response
	# prompts / closes. Controller is an autoload; safe to lookup at _ready.
	var dc: Node = _controller_node()
	if dc == null:
		# DialogueController autoload missing — spike-test contexts may bare-
		# instance the panel without booting the autoload. Don't push_warning
		# from a UI-side wiring failure; just render no content.
		return
	if dc.has_signal("branch_opened"):
		dc.connect("branch_opened", _on_branch_opened)
	if dc.has_signal("line_displayed"):
		dc.connect("line_displayed", _on_line_displayed)
	if dc.has_signal("responses_presented"):
		dc.connect("responses_presented", _on_responses_presented)
	if dc.has_signal("dialogue_closed"):
		dc.connect("dialogue_closed", _on_dialogue_closed)


## Safety guard — if the panel is freed mid-session, force-close the
## controller so a stuck `_active=true` doesn't permanently gate player
## input. Mirrors InventoryPanel._exit_tree's Engine.time_scale safety.
func _exit_tree() -> void:
	if not _open:
		return
	var dc: Node = _controller_node()
	if dc != null and dc.has_method("close"):
		dc.close()
	_open = false


# ---- Public API ----------------------------------------------------

func is_open() -> bool:
	return _open


# ---- Input ----------------------------------------------------------

## Handled BEFORE the GUI focus system per `.claude/docs/html5-export.md` §
## "Godot input handling order". A focused response Button (during the
## response-prompt phase) would otherwise swallow `E` (Button's default
## click-on-keypress for the Space / Enter equivalent doesn't include E,
## but Godot's focus traversal can still eat plain alphabetic keys in some
## paths — defensive). Esc and arrows could live in `_unhandled_input`
## (they don't conflict with Godot's built-in GUI semantics in a way that
## affects this panel), but routing all dialogue input through one handler
## keeps the gating uniform.
func _input(event: InputEvent) -> void:
	if not _open:
		return
	if not (event is InputEventKey):
		return
	var ke: InputEventKey = event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	# Esc — always closes via controller.
	if event.is_action_pressed(ACTION_CANCEL):
		get_viewport().set_input_as_handled()
		var dc_close: Node = _controller_node()
		if dc_close != null and dc_close.has_method("close"):
			dc_close.close()
		return
	# E — advance line (only meaningful during line-display phase, but
	# controller is the gate; panel forwards unconditionally).
	if ke.physical_keycode == KEY_E:
		get_viewport().set_input_as_handled()
		var dc_advance: Node = _controller_node()
		if dc_advance != null and dc_advance.has_method("advance_line"):
			dc_advance.advance_line()
		return
	# Number keys 1-4 — quick-select response. Only meaningful when buttons
	# are presented; controller rejects out-of-range with a WarningBus warn,
	# so we filter here against the live button count to keep the trace clean.
	if _response_buttons.size() > 0:
		var num: int = _digit_for_key(ke.physical_keycode)
		if num >= 1 and num <= _response_buttons.size():
			get_viewport().set_input_as_handled()
			_invoke_response(num - 1)
			return
	# Arrow up/down — focus cycling across response buttons. We let Godot's
	# default focus traversal handle this; this branch is a no-op placeholder
	# in case a future tweak needs it.


func _digit_for_key(physical_keycode: int) -> int:
	# Map main-row 1..4 + numpad 1..4. Godot's KEY_1..KEY_4 are the main row;
	# KEY_KP_1..KEY_KP_4 are numpad. We accept both.
	match physical_keycode:
		KEY_1, KEY_KP_1:
			return 1
		KEY_2, KEY_KP_2:
			return 2
		KEY_3, KEY_KP_3:
			return 3
		KEY_4, KEY_KP_4:
			return 4
		_:
			return -1


# ---- DialogueController signal handlers ---------------------------

func _on_branch_opened(_npc_id: StringName, _branch_key: StringName) -> void:
	# First branch_opened fires from open() — that's our "show panel" trigger.
	# Subsequent branch_opened (from response navigation) keeps the panel
	# visible; we just refresh the header.
	if not _open:
		_open = true
		visible = true
		panel_opened.emit()
	_refresh_header()
	_clear_responses()
	_continue_hint.visible = true


func _on_line_displayed(_line_index: int, line_text: String) -> void:
	_line_label.text = line_text
	_continue_hint.visible = true


func _on_responses_presented(responses: Array) -> void:
	_continue_hint.visible = false
	_render_responses(responses)


func _on_dialogue_closed(_npc_id: StringName) -> void:
	if not _open:
		return
	_open = false
	visible = false
	_clear_responses()
	panel_closed.emit()


# ---- View refresh --------------------------------------------------

func _refresh_header() -> void:
	var dc: Node = _controller_node()
	if dc == null:
		return
	var name: String = ""
	if dc.has_method("current_display_name"):
		name = dc.current_display_name()
	if name == "":
		# Fall back to npc_id if display_name is empty (authoring slip).
		if dc.has_method("current_npc_id"):
			name = str(dc.current_npc_id())
	_name_label.text = name


func _render_responses(responses: Array) -> void:
	_clear_responses()
	for i in responses.size():
		var response: DialogueResponse = responses[i] as DialogueResponse
		if response == null:
			continue
		var btn: Button = Button.new()
		btn.name = "ResponseBtn_%d" % i
		# "1. Accept the bounty" — number prefix lets player number-key select
		# without a separate visual hint per button.
		btn.text = (NUMBER_PREFIX_FMT % (i + 1)) + response.text
		btn.add_theme_color_override("font_color", COLOR_BODY)
		btn.add_theme_font_size_override("font_size", 14)
		btn.custom_minimum_size = Vector2(0, RESPONSE_BUTTON_MIN_HEIGHT)
		btn.focus_mode = Control.FOCUS_ALL
		# Bind the controller-side index so the live array's order matches
		# the panel's button order.
		btn.pressed.connect(_on_response_button_pressed.bind(i))
		_response_container.add_child(btn)
		_response_buttons.append(btn)
	if _response_buttons.size() > 0:
		# Focus the first button so keyboard nav (arrows + Enter) works
		# immediately without a mouse-hover prerequisite.
		_response_buttons[0].grab_focus()


func _clear_responses() -> void:
	for btn: Button in _response_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_response_buttons.clear()


func _on_response_button_pressed(idx: int) -> void:
	_invoke_response(idx)


func _invoke_response(idx: int) -> void:
	var dc: Node = _controller_node()
	if dc == null:
		return
	if not dc.has_method("select_response"):
		return
	dc.select_response(idx)


# ---- UI build ------------------------------------------------------

func _build_ui() -> void:
	# Background — bottom-anchored panel (Diablo-style dialogue ribbon).
	_bg_panel = ColorRect.new()
	_bg_panel.name = "Background"
	_bg_panel.color = COLOR_PANEL_BG
	# Anchor to bottom-center.
	_bg_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bg_panel.offset_left = -PANEL_WIDTH * 0.5
	_bg_panel.offset_right = PANEL_WIDTH * 0.5
	_bg_panel.offset_top = -PANEL_HEIGHT - 32.0  # 32 px margin from bottom edge
	_bg_panel.offset_bottom = -32.0
	_bg_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg_panel)

	# 1 px ember top edge — consistent with InventoryPanel.
	_border_top = ColorRect.new()
	_border_top.name = "TopEdgeBar"
	_border_top.color = COLOR_EMBER
	_border_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_border_top.offset_top = 0.0
	_border_top.offset_bottom = 1.0
	_bg_panel.add_child(_border_top)

	# Portrait placeholder — left-aligned ColorRect. Spike-only; real portraits
	# arrive in Sub-track 5d (stratum NPC sprites).
	_portrait = ColorRect.new()
	_portrait.name = "PortraitPlaceholder"
	_portrait.color = COLOR_PORTRAIT_PLACEHOLDER
	_portrait.position = Vector2(16, 16)
	_portrait.size = PORTRAIT_SIZE
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_panel.add_child(_portrait)

	# NPC name label — to the right of the portrait, top.
	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.add_theme_color_override("font_color", COLOR_EMBER)
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.position = Vector2(16 + PORTRAIT_SIZE.x + 16, 16)
	_name_label.size = Vector2(PANEL_WIDTH - PORTRAIT_SIZE.x - 48, 24)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_panel.add_child(_name_label)

	# Line text — RichTextLabel for BBCode (ember-keyword convention from
	# Uma's brief; ticket allows BBCode in lines for emphasis).
	_line_label = RichTextLabel.new()
	_line_label.name = "LineLabel"
	_line_label.bbcode_enabled = true
	_line_label.fit_content = true
	_line_label.scroll_active = false
	_line_label.add_theme_color_override("default_color", COLOR_BODY)
	_line_label.add_theme_font_size_override("normal_font_size", 14)
	_line_label.position = Vector2(16 + PORTRAIT_SIZE.x + 16, 16 + 24 + 8)
	_line_label.size = Vector2(PANEL_WIDTH - PORTRAIT_SIZE.x - 48,
			PORTRAIT_SIZE.y + 16 - 24 - 8)
	_line_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_panel.add_child(_line_label)

	# Continue hint — bottom-right of header area, visible during line-display
	# phase, hidden during response-prompt phase.
	_continue_hint = Label.new()
	_continue_hint.name = "ContinueHint"
	_continue_hint.text = "[E] continue   [Esc] close"
	_continue_hint.add_theme_color_override("font_color", COLOR_HINT)
	_continue_hint.add_theme_font_size_override("font_size", 11)
	_continue_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_continue_hint.offset_left = -260
	_continue_hint.offset_top = -22
	_continue_hint.offset_right = -16
	_continue_hint.offset_bottom = -6
	_continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_continue_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_panel.add_child(_continue_hint)

	# Response container — VBox below the line area. Buttons populate when
	# `responses_presented` fires.
	_response_container = VBoxContainer.new()
	_response_container.name = "ResponseContainer"
	_response_container.add_theme_constant_override("separation", 4)
	_response_container.position = Vector2(16 + PORTRAIT_SIZE.x + 16,
			16 + PORTRAIT_SIZE.y + 16)
	_response_container.size = Vector2(PANEL_WIDTH - PORTRAIT_SIZE.x - 48,
			PANEL_HEIGHT - PORTRAIT_SIZE.y - 48)
	_bg_panel.add_child(_response_container)


# ---- Helpers --------------------------------------------------------

func _controller_node() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null("DialogueController")
