# Embergrave — Pixel-Art Character Commission Brief (M3)

**Owner:** Priya · **Authored:** 2026-05-17 · **Status:** v1.0 draft awaiting Sponsor greenlight · **Driver ticket:** `86c9uth7g` (M3-T1-3) · **Source of truth for Sponsor decisions:** `team/priya-pl/m3-design-seeds.md §4` + `team/priya-pl/m3-tier-1-plan.md §3` + Shape A pick (2026-05-17, `team/priya-pl/m3-shape-options.md`).

---

## Sponsor escalation — read first

**This document is the artist-facing brief that Sponsor sends to 2-3 commissioned pixel-art artists for quote-gathering. Do NOT send this to artists until Sponsor explicitly greenlights it at PR merge.** The brief is authored against `m3-design-seeds.md §4` (character-art-pass) + `m3-tier-1-plan.md §3` (Tier 1 sequencing). Lead-time on 3 artist quotes is **~2-3 weeks** per `m3-design-seeds.md §4 — Cost-and-time bracket`; that lead time is the load-bearing reason this brief is on the **Tier 1 critical path**.

**Sponsor decisions required at this PR's merge** (Priya's recommendations in **bold**; Sponsor confirms or redirects):

| # | Decision | Default | Recommended | Tie-back |
|---|---|---|---|---|
| 1 | **Primary style** | 32-bit pixel-art, commissioned (Crystal Project / Octopath density) | **Commissioned, with AI-cleanup hybrid as documented fallback** | `m3-design-seeds.md §4.10` |
| 2 | **External-estimate greenlight** — send this brief to 2-3 artists | YES | **YES — start the 2-3-week clock now** | `m3-design-seeds.md §4.11` |
| 3 | **Per-cell rate range for Sponsor to use as negotiation anchor** | $30-80 mid-tier per cell · $100-200 premium-tier | **Confirm or redirect** | `m3-design-seeds.md §4` |

If Sponsor confirms #1+#2+#3, the orchestrator routes this brief to Sponsor's artist-outreach action. **The orchestrator does not send the brief to artists; Sponsor does.** Orchestrator's role is dispatch-and-greenlight; the artist relationship is Sponsor's.

---

## TL;DR (5 lines)

1. **What:** commission ~32-pixel character sprites for Embergrave M3, with animation states + per-stratum retint variants, locked to Embergrave's authoritative palette (`team/uma-ux/palette.md` + `palette-stratum-2.md` hex codes).
2. **Scope:** 6 mob archetypes + Player + 3 hub-town NPCs + retint pickup props. ~1,000-1,500 cells across the S1+S2 base set; per-stratum retint variants for S3-S8 at +10-20% per stratum.
3. **Timeline ask:** 8-16 weeks for the full M3 set; **segment-able by stratum** so the artist can deliver S1 first (enables `m3-design-seeds.md §4 Option B parallel-track shape`).
4. **Deliverables:** Aseprite source files + exported PNG sprite-sheets, frame-listed per the animation spec in §3 below.
5. **Selection criterion:** **style fit** (dark-folk-chamber tonal alignment) > throughput > price. We are not optimizing for cheapest; we are optimizing for an artist who reads the tonal anchors and lands the silhouettes on the first pass.

---

## §1 — Project framing (for the artist)

**Working title:** Embergrave (a 2D top-down action-RPG; Godot 4.3 engine; HTML5 export).

**Genre / reference shelf:** ARPG dungeon-descent with permanent character progression. Genre references: **Crystal Project** (single-dev shipped pixel-art ARPG; **the closest aesthetic precedent**), **Hyper Light Drifter** (animation crispness + combat-readability), **Octopath Traveler** (HD-2D sprite density as the bar; we are pure 2D), **Hades** (UI minimalism + combat feel — *not* the painted-art style).

**Tonal anchors:**

- **Dark-folk chamber** — small acoustic ensemble (cellos, frame drum, felted piano, single bronze bell, hurdy-gurdy drone). Intimate, sparse, warm-on-cold. Per `team/uma-ux/audio-direction.md §1`.
- **Ember-descent narrative** — the player carries a flame (`#FF6A2A`); they descend through 8 strata (Outer Cloister → Cinder Vaults → ... → Heart of Embergrave); the ember accent is **the through-line of every stratum** and **never changes hex code**. Per `team/uma-ux/palette.md`.
- **Hand-painted-feel pixel art**, NOT retro-clean, NOT cel-shaded. Mike Mignola illustration logic (warm accent on desaturated ground; single light source); From Software environmental decay (vertical descent = deeper = older = angrier). Per `team/uma-ux/visual-direction.md`.

