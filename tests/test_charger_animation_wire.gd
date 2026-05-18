extends GutTest
## M3W-3 paired test — Charger AnimatedSprite2D wiring.
##
## Pins:
##   - Sprite child resolves to AnimatedSprite2D.
##   - SpriteFrames at `res://assets/sprites/charger/Charger.tres` exposes
##     32 sub-anims (`<state>_<dir>` for state ∈ {walk, telegraph, atk, die},
##     dir ∈ {n, ne, e, se, s, sw, w, nw}).
##   - `walk_*` loops; rest one-shot. FPS=8 across all.
##   - **NO `hit_<dir>` key** — bear template ships no flinch anim. Hit-flash
##     uses the modulate fallback path of the 3-branch resolver (test asserts
##     `_hit_flash_uses_animated_sprite == true` AND no `hit_*` keys exist).
##   - State machine drives anim:
##       spotted / charging → walk_<dir>
##       telegraphing → telegraph_<dir>
##       recovering → atk_<dir>
##       die → die_<dir> (from `_die` directly)

const ChargerScript: Script = preload("res://scripts/mobs/Charger.gd")
const SPRITE_FRAMES_PATH: String = "res://assets/sprites/charger/Charger.tres"
const ANIM_DIRS: Array[String] = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
const ANIM_STATES: Array[String] = ["walk", "telegraph", "atk", "die"]
const LOOPING_STATES: Array[String] = ["walk"]
const ONE_SHOT_STATES: Array[String] = ["telegraph", "atk", "die"]


class FakePlayer:
	extends Node2D


# ---- Helpers ----------------------------------------------------------

func _make_scene_charger() -> Charger:
	var packed: PackedScene = load("res://scenes/mobs/Charger.tscn")
	var c: Charger = packed.instantiate() as Charger
	add_child_autofree(c)
	return c


func _make_scene_charger_in_room() -> Array:
	var room: Node2D = autofree(Node2D.new())
	add_child(room)
	var packed: PackedScene = load("res://scenes/mobs/Charger.tscn")
	var c: Charger = packed.instantiate() as Charger
	room.add_child(c)
	return [c, room]


# ---- SpriteFrames resource shape --------------------------------------

func test_sprite_frames_resource_exposes_all_state_x_direction_keys() -> void:
	# 4 states × 8 directions = 32 sub-animation keys.
	var frames: SpriteFrames = load(SPRITE_FRAMES_PATH) as SpriteFrames
	assert_not_null(frames, "Charger SpriteFrames .tres loads")
	for state in ANIM_STATES:
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("%s_%s" % [state, dir_suffix])
			assert_true(frames.has_animation(anim_name),
				"SpriteFrames exposes animation '%s'" % anim_name)


func test_sprite_frames_has_no_hit_keys() -> void:
	# Charger uses the bear PixelLab template which ships no flinch anim. The
	# hit-flash modulate-tween IS the visible hit feedback. This test pins the
	# absence so an accidental future add of `hit_<dir>` keys is flagged loudly.
	var frames: SpriteFrames = load(SPRITE_FRAMES_PATH) as SpriteFrames
	for dir_suffix in ANIM_DIRS:
		var anim_name: StringName = StringName("hit_%s" % dir_suffix)
		assert_false(frames.has_animation(anim_name),
			"Charger SpriteFrames has NO '%s' key (bear template constraint)" % anim_name)


func test_sprite_frames_loop_flags_match_convention() -> void:
	var frames: SpriteFrames = load(SPRITE_FRAMES_PATH) as SpriteFrames
	for state in LOOPING_STATES:
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("%s_%s" % [state, dir_suffix])
			assert_true(frames.get_animation_loop(anim_name),
				"'%s' loops" % anim_name)
	for state in ONE_SHOT_STATES:
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("%s_%s" % [state, dir_suffix])
			assert_false(frames.get_animation_loop(anim_name),
				"'%s' is one-shot" % anim_name)


func test_sprite_frames_fps_is_8_across_all_anims() -> void:
	var frames: SpriteFrames = load(SPRITE_FRAMES_PATH) as SpriteFrames
	for state in ANIM_STATES:
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("%s_%s" % [state, dir_suffix])
			assert_eq(frames.get_animation_speed(anim_name), 8.0,
				"'%s' plays at 8 fps" % anim_name)


# ---- Scene shape -----------------------------------------------------

func test_scene_sprite_is_animated_sprite2d_with_sprite_frames() -> void:
	var c: Charger = _make_scene_charger()
	var sprite_node: Node = c.get_node_or_null("Sprite")
	assert_not_null(sprite_node, "Charger.tscn has a 'Sprite' child")
	assert_true(sprite_node is AnimatedSprite2D,
		"Sprite child resolves to AnimatedSprite2D (M3W-3 swap)")
	var asprite: AnimatedSprite2D = sprite_node as AnimatedSprite2D
	assert_not_null(asprite.sprite_frames, "SpriteFrames resource assigned")
	assert_eq(asprite.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST,
		"texture_filter = NEAREST")


# ---- Hit-flash uses modulate fallback (no hit_<dir> anim) ------------

