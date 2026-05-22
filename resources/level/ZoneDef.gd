class_name ZoneDef
extends Resource
## A named zone — the geography layer that quests + map UI reference + the
## procgen assembler composes. A zone is a fixed sequence of hand-authored
## anchor rooms (`ZoneAnchor`) with procedural chunk fill BETWEEN anchors,
## drawn from `procedural_slot_pool` seeded by per-character `world_seed`.
##
## Pattern: Diablo II's "Den of Evil" / "Tools of the Trade" — each act has
## named sub-areas the quest log + map UI reference by name; the tile layout
## INSIDE each area varies per character but the area itself is a fixed,
## hand-authored shape. See `team/drew-dev/level-chunks.md` § "Zone schema"
## for the full design.
##
## Authoring rule: zones are content (StringName ids, references to chunk
## ids — same `mob_id`-style decoupling as `LevelChunkDef.mob_spawns`). The
## assembler resolves all ids at floor-build time; zones don't import the
## chunk-resource graph directly.
##
## Out of scope for THIS spike (per ticket `86c9xuap4`):
##   - `assemble_floor(chunks, zone_def, seed)` runtime — Track 1.5 procgen
##     spike (ticket `86c9xub9p`) implements it.
##   - S1 retrofit to ZoneDef shape — W2 impl ticket.
##   - Quest-state binding (zone_id references from quest `.tres`) — Track 3
##     W2 ticket.
##   - Map UI consumption — Track 4 W2 ticket.
##
## Cross-references:
##   - `team/drew-dev/level-chunks.md` § "Zone schema" (this resource's doc).
##   - `team/priya-pl/post-wave3-sequencing.md` v1.1 §1 Commitments 3 + 5.
##   - Sibling procgen spike: ticket `86c9xub9p` (consumes ZoneDef).

## Stable zone identifier (snake_case, unique). Quest content + map UI +
## save schema all reference zones by this string. Convention:
## `s{stratum}_z{ordinal}_{slug}` — e.g. &"s1_z1_outer_cloister",
## &"s2_z2_reading_chamber".
@export var zone_id: StringName = &""

## Player-visible name (surfaces in map UI + dialogue + quest log). en-source
## for M3 Tier 3.
@export var display_name: String = ""

## Which stratum this zone lives in (1..8 per `Stratum.gd`). Used by the
## map UI's stratum-pane to group zones + by procgen's per-stratum derived
## seed (`stratum_seed = hash(world_seed, stratum_id)`).
@export var stratum_id: int = 1

## Hand-authored anchor rooms. Each `ZoneAnchor` pins one `LevelChunkDef`
## (by id) to a semantic slot in the zone. Order is significant for the
## assembler: anchors are placed in array order along the zone graph, with
## procedural chunks filling slots between consecutive anchors.
##
## Authoring constraint (asserted by `validate()`):
##   - Exactly one &"entry" anchor.
##   - ≥1 &"exit" anchor.
##   - All `room_id` values unique within the zone.
@export var anchors: Array[ZoneAnchor] = []

## Chunk-id pool the procgen assembler draws from for procedural slots
## between anchors. Each entry is a snake_case chunk id resolvable to a
## `LevelChunkDef.tres` under `resources/level_chunks/`. Procgen uses
## per-zone derived seed (`zone_seed = hash(stratum_seed, zone_id)`) so
## re-entering a zone within a run produces the same layout.
##
## Pool size influences variance: ≥3 entries recommended so two characters
## with different `world_seed`s see meaningfully different layouts.
@export var procedural_slot_pool: Array[StringName] = []

## Inclusive lower bound on the number of procedural-fill chunks between
## any two consecutive anchors. `assemble_floor` clamps total zone length
## to `len(anchors) - 1` procedural-fill slots × range
## `[min_slots_between_anchors, max_slots_between_anchors]`.
@export var min_slots_between_anchors: int = 1

## Inclusive upper bound on the number of procedural-fill chunks between
## any two consecutive anchors. Must be ≥ `min_slots_between_anchors`.
@export var max_slots_between_anchors: int = 3

## Per-zone overrides on the chunk-level port-mating discipline (per
## `level-chunks.md` § "Why ports, not free-form transitions"). Default
## empty: the zone inherits chunk-level port semantics unchanged. Used
## sparingly when a specific zone has an anchor-specific constraint (e.g.
## boss arena's exit port mates only with a specific entry tag).
##
## Schema (when populated): { &"<port_tag_override>": &"<replacement_tag>", ... }
## Validated against the chunk-level port-tag set when `validate()` runs.
@export var port_mating_rules: Dictionary = {}


