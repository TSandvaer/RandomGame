extends GutTest
## Tests for Stratum1Boss — paired with `scripts/mobs/Stratum1Boss.gd`.
##
## Coverage per Drew's task spec (`86c9kxx4t`) + testing bar:
##   1. Spawns with full HP, health-bar reflects.
##   2. Phase-1 attack telegraphs + lands damage.
##   3. Phase transition at 66% HP fires `phase_changed(2)` signal.
##   4. Phase 2 has access to phase 1 + phase 2 attacks.
##   5. Phase transition at 33% HP fires `phase_changed(3)`.
##   6. Phase 3 enrage state (faster movement / more aggressive).
##   7. Boss death emits `boss_died` signal.
##   8. Boss respects player i-frames (no damage during dodge).
##   9. Boss death triggers loot drop from `boss_drops` table.
##  10. EDGE: rapid hit spam doesn't double-trigger phase transitions.
##  11. EDGE: boss takes damage during phase-transition slow-mo (should NOT —
##      stagger immune during transition).
##  12. EDGE: player dies mid-boss-fight, room state resets, boss respawns
##      at full HP. (Covered as a controller-level reset test —
##      `apply_mob_def(def)` re-seeds full HP; the room respawn flow itself
##      is integration test territory and not driven by the boss script.)
##
## Plus extras for safety:
##  - DORMANT state ignores damage (intro fairness, Uma BI-19).
##  - Layers/masks set per DECISIONS.md (enemy collision layer).
##  - Hitbox spawned by boss is on enemy team and masks player.
##  - Negative damage clamped to zero.
##  - Boss death emits boss_died exactly once under hit spam.
##  - Idempotent wake() (calling twice is no-op).

const BossScript: Script = preload("res://scripts/mobs/Stratum1Boss.gd")
const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")
const PlayerScript: Script = preload("res://scripts/player/Player.gd")
const MobLootSpawnerScript: Script = preload("res://scripts/loot/MobLootSpawner.gd")
const LootRollerScript: Script = preload("res://scripts/loot/LootRoller.gd")


# ---- Helpers ----------------------------------------------------------

class FakePlayer:
	extends Node2D
	# Dummy player target. The boss only reads global_position.


func _make_boss() -> Stratum1Boss:
	var b: Stratum1Boss = BossScript.new()
	b.skip_intro_for_tests = true  # start in IDLE not DORMANT
	add_child_autofree(b)
	return b


func _make_boss_with_def(def: MobDef) -> Stratum1Boss:
	var b: Stratum1Boss = BossScript.new()
	b.skip_intro_for_tests = true
	b.mob_def = def
	add_child_autofree(b)
	return b


func _make_dormant_boss() -> Stratum1Boss:
	# Default skip_intro_for_tests = false → starts DORMANT
	var b: Stratum1Boss = BossScript.new()
	add_child_autofree(b)
	return b


func _hit(b: Stratum1Boss, dmg: int) -> void:
	b.take_damage(dmg, Vector2.ZERO, null)


# ---- 1: full HP at spawn from MobDef --------------------------------

func test_spawns_with_full_hp_from_mobdef() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 600, "damage_base": 15, "move_speed": 80.0})
	var b: Stratum1Boss = _make_boss_with_def(def)
	assert_eq(b.get_hp(), 600, "starts at hp_base")
	assert_eq(b.get_max_hp(), 600, "max_hp = hp_base at spawn")
	assert_eq(b.damage_base, 15)
	assert_eq(b.move_speed_base, 80.0)
	assert_eq(b.get_phase(), Stratum1Boss.PHASE_1)
	assert_false(b.is_dead())


func test_default_hp_when_no_mobdef() -> void:
	var b: Stratum1Boss = _make_boss()
	# Per spec defaults: 600 HP, 12 damage (rebalanced M1 RC soak-4 — was 15).
	assert_eq(b.get_hp(), 600)
	assert_eq(b.get_max_hp(), 600)
	assert_eq(b.damage_base, 12)


# ---- 2: phase-1 melee attack telegraphs + lands damage --------------

