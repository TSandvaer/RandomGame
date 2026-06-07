extends GutTest
## S1 assembled-floor NAVIGABILITY GATE — grunt-radius-expanded BFS (ticket
## `86ca5errv`, the keystone retrofit's acceptance gate per Priya scope §3 T6
## navigability discipline + the #417 wedge lesson).
##
## **The bug class this catches.** When the assembler composes chunks into a
## floor, a navigability regression can take two shapes:
##   1. **Chunk-mating gap** — two consecutive chunks fail to abut edge-to-edge,
##      leaving a non-walkable gap a chaser can't cross (the floor splits into
##      disconnected islands; mobs behind the gap can never reach the player).
##   2. **Grunt-radius wedge** (the #417 lesson, Drew's W2-T3-era finding) — a
##      solid obstacle protruding into a lane is passable by a zero-radius point
##      but WEDGES a chaser whose body has a real collision radius (Grunt = 12 px).
##      A 1-px-aisle BFS passes; a grunt-radius-EXPANDED BFS catches it.
##
## **The gate.** Build a coarse occupancy grid over the assembled floor's
## bounding box: a cell is WALL if it lies outside every placed chunk's rect
## (inter-chunk gaps + the area beyond the floor). Expand walls by the Grunt body
## radius (12 px → ceil to whole cells) so the BFS walks the space a real chaser's
## CENTER can occupy, NOT a zero-radius point. Then BFS from the player-spawn cell
## and assert EVERY mob-spawn cell is reachable.
##
## **Foundation-scope note (honest).** The current S1 chunks render the
## placeholder `s1_room01_chunk.tscn` geometry shell — there is no solid-prop
## occupancy AUTHORED INTO THE CHUNK DEF DATA yet (full yard content is the
## downstream Drew ticket). So today this gate primarily proves shape (1)
## (contiguous mating → single connected component) + the grunt-radius BFS
## INFRASTRUCTURE. When Drew authors solid-prop yard chunks that declare
## occupancy, the SAME gate consumes that occupancy and catches shape (2)
## regressions without modification — that is the load-bearing reason it is built
## now, against the keystone, rather than deferred.

const FloorAssemblerScript: Script = preload("res://scripts/levels/FloorAssembler.gd")
const ZoneDefScript: Script = preload("res://resources/level/ZoneDef.gd")
const LevelChunkDefScript: Script = preload("res://scripts/levels/LevelChunkDef.gd")

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

## Grunt body collision radius (px) — mirrored from `scenes/mobs/Grunt.tscn`
## CircleShape2D radius = 12.0. The BFS expands walls by this so a chaser's
## CENTER, not a zero-radius point, drives reachability. If the grunt scene's
## radius changes, update here (a single-source mirror, same posture as
## `mouse-facing.ts`'s MOUSE_FACING_DEADZONE_PX mirror).
const GRUNT_BODY_RADIUS_PX: float = 12.0

## BFS grid cell size (px). 16 px = half a 32-px chunk tile — fine enough to
## resolve a grunt-radius wedge (12 px ≈ 1 cell of expansion) without an
## explosive cell count over a ~9-chunk floor.
const CELL_PX: float = 16.0

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# preload of s1_z1_outer_cloister.tres binds to null (test-conventions.md §
# "preload of .tres can bind to null") — route through runtime load().
func _load_outer_cloister_zone() -> ZoneDef:
	return load("res://resources/level/zones/s1_z1_outer_cloister.tres")


func _resolve_chunk_def(chunk_id: StringName) -> LevelChunkDef:
	var path: String = "res://resources/level_chunks/%s.tres" % String(chunk_id)
	var res: Resource = load(path)
	if res is LevelChunkDef:
		return res as LevelChunkDef
	return null


# -----------------------------------------------------------------------
# BFS navigability machinery
# -----------------------------------------------------------------------


