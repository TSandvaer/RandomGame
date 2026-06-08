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
##   2. The yard chunk scene paints the v5 AUTOTILE ground (dirt+grass base via
##      set_cells_terrain_connect over a doctrine-locked corner-Wang terrain TileSet —
##      Godot auto-selects the soft blended edge tile; the loved cobble lane + well apron
##      on top), builds the authored building structures (visual brick + StaticBody2D).
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

const SOURCE_COBBLE: int = 0  # surviving-paving cobble patches (v2; well apron on FloorTiles)
const SOURCE_WALL_FINE: int = 1
const SOURCE_PATH: int = 2  # fine-cobble LANE source (v2, replaces the dead slab)
const SOURCE_DIRT: int = 3  # worn-dirt atlas (DECLARED for asset pins; not painted in v5)
const SOURCE_GRASS: int = 4  # grass atlas (DECLARED for asset pins; not painted in v5)

# v5 AUTOTILE TERRAIN (s1_dirtgrass_terrain.tres). The dirt+grass BASE moved off FloorTiles
# onto the GroundTerrain layer, painted via set_cells_terrain_connect over a corner-Wang
# terrain set. terrain 0 = dirt, 1 = grass. The all-dirt Wang tile is atlas (2,1) (bbox
# 64,32 / 32 = col2,row1 = wang_0 all-lower); the all-grass tile is (0,3) (wang_15 all-upper).
const DG_TERRAIN_TILESET_PATH: String = "res://resources/tilesets/s1_dirtgrass_terrain.tres"
const DG_ATLAS_PATH: String = "res://assets/tilesets/s1_cloister/wang_dirtgrass.png"
# v5 Sponsor-approved AI weathered-cobble lane source (seamless via tools/seamless_cobble.py;
# packed into floor_path.png 6-variant atlas via tools/build_path_cobble_atlas.py).
const AI_COBBLE_PATH: String = "res://assets/tilesets/s1_cloister/floor_cobble_ai.png"
const DG_ALL_DIRT_ATLAS := Vector2i(2, 1)  # wang_0 (all 4 corners dirt)
const DG_ALL_GRASS_ATLAS := Vector2i(0, 3)  # wang_15 (all 4 corners grass)

# Well-head footprint mirror (matches S1YardChunk.well_footprint) — the nav grid bakes this as
# a wall too (the well is a solid walk-AROUND landmark, like buildings). v6 APPROVED-LAYOUT
# (s1-yard-layout-design.md §3.3): well at tile (12,17), collision footprint x11-13,y16-18 (3x3).
const WELL_FOOTPRINT := Rect2i(11, 16, 3, 3)

# S1_YARD_WATER_DOCTRINE / path doctrine eye-dropper hexes (Uma §2.4 / §3.3) — pinned
# so a regression that recolours the doctrine surfaces fails loudly. Values are the
# painter-side constants (water ColorRect) + the spec's named hexes for documentation.
const WATER_BASE_HEX := "2e2a26"  # PL-WATER-01 dark warm-neutral (NOT pure-black PL-WATER-02)

# Yard grid in LOGICAL tiles (must match S1YardChunk.grid_w/grid_h + s1_yard_slice.tres
# size_tiles + the ChunkDef contract). The WORLD is unchanged at 40x24 logical 32px tiles.
const YARD_W: int = 40
const YARD_H: int = 24
const TILE_PX: float = 32.0

# #426 FINER-CELL revision: the painter renders at a CELL_SUBDIV-finer grid (2x → 16px fine
# cells) so path/region geometry resolves in small smooth steps. The painted TileMapLayer
# cell coords are now in FINE cells (0..79 x 0..47); the cell-inspection tests iterate the
# fine grid. The ATLAS period is 8 fine cells (128px variant / 16px cell). The atlas PNGs
# are UNCHANGED (same 768x128 stones); only the .tres cell geometry got finer.
const CELL_SUBDIV: int = 2
const FINE_W: int = YARD_W * CELL_SUBDIV  # 80
const FINE_H: int = YARD_H * CELL_SUBDIV  # 48
const ATLAS_FINE_PERIOD: int = 8  # 128px variant / 16px fine cell

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


