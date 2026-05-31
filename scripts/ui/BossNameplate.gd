class_name BossNameplate
extends CanvasLayer
## M3-T2-W3-T13 — Boss nameplate banner (480×56 top-center HUD canvas).
##
## Direction source: `team/uma-ux/boss-intro.md` § "Boss nameplate spec"
## (Uma — binding). Acceptance criteria BI-07 through BI-15.
## Scope source: `team/priya-pl/w3-dispatch-plan.md` §3 Brief 1.
##
## ## Design intent (Uma)
##
## The nameplate "slides down from the top of the screen like a banner
## unfurled" on `entry_sequence_completed` — a single 0.4 s eased reveal.
## Its 3 visually-equal segments are **narrative phases, not literal HP
## brackets** ("the bar lies a little to make the story land"). Phase
## transitions visually re-anchor — the player feels "the boss responds."
##
## ## Composition
##
## | Element | Primitive | Notes |
## |---|---|---|
## | Background panel | ColorRect | `#1B1A1F` α 0.92 + 1 px `#FF6A2A` border |
## | Border (4 strips) | ColorRect × 4 | top/bottom/left/right 1 px ember-orange |
## | Threat glyph `[!]` | Label | 24×24, ember-orange, top-left |
## | Boss name | Label | 16 px caps off-white centered |
## | Threat label | Label | `THREAT: ELITE` muted parchment top-right |
## | Phase labels × 3 | Label | `PHASE 1/2/3` 10 px caps above each segment |
## | Segment FG × 3 | ColorRect | `#7A2A26` active foreground (instant on hit) |
## | Segment ghost × 3 | ColorRect | Ghost-damage drain over 0.6 s |
## | Segment separator × 2 | ColorRect | 2 px ember-orange between segments |
## | Pulse outline (T18) | ColorRect | 1 px ember-orange at 1.5 Hz when <10% |
##
## **Why ColorRect, not Polygon2D / NinePatchRect.** Per
## `.claude/docs/html5-export.md` § "gl_compatibility" — Polygon2D
## empirically silently-fails on WebGL2 (PR #137); ColorRect is the safe
## primitive class for filled rectangles. All ember-orange / off-white /
## muted-parchment colors are sub-1.0 channels (HDR-clamp safe).
##
## **Why CanvasLayer, not Control-on-HUD.** CanvasLayer ignores Camera2D
## transform — the nameplate stays screen-space-anchored when the T16
## cinematic zooms the camera to 1.5×. Matches the HUD / Vignette /
## BossDefeatedTitleCard pattern.
##
## **Layer placement.** `layer = 10` — same band as the HUD. Below
## InventoryPanel (80), below BossDefeatedTitleCard (50). Sits in the
## HUD band because it IS HUD (a context-region top-center widget); it
## must not paint over panels that the player explicitly opened.
##
## ## State machine
##
## ```
##   constructed → hidden (offscreen above top edge, modulate.a = 0)
##         ↓ show()
##   slide_in (0.4 s ease-out cubic) → fully visible
##         ↓ on damaged()
##   active segment foreground drops instantly + ghost-tween starts
##         ↓ on phase_changed(N)
##   completed segment locks at 0; active label brightens;
##   separator flashes ember 0.3 s; next segment activates
##         ↓ at <10% active-segment HP (T18)
##   pulse outline modulate-alpha at 1.5 Hz; stops on phase_changed
##         ↓ (life ends when room/main frees the nameplate)
##   hidden / freed
## ```
##
## ## Idempotence guards
##
## - `show()` is no-op if already shown.
## - `_on_damaged()` no-op if `_dismissed` (boss died — let title card own).
## - `_on_phase_changed(N)` early-return if `N <= _current_phase` — replays
##   a phase boundary do not double-flash the separator.
## - Ghost-drain tween is killed + restarted on each hit so the ghost
##   tracks the latest target value, not a stale snapshot.
## - Pulse tween is killed on phase-transition + re-armed if the new
##   active segment is already <10% (the design-side rare corner).
##
## ## Scaled tweens — intentional pause during freeze
##
## All tweens use default `create_tween()` (scaled-process) so the slide-in
## + ghost-drain + segment-flash + pulse all pause during T2 hit-pause /
## T3 phase-transition / T16 freeze. Matches the BossDefeatedTitleCard
## pattern and Uma's tonal intent: "the nameplate 'feels' the freeze."
##
## ## HTML5 visual-verification gate
##
## This is tween + modulate + multi-CanvasLayer composition. Per
## `.claude/docs/html5-export.md`, the "renderer-safe primitives" argument
## is NOT a substitute for an HTML5 screenshot. Self-Test Report invokes
## the per-surface escape clause (all primitives = ColorRect / Label;
## modulate-alpha tweens on sub-1.0 channels) and routes HTML5 visual
## verification to Sponsor-soak with concrete probe targets.

# ---- Spec constants (locked from Uma's brief §"Boss nameplate spec") ---

## Banner dimensions per Uma §"Boss nameplate spec § Layout".
const PANEL_WIDTH: float = 480.0
const PANEL_HEIGHT: float = 56.0

## Anchor — top-center, 12 px from screen top.
const TOP_MARGIN: float = 12.0

## Border thickness (ember-orange 1 px outline).
const BORDER_THICKNESS: float = 1.0

## Inner-content horizontal padding (text + segment row).
const INNER_PADDING_X: float = 24.0

## Bar dimensions per Uma §"Phase-segmented health bar".
const BAR_WIDTH: float = 432.0
const BAR_HEIGHT: float = 12.0
const SEGMENT_COUNT: int = 3
const SEGMENT_SEPARATOR_WIDTH: float = 2.0
## Visually-equal segment width: (BAR_WIDTH - 2*SEPARATOR) / 3 = 142.66...
## Use float division so the math stays clean. Each segment renders at the
## same width regardless of internal phase HP weight per Uma's design
## ("the bar lies a little to make the story land").
const SEGMENT_WIDTH: float = (BAR_WIDTH - 2.0 * SEGMENT_SEPARATOR_WIDTH) / SEGMENT_COUNT

## Slide-in tween — 0.4 s ease-out per Uma BI-07 + §"Beat 4 — Nameplate
## banner".
const SLIDE_IN_DURATION: float = 0.4

