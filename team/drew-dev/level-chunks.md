# Level Chunks — Embergrave

**Owner:** Drew (level systems)
**Status:** v1, M1-ready. Will widen as M2 strata pull procedural assembly.
**Audience:** Devon (room scenes flow into the main game loop / camera bounds), Uma (chunk size + tile size depend on her visual lock), Tess (level integration test cases hang off this contract), Priya (M1 acceptance criteria for "stratum-1 first room").

## Why chunks (and not "one tilemap per room")

A "room" in Embergrave is the smallest navigable space — what the player sees on one screen at the 480×270 internal canvas (per `team/uma-ux/visual-direction.md`). M1 ships exactly **one** room (`s1_room01`), but the level layer is being designed for M2's eight strata, where:

- A stratum is built from many rooms (≥6).
- Some rooms are hand-authored, some procedurally selected.
- Player progress (cleared mobs, found loot) needs to be tracked **per-room** so save/load can resume mid-stratum without spawning a corpse on top of the player.

A monolithic tilemap-per-room file makes the procedural step (M2) painful — every mob spawn, transition, and stratum-descent stair gets buried in scene tree property edits, with no schema for the assembler to reason about. The chunk schema fixes that: chunks are *data first*, scenes second.

## Reference graph

```
Stratum1Room01 (Node2D scene)
  └─ chunk_def: LevelChunkDef            # by-reference
        ├─ scene_path -> .tscn            # the visual geometry
        ├─ ports: Array[ChunkPort]        # entry/exit/locked, + direction + tile pos
        └─ mob_spawns: Array[MobSpawnPoint]   # by-id, resolved at spawn
              └─ mob_id: StringName

LevelAssembler (RefCounted helper)
  └─ assemble_single(chunk_def, mob_factory: Callable) -> AssemblyResult
        ├─ root: Node2D
        ├─ bounds_px: Rect2
        ├─ mobs: Array[Node]
        └─ entry_world_pos: Vector2
```

The assembler is a one-shot helper: pass a chunk def + a mob factory callable, get back a ready-to-parent root + introspection data. Tests inject a recording fake mob factory; the production room uses a Grunt-scene-spawning factory. M2's procedural assembler will add `assemble_floor(chunks: Array[LevelChunkDef])` next to `assemble_single`.

## Schema decisions

### Why mob spawns reference mob_id, not MobDef

Originally I planned `mob_spawns: Array[Dictionary]` with `{position, mob_def: MobDef}`. Switched to `mob_id: StringName` for two reasons:

1. **Decoupling.** Chunks shouldn't import the entire content-schema dependency graph. A chunk `.tres` referencing `MobDef` would cascade-load `LootTableDef`, `ItemDef`, `AffixDef`, `ItemBaseStats`, `LootEntry`, `AffixValueRange` — every `.tres` is then in memory whenever any chunk is. Mob ids are cheap.
2. **Forward-compat.** M2 introduces a `MobRegistry` autoload that maps id → MobDef and applies stratum-scaling multipliers. Chunks already speak the registry's language (string ids), so no migration when M2 lands.

### Why ports, not free-form transitions

A `ChunkPort` carries `(position_tiles, direction, tag)`. Two mating ports must:
- Have opposite directions (a north-edge port mates a south-edge port).
- Have compatible tags (`exit` on both sides).
- Land on the same tile coordinate after offset (the assembler aligns chunks edge-to-edge).

This mating discipline lets M2's assembler enumerate valid neighbour selections deterministically (input: a set of authored chunks + a target floor size, output: a placement). Without ports, the assembler would have to scan tilemap interior pixels for "looks like an exit" — fragile and slow.

### Tile size lock

`tile_size_px = 32` per Uma's visual-direction.md (DECISIONS.md 2026-05-02). Exposed as `@export` so M2 strata can experiment with bigger rooms (a 64 px boss room = larger reading room, more dramatic), but **changing the default for any M1 chunk is a content bug** — Tess's integration test asserts on it.

## File layout

```
res://
  resources/
    level_chunks/
      s1_room01.tres           # LevelChunkDef
  scenes/
    levels/
      Stratum1Room01.tscn      # production room scene root (Stratum1Room01.gd)
      chunks/
        s1_room01_chunk.tscn   # the chunk's visual geometry (loaded via scene_path)
  scripts/
    levels/
      LevelChunkDef.gd
      MobSpawnPoint.gd
      ChunkPort.gd
      LevelAssembler.gd
      Stratum1Room01.gd
```

## Validation

`LevelChunkDef.validate() -> Array[String]` returns an empty array if the chunk is well-formed; otherwise a list of human-readable error strings. Tests assert `validate().is_empty()`. Editor-time linting will eventually wrap this in `_validate_property` or an editor plugin (M2).

Validators check:
- `id` non-empty.
- `size_tiles` strictly positive.
- Every `MobSpawnPoint.position_tiles` is inside the chunk bounds.
- Every `MobSpawnPoint.mob_id` is non-empty.
- Every `ChunkPort.position_tiles` is inside the chunk bounds.

Future validators (M2):
- Port direction matches the edge it sits on.
- No two ports overlap.
- Every spawn point is reachable from every entry port (BFS over walkable tiles).

## Out of scope for M1

- **Procedural floor assembly** — M1 only calls `assemble_single`. M2 adds `assemble_floor`.
- **Persistent room state** (save: which mobs are dead, which chests are opened) — M1 wipes run-progress on death (DECISIONS.md M1-death-rule), so cleared rooms aren't persisted; M2 persists per-room state in the save schema.
- **Streaming / pre-loading** — M1 rooms are tiny, load-on-demand is fine. M2 may pre-load adjacent rooms at chunk boundaries to mask transitions.
- **Tilemap authoring tooling** — M1 chunks use ColorRect placeholders for floor + walls until Uma's pixel-art tiles ship. The schema doesn't change when real tiles arrive; only `s1_room01_chunk.tscn` does.

## Testing surface

- `tests/test_level_chunk.gd` — unit tests on `LevelChunkDef` (size math, contains_tile, port helpers, validate); on `MobSpawnPoint`, `ChunkPort`; and on `LevelAssembler.assemble_single` (null/invalid handling, factory call counts, tile-to-world math, entry-port resolution); plus an authored-TRES round-trip on `s1_room01.tres` (must validate, must be ≤ 480×270, must spawn only grunts).
- `tests/test_stratum1_room.gd` — integration tests on the actual `Stratum1Room01.tscn` scene (loads, instantiates, builds the assembly, spawns grunts inside bounds).

Edge cases tested:
- Out-of-bounds spawn → validation error.
- Out-of-bounds port → validation error.
- Empty mob_id → validation error.
- Invalid chunk passed to assembler → null result, no crash.
- Null chunk passed to assembler → null result, no crash.
- Factory returning null → spawn skipped, no crash.
- No entry port → world position falls back to chunk centre.

## Open decisions

None for M1. M2 will add:
- Procedural assembler shape (probably `Array[LevelChunkDef]` weighted by tag) — picked by Drew when M2 starts.
- Save schema for per-room state — Devon's call (save/load owner) when M2 stash UI lands.
