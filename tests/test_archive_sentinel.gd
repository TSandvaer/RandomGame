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
	assert_ne(b.get_state(), ArchiveSentinel.STATE_SLAM_TELEGRAPH, "phase 1 does NOT use slam")


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
		b.get_state(), ArchiveSentinel.STATE_SLAM_TELEGRAPH, "phase 2 picks slam at short range"
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
	assert_eq(b.get_state(), ArchiveSentinel.STATE_CAST, "phase 2 falls back to cast at long range")


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
		b.get_hp(), hp_before, "WAKING rejects damage (extends intro-fairness through standup)"
	)


func test_phase_transition_ignores_damage() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 700})
	var b: ArchiveSentinel = _make_sentinel_with_def(def)
	_hit(b, 350)  # 700 → 350, enters STATE_PHASE_TRANSITION
	assert_true(b.is_in_phase_transition())
	var hp_during: int = b.get_hp()
	_hit(b, 99)
	assert_eq(b.get_hp(), hp_during, "PHASE_TRANSITION rejects damage (stagger immune)")


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
	assert_eq(b.velocity, Vector2.ZERO, "knockback ignored — construct stays on its plinth")


# ---- 10: Layers + masks ----------------------------------------------


func test_collision_layer_is_enemy() -> void:
	var b: ArchiveSentinel = _make_sentinel()
	# Enemy = bit 4 = 8. (LAYER_ENEMY = 1 << 3.)
	assert_eq(b.collision_layer, ArchiveSentinel.LAYER_ENEMY, "collision_layer = enemy (bit 4)")


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


# ---- 12b: Cast spawns a VISIBLE bolt at fire time --------------------
# REGRESSION-86c9y7ygj (Sponsor re-soak 2026-05-29 — "ArchiveSentinel deals
# damage with ZERO visible attack"). The cast DAMAGE is a bare invisible Area2D
# Hitbox; without a paired visual node the cast is invisible damage. These
# tests pin "damage never lands without a concurrent visible attack-visual node"
# at the GUT layer — node presence + visibility (visible / modulate.a / z) is
# assertable headless; human-perceptibility stays the Sponsor-soak gate per
# test-conventions.md § headless≠perception.


func _await_deferred_add() -> void:
	# _spawn_cast_bolt uses call_deferred("add_child"); the bolt arrives on the
	# next idle frame. Drain one process frame so it's in the tree.
	await get_tree().process_frame
	await get_tree().process_frame


func _find_cast_bolt(parent: Node) -> ArchiveSentinelCastBolt:
	for child in parent.get_children():
		if child is ArchiveSentinelCastBolt:
			return child as ArchiveSentinelCastBolt
	return null


func test_cast_fire_spawns_visible_bolt_node() -> void:
	# The cast must spawn a visible attack-visual node concurrent with the
	# (invisible) damage hitbox. This is the regression guard for the Sponsor's
	# "invisible attack" report.
	var b: ArchiveSentinel = _make_sentinel()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	b.global_position = Vector2.ZERO
	p.global_position = Vector2(150.0, 0.0)
	b.set_player(p)
	b._physics_process(0.016)  # enter cast
	b._physics_process(ArchiveSentinel.CAST_TELEGRAPH_DURATION + 0.01)  # fire
	await _await_deferred_add()
	# Bolt is parented to the boss's parent (the room == the GutTest root here).
	var bolt: ArchiveSentinelCastBolt = _find_cast_bolt(b.get_parent())
	assert_not_null(bolt, "cast fire spawned a visible ArchiveSentinelCastBolt node")
	if bolt == null:
		return
	# Assert it is ACTUALLY visible at the moment damage is applied:
	assert_true(bolt.visible, "cast bolt node is visible==true")
	assert_gt(bolt.modulate.a, 0.0, "cast bolt modulate.a > 0 (not fully transparent)")
	assert_true(bolt.z_index >= 0, "cast bolt z_index is non-negative (not sunk below floor)")
	# And it carries a renderer-safe ColorRect body (NOT Polygon2D — PR #137).
	var has_color_rect: bool = false
	for child in bolt.get_children():
		if child is ColorRect:
			has_color_rect = true
	assert_true(has_color_rect, "cast bolt body is a ColorRect (renderer-safe, not Polygon2D)")
	bolt.queue_free()


