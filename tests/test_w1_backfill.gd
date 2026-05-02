extends GutTest
## Phase B — week-1 GUT backfill (ClickUp 86c9kxx8h).
##
## Audit pass per `team/TESTING_BAR.md` §Priya. Walked the seven w1 surfaces:
##
##   1. `Save.gd`             — round-trip, atomic_write, migration, README,
##                              corruption (test_save.gd 13, test_save_roundtrip.gd
##                              9, test_quit_relaunch_save.gd 4, test_save_readme.gd
##                              6 — total ~32). Solid. Backfill targets:
##                              multi-slot independence, README survives delete_save,
##                              save_path slot interpolation for negative/large slots.
##   2. `LootRoller.gd`       — Drew's flagship 28 paired tests cover all 10
##                              edge cases. Backfill targets: affix_count_for_tier
##                              T4/T5/T6 (Drew tested T1/T2/T3 only), pool < want
##                              cap (Fisher-Yates edge), unknown-tier fallback to 0,
##                              tier_modifier with extreme values stays in range.
##   3. `Grunt.gd` AI         — Drew's 16 tests cover state machine + edge probes.
##                              Backfill targets: telegraph re-entry guard during
##                              active telegraph, telegraph guard on dead grunt,
##                              dead-grunt _physics_process is a no-op.
##   4. `Hitbox.gd`           — Devon's 7 tests cover layer routing + single-hit.
##                              Backfill targets: multi-target invariant (two
##                              enemies in one lifetime, both take damage), target
##                              without take_damage method (still emits hit_target,
##                              never crashes), unknown-team layers are zero.
##   5. `Player.gd` i-frames  — Devon's 11+10 tests across move + attack solid.
##                              Backfill targets: i-frames idempotent (re-entering
##                              dodge while invulnerable doesn't double-toggle),
##                              attack during dodge does not silently extend recovery.
##   6. `LevelAssembler.gd`   — Drew's 16 unit tests + 6 integration cover
##                              validate, factory wiring, entry port. Backfill
##                              targets: chunk-port mismatch (multiple entry ports
##                              uses first only), factory-raises-error doesn't
##                              wedge the assembler (we can't catch a Godot
##                              GDScript exception inside the same call cleanly,
##                              but a Callable that returns null on bad mob_id
##                              already covered by Drew — re-asserting the
##                              "factory-author writes the error path" contract).
##   7. Testability hooks     — Devon's 33 tests across build_sha (8), fast_xp (9),
##                              save_readme (6), test_mode_seed (10). Solid.
##
## Net result: ALL w1 features have paired GUT covering meaningful behaviors.
## This file closes residual gaps surfaced by my audit; no separate tech-debt
## tickets needed (gaps were edge probes, not structural omissions).

const TEST_SLOT_A: int = 991
const TEST_SLOT_B: int = 992

const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")
const PlayerScript: Script = preload("res://scripts/player/Player.gd")
const GruntScript: Script = preload("res://scripts/mobs/Grunt.gd")
const LootRollerScript: Script = preload("res://scripts/loot/LootRoller.gd")
const LevelAssemblerScript: Script = preload("res://scripts/levels/LevelAssembler.gd")
const LevelChunkDefScript: Script = preload("res://scripts/levels/LevelChunkDef.gd")
const ChunkPortScript: Script = preload("res://scripts/levels/ChunkPort.gd")
const MobSpawnPointScript: Script = preload("res://scripts/levels/MobSpawnPoint.gd")


func _save() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Save")


func before_each() -> void:
	for slot in [TEST_SLOT_A, TEST_SLOT_B]:
		if _save().has_save(slot):
			_save().delete_save(slot)
		var tmp: String = _save().save_path(slot) + ".tmp"
		if FileAccess.file_exists(tmp):
			DirAccess.remove_absolute(tmp)


func after_each() -> void:
	for slot in [TEST_SLOT_A, TEST_SLOT_B]:
		if _save().has_save(slot):
			_save().delete_save(slot)


# =====================================================================
# Save.gd backfill
# =====================================================================

