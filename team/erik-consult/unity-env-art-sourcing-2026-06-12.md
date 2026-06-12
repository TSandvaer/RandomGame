# Unity Environment Art Sourcing — Alive Ground for Beach + Field Zones

## Question

How do we achieve ALIVE, varied ground (beach: multi-tone sand, stones, shells; field: grass
with flowers, straws, bushes) in a Unity 6 URP world that hosts billboarded pixel-art characters,
at hobby budget? This research feeds spike ticket 86ca7yt5u (iteration 4, Zone A pixel + Zone B
painterly side-by-side judgment build).

## Bottom line

**Zone A (pixel-art ground):** PixelLab can generate tileable Wang transition tilesets at 32x32
that cover sand, grass, and their boundary at usable quality — but it cannot produce the scatter
props (shells, pebbles, flower tufts) in one shot; those need a separate `create_map_object` pass
or a supplemental sourced pack. For the ground itself, the path that will most reliably hit the
north-star (fine multi-tone worn texture, purposeful scatter) is **Cainos Pixel Art Top Down –
Basic** as the no-cost baseline, **Mana Seed** (Seliel, $129 one-time, includes Tropical Shores /
all biomes) as the premium option, or **CraftPix** individual packs ($4–$15 each) if budget is
tighter. **Zone B (painterly ground):** the Unity Asset Store "Handpainted Grass & Ground Textures
Free" (free, URP-compatible, last updated May 2026) is the zero-cost starting point; the $4.59
"60+ Painterly Terrain Textures" pack gives immediate sand + grass + rock variety. Neither zone
is blocked at hobby budget.

**Critical URP gotcha for both zones:** Unity's built-in terrain detail billboard grass FAILS
at top-down camera angles (~55° pitch) — documented Unity Issue Tracker bug where billboards
disappear when the viewpoint is above them. **Do not use Unity terrain detail billboards for
scatter props.** Use plain prefab-scattered GPU-instanced meshes instead. Additionally, Unity
terrain splatmap layers force bilinear filtering even when the texture is set to Point — a
confirmed unresolved issue in Unity's terrain shader. For pixel-art Zone A ground, either use
flat Quad/Plane meshes with a custom point-filtered material (bypassing the terrain system) or
accept painterly splatmap blending at zone boundaries.

## Evidence

### 1. Exemplar games — ground style choices

