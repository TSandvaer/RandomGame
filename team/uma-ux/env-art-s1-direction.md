# S1 Environment-Art Direction Brief — Tilesets · Backgrounds · Props

**Owner:** Uma · **Phase:** M3 env-art workstream (S1 FIRST per Sponsor 2026-06-02) · **Ticket:** `86ca3gvgb`
**Sponsor:** visual taste-veto retained. **Drives:** orchestrator + Sponsor PixelLab generation; downstream Drew/Devon impl tickets.
**OOS:** S2 env-art (follow-up ticket); asset GENERATION (orch + Sponsor execute); impl/wiring (Drew/Devon); character/mob/boss art (separate pipeline).

This is a DESIGN-DOC. No game code. It tells (1) what the S1 world should LOOK like, (2) exactly which PixelLab tools generate it, and (3) precisely where the output lands in the existing room + procgen geometry.

---

## 0. The problem this solves (one paragraph)

Every S1 room renders as a flat `ColorRect` floor (`Color(0.36, 0.31, 0.24)`) ringed by four flat `ColorRect` wall sprites (`Color(0.18, 0.14, 0.11)`) — see `scenes/levels/chunks/s1_room01_chunk.tscn`. Functional geometry, zero texture, zero storytelling. The systems shipped; the *place* never did. This brief replaces those `ColorRect` primitives with a palette-locked tileset + a background layer + props, so that walking into an S1 room reads as **arriving somewhere**, not standing in a brown box.

---

## 1. TONAL ANCHOR (lead with this — everything ladders down from here)

> **Stratum 1 — Outer Cloister — reads as "a stone cloister settled into silence: the monks are gone, the candles are guttering, but the room hasn't noticed yet."**

This is the visual twin of the **S1 ambient anchor** (`s1-ambient.md`): "post-active, not deep-tunnel-alive." S2 (Cinder Vaults) is *pressure* — heat venting, rock under load. **S1 is the inverse: a place that USED to have ritual, now holding its breath.** Worn sandstone the monks polished smooth with their feet. Bronze door-trim gone green at the seams. A few braziers still lit because nobody put them out. Banners gone to parchment. The space should make the player's first footstep feel *important* — every prop is a thing someone left behind, not set-dressing.

**The descent payoff:** S1 is the player's introduction to the world's visual language. It must establish "warm sandstone + single warm light source" cleanly so that the S1→S2 descent (warm-yellow ~35° → warm-red ~5–15°, sandstone → burnt-earth) lands as a *temperature drop into pressure*. If S1 already looked dark/dangerous, the descent has nowhere to go. **S1 is the warmest, most-lit, most-legible stratum on purpose.**

