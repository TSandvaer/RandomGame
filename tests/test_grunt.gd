extends GutTest
## Tests for Grunt mob — paired with `scripts/mobs/Grunt.gd` and the
## first consumer of the TRES content schema (MobDef + LootTableDef).
##
## Coverage per testing bar (`team/TESTING_BAR.md` §Devon-and-Drew):
##   1. Spawns with full HP from MobDef.
##   2. Takes damage from a player-team Hitbox (layer 3 player_hitbox).
##   3. Damage decrements HP, emits `damaged` signal.
##   4. Death at 0 HP emits `mob_died` exactly once + carries mob_def + position.
##   5. State machine transitions: idle -> chasing -> attacking -> chasing.
##   6. Heavy telegraph fires once at <=30% HP, transitions to telegraphing,
##      finishes with a heavy swing.
##   7. Heavy telegraph is one-shot: never fires twice, even on re-cross 30%.
##   8. EDGE: rapid hit spam — multiple consecutive damage calls collapse
##      cleanly to one death; mob_died emits once.
##   9. EDGE: dies during heavy telegraph — no swing fires from the corpse.
##  10. EDGE: dies while pathing/chasing — velocity zeroed, no further state
##      transitions, no swings, mob_died fires once.
##  11. Layers/masks set per DECISIONS.md (enemy collision_layer).
##  12. Hitbox spawned by grunt is on enemy team and masks player.
##  13. Grunt at full HP does not telegraph on a single hit that doesn't
##      cross the threshold.
##  14. apply_mob_def() rebinds HP/damage/speed mid-life.

const GruntScript: Script = preload("res://scripts/mobs/Grunt.gd")
const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")
const MobDefScript: Script = preload("res://scripts/content/MobDef.gd")


# ---- Helpers ----------------------------------------------------------

class FakePlayer:
	extends Node2D
	# Dummy player target. The grunt only reads global_position.


func _make_grunt() -> Grunt:
	var g: Grunt = GruntScript.new()
	add_child_autofree(g)
	return g


func _make_grunt_with_def(def: MobDef) -> Grunt:
	var g: Grunt = GruntScript.new()
	g.mob_def = def
	add_child_autofree(g)
	return g


func _hit_grunt(g: Grunt, dmg: int) -> void:
	# Direct take_damage call mirrors what `Hitbox._try_apply_hit` does.
	g.take_damage(dmg, Vector2.ZERO, null)


# ---- 1: full HP at spawn from MobDef ---------------------------------

func test_spawns_with_full_hp_from_mobdef() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 80, "damage_base": 12, "move_speed": 75.0})
	var g: Grunt = _make_grunt_with_def(def)
	assert_eq(g.get_hp(), 80, "starts at hp_base")
	assert_eq(g.get_max_hp(), 80, "max_hp = hp_base at spawn")
	assert_eq(g.damage_base, 12, "damage_base from def")
	assert_eq(g.move_speed, 75.0, "move_speed from def")
	assert_false(g.is_dead())


func test_default_hp_when_no_mobdef_assigned() -> void:
	var g: Grunt = _make_grunt()
	# Per spec: 50 HP, 3 base damage if no def (rebalanced M1 RC soak-4 — was 5).
	assert_eq(g.get_hp(), 50)
	assert_eq(g.get_max_hp(), 50)
	assert_eq(g.damage_base, 3)


# ---- 2: takes damage via Hitbox layer-3 -------------------------------

func test_takes_damage_from_player_hitbox() -> void:
	# Construct a player-team hitbox manually and call the duck-typed
	# take_damage path. We don't simulate physics overlap (that's covered
	# by tests/test_hitbox.gd) — we verify the contract holds.
	var g: Grunt = _make_grunt()
	var hb: Hitbox = HitboxScript.new()
	hb.configure(15, Vector2.RIGHT * 50.0, 0.1, Hitbox.TEAM_PLAYER, null)
	add_child_autofree(hb)
	# The hitbox sits on player_hitbox (bit 3) and masks enemy (bit 4).
	assert_eq(hb.collision_layer, Hitbox.LAYER_PLAYER_HITBOX, "hitbox on layer 3")
	assert_eq(hb.collision_mask, Hitbox.LAYER_ENEMY, "hitbox masks layer 4 (enemy)")
	# Apply via Hitbox._try_apply_hit which is what the engine wires.
	hb._try_apply_hit(g)
	assert_eq(g.get_hp(), 35, "50 - 15 = 35")


