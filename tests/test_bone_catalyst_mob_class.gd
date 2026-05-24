extends GutTest
## Tests for BoneCatalyst mob class — paired with `scripts/mobs/BoneCatalyst.gd`
## per the testing bar (`team/TESTING_BAR.md` §Devon-and-Drew).
##
## Stage 3 scope (W3-T7 ticket 86c9y7ygj):
##   - Mob-class smoke (instantiable, state-machine boots).
##   - Channel-windup → slam-strike → recover progression (chase → channeling
##     → attacking → chasing loop).
##   - Differentiation pins vs S1 Grunt + S1 Charger (channel-windup duration,
##     no-projectile, no-charge-line semantics).
##   - Diagnostic trace contract (state_changed signal fires per Drew persona
##     rule "No new mob class without trace instrumentation").
##   - No USER WARNING: emissions during normal operation.

const BoneCatalystScript: Script = preload("res://scripts/mobs/BoneCatalyst.gd")
const GruntScript: Script = preload("res://scripts/mobs/Grunt.gd")
const ChargerScript: Script = preload("res://scripts/mobs/Charger.gd")
const MobDefScript: Script = preload("res://scripts/content/MobDef.gd")
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


func _make_bruiser() -> BoneCatalyst:
	var b: BoneCatalyst = BoneCatalystScript.new()
	add_child_autofree(b)
	return b


func _make_bruiser_with_def(def: MobDef) -> BoneCatalyst:
	var b: BoneCatalyst = BoneCatalystScript.new()
	b.mob_def = def
	add_child_autofree(b)
	return b


# ---- 1: spawn HP from MobDef + spec defaults --------------------------


func test_spawns_with_full_hp_from_mobdef() -> void:
	var def: MobDef = ContentFactory.make_mob_def(
		{"hp_base": 70, "damage_base": 5, "move_speed": 50.0}
	)
	var b: BoneCatalyst = _make_bruiser_with_def(def)
	assert_eq(b.get_hp(), 70, "starts at hp_base")
	assert_eq(b.get_max_hp(), 70)
	assert_eq(b.damage_base, 5)
	assert_eq(b.move_speed, 50.0)
	assert_false(b.is_dead())


func test_default_stats_when_no_mobdef() -> void:
	var b: BoneCatalyst = _make_bruiser()
	# Spec defaults: 70 HP, 5 damage, 50 move (S2 bruiser baseline).
	assert_eq(b.get_hp(), 70)
	assert_eq(b.get_max_hp(), 70)
	assert_eq(b.damage_base, 5)
	assert_almost_eq(b.move_speed, 50.0, 0.001)


# ---- 2: damage + death contract --------------------------------------


func test_damaged_signal_carries_payload() -> void:
	var b: BoneCatalyst = _make_bruiser()
	watch_signals(b)
	var src: Node2D = autofree(Node2D.new())
	b.take_damage(10, Vector2.ZERO, src)
	assert_signal_emitted_with_parameters(b, "damaged", [10, 60, src])


func test_death_emits_mob_died_once_with_compatible_payload() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 15})
	var b: BoneCatalyst = _make_bruiser_with_def(def)
	b.global_position = Vector2(123.0, 45.0)
	watch_signals(b)
	b.take_damage(15, Vector2.ZERO, null)
	assert_eq(b.get_hp(), 0)
	assert_true(b.is_dead())
	assert_eq(b.get_state(), BoneCatalyst.STATE_DEAD)
	assert_signal_emitted(b, "mob_died")
	var args: Array = get_signal_parameters(b, "mob_died", 0)
	assert_not_null(args)
	assert_eq(args[0], b)
	assert_almost_eq(args[1].x, 123.0, 0.001)
	assert_almost_eq(args[1].y, 45.0, 0.001)
	assert_eq(args[2], def, "mob_died carries MobDef")


