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
## Matches S1YardChunk.COBBLE_ATLAS_PERIOD (128px 4x4 varied-cobble atlas).
const COBBLE_ATLAS_PERIOD: int = 4

@export var grid_w: int = 6
@export var grid_h: int = 24

@onready var _floor_tiles: TileMapLayer = $FloorTiles


func _ready() -> void:
	_paint_floor()


func _paint_floor() -> void:
	if _floor_tiles == null:
		push_warning("S1YardDescentChunk: FloorTiles TileMapLayer missing — cannot paint")
		return
	for ty in range(grid_h):
		for tx in range(grid_w):
			var atlas: Vector2i = Vector2i(tx % COBBLE_ATLAS_PERIOD, ty % COBBLE_ATLAS_PERIOD)
			_floor_tiles.set_cell(Vector2i(tx, ty), SOURCE_COBBLE, atlas)
