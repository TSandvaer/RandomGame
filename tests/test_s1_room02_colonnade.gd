# gdlint:disable=max-public-methods
# GUT test class — high test_* count IS the design (one test per scenario).
extends GutTest
## S1 tile-quality rework + lined-hall colonnade (ticket 86ca44p4j; Uma spec
## team/uma-ux/s1-tile-rework.md §2.3/§3/§4). Pins the Stage-C impl invariants
## the HTML5 visual gate cannot assert headlessly (the crafted-floor read +
## colonnade feel are the Sponsor-soak gate of record; these pin the mechanics):
##
##   1. FLOOR/WALL render as the FULL 128-px crafted image tiled (4-tile period)
##      — the S1CloisterChunk painter writes each cell from its 4×4 atlas-window
##      position, NOT cell (0,0) repeated (the PR #407 single-32px wallpaper bug).
##   2. COLONNADE composition: 8 pillars in 2 mirrored vertically-aligned rows
##      framing a CLEAR aisle; braziers + banners present.
##   3. COLLISION: pillars + braziers + large rubble are SOLID StaticBody2D on
##      layer 1 (world) with a base-footprint box smaller than the sprite;
##      small props (small rubble / parchment / moss / banner) are NOT solid.
##   4. NAVIGABILITY (HARD): aisle band y∈[112,176] clear of every solid box;
##      every grunt-spawn tile is clear of solid boxes; gaps between adjacent
##      columns ≥ 2 tiles (64 px); a 4-px-grid BFS confirms every spawn reaches
##      the player mid-aisle + the room is clearable entry→exit (no dead-pocket).
##   5. No USER WARNING during load/paint (WarningBus guard).
##
## Paired Playwright spec: tests/playwright/specs/s1-room02-colonnade.spec.ts.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

const CHUNK_SCENE_PATH: String = "res://scenes/levels/chunks/s1_room02_wide_chunk.tscn"
const CHUNK_DEF_PATH: String = "res://resources/level_chunks/s1_room02_wide.tres"
const PAINTER_SOURCE: String = "res://scripts/levels/S1CloisterChunk.gd"

const GRID_W: int = 30
const GRID_H: int = 8
const TILE: int = 32
const SOURCE_FLOOR: int = 0
const SOURCE_WALL: int = 1
const ATLAS_PERIOD: int = 4

# Layer convention (project.godot): world=bit1, player=bit2(layer 2), enemy=bit4.
# Solid props must be on the WORLD layer (bit 1) to block BOTH the player
# (mask=1) and the grunt (mask=3 = world+player).
const LAYER_WORLD: int = 1 << 0

# Grunt collision radius (CircleShape2D in Grunt.tscn) — used to model where the
# grunt CENTER can travel for the BFS navigability check.
const GRUNT_R: int = 12

# Aisle band (px) framed by the colonnade — must stay fully clear (Uma §3.1/§4.2).
const AISLE_LO: int = 112
const AISLE_HI: int = 176

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


## All StaticBody2D under the SolidProps node + their CollisionShape2D box AABBs
## in WORLD space, as [cx, cy, half_w, half_h]. Excludes the perimeter walls.
func _solid_prop_boxes(inst: Node) -> Array:
	var out: Array = []
	var solid: Node = inst.get_node_or_null("SolidProps")
	if solid == null:
		return out
	for child in solid.get_children():
		if not (child is StaticBody2D):
			continue
		var body: StaticBody2D = child
		var cs: CollisionShape2D = body.get_node_or_null("CollisionShape2D")
		if cs == null or not (cs.shape is RectangleShape2D):
			continue
		var rect: RectangleShape2D = cs.shape
		# Body position is the box center (CollisionShape2D at local origin).
		out.append(
			{
				"name": body.name,
				"cx": body.global_position.x + cs.position.x,
				"cy": body.global_position.y + cs.position.y,
				"hw": rect.size.x * 0.5,
				"hh": rect.size.y * 0.5,
				"layer": body.collision_layer
			}
		)
	return out


