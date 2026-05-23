extends GutTest
## Integration test — M3-T2-W1-T8 boss wake-animation (ticket 86c9wjyp9).
##
## Pre-T8 the boss transitioned DORMANT -> IDLE directly inside `wake()`.
## With the wake-anim now wired:
##   1. SpriteFrames has 8 `wake_<dir>` animation keys (5 frames each, ~417 ms).
##   2. `wake()` transitions DORMANT -> STATE_WAKING (intermediate damage-immune
##      window) and plays `wake_<dir>` via `_play_anim`. `boss_woke.emit()`
##      still fires at the START so the Beat-3 audio stinger timing is intact.
##   3. Damage-immunity extends to cover STATE_WAKING.
##   4. After `WAKE_DURATION` (~417 ms) the boss auto-transitions to STATE_IDLE
##      and combat becomes available.
##
## Coverage shape — three test groups:
##   A. SpriteFrames assets — all 8 wake_<dir> keys present, 5 frames each,
##      loop=false (one-shot).
##   B. State machine — DORMANT -> WAKING on wake(), -> IDLE after duration,
##      `wake` anim played on AnimatedSprite2D, boss_woke timing preserved.
##   C. Damage-immunity — take_damage rejected during WAKING; lands after.
##
## REGRESSION-86c9wjyp9: catches the bug class "wake-anim window forgot to
## extend immunity from DORMANT to WAKING" — a player attack landing in the
## first frame after wake() would otherwise prematurely kill the boss.

const BossScript: Script = preload("res://scripts/mobs/Stratum1Boss.gd")
const BossRoomScript: Script = preload("res://scripts/levels/Stratum1BossRoom.gd")

const EXPECTED_WAKE_FRAMES: int = 5
const EXPECTED_WAKE_FPS: float = 12.0
const EXPECTED_WAKE_DURATION_S: float = 0.417

const DIR_SUFFIXES: Array[String] = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]

# ---- Test isolation ---------------------------------------------------
# M3 Tier 2 Wave 1 — Stratum1Boss fires TimeScaleDirector requests on hit /
# die / phase-transition. Reset on both ends so this suite doesn't leak
# Engine.time_scale into others. Same shape as test_boss_wakes_and_engages.


func before_each() -> void:
	var d: Node = Engine.get_main_loop().root.get_node_or_null("TimeScaleDirector")
	if d != null and d.has_method("reset"):
		d.reset()
	Engine.time_scale = 1.0


func after_each() -> void:
	var d: Node = Engine.get_main_loop().root.get_node_or_null("TimeScaleDirector")
	if d != null and d.has_method("reset"):
		d.reset()
	Engine.time_scale = 1.0


# ---- Helpers ----------------------------------------------------------


func _load_boss_frames() -> SpriteFrames:
	return load("res://assets/sprites/boss/Stratum1Boss.tres") as SpriteFrames


func _make_dormant_boss() -> Stratum1Boss:
	# Default skip_intro_for_tests = false → starts DORMANT.
	var b: Stratum1Boss = BossScript.new()
	add_child_autofree(b)
	return b


# ---- A: SpriteFrames assets ------------------------------------------


func test_sprite_frames_has_all_eight_wake_directions() -> void:
	# Structural — pins the SpriteFrames asset against accidental deletion or
	# rename. If a future refactor drops a wake direction, the boss with a
	# matching `_compute_facing_dir_suffix` value will animation-no-op silently
	# (the production guard in `_play_anim` is `has_animation(...) -> return`).
	var sf: SpriteFrames = _load_boss_frames()
	assert_not_null(sf, "Stratum1Boss.tres must load as SpriteFrames")
	for suffix in DIR_SUFFIXES:
		var key: StringName = StringName("wake_%s" % suffix)
		assert_true(
			sf.has_animation(key),
			"SpriteFrames missing wake animation '%s' (8-direction contract)" % key
		)


func test_each_wake_direction_has_five_frames() -> void:
	# Pin the PixelLab-source frame count. Each `getting-up` direction shipped
	# 5 frames; the SpriteFrames must reference all of them. If someone copies
	# a wake_<dir> entry without all 5 frames the wake animation cuts short
	# and reads as a frame-skip in HTML5 soak.
	var sf: SpriteFrames = _load_boss_frames()
	for suffix in DIR_SUFFIXES:
		var key: StringName = StringName("wake_%s" % suffix)
		assert_eq(
			sf.get_frame_count(key),
			EXPECTED_WAKE_FRAMES,
			(
				"wake_%s must have %d frames (PixelLab getting-up template)"
				% [suffix, EXPECTED_WAKE_FRAMES]
			)
		)


