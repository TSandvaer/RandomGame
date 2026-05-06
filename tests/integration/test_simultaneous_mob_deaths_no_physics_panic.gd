extends GutTest
## Regression test for the run-002 P0 — `_die` synchronous physics-state
## mutations during the body_entered flush.
##
## **Symptom (Sponsor's `embergrave-html5-4ab2813` retest):** with the
## diagnostic 2-swing-kill HP, two grunts both reach hp=0 in the same
## physics frame. The first mob's `_die → _play_death_tween |
## timer_armed=0.400s` logs cleanly; the second mob's `_die | starting
## death sequence` logs and then Godot fires:
##
##     USER ERROR: Can't change this state while flushing queries. Use
##     call_deferred() or set_deferred() to change monitoring state instead.
##
## After the panic, neither mob ever reaches `_force_queue_free` and the
## death sequence stalls. PR #136's queue_free decouple is correct on the
## first mob (timer fires) but the panic aborts the call chain on the
## second.
##
## **Root cause:** mob death emits `mob_died`, whose synchronously-running
## listeners include `MobLootSpawner.on_mob_died` (which calls
## `parent.add_child(pickup)` — Pickup is an Area2D, so adding it during
## physics-flush IS the forbidden mutation) AND `_spawn_death_particles`
## (which `room.add_child(burst)`s a CPUParticles2D — defensive defer). All
## three were latent because mobs almost never died (FIST_DAMAGE=1 vs
## HP=50). The diagnostic build surfaced it.
##
## **Why this previously slipped:** `tests/test_combat_visuals.gd` covers
## the death tween being created and `mob_died` firing on frame-1, but no
## test exercised the FULL chain: real Hitbox hits two mobs in the same
## physics frame via the engine signal flow, both `_die` bodies run, and
## both reach `_force_queue_free` without the engine panicking. That's
## what this file does.
##
## **The pair:** on `main` (pre-fix) `test_two_grunts_die_in_same_frame_no_panic`
## fails with at least one mob never reaching `queue_free`; on the fix
## branch all assertions pass.

const PHYS_DELTA: float = 1.0 / 60.0

const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")
const GruntScript: Script = preload("res://scripts/mobs/Grunt.gd")
const MobLootSpawnerScript: Script = preload("res://scripts/loot/MobLootSpawner.gd")
const LootRollerScript: Script = preload("res://scripts/loot/LootRoller.gd")


# ---- Helpers (mirror of test_hitbox_overlapping_at_spawn.gd patterns) -----

func _make_grunt_with_collider(at: Vector2, hp: int = 1) -> Grunt:
	# Bare-instantiated grunt — uses Grunt._apply_layers() defaults so
	# collision_layer = LAYER_ENEMY (bit 4). Authored Grunt.tscn carries a
	# CollisionShape2D child; bare-construct needs one or
	# get_overlapping_bodies returns empty.
	var g: Grunt = GruntScript.new()
	g.hp_max = hp
	g.hp_current = hp
	# Give the grunt a MobDef so the mob_died payload is non-null and the
	# loot-spawner path actually runs (the P0 trigger).
	g.mob_def = ContentFactory.make_mob_def({"hp_base": hp, "loot_table": _build_loot_table()})
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	g.add_child(shape)
	g.global_position = at
	return g


func _build_loot_table() -> LootTableDef:
	# 100% drop a single Pickup so the deferred-add-child code path runs.
	# Without this the spawner returns empty and the bug doesn't reproduce.
	var item: ItemDef = ContentFactory.make_item_def({"id": &"p0_test_drop"})
	var entry: LootEntry = ContentFactory.make_loot_entry(item, 1.0, 0)
	return ContentFactory.make_loot_table({"entries": [entry]})


func _make_hitbox_overlapping(grunts: Array[Grunt], radius: float) -> Hitbox:
	# Hitbox positioned to overlap ALL given grunts. The radius must be
	# wide enough to enclose every grunt's body; we pick one big enough.
	var hb: Hitbox = HitboxScript.new()
	hb.configure(99, Vector2.ZERO, 0.30, Hitbox.TEAM_PLAYER, null)
	# Center the hitbox on the centroid so a single radius covers both.
	var centroid: Vector2 = Vector2.ZERO
	for g: Grunt in grunts:
		centroid += g.global_position
	centroid /= float(grunts.size())
	hb.position = centroid
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	hb.add_child(shape)
	return hb


func _await_physics_settles() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame


# ---- The P0 paired test --------------------------------------------------