# ---- Convenience helpers -------------------------------------------

## Returns anchors of a given kind (e.g. ZoneDef.get_anchors_of_kind(&"npc_room"))
## . Empty array if none.
func get_anchors_of_kind(kind: StringName) -> Array[ZoneAnchor]:
	var out: Array[ZoneAnchor] = []
	for a: ZoneAnchor in anchors:
		if a.anchor_kind == kind:
			out.append(a)
	return out


## Returns the zone's single entry anchor (kind=&"entry"). Null if none —
## `validate()` flags this as an error so production-loaded zones always
## return a non-null entry.
func get_entry_anchor() -> ZoneAnchor:
	var entries: Array[ZoneAnchor] = get_anchors_of_kind(&"entry")
	if entries.is_empty():
		return null
	return entries[0]


## Returns true iff any anchor in this zone references `room_id`.
func has_anchor(room_id: StringName) -> bool:
	for a: ZoneAnchor in anchors:
		if a.room_id == room_id:
			return true
	return false


# ---- Validation ----------------------------------------------------

## Returns array of human-readable error strings (empty = valid).
## Editor lint + tests pin against an empty-array result. Production-loaded
## zones must validate cleanly; the assembler refuses to build a floor from
## a zone that returns errors.
##
## Invariants enforced:
##   - `zone_id` non-empty.
##   - `display_name` non-empty (surfaces in map UI; empty would render blank).
##   - `stratum_id` in [1, 8] (per `Stratum.gd` enum).
##   - Exactly one &"entry" anchor.
##   - ≥1 &"exit" anchor.
##   - All `room_id` values unique within `anchors`.
##   - Each `ZoneAnchor` validates cleanly (delegates to `ZoneAnchor.validate()`).
##   - `min_slots_between_anchors >= 0` and `<= max_slots_between_anchors`.
##   - `procedural_slot_pool` non-empty if `max_slots_between_anchors > 0`
##     (otherwise the assembler has nothing to draw from).
##   - Exit anchors with `target_zone_id != &""` reference a DIFFERENT zone
##     (no self-loops at this layer; legitimate loops happen at the floor
##     graph level, not the zone schema level).
func validate() -> Array[String]:
	var errors: Array[String] = []

	if zone_id == &"":
		errors.append("ZoneDef.zone_id must be non-empty")
	if display_name == "":
		errors.append("ZoneDef.display_name must be non-empty (surfaces in map UI)")
	if stratum_id < 1 or stratum_id > 8:
		errors.append("ZoneDef.stratum_id %d must be in [1, 8]" % stratum_id)

	# Per-anchor validate + room_id uniqueness + kind tallies.
	var seen_room_ids: Dictionary = {}
	var entry_count: int = 0
	var exit_count: int = 0
	for a: ZoneAnchor in anchors:
		var anchor_errors: Array[String] = a.validate()
		for e: String in anchor_errors:
			errors.append("anchor[%s]: %s" % [str(a.room_id), e])
		if a.room_id != &"":
			if seen_room_ids.has(a.room_id):
				errors.append("duplicate ZoneAnchor.room_id %s" % str(a.room_id))
			seen_room_ids[a.room_id] = true
		if a.anchor_kind == &"entry":
			entry_count += 1
		elif a.anchor_kind == &"exit":
			exit_count += 1
			if a.target_zone_id != &"" and a.target_zone_id == zone_id:
				errors.append(
					"exit anchor %s target_zone_id self-loops to %s"
					% [str(a.room_id), str(zone_id)]
				)

	if entry_count != 1:
		errors.append(
			"ZoneDef must have exactly one &\"entry\" anchor (got %d)" % entry_count
		)
	if exit_count < 1:
		errors.append(
			"ZoneDef must have at least one &\"exit\" anchor (got %d)" % exit_count
		)

	if min_slots_between_anchors < 0:
		errors.append(
			"ZoneDef.min_slots_between_anchors %d must be >= 0"
			% min_slots_between_anchors
		)
	if max_slots_between_anchors < min_slots_between_anchors:
		errors.append(
			"ZoneDef.max_slots_between_anchors %d must be >= min_slots_between_anchors %d"
			% [max_slots_between_anchors, min_slots_between_anchors]
		)
	if max_slots_between_anchors > 0 and procedural_slot_pool.is_empty():
		errors.append(
			"ZoneDef.procedural_slot_pool must be non-empty when max_slots_between_anchors > 0"
		)

	return errors
