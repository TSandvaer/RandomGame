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
	# Sanity: in the sweet-spot (KITE_RANGE..SHOOT_RANGE), velocity should
	# remain ZERO — the Shooter stands and aims, consistent with the design
	# intent for the sweet-spot band. Ticket 86c9uehaq tightened the sweet
	# spot from KITE_RANGE..AIM_RANGE (120..300) to KITE_RANGE..SHOOT_RANGE
	# (120..144) so the band matches actual projectile reach.
	var shooter: Shooter = _make_shooter(Vector2.ZERO)
	# 130 px: inside SHOOT_RANGE (144) and outside KITE_RANGE (120) = sweet-spot.
	var player: FakePlayer = _make_player(Vector2(130.0, 0.0))
	shooter.set_player(player)
	shooter._aim_left = Shooter.AIM_DURATION
	shooter._last_aim_dir = Vector2.RIGHT
	shooter._set_state(Shooter.STATE_AIMING)
	shooter._is_dead = false

	shooter._process_aiming(1.0 / 60.0)

	assert_eq(shooter.velocity, Vector2.ZERO,
		"Shooter must hold position in sweet-spot (KITE_RANGE..SHOOT_RANGE)")


# Regression guard for ticket 86c9uehaq Sponsor failure mode 3 ("out-of-range
# = no pursuit"). Pre-fix the close-the-gap threshold was AIM_RANGE (300 px),
# so a player standing at dist 200 — past projectile reach (144 px) but inside
# the old "sweet spot" — saw the shooter stand still firing un-reaching
# projectiles. Post-fix the threshold is SHOOT_RANGE (PROJECTILE_SPEED ×
# PROJECTILE_LIFETIME = 144 px) so any out-of-projectile-range player is
# actively pursued.
func test_shooter_pursues_when_player_past_projectile_reach() -> void:
	var shooter: Shooter = _make_shooter(Vector2.ZERO)
	# 200 px: past SHOOT_RANGE (144) but well inside AIM_RANGE (300).
	# Pre-fix this was "sweet spot, stand and fire un-reaching projectiles."
	# Post-fix this is "out of effective range, walk toward player."
	var player: FakePlayer = _make_player(Vector2(200.0, 0.0))
	shooter.set_player(player)
	shooter._aim_left = Shooter.AIM_DURATION
	shooter._last_aim_dir = Vector2.RIGHT
	shooter._set_state(Shooter.STATE_AIMING)
	shooter._is_dead = false

	shooter._process_aiming(1.0 / 60.0)

	assert_gt(shooter.velocity.x, 0.0,
		"REGRESSION CHECK (86c9uehaq Sponsor failure mode 3): Shooter must " +
		"close the gap (velocity.x > 0) when player is past SHOOT_RANGE but " +
		"inside the old AIM_RANGE — pre-fix stood still firing un-reaching shots.")
	assert_eq(shooter.velocity.length(), shooter.move_speed,
		"Pursuit speed must equal move_speed (no fractional)")


# Regression guard for ticket 86c9uehaq Sponsor failure mode 2 ("cornered =
# idle"). Pre-fix the kite state had no exit when wall-blocked and player
# still close — shooter stayed in KITING forever, velocity set every frame
# but move_and_slide produced no net motion. Post-fix two consecutive
# is_on_wall() ticks while still inside KITE_RANGE promote KITING -> AIMING
# with a short windup so the shooter fires in place.
func test_shooter_cornered_promotes_kiting_to_aiming() -> void:
	# Headless GUT can't wall-collide a CharacterBody2D, so we drive the
	# extracted `_promote_cornered_to_aiming` helper directly. The is_on_wall()
	# detection + tick-counter accumulation lives in `_process_kiting`; this
	# test pins the PROMOTION payload (state -> AIMING, aim_left shortened to
	# CORNERED_AIM_DURATION, attack-telegraph fired, aim_started signal emit).
	var shooter: Shooter = _make_shooter(Vector2.ZERO)
	# Player at 80px — inside KITE_RANGE (120).
	var player: FakePlayer = _make_player(Vector2(80.0, 0.0))
	shooter.set_player(player)
	shooter._set_state(Shooter.STATE_KITING)
	shooter._is_dead = false
	shooter._cornered_kite_ticks = Shooter.CORNERED_KITE_TICKS_TO_FIRE

	watch_signals(shooter)
	shooter._promote_cornered_to_aiming(80.0)

	assert_eq(shooter.get_state(), Shooter.STATE_AIMING,
		"REGRESSION CHECK (86c9uehaq Sponsor failure mode 2): cornered kite " +
		"promotion must transition to AIMING — pre-fix kiting had no exit " +
		"when wall-blocked + player close, so shooter froze indefinitely.")
	assert_almost_eq(shooter._aim_left, Shooter.CORNERED_AIM_DURATION, 0.001,
		"Cornered windup uses CORNERED_AIM_DURATION (fast) not AIM_DURATION " +
		"(normal) — player is right there, normal 0.55s windup feels idle.")
	assert_eq(shooter._cornered_kite_ticks, 0,
		"Cornered-tick counter must reset on promotion.")
	assert_eq(shooter.velocity, Vector2.ZERO,
		"Cornered AIMING starts with zero velocity — shooter is wall-blocked, " +
		"don't keep trying to retreat.")
	assert_signal_emitted(shooter, "aim_started",
		"Cornered promotion must emit aim_started so visual hooks fire the " +
		"telegraph (red glow on Sprite). Without this the cornered fallback " +
		"looks identical to standing idle.")


