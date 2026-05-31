# gdlint:disable=max-public-methods
# GUT test class — high test_* count IS the design (one test per scenario).
extends GutTest
## Integration tests for Stratum2BossRoom — paired with `scripts/levels/Stratum2BossRoom.gd`
## and `scenes/levels/Stratum2BossRoom.tscn`.
##
## Coverage per W3-T7 Stage 5 dispatch (ticket 86c9y7ygj Part D) + testing bar:
##   1. Scene loads + script wires.
##   2. Boss spawns at center plinth (synchronous from `_ready`).
##   3. Sentinel starts DORMANT (intro fairness).
##   4. Door trigger built + monitoring after deferred fixture pass
##      (regression pin against ticket 86c9tv8uf class — physics-flush fix).
##   5. StratumExit spawned + inactive at room ready, activates on boss death.
##   6. trigger_entry_sequence fires entry_sequence_started signal.
##   7. trigger_entry_sequence is idempotent (multiple calls = single fire).
##   8. ENTRY_SEQUENCE_DURATION constant pinned to 1.8 s (Uma spec lock).
##   9. complete_entry_sequence_for_test fast-forwards to IDLE_ACTIVE.
##  10. Boss death emits boss_defeated + stratum_exit_unlocked.
##  11. ARENA_BOUNDS pinned to 1024×768 (Uma §5.5 spec lock).
##  12. Scene .tscn carries four cardinal walls + floor (anti-regression
##      against silent wall-removal that would let player walk out mid-fight).
##  13. (Stage 6) BossNameplate reused from S1 — spawned in deferred fixture
##      pass, slides on entry_sequence_completed, opt-out when path empty.
##
## Replaces the pre-Stage-5 pending-stub scaffold that previously occupied
## this file (the W3-T4 placeholder tests; those were authored before Stage 5
## ticketing locked the Stratum2BossRoom scope under `86c9y7ygj` Part D, so
## the scaffold's W3-T4 cite is historically stale).

const BossRoomScript: Script = preload("res://scripts/levels/Stratum2BossRoom.gd")
const SentinelScript: Script = preload("res://scripts/mobs/ArchiveSentinel.gd")
const BOSS_ROOM_SCENE: PackedScene = preload("res://scenes/levels/Stratum2BossRoom.tscn")

# ---- Test isolation ---------------------------------------------------


func before_each() -> void:
	var d: Node = Engine.get_main_loop().root.get_node_or_null("TimeScaleDirector")
	if d != null and d.has_method("reset"):
		d.reset()
	Engine.time_scale = 1.0
	# Reset CameraDirector state — the room's `_engage_camera_for_boss_room`
	# sets follow_target + world_bounds; leaks into next test otherwise.
	var cam: Node = Engine.get_main_loop().root.get_node_or_null("CameraDirector")
	if cam != null and cam.has_method("reset_to_player"):
		cam.reset_to_player(0.0)


func after_each() -> void:
	var d: Node = Engine.get_main_loop().root.get_node_or_null("TimeScaleDirector")
	if d != null and d.has_method("reset"):
		d.reset()
	Engine.time_scale = 1.0
	var cam: Node = Engine.get_main_loop().root.get_node_or_null("CameraDirector")
	if cam != null and cam.has_method("reset_to_player"):
		cam.reset_to_player(0.0)


# ---- Helpers ----------------------------------------------------------


class FakePlayerBody:
	extends CharacterBody2D
	# A real CharacterBody2D so the door trigger's body_entered overlap
	# fires. We don't need any AI on it; just a body on the player layer.

	func _init() -> void:
		# Player layer = bit 2.
		collision_layer = 1 << 1


func _make_room() -> Stratum2BossRoom:
	var packed: PackedScene = BOSS_ROOM_SCENE
	var room: Stratum2BossRoom = packed.instantiate()
	add_child_autofree(room)
	return room


# ---- 1: scene loads + room script wires -----------------------------


func test_boss_room_scene_loads() -> void:
	var packed: PackedScene = BOSS_ROOM_SCENE
	assert_not_null(packed, "Stratum2BossRoom.tscn must load")
	var instance: Node = packed.instantiate()
	assert_true(instance is Stratum2BossRoom, "root is Stratum2BossRoom typed")
	instance.free()


# ---- 2: boss spawned synchronously at plinth + DORMANT --------------


