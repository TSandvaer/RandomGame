extends Node2D
class_name S1YardChunk
## Painter for the S1 open cloister-YARD chunk (ticket 86ca5erzk T4; v2 ground-
## composition RE-DO 86ca5hwmx; Uma s1-cloister-yard.md + s1-ground-composition-v2.md).
## Paints an OPEN, VARIED ground expanse — NOT the four-walls-boxing-the-screen room
## model — into the `FloorTiles` + `PathLane` TileMapLayers at `_ready`. The cloister
## BUILDINGS (collision structures) + their finer-brick visual + the carried-forward
## props live in the .tscn; this script paints the procedural ground + the lane on top
## so the wide yard never reads a tile-repeat.
##
## SPATIAL MODEL (the pivot — s1-cloister-yard.md §2): the yard is ONE big open
## traversable expanse, WIDER + TALLER than the 480x270 viewport so the camera scrolls
## in BOTH axes (the "big + endless" read). There is NO perimeter wall ring. Buildings
## are landmark STRUCTURES standing IN the expanse, set back with open ground running
## PAST them toward a soft scroll-horizon.
##
## V3 GROUND COMPOSITION — HAND-PLACED STRUCTURE (Sponsor 2026-06-08, FOURTH bounce on
## the v2 procedural-SCATTER render). Sponsor verbatim: "there is no structure to the
## tiles, it's just chaos." The v2 design noise-SCATTERED grass across the whole grid +
## strewed 5 cobble patches through the mid-field → the render read as random noise, not a
## yard. The references (inspiration/2026-06-08_11h18_12 Graveyard Keeper + 11h19_36
## Stardew) have STRUCTURE: a smooth dirt field, ONE deliberate path, grass only at the
## margins. So v3 DROPS the random scatter entirely and HAND-PLACES every material:
##   1. DIRT (source 3) = the SMOOTH continuous base field across the WHOLE yard. Painted
##      as ONE seamless wrapped variant (`_paint_dirt_field`) so the field reads as one
##      continuous expanse — NO per-block variant swap (that was the visible ~256px block-
##      seam grid in the v2 render: two different toroidal tiles don't mate at their shared
##      edge, and a smooth dirt field has no high-freq texture to hide the discontinuity).
##   2. PATH (source 2) = ONE clear, continuous, DELIBERATE fine-cobble LANE, hand-placed
##      as a connected ribbon along the route (spawn-gate WEST → curving → descent EAST),
##      3 tiles wide (`_compute_lane_cells`). The single most important structure element —
##      the path must READ as a path. Painted into PathLane, ground erased beneath (AC9).
##   3. GRASS (source 4) = ONLY at the OUTER edges / corners / margins, as a FEW deliberate
##      hand-placed regions with soft feathered borders (`_is_grass_cell` over authored
##      `grass_regions`, NOT a noise field across the middle). Reclaiming the borders.
##   4. COBBLE (source 0) = the well apron ONLY (a deliberate paved ring around the well),
##      nowhere else. NO mid-field cobble scatter (that was the chaos). The path lane is the
##      only OTHER cobble, and it lives in PathLane.
##   - Soft transitions between materials (feathered grass borders); AC9 one-class-per-cell.
##
## Why a script-painter: TileMapLayer serialises painted cells as a binary PackedByteArray
## that is impossible to diff-review. Painting via `set_cell` in `_ready` is deterministic,
## diff-readable, and GUT-testable.
##
## COLLISION IS DECOUPLED: building collision is the StaticBody2D nodes in the .tscn; this
## script paints only the *visual* ground. The open yard ground has NO floor collision
## (the player walks the whole expanse; only the building/well footprints + walls block).
##
## NO BAKED VEGETATION (spec §5 — the rule that killed the rejected paths): every WALKING
## tile (dirt / path-cobble / cobble-patch) ships ZERO green pixels. Grass is a SEPARATE
## composed GROUND material (source 4), painted as feathered patches, never baked speckle
## and never the rejected spiky moss_patch prop (`_scatter_decoration` stays a no-op).

# Atlas-source ids inside s1_cloister_yard.tres (v2 ground-composition, 86ca5hwmx).
const SOURCE_COBBLE: int = 0  # surviving-paving COBBLE patches (LOVED gen, ~10-20%)
const SOURCE_WALL_FINE: int = 1
## Source 2 = the v2 FINE-COBBLE LANE (`floor_path.png`, 86ca5hwmx; Uma
## s1-ground-composition-v2.md §2). REPLACES the dead ashlar slab (`floor_slab.png`,
## third rejection) + the twice-rejected `floor_sandstone.png`. The SAME loved Voronoi
## cobble tech, tuned FINER (largest stone ~10-14px, finer than the ground cobble) +
## WARMER+LIGHTER (S1_PATH_COBBLE_DOCTRINE) for the "walk here" path-vs-ground contrast.
## ZERO baked green. A 768x128 MULTI-VARIANT atlas (6 variant-blocks of 4x4 32px cells,
## variant v = cols [v*4 .. v*4+3]) — same packed layout as cobble, so the lane painter
## scatters variants per block to break the repeating stamp down the lane (spec §2.4).
const SOURCE_PATH: int = 2
## Path atlas: 6 variant-blocks, each a 4x4 grid of 32px cells (period 4 within a block).
const PATH_BLOCK_TILES: int = 4  # one path variant-block spans 4x4 game tiles
const PATH_VARIANTS: int = 6  # number of variant-blocks packed in the path atlas

