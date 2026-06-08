# gdlint:disable=max-public-methods
# GUT test class — high test_* count IS the design (one test per scenario).
extends GutTest
## S1 open cloister-YARD first-slice tests (ticket 86ca5erzk, S1-YARD T4;
## Uma s1-cloister-yard.md). Covers the FIRST WALKABLE yard slice on the
## assembler path. Five surfaces:
##   1. The yard ZoneDef + both chunk defs validate cleanly; the assembled floor's
##      bounding_box_px is WIDER AND TALLER than the 480x270 viewport (the two-axis
##      "big + endless" scroll lever) + well-mated (yard EAST exit ↔ descent WEST
##      entry).
##   2. The yard chunk scene paints OPEN cobble (no perimeter wall ring), builds
##      the authored building structures (visual brick + StaticBody2D collision),
##      and scatters jittered decoration after _ready.
##   3. The carried-forward props are present at the calibrated scales
##      (pillars 0.85 / braziers 0.65 / banners+rubble+parchment 0.70).
##   4. NAVIGABILITY (folds in T6 for the yard): grunt-radius BFS over a walk grid
##      that bakes the BUILDING FOOTPRINTS as walls — every mob spawn is reachable
##      from the player spawn (the player can traverse around the buildings; mobs
##      can reach the player). Anti-vacuousness: the grid keeps a walkable interior
##      + the BFS discriminates a synthetic gap.
##   5. No USER WARNING during load/paint (WarningBus guard).
##
## Paired Playwright spec: tests/playwright/specs/s1-yard-slice-render.spec.ts.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")
const FloorAssemblerScript: Script = preload("res://scripts/levels/FloorAssembler.gd")
const ZoneDefScript: Script = preload("res://resources/level/ZoneDef.gd")
const LevelChunkDefScript: Script = preload("res://scripts/levels/LevelChunkDef.gd")

const ZONE_PATH: String = "res://resources/level/zones/s1_z1_yard_slice.tres"
const YARD_CHUNK_DEF_PATH: String = "res://resources/level_chunks/s1_yard_slice.tres"
const DESCENT_CHUNK_DEF_PATH: String = "res://resources/level_chunks/s1_yard_descent.tres"
const YARD_TILESET_PATH: String = "res://resources/tilesets/s1_cloister_yard.tres"
const YARD_CHUNK_SCENE_PATH: String = "res://scenes/levels/chunks/s1_yard_slice_chunk.tscn"

# The viewport the yard must EXCEED on BOTH axes for two-axis scroll.
const VIEWPORT_W: float = 480.0
const VIEWPORT_H: float = 270.0

const SOURCE_COBBLE: int = 0
const SOURCE_WALL_FINE: int = 1
const SOURCE_SLAB: int = 2  # warm-sandstone flagstone slab-path source (T8)

# Well-head footprint mirror (matches S1YardChunk.well_footprint) — the nav grid
# bakes this as a wall too (the well is a solid walk-AROUND landmark, like buildings).
const WELL_FOOTPRINT := Rect2i(20, 16, 2, 2)  # SOAK-REVISION #426: 3x3→2x2 (well scale 0.85→0.35)

# S1_YARD_WATER_DOCTRINE / path doctrine eye-dropper hexes (Uma §2.4 / §3.3) — pinned
# so a regression that recolours the doctrine surfaces fails loudly. Values are the
# painter-side constants (water ColorRect) + the spec's named hexes for documentation.
const WATER_BASE_HEX := "2e2a26"  # PL-WATER-01 dark warm-neutral (NOT pure-black PL-WATER-02)

# Yard grid (must match S1YardChunk.grid_w/grid_h + s1_yard_slice.tres size_tiles).
const YARD_W: int = 40
const YARD_H: int = 24
const TILE_PX: float = 32.0

# Grunt body radius mirror (matches test_s1_assembled_floor_navigability.gd).
const GRUNT_BODY_RADIUS_PX: float = 12.0
const CELL_PX: float = 16.0

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- Helpers ---------------------------------------------------------


# preload of .tres can bind to null (test-conventions.md) — route through load().
func _load_zone() -> ZoneDef:
	return load(ZONE_PATH)


func _resolve_chunk_def(chunk_id: StringName) -> LevelChunkDef:
	var path: String = "res://resources/level_chunks/%s.tres" % String(chunk_id)
	var res: Resource = load(path)
	if res is LevelChunkDef:
		return res as LevelChunkDef
	return null


