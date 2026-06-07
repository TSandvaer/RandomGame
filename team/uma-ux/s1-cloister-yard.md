# S1 Cloister-YARD Vision — "Spawn into a World, Not a Room"

**Owner:** Uma (Stage A — vision/direction) → Priya (scope/tickets) → orch (PixelLab floor regen, orch-only) → Drew (Stage C — impl) · **Phase:** M3 S1 spatial pivot
**Sponsor:** taste-veto on this DIRECTION before any generation/build. Goes to **Sponsor sign-off** first — this is a major spatial-structure reframe, not a craft tweak.
**Supersedes (spatially):** the discrete room-to-room model AND the interior "lined hall" colonnade framing of `s1-tile-rework.md` (`86ca44p4j`, PR #408). The crafted PROP assets from that work carry forward verbatim; the SPATIAL STRUCTURE (rooms → open yard) and the FLOOR MATERIAL (sandstone flagstone → cobblestone+moss+dirt) change.
**Foundation:** this COMPOSES two already-shipped systems — `CameraDirector` continuous-scroll (`.claude/docs/camera-scroll.md`) + procgen `FloorAssembler` (`.claude/docs/procgen-pipeline.md`). It is NOT a from-scratch level system.
**OOS:** generating art (orch runs PixelLab on §2 floor spec); coding / `.tscn` / collision / nav (Drew, Stage C); ticket breakdown (Priya); S2+ biomes; mob/character art (separate pipeline, already shipped via PR #409–#416).

---

## 0. Why this pivot (one paragraph, so the fix targets the real failure)

Sponsor, soaking build `18c1406` (the tile-rework) on 2026-06-07, verbatim: **"I want to spawn into a world, not a room. Rooms are too crammed and small. I want to step into a cloister yard with the cloister buildings on the sides/middle of the yard, then walk through the cloister — not jump from room to room."** Two failures stacked. (1) **Spatial: the discrete-room model reads as crammed.** "ROOM 3/8" + a single-screen box + a teleport-on-door-walk to the next box is the antithesis of the locked M3 Diablo-shape vision (`m3-diablo-shape-directive`: continuous-scroll camera + open per-act maps + walked-through exploration). The systems to fix this already shipped (camera-scroll W1/W2, procgen FloorAssembler W1) but S1 still drives them in single-screen-room mode (`Main.S1_ROOM_BOUNDS = Rect2(0,0,480,270)`, which forces the bounds-clamp's "narrower-than-viewport → hold at center" branch every tick — zero scroll). (2) **Material: the sandstone flagstone reads as an interior hall floor, not an open courtyard.** Flagstone was the right call for a "lined processional hall"; it is the WRONG call for an open-air yard, which should read as cobblestone with moss and dirt working between the stones. This vision dissolves the rooms into one traversable yard and re-materials the floor to cobble+moss+dirt at a finer scale.

---

## 0.5. OVERARCHING FEEL TARGET — BIG AND ENDLESS (Sponsor north-star, 2026-06-07)

> **Sponsor, verbatim: "Remember I am ENTERING A WORLD — make the game feel BIG and ENDLESS."**

This is the SINGLE overarching feel-gate this whole vision serves. Every layout, palette, scale, and decoration call below favors **big + endless over contained**. The yard is NOT a bounded enclosed courtyard with the player penned inside four building-faces — it is an **open expanse that reads as PART of a larger world continuing past the viewport in every direction.** The binding sensations:

- **Long sightlines.** The player can see FAR — open cobble running to a distant horizon-edge, building silhouettes set back and receding, the eye carried across a big space rather than stopped by a near wall. Nothing crowds the immediate viewport.
- **Off-screen continuation.** The world visibly extends beyond the scroll-bounds — buildings whose tops/sides run off-frame, cobble ground that continues past where the camera clamps, a far edge that implies "more world that way" rather than "the level ends here." The camera-scroll bounds should feel like a soft horizon, not a box wall.
- **Open continuous space.** No teleport-boxes, no enclosing perimeter walls hugging the screen edge, no corridor linearity. One continuous traversable expanse the player moves through, with the cloister as landmarks WITHIN the bigness, not walls AROUND it.
- **Smallness of the player against the world.** The "small player, large world" north-star is the visual proof of "big + endless" — finer floor + receding-large architecture + open distance all make the player a small figure in a vast place.

**The tie-breaker rule for every call below:** when a layout/palette/decoration choice could go either "more contained + cozy" or "more open + endless," **choose open + endless.** A slightly-too-empty expanse serves the north-star; a slightly-too-crowded yard violates it. Err toward bigness.

**What this does NOT mean:** not literal infinite procgen (S1 has a spawn and a descent — it's bounded as a level). "Endless" is a FELT quality (the world reads as continuing past what you can see), achieved through composition + sightlines + off-screen continuation, NOT through unbounded generation. The descent stair is still the east terminus; it just shouldn't read as "you hit the wall of the level."

---

## 0.6. THE WORLD IS ALIVE — living-world / journey / wonder (Sponsor deepening, 2026-06-07)

> **Sponsor, verbatim: "I want to feel like I am entering a world that's already ALIVE — with NPCs, buildings, animals, vegetation, enemies, treasures, landscapes, distances. It should feel like you're on a JOURNEY through a MYSTICAL, WONDROUS world."**

This reframes S1 from a **combat space** into an **inhabited world experienced as an exploratory journey.** The cloister-yard is not an arena with mobs in it — it is a PLACE that was alive, is still half-alive, and the player is a traveler arriving in it with wonder. Combat is ONE thing that happens in the world, not the world's purpose. The "big + endless" expanse (§0.5) is the canvas; THIS section is what fills it with life + wonder + journey. Every layout/decoration/palette call must now ALSO ask: *does this make the world feel inhabited, wondrous, and worth exploring?*

**The three content pillars this section plants** (some ship now in S1, some are SEEDS the layout reserves space + tonal language for so later milestones drop them in without re-architecting):

### Pillar A — INHABITED (ambient life + NPCs + animals)

The yard should read as a place where things LIVE and once lived, not an empty box with enemies:

| Element | S1 status | How the yard plants it |
|---|---|---|
| **NPCs** | SEED (dialogue + quest systems already shipped — `.claude/docs/dialogue-system.md`, `quest-system.md`; hub-town NPC direction exists — `hub-town-direction.md`) | The yard RESERVES inhabited spots — a lone surviving caretaker/penitent by the well, a bounty-poster at the west gate, a hooded figure on the chapel steps. Layout leaves clear, lit, approachable "NPC stations" at landmarks (well, gate, chapel face, central building entrance) even if S1 ships with 0–1 NPCs and the rest land later. The STATIONS are authored now; the NPCs populate over milestones. |
| **Ambient creatures / animals** | SEED → light ship | Small non-combat ambient life that makes the world breathe: crows on the bell-tower + chapel roof (silhouettes that occasionally shift), rats/mice scurrying between rubble, moths/insects drifting near the lit braziers, maybe a stray cloister cat. These are AMBIENT (no combat, low cost — simple looped sprites / particle-ish drift) and they are the single cheapest highest-impact "alive" lever. Ship a few in S1; reserve the vocabulary for more. |
| **Living vegetation** | SHIP (folds into the cobble floor + decoration §3/§5) | The moss + weeds + grass aren't just texture — they're the world RECLAIMING the cloister. Vegetation that reads as alive + growing (clustered, varied, creeping up building bases, sprouting from cobble joints) tells "nature is taking this place back." A vine on a chapel wall, a sapling pushing through cobbles near the well. The overgrowth is LIFE, not decay-noise. |
| **Sound of life** | SEED (audio direction owns) | Ambient bird-call, wind, distant bell, insect-hum — the audio layer that makes the world feel populated even when the screen is still. Routes through `audio-direction.md` / `s1-ambient.md`; flagged here as a living-world dependency, specified there. |

### Pillar B — JOURNEY (exploration over arena; treasures + discovery)

The player is a TRAVELER passing through, not a fighter clearing rooms:

- **Exploration is the verb, combat is an encounter.** The yard rewards WANDERING — branching paths around the central building, a side-channel toward the well that isn't on the critical path, a corner of the dormitory ruin worth poking into. The player should feel they're CHOOSING a route through a place, discovering it, not running a combat corridor. (Composes the locked Diablo-shape "quest-driven exploration" — `m3-diablo-shape-directive`.)
- **Treasures + discovery beats.** Reserve discoverable rewards OFF the critical path — a chest/cache in the dormitory ruin, a glinting item-drop in a mossy corner, a hidden alcove behind the central building. The gear-drop light-beam (`palette.md` gear-tier light-beam) is a wonder-beat: a far glint across the expanse pulls the player to explore toward it. S1 ships a couple; the layout reserves more discovery-spots than it fills.
- **Landmarks as journey waypoints.** The chapel, the well, the central cloister building, the far outbuilding, the descent stair — these are the beats of a JOURNEY across the expanse. The player orients and progresses landmark-to-landmark (the "long sightline pulls you toward the next landmark" loop), which is what makes traversal feel like travel, not transit.
- **No "ROOM N/8."** Place-identity comes from the world itself + the region-name HUD (`world-map-direction.md`, `hud-boss-region-spec.md`) — you're SOMEWHERE on a journey, not on level N.

### Pillar C — MYSTICAL + WONDROUS (vista, distance, atmosphere, the sense of a world)

The first read on spawning must be WONDER — "look at this place" — not "here's an arena":

- **Layered landscape + distance/vista.** Depth is the headline wonder-lever. Build the expanse in LAYERS receding toward the eastern horizon: near open cobble → mid-ground buildings → a far, smaller outbuilding → an implied distance/sky-edge beyond. The long eastward sightline IS the vista — the player sees a WORLD with distance in it, not a flat floor. (Even within top-down, scale-graded buildings + a horizon-band treatment + atmospheric value-fade toward the far edge sell depth.)
- **Atmosphere = wonder.** Soft warm guttering brazier-light pooling on cobble in the dim, drifting motes/dust in the light shafts, the warm-stone buildings catching a low key-light, the moss + weeds catching damp highlight. The vignette (S1 30%, `vignette-spec.md`) frames the wonder. The mood is **abandoned-but-beautiful, holy-but-hushed, mysterious** — a place with a history you want to uncover.
- **Mystery hooks.** Visual questions that invite wonder: a sealed door you can't yet open, a bell-tower you can't reach, a glow from a window in the central building, faded banners with a symbol you don't recognize, the descent stair breathing ember-light from below (what's down there?). These plant narrative wonder without any content cost beyond placement + a glow.
- **The spawn moment is the wonder thesis.** The very first frame after spawn must say MYSTICAL WONDROUS WORLD: open cobble running to a lit distant cloister under a hushed warm light, a crow lifting off the bell-tower, motes in a brazier's glow, the descent's far ember-hint. If the first frame reads "arena," the whole north-star failed. **This is the single most important frame in S1** — author it deliberately (the spawn vista).

### How the pillars constrain the calls below

- **§2 layout** now reserves NPC-stations + discovery-spots + a deliberate layered-vista + a authored spawn-vista frame — not just combat arenas.
- **§3 floor + §5 decoration** treat vegetation as LIVING reclamation (clustered, varied, creeping) + add ambient-creature placement spots — not just texture.
- **§5 decoration** dials grass DOWN but adds LIFE (creatures, vines, a sapling) — sparse-but-alive beats dense-but-dead.
- **Combat density stays MODERATE** — enough threat to matter, never so much the yard reads as an arena. The world is alive with MORE than enemies.

**Tie-breaker (composing with §0.5):** when a call could go "more combat-arena" or "more living-world-to-explore," choose living-world. Big + endless + ALIVE + WONDROUS + a JOURNEY — in that combined spirit — wins every tie.

---

## 1. TONAL ANCHOR (lead with this — everything ladders down from here)

> **Stratum 1 — Outer Cloister YARD — reads as "an abandoned monastery courtyard that opens onto a WORLD: you spawn into open ground, the cloister buildings stand around and through a vast yard, the cobbles run worn and grown-over toward a horizon that keeps going — no one has swept this ground, and no one has found the edge of it."**

The interior anchor is unchanged in SPIRIT — *"a stone cloister settled into silence: the monks are gone, the candles are guttering, but the room hasn't noticed yet"* (`env-art-s1-direction.md` §1, `s1-ambient.md`). What changes is the **camera relationship to that anchor.** Before: the player stood INSIDE one room of the cloister and the room was the screen. Now: the player stands in the YARD the cloister is built around, and the buildings are structures you traverse past, between, and into. The feel-shift is **interior → open-air**. A courtyard breathes; a room presses in. The cobblestone-and-weeds floor is the single biggest carrier of "open-air" — flagstone says "swept indoor hall," cobble-with-moss-and-dirt says "exposed ground that weather and neglect have worked on."

**The descent payoff is preserved.** S1 must still be the **warmest, most-lit, most-legible stratum** so the S1→S2 temperature-drop into pressure lands (`palette.md` hue arc, `env-art-s1-direction.md` §1). An open courtyard under guttering brazier-light + dim ambient sky is still warm and legible — we are not darkening S1, we are opening it.

**Anti-list (decoration beats that DON'T serve the open-yard anchor — cut them):**
- No active fire/lava/heat floor FX (S2/S6 reward).
- No pristine/swept stone — the yard is overgrown and neglected; moss and dirt are the STORY, not noise.
- No pure black `#000000` (palette.md S1 anti-list — reserved S7-S8; breaks "warm cloister").
- No cyan/teal/violet environment accents (wrong stratum).
- **No interior-hall reads:** no wall-to-wall flagstone, no four-walls-boxing-the-screen framing, no "this is a corridor" linearity. The yard is a SPACE, not a passage.
- **No dense grid-aligned grass** — the #1 decoration complaint. Grass is sparse + jittered + clustered where damp collects, never a regular field (§3).

---

## 2. SPATIAL COMPOSITION — the open yard + buildings + the player journey

### 2.1 The shape: one BIG open expanse, buildings AS landmarks within it

S1 becomes **one continuous traversable expanse** — a much-wider-AND-taller-than-screen open ground the camera scrolls across in BOTH axes, with the cloister **buildings placed as solid landmark-structures across the sides, the middle, and the receding distance** of that ground. The buildings are landmarks WITHIN the bigness (not walls penning the player in); the open cobble between and around them is where you walk and fight. **The expanse is sized so the player never sees all four of its edges at once** — that off-screen continuation is the "endless" read.

```
  ↑ (world continues N — chapel range runs off the top of frame)
  ░░░░ chapel face / bell-tower (recedes off-frame N) ░░░░░░░░░░░░░░░░░░░░
  ┊                                                                      ┊
  ┊   · · open cobble · ·      ▓▓▓▓▓▓        · · open cobble · ·         ┊
  ┊    (weeds, dirt,          ▓CENTRAL▓        long sightline →         ┊
SPAWN→· · sparse moss) · · · ·▓CLOISTER▓· · · · · · · · · · · · · · · · →→  DESCENT
  ┊  (west — world           ▓BUILDING▓     open processional ground   ┊  (east —
  ┊   continues off-frame W)  ▓▓▓▓▓▓        receding toward far edge)   ┊   stair down)
  ┊                                            ░ outbuilding (far,      ┊
  ┊   · · open cobble · ·       ◯ well          small, off toward       ┊
  ┊                          dormitory ruin     the horizon) ░          ┊
  ░░░░ dormitory range (recedes off-frame S) ░░░░░░░░░░░░░░░░░░░░░░░░░░░░
  ↓ (world continues S — ground + ruin run off the bottom of frame)
   (┊ = soft scroll-horizon, NOT a hard wall — reads as "more world that way")
```

- **The expanse runs WEST → EAST as the primary journey axis** (existing S1 traversal: spawn WEST, descend EAST — matches the procgen EAST/WEST port-mating convention, `procgen-pipeline.md`) **but is also taller than the viewport on the N/S axis**, so the camera scrolls vertically too and the chapel/dormitory ranges recede off the top/bottom of the frame. Two-axis scroll is a big lever for "big" — a purely-horizontal corridor reads contained; an expanse you scroll in both directions reads as a place.
- **Buildings are landmarks across the expanse, set BACK from the player's immediate space:** a **north range** (chapel face / bell-tower — the tallest silhouette, running off-frame N so its top is never fully seen = "big building, bigger world"), a **south range** (dormitory ruin + cloister well, receding off-frame S), **1–2 CENTRAL structures** standing IN the expanse (the inner-cloister building Sponsor named — splitting the open ground into traversal channels), and **at least one far/small outbuilding toward the eastern horizon** rendered smaller to imply distance and pull the eye down a long sightline. The buildings are spaced so there is always **open cobble running past them toward an implied-further edge** — never a building-face hugging the screen edge.
- **The open cobble is the dominant surface** — long sightlines across it are the headline "endless" beat. Combat arenas, worn walking-ground, the moss-and-dirt floor (§3). Buildings are SOLID (collision); the expanse ground is open and runs to the soft scroll-horizon.
- **The scroll-bounds are a soft horizon, not a box.** Where `set_world_bounds` clamps the camera, the LAST thing visible should be open ground + a partial building / a far outbuilding / cobble continuing — implying world past the clamp — NOT a perimeter wall that says "the level stops here." (See §2.3 + §6 for the rendering implication.)

### 2.2 The player journey (spawn → traverse → landmarks → descent)

1. **Spawn at the west gate — the WONDER thesis frame** (§0.6 Pillar C). The player materializes in OPEN GROUND at the western edge, looking east across the expanse: open cobble running toward a lit distant cloister under hushed warm light, a crow lifting off the bell-tower, motes in a brazier's glow, the descent's far ember-hint on the horizon. First read must be *"look at this place — a whole mystical world, and it's alive."* NOT *"here's an arena."* The world visibly extends beyond the first screen (long sightline + off-screen buildings). A bounty-poster NPC-station sits at the gate (SEED — populated over milestones). **This is the single most important frame in S1 — author the spawn-vista deliberately.**
2. **Traverse the western open ground — explore first, fight as encounter.** The player WANDERS into the expanse. Ambient life (rats in the rubble, moths at a brazier) makes it breathe. A first MODERATE combat encounter — cloister-penitent grunts (PR #411) inhabit the open cobble — but the open ground + landmarks read as a place to explore, not a clearing to clear. A discoverable item-glint in a mossy corner off the main line rewards wandering.
3. **Navigate around the central building — the landmark + discovery beat.** The player CHOOSES a route: left (north, past the chapel face + its NPC-station on the steps) or right (south, past the well + dormitory ruin, where a treasure-cache hides off the critical path). The central building is the expanse's spatial anchor — you orient by it and want to know what's inside (a lit window = mystery hook). Braziers + banners on the building faces (carried-forward props) light the route; vines + a sapling show nature reclaiming it.
4. **Cross to the eastern processional ground — the vista deepens.** The expanse opens toward the layered eastern distance: a far, smaller outbuilding anchors a long sightline; the bronzed-trim + ember-glow density rises (the "something important ahead" funnel, carried from `env-art-s1-direction.md` §2c). The player feels they're journeying DEEPER into the world.
5. **Reach the descent stair (east) — the mystery payoff.** The S1→S2 transition: a stair DOWN into the Cinder Vaults breathing ember-light from below (what's down there?), replacing the abstract "door to next room." The journey continues; the world keeps going.

The journey is **one continuous exploratory walk across a living place**, not five teleports between boxes, and not a combat corridor. Combat is an encounter along the way; exploration + wonder + discovery are the experience. No "ROOM N/8" counter — the world-map / region-name HUD (`world-map-direction.md`, `hud-boss-region-spec.md`) carries place-identity: you're SOMEWHERE on a journey.

### 2.3 How it reads BIG and ENDLESS, not crammed (the binding feel-gate)

The "crammed/small" failure had three causes; the big+endless fix targets each AND adds the off-screen-continuation lever:

| Crammed cause (old) | Big + endless fix |
|---|---|
| Single-screen room = walls on all four edges of the viewport, always | Much-larger-than-screen expanse; the camera SCROLLS in BOTH axes (`CameraDirector.follow_target` + `set_world_bounds(expanse_bounds)`), so the player never sees all four edges at once — there is always more world off-frame. |
| Floor butts into wall ~6 tiles in every direction | Open cobble runs for MANY screen-widths with long sightlines; buildings are landmarks WITHIN the ground, set back, receding off-frame — never a near wall. |
| Flagstone = indoor hall material | Cobble + moss + dirt = outdoor-ground material; the eye reads "open courtyard onto a world," not "corridor." |
| Finer floor scale ("small player, large world") | Finer tiles (§3 + §5) make the player a small figure in a vast place — the `tile-scale-small-player-large-world` north-star is the visual proof of "big + endless." |
| Bounded box → "the level ends here" | **Soft scroll-horizon:** at the camera-bounds clamp the last visible band is open cobble + partial/far buildings, implying world past the clamp. The bound feels like a horizon, not a box wall (the "endless" read). |

**Composition contract for Drew + procgen (Stage C):** the expanse is authored as a **multi-chunk floor** (wide on EAST/WEST, also taller-than-viewport on N/S) assembled by `FloorAssembler.assemble_floor(zone_def, seed)` → `AssembledFloor.bounding_box_px`, and `Main._engage_camera_for_room()` switches its `set_world_bounds(...)` source from the hardcoded `S1_ROOM_BOUNDS` (480×270) to `assembled.bounding_box_px` (the full expanse extent). This is the EXACT forward-compat swap already documented in `camera-scroll.md` § "Forward-compat — AssembledFloor.bounding_box_px swap (W2-T3+)" — the wiring centralizes the bounds value in ONE place precisely so this pivot is a single-source change, not a rewrite. **Two-axis scroll note:** for an expanse taller than the viewport, the bounds-clamp takes the standard "wider/taller than viewport → clamp to edges" branch on BOTH axes (vs the single-screen room's "narrower than viewport → hold at center" branch) — this is the existing clamp math (`camera-scroll.md` § Bounds-clamp math), no new code, just a bounds rect bigger than the viewport on both axes. The expanse's chunks mate via the EAST/WEST port convention (`procgen-pipeline.md`); buildings are placed-prop / chunk-fixture content within the assembled floor. **This composes the shipped camera-scroll + procgen systems into S1 — it does not build a new level system.**

**Endless-read authoring rules (the soft-horizon discipline) for Stage C:**
- **No perimeter wall hugging the bounds.** The expanse edge is open cobble fading toward a far building / outbuilding, NOT a screen-edge wall. The eye should never hit a hard "this is the boundary" face at the scroll-clamp.
- **Buildings run off-frame.** Place the chapel/dormitory ranges so their tops/sides exceed the bounds — a building you can't see all of reads as part of a bigger world.
- **A far, smaller outbuilding toward the east horizon** anchors a long sightline and implies depth/distance (the player's eye is pulled "out there").
- **Open cobble continues past every landmark** toward the implied-further edge — density at the landmarks, big openness between them.

---

## 3. FLOOR PALETTE + MATERIAL DIRECTION — cobblestone + moss + dirt

### 3.1 The material shift (sandstone flagstone → cobblestone + moss + dirt)

The current floor is warm sandstone FLAGSTONE (`#7A6A4F` family, cut polished slabs) — an indoor-hall read. The yard floor becomes **rounded cobblestone with moss growing in the joints and dirt/soil patches working through** — an outdoor neglected-ground read. The distinction that carries the feel:

- **Flagstone** = large flat cut slabs, polished smooth, swept clean → "interior hall."
- **Cobblestone** = many small rounded set-stones, irregular, with gaps the moss and dirt invade → "exposed courtyard the weather got to."

This stays inside the warm-cloister mood but shifts the floor a touch **cooler and grayer than the warm sandstone** (cobbles are set-stone/granite-ish, not warm sandstone block) so the cobble reads as a DIFFERENT material from the warm sandstone WALLS/buildings — the buildings stay warm sandstone (carried forward, §4), the YARD GROUND goes cobble-gray-warm. That material contrast (warm sandstone buildings standing on cooler cobble ground) is itself a "buildings ON a yard" read.

### 3.2 The cobble-yard floor doctrine (HDR-clamp-aware, sub-1.0 every channel)

All hexes verified sub-1.0 per channel for WebGL2 sRGB HDR-clamp safety (`html5-export.md` § HDR modulate clamp). This EXTENDS the S1 doctrine with a cobble-ground sub-ramp; the warm-sandstone building ramp from `palette.md` is unchanged (§4).

```
S1_YARD_FLOOR_DOCTRINE = [
  "#6E665A",  # cobble base — warm-gray set-stone (cooler/grayer than #7A6A4F sandstone; the dominant yard tile)
  "#857C6C",  # cobble lit — highlight on a domed cobble top catching ambient light
  "#544C42",  # cobble shadow / deep joint between stones
  "#3D372F",  # joint-deep — the recessed gap where dirt + shadow collect (NOT #1A1210 wall-shadow; lighter, warmer)
  "#5C7044",  # moss — olive green creeping in the joints + damp clusters (REUSE S1 doctrine moss exactly)
  "#47592F",  # moss-deep — shadowed moss in the wettest joints (new, sub-1.0; darker olive)
  "#6B5A41",  # dirt / soil — bare earth working through where cobbles are missing/sunk
  "#54452F",  # dirt-deep — damp packed soil, shadowed
]
```

**Eye-dropper pin targets (Tess QA criteria):** yard cobble base reads `#6E665A` (PL-YARD-01), moss in joints reads `#5C7044` (PL-YARD-02, matches existing S1 moss), dirt patch reads `#6B5A41` (PL-YARD-03), and the cobble ground is **perceptibly cooler/grayer than the sandstone building walls** `#7A6A4F` (PL-YARD-04 — the material-contrast pin that proves "buildings ON a yard").

### 3.3 The four craft levers for the cobble floor (PixelLab + doctrine-lock target)

| Lever | Cobble-yard application |
|---|---|
| **Material read** | Rounded individual set-stones, each a small domed cobble with a lit top (`#857C6C`) and a shadow at its base (`#544C42`). NOT flat slabs — the eye must read MANY small rounded stones, not few large flat ones. This is the headline difference from flagstone. |
| **Joint discipline** | Between cobbles sit irregular dark joints (`#3D372F`) where dirt and shadow gather — and where moss (`#5C7044`/`#47592F`) and dirt (`#6B5A41`) invade. The joint is a GAP-between-rounded-stones, never a clean grid-border (the wallpaper failure). Irregular joint width is the craft. |
| **Organic invasion** | Moss creeps in the joints and clusters in damp patches (corners, building shadows, the well's surround); dirt works through where cobbles have sunk or gone missing. This invasion is RANDOM and CLUSTERED (§3 decoration rules), never uniform. The overgrowth IS the "abandoned yard" story at floor level. |
| **Tonal + wear variation** | Cobble tone drifts `#6E665A` (base) → `#857C6C` (worn-lit foot-path stones) → `#544C42` (sunk/damp stones). The foot-worn lighter path can trace the spawn→descent route across the yard (a tonal-storytelling beat — where the monks used to walk). No two adjacent cobble patches identical. |

### 3.4 Finer scale (the "small player, large world" north-star)

The current floor reads "a touch too large at 2×." Go FINER:

- **Generate the cobble floor at a finer effective resolution** so each cobble is smaller relative to the player — many small set-stones per tile rather than few large ones. Per `tile-scale-small-player-large-world` + `pixellab-pipeline.md` aspect-ratio two-step-downsample: the downsample caps at 2× before gridding artifacts appear, so achieve "finer" by generating DENSER cobble (more, smaller stones in the source) rather than relying on further downscale.
- **In-engine tile stays 32px** (chunk grid `tile_size_px=32`, unchanged) — "finer" means the cobble PATTERN within each 32px tile is denser (smaller stones), not a different grid size. The source PNG ships at the existing 128×128 set scale so slicing math is unchanged; the cobbles within are smaller/denser than the old flagstone slabs.
- **Variant set, not a single stamp** (anti-repeat, same discipline as `s1-tile-rework.md` §2.2): **5–6 cobble base variants** (different stone-layout + moss/dirt-invasion patterns) + **2–3 accent tiles** (heavy-moss cobble, dirt-through cobble, sunk/missing-cobble). Drew alternates variants so a wide yard never reads a tile-repeat. Across the multi-chunk yard this is critical — a wide scrolling floor exposes repeats far more than a single-screen room did.

### 3.5 PixelLab gen targets (orch run-sheet — orch-session only per pixellab-pipeline.md)

| Gen | Tool | Intent (the prompt's job) | Doctrine note |
|---|---|---|---|
| **Cobble yard floor set (5–6 variants)** | `create_topdown_tileset` | "Worn rounded cobblestone courtyard ground, many small set-stones, irregular dirt-and-shadow joints, olive moss creeping in the gaps, patches of bare dirt where stones have sunk, neglected overgrown outdoor yard, subtle stone-to-stone tonal variation, NO uniform grid border — top-down RPG tileset" | Lock to `S1_YARD_FLOOR_DOCTRINE` §3.2. Strategy 3 per-slot nearest-neighbor; over-request `quantize_palette target_colors≈12` for the 8-hex ramp. Strip any heavy per-tile outline (VD-13 — tiles get NO outline). Sub-1.0 every channel. |
| **Cobble accents (heavy-moss ×1, dirt-through ×1, sunk/missing-cobble ×1)** | `create_topdown_tileset` / `create_map_object` | "Cobblestone with thick olive moss overgrowth" / "patch of bare dirt where cobbles are missing" / "sunken broken cobbles with dirt and weeds" | Moss → `#5C7044`/`#47592F`. Dirt → `#6B5A41`/`#54452F`. The repeat-breakers + organic-invasion story. |
| **Yard floor→building seam (×1–2)** | `create_topdown_tileset` | A cobble-meets-building-base seam (dirt + shadow line `#3D372F`) so the cobble ground doesn't butt flat into a building wall | `#544C42` deep + `#3D372F` shadow. |

**Iteration discipline:** generate → doctrine-lock → mock-tile across a WIDE yard span at game zoom (the binding view — a wide scrolling floor, not an isolated swatch, per `TESTING_BAR.md` §"judge art in context") → judge against §3.3 craft levers → regen if it reads flat, reads as flagstone, or stamps a repeat. Budget 2–3 passes; the cobble floor is the single most-important surface of this pivot. Per Sponsor's "budget not a constraint — quality is the goal" directive (`s1-tile-rework.md` §5), iterate until the yard reads as overgrown cobble courtyard at game zoom.

---

## 4. WHAT CARRIES FORWARD vs WHAT CHANGES

### 4.1 Carries forward (verbatim — do NOT regen)

- **All 7 crafted props** (`assets/props/s1_cloister/`, PR #408 + earlier): `pillar_arch` (48×64), `brazier_lit` / `brazier_cold` (32×48), `banner_worn` (32×48), `rubble_01` (32×32), `parchment_01` (32×32), `moss_patch` (32×32). These doctrine-lock cleanly and read crafted; they re-deploy ONTO the building faces + into the yard. Braziers + banners light the building faces along the journey; pillars become the cloister-building colonnade FACES (the building edges that front the yard); rubble + parchment + moss-patch scatter as settle-decoration in the yard corners and at building bases.
- **The warm-sandstone BUILDING/WALL doctrine** (`palette.md` S1 env ramp: wall base `#4A3F2E`, trim `#9A7A4E`, moss `#5C7044`) — the cloister BUILDINGS stay warm sandstone. They are the structures standing ON the cobble yard. The material contrast (warm sandstone buildings / cooler cobble ground) is load-bearing for the "buildings on a yard" read (§3.1).
- **The tonal anchor's SPIRIT** (abandoned, holding-its-breath, monks-gone) and the **descent payoff** (S1 = warmest/most-lit/most-legible) — both unchanged.
- **The mob/character art** (PR #409–#416: monk player rig, cloister-penitent grunt, brazier-warden shooter, bone-hound charger) — all unchanged; they inhabit the yard.
- **The shipped camera-scroll + procgen systems** — composed, not rebuilt (§2.3).
- **The S1 character-direction, ambient, audio, and HUD specs** — `character-monster-direction.md`, `s1-ambient.md`, `s1-decoration-density.md` (its keep-clear + mob-reach thinking carries; its room-bound geometry is superseded by the yard), `audio-direction.md`, `world-map-direction.md`.

### 4.2 Changes

- **Floor MATERIAL:** sandstone flagstone → cobblestone + moss + dirt (§3). New PixelLab floor regen (orch-only). The old `floor_sandstone.png` is replaced by the cobble set for the YARD ground; sandstone tiles MAY survive as building-interior floors if any building has a walk-in interior (Drew/Priya scope call).
- **Floor SCALE:** finer / denser cobble (§3.4).
- **Spatial STRUCTURE:** 8 discrete rooms → one open traversable yard with buildings as structures (§2). Drives a Priya ticket-breakdown for the procgen zone-def + chunk authoring + camera-bounds swap.
- **Wall-brick SCALE:** the perimeter wall bricks read too large once the floor is finer — shrink the building-wall brick scale to match (§5). This is a regen of the wall set at finer brick scale (warm-sandstone doctrine unchanged, brick SIZE finer), OR a re-slice if the existing wall tile supports it (Drew/orch call).
- **Decoration density:** grass/moss/dirt dialed DOWN and randomized (§5 + the decoration rules below).

---

## 5. PROP / WALL / DECORATION SCALE + DENSITY

### 5.1 Scale targets relative to the player + finer tiles

`char_scale=0.6` is the shipped production player size (PR #405). Against the finer cobble floor:

| Element | Scale target | Rationale |
|---|---|---|
| **Cobble stones** | Many small rounded stones per 32px tile (denser than old flagstone slabs) | "Small player, large world" — finer ground makes the player read small in a big yard. |
| **Building-wall bricks** | SHRINK to ~match the finer cobble density — bricks read small/coursed, not oversized blocks | The current perimeter bricks read "out of place / oversized" against a finer floor (Sponsor). Brick scale should harmonize with cobble scale — neither dominates. |
| **Pillars / building faces** | Carried-forward `pillar_arch` (48×64) reads correctly as a building-face column at `char_scale=0.6` — tall relative to player, anchoring the building silhouette | Pillars front the cloister buildings; they SHOULD read large (they're architecture the player walks past), unlike the floor which goes finer. |
| **Braziers / rubble / parchment / moss-patch** | Carried-forward sizes (32×48 / 32×32) read correctly at `char_scale=0.6` | These are reused as-is; they sit on the building faces + yard corners. |

The principle: **FLOOR + WALL-BRICK go finer (small ground, small bricks = large-world read); BUILDING SILHOUETTES stay large (architecture the small player moves through).** That scale split is what sells "small player in a large cloister yard."

### 5.2 Decoration density + placement (dial DOWN + randomize — the #1 grass complaint)

Current grass is too dense + grid-aligned. The rules for Drew (Stage C):

- **Grass tufts: SPARSE + JITTERED + CLUSTERED, never a field.** Place grass only where it diegetically grows — in cobble joints, at building bases (damp), in corners, around the well, where dirt patches break through. **Target density: roughly 1 grass cluster per ~6–10 tiles of open cobble**, NOT one per tile. Each placement is **position-jittered** (random offset within its tile, not snapped to grid center) and **rotation/variant-jittered** if the asset supports it. Cluster 2–3 tufts together occasionally (grass grows in patches) rather than evenly spacing singles.
- **Moss: in the floor TILES (the cobble-joint moss, §3) + sparse moss_patch props clustered in damp zones** (building shadows, north-wall base, the well surround, corners). The tile-level moss carries most of the moss story; the moss_patch prop is for heavier damp accents, placed randomly ~1 per 8–10 tiles in damp zones only.
- **Dirt: in the floor TILES (the dirt-through cobble accents, §3), clustered where cobbles have sunk** (high-traffic center, gate approaches). Random placement, not uniform.
- **Settle-decoration (rubble / parchment): pooled at building bases + yard corners + the central building's feet**, not scattered across open ground. The open cobble walking-ground stays clear (combat + traversal space). Density at the edges + building-feet, clear in the open lanes — the same "density at edges, clear in the middle" principle from `s1-tile-rework.md` §3.1, applied to the yard.

**The jitter rule is the headline decoration fix:** the eye must NEVER find a regular grid in the grass/moss/dirt scatter. Jittered + clustered + sparse = "nature reclaimed this neglected yard." Dense + grid-aligned = "someone placed decoration on a tilemap." Cut any placement that reads as the latter.

### 5.3 LIVING decoration — ambient life + reclamation (Pillar A/C, §0.6)

Sparse-but-ALIVE beats dense-but-dead. The dialed-down vegetation budget is REINVESTED in life, not just removed:

- **Ambient creatures (the cheapest highest-impact "alive" lever — ship a few in S1):**
  - **Crows / birds** on the bell-tower + chapel roofline — silhouette sprites that occasionally shift/lift (a crow taking off as the player nears the chapel is a wonder-beat). 2–3 perched, looped.
  - **Rats / mice** scurrying between rubble piles + dormitory ruin — small looped-path sprites, no combat.
  - **Moths / insects** drifting near the lit braziers — tiny drift-motion (particle-ish or simple looped sprite). Cheapest of all.
  - **(Stretch) a stray cloister cat** by the well — a single ambient character, idle-loop.
  - These are AMBIENT (zero combat, low cost) and they are what make the world BREATHE. Place at landmarks (roofline, rubble, braziers, well). Reserve the vocabulary for more later.
- **Vegetation as LIFE, not decay-noise:** the moss/weeds/grass read as nature RECLAIMING the cloister — a **vine creeping up a chapel wall**, a **sapling pushing through the cobbles near the well**, grass clustered where damp + light meet. A few hero living-plant beats (vine, sapling) at landmarks elevate "alive" far more than scattered tufts. (Vine + sapling = 1–2 new prop gens, or fold into building-base decoration.)
- **NPC-stations (SEED — author the SPOTS now, populate over milestones):** keep a clear, lit, approachable footprint at the **west gate** (bounty-poster), **chapel steps** (hooded figure), **well** (caretaker/penitent), **central building entrance**. Even if S1 ships 0–1 NPCs, the layout must not block these spots with combat-clutter — they're where the world's inhabitants go.
- **Discovery-spots (SEED — reserve, fill a couple):** a treasure-cache footprint in the dormitory ruin, a glint-drop spot in a mossy corner, a hidden-alcove behind the central building. Off the critical path; reward wandering (§0.6 Pillar B).

**Placement budget caveat:** ambient life + NPC/discovery stations sit OFF the open combat lanes (at landmarks + edges), so they add LIFE without crowding the open expanse or compromising the big+endless sightlines (§0.5). Density at landmarks; openness between them.

---

## 6. HTML5 / WebGL2 RISK SURFACE (constrains the primitives)

| `html5-export.md` class | Yard application |
|---|---|
| **HDR modulate clamp** | All `S1_YARD_FLOOR_DOCTRINE` hexes sub-1.0 per channel (§3.2) — verified. Any door/descent ember-glow uses the existing `#FF6A2A` @60% (sub-1.0). |
| **Polygon2D → ColorRect rule** | Any cone/sweep/glow-wedge primitive (descent-stair ember-glow, any directional light cue) is a **rotated ColorRect, NOT a Polygon2D** — per the PR #137 HDR-clamp + Polygon2D + WebGL2 invisibility precedent. Tiles are TileMap render-path (fine); props are Sprite2D (fine); the rule binds any NEW glow/sweep decoration the yard adds. |
| **Z-index** | Floor z=0, building/props z=+1, player above — no negative z-index (PR #137). A wide scrolling yard exposes z-ordering at chunk seams more than a single room did (the camera-scroll § "Z-index sensitivity" highest-risk class) — Drew verifies cobble-chunk seams have no z-fight under `gl_compatibility`. |
| **Ambient-life primitives** | Ambient creatures are **Sprite2D / AnimatedSprite2D** (crow, rat, cat) or simple looped sprites / `CPUParticles2D`-free drift for moths — all renderer-safe. Any moth-drift implemented as `CPUParticles2D` falls under the visual-verification gate (PR #291 burst-class) → screenshot/soak required; prefer a simple looped-sprite drift to stay off that gate. No glow-wedge / cone primitive on ambient life → no Polygon2D risk. |
| **Visual-verification gate** | The cobble TileMap render + any modulate/glow + ambient-life animation is HTML5-gated. The big two-axis-scrolling living expanse is a first-of-class spatial surface → **Sponsor soak is the visual gate of record** (subjective big/endless/alive/wonder FEEL + finer-scale + decoration-density + spawn-vista are taste calls, not mechanical-correctness calls Playwright can pin). Probe targets: "does it read entering-a-big-living-WORLD, not a room or arena?", "does the spawn-vista frame land as wonder?", "does the world feel like it continues off-screen (soft horizon, not a box)?", "is the cobble perceptibly cooler than the sandstone buildings?", "is the floor scale finer / does the player read small in a big space?", "is the grass sparse + random not a grid?", "do the ambient creatures make it feel alive?", "does the camera scroll smoothly in both axes with no chunk-seam z-fight?". |

---

## 7. CROSS-REFERENCES (every anchor / hex / system above traces here)

- `.claude/docs/camera-scroll.md` — `CameraDirector.follow_target` + `set_world_bounds` + the **`AssembledFloor.bounding_box_px` swap** (§ Forward-compat) that this pivot consumes to scroll the yard; the `Main.S1_ROOM_BOUNDS` → `assembled.bounding_box_px` single-source change.
- `.claude/docs/procgen-pipeline.md` — `FloorAssembler.assemble_floor` + `AssembledFloor.bounding_box_px` + EAST/WEST port-mating (the yard is a multi-chunk assembled floor).
- `.claude/docs/html5-export.md` — HDR-clamp sub-1.0 every channel; Polygon2D→ColorRect for cones/sweeps (PR #137); z-index (floor z=0, props z=+1); visual-verification gate + Sponsor-soak routing.
- `.claude/docs/pixellab-pipeline.md` — `create_topdown_tileset` + canvas-size trap + doctrine-lock Strategy 3 (per-slot nearest-neighbor) + quantize over-request + aspect-ratio two-step downsample (the "finer" mechanism) + orch-session-only execution.
- `team/uma-ux/palette.md` — S1 warm-sandstone BUILDING/WALL doctrine (unchanged, carried forward §4); anti-list (PL-09 no pure-black, PL-11 mob eye-glow). The new `S1_YARD_FLOOR_DOCTRINE` (§3.2) extends this for the cobble GROUND.
- `team/uma-ux/env-art-s1-direction.md` (`86ca3gvgb`) — the LOCKED Outer Cloister tonal anchor §1 (spirit preserved); sub-biome funnel §2c (carried as the eastern descent approach); HTML5 constraints §4.1.
- `team/uma-ux/s1-tile-rework.md` (`86ca44p4j`, PR #408) — superseded SPATIALLY (rooms/colonnade) + MATERIALLY (flagstone); its PROP assets + anti-repeat variant-set discipline §2.2 + density-at-edges §3.1 carry forward; its `S1_ENV_DOCTRINE` building-ramp §7 is the building doctrine here.
- `team/uma-ux/s1-decoration-density.md` (`86ca3yuwv`) — its keep-clear + mob-reach + warmth-gradient thinking carries; its room-bound geometry is superseded by the yard.
- `team/uma-ux/visual-direction.md` — 32px tile / nearest-neighbour / **VD-13 tiles get NO 1px outline** (the cobble set takes no per-tile outline).
- `team/TESTING_BAR.md` §"judge art in context" + Pre-soak Gate 4 — cobble judged tiled across a WIDE yard span at game zoom + `char_scale=0.6`, never isolated swatches.
- Memory: `s1-cloister-yard-open-world-direction` (the Sponsor pivot), `tile-scale-small-player-large-world`, `m3-diablo-shape-directive`, `sponsor-prefers-ai-gen-tile-quality`.
- Carried-forward assets: `assets/props/s1_cloister/` (7 props + `_generation_map.md`); `assets/tilesets/s1_cloister/` (wall_cloister to re-scale finer; floor_sandstone superseded by cobble set).

---

## 8. Decision draft + Sponsor sign-off surface

**Decision draft (2026-06-07)** — for Priya's weekly `DECISIONS.md` batch (NOT direct-edited per Uma role rule):
> **S1 cloister-YARD spatial pivot directed** (supersedes the discrete-room + flagstone model). North-stars (Sponsor 2026-06-07): the player is **ENTERING A WORLD that is BIG, ENDLESS, ALIVE, MYSTICAL/WONDROUS, experienced as a JOURNEY** — not a room, not an arena. S1 becomes ONE big open traversable cobblestone EXPANSE the camera scrolls across in BOTH axes (larger than viewport on W/E and N/S; soft scroll-horizon, off-screen continuation, long sightlines, layered vista toward an eastern far-outbuilding horizon — reads as world-continuing-past-the-edge, never a box). Cloister BUILDINGS are landmark-structures across the sides + middle + receding distance (north chapel/bell-tower running off-frame / south dormitory+well / 1–2 central buildings / 1 far outbuilding). LIVING-WORLD pillars: INHABITED (ambient creatures — crows/rats/moths, ship a few; NPC-stations reserved at gate/chapel/well/central-building, populated over milestones; vegetation as nature reclaiming — vine/sapling hero beats), JOURNEY (exploration over arena; treasure/discovery spots off the critical path; landmark-to-landmark travel; no ROOM N/8), WONDER (authored spawn-vista as the thesis frame; layered depth/distance; atmosphere; mystery hooks — lit window, sealed door, ember-breathing descent stair). COMPOSES the shipped `CameraDirector` continuous-scroll + procgen `FloorAssembler` (swap `Main.S1_ROOM_BOUNDS` → `AssembledFloor.bounding_box_px` — single-source, forward-compat-documented; two-axis bounds = existing clamp math), NOT a new level system. FLOOR re-materialed sandstone flagstone → COBBLESTONE + MOSS + DIRT (new `S1_YARD_FLOOR_DOCTRINE` 8-hex ramp, cobble cooler/grayer than warm-sandstone buildings for a "buildings on a yard" contrast, sub-1.0 HDR-clamp-safe), FINER scale (denser cobble; bricks shrunk to match). DECORATION dialed DOWN + RANDOMIZED but REINVESTED in LIFE (grass sparse+jittered+clustered ~1 per 6–10 tiles never a grid; ambient creatures + vine/sapling at landmarks). CARRIES FORWARD: 7 crafted props, warm-sandstone building doctrine, tonal-anchor spirit, mob/character art, camera+procgen systems, dialogue/quest systems (NPC/quest SEEDS). CHANGES: floor material+scale, spatial structure, wall-brick scale, decoration density+life. GEN SCOPE: ~3–4 `create_topdown_tileset` (cobble floor set 5–6 variants + accents + seam) + ~2–4 ambient-life/vegetation gens (crow/rat/moth + vine/sapling) with 2–3 planned regen passes, orch-run, doctrine-lock Strategy 3; iterate until it reads alive overgrown-cobble-WORLD at game zoom. Sponsor soak is the visual gate of record (big/endless/alive/wonder/journey are taste calls). Reversibility: floor PNG swaps + zone-def/chunk authoring + the one-line bounds-source swap + ambient-life nodes are revertible.

**Sponsor sign-off surface (what to veto/approve before any generation/build):**
1. **Overarching feel** (§0.5 + §0.6): BIG + ENDLESS + ALIVE + WONDROUS + a JOURNEY — open continuous expanse, off-screen continuation, inhabited world, exploratory wonder, not a combat arena. Is this the right read of your north-stars?
2. **Spatial composition** (§2): one big expanse the camera scrolls across in both axes; north/south/central/far building landmarks; soft scroll-horizon + layered eastern vista; west-spawn→east-descent journey. Right "entering a world" read?
3. **Floor material + doctrine** (§3): cobblestone + moss + dirt, cooler/grayer than the sandstone buildings, finer scale, `S1_YARD_FLOOR_DOCTRINE` ramp. Right material for "open living courtyard, not interior hall"?
4. **Living-world pillars** (§0.6 + §5.3): ambient creatures (crows/rats/moths) + NPC-stations + discovery-spots + vine/sapling reclamation — ship some, seed the rest. Right "alive + journey + wonder" plant? Right S1 ship-vs-seed split?
5. **Carry-forward vs change split** (§4): keep 7 props + sandstone BUILDINGS + mob art + dialogue/quest systems; change floor material/scale + spatial structure + brick scale + decoration; ADD ambient life. Right scope boundary?
6. **Decoration density + life** (§5.2/§5.3): grass sparse + jittered + clustered (never a grid), reinvested in ambient life at landmarks, open lanes clear. Right "dialed down but alive" target?
7. **Scale split** (§5.1): floor + wall-brick go FINER; building silhouettes stay LARGE + recede off-frame. Right "small player, big living world" read?
