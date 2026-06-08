# S1 Yard LAYOUT DESIGN — the concrete level (coordinate-placed, build-ready)

**Owner:** Uma (level design) → **Sponsor APPROVES THE LAYOUT** → Drew (Stage C impl, only after approval) · **Phase:** M3 S1 spatial pivot — the LAYOUT the prior vision docs never authored.

**What this is and is NOT.** `s1-cloister-yard.md` + `s1-yard-ground-composition.md` are DIRECTION (materials, tone, principles). They were built literally → a bland symmetric result (a top bar + a bottom bar + a center box + scattered mobs; ports on the dead-center row; no designed path, no well, no slab routing, no focal point, no asymmetry). **This doc is the missing LAYOUT: every element placed at concrete tile coordinates on the yard's real grid, with the design rationale for the flow.** It does NOT re-spec tiles/materials (done — cobble + slab + dirt autotiles exist and look fine), does NOT touch code (Drew), does NOT re-decide combat/well scale.

**This is a DESIGN for Sponsor visual approval BEFORE any build.** The placements are concrete enough that the orchestrator can render a block-out from the coordinates alone.

---

## 1. THE CANVAS (real, verified dimensions — the grid the design must fit)

Verified from `resources/level_chunks/s1_yard_slice.tres` + `s1_yard_descent.tres` + `scripts/levels/S1YardChunk.gd`:

| Fact | Value | Source |
|---|---|---|
| Walkable yard chunk | **40 × 24 tiles = 1280 × 768 px** | `s1_yard_slice.tres` `size_tiles = Vector2i(40, 24)`, `tile_size_px = 32` |
| Descent cap (east) | **6 × 24 tiles = 192 × 768 px** | `s1_yard_descent.tres` `size_tiles = Vector2i(6, 24)` |
| **Total assembled floor** | **46 × 24 tiles = 1472 × 768 px** | yard mates EAST → descent cap |
| Tile size | 32 px | `tile_size_px = 32` |
| Viewport (baseline zoom) | 480 × 270 px = **15 × 8.4 tiles** | `camera-scroll.md` §Bounds-clamp |
| Scroll factor | **~3.07 screens wide × ~2.85 screens tall** | 1472/480, 768/270 |
| Player scale | `char_scale = 0.6` → player reads ~10 px wide on screen | PR #405 |
| WEST entry port (spawn seam) | tile **(0, 12)** | `s1_yard_slice.tres` entry_port |
| EAST exit port (to descent) | tile **(39, 12)** | `s1_yard_slice.tres` exit_port |

**Coordinate convention used below:** `(x, y)` in TILES, origin top-left, x→EAST, y→SOUTH. Yard x∈[0,39], y∈[0,23]. The descent cap occupies assembled x∈[40,45]; its content is just open cobble + the stair, so the design body below addresses x∈[0,39] (the yard) and treats x≥40 as the descent terminus.

### 1.1 Is the canvas big enough for a genuinely good design? — HONEST answer

**Yes, with one caveat I am NOT blocking on.** 40×24 walkable (~3×2.8 screens) is enough to author real asymmetric routing, a focal well, a route-choice fork, and 2–3 reveals — the design below uses every bit of it. It is on the *modest* end of "endless"; the felt-endlessness comes from off-frame buildings + the long east sightline + the soft horizon, not from raw size (per `s1-cloister-yard.md` §0.5: "endless" is a felt quality, not unbounded generation).

