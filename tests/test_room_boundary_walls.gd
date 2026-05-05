extends GutTest
## Boundary-wall invariants for stratum-1 room scenes. BB-3 fix
## (`86c9m393a` — Tess run-024 bug-bash): the player must not be able to
## walk off the visual room edge into the void. Each room scene must carry
## perimeter StaticBody2D walls covering all four edges so the player's
## CharacterBody2D collides before leaving the room rect.
##
## Coverage:
##   - `scenes/levels/chunks/s1_room01_chunk.tscn` — used by Rooms 01..08.
##   - `scenes/levels/Stratum1BossRoom.tscn` — boss arena.
##
## Why "shape coverage" not just "wall count": authors could rename a wall
## to satisfy a count assertion while leaving an edge open. We project each
## StaticBody2D's collision rect onto the room's bounding box and assert
## that every edge has at least one wall covering >= 90% of its length —
## that catches "missing east wall" without over-pinning the wall mesh.

# Room scenes under audit. Both must carry full perimeter walls per BB-3.
# Boss room is 480x270 (Uma full-canvas arena); chunk is 480x256 (15x8 tiles
# at 32 px each). Rooms 02..08 instance the same chunk so fixing it once
# fixes the void-walk bug for all 8 normal rooms.
const CHUNK_SCENE_PATH: String = "res://scenes/levels/chunks/s1_room01_chunk.tscn"
const BOSS_SCENE_PATH: String = "res://scenes/levels/Stratum1BossRoom.tscn"

# Coverage threshold per edge — tolerates a small doorway / decorative gap
# while still catching a flat-out missing wall.
const EDGE_COVERAGE_RATIO: float = 0.9


# ---- Helpers ---------------------------------------------------------

# Returns the world-space Rect2 of a CollisionShape2D's RectangleShape2D
# under its parent StaticBody2D, accounting for the body's position.
# Returns Rect2() if the shape isn't a RectangleShape2D (other shapes are
# not used by our boundary walls and would be a bug if added without
# updating this helper).
func _wall_world_rect(body: StaticBody2D) -> Rect2:
	for child in body.get_children():
		if not (child is CollisionShape2D):
			continue
		var cs: CollisionShape2D = child
		if not (cs.shape is RectangleShape2D):
			continue
		var rect_shape: RectangleShape2D = cs.shape
		var size: Vector2 = rect_shape.size
		var center: Vector2 = body.position + cs.position
		return Rect2(center - size * 0.5, size)
	return Rect2()


# Given a list of StaticBody2D walls and the room bounds, returns the
# total length of `bounds` edge `edge_name` covered by walls touching that
# edge. Each wall is projected to the relevant axis and overlaps merged.
func _edge_coverage_px(walls: Array, bounds: Rect2, edge: StringName) -> float:
	# Range [a, b] is the 1D axis interval of `bounds` along the edge:
	#   north / south → x axis (bounds.position.x .. bounds.end.x)
	#   east  / west  → y axis (bounds.position.y .. bounds.end.y)
	var axis_min: float = 0.0
	var axis_max: float = 0.0
	match edge:
		&"north", &"south":
			axis_min = bounds.position.x
			axis_max = bounds.position.x + bounds.size.x
		&"east", &"west":
			axis_min = bounds.position.y
			axis_max = bounds.position.y + bounds.size.y
		_:
			return 0.0

	# Tolerance for "wall touches edge" — within 4 px of the edge line.
	const TOUCH_EPS: float = 4.0
	var intervals: Array[Vector2] = []
	for w_any in walls:
		var w: StaticBody2D = w_any
		var r: Rect2 = _wall_world_rect(w)
		if r.size == Vector2.ZERO:
			continue
		var on_edge: bool = false
		match edge:
			&"north":
				on_edge = absf(r.position.y - bounds.position.y) <= TOUCH_EPS
			&"south":
				on_edge = absf((r.position.y + r.size.y) - (bounds.position.y + bounds.size.y)) <= TOUCH_EPS
			&"west":
				on_edge = absf(r.position.x - bounds.position.x) <= TOUCH_EPS
			&"east":
				on_edge = absf((r.position.x + r.size.x) - (bounds.position.x + bounds.size.x)) <= TOUCH_EPS
		if not on_edge:
			continue
		var a: float = 0.0
		var b: float = 0.0
		match edge:
			&"north", &"south":
				a = r.position.x
				b = r.position.x + r.size.x
			&"east", &"west":
				a = r.position.y
				b = r.position.y + r.size.y
		# Clamp to the edge's axis range.
		a = clampf(a, axis_min, axis_max)
		b = clampf(b, axis_min, axis_max)
		if b > a:
			intervals.append(Vector2(a, b))

	# Merge intervals + sum lengths.
	if intervals.is_empty():
		return 0.0
	intervals.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var merged: Array[Vector2] = []
	merged.append(intervals[0])
	for i in range(1, intervals.size()):
		var top: Vector2 = merged[merged.size() - 1]
		var cur: Vector2 = intervals[i]
		if cur.x <= top.y:
			# Overlap — extend the top.
			merged[merged.size() - 1] = Vector2(top.x, maxf(top.y, cur.y))
		else:
			merged.append(cur)
	var total: float = 0.0
	for iv in merged:
		total += iv.y - iv.x
	return total


