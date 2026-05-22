class_name PlacedChunk
extends Resource
## A single placed-chunk record inside `AssembledFloor.placed_chunks`. Tracks
## one chunk's identity, world position, size, and kind (anchor vs procedural)
## for downstream consumers (room driver, camera bounds, save schema).
##
## Top-level (not nested inside `AssembledFloor`) so `Array[PlacedChunk]`
## works as a typed field — Godot 4.3 GDScript doesn't allow type-tagged
## arrays of inner-class types.
##
## Authored callers don't construct `PlacedChunk` directly; the assembler
## (`FloorAssembler.assemble_floor`) produces them.
##
## Cross-references:
##   - `resources/level/AssembledFloor.gd` — the container that owns them.
##   - `scripts/levels/FloorAssembler.gd` — the producer.

## Chunk this entry placed (matches `LevelChunkDef.id`).
@export var chunk_id: StringName = &""

## World-pixel position of the chunk's local (0,0). Adjacent chunks along
## the assembly axis are mated edge-to-edge; this position is the
## left-edge / top-edge of the chunk in floor-local world space.
@export var position_px: Vector2 = Vector2.ZERO

## Per-chunk size in pixels (cached from `chunk_def.size_px()` at assemble
## time so downstream code doesn't re-load the chunk resource to know its
## extents).
@export var size_px: Vector2i = Vector2i.ZERO

## Placement kind — one of `&"anchor"` / `&"procedural"`. Anchor chunks are
## hand-authored per zone (deterministic across all characters); procedural
## chunks are drawn from `ZoneDef.procedural_slot_pool` seeded by per-
## character world_seed.
@export var kind: StringName = &"procedural"

## Iff `kind == &"anchor"`, the `ZoneAnchor.room_id` of the anchor this
## placement represents. Quest content + save schema key on this. Empty
## for procedural placements.
@export var anchor_room_id: StringName = &""
