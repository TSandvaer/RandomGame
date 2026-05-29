# gdlint:disable=max-public-methods
# GUT test class — high test_* count IS the design (one test per scenario).
extends GutTest
## Tests for ArchiveSentinel — paired with `scripts/mobs/ArchiveSentinel.gd`.
##
## Coverage per W3-T7 Stage 5 dispatch (ticket 86c9y7ygj Part D) + testing bar:
##   1. Spawns with full HP, defaults applied when no MobDef.
##   2. MobDef-driven hp_base / damage_base / move_speed_base applied at spawn.
##   3. Stationary — move_speed_base = 0.0 and velocity stays Vector2.ZERO.
##   4. Phase 1: cast attack only (no slam regardless of player distance).
##   5. Phase 2 unlocks slam at ~50% HP threshold.
##   6. Phase transition fires `phase_changed(2)` exactly once even under
##      hit-spam (idempotent latch).
##   7. STATE_DORMANT ignores damage (intro fairness).
##   8. STATE_WAKING ignores damage (extends intro fairness through wake-anim).
##   9. STATE_PHASE_TRANSITION ignores damage (stagger immune).
##  10. boss_died emits exactly once on death.
##  11. Knockback is REJECTED — construct stays on its plinth (Stage 5 design
##      departure from S1 Boss precedent).
##  12. Layers/masks set per DECISIONS.md (enemy collision layer).
##  13. wake() is idempotent (calling twice from DORMANT is no-op on the
##      second call).
##  14. Cast hitbox spawns at the captured target position, not the
##      construct position — player who moves during windup naturally dodges.

const SentinelScript: Script = preload("res://scripts/mobs/ArchiveSentinel.gd")
const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")

# ---- Test isolation ---------------------------------------------------
# ArchiveSentinel fires TimeScaleDirector requests on hit / die / phase-
# transition. Tests that take the boss to 0 HP or cross the 50% boundary
# leak director state into subsequent tests. Reset on both ends.


func before_each() -> void:
	var d: Node = Engine.get_main_loop().root.get_node_or_null("TimeScaleDirector")
	if d != null and d.has_method("reset"):
		d.reset()
	Engine.time_scale = 1.0
	_reset_boss_hp_mult()


func after_each() -> void:
	var d: Node = Engine.get_main_loop().root.get_node_or_null("TimeScaleDirector")
	if d != null and d.has_method("reset"):
		d.reset()
	Engine.time_scale = 1.0
	# boss_hp_mult is a global on the DebugFlags autoload; reset so the nerf
	# pin below can't leak its 0.2 multiplier into sibling tests.
	_reset_boss_hp_mult()


func _reset_boss_hp_mult() -> void:
	var df: Node = Engine.get_main_loop().root.get_node_or_null("DebugFlags")
	if df != null and df.has_method("reset_boss_hp_mult_for_test"):
		df.reset_boss_hp_mult_for_test()


# ---- Helpers ----------------------------------------------------------


class FakePlayer:
	extends Node2D
	# Dummy player target. The boss only reads global_position.


func _make_sentinel() -> ArchiveSentinel:
	var b: ArchiveSentinel = SentinelScript.new()
	b.skip_intro_for_tests = true  # start in IDLE_ACTIVE not DORMANT
	add_child_autofree(b)
	return b


func _make_sentinel_with_def(def: MobDef) -> ArchiveSentinel:
	var b: ArchiveSentinel = SentinelScript.new()
	b.skip_intro_for_tests = true
	b.mob_def = def
	add_child_autofree(b)
	return b


func _make_dormant_sentinel() -> ArchiveSentinel:
	# Default skip_intro_for_tests = false → starts DORMANT
	var b: ArchiveSentinel = SentinelScript.new()
	add_child_autofree(b)
	return b


func _hit(b: ArchiveSentinel, dmg: int) -> void:
	b.take_damage(dmg, Vector2.ZERO, null)


# ---- 1: full HP at spawn + bare defaults ------------------------------


func test_spawns_with_full_hp_from_mobdef() -> void:
	var def: MobDef = ContentFactory.make_mob_def(
		{"hp_base": 700, "damage_base": 14, "move_speed": 0.0}
	)
	var b: ArchiveSentinel = _make_sentinel_with_def(def)
	assert_eq(b.get_hp(), 700, "starts at hp_base")
	assert_eq(b.get_max_hp(), 700, "max_hp = hp_base at spawn")
	assert_eq(b.damage_base, 14)
	assert_eq(b.move_speed_base, 0.0, "stationary — move_speed_base = 0")
	assert_eq(b.get_phase(), ArchiveSentinel.PHASE_1)
	assert_false(b.is_dead())


