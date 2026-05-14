extends GutTest
## Integration tests for the M1 RC Bug 1 fix (ticket 86c9q7xgx):
## "auto-advance to next room on mob-hit — likely swing Hitbox triggers RoomGate."
##
## These tests verify that:
##   1. A player swing (Hitbox) does NOT advance the room (gate stays untriggered).
##   2. Killing all mobs WITHOUT crossing the gate does NOT advance the room.
##   3. Crossing the gate WITH mobs alive does NOT advance the room (gate locks,
##      stays locked until mobs die).
##   4. Crossing the gate + killing all mobs DOES advance the room (happy path).
##   5. Area2D neighbors (Hitbox, Projectile) cannot trigger the gate directly.
##   6. The BossRoom door trigger ignores Area2D neighbors (harmonization fix
##      for ticket 86c9p1fgf).
##
## Test design principle (from agent-verify-evidence.md + combat-architecture.md
## §"Equipped-weapon dual-surface rule"): uses REAL RoomGate + REAL Hitbox /
## Area2D nodes so integration surface bugs are caught, NOT stub nodes that
## silently skip the physics collision check.
##
## Note on HTML5 verification gate: the RoomGate uses body_entered (physics
## layer filtering), which behaves identically on all renderers — this is NOT
## in the class of Tween/modulate/Polygon2D/CPUParticles2D bugs that require
## HTML5-specific verification. The door-trigger filter fix is also physics-
## layer-only. Headless tests are sufficient here.

const RoomGateScript: Script = preload("res://scripts/levels/RoomGate.gd")
const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")
const Stratum1BossRoomScript: Script = preload("res://scripts/levels/Stratum1BossRoom.gd")


# ---- Helpers -----------------------------------------------------------

class FakeMob:
	extends Node2D
	signal mob_died(mob: Variant, position: Vector2, mob_def: Variant)
	func die() -> void:
		mob_died.emit(self, global_position, null)


class FakePlayer:
	extends CharacterBody2D
	# Real CharacterBody2D (not bare Node) — the gate's body_entered signal
	# fires from CharacterBody2D/PhysicsBody2D entries. A bare Node2D would
	# not trigger body_entered even at the correct layer position.


func _make_gate() -> RoomGate:
	var g: RoomGate = RoomGateScript.new()
	add_child_autofree(g)
	return g


func _make_fake_mob() -> FakeMob:
	var m: FakeMob = FakeMob.new()
	add_child_autofree(m)
	return m


func _make_fake_player() -> FakePlayer:
	var p: FakePlayer = FakePlayer.new()
	add_child_autofree(p)
	return p


func _make_hitbox() -> Hitbox:
	var h: Hitbox = HitboxScript.new()
	h.configure(5, Vector2.ZERO, 0.1, Hitbox.TEAM_PLAYER, null)
	add_child_autofree(h)
	return h


# ---- 1. Gate ignores Area2D entry (Hitbox / swing) --------------------

func test_area2d_entering_gate_does_not_lock_it() -> void:
	# Bug 1 core AC: a player Hitbox (Area2D) must NOT trigger the gate.
	# In Godot 4, body_entered only fires for PhysicsBody2D nodes —
	# Area2D entry fires area_entered, which the gate explicitly ignores.
	# This test verifies the gate stays OPEN after an area neighbor enters.
	var g: RoomGate = _make_gate()
	var m: FakeMob = _make_fake_mob()
	g.register_mob(m)
	watch_signals(g)

	# Simulate an area entering the gate's detection zone — mirrors the
	# runtime path when a player swing Hitbox overlaps the gate Area2D.
	var fake_area: Area2D = Area2D.new()
	add_child_autofree(fake_area)
	g._on_area_entered_ignored(fake_area)

	assert_eq(g.get_state(), RoomGate.STATE_OPEN,
		"gate must remain OPEN — Area2D (swing Hitbox) cannot trigger it")
	assert_signal_not_emitted(g, "gate_locked")
	assert_signal_not_emitted(g, "gate_unlocked")


func test_hitbox_area2d_entering_gate_does_not_lock_it() -> void:
	# Same as above but uses a real Hitbox instance so any future change to
	# Hitbox that makes it a PhysicsBody2D would immediately surface here.
	var g: RoomGate = _make_gate()
	var m: FakeMob = _make_fake_mob()
	g.register_mob(m)
	watch_signals(g)

	var h: Hitbox = _make_hitbox()
	# Directly invoke the area_entered handler — mirrors physics callback.
	g._on_area_entered_ignored(h)

	assert_eq(g.get_state(), RoomGate.STATE_OPEN,
		"real Hitbox entering gate detection zone must leave gate OPEN")
	assert_signal_not_emitted(g, "gate_locked")


# ---- 2. Mob kill WITHOUT gate trigger does NOT advance room ------------

