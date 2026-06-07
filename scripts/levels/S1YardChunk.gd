extends Node2D
class_name S1YardChunk
## Painter for the S1 open cloister-YARD chunk (ticket 86ca5erzk, S1-YARD T4;
## Uma s1-cloister-yard.md §0.5/§0.6/§2/§3/§5). Paints an OPEN cobble expanse —
## NOT the four-walls-boxing-the-screen room model — into the `FloorTiles`
## TileMapLayer at `_ready`, then scatters sparse+jittered+clustered grass/moss
## into the `Decoration` node. The cloister BUILDINGS (collision structures) +
## their finer-brick visual + the carried-forward props live in the .tscn (the
## assembler instantiates the whole chunk scene; this script paints the procedural
## floor + decoration on top so the wide yard never reads a tile-repeat).
##
## SPATIAL MODEL (the pivot — s1-cloister-yard.md §2): the yard is ONE big open
## traversable expanse, WIDER + TALLER than the 480x270 viewport so the camera
## scrolls in BOTH axes (the "big + endless" read). The floor is wall-to-wall
## OPEN COBBLE — there is NO perimeter wall ring. Buildings are landmark
## STRUCTURES standing IN the expanse (north range / south range / 1-2 central /
## a far outbuilding), set back from the player's immediate space with open cobble
## running PAST them toward a soft scroll-horizon. The buildings' finer-brick walls
## + collision are authored in the .tscn; this painter only paints the GROUND +
## scatters decoration.
##
## Why a script-painter (same rationale as S1CloisterChunk): TileMapLayer
## serialises painted cells as a binary PackedByteArray that is impossible to
## diff-review. Painting via `set_cell` in `_ready` is deterministic,
## diff-readable, and GUT-testable.
##
## COLLISION IS DECOUPLED: building collision is the StaticBody2D nodes in the
## .tscn; this script paints only the *visual* cobble + decoration. The open yard
## ground has NO floor collision (the player walks the whole expanse; only the
## building footprints + their walls block).
##
## DECORATION DISCIPLINE (s1-cloister-yard.md §5.2 — the #1 grass complaint):
## grass/moss is SPARSE + JITTERED + CLUSTERED, NEVER a grid. Placement is
## seeded-deterministic (RandomNumberGenerator with a fixed seed) so the GUT test
## + the visual are reproducible, but each tuft is position-jittered within its
## cell and clustered in damp zones (building bases, corners), not evenly spaced.
## Target density ~1 cluster per 6-10 open-cobble tiles (NOT one per tile).

# Atlas-source ids inside s1_cloister_yard.tres.
const SOURCE_COBBLE: int = 0
const SOURCE_WALL_FINE: int = 1
## Source 2 = warm-sandstone FLAGSTONE, reused as the worn processional SLAB-PATH
## material (S1-YARD T8; Uma s1-yard-ground-composition.md §2.1). 64x64 = 2x2 atlas.
const SOURCE_SLAB: int = 2
const SLAB_ATLAS_PERIOD: int = 2  # 2x2 flagstone atlas

## The cobble PNG is a MULTI-VARIANT atlas: SIX 4x4 variant-blocks side by side
## (768x128 = 24x4 cells; variant v occupies atlas columns [v*4 .. v*4+3]). Each
## variant is a distinct 384px source downsampled to 128px (preserves the Sponsor-
## LOVED fine varied-stone scale + grey tone). CLEAN grey cobble — no baked
## vegetation (Sponsor lock: dirt CUT, then green/moss stripped too).
##
## REPEAT-BREAK (PR #424 Sponsor fix — he marked identical block-rectangles every
## block period): a single repeated block stamped its stone layout identically across
## the yard. The painter SCATTERS the 6 variants per 4-tile block with a NON-TILING
## hash of the block coords, so adjacent blocks differ and no block-cluster repeats.
## Within a block the 4x4 cells map to the chosen variant's columns; each variant's
## STONES stay toroidally seamless internally (the loved read), so the variation is at
## the block level — pan the yard and see no repeating stamp.
const COBBLE_BLOCK_TILES: int = 4  # one variant-block spans 4x4 game tiles
const COBBLE_VARIANTS: int = 6  # number of variant-blocks packed in the atlas

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

## Seed for the per-block cobble-variant scatter (the repeat-break hash). Fixed so
## the yard's variant layout is deterministic across boots (GUT + visual repro);
## change it to re-roll the scatter. NOT the per-character world_seed.
@export var cobble_seed: int = 1763

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
## buildings) AND a worn slab apron rings it (§2.2 well-approach). The sprite itself
## is placed in the .tscn at the apron centre (688, 560 ≈ tile (21.5, 17.5)). Kept as
## data here so the nav GUT test can mirror it as a wall (parity with building_footprints).
## Footprint is the SOLID base of the well (~3x3 tiles) centred under the sprite, NOT the
## full sprite extent (the upper rim overhangs visually but the player collides with the base).
@export var well_footprint: Rect2i = Rect2i(20, 16, 3, 3)

