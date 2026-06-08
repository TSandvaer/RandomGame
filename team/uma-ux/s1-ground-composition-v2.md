# S1 Ground Composition v2 — "Fine Cobble Lane Through a Lived-In, Varied Yard"

**Owner:** Uma (Stage A — vision/direction) → orch (procedural gen, orch-only) → Drew (Stage C — paint/compose into the yard) · **Phase:** M3 S1 spatial pivot, GROUND + PATH layer.
**Replaces:** the **ashlar/slab-path approach is RETIRED** — see §0. Supersedes `s1-slab-path-texture.md` (the irregular-cut-stone ashlar spec, PR #427) AND the §2 slab-path sections of `s1-yard-ground-composition.md`. The water-feature / well / springs / decoration beats of `s1-yard-ground-composition.md` (§3–§4) carry forward UNCHANGED; only the path MATERIAL and the wall-to-wall-cobble GROUND assumption change here.
**Status of the loved tech:** the procedural cobble generator (`tools/gen_s1_cobble_floor.py`, additively-weighted toroidal Voronoi) is **the proven, Sponsor-LOVED tech.** This spec LEANS ON IT for both surfaces — it does NOT invent new procedural art.

---

## 0. WHY v2 — the THIRD rejection + the hard pivot (read this first)

The slab/ashlar path approach has now been rejected **three times** in soak. The path was:
1. reused `floor_sandstone.png` → "too big"
2. reused `floor_sandstone.png` again → "awful" (baked green dots + grid)
3. NEW procedural ASHLAR irregular-cut-stone slabs (PR #427) → **rejected again.**

**Sponsor's verbatim words this round (the binding direction):**
> *"the path is too big and not at all like a real path. look at all the images i put in the inspiration folder"*
> *"the problem is your artistic skills more than the slabs themselves. Fine small-cobble pavers is preferred. The cobblestone should only be parts of the walking background."*

**Two hard conclusions, no further slab iteration:**

1. **The path is NOT slabs/ashlar/cut-stone at ANY scale.** Big flat cut pavers — irregular or not — are the wrong shape for a "real path." **The path is FINE SMALL-COBBLE PAVERS** (look at `inspiration/2026-06-08_08h00_28.png` — the village street: a deliberate lane of small muted grey-tan cobbles, fine, walked-smooth, reading instantly as "a path"). Stop trying to make slabs read as a path; they never will. The slab concept is dead.

2. **The ground is NO LONGER wall-to-wall cobble.** Sponsor: *"The cobblestone should only be parts of the walking background."* The ground becomes a VARIED lived-in surface — worn dirt/earth + grass patches + cobble patches — with cobble appearing as PARTS, not a carpet (look at `2026-06-08_11h18_12.png` Graveyard Keeper + `2026-06-08_11h19_36.png` Stardew-like: the ground is mostly worn DIRT and GRASS, with paving only where it earns its place).

**THE EXECUTION INSIGHT (the load-bearing call):** Sponsor LOVED the procedural cobble (`gen_s1_cobble_floor.py` Voronoi). He REJECTED the new procedural ashlar. So the path solution **leans on the loved cobble tech, not fresh procedural art:** the fine-cobble-paver PATH is a **finer, tonally-distinct VARIANT of the cobble generator** (smaller stones + a slightly distinct tone for path-vs-ground contrast), NOT a new texture model. This is the single most important sentence in this doc: **reuse the loved tech, tune it; do not invent.**

---

## 1. TONAL ANCHOR (lead with this — everything ladders down)

> **The S1 yard ground reads as "a real lived-in monastery yard where the ground tells you how people moved: a fine, worn cobble LANE — small set stones walked smooth — threads across mostly bare worn EARTH, with grass reclaiming the edges and corners and a few patches of older cobble paving surviving here and there. The lane is unmistakably a PATH the moment you see it — finer and a touch warmer-grey than the rough ground around it — but it is humble and human-scaled, never a grand processional avenue. You read where people walked by where the dirt wore through and the cobbles got laid; you read where they DIDN'T by where the grass took over."**

Same overarching feel-gate as the parent vision — **BIG + ENDLESS + ALIVE + WONDROUS + a JOURNEY** (`s1-cloister-yard.md` §0.5/§0.6):
- **JOURNEY** — the fine-cobble lane is the literal desire-line. It reads at a glance as "walk here" — but as a humble worn village lane, not a monument. Wayfinding is its primary job; humility is what makes it a *real* path.
- **ALIVE** — a VARIED ground (worn dirt where feet fell, grass where they didn't, surviving cobble patches) is the biggest "lived-in" lever at floor level. A uniform anything — cobble carpet OR dirt carpet — reads as an arena. The variety IS the life.
- **BIG/ENDLESS** — varied ground (dirt + grass + cobble patches + the lane) keeps a multi-screen scroll from ever exposing a single tiled texture. Variety is the anti-repeat defense across the wide yard.
- **WONDER** — the well, springs, garden-bed-gone-wild (carried forward from `s1-yard-ground-composition.md` §3–§4) sit IN this varied ground as the most-reclaimed, most-alive pockets.

**The reference poles (LOOK at the images — they are ground truth):**
- **`inspiration/2026-06-08_08h00_28.png` (village street) — THE PATH TARGET.** A fine small-cobble lane: small muted grey-tan stones, walked-smooth, organic-edged, reading unmistakably as a walkable lane bordered by planting. THIS is the path look. Note the cobble is FINE (many small stones, not big slabs) and the lane is HUMBLE-width, not a grand road.
- **`inspiration/2026-06-08_11h18_12.png` (Graveyard Keeper) — THE GROUND TARGET.** The ground is mostly worn brown DIRT/earth, framed by GRASS, with dirt PATHS worn between buildings — paving appears only as small patches. Cobble is "parts of the walking background," exactly Sponsor's words.
- **`inspiration/2026-06-08_11h19_36.png` (Stardew-like) — THE DIRT+GRASS PATCHWORK.** Large worn-dirt areas meeting grass in soft organic borders — the varied-ground composition logic.
- **`inspiration/2026-06-08_07h54_44.png` (village courtyard) — THE BLEND DISCIPLINE.** Worn multi-tone stone with grass/dirt invading the joints and worn patches — aged, walked-on, NEVER a uniform grid. The "worn + blended + organic" craft target for both surfaces.

**Anti-list (what's dead / what to cut):**
- **NO slabs / ashlar / big flat cut-stone pavers — at ANY scale or irregularity.** Rejected three times. The path is fine cobble. (This retires `s1-slab-path-texture.md` entirely.)
- **NO wall-to-wall cobble carpet.** Cobble is now PARTS of the ground, not the whole ground.
- **NO grand processional avenue.** The lane is a humble worn village lane, fine and human-scaled. "Too big" was a rejection three times — the lane reads as a path you'd find in a village, not a cathedral approach.
- **NO baked green vegetation IN any ground/path tile.** (Carried forward, load-bearing — see §5.) Grass is a SEPARATE deliberate-planting/decoration layer painted ON TOP, never speckled into the tile. The path tile + the ground tiles ship with ZERO green pixels.
- **NO grid of identical anything** (cobble or dirt) — the Voronoi/noise tech guarantees organic variation; preserve it.
- **NO Polygon2D** for any ground/path/water light cue (ColorRect-rotated-rect per `html5-export.md` PR #137).

---

## 2. THE PATH — fine small-cobble pavers (a tuned variant of the LOVED cobble gen)

### 2.1 The material: a FINER, tonally-distinct variant of the proven cobble generator

The path is NOT a new texture. It is **the loved `gen_s1_cobble_floor.py` Voronoi tech, tuned two ways:**

1. **Finer stones** — the path cobbles are SMALLER than the background-ground cobble patches, so the lane reads as a deliberately-laid fine pavement (the village-street ref: many small set stones), distinct from the rougher surviving cobble patches in the ground.
2. **A slightly distinct tone** — the path cobble is a touch **warmer + lighter grey-tan** than the cooler/greyer background cobble, giving the path-vs-ground contrast that makes the lane read instantly as "walk here" WITHOUT introducing a new material. This is the same warm-vs-cool wayfinding logic the dead slab spec used — but now expressed as a *tone shift on the same cobble material*, which is subtle and real (a walked-lane DOES wear lighter/smoother), not a jarring material swap.

**Why this is the right call (three confirmations):**
- **Sponsor LOVED the cobble tech and REJECTED the ashlar.** Leaning on the loved tech is the lowest-risk path to a Sponsor-approved result.
- **The village-street reference IS fine cobble**, not slabs — the tech already produces exactly this stone shape; we just tune scale + tone.
- **The generator already has the scale lever built in.** `gen_s1_cobble_floor.py` documents (lines 176–185): the ONLY scale lever at fixed atlas period is the SOURCE RADII; the current FINE-COBBLE plan makes a large cobble render ~18 screen px ≈ 1/3 the 0.6 player. The path just needs an EVEN-FINER radii plan (smaller stones) — a one-parameter-family change, not new code.

### 2.2 Path scale — finer than the ground cobble, humble lane width

The repeated "too big" rejection is a SCALE failure. Concrete targets relative to the LOCKED fine cobble base (`gen_s1_cobble_floor.py`, large cobble ≈ 18 screen px ≈ 1/3 player):

- **Path stones are FINER than the background cobble** — the path's largest stone should render roughly **10–14 screen px** at game zoom (smaller than the ground cobble's ~18px largest), so the lane reads as a fine, deliberately-laid pavement of small set stones (village-street ref). Achieved by dropping the radii_plan tier sizes ~25–40% below the ground-cobble plan + raising counts (more, smaller stones). NEVER a stone that approaches player-size — that was every "too big" rejection.
- **The lane is HUMBLE width** — a worn village lane a few player-widths across, NOT a grand avenue. Drew sets exact width in composition; the spec rule is "reads as a village footpath, not a processional road." (The lane width is a Drew painting decision; the TILE just needs to be fine cobble.)
- **In-engine tile stays 32px** (chunk grid `tile_size_px=32`, unchanged) — "finer path cobble" means a finer stone PATTERN within the 32px tile, authored at the same 384px-class source res as the ground cobble so slicing math is identical. Same as the ground-cobble approach; only the radii plan differs.
- **Drew validates the path-to-ground SIZE + TONE contrast IN-CONTEXT** (path lane composed through the varied ground at game zoom + `char_scale=0.6`, per `TESTING_BAR.md` §"judge art in context") — the lane reads clearly finer + a touch warmer-lighter than the surrounding ground, an obvious "walk here" lane, but humble and small in the big yard. NEVER judged as an isolated swatch.

### 2.3 Palette — same cobble family, path-tone shifted warmer-lighter (HDR-safe)

The path reuses the cobble doctrine, shifted a touch warmer + lighter for the walked-lane read. Every channel sub-1.0 (HDR-clamp-safe per `html5-export.md`).

```
S1_PATH_COBBLE_DOCTRINE = [
  "#7E7460",  # path base — warm-grey set-stone, a touch WARMER+LIGHTER than ground cobble #6E665A (the walked-lane read)
  "#988C76",  # path lit — domed top of a walked-smooth path stone catching light (lighter than ground cobble_lit #857C6C)
  "#5E564A",  # path shadow — path stone base shadow / joint (slightly warmer than ground cobble_shadow #544C42)
  "#3D372F",  # joint deep — recessed dirt+shadow gap (SHARED with ground cobble + dirt doctrine; one joint hex across the whole yard)
]
```

**Channel-clamp check (sub-1.0, every channel):** `#7E7460`=(0.494,0.455,0.376) · `#988C76`=(0.596,0.549,0.463) · `#5E564A`=(0.369,0.337,0.290) · `#3D372F`=(0.239,0.216,0.184). All ≤ 0.60 — comfortably HDR-safe.

**The path-vs-ground contrast (the wayfinding payload — Tess pin PL-PATH-02):** path base `#7E7460` is **perceptibly warmer + lighter than the background-ground cobble** `#6E665A` AND obviously finer-stone. The contrast is the whole point of the lane reading as "walk here." It is subtle (a real walked-lane wears lighter, not a different color) — preserve the shift; do NOT exaggerate it into a jarring material swap, and do NOT collapse it (a path identical to the ground reads as no path at all).

**Eye-dropper pins (Tess QA criteria):**
- **PL-PATH-01** — path stone reads warm-grey cobble `#7E7460` (base) / `#988C76` (lit), FINE small stones (not slabs, not big pavers).
- **PL-PATH-02** — path is perceptibly warmer+lighter AND finer-stone than the surrounding ground cobble `#6E665A` (the "walk here" contrast).
- **PL-PATH-03** — path joints read dirt-shadow `#3D372F` (organic varied gaps, no grid).
- **PL-PATH-04 (rejection guard)** — **ZERO green pixels in the path tile.** Grass is a painted-on layer (§5), never baked.
- **PL-PATH-05 (scale guard)** — path's largest stone is FINER than the ground cobble's largest, and nowhere near player-sized (the "too big" guard).

### 2.4 Path gen-method — extend the LOVED cobble generator (one new radii plan + tone)

**Recommendation: PROCEDURAL — a fine+warm variant of `gen_s1_cobble_floor.py`, NOT a new script and NOT a new model.** Either:
- (a) add a `--profile path` flag to `gen_s1_cobble_floor.py` that swaps in the finer radii plan + `S1_PATH_COBBLE_DOCTRINE` tint, OR
- (b) a thin `gen_s1_path_cobble.py` that imports the same toroidal-Voronoi core and only overrides the radii plan + palette.

Both reuse the exact loved tech (additively-weighted toroidal Voronoi, seamless-by-construction, doctrine-lock, variant set). The ONLY changes vs the ground cobble:
1. **Finer radii plan** — tier sizes ~25–40% smaller + counts up (more, smaller stones) per §2.2.
2. **`S1_PATH_COBBLE_DOCTRINE` palette** — the warmer+lighter path tones per §2.3.
3. **No new model.** Keep the rounded-domed Voronoi look (it's the LOVED read); do NOT switch to ashlar/broken-course (that's the rejected model).

**Output:** 3–4 seamless path-cobble variants (toroidal, anti-repeat across the lane), at the 384px-class source res, doctrine-locked by construction. **Orch-run, ~2–3 tuning passes** (judge the path-to-ground scale + tone contrast in-context at game zoom). This is a near-trivial extension of a proven script — the lowest-risk possible path to a Sponsor-approved path surface.

**REJECTED gen alternatives:** PixelLab seamless-tile (no full-bleed floor gen, 32px Wang cap, can't guarantee zero-green or the scale — `pixellab-pipeline.md` §1100-1102; same reasons the cobble base went procedural); editing any old asset (the slab raster is dead). **No PixelLab needed for the path** — the loved procedural tech covers it.

---

## 3. THE VARIED GROUND — cobble as PARTS, not a carpet (Sponsor's words)

### 3.1 The composition: worn dirt is the MAJORITY; grass + cobble are PARTS

Per Sponsor — *"The cobblestone should only be parts of the walking background"* — the ground is no longer wall-to-wall cobble. It is a **composition of three ground materials** (look at Graveyard Keeper `11h18_12` + Stardew-like `11h19_36`):

| Material | Proportion (rough) | Where it appears | Why it's there (use-story) |
|---|---|---|---|
| **Worn dirt / bare earth** | **MAJORITY (~55–65%)** — the dominant walking background | The broad open yard between landmarks; the most-walked-but-unpaved ground; building approaches | A monastery yard is mostly trodden earth — feet wore the ground bare. This is the new "default" ground, replacing the old cobble carpet. (Graveyard Keeper's ground is mostly this.) |
| **Grass / reclaimed patches** | **~20–30%** | Edges, corners, the spaces between desire-lines, around the north wall + shadowed building bases, ringing the springs/garden | Where feet DIDN'T fall, nature took back. Grass reads "this corner is unused / reclaimed" — the ALIVE lever. (Soft organic borders with dirt, never hard edges — see `11h19_36`.) |
| **Cobble patches** | **~10–20% — PARTS, not a carpet** | A few surviving paved areas: a worn apron near the well, a patch by a building entrance, an old courtyard remnant near the central building | The bits of old paving that survived — "humans laid stone here once." Cobble is now a STORY ELEMENT (surviving paving), not the floor. Uses the LOVED ground-cobble gen at its current ~18px-stone scale. |

Plus the **fine-cobble LANE** (§2) threading through, the dominant wayfinding element — distinct from the surviving cobble patches by being finer + warmer-lighter + lane-shaped.

**This effectively MERGES the deferred "deliberate planting/vegetation" direction** (`art-direction.md` § "Reconciling drop-the-grass"). The grass patches here ARE the start of that deliberate-planting pass — composed grass+reclamation at edges/corners (not baked speckle). The fuller flowering-bush / planter layer (`art-direction.md` lush pole) still layers on top later as decoration props; this spec authors the GROUND-LEVEL grass-patch foundation it sits on. **Note for Priya:** the deferred deliberate-planting direction is now partly absorbed into this ground spec (grass patches as a ground material); the prop-level flowering decoration remains a future pass.

### 3.2 How the materials compose (the lived-in read)

- **Dirt is the connective tissue** — the open background ground. Reuse the cobble doctrine's dirt hexes (`#6B5A41` dirt / `#54452F` dirt_deep, already in `S1_YARD_FLOOR_DOCTRINE`) as a worn-earth ground surface. The dirt should have organic tonal variation (lighter worn-through where walked, darker damp in shadow) — the same noise-driven variation the cobble gen uses, applied to a dirt field.
- **Grass meets dirt in SOFT organic borders** — never a hard tile edge (look at `11h19_36`: the dirt-grass boundary is irregular, feathered). Drew composes grass patches with the existing grass props / a grass ground-tile, feathered into the dirt. Grass clusters where the tonal-anchor says (corners, edges, shadowed bases, around water/garden).
- **Cobble patches are deliberate survivors** — placed where the story wants them (well apron, a building entrance, a central-courtyard remnant), using the LOVED ground-cobble gen. They read as "old paving that survived," bordered by dirt + grass invasion at their edges (the cobble doctrine's existing dirt/moss-invasion fields do this for free).
- **The fine-cobble LANE cuts through all of it** — the one continuous element, the desire-line, finer + warmer than the cobble patches, unmistakably a path.

**Composition discipline (BIG/ENDLESS tie):** variety concentrated where the story is (lane + cobble patches + grass at landmarks/edges); broad worn-dirt openness BETWEEN. Density at landmarks, openness between — the parent vision's rule (`s1-cloister-yard.md` §2.3), now expressed across THREE ground materials instead of one cobble field. The variety prevents tile-repeat across the wide scroll without crowding the open sightlines.

### 3.3 Ground gen-method per surface

| Surface | Gen method | Notes |
|---|---|---|
| **Worn dirt / bare earth (the majority ground)** | **PROCEDURAL** — a dirt-field variant of the loved gen, OR a seamless noise-driven dirt tile (3–4 toroidal variants, organic tonal variation, `#6B5A41`/`#54452F` + worn-lighter/damp-darker). Lowest-risk: extend `gen_s1_cobble_floor.py`'s noise scaffolding to emit a stone-free worn-earth field. | The new dominant ground. Must be seamless + varied (anti-repeat across the wide yard) + ZERO green. ~2 tuning passes. |
| **Grass patches** | **REUSE existing grass props/tile** + Drew composes feathered borders. If a seamless grass ground-tile is needed, a simple noise-driven green-tonal tile (separate from dirt) — but **prefer composing existing grass decoration over a new grass carpet tile** (grass is meant to read as deliberate reclamation patches, not a lawn). | Grass is the deliberate-planting foundation (§3.1). Soft organic borders into dirt — Drew craft. |
| **Cobble patches (surviving paving)** | **REUSE the LOVED ground-cobble gen** (`gen_s1_cobble_floor.py`, current ~18px-stone fine plan, `S1_YARD_FLOOR_DOCTRINE`). No new gen. | Already locked + loved. Just painted as PATCHES, not wall-to-wall. |
| **Fine-cobble LANE (the path)** | **PROCEDURAL** — the finer+warmer cobble variant per §2.4. | The headline new gen. ~2–3 passes. |

**Net new gen for this spec:** (1) the fine-cobble PATH variant (§2.4) + (2) a worn-DIRT field tile/variant. Both are extensions of the LOVED cobble generator's proven toroidal-Voronoi/noise scaffolding — NOT new models, NOT PixelLab. The cobble patches reuse the locked gen; grass reuses existing props. **No PixelLab seamless-tile needed anywhere in this spec.** (If Drew finds a dirt→grass or dirt→cobble transition needs a dedicated seamless-blend tile beyond feathered painting, flag it — but the primary approach is painted feathered borders, not a Wang-blend tile, since PixelLab's blend tools cap at 32px and can't guarantee zero-green.)

---

## 4. WATER FEATURES + OTHER YARD BEATS — carried forward UNCHANGED

The well (hero landmark prop), springs (scattered damp seeps), garden bed gone wild, drainage gutters, and damp building-base aprons are **carried forward exactly as specced in `s1-yard-ground-composition.md` §3–§4** — they sit IN this varied ground unchanged. The only update: they now sit in a **varied dirt+grass+cobble ground** instead of a cobble carpet, which only HELPS them (the well apron's surviving cobble, the spring's damp grass-ring, the garden's tilled dirt all read more naturally in a varied ground than in a uniform cobble field). No re-spec needed; cross-reference §3–§4 of that doc for the well/spring/garden/gutter gen + composition.

- **Well:** hero prop, south-central, ringed by a **surviving cobble apron** (§3.1 cobble-patch logic) — the most-walked-and-paved spot. New gen (1 hero prop) per `s1-yard-ground-composition.md` §6.2.
- **Springs:** scattered damp seeps in low/shadow corners, ringed by the **wettest grass + damp dirt** (now even more natural in a grassy corner). 1–2 tile accents per that doc.
- **Garden bed gone wild:** tilled DIRT (now native to the ground) + overgrown grass/weeds — sits naturally in the varied ground. Reuse existing.
- **Drainage gutters + damp building-base aprons:** carried forward (secondary / free).

---

## 5. NO BAKED VEGETATION — the load-bearing rule (carried forward, applies to ALL ground tiles)

**Every ground + path TILE contains ZERO green vegetation pixels.** This is the rule that killed the twice-rejected `floor_sandstone.png` (baked green dots) and it applies to the path cobble, the dirt field, AND the cobble patches:

- **Path tile, dirt tile, cobble-patch tile all ship clean** — joints/gaps get dirt-shadow (`#3D372F`) ONLY, never a green sprout/dot/speckle.
- **Grass is a SEPARATE composed layer** — grass patches (§3.1) are painted decoration (existing grass props / a deliberate grass-patch tile), placed by Drew at chosen cells with feathered organic borders, NOT baked into the dirt/cobble/path tiles. This is the AC9 "paint-not-stack" discipline: grass is a deliberate-planting LAYER, never a property of the walking-surface tile.
- **The litmus test:** eye-dropper any pixel of the path tile, the dirt tile, or the cobble-patch tile — it is warm-grey-cobble, dirt-brown, or dirt-shadow. If ANY pixel of those tiles reads green, the gen is wrong; regen. (Grass-patch decoration tiles ARE green — but they are a separate, deliberately-placed layer, not the walking-surface base.)

**Why, for the next implementer:** Sponsor rejected baked-in green explicitly; vegetation in this project is a DELIBERATE-PLANTING pass (composed clusters at edges/landmarks), never a ground-tile property (`art-direction.md` § "Reconciling drop-the-grass"). v2 makes grass a first-class GROUND MATERIAL (§3) — but as a composed/painted patch layer, never as speckle baked into the walking tiles.

---

## 6. COMPOSITION MAP — one coherent lived-in, varied yard

```
  ↑ (world continues N — chapel range off-frame; grass + damp base apron grounds it)
  ░░░░ chapel face / bell-tower ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
  ┊ ,,grass,,        [worn DIRT — the open background ground]            ┊
  ┊ ,,corner,,   ▓▓cobble▓▓                                              ┊
SPAWN ===fine-cobble LANE (warm, finer, "walk here")=================►  DESCENT
  gate   ▓CENTRAL▓ (lane branches: N to chapel / S to well)    curving   ┊  (east —
  ┊  · dirt ·▓BLDG▓· dirt ·  ,,grass edge,,                    east      ┊   ember
  ┊         [dirt desire-shortcut ··· toward well]                       ┊   glow)
  ┊                  ◉ WELL (surviving-cobble apron, NPC seed)            ┊
  ┊  ~spring~      [garden bed: tilled dirt + weeds]   ░ outbuilding ░   ┊
  ┊  (damp grass    ,,grass,,                       dormitory ruin       ┊
  ┊   ring)                                          (grass + damp apron) ┊
  ░░░░ dormitory range (grass + damp mossy base apron) ░░░░░░░░░░░░░░░░░░░
  ↓ (world continues S)
  LEGEND: === fine-cobble lane  · worn dirt  ,,grass,, patches  ▓ cobble patch  ~ spring  ◉ well
```

**The reading (what the player perceives):**
1. **Spawn:** the eye lands on the FINE warm-cobble LANE leading east across the worn-dirt ground — instant, humble wayfinding ("the path goes that way") + grass softening the edges. The lane reads as a real village footpath, not a monument.
2. **Walking the lane:** fine worn cobble underfoot, broad worn dirt to the sides, grass reclaiming the corners, a surviving cobble patch by a building. The ground tells you where people walked (lane + dirt) AND where they didn't (grass).
3. **The central-building decision:** the lane branches N/S; a dirt shortcut to the well rewards reading the ground.
4. **The well:** a hero landmark ringed by a surviving-cobble apron, with a spring + garden-gone-wild + grassiest corner nearby — the most-alive, most-reclaimed pocket.
5. **Toward the descent:** the lane curves east, the varied ground opening toward the far-outbuilding vista — the journey continues.

**Why it reads "real lived-in monastery, not arena":** the ground is a RECORD of use across THREE materials — a humble worn cobble lane + broad trodden dirt + grass where nature took back + surviving cobble patches. Mostly-dirt-with-cobble-as-parts is exactly Sponsor's direction and exactly the Graveyard Keeper / Stardew / village references. A player reads the vanished community from the ground alone.

---

## 7. HTML5 / WebGL2 RISK SURFACE

| `html5-export.md` class | Application |
|---|---|
| **HDR modulate clamp** | All `S1_PATH_COBBLE_DOCTRINE` + reused dirt/cobble hexes sub-1.0 every channel — verified §2.3. |
| **Polygon2D → ColorRect rule** | All ground/path surfaces are TileMap render-path (safe). NO animated cue on the ground in S1 (still worn surfaces = zero gate). Any future ground-light/water-glint cue is a rotated/positioned **ColorRect with modulate tween, NEVER a Polygon2D** (PR #137 HDR-clamp + Polygon2D + WebGL2 invisibility precedent). |
| **Z-index** | Path lane, dirt, grass, cobble patches all floor-layer z=0; the path/ground/patch boundaries are flat ground transitions resolved by tile-painting (one class per cell) + feathered borders, NOT stacked z — avoids the camera-scroll z-fight class (`camera-scroll.md`). No negative z-index (PR #137). Grass-patch decoration props z=+0 over floor (or as a feathered overlay tile at z=0). |
| **Visual-verification gate** | Mechanical correctness (tiles paint seamless, no z-fight, scale/tone contrast holds, zero-green) is Playwright/Drew self-soak territory; the SUBJECTIVE FEEL — "does the fine-cobble lane read as a REAL humble path (not too big, not a slab)?", "is the ground convincingly VARIED (dirt majority + grass + cobble parts), not a carpet?", "is there ZERO green baked in the walking tiles?", "does it match the inspiration refs?" — is the **Sponsor-soak taste call** (the visual gate of record for this thrice-rejected surface). Probe targets feed the soak handoff. |

---

## 8. ASSET / GEN SUMMARY (for orch gen + Drew composition)

### 8.1 NEW GEN (orch-run, procedural — extends the LOVED cobble gen)
| Gen | Method | Intent | Passes |
|---|---|---|---|
| **Fine-cobble PATH variant** | `gen_s1_cobble_floor.py` finer-radii + `S1_PATH_COBBLE_DOCTRINE` (a `--profile path` flag or thin sibling script) | The walkable lane — fine warm-grey cobble, finer + warmer-lighter than the ground cobble, ZERO green. 3–4 seamless variants. | 2–3 |
| **Worn-DIRT field tile** | Extend the same gen's noise scaffolding to a stone-free worn-earth field (`#6B5A41`/`#54452F` + worn-lighter/damp-darker), seamless, ZERO green. 3–4 variants. | The new majority background ground. | ~2 |

### 8.2 REUSED (no gen)
- **Ground COBBLE patches:** `gen_s1_cobble_floor.py` output (LOCKED, current fine plan, `S1_YARD_FLOOR_DOCTRINE`) — painted as PATCHES, not a carpet.
- **Grass:** existing grass props / decoration — composed as feathered reclamation patches (the deliberate-planting foundation).
- **Well / springs / garden / gutters:** carried forward from `s1-yard-ground-composition.md` §6 (1 hero well prop + 1–2 spring tiles already scoped there).

### 8.3 DREW COMPOSITION (Stage C — placement + aging craft, no new model)
- Paint the fine-cobble LANE as a humble worn village footpath threading the yard (spawn → curving spine → descent; N/S branches at central building; well approach) — §2, §6.
- Paint the worn-DIRT field as the broad background ground (the new majority) — §3.
- Compose GRASS patches with feathered organic borders into the dirt, clustered at corners/edges/shadowed bases/water/garden — §3.2, §5.
- Paint surviving COBBLE patches (well apron, building entrance, courtyard remnant) using the locked ground-cobble gen — §3.
- Validate the path-to-ground SIZE + TONE contrast + all eye-dropper pins in-context at game zoom + `char_scale=0.6` — §2.2.
- Carry forward well/spring/garden/gutter/damp-apron placement (`s1-yard-ground-composition.md` §6.3) into the varied ground.

### 8.4 RETIRED (do NOT ship)
- **`s1-slab-path-texture.md` ashlar approach** — dead (third rejection). Do not gen `gen_s1_slab_path.py` / any broken-course ashlar slab. The path is fine cobble.
- **`floor_sandstone.png` as path** — dead (rejected twice prior). Keep only as deprecation reference.
- **Wall-to-wall cobble carpet** — dead; cobble is now PARTS of the ground.

---

## 9. CROSS-REFERENCES
- `inspiration/2026-06-08_08h00_28.png` (village street = THE path target), `2026-06-08_11h18_12.png` (Graveyard Keeper = THE ground target), `2026-06-08_11h19_36.png` (Stardew dirt+grass patchwork), `2026-06-08_07h54_44.png` (worn-blended discipline) — ground truth; LOOK at them.
- `tools/gen_s1_cobble_floor.py` — the LOVED procedural cobble tech this spec extends for BOTH new surfaces (path variant + dirt field); the scale-lever mechanics (lines 176–192); the locked ground-cobble plan reused for cobble patches.
- `team/uma-ux/s1-yard-ground-composition.md` — §3–§4 (well/springs/garden/gutters/damp-aprons) carried forward UNCHANGED into this varied ground; §1 tonal anchor parent.
- `team/uma-ux/s1-slab-path-texture.md` — **RETIRED by this doc** (the dead ashlar approach); kept for history only.
- `.claude/docs/art-direction.md` — the inspiration north-star; § "Reconciling drop-the-grass" = vegetation-is-deliberate-planting (now partly absorbed as the §3 grass-patch ground material).
- `.claude/docs/html5-export.md` — HDR-clamp sub-1.0; Polygon2D→ColorRect (PR #137); z-index; visual-verification gate + Sponsor-soak routing.
- `.claude/docs/pixellab-pipeline.md` §1100-1102 — why PixelLab is NOT the gen path (no full-bleed floor gen, 32px cap); the procedural-is-correct evidence.
- `team/uma-ux/palette.md` § "Stratum 1 env ramp" + `S1_YARD_FLOOR_DOCTRINE` (cobble/dirt source hexes); anti-list PL-09 (no pure-black), PL-04 (zero-green guard at floor level).
- `team/TESTING_BAR.md` §"judge art in context" — path + ground judged composed at game zoom + `char_scale=0.6`, never isolated swatches.
- `~/.claude/skills/game-art/SKILL.md` — "same object = same color family" (one cobble family for path + patches), "test silhouette at gameplay distance" (judge in-context), "art serves gameplay" (the lane's job is wayfinding).
- Memory: `tile-scale-small-player-large-world`, `s1-cloister-yard-open-world-direction`, `world-feel-big-and-endless`, `sponsor-prefers-ai-gen-tile-quality`.

---

## 10. Decision draft + Sponsor sign-off surface

**Decision draft** — for Priya's weekly `DECISIONS.md` batch (NOT direct-edited per Uma role rule):
> **S1 ground + path RE-SPECCED to v2 after the THIRD path rejection** (`s1-ground-composition-v2.md`; RETIRES the `s1-slab-path-texture.md` ashlar approach + the wall-to-wall-cobble ground assumption). Sponsor 2026-06-08 soak, verbatim: *"the path is too big and not at all like a real path"* + *"Fine small-cobble pavers is preferred. The cobblestone should only be parts of the walking background."* Two coupled changes: **(1) PATH = fine small-cobble pavers** (village-street ref `08h00_28`) — a FINER + warmer-lighter VARIANT of the LOVED procedural cobble generator (`gen_s1_cobble_floor.py`), NOT slabs/ashlar (dead) and NOT PixelLab. Path stone renders ~10–14 screen px (finer than the ground cobble's ~18px, nowhere near player-size — the "too big" fix), `S1_PATH_COBBLE_DOCTRINE` warmer+lighter than ground cobble for the "walk here" contrast, humble village-lane width, ZERO baked green. **(2) GROUND = varied, cobble as PARTS** (Graveyard Keeper / Stardew refs) — worn DIRT becomes the majority background (~55–65%), GRASS patches reclaim edges/corners (~20–30%, the deliberate-planting foundation, painted/feathered not baked), surviving COBBLE patches are PARTS (~10–20%, reuse the locked ground-cobble gen). EXECUTION INSIGHT: lean on the LOVED cobble tech (Voronoi) for both new surfaces — fine-cobble path variant + worn-dirt field variant are one-parameter extensions of the proven script, NOT new procedural art (the ashlar miss proved fresh procedural art is the risk). Merges the deferred deliberate-planting direction (grass now a first-class ground material). Well/springs/garden/gutters carry forward unchanged into the varied ground. Gen: 2 new procedural surfaces (path variant + dirt field), ~2–3 passes each, orch-run; cobble patches + grass reuse existing. Sponsor soak is the visual gate of record (real-humble-path / varied-not-carpet / zero-green / matches-refs are taste calls). Reversibility: 2 tunable gen extensions + tile-painting — fully revertible.

**Sponsor sign-off surface (veto/approve before generation/build):**
1. **The hard pivot** (§0): the slab/ashlar path is DEAD; the path is fine small-cobble pavers; the ground is varied (cobble as PARTS). Right read of your direction?
2. **Path = fine-cobble variant of the LOVED gen** (§2): a finer + warmer-lighter tuning of the proven cobble generator, not slabs, not a new model. Right call to lean on the loved tech?
3. **Path scale** (§2.2): finer than the ground cobble (~10–14px), humble village-lane width, nowhere near player-size. Right after three "too big" rejections?
4. **Varied ground** (§3): worn dirt majority + grass patches + cobble-as-parts, matching Graveyard Keeper / Stardew / village refs. Right proportions + materials?
5. **Grass as a ground material** (§3.1/§5): grass returns as composed/painted reclamation patches (the deliberate-planting foundation), ZERO green baked in the walking tiles. Right balance?
6. **Gen method** (§2.4/§3.3): extend the loved cobble generator for both path + dirt (procedural, not PixelLab, not a new model). Right path?
