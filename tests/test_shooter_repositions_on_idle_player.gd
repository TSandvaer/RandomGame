extends GutTest
## Integration tests for the M1 RC Bug 3 fix (ticket 86c9q7xha):
## "Shooter corner-camps + casts fireballs without movement (confirmed Room 4)."
##
## Sponsor observation: Shooter (blue mob) retreats to a corner and repeatedly
## fires projectiles that don't reach the player (who stands in the opposite
## corner). The Shooter never transitions back to CHASE and no pressure exists.
##
## Root cause: the AIMING state held velocity=ZERO unconditionally. When the
## player was > AIM_RANGE (300 px) away, the Shooter aimed and fired a
## projectile that traveled PROJECTILE_SPEED × PROJECTILE_LIFETIME = 90 × 1.6
## = 144 px — well short of a 400+ px gap. After POST_FIRE_RECOVERY,
## _pick_post_recovery_state() returned to AIMING (dist > KITE_RANGE), and the
## cycle repeated forever with zero movement.
##
## Fix: in _process_aiming(), when dist > AIM_RANGE, walk toward the player at
## move_speed so the Shooter closes the gap between aim pulses. The aim timer
## still ticks during the walk so the shot fires when the timer expires even if
## the gap is not yet closed.
##
## These tests use a real Shooter + real FakePlayer Node2D (Player-shaped node
## with global_position) to exercise the actual state machine, per the
## "stub-Node tests silently miss integration surface bugs" lesson from
## combat-architecture.md § "Equipped-weapon dual-surface rule".

const ShooterScript: Script = preload("res://scripts/mobs/Shooter.gd")
const MobDefScript: Script = preload("res://scripts/content/MobDef.gd")
const ContentFactory: GDScript = preload("res://tests/factories/content_factory.gd")


# ---- Helpers -----------------------------------------------------------

class FakePlayer:
	extends Node2D
	# Positioned anywhere in world space via global_position. The Shooter's
	# _resolve_player uses group "player"; we set_player() directly in helpers.


func _make_shooter(pos: Vector2 = Vector2.ZERO) -> Shooter:
	var s: Shooter = ShooterScript.new()
	s.set_physics_process(false)  # manual-tick mode — deterministic tests
	add_child_autofree(s)
	s.global_position = pos
	return s


func _make_player(pos: Vector2 = Vector2.ZERO) -> FakePlayer:
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	p.global_position = pos
	return p


func _tick_shooter(s: Shooter, delta: float, ticks: int) -> void:
	for _i: int in range(ticks):
		s._physics_process(delta)


# ---- 1. AIMING state closes the gap when player > AIM_RANGE ------------

func test_shooter_moves_toward_player_when_aiming_and_player_too_far() -> void:
	# Bug 3 core AC: when the Shooter is in AIMING state with the player
	# outside AIM_RANGE (300 px), the Shooter must walk toward the player
	# (velocity != ZERO). Pre-fix, velocity was ZERO unconditionally in AIMING.
	var shooter: Shooter = _make_shooter(Vector2.ZERO)
	var player: FakePlayer = _make_player(Vector2(400.0, 0.0))
	# 400 px > AIM_RANGE (300 px) → must close gap while aiming.
	shooter.set_player(player)

	# Manually transition to AIMING (skip IDLE/SPOTTED path for test isolation).
	shooter._aim_left = Shooter.AIM_DURATION
	shooter._last_aim_dir = Vector2.RIGHT
	shooter._set_state(Shooter.STATE_AIMING)
	shooter._is_dead = false

	# One physics tick — inspect velocity.
	shooter._process_aiming(1.0 / 60.0)

	assert_gt(shooter.velocity.x, 0.0,
		"Shooter must move toward player (velocity.x > 0) when player is " +
		"beyond AIM_RANGE during AIMING (Bug 3 fix)")
	assert_gt(shooter.velocity.length(), 0.0,
		"velocity must be non-zero when player is outside AIM_RANGE")


