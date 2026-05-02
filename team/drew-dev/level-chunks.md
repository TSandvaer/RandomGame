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
      s1_room01.tres ... s1_room08.tres   # LevelChunkDef (one per S1 room)
  scenes/
    levels/
      Stratum1Room01.tscn      # production room scene root (Stratum1Room01.gd, single-mob intro)
      Stratum1Room02.tscn ... Stratum1Room08.tscn  # MultiMobRoom-driven S1 rooms
      Stratum1BossRoom.tscn    # S1 boss arena (Stratum1BossRoom.gd)
      chunks/
        s1_room01_chunk.tscn   # the chunk's visual geometry (loaded via scene_path)
        ...
  scripts/
    levels/
      LevelChunkDef.gd         # generic chunk schema
      MobSpawnPoint.gd         # generic
      ChunkPort.gd             # generic
      LevelAssembler.gd        # generic; assemble_single() (M1), assemble_floor() (M2)
      MultiMobRoom.gd          # generic multi-mob room driver (S1 rooms 02-08; reusable for S2+)
      RoomGate.gd              # generic
      HealingFountain.gd       # generic
      StratumExit.gd           # generic descent portal
      Stratum.gd               # NEW: stratum namespace (enum + prefix + descent helpers)
      Stratum1Room01.gd        # S1 content (single-mob intro room)
      Stratum1BossRoom.gd      # S1 content (boss-room timing skeleton + loot routing)
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

## Multi-stratum tooling (M2 scaffold)

Landed in W3-B2 (`drew/stratum-2-scaffold`, 2026-05-02). Pure refactor + scaffold — **no new game content**. This section is the contract M2 implementers (S2 rooms, S2 mobs, S2 palette) read before authoring stratum-N content.

### What was renamed

| Before | After | Reason |
|---|---|---|
| `scripts/levels/Stratum1MultiMobRoom.gd` (`class_name Stratum1MultiMobRoom`) | `scripts/levels/MultiMobRoom.gd` (`class_name MultiMobRoom`) | Body had zero S1-specific logic. The mob_id list (`grunt`/`charger`/`shooter`) is M1 content served via `@export_file` paths, not a class-name contract. M2+ rooms reuse the script unchanged with stratum-N mob scenes wired through the same exports. |
| `scenes/levels/Stratum1Room0{2..8}.tscn` script ref | `res://scripts/levels/MultiMobRoom.gd` | Mechanical follow-on. Scene file names kept `Stratum1Room0N` (they're S1 *content* — the chunk_def + room_gate placement encode stratum-1 layouts). |
| `tests/test_stratum1_rooms.gd` type ref | `MultiMobRoom` (type) | Same rationale; test asserts the room behavior, not the class name. |

### What was deliberately NOT renamed (and why)

| Kept | Rationale |
|---|---|
| `Stratum1Room01.gd` (`class_name Stratum1Room01`) | Truly S1-specific. Hardcoded fallback `load("res://resources/level_chunks/s1_room01.tres")`; only knows `&"grunt"` mob_id. The single-mob "first room" is a one-off feel-good intro, not a generic mechanism. M2's first room would be its own one-off (`Stratum2Room01.gd`) or simply use `MultiMobRoom` with a chunk_def that has 1-2 mobs. |
| `Stratum1BossRoom.gd` (`class_name Stratum1BossRoom`) | References `Stratum1Boss` class + `stratum1_boss.tres` directly. Has the 1.8 s entry-sequence beat-counting that's stratum-1-specific (Uma's `boss-intro.md`). Recommendation for M2: when authoring `Stratum2BossRoom.gd`, extract the timing-skeleton + door-trigger + loot-routing logic into `BossRoomBase.gd` (RefCounted helper) and have both stratum boss rooms `extends BossRoomBase`. NOT extracting now because the boss-room logic is nuanced (Uma binding for Beats 1–4, signal contracts) and a premature extraction would risk a Stratum1BossRoom regression. Defer until S2 boss content lands and the second use case clarifies the seam. |
| `Stratum1Boss.gd` | Is the actual stratum-1 boss content. Phase weights 50/30/20%, enrage modifiers, `stratum1_boss.tres` MobDef are all S1-specific tuning. |
| `LevelChunkDef.gd`, `LevelAssembler.gd`, `MobSpawnPoint.gd`, `ChunkPort.gd` | Already generic. Audited — zero `Stratum1` / `s1_` references in source or behaviour. |
| `RoomGate.gd`, `HealingFountain.gd` | Generic mechanics. Single doc-comment mention of `Stratum1Room02..08` / `Stratum1Room06` as M1 *use sites* — kept as accurate pointer. |
| `StratumExit.gd`, `StratumProgression.gd` | Already generic — both use `room_id: StringName` and treat strata uniformly. The `mark_cleared` API doesn't even know which stratum a room belongs to; it just stores the id. |
| `resources/level_chunks/s1_*.tres` | Already stratum-prefixed. M2 adds `s2_*.tres` alongside. |