func test_two_grunts_die_in_same_frame_no_panic() -> void:
	# Build a small "room" so the loot spawner has a parent_for_pickups
	# target and the death-particle bursts have a tree to land in.
	var room: Node2D = autofree(Node2D.new())
	add_child(room)

	# Two grunts standing close together at HP=1 (lethal on a single hit).
	var g_a: Grunt = _make_grunt_with_collider(Vector2(0, 0), 1)
	var g_b: Grunt = _make_grunt_with_collider(Vector2(20, 0), 1)
	room.add_child(g_a)
	room.add_child(g_b)

	# Wire up the loot spawner exactly like production (Stratum1Room01 etc.):
	# `mob_died.connect(spawner.on_mob_died)`. This is what synchronously
	# adds Area2D Pickups during the flush. With deferred add_child, the
	# panic must NOT fire even when both mobs die in the same frame.
	var roller: LootRoller = LootRollerScript.new()
	roller.seed_rng(99)
	var spawner: MobLootSpawner = MobLootSpawnerScript.new(roller)
	spawner.set_parent_for_pickups(room)
	g_a.mob_died.connect(spawner.on_mob_died)
	g_b.mob_died.connect(spawner.on_mob_died)

	# Spawn ONE hitbox big enough to overlap both grunts. When the deferred
	# initial-overlap check runs, both grunts get hit in the same physics
	# step → both `take_damage(99)` → both `_die` → both emit `mob_died` →
	# both spawner+particles add_child paths run during the flush. Pre-fix
	# this is where Godot panics.
	var hb: Hitbox = _make_hitbox_overlapping([g_a, g_b], 60.0)
	add_child_autofree(hb)

	# Let the deferred initial-overlap check fire, the mob_died emits run,
	# all `call_deferred("add_child", ...)` instances land, and the
	# `_force_queue_free` safety-net timers (DEATH_TWEEN_DURATION + 0.2s)
	# fire on both grunts.
	await _await_physics_settles()

	# Frame-1 invariants: both mobs took the lethal hit and their `_is_dead`
	# latch is set. mob_died signals fired on the same frame.
	assert_true(g_a.is_dead(), "grunt A took the lethal hit and entered _die")
	assert_true(g_b.is_dead(), "grunt B took the lethal hit and entered _die")

	# Death-tween armed on both — PR #136's queue_free decouple should not
	# be aborted by the panic that the deferred fix prevents.
	assert_not_null(g_a._death_tween, "grunt A death tween created")
	assert_not_null(g_b._death_tween, "grunt B death tween created — pre-fix this would be null because the panic aborted before _play_death_tween could run")

	# Wait for the safety-net timer on each mob to fire (DEATH_TWEEN_DURATION
	# + 0.2s = 0.4s). We poll with physics frames + a real tree timer so the
	# SceneTreeTimer the production code armed actually fires.
	var settle_timer: SceneTreeTimer = get_tree().create_timer(0.5)
	await settle_timer.timeout

	# Post-fix: both grunts queue_free'd. is_queued_for_deletion or
	# `is_inside_tree()==false` both signal the queue_free landed.
	# The grunts were autofreed via `add_child_autofree` — wait, here we
	# add to room (not autofree), so we check explicitly.
	assert_true(not is_instance_valid(g_a) or g_a.is_queued_for_deletion(),
		"grunt A reached queue_free via _force_queue_free (PR #136) — pre-fix it would still be alive because the panic aborted the chain")
	assert_true(not is_instance_valid(g_b) or g_b.is_queued_for_deletion(),
		"grunt B reached queue_free")


# ---- Companion: a single mob death with loot still works (sanity) -------

func test_single_grunt_death_with_loot_drop_completes_cleanly() -> void:
	# Sanity check that the deferred add_child fix doesn't break the
	# single-mob death path. Same chain, one mob.
	var room: Node2D = autofree(Node2D.new())
	add_child(room)
	var g: Grunt = _make_grunt_with_collider(Vector2(0, 0), 1)
	room.add_child(g)

	var roller: LootRoller = LootRollerScript.new()
	roller.seed_rng(7)
	var spawner: MobLootSpawner = MobLootSpawnerScript.new(roller)
	spawner.set_parent_for_pickups(room)
	g.mob_died.connect(spawner.on_mob_died)

	var hb: Hitbox = _make_hitbox_overlapping([g], 30.0)
	add_child_autofree(hb)

	await _await_physics_settles()
	assert_true(g.is_dead())
	assert_not_null(g._death_tween)

	# After the deferred Pickup add_child lands, the room has the pickup
	# AND the burst CPUParticles2D as siblings of the dying grunt.
	var has_pickup: bool = false
	var has_particles: bool = false
	for child: Node in room.get_children():
		if child is Pickup:
			has_pickup = true
		if child is CPUParticles2D:
			has_particles = true
	assert_true(has_pickup,
		"deferred Pickup add_child landed under the room (loot drop visible to player)")
	assert_true(has_particles,
		"deferred death-burst add_child landed under the room (death FX visible)")

	# And the safety-net queue_free fires.
	var settle_timer: SceneTreeTimer = get_tree().create_timer(0.5)
	await settle_timer.timeout
	assert_true(not is_instance_valid(g) or g.is_queued_for_deletion(),
		"grunt reached queue_free via _force_queue_free")