## SPRING pools (S1-YARD T8, Uma §3.2; orch handoff: ColorRect-pool, NO bespoke asset).
## Each is a damp low/shadow corner where ground water surfaces. Authored in TILES as
## (x, y) pool-centre; the painter draws a still dark warm-neutral ColorRect pool there
## ringed by the carried-forward moss_patch (wettest-moss clustering) over the cobble.
## Two pools: one at the north-wall base (damp shadow under the chapel range), one in the
## dip near the dormitory ruin (SW). Both sit in OPEN cobble, clear of mob spawns + the spine.
@export var spring_tiles: Array[Vector2i] = [
	Vector2i(28, 2),  # north — damp shadow under the chapel range east section
	Vector2i(9, 18),  # SW dip near the dormitory ruin
]

## GARDEN BED gone wild (S1-YARD T8, Uma §4). ONE hero bed of tilled-soil-gone-to-weeds
## near the dormitory range (south). Authored as a TILE rect; the painter tints a damp
## earth ColorRect bed + clusters moss_patch overgrowth (reuse, no new asset). Placed in
## open cobble south of the central building, clear of the south range footprint + spawns.
@export var garden_bed: Rect2i = Rect2i(12, 17, 4, 3)

## S1_YARD_WATER_DOCTRINE (Uma §3.3) — still, dark, warm-neutral, sub-1.0 every channel,
## NEVER pure-black (PL-09). Used for the spring ColorRect pools (PL-WATER-01/02/03).
const WATER_BASE := Color(0.180, 0.165, 0.149, 1.0)  # #2E2A26 dark warm-neutral still surface
const WATER_HIGHLIGHT := Color(0.522, 0.486, 0.424, 1.0)  # #857C6C sparse still catch
## Damp earth tint for the garden bed (warm soil, sub-1.0). Doctrine dirt-through family.
const GARDEN_SOIL := Color(0.329, 0.271, 0.184, 0.78)  # #54452F soil, semi-transparent

## Carried-forward moss prop reused for spring rings + garden overgrowth + base aprons.
const MOSS_PATCH_PATH: String = "res://assets/props/s1_cloister/moss_patch.png"

const TILE_PX: float = 32.0

@onready var _floor_tiles: TileMapLayer = $FloorTiles
@onready var _slab_paths: TileMapLayer = $SlabPaths
@onready var _springs: Node2D = $Springs
@onready var _buildings: TileMapLayer = $Buildings
@onready var _building_bodies: Node2D = $BuildingBodies
@onready var _well_body: Node2D = $WellBody
@onready var _decoration: Node2D = $Decoration


## Single load site for the reused moss prop (dedupes the duplicated-load lint across
## the spring-ring / garden-overgrowth / building-apron call sites; resource cache hands
## back the same Texture2D instance so this is allocation-free after the first call).
func _load_moss() -> Texture2D:
	return load(MOSS_PATCH_PATH)


func _ready() -> void:
	_paint_floor()
	_paint_slab_paths()
	_build_structures()
	_build_well_collision()
	_paint_springs()
	_paint_garden_bed()
	_paint_building_aprons()
	_scatter_decoration()


## Paint the full grid_w x grid_h grid as OPEN COBBLE — no perimeter wall ring
## (the yard is open; buildings block via .tscn collision, not a painted wall).
## Idempotent (set_cell overwrites).
##
## REPEAT-BREAK: each 4x4 block of game tiles is assigned ONE of the 6 atlas
## variants via a non-tiling hash of the block coords (`_block_variant`), so the
## moss-feature positions differ block-to-block and the field never reads a repeating
## stamp (PR #424 Sponsor fix). Within a block, the local (bx,by) cell maps to that
## variant's atlas columns `[v*4 + bx, by]`. Stones stay seamless WITHIN each variant.
func _paint_floor() -> void:
	if _floor_tiles == null:
		push_warning("S1YardChunk: FloorTiles TileMapLayer missing — cannot paint")
		return
	for ty in range(grid_h):
		for tx in range(grid_w):
			var block_x: int = tx / COBBLE_BLOCK_TILES
			var block_y: int = ty / COBBLE_BLOCK_TILES
			var variant: int = _block_variant(block_x, block_y)
			var local_x: int = tx % COBBLE_BLOCK_TILES
			var local_y: int = ty % COBBLE_BLOCK_TILES
			var atlas := Vector2i(variant * COBBLE_BLOCK_TILES + local_x, local_y)
			_floor_tiles.set_cell(Vector2i(tx, ty), SOURCE_COBBLE, atlas)