func test_rapid_hit_spam_single_death() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 20})
	var b: BoneCatalyst = _make_bruiser_with_def(def)
	watch_signals(b)
	for i in 10:
		b.take_damage(50, Vector2.ZERO, null)
	assert_eq(b.get_hp(), 0)
	assert_true(b.is_dead())
	assert_signal_emit_count(b, "mob_died", 1)
	assert_signal_emit_count(b, "damaged", 1)


func test_negative_damage_does_not_heal() -> void:
	var b: BoneCatalyst = _make_bruiser()
	b.take_damage(-100, Vector2.ZERO, null)
	assert_eq(b.get_hp(), 70, "negative dmg clamps to 0 — no incidental healing")
	assert_false(b.is_dead())


# ---- 3: state-machine boot + chase → channel → strike path ------------


func test_initial_state_is_idle() -> void:
	var b: BoneCatalyst = _make_bruiser()
	assert_eq(b.get_state(), BoneCatalyst.STATE_IDLE)


func test_chase_engages_when_player_inside_aggro_radius() -> void:
	var b: BoneCatalyst = _make_bruiser()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	b.global_position = Vector2.ZERO
	# Outside SLAM_RANGE but inside AGGRO_RADIUS — should enter CHASING.
	p.global_position = Vector2(100.0, 0.0)
	b.set_player(p)
	b._physics_process(0.016)
	assert_eq(b.get_state(), BoneCatalyst.STATE_CHASING)
	assert_gt(b.velocity.length(), 0.0, "chasing moves at move_speed")


func test_channel_engages_when_player_inside_slam_range() -> void:
	var b: BoneCatalyst = _make_bruiser()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	b.global_position = Vector2.ZERO
	# Inside SLAM_RANGE (32 px) — should enter CHANNELING.
	p.global_position = Vector2(20.0, 0.0)
	b.set_player(p)
	watch_signals(b)
	b._physics_process(0.016)
	assert_eq(b.get_state(), BoneCatalyst.STATE_CHANNELING)
	assert_true(b.is_channeling(), "is_channeling helper reads true")
	assert_signal_emitted(b, "channel_started")


func test_channel_completes_to_slam_strike() -> void:
	var b: BoneCatalyst = _make_bruiser()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	b.global_position = Vector2.ZERO
	p.global_position = Vector2(20.0, 0.0)
	b.set_player(p)
	# Drive into CHANNELING.
	b._physics_process(0.016)
	assert_eq(b.get_state(), BoneCatalyst.STATE_CHANNELING)
	# Tick past CHANNEL_DURATION — should fire the slam strike + transition
	# to ATTACKING (post-strike recovery).
	watch_signals(b)
	b._physics_process(BoneCatalyst.CHANNEL_DURATION + 0.001)
	assert_eq(b.get_state(), BoneCatalyst.STATE_ATTACKING)
	assert_signal_emitted(b, "swing_spawned")
	var args: Array = get_signal_parameters(b, "swing_spawned", 0)
	assert_eq(args[0], BoneCatalyst.SWING_KIND_SLAM, "swing kind is &\"slam\"")


func test_recovery_returns_to_chasing() -> void:
	var b: BoneCatalyst = _make_bruiser()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	b.global_position = Vector2.ZERO
	p.global_position = Vector2(20.0, 0.0)
	b.set_player(p)
	b._physics_process(0.016)
	b._physics_process(BoneCatalyst.CHANNEL_DURATION + 0.001)
	assert_eq(b.get_state(), BoneCatalyst.STATE_ATTACKING)
	# Move player away so chase resumes (don't re-trigger channel immediately).
	p.global_position = Vector2(200.0, 0.0)
	# Tick past ATTACK_RECOVERY — should transition back to CHASING.
	b._physics_process(BoneCatalyst.ATTACK_RECOVERY + 0.001)
	# Tick once more so the chase-state handler runs after recovery zeroed.
	b._physics_process(0.016)
	assert_eq(b.get_state(), BoneCatalyst.STATE_CHASING)


# ---- 4: channel direction drift — re-resolved at strike time ---------