# ---- 3: damaged signal carries amount + remaining + source -----------

func test_damaged_signal_carries_payload() -> void:
	var g: Grunt = _make_grunt()
	watch_signals(g)
	var src: Node2D = autofree(Node2D.new())
	g.take_damage(7, Vector2.ZERO, src)
	assert_signal_emitted_with_parameters(g, "damaged", [7, 43, src])


# ---- 4: death emits mob_died exactly once + carries payload ----------

func test_death_emits_mob_died_once() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 20})
	var g: Grunt = _make_grunt_with_def(def)
	g.global_position = Vector2(123.0, 456.0)
	watch_signals(g)
	g.take_damage(20, Vector2.ZERO, null)
	assert_eq(g.get_hp(), 0)
	assert_true(g.is_dead())
	assert_eq(g.get_state(), Grunt.STATE_DEAD)
	assert_signal_emitted(g, "mob_died")
	# Payload includes (mob, position, def).
	var args: Array = get_signal_parameters(g, "mob_died", 0)
	assert_not_null(args)
	assert_eq(args[0], g, "mob_died carries the mob node")
	assert_almost_eq(args[1].x, 123.0, 0.001)
	assert_almost_eq(args[1].y, 456.0, 0.001)
	assert_eq(args[2], def, "mob_died carries the MobDef so loot listeners get loot_table without re-resolving")


# ---- 5: state machine transitions idle -> chasing --------------------

func test_state_chases_player_when_in_range() -> void:
	var g: Grunt = _make_grunt()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	g.global_position = Vector2.ZERO
	p.global_position = Vector2(200.0, 0.0)  # within AGGRO_RADIUS, outside ATTACK_RANGE
	g.set_player(p)
	g._physics_process(0.016)
	assert_eq(g.get_state(), Grunt.STATE_CHASING)
	# Velocity points roughly toward player (positive x).
	assert_gt(g.velocity.x, 0.0, "moves toward player on +x")


func test_state_idle_when_no_player() -> void:
	var g: Grunt = _make_grunt()
	g.set_player(null)
	g._physics_process(0.016)
	assert_eq(g.get_state(), Grunt.STATE_IDLE)
	assert_eq(g.velocity, Vector2.ZERO)


func test_state_swings_when_in_attack_range() -> void:
	var g: Grunt = _make_grunt()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	g.global_position = Vector2.ZERO
	p.global_position = Vector2(20.0, 0.0)  # < ATTACK_RANGE
	g.set_player(p)
	watch_signals(g)
	g._physics_process(0.016)
	# M1 RC soak-4 fix: grunt now enters STATE_TELEGRAPHING_LIGHT first
	# (rooted, 0.4 s windup) before the swing fires. Swing fires when the
	# telegraph window expires.
	assert_eq(g.get_state(), Grunt.STATE_TELEGRAPHING_LIGHT,
		"grunt enters telegraph state on first tick in melee range")
	# Tick past the telegraph window — swing fires and state advances to ATTACKING.
	g._physics_process(Grunt.LIGHT_TELEGRAPH_DURATION + 0.01)
	assert_eq(g.get_state(), Grunt.STATE_ATTACKING)
	assert_signal_emitted(g, "swing_spawned")


