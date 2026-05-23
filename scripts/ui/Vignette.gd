class_name Vignette
extends CanvasLayer
## M3-T2-W2-T12 — Global vignette CanvasLayer + opacity-ramp API.
##
## Direction source: `team/uma-ux/vignette-spec.md` (Uma — binding).
## Scope source: `team/priya-pl/m3-tier2-boss-room-polish-scope.md §3 T12`.
## Palette amendment: `team/uma-ux/palette.md` line 30 (S1 vignette `#000000` →
## `#0A0606` per Uma vignette-spec, queued in PR #294).
##
## **Tonal anchor (Uma).** The vignette is the room's attention. Default 30%
## (S1 baseline, "the room is watching"); BI-04 deepens to 70% on boss-entry
## ("the room is closing"); F2 deepens to 80% during boss-defeat dissolve
## ("the room narrows to the moment"); F3 returns to 30% after the title-card
## dismiss ("the player has the room back").
##
## **Visual primitive — TextureRect, NOT Polygon2D.** Per Uma vignette-spec
## "Rendering layer + visual primitive" + `.claude/docs/html5-export.md`
## (PR #137 precedent — Polygon2D filled shapes can silently fail to render
## on `gl_compatibility` / WebGL2). Pre-baked radial-gradient ImageTexture is
## the lowest-risk path; HDR-clamp-safe (every channel sub-1.0) and uses no
## custom shaders (which carry their own gl_compatibility quirks).
##
## **Layer placement.** `layer = 5` — above world (default 0), below HUD
## (10), below InventoryPanel (80), below BossDefeatedTitleCard (50), below
## DescendScreen (100). HUD remains fully readable at every vignette opacity
## including the F2 80% peak.
##
## **Screen-space, not world-space.** CanvasLayer ignores Camera2D transform
## by definition — the vignette does not zoom with the T9/T16 camera ease-in
## to 1.5×. Matches the HUD-anchor-pattern from T9.
##
## **Idempotence.** `set_opacity_tween()` kills any in-flight tween before
## starting a new one — rapid calls (boss-entry-then-defeat-skip edge case)
## produce one continuous tween, not two overlapping.
##
## **Scaled tweens — intentional pause during freeze.** Per
## `.claude/docs/time-scale-director.md` § "Scaled tweens — intentional pause
## during freeze": the opacity tween is a default `create_tween()` with no
## `ignore_time_scale` override, so it advances on scaled `_process` delta
## and pauses during any T2 hit-pause / T16 freeze. This is the desired
## cinematic behaviour — the vignette deepening "feels" the freeze and
## resumes synchronised with siblings (T16 embers, BossDefeatedTitleCard,
## etc., which are also scaled).
##
## **HTML5 visual-verification gate.** This is a CanvasLayer + TextureRect
## + modulate-alpha tween. The "renderer-safe primitives" argument is NOT a
## substitute for an HTML5 screenshot per `.claude/docs/html5-export.md`
## § "A renderer-safe primitives argument is NOT a substitute for a
## screenshot." Self-Test Report invokes the per-surface escape clause for
## the TextureRect-modulate-tween surface and routes HTML5 visual to
## Sponsor-soak with concrete probe targets.

# ---- Spec constants (locked from Uma vignette-spec.md) ----------------

## Warm-black tint per Uma vignette-spec.md § "Tint decision":
## `Color(0.04, 0.024, 0.024, opacity)` = `#0A0606`.
## All RGB channels sub-1.0 for HDR-clamp safety per html5-export.md.
const VIGNETTE_TINT: Color = Color(0.04, 0.024, 0.024, 1.0)

## S1 baseline opacity per `team/uma-ux/palette.md` line 30 (30% → 60% S1→S8
## ramp). T12 ships the S1 baseline; cross-stratum baseline shift is a
## separate ticket per Uma vignette-spec § "Default boot state".
const DEFAULT_OPACITY_S1: float = 0.30

## Locked duration + curve combinations per Uma vignette-spec § "Duration
## locks per consumer". The convenience methods bake these in; consumers
## (T13 nameplate, T16 cinematic) call the named methods rather than the
## general API.
const BI04_BOSS_ENTRY_TARGET: float = 0.70
const BI04_BOSS_ENTRY_DURATION: float = 0.6  # 600 ms
const F2_BOSS_DEFEAT_TARGET: float = 0.80
const F2_BOSS_DEFEAT_DURATION: float = 0.9  # 900 ms
const F3_POST_TITLECARD_TARGET: float = 0.30
const F3_POST_TITLECARD_DURATION: float = 0.4  # 400 ms

