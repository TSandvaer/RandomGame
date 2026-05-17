# pixel-mcp Pipeline — Tool Bugs, Behavioral Surprises, and Canonical Ordering

Reference for agents using `mcp__pixel-mcp__*` tools to process Midjourney sprite output into
doctrine-locked pixel art. Distilled from the first end-to-end MJ → pixel-mcp execution (S1
Grunt baseline sprite, 2026-05-17). Non-obvious tool bugs and behavioral traps documented here
so future executions don't rediscover them.

---

## Tool bugs (confirmed — affect every pixel-mcp session)

### `draw_pixels` is silently broken

`draw_pixels` returns success in **both RGB and indexed color modes** but does not write pixels.
The canvas is unchanged after the call; no error is raised.

**Workaround:** Use `draw_rectangle` with `w=1, h=1, filled=true` for every single-pixel write.

```python
# Broken — succeeds but writes nothing:
draw_pixels(pixels=[{"x": 5, "y": 3, "color": "#FF6A2A"}])

# Workaround:
draw_rectangle(x=5, y=3, w=1, h=1, color="#FF6A2A", filled=True)
```

This applies to all color modes. Do not use `draw_pixels` until a fixed version is confirmed.

---

### `fill_area` with `tolerance=0` is global replace, NOT connected flood-fill

`fill_area` at `tolerance=0` matches **all pixels in the canvas** sharing the target color and
replaces every one of them — it is a global color-replace, not a connected flood-fill bounded by
adjacent pixels.

**Consequence:** filling a color that appears in multiple unconnected regions (e.g. an anti-alias
gray present in both a robe and an eye shadow) rewrites every region at once. In the Grunt
execution, filling at `(13, 13)` also painted `(5, 13)` and `(8, 13)` because those pixels shared
the same MJ anti-alias source color — producing "stray eyes" far from the intended fill target.

**Safe usage:**

- Use `tolerance=0` only when the target color is unique in the canvas (verify with `get_pixels`
  first).
- For connected-region fills, use a non-zero tolerance appropriate to the source material, or
  manually recolor isolated regions with `draw_rectangle` 1×1 calls after a `get_pixels` audit.
- Before any `fill_area` call: `get_pixels` → check that the target hex appears only in the
  intended region. If it appears elsewhere, use targeted `draw_rectangle` calls instead.

---

## Behavioral surprises (not bugs — documented semantics, but non-obvious)

### `scale_sprite` modifies the source file destructively

`scale_sprite` writes the scaled result back to the source `.aseprite` file. There is no
non-destructive mode.

**Recovery:** Integer-ratio up-then-down is lossless for pixel art. If you scaled 32×32 → 16×16
to test proportions, re-open the original file (if preserved) or scale back up 16×16 → 32×32
(nearest-neighbor). Always keep the original `.aseprite` as a separate file before any
`scale_sprite` call, or work on a copy.

---

### Indexed-mode `set_palette` overwrites slot hexes but does NOT remap existing pixels

`set_palette` in indexed color mode replaces the palette's hex values but does **not** remap
canvas pixels to new slots. If slot 3 was `#5A4738` and you call `set_palette` to set slot 3 to
`#7A1F12`, every pixel previously at slot 3 now renders as `#7A1F12` — the pixel index is
unchanged but the color it references has changed.

This means palette surgery in indexed mode has unpredictable visual results unless you understand
the full slot-to-pixel mapping before the call.

**Rule:** Do all pixel-level editing in **RGB mode** first. Only convert to indexed (via
`quantize_palette`) after the sprite is visually correct. Never call `set_palette` to "fix" a
color in indexed mode on a sprite with existing pixel content.

**Mitigations — when positional `set_palette` is unavoidable** (e.g. doctrine-locking a
PixelLab quantize-pass output): two techniques, ranked by quality, validated on the S1 Charger
2026-05-17:

