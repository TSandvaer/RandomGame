extends Node2D
class_name S1CloisterChunk
## Painter for the S1 "Outer Cloister" chunk scene (ticket 86ca3h8hn,
## Uma env-art brief §3/§7.1). Paints the floor + wall perimeter into the
## `FloorTiles` TileMapLayer at `_ready` from `resources/tilesets/s1_cloister.tres`.
##
## Why a script-painter instead of a hand-authored `tile_map_data` blob:
## TileMapLayer serialises painted cells as a binary PackedByteArray that is
## error-prone to hand-edit in a .tscn and impossible to diff-review. Painting
## via `set_cell` in `_ready` is deterministic, diff-readable, and GUT-testable
## (assert cell sources/atlas-coords after `_ready`).
##
## COLLISION IS DECOUPLED: the four WallNorth/South/East/West StaticBody2D +
## CollisionShape2D perimeter nodes in the .tscn are the physics; this script
## only paints the *visual* tiles. The painted wall band sits under the same
## perimeter the collision walls already cover (BB-3 invariant unchanged).
##
## Grid: 15 tiles wide x 8 tiles tall, 32px (LevelChunkDef.size_tiles /
## tile_size_px). Wall band = outermost ring (rows 0 & 7, cols 0 & 14);
## floor = interior.

# Atlas-source ids inside s1_cloister.tres.
const SOURCE_FLOOR: int = 0
const SOURCE_WALL: int = 1
# Base tile atlas coordinate used for the bulk paint (top-left tile of each sheet).
const ATLAS_BASE: Vector2i = Vector2i(0, 0)

const GRID_W: int = 15
const GRID_H: int = 8

@onready var _floor_tiles: TileMapLayer = $FloorTiles


func _ready() -> void:
	_paint()


## Paints the full 15x8 grid: wall tiles on the perimeter ring, floor tiles
## on the interior. Idempotent — safe to call again (set_cell overwrites).
func _paint() -> void:
	if _floor_tiles == null:
		push_warning("S1CloisterChunk: FloorTiles TileMapLayer missing — cannot paint")
		return
	for ty in range(GRID_H):
		for tx in range(GRID_W):
			var is_perimeter: bool = tx == 0 or tx == GRID_W - 1 or ty == 0 or ty == GRID_H - 1
			var source_id: int = SOURCE_WALL if is_perimeter else SOURCE_FLOOR
			_floor_tiles.set_cell(Vector2i(tx, ty), source_id, ATLAS_BASE)
