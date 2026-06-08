extends SceneTree
## Build resources/tilesets/s1_dirtgrass_terrain.tres PROGRAMMATICALLY via the Godot API,
## then ResourceSaver.save() it — so the corner peering bits serialize in Godot's own
## canonical order (a HAND-WRITTEN .tres drops the peering bits, because the per-tile
## `terrains_peering_bit/*` lines parse BEFORE the [resource] block establishes the terrain
## set MODE, so Godot rejects them as invalid-for-mode — verified: bits read back as -1).
##
## Building via the API sets the mode FIRST, then the bits, so save() emits a valid file.
## Run:  godot --headless -s tools/build_dirtgrass_terrain.gd
## Reads wang_dirtgrass_meta.json for the per-tile corner terrain assignment (NE/NW/SE/SW).

const META := "res://assets/tilesets/s1_cloister/wang_dirtgrass_meta.json"
const ATLAS := "res://assets/tilesets/s1_cloister/wang_dirtgrass.png"
const OUT := "res://resources/tilesets/s1_dirtgrass_terrain.tres"
const CELL := 32

# meta corner key -> Godot CELL_NEIGHBOR corner enum.
var _corner_enum := {}


func _init() -> void:
	_corner_enum = {
		"NW": TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
		"NE": TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
		"SW": TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
		"SE": TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
	}
	var terrain := {"lower": 0, "upper": 1}  # dirt / grass

	var f := FileAccess.open(META, FileAccess.READ)
	var meta: Dictionary = JSON.parse_string(f.get_as_text())
	var tiles: Array = meta["tileset_data"]["tiles"]

	var ts := TileSet.new()
	ts.tile_size = Vector2i(CELL, CELL)
	# Terrain set FIRST (so peering bits are valid for the mode when we set them).
	ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	ts.add_terrain(0)  # terrain 0
	ts.set_terrain_name(0, 0, "dirt")
	ts.set_terrain_color(0, 0, Color(0.733, 0.541, 0.427))
	ts.add_terrain(0)  # terrain 1
	ts.set_terrain_name(0, 1, "grass")
	ts.set_terrain_color(0, 1, Color(0.36, 0.45, 0.27))

	var src := TileSetAtlasSource.new()
	src.texture = load(ATLAS)
	src.texture_region_size = Vector2i(CELL, CELL)
	ts.add_source(src, 0)

	for t: Dictionary in tiles:
		var bb: Dictionary = t["bounding_box"]
		var coords := Vector2i(int(bb["x"]) / CELL, int(bb["y"]) / CELL)
		src.create_tile(coords)
		var td: TileData = src.get_tile_data(coords, 0)
		td.terrain_set = 0
		var corners: Dictionary = t["corners"]
		var n_grass := 0
		for cname: String in corners:
			if corners[cname] == "upper":
				n_grass += 1
		td.terrain = 1 if n_grass >= 2 else 0  # center terrain = majority corner
		for cname: String in _corner_enum:
			td.set_terrain_peering_bit(_corner_enum[cname], terrain[corners[cname]])

	var err := ResourceSaver.save(ts, OUT)
	print("[terrain] saved ", OUT, " err=", err, " tiles=", tiles.size())
	# Verify a couple of peering bits round-trip.
	var check := load(OUT) as TileSet
	var cs := check.get_source(0) as TileSetAtlasSource
	var td0 := cs.get_tile_data(Vector2i(2, 1), 0)  # wang_0 all-dirt
	print(
		"[terrain] verify (2,1) terrain=",
		td0.terrain,
		" TL=",
		td0.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER)
	)
	quit()