**Optional enlargement (Sponsor's call, NOT required to build this design):** if Sponsor wants more breathing room, widen the yard chunk to **52 × 28 tiles (1664 × 896 px)** — that buys ~1 more screen of east sightline and a taller N/S scroll, which would let the central building sit further from the spawn and lengthen the reveal sequence. This is a one-line `size_tiles` edit in `s1_yard_slice.tres` + matching `grid_w/grid_h` in `S1YardChunk.gd` + a GUT-pin update (the size is already `@export`ed precisely so this is cheap). **I designed the layout below at the EXISTING 40×24** so it ships without a dimension change; §6 notes how it stretches if Sponsor approves 52×28. **Recommendation: build at 40×24 first** — prove the design reads, then enlarge if the soak wants more air.

---

## 2. THE DESIGN — annotated to-scale map (every element placed)

To-scale ASCII at **1 char = 1 tile**, full 40×24 yard + the 6-wide descent cap (x 40–45). Read it as the top-down plan Drew builds from. Legend below the map; exact coordinate tables in §3.

```
   0    5    10   15   20   25   30   35   39 | 43
   |    |    |    |    |    |    |    |    |   | |
 0 ████████░░░░░░░░░░░░░░░░░░CCCC░░░░░░░░░░░░░ | ░   ← N: chapel (off-frame N)
 1 █CHAPEL█░░░░░░░░░░░░░░░░░░░CCCC░░░░░░░░░░░░░ | ░     central bldg top course
 2 ████████░ vvv ░░░░░░░░░░░░CCCC░░░░░░░░░░░oo░ | ░     (oo = far outbuilding)
 3 ░░░░╱S╲░░░░░░░░░░░░░░░░░░░░CCCC░░░░░░░░░░░oo░ | ░     ╱S╲ = chapel-step NPC stn
 4 ░░░╱slab╲░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ | ░
 5 ░░░░║░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░·····░░░ | ░     ····  = east bronzed
 6 ░░░░║░░░░░░░░░·······░░░░░░░░░░░░░░░······░░ | ░       funnel decoration band
 7 ░░░░║░░░░░░·····G·····░░░░░░░·······░░░░░░░░ | ░     G = item-glint (off-path)
 8 ░░░░╠══════════════════╗░░░░░░░░░░░░░░░░░░░░ | ░     ══ = SLAB SPINE (worn path)
 9 SP→╫══════════════════ ╠═══════════════════>EXIT>≈≈≈   SP=spawn  >EXIT>=east port
10 ░░░░║ (open W lane) ░░░░║░░░░ (open E lane)░░ | ≈     ≈≈ = descent stair (ember)
11 ░░░░║░░░░░░░░░░░░░░░░░░░╚════╗░░░░░░░░░░░░░░░ | ░       in descent cap
12 ░░░░║·····░░░░░░░░░░░░░░░░░░░║░░░░░░░░░░░░░░░ | ░     · (W) = west spawn-area
13 ░░░░╚═══╗░·dirt·░░░░░░░░░░░░░║░░░░░░░░░░░░░░░ | ░         brazier-lit detail
14 ░░░░░░░░╚·track·░░░░░░░░░░░░░╚═══╗░░░░░░░░░░░ | ░
15 ░░░░░░░░░·····░░░░░░░░░░░░░░░░░░░║░░░░░░░░░░░ | ░     ~~ = spring (damp seep)
16 ░░░░░░░░░░░WWWW░░~~~~░░░░░░░░░░░░╚════╗░░░░░░ | ░     WWWW = WELL + slab apron
17 ░░░░░░░░░░░WoWW░~~~~░░░░░░░░░░░░░░░░░░╚══╗░░░ | ░     o = well-shaft (glint)
18 ░░░░░░░░░░░WWWW░░░░░░GG░░░░░░░░░░░░░░░░░░║░░░ | ░     GG = garden bed (gone wild)
19 ░░░░░░░░░░░░░░░░░░░░░GG░░░░░░░░░░░░░░░░░░╚═══>(to descent / chapel link unused)
20 ░░░░░░░░░░░░·····░░░░░GG░░░░░░░░░░░░░░░░░░░░░ | ░
21 ███████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ | ░   ← S: dormitory ruin
22 █DORMITORY RUIN█░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ | ░     (off-frame S; rubble)
23 ███████████████░░░░░░░░░░░░░░░░░░RR░░░░░░░░░ | ░     RR = rubble cache (treasure)
```

**Legend**
- `█` building footprint (solid collision) — `CHAPEL`=north range, `DORMITORY RUIN`=south range, `CCCC`=central cloister building, `oo`=far outbuilding.
- `═ ║ ╠ ╗ ╚ ╫` SLAB SPINE + its branches (warm-sandstone flagstone path through cobble; the worn processional route).
- `░` open cobble field (the dominant surface; combat lanes + traversal).
- `SP→` spawn point. `>EXIT>` east exit port → descent. `≈≈` descent stair (ember glow), in the cap.
- `WWWW / o` the WELL (hero landmark prop) + its shaft-glint. `~~` spring/damp seep. `GG` garden bed gone wild. `RR` rubble cache (treasure, off-path).
- `vvv` vine/sapling reclamation beat. `····` decoration density bands (W brazier detail / E bronzed funnel). `G` item-glint discovery. `╱S╲` chapel-step NPC station.

**The asymmetry is deliberate and visible in the map:** the spine does NOT run straight across the center row. It enters low-west, rises diagonally to clear the dormitory, runs the upper-center lane, FORKS at the central building (north link to chapel / south link down to the well), then the main line drops and curves east-and-down toward the exit. The buildings are NOT mirrored — chapel (N) and dormitory (S) are at DIFFERENT x-extents and different depths; the central building is OFF-center (x 26–29, north of mid), not dead-center; the far outbuilding sits high-east. The well anchors the south-center as a focal pull off the spine.

---

## 3. CONCRETE PLACEMENTS (coordinate tables — Drew builds directly from these)

### 3.1 Buildings — REPLACES the current `S1YardChunk.building_footprints`

The current array (the bland-symmetric one) is replaced by these `Rect2i(x, y, w, h)` footprints. Each carries a design intent (what it frames/blocks/reveals):

| Building | `Rect2i(x, y, w, h)` | Tiles | Design intent |
|---|---|---|---|
| **North range — Chapel + bell-tower** | `Rect2i(0, 0, 8, 3)` | x 0–7, y 0–2 | Anchors the NW corner AT the spawn shoulder. Its bell-tower silhouette (tall, runs off-frame N) is the first vertical the player sees — the spawn-vista headline. Asymmetric: hugs the west, NOT centered. Frames the spawn; the chapel-step NPC station sits just below it (§3.4). |
| **South range — Dormitory ruin** | `Rect2i(0, 21, 15, 3)` | x 0–14, y 21–23 | Runs the SW–S edge, wider than the chapel and offset east of it (asymmetry). A ruin (broken roofline) — rubble spills north of it (the treasure cache, §3.5). Blocks the SW so the spine must rise to clear it (forces the diagonal, §3.2). Runs off-frame S. |
| **Central cloister building** | `Rect2i(26, 0, 4, 4)` | x 26–29, y 0–3 | The spatial anchor, but placed HIGH and OFF-center (north-east of mid), NOT a dead-center box. It splits the upper-east open ground and creates the spine FORK decision (north of it vs south-around). Its lit window (mystery hook) faces south toward the player's approach. Runs off-frame N (top course only visible). |
| **Far outbuilding (east horizon)** | `Rect2i(38, 2, 2, 2)` | x 38–39, y 2–3 | SMALL, high-east, near the exit. Anchors the long east sightline (depth / "more world that way"). Sits ABOVE the exit line so it doesn't block the descent approach; the eye is pulled toward it across the open east lane. |

**Why this beats the old footprints:** old = two horizontal bars (top y0–2 x8–19, bottom y21–23 x6–19) + center box (x18–23 y9–13) = near-mirror symmetry, center blocked dead-on, no spawn anchor. New = corner-anchored chapel at spawn + offset wider dormitory + high-offset central + tiny east-horizon outbuilding = asymmetric, reads as a real irregular monastery footprint, and the open ground forms designed LANES not leftover gaps.

### 3.2 The SLAB SPINE + branches — the worn processional path (warm-sandstone slab tiles over cobble)

The spine is the headline level-design element: a worn flagstone-slab ribbon (per `s1-yard-ground-composition.md` §2) painted as a distinct tile-class over the cobble. It is **2 tiles wide** (reads as a real path, not a line) and follows this routed polyline of tile-segments. Asymmetric, with two designed turns and a fork.

| Segment | From → To (tile) | Width | Intent |
|---|---|---|---|
| **S1 — Spawn approach** | (0,12)→(4,12) then up (4,8)→(4,12) | 2 | Spawn at (1,12) on slab; path runs east then turns UP — the first turn hides the full yard for a beat (reveal). |
| **S2 — The rise (diagonal-stepped)** | (4,8)→(22,8) | 2 (rows 8–9) | The main worn run along the upper-center lane, ABOVE the dormitory, BELOW the central building. Long sightline east. This is where most spine-wear shows (foot-polished). |
| **S3 — THE FORK (at central bldg SW corner)** | branch at (22,8) | — | Spine splits. Decision point made legible by the ground. |
| **S3a — North link → chapel/central** | (4,8)→(4,3) up to chapel steps | 2 | The north choice: up to the chapel-step NPC station + central building face. |
| **S3b — South link → WELL** | (22,9)→(22,13)→(11,13)→(11,16) | 2 | The south choice: drops and curves west-and-down to the WELL apron. Off the critical path = exploration-bait + the well wonder-beat. |
| **S4 — Main line to exit (curve E-and-down)** | (22,9)→(28,9)→(28,11)→(36,11)→(36,14)→(39,14) | 2 | After the fork the critical line curves around the EAST side of the central building and steps DOWN toward the exit seam — NOT a straight shot. The curve keeps the long sightline and reveals the descent ember-glow late. |

**Note on the exit seam:** the engine exit port is fixed at (39,12) (the chunk `.tres`). The spine's S4 terminus lands at (39,14) then steps up to meet (39,12) — a 2-tile reconcile Drew paints. (If Sponsor approves moving the port, it's a `.tres` edit; not required — the spine reaches it either way.)

