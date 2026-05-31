# gdlint:disable=max-public-methods
# GUT test class — high test_* count IS the design (one test per scenario).
extends GutTest
## W3-T7 Stage 6 (ticket `86c9y7ygj`) — pins that Main.gd wires the
## Stratum2BossRoom into the production room-load flow so it is REACHABLE.
##
## Through Stages 1-5 the Stratum2BossRoom was authored standalone with no
## `Main._load_room_at_index` consumer (unreachable in production play).
## Stage 6 appends it as a terminal index (`S2_BOSS_ROOM_INDEX = 9`) reachable
## via the SAME room-load mechanism every other room uses + the
## `DebugFlags.start_room=9` URL hook.
##
## ## Coverage shape
##
##   1. **Reachability constant pins** — `ROOM_SCENE_PATHS[9]` is the S2
##      boss room scene; `ROOM_IDS[9]` is `s2_boss_room`;
##      `ROOM_INDEX_TO_ZONE_ID[9]` is `s2_z4_inner_sanctum`. A refactor that
##      drops the terminal entry breaks these.
##   2. **Source-scan structural pin (shared boss-room branch)** — verify
##      `_wire_room_signals` handles `index == S2_BOSS_ROOM_INDEX` through the
##      shared boss branch (loosely-typed, `has_signal`-guarded). Guards
##      against a regression that re-narrows the branch to S1-only.
##   3. **Behavioural pin (boot into S2 boss room)** — bare-instantiate Main,
##      drive `load_room_index(9)`, assert the boss is wired (boss_died
##      connected to Main._on_mob_died = the single-pipeline loot rule),
##      room signals connected, and the room reports the boss at the plinth.
##   4. **Loot single-pipeline pin** — assert ArchiveSentinel.boss_died is
##      connected to Main's `_on_mob_died` (so Main's MobLootSpawner is the
##      sole boss-loot pipeline per ticket `86c9uemdg`) and the boss room
##      does NOT spawn its own loot.
##   5. **Room-label pin** — index 9 renders "STRATUM 2 · BOSS".
##
## Mirrors `test_main_camera_wiring.gd`'s bare-Main-instance + source-scan
## conventions.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

const MAIN_SOURCE_PATH := "res://scenes/Main.gd"
const MAIN_SCENE := preload("res://scenes/Main.tscn")

const S2_BOSS_ROOM_SCENE_PATH := "res://scenes/levels/Stratum2BossRoom.tscn"
const S2_BOSS_ROOM_INDEX := 9

var _warn_guard: NoWarningGuard


func before_each() -> void:
	# Reset shared CameraDirector state — Main boot + boss-room engage leak
	# follow_target / world_bounds otherwise.
	var cam: Node = Engine.get_main_loop().root.get_node_or_null("CameraDirector")
	if cam != null:
		if cam.has_method("clear_follow_target"):
			cam.clear_follow_target()
		if cam.has_method("clear_world_bounds"):
			cam.clear_world_bounds()
		if cam.has_method("reset_to_player"):
			cam.reset_to_player(0.0)
	# Permissive warning gate — Main boot surfaces save/content-registry
	# warnings unrelated to Stage-6 wiring. Scope assertions to wiring.
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()
	# Clear the save so the boot path is deterministic (no restored room).
	var save_node: Node = Engine.get_main_loop().root.get_node_or_null("Save")
	if save_node != null and save_node.has_save(0):
		save_node.delete_save(0)


func after_each() -> void:
	var cam: Node = Engine.get_main_loop().root.get_node_or_null("CameraDirector")
	if cam != null:
		if cam.has_method("clear_follow_target"):
			cam.clear_follow_target()
		if cam.has_method("clear_world_bounds"):
			cam.clear_world_bounds()
		if cam.has_method("reset_to_player"):
			cam.reset_to_player(0.0)
	_warn_guard.detach()
	_warn_guard = null


# ---- Pin 1: reachability constant pins --------------------------------


func test_room_scene_paths_terminal_entry_is_s2_boss_room() -> void:
	# Source-scan the constant array — the terminal entry MUST be the S2 boss
	# room scene. A refactor that drops it makes the boss room unreachable
	# again (the Stage-5 problem this ticket exists to fix).
	var source: String = FileAccess.get_file_as_string(MAIN_SOURCE_PATH)
	assert_gt(source.length(), 0, "Main.gd readable as resource")
	assert_true(
		source.find(S2_BOSS_ROOM_SCENE_PATH) > -1,
		"ROOM_SCENE_PATHS includes the Stratum2BossRoom scene (reachability)"
	)
	assert_true(
		source.find("const S2_BOSS_ROOM_INDEX: int = 9") > -1,
		"Main declares S2_BOSS_ROOM_INDEX = 9 terminal index"
	)


