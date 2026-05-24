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

## Zone schema (M3 Tier 3 W1 spike, ticket `86c9xuap4`)

Landed as a spike in M3 Tier 3 W1 (`drew/86c9xuap4-zone-schema`). Pure paper-design + data layer — `assemble_floor(chunks, zone_def, seed)` runtime is the sibling procgen spike (ticket `86c9xub9p`). This section is the contract that ticket's runtime consumes; the W2 retrofit ticket converts S1's 8 hand-arranged chunks to anchor-driven assembly against this shape.

**Cross-references:**

- `team/priya-pl/post-wave3-sequencing.md` v1.1 §1 Commitment 3 (quests reference geography by `zone_id`) + Commitment 5 (per-character `world_seed` + procedural chunk-fill between anchors). Sponsor signed SI-2 + added Commitment 5 on 2026-05-22.
- `team/tess-qa/m3-acceptance-plan-tier-3.md` rows `ZQ-1` through `ZQ-8` (acceptance criteria fold up to this spike).
- Sibling procgen spike: ticket `86c9xub9p` (consumes `ZoneDef`; implements `assemble_floor`).

### Why zones (and not "one chunk = one room = one zone")

A **chunk** is a tile-arrangement unit — the smallest navigable space, sized to fit the 480×270 internal canvas (~15×8 tiles at 32 px). A **zone** is the named geography layer ABOVE chunks: a fixed sequence of hand-authored anchor chunks (entry, NPC room, boss room, quest target, exit) with procedural chunk-fill between them, drawn from a per-zone pool seeded by per-character `world_seed`.

**Diablo II precedent.** Each act in D2 has named sub-areas the quest log + map UI reference by name — "Den of Evil," "Tools of the Trade," "Search for Cain." Each is a fixed, hand-authored shape (entry from town portal, a quest-target room, an exit/boss area), with tile layout INSIDE the area varying per character. The Embergrave shape is structurally the same:

| D2 (single act) | Embergrave (single stratum) |
|---|---|
| "Den of Evil" sub-area | `s1_z1_outer_cloister` ZoneDef |
| Fixed entry + objective room + exit | `entry` + `quest_target` + `exit` anchors |
| Different tile maze per character | Procedural slots between anchors, seeded by `world_seed` |
| Quest log says "go to Den of Evil" | Quest `.tres` references `zone_id: &"s1_z1_outer_cloister"` |
| Map UI shows "Den of Evil (cleared)" | World-map UI per-stratum pane lists zones by `display_name` |

**Why the layer is necessary** (the alternative — quests referencing chunks or pixel coordinates — fails):

1. **Quests can't bind to chunks** — chunks are tile-arrangement units that procgen reshuffles per character. A quest pointing at "`s1_room04`" would target a chunk that doesn't exist in some characters' floors. Quests bind to zones (`s1_z1_outer_cloister`) and the quest-target anchor inside them, which is deterministic per zone.
2. **Map UI can't display chunk graphs** — 8 strata × N zones × M chunks-per-zone is too dense to render legibly. The Diablo-II per-act map shows ~5-10 named zones per act; that maps cleanly to "8 strata × 2-4 zones per stratum × tile-maze inside" which is the Embergrave shape.
3. **Procgen has nowhere to anchor** — without zones, "where does the boss room go?" has no answer. Zones fix the anchor positions (boss_room is always the second-to-last anchor) and let procgen randomize what's BETWEEN them.

The chunk schema already pre-shaped this in § "Why ports, not free-form transitions" (v1, M1) — the `ports + assemble_floor` design was sized for multi-chunk procedural assembly from day one. Zones are the layer that gives the assembler something to compose against; chunks are still the unit it places.

### ZoneDef shape