func _props_named_prefixed(inst: Node, prefix: String) -> Array:
	var out: Array = []
	var props: Node = inst.get_node_or_null("Props")
	if props == null:
		return out
	for child in props.get_children():
		if child is Sprite2D and String(child.name).begins_with(prefix):
			out.append(child)
	return out


# ---- 1. Floor/wall render as the full 128-px crafted image (4-tile period) ----


func test_painter_uses_4x4_atlas_window_not_single_cell() -> void:
	# The headline fix: the painter must paint each cell from its 4×4 source
	# window position (tx%4, ty%4), NOT cell (0,0) repeated. Source-scan pin —
	# the visible read is the Sponsor soak gate, this guards the code shape.
	var src: String = FileAccess.get_file_as_string(PAINTER_SOURCE)
	assert_gt(src.length(), 0, "painter source readable")
	assert_true(
		src.find("tx % ATLAS_PERIOD") > -1 and src.find("ty % ATLAS_PERIOD") > -1,
		"painter must paint from the 4×4 atlas window (tx%%4, ty%%4) — not a single repeated cell"
	)


func test_floor_interior_tiles_span_all_4x4_atlas_coords() -> void:
	# Behavioural proof of the fix: across the painted interior, the floor cells
	# must use MORE THAN ONE atlas coordinate — specifically the full 4×4 set —
	# so the crafted 128-px image renders, not one repeated 32-px sub-tile.
	var inst: Node = _instantiate_chunk()
	var floor_tiles: TileMapLayer = inst.get_node("FloorTiles")
	var seen: Dictionary = {}
	for ty in range(1, GRID_H - 1):
		for tx in range(1, GRID_W - 1):
			var cell: Vector2i = Vector2i(tx, ty)
			if floor_tiles.get_cell_source_id(cell) != SOURCE_FLOOR:
				continue
			var ac: Vector2i = floor_tiles.get_cell_atlas_coords(cell)
			seen[ac] = true
			# Each interior cell's atlas coord must equal its 4×4-window position.
			assert_eq(
				ac,
				Vector2i(tx % ATLAS_PERIOD, ty % ATLAS_PERIOD),
				"floor cell %s must paint from its 4×4 atlas-window position" % cell
			)
	assert_eq(
		seen.size(),
		ATLAS_PERIOD * ATLAS_PERIOD,
		"interior floor must use all 16 atlas cells (full crafted image), got %d" % seen.size()
	)


func test_floor_is_not_single_cell_wallpaper() -> void:
	# Direct regression guard on the PR #407 bug: the interior must NOT be a
	# single repeated atlas cell.
	var inst: Node = _instantiate_chunk()
	var floor_tiles: TileMapLayer = inst.get_node("FloorTiles")
	var distinct: Dictionary = {}
	for ty in range(1, GRID_H - 1):
		for tx in range(1, GRID_W - 1):
			if floor_tiles.get_cell_source_id(Vector2i(tx, ty)) == SOURCE_FLOOR:
				distinct[floor_tiles.get_cell_atlas_coords(Vector2i(tx, ty))] = true
	assert_gt(
		distinct.size(),
		1,
		"floor must use >1 atlas cell (PR #407 single-32px-tile wallpaper regression guard)"
	)


func test_wall_perimeter_uses_4x4_atlas_window() -> void:
	# The wall band gets the same 4×4-window treatment so the ashlar courses
	# stagger across the run (running-bond read) instead of one stamped block.
	var inst: Node = _instantiate_chunk()
	var floor_tiles: TileMapLayer = inst.get_node("FloorTiles")
	var seen: Dictionary = {}
	for tx in range(GRID_W):
		var cell: Vector2i = Vector2i(tx, 0)  # north wall run
		if floor_tiles.get_cell_source_id(cell) == SOURCE_WALL:
			seen[floor_tiles.get_cell_atlas_coords(cell)] = true
			assert_eq(
				floor_tiles.get_cell_atlas_coords(cell),
				Vector2i(tx % ATLAS_PERIOD, 0),
				"north wall cell %s paints from its 4×4 atlas-window column" % cell
			)
	assert_gt(
		seen.size(), 1, "north wall run must use >1 atlas column (staggered ashlar, not stamped)"
	)


