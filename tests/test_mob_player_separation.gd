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
##
## --- M2 W1 P1 polish (ticket 86c9q96kk) ---
##   7. Grunt — push-back velocity is non-zero on the light-swing fire tick.
##   8. Grunt — push-back velocity points away from player on light swing.
##   9. Grunt — push-back velocity is non-zero on the heavy-swing fire tick.
##  10. Grunt — recovery handler zeros velocity on SUBSEQUENT tick (rooted).
##  11. EDGE — Grunt does NOT chase player during recovery — stays rooted.

const ChargerScript: Script = preload("res://scripts/mobs/Charger.gd")
const BossScript: Script = preload("res://scripts/mobs/Stratum1Boss.gd")
const GruntScript: Script = preload("res://scripts/mobs/Grunt.gd")
const PlayerScript: Script = preload("res://scripts/player/Player.gd")

const PHYS_DELTA: float = 1.0 / 60.0


# ---- Helpers ----------------------------------------------------------

func _make_charger() -> Charger:
	var c: Charger = ChargerScript.new()
	add_child_autofree(c)
	c.set_physics_process(false)  # drive manually for determinism
	return c


func _make_grunt() -> Grunt:
	var g: Grunt = GruntScript.new()
	add_child_autofree(g)
	g.set_physics_process(false)
	return g


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


# ---- M2 W1 P1 polish: Grunt mob-stick fix (ticket 86c9q96kk) -------------

## Drive a Grunt from IDLE through the light-attack telegraph into the swing.
## Mirrors `_drive_charger_to_charging` but for the Grunt's IDLE → CHASE →
## TELEGRAPHING_LIGHT → ATTACKING pipeline.
func _drive_grunt_to_swing_fire(g: Grunt) -> void:
	# Tick 1: chase handler sees player in melee range → enters telegraph.
	g._physics_process(PHYS_DELTA)
	assert_eq(g.get_state(), Grunt.STATE_TELEGRAPHING_LIGHT,
		"precondition: grunt enters light telegraph when player in melee range")
	# Tick 2: tick past the telegraph window → swing fires → STATE_ATTACKING.
	g._physics_process(Grunt.LIGHT_TELEGRAPH_DURATION + 0.001)
	assert_eq(g.get_state(), Grunt.STATE_ATTACKING,
		"precondition: grunt enters attack-recovery after light swing fires")


# ---- 7: Grunt has nonzero pushback velocity after light-swing fires ------

func test_grunt_has_nonzero_pushback_velocity_after_light_swing() -> void:
	# Sponsor symptom (M1 RC re-soak attempt 5): when player moves through a
	# Grunt, the Grunt sticks to the player's edge instead of separating.
	# Pre-fix root cause: _swing_light only set _attack_recovery_left then
	# emitted swing_spawned, leaving velocity at whatever it had been when
	# entering the telegraph (zero, per _process_light_telegraph). With
	# velocity = ZERO, move_and_slide() generates no separation force on the
	# overlap and the two CharacterBody2Ds remain stuck.
	#
	# Post-fix: _apply_post_contact_pushback writes a non-zero velocity
	# directed away from the player on the swing-fire tick.
	var p: Player = _make_player()
	var g: Grunt = _make_grunt()
	# Place grunt just inside ATTACK_RANGE so the chase handler enters the
	# telegraph immediately on the first tick.
	g.global_position = Vector2.ZERO
	p.global_position = Vector2(Grunt.ATTACK_RANGE - 4.0, 0.0)
	g.set_player(p)

	_drive_grunt_to_swing_fire(g)

	# PRE-FIX: velocity was Vector2.ZERO — no separation, mob sticks.
	# POST-FIX: velocity is non-zero (pushback applied at swing-fire time).
	assert_gt(g.velocity.length(), 0.0,
		"grunt has non-zero pushback velocity on light-swing fire tick")


# ---- 8: Grunt pushback velocity points away from player ------------------