# Regression guard for ticket 86c9uehaq Sponsor failure mode 2 (cornered
# constants discipline). CORNERED_KITE_TICKS_TO_FIRE controls how fast the
# fallback fires; CORNERED_AIM_DURATION controls how long the windup is.
# Tune drift in either direction makes the fallback either spam-prone (too
# fast) or invisible (too slow).
func test_shooter_cornered_constants_are_balanced() -> void:
	assert_eq(Shooter.CORNERED_KITE_TICKS_TO_FIRE, 2,
		"Cornered promotion must fire fast — 2 ticks ≈ 33 ms at 60 Hz keeps " +
		"the shooter from looking idle for more than a single visible frame.")
	assert_lt(Shooter.CORNERED_AIM_DURATION, Shooter.AIM_DURATION,
		"Cornered windup must be shorter than the normal aim windup — the " +
		"player is right there; a 0.55 s telegraph would feel like the shooter " +
		"is still idle.")
	assert_gt(Shooter.CORNERED_AIM_DURATION, 0.0,
		"Cornered windup must be > 0 so the player has SOME telegraph window " +
		"to react/dodge — zero-windup point-blank fire is unfair.")


# Regression guard for ticket 86c9uehaq Sponsor failure mode 2 (counter logic).
# When kiting succeeds (non-blocked tick), the cornered-tick counter must
# reset so a momentary single-tick wall graze does not accumulate toward
# false-positive cornered promotion.
func test_shooter_cornered_counter_resets_on_unblocked_kite_tick() -> void:
	var shooter: Shooter = _make_shooter(Vector2.ZERO)
	var player: FakePlayer = _make_player(Vector2(80.0, 0.0))
	shooter.set_player(player)
	shooter._set_state(Shooter.STATE_KITING)
	shooter._is_dead = false
	# Pre-condition: counter already accumulated some blocked ticks.
	shooter._cornered_kite_ticks = 1

	# Drive _process_kiting once. Without a real wall, is_on_wall() returns
	# false in headless GUT — the else-branch fires, resetting the counter.
	shooter._process_kiting(1.0 / 60.0)

	assert_eq(shooter._cornered_kite_ticks, 0,
		"Cornered-tick counter must reset on any non-blocked kite tick.")
	# And kiting velocity is set (away from player).
	assert_lt(shooter.velocity.x, 0.0,
		"Unblocked kite tick still sets retreat velocity.")


# Regression guard for ticket 86c9uehaq SHOOT_RANGE derivation. The constant
# must equal PROJECTILE_SPEED × PROJECTILE_LIFETIME so the sweet spot matches
# actual projectile reach. If a future tune changes projectile speed/lifetime,
# SHOOT_RANGE auto-tracks — but if someone hard-codes SHOOT_RANGE to a literal
# this test catches the divergence.
func test_shoot_range_equals_projectile_reach() -> void:
	var expected: float = Shooter.PROJECTILE_SPEED * Shooter.PROJECTILE_LIFETIME
	assert_almost_eq(Shooter.SHOOT_RANGE, expected, 0.001,
		"SHOOT_RANGE must equal PROJECTILE_SPEED × PROJECTILE_LIFETIME so the " +
		"sweet spot matches actual projectile reach (ticket 86c9uehaq).")
	# And SHOOT_RANGE must be < AIM_RANGE (sweet spot is narrower than aggro).
	assert_lt(Shooter.SHOOT_RANGE, Shooter.AIM_RANGE,
		"SHOOT_RANGE must be tighter than AIM_RANGE — otherwise no close-the-gap " +
		"region exists.")
	# And SHOOT_RANGE must be > KITE_RANGE so a non-empty sweet spot exists.
	assert_gt(Shooter.SHOOT_RANGE, Shooter.KITE_RANGE,
		"SHOOT_RANGE must be greater than KITE_RANGE — otherwise the sweet spot " +
		"is empty and the shooter can never stand and fire.")


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