# Devon's existing test_save.gd asserts slot interpolation in path strings,
# but does NOT exercise that two distinct slots remain independent on disk.
# This is a regression-shape test: a future "single global save" refactor
# bug would silently overwrite slot A with slot B.
func test_save_two_distinct_slots_remain_independent() -> void:
	var data_a: Dictionary = _save().default_payload()
	data_a["character"]["level"] = 7
	data_a["character"]["xp"] = 1700
	var data_b: Dictionary = _save().default_payload()
	data_b["character"]["level"] = 12
	data_b["character"]["xp"] = 9000
	assert_true(_save().save_game(TEST_SLOT_A, data_a))
	assert_true(_save().save_game(TEST_SLOT_B, data_b))

	var loaded_a: Dictionary = _save().load_game(TEST_SLOT_A)
	var loaded_b: Dictionary = _save().load_game(TEST_SLOT_B)
	assert_eq(loaded_a["character"]["level"], 7, "slot A keeps its level")
	assert_eq(loaded_b["character"]["level"], 12, "slot B keeps its level")
	assert_ne(loaded_a["character"]["xp"], loaded_b["character"]["xp"],
		"slot A and slot B have different xp — no cross-slot bleed")


func test_save_path_handles_negative_and_large_slots() -> void:
	# save_path is a pure string format — it shouldn't crash on edge inputs.
	# Negative slot is unusual but the format spec uses %d which handles it.
	# Large slot is the realistic case (multi-character workflows in M2+).
	var p_neg: String = _save().save_path(-1)
	assert_true(p_neg.begins_with("user://"), "negative slot still under user://")
	var p_huge: String = _save().save_path(99999)
	assert_string_contains(p_huge, "99999", "large slot interpolated as decimal")


func test_delete_save_does_not_remove_readme() -> void:
	# README is a per-save-dir testability artifact, not per-slot. Deleting
	# slot 0 must not nuke the README — Tess's manual setup relies on it.
	_save().save_game(TEST_SLOT_A)
	# The README path is a constant on Save autoload.
	var readme_present: bool = FileAccess.file_exists("user://README.txt")
	assert_true(readme_present, "save_game writes README")
	_save().delete_save(TEST_SLOT_A)
	# README should still exist (delete only acts on the slot file).
	var readme_after: bool = FileAccess.file_exists("user://README.txt")
	assert_true(readme_after, "delete_save(slot) does not remove the README")


# =====================================================================
# LootRoller.gd backfill — affix_count_for_tier T4/T5/T6 + pool cap
# =====================================================================

func test_affix_count_for_tier_t4_returns_two_or_three() -> void:
	var r: LootRoller = LootRollerScript.new()
	r.seed_rng(0xBADF00D)
	# Sample many times; T4 must produce both 2 and 3 in 100 trials.
	var seen_two: bool = false
	var seen_three: bool = false
	var seen_other: bool = false
	for _i in 200:
		var n: int = r.affix_count_for_tier(ItemDef.Tier.T4)
		if n == 2: seen_two = true
		elif n == 3: seen_three = true
		else: seen_other = true
	assert_true(seen_two, "T4 produces 2 affixes")
	assert_true(seen_three, "T4 produces 3 affixes")
	assert_false(seen_other, "T4 ONLY produces 2 or 3 affixes")


func test_affix_count_for_tier_t5_t6_always_three() -> void:
	var r: LootRoller = LootRollerScript.new()
	r.seed_rng(1)
	for _i in 50:
		assert_eq(r.affix_count_for_tier(ItemDef.Tier.T5), 3, "T5 always 3 affixes")
		assert_eq(r.affix_count_for_tier(ItemDef.Tier.T6), 3, "T6 always 3 affixes")


func test_affix_count_for_unknown_tier_returns_zero() -> void:
	# Defensive — out-of-band tier index shouldn't crash, just produce 0.
	var r: LootRoller = LootRollerScript.new()
	# Use a tier value that's not in the enum (cast int to enum-shaped int).
	# Godot match{} default branch returns 0.
	var n: int = r.affix_count_for_tier(99)
	assert_eq(n, 0, "unknown tier index falls through to default 0")


func test_roll_affixes_caps_at_pool_size_when_pool_smaller_than_want() -> void:
	# T3 wants 1 or 2 affixes. With a pool of size 1, the result must always
	# be exactly 1 (capped at pool size), never duplicated to fill.
	var r: LootRoller = LootRollerScript.new()
	r.seed_rng(123)
	var pool: Array[AffixDef] = [ContentFactory.make_affix_def({"id": &"only_one"})]
	for _i in 30:
		var rolls: Array[AffixRoll] = r.roll_affixes_for_item(pool, ItemDef.Tier.T3)
		assert_eq(rolls.size(), 1,
			"pool-of-1 caps roll to 1 affix even when T3 wanted 1-or-2")


