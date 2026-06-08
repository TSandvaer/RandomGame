extends Node2D
## Paintable S1-yard authoring scene controller (ticket 86ca64xzb).
##
## This is the scene Sponsor opens in the Godot editor to PAINT the S1 yard with
## the Cainos tileset + place props, then presses F5 / Play-Scene to see it live.
## It is intentionally minimal: it just gives the painted TileMapLayers a player
## to walk and a camera that follows. The LEVEL ITSELF is authored by Sponsor in
## the editor — this script paints nothing.
##
## Camera: a Camera2D is attached to the Player at runtime with a zoom that shows
## the yard at the same scale as the live game (BASELINE_ZOOM mirrors
## CameraDirector's viewport-stretch ratio so painted tiles read at gameplay size).
##
## The Ground (grass↔stone-path autotile), StonePaths, Walls, and Props nodes are
## defined in the .tscn; this script does not touch their cells.

# Mirrors CameraDirector.BASELINE_ZOOM (viewport 1280x720 vs logical 480x270 =>
# 2.6667). Using it here makes the authoring view match the in-game scale so what
# Sponsor paints looks the same when the chunk is later consumed by the game.
const AUTHOR_ZOOM := Vector2(2.6667, 2.6667)

@export var camera_follows_player := true


func _ready() -> void:
	var player := get_node_or_null("Player")
	if player == null:
		push_warning("[S1YardAuthored] no Player node found — camera will not follow.")
		return

	var cam := Camera2D.new()
	cam.name = "AuthorCamera"
	cam.zoom = AUTHOR_ZOOM
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	if camera_follows_player:
		player.add_child(cam)
	else:
		add_child(cam)
	cam.make_current()

	print("[S1YardAuthored] ready — paint the Ground/StonePaths/Walls layers, " +
		"place props, save, and press F5 to walk your yard. zoom=%s" % str(AUTHOR_ZOOM))
