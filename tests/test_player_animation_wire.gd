extends GutTest
## M3W-2 paired test — Player AnimatedSprite2D wiring.
##
## Pins the conventions established by M3W-2 (this PR):
##   - Sprite child resolves to AnimatedSprite2D (not ColorRect) when the
##     production .tscn is loaded.
##   - SpriteFrames at `res://assets/sprites/player/Player.tres` exposes all
##     48 sub-anims (6 states × 8 directions). Loop policy: `walk_*` loops;
##     all others (attack_light/heavy, dodge, hit, die) are one-shots.
##   - 8-octant facing-direction quantizer maps each cardinal/diagonal
##     Vector2 to its expected dir suffix.
##   - `state_changed` signal drives `AnimatedSprite2D.animation = "<prefix>_<dir>"`
##     for each STATE_* transition; attack split between light/heavy by
##     `_current_attack_kind`.
##   - `take_damage` plays `hit_<dir>` interrupt + hit-flash modulate tween
##     toward HIT_FLASH_TINT (M3W-1 inheritance).
##   - `_die` plays `die_<dir>` (overrides any in-flight anim).
##   - Tier 1 color-delta on AnimatedSprite2D hit-flash — `HIT_FLASH_TINT`
##     observably differs from rest white (sum-delta >= 0.20). Mirror
##     PracticeDummy assertion shape.
##   - HTML5 HDR-clamp guard — every HIT_FLASH_TINT channel in [0, 1].
##
## Companion to existing `tests/test_player_*.gd` — pre-M3W-2 behavior
## (state machine transitions, damage/HP, dodge i-frames, regen) is covered
## there; this file pins ONLY the animation wiring contract.

const PlayerScript: Script = preload("res://scripts/player/Player.gd")
const SPRITE_FRAMES_PATH: String = "res://assets/sprites/player/Player.tres"
const ANIM_DIRS: Array[String] = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
const ANIM_STATES: Array[String] = ["walk", "attack_light", "attack_heavy", "dodge", "hit", "die"]

# ---- Helpers ----------------------------------------------------------


func _make_scene_player() -> Player:
	# Production scene-loaded Player (Sprite child is AnimatedSprite2D).
	var packed: PackedScene = load("res://scenes/player/Player.tscn")
	var p: Player = packed.instantiate() as Player
	add_child_autofree(p)
	return p


# ---- Convention: Sprite child resolves to AnimatedSprite2D ------------


func test_scene_sprite_is_animated_sprite2d_with_sprite_frames() -> void:
	# M3W-2 swap: the production .tscn's "Sprite" node is now AnimatedSprite2D,
	# not ColorRect. The node name is preserved ("Sprite") so existing
	# resolvers (`get_node("Sprite")`, `_update_sprite_rotation`,
	# `_hit_flash_target` resolver) continue to work.
	var p: Player = _make_scene_player()
	var sprite_node: Node = p.get_node_or_null("Sprite")
	assert_not_null(sprite_node, "Player.tscn has a 'Sprite' child")
	assert_true(
		sprite_node is AnimatedSprite2D,
		"Sprite child resolves to AnimatedSprite2D (M3W-2 convention)"
	)
	var asprite: AnimatedSprite2D = sprite_node as AnimatedSprite2D
	assert_not_null(asprite.sprite_frames, "AnimatedSprite2D has a SpriteFrames resource assigned")
	# texture_filter = TEXTURE_FILTER_NEAREST (1) preserves pixel-art hardness.
	assert_eq(
		asprite.texture_filter,
		CanvasItem.TEXTURE_FILTER_NEAREST,
		"texture_filter = NEAREST (pixel-art hardness preserved)"
	)


# ---- Convention: SpriteFrames exposes all 48 sub-anims ----------------