## Source 3 = worn-DIRT field (`floor_dirt.png`, v2 §3) — the new MAJORITY ground
## (~55-65%). Stone-free toroidal-noise worn earth, ZERO green. The default ground a
## monastery yard mostly is (trodden bare earth — Graveyard-Keeper ref).
const SOURCE_DIRT: int = 3
## Source 4 = GRASS reclamation tile (`floor_grass.png`, v2 §3) — ~20-30%, edges/
## corners/shadowed bases (where feet DIDN'T fall, nature took back). A clean green
## GROUND material (the deliberate-planting foundation), painted as PATCHES, NOT the
## rejected spiky moss_patch prop, NOT baked into the walking tiles (spec §5). The ONLY
## green source.
const SOURCE_GRASS: int = 4

## All four ground atlases share the SAME 768x128 6-variant-block packed layout, so one
## block-period + variant-count + scatter-hash convention covers every ground class.
const GROUND_BLOCK_TILES: int = 4  # one variant-block spans 4x4 game tiles
const GROUND_VARIANTS: int = 6  # variant-blocks packed in each ground atlas

## v3 (Sponsor 2026-06-08 seam fix): the DIRT field + GRASS regions paint from ONE variant
## each, addressed CONTINUOUSLY (world coord wrapped into the variant's 4x4 cells) so a
## single seamless toroidal tile wraps onto itself with ZERO block seam. The v2 per-block
## variant SWAP produced the visible ~256px grid (two different toroidal tiles don't mate).
## A FLAT field needs toroidal-CONTINUOUS, not variant-SCATTER. (Cobble/path keep the
## scatter — their high-freq stones mask variant edges.) Variant 0 chosen arbitrarily.
const DIRT_FIELD_VARIANT: int = 0
const GRASS_FIELD_VARIANT: int = 0

## Back-compat aliases for the cobble-patch repeat-break (the surviving-paving patches
## reuse the loved cobble gen + the same per-block variant scatter as before).
const COBBLE_BLOCK_TILES: int = 4
const COBBLE_VARIANTS: int = 6

## The finer-brick wall is a 128px 4x4 atlas (period 4). Building bricks use this
## period independently of the cobble (which is now multi-variant, see above).
const WALL_ATLAS_PERIOD: int = 4

## Yard grid size in tiles. 40x24 @ 32px = 1280x768px — WIDER (1280 > 480) AND
## TALLER (768 > 270) than the viewport, so the camera scrolls in BOTH axes
## (s1-cloister-yard.md §2.1 two-axis scroll = the "big" lever). @export so a
## downstream T7 chunk-extension can author a different size without a code edit;
## the bounds the camera clamps to derive from LevelChunkDef.size_tiles, so the
## .tres size_tiles MUST match these (pinned by the GUT test).
@export var grid_w: int = 40
@export var grid_h: int = 24

## Seed for the per-block ground-variant scatter (the repeat-break hash). Fixed so
## the yard's variant layout is deterministic across boots (GUT + visual repro);
## change it to re-roll the scatter. NOT the per-character world_seed.
@export var cobble_seed: int = 1763

## Seed for the GRASS-region feathered-border STIPPLE (v3: grass is HAND-PLACED in the
## authored `grass_regions` at the yard margins; this seed only drives the per-cell
## dither that softens each region's BORDER so the dirt↔grass edge is feathered, never a
## hard rectangle). Deterministic per boot. NOT a mid-field scatter field (that was v2's
## chaos — Sponsor "no structure ... just chaos").
@export var grass_seed: int = 2207

## HAND-PLACED GRASS REGIONS (v3, Sponsor 2026-06-08). Grass reclaims ONLY the OUTER
## edges / corners / margins of the yard — a FEW deliberate regions, NOT scattered across
## the middle (the v2 noise-scatter was the chaos). Each Rect2i is (x, y, w, h) in TILES,
## authored to hug the yard rim + corners (matching the Stardew ref 11h19_36: grass at the
## margins reclaiming the borders, smooth dirt field in the middle). The region INTERIOR is
## solid grass; the OUTER ring of each region feathers back to dirt on a fine dither
## (`_is_grass_cell`) so the border is soft, never a hard tile edge. Diff-reviewable data.
@export var grass_regions: Array[Rect2i] = [
	# --- NW corner: grass reclaiming the top-left margin (above + left of the chapel range).
	Rect2i(0, 0, 7, 6),
	# --- NE corner: grass at the top-right margin (right of the chapel range, N rim).
	Rect2i(33, 0, 7, 5),
	# --- SW corner: the wettest, grassiest corner (dormitory ruin + SW spring dip).
	Rect2i(0, 18, 9, 6),
	# --- SE corner: grass at the bottom-right margin (S rim toward the descent).
	Rect2i(34, 19, 6, 5),
	# --- North rim strip: a thin grass margin along the very top edge between the corners
	#     (the unwalked top border reclaimed) — kept thin so the mid-yard stays smooth dirt.
	Rect2i(20, 0, 10, 2),
	# --- South rim strip: a thin grass margin along the very bottom edge.
	Rect2i(22, 22, 11, 2),
]

