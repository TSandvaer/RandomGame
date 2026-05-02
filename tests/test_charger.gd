extends GutTest
## Tests for Charger mob — paired with `scripts/mobs/Charger.gd` per
## the testing bar (`team/TESTING_BAR.md` §Devon-and-Drew).
##
## Coverage:
##   1. Spawns with full HP from MobDef + spec defaults when no def.
##   2. take_damage decrements HP, emits `damaged`, mob_died on lethal.
##   3. State machine full path: idle -> spotted -> telegraphing -> charging
##      -> recovering -> spotted (re-engage) when player still in range.
##   4. State returns to idle from recovery when player out of range.
##   5. Charge direction locked at telegraph start (player movement during
##      telegraph does NOT redirect the charge).
##   6. Velocity is _charge_dir * charge_speed during STATE_CHARGING.
##   7. Vulnerability multiplier — damage during recovery is 2x; outside
##      recovery is 1x (armored).
##   8. EDGE: charge-into-wall stops cleanly (move_and_slide rejected motion
##      => transition to recovery, no orphan velocity).
##   9. EDGE: player dodge-rolls during charge — dodge-style i-frames mean
##      the charger's contact-hitbox spawns but the player's iframe layer
##      drop means it won't damage them. We assert at the test level that
##      a player who moves out of the charge line takes no body-hit.
##  10. EDGE: charger killed mid-charge — velocity zeroed, no further state
##      transitions, no charge_hit_spawned post-death, mob_died once.
##  11. Layers/masks per DECISIONS.md (enemy collision_layer).
##  12. Hitbox spawned by charger on charge-hit is enemy team / masks player.
##  13. apply_mob_def() rebinds HP/damage/charge_speed mid-life.
##  14. mob_died payload mirrors Grunt — works with MobLootSpawner.

const ChargerScript: Script = preload("res://scripts/mobs/Charger.gd")
const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")
const MobDefScript: Script = preload("res://scripts/content/MobDef.gd")


# ---- Helpers ----------------------------------------------------------

class FakePlayer:
	extends Node2D
	# Dummy player target. The charger only reads global_position.


func _make_charger() -> Charger:
	var c: Charger = ChargerScript.new()
	add_child_autofree(c)
	# Tests drive `_physics_process` manually with state-bounded deltas
	# (see `_drive_to_charging`). If the engine ALSO auto-ticks the body via
	# its physics scheduler, the two callers race: a slow CI runner can sneak
	# enough engine ticks between manual calls to expire `_charge_time_left`,
	# transitioning CHARGING -> RECOVERING before the test asserts on it. Real
	# observed flake: run 25260213330 fails with "expected charging, got
	# recovering" + "velocity > 0 mid-charge: 0.0". Disabling auto-physics
	# makes the test fully deterministic — manual `_physics_process(delta)`
	# calls still work, they just no longer race with the engine.
	c.set_physics_process(false)
	return c


func _make_charger_with_def(def: MobDef) -> Charger:
	var c: Charger = ChargerScript.new()
	c.mob_def = def
	add_child_autofree(c)
	# See _make_charger() for why auto-physics is disabled.
	c.set_physics_process(false)
	return c


## Drive the charger from idle through telegraph to CHARGING. Returns once
## the charger is in STATE_CHARGING.
func _drive_to_charging(c: Charger) -> void:
	# Tick once so idle picks up the player in range.
	c._physics_process(0.016)
	# Burn through the spotted hold.
	c._physics_process(Charger.SPOTTED_HOLD + 0.001)
	# Burn through the telegraph windup.
	c._physics_process(Charger.TELEGRAPH_DURATION + 0.001)


# ---- 1: spawn HP from MobDef + spec defaults --------------------------

