class_name FloorAssembler
extends RefCounted
## Per-character procedural floor assembly — composes a single `ZoneDef`
## into an ordered placement of anchor + procedural-fill chunks
## (`AssembledFloor`) deterministic in `(zone_def, seed)`.
##
## M3 Tier 3 W1 procgen spike Part A (ticket `86c9xub9p`). Sibling spikes:
## zone-schema (data shape this consumes — ticket `86c9xuap4`, MERGED) +
## camera-scroll (downstream consumer of `AssembledFloor.bounding_box_px`
## via `CameraDirector.set_world_bounds(...)` — ticket `86c9xu9yt`,
## MERGED PR #314).
##
## ## Seed-derivation contract
##
## The Diablo-shape directive (`m3-diablo-shape-directive.md`) is
## "each character has a `world_seed` rolled on creation; map layout is
## deterministic per character." Same character + same zone → same map;
## different characters → meaningfully different maps.
##
## The seed cascade is two layers:
##
##   stratum_seed = hash(world_seed, stratum_id)
##   zone_seed    = hash(stratum_seed, zone_id)
##
## `FloorAssembler.assemble_floor(zone_def, seed)` accepts the
## zone-level seed directly (caller derived it). Two helper statics
## (`derive_stratum_seed` + `derive_zone_seed`) let callers chain
## cleanly:
##
##   var zone_seed: int = FloorAssembler.derive_zone_seed(
##       character.world_seed, zone_def.stratum_id, zone_def.zone_id)
##   var floor: AssembledFloor = FloorAssembler.new().assemble_floor(
##       zone_def, zone_seed)
##
## **Why two layers, not one big hash:** the stratum_seed layer is the
## anchor for cross-zone consistency (e.g. all S1 zones share an entropy
## space that's disjoint from S2's, even if a zone_id happened to
## collide). The per-zone derivation pins re-entries to the same layout
## within a run — the assembler is pure given (zone_def, seed), so
## re-calling with the same inputs is the natural same-layout
## verification.
##
## ## Procedural fill semantics
##
## Per `ZoneDef`:
##   - `anchors` are placed in array order along the floor graph.
##   - Between each consecutive anchor pair, `randi_range(
##     zone_def.min_slots_between_anchors,
##     zone_def.max_slots_between_anchors)` chunks are drawn from
##     `zone_def.procedural_slot_pool` using a seeded RNG.
##
## The slot-count and per-slot pick are BOTH seeded from the same RNG
## (one `RandomNumberGenerator` per assemble call), so the call sequence
## is deterministic. Test pin: same seed → same placement vector.
##
## **Worked example** — `s1_z1_outer_cloister.tres` (5 anchors + 4 gaps,
## [1, 3] slots/gap, pool size 4):
##   - Procedural count per assembly: 4 to 12 (range 4 × 3 = 12 upper bound).
##   - Total chunks per assembly: 9 to 17.
##   - Per-seed variance is meaningful: two seeds produce different
##     slot counts AND different chunk selections AND different orderings.
##
## ## Port-mating contract (R-PROCGEN.b mitigation)
##
## Per `level-chunks.md` § "Why ports, not free-form transitions":
## adjacent chunks must have compatible ports on their shared edge.
##
## The assembler enforces this via `_check_port_mating(left, right)`:
##   - `left` chunk must declare a port with `direction = EAST` (=1)
##     and a `tag` in the open-port set (`&"entry"`, `&"exit"`,
##     `&"boss_door"`). The chunk's `&"locked"` tag is NEVER an open port.
##   - `right` chunk must declare a port with `direction = WEST` (=3)
##     and a compatible `tag`.
##   - Both ports' `position_tiles.y` must match (they sit on the same
##     row of the shared seam).
##
## Mating failures are RECORDED (in `AssembledFloor.port_mating_errors`),
## not raised — the assembler still returns a complete placement so the
## visual proof scene can show the regression. R-PROCGEN.b mitigation is
## the test in this PR's GUT suite that asserts a clean S1 zone assemble
## produces zero mating errors.
##
## ## Out of scope for THIS spike (Part A)
##
##   - `Character.world_seed` save schema field (Devon Part B).
##   - `ProcgenSpikeScene.tscn` visual proof scene (Devon Part C).
##   - HTML5 visual-verification gate (Devon Part C+D).
##   - SI-8 recommendation in PR body (Devon Part D).
##   - S1 retrofit to procedural assembly (W2 ticket).
##   - Cross-zone exit→entry mating (`target_zone_id` resolution) — only
##     in-zone seams are mated by this assembler. Cross-zone routing is
##     a stratum-flow concern handled at the Main.gd / room-driver
##     layer.
##   - Mob-spawn variance per character within chunks (M4-class).
##   - Loot-pickup variance per character within chunks (M4-class).


