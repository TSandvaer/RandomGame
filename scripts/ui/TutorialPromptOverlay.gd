class_name TutorialPromptOverlay
extends Control
## Single-instance non-modal tutorial-prompt overlay. Renders a one-line
## ghost-text Label over a thin ColorRect backdrop, fades in over 200 ms,
## holds for `duration` seconds, fades out over 200 ms. Replaces the previous
## prompt on every new `show_prompt` call (FIFO; per Uma's
## `team/uma-ux/player-journey.md` Beat 4 + cross-cutting rule #6 "One prompt
## at a time, ever").
##
## **This is the empty stage** for Drew's Stage 2b dispatch (ticket
## `86c9qaj3u`). No content (no actual prompt text) is wired here — Drew's
## room script will emit `TutorialEventBus.tutorial_beat_requested(...)`
## from Room01 entry / first-input / dummy-poof beats; this overlay
## subscribes and resolves text via the bus's beat dictionary.
##
## **Architecture:**
##   - Single global instance — mounted in `scenes/Main.gd::_build_hud` HUD
##     CanvasLayer (layer 10). Gameplay-visible, non-modal, never blocks input
##     (`mouse_filter = MOUSE_FILTER_IGNORE` on every node in the tree).
##   - Subscribes to `TutorialEventBus.tutorial_beat_requested` in `_ready`,
##     resolves beat_id → text via the bus, and calls `show_prompt`.
##   - Direct API (`show_prompt(text, duration, anchor)`) is also public so
##     Drew can fire ad-hoc prompts without registering a beat in the bus.
##
## **HTML5 safety (per `.claude/docs/html5-export.md` § HDR clamp + Polygon2D
## ban + tightened visual-verification gate):**
##   - Zero Polygon2D — backdrop is `ColorRect`, text is `Label`.
##   - All colors strictly sub-1.0 on every channel.
##   - `modulate.a` tween only — no HDR-clamped color tweens.
##   - Renderer-identical desktop ↔ HTML5 (ColorRect + Label + modulate-alpha
##     all flow through the same Godot text + UI pipeline on both).
##
## **Anchor positions (per Uma's player-journey Beat 4 = bottom-center "ghost
## text," Beat 6 = mob nameplate at center):** the overlay supports three
## anchored positions so future beats can re-use the same widget without
## proliferating per-beat overlays. Drew's Stage 2b uses BOTTOM for the
## WASD/dodge/strike beats per Uma's "centered low" spec — reconciled per
## Tess's PR #164 review note (default was CENTER_TOP, now BOTTOM).
##
## **Plate visibility reconciliation (Tess PR #164 note):** Uma's spec calls
## for "white text at 60% opacity, no panel background." Pre-Stage-2b the
## overlay shipped a 75%-alpha plate-background to read as a "system
## widget"; that diverged from Uma's "ambient guidance, not status" intent.
## `COLOR_PLATE.a = 0.0` (fully transparent) restores the no-panel
## appearance; `COLOR_TEXT.a = 0.6` matches the 60% opacity ghost-text
## phrasing exactly. Reconciled in Drew's Stage 2b PR rather than a
## separate UX cleanup ticket — overlay is shipping content for the first
## time, so design/default-alignment is part of that landing.

# ---- Signals ----------------------------------------------------------

## Emitted when the prompt becomes visible (post-fade-in). Tests assert
## this without polling modulate.a.
signal prompt_shown(text: String)

## Emitted when the prompt has fully faded out (or been replaced and the
## old fade is done). Tests + future content can chain on this.
signal prompt_dismissed()

# ---- Anchor enum -----------------------------------------------------

## Where on screen the prompt renders. Drew's Stage 2b WASD/dodge/strike
## beats use CENTER_TOP per Uma's player-journey Beat 4.
enum AnchorPos {
	CENTER_TOP,   # near top of screen, centered horizontally (default for first-input prompts)
	CENTER,       # middle of screen, centered both axes
	BOTTOM,       # near bottom of screen, centered horizontally (Uma's "centered low" Beat 4 phrasing)
}

# ---- Geometry constants (Uma's player-journey Beat 4 + general HUD typography) ----

## Plate is wide enough for a typical short prompt ("WASD to move." = 13 chars
## at 14 px font ≈ 110 px). 320 × 36 px gives generous breathing room.
const PLATE_SIZE: Vector2 = Vector2(320, 36)

## Vertical padding from the top edge for CENTER_TOP anchor. Uma's "centered
## low" Beat 4 phrasing is BOTTOM; CENTER_TOP is the matching opposite.
const ANCHOR_TOP_OFFSET_Y: float = 64.0

## Vertical padding from the bottom edge for BOTTOM anchor. Sits above the
## BootBanner (which spans `offset_top = -150`), but below the [+1 STAT] pip.
const ANCHOR_BOTTOM_OFFSET_Y: float = 200.0

