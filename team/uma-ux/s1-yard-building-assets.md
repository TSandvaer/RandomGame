# S1 Yard BUILDING ASSETS — PixelLab gen spec (orch-run)

**Owner:** Uma (visual direction / asset spec) → **orchestrator runs the gens** (PixelLab + pixel-mcp are orch-session-only per `pixellab-pipeline.md §"Execution context"`) → **Drew places** at the §3.1 footprint coordinates (Stage-C). · **Phase:** M3 S1 spatial pivot — the building-asset layer of the APPROVED `s1-yard-layout-design.md` layout.

## What this is and is NOT

Sponsor APPROVED the `s1-yard-layout-design.md` 40×24 layout (PR #430) with ONE addition: *"order PixelLab buildings instead of just stone slabs."* The 4 buildings in §3.1 must be **real PixelLab-generated top-down structure ASSETS** — not flat stone-slab / wall-tile footprints (the bland placeholder the literal-build produced). This doc SPECS each of the 4 building gens so the orchestrator can run them; it does NOT run the gens (orch), does NOT place/code them (Drew), does NOT re-open the approved layout (footprints + intent are locked in `s1-yard-layout-design.md §3.1`).

**These are PROPS, not tilemap features** — sibling to the carried-forward `pillar_arch` and the WELL-HEAD hero prop (`s1-yard-ground-composition.md §5`): collision-solid `Sprite2D` props placed at **z=+1** (the player walks AROUND them, not on them; floor is z=0 per `html5-export.md`). Drew sets the collision footprint from the §3.1 `Rect2i` and the visual draws at that footprint, with the off-frame vertical (bell-tower / roof) extending ABOVE the footprint's top edge — these are landmarks the small `char_scale=0.6` player reads as structures.

---

## 0. TONAL ANCHOR (the feel that governs every gen)

**The S1 yard reads as a monastery the monks abandoned and the world is reclaiming — humans built here once, then left, and the stone remembers them.** The buildings are the strongest "this was alive" beat in the yard: weathered warm-sandstone cloister stone, broken or sagging where time won, moss creeping the bases, one lit window holding a mystery. They are NOT pristine, NOT ruined-to-rubble (except the dormitory) — they are **dignified decay**: a real place that outlived its people. Every gen below ladders DOWN from this anchor: warm-sandstone color → weathered/abandoned texture → the per-building feature (bell-tower vista / broken roofline / lit-south-window mystery / small east-horizon depth). If a gen comes back pristine, glossy, or cold-grey, it's wrong on feel — re-roll toward warm + weathered.

Reference reads: Graveyard Keeper top-down monastery structures + the existing carried-forward S1 props (`pillar_arch`, `brazier_lit`/`brazier_cold` at `assets/props/s1_cloister/`) — match their warm-sandstone weathered cloister tone, top-down read, and pixel density.

---

## 1. SHARED GEN DISCIPLINE (applies to all 4)

### 1.1 Tool

**`mcp__pixellab__create_map_object`** — the structure/object generator (the SAME tool that produced the carried-forward S1 props per `env-art-s1-direction.md §6.1`, and the recommended tool for the WELL-HEAD hero prop per `s1-yard-ground-composition.md §5`). Single-object generation, transparent background, top-down view. NOT `create_topdown_tileset` (that's terrain Wang-autotile, wrong for a discrete structure) and NOT `create_character` (these are structures, not animated rigs).

### 1.2 View

**High top-down** — match the existing prop + tile camera read (the yard is a top-down RPG plan; the player sees roofs + the upper face of structures). The off-frame vertical (bell-tower, roofline) reads as the structure's silhouette extending toward the top of the canvas (screen-N), since N = "away/up" in the top-down convention. Request the structure's footprint as the ground plane with the vertical mass rising toward canvas-top.

### 1.3 Size discipline + the 400px `create_map_object` cap (`pixellab-pipeline.md` canvas-size trap)

PixelLab canvas is **always square** and the `size` param controls the object's approximate extent, NOT the canvas. **Tier 2 / Pixel Artisan cap = ≤400×400px** (`pixellab-pipeline.md §"Tier-based concurrent job-slot limit"`). The yard tile = 32px, so each building's footprint in px = `(w×32) × (h×32)` — BUT the GENERATED asset includes the off-frame vertical above the footprint, so the asset's pixel height exceeds the footprint height. Per-building px targets + crop plan are in each §2 entry. **Always confirm real canvas dims with `get_sprite_info` before crop** — never assume from the `size` param (canvas-size trap).

### 1.4 Palette guidance — warm-sandstone building doctrine, sub-1.0 HDR-safe

All 4 lock to the S1 environment doctrine (`palette.md` S1 + `env-art-s1-direction.md §6.3`). **Warm-sandstone building family:**

```
S1_BUILDING_DOCTRINE = [
  "#9A7A4E",  # bronzed trim / lit-stone edge (warmest building hex; arch + course highlights)
  "#7A6A4F",  # sandstone body base (the dominant building mass color)
  "#5C4F38",  # sandstone deep / recessed course / under-eave shadow
  "#4A3F2E",  # heavy cloister stone (wall base, darkest structural mass)
  "#5C7044",  # moss accent (base creep + damp north faces; SPARSE)
  "#D7C68F",  # parchment / pale weathered stone highlight (sun-bleached top courses)
  "#2C261C",  # iron-soot / dark timber (broken-roof beams, bell-tower fittings)
  "#1A1210",  # deep shadow / mortar joint line (NOT #000000 per PL-09)
]
```

Plus the **lit-window glow** for the central building ONLY (§2.3): warm ember-family, sub-1.0 every channel —

```
LIT_WINDOW = [
  "#FFB066",  # window-glow core (warm inner light)
  "#FF6A2A",  # window-glow rim / spill (ember accent — the brand through-line)
  "#E04D14",  # glow falloff / deep spill
]
```

**HDR-clamp safety (`html5-export.md`):** every channel must be **sub-1.0** (≤254 per channel) — no `#FFxxxx` at full 255 on a channel that would clip in WebGL2 sRGB. `#FFB066` and `#FF6A2A` are pre-cleared (they are the locked ember ramp, already used in-engine on the braziers); the doctrine body hexes are all sub-1.0 by construction. **Zero pure-black** (`#000000`) — use `#1A1210` for the deepest mortar/shadow (PL-09 S1 anti-list).

### 1.5 Doctrine-lock — Strategy 3 (per-slot nearest-neighbor), fresh-gen

These are **fresh PixelLab generations → first doctrine-lock**, so **Strategy 3 (per-slot nearest-neighbor)** is the validated winner (`pixellab-pipeline.md §"Doctrine palette compliance"` Strategy 3). Recipe:
1. `quantize_palette target_colors=12` (over-request ~40% above the 8-hex body doctrine to absorb dupe slots; +3 for the central building's 3 lit-window hexes → `target_colors=15` for that one).
2. Per-slot nearest-neighbor map each quantized slot to the closest `S1_BUILDING_DOCTRINE` hex (Euclidean RGB).
3. **Character-beat override (central building only):** the lit-window glow is the doctrine-critical accent — verify the brightest warm window slot routes to `#FFB066`/`#FF6A2A`, NOT to a muddy `#9A7A4E` trim. Manual-override that slot if Euclidean misroutes (the Grunt eye-glow override pattern, `pixellab-pipeline.md §"manual override for character-beat preservation"`).

### 1.6 Outline discipline (`env-art-s1-direction.md §6.3` VD-13)

**Buildings get NO 1px dark character-outline** (outlines are characters-only). Walls/courses MAY carry the `#1A1210` mortar/joint line — that's coursed-stone DETAIL, not a silhouette outline. If PixelLab adds a heavy black silhouette outline, strip it in pixel-mcp or the building reads as a bordered box, not a stone structure.

### 1.7 8h-expiry + download-promptly gotcha (`pixellab-pipeline.md`)

`create_map_object` results live on a temporary URL; **download the PNG promptly** (`curl --fail` the result URL the moment the gen completes). Completed gens persist on the CDN but harvest end-of-batch per the bulk-download default — do NOT leave the 4 building gens un-downloaded across a session boundary.

### 1.8 Output paths (`env-art-s1-direction.md §6.4` convention)

```
assets/props/s1_yard/chapel_belltower.png       # §2.1
assets/props/s1_yard/dormitory_ruin.png         # §2.2  (single asset; see §2.2 cap handling)
assets/props/s1_yard/cloister_central.png       # §2.3
assets/props/s1_yard/outbuilding_far.png        # §2.4
```
Raw PixelLab output → `assets/props/s1_yard/_pixellab_raw/<name>.png`; doctrine-locked export → the path above.

---

## 2. THE 4 BUILDING GENS

### 2.1 Chapel + bell-tower (NW spawn-shoulder anchor)

- **Footprint** (locked, `s1-yard-layout-design.md §3.1`): `Rect2i(0, 0, 8, 3)` → x0–7, y0–2 → **256×96px footprint**.
- **Design intent:** anchors the NW corner AT the spawn shoulder; the bell-tower vertical is the **spawn-vista headline** — the first vertical the player sees, runs off-frame N. The chapel-step NPC station sits just below it.
- **`create_map_object` description:**
  > `"Top-down weathered abandoned medieval monastery chapel, warm sandstone stone walls, a tall narrow bell-tower rising at one end with a dark bell visible in its arched belfry opening, sagging old timber roof, moss creeping the stone base, coursed-stone masonry, dignified decay, high top-down view, warm-sandstone palette."`
  > Lead with "chapel" + "bell-tower" (per the prompt-literalism first-noun-dominates rule, `pixellab-pipeline.md §"Prompt engineering"`); the bell-tower is the silhouette beat so it must read as a tall vertical mass distinct from the long chapel body.
- **Width/height:** the footprint is 256×96px, but the bell-tower rises ABOVE it (off-frame N). Generate at **`size=256`** (square 256×256 canvas gives room for the bell-tower vertical above the 96px chapel body). Crop to the chapel body + bell-tower silhouette: keep the full vertical, crop the canvas to ~**256w × ~180h** (body 96 + tower ~84 rising N). Under the 400px cap — single gen, no split. Confirm real dims with `get_sprite_info` before crop.
- **View:** high top-down; bell-tower as a tall vertical mass at the WEST end (toward x0, the corner it anchors), body running EAST.
- **Palette:** `S1_BUILDING_DOCTRINE` (no lit-window). Sun-bleached `#D7C68F` on the tower top-course, `#5C7044` moss on the base + north face.
- **Doctrine-lock:** Strategy 3, `target_colors=12`.

### 2.2 Dormitory ruin (S edge, broken-roofline ruin) — the >400px cap handling

- **Footprint** (locked): `Rect2i(0, 21, 15, 3)` → x0–14, y21–23 → **480×96px footprint** → **480 EXCEEDS the 400px `create_map_object` cap.**
- **Design intent:** runs the SW–S edge, wider than the chapel + offset east; a RUIN (broken roofline) with rubble spilling north (the treasure cache); blocks the SW so the spine must rise to clear it; runs off-frame S.
- **>400px cap handling — MY CALL: gen in 2 overlapping halves, Drew composites/places as one footprint.** Rationale: a ruined dormitory is the ONE building where seam-hiding is trivial — the broken roofline + rubble spill are irregular by nature, so a join seam between two halves disappears into the ruin texture (unlike a clean chapel wall where a seam would read as a crack). Tiling/scaling a single ≤400 gen (the alternative) would either soften the pixel density (scale-up) or force an awkward repeat (tile) on a structure that must read as ONE continuous broken building. Two halves preserve full pixel density AND let Drew vary the break per half.
  - **Left half (west, the more-intact end):** footprint x0–7 (~256px wide). Description:
    > `"Top-down weathered abandoned monastery dormitory ruin, warm sandstone walls, partially collapsed roof with broken exposed dark timber roof-beams, one end more intact, moss-grown stone, coursed masonry, dignified decay, high top-down view, warm-sandstone palette."`
    Generate `size=256` → crop to ~256×~140 (body 96 + a little roof-rise N). Under cap.
  - **Right half (east, the more-collapsed end + rubble):** footprint x7–14 (~256px wide, ~32px overlap with the left half at x7 for compositing). Description:
    > `"Top-down weathered abandoned monastery dormitory ruin, collapsed end with the roof fully fallen in, rubble and broken stone spilling out, warm sandstone walls reduced to stumps at the open end, moss-grown, dignified decay, high top-down view, warm-sandstone palette."`
    Generate `size=256` → crop to ~256×~140. Under cap.
  - **Drew composites:** the two halves abut at x7 (32px overlap blends the join in the broken-roof texture). Drew places the composite at the §3.1 `Rect2i(0,21,15,3)` footprint; the rubble-spill in the east half extends N toward the (32,23) rubble cache. The composite reads as one continuous ruin; the seam hides in the break.
- **Palette:** `S1_BUILDING_DOCTRINE`; heavier `#2C261C` (dark broken-timber beams) + `#1A1210` (deep recess where the roof fell in) on the collapsed end; `#5C7044` moss heavier than the chapel (more time-reclaimed).
- **Doctrine-lock:** Strategy 3, `target_colors=12`, per half. Lock both halves to the SAME doctrine so the composite is tonally seamless.

### 2.3 Central cloister building (high off-center anchor, lit south window)

- **Footprint** (locked): `Rect2i(26, 0, 4, 4)` → x26–29, y0–3 → **128×128px footprint**.
- **Design intent:** the spatial anchor placed HIGH + OFF-center (NE of mid); splits the upper-east ground; creates the spine FORK decision. **Its lit/glowing window (mystery hook) faces SOUTH toward the player's approach** — the single mystery beat of the yard. Runs off-frame N (top course only visible from the south approach).
- **`create_map_object` description:**
  > `"Top-down weathered abandoned monastery cloister building, square warm sandstone structure, an arched window on its south-facing wall with a warm orange glow spilling from inside as if a single light still burns, otherwise dark and abandoned, moss-grown base, coursed masonry, dignified decay with one lit window mystery, high top-down view, warm-sandstone palette with a warm glowing window."
  > Lead with the structure, then the lit south window as the dominant feature beat (per first-noun + character-beat-first discipline). The glow is small + contained (one window), NOT the whole face lit — per the Shooter "doctrine made it face-red; pixellab just made big eyes" lesson (`pixellab-pipeline.md §"selective slot routing"`), keep the emissive a small accent so doctrine-lock doesn't over-route it.
- **Width/height:** footprint 128×128px; runs off-frame N so generate at **`size=128`** (128×128 canvas), crop to ~**128w × ~160h** (body 128 + a small N-rise for the off-frame top course). Under cap — single gen. The SOUTH face (toward canvas-bottom, screen-S = toward player) carries the lit window.
- **View:** high top-down; the lit window on the south wall (canvas-bottom edge of the structure) since the player approaches from the south/west.
- **Palette:** `S1_BUILDING_DOCTRINE` + `LIT_WINDOW` (the ONLY building with the glow trio).
- **Doctrine-lock:** Strategy 3, `target_colors=15` (12 body + 3 window-glow). **Character-beat override:** verify the brightest window slot → `#FF6A2A`/`#FFB066`, NOT `#9A7A4E` trim; manual-override if misrouted. This window glow is the mystery hook — it MUST survive the lock as a warm spill, not collapse into stone-tan.

### 2.4 Far outbuilding (east-horizon depth anchor)

- **Footprint** (locked): `Rect2i(38, 2, 2, 2)` → x38–39, y2–3 → **64×64px footprint**.
- **Design intent:** SMALL, high-east, near the exit; anchors the long east sightline ("more world that way"); sits ABOVE the exit line so it doesn't block the descent approach; the eye is pulled toward it across the open east lane.
- **`create_map_object` description:**
  > `"Top-down small weathered abandoned monastery outbuilding, a little square warm sandstone shed or storehouse, simple low roof, moss-grown, humble and worn, dignified decay, high top-down view, warm-sandstone palette."`
  > "Small" + "little square" up front so PixelLab doesn't over-elaborate it into a second chapel — it's a depth anchor, not a focal structure; it should read as humble + distant.
- **Width/height:** footprint 64×64px; small structure with a low roof (minimal off-frame vertical). Generate at **`size=64`** (64×64 canvas), crop to ~**64×~80h** (body 64 + a small roof-rise). Well under cap — single gen. *(If `size=64` renders too coarse / under the humanoid-floor density, gen at `size=96` and downsample to ~64 — confirm density against the existing props before shipping.)*
- **View:** high top-down; simple read, no dominant feature (it IS the "no feature, just distance" beat).
- **Palette:** `S1_BUILDING_DOCTRINE` (no lit-window); slightly more `#D7C68F` sun-bleach + `#5C7044` moss to read as weathered-and-distant. The east-bronzed-funnel decoration band (`s1-yard-layout-design.md §3.7`) frames it — the building itself stays humble.
- **Doctrine-lock:** Strategy 3, `target_colors=12`.

---

## 3. GEN BATCH SUMMARY (orch run-sheet)

| # | Asset | `size` | Crop target | Cap | Lit window | `target_colors` |
|---|---|---|---|---|---|---|
| 1 | `chapel_belltower.png` | 256 | ~256×180 | OK | no | 12 |
| 2a | `dormitory_ruin` LEFT | 256 | ~256×140 | OK | no | 12 |
| 2b | `dormitory_ruin` RIGHT | 256 | ~256×140 | OK | no | 12 |
| 3 | `cloister_central.png` | 128 | ~128×160 | OK | **YES** | 15 |
| 4 | `outbuilding_far.png` | 64 (or 96↓64) | ~64×80 | OK | no | 12 |

**5 gens total** (the dormitory is 2 halves). All ≤400px → no gen exceeds the `create_map_object` cap. PixelLab queue is ~2-processing-at-a-time (`pixellab-pipeline.md`), so wall-time ≈ 5min × ceil(5/2) ≈ ~15min; harvest all via end-of-loop bulk-download. Each gen: `create_map_object` → `curl` the result → pixel-mcp `quantize_palette` → Strategy-3 nearest-neighbor `set_palette` → `crop_sprite` → `export_sprite` to the §1.8 path. Doctrine-verify (eye-dropper the body to `#7A6A4F`-family; the central building's window to the `#FF6A2A` ramp) before handing to Drew.

---

## 4. WHAT DREW BUILDS (after the gens land)

1. Place the 4 building assets as collision-solid `Sprite2D` props at z=+1 at the §3.1 `Rect2i` footprints (chapel `(0,0,8,3)`, dormitory composite `(0,21,15,3)`, central `(26,0,4,4)`, outbuilding `(38,2,2,2)`), with the off-frame vertical (bell-tower / roofline) drawing ABOVE the footprint top edge.
2. **Composite the dormitory** from the 2 halves (left x0–7, right x7–14, 32px overlap at x7) into one continuous ruin; the east-half rubble-spill extends N toward the (32,23) rubble cache.
3. Set collision from the `Rect2i` footprint (player walks around, not on). Floor stays z=0; buildings z=+1 per `html5-export.md` z-order.
4. The central building's lit-south-window faces the player approach (canvas-S of the structure); the central-entrance NPC station (`s1-yard-layout-design.md §3.4`, tiles 27–28,4) sits just S of it under the lit window.
5. **HTML5 visual-verification gate** (`html5-export.md`): the lit-window glow is a static baked-in PNG accent (NOT a Tween/modulate) so it's NOT itself gate-triggering; but the building-placement PR is a level/visual PR → author self-soak + Self-Test Report before Tess. If Drew later wants the window to FLICKER, that's a ColorRect-modulate cue (NOT Polygon2D, PR #137), flagged-not-specified here.

---

## 5. CROSS-REFERENCES

- `team/uma-ux/s1-yard-layout-design.md` §3.1 — the APPROVED footprints + per-building design intent this asset-spec generates art for (the LOCKED source of the 4 `Rect2i` + their feature beats).
- `team/uma-ux/s1-yard-ground-composition.md` §5 — the WELL-HEAD hero-prop gen (the `create_map_object` structure-prop precedent + landmark-scale + Strategy-3 doctrine-lock this spec mirrors).
- `team/uma-ux/env-art-s1-direction.md` §6 — the `create_map_object` prop run-sheet (tool choice, canvas-size discipline, the `S1_ENV_DOCTRINE` palette, VD-13 no-outline, output-path convention) the carried-forward props were built from.
- `team/uma-ux/palette.md` S1 — the warm-sandstone environment doctrine (`#7A6A4F` body / `#9A7A4E` trim / `#4A3F2E` heavy stone / `#5C7044` moss) + the ember ramp for the lit window + PL-09 zero-pure-black.
- `.claude/docs/pixellab-pipeline.md` — `create_map_object` orch-only execution, canvas-size trap, 400px Tier-2 cap, Strategy-3 nearest-neighbor doctrine-lock, character-beat override, prompt first-noun-dominates, end-of-loop bulk-download.
- `.claude/docs/html5-export.md` — HDR-clamp sub-1.0 channels, floor z=0 / props z=+1, ColorRect-not-Polygon2D for any future animated window cue (PR #137), visual-verification gate.
- `game-art` skill — silhouette readability, the landmark-scale + top-down structure read, staging (the buildings are the wayfinding silhouettes of §4 of the layout).
- Memory: `tile-scale-small-player-large-world` (buildings read as structures a small player walks up to), `s1-cloister-yard-open-world-direction`, `world-feel-big-and-endless`.

---

## 6. Decision draft (for Priya's weekly `DECISIONS.md` batch — NOT direct-edited per Uma role rule)

**Decision draft (2026-06-08)** — **S1 yard BUILDINGS spec'd as real PixelLab `create_map_object` structure ASSETS** (Sponsor addition to the approved layout: *"order PixelLab buildings instead of just stone slabs"*). The 4 buildings in `s1-yard-layout-design.md §3.1` become top-down weathered-cloister-stone PROPS (collision-solid, z=+1, warm-sandstone doctrine, sub-1.0 HDR-safe, Strategy-3 doctrine-lock), NOT flat stone-slab footprints. Chapel+bell-tower (`size=256`, spawn-vista headline), dormitory ruin (**gen in 2 halves** — footprint 480px exceeds the 400px `create_map_object` cap; the broken-roofline ruin hides the composite seam, Drew abuts left x0–7 + right x7–14 with 32px overlap), central cloister building (`size=128`, **lit south window** = the yard's mystery hook, the only building with the ember-glow trio + a character-beat override to protect the glow through doctrine-lock), far outbuilding (`size=64`, small east-horizon depth anchor). 5 gens total, all ≤400px, ~15min orch wall-time, end-of-loop bulk-download. Orch runs the gens (PixelLab orch-only); Drew places at the locked footprints + composites the dormitory. Reversibility: 5 PNG gens + prop placement — all revertible.