func test_room_spawns_boss_at_plinth_dormant() -> void:
	var room: Stratum2BossRoom = _make_room()
	# `_spawn_boss` stays synchronous in `_ready`, so the boss is available
	# immediately. Door trigger built in deferred fixture pass.
	var boss: ArchiveSentinel = room.get_boss()
	assert_not_null(boss, "boss spawned synchronously at room _ready")
	assert_true(boss is ArchiveSentinel, "boss is ArchiveSentinel typed")
	assert_eq(
		boss.global_position,
		Stratum2BossRoom.PLINTH_POSITION,
		"boss spawned at center plinth (512, 384)"
	)
	# Sentinel starts DORMANT per Uma BI-19 (no attack during intro).
	assert_true(boss.is_dormant(), "Sentinel starts dormant — wakes at end of intro")


# ---- 3: Physics-flush fix — door trigger enters tree + monitors -----
#
# Regression gate against ticket 86c9tv8uf class. Mirrors S1 BossRoom's
# equivalent test. The Stratum2BossRoom is loaded from a port-traversal
# callback whose physics-flush context is the same root-cause class as
# S1's Room 08 → boss-room load.


func test_door_trigger_enters_tree_and_monitors_after_deferred_pass() -> void:
	var room: Stratum2BossRoom = _make_room()
	# Pre-drain: deferred fixture pass has NOT landed; door trigger absent.
	assert_null(
		room.get_door_trigger(),
		"door trigger NOT built synchronously in _ready (deferred out of physics-flush window)"
	)
	await get_tree().process_frame
	# Post-drain: deferred `_assemble_room_fixtures` ran.
	var trigger: Area2D = room.get_door_trigger()
	assert_not_null(
		trigger, "REGRESSION-86c9tv8uf-class: door trigger Area2D built in deferred fixture pass"
	)
	assert_true(
		trigger.is_inside_tree(),
		"REGRESSION-86c9tv8uf-class: door trigger Area2D inserted in scene tree"
	)
	assert_eq(trigger.get_parent(), room, "door trigger parented under the boss room")
	assert_true(
		trigger.monitoring,
		(
			"REGRESSION-86c9tv8uf-class: door trigger Area2D monitoring ACTIVE — "
			+ "body_entered can fire so the player can leave the boss room"
		)
	)
	# CollisionShape2D child must be present (Area2D with no shape is inert).
	var has_shape: bool = false
	for c: Node in trigger.get_children():
		if c is CollisionShape2D:
			has_shape = true
	assert_true(has_shape, "door trigger Area2D carries its CollisionShape2D")
	# StratumExit also spawned in deferred pass.
	assert_not_null(
		room.get_stratum_exit(),
		"REGRESSION-86c9tv8uf-class: StratumExit spawned in the deferred fixture pass"
	)


# ---- 4: door trigger fires entry sequence ---------------------------


func test_trigger_entry_sequence_fires_signal() -> void:
	var room: Stratum2BossRoom = _make_room()
	watch_signals(room)
	room.trigger_entry_sequence()
	assert_signal_emitted(room, "entry_sequence_started")
	assert_true(room.is_entry_sequence_active())
	assert_false(room.is_entry_sequence_completed())


func test_trigger_entry_sequence_is_idempotent() -> void:
	var room: Stratum2BossRoom = _make_room()
	watch_signals(room)
	room.trigger_entry_sequence()
	room.trigger_entry_sequence()
	room.trigger_entry_sequence()
	assert_signal_emit_count(
		room,
		"entry_sequence_started",
		1,
		"entry sequence fires exactly once even if trigger overlaps multiple times"
	)


# ---- 5: ENTRY_SEQUENCE_DURATION constant lock -----------------------


func test_entry_sequence_duration_constant_is_1_8s() -> void:
	# Static contract — Uma's spec says 1.8 s. If this constant ever drifts,
	# tests bounce so we don't silently break Uma's beat-timing intent.
	assert_almost_eq(
		Stratum2BossRoom.ENTRY_SEQUENCE_DURATION,
		1.8,
		0.001,
		"entry sequence is exactly 1.8 s per Uma boss-intro.md (Stratum-2 mirrors Stratum-1 timing)"
	)


# ---- 6: complete_entry_sequence_for_test fast-forwards -------------


func test_complete_entry_sequence_for_test_drives_to_idle_active() -> void:
	# The test helper should drain BOTH the 1.8 s entry timer AND the boss's
	# ~417 ms wake-anim window so tests immediately observe IDLE_ACTIVE
	# (combat-ready, damage-eligible). Mirrors S1 BossRoom helper shape.
	var room: Stratum2BossRoom = _make_room()
	# Drain the deferred fixture pass so the entry sequence auto-fires.
	await get_tree().process_frame
	# At this point the auto-fire from `_assemble_room_fixtures` engaged
	# the entry sequence — `_entry_sequence_active = true`, boss DORMANT.
	# Use the helper to fast-forward.
	room.complete_entry_sequence_for_test()
	assert_true(room.is_entry_sequence_completed())
	var boss: ArchiveSentinel = room.get_boss()
	assert_not_null(boss)
	assert_eq(
		boss.get_state(),
		ArchiveSentinel.STATE_IDLE_ACTIVE,
		"complete_entry_sequence_for_test fast-forwards through wake-anim to IDLE_ACTIVE"
	)


