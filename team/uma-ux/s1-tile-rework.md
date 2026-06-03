# S1 Tile-Quality Upgrade + Lined-Hall Rework — "Make the Cloister Read Crafted"

**Owner:** Uma (Stage A — direction) → orch (Stage B — PixelLab gen on this spec) → Drew (Stage C — impl) · **Ticket:** `86ca44p4j`
**Sponsor:** taste-veto on this DIRECTION before any generation/build. This goes to **Sponsor sign-off** first.
**Phase:** M3 S1 polish · **Look:** "Outer Cloister" — **LOCKED** (env-art brief `env-art-s1-direction.md`, `86ca3gvgb`). This is a **craft upgrade WITHIN the locked look**, not a re-think.
**Supersedes:** the reuse-only approach in PR #407 / brief `s1-decoration-density.md` (Sponsor REJECTED on feel 2026-06-03). The decoration *thinking* from that brief survives — recomposed here into an intentional colonnade.
**OOS:** generating art (orch runs PixelLab on this spec); coding / `.tscn` (Drew Stage C); widening other rooms (S1B/S3 later); a new biome look (Outer Cloister kept).

---

## 0. Why #407 was rejected (one paragraph, so the fix targets the real failure)

Sponsor verbatim: *"this is not a lined hall, the objects placed look out of place and does not block user either. im not satisfied with the tile design, you should use more time on making that nice."* Three distinct failures stacked: (1) **the tiles themselves have no craft** — the floor is a flat uniform warm-brown and the wall tile repeats IDENTICALLY around the whole perimeter, so the room reads as *wallpaper*, not architecture. This is the exact "grid of bordered boxes / tiled wallpaper" anti-pattern I warned against in my own env-art brief §6.3 and that `TESTING_BAR.md` §"judge art in context" codifies — and #407 shipped it. (2) **The props are scattered singles**, not a composed hall — 2 lone pillars + random rubble/scroll/banner reads as clutter, not a colonnade. (3) **Nothing blocks the player**, so the space has no physicality. This rework fixes all three: premium tiles with a repeat-breaking set (the headline), a symmetric colonnade composition, and collision on the solid props. **The tile upgrade is the part that most needs to land — a beautiful colonnade on wallpaper tiles still fails.**

---

## 1. TONAL ANCHOR (unchanged — this is a craft upgrade, not a new look)

> **Stratum 1 — Outer Cloister — "a stone cloister settled into silence: the monks are gone, the candles are guttering, but the room hasn't noticed yet."** The widened antechamber is a **processional hall built for a crowd that no longer comes** — and a hall is supposed to be *lined*. The player walks a worn central aisle flanked by the colonnade and ritual-remains of a place that outlived its purpose.

Every upgrade below ladders down from this. The craft we are adding is the craft of **a real worked stone hall**: stones the monks polished smooth with their feet, mortar gone dark at the joints, a few flagstones cracked and sunk, moss creeping where damp collects, bronze trim gone green at the seams. **"Crafted" = the hand of a mason is visible. "Wallpaper" = a stamp repeated.** That is the whole job.

**Anti-list (unchanged from env-art brief, re-stated because it constrains the gen):**
- No active fire/lava/heat floor FX (S2/S6 reward).
- No pristine/repaired stone — every surface worn, cracked, mossed, or guttered.
- No pure black `#000000` (anti-list; reserved S7-S8) — darkest S1 dark is `#1A1210`.
- No cyan/teal/violet environment accents (wrong stratum).
- **NEW anti-beat:** no obvious tile-stamp repeat. If the eye can find the seam grid across a wall run at game zoom, the tile failed.

---

## 2. TILE-UPGRADE SPEC (the headline) — premium floor + wall, repeat broken

**Locked palette** — every tile below uses ONLY the `S1_ENV_DOCTRINE` 12 hexes (§7.1, from `palette.md`). Doctrine-lock via Strategy 3 (per-slot nearest-neighbor) per `pixellab-pipeline.md`. We are NOT changing the palette; we are changing the *craft* applied to it.

### 2.1 What makes a tile read CRAFTED (the four craft levers)