## Surviving-COBBLE apron region (v3 §4): cobble appears in the FloorTiles field ONLY as a
## deliberate paved apron ringing the well (the most-walked-and-paved spot — "everyone drew
## water here"). NO mid-field cobble scatter (that was the v2 chaos). The path LANE is the
## only OTHER cobble and it lives in PathLane. One Rect2i (x, y, w, h) in TILES around the
## well_footprint, painted in `_paint_well_apron` AFTER dirt (overwrites dirt) but the lane
## + grass + building passes still win where they overlap. Diff-reviewable.
@export var well_apron: Rect2i = Rect2i(19, 15, 4, 4)

## Building footprints — landmark STRUCTURES standing IN the open expanse
## (s1-cloister-yard.md §2.1: north range / south range / central / far
## outbuilding). Each Rect2i is (x, y, w, h) in TILES. The painter paints
## finer-brick into the `Buildings` TileMapLayer over the footprint AND builds a
## matching StaticBody2D collision rect, so a building is walk-AROUND (solid),
## NOT a teleport-room wall. Authored as data here (diff-reviewable) rather than
## hand-edited collision soup in the .tscn. Set back from the player's immediate
## space with open cobble running PAST them (Uma soft-horizon discipline §2.3) —
## the north/south ranges run to the grid edge so their far sides imply
## off-frame continuation ("a building you can't see all of reads as a bigger
## world"). The far outbuilding is small (toward the east horizon = long
## sightline / depth).
@export var building_footprints: Array[Rect2i] = [
	# North range (chapel face / bell-tower) — runs along the top, off-frame N
	# (y starts at row 0; the top courses are above the visible spawn band).
	Rect2i(8, 0, 12, 3),
	# South range (dormitory ruin) — along the bottom, off-frame S.
	Rect2i(6, 21, 14, 3),
	# Central cloister building — stands IN the expanse, splitting the open ground
	# into north + south traversal channels (set back; cobble runs both sides).
	Rect2i(18, 9, 6, 5),
	# Far, SMALL outbuilding toward the east horizon — anchors a long sightline
	# (depth / "more world that way").
	Rect2i(33, 6, 3, 3),
]

## WELL-HEAD landmark (S1-YARD T8, Uma §3.1). Footprint in TILES (x, y, w, h) — a
## south-central solid landmark OFF the processional spine at the south route-choice
## decision point. The painter builds a StaticBody2D over this (walk-AROUND, like the
## buildings) AND a worn fine-cobble apron rings it (§2.2 well-approach). The sprite itself
## is placed in the .tscn at the apron centre (688, 560 ≈ tile (21.5, 17.5)). Kept as
## data here so the nav GUT test can mirror it as a wall (parity with building_footprints).
## Footprint is the SOLID base of the well centred under the sprite, NOT the full sprite
## extent (the upper rim overhangs visually but the player collides with the base).
## SOAK-REVISION (#426): 3x3→2x2 to match the well scale drop 0.85→0.35 (the well is now
## a ~81px-wide real well a person draws from ≈1.5x player height, not a building);
## centred at tile (21,17).
@export var well_footprint: Rect2i = Rect2i(20, 16, 2, 2)

## SPRING pools (S1-YARD T8, Uma §3.2; orch handoff: ColorRect-pool, NO bespoke asset).
## Each is a damp low/shadow corner where ground water surfaces. Authored in TILES as
## (x, y) pool-centre; the painter draws a still dark warm-neutral ColorRect pool there
## drawn as just the ColorRect water pool (the moss_patch sprite ring was REMOVED in #426 —
## Sponsor flagged the green-flecked spiky moss sprites as ugly trash; water is the feature).
## Two pools: one at the north-wall base (damp shadow under the chapel range), one in the
## dip near the dormitory ruin (SW). Both sit in OPEN cobble, clear of mob spawns + the spine.
@export var spring_tiles: Array[Vector2i] = [
	Vector2i(28, 2),  # north — damp shadow under the chapel range east section
	Vector2i(9, 18),  # SW dip near the dormitory ruin
]

## GARDEN BED gone wild (S1-YARD T8, Uma §4). ONE hero bed of tilled-soil-gone-to-weeds
## near the dormitory range (south). Authored as a TILE rect; the painter tints a damp
## earth ColorRect bed (the moss_patch overgrowth clustering was REMOVED in #426 — Sponsor
## flagged those green-flecked spiky moss sprites as ugly trash). Placed in
## open cobble south of the central building, clear of the south range footprint + spawns.
@export var garden_bed: Rect2i = Rect2i(12, 17, 4, 3)