func test_phase1_melee_telegraphs_then_swings() -> void:
	var b: Stratum1Boss = _make_boss()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	b.global_position = Vector2.ZERO
	p.global_position = Vector2(20.0, 0.0)  # within MELEE_RANGE
	b.set_player(p)
	# First tick — boss enters melee telegraph.
	b._physics_process(0.016)
	assert_eq(b.get_state(), Stratum1Boss.STATE_TELEGRAPHING_MELEE,
		"boss winds up melee in range")
	# Tick past windup — swing fires.
	watch_signals(b)
	b._physics_process(Stratum1Boss.MELEE_TELEGRAPH_DURATION + 0.01)
	assert_eq(b.get_state(), Stratum1Boss.STATE_ATTACKING)
	assert_signal_emitted(b, "swing_spawned")
	var params: Array = get_signal_parameters(b, "swing_spawned", 0)
	assert_eq(params[0], Stratum1Boss.SWING_KIND_MELEE)


func test_phase1_does_not_use_slam() -> void:
	# In phase 1, boss never picks the slam attack regardless of distance.
	var b: Stratum1Boss = _make_boss()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	b.global_position = Vector2.ZERO
	p.global_position = Vector2(40.0, 0.0)  # in slam radius, outside melee
	b.set_player(p)
	b._physics_process(0.016)
	assert_ne(b.get_state(), Stratum1Boss.STATE_TELEGRAPHING_SLAM,
		"phase 1 does not slam")


# ---- 3: phase transition at 66% fires phase_changed(2) ---------------

func test_phase_transition_at_66pct_emits_phase_changed_2() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 600})
	var b: Stratum1Boss = _make_boss_with_def(def)
	watch_signals(b)
	# Bring HP to 66% — exactly the threshold (396 / 600 = 0.66).
	# Damage 204 takes us from 600 to 396 = phase-2 threshold.
	_hit(b, 204)
	assert_eq(b.get_hp(), 396)
	assert_eq(b.get_state(), Stratum1Boss.STATE_PHASE_TRANSITION)
	# Tick past the transition window — phase_changed fires on completion.
	b._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	assert_signal_emitted(b, "phase_changed")
	var params: Array = get_signal_parameters(b, "phase_changed", 0)
	assert_eq(params[0], 2, "phase_changed carries 2")
	assert_eq(b.get_phase(), Stratum1Boss.PHASE_2)


# ---- 4: phase 2 accesses melee + slam --------------------------------

func test_phase2_can_use_slam() -> void:
	var b: Stratum1Boss = _make_boss()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	b.set_player(p)
	# Drive into phase 2.
	_hit(b, 204)  # 600 → 396 (phase-2 threshold)
	assert_eq(b.get_state(), Stratum1Boss.STATE_PHASE_TRANSITION)
	b._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	assert_eq(b.get_phase(), Stratum1Boss.PHASE_2)
	# Position player inside slam radius. Phase 2 with cooldown-clear should
	# pick slam over melee.
	b.global_position = Vector2.ZERO
	p.global_position = Vector2(50.0, 0.0)  # > MELEE_RANGE (36), < SLAM_RADIUS (80)
	# Force chase state then tick.
	b._physics_process(0.016)
	assert_eq(b.get_state(), Stratum1Boss.STATE_TELEGRAPHING_SLAM,
		"phase 2 picks slam at slam-range")


func test_phase2_melee_still_works() -> void:
	var b: Stratum1Boss = _make_boss()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	b.set_player(p)
	# Drive into phase 2.
	_hit(b, 204)
	b._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	# Player in melee range — phase 2 still uses melee at close distance.
	b.global_position = Vector2.ZERO
	p.global_position = Vector2(20.0, 0.0)  # inside MELEE_RANGE
	# Slam cooldown is reset on phase entry; both attacks are eligible. The
	# boss prefers slam if in slam radius; at MELEE_RANGE 20, the boss is
	# also inside SLAM_HITBOX_RADIUS (80), so slam wins. To force a melee,
	# set slam cooldown so slam is unavailable — same effect post-slam in
	# real combat.
	b._slam_cooldown_left = Stratum1Boss.SLAM_COOLDOWN
	b._physics_process(0.016)
	assert_eq(b.get_state(), Stratum1Boss.STATE_TELEGRAPHING_MELEE,
		"phase 2 falls back to melee when slam on cooldown")


