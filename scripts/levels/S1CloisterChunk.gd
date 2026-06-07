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
## Grid: DEFAULT 15 tiles wide x 8 tiles tall, 32px (LevelChunkDef.size_tiles /
## tile_size_px). Wall band = outermost ring (rows 0 & H-1, cols 0 & W-1);
## floor = interior.
##
## **Grid is now @export (ticket 86ca3kpzz — S1 bigger-rooms retrofit S1A).**
## The original constants were hard-coded 15×8 (every S1 room shares this one
## chunk script). The widened proof chunk (`s1_room02_wide_chunk.tscn`, 30×8)
## sets `grid_w = 30` at author-time so the painter fills the wider floor;
## every other S1 room scene omits the override and keeps the 15×8 default —
## byte-identical paint behaviour to pre-retrofit. The export defaults are the
## old constants, so existing `s1_room01_chunk.tscn` (no override) is unchanged.

# Atlas-source ids inside s1_cloister.tres.
const SOURCE_FLOOR: int = 0
const SOURCE_WALL: int = 1
# Base tile atlas coordinate (top-left tile of each sheet). Retained for
# back-compat / tests; the bulk paint now uses the 4×4 ATLAS-WINDOW tiling
# below, not this single cell.
const ATLAS_BASE: Vector2i = Vector2i(0, 0)

## The wall PNG is a 128×128 = 4×4 atlas of 32-px sub-tiles that, stitched in
## source grid order, form ONE crafted 128-px image (running-bond ashlar flows
## across the whole block). The floor PNG was the same 128×128 4×4 — but Sponsor
## feel-rejected f0a8fc8 ("the tiles should be much much much smaller": ~8
## flagstones spanned the whole hall at 2.667× camera zoom). Ticket 86ca44p4j
## shrinks the FLOOR stone pitch 2×: the crafted 128-px block was downsampled to
## 64×64 (a 2×2 = 4-sub-tile atlas), so each 32-px game cell now shows ~2× finer
## flagstones and the block tiles at a 2-tile (64-px) period instead of 4-tile.
## The wall is UNCHANGED (4×4 / 128-px / period-4) — the reject was floor-only
## and the running-bond ashlar reads correct at game zoom (no scope creep).
##
## The painter paints each cell from its position WITHIN the source window,
## `Vector2i(tx % period, ty % period)`, so the full AI image tiles with a
## gentle period — stones read continuous within each block, the only repeat is
## the soft block seam (which the crafted source tiles seamlessly across, so no
## dark grid line). This is the PR #407 wallpaper-grid avoidance; verified
## intact at the smaller 2× floor scale (see PR #417 Self-Test Report).
##
## Per-source period: the floor (64-px / 2×2) tiles at 2; the wall (128-px /
## 4×4) tiles at 4.
const ATLAS_PERIOD: int = 4
const FLOOR_ATLAS_PERIOD: int = 2
const WALL_ATLAS_PERIOD: int = 4

## Grid width/height in tiles. Default = the M1 single-screen 15×8. The
## widened proof chunk overrides `grid_w` to 30. Painting derives entirely
## from these — no other geometry constant depends on them.
@export var grid_w: int = 15
@export var grid_h: int = 8

@onready var _floor_tiles: TileMapLayer = $FloorTiles


func _ready() -> void:
	_paint()


## Paints the full grid_w × grid_h grid: wall tiles on the perimeter ring,
## floor tiles on the interior. Idempotent — safe to call again (set_cell
## overwrites).
func _paint() -> void:
	if _floor_tiles == null:
		push_warning("S1CloisterChunk: FloorTiles TileMapLayer missing — cannot paint")
		return
	for ty in range(grid_h):
		for tx in range(grid_w):
			var is_perimeter: bool = tx == 0 or tx == grid_w - 1 or ty == 0 or ty == grid_h - 1
			var source_id: int = SOURCE_WALL if is_perimeter else SOURCE_FLOOR
			# Paint from the cell's position within the source window so the full
			# crafted image tiles at its period, NOT a single repeated 32-px
			# sub-tile (the PR #407 wallpaper failure). The atlas window is
			# anchored to the WORLD tile coord (tx,ty) — not a per-region offset —
			# so the windows stay phase-locked to the room grid and the blocks
			# line up consistently across the wider proof room. Per-source period:
			# floor tiles at 2 (64-px 2×2), wall at 4 (128-px 4×4) — see header.
			var period: int = WALL_ATLAS_PERIOD if is_perimeter else FLOOR_ATLAS_PERIOD
			var atlas: Vector2i = Vector2i(tx % period, ty % period)
			_floor_tiles.set_cell(Vector2i(tx, ty), source_id, atlas)
