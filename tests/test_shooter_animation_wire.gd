extends GutTest
## M3W-3 paired test — Shooter AnimatedSprite2D wiring.
##
## Pins:
##   - Sprite child resolves to AnimatedSprite2D.
##   - SpriteFrames at `res://assets/sprites/shooter/Shooter.tres` exposes 40
##     sub-anims (`<state>_<dir>` for state ∈ {walk, telegraph, atk, hit, die},
##     dir ∈ {n, ne, e, se, s, sw, w, nw}).
##   - `walk_*` loops; rest one-shot. FPS=8 across all.
##   - State machine drives anim per `Shooter.gd`'s 3-band design:
##       spotted / kiting → walk_<dir>
##       aiming → telegraph_<dir>
##       firing / post_fire_recovery → atk_<dir>
##       take_damage → hit_<dir>
##       die → die_<dir> (from `_die` directly)

const ShooterScript: Script = preload("res://scripts/mobs/Shooter.gd")
const SPRITE_FRAMES_PATH: String = "res://assets/sprites/shooter/Shooter.tres"
const ANIM_DIRS: Array[String] = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
const ANIM_STATES: Array[String] = ["walk", "telegraph", "atk", "hit", "die"]
const LOOPING_STATES: Array[String] = ["walk"]
const ONE_SHOT_STATES: Array[String] = ["telegraph", "atk", "hit", "die"]


class FakePlayer:
	extends Node2D


# ---- Helpers ----------------------------------------------------------


func _make_scene_shooter() -> Shooter:
	var packed: PackedScene = load("res://scenes/mobs/Shooter.tscn")
	var s: Shooter = packed.instantiate() as Shooter
	add_child_autofree(s)
	return s


func _make_scene_shooter_in_room() -> Array:
	var room: Node2D = autofree(Node2D.new())
	add_child(room)
	var packed: PackedScene = load("res://scenes/mobs/Shooter.tscn")
	var s: Shooter = packed.instantiate() as Shooter
	room.add_child(s)
	return [s, room]


# ---- SpriteFrames resource shape --------------------------------------


func test_sprite_frames_resource_exposes_all_state_x_direction_keys() -> void:
	# 5 states × 8 directions = 40 sub-animation keys.
	var frames: SpriteFrames = load(SPRITE_FRAMES_PATH) as SpriteFrames
	assert_not_null(frames, "Shooter SpriteFrames .tres loads")
	for state in ANIM_STATES:
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("%s_%s" % [state, dir_suffix])
			assert_true(
				frames.has_animation(anim_name), "SpriteFrames exposes animation '%s'" % anim_name
			)


func test_sprite_frames_loop_flags_match_convention() -> void:
	var frames: SpriteFrames = load(SPRITE_FRAMES_PATH) as SpriteFrames
	for state in LOOPING_STATES:
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("%s_%s" % [state, dir_suffix])
			assert_true(frames.get_animation_loop(anim_name), "'%s' loops" % anim_name)
	for state in ONE_SHOT_STATES:
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("%s_%s" % [state, dir_suffix])
			assert_false(frames.get_animation_loop(anim_name), "'%s' is one-shot" % anim_name)


func test_sprite_frames_fps_is_8_across_all_anims() -> void:
	var frames: SpriteFrames = load(SPRITE_FRAMES_PATH) as SpriteFrames
	for state in ANIM_STATES:
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("%s_%s" % [state, dir_suffix])
			assert_eq(frames.get_animation_speed(anim_name), 8.0, "'%s' plays at 8 fps" % anim_name)


# ---- Scene shape -----------------------------------------------------


func test_scene_sprite_is_animated_sprite2d_with_sprite_frames() -> void:
	var s: Shooter = _make_scene_shooter()
	var sprite_node: Node = s.get_node_or_null("Sprite")
	assert_not_null(sprite_node, "Shooter.tscn has a 'Sprite' child")
	assert_true(
		sprite_node is AnimatedSprite2D, "Sprite child resolves to AnimatedSprite2D (M3W-3 swap)"
	)
	var asprite: AnimatedSprite2D = sprite_node as AnimatedSprite2D
	assert_not_null(asprite.sprite_frames, "SpriteFrames resource assigned")
	assert_eq(asprite.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "texture_filter = NEAREST")