func test_shooter_holds_position_when_aiming_in_sweet_spot() -> void:
	# Sanity: in the sweet-spot (KITE_RANGE..AIM_RANGE), velocity should
	# remain ZERO — the Shooter stands and aims, consistent with the original
	# design intent for the sweet-spot band.
	var shooter: Shooter = _make_shooter(Vector2.ZERO)
	var player: FakePlayer = _make_player(Vector2(200.0, 0.0))
	# 200 px: inside AIM_RANGE (300) and outside KITE_RANGE (120) = sweet-spot.
	shooter.set_player(player)
	shooter._aim_left = Shooter.AIM_DURATION
	shooter._last_aim_dir = Vector2.RIGHT
	shooter._set_state(Shooter.STATE_AIMING)
	shooter._is_dead = false

	shooter._process_aiming(1.0 / 60.0)

	assert_eq(shooter.velocity, Vector2.ZERO,
		"Shooter must hold position in sweet-spot (KITE_RANGE..AIM_RANGE)")


func test_shooter_still_kites_when_player_too_close_during_aiming() -> void:
	# Pre-existing behaviour preserved: if player steps inside KITE_RANGE
	# during AIMING, the kite-interrupt fires.
	var shooter: Shooter = _make_shooter(Vector2.ZERO)
	var player: FakePlayer = _make_player(Vector2(50.0, 0.0))
	# 50 px < KITE_RANGE (120 px) → kite interrupt.
	shooter.set_player(player)
	shooter._aim_left = Shooter.AIM_DURATION
	shooter._last_aim_dir = Vector2.RIGHT
	shooter._set_state(Shooter.STATE_AIMING)
	shooter._is_dead = false

	shooter._process_aiming(1.0 / 60.0)

	assert_eq(shooter.get_state(), Shooter.STATE_KITING,
		"close-in player during AIMING must trigger kite-interrupt (pre-existing)")


# ---- 2. Shooter does NOT corner-camp with idle opposite-corner player ---

func test_shooter_closes_gap_after_repeated_fire_cycles() -> void:
	# Bug 3 integration AC: Shooter starts at one corner, player at the far end.
	# After N fire cycles, the Shooter must have moved CLOSER to the player
	# (not stayed frozen at its spawn corner).
	#
	# Room width is 480 px. Shooter at x=400, player at x=32 → distance ~368 px.
	# Pre-fix: Shooter loops SPOTTED→AIMING→FIRING→POST_FIRE_RECOVERY → back to
	# AIMING, with velocity=ZERO every tick → stays at x=400 indefinitely.
	# Post-fix: AIMING state walks toward player when dist > AIM_RANGE.
	var shooter: Shooter = _make_shooter(Vector2(400.0, 135.0))
	var player: FakePlayer = _make_player(Vector2(32.0, 135.0))
	shooter.set_player(player)
	shooter._is_dead = false

	var start_x: float = shooter.global_position.x
	# Manually push shooter through SPOTTED → AIMING to start the cycle.
	shooter._spotted_hold_left = 0.0
	shooter._set_state(Shooter.STATE_SPOTTED)

	# Run 120 physics ticks at 60fps = 2 seconds.
	# Each tick manually updates timers + state (physics_process disabled).
	var delta: float = 1.0 / 60.0
	for _i: int in range(120):
		# Tick timers manually (mirrors what _physics_process does before the match).
		shooter._tick_timers(delta)
		match shooter.get_state():
			Shooter.STATE_IDLE:
				shooter._process_idle(delta)
			Shooter.STATE_SPOTTED:
				shooter._process_spotted(delta)
			Shooter.STATE_AIMING:
				shooter._process_aiming(delta)
			Shooter.STATE_FIRING:
				shooter._process_firing(delta)
			Shooter.STATE_POST_FIRE_RECOVERY:
				shooter._process_post_fire(delta)
			Shooter.STATE_KITING:
				shooter._process_kiting(delta)
		# Apply velocity to position (move_and_slide not available headlessly,
		# so we apply velocity * delta directly — sufficient to test movement intent).
		shooter.global_position += shooter.velocity * delta

	var end_x: float = shooter.global_position.x
	# Shooter started at x=400, player is at x=32 (west).
	# Closer means x decreased toward 32.
	assert_lt(end_x, start_x,
		"Shooter must close the gap toward player (x decreased) during idle-player " +
		"scenario. Pre-fix: x=" + str(start_x) + " (frozen). Post-fix: x=" + str(end_x))