**Dirt desire-path (informal shortcut, FREE — reuse dirt-through cobble tiles):** a meandering 1-tile bare-dirt track from the spine at (13,13) cutting SW to the well at (12,16) — the unofficial worn shortcut paralleling the formal S3b slab link. Reinforces "people lived here."

### 3.3 The WELL — hero focal landmark (south-center)

| Element | Placement | Intent |
|---|---|---|
| **Well-head prop** | center tile **(12, 17)**; collision footprint x 11–13, y 16–18 (3×3) | Hero landmark, south-center, OFF the critical spine — a focal pull. The shaft-glint mystery hook (`o` in map) faces up. NPC-station footprint kept clear around it (§3.4). |
| **Slab apron** | ring of slab tiles x 11–13 (col) extended to a 4×4 worn apron x 10–13, y 16–18 around the well | The most-worn ground (everyone drew water). Connects to S3b slab link. |
| **Spring / damp seep** | small water-accent patch x 14–15, y 16–17 (2×2) | The cheap scatterable water beat; wettest moss rings it. Sits between the well and the garden — the most-reclaimed corner. |
| **Garden bed gone wild** | tilled-soil + weed patch x 19–20, y 18–20 (2×3) | Near the dormitory range (where a kitchen garden sits). Sapling reclamation beat. Off-path discovery. |