## Curve preset enum — matches the API contract in Uma vignette-spec
## § "API surface". `CURVE_EASE_IN_OUT_CUBIC` is the default (BI-04 + F2);
## `CURVE_EASE_OUT_CUBIC` is the post-climax "room exhales" return (F3).
const CURVE_EASE_IN_OUT_CUBIC: int = 0
const CURVE_EASE_OUT_CUBIC: int = 1

## Pre-baked radial-gradient texture dimensions. 256x256 keeps the asset
## small while providing enough radius samples for smooth falloff at
## 1280x720 viewport (TextureRect stretches via EXPAND_KEEP_ASPECT_COVERED).
const GRADIENT_TEX_SIZE: int = 256

# ---- Signals ----------------------------------------------------------

## Emitted after `set_opacity_tween(...)` completes its tween (target
## reached). Tests subscribe to assert ramp completion without polling.
signal opacity_tween_completed(target: float)

# ---- Runtime ----------------------------------------------------------

var _texture_rect: TextureRect = null
var _active_tween: Tween = null


func _init() -> void:
	# Layer 5: above world (default 0), below HUD (10). Per Uma vignette-spec
	# § "Layer ordering" and `scenes/Main.gd` HUD layer = 10.
	layer = 5


func _ready() -> void:
	_build_texture_rect()
	# Boot at S1 baseline (30%) per Uma vignette-spec § "Default boot state".
	set_opacity(DEFAULT_OPACITY_S1)


func _exit_tree() -> void:
	# Defensive cleanup — kill any in-flight tween before the node is
	# autofreed. If a tween's bound callback fires after the node leaves
	# the tree, GUT's autofree raises "Object is locked and can't be freed"
	# from `addons/gut/autofree.gd:51`. Production never hits this (Main's
	# vignette lives the lifetime of the play loop), but tests instantiate +
	# free vignettes per `after_each`, and a partial tween becomes the
	# locked object. Killing here releases the callback binding cleanly.
	_kill_active_tween()


# ---- Public API (Uma vignette-spec § "API surface") --------------------


## Set vignette opacity directly (no tween). `value` is clamped to `[0.0, 1.0]`.
## Used for boot init + tests + any consumer that needs an instant snap.
func set_opacity(value: float) -> void:
	if _texture_rect == null:
		return
	var clamped: float = clampf(value, 0.0, 1.0)
	# Kill any in-flight tween — instantaneous set wins over a partial ramp.
	_kill_active_tween()
	# Modulate alpha only; RGB stays at (1, 1, 1) so the texture's pre-baked
	# `#0A0606` warm-black tint is preserved unscaled (sub-1.0 — HDR-clamp safe).
	var m: Color = _texture_rect.modulate
	_texture_rect.modulate = Color(m.r, m.g, m.b, clamped)


## Tween vignette opacity over `duration` with the specified curve.
## `curve_preset` defaults to `CURVE_EASE_IN_OUT_CUBIC` (BI-04 + F2 shape);
## pass `CURVE_EASE_OUT_CUBIC` for the F3 post-climax return.
## Idempotent: a second call while a tween is active kills the previous
## tween before starting the new one (no overlap).
func set_opacity_tween(
	value: float, duration: float, curve_preset: int = CURVE_EASE_IN_OUT_CUBIC
) -> void:
	if _texture_rect == null:
		return
	var target: float = clampf(value, 0.0, 1.0)
	# Kill any in-flight tween (idempotence). Required for the boss-entry-then-
	# immediate-defeat edge case + the rapid-call test in `test_vignette.gd`.
	_kill_active_tween()
	# Default scaled-process tween — pauses during T2 hit-pause / T16 freeze
	# per `.claude/docs/time-scale-director.md` § "Scaled tweens — intentional
	# pause during freeze". This is the desired cinematic behaviour.
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_CUBIC)
	if curve_preset == CURVE_EASE_OUT_CUBIC:
		_active_tween.set_ease(Tween.EASE_OUT)
	else:
		_active_tween.set_ease(Tween.EASE_IN_OUT)
	_active_tween.tween_property(_texture_rect, "modulate:a", target, duration)
	# Completion callback emits signal for tests + later consumers (the F3
	# return callback could chain off this if a future ticket needs it).
	_active_tween.tween_callback(Callable(self, "_on_tween_completed").bind(target))


## Convenience: BI-04 boss-entry deepen — `current → 70%` over 600 ms,
## ease-in-out cubic. T13 nameplate consumer calls this on
## `Stratum1BossRoom.entry_sequence_started`.
func boss_entry_deepen() -> void:
	set_opacity_tween(BI04_BOSS_ENTRY_TARGET, BI04_BOSS_ENTRY_DURATION, CURVE_EASE_IN_OUT_CUBIC)