# ---- 7: ARENA_BOUNDS pin ----------------------------------------------


func test_arena_bounds_constant_is_1024x768() -> void:
	# Static contract — Uma §5.5 specifies ~32×24 tiles at 32 px/tile =
	# 1024×768 world units. If this drifts the camera continuous-scroll
	# bounds + the placeholder wall positions all drift in lockstep,
	# silently changing the boss-arena shape. The test pins the contract.
	assert_eq(
		Stratum2BossRoom.ARENA_BOUNDS,
		Rect2(0, 0, 1024, 768),
		"arena bounds = ~32×24 tiles (1024×768 world units) per Uma §5.5"
	)
	assert_eq(
		Stratum2BossRoom.PLINTH_POSITION,
		Vector2(512, 384),
		"plinth position = arena center"
	)


# ---- 7b: arena-zoom calibration (soak-round-2 "characters too big" fix) -


func test_arena_camera_zoom_constant_is_widest_allowed() -> void:
	# Static contract — the wider 1024×768 arena needs the camera zoomed OUT
	# vs the S1 viewport-native 480×270 default. 0.5 is CameraDirector's
	# MIN_NORMALIZED_ZOOM (widest view). If this drifts back toward 1.0 the
	# Sponsor "characters too big" regression re-opens. See ARENA_CAMERA_ZOOM
	# rationale in Stratum2BossRoom.gd.
	assert_eq(
		Stratum2BossRoom.ARENA_CAMERA_ZOOM,
		0.5,
		"arena camera zooms OUT to 0.5 normalized (widest allowed) for the 1024×768 arena"
	)


func test_engage_camera_requests_zoom_out_for_arena() -> void:
	# Behavioral pin — engaging the boss-room camera must zoom the
	# CameraDirector OUT to ARENA_CAMERA_ZOOM (not leave it at the 1.0 default
	# that renders the wide arena too tight). Drives the real CameraDirector
	# autoload via a player in the "player" group, matching production.
	var cam: Node = Engine.get_main_loop().root.get_node_or_null("CameraDirector")
	if cam == null or not cam.has_method("current_zoom"):
		pass_test("CameraDirector autoload absent in this GUT surface — skip behavioral pin")
		return
	var player: FakePlayerBody = FakePlayerBody.new()
	player.add_to_group("player")
	add_child_autofree(player)
	var room: Stratum2BossRoom = _make_room()
	await get_tree().process_frame  # drain deferred fixture pass (engages camera)
	assert_almost_eq(
		cam.current_zoom(),
		Stratum2BossRoom.ARENA_CAMERA_ZOOM,
		0.001,
		"boss-room engage zooms camera OUT to ARENA_CAMERA_ZOOM"
	)
	# Guard against the regression's exact shape: zoom must be < default 1.0.
	assert_lt(cam.current_zoom(), 1.0, "arena zoom is wider than the 480×270 default")


# ---- 8: boss death emits boss_defeated + stratum_exit_unlocked -----


func test_boss_death_emits_room_signals() -> void:
	var room: Stratum2BossRoom = _make_room()
	await get_tree().process_frame  # drain deferred fixture pass + entry auto-fire
	room.complete_entry_sequence_for_test()
	var boss: ArchiveSentinel = room.get_boss()
	# Boss should be combat-ready now.
	assert_eq(boss.get_state(), ArchiveSentinel.STATE_IDLE_ACTIVE)
	# Kill in two stages, draining the phase-transition window between them
	# (the phase-2 boundary is at 50% HP = 350 of the 700 archive_sentinel
	# baseline). Phase-transition rejects damage entirely, so we MUST drain
	# the 0.6 s window before applying the killing blow.
	watch_signals(room)
	boss.take_damage(350, Vector2.ZERO, null)  # 700 → 350 = phase 2 boundary
	boss._physics_process(ArchiveSentinel.PHASE_TRANSITION_DURATION + 0.01)
	boss.take_damage(350, Vector2.ZERO, null)  # 350 → 0 (fatal)
	assert_true(boss.is_dead(), "boss dies after second hit drains HP to 0")
	# Room handler subscribes to boss_died; should emit both room signals.
	assert_signal_emitted(room, "stratum_exit_unlocked", "stratum_exit_unlocked fires on boss death")
	assert_signal_emitted(room, "boss_defeated", "boss_defeated fires on boss death")
	assert_true(room.is_stratum_exit_unlocked())


