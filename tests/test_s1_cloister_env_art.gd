# gdlint:disable=max-public-methods
# GUT test class — high test_* count IS the design (one test per scenario).
extends GutTest
## Env-art wiring tests for the S1 "Outer Cloister" chunk (ticket 86ca3h8hn,
## Uma brief §3/§7.1). Verifies the foundational slice:
##   1. resources/tilesets/s1_cloister.tres loads with floor + wall sources +
##      terrain peering rules.
##   2. s1_room01_chunk.tscn paints a TileMapLayer floor (interior) + wall
##      perimeter band after _ready (the ColorRect→TileMapLayer swap).
##   3. The four Wall* StaticBody2D + CollisionShape2D perimeter nodes are
##      UNCHANGED (collision decoupled from visual — BB-3 invariant).
##   4. Props placed at z_index=+1, OFF the player spawn tile (240,200) and
##      OFF the port-opening tiles.
##   5. No USER WARNING during load/paint (WarningBus guard).
##
## Paired Playwright spec: tests/playwright/specs/s1-env-art-render.spec.ts.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

const TILESET_PATH: String = "res://resources/tilesets/s1_cloister.tres"
const CHUNK_SCENE_PATH: String = "res://scenes/levels/chunks/s1_room01_chunk.tscn"

# Grid geometry — must match LevelChunkDef.size_tiles / tile_size_px and
# S1CloisterChunk.GRID_W/GRID_H.
const GRID_W: int = 15
const GRID_H: int = 8
const SOURCE_FLOOR: int = 0
const SOURCE_WALL: int = 1

# DEFAULT_PLAYER_SPAWN = (240, 200) px → tile (7, 6) at 32px. Props must not
# sit on this tile.
const SPAWN_TILE: Vector2i = Vector2i(7, 6)
# Ports sit on tile-row y=4 (s1_room0N.tres entry/exit ports). Props must not
# block the WEST (x<=1) or EAST (x>=13) opening on that row.
const PORT_ROW_Y: int = 4

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- Helpers ---------------------------------------------------------


func _instantiate_chunk() -> Node:
	var packed: PackedScene = load(CHUNK_SCENE_PATH)
	assert_not_null(packed, "chunk scene must load: %s" % CHUNK_SCENE_PATH)
	var inst: Node = packed.instantiate()
	add_child_autofree(inst)
	return inst


func _collect_static_bodies(root: Node) -> Array:
	var out: Array = []
	if root is StaticBody2D:
		out.append(root)
	for child in root.get_children():
		out.append_array(_collect_static_bodies(child))
	return out


# ---- 1. TileSet resource --------------------------------------------


func test_tileset_resource_loads() -> void:
	var ts: TileSet = load(TILESET_PATH)
	assert_not_null(ts, "s1_cloister.tres must load as a TileSet")
	assert_eq(
		ts.tile_size, Vector2i(32, 32), "tile size must be 32x32 (LevelChunkDef.tile_size_px)"
	)


func test_tileset_has_floor_and_wall_sources() -> void:
	var ts: TileSet = load(TILESET_PATH)
	assert_true(ts.has_source(SOURCE_FLOOR), "TileSet must declare floor atlas source 0")
	assert_true(ts.has_source(SOURCE_WALL), "TileSet must declare wall atlas source 1")
	var floor_src: TileSetAtlasSource = ts.get_source(SOURCE_FLOOR)
	var wall_src: TileSetAtlasSource = ts.get_source(SOURCE_WALL)
	assert_true(floor_src is TileSetAtlasSource, "floor source is an atlas source")
	assert_true(wall_src is TileSetAtlasSource, "wall source is an atlas source")
	assert_not_null(floor_src.texture, "floor source has a texture")
	assert_not_null(wall_src.texture, "wall source has a texture")


func test_tileset_declares_terrain_peering_rules() -> void:
	# Brief §7.1 task 1: author terrain peering so a room can be painted by
	# dragging. Assert at least one terrain set + the two named terrains.
	var ts: TileSet = load(TILESET_PATH)
	assert_gte(ts.get_terrain_sets_count(), 1, "TileSet must declare >=1 terrain set")
	assert_gte(
		ts.get_terrains_count(0),
		2,
		"terrain set 0 must declare sandstone + cloister_stone terrains"
	)


