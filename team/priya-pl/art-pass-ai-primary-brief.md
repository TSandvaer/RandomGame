# Art-Pass — AI-Primary Workflow Brief (Sponsor-DIY, v1 $100 Budget)

**Owner:** Priya · **Authored:** 2026-05-17 · **Status:** v1.0 — Sponsor-executable solo · **Ticket:** `86c9uu2gd` · **Driver:** Sponsor budget decision 2026-05-17 evening ($100 USD total external/cash; Midjourney subscription already owned). Commission path (PR #257, $24-65K Phase 1 mid-tier) is **shelved for v1**.

This doc replaces the commission outreach path. It is the **Sponsor-executable** workflow for producing M3's character art using Midjourney + Aseprite, with no external artist. The brief assumes the reader (Sponsor) is the one generating, cleaning, and committing the art.

## TL;DR (7 lines)

1. **Pipeline:** Midjourney prompt → high-res output → downscale to 32-px target → Aseprite palette-lock + frame-align → export to `assets/sprites/<mob>/<state>.png`. Sponsor labor: ~1.5-3 hours per character roster slot.
2. **Cost (v1):** $0 cash if Aseprite already owned; **~$20** one-time if not (Aseprite Steam license — bought once, owned forever; free alternatives Pixelorama / Libresprite documented in §7). Phase 1 total external spend: **$0-20**, well inside Sponsor's $100 envelope.
3. **Palette discipline is load-bearing.** Midjourney CANNOT natively palette-lock — the Aseprite cleanup pass is what makes this path tonally coherent. Without rigorous palette-lock, AI output drifts and the game looks like every other AI-pixel-art indie.
4. **Animation-frame consistency is the hardest part.** Multi-frame characters need seed-locked batch generation + img2img anchoring + hand-tweening for cycles. §9 documents the techniques.
5. **Quality bar:** silhouette legible at 32 px + palette matches doctrine hex codes + frame-to-frame coherence within a state. Below bar → regenerate (see §5 decision rule).
6. **Honest trade vs commission (§10):** sub-Crystal-Project visual feel; Sponsor-labor variance; palette-discipline depends on Sponsor's rigor; less stylistic differentiation from other AI-pixel-art indies. The trade-off is real and worth documenting; the choice is informed.
7. **Collaboration shape (§14.5):** Sponsor executes Midjourney + Aseprite; orchestrator (main session) provides per-asset prompts on-demand + cleanup help when asked. Brief is the **framework**; per-asset prompts are NOT baked in — they come fresh from orchestrator with doctrine applied. Sponsor doesn't carry doctrine in head; iteration stays cheap. Per auto-memory `m3-art-pass-collaboration-shape`.

## Phase 1 scope + total Sponsor-labor estimate

| Slot | Count | States | Effort (hrs/slot) | Phase 1 hrs |
|---|---|---|---|---|
| Player | 1 | 6 (idle / walk / attack-light / attack-heavy / dodge / hit / die) | 4-6 (most anim depth) | 4-6 |
| Mob archetypes | 6 (Grunt / Charger / Shooter / PracticeDummy / Stoker / Stratum1Boss) | 5 (idle / walk / attack-telegraph / attack / hit-react / die) | 1.5-2.5 | 9-15 |
| Hub-town NPCs | 3 (vendor / anvil / bounty-poster) | 2 (idle / talk-pose) | 1-1.5 | 3-4.5 |
| Pickup / chest / ember-bag retints | ~6 sprites | 1-2 each | 0.5 | ~3 |
| Per-stratum retint (S2 only in Phase 1) | ~10 sprites × 1 retint | n/a | 0.25 | ~2.5 |

**Phase 1 total Sponsor-labor: ~22-31 hours.** Rough conversion: ~3-4 full evenings (6-8 hrs each) or ~7-10 part-time evenings (3 hrs each). Realistic over 2-4 weeks of part-time work.

Phase 2+ (S3-S8 retints, M4 class divergence sprites if Sponsor pursues) is out-of-scope here; documented in §8 asset list as deferrable.

---

## §1 — Tonal anchor + style refs (ported from PR #257)

The visual identity stays unchanged from the commission brief. What changes is how the reference is communicated — instead of an artist-portfolio fit framing, the references become **prompt-engineering anchors** for Midjourney.

### Doctrine

- **Dark-folk-chamber.** Cellos, frame drum, felted piano, bronze bell — the audio direction's tonal vocabulary maps to the visual: muted, weighty, single warm focal point against deeper-darker fields. Not orchestral, not chiptune. Not cute. Not glossy.
- **Descent narrative.** Embergrave is a vertical journey through pressure / heat / depth / origin. S1 sandstone-cloister → S8 ember-on-black. Character art reads against this arc; the player and mobs ARE the visual constant the world reframes around.
- **Ember through-line.** `#FF6A2A` is the player's flame across all 8 strata. Every character sprite preserves this hex; the rest of the palette darkens / cools / shifts but the ember does not.

### Game references (use these in Midjourney prompts)

**Primary anchors:**
- **Crystal Project** — the shipped solo-dev pixel-art density Embergrave matches. 32-px character density; warm fantasy palette; readable silhouettes at small scale.
- **Octopath Traveler** — the sprite-clarity bar (HD-2D is different rendering; we want the sprite quality, not the lighting).
- **Hyper Light Drifter** — animation crispness, single warm light source, saturated accent on desaturated ground.

**Secondary illustration anchors:**
- **Mike Mignola** (Hellboy comics) — black-shadow + warm-accent illustration logic. Critical for the "single warm light" feel.
- **Sergio Toppi** — dense detail in tilesets; restraint in characters. Embergrave characters should read RESTRAINED, not busy.
- **Sleepy Hollow (1999, Burton)** — muted greens-and-greys with a single ember light source. Tonally the closest film reference.

### Anti-references (use these as NEGATIVE prompt tokens — explicit "do not include")

- **Stardew Valley** — too cozy; wrong tonal register.
- **Diablo III sprites** — glossy 3D-pre-rendered; wrong era + wrong style.
- **Cuphead** — heavy outlines + cel-shaded vector; budget mismatch.
- **Octopath HD-2D environments** — we want sprites, not the lighting model.
- **Photoreal anything.**
- **Anime / chibi** — wrong tonal register.

### Mapping to Midjourney prompt tokens

Reference names CAN be cited in Midjourney prompts but rarely produce the cited style directly. Instead, use **descriptor decomposition** — the qualities the reference embodies:

- "Crystal Project" → "32-bit pixel art, top-down RPG sprite, hand-painted feel, warm fantasy palette, readable silhouette at small scale"
- "Mignola" → "stark shadow areas, single warm light source, high contrast, illustrative restraint"
- "Sergio Toppi" → "controlled detail, no decorative bloat, silhouette-first composition"

This decomposition style is what actually drives Midjourney; reference-name citations alone produce inconsistent results.

---

## §2 — Palette discipline (load-bearing)

Midjourney CANNOT palette-lock natively. There is no "use only these hex codes" prompt that works reliably. The **Aseprite cleanup pass is what produces palette-coherent output;** without it, the project ships AI-typical hue drift and the visual identity dissolves.

### Hex-lock rules (ported from `palette.md` + `palette-stratum-2.md`)

**Ember-orange ramp (constant across all 8 strata):**

| Use | Hex |
|---|---|
| Ember accent (primary) | `#FF6A2A` |
| Ember accent (mid) | `#E04D14` |
| Ember accent (deep) | `#A02E08` |
| Ember light (highlight) | `#FFB066` |

**Status colors (cross-stratum, NEVER change per stratum):**

| Use | Hex |
|---|---|
| HP foreground / **mob aggro eye-glow** | `#D24A3C` |
| XP / heroic gear | `#E0B040` |
| Heal popup | `#7AC773` |

**S1 mob accents (canonical anchor for ALL character art):**

| Use | Hex |
|---|---|
| Mob cloth (warm brown) | `#5A4738` |
| Mob skin (wash-out) | `#A0856B` |
| Aggro eye-glow | `#D24A3C` |
| Weapon edge (worn iron) | `#9C9590` |

**S2 mob accents (heat-blasted miner family):**

| Use | Hex |
|---|---|
| Mob cloth (heat-corroded) | `#7A1F12` |
| Mob skin (sun-scorched) | `#7E5A40` |
| Aggro eye-glow | `#D24A3C` |
| Weapon edge | `#9C9590` |

### No-invent rule

**Never invent a new hex code.** Every color in every sprite must trace to a hex in `palette.md` or `palette-stratum-N.md`. If a sprite needs a color that doesn't exist in the docs, **stop** — file a one-line palette amendment ticket and route to Uma's lane for sign-off before committing the sprite. The discipline is the project's tonal coherence; breaking it is what makes AI pixel-art look "AI."

### How the cleanup pass enforces palette-lock

Three techniques in Aseprite, applied in order:

1. **Palette-import.** Create a `.gpl` palette file (or Aseprite-native palette) containing every doctrine hex from the relevant stratum's section in `palette.md`. Aseprite menu: `Palette → Load Palette` → paste hex codes. Save as `assets/palettes/<stratum>.gpl` so future cleanup passes reuse it. (Reuse W3-T3's pattern — `palette-stratum-2.md §5` describes this for the tile pipeline; characters follow the same shape.)