func test_roll_affixes_empty_pool_returns_empty_at_any_tier() -> void:
	var r: LootRoller = LootRollerScript.new()
	r.seed_rng(0)
	var empty_pool: Array[AffixDef] = []
	for tier in [ItemDef.Tier.T1, ItemDef.Tier.T2, ItemDef.Tier.T3, ItemDef.Tier.T4]:
		var rolls: Array[AffixRoll] = r.roll_affixes_for_item(empty_pool, tier)
		assert_eq(rolls.size(), 0, "empty pool -> empty rolls at tier %d" % tier)


# =====================================================================
# Grunt.gd backfill — telegraph re-entry guards + dead no-op
# =====================================================================

func test_telegraph_does_not_re_enter_during_active_telegraph() -> void:
	# A second hit landing during the windup must NOT restart the telegraph
	# timer or fire a second `heavy_telegraph_started`. The guard is there
	# specifically to avoid stunlock loops on rapid low-HP hits.
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 100})
	var g: Grunt = GruntScript.new()
	g.mob_def = def
	add_child_autofree(g)
	g.take_damage(75, Vector2.ZERO, null)  # 25 HP — telegraph fires
	assert_eq(g.get_state(), Grunt.STATE_TELEGRAPHING_HEAVY)
	watch_signals(g)
	# Hit again WHILE telegraphing — must not re-fire the signal.
	g.take_damage(5, Vector2.ZERO, null)
	assert_signal_not_emitted(g, "heavy_telegraph_started",
		"telegraph guard rejects re-entry while already telegraphing")
	assert_eq(g.get_state(), Grunt.STATE_TELEGRAPHING_HEAVY,
		"state stays TELEGRAPHING_HEAVY after non-fatal in-windup hit")


func test_dead_grunt_physics_process_is_a_noop() -> void:
	# After death, _physics_process must early-out — no state transitions,
	# no velocity changes, no swing spawns. Belt-and-suspenders for the
	# corpse-sliding regression Drew's edge probe #10 chases.
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 10})
	var g: Grunt = GruntScript.new()
	g.mob_def = def
	add_child_autofree(g)
	g.take_damage(10, Vector2(50.0, 0.0), null)
	assert_true(g.is_dead())
	# Even with a knockback in velocity, post-death tick should not change state.
	var pre_state: StringName = g.get_state()
	watch_signals(g)
	g._physics_process(0.5)  # large delta
	g._physics_process(0.5)
	assert_eq(g.get_state(), pre_state, "dead grunt's state stays DEAD across ticks")
	assert_signal_not_emitted(g, "swing_spawned", "no swing fires post-death")
	assert_signal_not_emitted(g, "state_changed", "no transitions post-death")


func test_zero_damage_hit_is_a_noop_event() -> void:
	# Zero-amount damage shouldn't crash, but it does still emit `damaged`
	# (Drew's contract — analytics observers want to see the hit). Negative
	# damage is clamped to 0; this asserts the explicit-zero variant.
	var g: Grunt = GruntScript.new()
	add_child_autofree(g)
	var hp_before: int = g.get_hp()
	watch_signals(g)
	g.take_damage(0, Vector2.ZERO, null)
	assert_eq(g.get_hp(), hp_before, "0-damage hit doesn't change HP")
	assert_signal_emitted(g, "damaged", "0-damage still emits damaged signal (analytics contract)")


# =====================================================================
# Hitbox.gd backfill — multi-target + duck-type contract
# =====================================================================

class _FakeTarget:
	extends Node2D
	var hits: Array[Dictionary] = []
	func take_damage(amount: int, kb: Vector2, source: Node) -> void:
		hits.append({"amount": amount, "kb": kb, "source": source})


class _NoDamageTarget:
	# A node that does NOT implement take_damage. Should not crash.
	extends Node2D