## Ghost-drain duration — matches regular mob HP-bar shape per Uma
## §"Segment fill (active phase)".
const GHOST_DRAIN_DURATION: float = 0.6

## Phase-transition separator flash duration (BI-18).
const SEPARATOR_FLASH_DURATION: float = 0.3

## T18 — Below-10% HP pulse frequency (1.5 Hz = ~0.667 s period).
const PULSE_HZ: float = 1.5
const PULSE_PERIOD: float = 1.0 / PULSE_HZ
## T18 — Pulse threshold (active segment HP fraction).
const PULSE_THRESHOLD_FRACTION: float = 0.10

## Phase-transition HP thresholds — these are the DEFAULT (S1 Warden 3-phase)
## boundary fractions, used when no bound boss exposes `get_phase_boundary_fracs()`
## (e.g. legacy test stubs). The nameplate is read-only on boss state; these
## let the segment driver compute active-segment fill % independently when only
## `hp_current` + `hp_max` are observable.
##
## **Phase-count parameterization (ticket 86ca1m0at, Sponsor 2026-05-31 soak).**
## The nameplate is NO LONGER hard-locked to a 3-phase boss. At `show_for(boss)`
## time it reads the bound boss's `get_phase_boundary_fracs()` (descending
## boundary fracs) and rebuilds its segment row to `len + 1` segments, computing
## fills from those fracs. The 2-phase ArchiveSentinel (`[0.50]`) renders 2
## segments; the 3-phase Warden (`[0.66, 0.33]`) renders 3. **Root cause of the
## Sponsor's "boss never transitioned into phase 3, bar froze, sudden death"**:
## the boss is 2-phase (single emit `phase_changed(2)`), but the nameplate's
## hard-coded 0.66/0.33 + 3-segment model meant its phase-2 fill drained to 0 at
## hp = round(max*0.33) while the boss kept taking damage to 0 with no further
## phase emit — the PHASE-3 segment never lit and the bar appeared frozen for the
## final ~third of the fight.
const PHASE_2_HP_FRAC: float = 0.66
const PHASE_3_HP_FRAC: float = 0.33

## Default boundary fractions when no boss override is available (S1 3-phase).
const DEFAULT_BOUNDARY_FRACS: Array = [PHASE_2_HP_FRAC, PHASE_3_HP_FRAC]

# ---- Palette (locked from Uma palette.md + boss-intro.md) -------------

## Panel background — near-black `#1B1A1F` at 92% opacity per Uma
## §"Boss nameplate spec § Layout". HDR-clamp safe (all RGB sub-0.13).
const PANEL_BG: Color = Color(0x1B / 255.0, 0x1A / 255.0, 0x1F / 255.0, 0.92)

## Ember-orange `#FF6A2A` — border + separators + pulse + threat glyph.
## All RGB sub-1.0 (max channel 1.0; HDR-clamp lands here exactly, no clip).
## Locked from `palette.md` ember accent (primary).
const EMBER_ORANGE: Color = Color(0xFF / 255.0, 0x6A / 255.0, 0x2A / 255.0, 1.0)

## Boss-name + active-phase label color — off-white `#E8E4D6`
## (HUD body off-white per palette.md:24). HDR-clamp safe.
const HUD_OFF_WHITE: Color = Color(0xE8 / 255.0, 0xE4 / 255.0, 0xD6 / 255.0, 1.0)

## Threat label + completed-phase + future-phase label color —
## muted parchment `#B8AC8E`.
const MUTED_PARCHMENT: Color = Color(0xB8 / 255.0, 0xAC / 255.0, 0x8E / 255.0, 1.0)

## Future-phase label color — HUD disabled `#605C50` per palette.md.
const HUD_DISABLED: Color = Color(0x60 / 255.0, 0x5C / 255.0, 0x50 / 255.0, 1.0)

## Active-phase segment fill color — `#7A2A26` (mob HP foreground per
## palette.md + Uma §"Segment fill"). HDR-clamp safe.
const SEGMENT_ACTIVE_FG: Color = Color(0x7A / 255.0, 0x2A / 255.0, 0x26 / 255.0, 1.0)

## Future-phase locked segment fill — same red at 60% brightness per
## Uma §"Segment fill (active phase)".
const SEGMENT_FUTURE_FG: Color = Color(
	0x7A / 255.0 * 0.6, 0x2A / 255.0 * 0.6, 0x26 / 255.0 * 0.6, 1.0
)

## Ghost-drain layer — darker, drains behind the foreground for the
## "ghost damage" trail. Mirrors regular mob HP bar shape.
const SEGMENT_GHOST_FG: Color = Color(
	0x7A / 255.0 * 0.45, 0x2A / 255.0 * 0.45, 0x26 / 255.0 * 0.45, 1.0
)

# ---- Copy spec (locked from Uma §"Copy spec") -------------------------

const TITLE_FONT_SIZE: int = 16
const THREAT_FONT_SIZE: int = 12
const PHASE_LABEL_FONT_SIZE: int = 10

const THREAT_LABEL_TEXT: String = "THREAT: ELITE"
const PHASE_LABEL_TEMPLATE: String = "PHASE %d"
const THREAT_GLYPH_TEXT: String = "[!]"
const FALLBACK_BOSS_NAME: String = "WARDEN OF THE OUTER CLOISTER"

# ---- Signals ----------------------------------------------------------

## Emitted when the slide-in tween completes (T+0.4 game-time post-show).
## Tests + future consumers subscribe to assert the reveal landed.
signal slide_in_completed

## Emitted on every observed `damaged` event after the foreground +
## ghost are updated. Carries the post-damage active-segment fill in [0,1].
signal segment_fill_updated(phase: int, fill_fraction: float)

## Emitted when phase-transition flash starts (separator brightens +
## next active segment lights up).
signal phase_transition_flashed(new_phase: int)

# ---- Runtime ----------------------------------------------------------

# Composition root — slides down on show(). modulate.a + position.y both
# tween from hidden state into the on-screen position.
var _root: Control = null

