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
## `_attach_assembly()`, called first in the already-deferred
## `_assemble_room_fixtures()` pass — so the mob CollisionShape2D inserts
## land AFTER the physics flush completes, on a clean tick.
##
## **The pair:** these tests drive the EXACT physics-flush-window path —
## loading a real `Stratum1Room05` from inside a real `Area2D.body_entered`
## callback fired by a real `CharacterBody2D` walking the trigger via real
## physics. Pre-fix the mob shapes never register and the "player hitbox
## damages the mob" assertions fail (the mob is un-hittable). Post-fix the
## deferred attach lands the shapes cleanly and all 3 mobs are hittable +
## killable. `test_room05_build_does_not_attach_subtree_synchronously` is
## the structural companion — it pins the load-bearing contract (`_build()`
## leaves `_assembly.root` detached) directly, no physics-flush staging
## required.

const PHYS_DELTA: float = 1.0 / 60.0

const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")

const ROOM05_SCENE_PATH: String = "res://scenes/levels/Stratum1Room05.tscn"

# Layer bits (mirror project.godot).
const LAYER_WORLD: int = 1 << 0
const LAYER_PLAYER: int = 1 << 1


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
	# target and the trigger Area2D's body_entered fires for it.
	var p: CharacterBody2D = CharacterBody2D.new()
	p.collision_layer = LAYER_PLAYER
	p.collision_mask = LAYER_WORLD
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	p.add_child(shape)
	p.global_position = at
	p.add_to_group("player")
	return p


func _make_trigger_area(at: Vector2, size: Vector2) -> Area2D:
	# A plain Area2D trigger that masks the player layer. Plain (not RoomGate)
	# so the test's flush-window staging is isolated from RoomGate's own
	# state machine. monitoring defaults true.
	var area: Area2D = Area2D.new()
	area.collision_mask = LAYER_PLAYER
	area.position = at
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	area.add_child(shape)
	return area


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


## Drives a real CharacterBody2D through a trigger Area2D so `body_entered`
## fires for real, inside `PhysicsServer2D.flush_queries()`. From that
## callback it loads a real `Stratum1Room05` — reproducing the exact
## production call stack (`Main._load_room_at_index` runs `MultiMobRoom._ready`
## from inside the prior room's gate `body_entered` flush). Returns the loaded
## Room 05 node, or null if the body never crossed the trigger.
func _load_room05_from_inside_a_physics_flush(world: Node2D) -> Node:
	var trigger: Area2D = _make_trigger_area(Vector2(0, 0), Vector2(80, 80))
	world.add_child(trigger)

	var loaded: Array[Node] = []
	trigger.body_entered.connect(func(_body: Node) -> void:
		if not loaded.is_empty():
			return
		# SYNCHRONOUS room load — this runs inside the body_entered flush,
		# exactly as Main._load_room_at_index does in production.
		var packed: PackedScene = load(ROOM05_SCENE_PATH) as PackedScene
		var room: Node = packed.instantiate()
		world.add_child(room)  # triggers MultiMobRoom._ready DURING the flush
		loaded.append(room)
	)

	# Real player body well outside the trigger, walking +X straight through.
	var player: CharacterBody2D = _make_player_body(Vector2(-120, 0))
	world.add_child(player)
	# Generous frame budget: 4px/frame at 240px/s, ~30 frames to cross 120px;
	# 120 frames is ample slack for headless physics-frame cadence.
	for _i in range(120):
		player.velocity = Vector2(240, 0)
		player.move_and_slide()
		await get_tree().physics_frame
		if not loaded.is_empty():
			break
	if loaded.is_empty():
		return null
	return loaded[0]


# ---- 1: structural contract — _build() leaves the subtree DETACHED --------

