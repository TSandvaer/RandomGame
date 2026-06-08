# gdlint:disable=max-public-methods,max-file-lines
# GUT test class — high test_* count IS the design (one test per scenario); the v2
# ground-composition pins push the file past 1000 lines (each surface gets its own pin).
extends GutTest
## S1 open cloister-YARD first-slice tests (ticket 86ca5erzk, S1-YARD T4;
## Uma s1-cloister-yard.md). Covers the FIRST WALKABLE yard slice on the
## assembler path. Five surfaces:
##   1. The yard ZoneDef + both chunk defs validate cleanly; the assembled floor's
##      bounding_box_px is WIDER AND TALLER than the 480x270 viewport (the two-axis
##      "big + endless" scroll lever) + well-mated (yard EAST exit ↔ descent WEST
##      entry).
##   2. The yard chunk scene paints the v2 VARIED open ground (dirt majority + grass
##      patches + cobble patches + the fine-cobble lane, no perimeter wall ring), builds
##      the authored building structures (visual brick + StaticBody2D collision).
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
# v2 ground composition (86ca5hwmx): the path is the FINE-COBBLE lane atlas (replaces
# the dead ashlar slab); the ground is dirt-majority + grass + cobble patches.
const PATH_ATLAS_PATH: String = "res://assets/tilesets/s1_cloister/floor_path.png"
const DIRT_ATLAS_PATH: String = "res://assets/tilesets/s1_cloister/floor_dirt.png"
const GRASS_ATLAS_PATH: String = "res://assets/tilesets/s1_cloister/floor_grass.png"
const YARD_CHUNK_SCENE_PATH: String = "res://scenes/levels/chunks/s1_yard_slice_chunk.tscn"

# The viewport the yard must EXCEED on BOTH axes for two-axis scroll.
const VIEWPORT_W: float = 480.0
const VIEWPORT_H: float = 270.0

const SOURCE_COBBLE: int = 0  # surviving-paving cobble patches (v2)
const SOURCE_WALL_FINE: int = 1
const SOURCE_PATH: int = 2  # fine-cobble LANE source (v2, replaces the dead slab)
const SOURCE_DIRT: int = 3  # worn-dirt majority ground (v2)
const SOURCE_GRASS: int = 4  # grass reclamation patches (v2)

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


## v2 GROUND COMPOSITION (86ca5hwmx): the ground is NO LONGER wall-to-wall cobble — it
## is a VARIED open expanse of dirt (majority) + grass (edges) + cobble (patches), with
## NO perimeter wall ring (still the open-yard model). Every FloorTiles cell that is NOT
## under the fine-cobble lane must be exactly one valid GROUND class (dirt/grass/cobble),
## and EVERY cell must be painted (no holes in the open expanse).
func test_yard_chunk_paints_varied_open_ground_no_wall_ring() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var floor_tiles: TileMapLayer = inst.get_node("FloorTiles")
	var lane: TileMapLayer = inst.get_node("PathLane")
	assert_not_null(floor_tiles, "FloorTiles TileMapLayer present")
	if floor_tiles == null or lane == null:
		return
	var valid_ground := [SOURCE_COBBLE, SOURCE_DIRT, SOURCE_GRASS]
	for ty in range(YARD_H):
		for tx in range(YARD_W):
			var cell := Vector2i(tx, ty)
			# A cell is EITHER a lane cell (painted in PathLane, erased in FloorTiles) OR a
			# ground cell (painted in FloorTiles with a valid ground class). Exactly one.
			var lane_src: int = lane.get_cell_source_id(cell)
			var floor_src: int = floor_tiles.get_cell_source_id(cell)
			if lane_src == SOURCE_PATH:
				assert_eq(floor_src, -1, "lane cell %s has ground ERASED beneath (AC9)" % str(cell))
			else:
				assert_true(
					floor_src in valid_ground,
					(
						"ground cell %s is a valid class (dirt/grass/cobble), got %d"
						% [str(cell), floor_src]
					)
				)