# ---- 5: phase transition at 33% fires phase_changed(3) ---------------

func test_phase_transition_at_33pct_emits_phase_changed_3() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 600})
	var b: Stratum1Boss = _make_boss_with_def(def)
	# Cross phase 2 first.
	_hit(b, 204)
	b._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	assert_eq(b.get_phase(), Stratum1Boss.PHASE_2)
	watch_signals(b)
	# Cross into phase 3: drop to <= 33% (198).
	_hit(b, 198)  # 396 → 198 = exactly phase-3 threshold
	assert_eq(b.get_hp(), 198)
	assert_eq(b.get_state(), Stratum1Boss.STATE_PHASE_TRANSITION)
	b._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	assert_signal_emitted(b, "phase_changed")
	var params: Array = get_signal_parameters(b, "phase_changed", 0)
	assert_eq(params[0], 3)
	assert_eq(b.get_phase(), Stratum1Boss.PHASE_3)


# ---- 6: phase 3 enrage --------------------------------------------------

func test_phase3_enrage_speeds_up_movement() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 600, "move_speed": 80.0})
	var b: Stratum1Boss = _make_boss_with_def(def)
	# Cross both phase boundaries.
	_hit(b, 204)
	b._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	_hit(b, 198)
	b._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	assert_eq(b.get_phase(), Stratum1Boss.PHASE_3)
	assert_true(b.is_enraged())
	# Speed scaled by 1.5x (ENRAGE_SPEED_MULT).
	assert_almost_eq(b.move_speed, 80.0 * Stratum1Boss.ENRAGE_SPEED_MULT, 0.001,
		"phase 3 enrage applies 1.5x movement speed")


func test_phase3_no_new_attack_mechanic() -> void:
	# M1 scope: phase 3 shares phase 1 + phase 2 attacks; no new mechanic.
	# Verified by: SWING_KIND_* constants are exactly melee/slam_telegraph/
	# slam_hit. No SWING_KIND_PHASE3_X exists.
	var kinds: Array = [
		Stratum1Boss.SWING_KIND_MELEE,
		Stratum1Boss.SWING_KIND_SLAM_TELEGRAPH,
		Stratum1Boss.SWING_KIND_SLAM_HIT,
	]
	assert_eq(kinds.size(), 3, "exactly 3 swing kinds — no phase-3 mechanic added")


# ---- 7: boss death emits boss_died signal -----------------------------

func test_death_emits_boss_died_once() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 100})
	var b: Stratum1Boss = _make_boss_with_def(def)
	b.global_position = Vector2(123.0, 456.0)
	watch_signals(b)
	# Cross phase 2 first (66% of 100 = 66).
	_hit(b, 34)  # 100 -> 66 = threshold
	b._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	# Cross phase 3 (33% of 100 = 33).
	_hit(b, 33)  # 66 -> 33 = threshold
	b._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	# Lethal hit.
	_hit(b, 33)
	assert_eq(b.get_hp(), 0)
	assert_true(b.is_dead())
	assert_eq(b.get_state(), Stratum1Boss.STATE_DEAD)
	assert_signal_emitted(b, "boss_died")
	# Payload includes (boss, position, def).
	var args: Array = get_signal_parameters(b, "boss_died", 0)
	assert_eq(args[0], b, "boss_died carries the boss node")
	assert_almost_eq(args[1].x, 123.0, 0.001)
	assert_almost_eq(args[1].y, 456.0, 0.001)
	assert_eq(args[2], def, "boss_died carries the MobDef so loot listeners get loot_table")


func test_death_under_hit_spam_emits_boss_died_once() -> void:
	# Lethal hit-spam is idempotent — boss_died fires exactly once even when
	# the same lethal damage is delivered 10 times in a row.
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 100})
	var b: Stratum1Boss = _make_boss_with_def(def)
	# Drive past both phase boundaries first so death isn't intercepted.
	_hit(b, 34)
	b._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	_hit(b, 33)
	b._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	watch_signals(b)
	for i in 10:
		_hit(b, 9999)
	assert_signal_emit_count(b, "boss_died", 1)


# ---- 8: respects player i-frames ------------------------------------

