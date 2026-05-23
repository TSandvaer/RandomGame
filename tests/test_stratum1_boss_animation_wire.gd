extends GutTest
## M3W-4 paired test — Stratum1Boss AnimatedSprite2D wiring.
##
## Pins the conventions established by M3W-1 (PR #271 PracticeDummy) + M3W-3
## (#275 mob-trio) + the per-boss mapping introduced by M3W-4 (this PR):
##   - Sprite child resolves to AnimatedSprite2D (not ColorRect) when the
##     production .tscn is loaded.
##   - SpriteFrames at `res://assets/sprites/boss/Stratum1Boss.tres` exposes
##     all 56 sub-anims (`<state>_<dir>` for state ∈ {walk, atk, atk_telegraph,
##     slam, slam_telegraph, hit, die}, dir ∈ {n, ne, e, se, s, sw, w, nw}).
##   - `walk_*` loops; `atk_*`, `atk_telegraph_*`, `slam_*`, `slam_telegraph_*`,
##     `hit_*`, `die_*` are one-shot.
##   - FPS=8 across every animation.
##   - `HIT_FLASH_TINT` differs from rest white by channel-sum ≥ 0.20 (the
##     Tier 1 color-delta invariant from M3W-1).
##   - State machine transitions drive the matching anim key:
##       chase → walk_<dir>
##       telegraphing_melee → atk_telegraph_<dir>
##       attacking → atk_<dir>
##       telegraphing_slam → slam_telegraph_<dir>
##       slam_recovery → slam_<dir>
##       die (one-shot) → die_<dir>
##     `hit_<dir>` plays from `take_damage` directly (not state-driven).

const BossScript: Script = preload("res://scripts/mobs/Stratum1Boss.gd")
const BOSS_SCENE: PackedScene = preload("res://scenes/mobs/Stratum1Boss.tscn")
const SPRITE_FRAMES_PATH: String = "res://assets/sprites/boss/Stratum1Boss.tres"
const ANIM_DIRS: Array[String] = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
const ANIM_STATES: Array[String] = [
	"walk", "atk", "atk_telegraph", "slam", "slam_telegraph", "hit", "die", "wake"
]
const LOOPING_STATES: Array[String] = ["walk"]
const ONE_SHOT_STATES: Array[String] = [
	"atk", "atk_telegraph", "slam", "slam_telegraph", "hit", "die", "wake"
]
# Per-state FPS map — M3W-4 ran every anim at 8 fps; M3-T2-W1-T8 wake (Uma BI-06
# ~500ms target band) ships at 12 fps (5 frames -> ~417 ms).
const STATE_FPS: Dictionary = {
	"walk": 8.0,
	"atk": 8.0,
	"atk_telegraph": 8.0,
	"slam": 8.0,
	"slam_telegraph": 8.0,
	"hit": 8.0,
	"die": 8.0,
	"wake": 12.0,
}


class FakePlayer:
	extends Node2D


# ---- Helpers ----------------------------------------------------------


func _make_scene_boss() -> Stratum1Boss:
	var packed: PackedScene = BOSS_SCENE
	var b: Stratum1Boss = packed.instantiate() as Stratum1Boss
	b.skip_intro_for_tests = true  # start in IDLE not DORMANT
	add_child_autofree(b)
	return b


func _make_scene_boss_in_room() -> Array:
	# Parented scene-loaded boss + room (for _die path which needs a parent
	# for the deferred ember-particle add).
	var room: Node2D = autofree(Node2D.new())
	add_child(room)
	var packed: PackedScene = BOSS_SCENE
	var b: Stratum1Boss = packed.instantiate() as Stratum1Boss
	b.skip_intro_for_tests = true
	room.add_child(b)
	return [b, room]


# ---- SpriteFrames resource shape --------------------------------------


func test_sprite_frames_resource_exposes_all_state_x_direction_keys() -> void:
	# 8 states × 8 directions = 64 sub-animation keys (wake added in M3-T2-W1-T8).
	var frames: SpriteFrames = load(SPRITE_FRAMES_PATH) as SpriteFrames
	assert_not_null(frames, "Stratum1Boss SpriteFrames .tres loads")
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


func test_sprite_frames_fps_matches_state_fps_map() -> void:
	# M3W-1 baseline shipped FPS=8 across all anims. M3-T2-W1-T8 wake-anim
	# (Uma BI-06 ~500 ms target band) ships at 12 fps to land 5 frames in
	# ~417 ms. Per-state FPS map pins both.
	var frames: SpriteFrames = load(SPRITE_FRAMES_PATH) as SpriteFrames
	for state in ANIM_STATES:
		var expected_fps: float = STATE_FPS[state]
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("%s_%s" % [state, dir_suffix])
			assert_eq(
				frames.get_animation_speed(anim_name),
				expected_fps,
				"'%s' plays at %.1f fps" % [anim_name, expected_fps]
			)


# ---- Scene shape — production .tscn uses AnimatedSprite2D ------------


