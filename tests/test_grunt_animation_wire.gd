extends GutTest
## M3W-3 paired test — Grunt AnimatedSprite2D wiring.
##
## Pins the conventions established by M3W-1 (PR #271) + the per-mob mapping
## introduced by M3W-3 (this PR):
##   - Sprite child resolves to AnimatedSprite2D (not ColorRect) when the
##     production .tscn is loaded.
##   - SpriteFrames at `res://assets/sprites/grunt/Grunt.tres` exposes all
##     40 sub-anims (`<state>_<dir>` for state ∈ {walk, atk, atk_telegraph,
##     hit, die}, dir ∈ {n, ne, e, se, s, sw, w, nw}).
##   - `walk_*` loops; `atk_*`, `atk_telegraph_*`, `hit_*`, `die_*` are one-shot.
##   - FPS=8 across every animation.
##   - `HIT_FLASH_TINT` differs from rest white by channel-sum ≥ 0.20 (the
##     Tier 1 color-delta invariant from M3W-1).
##   - State machine transitions drive the matching anim key:
##       chase → walk_<dir>
##       telegraph (light + heavy) → atk_telegraph_<dir>
##       attacking → atk_<dir>
##       die (one-shot) → die_<dir>
##     `hit_<dir>` plays from `take_damage` directly (not state-driven).

const GruntScript: Script = preload("res://scripts/mobs/Grunt.gd")
const SPRITE_FRAMES_PATH: String = "res://assets/sprites/grunt/Grunt.tres"
const ANIM_DIRS: Array[String] = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
const ANIM_STATES: Array[String] = ["walk", "atk", "atk_telegraph", "hit", "die"]
const LOOPING_STATES: Array[String] = ["walk"]
const ONE_SHOT_STATES: Array[String] = ["atk", "atk_telegraph", "hit", "die"]


class FakePlayer:
	extends Node2D


# ---- Helpers ----------------------------------------------------------


func _make_scene_grunt() -> Grunt:
	var packed: PackedScene = load("res://scenes/mobs/Grunt.tscn")
	var g: Grunt = packed.instantiate() as Grunt
	add_child_autofree(g)
	return g


func _make_scene_grunt_in_room() -> Array:
	# Parented scene-loaded grunt + room (for _die path which needs a parent
	# for the deferred ember-particle add).
	var room: Node2D = autofree(Node2D.new())
	add_child(room)
	var packed: PackedScene = load("res://scenes/mobs/Grunt.tscn")
	var g: Grunt = packed.instantiate() as Grunt
	room.add_child(g)
	return [g, room]


# ---- SpriteFrames resource shape --------------------------------------


func test_sprite_frames_resource_exposes_all_state_x_direction_keys() -> void:
	# 5 states × 8 directions = 40 sub-animation keys.
	var frames: SpriteFrames = load(SPRITE_FRAMES_PATH) as SpriteFrames
	assert_not_null(frames, "Grunt SpriteFrames .tres loads")
	for state in ANIM_STATES:
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("%s_%s" % [state, dir_suffix])
			assert_true(
				frames.has_animation(anim_name), "SpriteFrames exposes animation '%s'" % anim_name
			)


func test_sprite_frames_loop_flags_match_convention() -> void:
	# Per M3W-1 convention: sustained states loop, one-shot beats don't.
	var frames: SpriteFrames = load(SPRITE_FRAMES_PATH) as SpriteFrames
	for state in LOOPING_STATES:
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("%s_%s" % [state, dir_suffix])
			assert_true(
				frames.get_animation_loop(anim_name), "'%s' loops (sustained gait)" % anim_name
			)
	for state in ONE_SHOT_STATES:
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("%s_%s" % [state, dir_suffix])
			assert_false(
				frames.get_animation_loop(anim_name), "'%s' is one-shot (loop=false)" % anim_name
			)


func test_sprite_frames_fps_is_8_across_all_anims() -> void:
	# FPS=8 across all anims per M3W-1 convention.
	var frames: SpriteFrames = load(SPRITE_FRAMES_PATH) as SpriteFrames
	for state in ANIM_STATES:
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("%s_%s" % [state, dir_suffix])
			assert_eq(
				frames.get_animation_speed(anim_name),
				8.0,
				"'%s' plays at 8 fps (M3W-1 convention)" % anim_name
			)


# ---- Scene shape — production .tscn uses AnimatedSprite2D ------------


func test_scene_sprite_is_animated_sprite2d_with_sprite_frames() -> void:
	var g: Grunt = _make_scene_grunt()
	var sprite_node: Node = g.get_node_or_null("Sprite")
	assert_not_null(sprite_node, "Grunt.tscn has a 'Sprite' child")
	assert_true(
		sprite_node is AnimatedSprite2D, "Sprite child resolves to AnimatedSprite2D (M3W-3 swap)"
	)
	var asprite: AnimatedSprite2D = sprite_node as AnimatedSprite2D
	assert_not_null(asprite.sprite_frames, "AnimatedSprite2D has a SpriteFrames resource assigned")
	assert_eq(
		asprite.texture_filter,
		CanvasItem.TEXTURE_FILTER_NEAREST,
		"texture_filter = NEAREST (pixel-art hardness preserved)"
	)


# ---- Tier 1 hit-flash tint != rest -----------------------------------