# ---- 9: arena walls + floor scene topology --------------------------


func test_room_scene_carries_arena_walls() -> void:
	# Verify the .tscn scene authoring includes the four cardinal walls +
	# floor. A regression that drops a wall in the scene file would let
	# the player walk out of the arena mid-fight — caught here.
	var room: Stratum2BossRoom = _make_room()
	var wall_names: Array = ["WallNorth", "WallSouth", "WallWest", "WallEast"]
	for wname: String in wall_names:
		var w: Node = room.get_node_or_null(wname)
		assert_not_null(w, "scene has wall '%s'" % wname)
		assert_true(w is StaticBody2D, "wall '%s' is StaticBody2D" % wname)
		var has_shape: bool = false
		for c: Node in w.get_children():
			if c is CollisionShape2D:
				has_shape = true
		assert_true(has_shape, "wall '%s' has CollisionShape2D child" % wname)
	# Floor present (ColorRect at the standard near-black tone).
	var floor_node: Node = room.get_node_or_null("ArenaFloor")
	assert_not_null(floor_node, "scene has ArenaFloor")
	assert_true(floor_node is ColorRect, "ArenaFloor is ColorRect")


# ---- 10: BossNameplate reused from S1 + slides on entry complete (Stage 6) ----
#
# W3-T7 Stage 6 (ticket 86c9y7ygj): the Stage-5 `_spawn_boss_nameplate`
# no-op hook is now a real spawn reusing `res://scenes/ui/BossNameplate.tscn`
# (NOT a parallel S2 nameplate). The banner is spawned hidden in the deferred
# fixture pass; `_complete_entry_sequence` calls `show_for(boss)` to start the
# slide-in.


func test_boss_nameplate_spawns_in_deferred_fixture_pass() -> void:
	var room: Stratum2BossRoom = _make_room()
	# Pre-drain: deferred fixture pass has NOT landed; nameplate absent.
	assert_null(
		room.get_boss_nameplate(),
		"boss nameplate NOT spawned synchronously in _ready (deferred fixture pass)"
	)
	await get_tree().process_frame
	# Post-drain: nameplate spawned + parented under the room.
	var nameplate: Node = room.get_boss_nameplate()
	assert_not_null(nameplate, "Stage 6: BossNameplate spawned in deferred fixture pass")
	assert_eq(nameplate.get_parent(), room, "nameplate parented under the boss room (room lifecycle)")
	# Reuse-the-S1-banner contract: the spawned node is the BossNameplate class
	# (NOT a parallel S2-specific nameplate).
	assert_true(nameplate is BossNameplate, "Stage 6: reuses the S1 BossNameplate class, not a parallel one")
	# Hidden by default until show_for fires.
	assert_false(nameplate.is_shown(), "nameplate hidden until entry sequence completes")


func test_boss_nameplate_shows_on_entry_sequence_complete() -> void:
	var room: Stratum2BossRoom = _make_room()
	await get_tree().process_frame  # drain deferred fixture pass + entry auto-fire
	var nameplate: Node = room.get_boss_nameplate()
	assert_not_null(nameplate, "nameplate spawned")
	assert_false(nameplate.is_shown(), "nameplate hidden during entry sequence (Beats 1-4)")
	# Completing the entry sequence (Beat 4 → Beat 5 boundary) triggers the
	# slide-in via show_for(boss).
	room.complete_entry_sequence_for_test()
	assert_true(
		nameplate.is_shown(),
		"Stage 6: nameplate slides in on entry_sequence_completed (Uma boss-intro.md BI-07)"
	)


func test_boss_nameplate_opt_out_when_scene_path_empty() -> void:
	# The spawn guards on `boss_nameplate_scene_path == ""` so a test (or a
	# future config) can opt out cleanly without crashing the room boot.
	var packed: PackedScene = BOSS_ROOM_SCENE
	var room: Stratum2BossRoom = packed.instantiate()
	room.boss_nameplate_scene_path = ""
	add_child_autofree(room)
	await get_tree().process_frame
	assert_null(
		room.get_boss_nameplate(),
		"empty boss_nameplate_scene_path opts out of the nameplate spawn cleanly"
	)
	# Completing the entry sequence must NOT crash with no nameplate present.
	room.complete_entry_sequence_for_test()
	assert_true(room.is_entry_sequence_completed(), "entry sequence completes fine without a nameplate")