func test_default_hp_when_no_mobdef() -> void:
	var b: ArchiveSentinel = _make_sentinel()
	# Per spec defaults: 700 HP, 14 damage, 0.0 move_speed (stationary).
	assert_eq(b.get_hp(), 700)
	assert_eq(b.get_max_hp(), 700)
	assert_eq(b.damage_base, 14)
	assert_eq(b.move_speed_base, 0.0)


# ---- 2: real archive_sentinel.tres values ----------------------------


func test_archive_sentinel_mobdef_loads_with_700hp_14dmg() -> void:
	# Pin the authored TRES values so a future content edit surfaces in CI
	# before silently shipping a balance change.
	var def: MobDef = load("res://resources/mobs/archive_sentinel.tres") as MobDef
	assert_not_null(def, "archive_sentinel.tres loads")
	assert_eq(def.id, &"archive_sentinel")
	assert_eq(def.display_name, "Archive Sentinel")
	assert_eq(def.hp_base, 700)
	assert_eq(def.damage_base, 14)
	assert_eq(def.move_speed, 0.0, "stationary boss — move_speed = 0")
	assert_eq(def.ai_behavior_tag, &"archive_sentinel")
	assert_eq(def.xp_reward, 350)
	assert_not_null(def.loot_table, "loot_table wired to boss_drops.tres")


# ---- 2b: boss_hp_mult soak-nerf parity (closes the parity gap) --------
# Mirrors Stratum1Boss — `?boss_hp_mult=N` URL param scales hp_base at spawn
# so Sponsor soak can reach phase-2 mechanics in far fewer hits. Headless GUT
# injects via DebugFlags.set_boss_hp_mult_for_test (the bridge path is
# unreachable from GUT — OS.has_feature("web") is always false). See
# .claude/docs/html5-export.md § "New-boss soak acceleration".


func _set_boss_hp_mult(mult: float) -> void:
	var df: Node = Engine.get_main_loop().root.get_node_or_null("DebugFlags")
	assert_not_null(df, "DebugFlags autoload present for boss_hp_mult injection")
	if df != null:
		df.set_boss_hp_mult_for_test(mult)


func test_boss_hp_mult_scales_mobdef_hp_base() -> void:
	# boss_hp_mult=0.2 ⟹ hp_max == authored hp_base * 0.2.
	_set_boss_hp_mult(0.2)
	var def: MobDef = ContentFactory.make_mob_def(
		{"hp_base": 700, "damage_base": 14, "move_speed": 0.0}
	)
	# Construct AFTER the mult is set so _apply_mob_def reads it at _ready.
	var b: ArchiveSentinel = _make_sentinel_with_def(def)
	var expected: int = int(round(700.0 * 0.2))  # 140
	assert_eq(b.get_max_hp(), expected, "hp_max scaled by boss_hp_mult=0.2")
	assert_eq(b.get_hp(), expected, "hp_current scaled by boss_hp_mult=0.2")
	assert_eq(b.damage_base, 14, "damage NOT scaled by boss_hp_mult")


func test_boss_hp_mult_scales_bare_default_hp() -> void:
	# The bare-instance fallback (no MobDef) also honors the multiplier so
	# tests can exercise the nerf without supplying a def.
	_set_boss_hp_mult(0.2)
	var b: ArchiveSentinel = _make_sentinel()
	var expected: int = int(round(700.0 * 0.2))  # 140
	assert_eq(b.get_max_hp(), expected, "bare default hp_max scaled by boss_hp_mult")
	assert_eq(b.get_hp(), expected, "bare default hp_current scaled by boss_hp_mult")


func test_boss_hp_mult_default_is_no_op() -> void:
	# Default (1.0) leaves the authored hp_base unchanged — the production
	# play path with no URL param.
	var def: MobDef = ContentFactory.make_mob_def(
		{"hp_base": 700, "damage_base": 14, "move_speed": 0.0}
	)
	var b: ArchiveSentinel = _make_sentinel_with_def(def)
	assert_eq(b.get_max_hp(), 700, "no-mult default leaves authored hp_base intact")


# ---- 3: stationary — velocity stays zero across attack states --------


func test_velocity_stays_zero_in_idle_active() -> void:
	var b: ArchiveSentinel = _make_sentinel()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	b.global_position = Vector2.ZERO
	p.global_position = Vector2(1000.0, 0.0)  # out of AGGRO_RADIUS (640)
	b.set_player(p)
	b._physics_process(0.016)
	assert_eq(b.get_state(), ArchiveSentinel.STATE_IDLE_ACTIVE, "out of range → idle")
	assert_eq(b.velocity, Vector2.ZERO, "stationary — velocity zero")


