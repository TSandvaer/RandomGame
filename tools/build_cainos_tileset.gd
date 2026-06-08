extends SceneTree
## Builds the Cainos S1 paintable TileSet (.tres) programmatically.
##
## WHY a builder, not a hand-written .tres:
##   A corner-Wang TerrainSet hand-authored as text silently DROPS the per-tile
##   peering bits (terrain-mode vs .tres parse-order serialization quirk) — the
##   autotiler then has no transition tiles and falls back to hard edges.
##   Build the terrain resource via the TileData API + ResourceSaver.save instead.
##   (procgen-pipeline.md § "Godot autotile TERRAIN authoring".)
##
## Run headless:
##   godot --headless --path <project> --script res://tools/build_cainos_tileset.gd
##
## Output: resources/tilesets/cainos_s1.tres
##
## TileSet layout (all 32px tiles, Nearest filter via project default):
##   Source 0  grass        (tx_tileset_grass.png, 8x8)  — TerrainSet 0:
##                            terrain 0 = grass, terrain 1 = stone_path.
##                            Corner-only autotile painted from the rows 4-7 Wang
##                            block (grass↔cobble-path blend). All 64 cells are
##                            also plain-paintable.
##   Source 1  stone_ground (tx_tileset_stone_ground.png, 8x8) — discrete slab
##                            tiles, all paintable (solid courtyard floor + framed
##                            borders). No corner terrain (the sheet is framed
##                            slabs, not an alpha-cutout blob set).
##   Source 2  wall         (tx_tileset_wall.png, 16x16) — brick wall pieces,
##                            all paintable.
##   Source 3  props        (tx_props.png, 16x16) — placeable prop tiles.
##   Source 4  plant        (tx_plant.png, 16x16) — placeable foliage tiles.
##   Source 5  struct       (tx_struct.png, 16x16) — placeable structure tiles.
##
## The grass↔stone-path corner map below was derived empirically from the Cainos
## sheet (tools/_cainos_corner_map.md records the derivation). Each entry is the
## 4 cell-corners as terrain ids: [top_left, top_right, bottom_left, bottom_right],
## 0 = grass, 1 = stone_path.

const TILE := 32
const OUT_PATH := "res://resources/tilesets/cainos_s1.tres"

const GRASS_PNG := "res://assets/tilesets/cainos/tx_tileset_grass.png"
const STONE_PNG := "res://assets/tilesets/cainos/tx_tileset_stone_ground.png"
const WALL_PNG := "res://assets/tilesets/cainos/tx_tileset_wall.png"
const PROPS_PNG := "res://assets/tilesets/cainos/tx_props.png"
const PLANT_PNG := "res://assets/tilesets/cainos/tx_plant.png"
const STRUCT_PNG := "res://assets/tilesets/cainos/tx_struct.png"

# Terrain ids inside TerrainSet 0.
const T_GRASS := 0
const T_PATH := 1

# Grass↔stone-path corner map: cell (col,row) -> [TL,TR,BL,BR] terrain ids.
# Derived from the rows 4-7 Wang block of tx_tileset_grass.png (S=path=1, G=grass=0).
# Cells NOT listed default to all-grass (terrain 0) — they are the plain-grass
# field tiles (rows 0-3) and remain paintable as solid grass.
const PATH_CORNERS := {
	# Solid stone-path fill variants (cols 0-1, rows 4-6).
	Vector2i(0, 4): [1, 1, 1, 1], Vector2i(1, 4): [1, 1, 1, 1],
	Vector2i(0, 5): [1, 1, 1, 1], Vector2i(1, 5): [1, 1, 1, 1],
	Vector2i(0, 6): [1, 1, 1, 1], Vector2i(1, 6): [1, 1, 1, 1],
	# Vertical edges (cols 2-3, rows 4-6): GSGS = grass-left/path-right, SGSG = path-left/grass-right.
	Vector2i(2, 4): [0, 1, 0, 1], Vector2i(3, 4): [1, 0, 1, 0],
	Vector2i(2, 5): [0, 1, 0, 1], Vector2i(3, 5): [1, 0, 1, 0],
	Vector2i(2, 6): [0, 1, 0, 1], Vector2i(3, 6): [1, 0, 1, 0],
	# Top edge / top corners (cols 4-7, rows 4-5).
	Vector2i(4, 4): [0, 0, 1, 1], Vector2i(5, 4): [0, 0, 1, 1],
	Vector2i(6, 4): [0, 0, 1, 1], Vector2i(7, 4): [0, 0, 1, 1],
	Vector2i(4, 5): [1, 1, 0, 0], Vector2i(5, 5): [1, 1, 0, 0],
	Vector2i(6, 5): [1, 1, 0, 0], Vector2i(7, 5): [1, 1, 0, 0],
	# Outer corners (row 6 cols 4-7) — path corner into grass.
	Vector2i(4, 6): [1, 0, 0, 0], Vector2i(5, 6): [0, 1, 0, 0],
	Vector2i(6, 6): [0, 0, 1, 0], Vector2i(7, 6): [0, 0, 0, 1],
	# Inner corners (row 7 cols 4-5) — grass notch into path.
	Vector2i(4, 7): [0, 1, 1, 1], Vector2i(5, 7): [1, 0, 1, 1],
}


