extends GutTest
## Tests for Shooter mob — paired with `scripts/mobs/Shooter.gd` per
## the testing bar (`team/TESTING_BAR.md` §Devon-and-Drew).
##
## Coverage:
##   1. Spawns with full HP from MobDef + spec defaults when no def.
##   2. take_damage decrements HP, emits `damaged`, mob_died on lethal.
##   3. State path: idle -> spotted -> aiming -> firing -> post-fire-recovery
##      -> aiming (re-engage).
##   4. State path with closing player: aiming -> kiting (when player crosses
##      KITE_RANGE), kiting -> aiming (when player walks back outside).
##   5. State returns to idle from post-fire-recovery when player out of range.
##   6. Firing spawns a projectile carrying damage_base, enemy team layers,
##      slower-than-player speed.
##   7. mob_died payload mirrors Grunt — works with MobLootSpawner.
##   8. Layers/masks per DECISIONS.md.
##   9. EDGE: rapid hit spam -> single death, mob_died once.
##  10. EDGE: player dodges out of aim line during AIMING — projectile fires
##      toward last-tracked dir; player sidesteps by movement, projectile
##      carries no damage to a dodged player. (We assert the projectile
##      direction is what the shooter committed to at FIRING; the actual
##      "no damage" is enforced by Player iframes / collision layers per
##      Devon's physics-layer convention.)
##  11. EDGE: shooter killed mid-aim — no projectile spawns from corpse.
##  12. EDGE: shooter killed during post-fire-recovery — no further state,
##      no second projectile.
##  13. apply_mob_def() rebinds at runtime.
##  14. Negative damage clamped.
##  15. Projectile speed < player walk speed (spec: dodgeable).

const ShooterScript: Script = preload("res://scripts/mobs/Shooter.gd")
const ProjectileScript: Script = preload("res://scripts/projectiles/Projectile.gd")
const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")
const MobDefScript: Script = preload("res://scripts/content/MobDef.gd")
const PlayerScript: Script = preload("res://scripts/player/Player.gd")


# ---- Helpers ----------------------------------------------------------

class FakePlayer:
	extends Node2D


func _make_shooter() -> Shooter:
	var s: Shooter = ShooterScript.new()
	add_child_autofree(s)
	return s


func _make_shooter_with_def(def: MobDef) -> Shooter:
	var s: Shooter = ShooterScript.new()
	s.mob_def = def
	add_child_autofree(s)
	return s


# ---- 1: spawn HP from MobDef + spec defaults --------------------------

func test_spawns_with_full_hp_from_mobdef() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 40, "damage_base": 6, "move_speed": 60.0})
	var s: Shooter = _make_shooter_with_def(def)
	assert_eq(s.get_hp(), 40, "starts at hp_base")
	assert_eq(s.get_max_hp(), 40)
	assert_eq(s.damage_base, 6)
	assert_eq(s.move_speed, 60.0)
	assert_false(s.is_dead())


func test_default_stats_when_no_mobdef() -> void:
	var s: Shooter = _make_shooter()
	# Spec defaults: 40 HP, 5 damage (rebalanced M1 RC soak-4 — was 6).
	assert_eq(s.get_hp(), 40)
	assert_eq(s.get_max_hp(), 40)
	assert_eq(s.damage_base, 5)


# ---- 2: damage signal + death --------------------------------------

func test_damaged_signal_carries_payload() -> void:
	var s: Shooter = _make_shooter()
	watch_signals(s)
	var src: Node2D = autofree(Node2D.new())
	s.take_damage(10, Vector2.ZERO, src)
	assert_signal_emitted_with_parameters(s, "damaged", [10, 30, src])


func test_death_emits_mob_died_once_with_compatible_payload() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 15})
	var s: Shooter = _make_shooter_with_def(def)
	s.global_position = Vector2(77.0, 88.0)
	watch_signals(s)
	s.take_damage(15, Vector2.ZERO, null)
	assert_eq(s.get_hp(), 0)
	assert_true(s.is_dead())
	assert_eq(s.get_state(), Shooter.STATE_DEAD)
	assert_signal_emitted(s, "mob_died")
	var args: Array = get_signal_parameters(s, "mob_died", 0)
	assert_not_null(args)
	assert_eq(args[0], s)
	assert_almost_eq(args[1].x, 77.0, 0.001)
	assert_almost_eq(args[1].y, 88.0, 0.001)
	assert_eq(args[2], def, "mob_died carries MobDef")


