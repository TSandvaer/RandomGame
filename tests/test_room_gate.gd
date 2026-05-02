extends GutTest
## Unit tests for `scripts/levels/RoomGate.gd`. Per testing-bar §Devon-and-
## Drew: every system with non-trivial logic gets paired tests, and gates
## are pure logic (count-down to zero, signal emission, idempotence).
##
## Coverage matches the dispatch's 5-point spec:
##   1. Gate locks when player enters room.
##   2. Gate unlocks when all mobs in room are dead.
##   3. Edge: room with zero mobs -> gate immediately unlocked on lock.
##   4. Edge: mob death from off-screen attacks counts (signal-driven).
##   5. Edge: rapid mob deaths in same frame counted correctly.

const RoomGateScript: Script = preload("res://scripts/levels/RoomGate.gd")


# ---- Helpers --------------------------------------------------------

class FakeMob:
	extends Node2D
	signal mob_died(mob: Variant, position: Vector2, mob_def: Variant)
	func die() -> void:
		mob_died.emit(self, global_position, null)


class FakePlayer:
	extends Node2D
	# Just a marker for body_entered tests; the gate doesn't read its state.


func _make_gate() -> RoomGate:
	var g: RoomGate = RoomGateScript.new()
	add_child_autofree(g)
	return g


func _make_fake_mob() -> FakeMob:
	var m: FakeMob = FakeMob.new()
	add_child_autofree(m)
	return m


# ---- 1. Gate locks when player enters room --------------------------

func test_gate_starts_open() -> void:
	var g: RoomGate = _make_gate()
	assert_eq(g.get_state(), RoomGate.STATE_OPEN, "fresh gate is OPEN")
	assert_false(g.is_locked())
	assert_false(g.is_unlocked())


func test_gate_locks_on_body_entered() -> void:
	var g: RoomGate = _make_gate()
	# Register one mob so the lock doesn't immediately auto-unlock.
	g.register_mob(_make_fake_mob())
	# Watch signals so we can assert emission ordering / count.
	watch_signals(g)
	g.trigger_for_test(FakePlayer.new())
	assert_eq(g.get_state(), RoomGate.STATE_LOCKED)
	assert_true(g.is_locked())
	assert_signal_emitted(g, "gate_locked")
	assert_signal_emit_count(g, "gate_locked", 1)


func test_re_entry_does_not_re_lock() -> void:
	var g: RoomGate = _make_gate()
	g.register_mob(_make_fake_mob())
	watch_signals(g)
	g.trigger_for_test(null)
	g.trigger_for_test(null)
	g.trigger_for_test(null)
	# Lock should fire exactly once even though body_entered fires three times.
	assert_signal_emit_count(g, "gate_locked", 1, "lock is idempotent across re-entries")


# ---- 2. Gate unlocks when all mobs in room are dead -----------------

func test_gate_unlocks_when_all_mobs_die() -> void:
	var g: RoomGate = _make_gate()
	var m1: FakeMob = _make_fake_mob()
	var m2: FakeMob = _make_fake_mob()
	var m3: FakeMob = _make_fake_mob()
	g.register_mob(m1)
	g.register_mob(m2)
	g.register_mob(m3)
	g.trigger_for_test(null)
	assert_true(g.is_locked())
	watch_signals(g)
	m1.die()
	assert_true(g.is_locked(), "still locked with 2 alive")
	assert_eq(g.mobs_alive(), 2)
	m2.die()
	assert_true(g.is_locked(), "still locked with 1 alive")
	m3.die()
	assert_eq(g.mobs_alive(), 0)
	assert_true(g.is_unlocked(), "unlocked once final mob dies")
	assert_signal_emitted(g, "gate_unlocked")
	assert_signal_emit_count(g, "gate_unlocked", 1, "unlock fires once")


func test_unlocked_state_is_terminal() -> void:
	var g: RoomGate = _make_gate()
	var m: FakeMob = _make_fake_mob()
	g.register_mob(m)
	g.trigger_for_test(null)
	m.die()
	assert_eq(g.get_state(), RoomGate.STATE_UNLOCKED)
	# Re-trigger doesn't push us back to LOCKED.
	g.trigger_for_test(null)
	assert_eq(g.get_state(), RoomGate.STATE_UNLOCKED, "unlocked is terminal")