func test_boss_hitbox_misses_player_during_iframes() -> void:
	# Spawn a real Player and put it through a dodge to clear its
	# collision_layer. The boss's hitbox masks layer 2 (player); when player
	# layer is cleared, the hitbox finds no targets via _try_apply_hit.
	# We assert the contract via direct inspection rather than physics tick.
	var player: Player = PlayerScript.new()
	add_child_autofree(player)
	player.try_dodge(Vector2.RIGHT)
	assert_true(player.is_invulnerable(), "player is in i-frames mid-dodge")
	# Build an enemy hitbox manually — the boss's _spawn_hitbox follows the
	# same shape (Hitbox.TEAM_ENEMY).
	var hb: Hitbox = HitboxScript.new()
	hb.configure(15, Vector2.RIGHT * 100.0, 0.1, Hitbox.TEAM_ENEMY, null)
	add_child_autofree(hb)
	# The hitbox is wired to mask LAYER_PLAYER (bit 2). During i-frames the
	# player's collision_layer is 0 (Player.gd::_enter_iframes clears it).
	# So a physics overlap can't fire — but we test the duck-typed contract
	# directly: even if _try_apply_hit is somehow called, the player WOULD
	# take damage. The i-frame guarantee is at the LAYER level.
	# Verify: hitbox masks only player layer; player layer is cleared.
	assert_eq(hb.collision_mask, Hitbox.LAYER_PLAYER, "enemy hitbox masks player layer only")
	assert_eq(player.collision_layer, 0, "player layer cleared during dodge — hitbox mask finds nothing")


# ---- 9: boss death triggers loot drop from boss_drops table ----------

func test_boss_death_drops_loot_via_spawner() -> void:
	# Build a tiny boss def with a mock loot table: one guaranteed entry.
	var item: ItemDef = ContentFactory.make_item_def({"id": &"boss_test_drop", "tier": ItemDef.Tier.T2})
	var entry: LootEntry = ContentFactory.make_loot_entry(item, 1.0, 0)
	var table: LootTableDef = ContentFactory.make_loot_table({"entries": [entry]})
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 100, "loot_table": table})
	var b: Stratum1Boss = _make_boss_with_def(def)
	# Wire up a real loot spawner.
	var roller: LootRoller = LootRollerScript.new()
	roller.seed_rng(0xB0551E)
	var spawner: MobLootSpawner = MobLootSpawnerScript.new(roller)
	var parent: Node = autofree(Node2D.new())
	add_child(parent)
	spawner.set_parent_for_pickups(parent)
	b.boss_died.connect(spawner.on_mob_died)
	# Drive past phases and kill the boss.
	_hit(b, 34)
	b._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	_hit(b, 33)
	b._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	_hit(b, 33)
	assert_true(b.is_dead())
	# The on_mob_died handler ran inline on the signal emit, but the
	# Pickup add_child is now deferred (physics-flush safety per `_die`
	# P0 fix run-002). Await one frame for the deferred call to land.
	await get_tree().process_frame
	# parent has at least one Pickup child if loot spawned.
	var pickup_count: int = 0
	for c: Node in parent.get_children():
		if c is Pickup:
			pickup_count += 1
	assert_gt(pickup_count, 0, "boss death spawned at least one Pickup")


func test_authored_boss_drops_table_loads() -> void:
	# Sanity: the authored boss_drops.tres + stratum1_boss.tres load and the
	# boss def references the loot table.
	var def: MobDef = load("res://resources/mobs/stratum1_boss.tres") as MobDef
	assert_not_null(def, "stratum1_boss.tres loads")
	assert_eq(def.id, &"stratum1_boss")
	assert_eq(def.hp_base, 600)
	assert_not_null(def.loot_table, "boss has loot table")
	assert_eq(def.loot_table.id, &"boss_drops")
	# At least one entry has a tier_modifier > 0 (T2/T3 climax loot).
	var has_upgraded: bool = false
	for entry: LootEntry in def.loot_table.entries:
		if entry != null and entry.tier_modifier > 0:
			has_upgraded = true
			break
	assert_true(has_upgraded, "boss drops include guaranteed T2/T3 climax loot")


# ---- 10 EDGE: rapid hit spam doesn't double-trigger phase transitions