func test_spawns_with_full_hp_from_mobdef() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 70, "damage_base": 8, "move_speed": 180.0})
	var c: Charger = _make_charger_with_def(def)
	assert_eq(c.get_hp(), 70, "starts at hp_base")
	assert_eq(c.get_max_hp(), 70, "max_hp = hp_base at spawn")
	assert_eq(c.damage_base, 8, "damage_base from def")
	assert_eq(c.charge_speed, 180.0, "charge_speed sourced from MobDef.move_speed")
	assert_false(c.is_dead())


func test_default_stats_when_no_mobdef() -> void:
	var c: Charger = _make_charger()
	# Spec: 70 HP, 8 base damage, 1.5x player walk speed (120 * 1.5 = 180).
	assert_eq(c.get_hp(), 70)
	assert_eq(c.get_max_hp(), 70)
	assert_eq(c.damage_base, 8)
	assert_eq(c.charge_speed, 180.0)


# ---- 2: damage + death + payload --------------------------------------

func test_damaged_signal_carries_payload() -> void:
	var c: Charger = _make_charger()
	watch_signals(c)
	var src: Node2D = autofree(Node2D.new())
	# In IDLE the multiplier is armored 1.0, so 7 in -> 7 out.
	c.take_damage(7, Vector2.ZERO, src)
	assert_signal_emitted_with_parameters(c, "damaged", [7, 63, src])


func test_death_emits_mob_died_once_with_grunt_compatible_payload() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 20})
	var c: Charger = _make_charger_with_def(def)
	c.global_position = Vector2(50.0, -25.0)
	watch_signals(c)
	c.take_damage(20, Vector2.ZERO, null)
	assert_eq(c.get_hp(), 0)
	assert_true(c.is_dead())
	assert_eq(c.get_state(), Charger.STATE_DEAD)
	assert_signal_emitted(c, "mob_died")
	# Payload (mob, position, def) — mirrors Grunt so MobLootSpawner reusable.
	var args: Array = get_signal_parameters(c, "mob_died", 0)
	assert_not_null(args)
	assert_eq(args[0], c)
	assert_almost_eq(args[1].x, 50.0, 0.001)
	assert_almost_eq(args[1].y, -25.0, 0.001)
	assert_eq(args[2], def, "mob_died carries MobDef so loot listeners get loot_table")


# ---- 3: full state path ----------------------------------------------

func test_full_state_machine_path() -> void:
	var c: Charger = _make_charger()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	c.global_position = Vector2.ZERO
	# Place player far enough that the charger won't collide on first frame
	# of charge — we want to observe the charge state cleanly.
	p.global_position = Vector2(400.0, 0.0)
	c.set_player(p)

	# Idle -> Spotted (player in aggro radius).
	c._physics_process(0.016)
	assert_eq(c.get_state(), Charger.STATE_SPOTTED, "spots player in aggro range")

	# Spotted -> Telegraphing (after spotted hold).
	c._physics_process(Charger.SPOTTED_HOLD + 0.001)
	assert_eq(c.get_state(), Charger.STATE_TELEGRAPHING, "spotted hold ends -> telegraph")

	# Telegraphing -> Charging (after windup).
	watch_signals(c)
	c._physics_process(Charger.TELEGRAPH_DURATION + 0.001)
	assert_eq(c.get_state(), Charger.STATE_CHARGING, "telegraph ends -> charge")

	# Charging -> Recovering (max charge duration). Move player far out so
	# we don't body-hit them during the simulated tick.
	p.global_position = Vector2(99999.0, 0.0)
	c._physics_process(Charger.CHARGE_MAX_DURATION + 0.001)
	assert_eq(c.get_state(), Charger.STATE_RECOVERING, "charge max -> recover")

	# Recovering -> Spotted again when player back in range (re-engage).
	p.global_position = Vector2(200.0, 0.0)
	c._physics_process(Charger.RECOVERY_DURATION + 0.001)
	assert_eq(c.get_state(), Charger.STATE_SPOTTED, "recovery ends with player in range -> spotted again")