# ---- 2. TileMapLayer painted ----------------------------------------


func test_chunk_has_tilemaplayer_not_floor_colorrect() -> void:
	var inst: Node = _instantiate_chunk()
	var floor_tiles: Node = inst.get_node_or_null("FloorTiles")
	assert_not_null(floor_tiles, "chunk must carry a FloorTiles node")
	assert_true(
		floor_tiles is TileMapLayer,
		"FloorTiles must be a TileMapLayer (ColorRect→TileMapLayer swap)"
	)
	# The old flat Floor ColorRect must be gone.
	assert_null(inst.get_node_or_null("Floor"), "old flat Floor ColorRect must be removed")


func test_chunk_floor_interior_painted_with_floor_source() -> void:
	var inst: Node = _instantiate_chunk()
	# _ready paints synchronously; the @onready ref resolves on tree-entry.
	var floor_tiles: TileMapLayer = inst.get_node("FloorTiles")
	# Sample an interior tile (not perimeter) — must be the floor source.
	var interior: Vector2i = Vector2i(7, 4)
	assert_eq(
		floor_tiles.get_cell_source_id(interior),
		SOURCE_FLOOR,
		"interior cell %s must be painted from the floor source" % interior
	)


func test_chunk_perimeter_painted_with_wall_source() -> void:
	var inst: Node = _instantiate_chunk()
	var floor_tiles: TileMapLayer = inst.get_node("FloorTiles")
	# Sample one cell on each perimeter edge — must be the wall source.
	var samples: Array[Vector2i] = [
		Vector2i(7, 0),  # north
		Vector2i(7, GRID_H - 1),  # south
		Vector2i(0, 4),  # west
		Vector2i(GRID_W - 1, 4),  # east
	]
	for c: Vector2i in samples:
		assert_eq(
			floor_tiles.get_cell_source_id(c),
			SOURCE_WALL,
			"perimeter cell %s must be painted from the wall source" % c
		)


func test_chunk_every_cell_in_grid_is_painted() -> void:
	var inst: Node = _instantiate_chunk()
	var floor_tiles: TileMapLayer = inst.get_node("FloorTiles")
	var unpainted: int = 0
	for ty in range(GRID_H):
		for tx in range(GRID_W):
			if floor_tiles.get_cell_source_id(Vector2i(tx, ty)) == -1:
				unpainted += 1
	assert_eq(
		unpainted,
		0,
		"all %d cells of the 15x8 grid must be painted; %d unpainted" % [GRID_W * GRID_H, unpainted]
	)


# ---- 3. Collision perimeter UNCHANGED -------------------------------


func test_collision_perimeter_nodes_unchanged() -> void:
	var inst: Node = _instantiate_chunk()
	# The four named StaticBody2D walls must still exist with their child
	# CollisionShape2D — the env-art swap touches only the VISUAL children.
	for wall_name: String in ["WallNorth", "WallSouth", "WallWest", "WallEast"]:
		var wall: Node = inst.get_node_or_null(wall_name)
		assert_not_null(
			wall, "%s StaticBody2D must still exist (collision decoupled from visual)" % wall_name
		)
		assert_true(wall is StaticBody2D, "%s must be a StaticBody2D" % wall_name)
		var cs: Node = wall.get_node_or_null("CollisionShape2D")
		assert_not_null(cs, "%s must keep its CollisionShape2D" % wall_name)
		assert_true(
			(cs as CollisionShape2D).shape is RectangleShape2D,
			"%s shape is a RectangleShape2D" % wall_name
		)


func test_collision_perimeter_count_is_four() -> void:
	var inst: Node = _instantiate_chunk()
	var bodies: Array = _collect_static_bodies(inst)
	assert_eq(
		bodies.size(),
		4,
		"chunk must carry exactly 4 perimeter StaticBody2D walls; got %d" % bodies.size()
	)


