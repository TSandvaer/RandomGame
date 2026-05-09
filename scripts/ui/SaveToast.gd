class_name SaveToast
extends Control
## Bottom-right "Saved" toast that fades in/out on every successful
## `Save.save_completed(slot, true)` emission. Per Uma's
## `team/uma-ux/m2-w1-ux-polish-design.md` § Ticket 2 (locked spec):
##
##   - Anchor: bottom-right, offset (-260, -64) from BOTTOM_RIGHT preset.
##   - Plate: 120 × 28 px ColorRect, panel-bg color at 85% alpha
##     (transient overlay vs. the InventoryPanel's permanent 92%).
##   - Pip:   8 × 8 px ColorRect, color #7AC773 (the shared positive-green
##     anchor — Inventory equipped indicator + this pip use the same hex).
##   - Text:  Label "Saved", body color #E8E4D6, font size 12.
##   - Animation: modulate.a tween only — no Polygon2D anywhere, all colors
##     sub-1.0, modulate scoped to this leaf Control (HTML5-safe per
##     `.claude/docs/html5-export.md` § HDR clamp + Polygon2D ban).
##
## Fade timeline (locked):
##   - Fade in:  modulate.a 0 → 1 over 0.20 s (LINEAR / EASE_OUT)
##   - Hold:     1.40 s at full alpha
##   - Fade out: modulate.a 1 → 0 over 0.60 s (LINEAR / EASE_IN)
##   - Total visible window: 2.20 s
##
## Throttle (locked): repeat saves while a toast is in flight extend the
## hold (kill + restart the tween from the current alpha). The visual effect
## is "the dot stays a little longer" — never two stacked toasts.
##
## **Failure path:** `save_completed(slot, false)` is intentionally ignored
## in M1 — the existing `push_error` console line is the failure surface
## (Tess + Sponsor watch for it). M2 may add a red-tinted "Save failed"
## variant.

# ---- Visual constants (Uma palette + design spec) -------------------

## Panel-bg color at 85% alpha — slightly more transparent than InventoryPanel
## (92%) so it reads as "transient overlay" rather than "permanent panel."
const COLOR_PLATE: Color = Color(0.10588235, 0.10196078, 0.12156863, 0.85)  # #1B1A1F @85%

## Shared positive-affirmation green — same hex as the InventoryPanel
## equipped-row outline + EQUIPPED badge plate (the M2 W1 polish wave's
## connecting visual thread). All channels strictly sub-1.0.
const COLOR_PIP: Color = Color(0.478, 0.780, 0.451, 1.0)  # #7AC773

## HUD body text — mirrors InventoryPanel's COLOR_BODY.
const COLOR_TEXT: Color = Color(0.9098, 0.8941, 0.8392, 1.0)  # #E8E4D6

# ---- Geometry constants (Uma design spec) -------------------------

const PLATE_SIZE: Vector2 = Vector2(120, 28)
const PIP_SIZE: Vector2 = Vector2(8, 8)
const PIP_OFFSET_LEFT: float = 8.0   # left margin inside the plate
const TEXT_OFFSET_LEFT: float = 24.0 # left of text within the plate

## Anchored bottom-right from the parent CanvasLayer / Control. Negative
## offsets pull inward from the screen edge.
const ANCHOR_OFFSET: Vector2 = Vector2(-260, -64)

# ---- Timing constants (Uma design spec) ----------------------------

const FADE_IN_DURATION: float = 0.20
const HOLD_DURATION: float = 1.40
const FADE_OUT_DURATION: float = 0.60

# ---- Runtime ----------------------------------------------------

## The Tween that drives the fade-in / hold / fade-out chain. Killed +
## restarted on every `save_completed(true)` so repeat saves throttle into
## one continuous toast (per design § "Throttle").
var _tween: Tween = null
var _plate: ColorRect = null
var _pip: ColorRect = null
var _label: Label = null


func _ready() -> void:
	_build_ui()
	# Hidden-but-not-freed at rest: alpha 0, but `visible = true` so the
	# tween can drive the alpha live. mouse_filter STOP would steal clicks
	# from the gameplay underneath; set IGNORE on the root + all children.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate = Color(1, 1, 1, 0.0)
	# Connect to the Save autoload's success signal. Defensive node lookup
	# because tests may stand up the toast in isolation without the autoload.
	var save_node: Node = _save_node()
	if save_node != null and save_node.has_signal("save_completed"):
		if not save_node.is_connected("save_completed", _on_save_completed):
			save_node.connect("save_completed", _on_save_completed)


# ---- Public API (test + integration) ---------------------------------

## Trigger the toast directly. Production code path goes through the
## `Save.save_completed` signal; this is the headless-test entry point so
## tests can drive the fade chain without standing up the Save autoload.
func show_saved() -> void:
	# Throttle: kill in-flight tween and restart from the current alpha.
	# The fade-in step uses the CURRENT alpha as its starting value, so a
	# repeat save mid-fade-out flips back up smoothly.
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_LINEAR)
	# Step 1: fade in to alpha 1.0
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION)
	# Step 2: hold at full alpha
	_tween.tween_interval(HOLD_DURATION)
	# Step 3: fade out to alpha 0
	_tween.set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_DURATION)


## Read accessors used by paired tests to assert visual primitives without
## reaching into private state. Mirrors the `_hp_bar_shimmer` accessor in
## `scenes/Main.gd`.
func get_plate() -> ColorRect:
	return _plate


func get_pip() -> ColorRect:
	return _pip


func get_label() -> Label:
	return _label


# ---- Signal handler ----------------------------------------------------

## Connected to `Save.save_completed`. Per design spec, M1 ignores the
## failure path (`ok=false`) — failure surface is the existing `push_error`
## console line.
func _on_save_completed(_slot: int, ok: bool) -> void:
	if not ok:
		return
	show_saved()


# ---- UI build ----------------------------------------------------

func _build_ui() -> void:
	# Anchor the toast at the bottom-right of its parent (CanvasLayer-scoped
	# Control via Main HUD). 120 × 28 plate sits at ANCHOR_OFFSET.
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = ANCHOR_OFFSET.x
	offset_top = ANCHOR_OFFSET.y
	offset_right = ANCHOR_OFFSET.x + PLATE_SIZE.x
	offset_bottom = ANCHOR_OFFSET.y + PLATE_SIZE.y

	_plate = ColorRect.new()
	_plate.name = "Plate"
	_plate.color = COLOR_PLATE
	_plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)

	_pip = ColorRect.new()
	_pip.name = "Pip"
	_pip.color = COLOR_PIP
	# Vertically centered on the 28 px plate — pip is 8 px so y = (28 - 8) / 2 = 10.
	_pip.position = Vector2(PIP_OFFSET_LEFT, (PLATE_SIZE.y - PIP_SIZE.y) * 0.5)
	_pip.size = PIP_SIZE
	_pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(_pip)

	_label = Label.new()
	_label.name = "Label"
	_label.text = "Saved"
	_label.add_theme_color_override("font_color", COLOR_TEXT)
	_label.add_theme_font_size_override("font_size", 12)
	_label.position = Vector2(TEXT_OFFSET_LEFT, 0)
	_label.size = Vector2(PLATE_SIZE.x - TEXT_OFFSET_LEFT - 4, PLATE_SIZE.y)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(_label)


# ---- Helpers ----------------------------------------------------

func _save_node() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null("Save")
