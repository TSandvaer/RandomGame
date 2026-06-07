# S1 Cloister-YARD Pivot — Workstream Scoping Proposal

**Status:** PROPOSAL ONLY — no ClickUp tickets created. Direction is still forming; Uma is drafting the visual vision (`team/uma-ux/s1-cloister-yard.md`) in parallel. Orchestrator surfaces this to Sponsor for confirmation before any ticket creation.

**Author:** Priya (PL) · **Date:** 2026-06-07 · **Branch:** `priya/s1-cloister-yard-scope`

**Source of the pivot:** Sponsor, 2026-06-07, during the `18c1406` soak of the PR #417 tile-rework. Captured in memory `[[s1-cloister-yard-open-world-direction]]` and `team/STATE.md` RESUME header (2026-06-07).

**North-star addition (Sponsor, 2026-06-07, same stream):** *"Remember I am ENTERING A WORLD — make the game feel BIG and ENDLESS."* The architecture should support a world that feels big and extends beyond the viewport (long traversal, off-screen continuation), **not a set of bounded rooms — and not a single bounded yard with a hard edge either.** This sharpens the §2 engine-path question and re-weights the §1 disposition + §3 ticket scope toward enabling the big/endless feel. It is woven through the sections below.

---

## 0. The pivot in one paragraph

Dissolve S1's discrete room-to-room model (the "ROOM 3/8" crammed-rooms shape) into **one open, traversable cloister YARD**: the player spawns into a world, cloister BUILDINGS sit as structures on the sides/middle of the yard, and you walk through continuously rather than teleporting room-to-room. Floor material changes from warm-sandstone flagstone to **cobblestone + moss + dirt**. Tiles go finer, wall bricks shrink to match, grass goes sparser + randomized. The foundation already exists — `CameraDirector` continuous-scroll (`.claude/docs/camera-scroll.md`) + procgen `FloorAssembler` (`.claude/docs/procgen-pipeline.md`) — so this is **composing existing systems into S1**, not building from scratch. North-stars: `[[s1-cloister-yard-open-world-direction]]` + `[[tile-scale-small-player-large-world]]` + `[[m3-diablo-shape-directive]]`.

---

## 1. PR #417 disposition — RECOMMENDATION

### Recommendation: **HARVEST + CLOSE #417. Close #407 as duplicate.**

Do NOT merge #417 as-is, and do NOT evolve it in place.

**PR #417** (`drew/86ca44p4j-s1-tile-rework`, HEAD `18c1406`, ticket `86ca44p4j`) — currently OPEN, MERGEABLE, Tess APPROVED `f0a8fc8`. It does **Room02 flagstone tile-rework + lined-hall colonnade + solid props** under the room model that the pivot is replacing.

**Why harvest-and-close, not evolve:**

1. **The spatial premise is gone — and the north-star makes it worse to keep.** #417 is fundamentally a *Room02-as-a-lined-interior-hall* deliverable — colonnade rows, a single bounded room, flagstone floor. The pivot replaces the bounded-room premise with an open yard; the "BIG and ENDLESS" north-star replaces it with an *off-screen-continuing* world. #417 is the most-bounded thing we could ship — a single hard-edged room. Evolving it means gutting its spatial structure (bounded room → endless-capable yard), its floor material (flagstone → cobble+moss+dirt), and its decoration density (dense grid → sparse random) — i.e. keeping the branch but replacing ~everything that makes it *that PR*. That's a re-write wearing a merge, not an evolution.
2. **Sponsor feel-rejected the direction, not a bug.** Sponsor feel-rejected the room/floor direction at `18c1406` ("the tiles should be much much much smaller" + the room-model pivot itself). Tess's APPROVE was on *mechanical correctness* (`f0a8fc8`); the rejection is at the design layer Tess doesn't gate. Merging an approved-but-feel-rejected PR pollutes main with a floor material + spatial model we've committed to replacing.
3. **The valuable output is the props, and props are branch-portable.** The crafted **braziers / pillars / rubble / banners** (7 scaled props from `18c1406`, collision-tuned, BFS-nav-verified) are the durable asset value. They carry forward as *structures placed in/around the yard* (cloister buildings + landmarks) regardless of floor material or spatial model. We harvest the asset files + the proportional-scale values + the grunt-radius-BFS navigability lesson, then close the PR.