func test_recovery_returns_to_idle_when_player_out_of_range() -> void:
	var c: Charger = _make_charger()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	c.global_position = Vector2.ZERO
	p.global_position = Vector2(200.0, 0.0)
	c.set_player(p)
	# Drive into charge and then out of charge (player out of range so no body hit).
	c._physics_process(0.016)
	c._physics_process(Charger.SPOTTED_HOLD + 0.001)
	c._physics_process(Charger.TELEGRAPH_DURATION + 0.001)
	# Yank player out of range before max-charge expires.
	p.global_position = Vector2(99999.0, 0.0)
	c._physics_process(Charger.CHARGE_MAX_DURATION + 0.001)
	assert_eq(c.get_state(), Charger.STATE_RECOVERING)
	c._physics_process(Charger.RECOVERY_DURATION + 0.001)
	assert_eq(c.get_state(), Charger.STATE_IDLE, "recovery ends with player out of range -> idle")


func test_idle_when_no_player() -> void:
	var c: Charger = _make_charger()
	c.set_player(null)
	c._physics_process(0.016)
	assert_eq(c.get_state(), Charger.STATE_IDLE)
	assert_eq(c.velocity, Vector2.ZERO)


# ---- 5: charge direction locked at telegraph start --------------------

func test_charge_direction_locks_at_telegraph_start() -> void:
	var c: Charger = _make_charger()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	c.global_position = Vector2.ZERO
	p.global_position = Vector2(100.0, 0.0)  # to the right
	c.set_player(p)
	# Tick into telegraph.
	c._physics_process(0.016)  # idle -> spotted
	c._physics_process(Charger.SPOTTED_HOLD + 0.001)  # spotted -> telegraphing
	# At telegraph start we lock dir = +x.
	var locked_dir: Vector2 = c.get_charge_dir()
	assert_almost_eq(locked_dir.x, 1.0, 0.001)
	assert_almost_eq(locked_dir.y, 0.0, 0.001)
	# Now move player to the LEFT during telegraph. Charge dir must NOT update.
	p.global_position = Vector2(-100.0, 0.0)
	c._physics_process(Charger.TELEGRAPH_DURATION + 0.001)
	# We're now in charging — direction is still +x.
	assert_eq(c.get_state(), Charger.STATE_CHARGING)
	assert_almost_eq(c.get_charge_dir().x, 1.0, 0.001, "charge dir does NOT redirect during telegraph")


# ---- 6: velocity during charge ---------------------------------------

func test_velocity_during_charge_is_dir_times_speed() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 70, "damage_base": 8, "move_speed": 180.0})
	var c: Charger = _make_charger_with_def(def)
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	c.global_position = Vector2.ZERO
	p.global_position = Vector2(400.0, 0.0)
	c.set_player(p)
	_drive_to_charging(c)
	assert_eq(c.get_state(), Charger.STATE_CHARGING)
	# Push player out so we don't body-hit during the assertion tick.
	p.global_position = Vector2(99999.0, 0.0)
	# One more tick to let charge state set velocity.
	c._physics_process(0.016)
	assert_almost_eq(c.velocity.x, 180.0, 0.5, "charge velocity = +x * 180 px/s")


# ---- 7: vulnerability multiplier ------------------------------------

func test_armored_outside_recovery_takes_1x() -> void:
	var c: Charger = _make_charger()
	# In idle, multiplier is 1.0 — 10 in, 10 out, hp 70->60.
	c.take_damage(10, Vector2.ZERO, null)
	assert_eq(c.get_hp(), 60, "outside recovery: 1x damage")