## S1_YARD_WATER_DOCTRINE (Uma §3.3) — still, dark, warm-neutral, sub-1.0 every channel,
## NEVER pure-black (PL-09). Used for the spring ColorRect pools (PL-WATER-01/02/03).
const WATER_BASE := Color(0.180, 0.165, 0.149, 1.0)  # #2E2A26 dark warm-neutral still surface
const WATER_HIGHLIGHT := Color(0.522, 0.486, 0.424, 1.0)  # #857C6C sparse still catch
## Damp earth tint for the garden bed (warm soil, sub-1.0). Doctrine dirt-through family.
const GARDEN_SOIL := Color(0.329, 0.271, 0.184, 0.78)  # #54452F soil, semi-transparent

const TILE_PX: float = 32.0

@onready var _floor_tiles: TileMapLayer = $FloorTiles
@onready var _path_lane: TileMapLayer = $PathLane
@onready var _springs: Node2D = $Springs
@onready var _buildings: TileMapLayer = $Buildings
@onready var _building_bodies: Node2D = $BuildingBodies
@onready var _well_body: Node2D = $WellBody
@onready var _decoration: Node2D = $Decoration


func _ready() -> void:
	# v3 STRUCTURED ground (Sponsor 2026-06-08 "no structure ... just chaos"): paint the
	# materials in deliberate LAYER ORDER, hand-placed, NOT a random scatter:
	#   1. DIRT  — the smooth continuous base field across the WHOLE yard (seamless).
	#   2. GRASS — overwrite dirt ONLY in the authored edge/corner regions (feathered).
	#   3. WELL APRON — overwrite with the surviving-cobble paved ring around the well.
	#   4. LANE  — the one clear fine-cobble PATH ribbon (PathLane; erases ground beneath).
	# Later: building bricks, well/spring/garden/apron decoration.
	_paint_dirt_field()
	_paint_grass_regions()
	_paint_well_apron()
	_paint_path_lane()
	_build_structures()
	_build_well_collision()
	_paint_springs()
	_paint_garden_bed()
	_paint_building_aprons()
	_scatter_decoration()


## v3 PASS 1 — paint the SMOOTH continuous DIRT base field across the WHOLE yard.
##
## SEAM FIX (Sponsor 2026-06-08 "hard square block seams forming a visible grid"): the v2
## painter swapped a DIFFERENT atlas variant per 4x4 block (`_block_variant`). Each dirt
## variant is INDIVIDUALLY toroidal-seamless (it wraps onto ITSELF), but two DIFFERENT
## toroidal tiles do NOT mate at their shared edge — variant A's right column ≠ variant B's
## left column → a hard discontinuity at every 4-tile block boundary (the ~256px grid in
## the render). The high-freq cobble texture HID this; a smooth low-freq dirt field has no
## texture to hide it, so the grid is plainly visible. The fix is to paint the dirt from
## ONE variant CONTINUOUSLY — address the atlas by the cell's WORLD coord wrapped into that
## variant's 4x4 cells (`tx % 4`, `ty % 4`). A single seamless tile wrapping onto itself
## has ZERO seam at every repeat, so the whole field reads as one continuous smooth expanse
## (the Stardew/Graveyard-Keeper dirt-field read), no block grid. (The cobble gen looked
## fine because its high-freq stones masked the variant-edge; the dirt-field variant needs
## the toroidal-CONTINUOUS discipline, not the variant-SCATTER.)
func _paint_dirt_field() -> void:
	if _floor_tiles == null:
		push_warning("S1YardChunk: FloorTiles TileMapLayer missing — cannot paint")
		return
	for ty in range(grid_h):
		for tx in range(grid_w):
			_floor_tiles.set_cell(Vector2i(tx, ty), SOURCE_DIRT, _dirt_atlas_coords(tx, ty))


## Atlas coords for the continuous DIRT field. Always variant 0 (`DIRT_FIELD_VARIANT`),
## addressed by the world coord wrapped into the variant's 4x4 cells → the single tile
## tiles seamlessly onto itself with no block seam. Pure (GUT-pinnable).
func _dirt_atlas_coords(tx: int, ty: int) -> Vector2i:
	var local_x: int = ((tx % GROUND_BLOCK_TILES) + GROUND_BLOCK_TILES) % GROUND_BLOCK_TILES
	var local_y: int = ((ty % GROUND_BLOCK_TILES) + GROUND_BLOCK_TILES) % GROUND_BLOCK_TILES
	return Vector2i(DIRT_FIELD_VARIANT * GROUND_BLOCK_TILES + local_x, local_y)