func test_state_recovers_then_returns_to_chasing() -> void:
	var g: Grunt = _make_grunt()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	g.global_position = Vector2.ZERO
	p.global_position = Vector2(20.0, 0.0)
	g.set_player(p)
	g._physics_process(0.016)
	# M1 RC soak-4 fix: grunt enters telegraph BEFORE swing/attacking now.
	assert_eq(g.get_state(), Grunt.STATE_TELEGRAPHING_LIGHT)
	# Tick past telegraph — swing fires and we enter ATTACKING (recovery).
	g._physics_process(Grunt.LIGHT_TELEGRAPH_DURATION + 0.01)
	assert_eq(g.get_state(), Grunt.STATE_ATTACKING)
	# Move player away so chase resumes after recovery.
	p.global_position = Vector2(200.0, 0.0)
	g._physics_process(Grunt.ATTACK_RECOVERY + 0.01)
	# Tick once more so state handler runs after recovery zeroed.
	g._physics_process(0.016)
	assert_eq(g.get_state(), Grunt.STATE_CHASING)


# ---- 6 + 7: heavy telegraph at <=30% HP, one-shot -------------------

func test_heavy_telegraph_fires_at_30_percent() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 100})
	var g: Grunt = _make_grunt_with_def(def)
	watch_signals(g)
	# 100 HP -> threshold is ceil(100*0.30) = 30. At 30 HP the telegraph fires.
	g.take_damage(70, Vector2.ZERO, null)
	assert_eq(g.get_hp(), 30)
	assert_eq(g.get_state(), Grunt.STATE_TELEGRAPHING_HEAVY)
	assert_signal_emitted(g, "heavy_telegraph_started")
	assert_true(g.has_heavy_telegraph_fired())


func test_heavy_telegraph_completes_with_heavy_swing() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 100, "damage_base": 10})
	var g: Grunt = _make_grunt_with_def(def)
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	p.global_position = Vector2(50.0, 0.0)
	g.set_player(p)
	g.take_damage(70, Vector2.ZERO, null)
	assert_eq(g.get_state(), Grunt.STATE_TELEGRAPHING_HEAVY)
	# Tick past the windup. _physics_process drives the telegraph completion.
	watch_signals(g)
	g._physics_process(Grunt.HEAVY_TELEGRAPH_DURATION + 0.01)
	# Telegraph completed -> heavy swing fired -> we're in attacking.
	assert_eq(g.get_state(), Grunt.STATE_ATTACKING)
	assert_signal_emitted(g, "swing_spawned")
	var params: Array = get_signal_parameters(g, "swing_spawned", 0)
	assert_not_null(params, "swing_spawned was emitted with params")
	assert_eq(params[0], Grunt.SWING_KIND_HEAVY, "telegraph completion fires HEAVY swing kind")


func test_heavy_telegraph_is_one_shot() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 100})
	var g: Grunt = _make_grunt_with_def(def)
	# Hit to 25 HP -> telegraph fires.
	g.take_damage(75, Vector2.ZERO, null)
	assert_true(g.has_heavy_telegraph_fired())
	# Finish the telegraph so we're back to a non-telegraph state.
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	p.global_position = Vector2(50.0, 0.0)
	g.set_player(p)
	g._physics_process(Grunt.HEAVY_TELEGRAPH_DURATION + 0.01)
	# Hit again — must NOT re-enter telegraph state.
	watch_signals(g)
	g.take_damage(5, Vector2.ZERO, null)
	assert_signal_not_emitted(g, "heavy_telegraph_started", "telegraph is one-shot — never refires")


# ---- 13: telegraph guard above threshold ----------------------------

func test_no_telegraph_above_threshold() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 100})
	var g: Grunt = _make_grunt_with_def(def)
	watch_signals(g)
	g.take_damage(50, Vector2.ZERO, null)  # 50 HP > 30% threshold
	assert_signal_not_emitted(g, "heavy_telegraph_started")
	assert_false(g.has_heavy_telegraph_fired())
	assert_ne(g.get_state(), Grunt.STATE_TELEGRAPHING_HEAVY)


# ---- 8 EDGE: rapid hit spam -----------------------------------------