**Anti-references** (we are NOT looking for these): glossy 3D-prerendered (Diablo III), cute pixel art (Stardew Valley), heavy outlines / cel-shaded vector (Cuphead), photoreal 2D (Octopath HD-2D lighting bill), chiptune-era 8-bit retro, AI-output untouched.

---

## §2 — Sprite spec (technical)

**Per `team/uma-ux/visual-direction.md`:**

- **Internal canvas:** 480 × 270 px (16:9 logical). Game renders at integer-scale (2× / 3× / 4×) onto display resolution.
- **Tile size:** 32 × 32 px internal (= 96 × 96 at 3× scaled onscreen).
- **Character sprite footprint (Player baseline):** 32 × 48 px internal (taller-than-a-tile by 50%; mob silhouettes vary per archetype but stay in the same scale family — character ~1/3 to ~2/3 tile-height for top-down ARPG readability).
- **Filter:** nearest-neighbour everywhere. **No bilinear, no anti-aliasing, no sub-pixel anti-alias.** Pixels must be 1:1 hard-edged.
- **Outline:** 1 px dark outline around player + humanoid mobs (clarity over silhouette). Environmental tiles get NO outline. Beasts (Charger, etc.) — artist's call when authoring; align with Drew's existing M1+M2 silhouette discipline.

**Palette lock (load-bearing):**

- **Use only the hex codes in `team/uma-ux/palette.md` + `team/uma-ux/palette-stratum-2.md`.** Provided as Aseprite `.aseprite` palette files alongside this brief.
- **Do not invent new hexes.** If a needed hue isn't in the palette, flag back to Uma for a palette doc update before authoring. The palette doctrine is cross-stratum-locked; ad-hoc hex additions break tester checks (`palette.md` PL-01 through PL-12).
- **Ember accent `#FF6A2A` is the global through-line.** Use exactly this hex for player flame, level-up glow, item-drop motes. Never substitute. **The ember reads identically across all 8 strata; what changes is its compositional role, not its hex code.**
- **Aggro-eye-glow `#D24A3C`** (same hex as player HP-foreground): every mob in every stratum uses this exact hex for the aggro-state eye-glow telegraph. Per `palette.md` PL-11 cross-stratum contract. **Do not deviate.**

**File format deliverables:**

1. **Aseprite source files** (`.aseprite`) — the single source of truth for every sprite. One `.aseprite` per character archetype, with anim states organized as Aseprite "Tags" (idle / walk / attack-telegraph / attack / hit-react / die). Palette swap layers for per-stratum retint variants (see §6).
2. **Exported PNG sprite-sheets** — generated from Aseprite via the standard export-as-sheet command. One PNG per character per anim-state, OR a single packed sheet per character with a Godot-readable JSON atlas. Artist's preference; engineering team will adapt.
3. **Layer organization in `.aseprite`:** body / cloth / weapon-edge / eye-glow / outline as separate layers, palette swap layer at top. This lets per-stratum retint variants reuse the same source file (Aseprite palette-swap pattern; W3-T3 established this pipeline in M2).

**Integration constraint** (existing engine code preserves these): `.claude/docs/combat-architecture.md § "Mob hit-flash"` runs a modulate cascade — the engine **multiplies** every mob sprite's color channel against the rest-color tween (rest → white → hold → rest, ~80ms total). **Artist provides the rest-color sprite at full saturation; the white-flash effect is applied at runtime.** Do not bake the white flash into the sprite; do not pre-modulate. The artist's sprite is "the mob at rest, lit ambient." The engine handles hit-state visuals.

---

## §3 — Animation states per character

Frame counts and FPS per `team/uma-ux/visual-direction.md § "Animation feel"`:

| State | Frames | FPS | Total duration | Notes |
|---|---|---|---|---|
| **idle** | 4 | 12 | ~1.0 s loop | Subtle breathing; player has ember-glints in eyes every ~3 s (1-frame highlight) |
| **walk** | 8 | 12 | ~0.67 s loop | 4-directional cardinal (N/S/E/W). 8-directional rejected for cost; we mirror for L/R. |
| **attack-telegraph** | 4 | 24 | ~0.17 s | The "rear back" anim; reads as "I'm about to attack" — load-bearing for player legibility |
| **attack** | 6 | 24 | ~0.25 s | Includes 1-frame 60 ms hit-stop on contact (engine applies; not baked) |
| **hit-react** | 3 | 24 | ~0.13 s | Brief stagger; not a knockback (engine handles motion) |
| **die** | 8 | 24 | ~0.33 s | 4-frame stagger + 4-frame ember-dissolve (mob silhouette fades into ember motes) |

