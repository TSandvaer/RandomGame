extends SceneTree
## Builds the paintable S1-yard authoring scene (ticket 86ca64xzb).
##
## Run headless:
##   godot --headless --path <project> --script res://tools/build_s1_authored_scene.gd
##
## Output: scenes/levels/s1_yard_authored.tscn
##
## The scene Sponsor opens + paints:
##   Node2D  S1YardAuthored                (script attaches a follow-camera at runtime)
##    ├─ Ground       TileMapLayer  (cainos_s1 set, terrain 0/1 = grass↔stone-path autotile)
##    ├─ StoneGround  TileMapLayer  (cainos_s1 set, source 1 = stone slabs, z=0)
##    ├─ Walls        TileMapLayer  (cainos_s1 set, source 2 = brick walls, z=1)
##    ├─ Props        Node2D        (z=2 — drag Cainos prop/plant/struct Sprite2Ds + the
##    │                              5 PixelLab building sprites here)
##    └─ Player       (instanced scenes/player/Player.tscn at a sensible spawn)
##
## A small STARTER PATCH of autotiled ground (grass field with a stone path strip)
## is painted so the scene renders Cainos tiles the moment it opens / runs — proves
## the wiring + gives Sponsor something to extend. Sponsor erases/extends freely.

const TILE := 32
const OUT_PATH := "res://scenes/levels/s1_yard_authored.tscn"
const TILESET_PATH := "res://resources/tilesets/cainos_s1.tres"
const SCRIPT_PATH := "res://scripts/levels/S1YardAuthored.gd"
const PLAYER_PATH := "res://scenes/player/Player.tscn"

const T_GRASS := 0
const T_PATH := 1


func _init() -> void:
	var ts := load(TILESET_PATH) as TileSet
	if ts == null:
		push_error("[build_s1_authored_scene] cannot load %s — run build_cainos_tileset.gd first" % TILESET_PATH)
		quit(1)
		return

	var root := Node2D.new()
	root.name = "S1YardAuthored"
	root.set_script(load(SCRIPT_PATH))

	# --- Ground: grass↔stone-path autotile layer ---
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = ts
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(ground)

	# --- StoneGround: discrete stone slab layer (source 1), same z as ground ---
	var stone := TileMapLayer.new()
	stone.name = "StoneGround"
	stone.tile_set = ts
	stone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(stone)

	# --- Walls: brick layer (source 2), drawn above ground ---
	var walls := TileMapLayer.new()
	walls.name = "Walls"
	walls.tile_set = ts
	walls.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	walls.z_index = 1
	root.add_child(walls)

	# --- Props container (drag Sprite2Ds here) ---
	var props := Node2D.new()
	props.name = "Props"
	props.z_index = 2
	root.add_child(props)

	# --- Player instance ---
	var player_scene := load(PLAYER_PATH) as PackedScene
	var player := player_scene.instantiate()
	player.name = "Player"
	player.position = Vector2(320, 320)
	root.add_child(player)

	# Ownership: every node must have owner=root to serialize into the .tscn.
	_set_owner_recursive(root, root)

	# --- Paint a starter patch so the scene renders Cainos tiles on open ---
	# A 20x14-cell grass field (terrain 0) with a 3-wide stone path (terrain 1)
	# running through it — uses set_cells_terrain_connect so the autotiler picks
	# the correct grass↔path transition tiles.
	var grass_cells: Array[Vector2i] = []
	for y in range(14):
		for x in range(20):
			grass_cells.append(Vector2i(x, y))
	ground.set_cells_terrain_connect(grass_cells, 0, T_GRASS, false)

	var path_cells: Array[Vector2i] = []
	for y in range(14):
		for x in range(8, 11):
			path_cells.append(Vector2i(x, y))
	ground.set_cells_terrain_connect(path_cells, 0, T_PATH, false)

	# set_cells_terrain_connect commits NEXT frame in headless — wait before pack.
	await process_frame
	await process_frame

	var packed := PackedScene.new()
	var perr := packed.pack(root)
	if perr != OK:
		push_error("[build_s1_authored_scene] pack failed: %d" % perr)
		quit(1)
		return
	var serr := ResourceSaver.save(packed, OUT_PATH)
	if serr != OK:
		push_error("[build_s1_authored_scene] save failed: %d" % serr)
		quit(1)
		return

	var painted := ground.get_used_cells().size()
	print("[build_s1_authored_scene] wrote %s (starter ground cells painted=%d)" % [OUT_PATH, painted])
	quit(0)


func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		if child != owner:
			child.owner = owner
		_set_owner_recursive(child, owner)