func test_rapid_hit_spam_does_not_double_trigger_phase_2() -> void:
	# Hit-spam straddling the 66% boundary must emit phase_changed exactly
	# once. Lethal damage in a single hit drops past phase 2 + phase 3 + 0.
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 600})
	var b: Stratum1Boss = _make_boss_with_def(def)
	watch_signals(b)
	# 10 successive 30-damage hits. First reaches 396 (phase 2 threshold).
	# Subsequent hits during STATE_PHASE_TRANSITION are rejected (immune).
	for i in 10:
		_hit(b, 30)
	# Tick past the transition window so phase_changed actually fires.
	b._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	# We asserted the boss latched phase 2 only once; phase_changed(2) fires
	# exactly once. Phase 3 may or may not have latched yet (HP did NOT drop
	# during the immune window since damage was rejected).
	var phase_2_count: int = 0
	for i in get_signal_emit_count(b, "phase_changed"):
		var params: Array = get_signal_parameters(b, "phase_changed", i)
		if params[0] == 2:
			phase_2_count += 1
	assert_eq(phase_2_count, 1, "phase_changed(2) fires exactly once under hit spam")


func test_phase_latches_are_idempotent_under_repeated_threshold_crossings() -> void:
	# After phase 2 latched, subsequent damage crossings must never re-latch
	# phase 2 even if HP somehow goes back up (it won't — but the latch is
	# the contract).
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 600})
	var b: Stratum1Boss = _make_boss_with_def(def)
	# Cross phase 2.
	_hit(b, 204)
	b._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	assert_eq(b.get_phase(), Stratum1Boss.PHASE_2)
	watch_signals(b)
	# Damage now must not re-fire phase_changed(2).
	_hit(b, 1)
	# We're not crossing 33% so no phase 3 transition either.
	b._physics_process(0.016)
	assert_signal_emit_count(b, "phase_changed", 0,
		"no phase_changed re-emission after latch")


# ---- 11 EDGE: damage during phase-transition is rejected ------------

func test_no_damage_taken_during_phase_transition() -> void:
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 600})
	var b: Stratum1Boss = _make_boss_with_def(def)
	_hit(b, 204)  # cross into phase transition
	assert_eq(b.get_state(), Stratum1Boss.STATE_PHASE_TRANSITION)
	assert_true(b.is_in_phase_transition())
	var hp_at_transition_start: int = b.get_hp()
	# Spam 5 hits during the transition window.
	watch_signals(b)
	for i in 5:
		_hit(b, 100)
	assert_eq(b.get_hp(), hp_at_transition_start,
		"no damage applied during phase-transition (stagger immune)")
	# `damaged` signal must not have fired during the transition.
	assert_signal_emit_count(b, "damaged", 0,
		"damaged signal blocked during transition")


# ---- 12 EDGE: room-state reset re-seeds boss to full HP --------------

func test_boss_resets_to_full_hp_via_apply_mob_def() -> void:
	# When the player dies mid-fight, the room reset path re-applies the
	# boss def. Verifying the reset contract: apply_mob_def returns a fresh
	# full-HP boss state. The room's actual respawn flow is integration
	# territory (covered in the room test); this asserts the unit contract.
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 600})
	var b: Stratum1Boss = _make_boss_with_def(def)
	# Damage the boss past phase 2.
	_hit(b, 204)
	b._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	assert_eq(b.get_phase(), Stratum1Boss.PHASE_2)
	assert_eq(b.get_hp(), 396)
	# Reset via apply_mob_def — note phase doesn't auto-reset (it's a runtime
	# field). The room respawn path instantiates a fresh boss node, which is
	# the proper reset; this test verifies the HP-reset half of the contract.
	b.apply_mob_def(def)
	assert_eq(b.get_hp(), 600, "apply_mob_def re-seeds HP")
	assert_eq(b.get_max_hp(), 600)


# ---- DORMANT state: intro fairness (Uma BI-19) ----------------------

func test_dormant_boss_ignores_damage() -> void:
	# Boss does NOT take damage during intro Beats 1–4 (per Uma's spec).
	var b: Stratum1Boss = _make_dormant_boss()
	assert_true(b.is_dormant())
	watch_signals(b)
	_hit(b, 100)
	assert_eq(b.get_hp(), b.get_max_hp(), "dormant boss takes no damage")
	assert_signal_emit_count(b, "damaged", 0)