func test_sprite_frames_resource_exposes_all_state_x_direction_keys() -> void:
	# 6 states × 8 directions = 48 sub-animation keys. The animation_key
	# convention is `<state>_<dir>`; M3W-2 mirrors M3W-1's shape verbatim.
	var frames: SpriteFrames = load(SPRITE_FRAMES_PATH) as SpriteFrames
	assert_not_null(frames, "Player SpriteFrames .tres loads")
	for state in ANIM_STATES:
		for dir_suffix in ANIM_DIRS:
			var anim_name: String = "%s_%s" % [state, dir_suffix]
			assert_true(
				frames.has_animation(StringName(anim_name)),
				"SpriteFrames exposes animation '%s'" % anim_name
			)


func test_sprite_frames_loop_flags_match_policy() -> void:
	# Loop policy — walk_* loops (movement is cyclical); attack_light/heavy,
	# dodge, hit, die are one-shots (loop=false; state machine drives next anim).
	var frames: SpriteFrames = load(SPRITE_FRAMES_PATH) as SpriteFrames
	for dir_suffix in ANIM_DIRS:
		var walk_name: StringName = StringName("walk_%s" % dir_suffix)
		assert_true(
			frames.get_animation_loop(walk_name), "'%s' loops (movement is cyclical)" % walk_name
		)
	for state in ["attack_light", "attack_heavy", "dodge", "hit", "die"]:
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("%s_%s" % [state, dir_suffix])
			assert_false(
				frames.get_animation_loop(anim_name), "'%s' is one-shot (loop=false)" % anim_name
			)


func test_sprite_frames_fps_is_8_for_all_anims() -> void:
	# FPS policy — 8 fps for every anim (M3W-1 convention).
	var frames: SpriteFrames = load(SPRITE_FRAMES_PATH) as SpriteFrames
	for state in ANIM_STATES:
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("%s_%s" % [state, dir_suffix])
			assert_eq(
				frames.get_animation_speed(anim_name),
				8.0,
				"'%s' plays at 8 fps (M3W-1 convention)" % anim_name
			)


# ---- 8-octant facing quantizer ---------------------------------------


func test_dir_suffix_for_facing_8_cardinals() -> void:
	# Each cardinal / diagonal Vector2 quantizes to its expected suffix.
	# Godot screen-space: +Y is DOWN, so:
	#   Vector2.RIGHT → "e"
	#   Vector2.DOWN  → "s"
	#   Vector2.LEFT  → "w"
	#   Vector2.UP    → "n"
	# Diagonals are unit-length normalized.
	assert_eq(PlayerScript.dir_suffix_for_facing(Vector2.RIGHT), "e", "+X (right) quantizes to 'e'")
	assert_eq(
		PlayerScript.dir_suffix_for_facing(Vector2(1, 1).normalized()),
		"se",
		"+X+Y (down-right) quantizes to 'se'"
	)
	assert_eq(PlayerScript.dir_suffix_for_facing(Vector2.DOWN), "s", "+Y (down) quantizes to 's'")
	assert_eq(
		PlayerScript.dir_suffix_for_facing(Vector2(-1, 1).normalized()),
		"sw",
		"-X+Y (down-left) quantizes to 'sw'"
	)
	assert_eq(PlayerScript.dir_suffix_for_facing(Vector2.LEFT), "w", "-X (left) quantizes to 'w'")
	assert_eq(
		PlayerScript.dir_suffix_for_facing(Vector2(-1, -1).normalized()),
		"nw",
		"-X-Y (up-left) quantizes to 'nw'"
	)
	assert_eq(PlayerScript.dir_suffix_for_facing(Vector2.UP), "n", "-Y (up) quantizes to 'n'")
	assert_eq(
		PlayerScript.dir_suffix_for_facing(Vector2(1, -1).normalized()),
		"ne",
		"+X-Y (up-right) quantizes to 'ne'"
	)


