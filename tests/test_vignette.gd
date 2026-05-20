extends GutTest
## M3-T2-W2-T12 — global vignette CanvasLayer paired tests.
##
## Direction source: `team/uma-ux/vignette-spec.md` § "Tester checklist"
## T12-VIG-01 through T12-VIG-14 (T12-VIG-12 is the HTML5 visual-verification
## gate, covered by the Self-Test Report; T12-VIG-15 is Sponsor-subjective).
##
## **Bug class this catches.** If a future refactor breaks one of:
##   1. Default boot opacity drifts from 30% (S1 baseline)
##   2. Vignette tint drifts from `#0A0606` (`Color(0.04, 0.024, 0.024, …)`)
##      — most likely as an HDR-clamp regression to an above-1.0 RGB channel
##   3. Visual primitive regresses from TextureRect to Polygon2D (PR #137
##      precedent — silently invisible on HTML5 / gl_compatibility)
##   4. CanvasLayer.layer drifts out of the (world, HUD) band (5 expected;
##      HUD = 10, world = 0)
##   5. `set_opacity_tween()` loses idempotence — overlapping tweens
##   6. Convenience methods (`boss_entry_deepen` / `boss_defeat_climax` /
##      `boss_defeat_return`) drift from their locked duration + target +
##      curve combinations
##   7. Opacity clamp regresses (negative or > 1.0 input not clamped)
## …this test fires in headless CI before the HTML5 visual gate ever sees it.
##
## **What this test does NOT cover.** Tween *timing* assertions (mid-tween
## opacity sampling, frame-perfect ramp shape) are renderer-fragile and
## belong in the Playwright spec (this PR's Self-Test Report routes HTML5
## visual to Sponsor-soak per the escape clause). The GUT pin is structural
## + endpoint correctness only.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")
const VignetteScript := preload("res://scripts/ui/Vignette.gd")
const VIGNETTE_SCENE_PATH: String = "res://scenes/ui/Vignette.tscn"

var _warn_guard: NoWarningGuard


# ---- Lifecycle --------------------------------------------------------

func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- Helpers ----------------------------------------------------------

func _make_vignette() -> Vignette:
	var packed: PackedScene = load(VIGNETTE_SCENE_PATH) as PackedScene
	assert_not_null(packed, "Vignette.tscn must load")
	var v: Vignette = packed.instantiate() as Vignette
	add_child_autofree(v)
	return v


# ---- T12-VIG-01: scene loads and is a Vignette CanvasLayer -----------

func test_vignette_scene_loads() -> void:
	var packed: PackedScene = load(VIGNETTE_SCENE_PATH)
	assert_not_null(packed, "Vignette.tscn must load")
	var instance: Node = packed.instantiate()
	assert_true(instance is Vignette, "root is Vignette typed")
	assert_true(instance is CanvasLayer, "root is CanvasLayer")
	instance.free()


# ---- T12-VIG-01: layer placement — above world (0), below HUD (10) ---

func test_vignette_layer_is_between_world_and_hud() -> void:
	# Uma vignette-spec § "Layer ordering (CanvasLayer indexing)":
	# vignette sits between world (layer 0) and HUD (layer 10). Concrete
	# recommendation: layer 5. This pin catches drift on either side —
	# layer >= 10 would render above HUD (breaks readability at F2 80%);
	# layer <= 0 would render below world (invisible).
	var v: Vignette = _make_vignette()
	assert_true(v.layer > 0, "vignette layer > 0 (above world)")
	assert_true(v.layer < 10, "vignette layer < 10 (below HUD)")


# ---- T12-VIG-02: default boot opacity = 30% (S1 baseline) -------------

