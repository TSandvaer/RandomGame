extends GutTest
## Regression test for ticket 86c9u1cx1 — Room 05 3-concurrent-chaser
## mob-freeze (the AC4 Room 05 hard wall).
##
## **Symptom (Devon, release-build `embergrave-html5-967f2c4`):** ~6-7s
## after entering Stratum-1 Room 05 (2 grunts + 1 charger — the FIRST
## 3-mob room), all 3 mobs become permanently un-hittable. They stay at
## full HP, the player's swings produce zero `Hitbox.hit` / `take_damage`
## traces against them, no mob ever dies, and the RoomGate never unlocks —
## Room 05 is unbeatable. The player stays alive and swinging.
##
## **Root cause (Drew investigation, ticket 86c9u1cx1):** confirmed against
## a release build of `e571ce0` via a Playwright repro that drove rooms
## 01..05 — the HTML5 console showed a burst of:
##
##     USER ERROR: Can't change this state while flushing queries.
##       at: body_set_shape_disabled (godot_physics_server_2d.cpp:654)
##       at: body_set_shape_as_one_way_collision (godot_physics_server_2d.cpp:663)
##
## fired the instant Room 05 loaded. `MultiMobRoom._build()` ran
## `add_child(_assembly.root)` SYNCHRONOUSLY from `_ready`, and `_ready`
## runs inside the prior room's `RoomGate.body_entered` physics-flush
## window (gate_traversed → room_cleared → Main._on_room_cleared →
## _load_room_at_index → _world.add_child(room) → MultiMobRoom._ready).
## Splicing the assembly subtree into the live tree mid-`flush_queries()`
## inserts every mob CharacterBody2D's `CollisionShape2D` into the physics
## server — and `body_set_shape_disabled` /
## `body_set_shape_as_one_way_collision` PANIC during a query flush. The
## C++ early-returns, leaving the mob's collision shape NOT registered with
## the server. The mob renders + AI-ticks fine, but the player's swing
## Hitbox Area2D's `get_overlapping_bodies` / `body_entered` never sees the
## mob's shape → the mob is un-hittable → never dies → gate never unlocks.
##
## PR #183 deferred the *RoomGate* Area2D fixture pass out of the flush,
## but explicitly LEFT `_build()` synchronous on the (wrong) rationale that
## "CharacterBody2D mobs = no Area2D monitoring mutation, safe." The
## physics-flush rule applies to `CollisionShape2D`-on-`PhysicsBody2D` adds
## too — not just Area2D monitoring.
##
## **The fix:** `MultiMobRoom._build()` now only CONSTRUCTS the
## `LevelAssembler.AssemblyResult` (geometry + mobs parented under the
## DETACHED `_assembly.root` — zero physics-server calls). The actual
## `add_child(_assembly.root)` tree-insertion is split into
## `_attach_assembly()`, called from the already-deferred
## `_assemble_room_fixtures()` pass — so the mob CollisionShape2D inserts
## land AFTER the physics flush completes, on a clean tick.
##
## **The pair:** these tests drive the EXACT physics-flush-window path —
## loading a real `Stratum1Room05` from inside a real `Area2D.body_entered`
## callback fired by a real player CharacterBody2D walking the trigger.
## Pre-fix the mob shapes never register and the "player hitbox damages the
## mob" assertions fail (the mob is un-hittable). Post-fix the deferred
## attach lands the shapes cleanly and all 3 mobs are hittable + killable.

const PHYS_DELTA: float = 1.0 / 60.0

const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")
const RoomGateScript: Script = preload("res://scripts/levels/RoomGate.gd")

const ROOM05_SCENE_PATH: String = "res://scenes/levels/Stratum1Room05.tscn"


# ---- Helpers ---------------------------------------------------------------

func _await_settle(frames: int = 8) -> void:
	# Drain enough physics + idle frames that:
	#   - MultiMobRoom._ready's call_deferred("_assemble_room_fixtures") lands
	#   - _attach_assembly() splices the mob subtree into the tree
	#   - the mobs' CollisionShape2Ds register with the physics server
	#   - a freshly-added Hitbox's deferred monitoring activation + initial
	#     overlap sweep runs
	for _i in range(frames):
		await get_tree().physics_frame
		await get_tree().process_frame


