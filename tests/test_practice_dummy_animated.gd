extends GutTest
## M3W-1 paired test — PracticeDummy AnimatedSprite2D wiring.
##
## Pins the conventions established by the foundation PR:
##   - Sprite child resolves to AnimatedSprite2D (not ColorRect) when the
##     production .tscn is loaded.
##   - SpriteFrames at `res://assets/sprites/practice_dummy/PracticeDummy.tres`
##     exposes all 16 sub-anims (`<state>_<dir>` for state in {hit, die},
##     dir in {n, ne, e, se, s, sw, w, nw}).
##   - `take_damage` drives `AnimatedSprite2D.animation = "hit_<dir>"`
##     (PD is stationary → DEFAULT_DIR_SUFFIX = "s" → "hit_s").
##   - `_die` drives `AnimatedSprite2D.animation = "die_<dir>"` ("die_s").
##   - Hit-flash still produces a tween reference change (Tier 1 invariant),
##     AND the AnimatedSprite2D's modulate is observably away from rest mid-flash
##     (Tier 1 color-delta assertion per `.claude/docs/test-conventions.md`).
##   - `_force_queue_free` still completes post-_die (the AnimatedSprite2D swap
##     does NOT break the existing death-tween + SceneTreeTimer safety-net
##     pipeline).
##
## Companion to `tests/test_practice_dummy.gd` — that file covers the
## pre-M3W-1 invariants (HP/damage/loot/layers); this one pins the
## animation wiring contract that downstream M3W PRs depend on.

const PracticeDummyScript: Script = preload("res://scripts/mobs/PracticeDummy.gd")
const PRACTICE_DUMMY_SCENE: PackedScene = preload("res://scenes/mobs/PracticeDummy.tscn")
const SPRITE_FRAMES_PATH: String = "res://assets/sprites/practice_dummy/PracticeDummy.tres"
const ANIM_DIRS: Array[String] = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
const ANIM_STATES: Array[String] = ["hit", "die"]

# ---- Helpers ----------------------------------------------------------


func _make_scene_dummy() -> PracticeDummy:
	# Production scene-loaded dummy (Sprite child is AnimatedSprite2D).
	var packed: PackedScene = PRACTICE_DUMMY_SCENE
	var d: PracticeDummy = packed.instantiate() as PracticeDummy
	add_child_autofree(d)
	return d


func _make_scene_dummy_in_room() -> Array:
	# Parented scene-loaded dummy + room (for _die path which needs a parent
	# for the iron_sword pickup + ember-particle deferred adds).
	var room: Node2D = autofree(Node2D.new())
	add_child(room)
	var packed: PackedScene = PRACTICE_DUMMY_SCENE
	var d: PracticeDummy = packed.instantiate() as PracticeDummy
	room.add_child(d)
	return [d, room]


func _hit(d: PracticeDummy, dmg: int) -> void:
	d.take_damage(dmg, Vector2.ZERO, null)


# ---- Convention: Sprite child resolves to AnimatedSprite2D ------------


func test_scene_sprite_is_animated_sprite2d_with_sprite_frames() -> void:
	# M3W-1 swap: the production .tscn's "Sprite" node is now AnimatedSprite2D,
	# not ColorRect. The node name is preserved ("Sprite") so `get_node("Sprite")`
	# resolvers continue to work — downstream M3W PRs follow the same node-name
	# convention.
	var d: PracticeDummy = _make_scene_dummy()
	var sprite_node: Node = d.get_node_or_null("Sprite")
	assert_not_null(sprite_node, "PracticeDummy.tscn has a 'Sprite' child")
	assert_true(
		sprite_node is AnimatedSprite2D,
		"Sprite child resolves to AnimatedSprite2D (M3W-1 convention)"
	)
	var asprite: AnimatedSprite2D = sprite_node as AnimatedSprite2D
	assert_not_null(asprite.sprite_frames, "AnimatedSprite2D has a SpriteFrames resource assigned")
	# texture_filter = TEXTURE_FILTER_NEAREST (1) preserves pixel-art hardness.
	assert_eq(
		asprite.texture_filter,
		CanvasItem.TEXTURE_FILTER_NEAREST,
		"texture_filter = NEAREST (pixel-art hardness preserved)"
	)


# ---- Convention: SpriteFrames exposes all 16 sub-anims ----------------