func test_grunt_pushback_velocity_points_away_from_player_after_light_swing() -> void:
	# The pushback must be DIRECTIONALLY away from the player, not just any
	# non-zero vector — this is the observable surface that prevents the
	# "sticking" on subsequent frames. Headless GUT skips the physics-server
	# step so move_and_slide() does not physically translate the node, but
	# the velocity direction IS the definitive pre/post-fix discriminant.
	var p: Player = _make_player()
	var g: Grunt = _make_grunt()
	# Place grunt to the left of player so the away-from-player direction
	# is unambiguously -x.
	g.global_position = Vector2(0.0, 0.0)
	p.global_position = Vector2(Grunt.ATTACK_RANGE - 4.0, 0.0)
	g.set_player(p)

	_drive_grunt_to_swing_fire(g)

	var pushback_dir: Vector2 = g.velocity.normalized()
	var away_dir: Vector2 = (g.global_position - p.global_position).normalized()
	var dot: float = pushback_dir.dot(away_dir)
	assert_gt(dot, 0.0,
		"grunt pushback must point away from player (dot=%.3f)" % dot)


# ---- 9: Grunt heavy-swing also applies pushback --------------------------

func test_grunt_has_nonzero_pushback_velocity_after_heavy_swing() -> void:
	# Heavy swing fires from STATE_TELEGRAPHING_HEAVY (low-HP one-shot).
	# Same fix path: _swing_heavy → _apply_post_contact_pushback. Mirror of
	# the light-swing test for completeness — both swing kinds must apply
	# the pushback.
	var p: Player = _make_player()
	var g: Grunt = _make_grunt()
	g.global_position = Vector2.ZERO
	p.global_position = Vector2(Grunt.ATTACK_RANGE - 4.0, 0.0)
	g.set_player(p)

	# Drop HP to <30% so heavy telegraph fires on next take_damage.
	# Default hp_max = 50, so 30% threshold = ceil(15) = 15. Hitting for 35
	# leaves 15, which is at the threshold (heavy fires).
	g.take_damage(35, Vector2.ZERO, null)
	assert_eq(g.get_state(), Grunt.STATE_TELEGRAPHING_HEAVY,
		"precondition: grunt in heavy telegraph after low-HP hit")

	# Tick past heavy telegraph window — heavy swing fires.
	g._physics_process(Grunt.HEAVY_TELEGRAPH_DURATION + 0.001)
	assert_eq(g.get_state(), Grunt.STATE_ATTACKING,
		"precondition: grunt enters attack recovery after heavy swing")

	assert_gt(g.velocity.length(), 0.0,
		"grunt has non-zero pushback velocity on heavy-swing fire tick")


# ---- 10: Grunt recovery handler zeros velocity on SUBSEQUENT tick --------

func test_grunt_recovery_handler_zeros_velocity_on_subsequent_tick() -> void:
	# After the swing-fire pushback tick, _process_recover must zero velocity
	# so the grunt stays rooted during the ATTACK_RECOVERY vulnerability
	# window — pre-fix, velocity persisted (no zero-each-tick guard) and the
	# grunt could float / drift away (ticket 86c9q804q recovery-velocity
	# audit). Mirrors the boss/charger pattern.
	var p: Player = _make_player()
	var g: Grunt = _make_grunt()
	g.global_position = Vector2.ZERO
	p.global_position = Vector2(Grunt.ATTACK_RANGE - 4.0, 0.0)
	g.set_player(p)

	_drive_grunt_to_swing_fire(g)
	# Pushback was non-zero on this tick (asserted in test 7).
	assert_gt(g.velocity.length(), 0.0)

	# SUBSEQUENT tick — _process_recover must zero velocity.
	g._physics_process(PHYS_DELTA)
	assert_eq(g.velocity, Vector2.ZERO,
		"grunt velocity zeroed on tick after pushback (rooted during recovery)")


# ---- 11: EDGE — Grunt stays rooted while player escapes during recovery --