# Collect every StaticBody2D in the scene's tree.
func _collect_walls(root: Node) -> Array:
	var out: Array = []
	if root is StaticBody2D:
		out.append(root)
	for child in root.get_children():
		out.append_array(_collect_walls(child))
	return out


func _instantiate(scene_path: String) -> Node:
	var packed: PackedScene = load(scene_path)
	assert_not_null(packed, "scene must load: %s" % scene_path)
	var inst: Node = packed.instantiate()
	add_child_autofree(inst)
	return inst


# ---- 1. Chunk scene (Rooms 01..08) ---------------------------------

func test_chunk_scene_has_static_body_walls() -> void:
	var inst: Node = _instantiate(CHUNK_SCENE_PATH)
	var walls: Array = _collect_walls(inst)
	# At least four perimeter walls — N/S/E/W. Authors are free to add more
	# (e.g. interior pillars in M2) so we assert a floor, not exact equality.
	assert_gte(walls.size(), 4,
		"chunk scene must carry >=4 StaticBody2D walls (N/S/E/W); got %d" % walls.size())


func test_chunk_scene_covers_all_four_edges() -> void:
	# Chunk is 15x8 tiles at 32 px = 480x256.
	var inst: Node = _instantiate(CHUNK_SCENE_PATH)
	var walls: Array = _collect_walls(inst)
	var bounds: Rect2 = Rect2(0, 0, 480, 256)
	for edge: StringName in [&"north", &"south", &"east", &"west"]:
		var axis_len: float = bounds.size.x if (edge == &"north" or edge == &"south") else bounds.size.y
		var covered: float = _edge_coverage_px(walls, bounds, edge)
		var ratio: float = covered / axis_len
		assert_gte(ratio, EDGE_COVERAGE_RATIO,
			"chunk %s edge coverage %.2f < %.2f (covered %.0f / %.0f px)" %
				[String(edge), ratio, EDGE_COVERAGE_RATIO, covered, axis_len])


# ---- 2. Boss arena ------------------------------------------------

func test_boss_room_has_static_body_walls() -> void:
	var inst: Node = _instantiate(BOSS_SCENE_PATH)
	var walls: Array = _collect_walls(inst)
	# Boss room script also spawns Area2D triggers (door + StratumExit) — those
	# are NOT StaticBody2D so they don't enter `walls`. We only count the four
	# perimeter walls authored in the .tscn.
	assert_gte(walls.size(), 4,
		"boss room scene must carry >=4 StaticBody2D walls (N/S/E/W); got %d" % walls.size())