# ---- 3: idle -> spotted -> aiming -> firing -> recovery -> aiming -

func test_full_state_path_in_sweet_spot() -> void:
	var s: Shooter = _make_shooter()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	s.global_position = Vector2.ZERO
	# Sweet spot — KITE_RANGE (120) < dist < AIM_RANGE (300).
	p.global_position = Vector2(200.0, 0.0)
	s.set_player(p)

	# Idle -> Spotted.
	s._physics_process(0.016)
	assert_eq(s.get_state(), Shooter.STATE_SPOTTED)

	# Spotted -> Aiming.
	s._physics_process(Shooter.SPOTTED_HOLD + 0.001)
	assert_eq(s.get_state(), Shooter.STATE_AIMING)

	# Aiming -> Firing -> POST_FIRE_RECOVERY (firing is a one-tick spawn).
	watch_signals(s)
	s._physics_process(Shooter.AIM_DURATION + 0.001)
	# After AIM_DURATION expires this physics tick, we transition to FIRING,
	# which on the *next* tick spawns the projectile and enters POST_FIRE_RECOVERY.
	# However our match block in _physics_process only runs the new state's
	# handler in a single dispatch, so we need an extra tick to run firing.
	s._physics_process(0.001)
	assert_eq(s.get_state(), Shooter.STATE_POST_FIRE_RECOVERY)
	assert_signal_emitted(s, "projectile_fired", "firing spawned a projectile")
	assert_eq(s.get_shots_fired(), 1)

	# POST_FIRE_RECOVERY -> Aiming again with player still in sweet spot.
	s._physics_process(Shooter.POST_FIRE_RECOVERY + 0.001)
	assert_eq(s.get_state(), Shooter.STATE_AIMING, "post-fire recovery -> aim again")


# ---- 4: aiming -> kiting when player closes -----------------

func test_aiming_interrupts_to_kiting_when_player_closes() -> void:
	var s: Shooter = _make_shooter()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	s.global_position = Vector2.ZERO
	p.global_position = Vector2(200.0, 0.0)
	s.set_player(p)
	# Drive into aiming.
	s._physics_process(0.016)
	s._physics_process(Shooter.SPOTTED_HOLD + 0.001)
	assert_eq(s.get_state(), Shooter.STATE_AIMING)
	# Player closes inside KITE_RANGE.
	p.global_position = Vector2(40.0, 0.0)
	s._physics_process(0.016)
	assert_eq(s.get_state(), Shooter.STATE_KITING, "close player interrupts aim -> kite")
	# Velocity is away from player (negative x since player is at +x).
	assert_lt(s.velocity.x, 0.0, "kiting moves away from player")


func test_kiting_returns_to_aiming_when_distance_restored() -> void:
	var s: Shooter = _make_shooter()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	s.global_position = Vector2.ZERO
	p.global_position = Vector2(40.0, 0.0)  # too close
	s.set_player(p)
	# Drive past spotted -> kiting.
	s._physics_process(0.016)
	s._physics_process(Shooter.SPOTTED_HOLD + 0.001)
	assert_eq(s.get_state(), Shooter.STATE_KITING)
	# Now move player far away.
	p.global_position = Vector2(300.0, 0.0)
	s._physics_process(0.016)
	assert_eq(s.get_state(), Shooter.STATE_AIMING, "distance restored -> re-aim")


# ---- 5: post-fire-recovery -> idle when player out of range ---

func test_post_fire_recovery_to_idle_when_player_gone() -> void:
	var s: Shooter = _make_shooter()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	s.global_position = Vector2.ZERO
	p.global_position = Vector2(200.0, 0.0)
	s.set_player(p)
	# Drive through fire.
	s._physics_process(0.016)  # idle -> spotted
	s._physics_process(Shooter.SPOTTED_HOLD + 0.001)  # -> aiming
	s._physics_process(Shooter.AIM_DURATION + 0.001)  # -> firing
	s._physics_process(0.001)  # firing -> post-fire-recovery
	# Yank the player far out.
	p.global_position = Vector2(99999.0, 0.0)
	s._physics_process(Shooter.POST_FIRE_RECOVERY + 0.001)
	assert_eq(s.get_state(), Shooter.STATE_IDLE, "no player in range -> idle")