## v3 PASS 2 — overwrite dirt with GRASS in the authored edge/corner regions ONLY.
## Grass reclaims the MARGINS (Stardew ref), NOT the mid-field (the v2 scatter was chaos).
## Each region's interior is solid grass; its OUTER ring feathers back to dirt on a fine
## dither (`_is_grass_cell`) so the dirt↔grass border is soft, never a hard rectangle.
## Grass uses the SAME continuous toroidal addressing as dirt (variant 0) so a multi-tile
## grass region reads as one continuous patch (no internal block seam either).
func _paint_grass_regions() -> void:
	if _floor_tiles == null:
		return
	for ty in range(grid_h):
		for tx in range(grid_w):
			var cell := Vector2i(tx, ty)
			if _is_grass_cell(cell):
				var local_x: int = tx % GROUND_BLOCK_TILES
				var local_y: int = ty % GROUND_BLOCK_TILES
				var atlas := Vector2i(GRASS_FIELD_VARIANT * GROUND_BLOCK_TILES + local_x, local_y)
				_floor_tiles.set_cell(cell, SOURCE_GRASS, atlas)


## True if a cell is GRASS. v3: grass is HAND-PLACED in the authored `grass_regions` at the
## yard margins (NOT a noise field across the middle — that was the v2 chaos). A cell is
## grass if it is inside any region AND either (a) in the region INTERIOR (solid grass) or
## (b) on the region's OUTER ring but PASSES a fine dither (so the border feathers back to
## dirt instead of a hard rectangle edge). Deterministic (grass_seed drives only the
## border stipple). Pure function (GUT-pinnable).
func _is_grass_cell(cell: Vector2i) -> bool:
	for region: Rect2i in grass_regions:
		if not region.has_point(cell):
			continue
		# Outer-ring cell? (one tile in from any region edge.) Feather it back to dirt on a
		# fine dither so the dirt↔grass border is a soft stipple, never a clean rectangle.
		var on_ring: bool = (
			cell.x == region.position.x
			or cell.x == region.position.x + region.size.x - 1
			or cell.y == region.position.y
			or cell.y == region.position.y + region.size.y - 1
		)
		if on_ring:
			# ~55% of ring cells stay grass, ~45% feather to dirt → soft organic border.
			return _fine_dither(cell) < 0.55
		return true  # region interior = solid grass
	return false


## v3 PASS 3 — the surviving-COBBLE well APRON. Cobble appears in the FloorTiles field ONLY
## here: a deliberate paved ring around the well (the most-walked-and-paved spot). NO mid-
## field cobble scatter. Overwrites dirt/grass within `well_apron`; the well_footprint
## interior is left (the well prop/collision occupies it) and the lane pass still wins.
## Uses the cobble atlas with the per-block variant scatter (high-freq stones hide any
## variant edge across this small region — the apron is tiny, no flat-field seam risk).
func _paint_well_apron() -> void:
	if _floor_tiles == null:
		return
	var region := well_apron
	for ty in range(region.position.y, region.position.y + region.size.y):
		for tx in range(region.position.x, region.position.x + region.size.x):
			if tx < 0 or tx >= grid_w or ty < 0 or ty >= grid_h:
				continue
			# Leave the well's own footprint interior unpaved (the well prop sits there).
			if well_footprint.has_point(Vector2i(tx, ty)):
				continue
			var block_x: int = tx / COBBLE_BLOCK_TILES
			var block_y: int = ty / COBBLE_BLOCK_TILES
			var variant: int = _block_variant(block_x, block_y)
			var local_x: int = tx % COBBLE_BLOCK_TILES
			var local_y: int = ty % COBBLE_BLOCK_TILES
			var atlas := Vector2i(variant * COBBLE_BLOCK_TILES + local_x, local_y)
			_floor_tiles.set_cell(Vector2i(tx, ty), SOURCE_COBBLE, atlas)


## Fine high-frequency dither in [0,1] for the grass-region border feather. Deterministic
## (grass_seed). Pure function.
func _fine_dither(cell: Vector2i) -> float:
	var h: int = ((cell.x * 2654435761) ^ (cell.y * 40503) ^ (grass_seed * 2246822519)) & 0x7fffffff
	return float(h % 1000) / 1000.0