func test_killing_all_mobs_without_gate_trigger_does_not_unlock() -> void:
	# Bug 1 AC: player kills all mobs but never crossed the gate.
	# Gate should stay OPEN — cannot unlock from STATE_OPEN.
	# (Room advance requires gate to be LOCKED first, then all mobs die.)
	var g: RoomGate = _make_gate()
	var m: FakeMob = _make_fake_mob()
	g.register_mob(m)
	watch_signals(g)

	# Kill the mob WITHOUT locking the gate first.
	m.die()
	# Ticket 86c9qcf9z: drain one frame so CONNECT_DEFERRED dispatch lands.
	await get_tree().process_frame

	assert_eq(g.get_state(), RoomGate.STATE_OPEN,
		"gate must remain OPEN when mobs die before player crosses it")
	assert_signal_not_emitted(g, "gate_locked")
	assert_signal_not_emitted(g, "gate_unlocked",
		"room_cleared must NOT fire if gate was never locked")


func test_multiple_mob_kills_without_gate_trigger_stays_open() -> void:
	var g: RoomGate = _make_gate()
	var m1: FakeMob = _make_fake_mob()
	var m2: FakeMob = _make_fake_mob()
	g.register_mob(m1)
	g.register_mob(m2)
	watch_signals(g)

	m1.die()
	m2.die()
	await get_tree().process_frame

	assert_eq(g.mobs_alive(), 0)
	assert_eq(g.get_state(), RoomGate.STATE_OPEN,
		"gate stays OPEN even after all mobs die without gate lock")
	assert_signal_not_emitted(g, "gate_unlocked")


# ---- 3. Gate lock + mobs alive = stays locked (no premature advance) ---

func test_gate_locks_on_player_body_entry_with_mobs_alive() -> void:
	# Verifies gate LOCKS when player CharacterBody2D crosses — and stays
	# LOCKED (not advancing) while mobs are still alive.
	var g: RoomGate = _make_gate()
	var m: FakeMob = _make_fake_mob()
	g.register_mob(m)
	watch_signals(g)

	# Player body crosses the gate. Use trigger_for_test (test-API shim that
	# invokes _on_body_entered without physics overlap).
	var p: FakePlayer = _make_fake_player()
	g.trigger_for_test(p)

	assert_true(g.is_locked(), "gate must LOCK on player body entry")
	assert_signal_emitted(g, "gate_locked")
	assert_signal_not_emitted(g, "gate_unlocked",
		"gate must stay LOCKED while the mob is alive — no premature advance")


func test_non_characterbody_does_not_lock_gate() -> void:
	# Bug 1 defence: a bare Node2D (or any non-CharacterBody2D) entering
	# must not lock the gate. The _on_body_entered guard explicitly checks
	# `body is CharacterBody2D` for belt-and-suspenders protection.
	var g: RoomGate = _make_gate()
	var m: FakeMob = _make_fake_mob()
	g.register_mob(m)
	watch_signals(g)

	# Pass a bare Node2D — not a CharacterBody2D.
	var bare_node: Node2D = Node2D.new()
	add_child_autofree(bare_node)
	g._on_body_entered(bare_node)

	assert_eq(g.get_state(), RoomGate.STATE_OPEN,
		"bare Node2D must not lock gate — CharacterBody2D guard required")
	assert_signal_not_emitted(g, "gate_locked")


# ---- 4. Gate lock + kill all mobs = unlocks (happy path) ---------------

func test_lock_then_kill_all_mobs_unlocks_gate() -> void:
	# Happy-path AC: player crosses gate (locks it) then kills all mobs
	# → gate unlocks → room_cleared fires.
	var g: RoomGate = _make_gate()
	var m: FakeMob = _make_fake_mob()
	g.register_mob(m)

	var p: FakePlayer = _make_fake_player()
	g.trigger_for_test(p)
	assert_true(g.is_locked())

	watch_signals(g)
	m.die()
	await get_tree().process_frame

	assert_true(g.is_unlocked(), "gate must UNLOCK once last mob dies (after gate locked)")
	assert_signal_emitted(g, "gate_unlocked")


func test_lock_then_kill_multiple_mobs_unlocks_on_last() -> void:
	var g: RoomGate = _make_gate()
	var m1: FakeMob = _make_fake_mob()
	var m2: FakeMob = _make_fake_mob()
	g.register_mob(m1)
	g.register_mob(m2)

	var p: FakePlayer = _make_fake_player()
	g.trigger_for_test(p)

	watch_signals(g)
	m1.die()
	await get_tree().process_frame
	assert_signal_not_emitted(g, "gate_unlocked",
		"gate must stay locked after first mob — second still alive")
	m2.die()
	await get_tree().process_frame
	assert_signal_emitted(g, "gate_unlocked", "gate unlocks when last mob dies")


# ---- 5. Collision layer: gate masks player, not enemy or hitbox layers --

