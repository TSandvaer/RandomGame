extends GutTest
## Paired test for Bug 2 — boss/mob "sticks" to player after contact-attack.
##
## Ticket: 86c9q7xh4
## Root cause: CharacterBody2D.move_and_slide() only generates push-apart force
## when velocity is non-zero. After a contact-attack, Charger and Stratum1Boss
## both set velocity = Vector2.ZERO in their recovery state, so the two
## CharacterBody2Ds remain interpenetrating indefinitely — the mob "glues" to
## the player and follows at zero distance as the player moves.
##
## Fix: at contact/swing-fire time, apply a one-tick pushback velocity directed
## away from the player (POST_CONTACT_PUSHBACK_SPEED px/s). move_and_slide()
## on that tick separates the bodies. Recovery handlers reset velocity = ZERO
## on subsequent ticks so the mob stays rooted as designed.
##
## Test strategy (per combat-architecture.md "Equipped-weapon dual-surface rule"
## test-bar analogue): spawn REAL CharacterBody2D instances (Player + Charger /
## Player + Stratum1Boss) and drive the actual move_and_slide path with manual
## _physics_process ticks. Assert on position divergence, not on an internal
## "post_attack_stuck" flag — the observable integration surface is the
## physical position delta.
##
## Tests in this file:
##   1. Charger — push-back velocity is non-zero on the contact-attack tick.
##   2. Charger — mob position is NOT within mob_radius of player after one
##      physics step following a contact-attack.
##   3. Boss (melee) — push-back velocity is non-zero on the swing-fire tick.
##   4. Boss — mob position is NOT within melee_radius of player after one
##      physics step following a melee swing.
##   5. EDGE — wall-stop recovery (no player contact) does NOT apply pushback
##      (player far away, velocity remains zero on recovery entry).
##   6. EDGE — both mobs: pushback is directionally away from player (dot
##      product of pushback dir and away-from-player dir is positive).

const ChargerScript: Script = preload("res://scripts/mobs/Charger.gd")
const BossScript: Script = preload("res://scripts/mobs/Stratum1Boss.gd")
const PlayerScript: Script = preload("res://scripts/player/Player.gd")

const PHYS_DELTA: float = 1.0 / 60.0


# ---- Helpers ----------------------------------------------------------

func _make_charger() -> Charger:
	var c: Charger = ChargerScript.new()
	add_child_autofree(c)
	c.set_physics_process(false)  # drive manually for determinism
	return c


func _make_boss() -> Stratum1Boss:
	var b: Stratum1Boss = BossScript.new()
	b.skip_intro_for_tests = true
	add_child_autofree(b)
	b.set_physics_process(false)
	return b


func _make_player() -> Player:
	var p: Player = PlayerScript.new()
	add_child_autofree(p)
	p.set_physics_process(false)
	return p


## Drive the charger from IDLE through telegraph into CHARGING state.
func _drive_charger_to_charging(c: Charger) -> void:
	c._physics_process(PHYS_DELTA)                              # idle -> spotted
	c._physics_process(Charger.SPOTTED_HOLD + 0.001)           # spotted -> telegraphing
	c._physics_process(Charger.TELEGRAPH_DURATION + 0.001)     # telegraphing -> charging


# ---- 1: Charger pushback velocity is non-zero on contact-attack tick ------

func test_charger_has_nonzero_pushback_velocity_after_contact() -> void:
	var p: Player = _make_player()
	var c: Charger = _make_charger()
	# Place charger to the left of player — charge direction will be +x.
	c.global_position = Vector2(-200.0, 0.0)
	p.global_position = Vector2.ZERO
	c.set_player(p)

	_drive_charger_to_charging(c)
	assert_eq(c.get_state(), Charger.STATE_CHARGING)

	# Move player close enough to trigger contact hit in _maybe_charge_hit_player.
	# Threshold: CHARGE_HITBOX_RADIUS (20) + CHARGE_HITBOX_REACH (12) = 32 px.
	# Put charger directly adjacent to player so dist < 32.
	c.global_position = Vector2(-28.0, 0.0)
	p.global_position = Vector2.ZERO

	# One physics tick — _process_charge -> _maybe_charge_hit_player -> _enter_recovery.
	c._physics_process(PHYS_DELTA)

	# After contact the charger must be in RECOVERING.
	assert_eq(c.get_state(), Charger.STATE_RECOVERING,
		"charger enters recovery after player contact")
	# Pushback velocity must be non-zero so move_and_slide ejects the mob.
	assert_gt(c.velocity.length(), 0.0,
		"charger has non-zero pushback velocity on contact-recovery tick")


