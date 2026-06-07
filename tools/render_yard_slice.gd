extends SceneTree
## One-off in-engine renderer for the S1 yard slice (ticket 86ca5erzk Self-Test
## Report). Loads the yard + descent chunks under a SubViewport, renders a few
## representative views (full-yard overview + game-zoom crops) by repositioning a
## single Camera2D, and saves PNGs to _yard_render/. Run:
##   godot --headless -s tools/render_yard_slice.gd
## NOT a test; not shipped in the play loop. The HTML5-gate self-soak stand-in
## (no export templates locally → in-engine render is the evidence).

const YARD_SCENE := "res://scenes/levels/chunks/s1_yard_slice_chunk.tscn"
const DESCENT_SCENE := "res://scenes/levels/chunks/s1_yard_descent_chunk.tscn"
const OUT_DIR := "res://_yard_render"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var vp := SubViewport.new()
	vp.size = Vector2i(960, 540)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	get_root().add_child(vp)

	var world := Node2D.new()
	vp.add_child(world)
	world.add_child(load(YARD_SCENE).instantiate())
	var descent: Node2D = load(DESCENT_SCENE).instantiate()
	descent.position = Vector2(40 * 32, 0)
	world.add_child(descent)

	var cam := Camera2D.new()
	vp.add_child(cam)
	cam.make_current()

	# Let _ready painters + a few frames commit the TileMapLayers.
	for _i in range(4):
		await process_frame

	await _shot(vp, cam, Rect2(0, 0, 1472, 768), "yard_overview.png")
	await _shot(vp, cam, Rect2(0, 250, 480, 270), "yard_spawn_vista.png")
	await _shot(vp, cam, Rect2(440, 250, 480, 270), "yard_central_building.png")

	print("[render] DONE — yard renders in ", OUT_DIR)
	quit()


func _shot(vp: SubViewport, cam: Camera2D, world_rect: Rect2, fname: String) -> void:
	cam.position = world_rect.position + world_rect.size * 0.5
	cam.zoom = Vector2(float(vp.size.x) / world_rect.size.x, float(vp.size.y) / world_rect.size.y)
	for _i in range(3):
		await process_frame
	var img: Image = vp.get_texture().get_image()
	var err: int = img.save_png(OUT_DIR + "/" + fname)
	print("[render] ", fname, " -> err=", err, " size=", img.get_size())
