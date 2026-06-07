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

## The cobble PNG is a 64px 2x2 atlas of 32-px sub-tiles that, stitched in source
## grid order, form ONE seamless varied-cobble block (toroidal-wrapped by the T1
## generator, 256px source downsampled to 64px for the FINER "small player, large
## world" stone scale — at baseline 2.6667x zoom the 0.6 player spans ~2-3 cobbles,
## not ~1). The painter paints each cell from its position WITHIN the source window,
## `Vector2i(tx % period, ty % period)`, so the block tiles with a period-2 (64px)
## repeat — stones read continuous, the only repeat is the soft block seam (which
## the generator wraps seamlessly across, so no dark grid line; verified seamcheck).
const COBBLE_ATLAS_PERIOD: int = 2

## The finer-brick wall is a 128px 4x4 atlas (period 4). Building bricks use this
## period independently of the cobble period above.
const WALL_ATLAS_PERIOD: int = 4

## Yard grid size in tiles. 40x24 @ 32px = 1280x768px — WIDER (1280 > 480) AND
## TALLER (768 > 270) than the viewport, so the camera scrolls in BOTH axes
## (s1-cloister-yard.md §2.1 two-axis scroll = the "big" lever). @export so a
## downstream T7 chunk-extension can author a different size without a code edit;
## the bounds the camera clamps to derive from LevelChunkDef.size_tiles, so the
## .tres size_tiles MUST match these (pinned by the GUT test).
@export var grid_w: int = 40
@export var grid_h: int = 24

## Deterministic decoration seed — fixed so the scatter is reproducible across
## boots (GUT + visual). NOT the per-character world_seed; decoration layout is
## authored content, not procgen variance (that's the floor-assembler's job).
@export var decoration_seed: int = 86

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
@onready var _decoration: Node2D = $Decoration


func _ready() -> void:
	_paint_floor()
	_build_structures()
	_scatter_decoration()


## Paint the full grid_w x grid_h grid as OPEN COBBLE — no perimeter wall ring
## (the yard is open; buildings block via .tscn collision, not a painted wall).
## Idempotent (set_cell overwrites). The atlas window is anchored to the WORLD
## tile coord so the cobble block stays phase-locked across the wide expanse.
func _paint_floor() -> void:
	if _floor_tiles == null:
		push_warning("S1YardChunk: FloorTiles TileMapLayer missing — cannot paint")
		return
	for ty in range(grid_h):
		for tx in range(grid_w):
			var atlas: Vector2i = Vector2i(tx % COBBLE_ATLAS_PERIOD, ty % COBBLE_ATLAS_PERIOD)
			_floor_tiles.set_cell(Vector2i(tx, ty), SOURCE_COBBLE, atlas)


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


## Scatter sparse + jittered + clustered grass/moss decoration into the
## `Decoration` node (s1-cloister-yard.md §5.2). Uses the carried-forward
## `moss_patch` prop as the vegetation stamp. Placement rules:
##   - SPARSE: ~1 cluster per 6-10 tiles (here: a target count derived from area),
##     never one-per-tile.
##   - JITTERED: each tuft offset randomly within its cell (NOT snapped to grid).
##   - CLUSTERED: 2-3 tufts grouped near a chosen anchor, biased toward the yard
##     EDGES + corners (damp zones), the open central lanes left clear for
##     traversal + combat (the "density at edges, clear in the middle" rule).
## Deterministic via `decoration_seed` so the scatter is reproducible.
func _scatter_decoration() -> void:
	if _decoration == null:
		return
	var moss_tex: Texture2D = load("res://assets/props/s1_cloister/moss_patch.png") as Texture2D
	if moss_tex == null:
		push_warning("S1YardChunk: moss_patch.png missing — skipping decoration scatter")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = decoration_seed
	var tile_px: float = 32.0
	# Target cluster count: ~1 per 8 tiles of open area, capped so the yard stays
	# OPEN (sparse-but-alive, never a grass field). 40x24=960 tiles → ~24 clusters.
	var cluster_count: int = int((grid_w * grid_h) / 40.0)
	for _c in range(cluster_count):
		# Anchor biased toward edges/corners (damp zones): pick a band within
		# `edge_band` tiles of an edge with high probability, else anywhere.
		var anchor: Vector2i = _pick_damp_anchor(rng)
		var tufts: int = rng.randi_range(2, 3)  # grass grows in patches
		for _t in range(tufts):
			var jx: float = rng.randf_range(-0.4, 0.4) * tile_px
			var jy: float = rng.randf_range(-0.4, 0.4) * tile_px
			var spread: float = rng.randf_range(-0.8, 0.8) * tile_px
			var spread_y: float = rng.randf_range(-0.8, 0.8) * tile_px
			var pos := Vector2(
				(anchor.x + 0.5) * tile_px + jx + spread, (anchor.y + 0.5) * tile_px + jy + spread_y
			)
			var spr := Sprite2D.new()
			spr.texture = moss_tex
			spr.position = pos
			# Slight per-tuft scale + flip jitter so no two read identical.
			var s: float = rng.randf_range(0.7, 1.05)
			spr.scale = Vector2(s, s)
			spr.flip_h = rng.randf() < 0.5
			_decoration.add_child(spr)


## Pick a decoration anchor tile biased toward the yard edges/corners (where damp
## collects — s1-cloister-yard.md §5.2), keeping the open central lanes clear.
func _pick_damp_anchor(rng: RandomNumberGenerator) -> Vector2i:
	var edge_band: int = 4
	if rng.randf() < 0.7:
		# Edge-biased: snap one axis into the edge band.
		if rng.randf() < 0.5:
			var x: int = (
				rng.randi_range(0, edge_band - 1)
				if rng.randf() < 0.5
				else rng.randi_range(grid_w - edge_band, grid_w - 1)
			)
			return Vector2i(x, rng.randi_range(0, grid_h - 1))
		var y: int = (
			rng.randi_range(0, edge_band - 1)
			if rng.randf() < 0.5
			else rng.randi_range(grid_h - edge_band, grid_h - 1)
		)
		return Vector2i(rng.randi_range(0, grid_w - 1), y)
	# Else anywhere (a little life in the open too).
	return Vector2i(rng.randi_range(0, grid_w - 1), rng.randi_range(0, grid_h - 1))