func _assemble() -> AssembledFloor:
	var zone: ZoneDef = _load_zone()
	if zone == null:
		return null
	var stratum_seed: int = FloorAssemblerScript.derive_stratum_seed(0, 1)
	var seed: int = FloorAssemblerScript.derive_zone_seed(stratum_seed, zone.zone_id)
	var assembler: FloorAssembler = FloorAssemblerScript.new()
	return assembler.assemble_floor(zone, seed)


func _instantiate_yard_chunk() -> Node:
	var packed: PackedScene = load(YARD_CHUNK_SCENE_PATH)
	assert_not_null(packed, "yard chunk scene must load: %s" % YARD_CHUNK_SCENE_PATH)
	var inst: Node = packed.instantiate()
	add_child_autofree(inst)
	return inst


func _collect_nodes(root: Node, of_type: String) -> Array:
	var out: Array = []
	if root.get_class() == of_type:
		out.append(root)
	for child in root.get_children():
		out.append_array(_collect_nodes(child, of_type))
	return out


# Building footprints (in tiles) mirrored from S1YardChunk.building_footprints —
# the nav grid bakes these as walls so the BFS reflects a grunt pathing AROUND the
# solid buildings, not a point that walks through them.
func _building_footprints() -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	out.append(Rect2i(8, 0, 12, 3))
	out.append(Rect2i(6, 21, 14, 3))
	out.append(Rect2i(18, 9, 6, 5))
	out.append(Rect2i(33, 6, 3, 3))
	return out


# ---- Surface 1: ZoneDef + chunk defs + assembled bounds --------------


func test_zone_def_validates_clean() -> void:
	var zone: ZoneDef = _load_zone()
	assert_not_null(zone, "yard ZoneDef must load")
	if zone == null:
		return
	var errs: Array[String] = zone.validate()
	assert_eq(errs.size(), 0, "yard ZoneDef must validate clean, got: %s" % str(errs))
	assert_eq(zone.zone_id, &"s1_z1_yard_slice", "zone_id")


func test_chunk_defs_validate_clean() -> void:
	for path: String in [YARD_CHUNK_DEF_PATH, DESCENT_CHUNK_DEF_PATH]:
		var cd: Resource = load(path)
		assert_true(cd is LevelChunkDef, "%s loads as LevelChunkDef" % path)
		if cd is LevelChunkDef:
			var errs: Array[String] = (cd as LevelChunkDef).validate()
			assert_eq(errs.size(), 0, "%s must validate clean, got: %s" % [path, str(errs)])


func test_yard_chunk_def_size_matches_painter_grid() -> void:
	var cd: LevelChunkDef = _resolve_chunk_def(&"s1_yard_slice")
	assert_not_null(cd)
	if cd == null:
		return
	# The painter derives its paint loop from grid_w/grid_h; the assembler derives
	# bounding_box_px from size_tiles. They MUST agree or the floor renders smaller
	# than the camera bounds (or vice versa). Pin both equal to (40, 24).
	assert_eq(cd.size_tiles, Vector2i(YARD_W, YARD_H), "yard chunk size_tiles = painter grid")


func test_assembled_bounds_wider_and_taller_than_viewport() -> void:
	var assembled: AssembledFloor = _assemble()
	assert_not_null(assembled)
	if assembled == null:
		return
	assert_false(assembled.is_empty(), "yard assembled floor must be non-empty")
	var b: Rect2 = assembled.bounding_box_px
	# Two-axis scroll is THE big+endless lever — the bounds must exceed the
	# viewport on BOTH axes (yard 40x24 → 1280x768; + descent 6 wide → 1472x768).
	assert_gt(b.size.x, VIEWPORT_W, "assembled bounds WIDER than viewport (x-scroll)")
	assert_gt(b.size.y, VIEWPORT_H, "assembled bounds TALLER than viewport (y-scroll)")


func test_assembled_floor_is_well_mated() -> void:
	var assembled: AssembledFloor = _assemble()
	if assembled == null:
		return
	# Yard EAST exit (y=12) ↔ descent WEST entry (y=12) must mate cleanly so the
	# floor is ONE continuous expanse, not split islands.
	assert_true(
		assembled.is_well_mated(),
		"yard↔descent must mate cleanly, errors: %s" % str(assembled.port_mating_errors)
	)
	assert_eq(assembled.chunk_count(), 2, "slice = yard + descent cap (2 chunks)")


# ---- Surface 2 + 3: chunk scene paint + props -----------------------


