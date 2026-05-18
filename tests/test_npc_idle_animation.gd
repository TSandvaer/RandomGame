extends GutTest
## M3W-5 paired test — hub-town NPC idle-animation wiring.
##
## Pins the conventions inherited verbatim from M3W-1 (PR #271) on the 3
## hub-town NPCs (Vendor / Anvil-keeper / Bounty-poster):
##   - SpriteFrames at `assets/sprites/<npc>/<NPC>.tres` loads + exposes
##     all 8 `idle_<dir>` sub-anims (`s, se, e, ne, n, nw, w, sw`).
##   - FPS = 8.0 per anim (M3W-1 convention).
##   - `loop = true` per anim — idle is the only NPC anim and must loop
##     continuously (vs PracticeDummy's hit/die which are `loop = false`
##     one-shots).
##   - NPC scene `Sprite` child resolves to AnimatedSprite2D.
##   - `texture_filter = NEAREST` (pixel-art hardness preserved).
##   - SpriteFrames is assigned on the AnimatedSprite2D.
##   - Initial animation key is `idle_s` (south-facing per the M3W-1
##     stationary-default convention).
##
## NPCs ship instantiable-but-not-instanced — the M3 hub-town scene that
## hosts them is a downstream PR. No state machine, no hit-flash, no
## face-track logic per Priya's m3-scene-wiring-scope.md §M3W-5.
##
## Regression guard: if a downstream PR breaks the SpriteFrames anim-key
## convention (e.g. renames `idle_s` to `idle_south`), the per-direction
## `has_animation` asserts below fail before runtime. If the scene swap
## reverts `AnimatedSprite2D` to `ColorRect`, the type check fails.

const ANIM_DIRS: Array[String] = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]

# Each entry: { npc_id, sprite_frames_path, scene_path, expected_root_name }
const NPC_FIXTURES: Array[Dictionary] = [
	{
		"npc_id": "vendor",
		"sprite_frames_path": "res://assets/sprites/npc_vendor/NPC_Vendor.tres",
		"scene_path": "res://scenes/npcs/NPC_Vendor.tscn",
		"expected_root_name": "NPC_Vendor",
	},
	{
		"npc_id": "anvil_keeper",
		"sprite_frames_path": "res://assets/sprites/npc_anvil_keeper/NPC_AnvilKeeper.tres",
		"scene_path": "res://scenes/npcs/NPC_AnvilKeeper.tscn",
		"expected_root_name": "NPC_AnvilKeeper",
	},
	{
		"npc_id": "bounty_poster",
		"sprite_frames_path": "res://assets/sprites/npc_bounty_poster/NPC_BountyPoster.tres",
		"scene_path": "res://scenes/npcs/NPC_BountyPoster.tscn",
		"expected_root_name": "NPC_BountyPoster",
	},
]


# ---- SpriteFrames resource shape -------------------------------------

func test_each_npc_sprite_frames_loads() -> void:
	for fixture in NPC_FIXTURES:
		var frames: SpriteFrames = load(fixture["sprite_frames_path"]) as SpriteFrames
		assert_not_null(frames,
			"NPC '%s' SpriteFrames at %s loads cleanly" % [fixture["npc_id"], fixture["sprite_frames_path"]])


func test_each_npc_exposes_all_eight_idle_direction_keys() -> void:
	# Eight directions, single state (`idle`) — 8 sub-anims per NPC.
	for fixture in NPC_FIXTURES:
		var frames: SpriteFrames = load(fixture["sprite_frames_path"]) as SpriteFrames
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("idle_%s" % dir_suffix)
			assert_true(frames.has_animation(anim_name),
				"NPC '%s' SpriteFrames exposes '%s'" % [fixture["npc_id"], anim_name])


func test_each_npc_idle_animations_loop_true() -> void:
	# NPCs are stationary and idle continuously — every direction must loop.
	# This is the only convention divergence from PracticeDummy (hit/die are
	# loop=false one-shots); pinning it explicitly because the loop flag is
	# load-bearing for the idle visual.
	for fixture in NPC_FIXTURES:
		var frames: SpriteFrames = load(fixture["sprite_frames_path"]) as SpriteFrames
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("idle_%s" % dir_suffix)
			assert_true(frames.get_animation_loop(anim_name),
				"NPC '%s' '%s' loops (loop=true)" % [fixture["npc_id"], anim_name])


func test_each_npc_idle_animations_play_at_8_fps() -> void:
	# FPS = 8 per M3W-1 convention. Per Priya's brief: PixelLab 4/6-frame
	# anims read cleanly at this rate; downstream walks/idles inherit it.
	for fixture in NPC_FIXTURES:
		var frames: SpriteFrames = load(fixture["sprite_frames_path"]) as SpriteFrames
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("idle_%s" % dir_suffix)
			assert_eq(frames.get_animation_speed(anim_name), 8.0,
				"NPC '%s' '%s' plays at 8 fps" % [fixture["npc_id"], anim_name])