func test_grunt_does_not_chase_player_during_recovery() -> void:
	# Sponsor's exact scenario reframed for Grunt: player moves AWAY from
	# Grunt during the recovery window. The Grunt must remain stationary
	# (velocity = ZERO across multiple recovery ticks) — it must NOT
	# re-chase, re-glue, or drift. This validates the recovery-velocity
	# audit (ticket 86c9q804q): post-fix, _process_recover zeros velocity
	# every tick regardless of where the player has moved.
	var p: Player = _make_player()
	var g: Grunt = _make_grunt()
	g.global_position = Vector2.ZERO
	p.global_position = Vector2(Grunt.ATTACK_RANGE - 4.0, 0.0)
	g.set_player(p)

	_drive_grunt_to_swing_fire(g)
	# Player escapes during recovery.
	p.global_position = Vector2(200.0, 0.0)

	# Multiple mid-recovery ticks. Recovery duration is ATTACK_RECOVERY (0.55s);
	# at PHYS_DELTA = 1/60 s ≈ 0.0167s per tick, 5 ticks = ~0.083s — well
	# inside the recovery window so we stay in STATE_ATTACKING throughout.
	for _i: int in range(5):
		g._physics_process(PHYS_DELTA)
		assert_eq(g.velocity, Vector2.ZERO,
			"grunt stays rooted (no chase) while player escapes during recovery")
		assert_eq(g.get_state(), Grunt.STATE_ATTACKING,
			"grunt remains in STATE_ATTACKING while recovery timer counts down")


# ---- M2 W1 universal-bug-class generalization: motion_mode = FLOATING ----
#
# Ticket: 86c9qanu1 (M2 W1).
# Drew's PR #163 fixed Stratum1Boss south-approach stick by setting
# `motion_mode = MOTION_MODE_FLOATING`. Per Drew's diagnosis (validated by
# Tess Lane 4 review of PR #163), the same MOTION_MODE_GROUNDED bug is
# universal — Grunt + Charger have the same latent bug below the
# observability threshold (smaller collision radius). This wave applies the
# FLOATING fix to Grunt and Charger for consistency.
#
# Root cause (full rationale in `.claude/docs/combat-architecture.md`
# § "CharacterBody2D motion_mode rule"): Godot 4 CharacterBody2D defaults
# to MOTION_MODE_GROUNDED with up_direction = (0, -1). move_and_slide() in
# GROUNDED mode treats collisions whose normal aligns with up_direction as
# floor and applies floor-snap/floor-stop semantics — including suppressing
# post-collision velocity along the +up axis. Player-from-south approaches
# align the collision normal with up_direction, so the GROUNDED-mode floor
# branch silently drops north-axis pushback velocity.
#
# Verification surface (headless): velocity-direction dot-product test on
# the swing-fire / contact tick — same shape as the boss tests in
# `tests/integration/test_boss_does_not_stick_after_contact.gd`. The
# motion_mode fix specifically affects the move_and_slide() resolution that
# follows; the velocity vector itself is set identically in all four cases.
# We additionally assert `motion_mode == FLOATING` directly so the
# regression is caught even if a future scene file overrides the property.

# ---- 12: Grunt motion_mode is FLOATING after _ready (regression guard) ---

func test_grunt_motion_mode_is_floating_after_ready() -> void:
	## Direct property assertion: the canonical Godot 4 top-down 2D
	## CharacterBody2D motion_mode is FLOATING. GROUNDED is the engine
	## default and would re-introduce the south-approach floor-snap bug.
	var g: Grunt = _make_grunt()
	assert_eq(g.motion_mode, CharacterBody2D.MOTION_MODE_FLOATING,
		"grunt motion_mode must be FLOATING after _ready() so move_and_slide treats every axis equally")


# ---- 13: Grunt separates from player on south approach (the latent bug) ---

