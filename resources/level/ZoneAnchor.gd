class_name ZoneAnchor
extends Resource
## A single hand-authored anchor room inside a `ZoneDef`. Each anchor pins one
## `LevelChunkDef` (by id) to a known semantic slot in the zone — entry, exit,
## npc_room, boss_room, quest_target, story_beat. The procgen assembler
## (`assemble_floor`) places anchors at deterministic positions in the zone
## graph, then fills the slots between them with chunks drawn from
## `ZoneDef.procedural_slot_pool` seeded by per-character `world_seed`.
##
## Anchors are deterministic per zone — every character in S1 sees the same
## entry, npc_room, quest_target, boss_room, exit chunks. Procedural variance
## happens BETWEEN anchors, not AT anchors. See
## `team/priya-pl/post-wave3-sequencing.md` v1.1 §1 Commitment 5
## (hand-authored anchors vs procedural fill split) and
## `team/drew-dev/level-chunks.md` § "Zone schema" for the full rationale.
##
## Anchor-kind taxonomy (exhaustive — extend deliberately, not casually; quest
## content + map UI + procgen all branch on these):
##
##   &"entry"          — player enters the zone here. Exactly one per zone
##                       (`ZoneDef.validate()` asserts).
##   &"exit"           — player leaves the zone here. ≥1 per zone; an exit
##                       anchor MAY set `target_zone_id` to declare the
##                       next zone (cross-zone mating per
##                       `level-chunks.md` § "Cross-zone transitions").
##   &"npc_room"       — hand-placed NPC sits here (per-stratum NPC roster
##                       per SI-5). Dialogue trees bind by `room_id`.
##   &"boss_room"      — the stratum boss arena. Stratum1BossRoom +
##                       Stratum2BossRoom are the M3 instances.
##   &"quest_target"   — exploration-quest objective resolves here
##                       (Commitment 3). Quest `.tres` resources reference
##                       `zone_id` + `quest_target_room_id` to land the
##                       objective inside this anchor.
##   &"story_beat"     — narrative-critical room flagged by Drew + Uma
##                       (rare; e.g. a forced cutscene trigger or a
##                       fixed-position lore prop).
##
## See `team/drew-dev/level-chunks.md` § "ZoneAnchor kinds" for per-kind
## semantics + examples.

## Anchor identifier inside the zone (snake_case, unique within the parent
## ZoneDef). Quest content + map UI reference anchors by `room_id`, NOT by
## chunk-id (so a zone can re-use a chunk shape with two different
## semantic slots — e.g. two `npc_room` anchors both pointing at the same
## chunk geometry).
@export var room_id: StringName = &""

## Snake_case chunk id referencing a `LevelChunkDef` registered with the
## level system (resources/level_chunks/<chunk_id>.tres). The assembler
## resolves this id at floor-build time; chunks declare `mob_id` strings
## the same way per `LevelChunkDef.gd` (decoupling rationale).
@export var chunk_id: StringName = &""

## Semantic role this anchor plays in the zone. One of the values in the
## class-doc taxonomy above. Procgen + quest + map UI branch on this.
@export var anchor_kind: StringName = &""

## OPTIONAL — for `anchor_kind == &"exit"` only — the `zone_id` this exit
## leads to. When set, the assembler stitches this zone's exit port to the
## target zone's `&"entry"` anchor via the existing port-mating
## discipline (per `level-chunks.md` § "Why ports, not free-form
## transitions"). Empty for terminal exits (e.g. boss-defeat → return to
## hub-town flow). Ignored for non-`exit` kinds.
@export var target_zone_id: StringName = &""


# ---- Validation -----------------------------------------------------

## Canonical anchor-kind set. `ZoneDef.validate()` rejects any anchor whose
## `anchor_kind` is not in this set. Keep in sync with the class-doc
## taxonomy + `level-chunks.md` § "ZoneAnchor kinds".
const KINDS: Array[StringName] = [
	&"entry",
	&"exit",
	&"npc_room",
	&"boss_room",
	&"quest_target",
	&"story_beat",
]


## Returns true iff `kind` is a recognized anchor-kind.
static func is_known_kind(kind: StringName) -> bool:
	return kind in KINDS


## Validate a single anchor. Returns array of human-readable error strings
## (empty = valid). `ZoneDef.validate()` calls this per-anchor and prefixes
## the anchor's `room_id` to each message.
func validate() -> Array[String]:
	var errors: Array[String] = []
	if room_id == &"":
		errors.append("ZoneAnchor.room_id must be non-empty")
	if chunk_id == &"":
		errors.append("ZoneAnchor.chunk_id must be non-empty")
	if not is_known_kind(anchor_kind):
		errors.append(
			"ZoneAnchor.anchor_kind %s is not in ZoneAnchor.KINDS %s"
			% [str(anchor_kind), str(KINDS)]
		)
	# target_zone_id is meaningful only on exit anchors. Warn (not error) if
	# set on a non-exit kind — the assembler ignores it, but a typo would
	# silently fail without this check.
	if target_zone_id != &"" and anchor_kind != &"exit":
		errors.append(
			"ZoneAnchor.target_zone_id only meaningful for anchor_kind=&\"exit\" (got %s)"
			% str(anchor_kind)
		)
	return errors