func test_each_npc_idle_animations_have_at_least_one_frame() -> void:
	# PixelLab `breathing-idle` template ships 4 frames per direction; pinning
	# `> 0` rather than `== 4` lets a future re-roll on a different template
	# count (e.g. 6 or 8 frames) land without changing this test.
	for fixture in NPC_FIXTURES:
		var frames: SpriteFrames = load(fixture["sprite_frames_path"]) as SpriteFrames
		for dir_suffix in ANIM_DIRS:
			var anim_name: StringName = StringName("idle_%s" % dir_suffix)
			assert_gt(frames.get_frame_count(anim_name), 0,
				"NPC '%s' '%s' has frames" % [fixture["npc_id"], anim_name])


# ---- NPC scene-wiring shape ------------------------------------------

func test_each_npc_scene_loads_and_has_animated_sprite_named_sprite() -> void:
	# Sprite child resolves to AnimatedSprite2D (not ColorRect). The node-name
	# `Sprite` is preserved for parity with the rest of the M3 roster — any
	# future hit-flash / state-hook resolver continues to grep `get_node("Sprite")`
	# even though NPCs themselves never need hit-flash.
	for fixture in NPC_FIXTURES:
		var packed: PackedScene = load(fixture["scene_path"]) as PackedScene
		assert_not_null(packed,
			"NPC '%s' scene at %s loads" % [fixture["npc_id"], fixture["scene_path"]])
		var root: Node = packed.instantiate()
		add_child_autofree(root)
		assert_eq(root.name, StringName(fixture["expected_root_name"]),
			"NPC '%s' scene root named %s" % [fixture["npc_id"], fixture["expected_root_name"]])
		var sprite_node: Node = root.get_node_or_null("Sprite")
		assert_not_null(sprite_node, "NPC '%s' has a 'Sprite' child" % fixture["npc_id"])
		assert_true(sprite_node is AnimatedSprite2D,
			"NPC '%s' Sprite child is AnimatedSprite2D (M3W-1 convention)" % fixture["npc_id"])


func test_each_npc_scene_assigns_sprite_frames_to_animated_sprite() -> void:
	# SpriteFrames wired in the scene file (not via _ready code). A missing
	# assignment would fail silently in production — the AnimatedSprite2D
	# would render nothing and tests like this one catch the regression.
	for fixture in NPC_FIXTURES:
		var packed: PackedScene = load(fixture["scene_path"]) as PackedScene
		var root: Node = packed.instantiate()
		add_child_autofree(root)
		var asprite: AnimatedSprite2D = root.get_node("Sprite") as AnimatedSprite2D
		assert_not_null(asprite.sprite_frames,
			"NPC '%s' AnimatedSprite2D has SpriteFrames assigned" % fixture["npc_id"])


func test_each_npc_scene_uses_nearest_neighbor_texture_filter() -> void:
	# `texture_filter = NEAREST` (= 1) preserves the pixel-art grid. Bilinear
	# (= 0 or 2) would blur the PixelLab output into mush at the rendered
	# size. Same gate that pinned PracticeDummy.
	for fixture in NPC_FIXTURES:
		var packed: PackedScene = load(fixture["scene_path"]) as PackedScene
		var root: Node = packed.instantiate()
		add_child_autofree(root)
		var asprite: AnimatedSprite2D = root.get_node("Sprite") as AnimatedSprite2D
		assert_eq(asprite.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST,
			"NPC '%s' texture_filter = NEAREST" % fixture["npc_id"])


func test_each_npc_scene_initial_animation_is_idle_s() -> void:
	# `idle_s` is the south-facing key — the default initial pose per the M3W-1
	# stationary-default convention. The scene file sets both `animation` and
	# `autoplay` to `idle_s` so the NPC immediately plays the looping idle on
	# scene-add without needing a `_ready` call.
	for fixture in NPC_FIXTURES:
		var packed: PackedScene = load(fixture["scene_path"]) as PackedScene
		var root: Node = packed.instantiate()
		add_child_autofree(root)
		var asprite: AnimatedSprite2D = root.get_node("Sprite") as AnimatedSprite2D
		# Wait one process_frame so the AnimatedSprite2D's _ready resolves
		# autoplay → is_playing.
		await get_tree().process_frame
		assert_eq(asprite.animation, StringName("idle_s"),
			"NPC '%s' initial animation is 'idle_s'" % fixture["npc_id"])
		assert_true(asprite.is_playing(),
			"NPC '%s' AnimatedSprite2D is_playing after autoplay" % fixture["npc_id"])
