# Procgen Pipeline — FloorAssembler runtime conventions

What this doc covers: the `FloorAssembler` runtime conventions introduced in the M3 Tier 3 W1 procgen spike (ticket `86c9xub9p`, pending PR #328 merge). The **zone schema data shapes** (ZoneDef / ZoneAnchor / procedural_slot_pool) live in `team/drew-dev/level-chunks.md` § "Zone schema (M3 Tier 3 W1 spike)" — this doc covers the runtime API, seed-derivation mechanics, mating discipline, and spike-class workflow patterns that future agents need when extending or retrofitting the assembler.

> **Status:** all file paths and line references below cite the unmerged branch `drew/86c9xub9p-procgen-part-a` (Part A) / `devon/86c9xub9p-procgen-part-bcd` (Parts B/C/D) — verify against `main` HEAD after PR #328 merges; update this status line on merge.

## Seed-cascade contract

The Diablo-shape directive (memory `m3-diablo-shape-directive`) requires: same character + same zone → identical layout; different characters → meaningfully different layouts. The cascade is two-layer, derived via Godot's built-in `hash()` against `Array` tuples:

```gdscript
stratum_seed = FloorAssembler.derive_stratum_seed(world_seed, stratum_id)
# impl: return hash([world_seed, stratum_id])

zone_seed = FloorAssembler.derive_zone_seed(stratum_seed, zone_id)
# impl: return hash([stratum_seed, String(zone_id)])
```

`assemble_floor(zone_def, seed)` takes the **zone-level derived seed directly** — callers chain the two statics before calling. The assembler never sees `world_seed` itself; this scoping means re-rolling one zone's seed (e.g. a save-migration backfill with `world_seed = 0`) produces a predictable layout without corrupting other zones.

**Why two layers, not one big hash:** the stratum layer anchors cross-zone consistency — all S1 zones share an entropy space disjoint from S2's even when zone IDs collide numerically. A single `hash(world_seed, stratum, zone)` would re-roll every zone whenever stratum count changes; the two-layer design lets stratum-level adjustments (adding a stratum, rebalancing zone count) leave sibling subtrees stable. Per-zone derivation makes `assemble_floor` a pure function of `(zone_def, seed)` — same inputs always produce same output, which IS the same-layout verification (and the test strategy).

**GUT pins** (pending PR #328): `test_derive_stratum_seed_is_deterministic` + `test_derive_zone_seed_is_deterministic` in `tests/test_floor_assembler.gd`.

**Save-schema binding:** `Character.world_seed` is rolled on creation and round-trips through `Save.gd` (additive on v5 per `team/devon-dev/save-schema-v5-plan.md`). The stratum/zone derivation from `world_seed` is the caller's responsibility — `FloorAssembler` is seed-consumer only.

**Source:** docstring at `scripts/levels/FloorAssembler.gd` lines 14–41; statics at `derive_stratum_seed` line 233 + `derive_zone_seed` line 244.

## Port-mating: record-not-raise convention

`FloorAssembler._sweep_port_mating()` records mating violations to `AssembledFloor.port_mating_errors: Array[String]` and returns normally — it **never calls `push_error`** on a mismatch. This is a deliberate spike design: R-PROCGEN.b evidence collection requires the assembler to produce an `AssembledFloor` even when the anchor-↔-procedural seam is broken, so the `ProcgenSpikeScene` visual proof can render the regression on screen.

Each consecutive `(left, right)` placed-chunk pair must satisfy:

- Left chunk has ≥1 open EAST port (`tag` in `OPEN_PORT_TAGS`, which excludes `&"locked"`).
- Right chunk has ≥1 open WEST port with a tag in the same set.
- At least one EAST/WEST pair shares `position_tiles.y` (same seam row).

**Downstream contract:** callers check `AssembledFloor.is_well_mated()` and decide whether to render. In spike context the scene renders regardless (proof-first). The W2 retrofit ticket treats a non-empty `port_mating_errors` list as a hard fail and will block merge until production chunks have full EAST/WEST coverage.

**Known spike-era finding:** `s1_room01.tres` (M1-era single-room intro) declares only a WEST entry port; its EAST seam is open. The worked-example assembly (`s1_z1_outer_cloister.tres`) therefore always produces exactly **one** mating error when `s1_room01` appears at a non-terminal position. Test `test_assemble_authored_s1_z1_records_s1_room01_east_seam_finding` (`tests/test_floor_assembler.gd` line 496) pins this expectation. Fix shape: add EAST `&"exit"` port at `position_tiles=(14, 4)` to `s1_room01.tres` — this is the W2 S1-retrofit ticket; do NOT fix in the spike PR.

**Source:** `scripts/levels/FloorAssembler.gd` lines 63–81 (docstring), `_sweep_port_mating` line 330, `_check_port_mating` line 360.

## AssembledFloor output shape

`resources/level/AssembledFloor.gd` is the typed output Resource. Five load-bearing fields:

| Field | Type | Purpose |
|---|---|---|
| `zone_id` | `StringName` | Source zone (stable save/quest/map-UI key) |
| `seed` | `int` | Zone-level derived seed (stored for debug + same-seed re-assembly) |
| `placed_chunks` | `Array[PlacedChunk]` | Ordered left→right; index 0 = leftmost in world space |
| `bounding_box_px` | `Rect2` | Full floor extent in pixels; fed to `CameraDirector.set_world_bounds(...)` per `.claude/docs/camera-scroll.md` |
| `port_mating_errors` | `Array[String]` | Non-empty iff a mating violation was recorded |

Convenience accessors: `is_empty()`, `is_well_mated()`, `chunk_count()`, `anchor_count()`, `procedural_count()`.

**`PlacedChunk` is top-level** (`resources/level/PlacedChunk.gd`) — NOT a nested inner class of `FloorAssembler`. Godot 4.3 GDScript rejects `Array[InnerClass]` typed fields. Keep it as a top-level named resource; do not nest it.

**`bounding_box_px → CameraDirector` integration** is the downstream consumer introduced in PR #314 (camera-scroll spike, `set_world_bounds`). The procgen spike scene wires this in `_ready` as a smoke integration test. Full camera-scroll API in `.claude/docs/camera-scroll.md`.

## Debug-string ASCII-only discipline

Mating-error strings emitted by `_sweep_port_mating` use ASCII `<->` (three characters), NOT U+2194 `↔`. The `ProcgenSpikeScene` HUD surfaces these strings in a `Label` node, where U+2194 renders as a notdef tofu box in the Godot 4.3 HTML5 default font. Devon caught + fixed during M3 Tier 3 W1 self-soak (commit `e900222`). The full rule lives in `.claude/docs/html5-export.md` § "Default-font glyph coverage" — this doc only flags the convention for future agents extending the mating-error format.

## Diag-build spike workflow

Devon used a `diag/procgen-spike-soak` branch for fast HTML5 self-soak iteration during the W1 spike. This parallels the diagnostic-build pattern (memory `diagnostic-build-pattern`) but is spike-specific: the diag branch activates `ProcgenSpikeScene.tscn` as the launch scene so Sponsor or QA can verify the assembled floor visually without navigating the main game. **Disposal:** never merge; delete from origin after the W2 retrofit ticket ships the spike into the production room-driver. See `.claude/docs/test-conventions.md` § "Spike-class specs" for the Playwright activation-race rule (diag-build-gated spec pattern from PR #314).

## Coordination — level-chunks.md

This doc references chunk-schema terms (`ZoneDef`, `LevelChunkDef`, `ChunkPort`, `ZoneAnchor`, port tags, `&"locked"`) without defining them — `team/drew-dev/level-chunks.md` is the authoritative schema. **Coordination cost:** when W2 begins, the orchestrator should prompt Drew to promote a § "Assembler runtime" subsection to `level-chunks.md` cross-linking to this doc (or vice versa). Until then, sub-agents working on procgen should read both `team/drew-dev/level-chunks.md` AND this doc. Do NOT duplicate chunk-schema definitions here — this doc covers runtime assembler behavior only.

## Cross-references

- `scripts/levels/FloorAssembler.gd` — producer; docstring is the deepest reference for seed derivation + port-mating internals
- `resources/level/AssembledFloor.gd` — output Resource type
- `resources/level/PlacedChunk.gd` — single-chunk record
- `tests/test_floor_assembler.gd` — 18 GUT pins (determinism, slot-count bounds, port mating, error-recording)
- `tests/test_world_seed_persists_across_save_load.gd` — Part B save-round-trip pin
- `scenes/spike/ProcgenSpikeScene.tscn` + `scripts/spike/ProcgenSpike.gd` — Part C proof scene
- `tests/playwright/specs/procgen-spike.spec.ts` — paired Playwright spec
- `team/drew-dev/level-chunks.md` — chunk-schema source (`LevelChunkDef`, `ChunkPort`, port direction/tag semantics, `ZoneDef`)
- `team/devon-dev/_pr-procgen-part-a-handoff.md` — Drew's enumeration of Part A surface + Devon's file-touch matrix
- `.claude/docs/camera-scroll.md` — `bounding_box_px → set_world_bounds` consumer
- `.claude/docs/html5-export.md` § "Default-font glyph coverage" — ASCII discipline rule