## Open-port tag set — port tags the assembler treats as a valid
## connection point. Adjacent chunks' ports must BOTH have tags in this
## set (per-tag pair compatibility is symmetric — see `_check_port_mating`).
##
## `&"locked"` is intentionally excluded: per `ChunkPort.gd` doc, a
## locked port forbids assembler neighbour placement.
const OPEN_PORT_TAGS: Array[StringName] = [
	&"entry",
	&"exit",
	&"boss_door",
]


## Default chunk root for loading `LevelChunkDef.tres` by chunk_id. Tests
## may override via `assemble_floor`'s `chunks_by_id` override to inject
## fixture chunks (avoiding disk I/O + isolating from production content).
const DEFAULT_CHUNK_ROOT: String = "res://resources/level_chunks/"


# -----------------------------------------------------------------------
# Public API
# -----------------------------------------------------------------------


## Assemble a floor from a zone definition + a per-zone seed.
##
## Returns an `AssembledFloor` carrying the placement, total bounds, and
## any port-mating violations.  Empty `placed_chunks` (i.e.
## `result.is_empty()`) signals the assembler bailed before placing any
## chunk (invalid zone_def, unresolvable anchors). Non-empty
## `port_mating_errors` signals R-PROCGEN.b regression (some adjacent
## pair did not mate cleanly); downstream code decides whether to render.
##
## `chunks_by_id` override (optional) maps `chunk_id` -> `LevelChunkDef`.
## When null, the assembler resolves chunk ids via `load()` against
## `DEFAULT_CHUNK_ROOT`. Tests inject this to isolate from production
## chunk content + avoid load() overhead in pure-determinism tests.
func assemble_floor(
	zone_def: ZoneDef,
	seed: int,
	chunks_by_id: Dictionary = {}
) -> AssembledFloor:
	if zone_def == null:
		push_error("FloorAssembler.assemble_floor: zone_def is null")
		return AssembledFloor.new()

	var validate_errors: Array[String] = zone_def.validate()
	if not validate_errors.is_empty():
		push_error(
			"FloorAssembler.assemble_floor: zone_def invalid: %s"
			% str(validate_errors)
		)
		return AssembledFloor.new()

	var result: AssembledFloor = AssembledFloor.new()
	result.zone_id = zone_def.zone_id
	result.seed = seed

	# Resolve all chunk ids the zone references (anchors + pool) up front.
	# Failing to resolve aborts the assemble — broken content is louder
	# than a silently-shrunken floor.
	var needed_ids: Array[StringName] = []
	for a: ZoneAnchor in zone_def.anchors:
		if not needed_ids.has(a.chunk_id):
			needed_ids.append(a.chunk_id)
	for id_in_pool: StringName in zone_def.procedural_slot_pool:
		if not needed_ids.has(id_in_pool):
			needed_ids.append(id_in_pool)

	var resolved: Dictionary = _resolve_chunks(needed_ids, chunks_by_id)
	for cid: StringName in needed_ids:
		if not resolved.has(cid):
			push_error(
				"FloorAssembler.assemble_floor: failed to resolve chunk_id %s"
				% str(cid)
			)
			return AssembledFloor.new()

	# Seeded RNG drives BOTH slot-counts and chunk picks. Single RNG
	# instance per assemble call so the call sequence is deterministic.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed

	# Walk the anchors + interleave procedural fills between consecutive
	# anchors. Anchor at index i+1 is placed AFTER the procedural slots
	# that follow anchor i.
	var placements: Array[PlacedChunk] = []
	var anchor_count: int = zone_def.anchors.size()
	for i: int in range(anchor_count):
		var anchor: ZoneAnchor = zone_def.anchors[i]
		var anchor_chunk: LevelChunkDef = resolved[anchor.chunk_id]
		placements.append(_place_anchor(anchor, anchor_chunk))

		# Interleave procedural fill between anchor[i] and anchor[i+1]
		# (no fill after the final anchor).
		if i < anchor_count - 1:
			var slot_count: int = rng.randi_range(
				zone_def.min_slots_between_anchors,
				zone_def.max_slots_between_anchors
			)
			for s: int in range(slot_count):
				var pool: Array[StringName] = zone_def.procedural_slot_pool
				var pick_idx: int = rng.randi_range(0, pool.size() - 1)
				var picked_id: StringName = pool[pick_idx]
				var picked_chunk: LevelChunkDef = resolved[picked_id]
				placements.append(_place_procedural(picked_id, picked_chunk))

	# Lay out placements along the +X axis (east-bound), mating each
	# chunk's left edge to the previous chunk's right edge. Per-chunk Y
	# is 0 (single-row floor for the spike — S2+ multi-row layouts are a
	# W3+ widening).
	var cursor_x: float = 0.0
	for pc: PlacedChunk in placements:
		pc.position_px = Vector2(cursor_x, 0.0)
		cursor_x += float(pc.size_px.x)
	result.placed_chunks = placements

	# Compute total bounding box. Union of every placed chunk's local
	# rect, expressed in floor-local world pixels.
	result.bounding_box_px = _compute_bounds(placements)

	# Port-mating sweep — record violations but continue.
	result.port_mating_errors = _sweep_port_mating(placements, resolved)

	return result