func test_yard_chunk_paints_open_cobble_floor() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var floor_tiles: TileMapLayer = inst.get_node("FloorTiles")
	assert_not_null(floor_tiles, "FloorTiles TileMapLayer present")
	if floor_tiles == null:
		return
	# Every interior cell painted with the cobble source — OPEN expanse, no
	# perimeter wall ring (the room model). Sample the four corners + centre.
	for probe: Vector2i in [
		Vector2i(0, 0),
		Vector2i(YARD_W - 1, 0),
		Vector2i(0, YARD_H - 1),
		Vector2i(YARD_W - 1, YARD_H - 1),
		Vector2i(YARD_W / 2, YARD_H / 2),
	]:
		assert_eq(
			floor_tiles.get_cell_source_id(probe),
			SOURCE_COBBLE,
			"cell %s painted as open cobble (no perimeter wall ring)" % str(probe)
		)


## REPEAT-BREAK (PR #424 Sponsor fix). The yard must NOT stamp one repeating cobble
## block — the painter scatters 6 atlas variants per 4x4 block via a non-tiling hash.
## Assert that across the yard's blocks MULTIPLE distinct variants are used (the
## variant = atlas_col / 4), so the field doesn't read a single repeating stamp. A
## regression back to a single-tile period would use exactly ONE variant → fails.
func test_yard_cobble_uses_multiple_variants_no_single_stamp() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var floor_tiles: TileMapLayer = inst.get_node("FloorTiles")
	if floor_tiles == null:
		return
	var variants_seen := {}
	# Sample one cell per 4x4 block across the whole yard; record its variant.
	for by: int in range(0, YARD_H, 4):
		for bx: int in range(0, YARD_W, 4):
			var coords: Vector2i = floor_tiles.get_cell_atlas_coords(Vector2i(bx, by))
			if coords.x < 0:
				continue
			var variant: int = coords.x / 4  # 6 variant-blocks of 4 cols each
			variants_seen[variant] = true
	# A single-stamp regression yields exactly 1 variant; the scatter must use several.
	assert_gt(
		variants_seen.size(),
		2,
		(
			"yard must scatter MULTIPLE cobble variants (no single repeating stamp), got %d"
			% variants_seen.size()
		)
	)


## The variant scatter is NON-TILING — it must not realign on a small period (which
## would re-introduce a visible variant grid). Assert two blocks a short period apart
## differ for at least one offset (cheap non-tiling probe).
func test_yard_cobble_variant_scatter_is_non_tiling() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var floor_tiles: TileMapLayer = inst.get_node("FloorTiles")
	if floor_tiles == null:
		return
	# Compare the variant of block row 0 across consecutive blocks — they must not be
	# all identical (a tiling period of 1) and not strictly alternating in a trivial
	# way. Cheap check: collect the row-0 variant sequence; assert ≥3 distinct values.
	var seq := {}
	for bx: int in range(0, YARD_W, 4):
		var coords: Vector2i = floor_tiles.get_cell_atlas_coords(Vector2i(bx, 0))
		if coords.x >= 0:
			seq[coords.x / 4] = true
	assert_gt(
		seq.size(), 2, "row-0 variant sequence must vary (non-tiling), got %d distinct" % seq.size()
	)


func test_yard_chunk_builds_solid_building_structures() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var bodies_root: Node = inst.get_node("BuildingBodies")
	assert_not_null(bodies_root, "BuildingBodies node present")
	# Scope to BuildingBodies — the well-head also has a StaticBody2D (in WellBody, T8),
	# so a whole-tree scan would over-count. One body per authored building footprint (4).
	var bodies: Array = _collect_nodes(bodies_root, "StaticBody2D")
	# One StaticBody2D per authored footprint (4) → buildings are walk-AROUND
	# solids, NOT teleport-room walls.
	assert_eq(bodies.size(), _building_footprints().size(), "one collision body per building")
	# Each body has a CollisionShape2D with a RectangleShape2D.
	for body: Node in bodies:
		var shapes: Array = _collect_nodes(body, "CollisionShape2D")
		assert_gt(shapes.size(), 0, "building has a CollisionShape2D")


