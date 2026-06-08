extends SceneTree
## Builds the prop-palette scene (ticket 86ca64xzb) — a visual tray of every
## placeable prop, laid out with name labels, so Sponsor can OPEN it, see each
## prop, and COPY (Ctrl+C) a Sprite2D node straight into s1_yard_authored.tscn
## (Ctrl+V). Each prop is a fully-configured Sprite2D — paste it, drag it where
## you want, done.
##
## Run headless:
##   godot --headless --path <project> --script res://tools/build_prop_palette_scene.gd
##
## Output: scenes/levels/s1_prop_palette.tscn
##
## Contents:
##   - 5 carried-forward PixelLab cloister props (pillar / brazier / banner /
##     rubble / parchment) as standalone Sprite2D nodes.
##   - A handful of Cainos props (barrel, crate, signpost, gravestone, statue)
##     as AtlasTexture Sprite2D nodes sliced from tx_props / tx_struct.
##
## Cainos props/plant/struct are ALSO registered as paintable atlas sources in
## cainos_s1.tres (sources 3/4/5) — Sponsor can alternatively PAINT them onto a
## TileMapLayer. This palette is the copy-a-Sprite path for the larger landmark
## props that read better as free-placed sprites than as grid tiles.

const OUT_PATH := "res://scenes/levels/s1_prop_palette.tscn"
const TILE := 32

# Carried-forward PixelLab props (the real on-main set — see PR body note on the
# ticket's `s1_yard/` path vs the actual `s1_cloister/` location).
const PIXELLAB_PROPS := [
	["Pillar", "res://assets/props/s1_cloister/pillar_arch.png"],
	["BrazierLit", "res://assets/props/s1_cloister/brazier_lit.png"],
	["BrazierCold", "res://assets/props/s1_cloister/brazier_cold.png"],
	["Banner", "res://assets/props/s1_cloister/banner_worn.png"],
	["Rubble", "res://assets/props/s1_cloister/rubble_01.png"],
	["Parchment", "res://assets/props/s1_cloister/parchment_01.png"],
]

# A few useful Cainos props as AtlasTexture regions (region = Rect2(x,y,w,h) in px).
# Coords read off tx_props.png / tx_struct.png (512x512). Sized generously to
# capture each whole prop; Sponsor can tweak the region in the inspector.
const CAINOS_PROPS := [
	["CainosBarrel", "res://assets/tilesets/cainos/tx_props.png", Rect2(96, 160, 32, 48)],
	["CainosCrate", "res://assets/tilesets/cainos/tx_props.png", Rect2(64, 16, 40, 40)],
	["CainosSignpost", "res://assets/tilesets/cainos/tx_props.png", Rect2(96, 176, 40, 64)],
	["CainosGravestone", "res://assets/tilesets/cainos/tx_props.png", Rect2(224, 160, 48, 64)],
	["CainosStatue", "res://assets/tilesets/cainos/tx_props.png", Rect2(416, 16, 64, 80)],
]


func _init() -> void:
	var root := Node2D.new()
	root.name = "S1PropPalette"

	var info := Label.new()
	info.name = "HowTo"
	info.position = Vector2(16, 8)
	info.text = "PROP PALETTE — click a prop's Sprite2D in the Scene tree, Ctrl+C, " + \
		"open s1_yard_authored.tscn, click the Props node, Ctrl+V, then drag into place."
	info.owner = null
	root.add_child(info)
	info.owner = root

	var x := 64.0
	var y := 96.0
	var col := 0

	for entry in PIXELLAB_PROPS:
		var spr := _make_sprite(entry[0], load(entry[1]) as Texture2D, Vector2(x, y))
		root.add_child(spr)
		spr.owner = root
		_add_label(root, entry[0], Vector2(x - 40, y + 60))
		x += 160.0
		col += 1
		if col >= 4:
			col = 0
			x = 64.0
			y += 180.0

	# new row for Cainos props
	x = 64.0
	y += 180.0
	col = 0
	for entry in CAINOS_PROPS:
		var atlas := AtlasTexture.new()
		atlas.atlas = load(entry[1]) as Texture2D
		atlas.region = entry[2]
		var spr := _make_sprite(entry[0], atlas, Vector2(x, y))
		root.add_child(spr)
		spr.owner = root
		_add_label(root, entry[0], Vector2(x - 40, y + 50))
		x += 160.0
		col += 1
		if col >= 4:
			col = 0
			x = 64.0
			y += 160.0

	var packed := PackedScene.new()
	var perr := packed.pack(root)
	if perr != OK:
		push_error("[build_prop_palette_scene] pack failed: %d" % perr)
		quit(1)
		return
	var serr := ResourceSaver.save(packed, OUT_PATH)
	if serr != OK:
		push_error("[build_prop_palette_scene] save failed: %d" % serr)
		quit(1)
		return
	print("[build_prop_palette_scene] wrote %s (pixellab=%d cainos=%d)" % [
		OUT_PATH, PIXELLAB_PROPS.size(), CAINOS_PROPS.size()])
	quit(0)


func _make_sprite(node_name: String, tex: Texture2D, pos: Vector2) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.name = node_name
	spr.texture = tex
	spr.position = pos
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return spr


func _add_label(root: Node2D, txt: String, pos: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = txt
	lbl.position = pos
	root.add_child(lbl)
	lbl.owner = root