## Compute the set of TILE cells that the worn processional slab paths occupy
## (S1-YARD T8, Uma s1-yard-ground-composition.md §2.2 desire-line map). Returns a
## Dictionary{Vector2i: true} so callers can test membership cheaply. The composition:
##   - PROCESSIONAL SPINE: west gate (player spawn, row 12) → curving east → the east
##     descent terminus. ~2 tiles wide, curving (never ruler-straight, §2.2). It DIPS
##     south around the central building (footprint 18-23 × 9-13) so it skirts the
##     solid structure on open cobble, then rises back to row 12 toward the descent.
##   - BUILDING-LINK: a short slab run from the spine N toward the central-building face.
##   - WELL APPROACH + APRON: a slab spur from the spine S to the well, ringed by a worn
##     slab apron around the well_footprint (§2.2 "everyone drew water — most-worn ground").
## Slabs are RIBBONS (a few tiles wide), NEVER a grid/plaza (§2.2 composition discipline).
## Cells overlapping a building footprint are EXCLUDED (a path doesn't run through a wall).
func _compute_slab_cells() -> Dictionary:
	var cells: Dictionary = {}

	# --- Processional spine: a curving 2-wide ribbon west → east. The centre-row
	# follows a gentle curve (south dip around the central building, back to centre).
	for tx in range(0, grid_w):
		var center_row: int = _spine_center_row(tx)
		# 2-wide ribbon: the centre row + one row south of it (keeps the band off the
		# very top/bottom and reads as a worn double-track).
		for dy in range(0, 2):
			_add_slab_cell(cells, tx, center_row + dy)

	# --- Building-link: short slab run from the spine up to the central building's
	# south face (footprint 18-23 × 9-13 → south face at y=13). Connects spine (south
	# of the building) to the colonnade the pillars front (s1_yard_slice_chunk.tscn).
	for ty in range(14, 16):
		for tx in range(20, 23):
			_add_slab_cell(cells, tx, ty)

	# --- Well approach + apron. The well_footprint is (20,16,3,3). Spur from the spine
	# down to the well, plus a 1-tile-thick apron ring around the well base (§2.2 "worn
	# slab apron"). The apron is the most-worn ground in the yard (everyone drew water).
	var well := well_footprint
	# Apron ring: the band one tile outside the well footprint on all sides.
	for ty in range(well.position.y - 1, well.position.y + well.size.y + 1):
		for tx in range(well.position.x - 1, well.position.x + well.size.x + 1):
			# Only the RING (exclude the interior, which the well prop/collision occupies).
			var on_ring: bool = (
				tx == well.position.x - 1
				or tx == well.position.x + well.size.x
				or ty == well.position.y - 1
				or ty == well.position.y + well.size.y
			)
			if on_ring:
				_add_slab_cell(cells, tx, ty)
	# Short spur connecting the spine to the apron (the well sits just south of the spine).
	for ty in range(15, well.position.y):
		_add_slab_cell(cells, well.position.x + 1, ty)

	return cells


## True spine centre-row at column tx — a gentle curve, not a straight road (§2.2).
## Anchored at row 12 (player-spawn centre / descent EAST exit y=12 → the journey line),
## dipping ~2 rows SOUTH across the mid-yard so the ribbon skirts the central building on
## open cobble + reads organic. Pure function (GUT-pinnable, deterministic).
func _spine_center_row(tx: int) -> int:
	# Quadratic-ish dip: deepest near the centre column, flat at the ends. Keeps the
	# band on the south side of the central building (footprint south face y=13) without
	# crossing INTO it (the _add_slab_cell building-footprint guard also protects this).
	var t: float = float(tx) / float(maxi(grid_w - 1, 1))  # 0..1 across the yard
	var dip: float = sin(t * PI) * 3.0  # 0 at ends, ~3 at centre → south dip
	return 12 + int(round(dip))


## Add a slab cell at (tx, ty) to the set IF it is in-bounds and NOT inside a building
## footprint (a processional path never runs through a solid wall). Idempotent.
func _add_slab_cell(cells: Dictionary, tx: int, ty: int) -> void:
	if tx < 0 or tx >= grid_w or ty < 0 or ty >= grid_h:
		return
	for foot: Rect2i in building_footprints:
		if foot.has_point(Vector2i(tx, ty)):
			return
	cells[Vector2i(tx, ty)] = true


