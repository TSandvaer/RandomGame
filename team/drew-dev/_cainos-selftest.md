## Self-Test Report — paintable Cainos S1 setup (PR #432, ticket 86ca64xzb)

Visual/level PR → Self-Test Report + in-game (release-build) visual verification.

### What was tested

| Surface | Method | Result |
|---|---|---|
| TileSet built correctly (peering bits present) | GUT `tests/test_cainos_tileset.gd` (15 pins) | **15/15 PASS** (Godot 4.3.stable.official.77dcf97d8) |
| TileSet built via API not hand-written | `tools/build_cainos_tileset.gd` ran clean: `wrote cainos_s1.tres (sources=6 terrains=2)` | PASS — 62 peering bits = terrain 1 serialized |
| Scene opens + runs (headless) | `godot --headless ... s1_yard_authored.tscn` → `[S1YardAuthored] ready ... zoom=(2.6667, 2.6667)`, no script/null errors | PASS |
| **In-game render (live HTML5 build)** | Playwright `cainos-authoring-scene-soak.spec.ts` against the **diag artifact** | **PASS — Cainos tiles render** |
| Headless import + GUT (CI) | feature-branch CI | **SUCCESS** |
| Export HTML5 (CI) | feature-branch CI | **SUCCESS** |

### In-game visual evidence (the FINAL-pivot gate — running game, not an offline tool)

Captured from the live HTML5 build via Playwright (`art-direction.md` FINAL-pivot:
"verify against the running game, not a proxy that can diverge"). Diag build:
`diag/cainos-authored-soak` @ SHA `99186c7` (release run 27162690259), main_scene
swapped to `s1_yard_authored.tscn`.

- `team/drew-dev/_cainos-shots/cainos-authoring-spawn.png` — spawn view: olive
  Cainos grass field with scattered detail + a cobble stone-path strip (blended
  grass↔path edges via the autotile terrain) + the monk Player on the path.
- `team/drew-dev/_cainos-shots/cainos-authoring-walked.png` — after WASD: camera
  scrolls, more painted ground visible. The black band below is UNPAINTED area
  (the starter patch is 20×14 cells) — expected; Sponsor paints the full yard.

Console confirmed live: `[S1YardAuthored] ready`, `CameraDirector.state
zoom=2.6667`, `Player.pos ... state=walk`, NO `Can't change this state while
flushing queries`, NO `SCRIPT ERROR`.

### Regression guard

- `main_scene` UNCHANGED on the feature branch (`res://scenes/Main.tscn`) — default
  game boot byte-identical. Only the throwaway `diag/cainos-authored-soak` branch
  swaps it (never merged; delete after this lands).
- No combat/mob/player/RoomGate code touched. New scene reuses existing
  `Player.tscn` + the standard `TileMapLayer` convention from the chunk scenes.
- GUT pin `test_path_fill_cell_has_all_path_corners` + `test_some_transition_tiles_exist`
  guard the peering-bits-drop bug class — a future hand-edit of the `.tres` that
  loses the bits goes red before merge.

### Cross-lane integration check

- `[combat-trace]` contract: untouched (no edits to scripts/mobs, scripts/combat,
  Player.gd). The diag soak confirms the live trace stream still emits
  `Player.pos` / `Player.coll_diag` / `CameraDirector.state` normally.
- Player iframes / Damage constants: untouched.
- RoomGate signal chain: untouched.
- Adjacent specs probed: none consume the new scene/tileset (additive). The
  production `Main.tscn` path is unaffected.

### Known CI note (not a regression)

The "Playwright E2E — HTML5 artifact smoke" check on the PR initially failed at the
**"Resolve artifact run ID + expected SHA"** step — the W3-T11 SHA-pin contract
(memory `Playwright artifact SHA-pin contract`) requires a release-build artifact
matching the PR HEAD SHA, which didn't exist yet. A release-build was then triggered
on the feature SHA `137e323` (run 27162955901) so the SHA-pinned Playwright can
resolve. The meaningful gates (GUT + import + HTML5 export) are green. This is the
standard "no same-SHA release artifact yet" behavior, not a code defect.

### Honest disclosure / probe targets for QA

- The autotile blend works (solid path body + blended edges) but is not pixel-
  perfect feathered — the grass sheet's own scattered loose-stone field variants
  appear in the grass (Cainos art, not a bug). If Sponsor wants tighter blends,
  tune `PATH_CORNERS` in the builder + re-run (do NOT hand-edit the `.tres`).
- Prop path: the 5 carried-forward props live at `assets/props/s1_cloister/`, not
  the ticket's `assets/props/s1_yard/` (which doesn't exist on main). Flag if a
  dedicated building set is expected.
- QA gate (Tess): does `s1_yard_authored.tscn` open in the editor, paint with the
  terrain brush (grass↔stone_path blend), accept copied props, save, and run (F6)?
  Is `s1-paint-guide.md` followable by someone new to the Godot editor?