func test_dir_suffix_for_facing_8_suffixes_are_permutation() -> void:
	# All 8 cardinals produce all 8 distinct suffixes — no octant collisions.
	var seen: Dictionary = {}
	var cardinals: Array = [
		Vector2.RIGHT,
		Vector2(1, 1).normalized(),
		Vector2.DOWN,
		Vector2(-1, 1).normalized(),
		Vector2.LEFT,
		Vector2(-1, -1).normalized(),
		Vector2.UP,
		Vector2(1, -1).normalized(),
	]
	for v in cardinals:
		var s: String = PlayerScript.dir_suffix_for_facing(v)
		seen[s] = true
	assert_eq(seen.size(), 8, "8 cardinals produce 8 distinct suffixes — got %d" % seen.size())


func test_dir_suffix_for_facing_zero_returns_default() -> void:
	# Zero vector (no facing) returns default "s" — defensive fallback;
	# callers should pre-filter, but the helper must not return ""/crash.
	assert_eq(
		PlayerScript.dir_suffix_for_facing(Vector2.ZERO),
		"s",
		"zero vector returns default 's' (defensive)"
	)


# ---- Convention: state_changed drives AnimatedSprite2D ---------------


func test_state_change_to_attack_light_plays_attack_light_dir() -> void:
	# state_changed signal handler drives AnimatedSprite2D into
	# `attack_light_<dir>` when STATE_ATTACK enters with ATTACK_LIGHT kind.
	var p: Player = _make_scene_player()
	# Snapshot facing east so the quantizer returns "e" deterministically.
	p._facing = Vector2.RIGHT
	# Fire a light attack — try_attack sets _current_attack_kind THEN set_state,
	# so the signal handler sees ATTACK_LIGHT.
	p.try_attack(Player.ATTACK_LIGHT, Vector2.RIGHT)
	var asprite: AnimatedSprite2D = p.get_node("Sprite") as AnimatedSprite2D
	assert_eq(
		asprite.animation,
		StringName("attack_light_e"),
		"STATE_ATTACK + ATTACK_LIGHT + facing east → 'attack_light_e'"
	)


func test_state_change_to_attack_heavy_plays_attack_heavy_dir() -> void:
	var p: Player = _make_scene_player()
	p._facing = Vector2.DOWN
	p.try_attack(Player.ATTACK_HEAVY, Vector2.DOWN)
	var asprite: AnimatedSprite2D = p.get_node("Sprite") as AnimatedSprite2D
	assert_eq(
		asprite.animation,
		StringName("attack_heavy_s"),
		"STATE_ATTACK + ATTACK_HEAVY + facing south → 'attack_heavy_s'"
	)


func test_state_change_to_dodge_plays_dodge_dir() -> void:
	var p: Player = _make_scene_player()
	p._facing = Vector2.LEFT
	p.try_dodge(Vector2.LEFT)
	var asprite: AnimatedSprite2D = p.get_node("Sprite") as AnimatedSprite2D
	assert_eq(asprite.animation, StringName("dodge_w"), "STATE_DODGE + facing west → 'dodge_w'")


func test_state_change_to_walk_plays_walk_dir_loop() -> void:
	# Forcing STATE_WALK via set_state drives walk_<dir> with is_playing()
	# true (the anim loops). Post walk-feel-fix: dir comes from `velocity`,
	# not `_facing`. We set both to north to keep this test's assertion
	# matched and orthogonal from the walk-vs-facing decoupling tests below.
	var p: Player = _make_scene_player()
	p._facing = Vector2.UP
	p.velocity = Vector2.UP * 120.0
	p.set_state(Player.STATE_WALK)
	var asprite: AnimatedSprite2D = p.get_node("Sprite") as AnimatedSprite2D
	assert_eq(asprite.animation, StringName("walk_n"), "STATE_WALK + velocity north → 'walk_n'")
	assert_true(asprite.is_playing(), "walk_n is_playing() — looping anim runs immediately")


# ---- take_damage drives hit anim + hit-flash --------------------------


func test_take_damage_plays_hit_dir_animation() -> void:
	var p: Player = _make_scene_player()
	p._facing = Vector2.RIGHT
	# Non-fatal hit (default HP=100, deal 5).
	p.take_damage(5, Vector2.ZERO, null)
	var asprite: AnimatedSprite2D = p.get_node("Sprite") as AnimatedSprite2D
	assert_eq(asprite.animation, StringName("hit_e"), "take_damage + facing east → 'hit_e'")


