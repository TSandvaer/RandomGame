extends GutTest
## Paired GUT tests for the S2 mob-spawn runtime consumer (ticket `86ca3amgt`,
## OOS gap (a) from PR #391). `Main._render_assembled_floor` now reads each
## placed chunk's `LevelChunkDef.mob_spawns` and instantiates a live mob per
## `MobSpawnPoint` at its authored tile position (converted to world pixels +
## chunk placement offset), resolving `mob_id` via the MobRegistry.
##
## What this pins (the BUG CLASS, not just the instance — per testing bar):
##   1. **Spawn-count contract** — rendering an S2 assembled floor instantiates
##      EXACTLY the number of mobs declared across all placed chunks' mob_spawns
##      (N spawns → N live mob nodes). A "> 0" assert is INSUFFICIENT (would pass
##      under a dual-spawn / off-by-one regression — see combat-architecture.md
##      § dual-spawn silent-killer); we assert the exact sum.
##   2. **Registry resolution** — every spawned mob has a non-null `mob_def`
##      applied (so the kill → mob_died → XP/loot pipeline does not silently
##      no-op) and is a combat-functional node (`take_damage` present → hookable
##      into the standard _die chain).
##   3. **Placement** — each mob's world position equals
##      `placed.position_px + position_tiles × tile_size_px` (the authored spot).
##   4. **No USER WARNING** — the spawn path is clean (NoWarningGuard).
##   5. **Structural wiring guard** — `_render_assembled_floor` calls
##      `_spawn_assembled_floor_mobs` and does NOT gate the zone advance on the
##      mob count (the chunk-clear GATE is the SEPARATE sibling ticket
##      `86ca3amyb` — this PR must NOT change auto-advance behaviour).
##
## **Why behavioural-via-Main + the real z1 entry hall floor.** The spawn helper
## is private and depends on `_s2_floor_container`; driving it through the
## production render path (descend → _begin_stratum_2 → _load_s2_zone(0)) is the
## real integration surface. z1 (`s2_z1_entry_hall`) deterministically carries
## ≥1 sunken_scholar (s2_room01.tres mob_spawns); the count assertion derives the
## expected total from the live chunk defs so it is exact, not hard-coded.
##
## Per `test-conventions.md` § "preload of .tres can bind to null at parse-time"
## — route .tres loads through runtime `load(...)`, not top-of-file `preload`.

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const MAIN_SOURCE_PATH: String = "res://scenes/Main.gd"
const FloorAssemblerScript: Script = preload("res://scripts/levels/FloorAssembler.gd")

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


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


## Compute the expected total mob count for the FIRST S2 zone (entry hall) by
## assembling it independently and summing every placed chunk's mob_spawns. The
## seed must match Main's: `derive_zone_seed(derive_stratum_seed(0, "s2"), zone_id)`.
## `_resolve_s2_world_seed` returns 0 when Save has no world_seed (current HEAD).
func _expected_z1_mob_total() -> int:
	var zone: ZoneDef = load("res://resources/level/zones/s2_z1_entry_hall.tres")
	assert_not_null(zone, "s2_z1_entry_hall.tres must load")
	if zone == null:
		return -1
	var asm: FloorAssembler = FloorAssemblerScript.new()
	var stratum_seed: int = FloorAssembler.derive_stratum_seed(0, &"s2")
	var zone_seed: int = FloorAssembler.derive_zone_seed(stratum_seed, zone.zone_id)
	var floor: AssembledFloor = asm.assemble_floor(zone, zone_seed)
	var total: int = 0
	for placed: PlacedChunk in floor.placed_chunks:
		var chunk: LevelChunkDef = load(
			"res://resources/level_chunks/%s.tres" % String(placed.chunk_id)
		)
		if chunk != null:
			total += chunk.mob_spawns.size()
	return total


# ---- Structural wiring guards ----------------------------------------


## Wiring guard — the render must consume mob_spawns via the spawn helper.
func test_render_spawns_mobs_from_assembled_floor() -> void:
	var src: String = _read_source(MAIN_SOURCE_PATH)
	var body: String = _func_body(src, "func _render_assembled_floor")
	assert_ne(body, "", "expected _render_assembled_floor")
	assert_gt(
		body.find("_spawn_assembled_floor_mobs("),
		0,
		"render must call _spawn_assembled_floor_mobs to consume mob_spawns"
	)


## REGRESSION GUARD (OOS boundary) — this PR makes mobs EXIST but must NOT add
## the chunk-clear gate (sibling ticket 86ca3amyb). The advance must stay
## unconditional (`call_deferred("_advance_s2_zone")`); it must NOT be gated on
## `_s2_mobs_remaining == 0` in THIS PR. If a future PR adds the gate here, this
## guard should be updated alongside that ticket — until then it pins the OOS.
func test_render_does_not_gate_advance_on_mob_count() -> void:
	var src: String = _read_source(MAIN_SOURCE_PATH)
	var advance_body: String = _func_body(src, "func _on_s2_zone_advance_ready")
	assert_ne(advance_body, "", "expected _on_s2_zone_advance_ready")
	assert_eq(
		advance_body.find("_s2_mobs_remaining"),
		-1,
		"OOS: advance hook must NOT gate on mob count in this PR (gate = ticket 86ca3amyb)"
	)