### The `Stratum` namespace

New file `scripts/levels/Stratum.gd` (class_name `Stratum`, RefCounted, static-only, NOT an autoload). Single source of truth for "which stratum is this?". API:

```
Stratum.Id.S1 ... Stratum.Id.S8         # int enum, persisted in saves
Stratum.ALL_IDS                          # Array[int], canonical descent order
Stratum.is_known(id) -> bool
Stratum.prefix(id) -> StringName         # Stratum.Id.S2 -> &"s2"
Stratum.id_from_prefix(p) -> int         # &"s3" -> Stratum.Id.S3
Stratum.display_name(id) -> String       # Stratum.Id.S1 -> "Stratum 1"
Stratum.next(id) -> int                  # descent helper; 0 at terminal
Stratum.id_from_chunk_id(chunk_id) -> int  # &"s2_room01" -> Stratum.Id.S2
```

Conventions:
- `id` is the stable int (1..8). Saves persist this.
- `prefix` is `sN` (lowercase), used in chunk ids and resource paths.
- `0` is the explicit unknown sentinel for parser misses — never == any real Id.

Tests in `tests/test_stratum_namespace.gd` (20 tests) lock the round-trip + listing exhaustiveness contract. **When you add an Id.S9, you MUST also extend ALL_IDS / prefix / id_from_prefix / display_name and add a row to the test file** — the test is exhaustive against ALL_IDS by design, so a half-update fails CI loudly.

Why not an autoload: `class_name` makes `Stratum.S1` reachable from any script implicitly without a `project.godot` autoload entry, keeping the autoload list lean. The static-only methods are pure functions; no state to share.

### Resource folder layout — recommendation for M2

Currently:
```
resources/
  level_chunks/   s1_room01..08.tres        # already stratum-prefixed (good)
  mobs/           grunt.tres, swift.tres... # FLAT — works because all M1 mobs are S1
  loot_tables/    boss_drops.tres, ...      # FLAT
  affixes/        swift.tres, vital.tres,...# FLAT
```

When S2 mobs / loot / affixes land, **place them under a stratum subfolder**:
```
resources/
  mobs/
    s1/   grunt.tres, charger.tres, shooter.tres, stratum1_boss.tres
    s2/   <s2 mobs go here>
  loot_tables/
    s1/   grunt_drops.tres, boss_drops.tres
    s2/   <s2 loot tables>
  affixes/
    shared/  swift.tres, vital.tres, keen.tres   # cross-stratum affixes stay shared
    s2/      <s2-only affixes if any>
```

**Don't move existing files in this PR** — the move would touch every test that hardcodes `res://resources/mobs/grunt.tres`, and the M1 RC has zero ROI from the churn. Move when M2 implementers add S2 content (single PR moves S1 + adds S2). If a `MobRegistry` autoload lands during M2 (per `MobSpawnPoint.gd` doc-comment), the registry can resolve `mob_id -> path` by stratum lookup, and call sites stop hardcoding paths entirely.

### M2 implementer checklist

When S2 rooms / mobs / palette are authored (M2 Drew or whoever picks up the dispatch):

