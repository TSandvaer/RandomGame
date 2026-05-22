class_name AssembledFloor
extends Resource
## Output container for `FloorAssembler.assemble_floor(zone_def, seed)` —
## the deterministic per-character placement of a single zone's chunks
## (anchors in zone-graph order + procedural fill between them).
##
## ## Why a Resource (not a plain Dictionary / Array)
##
## Pattern matches existing `LevelChunkDef` + `ZoneDef` data layer. Lets
## the assembler's output flow through the same type-system surface as
## the input (tests can `assert_typeof(result, AssembledFloor)`; future
## room-driver code receives a typed Resource rather than parsing a
## Dictionary contract). Also future-proofs against a `.tres` cache layer
## if W3+ ever wants to persist assembled floors (e.g. for save-mid-zone
## resumption — not currently in scope).
##
## ## Shape
##
## Five load-bearing fields:
##
##   `zone_id` — the zone this floor was assembled FROM (StringName,
##                matches `ZoneDef.zone_id`). Save schema + quest-state
##                + map UI key on this.
##
##   `seed` — the input seed used to assemble this floor. Documented as
##                the *zone-level derived seed* (callers typically pass
##                the result of `FloorAssembler.derive_zone_seed(...)`).
##                Stored for debug + same-seed re-assembly verification.
##
##   `placed_chunks` — ordered list of `PlacedChunk` resources. Index 0
##                is leftmost in world space, index N-1 is rightmost.
##
##   `bounding_box_px` — `Rect2` covering every placed chunk's local
##                bounds union, in world pixels relative to the floor's
##                local origin (0,0). Used by `CameraDirector.
##                set_world_bounds(...)` per camera-scroll.md.
##
##   `port_mating_errors` — list of human-readable strings; non-empty iff
##                the assembler placed an adjacent pair whose ports
##                failed the mating contract. The assembler returns a
##                result regardless (R-PROCGEN.b mitigation — broken
##                mating is reported, not raised), so downstream code
##                can defensively decide whether to render the floor or
##                error.
##
## ## Cross-references
##
##   - `scripts/levels/FloorAssembler.gd` — the producer.
##   - `resources/level/PlacedChunk.gd` — single-chunk record type.
##   - `resources/level/ZoneDef.gd` + `resources/level/ZoneAnchor.gd` — the input.
##   - `team/drew-dev/level-chunks.md` § "Zone schema" + § "Why ports".
##   - Sibling spike: ticket `86c9xub9p` (this resource lives in this PR).


## Zone this floor was assembled from. Stable identifier — matches
## `ZoneDef.zone_id`.
@export var zone_id: StringName = &""

## Zone-level derived seed used during assembly. Stored for debug
## visibility + same-seed re-assembly verification. NOT the world_seed
## itself — see `FloorAssembler.derive_zone_seed(stratum_seed, zone_id)`.
@export var seed: int = 0

## Ordered list of placed chunks. Index 0 = leftmost in world space.
@export var placed_chunks: Array[PlacedChunk] = []

## Floor's total bounding box in world pixels (relative to the floor's
## local origin 0,0). Consumed by `CameraDirector.set_world_bounds(...)`
## per camera-scroll.md.
@export var bounding_box_px: Rect2 = Rect2()

## Port-mating violations detected during assembly (empty = clean mating).
## Each entry is a human-readable description of the offending pair —
## non-fatal at assemble time (the chunks are still placed so the visual
## proof scene can render the regression), but the W2 retrofit ticket
## treats a non-empty list as a hard fail.
@export var port_mating_errors: Array[String] = []


## True iff `placed_chunks.is_empty()` — the assembler failed before
## placing any chunk (e.g. invalid zone_def passed). Distinguishes
## "empty zone" (degenerate but legal) from "assembler bailed".
func is_empty() -> bool:
	return placed_chunks.is_empty()


## True iff `port_mating_errors.is_empty()` — convenience for downstream
## "should I render this floor?" decisions.
func is_well_mated() -> bool:
	return port_mating_errors.is_empty()


## Number of placed chunks (anchor + procedural combined).
func chunk_count() -> int:
	return placed_chunks.size()


## Number of anchor-kind placements. Sum-check against the input ZoneDef's
## anchors array length (test pin).
func anchor_count() -> int:
	var n: int = 0
	for pc: PlacedChunk in placed_chunks:
		if pc.kind == &"anchor":
			n += 1
	return n


## Number of procedural-kind placements. Sum-check against zone_def's
## `[min_slots_between_anchors, max_slots_between_anchors]` × gap count
## bounds.
func procedural_count() -> int:
	var n: int = 0
	for pc: PlacedChunk in placed_chunks:
		if pc.kind == &"procedural":
			n += 1
	return n
