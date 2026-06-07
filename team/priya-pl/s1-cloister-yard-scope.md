# S1 Cloister-YARD Pivot — Workstream Scoping Proposal

**Status:** PROPOSAL ONLY — no ClickUp tickets created. Direction is still forming; Uma is drafting the visual vision (`team/uma-ux/s1-cloister-yard.md`) in parallel. Orchestrator surfaces this to Sponsor for confirmation before any ticket creation.

**Author:** Priya (PL) · **Date:** 2026-06-07 · **Branch:** `priya/s1-cloister-yard-scope`

**Source of the pivot:** Sponsor, 2026-06-07, during the `18c1406` soak of the PR #417 tile-rework. Captured in memory `[[s1-cloister-yard-open-world-direction]]` and `team/STATE.md` RESUME header (2026-06-07).

---

## 0. The pivot in one paragraph

Dissolve S1's discrete room-to-room model (the "ROOM 3/8" crammed-rooms shape) into **one open, traversable cloister YARD**: the player spawns into a world, cloister BUILDINGS sit as structures on the sides/middle of the yard, and you walk through continuously rather than teleporting room-to-room. Floor material changes from warm-sandstone flagstone to **cobblestone + moss + dirt**. Tiles go finer, wall bricks shrink to match, grass goes sparser + randomized. The foundation already exists — `CameraDirector` continuous-scroll (`.claude/docs/camera-scroll.md`) + procgen `FloorAssembler` (`.claude/docs/procgen-pipeline.md`) — so this is **composing existing systems into S1**, not building from scratch. North-stars: `[[s1-cloister-yard-open-world-direction]]` + `[[tile-scale-small-player-large-world]]` + `[[m3-diablo-shape-directive]]`.

---

## 1. PR #417 disposition — RECOMMENDATION

### Recommendation: **HARVEST + CLOSE #417. Close #407 as duplicate.**

Do NOT merge #417 as-is, and do NOT evolve it in place.

**PR #417** (`drew/86ca44p4j-s1-tile-rework`, HEAD `18c1406`, ticket `86ca44p4j`) — currently OPEN, MERGEABLE, Tess APPROVED `f0a8fc8`. It does **Room02 flagstone tile-rework + lined-hall colonnade + solid props** under the room model that the pivot is replacing.

**Why harvest-and-close, not evolve:**

1. **The spatial premise is gone.** #417 is fundamentally a *Room02-as-a-lined-interior-hall* deliverable — colonnade rows, a single bounded room, flagstone floor. The pivot replaces the bounded-room premise with an open yard. Evolving #417 means gutting its spatial structure (rooms → yard), its floor material (flagstone → cobble+moss+dirt), and its decoration density (dense grid → sparse random) — i.e. keeping the branch but replacing ~everything that makes it *that PR*. That's a re-write wearing a merge, not an evolution.
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

**My read (scope-shaping only, not a tech call):** (C) is the lowest-regret sequence — it gets Sponsor a soakable yard quickly while keeping S1 on the same integration path S2 already uses, so we don't build a throwaway. But **whether the open-yard feel is best expressed as an authored chunk vs assembler composition is Devon's engine call**, and **whether S1 should randomize per-character at all (vs stay hand-authored) is a Sponsor strategic call.** Surface both before locking the engine path.

**Recommended decision sequence:** lock the *feel* first (author the yard, Sponsor soaks the open-world read), defer the *randomization/assembler-depth* question until the feel is approved. Don't let the procgen architecture question block the Sponsor seeing the cloister yard.

---

## 3. Workstream breakdown (proposed tickets — NOT yet created)

Sized S/M/L. Sequenced by dependency. **All layout/decoration tickets depend on Uma's in-flight vision spec** `team/uma-ux/s1-cloister-yard.md` (yard layout + cobble/moss/dirt palette + decoration feel) — that spec is the design source the implementation tickets consume. Do not dispatch the Drew layout work until Uma's spec merges.

### Sequence overview

```
Uma vision spec (in flight) ──┐
                              ├─→ T1 cobble-floor regen (orch) ──┐
T0 #417 harvest+close ────────┘                                 ├─→ T4 yard layout authoring (Drew) ─→ T6 navigability gate (Drew+Tess)
                                  T2 wall-scale fix (orch) ──────┤
                                  T3 grass density/placement ────┘
                              (architectural Q §2 — Sponsor/Devon) ─→ T5 S1 retrofit engine path (Devon, IF shape B/C)
```

### Tickets

