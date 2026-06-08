extends Node2D
class_name S1YardChunk
## Painter for the S1 open cloister-YARD chunk (ticket 86ca5erzk T4; v2 ground-
## composition RE-DO 86ca5hwmx; #426 FINER-CELL soak-rev; v5 AUTOTILE-TERRAIN ground).
## Paints an OPEN, VARIED ground expanse — NOT the four-walls-boxing-the-screen room
## model — into the `GroundTerrain` + `FloorTiles` + `PathLane` TileMapLayers at `_ready`.
##
## SPATIAL MODEL (the pivot — s1-cloister-yard.md §2): the yard is ONE big open
## traversable expanse, WIDER + TALLER than the 480x270 viewport so the camera scrolls
## in BOTH axes. There is NO perimeter wall ring. Buildings are landmark STRUCTURES.
##
## v5 AUTOTILE-TERRAIN GROUND (Sponsor-approved 2026-06-08: the procedural dirt/grass
## ground is RETIRED — Sponsor "looks like crap" after 7 bounces. New pipeline = AI-gen
## Wang transition tilesets + Godot autotile). The dirt↔grass BASE is now painted via
## `set_cells_terrain_connect` over a doctrine-locked Wang TERRAIN TileSet
## (`s1_dirtgrass_terrain.tres`, corner-match Wang, 32px). Godot AUTO-SELECTS the soft
## blended edge tile per corner pattern → the Stardew/Graveyard-Keeper soft dirt↔grass
## blend WITHOUT a hand-rolled dither. The grass was doctrine-locked toward the muted S1
## moss family by `tools/mute_wang_grass.py` (no more neon). This REPLACES the v4
## hash-dither full-bleed dirt/grass fields (`_paint_dirt_field`/`_paint_grass_regions`).
##
## TWO TILE GRIDS (deliberate, decoupled):
##   1. TERRAIN cell (32px) — the dirt+grass autotile base on `GroundTerrain` (z=-1). The
##      blend happens at the 32px cell boundary, exactly as in the inspiration refs (the
##      Wang tiles ARE 32px). Painted over the LOGICAL 40x24 grid directly.
##   2. FINE cell (16px) — the cobble APRON + the fine-cobble LANE on `FloorTiles`/
##      `PathLane` (z=0), the loved procedural cobble. The lane's dip/edges resolve at the
##      16px fine grid (the #426 "chunky corners" fix). These OPAQUE layers render OVER the
##      terrain base (z-ordered, NOT stacked at equal z) → exactly one VISIBLE class per
##      cell, no z-fight (AC9). The cobble STONE size is unchanged (continuous 128px-period
##      addressing; `fx % ATLAS_FINE_PERIOD`).
##
## THE LANE / APRON are the LOVED procedural cobble (NOT the weak Wang cobble — the
## green-skewed gravelly Wang dirt↔cobble was rejected by the orch gen review). The cobble
## surface stays `floor_cobble.png` / `floor_path.png`. Only the dirt/grass BASE switched
## to the autotile terrain.
##
## V3 STRUCTURE (carried, Sponsor "no structure ... just chaos"): dirt-MAJORITY base, ONE
## deliberate fine-cobble LANE, GRASS only at the authored margins, COBBLE only as the well
## apron. The terrain autotile renders that structure with soft blended edges; it does not
## change the hand-placed layout (`grass_regions`, the lane spine, `well_apron`).
##
## Why a script-painter: TileMapLayer serialises painted cells as a binary PackedByteArray
## that is impossible to diff-review. Painting in `_ready` is deterministic, diff-readable,
## and GUT-testable.
##
## COLLISION IS DECOUPLED: building collision is the StaticBody2D nodes built here (in
## LOGICAL-tile world rects); this script paints only the *visual* ground. NO floor collision.

# Atlas-source ids inside s1_cloister_yard.tres (the 16px FINE-cell cobble/wall TileSet).
const SOURCE_COBBLE: int = 0  # surviving-paving COBBLE patches (well apron only, v3)
const SOURCE_WALL_FINE: int = 1
# the cobble LANE (floor_path.png = Sponsor-approved AI weathered cobble, v5).
const SOURCE_PATH: int = 2
# Sources 3 (dirt) + 4 (grass) remain DECLARED in the .tres for back-compat but are NO
# LONGER painted into FloorTiles — the dirt+grass BASE moved to the GroundTerrain autotile
# layer (s1_dirtgrass_terrain.tres) in v5. They stay so the existing atlas-geometry GUT
# pins (zero-green / multi-variant) keep guarding the procedural assets if ever re-deployed.

