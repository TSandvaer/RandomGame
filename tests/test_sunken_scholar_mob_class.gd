extends GutTest
## Tests for SunkenScholar mob class — paired with `scripts/mobs/SunkenScholar.gd`
## per the testing bar (`team/TESTING_BAR.md` §Devon-and-Drew).
##
## Stage 2 scope (W3-T7 ticket 86c9y7ygj):
##   - Mob-class smoke (instantiable, state-machine boots).
##   - Telegraph→fire progression (idle → spotted → aiming → firing).
##   - Band invariants (SHOOT_RANGE = PROJECTILE_SPEED * PROJECTILE_LIFETIME).
##   - Kite + cornered fallback.
##   - Differentiation pins (slower projectile + longer telegraph vs S1 Shooter).
##   - Diagnostic trace contract (state_changed signal fires per Drew persona rule).
##   - No USER WARNING: emissions during normal operation.

const SunkenScholarScript: Script = preload("res://scripts/mobs/SunkenScholar.gd")
const ShooterScript: Script = preload("res://scripts/mobs/Shooter.gd")
const ProjectileScript: Script = preload("res://scripts/projectiles/Projectile.gd")
const MobDefScript: Script = preload("res://scripts/content/MobDef.gd")
const PlayerScript: Script = preload("res://scripts/player/Player.gd")
const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

# ---- Universal-warning gate ------------------------------------------

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- Helpers ----------------------------------------------------------


class FakePlayer:
	extends Node2D


func _make_scholar() -> SunkenScholar:
	var s: SunkenScholar = SunkenScholarScript.new()
	add_child_autofree(s)
	return s


func _make_scholar_with_def(def: MobDef) -> SunkenScholar:
	var s: SunkenScholar = SunkenScholarScript.new()
	s.mob_def = def
	add_child_autofree(s)
	# Test-only: skip Projectile spawn so the full state-machine cycle can run
	# without leaking real Projectile nodes into the test tree.
	s.test_skip_projectile_spawn = true
	return s


# ---- 1: spawn HP from MobDef + spec defaults --------------------------


func test_spawns_with_full_hp_from_mobdef() -> void:
	var def: MobDef = ContentFactory.make_mob_def(
		{"hp_base": 50, "damage_base": 6, "move_speed": 60.0}
	)
	var s: SunkenScholar = _make_scholar_with_def(def)
	assert_eq(s.get_hp(), 50, "starts at hp_base")
	assert_eq(s.get_max_hp(), 50)
	assert_eq(s.damage_base, 6)
	assert_eq(s.move_speed, 60.0)
	assert_false(s.is_dead())


func test_default_stats_when_no_mobdef() -> void:
	var s: SunkenScholar = _make_scholar()
	# Spec defaults: 50 HP, 6 damage (S2 archetype baseline).
	assert_eq(s.get_hp(), 50)
	assert_eq(s.get_max_hp(), 50)
	assert_eq(s.damage_base, 6)


# ---- 2: damage + death contract --------------------------------------


func test_damaged_signal_carries_payload() -> void:
	var s: SunkenScholar = _make_scholar()
	watch_signals(s)
	var src: Node2D = autofree(Node2D.new())
	s.take_damage(10, Vector2.ZERO, src)
	assert_signal_emitted_with_parameters(s, "damaged", [10, 40, src])


func test_death_emits_mob_died_once_with_compatible_payload() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 15})
	var s: SunkenScholar = _make_scholar_with_def(def)
	s.global_position = Vector2(77.0, 88.0)
	watch_signals(s)
	s.take_damage(15, Vector2.ZERO, null)
	assert_eq(s.get_hp(), 0)
	assert_true(s.is_dead())
	assert_eq(s.get_state(), SunkenScholar.STATE_DEAD)
	assert_signal_emitted(s, "mob_died")
	var args: Array = get_signal_parameters(s, "mob_died", 0)
	assert_not_null(args)
	assert_eq(args[0], s)
	assert_almost_eq(args[1].x, 77.0, 0.001)
	assert_almost_eq(args[1].y, 88.0, 0.001)
	assert_eq(args[2], def, "mob_died carries MobDef")