func test_rapid_hit_spam_collapses_to_single_death() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 30})
	var g: Grunt = _make_grunt_with_def(def)
	watch_signals(g)
	# Spam 10 hits of 50 dmg each.
	for i in 10:
		g.take_damage(50, Vector2.ZERO, null)
	assert_eq(g.get_hp(), 0)
	assert_true(g.is_dead())
	# mob_died must fire exactly ONCE despite 10 take_damage calls.
	assert_signal_emit_count(g, "mob_died", 1, "death is idempotent — mob_died emits once")
	# damaged should fire exactly once too — subsequent hits are ignored
	# while is_dead is true.
	assert_signal_emit_count(g, "damaged", 1, "damaged blocked once dead")


# ---- 9 EDGE: dies during heavy telegraph ----------------------------

func test_dies_during_heavy_telegraph_no_swing_from_corpse() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 100, "damage_base": 10})
	var g: Grunt = _make_grunt_with_def(def)
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	p.global_position = Vector2(50.0, 0.0)
	g.set_player(p)
	# Drop to 20 HP -> telegraph fires.
	g.take_damage(80, Vector2.ZERO, null)
	assert_eq(g.get_state(), Grunt.STATE_TELEGRAPHING_HEAVY)
	# Watch signals AFTER entering telegraph so we only catch the death sig.
	watch_signals(g)
	# Kill mid-telegraph.
	g.take_damage(50, Vector2.ZERO, null)
	assert_eq(g.get_hp(), 0)
	assert_eq(g.get_state(), Grunt.STATE_DEAD)
	# Now tick past where the telegraph would have fired the heavy swing.
	g._physics_process(Grunt.HEAVY_TELEGRAPH_DURATION + 0.5)
	# No swing should have spawned from the corpse.
	assert_signal_not_emitted(g, "swing_spawned", "no heavy swing fires after death")
	assert_signal_emit_count(g, "mob_died", 1)


# ---- 10 EDGE: dies while pathing ------------------------------------

func test_dies_while_pathing() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 25})
	var g: Grunt = _make_grunt_with_def(def)
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	g.global_position = Vector2.ZERO
	p.global_position = Vector2(200.0, 0.0)
	g.set_player(p)
	# Tick once so we're chasing with a non-zero velocity.
	g._physics_process(0.016)
	assert_eq(g.get_state(), Grunt.STATE_CHASING)
	assert_gt(g.velocity.x, 0.0)
	watch_signals(g)
	# Lethal hit mid-chase.
	g.take_damage(25, Vector2.ZERO, null)
	assert_eq(g.get_state(), Grunt.STATE_DEAD)
	assert_eq(g.velocity, Vector2.ZERO, "velocity zeroed on death — no corpse-sliding")
	# Subsequent ticks must not transition state.
	g._physics_process(0.05)
	assert_eq(g.get_state(), Grunt.STATE_DEAD)
	assert_signal_emit_count(g, "mob_died", 1)


# ---- 11: layers per DECISIONS.md ------------------------------------

func test_collision_layer_is_enemy() -> void:
	var g: Grunt = _make_grunt()
	# The .gd default uses LAYER_ENEMY (bit 4 = 8). The .tscn also sets 8;
	# bare-instantiated CharacterBody2D defaults to layer 1, which our
	# _apply_layers replaces with LAYER_ENEMY. Either way we end up on bit 4.
	assert_eq(g.collision_layer, Grunt.LAYER_ENEMY, "grunt sits on enemy layer (bit 4)")
	# Mask collides with world (bit 1) and player (bit 2) so player can't
	# walk through us and we can't walk through walls.
	assert_eq(g.collision_mask, Grunt.LAYER_WORLD | Grunt.LAYER_PLAYER, "mask = world + player")


# ---- 12: spawned hitbox is enemy-team -------------------------------