# ---- _die drives die anim ---------------------------------------------


func test_die_plays_die_dir_animation() -> void:
	var p: Player = _make_scene_player()
	p._facing = Vector2.DOWN
	# Lethal hit (HP=100, deal 100).
	p.take_damage(100, Vector2.ZERO, null)
	assert_true(p.is_dead(), "player dead after lethal hit (precondition)")
	var asprite: AnimatedSprite2D = p.get_node("Sprite") as AnimatedSprite2D
	assert_eq(
		asprite.animation,
		StringName("die_s"),
		"_die + facing south → 'die_s' (overrides in-flight hit_s)"
	)


# ---- HIT_FLASH_TINT: Tier 1 color-delta + HTML5 HDR-clamp guard ------


func test_hit_flash_tint_differs_from_rest_white() -> void:
	# Tier 1 invariant per `.claude/docs/test-conventions.md` § "Visual-primitive
	# testing tiers": `target color ≠ rest color`. If HIT_FLASH_TINT == white,
	# the modulate tween is a no-op (the PR #115 / #140 trap class).
	#
	# Mirror PracticeDummy assertion shape (M3W-1 inheritance).
	var rest_white: Color = Color(1, 1, 1, 1)
	assert_ne(
		Player.HIT_FLASH_TINT,
		rest_white,
		"HIT_FLASH_TINT differs from rest white (tween is not a no-op)"
	)
	var delta: float = (
		absf(Player.HIT_FLASH_TINT.r - rest_white.r)
		+ absf(Player.HIT_FLASH_TINT.g - rest_white.g)
		+ absf(Player.HIT_FLASH_TINT.b - rest_white.b)
	)
	assert_gt(
		delta,
		0.20,
		"HIT_FLASH_TINT sum-delta vs (1,1,1) >= 0.20 (delta=%.3f, visible flash)" % delta
	)


func test_hit_flash_tint_channels_are_html5_safe() -> void:
	# HTML5 HDR-clamp guard per `.claude/docs/html5-export.md` — every
	# modulate channel must be in [0, 1]. The HIT_FLASH_TINT constant is the
	# only non-rest endpoint the AnimatedSprite2D path tweens to.
	var tint: Color = Player.HIT_FLASH_TINT
	assert_between(tint.r, 0.0, 1.0, "HIT_FLASH_TINT.r in [0,1] — HTML5 safe")
	assert_between(tint.g, 0.0, 1.0, "HIT_FLASH_TINT.g in [0,1] — HTML5 safe")
	assert_between(tint.b, 0.0, 1.0, "HIT_FLASH_TINT.b in [0,1] — HTML5 safe")
	assert_between(tint.a, 0.0, 1.0, "HIT_FLASH_TINT.a in [0,1] — HTML5 safe")


func test_hit_flash_tint_matches_practice_dummy_tint() -> void:
	# M3W-1 inheritance contract: every mob's hit-flash tint must be identical
	# so the M3 art roster reads with a single hit-reaction color. Drift here
	# means Drew/Tess sign-off on PracticeDummy doesn't transitively cover Player.
	var pd: GDScript = load("res://scripts/mobs/PracticeDummy.gd") as GDScript
	# PracticeDummy.HIT_FLASH_TINT is a class constant — read it via the class.
	var pd_tint: Color = pd.HIT_FLASH_TINT
	assert_eq(
		Player.HIT_FLASH_TINT,
		pd_tint,
		"Player.HIT_FLASH_TINT == PracticeDummy.HIT_FLASH_TINT (M3W-1 inheritance)"
	)


# ---- Hit-flash tween-reference flips on second hit (Tier 1 invariant) -