| # | Title (conventional-commit) | 1-line scope | Size | Owner | Depends on |
|---|---|---|---|---|---|
| **T0** | `chore(level): harvest PR #417 props + close #417/#407` | Cherry-pick braziers/pillars/rubble/banners assets + scale ratios onto the yard-layout branch; close #417 (superseded) + #407 (dup) with provenance notes. | **S** | Drew | — (do first) |
| **T1** | `feat(art): S1 cobble+moss+dirt floor tileset (PixelLab regen, finer scale)` | PixelLab-regen the yard floor at denser native stone count (cobblestone + moss + dirt, NOT sandstone flagstone); inset-crop + tile-verify at game zoom for "small player, large world"; finer than the 2× downsample ceiling. Orch-only (MCP). | **M** | Orch (PixelLab) | Uma palette in spec |
| **T2** | `feat(art): S1 perimeter wall tileset rescale to match finer floor` | Shrink wall-brick scale to harmonize with the finer cobble floor (current bricks read oversized); regen or rescale + re-verify tiled. Orch-only. | **S–M** | Orch (PixelLab) | T1 (match floor scale) |
| **T3** | `feat(level|ux): S1 grass + moss + dirt decoration — sparse + randomized` | Reduce grass-tuft count; replace grid-regular placement with jittered random scatter; layer moss/dirt accents per Uma feel. Decoration tunable dialed DOWN. | **M** | Drew | Uma spec + T4 (placed in the yard) |
| **T4** | `feat(level): S1 open cloister-yard layout — buildings as structures, walk-through` | Author the open traversable yard: cloister buildings as structures on sides/middle, harvested props as landmarks, camera follow + `set_world_bounds(yard_bounds)`. Engine path per §2 decision (authored chunk / assembler / hybrid). | **L** | Drew (+ Devon if shape B/C) | T0, T1, Uma spec, §2 decision |
| **T5** | `feat(level): finish S1 → FloorAssembler retrofit in Main.gd` (CONDITIONAL on §2 shape B/C) | Swap `Main` S1 path from static `ROOM_SCENE_PATHS` to the S2-style `_load_zone` → `assemble_floor` path; feed `bounding_box_px` to `_engage_camera_for_room()`. Closes the open S1 integration surface (§2 finding). | **M–L** | Devon (+ Drew) | §2 decision = B or C; T4 chunk/ZoneDef shape |
| **T6** | `test(level): S1 yard navigability gate — grunt-radius BFS` | Acceptance gate: every spawn reaches the player + all traversal lanes clear, validated with grunt-radius-EXPANDED BFS (not aisle/mob-only paths) per the #417 wedge lesson; Playwright walk-through spec; Tess sign-off. | **M** | Drew (tests) + Tess (sign-off) | T4 |