# v5 AUTOTILE TERRAIN (s1_dirtgrass_terrain.tres, corner-match Wang): one terrain set, two
# terrains. The painter paints DIRT everywhere then GRASS in the authored regions via
# set_cells_terrain_connect → Godot auto-selects the soft blended corner tile.
const DG_TERRAIN_SET: int = 0
const DG_TERRAIN_DIRT: int = 0
const DG_TERRAIN_GRASS: int = 1

## LOGICAL tile size (px) — the world/spawn/port/ChunkDef contract. UNCHANGED at 32px.
const TILE_PX: float = 32.0

## FINER-CELL revision (#426): the painter renders at `CELL_SUBDIV`x-finer cells so the
## path/region GEOMETRY resolves in small steps (the Sponsor "chunky corners" fix). 2x →
## a 16px fine cell (TILE_PX / CELL_SUBDIV). The TileSet cell size matches (16px).
const CELL_SUBDIV: int = 2
const FINE_CELL_PX: float = TILE_PX / float(CELL_SUBDIV)  # 16.0

## Each ground atlas is 768x128 = 6 variant-blocks, each variant a 128px-square seamless
## toroidal tile. Sliced at the 16px fine cell, one variant spans 8x8 fine cells
## (128/16). Continuous world-coord addressing wraps onto this period so the seamless
## 128px texture reconstructs with ZERO block seam — and the STONE size stays 128 world-px
## (the finer cell does NOT shrink the stones; it only resolves geometry finer).
const ATLAS_FINE_PERIOD: int = 8  # 128px variant / 16px fine cell

## The path atlas is the same 6-variant 768x128 layout; the lane scatters variants per
## (now-finer) BLOCK so it never reads a repeating stamp (spec §2.4). A path block is one
## variant tile = ATLAS_FINE_PERIOD fine cells wide.
const PATH_VARIANTS: int = 6
const COBBLE_VARIANTS: int = 6

## The finer-brick wall is a 128px atlas (now 8x8 of 16px cells). Building bricks address
## it by the fine world coord wrapped into the 8-cell period so coursing flows continuously.
const WALL_FINE_PERIOD: int = 8  # 128px wall atlas / 16px fine cell

## Width (in FINE cells) of the dither band that feathers the well-apron COBBLE edge into
## the terrain ground (the dirt/grass blend is now Godot autotile; this remains only for the
## apron's soft cobble→ground edge). ~3 fine cells ≈ 48 world-px. Across the band,
## P(keep-cobble) ramps 1.0 (interior) → 0.0 (outside), dithered per fine cell.
const BLEND_BAND_CELLS: int = 3

## Yard grid in LOGICAL tiles (32px). 40x24 @ 32px = 1280x768 world — the size_tiles the
## ChunkDef + assembler + camera-bounds all assume (pinned by the GUT test). @export so a
## downstream T7 chunk-extension can author a different size without a code edit.
@export var grid_w: int = 40
@export var grid_h: int = 24

## Seed for the per-block lane/cobble variant scatter (the repeat-break hash). Fixed so
## the yard's variant layout is deterministic across boots. NOT the per-character seed.
@export var cobble_seed: int = 1763

## Seed for the feathered DITHER on the cobble lane-edge + well-apron-edge (the soft cobble→
## ground feather). Deterministic per boot. (The dirt↔grass blend is now Godot autotile.)
@export var grass_seed: int = 2207