## Paint the worn processional slab paths (S1-YARD T8). For each slab cell: paint the
## warm-sandstone flagstone into the SlabPaths layer AND ERASE the cobble cell beneath
## in FloorTiles, so exactly ONE tile-class renders per cell (no stacked-z, no z-fight —
## T8 AC9 / html5-export.md §Z-index, both layers at z=0). The flagstone atlas is the
## 2x2 set; a non-tiling hash picks the atlas cell per world-coord so the slab run reads
## varied (worn cut stones), not a single repeated stamp.
func _paint_slab_paths() -> void:
	if _slab_paths == null or _floor_tiles == null:
		push_warning("S1YardChunk: SlabPaths/FloorTiles missing — cannot paint slab paths")
		return
	var cells: Dictionary = _compute_slab_cells()
	for cell: Vector2i in cells:
		var h: int = (cell.x * 73856093) ^ (cell.y * 19349663) ^ (cobble_seed * 6151)
		var ax: int = absi(h) % SLAB_ATLAS_PERIOD
		var ay: int = absi(h / SLAB_ATLAS_PERIOD) % SLAB_ATLAS_PERIOD
		_slab_paths.set_cell(cell, SOURCE_SLAB, Vector2i(ax, ay))
		# Erase cobble beneath → one tile-class per cell (the AC9 anti-z-fight rule).
		_floor_tiles.set_cell(cell, -1)


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
## PL-WATER-01/02) over the cobble, ringed by the carried-forward moss_patch (wettest-moss
## clustering, the most-reclaimed spots). NO bespoke asset, NO animation (still water =
## zero HTML5 gate per §3.3); a single fixed sparse highlight ColorRect reads "quiet catch
## of light on the surface" without any tween. NO Polygon2D (PR #137).
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
		# Wettest-moss ring: small moss_patch sprites clustered at the pool edge (reuse).
		# Kept SMALL (scale 0.5) so they read as damp moss flecks, NOT the player-sized
		# blobs the Sponsor rejected in PR #424's decoration scatter.
		for ring_offset: Vector2 in [Vector2(-22, 4), Vector2(22, 6), Vector2(2, 22)]:
			var moss := Sprite2D.new()
			moss.texture = _load_moss()
			moss.scale = Vector2(0.5, 0.5)
			moss.position = Vector2(cx + ring_offset.x, cy + ring_offset.y)
			_springs.add_child(moss)


## Paint the GARDEN BED gone wild (S1-YARD T8, Uma §4). ONE hero bed of tilled soil
## reclaimed by weeds near the dormitory range. A semi-transparent damp-earth ColorRect
## bed (cobble reads through, so it's "soil OVER the ground", not a hard tile swap) +
## clustered moss_patch overgrowth (reuse, small scale). LOW-cost, one bed (§4 "one hero
## bed, not multiple"). Floor-level (parented to Springs/floor container, z=0).
func _paint_garden_bed() -> void:
	if _springs == null:
		return
	var bed := garden_bed
	var soil := ColorRect.new()
	soil.color = GARDEN_SOIL
	soil.size = Vector2(bed.size.x * TILE_PX, bed.size.y * TILE_PX)
	soil.position = Vector2(bed.position.x * TILE_PX, bed.position.y * TILE_PX)
	_springs.add_child(soil)
	# Overgrowth: a few small moss tufts scattered in the bed (reclaimed-by-weeds read).
	for tuft: Vector2i in [Vector2i(0, 0), Vector2i(2, 1), Vector2i(3, 2), Vector2i(1, 2)]:
		var weed := Sprite2D.new()
		weed.texture = _load_moss()
		weed.scale = Vector2(0.55, 0.55)
		weed.position = Vector2(
			(float(bed.position.x + tuft.x) + 0.5) * TILE_PX,
			(float(bed.position.y + tuft.y) + 0.5) * TILE_PX
		)
		_springs.add_child(weed)


## Damp mossy aprons at building bases (S1-YARD T8, Uma §4 — FREE via existing doctrine).
## The ground at a building's SOUTH base (where sun never reaches the wall foot) reads
## damp + moss-thickened vs the open sun-ground — grounds the buildings INTO the yard. A
## subtle semi-transparent dark ColorRect strip along each building's south edge + a few
## small moss tufts. Floor-level (z=0 via Springs container). Subtle (low alpha) so it
## darkens the cobble shadow WITHOUT a hard border (no hard clean edge, §2.3 discipline).
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
		# A couple of small moss tufts at the damp base (reclaimed-corner read).
		for i in range(2):
			var moss := Sprite2D.new()
			moss.texture = _load_moss()
			moss.scale = Vector2(0.45, 0.45)
			moss.position = Vector2(
				(float(foot.position.x) + (float(i) + 0.5) * float(foot.size.x) * 0.5) * TILE_PX,
				(float(apron_y) + 0.2) * TILE_PX
			)
			_springs.add_child(moss)


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