```
ZoneDef (Resource — resources/level/ZoneDef.gd)
  ├─ zone_id: StringName            # &"s1_z1_outer_cloister" (stable id)
  ├─ display_name: String           # "Outer Cloister" (map UI + dialogue)
  ├─ stratum_id: int                # 1..8 (per Stratum.gd enum)
  ├─ anchors: Array[ZoneAnchor]     # hand-authored, deterministic per zone
  ├─ procedural_slot_pool: Array[StringName]  # chunk ids for procgen fill
  ├─ min_slots_between_anchors: int # inclusive lower bound (default 1)
  ├─ max_slots_between_anchors: int # inclusive upper bound (default 3)
  └─ port_mating_rules: Dictionary  # per-zone overrides (default empty)

ZoneAnchor (Resource — resources/level/ZoneAnchor.gd)
  ├─ room_id: StringName            # &"s1_z1_threshold" (unique inside zone)
  ├─ chunk_id: StringName           # &"s1_room01" (resolves to LevelChunkDef)
  ├─ anchor_kind: StringName        # one of ZoneAnchor.KINDS
  └─ target_zone_id: StringName     # only meaningful for exit anchors
```

**Design rationale (one bullet per non-obvious field):**

- **`zone_id` is StringName, not int.** Same rationale as chunk `mob_id`s: save schema + quest content + map UI all reference zones by string id, so the chunk-resource graph doesn't cascade-load on every quest/UI access. Convention: `s{stratum}_z{ordinal}_{slug}`.
- **`display_name` mandatory** (validate fails if empty). Map UI's per-stratum pane reads it; an empty display name renders blank cells which is a content bug, not a soft-fail.
- **`stratum_id: int` matches `Stratum.gd`'s enum** — `1..8`. The procgen assembler uses `stratum_seed = hash(world_seed, stratum_id)` to scope per-stratum determinism (re-rolling at S1 must not leak S2's layout into S1; see post-wave3-sequencing.md v1.1 §1 Commitment 5).
- **`anchors: Array[ZoneAnchor]` order matters.** The assembler places anchors in array order along the zone graph; procedural slots fill the gaps between consecutive anchors. Authoring convention: `entry` first, `exit` last, with `npc_room` / `quest_target` / `boss_room` / `story_beat` in narrative order between them.
- **`procedural_slot_pool: Array[StringName]` references chunk ids, not chunk resources.** Same `mob_id`-style decoupling — the zone `.tres` doesn't import the chunk-resource graph. Pool size ≥3 recommended so two characters with different `world_seed`s see meaningfully different layouts; the worked example uses 4.
- **`min_/max_slots_between_anchors` are inclusive bounds.** Total procedural chunks per zone is `(len(anchors) - 1) × [min, max]`. With 5 anchors + `[1, 3]`, a zone has 4 to 12 procedural chunks plus 5 anchors = 9 to 17 total chunks per character. Bounds prevent two failure modes: too few = zone reads as a hallway, too many = traversal becomes tedious.
- **`port_mating_rules: Dictionary` defaults empty.** Zones inherit chunk-level port-mating from § "Why ports" unchanged. Only populate when a specific zone has an anchor-specific constraint (e.g. boss arena's exit port mates only with a stratum-descent entry tag).

### ZoneAnchor kinds enum

Exhaustive list — `ZoneAnchor.KINDS` is the canonical source of truth, `ZoneDef.validate()` rejects unknown kinds. Extend deliberately, not casually: quest content + map UI + procgen all branch on these.

| Kind | Semantic | Worked-example reference | Notes |
|---|---|---|---|
| `&"entry"` | Player enters the zone here. The assembler resolves this to the player's spawn point on first zone-load. | `s1_z1_outer_cloister` → `s1_room01` (Threshold) | Exactly one per zone (`validate()` asserts). |
| `&"exit"` | Player leaves the zone here. May declare `target_zone_id` for cross-zone mating (see § "Cross-zone transitions" below). | `s1_z1_outer_cloister` → `s1_room08` chunk geometry, anchor `room_id = &"s1_z1_descent"`, `target_zone_id = &"s2_z1_sunken_entrance"` | ≥1 per zone. Empty `target_zone_id` = terminal exit (boss-defeat → hub-town flow). |
| `&"npc_room"` | Hand-placed NPC sits here. Dialogue trees bind by `room_id`. | `s1_z1_outer_cloister` → `s1_room02` (Antechamber) | Per-stratum NPC roster per SI-5: 1 in S1, 2 in S2. |
| `&"boss_room"` | Stratum boss arena. | `s1_z1_outer_cloister` → `s1_room08` (Bossward Threshold). The boss arena scene itself is `Stratum1BossRoom.tscn`; the anchor's chunk is the antechamber leading into it. | One per stratum (per the stratum-1 / stratum-2 boss model). |
| `&"quest_target"` | Exploration-quest objective resolves here (Commitment 3). | `s1_z1_outer_cloister` → `s1_room04` (Marksman's Perch — Shooter-only chunk; good "find the marksman" objective). | Quest `.tres` resources reference `zone_id` + the anchor `room_id`. |
| `&"story_beat"` | Narrative-critical room flagged by Drew + Uma. | (no example in S1 z1 — rare; e.g. a forced cutscene trigger or a fixed-position lore prop). | Use sparingly — story_beats are heavy; over-use erodes the player's sense of agency. |

**Two anchors MAY share chunk geometry** (i.e. point at the same `chunk_id`) **but MUST have distinct `room_id` values**. The worked example demonstrates this: `boss_room` (`room_id = &"s1_z1_bossward"`) and `exit` (`room_id = &"s1_z1_descent"`) both reference `chunk_id = &"s1_room08"`. The assembler places the chunk twice (with separate parent nodes); save schema + quest binding + map UI all key on `room_id` so the two slots are distinct entities to gameplay.

### Hand-authored vs procedural split

Restated from post-wave3-sequencing.md v1.1 §1 Commitment 5 for the level-content authoring surface:

**Hand-authored (deterministic per stratum + per zone, identical for all characters):**
- Zone entries + exits (the `entry` / `exit` anchors above; ports stitched per § "Why ports").
- NPC placement rooms (`npc_room` anchors).
- Boss rooms (`boss_room` anchors).
- Quest-target rooms (`quest_target` anchors per Commitment 3).
- Story-beat rooms (`story_beat` anchors flagged by Drew + Uma).
- Hub-town (single-screen by design per Commitment 4; not procedural).

**Procedural (per-character, seeded by `world_seed`):**
- Tile-chunk arrangement WITHIN zone bounds, between the hand-authored anchors (drawn from `procedural_slot_pool` with per-zone derived seed).
- Mob spawn point selection within procedural chunks (per chunk's authored set, which spawn-points fire for this character).
- Loot pickup placement within procedural chunks.

**Determinism:** per-character `world_seed` rolled at character creation (save schema additive on top of v5's per-character keys). Per-stratum derived seed: `stratum_seed = hash(world_seed, stratum_id)`. Per-zone derived seed: `zone_seed = hash(stratum_seed, zone_id)`. Same character on the same zone always sees the same layout; re-entering a zone within a run produces the same layout.

**Assembler signature (lives in sibling procgen spike `86c9xub9p`):**

```gdscript
# In LevelAssembler.gd, alongside the existing assemble_single():
func assemble_floor(
    chunks_by_id: Dictionary,    # &"s1_room01" -> LevelChunkDef
    zone_def: ZoneDef,
    seed: int                    # zone_seed = hash(stratum_seed, zone_id)
) -> AssemblyResult
```

The assembler places `zone_def.anchors` in order at deterministic positions in the floor graph, then for each gap between consecutive anchors draws `randi_range(zone_def.min_slots_between_anchors, zone_def.max_slots_between_anchors)` chunks from `zone_def.procedural_slot_pool` using a seeded RNG, mating ports per the existing chunk-level discipline. The implementation lives in the sibling spike — this spike just pins the data shape.

### Worked example: `s1_z1_outer_cloister.tres`

Lives at `resources/level/zones/s1_z1_outer_cloister.tres` — the first zone authored against the new schema, demonstrating all five anchor kinds (minus `story_beat`) + a 4-chunk procedural pool drawn from existing S1 chunk variants.

```
ZoneDef
  zone_id          = &"s1_z1_outer_cloister"
  display_name     = "Outer Cloister"
  stratum_id       = 1
  anchors          = [
    ZoneAnchor(room_id=&"s1_z1_threshold",       chunk_id=&"s1_room01", kind=&"entry"),
    ZoneAnchor(room_id=&"s1_z1_antechamber",     chunk_id=&"s1_room02", kind=&"npc_room"),
    ZoneAnchor(room_id=&"s1_z1_marksmans_perch", chunk_id=&"s1_room04", kind=&"quest_target"),
    ZoneAnchor(room_id=&"s1_z1_bossward",        chunk_id=&"s1_room08", kind=&"boss_room"),
    ZoneAnchor(room_id=&"s1_z1_descent",         chunk_id=&"s1_room08", kind=&"exit",
               target_zone_id=&"s2_z1_sunken_entrance"),
  ]
  procedural_slot_pool = [&"s1_room03", &"s1_room05", &"s1_room06", &"s1_room07"]
  min_slots_between_anchors = 1
  max_slots_between_anchors = 3
  port_mating_rules         = {}
```

**Per-character layout shape:** with 5 anchors + 4 gaps × `[1, 3]` procedural fill, each character sees 9 to 17 chunks total in this zone. With pool size 4 and 4-to-12 procedural slots, the per-character variance is substantial (different fill order, different fill density). The `entry → npc_room → quest_target → boss_room → exit` narrative ordering is identical across characters — the zone reads the same; only the tile-maze in between differs.

**Cross-validation with existing chunks:** all 5 anchor `chunk_id`s and all 4 `procedural_slot_pool` entries resolve to existing `resources/level_chunks/s1_room0N.tres` files. The spike's GUT test `test_authored_s1_z1_outer_cloister_anchor_chunks_resolve` + `..._pool_chunks_resolve` pin this — typos in the worked example fail CI loudly.

**W2 retrofit hook:** this zone is the W2 retrofit target. The existing S1 chunk arrangement (Stratum1Room01 through Stratum1Room08 in `Main.tscn` flow) becomes anchor-driven assembly via `assemble_floor(chunks_by_id, this_zone_def, seed)`. The 8 chunks split: 5 stay as anchors (with hand-authored deterministic order), 3 spill into the procedural pool. The W2 ticket coordinates the Main.tscn re-wire with Devon's camera-scroll bounds-clamp.

### Cross-zone transitions (ports between zones)

Zone-to-zone exit/entry mating uses the existing chunk-level port-mating discipline (per § "Why ports, not free-form transitions") with a thin zone-schema overlay:

1. **Source zone declares an `exit` anchor with `target_zone_id`.** Example: `s1_z1_outer_cloister`'s exit anchor sets `target_zone_id = &"s2_z1_sunken_entrance"`.
2. **Target zone's `entry` anchor accepts the source.** The assembler looks up `target_zone_id`, finds the target zone's `entry` anchor, and mates the source exit's port (direction + tag) to the target entry's port (opposite direction + matching tag) per existing chunk-level mating rules.
3. **Boss-defeat → terminal exit.** When `target_zone_id == &""` (empty), the exit is terminal — the assembler treats it as the flow that hands the player back to hub-town (per Stratum1BossRoom's existing `stratum_exit_unlocked` signal). The `boss_room` anchor's chunk handles the door-trigger; the `exit` anchor with empty `target_zone_id` is the descent ritual itself.
4. **Unresolved `target_zone_id` is a terminal exit (W2 transitional).** Until S2 zones land in W3, `s1_z1_outer_cloister`'s exit references a not-yet-authored zone (`s2_z1_sunken_entrance`). The assembler treats unresolved targets as terminal exits — the player falls back to hub-town on traversal. This is the documented W2 transitional behavior; W3 S2 zone authoring resolves it.

**Port-mating discipline preserved.** Cross-zone mating reuses the chunk-level port rules unchanged: opposite directions (north-edge ↔ south-edge), matching tags (`exit` ↔ `entry`), same tile coordinate after offset. Zone schema adds NO new port-mating semantics — it only adds the routing layer that says "this exit port leads to that zone's entry port." The R-PROCGEN.b risk (chunk-port mating gaps at procedural seams) per `risk-register.md` post-v1.1 is mitigated by this reuse: cross-zone seams are mated by the same code path that mates intra-zone seams, so a single port-mating fix lands at both.

**Save-schema implication (additive on v5):** cross-zone exit traversal persists the source zone's clear-state (which anchors visited, which procedural chunks the player entered) under the per-character key. The W2 procgen-spike sibling ticket's `world_seed` save-write is the entry point; this zone schema doesn't add new save fields directly — it adds the `zone_id` namespace that the W2 save-write organizes against.

## S2 zone roster (M3 Tier 3 W3, ticket `86c9y7ygj` Part A)

Stage 1 of the L-XL ticket — geographic shells only. Four S2 ZoneDef.tres files authored at `resources/level/zones/s2_z*.tres` declare zone identity (`zone_id` / `display_name` / `stratum_id = 2`); `anchors` + `procedural_slot_pool` are intentionally empty pending Part C (S2 chunk authoring) and Part D (S2 boss room). The shells exist so quest content (Part E) and any zone_id consumer can reference S2 zones by stable id before chunks land.

| zone_id | display_name | Role per stratum walkthrough |
|---|---|---|
| `s2_z1_entry_hall` | Entry Hall of the Archive | Descent-entry zone — first room the player sees crossing from S1. Mob density low; introduces S2 doctrine palette + ambient. |
| `s2_z2_reading_chamber` | Sunken Reading Chamber | Early-stratum exploration zone — first Sunken-Scholar (ranged) encounter. Anchors a S2 NPC slot (per post-wave3-sequencing.md §6 SI-5: 2 S2 NPCs). Low-pressure beat. |
| `s2_z3_archive_vault` | Archive Vault | Mid-stratum exploration zone — first Bone-Catalyst (melee) encounter alongside Sunken-Scholar. Pressure escalates; anchors a `quest_target` slot for a Track 3 exploration quest. |
| `s2_z4_inner_sanctum` | Inner Sanctum | Late-stratum / boss-approach zone — anchors the Archive Sentinel `boss_room` slot (Part D). High-pressure mixed-archetype roster in the procgen pool. Exit `target_zone_id` will reference S3 entry once S3 lands; terminal for M3 Tier 3. |

Sponsor-locked S2 names (2026-05-24): ranged mob = **Sunken-Scholar**, melee mob = **Bone-Catalyst**, boss = **Archive Sentinel**. Zone display_names thread the same library/archive aesthetic for narrative cohesion with the locked mob roster.

**Known follow-up — `s1_z1_outer_cloister` exit target drift.** The S1 zone's exit anchor declares `target_zone_id = &"s2_z1_sunken_entrance"` (per the M3 Tier 3 W1 spike — a name picked before Sponsor locked S2 mob/boss names on 2026-05-24). The S2 z1 shell authored here is `s2_z1_entry_hall`, not `s2_z1_sunken_entrance`. Per the cross-zone-transitions § above, an unresolved `target_zone_id` is treated as a terminal exit by the assembler — so this drift is currently inert (no broken mating). The cleanup is either (a) re-point `s1_z1_outer_cloister` exit to `s2_z1_entry_hall` or (b) rename `s2_z1_entry_hall` → `s2_z1_sunken_entrance`. Defer to Part C when the S2 chunks + entry-mating land; either fix is one-line.

**Stage 1 acceptance:** smoke tests (`tests/test_s2_zone_defs_load.gd`) pin load + field-read + universal-warning-gate compliance per `.claude/docs/test-conventions.md`. `validate()` is intentionally NOT called at Stage 1 — empty `anchors` would fail the entry/exit invariants; Part C ships the validate() pin once anchors are populated.

**TODO Part C** comments inside each .tres file mark where chunk anchors and procedural slot pools will populate. Per multi-stage-ticket-lifecycle memory, ticket `86c9y7ygj` stays at `in progress` across Parts B/C/D/E — flip `complete` only when ALL stages land.

## S2 mob roster (M3 Tier 3 W3, ticket `86c9y7ygj` Part B)

Stage 2 ships the first of two new S2 mob archetypes — **Sunken-Scholar** (ranged caster). The class file mechanically mirrors `scripts/mobs/Shooter.gd` (telegraph → fire → recovery kiter with sweet-spot band + cornered-fallback per ticket `86c9uehaq` doctrine) but differentiates per Uma's `palette-stratum-2.md` §5.5 character archetype:

| Lever | S1 Shooter | SunkenScholar (S2) | Why differentiate |
|---|---|---|---|
| `PROJECTILE_SPEED` | 90 px/s | 60 px/s | Uma §5.5: "slower bullet, longer telegraph, same effective TTK." |
| `PROJECTILE_LIFETIME` | 1.6 s | 2.4 s | Pairs with the slower speed — same 144 px effective reach, same sweet-spot width. |
| `SHOOT_RANGE` (derived) | 144 px | 144 px | Band invariant preserved — sweet spot 120..144 px in both. Per `combat-architecture.md` § "Shooter state machine — sweet-spot derivation rule." |
| `AIM_DURATION` | 0.55 s | 0.85 s | Uma §5.5 telegraph anchor — "lantern flares brighter, eyes ignite" — longer window pairs with brighter visual cue. |
| `CORNERED_AIM_DURATION` | 0.25 s | 0.30 s | Slightly longer than S1 to pair with the slower bullet (player still has dodge headroom). |
| `hp_base` | 40 | 50 | Compensation for slower projectile — player has more dodge opportunity per shot. Final balance lever is Sponsor soak. |
| `damage_base` | 5 | 6 | S2 archetype baseline (~ S1 × 1.15 — see `MobRegistry._STRATUM_SCALING`). Not yet auto-scaled at spawn; `apply_stratum_scaling` test pinned for the future wire-up. |
| Telegraph tint (placeholder ColorRect) | vivid red `#FF4D4D` | ember-amber `#FF8C4D` | Approximates Uma §5.5 "lantern-staff flare" until PixelLab sprite drops in. Sub-1.0 channels for HTML5 HDR-clamp safety. |
| Sprite-rest color (placeholder ColorRect) | blue `#5273C7` | parchment-tan `#A89270` | Uma §1.6 scholarly-overlay parchment hex — distinct from S1 Shooter blue at silhouette-distance. |

**Shared with S1 Shooter (cross-stratum constants per `palette-stratum-2.md` §2):**
- `HIT_FLASH_TINT = Color(1.0, 0.50, 0.50, 1.0)` — "I hit something" reads identically across the roster.
- Mob aggro eye-glow `#D24A3C` (when AnimatedSprite2D drops in — placeholder ColorRect doesn't yet expose this surface).
- Ember-light death-particle ramp (`#FF6A2A` → `#A02E08`) — diegetic logic per Uma §5.5: "lantern-light gutters out frame-by-frame — the ember IS the soul, leaving."

**Trace contract (Drew persona rule "No new mob class without trace instrumentation"):**
- `[combat-trace] SunkenScholar.pos | pos=(x,y) state=<S> hp=<N> dist_to_player=<D>` — throttled 0.25 s, mirrors `Shooter.pos`. Harness pursuit/observability surface.
- `[combat-trace] SunkenScholar._set_state | <old> -> <new> dist=<D> pos=(x,y)` — emits on every state transition.
- `[combat-trace] SunkenScholar.{take_damage, _die, _force_queue_free, _play_attack_telegraph, _promote_cornered_to_aiming, _process_aiming, _process_post_fire}` — uniform with the Shooter family. Harness greps map 1:1.

**Stage-2 ship state (placeholder sprite):**
- Sprite is a flat-color ColorRect (parchment-tan), 16×16 px centered. Hit-flash 3-branch resolver routes through the ColorRect branch (M3W-3 convention).
- PixelLab sprite generation deferred to a follow-up PR (Sponsor + orchestrator main-session executes `mcp__pixellab__*` per `sub-agent-mcp-tool-surface-scope` memory; SunkenScholar's PixelLab prompt seed is `palette-stratum-2.md` §5.5).
- Drop-in mechanic: replace the `Sprite` ColorRect node in `scenes/mobs/SunkenScholar.tscn` with an `AnimatedSprite2D` of the same name + assign `SpriteFrames`. Resolver branch 1 auto-picks it up — no script edit needed (M3W-1 PR #271 inheritance contract per `.claude/docs/combat-architecture.md` § "M3W-1 realized implementation").

**Out of scope for Stage 2 (deferred to later stages of `86c9y7ygj`):**
- Bone-Catalyst (melee, Stage 3) — separate class + scene + .tres + registry entry.
- Archive Sentinel boss (Stage 5) — distinct boss-room topology.
- S2 chunks consuming `&"sunken_scholar"` in `mob_spawns` (Stage 4 Part C).
- Stratum-scaling wired into spawn path (cross-cutting follow-up; `apply_stratum_scaling` API ready, no spawn-path wire-up yet).

**Paired tests:**
- `tests/test_sunken_scholar_mob_class.gd` — mob-class smoke (instantiation, state-machine boot, full path Idle→Spotted→Aiming→Firing, kite + cornered fallback, band invariants `SHOOT_RANGE = PROJECTILE_SPEED × PROJECTILE_LIFETIME`, differentiation pins vs S1 Shooter, no USER WARNING:).
- `tests/test_mob_registry_sunken_scholar_pin.gd` — roster registration pin (has_mob / get_mob_def / get_mob_scene / registered_ids / spawn / S2 stratum-scaling math).

### Stage 3 — Bone-Catalyst (melee bruiser)

Stage 3 ships the second of two new S2 mob archetypes — **Bone-Catalyst** (melee bruiser). The class file mechanically mirrors `scripts/mobs/Grunt.gd` (chase → telegraph → strike → recover) but differentiates per Uma's `palette-stratum-2.md` §5.5 Bone-Catalyst character archetype:

| Lever | S1 Grunt | BoneCatalyst (S2) | Why differentiate |
|---|---|---|---|
| Telegraph state name | `STATE_TELEGRAPHING_LIGHT` (raised-blade 1-frame tilt) | `STATE_CHANNELING` (stationary forearms-cross pose) | Uma §5.5: "the channel-wind-up double-forearm-cross IS the telegraph" — stationary pose vs Grunt's mid-motion raised blade. Reads as "gathering pressure," not "swinging." |
| Telegraph duration | `LIGHT_TELEGRAPH_DURATION = 0.40 s` | `CHANNEL_DURATION = 0.60 s` | Uma §5.5: "0.5-0.7 s windup window." Mid-band — long enough to dodge, short enough to avoid reading as "stunned." Pinned by `test_channel_duration_is_in_uma_spec_window`. |
| Strike-hitbox spec | reach=24 / radius=16 / lifetime=0.10 | reach=30 / radius=20 / lifetime=0.14 | Slam is the routine attack-shape (no heavy-telegraph fallback), so its hitbox is sized between Grunt LIGHT (24/16/0.10) and Grunt HEAVY (36/22/0.18). |
| Strike knockback | `LIGHT_KNOCKBACK = 120` | `SLAM_KNOCKBACK = 200` | The slam reads heavier visually — knockback matches. |
| Strike kind | `&"light"` | `&"slam"` | Single attack-shape (no separate light/heavy split). Bruiser doesn't shift gears. |
| Heavy-telegraph fallback | yes (`HEAVY_TELEGRAPH_HP_FRAC = 0.30`) | NO | Channel-windup IS the bruiser's primary read — adding a second low-HP telegraph would dilute the silhouette grammar. Drop the heavy slot. |
| `hp_base` | 50 | 70 | Compensation for longer windup — player has more dodge opportunity per attempt, so bruiser must eat more hits before going down. Final balance lever is Sponsor soak. |
| `damage_base` | 2 | 5 | Bruiser hits hard but tells you it's coming. Sponsor reads "I see the slam coming + got hit anyway" as legible, "I didn't see the swing" as unfair. |
| `move_speed` | 60 | 50 | Uma §5.5: "bruiser plodding gait." Slower approach reads as heavy mass. Pinned by `test_move_speed_is_slower_than_grunt`. |
| Telegraph tint (placeholder ColorRect) | vivid red `#FF4D4D` | warm bone-flare `#F2CC80` | Approximates Uma §5.5 "brass mask reads as the focal point of 'pressure gathering'" — warm bone-pale flare on placeholder until PixelLab sprite drops in. Sub-1.0 channels for HTML5 HDR-clamp safety. |
| Sprite-rest color (placeholder ColorRect) | (Grunt is AnimatedSprite2D) | bone-corroded brown-rust `Color(0.30, 0.18, 0.16, 1)` | Uma §5.5 "heat-corroded short tunic" — distinct from SunkenScholar's parchment-tan at silhouette-distance. Sub-1.0 channels HTML5-safe. |

**Shared with S1 Grunt + S2 SunkenScholar (cross-stratum constants per `palette-stratum-2.md` §2):**
- `HIT_FLASH_TINT = Color(1.0, 0.50, 0.50, 1.0)` — "I hit something" reads identically across the roster. Pinned by `test_hit_flash_tint_matches_cross_stratum_constant`.
- Ember-light death-particle ramp (`#FFB066` → `#A02E08`) — diegetic logic per Uma §5.5: "bone-fragments disperse via CPUParticles2D burst" via the unified ember ramp until PixelLab sprite-frames carry per-mob fragment visuals.

**Distinct from S1 Charger (third readable melee shape):**
- No `STATE_CHARGING` (BoneCatalyst is stationary during the windup; Charger dashes during it).
- No `get_charge_dir()` API, no `charge_telegraph_started` / `charge_hit_spawned` signals.
- Channel state is STATIONARY — velocity zero through CHANNEL_DURATION. Pinned by `test_no_charge_dash_unlike_charger`.

**Distinct from S1 Shooter / S2 SunkenScholar (no ranged-attack semantics):**
- No `STATE_AIMING` / `STATE_FIRING` / `STATE_POST_FIRE_RECOVERY` — pure melee.
- No `projectile_fired` signal, no `aim_started` signal — `channel_started` is the telegraph signal.
- No `SHOOT_RANGE` / `KITE_RANGE` band semantics — `SLAM_RANGE` triggers the channel at point-blank range. Pinned by `test_no_projectile_state_unlike_shooter_family`.

**Trace contract (Drew persona rule "No new mob class without trace instrumentation"):**
- `[combat-trace] BoneCatalyst.pos | pos=(x,y) state=<S> hp=<N> dist_to_player=<D>` — throttled 0.25 s, mirrors `Grunt.pos`. Harness pursuit/observability surface.
- `[combat-trace] BoneCatalyst._set_state | <old> -> <new> dist=<D> pos=(x,y)` — emits on every state transition.
- `[combat-trace] BoneCatalyst.{take_damage, _die, _force_queue_free, _play_attack_telegraph, _begin_channel}` — uniform with the Grunt family. Harness greps map 1:1.

**Stage-3 ship state (placeholder sprite):**
- Sprite is a flat-color ColorRect (bone-corroded brown-rust), 18×16 px (slightly wider than tall — bruiser silhouette per Uma §5.5 "stocky proportions"). Hit-flash 3-branch resolver routes through the ColorRect branch (M3W-3 convention). Pinned by `test_hit_flash_resolves_color_rect_branch_for_placeholder_sprite`.
- PixelLab sprite generation deferred to a follow-up PR (Sponsor + orchestrator main-session executes `mcp__pixellab__*` per `sub-agent-mcp-tool-surface-scope` memory; BoneCatalyst's PixelLab prompt seed is `palette-stratum-2.md` §5.5).
- Drop-in mechanic: replace the `Sprite` ColorRect node in `scenes/mobs/BoneCatalyst.tscn` with an `AnimatedSprite2D` of the same name + assign `SpriteFrames`. Resolver branch 1 auto-picks it up — no script edit needed (M3W-1 PR #271 inheritance contract per `.claude/docs/combat-architecture.md` § "M3W-1 realized implementation").

**Out of scope for Stage 3 (deferred to later stages of `86c9y7ygj`):**
- Archive Sentinel boss (Stage 5) — distinct boss-room topology + stationary-on-plinth shape.
- S2 chunks consuming `&"bone_catalyst"` in `mob_spawns` (Stage 4 Part C).
- Stratum-scaling wired into spawn path (`apply_stratum_scaling` API pinned via the registry test, no spawn-path wire-up yet — cross-cutting follow-up).
- BoneCatalyst-specific bone-fragment death-burst frames (visual layer is a future PixelLab-sprite-frame concern; placeholder uses unified ember ramp).

**Paired tests:**
- `tests/test_bone_catalyst_mob_class.gd` — mob-class smoke (instantiation, state-machine boot, chase → channel → strike → recover path, channel direction re-resolves at strike time, killed-mid-channel-no-slam, S1-melee-differentiation pins vs Grunt + Charger, channel-duration window pin per Uma §5.5, no USER WARNING:).
- `tests/test_mob_registry_bone_catalyst_pin.gd` — roster registration pin (has_mob / get_mob_def / get_mob_scene / registered_ids / spawn / S2 stratum-scaling math: 70 × 1.2 = 84 HP, 5 × 1.15 → 6 dmg).