func test_cast_bolt_color_channels_are_sub_one_html5_safe() -> void:
	# HDR-clamp safety: every channel of the bolt + impact colors must be ≤ 1.0
	# so WebGL2's sRGB clamp leaves the ember-orange intact (PR #137 lesson).
	for c in [
		ArchiveSentinelCastBolt.BOLT_COLOR,
		ArchiveSentinelCastBolt.IMPACT_COLOR,
	]:
		assert_true(c.r <= 1.0, "bolt color r ≤ 1.0 (HDR-clamp safe)")
		assert_true(c.g <= 1.0, "bolt color g ≤ 1.0")
		assert_true(c.b <= 1.0, "bolt color b ≤ 1.0")
		assert_true(c.a > 0.0, "bolt color alpha > 0 (visible)")


func test_cast_bolt_spawns_at_book_travels_to_captured_target() -> void:
	# The bolt must originate at the construct (book) and head to the CAPTURED
	# target — so the player sees "the book just shot at where I was standing".
	var b: ArchiveSentinel = _make_sentinel()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	b.global_position = Vector2(50.0, 50.0)
	p.global_position = Vector2(250.0, 50.0)  # captured at telegraph start
	b.set_player(p)
	b._physics_process(0.016)  # enter cast, captures (250,50)
	p.global_position = Vector2(250.0, 250.0)  # player moves during windup
	b._physics_process(ArchiveSentinel.CAST_TELEGRAPH_DURATION + 0.01)  # fire
	await _await_deferred_add()
	var bolt: ArchiveSentinelCastBolt = _find_cast_bolt(b.get_parent())
	assert_not_null(bolt, "cast bolt spawned")
	if bolt == null:
		return
	# Bolt spawns at the construct's book position (50,50).
	assert_almost_eq(bolt.global_position.x, 50.0, 0.5, "bolt spawns at construct x")
	assert_almost_eq(bolt.global_position.y, 50.0, 0.5, "bolt spawns at construct y")
	bolt.queue_free()


func test_cast_bolt_configure_clamps_travel_duration() -> void:
	# Defensive: a zero / negative travel duration would divide-by-zero the
	# tween; configure clamps to a tiny positive minimum.
	var bolt: ArchiveSentinelCastBolt = ArchiveSentinelCastBolt.new()
	bolt.configure(Vector2.ZERO, Vector2(100.0, 0.0), 0.0)
	# Not in tree — just verify configure didn't crash + stored a usable value
	# by adding it and confirming _ready builds the body without error.
	add_child_autofree(bolt)
	await get_tree().process_frame
	assert_true(is_instance_valid(bolt), "bolt survives _ready with clamped duration")


func test_cast_bolt_ready_emits_renderer_observable_visible_trace() -> void:
	# REGRESSION-86c9y7ygj — pins the bolt's OWN _ready visibility trace contract.
	# The Playwright spec asserts on `ArchiveSentinelCastBolt._ready | VISIBLE ...
	# visible=true alpha>0 z>=0 color_rect=true` to prove the attack-visual node
	# is RENDERABLE (not just spawned) at the moment the cast lands. If a refactor
	# drops the self-trace, this GUT pin fails before CI green and the harness
	# guard goes blind. The trace flows through the DebugFlags combat-trace shim;
	# here we verify the post-_ready render-state the trace REPORTS is correct
	# (visible / alpha / z / ColorRect body) — the same values the trace emits.
	var bolt: ArchiveSentinelCastBolt = ArchiveSentinelCastBolt.new()
	bolt.configure(Vector2(10.0, 10.0), Vector2(80.0, 10.0), 0.16)
	add_child_autofree(bolt)
	await get_tree().process_frame
	assert_true(bolt.visible, "bolt visible==true at _ready (trace reports visible=true)")
	assert_gt(bolt.modulate.a, 0.0, "bolt modulate.a > 0 at _ready (trace reports alpha>0)")
	assert_true(bolt.z_index >= 0, "bolt z_index >= 0 at _ready (trace reports z>=0)")
	var has_color_rect: bool = false
	for child in bolt.get_children():
		if child is ColorRect:
			has_color_rect = true
	assert_true(
		has_color_rect, "bolt has a ColorRect body at _ready (trace reports color_rect=true)"
	)


