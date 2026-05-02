# Visual Direction — Embergrave (M1, owned by Uma)

**Owner:** Uma · **Phase:** M1 · **Decision authority:** Uma owns the call. Logged in `DECISIONS.md` once committed.

This is the single visual-direction call for Embergrave. Drew's mob art, Devon's UI scenes, and Tess's regression screenshots all hang off this. Concrete enough that a tester can check whether a frame matches the spec.

## Decision (one line)

**Hand-painted-feel pixel art at 96 px/tile (16:9 logical 480×270 internal canvas, 4× scaled to 1920×1080 / 3× to 1440×810 / 2× to 960×540)** with a dark-fantasy ember-and-stone palette and a single warm light source per scene. Animation runs at 12 fps for character idles and 24 fps for combat impacts.

**Why pixel art:**
- Two devs, ~4 weeks part-time per milestone — pixel art is the only style that scales with the team. Hand-drawn / painted assets demand a full-time artist; vector loses the "dungeon crawler" mood; 3D is out of scope.
- Renders crisp on HTML5 at any window size with nearest-neighbour scaling; no anti-aliasing tax.
- Aseprite pipeline is already in the tech stack call (Drew/Uma own).
- The reference shelf (*Hyper Light Drifter*, *Tunic*, *CrossCode*, *Crystal Project*) proves it works for top-down adventure.

**Why 96 px/tile:**
- Fine enough that mobs read as creatures, not blobs (T1 grunt is ~96×128 on screen).
- Coarse enough that one mob can be drawn in a day and one tileset in a week.
- 480×270 internal canvas at integer scale fills 1080p without subpixel jitter — the HTML5 export's biggest visual bug source.

## Internal canvas + scaling rules

- **Logical resolution:** 480 × 270 px (16:9).
- **Tile size:** 32 × 32 internal = 96 × 96 at 3× scale onscreen.
- **Player sprite footprint:** 32 × 48 internal (so the avatar reads as just-taller-than-a-tile).
- **Allowed scale factors:** 2×, 3×, 4× (integer only — `Project Settings → Display → Stretch` set to `viewport` + `keep`). At non-integer browser zooms, force letterbox.
- **Filter:** nearest-neighbour everywhere. No bilinear. Devon: confirm `default_texture_filter = nearest` in `project.godot`.
- **Camera:** logical-pixel-aligned, 1 px = 1 px. No camera shake larger than 4 logical px. Devon's screen-shake spec must respect this.

## Lighting model