func test_velocity_stays_zero_during_cast_telegraph() -> void:
	var b: ArchiveSentinel = _make_sentinel()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	b.global_position = Vector2.ZERO
	p.global_position = Vector2(100.0, 0.0)  # in range, triggers cast
	b.set_player(p)
	b._physics_process(0.016)
	assert_eq(b.get_state(), ArchiveSentinel.STATE_CAST, "in range, cooldown clear → cast")
	assert_eq(b.velocity, Vector2.ZERO, "stationary during cast windup")


# ---- 4: Phase 1 — cast only, never slam ------------------------------


func test_phase1_uses_cast_at_short_range() -> void:
	var b: ArchiveSentinel = _make_sentinel()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	b.global_position = Vector2.ZERO
	# Player inside slam radius (96) — but phase 1 should still pick cast.
	p.global_position = Vector2(50.0, 0.0)
	b.set_player(p)
	b._physics_process(0.016)
	assert_eq(
		b.get_state(),
		ArchiveSentinel.STATE_CAST,
		"phase 1 picks cast even when player is in slam radius"
	)
	assert_ne(
		b.get_state(),
		ArchiveSentinel.STATE_SLAM_TELEGRAPH,
		"phase 1 does NOT use slam"
	)


func test_phase1_cast_fires_swing_spawned_with_cast_kind() -> void:
	var b: ArchiveSentinel = _make_sentinel()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	b.global_position = Vector2.ZERO
	p.global_position = Vector2(150.0, 0.0)
	b.set_player(p)
	# First tick — boss enters cast.
	b._physics_process(0.016)
	assert_eq(b.get_state(), ArchiveSentinel.STATE_CAST)
	# Tick past windup — cast fires.
	watch_signals(b)
	b._physics_process(ArchiveSentinel.CAST_TELEGRAPH_DURATION + 0.01)
	assert_eq(b.get_state(), ArchiveSentinel.STATE_CAST_RECOVERY)
	assert_signal_emitted(b, "swing_spawned")
	var params: Array = get_signal_parameters(b, "swing_spawned", 0)
	assert_eq(params[0], ArchiveSentinel.SWING_KIND_CAST, "swing_spawned carries CAST kind")


# ---- 5: Phase transition at 50% fires phase_changed(2) ----------------


func test_phase_transition_at_50pct_emits_phase_changed_2() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 700})
	var b: ArchiveSentinel = _make_sentinel_with_def(def)
	watch_signals(b)
	# 700 × 0.50 = 350. Damage 350 takes us from 700 to 350 = exactly the threshold.
	_hit(b, 350)
	assert_eq(b.get_hp(), 350)
	assert_eq(b.get_state(), ArchiveSentinel.STATE_PHASE_TRANSITION)
	# Tick past the transition window — phase_changed fires on completion.
	b._physics_process(ArchiveSentinel.PHASE_TRANSITION_DURATION + 0.01)
	assert_signal_emitted(b, "phase_changed")
	var params: Array = get_signal_parameters(b, "phase_changed", 0)
	assert_eq(params[0], 2, "phase_changed carries 2")
	assert_eq(b.get_phase(), ArchiveSentinel.PHASE_2)


func test_phase_transition_idempotent_under_hit_spam() -> void:
	# Drive boss into phase 2 with two hits straddling the boundary — should
	# emit phase_changed exactly once. (Both hits land while NOT in
	# STATE_PHASE_TRANSITION because the first hit causes the transition,
	# but the second hit lands during the transition window which we expect
	# to be ignored entirely.)
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 700})
	var b: ArchiveSentinel = _make_sentinel_with_def(def)
	watch_signals(b)
	_hit(b, 350)  # 700 → 350 = boundary, latches phase 2
	# Second hit during STATE_PHASE_TRANSITION — must be ignored (stagger immune).
	_hit(b, 100)
	assert_eq(b.get_hp(), 350, "stagger-immune during phase transition window — HP unchanged")
	# Drain the transition window.
	b._physics_process(ArchiveSentinel.PHASE_TRANSITION_DURATION + 0.01)
	assert_signal_emit_count(
		b, "phase_changed", 1, "phase_changed fires exactly once even under hit-spam"
	)


# ---- 6: Phase 2 unlocks slam at short range --------------------------