func test_recovery_takes_2x_damage() -> void:
	var c: Charger = _make_charger()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	c.global_position = Vector2.ZERO
	p.global_position = Vector2(400.0, 0.0)
	c.set_player(p)
	_drive_to_charging(c)
	# Push player far so no body-hit; let charge expire to recovery.
	p.global_position = Vector2(99999.0, 0.0)
	c._physics_process(Charger.CHARGE_MAX_DURATION + 0.001)
	assert_eq(c.get_state(), Charger.STATE_RECOVERING)
	assert_true(c.is_vulnerable())
	# Now hit for 10 — recovery multiplier 2.0 — should land 20 dmg.
	c.take_damage(10, Vector2.ZERO, null)
	assert_eq(c.get_hp(), 50, "recovery: 2x damage (70 - 20 = 50)")


# ---- 8 EDGE: charge-into-wall stops cleanly --------------------------

func test_charge_into_wall_stops_cleanly() -> void:
	# We can't easily author wall tiles in this test, but we can exercise
	# the same code path: when post-slide displacement is below the epsilon
	# during STATE_CHARGING, the charger transitions to recovery and zeros
	# velocity. We simulate that by pinning global_position before and after
	# the move_and_slide to be the same — since a bare CharacterBody2D in a
	# test scene has no collider environment, we'll wedge the position via
	# direct manipulation between physics ticks.
	var c: Charger = _make_charger()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	c.global_position = Vector2.ZERO
	p.global_position = Vector2(400.0, 0.0)
	c.set_player(p)
	_drive_to_charging(c)
	# Push player out of range so no body-hit happens.
	p.global_position = Vector2(99999.0, 0.0)
	# Force the wall-stop code path directly. Simulating an actual collision
	# in headless GUT requires a TileMap; the public observable contract
	# (zeroed velocity + recovery state + no orphan motion) is what we want
	# to assert. We exercise that contract via the wall-stop helper.
	c._end_charge_into_wall()
	assert_eq(c.get_state(), Charger.STATE_RECOVERING, "wall stop transitions to recovery")
	assert_eq(c.velocity, Vector2.ZERO, "wall stop zeros velocity (no orphan motion)")


# ---- 9 EDGE: player dodges out of charge line - no contact -----------

func test_player_dodge_out_of_line_no_contact() -> void:
	# The charger only spawns a charge_hit if the player is within the
	# contact radius of its position. If the player dodges sideways during
	# the charge, we should NOT see a charge_hit_spawned even after the
	# charge expires.
	var c: Charger = _make_charger()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	c.global_position = Vector2.ZERO
	p.global_position = Vector2(400.0, 0.0)  # on the +x line
	c.set_player(p)
	_drive_to_charging(c)
	# Player dodges far off the charge line (sideways). Charge dir is +x;
	# pushing the player to (400, 9999) puts them well outside the contact
	# radius for the entire charge duration.
	p.global_position = Vector2(400.0, 9999.0)
	watch_signals(c)
	c._physics_process(Charger.CHARGE_MAX_DURATION + 0.001)
	assert_signal_not_emitted(c, "charge_hit_spawned", "player dodged the line — no body hit")
	# Charge ended into recovery via timeout (no wall, no hit).
	assert_eq(c.get_state(), Charger.STATE_RECOVERING)


# ---- 10 EDGE: killed mid-charge ------------------------------------

func test_killed_mid_charge_no_orphan_motion() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 30})
	var c: Charger = _make_charger_with_def(def)
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	c.global_position = Vector2.ZERO
	p.global_position = Vector2(400.0, 0.0)
	c.set_player(p)
	_drive_to_charging(c)
	# Push player away so no body-hit happens.
	p.global_position = Vector2(99999.0, 0.0)
	# One charge tick so velocity is set and state is CHARGING.
	c._physics_process(0.016)
	assert_eq(c.get_state(), Charger.STATE_CHARGING)
	assert_gt(c.velocity.x, 0.0, "velocity > 0 mid-charge")
	# Lethal hit. Note: armored multiplier is 1.0 outside recovery, so 30
	# dmg in flat-kills the 30-HP charger.
	watch_signals(c)
	c.take_damage(30, Vector2.ZERO, null)
	assert_eq(c.get_hp(), 0)
	assert_eq(c.get_state(), Charger.STATE_DEAD)
	assert_eq(c.velocity, Vector2.ZERO, "velocity zeroed on death — no orphan motion")
	# Subsequent ticks must not transition state or fire the contact hitbox.
	c._physics_process(0.05)
	c._physics_process(0.5)
	assert_eq(c.get_state(), Charger.STATE_DEAD)
	assert_signal_not_emitted(c, "charge_hit_spawned", "no charge hit fires from a corpse")
	assert_signal_emit_count(c, "mob_died", 1, "mob_died emits exactly once")


