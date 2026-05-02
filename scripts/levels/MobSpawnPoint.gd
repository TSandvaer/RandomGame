class_name MobSpawnPoint
extends Resource
## A single mob spawn instruction inside a `LevelChunkDef`. Chunks reference
## mobs by `StringName` id (not by typed `MobDef` ref) so chunk authoring
## doesn't pull in the whole content-schema dependency graph. The level
## assembler resolves `mob_id` against a `MobRegistry` at room-build time.
##
## See `team/drew-dev/level-chunks.md` (sibling design doc) for rationale.

## Position in tile coordinates inside the chunk's local origin (0,0 = the
## chunk's top-left). The assembler converts to world-space pixels using
## `LevelChunkDef.tile_size_px` × the chunk's placement offset.
@export var position_tiles: Vector2i = Vector2i.ZERO

## Snake_case mob id. Must resolve against the MobRegistry at spawn time.
## Examples: &"grunt", &"shooter" (M2), &"charger" (M2).
@export var mob_id: StringName = &""