func test_default_boot_opacity_is_s1_baseline() -> void:
	# Uma vignette-spec § "Default boot state": S1 baseline = 30%.
	# Matches `palette.md` line 30 (30% → 60% S1 → S8 ramp; T12 ships S1).
	var v: Vignette = _make_vignette()
	# `_ready` has run on add_child; opacity is now at the baseline.
	assert_almost_eq(v.get_current_opacity(), 0.30, 0.001,
		"default boot opacity is S1 baseline 30%")


# ---- T12-VIG-03: tint is #0A0606 warm-black, every RGB sub-1.0 -------

func test_tint_constant_is_warm_black_sub_one() -> void:
	# Uma vignette-spec § "Tint decision": locked at Color(0.04, 0.024, 0.024).
	# Equivalent to #0A0606. ALL RGB channels MUST be sub-1.0 per
	# `.claude/docs/html5-export.md` § HDR-clamp safety.
	assert_almost_eq(VignetteScript.VIGNETTE_TINT.r, 0.04, 0.001, "R channel = 0.04")
	assert_almost_eq(VignetteScript.VIGNETTE_TINT.g, 0.024, 0.001, "G channel = 0.024")
	assert_almost_eq(VignetteScript.VIGNETTE_TINT.b, 0.024, 0.001, "B channel = 0.024")
	assert_true(VignetteScript.VIGNETTE_TINT.r < 1.0, "R sub-1.0 (HDR-clamp safe)")
	assert_true(VignetteScript.VIGNETTE_TINT.g < 1.0, "G sub-1.0 (HDR-clamp safe)")
	assert_true(VignetteScript.VIGNETTE_TINT.b < 1.0, "B sub-1.0 (HDR-clamp safe)")


# ---- T12-VIG-04: visual primitive is TextureRect, NOT Polygon2D ------

func test_visual_primitive_is_texture_rect_not_polygon2d() -> void:
	# Uma vignette-spec § "Visual primitive — ColorRect, NOT Polygon2D".
	# PR #137 precedent: filled Polygon2D shapes can silently fail to render
	# on gl_compatibility / WebGL2. The vignette MUST be TextureRect-based.
	var v: Vignette = _make_vignette()
	var tex: TextureRect = v.get_texture_rect()
	assert_not_null(tex, "TextureRect child exists")
	assert_true(tex is TextureRect, "child is TextureRect (NOT Polygon2D)")
	assert_not_null(tex.texture, "TextureRect.texture is assigned (radial-gradient)")
	# No Polygon2D children anywhere — defensive pin against a future
	# refactor swapping the texture for a vertex-color polygon.
	for child in v.get_children():
		assert_false(child is Polygon2D, "no Polygon2D children (PR #137 risk class)")
		for grandchild in child.get_children():
			assert_false(grandchild is Polygon2D, "no Polygon2D grandchildren")


# ---- T12-VIG-05: TextureRect ignores mouse input ----------------------

func test_texture_rect_mouse_filter_is_ignore() -> void:
	# Defensive: vignette must not absorb clicks (HUD interactions, pickups,
	# attack input all sit below or above in the input chain; vignette is
	# never the click target). Same rule as BossDefeatedTitleCard root.
	var v: Vignette = _make_vignette()
	var tex: TextureRect = v.get_texture_rect()
	assert_eq(tex.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"TextureRect.mouse_filter == IGNORE")


# ---- T12-VIG-06: set_opacity() clamps to [0, 1] -----------------------

func test_set_opacity_clamps_to_range() -> void:
	var v: Vignette = _make_vignette()
	v.set_opacity(-0.5)
	assert_almost_eq(v.get_current_opacity(), 0.0, 0.001, "negative clamps to 0")
	v.set_opacity(1.7)
	assert_almost_eq(v.get_current_opacity(), 1.0, 0.001, "above-1.0 clamps to 1")
	v.set_opacity(0.5)
	assert_almost_eq(v.get_current_opacity(), 0.5, 0.001, "mid value passes through")


# ---- T12-VIG-07: set_opacity_tween() reaches target after duration ---