## Compute the set of TILE cells the FINE-COBBLE LANE occupies (v2 §2 + §6 desire-line
## map). Returns a Dictionary{Vector2i: true} so callers test membership cheaply. The
## lane is a HUMBLE worn village footpath (NOT a grand avenue — three "too big"
## rejections), the dominant wayfinding element threading the varied ground:
##   - LANE SPINE: west gate (player spawn, row 12) → curving east → the descent
##     terminus. ~2 tiles wide, curving (never ruler-straight, §2.2). It DIPS south
##     around the central building (footprint 18-23 × 9-13) so it skirts the solid
##     structure on open ground, then rises back to row 12 toward the descent.
##   - BUILDING-LINK: a short lane run from the spine N toward the central-building face.
##   - WELL APPROACH + APRON: a lane spur from the spine S to the well, ringed by a worn
##     fine-cobble apron around the well_footprint (§2.2 "everyone drew water — most-worn
##     ground"; the well apron is the surviving-paving the lane lays).
## The lane is a RIBBON (a few tiles wide), NEVER a grid/plaza (§2.2 discipline). Cells
## overlapping a building footprint are EXCLUDED (a path doesn't run through a wall).
func _compute_lane_cells() -> Dictionary:
	var cells: Dictionary = {}

	# --- THE PROCESSIONAL SPINE: ONE clear, continuous, 3-wide fine-cobble ribbon running
	# WEST (spawn gate, row 12) → curving → EAST (descent, row 12). This is the single most
	# important structure element (Sponsor 2026-06-08: "the path must READ as a path").
	# 3 tiles wide (centre row ± 1) so it is unmistakably legible as "the walkable lane",
	# not a thin track. The centre-row follows a gentle south dip across the mid-yard
	# (`_spine_center_row`) so the ribbon skirts the central building on open ground and
	# curves organically (never a ruler-straight road). HAND-PLACED as a connected ribbon —
	# every column from the west edge to the east edge gets the 3-wide band, so the lane is
	# one continuous connected path (the GUT connectivity pin asserts this).
	for tx in range(0, grid_w):
		var center_row: int = _spine_center_row(tx)
		for dy in range(-1, 2):  # centre row ± 1 → a 3-wide legible lane
			_add_lane_cell(cells, tx, center_row + dy)

	# --- WELL SPUR: a short 1-wide fine-cobble spur from the spine SOUTH down to the well
	# apron, so the well reads as ON the path network (a deliberate approach). The spur
	# joins the spine (south side) to the top of the well apron region. Connected to the
	# spine so the whole lane stays one component.
	var spur_x: int = well_footprint.position.x + 1
	var spur_top: int = _spine_center_row(spur_x) + 1
	for ty in range(spur_top, well_apron.position.y):
		_add_lane_cell(cells, spur_x, ty)

	return cells


## True spine centre-row at column tx — a gentle curve, not a straight road (§2.2).
## Anchored at row 12 (player-spawn centre / descent EAST exit y=12 → the journey line),
## dipping ~2 rows SOUTH across the mid-yard so the ribbon skirts the central building on
## open cobble + reads organic. Pure function (GUT-pinnable, deterministic).
func _spine_center_row(tx: int) -> int:
	# Gentle dip: deepest near the centre column, flat at the ends. v3 reduces the
	# amplitude 3.0→2.0 so the 3-wide lane staggers in fewer, gentler steps (a smoother
	# path edge, closer to the references' clean lanes — the prior ×3 stepped too sharply).
	# Keeps the band south of the central building (footprint south face y=13) without
	# crossing INTO it (the _add_lane_cell footprint guard also protects this).
	var t: float = float(tx) / float(maxi(grid_w - 1, 1))  # 0..1 across the yard
	var dip: float = sin(t * PI) * 2.0  # 0 at ends, ~2 at centre → gentle south dip
	return 12 + int(round(dip))


## Add a lane cell at (tx, ty) to the set IF it is in-bounds and NOT inside a building
## footprint OR the well footprint (a path never runs through a solid structure). Idempotent.
func _add_lane_cell(cells: Dictionary, tx: int, ty: int) -> void:
	if tx < 0 or tx >= grid_w or ty < 0 or ty >= grid_h:
		return
	for foot: Rect2i in building_footprints:
		if foot.has_point(Vector2i(tx, ty)):
			return
	# The well is a solid landmark too — the lane skirts it (apron rings it instead).
	if well_footprint.has_point(Vector2i(tx, ty)):
		return
	cells[Vector2i(tx, ty)] = true


## Paint the FINE-COBBLE LANE (the v2 path; 86ca5hwmx). For each lane cell: paint the
## fine-cobble path tile into the PathLane layer AND ERASE the ground cell beneath in
## FloorTiles, so exactly ONE tile-class renders per cell (no stacked-z, no z-fight —
## AC9 / html5-export.md §Z-index, both layers at z=0).
##
## REPEAT-BREAK (spec §2.4): the path atlas is multi-variant (6 variant-blocks). Each
## lane cell is assigned a variant via a non-tiling hash of its 4x4 BLOCK coords (so
## adjacent blocks differ and the lane never reads a repeating stamp), then the cell's
## local (bx,by) maps to that variant's atlas columns [v*4 + bx, by]. The lane world-
## coord (NOT cell index within the ribbon) drives the block so the variation is
## spatially coherent with the ground field beneath/around it.
func _paint_path_lane() -> void:
	if _path_lane == null or _floor_tiles == null:
		push_warning("S1YardChunk: PathLane/FloorTiles missing — cannot paint the lane")
		return
	var cells: Dictionary = _compute_lane_cells()
	for cell: Vector2i in cells:
		var block_x: int = cell.x / PATH_BLOCK_TILES
		var block_y: int = cell.y / PATH_BLOCK_TILES
		var variant: int = _path_block_variant(block_x, block_y)
		var local_x: int = cell.x % PATH_BLOCK_TILES
		var local_y: int = cell.y % PATH_BLOCK_TILES
		var atlas := Vector2i(variant * PATH_BLOCK_TILES + local_x, local_y)
		_path_lane.set_cell(cell, SOURCE_PATH, atlas)
		# Erase ground beneath → one tile-class per cell (the AC9 anti-z-fight rule).
		_floor_tiles.set_cell(cell, -1)


