# M3 Tier 3 W1 procgen spike — Part A handoff (ticket `86c9xub9p`)

Branch: `drew/86c9xub9p-procgen-part-a`
HEAD SHA: `3601811` (rebased on `main` @ `37bc2ee` — was `72e1cd6` pre-rebase)
Part A author: Drew

## What Part A delivers

Three load-bearing scripts + one GUT suite, 1085 lines total.

### Files

| Path | Lines | Purpose |
|---|---|---|
| `scripts/levels/FloorAssembler.gd` | 387 | `assemble_floor(zone_def, seed, chunks_by_id={}) -> AssembledFloor` + static seed-derivation helpers (`derive_stratum_seed`, `derive_zone_seed`). Anchor placement in input order, procedural fill between consecutive anchors, port-mating sweep recording violations without raising (R-PROCGEN.b mitigation). |
| `resources/level/AssembledFloor.gd` | 116 | Typed output Resource — `zone_id`, `seed`, `placed_chunks: Array[PlacedChunk]`, `bounding_box_px: Rect2`, `port_mating_errors: Array[String]`. Convenience accessors (`is_empty`, `is_well_mated`, `chunk_count`, `anchor_count`, `procedural_count`). |
| `resources/level/PlacedChunk.gd` | 40 | Single placed-chunk record (`chunk_id`, `position_px`, `size_px`, `kind`, `anchor_room_id`). Top-level (not nested) so `Array[PlacedChunk]` works — Godot 4.3 GDScript rejects typed arrays of inner-class types. |
| `tests/test_floor_assembler.gd` | 542 | 18 GUT tests, NoWarningGuard wired. |

### GUT test names + line numbers

`tests/test_floor_assembler.gd`:

| Line | Test |
|---|---|
| 165 | `test_assemble_same_seed_yields_identical_placement` |
| 188 | `test_assemble_different_seeds_produce_different_placements` (N=8 seeds) |
| 218 | `test_slot_count_between_anchors_within_bounds` (N=8 seeds) |
| 244 | `test_zero_max_slots_produces_anchor_only_floor` |
| 277 | `test_anchors_placed_in_input_order_with_room_ids_preserved` |
| 300 | `test_bounding_box_spans_full_floor` |
| 316 | `test_chunks_laid_out_left_to_right_no_overlap` |
| 337 | `test_fixture_zone_has_zero_port_mating_errors` (N=8 seeds) |
| 349 | `test_port_mismatch_recorded_not_raised` |
| 382 | `test_null_zone_def_returns_empty_floor` |
| 393 | `test_invalid_zone_def_returns_empty_floor` |
| 407 | `test_unresolvable_chunk_id_returns_empty_floor` |
| 431 | `test_derive_stratum_seed_is_deterministic` |
| 445 | `test_derive_zone_seed_is_deterministic` |
| 461 | `test_assemble_authored_s1_z1_outer_cloister_round_trip` |
| 481 | `test_assemble_authored_s1_z1_same_seed_identical_across_runs` |
| 496 | `test_assemble_authored_s1_z1_records_s1_room01_east_seam_finding` (R-PROCGEN.b empirical) |
| 529 | `test_assemble_authored_s1_z1_boss_door_mates_cleanly` |

## Part A ticket spec verification

| Sub-bullet | Status | Evidence |
|---|---|---|
| `assemble_floor(zone_def, seed)` API | Y | `FloorAssembler.gd:135-139` — signature is `assemble_floor(zone_def: ZoneDef, seed: int, chunks_by_id: Dictionary = {}) -> AssembledFloor`. `chunks_by_id` is an optional test-override; production callers pass two args. |
| Seed-derivation cascade documented | Y | `FloorAssembler.gd:14-41` docstring spells out `stratum_seed = hash(world_seed, stratum_id)` / `zone_seed = hash(stratum_seed, zone_id)`. Statics `derive_stratum_seed` (line 233) + `derive_zone_seed` (line 244). |
| Port-mating discipline per `level-chunks.md` § "Why ports" | Y | `FloorAssembler.gd:63-81` docstring + `_check_port_mating` (line 360) + `_sweep_port_mating` (line 330). `OPEN_PORT_TAGS` set excludes `&"locked"` per `ChunkPort.gd` doc. Seam-row alignment enforced (line 370). |
| GUT pins cover deterministic seed + port mating | Y | Determinism: `test_assemble_same_seed_yields_identical_placement` (line 165) + `test_assemble_authored_s1_z1_same_seed_identical_across_runs` (line 481). Port mating: `test_fixture_zone_has_zero_port_mating_errors` (line 337, N=8) + `test_port_mismatch_recorded_not_raised` (line 349) + `test_assemble_authored_s1_z1_boss_door_mates_cleanly` (line 529). |

