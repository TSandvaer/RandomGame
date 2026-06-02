extends GutTest
## Paired GUT tests for the S2 room-by-room traversal in the production play
## loop (ticket `86ca1m0ph`, Option A — procgen via FloorAssembler).
##
## What this pins:
##   1. **Regression guard** — descend no longer reloads S1 Room01 as a
##      placeholder. `_on_descend_restart_run` must NOT call
##      `_load_room_at_index(0)`; it must route through `_begin_stratum_2`.
##      This is the single test that catches a regression back to the
##      Room01-reload placeholder (the bug this ticket closes).
##   2. **Reachability** — driving the descend handler from a bare-instance
##      Main reaches the authored S2 boss room (`S2_BOSS_ROOM_INDEX`), not
##      S1 Room01.
##   3. **Discovery + save seam** — the S2 zones are marked discovered on the
##      Player during traversal (composes against W2-T5 save round-trip).
##   4. **Structural wiring** — the traversal calls the FloorAssembler API +
##      the S2 audio entry trigger + the camera-scroll API.
##
## **Content note (updated for ticket 86ca3amyb — chunk-clear gate).** The S2
## chunk `.tres` HAVE authored `scene_path` + declarative `mob_spawns`. As of
## #392 mobs spawn; as of THIS ticket the zone-advance is GATED on those mobs
## being cleared (`_s2_mobs_remaining == 0`). So a freshly-descended floor HOLDS
## at z1 with live mobs — it does NOT auto-advance to the boss room. The
## reach-boss-room test below therefore DEFEATS the spawned mobs to drive the
## traversal, rather than relying on a free auto-advance. The traversal WIRING +
## terminal reachability are what these tests assert.

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const MAIN_SOURCE_PATH: String = "res://scenes/Main.gd"
const DESCEND_SOURCE_PATH: String = "res://scripts/screens/DescendScreen.gd"

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- Source-scan structural tests ------------------------------------