func _init() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)

	# --- Source 0: grass (with terrain set + corners) ---
	var grass_src := _make_atlas_source(GRASS_PNG)
	ts.add_source(grass_src, 0)

	# Terrain set 0 — corner mode, terrains grass + stone_path.
	ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	ts.add_terrain(0)  # terrain 0
	ts.set_terrain_name(0, T_GRASS, "grass")
	ts.set_terrain_color(0, T_GRASS, Color(0.45, 0.46, 0.11))
	ts.add_terrain(0)  # terrain 1
	ts.set_terrain_name(0, T_PATH, "stone_path")
	ts.set_terrain_color(0, T_PATH, Color(0.50, 0.49, 0.45))

	_assign_grass_terrain(grass_src)

	# --- Sources 1-5: plain paintable atlases ---
	ts.add_source(_make_atlas_source(STONE_PNG), 1)
	ts.add_source(_make_atlas_source(WALL_PNG), 2)
	ts.add_source(_make_atlas_source(PROPS_PNG), 3)
	ts.add_source(_make_atlas_source(PLANT_PNG), 4)
	ts.add_source(_make_atlas_source(STRUCT_PNG), 5)

	var err := ResourceSaver.save(ts, OUT_PATH)
	if err != OK:
		push_error("[build_cainos_tileset] ResourceSaver.save failed: %d" % err)
		quit(1)
		return
	print("[build_cainos_tileset] wrote %s (sources=%d terrains=%d)" % [
		OUT_PATH, ts.get_source_count(), ts.get_terrains_count(0)])
	quit(0)


## Builds a TileSetAtlasSource that registers EVERY 32px cell as a paintable tile.
func _make_atlas_source(png_path: String) -> TileSetAtlasSource:
	var tex := load(png_path) as Texture2D
	if tex == null:
		push_error("[build_cainos_tileset] failed to load %s" % png_path)
		quit(1)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	var cols := tex.get_width() / TILE
	var rows := tex.get_height() / TILE
	for y in range(rows):
		for x in range(cols):
			var coord := Vector2i(x, y)
			# Skip fully-transparent cells (no paintable tile there).
			if _cell_is_empty(tex, coord):
				continue
			src.create_tile(coord)
	return src


func _cell_is_empty(tex: Texture2D, coord: Vector2i) -> bool:
	var img := tex.get_image()
	if img == null:
		return false
	if not img.is_compressed():
		var opaque := 0
		for dy in range(0, TILE, 4):
			for dx in range(0, TILE, 4):
				var px := img.get_pixel(coord.x * TILE + dx, coord.y * TILE + dy)
				if px.a > 0.12:
					opaque += 1
		return opaque == 0
	return false


## Writes the corner peering bits onto the grass source per PATH_CORNERS.
## Cells not in the map are set all-grass (terrain 0) so the field tiles
## participate in the terrain as solid grass.
func _assign_grass_terrain(src: TileSetAtlasSource) -> void:
	var tex := src.texture
	var cols := tex.get_width() / TILE
	var rows := tex.get_height() / TILE
	for y in range(rows):
		for x in range(cols):
			var coord := Vector2i(x, y)
			if not src.has_tile(coord):
				continue
			var data := src.get_tile_data(coord, 0)
			if data == null:
				continue
			data.terrain_set = 0
			var corners: Array = PATH_CORNERS.get(coord, [T_GRASS, T_GRASS, T_GRASS, T_GRASS])
			# TileData corner peering-bit setters (corner-match mode):
			data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, corners[0])
			data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER, corners[1])
			data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, corners[2])
			data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER, corners[3])
			# The tile's own "terrain" = majority corner (used by the editor brush
			# to bucket tiles under a terrain). Grass-dominant -> grass, else path.
			var path_count := 0
			for c in corners:
				if c == T_PATH:
					path_count += 1
			data.terrain = T_PATH if path_count >= 3 else T_GRASS