func test_rapid_hit_spam_single_death() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 20})
	var s: SunkenScholar = _make_scholar_with_def(def)
	watch_signals(s)
	for i in 10:
		s.take_damage(50, Vector2.ZERO, null)
	assert_eq(s.get_hp(), 0)
	assert_true(s.is_dead())
	assert_signal_emit_count(s, "mob_died", 1)
	assert_signal_emit_count(s, "damaged", 1)


func test_negative_damage_does_not_heal() -> void:
	var s: SunkenScholar = _make_scholar()
	s.take_damage(-100, Vector2.ZERO, null)
	assert_eq(s.get_hp(), 50, "negative dmg clamps to 0 — no incidental healing")
	assert_false(s.is_dead())


# ---- 3: state-machine boot + idle→spotted→aiming→firing path ----------


func test_initial_state_is_idle() -> void:
	var s: SunkenScholar = _make_scholar()
	assert_eq(s.get_state(), SunkenScholar.STATE_IDLE)


func test_full_state_path_in_sweet_spot() -> void:
	var s: SunkenScholar = _make_scholar()
	s.test_skip_projectile_spawn = true
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	s.global_position = Vector2.ZERO
	# Sweet spot — KITE_RANGE (120) < dist < SHOOT_RANGE (144). Use 130 mid-band.
	p.global_position = Vector2(130.0, 0.0)
	s.set_player(p)

	# Idle -> Spotted.
	s._physics_process(0.016)
	assert_eq(s.get_state(), SunkenScholar.STATE_SPOTTED)

	# Spotted -> Aiming.
	s._physics_process(SunkenScholar.SPOTTED_HOLD + 0.001)
	assert_eq(s.get_state(), SunkenScholar.STATE_AIMING)

	# Aiming -> Firing (one-tick spawn) -> POST_FIRE_RECOVERY.
	watch_signals(s)
	s._physics_process(SunkenScholar.AIM_DURATION + 0.001)
	s._physics_process(0.001)
	assert_eq(s.get_state(), SunkenScholar.STATE_POST_FIRE_RECOVERY)
	assert_signal_emitted(s, "projectile_fired", "firing spawned a projectile")
	assert_eq(s.get_shots_fired(), 1)


# ---- 4: kite when player closes; resume aim when distance restored -----


func test_aiming_interrupts_to_kiting_when_player_closes() -> void:
	var s: SunkenScholar = _make_scholar()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	s.global_position = Vector2.ZERO
	p.global_position = Vector2(200.0, 0.0)
	s.set_player(p)
	s._physics_process(0.016)
	s._physics_process(SunkenScholar.SPOTTED_HOLD + 0.001)
	assert_eq(s.get_state(), SunkenScholar.STATE_AIMING)
	# Player closes inside KITE_RANGE.
	p.global_position = Vector2(40.0, 0.0)
	s._physics_process(0.016)
	assert_eq(s.get_state(), SunkenScholar.STATE_KITING)
	assert_lt(s.velocity.x, 0.0, "kiting moves away from +x player")


func test_kiting_returns_to_aiming_when_distance_restored() -> void:
	var s: SunkenScholar = _make_scholar()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	s.global_position = Vector2.ZERO
	p.global_position = Vector2(40.0, 0.0)
	s.set_player(p)
	s._physics_process(0.016)
	s._physics_process(SunkenScholar.SPOTTED_HOLD + 0.001)
	assert_eq(s.get_state(), SunkenScholar.STATE_KITING)
	# Move player far away — past KITE_RANGE + 16 exit threshold.
	p.global_position = Vector2(300.0, 0.0)
	s._physics_process(0.016)
	assert_eq(s.get_state(), SunkenScholar.STATE_AIMING)


