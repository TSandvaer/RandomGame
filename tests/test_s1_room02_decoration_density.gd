# gdlint:disable=max-public-methods
extends GutTest
## S1 widened-room decoration-density pass (ticket 86ca3yuwv — Drew Stage B impl
## of Uma's brief team/uma-ux/s1-decoration-density.md).
##
## The actual "reads furnished/intentional at game zoom + char_scale=0.6" call is
## the Sponsor-soak gate of record (HTML5 visual gate). These headless pins guard
## the mechanics the soak cannot assert cheaply:
##
##   - The 3 approved-but-unused props are ACTIVATED (brazier_cold, banner_worn,
##     pillar_arch) — the core "reuse-only first pass" deliverable.
##   - Density rose into Uma's 20-24 target band for the 960x256 room.
##   - KEEP-CLEAR is honored EXACTLY (chunk-def-traced): no decoration node sits
##     in the central lane (y 112-176), within ~48px of a grunt-spawn tile, in
##     either port region, or in the RoomGate swept area. This is the regression
##     guard — a future coord edit that drifts a prop into the aisle / onto a
##     spawn / over the gate fails loud here, BEFORE the Sponsor soaks.
##   - The painter still paints the full 30x8 grid with zero WarningBus
##     emissions (decoration is additive Sprite2D over the painter; must not
##     regress the warning gate).

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

const WIDE_CHUNK_SCENE_PATH: String = "res://scenes/levels/chunks/s1_room02_wide_chunk.tscn"
const WIDE_CHUNK_DEF_PATH: String = "res://resources/level_chunks/s1_room02_wide.tres"

# The 3 approved-but-unused props this pass activates (Uma brief §4).
const ACTIVATED_PROP_TEXTURES: Array[String] = [
	"res://assets/props/s1_cloister/brazier_cold.png",
	"res://assets/props/s1_cloister/banner_worn.png",
	"res://assets/props/s1_cloister/pillar_arch.png",
]

# Central processional lane (Uma brief §2 keep-clear) — full-width band.
const LANE_Y_MIN: float = 112.0
const LANE_Y_MAX: float = 176.0
const LANE_X_MIN: float = 64.0
const LANE_X_MAX: float = 896.0

# Spawn keep-clear radius (Uma brief §2 — ~48px around each grunt-spawn tile).
const SPAWN_CLEAR_RADIUS: float = 48.0

# Port + RoomGate keep-clear regions (Uma brief §2; RoomGate (48,144) size
# (48,80) -> swept x[24,72] y[104,184], absorbed into the west-entry band).
const WEST_PORT_RECT := Rect2(0, 104, 112, 80)
const EAST_PORT_RECT := Rect2(896, 104, 64, 80)

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	_warn_guard.detach()
	_warn_guard = null


func _spawn_world_positions() -> Array[Vector2]:
	# Derive the keep-clear spawn anchors from the chunk-def (NOT hardcoded), per
	# Uma brief §6 "always read these from the resource, not memory".
	var c: LevelChunkDef = load(WIDE_CHUNK_DEF_PATH) as LevelChunkDef
	assert_not_null(c, "wide chunk def loads")
	var tile_px: float = float(c.tile_size_px)
	var out: Array[Vector2] = []
	for ms: MobSpawnPoint in c.mob_spawns:
		# Tile center: (tile + 0.5) * tile_px. The chunk-def comment + Uma brief
		# both cite px (336,112) etc. = tile*32 (tile-origin), so use tile-origin
		# to match the brief's traced anchors.
		out.append(Vector2(ms.position_tiles) * tile_px)
	return out


func _decoration_sprites(inst: Node) -> Array:
	var props: Node = inst.get_node_or_null("Props")
	assert_not_null(props, "wide chunk has a Props Node2D")
	var sprites: Array = []
	for child: Node in props.get_children():
		if child is Sprite2D:
			sprites.append(child)
	return sprites


