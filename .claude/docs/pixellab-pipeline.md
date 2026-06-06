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

---

## `create_topdown_tileset` is a terrain-TRANSITION tool — NOT for a uniform crafted floor

Validated 2026-06-06 (S1 tile upgrade `86ca44p4j`, 2 passes). `create_topdown_tileset` is a **Wang/autotile generator for terrain boundaries** (grass↔water↔sand). It takes `lower_description` + `upper_description` and produces 16 corner-based tiles whose whole purpose is the *transition* between two terrains. Consequences when (mis)used for a single crafted surface like a cloister flagstone floor:

- **lower ≠ upper (even subtly):** the autotiler renders one terrain as a PATH/ISLAND over the other as a FIELD. Pass 1 (`lower="dark mortar"` / `upper="flagstone"`, transition 0.5) → beige flagstone **islands in big dark channels**. Pass 2 (`lower="sunken flagstone"` / `upper="foot-worn flagstone"`, transition 0.25) → a beige **path winding over a grey field**. Both are two-zone maps, not a continuous floor.
- **lower == upper (identical):** no terrain difference → the autotiler only ever places the "all-same" interior tile → a **flat uniform repeat** (the wallpaper failure you were trying to avoid). The tool's variation comes ONLY from corner-terrain differences, which are exactly the path/field split you don't want.

So the Wang tool gives you **path/field OR flat-repeat** — never "continuous floor, richly varied, seam-free." It is the right tool for an actual terrain edge (floor→pit, grass→stone), not for re-arting one surface.

**For a uniform crafted floor/wall surface, use a VARIANT-SET approach instead:** generate several individual seamless tile variants (`create_map_object` / `create_1_direction_object`, or pixel-mcp hand-craft for full control) — each a self-contained worn-stone tile with different crack/wear — then the game-side painter scatters them so no tile repeats in a run (matches the multi-variant-set intent in `team/uma-ux/s1-tile-rework.md` §2.2A). Mind seamlessness: object-gen does not guarantee edge-matching tiles; for a stone floor, mild edge mismatch reads as irregular grooves (acceptable), but verify tiled at game zoom. This corrects the spec's assumption that `create_topdown_tileset` would produce crafted floor/wall sets.

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