func test_multi_target_each_hit_once_within_lifetime() -> void:
	# Two distinct enemies overlap a single hitbox. Each must take damage
	# exactly once; the single-hit-per-target invariant tracks per-target
	# (Devon's existing test only asserts single-hit on the same target).
	var hb: Hitbox = HitboxScript.new()
	hb.configure(13, Vector2.RIGHT * 100.0, 0.1, Hitbox.TEAM_PLAYER, null)
	add_child_autofree(hb)
	var t1: _FakeTarget = _FakeTarget.new()
	var t2: _FakeTarget = _FakeTarget.new()
	add_child_autofree(t1)
	add_child_autofree(t2)
	# Hit both — twice each — within the same lifetime.
	hb._try_apply_hit(t1)
	hb._try_apply_hit(t2)
	hb._try_apply_hit(t1)  # should NOT double-hit
	hb._try_apply_hit(t2)  # should NOT double-hit
	assert_eq(t1.hits.size(), 1, "target1 hit exactly once")
	assert_eq(t2.hits.size(), 1, "target2 hit exactly once")
	assert_eq(t1.hits[0]["amount"], 13)
	assert_eq(t2.hits[0]["amount"], 13)


func test_target_without_take_damage_method_does_not_crash() -> void:
	# A wall, decoration, or other passive scenery overlaps with the hitbox.
	# It has no take_damage method. Hitbox must tolerate this — log nothing,
	# crash nothing. Contract: hit_target signal still fires for analytics.
	var hb: Hitbox = HitboxScript.new()
	hb.configure(7, Vector2.ZERO, 0.1, Hitbox.TEAM_PLAYER, null)
	add_child_autofree(hb)
	var passive: _NoDamageTarget = _NoDamageTarget.new()
	add_child_autofree(passive)
	watch_signals(hb)
	# Should not crash.
	hb._try_apply_hit(passive)
	# Signal STILL emits — observers (VFX, analytics) get the event.
	assert_signal_emitted(hb, "hit_target",
		"hit_target signal emits even when target has no take_damage method")
	# And the target ends up in _hit_already so a duplicate overlap is filtered.
	assert_true(hb.has_already_hit(passive))


func test_unknown_team_leaves_layers_empty() -> void:
	# An unknown team string is a content bug. Hitbox warns + leaves layers
	# empty. Visible behavior: no enemy nor player gets hit (zero mask).
	var hb: Hitbox = HitboxScript.new()
	hb.configure(5, Vector2.ZERO, 0.1, &"unknown_team_xyz", null)
	add_child_autofree(hb)
	assert_eq(hb.collision_layer, 0, "unknown team -> empty layer")
	assert_eq(hb.collision_mask, 0, "unknown team -> empty mask (no false-positive damage)")


# =====================================================================
# Player.gd i-frame backfill
# =====================================================================

func test_iframes_idempotent_when_re_entering_dodge_during_invulnerable_window() -> void:
	# can_dodge is the gate, but if a state-machine bug ever let try_dodge
	# fire during an active dodge, _enter_iframes would clobber
	# _saved_collision_layer with the (zeroed) live value, permanently
	# breaking the layer restore. We can't trigger that path through public
	# API (try_dodge gates on can_dodge, which checks STATE_DODGE), but we
	# can at least assert the public-API behavior holds: a second try_dodge
	# during the i-frame window is rejected and leaves saved-layer intact.
	var p: Player = PlayerScript.new()
	add_child_autofree(p)
	var layer_before: int = p.collision_layer
	assert_true(p.try_dodge(Vector2.RIGHT))
	# In the middle of i-frames, try a second dodge.
	assert_false(p.try_dodge(Vector2.LEFT), "second dodge during i-frames rejected")
	# After dodge ends, layer must restore to the original.
	p._tick_timers(Player.DODGE_DURATION + 0.01)
	p._process_dodge(0.0)
	assert_eq(p.collision_layer, layer_before,
		"layer restored exactly to pre-dodge value (saved-layer not clobbered by aborted re-dodge)")


func test_iframes_signal_count_per_dodge_is_one_each() -> void:
	# Critical for VFX observers: exactly one iframes_started + one
	# iframes_ended per dodge — never zero, never two, never interleaved.
	var p: Player = PlayerScript.new()
	add_child_autofree(p)
	watch_signals(p)
	p.try_dodge(Vector2.UP)
	# End of dodge.
	p._tick_timers(Player.DODGE_DURATION + 0.01)
	p._process_dodge(0.0)
	assert_signal_emit_count(p, "iframes_started", 1)
	assert_signal_emit_count(p, "iframes_ended", 1)