# -----------------------------------------------------------------------
# Static helpers — seed derivation (Diablo-shape per-character seed cascade)
# -----------------------------------------------------------------------


## Derive a stratum-level seed from a per-character world_seed +
## stratum_id. Hash combines via Godot's built-in `hash()` against a
## tuple-like Array — symmetric across runs + cheap.
static func derive_stratum_seed(world_seed: int, stratum_id: int) -> int:
	return hash([world_seed, stratum_id])


## Derive a zone-level seed from a stratum_seed + zone_id. Same shape as
## `derive_stratum_seed` — Array-tuple into `hash()`.
##
## Callers typically chain:
##   var stratum_seed = FloorAssembler.derive_stratum_seed(world_seed, stratum_id)
##   var zone_seed    = FloorAssembler.derive_zone_seed(stratum_seed, zone_id)
##   var floor        = FloorAssembler.new().assemble_floor(zone_def, zone_seed)
static func derive_zone_seed(stratum_seed: int, zone_id: StringName) -> int:
	return hash([stratum_seed, String(zone_id)])


# -----------------------------------------------------------------------
# Internals
# -----------------------------------------------------------------------


## Resolve a list of chunk_ids to LevelChunkDef Resources. Tests pass
## `override` to inject fixture chunks; production resolves via `load()`
## against `DEFAULT_CHUNK_ROOT`.
##
## Returns a Dictionary mapping resolved ids -> LevelChunkDef. Unresolved
## ids are simply absent; the caller treats a missing key as failure.
func _resolve_chunks(
	needed_ids: Array[StringName],
	override: Dictionary
) -> Dictionary:
	var out: Dictionary = {}
	for cid: StringName in needed_ids:
		if override.has(cid):
			var v: Variant = override[cid]
			if v is LevelChunkDef:
				out[cid] = v
				continue
			# Type mismatch in override — log and fall through to load().
			push_warning(
				"FloorAssembler._resolve_chunks: override entry %s is not LevelChunkDef"
				% str(cid)
			)
		var path: String = "%s%s.tres" % [DEFAULT_CHUNK_ROOT, String(cid)]
		var res: Resource = load(path)
		if res is LevelChunkDef:
			out[cid] = res
	return out


## Build a `PlacedChunk` for an anchor placement. Position is filled in
## by the layout sweep — this just stamps the chunk_id + kind + size +
## anchor_room_id.
func _place_anchor(
	anchor: ZoneAnchor,
	chunk: LevelChunkDef
) -> PlacedChunk:
	var pc: PlacedChunk = PlacedChunk.new()
	pc.chunk_id = chunk.id
	pc.size_px = chunk.size_px()
	pc.kind = &"anchor"
	pc.anchor_room_id = anchor.room_id
	# pc.position_px set during layout sweep.
	return pc