# ---- 5: cornered fallback — wall-blocked + close player → AIMING ------


func test_promote_cornered_to_aiming_uses_short_windup() -> void:
	# Drive `_promote_cornered_to_aiming` directly — headless GUT can't
	# simulate is_on_wall() without a populated physics world. The helper is
	# the test seam (mirrors Shooter's pattern, ticket 86c9uehaq doctrine).
	var s: SunkenScholar = _make_scholar()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	s.global_position = Vector2.ZERO
	p.global_position = Vector2(50.0, 0.0)  # inside KITE_RANGE
	s.set_player(p)
	watch_signals(s)
	s._promote_cornered_to_aiming(50.0)
	assert_eq(s.get_state(), SunkenScholar.STATE_AIMING)
	# Cornered windup is SHORTER than the normal AIM_DURATION.
	assert_eq(s._aim_left, SunkenScholar.CORNERED_AIM_DURATION)
	assert_lt(
		SunkenScholar.CORNERED_AIM_DURATION,
		SunkenScholar.AIM_DURATION,
		"cornered windup must be faster than normal aim — fights back, doesn't freeze"
	)
	assert_signal_emitted(s, "aim_started")


# ---- 6: SHOOT_RANGE band invariant (drift-detector per 86c9uehaq) -----


func test_shoot_range_equals_projectile_reach() -> void:
	# Doctrine — band invariant. Any future tune to PROJECTILE_SPEED or
	# PROJECTILE_LIFETIME must auto-update SHOOT_RANGE. A hard-coded divergence
	# would re-open the Sponsor "shoots from distance, projectiles fall short"
	# failure class.
	assert_almost_eq(
		SunkenScholar.SHOOT_RANGE,
		SunkenScholar.PROJECTILE_SPEED * SunkenScholar.PROJECTILE_LIFETIME,
		0.001,
		"SHOOT_RANGE must equal projectile reach (speed × lifetime)"
	)


func test_band_invariant_non_empty_sweet_spot() -> void:
	# Doctrine — KITE_RANGE < SHOOT_RANGE so the stand-and-fire band is
	# non-empty; SHOOT_RANGE < AIM_RANGE so the close-the-gap region is too.
	assert_lt(
		SunkenScholar.KITE_RANGE,
		SunkenScholar.SHOOT_RANGE,
		"KITE_RANGE must be below SHOOT_RANGE so sweet-spot band exists"
	)
	assert_lt(
		SunkenScholar.SHOOT_RANGE,
		SunkenScholar.AIM_RANGE,
		"SHOOT_RANGE must be below AIM_RANGE so close-the-gap region exists"
	)


# ---- 7: differentiation from S1 Shooter (Uma §5.5 contract) ----------


func test_projectile_is_slower_than_s1_shooter() -> void:
	# Uma §5.5 contract — SunkenScholar is the "slower bullet, longer
	# telegraph" variant. If a future tune crosses these into S1 Shooter's
	# values, the visual-vs-mechanical contract breaks (same TTK but the
	# distinct silhouette + cast-tell anchor disappears).
	assert_lt(
		SunkenScholar.PROJECTILE_SPEED,
		ShooterScript.PROJECTILE_SPEED,
		"SunkenScholar projectile must be slower than S1 Shooter"
	)


func test_aim_duration_is_longer_than_s1_shooter() -> void:
	assert_gt(
		SunkenScholar.AIM_DURATION,
		ShooterScript.AIM_DURATION,
		"SunkenScholar telegraph must be longer than S1 Shooter (longer wind-up paired with slower bullet)"
	)


func test_projectile_speed_is_slower_than_player_walk() -> void:
	# Spec: projectile dodgeable by a walking player. (Already true of S1
	# Shooter; pin here too so a future scaling regression on either side
	# fails fast.)
	assert_lt(
		SunkenScholar.PROJECTILE_SPEED,
		PlayerScript.WALK_SPEED,
		"projectile slower than player walk — guaranteed dodgeable"
	)


