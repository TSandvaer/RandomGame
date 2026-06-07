# S1 Yard Ground Composition — "A Monastery Would Never Pave It All in Cobble"

**Owner:** Uma (Stage A — vision/direction) → Priya (scope/tickets) → orch (PixelLab gen, orch-only) → Drew (Stage C — yard-composition impl) · **Phase:** M3 S1 spatial pivot, ground LAYER
**Extends:** `s1-cloister-yard.md` (the merged yard vision). That doc locked the spatial pivot (one big two-axis-scrolling expanse, buildings as landmarks) + the cobble BASE floor material (`S1_YARD_FLOOR_DOCTRINE`). **This doc is the NEXT LAYER: composing variety ONTO that cobble base** so the yard reads as a real lived-in monastery, not a single uniform cobble carpet.
**Status of the base:** the procedural cobble floor (`tools/gen_s1_cobble_floor.py`) is locked. Drew is currently fixing its IN-ENGINE SCALE (was rendering ~10× too large). This spec assumes the cobble base ships at correct fine scale; it does NOT re-open the cobble material/scale decision.
**Sponsor input that drove this (2026-06-07, soak):** verbatim — *"It should NOT all be cobblestone — imagine how a real monastery would contain cobblestone WITH stone slab paths, springs, a well, etc."* The yard had become correct-but-monotonous: one material wall-to-wall. A real cloister ground is a COMPOSITION of surfaces that record how the place was used.
**OOS:** generating art (orch runs PixelLab); coding / `.tscn` / collision / nav / placement (Drew, Stage C); ticket breakdown (Priya); the cobble-base material itself (locked, this layers on top); S2+ biomes; building-wall / prop art (carried forward unchanged). No Tess gate — this is a vision/direction doc feeding a downstream Drew ticket + asset gen.

---

## 1. TONAL ANCHOR (lead with this — everything ladders down)

> **The S1 yard ground reads as "a monastery's working courtyard that nature is reclaiming: the monks laid worn stone-slab paths where they walked every day — chapel to refectory, gate to well — and left the rest as rough cobble, dirt, and garden. The processional slabs are sunk and cracked, moss has crept into every joint, and water still wells up where it always did. You can read where people LIVED by where the ground was worn smooth."**

This is the same overarching feel-gate as the parent vision — **BIG + ENDLESS + ALIVE + WONDROUS + a JOURNEY** (`s1-cloister-yard.md` §0.5/§0.6). Ground-surface variety serves ALL FIVE:
- **ALIVE** — a composed ground (paths people wore, a well still flowing, a garden bed gone wild) reads as a place that was USED, not an empty arena floor. This is the single biggest ground-level "alive" lever.
- **JOURNEY** — the slab paths are literal desire-lines: they show the player where to walk (chapel → well → descent) and reward stepping OFF them to discover the overgrown corners. Paths are wayfinding AND exploration-bait at once.
- **WONDER** — a well as a central landmark, water catching the warm brazier-light, a spring damp-darkening the cobble around it — these are wonder-beats that say "this place has a history."
- **BIG/ENDLESS** — variety prevents the wide scrolling expanse from reading as a tiled repeat. A monotone cobble carpet exposes its own tiling across a multi-screen scroll; a composed ground (paths cutting diagonals, water features breaking the field, dirt/garden patches) keeps the eye moving and the bigness feeling authored, not stamped.

**The tonal RULE for this layer:** *the ground records human use.* Every surface-variety beat must answer "why is the ground different HERE?" with a monastery-life reason (this is where they walked / drew water / grew herbs / dumped rubble), never "to break up the texture." Decoration that doesn't carry a use-story gets cut — same discipline as the parent vision's anti-list.