## Instantiate the chunk AND await a frame so the GroundTerrain set_cells_terrain_connect
## autotile result commits (the terrain buffer commits on the frame after the paint —
## verified empirically; reading get_used_cells() in the same synchronous block returns 0).
## Tests that inspect GroundTerrain MUST use this async variant.
func _instantiate_yard_chunk_committed() -> Node:
	var inst: Node = _instantiate_yard_chunk()
	await get_tree().process_frame
	await get_tree().process_frame
	return inst


## Count the GroundTerrain cells whose atlas coords resolve to dirt-corner vs grass-corner.
## A cell is "grassy" if its selected Wang tile has ANY grass corner (i.e. it is NOT the
## all-dirt tile); "dirt" if it is the all-dirt tile. Returns {dirt, grass, total}.
func _ground_terrain_counts(gt: TileMapLayer) -> Dictionary:
	var dirt := 0
	var grass := 0
	for c: Vector2i in gt.get_used_cells():
		if gt.get_cell_atlas_coords(c) == DG_ALL_DIRT_ATLAS:
			dirt += 1
		else:
			grass += 1  # any non-all-dirt Wang tile carries grass (center or blend)
	return {"dirt": dirt, "grass": grass, "total": gt.get_used_cells().size()}


func _collect_nodes(root: Node, of_type: String) -> Array:
	var out: Array = []
	if root.get_class() == of_type:
		out.append(root)
	for child in root.get_children():
		out.append_array(_collect_nodes(child, of_type))
	return out


# Building footprints (in tiles) mirrored from S1YardChunk.building_footprints — the nav grid
# bakes these as walls so the BFS reflects a grunt pathing AROUND the solid buildings. v6
# APPROVED-LAYOUT (s1-yard-layout-design.md §3.1): chapel NW-corner / dormitory S-edge-wider /
# central high-off-center / outbuilding tiny-east-horizon.
func _building_footprints() -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	out.append(Rect2i(0, 0, 8, 3))  # chapel + bell-tower
	out.append(Rect2i(0, 21, 15, 3))  # dormitory ruin (2 sprites, 1 collision)
	out.append(Rect2i(26, 0, 4, 4))  # central cloister building
	out.append(Rect2i(38, 2, 2, 2))  # far outbuilding
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


## v5 AUTOTILE GROUND (86ca5hwmx, Sponsor-approved AI-gen Wang + Godot autotile). The dirt+
## grass BASE is painted on the GroundTerrain layer via set_cells_terrain_connect — EVERY
## logical cell (40x24) is painted (no holes), and every painted cell resolves to a valid
## Wang atlas tile (source 0 of the terrain TileSet). FloorTiles now holds ONLY the cobble
## apron + lane-erasures (no dirt/grass). Pin: GroundTerrain covers the whole grid; FloorTiles
## holds only valid cobble (or empty).
func test_yard_chunk_paints_full_autotile_ground_base() -> void:
	var inst: Node = await _instantiate_yard_chunk_committed()
	var gt: TileMapLayer = inst.get_node("GroundTerrain")
	var floor_tiles: TileMapLayer = inst.get_node("FloorTiles")
	assert_not_null(gt, "GroundTerrain TileMapLayer present")
	if gt == null or floor_tiles == null:
		return
	# Every logical cell painted on GroundTerrain (no holes in the open expanse).
	assert_eq(
		gt.get_used_cells().size(),
		YARD_W * YARD_H,
		"GroundTerrain paints EVERY logical cell (40x24=960, no holes)"
	)
	# Every painted terrain cell resolves to a real Wang atlas tile (source 0, coords valid).
	for c: Vector2i in gt.get_used_cells():
		assert_eq(gt.get_cell_source_id(c), 0, "terrain cell %s uses the Wang source (0)" % str(c))
		var a: Vector2i = gt.get_cell_atlas_coords(c)
		assert_between(a.x, 0, 3, "terrain atlas col in [0,4) for %s" % str(c))
		assert_between(a.y, 0, 3, "terrain atlas row in [0,4) for %s" % str(c))
	# FloorTiles holds ONLY cobble (the apron) where painted — never dirt/grass anymore.
	for c: Vector2i in floor_tiles.get_used_cells():
		assert_eq(
			floor_tiles.get_cell_source_id(c),
			SOURCE_COBBLE,
			"FloorTiles holds ONLY the cobble apron (v5 moved dirt/grass to the terrain layer)"
		)


