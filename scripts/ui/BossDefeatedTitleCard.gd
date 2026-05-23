class_name BossDefeatedTitleCard
extends CanvasLayer
## M3-T4 — defeat title card. "The Warden falls." + STRATUM 1 CLEARED.
##
## Direction source: `team/uma-ux/m3-t4-defeat-title-card-brief.md` (Uma —
## binding). See also `team/uma-ux/boss-intro.md` Beat F3.
##
## **Tonal anchor.** The card is the silence that lets the kill land — two
## lines of off-white text breathing against the darkened post-boss room.
## NO audio fires under the card; the F2 horn (sibling ticket T16) IS the
## title-card audio. Adding any sting/chime here would compete with the
## wordmark and break the beat.
##
## **Lifecycle.** Lazily instantiated in `Main._on_boss_defeated(...)` once
## per kill, runs the fade sequence, then `queue_free`s itself. The card
## does NOT live in the scene tree across the run.
##
## **Skip rule (locked).** Unskippable on every kill. Per Uma §4 — the
## defeat card is 1.6 s of payoff after a ~30-60 s fight; making it
## skippable would expose a key-listener surface that could accidentally
## fire while the player reaches for the dropped loot under the card.
## Input falls through to the player; `mouse_filter = IGNORE` on the Root
## Control is the structural enforcement.
##
## **Scaled-tween scheduling.** Tweens default to scaled-process (game
## time, NOT wall time) — this is INTENTIONAL. Per `.claude/docs/time-scale-director.md`,
## if a future T2 hit-pause `freeze()` window spans T+0.0..T+0.3 after
## `boss_defeated`, the card's PRE_FADE_DELAY tween pauses during the
## freeze and resumes when it releases. The card "feels" the freeze and
## lands AFTER it — synchronised with T16's embers + horn (which are also
## scaled). If a future cue needs wall-time, wrap it in an
## `ignore_time_scale=true` SceneTreeTimer per `TimeScaleDirector.freeze`.
##
## **HTML5 visual-verification gate.** This is a modulate+Label tween on a
## CanvasLayer — per `.claude/docs/html5-export.md` § "renderer-safe
## primitives" rule, the safe-primitives argument is NOT a substitute for
## an HTML5 screenshot. Self-Test Report must include a release-build
## screenshot or short clip showing the card fading in over the post-boss
## room state.

# ---- Spec constants (locked from Uma's brief §1, §3) ------------------

const FADE_IN_DURATION: float = 0.4
const HOLD_DURATION: float = 0.8
const FADE_OUT_DURATION: float = 0.4
## Game-time delay between `boss_defeated` emit and the card's fade-in
## start. Synchronised with Uma's F3 timeline — the F2 horn (sibling T16)
## starts at T+0.3 and runs ~0.9 s; the card lands as the horn tails out
## into silence.
const PRE_FADE_DELAY: float = 1.2

## Title color — HUD body off-white (`team/uma-ux/palette.md:24`). NOT
## ember-orange. Ember is reserved for the player's flame (descend,
## level-up, item-drops); the boss's death is the absence of the boss's
## flame, not a player flourish.
const TITLE_COLOR: Color = Color("e8e4d6")
## Subtitle color — muted parchment (`team/uma-ux/palette.md:25`). The
## subtitle is the *context tag* not the *headline*; muted parchment
## recedes so the off-white wordmark leads.
const SUBTITLE_COLOR: Color = Color("b8ac8e")

const TITLE_FONT_SIZE: int = 40
const SUBTITLE_FONT_SIZE: int = 14

## Subtitle is hard-coded for M1; future strata template by current
## stratum id. The card is M1-only at this milestone.
const SUBTITLE_TEXT: String = "STRATUM 1 CLEARED"
## Title template — first word of the boss's `display_name`. Works for
## "Warden of the Outer Cloister" → "Warden", future "Stoker of Vault
## Forge" → "Stoker", single-word "Vorgath" → "Vorgath". Period at the
## end is intentional — declarative sentence, not banner (Uma §1).
const TITLE_TEMPLATE: String = "The %s falls."
## Fallback boss-name token if `MobDef.display_name` is empty / null.
const FALLBACK_BOSS_NAME: String = "Warden"

