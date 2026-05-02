class_name DescendScreen
extends CanvasLayer
## Fullscreen "descend to next stratum" interstitial. Fires after the
## player walks into the StratumExit and presses the interact key.
##
## M1 contract:
##   - Fade-in from transparent to fully opaque over `FADE_DURATION` s.
##   - "Stratum 2 — Coming in M2" placeholder copy. M2 will replace this
##     scene with the actual stratum-2 first-room load.
##   - "Return to Stratum 1" button restarts the M1 demo loop. Per
##     `team/uma-ux/death-restart-flow.md` Beat F's audio/copy convention:
##     the descend is conceptually similar to a successful "Descend Again"
##     but with different framing — *the player chose this*, so the fade
##     and copy are gentler (no "You fell." card).
##
## Why a CanvasLayer (not a Control root): the screen has to render *over*
## the world viewport at output resolution, not the 480×270 internal
## canvas. Uma `visual-direction.md` "UI vs. world rendering": HUD/panels
## live on a screen-space CanvasLayer.
##
## Test surface (per `tests/test_descend_screen.gd`):
##   - `is_fade_complete()` — true once the fade-in tween has finished.
##   - `complete_fade_for_test()` — skip the wall-clock wait deterministically.
##   - `press_return_for_test()` — emit `restart_run` without standing up
##     a real Button input event.
##
## Per the M1 death rule (DECISIONS.md 2026-05-02): descending preserves
## EVERYTHING (level, equipped, inventory) since the player succeeded at
## stratum 1. This is fundamentally different from death — `restart_run`
## semantics here are "loop the M1 demo with the same character," not
## "punish-reset on death."

# ---- Signals ------------------------------------------------------------

## Player chose to restart the M1 demo loop. Owning game-flow code reloads
## stratum 1 room 1. One-shot — once emitted, further button presses are
## no-ops (rapid mash idempotence — see `_on_return_pressed`).
signal restart_run()

## Fade-in tween has completed. Mostly used by tests to assert the timing
## but a cinematic layer could subscribe for "now play the bell strike."
signal fade_in_completed()

# ---- Tuning ------------------------------------------------------------

## Total duration of the fade-in tween (transparent → fully opaque). Per
## Uma's death-restart Beat D ("0.4 s panel-bg fade"), the descend screen
## is a slightly slower 0.6 s — descent is intentional, give it weight.
const FADE_DURATION: float = 0.6

## Title copy. Bound here so a future microcopy pass can find the string
## quickly. Uma may revise.
const TITLE_TEXT: String = "STRATUM 2"

## Subtitle copy — the M1 placeholder line. M2 will replace this scene
## entirely; until then this is the player's "yes the game continues" cue.
const SUBTITLE_TEXT: String = "Coming in M2"

## Body copy explaining the loop-back option.
const BODY_TEXT: String = "You have cleared the Outer Cloister.\nThe path deeper waits to be carved."

## Button copy.
const RETURN_BUTTON_TEXT: String = "Return to Stratum 1"

# ---- Palette (Uma `palette.md`) ---------------------------------------

## Panel background — `#1B1A1F` at 100% opacity (Uma death-restart Beat D
## convention: "stop-the-world moments are 100% opaque, not 92%").
const PANEL_BG_COLOR: Color = Color(0.10588235, 0.10196078, 0.12156863, 1.0)

## Title — ember accent `#FF6A2A`.
const TITLE_COLOR: Color = Color(1.0, 0.4156862745, 0.1647058824, 1.0)

## Body text — off-white HUD body `#E8E4D6`.
const BODY_COLOR: Color = Color(0.9098, 0.8941, 0.8392, 1.0)

## Subtitle — muted parchment `#B8AC8E` for the "M2" hint.
const SUBTITLE_COLOR: Color = Color(0.7215686275, 0.6745098039, 0.5568627451, 1.0)

# ---- Runtime ----------------------------------------------------------

var _fade_complete: bool = false
var _restart_emitted: bool = false

var _bg_panel: ColorRect = null
var _title_label: Label = null
var _subtitle_label: Label = null
var _body_label: Label = null
var _return_button: Button = null
var _fade_tween: Tween = null


func _ready() -> void:
	# CanvasLayers default to layer 1; bump to a high value so we sit over
	# the HUD (which is also a CanvasLayer in Devon's scene authoring).
	layer = 100
	_build_ui()
	_start_fade_in()