func test_spawned_hitbox_is_enemy_team() -> void:
	var g: Grunt = _make_grunt()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	g.global_position = Vector2.ZERO
	p.global_position = Vector2(20.0, 0.0)  # in attack range
	g.set_player(p)
	var captured_hb: Array = [null]
	g.swing_spawned.connect(func(_kind: StringName, hb: Node) -> void:
		captured_hb[0] = hb
	)
	# M1 RC soak-4 fix: enter telegraph first, then tick past it so swing fires.
	g._physics_process(0.016)
	g._physics_process(Grunt.LIGHT_TELEGRAPH_DURATION + 0.01)
	assert_not_null(captured_hb[0], "swing fired in attack range after telegraph window")
	var hb: Hitbox = captured_hb[0]
	assert_eq(hb.team, Hitbox.TEAM_ENEMY, "grunt swings on enemy team")
	assert_eq(hb.collision_layer, Hitbox.LAYER_ENEMY_HITBOX, "enemy_hitbox layer (bit 5)")
	assert_eq(hb.collision_mask, Hitbox.LAYER_PLAYER, "masks player (bit 2)")


# ---- 14: apply_mob_def() rebinds at runtime -------------------------

func test_apply_mob_def_rebinds_runtime_stats() -> void:
	var g: Grunt = _make_grunt()
	# Default 50/5/60 in scope.
	var hot_swap: MobDef = ContentFactory.make_mob_def({"hp_base": 200, "damage_base": 25, "move_speed": 90.0})
	g.apply_mob_def(hot_swap)
	assert_eq(g.get_hp(), 200)
	assert_eq(g.get_max_hp(), 200)
	assert_eq(g.damage_base, 25)
	assert_eq(g.move_speed, 90.0)


# ---- 15: knockback applied on damage --------------------------------

func test_damage_applies_knockback_velocity() -> void:
	var g: Grunt = _make_grunt()
	g.take_damage(5, Vector2(75.0, 0.0), null)
	assert_almost_eq(g.velocity.x, 75.0, 0.001)


# ---- 16: negative damage clamped to zero ----------------------------

func test_negative_damage_does_not_heal() -> void:
	var g: Grunt = _make_grunt()
	g.take_damage(-100, Vector2.ZERO, null)
	assert_eq(g.get_hp(), 50, "negative dmg clamps to 0 — no incidental healing")
	assert_false(g.is_dead())


# ---- 17 — M2 W1 P1 polish: recovery-velocity decays to zero -------------
# Ticket: 86c9q804q (Grunt recovery-velocity audit).
# Symptom from M1 RC re-soak: after a Grunt takes damage and enters its
# _play_hit_flash + recovery state, its velocity sometimes leaves it floating
# or sliding. Pre-fix, _process_recover did not zero velocity each tick —
# any residual vector (knockback impulse, post-contact pushback) persisted
# for the whole recovery window and visibly drifted the grunt.
# Post-fix, _process_recover sets `velocity = Vector2.ZERO` every tick.

func test_grunt_recovery_velocity_decays_to_zero_within_two_ticks() -> void:
	# Drive grunt into STATE_ATTACKING (the recovery state) by firing a swing
	# at a player in melee range. The swing-fire tick now applies a one-tick
	# pushback velocity (the mob-stick fix), so velocity is non-zero on entry
	# to recovery. We assert that on the NEXT physics tick, _process_recover
	# zeroes it back to Vector2.ZERO — proving the recovery-velocity audit
	# fix lands on every tick, not just on swing-fire.
	var g: Grunt = _make_grunt()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	g.global_position = Vector2.ZERO
	p.global_position = Vector2(Grunt.ATTACK_RANGE - 4.0, 0.0)
	g.set_player(p)
	# Tick 1: chase → telegraph.
	g._physics_process(0.016)
	assert_eq(g.get_state(), Grunt.STATE_TELEGRAPHING_LIGHT)
	# Tick 2: telegraph completes → swing fires → recovery state with
	# pushback velocity applied.
	g._physics_process(Grunt.LIGHT_TELEGRAPH_DURATION + 0.01)
	assert_eq(g.get_state(), Grunt.STATE_ATTACKING)
	assert_gt(g.velocity.length(), 0.0,
		"swing-fire applies non-zero pushback (sets up the recovery-decay test)")
	# Tick 3: _process_recover runs and zeroes velocity.
	g._physics_process(0.016)
	assert_eq(g.velocity, Vector2.ZERO,
		"recovery handler zeros velocity on first post-pushback tick (no float / drift)")