# ---- Tier 1 hit-flash tint -------------------------------------------


func test_hit_flash_tint_differs_from_rest_white_above_threshold() -> void:
	var tint: Color = Shooter.HIT_FLASH_TINT
	var rest_white: Color = Color(1, 1, 1, 1)
	var delta: float = (
		absf(tint.r - rest_white.r) + absf(tint.g - rest_white.g) + absf(tint.b - rest_white.b)
	)
	assert_gt(
		delta, 0.20, "HIT_FLASH_TINT vs rest sum-delta >= 0.20 (visible flash, delta=%.3f)" % delta
	)
	assert_between(tint.r, 0.0, 1.0, "HIT_FLASH_TINT.r in [0,1]")
	assert_between(tint.g, 0.0, 1.0, "HIT_FLASH_TINT.g in [0,1]")
	assert_between(tint.b, 0.0, 1.0, "HIT_FLASH_TINT.b in [0,1]")
	assert_between(tint.a, 0.0, 1.0, "HIT_FLASH_TINT.a in [0,1]")


# ---- State-driven anim playback --------------------------------------


func test_take_damage_plays_hit_anim() -> void:
	var s: Shooter = _make_scene_shooter()
	var asprite: AnimatedSprite2D = s.get_node("Sprite") as AnimatedSprite2D
	s.take_damage(1, Vector2.ZERO, null)
	assert_eq(
		asprite.animation,
		StringName("hit_s"),
		"take_damage plays 'hit_<dir>' on the AnimatedSprite2D"
	)


func test_die_plays_die_anim() -> void:
	var bundle: Array = _make_scene_shooter_in_room()
	var s: Shooter = bundle[0]
	var asprite: AnimatedSprite2D = s.get_node("Sprite") as AnimatedSprite2D
	s.take_damage(s.hp_max, Vector2.ZERO, null)
	assert_true(s.is_dead(), "shooter dead after lethal hit (precondition)")
	assert_eq(
		asprite.animation, StringName("die_s"), "_die plays 'die_<dir>' on the AnimatedSprite2D"
	)


# ---- Direction-suffix derivation pin ---------------------------------


func test_vec_to_dir_suffix_8_octants() -> void:
	assert_eq(Shooter._vec_to_dir_suffix(Vector2(1, 0)), "e")
	assert_eq(Shooter._vec_to_dir_suffix(Vector2(1, 1)), "se")
	assert_eq(Shooter._vec_to_dir_suffix(Vector2(0, 1)), "s")
	assert_eq(Shooter._vec_to_dir_suffix(Vector2(-1, 1)), "sw")
	assert_eq(Shooter._vec_to_dir_suffix(Vector2(-1, 0)), "w")
	assert_eq(Shooter._vec_to_dir_suffix(Vector2(-1, -1)), "nw")
	assert_eq(Shooter._vec_to_dir_suffix(Vector2(0, -1)), "n")
	assert_eq(Shooter._vec_to_dir_suffix(Vector2(1, -1)), "ne")


# ---- Tween-reference flip on second hit (Tier 1 invariant) -----------


func test_hit_flash_tween_reference_flips_on_second_hit() -> void:
	var s: Shooter = _make_scene_shooter()
	s.take_damage(1, Vector2.ZERO, null)
	var first_tween: Tween = s._hit_flash_tween
	assert_not_null(first_tween, "first hit produces a flash tween")
	s.take_damage(1, Vector2.ZERO, null)
	var second_tween: Tween = s._hit_flash_tween
	assert_not_null(second_tween, "second hit leaves a tween in place")
	assert_ne(
		first_tween,
		second_tween,
		"second hit kills + restarts (tween reference flipped — Tier 1 invariant)"
	)


# ---- `_play_anim` no-op safety ---------------------------------------


func test_play_anim_is_safe_noop_on_bare_instanced_shooter() -> void:
	var s: Shooter = ShooterScript.new()
	add_child_autofree(s)
	s._play_anim(&"walk")
	s._play_anim(&"telegraph")
	s._play_anim(&"atk")
	s._play_anim(&"hit")
	s._play_anim(&"die")
	s._play_anim(&"nonexistent_state")
	assert_eq(true, true, "bare-instanced _play_anim calls did not crash")