# ===========================================================================
# SHARPENED TESTS — P0 #2 regression (build embergrave-html5-356086a)
# The original Bug 3 fix only added close-the-gap to AIMING state. The
# missing piece: POST_FIRE_RECOVERY also held velocity=ZERO, meaning the
# Shooter only closed the gap ~27px/s effective (33px over 0.55s AIMING,
# then 0px over 0.65s POST_FIRE_RECOVERY). Fix: also close the gap in
# POST_FIRE_RECOVERY when dist > AIM_RANGE. These tests would have FAILED
# pre-fix and now PASS with the P0 #2 fix.
# ===========================================================================

## P0 #2 core: POST_FIRE_RECOVERY walks toward player when dist > AIM_RANGE.
## Pre-fix this was velocity=ZERO unconditionally in _process_post_fire.
func test_p0_shooter_closes_gap_during_post_fire_recovery() -> void:
	var shooter: Shooter = _make_shooter(Vector2.ZERO)
	var player: FakePlayer = _make_player(Vector2(400.0, 0.0))
	# 400 px >> AIM_RANGE (300 px). Recovery timer still active (non-zero).
	shooter.set_player(player)
	shooter._post_fire_recovery_left = Shooter.POST_FIRE_RECOVERY  # timer still running
	shooter._set_state(Shooter.STATE_POST_FIRE_RECOVERY)
	shooter._is_dead = false

	shooter._process_post_fire(1.0 / 60.0)

	assert_gt(shooter.velocity.x, 0.0,
		"REGRESSION CHECK (P0 #2): Shooter must walk toward player (velocity.x > 0) " +
		"during POST_FIRE_RECOVERY when dist > AIM_RANGE. Pre-fix: velocity=ZERO.")
	assert_gt(shooter.velocity.length(), 0.0,
		"velocity must be non-zero during POST_FIRE_RECOVERY when out of sweet-spot")


## P0 #2: POST_FIRE_RECOVERY holds position when player is in sweet-spot (KITE_RANGE..AIM_RANGE).
func test_p0_post_fire_recovery_holds_position_in_sweet_spot() -> void:
	var shooter: Shooter = _make_shooter(Vector2.ZERO)
	var player: FakePlayer = _make_player(Vector2(200.0, 0.0))
	# 200 px: sweet-spot (KITE_RANGE=120 < 200 < AIM_RANGE=300).
	shooter.set_player(player)
	shooter._post_fire_recovery_left = Shooter.POST_FIRE_RECOVERY
	shooter._set_state(Shooter.STATE_POST_FIRE_RECOVERY)
	shooter._is_dead = false

	shooter._process_post_fire(1.0 / 60.0)

	assert_eq(shooter.velocity, Vector2.ZERO,
		"Shooter holds position during POST_FIRE_RECOVERY when player is in sweet-spot")