# ---- 6: firing spawns a projectile w/ correct config -----------

func test_firing_spawns_projectile_with_correct_payload() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 40, "damage_base": 6})
	var s: Shooter = _make_shooter_with_def(def)
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	s.global_position = Vector2.ZERO
	p.global_position = Vector2(200.0, 0.0)  # +x, sweet spot
	s.set_player(p)
	var captured: Array = [null, Vector2.ZERO]
	s.projectile_fired.connect(func(proj: Node, dir: Vector2) -> void:
		captured[0] = proj
		captured[1] = dir
	)
	# Drive to firing.
	s._physics_process(0.016)
	s._physics_process(Shooter.SPOTTED_HOLD + 0.001)
	s._physics_process(Shooter.AIM_DURATION + 0.001)
	s._physics_process(0.001)
	assert_not_null(captured[0], "projectile spawned")
	var proj: Projectile = captured[0]
	# Ensure it's freed at end of test (it parents to whatever the shooter
	# does — usually shooter's parent which is the GUT root).
	if is_instance_valid(proj):
		# Already in tree; autofree under gut by hand.
		proj.queue_free()
	# Direction toward player (+x).
	assert_almost_eq(captured[1].x, 1.0, 0.001)
	assert_almost_eq(captured[1].y, 0.0, 0.001)
	# Damage matches mob's damage_base.
	assert_eq(proj.damage, 6)
	# Team enemy.
	assert_eq(proj.team, Projectile.TEAM_ENEMY)


# ---- 8: layers per DECISIONS.md --------------------------

func test_collision_layer_is_enemy() -> void:
	var s: Shooter = _make_shooter()
	assert_eq(s.collision_layer, Shooter.LAYER_ENEMY)
	assert_eq(s.collision_mask, Shooter.LAYER_WORLD | Shooter.LAYER_PLAYER)


# ---- 9 EDGE: rapid hit spam -----------------------

func test_rapid_hit_spam_single_death() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 20})
	var s: Shooter = _make_shooter_with_def(def)
	watch_signals(s)
	for i in 10:
		s.take_damage(50, Vector2.ZERO, null)
	assert_eq(s.get_hp(), 0)
	assert_true(s.is_dead())
	assert_signal_emit_count(s, "mob_died", 1)
	assert_signal_emit_count(s, "damaged", 1)


# ---- 10 EDGE: aim direction tracks player up to firing ----

func test_aim_direction_locks_at_firing() -> void:
	var s: Shooter = _make_shooter()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	s.global_position = Vector2.ZERO
	p.global_position = Vector2(200.0, 0.0)
	s.set_player(p)
	# Drive to aiming.
	s._physics_process(0.016)
	s._physics_process(Shooter.SPOTTED_HOLD + 0.001)
	# Mid-aim, move player to a different bearing.
	p.global_position = Vector2(0.0, 200.0)  # straight down
	# Drive aim duration until firing.
	var captured_dir: Array = [Vector2.ZERO]
	s.projectile_fired.connect(func(_proj: Node, dir: Vector2) -> void:
		captured_dir[0] = dir
	)
	s._physics_process(Shooter.AIM_DURATION + 0.001)
	s._physics_process(0.001)
	# Direction at firing time should be toward the player's NEW position.
	assert_almost_eq(captured_dir[0].x, 0.0, 0.05)
	assert_almost_eq(captured_dir[0].y, 1.0, 0.05, "fires at last-tracked direction (down), not aim-start direction")


# ---- 11 EDGE: killed mid-aim - no projectile fires ---

func test_killed_mid_aim_no_projectile() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 25})
	var s: Shooter = _make_shooter_with_def(def)
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	s.global_position = Vector2.ZERO
	p.global_position = Vector2(200.0, 0.0)
	s.set_player(p)
	# Drive to aiming.
	s._physics_process(0.016)
	s._physics_process(Shooter.SPOTTED_HOLD + 0.001)
	assert_eq(s.get_state(), Shooter.STATE_AIMING)
	watch_signals(s)
	# Kill mid-aim.
	s.take_damage(25, Vector2.ZERO, null)
	assert_eq(s.get_hp(), 0)
	assert_eq(s.get_state(), Shooter.STATE_DEAD)
	# Tick past where firing would have happened.
	s._physics_process(Shooter.AIM_DURATION + 0.5)
	s._physics_process(0.5)
	assert_signal_not_emitted(s, "projectile_fired", "no projectile from a corpse")
	assert_eq(s.get_shots_fired(), 0, "shots_fired stays 0 — never fired")