## v2 §3: the ground is DIRT-MAJORITY (~55-65%), with grass (~20-30%) + cobble (~10-20%)
## as PARTS, NOT a cobble carpet (Sponsor: "cobblestone should only be parts of the
## walking background"). Pin the composition ratios so a regression back to a cobble (or
## any single-class) carpet fails loudly. Counts are over ground (non-lane) cells.
func test_ground_composition_is_dirt_majority_cobble_is_parts() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var floor_tiles: TileMapLayer = inst.get_node("FloorTiles")
	if floor_tiles == null:
		return
	var counts := {SOURCE_DIRT: 0, SOURCE_GRASS: 0, SOURCE_COBBLE: 0}
	var total := 0
	for ty in range(YARD_H):
		for tx in range(YARD_W):
			var src: int = floor_tiles.get_cell_source_id(Vector2i(tx, ty))
			if counts.has(src):
				counts[src] += 1
				total += 1
	assert_gt(total, 0, "ground has painted cells")
	var dirt_frac: float = float(counts[SOURCE_DIRT]) / float(total)
	var grass_frac: float = float(counts[SOURCE_GRASS]) / float(total)
	var cobble_frac: float = float(counts[SOURCE_COBBLE]) / float(total)
	# DIRT is the clear majority (the new default ground).
	assert_gt(dirt_frac, 0.50, "dirt is the MAJORITY ground (got %.1f%%)" % (dirt_frac * 100.0))
	# GRASS + COBBLE are PARTS, not the dominant surface (each well under half).
	assert_lt(
		grass_frac, 0.40, "grass is a PART, not the majority (got %.1f%%)" % (grass_frac * 100.0)
	)
	assert_lt(
		cobble_frac, 0.40, "cobble is a PART, not a carpet (got %.1f%%)" % (cobble_frac * 100.0)
	)
	# All three materials are actually PRESENT (the composition is genuinely varied).
	assert_gt(counts[SOURCE_DIRT], 0, "dirt present")
	assert_gt(counts[SOURCE_GRASS], 0, "grass present (reclamation patches)")
	assert_gt(counts[SOURCE_COBBLE], 0, "cobble present (surviving-paving patches)")


## v3 SEAM-FIX PIN (Sponsor 2026-06-08 "hard square block seams forming a visible grid").
## The v2 painter swapped a DIFFERENT atlas variant per 4x4 block; two different toroidal
## tiles don't mate at their shared edge → the visible ~256px block grid on the smooth
## dirt field. v3 paints the DIRT field from ONE variant CONTINUOUSLY (`_dirt_atlas_coords`:
## variant 0, addressed by world coord wrapped into the variant's 4x4 cells), so a single
## seamless tile wraps onto itself with NO block seam. Pin that EVERY dirt cell uses the
## SAME variant (variant 0) AND that the atlas col within a 4x4 block period equals the
## cell's tx%4 (the continuous-wrap contract) — a regression back to the per-block variant
## SWAP (the seam bug) would use multiple variants on dirt cells and fail this loudly.
func test_dirt_field_is_continuous_single_variant_no_block_seam() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var floor_tiles: TileMapLayer = inst.get_node("FloorTiles")
	if floor_tiles == null:
		return
	var dirt_cells := 0
	for ty in range(YARD_H):
		for tx in range(YARD_W):
			var cell := Vector2i(tx, ty)
			if floor_tiles.get_cell_source_id(cell) != SOURCE_DIRT:
				continue
			dirt_cells += 1
			var coords: Vector2i = floor_tiles.get_cell_atlas_coords(cell)
			var variant: int = coords.x / 4  # 6 variant-blocks of 4 cols each
			var local_col: int = coords.x % 4
			# THE SEAM-FIX INVARIANT: every dirt cell is variant 0 (continuous, no swap)
			# AND its atlas col within the block tracks tx%4 (the toroidal-wrap addressing).
			assert_eq(variant, 0, "dirt cell %s uses the single continuous variant 0" % str(cell))
			assert_eq(
				local_col, tx % 4, "dirt cell %s atlas col tracks tx%%4 (continuous wrap)" % str(cell)
			)
			assert_eq(coords.y, ty % 4, "dirt cell %s atlas row tracks ty%%4" % str(cell))
	assert_gt(dirt_cells, 400, "dirt is the majority continuous field (got %d cells)" % dirt_cells)


