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
## the instant Room 05 loaded. `RoomGate.gate_traversed` is emitted from
## `RoomGate._on_body_entered` — a `body_entered` physics callback that runs
## synchronously inside `PhysicsServer2D.flush_queries()`. `MultiMobRoom`
## connected `_on_room_gate_traversed` with a SYNCHRONOUS connection, so the
## whole next-room load chain — `_on_room_gate_traversed → room_cleared →
## Main._on_room_cleared → _load_room_at_index → _world.add_child(next_room)
## + next_room.add_child(_player)` — ran INSIDE that flush window. Splicing
## the next room's mob CharacterBody2D + CollisionShape2D subtrees into the
## physics server mid-`flush_queries()` panics (`body_set_shape_disabled` /
## `body_set_shape_as_one_way_collision`); the C++ early-returns, leaving the
## mobs' collision shapes UNREGISTERED with the server. The mobs render +
## AI-tick fine, but the player's swing `Hitbox` Area2D never detects them
## (`get_overlapping_bodies` / `body_entered` see no shape) → un-hittable →
## never die → gate never unlocks → Room 05 unbeatable.
##
## **The fix:** connect `RoomGate.gate_traversed` →
## `MultiMobRoom._on_room_gate_traversed` with `CONNECT_DEFERRED`. The entire
## next-room load chain then runs at end-of-frame, OUTSIDE `flush_queries()`,
## so every body/shape splice in the load lands on a clean tick. Mirrors PR
## #173's `mob_died` `CONNECT_DEFERRED` on `RoomGate.register_mob` — same
## physics-flush race class.
##
## **The pair:**
##   - `test_*_gate_traversed_connection_is_deferred` pins the fix structurally
##     (the connection flag) for every gated Stratum-1 room.
##   - `test_room_cleared_does_not_fire_synchronously_inside_body_entered_flush`
##     pins it behaviourally: emitting `gate_traversed` from inside a real
##     `Area2D.body_entered` flush must NOT run `room_cleared` synchronously
##     in that flush — it must land deferred, on the next frame. Pre-fix
##     `room_cleared` (and the whole room-load chain) fired synchronously
##     inside the flush; post-fix it is deferred out.
##   - `test_room05_three_mobs_hittable_and_gate_unlocks` is the end-to-end
##     smoke: all 3 Room 05 mobs are hittable, killable, and the gate unlocks.

const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")

const ROOM05_SCENE_PATH: String = "res://scenes/levels/Stratum1Room05.tscn"

# Every gated Stratum-1 room scene driven by MultiMobRoom.
const GATED_ROOM_SCENES: Array[String] = [
	"res://scenes/levels/Stratum1Room02.tscn",
	"res://scenes/levels/Stratum1Room03.tscn",
	"res://scenes/levels/Stratum1Room04.tscn",
	"res://scenes/levels/Stratum1Room05.tscn",
	"res://scenes/levels/Stratum1Room06.tscn",
	"res://scenes/levels/Stratum1Room07.tscn",
	"res://scenes/levels/Stratum1Room08.tscn",
]


# ---- Helpers ---------------------------------------------------------------

func _await_settle(frames: int = 8) -> void:
	# Drain physics + idle frames so MultiMobRoom._ready's deferred
	# _assemble_room_fixtures lands, the RoomGate registers its mobs, and a
	# freshly-added Hitbox's deferred monitoring activation + overlap sweep run.
	for _i in range(frames):
		await get_tree().physics_frame
		await get_tree().process_frame


## Loads a gated MultiMobRoom scene, adds it to the tree, and drains a frame
## so the deferred fixture pass (RoomGate spawn + mob registration) lands.
func _load_gated_room(scene_path: String) -> MultiMobRoom:
	var packed: PackedScene = load(scene_path) as PackedScene
	assert_not_null(packed, "scene loads: %s" % scene_path)
	var room: MultiMobRoom = packed.instantiate() as MultiMobRoom
	add_child_autofree(room)
	await _await_settle()
	return room


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


## True iff `obj`'s `signal_name` has a connection to a Callable on `target`
## whose flags include CONNECT_DEFERRED.
func _connection_is_deferred(obj: Object, signal_name: StringName, target: Object) -> bool:
	for conn: Dictionary in obj.get_signal_connection_list(signal_name):
		var cb: Callable = conn["callable"]
		if cb.get_object() == target:
			return (int(conn["flags"]) & CONNECT_DEFERRED) != 0
	return false


# ---- 1: structural — gate_traversed → room is connected CONNECT_DEFERRED ---

func test_room05_gate_traversed_connection_is_deferred() -> void:
	# The load-bearing fix, pinned directly: MultiMobRoom must connect the
	# RoomGate's `gate_traversed` signal to its own `_on_room_gate_traversed`
	# handler with CONNECT_DEFERRED — so the next-room load chain it kicks off
	# escapes the physics-flush window `gate_traversed` is emitted inside.
	#
	# Pre-fix the connection was synchronous → this test fails on `main`.
	var room: MultiMobRoom = await _load_gated_room(ROOM05_SCENE_PATH)
	var gate: RoomGate = room.get_room_gate()
	assert_not_null(gate, "Room 05 spawned its RoomGate")
	if gate == null:
		return
	assert_true(
		_connection_is_deferred(gate, "gate_traversed", room),
		"REGRESSION-86c9u1cx1: RoomGate.gate_traversed → MultiMobRoom." +
		"_on_room_gate_traversed must be a CONNECT_DEFERRED connection so the " +
		"next-room load chain runs OUTSIDE the body_entered physics-flush window")