**Total per character per direction:** ~33 frames × 4 directions = **~132 cells per character per stratum (base color)**. Add per-stratum retint variants per §6.

**Direction count:** **4 cardinal** (N/S/E/W) with L/R mirroring for sprite reuse. 8-directional was rejected at scoping for cost; the artist need not author diagonal frames. The engine flips the W-facing sprite to produce E-facing.

**Mob-specific deviations** — some archetypes have lighter or heavier anim needs:

- **Stratum1Boss** (Warden) — adds **phase-transition** anim (4-frame stagger when HP crosses 66% / 33% thresholds) + **entry-sequence** anim (boss-wake, ~12 frames, cinematic). Boss is the heaviest single character to author.
- **PracticeDummy** — idle + hit-react only. No walk, no attack, no die. **~7 cells total** (idle 4 + hit-react 3).
- **Shooter** — replaces "attack" anim with **aim-and-fire** (4-frame aim + 2-frame loose; projectile is engine-authored). Otherwise standard.
- **Charger** — adds **dash-windup** (overlaps attack-telegraph framing; artist's call on whether to merge or split).

---

## §4 — Character roster (the deliverables list)

### M3 base set (S1 + S2 baseline) — primary deliverable

| Character | Archetype | Anim states needed | Per-stratum variant? | Approx. cell count (base, 4-dir) |
|---|---|---|---|---|
| **Player** | warrior / edge-stat archetype (no class divergence M3) | full set + dodge-roll (6 frames @ 24 fps) | NO — player flame is cross-stratum through-line; player sprite never retints per stratum | ~150 cells (more anim states than mobs) |
| **Grunt** | hooded-monk silhouette (S1 cloister) | full set | YES — retints to S2 "heat-blasted miner" silhouette as Stoker variant; per-stratum retints S3-S8 | ~132 base + retints |
| **Charger** | bestial four-legged silhouette | full set + dash-windup | YES — retints OK per `palette-stratum-2.md §5` | ~140 base + retints |
| **Shooter** | skeletal-archer silhouette | full set with aim-and-fire | YES — retints OK | ~132 base + retints |
| **PracticeDummy** | training-target post silhouette | idle + hit-react only | NO — single training-room prop, doesn't retint | ~7 cells |
| **Stoker** (S2-authoritative) | heat-blasted miner silhouette; **palette-swap variant of Grunt** per `palette-stratum-2.md §5` | full set | YES (as S2 variant of Grunt) | included in Grunt's retint cell count |
| **Stratum1Boss** (Warden) | heavy-armored cloister-warden silhouette | full set + phase-transition + entry-sequence | NO — stratum-specific boss; future bosses are separate commissions (M3+ scope) | ~200 cells (heaviest single character) |

**Subtotal (M3 base set, S1 authoritative):** ~760 cells of character art, before per-stratum retints.

### Additional sprites (M3 scope, non-mob)

| Item | Anim states | Cell count |
|---|---|---|
| **Hub-town NPC: Vendor** | idle + talk (subtle gesture loop, ~6 frames @ 12 fps) | ~10 cells |
| **Hub-town NPC: Anvil / reroll-master** | idle + hammer-strike loop (~8 frames @ 12 fps) | ~12 cells |
| **Hub-town NPC: Lore-giver / quest-poster** | idle + read-from-tome loop (~6 frames @ 12 fps) | ~10 cells |
| **Pickup sprite** (item drop cloth-bundle) | static + 6-frame bounce-on-spawn | ~7 cells |
| **Stash chest** | static + lid-open / lid-close (~4 frames each direction) | ~9 cells |
| **Ember-bag** (player carries between runs) | static + idle ember-motes (~4 frames @ 12 fps) | ~5 cells |

**Subtotal (M3 non-mob set):** ~53 cells.

### Per-stratum retint variants (S2-S8)

Per `palette-stratum-2.md §5` + `palette.md § Stratum 3-8 sprite-reuse hints`:

- **S2 Cinder Vaults:** retint Charger + Shooter; **Stoker = retint of Grunt** (palette swap, ~30% of fresh-author cost per `m3-design-seeds.md §4`).
- **S3 Drowned Reliquary:** retint Grunt as drowned monk; retint Charger + Shooter. NEW: drowned silhouette is the SAME as S1 monk (per palette doc), so retint not fresh-author.
- **S4 Hollow Foundry:** Stoker retints further; Charger retints as forge-creature variant.
- **S5 Bonemeal Reach:** Reach-cultist = retint of Grunt (diegetic: "these are what the S1 monks turned into").
- **S6 Magmaroot Hollows:** Charger retints as magma-quadrupedal cousin; new authoring for Magmaroot creature itself (likely M3.1+ scope, not in M3.0 base commission).
- **S7 Ash Cathedral:** Glassbearer (S7-authoritative) — likely **new authoring** (silhouette doesn't reuse). Outside this commission's M3.0 base set; future M3 follow-on if Sponsor extends.
- **S8 Heart of Embergrave:** boss-rank mobs — **new authoring** when M3 boss design lands. Outside this commission's M3.0 base set.

**Per-stratum retint cost rule of thumb:** ~10-20% of base authoring cost per retint pass (`m3-design-seeds.md §4`). Artist confirms; this is our internal estimate, not a quote anchor.

**Total commission scope, M3.0 base + S2 retints:** ~1,000-1,200 cells. **Extended scope including S3-S8 retints:** ~1,500-2,000 cells if Sponsor extends.

---

## §5 — Style references (mood-board pointers)

We are NOT attaching reference images to this brief; the artist is invited to pull their own from these sources:

**Primary references (the look we want):**

- **Crystal Project** (Andrew Willman, 2022) — **the closest aesthetic precedent.** Single-dev shipped pixel-art ARPG with 7+ strata of biome density, 32-bit-style sprites, palette-disciplined per region. If you've shipped or studied work in Crystal Project's tradition, you are well-matched to Embergrave.
- **Hyper Light Drifter** (Heart Machine, 2016) — animation-quality reference for combat readability. Saturated accent on desaturated ground; single warm light source. **The combat-attack framing + hit-stop discipline is the bar.**
- **Octopath Traveler** (Acquire, 2018) — sprite-density bar (note: Embergrave is **pure 2D**, not HD-2D — no 3D environment underlayment). The anim-crispness + silhouette legibility at small scale is the reference.
- **Stardew Valley** (ConcernedApe, 2016) — one step less dense than our target (16-bit-feel), but **the solo-dev shipped-art-pipeline reference.** Useful for understanding how palette-swap variant authoring scales.

**Secondary tonal anchors:**

- **Mike Mignola** (Hellboy comics) — black-shadow + warm-accent illustration logic. Our environmental compositions lean this way.
- **From Software environment art** (Dark Souls 1 specifically) — vertical decay; deeper = older = angrier. Our stratum-descent visual language carries this.
- **Sergio Toppi** illustration ink work — dense detail in environments; restraint in characters. We want characters to read silhouette-first.

**Anti-references** (where we are NOT going):

- Glossy 3D-prerendered (Diablo III, Diablo Immortal)
- Cute / cozy pixel art (Stardew Valley FACE — but its pipeline is fine)
- Heavy outlines / cel-shaded vector (Cuphead's flapper-era look)
- Photoreal 2D (Octopath's HD-2D lighting bills)
- Chiptune-era 8-bit (NES-aesthetic; too retro for our tonal weight)
- AI-output ungroomed (we will not accept pure-AI deliverables; AI-assisted-then-fully-cleaned is acceptable if the cleanup is artist-led and the palette / silhouette / frame-consistency is hand-locked)

**Authoritative palette files** (provided alongside this brief as Aseprite-importable):

- `team/uma-ux/palette.md` — global palette + S1 (Outer Cloister) authoritative + S3-S8 indicative.
- `team/uma-ux/palette-stratum-2.md` — S2 (Cinder Vaults) authoritative.
- `team/uma-ux/visual-direction.md` — sprite scale, anim FPS, outline rule.

We will provide these to the artist verbatim; the brief is anchored on them, not on this summary.

---

## §6 — Per-stratum retint pipeline (Aseprite palette-swap)

The pipeline established by W3-T3 in M2 (`team/uma-ux/palette-stratum-2.md §5`) is the canonical retint workflow:

1. **Author the S1 base sprite in Aseprite** with body / cloth / weapon-edge / eye-glow / outline on separate layers. The palette is the active swatch set during authoring.
2. **Add a "palette swap" layer above the body layers**, using Aseprite's color-replace or `Cels → Color → Replace Color` workflow. This layer applies the per-stratum hex shift on top of the base.
3. **Per-stratum palette files** are provided at `assets/palettes/stratum-<N>.aseprite`. The artist switches the active palette in Aseprite and re-exports; the same `.aseprite` source produces N stratum variants.
4. **Export PNG per variant** with a naming convention: `<character>_<state>_s<stratum>_<direction>.png` (or a single packed sheet per character with a JSON atlas — artist's call).
5. **Engineering integrates the retint** by selecting the per-stratum PNG at runtime based on `meta.deepest_stratum` or the active stratum chunk. Already-established pattern; the artist authors against the palette doc, the engine consumes.

**Why palette-swap and not fresh authoring per stratum:** 8 strata × 5 mob archetypes × full anim sets = ~5,000 cells of fresh authoring. Palette-swap reduces this to ~1,200 base cells + per-stratum overlays at +10-20% per stratum. **This is the pipeline that makes 8 strata of art-pass achievable at indie scale.**

---

## §7 — Timeline ask + segmentation

**Target delivery window:** **8-16 weeks** for the full M3.0 base set + S2 retints. **Segment-able by stratum** — the artist can deliver S1 first, then S2 retints, then S3 retints — enabling Embergrave's M3 to ship **incrementally** per `m3-design-seeds.md §4 Option B parallel-track shape`.

**Suggested segmentation (artist confirms feasibility):**

| Phase | Deliverable | Estimated window |
|---|---|---|
| **Phase 1** | S1 base set (Player + Grunt + Charger + Shooter + PracticeDummy + Stratum1Boss + 3 NPCs + pickup/chest/ember-bag) | weeks 1-6 |
| **Phase 2** | S2 retints (Stoker = Grunt variant + Charger S2 + Shooter S2) | weeks 6-8 |
| **Phase 3 (extended)** | S3-S5 retints + Bonemeal cultist | weeks 8-12 |
| **Phase 4 (extended)** | S6-S8 new authoring (Magmaroot, Glassbearer, boss-rank, etc.) | weeks 12-16 |

**Sponsor-input note:** Phase 1+2 is the **M3.0 ship-required baseline** (per `m3-design-seeds.md §4 Risks Mitigation 2 — scope-down floor`). Phase 3+4 is "extended M3 / M3.1" scope. Sponsor confirms the scope-tier at quote-acceptance time.

**Milestone payments** (artist-friendly, project-friendly): we expect to structure as fixed-price milestones per phase, with revision rounds (1-2 per phase, artist's call) included. The artist's quote should include the milestone structure they prefer.

---

## §8 — Selection criteria (how Sponsor picks among quotes)

Listed in **priority order**:

1. **Style fit — highest weight.** Does the artist's portfolio show work that lands the tonal anchors (dark-folk-chamber, ember-descent, hand-painted-feel-pixel-art, Mignola-illustration-logic)? Crystal Project's tradition is the closest precedent — artists who've shipped in that lane will land Embergrave's silhouettes faster than artists from a Cuphead / Stardew / chiptune background, even if technically skilled.
2. **Palette discipline.** Has the artist worked from a locked palette before, OR can they demonstrate paste-board hex-code work? Embergrave's palette doctrine (cross-stratum ember through-line, hex-locked accent codes, anti-list rules) is **load-bearing for stratum-arc coherence**. An artist who silently expands the palette breaks the doctrine; we need an artist who treats the palette as an input constraint, not a starting suggestion.
3. **Silhouette legibility at 32 px.** The deliverable is small sprites (32 × 48 player baseline). Artists who excel at "more density at smaller scale" are over-indexed for portfolio fit. Detail-heavy / large-canvas-only artists are mis-matched.
4. **Throughput / segmentation comfort.** Can the artist commit to Phase 1+2 (~8 weeks) as a baseline, with the option to extend? Artists who only do "all-or-nothing" commissions are misaligned; we want incremental delivery so M3 can ship Phase 1 even if Phase 3+ slips.
5. **Cost band.** Per `m3-design-seeds.md §4`: **mid-tier ($30-80 per cell)** is the target band. **Premium ($100-200 per cell)** is the upper bound — defensible if the artist's style-fit + portfolio is materially superior. **Sub-$30 is a red flag** for pixel-art at this density / palette-discipline — likely indicates AI-output-with-light-cleanup or rushed authoring; review portfolio carefully.
6. **Communication / revision turnaround.** Pixel-art commission feedback loops thrive on tight cycles. Artists who reply within ~48 hours, do 1-2 revision rounds per phase, and are comfortable with palette-doctrine corrections rank higher than slower-responders even at equal skill.

**What we are NOT optimizing for:**

- **Cheapest quote.** A misaligned cheap artist costs more than a well-aligned mid-tier artist — we will rework the deliverable, not the price.
- **Fastest quote.** Phase 1's 6-week window is the target; "I can do it in 3 weeks" likely means rushing or AI-assisted, both of which fail the doctrine bar.
- **Highest-profile portfolio.** A well-known pixel-art studio whose portfolio doesn't fit Embergrave's tone is a worse pick than a mid-tier artist whose portfolio lands the silhouette + palette tests.

**Sponsor framework for picking among 2-3 quotes:** if the top-fit artist is within 20% of the cheapest, **pick the top-fit artist**. If they are 50%+ more expensive, escalate back to orchestrator + Priya for a re-scope (likely Phase 1 only, with Phase 2+ deferred).

---

## §9 — Licensing + IP

**Embergrave will retain full commercial rights to all delivered artwork.** Standard work-for-hire commission terms; we expect the contract to specify:

- **All sprites become Embergrave's exclusive property** upon final payment of each milestone.
- **Artist retains the right to portfolio the work** (include screenshots / sheets in their public portfolio) — we encourage this; the artist's reputation benefits us indirectly.
- **No re-use of identical sprites in other commercial games** — palette-disciplined sprites are project-specific by nature; the artist's stylistic vocabulary remains theirs.
- **Source files (`.aseprite`) are delivered alongside PNGs** and become Embergrave's property — required so we can extend / retint per stratum without re-commissioning.
- **Credit:** the artist will be credited prominently in the game's credit roll (typically "Character Art" or similar) and on Embergrave's distribution surface (Steam page, itch.io page, etc.) when public.

**The contract will be Sponsor-Thomas to artist directly.** This brief is the design / scope anchor; Sponsor + artist negotiate the legal terms.

---

## §10 — Quote-request format (what we want back from each artist)

When Sponsor sends this brief, the requested response from each artist is:

1. **Portfolio link** (1-3 sample works that land the style-fit criteria from §8).
2. **Per-cell rate** (in USD or local currency; we will convert). Artists may quote a tiered rate (e.g., "$40/cell for body sprites, $60/cell for boss-rank, $20/cell for pickup props").
3. **Phase 1 quote** (M3.0 baseline: ~760 cells of character art + ~53 cells of NPC/prop art) — fixed-price total + estimated weeks to deliver.
4. **Phase 2 quote** (S2 retints: ~150-200 additional cells via palette swap; typically priced at a discount to fresh authoring) — fixed-price total + estimated additional weeks.
5. **Phase 3+ optional quote** (extended scope: S3-S8 retints + new authoring for S6-S8 archetypes) — open-ended; can be quoted at a per-cell rate without fixed total if scope is uncertain.
6. **Revision policy** (e.g., "2 revisions per milestone included; additional revisions at $X/hour"). Embergrave does NOT expect unlimited revisions; we are looking for a clear cycle, not "I'll redo it forever."
7. **Communication cadence** (typical response time + availability windows + any planned breaks during the 8-16 week target window).
8. **Anything they want to flag** about the scope — e.g., "Stratum1Boss looks more like a 200-cell job than a 132-cell job, I'd want to scope that separately" is **valuable signal**, not a red flag.

**Sponsor will share each artist's response with Priya + the orchestrator** for a portfolio-fit and cost-bracket comparison. Final pick is Sponsor's call; recommendation comes back via orchestrator per `sponsor-decision-delegation` memory.

---

## §11 — What's NOT in this commission (M3-scoped, M4-scoped, or never)

**Out of scope for this commission:**

- **Class-divergent character art** — `m3-design-seeds.md §1.2` defers class divergence to M4. The player sprite is one "warrior with edge-stat focus" archetype; class variants come later.
- **Hand-drawn portraits for dialog** — Shape-C-style narrative-portrait art is M4+ scope (per `m3-shape-options.md §Shape C`). If we commission portraits, that's a separate brief with a different artist pool (illustration-portrait, not sprite-anim).
- **3D-rendered-to-2D sprites** — wrong tonal register; cost-prohibitive; breaks our Aseprite + palette-swap pipeline. Anti-reference per §5.
- **Environment tiles** (floor / wall / props) — Drew owns environmental tile authoring per `palette-stratum-2.md §5`. The commissioned artist is **character-only**; environments stay in-house (with cross-stratum palette doctrine consultation as needed).
- **Animations beyond the §3 state list** — special effects, hit-particles, ember-mote shaders, etc. are engine-authored (CPUParticles2D, ColorRect shaders) and live in the engineering lane.
- **AI-generated work as final deliverable** — AI-assisted-then-fully-cleaned is acceptable if the artist discloses it; pure AI output is rejected. The cleanup must be artist-led and the silhouette / palette / frame-consistency hand-locked.

**Future commission scope (deferred to post-M3.0):**

- S6-S8 boss-rank mob authoring (when M3 boss design lands).
- Class-divergence character art (M4).
- Portrait illustration for narrative beats (M4+, separate commission lane).

---

## §12 — Risks + mitigations (Priya internal)

This section is **Sponsor-internal** — not for the artist. Surfaces what could go wrong + the pre-committed mitigations.

**Risk: artist quote-lead-time slips past 2-3 weeks.**

- **Mitigation:** the M3 Tier 1 dev tracks (§1 multi-character + §2 hub-town + §4 multi-character UI) are **independent of artist quotes** per `m3-tier-1-plan.md §3`. M3 Tier 1 ships on its own clock; the art-pass commission lands mid-M3 and Phase 1 sprites land late-M3.

**Risk: all 2-3 quotes come in above premium-tier ($100-200/cell).**

- **Mitigation:** escalate to Sponsor for re-scope. Options: (a) commission Phase 1 only (S1 base set, ~760 cells × $150 average = ~$114K — likely too high; Sponsor's call); (b) cut scope further (Player + Grunt + Stratum1Boss only = ~480 cells); (c) AI-cleanup hybrid fallback per `m3-design-seeds.md §4` (significantly lower cost; documented tradeoff); (d) defer character-art-pass to M4 (M3 ships with rectangles + hex-block fallback).

**Risk: no artist responses meet the style-fit criteria.**

- **Mitigation:** expand outreach to 4-5 artists (vs original 2-3). If still no fit, the AI-cleanup hybrid fallback becomes the default path — `m3-design-seeds.md §4` already documents this as the contingency.

**Risk: artist delivers Phase 1, then becomes unavailable for Phase 2.**

- **Mitigation:** the Aseprite source files + palette docs are sufficient to onboard a second artist for Phase 2 retints (palette-swap pipeline is hand-off-friendly). We accept this as a normal commission-handoff risk and pre-commit to "artist may rotate between phases" in the contract.

**Risk: Sponsor greenlight delayed; lead time slips beyond M3 W4.**

- **Mitigation:** the brief is **dispatch-ready** at this PR's merge. Sponsor greenlight is the single gate; once greenlit, Sponsor reaches out to artists same-day. The orchestrator will surface "no artist outreach yet" as a heartbeat-check item if the greenlight is held.

---

## §13 — Open questions (Sponsor-input deferred)

Items not blocking the artist quote-request but flagged for Sponsor consideration at quote-accept time:

- **Q1: Does Sponsor want the brief sent to artists Priya / Sponsor identify together, or does Sponsor have artist candidates in mind?** Priya does not currently have a candidate shortlist; if Sponsor has artists in mind (from prior work, recommendations, etc.), name them at the greenlight conversation. If not, orchestrator + Priya can compile a 3-5 artist shortlist from public pixel-art communities (Aseprite Discord, /r/PixelArt, indie pixel-art portfolios) — adds ~1 week to the lead time.

- **Q2: Premium-tier commission ($100-200/cell) — defensible budget or pre-rejected?** Sponsor's M3 budget envelope is not specified in current docs. If premium-tier is pre-rejected, the brief's selection criteria §8 should note "max $80/cell" upfront so artists self-filter. Default: open at quote stage; Sponsor confirms at quote-accept.

- **Q3: AI-cleanup hybrid disclosure to artists.** Some pixel-art artists explicitly do not work with AI-assisted tooling (philosophical / professional-pride reasons). Should the brief mention the AI-cleanup hybrid as a fallback, or omit it to keep the artist pool open? **Recommended: omit.** The fallback is Sponsor-internal contingency; mentioning it to artists telegraphs lack of commitment. If we end up going AI-cleanup, that's a separate (different-artist or in-house) commission, not a re-scope of this one.

- **Q4: Multi-artist split for Phase 1?** If 2 artists quote competitively and Sponsor wants to hedge, we could split Phase 1 across two artists (e.g., one does mobs, one does Player + NPCs). **Recommended: single-artist for Phase 1** to preserve stylistic coherence; the W3-T3 retint pipeline establishes a clear hand-off shape if Phase 2+ rotates.

These are flagged for Sponsor reading; the brief itself doesn't gate on them.

---

## §14 — Hand-off

**Sponsor (post-PR-merge):**

1. Read the brief end-to-end. Confirm or redirect the three top-of-doc decisions (primary style, external-estimate greenlight, per-cell rate range).
2. Send the brief (or a slightly-adapted artist-facing version — Sponsor's call on phrasing) to 2-3 candidate artists. Include the Aseprite palette files alongside.
3. Collect quotes per §10 format. Share back with orchestrator + Priya for fit + cost-bracket comparison.
4. Pick the artist (or escalate re-scope per §12). Sign contract. Initiate Phase 1.

**Orchestrator (between Sponsor greenlight + artist quotes landing):**

1. Surface "no artist outreach yet" as heartbeat-check after 48 hours from greenlight.
2. Surface "no quotes yet" as heartbeat-check after 2 weeks from outreach.
3. Route quote responses to Priya for style-fit review + cost-bracket analysis.
4. Dispatch M3 Tier 1 dev work in parallel — art-pass is NOT a blocker for `§1 save-schema v5` or `§2 hub-town direction` or `§4 multi-character UI` per `m3-tier-1-plan.md §3`.

**Priya (when quotes land):**

1. Style-fit review of each artist's portfolio against §8 criteria.
2. Cost-bracket comparison; flag any pre-rejection-tier outliers.
3. Recommend a pick (or recommend re-scope per §12). Sponsor decides.
4. Update this brief to v1.1 with the picked artist's segmentation + start date logged.

**Drew (when Phase 1 sprites land):**

1. Aseprite sources go into `assets/sprites/source/<character>.aseprite` (new convention; W3-T3 partially established this).
2. PNG exports go into `assets/sprites/<character>/<state>_<direction>.png`.
3. Per-mob integration: swap the existing ColorRect Sprite child for a `Sprite2D` with the exported PNG texture. Per `combat-architecture.md § "Mob hit-flash"`: the rest-color modulate hex is set on the new Sprite2D; the hit-flash tween logic is unchanged.
4. Paired GUT test updates: any test that asserted "Sprite child is a ColorRect" needs to be relaxed to "Sprite child has the per-mob rest-color modulate."

**Tess (when sprites integrate):**

1. HTML5 visual-verification gate — per `.claude/docs/html5-export.md`, character-sprite swaps need explicit HTML5 release-build smoke before merge.
2. Palette doc tester-checklist (`palette.md` PL-01 through PL-12, `palette-stratum-2.md` S2-PL-01 through S2-PL-15) — re-run against the new sprites.
3. Self-Test Report screenshots for each character-art integration PR per `self-test-report-gate` memory.

---

## Cross-references

- `team/priya-pl/m3-design-seeds.md §4` — character-art-pass design rationale + cost-bracket reasoning + risk doctrine
- `team/priya-pl/m3-tier-1-plan.md §3` — M3 Tier 1 sequencing context (why this brief is on the critical path)
- `team/priya-pl/m3-shape-options.md § Shape A` — locked 2026-05-17; the content-track shape this brief serves
- `team/uma-ux/palette.md` — global palette + S1 authoritative + S3-S8 indicative (artists lock against)
- `team/uma-ux/palette-stratum-2.md` — S2 (Cinder Vaults) authoritative + soft-retint pipeline
- `team/uma-ux/visual-direction.md` — sprite scale + anim FPS + outline rule + reference shelf
- `team/uma-ux/audio-direction.md §1` — dark-folk-chamber tonal anchor (the audio cousin artists should know about)
- `.claude/docs/combat-architecture.md § "Mob hit-flash"` — engine integration constraint (rest-color modulate cascade)
- `.claude/docs/html5-export.md § "HTML5 visual-verification gate"` — sprite-integration PR gate
- `team/uma-ux/` (Uma's hub-town visual direction — landing in parallel via ticket `86c9uth6a`) — anchor point for Phase 1 NPC silhouette direction; if Uma's brief lands before Phase 1 authoring, NPC silhouettes lock against it

---

## Caveat — this is a brief, not a contract

This document is the **scope + design anchor** for artist outreach. It is NOT the legal commission contract. The contract is Sponsor-to-artist directly, with terms negotiated per artist. This brief is **dispatch-ready for Sponsor's greenlight at this PR's merge** — orchestrator surfaces the three top-of-doc decisions; Sponsor confirms or redirects; orchestrator routes Sponsor's outreach action.

**Decision draft (for next Priya batch-PR to `team/DECISIONS.md`):** 2026-05-17 — M3 art-pass commission brief authored (`team/priya-pl/art-pass-commission-brief.md`); Sponsor-input items embedded for greenlight at PR-merge time; targets 2-3 pixel-art artist quotes with 2-3 week lead time per `m3-design-seeds.md §4` framing; selection criterion ordered as style-fit > palette-discipline > silhouette-legibility > throughput > cost-band > comms; AI-cleanup hybrid retained as documented Sponsor-internal contingency only (not surfaced in artist-facing brief). Cross-ref: ticket `86c9uth7g`, PR (this).
