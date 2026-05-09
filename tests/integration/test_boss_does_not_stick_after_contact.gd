extends GutTest
## Integration test — Boss/mob does NOT stick to player after contact-attack.
##
## Ticket: 86c9q7xh4
## Sponsor symptom (M1 RC re-soak 3, artifact embergrave-html5-deb0d21):
##   "when a boss attacked me without me moving, its sticking to me when i move"
##
## This test drives REAL Player + REAL Charger / REAL Stratum1Boss instances
## through the actual contact-attack path and asserts that the mob's velocity
## direction separates from the player on the contact tick. Position assertions
## are velocity-direction-based (dot-product test) because headless GUT runs
## skip the Godot physics server step so move_and_slide() does not physically
## translate the node — but the velocity set on the physics body IS the
## observable fix signal, and it correctly fails pre-fix (velocity = ZERO)
## and passes post-fix (velocity directed away from player).
##
## Per combat-architecture.md "Equipped-weapon dual-surface rule":
## tests must drive the actual move_and_slide path with real CharacterBody2D
## instances. FakePlayer (Node2D stub) is NOT used here — we instantiate a
## real Player so collision_layer/mask, group registration, and all physics
## properties match the production surface.

const ChargerScript: Script = preload("res://scripts/mobs/Charger.gd")
const BossScript: Script = preload("res://scripts/mobs/Stratum1Boss.gd")
const PlayerScript: Script = preload("res://scripts/player/Player.gd")

const PHYS_DELTA: float = 1.0 / 60.0


# ---- Helpers ----------------------------------------------------------

func _make_player_at(pos: Vector2) -> Player:
	var p: Player = PlayerScript.new()
	p.global_position = pos
	add_child_autofree(p)
	p.set_physics_process(false)
	return p


func _make_charger_at(pos: Vector2) -> Charger:
	var c: Charger = ChargerScript.new()
	c.global_position = pos
	add_child_autofree(c)
	c.set_physics_process(false)
	return c


func _make_boss_at(pos: Vector2) -> Stratum1Boss:
	var b: Stratum1Boss = BossScript.new()
	b.skip_intro_for_tests = true
	b.global_position = pos
	add_child_autofree(b)
	b.set_physics_process(false)
	return b


## Drive Charger from IDLE to CHARGING (standard path).
func _drive_charger_to_charging(c: Charger) -> void:
	c._physics_process(PHYS_DELTA)
	c._physics_process(Charger.SPOTTED_HOLD + 0.001)
	c._physics_process(Charger.TELEGRAPH_DURATION + 0.001)


# ---- AC: Charger does NOT stick to player after contact attack --------

func test_charger_separates_from_player_after_contact_attack() -> void:
	## Sponsor scenario: boss attacks player standing still → boss glued to player.
	## Charger equivalent: charge hits stationary player → charger enters recovery
	## at zero distance from player → player moves → charger follows (pre-fix).
	##
	## Post-fix assert: on the contact tick the charger's velocity is directed
	## AWAY from the player, not at zero. This is the observable surface that
	## prevents the "sticking" on subsequent frames.
	var p: Player = _make_player_at(Vector2.ZERO)
	var c: Charger = _make_charger_at(Vector2(-200.0, 0.0))
	c.set_player(p)

	# Drive into charging state.
	_drive_charger_to_charging(c)
	assert_eq(c.get_state(), Charger.STATE_CHARGING,
		"precondition: charger must be in CHARGING before contact test")

	# Place charger right at contact threshold (CHARGE_HITBOX_RADIUS=20 + REACH=12 = 32 px).
	c.global_position = Vector2(-28.0, 0.0)  # dist = 28, < 32 → contact
	p.global_position = Vector2.ZERO

	# Drive contact tick — _maybe_charge_hit_player fires, _enter_recovery called.
	c._physics_process(PHYS_DELTA)

	assert_eq(c.get_state(), Charger.STATE_RECOVERING,
		"charger must be in RECOVERING after player contact")

	# PRE-FIX: velocity was Vector2.ZERO — no separation, mob sticks.
	# POST-FIX: velocity is non-zero and directed away from player.
	assert_gt(c.velocity.length(), 0.0,
		"charger velocity must be non-zero after contact so move_and_slide separates bodies")

	var away_dir: Vector2 = (c.global_position - p.global_position).normalized()
	var pushback_dir: Vector2 = c.velocity.normalized()
	var dot: float = pushback_dir.dot(away_dir)
	assert_gt(dot, 0.0,
		"charger pushback must point away from player to effect separation (dot=%.3f)" % dot)