## P0 #2 worst-case far-corner scenario: shooter at one corner, player at the
## opposite end with a gap MUCH larger than one cycle can close. This forces
## both AIMING and POST_FIRE_RECOVERY to spend the full cycle closing the gap
## (neither phase reaches AIM_RANGE before the cycle ends, so velocity stays
## non-zero throughout both). This isolates and measures the post-fix behavior
## that PR #155 is required to deliver.
##
## Pre-fix: AIMING closes ~33px, POST_FIRE_RECOVERY closes 0px (held ZERO),
## gap_closed ≈ 33px per cycle.
## Post-fix: both AIMING (33px) and POST_FIRE_RECOVERY (~38px over its 0.65s
## window when dist stays > AIM_RANGE), gap_closed ≈ 71px per cycle.
##
## Tess bounce #1 fix: enabled test_skip_projectile_spawn so the FIRING tick
## doesn't side-effect-add a Projectile node into the test tree (which stalled
## the simulation in headless GUT context). Drop straight into STATE_AIMING
## with timer primed so we measure exactly the close-the-gap behavior across
## the full aim+recovery cycle. Choose the initial gap so neither phase
## individually reaches AIM_RANGE within its window — otherwise the post-fix
## velocity drops to ZERO once dist <= AIM_RANGE and the test under-measures
## the recovery contribution. For 1.2s at 60px/s movement = 72px potential;
## start with dist=500 (>> 300+72) so the gap is never below AIM_RANGE during
## the cycle, exposing the full velocity contribution from BOTH phases.
func test_p0_far_corner_scenario_shooter_closes_gap_over_full_cycle() -> void:
	# Choose an initial gap large enough that neither AIMING nor POST_FIRE_RECOVERY
	# alone reaches AIM_RANGE. dist=500 > AIM_RANGE+full-cycle-movement (~372).
	var shooter: Shooter = _make_shooter(Vector2(500.0, 96.0))
	var player: FakePlayer = _make_player(Vector2(0.0, 96.0))
	# Initial distance: 500px. After 72 ticks at 60px/s = 72px movement,
	# dist ends at ~428px — still >> AIM_RANGE (300), so velocity is non-zero
	# throughout the entire cycle and we measure the full close-gap contribution.
	shooter.set_player(player)
	shooter._is_dead = false
	# Skip the real Projectile spawn — state machine still advances FIRING →
	# POST_FIRE_RECOVERY via the caller, but no scene-tree side effects.
	shooter.test_skip_projectile_spawn = true
	# Skip SPOTTED entirely: drop straight into AIMING with the timer primed.
	# This isolates the test to the aim+recovery cycle, removing the 0.15s
	# SPOTTED_HOLD from the budget so all 72 ticks measure close-gap behavior.
	shooter._aim_left = Shooter.AIM_DURATION
	shooter._last_aim_dir = (player.global_position - shooter.global_position).normalized()
	shooter._set_state(Shooter.STATE_AIMING)

	var start_x: float = shooter.global_position.x
	var delta: float = 1.0 / 60.0
	# 72 ticks = 1.2s = one full aim+recovery cycle (0.55s AIMING + 0.65s recovery).
	for _i: int in range(72):
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
		shooter.global_position += shooter.velocity * delta

	var end_x: float = shooter.global_position.x
	var gap_closed: float = start_x - end_x  # positive means moved toward player (west)

	# Pre-fix: gap_closed ≈ 33px (only AIMING window, recovery=ZERO).
	# Post-fix: gap_closed ≈ 71px (both AIMING + RECOVERY at 60px/s).
	# Assert > 50px to clearly distinguish pre-fix (~33px) from post-fix (~71px),
	# allowing for state-transition single-tick gaps in the simulation.
	assert_gt(gap_closed, 50.0,
		"REGRESSION CHECK (P0 #2): Shooter must close > 50px gap in one full aim+recovery " +
		"cycle when the gap remains >> AIM_RANGE throughout. " +
		"Got gap_closed=%.1f px. Pre-fix would show ~33px (AIMING only — recovery held velocity=ZERO). " % gap_closed +
		"Post-fix expects ~71px (AIMING + POST_FIRE_RECOVERY both walk toward player at move_speed=60).")


## P0 #2: velocity direction during POST_FIRE_RECOVERY points toward player.
func test_p0_post_fire_recovery_velocity_direction_toward_player() -> void:
	var shooter: Shooter = _make_shooter(Vector2.ZERO)
	var player: FakePlayer = _make_player(Vector2(0.0, -400.0))
	# Player is directly north (negative y), dist=400 >> AIM_RANGE=300.
	shooter.set_player(player)
	shooter._post_fire_recovery_left = Shooter.POST_FIRE_RECOVERY
	shooter._set_state(Shooter.STATE_POST_FIRE_RECOVERY)
	shooter._is_dead = false

	shooter._process_post_fire(1.0 / 60.0)

	assert_almost_eq(shooter.velocity.x, 0.0, 1.0,
		"velocity.x should be ~0 (player is due north)")
	assert_lt(shooter.velocity.y, 0.0,
		"velocity.y must be negative (moving north toward player)")