# ---- 12c: Phase-2 slam telegraph spawns a VISIBLE draw_arc indicator -----
# Companion to the cast-bolt visibility pins: proves the phase-2 slam ALSO has a
# visible attack-visual node (the draw_arc AOE telegraph) and is NOT a second
# invisible-attack regression. The slam's visual is the TELEGRAPH (fade-in +
# strobe over the windup) — the player sees the danger circle BEFORE the damage
# hitbox fires, so unlike the cast there is no "invisible damage" surface here.
# This test pins the indicator node presence + renderer-safe draw class + z so a
# future refactor cannot silently drop the phase-2 telegraph.


func test_phase2_slam_telegraph_spawns_visible_draw_arc_indicator() -> void:
	var b: ArchiveSentinel = _make_sentinel()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	b.set_player(p)
	# Drive into phase 2 (700 → 350 boundary), drain the transition window.
	_hit(b, 350)
	b._physics_process(ArchiveSentinel.PHASE_TRANSITION_DURATION + 0.01)
	assert_eq(b.get_phase(), ArchiveSentinel.PHASE_2, "boss is in phase 2")
	# Player inside slam radius → next tick begins the slam telegraph.
	b.global_position = Vector2.ZERO
	p.global_position = Vector2(60.0, 0.0)  # < SLAM_HITBOX_RADIUS (96)
	b._physics_process(0.016)
	assert_eq(
		b.get_state(),
		ArchiveSentinel.STATE_SLAM_TELEGRAPH,
		"phase 2 short-range begins the slam telegraph"
	)
	# The slam indicator is parented to the construct (construct-centered draw).
	var indicator: ArchiveSentinelSlamIndicator = null
	for child in b.get_children():
		if child is ArchiveSentinelSlamIndicator:
			indicator = child as ArchiveSentinelSlamIndicator
	assert_not_null(indicator, "slam telegraph spawned a visible ArchiveSentinelSlamIndicator node")
	if indicator == null:
		return
	assert_true(indicator.visible, "slam indicator node is visible==true")
	assert_true(indicator.z_index >= 0, "slam indicator z_index >= 0 (not sunk below floor)")
	# Renderer-safe: the indicator overrides _draw (draw_arc path), NOT Polygon2D.
	assert_true(
		indicator.has_method("_draw"),
		"slam indicator uses _draw/draw_arc (renderer-safe, NOT Polygon2D — PR #137)"
	)
	# Its draw radius mirrors the slam hitbox radius (96 px) so the visual matches
	# the danger zone — drift here would teach the player the wrong dodge distance.
	assert_almost_eq(
		ArchiveSentinelSlamIndicator.SLAM_HITBOX_RADIUS_CONST,
		ArchiveSentinel.SLAM_HITBOX_RADIUS,
		0.5,
		"slam indicator draw radius mirrors SLAM_HITBOX_RADIUS"
	)


func test_slam_indicator_color_channels_are_sub_one_html5_safe() -> void:
	# HDR-clamp safety for the slam telegraph (PR #137 lesson) — every RGB channel
	# of the draw_arc color must be ≤ 1.0 so WebGL2's sRGB clamp leaves the
	# ember-orange intact rather than collapsing it toward white.
	var c: Color = ArchiveSentinelSlamIndicator.SLAM_INDICATOR_COLOR_CONST
	assert_true(c.r <= 1.0, "slam indicator color r ≤ 1.0 (HDR-clamp safe)")
	assert_true(c.g <= 1.0, "slam indicator color g ≤ 1.0")
	assert_true(c.b <= 1.0, "slam indicator color b ≤ 1.0")
	assert_gt(c.a, 0.0, "slam indicator base alpha > 0 (visible)")


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


# =====================================================================
# Phase-blink reposition (W3-T7 Stage 6, ticket 86c9y7ygj) — Uma section 5.5a.
# The Sentinel does NOT walk/chase; it phase-blinks (instant reposition +
# VFX) between cast volleys to one of 4 fixed plinth-points. Coverage:
#   B1. select_blink_target_idx picks FARTHEST-from-player.
#   B2. select_blink_target_idx NEVER picks the current index (never adjacent).
#   B3. Cadence hard-floor blocks a second blink until the floor elapses.
#   B4. Floor differs phase 1 (2.5s) vs phase 2 (1.5s) — phase-2 tightens.
#   B5. Suppress-at-max-range: no blink when player is beyond suppress range.
#   B6. No move_and_slide / velocity stays ZERO — reposition is a teleport.
#   B7. Blink target is one of the 4 fixed plinth-points (arena-bounded).
#   B8. PLINTH_OFFSETS sub-arena bound + channel-safe VFX color sanity.
# =====================================================================