func test_wake_animations_are_one_shot() -> void:
	# Wake is a single stand-up beat — must NOT loop. If `loop` accidentally
	# defaults to true (the SpriteFrames editor default), the boss enters an
	# infinite stand-up cycle and the auto-transition to STATE_IDLE plays the
	# `walk_<dir>` anim on top of the still-running wake — visual jank.
	var sf: SpriteFrames = _load_boss_frames()
	for suffix in DIR_SUFFIXES:
		var key: StringName = StringName("wake_%s" % suffix)
		assert_false(sf.get_animation_loop(key), "wake_%s must be one-shot (loop=false)" % suffix)


func test_wake_animation_speed_lands_inside_uma_bi06_band() -> void:
	# Per Uma BI-06 the wake-anim target window is ~500 ms. 5 frames @ 12 fps
	# = ~417 ms — inside the band. If someone bumps the speed to 8 or 16 fps,
	# the wake animation falls outside the BI-06 target and either drags or
	# clips the boss-room cinematic rhythm.
	var sf: SpriteFrames = _load_boss_frames()
	for suffix in DIR_SUFFIXES:
		var key: StringName = StringName("wake_%s" % suffix)
		assert_eq(
			sf.get_animation_speed(key),
			EXPECTED_WAKE_FPS,
			"wake_%s speed must be %.1f fps" % [suffix, EXPECTED_WAKE_FPS]
		)


func test_wake_duration_constant_matches_frame_math() -> void:
	# Drift-pin: WAKE_DURATION on the boss script must be consistent with the
	# SpriteFrames frame-count * (1 / speed). If a future refactor bumps the
	# SpriteFrames speed without bumping the script constant (or vice versa)
	# the damage-immunity window decouples from the actual animation length.
	var derived: float = float(EXPECTED_WAKE_FRAMES) / EXPECTED_WAKE_FPS
	assert_almost_eq(
		Stratum1Boss.WAKE_DURATION, derived, 0.001, "WAKE_DURATION constant must equal frames/fps"
	)
	assert_almost_eq(
		Stratum1Boss.WAKE_DURATION,
		EXPECTED_WAKE_DURATION_S,
		0.001,
		"WAKE_DURATION must match the Uma BI-06 ~500ms target band"
	)


# ---- B: State machine ------------------------------------------------


func test_wake_call_transitions_dormant_to_waking() -> void:
	var b: Stratum1Boss = _make_dormant_boss()
	assert_eq(b.get_state(), Stratum1Boss.STATE_DORMANT, "precondition: DORMANT")
	watch_signals(b)
	b.wake()
	assert_eq(
		b.get_state(),
		Stratum1Boss.STATE_WAKING,
		"wake() lands in WAKING (not IDLE — wake-anim window first)"
	)
	assert_true(b.is_waking(), "is_waking() helper returns true")
	# Beat-3 audio stinger timing preserved — boss_woke emits on wake-entry.
	assert_signal_emit_count(
		b, "boss_woke", 1, "boss_woke fires on DORMANT -> WAKING transition (Beat 3)"
	)


func test_waking_state_advances_to_idle_after_wake_duration() -> void:
	var b: Stratum1Boss = _make_dormant_boss()
	b.wake()
	# Tick enough frames to drain WAKE_DURATION (417 ms). Each tick = 16 ms.
	# 30 ticks = 480 ms — safely past WAKE_DURATION.
	for _i in 30:
		b._physics_process(0.016)
	assert_eq(
		b.get_state(),
		Stratum1Boss.STATE_IDLE,
		"WAKING -> IDLE auto-transition after WAKE_DURATION drains"
	)
	assert_false(b.is_waking(), "is_waking() returns false after transition")