func test_channel_strike_direction_re_resolves_at_fire_time() -> void:
	# Direction at channel-start may drift if player moves during the 0.6s
	# window. Strike should re-resolve toward player position at fire time.
	# (Same shape as Grunt._finish_light_telegraph contract.)
	var b: BoneCatalyst = _make_bruiser()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	b.global_position = Vector2.ZERO
	p.global_position = Vector2(20.0, 0.0)  # initial east
	b.set_player(p)
	b._physics_process(0.016)
	assert_eq(b.get_state(), BoneCatalyst.STATE_CHANNELING)
	# Move player during channel — drift north.
	p.global_position = Vector2(0.0, -20.0)
	watch_signals(b)
	b._physics_process(BoneCatalyst.CHANNEL_DURATION + 0.001)
	# swing_spawned fired; hitbox position should be re-resolved toward NEW
	# player position (north), not the original east.
	var args: Array = get_signal_parameters(b, "swing_spawned", 0)
	assert_not_null(args)
	var hb: Node = args[1] as Node
	assert_not_null(hb)
	# hb.position is in BoneCatalyst-local space, dir * SLAM_HITBOX_REACH.
	# A north-resolved dir should produce a negative y offset.
	assert_lt((hb as Node2D).position.y, 0.0, "strike direction re-resolves toward NEW player pos")


# ---- 5: killed mid-channel — no slam on corpse ------------------------


func test_killed_mid_channel_no_slam() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 25})
	var b: BoneCatalyst = _make_bruiser_with_def(def)
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	b.global_position = Vector2.ZERO
	p.global_position = Vector2(20.0, 0.0)
	b.set_player(p)
	b._physics_process(0.016)
	assert_eq(b.get_state(), BoneCatalyst.STATE_CHANNELING)
	watch_signals(b)
	b.take_damage(25, Vector2.ZERO, null)
	assert_eq(b.get_state(), BoneCatalyst.STATE_DEAD)
	# Tick well past where the slam would have fired.
	b._physics_process(BoneCatalyst.CHANNEL_DURATION + 0.5)
	b._physics_process(0.5)
	assert_signal_not_emitted(b, "swing_spawned")


# ---- 6: layers per DECISIONS.md ---------------------------------------


func test_collision_layer_is_enemy() -> void:
	var b: BoneCatalyst = _make_bruiser()
	assert_eq(b.collision_layer, BoneCatalyst.LAYER_ENEMY)
	assert_eq(b.collision_mask, BoneCatalyst.LAYER_WORLD | BoneCatalyst.LAYER_PLAYER)


# ---- 7: state_changed signal contract (Drew persona instrumentation rule) ----


func test_state_changed_emits_on_transition() -> void:
	# Drew persona rule: "No new mob class without trace instrumentation."
	# `state_changed` is the Godot signal half (combat-trace shim is HTML5
	# only). A future Playwright spec asserts on the [combat-trace] line; this
	# GUT test pins the signal contract so a future refactor that drops the
	# emit fails fast in headless CI.
	var b: BoneCatalyst = _make_bruiser()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	b.global_position = Vector2.ZERO
	p.global_position = Vector2(100.0, 0.0)
	b.set_player(p)
	watch_signals(b)
	b._physics_process(0.016)
	assert_signal_emitted_with_parameters(
		b, "state_changed", [BoneCatalyst.STATE_IDLE, BoneCatalyst.STATE_CHASING]
	)


# ---- 8: apply_mob_def() rebinds runtime stats ------------------------


func test_apply_mob_def_rebinds_runtime_stats() -> void:
	var b: BoneCatalyst = _make_bruiser()
	var hot_swap: MobDef = ContentFactory.make_mob_def(
		{"hp_base": 100, "damage_base": 20, "move_speed": 90.0}
	)
	b.apply_mob_def(hot_swap)
	assert_eq(b.get_hp(), 100)
	assert_eq(b.get_max_hp(), 100)
	assert_eq(b.damage_base, 20)
	assert_eq(b.move_speed, 90.0)