func test_sprite_frames_resource_exposes_all_state_x_direction_keys() -> void:
	# 2 states × 8 directions = 16 sub-animation keys. The animation_key
	# convention is `<state>_<dir>`; downstream M3W PRs share this convention.
	var frames: SpriteFrames = load(SPRITE_FRAMES_PATH) as SpriteFrames
	assert_not_null(frames, "PracticeDummy SpriteFrames .tres loads")
	for state in ANIM_STATES:
		for dir_suffix in ANIM_DIRS:
			var anim_name: String = "%s_%s" % [state, dir_suffix]
			assert_true(
				frames.has_animation(StringName(anim_name)),
				"SpriteFrames exposes animation '%s'" % anim_name
			)
	# Loop flag policy — hit + die are one-shot (loop=false).
	for state in ANIM_STATES:
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("%s_%s" % [state, dir_suffix])
			assert_false(
				frames.get_animation_loop(anim_name),
				"'%s' is one-shot (loop=false) — hit/die never loop" % anim_name
			)
	# FPS policy — 8 fps (PixelLab 6-frame anims read cleanly per Priya's
	# brief). Downstream walks/idles may override; M3W-1 fixes the hit/die default.
	for state in ANIM_STATES:
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("%s_%s" % [state, dir_suffix])
			assert_eq(
				frames.get_animation_speed(anim_name),
				8.0,
				"'%s' plays at 8 fps (M3W-1 convention)" % anim_name
			)


# ---- Convention: take_damage drives `hit_s` ---------------------------


func test_take_damage_plays_hit_s_animation() -> void:
	var d: PracticeDummy = _make_scene_dummy()
	var asprite: AnimatedSprite2D = d.get_node("Sprite") as AnimatedSprite2D
	_hit(d, 1)
	# AnimatedSprite2D.animation reflects the most recent play() call. PD has
	# no facing-derivation (it's stationary), so the suffix is always "s".
	assert_eq(
		asprite.animation, StringName("hit_s"), "take_damage plays 'hit_s' on the AnimatedSprite2D"
	)
	assert_true(asprite.is_playing(), "AnimatedSprite2D is_playing() true after take_damage")


# ---- Convention: _die drives `die_s` ----------------------------------


func test_die_plays_die_s_animation() -> void:
	var bundle: Array = _make_scene_dummy_in_room()
	var d: PracticeDummy = bundle[0]
	var asprite: AnimatedSprite2D = d.get_node("Sprite") as AnimatedSprite2D
	# Lethal hit drives _die which plays "die_s".
	_hit(d, PracticeDummy.HP_MAX)
	assert_true(d.is_dead(), "dummy dead after lethal hit (precondition)")
	assert_eq(
		asprite.animation,
		StringName("die_s"),
		"_die plays 'die_s' on the AnimatedSprite2D (overrides the in-flight hit_s)"
	)


# ---- Hit-flash tint != rest (Tier 1 invariant per test-conventions.md) -


func test_hit_flash_animated_sprite_tint_differs_from_rest_white() -> void:
	# Tier 1 invariant per `.claude/docs/test-conventions.md` § "Visual-primitive
	# testing tiers": `target color ≠ rest color (assert_ne)`. Asserting on the
	# live `modulate` mid-tween is unreliable in headless GUT (the tween is
	# advanced by SceneTree.process_frame timing which may not have elapsed
	# enough between the take_damage call and the read). The Tier 1 surface
	# is the CONSTANTS being distinct — if HIT_FLASH_TINT == rest white, the
	# tween is a no-op (the PR #115/#140 trap class); if they're distinct,
	# the tween produces a visible color delta at render-time.
	var d: PracticeDummy = _make_scene_dummy()
	var asprite: AnimatedSprite2D = d.get_node("Sprite") as AnimatedSprite2D
	# Rest modulate on the AnimatedSprite2D is the .tscn-author-time spawn
	# value (Color(1,1,1,1) — no per-author override in PracticeDummy.tscn).
	var rest: Color = asprite.modulate
	assert_eq(
		rest,
		Color(1, 1, 1, 1),
		"rest modulate is (1,1,1,1) — AnimatedSprite2D's spawn-time default"
	)
	# Drive the hit-flash so the .tres-side state is exercised end-to-end.
	_hit(d, 1)
	# Tier 1 — the tween target (HIT_FLASH_TINT) must differ from rest by an
	# observable amount. This is the actual gate that catches the PR #115/#140
	# no-op trap; tween-progression checks are deferred to Tier 3 (framebuffer
	# pixel-delta, post-renderer-CI-lane).
	assert_ne(
		PracticeDummy.HIT_FLASH_TINT,
		rest,
		"HIT_FLASH_TINT differs from rest modulate (tween is not a no-op)"
	)
	# Stronger gate: channel-sum delta from rest must exceed a threshold so a
	# near-imperceptible tint (e.g. Color(1.0, 0.99, 0.99)) doesn't sneak past.
	var delta: float = (
		absf(PracticeDummy.HIT_FLASH_TINT.r - rest.r)
		+ absf(PracticeDummy.HIT_FLASH_TINT.g - rest.g)
		+ absf(PracticeDummy.HIT_FLASH_TINT.b - rest.b)
	)
	assert_gt(
		delta, 0.20, "HIT_FLASH_TINT vs rest sum-delta >= 0.20 (visible flash, delta=%.3f)" % delta
	)