**Notes:**
- **T1/T2 are orch-only PixelLab** (sub-agents can't run the MCP per `[[sub-agent-mcp-tool-surface-scope]]`); orchestrator runs generation in the main session, Drew integrates the resulting assets. Same shape as the existing S1 tile work.
- **T5 is conditional** — only fires if Sponsor/Devon pick §2 shape (B) or (C). If shape (A) (authored chunk, no assembler), T5 drops and T4 absorbs the camera-bounds wiring (which is already live).
- **T0 first** so the props are on the working branch before T4 places them.
- **Parallelizable once Uma's spec lands:** T1 + T2 (orch PixelLab) run alongside T0 (Drew). T4 gates on T1 + T0 + the §2 decision.
- This is a **scope skeleton, not dispatch-ready tickets.** Full ACs / OOS / file-lists get authored per-ticket AFTER Sponsor confirms the direction + Uma's spec merges. Do not dispatch from this table.

---

## 4. DECISIONS.md draft entry (NOT yet appended — for the next Monday batch)

> **Decision draft (2026-06-07):** S1 (Stratum 1 "Outer Cloister") spatial model pivots from the discrete 8-room room-to-room model to **one open, traversable cloister YARD** — spawn into a world, cloister buildings as structures on the sides/middle, walk through continuously (no room-to-room teleport). Floor material changes from warm-sandstone flagstone to **cobblestone + moss + dirt**; tiles go finer; perimeter wall bricks shrink to match; grass decoration goes sparser + randomized. Composes the already-live `CameraDirector` continuous-scroll + `FloorAssembler` procgen systems into S1 rather than building anew. **Consequence:** PR #417 (Room02 flagstone tile-rework + lined-hall colonnade) is harvested (crafted props carry forward) and closed superseded; PR #407 closed duplicate. **Foundation:** Sponsor direction 2026-06-07 `18c1406` soak; memory `[[s1-cloister-yard-open-world-direction]]`; aligns S1 with `[[m3-diablo-shape-directive]]`. **Open:** the S1 engine-path (authored open chunk vs assembler-driven vs hybrid) and per-character S1 randomization are deferred to a Sponsor/Devon decision (this proposal §2) — NOT settled by this entry.

---

## 5. Risks + open questions for Sponsor

### Open questions (Sponsor decisions)

1. **#417 disposition** — confirm harvest-props-and-close (my recommendation §1) vs evolve-in-place? (Recommend: harvest + close.)
2. **S1 engine path (§2)** — should the cloister yard be (A) one authored open chunk, (B) assembler-driven, or (C) hybrid (author now, on the assembler integration path)? This pairs with: **should S1 randomize per-character at all**, or stay hand-authored? (My scope read: lock the *feel* first via authored layout; defer randomization depth. But the path is Devon's tech call + your strategic call.)
3. **Scope of the yard** — is this a full S1 replacement (all 8 rooms' worth of content reconceived as one yard + buildings), or a single yard "zone" that S1 traversal flows through with descent at the far end? Affects T4 size materially (single yard = L; full 8-room-equivalent content = L×N).
4. **Boss room** — does `Stratum1BossRoom` stay a discrete bounded encounter at the end of the yard, or does the boss also live in the open yard? (Recommend: keep the boss room discrete — bounded arenas are good for boss encounters; the yard leads INTO it. But flag for your call.)

### Risks

| ID | Risk | Severity | Mitigation |
|---|---|---|---|
| **R-YARD-1** | **Open-yard feel may not be expressible in the port-mating chunk model.** Ports were designed for room-to-room horizontal mating, not an open walk-anywhere yard. Forcing the yard into the assembler (§2 shape B) could fight the schema. | Med/High | §2 shape (A) or (C) sidesteps it — author the yard as one chunk; defer assembler-depth. Surface to Devon before locking shape B. |
| **R-YARD-2** | **Floor-scale ceiling (proven).** Clean downsample past 2× regresses to the #407 wallpaper-grid. True 3–4× finer needs a PixelLab regen at denser native stone count — not a downsample. | Med/Med | T1 is a *regen* ticket, not a downsample; bake "denser native count" into the brief. North-star check `[[tile-scale-small-player-large-world]]` before Drew integration. |
| **R-YARD-3** | **HTML5 procedural-seam / z-index risk (R-PROCGEN).** A wider scrolling yard exposes chunk-seam z-index divergence under `gl_compatibility` that the viewport-native rooms masked (`.claude/docs/camera-scroll.md` risk table). | Med/Med | HTML5 visual-verification gate is mandatory on T4/T5; author self-soak first; seam-marker regression-tells. |
| **R-YARD-4** | **Navigability regression (the #417 wedge class).** Buildings + props as solid structures in an open yard create more lane-wedge surface than a bounded room; grunts can get stuck. | Med/High | T6 grunt-radius-EXPANDED BFS gate is a hard acceptance criterion, not a nicety. Bake the #417 lesson in as a gate. |
| **R-YARD-5** | **Scope creep — "open yard" can balloon.** Reconceiving all 8 rooms' content as yard + buildings is materially larger than re-skinning Room02. | High/Med | Open Q3 forces the Sponsor to bound the yard scope BEFORE ticket creation. Default-recommend a single bounded yard zone for the first soakable slice, expand after feel-approval. |
| **R-YARD-6** | **In-flight asset gap (carried from STATE.md).** v2 prop silhouettes (`pillar_v2`, `rubble_*`, `niche`, `cracked`, `banner_v2`, `brazier_*_v2`) are raw/unprocessed; needs orch PixelLab cleanup IF Sponsor wants those over the current scaled crafted props. | Low/Med | T0 harvests the *current scaled crafted props* (known-good, BFS-verified). v2 silhouette cleanup is a separate optional ticket, not on the critical path. |

---

## 6. What happens next (process)

1. Orchestrator consolidates this proposal + Uma's vision spec → surfaces a shaping summary + the #417 recommendation + the §2/§5 open questions to Sponsor.
2. On Sponsor confirmation: Priya authors the dispatch-ready tickets (full ACs/OOS/file-lists) from this skeleton; orch starts the T1 PixelLab cobble-floor regen; Drew picks up T0 harvest.
3. The DECISIONS draft (§4) lands in the next Monday Priya batch — NOT appended now.
4. Do NOT reflexively re-dispatch the tile-tweak loop — the room model itself is being replaced (STATE.md guard).