func test_animated_sprite_hit_flash_tween_reference_flips_on_second_hit() -> void:
	# The PR #221 Tier 1 reference-change invariant — a second hit during the
	# flash window kills the in-flight tween and creates a fresh one. Assert the
	# tween reference flipped (kill is async; is_valid would lie about the
	# prior tween's state).
	var p: Player = _make_scene_player()
	p.take_damage(5, Vector2.ZERO, null)
	var first_tween: Tween = p._hit_flash_tween
	assert_not_null(first_tween, "first hit produces a flash tween (AnimatedSprite2D path)")
	p.take_damage(5, Vector2.ZERO, null)
	# If hit-iframes ate the second damage, take_damage returns without firing
	# a flash. Force-clear iframes before the second hit so we exercise the
	# kill-and-restart path.
	# (The first take_damage grants HIT_IFRAMES_SECS = 0.25; that's why this
	# test forces a second non-iframe-blocked hit via direct _play_hit_flash.)
	p._play_hit_flash()
	var second_tween: Tween = p._hit_flash_tween
	assert_not_null(second_tween, "second hit leaves a tween in place")
	assert_ne(
		first_tween,
		second_tween,
		"second hit kills + restarts (tween reference flipped — Tier 1 invariant)"
	)


# ---- AnimatedSprite2D resolved lazily on bare player ----------------


func test_play_anim_is_a_safe_noop_on_bare_instanced_player() -> void:
	# Bare-instanced player (no Sprite child, no SpriteFrames) — `_play_anim`
	# must be a no-op, not a crash. Existing tests construct a Player via
	# `Player.new()` in some paths.
	var p: Player = PlayerScript.new()
	add_child_autofree(p)
	# These calls would crash if the resolver didn't no-op gracefully.
	p._play_anim("walk")
	p._play_anim("attack_light")
	p._play_anim("nonexistent_state")
	assert_eq(true, true, "bare-instanced _play_anim calls did not crash")


# ---- Idle freezes on frame 0 -----------------------------------------


func test_idle_state_stops_animated_sprite_on_frame_0() -> void:
	# STATE_IDLE special-case: prefix resolves to `walk` (placeholder, no idle
	# anim in #265 PixelLab batch), but we want the sprite frozen on frame 0
	# of `walk_<dir>` rather than animating-in-place. Tested by transitioning
	# WALK → IDLE and checking is_playing() == false + frame == 0.
	var p: Player = _make_scene_player()
	p._facing = Vector2.DOWN
	# Pre-fix: STATE_WALK alone produced walk_<facing-dir>. Post-fix: it
	# resolves via velocity octant, so the test must drive velocity too.
	p.velocity = Vector2.DOWN * 120.0  # walk speed south
	p.set_state(Player.STATE_WALK)
	var asprite: AnimatedSprite2D = p.get_node("Sprite") as AnimatedSprite2D
	assert_true(asprite.is_playing(), "walk is playing (precondition)")
	# IDLE entry — `_process_grounded` would write velocity = ZERO, mirror it.
	p.velocity = Vector2.ZERO
	p.set_state(Player.STATE_IDLE)
	# IDLE handler calls stop() + frame = 0.
	assert_false(asprite.is_playing(), "STATE_IDLE stops the AnimatedSprite2D (rest pose)")
	assert_eq(asprite.frame, 0, "STATE_IDLE freezes on frame 0 of walk_<dir>")


# ---- Walk-feel fix: anim dir follows velocity, not _facing -----------
# Sponsor 2026-05-18 soak finding on PR #274 — "character looking at mouse
# cursor while walking is weird". The fix decouples animation direction from
# aim direction: WALK/IDLE → velocity octant (or held last); ATTACK/DODGE
# → `_facing` octant (mouse-derived, unchanged from PR #255).
#
# These tests pin the decoupling so a future refactor can't silently
# re-couple walk anim to `_facing`.


