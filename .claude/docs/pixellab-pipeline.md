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

**Plan-tier context (as of 2026-05-17):** Sponsor is on **Tier 2 ($24/mo)** with a
**2000-generation monthly allowance** — confirmed and active after the Charger + Grunt
free-trial validation passed. M3 art-pass roster (9 characters × idle + 3 template animations)
≈ 225 generations, fitting comfortably in one Tier 2 month with ~10× headroom for re-rolls.

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