func test_yard_chunk_paints_building_bricks() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var buildings: TileMapLayer = inst.get_node("Buildings")
	assert_not_null(buildings, "Buildings TileMapLayer present")
	if buildings == null:
		return
	# A cell inside the central building footprint (18-23 × 9-13) is painted with
	# the finer-brick source; a cell in open ground is NOT.
	assert_eq(
		buildings.get_cell_source_id(Vector2i(20, 11)),
		SOURCE_WALL_FINE,
		"central-building cell painted with finer brick"
	)
	assert_eq(
		buildings.get_cell_source_id(Vector2i(3, 12)),
		-1,
		"open-ground cell has NO building brick (empty cell)"
	)


func test_carried_forward_props_present_at_calibrated_scales() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var props_root: Node = inst.get_node("Props")
	assert_not_null(props_root, "Props node present")
	if props_root == null:
		return
	var sprites: Array = _collect_nodes(props_root, "Sprite2D")
	assert_gt(sprites.size(), 0, "yard places carried-forward props as landmarks")
	# Per ticket scale calibration: pillars 0.85, braziers 0.65, banners/rubble/
	# parchment 0.70. Verify by texture-path → expected scale.
	var expected := {
		"pillar_arch.png": 0.85,
		"brazier_lit.png": 0.65,
		"banner_worn.png": 0.70,
		"rubble_01.png": 0.70,
		"parchment_01.png": 0.70,
	}
	var seen := {}
	for spr: Sprite2D in sprites:
		if spr.texture == null:
			continue
		var path: String = spr.texture.resource_path
		for key: String in expected.keys():
			if path.ends_with(key):
				seen[key] = true
				assert_almost_eq(
					spr.scale.x,
					float(expected[key]),
					0.001,
					"%s scaled to calibration %.2f" % [key, expected[key]]
				)
	# At least the pillar + brazier landmark families are present.
	assert_true(seen.has("pillar_arch.png"), "pillars present as building-face landmarks")
	assert_true(seen.has("brazier_lit.png"), "braziers present as atmosphere landmarks")


## Decoration prop scatter is EMPTY (Sponsor scale soak fix, PR #424). The prior
## moss_patch tuft scatter rendered ~player-sized dark spiky blobs ("ugly objects
## out of proportion" — Sponsor). The vegetation/"nature reclaiming" story is carried
## by the cobble FLOOR tiles' baked-in moss (s1-cloister-yard.md §5.2); a proper
## correctly-proportioned ground-vegetation prop is T3's surface. Pin the no-op so a
## future re-introduction of oversized blob props fails this gate loudly.
func test_yard_chunk_decoration_has_no_oversized_blob_props() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var deco: Node = inst.get_node("Decoration")
	assert_not_null(deco, "Decoration node present (empty container; T3 repopulates)")
	if deco == null:
		return
	var tufts: Array = _collect_nodes(deco, "Sprite2D")
	assert_eq(
		tufts.size(),
		0,
		(
			"yard places NO prop-scatter tufts — the moss_patch blobs read ~player-sized"
			+ " and ugly (Sponsor); vegetation lives in the cobble floor tiles. T3 adds a"
			+ " proper proportional ground-vegetation prop."
		)
	)


# ---- Surface 4: navigability (T6 gate for the yard) ------------------


## Build a walk grid over the assembled floor that bakes (a) inter-chunk gaps +
## off-floor as walls AND (b) the yard's building footprints as walls, then dilates
## by the grunt radius. This is the yard-aware extension of the keystone nav gate
## (test_s1_assembled_floor_navigability.gd) — it adds the building-occupancy the
## yard introduces, which that test (room-shell occupancy only) does not model.
func _build_yard_walk_grid(assembled: AssembledFloor) -> Dictionary:
	var bounds: Rect2 = assembled.bounding_box_px
	var cols: int = int(ceil(bounds.size.x / CELL_PX))
	var rows: int = int(ceil(bounds.size.y / CELL_PX))
	var walk: PackedByteArray = PackedByteArray()
	walk.resize(cols * rows)

	# Precompute building world-rects (footprints belong to the YARD chunk, placed
	# at the yard's position_px).
	var building_world_rects: Array[Rect2] = []
	for placed: PlacedChunk in assembled.placed_chunks:
		if placed.chunk_id != &"s1_yard_slice":
			continue
		for foot: Rect2i in _building_footprints():
			var r := Rect2(
				placed.position_px + Vector2(foot.position) * TILE_PX, Vector2(foot.size) * TILE_PX
			)
			building_world_rects.append(r)
		# The well-head is ALSO a solid landmark (T8) — bake its footprint as a wall so
		# the nav gate proves mobs/player path AROUND it, not through it.
		building_world_rects.append(
			Rect2(
				placed.position_px + Vector2(WELL_FOOTPRINT.position) * TILE_PX,
				Vector2(WELL_FOOTPRINT.size) * TILE_PX
			)
		)

	for r: int in range(rows):
		for c: int in range(cols):
			var center := Vector2(
				bounds.position.x + (float(c) + 0.5) * CELL_PX,
				bounds.position.y + (float(r) + 0.5) * CELL_PX
			)
			var inside_chunk: bool = false
			for placed: PlacedChunk in assembled.placed_chunks:
				if Rect2(placed.position_px, Vector2(placed.size_px)).has_point(center):
					inside_chunk = true
					break
			var inside_building: bool = false
			if inside_chunk:
				for br: Rect2 in building_world_rects:
					if br.has_point(center):
						inside_building = true
						break
			walk[r * cols + c] = 1 if (inside_chunk and not inside_building) else 0

	# Dilate walls by the grunt radius (ceil(12/16)=1 cell).
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
					if nr < 0 or nr >= rows or nc < 0 or nc >= cols or walk[nr * cols + nc] == 0:
						blocked = true
						break
				if blocked:
					break
			if blocked:
				dilated[r * cols + c] = 0
	return {"cols": cols, "rows": rows, "walk": dilated}


