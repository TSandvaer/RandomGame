extends GutTest
## Integration tests for `scenes/levels/Stratum1BossRoom.tscn` — verifies the
## door-trigger fires the entry sequence, the sequence completes in 1.8 s,
## the boss spawns at the end, and boss death triggers the
## stratum-exit-unlocked state.
##
## Per testing bar §integration check + Drew's task spec (`86c9kxx4t`).

const BossRoomScript: Script = preload("res://scripts/levels/Stratum1BossRoom.gd")
const BossScript: Script = preload("res://scripts/mobs/Stratum1Boss.gd")


# ---- Helpers ----------------------------------------------------------

class FakePlayerBody:
	extends CharacterBody2D
	# A real CharacterBody2D so the door trigger's body_entered overlap
	# fires. We don't need any AI on it; just a body on the player layer.
	func _init() -> void:
		# Player layer = bit 2.
		collision_layer = 1 << 1


func _make_room() -> Stratum1BossRoom:
	var packed: PackedScene = load("res://scenes/levels/Stratum1BossRoom.tscn")
	var room: Stratum1BossRoom = packed.instantiate()
	add_child_autofree(room)
	return room


# ---- 1: scene loads + room script wires -----------------------------

func test_boss_room_scene_loads() -> void:
	var packed: PackedScene = load("res://scenes/levels/Stratum1BossRoom.tscn")
	assert_not_null(packed, "Stratum1BossRoom.tscn must load")
	var instance: Node = packed.instantiate()
	assert_true(instance is Stratum1BossRoom, "root is Stratum1BossRoom typed")
	instance.free()


func test_room_has_door_trigger_and_boss() -> void:
	var room: Stratum1BossRoom = _make_room()
	assert_not_null(room.get_door_trigger(), "door trigger Area2D exists")
	assert_not_null(room.get_boss(), "boss spawned at room ready")
	var boss: Stratum1Boss = room.get_boss()
	# Boss starts DORMANT — Uma BI-19 (no attack during intro).
	assert_true(boss.is_dormant(), "boss starts dormant — wakes at end of intro")


# ---- 2: door trigger fires entry sequence ---------------------------

func test_door_trigger_fires_entry_sequence() -> void:
	var room: Stratum1BossRoom = _make_room()
	watch_signals(room)
	# Simulate the player crossing the trigger via the public API. (A real
	# physics overlap is covered downstream by Tess's manual test; the unit-
	# level contract is "trigger_entry_sequence flips the sequence on".)
	room.trigger_entry_sequence()
	assert_signal_emitted(room, "entry_sequence_started")
	assert_true(room.is_entry_sequence_active())
	assert_false(room.is_entry_sequence_completed())


func test_door_trigger_is_idempotent() -> void:
	var room: Stratum1BossRoom = _make_room()
	watch_signals(room)
	room.trigger_entry_sequence()
	room.trigger_entry_sequence()
	room.trigger_entry_sequence()
	assert_signal_emit_count(room, "entry_sequence_started", 1,
		"entry sequence fires exactly once even if trigger overlaps multiple times")


# ---- 3: entry sequence completes within 1.8 s ± tolerance -----------

func test_entry_sequence_duration_constant_is_1_8s() -> void:
	# Static contract — Uma's spec says 1.8 s. If this constant ever drifts,
	# tests bounce so we don't silently break Uma's beat-timing intent.
	assert_almost_eq(Stratum1BossRoom.ENTRY_SEQUENCE_DURATION, 1.8, 0.001,
		"entry sequence is exactly 1.8 s per Uma boss-intro.md")


func test_entry_sequence_completion_signal_fires_after_completion_call() -> void:
	# Production waits on a SceneTreeTimer; tests use the test-helper to
	# fast-forward to the end of the sequence deterministically.
	var room: Stratum1BossRoom = _make_room()
	watch_signals(room)
	room.trigger_entry_sequence()
	room.complete_entry_sequence_for_test()
	assert_signal_emitted(room, "entry_sequence_completed")
	assert_true(room.is_entry_sequence_completed())
	assert_false(room.is_entry_sequence_active())


# ---- 4: boss spawns at end of entry sequence (i.e. wakes) ------------