func test_charger_recovery_is_rooted_after_pushback_tick() -> void:
	## The pushback is a one-tick mechanism. On subsequent recovery ticks the
	## charger must be stationary (velocity = ZERO) so it stays in the
	## vulnerability window rather than sliding away continuously.
	var p: Player = _make_player_at(Vector2.ZERO)
	var c: Charger = _make_charger_at(Vector2(-200.0, 0.0))
	c.set_player(p)

	_drive_charger_to_charging(c)
	c.global_position = Vector2(-28.0, 0.0)
	p.global_position = Vector2.ZERO

	# Contact tick (pushback applied).
	c._physics_process(PHYS_DELTA)
	assert_eq(c.get_state(), Charger.STATE_RECOVERING)

	# Mid-recovery tick — must be rooted.
	c._physics_process(PHYS_DELTA)
	assert_eq(c.velocity, Vector2.ZERO,
		"charger is rooted (velocity=ZERO) during recovery after one-tick pushback")


# ---- AC: Stratum1Boss does NOT stick to player after melee contact ----

func test_boss_separates_from_player_after_melee_swing() -> void:
	## Direct Sponsor scenario: boss melee swings player at close range →
	## boss enters attack recovery with velocity = ZERO → player moves →
	## boss immediately re-engages at zero distance (sticking, pre-fix).
	##
	## Post-fix: swing-fire tick applies pushback velocity directed away from
	## player. move_and_slide() on that tick separates the bodies.
	var p: Player = _make_player_at(Vector2(Stratum1Boss.MELEE_RANGE - 2.0, 0.0))
	var b: Stratum1Boss = _make_boss_at(Vector2.ZERO)
	b.set_player(p)

	# Tick 1 — chase → begin_melee_telegraph.
	b._physics_process(PHYS_DELTA)
	assert_eq(b.get_state(), Stratum1Boss.STATE_TELEGRAPHING_MELEE,
		"precondition: boss must telegraph before swing")

	# Tick 2 — telegraph expires → _fire_melee_swing.
	b._physics_process(Stratum1Boss.MELEE_TELEGRAPH_DURATION + 0.001)
	assert_eq(b.get_state(), Stratum1Boss.STATE_ATTACKING,
		"boss enters attack-recovery after melee swing")

	# PRE-FIX: velocity was ZERO → no separation on this tick → sticking.
	# POST-FIX: velocity is non-zero, directed away from player.
	assert_gt(b.velocity.length(), 0.0,
		"boss velocity must be non-zero after swing-fire so move_and_slide separates bodies")

	var away_dir: Vector2 = (b.global_position - p.global_position).normalized()
	var pushback_dir: Vector2 = b.velocity.normalized()
	var dot: float = pushback_dir.dot(away_dir)
	assert_gt(dot, 0.0,
		"boss pushback must point away from player to effect separation (dot=%.3f)" % dot)


func test_boss_attack_recovery_is_rooted_after_pushback_tick() -> void:
	## Post-pushback, the boss must be stationary for the rest of the attack
	## recovery window. This ensures the pushback is a one-tick escape mechanism,
	## not a sustained drift that would make the boss float away during recovery.
	var p: Player = _make_player_at(Vector2(Stratum1Boss.MELEE_RANGE - 2.0, 0.0))
	var b: Stratum1Boss = _make_boss_at(Vector2.ZERO)
	b.set_player(p)

	b._physics_process(PHYS_DELTA)
	assert_eq(b.get_state(), Stratum1Boss.STATE_TELEGRAPHING_MELEE)
	b._physics_process(Stratum1Boss.MELEE_TELEGRAPH_DURATION + 0.001)
	assert_eq(b.get_state(), Stratum1Boss.STATE_ATTACKING)

	# Subsequent tick — attack recovery handler must zero velocity.
	b._physics_process(PHYS_DELTA)
	assert_eq(b.velocity, Vector2.ZERO,
		"boss is rooted (velocity=ZERO) during attack recovery after one-tick pushback")


# ---- AC: Player escape after contact does not re-trigger stick --------

func test_charger_does_not_follow_player_during_recovery() -> void:
	## Simulates Sponsor's exact scenario: player moves AWAY from mob during
	## recovery window. The mob's velocity must remain zero (stationary) —
	## it must NOT re-chase or re-glue during the recovery state.
	var p: Player = _make_player_at(Vector2.ZERO)
	var c: Charger = _make_charger_at(Vector2(-200.0, 0.0))
	c.set_player(p)

	_drive_charger_to_charging(c)
	c.global_position = Vector2(-28.0, 0.0)
	p.global_position = Vector2.ZERO

	# Contact tick.
	c._physics_process(PHYS_DELTA)
	assert_eq(c.get_state(), Charger.STATE_RECOVERING)

	# Player "moves" away — simulate by setting player position far.
	p.global_position = Vector2(100.0, 0.0)

	# Multiple mid-recovery ticks — charger must stay rooted.
	for _i: int in range(5):
		c._physics_process(PHYS_DELTA)
		assert_eq(c.velocity, Vector2.ZERO,
			"charger stays rooted (no follow) while player escapes during recovery")
		assert_eq(c.get_state(), Charger.STATE_RECOVERING,
			"charger remains in RECOVERING state while timer counts down")