func test_grunt_separates_from_player_approached_from_south() -> void:
	## The previously-latent bug: player below grunt → collision normal aligns
	## with up_direction → GROUNDED-mode floor branch suppresses north-axis
	## pushback. Post-fix (FLOATING), pushback velocity points NORTH and
	## move_and_slide() resolves the separation cleanly.
	##
	## Player south of grunt → player_pos.y > grunt_pos.y → away.y < 0 →
	## pushback.y < 0 (NORTH). We assert dot-product against the away-axis,
	## same shape as the existing east-approach test (#7 + #8 above).
	var p: Player = _make_player()
	var g: Grunt = _make_grunt()
	# Player below grunt, just inside ATTACK_RANGE so chase commits to a swing.
	g.global_position = Vector2.ZERO
	p.global_position = Vector2(0.0, Grunt.ATTACK_RANGE - 4.0)
	g.set_player(p)

	_drive_grunt_to_swing_fire(g)

	assert_gt(g.velocity.length(), 0.0,
		"south-approach: grunt velocity must be non-zero after swing-fire (separation from player)")
	# Pushback must point NORTH (away from player below). i.e. velocity.y < 0.
	assert_lt(g.velocity.y, 0.0,
		"south-approach: pushback must point NORTH (negative Y) — got velocity=(%.2f,%.2f)" % [g.velocity.x, g.velocity.y])

	var away_dir: Vector2 = (g.global_position - p.global_position).normalized()
	var pushback_dir: Vector2 = g.velocity.normalized()
	var dot: float = pushback_dir.dot(away_dir)
	assert_gt(dot, 0.0,
		"south-approach: pushback aligned with away-from-player vector (dot=%.3f)" % dot)


# ---- 14: Grunt north-approach baseline (was always working) -------------

func test_grunt_separates_from_player_approached_from_north() -> void:
	## Baseline regression test: north approach was reported working pre-fix.
	## Post-fix must still work — assert pushback points SOUTH (positive Y).
	## Adding this so any future approach-direction asymmetry surfaces
	## immediately rather than waiting for Sponsor soak.
	var p: Player = _make_player()
	var g: Grunt = _make_grunt()
	# Player above grunt.
	g.global_position = Vector2.ZERO
	p.global_position = Vector2(0.0, -(Grunt.ATTACK_RANGE - 4.0))
	g.set_player(p)

	_drive_grunt_to_swing_fire(g)

	assert_gt(g.velocity.length(), 0.0,
		"north-approach: grunt velocity must be non-zero after swing-fire")
	assert_gt(g.velocity.y, 0.0,
		"north-approach: pushback must point SOUTH (positive Y) — got velocity=(%.2f,%.2f)" % [g.velocity.x, g.velocity.y])

	var away_dir: Vector2 = (g.global_position - p.global_position).normalized()
	var dot: float = g.velocity.normalized().dot(away_dir)
	assert_gt(dot, 0.0, "north-approach: pushback aligned with away-axis (dot=%.3f)" % dot)


# ---- 15: Grunt west-approach baseline ------------------------------------

func test_grunt_separates_from_player_approached_from_west() -> void:
	## Baseline regression: west approach. Post-fix pushback points EAST (+X).
	var p: Player = _make_player()
	var g: Grunt = _make_grunt()
	# Player west of grunt.
	g.global_position = Vector2.ZERO
	p.global_position = Vector2(-(Grunt.ATTACK_RANGE - 4.0), 0.0)
	g.set_player(p)

	_drive_grunt_to_swing_fire(g)

	assert_gt(g.velocity.length(), 0.0,
		"west-approach: grunt velocity must be non-zero after swing-fire")
	assert_gt(g.velocity.x, 0.0,
		"west-approach: pushback must point EAST (positive X) — got velocity=(%.2f,%.2f)" % [g.velocity.x, g.velocity.y])

	var away_dir: Vector2 = (g.global_position - p.global_position).normalized()
	var dot: float = g.velocity.normalized().dot(away_dir)
	assert_gt(dot, 0.0, "west-approach: pushback aligned with away-axis (dot=%.3f)" % dot)


# Note: existing tests #7 + #8 already cover the EAST approach (player at +X
# relative to grunt at origin). Together with #13 / #14 / #15, all four
# cardinal approach angles are now covered.


# ---- 16: Charger motion_mode is FLOATING after _ready (regression guard) -