## mob_id resolution must route through MobRegistry with an explicit unknown-id
## skip (no silent crash) — the spawn helper warns + continues.
func test_unknown_mob_id_is_warned_and_skipped_not_crashed() -> void:
	var src: String = _read_source(MAIN_SOURCE_PATH)
	var body: String = _func_body(src, "func _spawn_one_chunk_mob")
	assert_ne(body, "", "expected _spawn_one_chunk_mob")
	assert_gt(body.find("has_mob("), 0, "must gate on registry.has_mob")
	assert_gt(body.find("WarningBus.warn"), 0, "unknown mob_id must warn (not silent)")
	assert_gt(body.find("unknown mob_id"), 0, "warning must name the unknown-id case")


# ---- Behavioural — real z1 entry-hall floor --------------------------


## Drive the production descend path on a bare-instance Main, capture the FIRST
## S2 zone's mob state BEFORE the deferred auto-advance tears it down, and assert
## the spawn-count contract + registry resolution + placement.
func test_z1_render_spawns_expected_mob_count() -> void:
	var expected: int = _expected_z1_mob_total()
	assert_gt(expected, 0, "z1 entry hall must declare ≥1 mob spawn (sunken_scholar)")

	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame

	main.force_descend_for_test()
	await get_tree().process_frame
	var screen: Node = main.get_descend_screen()
	assert_not_null(screen, "force_descend must mount the DescendScreen")
	if screen == null:
		main.queue_free()
		return
	# press_return_for_test → restart_run → _begin_stratum_2 → _load_s2_zone(0)
	# runs SYNCHRONOUSLY. The auto-advance to z2 is a call_deferred, so the z1
	# floor + its mobs are live until we drain a frame. Inspect NOW, before drain.
	screen.press_return_for_test()

	# EXACT count — N spawns → N live mob nodes. "> 0" is insufficient (would
	# pass a dual-spawn regression); we pin the exact authored total.
	assert_eq(
		main.s2_mobs_remaining(),
		expected,
		"z1 must spawn exactly the declared mob_spawns total"
	)
	var mobs: Array = main.get_s2_mobs()
	assert_eq(mobs.size(), expected, "get_s2_mobs() size matches the spawn count")

	# Registry resolution + combat-functionality: every mob has a non-null
	# mob_def (kill→loot/XP pipeline payload) and is hittable (take_damage).
	for mob: Node in mobs:
		assert_true(is_instance_valid(mob), "spawned mob is a valid live node")
		assert_true("mob_def" in mob, "spawned mob exposes mob_def")
		if "mob_def" in mob:
			assert_not_null(mob.mob_def, "mob_def applied (non-null) for combat/loot pipeline")
		assert_true(
			mob.has_method("take_damage"),
			"spawned mob is combat-functional (take_damage → standard _die chain)"
		)

	main.queue_free()


## Placement — each spawned mob sits at its chunk placement + authored tile
## offset. We re-derive the expected world positions from the assembled floor +
## chunk defs and assert the live mobs occupy that set (order-independent).
func test_z1_mob_placement_matches_authored_tiles() -> void:
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

	# Re-derive the authored world positions independently.
	var zone: ZoneDef = load("res://resources/level/zones/s2_z1_entry_hall.tres")
	var asm: FloorAssembler = FloorAssemblerScript.new()
	var stratum_seed: int = FloorAssembler.derive_stratum_seed(0, &"s2")
	var zone_seed: int = FloorAssembler.derive_zone_seed(stratum_seed, zone.zone_id)
	var floor: AssembledFloor = asm.assemble_floor(zone, zone_seed)
	var expected_positions: Array[Vector2] = []
	for placed: PlacedChunk in floor.placed_chunks:
		var chunk: LevelChunkDef = load(
			"res://resources/level_chunks/%s.tres" % String(placed.chunk_id)
		)
		if chunk == null:
			continue
		for spawn: MobSpawnPoint in chunk.mob_spawns:
			var local_px := Vector2(spawn.position_tiles * chunk.tile_size_px)
			expected_positions.append(placed.position_px + local_px)

	var mobs: Array = main.get_s2_mobs()
	assert_eq(mobs.size(), expected_positions.size(), "mob count matches expected positions")
	for mob: Node in mobs:
		if not (mob is Node2D):
			continue
		var pos: Vector2 = (mob as Node2D).position
		var matched: bool = false
		for ep: Vector2 in expected_positions:
			if pos.is_equal_approx(ep):
				matched = true
				break
		assert_true(matched, "mob at %s matches an authored spawn position" % str(pos))

	main.queue_free()