func test_scene_sprite_is_animated_sprite2d_with_sprite_frames() -> void:
	var b: Stratum1Boss = _make_scene_boss()
	var sprite_node: Node = b.get_node_or_null("Sprite")
	assert_not_null(sprite_node, "Stratum1Boss.tscn has a 'Sprite' child")
	assert_true(
		sprite_node is AnimatedSprite2D, "Sprite child resolves to AnimatedSprite2D (M3W-4 swap)"
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
	var tint: Color = Stratum1Boss.HIT_FLASH_TINT
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


func test_hit_flash_tint_matches_grunt_practice_dummy_inheritance() -> void:
	# Per `.claude/docs/combat-architecture.md` §"M3W-1 realized implementation"
	# inheritance contract: HIT_FLASH_TINT is identical across the M3 mob roster
	# so the visual grammar reads "I hit something" uniformly. Pin this.
	assert_eq(
		Stratum1Boss.HIT_FLASH_TINT,
		Grunt.HIT_FLASH_TINT,
		"Stratum1Boss.HIT_FLASH_TINT == Grunt.HIT_FLASH_TINT (M3W-1 contract)"
	)
	assert_eq(
		Stratum1Boss.HIT_FLASH_TINT,
		PracticeDummy.HIT_FLASH_TINT,
		"Stratum1Boss.HIT_FLASH_TINT == PracticeDummy.HIT_FLASH_TINT (M3W-1 contract)"
	)


# ---- State-driven anim playback --------------------------------------


func test_take_damage_plays_hit_anim() -> void:
	var b: Stratum1Boss = _make_scene_boss()
	var asprite: AnimatedSprite2D = b.get_node("Sprite") as AnimatedSprite2D
	# No player → facing defaults to "s".
	b.take_damage(1, Vector2.ZERO, null)
	assert_eq(
		asprite.animation,
		StringName("hit_s"),
		"take_damage plays 'hit_<dir>' on the AnimatedSprite2D"
	)


func test_die_plays_die_anim() -> void:
	var bundle: Array = _make_scene_boss_in_room()
	var b: Stratum1Boss = bundle[0]
	var asprite: AnimatedSprite2D = b.get_node("Sprite") as AnimatedSprite2D
	# Deal lethal damage in one shot — boss max HP is 600 default.
	b.take_damage(b.hp_max, Vector2.ZERO, null)
	assert_true(b.is_dead(), "boss dead after lethal hit (precondition)")
	assert_eq(
		asprite.animation, StringName("die_s"), "_die plays 'die_<dir>' on the AnimatedSprite2D"
	)


func test_chase_state_plays_walk_anim() -> void:
	# Boss with a player due east → enters chasing → plays walk_e.
	var b: Stratum1Boss = _make_scene_boss()
	var asprite: AnimatedSprite2D = b.get_node("Sprite") as AnimatedSprite2D
	var fp: FakePlayer = FakePlayer.new()
	add_child_autofree(fp)
	# Distance > MELEE_RANGE (36) and > SLAM_HITBOX_RADIUS (80) so chase
	# state holds — boss doesn't immediately telegraph melee.
	fp.global_position = b.global_position + Vector2(200.0, 0.0)
	b.set_player(fp)
	# Step physics so _process_chase runs.
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(b.get_state(), Stratum1Boss.STATE_CHASING, "boss entered chase state")
	# Player is due east → facing suffix = "e".
	assert_eq(
		asprite.animation, StringName("walk_e"), "chase state plays 'walk_e' (player is due east)"
	)


func test_telegraphing_melee_plays_atk_telegraph_anim() -> void:
	# Boss with a player at melee range → enters telegraphing_melee → plays
	# atk_telegraph_<dir>.
	var b: Stratum1Boss = _make_scene_boss()
	var asprite: AnimatedSprite2D = b.get_node("Sprite") as AnimatedSprite2D
	var fp: FakePlayer = FakePlayer.new()
	add_child_autofree(fp)
	# Player inside MELEE_RANGE (36 px) → boss begins melee telegraph.
	fp.global_position = b.global_position + Vector2(20.0, 0.0)
	b.set_player(fp)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(
		b.get_state(), Stratum1Boss.STATE_TELEGRAPHING_MELEE, "boss entered melee-telegraph state"
	)
	assert_eq(
		asprite.animation,
		StringName("atk_telegraph_e"),
		"telegraph state plays 'atk_telegraph_e' (player due east)"
	)


func test_attacking_state_plays_atk_anim() -> void:
	# Drive boss into the attacking state via a synthetic _set_state call.
	# The state-driven _set_state match arm should fire _play_anim(&"atk").
	var b: Stratum1Boss = _make_scene_boss()
	var asprite: AnimatedSprite2D = b.get_node("Sprite") as AnimatedSprite2D
	# Direct state poke so we don't have to run a full melee fire cycle.
	b._set_state(Stratum1Boss.STATE_ATTACKING)
	assert_eq(
		asprite.animation,
		StringName("atk_s"),
		"attacking state plays 'atk_<dir>' (no player → defaults to s)"
	)


func test_telegraphing_slam_plays_slam_telegraph_anim() -> void:
	var b: Stratum1Boss = _make_scene_boss()
	var asprite: AnimatedSprite2D = b.get_node("Sprite") as AnimatedSprite2D
	b._set_state(Stratum1Boss.STATE_TELEGRAPHING_SLAM)
	assert_eq(
		asprite.animation,
		StringName("slam_telegraph_s"),
		"slam-telegraph state plays 'slam_telegraph_<dir>'"
	)


func test_slam_recovery_plays_slam_anim() -> void:
	var b: Stratum1Boss = _make_scene_boss()
	var asprite: AnimatedSprite2D = b.get_node("Sprite") as AnimatedSprite2D
	b._set_state(Stratum1Boss.STATE_SLAM_RECOVERY)
	assert_eq(asprite.animation, StringName("slam_s"), "slam-recovery state plays 'slam_<dir>'")


# ---- Phase 2/3 slam-state animation coverage --------------------------


func test_phase_2_boss_slams_plays_slam_telegraph_then_slam() -> void:
	# Boss in phase 2 with player in slam range — should telegraph slam then
	# recover slam. Drives via direct phase set + close-range player.
	var b: Stratum1Boss = _make_scene_boss()
	var asprite: AnimatedSprite2D = b.get_node("Sprite") as AnimatedSprite2D
	var fp: FakePlayer = FakePlayer.new()
	add_child_autofree(fp)
	# Slam range = SLAM_HITBOX_RADIUS (80). Player at 60 east → in slam range,
	# not in melee range (36).
	fp.global_position = b.global_position + Vector2(60.0, 0.0)
	b.set_player(fp)
	# Manually flip to phase 2 + reset cooldowns so chase picks slam path.
	b.phase = Stratum1Boss.PHASE_2
	b._slam_cooldown_left = 0.0
	# Step physics — _process_chase should detect phase >= 2 + dist <= slam
	# range + cooldown 0 and enter telegraphing_slam.
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(
		b.get_state(),
		Stratum1Boss.STATE_TELEGRAPHING_SLAM,
		"phase 2 boss with player in slam range enters telegraphing_slam"
	)
	assert_eq(
		asprite.animation,
		StringName("slam_telegraph_e"),
		"slam-telegraph state plays slam_telegraph_<dir>"
	)


# ---- Direction-suffix derivation pins (8 octants) ---------------------


func test_vec_to_dir_suffix_8_octants() -> void:
	# Pin every cardinal + diagonal so a future refactor of the atan2 bin
	# math doesn't silently swap two directions. Mirrors Grunt's same pin.
	assert_eq(Stratum1Boss._vec_to_dir_suffix(Vector2(1, 0)), "e", "east")
	assert_eq(Stratum1Boss._vec_to_dir_suffix(Vector2(1, 1)), "se", "south-east")
	assert_eq(Stratum1Boss._vec_to_dir_suffix(Vector2(0, 1)), "s", "south")
	assert_eq(Stratum1Boss._vec_to_dir_suffix(Vector2(-1, 1)), "sw", "south-west")
	assert_eq(Stratum1Boss._vec_to_dir_suffix(Vector2(-1, 0)), "w", "west")
	assert_eq(Stratum1Boss._vec_to_dir_suffix(Vector2(-1, -1)), "nw", "north-west")
	assert_eq(Stratum1Boss._vec_to_dir_suffix(Vector2(0, -1)), "n", "north")
	assert_eq(Stratum1Boss._vec_to_dir_suffix(Vector2(1, -1)), "ne", "north-east")


# ---- Tween-reference flip on second hit (Tier 1 invariant) -----------


func test_hit_flash_tween_reference_flips_on_second_hit() -> void:
	# Mirror of test_grunt_animation_wire.gd / test_practice_dummy_animated.gd
	# same-class invariant per `.claude/docs/combat-architecture.md` § "Tier 1
	# corollary — tween kill-and-restart pattern".
	var b: Stratum1Boss = _make_scene_boss()
	b.take_damage(1, Vector2.ZERO, null)
	var first_tween: Tween = b._hit_flash_tween
	assert_not_null(first_tween, "first hit produces a flash tween")
	b.take_damage(1, Vector2.ZERO, null)
	var second_tween: Tween = b._hit_flash_tween
	assert_not_null(second_tween, "second hit leaves a tween in place")
	assert_ne(
		first_tween,
		second_tween,
		"second hit kills + restarts (tween reference flipped — Tier 1 invariant)"
	)


# ---- `_play_anim` no-op safety (bare-instanced boss) ------------------


func test_play_anim_is_safe_noop_on_bare_instanced_boss() -> void:
	# Bare-instanced boss (no Sprite child) — `_play_anim` must no-op, not crash.
	var b: Stratum1Boss = BossScript.new()
	b.skip_intro_for_tests = true
	add_child_autofree(b)
	b._play_anim(&"walk")
	b._play_anim(&"hit")
	b._play_anim(&"die")
	b._play_anim(&"slam_telegraph")
	b._play_anim(&"nonexistent_state")
	assert_eq(true, true, "bare-instanced _play_anim calls did not crash")