func test_walk_anim_follows_velocity_not_facing() -> void:
	# Player moving NORTH with mouse-facing EAST should play `walk_n`
	# (movement direction), NOT `walk_e` (mouse direction).
	var p: Player = _make_scene_player()
	p._facing = Vector2.RIGHT  # mouse to the east
	p.velocity = Vector2.UP * 120.0  # WASD pushing north (Y-up in Godot)
	p.set_state(Player.STATE_WALK)
	var asprite: AnimatedSprite2D = p.get_node("Sprite") as AnimatedSprite2D
	assert_eq(
		asprite.animation,
		StringName("walk_n"),
		"WALK + velocity north + facing east → 'walk_n' (movement wins)"
	)


func test_walk_anim_velocity_octant_for_all_8_directions() -> void:
	# Every cardinal/diagonal velocity quantizes to the matching walk_<dir>
	# anim regardless of `_facing`. Anchor `_facing` to east so any leak from
	# the pre-fix `_facing`-based resolver would visibly produce "walk_e"
	# instead of the expected direction.
	var p: Player = _make_scene_player()
	p._facing = Vector2.RIGHT  # constant mouse-facing east
	var asprite: AnimatedSprite2D = p.get_node("Sprite") as AnimatedSprite2D
	var cases: Array = [
		[Vector2.RIGHT, "e"],
		[Vector2(1, 1).normalized(), "se"],
		[Vector2.DOWN, "s"],
		[Vector2(-1, 1).normalized(), "sw"],
		[Vector2.LEFT, "w"],
		[Vector2(-1, -1).normalized(), "nw"],
		[Vector2.UP, "n"],
		[Vector2(1, -1).normalized(), "ne"],
	]
	for c in cases:
		var v: Vector2 = c[0]
		var expected_dir: String = c[1]
		# Transition through IDLE so set_state(STATE_WALK) is a real edge that
		# fires state_changed. Same-state set_state would early-out.
		p.velocity = Vector2.ZERO
		p.set_state(Player.STATE_IDLE)
		p.velocity = v * 120.0
		p.set_state(Player.STATE_WALK)
		assert_eq(
			asprite.animation,
			StringName("walk_%s" % expected_dir),
			"velocity %s (facing east) → 'walk_%s'" % [v, expected_dir]
		)


func test_idle_holds_last_walk_direction_not_facing() -> void:
	# Player walks NORTH, then stops while mouse points EAST. The held idle
	# anim must be `walk_n` (last walk dir frame 0), NOT `walk_e` (cursor).
	var p: Player = _make_scene_player()
	# Phase 1: walk north.
	p._facing = Vector2.UP
	p.velocity = Vector2.UP * 120.0
	p.set_state(Player.STATE_WALK)
	var asprite: AnimatedSprite2D = p.get_node("Sprite") as AnimatedSprite2D
	assert_eq(
		asprite.animation, StringName("walk_n"), "phase 1: walking north → 'walk_n' (precondition)"
	)
	# Phase 2: stop walking, mouse swings east — IDLE must hold north.
	p._facing = Vector2.RIGHT  # cursor moves east
	p.velocity = Vector2.ZERO  # WASD released
	p.set_state(Player.STATE_IDLE)
	assert_eq(
		asprite.animation,
		StringName("walk_n"),
		"phase 2: idle + cursor east holds 'walk_n' (not snap to 'walk_e')"
	)
	# IDLE special-case: frozen on frame 0.
	assert_false(asprite.is_playing(), "idle frozen (not looping)")
	assert_eq(asprite.frame, 0, "idle frozen on frame 0")


func test_walk_dir_updates_when_velocity_octant_changes_mid_walk() -> void:
	# Player walking north (WASD = W), then changes to east (WASD = D) without
	# leaving STATE_WALK. The walk anim must switch from `walk_n` to `walk_e`
	# on the NEXT physics tick — `state_changed` won't fire because the state
	# didn't change. `_drive_walk_anim_if_moving` is the path that handles this.
	var p: Player = _make_scene_player()
	p._facing = Vector2.RIGHT  # mouse east (red herring — should NOT affect walk anim)
	p.velocity = Vector2.UP * 120.0
	p.set_state(Player.STATE_WALK)
	var asprite: AnimatedSprite2D = p.get_node("Sprite") as AnimatedSprite2D
	assert_eq(
		asprite.animation, StringName("walk_n"), "phase 1: velocity north → 'walk_n' (precondition)"
	)
	# Phase 2: velocity rotates east mid-walk (still STATE_WALK).
	p.velocity = Vector2.RIGHT * 120.0
	p._drive_walk_anim_if_moving()  # called by _physics_process post-move_and_slide
	assert_eq(
		asprite.animation,
		StringName("walk_e"),
		"velocity east mid-walk → 'walk_e' (re-driven without state transition)"
	)