func test_phase2_picks_slam_at_short_range() -> void:
	var b: ArchiveSentinel = _make_sentinel()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	b.set_player(p)
	# Drive into phase 2 (full damage range from 700 to 350 boundary).
	_hit(b, 350)
	assert_eq(b.get_state(), ArchiveSentinel.STATE_PHASE_TRANSITION)
	b._physics_process(ArchiveSentinel.PHASE_TRANSITION_DURATION + 0.01)
	assert_eq(b.get_phase(), ArchiveSentinel.PHASE_2)
	# Position player inside slam radius. Phase 2 with cooldown-clear should
	# pick slam over cast.
	b.global_position = Vector2.ZERO
	p.global_position = Vector2(60.0, 0.0)  # < SLAM_HITBOX_RADIUS (96)
	b._physics_process(0.016)
	assert_eq(
		b.get_state(),
		ArchiveSentinel.STATE_SLAM_TELEGRAPH,
		"phase 2 picks slam at short range"
	)


func test_phase2_uses_cast_at_long_range_even_when_slam_unlocked() -> void:
	var b: ArchiveSentinel = _make_sentinel()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	b.set_player(p)
	# Drive into phase 2.
	_hit(b, 350)
	b._physics_process(ArchiveSentinel.PHASE_TRANSITION_DURATION + 0.01)
	assert_eq(b.get_phase(), ArchiveSentinel.PHASE_2)
	# Position player outside slam radius but inside AGGRO_RADIUS.
	b.global_position = Vector2.ZERO
	p.global_position = Vector2(300.0, 0.0)  # > SLAM_HITBOX_RADIUS, < AGGRO
	b._physics_process(0.016)
	assert_eq(
		b.get_state(), ArchiveSentinel.STATE_CAST, "phase 2 falls back to cast at long range"
	)


# ---- 7: Damage-immunity gates -----------------------------------------


func test_dormant_ignores_damage() -> void:
	var b: ArchiveSentinel = _make_dormant_sentinel()
	assert_true(b.is_dormant(), "starts DORMANT (intro fairness)")
	var hp_before: int = b.get_hp()
	_hit(b, 100)
	assert_eq(b.get_hp(), hp_before, "DORMANT rejects damage entirely")


func test_waking_ignores_damage() -> void:
	var b: ArchiveSentinel = _make_dormant_sentinel()
	b.wake()
	assert_true(b.is_waking(), "wake() transitions DORMANT → WAKING")
	var hp_before: int = b.get_hp()
	_hit(b, 100)
	assert_eq(
		b.get_hp(),
		hp_before,
		"WAKING rejects damage (extends intro-fairness through standup)"
	)


func test_phase_transition_ignores_damage() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 700})
	var b: ArchiveSentinel = _make_sentinel_with_def(def)
	_hit(b, 350)  # 700 → 350, enters STATE_PHASE_TRANSITION
	assert_true(b.is_in_phase_transition())
	var hp_during: int = b.get_hp()
	_hit(b, 99)
	assert_eq(
		b.get_hp(),
		hp_during,
		"PHASE_TRANSITION rejects damage (stagger immune)"
	)


# ---- 8: boss_died emits exactly once ---------------------------------


func test_boss_died_emits_exactly_once() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 100})
	var b: ArchiveSentinel = _make_sentinel_with_def(def)
	watch_signals(b)
	# Kill in two hits straddling the phase boundary, with one extra
	# post-fatal hit to verify idempotence.
	_hit(b, 50)  # 100 → 50 = phase 2 boundary
	b._physics_process(ArchiveSentinel.PHASE_TRANSITION_DURATION + 0.01)
	_hit(b, 50)  # 50 → 0 (fatal)
	assert_true(b.is_dead())
	_hit(b, 100)  # post-fatal — should be no-op
	assert_signal_emit_count(b, "boss_died", 1, "boss_died fires exactly once")


# ---- 9: Knockback is REJECTED (Stage 5 design departure) -------------


func test_knockback_does_not_set_velocity() -> void:
	# Sentinel is rooted to plinth — knockback must NOT translate to
	# velocity (unlike S1 Boss which DOES apply knockback). Visual grammar:
	# "the construct does not flinch".
	var b: ArchiveSentinel = _make_sentinel()
	b.take_damage(10, Vector2(500.0, -500.0), null)
	assert_eq(
		b.velocity, Vector2.ZERO, "knockback ignored — construct stays on its plinth"
	)


# ---- 10: Layers + masks ----------------------------------------------


func test_collision_layer_is_enemy() -> void:
	var b: ArchiveSentinel = _make_sentinel()
	# Enemy = bit 4 = 8. (LAYER_ENEMY = 1 << 3.)
	assert_eq(
		b.collision_layer,
		ArchiveSentinel.LAYER_ENEMY,
		"collision_layer = enemy (bit 4)"
	)


