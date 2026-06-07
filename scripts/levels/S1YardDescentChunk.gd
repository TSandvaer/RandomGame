extends Node2D
class_name S1YardDescentChunk
## Painter for the S1 yard EAST descent-cap chunk (ticket 86ca5erzk, S1-YARD T4;
## Uma s1-cloister-yard.md §2.2 step 5). A narrow open-cobble strip that caps the
## east end of the yard slice — the descent terminus where the yard continues
## toward the stair down into the Cinder Vaults. Mates WEST onto the main yard
## chunk's EAST exit port (procgen EAST/WEST mating) so the assembled floor is
## ONE continuous open expanse, not two stamped copies.
##
## Why a separate small chunk and not a second copy of the big yard: the ZoneDef
## validate() requires exactly one &"entry" + ≥1 &"exit" anchor → ≥2 anchors → ≥2
## placed chunks. Reusing the 40-wide yard for the exit would stamp TWO full yards
## (duplicate buildings = a tile-repeat, the exact read Uma's anti-repeat
## discipline forbids). A small distinct descent-cap is the correct east terminus:
## open cobble running PAST the buildings toward the descent (soft scroll-horizon,
## §2.3), no duplicated landmarks.
##
## Paints OPEN COBBLE only (no buildings) — the descent approach is clear ground.
## The actual StratumExit/descent-stair wiring on the assembler path is downstream
## (Main._load_s1_zone does not yet spawn a StratumExit — see Main.gd §"S1
## assembler retrofit"); this slice is the FEEL soak of the open yard.

const SOURCE_COBBLE: int = 0
## The cobble atlas is the multi-variant 24x4 set (6 variant-blocks of 4x4). The
## descent cap scatters variants per 4x4 block too (non-tiling hash) so it reads
## continuous with the main yard, no repeat. Mirrors S1YardChunk's scheme.
const COBBLE_BLOCK_TILES: int = 4
const COBBLE_VARIANTS: int = 6

@export var grid_w: int = 6
@export var grid_h: int = 24
## Offset so the descent cap's variant scatter continues the yard's (the cap sits
## east of the 40-wide yard = 10 blocks; start its block-x at 10 for continuity).
@export var cobble_seed: int = 1763
@export var block_x_offset: int = 10

@onready var _floor_tiles: TileMapLayer = $FloorTiles


func _ready() -> void:
	_paint_floor()


func _paint_floor() -> void:
	if _floor_tiles == null:
		push_warning("S1YardDescentChunk: FloorTiles TileMapLayer missing — cannot paint")
		return
	for ty in range(grid_h):
		for tx in range(grid_w):
			var block_x: int = block_x_offset + tx / COBBLE_BLOCK_TILES
			var block_y: int = ty / COBBLE_BLOCK_TILES
			var h: int = (block_x * 73856093) ^ (block_y * 19349663) ^ (cobble_seed * 83492791)
			var variant: int = absi(h) % COBBLE_VARIANTS
			var atlas := Vector2i(
				variant * COBBLE_BLOCK_TILES + tx % COBBLE_BLOCK_TILES, ty % COBBLE_BLOCK_TILES
			)
			_floor_tiles.set_cell(Vector2i(tx, ty), SOURCE_COBBLE, atlas)