## HAND-PLACED GRASS REGIONS (v5) in LOGICAL tiles (x,y,w,h). Grass reclaims ONLY the OUTER
## edges/corners — a FEW LARGE, SOLID blocks, NOT thin strips or mid-field scatter. v5 lesson
## (in-game gate): the Wang transition tile rings each grass patch with a soft blended edge,
## so SMALL/THIN grass regions become all-edge blobs (no solid interior) that read as a busy
## cliff-scatter. LARGE solid blocks (≥6x6) give the autotile a clean solid-grass INTERIOR
## (the wang_15 center tile) with ONE soft blend ring at the perimeter — the Stardew/
## Graveyard-Keeper "grass reclaims the corner" read. Diff-reviewable data.
## v6 APPROVED-LAYOUT (s1-yard-layout-design.md §3.7, PR #430). Grass reclaims the OUTER
## corners as a FEW LARGE solid blocks (≥6x6 so the autotile gets a clean solid interior +
## ONE soft blend ring — the v5 lesson). Re-anchored away from the §3.1 building footprints
## (chapel NW 0-7×0-2, dormitory S 0-14×21-23, central 26-29×0-3, outbuilding 38-39×2-3) so
## grass fills the open corners between landmarks, not under a building.
@export var grass_regions: Array[Rect2i] = [
	Rect2i(0, 4, 8, 8),  # W edge below the chapel — large solid block
	Rect2i(31, 6, 9, 8),  # E edge below the outbuilding / NE-of-mid
	Rect2i(0, 14, 9, 7),  # SW corner above the dormitory (wettest, grassiest)
	Rect2i(32, 17, 8, 7),  # SE corner
]

## Surviving-COBBLE apron region (v6) in LOGICAL tiles — the worn paved ring around the WELL
## at (12,17). s1-yard-layout-design.md §3.3: a 4x4 worn apron x10-13, y16-18 (the most-worn
## ground — everyone drew water). Its outer ring feathers into the ground on the dither band.
@export var well_apron: Rect2i = Rect2i(10, 16, 4, 4)

## Building footprints in LOGICAL tiles (x,y,w,h) — the APPROVED-LAYOUT landmark structures
## (s1-yard-layout-design.md §3.1). The painter builds a matching StaticBody2D per footprint
## (walk-AROUND solid); the VISUAL is the PixelLab iso/oblique building Sprite2D placed in the
## .tscn (NOT painted brick — the v6 building-asset layer, s1-yard-building-assets.md §4). The
## dormitory footprint Rect2i(0,21,15,3) is covered by TWO distinct ruin sprites (left x0-7 +
## right x7-14) per the orch decision, but the collision is ONE solid over the full footprint.
@export var building_footprints: Array[Rect2i] = [
	Rect2i(0, 0, 8, 3),  # Chapel + bell-tower — NW-corner-at-spawn anchor (§3.1)
	Rect2i(0, 21, 15, 3),  # Dormitory ruin — S edge, wider+offset-east (§3.1; 2 ruin sprites)
	Rect2i(26, 0, 4, 4),  # Central cloister building — high, off-center, lit S window (§3.1)
	Rect2i(38, 2, 2, 2),  # Far outbuilding — tiny east-horizon depth anchor (§3.1)
]

## WELL-HEAD landmark in LOGICAL tiles (x,y,w,h) — solid base under the .tscn well sprite.
## s1-yard-layout-design.md §3.3: center tile (12,17), collision footprint x11-13,y16-18 (3x3).
@export var well_footprint: Rect2i = Rect2i(11, 16, 3, 3)

## SPRING / damp seep (§3.3) — a small water-accent patch x14-15,y16-17 (2x2) between the well
## and the garden (the most-reclaimed corner). Still dark warm-neutral ColorRect pools.
@export var spring_tiles: Array[Vector2i] = [
	Vector2i(14, 16),  # the damp seep beside the well apron (§3.3)
]

## GARDEN BED gone wild (§3.3) — ONE hero bed of tilled-soil-gone-to-weeds near the dormitory
## range, x19-20,y18-20 (2x3). Off-path discovery beat.
@export var garden_bed: Rect2i = Rect2i(19, 18, 2, 3)

## S1_YARD_WATER_DOCTRINE (Uma §3.3) — still, dark, warm-neutral, sub-1.0, NEVER pure-black.
const WATER_BASE := Color(0.180, 0.165, 0.149, 1.0)  # #2E2A26 dark warm-neutral still surface
const WATER_HIGHLIGHT := Color(0.522, 0.486, 0.424, 1.0)  # #857C6C sparse still catch
const GARDEN_SOIL := Color(0.329, 0.271, 0.184, 0.78)  # #54452F soil, semi-transparent

## Fine-grid dimensions (derived). The painter iterates these; geometry decisions map a
## fine cell back to its fractional LOGICAL tile.
var _fw: int = 0
var _fh: int = 0