func test_room05_build_does_not_attach_subtree_synchronously() -> void:
	# The load-bearing fix contract, pinned directly: after MultiMobRoom._ready
	# returns, `_build()` has CONSTRUCTED the assembly (so get_spawned_mobs()
	# returns the full roster for Main._wire_room_signals) but has NOT spliced
	# `_assembly.root` into the live tree — that is deferred to _attach_assembly
	# so the mob CollisionShape2D inserts never land mid physics-flush.
	#
	# Pre-fix `_build()` ran `add_child(_assembly.root)` synchronously, so the
	# subtree was in-tree the instant `_ready` returned — this test fails on
	# `main` and passes on the fix branch.
	var packed: PackedScene = load(ROOM05_SCENE_PATH) as PackedScene
	assert_not_null(packed, "Stratum1Room05.tscn loads")
	var room: Node = packed.instantiate()
	add_child_autofree(room)
	# _ready has now run synchronously.

	var mobs: Array[Node] = room.get_spawned_mobs()
	assert_eq(mobs.size(), 3,
		"get_spawned_mobs() returns all 3 Room 05 mobs synchronously after _ready (Main wiring contract)")

	# CORE STRUCTURAL ASSERTION: the assembly subtree must NOT be in the live
	# tree yet — _build() only constructed it; _attach_assembly (deferred) does
	# the splice. Pre-fix this is already in-tree → assertion fails.
	var any_in_tree: bool = false
	for m: Node in mobs:
		if m.is_inside_tree():
			any_in_tree = true
	assert_false(any_in_tree,
		"REGRESSION-86c9u1cx1: _build() leaves the mob subtree DETACHED — the " +
		"add_child(_assembly.root) splice is deferred to _attach_assembly so the " +
		"mob CollisionShape2D inserts never run mid physics-flush")

	# After the deferred fixture pass lands, the mobs ARE spliced in.
	await _await_settle()
	for m: Node in mobs:
		assert_true(m.is_inside_tree(),
			"mob '%s' is spliced into the live tree by the deferred _attach_assembly" % m.name)


# ---- 2: room loaded mid-flush — all 3 mobs end up hittable ----------------

func test_room05_loaded_during_physics_flush_mobs_are_hittable() -> void:
	# Drive the EXACT production call stack: a real body crossing a trigger
	# Area2D fires body_entered inside flush_queries(); from that callback we
	# load Room 05 synchronously — the same window Main._load_room_at_index
	# runs MultiMobRoom._ready in.
	var world: Node2D = autofree(Node2D.new())
	add_child(world)

	var room05: Node = await _load_room05_from_inside_a_physics_flush(world)
	assert_not_null(room05,
		"player crossed the trigger → Room 05 was loaded from inside the body_entered flush")
	if room05 == null:
		return

	# Main._wire_room_signals contract: get_spawned_mobs() returns the full
	# 3-mob roster synchronously, the same tick the room was added.
	var mobs: Array[Node] = room05.get_spawned_mobs()
	assert_eq(mobs.size(), 3,
		"get_spawned_mobs() returns all 3 Room 05 mobs synchronously after _ready")

	# Let the deferred _assemble_room_fixtures → _attach_assembly land.
	await _await_settle()

	for m: Node in mobs:
		assert_true(m.is_inside_tree(),
			"mob '%s' is spliced into the live tree by the deferred _attach_assembly" % m.name)

	# **CORE ASSERTION:** a player hitbox overlapping each mob must actually
	# damage it. If the mob's CollisionShape2D failed to register with the
	# physics server (the bug), the hitbox's overlap sweep finds nothing and
	# HP never moves — the mob is un-hittable, the Room 05 freeze.
	for m: Node in mobs:
		var hp_before: int = m.get_hp()
		var hb: Hitbox = _make_player_hitbox_at(m.global_position, 32.0)
		world.add_child(hb)
		await _await_settle(3)
		assert_lt(m.get_hp(), hp_before,
			"REGRESSION-86c9u1cx1: player hitbox overlapping mob '%s' applies damage " % m.name +
			"(pre-fix the body_set_shape_* flush panic left the mob's collision shape " +
			"unregistered → un-hittable → Room 05 unbeatable)")
		hb.queue_free()


# ---- 3: all 3 Room 05 mobs can be killed + the gate unlocks ---------------

func test_room05_three_mobs_killable_and_gate_unlocks() -> void:
	# End-to-end: load Room 05 mid-flush, then kill all 3 mobs via real player
	# hitboxes and assert the RoomGate reaches UNLOCKED. Pre-fix the mobs are
	# un-hittable so the gate stays LOCKED forever (room unbeatable).
	var world: Node2D = autofree(Node2D.new())
	add_child(world)

	var room05: Node = await _load_room05_from_inside_a_physics_flush(world)
	assert_not_null(room05, "Room 05 loaded from inside the trigger body_entered flush")
	if room05 == null:
		return

	await _await_settle()

	var mobs: Array[Node] = room05.get_spawned_mobs()
	assert_eq(mobs.size(), 3, "Room 05 has its 3-mob roster")

	# The room's own RoomGate must have registered all 3 mobs in the deferred
	# fixture pass (it can only register mobs that exist as nodes — they do).
	var gate: RoomGate = room05.get_room_gate()
	assert_not_null(gate, "Room 05 spawned its RoomGate")
	if gate == null:
		return
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
		var hb: Hitbox = _make_player_hitbox_at(m.global_position, 32.0)
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
