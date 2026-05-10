extends GutTest
## Regression test for ticket 86c9qcf9z — RoomGate._mobs_alive desync vs
## Grunt._die signal (blocks AC4 final flip).
##
## **Symptom (Tess's PR #172 AC4 spec, post-#171 origin/main):** in Room02
## (2 grunts), `clearRoomMobs` counts 2 `Grunt._die` traces, but the gate's
## `_mobs_alive` counter only decrements to 1, not 0. The gate stays in
## OPEN state with mobs_alive=1 instead of transitioning LOCKED → UNLOCKED.
## This blocks the AC4 final test.fail() → test() flip.
##
## **Pair-test contract:** drive the actual MultiMobRoom path with 2 real
## Grunts wired through register_mob, kill both, and assert:
##   - both register_mob calls land (mobs_alive hits 2)
##   - both `mob_died` emits decrement the counter (mobs_alive reaches 0)
##   - gate transitions LOCKED → UNLOCKED + emits `gate_unlocked`
##
## On origin/main pre-fix this test fails with `mobs_alive` stuck at 1
## (matching Tess's empirical AC4 trace). On the fix branch it passes.
##
## **Why integration not unit:** existing `tests/test_room_gate.gd` uses
## `FakeMob` (a Node2D with the mob_died signal). It validates the gate's
## counter logic in isolation, but does NOT exercise the actual signal-
## emission path through Grunt._die or the MultiMobRoom registration
## ordering. The desync surfaced ONLY when real Grunt nodes were spawned
## via LevelAssembler and registered via MultiMobRoom._register_mobs_with_gate.

const PHYS_DELTA: float = 1.0 / 60.0

const RoomGateScript: Script = preload("res://scripts/levels/RoomGate.gd")
const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")
const GruntScript: Script = preload("res://scripts/mobs/Grunt.gd")


# ---- Helpers ----------------------------------------------------------

func _make_grunt(at: Vector2, hp: int = 1) -> Grunt:
	# Same recipe as test_simultaneous_mob_deaths_no_physics_panic.gd —
	# bare-instanced grunt with a CollisionShape2D so get_overlapping_bodies
	# returns it from the test hitbox.
	var g: Grunt = GruntScript.new()
	g.hp_max = hp
	g.hp_current = hp
	g.mob_def = ContentFactory.make_mob_def({"hp_base": hp})
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	g.add_child(shape)
	g.global_position = at
	return g


func _make_gate() -> RoomGate:
	var g: RoomGate = RoomGateScript.new()
	# test_skip_death_wait flag is flipped by trigger_for_test; here we
	# use the public lock() path (also auto-unlocks on mobs_alive==0 OR
	# triggers the death wait). Since we want the synchronous unlock
	# behavior the existing tests rely on, we set test_skip_death_wait
	# directly.
	g.test_skip_death_wait = true
	return g


func _make_hitbox_overlapping(grunts: Array[Grunt], radius: float) -> Hitbox:
	var hb: Hitbox = HitboxScript.new()
	hb.configure(99, Vector2.ZERO, 0.30, Hitbox.TEAM_PLAYER, null)
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
	# Drain physics + process frames so:
	#   - Hitbox._activate_and_check_initial_overlaps's deferred call lands
	#   - Both grunts' take_damage → _die → mob_died.emit chain runs
	#   - CONNECT_DEFERRED dispatch from RoomGate.register_mob (ticket
	#     86c9qcf9z) runs the gate's _on_mob_died at end-of-frame
	#   - The death-tween + safety-net timer don't matter for the gate's
	#     mobs_alive accounting (it only depends on mob_died emit timing)
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame


# ---- The P0 paired test ----------------------------------------------