func test_every_cell_painted() -> void:
	var inst: Node = _instantiate_chunk()
	var floor_tiles: TileMapLayer = inst.get_node("FloorTiles")
	var unpainted: int = 0
	for ty in range(GRID_H):
		for tx in range(GRID_W):
			if floor_tiles.get_cell_source_id(Vector2i(tx, ty)) == -1:
				unpainted += 1
	assert_eq(unpainted, 0, "all %d cells painted; %d unpainted" % [GRID_W * GRID_H, unpainted])


# ---- 2. Colonnade composition ----------------------------------------


func test_eight_pillars_in_two_mirrored_rows() -> void:
	var inst: Node = _instantiate_chunk()
	var pillars: Array = _props_named_prefixed(inst, "Pillar")
	assert_eq(pillars.size(), 8, "colonnade is 8 pillars (Uma §3.1)")
	var north_xs: Array = []
	var south_xs: Array = []
	for p: Sprite2D in pillars:
		if p.position.y < 144:
			north_xs.append(p.position.x)
		else:
			south_xs.append(p.position.x)
	assert_eq(north_xs.size(), 4, "4 pillars in the north row")
	assert_eq(south_xs.size(), 4, "4 pillars in the south row")
	north_xs.sort()
	south_xs.sort()
	assert_eq(
		north_xs,
		south_xs,
		"north + south pillar columns are vertically ALIGNED (the colonnade read)"
	)


func test_braziers_and_banners_present() -> void:
	var inst: Node = _instantiate_chunk()
	var lit: Array = _props_named_prefixed(inst, "BrazierLit")
	var cold: Array = _props_named_prefixed(inst, "BrazierCold")
	var banners: Array = _props_named_prefixed(inst, "Banner")
	assert_eq(lit.size(), 3, "3 lit braziers on the north wall (Uma §3.2)")
	assert_eq(cold.size(), 1, "1 cold brazier on the south wall (Uma §3.2)")
	assert_eq(banners.size(), 2, "2 banners over the central bays (Uma §3.3)")


func test_props_render_above_floor() -> void:
	var inst: Node = _instantiate_chunk()
	var props: Node2D = inst.get_node("Props")
	assert_eq(props.z_index, 1, "Props container z_index=+1 (above floor z=0, never negative)")


# ---- 3. Collision on solid props -------------------------------------


func test_solid_props_present_with_collision_on_world_layer() -> void:
	var inst: Node = _instantiate_chunk()
	var boxes: Array = _solid_prop_boxes(inst)
	# 8 pillars + 3 lit + 1 cold brazier + 2 large rubble = 14 solid props.
	assert_eq(
		boxes.size(), 14, "14 solid-prop StaticBody2D (8 pillars + 4 braziers + 2 large rubble)"
	)
	for b in boxes:
		assert_eq(
			int(b["layer"]) & LAYER_WORLD,
			LAYER_WORLD,
			(
				"%s collision_layer must include WORLD bit (blocks player mask=1 + grunt mask=3)"
				% b["name"]
			)
		)


func test_solid_prop_footprints_smaller_than_sprites() -> void:
	# Footprint discipline (Uma §4.1): collision box smaller than the sprite,
	# at the base. Pillar sprite is 48×64; box must be ≤ that. Braziers 32×48,
	# rubble 32×32.
	var inst: Node = _instantiate_chunk()
	var boxes: Array = _solid_prop_boxes(inst)
	for b in boxes:
		var w: float = b["hw"] * 2.0
		var h: float = b["hh"] * 2.0
		assert_lte(
			w,
			32.0,
			"%s footprint width %d ≤ sprite (smaller than silhouette)" % [b["name"], int(w)]
		)
		assert_lte(h, 32.0, "%s footprint height %d ≤ sprite" % [b["name"], int(h)])