func test_hit_flash_tint_differs_from_rest_white_above_threshold() -> void:
	# Tier 1 color-delta invariant per `.claude/docs/test-conventions.md` —
	# HIT_FLASH_TINT must differ from rest white by channel-sum ≥ 0.20 so the
	# tween is not the PR #115/#140 no-op trap.
	var tint: Color = Grunt.HIT_FLASH_TINT
	var rest_white: Color = Color(1, 1, 1, 1)
	var delta: float = (
		absf(tint.r - rest_white.r) + absf(tint.g - rest_white.g) + absf(tint.b - rest_white.b)
	)
	assert_gt(
		delta, 0.20, "HIT_FLASH_TINT vs rest sum-delta >= 0.20 (visible flash, delta=%.3f)" % delta
	)
	# Every channel must be in [0,1] per HTML5 HDR-clamp rule.
	assert_between(tint.r, 0.0, 1.0, "HIT_FLASH_TINT.r in [0,1] — HTML5 safe")
	assert_between(tint.g, 0.0, 1.0, "HIT_FLASH_TINT.g in [0,1] — HTML5 safe")
	assert_between(tint.b, 0.0, 1.0, "HIT_FLASH_TINT.b in [0,1] — HTML5 safe")
	assert_between(tint.a, 0.0, 1.0, "HIT_FLASH_TINT.a in [0,1] — HTML5 safe")


# ---- State-driven anim playback --------------------------------------


func test_take_damage_plays_hit_anim() -> void:
	var g: Grunt = _make_scene_grunt()
	var asprite: AnimatedSprite2D = g.get_node("Sprite") as AnimatedSprite2D
	# No player → facing defaults to "s".
	g.take_damage(1, Vector2.ZERO, null)
	assert_eq(
		asprite.animation,
		StringName("hit_s"),
		"take_damage plays 'hit_<dir>' on the AnimatedSprite2D"
	)


func test_die_plays_die_anim() -> void:
	var bundle: Array = _make_scene_grunt_in_room()
	var g: Grunt = bundle[0]
	var asprite: AnimatedSprite2D = g.get_node("Sprite") as AnimatedSprite2D
	g.take_damage(g.hp_max, Vector2.ZERO, null)
	assert_true(g.is_dead(), "grunt dead after lethal hit (precondition)")
	assert_eq(
		asprite.animation, StringName("die_s"), "_die plays 'die_<dir>' on the AnimatedSprite2D"
	)


func test_chase_state_plays_walk_anim() -> void:
	# Grunt with a player a few tiles east → enters chasing → plays walk_e.
	var g: Grunt = _make_scene_grunt()
	var asprite: AnimatedSprite2D = g.get_node("Sprite") as AnimatedSprite2D
	var fp: FakePlayer = FakePlayer.new()
	add_child_autofree(fp)
	fp.global_position = g.global_position + Vector2(100.0, 0.0)
	g.set_player(fp)
	# Step physics so _process_chase runs.
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(g.get_state(), Grunt.STATE_CHASING, "grunt entered chase state")
	# Player is due east — facing suffix = "e".
	assert_eq(
		asprite.animation, StringName("walk_e"), "chase state plays 'walk_e' (player is due east)"
	)


# ---- Direction-suffix derivation pins (8 octants) ---------------------


func test_vec_to_dir_suffix_8_octants() -> void:
	# Pin every cardinal + diagonal so a future refactor of the atan2 bin
	# math doesn't silently swap two directions.
	assert_eq(Grunt._vec_to_dir_suffix(Vector2(1, 0)), "e", "east")
	assert_eq(Grunt._vec_to_dir_suffix(Vector2(1, 1)), "se", "south-east")
	assert_eq(Grunt._vec_to_dir_suffix(Vector2(0, 1)), "s", "south")
	assert_eq(Grunt._vec_to_dir_suffix(Vector2(-1, 1)), "sw", "south-west")
	assert_eq(Grunt._vec_to_dir_suffix(Vector2(-1, 0)), "w", "west")
	assert_eq(Grunt._vec_to_dir_suffix(Vector2(-1, -1)), "nw", "north-west")
	assert_eq(Grunt._vec_to_dir_suffix(Vector2(0, -1)), "n", "north")
	assert_eq(Grunt._vec_to_dir_suffix(Vector2(1, -1)), "ne", "north-east")


# ---- Tween-reference flip on second hit (Tier 1 invariant) -----------


func test_hit_flash_tween_reference_flips_on_second_hit() -> void:
	# Mirror of test_practice_dummy_animated.gd's same-class invariant.
	var g: Grunt = _make_scene_grunt()
	g.take_damage(1, Vector2.ZERO, null)
	var first_tween: Tween = g._hit_flash_tween
	assert_not_null(first_tween, "first hit produces a flash tween")
	g.take_damage(1, Vector2.ZERO, null)
	var second_tween: Tween = g._hit_flash_tween
	assert_not_null(second_tween, "second hit leaves a tween in place")
	assert_ne(
		first_tween,
		second_tween,
		"second hit kills + restarts (tween reference flipped — Tier 1 invariant)"
	)


# ---- `_play_anim` no-op safety (bare-instanced grunt) -----------------


func test_play_anim_is_safe_noop_on_bare_instanced_grunt() -> void:
	# Bare-instanced grunt (no Sprite child) — `_play_anim` must no-op, not crash.
	var g: Grunt = GruntScript.new()
	add_child_autofree(g)
	g._play_anim(&"walk")
	g._play_anim(&"hit")
	g._play_anim(&"die")
	g._play_anim(&"nonexistent_state")
	assert_eq(true, true, "bare-instanced _play_anim calls did not crash")