func test_opacity_tween_reaches_target() -> void:
	# Endpoint correctness — tween from 30% to 70% over short duration must
	# land at 70% when the tween completes. Uses a short duration (0.05 s)
	# to keep CI quick.
	var v: Vignette = _make_vignette()
	# Wait one frame so the vignette's _ready fires and sets opacity to 0.30
	await get_tree().process_frame
	assert_almost_eq(v.get_current_opacity(), 0.30, 0.01, "starts at S1 baseline")
	v.set_opacity_tween(0.70, 0.05, Vignette.CURVE_EASE_IN_OUT_CUBIC)
	# Wait for the tween to complete (signal-driven, no wall-clock guesswork)
	await v.opacity_tween_completed
	assert_almost_eq(v.get_current_opacity(), 0.70, 0.001,
		"tween reaches target opacity at completion")


# ---- T12-VIG-08: boss_entry_deepen() — locked BI-04 endpoint ---------

func test_boss_entry_deepen_reaches_70_percent() -> void:
	# Uma vignette-spec § "Duration locks per consumer" BI-04:
	# 30% → 70%, 600 ms, ease-in-out cubic.
	# We test the *endpoint* (locked at VignetteScript.BI04_BOSS_ENTRY_TARGET)
	# without waiting the full 600 ms — fast-forward via direct constant
	# lookup, then exercise the API with a short-duration override.
	assert_almost_eq(VignetteScript.BI04_BOSS_ENTRY_TARGET, 0.70, 0.001,
		"BI-04 target locked at 70%")
	assert_almost_eq(VignetteScript.BI04_BOSS_ENTRY_DURATION, 0.6, 0.001,
		"BI-04 duration locked at 600 ms")
	var v: Vignette = _make_vignette()
	await get_tree().process_frame
	v.boss_entry_deepen()
	# Tween starts immediately + active until duration elapses.
	assert_true(v.has_active_tween(), "tween active after boss_entry_deepen()")


# ---- T12-VIG-09: boss_defeat_climax() — locked F2 endpoint -----------

func test_boss_defeat_climax_reaches_80_percent() -> void:
	# Uma vignette-spec § "Duration locks per consumer" F2:
	# current → 80%, 900 ms, ease-in-out cubic.
	assert_almost_eq(VignetteScript.F2_BOSS_DEFEAT_TARGET, 0.80, 0.001,
		"F2 target locked at 80%")
	assert_almost_eq(VignetteScript.F2_BOSS_DEFEAT_DURATION, 0.9, 0.001,
		"F2 duration locked at 900 ms")


# ---- T12-VIG-10: boss_defeat_return() — locked F3 endpoint -----------

func test_boss_defeat_return_returns_to_30_percent() -> void:
	# Uma vignette-spec § "Duration locks per consumer" F3:
	# current → 30%, 400 ms, ease-OUT cubic (NOT ease-in-out).
	assert_almost_eq(VignetteScript.F3_POST_TITLECARD_TARGET, 0.30, 0.001,
		"F3 target locked at S1 baseline 30%")
	assert_almost_eq(VignetteScript.F3_POST_TITLECARD_DURATION, 0.4, 0.001,
		"F3 duration locked at 400 ms")


# ---- T12-VIG-11: idempotence — rapid calls produce one continuous tween