func test_small_props_have_no_collision() -> void:
	# Small rubble / parchment / moss / banner are decoration only (Uma §4.1) —
	# they must NOT appear as solid bodies.
	var inst: Node = _instantiate_chunk()
	var boxes: Array = _solid_prop_boxes(inst)
	var solid_names: Array = []
	for b in boxes:
		solid_names.append(String(b["name"]))
	# No banner / parchment / moss body.
	for forbidden in ["Banner", "Parchment", "Moss"]:
		for n in solid_names:
			assert_false(
				n.begins_with(forbidden),
				"%s is decoration and must NOT be a solid body (got %s)" % [forbidden, n]
			)


# ---- 4. Navigability (HARD) ------------------------------------------


func _blocked(px: float, py: float, boxes: Array) -> bool:
	# Interior walkable bounds for the grunt CENTER (walls 1 tile thick).
	if px < TILE + GRUNT_R or px > GRID_W * TILE - TILE - GRUNT_R:
		return true
	if py < TILE + GRUNT_R or py > GRID_H * TILE - TILE - GRUNT_R:
		return true
	for b in boxes:
		if absf(px - b["cx"]) <= b["hw"] + GRUNT_R and absf(py - b["cy"]) <= b["hh"] + GRUNT_R:
			return true
	return false


func test_aisle_band_clear_of_all_solid_boxes() -> void:
	# The central aisle (y∈[112,176]) is the clear processional walk + combat
	# arena (Uma §3.1/§4.2). No solid box (expanded by the grunt radius) may
	# intrude it.
	var inst: Node = _instantiate_chunk()
	var boxes: Array = _solid_prop_boxes(inst)
	for b in boxes:
		var top: float = b["cy"] - b["hh"] - GRUNT_R
		var bot: float = b["cy"] + b["hh"] + GRUNT_R
		var intrudes: bool = bot > AISLE_LO and top < AISLE_HI
		assert_false(
			intrudes,
			(
				"%s solid box intrudes the clear aisle band [%d,%d] (y-extent [%d,%d])"
				% [b["name"], AISLE_LO, AISLE_HI, int(top), int(bot)]
			)
		)


func test_every_grunt_spawn_clear_of_solid_boxes() -> void:
	# A pillar/brazier/rubble box must never sit on a spawn tile (Uma §4.2).
	var inst: Node = _instantiate_chunk()
	var boxes: Array = _solid_prop_boxes(inst)
	var chunk_def: LevelChunkDef = load(CHUNK_DEF_PATH) as LevelChunkDef
	assert_not_null(chunk_def, "chunk def loads")
	for ms: MobSpawnPoint in chunk_def.mob_spawns:
		var sx: float = ms.position_tiles.x * TILE + TILE * 0.5
		var sy: float = ms.position_tiles.y * TILE + TILE * 0.5
		assert_false(
			_blocked(sx, sy, boxes),
			(
				"grunt spawn tile %s (px %d,%d) must be clear of solid boxes"
				% [str(ms.position_tiles), int(sx), int(sy)]
			)
		)


func test_adjacent_column_gaps_are_at_least_two_tiles() -> void:
	# Gaps between adjacent paired columns ≥ 2 tiles (64 px) so the colonnade is
	# permeable (Uma §4.2).
	var inst: Node = _instantiate_chunk()
	var pillars: Array = _props_named_prefixed(inst, "Pillar")
	var north_xs: Array = []
	for p: Sprite2D in pillars:
		if p.position.y < 144:
			north_xs.append(p.position.x)
	north_xs.sort()
	# Pillar collision half-width (24-px box ⇒ 12 px half).
	const HALF: float = 12.0
	for i in range(north_xs.size() - 1):
		var gap: float = (north_xs[i + 1] - HALF) - (north_xs[i] + HALF)
		assert_gte(
			gap,
			64.0,
			(
				"gap between columns x%d..x%d ≥ 2 tiles, got %d px"
				% [int(north_xs[i]), int(north_xs[i + 1]), int(gap)]
			)
		)