## v3 STRUCTURE PIN (Sponsor 2026-06-08 "no structure ... just chaos"). Grass is HAND-
## PLACED at the OUTER edges/corners ONLY — NOT scattered across the mid-field (the v2
## noise scatter was the chaos). Pin that EVERY grass cell sits within a hand-authored
## grass_region (all at the yard margins) AND that the OPEN MID-FIELD (a central band well
## away from the rim) is entirely dirt/lane/cobble — ZERO grass. A regression back to the
## noise-scatter (grass blobs in the middle) fails this loudly.
func test_grass_only_at_edges_none_in_mid_field() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var floor_tiles: TileMapLayer = inst.get_node("FloorTiles")
	if floor_tiles == null:
		return
	# Mid-field probe box: columns 12..28, rows 7..17 (the open centre, clear of the
	# corner/rim grass regions). No grass may appear here — the middle is smooth dirt + lane.
	var mid_grass := 0
	for ty in range(7, 18):
		for tx in range(12, 29):
			if floor_tiles.get_cell_source_id(Vector2i(tx, ty)) == SOURCE_GRASS:
				mid_grass += 1
	assert_eq(
		mid_grass,
		0,
		(
			"NO grass in the open mid-field (cols 12-28, rows 7-17) — grass is hand-placed at"
			+ " the EDGES only; mid-field scatter is the rejected v2 chaos (got %d)" % mid_grass
		)
	)
	# And grass IS present at the corners (the hand-placed reclamation regions exist).
	var corner_grass := 0
	for probe: Vector2i in [Vector2i(1, 1), Vector2i(38, 1), Vector2i(2, 21), Vector2i(37, 22)]:
		if floor_tiles.get_cell_source_id(probe) == SOURCE_GRASS:
			corner_grass += 1
	assert_gt(corner_grass, 0, "grass reclaims the corners (hand-placed edge regions present)")


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
# S1-YARD ground-composition layer — v2 (86ca5hwmx): fine-cobble lane + varied ground
# (dirt majority + grass patches + cobble patches) + well + springs + garden. Replaces
# the dead ashlar slab path (third soak rejection).
# ====================================================================


## The fine-cobble LANE tileset source (source 2, v2) is wired into the yard TileSet. A
## regression dropping the source would break every lane cell. (Replaces the dead slab.)
func test_tileset_has_path_source() -> void:
	var ts: TileSet = load(YARD_TILESET_PATH)
	assert_not_null(ts, "yard TileSet loads")
	if ts == null:
		return
	assert_true(ts.has_source(SOURCE_PATH), "yard TileSet has the fine-cobble lane source (id 2)")
	# v2 also wires the dirt + grass ground sources (3 + 4).
	assert_true(ts.has_source(SOURCE_DIRT), "yard TileSet has the worn-dirt source (id 3)")
	assert_true(ts.has_source(SOURCE_GRASS), "yard TileSet has the grass source (id 4)")


## The fine-cobble LANE is painted as a RIBBON into the PathLane layer, AND the ground
## cell beneath each lane cell is ERASED in FloorTiles — exactly ONE tile-class per cell,
## no stacked-z, no z-fight (AC9 / html5-export.md §Z-index). This is the load-bearing
## anti-z-fight invariant: assert that EVERY painted lane cell has empty ground beneath.
func test_lane_painted_with_ground_erased_beneath_no_zfight() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var lane: TileMapLayer = inst.get_node("PathLane")
	var floor_tiles: TileMapLayer = inst.get_node("FloorTiles")
	assert_not_null(lane, "PathLane layer present")
	assert_not_null(floor_tiles, "FloorTiles layer present")
	if lane == null or floor_tiles == null:
		return
	var lane_cells: int = 0
	for cell: Vector2i in lane.get_used_cells():
		assert_eq(
			lane.get_cell_source_id(cell),
			SOURCE_PATH,
			"lane cell %s painted with the fine-cobble path source" % str(cell)
		)
		# THE AC9 INVARIANT: no ground underneath a lane cell (one tile-class per cell).
		assert_eq(
			floor_tiles.get_cell_source_id(cell),
			-1,
			(
				"ground ERASED beneath lane cell %s — one tile-class per cell, no z-fight (AC9)"
				% str(cell)
			)
		)
		lane_cells += 1
	# The spine + links + apron paint a meaningful ribbon, not zero cells.
	assert_gt(lane_cells, 30, "the lane paints a real wayfinding ribbon (got %d)" % lane_cells)