func _make_player_body(at: Vector2) -> CharacterBody2D:
	# A minimal CharacterBody2D on the player layer (bit 2) with a collider,
	# registered in the "player" group so the room's mobs resolve it as their
	# target and the RoomGate's body_entered filter accepts it.
	var p: CharacterBody2D = CharacterBody2D.new()
	p.collision_layer = 1 << 1   # player bit
	p.collision_mask = 1 << 0    # world
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	p.add_child(shape)
	p.global_position = at
	p.add_to_group("player")
	return p


func _make_player_hitbox_at(center: Vector2, radius: float) -> Hitbox:
	# A TEAM_PLAYER hitbox (layer = player_hitbox bit 3, mask = enemy bit 4)
	# big enough to overlap a mob. If the mob's CollisionShape2D registered
	# with the physics server, the hitbox's deferred initial-overlap sweep
	# finds it and applies damage; if the shape failed to register (the bug),
	# the sweep finds nothing and the mob takes no damage.
	var hb: Hitbox = HitboxScript.new()
	hb.configure(9999, Vector2.ZERO, 0.30, Hitbox.TEAM_PLAYER, null)
	hb.position = center
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	hb.add_child(shape)
	return hb


## Loads a Stratum1Room05 instance — INTENTIONALLY invoked from inside a
## RoomGate.body_entered callback so MultiMobRoom._ready runs inside the
## physics-query-flush window, exactly as Main._load_room_at_index does in
## production (the prior room's gate_traversed → room_cleared → load chain).
func _load_room05_during_flush(world: Node) -> Node:
	var packed: PackedScene = load(ROOM05_SCENE_PATH) as PackedScene
	assert_not_null(packed, "Stratum1Room05.tscn loads")
	var room: Node = packed.instantiate()
	world.add_child(room)  # triggers MultiMobRoom._ready DURING the flush
	return room


# ---- 1: room loaded mid-flush — all 3 mobs end up hittable + killable ------

func test_room05_loaded_during_physics_flush_mobs_are_hittable() -> void:
	# Build a "world" + a prior-room RoomGate. Walking a real player
	# CharacterBody2D through the gate fires body_entered DURING the physics
	# flush; from that callback we load Room 05 — reproducing the exact
	# production call stack that panicked pre-fix.
	var world: Node2D = autofree(Node2D.new())
	add_child(world)

	var prior_gate: RoomGate = RoomGateScript.new()
	prior_gate.trigger_size = Vector2(64.0, 64.0)
	prior_gate.position = Vector2(0, 0)
	world.add_child(prior_gate)

	var room05_holder: Array[Node] = []
	# When the player crosses the prior gate, load Room 05 — synchronously,
	# inside the body_entered flush. This is the physics-flush window.
	prior_gate.body_entered.connect(func(_body: Node) -> void:
		if room05_holder.is_empty():
			room05_holder.append(_load_room05_during_flush(world))
	)

	# Real player body, placed just outside the gate, walking +X into it.
	var player: CharacterBody2D = _make_player_body(Vector2(-60, 0))
	world.add_child(player)

	# Drive real physics so body_entered fires for real (inside flush_queries).
	for _i in range(30):
		player.velocity = Vector2(240, 0)
		player.move_and_slide()
		await get_tree().physics_frame
		if not room05_holder.is_empty():
			break
	assert_false(room05_holder.is_empty(),
		"player crossed the prior gate → Room 05 was loaded from inside the body_entered flush")
	var room05: Node = room05_holder[0]

	# The Main._wire_room_signals contract: get_spawned_mobs() must return the
	# full 3-mob roster synchronously, the same tick the room was added — even
	# though the assembly subtree is not yet spliced into the live tree.
	var mobs: Array[Node] = room05.get_spawned_mobs()
	assert_eq(mobs.size(), 3,
		"get_spawned_mobs() returns all 3 Room 05 mobs synchronously after _ready (Main wiring contract)")

	# Let the deferred _assemble_room_fixtures → _attach_assembly land.
	await _await_settle()

	# Post-fix: every mob is now inside the live tree with a registered
	# CollisionShape2D. Pre-fix the body_set_shape_* panic left the shape
	# unregistered.
	for m: Node in mobs:
		assert_true(m.is_inside_tree(),
			"mob '%s' is spliced into the live tree by the deferred _attach_assembly" % m.name)

	# **CORE ASSERTION:** a player hitbox overlapping each mob must actually
	# damage it. If the mob's CollisionShape2D failed to register with the
	# physics server (the bug), the hitbox's overlap sweep finds nothing and
	# HP never moves — the mob is un-hittable, the Room 05 freeze.
	for m: Node in mobs:
		var hp_before: int = m.get_hp()
		var hb: Hitbox = _make_player_hitbox_at(m.global_position, 28.0)
		world.add_child(hb)
		await _await_settle(3)
		assert_lt(m.get_hp(), hp_before,
			"REGRESSION-86c9u1cx1: player hitbox overlapping mob '%s' applies damage " % m.name +
			"(pre-fix the body_set_shape_* flush panic left the mob's collision shape " +
			"unregistered → un-hittable → Room 05 unbeatable)")
		hb.queue_free()