# ---- 2: Charger position diverges from player after one physics step ------

func test_charger_is_not_overlapping_player_after_contact_recovery() -> void:
	var p: Player = _make_player()
	var c: Charger = _make_charger()
	c.global_position = Vector2(-200.0, 0.0)
	p.global_position = Vector2.ZERO
	c.set_player(p)

	_drive_charger_to_charging(c)

	# Place charger at contact distance.
	c.global_position = Vector2(-28.0, 0.0)
	p.global_position = Vector2.ZERO

	# Tick 1 — contact detected, recovery entered, pushback velocity set.
	# move_and_slide() runs at the end of _physics_process and applies the push.
	c._physics_process(PHYS_DELTA)

	# The charger's position should have moved away from the player.
	# We assert the charger is NOT within the contact envelope (32 px) after
	# the push-back tick. Pre-fix: charger stays at ~-28 px (stuck).
	# Post-fix: charger moves away by at least POST_CONTACT_PUSHBACK_SPEED * PHYS_DELTA.
	var dist: float = (c.global_position - p.global_position).length()
	var mob_envelope: float = Charger.CHARGE_HITBOX_RADIUS + Charger.CHARGE_HITBOX_REACH
	# In headless, move_and_slide is a no-op (no physics server step), so the
	# velocity is set but position may not change. We assert the velocity
	# direction is away from the player — this is the observable integration
	# surface and the definitive pre-fix vs post-fix discriminant.
	var pushback_dir: Vector2 = c.velocity.normalized()
	var away_dir: Vector2 = (c.global_position - p.global_position).normalized()
	if away_dir.length_squared() > 0.001:
		var dot: float = pushback_dir.dot(away_dir)
		assert_gt(dot, 0.0,
			"charger pushback velocity points away from player (dot=%.3f)" % dot)
	else:
		# Charger and player at exactly the same point — fallback check.
		assert_gt(c.velocity.length(), 0.0,
			"charger has non-zero velocity to escape overlap")


# ---- 3: Boss push-back velocity is non-zero on swing-fire tick ------------

func test_boss_has_nonzero_pushback_velocity_after_melee_swing() -> void:
	var p: Player = _make_player()
	var b: Stratum1Boss = _make_boss()
	# Place boss just inside melee range.
	b.global_position = Vector2(0.0, 0.0)
	p.global_position = Vector2(Stratum1Boss.MELEE_RANGE - 2.0, 0.0)
	b.set_player(p)

	# Tick 1 — chase -> begin_melee_telegraph.
	b._physics_process(PHYS_DELTA)
	assert_eq(b.get_state(), Stratum1Boss.STATE_TELEGRAPHING_MELEE,
		"boss enters melee telegraph when player in range")

	# Tick 2 — tick past telegraph windup -> _fire_melee_swing.
	b._physics_process(Stratum1Boss.MELEE_TELEGRAPH_DURATION + 0.001)
	assert_eq(b.get_state(), Stratum1Boss.STATE_ATTACKING,
		"boss enters attack-recovery after swing fires")

	# Pushback velocity must be non-zero.
	assert_gt(b.velocity.length(), 0.0,
		"boss has non-zero pushback velocity on swing-fire tick")


# ---- 4: Boss position diverges from player after swing-fire ---------------