## v5 §3 + Sponsor "cobblestone should only be parts": the autotiled ground is DIRT-MAJORITY
## with GRASS as PARTS (reclaimed corners). Pin the composition over GroundTerrain cells: the
## all-dirt Wang tile dominates (>55%), grass-bearing tiles (center + blend) are a minority
## (<40%), and BOTH are genuinely present. A regression to a grass-carpet (or all-dirt with no
## reclamation) fails loudly.
func test_ground_composition_is_dirt_majority_grass_is_parts() -> void:
	var inst: Node = await _instantiate_yard_chunk_committed()
	var gt: TileMapLayer = inst.get_node("GroundTerrain")
	if gt == null:
		return
	var counts: Dictionary = _ground_terrain_counts(gt)
	var total: int = counts["total"]
	assert_gt(total, 0, "terrain has painted cells")
	var dirt_frac: float = float(counts["dirt"]) / float(total)
	var grass_frac: float = float(counts["grass"]) / float(total)
	assert_gt(dirt_frac, 0.55, "dirt is the MAJORITY ground (got %.1f%%)" % (dirt_frac * 100.0))
	assert_lt(
		grass_frac, 0.40, "grass+blend is a PART, not the majority (got %.1f%%)" % (grass_frac * 100.0)
	)
	assert_gt(counts["dirt"], 0, "all-dirt tiles present (the open field)")
	assert_gt(counts["grass"], 0, "grass-bearing tiles present (reclamation corners + blend)")


## v5 STRUCTURE PIN (Sponsor "no structure ... just chaos"; carried). Grass is HAND-PLACED at
## the OUTER corners ONLY — the OPEN MID-FIELD (a central band away from the rim) is entirely
## the all-dirt Wang tile (zero grass-bearing tiles). A regression to mid-field grass scatter
## (the rejected chaos, or an autotile mis-wire that grasses the centre) fails loudly.
func test_ground_grass_only_at_corners_none_in_mid_field() -> void:
	var inst: Node = await _instantiate_yard_chunk_committed()
	var gt: TileMapLayer = inst.get_node("GroundTerrain")
	if gt == null:
		return
	# Mid-field probe box in LOGICAL cells: cols 14..26 / rows 9..15 (the open centre, clear of
	# the v6 grass regions W-below-chapel(0,4,8,8) E(31,6,9,8) SW(0,14,9,7) SE(32,17,8,7)). Every
	# cell here must be the all-dirt Wang tile (no grass corner).
	var mid_grass := 0
	for ty in range(9, 16):
		for tx in range(14, 27):
			if gt.get_cell_atlas_coords(Vector2i(tx, ty)) != DG_ALL_DIRT_ATLAS:
				mid_grass += 1
	assert_eq(
		mid_grass,
		0,
		(
			"NO grass-bearing tiles in the open mid-field (logical cols 14-26, rows 9-15) —"
			+ " grass is hand-placed at the corners only (got %d)" % mid_grass
		)
	)
	# Grass IS present in the DEEP INTERIOR of each v6 grass region (the all-grass Wang tile).
	# Probes are ≥1 cell inside each region edge so all 4 corners are grass.
	var corner_grass := 0
	for probe: Vector2i in [Vector2i(3, 7), Vector2i(35, 10), Vector2i(4, 17), Vector2i(35, 20)]:
		if gt.get_cell_atlas_coords(probe) == DG_ALL_GRASS_ATLAS:
			corner_grass += 1
	assert_gt(
		corner_grass, 0, "grass reclaims the corners (solid all-grass Wang interior present)"
	)


## v5 AUTOTILE BLEND PIN (Sponsor-approved soft dirt↔grass blend). At a grass region's edge
## the autotile must select BLEND tiles (Wang tiles with MIXED corners — neither all-dirt nor
## all-grass), proving the dirt↔grass boundary is the soft Godot-autotiled corner blend
## (Stardew/Graveyard-Keeper), not a hard cut. Scan a band straddling the NW region's east
## edge (logical col ~8-9) and require ≥1 mixed-corner Wang tile.
func test_ground_dirt_grass_boundary_uses_blend_tiles() -> void:
	var inst: Node = await _instantiate_yard_chunk_committed()
	var gt: TileMapLayer = inst.get_node("GroundTerrain")
	if gt == null:
		return
	# v6 W region is logical Rect2i(0,4,8,8) → east edge at col 7/8. Scan cols 6..10 rows 5..11
	# (a band straddling the dirt↔grass boundary).
	var blend_tiles := 0
	for ty in range(5, 12):
		for tx in range(6, 11):
			var a: Vector2i = gt.get_cell_atlas_coords(Vector2i(tx, ty))
			if a != DG_ALL_DIRT_ATLAS and a != DG_ALL_GRASS_ATLAS:
				blend_tiles += 1
	assert_gt(
		blend_tiles,
		0,
		(
			"the dirt↔grass boundary selects BLEND Wang tiles (mixed corners) — the soft Godot"
			+ " autotile transition, not a hard cut (v5 Stardew/Graveyard-Keeper blend)"
		)
	)