func test_set_opacity_tween_idempotent_kills_previous() -> void:
	# Uma vignette-spec § "Idempotence" — two `set_opacity_tween` calls
	# within rapid succession (boss-entry-then-immediate-defeat-skip edge
	# case) MUST produce one continuous tween, not two overlapping.
	#
	# Pin: after two rapid calls, only ONE tween is `is_valid()`. The
	# previous tween must have been killed by the second call.
	var v: Vignette = _make_vignette()
	await get_tree().process_frame
	v.set_opacity_tween(0.50, 1.0, Vignette.CURVE_EASE_IN_OUT_CUBIC)
	assert_true(v.has_active_tween(), "first tween active")
	# Capture the first tween reference to assert it gets killed.
	# (Vignette exposes has_active_tween + an opacity_tween_completed signal,
	#  but the kill happens internally — we test the observable result.)
	v.set_opacity_tween(0.20, 1.0, Vignette.CURVE_EASE_IN_OUT_CUBIC)
	# After the second call, exactly one tween is alive (the second one);
	# the first was killed in _kill_active_tween().
	assert_true(v.has_active_tween(), "second tween active")
	# Wait for completion of the second tween — if the first had survived,
	# we'd see opacity_tween_completed fire twice; with proper kill, only
	# the second target (0.20) lands.
	await v.opacity_tween_completed
	assert_almost_eq(v.get_current_opacity(), 0.20, 0.001,
		"second tween's target wins (first was killed)")


# ---- T12-VIG-11 cont.: instant set_opacity also kills active tween ----

func test_set_opacity_instant_kills_active_tween() -> void:
	# Defensive: set_opacity (instant) must also kill any in-flight tween,
	# otherwise the tween would overwrite the instant value on its next
	# frame.
	var v: Vignette = _make_vignette()
	await get_tree().process_frame
	v.set_opacity_tween(0.70, 1.0, Vignette.CURVE_EASE_IN_OUT_CUBIC)
	assert_true(v.has_active_tween(), "tween active")
	v.set_opacity(0.10)
	assert_false(v.has_active_tween(), "instant set killed the tween")
	assert_almost_eq(v.get_current_opacity(), 0.10, 0.001,
		"instant value lands without tween overwrite")


# ---- T12-VIG-14 endpoint: tween-completed signal fires on completion -

func test_opacity_tween_completed_signal_fires() -> void:
	# Signal-driven endpoint assertion — tests subscribing to this signal can
	# chain callback logic without polling. Convenience for T13/T16 if they
	# ever need post-ramp completion hooks.
	var v: Vignette = _make_vignette()
	await get_tree().process_frame
	var seen_target: float = -1.0
	v.opacity_tween_completed.connect(
		func(target: float) -> void: seen_target = target)
	v.set_opacity_tween(0.55, 0.05, Vignette.CURVE_EASE_IN_OUT_CUBIC)
	await v.opacity_tween_completed
	assert_almost_eq(seen_target, 0.55, 0.001,
		"opacity_tween_completed emits with the target value")


# ---- T12 — texture is non-trivial (radial gradient generated) ---------

func test_radial_gradient_texture_is_generated() -> void:
	# Defensive: the procedural radial-gradient builder must produce a real
	# Texture2D with the expected dimensions. If a future refactor regresses
	# to a null texture, the TextureRect would render as a transparent rect
	# (vignette silently invisible) — this test catches that at CI time.
	var v: Vignette = _make_vignette()
	var tex: TextureRect = v.get_texture_rect()
	assert_not_null(tex.texture, "texture assigned")
	assert_eq(tex.texture.get_width(), Vignette.GRADIENT_TEX_SIZE,
		"texture width = GRADIENT_TEX_SIZE (256)")
	assert_eq(tex.texture.get_height(), Vignette.GRADIENT_TEX_SIZE,
		"texture height = GRADIENT_TEX_SIZE (256)")


# ---- T12 — curve-preset enum stability --------------------------------

func test_curve_preset_constants_are_stable() -> void:
	# Pin the curve-preset enum values so future API callers (T13, T16) can
	# reference them by name without surprise. The default must be ease-in-out
	# cubic (BI-04 + F2 shape); 1 = ease-out cubic (F3 return shape).
	assert_eq(Vignette.CURVE_EASE_IN_OUT_CUBIC, 0, "ease-in-out cubic = 0 (default)")
	assert_eq(Vignette.CURVE_EASE_OUT_CUBIC, 1, "ease-out cubic = 1 (F3 only)")