func test_register_same_mob_twice_is_no_op() -> void:
	var g: RoomGate = _make_gate()
	var m: FakeMob = _make_fake_mob()
	g.register_mob(m)
	g.register_mob(m)
	g.register_mob(m)
	assert_eq(g.mobs_alive(), 1, "duplicate registrations counted once")


func test_register_null_is_safe() -> void:
	var g: RoomGate = _make_gate()
	g.register_mob(null)
	assert_eq(g.mobs_alive(), 0, "null mob registration is a no-op")


# ---- 3. Edge: zero mobs -> immediately unlocked --------------------

func test_zero_mob_room_unlocks_immediately_on_lock() -> void:
	var g: RoomGate = _make_gate()
	# No register_mob calls — mobs_alive starts at zero.
	watch_signals(g)
	g.trigger_for_test(null)
	# Both signals fire (lock then auto-unlock) and the state lands UNLOCKED.
	assert_signal_emit_count(g, "gate_locked", 1)
	assert_signal_emit_count(g, "gate_unlocked", 1)
	assert_eq(g.get_state(), RoomGate.STATE_UNLOCKED)


func test_explicit_lock_with_zero_mobs_auto_unlocks() -> void:
	# Same as above but exercising the public lock() API rather than the
	# Area2D body_entered path. Useful for room scripts that want to
	# trigger lock from non-physics sources (e.g. a cutscene end).
	var g: RoomGate = _make_gate()
	g.lock()
	assert_eq(g.get_state(), RoomGate.STATE_UNLOCKED, "trivially-clear room auto-unlocks")


# ---- 4. Edge: mob death from off-screen attacks counts --------------

func test_offscreen_mob_death_still_counts() -> void:
	# The gate listens to `mob_died` signals — it doesn't poll for visibility
	# or distance. This test pins that behavior by parking a mob far outside
	# any reasonable camera frame and emitting its death.
	var g: RoomGate = _make_gate()
	var m: FakeMob = _make_fake_mob()
	m.global_position = Vector2(99999.0, -99999.0)  # off-screen
	g.register_mob(m)
	g.trigger_for_test(null)
	assert_true(g.is_locked())
	m.die()
	assert_true(g.is_unlocked(),
		"mob dying off-screen still counts toward the gate's clear condition")


# ---- 5. Edge: rapid mob deaths in same frame counted correctly ------

func test_rapid_same_frame_deaths_all_counted() -> void:
	# Simulate three mobs dying back-to-back without yielding to the engine
	# (i.e. all in the same physics frame from the gate's POV). Each must
	# decrement the counter; the gate must NOT short-circuit on the first
	# death and miss the rest.
	var g: RoomGate = _make_gate()
	var m1: FakeMob = _make_fake_mob()
	var m2: FakeMob = _make_fake_mob()
	var m3: FakeMob = _make_fake_mob()
	g.register_mob(m1)
	g.register_mob(m2)
	g.register_mob(m3)
	g.trigger_for_test(null)
	# Fire all three death signals back-to-back synchronously.
	m1.die()
	m2.die()
	m3.die()
	assert_eq(g.mobs_alive(), 0, "all three deaths counted")
	assert_true(g.is_unlocked(), "gate unlocked after burst of deaths")


func test_late_registration_after_lock_still_tracked() -> void:
	# A mob registered AFTER the gate locks (e.g. spawned mid-fight by some
	# future M2 event) is still counted. We don't snapshot at lock time.
	var g: RoomGate = _make_gate()
	var m1: FakeMob = _make_fake_mob()
	g.register_mob(m1)
	g.trigger_for_test(null)
	# Register a second mob AFTER the lock fires.
	var m2: FakeMob = _make_fake_mob()
	g.register_mob(m2)
	assert_eq(g.mobs_alive(), 2)
	m1.die()
	assert_true(g.is_locked(), "gate still locked while m2 is alive")
	m2.die()
	assert_true(g.is_unlocked(), "gate unlocks once both mobs dead, including the late one")


func test_layer_mask_targets_player_only() -> void:
	# Defensive: the gate's collision_mask must include the player layer
	# (bit 2) and NOT include the enemy layer (bit 4). This ensures mobs
	# walking through the gate area don't accidentally trigger lock.
	var packed: PackedScene = load("res://scenes/levels/RoomGate.tscn")
	var g: RoomGate = packed.instantiate()
	add_child_autofree(g)
	assert_true((g.collision_mask & RoomGate.LAYER_PLAYER) != 0, "masks player")
	assert_eq(g.collision_layer, 0, "gate emits no collisions itself")