func test_three_unused_props_are_activated() -> void:
	# The headline deliverable: brazier_cold / banner_worn / pillar_arch — placed
	# zero times pre-pass — now appear at least once each.
	var inst: Node = (load(WIDE_CHUNK_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	var seen: Dictionary = {}
	for s: Sprite2D in _decoration_sprites(inst):
		if s.texture != null:
			seen[s.texture.resource_path] = true
	for tex_path: String in ACTIVATED_PROP_TEXTURES:
		assert_true(
			seen.has(tex_path),
			"activated prop present in scene: %s" % tex_path
		)


func test_density_in_uma_target_band() -> void:
	# Uma brief §4: ~9 -> ~20-24 props for the 960x256 room. Pin a floor of 20
	# (the "reads furnished at 0.6 scale" threshold) and a ceiling of 26 (a
	# slightly-over-target edit is allowed; a runaway one is the regression).
	var inst: Node = (load(WIDE_CHUNK_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	var count: int = _decoration_sprites(inst).size()
	assert_between(count, 20, 26, "decoration prop count in Uma's 20-24 target band (got %d)" % count)


func test_no_decoration_in_central_lane() -> void:
	# KEEP-CLEAR regression guard #1: the swept processional aisle (y 112-176)
	# must stay ZERO-decoration so traversal + combat + the "clear aisle" read
	# all hold. A prop drifting into the lane fails here.
	var inst: Node = (load(WIDE_CHUNK_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	for s: Sprite2D in _decoration_sprites(inst):
		var p: Vector2 = s.position
		var in_lane_band: bool = (
			p.y > LANE_Y_MIN and p.y < LANE_Y_MAX
			and p.x > LANE_X_MIN and p.x < LANE_X_MAX
		)
		assert_false(
			in_lane_band,
			"%s at %s is in the central lane (y 112-176) — blocks the aisle" % [s.name, str(p)]
		)


func test_no_decoration_within_spawn_radius() -> void:
	# KEEP-CLEAR regression guard #2: nothing within ~48px of a grunt-spawn tile
	# (a prop on the spawn clips the mob or blocks its first step). Anchors read
	# from the chunk-def, not hardcoded.
	var inst: Node = (load(WIDE_CHUNK_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	var spawns: Array[Vector2] = _spawn_world_positions()
	for s: Sprite2D in _decoration_sprites(inst):
		for sp: Vector2 in spawns:
			assert_gt(
				s.position.distance_to(sp),
				SPAWN_CLEAR_RADIUS,
				"%s at %s is within %dpx of spawn %s" % [s.name, str(s.position), SPAWN_CLEAR_RADIUS, str(sp)]
			)


func test_no_decoration_in_port_or_gate_regions() -> void:
	# KEEP-CLEAR regression guard #3: west entry + RoomGate swept area, and the
	# east exit doorway, stay readable + walkable.
	var inst: Node = (load(WIDE_CHUNK_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	for s: Sprite2D in _decoration_sprites(inst):
		assert_false(
			WEST_PORT_RECT.has_point(s.position),
			"%s at %s sits in the west-entry / RoomGate region" % [s.name, str(s.position)]
		)
		assert_false(
			EAST_PORT_RECT.has_point(s.position),
			"%s at %s sits in the east-exit port region" % [s.name, str(s.position)]
		)


func test_decoration_pass_paints_grid_without_warnings() -> void:
	# Decoration is additive Sprite2D over the S1CloisterChunk painter — it must
	# not regress the painter's full-grid paint nor emit any WarningBus events.
	var inst: Node = (load(WIDE_CHUNK_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	var floor_tiles: TileMapLayer = inst.get_node_or_null("FloorTiles")
	assert_not_null(floor_tiles, "wide chunk still has a FloorTiles TileMapLayer")
	var used: Rect2i = floor_tiles.get_used_rect()
	assert_eq(used.size.x, 30, "painted floor still spans the full 30 tile columns")
	assert_eq(used.size.y, 8, "painted floor still spans the full 8 tile rows")
	_warn_guard.assert_clean(self)