# Composition primitives (kept as members for test introspection).
var _panel_bg: ColorRect = null
var _border_top: ColorRect = null
var _border_bottom: ColorRect = null
var _border_left: ColorRect = null
var _border_right: ColorRect = null
var _threat_glyph_label: Label = null
var _name_label: Label = null
var _threat_label: Label = null

# Per-segment composition. Index 0..2 = phase 1..3.
var _segment_ghosts: Array[ColorRect] = []
var _segment_fgs: Array[ColorRect] = []
var _segment_separators: Array[ColorRect] = []  # 2 separators between 3 segs
var _phase_labels: Array[Label] = []
var _pulse_outlines: Array[ColorRect] = []  # T18 — 1 per segment

# Per-segment ghost-drain tweens (killed + restarted on each hit).
# Plain Array (not Array[Tween]) so null entries are tolerated without
# typed-array strictness errors on init.
var _ghost_tweens: Array = [null, null, null]

# Separator flash tweens (plain Array — null entries on init).
var _separator_flash_tweens: Array = [null, null]

# T18 — pulse tween (active segment only; at most one active at a time).
var _active_pulse_tween: Tween = null
var _active_pulse_segment_index: int = -1

# Slide-in tween (modulate.a + position.y).
var _slide_tween: Tween = null

# State.
var _shown: bool = false
var _slide_in_done: bool = false
var _dismissed: bool = false
var _current_phase: int = 1  # Phases 1..N (boss starts in phase 1).
var _hp_max_cached: int = 0
## Bound boss — kept so we can disconnect on dismiss and to read state.
var _boss: Node = null

## Runtime phase model — parameterized from the bound boss at `show_for`
## (ticket 86ca1m0at). `_segment_count` = number of phase segments rendered
## (defaults to SEGMENT_COUNT; rebuilt to match the boss's phase count).
## `_boundary_fracs` = descending HP-boundary fractions (defaults to S1's
## [0.66, 0.33]; replaced by the boss's `get_phase_boundary_fracs()`).
var _segment_count: int = SEGMENT_COUNT
var _boundary_fracs: Array = DEFAULT_BOUNDARY_FRACS.duplicate()


func _init() -> void:
	# HUD-band CanvasLayer. Same layer as Main._build_hud (10).
	# Below BossDefeatedTitleCard (50) and InventoryPanel (80) so opening
	# any panel paints over the nameplate cleanly.
	layer = 10


func _ready() -> void:
	if _root == null:
		_build_ui()


# ---- Public API -------------------------------------------------------


## Wire the nameplate to a Stratum1Boss + show the slide-in. Subscribes to
## the boss's `damaged` + `phase_changed` signals. Idempotent — a second
## call is a no-op (the room emits `entry_sequence_completed` exactly once
## per fight per `Stratum1BossRoom._complete_entry_sequence`, but pin it).
##
## `boss` is typed loosely (Node) so tests can pass a fake stub exposing
## `display_name`, `hp_current`, `hp_max`, and the two signals.
func show_for(boss: Node) -> void:
	if _shown:
		return
	_shown = true
	if _root == null:
		_build_ui()
	_boss = boss
	_apply_boss_name(boss)
	_hp_max_cached = _read_hp_max(boss)
	_current_phase = _read_initial_phase(boss)
	# Parameterize the segment count + phase-boundary fracs from the bound boss
	# (ticket 86ca1m0at) BEFORE the initial paint, so a 2-phase boss renders 2
	# segments + drives its fill math off the boss's real thresholds.
	_configure_phase_model(boss)
	_subscribe_to_boss_signals(boss)
	# Initial segment paint — segments 1..3 start at full fill; the current
	# phase's segment animates on hit, future segments stay locked at 100%
	# (at 60% brightness per Uma §"Segment fill"), completed segments at 0.
	_paint_initial_segment_state()
	# Phase labels start with PHASE 1 active (boss-defeated UI never
	# observes the pre-wake state because show_for fires on
	# entry_sequence_completed AFTER the boss has woken).
	_apply_phase_label_state()
	# Start hidden offscreen above the top edge; slide_in tween lands it
	# into the 12 px top-margin slot. Control's `position` is a wrapper
	# over offset_left/top under anchor PRESET_CENTER_TOP, so adjusting
	# offset_top directly is the cleanest tween target — it remains valid
	# whether the Control is rooted at preset CENTER_TOP or any other
	# top-anchor layout (a future spec tweak to the anchor preset would
	# keep this working without re-rebasing the math).
	_root.offset_top = -PANEL_HEIGHT
	_root.offset_bottom = 0.0
	_root.modulate = Color(1, 1, 1, 0)
	_start_slide_in_tween()


# ---- Test introspection -----------------------------------------------


func get_root_control() -> Control:
	return _root


func get_panel_bg() -> ColorRect:
	return _panel_bg


func get_name_label() -> Label:
	return _name_label


func get_threat_label() -> Label:
	return _threat_label


func get_threat_glyph_label() -> Label:
	return _threat_glyph_label


func get_phase_label(phase: int) -> Label:
	# `phase` is 1-indexed; array is 0-indexed. Bound by the actual built count
	# (a 2-phase nameplate has only 2 labels) — not the SEGMENT_COUNT max.
	if phase < 1 or phase > _phase_labels.size():
		return null
	return _phase_labels[phase - 1]


func get_segment_fg(phase: int) -> ColorRect:
	if phase < 1 or phase > _segment_fgs.size():
		return null
	return _segment_fgs[phase - 1]


func get_segment_ghost(phase: int) -> ColorRect:
	if phase < 1 or phase > _segment_ghosts.size():
		return null
	return _segment_ghosts[phase - 1]


func get_segment_separator(index: int) -> ColorRect:
	# `index` 0..1 (two separators between three segments).
	if index < 0 or index >= _segment_separators.size():
		return null
	return _segment_separators[index]


func get_pulse_outline(phase: int) -> ColorRect:
	if phase < 1 or phase > _pulse_outlines.size():
		return null
	return _pulse_outlines[phase - 1]


func is_shown() -> bool:
	return _shown


func is_slide_in_done() -> bool:
	return _slide_in_done


func get_current_phase() -> int:
	return _current_phase


func is_pulse_active() -> bool:
	return _active_pulse_tween != null and _active_pulse_tween.is_valid()