**What "harvest" concretely means** (folds into the new workstream tickets, see §3):
- The prop PNGs + `.tres` already on `drew/86ca44p4j-s1-tile-rework` (braziers/pillars/rubble/banners) are cherry-picked / re-committed into the yard-layout ticket's branch.
- The proportional scale ratios (pillars 0.85 / braziers 0.65 / banners+rubble 0.70) carry as the starting calibration.
- The **grunt-radius-expanded-BFS navigability discipline** (Drew's W2-T3-era lesson: solid props protruding a lane wedge chasers; validate solid-prop levels with grunt-radius-expanded BFS, not just aisle/mob paths) becomes an acceptance gate on the yard-navigability ticket. (Already queued as a DECISIONS draft per the STATE.md QUEUED-for-orch-docs block — fold it in.)
- The FLOOR material (flagstone) and the SPATIAL structure (lined hall) are **dropped**, not harvested.

**PR #407** (`drew/86ca3yuwv-s1-decoration-impl`, ticket `86ca3yuwv`) — OPEN, already flagged HELD/superseded in STATE.md (the old rejected decoration-density pass, "#407 wallpaper-grid"). **Close as duplicate-of-superseded.** It was always going to close when the tile rework landed; the pivot just changes *which* successor supersedes it. No assets worth harvesting from #407 (its decoration approach is the grid-regular density the pivot explicitly reverses).

**Ticket hygiene on close:** `86ca44p4j` → closed (not complete — the deliverable is superseded, not shipped). Harvest note + link to the new yard-layout ticket in the close comment so the asset provenance is traceable. Same for `86ca3yuwv`.

---

## 2. S1 continuous-scroll retrofit relationship — the architectural question for Sponsor/Devon

**This section surfaces the engine-path decision. I do NOT pre-decide it — Devon owns the tech call, Sponsor signs the strategic direction.**

### What already exists (verified this session)

- **Continuous-scroll camera: LIVE.** `CameraDirector.follow_target` + `set_world_bounds` shipped (PR #314 spike) and are wired into the S1 production play loop via `Main._engage_camera_for_room()` (W2-T1, PR for `86c9y0zmg`). Today S1 rooms are 480×270 viewport-native, so the bounds-clamp holds the camera at bounds-center — *the scrolling machinery is engaged but has nothing wider-than-screen to scroll across yet.*
- **FloorAssembler: LIVE, with an S2-only production consumer.** `FloorAssembler.assemble_floor(zone_def, seed) -> AssembledFloor` shipped (PR #344) and got its first live-play-loop consumer in **S2** via `Main._load_s2_zone` (PR #391). It produces `bounding_box_px` that `_engage_camera_for_room()` is *designed* to consume.
- **S1 ZoneDef data exists:** `resources/level/zones/s1_z1_outer_cloister.tres` is authored (zone-schema spike PR #312 worked example).

### The load-bearing finding (must surface honestly to Sponsor + Devon)

**S1's live play loop was never swapped to the assembler.** Verified in `scenes/Main.gd`: S1 boots via `_load_room_at_index(0)` → static `ROOM_SCENE_PATHS` `.tscn` instantiation (the 8 discrete rooms). Only **S2** consumes `assemble_floor` in production. The W2-T3 ticket `86c9y1045` ("assemble_floor impl + S1 procgen retrofit") is marked **complete** in ClickUp — but its delivered scope was the *FloorAssembler extension + S1 ZoneDef authoring + tests*, NOT the Main.gd swap that makes S1 actually render from the assembler. The data layer is ready; **the S1 integration surface is still open.** (This is a `[[product-vs-component-completeness]]` gap — "the assembler can assemble S1" ≠ "S1 plays through the assembler.")

This is *good news for the pivot*: the cloister-yard is the natural moment to finish the S1 retrofit the data layer already supports.

### The architectural question (Sponsor + Devon decide — three shapes)

**Q: Is the cloister yard a NEW S1 layout authored as one open chunk, or procgen-assembled from the existing chunk/ZoneDef system?**

| Shape | What it is | Pro | Con |
|---|---|---|---|
| **(A) One authored open chunk** | The yard is a single hand-authored wide tilemap (buildings + props placed by hand); camera scrolls across it via existing `follow_target` + `set_world_bounds(yard_bounds)`. No assembler involved for S1. | Fastest to a Sponsor-soakable yard; full authorial control over building placement + feel; lowest risk. Uses the camera path that's already live. | Diverges from the Diablo per-character-randomized-map direction for S1; if S1 should eventually randomize, this is throwaway. |
| **(B) Assembler-driven yard (finish the W2-T3 retrofit)** | The yard is assembled from anchor chunks (buildings as set-piece anchors) + light procedural fill, via `assemble_floor`; `Main` swaps S1 to the S2-style `_load_zone` path. | Aligns S1 with the locked SI-8 (b) "partially procedural with hand-pinned set-pieces" model + `[[m3-diablo-shape-directive]]`; finishes the retrofit that's already 80% built; per-character variation comes for free. | Larger; the open-yard feel must be expressible in the chunk/port-mating model (ports were designed for room-to-room mating, not an open yard — may need schema thought); HTML5 procedural-seam risk (R-PROCGEN). |
| **(C) Hybrid** | Author the yard as ONE big anchor chunk now (Sponsor sees the feel fast), wire it through the assembler path (one anchor, zero procedural fill) so the integration surface is the S2-style `_load_zone` path. Procedural fill added later when/if S1 should randomize. | Sponsor-soakable feel fast AND on the strategic integration path; defers the open-yard-in-port-model question without throwing away the camera/assembler wiring. | Slightly more wiring than (A); the "open yard as a single anchor" still needs the port model to not fight it. |

### How the "BIG and ENDLESS" north-star re-weights the shapes

The Sponsor's "entering a world, big and endless" target **rules shape (A) out as the destination.** A single authored open chunk is, by definition, a bounded yard with a hard edge — it can read "open" but it cannot read "endless." The big/endless feel requires the world to **continue off-screen via composed chunks** — exactly what `FloorAssembler` + multi-chunk `bounding_box_px` + continuous-scroll camera were built to deliver. So:

- **(A) authored single chunk** → fine as a *throwaway feel-prototype* to get the cobble/moss/yard art in front of Sponsor fast, but NOT the shipping architecture. If we go (A), we must say out loud it's a stepping stone, not the answer.
- **(B) assembler-driven** → this is what makes "endless" structurally possible: the yard becomes a chain of mating chunks (cloister buildings + courtyards as anchors, traversal corridors + procedural fill between them), the camera scrolls across a `bounding_box_px` much wider than the viewport, and per-character seeding gives the "this world goes on" variation. This is the path the north-star points at.
- **(C) hybrid** → author the first yard slice as an anchor chunk for fast feel-soak, but wire it through the assembler `_load_zone` path from day one so the "extend with more chunks" capability is live, not retrofitted later. Best sequencing of *fast feel* + *endless-capable architecture*.

**My read (scope-shaping only, not a tech call):** the north-star pushes the recommendation from "lowest-regret = C" to "**C is the path, and B is the destination.**" Author the first yard slice fast (so Sponsor soaks the cobble-yard feel), but build it ON the assembler/continuous-scroll path so "big and endless" is an architectural property from the start — not a thing we'd have to re-architect toward after shipping a bounded yard. Shape (A) as a *permanent* answer is now off the table; shape (A) as a feel-prototype is acceptable only if explicitly labeled disposable.

**Still genuinely open (Sponsor/Devon, not pre-decided here):**
- Whether the open-yard / walk-anywhere feel is cleanly expressible in the current port-mating chunk model, or whether the schema needs thought for non-corridor (open-courtyard) mating — **Devon's engine call** (R-YARD-1).
- How far "endless" goes — finite-but-large authored+procedural S1, vs truly-unbounded streaming. The latter is a much bigger systems lift; the former likely satisfies the *feel* without unbounded-streaming complexity. **Sponsor strategic call** (Open Q5).

**Recommended decision sequence:** lock the *feel* first (author the first yard slice on the assembler path, Sponsor soaks the big-open-world read), then expand chunk-by-chunk toward "endless" once the feel is approved. Don't let the unbounded-streaming question block Sponsor seeing the cloister yard — but don't ship a hard-edged bounded yard as the answer either.

---

## 3. Workstream breakdown (proposed tickets — NOT yet created)

Sized S/M/L. Sequenced by dependency. **All layout/decoration tickets depend on Uma's in-flight vision spec** `team/uma-ux/s1-cloister-yard.md` (yard layout + cobble/moss/dirt palette + decoration feel) — that spec is the design source the implementation tickets consume. Do not dispatch the Drew layout work until Uma's spec merges.

### Sequence overview

```
Uma vision spec (in flight) ──┐
                              ├─→ T1 cobble-floor regen (orch) ──┐
T0 #417 harvest+close ────────┘                                 ├─→ T4 yard first slice (Drew+Devon) ─→ T6 navigability gate
                                  T2 wall-scale fix (orch) ──────┤        │                                  │
                                  T3 grass density/placement ────┘        ▼                                  ▼
                              (architectural Q §2 — Sponsor/Devon) ─→ T5 Main.gd assembler retrofit ─→ T7 chunk-extension (endless)
                                                                       (keystone: world scrolls past viewport)
```

### Tickets

| # | Title (conventional-commit) | 1-line scope | Size | Owner | Depends on |
|---|---|---|---|---|---|
| **T0** | `chore(level): harvest PR #417 props + close #417/#407` | Cherry-pick braziers/pillars/rubble/banners assets + scale ratios onto the yard-layout branch; close #417 (superseded) + #407 (dup) with provenance notes. | **S** | Drew | — (do first) |
| **T1** | `feat(art): S1 cobble+moss+dirt floor tileset (PixelLab regen, finer scale)` | PixelLab-regen the yard floor at denser native stone count (cobblestone + moss + dirt, NOT sandstone flagstone); inset-crop + tile-verify at game zoom for "small player, large world"; finer than the 2× downsample ceiling. Orch-only (MCP). | **M** | Orch (PixelLab) | Uma palette in spec |
| **T2** | `feat(art): S1 perimeter wall tileset rescale to match finer floor` | Shrink wall-brick scale to harmonize with the finer cobble floor (current bricks read oversized); regen or rescale + re-verify tiled. Orch-only. | **S–M** | Orch (PixelLab) | T1 (match floor scale) |
| **T3** | `feat(level|ux): S1 grass + moss + dirt decoration — sparse + randomized` | Reduce grass-tuft count; replace grid-regular placement with jittered random scatter; layer moss/dirt accents per Uma feel. Decoration tunable dialed DOWN. | **M** | Drew | Uma spec + T4 (placed in the yard) |
| **T4** | `feat(level): S1 open cloister-yard first slice — buildings as structures, walk-through` | Author the first traversable yard slice as an assembler **anchor chunk**: cloister buildings as structures on sides/middle, harvested props as landmarks, camera follow + `set_world_bounds(yard_bounds)`. Built ON the assembler path (shape C) so it extends chunk-by-chunk toward "endless." | **L** | Drew (+ Devon) | T0, T1, Uma spec, §2 decision |
| **T5** | `feat(level): S1 → FloorAssembler retrofit in Main.gd (endless-capable traversal)` | Swap `Main` S1 path from static `ROOM_SCENE_PATHS` to the S2-style `_load_zone` → `assemble_floor` path; feed multi-chunk `bounding_box_px` to `_engage_camera_for_room()` so the world scrolls beyond the viewport. Closes the open S1 integration surface (§2 finding) — the keystone of the big/endless feel. | **M–L** | Devon (+ Drew) | §2 decision = B/C; T4 chunk/ZoneDef shape |
| **T6** | `test(level): S1 yard navigability gate — grunt-radius BFS` | Acceptance gate: every spawn reaches the player + all traversal lanes clear, validated with grunt-radius-EXPANDED BFS (not aisle/mob-only paths) per the #417 wedge lesson; Playwright walk-through spec; Tess sign-off. | **M** | Drew (tests) + Tess (sign-off) | T4 |
| **T7** | `feat(level): S1 yard chunk-extension pass — chain courtyards toward "endless"` | Author 2–3 additional mating yard chunks (further courtyards / cloister wings / traversal corridors) chained off T4's first slice via port-mating, so traversal reads long + off-screen-continuing. Sized per Sponsor's "how far is endless" answer (Open Q5). | **L** | Drew (+ Devon) | T4, T5, Open Q5 bound |

**Notes:**
- **T1/T2 are orch-only PixelLab** (sub-agents can't run the MCP per `[[sub-agent-mcp-tool-surface-scope]]`); orchestrator runs generation in the main session, Drew integrates the resulting assets. Same shape as the existing S1 tile work.
- **T5 is the keystone of "big and endless"** — it swaps S1 onto the assembler/multi-chunk-bounds path so the world can scroll beyond the viewport and extend chunk-by-chunk. It only drops if Sponsor explicitly picks §2 shape (A) as a *permanent* answer — which the north-star argues against. Under the recommended shape (C), T5 fires.
- **T7 is what makes the world actually feel endless** — T4 is one yard slice (feel-prototype-grade open); T7 chains more chunks so traversal is long. Its size scales with Open Q5 (how far "endless" goes). Don't author T7 until the T4 feel is Sponsor-approved.
- **T0 first** so the props are on the working branch before T4 places them.
- **Parallelizable once Uma's spec lands:** T1 + T2 (orch PixelLab) run alongside T0 (Drew). T4 gates on T1 + T0 + the §2 decision.
- This is a **scope skeleton, not dispatch-ready tickets.** Full ACs / OOS / file-lists get authored per-ticket AFTER Sponsor confirms the direction + Uma's spec merges. Do not dispatch from this table.

---

## 3.5 The living-world / journey arc — S1 cloister-yard as the FIRST step

**Sponsor vision deepening (2026-06-07, same stream):** *"I want to feel like I am entering a world that's already ALIVE — NPCs, buildings, animals, vegetation, enemies, treasures, landscapes, distances. A JOURNEY through a MYSTICAL, WONDROUS world."*

This is bigger than S1's spatial model — it's the **direction for the whole game's feel**. The S1 cloister-yard workstream (§3) is the **first concrete step** of this living-world/journey arc: it proves the "entering a big open living world" read at one stratum. The immediate S1 tickets stay focused (§3); the broader arc below is **context + future scope for the Sponsor to sequence**, NOT tickets to create now.

### Content-pillar inventory — what already has systems vs what's new

| Pillar | Status | System / where it lives | S1-yard relevance |
|---|---|---|---|
| **NPCs + dialogue** | ✅ **System exists** | DialogueController + DialogueTreeDef schema (`.claude/docs/dialogue-system.md`); per-stratum NPCs planned (1 in S1) per `[[m3-diablo-shape-directive]]` SI-5 | Place the S1 NPC(s) as living structures in the yard (e.g. a wounded scholar near the descent). In-scope to *place*; content authored via existing system. |
| **Enemies + combat** | ✅ **System exists** | Full combat runtime (`.claude/docs/combat-architecture.md`); Grunt/Charger/Shooter rigged with PixelLab art | Yard mob spawns via existing spawn system; navigability gate (T6) covers it. In-scope. |
| **Quests + exploration** | ✅ **System exists** | QuestActionRouter + QuestDef/QuestState (`.claude/docs/quest-system.md`); 3-5 exploration quests planned in M3 Tier 3 | Quest objectives as hand-pinned anchors in the yard (legibility per SI-8 (b), R-YARD-7). System ready; content authored separately. |
| **Buildings** | 🟡 **Partial** (props exist, "structures" framing new) | Crafted props (#417 braziers/pillars/rubble/banners) + the spatial-structure framing from this pivot | Core of the §3 yard work (T4) — buildings AS walk-around structures. In-scope. |
| **Vegetation** | 🟡 **Partial** (grass exists, layered ecology new) | Current grass-tuft scatter (being dialed sparse + random, T3); moss + dirt floor accents (T1) | Basic vegetation in-scope (T1/T3). *Layered/varied ecology* (trees, bushes, varied groundcover) is new — future. |
| **Ambient animals** | 🔴 **NEW pillar** | No system today | Birds, critters, ambient fauna that make the world feel alive. New art + a lightweight ambient-actor system. **Future scope** — flag, don't ticket now. |
| **Treasures** | 🔴 **NEW-ish** | Pickup/Inventory system exists, but "world treasures to discover" (chests, hidden caches, reward-for-exploration) is a new content+placement layer | Pickup mechanics exist; *discoverable world treasure* as an exploration-reward layer is new design. **Future scope.** |
| **Landscapes / vistas / distance** | 🔴 **NEW pillar** | No parallax/backdrop/distance system today; the world is a flat top-down floor | "Distances" + "landscapes" imply depth cues — parallax backdrops, far-vista layers, sense of a world extending to a horizon. Materially new rendering work. **Future scope — the biggest new pillar.** |
| **"Mystical / wondrous" feel** | 🟡 **Cross-cutting** | Audio (`.claude/docs/audio-architecture.md`) + lighting/particle affordances exist; "wondrous" is an art+audio+lighting direction | Uma's vision spec owns the S1 mystical-wondrous read (palette, lighting, ambient audio). In-scope as *direction*; deeper VFX/lighting systems future. |

### How to sequence (recommendation — Sponsor confirms)

- **Now (this workstream, §3):** S1 cloister-yard using the pillars that already have systems (buildings/structures, existing NPCs/combat/quests placed in the yard, basic sparse vegetation). This is the *first step* — prove the "big, open, alive-with-existing-content world" read at S1.
- **Next (flag, don't ticket):** the three new pillars — **ambient animals**, **discoverable world treasures**, **landscapes/vistas/distance (parallax depth)**. Each is its own systems+content lift. Recommend the Sponsor sequences these as their own mini-tracks AFTER the S1 yard feel is approved, in roughly that order of leverage-per-effort (animals cheapest, distance/parallax biggest).
- **Cross-cutting:** "mystical/wondrous" is a continuous art+audio+lighting direction Uma carries through every step, not a discrete ticket.

**The framing for the Sponsor:** the S1 cloister-yard is step one of a living-world journey, deliberately built on the systems we already have so we ship a *believably-alive* S1 fast — then layer the new pillars (animals → treasures → vistas) onto the proven foundation. Don't try to build all pillars into the first yard; build the yard so the new pillars have somewhere to live.

---

## 4. DECISIONS.md draft entry (NOT yet appended — for the next Monday batch)

> **Decision draft (2026-06-07):** S1 (Stratum 1 "Outer Cloister") spatial model pivots from the discrete 8-room room-to-room model to **one open, traversable cloister YARD that feels BIG and ENDLESS** — spawn into a world (not a room, not a bounded yard with a hard edge), cloister buildings as structures on the sides/middle, walk through continuously with the world continuing off-screen. Floor material changes from warm-sandstone flagstone to **cobblestone + moss + dirt**; tiles go finer; perimeter wall bricks shrink to match; grass decoration goes sparser + randomized. Composes the already-live `CameraDirector` continuous-scroll + `FloorAssembler` multi-chunk procgen systems into S1 so the world extends beyond the viewport, rather than building anew. **The S1 live play loop is retrofitted off static `ROOM_SCENE_PATHS` onto the S2-style `assemble_floor` path** — this is the open integration surface the W2-T3 data layer never wired into Main.gd (§2 finding). **Consequence:** PR #417 (Room02 flagstone tile-rework + lined-hall colonnade) is harvested (crafted props carry forward) and closed superseded; PR #407 closed duplicate. **Foundation:** Sponsor direction 2026-06-07 `18c1406` soak + "entering a world, big and endless" north-star; memory `[[s1-cloister-yard-open-world-direction]]`; aligns S1 with `[[m3-diablo-shape-directive]]`. **Open (deferred to Sponsor/Devon, NOT settled here):** how far "endless" goes (finite-large-that-reads-endless vs truly-unbounded streaming) and per-character S1 randomization depth (proposal §2 + Open Q5).

---

## 5. Risks + open questions for Sponsor

### Open questions (Sponsor decisions)

1. **#417 disposition** — confirm harvest-props-and-close (my recommendation §1) vs evolve-in-place? (Recommend: harvest + close.)
2. **S1 engine path (§2)** — given the "BIG and ENDLESS" north-star, do you confirm shape **(C) → (B)**: author the first yard slice fast for feel-soak but build it ON the assembler/continuous-scroll path so the world is endless-capable from the start? (Shape (A) as a *permanent* bounded yard is now off the table per the north-star; acceptable only as a labeled disposable feel-prototype.) This pairs with: **should S1 randomize per-character**, or be a fixed-but-large authored+procedural world? (My scope read: C is the path, B is the destination; randomization depth deferrable.)
3. **Scope of the yard** — is this a full S1 replacement (all 8 rooms' worth of content reconceived as yard + buildings), or a first yard "zone" that traversal flows through with descent at the far end? Affects T4 size (first slice = L) and T7 size (chunk-extension toward endless = L scaling with Q5). (Recommend: ship a first soakable slice, then extend.)
4. **Boss room** — does `Stratum1BossRoom` stay a discrete bounded encounter at the end of the yard, or does the boss also live in the open yard? (Recommend: keep the boss room discrete — bounded arenas are good for boss encounters; the endless yard leads INTO it. The "endless" feel is for traversal, not the boss fight. But flag for your call.)
5. **How far is "endless"?** — does S1 want (i) a *finite-but-large* authored+procedural world that *reads* endless (long traversal, off-screen continuation, no visible hard edge) — the cheaper lift that likely satisfies the feel; or (ii) *truly-unbounded* streaming/infinite generation — a much larger systems lift? This bounds T7 size and the assembler-depth in T5. (Recommend (i): "feels endless" via finite-large + off-screen continuation; reserve true-infinite for a later milestone if the feel demands it.)
6. **Living-world pillar sequencing (§3.5)** — confirm the S1 cloister-yard ships FIRST on existing-system pillars (buildings/NPCs/combat/quests/basic vegetation), and the three NEW pillars — **ambient animals**, **discoverable treasures**, **landscapes/vistas/distance (parallax depth)** — are sequenced as their own later mini-tracks (recommended order: animals → treasures → vistas)? Or do you want any of the new pillars pulled into the first S1 slice? (Recommend: keep the first slice focused; layer new pillars onto the proven yard.)

### Risks

| ID | Risk | Severity | Mitigation |
|---|---|---|---|
| **R-YARD-1** | **Open-yard feel may not be expressible in the port-mating chunk model.** Ports were designed for room-to-room horizontal mating, not an open walk-anywhere yard. Forcing the yard into the assembler (§2 shape B) could fight the schema. | Med/High | §2 shape (A) or (C) sidesteps it — author the yard as one chunk; defer assembler-depth. Surface to Devon before locking shape B. |
| **R-YARD-2** | **Floor-scale ceiling (proven).** Clean downsample past 2× regresses to the #407 wallpaper-grid. True 3–4× finer needs a PixelLab regen at denser native stone count — not a downsample. | Med/Med | T1 is a *regen* ticket, not a downsample; bake "denser native count" into the brief. North-star check `[[tile-scale-small-player-large-world]]` before Drew integration. |
| **R-YARD-3** | **HTML5 procedural-seam / z-index risk (R-PROCGEN).** A wider scrolling yard exposes chunk-seam z-index divergence under `gl_compatibility` that the viewport-native rooms masked (`.claude/docs/camera-scroll.md` risk table). | Med/Med | HTML5 visual-verification gate is mandatory on T4/T5; author self-soak first; seam-marker regression-tells. |
| **R-YARD-4** | **Navigability regression (the #417 wedge class).** Buildings + props as solid structures in an open yard create more lane-wedge surface than a bounded room; grunts can get stuck. | Med/High | T6 grunt-radius-EXPANDED BFS gate is a hard acceptance criterion, not a nicety. Bake the #417 lesson in as a gate. |
| **R-YARD-5** | **Scope creep — "open yard" can balloon, and "endless" balloons it further.** Reconceiving all 8 rooms as yard + buildings is materially larger than re-skinning Room02; "big and endless" tempts toward truly-unbounded streaming (a milestone-sized systems lift). | High/High | Open Q3 + Q5 force the Sponsor to bound BOTH the yard scope AND the "how far is endless" target BEFORE ticket creation. Default-recommend: first soakable slice (T4) → extend chunk-by-chunk (T7) → "feels endless" via finite-large + off-screen continuation, NOT true-infinite. Reserve unbounded streaming for a later milestone. |
| **R-YARD-7** | **"Endless feel" vs the descent/quest structure.** S1 has a descent to S2 + (per `[[m3-diablo-shape-directive]]`) quest objectives that must be reachable/legible. An endless-feeling open world can make the descent + quest targets hard to find / structurally weird (the SI-8 (b) legibility concern, amplified). | Med/Med | Hand-pin the descent + quest set-pieces as anchors (SI-8 (b) model already does this); "endless" applies to traversal/exploration fill, not to the critical-path landmarks. Surface to Uma for wayfinding in the vision spec. |
| **R-YARD-6** | **In-flight asset gap (carried from STATE.md).** v2 prop silhouettes (`pillar_v2`, `rubble_*`, `niche`, `cracked`, `banner_v2`, `brazier_*_v2`) are raw/unprocessed; needs orch PixelLab cleanup IF Sponsor wants those over the current scaled crafted props. | Low/Med | T0 harvests the *current scaled crafted props* (known-good, BFS-verified). v2 silhouette cleanup is a separate optional ticket, not on the critical path. |

---

## 6. What happens next (process)

1. Orchestrator consolidates this proposal + Uma's vision spec → surfaces a shaping summary + the #417 recommendation + the §2/§5 open questions to Sponsor.
2. On Sponsor confirmation: Priya authors the dispatch-ready tickets (full ACs/OOS/file-lists) from this skeleton; orch starts the T1 PixelLab cobble-floor regen; Drew picks up T0 harvest.
3. The DECISIONS draft (§4) lands in the next Monday Priya batch — NOT appended now.
4. Do NOT reflexively re-dispatch the tile-tweak loop — the room model itself is being replaced (STATE.md guard).