func _world_to_cell(world: Vector2, assembled: AssembledFloor, grid: Dictionary) -> Vector2i:
	var bounds: Rect2 = assembled.bounding_box_px
	var c: int = int(floor((world.x - bounds.position.x) / CELL_PX))
	var r: int = int(floor((world.y - bounds.position.y) / CELL_PX))
	c = clampi(c, 0, int(grid["cols"]) - 1)
	r = clampi(r, 0, int(grid["rows"]) - 1)
	return Vector2i(c, r)


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
			if n.x < 0 or n.x >= cols or n.y < 0 or n.y >= rows or seen.has(n):
				continue
			seen[n] = true
			if walk[n.y * cols + n.x] == 1:
				return n
			queue.append(n)
	return Vector2i(-1, -1)


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
			if n.x < 0 or n.x >= cols or n.y < 0 or n.y >= rows or seen.has(n):
				continue
			if walk[n.y * cols + n.x] == 1:
				seen[n] = true
				queue.append(n)
	return seen


func _mob_spawn_world_positions(assembled: AssembledFloor) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for placed: PlacedChunk in assembled.placed_chunks:
		var cd: LevelChunkDef = _resolve_chunk_def(placed.chunk_id)
		if cd == null:
			continue
		for spawn: MobSpawnPoint in cd.mob_spawns:
			out.append(placed.position_px + Vector2(spawn.position_tiles * cd.tile_size_px))
	return out


## THE YARD NAVIGABILITY GATE (T6). With the buildings baked as walls, the player
## must be able to reach every mob spawn (traverse AROUND the buildings) and every
## mob must be able to reach the player. A building blocking a lane into a
## disconnected pocket would fail this.
func test_every_mob_spawn_reachable_around_buildings() -> void:
	var assembled: AssembledFloor = _assemble()
	assert_not_null(assembled)
	if assembled == null:
		return
	var grid: Dictionary = _build_yard_walk_grid(assembled)
	var bounds: Rect2 = assembled.bounding_box_px
	# Player spawn mirrors Main._s2_floor_spawn: left edge + 24 px, vertically centred.
	var player_world := Vector2(bounds.position.x + 24.0, bounds.position.y + bounds.size.y * 0.5)
	var player_cell: Vector2i = _nearest_walkable(
		_world_to_cell(player_world, assembled, grid), grid
	)
	assert_ne(player_cell, Vector2i(-1, -1), "player spawn has a walkable cell")
	if player_cell == Vector2i(-1, -1):
		return
	var reachable: Dictionary = _reachable_from(player_cell, grid)
	var spawns: Array[Vector2] = _mob_spawn_world_positions(assembled)
	assert_gt(spawns.size(), 0, "yard has authored mob spawns to validate")
	for spawn_world: Vector2 in spawns:
		var spawn_cell: Vector2i = _nearest_walkable(
			_world_to_cell(spawn_world, assembled, grid), grid
		)
		assert_true(
			reachable.has(spawn_cell),
			(
				"mob spawn %s (cell %s) UNREACHABLE around buildings — pocketed lane"
				% [str(spawn_world), str(spawn_cell)]
			)
		)


