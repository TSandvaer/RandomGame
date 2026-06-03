# S1 Widened-Room Decoration-Density Brief — "Furnish the Cloister"

**Owner:** Uma (Stage A — direction) → Drew (Stage B — impl) · **Ticket:** `86ca3yuwv`
**Sponsor:** taste-veto on the DIRECTION (this doc) before Drew implements.
**Phase:** M3 S1 Stage-1 polish · **Look:** "Outer Cloister" — **LOCKED** (env-art brief `86ca3gvgb`, Sponsor-approved). This is DENSITY + PLACEMENT, not a new look.
**OOS:** editing the `.tscn` (Drew Stage B); generating art (orch runs PixelLab on my recommendation); new biome/look; gameplay/collision/spawn/gate coord changes; widening other rooms (S1B/S3 later — this sets the pattern).

This is a DESIGN-DOC. No game code. It tells Drew (1) which decoration beats to add and how many, (2) exactly where they cluster and what stays clear, (3) the brazier/light rhythm across the wider span, and (4) whether a small new-prop gen is worth it. Every count + anchor below is traced to a real file (§9).

---

## 0. The problem this solves (one paragraph)

The widened proof room (`s1_room02_wide_chunk.tscn`, 30×8 = 960×256) doubled the floor span to drive camera-scroll, but the prop set carried over from the 15×8 room mostly unchanged: **4 north-wall braziers, 2 moss patches, 1 parchment, 2 rubble — 9 props across a 960px floor.** At full character scale that read thin; with `char_scale=0.6` shipped (PR #405) the player + mobs are now 0.6× their old footprint, so the *same* empty floor reads even emptier — the eye has less on-screen mass to anchor to, and the warm-sandstone expanse dominates. The room solved "box in the middle of a big screen"; now the extra space needs to feel *intentionally abandoned*, not *unfinished*. This brief raises prop density to a target that reads furnished at game zoom + 0.6 scale, using the **already-approved** s1_cloister assets first.

---

## 1. TONAL ANCHOR (lead with this — every beat ladders down from here)

> **The widened Outer Cloister antechamber reads as "a hall built for a crowd that no longer comes — the space outlived its purpose, and the few things still here are the things nobody bothered to carry out."**

This is the wider-room reading of the locked S1 anchor ("a stone cloister settled into silence — the monks are gone, the candles are guttering, but the room hasn't noticed yet"). The narrow rooms read as *cells*; the wide antechamber reads as a *processional hall* — and a hall is supposed to be lined. **Emptiness in a hall reads as ABANDONMENT when it's framed by structure (pillars, braziers, banners marching down the walls), but as UNFINISHED when it's just bare floor.** The decoration job is to add the *framing* that makes the central emptiness intentional: the player should walk a clear stone aisle flanked by the worn remains of ritual, not cross a blank room with a few objects scattered at random.

**The density principle:** rising mass at the EDGES, clear AISLE down the MIDDLE. The wider the room, the more the walls must carry — because the playable center must stay open for traversal + combat. Density goes UP at the perimeter exactly as it must stay DOWN in the lane.

**Anti-list (beats that DON'T serve the anchor — cut them):**
- No mid-floor clutter in the central lane (breaks traversal AND breaks the "clear processional aisle" read — see §2 keep-clear).
- No NEW object *types* that aren't "things left behind" (no furniture, no crates, no treasure — wrong tone; this is a cloister, not a dungeon storeroom).
- No active fire/lava/heat FX (that's the S2 descent reward; S1 stays warmest-but-still).
- No pristine/repaired surfaces (everything worn, cracked, mossed, or guttering).
- No pure black / cyan-teal-violet accents (palette anti-list, wrong stratum).

---

## 2. PLACEMENT ZONES — where density goes, what stays clear

Room geometry (ground-truth from the `.tscn` + chunk-def, §9): 30×8 tiles, 32px. Walkable interior = tiles (1,1)–(28,6) → px **x∈[32,928], y∈[32,224]**. Wall band = the outer ring. The traversal axis is **WEST entry → EAST exit**, both at tile-row 4 (**y≈144**).

### KEEP-CLEAR (do NOT decorate — traversal + combat + gates)

| Zone | Px region | Why clear |
|---|---|---|
| **Central processional lane** | full-width band **y ≈ 112–176** (tile-rows 3–5), x∈[64,896] | The W→E walk path + the combat arena. The aisle. Props here block movement AND kill the "clear aisle" read. |
| **West entry + RoomGate** | x∈[0,112], y∈[104,184] | Entry port (tile 0,4) + RoomGate at (48,144) size (48,80). Nothing in the gate's swept area. |
| **East exit port** | x∈[896,960], y∈[104,184] | Exit port (tile 29,4). Keep the doorway readable + walkable. |
| **The 4 mob-spawn tiles** | (336,112) · (496,176) · (688,112) · (816,176), **clear a ~48px radius around each** | Grunts spawn here; a prop on the spawn tile clips the mob or blocks its first step. |
| **Fountain** | N/A this room | `place_healing_fountain = false` — no fountain in Room02. (Pattern note for rooms that DO have one: ring it, never block it.) |

### DECORATE-HEAVY (cluster density here)

| Zone | Px region | What clusters |
|---|---|---|
| **North wall band** | y≈12–40, full width | Brazier rhythm (§3) + 2 hanging banners. The "lined hall" framing — most visible because the camera sits low-ish on a 256-tall room. |
| **South wall band** | y≈216–240, full width | Cold/guttered brazier + rubble + moss creep + parchment. The "decay" wall — opposite the lit north wall, reads dimmer on purpose. |
| **Four corners** | ~64×64 each, tiles (1,1)/(28,1)/(1,6)/(28,6) | Where things SETTLE: rubble piles, parchment drifts, moss. Corners are the natural "nobody swept here" pockets. |
| **Wall-adjacent alcove rhythm** | along walls between braziers, off the lane | Pillars (if gen'd, §5) + smaller rubble/moss accents to break the long bare wall-runs. |

**The shape to hand Drew:** picture two decorated rails (north + south wall bands) with corner-pockets at the ends, and a swept-clear aisle running W→E between them. Density is highest at the corners and along the walls; it drops to ZERO in the y≈112–176 lane.

---

## 3. LIGHT / SHADOW / TONE — brazier rhythm across the wider span

The single warm key-light is the through-line. Today: **4 lit braziers on the north wall** at x = 160 / 400 / 640 / 840 (≈240px apart). That spacing is actually decent across 960px — **keep all four lit braziers where they are.** The fix is *rhythm and contrast*, not more north-wall light:

1. **Add 1 COLD/guttered brazier on the SOUTH wall** (`brazier_cold`, currently unused), offset from the north rhythm — place it around x≈520, y≈228 (south band, between the lane and the south wall, NOT in the lane). This is the "this one went out" abandonment beat and it makes the south wall read *dimmer/colder* than the lit north wall — a top-to-bottom warmth gradient that adds depth to a flat top-down room.
2. **Brazier coherence:** the lit braziers stay the warm key (`#FFB066` core / `#FF6A2A` outer / `#2C261C` base — locked). Do NOT brighten via `modulate` (HDR-clamp: `#FF6A2A` R-channel is already at the 1.0 ceiling; a `>1.0` modulate is the PR #137 SWING_FLASH invisibility bug). If a glow pool under each brazier is wanted, that is a **ColorRect with the ember tint at sub-1.0 alpha — NOT Polygon2D** (PR #137 precedent: vector primitives go invisible on WebGL2 `gl_compatibility`). Author-flag only; the brazier sprite alone reads fine.
3. **Warmth gradient as composition:** lit north wall (warm) → clear sandstone aisle (neutral-warm) → dimmer south wall with the cold brazier + heavier moss (cooler/decayed). This gives the wide flat room a legible top-to-bottom tonal arc without any new lighting tech — it's pure placement.

The Vignette CanvasLayer (S1 30%, shipped, HDR-safe) still frames the whole as "single warm room." No new light node.

---

## 4. DECORATION BEATS — props + density target for a 960×256 room

Reuse the 7 approved s1_cloister props FIRST. Three are currently **placed**, three are **approved-but-unused** (`brazier_cold`, `banner_worn`, `pillar_arch`), one (`moss_patch`) is placed but can scale up. Target counts below are for THIS 960×256 room; the per-100px-of-width rate in §6 generalizes them.

| Beat (prop) | Today | TARGET (wide room) | Where (zone, §2) | Story beat |
|---|---|---|---|---|
| **Lit brazier** (`brazier_lit`) | 4 | **4** (keep) | North wall, x=160/400/640/840 | The light nobody put out |
| **Cold brazier** (`brazier_cold`) ⟵ unused | 0 | **1** | South wall ~x520 | "this one went out" |
| **Hanging banner** (`banner_worn`) ⟵ unused | 0 | **2** | North wall, between braziers (~x280, ~x720) | Faded ritual signifier; lines the hall |
| **Rubble** (`rubble_01`) | 2 | **4–5** | Corners + south band (off-lane) | Collapse / decay |
| **Parchment** (`parchment_01`) | 1 | **3** | Corners + near walls (where paper settles) | The monks' records, left to rot |
| **Moss patch** (`moss_patch`) | 2 | **4–5** | South band + corners + wall bases (damp) | Time, neglect |
| **Pillar/arch** (`pillar_arch`) ⟵ unused | 0 | **2–4** (see §5) | Wall-adjacent, flanking the aisle | Architectural weight; makes it a HALL |

**Total prop count: ~9 today → ~20–24 target.** Roughly a **2.3–2.7× density increase**, concentrated entirely in the wall bands + corners (the lane stays clear). That ratio is what reads "furnished" at game zoom with `char_scale=0.6` — the 0.6 shrink means on-screen object mass needs to roughly double vs the old full-scale single-screen feel to hold the eye.

**Variation discipline (so it doesn't read as copy-paste):** stagger props off a clean grid; vary which corner gets rubble-heavy vs parchment-heavy; mirror the banner rhythm against the brazier rhythm (banner *between* braziers, not aligned). Repetition of the SAME sprite at EVEN spacing reads as tiling — break it.

**Collision:** all decoration is visual-only (no collision), per the env-art brief. Rubble/pillars *could* be soft cover but that's a gameplay call and OOS here — Stage B places pure-decoration nodes only.

---

## 5. REUSE-VS-NEW — recommendation

**DEFAULT: pure reuse covers ~85% of the target.** The 7 approved props (with the 3 currently-unused ones activated) hit every beat in §4. Recommendation: **Stage B ships reuse-only first** — it's zero-cost, zero-risk, already doctrine-locked, and Sponsor can judge whether the room reads furnished before any new credits are spent.

**ONE conditional new-gen recommendation (only if reuse-only still reads bare at soak):**

| Candidate new prop | Count | Rationale | Verdict |
|---|---|---|---|
| **Floor crack / flagstone-fracture overlay** | 2–3 variants | The floor is the largest bare surface; cracks break the uniform sandstone WITHOUT adding standing objects to the lane (they're flat, lane-safe). Highest value-per-gen for "the floor itself looks worn." | **RECOMMEND if a 2nd pass is needed** |
| **Wider rubble shape** (long fallen-beam vs the round pile) | 1 | Current `rubble_01` is one silhouette; a 2nd shape kills copy-paste read along the south wall. | Nice-to-have |
| Wall banner 2nd variant | — | The single `banner_worn` repeated twice at staggered wear is enough; a 2nd gen is low-value. | **SKIP** |
| New pillar | — | `pillar_arch` (unused, 48×64) already exists — activate it, don't gen a new one. | **SKIP (reuse)** |

**Net new-gen recommendation: 0 in the first pass; up to 3–4 small `create_map_object` gens (2–3 floor-crack variants + 1 rubble shape) ONLY if Sponsor soak of the reuse-only pass still reads thin.** Floor cracks are the single highest-leverage add because they texture the biggest bare surface (the floor) while staying flat/lane-safe. Cost is small per `pixellab-pipeline.md` (single `create_map_object` calls, doctrine-locked Strategy-3 in pixel-mcp — the same pipeline that produced the existing 7). I do NOT generate art — orchestrator + Sponsor run PixelLab if this 2nd pass is approved.

---

## 6. REUSABLE PATTERN — applies to all 8 S1 rooms when they widen (S1B/S3)

This brief sets the density doctrine, not a one-off Room02 layout. When the other 7 rooms widen later, apply:

**The S1 wide-room density rule:**
1. **Density target ≈ 1 prop per ~40–50px of room WIDTH**, concentrated in the wall bands + corners. (960px → ~20–24 props. A 480px narrow room → ~9–11. Linear in width.) The `char_scale=0.6` shrink is already baked into this rate.
2. **Decorated rails + clear aisle.** North + south wall bands carry the mass; the central traversal lane (the row(s) connecting the entry/exit ports) stays ZERO-decoration. Always derive the keep-clear lane from the chunk-def's port `position_tiles`, never hardcode.
3. **Brazier rhythm ≈ every 240px** along the lit wall; warmth-gradient the opposite wall darker with a cold brazier + heavier moss/rubble.
4. **Corners settle.** Rubble/parchment/moss pile in the four corners — the "nobody swept here" pockets — at every room size.
5. **Always keep-clear:** every mob-spawn tile (read from chunk-def `mob_spawns`), both ports, the RoomGate swept area, and the fountain (if `place_healing_fountain`). Read these from the resource, not from memory.
6. **Sub-biome scaling** (env-art brief §2): the same rule, with prop *types* shifting — Cloister Walk (01-03) lighter, Disused Cells (04-06) heavier moss/parchment/cold-braziers, Sanctum approach (07-08) denser pillars funneling toward the boss. Density rises toward the boss; the keep-clear discipline never changes.

This rule is portable to S1B/S3 widening and forward-compatible with procgen: because decoration lives in the chunk `.tscn`, an assembled wide floor inherits its props for free (env-art brief §7.2).

---

## 7. Stage-B hand-off to Drew (impl checklist — for AFTER Sponsor taste-review)

1. Add ~11–15 new decoration `Sprite2D` nodes under the existing `Props` Node2D (z_index already +1), reusing the 4 already-placed prop textures + activating the 3 unused ones (`brazier_cold`, `banner_worn`, `pillar_arch`).
2. Honor §2 keep-clear absolutely: nothing in the y≈112–176 lane, nothing within ~48px of a mob-spawn tile, nothing in the gate/port regions.
3. Stagger placement off a clean grid (§4 variation discipline).
4. Any brazier glow-pool = ColorRect ember tint at sub-1.0 alpha, NOT Polygon2D; NO `>1.0` modulate (§3).
5. NO collision / gameplay-coord / spawn / gate changes — decoration nodes ONLY.
6. Paired test: decoration nodes present after `_ready`, no USER WARNING. HTML5-visual-gated → Self-Test Report + Tess verify + Sponsor soak (judge IN-CONTEXT at game zoom + 0.6 scale per Pre-soak Gate 4).

---

## 8. Decision draft + Sponsor taste-review surface

**Decision draft (2026-06-03)** — for Priya's weekly `DECISIONS.md` batch (NOT direct-edited per Uma role rule):
> **S1 wide-room decoration-density doctrine set.** Widened Outer Cloister antechamber reads as "a hall built for a crowd that no longer comes." Density ~9→~20–24 props for the 960×256 room (≈1 prop/40–50px width), concentrated in wall bands + corners with a ZERO-decoration central lane (W→E traversal + combat arena). Activates the 3 approved-but-unused props (cold brazier / banner / pillar). Warmth gradient: lit north wall → clear aisle → dimmer south wall (cold brazier + heavier moss). Pure reuse first (0 new gens); conditional 2nd pass of ~3–4 floor-crack/rubble `create_map_object` gens only if reuse-only soaks thin. Reusable rule generalizes to all 8 S1 rooms at S1B/S3 widen + procgen (decoration-in-chunk-`.tscn` inherits for free). Reversibility: decoration is additive Sprite2D nodes; revertible by deleting them.

**Sponsor taste-review surface (what to veto/approve):**
1. **Tonal anchor** (§1): "a hall built for a crowd that no longer comes — decorated rails, clear aisle." Right read for the wide antechamber, or different?
2. **Density target** (§4): ~9→~20–24 props (2.3–2.7× increase). Too much / too little?
3. **Warmth gradient** (§3): lit north wall vs dimmer south wall via 1 cold brazier + heavier south moss. Worth doing, or keep symmetric?
4. **Reuse-vs-new** (§5): reuse-only first pass (0 gens), with conditional floor-crack gens (~3–4) only if it soaks thin. Approve, or pre-authorize the floor cracks now?
5. **Reusable pattern** (§6): lock this density rule as the S1 wide-room doctrine for S1B/S3, or treat Room02 as one-off and revisit?

---

## 9. Cross-references (every count/anchor above traces here)

- `scenes/levels/chunks/s1_room02_wide_chunk.tscn` — the proof room; existing prop placement (4 lit braziers north wall y=28 @ x160/400/640/840; 2 moss; 1 parchment; 2 rubble). The Stage-B impl seam.
- `resources/level_chunks/s1_room02_wide.tres` — chunk-def: 30×8, ports entry(0,4)/exit(29,4), 4 grunt spawns at tiles (10,3)/(15,5)/(21,3)/(25,5) → px (336,112)/(496,176)/(688,112)/(816,176). Keep-clear anchors derive from here.
- `scenes/levels/Stratum1Room02.tscn` — RoomGate at (48,144) size (48,80); `place_healing_fountain = false`.
- `scripts/levels/S1CloisterChunk.gd` — the floor/wall painter (grid_w=30 override). Decoration is additive over this; does NOT touch the painter.
- `assets/props/s1_cloister/` + `_generation_map.md` — the 7 approved doctrine-locked props (banner_worn 32×48, brazier_cold 32×48, brazier_lit 32×48, moss_patch 32×32, parchment_01 32×32, pillar_arch 48×64, rubble_01 32×32). Reuse FIRST.
- `team/uma-ux/env-art-s1-direction.md` — the LOCKED Outer Cloister look (`86ca3gvgb`): tonal anchor, palette ramp, prop roster, sub-biome plan §2, prop placement rules §5, HTML5/HDR/Polygon2D constraints §4.1.
- PR #404 (widened Room02) + PR #405 (`char_scale=0.6`) — the soak that triggered this density pass.
- `.claude/docs/html5-export.md` — HDR-clamp sub-1.0, Polygon2D→ColorRect rule (§3 brazier-glow), z-index, visual-verification gate.
- `.claude/docs/pixellab-pipeline.md` — `create_map_object` + Strategy-3 doctrine-lock + cost model (§5 conditional new gens).
- `team/TESTING_BAR.md` Pre-soak Gate 4 — judge density IN-CONTEXT at game zoom + 0.6 char scale, never isolated swatches.