func test_walk_anim_does_not_restart_when_velocity_octant_unchanged() -> void:
	# `_drive_walk_anim_if_moving` must NOT call play() when the resolved
	# octant matches `_last_anim_dir` — otherwise the walk loop would freeze
	# on frame 0 every physics tick (play() restarts from frame 0).
	var p: Player = _make_scene_player()
	p._facing = Vector2.DOWN
	p.velocity = Vector2.DOWN * 120.0
	p.set_state(Player.STATE_WALK)
	var asprite: AnimatedSprite2D = p.get_node("Sprite") as AnimatedSprite2D
	assert_eq(asprite.animation, StringName("walk_s"), "precondition: walk_s")
	# Advance to a non-zero frame so we can detect a play()-restart.
	asprite.frame = 2
	# Same velocity, multiple ticks — should be a no-op.
	p._drive_walk_anim_if_moving()
	p._drive_walk_anim_if_moving()
	p._drive_walk_anim_if_moving()
	assert_eq(asprite.frame, 2, "velocity unchanged → no play() restart (frame stays at 2)")


func test_attack_anim_still_uses_facing_not_velocity() -> void:
	# Mouse-direction attacks must still aim at cursor (PR #255 contract).
	# Player walking south with mouse pointing east → attack_light must play
	# `attack_light_e` (cursor direction), NOT `attack_light_s` (movement dir).
	var p: Player = _make_scene_player()
	p._facing = Vector2.RIGHT  # mouse east
	p.velocity = Vector2.DOWN * 120.0  # walking south
	p.set_state(Player.STATE_WALK)
	# Fire light attack — try_attack sets _current_attack_kind THEN set_state.
	p.try_attack(Player.ATTACK_LIGHT, Vector2.ZERO)
	var asprite: AnimatedSprite2D = p.get_node("Sprite") as AnimatedSprite2D
	assert_eq(
		asprite.animation,
		StringName("attack_light_e"),
		"attack with mouse east + walking south → 'attack_light_e' (cursor wins)"
	)


func test_heavy_attack_anim_still_uses_facing_not_velocity() -> void:
	# Same contract for heavy attacks.
	var p: Player = _make_scene_player()
	p._facing = Vector2.UP  # mouse north
	p.velocity = Vector2.LEFT * 120.0  # walking west
	p.set_state(Player.STATE_WALK)
	p.try_attack(Player.ATTACK_HEAVY, Vector2.ZERO)
	var asprite: AnimatedSprite2D = p.get_node("Sprite") as AnimatedSprite2D
	assert_eq(
		asprite.animation,
		StringName("attack_heavy_n"),
		"heavy attack with mouse north + walking west → 'attack_heavy_n'"
	)


func test_dodge_anim_uses_facing_after_try_dodge() -> void:
	# `try_dodge(dir)` overwrites `_facing = dir` (movement-dodge by design),
	# then sets STATE_DODGE. The dodge anim direction follows the dodge dir.
	# This test guards that the walk-feel fix didn't accidentally redirect
	# dodge anim to use velocity (which `try_dodge` ALSO sets, but to the
	# same value as _facing — so the octant would coincide. We assert the
	# anim is driven by _facing for documentation, not for distinguishing).
	var p: Player = _make_scene_player()
	p._facing = Vector2.RIGHT  # initial cursor east (irrelevant after try_dodge)
	p.try_dodge(Vector2.LEFT)  # dodge west — try_dodge sets _facing = LEFT
	var asprite: AnimatedSprite2D = p.get_node("Sprite") as AnimatedSprite2D
	assert_eq(
		asprite.animation,
		StringName("dodge_w"),
		"dodge west → 'dodge_w' (try_dodge sets _facing to dodge dir)"
	)