## Test-only — returns the active ghost-drain tween for the given phase
## (1..3). Used by `test_ghost_drain_tween_restarts_on_repeated_hits` to
## pin the kill-restart pattern (Tier 1 corollary in `test-conventions.md`).
func get_ghost_tween(phase: int) -> Tween:
	var i: int = phase - 1
	if i < 0 or i >= _ghost_tweens.size():
		return null
	return _ghost_tweens[i]


# ---- Internal: composition --------------------------------------------


func _build_ui() -> void:
	if _root != null:
		return
	_root = Control.new()
	_root.name = "Root"
	# Anchor preset top-center; manual horizontal offset for the 480 px width.
	_root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_root.offset_left = -PANEL_WIDTH * 0.5
	_root.offset_top = TOP_MARGIN
	_root.offset_right = PANEL_WIDTH * 0.5
	_root.offset_bottom = TOP_MARGIN + PANEL_HEIGHT
	# Never absorb mouse input — clicks must fall through to the gameplay
	# canvas for combat. Same rule as BossDefeatedTitleCard + Vignette.
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.modulate = Color(1, 1, 1, 0)  # hidden by default until show_for
	add_child(_root)

	_build_panel_bg_and_border()
	_build_text_labels()
	_build_segment_row()


func _build_panel_bg_and_border() -> void:
	# Background panel — full size, `#1B1A1F` at 92% opacity.
	_panel_bg = ColorRect.new()
	_panel_bg.name = "PanelBG"
	_panel_bg.color = PANEL_BG
	_panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_panel_bg)

	# 1 px ember-orange border — 4 ColorRect strips (top, bottom, left, right).
	# Building it as 4 strips (rather than a single hollow primitive) keeps
	# the renderer-safe path — every primitive is a filled ColorRect.
	_border_top = _make_border_strip("BorderTop")
	_border_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_border_top.offset_top = 0.0
	_border_top.offset_bottom = BORDER_THICKNESS
	_root.add_child(_border_top)

	_border_bottom = _make_border_strip("BorderBottom")
	_border_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_border_bottom.offset_top = -BORDER_THICKNESS
	_border_bottom.offset_bottom = 0.0
	_root.add_child(_border_bottom)

	_border_left = _make_border_strip("BorderLeft")
	_border_left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_border_left.offset_left = 0.0
	_border_left.offset_right = BORDER_THICKNESS
	_root.add_child(_border_left)

	_border_right = _make_border_strip("BorderRight")
	_border_right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_border_right.offset_left = -BORDER_THICKNESS
	_border_right.offset_right = 0.0
	_root.add_child(_border_right)


func _make_border_strip(strip_name: String) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.name = strip_name
	r.color = EMBER_ORANGE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _build_text_labels() -> void:
	# Threat glyph `[!]` — top-left.
	_threat_glyph_label = Label.new()
	_threat_glyph_label.name = "ThreatGlyph"
	_threat_glyph_label.text = THREAT_GLYPH_TEXT
	_threat_glyph_label.add_theme_color_override("font_color", EMBER_ORANGE)
	_threat_glyph_label.add_theme_font_size_override("font_size", THREAT_FONT_SIZE)
	_threat_glyph_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_threat_glyph_label.offset_left = INNER_PADDING_X - 16.0
	_threat_glyph_label.offset_top = 4.0
	_threat_glyph_label.offset_right = INNER_PADDING_X + 8.0
	_threat_glyph_label.offset_bottom = 28.0
	_threat_glyph_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_threat_glyph_label)

	# Boss name — centered top row. 16 px caps off-white.
	_name_label = Label.new()
	_name_label.name = "BossName"
	_name_label.text = FALLBACK_BOSS_NAME
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_color_override("font_color", HUD_OFF_WHITE)
	_name_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_name_label.offset_left = INNER_PADDING_X
	_name_label.offset_top = 4.0
	_name_label.offset_right = -INNER_PADDING_X
	_name_label.offset_bottom = 28.0
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_name_label)

	# Threat label `THREAT: ELITE` — top-right muted parchment.
	_threat_label = Label.new()
	_threat_label.name = "ThreatLabel"
	_threat_label.text = THREAT_LABEL_TEXT
	_threat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_threat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_threat_label.add_theme_color_override("font_color", MUTED_PARCHMENT)
	_threat_label.add_theme_font_size_override("font_size", THREAT_FONT_SIZE)
	_threat_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_threat_label.offset_left = -120.0
	_threat_label.offset_top = 4.0
	_threat_label.offset_right = -INNER_PADDING_X
	_threat_label.offset_bottom = 28.0
	_threat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_threat_label)


## Runtime per-segment width — BAR_WIDTH split across `_segment_count` segments
## with (N-1) separators between. At the default 3 segments this equals the
## SEGMENT_WIDTH constant; at 2 segments each segment is wider.
func _runtime_segment_width() -> float:
	var n: int = maxi(1, _segment_count)
	return (BAR_WIDTH - float(n - 1) * SEGMENT_SEPARATOR_WIDTH) / float(n)


## Read the bound boss's phase model and adopt its segment count + boundary
## fractions (ticket 86ca1m0at). Falls back to the S1 3-phase default for any
## boss/stub that does not expose `get_phase_boundary_fracs()`. If the resolved
## segment count differs from the row already built (the default 3), the segment
## row is torn down + rebuilt to N segments before the initial paint.
func _configure_phase_model(boss: Node) -> void:
	var fracs: Array = DEFAULT_BOUNDARY_FRACS.duplicate()
	if boss != null and boss.has_method("get_phase_boundary_fracs"):
		var reported: Array = boss.call("get_phase_boundary_fracs")
		if reported != null and reported.size() >= 1:
			fracs = reported.duplicate()
	# Boundaries must be strictly descending fractions in (0,1); segment count
	# is boundaries + 1. Clamp to [1, SEGMENT_COUNT] — the row composition + the
	# `PHASE_LABEL_TEMPLATE` only have art for up to SEGMENT_COUNT phases.
	_boundary_fracs = fracs
	var new_count: int = clampi(fracs.size() + 1, 1, SEGMENT_COUNT)
	if new_count != _segment_count:
		_segment_count = new_count
		_rebuild_segment_row()
	else:
		_segment_count = new_count