# ---- 9: scene round-trip + mob_def resolves from .tres ---------------


func test_scene_instantiates_clean_with_mob_def() -> void:
	# Pin the production scene + .tres path. Future renames must update both.
	var scene: PackedScene = load("res://scenes/mobs/BoneCatalyst.tscn") as PackedScene
	assert_not_null(scene, "scene loads")
	var def: MobDef = load("res://resources/mobs/bone_catalyst.tres") as MobDef
	assert_not_null(def, "mob_def loads")
	assert_eq(def.id, &"bone_catalyst")
	assert_eq(def.hp_base, 70)
	assert_eq(def.damage_base, 5)
	assert_eq(def.ai_behavior_tag, &"melee_bruiser")
	var inst: BoneCatalyst = scene.instantiate() as BoneCatalyst
	assert_not_null(inst, "scene instantiates as BoneCatalyst")
	inst.mob_def = def
	add_child_autofree(inst)
	assert_eq(inst.get_hp(), 70, "HP applied from .tres at _ready")


# ---- 10: S1-melee-differentiation pins (Uma §5.5 contract) -----------


func test_channel_duration_is_longer_than_grunt_light_telegraph() -> void:
	# Uma §5.5 contract — BoneCatalyst's stationary channel-pose is a LONGER
	# windup than Grunt's 1-frame raised-blade tilt. The longer window pairs
	# with the "I am gathering pressure" reading (player has time to dodge
	# and the brass-mask center IS the focal point).
	assert_gt(
		BoneCatalyst.CHANNEL_DURATION,
		GruntScript.LIGHT_TELEGRAPH_DURATION,
		"BoneCatalyst channel-windup must be longer than Grunt light telegraph"
	)


func test_channel_duration_is_in_uma_spec_window() -> void:
	# Uma §5.5 verbatim: "0.5-0.7 s windup window — long enough that player can
	# dodge, short enough that it doesn't read as 'stunned.'" Pin the window
	# so a future tune that crosses outside it surfaces here.
	assert_gte(
		BoneCatalyst.CHANNEL_DURATION,
		0.5,
		"channel-windup must be >= 0.5s (Uma §5.5 lower bound)"
	)
	assert_lte(
		BoneCatalyst.CHANNEL_DURATION,
		0.7,
		"channel-windup must be <= 0.7s (Uma §5.5 upper bound — too long reads as stunned)"
	)


func test_no_projectile_state_unlike_shooter_family() -> void:
	# Uma §5.5 contract — BoneCatalyst is melee, weaponless-but-armored-
	# forearms. Distinct from S1 Shooter/SunkenScholar which are ranged
	# (telegraph → fire projectile → recover). Pin that the state-machine
	# has NO projectile-fire state.
	var b: BoneCatalyst = _make_bruiser()
	# Iterate every reachable state via _set_state — none should be a
	# projectile-fire / aim / firing state.
	var all_states: Array[StringName] = [
		BoneCatalyst.STATE_IDLE,
		BoneCatalyst.STATE_CHASING,
		BoneCatalyst.STATE_CHANNELING,
		BoneCatalyst.STATE_ATTACKING,
		BoneCatalyst.STATE_DEAD,
	]
	# Sanity: no aim / firing / projectile-named state in the public state-list.
	for s in all_states:
		var sname: String = String(s)
		assert_false(
			sname == "aiming" or sname == "firing" or sname == "post_fire_recovery",
			"BoneCatalyst state %s must not be a ranged-attack state" % sname
		)
	# No projectile_fired signal exists (only `swing_spawned` for the slam).
	assert_false(
		b.has_signal("projectile_fired"),
		"BoneCatalyst is melee-only — no projectile_fired signal"
	)
	# No aim_started signal — channel_started is the telegraph signal.
	assert_false(b.has_signal("aim_started"), "BoneCatalyst uses channel_started, not aim_started")
	assert_true(b.has_signal("channel_started"))