func test_grunt_recovery_velocity_stays_zero_across_full_window() -> void:
	# Walk through every tick of the recovery window and assert velocity
	# never drifts away from ZERO. Pre-fix, knockback or pushback residuals
	# could persist across all recovery ticks; post-fix, every tick re-zeroes
	# the velocity field deterministically.
	var g: Grunt = _make_grunt()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	g.global_position = Vector2.ZERO
	p.global_position = Vector2(Grunt.ATTACK_RANGE - 4.0, 0.0)
	g.set_player(p)
	g._physics_process(0.016)
	g._physics_process(Grunt.LIGHT_TELEGRAPH_DURATION + 0.01)
	assert_eq(g.get_state(), Grunt.STATE_ATTACKING)
	# First tick of recovery — re-zeroes the swing-fire pushback.
	g._physics_process(0.016)
	# Walk the rest of the recovery window in 0.016s ticks. Each must keep
	# velocity at ZERO. We move the player far away to verify the grunt
	# does NOT drift toward them — recovery is rooted regardless.
	p.global_position = Vector2(500.0, 0.0)
	for _i in 10:
		g._physics_process(0.016)
		# The recovery timer may expire mid-loop and transition us to
		# STATE_CHASING (which then sets non-zero velocity toward player).
		# Bail early if that happens — the recovery-window assertion has
		# already been validated.
		if g.get_state() != Grunt.STATE_ATTACKING:
			break
		assert_eq(g.velocity, Vector2.ZERO,
			"grunt velocity stays at ZERO every tick of recovery window")


func test_grunt_knockback_does_not_persist_into_recovery() -> void:
	# Edge case: Grunt takes damage (which writes velocity = knockback) WHILE
	# in STATE_ATTACKING — the recovery handler must zero that knockback on
	# the next tick rather than letting it slide for the rest of recovery.
	# This was the original failure pattern: a hit during recovery → mob
	# floats away.
	var g: Grunt = _make_grunt()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	g.global_position = Vector2.ZERO
	p.global_position = Vector2(Grunt.ATTACK_RANGE - 4.0, 0.0)
	g.set_player(p)
	# Drive into STATE_ATTACKING.
	g._physics_process(0.016)
	g._physics_process(Grunt.LIGHT_TELEGRAPH_DURATION + 0.01)
	assert_eq(g.get_state(), Grunt.STATE_ATTACKING)
	# First recovery tick zeroes the swing-fire pushback.
	g._physics_process(0.016)
	assert_eq(g.velocity, Vector2.ZERO)
	# Now slam a knockback impulse onto the grunt while it's in recovery.
	# take_damage sets velocity = knockback unconditionally (when nonzero).
	g.take_damage(1, Vector2(150.0, 0.0), null)
	assert_almost_eq(g.velocity.x, 150.0, 0.001,
		"take_damage writes knockback velocity even while recovering")
	# Next physics tick — _process_recover must wipe that knockback away
	# (rooted-during-recovery contract). Without the zero-each-tick guard,
	# the grunt would drift at +150 px/s for the rest of ATTACK_RECOVERY.
	g._physics_process(0.016)
	assert_eq(g.velocity, Vector2.ZERO,
		"recovery handler zeros knockback velocity that lands during recovery")


# ---- Combat-trace spy infra (mirrors test_charger.gd / test_shooter.gd) ---
#
# Why a spy node, not an output-text assertion: `DebugFlags.combat_trace` is
# HTML5-only by design (`OS.has_feature("web")`), so the real shim is a no-op
# in headless GUT and the line text never reaches stdout here. The
# `_combat_trace` helper on the mob resolves `DebugFlags` from the tree root
# by name, so we temporarily rename the real autoload, slot in a recording
# spy under the same name, drive the physics frames, assert the spy captured
# the expected tag, then restore the autoload.