## v5 GRASS-MUTE PIN (the doctrine-lock — Sponsor: grass muted/mossy, NOT neon). The shipped
## Wang atlas's grass must read MUTED OLIVE-green (the moss family ~88° hue, sat <0.70), NOT
## the raw PixelLab NEON green (~123° hue, sat ~0.97). Sample the green-dominant pixels and
## assert their mean saturation is muted + their mean hue is olive-shifted off pure green.
func test_wang_grass_is_muted_not_neon() -> void:
	var tex: Texture2D = load(DG_ATLAS_PATH)
	assert_not_null(tex, "wang_dirtgrass.png loads")
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null:
		return
	var w: int = img.get_width()
	var h: int = img.get_height()
	var sat_acc := 0.0
	var hue_acc := 0.0
	var n := 0
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			var c: Color = img.get_pixel(x, y)
			# green-dominant pixel (the grass).
			if c.g > c.r + 0.008 and c.g > c.b + 0.008:
				sat_acc += c.s
				hue_acc += c.h * 360.0
				n += 1
	assert_gt(n, 0, "atlas has grass pixels to sample")
	var mean_sat: float = sat_acc / float(maxi(n, 1))
	var mean_hue: float = hue_acc / float(maxi(n, 1))
	# Muted: mean saturation well below the raw neon ~0.97 (doctrine-lock crushed it).
	assert_lt(
		mean_sat,
		0.70,
		"grass is MUTED (mean sat %.2f < 0.70 — not the raw neon ~0.97)" % mean_sat
	)
	# Olive-shifted: mean hue pulled OFF pure green (123°) toward the moss family (~88-100°).
	assert_lt(
		mean_hue,
		115.0,
		"grass hue olive-shifted toward moss (mean %.1f deg < 115 — off neon-green 123)" % mean_hue
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


## v6 APPROVED-LAYOUT: the Buildings TileMapLayer is NO LONGER painted (the painter dropped
## finer-brick — the flat brick read flat + clashed with the iso building sprites). The building
## VISUAL is now the BuildingSprites group of PixelLab iso/oblique structure Sprite2Ds. Pin:
## Buildings layer EMPTY + BuildingSprites has the 5 building sprites (chapel + 2 dormitory ruins
## + central + outbuilding) using the s1_yard building textures.
func test_buildings_are_iso_sprites_not_painted_brick() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var buildings: TileMapLayer = inst.get_node("Buildings")
	var sprites_root: Node = inst.get_node("BuildingSprites")
	assert_not_null(buildings, "Buildings TileMapLayer present (empty, back-compat skeleton)")
	assert_not_null(sprites_root, "BuildingSprites group present")
	if buildings == null or sprites_root == null:
		return
	# Buildings layer paints NOTHING now (iso sprites carry the visual).
	assert_eq(
		buildings.get_used_cells().size(),
		0,
		"Buildings TileMapLayer is EMPTY — buildings are iso Sprite2D landmarks now (v6)"
	)
	# 5 building sprites, each using an s1_yard building texture.
	var sprites: Array = _collect_nodes(sprites_root, "Sprite2D")
	assert_eq(sprites.size(), 5, "5 building sprites (chapel + 2 dorm ruins + central + outbuilding)")
	var expected_textures := {
		"chapel_belltower.png": false,
		"dormitory_ruin_left.png": false,
		"dormitory_ruin_right.png": false,
		"cloister_central.png": false,
		"outbuilding_far.png": false,
	}
	for spr: Sprite2D in sprites:
		if spr.texture == null:
			continue
		var path: String = spr.texture.resource_path
		for key: String in expected_textures.keys():
			if path.ends_with(key):
				expected_textures[key] = true
				# Buildings are z=+1 group (BuildingSprites z_index=1); centered=false (footprint
				# top-left anchoring per s1-yard-building-assets.md §4).
				assert_false(spr.centered, "%s anchored top-left (centered=false)" % key)
	for key: String in expected_textures.keys():
		assert_true(expected_textures[key], "building sprite present: %s" % key)


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
	# Sources 3+4 (dirt/grass atlases) stay DECLARED for back-compat asset pins.
	assert_true(ts.has_source(SOURCE_DIRT), "yard TileSet has the worn-dirt source (id 3)")
	assert_true(ts.has_source(SOURCE_GRASS), "yard TileSet has the grass source (id 4)")
	# v5: the dirt+grass BASE is now the autotile TERRAIN TileSet (a separate resource). It
	# must load + carry one corner-match terrain set with 2 terrains (dirt + grass).
	var dg: TileSet = load(DG_TERRAIN_TILESET_PATH)
	assert_not_null(dg, "dirt/grass terrain TileSet loads")
	if dg != null:
		assert_eq(dg.get_terrain_sets_count(), 1, "terrain TileSet has one terrain set")
		assert_eq(
			dg.get_terrain_set_mode(0),
			TileSet.TERRAIN_MODE_MATCH_CORNERS,
			"terrain set is corner-match (Wang)"
		)
		assert_eq(dg.get_terrains_count(0), 2, "terrain set has dirt + grass terrains")


## The fine-cobble LANE is painted as a RIBBON into the PathLane layer, AND any cobble-apron
## cell beneath each lane cell is ERASED in FloorTiles — exactly ONE VISIBLE COBBLE-class per
## cell, no z-fight (AC9 / html5-export.md §Z-index). The dirt/grass TERRAIN base (z=-1) is
## intentionally left intact beneath the lane — the opaque lane renders OVER it (z-ordered),
## the path-through-ground read. This pins that no apron-cobble fights the lane-cobble.
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
	# The spine + spur paint a meaningful ribbon. At the FINE grid the lane is ~6 fine cells
	# wide x ~160 fine cols (minus building skips + soft-edge feather), so hundreds of cells.
	assert_gt(lane_cells, 200, "the lane paints a real wayfinding ribbon (got %d)" % lane_cells)


## The lane spine runs west→east — assert lane cells exist near the WEST edge (spawn gate)
## AND near the EAST edge (descent), so the path is a continuous wayfinding ribbon spanning
## the journey, not a disconnected blob.
func test_lane_spine_spans_west_to_east() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var lane: TileMapLayer = inst.get_node("PathLane")
	if lane == null:
		return
	# West/east edges in FINE cells (#426): west fx ≤ 2, east fx ≥ FINE_W - 3.
	var has_west: bool = false
	var has_east: bool = false
	for cell: Vector2i in lane.get_used_cells():
		if cell.x <= 2:
			has_west = true
		if cell.x >= FINE_W - 3:
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
		if cur.x >= FINE_W - 3:
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
		coverage,
		0.95,
		"≥95%% of lane cells are in ONE connected ribbon (got %.1f%%)" % (coverage * 100.0)
	)