1. **Author S2 chunks.** Create `resources/level_chunks/s2_room0N.tres` (`LevelChunkDef`) for each S2 room. Use `&"s2_roomNN"` chunk ids. The `Stratum.id_from_chunk_id` parser already routes these correctly (test pinned).
2. **Author S2 mob scenes + TRES.** Place under `resources/mobs/s2/<mob>.tres` per the recommendation above. Wire scene paths.
3. **Build S2 scenes.** One `.tscn` per room. Most rooms reuse `MultiMobRoom.gd` directly — point `chunk_def` at the matching `s2_room0N.tres` and update the `*_scene_path` exports if the mob roster differs from S1's grunt/charger/shooter set.
4. **S2 boss room.** Author `Stratum2BossRoom.gd` (parallel to `Stratum1BossRoom.gd`). If you need to extract `BossRoomBase.gd` (entry-sequence timing + boss spawn + loot routing + StratumExit wiring), do it as a small refactor PR landed BEFORE the S2 boss content PR — keeps the diff readable. If S2 boss is mechanically very different (e.g. multi-phase shifts the timing assumptions), keep the two boss rooms parallel-but-separate; premature DRY is a bigger maintenance hazard than two mostly-similar 270-line files.
5. **Mob_id resolution.** `MultiMobRoom._spawn_mob` is a `match` on mob_id with `&"grunt"`/`&"charger"`/`&"shooter"` arms. Add S2 mob arms inline OR (preferred) replace the match with a `MobRegistry` autoload lookup so the room script becomes stratum-agnostic. The `MobRegistry` shape is sketched in `MobSpawnPoint.gd` doc-comment (StringName id → MobDef + scene + apply stratum scaling).
6. **Stratum descent.** `Stratum.next(Stratum.Id.S1) == Stratum.Id.S2` already (test pinned). The S1 boss room emits `stratum_exit_unlocked`; route it to a level-flow controller that calls `Stratum.next(current)`, loads the matching S2 first-room scene, and persists progression via `StratumProgression.preserve_for_descend()`.
7. **Save schema.** This scaffold did NOT bump v3. M2's persistent-meta PR (Devon W3-B4 in flight) handles v3→v4 with the per-stratum unlock state. Coordinate with Devon's spec before persisting any new "current_stratum" field.
8. **Tests.** Pair S2 rooms with `tests/test_stratum2_rooms.gd` (mirroring `test_stratum1_rooms.gd`'s 17 tests — load, mob counts, port chain, archetype mix). The `Stratum` namespace tests are exhaustive — adding Id.S9 requires extending those, but adding S2-only content does not (S2 already lives in the enum).

### Audit notes

Audit findings (full sweep of `scripts/levels/*` + `tests/test_stratum1_*` + `scenes/levels/*`):

- **0 generic classes had S1-specific assumptions.** `LevelChunkDef`, `LevelAssembler`, `MobSpawnPoint`, `ChunkPort`, `RoomGate`, `HealingFountain`, `StratumExit` all read S1 chunk data uniformly via `chunk_def.id` and string-typed mob_ids; renaming any of them would have been spurious.
- **1 mis-named class found and renamed:** `Stratum1MultiMobRoom` → `MultiMobRoom`.
- **2 classes correctly named as S1-content (kept):** `Stratum1Room01`, `Stratum1BossRoom` — both tied to S1-specific resources/behaviour.
- **`StratumProgression` autoload is already stratum-aware** — uses StringName room_ids without baked-in stratum coupling. No changes needed.
- **`StratumExit` is already generic** — color constants + prompt text are cross-stratum, no S1-specific tuning.
- **Save schema unchanged** — v3 stays v3. The `Stratum` enum int values match the integers Devon's W3-B4 schema-bump spec will use (1..8), so when v4 lands and starts persisting `meta.deepest_stratum` as a typed int, the values are already aligned.

## Open decisions

None for M1. M2 will add:
- Procedural assembler shape (probably `Array[LevelChunkDef]` weighted by tag) — picked by Drew when M2 starts.
- Save schema for per-room state — Devon's call (save/load owner) when M2 stash UI lands.
- Whether `_spawn_mob` in `MultiMobRoom` becomes a `MobRegistry`-driven lookup (preferred) or stays a hand-rolled match block. Decided when S2 mob count > 5 makes the match block unwieldy.
- Whether to extract `BossRoomBase.gd` from `Stratum1BossRoom.gd` — decided when S2 boss content authoring exposes the seam.