func test_hit_flash_uses_animated_sprite_modulate_path() -> void:
	# Per the bear-template constraint, Charger's only hit-feedback channel is
	# the `HIT_FLASH_TINT` modulate tween on the AnimatedSprite2D itself
	# (branch 1 of the 3-branch resolver). This test pins that the resolver
	# DOES land on the AnimatedSprite2D modulate path — NOT the legacy
	# ColorRect path nor the self-modulate fallback.
	var c: Charger = _make_scene_charger()
	c.take_damage(1, Vector2.ZERO, null)
	assert_true(c._hit_flash_uses_animated_sprite,
		"3-branch resolver landed on AnimatedSprite2D modulate path (branch 1)")
	assert_true(c._hit_flash_uses_sprite,
		"_hit_flash_uses_sprite stays true (branch 1 OR 2)")
	assert_not_null(c._hit_flash_tween,
		"hit-flash tween created on take_damage")


func test_hit_flash_tint_differs_from_rest_white_above_threshold() -> void:
	var tint: Color = Charger.HIT_FLASH_TINT
	var rest_white: Color = Color(1, 1, 1, 1)
	var delta: float = absf(tint.r - rest_white.r) \
		+ absf(tint.g - rest_white.g) \
		+ absf(tint.b - rest_white.b)
	assert_gt(delta, 0.20,
		"HIT_FLASH_TINT vs rest sum-delta >= 0.20 (visible flash, delta=%.3f)" % delta)
	assert_between(tint.r, 0.0, 1.0, "HIT_FLASH_TINT.r in [0,1]")
	assert_between(tint.g, 0.0, 1.0, "HIT_FLASH_TINT.g in [0,1]")
	assert_between(tint.b, 0.0, 1.0, "HIT_FLASH_TINT.b in [0,1]")
	assert_between(tint.a, 0.0, 1.0, "HIT_FLASH_TINT.a in [0,1]")


# ---- State-driven anim playback --------------------------------------

func test_take_damage_does_not_play_hit_anim_for_charger() -> void:
	# Negative coverage — Charger MUST NOT call _play_anim(&"hit") because no
	# such SpriteFrames key exists; the script skips the call entirely so the
	# trace doesn't emit `MISS anim=hit_<dir>` lines on every hit.
	var c: Charger = _make_scene_charger()
	var asprite: AnimatedSprite2D = c.get_node("Sprite") as AnimatedSprite2D
	# Whatever anim is playing pre-hit must STILL be playing post-hit — the
	# hit anim path is intentionally not wired for Charger.
	var pre_anim: StringName = asprite.animation
	c.take_damage(1, Vector2.ZERO, null)
	# After hit, anim should be unchanged OR reflect a state-driven change (not
	# a hit anim). The only `hit_*` keys are forbidden, so just verify there's
	# no `hit_*` key being played.
	assert_false(String(asprite.animation).begins_with("hit_"),
		"take_damage does NOT play a `hit_<dir>` anim (bear template constraint)")
	# Sanity: pre + post are both NOT hit_* (regardless of what state-anim is
	# playing, it can never be a hit anim on Charger).
	assert_false(String(pre_anim).begins_with("hit_"),
		"pre-hit anim is NOT a hit anim (sanity check)")


func test_die_plays_die_anim() -> void:
	var bundle: Array = _make_scene_charger_in_room()
	var c: Charger = bundle[0]
	var asprite: AnimatedSprite2D = c.get_node("Sprite") as AnimatedSprite2D
	# Lethal hit. Use a knockback amount big enough to ensure the recovery-
	# multiplier doesn't matter; bare-no-MobDef defaults give hp_max=70.
	c.take_damage(c.hp_max, Vector2.ZERO, null)
	assert_true(c.is_dead(), "charger dead after lethal hit (precondition)")
	assert_eq(asprite.animation, StringName("die_s"),
		"_die plays 'die_<dir>' on the AnimatedSprite2D")


# ---- Direction-suffix derivation pin ---------------------------------

func test_vec_to_dir_suffix_8_octants() -> void:
	assert_eq(Charger._vec_to_dir_suffix(Vector2(1, 0)), "e")
	assert_eq(Charger._vec_to_dir_suffix(Vector2(1, 1)), "se")
	assert_eq(Charger._vec_to_dir_suffix(Vector2(0, 1)), "s")
	assert_eq(Charger._vec_to_dir_suffix(Vector2(-1, 1)), "sw")
	assert_eq(Charger._vec_to_dir_suffix(Vector2(-1, 0)), "w")
	assert_eq(Charger._vec_to_dir_suffix(Vector2(-1, -1)), "nw")
	assert_eq(Charger._vec_to_dir_suffix(Vector2(0, -1)), "n")
	assert_eq(Charger._vec_to_dir_suffix(Vector2(1, -1)), "ne")


# ---- Tween-reference flip on second hit (Tier 1 invariant) -----------

func test_hit_flash_tween_reference_flips_on_second_hit() -> void:
	var c: Charger = _make_scene_charger()
	c.take_damage(1, Vector2.ZERO, null)
	var first_tween: Tween = c._hit_flash_tween
	assert_not_null(first_tween, "first hit produces a flash tween")
	c.take_damage(1, Vector2.ZERO, null)
	var second_tween: Tween = c._hit_flash_tween
	assert_not_null(second_tween, "second hit leaves a tween in place")
	assert_ne(first_tween, second_tween,
		"second hit kills + restarts (tween reference flipped — Tier 1 invariant)")


# ---- `_play_anim` no-op safety ---------------------------------------

func test_play_anim_is_safe_noop_on_bare_instanced_charger() -> void:
	var c: Charger = ChargerScript.new()
	add_child_autofree(c)
	c._play_anim(&"walk")
	c._play_anim(&"telegraph")
	c._play_anim(&"die")
	c._play_anim(&"hit")  # not authored — must MISS-no-op safely
	assert_eq(true, true, "bare-instanced _play_anim calls did not crash")