## Tear down the existing segment row + rebuild it at the current
## `_segment_count`. Used when the bound boss's phase count differs from the
## default. All per-segment node arrays + their tweens are cleared first.
func _rebuild_segment_row() -> void:
	# Kill any in-flight tweens that reference the about-to-be-freed nodes.
	for t in _ghost_tweens:
		if t != null and (t as Tween).is_valid():
			(t as Tween).kill()
	for t in _separator_flash_tweens:
		if t != null and (t as Tween).is_valid():
			(t as Tween).kill()
	if _active_pulse_tween != null and _active_pulse_tween.is_valid():
		_active_pulse_tween.kill()
	_active_pulse_tween = null
	_active_pulse_segment_index = -1
	# Free the old segment-row nodes.
	for arr in [_phase_labels, _segment_ghosts, _segment_fgs, _pulse_outlines, _segment_separators]:
		for node in arr:
			if node != null and is_instance_valid(node):
				node.queue_free()
	_phase_labels.clear()
	_segment_ghosts.clear()
	_segment_fgs.clear()
	_pulse_outlines.clear()
	_segment_separators.clear()
	_ghost_tweens = []
	_separator_flash_tweens = []
	for _i in range(_segment_count):
		_ghost_tweens.append(null)
	for _i in range(maxi(0, _segment_count - 1)):
		_separator_flash_tweens.append(null)
	_build_segment_row()


func _build_segment_row() -> void:
	# Phase labels (PHASE 1 / PHASE 2 / ...) — above each segment.
	# Y baseline: 28..40 (above the bar which sits at 40..52).
	# Bar X starts at INNER_PADDING_X = 24; spans BAR_WIDTH = 432.
	var bar_x_start: float = INNER_PADDING_X
	var bar_y_top: float = 40.0
	# Segment width scales with the runtime segment count so N segments fill the
	# BAR_WIDTH cleanly (2-phase boss → 2 wide segments; 3-phase → 3 narrower).
	var seg_w: float = _runtime_segment_width()
	for i in range(_segment_count):
		var seg_x: float = bar_x_start + i * (seg_w + SEGMENT_SEPARATOR_WIDTH)
		# Phase label.
		var lbl: Label = Label.new()
		lbl.name = "PhaseLabel%d" % (i + 1)
		lbl.text = PHASE_LABEL_TEMPLATE % (i + 1)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", _color_for_phase_label(i + 1))
		lbl.add_theme_font_size_override("font_size", PHASE_LABEL_FONT_SIZE)
		lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
		lbl.offset_left = seg_x
		lbl.offset_top = 28.0
		lbl.offset_right = seg_x + seg_w
		lbl.offset_bottom = 40.0
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_phase_labels.append(lbl)
		_root.add_child(lbl)

		# Ghost-drain layer (rendered BEHIND foreground; same starting fill).
		var ghost: ColorRect = ColorRect.new()
		ghost.name = "SegmentGhost%d" % (i + 1)
		ghost.color = SEGMENT_GHOST_FG
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.set_anchors_preset(Control.PRESET_TOP_LEFT)
		ghost.offset_left = seg_x
		ghost.offset_top = bar_y_top
		ghost.offset_right = seg_x + seg_w
		ghost.offset_bottom = bar_y_top + BAR_HEIGHT
		_segment_ghosts.append(ghost)
		_root.add_child(ghost)

		# Foreground (on top of ghost; instant drop on hit).
		var fg: ColorRect = ColorRect.new()
		fg.name = "SegmentFG%d" % (i + 1)
		fg.color = _color_for_segment_phase(i + 1)
		fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fg.set_anchors_preset(Control.PRESET_TOP_LEFT)
		fg.offset_left = seg_x
		fg.offset_top = bar_y_top
		fg.offset_right = seg_x + seg_w
		fg.offset_bottom = bar_y_top + BAR_HEIGHT
		_segment_fgs.append(fg)
		_root.add_child(fg)

		# T18 — Pulse outline (initially transparent; modulates on at <10%).
		# 1 px ember-orange outline around the segment. Built as a single
		# ColorRect with TRANSPARENT fill — we tween its border via a child
		# strip approach. Simplest: render it as a 1 px outline by stacking
		# 4 tiny ColorRect strips, OR use a single rect with `mouse_filter`
		# IGNORE and a clear interior. For renderer-safety we build it as
		# 4 strips like the panel border, but inline as a single composite
		# node-tree.
		var pulse: ColorRect = _build_pulse_outline_rect(
			"PulseOutline%d" % (i + 1), seg_x, bar_y_top, seg_w, BAR_HEIGHT
		)
		_pulse_outlines.append(pulse)
		_root.add_child(pulse)

		# Separators between adjacent segments (N-1 separators for N segments).
		if i < _segment_count - 1:
			var sep_x: float = seg_x + seg_w
			var sep: ColorRect = ColorRect.new()
			sep.name = "SegmentSeparator%d" % (i + 1)
			sep.color = EMBER_ORANGE
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sep.set_anchors_preset(Control.PRESET_TOP_LEFT)
			sep.offset_left = sep_x
			sep.offset_top = bar_y_top
			sep.offset_right = sep_x + SEGMENT_SEPARATOR_WIDTH
			sep.offset_bottom = bar_y_top + BAR_HEIGHT
			_segment_separators.append(sep)
			_root.add_child(sep)