func test_shooter_approaches_player_who_is_at_maximum_room_diagonal() -> void:
	# Room 4 scenario: Sponsor stood in one corner while Shooter was in the
	# other. Maximum room size is 480×256 → diagonal ~547 px.
	# Shooter at (448, 32), player at (32, 224) → distance = sqrt(416^2+192^2)
	# ≈ 457 px >> AIM_RANGE (300 px).
	# After one AIMING tick, Shooter must have non-zero velocity toward player.
	var shooter: Shooter = _make_shooter(Vector2(448.0, 32.0))
	var player: FakePlayer = _make_player(Vector2(32.0, 224.0))
	shooter.set_player(player)
	shooter._aim_left = Shooter.AIM_DURATION
	shooter._last_aim_dir = (player.global_position - shooter.global_position).normalized()
	shooter._set_state(Shooter.STATE_AIMING)
	shooter._is_dead = false

	shooter._process_aiming(1.0 / 60.0)

	var vel_len: float = shooter.velocity.length()
	assert_gt(vel_len, 0.0,
		"Shooter must move toward player in max-diagonal corner-camp scenario " +
		"(dist ≈ 457 px >> AIM_RANGE 300 px)")
	# Velocity should point roughly toward player (negative x, positive y).
	assert_lt(shooter.velocity.x, 0.0,
		"velocity.x must be negative (moving west toward player)")
	assert_gt(shooter.velocity.y, 0.0,
		"velocity.y must be positive (moving south toward player)")


# ---- 3. Existing Shooter behaviours preserved (regression guards) -------

func test_shooter_kites_when_player_closes_in() -> void:
	# Pre-existing: player inside KITE_RANGE → kiting velocity is non-zero
	# and points AWAY from player.
	var shooter: Shooter = _make_shooter(Vector2.ZERO)
	var player: FakePlayer = _make_player(Vector2(60.0, 0.0))  # < KITE_RANGE
	shooter.set_player(player)
	shooter._set_state(Shooter.STATE_KITING)
	shooter._is_dead = false

	shooter._process_kiting(1.0 / 60.0)

	assert_lt(shooter.velocity.x, 0.0,
		"Shooter kites AWAY from player (velocity.x < 0 when player is east)")


func test_shooter_idles_outside_aggro_radius() -> void:
	# Pre-existing: player outside AGGRO_RADIUS → Shooter stays IDLE.
	var shooter: Shooter = _make_shooter(Vector2.ZERO)
	var player: FakePlayer = _make_player(Vector2(600.0, 0.0))  # > AGGRO_RADIUS (480)
	shooter.set_player(player)
	shooter._set_state(Shooter.STATE_IDLE)
	shooter._is_dead = false

	shooter._process_idle(1.0 / 60.0)

	assert_eq(shooter.get_state(), Shooter.STATE_IDLE,
		"player beyond AGGRO_RADIUS must not trigger SPOTTED from IDLE")


func test_post_fire_recovery_transitions_to_aiming_when_player_in_aggro_radius() -> void:
	# Pre-existing: after POST_FIRE_RECOVERY completes, shooter re-engages.
	# With the Bug 3 fix, AIMING now closes the gap — but the transition
	# from POST_FIRE_RECOVERY to AIMING still fires, and AIMING still fires
	# the shot eventually. Regression: verify POST_FIRE_RECOVERY→AIMING path.
	var shooter: Shooter = _make_shooter(Vector2.ZERO)
	var player: FakePlayer = _make_player(Vector2(200.0, 0.0))  # in sweet-spot
	shooter.set_player(player)
	shooter._post_fire_recovery_left = 0.0  # recovery expired
	shooter._set_state(Shooter.STATE_POST_FIRE_RECOVERY)
	shooter._is_dead = false

	shooter._process_post_fire(1.0 / 60.0)

	assert_eq(shooter.get_state(), Shooter.STATE_AIMING,
		"post-fire recovery must transition to AIMING (re-engage) when player in range")


func test_shooter_returns_to_idle_after_fire_cycle_when_player_leaves_aggro() -> void:
	# Pre-existing: after POST_FIRE_RECOVERY with player beyond AGGRO_RADIUS
	# → transitions to IDLE (not stuck in AIMING).
	var shooter: Shooter = _make_shooter(Vector2.ZERO)
	var player: FakePlayer = _make_player(Vector2(600.0, 0.0))  # > AGGRO_RADIUS
	shooter.set_player(player)
	shooter._post_fire_recovery_left = 0.0
	shooter._set_state(Shooter.STATE_POST_FIRE_RECOVERY)
	shooter._is_dead = false

	shooter._process_post_fire(1.0 / 60.0)

	assert_eq(shooter.get_state(), Shooter.STATE_IDLE,
		"shooter must return to IDLE when player leaves AGGRO_RADIUS post-recovery")