func test_collision_shapes_match_authored_sizes() -> void:
	# Byte-unchanged perimeter: N/S = 480x32, E/W = 32x256.
	var inst: Node = _instantiate_chunk()
	for wall_name: String in ["WallNorth", "WallSouth"]:
		var cs: CollisionShape2D = inst.get_node("%s/CollisionShape2D" % wall_name)
		assert_eq(
			(cs.shape as RectangleShape2D).size, Vector2(480, 32), "%s shape size" % wall_name
		)
	for wall_name: String in ["WallWest", "WallEast"]:
		var cs: CollisionShape2D = inst.get_node("%s/CollisionShape2D" % wall_name)
		assert_eq(
			(cs.shape as RectangleShape2D).size, Vector2(32, 256), "%s shape size" % wall_name
		)


# ---- 4. Props at z+1, off spawn/port tiles --------------------------


func test_props_present_under_props_node() -> void:
	var inst: Node = _instantiate_chunk()
	var props: Node = inst.get_node_or_null("Props")
	assert_not_null(props, "chunk must carry a Props node")
	var sprite_count: int = 0
	for child in props.get_children():
		if child is Sprite2D:
			sprite_count += 1
	assert_gte(
		sprite_count, 3, "at least 3 prop Sprite2D nodes per §5 2a density; got %d" % sprite_count
	)


func test_props_render_above_floor() -> void:
	# Per html5-export.md §4.1: props at z_index=+1 (above the floor TileMap
	# at z=0); never negative z. The Props container carries the +1.
	var inst: Node = _instantiate_chunk()
	var props: Node2D = inst.get_node("Props")
	assert_eq(props.z_index, 1, "Props container must be z_index=+1 (above floor, never negative)")


func test_props_off_spawn_and_port_tiles() -> void:
	var inst: Node = _instantiate_chunk()
	var props: Node = inst.get_node("Props")
	for child in props.get_children():
		if not (child is Sprite2D):
			continue
		var sprite: Sprite2D = child
		var tile: Vector2i = Vector2i(int(sprite.position.x) / 32, int(sprite.position.y) / 32)
		# Off the player spawn tile.
		assert_ne(
			tile, SPAWN_TILE, "prop %s sits ON the player spawn tile %s" % [sprite.name, SPAWN_TILE]
		)
		# Off the WEST/EAST port openings on the port row.
		var on_port_row: bool = tile.y == PORT_ROW_Y
		var on_west_port: bool = on_port_row and tile.x <= 1
		var on_east_port: bool = on_port_row and tile.x >= GRID_W - 2
		assert_false(
			on_west_port, "prop %s blocks the WEST port opening (tile %s)" % [sprite.name, tile]
		)
		assert_false(
			on_east_port, "prop %s blocks the EAST port opening (tile %s)" % [sprite.name, tile]
		)


# ---- 5. Floor-meets-wall seam (ColorRect, not Polygon2D) ------------


func test_floor_wall_seam_uses_colorrect() -> void:
	# Brief §4.1 / PR #137: ember/shadow accents use ColorRect, never Polygon2D.
	var inst: Node = _instantiate_chunk()
	var seam: Node = inst.get_node_or_null("FloorWallSeam")
	assert_not_null(seam, "chunk must carry the FloorWallSeam shadow node")
	var colorrects: int = 0
	for child in seam.get_children():
		assert_false(
			child is Polygon2D, "seam must NOT use Polygon2D (gl_compatibility invisibility risk)"
		)
		if child is ColorRect:
			colorrects += 1
	assert_gte(colorrects, 1, "seam must use >=1 ColorRect")


func test_seam_colors_are_hdr_clamp_safe() -> void:
	# Every tint sub-1.0 on every channel (html5-export.md HDR clamp).
	var inst: Node = _instantiate_chunk()
	var seam: Node = inst.get_node("FloorWallSeam")
	for child in seam.get_children():
		if child is ColorRect:
			var c: Color = (child as ColorRect).color
			assert_lte(c.r, 1.0, "seam R channel must be <= 1.0")
			assert_lte(c.g, 1.0, "seam G channel must be <= 1.0")
			assert_lte(c.b, 1.0, "seam B channel must be <= 1.0")
