## Self-Test Report (v5 AUTOTILE-TERRAIN + AI-COBBLE LANE) — S1-YARD (PR #426)

Continues HELD PR #426 — no new PR. Sponsor-approved new ground pipeline (2026-06-08): the
procedural dirt/grass ground is RETIRED ("looks like crap", 7 bounces) → **AI-gen Wang
transition tilesets + Godot autotile** for the dirt↔grass blend, + the **Sponsor-approved AI
weathered-cobble for the LANE**. Verified IN-GAME via the GPU SubViewport render (the gate of
record — the offline render tool LIED last round; this is the real Godot renderer).

### What shipped (the architecture)
1. **Dirt↔grass = Godot TileSet TerrainSet (corner-match Wang autotile).** New
   `resources/tilesets/s1_dirtgrass_terrain.tres` (built via `tools/build_dirtgrass_terrain.gd`
   from the approved Set-A `wang_dirtgrass_meta.json` corner data). Painted on a new
   `GroundTerrain` TileMapLayer (z=-1) via `set_cells_terrain_connect` — Godot auto-selects the
   soft blended corner tile wherever dirt meets grass. Replaces the v4 hash-dither full-bleed
   fields. **Grass doctrine-locked** toward the muted S1 moss family by `tools/mute_wang_grass.py`
   (hue 123°→96°, sat 0.97→0.52 — no more neon; dirt left warm/untouched) + a cliff-shadow
   neutralize pass (the maroon raised-grass cliff edge → warm flat dirt-shadow, so the blend
   reads FLAT not as a plateau drop).
2. **Cobble LANE = Sponsor-approved AI weathered cobble.** `floor_cobble_ai.png` (256² grey-tan
   cobble + moss grout) seamless-ized via `tools/seamless_cobble.py` (textbook edge-wrap blend),
   packed into the 6-variant `floor_path.png` via `tools/build_path_cobble_atlas.py` so the
   existing lane painter is unchanged. Lane renders OVER the terrain base (z=0 > z=-1) = path
   through the ground. NOT the weak green-skewed Wang cobble (rejected in orch gen review).
3. **#426 wins KEPT:** mob 1.265× (grunt NIT 0.552→0.607 folded), well 0.35, char_scale,
   AC9 one-visible-class-per-cell (lane erases apron beneath; terrain base untouched).

### THE IN-GAME GATE (verification of record) — does the GAME read like the refs now?
**YES.** GPU SubViewport render (real Godot renderer, not the offline tool):
`_yard_render/ingame_terrain.png` (full yard) + `_yard_render/ingame_terrain_nw_blend.png`
(corner blend close-up) + `_yard_render/ingame_terrain_lane_east.png` (AI cobble lane).
Self-judge HARD vs `inspiration/2026-06-08_11h18_12.png` (Graveyard Keeper) + `11h19_36`
(Stardew):
- **Soft dirt↔grass blends?** YES — autotile selects the ragged-edge Wang tiles; grass reclaims
  the 4 corners as SOLID muted-olive blocks with one soft feathered rim (matches GK/Stardew
  "grass reclaims the corner"). NOT the v4 hard-dither scatter.
- **Legible cobble lane?** YES — the AI weathered cobble reads as a distinct grey stone path
  threading the warm dirt west→east; fine dense stones (not huge), lighter than the dirt
  (lum 107 vs 84 — the wayfinding contrast holds).
- **Muted not-neon grass?** YES — olive-mossy, sat crushed from 0.97→~0.5.
- **No hard edges?** YES — autotile blend + feathered lane rim; the maroon-cliff artifact was
  caught in-game (first render) + fixed (neutralize pass) — exactly the "verify in-game" gate
  working.
- **No black-square artifact?** YES — 21 near-black px of 518k (prop AA only).

(First in-game render exposed two real misses the OFFLINE atlas hid: a maroon raised-grass
cliff edge + grass fragmentation from thin regions. Both fixed: cliff-neutralize pass + larger
solid grass regions. This is the in-game gate catching what the render tool would have lied
about.)

### Tests / gates (cite-able)
- **GUT yard suite:** 36/36 (`tests/test_s1_yard_slice.gd`) — rewrote the dirt/grass-in-FloorTiles
  pins to autotile-terrain pins: full-base-coverage, dirt-majority/grass-parts (over terrain
  cells), grass-only-at-corners, **dirt↔grass uses BLEND tiles** (mixed-corner Wang), **grass
  muted-not-neon** (sat<0.70 + hue<115°), AI-cobble-lane-present-with-grout, terrain TileSet
  corner-match. Empirically verified `set_cells_terrain_connect` selects solid all-grass
  interior + all-dirt field + blend rims (probe).
- **Grunt NIT:** `test_grunt.gd` 0.552→0.607 (0.48×1.265 MOB_SCALE_FACTOR) — pass.
- **GUT full suite:** 2042 passing, 0 failing (67 pre-existing pending/risky; the ERROR lines
  are deliberate negative-path tests asserting graceful handling). Adjacent suites green:
  assembler-retrofit 7/7, nav 3/3, env-art 15/15.
- **Painter parses clean; line-length ≤100 on all edited lines.**

### CROSS-LANE INTEGRATION CHECK (PR #216 gate)
- **`[combat-trace]` contract preserved:** untouched — no mob/combat code changed. The
  `Main.load_s1_zone` trace (chunks=2 + bounds) the Playwright spec keys on is unchanged
  (no ZoneDef/assembler/chunk-def edit).
- **Player iframes / Damage constants:** untouched (out of scope).
- **RoomGate signal chain:** untouched.
- **Adjacent specs probed:** `s1-yard-slice-render.spec.ts` asserts boot-clean + the load trace
  + zero USER WARNING + no 404 — the new terrain TileSet + AI cobble PNGs must resolve in the
  .pck (CI gate). GUT nav suite confirms buildings/well still walk-around + descent reachable.
- **Regression guard (Done clause):** `test_ground_dirt_grass_boundary_uses_blend_tiles` +
  `test_wang_grass_is_muted_not_neon` pin the v5 look so a regression (neon grass / hard cut /
  lost autotile) fails loudly; `test_dirt_field_has_zero_green_pixels` keeps the dirt clean.

### HTML5 build + Playwright — CI gate (no local web export templates)
Local env has the 4.3.stable base templates but NOT the `web_nothreads_*.zip` web templates, so
I cannot export HTML5 or run the Playwright spec locally (documented constraint, same as
`render_yard_slice.gd`). The **GPU SubViewport in-engine render IS the in-game visual of
record** (real Godot renderer). The release HTML5 build + the `s1-yard-slice-render.spec.ts`
Playwright capture run in **CI** on push — that is where the `?s1_assembler=1` browser capture +
warning-gate land. Build artifact URL + Playwright run will be filled from the CI run on this
HEAD (separate turn, real values — not fabricated here).

### Sponsor soak probe targets (CI release artifact, `?s1_assembler=1`, cache-clear + incognito)
1. Dirt↔grass reads as a SOFT autotiled blend (grass reclaims corners, soft rim) — Stardew/GK feel.
2. Grass is MUTED olive-mossy, NOT neon.
3. The cobble LANE (AI weathered cobble) reads as a legible grey stone path through the dirt.
4. No hard tile edges / no maroon cliff / no black square.
5. #426 wins intact (mob/well/char scale).