# ---- 12 EDGE: killed during post-fire-recovery - no second shot ---

func test_killed_during_recovery_no_second_shot() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 30})
	var s: Shooter = _make_shooter_with_def(def)
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	s.global_position = Vector2.ZERO
	p.global_position = Vector2(200.0, 0.0)
	s.set_player(p)
	# Drive past first fire.
	s._physics_process(0.016)
	s._physics_process(Shooter.SPOTTED_HOLD + 0.001)
	s._physics_process(Shooter.AIM_DURATION + 0.001)
	s._physics_process(0.001)
	assert_eq(s.get_state(), Shooter.STATE_POST_FIRE_RECOVERY)
	assert_eq(s.get_shots_fired(), 1)
	# Kill in recovery.
	s.take_damage(30, Vector2.ZERO, null)
	assert_eq(s.get_state(), Shooter.STATE_DEAD)
	# Tick past where re-aim and second fire would have happened.
	watch_signals(s)
	s._physics_process(Shooter.POST_FIRE_RECOVERY + 0.5)
	s._physics_process(Shooter.AIM_DURATION + 0.5)
	s._physics_process(0.5)
	assert_signal_not_emitted(s, "projectile_fired", "no second projectile")
	assert_eq(s.get_shots_fired(), 1, "still 1 — second shot never fired")


# ---- 13: apply_mob_def() rebinds runtime stats ---------

func test_apply_mob_def_rebinds_runtime_stats() -> void:
	var s: Shooter = _make_shooter()
	var hot_swap: MobDef = ContentFactory.make_mob_def({"hp_base": 100, "damage_base": 20, "move_speed": 90.0})
	s.apply_mob_def(hot_swap)
	assert_eq(s.get_hp(), 100)
	assert_eq(s.get_max_hp(), 100)
	assert_eq(s.damage_base, 20)
	assert_eq(s.move_speed, 90.0)


# ---- 14: negative damage clamp ---------------

func test_negative_damage_does_not_heal() -> void:
	var s: Shooter = _make_shooter()
	s.take_damage(-100, Vector2.ZERO, null)
	assert_eq(s.get_hp(), 40, "negative dmg clamps to 0 — no incidental healing")
	assert_false(s.is_dead())


# ---- 15: projectile speed < player walk speed (spec: dodgeable) ---

func test_projectile_speed_is_slower_than_player_walk() -> void:
	# Spec: "projectile speed slower than player run speed so player can
	# dodge." We assert it's slower than player WALK speed too — even more
	# generous: a walking player can clear the line.
	assert_lt(Shooter.PROJECTILE_SPEED, PlayerScript.WALK_SPEED, "projectile slower than player walk — guaranteed dodgeable")


# ---- 16: takes damage from player Hitbox ---------------

func test_takes_damage_from_player_hitbox() -> void:
	var s: Shooter = _make_shooter()
	var hb: Hitbox = HitboxScript.new()
	hb.configure(15, Vector2.RIGHT * 50.0, 0.1, Hitbox.TEAM_PLAYER, null)
	add_child_autofree(hb)
	hb._try_apply_hit(s)
	assert_eq(s.get_hp(), 25, "40 - 15 = 25")


# ---- 17: aim_started signal carries direction ---------

func test_aim_started_signal_carries_direction() -> void:
	var s: Shooter = _make_shooter()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	s.global_position = Vector2.ZERO
	p.global_position = Vector2(0.0, -200.0)  # straight up
	s.set_player(p)
	watch_signals(s)
	s._physics_process(0.016)  # idle -> spotted
	s._physics_process(Shooter.SPOTTED_HOLD + 0.001)  # -> aiming
	assert_signal_emitted(s, "aim_started")
	var args: Array = get_signal_parameters(s, "aim_started", 0)
	assert_not_null(args)
	var dir: Vector2 = args[0]
	assert_almost_eq(dir.x, 0.0, 0.001)
	assert_almost_eq(dir.y, -1.0, 0.001, "aim direction toward player (up)")