## Repro-hardening counterpart to test_killed_mid_charge_no_orphan_motion:
## loops the kill sequence N times in the same test body. With the production
## fix (WALL_STOP_FRAMES_REQUIRED = 2) and `set_physics_process(false)` in
## the helper, every iteration must pass deterministically. CI runs
## 25260213330 + 25260326711 + 25260666771 captured the original flake
## (single-frame sub-epsilon move_and_slide displacement falsely tripping
## the wall-stop branch). If this loop ever flakes again, the regression is
## reproducible — not a one-shot.
func test_killed_mid_charge_zero_velocity_immediate_loop() -> void:
	const ITERATIONS: int = 25
	for i in range(ITERATIONS):
		var def: MobDef = ContentFactory.make_mob_def({"hp_base": 30})
		var c: Charger = _make_charger_with_def(def)
		var p: FakePlayer = FakePlayer.new()
		add_child_autofree(p)
		c.global_position = Vector2.ZERO
		p.global_position = Vector2(400.0, 0.0)
		c.set_player(p)
		_drive_to_charging(c)
		p.global_position = Vector2(99999.0, 0.0)
		c._physics_process(0.016)
		# Pre-kill invariants: charging with non-zero velocity.
		assert_eq(c.get_state(), Charger.STATE_CHARGING, "iter %d: charging pre-kill" % i)
		assert_gt(c.velocity.length(), 0.0, "iter %d: velocity > 0 pre-kill" % i)
		# Kill and assert zero-velocity invariant immediately.
		c.take_damage(30, Vector2.ZERO, null)
		assert_eq(c.get_state(), Charger.STATE_DEAD, "iter %d: dead post-kill" % i)
		assert_eq(c.velocity, Vector2.ZERO, "iter %d: velocity zeroed on death" % i)


# ---- 11: layers per DECISIONS.md ----------------------------------

func test_collision_layer_is_enemy() -> void:
	var c: Charger = _make_charger()
	assert_eq(c.collision_layer, Charger.LAYER_ENEMY, "charger sits on enemy layer (bit 4)")
	assert_eq(c.collision_mask, Charger.LAYER_WORLD | Charger.LAYER_PLAYER, "mask = world + player")


# ---- 12: charge-contact hitbox is enemy team ---------------------

func test_charge_contact_hitbox_is_enemy_team() -> void:
	var c: Charger = _make_charger()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	c.global_position = Vector2.ZERO
	p.global_position = Vector2(20.0, 0.0)  # within contact radius
	c.set_player(p)
	# Drive to charging so the body-contact code path activates.
	_drive_to_charging(c)
	var captured_hb: Array = [null]
	c.charge_hit_spawned.connect(func(hb: Node) -> void:
		captured_hb[0] = hb
	)
	# One charging tick — should trigger _maybe_charge_hit_player.
	c._physics_process(0.016)
	assert_not_null(captured_hb[0], "charge body-hit spawned hitbox in contact range")
	var hb: Hitbox = captured_hb[0]
	assert_eq(hb.team, Hitbox.TEAM_ENEMY, "charger swings on enemy team")
	assert_eq(hb.collision_layer, Hitbox.LAYER_ENEMY_HITBOX, "enemy_hitbox layer (bit 5)")
	assert_eq(hb.collision_mask, Hitbox.LAYER_PLAYER, "masks player (bit 2)")
	# The body-hit also transitions us to recovery.
	assert_eq(c.get_state(), Charger.STATE_RECOVERING)