## Convenience: F2 boss-defeat climax — `current → 80%` over 900 ms,
## ease-in-out cubic. T16 cinematic consumer calls this on `boss_defeated`
## (with T+0.3 s offset to match Beat F2 start per Uma vignette-spec).
func boss_defeat_climax() -> void:
	set_opacity_tween(F2_BOSS_DEFEAT_TARGET, F2_BOSS_DEFEAT_DURATION, CURVE_EASE_IN_OUT_CUBIC)


## Convenience: F3 post-titlecard return — `current → 30%` over 400 ms,
## ease-out cubic. T16 cinematic consumer calls this on
## `boss_defeated_card_dismissed` (or T+2.4 s timer).
func boss_defeat_return() -> void:
	set_opacity_tween(F3_POST_TITLECARD_TARGET, F3_POST_TITLECARD_DURATION, CURVE_EASE_OUT_CUBIC)


# ---- Test introspection ----------------------------------------------


func get_texture_rect() -> TextureRect:
	return _texture_rect


func get_current_opacity() -> float:
	if _texture_rect == null:
		return 0.0
	return _texture_rect.modulate.a


func has_active_tween() -> bool:
	return _active_tween != null and _active_tween.is_valid()


# ---- Internal --------------------------------------------------------


func _build_texture_rect() -> void:
	if _texture_rect != null:
		return
	_texture_rect = TextureRect.new()
	_texture_rect.name = "VignetteOverlay"
	_texture_rect.texture = _build_radial_gradient_texture()
	# Stretch to viewport via expand+cover. The CanvasLayer's transform is
	# screen-space; the TextureRect's anchors fill the full viewport.
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Never absorb mouse input — pickups, click-to-attack, HUD interactions
	# must pass through. Same rule as BossDefeatedTitleCard root Control.
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Initial modulate: pre-baked tint already encodes the `#0A0606` color in
	# the texture's RGB; modulate.rgb stays at (1, 1, 1) so the tint shows
	# through unscaled. Alpha set to 0 here, then `set_opacity(0.30)` in
	# `_ready` ramps it to the S1 baseline.
	_texture_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(_texture_rect)


## Build the radial-gradient ImageTexture procedurally.
##
## Center = `Color(0.04, 0.024, 0.024, 0.0)` (transparent warm-black at center)
## Edges  = `Color(0.04, 0.024, 0.024, 1.0)` (opaque warm-black at corners)
## Per Uma vignette-spec § "Visual primitive — ColorRect, NOT Polygon2D" — the
## pre-baked radial-gradient approach. Generating the texture procedurally
## (instead of shipping a binary PNG) keeps the asset version-controllable
## as code while producing an identical render result; the TextureRect
## consumes a `Texture2D` either way.
##
## Smooth quadratic falloff (`t * t`) is the Uma-aesthetic-locked shape; pure
## linear falloff produces a "darker ring" feel that conflicts with the
## "room's attention" anchor.
##
## **HDR-clamp safety:** every pixel's RGB is `(10, 6, 6)` (sub-0.05 on a
## 0..255 scale = sub-0.001 on the 0..1 GPU scale). Alpha is in `[0, 1]` by
## image-format constraint. Sub-1.0 on every channel; safe across
## `forward_plus`/`mobile`/`gl_compatibility` per html5-export.md.
func _build_radial_gradient_texture() -> Texture2D:
	var size: int = GRADIENT_TEX_SIZE
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center_x: float = float(size) * 0.5
	var center_y: float = float(size) * 0.5
	# Max radius = corner distance from center. Using the corner instead of
	# the edge-midpoint means the alpha at the screen edges (when stretched
	# to viewport via EXPAND_KEEP_ASPECT_COVERED) is non-saturating — slight
	# headroom keeps the center darkening curve smooth.
	var max_r: float = sqrt(center_x * center_x + center_y * center_y)
	# Pre-baked tint — locked color from Uma vignette-spec § "Tint decision".
	# Same hex as `VIGNETTE_TINT` but expressed as integer 0-255 components
	# for direct Image.set_pixel().
	var tint_r: float = VIGNETTE_TINT.r
	var tint_g: float = VIGNETTE_TINT.g
	var tint_b: float = VIGNETTE_TINT.b
	for y in size:
		for x in size:
			var dx: float = float(x) - center_x
			var dy: float = float(y) - center_y
			var r: float = sqrt(dx * dx + dy * dy)
			# Normalized distance [0..1] from center to corner.
			var t: float = clampf(r / max_r, 0.0, 1.0)
			# Smooth quadratic falloff — t=0 at center (transparent), t=1 at
			# corner (opaque). Squaring produces the "room watches" feel; the
			# center stays transparent for longer, edges darken sharply.
			var a: float = t * t
			img.set_pixel(x, y, Color(tint_r, tint_g, tint_b, a))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	return tex


func _kill_active_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null


func _on_tween_completed(target: float) -> void:
	opacity_tween_completed.emit(target)
	_active_tween = null