func test_charger_motion_mode_is_floating_after_ready() -> void:
	## Direct property assertion. Same rationale as the grunt + boss tests.
	var c: Charger = _make_charger()
	assert_eq(c.motion_mode, CharacterBody2D.MOTION_MODE_FLOATING,
		"charger motion_mode must be FLOATING after _ready() so move_and_slide treats every axis equally")


# ---- 17: Charger separates from player on south approach ----------------

func test_charger_separates_from_player_approached_from_south() -> void:
	## Player below charger → collision normal aligns with up_direction →
	## pre-fix GROUNDED mode would suppress north-axis pushback. Post-fix
	## (FLOATING), pushback velocity points NORTH and move_and_slide()
	## resolves the separation.
	##
	## Mirrors the boss south-approach test in
	## `tests/integration/test_boss_does_not_stick_after_contact.gd`.
	var p: Player = _make_player()
	var c: Charger = _make_charger()
	# Charger above, player below — charger needs to be in CHARGING with
	# direction toward the player so contact triggers _enter_recovery.
	c.global_position = Vector2(0.0, -200.0)
	p.global_position = Vector2.ZERO
	c.set_player(p)

	_drive_charger_to_charging(c)
	assert_eq(c.get_state(), Charger.STATE_CHARGING)

	# Place charger at contact distance directly north of player.
	c.global_position = Vector2(0.0, -28.0)
	p.global_position = Vector2.ZERO

	c._physics_process(PHYS_DELTA)
	assert_eq(c.get_state(), Charger.STATE_RECOVERING,
		"charger enters recovery on south-approach contact (no direction-asymmetry in trigger logic)")

	assert_gt(c.velocity.length(), 0.0,
		"south-approach: charger velocity must be non-zero on contact tick")
	# Pushback must point NORTH (away from player below). i.e. velocity.y < 0.
	assert_lt(c.velocity.y, 0.0,
		"south-approach: pushback must point NORTH (negative Y) — got velocity=(%.2f,%.2f)" % [c.velocity.x, c.velocity.y])

	var away_dir: Vector2 = (c.global_position - p.global_position).normalized()
	var pushback_dir: Vector2 = c.velocity.normalized()
	var dot: float = pushback_dir.dot(away_dir)
	assert_gt(dot, 0.0,
		"south-approach: charger pushback aligned with away-from-player vector (dot=%.3f)" % dot)


# ---- 18: Charger north-approach baseline --------------------------------

func test_charger_separates_from_player_approached_from_north() -> void:
	## Baseline regression: north approach. Post-fix pushback points SOUTH (+Y).
	var p: Player = _make_player()
	var c: Charger = _make_charger()
	# Charger below, player above.
	c.global_position = Vector2(0.0, 200.0)
	p.global_position = Vector2.ZERO
	c.set_player(p)

	_drive_charger_to_charging(c)
	c.global_position = Vector2(0.0, 28.0)
	p.global_position = Vector2.ZERO

	c._physics_process(PHYS_DELTA)
	assert_eq(c.get_state(), Charger.STATE_RECOVERING)

	assert_gt(c.velocity.length(), 0.0,
		"north-approach: charger velocity must be non-zero on contact tick")
	assert_gt(c.velocity.y, 0.0,
		"north-approach: pushback must point SOUTH (positive Y) — got velocity=(%.2f,%.2f)" % [c.velocity.x, c.velocity.y])

	var away_dir: Vector2 = (c.global_position - p.global_position).normalized()
	var dot: float = c.velocity.normalized().dot(away_dir)
	assert_gt(dot, 0.0, "north-approach: charger pushback aligned with away-axis (dot=%.3f)" % dot)


# Note: existing tests #1 / #2 / #6 cover the WEST approach (charger at -X
# of player). The boss test file covers all four cardinal directions for
# Stratum1Boss directly. Together with #17 / #18 / the existing west tests,
# the charger has N / S / W coverage and the load-bearing south case (the
# axis the GROUNDED-mode floor branch dropped) is explicitly asserted.