# ---- 13: apply_mob_def() rebinds at runtime ---------------------

func test_apply_mob_def_rebinds_runtime_stats() -> void:
	var c: Charger = _make_charger()
	var hot_swap: MobDef = ContentFactory.make_mob_def({"hp_base": 200, "damage_base": 25, "move_speed": 240.0})
	c.apply_mob_def(hot_swap)
	assert_eq(c.get_hp(), 200)
	assert_eq(c.get_max_hp(), 200)
	assert_eq(c.damage_base, 25)
	assert_eq(c.charge_speed, 240.0)


# ---- 14: takes damage from player Hitbox ---------------------

func test_takes_damage_from_player_hitbox() -> void:
	var c: Charger = _make_charger()
	var hb: Hitbox = HitboxScript.new()
	hb.configure(15, Vector2.RIGHT * 50.0, 0.1, Hitbox.TEAM_PLAYER, null)
	add_child_autofree(hb)
	hb._try_apply_hit(c)
	# Idle => armored 1.0 multiplier => 70 - 15 = 55.
	assert_eq(c.get_hp(), 55)


# ---- 15: rapid hit spam -> single death ---------------------

func test_rapid_hit_spam_single_death() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 30})
	var c: Charger = _make_charger_with_def(def)
	watch_signals(c)
	for i in 10:
		c.take_damage(50, Vector2.ZERO, null)
	assert_eq(c.get_hp(), 0)
	assert_true(c.is_dead())
	assert_signal_emit_count(c, "mob_died", 1, "death idempotent")
	assert_signal_emit_count(c, "damaged", 1, "damaged blocked once dead")


# ---- 16: knockback skipped during charge ---------------------

func test_knockback_skipped_during_charge() -> void:
	var c: Charger = _make_charger()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	c.global_position = Vector2.ZERO
	p.global_position = Vector2(400.0, 0.0)
	c.set_player(p)
	_drive_to_charging(c)
	p.global_position = Vector2(99999.0, 0.0)
	c._physics_process(0.016)
	var charge_velocity: Vector2 = c.velocity
	# Hit during charge with sideways knockback. Charging should ignore it.
	c.take_damage(5, Vector2(0.0, 500.0), null)
	# Velocity stays approximately the charge velocity (not punted to +y).
	assert_almost_eq(c.velocity.x, charge_velocity.x, 1.0, "charge x-velocity preserved")
	assert_almost_eq(c.velocity.y, charge_velocity.y, 1.0, "charge does not get knocked sideways")


# ---- 17: negative damage clamp ---------------------

func test_negative_damage_does_not_heal() -> void:
	var c: Charger = _make_charger()
	c.take_damage(-100, Vector2.ZERO, null)
	assert_eq(c.get_hp(), 70, "negative dmg clamps to 0 — no incidental healing")
	assert_false(c.is_dead())


# ---- 18: telegraph signal carries direction ---------------------

func test_telegraph_signal_carries_direction() -> void:
	var c: Charger = _make_charger()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	c.global_position = Vector2.ZERO
	p.global_position = Vector2(0.0, 100.0)  # straight down
	c.set_player(p)
	watch_signals(c)
	c._physics_process(0.016)  # idle -> spotted
	c._physics_process(Charger.SPOTTED_HOLD + 0.001)  # spotted -> telegraphing
	assert_signal_emitted(c, "charge_telegraph_started")
	var args: Array = get_signal_parameters(c, "charge_telegraph_started", 0)
	assert_not_null(args)
	var dir: Vector2 = args[0]
	assert_almost_eq(dir.x, 0.0, 0.001)
	assert_almost_eq(dir.y, 1.0, 0.001, "telegraph direction toward player")