2. **Color-replace pass.** With the imported palette loaded, every non-doctrine pixel gets replaced by the nearest doctrine hex. Aseprite tool: `Sprite → Color Mode → Indexed` (Mode: Best Match for indexed; preserves transparency). The "Best Match" algorithm maps each off-palette pixel to its closest doctrine hex — usually correct, occasionally needs manual override (Sponsor catches outliers with eyedropper inspection).

3. **Indexed-color export.** Final PNG export with palette baked in (`File → Export Sprite → Color Mode: Indexed`). The exported file CANNOT contain off-palette pixels by definition. This is the audit-proof — load the PNG in any image editor with hex inspection and every pixel resolves to a doctrine hex.

**Order matters.** Generate first (Midjourney), then downscale, THEN palette-lock. Palette-locking before downscaling produces dithering artifacts (Midjourney output is full-color 1024-px; locking pre-downscale puts the palette in the wrong scale). Always: generate → downscale → palette-lock → frame-align → export.

### Verification protocol per sprite

Before committing any sprite to the repo:

1. Open the exported PNG in Aseprite.
2. `Sprite → Color Mode` → confirm "Indexed."
3. `Window → Palette` → confirm the displayed palette matches the stratum's doctrine ramp.
4. Pixel-spot-check 3 random non-transparent pixels with eyedropper; confirm each is a doctrine hex.

This takes ~30 seconds per sprite and catches palette drift before it lands in `main`.

---

## §3 — Midjourney prompt patterns

### Universal skeleton

```
top-down RPG character sprite, 32-bit pixel art style, [character archetype],
[clothing/equipment], [pose/animation state], hand-painted pixel feel,
warm fantasy color palette, single warm light source from above, dark folk
fantasy aesthetic, readable silhouette, --ar 1:1 --style raw --no [anti-tokens]
```

**Anti-tokens (always include in `--no`):**

```
--no anti-aliasing, smooth, 3D render, photoreal, gloss, vector, cel-shaded,
cute, chibi, anime, watercolor, watercolor edges, modern UI, HUD overlay,
text, logo, frame, border, white background
```

The anti-aliasing token is critical — without it Midjourney outputs softened edges that defeat the pixel-art look. The "white background" anti-token forces the sprite onto a neutral field that's easier to mask in cleanup.

### Per-character prompts (Phase 1 roster) — ILLUSTRATIVE STARTING POINTS

> **Important framing per §14.5 (Sponsor-Orchestrator collaboration loop):** the per-character prompts below are **illustrative starting points the brief bakes for reference**, not the prompts Sponsor will use during execution. Real prompts come from the orchestrator on-demand when Sponsor signals "ready to generate character X" — orchestrator composes a fresh prompt using §3 skeleton + §1 tonal anchors + §2 palette doctrine + §3 anti-tokens, reflecting Sponsor's current execution state. Treat the examples below as worked illustrations of the prompt-shape, not as the recipes to copy.

Each prompt is a **starting point**, not a finished recipe. Sponsor iterates: generate 4-image grid, pick best variant, regenerate variations on that (Midjourney `V1`-`V4` buttons), select final.

**Player**

```
top-down RPG character sprite, 32-bit pixel art, hooded human warrior with
worn iron sword, neutral idle stance facing camera, leather and cloth armor
in warm brown #5A4738 and worn iron #9C9590, ember-orange glow at chest
suggesting inner flame, 1-pixel dark outline silhouette, hand-painted pixel
feel, single warm light source from above, dark folk fantasy aesthetic,
readable silhouette at 32px, --ar 1:1 --style raw --no [anti-tokens]
```

Variations for state cycles (idle / walk / attack-light / attack-heavy / dodge / hit / die): change "neutral idle stance" → "mid-walk step" / "sword raised mid-swing" / "heavy two-handed downward strike" / "rolling dodge motion" / "stumble backward hit reaction" / "collapsing forward death pose."

**Grunt (S1 hooded monk archetype)**

```
top-down RPG enemy sprite, 32-bit pixel art, hooded human cultist in tattered
brown robes #5A4738, wash-out skin tone #A0856B, glowing red eyes #D24A3C
under hood, holding worn rusty short blade, hostile lean-forward stance,
1-pixel dark outline, hand-painted pixel feel, single warm light source from
above, dark folk fantasy, readable silhouette, --ar 1:1 --style raw
--no [anti-tokens]
```

**Charger (S1 bestial four-legged)**

```
top-down RPG enemy sprite, 32-bit pixel art, low quadrupedal creature,
matted fur in warm brown #5A4738, glowing red eyes #D24A3C, exposed teeth,
muscular shoulders, mid-charge running pose, 1-pixel dark outline, hand-
painted pixel feel, single warm light source, dark folk fantasy, readable
silhouette, --ar 1:1 --style raw --no [anti-tokens]
```

**Shooter (S1 skeletal-archer)**

```
top-down RPG enemy sprite, 32-bit pixel art, skeletal archer in faded cloak
#5A4738, bone-white face #C9C2B2 (T1 worn hex), glowing red eyes #D24A3C,
holding aged longbow drawn back, lean-back firing stance, 1-pixel dark
outline, hand-painted pixel feel, single warm light, dark folk fantasy,
readable silhouette, --ar 1:1 --style raw --no [anti-tokens]
```

**Stratum1Boss (S1 Warden — deep red doctrine `#7A1F29`)**

```
top-down RPG boss sprite, 32-bit pixel art, hulking armored warden in
heavy iron plate, deep red surcoat #7A1F29, glowing red helmet visor
#D24A3C, two-handed flanged mace, imposing stance facing camera, 1-pixel
dark outline, hand-painted pixel feel, single warm light source from above,
dark folk fantasy, readable silhouette at 48px (slightly larger than mobs),
--ar 1:1 --style raw --no [anti-tokens]
```

**Stoker (S2 heat-blasted miner — retint of Grunt silhouette per `palette-stratum-2.md §5`)**