func _read_source(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(f, "could not open source %s" % path)
	if f == null:
		return ""
	var src: String = f.get_as_text()
	f.close()
	return src


func _func_body(src: String, fn_decl: String) -> String:
	var fn_idx: int = src.find(fn_decl)
	if fn_idx < 0:
		return ""
	var next_fn: int = src.find("\nfunc ", fn_idx + 1)
	if next_fn > fn_idx:
		return src.substr(fn_idx, next_fn - fn_idx)
	return src.substr(fn_idx)


## REGRESSION GUARD (ticket 86ca1m0ph). The descend handler must NOT reload
## S1 Room01 as a placeholder. If a future refactor reintroduces
## `_load_room_at_index(0)` inside `_on_descend_restart_run`, this fails.
func test_descend_does_not_reload_s1_room01() -> void:
	var src: String = _read_source(MAIN_SOURCE_PATH)
	var body: String = _func_body(src, "func _on_descend_restart_run")
	assert_ne(body, "", "expected _on_descend_restart_run")
	assert_eq(
		body.find("_load_room_at_index(0)"),
		-1,
		"REGRESSION: descend must NOT reload Room01 — route through _begin_stratum_2"
	)
	assert_gt(body.find("_begin_stratum_2()"), 0, "descend must call _begin_stratum_2()")


## The traversal must consume the FloorAssembler API (Option A — procgen).
func test_traversal_consumes_floor_assembler() -> void:
	var src: String = _read_source(MAIN_SOURCE_PATH)
	assert_gt(src.find("FloorAssembler.derive_stratum_seed"), 0, "must derive stratum seed")
	assert_gt(src.find("FloorAssembler.derive_zone_seed"), 0, "must derive zone seed")
	assert_gt(src.find("assemble_floor("), 0, "must call assemble_floor")


## The traversal must fire the S1->S2 audio entry trigger.
func test_traversal_fires_s2_audio_entry() -> void:
	var src: String = _read_source(MAIN_SOURCE_PATH)
	var body: String = _func_body(src, "func _begin_stratum_2")
	assert_ne(body, "", "expected _begin_stratum_2")
	assert_gt(body.find("play_stratum2_entry"), 0, "must fire play_stratum2_entry")


## The assembled-floor render must engage the continuous-scroll camera API.
func test_traversal_engages_camera_for_floor() -> void:
	var src: String = _read_source(MAIN_SOURCE_PATH)
	var body: String = _func_body(src, "func _engage_camera_for_assembled_floor")
	assert_ne(body, "", "expected _engage_camera_for_assembled_floor helper")
	assert_gt(body.find("follow_target"), 0, "must call follow_target")
	assert_gt(body.find("set_world_bounds"), 0, "must call set_world_bounds")


## The boss-room terminal hands off to the authored Stratum2BossRoom at index 9.
func test_traversal_terminal_loads_boss_room() -> void:
	var src: String = _read_source(MAIN_SOURCE_PATH)
	var body: String = _func_body(src, "func _enter_s2_boss_room")
	assert_ne(body, "", "expected _enter_s2_boss_room")
	assert_gt(
		body.find("_load_room_at_index(S2_BOSS_ROOM_INDEX)"),
		0,
		"boss-room terminal must load S2_BOSS_ROOM_INDEX"
	)


## DescendScreen subtitle must no longer be the "Coming in M2" placeholder.
func test_descend_subtitle_off_coming_in_m2() -> void:
	var src: String = _read_source(DESCEND_SOURCE_PATH)
	var subtitle_idx: int = src.find("const SUBTITLE_TEXT")
	assert_gt(subtitle_idx, 0, "expected SUBTITLE_TEXT const")
	var line_end: int = src.find("\n", subtitle_idx)
	var line: String = src.substr(subtitle_idx, line_end - subtitle_idx)
	assert_eq(line.find("Coming in M2"), -1, "subtitle must NOT say 'Coming in M2'")


# ---- Behavioural bare-instance Main tests -----------------------------


## Lethal-damage every currently-live S2 mob (drives the standard _die →
## mob_died chain). Returns the count killed this call. The gate connects
## mob_died CONNECT_DEFERRED, so the caller must drain a frame for the
## `_s2_mobs_remaining` decrement to land.
func _kill_live_s2_mobs(main: Node) -> int:
	var mobs: Array = main.get_s2_mobs()
	var killed: int = 0
	for mob: Node in mobs:
		if is_instance_valid(mob) and mob.has_method("take_damage"):
			mob.take_damage(99999, Vector2.ZERO, null)
			killed += 1
	return killed


## Drive the production descend path on a bare-instance Main and assert that —
## with the chunk-clear gate (86ca3amyb) — the floor HOLDS at z1 with live mobs
## and reaches the authored S2 boss room ONLY after the player clears each zone.
## This is the room-by-room pacing the headline #391 traversal set up.
func test_descend_reaches_s2_boss_room_after_clearing_each_zone() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(main.get_current_room_index(), 0, "boots into Room 01")

	main.force_descend_for_test()
	await get_tree().process_frame
	var screen: Node = main.get_descend_screen()
	assert_not_null(screen, "force_descend must mount the DescendScreen")
	if screen == null:
		main.queue_free()
		return
	assert_true(screen.has_method("press_return_for_test"), "screen exposes press_return_for_test")
	screen.press_return_for_test()

	# z1 is now LIVE with mobs — the gate must HOLD. Drain several frames and
	# assert we have NOT advanced to the boss room (the gate is doing its job).
	for _i: int in range(4):
		await get_tree().process_frame
	assert_gt(main.s2_mobs_remaining(), 0, "z1 entry hall spawns mobs (gate has something to hold on)")
	assert_ne(
		main.get_current_room_index(),
		main.S2_BOSS_ROOM_INDEX,
		"GATE: must NOT reach boss room while z1 mobs are alive (no premature advance)"
	)

	# Clear each zone in turn. Each kill-all + frame-drain advances one zone;
	# the next zone loads with its own mobs (until z3 clears → boss-room load).
	# Bound the loop generously (3 authored zones + margin) to avoid an infinite
	# loop if a regression breaks the advance.
	var hops: int = 0
	while main.get_current_room_index() != main.S2_BOSS_ROOM_INDEX and hops < 12:
		_kill_live_s2_mobs(main)
		# Drain enough frames for the deferred decrement, the deferred advance,
		# and the next zone's synchronous render + spawn.
		for _j: int in range(4):
			await get_tree().process_frame
		hops += 1

	assert_eq(
		main.get_current_room_index(),
		main.S2_BOSS_ROOM_INDEX,
		"clearing every zone must reach the authored S2 boss room (index 9)"
	)
	assert_ne(main.get_current_room_index(), 0, "descend must NOT end on S1 Room01")
	main.queue_free()


## Premature-advance / no-skipped-zone guard. After descend, defeating NONE of
## the z1 mobs must keep the floor at z1 indefinitely (the gate never opens). A
## regression to unconditional auto-advance would whisk past z1 → boss room with
## mobs still alive — this asserts the floor stays put with mobs remaining.
func test_descend_does_not_advance_while_mobs_alive() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main.force_descend_for_test()
	await get_tree().process_frame
	var screen: Node = main.get_descend_screen()
	if screen == null:
		main.queue_free()
		return
	screen.press_return_for_test()

	var z1_mobs: int = main.s2_mobs_remaining()
	assert_gt(z1_mobs, 0, "z1 must spawn mobs for the gate to hold")
	# Drain many frames WITHOUT killing anything — the gate must hold the floor.
	for _i: int in range(10):
		await get_tree().process_frame
	assert_eq(
		main.s2_mobs_remaining(),
		z1_mobs,
		"no mob died → counter unchanged (no spurious decrement)"
	)
	assert_ne(
		main.get_current_room_index(),
		main.S2_BOSS_ROOM_INDEX,
		"GATE: floor must NOT advance to boss room while mobs are alive"
	)
	main.queue_free()


## Traversal marks the S2 zones discovered on the Player (save round-trip seam).
func test_descend_discovers_s2_zones() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var player: Node = main.get_player()
	assert_not_null(player, "Main must spawn a player")
	if player == null or not player.has_method("to_save_dict"):
		main.queue_free()
		return

	main.force_descend_for_test()
	await get_tree().process_frame
	var screen: Node = main.get_descend_screen()
	if screen != null and screen.has_method("press_return_for_test"):
		screen.press_return_for_test()
	for _i: int in range(8):
		await get_tree().process_frame

	# The first authored S2 zone (entry hall) must be discovered by traversal.
	# Query via Player.to_save_dict()["discovered_zones"] — the confirmed public
	# surface that `mark_zone_discovered` writes into (Player.discovered_zones
	# Dictionary, serialised by to_save_dict). Keys are StringName-shaped.
	var save_dict: Dictionary = player.to_save_dict()
	var discovered: Dictionary = save_dict.get("discovered_zones", {})
	var found: bool = discovered.has(&"s2_z1_entry_hall") or discovered.has("s2_z1_entry_hall")
	assert_true(found, "S2 traversal must discover s2_z1_entry_hall (entry zone)")
	main.queue_free()