**Anti-list (ground beats that DON'T serve the anchor — cut them):**
- No grass FIELDS or paved plazas — monastery ground is worked and irregular, never landscaped-lawn or town-square.
- No water that reads as a hazard/FX pool (no glowing/bubbling/lava-adjacent treatment — that's S2/S6). Water here is still, dark, reflective, QUIET.
- No slab path that reads as PRISTINE — the slabs are the ABANDONED material (see §2): worn, sunk, cracked, moss-jointed. A clean swept path breaks "abandoned."
- No pure-black water (`#000000` is on the S1 anti-list, `palette.md` PL-09 — reserved S7-S8). Water is dark warm-neutral, never black.
- No Polygon2D for any water-shimmer / spring-glint / path-light cue (§5 — ColorRect-rotated-rect per `html5-export.md` PR #137 rule).

---

## 2. STONE-SLAB PATHS — the worn processional routes (the headline beat)

### 2.1 The material: the SET-ASIDE warm-sandstone flagstone IS the slab-path material

The single best material decision available is **free**: the original S1 floor — warm-sandstone FLAGSTONE (`#7A6A4F` family, `assets/tilesets/s1_cloister/floor_sandstone.png`) — was set aside when the yard re-materialed to cobble (`s1-cloister-yard.md` §3.1/§4.2). That flagstone was the WRONG call for a wall-to-wall yard floor (it read as an indoor swept hall). But it is **exactly right as the slab-path material**: large flat cut stones, processional, distinct from the rough cobble field around them. A monastery's main walking routes WOULD be laid in cut flagstone; the rough cobble is the in-between ground. **The abandoned base material becomes the path material — reuse, not regen.**

This gives a clean two-material ground read for free:
- **Cobble** (`S1_YARD_FLOOR_DOCTRINE`, cooler/grayer `#6E665A`) = the rough working ground, the between-spaces, the combat lanes.
- **Flagstone slabs** (warm-sandstone `#7A6A4F`) = the worn processional PATHS cutting through the cobble — warmer + larger-stone + flatter than the cobble around them.

The cobble-cooler / slab-warmer contrast is the same material-contrast logic the parent vision already uses for "warm buildings ON cooler cobble ground" (`s1-cloister-yard.md` §3.1) — now applied a second time so the slab paths read as warm processional ribbons threading the cool cobble field. That contrast is the whole point: a path the eye instantly reads as "this is where you walk."

### 2.2 Where the slab paths run (composition — the desire-line map)

Slab paths are NOT decorative scatter — they trace the monastery's actual circulation, which is also the player's journey (`s1-cloister-yard.md` §2.2). Three path types:

| Path | Route | Why it's there (use-story) |
|---|---|---|
| **The processional spine** | West gate (SPAWN) → curving east across the expanse → the descent stair (EAST terminus) | The main route the monks walked daily; the player's critical path. The spine is the strongest, widest, most-worn slab run — it literally shows the player "the journey goes this way." Curves (never a ruler-straight road) so it reads organic + keeps the long sightline alive. |
| **Building-to-building links** | Short slab runs connecting building entrances — chapel face ↔ central cloister ↔ dormitory range | Cloister life moved between buildings; the slabs record those routes. These branch OFF the spine at the central building (the parent vision's "choose left/right around the central building" decision beat, §2.2.3) — slabs make that choice legible. |
| **The well approach** | A slab apron ringing the WELL (§3) + a short slab run from the spine to it | Everyone drew water; the ground to the well would be the most-walked-and-worn of all. A worn slab apron around the well = a landmark you're drawn to. |

**Composition discipline (the BIG/ENDLESS tie):** paths CONNECT landmarks and leave big open cobble BETWEEN them. Density of slabs AT the landmarks (gate, central building, well, descent); open cobble in the wide-open stretches. This is the parent vision's "density at landmarks, openness between" rule (`s1-cloister-yard.md` §2.3) expressed at the ground-surface layer. The slabs should never form a grid or pave a large area — they are RIBBONS through the cobble, a few tiles wide, worn where feet fell.

### 2.3 How the slabs READ (the craft — worn + sunk + reclaimed)

The flagstone asset already exists; the composition craft is in how Drew lays + ages it against the cobble:
- **Worn-smooth centers, mossy edges.** The slab path's center tiles are the worn-smooth flagstone (foot-polished); the EDGE tiles where slab meets cobble are moss-invaded + dirt-crept (the same joint-moss `#5C7044` from the cobble doctrine bleeds into the slab joints). Reuse the cobble doctrine's moss/dirt hexes at the seam — one palette across the whole ground.
- **Sunk + cracked, not flush.** Where a slab path crosses high-traffic ground it should read slightly SUNK into the cobble (a dirt-shadow `#3D372F` rim where slab meets cobble) — abandoned + settled, never freshly-laid-flush. A cracked/displaced slab here and there (reuse `rubble_01` at a path edge) tells the abandonment story.
- **The wear traces the use.** Per the parent vision's "foot-worn lighter path can trace the spawn→descent route" lever (`s1-cloister-yard.md` §3.3): the SPINE slabs are the most worn-smooth-light; the side-links less so; a rarely-used branch can be half-reclaimed by moss. Wear-level = how-used, which is storytelling at floor level.

### 2.4 Scale + palette vs the cobble base

- **Scale:** flagstone slabs are LARGER individual stones than the fine cobble (that size contrast is what makes them read as a deliberate path vs the rough field). The existing `floor_sandstone.png` slab scale is correct for this RELATIVE to the FIXED cobble base — it was "too large" only as a wall-to-wall floor; as a path threading fine cobble, the larger slab reads exactly as "cut processional stone." **Drew validates the slab-to-cobble size ratio in-context** (slab path tiled through the fine cobble at game zoom + `char_scale=0.6`) once the cobble in-engine scale fix lands — the slab should read clearly larger-stone than the cobble but still a small element in the big yard.
- **Palette:** slabs stay the warm-sandstone `#7A6A4F` family (carried forward, sub-1.0 HDR-safe, `palette.md` env ramp). The seam moss/dirt reuse the cobble doctrine hexes. NO new path palette — the whole ground shares ONE 10-hex working palette (8 cobble + the 2 warm-sandstone path tones already in `palette.md`).

**Eye-dropper pins (Tess QA criteria):** slab-path stone reads warm-sandstone `#7A6A4F` (PL-PATH-01), **perceptibly WARMER than the surrounding cobble** `#6E665A` (PL-PATH-02 — the material-contrast pin proving "warm path through cool field"), and the slab→cobble seam carries moss `#5C7044` + dirt-shadow `#3D372F` (PL-PATH-03, no hard clean border).

---

## 3. WATER FEATURES — the WELL (central landmark) + springs

### 3.1 The WELL — a focal landmark in the yard (Sponsor named "a well")

The well is the parent vision's south-range / central landmark beat made concrete (`s1-cloister-yard.md` §2.1 already places "the cloister well" by the dormitory range). Sponsor named it explicitly — promote it to a **hero focal landmark**, a wonder-beat + NPC-station + journey-waypoint all at once:

- **Placement:** a **stone well-head as a PROP landmark**, set in the south-central yard off the processional spine, ringed by the worn slab apron (§2.2). It sits at a journey decision-point (the south route around the central building) so the player is drawn toward it. It is a LANDMARK you orient by, not a wall-edge dressing.
- **It is a PROP, not a tilemap feature.** The well-head is a `Sprite2D` prop (collision-solid, like the buildings) authored at landmark scale — tall enough to read as a structure the small player walks up to (sibling to the carried-forward `pillar_arch` at landmark scale, `s1-cloister-yard.md` §5.1). New asset gen (§5 / asset list).
- **It is an NPC-station + discovery anchor (SEED).** The parent vision reserved a "caretaker/penitent by the well" NPC-station + the well as a wonder-spot (`s1-cloister-yard.md` §0.6 Pillar A, §5.3). The well's slab apron + clear approach footprint authors that station now; populate over milestones.
- **Mystery hook (WONDER):** a faint warm glint of water deep in the well-shaft (a small dark-warm ColorRect with a subtle still highlight) — "there's water down there, this place still has life in it." A bucket/rope detail (fold into the well sprite or a tiny prop) tells "someone used this."

### 3.2 Springs — water welling up through the ground (smaller, scattered)

Beyond the one hero well, a real monastery yard has water working through the ground — **springs / seeps** where the water table surfaces. These are the cheaper, scatterable water beat:
- **What they are:** small still pools / damp seeps where water wells up between the cobbles — a low spot the ground water found. 1–2 in the yard, placed in low/shadowed corners (north-wall base, a dip near the dormitory ruin) where damp diegetically collects (same "damp zones" logic as the moss clustering, `s1-cloister-yard.md` §5.2).
- **They are a TILEMAP/decoration beat, not a prop.** A spring is a small cobble-with-standing-water patch — a **water accent tile** (or a small ColorRect-pool decoration over the cobble) ringed by the wettest moss (`#47592F` moss-deep) + dark damp cobble (`#544C42`). It reads as "the cobble is wet + sunken here," not a built structure. This keeps them cheap + scatterable vs the hero well.
- **They reinforce the living-ground story:** water + the wettest moss clustered around it = the most-alive-and-reclaimed spots in the yard. A spring is where the vine/sapling reclamation beats (`s1-cloister-yard.md` §5.3) naturally cluster — a sapling pushing up by the damp.

### 3.3 Water visual treatment (HDR-clamp-safe, ColorRect-not-Polygon2D)

Water is the highest HTML5-risk surface in this layer — author it conservatively:
- **Still, dark, warm-neutral — never black, never bright.** Water surface reads as a dark warm-neutral reflective pool. Doctrine hexes (sub-1.0 every channel, HDR-clamp-safe per `html5-export.md`):

```
S1_YARD_WATER_DOCTRINE = [
  "#2E2A26",  # water base — dark warm-neutral still surface (NOT #000000; warm, sub-1.0)
  "#3D3833",  # water mid — slightly lit reflective band
  "#544C42",  # water-edge damp cobble — the wet ring where water meets stone (REUSE cobble shadow)
  "#857C6C",  # still highlight — a quiet catch of brazier/ambient light on the surface (REUSE cobble lit; sparse)
]
```

- **Any shimmer / glint / light-catch is a ColorRect, NEVER a Polygon2D.** Per the `html5-export.md` PR #137 precedent (HDR-clamp + Polygon2D + WebGL2 invisibility): if the well's water-glint or a spring's surface-catch is animated as a moving highlight, it is a small **rotated/positioned `ColorRect`** with a `modulate.a` tween (sub-1.0, slow, subtle) — same primitive discipline the parent vision binds for the descent ember-glow (`s1-cloister-yard.md` §6). Prefer NO animated shimmer at all for S1 (a still dark pool with a fixed sparse highlight tile reads quiet + wondrous + costs zero animation gate) — if Drew adds a subtle surface-catch later it's a ColorRect modulate tween, gated by the visual-verification gate.
- **No CPUParticles2D water FX.** Drips/ripples as particles would fall under the PR #291 burst-class visual gate — out of scope for S1's quiet still water. Stillness IS the tonal call (quiet, holy, hushed).
- **Eye-dropper pins:** well/spring water reads dark warm-neutral `#2E2A26` (PL-WATER-01), is **NOT pure black** (PL-WATER-02 — anti-list compliance), wet-ring damp cobble reads `#544C42` (PL-WATER-03).

---

## 4. OTHER MONASTERY-YARD GROUND BEATS — what else authenticates a cloister yard

Propose, don't overbuild — each must carry a use-story (§1 rule). Ranked by impact-per-cost:

| Beat | What it is | Use-story | Cost / how |
|---|---|---|---|
| **Worn dirt desire-paths** | Bare-earth tracks where feet wore through to soil — branching OFF the slab spine toward the well, a building, a corner | The unofficial shortcuts people actually walked, paralleling the formal slab routes | **FREE** — reuse the cobble doctrine's dirt-through accent tiles (`#6B5A41`/`#54452F`, `s1-cloister-yard.md` §3.2) laid as a meandering track. A dirt desire-path is the cheapest "people lived here" beat and the natural complement to the formal slabs (formal slab spine + informal dirt shortcuts = real circulation). |
| **A garden / herb bed gone wild** | A bounded patch of tilled soil + overgrown weeds + maybe a sapling — a former kitchen-garden / physic-garden | Monasteries grew their own food + medicine; the abandoned bed reclaimed by weeds is pure "nature taking it back" (Pillar A, `s1-cloister-yard.md`) | **LOW** — a dirt-bed tile patch (reuse dirt hexes) + clustered grass/weeds (reuse existing) + the §5.3 sapling reclamation beat. Place near the dormitory/refectory range (where a kitchen garden would sit). One hero garden bed; not multiple. |
| **Drainage channels** | Shallow worn stone gutters running along building bases + carrying toward the low/spring spots | Cloisters managed rainwater off the roofs; a stone gutter at the building base is authentic + reads as worked-ground | **LOW** — a thin slab-gutter accent tile (reuse warm-sandstone path palette, narrow) run along building bases. Bonus: it visually CONNECTS the buildings to the springs (water logic: roof → gutter → spring/low-spot), reinforcing the living-ground story. Secondary beat — add if budget allows. |
| **Mossy/damp building-base aprons** | The cobble/ground darkening + moss-thickening in the shadow at building bases | Damp collects in shadow where sun never reaches the base of a wall | **FREE** — already covered by the cobble doctrine's moss/damp clustering rule (`s1-cloister-yard.md` §5.2); flagged here as a ground-COMPOSITION beat: the building bases should visibly read damp+mossy vs the open sun-ground, grounding the buildings into the yard. |

**The two FREE beats (dirt desire-paths + damp building-base aprons) reuse existing doctrine tiles and should ship; the garden bed is LOW-cost and high-story-value (ship one); drainage channels are a secondary nice-to-have (defer if budget tight).** Nothing here needs new palette — all reuse the cobble + path + water doctrines.

---

## 5. COMPOSITION MAP — one coherent lived-in monastery yard

How every surface layer composes into ONE ground that reads "lived-in monastery," tied to the BIG/ENDLESS/ALIVE/JOURNEY/WONDER north-stars:

```
  ↑ (world continues N — chapel range runs off-frame; damp mossy base apron grounds it)
  ░░░░ chapel face / bell-tower ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
  ┊        [drainage gutter along building base →→ toward spring]          ┊
  ┊  · cobble ·     ▓▓▓▓▓▓        · · open cobble (combat lane) · ·        ┊
  ┊   (rough        ▓CENTRAL▓                                              ┊
SPAWN══[SLAB SPINE — worn warm processional]═══════════════════════════►  DESCENT
  gate  ▓CLOISTER▓ (slab links branch here:          curving toward       ┊  (east —
  ┊  · ·▓BUILDING▓· N to chapel / S to well)          the descent)        ┊   ember
  ┊   [dirt desire-path shortcut ··· toward well]                         ┊   glow)
  ┊                  ◉ WELL (slab apron, NPC-station,                      ┊
  ┊  ~spring~       water-glint mystery hook) ◉      ░ far outbuilding ░   ┊
  ┊  (damp, wettest  [garden bed gone wild —    dormitory ruin           ┊
  ┊   moss, sapling)  tilled soil + weeds]                                ┊
  ░░░░ dormitory range (damp mossy base apron) ░░░░░░░░░░░░░░░░░░░░░░░░░░░░
  ↓ (world continues S)
  LEGEND: ═ slab spine  · cobble field  ··· dirt desire-path  ~ spring  ◉ well  ▓ building
```

**The reading, layer by layer (what the player perceives):**
1. **Spawn:** the eye lands on the WARM SLAB SPINE leading east across cool cobble — instant wayfinding ("the journey goes that way") + the wonder-vista (the parent vision's authored spawn frame, `s1-cloister-yard.md` §2.2.1). The slab path makes the big expanse READABLE, not just big.
2. **Walking the spine:** worn slabs underfoot, rough cobble to the sides (the combat lanes), dirt desire-paths branching off as exploration-bait. The ground tells you where people walked AND invites you off-path.
3. **The central-building decision:** slab links branch N (chapel) / S (well) — the parent vision's route-choice beat, now made legible by the ground itself. A dirt shortcut to the well rewards the player who reads the ground.
4. **The well:** the south route's payoff — a hero landmark ringed by a worn slab apron, water-glint mystery, the garden bed gone wild + a spring nearby (the most-alive, most-reclaimed corner of the yard). Wander-reward + NPC-station + wonder.
5. **Toward the descent:** the spine curves east, cobble opening toward the layered far-outbuilding vista (parent vision's eastern depth, `s1-cloister-yard.md` §2.2.4) — the journey continues, the world keeps going.

**Why it reads "lived-in monastery, not arena" (the binding feel-gate):** the ground is a RECORD of use — formal processional slabs + informal dirt shortcuts + a working well + a kitchen garden + drainage + damp shadow-aprons. Every surface answers "why is the ground different here?" with a monastery-life reason. A player can read the vanished community from the ground alone. That is the ALIVE north-star at floor level.

**Why it stays BIG/ENDLESS (composing with the parent vision):** variety is concentrated AT the landmarks (slab density at gate/central/well/descent; water + garden at the well; gutters at building bases) and the BETWEEN-spaces stay big open cobble. The slabs are ribbons, not pavement; the water + garden are pockets, not fields. The composed variety keeps the wide scroll from reading as a tile-repeat WITHOUT crowding the open sightlines — density at landmarks, openness between, exactly the parent vision's rule (`s1-cloister-yard.md` §2.3).

---

## 6. ASSET LIST — for Drew (composition) + orch (new gen)

### 6.1 REUSED (no gen — carry forward / re-deploy)

| Asset | Source | Re-deployed as |
|---|---|---|
| **Sandstone flagstone floor** | `assets/tilesets/s1_cloister/floor_sandstone.png` (the SET-ASIDE base material) | **The slab-path tiles (§2)** — laid as worn processional ribbons through the cobble. The single highest-value reuse in this spec. |
| **Cobble base floor** | `tools/gen_s1_cobble_floor.py` output (LOCKED; Drew fixing in-engine scale) | The rough working-ground field (unchanged — this layers ON it). |
| **Cobble doctrine accents** | dirt-through / moss / damp tiles (`S1_YARD_FLOOR_DOCTRINE`, `s1-cloister-yard.md` §3.2) | Dirt desire-paths (§4), spring damp-rings (§3.2), slab→cobble seam moss (§2.3), garden-bed soil (§4) — all REUSE these hexes. |
| **`rubble_01`** | `assets/props/s1_cloister/rubble_01.png` | A cracked/displaced slab at a path edge (§2.3 abandonment beat). |
| **Existing grass/weed + `moss_patch`** | `assets/props/s1_cloister/moss_patch.png` + grass | Garden-bed overgrowth (§4), spring-edge clustering (§3.2). |

### 6.2 NEW GEN (orch-run PixelLab, orch-session only per `pixellab-pipeline.md`)

| Gen | Tool | Intent | Scale + palette target |
|---|---|---|---|
| **WELL-HEAD prop (hero landmark)** | `create_character` / `create_map_object` (stone structure prop) | "Abandoned monastery stone well-head, round/square cut-stone rim, weathered, moss-grown base, a rotted bucket + frayed rope, dark still water with a faint glint deep in the shaft, top-down RPG landmark prop" | **Landmark scale** (reads tall like `pillar_arch` 48×64-class — a structure the `char_scale=0.6` player walks up to). Palette: warm-sandstone rim (`#7A6A4F`/`#9A7A4E`, REUSE building doctrine) + moss base (`#5C7044`) + water (`S1_YARD_WATER_DOCTRINE` §3.3). Sub-1.0 every channel. Doctrine-lock Strategy 3 per-slot nearest-neighbor. |
| **Spring / standing-water accent tile** | `create_topdown_tileset` / `create_map_object` | "Small still pool of dark water welling up between worn cobblestones, wettest moss ringing it, sunken damp ground, neglected, top-down RPG ground accent" | Tile-scale (matches cobble base). Palette: `S1_YARD_WATER_DOCTRINE` + cobble damp/moss. NO outline (VD-13). Sub-1.0. 1–2 variants. |
| **(Optional) drainage-gutter accent tile** | `create_topdown_tileset` | "Shallow worn stone drainage channel, cut-sandstone gutter, running along a building base, top-down RPG ground accent" | Narrow, warm-sandstone path palette (`#7A6A4F` family + `#3D372F` shadow). Defer if budget tight (§4 secondary beat). |

**Gen budget:** 1 hero prop (well) + 1–2 water accent tiles + 1 optional gutter tile = **2–3 gens**, 2 planned doctrine-lock passes each. Iterate against the in-context view (composed onto the cobble base at game zoom + `char_scale=0.6`, per `TESTING_BAR.md` §"judge art in context") — the well judged AS a landmark in the yard, the water tile judged AS a pocket in the cobble field, never isolated swatches.

### 6.3 DREW COMPOSITION WORK (Stage C — no new asset, placement + aging craft)

- Lay slab-path tiles as worn ribbons along the spine + building-links + well-apron (§2.2), with worn-center / mossy-sunk-edge aging (§2.3) + wear-traces-use gradient (§2.3).
- Lay dirt desire-paths as meandering reuse-tracks (§4).
- Place the well-head prop as a south-central landmark with slab apron + clear NPC-station footprint (§3.1).
- Place spring(s) in damp low/shadow corners with wettest-moss clustering (§3.2).
- Author one garden bed gone wild near the dormitory range (§4).
- (Optional) drainage gutters along building bases (§4).
- Damp mossy aprons at all building bases (§4, FREE via existing doctrine).
- Validate slab-to-cobble SIZE RATIO + all eye-dropper pins in-context once the cobble in-engine scale fix lands.

---

## 7. HTML5 / WebGL2 RISK SURFACE (constrains the primitives)

| `html5-export.md` class | Yard-ground-composition application |
|---|---|
| **HDR modulate clamp** | All new doctrine hexes (`S1_YARD_WATER_DOCTRINE` §3.3) + reused path/cobble hexes are sub-1.0 every channel — verified. Any water-glint modulate stays sub-1.0. |
| **Polygon2D → ColorRect rule** | Any water-shimmer / well-glint / spring surface-catch animated cue is a **rotated/positioned ColorRect with modulate tween, NEVER a Polygon2D** — per the PR #137 HDR-clamp + Polygon2D + WebGL2 invisibility precedent. Slab + cobble + spring tiles are TileMap render-path (safe); the well is a Sprite2D prop (safe); the rule binds ONLY a NEW animated water-light cue if Drew adds one. **Preferred: no animated water cue in S1 — still water + fixed highlight tile = zero gate.** |
| **Z-index** | Ground surfaces (cobble, slab, spring, dirt) all floor-layer z=0; the well prop z=+1 (props above floor, player above props), no negative z-index (PR #137). The slab path is a SECOND floor-layer tile-class over/beside the cobble at the SAME z=0 — Drew verifies no z-fight where slab-tile-class meets cobble-tile-class across the wide scroll (the camera-scroll `Z-index sensitivity` highest-risk class, `camera-scroll.md`); the slab/cobble seam is a flat ground transition, not an overlap, so resolve via tile-painting (one or the other per cell), NOT stacked z. |
| **Visual-verification gate** | New ground composition (slab paths, well prop, springs, garden) is HTML5-gated. Mechanical correctness (tiles paint, prop collides, no z-fight) is Playwright/Drew self-soak territory; the SUBJECTIVE FEEL — "does the composed ground read lived-in-monastery not arena?", "do the warm slabs read as paths through cool cobble?", "is the well a wonder-landmark?", "does water read quiet+still not hazard?", "does variety break the tile-repeat without crowding the bigness?" — is a **Sponsor-soak taste call** (the visual gate of record for this layer, sibling to the parent vision's soak routing, `s1-cloister-yard.md` §6). Probe targets feed the soak handoff. |

---

## 8. CROSS-REFERENCES

- `team/uma-ux/s1-cloister-yard.md` — the parent yard vision this LAYERS onto: §0.5/§0.6 north-stars (big/endless/alive/wonder/journey), §2 spatial composition (the expanse + landmarks + journey this ground threads), §3 `S1_YARD_FLOOR_DOCTRINE` cobble base (this composes variety onto it), §4.2 flagstone-set-aside (the slab-path material reuse), §5.3 living decoration (vine/sapling/NPC-stations this ground anchors), §6 HTML5 risk surface.
- `.claude/docs/html5-export.md` — HDR-clamp sub-1.0 every channel; Polygon2D→ColorRect for any animated water cue (PR #137); z-index (floor z=0, props z=+1); visual-verification gate + Sponsor-soak routing.
- `.claude/docs/procgen-pipeline.md` — `FloorAssembler.assemble_floor` + `AssembledFloor.bounding_box_px` + EAST/WEST port-mating (the yard is the multi-chunk assembled floor; slab paths + well + springs are placed-content within the assembled chunks).
- `.claude/docs/camera-scroll.md` — the two-axis scroll the composed ground is exposed across; `Z-index sensitivity` highest-risk class (slab/cobble seam verification); `Main.S1_ROOM_BOUNDS → AssembledFloor.bounding_box_px` swap.
- `.claude/docs/pixellab-pipeline.md` — `create_topdown_tileset` / `create_map_object` + doctrine-lock Strategy 3 + canvas-size trap + orch-session-only execution (well + spring + gutter gens).
- `team/uma-ux/palette.md` — S1 warm-sandstone env ramp (`#7A6A4F` floor/path, `#9A7A4E` trim, `#4A3F2E` wall — slab-path palette source); anti-list (PL-09 no pure-black — binds the water doctrine).
- `team/uma-ux/visual-direction.md` — VD-13 tiles get NO 1px outline (spring/gutter tiles take no outline).
- `team/TESTING_BAR.md` §"judge art in context" — well + ground judged composed onto the cobble base at game zoom + `char_scale=0.6`, never isolated swatches.
- Memory: `s1-cloister-yard-open-world-direction`, `tile-scale-small-player-large-world`, `m3-diablo-shape-directive`, `sponsor-prefers-ai-gen-tile-quality`.
- Carried-forward assets: `assets/tilesets/s1_cloister/floor_sandstone.png` (→ slab paths), `assets/props/s1_cloister/` (rubble_01, moss_patch, grass → ground beats); `tools/gen_s1_cobble_floor.py` (the locked cobble base this layers on).

---

## 9. Decision draft + Sponsor sign-off surface

**Decision draft (2026-06-07)** — for Priya's weekly `DECISIONS.md` batch (NOT direct-edited per Uma role rule):
> **S1 yard GROUND-COMPOSITION layer directed** (extends the `s1-cloister-yard.md` cobble-base vision; does NOT re-open the locked cobble material/scale). Sponsor 2026-06-07 soak: *"It should NOT all be cobblestone — a real monastery would contain cobblestone WITH stone slab paths, springs, a well."* Tonal anchor: **the ground RECORDS human use** — formal worn processional STONE-SLAB PATHS + informal dirt desire-paths + a working WELL + a kitchen-garden-gone-wild + drainage + damp shadow-aprons compose onto the rough cobble field so the yard reads lived-in-monastery, not arena. **Headline reuse:** the SET-ASIDE warm-sandstone flagstone (`floor_sandstone.png`) becomes the slab-path material (warmer + larger-stone than the cool cobble — instant "warm path through cool field" wayfinding read), free, no regen. Slab paths trace the monastery's circulation = the player's journey (spawn-gate → curving spine → descent; building-links branching at the central building; a worn apron ringing the well) — paths are wayfinding AND exploration-bait. The WELL = a HERO landmark PROP (south-central, slab apron, water-glint mystery hook, NPC-station + discovery anchor SEED). SPRINGS = cheap scatterable water TILEMAP accents in damp low/shadow corners (wettest-moss-clustered, the most-reclaimed spots). Water visual treatment: still, dark warm-neutral (`S1_YARD_WATER_DOCTRINE`, NOT pure-black per PL-09, sub-1.0 HDR-safe); ANY animated glint = ColorRect-modulate NOT Polygon2D (PR #137); preferred = no animated water cue in S1 (still water = zero gate). Other beats: dirt desire-paths (FREE reuse), garden bed gone wild (LOW, ship one), drainage gutters (secondary, defer if tight), damp building-base aprons (FREE). COMPOSITION RULE: variety concentrated AT landmarks, big open cobble BETWEEN (density-at-landmarks / openness-between — composes the parent vision's big/endless sightlines without crowding). GEN SCOPE: ~2–3 PixelLab gens (well-head hero prop + 1–2 spring tiles + optional gutter tile), 2 doctrine-lock passes each, orch-run. REUSE: flagstone (→ slabs), cobble base + doctrine accents (→ dirt-paths/springs/seams/garden), rubble/moss/grass props. Drew Stage-C work is placement + aging craft (worn-center/mossy-sunk-edge slabs, wear-traces-use gradient, well-apron, spring clustering, garden bed) + validate slab-to-cobble size ratio once the cobble in-engine scale fix lands. Sponsor soak is the visual gate of record (lived-in / path-readability / well-as-wonder / quiet-water / variety-without-crowding are taste calls). Reversibility: tile-painting + prop placement + 2–3 PNG gens — all revertible.

**Sponsor sign-off surface (what to veto/approve before any generation/build):**
1. **Tonal anchor** (§1): the ground RECORDS human use — slab paths + dirt shortcuts + well + garden + drainage tell where people lived. Right read of "a real monastery, not all cobble"?
2. **Slab-path material reuse** (§2): the set-aside warm-sandstone flagstone becomes the worn processional slab paths (warm path through cool cobble field). Right call — and right to reuse the abandoned base material for free?
3. **Slab-path composition** (§2.2): processional spine (spawn→descent) + building-links + well-apron, tracing the monastery's circulation = the player journey. Right routes?
4. **The well** (§3.1): a hero landmark prop, south-central, slab apron, water-glint mystery, NPC-station seed. Right to promote it to a focal wonder-landmark?
5. **Springs + water treatment** (§3.2/§3.3): scattered damp seeps + still dark warm-neutral water (never black, never bright, no particle FX). Right "quiet holy water" read?
6. **Other ground beats** (§4): dirt desire-paths + a garden bed gone wild + drainage gutters + damp building-base aprons — ship the FREE/LOW ones, defer gutters if tight. Right scope?
7. **Composition + bigness** (§5): variety AT landmarks, open cobble BETWEEN — composed ground that reads lived-in WITHOUT crowding the big/endless sightlines. Right balance?
