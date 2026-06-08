extends Node2D
class_name S1YardDescentChunk
## Painter for the S1 yard EAST descent-cap chunk (ticket 86ca5erzk, S1-YARD T4;
## Uma s1-cloister-yard.md §2.2 step 5). A narrow open-cobble strip that caps the
## east end of the yard slice — the descent terminus where the yard continues
## toward the stair down into the Cinder Vaults. Mates WEST onto the main yard
## chunk's EAST exit port so the assembled floor is ONE continuous open expanse.
##
## Paints OPEN COBBLE only (no buildings) — the descent approach is clear ground.
##
## #426 FINER-CELL REVISION: the shared yard TileSet (`s1_cloister_yard.tres`) now uses a
## 16px FINE cell (was 32px) so the main yard's path/region geometry resolves in small
## smooth steps. The descent cap shares that TileSet, so it MUST paint at the SAME fine grid
## or it would render at quarter-area (16px cells over a 32px-logical chunk) and shrink its
## cobble. Mirror S1YardChunk's fine-grid convention: iterate the CELL_SUBDIV-finer grid,
## address the cobble atlas CONTINUOUSLY by the FINE world cell wrapped into the 8-fine-cell
## (128px) variant period so the STONE size stays constant, and scatter the variant per FINE
## block so the cap reads continuous with the main yard (no repeat, no seam at the mate).

const SOURCE_COBBLE: int = 0
const COBBLE_VARIANTS: int = 6

## Mirror S1YardChunk: 2x-finer cell, 8-fine-cell (128px) continuous-wrap atlas period.
const CELL_SUBDIV: int = 2
const ATLAS_FINE_PERIOD: int = 8  # 128px variant / 16px fine cell

## Grid in LOGICAL tiles (the ChunkDef/assembler/world contract, UNCHANGED at 32px).
@export var grid_w: int = 6
@export var grid_h: int = 24
@export var cobble_seed: int = 1763
## Block-x offset (in FINE blocks) so the cap's variant scatter continues the yard's. The
## yard is 40 logical tiles = 80 fine cells = 10 fine blocks (80/8); start the cap east of
## that at block-x 10 for variant-field continuity across the mate.
@export var block_x_offset: int = 10

var _fw: int = 0
var _fh: int = 0

@onready var _floor_tiles: TileMapLayer = $FloorTiles


func _ready() -> void:
	_fw = grid_w * CELL_SUBDIV
	_fh = grid_h * CELL_SUBDIV
	_paint_floor()


## Paint open cobble across the whole FINE grid. Each fine cell scatters a variant per FINE
## block (continuous with the yard via block_x_offset) and addresses the atlas continuously
## by the fine world cell wrapped into the 8-fine-cell period (constant stone size, seamless).
func _paint_floor() -> void:
	if _floor_tiles == null:
		push_warning("S1YardDescentChunk: FloorTiles TileMapLayer missing — cannot paint")
		return
	for fy in range(_fh):
		for fx in range(_fw):
			var block_x: int = block_x_offset + fx / ATLAS_FINE_PERIOD
			var block_y: int = fy / ATLAS_FINE_PERIOD
			var h: int = (block_x * 73856093) ^ (block_y * 19349663) ^ (cobble_seed * 83492791)
			var variant: int = absi(h) % COBBLE_VARIANTS
			var local_x: int = fx % ATLAS_FINE_PERIOD
			var local_y: int = fy % ATLAS_FINE_PERIOD
			var atlas := Vector2i(variant * ATLAS_FINE_PERIOD + local_x, local_y)
			_floor_tiles.set_cell(Vector2i(fx, fy), SOURCE_COBBLE, atlas)