```
top-down RPG enemy sprite, 32-bit pixel art, soot-blackened human miner in
heat-corroded smock #7A1F12, sun-scorched skin #7E5A40, glowing red eyes
#D24A3C, holding rusted mining pick, hostile crouched stance, 1-pixel dark
outline, hand-painted pixel feel, single warm light source, dark folk
fantasy, readable silhouette, --ar 1:1 --style raw --no [anti-tokens]
```

**PracticeDummy** (training target, no animation states beyond idle + hit)

```
top-down RPG training-dummy sprite, 32-bit pixel art, wooden post with
straw-padded humanoid silhouette wrapped in faded burlap #B8AC8E, dark wood
base #4A3F2E, no facial features, simple sturdy stance, 1-pixel dark
outline, hand-painted pixel feel, single warm light, dark folk fantasy,
readable silhouette, --ar 1:1 --style raw --no [anti-tokens]
```

**Hub-town NPCs (3)**

- **Vendor:** "robed merchant in warm bronze cloak `#9A7A4E`, parchment-toned hood `#D7C68F`, neutral standing pose, holding open ledger book..."
- **Anvil-keeper:** "burly smith with leather apron `#5A4738`, bare arms with soot smudges, holding small hammer, neutral standing pose by implied anvil..."
- **Bounty-poster:** "lean cloaked lore-keeper, hood drawn deep, parchment scroll in one hand `#D7C68F`, neutral standing pose..."

### Per-state prompt deltas (delta from idle baseline)

For each character, the 5-6 anim states reuse the character description but change the action verb + pose:

| State | Verb fragment | Frame count |
|---|---|---|
| idle | "neutral standing pose, slight breathing" | 4 |
| walk | "mid-step walking pose" | 8 |
| attack-telegraph | "windup pose, weapon raised back" | 4 |
| attack | "mid-swing pose, weapon at strike point" | 6 |
| hit-react | "stumble back hit reaction, pained expression" | 3 |
| die | "collapsing forward, weapon falling" | 8 |

Frame counts match `visual-direction.md §"Animation feel"`. The cleanup pass converts the 4-image Midjourney grid into the frame count needed (often via hand-tweening — see §9).

---

## §4 — Generation → cleanup pipeline (step-by-step)

The canonical Sponsor workflow. Each step is concrete; the whole pipeline takes ~1.5-3 hours per character roster slot.

### Step 1 — Generate (Midjourney, ~10-30 min/character)

