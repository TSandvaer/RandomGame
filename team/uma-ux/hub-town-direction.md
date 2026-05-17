# Hub-Town Visual Direction — Cloister Reawakened (M3 Tier 1)

**Owner:** Uma · **Phase:** M3 Tier 1 (design only; implementation lands in Drew's `HubTown.tscn` + Devon's save-state hooks per `m3-tier-1-plan.md` §2-T2) · **Drives:** Drew's hub-town scene authoring (NPC scenes, 3 prop sprites, descent-portal interactable), Devon's `meta.hub_town_seen` save hook + scene-routing spike, Tess's M3 acceptance rows for §2.

This doc extends `team/uma-ux/visual-direction.md` (480×270 internal canvas, integer scale, nearest-neighbour, ember-orange through-line) and `team/uma-ux/stash-ui-v1.md` (between-runs venue rules: no mobs, `Engine.time_scale=1.0`, menu-pad volume) into the M3 hub-town surface. It is design-only — nothing here ships in code until M3 Tier 2 dispatches consume it.

## TL;DR (5-line summary)

1. **Tonal anchor — "the cloister did not stay empty."** Hub-town reads as the **Outer Cloister awake** — the same sandstone bones the player walked into at the start of S1 R1, but now populated by three monks who tend the braziers, mind the anvil, and post the bounties. **Not a new biome; the same biome reframed as home.** This is the diegetic answer to "where does the player live between runs": where they started.
2. **Single-screen 480×270 canvas, Outer Cloister palette.** Reuses S1 sandstone floor, cloister masonry walls, brazier sprite, ember-accent torches. New authoring is restricted to 3 NPC pawns + 3 anchor props (anvil station, vendor stall, bounty-board) + 1 descent-portal interactable. Cheap; defers "new biome" to M4 polish.
3. **Three NPCs at fixed positions:** Vendor (Hadda, west), Anvil-keeper (Brother Voll, center), Bounty-poster (Sister Ennick, east). Each is a stationary humanoid silhouette with a single 4-frame idle anim + an interact prompt. Names + visual descriptors below.
4. **Descent-portal at south edge** — the M2 "Down to descend" door evolves into a glowing-arch portal that opens a stratum picker UI (`S1`, `S2`, ... up to `meta.deepest_stratum`). Player walks up + presses E; UI overlays. Replaces the room-step descent pattern.
5. **Ambient identity distinct from S1 stratum BGM.** New cue `mus-hub-town` — sparse, hopeful, dawn-feel. Same dark-folk-chamber ensemble (per `audio-direction.md §1`) but the **frame drum is silent** and the piano leads. Ambient bed `amb-hub-town` is wind-through-cloister + distant bell-chime. This is the audio cousin of the visual reframe: same instruments, different posture.

## Source of truth

This doc extends:

- **`team/uma-ux/visual-direction.md`** — 480×270 internal canvas, 96 px/tile, integer scale, nearest-neighbour, ember accent `#FF6A2A` through-line. Hub-town conforms verbatim.
- **`team/uma-ux/palette.md`** Stratum 1 — sandstone floor `#7A6A4F`, cloister walls `#4A3F2E`, brazier flame `#FFB066`/`#FF6A2A`, parchment `#D7C68F`. Hub-town renders from this hex set with one addition (the descent-portal arch glow — see §4 below).
- **`team/uma-ux/stash-ui-v1.md` §1** — between-runs venue rules: `Engine.time_scale = 1.0`, no mobs, no hazards, ambient music at menu-pad volume, vignette at 20%. Hub-town inherits these.
- **`team/uma-ux/audio-direction.md` §1+§2** — dark-folk-chamber ensemble, single-bell discipline. Hub-town adds two cues to the cue list; no new instruments.
- **`team/priya-pl/m3-design-seeds.md` §2** — the framing seed ("the Outer Cloister but populated") this doc commits to as the M3 baseline. Defaults locked: single-screen (`§2.4`), 3 NPCs (`§2.5`), Outer Cloister evolution (`§2.6`).
- **`team/priya-pl/m3-tier-1-plan.md` §2** — Tier 1 sequencing. This doc IS §2-T1's deliverable.
- **`.claude/docs/html5-export.md`** — HDR clamp + Polygon2D rendering quirks shape the visual-primitive calls in §4.

---

## §1 — Tonal anchor: "the cloister did not stay empty"

The hub-town is **not a new place**. It is the **first place the player ever saw** — the entry room of Stratum 1, the Outer Cloister — re-encountered after the player has descended, died, returned. The diegetic claim: monks have been here all along. The player ran past them on the first run because they were busy descending; now, between runs, they stop and see who lives here.

**Why this framing carries:**

- **Diegetic continuity.** The Outer Cloister was the player's first impression of Embergrave's tone (warm sandstone, ember accents, single-warm-light-source per `visual-direction.md`). Reusing it as the hub-town means the player's "home" is the same architecture as their first impression. Crystal Project's Capital City does this; Hades's House of Hades does this with the inversion ("you live in the place the dead live"); Dark Souls's Firelink Shrine does this. Embergrave's hub-town is the **warm-version** of the same room.
- **Descent narrative payoff.** Each time the player returns to the hub after a run, they pass back through the same warm light they left. The descent narrative is **circular**, not linear — you go down, you come back up, you find that the place you left is unchanged. That stability is what makes the deepening strata feel like the player is moving, not the world.
- **Production-cheap.** Per `m3-design-seeds.md §2.6` — same tile language, same hex codes, same brazier sprite. The new authoring is 3 NPC pawns + 3 anchor props + 1 portal. Everything else is `palette.md` paste.
- **Rejects the "surface village" framing.** Some hub-town designs put the player on the surface (above the dungeon, in town). Embergrave's narrative spine is *descent*; the hub-town must sit **at the descent threshold**, not above it. The Outer Cloister IS the threshold — it's where the cloister stones meet the unmapped depths. That's exactly where the hub belongs.

**Reads as:** quiet, warm, lived-in. Not bustling. The three monks are stationed, not wandering. Two braziers crackle at the north wall. Two scrolls lie on the anvil. The bounty-board has parchments pinned with iron nails. The descent-portal at the south wall glows with ember-light. The player crosses through this room before every descent; it is the **last quiet moment** before the dark.

**Tonal anti-references** (what hub-town must NOT read as):

- **Bustling town square** (Stardew Valley town map) — too cozy; breaks descent gravity.
- **Grand cathedral / chapter house** (Dark Souls 3 Firelink Shrine architecture) — too monumental; the cloister is **modest**, not grand.
- **Hades's House of Hades** (rich tapestry, abundant trinkets) — visually too dense for our pixel-art budget AND tonally wrong (Hades is wry; Embergrave is solemn).
- **Crystal Project Capital City** (sprawling multi-room) — too large for M3.0 budget (`m3-design-seeds.md §2.4` defaults single-screen).

The reference shelf is closer to: **Hyper Light Drifter's central plaza** (small, quiet, anchored on a single warm light), **Tunic's hub island** (sparse populated; player is the visitor), **Crystal Project's first-town inn** (modest, monks tending tasks).

---

## §2 — Visual shape

### Internal canvas + camera

- **Logical resolution:** 480 × 270 px (per `visual-direction.md` lock). Single-screen, zero-scrolling.
- **Tile size:** 32 × 32 internal (3× scale onscreen). Same as S1 R1.
- **Camera:** dead-centered, no smoothing, no look-ahead (per `visual-direction.md` non-combat default).
- **Player footprint:** 32 × 48 internal (unchanged from `visual-direction.md`).

The room is **wider than tall** — the cloister architecture is a long colonnaded hall, not a square chapel. Layout approximates:

```
+-------------------------------------------------------------------+
|  [BRAZIER]                                            [BRAZIER]   |
|       \                                                 /         |
|                                                                   |
|   [HADDA]              [BROTHER VOLL]            [SISTER ENNICK]  |
|   vendor                anvil-keeper             bounty-poster    |
|   (W stall)             (C anvil)                (E parchment-bd) |
|                                                                   |
|                          [PLAYER ENTRY]                           |
|                                                                   |
|                          [DESCENT ARCH]                           |
|                          ember-glow portal                        |
+-------------------------------------------------------------------+
```