**Anti-list (decoration beats that DON'T serve the anchor — cut them):**
- No active fire/lava/magma floor effects (that's S2/S6 — heat is the descent reward).
- No pristine/clean stone (the place is *abandoned*, not maintained — every surface is worn, cracked, or mossed).
- No pure black `#000000` (palette.md S1 anti-list — reserved S7-S8; breaks "warm cloister").
- No cyan/teal/violet environment accents (wrong stratum).

---

## 2. Sub-biome plan — three reads inside one warm-sandstone doctrine

S1 ships as ONE zone (`s1_z1_outer_cloister`, Rooms 01-08 + boss) per `Main.gd ROOM_INDEX_TO_ZONE_ID`. But a single floor texture across 8 rooms reads monotone. We get variety *without* a new palette by sub-bioming through **tile-set variants + prop density**, all inside the locked S1 sandstone ramp. Three sub-biomes, mapped to the narrative arc of the room sequence:

| Sub-biome | Rooms | Tonal read | What changes (palette stays locked) |
|---|---|---|---|
| **2a. Cloister Walk** (default) | 01-03 (intro/tutorial) | "you've arrived; it's quiet, it's safe-ish" | Clean-ish worn sandstone floor, sparse moss, lit braziers. Highest light, lowest threat-read. |
| **2b. Disused Cells** | 04-06 (mid) | "people lived here once; they're gone" | More cracks + recessed `#5C4F38` deep-tiles, heavier `#5C7044` moss creep, scattered parchment/rubble props, fewer lit braziers (some guttered to `#2C261C` cold iron). |
| **2c. Inner Sanctum approach** | 07-08 + boss | "something important is ahead" | Bronzed trim `#9A7A4E` denser (pillar arches), doorway ember-glow `#FF6A2A` @60% stronger, banners more present, vignette reads deepest (still S1 30%). The room *funnels* toward the boss. |

These are **prop-density + tile-frequency reskins of one tileset**, NOT three tilesets. Authoring leverage: one master S1 tileset; sub-biome differentiation is the autotile terrain-mix + prop placement, which Drew controls at the chunk-`.tscn` level. This is the cheapest path to "8 rooms that don't feel identical."

---

## 3. Tileset plan — what replaces the flat ColorRect backdrop

**Spec frame (from `visual-direction.md`):** 32×32 internal tiles, 480×270 logical canvas, nearest-neighbour, 1px dark outline on characters but **NOT on tiles** (VD-13). A room is a 15×8 tile grid (`LevelChunkDef.size_tiles = Vector2i(15, 8)`, `tile_size_px = 32`).

### 3.1 Floor tiles (replaces the `Color(0.36,0.31,0.24)` Floor ColorRect)

A **9-tile autotile (3×3 terrain) sandstone set** + scatter variants. Palette-locked to the S1 environment ramp:

| Tile role | Primary hex | Notes |
|---|---|---|
| Floor — base flagstone | `#7A6A4F` warm sandstone | The dominant tile. Worn, smooth. |
| Floor — deep / crack / recess | `#5C4F38` | Cracks between flagstones, recessed drainage tiles. Used heavier in sub-biome 2b. |
| Floor — lit edge / polished | `#A89677` highlight | Where the single warm key-light catches a raised stone lip. |
| Floor — moss-creep overlay | `#5C7044` olive moss | SPARSE in 2a, creeping in 2b. A scatter-tile, not a base. |

Author **4-6 base flagstone variants** (same hex family, different crack/wear patterns) so a 15×8 floor doesn't tile-repeat visibly. Plus 2 transition/edge autotile corners for the floor-meets-wall seam.

### 3.2 Wall tiles (replaces the four `Color(0.18,0.14,0.11)` wall ColorRect sprites)

Walls are a 32px perimeter band (north/south = 480×32, east/west = 32×256 — see chunk geometry). Replace with:

| Tile role | Primary hex | Notes |
|---|---|---|
| Wall — base cloister stone | `#4A3F2E` heavy stone | The wall body. Coursed-stone read (visible block joints). |
| Wall — moss accent | `#5C7044` | Sparse green at the wall base where damp collects. |
| Wall — bronzed trim / pillar | `#9A7A4E` | Door arches, pillar capitals. Sub-biome 2c uses this densely. |
| Wall — deep shadow / outline | `#1A1210` | The recessed mortar line + the floor-meets-wall shadow. NOT pure black (anti-list). |

Author: a **horizontal wall-run tile + a vertical wall-run tile + 2 corner pieces + 1 pillar/arch tile**. The arch tile is the boss-room door surround (sub-biome 2c).

### 3.3 Transition / edge / door tiles

- **Floor→wall seam:** a 1-tile transition row (`#5C4F38` deep + `#1A1210` shadow line) so the floor doesn't butt flat into the wall.
- **Door / port opening:** S1 chunks declare EAST/WEST `&"exit"` ports (procgen-pipeline.md). The door-opening tile is an **arch in `#9A7A4E` bronzed trim with `#FF6A2A` ember-glow @60% opacity** in the threshold — diegetically "the next room is lit; come through." This doubles as the procgen port-mating visual marker.

**Door-glow is the ONE place a tile carries the ember through-line.** Per `palette.md` "Doorway ember-glow `#FF6A2A` at 60% opacity, soft falloff." HDR-clamp note below applies.

---

## 4. Background-layer approach — HTML5/WebGL2-aware

S1 rooms are 480×270 (viewport-native) and the camera is bounds-clamped (Main.gd `S1_ROOM_BOUNDS`), so for current single-screen S1 rooms **there is no off-screen area for a parallax layer to scroll against** — the room IS the screen. Therefore:

**Decision: STATIC backdrop + baked vignette, NO parallax for S1.** Parallax is a procgen-wide-room concern (M3+ when S1 retrofits to multi-chunk scrolling floors); it is OUT of scope here and noted as forward-compat below.

The background layer is two parts:

1. **Floor-as-background.** The tileset floor (§3.1) IS the playfield background. There is nothing "behind" the floor in a top-down cloister — the floor is the ground plane. No separate sky/void layer.
2. **A subtle warm-radial darkening behind the floor** to sell "single warm key-light per scene" (`visual-direction.md` lighting model). This is the existing **Vignette CanvasLayer** (`scenes/ui/Vignette.tscn`, layer 5, S1 = 30% per `vignette-spec.md`) — already shipped, already HDR-clamp-safe (`#0A0606` warm-black, sub-1.0 channels). **No new background node needed; the vignette already does the "single warm light" framing.**

### 4.1 HTML5 / WebGL2 constraints (HARD rules — cite per primitive)

- **Tilesets render via Godot `TileMap` / `TileMapLayer` (textured `Sprite2D`-class draw path), NOT `Polygon2D`.** This is inherently safe — TileMap uses the textured-quad batcher, the same path that's renderer-consistent across `gl_compatibility`. The PR #137 Polygon2D invisibility risk class does NOT apply to TileMaps. (The risk class is for *vector* primitives; our tiles are raster PNGs.)
- **Any cone/sweep/telegraph overlay drawn on top of the floor uses ColorRect rotated-rect, NOT Polygon2D** (PR #137 precedent). No env-art surface here needs one, but flagged so Drew's impl doesn't reach for Polygon2D for a door-glow wedge — use a **ColorRect with the ember tint** for the door threshold glow, OR a textured glow tile baked into the door arch.
- **HDR-clamp: every tint sub-1.0 on every channel.** The door ember-glow `#FF6A2A` = `(1.0, 0.416, 0.165)` — R channel is exactly 1.0, which is the clamp ceiling, safe (it does not exceed 1.0). If Drew applies a `modulate` *brighten* on the glow tile, the modulate target must stay ≤ `(1.0, x, x)` — never `1.4×` (the PR #137 SWING_FLASH bug). Bake the glow into the tile art at final brightness instead of modulate-brightening at runtime.
- **No `z_index = -1` for the floor.** Per html5-export.md, negative z can sink below the room draw layer inconsistently. Floor TileMap at `z_index = 0`; props at `z_index = +1` where they must read above the floor; player above props. (Co-rule: shared-z tie-breaks differ between renderers — give props an explicit positive z, don't rely on child order.)
- **No Unicode glyphs in any tile/prop that routes to a Label.** N/A for raster tiles, but flagged for any future debug-overlay on the env-art surface.

---

## 5. Props / decoration beats — density + placement per room type

Props serve the anchor: **every prop is a thing someone left behind.** Density rises toward the boss (sub-biome arc). Props are `map_object` sprites placed as child `Sprite2D`/`Node2D` nodes in the chunk `.tscn` (NOT tiles — they sit on top of the floor TileMap).

| Prop | Hex anchor | Role / story beat | Density by sub-biome |
|---|---|---|---|
| **Wall brazier (lit)** | core `#FFB066` / outer `#FF6A2A` / base `#2C261C` | The single warm light source made literal. The thing nobody put out. | 2a: 2-3/room · 2b: 1-2 (some guttered) · 2c: 3-4 (funnel-lighting toward boss) |
| **Brazier (guttered/cold)** | `#2C261C` iron + soot, no flame | "this one went out" — abandonment beat | 2a: 0 · 2b: 1-2 · 2c: 0 |
| **Rubble / fallen stone** | `#5C4F38` deep + `#4A3F2E` wall | Collapse; the cloister decaying | 2a: sparse · 2b: moderate (blocks sightlines) · 2c: sparse (cleared path to boss) |
| **Scattered parchment / scroll** | `#D7C68F` parchment | The monks' records, left to rot | 2a: 1-2 · 2b: 3-4 (the cells where they worked) · 2c: 1 |
| **Hanging banner (worn)** | `#D7C68F` + `#9A7A4E` trim | Ritual signifier, faded | 2a: 1 · 2b: 0-1 · 2c: 2 (sanctum approach) |
| **Bronzed pillar / arch** | `#9A7A4E` trim + `#4A3F2E` body | Architectural weight | 2a: 0-2 · 2b: 2 · 2c: 4+ (colonnade funnel) |
| **Moss patch (floor)** | `#5C7044` | Damp, time, neglect | 2a: sparse · 2b: heavy · 2c: moderate |

**Placement rules (for Drew's chunk authoring):**
- Braziers go on walls (north/east/west bands), never mid-floor (they're the light source, and mid-floor props block movement).
- Rubble + moss can sit mid-floor in 2b to break sightlines and slow the player (pacing), but NEVER on the player spawn tile (`DEFAULT_PLAYER_SPAWN = (240, 200)`) or on a port-opening tile (blocks traversal).
- Parchment/scrolls cluster near walls + corners (where things settle), not center-room.
- **The boss-room door (sub-biome 2c) gets the densest brazier framing** — two braziers flanking the arch, ember-glow threshold. This is the "something important is ahead" beat made literal.

**Collision discipline:** rubble + pillars are visual-only by default (no collision) UNLESS Drew wants them as soft cover — that's an impl call, flagged not specified. Braziers/banners are pure decoration (no collision).

---

## 6. PixelLab generation plan (concrete enough to run per-asset)

Per `pixellab-pipeline.md`: PixelLab + pixel-mcp run in the **orchestrator main session ONLY** (sub-agents lack the tools). The orchestrator + Sponsor execute generation; this section is the run-sheet.

### 6.1 Tools

- **Floor + wall tilesets → `mcp__pixellab__create_topdown_tileset`** (the MCP server advertises "Top-down tilesets for game maps"). One call per terrain set: one for sandstone-floor autotile, one for cloister-wall set. If the tool produces a single bonded tileset image, request the 3×3 autotile (Wang/blob) layout.
- **Props → `mcp__pixellab__create_map_object`** (advertised "isometric tiles / map objects"). One call per prop in §5 (brazier-lit, brazier-cold, rubble, parchment, banner, pillar, moss-patch). Single-object generations, transparent background.
- **Lit brazier flame animation:** if `create_map_object` supports a state/anim variant, generate a 4-frame flame flicker (`#FFB066`→`#FF6A2A`) at 12fps per `visual-direction.md`. Otherwise ship a static brazier + a separate ember-flicker handled by Devon as a small CPUParticles2D (subject to the html5 visual-verification gate — flag to Drew/Devon, not author here).

### 6.2 Canvas / size discipline (pixellab-pipeline.md canvas-size trap)

- **Tiles:** target 32×32 internal. PixelLab canvas is always square; request the tileset at a size that downsamples cleanly to 32px tiles. Plan a **`crop_sprite` + per-tile slice** step — PixelLab pads its canvas, so confirm dimensions with `get_sprite_info` before slicing (never assume from the `size` param).
- **Props:** size to footprint — brazier ~24×40 (wall-mounted, taller than wide), rubble ~32×24, parchment ~16×16, pillar ~32×64, banner ~24×48. Generate at PixelLab's square canvas, then `crop_sprite` to footprint per the canvas-size trap.
- **PixelLab has NO palette-lock param** — the model picks colors. **All S1 doctrine compliance happens in pixel-mcp post-process.**

### 6.3 Doctrine-lock strategy (pixellab-pipeline.md §"Doctrine palette compliance")

These are **fresh generations → first doctrine-lock**, so **Strategy 3 (per-slot nearest-neighbor mapping)** is the validated winner. The S1 environment doctrine palette to lock against (from `palette.md` + the Grunt worked example in `pixel-mcp-pipeline.md`):

```
S1_ENV_DOCTRINE = [
  "#7A6A4F",  # floor base (warm sandstone)
  "#5C4F38",  # floor deep / crack
  "#A89677",  # floor highlight
  "#4A3F2E",  # wall base
  "#5C7044",  # moss accent
  "#9A7A4E",  # bronzed trim
  "#D7C68F",  # parchment
  "#FFB066",  # brazier flame core
  "#FF6A2A",  # brazier flame outer / ember
  "#E04D14",  # ember mid
  "#2C261C",  # brazier base / iron-soot
  "#1A1210",  # deep shadow / mortar line (NOT #000000)
]
```

Per the pipeline doc: over-request `quantize_palette target_colors` ~30-40% above the doctrine size (so ~16 for this 12-color palette) to absorb dupe slots. After quantize, run per-slot nearest-neighbor. **Character-beat override for env-art:** the brazier flame (`#FFB066`/`#FF6A2A`) is the only saturated accent — verify nearest-neighbor routes the brightest flame slot to `#FF6A2A` (not to a muddy `#9A7A4E` trim). Manual-override that slot if Euclidean misroutes it (the Grunt eye-glow override pattern).

**Tiles get NO 1px dark outline** (VD-13 — outlines are characters-only). If PixelLab adds a heavy outline to a tile, strip it in pixel-mcp or it will read as a grid of bordered boxes. Walls MAY carry the `#1A1210` mortar/joint line (that's coursed-stone detail, not a silhouette outline).

### 6.4 Output paths

```
assets/tilesets/s1_cloister/floor_sandstone.png      (sliced autotile)
assets/tilesets/s1_cloister/wall_cloister.png        (sliced autotile)
assets/props/s1_cloister/brazier_lit.png
assets/props/s1_cloister/brazier_cold.png
assets/props/s1_cloister/rubble_01.png
assets/props/s1_cloister/parchment_01.png
assets/props/s1_cloister/banner_worn.png
assets/props/s1_cloister/pillar_arch.png
assets/props/s1_cloister/moss_patch.png
assets/props/s1_cloister/_pixellab_raw/...           (raw, pre-doctrine-lock)
```

Mirror the character-pipeline `_pixellab_raw/` + reverse-map convention so a future auditor can trace a shipped tile back to its PixelLab generation.

---

## 7. Implementation hand-off — how tiles/props map onto existing geometry

The single render path for ALL S1 rooms is the chunk `.tscn` (e.g. `scenes/levels/chunks/s1_room01_chunk.tscn`). Rooms 02-08 load via `MultiMobRoom` + `LevelAssembler`, which instantiates the chunk geometry; Room01 loads its chunk directly. **There is exactly ONE place the flat ColorRects live, and it's the chunk scenes.** This is the impl seam.

### 7.1 Drew's tickets (game-side)

1. **Build the S1 TileSet resource** (`resources/tilesets/s1_cloister.tres`) from the §6.4 floor + wall PNGs — author the autotile/terrain peering rules so Drew can paint a room by dragging.
2. **Swap the chunk `.tscn` Floor ColorRect → a `TileMapLayer` floor.** Replace the `[node name="Floor" type="ColorRect"]` (`Color(0.36,0.31,0.24)`) with a `TileMapLayer` painted from the sandstone autotile across the 15×8 grid. **Collision is unchanged** — the four `WallNorth/South/East/West StaticBody2D` + `CollisionShape2D` nodes STAY; only the visual `Sprite` ColorRect children swap to wall-tile sprites (or a wall TileMapLayer band). The physics perimeter is decoupled from the visual.
3. **Swap the four wall `Sprite` ColorRects → wall tiles** (`#4A3F2E` cloister stone) on the perimeter band, with the `#1A1210` floor-meets-wall shadow seam.
4. **Place props per §5 density table** as child `Sprite2D` nodes in each chunk `.tscn`, at `z_index = +1`, respecting the placement rules (off spawn-tile, off port-tiles).
5. **Sub-biome the 8 rooms** per §2: rooms 01-03 use the 2a tile-mix + prop density, 04-06 use 2b, 07-08+boss use 2c. Same TileSet, different paint + prop placement per chunk `.tscn`.
6. **Door/port arch tile** at each EAST/WEST `&"exit"` port opening, with the ember-glow threshold (ColorRect ember tint OR baked glow tile — NOT Polygon2D). Pairs with the procgen-pipeline.md port-mating: the open seam at `position_tiles.y` gets the arch visual.

**This is HTML5-visual-gated work** (TileMap render path + any modulate on the door glow). Drew's Self-Test Report needs the screenshot evidence per html5-export.md; primitive-safety analysis is not a substitute.

### 7.2 Procgen forward-compat (the S2-pattern S1 will inherit)

The procgen `_render_assembled_floor` / `_instantiate_chunks` path (`Main.gd`) instantiates chunk `.tscn` by `scene_path`. **Because the env-art lives entirely inside the chunk `.tscn`, the procgen path gets the tilesets + props for free** — when W2 retrofits S1 to multi-chunk scrolling floors, each assembled chunk already carries its tiles + props. No `Main.gd` render change needed for env-art. (Parallax background for wide scrolling rooms is a separate future ticket — see §4.)

### 7.3 Devon's tickets (engine-side, if any)

- The brazier flame animation, IF shipped as CPUParticles2D rather than a baked anim tile, is Devon's (z_index=+1, html5 visual-gate, sub-1.0 ramp). Author-flag only; the default is a baked anim tile (§6.1) which is Drew's.

---

## 8. Sub-biome calls + decision drafts (my delegated authority)

I made these calls within direction-author authority. Sponsor taste-veto applies to all of §1, §2, §5.

- **No parallax for S1** (§4) — rooms are single-screen viewport-native; parallax is a procgen-wide-room future concern. Reversible: a parallax CanvasLayer is additive when S1 scrolling rooms land.
- **Three sub-biomes via tile-mix + prop-density, NOT three tilesets** (§2) — authoring economy; one master S1 TileSet.
- **Vignette is the "single warm light" background, no new node** (§4) — reuses shipped `Vignette.tscn`.

**Decision draft (2026-06-02)** — for Priya's weekly `DECISIONS.md` batch (NOT direct-edited per Uma role rule):
> **S1 environment-art direction locked.** Outer Cloister reads as "stone cloister settled into silence" (warmest/most-lit stratum, post-active not deep-tunnel-alive). Tileset = palette-locked sandstone autotile (floor) + cloister-stone (wall) replacing flat ColorRect chunk backdrops; three sub-biomes (Cloister Walk / Disused Cells / Sanctum approach) via tile-mix + prop density across Rooms 01-08; static backdrop + shipped vignette (no parallax for single-screen S1); props = braziers/rubble/parchment/banner/pillar/moss serving "things left behind." Generation via PixelLab `create_topdown_tileset` + `create_map_object`, doctrine-locked Strategy 3 in pixel-mcp. Impl seam = the chunk `.tscn` files (one render path); Drew swaps ColorRect→TileMapLayer, collision perimeter unchanged. Reversibility: env-art is additive over working geometry; revertible by restoring the ColorRect chunk nodes.

---

## 9. Cross-references

- `team/uma-ux/palette.md` — S1 authoritative ramp (every hex above traces here) + anti-list (PL-09 no pure-black, PL-10 no tier-violet env).
- `team/uma-ux/visual-direction.md` — 32px tile / 480×270 canvas / nearest-neighbour / VD-13 tiles-no-outline / lighting model.
- `team/uma-ux/s1-ambient.md` — the tonal-anchor twin ("cloister settled into silence"); audio + visual must agree.
- `team/uma-ux/vignette-spec.md` — S1 30% vignette = the "single warm light" background layer.
- `.claude/docs/pixellab-pipeline.md` — canvas-size trap, doctrine-lock Strategy 3, cost model, orch-session-only execution.
- `.claude/docs/pixel-mcp-pipeline.md` — quantize/set_palette traps, S1 Grunt doctrine-lock worked example (the env-doctrine palette §6.3 extends it).
- `.claude/docs/html5-export.md` — HDR-clamp sub-1.0, Polygon2D→ColorRect rule, z-index, visual-verification gate.
- `.claude/docs/procgen-pipeline.md` — chunk `scene_path` instantiation; env-art-in-chunk-`.tscn` means procgen inherits tiles for free.
- `scenes/levels/chunks/s1_room01_chunk.tscn` — the flat-ColorRect placeholder this brief replaces (the impl seam).
- `scenes/Main.gd` `_load_room_at_index` / `_render_assembled_floor` / `_instantiate_chunks` — render path (no env-art change needed at this layer).
- Memory: `m3-art-pass-collaboration-shape` — orch + Sponsor execute generation; Uma + orch provide direction + per-asset prompts.

## 10. Sponsor taste-review surface (what to veto/approve)

1. **Tonal anchor** (§1): is "cloister settled into silence — warmest/most-lit stratum" the right S1 read, or should S1 already feel more dangerous?
2. **Palette feel:** warm sandstone `#7A6A4F` floor + `#4A3F2E` cloister-stone walls + lit-brazier ember through-line. Approve the ramp before generation burns PixelLab credits.
3. **Three sub-biomes** (§2): does "Cloister Walk → Disused Cells → Sanctum approach" across Rooms 01-08 read as progression, or is one S1 look enough?
4. **Prop density** (§5): braziers + rubble + parchment + banners + pillars + moss. Too much / too little / wrong objects?
5. **No-parallax call** (§4): static backdrop + vignette for single-screen S1 — acceptable, or does S1 want depth now?
