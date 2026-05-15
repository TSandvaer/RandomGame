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
	# `_spawn_boss` stays synchronous in `_ready`, so the boss is available
	# immediately. The door trigger is built in the deferred `_assemble_room_fixtures`
	# pass (ticket 86c9tv8uf physics-flush fix) — drain a frame for it.
	assert_not_null(room.get_boss(), "boss spawned at room ready (synchronous)")
	await get_tree().process_frame
	assert_not_null(room.get_door_trigger(), "door trigger Area2D exists after deferred fixture pass")
	var boss: Stratum1Boss = room.get_boss()
	# Boss starts DORMANT — Uma BI-19 (no attack during intro).
	assert_true(boss.is_dormant(), "boss starts dormant — wakes at end of intro")


# ---- 1b. Physics-flush fix — door trigger enters tree + monitors ----
#
# **The ticket 86c9tv8uf regression gate.** Drives the REAL Stratum1BossRoom
# build path (scene instantiate → `_ready` → deferred `_assemble_room_fixtures`)
# and asserts the door-trigger Area2D ends up correctly inserted in the tree
# AND monitoring.
#
# Pre-fix: `_build_door_trigger` ran synchronously inside `_ready`. In
# production that `_ready` runs inside a physics-flush window — the boss room
# is loaded by `Main._load_room_at_index(8)` from Room 08's `gate_traversed`
# body callback. Adding the door-trigger Area2D + activating its monitoring
# inside that flush panics (`USER ERROR: Can't change this state while
# flushing queries`); the C++ early-returns, leaving the Area2D improperly
# inserted — it never monitors, `body_entered` never fires, and the player
# can never leave the boss room.
#
# Post-fix: `_build_door_trigger` + `_spawn_stratum_exit` are deferred out of
# the physics-flush window via `call_deferred("_assemble_room_fixtures")`.
# After one drained frame the door trigger exists, is inside the tree, and
# has monitoring active.
#
# (GUT's `add_child` is not itself inside a physics flush, so this test can't
# reproduce the panic directly — but it pins the load-bearing post-condition:
# after the deferred pass, the door trigger is a properly-monitoring Area2D
# in the tree. The HTML5 release-build trace evidence in the Self-Test Report
# covers the actual physics-flush-window path.)

func test_door_trigger_enters_tree_and_monitors_after_deferred_pass() -> void:
	var room: Stratum1BossRoom = _make_room()
	# Pre-drain: the deferred fixture pass has NOT landed yet, so the door
	# trigger does not exist.
	assert_null(room.get_door_trigger(),
		"door trigger is NOT built synchronously in _ready (deferred out of physics-flush window)")
	await get_tree().process_frame
	# Post-drain: the deferred `_assemble_room_fixtures` pass has run.
	var trigger: Area2D = room.get_door_trigger()
	assert_not_null(trigger, "REGRESSION-86c9tv8uf: door trigger Area2D built in deferred fixture pass")
	assert_true(trigger.is_inside_tree(),
		"REGRESSION-86c9tv8uf: door trigger Area2D is inserted in the scene tree")
	assert_eq(trigger.get_parent(), room,
		"door trigger is parented under the boss room")
	assert_true(trigger.monitoring,
		"REGRESSION-86c9tv8uf: door trigger Area2D has monitoring ACTIVE — " +
		"body_entered can fire so the player can exit the boss room")
	# The trigger must still carry a CollisionShape2D child (the rect that
	# defines the overlap zone) — a monitoring Area2D with no shape is inert.
	var has_shape: bool = false
	for c: Node in trigger.get_children():
		if c is CollisionShape2D:
			has_shape = true
	assert_true(has_shape, "door trigger Area2D carries its CollisionShape2D")
	# StratumExit (which builds its own Area2D interaction area on _ready) is
	# also spawned in the deferred pass — confirm it landed.
	assert_not_null(room.get_stratum_exit(),
		"REGRESSION-86c9tv8uf: StratumExit spawned in the deferred fixture pass")


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


## REGRESSION-86c9uemdg — boss-room single-loot-pipeline rule.
##
## **Pre-fix:** Stratum1BossRoom owned its own `MobLootSpawner` and called
## `on_mob_died(boss, ...)` from `_on_boss_died`. Main also subscribed to
## `boss_died` via `_wire_mob` and called its OWN spawner — producing TWO
## independent roll() sets per boss death. Main's set was wired via
## `Inventory.auto_collect_pickups` (player walking over them adds to
## inventory); BossRoom's set had no listener on `picked_up` so the player
## walking over them produced no effect — Sponsor reported "boss room 8
## cannot loot dropped items" (M2 RC soak build 5bef197).
##
## **Post-fix:** Stratum1BossRoom no longer owns a `_loot_spawner`. Main is
## the single source of boss loot. This test pins the new contract — running
## the room standalone produces ZERO Pickup children (no loot drop happens
## without Main's wiring). The Main-driven boss-loot path is covered by
## `tests/integration/test_boss_loot_integration.gd`.
func test_standalone_boss_death_drops_NO_loot_from_room_self() -> void:
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
	# fix run-002). Await one frame for any deferred call to land.
	await get_tree().process_frame
	var pickup_count: int = 0
	for c: Node in room.get_children():
		if c is Pickup:
			pickup_count += 1
	assert_eq(pickup_count, 0,
		"REGRESSION-86c9uemdg: boss room does NOT spawn its own loot — Main owns the boss-loot pipeline")


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