func test_hit_anim_uses_facing_not_velocity() -> void:
	# take_damage plays hit_<dir>. The "threat direction" semantics use
	# `_facing` (PR #255 cursor-direction). Walk-feel fix must not redirect
	# hit anim to velocity octant.
	var p: Player = _make_scene_player()
	p._facing = Vector2.RIGHT  # mouse east
	p.velocity = Vector2.DOWN * 120.0  # walking south (irrelevant for hit)
	p.set_state(Player.STATE_WALK)
	# Non-fatal hit.
	p.take_damage(5, Vector2.ZERO, null)
	var asprite: AnimatedSprite2D = p.get_node("Sprite") as AnimatedSprite2D
	assert_eq(
		asprite.animation,
		StringName("hit_e"),
		"hit with cursor east + walking south → 'hit_e' (cursor wins)"
	)


func test_die_anim_uses_facing_not_velocity() -> void:
	# Same contract for _die. Walk-feel fix preserves cursor-direction die anim.
	var p: Player = _make_scene_player()
	p._facing = Vector2.UP
	p.velocity = Vector2.LEFT * 120.0  # walking west (irrelevant)
	p.set_state(Player.STATE_WALK)
	p.take_damage(100, Vector2.ZERO, null)  # lethal
	assert_true(p.is_dead(), "player dead after lethal hit (precondition)")
	var asprite: AnimatedSprite2D = p.get_node("Sprite") as AnimatedSprite2D
	assert_eq(
		asprite.animation,
		StringName("die_n"),
		"_die with cursor north + walking west → 'die_n' (cursor wins)"
	)


func test_velocity_octant_threshold_treats_near_zero_as_idle() -> void:
	# Velocity below VELOCITY_OCTANT_THRESHOLD (1.0) should be treated as
	# "not moving" — the resolver holds `_last_anim_dir` instead of snapping
	# to the noise vector's octant. Guards against floating-point drift
	# producing flickery dir suffixes on near-zero velocity frames.
	var p: Player = _make_scene_player()
	# Seed: walk south, anchor _last_anim_dir = "s".
	p._facing = Vector2.DOWN
	p.velocity = Vector2.DOWN * 120.0
	p.set_state(Player.STATE_WALK)
	var asprite: AnimatedSprite2D = p.get_node("Sprite") as AnimatedSprite2D
	assert_eq(asprite.animation, StringName("walk_s"), "precondition")
	# Now drop into STATE_IDLE with a tiny non-zero velocity (e.g. from
	# physics-bounce drift). Should still hold "walk_s", not snap.
	p.velocity = Vector2(0.3, -0.4)  # length ~0.5, below 1.0 threshold
	p.set_state(Player.STATE_IDLE)
	assert_eq(
		asprite.animation,
		StringName("walk_s"),
		"velocity below threshold treated as idle (holds last dir)"
	)


func test_seed_anim_in_ready_renders_walk_s_for_default_facing() -> void:
	# Regression pin: a scene-loaded Player must show `walk_s` frame 0 on
	# first render (default _facing = Vector2.DOWN, default _last_anim_dir
	# = "s", initial state = IDLE). Pre-fix and post-fix both produce the
	# same first-frame rest pose — this test pins post-fix parity.
	var p: Player = _make_scene_player()
	var asprite: AnimatedSprite2D = p.get_node("Sprite") as AnimatedSprite2D
	assert_eq(
		asprite.animation,
		StringName("walk_s"),
		"seed-anim: default IDLE state + default facing south → 'walk_s'"
	)
	assert_false(asprite.is_playing(), "seed-anim: frozen on frame 0 (idle)")