func test_room_clearable_and_every_spawn_reaches_player() -> void:
	# HARD AC: BFS on a 4-px grid (modelling the grunt's direct-steering +
	# move_and_slide pathing — Grunt has NO NavigationAgent). Confirms (a) the
	# room is clearable entry→exit, and (b) every grunt spawn can reach the
	# player at mid-aisle around the colonnade — no nav dead-pocket.
	var inst: Node = _instantiate_chunk()
	var boxes: Array = _solid_prop_boxes(inst)
	var chunk_def: LevelChunkDef = load(CHUNK_DEF_PATH) as LevelChunkDef

	# (a) Clearable: entry (40,144) reaches exit (912,144).
	var from_entry: Dictionary = _bfs(Vector2(40, 144), boxes)
	assert_true(
		_set_has_point(from_entry, Vector2(912, 144), 12),
		"room must be clearable: ENTRY(40,144) reaches EXIT(912,144)"
	)

	# (b) Each spawn reaches the player at mid-aisle (480,144).
	for ms: MobSpawnPoint in chunk_def.mob_spawns:
		var sx: float = ms.position_tiles.x * TILE + TILE * 0.5
		var sy: float = ms.position_tiles.y * TILE + TILE * 0.5
		var reach: Dictionary = _bfs(Vector2(sx, sy), boxes)
		assert_true(
			_set_has_point(reach, Vector2(480, 144), 12),
			(
				"grunt spawn %s must reach the player at mid-aisle (480,144) — no dead-pocket"
				% str(ms.position_tiles)
			)
		)


func _bfs(start: Vector2, boxes: Array) -> Dictionary:
	const STEP: int = 4
	var seen: Dictionary = {}
	var q: Array = []
	var s: Vector2i = Vector2i(int(start.x) / STEP * STEP, int(start.y) / STEP * STEP)
	seen[s] = true
	q.append(s)
	var head: int = 0
	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1
		for d: Vector2i in [
			Vector2i(STEP, 0), Vector2i(-STEP, 0), Vector2i(0, STEP), Vector2i(0, -STEP)
		]:
			var nxt: Vector2i = cur + d
			if seen.has(nxt):
				continue
			if _blocked(nxt.x, nxt.y, boxes):
				continue
			seen[nxt] = true
			q.append(nxt)
	return seen


func _set_has_point(seen: Dictionary, target: Vector2, tol: int) -> bool:
	for k in seen.keys():
		var p: Vector2i = k
		if absf(p.x - target.x) <= tol and absf(p.y - target.y) <= tol:
			return true
	return false


# ---- 5. Perimeter walls unchanged (BB-3 invariant) -------------------


func test_perimeter_walls_unchanged() -> void:
	var inst: Node = _instantiate_chunk()
	for wall_name: String in ["WallNorth", "WallSouth", "WallWest", "WallEast"]:
		var wall: Node = inst.get_node_or_null(wall_name)
		assert_not_null(wall, "%s perimeter wall present" % wall_name)
		assert_true(wall is StaticBody2D, "%s is StaticBody2D" % wall_name)
		var cs: Node = wall.get_node_or_null("CollisionShape2D")
		assert_not_null(cs, "%s keeps its CollisionShape2D" % wall_name)


# ---- 6. Warning gate -------------------------------------------------


func test_no_user_warning_on_load_and_paint() -> void:
	var inst: Node = _instantiate_chunk()
	await get_tree().process_frame
	var floor_tiles: TileMapLayer = inst.get_node_or_null("FloorTiles")
	assert_not_null(floor_tiles, "FloorTiles painted")
	# WarningBus assertion runs in after_each via _warn_guard.assert_clean.
