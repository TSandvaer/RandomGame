# Low-Poly Smooth-Shaded Style — Asset Sourcing, Technique Inventory, and Character-Cohesion Assessment

## Question

Sponsor mid-soak signal on the Unity 6 URP proof-slice (ticket 86ca7y46c): "I think I wanna go
with a 'Low-Poly (with Smooth Shading)' style." Devon is building Zone C (low-poly smooth-shaded)
+ Zone D (same + lighting/fog/post quality pass) alongside existing Zone A (pixel billboards) and
Zone B (painterly textures). This research answers three sub-questions:

1. CC0/free low-poly nature asset packs usable in Unity 6 URP for a beach-to-field vignette.
2. The technique inventory that produces the Sponsor's named style — "low-poly with smooth shading"
   — including what distinguishes it from classic flat/faceted low-poly.
3. Pixel-art billboard characters on a low-poly 3D world: cohesion evidence, known risks, and the
   character-route implications if Sponsor later goes full low-poly.

---

## Bottom line

**Asset sourcing:** Kenney Nature Kit (CC0, 330 models, FBX/GLB, no URP setup included — raw
meshes) and Quaternius Stylized Nature MegaKit (CC0, 116 models including 40 trees + 27 rocks +
35 plants, FBX/OBJ/glTF, 60-70% free in Standard tier, URP implementation confirmed for Unity
2022.3.4+) are the two zero-cost standouts. Both cover trees, rocks, and foliage adequate for a
beach-to-field vignette; water-adjacent props exist in Kenney but sand/beach-specific geometry
is thin in both packs.

**Technique:** "Low-poly with smooth shading" is a specific style distinct from classic
flat/faceted low-poly: geometry is LOW polygon count but vertex normals are averaged (shared
across faces), producing smooth lighting gradients over big angular facets rather than per-face
flat color. In URP this is achieved with standard Lit or a cel/toon shader (e.g. Flat Kit,
~€18–37), one directional light, an ambient gradient sky, and optional fog/post-volume. The
Sponsor's phrase "smooth shading" is the technical correct term — the look lands by default on
any low-poly mesh imported without "Normals: Import" set to "Calculate (Flat)".