## The lane never runs through a building footprint (a path doesn't cross a solid wall).
func test_lane_cells_never_inside_a_building() -> void:
	var inst: Node = _instantiate_yard_chunk()
	var lane: TileMapLayer = inst.get_node("PathLane")
	if lane == null:
		return
	# Lane cells are FINE cells (#426); footprints are LOGICAL tiles. Convert each footprint
	# to its fine-cell rect and assert no lane fine cell falls inside.
	for cell: Vector2i in lane.get_used_cells():
		for foot: Rect2i in _building_footprints():
			var fine_foot := Rect2i(foot.position * CELL_SUBDIV, foot.size * CELL_SUBDIV)
			assert_false(
				fine_foot.has_point(cell),
				"lane fine cell %s must NOT be inside building (fine %s)" % [cell, fine_foot]
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


## REGRESSION GUARD (v5). The DIRT walking field must stay ZERO-green (no baked moss-dot
## scatter — the twice-rejected class). The DIRT atlas joints/gaps are dirt-shadow ONLY.
## NOTE (v5 Sponsor-approved cobble swap): the LANE atlas (floor_path.png) is now the AI
## weathered cobble whose grout IS mossy green — Sponsor explicitly approved that look, so the
## lane is INTENTIONALLY excluded from the zero-green guard (the green there is real grout in a
## crafted tile, not a baked-vegetation scatter). The grass GROUND is a separate layer.
func test_dirt_field_has_zero_green_pixels() -> void:
	var tex: Texture2D = load(DIRT_ATLAS_PATH)
	assert_not_null(tex, "%s loads" % DIRT_ATLAS_PATH)
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null:
		return
	var w: int = img.get_width()
	var h: int = img.get_height()
	var green_pixels: int = 0
	for y: int in range(0, h, 2):
		for x: int in range(0, w, 2):
			var c: Color = img.get_pixel(x, y)
			if c.g > c.r + 0.02 and c.g > c.b + 0.02:
				green_pixels += 1
	assert_eq(
		green_pixels,
		0,
		(
			"the DIRT walking field %s must have ZERO green pixels (no baked moss-dot scatter)"
			% DIRT_ATLAS_PATH
			+ " — found %d. The grass GROUND is a separate autotile layer." % green_pixels
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
	# #426 FINER CELL: the .tres now declares 16px regions (was 32px) over the path/dirt/grass
	# sources — the atlas PNGs are UNCHANGED (768x128 stones); only the cell geometry got finer.
	var ts: TileSet = load(YARD_TILESET_PATH)
	if ts == null:
		return
	for src_id: int in [SOURCE_PATH, SOURCE_DIRT, SOURCE_GRASS]:
		var src: TileSetAtlasSource = ts.get_source(src_id) as TileSetAtlasSource
		assert_not_null(src, "source %d is a TileSetAtlasSource" % src_id)
		if src != null:
			assert_eq(
				src.texture_region_size,
				Vector2i(16, 16),
				"source %d region size = 16px fine cell (#426)" % src_id
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
		variants_seen[coords.x / ATLAS_FINE_PERIOD] = true  # 6 variant-blocks of 8 fine cols
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
	# At the finer grid the atlas is 6 variants x 8 fine cols = [0,48) cols, 8 rows = [0,8).
	for cell: Vector2i in lane.get_used_cells():
		var coords: Vector2i = lane.get_cell_atlas_coords(cell)
		assert_between(coords.x, 0, 47, "lane atlas col in [0,48) for cell %s" % str(cell))
		assert_between(coords.y, 0, 7, "lane atlas row in [0,8) for cell %s" % str(cell))


## The cobble LANE reads PERCEPTIBLY LIGHTER than the surrounding dirt ground (the PL-PATH-02
## "walk here" wayfinding contrast). v5: the lane is now the Sponsor-approved AI weathered
## cobble (floor_path.png rebuilt from floor_cobble_ai.png) — grey-tan stone, mean luminance
## ~107 vs the dark dirt ~84, so the lane still stands out against the dirt-majority ground.
## Pin that the path atlas mean luminance EXCEEDS the dirt mean (contrast didn't collapse).
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


## v5 AI-COBBLE LANE SOURCE PIN (Sponsor-approved this round). The seamless AI weathered
## cobble (floor_cobble_ai.png) ships + is the lane source. Pin: it loads, is 256x256, AND
## carries mossy grout (some green-dominant pixels — the approved look, distinct from the
## zero-green DIRT field). A regression that loses the AI cobble or strips its grout fails here.
func test_ai_cobble_lane_source_present_with_grout() -> void:
	var tex: Texture2D = load(AI_COBBLE_PATH)
	assert_not_null(tex, "AI weathered-cobble lane source loads: %s" % AI_COBBLE_PATH)
	if tex == null:
		return
	assert_eq(tex.get_width(), 256, "AI cobble is 256px wide")
	assert_eq(tex.get_height(), 256, "AI cobble is 256px tall")
	var img: Image = tex.get_image()
	if img == null:
		return
	var green := 0
	for y: int in range(0, 256, 4):
		for x: int in range(0, 256, 4):
			var c: Color = img.get_pixel(x, y)
			if c.g > c.r + 0.02 and c.g > c.b + 0.02:
				green += 1
	assert_gt(green, 0, "AI cobble carries mossy grout (Sponsor-approved green grout in the lane)")


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
