# PixelLab Pipeline — Tool Sequence, Traps, and Cost Model

Reference for agents using `mcp__pixellab__*` to generate character sprites, then
`mcp__pixel-mcp__*` for doctrine-palette compliance and export. Distilled from the first
end-to-end PixelLab → pixel-mcp execution (S1 Charger, 2026-05-17).

Cross-reference: [`pixel-mcp-pipeline.md`](pixel-mcp-pipeline.md) for all pixel-mcp tool bugs
and behavioral surprises. This doc covers the PixelLab side and the seam between the two tools.

---

## Execution context — orchestrator main session ONLY

**`mcp__pixellab__*` and `mcp__pixel-mcp__*` are NOT dispatchable to sub-agents.**

Empirically confirmed 2026-05-21 (Devon T8 boss wake-anim blocker): sub-agent personas at
`.claude/agents/{role}.md` enumerate a specific tool list, and **no role enumerates the
PixelLab or pixel-mcp tools**. Devon's persona lists only `mcp__clickup__*` plus the basics
(Read/Write/Edit/Grep/Glob/Bash/Skill/WebFetch). Attempting `mcp__pixellab__animate_character`
from a sub-agent returns `No such tool available`. Direct REST bypass via `curl` with the
Bearer token is harness-blocked by the auto-mode credential-leakage classifier.

**Execution model:** The orchestrator main session runs all PixelLab + pixel-mcp tool calls
directly (steps 1–10 in the canonical pipeline below), saves the final exported PNGs to a
checkout-able path under `assets/sprites/<char>/`, **then** dispatches a sub-agent (Devon for
engine integration, Drew for game-side hook-up) to do the integration work:
- Add the `<state>_<dir>` animation key to the relevant `.tres` SpriteFrames resource
- Hook into the state machine (`wake()`, `dash()`, etc.)
- Write paired GUT test
- Open the PR

This split is durable until persona files are updated to include `mcp__pixellab__*` /
`mcp__pixel-mcp__*` (out of scope as of 2026-05-21 — would expand sub-agent attack surface +
need explicit Sponsor approval).

---

## Canonical hybrid pipeline

```
1.  mcp__pixellab__create_character(description, body_type, template, size, n_directions=8, …)
       → returns char_id

2.  mcp__pixellab__get_character(char_id)   ← poll until rotations are populated (30–120 s)
       → returns 8 rotation PNG URLs (south / south-east / east / north-east / north /
         north-west / west / south-west)

3.  curl each direction URL → save to:
       assets/sprites/<char>/_pixellab_raw/<direction>.png

4.  mcp__pixel-mcp__create_canvas(W, H, "rgb")
       → returns scratch .aseprite path  (MUST exist before import_image — import_image does
         NOT create the file)

5.  mcp__pixel-mcp__import_image(sprite_path, image_path, layer_name, frame_number)
       NOTE: parameter name is `image_path`, NOT `file_path` (the parent doc uses `file_path`
       elsewhere — pixel-mcp tool param naming is not consistent)

6.  mcp__pixel-mcp__flatten_layers(sprite_path)

7.  mcp__pixel-mcp__crop_sprite(...)   ← see canvas-size trap; almost always needed for
                                          non-square target dimensions

8.  mcp__pixel-mcp__quantize_palette(sprite_path, target_colors, algorithm, ...)
       ← see dupe-slot trap; over-request target_colors by 30–40%

9.  [optional doctrine-lock — see "Doctrine palette compliance" section below]

10. mcp__pixel-mcp__export_sprite(sprite_path, output_path, "png", frame_number)
```

**Key seam constraint:** PixelLab has **no palette-lock parameter** in `create_character` —
the model picks its own colors. All doctrine compliance happens in pixel-mcp post-process.

---

## Canvas-size trap — `size` param controls character height, NOT canvas

`create_character(size=48)` produces a **68×68 square canvas** with the character roughly 40 px
tall × 30 px wide, centered. The `size` param controls approximate character height; the canvas
is always square (regardless of `body_type` or `size`) and is always ~`size × 1.4`.

**Empirical size → canvas table (extend as more sizes are observed):**

| `size` param | observed canvas | observed in project |
|---|---|---|
| 32 | 48×48 | (DO NOT USE for humanoid mobs — too small vs roster, see below) |
| 48 | 68×68 | Player / Grunt / Grunt v2 / Charger / Shooter / NPCs / PracticeDummy — **project humanoid mob scale** |
| 56 | 80×80 | Stratum1Boss — **project boss scale** |

**Project roster scale doctrine (PR #364→Sunken-Scholar miscall 2026-05-24).** Match the
`size` param to the EXISTING ROSTER, not to any literal "N px" reference in an Uma direction
doc. The project's humanoid mob scale is `size=48` (→ 68×68 canvas, ~48 px character height);
bosses are `size=56` (→ 80×80 canvas). A new humanoid mob created with `size=32` will render
visibly chibi-shrunken next to a Grunt at `size=48` in the same room — even if a doc cites
"32 px standing height" the right reading is "32 px is the dimension-table FLOOR, not the
target for THIS character." Uma's `palette-stratum-2.md §5.5` Sunken-Scholar entry empirically
hit this trap: the "Standing height ~32 px (humanoid floor per pixel-mcp-pipeline.md
dimension table)" line was misread literally as `size=32`; the right call was `size=48` to
match every other character in the PixelLab account. **Before dispatching a `create_character`
call: log into pixellab.ai → confirm the canvas size of the closest existing analog (Grunt
for melee, Shooter for ranged, Stratum1Boss for boss) and match.**

**Consequence:** To hit per-character target dimensions from the art-pass brief (e.g. Charger
48×32 landscape, Grunt 32×48 portrait), the PixelLab output must be cropped after import:

```
1. create_character(size=48)             → 68×68 canvas, char ~40×30 centered
2. import_image into pixel-mcp scratch
3. get_sprite_info to confirm dimensions
4. crop_sprite(x, y, w=48, h=32)         → extract character bounding box
```

Unlike Midjourney where `--ar` gives approximate canvas-shape control, PixelLab canvas is
always-square — plan the crop step into every pipeline.

---

## Transparent-padding trap — canvas bottom is NOT the character's feet

PixelLab canvases carry roughly **24 px of fully-transparent alpha below the character's
lowest opaque pixel** (validated on 92×92 `v3` canvases; likely present on other sizes but
not independently measured). Ground-anchored renderers that treat the canvas bottom-center as
the feet will float the character ~24 px above its true ground position. The offset is
camera-angle-dependent (grows more visible at steeper pitch) and is easy to miss in
single-view tests.

**Why BottomCenter is insufficient.** The naive fix — pivot `(0.5, 0.0)` in bottom-normalized
convention, i.e. canvas BottomCenter — leaves the full transparent footer intact. Empirically
confirmed on the Player Monk v3 strict rig (92×92, 88 frames): BottomCenter still produced a
visible residual offset at multiple camera pitches; Sponsor photographed the drift. The
correct pivot is pinned to the **actual lowest opaque pixel row** in the frame, not the
canvas edge. (ClickUp 86ca7y46c, iteration-3 evidence comment.)

**Measured values (Player Monk v3 strict, 2026-06-12):**
- Canvas: 92×92 px
- Lowest opaque row: ≈ row 67 of 92 (0-indexed from top)
- Transparent footer: ≈ 24–25 px
- Pivot bottom-normalized: `spritePivot.y ≈ 0.266`
- Validated via 12-capture 360°-orbit + zoom boundary sweep across all 88 frames

**Convention used throughout:** `0 = canvas bottom, 1 = canvas top` (bottom-normalized). The
measured `0.266` means the pivot sits 26.6% of canvas height above the canvas bottom.

**Alpha-scan code (PIL + NumPy):**

```python
import numpy as np
from PIL import Image

def find_sprite_pivot(png_path: str) -> float:
    """Return bottom-normalized pivot_y (0=canvas bottom, 1=top).
    Pin the pivot to the lowest opaque pixel row in the frame."""
    arr = np.array(Image.open(png_path).convert("RGBA"))
    alpha = arr[:, :, 3]           # shape (H, W)
    h = alpha.shape[0]
    opaque_rows = np.where(alpha.max(axis=1) > 0)[0]
    if opaque_rows.size == 0:
        return 0.0                 # fully transparent — fallback
    lowest_opaque = int(opaque_rows.max())   # 0-indexed from top
    # bottom-normalise: canvas bottom = row (h-1)
    return 1.0 - lowest_opaque / (h - 1)
```

**Practical rule:** scan 2–4 representative frames (idle south + a walk extreme). If the
pivot variance across frames is small (< 0.01), use the mean as a single shared pivot;
otherwise use per-frame pivots. The monk frames had low variance across all 88 frames — a
single mean pivot was sufficient.

**Engine application:**

- **Godot:** shift `sprite.offset.y` so the lowest opaque row sits on the node origin
  (ground contact point) instead of the canvas bottom/center.