func test_boss_wakes_at_entry_sequence_end() -> void:
	var room: Stratum1BossRoom = _make_room()
	var boss: Stratum1Boss = room.get_boss()
	assert_true(boss.is_dormant(), "boss dormant before sequence")
	room.trigger_entry_sequence()
	# Still dormant during the sequence.
	assert_true(boss.is_dormant(), "boss still dormant during entry sequence")
	room.complete_entry_sequence_for_test()
	assert_false(boss.is_dormant(), "boss is awake after sequence completes")
	assert_eq(boss.get_state(), Stratum1Boss.STATE_IDLE)


func test_boss_does_not_take_damage_during_intro() -> void:
	# Acceptance for Uma BI-19: boss does NOT engage during Beats 1–4.
	var room: Stratum1BossRoom = _make_room()
	var boss: Stratum1Boss = room.get_boss()
	room.trigger_entry_sequence()
	# Boss is dormant during entry — damage is rejected.
	var hp_at_intro: int = boss.get_hp()
	boss.take_damage(50, Vector2.ZERO, null)
	assert_eq(boss.get_hp(), hp_at_intro,
		"boss takes no damage during intro sequence")


# ---- 5: boss death triggers stratum-exit-unlocked state -------------

func test_boss_death_unlocks_stratum_exit() -> void:
	var room: Stratum1BossRoom = _make_room()
	var boss: Stratum1Boss = room.get_boss()
	# Wake the boss and bring HP to 0 by emitting boss_died directly via a
	# configured kill path. Use the actual phase-down sequence so the death
	# condition runs through the production path.
	room.trigger_entry_sequence()
	room.complete_entry_sequence_for_test()
	assert_false(boss.is_dormant())
	watch_signals(room)
	# Boss has 600 HP. Cross both phase boundaries, then kill.
	# Phase 2 at 396, phase 3 at 198.
	boss.take_damage(204, Vector2.ZERO, null)  # 600 → 396 (phase 2 trigger)
	boss._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	boss.take_damage(198, Vector2.ZERO, null)  # 396 → 198 (phase 3 trigger)
	boss._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	boss.take_damage(198, Vector2.ZERO, null)  # 198 → 0 (death)
	assert_true(boss.is_dead())
	assert_signal_emitted(room, "stratum_exit_unlocked")
	assert_signal_emitted(room, "boss_defeated")
	assert_true(room.is_stratum_exit_unlocked())


func test_boss_death_drops_loot_into_room() -> void:
	# When the boss dies in the room, loot pickups are children of the room
	# (via MobLootSpawner.set_parent_for_pickups(self)).
	var room: Stratum1BossRoom = _make_room()
	var boss: Stratum1Boss = room.get_boss()
	room.trigger_entry_sequence()
	room.complete_entry_sequence_for_test()
	# Kill the boss.
	boss.take_damage(204, Vector2.ZERO, null)
	boss._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	boss.take_damage(198, Vector2.ZERO, null)
	boss._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	boss.take_damage(198, Vector2.ZERO, null)
	assert_true(boss.is_dead())
	# Pickup add_child is deferred (physics-flush safety per `_die` P0
	# fix run-002). Await one frame for the deferred call to land.
	await get_tree().process_frame
	# At least one Pickup child under the room.
	var pickup_count: int = 0
	for c: Node in room.get_children():
		if c is Pickup:
			pickup_count += 1
	assert_gt(pickup_count, 0, "boss death drops at least one Pickup into the room")


# ---- Bounds + content sanity ----------------------------------------

func test_boss_spawn_position_is_in_arena() -> void:
	# Default spawn at (240, 135) sits inside Uma's 480x270 internal canvas
	# centered at (240, 135) — i.e. dead center.
	var room: Stratum1BossRoom = _make_room()
	var boss: Stratum1Boss = room.get_boss()
	assert_almost_eq(boss.position.x, 240.0, 0.001)
	assert_almost_eq(boss.position.y, 135.0, 0.001)


func test_boss_uses_authored_mobdef() -> void:
	# Boss should pick up stratum1_boss.tres values: 600 HP, "Warden ..."
	# display_name. Verifies the room's spawn path applies the def.
	var room: Stratum1BossRoom = _make_room()
	var boss: Stratum1Boss = room.get_boss()
	assert_eq(boss.get_max_hp(), 600, "authored stratum1_boss.tres applied — 600 HP")
	assert_not_null(boss.mob_def)
	assert_eq(boss.mob_def.id, &"stratum1_boss")