# ---- 8: layers per DECISIONS.md ---------------------------------------


func test_collision_layer_is_enemy() -> void:
	var s: SunkenScholar = _make_scholar()
	assert_eq(s.collision_layer, SunkenScholar.LAYER_ENEMY)
	assert_eq(s.collision_mask, SunkenScholar.LAYER_WORLD | SunkenScholar.LAYER_PLAYER)


# ---- 9: state_changed signal contract (Drew persona instrumentation rule) ----


func test_state_changed_emits_on_transition() -> void:
	# Drew persona rule: "No new mob class without trace instrumentation."
	# `state_changed` is the Godot signal half (combat-trace shim is HTML5
	# only). A Playwright spec asserts on the [combat-trace] line; this GUT
	# test pins the signal contract so a future refactor that drops the
	# emit fails fast in headless CI.
	var s: SunkenScholar = _make_scholar()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	s.global_position = Vector2.ZERO
	p.global_position = Vector2(130.0, 0.0)
	s.set_player(p)
	watch_signals(s)
	s._physics_process(0.016)
	assert_signal_emitted_with_parameters(
		s, "state_changed", [SunkenScholar.STATE_IDLE, SunkenScholar.STATE_SPOTTED]
	)


# ---- 10: killed mid-aim — no projectile from corpse -------------------


func test_killed_mid_aim_no_projectile() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 25})
	var s: SunkenScholar = _make_scholar_with_def(def)
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	s.global_position = Vector2.ZERO
	p.global_position = Vector2(130.0, 0.0)
	s.set_player(p)
	s._physics_process(0.016)
	s._physics_process(SunkenScholar.SPOTTED_HOLD + 0.001)
	assert_eq(s.get_state(), SunkenScholar.STATE_AIMING)
	watch_signals(s)
	s.take_damage(25, Vector2.ZERO, null)
	assert_eq(s.get_state(), SunkenScholar.STATE_DEAD)
	# Tick past where firing would have happened.
	s._physics_process(SunkenScholar.AIM_DURATION + 0.5)
	s._physics_process(0.5)
	assert_signal_not_emitted(s, "projectile_fired")
	assert_eq(s.get_shots_fired(), 0)


# ---- 11: apply_mob_def() rebinds runtime stats ------------------------


func test_apply_mob_def_rebinds_runtime_stats() -> void:
	var s: SunkenScholar = _make_scholar()
	var hot_swap: MobDef = ContentFactory.make_mob_def(
		{"hp_base": 100, "damage_base": 20, "move_speed": 90.0}
	)
	s.apply_mob_def(hot_swap)
	assert_eq(s.get_hp(), 100)
	assert_eq(s.get_max_hp(), 100)
	assert_eq(s.damage_base, 20)
	assert_eq(s.move_speed, 90.0)


# ---- 12: scene round-trip + mob_def resolves from .tres ---------------


func test_scene_instantiates_clean_with_mob_def() -> void:
	# Pin the production scene + .tres path. Future renames must update both.
	var scene: PackedScene = load("res://scenes/mobs/SunkenScholar.tscn") as PackedScene
	assert_not_null(scene, "scene loads")
	var def: MobDef = load("res://resources/mobs/sunken_scholar.tres") as MobDef
	assert_not_null(def, "mob_def loads")
	assert_eq(def.id, &"sunken_scholar")
	assert_eq(def.hp_base, 50)
	assert_eq(def.damage_base, 6)
	assert_eq(def.ai_behavior_tag, &"ranged_kiter")
	var inst: SunkenScholar = scene.instantiate() as SunkenScholar
	assert_not_null(inst, "scene instantiates as SunkenScholar")
	inst.mob_def = def
	add_child_autofree(inst)
	assert_eq(inst.get_hp(), 50, "HP applied from .tres at _ready")