@onready var _ground_terrain: TileMapLayer = $GroundTerrain
@onready var _floor_tiles: TileMapLayer = $FloorTiles
@onready var _path_lane: TileMapLayer = $PathLane
@onready var _springs: Node2D = $Springs
@onready var _buildings: TileMapLayer = $Buildings
@onready var _building_bodies: Node2D = $BuildingBodies
@onready var _well_body: Node2D = $WellBody
@onready var _decoration: Node2D = $Decoration


func _ready() -> void:
	_fw = grid_w * CELL_SUBDIV
	_fh = grid_h * CELL_SUBDIV
	# Layer order (deliberate, hand-placed):
	#   1. GROUND TERRAIN (z=-1) — dirt+grass autotile BASE: paint dirt everywhere, then
	#      grass in the authored edge/corner regions via set_cells_terrain_connect → Godot
	#      auto-selects the soft blended corner tile (the v5 Stardew/Graveyard-Keeper blend).
	#   2. WELL APRON (z=0) — surviving LOVED-cobble paved ring around the well, soft edge.
	#   3. LANE  (z=0) — the one clear fine-cobble PATH ribbon (finer-resolved dip), soft edge.
	# Later: building bricks, well/spring/garden/apron decoration.
	_paint_ground_terrain()
	_paint_well_apron()
	_paint_path_lane()
	_build_structures()
	_build_well_collision()
	_paint_springs()
	_paint_garden_bed()
	_paint_building_aprons()
	_scatter_decoration()


# ---- PASS 1: dirt+grass AUTOTILE TERRAIN base (v5) ----------------------------


## Paint the dirt+grass BASE on the GroundTerrain layer (z=-1) via Godot autotile. Paint
## DIRT across the WHOLE logical grid, then GRASS in the authored edge/corner regions, both
## through `set_cells_terrain_connect` — Godot then AUTO-SELECTS the soft blended Wang
## corner tile wherever dirt meets grass (the v5 Stardew/Graveyard-Keeper blend, no hand
## dither). Painted at the 32px LOGICAL grid (the Wang terrain tiles ARE 32px; the blend
## happens at cell scale, exactly as in the inspiration refs).
func _paint_ground_terrain() -> void:
	if _ground_terrain == null:
		push_warning("S1YardChunk: GroundTerrain TileMapLayer missing — cannot paint ground")
		return
	# 1. DIRT everywhere (the dirt-majority base).
	var dirt_cells: Array[Vector2i] = []
	for ty in range(grid_h):
		for tx in range(grid_w):
			dirt_cells.append(Vector2i(tx, ty))
	_ground_terrain.set_cells_terrain_connect(dirt_cells, DG_TERRAIN_SET, DG_TERRAIN_DIRT, false)
	# 2. GRASS in the authored margin regions (Godot auto-blends the dirt↔grass corners).
	var grass_cells: Array[Vector2i] = _grass_region_cells()
	if not grass_cells.is_empty():
		_ground_terrain.set_cells_terrain_connect(
			grass_cells, DG_TERRAIN_SET, DG_TERRAIN_GRASS, false
		)


## The LOGICAL-tile cells covered by the authored grass regions (the yard margins/corners).
## Hand-placed at the edges ONLY (no mid-field scatter — the v3 anti-chaos structure). Pure
## (GUT-pinnable): deterministic from `grass_regions`.
func _grass_region_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var seen: Dictionary = {}
	for region: Rect2i in grass_regions:
		for ty in range(region.position.y, region.position.y + region.size.y):
			for tx in range(region.position.x, region.position.x + region.size.x):
				if tx < 0 or tx >= grid_w or ty < 0 or ty >= grid_h:
					continue
				var c := Vector2i(tx, ty)
				if not seen.has(c):
					seen[c] = true
					cells.append(c)
	return cells


# ---- PASS 2: surviving-COBBLE well apron (LOVED cobble, feathered edge) --------