func test_two_real_grunts_both_decrement_gate_counter() -> void:
	# Build a "room" (Node2D parent) so mobs + gate share a tree.
	var room: Node2D = autofree(Node2D.new())
	add_child(room)

	# Two real Grunts at HP=1 (lethal on a single hit). Mirrors the Room02
	# layout (2 grunts) without going through the full MultiMobRoom build,
	# so the test isolates the register_mob → mob_died decrement chain.
	var g_a: Grunt = _make_grunt(Vector2(0, 0), 1)
	var g_b: Grunt = _make_grunt(Vector2(20, 0), 1)
	room.add_child(g_a)
	room.add_child(g_b)

	# Gate registered with both grunts — same call shape that
	# MultiMobRoom._register_mobs_with_gate uses (sequential register_mob
	# calls iterating the live mob list).
	var gate: RoomGate = _make_gate()
	room.add_child(gate)
	gate.register_mob(g_a)
	gate.register_mob(g_b)
	assert_eq(gate.mobs_alive(), 2, "both grunts registered → mobs_alive starts at 2")

	# Lock the gate (simulates player walking into the trigger).
	gate.lock()
	assert_true(gate.is_locked(), "gate locked with both mobs alive")

	# Watch signals from this point so we can assert ordering / count.
	watch_signals(gate)

	# Single hitbox overlapping BOTH grunts → both take_damage(99) → both
	# _die → both emit mob_died synchronously. This is the production death
	# pathway: Hitbox.body_entered → take_damage → _die → mob_died.emit →
	# RoomGate._on_mob_died → decrement.
	var hb: Hitbox = _make_hitbox_overlapping([g_a, g_b], 60.0)
	add_child_autofree(hb)

	await _await_physics_settles()

	# Both grunts should have entered _die and emitted mob_died.
	assert_true(g_a.is_dead(), "grunt A took the lethal hit and entered _die")
	assert_true(g_b.is_dead(), "grunt B took the lethal hit and entered _die")

	# **CORE ASSERTION (the regression fix gate):** the gate's _mobs_alive
	# counter must reach 0 after both grunts die. Pre-fix this is stuck at 1
	# (Tess's AC4 trace evidence on origin/main 1c2438e/c72e758).
	assert_eq(gate.mobs_alive(), 0,
		"gate._mobs_alive must reach 0 after both grunts emit mob_died — " +
		"this is the desync bug from ticket 86c9qcf9z")

	# Gate must transition LOCKED → UNLOCKED + emit gate_unlocked exactly once.
	assert_true(gate.is_unlocked(), "gate transitioned to UNLOCKED")
	assert_signal_emitted(gate, "gate_unlocked")
	assert_signal_emit_count(gate, "gate_unlocked", 1, "gate_unlocked emits exactly once")


# ---- Companion: 3 grunts (Room05 / Room08 grunt count) ---------------

func test_three_real_grunts_all_decrement_gate_counter() -> void:
	# Generalises the regression: 3 grunts dying simultaneously, all 3
	# mob_died emissions must reach the gate. Pre-fix at least one is lost.
	var room: Node2D = autofree(Node2D.new())
	add_child(room)

	var g_a: Grunt = _make_grunt(Vector2(0, 0), 1)
	var g_b: Grunt = _make_grunt(Vector2(20, 0), 1)
	var g_c: Grunt = _make_grunt(Vector2(-20, 0), 1)
	room.add_child(g_a)
	room.add_child(g_b)
	room.add_child(g_c)

	var gate: RoomGate = _make_gate()
	room.add_child(gate)
	gate.register_mob(g_a)
	gate.register_mob(g_b)
	gate.register_mob(g_c)
	assert_eq(gate.mobs_alive(), 3, "3 grunts registered")
	gate.lock()
	watch_signals(gate)

	var hb: Hitbox = _make_hitbox_overlapping([g_a, g_b, g_c], 80.0)
	add_child_autofree(hb)
	await _await_physics_settles()

	assert_true(g_a.is_dead() and g_b.is_dead() and g_c.is_dead(),
		"all 3 grunts entered _die")
	assert_eq(gate.mobs_alive(), 0,
		"gate._mobs_alive reaches 0 after all 3 grunts emit mob_died")
	assert_true(gate.is_unlocked())
	assert_signal_emit_count(gate, "gate_unlocked", 1)


# ---- Companion: register order vs death order doesn't matter ---------

func test_grunt_dies_after_gate_locks_late_register_works() -> void:
	# Late-registration scenario: grunt B is registered AFTER gate.lock().
	# Both must still decrement; this is the same edge already covered by
	# tests/test_room_gate.gd::test_late_registration_after_lock_still_tracked
	# but exercised against a REAL Grunt (not FakeMob).
	var room: Node2D = autofree(Node2D.new())
	add_child(room)

	var g_a: Grunt = _make_grunt(Vector2(0, 0), 1)
	var g_b: Grunt = _make_grunt(Vector2(20, 0), 1)
	room.add_child(g_a)
	room.add_child(g_b)

	var gate: RoomGate = _make_gate()
	room.add_child(gate)
	gate.register_mob(g_a)
	gate.lock()
	# Late-register g_b AFTER the lock fires.
	gate.register_mob(g_b)
	assert_eq(gate.mobs_alive(), 2, "late-register added g_b to count")

	watch_signals(gate)
	var hb: Hitbox = _make_hitbox_overlapping([g_a, g_b], 60.0)
	add_child_autofree(hb)
	await _await_physics_settles()

	assert_eq(gate.mobs_alive(), 0, "both decrements landed even with late-register")
	assert_true(gate.is_unlocked())
	assert_signal_emit_count(gate, "gate_unlocked", 1)