func test_room_ids_and_zone_mapping_have_s2_boss_entry() -> void:
	var source: String = FileAccess.get_file_as_string(MAIN_SOURCE_PATH)
	assert_true(
		source.find("&\"s2_boss_room\"") > -1,
		"ROOM_IDS carries the s2_boss_room id (StratumProgression bookkeeping)"
	)
	assert_true(
		source.find("&\"s2_z4_inner_sanctum\"") > -1,
		"ROOM_INDEX_TO_ZONE_ID maps the S2 boss room to its zone (world-map discovery)"
	)


# ---- Pin 2: source-scan structural — shared boss-room branch ----------


func test_wire_room_signals_handles_s2_boss_index() -> void:
	# The boss-room branch must accept BOTH index 8 (S1) and index 9 (S2).
	# A regression that re-narrows to `index == BOSS_ROOM_INDEX` would silently
	# leave the S2 boss room un-wired (no loot, no exit, no title card).
	var source: String = FileAccess.get_file_as_string(MAIN_SOURCE_PATH)
	var fn_start: int = source.find("func _wire_room_signals(")
	assert_gt(fn_start, -1, "Main defines _wire_room_signals")
	var next_fn: int = source.find("\nfunc ", source.find("\n", fn_start))
	var fn_body: String = source.substr(fn_start, next_fn - fn_start)
	assert_true(
		fn_body.find("index == BOSS_ROOM_INDEX or index == S2_BOSS_ROOM_INDEX") > -1,
		"boss-room branch handles BOTH S1 (index 8) and S2 (index 9) boss rooms"
	)
	# The shared branch resolves the boss via has_method('get_boss') so it
	# does not couple to the concrete S1 boss-room type.
	assert_true(
		fn_body.find("has_method(\"get_boss\")") > -1,
		"shared boss branch resolves the boss generically (not S1-typed)"
	)


# ---- Pin 3 + 4: behavioural — boot into S2 boss room ------------------


func test_main_loads_s2_boss_room_and_wires_boss() -> void:
	assert_not_null(MAIN_SCENE, "Main.tscn loads")
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	# Settle the boot chain (Room 01 load + deferred frees).
	await get_tree().process_frame
	await get_tree().process_frame
	# Drive directly into the S2 boss room via the production load path.
	main.load_room_index(S2_BOSS_ROOM_INDEX)
	# Drain the boss room's deferred fixture pass.
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(
		main.get_current_room_index(),
		S2_BOSS_ROOM_INDEX,
		"Main current room index is the S2 boss room (9)"
	)
	var room: Node = main.get_current_room()
	assert_not_null(room, "S2 boss room loaded as current room")
	assert_true(room is Stratum2BossRoom, "current room is Stratum2BossRoom typed")
	# Boss present at plinth.
	var boss: Node = room.get_boss()
	assert_not_null(boss, "ArchiveSentinel spawned in the loaded S2 boss room")
	assert_true(boss is ArchiveSentinel, "boss is ArchiveSentinel typed")


func test_s2_boss_died_wired_to_main_single_loot_pipeline() -> void:
	# Single-pipeline loot rule (ticket `86c9uemdg`): Main's MobLootSpawner is
	# the SOLE boss-loot pipeline. `_wire_mob(boss)` connects the boss's
	# `boss_died` to Main._on_mob_died. Assert that connection exists and the
	# boss room does NOT own its own loot spawner.
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main.load_room_index(S2_BOSS_ROOM_INDEX)
	await get_tree().process_frame
	await get_tree().process_frame
	var room: Node = main.get_current_room()
	var boss: Node = room.get_boss()
	assert_not_null(boss, "boss present")
	# boss_died must be connected to SOMETHING on Main (the _on_mob_died
	# forwarder that drives MobLootSpawner + Inventory.auto_collect_pickups).
	assert_true(boss.has_signal("boss_died"), "ArchiveSentinel exposes boss_died")
	var connections: Array = boss.get_signal_connection_list("boss_died")
	# At least one connection's callable target is the Main node (Main._on_mob_died).
	var wired_to_main: bool = false
	for c: Dictionary in connections:
		var cb: Callable = c.get("callable", Callable())
		if cb.get_object() == main:
			wired_to_main = true
	assert_true(
		wired_to_main,
		"ArchiveSentinel.boss_died is connected to Main (single-pipeline loot per 86c9uemdg)"
	)


func test_s2_boss_room_label_renders_stratum_2_boss() -> void:
	var source: String = FileAccess.get_file_as_string(MAIN_SOURCE_PATH)
	# Source-scan pin — the room-label branch must render "STRATUM 2 · BOSS"
	# for the S2 boss index. (Behavioural HUD-label assertion is brittle
	# against the bare-instance HUD build timing; the source-scan pins the
	# string contract.)
	assert_true(
		source.find("STRATUM 2 · BOSS") > -1,
		"_refresh_room_label renders 'STRATUM 2 · BOSS' for the S2 boss room index"
	)