## Build a walkability grid over the assembled floor. Returns a Dictionary:
##   { "cols": int, "rows": int, "walk": PackedByteArray (1 = walkable) }
## A cell is initially walkable iff its center lies inside SOME placed chunk's
## rect. Then walls are dilated by the grunt radius (any walkable cell adjacent
## — within `radius_cells` — to a wall becomes wall) so the BFS reflects a
## chaser's body, not a point. Placed-chunk occupancy is read from the assembled
## floor + each chunk def's size (the data the assembler produced).
func _build_walk_grid(assembled: AssembledFloor) -> Dictionary:
	var bounds: Rect2 = assembled.bounding_box_px
	var cols: int = int(ceil(bounds.size.x / CELL_PX))
	var rows: int = int(ceil(bounds.size.y / CELL_PX))
	var walk: PackedByteArray = PackedByteArray()
	walk.resize(cols * rows)

	# Pass 1 — a cell is walkable iff its center is inside some placed chunk rect.
	for r: int in range(rows):
		for c: int in range(cols):
			var center := Vector2(
				bounds.position.x + (float(c) + 0.5) * CELL_PX,
				bounds.position.y + (float(r) + 0.5) * CELL_PX
			)
			var inside: bool = false
			for placed: PlacedChunk in assembled.placed_chunks:
				var rect := Rect2(placed.position_px, Vector2(placed.size_px))
				if rect.has_point(center):
					inside = true
					break
			walk[r * cols + c] = 1 if inside else 0

	# Pass 2 — dilate walls by the grunt radius. A walkable cell within
	# `radius_cells` of any wall (or the grid edge) becomes wall, so the BFS only
	# traverses cells a grunt's CENTER can legally occupy. ceil(12/16) = 1 cell.
	var radius_cells: int = int(ceil(GRUNT_BODY_RADIUS_PX / CELL_PX))
	var dilated: PackedByteArray = walk.duplicate()
	for r: int in range(rows):
		for c: int in range(cols):
			if walk[r * cols + c] == 0:
				continue
			var blocked: bool = false
			for dr: int in range(-radius_cells, radius_cells + 1):
				for dc: int in range(-radius_cells, radius_cells + 1):
					var nr: int = r + dr
					var nc: int = c + dc
					if nr < 0 or nr >= rows or nc < 0 or nc >= cols:
						blocked = true  # grid edge counts as wall (off-floor)
						break
					if walk[nr * cols + nc] == 0:
						blocked = true
						break
				if blocked:
					break
			if blocked:
				dilated[r * cols + c] = 0
	return {"cols": cols, "rows": rows, "walk": dilated}


## Convert a world position to a grid cell (col, row). Clamped to grid range.
func _world_to_cell(world: Vector2, assembled: AssembledFloor, grid: Dictionary) -> Vector2i:
	var bounds: Rect2 = assembled.bounding_box_px
	var c: int = int(floor((world.x - bounds.position.x) / CELL_PX))
	var r: int = int(floor((world.y - bounds.position.y) / CELL_PX))
	c = clampi(c, 0, int(grid["cols"]) - 1)
	r = clampi(r, 0, int(grid["rows"]) - 1)
	return Vector2i(c, r)


## Nearest walkable cell to `start` (BFS outward) — handles a spawn/player point
## that lands on a dilated-wall cell (e.g. exactly on a seam). Returns (-1,-1) if
## no walkable cell exists at all (degenerate floor).
func _nearest_walkable(start: Vector2i, grid: Dictionary) -> Vector2i:
	var cols: int = int(grid["cols"])
	var rows: int = int(grid["rows"])
	var walk: PackedByteArray = grid["walk"]
	if walk[start.y * cols + start.x] == 1:
		return start
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if n.x < 0 or n.x >= cols or n.y < 0 or n.y >= rows:
				continue
			if seen.has(n):
				continue
			seen[n] = true
			if walk[n.y * cols + n.x] == 1:
				return n
			queue.append(n)
	return Vector2i(-1, -1)


## BFS reachable set from `start` cell over walkable cells. Returns a Dictionary
## set of reachable Vector2i cells.
func _reachable_from(start: Vector2i, grid: Dictionary) -> Dictionary:
	var cols: int = int(grid["cols"])
	var rows: int = int(grid["rows"])
	var walk: PackedByteArray = grid["walk"]
	var seen: Dictionary = {}
	if walk[start.y * cols + start.x] != 1:
		return seen
	seen[start] = true
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if n.x < 0 or n.x >= cols or n.y < 0 or n.y >= rows:
				continue
			if seen.has(n):
				continue
			if walk[n.y * cols + n.x] == 1:
				seen[n] = true
				queue.append(n)
	return seen


## Collect every mob-spawn world position from the assembled floor (chunk-local
## tile offset → world px, mirroring Main._spawn_one_chunk_mob's math).
func _mob_spawn_world_positions(assembled: AssembledFloor) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for placed: PlacedChunk in assembled.placed_chunks:
		var chunk_def: LevelChunkDef = _resolve_chunk_def(placed.chunk_id)
		if chunk_def == null:
			continue
		for spawn: MobSpawnPoint in chunk_def.mob_spawns:
			var local_px := Vector2(spawn.position_tiles * chunk_def.tile_size_px)
			out.append(placed.position_px + local_px)
	return out


# -----------------------------------------------------------------------
# Tests
# -----------------------------------------------------------------------