# ---- Visual constants (sub-1.0 channels per HTML5 HDR-clamp rule) ----

## Plate alpha = 0 per Uma Beat 4 "no panel background" (Tess PR #164 note
## reconciliation, Drew Stage 2b). The plate node is preserved in the tree
## (rather than removed) so future beats can opt back into a backdrop via
## a dedicated anchor or `set_plate_alpha()` extension; the BBCode-style
## guidance text is the load-bearing visual for Beats 4-5. Channels stay
## sub-1.0 per HTML5 HDR-clamp rule — the alpha=0 keeps the plate invisible
## even if a future tweak bumps the RGB.
const COLOR_PLATE: Color = Color(0.10588235, 0.10196078, 0.12156863, 0.0)  # #1B1A1F @0% (invisible)

## HUD body color at 60% alpha per Uma Beat 4 "white text with 60% opacity"
## (Tess PR #164 note reconciliation, Drew Stage 2b — was 1.0). The 60%
## opacity is the load-bearing "ghost text" feel; full alpha read as a
## hard system label. The `modulate.a` tween (FADE_IN / FADE_OUT) multiplies
## with this base alpha, so peak visibility is 60% × modulate.a (peak 100%
## modulate × 60% color alpha = 60% effective text opacity, as spec'd).
const COLOR_TEXT: Color = Color(0.9098, 0.8941, 0.8392, 0.6)  # #E8E4D6 @60%

# ---- Timing constants -----------------------------------------------

## Fade-in / fade-out duration per Uma's spec (Beat 4: "fades in/out over
## 0.2 s, never blocks input").
const FADE_IN_DURATION: float = 0.20
const FADE_OUT_DURATION: float = 0.20

## Default `duration` argument to `show_prompt`. The on-screen window for
## a single prompt before auto-dismiss. Drew's Stage 2b prompts are
## input-driven (advance on first WASD / first dodge), so the duration is
## a safety-net auto-dismiss for any prompt that never gets advanced.
const DEFAULT_DURATION: float = 3.0

# ---- Runtime ----------------------------------------------------

## In-flight Tween. Killed + replaced on every new `show_prompt` call
## (replace-on-new-show per Uma's cross-cutting rule #6 "One prompt at a
## time, ever"). Mirrors SaveToast's tween-throttle discipline.
var _tween: Tween = null

## Built-up node refs.
var _plate: ColorRect = null
var _label: Label = null

## The currently-displayed text — read by tests so they can assert text
## delta on the public API surface (vs. reaching into the Label).
var _current_text: String = ""

## Currently-active anchor — drives the layout in `_apply_anchor`. Default
## BOTTOM per Uma Beat 4 "centered low" (Tess PR #164 note reconciliation,
## Drew Stage 2b — was CENTER_TOP). Drew's room script passes BOTTOM=2
## explicitly when emitting via the bus, so the default only matters for
## the rare ad-hoc `show_prompt` callers that omit the anchor argument.
var _current_anchor: AnchorPos = AnchorPos.BOTTOM


func _ready() -> void:
	_build_ui()
	# Hidden-but-not-freed at rest: alpha 0 + visible=true so the tween can
	# drive the alpha live. mouse_filter IGNORE on root + every child so the
	# overlay never steals input.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate = Color(1, 1, 1, 0.0)
	# Subscribe to the event-bus autoload. Defensive lookup so headless tests
	# can stand up the overlay in isolation without the autoload registered.
	var bus: Node = _bus_node()
	if bus != null and bus.has_signal("tutorial_beat_requested"):
		if not bus.is_connected("tutorial_beat_requested", _on_tutorial_beat_requested):
			bus.connect("tutorial_beat_requested", _on_tutorial_beat_requested)


# ---- Public API -------------------------------------------------------

## Show a prompt with the given text for `duration` seconds at `anchor`.
## Replaces any in-flight prompt (kill + restart fade chain). Per Uma
## player-journey rule #6 "One prompt at a time, ever."
##
## - `text` — body text rendered in the Label.
## - `duration` — seconds at full alpha before auto-dismiss starts. Default
##   3.0; pass 0 for "fade-in then immediately fade-out" (no hold).
## - `anchor` — which screen edge to anchor against. Default CENTER_TOP per
##   Uma's first-input-prompt placement.
func show_prompt(text: String, duration: float = DEFAULT_DURATION, anchor: AnchorPos = AnchorPos.BOTTOM) -> void:
	# Replace-on-new-show: kill in-flight tween, restart from current alpha.
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

	_current_text = text
	_current_anchor = anchor
	if _label != null:
		_label.text = text
	_apply_anchor(anchor)

	# Build the fade-in → hold → fade-out chain. The fade-in step uses the
	# CURRENT alpha as starting point so a replace mid-fade-out flips smoothly.
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_LINEAR)
	# Step 1 — fade in to alpha 1.0
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION)
	# Step 2 — emit prompt_shown via a callback on the chain (post-fade-in).
	# Bind the text so callers can read the just-shown prompt from the signal
	# payload without a separate accessor call.
	_tween.tween_callback(Callable(self, "_emit_prompt_shown").bind(text))
	# Step 3 — hold at full alpha for `duration` (clamped to >= 0).
	var hold: float = max(duration, 0.0)
	if hold > 0.0:
		_tween.tween_interval(hold)
	# Step 4 — fade out to alpha 0.
	_tween.set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_DURATION)
	# Step 5 — post-fade-out callback emits prompt_dismissed.
	_tween.tween_callback(Callable(self, "_emit_prompt_dismissed"))