# ---- AC: Boss separation symmetric across all four approach directions ---
#
# Ticket: 86c9q96jv (M1 RC re-soak 5: "boss sticks from bottom edge only").
# Sponsor symptom: when the player approached Stratum1Boss from the south
# (below), the boss stuck to the player and resisted separation. Other
# approach angles (north / east / west) worked — the existing post-contact
# pushback in `_fire_melee_swing` separated bodies cleanly.
#
# Root cause: CharacterBody2D defaults to MOTION_MODE_GROUNDED with
# `up_direction = (0, -1)`. When the player approaches from south, the
# collision normal between player and boss aligns with up_direction, which
# engages GROUNDED mode's floor-detection branch and suppresses the boss's
# pushback velocity along the +up axis. North / east / west approaches
# don't align the collision normal with up_direction, so the floor branch
# never engages and the bug never manifests.
#
# Fix: `_apply_motion_mode()` sets `motion_mode = MOTION_MODE_FLOATING` in
# `_ready()` so every axis is treated equally. The boss has no floor /
# gravity / jump concept (top-down 2D), making FLOATING the canonical
# motion mode regardless.
#
# Verification surface (headless): velocity-direction dot-product test on
# the swing-fire tick — same shape as the existing east-approach test but
# parameterised over all four approach angles. The motion_mode fix
# specifically affects the move_and_slide() resolution that follows; the
# velocity vector itself is set identically in all four cases. We
# additionally assert `motion_mode == FLOATING` directly so the regression
# is caught even if a future scene file overrides the property.

func test_boss_motion_mode_is_floating_after_ready() -> void:
	## Direct property assertion: the canonical Godot 4 top-down 2D
	## CharacterBody2D motion_mode is FLOATING. GROUNDED is the engine
	## default and would re-introduce the south-approach floor-snap bug.
	var b: Stratum1Boss = _make_boss_at(Vector2.ZERO)
	assert_eq(b.motion_mode, CharacterBody2D.MOTION_MODE_FLOATING,
		"boss motion_mode must be FLOATING after _ready() so move_and_slide treats every axis equally")


func test_boss_separates_from_player_approached_from_south() -> void:
	## Sponsor's exact M1 RC re-soak 5 scenario: player walks north into
	## boss from below. Pre-fix (M1 RC re-soak 5): boss stuck to player —
	## the GROUNDED-mode floor-snap suppressed the north-axis pushback.
	## Post-fix: pushback velocity is non-zero AND directed away from
	## player (i.e. NORTH = negative Y), and motion_mode = FLOATING ensures
	## move_and_slide actually applies it.
	##
	## Player south of boss → player_pos.y > boss_pos.y → away.y < 0 →
	## pushback.y < 0 (NORTH). We assert dot-product against the away-axis,
	## same shape as the east-approach test.
	var b: Stratum1Boss = _make_boss_at(Vector2.ZERO)
	# Player below boss, just inside MELEE_RANGE so the chase-tick commits to a melee swing.
	var p: Player = _make_player_at(Vector2(0.0, Stratum1Boss.MELEE_RANGE - 2.0))
	b.set_player(p)

	# Tick 1: chase → telegraph.
	b._physics_process(PHYS_DELTA)
	assert_eq(b.get_state(), Stratum1Boss.STATE_TELEGRAPHING_MELEE,
		"precondition: south-approach also triggers melee telegraph (no direction-asymmetry in trigger logic)")

	# Tick 2: telegraph expires → swing fires → pushback applied.
	b._physics_process(Stratum1Boss.MELEE_TELEGRAPH_DURATION + 0.001)
	assert_eq(b.get_state(), Stratum1Boss.STATE_ATTACKING)

	assert_gt(b.velocity.length(), 0.0,
		"south-approach: boss velocity must be non-zero after swing-fire (separation from player)")

	# Pushback must point NORTH (away from player below). i.e. velocity.y < 0.
	assert_lt(b.velocity.y, 0.0,
		"south-approach: pushback must point NORTH (negative Y) — got velocity=(%.2f,%.2f)" % [b.velocity.x, b.velocity.y])

	var away_dir: Vector2 = (b.global_position - p.global_position).normalized()
	var pushback_dir: Vector2 = b.velocity.normalized()
	var dot: float = pushback_dir.dot(away_dir)
	assert_gt(dot, 0.0,
		"south-approach: pushback aligned with away-from-player vector (dot=%.3f)" % dot)