**Character cohesion:** Mixing 2D billboard pixel-art characters with a low-poly 3D world is a
validated, commercially shipped technique (Songs of Conquest, HD-2D series). The primary cohesion
risks are palette mismatch and the "floating" read when the character's palette doesn't share
hue-family with the world. Mitigations: grounding blob shadow (already in Devon's slice at iter-3),
shared warm palette, and optionally a thin outline on the sprite. This is a lower-risk combination
than pixel-art + painterly (Zone B) because low-poly geometry has flat-region color fields that
are visually "closer" to a pixel-art ramp than a painterly texture.

---

## Evidence

### 1. CC0/Free Low-Poly Nature Asset Packs

**Kenney Nature Kit**
- Source: [Kenney Nature Kit](https://kenney.nl/assets/nature-kit), kenney.nl, CC0 license,
  accessed 2026-06-12. **Strength: Strong (official product page, license confirmed).**
- 330 models total. Tag categories: tree, rock, foliage, terrain elements, waterfalls, camping
  equipment, plants. CC0 — commercial use, no attribution. Available as FBX and GLB
  (GLB confirmed via [convenience GLB repack](https://eclair-assets.itch.io/nature-kit-glb-pack-329-free-cc0-3d-models)).
  URP support: raw meshes only — no pre-configured URP materials. Devon assigns Unity URP
  materials at import (Standard URP/Lit, or Flat Kit shader). No URP-specific setup required
  for basic Lit rendering.
- Water-adjacent coverage: waterfall terrain elements listed. No dedicated beach/sand terrain.
- Verdict: **best zero-cost first pass for trees + rocks + general props**. Fill the sand gap
  with a PixelLab-generated sand ground tile or supplement with Quaternius.

**Quaternius Stylized Nature MegaKit (Standard + Pro tiers — free)**
- Source: [Quaternius product page](https://quaternius.com/packs/stylizednaturemegakit.html),
  Quaternius, accessed 2026-06-12 — CC0, commercial use confirmed. **Strength: Strong (official
  page, fetched directly).**
- 116 unique models: 40 tree models, 35 plants + flowers, 27 rocks + additional grass/bushes.
  Formats: FBX, OBJ, glTF. Standard tier (free) covers 60-70% of the pack; Pro tier adds
  remaining 30-40% — both are free downloads from the product page.
- Unity URP implementation: confirmed tested on Unity 2022.3.4 LTS; Unity 6 is above that floor.
  Custom shaders and engine-implemented versions available in the paid Source tier (Patreon,
  $10-50/month for claim keys). For free tiers, Devon applies URP Lit materials at import.
- Note: the Stylized Ghibli-ish aesthetic of this pack (soft bright greens, white trunks) may
  not match the project's "dark sinister" direction (memory: `iso-style-dark-sinister-not-cartoonish`).
  Recommend Devon imports a small selection and judges against the Sponsor's dark palette before
  batch-using this pack for Zone C/D.
- Verdict: **best-in-class for variety + quality in the free tier**. Palette caveat is real.

**Quaternius Universal Base Characters (CC0, free) + Universal Animation Library**
- Source: [Quaternius assets page](https://quaternius.com/assets.html), accessed via search
  2026-06-12 — CC0, rigged humanoid FBX/glTF, Mixamo-compatible rig, Universal Animation
  Library (also CC0). **Strength: Strong (official source, CC0 confirmed by search results).**
- Directly relevant to the "full low-poly character route" section below.

**Mixamo (Adobe, free account required)**
- Source: [LicenseOrg Mixamo guide](https://www.licenseorg.com/guide/3d-assets/mixamo),
  accessed 2026-06-12 — commercial use confirmed, no attribution, no royalties; characters
  cannot be redistributed as standalone assets but CAN be incorporated into shipped games.
  **Strength: Moderate (third-party license summary; Adobe reserves right to change terms).**
- Adobe Mixamo provides free rigged humanoid character models + animation library. Download as
  FBX for Unity. Caveat: Adobe controls availability; terms can change without notice.
- Relevance: if Sponsor pivots to 3D characters, Mixamo is the fastest free-rigged-humanoid path.
  Quaternius Universal Base Characters (CC0, no Adobe dependency) are the more durable alternative.

---

### 2. The "Low-Poly with Smooth Shading" Technique

**What the Sponsor's phrase actually means (technique clarification)**
- "Low-poly" = low triangle count. "Smooth shading" = vertex normals averaged across adjacent
  faces, so lighting interpolates smoothly across the surface — the opposite of "flat shading"
  where each triangle has its own perpendicular normal producing a faceted/prismatic look.
- The naming is technically correct and produces a specific visual: you see the angular geometry
  but the shading gradient flows continuously over it, making it read as a smooth sculptural
  surface with visible polygon edges rather than as a series of flat colored panels.
- Source: [Flat Kit docs — stylized surface](https://flatkit.dustyroom.com/stylized-surface/),
  Dustyroom, accessed 2026-06-12 — "models can be either flat-shaded or smooth-shaded; if
  smooth-shaded normals, the cel shading will be smooth." **Strength: Strong (official shader
  documentation).**
- Source: [80.lv — Implementing Low-Poly Style](https://80.lv/articles/implementing-low-poly-style-in-game-dev),
  accessed via search 2026-06-12 — artist confirms "smooth shaded geometry with material shaders
  can achieve shading gradient colors" using face/edge normals in Blender before export.
  **Strength: Moderate (practitioner interview, specific technique confirmed).**

**What produces this look in Unity 6 URP — build-actionable inventory**

1. **Mesh import setting.** In Unity's Model Import settings, Normals: set to "Import" (if the
   mesh was exported smooth) or "Calculate" with a Smoothing Angle (~60°). Do NOT use Normals:
   "Calculate" + Smoothing Angle = 0° — that produces flat shading regardless of the mesh's
   intended normals.
   - Source: [Unity docs — Importing 3D models](https://docs.unity3d.com/6000.4/Documentation/Manual/ImportingModelFiles.html),
     Unity Technologies, 2026. **Strength: Strong (official docs).**

2. **Standard URP Lit shader** renders smooth-shaded low-poly by default — no custom shader
   required. The "Smoothness" slider controls specular highlight rolloff; low values (0.0–0.2)
   give a matte-with-subtle-highlight read. This is the minimum viable technique.

3. **Optional: cel/toon shader for banded look.** Flat Kit's Stylized Surface shader (€18.35
   discounted, confirmed Unity 6 URP compatible) adds color-step bands, gradient color ramps,
   and specular bands on top of smooth normals — giving the "painterly low-poly" look. The
   shader's "Cel Mode" with smooth normals produces gradient bands that flow over each facet
   rather than uniform face colors.
   - Source: [Unity Asset Store — Flat Kit](https://assetstore.unity.com/packages/vfx/shaders/flat-kit-toon-shading-and-water-143368),
     Dustyroom, accessed 2026-06-12, ~€18-37 (50% sale seen at €18.35 / full price €36.71),
     Unity 2020.3–6000.4 confirmed, URP confirmed, HDRP NOT supported. 8,910 favorites / 199
     ratings. **Strength: Strong (official store page, price verified).**

4. **Lighting setup.** One directional light (warm tone, ~45° elevation to model the sun) + a
   gradient skybox ambient (URP Volume → Visual Environment → Sky Type: Gradient Sky or
   Physical Based Sky). The sky sets the ambient fill color for shadow regions. For the dark-
   sinister project direction: lower the sky ambient to a dark cool purple/blue; set the directional
   light to a warm amber. The contrast between warm key and cool fill over smooth low-poly geometry
   is the primary driver of the "look good" signal (confirmed by Lonely Mountains Downhill, cited
   as a contemporary low-poly benchmark in [Sunday Sundae — How to Make Low Poly Look Good](https://sundaysundae.co/how-to-make-low-poly-look-good/),
   accessed 2026-06-12). **Strength: Moderate (practitioner article with shipped game example).**

5. **Fog + post-processing volume.** URP's built-in Fog (Exponential Squared) provides depth
   separation. A lightweight Post Volume (Bloom on emissive surfaces, Color Grading) locks mood.
   These are the Zone D additions — "same + lighting/fog/post quality pass."

6. **Critical carry-over from iteration 4 FINDINGS.txt:** do NOT use Unity terrain detail
   billboard grass — it disappears at ~55° top-down pitch (confirmed Unity bug). Use prefab scatter
   (same as Zone A/B). The smooth-shaded Zone C ground should be a Quad mesh with URP/Lit, not
   the terrain system. **Strength: Strong (empirically confirmed in Devon's slice + Unity tracker).**

---

### 3. Character Cohesion: Pixel-Art Billboard on a Low-Poly World

**Shipped precedents**

- **Songs of Conquest** (Lavapotion, 2022–present): 2D pixel-art billboard characters on a 3D
  low-poly environment world. Developer interview confirms the hybrid was intentional and the
  hardest technical challenge; the aesthetic was considered "2.5D." The game is commercially
  shipped and positively reviewed for visual cohesion.
  - Source: [80.lv — Mixing 2D Billboards and 3D Environments](https://80.lv/articles/mixing-2d-billboards-and-3d-environments-in-a-game),
    accessed 2026-06-12. **Strength: Strong (developer first-party interview, shipped product).**
  - Key technique: well-packed sprite atlases, a shader-scroll approach for animation (no per-
    billboard individual draw calls), a real-time lightmap applied via top-down UV projection.
    The billboard sprite received ambient occlusion through the lightmap even though it was a
    flat 2D image — this grounded the character in the 3D world. Devon's existing blob shadow
    (iter-3) achieves a simpler version of the same grounding signal.

- **HD-2D series** (Square Enix: Octopath Traveler, Triangle Strategy, 2018–2023): 2D pixel
  sprites on full 3D painterly/smooth environments in Unreal. Commercially validated at AAA scale.
  - Source: [Unreal Engine HD-2D developer interview](https://www.unrealengine.com/en-US/developer-interviews/octopath-traveler-ii-builds-a-bigger-bolder-world-in-its-stunning-hd-2d-style),
    cited in existing `unity-env-art-sourcing-2026-06-12.md`. **Strength: Strong (first-party).**

**Known cohesion risks and mitigations**

| Risk | Cause | Mitigation |
|---|---|---|
| Character "floats" off the ground | Sprite transparent padding below feet (iter-3 root cause A) | Alpha-detected feet pivot (already fixed in Devon's slice) |
| Character reads from wrong biome under orbit | Grazing pitch + lack of grounding cue | Grounding blob shadow (iter-3) + pitch clamp 35-70° (iter-3) |
| Palette mismatch — sprite looks out of place | Pixel-art sprite uses saturated primary colors; low-poly world uses a different hue family | Sample the world's dominant hue-family from the ambient + sky settings, and constrain the sprite's shadow/midtone hues to that family (existing project doctrine: warm amber + dark stone palette) |
| Sprite reads "flat" against a 3D world with depth cues | 2D has no parallax; 3D world recedes | Fog depth gradient (Zone D post pass) compresses perceived depth and makes the billboard read more naturally within the scene |
| Sprite outline style inconsistency | Pixel-art has hard 1-pixel outlines; smooth low-poly geometry has no outline unless a separate outline shader is added | Option A: remove the hard pixel outline from the sprite (use a softer shadow/AO treatment) so the world and sprite share no-outline consistent style. Option B: add a thin outline pass on the low-poly meshes to match. Most shipped 2D/3D hybrids choose Option A (Songs of Conquest, HD-2D). |

**Evidence strength for cohesion assessment:** Moderate-Strong. Songs of Conquest is a direct
shipped example of the identical hybrid (pixel billboard on 3D). HD-2D adds weight but uses
painterly rather than low-poly 3D. No published case study of pixel billboard + low-poly smooth-
shaded specifically — the closest analogue is Songs of Conquest.

---

### 4. If Sponsor Goes Full Low-Poly (Characters Too) — Route Inventory

This section does not recommend the pivot — it enumerates the routes if Sponsor asks. The pixel-
art pipeline (PixelLab + Devon's billboard system) is not being retired on current information;
this is contingency research.

**CC0/free rigged low-poly humanoid options:**

- **Quaternius Universal Base Characters** — CC0, humanoid rig, FBX/glTF, Mixamo-compatible.
  No animation library bundled; pair with Quaternius Universal Animation Library (also CC0) for
  idle/walk/attack cycles. Best CC0 path.
  - Source: [Quaternius assets page](https://quaternius.com/assets.html), accessed 2026-06-12.
    **Strength: Strong (official source, CC0 confirmed).**

- **Mixamo (Adobe)** — Free account, rigged humanoid characters + 100+ animation retarget options.
  Commercial use permitted; no redistribution as standalone. Not truly CC0 (Adobe-owned, terms
  can change). Fastest path to a wide animation library.
  - Source: LicenseOrg Mixamo guide (above). **Strength: Moderate (Adobe terms summarised by
    third party; verify at mixamo.com before shipping).**

**What happens to the PixelLab pipeline if Sponsor goes full low-poly:**
- The PixelLab character pipeline (create_character → 8-direction billboard) is retired for
  environment characters. PixelLab can still serve: UI illustration, icon/HUD assets,
  2D map surfaces, dialogue portrait art. The `create_topdown_tileset` / `create_map_object`
  tools remain relevant regardless of character style choice.
- Re-tooling cost: Low (the pipeline is parallel, not load-bearing for the engine architecture).
  Devon's billboard/facing system becomes irrelevant for 3D characters; the PixelLab MCP session
  scope narrows to non-character assets.
- This is a pre-decision enumeration only. The Sponsor's stated signal ("low-poly with smooth
  shading") applies to the world art; character style is not yet stated. Do not pre-judge.

---

## Application to Embergrave

**Zone C/D build — Devon's immediate brief:**

Zone C minimum viable build:
1. Import Kenney Nature Kit (GLB) or Quaternius Stylized Nature MegaKit (FBX, free tier). Assign
   URP/Lit materials. Set mesh normals to "Calculate" with Smoothing Angle ~60° in Unity import
   settings — this gives smooth shading with visible facets, exactly "low-poly with smooth
   shading."
2. Use same quad-mesh ground as Zone A/B (not terrain). For sand: a URP/Lit material with a sandy
   base color + mild normal map or vertex color variation — procedural placeholder acceptable for
   Zone C judgment (the ArtDrop hot-swap path is already wired).
3. Lighting: one warm directional light + gradient sky ambient (dark cool purple/blue) in a URP
   Volume. This single change over Zone A's lighting will produce the most visible style
   differentiation.
4. Scatter: low-poly trees + rocks from Kenney/Quaternius replacing Zone A's billboard sprites.
   Same prefab-scatter system (no terrain detail billboards).

Zone D adds: URP Fog Volume (Exponential Squared), Bloom on emissive props, Color Grading
post-volume. Optional: Flat Kit shader (~€18-37) to add color-band gradient on key meshes (trees,
rocks) for a more stylized read.

**Palette note for dark-sinister direction:** both Kenney (neutral raw meshes, Devon colors them)
and Quaternius (Ghibli-bright defaults — needs recoloring). For Zone C to match Embergrave's
"blackened/sinister" north-star, Devon should override the Quaternius default materials with
desaturated dark-green/grey/brown tones. The mesh geometry is correct; the palette is the
configurable surface.

**Budget fit:** Zero cost for Kenney + Quaternius free tiers. Flat Kit at ~€18-37 one-time is
within the $50 single-item autonomous cap (memory: `sponsor-trusts-tactical-defaults`). No Sponsor
auth required for Zone C/D build assets at current pricing.

---

## Sources

- [Kenney Nature Kit](https://kenney.nl/assets/nature-kit) — CC0, 330 models, FBX/GLB
- [Nature Kit GLB Pack — Eclair Assets itch.io](https://eclair-assets.itch.io/nature-kit-glb-pack-329-free-cc0-3d-models) — GLB repack confirmation
- [Quaternius Stylized Nature MegaKit](https://quaternius.com/packs/stylizednaturemegakit.html) — CC0, 116 models, Unity URP 2022.3.4+
- [Quaternius assets page](https://quaternius.com/assets.html) — Universal Base Characters + Universal Animation Library, CC0
- [Flat Kit: Toon Shading and Water — Unity Asset Store](https://assetstore.unity.com/packages/vfx/shaders/flat-kit-toon-shading-and-water-143368) — ~€18-37, Unity 6 URP confirmed
- [Flat Kit docs — Stylized Surface](https://flatkit.dustyroom.com/stylized-surface/) — smooth vs flat shading docs
- [80.lv — Implementing Low-Poly Style in Game Dev](https://80.lv/articles/implementing-low-poly-style-in-game-dev) — practitioner smooth-shading technique
- [80.lv — Mixing 2D Billboards and 3D Environments (Songs of Conquest)](https://80.lv/articles/mixing-2d-billboards-and-3d-environments-in-a-game) — billboard/3D cohesion technique
- [Sunday Sundae — How to Make Low Poly Look Good](https://sundaysundae.co/how-to-make-low-poly-look-good/) — lighting setup + Lonely Mountains Downhill example
- [RetroStyleGames — Low Poly Game Art Guide](https://retrostylegames.com/blog/low-poly-game-art-an-ultimate-guide/) — shading approaches survey
- [LicenseOrg — Mixamo License Guide](https://www.licenseorg.com/guide/3d-assets/mixamo) — commercial use summary
- [Unreal Engine — Octopath Traveler II HD-2D interview](https://www.unrealengine.com/en-US/developer-interviews/octopath-traveler-ii-builds-a-bigger-bolder-world-in-its-stunning-hd-2d-style) — pixel sprite + 3D world precedent
- [Songs of Conquest Q&A — eXplorminate](https://explorminate.org/songs-of-conquest-qa/) — 2D/3D hybrid art direction context
- [Unity Issue Tracker — billboard grass disappears above viewpoint](https://issuetracker.unity3d.com/issues/billboardgrasstexture-billboard-grass-texture-painted-on-terrain-hills-slope-disappears-when-viewpoint-is-above-it) — terrain billboard top-down bug (also in previous sourcing note)