## The surviving-COBBLE well APRON (the LOVED procedural cobble, NOT the weak Wang cobble).
## Cobble appears in FloorTiles ONLY here — a deliberate paved ring around the well, painted
## at z=0 OVER the terrain dirt/grass base. The well_footprint interior is left unpaved (the
## well prop occupies it). The apron's OUTER ring feathers out (leaves FloorTiles empty so
## the terrain ground shows through) for a soft edge, not a hard rect. Uses the cobble atlas
## with per-block variant scatter (high-freq stones mask any variant edge). 16px fine-grid.
func _paint_well_apron() -> void:
	if _floor_tiles == null:
		return
	var ax0: int = well_apron.position.x * CELL_SUBDIV
	var ay0: int = well_apron.position.y * CELL_SUBDIV
	var ax1: int = (well_apron.position.x + well_apron.size.x) * CELL_SUBDIV - 1
	var ay1: int = (well_apron.position.y + well_apron.size.y) * CELL_SUBDIV - 1
	for fy in range(ay0, ay1 + 1):
		for fx in range(ax0, ax1 + 1):
			if fx < 0 or fx >= _fw or fy < 0 or fy >= _fh:
				continue
			# Leave the well's own footprint interior unpaved (the well prop sits there).
			if _logical_rect_has_fine(well_footprint, fx, fy):
				continue
			# Feather the apron's outer ring: depth from the apron edge, dither. A dropped
			# cell leaves FloorTiles empty here so the terrain dirt/grass base shows through
			# (z=-1) — a soft apron edge, not a hard cobble rectangle.
			var d: int = min(min(fx - ax0, ax1 - fx), min(fy - ay0, ay1 - fy))
			if d < BLEND_BAND_CELLS:
				var p_keep: float = float(d + 1) / float(BLEND_BAND_CELLS + 1)
				if _fine_dither(Vector2i(fx, fy)) >= p_keep:
					continue  # feathered out — terrain ground shows through (soft apron edge)
			var block_x: int = fx / ATLAS_FINE_PERIOD
			var block_y: int = fy / ATLAS_FINE_PERIOD
			var variant: int = _block_variant(block_x, block_y)
			var atlas := _scatter_atlas_coords(variant, fx, fy)
			_floor_tiles.set_cell(Vector2i(fx, fy), SOURCE_COBBLE, atlas)


## Continuous atlas coords for a SCATTERED-variant surface (cobble apron / path lane): the
## chosen `variant` block, addressed by the FINE world cell wrapped into the 8-fine-cell
## period → constant stone size, seamless within the block. Pure.
func _scatter_atlas_coords(variant: int, fx: int, fy: int) -> Vector2i:
	var local_x: int = ((fx % ATLAS_FINE_PERIOD) + ATLAS_FINE_PERIOD) % ATLAS_FINE_PERIOD
	var local_y: int = ((fy % ATLAS_FINE_PERIOD) + ATLAS_FINE_PERIOD) % ATLAS_FINE_PERIOD
	return Vector2i(variant * ATLAS_FINE_PERIOD + local_x, local_y)


## True if FINE cell (fx,fy) falls inside a LOGICAL-tile rect. Pure helper.
func _logical_rect_has_fine(rect: Rect2i, fx: int, fy: int) -> bool:
	var lx0: int = rect.position.x * CELL_SUBDIV
	var ly0: int = rect.position.y * CELL_SUBDIV
	var lx1: int = (rect.position.x + rect.size.x) * CELL_SUBDIV - 1
	var ly1: int = (rect.position.y + rect.size.y) * CELL_SUBDIV - 1
	return fx >= lx0 and fx <= lx1 and fy >= ly0 and fy <= ly1


## Fine high-frequency dither in [0,1] for the seamless-blend feather. Deterministic
## (grass_seed). Pure function.
func _fine_dither(cell: Vector2i) -> float:
	var h: int = ((cell.x * 2654435761) ^ (cell.y * 40503) ^ (grass_seed * 2246822519)) & 0x7fffffff
	return float(h % 1000) / 1000.0


# ---- PASS 3: the fine-cobble LANE (LOVED cobble, finer-resolved dip + soft edges) ---


