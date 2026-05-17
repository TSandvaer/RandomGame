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
##
## **Ticket 86c9qcf9z (CONNECT_DEFERRED migration):** the gate now connects
## the mob.mob_died signal with `CONNECT_DEFERRED` so the decrement runs at
## end-of-frame rather than synchronously inside the mob's _die chain. Tests
## that emit `m.die()` synchronously now await one frame via `_await_frame`
## before asserting `mobs_alive()` / `is_unlocked()`. The state-machine
## semantics are unchanged; only the dispatch timing shifts by one frame.
## See RoomGate.register_mob docstring for the full rationale.

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


# Helper: drain one process-frame so CONNECT_DEFERRED handlers run.
# Ticket 86c9qcf9z: register_mob now connects with CONNECT_DEFERRED, so
# the gate's _on_mob_died decrement runs at end-of-frame rather than
# synchronously inside the emit call. Tests that fire m.die() and then
# inspect mobs_alive() / is_unlocked() must await a frame between the two.
func _await_frame() -> void:
	await get_tree().process_frame


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
	# CONNECT_DEFERRED dispatch (ticket 86c9qcf9z): drain one frame for the
	# gate's _on_mob_died decrement to land.
	await _await_frame()
	assert_true(g.is_locked(), "still locked with 2 alive")
	assert_eq(g.mobs_alive(), 2)
	m2.die()
	await _await_frame()
	assert_true(g.is_locked(), "still locked with 1 alive")
	m3.die()
	await _await_frame()
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
	await _await_frame()
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
	await _await_frame()
	assert_true(g.is_unlocked(),
		"mob dying off-screen still counts toward the gate's clear condition")


# ---- 5. Edge: rapid mob deaths in same frame counted correctly ------

func test_rapid_same_frame_deaths_all_counted() -> void:
	# Simulate three mobs dying back-to-back without yielding to the engine
	# (i.e. all in the same physics frame from the gate's POV). Each must
	# decrement the counter; the gate must NOT short-circuit on the first
	# death and miss the rest.
	#
	# Ticket 86c9qcf9z: this is the regression test that pins the desync
	# fix. Pre-CONNECT_DEFERRED, the gate's _on_mob_died ran inside each
	# m.die() emit's synchronous handler chain. The real-game equivalent
	# of this scenario (Tess's PR #172 AC4 spec) saw only ONE of the three
	# decrements land. With CONNECT_DEFERRED, all three queue up and drain
	# in order at end-of-frame.
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
	# Drain ONE frame — CONNECT_DEFERRED queues all three decrements; they
	# run in connect-order at end-of-frame. The single frame drain is
	# sufficient because deferred-call dispatch is FIFO and all three were
	# queued in the same frame.
	await _await_frame()
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
	await _await_frame()
	assert_true(g.is_locked(), "gate still locked while m2 is alive")
	m2.die()
	await _await_frame()
	assert_true(g.is_unlocked(), "gate unlocks once both mobs dead, including the late one")


func test_3mob_concurrent_death_with_death_wait_unlocks() -> void:
	# Regression pin for ticket 86c9u6uhg (Room 05 unlocks correctly when 3
	# chasers die concurrently — including the production death-wait Timer
	# path, NOT the test-only `test_skip_death_wait = true` short-circuit
	# that the other tests in this file use).
	#
	# Story: in the AC4 release-build run, all 3 Room 05 chasers die within
	# ~1s of each other. The gate's `_on_mob_died` (CONNECT_DEFERRED) is
	# fired three times in quick succession. The LAST decrement
	# (mobs_alive 1 → 0) is the one that arms `_start_death_wait` for
	# DEATH_TWEEN_WAIT_SECS (0.65s) before unlocking.
	#
	# The original AC4 failure ("gateUnlocked=false after settle") was NOT
	# this race — investigation found the actual cause was
	# `Engine.time_scale = 0.10` (StatAllocationPanel auto-open on the
	# concurrent L1→L2 cross). But the dispatch asked for a regression pin
	# on the 3-mob concurrent-death gate path itself, and this is it:
	# without `test_skip_death_wait = true`, the gate must STILL fire
	# `gate_unlocked` after the Timer's wait_time elapses.
	#
	# We don't wait the full 0.65 s real-time — `advance_death_wait_for_test`
	# simulates the Timer firing immediately so the test stays fast.
	var g: RoomGate = _make_gate()
	# DO NOT use trigger_for_test (it sets test_skip_death_wait = true).
	# Use lock() directly + register mobs to keep the production death-
	# wait path active.
	var m1: FakeMob = _make_fake_mob()
	var m2: FakeMob = _make_fake_mob()
	var m3: FakeMob = _make_fake_mob()
	g.register_mob(m1)
	g.register_mob(m2)
	g.register_mob(m3)
	# Manually flip state to LOCKED so _on_mob_died's
	# `_mobs_alive == 0 and _state == STATE_LOCKED` branch arms the wait.
	g.lock()
	assert_true(g.is_locked(), "gate locked with 3 mobs alive")
	watch_signals(g)
	# Fire all three death signals concurrently (same frame).
	m1.die()
	m2.die()
	m3.die()
	# Drain ONE frame — CONNECT_DEFERRED queues all three decrements.
	await _await_frame()
	# After the deferred decrements, mobs_alive == 0 and the death-wait
	# Timer has been armed. The gate has NOT unlocked yet (still LOCKED,
	# waiting for the timer).
	assert_eq(g.mobs_alive(), 0, "all three deaths decremented")
	assert_true(g.is_locked(), "gate still LOCKED — waiting on death-wait timer")
	# Simulate the timer firing (production path: SceneTreeTimer or Timer
	# node fires after DEATH_TWEEN_WAIT_SECS).
	g.advance_death_wait_for_test()
	assert_true(g.is_unlocked(), "gate UNLOCKED after death-wait elapses")
	assert_signal_emit_count(g, "gate_unlocked", 1, "gate_unlocked emitted exactly once")