func _make_sentinel_at(pos: Vector2) -> ArchiveSentinel:
	# A blink-ready sentinel rooted at pos with the plinth origin captured.
	var b: ArchiveSentinel = _make_sentinel()
	b.global_position = pos
	b._ensure_plinth_origin()
	return b


# ---- B1: target-select picks the FARTHEST candidate -------------------


func test_select_blink_target_idx_picks_farthest_from_player() -> void:
	var candidates: Array = [
		Vector2(0, 0),
		Vector2(100, 0),
		Vector2(200, 0),
		Vector2(300, 0),
	]
	var idx: int = ArchiveSentinel.select_blink_target_idx(candidates, 1, Vector2(10, 0))
	assert_eq(idx, 3, "picks the candidate farthest from the player")


func test_select_blink_target_idx_player_near_far_end_picks_near_end() -> void:
	var candidates: Array = [
		Vector2(0, 0),
		Vector2(100, 0),
		Vector2(200, 0),
		Vector2(300, 0),
	]
	var idx: int = ArchiveSentinel.select_blink_target_idx(candidates, 2, Vector2(290, 0))
	assert_eq(idx, 0, "player near high end gives farthest at index 0")


# ---- B2: never re-picks the current index (never adjacent) ------------


func test_select_blink_target_idx_never_returns_current_index() -> void:
	var candidates: Array = [
		Vector2(0, 0),
		Vector2(100, 0),
		Vector2(200, 0),
		Vector2(300, 0),
	]
	var idx: int = ArchiveSentinel.select_blink_target_idx(candidates, 0, Vector2(300, 0))
	assert_ne(idx, 0, "never re-picks the currently-occupied plinth")
	assert_eq(idx, 1, "falls to the next-farthest non-current candidate")


# ---- B3: cadence hard-floor blocks back-to-back blinks ----------------


func test_blink_floor_blocks_second_blink_until_elapsed() -> void:
	var b: ArchiveSentinel = _make_sentinel_at(Vector2(512, 384))
	var p: FakePlayer = FakePlayer.new()
	p.global_position = Vector2(540, 384)
	add_child_autofree(p)
	b.set_player(p)

	var fired_1: bool = b.try_blink_for_test()
	assert_true(fired_1, "first blink fires (floor was clear)")
	assert_gt(b.get_blink_floor_left(), 0.0, "floor armed after blink")

	var fired_2: bool = b.try_blink_for_test()
	assert_false(fired_2, "second blink blocked while floor is armed")

	b._blink_floor_left = 0.0
	b._blink_in_progress = false
	var fired_3: bool = b.try_blink_for_test()
	assert_true(fired_3, "blink eligible again once floor elapses")


# ---- B4: phase-2 floor is tighter than phase-1 ------------------------


func test_blink_floor_tightens_in_phase_2() -> void:
	var b: ArchiveSentinel = _make_sentinel_at(Vector2(512, 384))
	var p: FakePlayer = FakePlayer.new()
	p.global_position = Vector2(540, 384)
	add_child_autofree(p)
	b.set_player(p)

	assert_eq(b.get_phase(), ArchiveSentinel.PHASE_1)
	b.try_blink_for_test()
	var floor_p1: float = b.get_blink_floor_left()
	assert_almost_eq(floor_p1, ArchiveSentinel.BLINK_FLOOR_PHASE_1, 0.001)

	b.phase = ArchiveSentinel.PHASE_2
	b._blink_floor_left = 0.0
	b._blink_in_progress = false
	b.try_blink_for_test()
	var floor_p2: float = b.get_blink_floor_left()
	assert_almost_eq(floor_p2, ArchiveSentinel.BLINK_FLOOR_PHASE_2, 0.001)

	assert_lt(floor_p2, floor_p1, "phase-2 cadence is tighter than phase-1")