### 3.4 NPC stations (SEED — author the clear footprints now, populate over milestones)

| Station | Clear footprint (tiles) | Why here |
|---|---|---|
| **West gate — bounty-poster** | (1–2, 13–14) just SE of spawn | First thing past spawn; on the spine. |
| **Chapel steps — hooded figure** | (3–4, 3–4) below chapel SE corner | The S3a north-link terminus; `╱S╲` in map. |
| **Well — caretaker/penitent** | (9–10, 17) west of the well apron | The well wonder-station. |
| **Central building entrance** | (27–28, 4) just S of central bldg | The mystery-window face; lit-window hook above. |

These sit OFF the open combat lanes — they must stay clear of mob spawns (§3.6).

### 3.5 Discovery / treasure (SEED — reserve, fill 1–2 in S1)

| Spot | Placement | Reward |
|---|---|---|
| **Rubble cache (dormitory)** | (32–33, 23) in the rubble north of the dormitory ruin | Treasure chest/cache — off the critical path, rewards poking the ruin. `RR` in map. |
| **Item-glint (mossy corner)** | (13, 7) in the upper-center mossy lane, N of the spine | A far glint the player sees from the spine and detours for. `G` in map. |
| **Hidden alcove (behind central bldg)** | (28, 0–1) tucked at the central building's north back | Behind the landmark — rewards circling it. Optional. |