## Build a 1 px ember-orange outline composed of 4 ColorRect strips
## wrapped in a parent Control. Returns the parent Control (typed as
## ColorRect-list-root would be misleading) — we return the topmost
## ColorRect strip as the "outline" handle and the rest live as children
## under the same Control parent in `_root`. To keep the data model
## simple we return ONE ColorRect (the top strip) and use its `modulate`
## as the shared visibility driver for all 4 strips (children inherit
## modulate cascade through `_pulse_outline_strips[i]`).
##
## NOTE — implementation: we group the 4 strips under a wrapper Control
## so a single modulate.a tween affects all 4 strips. Wrapper returned as
## the "outline" handle since modulate.a writes propagate to children.
func _build_pulse_outline_rect(
	base_name: String, x: float, y: float, w: float, h: float
) -> ColorRect:
	# Wrap the 4 strips under a ColorRect-typed parent whose own `color.a`
	# we keep at 0 (parent draws nothing). We need a Control-derived parent
	# for modulate cascade; a plain Control would work but ColorRect is
	# fine with `color = Color(0,0,0,0)` (fully transparent) — its own
	# render is a no-op while children render normally and inherit
	# modulate.a from this parent.
	#
	# **Why ColorRect-typed parent, not Control:** the `_pulse_outlines`
	# array is `Array[ColorRect]` for symmetry with `_segment_fgs` /
	# `_segment_ghosts`. Tests' `get_pulse_outline(phase)` returns
	# `ColorRect` so the typing matches.
	var parent: ColorRect = ColorRect.new()
	parent.name = base_name
	parent.color = Color(0, 0, 0, 0)
	parent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.set_anchors_preset(Control.PRESET_TOP_LEFT)
	parent.offset_left = x
	parent.offset_top = y
	parent.offset_right = x + w
	parent.offset_bottom = y + h
	# Start invisible — modulate.a = 0; tween at <10% threshold ramps to 1.
	parent.modulate = Color(1, 1, 1, 0)
	# 4 strips — top / bottom / left / right (1 px each, ember-orange).
	var top_strip: ColorRect = ColorRect.new()
	top_strip.name = "Top"
	top_strip.color = EMBER_ORANGE
	top_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_strip.offset_top = 0.0
	top_strip.offset_bottom = BORDER_THICKNESS
	parent.add_child(top_strip)

	var bottom_strip: ColorRect = ColorRect.new()
	bottom_strip.name = "Bottom"
	bottom_strip.color = EMBER_ORANGE
	bottom_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_strip.offset_top = -BORDER_THICKNESS
	bottom_strip.offset_bottom = 0.0
	parent.add_child(bottom_strip)

	var left_strip: ColorRect = ColorRect.new()
	left_strip.name = "Left"
	left_strip.color = EMBER_ORANGE
	left_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_strip.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left_strip.offset_left = 0.0
	left_strip.offset_right = BORDER_THICKNESS
	parent.add_child(left_strip)

	var right_strip: ColorRect = ColorRect.new()
	right_strip.name = "Right"
	right_strip.color = EMBER_ORANGE
	right_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_strip.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right_strip.offset_left = -BORDER_THICKNESS
	right_strip.offset_right = 0.0
	parent.add_child(right_strip)
	return parent


# ---- Internal: paint helpers ------------------------------------------


func _color_for_phase_label(phase: int) -> Color:
	# Active phase → HUD off-white; completed → muted parchment;
	# future → HUD disabled. Per Uma §"Phase label".
	if phase == _current_phase:
		return HUD_OFF_WHITE
	if phase < _current_phase:
		return MUTED_PARCHMENT
	return HUD_DISABLED


func _color_for_segment_phase(phase: int) -> Color:
	# Active phase → full red `#7A2A26`; completed → ghost-only (foreground
	# hidden via fill = 0); future → 60% brightness red.
	# This returns the FG color value; the per-frame fill width is set
	# separately by `_paint_active_segment_fill` for the active segment,
	# and by `_paint_completed_segments` for the completed ones.
	if phase == _current_phase:
		return SEGMENT_ACTIVE_FG
	if phase < _current_phase:
		return SEGMENT_ACTIVE_FG  # color stays; width snaps to 0 in paint helper
	return SEGMENT_FUTURE_FG


func _paint_initial_segment_state() -> void:
	# Each segment fg + ghost spans its full width by default (the
	# `_build_segment_row` step already sized them); refresh colors based
	# on current phase. Foreground stays 100% width on every segment at
	# show-time because we paint phases on phase_changed events (initial
	# phase is 1 — future segments stay at 100% width but 60% brightness).
	for i in range(_segment_count):
		var p: int = i + 1
		_segment_fgs[i].color = _color_for_segment_phase(p)
		# Set the foreground width based on phase state.
		# Active phase: full width (will be tracked by _on_damaged on hit).
		# Completed: width = 0 (segment is drained).
		# Future: full width (locked, 60% brightness).
		_set_segment_fg_fill(p, 1.0)
		# Ghost layer mirrors foreground initially (no drain yet).
		_set_segment_ghost_fill(p, 1.0)


## Set the foreground rect's width to `fraction × SEGMENT_WIDTH`.
## `fraction` is clamped to [0, 1]. Operates on the segment's `offset_right`
## relative to its `offset_left` so the fill drops from the right side
## (HP bar drains right-to-left, mirroring regular mob HP bar).
func _set_segment_fg_fill(phase: int, fraction: float) -> void:
	var i: int = phase - 1
	if i < 0 or i >= _segment_fgs.size():
		return
	var clamped: float = clampf(fraction, 0.0, 1.0)
	var fg: ColorRect = _segment_fgs[i]
	# Width = runtime-segment-width * fraction. offset_right = offset_left + width.
	fg.offset_right = fg.offset_left + _runtime_segment_width() * clamped


func _set_segment_ghost_fill(phase: int, fraction: float) -> void:
	var i: int = phase - 1
	if i < 0 or i >= _segment_ghosts.size():
		return
	var clamped: float = clampf(fraction, 0.0, 1.0)
	var ghost: ColorRect = _segment_ghosts[i]
	ghost.offset_right = ghost.offset_left + _runtime_segment_width() * clamped


func _apply_phase_label_state() -> void:
	for i in range(_segment_count):
		var p: int = i + 1
		_phase_labels[i].add_theme_color_override("font_color", _color_for_phase_label(p))


func _apply_boss_name(boss: Node) -> void:
	if _name_label == null:
		return
	var raw: String = _read_display_name(boss)
	if raw == "":
		_name_label.text = FALLBACK_BOSS_NAME
		return
	# Render uppercase per Uma §"Boss name (top-center, 16 px caps)".
	# `display_name` on MobDef ships title-cased ("Warden of the Outer
	# Cloister") so we uppercase here at render time rather than mutate
	# the source content.
	_name_label.text = raw.to_upper()


# ---- Internal: tween + signal handlers --------------------------------