## Read accessors used by paired tests to assert visual primitives without
## reaching into private state. Mirrors SaveToast's `get_plate` / `get_label`.
func get_plate() -> ColorRect:
	return _plate


func get_label() -> Label:
	return _label


func get_current_text() -> String:
	return _current_text


func get_current_anchor() -> AnchorPos:
	return _current_anchor


# ---- Signal handler ---------------------------------------------------

## Connected to `TutorialEventBus.tutorial_beat_requested`. Resolves the
## beat_id → text via the bus's beat dictionary and calls `show_prompt`.
func _on_tutorial_beat_requested(beat_id: StringName, anchor: int) -> void:
	var bus: Node = _bus_node()
	if bus == null:
		return
	if not bus.has_method("resolve_beat_text"):
		return
	var text: String = String(bus.call("resolve_beat_text", beat_id))
	if text.is_empty():
		# Unknown beat_id — silently no-op. Tests assert this contract so an
		# unregistered beat doesn't render an empty prompt.
		return
	# Bus payload uses int (autoload signal-payload friendly); coerce to enum
	# for the public API. AnchorPos values are 0/1/2 so int <-> enum is
	# bidirectional.
	var anchor_enum: AnchorPos = anchor as AnchorPos
	show_prompt(text, DEFAULT_DURATION, anchor_enum)


# ---- UI build ---------------------------------------------------

func _build_ui() -> void:
	# Root Control sized to the plate — the screen-anchor is applied in
	# `_apply_anchor` per show_prompt call. Default CENTER_TOP layout.
	_plate = ColorRect.new()
	_plate.name = "Plate"
	_plate.color = COLOR_PLATE
	_plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)

	_label = Label.new()
	_label.name = "Label"
	_label.text = ""
	_label.add_theme_color_override("font_color", COLOR_TEXT)
	_label.add_theme_font_size_override("font_size", 14)
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(_label)

	# Initial anchor — BOTTOM per Uma Beat 4. Updated per show_prompt call.
	_apply_anchor(AnchorPos.BOTTOM)


## Position the overlay's plate against the screen edge per `anchor`. The
## plate is `PLATE_SIZE` wide and centered horizontally; vertical position
## depends on the anchor enum.
func _apply_anchor(anchor: AnchorPos) -> void:
	# Use offsets-from-anchor-preset to get screen-relative positioning that
	# survives viewport size changes (HTML5 fullscreen / browser resize).
	# Horizontal: always centered.
	# Vertical: TOP / CENTER / BOTTOM differ.
	match anchor:
		AnchorPos.CENTER_TOP:
			set_anchors_preset(Control.PRESET_CENTER_TOP)
			offset_left = -PLATE_SIZE.x * 0.5
			offset_right = PLATE_SIZE.x * 0.5
			offset_top = ANCHOR_TOP_OFFSET_Y
			offset_bottom = ANCHOR_TOP_OFFSET_Y + PLATE_SIZE.y
		AnchorPos.CENTER:
			set_anchors_preset(Control.PRESET_CENTER)
			offset_left = -PLATE_SIZE.x * 0.5
			offset_right = PLATE_SIZE.x * 0.5
			offset_top = -PLATE_SIZE.y * 0.5
			offset_bottom = PLATE_SIZE.y * 0.5
		AnchorPos.BOTTOM:
			set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
			offset_left = -PLATE_SIZE.x * 0.5
			offset_right = PLATE_SIZE.x * 0.5
			offset_top = -ANCHOR_BOTTOM_OFFSET_Y - PLATE_SIZE.y
			offset_bottom = -ANCHOR_BOTTOM_OFFSET_Y


# ---- Tween-callback method refs --------------------------------

## Emit `prompt_shown(text)` — called from the tween's post-fade-in step.
## Bound from `show_prompt` so the payload carries the just-shown prompt.
func _emit_prompt_shown(text: String) -> void:
	prompt_shown.emit(text)


## Emit `prompt_dismissed()` — called from the tween's post-fade-out step.
func _emit_prompt_dismissed() -> void:
	prompt_dismissed.emit()


# ---- Helpers ---------------------------------------------------

func _bus_node() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null("TutorialEventBus")