## v6 APPROVED-LAYOUT spine (s1-yard-layout-design.md §3.2): the worn cobble LANE follows the
## ROUTED polyline — NOT a parametric sine dip. It enters low-west at the spawn, turns UP, runs
## the upper-center rise, then the FORK splits: the MAIN line (S4) curves east-and-down to the
## exit, and the SOUTH link (S3b) drops to the WELL. The lane is the v5 loved cobble (PathLane),
## reconciled to route the approved spine + fork (orch decision #3 — no separate slab spine).
## 2 LOGICAL tiles wide (= 4 fine cells) per the §3.2 "2 tiles wide" spec. Cells inside a
## building/well footprint are EXCLUDED (a path never crosses a solid wall). Returns
## Dictionary{Vector2i(fine): true}. All segment endpoints are in LOGICAL tiles → fine via x2.
func _compute_lane_cells() -> Dictionary:
	var cells: Dictionary = {}
	# §3.2 routed polyline in LOGICAL tiles (a 2-tile-wide ribbon stamped along each segment):
	#   S1 spawn approach: (0,12)→(4,12) then turn UP (4,12)→(4,8)
	#   S2 the rise:       (4,8)→(22,8)            (upper-center run, long east sightline)
	#   S4 main→exit:      (22,8)→(28,8)→(28,11)→(36,11)→(36,12)→(39,12)  (curve E-and-down to port)
	#   S3b south→well:    (22,8)→(22,13)→(14,13)→(14,16)                 (drops + curves to the well apron)
	var spine_pts: Array[Vector2i] = [
		Vector2i(0, 12), Vector2i(4, 12), Vector2i(4, 8), Vector2i(22, 8),
		Vector2i(28, 8), Vector2i(28, 11), Vector2i(36, 11), Vector2i(36, 12), Vector2i(39, 12),
	]
	_stamp_polyline(cells, spine_pts, 2)  # 2 logical tiles wide
	var well_link: Array[Vector2i] = [
		Vector2i(22, 8), Vector2i(22, 13), Vector2i(14, 13), Vector2i(14, 16),
	]
	_stamp_polyline(cells, well_link, 2)
	# Soft path edge (#426 / Stardew): feather the OUTERMOST rim of the stamped ribbon into the
	# ground so the lane edge softens (keep ~65%, drop ~35% on the dither) WITHOUT reading
	# ragged. Applied as a post-pass on rim cells (a cell with <4 lane neighbours is a rim cell).
	_feather_lane_rim(cells)
	return cells


## Stamp a 2-tile-wide (= width_tiles*CELL_SUBDIV fine cells) ribbon along the polyline of
## LOGICAL-tile waypoints into `cells`. Each consecutive pair is walked in fine-cell steps
## (axis-aligned segments — the §3.2 polyline is rectilinear) and a square brush of the band
## width is stamped at each step so corners stay connected. Pure-ish (writes into `cells`).
func _stamp_polyline(cells: Dictionary, pts: Array[Vector2i], width_tiles: int) -> void:
	var half: int = (width_tiles * CELL_SUBDIV) / 2  # 2 fine cells either side for width 2
	for i in range(pts.size() - 1):
		var a := Vector2i(pts[i].x * CELL_SUBDIV, pts[i].y * CELL_SUBDIV)
		var b := Vector2i(pts[i + 1].x * CELL_SUBDIV, pts[i + 1].y * CELL_SUBDIV)
		var steps: int = maxi(absi(b.x - a.x), absi(b.y - a.y))
		for s in range(steps + 1):
			var t: float = float(s) / float(maxi(steps, 1))
			var cx: int = int(round(lerp(float(a.x), float(b.x), t)))
			var cy: int = int(round(lerp(float(a.y), float(b.y), t)))
			# Square brush so corners fill (a 90° turn keeps a solid elbow, not a 1px hinge).
			for dy in range(-half, half + 1):
				for dx in range(-half, half + 1):
					_add_lane_cell(cells, cx + dx, cy + dy)


## Feather the lane's outer rim into the surrounding ground (Stardew soft path edge). A fine
## lane cell with fewer than 4 orthogonal lane neighbours is a RIM cell; drop ~35% of rim cells
## on the dither so the edge softens without reading ragged. The solid interior is untouched
## (≥4 lane neighbours always kept). Mutates `cells`.
func _feather_lane_rim(cells: Dictionary) -> void:
	var rim_drop: Array[Vector2i] = []
	for cell: Vector2i in cells:
		var neighbours: int = 0
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if cells.has(cell + d):
				neighbours += 1
		if neighbours < 4 and _fine_dither(cell) >= 0.65:
			rim_drop.append(cell)
	for cell: Vector2i in rim_drop:
		cells.erase(cell)