## Pick a path variant [0, PATH_VARIANTS) for a 4x4 block via a non-tiling hash of the
## block coords + cobble_seed (distinct prime mix from _block_variant so the lane + ground
## variant fields don't realign). Deterministic per seed (GUT + visual repro).
func _path_block_variant(block_x: int, block_y: int) -> int:
	var h: int = (block_x * 49979693) ^ (block_y * 86028157) ^ (cobble_seed * 6151)
	return absi(h) % PATH_VARIANTS


## Pick a cobble variant [0, COBBLE_VARIANTS) for a 4x4 block via a non-tiling
## integer hash of the block coords + cobble_seed. The hash mixes x and y with
## distinct large odd primes so the variant sequence does NOT realign on any small
## period (no visible variant grid). Deterministic per seed (GUT + visual repro).
func _block_variant(block_x: int, block_y: int) -> int:
	var h: int = (block_x * 73856093) ^ (block_y * 19349663) ^ (cobble_seed * 83492791)
	return absi(h) % COBBLE_VARIANTS


## Build the cloister BUILDINGS as solid landmark structures (s1-cloister-yard.md
## §2.1): for each authored footprint, paint finer-brick into the `Buildings`
## TileMapLayer (the visual) AND add a StaticBody2D + CollisionShape2D over the
## footprint (the physics). Buildings are walk-AROUND (the player + mobs path
## around them through open cobble), NOT teleport-room walls. The brick atlas
## window is phase-locked to the world tile coord so coursing flows continuously
## across a multi-tile building face.
func _build_structures() -> void:
	for foot: Rect2i in building_footprints:
		_paint_building_bricks(foot)
		_add_building_collision(foot)


## Paint finer-brick over a building footprint into the `Buildings` TileMapLayer.
func _paint_building_bricks(foot: Rect2i) -> void:
	if _buildings == null:
		return
	for ty in range(foot.position.y, foot.position.y + foot.size.y):
		for tx in range(foot.position.x, foot.position.x + foot.size.x):
			if tx < 0 or tx >= grid_w or ty < 0 or ty >= grid_h:
				continue
			# Period-4 wall atlas window, world-tile phase-locked so coursing flows.
			var atlas := Vector2i(tx % WALL_ATLAS_PERIOD, ty % WALL_ATLAS_PERIOD)
			_buildings.set_cell(Vector2i(tx, ty), SOURCE_WALL_FINE, atlas)


## Add a StaticBody2D + RectangleShape2D collision over a building footprint so
## the building is solid (walk-around). Centred on the footprint in world pixels.
func _add_building_collision(foot: Rect2i) -> void:
	if _building_bodies == null:
		return
	var tile_px: float = 32.0
	var body := StaticBody2D.new()
	body.name = "Building_%d_%d" % [foot.position.x, foot.position.y]
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(foot.size.x * tile_px, foot.size.y * tile_px)
	shape.shape = rect
	body.position = Vector2(
		(foot.position.x + foot.size.x * 0.5) * tile_px,
		(foot.position.y + foot.size.y * 0.5) * tile_px
	)
	body.add_child(shape)
	_building_bodies.add_child(body)


## Build the well-head collision (S1-YARD T8). A StaticBody2D over `well_footprint` so
## the well is a solid walk-AROUND landmark (like the buildings). The footprint is the
## well's SOLID base (3x3 tiles) centred under the sprite (which sits at the apron centre
## in the .tscn); the upper rim overhangs visually but the player collides with the base.
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


## Paint the SPRING pools (S1-YARD T8, Uma §3.2 + orch handoff). Each spring is a still
## dark warm-neutral ColorRect pool (S1_YARD_WATER_DOCTRINE — sub-1.0, NEVER pure-black,
## PL-WATER-01/02) over the cobble. The moss_patch sprite ring is REMOVED (#426 — Sponsor
## flagged the green-flecked spiky moss sprites as ugly trash). NO bespoke asset, NO
## animation (still water = zero HTML5 gate per §3.3); a single fixed sparse highlight
## ColorRect reads "quiet catch of light on the surface" without any tween. NO
## Polygon2D (PR #137).
func _paint_springs() -> void:
	if _springs == null:
		return
	for center: Vector2i in spring_tiles:
		var cx: float = (float(center.x) + 0.5) * TILE_PX
		var cy: float = (float(center.y) + 0.5) * TILE_PX
		# Pool: ~2x2-tile still dark pool, slightly irregular via a small offset rect.
		var pool := ColorRect.new()
		pool.color = WATER_BASE
		pool.size = Vector2(TILE_PX * 1.6, TILE_PX * 1.4)
		pool.position = Vector2(cx - pool.size.x * 0.5, cy - pool.size.y * 0.5)
		_springs.add_child(pool)
		# A single fixed sparse highlight (still catch of light) — NO tween (zero gate).
		var glint := ColorRect.new()
		glint.color = WATER_HIGHLIGHT
		glint.size = Vector2(TILE_PX * 0.5, TILE_PX * 0.28)
		glint.position = Vector2(cx - glint.size.x * 0.5, cy - TILE_PX * 0.35)
		_springs.add_child(glint)
		# SOAK-REVISION (#426, Sponsor 2026-06-08): the moss_patch sprite RING is REMOVED.
		# The Sponsor flagged the scattered spiky/burr moss_patch sprites (green-flecked
		# brown blobs across the yard + leaking onto the wall band) as ugly "trash" — the
		# SAME ugly-spiky-object class removed once before (the _scatter_decoration no-op).
		# The spring is now JUST the still dark ColorRect pool + the fixed highlight (the
		# water feature is load-bearing; the moss props were the trash).