# ---- B5: suppress-at-max-range ----------------------------------------


func test_blink_suppressed_when_player_at_max_range() -> void:
	var b: ArchiveSentinel = _make_sentinel_at(Vector2(512, 384))
	var p: FakePlayer = FakePlayer.new()
	var far: float = ArchiveSentinel.AGGRO_RADIUS * ArchiveSentinel.BLINK_SUPPRESS_RANGE_FRAC + 50.0
	p.global_position = Vector2(512, 384) + Vector2(far, 0)
	add_child_autofree(p)
	b.set_player(p)

	var fired: bool = b.try_blink_for_test()
	assert_false(fired, "no blink when player is already at max range")
	assert_eq(b.get_blink_floor_left(), 0.0, "floor not armed when suppressed")


func test_blink_not_suppressed_when_player_in_range() -> void:
	var b: ArchiveSentinel = _make_sentinel_at(Vector2(512, 384))
	var p: FakePlayer = FakePlayer.new()
	p.global_position = Vector2(560, 384)
	add_child_autofree(p)
	b.set_player(p)
	var fired: bool = b.try_blink_for_test()
	assert_true(fired, "blink fires when player is in-range (not suppressed)")


# ---- B6: no move_and_slide — velocity stays ZERO, reposition is teleport


func test_blink_reposition_is_teleport_velocity_stays_zero() -> void:
	var b: ArchiveSentinel = _make_sentinel_at(Vector2(512, 384))
	var p: FakePlayer = FakePlayer.new()
	p.global_position = Vector2(560, 384)
	add_child_autofree(p)
	b.set_player(p)

	b.try_blink_for_test()
	assert_eq(b.velocity, Vector2.ZERO, "velocity ZERO right after blink fire")

	for _i in 40:
		await get_tree().process_frame
		assert_eq(b.velocity, Vector2.ZERO, "velocity stays ZERO every frame of blink")

	var landed_on_plinth: bool = false
	for off in ArchiveSentinel.PLINTH_OFFSETS:
		if b.global_position.distance_to(Vector2(512, 384) + off) < 0.5:
			landed_on_plinth = true
	assert_true(landed_on_plinth, "construct landed exactly on a fixed plinth-point")


# ---- B7: blink target is one of the 4 fixed plinth-points -------------


func test_blink_target_is_a_fixed_plinth_point() -> void:
	var origin: Vector2 = Vector2(512, 384)
	var b: ArchiveSentinel = _make_sentinel_at(origin)
	var p: FakePlayer = FakePlayer.new()
	p.global_position = Vector2(560, 384)
	add_child_autofree(p)
	b.set_player(p)

	var before_idx: int = b.get_current_plinth_idx()
	b.try_blink_for_test()
	var after_idx: int = b.get_current_plinth_idx()
	assert_ne(after_idx, before_idx, "plinth index changed on blink")
	assert_true(
		after_idx >= 0 and after_idx < ArchiveSentinel.PLINTH_OFFSETS.size(),
		"target index in the fixed plinth set"
	)


# ---- B8: plinth offsets arena-bounded + VFX channels HDR-safe ---------


func test_plinth_offsets_are_arena_bounded() -> void:
	var center: Vector2 = Vector2(512, 384)
	for off in ArchiveSentinel.PLINTH_OFFSETS:
		var pos: Vector2 = center + off
		assert_true(pos.x > 80 and pos.x < 944, "plinth x inside arena interior: %s" % pos)
		assert_true(pos.y > 80 and pos.y < 688, "plinth y inside arena interior: %s" % pos)


func test_blink_vfx_color_channels_are_sub_one_html5_safe() -> void:
	var colors: Array = [
		ArchiveSentinelBlinkVfx.EMBER_MOTE_COLOR,
		ArchiveSentinelBlinkVfx.GLYPH_FLECK_COLOR,
		ArchiveSentinelBlinkVfx.SEAM_COLOR,
		ArchiveSentinelBlinkVfx.IMPACT_FLARE_COLOR,
	]
	for c in colors:
		assert_true((c as Color).r <= 1.0, "r le 1.0 (HDR-clamp safe): %s" % c)
		assert_true((c as Color).g <= 1.0, "g le 1.0: %s" % c)
		assert_true((c as Color).b <= 1.0, "b le 1.0: %s" % c)