## Visual layout — title baseline above geometric center, subtitle 12 px
## below (Uma §1 — "slightly above center reads as rising, not settling").
const TITLE_BASELINE_OFFSET_Y: float = -12.0
const SUBTITLE_BASELINE_OFFSET_Y: float = 24.0

# ---- Signals ----------------------------------------------------------

## Emitted when the fade-in tween starts (T+1.2 game-time post-trigger).
## Playwright spec hook + GUT timing test hook.
signal title_card_shown()

## Emitted when the fade-out tween completes and the node is about to
## `queue_free`. Tests use this to assert the lifecycle landed.
signal title_card_dismissed()

# ---- Runtime ----------------------------------------------------------

var _root: Control = null
var _title_label: Label = null
var _subtitle_label: Label = null
var _tween: Tween = null
var _shown: bool = false
var _dismissed: bool = false


func _init() -> void:
	# CanvasLayer above HUD. HUD lives ≤49; card sits at 50 per Uma §1.
	layer = 50


func _ready() -> void:
	_build_ui()


# ---- Public API -------------------------------------------------------

## Kicks off the fade sequence. Idempotent — a second call while the
## card is on screen is a no-op (the room emits `boss_defeated` exactly
## once per fight per `Stratum1BossRoom.gd:427`, but pin it anyway).
##
## `boss` is a Stratum1Boss (typed loosely here so tests can pass a
## minimal stub). `_death_position` is currently unused; reserved in case
## a future spec wants to anchor the card to the death point.
func show_for(boss: Node, _death_position: Vector2 = Vector2.ZERO) -> void:
	if _shown:
		return
	_shown = true
	if _root == null:
		_build_ui()
	_apply_title_text_from_boss(boss)
	# Start invisible — the fade-in tween ramps to opaque.
	_root.modulate.a = 0.0
	_start_tween()


## Resolves the boss's short name from its `MobDef.display_name`. First
## word + capital-T prefix. Per Uma §6 note 1 — produces correct output
## for every boss across M1-M3 as currently named. M3+ bosses that break
## the pattern can opt into a `short_defeat_name: String` override on
## MobDef (NOT in T4 scope; deferred per Uma §7 note 5).
func resolve_short_name(boss: Node) -> String:
	if boss == null:
		return FALLBACK_BOSS_NAME
	# Tolerant lookup — boss may be a typed Stratum1Boss with `mob_def`
	# property OR a test stub that exposes `display_name` directly.
	var raw: String = ""
	if "mob_def" in boss and boss.mob_def != null:
		var def: Variant = boss.mob_def
		if "display_name" in def and (def.display_name as String) != "":
			raw = def.display_name as String
	elif "display_name" in boss and (boss.display_name as String) != "":
		raw = boss.display_name as String
	if raw == "":
		return FALLBACK_BOSS_NAME
	var parts: PackedStringArray = raw.split(" ", false)
	if parts.size() == 0:
		return FALLBACK_BOSS_NAME
	return parts[0]


# ---- Test introspection -----------------------------------------------

func get_root_control() -> Control:
	return _root


func get_title_label() -> Label:
	return _title_label


func get_subtitle_label() -> Label:
	return _subtitle_label


func is_shown() -> bool:
	return _shown


func is_dismissed() -> bool:
	return _dismissed


# ---- Internal --------------------------------------------------------