## The descent (east terminus) is reachable from the player spawn — the player can
## walk the full journey west→east AROUND the central building to the descent cap.
func test_descent_reachable_from_player_spawn() -> void:
	var assembled: AssembledFloor = _assemble()
	if assembled == null:
		return
	var grid: Dictionary = _build_yard_walk_grid(assembled)
	var bounds: Rect2 = assembled.bounding_box_px
	var player_world := Vector2(bounds.position.x + 24.0, bounds.position.y + bounds.size.y * 0.5)
	var player_cell: Vector2i = _nearest_walkable(
		_world_to_cell(player_world, assembled, grid), grid
	)
	if player_cell == Vector2i(-1, -1):
		return
	var reachable: Dictionary = _reachable_from(player_cell, grid)
	# A point deep in the descent cap (east edge, vertically centred).
	var descent_world := Vector2(bounds.end.x - 32.0, bounds.position.y + bounds.size.y * 0.5)
	var descent_cell: Vector2i = _nearest_walkable(
		_world_to_cell(descent_world, assembled, grid), grid
	)
	assert_true(
		reachable.has(descent_cell), "east descent terminus reachable from west spawn (journey)"
	)


## Anti-vacuousness: the yard walk grid keeps a substantial walkable interior (the
## buildings + dilation must not erase the whole open expanse).
func test_yard_walk_grid_has_walkable_interior() -> void:
	var assembled: AssembledFloor = _assemble()
	if assembled == null:
		return
	var grid: Dictionary = _build_yard_walk_grid(assembled)
	var walk: PackedByteArray = grid["walk"]
	var walkable: int = 0
	for b: int in walk:
		if b == 1:
			walkable += 1
	# Buildings occupy a small fraction of a big open expanse; ≥40% walkable.
	assert_gt(
		float(walkable) / float(walk.size()),
		0.40,
		"yard keeps an open walkable interior (buildings are landmarks, not walls)"
	)


## Anti-vacuousness control — the BFS discriminates a synthetic gap.
func test_bfs_detects_disconnected_component() -> void:
	var cols: int = 10
	var rows: int = 3
	var walk: PackedByteArray = PackedByteArray()
	walk.resize(cols * rows)
	for r: int in range(rows):
		for c: int in range(cols):
			walk[r * cols + c] = 0 if c == 5 else 1
	var grid: Dictionary = {"cols": cols, "rows": rows, "walk": walk}
	var reachable: Dictionary = _reachable_from(Vector2i(0, 1), grid)
	assert_true(reachable.has(Vector2i(4, 1)), "left-half reachable")
	assert_false(reachable.has(Vector2i(6, 1)), "right-half UNREACHABLE (wall splits floor)")


# ====================================================================
# S1-YARD T8 — ground-composition layer (slab paths + well + springs + garden)
# ====================================================================


## The slab-path tileset source (warm-sandstone flagstone, source 2) is wired into the
## yard TileSet. A regression dropping the source would break every slab cell.
func test_tileset_has_slab_source() -> void:
	var ts: TileSet = load(YARD_TILESET_PATH)
	assert_not_null(ts, "yard TileSet loads")
	if ts == null:
		return
	assert_true(ts.has_source(SOURCE_SLAB), "yard TileSet has the slab-path source (id 2)")


## Slab paths are painted as a RIBBON into the SlabPaths layer, AND the cobble cell
## beneath each slab is ERASED in FloorTiles — exactly ONE tile-class per cell, no
## stacked-z, no z-fight (T8 AC9 / html5-export.md §Z-index). This is the load-bearing
## anti-z-fight invariant: assert that EVERY painted slab cell has empty cobble beneath.
func test_slab_paths_painted_with_cobble_erased_beneath_no_zfight() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var slab: TileMapLayer = inst.get_node("SlabPaths")
	var floor_tiles: TileMapLayer = inst.get_node("FloorTiles")
	assert_not_null(slab, "SlabPaths layer present")
	assert_not_null(floor_tiles, "FloorTiles layer present")
	if slab == null or floor_tiles == null:
		return
	var slab_cells: int = 0
	for cell: Vector2i in slab.get_used_cells():
		assert_eq(
			slab.get_cell_source_id(cell),
			SOURCE_SLAB,
			"slab cell %s painted with the flagstone source" % str(cell)
		)
		# THE AC9 INVARIANT: no cobble underneath a slab cell (one tile-class per cell).
		assert_eq(
			floor_tiles.get_cell_source_id(cell),
			-1,
			(
				"cobble ERASED beneath slab cell %s — one tile-class per cell, no z-fight (AC9)"
				% str(cell)
			)
		)
		slab_cells += 1
	# The spine + links + apron paint a meaningful ribbon, not zero cells.
	assert_gt(slab_cells, 30, "slab paths paint a real processional ribbon (got %d)" % slab_cells)