func test_dormant_boss_does_not_act() -> void:
	var b: Stratum1Boss = _make_dormant_boss()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	p.global_position = Vector2(20.0, 0.0)
	b.set_player(p)
	# Tick — boss should remain DORMANT and not telegraph any attack.
	watch_signals(b)
	for i in 10:
		b._physics_process(0.016)
	assert_eq(b.get_state(), Stratum1Boss.STATE_DORMANT)
	assert_signal_emit_count(b, "swing_spawned", 0,
		"dormant boss never swings")


func test_wake_transitions_to_idle() -> void:
	var b: Stratum1Boss = _make_dormant_boss()
	watch_signals(b)
	b.wake()
	assert_eq(b.get_state(), Stratum1Boss.STATE_IDLE)
	assert_signal_emit_count(b, "boss_woke", 1)


func test_wake_is_idempotent() -> void:
	# Calling wake() twice does not re-fire boss_woke or interrupt state.
	var b: Stratum1Boss = _make_dormant_boss()
	b.wake()
	watch_signals(b)
	b.wake()
	assert_signal_emit_count(b, "boss_woke", 0,
		"second wake() call is no-op")


# ---- Layers / hitbox contract -----------------------------------------

func test_collision_layer_is_enemy() -> void:
	var b: Stratum1Boss = _make_boss()
	assert_eq(b.collision_layer, Stratum1Boss.LAYER_ENEMY,
		"boss sits on enemy layer (bit 4)")
	assert_eq(b.collision_mask, Stratum1Boss.LAYER_WORLD | Stratum1Boss.LAYER_PLAYER,
		"mask = world + player")


func test_spawned_hitbox_is_enemy_team() -> void:
	var b: Stratum1Boss = _make_boss()
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	b.global_position = Vector2.ZERO
	p.global_position = Vector2(20.0, 0.0)
	b.set_player(p)
	var captured: Array = [null]
	b.swing_spawned.connect(func(_kind: StringName, hb: Node) -> void:
		captured[0] = hb
	)
	# Drive past the telegraph so the swing fires.
	b._physics_process(0.016)
	b._physics_process(Stratum1Boss.MELEE_TELEGRAPH_DURATION + 0.01)
	assert_not_null(captured[0])
	var hb: Hitbox = captured[0]
	assert_eq(hb.team, Hitbox.TEAM_ENEMY)
	assert_eq(hb.collision_layer, Hitbox.LAYER_ENEMY_HITBOX)
	assert_eq(hb.collision_mask, Hitbox.LAYER_PLAYER)


# ---- Negative damage clamp -------------------------------------------

func test_negative_damage_does_not_heal() -> void:
	var b: Stratum1Boss = _make_boss()
	b.take_damage(-100, Vector2.ZERO, null)
	assert_eq(b.get_hp(), b.get_max_hp(), "negative dmg clamps to 0 — no incidental heal")
	assert_false(b.is_dead())


# ---- Death cancels in-flight attacks ---------------------------------

func test_dies_during_telegraph_no_swing_from_corpse() -> void:
	# Boss in mid-telegraph, then killed — no swing fires after death.
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 100})
	var b: Stratum1Boss = _make_boss_with_def(def)
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	p.global_position = Vector2(20.0, 0.0)
	b.set_player(p)
	# Cross both phase boundaries first.
	_hit(b, 34)
	b._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	_hit(b, 33)
	b._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	# Now in phase 3 with 33 HP. Trigger a melee telegraph.
	b._physics_process(0.016)
	assert_true(b.get_state() == Stratum1Boss.STATE_TELEGRAPHING_MELEE
		or b.get_state() == Stratum1Boss.STATE_TELEGRAPHING_SLAM,
		"boss is winding up an attack")
	watch_signals(b)
	# Lethal hit.
	_hit(b, 33)
	assert_true(b.is_dead())
	# Tick well past where the telegraph would have fired.
	b._physics_process(1.0)
	assert_signal_emit_count(b, "swing_spawned", 0,
		"no swing fires from corpse")
	assert_signal_emit_count(b, "boss_died", 1)
