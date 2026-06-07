## S1 → FloorAssembler retrofit (keystone) — ticket `86ca5errv`

Wires Stratum-1's live play loop onto `FloorAssembler` — today only **S2** consumes it in production (`_load_s2_zone`, PR #391). This is the open `product-vs-component-completeness` gap Priya's scope §2 flagged: the W2-T3 data layer (`s1_z1_outer_cloister.tres` + the FloorAssembler runtime) shipped, but S1's `Main.gd` was never swapped onto it — S1 still booted via static `ROOM_SCENE_PATHS`.

**Roadmap framing (per Sponsor 2026-06-07):** the cloister-yard is STEP ONE of a larger journey-out-into-the-world arc (landscapes / villages / dungeons / caves). This assembler + continuous-scroll path IS the structural foundation that larger world needs — built endless-capable from the start (multi-chunk `bounding_box_px` → continuous-scroll bounds), not as a bounded yard we'd have to re-architect. This PR is the foundation + a minimal proof; full multi-chunk YARD content authoring is a separate downstream Drew ticket (Priya scope §3 T4/T7).

### What changed

- **`scenes/Main.gd`** — new `_load_s1_zone(zone_id)` mirroring `_load_s2_zone`: derives the seed via the standard cascade (`derive_stratum_seed` → `derive_zone_seed` off `_resolve_s1_world_seed()`), calls `assemble_floor`, renders chunk geometry + spawns chunk mobs into a fresh `S1FloorContainer`, re-parents the player to the floor spawn, and engages the continuous-scroll camera against `assembled.bounding_box_px` via the shared `_engage_camera_for_assembled_floor` helper — **replacing the hardcoded `S1_ROOM_BOUNDS`** (the keystone camera swap).
- **Shared-helper refactor** — `_instantiate_chunks` / `_spawn_assembled_floor_mobs` / `_spawn_one_chunk_mob` now take a `container` param (+ an opt-in `wire_combat` flag). S2 callers pass the prior behaviour (`wire_combat=false`, counter-only); S1 enables XP/loot parity (`wire_combat=true`). S2 behaviour is byte-identical — verified by the S2 regression suite below.
- **`scripts/debug/DebugFlags.gd`** — `?s1_assembler=1` soak flag (same HTML5-only-via-bridge truthy shape as `force_descend`) + `set_s1_assembler_for_test` / `reset_s1_assembler_for_test` + boot-line surfacing.
- **Soak-gated, not a hard swap.** Default boot stays on the static rooms; the assembler path activates only via `?s1_assembler=1` or `load_s1_zone_for_test()`. This mirrors how S2 traversal was ADDED as a new path (PR #391) rather than by deleting room loads — a hard swap would break the Room01 onboarding pickup gate, RoomGate clears, boss reachability, and ~dozens of Playwright specs. Cut-over of the default boot is the downstream content ticket.

### Dependency resolutions (the brief's flagged risks)

- **`s1_room01` missing-EAST-port** — ALREADY resolved on `main`: `s1_room01.tres` carries the EAST `&"exit"` port at `position_tiles=(14,4)`. The zone assembles clean-mated across seeds (pinned by `test_floor_assembler.gd::test_s1_z1_clean_mating_across_8_seeds`). No change needed.
- **`s1_z1_outer_cloister.tres` preload→null trap** (`test-conventions.md`) — both new test files route through runtime `load(...)`, never `preload`, for that resource.
- **`practice_dummy` known-skip** — empirically discovered via local GUT (trace-first): the `s1_room01` chunk declares a `practice_dummy` spawn, but `MobRegistry` registers only grunt/charger/shooter (there is no `practice_dummy` MobDef; the dummy lives on the authored `Stratum1Room01._spawn_mob` onboarding surface with custom iron_sword wiring per `combat-architecture.md`). The assembled floor is a traversal surface, not the onboarding surface, so the dummy is an **intentional known-skip** (`ASSEMBLED_FLOOR_INTENTIONAL_SKIP_MOB_IDS`) — silent, so the universal-warning gate still catches GENUINE unknown-id regressions. Carried forward consciously, not silently regressed.

### OOS gaps carried forward consciously (parity with S2)

1. **No in-zone chunk-clear progression gate.** S1 is a single assembled floor — there's nothing to advance TO within the zone (the descent terminus is the StratumExit, unchanged). The `_s1_mobs_remaining` counter + `_on_s1_mob_died` exist for parity + a forward-compat clear gate a downstream yard-content ticket will consume.
2. **Chunk geometry is the placeholder `s1_room01_chunk.tscn` shell.** Full multi-chunk YARD content (cobble+moss+dirt floor, buildings-as-structures, sparse decoration) is the downstream Drew authoring ticket. The retrofit renders whatever the chunk defs declare.

(These mirror the two documented S2 OOS gaps — `procgen-pipeline.md` § "S2 production consumer".)

### PR #216 process gates

- **Regression guard:** `test_main_s1_assembler_retrofit.gd::test_s1_load_zone_consumes_floor_assembler` + `::test_s1_render_engages_camera_for_assembled_floor` catch a refactor that drops the S1 assembler path or the `bounding_box_px → camera` swap. `::test_default_boot_does_not_activate_s1_assembler_floor` catches an accidental hard-swap of the default boot.
- **Cross-lane integration check (adjacent surfaces):**
  - **S2 traversal / mob-spawns** (shared-helper refactor blast radius) — `test_main_s2_traversal.gd` + `test_main_s2_mob_spawns.gd`: **green** (S2 behaviour byte-identical, wire_combat=false preserves counter-only).
  - **Camera** — `test_main_camera_wiring.gd`: **green** (S1 static-room camera path untouched; new S1-floor path uses the existing `_engage_camera_for_assembled_floor`).
  - **FloorAssembler** — `test_floor_assembler.gd`: 49 green + 1 pre-existing risky (`test_assemble_authored_s1_z1_boss_door_mates_cleanly` — file untouched by this PR; baseline quirk).
  - **M1 play loop** (static-room boot) — `tests/integration/test_m1_play_loop.gd`: 16 green (production boot undisturbed).
  - **DebugFlags** — `test_cam_zoom_debug.gd`: green; boot line correctly shows `s1_assembler=false` by default.

### Local GUT evidence (run on Godot 4.3.0 + GUT 9.3.0, `/c/Tools/Godot-4.3/godot --headless`)

- New paired tests: `test_main_s1_assembler_retrofit.gd` + `test_s1_assembled_floor_navigability.gd` → **10/10 passing**, 253 asserts.
- Regression set (S2 traversal + S2 mob-spawns + camera wiring + floor assembler): **49 passing / 1 pre-existing risky**, 351 asserts.
- M1 play loop integration: **16/16 passing**.
- gdformat: all 4 files clean. gdlint: new test files clean (0 findings); `scenes/Main.gd` + `scripts/debug/DebugFlags.gd` at their pre-existing baseline finding counts (no NEW findings introduced; CI lint is warnings-only + `scenes/` is not CI-linted anyway).

---

## Self-Test Report

**AC walkthrough** (foundation + minimal proof scope):

| AC | Observed |
|---|---|
| Swap S1 boot to a `_load_s1_zone` path mirroring `_load_s2_zone` | DONE — `_load_s1_zone` derives the seed cascade, calls `assemble_floor`, renders + spawns. GUT `test_s1_load_zone_consumes_floor_assembler` green. |
| Feed `bounding_box_px` to the camera (replace `S1_ROOM_BOUNDS`) | DONE — `_render_assembled_s1_floor` → `_engage_camera_for_assembled_floor(assembled)` → `set_world_bounds(assembled.bounding_box_px)`. GUT `test_load_s1_zone_sets_camera_bounds_from_assembled_floor` asserts the live `CameraDirector.get_world_bounds().size.x` is WIDER than `S1_ROOM_BOUNDS` (the scroll-enabling swap). Green. |
| Prove the path boots cleanly with the existing ZoneDef | DONE — `test_load_s1_zone_renders_assembled_floor_clean`: floor activates, authored chunk mobs spawn (`s1_mobs_remaining() > 0`), zero `USER WARNING` via NoWarningGuard (clean mating + clean mob resolution end-to-end through Main). |
| Resolve / flag the s1_room01 missing-EAST-port dependency | RESOLVED on main already (EAST exit port present); clean-mated across seeds. |
| Carry the two S2 OOS gaps forward consciously | DONE — documented above + in the `_s1_*` state docstring; not silently regressed. |
| Paired GUT tests (determinism + bounds + grunt-radius BFS navigability) | DONE — determinism/bounds at assembler layer (existing `test_floor_assembler.gd`); integration determinism + bounds (new `test_main_s1_assembler_retrofit.gd`); grunt-radius-expanded BFS (`test_s1_assembled_floor_navigability.gd`). |

**Side-effect inventory** (surfaces this change CAN fire on):
- `Main._ready` boot (only when `?s1_assembler=1` — default off → no production fire).
- The shared assembled-floor helpers (S1 + S2 both route through them) — S2 behaviour preserved via `wire_combat` default + container param.
- `CameraDirector.set_world_bounds` (S1-floor path only; static-room path unchanged).
- `WarningBus` (S1 mob-spawn unknown-id path — now skips known-intentional ids silently).
- `Player.mark_zone_discovered` (`_record_discovered_zone` on S1 zone load — composes with the W2-T5 save round-trip; idempotent).

**HTML5 visual-verification gate — escape clause invoked (author cannot launch interactive Chromium in this CLI environment).** This PR touches Area2D-state (chunk-mob spawns) + the camera world-bounds path → it is **gated**. The new visual surface is the assembler-driven S1 floor scrolling under continuous-scroll camera. **Sponsor-soak probe targets** (route the diag-build artifact, NOT the production artifact — the path is INERT in production until `?s1_assembler=1` is set):
1. Boot `?s1_assembler=1` → confirm the floor renders MANY chunk-widths wide (not a single 480-px screen) and the camera SCROLLS as the player walks east (the "big" read) — vs the static-room hold-at-center.
2. Confirm `[combat-trace] Main.load_s1_zone | zone_id=s1_z1_outer_cloister ... bounds=...` fires in DevTools with a `bounds` width well over 480.
3. Confirm chunk mobs (grunts/chargers/shooters) spawn + aggro across the wide floor; confirm NO `USER WARNING: ... unknown mob_id` (the practice_dummy skip is silent).
4. Confirm the camera clamps cleanly at the floor's left/right edges (no scroll past authored content).

Per `html5-export.md` § "Diagnostic-build pattern": a `diag/s1-assembler-soak` branch swapping `?s1_assembler` default-on (or `project.godot` main_scene) gives Sponsor a one-load soak. The structural + behavioural GUT tests + headless camera-bounds assertion are the mechanical gate; Sponsor interactive soak is the visual gate of record.