## Add a lane FINE cell at (fx,fy) IF in-bounds and NOT inside a building/well footprint.
## #426 SOFT EDGE: the OUTERMOST lane band (the top/bottom fine row of the 6-wide band)
## probabilistically falls back to dirt on the dither so the path edge feathers into the
## surrounding earth (Stardew/Graveyard-Keeper soft path edge), instead of a hard cobble cut.
func _add_lane_cell(cells: Dictionary, fx: int, fy: int) -> void:
	if fx < 0 or fx >= _fw or fy < 0 or fy >= _fh:
		return
	for foot: Rect2i in building_footprints:
		if _logical_rect_has_fine(foot, fx, fy):
			return
	if _logical_rect_has_fine(well_footprint, fx, fy):
		return
	cells[Vector2i(fx, fy)] = true


## Paint the fine-cobble LANE (LOVED cobble) into PathLane (z=0) AND erase any FloorTiles
## cobble-apron cell beneath (AC9: exactly ONE VISIBLE cobble-class per cell — where the lane
## crosses the apron, only the lane shows). The dirt/grass TERRAIN base (z=-1) is left intact
## beneath the lane: the lane's opaque cobble renders over it (z-ordered), so the lane reads
## as a path THROUGH the ground exactly as in the refs. The soft path edge is applied in
## `_compute_lane_cells` (the outermost spine band feathers out). Variant scatter (per FINE
## block) keeps the lane from reading a repeating stamp (§2.4).
func _paint_path_lane() -> void:
	if _path_lane == null or _floor_tiles == null:
		push_warning("S1YardChunk: PathLane/FloorTiles missing — cannot paint the lane")
		return
	var cells: Dictionary = _compute_lane_cells()
	for cell: Vector2i in cells:
		var block_x: int = cell.x / ATLAS_FINE_PERIOD
		var block_y: int = cell.y / ATLAS_FINE_PERIOD
		var variant: int = _path_block_variant(block_x, block_y)
		var atlas := _scatter_atlas_coords(variant, cell.x, cell.y)
		_path_lane.set_cell(cell, SOURCE_PATH, atlas)
		# Erase any apron-cobble beneath → one VISIBLE cobble-class per cell (AC9). The
		# terrain dirt/grass base on GroundTerrain (z=-1) is NOT touched — the opaque lane
		# renders over it (the path-through-ground read).
		_floor_tiles.set_cell(cell, -1)


## Pick a path variant [0, PATH_VARIANTS) for a fine BLOCK via a non-tiling hash. Distinct
## prime mix from _block_variant so the lane + ground variant fields don't realign. Pure.
func _path_block_variant(block_x: int, block_y: int) -> int:
	var h: int = (block_x * 49979693) ^ (block_y * 86028157) ^ (cobble_seed * 6151)
	return absi(h) % PATH_VARIANTS


## Pick a cobble variant [0, COBBLE_VARIANTS) for a fine BLOCK via a non-tiling hash. Pure.
func _block_variant(block_x: int, block_y: int) -> int:
	var h: int = (block_x * 73856093) ^ (block_y * 19349663) ^ (cobble_seed * 83492791)
	return absi(h) % COBBLE_VARIANTS


# ---- Structures, collision, decoration (LOGICAL-tile world rects) -------------


## Build the cloister BUILDINGS as solid landmark structures: add a StaticBody2D per footprint
## (walk-AROUND collision). v6: the VISUAL is the PixelLab iso/oblique building Sprite2D placed
## in the .tscn (s1-yard-building-assets.md §4) — the painter NO LONGER paints finer-brick into
## the `Buildings` TileMapLayer (the flat brick read flat + clashed with the iso sprite mass).
## Collision only here; the `Buildings` TileMapLayer stays in the scene tree (empty) for back-
## compat with the node skeleton, but is no longer painted.
func _build_structures() -> void:
	for foot: Rect2i in building_footprints:
		_add_building_collision(foot)