### 3.6 Mob encounters — REPLACES the current scattered `mob_spawns`

Combat is MODERATE and placed as ENCOUNTERS along the journey, never an arena fill. All on open cobble, reachable, OFF the NPC/discovery footprints:

| Encounter | Mob | Tile | Intent |
|---|---|---|---|
| **First contact (west lane)** | grunt | (9, 11) | Just past the spawn approach, on the open W lane — the first "the world has threat" beat. |
| **West lane second** | grunt | (8, 15) | Below the spine; covers the south-route approach toward the well. |
| **Fork pressure (central)** | grunt | (24, 11) | At the fork, in the open south-of-central lane — makes the route-choice tense. |
| **East lane** | grunt | (33, 9) | On the long east approach to the exit — the "deeper into the world" beat. |

Old spawns were (12,14)/(26,6)/(30,16) — scattered without relation to flow. New spawns gate the lanes the spine routes through, so combat punctuates the journey (4 grunts, MODERATE, matches `s1-cloister-yard.md` §0.6).

### 3.7 Decoration density bands (the §5.2 jitter discipline, placed)

- **West spawn detail** (·····  near (4–8,12) + (10–14,20)): brazier-lit cobble + sparse moss clustered at the chapel base + spawn shoulder — warmth at the entrance.
- **East bronzed funnel** (····· near (35–39,5–6)): rising bronzed-trim + ember density toward the far outbuilding + exit (`env-art-s1-direction.md` §2c "something ahead" funnel).
- **Damp building-base aprons** (FREE): moss-thicken the cobble along all building bases (chapel y3, dormitory y20, central y4).
- **Open lanes stay CLEAR:** the W lane (x5–18, y10–16 minus well), the E lane (x30–38, y7–16) are open cobble for combat + traversal. Density at edges/landmarks, openness between — never a grass grid.

---

## 4. DESIGN RATIONALE — why this flow works (the level-design craft)

**The spine is a guided desire-line, not a road.** The player spawns on slab at (1,12), and the slab IMMEDIATELY turns up (the S1→S2 turn) — this hides the full east yard for one beat, so cresting the rise (S2) is a small reveal: the long upper-center sightline opens, the central building and the far outbuilding pop on the horizon. Leading line + staged reveal, the `game-art` staging principle applied.

**Asymmetry creates interest at every scale.** Buildings: chapel hugs NW-corner-at-spawn, dormitory is wider and offset east, central is high-and-east-of-mid, outbuilding is tiny-high-east — no two mirror, the open ground reads as authored irregular monastery, not a symmetric arena. The spine: enters low, rises, runs high-center, forks, curves E-and-down — three turns, never a straight line. This is exactly what the old "straight V-lane" lacked.

**The FORK is the heart of the design (the decision point).** At (22,8) the slab visibly splits: NORTH to the chapel-step NPC + central-building mystery window, or SOUTH-and-down to the WELL (wonder landmark + spring + garden + the treasure-adjacent dormitory). Both rejoin the east approach. The north route is the "lore/NPC" read; the south route is the "explore/treasure/wonder" read. Neither is the critical path — the critical line (S4) curves around the central building's EAST side independent of the fork, so the fork is pure optional exploration. **The player CHOOSES how to cross the world** — the Diablo-shape "quest-driven exploration" verb at the room scale.

**Sightlines and reveals (where the eye goes):**
1. **Spawn frame:** bell-tower vertical (NW) + slab leading east + ember-hint far east. Wonder thesis.
2. **Cresting the rise:** long upper-center sightline → central building + far outbuilding on the horizon.
3. **At the fork:** the WELL becomes visible down-left (a focal pull); the central building's lit window draws up-right.
4. **East approach:** the descent ember-glow reveals late as the spine curves down — the "something important ahead" payoff.