func test_boss_room_covers_all_four_edges() -> void:
	# Boss arena is the full 480x270 canvas (ArenaFloor offset_bottom=270).
	var inst: Node = _instantiate(BOSS_SCENE_PATH)
	var walls: Array = _collect_walls(inst)
	var bounds: Rect2 = Rect2(0, 0, 480, 270)
	for edge: StringName in [&"north", &"south", &"east", &"west"]:
		var axis_len: float = bounds.size.x if (edge == &"north" or edge == &"south") else bounds.size.y
		var covered: float = _edge_coverage_px(walls, bounds, edge)
		var ratio: float = covered / axis_len
		assert_gte(ratio, EDGE_COVERAGE_RATIO,
			"boss room %s edge coverage %.2f < %.2f (covered %.0f / %.0f px)" %
				[String(edge), ratio, EDGE_COVERAGE_RATIO, covered, axis_len])


# ---- 3. Door trigger preserved (BB-3 invariant) -------------------

func test_boss_room_door_trigger_still_reachable() -> void:
	# Walls must not occlude the boss-room door trigger. The trigger is at
	# (240, 250) size (80, 16) — i.e. world rect (200..280, 242..258). The
	# player approaches from the north (spawn at 240, 200) and walks south.
	# The south wall must start AT OR SOUTH OF y=258 so the player can reach
	# the trigger before being stopped.
	var inst: Node = _instantiate(BOSS_SCENE_PATH)
	var walls: Array = _collect_walls(inst)
	# Find the south wall (touches the south edge y=270).
	var south_wall_top: float = INF
	for w_any in walls:
		var w: StaticBody2D = w_any
		var r: Rect2 = _wall_world_rect(w)
		if r.size == Vector2.ZERO:
			continue
		# South wall: bottom edge at y=270 (within 4 px) AND horizontally
		# oriented (width > height). The east/west perimeter walls are
		# 32x270 verticals — their bottom edge ALSO touches y=270, so we
		# additionally require `size.x > size.y` to exclude them. Without
		# this filter `WallEast` / `WallWest` (position.y=0) would drag
		# `south_wall_top` to 0 and false-positive the door-trigger
		# occlusion assertion.
		var is_horizontal: bool = r.size.x > r.size.y
		if is_horizontal and absf((r.position.y + r.size.y) - 270.0) <= 4.0:
			south_wall_top = minf(south_wall_top, r.position.y)
	assert_lt(south_wall_top, 270.0, "south wall present")
	# Trigger's south edge is y=258 — wall must start at or below that so the
	# player can walk into the trigger.
	assert_gte(south_wall_top, 258.0,
		"south wall starts at y=%.1f — must be >= 258 to leave the door trigger reachable"
			% south_wall_top)


# ---- 4. Room scene smoke (each scene loads with walls present) ----

func test_each_stratum1_room_scene_has_walls_at_runtime() -> void:
	# Rooms 01..08 instantiate via LevelAssembler which (post-BB-3 fix) loads
	# the chunk's `scene_path` and parents it under the room root. After
	# `_ready` the room's tree must surface the chunk's perimeter walls so
	# the player physically collides with them at play time. Without this
	# wiring the chunk geometry is "authored" but never reaches the running
	# scene tree — the original BB-3 symptom.
	var room_paths: Array[String] = [
		"res://scenes/levels/Stratum1Room01.tscn",
		"res://scenes/levels/Stratum1Room02.tscn",
		"res://scenes/levels/Stratum1Room08.tscn",
	]
	for p: String in room_paths:
		var inst: Node = _instantiate(p)
		var walls: Array = _collect_walls(inst)
		assert_gte(walls.size(), 4,
			"%s must surface >=4 boundary StaticBody2D walls at runtime; got %d"
				% [p, walls.size()])
		var bounds: Rect2 = Rect2(0, 0, 480, 256)
		for edge: StringName in [&"north", &"south", &"east", &"west"]:
			var axis_len: float = bounds.size.x if (edge == &"north" or edge == &"south") else bounds.size.y
			var covered: float = _edge_coverage_px(walls, bounds, edge)
			var ratio: float = covered / axis_len
			assert_gte(ratio, EDGE_COVERAGE_RATIO,
				"%s %s edge runtime coverage %.2f < %.2f"
					% [p, String(edge), ratio, EDGE_COVERAGE_RATIO])
