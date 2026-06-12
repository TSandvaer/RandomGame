# Procgen Pipeline — FloorAssembler runtime conventions

What this doc covers: the `FloorAssembler` runtime conventions introduced in the M3 Tier 3 W1 procgen spike (ticket `86c9xub9p`, PR #328 merged `5304b62` 2026-05-22). The **zone schema data shapes** (ZoneDef / ZoneAnchor / procedural_slot_pool) live in `team/drew-dev/level-chunks.md` § "Zone schema (M3 Tier 3 W1 spike)" — this doc covers the runtime API, seed-derivation mechanics, mating discipline, and spike-class workflow patterns that future agents need when extending or retrofitting the assembler.

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

**GUT pins:** `test_derive_stratum_seed_is_deterministic` + `test_derive_zone_seed_is_deterministic` in `tests/test_floor_assembler.gd`.

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

## Port-additivity invariance

**The invariant:** adding a new port to an existing chunk resource is non-breaking to all other chunks' mating contracts, provided the new port does not introduce a collision with existing mating — specifically, if no currently-assembled zone has a chunk placed to the right of the modified chunk that ALSO needs a matching WEST port at the same `position_tiles.y`. If no such collision exists, `_sweep_port_mating()` records zero new mating errors; the pre-existing error count can only decrease (the new port satisfies previously-unsatisfied EAST requirements).

**Why this holds.** The assembler's `_sweep_port_mating` sweep is pairwise — it checks consecutive `(left, right)` chunk pairs independently. Adding an EAST port to the left chunk of any pair can only satisfy or leave unchanged the left-side requirement; it cannot break a pair where the left chunk previously had no EAST requirement. The invariance follows from the pairwise-independence of the mating sweep.

**Pre-addition checklist (before adding a port to an existing chunk):**

1. `grep -r "<chunk_name>" resources/level/zones/` — enumerate every zone that references the chunk.
2. For each referencing zone, identify any chunk placed to the **right** (higher index) of the target chunk in the `anchor_chunks` or `procedural_slots` list.
3. Confirm the right-side chunk's WEST port set includes a `position_tiles.y` that matches your new EAST port. If it does: no collision, proceed. If it does not: the new EAST port will create a NEW mating error for that pair, counteracting any error you intended to clear.

**Implication for sprint planning:** port-add fixes and chunk-content overhauls are independently mergeable. Block port-adds on `is_well_mated()` test passage, not on full ZoneDef pool completeness.

**Scope note.** This invariant covers port *additions* only. Port *removals* and port *position_tiles changes* do NOT hold this invariant — they can break existing mating in any zone that relied on the removed/moved port. Port additions are the uniquely safe mutation class.

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

## S2 production consumer — `Main.gd` traversal driver (PR #391, merge `9a6b479`)

`FloorAssembler.assemble_floor` got its **first production consumer in the live play loop** as of PR #391 (2026-06-02). All prior consumers were spike scenes or tests. The call chain in `scenes/Main.gd`:

```
DescendScreen.restart_run signal
  → _on_descend_restart_run()
    → _begin_stratum_2()              # fires AudioDirector.play_stratum2_entry() here
      → _load_s2_zone(0)              # iterates zone_id in S2_ZONE_IDS (z1→z2→z3)
          FloorAssembler.assemble_floor(zone_def, zone_seed)
          _render_assembled_floor()
      → past last authored zone → _enter_s2_boss_room()   # terminal index 9 = s2_z4_inner_sanctum (ArchiveSentinel)
```

**Seed call site.** `_load_s2_zone` derives seeds via the standard cascade:
```gdscript
stratum_seed = FloorAssembler.derive_stratum_seed(_resolve_s2_world_seed(), S2_STRATUM_ID)  # S2_STRATUM_ID = 2
zone_seed    = FloorAssembler.derive_zone_seed(stratum_seed, zone_id)
```
`_resolve_s2_world_seed()` returns a **fixed deterministic `0`** today — no `world_seed` save surface exists yet (Commitment 5, randomized-maps-per-character, unimplemented). It is a one-line swap to `Save.get_world_seed()` when that ships; no assembler change needed. Until then every character gets structurally identical S2 layouts.

**Two OOS gaps are deliberate skeleton, NOT bugs.** Agents dispatched against "wire chunk-clear" or "populate mob spawns" should read `_render_assembled_floor` and `_advance_s2_zone` as the two extension points:

1. **`AssembledFloor.mob_spawns` has no runtime consumer.** `assemble_floor` populates it correctly, but `_render_assembled_floor` does not yet instantiate mobs from it — S2 zones render geometry shells and spawn zero enemies. Future wiring site: inside `_render_assembled_floor`.
2. **No chunk-clear gate — zones auto-advance on the next frame.** `_render_assembled_floor` arms `_on_s2_zone_advance_ready()` → `call_deferred("_advance_s2_zone")`. With no `_s2_chunks_remaining == 0` guard yet, descending whisks through z1→z2→z3 in ~3 frames straight to the boss. `_s2_chunks_remaining` is the designed future guard variable.

Net effect: S2 is a **reachable skeleton** — traversal flow is live and the boss room is reachable, but room-by-room progression and mob population are stubs. (Soak entry points + the `start_room`/`force_descend` param gotcha: `.claude/docs/html5-export.md`.)

## S1 production consumer — `_load_s1_zone` (PR #421, soak-gated additive path)

**As of PR #421 (ticket `86ca5errv`, 2026-06-07) S1 has an assembler consumer — but it is SOAK-GATED behind `?s1_assembler=1`; the DEFAULT S1 boot is still the static `ROOM_SCENE_PATHS` path (byte-identical to pre-#421).** The default cut-over is deferred to the downstream yard-content ticket (T4/T7) once multi-chunk yard content is authored.

| Stratum | Boot path | Assembler? |
|---|---|---|
| S1 default (rooms 1–8 + boss) | `_load_room_at_index(idx)` → `load(ROOM_SCENE_PATHS[idx])` (`Main.gd:64`,`:393`,`:691`) | No — static `.tscn` (unchanged) |
| **S1 with `?s1_assembler=1`** | `_load_s1_zone(zone_id)` → `assemble_floor` → render chunk geometry + mobs | **Yes — PR #421**, mirrors `_load_s2_zone` |
| S2 (zones z1→z2→z3) | `_begin_stratum_2` → `_load_s2_zone` → `assemble_floor` | Yes — first production consumer (section above) |
| S2 terminal (boss) | `_enter_s2_boss_room` → static `ROOM_SCENE_PATHS` load | No — authored scene terminal |

**Two non-obvious conventions PR #421 introduced (reusable for T4/T7 yard-content + any future stratum retrofit):**
1. **Soak-gated additive retrofit, NOT a hard swap.** The assembler path is added behind a `DebugFlags` gate (`?s1_assembler=1`) so the default game is untouched and the risky cut-over is decoupled from the plumbing. The flag path is **INERT in production** — a Sponsor VISUAL soak of it requires a diag-build, not the production artifact.
2. **`ASSEMBLED_FLOOR_INTENTIONAL_SKIP_MOB_IDS`** — `s1_room01.tres:22` declares a `practice_dummy` spawn that `MobRegistry` has no MobDef for (it lives on the authored onboarding surface, not the registry). The render path **silently** skips ids in this set so the universal-warning gate still fires `WarningBus.warn` on *genuine* unknown mob ids. Add new authored-but-unregistered spawn ids here, not by loosening the warning gate.
3. **Shared S2/S1 render helpers via `wire_combat` flag + container param** — `_load_s1_zone` reuses S2's render helpers; S2 behaviour is preserved byte-identical (`wire_combat=false` default, regression-verified). Extend the shared helper rather than forking per-stratum render code.

**Carried-forward OOS (same as S2):** `AssembledFloor.mob_spawns` partial-consume + no chunk-clear gate — these apply to the S1 path too; do not assume the gated S1 path is more complete than S2.

**Historical note (the gap PR #421 closed).** Before #421 only S2 consumed `assemble_floor`; S1 booted purely static. The W2-T3 data-layer ticket `86c9y1045` shipped the FloorAssembler S1 extension + ZoneDef + tests but NOT the `Main.gd` swap — a `[[product-vs-component-completeness]]` gap ("the assembler *can* assemble S1" ≠ "S1 *plays through* the assembler"). The `s1_room01.tres` EAST-port was already present on main (the PR #418 scoping note that it was missing was wrong — verified by Devon during #421). **Trap that remains:** `s1_z1_outer_cloister.tres` + `ROOM_INDEX_TO_ZONE_ID` exist for world-map bookkeeping + spike tests; the DEFAULT loop still calls `assemble_floor` for no S1 zone — only the `?s1_assembler=1` path does. Source: PR #421 (`86ca5errv`), PR #418 scoping.

## Debug-string ASCII-only discipline

Mating-error strings emitted by `_sweep_port_mating` use ASCII `<->` (three characters), NOT U+2194 `↔`. The `ProcgenSpikeScene` HUD surfaces these strings in a `Label` node, where U+2194 renders as a notdef tofu box in the Godot 4.3 HTML5 default font. Devon caught + fixed during M3 Tier 3 W1 self-soak (commit `e900222`). The full rule lives in `.claude/docs/html5-export.md` § "Default-font glyph coverage" — this doc only flags the convention for future agents extending the mating-error format.

## Godot autotile TERRAIN authoring — two engine gotchas (S1 ground, PR #426 v5)

The S1 yard ground (after the procedural→AI-tileset pivot) renders dirt↔grass blends via a Godot **TileSet TerrainSet** (corner/peering-bit Wang autotile) painted with `set_cells_terrain_connect`, on a dedicated `GroundTerrain` layer at `z=-1`. Two non-obvious Godot 4.3 gotchas surfaced wiring it:

- **A corner-Wang TerrainSet `.tres` MUST be built via the Godot API + `ResourceSaver.save`, NOT hand-written.** A hand-authored `.tres` **silently drops the per-tile peering bits** (terrain-mode vs `.tres` parse-order serialization quirk) → the autotiler then has no transition tiles and falls back to hard edges / wrong tiles. Build the terrain resource programmatically (see `tools/build_dirtgrass_terrain.gd`: set terrain set + per-tile peering bits via the TileData API, then `ResourceSaver.save`). Editing the generated `.tres` by hand afterwards re-drops the bits.
- **`set_cells_terrain_connect` commits on the NEXT frame in headless** — reading the painted cells back in the SAME frame returns 0/unpainted. GUT tests asserting autotile results must `await get_tree().process_frame` (or physics_frame) before reading. (Sibling to the `body_entered` / Area2D-monitoring next-frame rules in `combat-architecture.md`.)

**AI-tile prep pipeline (same PR):** the PixelLab dirt↔grass Wang set is doctrine-locked (`tools/mute_wang_grass.py` — HSV sat-crush + cliff-shadow neutralize to mute the neon-green skew toward `#5C7044`); the AI weathered-cobble lane (`create_map_object` 256px, see `pixellab-pipeline.md`) is made seam-free (`tools/seamless_cobble.py`, np.roll wrap) then packed into a 6-variant atlas (`tools/build_path_cobble_atlas.py`) so the lane never repeats a tile in a run.

## Sourced-tileset paintable authoring (Cainos, PR #432 — the level-design pivot)

After the AI/procedural ground was retired in favour of a SOURCED pro tileset + Sponsor-hand-authored levels (memory `level-design-pivot-godot-editor-sourced-tileset`, `art-direction.md` § "The FINAL pivot"), the same TerrainSet rules above apply to a sourced pack — plus three new conventions from standing up the Cainos "Pixel Art Top Down – Basic" workflow:

- **Building the terrain `.tres` from a SOURCED sheet → derive peering bits by corner-quadrant classification.** You can't hand-author the bits (same drop-on-hand-edit rule). For a sourced autotile sheet, classify each tile's four corner quadrants (e.g. sample the quadrant for the terrain's signature channel — Cainos stone-path edge vs grass) to assign the per-corner peering bits, then `ResourceSaver.save` (see `tools/build_cainos_tileset.gd` + `tools/_cainos_corner_map.md`). GUT pins the bit count (PR #432: 62 grass↔stone-path bits) as a bug-class guard.
- **Paintable authoring-scene pattern.** A Sponsor-facing design scene = TileMapLayers (one per terrain/material) + an instanced Player + a runtime follow-camera at `CameraDirector.BASELINE_ZOOM`, runnable on **F6** (Play Current Scene, NOT F5/Main.tscn). Sponsor paints terrain (autotile brush) + drops free-placed `Sprite2D` props, saves, F6 to see it live — no build/soak round-trip. See `scenes/levels/s1_yard_authored.tscn` + `team/drew-dev/s1-paint-guide.md`. Because the production build doesn't boot this scene, **capture it for QA via a diag-build that swaps `main_scene`** (same diag pattern as below) — a normal Playwright smoke can't reach an F6-only authoring scene (this is the "Playwright SHA-pin FAILURE = non-defect" cause on such PRs).
- **A terrain `.tres` is ENGINE-VERSION-SENSITIVE — rebuild it (via the builder) on every Godot bump, never hand-edit (Godot 4.3→4.6 migration, 86ca65gyv/86ca67aj0).** The corner peering-bit serialization differs across engine versions: a `cainos_s1.tres` built with the 4.3 TileData API had peering bits that were MALFORMED for 4.6's terrain system (errors + instability on load), even though the same builder run under 4.6 produces a clean resource. So treat generated `.tres` terrain resources as build artifacts pinned to an engine version — on an engine bump, re-run `tools/build_*_tileset.gd` under the new engine + commit the re-serialized output; do not carry the old `.tres` forward or hand-patch it. Corollary 4.6 gotcha: reading a corner peering bit on a tile whose `terrain_set == -1` raises `is_valid_terrain_peering_bit` — guard notch/empty cells (don't classify them into the terrain). (A separate, still-under-investigation 4.6 hazard — instantiating a TileMapLayer corner-terrain scene inside the FULL GUT suite's accumulated state SIGSEGVs despite being clean standalone + in-game — is tracked in engine follow-up `86ca68b0u`; characterize it there before documenting a fix.)
- **Black-square / black-mark artifact = project clear-color (or a near-black opaque element) showing where transparency was expected.** Recurred twice on S1 ground: (1) a spring `ColorRect` left at **alpha 1.0** (opaque near-black `#2E2A26`) read as a ~50px black box (fix: drop alpha to ~0.42 so the ground shows through); (2) the project **clear-color `(15,13,20)` bleeding through a ~10px transparent NOTCH** in two grass autotile cells the autotiler picked for fill (fix: `TERRAIN_EXCLUDE` those holey cells so fill stays on clean opaque rows). **Diagnose this class first** (look for opaque/near-black nodes at full alpha + transparent gaps in tiles used as autotile fill) before suspecting a sprite-render failure — a `[prop-trace]` of building-render-state (modulate/visible/texture-loaded/size) discriminates "stray clear-color artifact" from "a real building rendered wrong".

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