func test_no_charge_dash_unlike_charger() -> void:
	# Uma §5.5 contract — BoneCatalyst telegraphs via a STATIONARY channel
	# pose. Distinct from S1 Charger which telegraphs via rear-back + then
	# DASHES in a charge-line. Pin that BoneCatalyst has no charge state +
	# no charge_telegraph_started signal + no get_charge_dir API.
	var b: BoneCatalyst = _make_bruiser()
	assert_false(
		b.has_signal("charge_telegraph_started"),
		"BoneCatalyst telegraphs via channel_started, not charge_telegraph_started"
	)
	assert_false(b.has_signal("charge_hit_spawned"), "BoneCatalyst has no charge-hit signal")
	assert_false(b.has_method("get_charge_dir"), "BoneCatalyst has no charge-direction API")
	# Verify channel is STATIONARY — drive into the channel state, then tick
	# physics; velocity must stay at ZERO during the windup (contrast with
	# Charger's STATE_CHARGING which moves at charge_speed).
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	b.global_position = Vector2.ZERO
	p.global_position = Vector2(20.0, 0.0)
	b.set_player(p)
	b._physics_process(0.016)
	assert_eq(b.get_state(), BoneCatalyst.STATE_CHANNELING)
	# Tick mid-windup; velocity stays zero.
	b._physics_process(0.05)
	assert_eq(b.velocity, Vector2.ZERO, "channel state is stationary — no dash motion")


func test_move_speed_is_slower_than_grunt() -> void:
	# Uma §5.5: "bruiser plodding gait" — slower than Grunt to read as heavy.
	# Pin the differentiation so a future tune doesn't quietly equalise it.
	# (Default values, not MobDef-injected — the spec-default move speed.)
	var b: BoneCatalyst = _make_bruiser()
	var g: Grunt = GruntScript.new()
	add_child_autofree(g)
	assert_lt(b.move_speed, g.move_speed, "BoneCatalyst plods — slower than Grunt")


func test_hp_is_higher_than_grunt() -> void:
	# Spec contract — BoneCatalyst has higher HP to compensate for the longer
	# windup (player has more dodge opportunity → bruiser must eat more hits
	# before going down). Pin so a future balance pass doesn't quietly equalise.
	var b: BoneCatalyst = _make_bruiser()
	var g: Grunt = GruntScript.new()
	add_child_autofree(g)
	assert_gt(b.hp_max, g.hp_max, "BoneCatalyst HP > Grunt HP — windup compensation")


# ---- 11: hit-flash branches resolve cleanly --------------------------


func test_hit_flash_resolves_color_rect_branch_for_placeholder_sprite() -> void:
	# The placeholder scene uses a ColorRect "Sprite" child. Pin that the
	# 3-branch resolver picks the ColorRect branch (M3W-3 convention).
	var scene: PackedScene = load("res://scenes/mobs/BoneCatalyst.tscn") as PackedScene
	var inst: BoneCatalyst = scene.instantiate() as BoneCatalyst
	add_child_autofree(inst)
	# Drive a hit to force resolver init.
	inst.take_damage(1, Vector2.ZERO, null)
	# Reflect — the resolver should land on the ColorRect branch.
	assert_true(inst._hit_flash_uses_sprite, "ColorRect branch active")
	assert_false(
		inst._hit_flash_uses_animated_sprite, "AnimatedSprite2D branch inactive (placeholder)"
	)


# ---- 12: HIT_FLASH_TINT is the cross-stratum constant ----------------


func test_hit_flash_tint_matches_cross_stratum_constant() -> void:
	# Per `palette-stratum-2.md` §2 + `combat-architecture.md` § "M3W-1
	# realized implementation": every mob's hit-flash reads the same wash so
	# "I hit something" is unambiguous. Pin that BoneCatalyst's tint matches
	# Grunt's (the canonical reference).
	assert_eq(
		BoneCatalyst.HIT_FLASH_TINT,
		GruntScript.HIT_FLASH_TINT,
		"HIT_FLASH_TINT is cross-stratum constant — must match Grunt"
	)