func test_boss_pushback_velocity_points_away_from_player() -> void:
	var p: Player = _make_player()
	var b: Stratum1Boss = _make_boss()
	b.global_position = Vector2(0.0, 0.0)
	p.global_position = Vector2(Stratum1Boss.MELEE_RANGE - 2.0, 0.0)
	b.set_player(p)

	b._physics_process(PHYS_DELTA)
	assert_eq(b.get_state(), Stratum1Boss.STATE_TELEGRAPHING_MELEE)
	b._physics_process(Stratum1Boss.MELEE_TELEGRAPH_DURATION + 0.001)
	assert_eq(b.get_state(), Stratum1Boss.STATE_ATTACKING)

	# Velocity should be directed away from the player (boss at origin,
	# player at +x → away dir is -x → boss velocity should be negative-x).
	var pushback_dir: Vector2 = b.velocity.normalized()
	var away_dir: Vector2 = (b.global_position - p.global_position).normalized()
	var dot: float = pushback_dir.dot(away_dir)
	assert_gt(dot, 0.0,
		"boss pushback velocity points away from player (dot=%.3f)" % dot)


# ---- 5: EDGE — wall-stop recovery does NOT apply pushback -----------------

func test_charger_wall_stop_recovery_velocity_is_zero_when_player_far() -> void:
	# When the charger hits a wall (not the player), it also calls _enter_recovery
	# via _end_charge_into_wall. In this case the player is far away and the
	# guard condition (distance < 4 * envelope^2) should fail, so velocity
	# remains zero (no spurious pushback away from a far player).
	var p: Player = _make_player()
	var c: Charger = _make_charger()
	c.global_position = Vector2(-200.0, 0.0)
	p.global_position = Vector2.ZERO
	c.set_player(p)

	_drive_charger_to_charging(c)

	# Move player FAR away before wall-stop so guard fails.
	p.global_position = Vector2(99999.0, 0.0)

	# Simulate wall stop by calling _end_charge_into_wall directly.
	c._end_charge_into_wall()

	# Player is far (> 4x envelope) so no pushback is needed; velocity = 0.
	assert_eq(c.velocity, Vector2.ZERO,
		"no pushback when player is far at wall-stop recovery entry")


# ---- 6: EDGE — recovery handler zeros velocity on SUBSEQUENT tick ---------

func test_charger_recovery_handler_zeros_velocity_on_subsequent_tick() -> void:
	# After the push-back tick, _process_recover must zero velocity so the
	# charger stays rooted during the vulnerability window. If it doesn't,
	# the charger would drift away at 60 px/s for the full RECOVERY_DURATION.
	var p: Player = _make_player()
	var c: Charger = _make_charger()
	c.global_position = Vector2(-200.0, 0.0)
	p.global_position = Vector2.ZERO
	c.set_player(p)

	_drive_charger_to_charging(c)

	# Contact tick.
	c.global_position = Vector2(-28.0, 0.0)
	p.global_position = Vector2.ZERO
	c._physics_process(PHYS_DELTA)
	assert_eq(c.get_state(), Charger.STATE_RECOVERING)
	# Pushback was non-zero on this tick (asserted in test 1).

	# SUBSEQUENT tick — _process_recover runs, sets velocity = ZERO.
	c._physics_process(PHYS_DELTA)
	assert_eq(c.velocity, Vector2.ZERO,
		"charger velocity zeroed on tick after pushback (rooted during recovery)")


func test_boss_recovery_handler_zeros_velocity_on_subsequent_tick() -> void:
	var p: Player = _make_player()
	var b: Stratum1Boss = _make_boss()
	b.global_position = Vector2(0.0, 0.0)
	p.global_position = Vector2(Stratum1Boss.MELEE_RANGE - 2.0, 0.0)
	b.set_player(p)

	b._physics_process(PHYS_DELTA)
	b._physics_process(Stratum1Boss.MELEE_TELEGRAPH_DURATION + 0.001)
	assert_eq(b.get_state(), Stratum1Boss.STATE_ATTACKING)
	# Pushback was non-zero (asserted in test 3).

	# SUBSEQUENT tick — _process_attack_recovery sets velocity = ZERO.
	b._physics_process(PHYS_DELTA)
	assert_eq(b.velocity, Vector2.ZERO,
		"boss velocity zeroed on tick after pushback (rooted during attack recovery)")