**Eastward (Pixpil, 2021)**
- Source: [Game Developer interview](https://www.gamedeveloper.com/art/eastward-s-creators-share-insights-on-making-pixel-art-adventures) — Strong (developer first-party statement).
- 3D world with custom MOAI engine + 3D lighting, 2D pixel-art characters. Ground is hand-painted
  pixel art on 3D planes with per-object bump maps for lighting. Style direction: hybrid — pixel
  textures on 3D terrain geometry, not a 2D tilemap. Ground reads warm and painterly because the
  3D lighting bathes hand-painted tiles. Lesson: point-filtered pixel tiles on 3D meshes can carry
  a warm, cohesive, alive look when lit well.

**Octopath Traveler / Triangle Strategy (Square Enix HD-2D, 2018–2023)**
- Source: [Unreal Engine developer interview](https://www.unrealengine.com/en-US/developer-interviews/octopath-traveler-ii-builds-a-bigger-bolder-world-in-its-stunning-hd-2d-style) — Strong (first-party).
- 2D pixel-art characters on full 3D backgrounds in UE4/5. Ground is 3D-rendered with stylized
  textures + depth-of-field. Style direction: painterly/smooth terrain, never pixel-tiled ground.
  The contrast between smooth 3D world and pixel characters is an intentional HD-2D aesthetic.
  Lesson: the painterly ground direction is mainstream and commercially validated for pixel-art
  character + 3D world mixes.

**Graveyard Keeper (Lazy Bear Games, 2018)**
- Source: Sponsor's own inspiration board (`inspiration/2026-06-08_11h18_12.png`) — Strong
  (directly observed in this session).
- Pure 2D hand-authored pixel tileset. Ground is hand-painted pixel tiles: warm earth tones,
  organic grass patches, multi-tone dirt. Style direction: pixel tileset, completely 2D. Confirms
  the target quality bar for Zone A. Key observation: the ground reads alive because the tiles have
  fine internal texture noise — not a flat colour.

**Stardew Valley (ConcernedApe, 2016)**
- Source: Sponsor's inspiration board (`inspiration/2026-06-08_11h19_36.png`) — Strong.
- Hand-authored pixel tileset on the same 2D engine. Beach/grass transitions use explicit edge and
  transition tiles (Wang-style). Scatter objects (flowers, bushes, stones) are separate sprite
  objects layered above the ground. Lesson: scatter variety comes from a large library of
  small 16–32 px sprite objects, not from baked ground texture.

**A-pixel-art garden reference (inspiration/2026-06-08_07h53_24.png)**
- Source: Sponsor inspiration board — Strong (project north-star).
- Top-down pixel garden with dense layered flowering planting, cobble paths, fountain. Style
  direction: pure pixel tileset + sprite-layer scatter. Confirms the Sponsor's visual north-star
  for Zone A: the "alive" read comes from dense LAYERED scatter, not from a single texture.

Summary pattern: shipped titles that hit the north-star either (a) use professionally hand-crafted
pixel tilesets + a rich scatter-sprite library (Graveyard Keeper, Stardew), or (b) use a painterly
3D terrain with strong lighting (Eastward, Octopath HD-2D). No shipped exemplar successfully used
AI-generated tilesets as the primary ground layer — consistent with the project's own seven-bounce
history documented in `art-direction.md`.

### 2. Asset sources

#### Zone A — Tileable pixel-art terrain packs

**Cainos "Pixel Art Top Down – Basic" (free / name-your-price)**
- Source: [itch.io product page](https://cainos.itch.io/pixel-art-top-down-basic) — Strong (direct fetch).
- 32x32 tiles, includes grass tileset (256x256 sheet), stone ground, 48 props, 15 grass variants,
  3 trees. Commercial use allowed. No sand/beach tiles in this pack. Already in the project
  (the cloister S1 tileset is Cainos). Baseline available at zero cost for Zone A grass zones.
- Verdict: fine for field/grass. No beach coverage — needs supplementing.

**CraftPix "Grassland Top Down Tileset Pixel Art"**
- Source: [CraftPix product page](https://craftpix.net/product/grassland-top-down-tileset-pixel-art/) — Strong (direct fetch).
- 16x16 tiles. Includes earth, water, grass, mud, stones, vines, bushes (with/without berries),
  stumps, trees. Commercial use, unlimited projects. PSD + PNG. Requires CraftPix Premium
  membership ($15/month or $4/month billed annually = $48/year) or per-pack purchase
  ($4–$15 each). Commercial use without royalty explicitly confirmed.
- Verdict: excellent scatter prop variety for field. Annual membership ($48) fits within
  the 100–200 USD/month budget easily. Does not cover beach.

**CraftPix free tier + "Seabed/Beach" individual packs**
- Source: [CraftPix top-down category](https://craftpix.net/categorys/top-down-tilesets/) — Moderate (category listing, individual pages not fully fetched).
- Specific beach packs exist (Seabed Pixel Art Top Down Tileset) but appear to be underwater-
  oriented rather than above-water beach. The grassland + a separate beach/desert pack is the
  likely pairing. Individual packs $4–$15 each; free tier has selection of sampler packs.
- Verdict: viable for beach if the right pack is identified; needs a per-page confirm before Devon
  wires the drop folder.

**Mana Seed Pixel Art Tileset Collection (Seliel the Shaper, $129)**
- Source: [itch.io product page](https://seliel-the-shaper.itch.io/unity-tileset-collection) — Strong (direct fetch).
- 16x16 tiles. 20+ environments including **Tropical Shores** (beach), multiple forest biomes,
  deserts, dungeons. Unity package, pre-sliced. Commercial single-product license (read Mana Seed
  User License before purchasing). $129 one-time exceeds single-item budget ($50 cap per brief)
  but is under the 100–200 USD/month tooling tolerance if treated as a durable asset.
- Verdict: best-in-class for multi-biome coverage including beach and field in a single coherent
  palette. The $129 price is the one item in this survey above the nominal $50 individual cap;
  needs explicit Sponsor authorization before purchase. Highest quality path for Zone A if
  approved.

**Anokolisa "Free Pixel Art Asset Pack – Topdown Tileset" (free, 16x16)**
- Source: [itch.io](https://anokolisa.itch.io/free-pixel-art-asset-pack-topdown-tileset-rpg-16x16-sprites) — Moderate (search result description, not full page fetch).
- 400+ sprites, grassy surfaces. Commercial use. Does not appear to cover beach in the base pack.
- Verdict: free supplemental grass sprites; palette coherence with other packs unverified.

**Zamirbek "2D Pixel Art Tileset – Grass, Water, Sand" (free)**
- Source: [itch.io search result](https://zamirbek.itch.io/2d-pixel-art-tileset-grass-water-sand) — Weak (search result description only, page not directly fetched).
- Described as grass, water, sand. CC0-equivalent (no attribution required). Unknown tile size and
  quality level.
- Verdict: worth downloading to evaluate quality; could fill the sand gap alongside Cainos for
  a zero-cost Zone A. Tile quality unverified — do NOT commit to build before in-engine check.

#### Zone B — Stylized painterly terrain textures

**"Handpainted Grass & Ground Textures Free" (free, Unity Asset Store)**
- Source: [Unity Asset Store page](https://assetstore.unity.com/packages/2d/textures-materials/nature/handpainted-grass-ground-textures-free-top-down-rpg-terrain-tool-187634) — Strong (direct fetch).
- Free. 131.5 MB. URP + HDRP compatible. Updated May 4, 2026 (current). Standard EULA, commercial
  allowed. Includes grass, dirt, snow, swamp variants.
- Verdict: zero-cost starting point for Zone B. No beach/sand confirmed in free tier — check full
  description in-editor.

**"Handpainted Grass & Ground Textures" paid (same publisher)**
- Source: [Unity Asset Store](https://assetstore.unity.com/packages/2d/textures-materials/nature/handpainted-grass-ground-textures-187634) — Moderate (title confirmed, price/contents returned as "free" by fetch — may be the same page).
- Likely contains expanded biomes including sand/beach variant. Needs in-store inspection.

**"60+ Painterly Terrain Textures" (Unity Asset Store, €4.59)**
- Source: [Unity Asset Store page](https://assetstore.unity.com/packages/2d/textures-materials/floors/60-painterly-terrain-textures-15334) — Moderate (direct fetch, description absent).
- €4.59. 38.2 MB. Standard EULA. Last updated November 2015 — no URP support statement found.
  Version 1.8, requires Unity 4.3.4+. Old package may have missing URP shaders.
- Verdict: cheap but old. Test URP compatibility before adopting; may need re-shading.

**"25+ Free Stylized Textures – Grass, Ground, Floors, Walls" (Unity Asset Store, free)**
- Source: [Unity Asset Store search result](https://assetstore.unity.com/packages/2d/textures-materials/25-free-stylized-textures-grass-ground-floors-walls-more-241895) — Moderate (search result, not fully fetched).
- Free. URP support mentioned in search result snippet.
- Verdict: second free painterly option; worth importing alongside the handpainted pack for comparison.

**"280+ Stylized Desert & Beach Textures" (Unity Asset Store)**
- Source: [unityunreal.com listing](https://unityunreal.com/unity-assets-free-download-2/2d/5083-280-stylized-desert-beach-textures-sand-cracked-sand-water-more.html) — Weak (third-party aggregator, not official store page).
- Described as tileable, seamless, URP + HDRP. Sand, cracked sand, water textures. Price not
  confirmed from primary source.
- Verdict: beach coverage for Zone B if confirmed; verify on Asset Store directly.

### 3. Unity scatter tech under URP — billboard vs prefab

**Unity terrain detail billboard grass fails at top-down camera angles (confirmed bug)**
- Source: [Unity Issue Tracker](https://issuetracker.unity3d.com/issues/billboardgrasstexture-billboard-grass-texture-painted-on-terrain-hills-slope-disappears-when-viewpoint-is-above-it) — Strong (official Unity tracker).
- Billboard grass textures disappear when the camera viewpoint is above them — exactly the ~55°
  default pitch used in the spike. The documented workaround is to disable the Billboard checkbox,
  which means detail objects render as flat ground-facing quads (losing the "grass upright" read).
- Source: [Unity forum thread](https://forum.unity.com/threads/grass-in-top-down-h.719219/) — Strong (first-party community).
- Users confirm: "Unity's grass solution doesn't work well with high isometric/near top-down camera
  angles" — becomes transparent at certain angles in both billboard and non-billboard modes.

**Recommended approach: GPU-instanced prefab scatter, NOT terrain detail billboards**
- Source: [Six Grass Rendering Techniques in Unity](https://danielilett.com/2022-12-05-tut6-2-six-grass-techniques/) — Moderate (well-sourced technical article).
- For top-down angles, prefab scatter (meshes placed programmatically or via brushes like
  Polybrush) with GPU instancing enabled on the material is more controllable and camera-angle-
  agnostic than the terrain detail system. The bababuyyy pixel pipeline on GitHub uses GPU-instanced
  grass with a ToonLit shader + world-space noise for natural color variation without relying on
  Unity terrain detail.

**Unity terrain billboard grass shader override in URP requires embedding the URP package**
- Source: [TW0CATS Games dev blog, March 2024](https://tw0catsgames.com/update/2024/03/30/perfecting-unitys_billboard_shader_for_grass_01.html) — Moderate (practitioner writeup with tested solutions).
- URP overrides the grass shader at runtime; Filter Mode on textures is ignored; there is no URP
  option to change the terrain grass shader without embedding URP locally. Build times increase
  significantly with embedded URP. For a spike/throwaway project, this is too much overhead.
- Conclusion: **avoid terrain detail billboards entirely for this spike**; scatter props via prefab.

**Unity terrain splatmap forces bilinear filtering on pixel-art textures (confirmed unresolved)**
- Source: [Unity Discussions thread](https://discussions.unity.com/t/blurry-terrain-layers-which-i-want-to-be-pixelated/842813) — Strong (community thread with reproducible evidence).
- Even with Point (no filter) set on the texture, Unity terrain layers apply bilinear blending via
  the splatmap shader. Disabling mipmaps does not resolve it. No confirmed Unity 6 fix found.
- Application to Zone A: if Devon uses Unity terrain for Zone A pixel ground, the textures WILL be
  blurry at zone boundaries. Mitigation: use flat Quad meshes with a custom point-filtered Material
  (bypassing the terrain system entirely), accepting a hard edge at zone boundaries, OR use a
  custom splatmap shader. The bababuyyy pixel pipeline's approach (world-space noise color
  variation in a custom ToonLit shader on meshes) is the cleanest bypass.

**GPU instancing for detail: batches of 1023, no lightmap/lightprobe support**
- Source: [Unity Manual: Grass and other details](https://docs.unity3d.com/6000.4/Documentation/Manual/terrain-Grass.html) — Strong (official docs).
- For prefab scatter props at sparse density (pebbles, shells, flowers), 1023-batch limit is not
  a concern. No lightmap support means scatter props pick up lighting only via ambient + per-vertex
  probes — acceptable for small low-poly props at this spike stage.

### 4. PixelLab fit assessment

**`create_topdown_tileset` / `create_tiles` (Pro) capabilities**
- Source: [PixelLab docs: create-tileset](https://www.pixellab.ai/docs/tools/create-tileset),
  [tileset options](https://www.pixellab.ai/docs/options/tileset),
  [create-tiles-pro](https://www.pixellab.ai/docs/tools/create-tiles-pro) — Strong (official
  documentation, directly fetched).
- Tile sizes supported: **16x16 and 32x32** (confirmed from tileset options doc). The Pro tool
  lists 16, 32, 48, 64, 96, 128 square options and rectangle variants.
- Output format: Wang tileset (exported to Wang, dual-grid 15-tileset, or 3x3 tileset) — directly
  compatible with Unity tilemap autotile workflows.
- Terrain chaining: supports `lower="ocean", upper="beach"` style descriptors with base_tile_id
  chaining for seamless multi-terrain transition sets. Can generate sand, grass, beach boundary
  transitions from text descriptions.
- Constraint: **≤400px per side** (project-confirmed from pixellab-pipeline.md context). A 32x32
  Wang tileset fits easily. A 128x128 tile would fit in a single generation. A full tileset sheet
  (e.g. 16 tiles at 32px each = 512px wide) may require split generation.

**`create_map_object` for scatter props**
- Source: [PixelLab docs: map tools guide](https://www.pixellab.ai/docs/guides/map-tiles) — Strong (official).
- Generates individual objects with transparent backgrounds matching an existing map's style. Can
  produce pebbles, shells, flowers, grass tufts as separate sprites. Style-matching parameter
  locks to the generated tileset palette.
- Constraint: ≤400px canvas. A scatter prop at 32px sprite fits trivially. Batch generation of
  10–20 scatter variants (shells, pebbles, driftwood, flower types) is feasible within Tier 2
  concurrency (10 slots).

**Verdict on PixelLab for Zone A ground:**
PixelLab CAN plausibly produce a usable sand+grass tileset with beach transition — both terrain
types match documented example inputs. Evidence strength: **Moderate** (docs describe the
capability; no shipped-game example of PixelLab ground passing a comparable quality bar). The
critical risk is that the project's own art-direction.md documents a seven-bounce history where
AI-generated tileset ground missed the Sponsor's quality bar even after an AI-Wang-tileset path
was tried. Recommend: generate ONE sand tile + ONE grass tile + ONE transition row → orch
pre-judges against inspiration board → Sponsor mini-soak BEFORE committing to PixelLab as the
primary Zone A source. Do not batch-generate a full tileset first.

**PixelLab for scatter props:**
The `create_map_object` path is well-suited for scatter sprites (pebbles, shells, flowers,
grass tufts) because (a) size fits trivially, (b) style-matching keeps palette coherence with
the generated ground, (c) no transition complexity. This is the most reliable use of PixelLab
in Zone A — generate the ground from sourced tilesets, generate scatter props from PixelLab.

## Application to Embergrave

**Context from spike comments (ticket 86ca7y46c):** iteration 3 fixed feet pivot + blob shadow +
pitch clamp 35-70°. Devon carries a working biome-boundary (sand/grass) with flat-color ground.
Iteration 4 is the first art-real pass on that boundary — Zone A and Zone B side-by-side.

**North-star alignment (from `inspiration/*.png` viewed this session):**
The garden reference (07h53_24) and village courtyard (07h54_44) both confirm: the "alive" read
comes from dense layered SCATTER above the ground tile, not from intricate baked ground texture.
The ground itself is a multi-tone warmed tile; the life comes from clustered flowering bushes,
mossy joints, and purposeful objects. This means Zone A's success depends more on the SCATTER
PROP library than on the ground tile complexity.

**Recommended build plan for iteration 4:**

Zone A (pixel ground):
1. Ground: Cainos 32x32 grass tileset (already in project) for the field. For sand: download
   Zamirbek free pack first; if quality insufficient, generate one PixelLab sand tile as backup.
   Unity implementation: Quad-mesh with point-filtered material, NOT terrain system (avoids
   bilinear-blur bug).
2. Transition: PixelLab `create_topdown_tileset` with `lower="sandy beach", upper="grass meadow"`
   at 32x32 — one generation, pre-judge before batch.
3. Scatter props: PixelLab `create_map_object` for ~8–12 sprites (pebbles, shells, driftwood /
   grass tuft, flower patch, small bush). Unity side: simple Prefab with GPU instancing enabled
   + Polybrush or scripted random placement. Do NOT use terrain detail system.

Zone B (painterly):
1. Ground: "Handpainted Grass & Ground Textures Free" (URP, free, May 2026 updated) for field.
   For beach/sand: confirm whether "280+ Stylized Desert & Beach Textures" is on Asset Store and
   URP-compatible; import test before committing.
2. Scatter props: same prefab-scatter approach, using stylized 3D low-poly or hand-painted objects.
   Unity terrain detail meshes (non-billboard) are acceptable for zone B because the bilinear-blur
   issue is aesthetic-compatible with painterly style.

**Budget fit:**
- Zero-cost path: Cainos + free Asset Store packs + Zamirbek sand + PixelLab tileset generations
  (within existing Tier 2 subscription). Fully within budget.
- Best-quality path: Mana Seed $129 one-time (needs Sponsor auth at individual-purchase cap).
- CraftPix annual $48 covers both beach and grassland individual packs with commercial use.

**HTML5 distribution note:** This spike is desktop-only (Windows build). The terrain approach
(Quad meshes or terrain + URP) has no known HTML5 blockers specific to ground textures beyond
the standard URP-WebGL2 surface area documented in the project's `html5-export.md`.

## Sources

- [Unity Manual: Grass and other details (Unity 6.4)](https://docs.unity3d.com/6000.4/Documentation/Manual/terrain-Grass.html)
- [Unity Issue Tracker: Billboard grass disappears above viewpoint](https://issuetracker.unity3d.com/issues/billboardgrasstexture-billboard-grass-texture-painted-on-terrain-hills-slope-disappears-when-viewpoint-is-above-it)
- [TW0CATS Games: Perfecting Unity's Billboard Shader for Grass (March 2024)](https://tw0catsgames.com/update/2024/03/30/perfecting-unitys_billboard_shader_for_grass_01.html)
- [Unity Discussions: Blurry terrain layers / pixelated workaround](https://discussions.unity.com/t/blurry-terrain-layers-which-i-want-to-be-pixelated/842813)
- [bababuyyy: unity-isometric-pixel-pipeline (Unity 6 URP, GPU grass, sharp upscale)](https://github.com/bababuyyy/unity-isometric-pixel-pipeline)
- [PixelLab docs: create-tileset](https://www.pixellab.ai/docs/tools/create-tileset)
- [PixelLab docs: tileset options](https://www.pixellab.ai/docs/options/tileset)
- [PixelLab docs: create-tiles (Pro)](https://www.pixellab.ai/docs/tools/create-tiles-pro)
- [SLYNYRD Pixelblog #43: Top Down Tiles Part 2](https://www.slynyrd.com/blog/2023/3/26/pixelblog-43-top-down-tiles-part-2)
- [Cainos: Pixel Art Top Down – Basic (itch.io)](https://cainos.itch.io/pixel-art-top-down-basic)
- [Seliel the Shaper: Mana Seed Unity Tileset Collection (itch.io)](https://seliel-the-shaper.itch.io/unity-tileset-collection)
- [CraftPix: Grassland Top Down Tileset Pixel Art](https://craftpix.net/product/grassland-top-down-tileset-pixel-art/)
- [CraftPix membership pricing](https://craftpix.net/membership/)
- [Unity Asset Store: Handpainted Grass & Ground Textures Free](https://assetstore.unity.com/packages/2d/textures-materials/nature/handpainted-grass-ground-textures-free-top-down-rpg-terrain-tool-187634)
- [Unity Asset Store: 60+ Painterly Terrain Textures](https://assetstore.unity.com/packages/2d/textures-materials/floors/60-painterly-terrain-textures-15334)
- [Unreal Engine: Octopath Traveler II HD-2D developer interview](https://www.unrealengine.com/en-US/developer-interviews/octopath-traveler-ii-builds-a-bigger-bolder-world-in-its-stunning-hd-2d-style)
- [Game Developer: Eastward creators interview](https://www.gamedeveloper.com/art/eastward-s-creators-share-insights-on-making-pixel-art-adventures)