Approximate coordinate anchors (in 480×270 logical pixels; player spawn at center-south):

| Anchor | Position (x, y) | Notes |
|---|---|---|
| Player spawn (on return from run) | (240, 200) | Center-south; player faces north, sees the room |
| Hadda (vendor) | (96, 120) | West third, midline |
| Brother Voll (anvil-keeper) | (240, 96) | Center, slightly north (the anvil is the room's focal point) |
| Sister Ennick (bounty-poster) | (384, 120) | East third, midline |
| North brazier (left) | (128, 48) | NW; flame anim already exists S1 |
| North brazier (right) | (352, 48) | NE; flame anim already exists S1 |
| Descent-portal arch | (240, 240) | Center-south; player walks up + E to open stratum picker |

**Why this layout:**

- **Diagonals of approach.** Player spawns south, sees three NPCs in a triangular spread. The player's first glance reads all three NPC affordances at once — no scrolling, no exploration phase to discover what's available.
- **Anvil as visual anchor.** Brother Voll + the anvil are the **center-north** anchor; the room composes around them. The anvil is the M3 affix-reroll surface (per `mvp-scope.md §M3` "crafting/reroll bench") — it earns the center spot because rerolling is the M3 economy primitive most players will engage with most often.
- **Descent-portal at south.** Player walks **toward** the portal to leave; the portal is the bottom of the screen. This matches the M2 "Down to descend" door convention — descent is south, return is from the south edge inward.
- **Two braziers, not one.** Symmetric warm light from the NW + NE corners reinforces the "warm key light per scene" rule (`visual-direction.md` lighting model) — the cloister's lighting is mirrored, the room feels balanced, not stage-lit.
- **No interior pillars / columns blocking sight lines.** The cloister architecture has pillars (per `palette.md` Outer Cloister section "Trim / pillar `#9A7A4E`"), but in hub-town those sit AT the room edges, not internal. A clear sight line from spawn to every NPC + the portal is required — the player should never have to camera-pan to see what's available.

### Tile-reuse strategy — Outer Cloister evolution

Per `m3-design-seeds.md §2.6` default. **Specific reused assets** (no new sprite authoring required for the environment):

| Asset | Source | Reuse role |
|---|---|---|
| Sandstone floor (`#7A6A4F` / `#5C4F38` / `#A89677`) | S1 R1 tilemap | Hub-town floor — full ramp |
| Cloister masonry walls (`#4A3F2E`) | S1 R1 tilemap | Hub-town walls |
| Olive moss accent (`#5C7044`) | S1 R1 tilemap | Sparse use — north corner brick joints |
| Brazier base + flame (`#2C261C` + `#FFB066` + `#FF6A2A`) | S1 R1 brazier sprite | Two instances at NW + NE corners — **identical sprite to S1 R1** |
| Parchment color (`#D7C68F`) | `palette.md` Outer Cloister accents | Bounty-board parchments + scattered scrolls on anvil |
| Trim / pillar bronzed (`#9A7A4E`) | `palette.md` | Room-edge column trim |
| Doorway ember-glow (`#FF6A2A` 60% opacity) | S1 doors | Descent-portal arch glow (same hex, larger area) |

**New authoring** (Drew's M3 Tier 2 §2-T2 ticket):

1. **Three NPC pawns** — see §3 below.
2. **Anvil station prop** — 32 × 32 internal. Iron-grey body (`#3A363D` matches inventory cell-border slate, close enough), two scrolls on top (`#D7C68F` parchment). No anim (static); ember-glow `#FF6A2A` 40% opacity halo when player is within 1.5 tiles (proximity affordance — see §3 interaction model).
3. **Vendor stall prop** — 24 × 32 internal. Wooden frame (`#5A4738` grunt-cloth hex — re-use; warm-brown reads as worn wood) with parchment banner (`#D7C68F`) hung from the top edge; a small inventory pile visible (3-4 generic gear-icon silhouettes in tier-color borders — re-use existing pickup sprites at 50% scale).
4. **Bounty-board prop** — 24 × 32 internal. Dark cloister stone (`#4A3F2E` wall hex) with 3 parchments (`#D7C68F`) pinned with iron nails (`#9C9590` grunt-weapon-edge hex — re-use). One parchment has an ember-orange wax seal (`#FF6A2A`) — the active bounty.
5. **Descent-portal arch** — 48 × 64 internal. The cloister doorway frame (bronzed trim `#9A7A4E`) with an ember-orange luminous interior — see §4 visual-primitive note. The interior is the player's affordance to interact.

**Sprite-reuse leverage:** all environment, the brazier, the doors, the pillars come for free from S1 R1. The new authoring is **5 sprites total**. This is the cheapest-possible hub-town.

### Vignette + lighting

- **Vignette:** 20% opacity (matches `stash-ui-v1.md §4` stash-room ambient — between-runs venues read brighter than in-run rooms). S1 R1 in-run is 30%; hub-town drops to 20% to signal "safe."
- **Light sources:** two braziers (NW + NE) + portal ember-glow (south arch interior). The two braziers are the dominant warm-key sources; the portal arch is a subordinate ember-accent (cooler hue relationship — see §4).
- **Player low-HP red pulse:** suppressed in hub-town (per `stash-ui-v1.md` no-combat-context rule). The HUD HP bar still shows current HP, but the vignette red-pulse overlay is `_set_red_pulse_enabled(false)` while `Levels.in_hub_town == true`. Devon's call on the exact flag plumbing.
- **Ember motes (decorative):** sparse particle drift rising from the braziers (4-5 motes/sec, `#FFB066` highlight on `#FF6A2A` core, 0.5 px/frame upward velocity, fading at top edge). Reuses S1 R1 brazier mote shader; no new code.

---

## §3 — Three NPCs: names, visual descriptors, interaction model

The three monks are stationary humanoid pawns at fixed positions. Each has a single 4-frame idle anim (12 fps, ~1 s loop) — subtle breathing or task-motion. None walk. Player walks up to them and presses **E** to interact (consistent with existing pickup-interact key — see §6 input bindings).

### Vendor — Hadda (west position)

**Diegetic role:** the cloister's quartermaster. Sells gear at fixed prices, buys excess inventory. Per `m3-design-seeds.md §2` — Diablo II Charsi-style.

**Name:** Hadda. Short, two-syllable, scriptural-feel without being specifically referential. Easy to remember; reads as feminine but tonally neutral.

**Visual descriptor:** older woman, weathered. Heavy brown cloth robe — `#5A4738` (S1 grunt cloth hex; the diegetic logic is the same as the cult-monks-of-the-Reach: cloister monks wear the same tattered brown). A heavier leather apron over the robe — `#5C3F2A` (S4 Hollow Foundry bellow-leather hex; re-used because she works with goods, has a quartermaster's wear). Grey hair pulled back, tied with a parchment-colored ribbon (`#D7C68F`). One hand rests on the stall edge; the other gestures slightly during the idle anim. Eyes are visible as two small dark dots; **no aggro eye-glow** — she is human, not hostile (no `#D24A3C` pulse).

**Pose:** standing behind her stall, half-facing the player (3/4 turn). 32 × 48 internal footprint.

**Idle anim:** 4f at 12 fps. Frames: (1) shoulders down, hand on stall; (2) shoulders rise slightly (inhale); (3) shoulders peak; (4) shoulders descend (exhale). Subtle ~2 px vertical drift on shoulders + a 1 px head bob. Same shape as the player idle from `visual-direction.md` Animation Feel section.

**Interact affordance:** when player is within 1.5 tiles, a 12 px ember-orange **E** glyph (`#FF6A2A`) appears 24 px above her head, drawn as a **`Label` node** with the project default font — plain ASCII, safe per `html5-export.md` default-font-glyph rule. Player presses E → vendor UI opens (Drew's M3 Tier 2 ticket; UI surface design is a separate dispatch, NOT this doc).

**Voice / dialogue tonal note:** sparse, practical. "Take what you need." "Leave what you don't." Three lines maximum per visit, randomly selected. No lore-dump; she's a quartermaster, not a storyteller.

### Anvil-keeper — Brother Voll (center position)

**Diegetic role:** affix-reroll surface. Per `mvp-scope.md §M3` "crafting/reroll bench" — the cloister's smith. Player brings an item; Brother Voll rerolls one affix on it; cost is ember-shards (per `m3-design-seeds.md §3` currency primitive).

**Name:** Brother Voll. The "Brother" carries the monastic order tone; "Voll" is a short Germanic-feel monosyllable, easy to remember.

**Visual descriptor:** middle-aged man, broad-shouldered. Same heavy brown robe (`#5A4738`) as Hadda — the cloister wears one cloth. Leather smithing gauntlets — `#3A363D` (cell-border slate; reads as worn leather). A bronze trim band on his chest (`#9A7A4E` cloister trim hex) — the smith's-medallion. Bald with a circle of dark hair (a tonsure); head reads as a `#A0856B` skin oval (S1 grunt skin hex). He holds a small smith's hammer in his right hand, resting on the anvil edge. **No aggro eye-glow.**

**Pose:** standing behind the anvil, facing the player (full-front). 32 × 48 internal footprint.

**Idle anim:** 4f at 12 fps. Frames: (1) hammer down on anvil; (2) hammer lifts ~4 px; (3) hammer peak ~6 px; (4) hammer descends. Soft tap on each cycle — but **no audio cue** (the cue is reserved for the active reroll interaction). The shoulders also rise/fall subtly with the hammer. Distinguishes him visually from the other two NPCs at a glance (he is the one *working*).

**Interact affordance:** identical to Hadda — ember-orange **E** glyph above head when player within 1.5 tiles. Press E → reroll UI opens.

**Voice / dialogue tonal note:** terse, smith's-language. "Show me." "The flame will hold." "Pay the shards." Three lines max per visit.

**Why center position:** the anvil-reroll is the M3 economy primitive most players will engage with most often (per `m3-design-seeds.md §3` — currency exists to be spent at the anvil). The center spot earns visual primacy. Brother Voll is the visual center of the room.

### Bounty-poster — Sister Ennick (east position)

**Diegetic role:** bounty-board / lore-giver. Per `mvp-scope.md §M3` "bounty quest system" — hands out per-run tasks (kill N of mob type X in stratum Y); reward is ember-shards + lore-text snippet (per `m3-design-seeds.md §3`).

**Name:** Sister Ennick. The "Sister" matches Brother Voll's monastic title; "Ennick" is two-syllable, feminine-leaning but ambiguous-OK.

**Visual descriptor:** younger woman, slender. Same heavy brown robe (`#5A4738`) — uniform across the order. A hooded cowl drawn back to her shoulders (so her face is visible). Parchment-colored prayer cord around her waist (`#D7C68F`). Her right hand holds a small leather-bound book; her left hand gestures slightly toward the bounty-board behind her during the idle anim. Black hair, tied with a leather thong. **No aggro eye-glow.**

**Pose:** standing in front of the bounty-board, facing the player at a slight angle (5/8 turn) so she reads as gesturing toward the board. 32 × 48 internal footprint.

**Idle anim:** 4f at 12 fps. Frames: (1) book held at waist; (2) book lifts to chest-height; (3) book peak; (4) book descends. Subtle gesturing motion toward the board on each cycle. The implication is "she's about to read you something."

**Interact affordance:** identical to Hadda + Voll — ember-orange **E** glyph + press E.

**Voice / dialogue tonal note:** more verbose than the other two — she's the lore-giver. Each bounty assignment is a 2-3 sentence narrative framing ("The vault-forged stokers still burn in S2. The flame demands their quenching. Bring me proof of three."). Lore-text snippets unlocked via completed bounties are stored in `meta.lore_unlocked` (per `m3-design-seeds.md §3`) and read back from her on subsequent visits.

**Why east position:** narratively, the player reads the room left-to-right (Western reading order). Vendor first (transactional), anvil center (mechanical), bounty-poster last (narrative). The reading order is the player's recommended visit order on each return — pay attention to gear (Hadda), reroll if needed (Voll), pick up the next story-thread (Ennick).

### Common interaction rules (all three NPCs)

- **Interact key:** **E** (consistent with existing pickup-interact + stash-chest-open affordances per `stash-ui-v1.md §1`).
- **Proximity threshold:** 1.5 tiles (48 logical px) from the NPC's center. Same as pickup-interact threshold.
- **Interaction prompt:** ember-orange **E** glyph (`#FF6A2A`) 24 px above the NPC's head, drawn as a `Label` node with the project default font (ASCII-safe per `html5-export.md`). Fade-in 0.2 s on proximity-enter; fade-out 0.2 s on proximity-exit.
- **First-visit hint-strip** (per `m3-design-seeds.md §2 Save-schema`): on the player's **first-ever** hub-town visit (`meta.hub_town_seen == false`), a non-modal hint-strip appears at screen-bottom for 5 s: `[E] Talk · [Down] Descend · [B] Stash · [Tab] Inventory`. Same shape as `stash-ui-v1.md §3` Stash-Room-Entry hint-strip. After the first visit, `meta.hub_town_seen = true` and the hint never re-shows in that save slot.
- **Talk-to-NPC opens a focused modal UI.** Each NPC has its own UI surface (vendor inventory grid, reroll bench panel, bounty board panel). **These UIs are NOT designed in this doc** — they are separate M3 Tier 2 dispatches per `m3-tier-1-plan.md` sub-milestones. This doc locks: NPC positions, names, visual descriptors, idle anims, interact affordances. The UIs they open are downstream tickets.
- **Engine.time_scale during modal:** the player retains `time_scale = 1.0` during NPC-UI modals (per `stash-ui-v1.md §1` between-runs rule). The world is already paused (no mobs, no hazards); no time-slow is needed.
- **Esc closes the UI.** LIFO close stack per `stash-ui-v1.md §1`.

---

## §4 — Descent-portal: south-edge ember arch

The descent-portal replaces the M2 "Down to descend" door (the single tile on the south wall the player walks into to commit to a run). In M3, the descent action **opens a stratum-picker UI** instead of immediately loading a fixed scene — the player chooses where to descend, gated by `meta.deepest_stratum`.

### Visual shape

- **Sprite:** 48 × 64 internal (1.5 × 2 tiles). Sits flush with the south wall, center horizontal.
- **Frame:** bronzed trim (`#9A7A4E` cloister-trim hex) — a stone-and-iron archway, ornate but not gaudy. Reuses the door-arch pattern from S1 R1's exits, scaled up by 1.5×.
- **Interior:** ember-orange luminous area, `#FF6A2A` core to `#FFB066` highlight gradient, with a soft falloff to the outer rim. **Critical visual-primitive call** — see Visual-primitive note below.
- **Idle anim:** the interior pulses subtly — 6 fps, 4 frames, opacity range 70% → 100% → 90% → 80% loop. Reads as living flame, same energy-language as the braziers but bigger. **Engine.time_scale = 1.0** in hub-town, so the pulse renders at full rate.
- **Embers rising:** sparse mote particles drift up from the interior (3-4 per sec), `#FFB066` highlight color, 0.5 px/frame upward velocity. Re-uses the brazier mote shader.

### Interact affordance

- **Proximity:** 1.5 tiles from portal center (same as NPC interact threshold).
- **Prompt:** ember-orange **[Down] Descend** glyph at the player's feet (12 px font, `Label` node, ASCII-safe — `Down` not an arrow glyph per `html5-export.md` default-font-glyph rule). Fade-in 0.2 s.
- **Key:** **Down arrow** (or **S**) — consistent with the M2 "Down to descend" pattern from `stash-ui-v1.md §3` Stash-Room-Entry hint-strip. **NOT E**, to disambiguate from NPC interact.
- **On press:** stratum-picker UI overlays. The player sees a list of available strata (S1, S2, ..., up to `meta.deepest_stratum`), confirms a selection, descends.
- **Stratum-picker UI design:** **NOT in scope for this doc.** Recommended owner: Drew (M3 Tier 2 §2-T2). The picker is a focused modal with rows for each unlocked stratum + last-descended-result hint per stratum (e.g., "S2 · last run: died at room 3" — pulled from `meta` save data).

### Visual-primitive note — HDR-clamp + WebGL2 compatibility

The portal's luminous interior is a **gradient ember-glow at full saturation**. This is exactly the visual-primitive class where M1 PR #137 was burned (the swing-flash tint `Color(1.4, 1.0, 0.7)` was clamped to `(1.0, 1.0, 0.7)` in HTML5, killing the visible delta). **Recommended primitive choices for Drew:**

1. **Use `ColorRect` nodes, NOT `Polygon2D`,** for the ember-glow body. The Polygon2D / `gl_compatibility` rendering quirk (per `.claude/docs/html5-export.md`) — a multi-vertex polygon may render correctly on desktop and **invisibly** in HTML5. ColorRect rotated/sized to fit the arch interior is the safe primitive. PR #137 precedent.
2. **All tween/modulate color targets MUST stay sub-1.0 on every channel.** The pulse animation tweens the ember-glow's modulate channel between approximately `Color(0.95, 0.55, 0.20)` and `Color(0.95, 0.65, 0.30)` — both sub-1.0 on every channel. **Do NOT use `Color(1.0, 0.7, 0.3)` as a tween peak** — even though it's technically in-range, the HDR clamp at exactly 1.0 has a sub-perceptible delta concern. Pick `0.95` or `0.92` peaks to leave margin.
3. **z_index discipline.** The portal sits on the south wall — `z_index = 1` (above floor, below player) is the right layer. **Do NOT use `z_index = -1`** for any portal sub-component — per `html5-export.md`, negative z_index in `gl_compatibility` can sink below the room background. PR #137 lifted to +1 as part of the same fix.
4. **Default-font hint glyphs.** `Down`, `Descend`, `E`, `Talk`, `Stash`, `Inventory` — all ASCII, all safe. If a future iteration wants an arrow glyph (e.g., `↓ Descend`), import a custom `.ttf` per `html5-export.md` default-font-glyph rule. **First implementation should use plain ASCII.**

These four are **mandatory** — they are the load-bearing primitive calls that prevent the visual from becoming an HTML5-only regression at merge time. Drew should cite this section in the §2-T2 PR Self-Test Report.

### Diegetic logic

The portal is **the embergrave seam surfacing into the cloister**. The same substance the player carries (their flame), the same substance that feeds the braziers, the same substance that runs in veins through Stratum 2 (per `palette-stratum-2.md §3` vein-core motif) — it pools here, at the cloister's threshold, and the monks have built an arch around it. Stepping through the arch IS the descent: the player's flame mixes with the seam's, and they fall.

This is the **second** location in the game where ember-substance is both player-personal AND environmental (S2 vein-cores were the first; per `palette.md` cross-stratum ember-role table). The disambiguation rules from `palette-stratum-2.md §6` apply: portal interior is **band-shaped** + **fixed in space** + **arch-mounted**, where the player's flame is **mote-shaped** + **rising** + **attached to the player**. Three distinct shape/motion/position roles for visually-similar hex codes.

---

## §5 — Audio identity: hub-town has its own bed

Hub-town's audio is **distinct from S1 stratum BGM**. The diegetic claim is "this is home, not the dungeon"; the audio cousin of that visual reframe is **softer percussion + leading piano + sparser frame**. Same `audio-direction.md §1` dark-folk-chamber ensemble; different posture.

### New cues (additions to `audio-direction.md §2` cue list)

| Cue ID | Type | Trigger | Mood / keyword | Length / loop spec | Source plan | Priority |
|---|---|---|---|---|---|---|
| `mus-hub-town` | Music | Player in hub-town scene (looped) | sparse, hopeful, dawn-feel, leading piano | ~90 s loop, no hard stop | hand-composed — **M3 ships placeholder synthesis (`<deferred-M4>` promotion to DAW final);** rationale: hub-town is the most-heard scene in M3, deserves a hand-composed pass eventually | M3 must |
| `amb-hub-town` | Ambient | Player in hub-town scene (layered under `mus-hub-town`) | distant wind through cloister, faint bell-chime every 20-30 s, sparse parchment-rustle | 60 s loop | freesound (wind + bell tail) + hand-mix | M3 must |
| `sfx-hub-anvil-tap` | SFX | Brother Voll's idle-anim frame 1 (hammer-down) | soft anvil tap | 0.15 s | hand-Foley (light hammer on metal) | M3 nice |
| `sfx-hub-portal-pulse` | SFX | Descent-portal idle pulse peak (every 4th frame of the 6 fps anim, so ~1.5 s cadence) | low ember-glow whoosh | 0.40 s | reuse `sfx-ember-rise` filtered low; no new authoring | M3 nice |

### Tonal direction for `mus-hub-town`

- **Instrumentation:** felted piano leads (the **leading instrument** — first time the piano takes lead in any Embergrave cue; in all stratum BGMs the piano is texture, in hub-town it carries the melody). Single cello drone underneath (low register, sustained, ~30% of the piano's mix volume). Occasional bronze bell strike (every ~15 s, long reverb tail). **No frame drum** — this is the audio identifier that distinguishes hub-town from any stratum BGM. The frame drum is the dungeon's heartbeat; hub-town is **above the heartbeat**.
- **Tempo:** slow. ~50-60 BPM. Slower than `mus-stratum1-bgm` (~70 BPM frame-drum) and ~`mus-stratum2-bgm` (~65 BPM). The hub feels **paused**, not paced.
- **Key:** suggest major mode (a single major triad cello drone — D2-F#2-A2 or G2-B2-D3) — contrasts with the minor modes of the stratum BGMs (e.g., S2 boss is D-minor third). This is the **only place** in the game with major tonality; the descent narrative pays off harmonically too. **Sponsor-input item** (deferrable): if Sponsor wants hub-town in minor for tonal consistency, Uma redirects in v1.1 — major is the recommended call.
- **Length:** ~90 s loop. Long enough that the player doesn't notice the loop point on a 2-3 minute hub visit. Loop-point should be on a sustained cello note, no percussive landmark (so the seam is invisible).
- **Reference:** Dark Souls 1's Firelink Shrine theme (sparse piano + bell + cello), specifically the second half where the piano comes forward.

### Tonal direction for `amb-hub-town`

- **Bed:** distant outdoor wind (filtered, low gain, ~-24 dB). Not gale-force — **a breeze through stone arches**. Hints that the cloister is at the surface, that there's a world above. The player rarely consciously hears this layer but feels its absence if it's not there (the "what does silence sound like" question).
- **Bell-chime accent:** a single bronze bell strike every 20-30 s (randomized within range), with a 2 s reverb tail. **Reuses `sfx-bell-struck`** from `audio-direction.md §2` — no new authoring. Mix volume ~-18 dB so it sits below `mus-hub-town`'s bell strikes. Diegetic: a distant cloister bell tolls; the monks count time.
- **Parchment-rustle:** sparse, ~1 per 30-45 s, very quiet (~-30 dB). Hand-Foley (paper rustle, 0.2 s). Reads as Sister Ennick turning a page in her book OR a scroll moving on the anvil. Decorative; doesn't sync to NPC anim frames.

### HTML5 audio-playback gate

Per `.claude/docs/audio-architecture.md` § "HTML5 audio-playback gate" — `mus-hub-town` + `amb-hub-town` MUST fire **after** a user gesture, not at hub-town scene `_ready()` (no gesture has happened yet on first load). **Safe-by-default cue site:** the descent-portal interact (player presses Down at the M2 "Down to descend" door before they ever reach hub-town in M3's flow) — that keypress is a gesture, AudioContext unlocks there. **Devon's wiring call** when §2-T2 lands: route `AudioDirector.play_hub_town_entry()` from the player's first hub-town scene-entry signal, which arrives post-gesture.

### Ducking + bus assignment

- `mus-hub-town` → `BGM` bus (-12 dB per `audio-direction.md §3`).
- `amb-hub-town` → `Ambient` bus (-18 dB).
- `sfx-hub-anvil-tap` → `SFX` bus (-6 dB).
- `sfx-hub-portal-pulse` → `SFX` bus.
- **Sidechain ducking:** when an NPC modal opens (vendor / reroll / bounty UI), duck `mus-hub-town` to -18 dB (additional -6 dB cut) for the modal duration. Same pattern as `audio-direction.md §3` panel-open duck rule. Restored on modal close.

### Cycle-time risk

`mus-hub-town`'s 90 s loop on a hub-town session is fine — most visits are 30-90 s (talk to one NPC, hit descend). On a longer session (player rerolling many affixes), the loop may be heard 2-3 times. Recommend the loop's primary melodic phrase be **harmonically stable** (no strong cadences that punctuate the loop) so the seam is invisible. Same discipline as stratum BGMs.

### Quality-deficit acknowledgement

The brief notes that M2 ships placeholder synthesis (libsndfile q5) for `mus-stratum2-bgm` + `mus-boss-stratum2` + `amb-stratum2-room`, with `<deferred-M3>` markers for DAW promotion. **Hub-town's cues land in the same posture:** M3.0 ships placeholder synthesis; **the spec is q7 final-quality**; the promotion target is M4 or post-M3-RC-soak whichever comes first. Logged here so `audio-direction.md §6` (placeholder synthesis disclosure) absorbs hub-town when v1.1 amends.

---

## §6 — Input bindings + first-visit gating

Hub-town input bindings extend the conventions from `stash-ui-v1.md §1` (B-key + Tab + Esc + E + Down). **No new keys are introduced.**

### Binding table

| Key | Action in hub-town | Notes |
|---|---|---|
| **E** | Interact with NPC at 1.5-tile proximity | NPC-UI opens. LIFO close stack with Esc. |
| **Down** (or **S**) | Open stratum-picker at descent-portal | Only fires when player within 1.5 tiles of portal. Otherwise S = movement. |
| **B** | Open stash panel | Inherits `stash-ui-v1.md §1` rule — `Levels.in_hub_town == true` enables the binding. Stash panel is a focused modal; reuses M2 12×6 grid UI. |
| **Tab** | Open inventory panel | Standard inventory toggle. Coexists with B per `stash-ui-v1.md §1` two-panels-simultaneously rule. |
| **Esc** | Close most-recently-opened panel/modal | LIFO close stack. |
| **Movement (WASD / arrows)** | Player walks | Player has full agency — no scripted-movement, no cutscene. |
| **Attack (LMB / Space)** | **Suppressed in hub-town** | `Player.can_attack = false` while `Levels.in_hub_town == true`. The swing wedge does not render. Diegetic: this is a sanctuary; the player's flame doesn't burn here. |
| **Dodge (Shift / RMB)** | **Suppressed in hub-town** | Same logic — dodge has no use without combat. |

The attack/dodge suppression is **the hub-town's mechanical signature** (alongside `time_scale = 1.0` + no mobs). It signals "you cannot fight here" without needing a tutorial. The player will try to swing once, observe nothing happens, internalize "this room is different." Devon's call on whether to play a soft UI-disabled tick on suppressed-attack input (recommend: **no** — silence reinforces the sanctuary).

### First-visit hint-strip (`meta.hub_town_seen`)

Per `m3-design-seeds.md §2 Save-schema` — a save-state flag gates the first-visit tutorial cue.

- **Trigger:** player enters hub-town for the first time in this save slot AND `meta.hub_town_seen == false`.
- **Surface:** non-modal hint-strip at screen-bottom, 32 px tall, full-width. Background dark slate `#1B1A1F` at 92% opacity (matches `stash-ui-v1.md §4` chrome). Text: ember-orange `#FF6A2A`, 12 px small caps, ASCII-safe glyphs only.
- **Content:** `[E] TALK  ·  [Down] DESCEND  ·  [B] STASH  ·  [Tab] INVENTORY`
- **Duration:** fades in over 0.4 s on hub-town scene `_ready` (post-fade-in); displays for 5 s; fades out over 0.4 s. Dismisses early on any player movement input.
- **State write:** `meta.hub_town_seen = true` is set when the hint-strip fades out OR when the player presses any of the four shown keys, whichever comes first. Save-write happens at hub-town scene `_exit_tree()` (player descends or quits).
- **Re-show condition:** never. After the first visit, the hint never re-shows in that save slot. Player can rediscover via experimentation OR an in-NPC-UI affordance (Brother Voll's "Show me" line could remind them of E-to-interact).

The hint-strip is **the only tutorial Embergrave's hub-town gets**. No tooltip overlays, no NPC speech-bubbles on first approach, no "tutorial mode." The four-key strip is enough — the player's read on a single screen tells them what's available.

---

## §7 — Save-state implications

Two save-state additions for `meta` dictionary (additive only — no schema-bump beyond the v5 work already scoped for §1 multi-character):

```
data.meta:
  hub_town_seen: bool                    # default false; first-visit gate
  hub_town_last_descended_stratum: int   # default 0; remembers last stratum-picker choice for default-selection
```

`hub_town_seen` is **per-save-slot** (not per-account, not per-character). The hint-strip is keyed to character creation, not player-account. Diegetic: each new character is encountering the cloister for the first time as themselves. New character → hint re-shows. Returning character → never shows.

`hub_town_last_descended_stratum` is **per-character** (lives under `characters[N]` in v5). When player opens stratum-picker, the default selection is highlighted at the last-descended stratum. Player can change it, but the picker is fast-default for the common case of "descend the same place I just came from."

**Devon's implementation surface:**

- `Save.gd` migration v4 → v5 adds `meta.hub_town_seen = false` and `characters[N].hub_town_last_descended_stratum = 1` (S1 default) for existing characters. Migration is additive; no data loss.
- New characters (M3 new-game flow) initialize both to defaults.
- `HubTown.tscn._ready()` reads `meta.hub_town_seen` to gate the hint-strip; `_exit_tree()` writes it back.
- Stratum-picker UI reads `meta.deepest_stratum` (already in v3+) to determine available rows + `characters[N].hub_town_last_descended_stratum` to determine the default-highlighted row.

Both flags are wired through `meta`, not `Inventory` or `StratumProgression`. The hub-town's state surface is small enough that no new autoload is justified.

---

## §8 — Implementation handoff guidance for Drew

This section is Drew-facing — concrete enough that Drew's §2-T2 PR (`HubTown.tscn` authoring) can start from this doc without further design questions.

### Scenes to author

1. **`scenes/levels/HubTown.tscn`** — the hub-town scene. Root `Node2D`. Wireframe:
   - **Background:** `TileMap` with S1 cloister tileset; 30×17 cell layout (480 px ÷ 16 px cells; 270 px ÷ 16 px cells). Floor `#7A6A4F`, walls `#4A3F2E`, brazier-base tiles at NW + NE.
   - **Decoration nodes:** two `Sprite2D` brazier-flames at NW + NE (re-uses S1 brazier scene).
   - **NPC nodes:** three `Node2D` children — `Hadda`, `BrotherVoll`, `SisterEnnick`. Each instantiates `scenes/npcs/HubNPC.tscn` (a shared base scene; per-NPC the sprite + name + interact-payload differ).
   - **Prop nodes:** `Sprite2D` for anvil (under Brother Voll), vendor stall (under Hadda), bounty-board (behind Sister Ennick).
   - **Portal node:** `Node2D` named `DescentPortal` at (240, 240). Children: arch frame `Sprite2D` (bronzed trim), interior `ColorRect` (ember-glow, see §4 primitive note), interact `Area2D` (1.5-tile radius CollisionShape2D).
   - **Player spawn marker:** `Marker2D` named `PlayerSpawn` at (240, 200).
   - **AmbientLight:** vignette 20%, two brazier-key lights (NW + NE), portal sub-light (south center). Re-uses S1 R1 lighting pattern.
   - **Script:** `scripts/levels/HubTown.gd` — handles `_ready` (route to AudioDirector.play_hub_town_entry, evaluate `meta.hub_town_seen` hint-strip), `_input` (Down arrow + portal proximity → open stratum-picker), `_exit_tree` (save-write).

2. **`scenes/npcs/HubNPC.tscn`** — shared NPC base. Root `Node2D`. Children:
   - `Sprite2D` body (NPC art).
   - `AnimationPlayer` with `idle` 4f anim.
   - `Area2D` for interact-proximity (1.5-tile radius).
   - `Label` for E-prompt (initially hidden, fades in on proximity).
   - `Script` exporting `npc_name: String`, `interact_payload: Resource` (the UI scene to open).

3. **`scenes/ui/DescentPortalPicker.tscn`** — stratum-picker UI overlay. **Out of scope for this doc.** Recommended size: focused modal, vertical list of stratum rows, ember-orange selection highlight, Esc to cancel. Drew's call when §2-T2-impl lands.

4. **`scenes/ui/HubTownHintStrip.tscn`** — first-visit hint-strip. Root `Control`. Anchored to scene-bottom, full-width, 32 px tall. `Label` with the 4-key text, `AnimationPlayer` for fade in/out.

5. **Three NPC-UI surfaces** — vendor inventory, anvil reroll bench, bounty board. **Out of scope for this doc.** Each is its own M3 Tier 2 dispatch (Drew authors; Uma may direction-doc them as v1.1 amendments to this file if needed).

### Sprite authoring deliverables (M3 Tier 2 §2-T2 + sprite-swap-pipeline)

| Asset | Internal size | Anim frames | Hex codes |
|---|---|---|---|
| Hadda (vendor) | 32 × 48 | 4f idle | `#5A4738` robe, `#5C3F2A` apron, `#D7C68F` ribbon, `#A0856B` skin |
| Brother Voll (anvil-keeper) | 32 × 48 | 4f idle | `#5A4738` robe, `#3A363D` gauntlets, `#9A7A4E` chest band, `#A0856B` skin |
| Sister Ennick (bounty-poster) | 32 × 48 | 4f idle | `#5A4738` robe, `#D7C68F` cord, `#A0856B` skin, dark hair |
| Anvil prop | 32 × 32 | static + ember-glow halo | `#3A363D` body, `#D7C68F` scrolls, `#FF6A2A` halo (proximity-gated) |
| Vendor stall prop | 24 × 32 | static | `#5A4738` frame, `#D7C68F` banner |
| Bounty-board prop | 24 × 32 | static + 1 wax-seal accent | `#4A3F2E` body, `#D7C68F` parchments, `#9C9590` nails, `#FF6A2A` seal |
| Descent-portal arch | 48 × 64 | 4f interior pulse @ 6 fps | `#9A7A4E` frame, `#FF6A2A` → `#FFB066` gradient interior |

**Total new authoring:** 7 sprites, ~24 cells (3 NPCs × 4f + 4 props with mostly-static states + 1 portal × 4f). Smallest hub-town authoring budget the design defaults to.

### Cross-references for Drew

- **Visual conformance:** `team/uma-ux/visual-direction.md` + `team/uma-ux/palette.md` (Outer Cloister section). Every hex in the table above is from `palette.md`.
- **Primitive choices (HTML5 safety):** `.claude/docs/html5-export.md` § "Renderer" — ColorRect not Polygon2D, sub-1.0 tween targets, z_index positive, ASCII glyphs.
- **Audio integration:** `.claude/docs/audio-architecture.md` § "AudioDirector autoload" — add `play_hub_town_entry()` method to AudioDirector. HTML5 gesture-gate per § "HTML5 audio-playback gate."
- **NPC interact pattern:** existing `Pickup.tscn` proximity-based E-interact is the closest precedent. The `HubNPC.tscn` base reuses that Area2D + Label pattern.
- **Between-runs venue rules:** `team/uma-ux/stash-ui-v1.md` §1 — `time_scale=1.0`, no mobs, ambient music at menu-pad. Hub-town inherits verbatim.
- **Save-state hook:** Devon's v5 save-schema spike (`team/devon-dev/save-schema-v5-plan.md` — landing as M3-T1-1) will scaffold the `meta.hub_town_seen` field. Devon owns the migration; Drew reads + writes the field from `HubTown.gd`.

### What Drew does NOT design from this doc

- **Stratum-picker UI layout.** Recommended in §4; Drew's call on details.
- **Vendor inventory UI grid.** Separate M3 Tier 2 dispatch.
- **Anvil reroll bench UI panel.** Separate M3 Tier 2 dispatch.
- **Bounty board UI layout.** Separate M3 Tier 2 dispatch.
- **NPC dialogue text.** Three lines per NPC are sketched in §3 as tonal examples; full dialogue authoring is post-§2-T2 polish.
- **First-visit cutscene / pan / camera-introduction.** No cutscene — the hint-strip is the only tutorial.

---

## §9 — Asset list (consolidated)

| Category | Count | Items |
|---|---|---|
| New sprites | 7 | Hadda, Brother Voll, Sister Ennick, anvil prop, vendor stall, bounty-board, descent-portal arch |
| Anim cells | ~16 | 3 NPCs × 4f idle = 12, portal × 4f = 4 (props static) |
| Reused sprites | 7+ | S1 floor tileset, S1 wall tileset, brazier base + flame, brazier mote particles, doorway ember-glow, parchment/scroll, generic pickup-icons (vendor pile) |
| New scenes | 4 | `HubTown.tscn`, `HubNPC.tscn`, `DescentPortalPicker.tscn`, `HubTownHintStrip.tscn` (deferred — Drew's §2-T2) |
| New audio cues | 4 | `mus-hub-town`, `amb-hub-town`, `sfx-hub-anvil-tap`, `sfx-hub-portal-pulse` |
| Reused audio cues | 1 | `sfx-bell-struck` (in `amb-hub-town` chime layer) |
| Save-state additions | 2 fields | `meta.hub_town_seen`, `characters[N].hub_town_last_descended_stratum` |
| Tile-reuse hex codes | 7 | `#7A6A4F` floor, `#4A3F2E` walls, `#A89677` highlight, `#FFB066`/`#FF6A2A` brazier, `#D7C68F` parchment, `#9A7A4E` trim — all from `palette.md` Outer Cloister section |
| Total new authoring (sprites + cells) | **7 sprites / ~16 cells** | Smallest M3 Tier 1 visual surface; the hub-town is the cheapest M3 venue by design |

**Sponsor-disclosable cost framing:** hub-town is **production-cheap by intent** — the design defaults compress new authoring to a 7-sprite minimum because the tonal anchor IS the reuse (the cloister did not stay empty). If Sponsor wants a richer hub (more NPCs, animated cloister doves, surface-light-through-arches), that's an M4-polish dispatch built on top of this M3.0 floor. The 7-sprite floor is shippable; everything above is gravy.

---

## §10 — Sponsor-input items + redirect windows

Per `m3-design-seeds.md §2` defaults, this doc authors against the recommended call shape. **No Sponsor escalation needed at PR-merge time** — but the redirect window is open until §2-T2 impl dispatches.

### Defaults locked in this doc (recommend-default per `m3-design-seeds.md`)

1. **§2.4 Hub-town size:** single-screen 480×270 (recommended; locked here).
2. **§2.5 NPC count:** 3 (Hadda, Brother Voll, Sister Ennick).
3. **§2.6 Hub-town visual:** Outer Cloister evolution (reuse S1 tiles).

### New design calls made in this doc (Uma's call within her delegated authority)

1. **NPC names:** Hadda, Brother Voll, Sister Ennick. Short, monastic-tone, easy to remember. Sponsor can redirect; no design-doctrine impact.
2. **NPC positions:** vendor W, anvil center, bounty E. Western reading order. Sponsor can swap.
3. **Player spawn point:** center-south (240, 200), facing north. Standard "return from descent" entry-feel.
4. **Hub-town audio identity:** distinct from S1 BGM, major-mode tonality, piano-led, frame-drum silent. **The major-mode call is the most-opinionated tonal call in the doc** — Sponsor redirect if minor-mode preferred for consistency with stratum BGMs. Recommended: major.
5. **Suppress attack + dodge in hub-town:** mechanical signature of the sanctuary. Sponsor can override (e.g., "allow practice-swings in hub-town for tonal-feel") but recommended is suppress.
6. **First-visit hint-strip content:** four keys (E / Down / B / Tab). Sponsor can add a fifth (e.g., Esc) or trim to three. Recommended: four.

### Items deferred to v1.1 (post-Sponsor-review)

1. Major-mode vs minor-mode for `mus-hub-town` — Sponsor's call.
2. Whether the cloister braziers should have a Sister Ennick equivalent of the parchment-rustle ambient cue (i.e., should the bounty-board posters rustle every 20-30 s as part of `amb-hub-town`?) — Uma's call at audio-sourcing time.
3. Whether the descent-portal arch's gradient interior is animated as a 4f loop OR as a per-frame shader (e.g., AnimatedSprite2D vs. a custom ColorRect modulate-tween). Recommended: AnimatedSprite2D (4f, simpler, no shader-write risk for HTML5).

### Redirect window timing

- **At PR-merge time (this doc landing on main):** Sponsor reviews the direction doc; redirect window open for: NPC names, NPC positions, audio mode (major/minor), attack/dodge suppression. No Sponsor escalation routed by orchestrator — Sponsor reviews the merged doc.
- **At §2-T2 impl dispatch:** Drew consumes this doc as authored. If Sponsor wants a redirect between merge-time and §2-T2 dispatch, v1.1 amendment to this doc + DECISIONS.md entry per `team/DECISIONS.md` cadence.
- **At §2-T2 PR-merge time:** Sponsor soaks the implementation. Redirect window open for: anything visible in-engine that doesn't match the spec (e.g., "Hadda's apron is too dark" → Uma re-spec hex; "anvil doesn't read as center-of-room" → Uma re-spec position).

---

## §11 — Tester checklist for Tess (M3 acceptance)

Per `team/TESTING_BAR.md`. M3 Tier 1 acceptance rows for hub-town; locks at §2-T2 impl landing.

| ID | Check | Pass |
|---|---|---|
| HT-01 | `HubTown.tscn` loads from `Main.gd` scene-routing path (post-respawn OR new-game) | yes |
| HT-02 | Hub-town is a single-screen 480×270 internal canvas; no scrolling | yes |
| HT-03 | Three NPCs visible at spawn: Hadda (W), Brother Voll (C), Sister Ennick (E) | yes |
| HT-04 | NPC idle anim runs at 12 fps, 4 frames, ~1 s loop (eye-test) | yes |
| HT-05 | Walking within 1.5 tiles of any NPC shows ember-orange [E] glyph above head | yes |
| HT-06 | Pressing E within proximity opens the NPC's UI modal | yes |
| HT-07 | Pressing E outside proximity does nothing | yes |
| HT-08 | Descent-portal at south wall has ember-glow interior (visible, non-stale) | yes |
| HT-09 | Walking within 1.5 tiles of portal shows "[Down] Descend" prompt at player feet | yes |
| HT-10 | Pressing Down (or S) at portal opens stratum-picker UI | yes |
| HT-11 | Stratum picker shows S1 + every S up to `meta.deepest_stratum` | yes |
| HT-12 | Player attack input (LMB / Space) is suppressed in hub-town (no swing wedge renders) | yes |
| HT-13 | Player dodge input (Shift / RMB) is suppressed in hub-town | yes |
| HT-14 | `Engine.time_scale == 1.0` throughout hub-town session | yes |
| HT-15 | Vignette renders at 20% opacity (vs. 30% in S1 R1) | yes |
| HT-16 | Two braziers at NW + NE play idle flame anim + ember mote particles | yes |
| HT-17 | First-visit (`meta.hub_town_seen == false`): hint-strip displays for 5 s; sets flag to true on first key/move/timeout | yes |
| HT-18 | Subsequent visits (`meta.hub_town_seen == true`): no hint-strip displays | yes |
| HT-19 | `mus-hub-town` plays on hub-town entry (after player gesture); `amb-hub-town` layered underneath | yes |
| HT-20 | `mus-hub-town` ducks to -18 dB when NPC UI modal opens; restores on close | yes |
| HT-21 | Save → quit → relaunch from hub-town preserves `meta.hub_town_seen` + `hub_town_last_descended_stratum` | yes |
| HT-22 | HTML5 release-build artifact: descent-portal ember-glow renders visibly (HDR clamp pass) | yes |
| HT-23 | HTML5 release-build artifact: NPC E-glyphs render correctly (no tofu boxes, ASCII safe) | yes |
| HT-24 | HTML5 release-build artifact: no `USER WARNING` or `USER ERROR` lines on hub-town entry / exit | yes |
| HT-25 | Player attack-suppression: no audio cue plays on attempted swing (silent suppression) | yes |
| HT-26 | Visual conformance: every in-engine color in hub-town matches a hex from `palette.md` Outer Cloister section + the seven hex codes listed in §2 tile-reuse table | yes |
| HT-27 | Polygon2D / Area2D regression sweep: no Polygon2D used for any hub-town visual primitive (audit code review) | yes |

### Sponsor probe targets

When M3 Tier 1 reaches Sponsor's interactive soak, watch for:

- **"Wait, this is the first room?"** — diegetic recognition of the Outer Cloister reuse. **Wanted reaction.** If Sponsor doesn't recognize it, the tonal anchor isn't reading; tile-reuse may need a stronger differentiator (e.g., subtly recolor wall trim, or add a small inscription).
- **"Who are these people?"** — NPC name + role legibility. If Sponsor can't tell at-a-glance which NPC is which role, the visual descriptors aren't doing their job. Recommended fallback: add a small icon above each NPC's head (anvil glyph above Voll, coin-purse above Hadda, scroll above Ennick) — but only if at-a-glance fails.
- **"Where do I go?"** — descent-portal discoverability. If Sponsor stands in hub-town for >2 minutes without finding the portal, the south-edge affordance is too quiet. Recommended fallback: increase portal ember-glow intensity, or animate ember motes more aggressively.
- **"This music is different."** — `mus-hub-town` tonal-shift recognition. **Wanted reaction.** Confirms the major-mode + frame-drum-silent decision is reading. If Sponsor finds it jarring, redirect to minor-mode in v1.1.
- **"Why can't I swing?"** — attack-suppression discoverability. The player should TRY to swing, observe it doesn't work, internalize. If Sponsor finds it frustrating ("am I broken?"), add a tiny UI hint ("the cloister is sanctuary; your flame rests here"). Recommended: hold the line, no extra UI; the friction is the lesson.

---

## §12 — Open questions

Flagged for Sponsor / orchestrator / Priya — not all need resolving before §2-T2 implementation begins.

1. **NPC dialogue authoring** — three lines per NPC are sketched in §3 as tonal examples. Full dialogue (every line each NPC says across every visit + bounty-completion lore snippets) is a separate authoring pass. **Owner:** Uma (tone direction) + Sponsor or Priya (line writing). Defer to post-§2-T2 polish.

2. **Anvil-tap audio cue tightness** — `sfx-hub-anvil-tap` fires on Brother Voll's idle-anim frame 1 (every ~1 s). At 0.15 s duration, this is **constant subtle tapping** during a hub-town visit. May be too persistent if the hub session is long (player rerolling 5-10 affixes). **Mitigation if surfaced in soak:** cut the cue to fire every 3rd cycle (so ~3 s cadence) OR mute entirely when player is >2 tiles from anvil. **Owner:** Uma (tune at audio-sourcing time).

3. **Stratum-picker default selection** — `characters[N].hub_town_last_descended_stratum` is the default-highlighted row. Edge case: on first-ever descent, what's the default? Recommend S1 (only available row). Edge case: returning character with `meta.deepest_stratum = 5` whose last-descended was S2 — does the picker default to S2 (their last choice) or S5 (their deepest unlock)? **Recommended:** S2 (their last choice; lets them grind a specific stratum without re-selecting every run). **Owner:** Drew at impl-time; Uma if Sponsor redirects.

4. **Major vs minor tonality for `mus-hub-town`** — recommended major mode (§5). If Sponsor prefers minor for stratum-BGM consistency, redirect at PR-merge. **Owner:** Sponsor.

5. **Cloister bell-chime cadence in `amb-hub-town`** — 20-30 s randomized. May feel arrhythmic if the loops align (e.g., bell fires at hub entry, again at 22 s, player has been in hub 25 s — bell didn't fire when expected). **Mitigation if surfaced:** make cadence more deterministic (every 30 s, ± 2 s jitter) OR mix-tied-to-melodic-phrase (bell fires at end of each `mus-hub-town` loop-quarter). **Owner:** Uma at audio-sourcing time.

6. **Hub-town save-on-entry vs save-on-exit** — currently spec'd: `meta.hub_town_seen` writes at `_exit_tree()` (player descends or quits). Edge case: player enters hub-town for first time, then alt-F4 / browser-tab-close mid-visit. Did `_exit_tree` fire? In HTML5 / Godot 4.3, `_exit_tree` is NOT guaranteed on tab-close (browser doesn't grant the unload time). **Recommended mitigation:** also write `meta.hub_town_seen = true` on the hint-strip fade-out tick (a `Tween.finished` signal handler). Belt + suspenders. **Owner:** Devon at impl-time.

7. **Vendor inventory regeneration cadence** — per `m3-design-seeds.md §2`, vendor inventory regenerates per-run from `meta.deepest_stratum` + RNG. Open question: regenerate on each hub-town entry, OR on each new descend-action (so visiting Hadda multiple times within one hub session shows the same stock)? **Recommended:** per descend-action — gives the player a reason to descend → return rather than camping in hub. **Owner:** Drew at impl-time; Uma if Sponsor redirects.

8. **Cross-character hub-town visibility** — `meta.hub_town_seen` is per-save-slot. Open question: if the player has 3 characters and character A has seen the hub, should character B's first hub-town visit re-show the hint-strip? **Recommended:** yes — each character is a new identity; the hint is for the player-as-character, not the player-as-account. **Owner:** Sponsor (multi-character philosophy call) — but defaults to recommended unless redirected.

---

## Hand-off

- **Drew (M3 Tier 2 §2-T2 impl):** scenes/sprites/scripts to author per §8 + §9 + asset table. All hex codes paste-able from `palette.md`. Self-Test Report on §2-T2 PR includes HTML5 release-build screenshot demonstrating portal ember-glow visibility per HT-22.
- **Devon (M3 Tier 1 §1 save-schema v5 spike + Tier 2 §2 hub-town save hooks):** add `meta.hub_town_seen` + `characters[N].hub_town_last_descended_stratum` to v5 schema; wire `AudioDirector.play_hub_town_entry()`; route hub-town scene-routing per `m3-tier-1-plan.md` §2 spike S2 (hub-town engine architecture).
- **Tess (M3 Tier 1 §QA scaffold + Tier 2 acceptance fill-in):** HT-01 through HT-27 above. Add to `team/tess-qa/m3-acceptance-plan-tier-1.md` as §2 placeholder rows.
- **Priya (M3 Tier 1 plan absorb + Sponsor escalation routing):** no Sponsor escalation required from this doc; redirect window open at PR-merge. v1.1 amendment if Sponsor redirects anything.
- **Uma (this doc + v1.1):** absorb Sponsor feedback at PR-merge; v1.1 if redirects land. Subsequent NPC-UI direction docs (vendor UI, anvil UI, bounty UI) are separate M3 Tier 2 dispatches.

---

## Appendix — what we are NOT designing here

- **Vendor inventory UI grid** — focused modal showing items for sale + buy/sell flow. Separate M3 Tier 2 dispatch.
- **Anvil reroll bench UI panel** — focused modal showing item + current affixes + reroll cost in ember-shards. Separate M3 Tier 2 dispatch.
- **Bounty board UI** — focused modal showing active bounty + bounty offers + lore-snippet readback. Separate M3 Tier 2 dispatch.
- **Stratum-picker UI** — focused modal at descent-portal. Sketched in §4; Drew authors at §2-T2 impl-time.
- **Ember-shard currency drop logic** — mob death drops shards into inventory; per `m3-design-seeds.md §3` Devon owns the engine plumbing. Separate dispatch.
- **NPC full dialogue corpus** — three lines per NPC sketched in §3 as tonal examples; full authoring is post-§2-T2 polish.
- **Hub-town visual variants per `meta.deepest_stratum`** — e.g., does the hub-town subtly darken / accumulate motes / change brazier intensity as the player descends deeper? **Tonally interesting but explicitly out of scope for M3.0.** Logged as M4 polish concern.
- **Hub-town multi-character "alt visiting" tonal beats** — e.g., does Sister Ennick acknowledge that you've sent another character down? **Lore deepening; explicitly M4+.**
- **Hub-town's relationship to per-stratum stash chambers** — `stash-ui-v1.md §2` defines stash rooms at every stratum entry. M3 hub-town has its own stash access (B-key opens shared stash pool). The per-stratum chambers persist per `m3-design-seeds.md §2` as auxiliary venues. **Coexistence is the design; no further direction here.**

---

## Cross-references

- **`team/uma-ux/visual-direction.md`** — 480×270 canvas, palette through-line, animation feel. Hub-town conforms.
- **`team/uma-ux/palette.md`** — Outer Cloister hex codes (M1 authoritative). Every environment hex in hub-town comes from here.
- **`team/uma-ux/stash-ui-v1.md`** — between-runs venue rules (time_scale, no mobs, menu-pad audio, vignette 20%, B-key context). Hub-town inherits.
- **`team/uma-ux/audio-direction.md`** — dark-folk-chamber ensemble, bus structure, cue-list convention. Hub-town adds 4 cues.
- **`team/priya-pl/m3-design-seeds.md`** §2 — Sponsor-input items + defaults for hub-town. Locked here.
- **`team/priya-pl/m3-tier-1-plan.md`** §2 — Tier 1 sequencing. This doc is §2-T1's deliverable.
- **`.claude/docs/html5-export.md`** — HDR clamp, Polygon2D quirks, z-index, default-font glyph constraints. All shape §4 portal primitive choices + §6 hint-strip text.
- **`.claude/docs/audio-architecture.md`** — AudioDirector autoload, bus layout, HTML5 audio-playback gate. Hub-town audio integration surface.
- **`team/devon-dev/save-schema-v5-plan.md`** (in flight, M3-T1-1) — v5 schema. Hub-town's two `meta` field additions land here.
- **`team/DECISIONS.md`** — Decision draft (below) for Priya's weekly batch.

---

## Non-obvious findings

1. **The hub-town is the cheapest M3 venue by design intent, not by budget pressure.** Reusing the Outer Cloister palette + tileset is what makes the tonal anchor work ("the cloister did not stay empty"). A richer biome would dilute the diegetic claim. The 7-sprite floor is the *correct* authoring volume, not a cost-cap concession.

2. **The descent-portal's ember-glow interior is exactly the visual-primitive class that burned PR #137 (swing-flash tint).** HDR clamp + Polygon2D + WebGL2 rendering quirks all converge on this element. Drew must use ColorRect (not Polygon2D), sub-1.0 modulate targets, positive z_index. Self-Test Report on §2-T2 needs HTML5 release-build screenshot demonstrating portal visibility.

3. **Hub-town's audio identity is the first major-mode cue in Embergrave.** Every stratum BGM + boss theme has been minor-mode (per `audio-direction.md` instrumentation). The recommended major-mode `mus-hub-town` is **the harmonic payoff of the descent narrative** — coming back up from the dungeon, the hub feels major. This is an opinionated call; Sponsor redirect window is open.

4. **Attack-suppression in hub-town is the mechanical signature of the sanctuary, not a quality-of-life feature.** The player's attempt to swing + observe no-effect is the tutorial. No UI hint, no soft-error tick — silence reinforces the tonal anchor. This is intentional friction.

5. **The first-visit hint-strip is the ONLY tutorial hub-town gets.** No NPC speech-bubbles, no tooltip overlays, no "press E to interact" floating text beyond the per-NPC proximity glyph. Four keys on a single strip is enough — the player's read on a single screen tells them what's available.

6. **`meta.hub_town_seen` is per-save-slot, not per-account.** Each new character re-encounters the cloister as themselves. This is a multi-character framing call (per §1 multi-character M3 scope) — siblings each get their own first-visit. Diegetic logic: each character is a separate identity meeting the monks for the first time.

7. **The NPC reading order (W → C → E) maps to the recommended visit cadence:** vendor first (transactional), anvil center (mechanical), bounty-poster last (narrative). Western reading order is the player's natural eye-path; the room's economy guides itself.

---

## Decision draft (for Priya's weekly DECISIONS.md batch)

```
2026-05-17 — Hub-town visual direction: Outer Cloister evolution, 3 NPCs at fixed positions, descent-portal at south edge, hub-town-distinct audio identity (major-mode, frame-drum-silent). Per Uma's m3-hub-town-direction.md (M3-T1-2). Defaults to m3-design-seeds.md §2.4-2.6 recommendations; Sponsor redirect window open at PR-merge time for: NPC names, NPC positions, audio tonality (major/minor), attack-suppression. v1.1 amendment if Sponsor redirects post-merge.
```