## The lane spine runs west→east — assert lane cells exist near the WEST edge (spawn gate)
## AND near the EAST edge (descent), so the path is a continuous wayfinding ribbon spanning
## the journey, not a disconnected blob.
func test_lane_spine_spans_west_to_east() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var lane: TileMapLayer = inst.get_node("PathLane")
	if lane == null:
		return
	var has_west: bool = false
	var has_east: bool = false
	for cell: Vector2i in lane.get_used_cells():
		if cell.x <= 2:
			has_west = true
		if cell.x >= YARD_W - 3:
			has_east = true
	assert_true(has_west, "lane reaches the WEST spawn-gate edge")
	assert_true(has_east, "lane reaches the EAST descent edge (journey span)")


## v3 PATH-LEGIBILITY PIN (Sponsor 2026-06-08 "the path must READ as a path"). The lane
## must be ONE CONNECTED component (a continuous ribbon you can walk west→east), not a
## scatter of disconnected cobble cells. 4-connectivity flood-fill from any west-edge lane
## cell must reach an east-edge lane cell AND cover (nearly) all lane cells. A regression
## that fragments the lane into islands (the rejected scatter read) fails this loudly.
func test_lane_is_one_connected_ribbon_west_to_east() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var lane: TileMapLayer = inst.get_node("PathLane")
	if lane == null:
		return
	var lane_set := {}
	var west_seed := Vector2i(-1, -1)
	for cell: Vector2i in lane.get_used_cells():
		lane_set[cell] = true
		if west_seed == Vector2i(-1, -1) and cell.x <= 2:
			west_seed = cell
	assert_ne(west_seed, Vector2i(-1, -1), "lane has a west-edge seed cell")
	if west_seed == Vector2i(-1, -1):
		return
	# 4-connectivity flood fill from the west seed over the lane cells.
	var seen := {west_seed: true}
	var queue: Array[Vector2i] = [west_seed]
	var head := 0
	var reached_east := false
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		if cur.x >= YARD_W - 3:
			reached_east = true
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if lane_set.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	assert_true(reached_east, "lane is connected west→east (one walkable ribbon, not islands)")
	# (Nearly) ALL lane cells are in the one component — no orphan lane islands. Allow a
	# tiny slack for the well-spur tip if the gentle dip leaves it 1 cell detached.
	var coverage: float = float(seen.size()) / float(maxi(lane_set.size(), 1))
	assert_gt(
		coverage, 0.95, "≥95%% of lane cells are in ONE connected ribbon (got %.1f%%)" % (coverage * 100.0)
	)