1. Submit the per-character prompt from §3 to Midjourney via Discord or web UI.
2. Receive a 4-image grid at full resolution (1024×1024 or similar).
3. Visually evaluate: silhouette legible? doctrine palette implied (not exact — that's the cleanup pass)? anatomy intact?
4. **Iterate.** If no variant in the grid is usable: regenerate with a slight prompt tweak (move adjective order, add a stronger style anchor like "in the style of Crystal Project pixel sprites"). If 1-2 variants are close: use Midjourney's `V1`-`V4` buttons to generate variations on the best candidate. 2-3 iteration cycles is normal.
5. Pick the final variant. Download as PNG.

**Quality gate at this step (decision rule — §5):** silhouette legibility + anatomy correctness. Palette + pixel-perfection happen in cleanup; don't reject for those at this step.

### Step 2 — Downscale (Aseprite or any pixel-aware tool, ~5 min/character)

The Midjourney output is high-res (1024×1024). The game's target sprite is 32×48 (player) or similar. Direct downscale destroys silhouette; need a careful path:

1. **Open the Midjourney PNG in Aseprite.**
2. **Crop tight** to the character silhouette (remove background, leaving ~10% margin). `Image → Trim` after a mask-by-color cleanup.
3. **Resize.** `Sprite → Sprite Size` → set new size to the target (e.g. 32×48 for player; 32×32 for Grunt). Resize algorithm: **Rotsprite** (best for pixel art) or **Nearest Neighbor** (sharper but blockier). Avoid bilinear / bicubic — they introduce anti-aliasing that defeats the pixel-art look.
4. **Inspect.** At target size, the silhouette should still be legible. If it's not — the source generation was too detailed; regenerate with stronger "readable silhouette" anchoring.
5. **Save as PNG** to a scratch folder (NOT the repo yet — cleanup happens before commit).

> **MJ output is square — use a two-step downscale for non-square targets.**
> Midjourney outputs square images (typically 2048×2048). Scaling directly to a non-square target
> (e.g. 32×48) distorts the character's aspect ratio. Instead: (1) scale to the smallest square
> >= your longer target axis (e.g. 48×48 for a 32×48 target), then (2) crop to the final
> dimensions (e.g. center-crop 48×48 → 32×48). See
> `.claude/docs/pixel-mcp-pipeline.md §Aspect-ratio downsampling` for the canonical agent-side
> procedure when using pixel-mcp tools.

### Step 3 — Palette-lock (Aseprite, ~15 min/character)

Apply the §2 palette discipline. Concrete steps:

1. `Palette → Load Palette` → load `assets/palettes/<stratum>.gpl` (the doctrine hex file).
2. `Sprite → Color Mode → Indexed` with Mode: **Best Match**. Aseprite remaps every pixel to the nearest doctrine hex.
3. **Eyedropper-spot-check.** Pick 5 random non-transparent pixels; confirm each is a doctrine hex.
4. **Manual override.** If "Best Match" picked a wrong-feeling hex (e.g. mapped a mid-tone to deep-shadow), use Aseprite's `Color → Replace Color` to swap that specific hex for the correct doctrine one. Repeat per problem area.

**Rule:** every pixel in the final sprite traces to a doctrine hex. No exceptions.

### Step 4 — Frame-align (Aseprite, ~30-60 min/character — most labor-intensive step)

The Midjourney output produces ONE pose per generation. The game needs **frame cycles**: 4-8 frames per state. Three techniques to build the cycle (§9 deep-dives):

- **Seed-lock batch generation** — multiple coherent poses from a single prompt seed.
- **img2img anchoring** — feed frame N back to Midjourney to generate frame N+1.
- **Hand-tweening** — author intermediate frames by editing the pose anchor.

Hand-tweening is the most reliable for short cycles (4 frames idle, 6 frames attack). Seed-lock and img2img scale better for longer cycles (8-frame walk).

### Step 5 — Export (Aseprite, ~5 min/character)

1. **Aseprite source file.** Save the `.aseprite` to `assets/sprites/<character>/source.aseprite`. The `.aseprite` is the single source of truth — every future edit happens here, not on the PNG.
2. **Sprite sheet export.** `File → Export Sprite Sheet` → output PNG with each frame in a horizontal strip. Naming: `assets/sprites/<character>/<state>.png` (e.g. `assets/sprites/grunt/idle.png`, `walk.png`, etc.).
3. **Verify indexed.** Open the exported PNG in any inspector; confirm Color Mode: Indexed and palette matches doctrine.
4. **Commit BOTH the `.aseprite` AND the PNGs** to the same PR. CI hook detects stale exports (a `.aseprite` edit without paired `.png` re-export = CI fail).

### Step 6 — Engine integration (when ready to land sprite swap PR)

This is the **engineering-side step** (per `m3-design-seeds.md §4 Asset pipeline`). Drew or Devon does this; Sponsor does NOT need to touch it:

- Swap the mob's `Sprite` child from `ColorRect` to `Sprite2D` with the exported PNG as texture.
- The `_play_hit_flash` modulate-cascade per `.claude/docs/combat-architecture.md § "Mob hit-flash"` is preserved; only the visible texture changes.
- Paired tests update: rest-color assertions become "modulate matches hex"; tween targets stay the same.

Per `m3-design-seeds.md §4`, this is ~1-2 dev-hours per mob and is independent of Sponsor's art labor. Sponsor produces the PNGs; the dev team consumes them.

---

## §5 — Quality bar + re-generation triggers

The hardest decision in this workflow is **regenerate vs cleanup-harder**. Regenerating burns 10-30 min and Midjourney generation credits; cleaning-harder burns Sponsor labor. Pick wrong on every sprite and Phase 1 stretches from 22-31 hours to 60+ hours.

### Quality bar (per sprite — must clear all 4 to ship)

1. **Silhouette legible at target size.** Block out the sprite at 32×32 in a screenshot; can you identify the character from silhouette alone (no color, no detail)? If not, regenerate.
2. **Palette doctrine-clean.** Every pixel traces to a doctrine hex (§2 verification). Non-doctrine pixels = cleanup-harder OR regenerate.
3. **Anatomy intact.** Two arms, two legs, one head, no extra fingers, no impossible joint angles. AI hands are notoriously bad — if hands are visible, scrutinize. If anatomy is broken: regenerate (cleanup-harder rarely fixes anatomy).
4. **Frame-cycle coherence.** If this sprite is part of a multi-frame cycle (idle, walk, attack), does it match the other frames? Same character identity, same equipment, same silhouette mass? If not — investigate per §9.

### Decision rule: regenerate vs cleanup-harder

**Regenerate when:**
- Silhouette unreadable at 32 px (gate 1 fail).
- Anatomy structurally broken (gate 3 fail — extra limb, impossible pose).
- Character identity wrong (e.g. you asked for a hooded monk and got an unhooded knight).
- ≥3 of the 4 quality gates fail — cleanup-harder costs more than re-rolling 4-image grid.

**Cleanup-harder when:**
- Silhouette correct but palette drift (gate 2 fail) — palette-lock pass fixes this.
- Anatomy intact but proportions slightly off — hand-edit in Aseprite (~10 min).
- Frame consistent with siblings except for one detail (e.g. wrong weapon color) — color-replace fix (~5 min).
- 1-2 gates fail and the failures are surface-level (texture, hue, single anatomical fix).

### The diagnostic-traces-before-fixes lesson applied

Per memory `diagnostic-traces-before-hypothesized-fixes`: **before regenerating a "bad" sprite, identify WHY it's bad with empirical evidence, not a hypothesis.** Eyedrop the off-palette pixels. Screenshot the silhouette at 32 px. Compare frame N to frame N-1 with overlay. Only then decide.

The trap: regenerating a sprite that was 90% there because "it felt off" — losing 20 minutes of cleanup progress to chase a hypothesized fix. Better to spend 5 minutes diagnosing the specific problem and 10 minutes targeted-fixing than to gamble on a fresh roll.

### Quality-variance honest framing

AI output is **stochastic**. You will roll 4-image grids where all 4 fail every gate; you will also roll grids where the first variant is shippable with 5 minutes of cleanup. Average cycle is 2-3 iterations per character. **Don't assume the first roll is the floor** — sometimes it's the ceiling. Always evaluate against the gates, not against "is this my best yet."

---

## §6 — Time budget per character + total Phase 1 labor

Per-character estimates (median Sponsor labor; assumes Aseprite competence + 1-2 Midjourney iterations to find usable base output):

| Character class | Generation | Downscale | Palette-lock | Frame-align | Export | Total |
|---|---|---|---|---|---|---|
| Player (6 states, most depth) | 30-60 min | 15 min | 30 min | 90-180 min | 10 min | **3-5 hrs** |
| Mob archetype (5 states) | 20-40 min | 10 min | 20 min | 60-90 min | 10 min | **2-2.5 hrs** |
| Hub-town NPC (2 states, simpler) | 15-25 min | 5 min | 10 min | 30 min | 5 min | **1-1.5 hrs** |
| Retint pass (palette swap of existing) | 0 min | 0 min | 5 min | 15 min | 5 min | **0.5 hrs** |

**Phase 1 total (per the table at top of doc): ~22-31 hours.**

### Where time actually goes

The dominant cost is **frame-align** (Step 4). Single-frame generation is cheap (Midjourney does it for you); turning 1 frame into a coherent 6-frame cycle is hand-labor. Sponsor should NOT expect Midjourney to produce 4-frame walk cycles natively — it can't.

### Acceleration tactics

If labor estimates are too high:

1. **Use Stoker as Grunt retint** (per `palette-stratum-2.md §5`). Same silhouette + animation cycle; only palette differs. Cuts ~2 hrs.
2. **Reuse hub-town NPC bodies across roles.** Three NPCs can share a torso template with different head + prop overlays. Cuts ~1.5 hrs.
3. **Skip PracticeDummy attack animations.** It's a training dummy; idle + hit-react are sufficient. Cuts ~0.5 hrs.
4. **Defer S2 retint to Phase 1.5.** Ship Phase 1 with S1 sprites only; S2 retint when S2 boss room lands. Cuts ~2.5 hrs.

Aggressive trim: ~6.5 hrs cut → Phase 1 in **15-25 hours**. Realistic over 2-3 weeks of evenings.

---

## §7 — Tool stack ($0-20 incremental)

Sponsor already owns Midjourney. The only question is the pixel-art editor.

### Required tools

**Midjourney** — generation engine. Sponsor owns. Subscription is the only ongoing cost (Sponsor's existing budget covers it). $0 incremental.

**Aseprite (recommended)** — palette-lock, frame-align, sprite-sheet export. **$19.99 USD one-time on Steam** or $19.99 from the official site. One-time purchase, owned forever, used for every sprite in the project's lifetime. Best-in-class pixel-art tool. **Recommended.**

### Free alternatives (if Sponsor wants $0)

**Pixelorama** — free, open-source pixel-art editor. Has frame timeline, palette management, color-mode controls. **Less polished than Aseprite** (fewer keyboard shortcuts, slower for complex multi-layer work) but functional. Download: https://orama-interactive.itch.io/pixelorama. **$0.**

**Libresprite** — fork of the pre-paid version of Aseprite. Free, open-source. Older feature set than current Aseprite but covers palette-lock + sprite-sheet export. **$0.**

**GIMP** — general-purpose editor; not pixel-art-native but workable with the right plugin (PixelArt plugin or manual nearest-neighbor pipeline). **Slowest of the alternatives** for sprite workflow. **$0.**

### Recommendation

**Buy Aseprite ($20).** The labor savings over Pixelorama / Libresprite recoup the $20 in the first few characters. Aseprite's palette-import + indexed-color export workflow is *built for* the cleanup pipeline this brief describes; the free alternatives require more manual steps to achieve the same output. If $20 is unacceptable, **Pixelorama is the best free alternative** — same conceptual workflow, slightly slower execution.

### Anti-recommendation

- **Photoshop / Illustrator** — overkill, expensive, not pixel-art-native. Anti-aliasing defaults work against the pipeline.
- **Generic AI upscalers** for pixel-art (waifu2x, etc.) — wrong tool; they produce smooth-edged output, not pixel-art.
- **Online sprite-sheet generators** — quality variance is high; none preserves palette discipline.

---

## §8 — Asset list (Phase 1 scope)

Same scope as PR #257's commission brief — DIY-paced rather than commission-scheduled. **~813 cells total** when including all states + retint variants:

### Phase 1 — must-ship (Sponsor labor commitment)

| Asset | States | Frames/state | Cells |
|---|---|---|---|
| Player | idle / walk / attack-light / attack-heavy / dodge / hit / die | 4/8/4/8/6/3/8 | ~41 base (× 4 directions = ~164) |
| Grunt | idle / walk / attack-telegraph / attack / hit-react / die | 4/8/4/6/3/8 | ~33 base (× 4 dir = ~132) |
| Charger | idle / walk / attack-telegraph / attack / hit-react / die | 4/8/4/6/3/8 | ~33 base (× 4 dir = ~132) |
| Shooter | idle / walk / attack-telegraph / attack / hit-react / die | 4/8/4/6/3/8 | ~33 base (× 4 dir = ~132) |
| Stratum1Boss | idle / walk / attack-telegraph-A / attack-A / attack-telegraph-B / attack-B / hit-react / die | 4/8/4/6/4/8/3/12 | ~49 base (× 4 dir = ~196) |
| Stoker (S2 retint of Grunt) | same as Grunt | same | ~33 base (palette-swap; no new authoring) |
| PracticeDummy | idle / hit-react / die | 4/3/8 | ~15 base (× 1 dir = ~15) |
| Vendor NPC | idle / talk | 4/4 | ~8 |
| Anvil-keeper NPC | idle / talk | 4/4 | ~8 |
| Bounty-poster NPC | idle / talk | 4/4 | ~8 |
| Pickup sprite | bounce / rest | 6/1 | ~7 |
| Stash chest | idle / open / close | 4/4/4 | ~12 |
| Ember-bag | idle (ember mote anim) | 4 | ~4 |

**Phase 1 cell total: ~813 cells (matches PR #257 commission brief estimate).** With 4-directional cardinal, that's the high estimate; 4-direction-mirrored (left = mirror of right) cuts to ~440 cells. Phase 1 should ship 4-directional cardinal for the player + 4-directional-mirrored for mobs/NPCs (cheaper authoring per `visual-direction.md`'s open-question note on outline).

### Phase 1.5 — Sponsor-optional Phase 1 cuts (per §6 acceleration tactics)

- **PracticeDummy reduce to idle + hit-react only** — saves ~7 cells.
- **NPC reduce to 1 state (idle only)** — saves ~12 cells.
- **Stash chest single-state** — saves ~8 cells.

Aggressive Phase 1 floor: **~786 cells** (3% cut, ~1 hr saved). Phase 1 doesn't reduce meaningfully without dropping characters entirely.

### Phase 2+ — deferred (out-of-scope for $100 v1)

- **S2 environment retints** — covered in Drew's W3-T3 / `palette-stratum-2.md §5` retint pattern. Drew handles tile retints; Sponsor handles mob/NPC retints. The S2 mob retint (Stoker = Grunt palette-swap) IS in Phase 1; S3-S8 retints are Phase 2.
- **S3-S8 mob retints** — ~6 mobs × 6 strata = 36 retint passes. ~18 hrs Sponsor labor. Phase 2 timing aligns with S3+ design work.
- **M4 class divergence sprites** — if Sponsor picks class divergence as M4 headline (per `m3-design-seeds.md §1.2` recommended deferral), 2-3 additional player-class authoring rounds. Same pipeline; ~10-15 hrs each.

### What's NOT in this brief

- **Environment tile art** — Drew owns per `palette-stratum-2.md §5` retint pattern + S3-S8 directional palettes in `palette.md`. Sponsor is **character-only** under this brief.
- **UI / HUD chrome** — cross-stratum constant; unchanged from M1/M2.
- **Hand-drawn dialog portraits** (Shape C narrative-portrait style) — out-of-scope for Shape A; if Sponsor pivots to Shape C in M4, separate brief.
- **Item icons** — 24×24 internal; already shipping; not regenerated under this brief.
- **Engine-authored effects** (CPUParticles2D, ember-mote shaders, hit-flash modulate) — engineering lane, unchanged.

---

## §9 — Animation-frame consistency (the hardest part)

This is the section the commission brief did NOT need to cover, because commissioned artists handle frame-coherence as a baseline professional skill. With AI-primary, **frame consistency is the load-bearing technical problem** — Midjourney outputs ONE pose per generation; turning one pose into a coherent multi-frame cycle is where most projects fail.

### The core problem

Midjourney's default generation is **stateless** — every prompt produces a fresh interpretation of the description. Generate the Grunt twice with the same prompt and you get TWO Grunts: similar enough to be the same archetype, different enough that frame N looks like a different character than frame N+1. Without coherence techniques, AI-generated animation cycles look like a flipbook of related-but-different characters.

### Technique 1 — Seed-lock + variation grid (best for short cycles, 4-6 frames)

**Pattern:**

1. Submit the base character prompt to Midjourney. Receive 4-image grid.
2. Pick the best variant. Note Midjourney's seed value (visible in image metadata or generation log).
3. Generate variations on that variant via `V1`-`V4` buttons. These variations **use the same seed** with small parameter shifts — produces poses that share the underlying character identity.
4. Generate 3-5 variation passes; pick the poses that best fit the frame sequence (e.g. for idle: pick the 4 closest variants and use them as the 4 idle frames).

**Limitations:**
- Works best when frames are **similar poses** (idle breathing, slight stance shifts). Doesn't work for cycles with large pose deltas (e.g. walk: leg positions change dramatically).
- Costs more generation credits — 3-5 variation rounds per character.
- Frame-to-frame consistency is still imperfect; hand-cleanup needed for outliers.

### Technique 2 — img2img anchoring (best for medium-pose-delta cycles, 6-8 frames)

**Pattern:**

1. Generate frame 1 normally.
2. For frame 2: use Midjourney's `Vary (Region)` or upload frame 1 as an image-prompt, with a prompt describing the new pose (e.g. "same character, mid-stride walking"). Midjourney generates frame 2 anchored to frame 1's character identity.
3. Repeat for frame 3 anchored to frame 2, frame 4 anchored to frame 3, etc.

**Limitations:**
- Anchoring works in Midjourney V6+ but is imperfect; the character can drift over a long chain (frame 8 may look like a different character than frame 1).
- Mitigation: anchor every NEW frame to **frame 1**, not to the immediately-previous frame. This keeps drift bounded.
- Cost: each anchored generation is a fresh Midjourney roll. 8-frame cycle = 8 generations.

### Technique 3 — Hand-tweening (most reliable for short cycles; the load-bearing fallback)

**Pattern:**

1. Generate frame 1 and frame N (the two pose extremes) via §3 prompt patterns.
2. Pick the best variants of both; downscale + palette-lock both.
3. In Aseprite, copy frame 1 to a new layer; manually edit toward frame N's pose, producing frames 2, 3, ..., N-1.
4. Use Aseprite's onion-skin feature (`View → Show Onion Skin`) to see prev/next frames as ghosts while editing.

**Limitations:**
- Manual labor — ~5-15 min per intermediate frame.
- Quality bound by Sponsor's pixel-art skill at the moment of authoring.
- BUT: **most reliable for character identity coherence** (Sponsor IS preserving identity, not gambling on Midjourney to do it).

**This is the workflow's load-bearing technique.** Sponsor should expect to hand-tween at least 50% of frames in any cycle. The AI provides the pose anchors; the cleanup provides the connective tissue. Plan labor estimates against this.

### Combined recommended workflow per state

For a 6-frame attack-light cycle:

1. **Seed-lock** to generate the windup pose + the strike pose (2 frames as Midjourney rolls).
2. **Hand-tween** the 4 intermediate frames in Aseprite.
3. **Palette-lock** the whole cycle to doctrine hexes.

Total time per state: ~30-60 min. Total per 6-state mob: ~3-6 hours (matches §6 mob-archetype estimate).

### Honest framing on quality

**Frame consistency in AI pixel art is sub-par compared to commissioned art.** Even with all three techniques applied rigorously, AI-generated cycles will have:

- Subtle character-identity drift across long cycles (recognizable but not pixel-perfect).
- Anatomical jitter (a finger appears/disappears across frames).
- Occasional palette-drift before cleanup (caught in the verification pass, but adds labor).

Sponsor should expect to **rebuild** ~10-20% of frames after first-pass cycle assembly when the inconsistency is too jarring. This is normal; budget for it in the §6 time estimates (already included).

---

## §10 — Honest trade vs commission (what's lost)

The Sponsor budget decision is informed. This section documents what going AI-only **gives up** compared to the commission path (PR #257), so the trade is honest.

### What AI-primary delivers

- **$0-20 v1 cost** vs commission's $24-65K Phase 1 mid-tier.
- **Sponsor control** over the visual identity at every step.
- **Iterability** — Sponsor can regenerate any sprite in 1-3 hours if it doesn't feel right after playtesting.
- **No external coordination overhead** — no artist briefs, no quote rounds, no revision-cycle scheduling.
- **Pipeline reusable for Phase 2+ retints** at $0 incremental cost.

### What AI-primary loses

**1. Sub-Crystal-Project visual feel.**

Crystal Project's solo-dev shipped pixel-art is **hand-authored, palette-disciplined from day 1, animation-coherent at the frame level.** AI-primary even with rigorous cleanup will land **below that bar.** The gap is not "looks AI" (the cleanup pipeline hides most AI tells); the gap is **stylistic differentiation** — Crystal Project has a specific authored *feel* that an AI workflow can't replicate. Embergrave's AI-primary v1 will look like "competent indie pixel-art" rather than "this game has a visual identity."

Concrete trade: Embergrave's Steam-page screenshots will sell on **mechanical depth + tonal atmosphere + writing** rather than on **art identity**. The audio direction + palette doctrine + descent-narrative still carry tonal weight; the character art does not contribute to differentiation the way it would with commission.

**2. Longer Sponsor labor.**

Commission path: Sponsor reviews + approves; ~5-10 hrs total Sponsor time across Phase 1. AI-primary: Sponsor IS the artist; ~22-31 hrs Phase 1 (§6 estimate). **3-4× labor multiplier on Sponsor time**, replacing dollar cost with time cost.

Concrete trade: 22-31 hrs over 2-4 weeks part-time is non-trivial. If Sponsor's available time-budget is constrained (other M3 oversight, work-life, M4 planning), this becomes the actual M3 critical-path constraint — not the agent dev work.

**3. Palette-discipline depends on Sponsor's rigor.**

Commissioned artists with portfolio-fit alignment carry palette discipline as professional baseline. The Aseprite cleanup pass in this brief enforces palette-lock, but **only if Sponsor executes the pass rigorously every time.** A skipped verification step ships a sprite with off-palette pixels; one off-palette sprite degrades the project's tonal coherence noticeably.

Concrete trade: every sprite needs the 30-second §2 verification protocol. Skipping it on "obvious" sprites is the failure mode. **R-AI-CLEANUP risk** (proposed amendment to `risk-register.md` per §11) captures this.

**4. Frame-consistency floor is lower.**

Per §9, AI-generated cycles have sub-pixel jitter that hand-authored cycles don't. Visible during fast animations (walk cycles, attack cycles). Less visible during slow ones (idle, dying). Concrete trade: combat animations will read "slightly off" compared to commissioned-art alternatives. Mitigation: hand-tween rigorously, but the floor is still below commissioned baseline.

**5. Less stylistic differentiation from other AI-pixel-art indies.**

The 2024-2026 indie scene has many AI-pixel-art games. Most look interchangeable — Midjourney/SDXL outputs cluster around recognizable visual modes. Embergrave's tonal anchors (dark-folk-chamber, ember through-line) help, but the *art surface itself* will look familiar to anyone who's seen the genre.

Concrete trade: Embergrave's marketing can't lead with "look at our distinctive art" — has to lead with mechanics, audio, writing, tonal coherence.

**6. Less defensible against criticism.**

Some indie players + reviewers reject AI-generated art categorically. The cleanup pipeline produces output that is **technically not raw AI** (palette-locked, frame-aligned, hand-tweened ≥50%), but the workflow is AI-primary and Sponsor should be honest about that in marketing if asked.

Concrete trade: Steam reviews, marketing copy, press outreach — Sponsor faces a credibility question on art provenance that commission-path doesn't have.

### When the AI-primary trade is the right call

- **Budget is the actual constraint.** $100 vs $25K is not a "tighten the belt" trade; it's a "shipping vs not-shipping" trade. AI-primary makes shipping possible.
- **Mechanical / writing / audio identity carries the project.** Embergrave's competitive position rests on these — the art-pass is polish layer, not flag-planting feature.
- **Sponsor has 25+ hrs of available labor over 4 weeks.** Time-rich, money-poor profile.
- **Sponsor is comfortable with the visual ceiling** (competent indie pixel-art, not breakthrough).

### When the AI-primary trade is the wrong call

- **Budget shifts and commission becomes feasible.** If Sponsor's budget envelope grows to $5-10K+ post-v1, switch to a commission Phase 2; AI-primary Phase 1 can be retired or kept as fallback.
- **Player feedback signals art is the differentiation gap.** If post-M3 playtesters report "the systems are great but the art holds it back" as the dominant criticism, commission is the recovery path.
- **Sponsor labor becomes infeasible.** If 25+ hrs becomes 10 hrs over 8 weeks due to life constraints, the workflow's labor-cost dominates and a paid contractor for the cleanup pass becomes cheaper than Sponsor's time.

**The decision is informed and reversible.** AI-primary in v1 doesn't preclude commission in v2 — the Aseprite source files remain editable, the pipeline remains usable, and the spend envelope can shift any time.

---

## §11 — Risk amendment proposal (R-AI-CLEANUP)

Proposed v1.2 amendment to `team/priya-pl/risk-register.md` (separate amendment ticket if not in-scope here; flag retained as risk-register watchlist entry until that lands).

### R-AI-CLEANUP — AI cleanup-pipeline labor variance + frame-consistency hazard

- **Probability:** med (Sponsor-skill-dependent; AI-pipeline is empirically new to project)
- **Impact:** med
- **Why:** AI-primary art-pass workflow has two failure modes that the commission path does not face:
  - **Sponsor-labor variance.** §6 estimates 22-31 hrs Phase 1; first-time-through-the-pipeline reality may be 40-60 hrs as Sponsor builds Aseprite competence + iterates on Midjourney prompt patterns. If labor exceeds 1.5× the estimate, M3 timing pressure shifts to art-pass and other tracks idle.
  - **Frame-consistency hazard.** §9 documents three techniques (seed-lock / img2img / hand-tween); rigorous application produces acceptable frame coherence, but missed verification steps ship sprites with anatomical jitter or palette drift. Hard to catch in headless tests (visual-only failure mode); only Sponsor-soak + HTML5 visual-verification gate surface it.
- **Mitigation:**
  - **§5 quality bar + decision rule** (regenerate vs cleanup-harder) — prevents Sponsor from over-iterating or under-iterating.
  - **§2 verification protocol per sprite** (30-second eyedrop check) — catches palette drift before commit.
  - **§9 hand-tweening as load-bearing technique** — sets expectation that 50%+ of frames are hand-authored; Sponsor budgets time accordingly.
  - **§6 acceleration tactics** — if labor exceeds estimate, Stoker-retint / NPC-reuse / PracticeDummy-trim cuts ~6.5 hrs.
  - **Scope-down floor (per `m3-design-seeds.md §4 Risks`):** if art-pass slips, ship S1-only character art + hex-block fallback for S2-S8. Already pre-committed mitigation; AI-primary keeps it as the safety net.
  - **HTML5 visual-verification gate** per `.claude/docs/html5-export.md`: every PR that lands a new character sprite must clear the visual-verification gate (Self-Test Report with screenshot/screen-recording from HTML5 release-build).
- **Trigger / signal:** Sponsor labor exceeds 1.5× §6 estimate at any per-character measurement; OR Sponsor-soak surfaces "this sprite looks wrong" findings on ≥2 sprites in one soak (frame-consistency or palette-drift). Either signal triggers an audit of the cleanup-pass discipline.
- **Evidence:** None yet (workflow is v1, untested). First evidence point: Sponsor's first per-character end-to-end execution (any of Grunt / Player / Stoker) — labor measured, output graded against quality bar.
- **Owner:** Sponsor (executes pipeline), Priya (gate via quality bar + decision rule), Uma (palette-doctrine audit on Sponsor-soak findings if R-AI-CLEANUP fires).

**Filed against:** `risk-register.md` Top-5 watchlist (probability med, impact med → watchlist not top-5). Promote to top-5 if Sponsor's first per-character end-to-end shows labor >1.5× estimate.

---

## §12 — Amendment to `m3-tier-1-plan.md §3` (recharacterize from commission to AI-primary)

The amendment ticket `86c9utcx8` (v1.1 amendment to `m3-tier-1-plan.md`) absorbs this recharacterization:

### Current §3 framing (commission-shaped)

> **Sub-milestone §3 — Character-art pass external estimate (Sponsor-routed, Priya-supported)**
>
> **Why first:** Per `m3-design-seeds.md §4` cost-bracket section, character-art pass cost is **not defensibly internally-estimable** — Sponsor must commission 2-3 external pixel-art artist quotes. **Lead-time on a 3-artist estimate is ~2-3 weeks**...

### Proposed §3 framing (AI-primary-shaped)

> **Sub-milestone §3 — Character-art pass AI-primary execution (Sponsor-DIY, Priya-supported)**
>
> **Why first:** Per Sponsor budget decision 2026-05-17 ($100 USD v1 envelope; commission shelved), character-art pass shifts to Sponsor-DIY workflow using Midjourney + Aseprite. The brief at `team/priya-pl/art-pass-ai-primary-brief.md` is the source of truth; Sponsor executes the pipeline per §3-T1 ticket. **Lead-time on character-art is no longer artist-quote-bound** — Sponsor begins Phase 1 immediately, paced at ~22-31 hrs over 2-4 weeks part-time. **Brief authoring is M3 Tier 1; Sponsor execution is parallel to all M3 Tier 1 + Tier 2 dev work** — same parallel-track shape as commission, just Sponsor-as-artist instead of external commission.
>
> **Scope:** Priya authors `team/priya-pl/art-pass-ai-primary-brief.md` (this doc — already landed); Sponsor executes the pipeline per the brief. Per-character order: Grunt (lowest-stakes archetype; pipeline validation) → Player (highest-visibility) → other mob archetypes → NPCs → retints. Sponsor labor is the cost; cleanup pipeline discipline is the load-bearing constraint.
>
> **Dependencies:** None for the brief authoring (landed). Sponsor execution depends on Aseprite competence (small ramp; ~2-3 hrs first-time) + Midjourney subscription (already owned). No agent-dev dependency; no engine-side dependency.
>
> **Sequencing:** **Brief authoring is M3 Tier 1 (landed). Sponsor execution is parallel to ALL of M3 Tier 1 + Tier 2 dev work.** Estimated 2-4 weeks of part-time Sponsor labor for Phase 1 (~22-31 hrs total per `art-pass-ai-primary-brief.md §6`). No dispatch-gating event; Sponsor ships sprites at own pace. **Hex-block fallback per `m3-design-seeds.md §4 Risks` is preserved as safety net** — Embergrave M3 ships mechanically-complete even if art-pass slips.

The amendment ticket `86c9utcx8` should absorb this rewrite in §3 of `m3-tier-1-plan.md`. The §3-T1 ticket (`86c9uth7g`) — currently named for the commission brief — should be either closed (commission path shelved) or re-pointed to this AI-primary brief as the deliverable; orchestrator + Sponsor align on which.

---

## §13 — Cross-references + status of PR #257

### PR #257 (commission brief) — status

- **State:** CLOSED (per Sponsor budget decision 2026-05-17 evening).
- **Disposition:** Closed unmerged. Uma's APPROVED_WITH_NITS review stood; artifact was sound but the path is shelved per the $100 v1 budget.
- **What changed:** Sponsor's budget envelope reframed the strategic question. The commission brief's quote-collection apparatus, per-cell pricing analysis, and artist-selection framework are now informational-only.
- **Where the work lives:** PR #257's body retained Priya's commission-brief content; this brief replaces it as the active art-pass source of truth.
- **Revisit trigger:** if Sponsor's budget envelope grows to ≥$5K+ in Phase 2, the commission brief becomes re-applicable as a Phase 2+ source. The Aseprite pipeline + AI cleanup discipline established here remain durable across either path.

### Cross-references

- **Doctrine sources:**
  - `team/uma-ux/visual-direction.md` — pixel-art density, 480×270 internal canvas, integer scaling, lighting model.
  - `team/uma-ux/palette.md` — global palette doctrine (ember through-line, S1 authoritative, indicative S3-S8).
  - `team/uma-ux/palette-stratum-2.md` — S2 authoritative palette; soft-retint pattern (§5).
  - `team/uma-ux/audio-direction.md` — tonal anchor (dark-folk chamber); paired aesthetic.
- **M3 framing:**
  - `team/priya-pl/m3-shape-options.md § Shape A` — content track (locked 2026-05-17).
  - `team/priya-pl/m3-design-seeds.md §4` — character-art-pass framing (now AI-primary instead of commission).
  - `team/priya-pl/m3-tier-1-plan.md §3` — Tier 1 dispatch breakdown (amendment proposed in §12 above).
- **Engineering integration:**
  - `.claude/docs/combat-architecture.md § "Mob hit-flash"` — modulate-cascade pattern preserved across sprite swap.
  - `.claude/docs/html5-export.md § "HTML5 visual-verification gate"` — every sprite-swap PR clears this gate.
- **Risk:**
  - `team/priya-pl/risk-register.md` — R-AI-CLEANUP amendment proposed in §11.
- **Ticket:**
  - `86c9uu2gd` — this brief's source ticket.
  - `86c9utcx8` — `m3-tier-1-plan.md` v1.1 amendment ticket (absorbs §12 recharacterization).
  - `86c9uth7g` — original commission-brief ticket (orchestrator + Sponsor align on close vs re-point).

---

## §14.5 — Sponsor-Orchestrator collaboration loop (per-asset on-demand)

Sponsor confirmed (2026-05-17) the collaboration shape for executing this brief: **"I do manual work with your guidance (prompts + help for cleanup)."** Sponsor executes Midjourney generation + Aseprite cleanup; orchestrator (main Claude Code session) provides per-asset prompts on-demand + cleanup help when asked. This brief is the **framework**; orchestrator-Sponsor fills the per-asset specifics during M3 execution.

Auto-memory `m3-art-pass-collaboration-shape` codifies this for future sessions.

### Division of labor

**The brief bakes (durable, framework-level):**

- Tonal anchors (§1 — Crystal Project / Mignola / dark-folk-chamber doctrine).
- Palette discipline (§2 — hex-lock rules, doctrine ramps, no-invent rule, verification protocol).
- Cleanup pipeline framework (§4 — generate → downscale → palette-lock → frame-align → export, with per-step concrete techniques).
- Quality-bar decision rules (§5 — regenerate vs cleanup-harder).
- Anti-token lists (§3 — universal anti-tokens that go into every Midjourney prompt's `--no` block).
- Animation-frame-consistency techniques (§9 — seed-lock, img2img, hand-tweening).
- Time + tool budgets (§6, §7).
- Asset list scope (§8).
- Honest trade analysis (§10).

**The brief does NOT bake (per-asset, ephemeral):**

- The exact Midjourney prompt string for a specific character on a specific day. Sponsor asks orchestrator on-demand when ready to generate; orchestrator drafts a prompt using §3 skeleton + doctrine + the asset's specific role; Sponsor iterates against Midjourney output.
- Specific cleanup decisions per sprite (e.g. "which doctrine hex replaces this off-palette pixel?"). Sponsor asks orchestrator when stuck; orchestrator advises against the palette doctrine.
- Frame-by-frame tween paths for a specific cycle. Sponsor asks for advice when a cycle isn't reading right; orchestrator suggests technique adjustments per §9.

**The brief NOTES (process, not content):**

- Per-asset prompts come from orchestrator on-demand with Embergrave doctrine baked in — Sponsor doesn't need to remember §1 tonal anchors + §2 palette + §3 skeleton + §3 anti-tokens every time; orchestrator composes the prompt fresh per asset and Sponsor copy-pastes to Midjourney.
- Cleanup help is back-and-forth — Sponsor screenshots the in-progress sprite or describes the issue; orchestrator points at the relevant §4/§5/§9 technique. Multi-round per asset is normal.
- The §3 per-character prompt examples in this brief are **illustrative starting points**, not the prompts Sponsor will use. Real prompts come from the on-demand loop and reflect Sponsor's current execution state (which strata are active, which characters remain to generate, what's worked in prior iterations).

### Workflow per asset (concrete)

1. **Sponsor signals** ready to generate character X (e.g. "ready to do Grunt").
2. **Orchestrator drafts prompt** using §3 skeleton + §1 tonal anchors + §2 palette doctrine + §3 anti-tokens + the asset's specific role. Returns the prompt string + a one-line reminder of which §4 steps come next.
3. **Sponsor submits to Midjourney**, evaluates the 4-image grid against §5 quality bar.
4. **If output fails gate 1 (silhouette) or gate 3 (anatomy):** Sponsor asks orchestrator for a prompt revision; orchestrator adjusts based on Sponsor's description of what went wrong.
5. **If output is usable:** Sponsor proceeds through §4 cleanup (downscale → palette-lock → frame-align → export).
6. **During cleanup:** if Sponsor hits a snag (palette mismatch, frame inconsistency, anatomy needs hand-fix), Sponsor asks orchestrator for technique help; orchestrator points at the relevant §2/§9 procedure.
7. **Sponsor commits** the `.aseprite` source + the `.png` exports to a PR. Drew / Devon picks up engine integration per §4 Step 6.
8. **HTML5 visual-verification gate** per `.claude/docs/html5-export.md` applies — Self-Test Report screenshot/recording from release-build confirms the sprite renders correctly in `gl_compatibility`.

### What this collaboration shape enables

- **Sponsor doesn't carry doctrine in head.** Orchestrator has read `palette.md` + `visual-direction.md` + this brief; Sponsor doesn't need to re-read every session.
- **Iteration is cheap.** Prompt revisions take seconds (orchestrator drafts; Sponsor copies). Cleanup advice is one message back-and-forth, not a research round.
- **Doctrine drift is bounded.** Every prompt goes through orchestrator's doctrine filter — palette hexes, tonal anchors, anti-tokens applied consistently. Sponsor isn't manually palette-locking the prompt every time (orchestrator does it).
- **Sponsor labor stays in the labor lane** — Midjourney UI, Aseprite UI, the actual cleanup work. Doctrine-reasoning stays with orchestrator. Time-efficient division.

### When Sponsor should NOT loop in orchestrator

- **Trivial cleanup steps** (eyedrop verification, sprite-sheet export naming). The brief covers these; no per-instance orchestrator round-trip needed.
- **Repeated retints** (Stoker palette-swap of Grunt, S3-S8 mob retints). The first instance teaches the pattern; subsequent retints follow the same path.
- **Pure Aseprite operations** Sponsor is fluent in. Orchestrator doesn't add value here.

The loop is **on-demand and Sponsor-initiated**, not "every step routes through orchestrator." Calibration target: ~3-5 orchestrator round-trips per character (initial prompt + 1-2 prompt revisions + 1-2 cleanup advisories). Less than 2 round-trips means Sponsor is over-self-sufficient (probably skipping doctrine checks); more than 8 means the brief needs better framework coverage for the area Sponsor keeps asking about.

---

## §14 — Hand-off

- **Sponsor (post-PR-merge):** the brief is Sponsor-executable solo. Recommended first-execution order: **Grunt** (5-state mob; pipeline validation, lowest stakes) → if Grunt clears quality bar at first-pass, proceed to Player. If Grunt requires >1.5× the §6 estimate (~4+ hrs), pause and triage cleanup-discipline gaps before committing to Phase 1 full execution. Tool stack: confirm Aseprite ownership ($0 if owned; $20 one-time Steam license recommended; Pixelorama / Libresprite as free fallback per §7).
- **Priya:** absorb Sponsor feedback on first Grunt execution; revise §6 labor estimates with empirical data; amend `risk-register.md` to add R-AI-CLEANUP per §11 (separate amendment ticket if needed); amend `m3-tier-1-plan.md §3` per §12 (absorbed by `86c9utcx8`).
- **Uma:** natural peer reviewer (visual style cohesion + AI-cleanup workflow audit) per `tess-cant-self-qa-peer-review` pattern for design PRs.
- **Drew / Devon:** no action until Sponsor delivers first Phase 1 sprites. Engine integration (sprite-swap PR per `m3-design-seeds.md §4 Asset pipeline`) is ~1-2 dev hours per mob; not on Sponsor's critical path.
- **Tess:** HTML5 visual-verification gate per `.claude/docs/html5-export.md` applies to every sprite-swap PR. Self-Test Report must include HTML5 release-build screenshot/screen-recording showing the new sprite rendering correctly in `gl_compatibility`.

---

## Caveat — Sponsor-executable-solo, but design seed not design lock

The brief is dispatch-ready and Sponsor-executable solo without agent dependency for art production. However:

- **§6 time estimates are estimates, not commitments.** First per-character execution validates or invalidates; revision lands as v1.1 amendment.
- **§9 frame-consistency techniques are starting points, not exhaustive.** Sponsor may discover Midjourney version-specific tricks that improve coherence; document them as v1.x updates.
- **§10 honest trade is the current understanding** — if Sponsor's execution surfaces surprising costs or benefits, the trade analysis updates.

The pipeline is **iterable**. Ship Phase 1 against the v1.0 brief; refine the brief based on lived experience; v1.1 reflects what actually worked. Per the M2 W2-T11 audio-direction precedent, design-spec docs improve over execution rounds.

---

## Decision draft (collected for next Priya weekly batch-PR to `team/DECISIONS.md`)

2026-05-17 — M3 art-pass path locked as AI-primary (Sponsor-DIY) per Sponsor's 2026-05-17 evening budget decision ($100 USD v1 envelope; commission path PR #257 shelved). Brief landed at `team/priya-pl/art-pass-ai-primary-brief.md`: Midjourney generation → Aseprite cleanup (palette-lock + frame-align + indexed-color export) → engine integration. Phase 1 scope ~813 cells; Sponsor labor estimate 22-31 hrs over 2-4 weeks part-time. Tool stack $0-20 incremental (Aseprite recommended; Pixelorama/Libresprite free fallback). Risk amendment R-AI-CLEANUP proposed (Sponsor-labor variance + frame-consistency hazard; med/med watchlist). Honest trade documented: sub-Crystal-Project visual feel, longer Sponsor labor, palette-discipline depends on Sponsor's rigor, less stylistic differentiation from other AI-pixel-art indies. Trade is informed and reversible (commission path remains feasible if budget shifts in Phase 2+). Cross-ref: ticket `86c9uu2gd`, this PR.