## The processional spine runs west→east — assert slab cells exist near the WEST edge
## (spawn gate) AND near the EAST edge (descent), so the path is a continuous wayfinding
## ribbon spanning the journey, not a disconnected blob.
func test_slab_spine_spans_west_to_east() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var slab: TileMapLayer = inst.get_node("SlabPaths")
	if slab == null:
		return
	var has_west: bool = false
	var has_east: bool = false
	for cell: Vector2i in slab.get_used_cells():
		if cell.x <= 2:
			has_west = true
		if cell.x >= YARD_W - 3:
			has_east = true
	assert_true(has_west, "slab spine reaches the WEST spawn-gate edge")
	assert_true(has_east, "slab spine reaches the EAST descent edge (journey span)")


## Slabs never run through a building footprint (a path doesn't cross a solid wall).
func test_slab_cells_never_inside_a_building() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var slab: TileMapLayer = inst.get_node("SlabPaths")
	if slab == null:
		return
	for cell: Vector2i in slab.get_used_cells():
		for foot: Rect2i in _building_footprints():
			assert_false(
				foot.has_point(cell), "slab cell %s must NOT be inside building %s" % [cell, foot]
			)


## The well-head landmark is present: a Sprite2D in Props using well_head.png at the
## calibrated landmark scale 0.85, AND a solid StaticBody2D collision (walk-around).
func test_well_head_prop_and_collision_present() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var props: Node = inst.get_node("Props")
	var well_body: Node = inst.get_node("WellBody")
	assert_not_null(props, "Props node present")
	assert_not_null(well_body, "WellBody node present")
	if props == null or well_body == null:
		return
	var sprites: Array = _collect_nodes(props, "Sprite2D")
	var found_well := false
	for spr: Sprite2D in sprites:
		if spr.texture != null and spr.texture.resource_path.ends_with("well_head.png"):
			found_well = true
			# SOAK-REVISION #426: well scale 0.85→0.35 (rim ~1.5x player height, a real
			# well not a building — Sponsor "drastically too big" 2026-06-08; calibrated to
			# the human-scale fountain in inspiration/2026-06-08_07h53_24.png).
			assert_almost_eq(spr.scale.x, 0.35, 0.001, "well at soak-revised scale 0.35")
	assert_true(found_well, "well-head prop present (well_head.png landmark)")
	# Collision: one StaticBody2D with a CollisionShape2D (solid walk-around landmark).
	var bodies: Array = _collect_nodes(well_body, "StaticBody2D")
	assert_eq(bodies.size(), 1, "well-head has exactly one collision body")
	for body: Node in bodies:
		assert_gt(_collect_nodes(body, "CollisionShape2D").size(), 0, "well body has a shape")


## Springs are still dark warm-neutral ColorRect pools (NO bespoke asset; orch handoff).
## Assert: ≥1 pool ColorRect with the doctrine water-base hex AND it is NOT pure-black
## (PL-WATER-01/02). Also assert NO Polygon2D anywhere in Springs (PR #137 / §3.3 rule).
func test_springs_are_colorrect_pools_doctrine_water_not_black_no_polygon2d() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var springs: Node = inst.get_node("Springs")
	assert_not_null(springs, "Springs node present")
	if springs == null:
		return
	# No Polygon2D in the water surface (HTML5 invisibility class, PR #137).
	assert_eq(
		_collect_nodes(springs, "Polygon2D").size(), 0, "springs use NO Polygon2D (ColorRect only)"
	)
	var rects: Array = _collect_nodes(springs, "ColorRect")
	assert_gt(rects.size(), 0, "springs author ColorRect pools")
	var found_water := false
	for rect: ColorRect in rects:
		if rect.color.to_html(false) == WATER_BASE_HEX:
			found_water = true
			# PL-WATER-02: NOT pure-black.
			assert_ne(rect.color, Color(0, 0, 0, 1.0), "spring water is NOT pure black (PL-09)")
			# Sub-1.0 HDR-clamp-safe every channel (PL-WATER-01 doctrine).
			assert_lt(rect.color.r, 1.0, "water R sub-1.0 (HDR-clamp safe)")
			assert_lt(rect.color.g, 1.0, "water G sub-1.0")
			assert_lt(rect.color.b, 1.0, "water B sub-1.0")
	assert_true(
		found_water, "a spring pool uses the S1_YARD_WATER_DOCTRINE base hex #%s" % WATER_BASE_HEX
	)


