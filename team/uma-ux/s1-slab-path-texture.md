# S1 Slab-Path Texture — RETIRED (DEAD — third path rejection)

> **⛔ RETIRED 2026-06-08 — DO NOT IMPLEMENT.** This ashlar/cut-stone slab-path approach
> was **rejected a third time** in soak. Sponsor verbatim: *"the path is too big and not at
> all like a real path… Fine small-cobble pavers is preferred. The cobblestone should only be
> parts of the walking background."* Big flat cut pavers — irregular or not, at any scale — are
> the wrong shape for a real path. **The path is now FINE SMALL-COBBLE PAVERS (a finer/warmer
> variant of the LOVED `gen_s1_cobble_floor.py`), and the ground is varied (cobble as PARTS,
> not a carpet).** See the live spec: **`team/uma-ux/s1-ground-composition-v2.md`.**
> Do NOT generate `gen_s1_slab_path.py` / any broken-course ashlar slab. The content below is
> kept for history only.

---

# (HISTORICAL) S1 Slab-Path Texture — "Cut Processional Stone, Worn Smooth by Centuries of Feet"

**Owner:** Uma (Stage A — vision/direction) → orch (PixelLab/procedural gen, orch-only) → Drew (Stage C — paint into the held PR #426 or a follow-up) · **Phase:** M3 S1 spatial pivot, ground LAYER, slab-path MATERIAL.
**Extends / replaces:** `s1-yard-ground-composition.md` §2 assumed the SET-ASIDE `floor_sandstone.png` could be reused verbatim as the slab-path material. **That reuse is now DEAD.** Sponsor rejected the reused asset TWICE in soak — first "too big," then "awful." Drew read the asset and confirmed the root cause: it has **bright green moss-sprout DOTS baked into the joints** + **grid-regular identical square pavers**. This doc specs a NEW slab texture to replace it. Everything else in §2 (where the slabs run, the worn-center/mossy-edge composition, the warm-path-through-cool-cobble contrast) carries forward unchanged — only the MATERIAL changes from "reuse the old asset" to "gen a new one per this spec."
**Sponsor input that drove this:** two soak rejections of `assets/tilesets/s1_cloister/floor_sandstone.png` reused as the slab path — "too big" (scale), then "awful" (the baked green dots + grid read).
**OOS:** generating the asset (orch runs the gen); code / `.tscn` / collision / nav / placement (Drew, Stage C — held PR #426 or a follow-up); ticket breakdown (Priya); the cobble-base material/scale (LOCKED, this is the path-on-top); the LUSH deliberate-planting / decoration pass (a SEPARATE future Uma spec — see §2 explicit note); S2+ biomes. No Tess gate — this is a vision/direction doc feeding a downstream gen + Drew ticket.

---

## 1. TONAL ANCHOR (lead with this — everything ladders down)

> **The slab path reads as "the one stretch of ground the monks cut and laid deliberately — big flat cut-stone pavers, every one a slightly different shape and size, fitted by hand and then walked smooth over centuries until the centers shine and the edges sank. It is the oldest, most-deliberate, most-USED surface in the yard: where you put your feet is where a thousand monks put theirs. Worn, not pristine; cut, not blocky; a warm processional ribbon you instantly read as 'this is the way.'"**

Same overarching feel-gate as the parent vision — **BIG + ENDLESS + ALIVE + WONDROUS + JOURNEY** (`s1-cloister-yard.md` §0.5/§0.6) — expressed at the path-material level:
- **JOURNEY** — the slab path is the literal desire-line. It must read at a glance as "walk here," warmer + larger-stone than the cool cobble around it. Wayfinding is the path's primary job.
- **ALIVE** — the wear records use. Foot-polished smooth centers + sunk cracked edges + dirt in the joints = a surface that says "people walked here every day for centuries," not a stamped texture.
- **BIG/ENDLESS** — irregular, organic pavers (no two the same, no grid) keep the path from exposing its own tiling across a multi-screen scroll. A grid of identical squares is the single fastest way to make a big world read as a small tiled one (this is exactly what got rejected).

**The two reference poles (look at the images — `inspiration/2026-06-08_07h53_24.png` + `..._07h54_44.png`):**
- **Garden (`07h53_24`):** the concentric warm-tan paver path is the target SHAPE — irregular cut-stone pavers, varied sizes, darker grout/dirt in the joints, organic edges. Vegetation in that image is **clustered bushes at the path EDGES, never baked dots IN the pavers.**
- **Village (`07h54_44`):** worn multi-tone blended flagstone — cream/tan/grey across the field, aged and walked-on, **never a uniform tile grid.** Grass/dirt invade the joints and worn patches, but as natural invasion, not stamped speckle.

**Anti-list (what got rejected — explicitly cut):**
- **NO grid of identical squares.** The pavers are irregular polygons of VARIED size and shape, hand-fitted. A repeating square grid is the rejected read and the #1 thing to avoid.
- **NO baked green moss-sprout dots.** ZERO green vegetation pixels in the tile. This is the load-bearing rule of this spec — see §2.
- **NO pristine / freshly-laid look.** The slabs are the ABANDONED, sunk, cracked, foot-worn material. A clean swept path breaks "abandoned monastery."
- **NO "too big" single-paver scale** that reads player-sized. Pavers are a clear step UP from the fine cobble but still a SMALL element in the big yard (§3).
- **NO Polygon2D** for any path-light / wear-shimmer cue (§5 — ColorRect-rotated-rect per `html5-export.md` PR #137).

---

## 2. NO BAKED VEGETATION — the load-bearing rule (read this before generating)

**The tile contains ZERO green vegetation pixels.** The rejected `floor_sandstone.png` baked bright green moss-sprout DOTS into the joints — that is the precise thing Sponsor called "awful." The new slab tile's joints get **a subtle dark grout / dirt-shadow ONLY** (`#3D372F` joint-deep, the same hex the cobble doctrine uses), never a green sprout, never a moss dot, never a speckle.

**Why no baked vegetation, stated for the next implementer so it is NOT re-baked:**
1. **Sponsor rejected baked-in green explicitly** ("awful" = the green dots). Re-baking ANY green into the slab tile re-creates the rejected asset.
2. **Vegetation in this project is a DELIBERATE-PLANTING pass, never a ground-tile property.** Per `.claude/docs/art-direction.md` § "Reconciling with the drop-the-grass decision": Sponsor's "drop the grass" was a rejection of ugly baked-in moss/spiky tufts, NOT a rejection of vegetation. Vegetation returns LATER as **deliberate, high-quality, clustered planting** (flowering bushes, layered greens, real planters) composed AT the path edges and landmarks — exactly the garden reference's "bushes ring the path, joints stay clean" read. That is a **separate future Uma spec → Drew ticket** (the "deliberate-planting / decoration pass"), NOT part of this slab texture.
3. **Seam moss is PAINTED, not baked (AC9).** Where the parent composition (`s1-yard-ground-composition.md` §2.3) calls for moss creeping into the slab→cobble seam, that moss is a SEPARATE painted decoration layer (existing `moss_patch` prop / cobble moss accent), placed by Drew at chosen seam cells — it is NOT a pixel inside the slab tile. The slab tile ships clean; the seam look is composed on top. This is the AC9 "paint-not-stack" discipline (§5).

**The litmus test for the generated tile:** eye-dropper any pixel — it is warm-sandstone, dirt-shadow, or grout. If ANY pixel reads green, the gen is wrong; regen.

---

## 3. LOOK — irregular worn cut-stone pavers (the craft)

### 3.1 Material read — the four levers

| Lever | Slab-path application |
|---|---|
| **Irregular cut pavers** | Large FLAT cut stones, each a different polygon shape + size, hand-fitted with thin irregular grout gaps between them. The eye must read "deliberately cut + fitted by hand," NOT "stamped square grid" (the rejection) and NOT "rounded set-stones" (that's the cobble — the cobble doctrine §3.3 explicitly authors ROUNDED domed stones; slabs are FLAT cut stones, the opposite read, which is what makes the path distinct from the field). Garden-reference shape: organic-edged pavers of varied size. |
| **Multi-tone worn surface** | Each paver a slightly different warm-sandstone tone across the §4 ramp — the village reference's "cream/tan/grey blended, never one flat tone." No two adjacent pavers identical. The tonal drift IS the aged-and-walked-on read. |
| **Worn-smooth centers, sunk cracked edges** | Paver CENTERS are the foot-polished highlight tone (`#A89677` — where feet fell for centuries); paver EDGES sink toward the grout with a thin dirt-shadow rim (`#3D372F`) so each slab reads slightly SUNK + settled, never flush-and-new. A cracked/displaced paver here and there (a split line in the stone) tells the abandonment story. |
| **Grout = dirt-shadow ONLY** | The gaps between pavers are thin IRREGULAR dirt-and-shadow grout lines (`#3D372F` deep, `#5C4F38` bed), varied in width, never a clean uniform mortar grid. NO green in the grout (§2). Irregular grout width is the craft that breaks the grid read. |

### 3.2 Seamless + variant-set (anti-repeat, anti-grid)

- **Seamless by construction.** The tile must wrap perfectly (toroidal) so a multi-screen processional spine never shows a seam — same hard requirement the cobble base met (`gen_s1_cobble_floor.py` HARD REQUIREMENTS #2).
- **A variant SET, not one stamp.** Author **3–4 slab base variants** (different paver-layout + crack/wear patterns) + the painter scatters them so the spine never repeats a tile in a run. A single slab stamp tiled down a long path is the grid-read failure all over again; the variant set is the structural defense. This matches the multi-variant-set discipline the cobble base + `s1-tile-rework.md` §2.2A use.
- **Wear-traces-use variants (optional, high story-value):** a "most-worn spine" variant (centers brightest, most foot-polish) for the processional spine + a "less-worn link" variant (more grout, more sink) for the side-links — so wear-level encodes how-used (parent §2.3 "the wear traces the use").

---

## 4. PALETTE — warm-sandstone family, HDR-safe, warm-path-through-cool-cobble

The slab path stays the **warm-sandstone** family already locked in `palette.md` § "Stratum 1 — Environment ramp — sandstone." Every channel sub-1.0 (HDR-clamp-safe per `html5-export.md` § Renderer / HDR modulate clamp — WebGL2 sRGB clamps `[0,1]`; sub-1.0 verified on every hex below). NO new path palette — reuse the existing ramp + the cobble seam hexes.

```
S1_SLAB_PATH_DOCTRINE = [
  "#7A6A4F",  # slab base — warm sandstone, the dominant paver tone (palette.md "Floor — base")
  "#A89677",  # slab highlight — foot-polished worn-smooth paver center (palette.md "Floor — highlight"; the wear read)
  "#5C4F38",  # slab deep — cracks, recessed/sunk paver, grout bed (palette.md "Floor — deep")
  "#9A7A4E",  # slab warm-trim variant — a slightly warmer paver tone for tonal drift (palette.md "Trim / pillar"; sparse, for multi-tone variety)
  "#3D372F",  # grout / dirt-shadow — the dirt-and-shadow joint between pavers + the sunk-edge rim (REUSE cobble joint-deep §3.2; the slab↔cobble seam hex too)
]
```

**Channel-clamp check (sub-1.0, every channel):** `#7A6A4F`=(0.478,0.416,0.310) · `#A89677`=(0.659,0.588,0.467) · `#5C4F38`=(0.361,0.310,0.220) · `#9A7A4E`=(0.604,0.478,0.306) · `#3D372F`=(0.239,0.216,0.184). All ≤ 0.66 — comfortably HDR-safe.

**The warm-path-through-cool-cobble contrast (PL-PATH-02, carried forward):** the slab base `#7A6A4F` is **perceptibly WARMER than the surrounding cobble base** `#6E665A` (the cobble is the deliberately cooler/greyer set-stone). That warm-vs-cool material contrast is the whole wayfinding payload — the eye reads the warm ribbon as "walk here" against the cool field. Preserve it: do NOT cool the slab toward the cobble, do NOT warm the cobble toward the slab.

**Eye-dropper pins (Tess QA criteria, carried forward + sharpened):**
- **PL-PATH-01** — slab-path stone reads warm-sandstone `#7A6A4F` (base) / `#A89677` (worn center).
- **PL-PATH-02** — slab path is perceptibly WARMER than the surrounding cobble `#6E665A` (material-contrast pin: "warm path through cool field").
- **PL-PATH-03** — slab grout / sunk-edge reads dirt-shadow `#3D372F` (no clean grid border).
- **PL-PATH-04 (NEW, the rejection guard)** — **ZERO green pixels in the slab tile.** Eye-dropper the joints: dirt-shadow `#3D372F`, never moss green. (This is the pin that proves the "awful" baked-dot rejection is fixed.)
- **PL-PATH-05 (NEW, the scale guard)** — a single paver reads clearly larger-stone than a cobble but is NOT player-sized (§5).

---

## 5. SCALE + SEAM TREATMENT

### 5.1 Scale — a clear step UP from the cobble, still small in the big yard

The rejected asset failed scale first ("too big"). Concrete target relative to the LOCKED fine cobble:

- **Cobble reference (locked, `gen_s1_cobble_floor.py`):** the LARGEST cobble renders **~18 screen px ≈ 1/3 of the 0.6-scale player** at game zoom; in-engine tile is 32px, source authored at 384px period 4. The player walks on a FINE cobble ground (`tile-scale-small-player-large-world`).
- **Slab target:** a single paver should read as a clear step UP — roughly **2.5–3× the largest cobble's footprint**, i.e. a paver renders **~45–55 screen px** at game zoom (still meaningfully SMALLER than the 0.6 player's full height ~38px tall × the footprint — a paver is "a stone you could stand on," not "a stone the size of you"). That ratio gives the "processional cut stone vs rough field" read the spec wants WITHOUT the rejected player-sized "too big."
- **In-engine tile stays 32px** (chunk grid `tile_size_px=32`, unchanged) — "larger pavers" means the PAVER pattern within each 32px tile is coarser than the cobble's (fewer, bigger stones per tile), NOT a different grid size. Author the source at the same 384px-class resolution as the cobble so slicing math is unchanged; the pavers within are 2.5–3× the cobble stones.
- **Drew validates the slab-to-cobble size ratio IN-CONTEXT** (slab spine tiled through the fine cobble at game zoom + `char_scale=0.6`, per `TESTING_BAR.md` § "judge art in context") — the paver reads clearly larger-stone than the cobble but still a small element in the big yard. Never judge the slab as an isolated swatch.

### 5.2 Seam treatment at the slab↔cobble boundary (AC9 paint-not-stack)

The slab path is a SECOND floor-tile class painted beside/over the cobble at the SAME z=0 (floor layer; props z=+1; no negative z-index — `html5-export.md` § Z-index, PR #137). The slab/cobble boundary is a flat ground transition, resolved by tile-painting (one class or the other per cell), NOT stacked z (avoids the camera-scroll z-fight class, `camera-scroll.md`).

- **The seam hex is the shared dirt-shadow `#3D372F`** (the slab grout hex IS the cobble joint-deep hex — one palette across the whole ground, so the seam reads as a continuous dirt-and-shadow line, not a hard clean cut between two materials).
- **NO green dots at the seam (AC9 paint-not-stack).** The parent composition wants moss creeping into the seam — but that moss is a SEPARATE painted decoration layer (existing `moss_patch` prop / cobble moss accent), placed by Drew at CHOSEN seam cells, NOT baked into the slab tile and NOT baked into a seam tile. The slab tile ships clean (§2); Drew composes the mossy-seam look on top by painting moss decorations where he wants them. This is the AC9 discipline: paint the decoration as a layer, don't stack it into the base material. The slab edge itself gets only the dirt-shadow sunk-rim (`#3D372F`), never a green pixel.
- **Optional seam tile (defer-able):** if a dedicated slab→cobble transition tile helps Drew avoid a hard butt-join, it is a thin `#3D372F` deep + `#5C4F38` bed dirt-line tile — warm-sandstone-side fading to cobble-side, NO green. Secondary; the painted-decoration approach above is the primary.

---

## 6. GEN METHOD RECOMMENDATION (orch executes; I do not)

**Recommendation: PROCEDURAL — extend `tools/gen_s1_cobble_floor.py`'s proven approach into a sibling `gen_s1_slab_path.py`, using the rectangular broken-course (ASHLAR) stone model, NOT Voronoi.**

Reasoning, ranked against the three candidate paths:

1. **Procedural (RECOMMENDED).** Three independent confirmations point here:
   - **Sponsor already chose procedural over PixelLab for the cobble base** for exactly this problem class — the cobble generator's header records: *"Sponsor decision 2026-06-07: procedural over PixelLab. PixelLab's seamless Wang tool caps at 32px/tile; the Sponsor wants HIGHER-quality (higher-res + seamless + genuinely varied). Procedural delivers all three."* The slab path has the identical requirement set (higher-res + seamless + genuinely varied irregular pavers). Same decision applies.
   - **PixelLab has NO full-bleed seamless-floor generator** (confirmed empirically, `pixellab-pipeline.md` §1100-1102: `create_topdown_tileset` = terrain-transition Wang; `create_tiles_pro`/`create_map_object` = transparent tokens/objects, NOT continuous floor). For a continuous crafted floor surface the reliable path is to AUTHOR the tile seamless-by-construction.
   - **The validated authoring recipe is exactly this material** (`pixellab-pipeline.md` §1102, the "broken-ashlar flagstone" recipe that "finally broke the #407 wallpaper failure"): *lay irregular rectangular stones in jittered offset courses, 1px mortar gap, per-stone flat doctrine tone with a few worn-lighter stones, a 1px lit lip top+left + 1px shadow bottom+right (carved relief), wrap stone x-positions and course heights toroidally for seamlessness.* It explicitly notes: **"the rectangular broken-course (ashlar) model is the correct shape for cut flagstone; Voronoi reads as angular shards/scales and is NOT."** The cobble generator's additively-weighted toroidal Voronoi (right for ROUNDED cobbles) is the WRONG model here — slabs need the broken-course ashlar model. Reuse the cobble generator's toroidal-wrap + doctrine-lock + variant-set scaffolding, swap the stone model from Voronoi to broken-course, drop the rounded-dome shading for flat-cut-relief shading, and the green/moss invasion field is REMOVED entirely (§2 — no baked vegetation).
   - **Bonus:** procedural gives exact, code-level control over (a) zero green pixels by construction, (b) the precise paver-to-cobble scale ratio (§5.1), (c) HDR-safe doctrine hexes baked in, (d) the variant set — all the rejection-fix levers in one tunable script.

2. **PixelLab seamless-tile.** REJECT for this surface. The seamless-tile technique caps at the 32px Wang ceiling, cannot guarantee zero-green by construction (the model picks its own colors; would need a post doctrine-lock pass to strip green and even then can't guarantee a clean irregular-paver shape), and PixelLab has no full-bleed floor generator (above). It is the path that PRODUCED the rejected-asset class of problem.

3. **Edit the existing `floor_sandstone.png` (strip green + de-grid).** REJECT. The asset is 128×128, grid-regular, and the green is baked INTO the joints between identical squares — stripping the green leaves the rejected GRID (the "too big" + uniform-square read), and de-gridding a baked square-paver raster into irregular hand-cut pavers is not an edit, it's a re-authoring. Cheaper and higher-quality to generate fresh per §3 than to salvage the twice-rejected raster. (Keep the old asset only as a deprecation reference; do NOT ship it.)

**Gen budget:** one procedural script run producing **3–4 seamless slab base variants** (+ optional most-worn-spine / less-worn-link wear variants) at the 384px-class source res, doctrine-locked to `S1_SLAB_PATH_DOCTRINE` by construction. Iterate against the in-context view (slab spine composed through the cobble field at game zoom + `char_scale=0.6`) — judge the paver shape (irregular cut, not grid), the scale ratio (§5.1), zero-green (§2), and the warm-path-through-cool-cobble contrast (§4). Budget 2–3 tuning passes per the cobble base's precedent.

---

## 7. HTML5 / WebGL2 RISK SURFACE

| `html5-export.md` class | Slab-path application |
|---|---|
| **HDR modulate clamp** | All `S1_SLAB_PATH_DOCTRINE` hexes sub-1.0 every channel — verified §4. |
| **Polygon2D → ColorRect rule** | The slab tiles are TileMap render-path (safe). The slab path has NO animated cue in S1 (a still worn-stone path = zero gate). IF a future path-light / wear-glint cue is ever added it is a rotated/positioned **ColorRect with modulate tween, NEVER a Polygon2D** (PR #137 HDR-clamp + Polygon2D + WebGL2 invisibility precedent). |
| **Z-index** | Slab tiles floor-layer z=0 (same as cobble); the slab/cobble seam is a flat ground transition resolved by tile-painting (one class per cell), NOT stacked z — avoids the camera-scroll z-fight class. No negative z-index (PR #137). |
| **Visual-verification gate** | Mechanical correctness (tiles paint seamless, no z-fight, scale ratio holds) is Playwright/Drew self-soak territory; the SUBJECTIVE FEEL — "do the pavers read as irregular hand-cut stone, not a grid?", "is there ZERO green in the path?", "does the slab read as a warm processional ribbon through cool cobble?", "is the scale a clear step up but not player-sized?" — is a **Sponsor-soak taste call** (the visual gate of record for this twice-rejected surface). Probe targets feed the soak handoff. |

---

## 8. CROSS-REFERENCES

- `team/uma-ux/s1-yard-ground-composition.md` §2 — the slab-path COMPOSITION (where the paths run, worn-center/mossy-edge aging, the desire-line map) this MATERIAL serves; this doc replaces only §2's dead "reuse `floor_sandstone.png`" material call.
- `.claude/docs/art-direction.md` — Sponsor inspiration north-star (the garden + village references); § "Reconciling drop-the-grass" = the vegetation-is-a-deliberate-planting-pass rule (§2 here).
- `inspiration/2026-06-08_07h53_24.png` (garden — concentric warm irregular pavers, clean joints, clustered edge planting) + `inspiration/2026-06-08_07h54_44.png` (village — worn multi-tone irregular flagstone, grass in joints not baked dots) — the ground truth; look at them.
- `.claude/docs/pixellab-pipeline.md` §1100-1102 — PixelLab has NO full-bleed seamless-floor generator; the validated "broken-ashlar flagstone" authoring recipe; ashlar-not-Voronoi for cut flagstone (the §6 gen-method evidence).
- `tools/gen_s1_cobble_floor.py` — the procedural sibling to extend (toroidal-wrap + doctrine-lock + variant-set scaffolding; the locked cobble scale this slab steps up FROM, §5.1).
- `team/uma-ux/palette.md` § "Stratum 1 — Environment ramp — sandstone" — `#7A6A4F`/`#A89677`/`#5C4F38`/`#9A7A4E` slab palette source; § anti-list (PL-09 no pure-black).
- `.claude/docs/html5-export.md` — HDR-clamp sub-1.0; Polygon2D→ColorRect (PR #137); z-index; visual-verification gate + Sponsor-soak routing.
- `team/uma-ux/visual-direction.md` — VD-13 tiles get NO 1px outline (slab tiles take no outline).
- `~/.claude/skills/game-art/SKILL.md` — general principles applied: "same object = same color family" (one sandstone ramp), "test silhouette at gameplay distance" (judge in-context at game zoom), "art serves gameplay" (the path's job is wayfinding).
- Memory: `tile-scale-small-player-large-world`, `s1-cloister-yard-open-world-direction`, `sponsor-prefers-ai-gen-tile-quality`, `world-feel-big-and-endless`.

---

## 9. Decision draft + Sponsor sign-off surface

**Decision draft** — for Priya's weekly `DECISIONS.md` batch (NOT direct-edited per Uma role rule):
> **S1 slab-path texture re-specced as a NEW asset** (replaces the dead `s1-yard-ground-composition.md` §2 reuse of `floor_sandstone.png`). Sponsor rejected the reused asset twice in soak — "too big," then "awful"; Drew confirmed root cause = baked green moss-sprout DOTS in the joints + grid-regular identical square pavers. NEW spec: **irregular worn cut-stone pavers** (garden + village reference shape — varied size/shape, multi-tone warm-sandstone, foot-polished smooth centers + sunk cracked edges, thin irregular dirt-shadow grout), warm-sandstone family (`S1_SLAB_PATH_DOCTRINE` = `#7A6A4F`/`#A89677`/`#5C4F38`/`#9A7A4E`/`#3D372F`, sub-1.0 HDR-safe, preserves PL-PATH-02 warm-path-through-cool-cobble). **ZERO baked vegetation** (the rejection cause): joints get dirt-shadow `#3D372F` ONLY; vegetation returns later as a SEPARATE deliberate-planting pass, never baked into the ground tile; seam moss is PAINTED decoration (AC9 paint-not-stack), not baked. Scale: a paver renders ~45–55 screen px (~2.5–3× the largest cobble ≈ 1/3-player), a clear step UP from the fine cobble but not player-sized. **Gen method: PROCEDURAL** — extend `gen_s1_cobble_floor.py` into a `gen_s1_slab_path.py` using the broken-course ASHLAR stone model (NOT Voronoi — ashlar is the validated shape for cut flagstone per `pixellab-pipeline.md` §1102; PixelLab has no full-bleed seamless-floor gen + Sponsor already chose procedural for the cobble base for the identical higher-res+seamless+varied requirement). 3–4 seamless variants, 2–3 tuning passes, orch-run. Sponsor soak is the visual gate of record (irregular-not-grid / zero-green / warm-ribbon / scale-step-up are taste calls). Reversibility: a tunable gen script + tile-painting — fully revertible.

**Sponsor sign-off surface (veto/approve before generation):**
1. **Tonal anchor** (§1): cut processional stone, worn smooth, the most-deliberate-and-used surface in the yard — irregular not grid, worn not pristine. Right read?
2. **No baked vegetation** (§2): zero green in the tile; vegetation is a separate future deliberate-planting pass; seam moss is painted on top. Right call?
3. **Look** (§3): irregular varied-size warm-sandstone pavers, multi-tone, worn-smooth centers + sunk cracked edges, dirt-shadow grout, 3–4-variant set. Right craft?
4. **Scale** (§5.1): a paver ~2.5–3× the largest cobble (~45–55 screen px, ~1/3 player) — clear step up but not player-sized. Right ratio after "too big"?
5. **Gen method** (§6): PROCEDURAL ashlar-model sibling of the cobble generator. Right path (vs PixelLab vs editing the old asset)?