func test_collision_mask_is_world_plus_player() -> void:
	var b: ArchiveSentinel = _make_sentinel()
	# World (bit 1) + player (bit 2) = 1 + 2 = 3.
	assert_eq(
		b.collision_mask,
		ArchiveSentinel.LAYER_WORLD | ArchiveSentinel.LAYER_PLAYER,
		"collision_mask = world + player"
	)


# ---- 11: wake() idempotence + boss_woke contract --------------------


func test_wake_is_idempotent() -> void:
	var b: ArchiveSentinel = _make_dormant_sentinel()
	watch_signals(b)
	b.wake()
	b.wake()
	b.wake()
	assert_signal_emit_count(
		b, "boss_woke", 1, "boss_woke fires exactly once even on triple wake()"
	)


func test_wake_transitions_dormant_to_waking() -> void:
	var b: ArchiveSentinel = _make_dormant_sentinel()
	assert_true(b.is_dormant())
	b.wake()
	assert_true(b.is_waking(), "wake() → STATE_WAKING (damage-immune window)")
	# After WAKE_DURATION drains, transitions to IDLE_ACTIVE.
	b._physics_process(ArchiveSentinel.WAKE_DURATION + 0.01)
	assert_eq(
		b.get_state(),
		ArchiveSentinel.STATE_IDLE_ACTIVE,
		"WAKING drains to IDLE_ACTIVE after WAKE_DURATION"
	)


func test_complete_wake_for_test_fast_forwards() -> void:
	# Helper for test suites that want to skip the wake window without
	# physics-tick simulation. Mirrors S1 Boss complete_wake_for_test.
	var b: ArchiveSentinel = _make_dormant_sentinel()
	b.wake()
	assert_true(b.is_waking())
	b.complete_wake_for_test()
	assert_eq(
		b.get_state(),
		ArchiveSentinel.STATE_IDLE_ACTIVE,
		"complete_wake_for_test fast-forwards to IDLE_ACTIVE"
	)


# ---- 12: Cast hitbox spawns at captured target -----------------------


func test_cast_hitbox_spawns_at_captured_player_position() -> void:
	# The cast captures player position at telegraph START. Player who
	# moves during windup naturally dodges — the projectile lands at
	# their original position.
	var b: ArchiveSentinel = _make_sentinel()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	b.global_position = Vector2.ZERO
	# Capture position at telegraph start: (200, 0).
	p.global_position = Vector2(200.0, 0.0)
	b.set_player(p)
	b._physics_process(0.016)
	assert_eq(b.get_state(), ArchiveSentinel.STATE_CAST)
	# MOVE player during the windup to (200, 200).
	p.global_position = Vector2(200.0, 200.0)
	# Tick past windup — cast fires at the CAPTURED (200, 0) position.
	watch_signals(b)
	b._physics_process(ArchiveSentinel.CAST_TELEGRAPH_DURATION + 0.01)
	assert_signal_emitted(b, "swing_spawned")
	var params: Array = get_signal_parameters(b, "swing_spawned", 0)
	var hb: Hitbox = params[1] as Hitbox
	assert_not_null(hb, "swing_spawned carried a Hitbox")
	# The hitbox is parented to the boss at (0, 0); its local position is
	# `dir * reach` where dir is the normalized (200, 0) → (1, 0) and reach
	# is the captured target distance (200). Global position should land
	# on the captured target: (200, 0).
	assert_almost_eq(
		hb.global_position.x,
		200.0,
		0.01,
		"hitbox global_position.x lands at captured target x (player original position)"
	)
	assert_almost_eq(
		hb.global_position.y,
		0.0,
		0.01,
		"hitbox global_position.y lands at captured target y (player original position)"
	)


# ---- 13: Negative damage clamped + zero-damage doesn't transition -----


func test_negative_damage_clamped_to_zero() -> void:
	var b: ArchiveSentinel = _make_sentinel()
	var hp_before: int = b.get_hp()
	_hit(b, -100)
	assert_eq(b.get_hp(), hp_before, "negative damage clamped to 0")


func test_zero_damage_does_not_trigger_phase_check() -> void:
	# Edge probe: zero damage shouldn't trigger phase transition even if HP
	# is sitting at the boundary already. (Theoretically impossible — you'd
	# need to spawn at exactly phase-2 threshold — but the clamp + latch
	# logic must handle it.)
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 700})
	var b: ArchiveSentinel = _make_sentinel_with_def(def)
	watch_signals(b)
	_hit(b, 0)
	assert_signal_emit_count(b, "phase_changed", 0)
	assert_eq(b.get_phase(), ArchiveSentinel.PHASE_1)
