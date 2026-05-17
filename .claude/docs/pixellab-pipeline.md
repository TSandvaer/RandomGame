# PixelLab Pipeline — Tool Sequence, Traps, and Cost Model

Reference for agents using `mcp__pixellab__*` to generate character sprites, then
`mcp__pixel-mcp__*` for doctrine-palette compliance and export. Distilled from the first
end-to-end PixelLab → pixel-mcp execution (S1 Charger, 2026-05-17).

Cross-reference: [`pixel-mcp-pipeline.md`](pixel-mcp-pipeline.md) for all pixel-mcp tool bugs
and behavioral surprises. This doc covers the PixelLab side and the seam between the two tools.

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

| `size` param | observed canvas |
|---|---|
| 48 | 68×68 |

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

**Plan-tier context (as of 2026-05-17):** Sponsor was on the **free trial plan (20 generations
lifetime)** when this doc was written; Tier 2 ($24/mo) was being evaluated for full roster +
animation phase. M3 art-pass roster (9 characters × idle + 3 template animations) ≈ 225
generations — fits within one Tier 2 month, infeasible on free trial.

**Rules for credit-conserving sessions:**
- Standard `create_character` only — do NOT trigger pro mode without explicit Sponsor approval.
- Template animations only — custom animations cost up to 37× more per direction.
- Get Sponsor confirmation before any call > 5 generations.

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

---

## Cross-references

- [`pixel-mcp-pipeline.md`](pixel-mcp-pipeline.md) — pixel-mcp tool bugs, canonical RGB-first
  pipeline, indexed-mode set_palette rule, Windows path escape, doctrine palette lock worked
  example (S1 Grunt — MJ source variant of this pipeline)
- `team/priya-pl/art-pass-ai-primary-brief.md §2` — palette discipline, hex-lock rules
- `team/uma-ux/palette.md` — global palette doctrine, S1 authoritative ramp
- Memory: `pixellab-mcp-installed` — install date, subscription tier, hybrid pipeline summary