func test_gate_collision_mask_targets_player_layer_only() -> void:
	var packed: PackedScene = load("res://scenes/levels/RoomGate.tscn")
	var g: RoomGate = packed.instantiate()
	add_child_autofree(g)
	assert_true((g.collision_mask & RoomGate.LAYER_PLAYER) != 0,
		"gate must mask the player physics layer")
	assert_eq(g.collision_layer, 0,
		"gate emits no collisions itself — zero collision_layer")
	# Hitbox sits on LAYER_PLAYER_HITBOX (bit 3 = 4). Gate must NOT mask it.
	const LAYER_PLAYER_HITBOX: int = 1 << 2
	assert_eq(g.collision_mask & LAYER_PLAYER_HITBOX, 0,
		"gate must NOT mask player_hitbox layer — swing Hitbox cannot trigger it")
	# Enemy sits on LAYER_ENEMY (bit 4 = 8). Gate must NOT mask it.
	const LAYER_ENEMY: int = 1 << 3
	assert_eq(g.collision_mask & LAYER_ENEMY, 0,
		"gate must NOT mask enemy layer — mob bodies cannot trigger it")


# ---- 6. BossRoom door trigger harmonization (ticket 86c9p1fgf) ---------

func test_boss_room_door_trigger_is_not_monitorable() -> void:
	# Bug 1 harmonization AC: the BossRoom door trigger is built with
	# monitorable=false so other Area2Ds (Hitbox, Projectile) cannot receive
	# area_entered FROM it. The trigger only needs to DETECT bodies (player),
	# not to BE detected.
	#
	# We instantiate Stratum1BossRoom bare (no boss scene, no StratumExit)
	# by overriding the export paths to empty strings so the load calls
	# skip gracefully. Then verify the built door trigger.
	var boss_room: Stratum1BossRoom = Stratum1BossRoomScript.new()
	# Suppress scene loads in _ready so tests don't need filesystem resources.
	boss_room.boss_scene_path = ""
	boss_room.boss_mob_def_path = ""
	boss_room.stratum_exit_scene_path = ""
	add_child_autofree(boss_room)
	# Physics-flush fix (ticket 86c9tv8uf): `_build_door_trigger` is now
	# deferred via `_ready → call_deferred("_assemble_room_fixtures")`, so the
	# door trigger lands next-frame. Drain a frame before retrieving it.
	await get_tree().process_frame
	var trigger: Area2D = boss_room.get_door_trigger()
	assert_not_null(trigger, "door trigger must exist after deferred fixture pass")
	assert_false(trigger.monitorable,
		"Bug 1 harmonization: BossRoom door trigger must be non-monitorable " +
		"so Area2D neighbors cannot receive area_entered from it")


func test_boss_room_door_trigger_area_entered_ignored_does_not_start_entry_sequence() -> void:
	# The new _on_door_trigger_area_entered_ignored handler must be a true
	# no-op — area neighbors must not trigger the entry sequence.
	var boss_room: Stratum1BossRoom = Stratum1BossRoomScript.new()
	boss_room.boss_scene_path = ""
	boss_room.boss_mob_def_path = ""
	boss_room.stratum_exit_scene_path = ""
	add_child_autofree(boss_room)
	# Deferred fixture pass (ticket 86c9tv8uf) — drain a frame so the door
	# trigger + its area_entered connection exist before we exercise them.
	await get_tree().process_frame
	watch_signals(boss_room)

	# Invoke the area_entered no-op handler directly.
	var fake_area: Area2D = Area2D.new()
	add_child_autofree(fake_area)
	boss_room._on_door_trigger_area_entered_ignored(fake_area)

	assert_signal_not_emitted(boss_room, "entry_sequence_started",
		"area entering door trigger must NOT start boss entry sequence")
	assert_false(boss_room.is_entry_sequence_active(),
		"entry sequence must remain inactive after area_entered no-op")


func test_boss_room_door_trigger_non_characterbody_ignored() -> void:
	# Boss entry sequence must only fire for CharacterBody2D.
	var boss_room: Stratum1BossRoom = Stratum1BossRoomScript.new()
	boss_room.boss_scene_path = ""
	boss_room.boss_mob_def_path = ""
	boss_room.stratum_exit_scene_path = ""
	add_child_autofree(boss_room)
	# Deferred fixture pass (ticket 86c9tv8uf) — drain a frame so the door
	# trigger exists before we exercise its body_entered handler.
	await get_tree().process_frame
	watch_signals(boss_room)

	# Invoke body_entered with a bare Node2D — not a CharacterBody2D.
	var bare: Node2D = Node2D.new()
	add_child_autofree(bare)
	boss_room._on_door_trigger_body_entered(bare)

	assert_signal_not_emitted(boss_room, "entry_sequence_started",
		"bare Node2D body must NOT trigger boss entry sequence")