func test_set_state_plays_wake_anim_on_animated_sprite() -> void:
	# Production .tscn has an AnimatedSprite2D child; bare-instanced bosses
	# don't, so the `_play_anim` resolver no-ops. We verify the SET_STATE path
	# DOES call `_play_anim(&"wake")` via the side-effect of the trace shim
	# being reachable — concretely, by ensuring the state-key mapping covers
	# STATE_WAKING (no MISS warning). Tier-1 visual primitive — pins the
	# state -> SpriteFrames key contract per `team/TESTING_BAR.md`.
	var b: Stratum1Boss = _make_dormant_boss()
	# Attach an AnimatedSprite2D child with the real SpriteFrames so
	# `_play_anim` resolves a real key.
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = _load_boss_frames()
	b.add_child(sprite)
	b.wake()
	# After wake(), `_set_state(STATE_WAKING)` runs and calls `_play_anim(&"wake")`.
	# The full key is `wake_<dir>` where dir defaults to "s" with no player.
	assert_eq(
		sprite.animation,
		StringName("wake_s"),
		"AnimatedSprite2D plays wake_s (default dir without player)"
	)
	assert_true(sprite.is_playing(), "AnimatedSprite2D is_playing() must be true after wake()")


func test_wake_animation_uses_facing_dir_when_player_present() -> void:
	# Faces the player on wake — same _compute_facing_dir_suffix contract as
	# walk/atk/slam/hit/die already use. Player to the east => wake_e.
	var b: Stratum1Boss = _make_dormant_boss()
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = _load_boss_frames()
	b.add_child(sprite)
	var p: Node2D = Node2D.new()
	add_child_autofree(p)
	p.global_position = Vector2(200, 0)  # east of boss at (0,0)
	b.set_player(p)
	b.wake()
	assert_eq(
		sprite.animation,
		StringName("wake_e"),
		"wake anim picks the direction toward the player (east)"
	)


# ---- C: Damage-immunity ---------------------------------------------


func test_damage_is_rejected_during_waking() -> void:
	# Load-bearing: catches the regression where someone adds STATE_WAKING but
	# forgets to extend the take_damage immunity guard. Without this gate, a
	# player swing landing in the first frame after wake() can kill the boss
	# before its standup animation has a chance to play.
	var b: Stratum1Boss = _make_dormant_boss()
	b.wake()
	assert_eq(b.get_state(), Stratum1Boss.STATE_WAKING, "precondition: WAKING")
	var hp_before: int = b.get_hp()
	b.take_damage(50, Vector2.ZERO, null)
	assert_eq(
		b.get_hp(),
		hp_before,
		"REGRESSION-86c9wjyp9: damage MUST be rejected during WAKING (immunity matches DORMANT)"
	)


func test_damage_lands_after_wake_window_closes() -> void:
	# Complement — once WAKING -> IDLE, damage must land. Catches the inverse
	# regression where someone over-extends the immunity guard and leaves the
	# boss un-killable.
	var b: Stratum1Boss = _make_dormant_boss()
	b.wake()
	for _i in 30:
		b._physics_process(0.016)
	assert_eq(b.get_state(), Stratum1Boss.STATE_IDLE, "precondition: IDLE")
	var hp_before: int = b.get_hp()
	b.take_damage(50, Vector2.ZERO, null)
	assert_lt(
		b.get_hp(),
		hp_before,
		"damage lands after the wake-anim window closes (boss IS killable in IDLE)"
	)


# ---- D: Room-level integration --------------------------------------


func test_room_entry_sequence_completes_into_idle_via_test_helper() -> void:
	# Pins the chain: Stratum1BossRoom.complete_entry_sequence_for_test()
	# fast-forwards through both the 1.8 s entry sequence AND the ~417 ms
	# wake-anim window. Without the chain, 8+ downstream integration tests
	# (test_boss_wakes_and_engages, test_boss_loot_integration, etc.) would
	# need per-test wake-tick simulation. The chain keeps the surface area
	# of T8 contained.
	var packed: PackedScene = load("res://scenes/levels/Stratum1BossRoom.tscn")
	var room: Stratum1BossRoom = packed.instantiate()
	add_child_autofree(room)
	var boss: Stratum1Boss = room.get_boss()
	await get_tree().process_frame  # let deferred trigger land
	room.complete_entry_sequence_for_test()
	assert_eq(
		boss.get_state(),
		Stratum1Boss.STATE_IDLE,
		"complete_entry_sequence_for_test chains into complete_wake_for_test, landing in IDLE"
	)