func test_layer_mask_targets_player_only() -> void:
	# Defensive: the gate's collision_mask must include the player layer
	# (bit 2) and NOT include the enemy layer (bit 4). This ensures mobs
	# walking through the gate area don't accidentally trigger lock.
	var packed: PackedScene = load("res://scenes/levels/RoomGate.tscn")
	var g: RoomGate = packed.instantiate()
	add_child_autofree(g)
	assert_true((g.collision_mask & RoomGate.LAYER_PLAYER) != 0, "masks player")
	assert_eq(g.collision_layer, 0, "gate emits no collisions itself")


# ---- Knockback-overlap fix (ticket 86c9ujf5v / 86c9ujf14) ---------------
#
# When combat knockback pushes the player INTO the gate trigger while mobs are
# alive, `body_entered` fires the lock transition. If the player stays inside
# the trigger until the last mob dies and `_unlock()` runs, Godot will NOT
# re-emit `body_entered` — the player is STUCK.
#
# Fix: `_unlock` calls `_fire_traversal_if_unlocked` deferred. The test asserts
# the deferred helper emits `gate_traversed` exactly once, even without a real
# physics overlap, by calling it directly after `_unlock`.

func test_fire_traversal_if_unlocked_emits_gate_traversed() -> void:
	# `_fire_traversal_if_unlocked` fires `gate_traversed` when the gate is
	# UNLOCKED and `_traversed_emitted` is false. Simulates the knockback-overlap
	# path: player was inside the trigger when `_unlock` ran, then the deferred
	# `_fire_traversal_if_unlocked` fires.
	var g: RoomGate = _make_gate()
	var m: FakeMob = _make_fake_mob()
	g.register_mob(m)
	g.trigger_for_test(null)   # sets test_skip_death_wait + locks
	m.die()
	await _await_frame()       # CONNECT_DEFERRED decrement runs
	# Gate is now UNLOCKED (test_skip_death_wait=true → _unlock fires synchronously).
	assert_true(g.is_unlocked(), "gate must be UNLOCKED before testing the overlap path")
	watch_signals(g)
	# Simulate the deferred call from _unlock: player was overlapping at unlock time.
	g._fire_traversal_if_unlocked()
	assert_signal_emitted(g, "gate_traversed",
		"gate_traversed emits when _fire_traversal_if_unlocked is called on UNLOCKED gate")
	assert_signal_emit_count(g, "gate_traversed", 1,
		"gate_traversed emits exactly once (idempotency guard)")


func test_fire_traversal_if_unlocked_is_idempotent() -> void:
	# Calling `_fire_traversal_if_unlocked` twice must emit `gate_traversed`
	# exactly once — the `_traversed_emitted` guard prevents double-emission
	# even if the deferred call races with a real `body_entered`.
	var g: RoomGate = _make_gate()
	var m: FakeMob = _make_fake_mob()
	g.register_mob(m)
	g.trigger_for_test(null)
	m.die()
	await _await_frame()
	assert_true(g.is_unlocked(), "gate UNLOCKED precondition")
	watch_signals(g)
	g._fire_traversal_if_unlocked()
	g._fire_traversal_if_unlocked()  # second call — must no-op
	assert_signal_emit_count(g, "gate_traversed", 1,
		"second _fire_traversal_if_unlocked is a no-op (_traversed_emitted guard)")