These are the levers PixelLab must hit and that pixel-mcp must preserve through doctrine-lock. Each is a concrete instruction, not a vibe.

| Lever | Floor application | Wall application |
|---|---|---|
| **Material read** | Flagstones, not flat fill: each stone is a discrete polished slab with a faint domed lit-top (`#A89677` highlight on the upper-left lip) and a settling shadow on the lower-right (`#5C4F38`). The eye should read *cut stone*, not *brown paper*. | Coursed ashlar masonry: visible individual blocks in a running-bond (offset-row) pattern, each block with a lit top edge (`#9A7A4E`-leaning) and shadowed underside. Reads as *stacked worked stone*. |
| **Edge wear** | Corners of flagstones rounded/chipped; a few stones more worn (lighter, `#A89677`-dominant — the foot-traffic path) than others. Wear is *uneven* — that unevenness is the craft. | Block edges chipped irregularly; some blocks darker/more weathered than neighbors. A few blocks cracked. |
| **Seam / grout discipline** | Mortar lines between flagstones are a thin `#5C4F38` recessed groove with a `#1A1210` shadow only on the shadow side — NOT a full dark box-border around every tile (that's the wallpaper failure). Seams should read as *grooves between stones*, irregular in width, never a clean grid. | Mortar joints `#1A1210` in the recessed courses, thin and irregular. The `#1A1210` is a JOINT line (coursed-stone detail), explicitly NOT a silhouette outline (VD-13 — tiles get no outline). |
| **Tonal variation** | Across the floor, base flagstone tone drifts subtly between `#7A6A4F` (base), `#5C4F38` (sunk/damp stones), and `#A89677` (worn/lit stones). No two adjacent tiles identical in tone. | Block tone drifts between `#4A3F2E` (base) and `#5C4F38`/`#9A7A4E` accents. Weathering varies block-to-block. |

### 2.2 HOW TO BREAK THE WALLPAPER REPEAT (the critical part)

The repeat is the #1 Sponsor complaint. Two mechanisms, used together:

**(A) Multi-tile VARIANT SET, not a single stamp.** Generate a *set* of interchangeable tiles per surface so the painter can scatter variants and the grid never reads:

- **FLOOR: 5 base-flagstone variants** + **2 accent/scatter tiles.** Same `#7A6A4F` family, same flagstone size, but each variant has a *different crack/wear/stone-layout pattern*. When Drew paints the floor he alternates the 5 variants pseudo-randomly so no 2×2 block ever repeats. (Wear-path variant — the lighter, foot-polished stones — gets placed down the central aisle to literally show where the crowd used to walk. That's a tonal-storytelling beat, not just anti-repeat.)
- **WALL: a proper Wang/autotile SET, not one repeated block.** Coursed-ashlar running-bond pattern across the set so block joints stagger row-to-row (real masonry never stacks joints vertically — the vertical-aligned joint is what made #407 read as wallpaper). Plus **2–3 wall-block variants** (clean / weathered / cracked) the painter scatters along the run.

**(B) ACCENT tiles that interrupt the field.** A handful of "this one is different" tiles that break any residual rhythm:

- **Floor accent — cracked/sunk flagstone** (1–2 variants): a stone that has fractured and sunk slightly, heavier `#5C4F38` recess. Scattered ~1 per 8–10 floor tiles. Flat, lane-safe (no standing object), textures the biggest bare surface.
- **Floor accent — moss-creep flagstone** (1 variant): `#5C7044` olive moss creeping across a stone, for damp corners + south band. Reuses the moss beat as a *tile* (under the props), adding floor-level material story.
- **Wall accent — alcove/niche block** (1 variant): a single recessed arched-niche block (the OLD wall's arched-alcove motif — Sponsor flagged the *repeated* alcove as "the worst offender," so we keep ONE as a rare accent, NOT the whole wall). Placed sparingly (1–2 per wall run) it reads as *architecture*; stamped every tile it read as wallpaper. This is the exact fix: demote the alcove from base-tile to rare-accent.

**The rule for Drew (Stage C):** paint floor by alternating the 5 base variants + sprinkling the 2 accents; paint walls with the running-bond autotile + scatter the 2–3 block variants + place the niche accent rarely. **Never the same tile twice in a row along any run.**

### 2.3 Concrete PixelLab gen targets (orch run-sheet)

Tool: `mcp__pixellab__create_topdown_tileset` for floor + wall (it advertises top-down tilesets). Canvas is always square — plan the `crop_sprite` + per-tile slice; confirm dims with `get_sprite_info` (canvas-size trap). In-engine tile = 32px (chunk grid `tile_size_px=32`); source PNGs the existing set ships at 128×128 — match that so slicing math is unchanged. Doctrine-lock Strategy 3, over-request `quantize_palette target_colors≈16` for the 12-hex palette.

| Gen | Tool | Intent (the prompt's job) | Doctrine note |
|---|---|---|---|
| **Floor flagstone set (5 variants)** | `create_topdown_tileset` | "Worn polished sandstone flagstone floor, individual cut stones with rounded chipped edges, irregular mortar grooves, NO uniform border grid, subtle tonal variation stone-to-stone, some stones cracked or foot-worn lighter — top-down RPG tileset" | Lock to `#7A6A4F`/`#5C4F38`/`#A89677` floor ramp + `#1A1210` shadow-side groove. Strip any heavy per-tile outline (VD-13). |
| **Floor accents (cracked-sunk ×1–2 + moss-creep ×1)** | `create_topdown_tileset` or `create_map_object` overlay | "Single cracked sunken sandstone flagstone, deep fracture" / "olive moss creeping across a sandstone flagstone" | Cracked → `#5C4F38` recess + `#1A1210` fracture line. Moss → `#5C7044`. |
| **Wall ashlar set (running-bond autotile + 2–3 block variants)** | `create_topdown_tileset` (Wang/blob layout) | "Coursed ashlar cloister stone wall, running-bond offset blocks, individual worked stones with lit top edge and shadowed underside, irregular dark mortar joints, some blocks weathered or cracked, NO repeating arched-alcove motif — top-down RPG wall tileset" | Lock to `#4A3F2E` base + `#9A7A4E` lit-edge trim + `#5C4F38` weather + `#1A1210` joint. Joints are coursed-stone detail, NOT silhouette outline. |
| **Wall niche accent (×1)** | `create_map_object` (single block) or part of the wall set | "Single recessed arched stone niche set into a cloister wall, worn bronze-trim edge, empty — rare accent block" | `#9A7A4E` trim arch + `#4A3F2E` body + `#1A1210` interior shadow. |

**Estimated tile gens: ~3–4 `create_topdown_tileset` calls** (floor set, wall set, possibly a floor-accent pass + a niche) — iterate on craft until they read premium at game zoom per Stage B. Floor + wall are the two that MUST nail premium; accents are the repeat-breakers.

**Character-beat override during doctrine-lock:** the only saturated accent in env tiles is the door ember-glow (if a door tile is in-frame) — verify nearest-neighbor routes the brightest flame slot to `#FF6A2A`, not a muddy `#9A7A4E`. Manual-override per the Grunt eye-glow pattern.

---

## 3. LINED-HALL COMPOSITION — the colonnade (arrangement pattern, not pixel coords)

"Lined hall" = **COLONNADE**: pillars in symmetric ROWS lining the hall, framing a central aisle. Intentional symmetry. This replaces the scattered-singles placement of #407.

Room geometry (ground-truth from §6): widened Room02 = 30×8 tiles @ 32px, walkable interior tiles (1,1)–(28,6) → px **x∈[32,928], y∈[32,224]**. Traversal axis **WEST entry → EAST exit**, both at tile-row 4 (**y≈144**). The aisle is the central horizontal band.

### 3.1 The colonnade pattern

**Two symmetric ROWS of pillars** running W→E, one north of the aisle, one south, mirrored across the aisle centerline (y≈144):

- **North pillar row** at **y≈64** (tile-row ~2), **South pillar row** at **y≈208** (tile-row ~6) — both off the central lane, framing it.
- **Pillars spaced evenly** along each row: **~4 pillars per row at x ≈ 200 / 420 / 640 / 860** (≈220px apart), **north and south pillars vertically ALIGNED** (a pillar at x=200 north has a twin at x=200 south). That vertical alignment IS the colonnade read — the eye sees paired columns marching down the hall. (8 pillars total. If 4-per-row reads too dense at game zoom, drop to 3-per-row at x≈240/520/800 — Stage C tuning.)
- **The aisle between the rows (y≈112–176) stays ZERO-decoration** — the clear processional walk + combat arena. Density at the edges, clear lane down the middle.

### 3.2 Brazier rhythm (the light, syncopated against the pillars)

- **Lit braziers on the NORTH wall** (y≈28, the wall band behind the north pillar row) at **x≈310 / 530 / 750** — placed *between* the pillar x-positions, NOT aligned with them. Brazier-between-pillars is the syncopation that makes the rhythm read as composed, not stamped. 3 lit braziers.
- **1 COLD/guttered brazier on the SOUTH wall** (y≈228) at x≈530, offset — the "this one went out" abandonment beat, and it makes the south wall read dimmer/cooler than the lit north wall (the warmth gradient from the decoration brief: lit north → neutral aisle → dim south).

### 3.3 Banner placement (symmetric, framing)

- **2 hanging banners on the NORTH wall**, between braziers, at **x≈420 / 640** (aligned over the central pillar pair) — banners hang *above the paired columns* so the vertical pillar+banner stack reads as a processional bay. Symmetric about the room centerline (x≈480).
- Banners are faded `#D7C68F` parchment + `#9A7A4E` trim — ritual signifiers, worn.

### 3.4 Settle-decoration (the "left behind" beats, in the corners + south band)

These keep the abandonment story without cluttering the colonnade. Off the aisle, off the pillar rows:

- **Rubble** (2–3): base of pillars + SW/SE corners — collapse gathering at the feet of the columns.
- **Parchment** (2): NW/SW corners where paper settles.
- **Moss** (2–3 props on top of the moss-creep floor tiles): south wall base + corners (damp).

**The shape to hand Drew:** a symmetric colonnade — paired columns marching W→E framing a clear worn aisle, braziers syncopated between the columns on the lit north wall, banners hung over the central bays, one cold brazier and heavier moss/rubble dimming the south wall, settle-decoration pooling at column-feet and corners. **Symmetry is the craft here** — #407 failed because the props were asymmetric and random; this is intentional and mirrored.

---

## 4. COLLISION PLAN — solid props block, room stays clearable, mobs still reach

Sponsor decision (1): **solid props get COLLISION (block player + mobs).** The navigability constraint is absolute: the room MUST stay traversable + clearable, and **mobs MUST still reach the player** around the obstacles — we do NOT wall off the lane.

### 4.1 Which props are solid (get collision) vs decoration (no collision)

| Prop | Solid? | Footprint (collision shape) | Why |
|---|---|---|---|
| **Pillar** (×8, the colonnade) | **SOLID** | ~24×24px circle/box at the pillar base (smaller than the sprite — collide on the *stone base*, not the visual cap overhang) | Columns are physical; you walk around them. The colonnade's whole point is physicality. |
| **Lit brazier** (×3, north wall) | **SOLID** | ~20×20px box at base | Iron fire-stand; you don't walk through it. On the wall band, so it eats little floor. |
| **Cold brazier** (×1, south wall) | **SOLID** | ~20×20px box at base | Same. |
| **Large rubble** (the 2–3 bigger piles) | **SOLID** | ~24×20px box | Sponsor named "large rubble" as solid — fallen stone you path around. |
| **Small rubble / parchment / moss / banner** | **decoration (no collision)** | — | Flat or wall-hung; flavor, not obstacle. Banners hang on the wall (no floor footprint). |

**Footprint discipline:** collision shapes are SMALLER than the sprite and centered on the prop's *base* (where it meets the floor), so the player can brush the visual edge without a sticky invisible wall. This is the standard "collide on the footprint, not the silhouette" rule.

### 4.2 Navigability constraint (the hard rule for Stage C)

- **The central aisle (y≈112–176) stays a clear lane** — pillars sit at y≈64 (north) and y≈208 (south), well clear of the y≈144 traversal row. The player and mobs always have an open W→E corridor.
- **Gaps between paired columns are ≥ 2 tiles (~64px) wide** — wider than the player + mob footprint at `char_scale=0.6`, so mobs path *between and around* columns to reach the player. The colonnade is permeable, not a wall.
- **Mobs must still reach + engage:** the 4 grunt-spawn tiles (read from the chunk-def, §6) stay clear of collision props, and the path from each spawn to the aisle stays open. A pillar must never box a spawn tile in. **Stage C paired test: spawn a mob, confirm it reaches the player across the colonnade (no nav dead-pocket).**
- **Room stays clearable:** no collision arrangement may trap the player or a mob in an un-exitable pocket. Verify the room is fully traversable entry→exit with all props placed.

**Collision is Drew's impl (Stage C)** — StaticBody2D + CollisionShape2D children on the solid props, footprint per §4.1. Mobs path via the existing nav; the constraint is "permeable colonnade, clear aisle, every spawn reaches the player."

---

## 5. PIXELLAB GEN SCOPE (orch run-sheet — exactly what to generate/upgrade)

**Quality is the goal, NOT a small gen count.** Sponsor directive (2026-06-03): budget is explicitly NOT a constraint (thousands of credits before ~June 17); he would rather spend credits than ship bad quality. So this scope recommends the gens that achieve **PREMIUM** craft, with **planned iteration (expect 2–3 regen passes per tile to nail quality)** — not the cheapest sufficient set. We are NOT minimizing gen count. Tools per `pixellab-pipeline.md` (orch-session only — sub-agents lack PixelLab). Doctrine-lock Strategy 3, judged in-context at game zoom per Stage B.

**Iteration discipline (apply to every tile gen below):** generate → doctrine-lock → mock-tile across a real room span at game zoom → judge against §2 craft levers → regen if it reads flat or stamps a repeat. **Budget 2–3 passes per tile set as the EXPECTED path, not a fallback.** A first-pass tile that reads "fine in isolation" but stamps a grid when tiled (the `TESTING_BAR.md` in-context failure) gets regenerated, not shipped. The floor + wall sets are the headline — spend the most iteration there.

### 5.1 TILES — the headline (UPGRADE, regen at premium craft, iterate hard)

- **Floor flagstone SET — UPGRADE `floor_sandstone.png` → 5–7 variants.** `create_topdown_tileset`. Was 1 flat tile; now a rich multi-variant crafted set (§2.2A) so a 30-tile-wide floor never reads a repeat. **The single most important surface — iterate 2–3 passes minimum** until the flagstones read as discrete polished cut stone with uneven wear, not brown fill.
- **Wall ashlar SET — UPGRADE `wall_cloister.png` → running-bond autotile + 3–4 block variants.** `create_topdown_tileset` (Wang/blob). Kills the vertical-joint wallpaper repeat that was the worst offender. **Iterate 2–3 passes** until the masonry reads as stacked worked stone with staggered joints + block-to-block weathering, never a stamped grid.
- **Floor accents — NEW: cracked-sunk flagstone (×2) + moss-creep flagstone (×1–2) + worn foot-path flagstone (×1).** `create_topdown_tileset`/`create_map_object`. Repeat-breakers + floor material story (the foot-path worn stones run down the aisle as a tonal-storytelling beat). Generate a richer accent pool, not the minimum.
- **Floor→wall TRANSITION / seam tile — NEW: ×1–2.** `create_topdown_tileset`. A proper floor-meets-wall seam row (`#5C4F38` deep + `#1A1210` shadow line) so the floor doesn't butt flat into the wall — a craft detail that elevates the whole room edge.
- **Wall niche accent — NEW: ×1–2 arched-niche block variants.** Demotes the old repeated alcove motif to a rare hand-placed accent. `create_map_object` or fold into wall set.

### 5.2 PROPS — craft-elevate the hero props; reuse the rest unless they read thin

- **Pillar — UPGRADE `pillar_arch.png` → premium regen (RECOMMEND, not optional).** The colonnade puts 8 pillars on screen as the hero prop — regen at higher craft (carved fluting, clear lit/shadow sides, worn bronze capital) so a mirrored row reads as a real colonnade, not 8 stamped copies. **Consider 1–2 silhouette variants** (e.g. a slightly-more-collapsed pillar) so the rows aren't identical copies. Iterate to premium. ~2–3 gens with iteration.
- **Large rubble — NEW 2nd silhouette (RECOMMEND).** A long fallen-beam / toppled-column shape vs the round pile, so the south band + column-feet rubble doesn't copy-paste. Now that rubble is a *solid collision* prop (§4) it reads more, so it earns the craft. ~1–2 gens.
- **Braziers (lit + cold), parchment, banner, moss — REUSE as-is by default, regen any that read thin in the new composition at soak.** These 7 doctrine-lock cleanly and the #407 failure was composition + tiles, not these sprites — but if the lit brazier or banner reads low-craft next to the upgraded tiles at game zoom, regen it rather than let it drag the room down. Hold these as iteration candidates, not locked-reuse.

### 5.3 Gen-scope summary (premium, iteration-planned)

- **TILES (headline): ~8–12 gens across the run** — floor set (5–7 variants, 2–3 passes), wall set (running-bond + 3–4 variants, 2–3 passes), floor accents (~4), transition seam (~1–2), niche (~1–2). **Budget 2–3 regen passes per set; this is where the credits go.**
- **PROPS: ~4–6 gens** — pillar premium regen + 1–2 variants, 2nd rubble silhouette, plus any of the reuse-7 that need a craft-lift at soak.
- **Total: ~12–18 gens with iteration headroom, and MORE if a surface still doesn't read premium.** Do NOT stop at "good enough" — the bar is crafted-at-game-zoom. Per `pixellab-pipeline.md` cost model each `create_topdown_tileset`/`create_map_object` is ~1 gen; with thousands of credits available before June 17, gen count is not a limiter. **If the floor or wall still reads flat/wallpaper after the planned passes, keep iterating — quality is the gate, not budget.**

---

## 6. CROSS-REFERENCES (every count/anchor/hex above traces here)

- `team/uma-ux/env-art-s1-direction.md` (`86ca3gvgb`) — the LOCKED Outer Cloister look: tonal anchor §1, `S1_ENV_DOCTRINE` palette §6.3, tile/wall ramp §3, the "grid of bordered boxes" warning §6.3 (the wallpaper failure this rework fixes), HTML5/HDR/Polygon2D constraints §4.1, PixelLab tool plan §6.
- `team/uma-ux/s1-decoration-density.md` (`86ca3yuwv`) — the superseded reuse-only brief; its colonnade *thinking* (decorated rails + clear aisle, brazier rhythm, warmth gradient) is recomposed here into intentional symmetry. Its keep-clear zones §2 + mob-spawn anchors carry forward.
- `team/uma-ux/palette.md` — S1 authoritative sandstone ramp (every tile hex traces here) + anti-list (PL-09 no pure-black, PL-10 no tier-violet env, PL-03 floor `#7A6A4F` eye-dropper).
- `team/uma-ux/visual-direction.md` — 32px tile / 480×270 canvas / nearest-neighbour / **VD-13 tiles get NO 1px outline** (critical: a per-tile outline is the wallpaper-grid failure).
- `.claude/docs/pixellab-pipeline.md` — `create_topdown_tileset` + canvas-size trap (confirm dims, plan crop+slice), doctrine-lock Strategy 3 (per-slot nearest-neighbor), `quantize` over-request, cost model, **orch-session-only execution** (sub-agents lack the tools).
- `.claude/docs/pixel-mcp-pipeline.md` — quantize/set_palette traps, `draw_pixels` broken (use `draw_rectangle` 1×1), `fill_area tolerance=0` global-replace trap, Windows forward-slash paths, S1 Grunt doctrine-lock worked example.
- `.claude/docs/html5-export.md` — HDR-clamp sub-1.0 every channel, Polygon2D→ColorRect rule (any door-glow wedge is ColorRect ember tint, NOT Polygon2D — PR #137 precedent), z-index (floor z=0, props z=+1), visual-verification gate (TileMap render path + any modulate is HTML5-gated).
- `team/TESTING_BAR.md` §"judge art in context" + Pre-soak Gate 4 — first-of-class art judged tiled IN-CONTEXT at game zoom + `char_scale=0.6`, never isolated swatches. The binding view is the tiled room, not a 4× contact sheet.
- Chunk geometry: `scenes/levels/chunks/s1_room02_wide_chunk.tscn` (the proof room — 30×8, existing prop placement, Stage-C impl seam) + `resources/level_chunks/s1_room02_wide.tres` (ports entry(0,4)/exit(29,4), 4 grunt spawns — keep-clear + mob-reach anchors derive HERE, read from the resource not memory).
- `assets/{tilesets,props}/s1_cloister/` + `_generation_map.md` — existing files to UPGRADE (same paths) + the PixelLab reverse-map to extend with the new gen IDs.

---

## 7. Doctrine palette (paste-board for Stage B — DO NOT deviate)

```
S1_ENV_DOCTRINE = [
  "#7A6A4F",  # floor base (warm sandstone)
  "#5C4F38",  # floor deep / crack / mortar-groove
  "#A89677",  # floor highlight (lit/worn stone, foot-path)
  "#4A3F2E",  # wall base (cloister stone)
  "#5C7044",  # moss accent
  "#9A7A4E",  # bronzed trim / pillar / lit block-edge
  "#D7C68F",  # parchment / banner
  "#FFB066",  # brazier flame core
  "#FF6A2A",  # brazier flame outer / ember (door-glow only on tiles)
  "#E04D14",  # ember mid
  "#2C261C",  # brazier base / iron-soot
  "#1A1210",  # deep shadow / mortar joint (NOT #000000)
]
```

---

## 8. Decision draft + Sponsor sign-off surface

**Decision draft (2026-06-03)** — for Priya's weekly `DECISIONS.md` batch (NOT direct-edited per Uma role rule):
> **S1 tile-quality upgrade + lined-hall rework directed** (`86ca44p4j`, supersedes reuse-only #407 rejected on feel). Outer Cloister look LOCKED; this is a craft upgrade within it. TILES (headline): floor → 5-variant crafted flagstone set + accents; wall → running-bond ashlar autotile + block variants + rare niche accent — breaks the wallpaper repeat (demote the repeated arched-alcove to a rare accent; stagger joints; never same tile twice in a run). COMPOSITION: symmetric COLONNADE — 8 pillars in 2 mirrored rows framing a clear central aisle, braziers syncopated between columns on the lit north wall, banners over central bays, cold brazier + heavier moss dimming the south wall, settle-decoration at column-feet/corners. COLLISION: pillars + braziers + large rubble are SOLID (footprint at base, smaller than sprite); aisle stays clear, gaps ≥2 tiles, every mob-spawn reaches the player (permeable colonnade, not a wall). GEN SCOPE (Sponsor: budget NOT a constraint — quality is the goal): ~12–18 PixelLab gens with planned 2–3 regen passes per tile set (floor 5–7 variants + wall running-bond autotile + accents + transition + niche; pillar premium regen + variants; 2nd rubble silhouette; reuse-7 as craft-lift candidates), and MORE if a surface still reads flat — iterate until premium at game zoom. PixelLab orch-run, doctrine-lock Strategy 3. Reversibility: tile swaps + collision nodes are revertible (restore prior PNGs + delete StaticBody children).

**Sponsor sign-off surface (what to veto/approve before any generation/build):**
1. **Tile-upgrade approach** (§2): premium crafted flagstone + ashlar, repeat broken via 5-floor-variant set + running-bond wall autotile + rare niche accent (demoting the alcove that was the worst offender). Right fix for "wallpaper, not architecture"?
2. **Colonnade** (§3): 8 pillars in 2 symmetric mirrored rows framing a clear aisle, braziers syncopated between columns, banners over central bays. Right "lined hall" read? 4-per-row or 3-per-row?
3. **Collision set** (§4): pillars + braziers + large rubble solid; aisle clear; permeable so mobs still reach. Right props to make solid?
4. **Gen scope** (§5): premium scope per your "spend credits for quality" directive — ~12–18 gens with 2–3 planned regen passes per tile set (rich floor/wall variant sets + accents + transition + niche; pillar premium regen; 2nd rubble), iterate until the floor/wall read crafted at game zoom, MORE if needed. Approve this premium/iterative scope?