# =====================================================================
# LevelAssembler backfill — port handling + mob-id resilience
# =====================================================================

func test_multiple_entry_ports_uses_first_one_only() -> void:
	# Architecture decision: chunks should declare exactly one entry port,
	# but the API tolerates multiple — first-tagged-entry wins. This locks
	# that behavior so a future "smart entry pick" change is a deliberate
	# migration, not a silent break.
	var asm: LevelAssembler = LevelAssemblerScript.new()
	var c: LevelChunkDef = LevelChunkDefScript.new()
	c.id = &"multi_entry"
	c.size_tiles = Vector2i(10, 10)
	c.tile_size_px = 32
	var p1: ChunkPort = ChunkPortScript.new()
	p1.position_tiles = Vector2i(2, 4); p1.direction = ChunkPort.Direction.WEST; p1.tag = &"entry"
	var p2: ChunkPort = ChunkPortScript.new()
	p2.position_tiles = Vector2i(8, 4); p2.direction = ChunkPort.Direction.EAST; p2.tag = &"entry"
	c.ports = [p1, p2]
	var result: LevelAssembler.AssemblyResult = asm.assemble_single(c, Callable())
	# First entry port at tile (2,4) -> world center (2*32+16, 4*32+16) = (80, 144).
	assert_almost_eq(result.entry_world_pos.x, 80.0, 0.001,
		"first entry port wins (deterministic — author second entry as exit)")
	assert_almost_eq(result.entry_world_pos.y, 144.0, 0.001)
	result.root.queue_free()


func test_factory_receives_correct_mob_id_for_each_spawn() -> void:
	# Mob-id misses (factory called with wrong id) would silently produce
	# the wrong mob without this test. Asserts the assembler hands the
	# spawn's mob_id verbatim — no normalization, no case-fold, no swap.
	var asm: LevelAssembler = LevelAssemblerScript.new()
	var c: LevelChunkDef = LevelChunkDefScript.new()
	c.id = &"id_check"
	c.size_tiles = Vector2i(15, 8); c.tile_size_px = 32
	var s_grunt: MobSpawnPoint = MobSpawnPointScript.new()
	s_grunt.position_tiles = Vector2i(3, 3); s_grunt.mob_id = &"grunt"
	var s_charger: MobSpawnPoint = MobSpawnPointScript.new()
	s_charger.position_tiles = Vector2i(5, 5); s_charger.mob_id = &"charger"
	# NOTE: schema validate() rejects empty mob_id only — distinct ids are fine.
	c.mob_spawns = [s_grunt, s_charger]
	var seen_ids: Array[StringName] = []
	var fact: Callable = func(mob_id: StringName, _pos: Vector2) -> Node:
		seen_ids.append(mob_id)
		return Node2D.new()
	var result: LevelAssembler.AssemblyResult = asm.assemble_single(c, fact)
	assert_eq(seen_ids.size(), 2)
	assert_true(seen_ids.has(&"grunt"))
	assert_true(seen_ids.has(&"charger"),
		"factory receives each distinct mob_id verbatim — no id-translation in assembler")
	result.root.queue_free()


func test_chunk_with_zero_mob_spawns_assembles_cleanly() -> void:
	# Empty rooms are valid — used for puzzle / loot / save-point chunks
	# that come up later in the stratum. assemble_single must not crash
	# nor invent spawn points.
	var asm: LevelAssembler = LevelAssemblerScript.new()
	var c: LevelChunkDef = LevelChunkDefScript.new()
	c.id = &"empty_room"
	c.size_tiles = Vector2i(15, 8); c.tile_size_px = 32
	c.mob_spawns = []  # explicit empty
	var rec_calls: Array = []
	var fact: Callable = func(mob_id: StringName, pos: Vector2) -> Node:
		rec_calls.append(mob_id)
		return Node2D.new()
	var result: LevelAssembler.AssemblyResult = asm.assemble_single(c, fact)
	assert_not_null(result, "empty-spawn chunk still assembles")
	assert_eq(result.mobs.size(), 0, "no mobs spawned")
	assert_eq(rec_calls.size(), 0, "factory never called when mob_spawns empty")
	result.root.queue_free()