## THE NAVIGABILITY GATE. Assemble the authored S1 zone, build the grunt-radius-
## expanded walk grid, and assert every mob spawn is reachable from the player
## spawn. A chunk-mating gap or a grunt-radius wedge would leave a spawn in a
## disconnected component → this fails. Run across several seeds (procedural fill
## reorders the floor) so a seed-specific layout regression surfaces.
func test_every_mob_spawn_reachable_from_player_spawn_across_seeds() -> void:
	var zone: ZoneDef = _load_outer_cloister_zone()
	assert_not_null(zone, "s1_z1_outer_cloister.tres must load as ZoneDef")
	if zone == null:
		return

	var stratum_seed: int = FloorAssemblerScript.derive_stratum_seed(0, 1)
	# Several distinct zone-derived seeds → distinct procedural-fill layouts.
	var probe_seeds: Array[int] = []
	for s: int in [0, 1, 7, 42, 1337]:
		probe_seeds.append(FloorAssemblerScript.derive_zone_seed(stratum_seed + s, zone.zone_id))

	for seed: int in probe_seeds:
		var assembler: FloorAssembler = FloorAssemblerScript.new()
		var assembled: AssembledFloor = assembler.assemble_floor(zone, seed)
		assert_false(assembled.is_empty(), "seed %d: assembled floor must be non-empty" % seed)
		assert_true(
			assembled.is_well_mated(),
			"seed %d: floor must be well-mated (gaps fail navigability)" % seed
		)

		var grid: Dictionary = _build_walk_grid(assembled)

		# Player spawn = the S1 floor spawn (mirrors Main._s2_floor_spawn): left
		# edge + 24 px, vertically centred.
		var bounds: Rect2 = assembled.bounding_box_px
		var player_world := Vector2(
			bounds.position.x + 24.0, bounds.position.y + bounds.size.y * 0.5
		)
		var player_cell: Vector2i = _nearest_walkable(
			_world_to_cell(player_world, assembled, grid), grid
		)
		assert_ne(player_cell, Vector2i(-1, -1), "seed %d: player spawn has a walkable cell" % seed)
		if player_cell == Vector2i(-1, -1):
			continue

		var reachable: Dictionary = _reachable_from(player_cell, grid)

		var spawns: Array[Vector2] = _mob_spawn_world_positions(assembled)
		assert_gt(spawns.size(), 0, "seed %d: floor has authored mob spawns to validate" % seed)
		for spawn_world: Vector2 in spawns:
			var spawn_cell: Vector2i = _nearest_walkable(
				_world_to_cell(spawn_world, assembled, grid), grid
			)
			assert_true(
				reachable.has(spawn_cell),
				(
					"seed %d: mob spawn %s (cell %s) UNREACHABLE — chunk-gap or grunt-radius wedge"
					% [seed, str(spawn_world), str(spawn_cell)]
				)
			)


## The walk grid is non-degenerate — the grunt-radius dilation must not erase the
## entire floor (a regression that over-dilates would make EVERYTHING a wall and
## the reachability test would pass vacuously with an empty reachable set + zero
## spawns happening to also be unreachable). Assert a healthy walkable interior.
func test_walk_grid_has_substantial_walkable_interior() -> void:
	var zone: ZoneDef = _load_outer_cloister_zone()
	if zone == null:
		return
	var stratum_seed: int = FloorAssemblerScript.derive_stratum_seed(0, 1)
	var seed: int = FloorAssemblerScript.derive_zone_seed(stratum_seed, zone.zone_id)
	var assembler: FloorAssembler = FloorAssemblerScript.new()
	var assembled: AssembledFloor = assembler.assemble_floor(zone, seed)
	var grid: Dictionary = _build_walk_grid(assembled)
	var walk: PackedByteArray = grid["walk"]
	var walkable: int = 0
	for b: int in walk:
		if b == 1:
			walkable += 1
	# The S1 chunks are 15×8 tiles (480×256 px) open shells; after a 1-cell grunt
	# dilation the interior is still the dominant area. Require ≥25% walkable so a
	# future over-dilation / all-wall regression fails loudly (anti-vacuousness).
	assert_gt(
		float(walkable) / float(walk.size()),
		0.25,
		"grunt-radius walk grid must keep a walkable interior (not over-dilated to all-wall)"
	)


## Anti-vacuousness control — the BFS machinery actually DISCRIMINATES. A floor
## split into two disconnected halves (an artificial gap) must produce an
## UNreachable cell. This proves the gate would catch a real chunk-mating gap,
## not pass everything regardless. (Synthetic grid, no assembler — pure BFS test.)
func test_bfs_detects_disconnected_component() -> void:
	# 10×3 grid, fully walkable EXCEPT a vertical wall column at c=5 splitting it.
	var cols: int = 10
	var rows: int = 3
	var walk: PackedByteArray = PackedByteArray()
	walk.resize(cols * rows)
	for r: int in range(rows):
		for c: int in range(cols):
			walk[r * cols + c] = 0 if c == 5 else 1
	var grid: Dictionary = {"cols": cols, "rows": rows, "walk": walk}
	var reachable: Dictionary = _reachable_from(Vector2i(0, 1), grid)
	# Left half (c<5) reachable; right half (c>5) is NOT.
	assert_true(reachable.has(Vector2i(4, 1)), "left-half cell reachable")
	assert_false(
		reachable.has(Vector2i(6, 1)), "right-half cell must be UNREACHABLE (wall splits the floor)"
	)