## Paint the GARDEN BED gone wild (S1-YARD T8, Uma §4). ONE hero bed of tilled soil
## reclaimed by weeds near the dormitory range. A semi-transparent damp-earth ColorRect
## bed (cobble reads through, so it's "soil OVER the ground", not a hard tile swap).
## SOAK-REVISION (#426, Sponsor 2026-06-08): the clustered moss_patch OVERGROWTH is
## REMOVED — those green-flecked moss sprites were part of the "ugly trash" spiky-prop
## class the Sponsor cut. Per the spec rule "the garden bed can stay ONLY if it doesn't
## use these spiky props", the bed is kept as the clean damp-soil ColorRect alone (no
## moss_patch sprites). LOW-cost, one bed (§4 "one hero bed, not multiple"). Floor-level.
func _paint_garden_bed() -> void:
	if _springs == null:
		return
	var bed := garden_bed
	var soil := ColorRect.new()
	soil.color = GARDEN_SOIL
	soil.size = Vector2(bed.size.x * TILE_PX, bed.size.y * TILE_PX)
	soil.position = Vector2(bed.position.x * TILE_PX, bed.position.y * TILE_PX)
	_springs.add_child(soil)


## Damp mossy aprons at building bases (S1-YARD T8, Uma §4 — FREE via existing doctrine).
## The ground at a building's SOUTH base (where sun never reaches the wall foot) reads
## damp + moss-thickened vs the open sun-ground — grounds the buildings INTO the yard. A
## subtle semi-transparent dark ColorRect strip along each building's south edge. Floor-
## level (z=0 via Springs container). Subtle (low alpha) so it darkens the cobble shadow
## WITHOUT a hard border (no hard clean edge, §2.3 discipline).
## SOAK-REVISION (#426, Sponsor 2026-06-08): the moss_patch TUFTS at building bases are
## REMOVED — these were the moss sprites "leaking onto the wall band" the Sponsor flagged
## (red arrows on the bottom wall band). The apron is now JUST the subtle dark shadow
## strip (a ColorRect, not a spiky prop) — it still grounds the buildings without the trash.
func _paint_building_aprons() -> void:
	if _springs == null:
		return
	for foot: Rect2i in building_footprints:
		# South-base apron strip: one tile tall along the building's bottom edge, IN the
		# open ground just south of the footprint (not over the building itself).
		var apron_y: int = foot.position.y + foot.size.y
		if apron_y >= grid_h:
			continue  # building runs to the grid edge (off-frame) — no visible south base
		var apron := ColorRect.new()
		apron.color = Color(0.16, 0.15, 0.13, 0.32)  # damp-shadow darken, sub-1.0, low alpha
		apron.size = Vector2(foot.size.x * TILE_PX, TILE_PX * 0.6)
		apron.position = Vector2(foot.position.x * TILE_PX, apron_y * TILE_PX)
		_springs.add_child(apron)


## Yard decoration. INTENTIONALLY a NO-OP as of the Sponsor scale soak (2026-06-07,
## PR #424): the prior pass scattered the carried-forward `moss_patch` prop as
## grass/moss tufts, but that 32x32 sprite renders ~85x85 px at baseline game zoom
## (≈ player-sized) and reads as a DARK SPIKY BLOB with green flecks — the Sponsor
## flagged these as "ugly objects out of proportion" (he didn't recognize them).
## They were the moss-patch tufts, NOT mobs.
##
## The vegetation/"nature reclaiming" story is ALREADY carried by the cobble FLOOR
## tiles — the v2 generator bakes clustered olive moss into the cobble joints
## (s1-cloister-yard.md §5.2: "the tile-level moss carries most of the moss story").
## So the floor keeps its overgrown-yard read WITHOUT the oversized ugly prop blobs.
##
## T3 (the dedicated decoration ticket) owns adding PROPER ground-vegetation props
## (a clean, correctly-proportioned grass/sprout asset at the right scale) — the
## `tile-scale-small-player-large-world` north-star extends to props: nice +
## proportional, no ugly placeholders. Until that asset exists, no prop scatter.
func _scatter_decoration() -> void:
	pass