func _build_ui() -> void:
	if _root != null:
		return
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Card never absorbs clicks — loot may drop UNDER the card during the
	# hold phase (Uma §3 — T+1.6 loot drop lands during card visibility).
	# Pickup interaction must fall through to the player.
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Pre-`show_for` the card sits invisible. Avoids a one-frame flash on
	# instantiation before the tween's first frame runs.
	_root.modulate = Color(1, 1, 1, 0)
	add_child(_root)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = TITLE_TEMPLATE % FALLBACK_BOSS_NAME
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", TITLE_COLOR)
	_title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	# Center the label across the full Root rect; positional offset
	# anchors it slightly above geometric center per Uma §1.
	_title_label.set_anchors_preset(Control.PRESET_CENTER)
	_title_label.offset_left = -240.0
	_title_label.offset_right = 240.0
	_title_label.offset_top = TITLE_BASELINE_OFFSET_Y - 22.0
	_title_label.offset_bottom = TITLE_BASELINE_OFFSET_Y + 22.0
	_root.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.name = "SubtitleLabel"
	_subtitle_label.text = SUBTITLE_TEXT
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_color_override("font_color", SUBTITLE_COLOR)
	_subtitle_label.add_theme_font_size_override("font_size", SUBTITLE_FONT_SIZE)
	_subtitle_label.set_anchors_preset(Control.PRESET_CENTER)
	_subtitle_label.offset_left = -240.0
	_subtitle_label.offset_right = 240.0
	_subtitle_label.offset_top = SUBTITLE_BASELINE_OFFSET_Y - 10.0
	_subtitle_label.offset_bottom = SUBTITLE_BASELINE_OFFSET_Y + 10.0
	_root.add_child(_subtitle_label)


func _apply_title_text_from_boss(boss: Node) -> void:
	if _title_label == null:
		return
	var short_name: String = resolve_short_name(boss)
	_title_label.text = TITLE_TEMPLATE % short_name


func _start_tween() -> void:
	# Kill any in-flight tween defensively — keeps `show_for` re-entrant
	# in tests that exercise the path twice.
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	# Default `Tween.TWEEN_PROCESS_IDLE` + node `PROCESS_MODE_INHERIT`
	# means the tween advances on scaled `_process` delta — paused during
	# any `Engine.time_scale = 0.0` freeze, resumes when freeze releases.
	# This is the Uma-locked behaviour (§3 — "the card 'feels' the freeze
	# and lands after it").
	_tween.tween_interval(PRE_FADE_DELAY)
	_tween.tween_callback(Callable(self, "_emit_title_card_shown"))
	# Fade in — modulate.a only. RGB stays at (1, 1, 1) — never modulate
	# above 1.0 on any channel per `.claude/docs/html5-export.md` § HDR
	# clamp.
	(_tween.tween_property(_root, "modulate:a", 1.0, FADE_IN_DURATION)
		.set_trans(Tween.TRANS_QUAD)
		.set_ease(Tween.EASE_OUT))
	# Hold — explicit interval keeps the tween chain readable.
	_tween.tween_interval(HOLD_DURATION)
	# Fade out — symmetric easing.
	(_tween.tween_property(_root, "modulate:a", 0.0, FADE_OUT_DURATION)
		.set_trans(Tween.TRANS_QUAD)
		.set_ease(Tween.EASE_IN))
	# Completion callback: emit dismiss signal then queue_free. NEVER
	# call into Area2D monitoring mutations or `add_child` here — per
	# `.claude/docs/combat-architecture.md` § "physics-flush rule", a
	# Tween callback landing during a physics-tick context is a known
	# panic surface. T4 is cosmetic; the only path is `queue_free`.
	_tween.tween_callback(Callable(self, "_on_fade_complete"))


func _emit_title_card_shown() -> void:
	title_card_shown.emit()
	_combat_trace("BossDefeatedTitleCard.title_card_shown",
		"text='%s' subtitle='%s'" % [_title_label.text, _subtitle_label.text])


func _on_fade_complete() -> void:
	if _dismissed:
		return
	_dismissed = true
	title_card_dismissed.emit()
	_combat_trace("BossDefeatedTitleCard.title_card_dismissed", "")
	queue_free()


## Combat-trace shim — routes through DebugFlags.combat_trace (HTML5-only).
## Same pattern as `Stratum1BossRoom._combat_trace` / `RoomGate._combat_trace`.
## Lets the Playwright harness assert title-card visibility against a
## console trace line without depending on canvas-pixel inspection.
func _combat_trace(tag: String, msg: String = "") -> void:
	var df: Node = null
	if is_inside_tree():
		df = get_tree().root.get_node_or_null("DebugFlags")
	if df != null and df.has_method("combat_trace"):
		df.combat_trace(tag, msg)