# ---- 2: all 3 Room 05 mobs can be killed + the gate unlocks ----------------

func test_room05_three_mobs_killable_and_gate_unlocks() -> void:
	# End-to-end: load Room 05 mid-flush, then kill all 3 mobs via real
	# player hitboxes and assert the RoomGate reaches UNLOCKED. Pre-fix the
	# mobs are un-hittable so the gate stays LOCKED forever (room unbeatable).
	var world: Node2D = autofree(Node2D.new())
	add_child(world)

	var prior_gate: RoomGate = RoomGateScript.new()
	prior_gate.trigger_size = Vector2(64.0, 64.0)
	prior_gate.position = Vector2(0, 0)
	world.add_child(prior_gate)

	var room05_holder: Array[Node] = []
	prior_gate.body_entered.connect(func(_body: Node) -> void:
		if room05_holder.is_empty():
			room05_holder.append(_load_room05_during_flush(world))
	)

	var player: CharacterBody2D = _make_player_body(Vector2(-60, 0))
	world.add_child(player)
	for _i in range(30):
		player.velocity = Vector2(240, 0)
		player.move_and_slide()
		await get_tree().physics_frame
		if not room05_holder.is_empty():
			break
	assert_false(room05_holder.is_empty(), "Room 05 loaded from inside the gate body_entered flush")
	var room05: Node = room05_holder[0]

	await _await_settle()

	var mobs: Array[Node] = room05.get_spawned_mobs()
	assert_eq(mobs.size(), 3, "Room 05 has its 3-mob roster")

	# The room's own RoomGate must have registered all 3 mobs in the deferred
	# fixture pass (it can only register mobs that exist as nodes — they do,
	# parented under the assembly root).
	var gate: RoomGate = room05.get_room_gate()
	assert_not_null(gate, "Room 05 spawned its RoomGate")
	assert_eq(gate.mobs_alive(), 3,
		"all 3 Room 05 mobs registered with the gate after the deferred fixture pass")

	# Lock the gate (simulate the player having walked into the room).
	gate.test_skip_death_wait = true
	gate.lock()
	assert_true(gate.is_locked(), "gate locked with 3 mobs alive")

	# Kill each mob with an overlapping player hitbox. Each kill must land —
	# pre-fix the un-hittable mobs would keep HP and the loop would never
	# clear the room.
	for m: Node in mobs:
		var hb: Hitbox = _make_player_hitbox_at(m.global_position, 28.0)
		world.add_child(hb)
		await _await_settle(3)
		assert_true(m.is_dead(),
			"REGRESSION-86c9u1cx1: Room 05 mob '%s' is killable by a real player hitbox" % m.name)
		hb.queue_free()

	# With all 3 mobs dead, the gate must reach UNLOCKED — Room 05 clears.
	await _await_settle()
	assert_eq(gate.mobs_alive(), 0, "gate counter reached 0 after all 3 mobs died")
	assert_true(gate.is_unlocked(),
		"REGRESSION-86c9u1cx1: RoomGate UNLOCKS once all 3 Room 05 mobs die — " +
		"pre-fix the un-hittable mobs left the gate LOCKED forever (room unbeatable)")