- **Unity:** `sprite.pivot = new Vector2(0.5f, pivot_y)` with the bottom-normalized value
  (Unity's pivot `y=0` = canvas bottom — matches this convention directly).

**Verification ritual:** place a visible marker at the character's world ground point and
run a 360°-orbit sweep at both minimum and maximum camera pitch. The marker must sit at the
character's visible feet in every capture; camera-angle-dependent drift is the tell that the
padding is still unaccounted for.

**Cite:** ClickUp ticket 86ca7y46c (engine-spike iteration 3, evidence comment).
Engine-agnostic finding — applies to Godot and Unity alike.

---

## Quantize duplicate-slot trap — over-request target_colors

PixelLab generations that are color-clustered (brown bears, grey wolves, etc.) cause k-means
quantize to produce **repeated palette slots**. The Charger trial's 12-target call produced
4× `#65353E` → only 9 distinct colors. Dupe slots consume budget and reduce effective doctrine
mappings.

**Fix — pick one:**

1. **Over-request:** pass `target_colors` 30–40% higher than the doctrine palette size. For an
   11-color doctrine palette, request `target_colors=15` or `16`. Excess slots absorb the dupes.
2. **Dedupe-after-quantize:** call `get_palette` after `quantize_palette`, count distinct hexes,
   re-quantize with a higher target if dupes appear. Slower but more predictable.

---

## Doctrine palette compliance — pick a strategy

After `quantize_palette`, the sprite is indexed-mode with PixelLab's k-means palette. Three
strategies to enforce the doctrine palette, ordered worst → best:

### Strategy 1 — Naive positional set_palette ❌ (DO NOT USE)

Calling `set_palette` with the doctrine palette in its own canonical order (darkest →
deep-shadow → mid-dark → fur-base → …) maps **positionally by slot index**, not perceptually.
Validated failure: a brown bear collapsed into a flat black silhouette because slot 1 (mid-brown
fur) → doctrine darkest, slot 2 (red eye-glow) → deep shadow, slot 4 (light tan) → mid fur.

This is the trap documented in `pixel-mcp-pipeline.md §"Indexed-mode set_palette overwrites slot
hexes but does NOT remap existing pixels"` — never call set_palette with a doctrine palette in
canonical order on an indexed-mode sprite.

### Strategy 2 — Luminance-sort both palettes ⚠️ (mitigation)

If you must use `set_palette` and don't want to compute per-slot nearest-neighbor: sort BOTH
the quantized palette and the doctrine palette by luminance (`Y = 0.299R + 0.587G + 0.114B`)
before the call. Dark maps to dark, light to light, preserving brightness ordering. Accents
in different hue ranges (e.g. an isolated red eye-glow among brown tones) may still cross-map
if their luminance is close to non-accent slots.

```python
def luminance(hex_color):
    h = hex_color.lstrip("#")
    r, g, b = int(h[0:2],16), int(h[2:4],16), int(h[4:6],16)
    return 0.299*r + 0.587*g + 0.114*b

quantized_sorted = sorted(quantized_palette, key=luminance)
doctrine_sorted  = sorted(doctrine_palette,  key=luminance)
set_palette(palette=doctrine_sorted)
```

### Strategy 3 — Per-slot nearest-neighbor mapping ✓ (BEST, validated 2026-05-17)

Compute the perceptually nearest doctrine color for each quantized slot using Euclidean RGB
distance (or CIEDE2000 for accuracy), then build a doctrine palette in the SAME slot order as
the quantized palette. A positional `set_palette` call then maps each slot to its perceptually
nearest doctrine match.

This is the **validated winner** from the Charger trial — recovered the bear silhouette, fur
tonal variation, AND eye-glow (`#C60A1A` PixelLab red → `#D24A3C` doctrine aggro-glow via
nearest-match).

```python
def rgb(hex_color):
    h = hex_color.lstrip("#")
    return (int(h[0:2],16), int(h[2:4],16), int(h[4:6],16))

def distance(c1, c2):
    return sum((a-b)**2 for a,b in zip(rgb(c1), rgb(c2)))

def nearest_doctrine(quantized_hex, doctrine_palette):
    if quantized_hex.endswith("00"):   # transparent
        return "#00000000"
    return min(doctrine_palette, key=lambda d: distance(quantized_hex, d))

# Build positional doctrine palette matching quantized slot order:
nn_palette = [nearest_doctrine(q, DOCTRINE_S1) for q in quantized_palette]
set_palette(palette=nn_palette)
```

**Caveat:** If the doctrine palette has no good match for a PixelLab color (e.g. a red-purple
accent with no red-purple in doctrine), the nearest match may be a muddy compromise. Visually
verify after every doctrine-lock; if the result loses a key character beat, extend the doctrine
palette via Uma's lane (per `pixel-mcp-pipeline.md §"Doctrine palette lock — worked example"`).

**Refinement — manual override for character-beat preservation:** When a quantized slot is a
doctrine-critical accent (red eye-glow, gold trim, signature color) but the doctrine palette
has only ONE family member for that color (e.g. one red, one gold), pure Euclidean
nearest-neighbor will route the slot to a muddy compromise if the source color is far from
that single doctrine entry. Manually override that slot to the doctrine "family member" even
when the Euclidean distance points elsewhere — character-beat preservation beats slot accuracy.

Validated 2026-05-17 on S1 Grunt v2: PixelLab produced two red slots — `#F5490A` bright
eye-glow (slot 12) and `#6B1114` dark eye-shadow (slot 7). Euclidean nearest-neighbor
correctly routed slot 12 → `#D24A3C` aggro-glow. But slot 7's nearest match by RGB distance
was `#5A4738` cloth base (d²=1513) over `#D24A3C` (d²=15458) — a 10× preference for the
muddy brown. Letting the algorithm win would have erased the eye-shadow ring entirely. Manual
override to `#D24A3C` for both red slots preserved the character beat.

**Rule of thumb:** before applying the nearest-neighbor palette, scan the quantized palette for
known character-beat colors (high-saturation accents, glow tones, signature hues). For each,
verify the algorithm's choice — if it's not the closest doctrine family member of the same
hue family, override manually.

**Refinement — doctrine-exaggeration when doctrine has only ONE color per hue family:**

PixelLab typically generates 2-3 tones per accent family (e.g. bright-red eye-dot + pinkish-red
eye-wash + dark-red shadow). Doctrine palettes often have only ONE color per hue family (e.g.
just `#D24A3C` for "red"). Pure nearest-neighbor will map ALL the PixelLab accent tones to that
single doctrine color, **exaggerating** the feature from "small dot + soft wash" into "solid
bright area."

Validated 2026-05-17 on Shooter v2 eye-variant: PixelLab generated bright `#BF1E22` eye-dots
(small area) plus warm-pink `#CF695B` eye-wash (larger area, like flushed-skin shading). My
first doctrine-lock mapped BOTH `#BF1E22` and `#CF695B` to `#D24A3C` aggro-glow → the entire
face turned bright red. Sponsor correctly diagnosed: "no, doctrine made it face red; pixellab
just made big eyes."

**Fix — selective slot routing:**

1. Identify the BRIGHTEST / most-saturated slot in the accent family — that's the "true
   feature pixel" (the eye-dot, the gem accent, etc.). Map it to the doctrine accent color.
2. Route the SOFTER / less-saturated slots in the same hue family to a NEUTRAL doctrine color
   (bone, skin, shadow) — these are PixelLab's gradient/wash pixels, not the feature itself.
3. This trades absolute hue accuracy on the wash for character-beat clarity. The result reads
   as "feature in correct location with correct color" rather than "feature spreads into
   surrounding region."

**Worked example for Shooter eye-variant (5 PixelLab red-family slots → 2 doctrine slots):**

| PixelLab slot | Source hex | Naive nearest | Selective routing | Outcome |
|---|---|---|---|---|
| 7 | `#CF695B` warm pink-wash | `#D24A3C` red | `#C9C2B2` bone-white | Wash dissolves into skull |
| 9 | `#CF695B` dupe | `#D24A3C` red | `#C9C2B2` bone-white | Wash dissolves |
| 10 | `#CF695B` dupe | `#D24A3C` red | `#C9C2B2` bone-white | Wash dissolves |
| 12 | `#BF1E22` bright eye-dot | `#D24A3C` red | `#D24A3C` red ✓ | Eye preserved as bright accent |
| 16 | `#D4B6AD` light pink (skull) | `#C9C2B2` bone | `#C9C2B2` bone ✓ | Skull stays bone-white |

This is the **iteration-via-set_palette** pattern in action: the third `set_palette` call on
the same indexed canvas (v3) corrected the over-routing without re-importing or re-quantizing.
Cost: zero generations, ~1 second of pixel-mcp time.

### Strategy 4 — Luminance-band role routing + character-beat overrides ✓ (BEST for cross-stratum retints, validated 2026-05-18 on S1→S2 Stoker, PR #276)

Strategies 1–3 all route by **color distance** (palette → palette, Euclidean RGB or
CIEDE2000). That works when the source is a freshly-generated PixelLab character whose
tonal structure is unknown and must be discovered.

It **fails** when the source is an **already-doctrine-locked sprite being retinted to a
new stratum**. Color distance is silhouette-blind across stratum doctrines — a "red
eye-glow" pixel in S1 may have no red neighbor in S2 at all, so pure NN routes it to
whatever's closest in RGB (cloth-base, leather, anything), and the role/tonal structure
the source was authored with collapses.

Strategy 4 routes by **luminance ROLE** (where the pixel sits in the tonal hierarchy)
rather than by source hex distance. This works specifically because the source is already
doctrine-locked — its tonal structure is **correct by construction**, so the
highlight pixels really are highlights, mid pixels really are mids, etc. Mapping role →
role rather than color → color preserves the silhouette across the retint.

**Band-to-doctrine-role table** (S2 Stoker doctrine, illustrative):

| Luminance Y | Role | S2 Stoker doctrine slot |
|---|---|---|
| Y ≥ 0.78 | Highlight | `#E8D9B0` warm cream |
| 0.60 ≤ Y < 0.78 | Lit | `#C49960` warm tan |
| 0.40 ≤ Y < 0.60 | Mid | `#8A5A2E` bronze |
| 0.25 ≤ Y < 0.40 | Shadow | `#4E2F18` deep bronze |
| Y < 0.25 (non-alpha) | Deep | `#2A180C` near-black |
| outline (pre-tagged) | Outline | `#1A0E08` stratum outline |

(Actual band thresholds + doctrine hexes live in `tools/bake_stoker_palette.py` — tune
per stratum doctrine.)

**Character-beat overrides bypass the routing.** Doctrine-critical accents (red
eye-glow, iron-neutral metal) must never be reduced to "whatever luminance band they
fall in" — those *are* the character beat and need explicit detection BEFORE the
luminance dispatch. Validated HSV detection patterns:

- **Red eye-glow:** `H ∈ [350°, 20°] AND S > 0.45 AND V > 0.4` → route to
  doctrine accent (`#D24A3C` aggro-glow in S2 Stoker).
- **Iron-neutral metal:** `S < 0.15 AND 0.25 < V < 0.65` → route to doctrine
  iron slot (`#7A7468` neutral iron); preserves metal from being warmed into the
  bronze family.

**Implementation pattern** (from `tools/bake_stoker_palette.py`):

```python
def route_pixel(r, g, b, a):
    if a == 0:
        return (0, 0, 0, 0)
    # Character-beat overrides FIRST — bypass luminance routing.
    if is_red_glow(r, g, b):
        return DOCTRINE["aggro_glow"]
    if is_iron_neutral(r, g, b):
        return DOCTRINE["iron"]
    # Then luminance-band role dispatch.
    y = 0.299*r + 0.587*g + 0.114*b
    if y >= 0.78 * 255: return DOCTRINE["highlight"]
    if y >= 0.60 * 255: return DOCTRINE["lit"]
    if y >= 0.40 * 255: return DOCTRINE["mid"]
    if y >= 0.25 * 255: return DOCTRINE["shadow"]
    return DOCTRINE["deep"]
```

**Validation (2026-05-18, PR #276 Stoker):** 280 retinted PNGs across the Stoker
animation set, 16/16 GUT tests green, Tess HTML5 sign-off. The naive Strategy-3 pure-NN
alternative would have routed the red eye-glow into the cloth-base family (closest RGB
neighbor with no red in S2 doctrine) and routed the iron buckle into warm-bronze
(metal-warmth contamination) — both verified by trial before settling on Strategy 4.

**When to use 3 vs 4:**

| Scenario | Strategy |
|---|---|
| Fresh PixelLab generation → first doctrine-lock | **3** (per-slot NN + manual overrides) |
| Doctrine-locked sprite → retint to sibling stratum | **4** (luminance-band + beat overrides) |
| Doctrine-locked sprite → retint within same stratum | **3** (NN is fine, doctrine families overlap) |
| Roles unknown / source has unclear tonal structure | **3** (discover via NN first) |
| Roles known / source authored to doctrine | **4** (preserve role mapping) |

**5-step validation pattern:**

1. Identify character beats in source (eye-glow, signature metal/gem, etc.) and write
   their HSV bounds.
2. Define luminance bands + doctrine role mapping for the target stratum.
3. Bake one frame, visual diff vs source — confirm silhouette + beats preserved.
4. Bake full animation set; spot-check across animations (idle / hit / death frames
   often surface band-threshold edge cases).
5. GUT + Playwright + HTML5 visual-verification per the standard gate.

**Reference impl:** `tools/bake_stoker_palette.py` (PR #276). Nit: hardcoded
`REPO_ROOT` deferred to M4 — see ClickUp `86c9uze5j`.

### Strategy 5 — Single-region hue-mask recolor with luminance preservation ✓ (validated 2026-06-07, S1 well-head water)

Strategies 1–4 all operate **palette-wide** — they remap every pixel. Use Strategy 5 when
only ONE color region needs a hue shift (e.g. water came back cool/teal but the surrounding
moss, stone rim, and bucket detail are already doctrine-correct). Remapping the whole palette
would disturb the correct neighbors; a targeted region mask shifts the off-material alone, and
re-rolling would risk losing the good detail elsewhere.

**Hue-mask discrimination (S1 water vs moss example):** hue families have discriminating
color-channel relationships that survive PixelLab's palette variance. Pick the mask whose
false-positive rate on neighboring materials is verifiable by inspection.

| Material to target | Mask condition | Why |
|---|---|---|
| Cool / teal water | `b > r + 12` | blue clearly dominates red in teal |
| Yellow-green moss | `g > b + 20` | green dominates blue — the `b > r+12` water mask naturally EXCLUDES it |
| Warm stone / dirt | `r > b AND r > g` | already doctrine-warm; untouched |
| Red accent / glow | `r > g + 30 AND r > b + 30` | red dominates both |

**Luminance-preserving recolor (keep light/dark structure, shift hue only):**

```python
import numpy as np
from PIL import Image

# Target warm-neutral ratio from the doctrine (e.g. S1_YARD_WATER_DOCTRINE R:G:B ≈ 1.0:0.92:0.82)
RATIO_R, RATIO_G, RATIO_B = 1.0, 0.92, 0.82
DENOM = 0.299*RATIO_R + 0.587*RATIO_G + 0.114*RATIO_B  # ≈ 0.9325 — normalises k to preserve luminance

arr = np.array(Image.open("source.png").convert("RGBA"), dtype=float)
r, g, b, a = arr[...,0], arr[...,1], arr[...,2], arr[...,3]

mask = (b > r + 12) & (a > 0)              # cool water pixels only
L = 0.299*r + 0.587*g + 0.114*b            # BT.601 source luminance
k = L / DENOM                              # scale so recolored pixel matches source luminance
arr[mask, 0] = np.clip(k[mask]*RATIO_R, 0, 255)
arr[mask, 1] = np.clip(k[mask]*RATIO_G, 0, 255)
arr[mask, 2] = np.clip(k[mask]*RATIO_B, 0, 255)

Image.fromarray(arr.astype(np.uint8), "RGBA").save("recolored.png")
```

**Why luminance-preservation matters:** a flat hue-swap (`r,g,b = target` for all masked
pixels) collapses the structure — the glint becomes the same color as the deep shadow. Scaling
by `L/DENOM` keeps the bright glint bright and the deep water dark, just in the new hue family.

**When to use 5 vs 3/4 vs re-roll:**

| Scenario | Strategy |
|---|---|
| Wrong hue on ONE region; rest of sprite is correct | **5** (raster PIL mask on raw PNG) |
| Whole sprite needs doctrine compliance (fresh gen) | **3** (per-slot NN on indexed canvas) |
| Doctrine-locked sprite retinted to sibling stratum | **4** (luminance-band role routing) |
| Wrong silhouette / proportions / missing character beat | re-roll |

**Distinct from 3/4:** Strategy 5 runs a PIL/numpy pixel loop on the **raw (non-indexed) PNG**,
targeting pixels by hue condition rather than palette slot — no quantize step. Cost: zero
PixelLab gens, <1 s. **Caveat:** if the off-hue region shares a channel ratio with a correct
neighbor (e.g. cool stone AND cool water both fire `b > r+12`), tighten the threshold or add a
spatial (bounding-rect) mask, and always verify the mask visually as an alpha overlay first.

---

## Doctrine-hex-in-prompt — partial success, area-dependent reliability

PixelLab `create_character` **partially honors hex codes embedded in the description**, but
with character-area-specific reliability. Validated 2026-05-17 on NPC Bounty-poster with prompt
`"robed scribe NPC in dark brown #4A3F2E robes, parchment scroll #C9C2B2 in one hand, warm tan
#A0856B skin tone visible inside hood, ..."`:

| Hex requested | PixelLab produced | Match quality |
|---|---|---|
| `#A0856B` skin tone | `#AF8266` | **EXCELLENT** — ~5/channel distance, near-exact |
| `#4A3F2E` cloth/robe | `#422D2B` | **PARTIAL** — got dark brown hue but warmer/redder shade than requested |
| `#C9C2B2` parchment scroll | (not in quantized palette) | **MISSING** — small accent either ignored by PixelLab or merged into surrounding pixels by quantize |

**Operational guidance:**

- **Skin/face hex tokens land reliably.** PixelLab's training likely has strong "skin tone"
  semantic anchoring. Include doctrine skin hex in the prompt — typically arrives within
  perceptual nearest-neighbor distance of doctrine.
- **Dominant body-color hex tokens land in the right hue family, but specific shade may drift.**
  The doctrine intent (e.g. "warm brown robe") survives, but the specific RGB triple may be
  off by 10-20/channel. Acceptable for raw-ship; if exact doctrine compliance matters, still
  pipe through pixel-mcp doctrine-lock.
- **Small-accent hex tokens (scrolls, gems, weapon edges) are unreliable.** Either PixelLab
  doesn't render them strongly enough OR the small pixel count gets merged into surrounding
  slots by `quantize_palette`. Don't expect accent hexes to survive.

**Recommended hybrid: doctrine hexes IN prompt for skin + body, ship raw for accents.** This
gives:
1. PixelLab generates with closer-to-doctrine starting palette (less post-process drift)
2. No `quantize_palette` + `set_palette` step needed for most characters
3. Per-character accents that matter (e.g. red eye-glow) handled via separate
   `create_character_state` variant or manual paint

This is NOT a replacement for the pixel-mcp doctrine-lock pipeline — it's an upstream
mitigation that reduces how often the lock step is needed.

---

## Template animations can flip character facing direction mid-cycle

PixelLab template animations can produce frames where the character's **facing direction
inverts within a single 4-frame walk cycle** — e.g. frame 0 faces forward (south), frame 1
faces backward (north), frame 2 forward, frame 3 backward. The walk-in-place pose oscillates
between front-of-head and back-of-head views instead of maintaining a consistent facing while
the legs animate.

Validated 2026-05-17 on Player `walking-4-frames` south: 4 frames extracted from ZIP,
inspected pixel-by-pixel — frames 0 and 2 showed the player's face clearly; frames 1 and 3
showed only the back of the head (north-facing pose). Sponsor reported the in-viewer
animation looked like the player "flips from back to front of the head" repeatedly. Confirmed
visually by reading each PNG.

**Why this happens (best guess):** PixelLab's template-to-character interpolation occasionally
samples a pose from a different rotation when filling in animation frames, especially when the
template's keypoint motion sweeps across the character's central axis. The "low top-down" view
makes south/north pairs visually similar at the head-only zoom level — the model loses track
of which side is "front".

**Detection:** AFTER downloading the animation ZIP, inspect each `frame_NNN.png` per
direction. If consecutive frames show inconsistent facing (face visible / face hidden /
face visible / face hidden), the cycle is broken. Cannot detect from `get_character`
metadata — frame count looks correct; only pixel inspection reveals the issue.

**Fixes (in order of cost):**

1. **Re-roll the broken direction with a different template** — `animate_character(...,
   template_animation_id="walking-8-frames", directions=["south"])` is 1 gen. Try
   `walking-8-frames`, then `walking`, then `walking-2-frames`, then `scary-walk` until you
   get a stationary-facing walk cycle.
2. **Use only the frames with correct facing** — if frames 0 and 2 are good, ship a 2-frame
   walk for that direction (drop frames 1 and 3). Visually weaker but free.
3. **Manual frame edit in Aseprite** — copy the correct-facing frame over the wrong-facing
   one. Tedious; only viable for 1-2 broken frames per character.
4. **Full character re-roll** — last resort if multiple templates flip on the same character.

**Operational note:** the broken-cycle frames are NOT visible from `get_character` metadata
(which only reports frame counts). Always inspect animation frames before shipping; the cost
of a 1-direction re-roll is much lower than shipping a broken-cycle sprite into the game.

**Hand-object continuity is NOT preserved across animation frames.**

Validated 2026-05-17 on Player south walk (`walking` template): the sword (described in the
character prompt as "holding short sword in right hand") visibly **swaps between right and
left hand** across consecutive walk frames. The mannequin template treats hands symmetrically
during animation interpolation; held-item-in-specific-hand is not a constraint the template
engine respects.

**Affects:** held weapons (swords, bows, hammers), held props (scrolls, books, lanterns), and
any character-prompt detail tied to a specific arm/hand.

**Detection:** post-download per-frame inspection. The static rotation PNGs render the prompt's
hand-assignment correctly; the animation frames lose it.

**Workarounds (all imperfect):**

- **Accept it** — at pixel scale, small held items (1-2 px) may not read as a hand-swap to
  players. Try in-game before committing to a fix.
- **Manual frame edit** — paint-over in Aseprite to keep the item in the correct hand
  consistently. Tedious; scales linearly with frame count.
- **No-weapon character + separate weapon layer** — generate the character without the weapon,
  add the weapon as a separate Aseprite sprite layer positioned per-direction. More authoring
  work but solves the swap permanently.
- **Different template choice** — some templates (e.g. those that don't swing the arms
  symmetrically) may preserve hand-object position better. Trial-and-error.

**Don't trust the static rotation as proof of animation quality.** A character whose idle PNG
shows "sword in right hand" will still have the sword swap during walk; the rotation and
animation streams are generated independently.

---

**Multi-template failure pattern — when 2+ templates fail on the same character/direction:**

Validated 2026-05-17 on Player south: `walking-4-frames` flipped facing direction (back/front
alternation); `walking-8-frames` produced a limp/wonky gait. **Different templates can fail in
different ways on the same character/direction pair** — suggests the character's static pose
itself is hard for PixelLab's template engine to interpret cleanly, not just a template-choice
issue.

**Diagnostic heuristic:** if 2 templates fail on the same direction, try ONE more template
from a different family (e.g. `crouched-walking` after `walking-4-frames` + `walking-8-frames`
fail). If the 3rd also fails, the cause is upstream (character-pose-specific). Stop burning
gens on retries; pick a workaround:

- **Direction borrowing:** use a working diagonal's animation cycle for the failing cardinal
  direction (e.g. ship `south-east` walk frames as `south` walk — character appears slightly
  angled but motion is clean).
- **Idle as walk:** use the static idle pose for the failing direction's walk too — character
  appears stationary while moving. Worst aesthetic but ships immediately.
- **Manual frame edit:** copy a good frame over the bad one in Aseprite. Tedious; only viable
  for 1-2 frames.

Document the workaround in the character's commit message so future iteration knows the
direction is using a substitute, not a true walking-template render.

---

**Per-direction template variance — single template, different motion across directions (PR #291 B3 finding, 2026-05-21):**

Same template can produce **different motion semantics across directions**, not just visual quality differences. The `surprise-uppercut` template on the eye-variant boss (`80a555b9-a2cc-4b81-b66b-f9de61415e4c`) generated 8 directions × 7 frames each on 2026-05-17. The drop-in into `Stratum1Boss.tres` as the `slam` animation appeared correct (frame paths verified, PNG bytes verified as the template output), but **the SOUTH rotation produced a body-swaying side-strike** rather than the centered overhead uppercut the template name implies.

**Diagnostic:** per-frame center-of-mass analysis on `slam/south/*.png` shows 15-pixel sideways body sway across the 7 frames — visually reads as a sideways-stepping strike, not an overhead uppercut. Other directions' frames may differ.

**Why this matters:** if you select a template by its NAME ("surprise-uppercut" reads as "overhead uppercut"), you may get motion that matches the name in some directions but not others. Always inspect ALL 8 directions before declaring the animation correct. The PixelLab template engine's interpretation of "uppercut" is rotation-dependent in ways the docs don't surface.

**Workaround:** for character beats with strict per-direction motion requirements (combat slam, dash, charge), try multiple templates AND verify each direction independently. If only some directions read correctly, try direction borrowing (cardinal from diagonal) per the multi-template-failure pattern above. If no template family produces all-correct directions, consider a custom `action_description` call (more expensive, more controllable).

**Selection heuristic for action animations:** prefer templates with the most descriptive motion verbs (`overhead-strike`, `two-handed-slam`) over compound-action templates (`surprise-uppercut` which combines surprise reaction + uppercut motion — the surprise reaction may dominate in some directions). The PR #291 B3 follow-up ticket `86c9x8tc9` is re-rolling slam with a different template choice (likely custom `action_description="overhead two-handed weapon slam"`).

---

## Prompt engineering — PixelLab interprets constraints literally

PixelLab `create_character` weights negative-shaped constraints (e.g. "obscuring", "hidden",
"covered") more heavily than the positive sub-clauses they qualify. Validated 2026-05-17 on
S1 Grunt v1:

- **Prompt:** `"...deep cowl hood completely obscuring face except glowing red eyes..."`
- **Result:** face fully hidden, ZERO red pixels in the output palette. PixelLab honored
  "completely obscuring face" and dropped the "except glowing red eyes" sub-clause.
- **Re-prompt:** `"...two bright glowing red eyes piercing through hood shadow, dark fantasy
  enemy, menacing red eye-glow clearly visible inside the hood, tattered cloth robe..."` —
  leads with the positive feature, demotes the obscuring-hood constraint to a setting detail.

**Rules:**

1. **Lead with the positive feature you want preserved.** If a character beat (eye-glow, weapon,
   accent) is doctrine-critical, put it first in the description, not as a sub-clause modifier.
2. **Demote constraints to setting context.** "Inside the hood" / "in the shadow" / "beneath the
   helm" frames a feature in context without overriding it.
3. **Avoid absolutist negation words** ("completely", "entirely", "fully obscuring") near features
   you want PixelLab to render. They override sibling clauses.
4. **Verify the palette after every generation.** Pull `get_palette` after `quantize_palette` —
   if the doctrine-critical accent hex (e.g. `#D24A3C` aggro-glow) has no near match, the source
   doesn't contain it and no doctrine-lock will recover it. Re-roll or use `create_character_state`
   to add the missing beat (see below).
5. **Negative prompts do NOT reliably suppress an element — omit the triggering concept entirely,
   then add the element in post.** Validated 2026-06-06 on the S1 charger (bone-hound + "ember-coal
   in ribcage" tell). Across 3 pro gens, PixelLab kept attaching large **head/mane flames** that read
   as detached fireballs in most rotations — because the prompt contained "ember / glowing / coals".
   Phrasing the suppression as `"...no fire, no flames on the head..."` is unreliable: on a fire/ember
   concept the negation word can *reinforce* the very element (same literalism failure as the
   absolutist-negation trap in rule 3, inverted). The reliable fix was to remove **every** fire/ember/
   glow word from the description (pure `"skeletal undead dog ... bare bleached bone ... hollow eye
   sockets"`) → came back clean across all 8 directions on the first try → then add the small contained
   ribcage ember **in post** (pixel-mcp additive glow on the harvested frames). Generalizes to any
   creature whose locked tell is a glow/fire/energy element: **gen the base WITHOUT the emissive
   concept, composite the emissive in post** — far cheaper and more controllable than re-rolling for a
   contained-fire result PixelLab won't reliably produce.

---

## Fixing a single missing detail — `create_character_state`

When a generated character is close-to-right but missing one detail (eye-glow on a hooded mob,
accent color on armor, weapon in hand), `mcp__pixellab__create_character_state` applies an edit
consistently across all 4/8 stored rotations for the cost of one generation. Useful as a cheaper
alternative to full re-roll.

```python
mcp__pixellab__create_character_state(
    character_id="<existing-char-id>",
    edit_description="add two bright glowing red eyes visible inside the hood"
)
# Returns NEW character_id; keeps source identity, body type, proportions.
# Inspect siblings via list_characters / get_character on the group_id.
```

**Caveats:**

- Returns a NEW `character_id`; the source still exists. Delete the source via `delete_character`
  if the variant is canonical.
- The edit is applied "consistently across rotations" — but consistency is best-effort; verify
  every direction, especially for asymmetric features.
- Auto-waits up to 30s for the source to complete if still generating.

---

## Dispatch loops — end-of-loop bulk download is the right default

When running a multi-tick dispatch loop (e.g. queue-driven `animate_character` advancement
via away-mode ticks), the loop body can be dispatch-only (no per-completion harvest). At
end-of-loop, download each character's ZIP once. The ZIPs are **cumulative** — each character's
download at any moment contains ALL rotations + ALL animations completed so far — so one
final download per character gets the complete set.

**Why this is preferred over per-completion harvest:**

1. **PixelLab CDN persists completed gens indefinitely** — unlike PENDING entries which can
   be silently garbage-collected, COMPLETED animations stay accessible. No risk of losing
   work between checkpoints.
2. **Fewer tool calls** — 1 curl per character at end vs N curls (one per animation).
3. **Cumulative ZIPs mean intermediate downloads are redundant.** The last download supersedes
   all earlier ones.

**End-of-loop harvest protocol:**

```
once all dispatches complete and all animations show done in list_characters:
  for each character in the batch:
    curl --fail -o tmp/<char>.zip "https://api.pixellab.ai/mcp/characters/<char_id>/download"
    unzip tmp/<char>.zip -d assets/sprites/<char>/_pixellab_anims/
```

The dispatch loop itself stays simple: check in-flight done → dispatch next pending → repeat.

**When per-completion harvest IS warranted:**

- The loop might run for many hours and Sponsor wants intermediate visibility (e.g. to spot
  a bad template choice early without waiting for completion of unrelated character anims).
- The loop is interrupted by external events (auth changes, billing changes) that could
  affect later access — never observed yet but a theoretical risk.
- You need per-completion validation (palette inspect, frame-count sanity-check) to gate the
  next dispatch.

In those cases, fold a single `curl + unzip` step into the tick body after the
"in-flight done" check.

**Validated failure mode 2026-05-17 (the lesson that drove this rule):** dispatched 8 animations
across Player + Grunt + Charger over ~30 min via 3-min ticks. Each tick checked "is the
in-flight anim done? if yes, dispatch next." None of the ticks downloaded anything. When the
loop was paused, the only local artifact was the queue tracking file with `done` markers —
zero PNG frames on disk. Solution: a single batch download recovered everything (CDN persists).

---

## Animation frames are only exposed via ZIP download

The `get_character` response surfaces idle-rotation URLs (8 per direction) AND lists animations
as metadata (e.g. `"walking-4-frames (south, 4 frames)"`), but **does NOT expose individual
animation-frame URLs the way it exposes rotation URLs.** To access animation frames, download
the character ZIP and unzip.

**Workflow:**

```bash
# 1. Get the ZIP URL from get_character output (in the "📥 Download" section)
curl -fsSL -o character.zip "https://api.pixellab.ai/mcp/characters/<char_id>/download"

# 2. Unzip
unzip character.zip -d extracted/

# 3. Animation frames live at:
#    extracted/<character_name>/animations/animating-<uuid>/<direction>/frame_<NNN>.png
#    Frames are sequentially numbered (frame_000.png, frame_001.png, ...) with zero-padding.
```

**Validated 2026-05-17** on Player walking-4-frames test: south-direction 4-frame walk cycle
extracted cleanly via ZIP. Idle rotation PNGs are also bundled in the ZIP at
`<character_name>/rotations/<direction>.png` (duplicates of the URL-accessible ones).

**Caveats:**

- The animation directory naming is **inconsistent across PixelLab versions** — observed in
  the same ZIP 2026-05-17: some animations stored under `animating-<uuid>/` (no template name,
  just UUID); others under `<template_name>_<animation_name>-<uuid>/` (semi-readable). Cannot
  rely on parsing folder names for semantic mapping back to game-state animations.
- **Always consult `metadata.json` at the ZIP root** for the authoritative
  `folder_name → animation_name → template_animation_id` mapping. The `animation_name`
  parameter passed at `animate_character` dispatch time is what survives — use it as the
  semantic anchor when renaming folders for game use.
- HTTP 423 returned if any animation is still pending — wait for all to complete before
  downloading.
- Always use `curl --fail` (per the docs warning) — without it, curl saves the error JSON
  as if it were the ZIP.

---

## PixelLab MCP PNG download URLs require `curl -L` (redirect not followed by default)

Tileset and map-object tools return PNG download URLs of the form
`https://api.pixellab.ai/mcp/tilesets/<id>/image` and
`https://api.pixellab.ai/mcp/map-objects/<id>/download`. These issue an HTTP redirect to the
actual file location. Plain `curl -s -o out.png <url>` does NOT follow it and **silently writes
a 0-byte file** — curl exits 0, the file exists, and the failure only surfaces downstream
(PIL: `UnidentifiedImageError: cannot identify image file`).

```bash
# WRONG — silent 0-byte file:
curl -s -o tiles.png "https://api.pixellab.ai/mcp/tilesets/<id>/image"

# CORRECT — -L (follow redirect) is the load-bearing flag; -f fails loud on HTTP errors:
curl -sS -L -f -o tiles.png "https://api.pixellab.ai/mcp/tilesets/<id>/image"
```

The character-ZIP examples elsewhere in this doc already use `-fsSL` (which includes `-L`) and
are unaffected. The trap fires when composing a fresh curl for the tileset/map-object PNG
endpoints. Validated 2026-06-12 (ClickUp `86ca7yt5u`): first tileset download wrote 0 bytes;
adding `-L` fixed it on the immediate retry. Default to `curl -sS -L -f` for every
`mcp__pixellab__*` image URL.

---

## Folder-rename + reverse-map — PixelLab UUID exports → game-side semantic names (M3W-1, PR #271)

PixelLab ZIPs unpack with animation dirs named `animations/animating-<uuid>/` or `<template>_<name>-<uuid>/` — neither shape is grep-friendly from game-side code, and the UUID slug ties the game scene to a PixelLab-internal identifier. PR #271 (PracticeDummy, M3W-1 foundation) established the rename + reverse-map convention every downstream M3W character inherits.

**Pattern:**

1. Unzip per the workflow above into `assets/sprites/<character>/_pixellab_anims/`.
2. Rename each `animating-<uuid>/` (or `<template>_<name>-<uuid>/`) dir to its semantic state name — `hit/`, `die/`, `idle/`, `walk/`, etc. The semantic name is what `<Character>.tres` references in `SpriteFrames` anim-keys (which append `_<dir>` per `.claude/docs/combat-architecture.md §"M3W-1 realized implementation"`).
3. Commit `assets/sprites/<character>/_pixellab_anims/anim-folder-map.md` recording the original-UUID → semantic-name mapping. This is the **reverse-map** — auditors hitting a `<Character>.tres` anim-key can trace back to the originating PixelLab dispatch.
4. **`metadata.json` stays byte-identical to the ZIP root** — it is the upstream-API authoritative source for `animation_name → template_animation_id`. The rename does NOT touch it. The pair (rename + `anim-folder-map.md` + unchanged `metadata.json`) is non-redundant: `metadata.json` is the upstream truth, `anim-folder-map.md` is the local rename truth, the renamed dirs are the PR-time legible shape.

**`anim-folder-map.md` schema:**

```markdown
# <Character> PixelLab anim folder map

Original PixelLab character_id: <char_id>
Generated: YYYY-MM-DD

| Original folder | Semantic name | template | animation_name | direction |
|---|---|---|---|---|
| `taking_a_punch-1f45c4b5` | `hit` | taking-a-punch | hit | (8 dirs) |
| `falling_backward-26fe5a45` | `die` | falling-back-death | die | (8 dirs) |
| ... | ... | ... | ... | ... |
```

Pull the `template` / `animation_name` columns from the ZIP's root `metadata.json` (authoritative — see the parent section's caveat about inconsistent folder naming across PixelLab versions).

**Operational note — when to rename:**

- **Before** building the `<Character>.tres` SpriteFrames resource. SpriteFrames references frame paths by string; renaming after the `.tres` is wired forces a second pass updating every anim-key.
- **After** any per-frame inspection / facing-direction validation (per the "Template animations can flip character facing direction mid-cycle" caveat above). Rename only directions that passed inspection; flag failing directions in the map with a `STATUS: rerolled` note so the audit trail captures the reroll history.

This is the **PixelLab side** of the M3W-1 SpriteFrames-layout contract documented in `.claude/docs/combat-architecture.md §"M3W-1 realized implementation"`. The game-side rule is "`<Character>.tres` lives at `assets/sprites/<character>/<Character>.tres`, anim-keys `<state>_<dir>`"; the rename + reverse-map is how the PixelLab exports get from raw-ZIP shape to that contract.

---

## Operational notes from M3 batch run (2026-05-17)

Empirical observations from queueing 7 characters in parallel after Tier 2 upgrade:

### PixelLab generation failures can be reproducible (not just transient)

Distinct from silent garbage collection: some `create_character` jobs return an explicit
`failed` status via `get_character`, with the error message "Generation failed. Please try
again." These failures can be **deterministic** — the same prompt structure may fail on every
retry, suggesting a specific token or combination triggers a backend rejection (content filter,
unknown model token, or some other reproducible condition).

**Validated 2026-05-17:** NPC Bounty-poster failed 2/2 retries with similar-but-not-identical
prompts (one plain, one with embedded doctrine hexes). Both shared the descriptive structure
`"friendly lean cloaked lore-keeper NPC with deep drawn hood, scholarly demeanor, dark fantasy
town bounty-poster..."`. Other NPCs with similar shape (Vendor, Anvil-keeper, both also
"friendly + cloaked/aproned + holding item + standing pose") generated cleanly first try.
Difference candidates: `"lore-keeper"`, `"bounty-poster"`, `"scholarly"`, or some combination.

**Diagnostic strategy:**

1. If a `create_character` returns `failed`, retry ONCE (handles true transient failures).
2. If the 2nd attempt also returns `failed`, **stop retrying with the same prompt** — assume
   reproducible failure trigger. Each retry costs 1 generation and adds zero information.
3. Simplify the prompt: drop domain-specific jargon (`"lore-keeper"`, `"bounty-poster"`) in
   favor of plain descriptors (`"robed scribe with parchment scroll"`).
4. Alternative: use `create_character_state` from a working sibling character (e.g. base a
   Bounty-poster on a working Vendor with `edit_description="change to deeper hood, holding
   parchment scroll, more scholarly pose"`).

**Don't confuse failure modes:**

- Silent garbage collection (entry vanishes from `list_characters`) ≠ explicit failure (entry
  shows `failed` status with error message). Different recovery paths.

---

### PixelLab silently garbage-collects stuck queue entries

If a queued `create_character` job sits in `pending` status for ≳30 min without ever moving to
`processing`, PixelLab may **silently drop it** — no error returned, no completion notification,
the character just vanishes from `list_characters` on the next poll. Validated 2026-05-17 with
4 characters (Player + 3 hub NPCs) queued in a batch that included variant edits jumping ahead;
the 4 base-character entries stayed pending for >30 min then disappeared between polls.

**Suspected trigger:** queue position deprioritization combined with a backend timeout. The
disappearance correlated with the free→Tier 2 subscription transition during the stuck window,
suggesting the upgrade may have triggered a queue-state migration that lost in-flight pending
entries.

**Rule:** if a `pending` entry has not moved to `processing` after ~15 min of polling, assume
it will vanish. Do NOT wait indefinitely. Either re-queue defensively or delete + re-queue
explicitly.

**Re-queue pattern:** when silent-dropped entries are detected (compare current `list_characters`
output against the originally-queued ID set), re-call `create_character` with the same
parameters. Cost: 1 gen per re-queue, but no recovery of the lost queue position — the new
entry goes to the queue tail.

---

### Tier-based concurrent job-slot limit (per-call atomicity)

PixelLab enforces a **per-tier concurrent job-slot ceiling** and **rejects whole animation
calls atomically** if there aren't enough slots free for ALL its directions. Validated 2026-05-17:

| Tier | Concurrent job slots |
|---|---|
| Tier 1 / Pixel Apprentice ($12/mo, 2000 gens) | **8** |
| Tier 2 / Pixel Artisan ($24/mo, 5000 gens) | **10** ← ACTIVE since 2026-05-29 |
| Tier 3 | 20 |

**Active account: Tier 2 / Pixel Artisan as of 2026-05-29** (was Tier 1 through 2026-05-29 — see memory `[[pixellab-mcp-installed]]`). 5000 gens/mo, ≤400×400px images.

**Atomicity:** an 8-direction `animate_character` call needs 8 free slots. If only 7 are free,
the call **rejects entirely** with "Insufficient job slots for complete animation" — no partial
queueing. Same applies to `create_character` (8 directions per char).

**Consequence (still holds on Tier 2):** at most **one 8-direction animation can be queued at a time** —
10 slots cannot fit two 8-dir jobs (8+8=16 > 10), so the serial-by-animation rule is unchanged by the
Tier 2 upgrade. What Tier 2 buys: up to 10-way parallelism for **single-direction** dispatch (strategy 2),
priority-queue turnaround, and 400px boss-scale headroom. You still cannot batch-dispatch a multi-animation
plan with parallel full `animate_character` calls.

**Strategies:**

1. **Serial-by-animation:** dispatch one animate call, wait ~2-4 min for the 8 jobs to clear,
   dispatch the next. ~3 min × N anims wall time.
2. **Single-direction dispatch loop:** dispatch one direction at a time (`directions=["south"]`,
   then `["east"]`, etc.). Uses 1 slot per call → up to 8 calls in flight. Faster wall time
   than full-anim-at-a-time, but ~8× the tool calls.
3. **Upgrade to Tier 2 or 3** if batch throughput matters more than monthly cost.

Validated 2026-05-17 by attempted 32-anim parallel dispatch: only the first 7-direction call
(Player walking-4-frames, south was pre-existing) succeeded; the remaining 31 ALL rejected.

---

### PixelLab queue limit — ~2 characters processing simultaneously

Batch-queueing 7 `create_character` calls in a single tool round did NOT result in 7 parallel
processing. PixelLab serialized them: 2 active + 5 queued, then 2 active + 3 queued, etc.

**Wall-time estimate:** `~5 min × ceil(N / 2)` for N parallel queues. For 7 chars ≈ 17-20 min
to last completion. Plan workflow around this — don't block waiting for all to complete; start
processing the early-finishers' doctrine-lock pipelines while later ones bake.

**Optimization:** if you have a known order of priority, queue the highest-priority chars
first; they hit PixelLab's queue head and complete first.

### Prompt-literalism — first noun dominates the silhouette

Reinforcement of the rule documented above. The Boss prompt
`"hulking armored warden in heavy iron plate, deep red surcoat..."` produced **iron-dominant
armor** with the surcoat reduced to a small accent. PixelLab anchored on "iron plate" as the
body, treating "deep red surcoat" as a detail layer.

**Pattern across M3 chars:**

| Character | Prompt phrasing | Result |
|---|---|---|
| Grunt v1 | `"deep cowl hood completely obscuring face except glowing red eyes"` | Face fully hidden, no eyes |
| Grunt v2 | `"two bright glowing red eyes piercing through hood shadow"` (eyes-first) | Eyes prominent ✓ |
| Boss v1 | `"hulking armored warden in heavy iron plate, deep red surcoat"` | Iron dominates, surcoat lost |

**Rule applied:** lead with the dominant intent-feature. For body-color dominance: `"deep red
warden in iron-plated armor"` (red leads); for armor dominance: `"iron-plated warden with deep
red surcoat"` (iron leads + accept the surcoat as accent).

### `create_character_state` dramatically simplifies palette

The variant tool produces a **far simpler palette** than the original `create_character` output.
Empirical from Shooter v1 vs v2 (eye-variant): v1 had 38 distinct colors in the raw, quantized
to 17 slots with red below the quantize floor. v2 (variant adding eyes) had only **8 distinct
colors** in the raw, quantized cleanly to 8 slots, with red as a prominent slot.

**Consequence:** doctrine-lock is EASIER on variants (fewer slots to map, clearer character
beats), but you LOSE the intermediate tonal variation that the original generation had.
Variants are visually flatter / more cartoony / less subtly shaded.

**When to use variant vs re-roll:**
- Variant (`create_character_state`): when you want to add/fix a specific feature on a
  silhouette you already like. Trades tonal subtlety for guaranteed feature preservation.
- Full re-roll (`create_character`): when you want fresh tonal variation or significant
  silhouette changes. Risks losing the silhouette quality you had.

### set_palette is idempotent on a stable indexed canvas

After `quantize_palette` converts the sprite to indexed mode, the **pixel slot indices stay
stable** until the sprite is re-quantized or re-imported. This means `set_palette` can be called
**multiple times** with different doctrine assignments to iterate on the doctrine mapping
without re-importing or re-quantizing.

**Iteration pattern (validated 2026-05-17 on Shooter cloth-darkness fix):**

```
1. quantize_palette                       # creates indexed slots
2. set_palette + export                   # try mapping v1
3. visually verify                        # iterate
4. set_palette + export                   # try mapping v2 with darker cloth
5. visually verify                        # ship when right
```

Each `set_palette` + `export_sprite` cycle costs only a few hundred ms of pixel-mcp time and
zero PixelLab generations. **Use this freely** during doctrine-tuning rather than burning
generations on re-rolls when the silhouette is fine and only the color mapping needs work.

### Nearest-neighbor breaks doctrine-ramp intent for mid-tones — bias toward dark

Pure Euclidean RGB distance is **silhouette-blind**: it picks the perceptually closest doctrine
color regardless of what role that color plays in the doctrine ramp. For mid-tones (mid-browns,
mid-greys), this often picks the doctrine **highlight** color over the doctrine **base**
because highlights and mid-tones are perceptually closer than bases.

**Failure pattern (Shooter v1, 2026-05-17):**
- PixelLab cloak mid-tone: `#8C593D` (140, 89, 61)
- Nearest doctrine by Euclidean: `#7A6A4F` cloth highlight (d²=937)
- Doctrine ramp intent: `#5A4738` cloth base for the body color
- Result: cloak too light, off-doctrine despite "doctrine compliance"

**Rule — bias mid-tones toward base/shadow when character should read DARK:**

When the character's intent is dark/menacing (most S1 hostile mobs), consciously override the
Euclidean nearest-neighbor for mid-tones and shadows toward the base/shadow side of the
doctrine ramp, not the highlight side. Reserve the highlight slot for the actual lightest
non-skin region.

**Worked example for cloth-on-cloth doctrine on S1:**

| Source slot characteristic | Use doctrine | NOT |
|---|---|---|
| Cloak body / dominant fill | `#5A4738` cloth base | `#7A6A4F` cloth highlight |
| Cloak lit / mid highlight | `#5C4F38` cloth lit | `#9A7A4E` trim |
| Cloak shadow / under-fold | `#4A3F2E` cloth shadow | `#2C261C` deep |
| Cloak deepest shadow | `#2C261C` deep shadow | `#1B1A1F` darkest |
| Pure outline / hole | `#1B1A1F` darkest | (don't lift to shadow) |

The cleanest implementation: run nearest-neighbor as a starting point, then apply a **post-hoc
bias-darker pass** for any source slot whose Euclidean winner was a doctrine `highlight` or
`lit` color but whose source RGB is within the doctrine `base` color's distance range. Swap
toward base.

### Sub-2-pixel character beats may not survive quantize

The Shooter trial revealed a new failure mode distinct from prompt-literalism: PixelLab DID
render a small red eye-glow inside the skull sockets, but at 1-2 pixels per direction it was
too sparse to register as a distinct cluster in `quantize_palette` (kmeans target_colors=16).
Result: no red slot in the quantized palette; doctrine-lock could not preserve the beat
because the source had effectively erased it through quantization.

**Diagnostic:** after `quantize_palette`, scan the returned palette for the expected
character-beat hex family (red for aggro-glow, gold for trim, etc.). If absent and you believe
the raw had the beat: verify by reading the raw PNG bytes pre-quantize (or visually
inspecting the raw at native resolution).

**Fixes (in order of preference):**

1. **Higher target_colors:** re-quantize with `target_colors=24` or `32` to give small accents
   their own slot. Costs 0 generations; only pixel-mcp time.
2. **Manual paint:** `draw_rectangle 1×1` at the known character-beat location with the
   doctrine accent hex. Costs 0 gens; requires knowing pixel coords per direction (use
   `get_pixels` to locate the right region first).
3. **Re-roll with stronger character-beat emphasis:** apply prompt-literalism rule + brighter
   accent words. Costs 1 gen per re-roll.

The Shooter trial chose option 1 (re-quantize) → option 2 (manual paint) as the cheap path; full
re-roll reserved if both fail.

---

## Doctrine-lock is per-character — check the doctrine-exemption policy before defaulting

**Not every character gets doctrine-locked.** Some characters are designated cross-stratum
constants and ship with their PixelLab-natural palette directly (no `quantize_palette` → doctrine
remap pipeline). Default-pipelining EVERY character through doctrine-lock is wrong and will lose
intended character beats that distinguish doctrine-exempt characters from stratum-themed mobs.

**Validated 2026-05-17 on Player:** my default pipeline doctrine-locked the Player along with
the rest of the M3 roster. Sponsor caught it — the Player's PixelLab-natural purple/blue palette
(blue eyes, purple-grey cloth) got mapped to S1 doctrine browns and the eye-blue specifically
vanished. The Player is **explicitly doctrine-exempt** per
`team/uma-ux/palette-stratum-2.md` §5 sprite-reuse table line 190:

> "Player ... **NO CHANGE** — cross-stratum constant per `palette.md`. The player is not
> retinted per stratum. ... Player flame is the through-line; retinting the player would break
> the diegetic logic."

**Rule — before processing any character through the doctrine-lock pipeline:**

1. Check `team/uma-ux/palette-stratum-2.md` §5 sprite-reuse table (or equivalent S3+ docs) for
   the character's row.
2. If the row says "NO CHANGE" or "doctrine-exempt" or "cross-stratum constant": **skip the
   doctrine-lock pipeline entirely.** Ship the PixelLab raw south (or a minimal-edit version) as
   the canonical `idle_s.png`.
3. If the row says "RETINT OK" or "NEW AUTHORING" or has stratum-specific palette hexes:
   doctrine-lock applies; use the per-stratum palette per the table's hex citations.

**Known doctrine-exempt characters (Phase 1, expand as more land):**

- **Player** — cross-stratum constant; ship PixelLab raw directly.

**Known doctrine-locked characters (S1):**

- Grunt, Charger, Shooter, Stratum1Boss, PracticeDummy — all use S1 doctrine palette
  (`#5A4738` cloth base, `#A0856B` skin, `#D24A3C` aggro eye-glow, plus character-specific
  accents like Shooter's bone-white `#C9C2B2` and Boss's Warden red `#7A1F29`).

- Stoker (S2 retint of Grunt silhouette) — per `palette-stratum-2.md §5` line 191; uses S2
  mob ramp (`#7A1F12` heat-corroded smock, `#7E5A40` sun-scorched skin) but shares Grunt
  silhouette via palette swap. **Note:** the art-pass brief and the S2 palette doc disagree
  on whether Stoker needs new authoring or retint suffices — this is currently flagged for
  Priya/Uma resolution.

**Hub-town NPCs** (Vendor, Anvil-keeper, Bounty-poster): no explicit doctrine-exemption stated;
default to doctrine-lock with NPC-appropriate palette (warm bronze + parchment hood per the
art-pass brief). Validated 2026-05-17 — Sponsor approved Vendor + Anvil-keeper doctrine-locked
output.

---

## Cost model — credit consumption

PixelLab charges credits per generation, not per tool call:

| Operation | Approx. cost |
|---|---|
| `create_character` (standard mode) | 1 generation |
| `create_character` (pro mode) | 20–40 generations |
| `animate_character` (template, 1 direction) | ~1 generation |
| `animate_character` (template, full 8-direction set) | ~8 generations |
| `animate_character` (custom action_description, 1 direction) | 20–40 generations |
| `animate_character` (custom, full 8-direction set) | 60–300+ generations |

**Plan-tier context (as of 2026-05-17):** Sponsor is on **Tier 1 ($12/mo)** with a
**2000-generation monthly allowance** — confirmed and active after the Charger + Grunt
free-trial validation passed. **Tier 2 (5000 gens/month) upgrade is available** if usage
approaches the limit; treat 2000 as soft cap and 5000 as ceiling for planning. M3 art-pass
roster (9 characters × idle + 3 template animations) ≈ 225 generations, fitting comfortably
in one Tier 1 month with ~10× headroom for re-rolls.

**Cost calibration (validated 2026-05-17 via single-direction Player walking-4-frames test):**
template `animate_character` cost confirmed at **1 generation per direction**. Dashboard went
47 → 48 for a single south-direction 4-frame walk cycle. The per-frame count does NOT multiply
the cost.

**However: real-world session burn can run ~2.5× higher than naive (standard_create × N_chars)
accounting** due to non-character-creation cost sources:

- **`create_character_state` variants may be billed per-direction (8 each, not 1).** The docs
  describe it as a single "edit", but empirical burn suggests per-direction billing similar to
  template animation.
- **Silently-GC'd queued entries appear to still consume credits** even though they produce no
  usable output (see "PixelLab silently garbage-collects" section below).
- **Explicit-failure entries also bill** — the failure-charge applies regardless of whether
  pixels were returned.
- **Re-queue retries add full cost** of a fresh create_character call.

**When tracking against budget:** the per-operation table is accurate IF every operation
succeeds first try AND you avoid variants. Real sessions with re-rolls, failures, and variants
will run higher. Verify against the PixelLab dashboard rather than trusting in-session
arithmetic; multiply naive estimates by ~1.5-2× as a safety factor.

**Rules for credit-conserving sessions:**
- Standard `create_character` by default — do NOT trigger pro mode (20-40 gens) without
  explicit Sponsor approval; pro is for hero / boss / one-off detail work, not roster fill.
- Prefer template animations to custom; custom animations cost up to 37× more per direction
  and burn the monthly budget fast.
- Get Sponsor confirmation before any single call > 40 generations (pro mode, custom 8-dir
  animations, etc.).
- Tier 2 budget is generous but resets monthly — track approximate burn against the
  month-start baseline; flag if approaching 1500+ before month-end.

---

## `import_image` parameter trap — `image_path` not `file_path`

`mcp__pixel-mcp__import_image` takes the parameter **`image_path`** for the source PNG path.
Calling with `file_path` produces a schema-validation error:

```
MCP error -32602: invalid params: validating "arguments": validating root:
unexpected additional properties ["file_path"]
```

This is non-obvious because some pixel-mcp tools use `sprite_path` or `file_path` for path
parameters; `import_image` is the outlier.

```python
# Broken (schema error):
import_image(sprite_path="...", file_path="C:/path/source.png")

# Correct:
import_image(sprite_path="...", image_path="C:/path/source.png",
             layer_name="...", frame_number=1)
```

---

## `create_character` mode ladder + animation job-slot math (validated 2026-06-04, player-monk regen)

**Mode ladder — concept cheap, production v3.** `create_character` `mode` param:
- `standard` (1 gen, respects `outline`/`shading`/`detail`/`view`, 4 or 8 dir) — use for **concept exploration** (gen 3 identity concepts at `n_directions=4`, let Sponsor pick one). Cheapest.
- `v3` (2-9 gens, **always 8 dir**, highest quality; **ignores `shading`/`proportions`**, `outline`/`detail` soft; **HUMANOID-ONLY** — rejects `body_type=quadruped` with `"Use mode='standard' or mode='pro' for quadrupeds"`, verified 2026-06-05) — production rig for **humanoids** once the concept is locked. Workflow: cheap `standard` concepts → Sponsor picks → re-gen winner in `v3`.
- `pro` (20-40 gens, reference-based, ignores all style params, always 8 dir) — production tier for **quadrupeds** (v3 is unavailable for them — e.g. S1 charger bone-hound) AND boss-tier.
- **Sponsor quality floor (2026-06-05): any production-ready graphic ALWAYS uses the highest-quality mode for its body type — `v3` for humanoids, `pro` for quadrupeds. `standard` mode is a throwaway concept-proof ONLY (silhouette/placement check), never shipped as installed art.** The cheap-concept→confirm→production-regen workflow stays; the production regen must be the max mode.
- **Drift warning:** `v3`/`pro` re-interpret the description and will *embellish* (a "humble monk" v3'd into an armored bearded ranger). To hold a locked look, write HARD negatives ("NO armor, NO beard, ONLY a plain robe") — the v3 still honors the description text, just not the soft style knobs.

**Canvas size by mode (the size=char-height trap, concrete data):** `size=48` → `standard` yields **68×68** canvas; **`v3` yields 92×92**. Always confirm the actual canvas from `get_character` and match the existing roster rig before installing (don't assume from `size`).

**Animations are SERIAL on Tier 2.** Job-slot cap = **10**; each `animate_character` (template mode, all directions) = **8 jobs** (1/direction). So only ONE animation runs at a time — a 2nd `animate_character` errors `need 8 job slots but only N available`. Fire the animation set **one at a time**, polling `get_character` until `pending jobs` is empty (or download the rig ZIP with `curl --fail` — it 423s until all jobs clear) before firing the next. Budget ~3-5 min/animation × N animations, serial.

**Heavy-load failures + single-direction re-fire (split-folder gotcha).** Under PixelLab "heavy load," individual direction-jobs can FAIL (`Generation failed due to heavy load`) or stall (one direction at ~35-min ETA while siblings finish in seconds). Re-fire just the failed direction with `directions: ["north-east"]` (1 job) — BUT this creates a **SECOND animation folder** for that anim in the ZIP (e.g. `taking_a_punch-04c0be52/` with 7 dirs + `taking_a_punch-56764fe0/` with only north-east). The game-side install must **merge** the re-fired direction back into the main anim's per-direction set. Flag this to the installing agent.

**Rig ZIP layout** (`curl --fail https://api.pixellab.ai/mcp/characters/<id>/download`, valid ~8h): `<CharName>/rotations/<dir>.png` (8 static directional sprites) + `<CharName>/animations/<animname>-<uuid>/<dir>/frame_NNN.png`. Idle from `breathing-idle` lands under a generic `animating-<uuid>` folder — identify by frame count (idle=4f) not folder name.

**CHECK THE TARGET MOB'S ANIM CONTRACT *BEFORE* GENERATING THE ANIM SET — and mind that quadruped templates lack `die`/`hit`.** When re-arting an EXISTING mob (frames-swap into its `.tres`), read the contract FIRST: the keys the game expects are pinned by `tests/test_<mob>_animation_wire.gd` and mirrored by the current `_pixellab_anims/<OldRig>/animations/` folder names. Generate the FULL required set, not a plausible-looking subset. Concrete miss (S1 charger bone-hound, 2026-06-06): the charger is an existing mob with contract `{walk, telegraph, atk, die}`, but the quadruped template list is only `{bark, fast-walk, idle, running-Nf, sneaking, walk-Nf}` — there is **no death or hit or telegraph template for quadrupeds**. Animating idle/walk/running/bark produced a rig MISSING `die` (had to be added afterward as a **v3 custom animation**, `action_description="collapsing and falling over dead..."`, which DOES support arbitrary actions for quadrupeds — pass explicit `directions:[all 8]` since v3 defaults to south-only). Map the rest at install (`running→telegraph`, `bark→atk`). Failing to check the contract up front cost a wasted animation cycle. (Tooling trap that hid this: the Bash tool persists cwd, and `git ls-tree origin/main` applies the cwd prefix — running it from a subdirectory silently scopes the listing to that dir and can look like "the file doesn't exist." Run repo-wide `git ls-tree -r` from the repo root or with `git -C <root>`.)

**v3 creation HOLDS 3 job slots while running — queue the walk only after status = completed
(validated 2026-06-10, iso-proof monk).** A v3 humanoid creation (`size=48`, 2 gens, 8 dirs)
holds **3 of 10** Tier-2 job slots while in progress. Queuing `animate_character` template
`"walking"` (8 directions = 8 slots) during that window fails atomically:
`need 8 job slots but only 7 available (3/10 used)`. This happens **even while `get_character`
shows the hint "animate_character can be queued now (runs after creation completes)"** — that
hint is unreliable; queue the walk only AFTER `get_character` returns `status: completed` with
rotation URLs populated. Observed wall-clock: v3 creation ~10–15 min (vs the "~3–5 min" hint);
the walk itself ~5 min (within its stated class).

**Per-direction frame URLs (alternative to the rig ZIP).** Each direction of a walk set gets
its **own animation UUID**; frames live at
`animations/<anim-uuid>/<direction>/<frame-index>.png` with frames named `0.png`–`5.png`
(6-frame walk). Build a `direction → uuid` map from the `get_character` output before
harvesting — do NOT assume one shared UUID across directions. Per-direction URL fetching is
validated; the rig ZIP (above) remains the bulk alternative.

---

## PixelLab is pixel-art-native — non-pixel-art aesthetics are not achievable (validated 2026-06-12)

PixelLab produces pixel art. Always. Style params are soft guidance; they **cannot escape the pixel-art grain** — stair-stepped edges, pixel-cluster shading, selective outlining are structural, not an artefact of a bad prompt.

**Empirical validation (2× probes, ClickUp `86ca7zkyr`):**

| Probe | char-id | Key params | Description strategy | Result |
|---|---|---|---|---|
| 1 | `dd85e045-8d32-48ce-8528-08d7f373188f` | v3, `outline="lineless"`, `detail="low detail"` | Low-poly render description ("smooth-shaded LOW-POLY 3D model, flat color facets, no outlines, no pixel dithering") | Classic pixel art — stair edges, cluster shading, selective outlines despite "lineless" |
| 2 | `68bf9445-3996-4e5f-97f0-e7f1b4b538e5` | v3, maximally aggressive prompt | "ABSOLUTELY NOT pixel art … a clean 3D render like Ico/Journey/Quaternius/Synty" | Unmistakably pixel art — identical failure mode |

**Why style params don't help:**
- `outline` / `detail` are soft guidance — they nudge pixel-art style, not the rendering model.
- `shading` and `proportions` are **ignored entirely** by v3 (already documented in the mode-ladder section above).
- Out-of-distribution prompting ("not pixel art", "smooth shading") does not suppress the mode; PixelLab's literal-interpretation behavior (see § "Prompt engineering" above) may actually reinforce the concept being negated — the same class as the absolutist-negation trap documented there.
- PixelLab's training distribution is pixel art; no prompt combination escapes it.

**Hard rule — do NOT spend generations chasing non-pixel-art aesthetics.** Stop after the FIRST probe confirms pixel-art output. Aesthetics that cannot be produced:
- Smooth low-poly render (Synty / Quaternius style)
- Vector / painterly-smooth illustration
- Gouraud / Phong shading look
- "Screenshot of a 3D game"

**Routing — when the target aesthetic is non-pixel-art:**

| Need | Route |
|---|---|
| Low-poly 3D characters (Quaternius/Kenney style) | CC0 asset packs — quaternius.com, kenney.nl, OpenGameArt.org (Synty POLYGON packs match the look but are PAID, need Sponsor auth) |
| Custom 3D model | Blender modeling via Devon/Drew |
| Text-to-3D from description | `mcp__blender__generate_hyper3d_model_via_text` (Blender MCP) |
| Text-to-3D from concept art | `mcp__blender__generate_hyper3d_model_via_images` |

**PixelLab's value in a 3D-style project:** even when the game world is 3D or low-poly, PixelLab is the right tool for:
- Pixel-art HUD / UI elements
- 2D billboard sprites used as decals, particles, or FX overlays
- **Identity design sheets** — the castaway exploration probes (`_castaway_judge/castaway_v3_south_2x.png`, `castaway_v4_south_2x.png`) were rejected as shipped sprites but kept as design reference for silhouette / proportion / palette decisions.

**Evidence trail:** ClickUp `86ca7zkyr`; judged outputs at `_castaway_judge/castaway_v3_south_2x.png` and `_castaway_judge/castaway_v4_south_2x.png`.

---

## `create_topdown_tileset` is a terrain-TRANSITION tool — NOT for a uniform crafted floor

Validated 2026-06-06 (S1 tile upgrade `86ca44p4j`, 2 passes). `create_topdown_tileset` is a **Wang/autotile generator for terrain boundaries** (grass↔water↔sand). It takes `lower_description` + `upper_description` and produces 16 corner-based tiles whose whole purpose is the *transition* between two terrains. Consequences when (mis)used for a single crafted surface like a cloister flagstone floor:

- **lower ≠ upper (even subtly):** the autotiler renders one terrain as a PATH/ISLAND over the other as a FIELD. Pass 1 (`lower="dark mortar"` / `upper="flagstone"`, transition 0.5) → beige flagstone **islands in big dark channels**. Pass 2 (`lower="sunken flagstone"` / `upper="foot-worn flagstone"`, transition 0.25) → a beige **path winding over a grey field**. Both are two-zone maps, not a continuous floor.
- **lower == upper (identical):** no terrain difference → the autotiler only ever places the "all-same" interior tile → a **flat uniform repeat** (the wallpaper failure you were trying to avoid). The tool's variation comes ONLY from corner-terrain differences, which are exactly the path/field split you don't want.

So the Wang tool gives you **path/field OR flat-repeat** — never "continuous floor, richly varied, seam-free." It is the right tool for an actual terrain edge (floor→pit, grass→stone), not for re-arting one surface.

**Addendum — the 32px resolution cap (re-confirmed 2026-06-07, S1 cobble-yard `86ca5erva`).** Even used *correctly* — a deliberate `lower="dirt"` / `upper="cobblestone"` setup so the base (all-corners-upper) tile IS a seamless single-surface cobble, with dirt only as occasional sunk-stone patches — `create_topdown_tileset` DOES tile seam-free (the Wang corner-matching works). BUT its `tile_size` is **hard-capped at 16 or 32px** (see the tool schema), and at 32px even with `detail="highly detailed"` + `shading="highly detailed shading"` the stones come out **small and uniform** (and skew green/mossy). So the Wang tool's ceiling for a floor is *seamless-but-low-res-uniform*. This is the load-bearing reason a high-detail, genuinely-varied-stone floor must be **procedural** (any resolution, seamless-by-construction via toroidal wrap, varied-radius stones) rather than any PixelLab tool — Sponsor chose procedural for the cobble-yard on exactly this quality tradeoff. (Also re-confirmed this session: `create_tiles_pro` with `outline_mode=segmentation` gives full-bleed tiles but the numbered variants *diverge in palette* — grey vs green vs dirt — and being independent square tiles they still show a grid; and `create_map_object` at ≥256px stops making a floor patch and renders a whole walled scene.)

**For a uniform crafted floor/wall surface, use a VARIANT-SET approach instead:** generate several individual seamless tile variants (`create_map_object` / `create_1_direction_object`, or pixel-mcp hand-craft for full control) — each a self-contained worn-stone tile with different crack/wear — then the game-side painter scatters them so no tile repeats in a run (matches the multi-variant-set intent in `team/uma-ux/s1-tile-rework.md` §2.2A). Mind seamlessness: object-gen does not guarantee edge-matching tiles; for a stone floor, mild edge mismatch reads as irregular grooves (acceptable), but verify tiled at game zoom. This corrects the spec's assumption that `create_topdown_tileset` would produce crafted floor/wall sets.

**Addendum — terrain QUALITY is material-dependent, even in the CORRECT (transition) role (2026-06-08, S1 ground pivot).** When finally used the right way — Wang transition sets for `?s1_assembler=1` ground blends — the tool's output quality split sharply by material:
- **Natural / organic terrains (dirt↔grass): EXCELLENT.** The dirt↔grass set produced a soft, ragged, hand-painted-looking blend (sunk-dirt path with a mossy/rooty grass bank) — **Sponsor-approved on sight.** The Wang tool is genuinely good for organic terrain edges (dirt, grass, sand, earth).
- **Man-made fine STONE (cobble): FAILS.** A dirt↔cobble set with an explicit `upper="fine small warm grey-tan cobblestones, warm tan not grey, NO moss, NO green"` + `detail/shading=highly detailed` STILL came back **green/mossy with no real stone structure** at 32px. A Strategy-5 hue-mask recolor (green→warm) only yielded a muddy **gravel mush**, not crisp cobble — the recolor fixes hue, not the missing stone geometry.
- **Practical rule:** use `create_topdown_tileset` for **organic/natural terrain blends** (the soft dirt/grass/sand edges it excels at); do NOT use it for **man-made stone surfaces** (cobble, pavers, flagstone). For a stone GROUND, the AI route that WORKS is a **high-res (256px) full-bleed `create_map_object`** ("Top-down weathered cobblestone ground, …" at 256×256 came back full-bleed-opaque + good — Sponsor-approved 2026-06-08, far better than the 32px Wang cobble); tile it seam-free via the np.roll wrap (the INSET-CROP technique above). Procedural (`gen_s1_cobble_floor.py`) is the other viable stone route. Let the Wang tool handle only the *natural* terrain transitions around the stone. (S1 yard ground: dirt+grass = Wang autotile; cobble lane = 256px `create_map_object` cobble.) The Wang grass also skews neon → mute via Strategy-5 toward the doctrine green (`#5C7044`).
- **Map-object expiry gotcha:** `create_map_object` outputs **auto-delete after 8h**. `list_objects` keeps showing the expired entry, but `get_map_object` and the `/download` URL both return "not found" / JSON-error once expired — so a good ground/prop you want to keep must be **downloaded + committed promptly, or regenerated from its prompt** (the list row's name is the only surviving record). Don't assume a listed object is still retrievable.

---

## `create_topdown_tileset` — flat-terrain calibration traps (Zone-A beach/field, 2026-06-12, ClickUp `86ca7yt5u`)

First production use in its CORRECT role (organic terrain blends — sand↔grass, dry↔wet sand)
surfaced four calibration findings beyond the material-quality rules above:

**1. `transition_size` bakes a HEIGHT LEDGE into flat blends.** At `0.5` the boundary renders
as a cliff lip with cast shadow (reads as raised grass platform over sand); at `0.25` still
slightly ledge-y. The param's own doc hints it "often affects the height difference" — treat it
as a height-step control, not a blend-width control. For flat ground↔ground blends, keep it low
(≤0.15 — *inference, untested below 0.25*) and/or add "completely flat ground, no cliff, no
ledge, no height difference" to the transition description. If you only need the interior fill
tiles (below), the transition render is irrelevant.

**2. Featureless terrain + `detail="highly detailed"` induces mechanical weave/grid
micro-structure.** Sand at "highly detailed" came back as basket-weave — the model fills the
detail budget on a featureless material with periodic structure. Validated fix (both changes
applied together, not isolated): `detail="medium detail"` + explicit description language
`"NO pattern, NO grid, NO weave, no repeating structure, organic randomness"`.

**3. Name the palette tones; adjectives under-deliver.** `"lush meadow grass, layered
multi-tone greens"` → flat saturated cartoon green (FAIL). `"dense short grass in many layered
muted green tones (olive, moss, forest green)"` → real tonal layering (PASS). Same pattern for
sand: `"muted warm palette ... tan and beige"` under-delivered vs naming `"tan, beige and
khaki"`. Rule: enumerate 2-3 specific tone names per terrain in `lower_description` /
`upper_description`; this is the terrain analogue of the character prompt-engineering rules.

**4. Purity-scan fill extraction — and the dry↔wet pair trick.** Every Wang-16 sheet contains
pure single-terrain interior tiles (all corners the same terrain). Extract them
programmatically: split the sheet into `tile_size` cells, classify each pixel into the two
terrain color-classes (a simple channel comparison suffices — e.g. green-dominant vs
tan-dominant), and take cells with purity 1.0. These are seamless per-terrain fills usable
independently of the transition. **Bonus:** a `lower="dry sand"` / `upper="wet sand"` variant
pair yields TWO usable fills of the same material from ONE generation. **Caveat:** a single
extracted 32px cell carries less tonal variation than the sheet read suggests — the Zone-A sand
fill read pale/uniform in-engine. If the fill needs more richness, prefer the 256px
`create_map_object` + inset-crop route (section above) or composite mild luminance variation
over the fill.

---

## `create_tiles_pro` is ALSO wrong for a continuous floor — it makes transparent tile-TOKENS, not full-bleed terrain

Validated 2026-06-06 (S1 tile upgrade `86ca44p4j`, same session as the `create_topdown_tileset` finding above). After the Wang tool was eliminated, `create_tiles_pro` (`tile_type="square_topdown"`, `tile_view="top-down"`, `outline_mode="segmentation"`, `tile_size=128`) looked promising — it generates **multiple tile variations in one call** (exactly the variant-set intent) and the per-tile stone craft is genuinely good (discrete cut stones, tonal variation, no outline grid in isolation). **But it is unusable as a continuous floor**, for a structural reason only visible when you check the alpha channel:

- Each generated tile is a **rounded stone-TOKEN centered on a transparent canvas — ~55% of every tile is fully transparent (alpha 0 at all four corners).** It is designed for stamping discrete tiles onto a base layer (board-game / isometric-map token style), NOT a full-bleed terrain surface.
- Tiled edge-to-edge, the transparent margins read as a **heavy black/empty grid between rounded boxes** — the exact "grid of bordered boxes / wallpaper" anti-pattern (`env-art-s1-direction.md §6.3`). Same end-symptom as the Wang tool's flat-repeat, different cause.
- The opaque cores ARE good stone; you can salvage them (crop the opaque center + edge-wrap-blend to seamless + downsample), but the result is soft/uniform and not premium.

**Net: PixelLab has NO full-bleed seamless-floor generator.** `create_topdown_tileset` = terrain-transition Wang; `create_tiles_pro` = transparent tokens; `create_map_object`/`create_1_direction_object` = transparent-background objects by definition (tool desc says so). For a CONTINUOUS crafted floor/wall the reliable path is to **AUTHOR the tile** (pixel-mcp or PIL/numpy), seamless-by-construction.

**Validated authoring recipe (the one that worked — "broken-ashlar" flagstone):** lay irregular rectangular stones in jittered offset courses (course height ~11-13 px for slabs / ~7-9 px for cobbles at a 32 px tile), 1 px mortar gap (`#5C4F38` bed + `#1A1210` shadow side), per-stone flat doctrine tone with a few worn-lighter (`#A89677`) stones, a 1 px lit lip on the top+left of each stone and a 1 px `#1A1210`/`#5C4F38` shadow on bottom+right (carved relief). **Make it seamless by wrapping stone x-positions and course heights toroidally (modulo the tile size)** — every paint op writes at `(px % S, py % S)`. Generate a small variant SET (3 base + worn-path + moss + cracked) by varying the RNG seed; the game-side painter scatters them. A toroidal-**Voronoi** stone model also tiles seamlessly but reads as angular shards/scales — the **rectangular broken-course (ashlar) model is the correct shape for cut flagstone**, Voronoi is not. Judge tiled across a 15×8 (one-screen) span at 3× zoom, not in isolation. This is the path that finally broke the `#407` wallpaper failure.

**Premium-pass refinements on top of the base recipe (two non-obvious traps, validated 2026-06-06 slab2 pass):**
- **Large-scale tonal variation must be a TOROIDAL low-freq drift, not per-stone randomness** — add `0.06*sin(2π·x/S+φx) + 0.05*cos(2π·y/S+φy)` as a brightness multiplier across the whole tile. Built from full-period sines on the tile dimension it stays seamless, and it kills the "every stone independently random → flat noise" look by giving the surface gentle light/dark regions (reads as unevenly worn stone). Per-stone random tone alone reads flat; the drift is what makes it read crafted.
- **Moss must be soft FACE-BLOBS, never groove-following** — the intuitive "paint moss along the dark mortar pixels" produces a bright-green DASHED WIREFRAME outlining every stone (a glitch read, not moss). Instead scatter 2-3 circular olive clusters (`#5C7044`, ~55% fill, with a `×0.78` darker sibling) **only over lit stone faces** (skip pixels whose RGB sum is in shadow range) — reads as organic damp creep. Same principle for any in-groove accent: grooves are structure, not a place to paint color.

---

## AI-generated tiles CAN make a continuous floor — the fix is INSET-CROP (validated 2026-06-06, Sponsor-preferred over procedural)

The procedural recipe above works, but a Sponsor may prefer the more organic/painterly look of an **AI-generated** `create_map_object` floor tile (e.g. a 128×128 "seamless top-down aged sandstone flagstones"). Earlier in this same session both PixelLab tile tools were ruled out for continuous floors — but that conclusion was **too strong**. AI tile-objects ARE usable as a continuous floor; the blocker is a specific, fixable artifact:

- **The real culprit is a heavy dark PERIMETER FRAME, not the transparency or "seamlessness."** Every `create_map_object` tile renders the stone motif with a thick dark mortar/shadow border around all four sides, sitting on a transparent margin (~28% alpha-0). Tiling it raw → the transparent margin reads as black gaps; cropping only to the opaque bbox still leaves the dark frame → every tile boundary becomes a heavy grid line (the wallpaper read). Scattering N different AI tiles makes it WORSE (mismatched frames meet → coarse grid of distinct bordered squares).
- **Fix: crop ~10-12px INSIDE the opaque bbox**, cutting the frame, so the stone field reaches the new edge. Then tiles abut **stone-to-stone** with only a thin natural joint, and the tile boundary becomes indistinguishable from the internal mortar joints. A single inset-cropped tile tiled at its native period reads as a continuous crafted flagstone floor at game zoom. (One tile + sparse hand-placed accent tiles to break the period beats a multi-variant scatter.)
- **Engine integration is free:** the existing `s1_cloister.tres` already treats the 128px floor PNG as a **4×4 atlas of 32px tiles** painted to reconstruct the image — so dropping in a full-bleed inset-cropped 128px AI floor tiles at a gentle 4-tile (128px) period with stones flowing inside each block. Just match the existing 128px source dimension.
- **Palette coherence — recolor cold AI tiles to the doctrine ramp via a luminance→ramp gradient map.** The AI floor came back warm (fine), but the AI *wall* came back cold grey and clashed. A luminance→warm-ramp map (`#1A1210`→`#2C261C`→`#4A3F2E`→`#5C4F38`→`#9A7A4E`) recolors it to the warm cloister palette while keeping the AI stone structure — though a fresh AI gen with an explicit "WARM tan, NOT grey" prompt reads crisper than recoloring a grey source.

**When to use which:** procedural broken-ashlar = full doctrine control, no gen cost, but reads slightly mechanical. AI-tile + inset-crop = more organic/painterly (Sponsor preferred), costs gens + needs the frame-crop + possible palette recolor. The Sponsor is the taste authority; his feel-approval of the AI look overrides the doctrine-lock mandate where they conflict (do a gentle nudge, not a hard lock, to preserve the approved look).

---

## `create_map_object` cannot render flat ground-texture variations — it builds a structure

**Validated 2026-06-07 (S1 yard ground-composition, spring/seep attempts).** `create_map_object`
interprets pool / spring / seep / wet-patch prompts as **discrete built objects** (a thing with
a rim, walls, or basin), not flat ground-texture variations. Two attempts:

- `"still pool welling up between cobblestones, top-down"` → a **stone-rim basin** (a built
  structure — correct shape for a well, wrong for ground water).
- a simpler flat-seep prompt → a **flat dark blob with an over-bright moss ring**, reading as a
  circular decal prop stamped on the floor, not organic ground texture.

**Root cause:** `create_map_object` is designed for discrete objects that sit ON a surface
(barrels, wells, crates, braziers). The transparent-background constraint means every output has
a hard object silhouette — architecturally outside "a patch that blends seamlessly into the
surrounding floor." Top-down framing does not override this.

**Same class as the floor-tool ceiling above:** just as `create_topdown_tileset` and
`create_tiles_pro` cannot produce a continuous crafted floor, `create_map_object` cannot produce
a flat ground patch. PixelLab tools are for discrete objects + terrain edges; flat continuous
ground variations (wet patches, mud, puddles, worn paths that are part of the floor) are
**in-engine territory**.

**Fallback for ground-seep / wet-cobble / damp-patch:** author in-engine as a `ColorRect` or
`Sprite2D` with a semi-transparent warm-neutral tint (e.g. `Color(0.18, 0.16, 0.15, 0.35)`)
over the existing floor tiles, plus reused moss/damp tile variants for organic edge blending.
Free (no gen cost), full control over the spread shape. (Used for S1 yard springs per the
ground-composition spec §3.2.)

## `create_map_object` building-asset gotchas (S1 yard buildings, 2026-06-08)

Validated generating the 5 S1-yard building props (chapel, dormitory ×2, central, outbuilding) via `create_map_object`.

**1. Larger gens silently bake an OPAQUE matte background — despite the API reporting "background: transparent".** The 256px gens (chapel, both dormitory halves) came back with a flat warm-grey matte filling the canvas (corner pixels `(214,206,194,255)` / `(204,198,173,255)`, **0 transparent pixels**), while the 128px + 96px gens (central, outbuilding) were correctly transparent (corner alpha 0). The `get_map_object` output line still said `background: transparent` for all of them — **do not trust it; check `px[0,0][3]` after download.** Hypothesis (unconfirmed): the matte appears on the larger canvases; size threshold not pinned. Always inspect corner alpha before placing.

**2. Strip the matte by EDGE-FLOOD, never global color-replace.** The matte color (warm tan-grey) is Euclidean-close to the sandstone walls, so a global "make all pixels matching bg transparent" punches holes in the building (the same class as pixel-mcp's `fill_area` global-replace trap). Safe fix: BFS flood from the border pixels with a small tolerance (`TOL≈18` RGB), removing only the **contiguous** border matte; the selective-outline silhouette stops the flood at the building edge. Then `getbbox()` + crop to tighten bounds so the footprint maps to the placement `Rect2i`. Reusable script: `tools/crop_s1_buildings.py`.

**3. Static sprites need NO HDR-clamp — clamping is only for modulate/tween.** The `html5-export.md` sub-1.0-channel rule bites when a color is *multiplied* (modulate/tween push >1.0 → WebGL2 clip). A static PNG sprite with full-255 channels displays correctly; clamping it is unnecessary motion. Clamp only if/when the sprite gets a runtime modulate cue (e.g. a flickering lit window → that's a ColorRect-modulate, then clamp).

**4. The building/wall palette doctrine has NO roof color — do NOT hard-snap buildings to it.** `S1_BUILDING_DOCTRINE` (8 hexes: sandstone body/trim/deep + moss + parchment + soot + mortar) is a *wall/stone* palette. Buildings-with-roofs (terracotta chapel roof, grey-slate dormitory roof) have legitimate roof materials the doctrine never anticipated; Strategy-3 nearest-neighbor would route a terracotta roof to `#9A7A4E` bronzed-trim and a slate roof to wall-stone, turning roofs into walls. For first-of-class building gens that already read warm + weathered, prefer **mechanical-only processing** (matte-strip + bbox-crop) and preserve the natural roofs; the Stardew/Graveyard-Keeper references favor warm colored roofs anyway. Treat "how muted should the buildings be" as a Sponsor subjective-feel call surfaced at the in-game serve, not an auto-applied doctrine-lock.

**5. Baked ground-plate under iso buildings: RECOLOR, do not remove (validated 2026-06-10, `building_ruin.png`).** D2-style iso building gens come with a baked maroon/oxblood ground-plate diamond under the footprint (plus pebbles + a path stub drawn ON it). Surgical removal destroys the asset — two attempts failed: (a) color-cluster masking in the lower region also ate the door-arch interior and wall shadows (same color family); (b) flood-fill from plate seeds spread up through connected shadow tones and ate most of the building. The safe fix is a **luminance-preserving recolor** of the plate family only: select red-dominant pixels (`(r>45)&(r<150)&(g<60)&(b<45)&(r>g*2.2)`, restricted to the lower canvas region), compute per-pixel luminance relative to the plate's anchor color (here `(112,25,4)`), and remap onto a target earth-brown ramp (`lum × (146,106,72)`). Walls/roof untouched; pebbles and path stub stay coherent; the plate reads as an intentional dirt foundation bed that harmonizes with ground tiles. Keep the original as a `_*_orig.png` backup before swapping.

**5b. Building APRONS: do NOT strip — keep and BLEND with a matching tile material (settled 2026-06-11 after two failed strip attempts).** Apron removal joins gotcha #5's removal graveyard: (a) a geometric wall-base-diamond cut (`outside diamond AND below band`, per-building `(halfw, halfh, drop)`) sliced into the walls — fixed params don't generalize across buildings, and the damage SHIPPED because it was judged from a THUMBNAIL; full-size before/after renders are mandatory for any destructive sprite op; (b) a per-column bottom-up color strip stalled immediately — apron grout lines are dark pixels that satisfy any sane "stop at outline" condition (332/0/689 px removed of ~15k targets). The SHIPPED solution inverts the problem: keep aprons, sample their palette (family H/S/V stats + V-mean scaling), recolor an existing seamless tile material into it → new paintable terrain ("plaza") with full transitions; painting plaza around a building makes the baked apron read as an intentional terrace. Classify bases regardless: flat slab aprons (blend with plaza) vs architectural bases (walled forecourts, gallery floors, plinths — always keep).


## Building-wall kit generation — oblique view, width, and seam strategy (S1 yard, 2026-06-10)

> **SUPERSEDED AS ACTIVE DIRECTION — 2026-06-10.** The same day this workflow was validated,
> the project pivoted to a **full isometric world** (Diablo-2 style); see
> `team/DECISIONS.md` (2026-06-10 full-isometric-world entry). The oblique wall-kit approach
> is abandoned as the current direction. The techniques below (pier-on-seam, frame-normalize,
> tone-match, single-bay width rule) remain valid reference; for the **active path** see the
> isometric building recipe section below.

Validated generating oblique cloister building-WALL blocks (new asset class distinct from the
building-prop assets above) via `create_map_object`.

### View param — which value gives which building read

| `view` value | Result |
|---|---|
| `"low top-down"` | Oblique angled roof + facade — **correct for S1 monastery wall bays** ✓ |
| `"top-down"` | Flat pure-top view; no visible façade |
| `"side"` | Crenellated castle battlements — reads militaristic, NOT monastery |

**Use `"low top-down"` for any oblique monastery wall or facade asset.** `"side"` is
recorded here because it is tempting (orthographic wall face) but produces castle battlements
regardless of how explicitly "NOT castle" the prompt is.

### Width: single bay (~128px) keeps on-style; wide (384px, 3-bay) castle-ifies

Generating a wide multi-bay span in a single prompt causes PixelLab to shift toward
heavy castle architecture even with strong "monastery NOT castle" wording. **Prompt single
bays (~128px each) and composite them in post.** A 3-bay wall is a post-process assembly of
3 individual bay gens.

### Plain bays — generate with minimal openings, then patch

PixelLab resists blank walls and typically inserts small windows or slits even when the prompt
forbids them. The recommended strategy for a truly plain bay is to **generate a plain-as-possible
bay (accepting the small windows as a starting point) and then patch stone texture over the
openings in post** using the Python+Pillow pipeline (see the System.Drawing section in
`pixel-mcp-pipeline.md`).

### Kit seam strategy — pier-on-seam + frame-normalize + tone-match

The kit (`assets/props/s1_cloister/buildings/`) contains individual bay PNGs and a 48px-wide
pier sprite. The assembly pipeline (`assets/props/s1_cloister/buildings/_pixellab_raw/build_kit.py`):

**Pier-on-seam** — stamp the 48px buttress-pier sprite at every bay boundary (seam). This
hides roofline steps, edge mismatch, and tone breaks between adjacent bays. Because the pier
fully covers each bay edge, the shared roof band does NOT need to tile horizontally — each bay
can have its own roofline variation (validated: per-bay rooflines vary 45–64px).

**Frame-normalize + tone-match** — for each assembled bay, stamp the shared roof band
(rows 0–66 from the reference bay) to create a consistent skyline, then apply a per-channel
multiplicative gain to match the bay's mean tone to the group wall-mean (so bays generated
at different sessions don't read as patchwork). Both passes run in the same Python step before
pier assembly.

```python
# Skeleton — tone-match (per-channel multiplicative gain)
import numpy as np
from PIL import Image

def tone_match(src: np.ndarray, target_mean: np.ndarray) -> np.ndarray:
    """Scale each RGB channel so src wall-region mean matches target_mean."""
    mask = src[..., 3] > 0                          # opaque pixels only
    result = src.copy().astype(float)
    for c in range(3):
        src_mean = result[mask, c].mean()
        if src_mean > 1e-3:
            result[..., c] = np.clip(result[..., c] * (target_mean[c] / src_mean), 0, 255)
    return result.astype(np.uint8)
```

### Asset locations

| File | Contents |
|---|---|
| `assets/props/s1_cloister/buildings/_pixellab_raw/` | Raw PixelLab downloads for wall bays + `build_kit.py` |
| `assets/props/s1_cloister/buildings/cloister_bay_plain.png` | Plain bay (generated; for a fully-blank variant, patch openings in post) |
| `assets/props/s1_cloister/buildings/cloister_bay_window.png` | Bay with arched window |
| `assets/props/s1_cloister/buildings/cloister_bay_door.png` | Bay with door opening |
| `assets/props/s1_cloister/buildings/cloister_bay_arch.png` | Bay with arcade arch |
| `assets/props/s1_cloister/buildings/cloister_bay_decorated.png` | Bay with niche/banner stonework |
| `assets/props/s1_cloister/buildings/pier.png` | 48px-wide buttress pier (boundary stamp) |
| `scenes/levels/demo/cloister_wall_demo.tscn` | Demo scene showing a composed wall run |

## `create_map_object` — isometric building recipe (D2-style, validated 2026-06-10)

Validated generating isometric buildings in Diablo-2 style via `create_map_object`
(object ID `29721b7a`, size 320). This is the **active building path** after the 2026-06-10
full-isometric-world pivot (`team/DECISIONS.md`).

**Validated prompt pattern:**

```
Isometric view of <subject>. Diablo 2 style. True isometric projection showing two visible
walls meeting at a front corner, with depth. <material/condition descriptors, e.g.
"worn tan sandstone, caved-in terracotta roof, rubble at the base">
```

- `view`: `"low top-down"` — confirmed correct for the iso-corner framing.
- `size`: 320 validated (object `29721b7a`); 256–384 is the working range.
- **The framing phrase is load-bearing.** "True isometric projection showing two visible
  walls meeting at a front corner, with depth" empirically avoided the castle-ification /
  battlements trap FIRST TRY — the same subject phrased as a "wall" prompt castle-ifies
  (see the wall-kit section above). Drop the phrase and you risk a fortress read.

**Matte trap RE-VALIDATED at 320px.** Corner pixel `(127,124,125,255)` — fully opaque despite
`get_map_object` reporting `background: transparent`. Apply the same BFS edge-flood fix as
building-asset gotcha #2 above (`TOL≈18`, `getbbox()` crop). Always check `px[0,0][3]` after
download; do not trust the API field.

**8-hour auto-expiry applies.** Download promptly after generation.

**Do NOT hard-snap iso buildings to `S1_BUILDING_DOCTRINE`.** Gotcha #4 above applies
identically: legitimate roof materials (terracotta, slate) fall outside the wall/stone doctrine
palette; prefer mechanical-only processing (matte-strip + bbox-crop) and preserve natural roof
colors. Treat muting as a Sponsor subjective-feel call at in-game serve.

## `create_map_object` — scatter prop generation traps (Zone-A, 2026-06-12, ClickUp `86ca7yt5u`)

Validated across an 11-prop scatter set for the Zone-A beach/field ground layer (grass tuft,
dry tuft, pebble, pebble cluster, seashell, driftwood, red/yellow/purple wildflower clumps,
straw stalks, bush). Building-asset gotchas above (matte trap, 8h expiry) still apply; these
are additional, scatter-specific:

**1. Shape override — "bush" generates a CONIFER without explicit NOT-tree language.**
`"small dense wild bush, layered muted green foliage"` returned an unmistakable small conifer
(triangular silhouette; its berries read as ornaments). Validated fix (re-roll passed first
try): `"low rounded wild shrub, irregular dome shape wider than tall, ... NOT a tree, no
trunk, no conifer shape"`. General rule: when the desired shape is not the dominant archetype
of the prompted object class, add explicit `NOT <taller/dominant form>` language.

**2. Non-square canvas may come back square with transparent padding.** A 64×32 driftwood
request returned a 64×64 canvas (observed once). Harmless if the consumer feet-anchors and
crops, but never assume the returned canvas matches the request — check `Image.open(p).size`
and crop to `getbbox()` when the footprint matters.

**3. Concurrency rate-limit observed below the nominal cap.** Firing 10 `create_map_object`
calls at once (with a tileset job also in flight) rejected 4 with `rate limit exceeded` at ~7
accepted jobs — Tier-2 nominal is 10 concurrent. Observed once; treat ~6 simultaneous calls as
the safe batch size. The error's own "wait 15-30s" hint works: retried calls all succeeded
after the first batch drained.

**4. Style-param lock that held across all 12 props (probe + batch):** `detail="medium
detail"`, `shading="medium shading"`, `outline="lineless"`, `view="high top-down"`. Lock these
across a scatter batch and vary only the description — prevents style drift between props that
will share one ground. Probe ONE prop first (the grass tuft was the validation probe), judge
it, then batch the rest with identical params.

**5. 8-hour auto-delete applies to scatter props** (same rule as the map-object expiry gotcha
above) — harvest the whole batch promptly; the generation prompt is the only surviving record
after expiry.

## Multi-gen building SETS — palette drift, harmonization, and complex-vs-segment granularity (validated 2026-06-10)

**Every independent gen rolls its own palette.** A 7-building batch with IDENTICAL
material/palette prompt tails came back with visibly different roof reds and stone tints
(Sponsor: "its 3 different shades of red"). Prompt wording cannot fix this — harmonize in post.

**Family-recolor harmonization (validated 2×, red-roof set + ember set):**
1. Pick ONE Sponsor-approved piece as the palette anchor.
2. Family selectors by channel ratio on each piece, e.g. roof-red `(r>g*1.25)&(r>b*1.25)&(r>55)`,
   moss `(g>r*1.3)&(g>b*1.1)` (exclude — keep moss green), ember-glow `(r>120)&(r>g*1.25)&(g>b)`
   (exclude — keep warm window light), stone = everything else opaque above near-black.
3. Per family: HSV remap — hue := anchor family's circular-mean hue; sat := `0.3·own + 0.7·anchor_mean`;
   **keep V** (preserves all shading/detail). Optional gentle darkness pull for outlier pieces:
   if a piece's family V-mean exceeds anchor's by >12%, scale V toward `anchor_mean×1.06`.
4. PIL `convert('HSV')` round-trip works; carry alpha separately.

This is cheap, deterministic, and uniform across any number of pieces — re-anchoring a whole
set to a new Sponsor style pick is a re-run, not a regeneration.

**Granularity rule — prompt whole CONNECTED COMPLEXES, never "segments".** Modular-kit
prompts misfire: "short section of a monastery wing" → a complete tall gable house; "tall
narrow stone buttress pier" → a crenellated castle turret (the castle-ification trap recurs
on any wall-like fragment subject). But complex subjects excel: "U-shaped range around a
court", "L-shaped wing meeting a square corner bell tower", "quadrangle with enclosed inner
courtyard" all produce coherent connected-wing buildings first try. Compose large complexes
(monasteries, castles) from complex-buildings placed close together + standalone TOWERS at
junctions (towers hide all joints — sibling of the wall-kit pier-on-seam trick); do NOT chase
edge-mating segment kits.

**Long-range subjects drift to enclosures.** "Long two-storey range" prompts repeatedly grew
courtyards/battlemented forecourts (3 occurrences). Strongest counter-wording found: "one
single straight long narrow ... much longer than tall ... NO battlements" — still only
partially effective; budget a re-roll.

## `create_isometric_tile` — size cap, shape param, and real ETA (validated 2026-06-10)

**Hard size cap: 64px** (`size` param maximum).

**`tile_shape` — use `"thin tile"` for D2-flat ground.** The `"thin tile"` variant is ~10%
canvas height (flat diamond), matching how walkable ground reads in Diablo-2-style iso.
Thicker shapes (`"thick tile"` ~25%, `"block"` ~50%) read as raised slabs or blocks — right
for elevated terrain, wrong for flat ground.

**Real ETA: ~463–465 s (≈8 min) observed** at `size=64`, `detail="highly detailed"`, despite
the tool description claiming "~10–20s".

**General rule: NEVER schedule from tool-description ETAs.** Same hint-vs-reality class as
`create_map_object`'s "30–90s" claim (observed ~7–8 min at 320–384px high detail) and
`create_character` v3's "~3–5 min" hint (observed ~10–15 min). PixelLab description ETAs are
aspirational across all async tools — trust the `eta` field in the `get_*` poll response.

**NEVER use `create_isometric_tile` for continuous ground — it seams by design (validated
2026-06-10, Sponsor-observed).** Each generated diamond is a self-contained slab: its own
stone-border composition + a baked side lip from the `tile_shape` thickness. Adjacent painted
cells read as separate slabs with visible seams everywhere; this is structural, not a quality
issue — unfixable by prompting or re-rolling. Suitable for **standalone props or raised
platforms** where the slab border is intentional; wrong for walkable ground fields.

**Validated replacement for seamless iso ground: project a seamless top-down texture into
diamonds.** Source: any seamless cross-mating top-down tile set (validated on
`assets/tilesets/s1_cloister/floor_cobble.png`, 768×128 = six cross-mating 128px variants).
For a 128×64 diamond canvas, per output pixel (X, Y):

```
U = (2Y + X − 64) mod 128
V = (2Y − X + 64) mod 128
color = source[V, U + 128·n]          # n = variant index 0–5
alpha = diamond mask: |X−64|/64 + |Y−32|/32 ≤ 1
```

Integer-exact nearest sampling — no resample blur. **Load-bearing property:** one map-cell
advance equals exactly one source period (128px), so every diamond's edges land on the source
tiles' own (mating) borders — self-mating AND cross-variant-mating by construction. Verified:
a 10×10 random-variant field renders as one continuous plane, zero seams. Output is flat (no
lip) and inherits the production palette. Implementation:
`assets/iso_proof/make_iso_cobble.py`; resulting TileSet = single 768×64 atlas,
`texture_region_size` 128×64, 6 tiles, `tile_shape=1`, `tile_size` 128×64, no texture_origin.

| Need | Use |
|---|---|
| Standalone elevated platform / iso prop tile | `create_isometric_tile` |
| Continuous walkable iso ground field | Projection-slice from a seamless top-down source (recipe above) |

Same root-cause family as the top-down cross-variant constraint in the next section
(period/edge mismatch between independently generated tiles).

## `create_tiles_pro` — validated route for seamless flat iso GROUND when no top-down source exists (validated 2026-06-10)

**Amendment to the earlier "`create_tiles_pro` is ALSO wrong for a continuous floor" conclusion:**
that conclusion was for `tile_type="square_topdown"`, which produces transparent rounded-token
tiles. The `tile_type="isometric"` variant is a structurally different path and IS validated for
seamless flat iso ground tiles (this is the same feature as the web GUI's Maps → Tiles →
Isometric group generator).

**Validated recipe (exact call used for the iso-proof grass/flagstone/dirt sets):**

```python
mcp__pixellab__create_tiles_pro(
    description="1). <material one> 2). <material two> ...",  # numbered materials, ONE string
    tile_type="isometric",
    tile_size=128,           # canvas comes back 128×128; flat diamond occupies rows 32–95
    tile_height=64,
    tile_view_angle=30,
    tile_depth_ratio=0,      # flat ground — no slab lip
    outline_mode="segmentation",
    seed=7,
)
```

Crop the **128×64 band at rows 32–95** of each 128×128 canvas for the Godot `tile_shape=1`
TileSet (`texture_region_size = Vector2i(128, 64)`). Grass-tuft overhang may poke a few px
above row 32; clipped on crop, negligible at game zoom.

**Geometry trap — `tile_view="top-down"` gives a 1:1 square diamond, not D2 2:1.** The
default-looking choice for "flat ground" yields 64×64 1:1 diamonds. For the D2 2:1 dimetric
grid you need `tile_view_angle=30` + `tile_depth_ratio=0` (+ `tile_size=128, tile_height=64`).

**Variant counts are auto-computed (totals, not per-material):** 4 materials @ 64px → 16 tiles
(≈4/material); 4 materials @ 128px → 10 tiles (≈2-3/material); 1 material @ 128px → 10 tiles.
Cost ~20–40 gens per call.

**Per-material seam verdicts (6×6 lattice field mocks, same-tile worst case + mixed-variant):**

| Material | Verdict | Notes |
|---|---|---|
| Grass | PASS | No seam lines even same-tile-repeated; mixed variants read organic |
| Flagstone | PASS | Tile borders read as intentional grout — D2-dungeon look |
| Cobble (multi-material group) | FAIL | Moss/dark bands baked along diamond edges → visible lattice; variant tone-spread → patchwork |
| Dirt (multi-material group) | FAIL | Streaky directional texture repeats hard; variant tone-spread → patchwork |

**Patchwork mitigation (validated on dirt):**

1. Re-call `create_tiles_pro` with ONLY the failing material and a defect-tuned prompt
   (dirt fix: "smooth trodden earth, even warm brown tone, no streaks, no cracks").
2. Download all variants; compose lattice field mocks (same-tile worst case first).
3. Keep only the tone-coherent subset — judge BEFORE installing into the TileSet.
   Dirt: kept 4 of 10 (most-uniform first).

Cobble mitigation via single-material regen is **unvalidated** (never attempted — the
projection route already covers cobble; see routing below).

**Post-processing mitigations after the cull (validated 2026-06-10 on grass v2):**

- **Alpha pin-holes inside the diamond** (blade-fringe notches; ~120-220 px/tile observed on
  grass) read as black gap slivers when painted back-to-back. Fix: iterative 4-neighbor
  nearest-fill restricted to the diamond mask (np.roll the opaque mask in 4 directions,
  copy RGBA where a transparent-in-diamond pixel gains an opaque neighbor; ~8 iterations),
  then force `alpha=255` everywhere inside the diamond.
- **Cross-variant tone spread** (soft patchwork even within one gen's culled subset): shift
  each variant's RGB by `(pool_mean − tile_mean) × 0.7` (means over in-diamond pixels).
  70% correction removes the value-step between diamonds while keeping per-tile character.
  Observed shifts are small (1-4 RGB points) — the residual lattice readability comes from
  per-tile grain direction, which equalization cannot fix; diminishing returns past this.
- **Cross-GENERATION pooling FAILS — negative result.** Pooling variants from two different
  `create_tiles_pro` calls (different prompts/seeds, same material) checkerboards hard:
  generations differ systematically in tone AND texture character, and mean-equalization
  cannot fix texture. Variant pools must come from a single generation call. (Observed:
  dirt v1 smooth-tan subset + dirt v2 grainy-dark tiles → hard checkerboard.)

**Routing rule — which iso-ground path:**

| Scenario | Route |
|---|---|
| Seamless top-down source already exists (e.g. `floor_cobble.png`) | Projection-slice (`make_iso_cobble.py`, section above) — seamless by construction, zero gen cost |
| No source; material passes the lattice-mock gate | `create_tiles_pro` isometric (single-material + culled subset if the multi-material group seams) |
| No source; material fails even single-material mitigation | Generate a seamless top-down source first (inset-crop doctrine, pixel-mcp-pipeline.md), then projection-slice |

Field-mock judge artifacts: `assets/iso_proof/_tiles_pro*/`. Do NOT confuse this path with
`create_isometric_tile` (seams-by-design slabs, section above) or `create_tiles_pro`
`square_topdown` (transparent tokens, section above).

## Scripted iso TRANSITION tiles — mate-by-construction, zero gen cost (validated 2026-06-10)

Cross-material border tiles (grass↔dirt etc.) for the Godot terrain auto-tiler are
constructed procedurally from the shipped material textures — no PixelLab generation.
For each unordered material pair: the 14 side-combination tiles (2⁴ bitmasks minus the
2 pures) at 128×64. Implementation: `assets/iso_proof/make_iso_transitions.py` (builds
all 6 pair atlases AND regenerates the entire terrain-wired `.tres` in one pass — never
hand-edit the .tres; re-run the script).

**Diamond-local coordinate frame.** The 128×64 diamond is the image of the unit square
under `X = 64 + (u − v)·64`, `Y = (u + v)·32`. Edges: NE = `v=0`, SE = `u=1`, SW = `v=1`,
NW = `u=0`. (Godot peering-bit names: NE=`top_right_side`, SE=`bottom_right_side`,
SW=`bottom_left_side`, NW=`top_left_side` — see godot-headless-tooling.md Pattern 5.)

**Mask field = inverse-distance (Shepard p=2) interpolation of the 4 SIDE bits** (bit=1 →
that edge mates material B):

```python
d = [v, 1-u, 1-v, u]                  # distances to NE, SE, SW, NW edges
w = [1.0 / (di + 1e-3)**2 for di in d]
f = sum(wi*bi for wi, bi in zip(w, bits)) / sum(w)   # → B where f > 0.5
```

The field is PURE at every edge (distance→0 → that side's weight dominates → f → its bit),
so edges are canonical: any two tiles agreeing on a shared edge's terrain mate exactly,
including against the pure material tiles. Boundaries pin to corner points on mixed corners.

**Negative result — Coons-patch / bilinear-corner construction FAILS.** Along the NE edge
(v=0) the bilinear form evaluates to `b_ne/2 + (1−u)·b_nw/2 + u·b_se/2` — NOT pure, →
seams against pure neighbors. Same for corner-anchored Shepard (edge midpoints blend the
two adjacent corners → 0.5). Side-distance Shepard is the construction that works.

**Organic boundaries without breaking the mating guarantee:** multi-octave noise (octaves
4/8/16, bilinear-upscaled randn) added to the field with **edge-vanishing amplitude**
`clip(min_edge_dist × 4, 0, 1) × 0.55` — zero at edges keeps them canonical; full noise in
the interior. A ±0.05 band around the 0.5 threshold gets random per-pixel dither for
pixel-art feel. Texture sampling: A-pixels from material A's variant-0 tile, B-pixels from
B's variant 0 (all variants of a material mate, so transitions mate every painted variant).

**Atlas convention:** column index = bits − 1 where bits = NE | SE&lt;&lt;1 | SW&lt;&lt;2 | NW&lt;&lt;3,
bits ∈ [1..14]. Tile `terrain` (center) = B when ≥3 bits set, else A.

## Projection limits + iso-lattice TORUS synthesis (validated 2026-06-10)

**The projection-slice route destroys directional texture.** `U=(2Y+X-64)%128, V=(2Y-X+64)%128`
maps source-space verticals onto diagonals and compresses everything 2:1 vertically — fine
upright structure (grass blades) becomes diagonal smear/speckle. Projection works for
ISOTROPIC textures only (cobble, packed dirt, flagstone slabs). Empirical: projected grass
read as "static noise" two attempts in a row; PixelLab's native iso tiles read well because
their blades are drawn in iso view.

**Fix — synthesize directly in SCREEN space on the iso-lattice torus.** The diamond lattice
(translations `(±64,+32)`) has a 128×32 fundamental domain with a TWISTED wrap: stepping past
`y=31` shifts `x` by 64. Paint upright strokes with lattice folding and the result tiles
perfectly while keeping screen-space orientation:

```python
FW, FH = 128, 32
def fold(x, y):                      # screen coords -> fundamental domain
    t = (y // FH) % 2
    return (x + 64 * t) % FW, y % FH
# smoothing must twist too: vertical np.roll wraps get an extra 64px x-shift
# diamond build: SX = (X + 64*((Y // FH) % 2)) % FW;  SY = Y % FH;  tile = buf[SY, SX]
```

Validated for grass (5200 micro-strokes + 1500 upright 2-4px blades + sparse muted dry
blades over a 2-tone lattice-smoothed base): zero seams, blades upright. Implementation
inline in the session; the projection machinery lives in `make_iso_projected_grounds.py`.

**Keep the AI look without the AI seams — palette sampling.** Histogram-quantize the
approved PixelLab tiles (`(px // 12 * 12)`, count clusters, take top-N sorted by brightness)
and drive the procedural synthesis with those dominant colors. Bridges the Sponsor's
AI-quality preference (memory `sponsor-prefers-ai-gen-tile-quality`) with construction-level
seamlessness; tuft DECALS cropped from the AI tiles add back organic life per-variant.

**Object-route ground sources are unreliable.** `create_1_direction_object` with
"edge-to-edge ground texture, tileable" prompts usually returns sparse blobs-on-transparent
(2 of 3 packs failed entirely, 2026-06-10; the one earlier success was luck). Slab/stone
subjects fare better than organic scatter (the flagstone pack yielded 1 good full-bleed
candidate of 4 — check `(a[...,3]<200).sum()` and np.roll(64,64) wrap-test before trusting).
Sources may carry in-texture transparent holes — pin-hole fill with TOROIDAL neighbors
(np.roll wraps) before projecting.

**Updated routing for iso ground materials:**

| Material class | Route |
|---|---|
| Isotropic, seamless top-down source exists (cobble) | Projection-slice |
| Isotropic, no source (dirt, flagstone) | Procedural toroidal synth or one AI source attempt → projection-slice |
| Directional/organic (grass, fur, reeds) | Iso-lattice torus synthesis in screen space (this section) |
| Any material, per-tile AI look preferred over seamlessness | `create_tiles_pro` iso + post-processing mitigations (sections above) |

## Multi-variant seamless FIELD — toroidal ≠ cross-variant edge-mating (S1 yard, PR #426)

Validated 2026-06-08. A toroidally-seamless tile (the `np.roll` half-offset wrap, or any
generator that guarantees a tile wraps with **itself**) is seamless **only when the SAME tile
repeats**. It does NOT guarantee that two **different variants** mate at their shared edge.

**The trap:** painting a large ground field by swapping among N seamless variants *per block*
(e.g. a different 256px cobble/dirt variant per chunk-block for visual variety) exposes a
**visible grid of seams** at every block boundary — adjacent variants' edge pixels don't line
up, so the eye reads a ~256px lattice across what should be a continuous field. This was the
"no structure / block-grid" artifact in the S1 yard v2 dirt field.

**Fixes:**
- **Single-variant continuous addressing (used for the S1 dirt fix):** paint the field from ONE
  variant addressed continuously across the whole region (sample one large virtual texture by
  world-coordinate modulo), so every cell mates with its neighbor by construction. Variety then
  comes from composition (paths, patches, edges), NOT per-block texture swaps.
- If you DO need multiple variants in one field, they must be generated to share identical edge
  pixels (a common seam ring) — otherwise they cannot tile against each other.

**Corollary (the broader S1-path lesson):** procedural *scatter* of material patches reads as
chaos, not as authored ground. A varied ground that reads "designed" (smooth field + one
legible path + grass at the margins) needs **hand-placed composition**, not per-block random
variant/patch selection. See `.claude/docs/art-direction.md` § Execution lessons.

**Finer geometry WITHOUT shrinking the texture — decouple the painter cell from the atlas (PR #426 v4).**
To make path/region GEOMETRY finer (smaller corners/steps, soft edges) without shrinking the
loved stone size: **decouple the painter/TileMap cell from the texture sampling.** Use a finer
cell grid for authoring/painting (smaller cells → finer step resolution + room for feathered
dither bands at material edges), but sample the atlas by **continuous world-coordinate** (`fx %
period`) so the stone scale stays pinned to the atlas period regardless of cell size. The cobble
"stones" stay the size Sponsor approved while the path corners get finer. **Constraint:** the
cell size must divide BOTH the world dimension AND the atlas period for clean seamless tiling —
this capped the S1 yard at a 16px cell (only 2× finer than the 32px logical tile) in the fixed
1280×768 world. Finer-than-that needs a different world dimension or a boundary blend-shader.

## Checklist — before every PixelLab + pixel-mcp session

1. Check Sponsor's credit balance / plan tier before starting; do not consume pro-mode credits
   without explicit approval.
2. Create the .aseprite canvas with `create_canvas` BEFORE calling `import_image`.
3. Use `image_path` (not `file_path`) in `import_image`.
4. After import, call `get_sprite_info` to confirm canvas dimensions — never assume from `size`.
5. Plan a `crop_sprite` step to extract character from PixelLab's square padding.
6. If using `quantize_palette` with N ≤ 12: request `target_colors = N + 30%` to absorb dupes.
7. For doctrine-lock: use Strategy 3 (per-slot nearest-neighbor mapping) — best validated result.
8. Verify visually after every `set_palette` or `export_sprite` call.
9. All pixel-mcp trap rules from `pixel-mcp-pipeline.md` still apply (Windows path escape,
   draw_pixels broken, fill_area global-replace, scale_sprite destructive).
10. For characters destined for ground-anchored rendering (isometric / 3D billboard): alpha-scan
    the idle-south frame for the lowest opaque pixel row and pivot there, NOT the canvas bottom
    (see "Transparent-padding trap" section). If pivot drifts > 2 px across sample frames,
    switch to per-frame pivots.

## Env-art pre-delivery judge ritual (validated 2026-06-12, ClickUp `86ca7yt5u`)

14 environment-art generations (tilesets + scatter props) for Zone-A; 3 failed the art bar and
all 3 were caught BEFORE delivery by this ritual. Failures are invisible at the thumbnail scale
the MCP tool response renders — judge at inspection scale, against the board, before any
delivery to engine/consumer.

1. **Download with `curl -sS -L -f`** (see the redirect-trap section) and fail-fast-verify the
   file opens (`PIL.Image.open`).
2. **Upscale NEAREST for inspection** — 4× for tile sheets, 8× for small props. Nearest-neighbor
   (never bilinear) preserves pixel structure so weave/grid artifacts and silhouettes read.
3. **Tiles: 4×4 self-tiled preview** — paste the candidate fill tile in a 4×4 grid and upscale.
   Seams, repeat rhythm, and mechanical structure only become visible in a tiled field; a tile
   judged in isolation always looks better than it tiles.
4. **Props: contact-sheet the batch** — composite all props (8×, on a neutral grey background)
   into ONE image and Read once. Style drift and scale mismatch read immediately in a grid;
   N individual reads waste rounds and hide relative problems.
5. **Judge against `art-direction.md`'s inspiration board**, not against "is this a good
   sprite": the question is whether it reads as part of THIS world (fine multi-tone texture,
   muted natural palette, no cartoon brightness). Record verdict + lesson per generation in a
   session judge-trail file so prompt fixes accumulate instead of being rediscovered.

**Zone-A worked examples (symptom → fix):** flat cartoon-green grass → name the tones
(olive/moss/forest green); basket-weave sand → medium detail + "NO pattern/grid/weave, organic
randomness"; conifer-shaped "bush" → explicit "NOT a tree, no trunk, no conifer shape";
0-byte download → `curl -L`.

---

## Cross-references

- [`pixel-mcp-pipeline.md`](pixel-mcp-pipeline.md) — pixel-mcp tool bugs, canonical RGB-first
  pipeline, indexed-mode set_palette rule, Windows path escape, doctrine palette lock worked
  example (S1 Grunt — MJ source variant of this pipeline)
- `team/priya-pl/art-pass-ai-primary-brief.md §2` — palette discipline, hex-lock rules
- `team/uma-ux/palette.md` — global palette doctrine, S1 authoritative ramp
- Memory: `pixellab-mcp-installed` — install date, subscription tier, hybrid pipeline summary