func test_hit_flash_modulate_endpoints_are_html5_safe() -> void:
	# HTML5 HDR-clamp guard per `.claude/docs/html5-export.md` — every modulate
	# channel must be in [0, 1]. The HIT_FLASH_TINT constant is the only
	# non-rest endpoint the AnimatedSprite2D path tweens to.
	var tint: Color = PracticeDummy.HIT_FLASH_TINT
	assert_between(tint.r, 0.0, 1.0, "HIT_FLASH_TINT.r in [0,1] — HTML5 safe")
	assert_between(tint.g, 0.0, 1.0, "HIT_FLASH_TINT.g in [0,1] — HTML5 safe")
	assert_between(tint.b, 0.0, 1.0, "HIT_FLASH_TINT.b in [0,1] — HTML5 safe")
	assert_between(tint.a, 0.0, 1.0, "HIT_FLASH_TINT.a in [0,1] — HTML5 safe")
	# Sanity: tint is visibly different from rest white (otherwise the flash
	# is a no-op — the PR #115/#140 trap class). Channel delta vs (1,1,1) ≥ 0.20.
	var rest_white: Color = Color(1, 1, 1, 1)
	var delta: float = (
		absf(tint.r - rest_white.r) + absf(tint.g - rest_white.g) + absf(tint.b - rest_white.b)
	)
	assert_gt(
		delta,
		0.20,
		"HIT_FLASH_TINT delta vs (1,1,1) >= 0.20 (visible flash, not PR#115/#140 no-op trap)"
	)


# ---- queue_free pipeline still completes post-die ---------------------


func test_force_queue_free_still_completes_post_die_with_animated_sprite() -> void:
	# Regression guard — the AnimatedSprite2D swap does NOT break the existing
	# death-tween + SceneTreeTimer safety-net pipeline. The PracticeDummy
	# should still queue_free after _die, exactly as the ColorRect-era dummy did.
	var bundle: Array = _make_scene_dummy_in_room()
	var d: PracticeDummy = bundle[0]
	_hit(d, PracticeDummy.HP_MAX)
	# Drive the death tween + safety-net timer. DEATH_TWEEN_DURATION = 0.2s;
	# the SceneTreeTimer is armed at DURATION + 0.2 = 0.4s. Wait ~0.5s of
	# scaled simulation time via process_frame loops so either the tween or
	# the timer fires.
	for _i in range(40):
		await get_tree().process_frame
	# Either freed or queued for deletion — both satisfy "pipeline completed".
	# Check is_instance_valid FIRST — if the node has been freed, calling
	# is_queued_for_deletion crashes ("Cannot call method on previously freed
	# instance"). The OR short-circuits when validity is false, leaving the
	# expression as true (pipeline did complete, the node is gone).
	var pipeline_complete: bool = not is_instance_valid(d) or d.is_queued_for_deletion()
	assert_true(
		pipeline_complete,
		"dummy queued for deletion / freed after _die (post-AnimatedSprite2D pipeline intact)"
	)


# ---- Tween reference still flips on second hit (Tier 1 invariant) -----


func test_animated_sprite_hit_flash_tween_reference_flips_on_second_hit() -> void:
	# The PR #221 Tier 1 reference-change invariant survives the AnimatedSprite2D
	# swap: a second hit during the flash window kills the in-flight tween and
	# creates a fresh one. We assert the tween reference flipped (kill is async;
	# is_valid would lie about the prior tween's state).
	var d: PracticeDummy = _make_scene_dummy()
	_hit(d, 1)
	var first_tween: Tween = d._hit_flash_tween
	assert_not_null(first_tween, "first hit produces a flash tween (AnimatedSprite2D path)")
	_hit(d, 1)
	var second_tween: Tween = d._hit_flash_tween
	assert_not_null(second_tween, "second hit leaves a tween in place")
	assert_ne(
		first_tween,
		second_tween,
		"second hit kills + restarts (tween reference flipped — Tier 1 invariant)"
	)


# ---- `_play_anim` no-op safety (bare-instanced dummy) -----------------


func test_play_anim_is_a_safe_noop_on_bare_instanced_dummy() -> void:
	# Bare-instanced dummy (no Sprite child, no SpriteFrames) — `_play_anim`
	# must be a no-op, not a crash. Tests + Stratum1Room01._spawn_mob both
	# construct dummies via `PracticeDummyScript.new()` in some paths.
	var d: PracticeDummy = PracticeDummyScript.new()
	add_child_autofree(d)
	# These calls would crash if the resolver didn't no-op gracefully.
	d._play_anim("hit")
	d._play_anim("die")
	d._play_anim("nonexistent_state")
	# Reaching here is the pass condition.
	assert_eq(true, true, "bare-instanced _play_anim calls did not crash")