## The lane never runs through a building footprint (a path doesn't cross a solid wall).
func test_lane_cells_never_inside_a_building() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var lane: TileMapLayer = inst.get_node("PathLane")
	if lane == null:
		return
	for cell: Vector2i in lane.get_used_cells():
		for foot: Rect2i in _building_footprints():
			assert_false(
				foot.has_point(cell), "lane cell %s must NOT be inside building %s" % [cell, foot]
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


## REGRESSION GUARD PL-PATH-04 (v2, the rejection guard). The twice-rejected
## floor_sandstone.png + the thrice-rejected ashlar slab are dead. The v2 fine-cobble
## LANE (floor_path.png) + the worn-DIRT field (floor_dirt.png) are walking surfaces
## that ship with ZERO baked vegetation — joints/gaps are dirt-shadow ONLY. Eye-dropper
## EVERY pixel of the shipped path + dirt atlases: warm-grey/earth always has R >= G >= B.
## A green pixel (G clearly exceeds R) is the rejected baked-vegetation class — assert NONE
## exist on the WALKING surfaces (grass is the SEPARATE green layer, tested elsewhere).
func test_walking_atlases_have_zero_green_pixels_pl_path_04() -> void:
	for atlas_path: String in [PATH_ATLAS_PATH, DIRT_ATLAS_PATH]:
		var tex: Texture2D = load(atlas_path)
		assert_not_null(tex, "%s loads" % atlas_path)
		if tex == null:
			continue
		var img: Image = tex.get_image()
		assert_not_null(img, "atlas image readable: %s" % atlas_path)
		if img == null:
			continue
		var w: int = img.get_width()
		var h: int = img.get_height()
		var green_pixels: int = 0
		for y: int in range(0, h, 2):
			for x: int in range(0, w, 2):
				var c: Color = img.get_pixel(x, y)
				# Green = G clearly dominant over BOTH R and B. Small tolerance for AA.
				if c.g > c.r + 0.02 and c.g > c.b + 0.02:
					green_pixels += 1
		assert_eq(
			green_pixels,
			0,
			(
				(
					"PL-PATH-04: walking atlas %s must have ZERO green pixels (the rejected baked"
					+ " moss-dot class) — found %d. Vegetation is the SEPARATE grass ground layer,"
					+ " never baked into a walking tile."
				)
				% [atlas_path, green_pixels]
			)
		)


## The path/dirt/grass atlases are the v2 multi-variant atlases: 768x128 = 24x4 cells =
## SIX 4x4 variant-blocks (region 32x32) — the same layout as the cobble atlas, so the
## painter's [v*4 + bx, by] addressing is uniform across every ground class. A regression
## to a wrong size/region would break the variant scatter. Pin dimensions + region.
func test_ground_atlases_are_multi_variant_geometry() -> void:
	for atlas_path: String in [PATH_ATLAS_PATH, DIRT_ATLAS_PATH, GRASS_ATLAS_PATH]:
		var tex: Texture2D = load(atlas_path)
		assert_not_null(tex, "%s loads" % atlas_path)
		if tex == null:
			continue
		# 6 variants * 128px = 768 wide; 128 tall (a 4x4 atlas of 32px cells per variant).
		assert_eq(tex.get_width(), 768, "%s 768px wide (6 variant-blocks of 128px)" % atlas_path)
		assert_eq(tex.get_height(), 128, "%s 128px tall (4 rows of 32px cells)" % atlas_path)
	# The .tres declares 32x32 regions over the path/dirt/grass sources.
	var ts: TileSet = load(YARD_TILESET_PATH)
	if ts == null:
		return
	for src_id: int in [SOURCE_PATH, SOURCE_DIRT, SOURCE_GRASS]:
		var src: TileSetAtlasSource = ts.get_source(src_id) as TileSetAtlasSource
		assert_not_null(src, "source %d is a TileSetAtlasSource" % src_id)
		if src != null:
			assert_eq(
				src.texture_region_size,
				Vector2i(32, 32),
				"source %d region size = 32px tile" % src_id
			)


## The lane scatters MULTIPLE atlas variants (the repeat-break, spec §2.4) — a single
## repeated stamp down the lane is the rejected grid read. Assert the painted lane cells
## use more than one variant (variant = atlas_col / 4).
func test_lane_scatters_multiple_variants_no_single_stamp() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var lane: TileMapLayer = inst.get_node("PathLane")
	if lane == null:
		return
	var variants_seen := {}
	for cell: Vector2i in lane.get_used_cells():
		var coords: Vector2i = lane.get_cell_atlas_coords(cell)
		if coords.x < 0:
			continue
		variants_seen[coords.x / 4] = true  # 6 variant-blocks of 4 cols each
	assert_gt(
		variants_seen.size(),
		1,
		(
			"the lane must scatter MULTIPLE fine-cobble variants (no single repeating stamp —"
			+ " spec §2.4 anti-grid), got %d" % variants_seen.size()
		)
	)


## The lane atlas column addressing must stay in-bounds: variant in [0,6), local col in
## [0,4), so atlas col = v*4 + bx ∈ [0,24). Pin every painted lane cell's atlas coords
## within the 24x4 atlas (catches an off-by-one in the variant/local mapping).
func test_lane_atlas_coords_in_bounds() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var lane: TileMapLayer = inst.get_node("PathLane")
	if lane == null:
		return
	for cell: Vector2i in lane.get_used_cells():
		var coords: Vector2i = lane.get_cell_atlas_coords(cell)
		assert_between(coords.x, 0, 23, "lane atlas col in [0,24) for cell %s" % str(cell))
		assert_between(coords.y, 0, 3, "lane atlas row in [0,4) for cell %s" % str(cell))


## The fine-cobble LANE reads PERCEPTIBLY WARMER + LIGHTER than the surrounding ground
## (the PL-PATH-02 "walk here" wayfinding contrast, spec §2.3). The path doctrine base
## #7E7460 is warmer+lighter than the ground cobble #6E665A AND the dirt #6B5A41. Pin
## that the path atlas mean luminance EXCEEDS the dirt atlas mean (so the lane stands out
## against the dirt-majority ground it threads), proving the contrast didn't collapse.
func test_lane_reads_lighter_than_dirt_ground_pl_path_02() -> void:
	var path_tex: Texture2D = load(PATH_ATLAS_PATH)
	var dirt_tex: Texture2D = load(DIRT_ATLAS_PATH)
	if path_tex == null or dirt_tex == null:
		return
	var path_lum: float = _atlas_mean_luminance(path_tex.get_image())
	var dirt_lum: float = _atlas_mean_luminance(dirt_tex.get_image())
	assert_gt(
		path_lum,
		dirt_lum,
		(
			"the fine-cobble LANE must read LIGHTER than the dirt ground (PL-PATH-02 walk-here"
			+ " contrast) — path lum %.3f vs dirt lum %.3f" % [path_lum, dirt_lum]
		)
	)


## Mean perceptual luminance of an atlas image (stride-sampled). Helper for PL-PATH-02.
func _atlas_mean_luminance(img: Image) -> float:
	if img == null:
		return 0.0
	var w: int = img.get_width()
	var h: int = img.get_height()
	var acc: float = 0.0
	var n: int = 0
	for y: int in range(0, h, 4):
		for x: int in range(0, w, 4):
			var c: Color = img.get_pixel(x, y)
			acc += 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
			n += 1
	return acc / float(maxi(n, 1))


## The GRASS atlas IS green (it is the deliberate-planting reclamation layer, v2 §3/§5) —
## the complement of PL-PATH-04: the walking surfaces ship ZERO green, but the grass
## GROUND material must actually read green (a regression generating a grey grass tile
## would silently strip the reclamation read). Assert a substantial fraction of grass
## pixels are green-dominant (G >= R and G >= B).
func test_grass_atlas_is_actually_green() -> void:
	var tex: Texture2D = load(GRASS_ATLAS_PATH)
	assert_not_null(tex, "floor_grass.png loads")
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null:
		return
	var w: int = img.get_width()
	var h: int = img.get_height()
	var green: int = 0
	var total: int = 0
	for y: int in range(0, h, 2):
		for x: int in range(0, w, 2):
			var c: Color = img.get_pixel(x, y)
			total += 1
			if c.g >= c.r and c.g >= c.b:
				green += 1
	# The grass tile is overwhelmingly green-dominant (olive-to-mid greens).
	assert_gt(
		float(green) / float(maxi(total, 1)),
		0.80,
		(
			"grass atlas is the GREEN reclamation layer (got %.1f%% green-dominant)"
			% (100.0 * green / total)
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