func test_boss_separates_from_player_approached_from_north() -> void:
	## Baseline regression test: north approach was reported working pre-fix.
	## Post-fix must still work — assert pushback points SOUTH (positive Y).
	## Adding this so any future approach-direction asymmetry surfaces
	## immediately rather than waiting for Sponsor soak (lesson from this
	## bug: the test suite had only one approach-direction case).
	var b: Stratum1Boss = _make_boss_at(Vector2.ZERO)
	# Player above boss.
	var p: Player = _make_player_at(Vector2(0.0, -(Stratum1Boss.MELEE_RANGE - 2.0)))
	b.set_player(p)

	b._physics_process(PHYS_DELTA)
	assert_eq(b.get_state(), Stratum1Boss.STATE_TELEGRAPHING_MELEE)
	b._physics_process(Stratum1Boss.MELEE_TELEGRAPH_DURATION + 0.001)
	assert_eq(b.get_state(), Stratum1Boss.STATE_ATTACKING)

	assert_gt(b.velocity.length(), 0.0,
		"north-approach: boss velocity must be non-zero after swing-fire")
	assert_gt(b.velocity.y, 0.0,
		"north-approach: pushback must point SOUTH (positive Y) — got velocity=(%.2f,%.2f)" % [b.velocity.x, b.velocity.y])

	var away_dir: Vector2 = (b.global_position - p.global_position).normalized()
	var dot: float = b.velocity.normalized().dot(away_dir)
	assert_gt(dot, 0.0, "north-approach: pushback aligned with away-axis (dot=%.3f)" % dot)


func test_boss_separates_from_player_approached_from_west() -> void:
	## Baseline regression: west approach. Post-fix pushback points EAST (+X).
	var b: Stratum1Boss = _make_boss_at(Vector2.ZERO)
	# Player west of boss.
	var p: Player = _make_player_at(Vector2(-(Stratum1Boss.MELEE_RANGE - 2.0), 0.0))
	b.set_player(p)

	b._physics_process(PHYS_DELTA)
	assert_eq(b.get_state(), Stratum1Boss.STATE_TELEGRAPHING_MELEE)
	b._physics_process(Stratum1Boss.MELEE_TELEGRAPH_DURATION + 0.001)
	assert_eq(b.get_state(), Stratum1Boss.STATE_ATTACKING)

	assert_gt(b.velocity.length(), 0.0,
		"west-approach: boss velocity must be non-zero after swing-fire")
	assert_gt(b.velocity.x, 0.0,
		"west-approach: pushback must point EAST (positive X) — got velocity=(%.2f,%.2f)" % [b.velocity.x, b.velocity.y])

	var away_dir: Vector2 = (b.global_position - p.global_position).normalized()
	var dot: float = b.velocity.normalized().dot(away_dir)
	assert_gt(dot, 0.0, "west-approach: pushback aligned with away-axis (dot=%.3f)" % dot)


# Note: the existing `test_boss_separates_from_player_after_melee_swing` covers
# the east approach (player at +X). Together with the three above, all four
# cardinal approach angles are covered by paired tests so any future
# direction-asymmetry surfaces immediately.


# ---- AC: Slam recovery is rooted (boss Phase 2+) ---------------------

func test_boss_slam_recovery_velocity_is_zero() -> void:
	## Slam uses a separate recovery state. Assert it also doesn't cause sticking
	## (slam's knockback direction already pushes player away, so the boss does
	## not need a special push-back here — but confirm velocity is zeroed in
	## slam-recovery so the boss doesn't drift).
	var p: Player = _make_player_at(Vector2(40.0, 0.0))  # slam range 80px
	var b: Stratum1Boss = _make_boss_at(Vector2.ZERO)
	b.set_player(p)

	# Drive into phase 2 (unlocks slam).
	b.take_damage(204, Vector2.ZERO, null)  # 600 → 396 (phase-2 threshold)
	b._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.001)
	assert_eq(b.get_phase(), Stratum1Boss.PHASE_2)

	# Player within slam range (40px < 80px). Slam cooldown clear on phase entry.
	b._physics_process(PHYS_DELTA)   # chase → slam_telegraph
	assert_eq(b.get_state(), Stratum1Boss.STATE_TELEGRAPHING_SLAM,
		"phase 2 boss picks slam when player inside slam radius")

	# Slam fires.
	b._physics_process(Stratum1Boss.SLAM_TELEGRAPH_DURATION + 0.001)
	assert_eq(b.get_state(), Stratum1Boss.STATE_SLAM_RECOVERY)

	# Slam recovery handler: velocity = ZERO (slam already knockbacked player away).
	b._physics_process(PHYS_DELTA)
	assert_eq(b.velocity, Vector2.ZERO,
		"boss velocity is zero during slam recovery (no drift/stick)")