1. **Per-slot nearest-neighbor mapping (BEST):** for each quantized slot, compute the
   perceptually nearest doctrine color (Euclidean RGB distance is sufficient), then build a
   doctrine palette in the SAME slot order as the quantized palette. Positional `set_palette`
   then maps each slot to its nearest match. Recovers character beats (e.g. a red eye-glow
   maps to the closest doctrine red, not a positionally-coincident dark shadow). This was
   the validated winner on the Charger after Strategy 1 failed and Strategy 2 was skipped.
2. **Luminance-sort both palettes (mitigation):** sort BOTH palettes by
   `Y = 0.299R + 0.587G + 0.114B` before `set_palette`. Preserves dark→dark, light→light
   mapping but loses hue alignment — an isolated red accent at mid luminance may still
   cross-map to a brown of similar luminance.

See [`pixellab-pipeline.md §"Doctrine palette compliance — pick a strategy"`](pixellab-pipeline.md)
for full code samples and validation evidence.

---

## Frame-edge artifact — MJ-source PNGs carry a near-pure-black perimeter strip

Midjourney outputs contain a **1-2 px near-pure-black perimeter strip** on the bottom and left
edges (confirmed on two Charger generations: row 31 = solid `#1B1A1F`; cols 0-1 = similar). These
pixels are NOT `#000000` — they are off-pure-black values that `fill_area` with `tolerance=0` does
NOT catch (the outer-BG mask misses them because they don't match the target color exactly).

**Consequence:** if the perimeter strip survives into the final sprite, indexed-color export bakes
in stray near-black pixels that read as outline bleed or dirty edges at 32-px scale.

**Safe fix — 4-perimeter-strip clear:**

After background masking, before downsampling, explicitly overwrite the four edges with transparent:

```python
# After background mask, before scale_sprite — clear perimeter strip
# Assumes canvas is W×H (e.g. 2048×2048); adjust for your resolution
draw_rectangle(x=0, y=0, w=W, h=1, color="#00000000", filled=True)    # top row
draw_rectangle(x=0, y=H-1, w=W, h=1, color="#00000000", filled=True)  # bottom row
draw_rectangle(x=0, y=0, w=1, h=H, color="#00000000", filled=True)    # left col
draw_rectangle(x=W-1, y=0, w=1, h=H, color="#00000000", filled=True)  # right col
```

Apply this after every `import_image` call on an MJ source PNG. Use actual pixel dimensions
returned by `get_sprite_info` for W and H.

**`tolerance=15` alternative:** `fill_area` with `tolerance=15` on a corner pixel can catch the
near-black edge region, but risks bleeding into legitimate dark outline pixels on complex
silhouettes. The explicit 4-strip clear is safer and has no false-positive risk.

---

## Canonical pipeline ordering

**Always work RGB → indexed. Never reverse.**

```
1. import_image        — load MJ PNG (RGB, typically 2048×2048)
2. [crop/mask pass]    — remove background, isolate character silhouette
3. scale_sprite        — downsample to intermediate square (see aspect-ratio section below)
4. crop_sprite         — cut to final non-square target dimensions (e.g. 32×48)
5. [pixel editing]     — draw_rectangle (not draw_pixels), fill_area (audit first)
6. quantize_palette    — convert to indexed, mapping to doctrine hex palette
7. export_sprite       — export final PNG
```

**Why this order matters:**

- Palette-locking before downscaling introduces dithering artifacts (MJ output is full-color
  high-res; locking pre-downscale puts the palette in the wrong scale).
- Pixel editing in RGB mode avoids the indexed `set_palette` trap described above.
- `quantize_palette` at step 6 is the single conversion point — once indexed, do not edit pixels.

This ordering matches the Aseprite manual pipeline described in
`team/priya-pl/art-pass-ai-primary-brief.md §2` ("Order matters").

---

## Aspect-ratio downsampling — MJ output is always square

Midjourney outputs square images (typically 2048×2048) regardless of the `--ar` flag behavior
observed in practice. A 32×48 target cannot be reached with a single `scale_sprite` call without
distorting the character's aspect ratio.

**Two-step pattern:**

```
1. scale_sprite to a square intermediate that fits the longer axis:
   e.g. for 32×48 target → scale to 48×48 (preserves aspect, adds headroom)

2. crop_sprite to the final target dimensions:
   e.g. crop_sprite(x=8, y=0, w=32, h=48)  # center-crop the 48×48 → 32×48
```

**Why not one step:** `scale_sprite` to a non-square target squashes or stretches the character.
The square-intermediate step preserves the source aspect ratio through downscaling; the crop step
removes the excess.

Choose the intermediate square size to be the **smallest integer multiple >= the longer target
dimension** to minimize quality loss from the nearest-neighbor resize.

---

## MJ prompt-engineering for downsample-bound sprites

When the game target is 32×32 or 48×32, the final sprite retains very few pixels — complex
silhouettes collapse into unreadable blobs. Prompt-engineering the MJ source to produce
**chunky, simple shapes** dramatically reduces re-rolls.

### Positive tokens that survive downsampling

| Token | Effect |
|---|---|
| `simple silhouette` | Pushes MJ away from detailed multi-part body parts |
| `head-on facing camera` | Produces a symmetric front-facing pose; maximises width budget |
| `four distinct paws` | Forces quadruped leg separation — avoids blob body |
| `prominent muzzle` | Ensures the head reads as a distinct shape at small scale |
| `stocky proportions` | Exaggerates readable mass; thin limbs disappear at 32 px |
| `bold 1-pixel dark outline` | Hardens silhouette edge; survives nearest-neighbor resize |

**Head-on pose rule (quadrupeds):** top-down RPG sprites of four-legged creatures almost always
need a **head-on camera angle** rather than a 45° three-quarter view. The three-quarter view
compresses one pair of legs behind the other at 32 px — you lose the quadruped read entirely.
Lock in `head-on facing camera` for any non-humanoid with multiple limbs.

### Anti-tokens that kill MJ defaults that don't survive downsampling

Always add these to the `--no` block for downsample-bound sprites:

| Token | Why |
|---|---|
| `ground shadow` | MJ default; shadow merges with the character blob at 32 px |
| `complex fur` | High-frequency texture detail; gone after nearest-neighbor resize |
| `background` | Any background element competes with silhouette at small scale |
| `multiple poses` | Forces MJ to show one clean pose, not a pose-sheet |
| `action lines` | Motion-blur artifacts collapse into dirty edge pixels |

### Worked evidence

**Grunt (32×48, humanoid):** standard skeleton + `readable silhouette` tokens were sufficient;
humanoid silhouettes are MJ-native. No special positive tokens needed beyond the universal set.

**Charger (32×32, quadruped):** first roll at 32×32 produced a blob; partially resolved at 48×32
but still required re-rolls. Adding `head-on facing camera`, `four distinct paws`, `prominent
muzzle`, and `stocky proportions` to the prompt, plus `ground shadow`, `complex fur`, `background`
to `--no`, produced a clean quadruped read that survived the downsample.

### Dimension floor by character complexity

| Character type | Minimum dimension | Rationale |
|---|---|---|
| Humanoid (Grunt, NPC, Player) | 32×32 (prefer 32×48) | Vertical silhouette reads at 32 px |
| Compact quadruped (Charger) | 48×32 or 32×32 with head-on prompt | Width budget tight; head-on mandatory |
| Boss / elite mob | 48×48 or larger | Visual weight relative to 32-px mobs |

If a 32×32 roll produces a blob at the cleanup inspect step, **bump to 48×32 before re-rolling.**
Re-rolling at the same dimension with the same prompt rarely recovers the silhouette problem; the
dimension change is often what unlocks a clean read.

Cross-reference: `team/priya-pl/art-pass-ai-primary-brief.md §1.5` — canonical per-character
target-dimension table.

---

## Windows path escape — MJ filenames starting with `u<digits>_`

Midjourney filenames frequently start with `u<digits>_` (e.g. `u1234_grunt_idle.png`). Under
Windows backslash paths, the `u` followed by hex digits is Unicode-escaped by some tools and
shells, corrupting the filename in tool parameters.

**Rule:** Always pass file paths to pixel-mcp tools using **forward slashes**, even on Windows.

```python
# Broken on Windows with backslash:
import_image(path="C:\\sprites\\u1234_grunt.png")

# Safe:
import_image(path="C:/sprites/u1234_grunt.png")
```

This applies to any pixel-mcp tool that takes a file path parameter.

---

## Doctrine palette lock — worked example (S1 Grunt)

When `quantize_palette` is used to lock a downscaled sprite to the doctrine palette, the palette
argument must contain **only** doctrine hexes for the relevant stratum. For the S1 Grunt baseline
(first execution 2026-05-17), the full color set passed to `quantize_palette` was:

**S1 mob doctrine ramp** (from `team/priya-pl/art-pass-ai-primary-brief.md §2` + `team/uma-ux/palette.md`):

| Role | Hex |
|---|---|
| Mob cloth (warm brown) | `#5A4738` |
| Mob skin (wash-out) | `#A0856B` |
| Aggro eye-glow | `#D24A3C` |
| Weapon edge (worn iron) | `#9C9590` |
| Ember accent (primary) | `#FF6A2A` |
| Ember accent (mid) | `#E04D14` |
| Ember accent (deep) | `#A02E08` |
| Ember light (highlight) | `#FFB066` |
| Deep shadow / outline | `#1A1210` |
| Hood interior dark 1 | `#2E2118` |
| Hood interior dark 2 | `#3D2E20` |

The last three entries (deep shadow, hood interior darks) are **environment hexes** extended from
the S1 stratum palette to handle the interior-of-hood darks that MJ outputs. They are not present
in the base mob-accent table in the brief but are doctrine-compliant S1 darks derived from the
stratum ramp. If a cleanup pass surfaces MJ-output darks not covered by existing palette entries,
extend the palette with the nearest S1-stratum dark — don't invent cross-stratum colors.

**Per-sprite palette extension rule:** the worked S1 Grunt example above is the template shape.
Future sprites use the same structure: base doctrine ramp for the stratum + mob-specific accents +
any shadow/dark extensions needed for the specific silhouette. Each new extension must trace to
the stratum palette in `palette.md` or `palette-stratum-N.md`; file a palette amendment ticket
via Uma's lane if no doctrine hex covers the needed dark.

---

## Checklist — before every pixel-mcp session

1. Use forward slashes in all file paths.
2. Never call `draw_pixels` — use `draw_rectangle(w=1, h=1, filled=True)` instead.
3. Before any `fill_area`: audit target color uniqueness with `get_pixels`.
4. Back up the source `.aseprite` file before `scale_sprite`.
5. Keep the canvas in RGB mode until all pixel editing is done; quantize once at the end.
6. For non-square targets: scale to square intermediate, then crop.
7. After `import_image`, clear the 4-perimeter strips with `draw_rectangle` before masking — MJ
   sources carry a near-pure-black edge that `fill_area tolerance=0` misses.

---

## Cross-references

- [`pixellab-pipeline.md`](pixellab-pipeline.md) — PixelLab source variant of this pipeline
  (canvas-size trap, quantize dupe-slot mitigation, doctrine-compliance strategies including
  per-slot nearest-neighbor and luminance-sort, cost model, `import_image` param trap); the
  pixel-mcp trap rules documented in THIS file apply to both pipelines equally
- `team/priya-pl/art-pass-ai-primary-brief.md §2` — palette discipline (hex-lock rules, no-invent
  rule, doctrine ramp sources, verification protocol)
- `team/priya-pl/art-pass-ai-primary-brief.md §4` — generate → downscale → palette-lock →
  frame-align → export canonical pipeline (Aseprite manual steps)
- `team/uma-ux/palette.md` — global palette doctrine (ember through-line, S1 authoritative ramp)
- `team/uma-ux/palette-stratum-2.md` — S2 authoritative palette + soft-retint pattern (§5)