## Add a StaticBody2D + RectangleShape2D over a building footprint (LOGICAL-tile world rect)
## so the building is solid (walk-around). World position is UNCHANGED from 23ca119 (the
## finer cell does not move buildings — collision is in world px from the logical footprint).
func _add_building_collision(foot: Rect2i) -> void:
	if _building_bodies == null:
		return
	var body := StaticBody2D.new()
	body.name = "Building_%d_%d" % [foot.position.x, foot.position.y]
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(foot.size.x * TILE_PX, foot.size.y * TILE_PX)
	shape.shape = rect
	body.position = Vector2(
		(foot.position.x + foot.size.x * 0.5) * TILE_PX,
		(foot.position.y + foot.size.y * 0.5) * TILE_PX
	)
	body.add_child(shape)
	_building_bodies.add_child(body)


## Build the well-head collision — a StaticBody2D over `well_footprint` (LOGICAL-tile world
## rect, position UNCHANGED). Walk-AROUND solid like the buildings.
func _build_well_collision() -> void:
	if _well_body == null:
		return
	var foot := well_footprint
	var body := StaticBody2D.new()
	body.name = "WellHeadBody"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(foot.size.x * TILE_PX, foot.size.y * TILE_PX)
	shape.shape = rect
	body.position = Vector2(
		(foot.position.x + foot.size.x * 0.5) * TILE_PX,
		(foot.position.y + foot.size.y * 0.5) * TILE_PX
	)
	body.add_child(shape)
	_well_body.add_child(body)


## Paint the SPRING pools (T8) — still dark warm-neutral ColorRect pools (sub-1.0, NEVER
## pure-black). Positions in LOGICAL-tile world px (UNCHANGED). NO Polygon2D, NO tween, NO
## moss_patch sprites (the #426 spiky-prop "trash" class was removed — water is the feature).
func _paint_springs() -> void:
	if _springs == null:
		return
	for center: Vector2i in spring_tiles:
		var cx: float = (float(center.x) + 0.5) * TILE_PX
		var cy: float = (float(center.y) + 0.5) * TILE_PX
		var pool := ColorRect.new()
		pool.color = WATER_BASE
		pool.size = Vector2(TILE_PX * 1.6, TILE_PX * 1.4)
		pool.position = Vector2(cx - pool.size.x * 0.5, cy - pool.size.y * 0.5)
		_springs.add_child(pool)
		var glint := ColorRect.new()
		glint.color = WATER_HIGHLIGHT
		glint.size = Vector2(TILE_PX * 0.5, TILE_PX * 0.28)
		glint.position = Vector2(cx - glint.size.x * 0.5, cy - TILE_PX * 0.35)
		_springs.add_child(glint)


## Paint the GARDEN BED gone wild (T8) — ONE hero damp-soil ColorRect bed (LOGICAL-tile world
## px, UNCHANGED). The moss_patch overgrowth was removed (#426 spiky-prop "trash" class).
func _paint_garden_bed() -> void:
	if _springs == null:
		return
	var bed := garden_bed
	var soil := ColorRect.new()
	soil.color = GARDEN_SOIL
	soil.size = Vector2(bed.size.x * TILE_PX, bed.size.y * TILE_PX)
	soil.position = Vector2(bed.position.x * TILE_PX, bed.position.y * TILE_PX)
	_springs.add_child(soil)


## Damp shadow aprons at building south bases (T8) — a subtle dark ColorRect strip grounding
## each building into the yard (LOGICAL-tile world px, UNCHANGED). NO moss_patch tufts (#426).
func _paint_building_aprons() -> void:
	if _springs == null:
		return
	for foot: Rect2i in building_footprints:
		var apron_y: int = foot.position.y + foot.size.y
		if apron_y >= grid_h:
			continue  # building runs to the grid edge (off-frame) — no visible south base
		var apron := ColorRect.new()
		apron.color = Color(0.16, 0.15, 0.13, 0.32)  # damp-shadow darken, sub-1.0, low alpha
		apron.size = Vector2(foot.size.x * TILE_PX, TILE_PX * 0.6)
		apron.position = Vector2(foot.position.x * TILE_PX, apron_y * TILE_PX)
		_springs.add_child(apron)


## Yard decoration. INTENTIONALLY a NO-OP (Sponsor scale soak, PR #424): the prior moss_patch
## tuft scatter read as oversized ugly spiky blobs. The vegetation story is carried by the
## grass GROUND material; T3 owns proper proportional ground-vegetation props.
func _scatter_decoration() -> void:
	pass