func _start_slide_in_tween() -> void:
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	# Default scaled-process tween — pauses during T2 hit-pause / T16
	# freeze per `.claude/docs/time-scale-director.md`. Matches Vignette
	# + BossDefeatedTitleCard pattern.
	_slide_tween = create_tween()
	_slide_tween.set_parallel(true)
	# Slide offset_top from -PANEL_HEIGHT (offscreen) to TOP_MARGIN (on-screen).
	# offset_bottom from 0 to TOP_MARGIN + PANEL_HEIGHT in tandem keeps the
	# rect height constant during the tween.
	(
		_slide_tween
		. tween_property(_root, "offset_top", TOP_MARGIN, SLIDE_IN_DURATION)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_slide_tween
		. tween_property(_root, "offset_bottom", TOP_MARGIN + PANEL_HEIGHT, SLIDE_IN_DURATION)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_slide_tween
		. tween_property(_root, "modulate:a", 1.0, SLIDE_IN_DURATION)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	_slide_tween.chain().tween_callback(Callable(self, "_on_slide_in_done"))


func _on_slide_in_done() -> void:
	_slide_in_done = true
	slide_in_completed.emit()
	_combat_trace("BossNameplate.slide_in_completed", "")


func _subscribe_to_boss_signals(boss: Node) -> void:
	if boss == null:
		return
	if boss.has_signal("damaged"):
		if not boss.is_connected("damaged", _on_boss_damaged):
			boss.connect("damaged", _on_boss_damaged)
	if boss.has_signal("phase_changed"):
		if not boss.is_connected("phase_changed", _on_boss_phase_changed):
			boss.connect("phase_changed", _on_boss_phase_changed)
	if boss.has_signal("boss_died"):
		if not boss.is_connected("boss_died", _on_boss_died):
			boss.connect("boss_died", _on_boss_died)


func _on_boss_damaged(_amount: int, hp_remaining: int, _source: Node) -> void:
	if _dismissed:
		return
	# Compute active segment fill fraction. Within a phase, the fill is
	# `(hp_remaining - phase_floor) / (phase_ceiling - phase_floor)`.
	# Phase 1 spans hp_max..phase_2_threshold;
	# Phase 2 spans phase_2_threshold..phase_3_threshold;
	# Phase 3 spans phase_3_threshold..0.
	var fraction: float = _compute_active_segment_fill(hp_remaining)
	# Foreground snaps instantly; ghost drains via tween over GHOST_DRAIN_DURATION.
	_set_segment_fg_fill(_current_phase, fraction)
	_start_ghost_drain_tween(_current_phase, fraction)
	segment_fill_updated.emit(_current_phase, fraction)
	# T18 — Below-10% pulse trigger.
	if fraction < PULSE_THRESHOLD_FRACTION:
		_start_pulse_if_inactive(_current_phase)


func _compute_active_segment_fill(hp_remaining: int) -> float:
	if _hp_max_cached <= 0:
		return 0.0
	# Generic N-phase fill (ticket 86ca1m0at). The active phase `p` (1-indexed)
	# spans [ceiling_hp .. floor_hp] where:
	#   ceiling_frac = 1.0           if p == 1, else _boundary_fracs[p-2]
	#   floor_frac   = 0.0           if p > num_boundaries, else _boundary_fracs[p-1]
	# Fill = (hp - floor_hp) / (ceiling_hp - floor_hp), clamped to [0,1]. This
	# tracks the boss's REAL boundaries, so the bar no longer drains to 0 before
	# the boss's last phase (the Sponsor-soak "frozen bar + sudden death" cause).
	var num_boundaries: int = _boundary_fracs.size()
	var phase: int = clampi(_current_phase, 1, _segment_count)
	var ceiling_frac: float = 1.0
	if phase > 1 and (phase - 2) < num_boundaries:
		ceiling_frac = float(_boundary_fracs[phase - 2])
	var floor_frac: float = 0.0
	if (phase - 1) < num_boundaries:
		floor_frac = float(_boundary_fracs[phase - 1])
	var ceiling_hp: float = round(float(_hp_max_cached) * ceiling_frac)
	var floor_hp: float = round(float(_hp_max_cached) * floor_frac)
	var span: float = ceiling_hp - floor_hp
	if span <= 0.0:
		return 0.0
	return clampf((float(hp_remaining) - floor_hp) / span, 0.0, 1.0)


func _start_ghost_drain_tween(phase: int, target_fraction: float) -> void:
	var i: int = phase - 1
	if i < 0 or i >= _segment_ghosts.size():
		return
	# Kill any in-flight ghost tween for this segment so we don't stack.
	# This is the load-bearing idempotence on hit-spam — the ghost layer
	# always tracks the LATEST hit, not a stale snapshot of two-hits-ago.
	var existing: Tween = _ghost_tweens[i]
	if existing != null and existing.is_valid():
		existing.kill()
	var ghost: ColorRect = _segment_ghosts[i]
	# Compute the target offset_right value (matches the foreground when
	# the ghost finishes draining).
	var target_offset_right: float = ghost.offset_left + _runtime_segment_width() * target_fraction
	var t: Tween = create_tween()
	(
		t
		. tween_property(ghost, "offset_right", target_offset_right, GHOST_DRAIN_DURATION)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	_ghost_tweens[i] = t


func _on_boss_phase_changed(new_phase: int) -> void:
	if _dismissed:
		return
	# Idempotence — phase_changed only ever goes UP. A repeated emit at
	# the same phase (or backward) is a no-op.
	if new_phase <= _current_phase:
		return
	if new_phase > _segment_count:
		# Defensive — out-of-range phase emit. Cap at the last built segment.
		new_phase = _segment_count
	# Stop the pulse on the previously-active segment (if it was pulsing).
	_stop_pulse_for_segment(_current_phase)
	# Drain previously-active segment to 0 (visual completion).
	_set_segment_fg_fill(_current_phase, 0.0)
	_set_segment_ghost_fill(_current_phase, 0.0)
	_current_phase = new_phase
	# Brighten new active segment to full + flash the appropriate separator.
	_set_segment_fg_fill(_current_phase, 1.0)
	_set_segment_ghost_fill(_current_phase, 1.0)
	# Repaint phase labels (active brightens; completed mutes).
	_apply_phase_label_state()
	# Repaint segment colors (completed stays 0 width but color update is
	# defensive against future paint cycles).
	for i in range(_segment_count):
		var p: int = i + 1
		_segment_fgs[i].color = _color_for_segment_phase(p)
	# Flash the separator immediately before the new active segment.
	_flash_separator_for_phase(_current_phase)
	phase_transition_flashed.emit(_current_phase)
	_combat_trace("BossNameplate.phase_transition_flashed", "new_phase=%d" % _current_phase)


## Flash separator at the boundary leading INTO the new active phase.
## new_phase=2 → flash separator 0 (between segments 1 and 2).
## new_phase=3 → flash separator 1 (between segments 2 and 3).
func _flash_separator_for_phase(new_phase: int) -> void:
	var sep_idx: int = new_phase - 2  # 2 → 0, 3 → 1
	if sep_idx < 0 or sep_idx >= _segment_separators.size():
		return
	var sep: ColorRect = _segment_separators[sep_idx]
	# Kill existing flash tween if any (idempotent on rapid phase transit).
	var existing: Tween = _separator_flash_tweens[sep_idx]
	if existing != null and existing.is_valid():
		existing.kill()
	# Flash sequence — modulate.a from 1.0 down to 0.3 and back to 1.0,
	# over SEPARATOR_FLASH_DURATION. Symmetric so the separator never
	# stays dim. Modulate-alpha only (no RGB shift) — HDR-clamp safe.
	sep.modulate = Color(1, 1, 1, 1)
	var t: Tween = create_tween()
	t.tween_property(sep, "modulate:a", 0.3, SEPARATOR_FLASH_DURATION * 0.5)
	t.tween_property(sep, "modulate:a", 1.0, SEPARATOR_FLASH_DURATION * 0.5)
	_separator_flash_tweens[sep_idx] = t


# ---- T18 — Below-10% HP pulse ----------------------------------------


func _start_pulse_if_inactive(phase: int) -> void:
	if (
		_active_pulse_tween != null
		and _active_pulse_tween.is_valid()
		and _active_pulse_segment_index == phase - 1
	):
		return  # Already pulsing this segment.
	# Stop any prior pulse (rare — phase changed mid-pulse).
	_stop_pulse_for_segment(_active_pulse_segment_index + 1)
	var i: int = phase - 1
	if i < 0 or i >= _pulse_outlines.size():
		return
	var pulse: ColorRect = _pulse_outlines[i]
	# Reset alpha to 0 before tween so the first frame's tween direction
	# is well-defined (modulate.a goes 0 → 1 → 0 → 1 → ...).
	pulse.modulate = Color(1, 1, 1, 0)
	var t: Tween = create_tween()
	t.set_loops()  # infinite loop until killed
	# Half-period up, half-period down — produces a 1.5 Hz frequency
	# (full cycle is up + down = PULSE_PERIOD).
	t.tween_property(pulse, "modulate:a", 1.0, PULSE_PERIOD * 0.5)
	t.tween_property(pulse, "modulate:a", 0.0, PULSE_PERIOD * 0.5)
	_active_pulse_tween = t
	_active_pulse_segment_index = i


func _stop_pulse_for_segment(phase: int) -> void:
	if phase < 1 or phase > SEGMENT_COUNT:
		return
	if _active_pulse_tween != null and _active_pulse_tween.is_valid():
		_active_pulse_tween.kill()
	_active_pulse_tween = null
	var i: int = phase - 1
	if i >= 0 and i < _pulse_outlines.size():
		# Reset the outline to invisible — no lingering alpha.
		_pulse_outlines[i].modulate = Color(1, 1, 1, 0)
	if _active_pulse_segment_index == i:
		_active_pulse_segment_index = -1


# ---- Boss-died handler ------------------------------------------------


func _on_boss_died(_died_boss, _death_pos: Vector2, _mob_def) -> void:
	# Boss is dead — title card takes over. Stop pulse + ghost tweens.
	# Do NOT free the nameplate here; Main owns the lifecycle (the
	# nameplate parent is the Stratum1BossRoom or Main HUD).
	_dismissed = true
	_stop_pulse_for_segment(_active_pulse_segment_index + 1)
	# Drain remaining ghost tweens defensively.
	for i in range(_ghost_tweens.size()):
		var t: Tween = _ghost_tweens[i]
		if t != null and t.is_valid():
			t.kill()
		_ghost_tweens[i] = null


# ---- Boss-state reading (tolerant of test stubs) ----------------------


func _read_hp_max(boss: Node) -> int:
	if boss == null:
		return 0
	if boss.has_method("get_max_hp"):
		return boss.call("get_max_hp")
	if "hp_max" in boss:
		return boss.get("hp_max")
	return 0


func _read_initial_phase(boss: Node) -> int:
	if boss == null:
		return 1
	if boss.has_method("get_phase"):
		return boss.call("get_phase")
	if "phase" in boss:
		return boss.get("phase")
	return 1


func _read_display_name(boss: Node) -> String:
	if boss == null:
		return ""
	# Tolerant lookup — boss may be a typed Stratum1Boss with `mob_def`
	# property exposing `display_name`, OR a test stub exposing
	# `display_name` directly. Matches BossDefeatedTitleCard's resolve.
	if "mob_def" in boss and boss.mob_def != null:
		var def: Variant = boss.mob_def
		if "display_name" in def and (def.display_name as String) != "":
			return def.display_name as String
	if "display_name" in boss and (boss.display_name as String) != "":
		return boss.display_name as String
	return ""


# ---- Diagnostics ------------------------------------------------------


## Combat-trace shim — routes through DebugFlags.combat_trace (HTML5-only).
## Same pattern as `Stratum1BossRoom._combat_trace` /
## `BossDefeatedTitleCard._combat_trace`. Lets the Playwright harness
## assert nameplate slide-in + phase-transition events against console
## traces without depending on canvas-pixel inspection.
func _combat_trace(tag: String, msg: String = "") -> void:
	var df: Node = null
	if is_inside_tree():
		df = get_tree().root.get_node_or_null("DebugFlags")
	if df != null and df.has_method("combat_trace"):
		df.combat_trace(tag, msg)