- **One warm key light per scene**, baked into tile colors. No realtime shadows in M1.
- **Ember accents** are literal `#FF6A2A` pixels in animations (fire bowls, ember-bursts, the player's heart-glow on level-up).
- **Vignette** is a dark-overlay quad at 30–60% opacity around the screen rim, intensifying as the player descends strata. M1 (stratum 1) uses 30%.
- **Player low-HP red pulse** is a separate vignette layer sitting *over* the dark vignette, ramped by `(33 - hp_pct) / 33` clamped 0–1.

## Stratum visual progression (8-stratum plan)

The palette must signal "going deeper / more dangerous." Progression is by **dominant hue temperature shift + saturation drop + ember-accent intensity climb**.

| Stratum | Setting          | Dominant hue family       | Saturation | Ember accent | Reads as            |
|---------|------------------|---------------------------|------------|--------------|---------------------|
| 1       | Outer Cloister   | Warm sandstone + parchment| mid        | low          | "you've arrived"    |
| 2       | Sunken Library   | Muted teal + bronze        | mid-low    | low          | quiet, eerie         |
| 3       | The Foundry      | Iron grey + amber forge    | mid        | mid          | industrial menace    |
| 4       | Caverns of Echo  | Cold blue-grey            | low        | mid          | isolation            |
| 5       | The Bone Market  | Sickly pale-yellow + violet| mid-high  | mid          | wrongness            |
| 6       | Glasswound       | Black + cyan-glass         | high accent on dark | high | hostile, sharp        |
| 7       | The Ember Vein   | Deep red + pure black      | high       | very high    | climactic            |
| 8       | Heart of Embergrave | Pure black + white-hot ember | extreme | extreme    | almost-blinding      |

Each stratum has 4 base tile colors + 2 accent colors + 1 hostile-creature accent. The ember accent (`#FF6A2A`) is constant across all strata — the through-line of the player's flame.

**M1 only ships stratum 1 (Outer Cloister).** Stratum 1's full palette is in `palette.md`; the rest of the strata get authoritative palettes only when the work begins.

## Animation feel

- **Player idle:** 12 fps, 4 frames, ~1 s loop. Subtle breathing, ember glints in the eyes every ~3 s.
- **Player walk:** 12 fps, 8 frames, 8-direction (or 4-direction with mirror — Drew's call).
- **Player attack light:** 24 fps, 4 frames, 0.17 s total.
- **Player attack heavy:** 24 fps, 8 frames, 0.33 s total with a 1-frame 60 ms hit-stop on contact.
- **Player dodge-roll:** 24 fps, 6 frames, 0.25 s total — the i-frame window is the middle 4 frames (~0.17 s).
- **Mob idle:** 12 fps, 4 frames.
- **Mob aggro telegraph:** 1-frame red glow on silhouette plus a 4-frame "rear back" anim at 24 fps.
- **Mob death:** 4-frame stagger + 4-frame ember-dissolve at 24 fps, total 0.33 s.
- **Item drop:** the item literally drops from above with a 6-frame bounce anim at 24 fps, then the tier-color light-beam particle effect plays in a 1 s loop until pickup.

## Camera behavior

- **Default:** dead-centered on player, no smoothing.
- **In combat (any aggro'd mob within 8 tiles):** light look-ahead toward the cursor or movement direction, max 32 logical px offset, 0.15 s damp.
- **Boss room entry:** 1.0 s pan from player to boss and back, locked input during pan, slight zoom-out (1.2× world, equivalent of dropping internal res to 400×225 visible).
- **Death:** push-in to 2× internal-pixel scale on player over 0.8 s, then dissolve.

## UI vs. world rendering

- **World:** rendered in the 480×270 logical canvas, then upscaled. Tile-aligned, pixel-aligned, no subpixels.
- **UI / HUD / panels:** rendered in screen-space at the **output resolution** — so HUD text is crisp at 1080p, not bilinear-upscaled from 480×270. Devon: this is two `Viewport` layers in Godot — a `World` viewport at internal res, a `UI` `CanvasLayer` at display res. Test that text inside ItemTooltip remains sharp at all zooms.

## Reference board (names only — no asset embedding per `team/GIT_PROTOCOL.md` "no large binaries")

### Games
- **Hyper Light Drifter** — pixel resolution + saturated accent on a desaturated ground; the "single warm light source" instinct.
- **Tunic** — adventurous mood; mystery via what's *not* shown; isometric-feel even though we're top-down.
- **CrossCode** — 2D combat polish, hit-stop discipline.
- **Crystal Project** — proof a 3-person team can hand-author a beautiful 8-region crawler in 2D.
- **Hades** — run feel + UI clarity in combat. We don't copy Hades's painted style; we copy its UI minimalism.
- **Diablo II** — gear-tier color language (white / yellow / blue / orange) that we adapt below.
- **Death's Door** — top-down camera framing; how a small-team game gets cinematic moments cheaply.

### Films / illustration / aesthetic
- **Sleepy Hollow (1999, Burton)** — the muted greens-and-greys with a single ember light source.
- **Mike Mignola** (Hellboy comics) — black-shadow + warm-accent illustration logic.
- **From Software** environment art (Dark Souls 1) — vertical decay; deeper = older = angrier.
- **Sergio Toppi** illustration ink work — dense detail in tilesets; restraint in characters.

### Anti-references (we do NOT take cues from)
- Glossy 3D-pre-rendered sprites (Diablo III) — tonally wrong.
- Cute pixel-art (Stardew Valley) — Embergrave is dark fantasy, not cozy.
- Heavy outlines / cel-shaded vector (Cuphead) — we don't have the budget.
- Photoreal 2D (Octopath Traveler) — the HD-2D lighting bill is too high.

## Constraints this decision puts on other roles (logging in DECISIONS.md)

- **Drew (mob art, item icons):** all sprites authored at the per-spec internal res. Item icons are 24×24 internal (3× = 72×72 displayed in tooltip). Mobs sized so a stratum-1 grunt is ~32×48 internal (M2+ bigger mobs will scale up).
- **Devon (UI, scenes):** nearest-neighbour filter project-wide; integer scale; UI on a separate screen-space canvas layer. Camera shake limited to 4 logical px max amplitude.
- **Tess:** screenshot regression tests can use exact-pixel diff against a reference frame — the integer-scale rule guarantees pixel-perfect reproducibility at a given resolution.
- **Audio (later, Uma curates):** key tonal anchors are dark string + bell + ember-crackle; not orchestral, not chiptune. Ambient bed loops at 30 s minimum.

## Open questions

- **Sprite outline:** Do we use a 1-pixel dark outline around characters? Uma's call: **yes** for player and humanoid mobs (clarity over silhouette), **no** for environmental tiles. Drew confirms feasibility when he picks up mob art.
- **Diegetic UI:** the player's HP could be shown as an embered crystal in the HUD's portrait corner instead of a literal bar. M2 polish stretch — M1 ships with the bar in `hud.md`.

---

## Tester checklist (yes/no)

| ID    | Check                                                                                                | Pass criterion (yes/no) |
|-------|------------------------------------------------------------------------------------------------------|-------------------------|
| VD-01 | Internal viewport resolution is 480 × 270                                                            | yes                     |
| VD-02 | Default texture filter is nearest-neighbour project-wide                                              | yes                     |
| VD-03 | Window scales only at integer factors (2×, 3×, 4×); non-integer scales letterbox                     | yes                     |
| VD-04 | UI canvas-layer renders text at output resolution (sharp, not upscaled from 480×270)                 | yes                     |
| VD-05 | Stratum 1 dominant palette matches the warm sandstone + parchment family in `palette.md`             | yes                     |
| VD-06 | Player idle animation is 4 frames at 12 fps, ~1 s loop                                               | yes                     |
| VD-07 | Player attack-heavy animation produces a 60 ms hit-stop on contact                                   | yes                     |
| VD-08 | Player dodge-roll i-frame window is centered in the animation, ~0.17 s of 0.25 s total              | yes                     |
| VD-09 | Camera shake amplitude never exceeds 4 logical pixels                                                | yes                     |
| VD-10 | Boss-room entry plays a 1 s camera pan from player to boss and back, with input locked              | yes                     |
| VD-11 | Vignette overlay at 30% opacity is visible in stratum 1                                              | yes                     |
| VD-12 | When player HP < 33%, a red vignette layer fades in over the dark vignette                          | yes                     |
| VD-13 | Player and humanoid-mob sprites have a 1-pixel dark outline; tiles do not                           | yes                     |
| VD-14 | Item drop plays a 6-frame bounce at 24 fps, then a tier-color light-beam particle effect            | yes                     |
| VD-15 | All hex codes referenced in `palette.md` exist in their named ramps with no duplicates              | yes                     |