class CombatTraceSpy:
	extends Node
	var calls: Array = []  # Array of [tag, msg]
	func combat_trace(tag: String, msg: String = "") -> void:
		calls.append([tag, msg])
	func has_tag(tag: String) -> bool:
		for c: Array in calls:
			if c[0] == tag:
				return true
		return false
	func has_msg_containing(tag: String, needle: String) -> bool:
		for c: Array in calls:
			if c[0] == tag and (c[1] as String).find(needle) != -1:
				return true
		return false


## Swap the real DebugFlags autoload for a recording spy. Returns the spy;
## caller restores via `_restore_debug_flags`.
func _install_combat_trace_spy() -> CombatTraceSpy:
	var root: Node = get_tree().root
	var real: Node = root.get_node_or_null("DebugFlags")
	assert_not_null(real, "DebugFlags autoload must exist to swap for the spy")
	real.name = "DebugFlags__real_parked"
	var spy: CombatTraceSpy = CombatTraceSpy.new()
	spy.name = "DebugFlags"
	root.add_child(spy)
	return spy


func _restore_debug_flags(spy: CombatTraceSpy) -> void:
	var root: Node = get_tree().root
	root.remove_child(spy)
	spy.free()
	var parked: Node = root.get_node_or_null("DebugFlags__real_parked")
	if parked != null:
		parked.name = "DebugFlags"


# ---- Grunt.pos harness-observability trace (ticket 86c9u05d7) ---------
#
# The AC4 multi-chaser clear sub-helper (tests/playwright/fixtures/kiting-
# mob-chase.ts) cannot reliably clear a 3-mob chaser room by fixed-position
# click-spam — a chaser drifts out of the player's swing wedge. The helper
# instead PURSUES, steering off each chaser's throttled `[combat-trace]
# <Mob>.pos` line. `Shooter.pos` already existed (ticket 86c9tz7zg); this
# closes the sibling gap for `Grunt.pos`. Same CombatTraceSpy injection +
# direct-physics-frame pattern as test_shooter.gd's pos-trace test.

func test_pos_trace_emits_after_throttle_interval() -> void:
	var g: Grunt = _make_grunt()
	# Place at a known world position so the trace payload is predictable,
	# and set a player ref so the payload carries a real dist_to_player.
	g.global_position = Vector2(208, 80)
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	p.global_position = Vector2(240, 200)
	g.set_player(p)
	var spy: CombatTraceSpy = _install_combat_trace_spy()
	# One physics frame just under the throttle interval — no emit yet.
	g._physics_process(Grunt.POS_TRACE_INTERVAL - 0.01)
	var emitted_early: bool = spy.has_tag("Grunt.pos")
	# A second frame pushes the accumulator past POS_TRACE_INTERVAL — emit.
	g._physics_process(0.02)
	var emitted_after: bool = spy.has_tag("Grunt.pos")
	# Capture the payload of the emitted line before restoring DebugFlags.
	var pos_msg: String = ""
	for c: Array in spy.calls:
		if c[0] == "Grunt.pos":
			pos_msg = c[1]
			break
	_restore_debug_flags(spy)
	assert_false(emitted_early,
		"Grunt.pos must NOT emit before POS_TRACE_INTERVAL elapses — the " +
		"trace is throttled so it is a cheap no-op on perf")
	assert_true(emitted_after,
		"Grunt.pos must emit once the throttle accumulator passes " +
		"POS_TRACE_INTERVAL — the AC4 multi-chaser clear helper steers off it")
	# Downstream consequence (Tier 2 bar): the payload carries the world
	# coords the harness parses with /pos=\((-?\d+),(-?\d+)\)/.
	assert_string_contains(pos_msg, "pos=(208,80)",
		"Grunt.pos payload must carry the parseable world-coord tuple")
	assert_string_contains(pos_msg, "dist_to_player=",
		"Grunt.pos payload must carry dist_to_player for the chase helper")