## Springs sit in OPEN cobble (no slab, no building) so they read as low damp spots in
## the field, and there are 1-2 of them (§3.2 "1-2 in the yard").
func test_springs_count_in_range() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var springs: Node = inst.get_node("Springs")
	if springs == null:
		return
	# Count distinct pool ColorRects (the water-base hex) — should be 1-2 hero springs.
	var pools := 0
	for rect: ColorRect in _collect_nodes(springs, "ColorRect"):
		if rect.color.to_html(false) == WATER_BASE_HEX:
			pools += 1
	assert_between(pools, 1, 2, "1-2 spring pools in the yard (§3.2)")


## ONE garden bed gone wild (§4 "one hero bed, not multiple") — a soil ColorRect bed
## near the dormitory range (south half). SOAK-REVISION #426: the moss_patch overgrowth
## sprites were cut (spiky-prop "trash" class); the bed is the clean soil ColorRect alone.
func test_one_garden_bed_soil_in_south_half() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var springs: Node = inst.get_node("Springs")
	if springs == null:
		return
	# The garden soil bed is the largest non-water ColorRect; assert exactly one soil bed
	# distinct from the spring pools/highlights/aprons by its garden-soil tint signature.
	var garden_soil_hex := Color(0.329, 0.271, 0.184, 0.78).to_html(true)
	var beds := 0
	for rect: ColorRect in _collect_nodes(springs, "ColorRect"):
		if rect.color.to_html(true) == garden_soil_hex:
			beds += 1
			# Sits in the south half (near dormitory range).
			assert_gt(rect.position.y, float(YARD_H) * TILE_PX * 0.5, "garden bed in south half")
	assert_eq(beds, 1, "exactly ONE garden bed (§4 one hero bed)")


## REGRESSION GUARD (SOAK-REVISION #426). The Sponsor flagged the scattered moss_patch
## sprites (spring rings + garden overgrowth + building-base aprons) as ugly spiky "trash"
## leaking across the yard + onto the wall band, and asked for the whole class removed.
## Pin that the ground-composition containers hold NO Sprite2D props (the moss_patch
## class) — only ColorRects (water pools/glints, garden soil, apron shadow strips). A
## future re-introduction of the moss-tuft scatter fails this gate loudly. (The well-head
## + carried-forward landmark props live in Props, which is intentionally unaffected.)
func test_ground_composition_has_no_moss_patch_trash_sprites() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var springs: Node = inst.get_node("Springs")
	assert_not_null(springs, "Springs container present")
	if springs == null:
		return
	var sprites: Array = _collect_nodes(springs, "Sprite2D")
	assert_eq(
		sprites.size(),
		0,
		(
			"ground-composition (Springs container) places NO Sprite2D props — the moss_patch"
			+ " tufts read as ugly spiky 'trash' (Sponsor #426); springs/garden/aprons are"
			+ " ColorRect-only now."
		)
	)


## The well-baked nav grid still keeps a walkable interior + every mob spawn reachable
## (already covered by the spawn-reachability test, which now bakes the well too). This
## adds an explicit pin that adding the well did NOT pocket the descent journey.
func test_descent_still_reachable_with_well_baked() -> void:
	var assembled: AssembledFloor = _assemble()
	if assembled == null:
		return
	var grid: Dictionary = _build_yard_walk_grid(assembled)  # now bakes WELL_FOOTPRINT
	var bounds: Rect2 = assembled.bounding_box_px
	var player_world := Vector2(bounds.position.x + 24.0, bounds.position.y + bounds.size.y * 0.5)
	var player_cell: Vector2i = _nearest_walkable(
		_world_to_cell(player_world, assembled, grid), grid
	)
	if player_cell == Vector2i(-1, -1):
		return
	var reachable: Dictionary = _reachable_from(player_cell, grid)
	var descent_world := Vector2(bounds.end.x - 32.0, bounds.position.y + bounds.size.y * 0.5)
	var descent_cell: Vector2i = _nearest_walkable(
		_world_to_cell(descent_world, assembled, grid), grid
	)
	assert_true(
		reachable.has(descent_cell),
		"descent reachable AROUND the well (well didn't pocket the journey)"
	)