# ---- Public API -------------------------------------------------------

func is_fade_complete() -> bool:
	return _fade_complete


func is_restart_emitted() -> bool:
	return _restart_emitted


func get_bg_panel() -> ColorRect:
	return _bg_panel


func get_return_button() -> Button:
	return _return_button


func get_title_label() -> Label:
	return _title_label


## Test-only: skip the wall-clock fade and snap to "fully opaque + fade
## complete" deterministically. Production waits the real 0.6 s.
func complete_fade_for_test() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
		_fade_tween = null
	if _bg_panel != null:
		_bg_panel.modulate = Color(1, 1, 1, 1)
	_on_fade_completed()


## Test-only: simulate the return-button press without dispatching a real
## button event. Same idempotence guarantees as the live button path.
func press_return_for_test() -> void:
	_on_return_pressed()


# ---- Internal --------------------------------------------------------

func _build_ui() -> void:
	# Background panel — full screen, modulated for the fade-in.
	_bg_panel = ColorRect.new()
	_bg_panel.name = "BackgroundPanel"
	_bg_panel.color = PANEL_BG_COLOR
	_bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Start invisible; tween will ramp to opaque.
	_bg_panel.modulate = Color(1, 1, 1, 0)
	_bg_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg_panel)

	# Title — ember-orange "STRATUM 2".
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = TITLE_TEXT
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", TITLE_COLOR)
	_title_label.add_theme_font_size_override("font_size", 48)
	_title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title_label.offset_left = -200.0
	_title_label.offset_right = 200.0
	_title_label.offset_top = 120.0
	_title_label.offset_bottom = 180.0
	_bg_panel.add_child(_title_label)

	# Subtitle — muted "Coming in M2".
	_subtitle_label = Label.new()
	_subtitle_label.name = "SubtitleLabel"
	_subtitle_label.text = SUBTITLE_TEXT
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_color_override("font_color", SUBTITLE_COLOR)
	_subtitle_label.add_theme_font_size_override("font_size", 18)
	_subtitle_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_subtitle_label.offset_left = -200.0
	_subtitle_label.offset_right = 200.0
	_subtitle_label.offset_top = 184.0
	_subtitle_label.offset_bottom = 208.0
	_bg_panel.add_child(_subtitle_label)

	# Body copy.
	_body_label = Label.new()
	_body_label.name = "BodyLabel"
	_body_label.text = BODY_TEXT
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_body_label.add_theme_color_override("font_color", BODY_COLOR)
	_body_label.add_theme_font_size_override("font_size", 16)
	_body_label.set_anchors_preset(Control.PRESET_CENTER)
	_body_label.offset_left = -300.0
	_body_label.offset_right = 300.0
	_body_label.offset_top = -20.0
	_body_label.offset_bottom = 60.0
	_bg_panel.add_child(_body_label)

	# Return button. Default-focused so Enter / E works without hunting.
	_return_button = Button.new()
	_return_button.name = "ReturnButton"
	_return_button.text = RETURN_BUTTON_TEXT
	_return_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_return_button.offset_left = -120.0
	_return_button.offset_right = 120.0
	_return_button.offset_top = -120.0
	_return_button.offset_bottom = -80.0
	_return_button.pressed.connect(_on_return_pressed)
	_bg_panel.add_child(_return_button)


func _start_fade_in() -> void:
	if _bg_panel == null:
		# Defensive — should never happen since _build_ui() runs first.
		_on_fade_completed()
		return
	# Kill any in-flight tween before replacing — keeps `_ready` re-entrant
	# in tests that re-instance.
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(
		_bg_panel, "modulate:a", 1.0, FADE_DURATION
	).from(0.0)
	_fade_tween.finished.connect(_on_fade_completed)


func _on_fade_completed() -> void:
	if _fade_complete:
		return
	_fade_complete = true
	# Grab focus for the return button now that the player can see + click.
	if _return_button != null and _return_button.is_inside_tree():
		_return_button.grab_focus()
	fade_in_completed.emit()


func _on_return_pressed() -> void:
	# Idempotent — first press fires `restart_run`; further presses are
	# no-ops. This is the rapid-mash guard for the test-spec edge case.
	if _restart_emitted:
		return
	_restart_emitted = true
	# Disable the button so visual mash-feedback matches state.
	if _return_button != null:
		_return_button.disabled = true
	restart_run.emit()