## R-PROCGEN.b empirical finding (Part A surfaces it)

`test_assemble_authored_s1_z1_records_s1_room01_east_seam_finding` (line 496) pins the empirical reality: the production `s1_room01.tres` declares only a WEST entry port (M1-era single-room intro), so its EAST seam is open and the assembler records exactly one mating error per assemble against the worked-example zone. The fix-shape (add an EAST `&"exit"` port at `position_tiles=(14, 4)` to `s1_room01.tres`) is documented in the test's docstring as actionable data for the W2 retrofit ticket. Part A does NOT fix this — the assembler records-not-raises so the visual proof scene (Devon Part C) can show the regression.

## Rebase

Was 1 commit ahead of `main @ abd1182` (PR #325). After fetch, `main` had advanced to `37bc2ee` (PR #326 — `chore(orch-hooks): maintain-docs Stop hook — skip silently on no-edit turns`, shell-only, no game-side impact). Rebased cleanly with no conflicts. Force-pushed `72e1cd6 -> 3601811` with `--force-with-lease`.

## GUT run status

**Did NOT run locally** — Godot CLI is not on PATH in the orchestrator/Drew worktree environment (no `godot`/`godot.exe` discoverable via `where godot` / typical install locations: `C:/Program Files/Godot`, `C:/Godot`, `C:/Tools/Godot`, `scoop`, `AppData/Local/Godot`). GUT verification will land via CI on PR-open (Devon's combined PR) — `tests/test_floor_assembler.gd` runs in the same headless-Godot CI lane as every other GUT test.

## Devon picks up Parts B/C/D here

| Part | Owner | Scope | Files Devon touches |
|---|---|---|---|
| **B** | Devon | Per-character `world_seed` save schema field. Roll on character creation; persist through `Save.gd`; expose via `Character` (or wherever Devon decides the seed canonically lives). | `scripts/save/Save.gd`, plus likely a new `scripts/character/Character.gd` field (or whatever the canonical home is — Devon's call). Tests: `tests/test_save.gd` migration pin + `tests/test_save_roundtrip.gd` round-trip pin. |
| **C** | Devon | `ProcgenSpikeScene.tscn` visual proof scene + `scripts/spike/ProcgenSpike.gd`. Wire up `assemble_floor` against the worked-example `s1_z1_outer_cloister.tres`; render the placed chunks; print the port-mating findings on screen. Mirror the spike-class pattern from PR #314 (`scenes/spike/CameraScrollSpike.tscn` + `tests/playwright/specs/camera-scroll-spike.spec.ts`). | `scenes/spike/ProcgenSpikeScene.tscn`, `scripts/spike/ProcgenSpike.gd`, `tests/playwright/specs/procgen-spike.spec.ts` (diag-build-gated activation race per `test-conventions.md` § "Spike-class specs"). |
| **D** | Devon | HTML5 release-build verification of the spike scene; SI-8 recommendation written into the combined PR body. | PR description + Self-Test Report comment on the combined PR. |

Devon's combined PR is the single PR for the whole spike per ticket Owner section — do NOT open a Part-A-only PR.

## Notes for Devon at hand-off

- All four files Part A added are typed-strict GDScript. The `Dictionary` typing pattern for `branches` / `chunks_by_id` is intentional (Godot 4.3 typed-Dict editor quirks per `dialogue-system.md` § Schema) — do NOT promote to `Dictionary[StringName, LevelChunkDef]`.
- The `chunks_by_id` Dict override on `assemble_floor` is a test-only injection point. Production callers (the spike scene Devon writes for Part C) pass two args; production resolves via `load()` against `DEFAULT_CHUNK_ROOT = "res://resources/level_chunks/"`.
- `AssembledFloor.bounding_box_px` is the field that should feed `CameraDirector.set_world_bounds(...)` in Part C — Devon may want to wire this in the spike scene's `_ready` so the camera-scroll spike API gets a real-content integration smoke.
- The Part A test suite includes 4 tests against the production `.tres` files (lines 461 / 481 / 496 / 529); these load via `load("res://resources/level/zones/s1_z1_outer_cloister.tres")` and exercise the full pipeline without any test-override. CI will catch any drift in the worked-example .tres.
- 1 known port-mating error is EXPECTED in the worked-example assembly (the `s1_room01` east seam). Tests pin this expectation. Do NOT fix it in this PR — that's the W2 S1-retrofit ticket.

## Branch URL

https://github.com/TSandvaer/RandomGame/tree/drew/86c9xub9p-procgen-part-a
