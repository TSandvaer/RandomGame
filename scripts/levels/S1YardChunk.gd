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

## The cobble PNG is a MULTI-VARIANT atlas: SIX 4x4 variant-blocks side by side
## (768x128 = 24x4 cells; variant v occupies atlas columns [v*4 .. v*4+3]). Each
## variant is a distinct 384px source downsampled to 128px (preserves the Sponsor-
## LOVED fine varied-stone scale + grey tone). dirt CUT; green VARIED by the generator.
##
## REPEAT-BREAK (PR #424 Sponsor fix — he marked identical feature-rectangles every
## block period): a single repeated block stamped its moss positions identically
## across the yard. The painter now SCATTERS the 6 variants per 4-tile block with a
## NON-TILING hash of the block coords, so adjacent blocks differ and no feature-
## cluster repeats. Within a block the 4x4 cells map to the chosen variant's columns;
## each variant's STONES stay toroidally seamless internally (the loved read), so the
## variation is at the block level — pan the yard and see no repeating stamp.
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

@onready var _floor_tiles: TileMapLayer = $FloorTiles
@onready var _buildings: TileMapLayer = $Buildings
@onready var _building_bodies: Node2D = $BuildingBodies


func _ready() -> void:
	_paint_floor()
	_build_structures()
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