func test_fire_traversal_if_unlocked_noop_when_not_unlocked() -> void:
	# `_fire_traversal_if_unlocked` must be a no-op when the gate is LOCKED
	# (not yet UNLOCKED). Guards against a race where the deferred call fires
	# before the unlock completes.
	var g: RoomGate = _make_gate()
	var m: FakeMob = _make_fake_mob()
	g.register_mob(m)
	g.trigger_for_test(null)  # LOCKED, mob alive
	assert_true(g.is_locked(), "gate is LOCKED precondition")
	watch_signals(g)
	g._fire_traversal_if_unlocked()  # must be a no-op (gate not UNLOCKED yet)
	assert_signal_not_emitted(g, "gate_traversed",
		"_fire_traversal_if_unlocked is a no-op when gate is LOCKED (not UNLOCKED)")


# ---- B-OUTSIDE harness contract — ticket 86c9utcb7 ------------------------
#
# The case B-OUTSIDE harness path (`gateTraversalWalk` in
# `tests/playwright/fixtures/gate-traversal.ts`) relies on this game-side
# contract: when the last mob dies and `_unlock()` runs WITHOUT a body
# overlapping the trigger, `gate_unlocked` MUST emit exactly once, but
# `gate_traversed` MUST NOT auto-emit. The player has to walk back into the
# trigger to fire `body_entered`, which the UNLOCKED-branch of
# `_on_body_entered` then converts to `gate_traversed`.
#
# This is the empirically-observed Room 03 Charger-knockback shape (PR #251
# traces): the player drifts ~12-24 px east of the trigger east edge by the
# unlock instant, so `get_overlapping_bodies()` is empty and
# `_fire_traversal_if_unlocked` is correctly never invoked. The harness
# resolves this via a staged-east + walk-west finish-traversal (legitimate
# §15 game-mechanic-driven multi-outcome — analogous to Consumer 1 case B
# in `kiting-mob-chase.ts`).
#
# If this contract is ever changed (e.g. a future PR makes `_unlock` always
# fire `gate_traversed` as a "convenience"), this test fails before the
# harness's B-OUTSIDE walk has a chance to surface the regression — and the
# harness would then be silently masking a behavioural change.

func test_unlock_with_no_overlap_emits_gate_unlocked_only() -> void:
	# `_unlock()` invoked with no body overlapping the trigger emits
	# `gate_unlocked` but NOT `gate_traversed`. The B-OUTSIDE harness path
	# is built on this guarantee: the gate stops at UNLOCKED, and the
	# player must walk in again to fire `body_entered → gate_traversed`.
	#
	# Headless GUT note: bare-instanced RoomGate has no physics overlap
	# regardless of body position, so `get_overlapping_bodies()` returns []
	# inside `_unlock()`. That matches the production semantics for the
	# B-OUTSIDE sub-case (player outside trigger ↔ empty overlap list).
	var g: RoomGate = _make_gate()
	var m: FakeMob = _make_fake_mob()
	g.register_mob(m)
	g.trigger_for_test(null)
	assert_true(g.is_locked(), "gate locked precondition")
	watch_signals(g)
	m.die()
	# CONNECT_DEFERRED decrement + `_unlock` chain runs at end-of-frame.
	# Drain one frame for the decrement; `test_skip_death_wait=true` (set by
	# `trigger_for_test`) makes `_unlock` fire synchronously inside the same
	# decrement handler.
	await _await_frame()
	assert_true(g.is_unlocked(), "gate UNLOCKED after final mob dies")
	assert_signal_emitted(g, "gate_unlocked",
		"gate_unlocked emits when last mob dies")
	assert_signal_emit_count(g, "gate_unlocked", 1,
		"gate_unlocked emits exactly once")
	# Critical: no auto-traversal. The B-OUTSIDE harness path REQUIRES that
	# `gate_traversed` is NOT auto-emitted when no body overlaps at unlock.
	assert_signal_not_emitted(g, "gate_traversed",
		"gate_traversed must NOT auto-emit when no body overlaps at " +
		"unlock — harness B-OUTSIDE path (ticket 86c9utcb7) requires the " +
		"player to walk back into the trigger to fire gate_traversed.")