**The focal point is the WELL, reinforced by the radial-composition lesson** from the garden inspiration (`07h53`/`08h00`): a landmark with worn paths converging on it (slab apron + S3b link + dirt shortcut all reach the well) reads as a place the world centered on. It's the single strongest "this was alive" beat, placed off the critical path so discovering it is a reward, not a transit.

**Wayfinding by landmark, not by minimap.** Chapel (NW/spawn), central building (high-center mystery), well (south-center wonder), far outbuilding (east-horizon depth), descent ember (east terminus) — five distinct silhouettes at distinct positions. The player orients landmark-to-landmark — travel, not transit (no "ROOM N/8").

**How it stays BIG/ENDLESS at this modest size:** the chapel + dormitory + central all run off-frame (N/S), the far outbuilding implies east-distance, the exit terminus is open cobble + ember (soft horizon, not a wall). The eye is never stopped by a near building-face — open lanes run past every landmark. (Per `s1-cloister-yard.md` §2.3 soft-horizon discipline.)

---

## 5. WHAT DREW BUILDS (the concrete change set — after Sponsor approval)

1. **Replace `S1YardChunk.building_footprints`** with the 4 footprints in §3.1 (chapel `Rect2i(0,0,8,3)`, dormitory `Rect2i(0,21,15,3)`, central `Rect2i(26,0,4,4)`, outbuilding `Rect2i(38,2,2,2)`).
2. **Paint the SLAB SPINE + branches** (§3.2) as the warm-sandstone slab tile-class over the cobble, with worn-center / mossy-sunk-edge aging (`s1-yard-ground-composition.md` §2.3). Add the dirt desire-path shortcut.
3. **Place the WELL prop** at (12,17) + slab apron + spring (14–15,16–17) + garden bed (19–20,18–20) (§3.3).
4. **Reserve NPC-station footprints** (§3.4) + **place 1–2 discovery rewards** (§3.5 rubble cache + item-glint).
5. **Replace `mob_spawns`** in `s1_yard_slice.tres` with the 4 lane-gating grunts (§3.6).
6. **Decoration density bands** (§3.7) — re-enable proper scatter ONLY with the correctly-scaled vegetation asset (the painter's `_scatter_decoration` is currently a deliberate no-op per PR #424; the T3 decoration asset gates this).
7. **GUT pins update** for the new footprints + mob spawns (the size_tiles stays 40×24 — no assembler/bounds change needed).

**Nothing here requires a new level system, a new chunk schema, or a dimension change.** It's a footprint-array swap + a slab-spine paint pass + a well prop + mob respawn — all within the existing painter + `.tres` surface.

---

## 6. IF SPONSOR APPROVES THE OPTIONAL ENLARGEMENT (52×28)

Not required; only if the 40×24 soak wants more air. The design stretches cleanly:
- Chapel/dormitory shift to the new west edge; central building moves to ~x34, outbuilding to ~x50 (longer east sightline).
- Spine S2 run lengthens (more crest-reveal distance); the fork moves east; the well stays south-center at the new proportions (~x16,y20).
- Mobs re-space to the wider lanes (still 4–5, MODERATE).
- Cost: `size_tiles=Vector2i(52,28)` in `s1_yard_slice.tres` + `grid_w=52/grid_h=28` in `S1YardChunk.gd` + GUT-pin update (size is `@export`ed for exactly this). The descent cap stays 6×28.

---

## 7. CROSS-REFERENCES

- `team/uma-ux/s1-cloister-yard.md` — the parent VISION (tone, big/endless/alive/wonder/journey north-stars, material doctrine) this LAYOUT realizes concretely.
- `team/uma-ux/s1-yard-ground-composition.md` — the GROUND-surface direction (slab paths = reused warm-sandstone flagstone, well, springs, garden) this layout places at coordinates.
- `resources/level_chunks/s1_yard_slice.tres` + `s1_yard_descent.tres` — the real chunk grid (40×24 + 6×24) the design fits; the `mob_spawns` + ports this layout edits.
- `scripts/levels/S1YardChunk.gd` — the painter; `building_footprints` (§3.1 replaces it), `_paint_floor`, `_scatter_decoration` (no-op gate).
- `.claude/docs/procgen-pipeline.md` — `FloorAssembler.assemble_floor` + EAST/WEST port-mating (yard mates → descent cap).
- `.claude/docs/camera-scroll.md` — `Main.S1_ROOM_BOUNDS → AssembledFloor.bounding_box_px` swap (the two-axis scroll the layout is exposed across); viewport = 480×270 = 15×8.4 tiles.
- `.claude/docs/html5-export.md` — any slab/spring glint or descent-ember cue = ColorRect-rotated-rect, NOT Polygon2D (PR #137); floor z=0 / props z=+1; visual-verification gate.
- `game-art` skill — staging, leading lines, focal point, silhouette readability (the level-design principles applied in §4).
- Memory: `s1-cloister-yard-open-world-direction`, `tile-scale-small-player-large-world`, `m3-diablo-shape-directive`, `world-feel-big-and-endless`.

---

## 8. Decision draft + Sponsor sign-off surface

**Decision draft (2026-06-08)** — for Priya's weekly `DECISIONS.md` batch (NOT direct-edited per Uma role rule):
> **S1 yard CONCRETE LAYOUT authored** (the level design the prior vision docs never produced — root cause of the ~8 S1 bounces: direction was built literally → bland symmetric result). The layout is coordinate-placed on the real grid (40×24 walkable + 6×24 descent cap = 46×24 @ 32px, verified from `s1_yard_slice.tres`). Four ASYMMETRIC building footprints REPLACE the current symmetric bar/bar/box array: chapel `Rect2i(0,0,8,3)` (NW-corner-at-spawn), dormitory `Rect2i(0,21,15,3)` (wider, offset-east), central `Rect2i(26,0,4,4)` (high, off-center), far outbuilding `Rect2i(38,2,2,2)` (tiny, east-horizon). A worn SLAB SPINE (warm-sandstone flagstone over cobble, 2 tiles wide) routes spawn(1,12)→turn-up→rise along upper-center→FORK at (22,8)→[north link to chapel/central OR south link down to the WELL]→main line curves E-and-down to exit(39,12) — three turns + a fork, never straight, never symmetric. The WELL (hero focal landmark) at (12,17) south-center off the critical path with slab apron + spring(14–15,16) + garden bed(19–20,18) = the wonder/discovery corner. NPC-stations reserved (gate/chapel-steps/well/central-entrance); 1–2 discovery rewards placed (rubble cache (32,23), item-glint (13,7)). Mobs REPLACED with 4 lane-gating grunts (MODERATE, punctuate the journey). Rationale: guided desire-line spine + staged reveals (spawn-vista → crest → fork → late ember-reveal) + landmark wayfinding + the well as radial focal point (garden-inspiration lesson). Builds within the existing painter + .tres surface — footprint-array swap + slab paint + well prop + mob respawn — NO new level system, NO dimension change required. Optional enlargement to 52×28 offered (Sponsor's call; a 3-edit cheap change, NOT required). GATE: Sponsor approves the LAYOUT (orchestrator renders a block-out from these coordinates) BEFORE Drew builds. Reversibility: footprint array + tile-paint + prop placement + mob list — all revertible.

**Sponsor sign-off surface (approve/veto the LAYOUT before any build):**
1. **The flow** (§2 map + §4): spawn-turn-up → rise → fork → curve-down-to-exit, with the well as the south-center focal pull. Does the routed journey read right?
2. **The asymmetry** (§3.1): NW-corner chapel / offset-east dormitory / high-off-center central / tiny east-horizon outbuilding — no mirroring. Right "irregular real monastery" footprint?
3. **The FORK** (§3.2, §4): north (chapel/lore) vs south (well/explore/treasure), both optional off the critical line. Right decision-point design?
4. **The WELL as focal point** (§3.3): south-center, off-path, paths converging on it. Right hero landmark placement?
5. **Mob placement** (§3.6): 4 grunts gating the lanes the spine routes through. Right MODERATE encounter rhythm?
6. **Size** (§1.1, §6): build at the existing 40×24 first, OR approve the optional 52×28 enlargement for more air. Which?