## Build a `PlacedChunk` for a procedural placement.
func _place_procedural(
	chunk_id: StringName,
	chunk: LevelChunkDef
) -> PlacedChunk:
	var pc: PlacedChunk = PlacedChunk.new()
	pc.chunk_id = chunk.id
	pc.size_px = chunk.size_px()
	pc.kind = &"procedural"
	# anchor_room_id stays empty for procedural placements.
	# position_px set during layout sweep.
	return pc


## Compute the floor-local bounding box from a placement list.
func _compute_bounds(placements: Array[PlacedChunk]) -> Rect2:
	if placements.is_empty():
		return Rect2()
	var min_x: float = INF
	var min_y: float = INF
	var max_x: float = -INF
	var max_y: float = -INF
	for pc: PlacedChunk in placements:
		min_x = min(min_x, pc.position_px.x)
		min_y = min(min_y, pc.position_px.y)
		max_x = max(max_x, pc.position_px.x + float(pc.size_px.x))
		max_y = max(max_y, pc.position_px.y + float(pc.size_px.y))
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


## Sweep every adjacent (left, right) pair in the placement list, check
## port compatibility, and accumulate violation strings.
func _sweep_port_mating(
	placements: Array[PlacedChunk],
	resolved: Dictionary
) -> Array[String]:
	var errors: Array[String] = []
	if placements.size() < 2:
		return errors
	for i: int in range(placements.size() - 1):
		var left_pc: PlacedChunk = placements[i]
		var right_pc: PlacedChunk = placements[i + 1]
		var left_chunk: LevelChunkDef = resolved[left_pc.chunk_id]
		var right_chunk: LevelChunkDef = resolved[right_pc.chunk_id]
		var pair_err: String = _check_port_mating(left_chunk, right_chunk)
		if pair_err != "":
			# ASCII-only separator (`<->` not `↔`) — Godot 4.3 HTML5
			# default-font lacks U+2194 glyph coverage, so non-ASCII
			# renders as a tofu box in any UI surface that displays this
			# string. See `.claude/docs/html5-export.md` § "Default-font
			# glyph coverage". The ProcgenSpike scene surfaces this
			# string in its amber-error HUD label — empirically caught
			# during the M3 Tier 3 W1 author-self-soak (commit ff67d0c).
			errors.append(
				"chunks[%d]=%s <-> chunks[%d]=%s: %s"
				% [i, str(left_pc.chunk_id), i + 1, str(right_pc.chunk_id), pair_err]
			)
	return errors


## Check a single adjacent (left, right) pair. Returns empty string iff
## the pair mates cleanly; otherwise returns a human-readable error
## describing the violation.
##
## Contract per § "Port-mating contract":
##   - Left chunk has ≥1 port with direction=EAST and tag in OPEN_PORT_TAGS.
##   - Right chunk has ≥1 port with direction=WEST and tag in OPEN_PORT_TAGS.
##   - Some EAST port on left + some WEST port on right share
##     `position_tiles.y` (same seam row).
func _check_port_mating(left: LevelChunkDef, right: LevelChunkDef) -> String:
	var left_east: Array[ChunkPort] = _open_ports_on_edge(left, ChunkPort.Direction.EAST)
	if left_east.is_empty():
		return "left chunk has no open EAST port"
	var right_west: Array[ChunkPort] = _open_ports_on_edge(right, ChunkPort.Direction.WEST)
	if right_west.is_empty():
		return "right chunk has no open WEST port"
	# Find at least one (left-east, right-west) pair sharing seam row.
	for le: ChunkPort in left_east:
		for rw: ChunkPort in right_west:
			if le.position_tiles.y == rw.position_tiles.y:
				return ""
	return (
		"no shared seam row between left EAST port(s) and right WEST port(s)"
	)


## Return ports on the given chunk whose `direction == edge` AND whose
## `tag` is in `OPEN_PORT_TAGS`.
func _open_ports_on_edge(chunk: LevelChunkDef, edge: int) -> Array[ChunkPort]:
	var out: Array[ChunkPort] = []
	for p: ChunkPort in chunk.ports:
		if int(p.direction) != edge:
			continue
		if not OPEN_PORT_TAGS.has(p.tag):
			continue
		out.append(p)
	return out