func test_every_gated_room_defers_gate_traversed() -> void:
	# Generalise across every MultiMobRoom-driven gated room (02..08): all of
	# them load the *next* room from the same flush-rooted `gate_traversed`
	# chain, so every one must defer it. A room that connects synchronously
	# would re-introduce the freeze for whatever room loads after it.
	for scene_path: String in GATED_ROOM_SCENES:
		var room: MultiMobRoom = await _load_gated_room(scene_path)
		var gate: RoomGate = room.get_room_gate()
		assert_not_null(gate, "%s spawned a RoomGate" % scene_path)
		if gate == null:
			continue
		assert_true(
			_connection_is_deferred(gate, "gate_traversed", room),
			"%s: gate_traversed → _on_room_gate_traversed must be CONNECT_DEFERRED" % scene_path)


# ---- 2: behavioural — room_cleared lands DEFERRED, not synchronously ------

func test_room_cleared_fires_deferred_after_gate_traversed() -> void:
	# Behavioural consequence of the CONNECT_DEFERRED fix: when the RoomGate
	# emits `gate_traversed`, `MultiMobRoom._on_room_gate_traversed` (and the
	# `room_cleared` it emits) must NOT run synchronously in the emit call —
	# it must land on the next frame's deferred-call flush.
	#
	# This is the load-bearing behaviour: in production `gate_traversed` is
	# emitted from inside `PhysicsServer2D.flush_queries()`; deferring the
	# handler is what moves the entire downstream next-room load
	# (Main._on_room_cleared → _load_room_at_index → add_child of the next
	# room + player) OUT of the flush window, so the body/shape splices land
	# on a clean tick (ticket 86c9u1cx1).
	#
	# Pre-fix the connection was synchronous → `room_cleared` fired DURING the
	# `gate_traversed.emit()` call → this test fails on `main`.
	var room: MultiMobRoom = await _load_gated_room(ROOM05_SCENE_PATH)
	var gate: RoomGate = room.get_room_gate()
	assert_not_null(gate, "Room 05 spawned its RoomGate")
	if gate == null:
		return

	var cleared_count: Array[int] = [0]
	room.room_cleared.connect(func() -> void:
		cleared_count[0] += 1
	)

	# Drive the gate to UNLOCKED the real way (lock → kill all 3 mobs), so
	# `traverse_for_test()` can legitimately emit `gate_traversed`.
	gate.test_skip_death_wait = true
	gate.lock()
	for m: Node in room.get_spawned_mobs():
		if m.has_method("take_damage"):
			m.take_damage(999999, Vector2.ZERO, null)
	await _await_settle()  # let the deferred mob_died decrements + unlock land
	assert_true(gate.is_unlocked(), "gate reached UNLOCKED after all 3 mobs died")
	assert_eq(cleared_count[0], 0, "room_cleared has not fired yet — gate only just unlocked")

	# Emit gate_traversed. With CONNECT_DEFERRED, _on_room_gate_traversed does
	# NOT run inside this call — so room_cleared must still be at 0 immediately
	# after the emit returns.
	gate.traverse_for_test()
	assert_eq(cleared_count[0], 0,
		"REGRESSION-86c9u1cx1: room_cleared must NOT fire synchronously inside " +
		"the gate_traversed emit — the gate_traversed → _on_room_gate_traversed " +
		"connection is CONNECT_DEFERRED so the next-room load escapes the " +
		"body_entered physics-flush window")

	# After one frame's deferred-call flush, the handler runs and room_cleared fires.
	await _await_settle(2)
	assert_eq(cleared_count[0], 1,
		"room_cleared fires exactly once on the deferred-call flush after gate_traversed")


# ---- 3: end-to-end — all 3 Room 05 mobs hittable + killable + gate unlocks -

func test_room05_three_mobs_hittable_and_gate_unlocks() -> void:
	# End-to-end smoke for the Room 05 roster: load the real Stratum1Room05,
	# confirm its RoomGate registered all 3 mobs, then kill each mob with a
	# real overlapping player Hitbox and assert the gate UNLOCKS. This is the
	# "Room 05 is actually beatable" guarantee — the symptom the ticket
	# reported was that it was not.
	var room: MultiMobRoom = await _load_gated_room(ROOM05_SCENE_PATH)

	var mobs: Array[Node] = room.get_spawned_mobs()
	assert_eq(mobs.size(), 3, "Room 05 spawned its 3-mob roster (2 grunts + 1 charger)")

	var gate: RoomGate = room.get_room_gate()
	assert_not_null(gate, "Room 05 spawned its RoomGate")
	if gate == null:
		return
	assert_eq(gate.mobs_alive(), 3,
		"all 3 Room 05 mobs registered with the gate after the deferred fixture pass")

	gate.test_skip_death_wait = true
	gate.lock()
	assert_true(gate.is_locked(), "gate locked with 3 mobs alive")

	# Kill each mob with an overlapping player hitbox — each kill must land.
	for m: Node in mobs:
		var hp_before: int = m.get_hp()
		var hb: Hitbox = _make_player_hitbox_at(m.global_position, 32.0)
		room.add_child(hb)
		await _await_settle(3)
		assert_lt(m.get_hp(), hp_before,
			"REGRESSION-86c9u1cx1: player hitbox overlapping Room 05 mob '%s' applies damage" % m.name)
		assert_true(m.is_dead(),
			"REGRESSION-86c9u1cx1: Room 05 mob '%s' is killable by a real player hitbox" % m.name)
		hb.queue_free()

	# With all 3 mobs dead, the gate must reach UNLOCKED — Room 05 clears.
	await _await_settle()
	assert_eq(gate.mobs_alive(), 0, "gate counter reached 0 after all 3 mobs died")
	assert_true(gate.is_unlocked(),
		"REGRESSION-86c9u1cx1: RoomGate UNLOCKS once all 3 Room 05 mobs die — " +
		"Room 05 is beatable")
