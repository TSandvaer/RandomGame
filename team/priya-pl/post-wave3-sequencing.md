# Post-Wave-3 Sequencing — From Now to Ship

**Owner:** Priya · **Authored:** 2026-05-22 · **Amended:** 2026-05-22 (v1.1), 2026-05-22 (v1.2 — W2 ticket family filed), 2026-05-23 (v1.3 — post-W1 audit + W2 ticket-shape verdict) · **Status:** v1.3 — W1 closed for 4 system-shape spikes; procgen spike (`86c9xub9p`) in flight; SI-8 still gating on procgen-spike PR-merge. W2 ticket family verdict = 5 keep-as-is / 2 amend (paper-shaped already in v1.2 §5.1) / 0 new.

## v1.1 amendment — 2026-05-22 — randomized-maps directive + §6 SI-1..5 Sponsor sign-off

This amendment folds Sponsor's two same-day signals into the v1.0 sequencing plan:
- **§6 SI-1 through SI-5 signed by Sponsor** (locks the Diablo-shape vertical-slice scope: continuous-scroll camera, full state-branching dialogue, Diablo-II per-act map, 2 new S2 mob archetypes, 3 M3 Tier 3 stratum NPCs)
- **New §1 Commitment 5** — randomized maps per character via per-character `world_seed` + procedural chunk-fill between fixed anchors (zone entries/exits, NPCs, boss rooms, quest-target rooms, hub-town)

**Substantive sections that change:** §1 (add Commitment 5), §2 (procgen spike scope inside vertical slice), §3 (calendar — Tier 3 widens 6-8 → 7-10 weeks honest middle), §4 (procgen-spike + assemble_floor-impl + per-character-seed-binding tickets added to W1/W2), §6 (close SI-1 through SI-5 as signed; mark SI-6 + SI-7 still deferrable; add new SI-8 on procgen scope), §7 (add R-PROCGEN; demote R-SCOPE), §8 (add `level-chunks.md` ports § + `save-schema-v5-plan.md`).

**SI-8 — new Sponsor-input item, surfaced by Commitment 5.** Procgen scope: (a) fully procedural chunk-fill between anchors / (b) partially procedural with hand-pinned set-pieces inside zones / (c) hybrid by stratum (S1-S2 hand-pinned, S3-S8 procedural). **Recommended:** (b) partially procedural with hand-pinned set-pieces inside zones. Reasoning: S1+S2 vertical slice already requires hand-authored zones for the quest-target rooms and NPC placements per Commitment 3 + SI-5; pure procedural inside zones risks the quest objective being placed in a structurally-weird position that the player can't read. Set-piece pinning preserves authorial control over critical rooms while letting the rest of the zone fill procedurally. (a) is cheapest but risks legibility; (c) is the slip-floor if the procgen spike surfaces HTML5-seam regressions that gate S2 fill. **Lockable by:** end of M3 Tier 3 W1 (post-spike).

Pre-existing v1.0 content below is preserved as the historical record; this amendment supersedes by section. The §3 calendar shift is the most-load-bearing v1.1 delta — Tier 3 widens from 6-8 weeks to 7-10 weeks honest middle to absorb the procgen spike + `assemble_floor` runtime impl + the procedural-seam HTML5 visual-verification.

### v1.1 — §1 — NEW Commitment 5 — Randomized maps per character (procedural-arrangement + per-character seed)

> *"i also want randomized maps per level, meaning tile sprites are put together randomly for each new player"* — Sponsor verbatim, 2026-05-22, post-PR-#303-merge.

**The lock:** Diablo-II "procedurally arranged per character" pattern. Each character has a `world_seed: int` (rolled on character creation, persisted in v5 save schema per `save-schema-v5-plan.md`). The map layout the player sees is **deterministic for that character** — re-rolling the same character always yields the same maps; rolling a new character yields a different layout. Different characters in the same save slot may share strata + zones + NPC placement, but the **chunk arrangement WITHIN zones differs per character**.

**Hand-authored vs procedural split:**

- **Hand-authored (deterministic per stratum + per zone, identical for all characters):**
  - Zone entries + exits (the ports connecting zones — per `level-chunks.md` § "Why ports, not free-form transitions" — the schema is already pre-shaped for this)
  - NPC placement rooms (per stratum NPC roster per SI-5: 1 NPC in S1, 2 NPCs in S2)
  - Boss rooms (`Stratum1BossRoom`, `Stratum2BossRoom`)
  - Quest-target rooms (the rooms where exploration-quest objectives resolve — per Commitment 3)
  - Story-beat rooms (any zone room flagged as narrative-critical by Drew + Uma)
  - Hub-town (single-screen 480×270 by design; not procedural per Commitment 4)
- **Procedural (per-character, seeded by `world_seed`):**
  - Tile-chunk arrangement WITHIN zone bounds, between the hand-authored anchors
  - Mob spawn point selection within procedural chunks (which spawn-points of the chunk's authored set fire for this character)
  - Loot pickup placement within procedural chunks (the existing pickup-drop pool, just spawned in different chunks per character)

**Determinism:** seeded by per-character `world_seed`; same character on the same stratum always sees the same maps. Per-stratum derived seeds: `stratum_seed = hash(world_seed, stratum_id)` — keeps re-rolling at S1 from leaking S2's layout into S1. Per-zone seeds derived the same way (`zone_seed = hash(stratum_seed, zone_id)`) so re-entering a zone within a run produces the same layout.

**Save-schema implication:** additive on top of v5's per-character keys. `data.characters[N].world_seed: int` (rolled at character creation; immutable thereafter). See `save-schema-v5-plan.md` for the v5 structure; this addition is purely additive on a per-character key, doesn't touch v5's non-additive multi-character lift.

**Reference architecture:** the schema is **already pre-shaped** for this in `level-chunks.md` § "Why ports, not free-form transitions" + § "Out of scope for M1" (which explicitly lists `assemble_floor` as M2/M3 work). The chunk schema's `ports + assemble_floor` was designed exactly for multi-chunk procedural assembly. M3 Tier 3 W1 spike implements `assemble_floor(chunks: Array[LevelChunkDef], zone_def: ZoneDef, seed: int)`.

**Cost:** M-L. The procgen system is non-trivial (per-character seed binding, zone-bound chunk selection, port-mating discipline, save-write on character creation), but `level-chunks.md` § "Why chunks" + § "Why ports" pre-shape it heavily. **Honest middle:** ~2 calendar weeks of Devon+Drew parallel work for the spike + impl + S1 retrofit; another ~1 week for HTML5 procedural-seam visual-verification. See R-PROCGEN below.

**Landing point:** M3 Tier 3 W1 spike (`procgen_spike`) → W2 `assemble_floor` impl + S1 retrofit → W3 S2 procedural fill at zone authoring time. **The procgen spike must prove three things before W2 dispatches:**
1. Per-character seed binding round-trip (create character → save → load → same map renders)
2. Hand-authored anchors compose with procedural fill correctly (zone entry/exit ports mate; quest-target room is reachable; NPC room is reachable)
3. Chunk-port mating at procedural seams renders cleanly under continuous-scroll camera (HTML5 z-index sharp edge per `html5-export.md` § "Z-index sensitivity" + the burst-contrast finding)

### v1.1 — §2 — Vertical-slice scope clarification — procgen spike added

The M3 Tier 3 vertical slice (S1+S2 polished) now includes a procgen spike as Track 1.5 (between Camera-scroll Track 1 and Dialogue-system Track 2 in dispatch order — procgen spike is the foundation Track 1's camera-scroll consumes once chunks compose into wider-than-screen tilemaps).

**The spike must prove:**

1. **Per-character seed binding.** Character creation rolls `world_seed`; save round-trips it; load reads it; assembler consumes it; same character → same map across loads. Paired GUT test pins the round-trip.
2. **Hand-authored anchors compose with procedural fill correctly.** Zone schema (per Commitment 3 ZoneDef) defines anchor rooms by id (`entry`, `npc_room`, `boss_room`, `quest_target`, `exit`) + procedural slots between them. The assembler places anchors first (deterministic position), then fills slots with seed-selected chunks. Port-mating discipline (per `level-chunks.md` § "Why ports") ensures no broken seams.
3. **Chunk-port mating at procedural seams renders cleanly under continuous-scroll camera under HTML5 `gl_compatibility`.** This is the HTML5 sharp edge — the procedural seam between two chunks may produce tilemap z-index ordering issues or visible mating gaps that don't reproduce on desktop. Visual-verification gate per `html5-export.md` § "HTML5 visual-verification gate" is mandatory; Sponsor-soak with concrete probe targets per the per-surface escape clause.

**If the spike surfaces an unworkable HTML5 procedural-seam regression**, the fallback shape is SI-8 option (c) — hybrid: S1+S2 ship with hand-pinned chunks inside zones (no procedural fill, but per-character seed still drives anchor selection from a hand-authored pool); M5 strata revisit procedural fill once the seam regression is debugged. This preserves the per-character map experience (different characters see different maps via the seeded anchor selection) without the procedural-seam HTML5 risk.

### v1.1 — §3 — Milestone calendar updated — Tier 3 widens 6-8 → 7-10 weeks

The procgen spike + `assemble_floor` impl + per-character-seed save lift + HTML5 procedural-seam visual-verification adds **~1-2 calendar weeks** to M3 Tier 3. Honest middle: **7-10 weeks parallel-dispatched** (was 6-8).

**Updated W1-W5 calendar (replaces v1.0 §3 M3 Tier 3 calendar):**

- **Week 1** — Sponsor signs SI-8 (procgen scope). Track 1 spike (camera-scroll). Track 1.5 spike (procgen `assemble_floor` + per-character seed). Track 2 spike (dialogue schema). Sub-track 5a Sponsor PixelLab batch wave 1 (Player + Grunt + Charger + Shooter).
- **Weeks 2-3** — Track 1 implementation + S1 light retrofit. Track 1.5 `assemble_floor` impl + per-character seed save-write + S1 procedural retrofit (replace static chunk arrangement with assembler-driven). Track 2 implementation + first 3 dialogue trees. Track 3 zone-schema extension + 2-3 exploration quests authored. Sub-track 5a continues.
- **Weeks 4-5** — Track 4 world-map UI minimal. Sub-track 5b hub-town impl. Sub-track 5d S1 + S2 NPC sprites + dialogue trees. Sub-track 5c S2 content authoring (zones + new mobs) **with procedural chunk-fill inside zones via the W2 assembler**.
- **Weeks 6-7** — S2 boss room polish; Sub-track 5d completes; HTML5 procedural-seam visual-verification round (Tess + Sponsor-soak with probe targets per `html5-export.md`); Tess M3 Tier 3 acceptance plan + per-track QA omnibus.
- **Weeks 8-9** — Sponsor M3 Tier 3 soak; fix-forward absorbed. Procgen HTML5-seam fix-forward if Sponsor surfaces regression.
- **Week 10** — slip buffer (was implicit in v1.0; made explicit in v1.1 for the procgen-HTML5-seam risk class).

**Total calendar from now to ship:** ~11-15 months honest middle (was 10-14). Sponsor should plan against the 15-month shape; team ships as fast as quality holds. The hex-block fallback per v1.0 §1 stays as the slip safety net AND SI-8 option (c) is the procgen slip safety net.

### v1.1 — §4 — Ticket pre-shape updated — procgen tickets added to W1/W2

Three new tickets added to M3 Tier 3 ticket pre-shape (insert into v1.0 §4 M3 Tier 3 table at indicated waves):

| Wave | Tickets | Ownership | Count | Notes |
|---|---|---|---|---|
| **W1** | **Procgen spike: `assemble_floor` + per-character `world_seed` binding (NEW)** | **Devon + Drew** | **2 (spike + paired test)** | **Gated on §6 SI-8. Proves per-character seed round-trip + anchor-procgen composition before W2 impl.** |
| **W2** | **`assemble_floor(chunks, zone_def, seed)` impl + S1 procedural retrofit (NEW)** | **Drew + Devon** | **2-3** | **Depends on W1 procgen spike + W1 zone schema spike. S1's existing 8 rooms transition to anchor-driven assembly.** |
| **W2** | **Per-character `world_seed` save-write + v5 schema additive field (NEW)** | **Devon** | **1** | **Additive on top of v5 per-character keys; not a v5-non-additive lift. Save round-trip GUT test pinned.** |
| **W6-W7** | **HTML5 procedural-seam visual-verification + Sponsor-soak probe round (NEW)** | **Tess + Sponsor** | **1 QA + 1 soak** | **Visual-verification per `html5-export.md` per-surface escape clause; concrete probe targets on chunk seams + scroll transitions.** |

**Updated M3 Tier 3 ticket total:** ~50 across 5 waves (was ~45 across 4 waves). Procgen spike + impl + seed save-write + HTML5 seam QA = +5 tickets net.

### v1.1 — §6 — Sponsor-input items, post-2026-05-22 sign-off

**Closed this session (Sponsor signed 2026-05-22):**

- ✅ **SI-1 — Camera-scroll shape:** Sponsor confirmed (a) continuous-scroll. (b) Zelda-edge-pan and (c) Tunic-fixed-camera dropped.
- ✅ **SI-2 — Dialogue system scope:** Sponsor confirmed full state-branching (pre-quest / active / completed / failed branches).
- ✅ **SI-3 — World-map UI shape:** Sponsor picked (a) Diablo-II per-act map (the genuine fork from (b) Diablo-IV persistent overworld and (c) Crystal-Project room-tree).
- ✅ **SI-4 — S2 mob archetypes:** Sponsor confirmed 2 new archetypes — Sunken-Scholar (ranged) + Bone-Catalyst (melee). Mechanical details + final names confirmed at S2 content authoring time per v1.0 §3 Sub-track 5c.
- ✅ **SI-5 — Per-stratum NPC count in M3 Tier 3:** Sponsor confirmed 3 stratum NPCs (1 in S1, 2 in S2) on top of 3 hub-town NPCs = 6 total dialogue trees in M3 Tier 3.

Decision drafts for the next weekly DECISIONS.md batch (Priya weekly cadence):

> Decision draft: Sponsor signed Diablo-shape vertical-slice scope locks 2026-05-22 — continuous-scroll camera (SI-1), full state-branching dialogue (SI-2), Diablo-II per-act map (SI-3), 2 new S2 mob archetypes Sunken-Scholar + Bone-Catalyst (SI-4), 3 M3 Tier 3 stratum NPCs (SI-5). M3 Tier 3 W1 dispatch unblocked.

> Decision draft: Sponsor added fifth Diablo-shape directive 2026-05-22 — randomized maps per character via per-character `world_seed` + procedural chunk-fill between hand-authored anchors. Adds M3 Tier 3 procgen spike + `assemble_floor` impl + per-character-seed-save tickets to W1/W2; widens Tier 3 calendar 6-8 → 7-10 weeks honest middle.

**Open — Sponsor input needed:**

- **NEW SI-8 — Procgen scope:** (a) fully procedural chunk-fill between anchors / (b) partially procedural with hand-pinned set-pieces inside zones / (c) hybrid by stratum (S1-S2 hand-pinned, S3-S8 procedural). **Recommended:** (b) partially procedural with hand-pinned set-pieces inside zones — per the reasoning at the top of this v1.1 amendment block. **Lockable by:** end of M3 Tier 3 W1 (post-spike).

**Deferrable — remain held:**

- **SI-6 — Multi-character slot count.** Recommended: 3. Lockable by: M4 W1.
- **SI-7 — M5 stratum order.** Recommended: sequential. Lockable by: end of M4 close.
- **SI-Δ-1 — NG+ Paragon track shape.** Recommended: ship Paragon. Lockable by: M4 W2.
- **SI-Δ-2 — Ship target.** Recommended: itch.io first + Steam playtest concurrent. Lockable by: M5.9.
- **SI-Δ-3 — Per-stratum NPC density in M5.** Recommended: 1-3 per stratum tuned to tone. Lockable by: M5.1.

### v1.1 — §7 — Risk register update — R-PROCGEN added, R-SCOPE demoted

**NEW R-PROCGEN — Procgen + HTML5 procedural-seam regression.** **Probability:** med. **Impact:** high. **Why:** the procgen system is the project's first net-new content-architecture system (Tier 1 was schema-design; Tier 2 was polishing existing surfaces; Tier 3 W1 builds new content architecture). Three sub-risks:
- **R-PROCGEN.a — Per-character seed-binding bugs.** Same character → different maps across loads = save corruption-class bug. Mitigated by W1 spike's paired-GUT round-trip pin + Tess M3 Tier 3 acceptance plan including seed-round-trip in QA matrix.
- **R-PROCGEN.b — Chunk-port mating gaps at procedural seams.** Ports mis-mate produces a visible tile gap or overlap; player walks into invisible wall or sees draw-order seam. Mitigated by `level-chunks.md` § "Why ports" already-validated port-discipline + W1 spike's anchor-procgen composition gate (proof 2).
- **R-PROCGEN.c — HTML5 `gl_compatibility` procedural-seam rendering divergence.** Tilemap z-index ordering or seam draw-order differs from desktop. Mitigated by `html5-export.md` HTML5 visual-verification gate + W6-W7 Sponsor-soak probe round (NEW ticket above) + fallback to SI-8 option (c) hybrid if regression is unworkable.

**Trigger:** W1 spike surfaces any of the three sub-risks; Tess M3 Tier 3 acceptance plan flags seed-round-trip drift; Sponsor M3 Tier 3 soak surfaces visible procedural seams. **Owner:** Devon (seed-binding + save), Drew (procgen + assembler), Tess (HTML5 visual-verification gate).

**R-SCOPE (this doc's adoption) — DEMOTED.** v1.0 §7 listed R-SCOPE as the "Sponsor disagrees with milestone shape" risk. With SI-1 through SI-5 now signed and SI-8 added as a discrete pinpoint, the v1.0 R-SCOPE has effectively retired (Sponsor signed the milestone shape). **Demote to:** retired pending SI-8 sign-off. Re-arm only if Sponsor diverges on SI-8 or surfaces a new directive.

**All other v1.0 §7 risks (R-SCROLL, R-DIALOGUE, R-MAP, R-ART, R6, R-AC4, R1, R8, R-M3) unchanged.** Risk register update lands in next Priya weekly batch.

### v1.1 — §8 — Cross-references added

In addition to all v1.0 §8 references, this amendment cites:

- **`team/drew-dev/level-chunks.md`** § "Why ports, not free-form transitions" — the port-mating discipline that pre-shapes the procgen system. Already cited in v1.0 §8 § "Why chunks"; v1.1 specifically pins the "Why ports" subsection as load-bearing for Commitment 5.
- **`team/devon-dev/save-schema-v5-plan.md`** — verified to exist (M3 Tier 1 spike landed by Devon). Commitment 5's `world_seed` additive field rides on top of v5's per-character key structure (`data.characters[N].world_seed: int`) without touching the non-additive multi-character lift. The v5 spike's pointer-shadow strategy (per `save-schema-v5-plan.md §4.4`) is unaffected.

---

## v1.2 amendment — 2026-05-22 (post-W1) — W2 ticket family filed + Drew nit routing + R-PROCGEN W1 update

This amendment folds the W2 ticket pre-shape into discrete dispatch-ready tickets, routes Drew's PR #320 review nits across the W2 tickets, and updates R-PROCGEN's W1 probability now that the procgen spike is in flight.

**Authored:** end of M3 Tier 3 W1 — after PR #314 camera-scroll spike merge, PR #319 dialogue spike merge, PR #312 zone-schema spike merge, PR #320 save-survey merge, PR #323 modal-input-gate merge, PR #325 docs cleanup merge, procgen spike `86c9xub9p` dispatched to Drew Part A → Devon Parts B/C/D (in flight).

**Substantive sections that change:** §5 NEW W2 ticket family + Drew nit routing; §7 R-PROCGEN row updated (probability state now that spike is in flight).

### v1.2 — §5 — W2 ticket family filed + Drew nit routing

**Seven W2 tickets filed.** Inline IDs below; pre-filed serially per `parallel-dispatch-ticket-race` memory (Priya creates the ticket roster solo BEFORE worker dispatch fans out, so worker briefs reference the IDs without searching).

| # | Ticket ID | Title | Owner | Size | Priority |
|---|---|---|---|---|---|
| W2-T1 | `86c9y0zmg` | `feat(camera): continuous-scroll integration + S1 light retrofit` | Drew + Devon | M | P0 |
| W2-T2 | `86c9y0zyv` | `feat(dialogue): impl + first 3 hub-town dialogue trees + signal-signature wiring` | Devon + Drew | L | P0 |
| W2-T3 | `86c9y1045` | `feat(level): assemble_floor impl + S1 procgen retrofit` (SI-8-dependent) | Drew + Devon | L-XL (SI-8a/b) / M (SI-8c) | P0 |
| W2-T4 | `86c9y108t` | `feat(save): per-character world_seed save-write + v5 additive field` | Devon | S-M | P0 |
| W2-T5 | `86c9y10fv` | `feat(ui): world-map UI minimal — Diablo-II per-act parchment map` | Devon | M | P0 |
| W2-T6 | `86c9y10p4` | `art(pixellab): Sponsor batch wave 2 — Stoker + Boss + PracticeDummy + 3 hub-town NPCs` | Sponsor + Drew | L | P1 |
| W2-T7 | `86c9y10x3` | `docs(save): PR #320 review-nit corrections — signal signature + v5-paper-vs-impl footnote + v6 multi-bounty edge case` | Devon | S | P1 |

**Total W2 work estimate:** ~30-45 ticks across 7 dispatch surfaces (size varies on SI-8 lock — see W2-T3 SI-8 scope branches).

#### v1.2 — §5.1 — Drew PR #320 review-nit routing

Drew's PR #320 review (comment id 4519855248) approved Devon's save-schema v5 Tier 3 additive survey with 3 nits + 1 optional refinement, explicitly flagged "fix-on-W2-dispatch, not in this PR." Each nit is routed to the W2 ticket that most-naturally captures it:

**Drew nits 1 + 2 — `dialogue_closed` signal payload + `close()` signature.**

- **Survey-doc impact:** Survey §2.4 says save-write fires on `dialogue_closed(npc_id, branch_key)` and "Coupling guard for W2 impl" describes `DialogueController.close(npc_id, branch_key)`. **Actual engine surface:** signal is `dialogue_closed(npc_id)` single-arg (`scripts/dialogue/DialogueController.gd:116` + line 232); close is `close() -> void` (`DialogueController.gd:226`). The controller reads `_active_tree.npc_id` internally.
- **Routed to W2-T2** `feat(dialogue): impl + first 3 hub-town dialogue trees + signal-signature wiring` (Devon + Drew) — Part D acceptance: the QuestActionRouter listener stub MUST read `current_branch_key()` synchronously BEFORE `close()` clears state. Paired GUT test `test_quest_action_listener_reads_branch_key_before_close.gd` pins the read-order discipline.
- **Survey-doc correction also routed to W2-T7** — structural fix for future W2/W3 readers grepping the survey.
- **Why dual-route:** Part D in W2-T2 protects the W2 implementer from the wording trap regardless of whether W2-T7 lands first; W2-T7 ensures the survey doc itself is accurate for future readers.

**Drew nit 3 — `_migrate_v5_to_v5_tier3` function name + Save.gd HEAD = v4.**

- **Survey-doc impact:** Survey header references a forward-looking migration function name; Save.gd HEAD is `SCHEMA_VERSION = 4` (v5 lift is paper-only per PR #256 plan, not impl). Future readers grepping for the function name will not find it.
- **Routed to W2-T4** `feat(save): per-character world_seed save-write + v5 additive field` (Devon) — Part D acceptance: one-line footnote update to survey § header noting Save.gd HEAD is still v4 + v5 lift is paper-only at survey authorship time.
- **Survey-doc correction also routed to W2-T7** — centralized cleanup for the same reason.
- **Why dual-route:** W2-T4's Part D is the inline correction during the world_seed dispatch (Devon is editing the survey anyway as he wires the field); W2-T7 ensures the broader set of nits + the optional refinement land in one structural cleanup so the survey doc is accurate going into W3+.

**Drew optional refinement — v6 multi-bounty edge case.**

- **Survey-doc impact:** §9 v6 trigger guard does not enumerate the case where Track 3 W2 extends `active_bounty` from `Dictionary | null` to `Array[Dictionary]` (multiple concurrent bounties). This would be a `save-schema-v4-plan.md §4.1` rule 2 violation (type change) → v6 trigger.
- **Routed to W2-T7 only** — single-route because (a) the addendum is paper-shape, (b) no W2 ticket currently depends on multi-bounty shape (Track 3 W2 ships single-active-bounty per `mvp-scope.md §M3` shape), and (c) routing to a non-cleanup ticket would scatter the addendum.

**Routing summary:**

| Drew finding | Routing | Inline impact | Survey-doc cleanup |
|---|---|---|---|
| Nit 1 — `dialogue_closed` payload | W2-T2 Part D + W2-T7 | dialogue listener wiring | survey §2.4 |
| Nit 2 — `close()` signature | W2-T2 Part D + W2-T7 | dialogue listener wiring | survey §2.4 |
| Nit 3 — `_migrate_v5_to_v5_tier3` name + Save.gd HEAD = v4 | W2-T4 Part D + W2-T7 | save-write impl context | survey § header footnote |
| Optional — v6 multi-bounty edge case | W2-T7 only | (n/a — no W2 depends on multi-bounty) | survey §9 addendum |

This routing matches the v1.1 §4 W2 surface enumeration AND the `parallel-dispatch-ticket-race` mitigation (Priya files all 7 tickets serially BEFORE worker dispatch fans).

#### v1.2 — §5.2 — SI-8-dependent slice handling for W2-T3

W2-T3 procgen impl (`feat(level): assemble_floor impl + S1 procgen retrofit`) has substantially different scope across SI-8 options (a / b / c). The W2-T3 ticket pre-shapes the COMMON scope (FloorAssembler.gd runtime, Main.gd integration, paired tests, HTML5 verification) + enumerates THREE SI-8 scope branches in § "SI-8 scope branches":

- **SI-8 (a) — fully procedural chunk-fill between anchors** → L-XL (7-10 ticks). S1 8-room refactor + Stratum1 ZoneDef authoring + ~6-12 procedural chunks.
- **SI-8 (b) — partially procedural with hand-pinned set-pieces** → L (5-7 ticks). S1 8 rooms become anchors; smaller `procedural_slot_pool`.
- **SI-8 (c) — hybrid by stratum, S1+S2 hand-pinned, S3-S8 procedural** → M (3-5 ticks). S1 minimal retrofit; per-character seed drives anchor variant selection only; zone authoring deferred to M5.

**Why pre-shape with explicit SI-8 branches rather than wait for SI-8 lock:** Sponsor decides SI-8 at procgen-spike `86c9xub9p` PR-merge moment (per v1.1 §6 SI-8 lockable-by). Without the pre-shaped ticket, orchestrator would either (a) wait for SI-8 to lock before filing the ticket (delaying W2 dispatch by 1-2 days) or (b) file a single-scope ticket and re-scope post-SI-8 (per `parallel-dispatch-ticket-race` memory, re-scope is exactly the wasted-work the memory warns against). Pre-shaping with the three-fork SI-8 acceptance keeps the ticket dispatchable IMMEDIATELY at SI-8 lock — Sponsor signs SI-8 at PR-merge, orchestrator's NEXT tool round inlines the SI-8 outcome in the dispatch brief, W2-T3 dispatches without re-shape.

**Dispatch-time contract:** when orchestrator dispatches W2-T3, the dispatch brief MUST inline the locked SI-8 option (a / b / c) so the worker (Drew + Devon) knows which scope branch to execute. The ticket as filed is option-neutral — the dispatch brief is the binding decision-anchor.

#### v1.2 — §5.3 — Dispatch order recommendation for W2

Per `team/priya-pl/m3-tier3-w1-tickets.md` W1 dispatch-order precedent (5 parallel Day-1 dispatches across 5 worktrees; 2 parallel Day-2 dispatches accounting for Devon-wt serialization). W2 has similar Devon-wt bottleneck — Devon is co-author on W2-T1, primary on W2-T2, W2-T4, W2-T5, secondary on W2-T3. Recommend the following dispatch sequencing for the next orchestrator session:

**Day-1 (after SI-8 locks via procgen-spike PR-merge — 3-4 parallel):**

- **Drew** → `86c9y0zmg` W2-T1 camera-scroll integration (Drew-wt; Part C Devon-spec later)
- **Devon** → `86c9y108t` W2-T4 world_seed save-write (small; lands fastest; unblocks W2-T3)
- **Sponsor + Drew** → `86c9y10p4` W2-T6 PixelLab batch wave 2 (orchestrator main-session-led generation; Drew integration PRs land per character)
- **Tess** → continues acceptance-plan rows as W1 spike PRs surface (already in flight from W1)

**Day-2 (after W2-T4 lands OR is far enough along to consume world_seed — 2-3 parallel):**

- **Drew + Devon** → `86c9y1045` W2-T3 procgen impl (SI-8-locked scope; serializes Drew Part A → Devon Parts C+D per multi-author worktree pattern)
- **Devon** → `86c9y0zyv` W2-T2 dialogue impl (Devon-wt available after W2-T4 PR opens; folds Drew nits 1+2 in Part D)
- **Devon** → `86c9y10fv` W2-T5 world-map UI minimal (Devon-wt; sequences after dialogue impl OR parallel if Devon-wt freed)

**Day-3+:**

- **Devon** → `86c9y10x3` W2-T7 survey-doc cleanup (small; lands during drain)
- W2 acceptance plan close + drain

**Why this order:**

- **W2-T4 first on Devon-wt** because it's small (S-M), unblocks W2-T3, and lands fastest of Devon-wt tickets.
- **W2-T1 first on Drew-wt** because it's independent of SI-8 + provides production-wiring scaffold W2-T3 consumes.
- **W2-T6 art batch in parallel** because Sponsor labor is the critical path; the earlier the batch starts, the more time for re-rolls + integration PRs.
- **W2-T3 procgen impl on Day-2** because it depends on W2-T4 world_seed + W2-T1 camera-scroll wiring.
- **W2-T2 dialogue impl after W2-T3** because Devon-wt single-tenancy + dialogue is medium-priority (W3 hub-town impl is the consumer; not strictly W2-gating).
- **W2-T5 world-map UI** after W2-T2 OR parallel — Devon-wt available depending on dialogue impl PR timing.
- **W2-T7 cleanup during drain** — small, P1, can absorb any free Devon-wt cycle.

### v1.2 — §7.1 — R-PROCGEN probability state update (W1 in flight)

Per v1.1 §7 R-PROCGEN — med probability / high impact. Updated state at end-of-W1:

- **W1 procgen spike `86c9xub9p` in flight** (Drew Part A dispatched; Devon Parts B/C/D follow per multi-author serialization).
- **Sibling W1 spikes that procgen consumes have all landed:** zone-schema (PR #312, merged `36b0b77`) + camera-scroll (PR #314, merged `6718a07`) + save-survey (PR #320, merged `c4c07ce`). Zero blockers on procgen spike dispatch.
- **R-PROCGEN sub-risks empirically pending:**
    - **R-PROCGEN.a — Seed-binding bugs:** mitigated by Devon's Part B GUT round-trip test (in spike, promoted to production by W2-T4).
    - **R-PROCGEN.b — Chunk-port mating gaps at seams:** mitigated by Drew's Part A FloorAssembler port-mating discipline preserving `level-chunks.md` § "Why ports" patterns.
    - **R-PROCGEN.c — HTML5 procedural-seam rendering divergence:** the empirical surface that drives SI-8 lock. Spike's Part C HTML5 verification + Self-Test Report is the data Sponsor uses to decide SI-8 (a / b / c).
- **Probability update:** held at MED at W1 in-flight state. Will re-score at W2 end (post-spike-PR-merge + post-W2-T3-merge):
    - If spike + W2-T3 both close clean → demote R-PROCGEN to held off-top-5 (sub-risks all closed).
    - If spike + W2-T3 surface a single sub-risk → keep at med; re-mitigate at the specific sub-risk.
    - If spike surfaces R-PROCGEN.c unworkable → SI-8 (c) fallback kicks in; R-PROCGEN re-shapes against the hybrid-by-stratum scope.

**Follow-up note for end-of-W2 risk-register review:** the W2 close retrospective should re-score R-PROCGEN based on:
1. Procgen spike PR findings (Part D Q1/Q2/Q3 verdict).
2. SI-8 outcome (a / b / c).
3. W2-T3 + W2-T4 implementation experience (any sub-risk surfaced inline).
4. HTML5 visual-verification round (Tess + Sponsor-soak per W6-W7 sub-track).

Risk register update lands in next Priya weekly batch (Monday cadence) AFTER end-of-W2 review.

### v1.2 — §8.1 — Cross-references added

In addition to all v1.1 §8 references, this amendment cites:

- **`team/devon-dev/save-schema-v5-tier3-additions.md`** (PR #320, merged `c4c07ce`) — Devon's save-schema v5 Tier 3 additive layer survey. W2-T4 + W2-T7 are the downstream consumers.
- **`team/uma-ux/world-map-direction.md`** (PR #308, merged `481dc62`) — Uma's world-map UI direction doc; W2-T5 implements per its parchment + zone-state-as-geometry spec.
- **`.claude/docs/dialogue-system.md`** (PR #319 spike landing) — canonical signal signature for `dialogue_closed(npc_id)` (single-arg) + `close() -> void` (no-args) per Drew nit 1+2 correction routing.
- **`.claude/docs/camera-scroll.md`** (PR #314 spike landing) — production-wiring patterns W2-T1 consumes.
- **PR #320 comment id 4519855248** — Drew's review with the three nits + optional refinement that drive W2-T7's scope.

---

## v1.3 amendment — 2026-05-23 — post-W1 audit pass + W2 ticket-shape verdict + S2 pre-shape gap callout

This amendment audits the W2 ticket family against post-W1 reality, surfaces a structural gap (S2 pre-shape), and flags the SI-8 still-pending state. It does NOT supersede v1.2 — v1.2's ticket family is intact; this amendment is a verdict + delta pass against it.

**Authored:** start of W2 transition planning, after Drew Part A of procgen spike pushed to `drew/86c9xub9p-procgen-part-a` (HEAD `72e1cd6`) but Devon Parts B/C/D still pending + procgen spike PR not yet open. Main HEAD at `37bc2ee` (hooks chore PR landed). No new functional code on main since the v1.2 W2 ticket family was filed.

### v1.3 — §A — W1 outcomes summary (verified against main HEAD)

W1 spike landings, by ticket (verified against `gh pr list --state merged --limit 12` on `priya/m3-tier3-w2-pre-shape` at `37bc2ee`):

| W1 ticket | Spike PR | Merge SHA | Status | Doc captured |
|---|---|---|---|---|
| `86c9xu9yt` camera-scroll | #314 | `6718a07` | Merged | `.claude/docs/camera-scroll.md` |
| `86c9xuab3` dialogue | #319 | confirmed-merged via log | Merged | `.claude/docs/dialogue-system.md` |
| `86c9xuap4` zone-schema | #312 | confirmed-merged | Merged | (worked example `s1_z1_outer_cloister.tres`) |
| `86c9xubkj` world-map UI direction | #308 | confirmed-merged | Merged | `team/uma-ux/world-map-direction.md` |
| `86c9xuc17` save-survey | #320 | confirmed-merged | Merged | `team/devon-dev/save-schema-v5-tier3-additions.md` |
| `86c9xucuc` Tess M3 Tier 3 acceptance plan scaffold | N/A | (deferred — Tess on in-flight QA per W1 Day-1 dispatch caveat) | Pending | TBD |
| `86c9xub9p` procgen spike | (PR NOT YET OPEN) | Drew Part A `72e1cd6` pushed | **In flight** | TBD |

Plus W1-companion captures that landed orthogonally:
- PR #323 — InventoryPanel modal-input-gate (generalizes Player dialogue gate per `86c9xxg0n` / Sponsor Option A)
- PR #325 — post-W1 doc captures (modal-input-gate + spike-class spec + source-scan pin + soak-routing rule)
- PR #316 — M3 retro mitigations 1+2+3 (landed retro tightened-final-report contract + claim-fidelity amendment)
- PR #324 — session-closure captures (Drew unmerged-API-defer + Tess 3 finds + morning-Tess incident)

**SI-8 still NOT locked.** Per v1.1 §6, SI-8 is lockable at procgen-spike PR-merge moment. Drew Part A is on a branch; Devon Parts B/C/D pending; spike PR not yet open. Sponsor decision deferred until spike PR surfaces empirical answers to the three proof questions (seed round-trip / anchor-procgen composition / HTML5 procedural-seam rendering).

### v1.3 — §B — W2 ticket-shape verdict (per ticket)

Per CLAUDE.md "never fabricate, never guess" — **ClickUp MCP is not connected in the current orchestrator session**, so I cannot fetch the seven W2 ticket bodies via `clickup_get_task` to verify acceptance criteria byte-for-byte. The verdict below is grounded in the v1.2 §5 ticket-roster table + the routing tables + the dispatch-order recommendation that I authored in the same prior session. If Sponsor / next orchestrator finds drift between the v1.2 table and the actual ClickUp ticket bodies, this verdict is the canonical paper-shape and ClickUp body updates should reconcile to it (route via `clickup_update_task` once MCP is reconnected).

| W2 ticket | Verdict | Rationale |
|---|---|---|
| W2-T1 `86c9y0zmg` camera-scroll integration | **Keep as-is** | `.claude/docs/camera-scroll.md` § "Open follow-ups" enumerates the exact W2 scope (S1 retrofit + `Main._load_room_at_index → set_world_bounds`); no scope drift from W1 spike findings |
| W2-T2 `86c9y0zyv` dialogue impl + 3 hub-town trees | **Amend — fold v1.2 Part D explicitly** | v1.2 §5.1 routed Drew nits 1+2 (`dialogue_closed(npc_id)` single-arg signature + `close() -> void` no-args) into "Part D" of this ticket; ticket body MUST inline the `current_branch_key()`-before-`close()` read-order discipline + paired GUT test name `test_quest_action_listener_reads_branch_key_before_close.gd`. Verdict: amend ticket body if not yet inlined |
| W2-T3 `86c9y1045` assemble_floor impl + S1 procgen retrofit | **Keep as-is, dispatch-blocked on SI-8** | v1.2 §5.2 pre-shaped with three SI-8 scope branches; option-neutral; dispatch brief (not ticket) inlines locked option. No re-shape needed until SI-8 surfaces from procgen spike PR |
| W2-T4 `86c9y108t` world_seed save-write + v5 additive field | **Amend — fold v1.2 Part D** | v1.2 §5.1 routed Drew nit 3 (`_migrate_v5_to_v5_tier3` name + Save.gd HEAD = v4) into "Part D" of this ticket; ticket body MUST inline the survey § header footnote correction acceptance criterion |
| W2-T5 `86c9y10fv` world-map UI minimal — Diablo-II per-act parchment map | **Keep as-is** | `team/uma-ux/world-map-direction.md` (PR #308) is the binding direction doc; v1.2 §8.1 cross-reference still load-bearing; no scope drift |
| W2-T6 `86c9y10p4` PixelLab batch wave 2 | **Keep as-is** | Sponsor labor cadence is the critical path; ticket is open-ended on Sponsor capacity per `m3-art-pass-collaboration-shape` memory; no W1-finding-driven scope change |
| W2-T7 `86c9y10x3` survey-doc cleanup + v6 multi-bounty edge case | **Keep as-is** | v1.2 §5.1 routing table is the load-bearing scope; small (S) cleanup ticket; no W1 surface change |

**Net verdict:** 5 keep-as-is / 2 amend / 0 new. The two amendments are both **already paper-shaped in v1.2 §5.1** — they require ClickUp body updates to inline the v1.2 §5.1 Part D acceptance criteria. If ticket bodies were filed as one-line headlines, the amendment ask is "expand acceptance to mirror v1.2 §5.1 Part D content." If ticket bodies already inline v1.2 §5.1, amendment is a no-op and verdict collapses to "keep as-is."

**Recommended next action:** next orchestrator session (with ClickUp MCP reconnected) runs `clickup_get_task` on W2-T2 + W2-T4, verifies Part D acceptance criteria are inlined; if not, `clickup_update_task` to amend.

### v1.3 — §C — Identified W2 gaps (post-W1 reality check)

The W2 ticket family is dispatch-ready for the **system-shape** lane (camera, dialogue, procgen, save, world-map UI, art batch, doc cleanup). But the brief's gap-question prompted a re-read of v1.1 §3 calendar — and one structural gap surfaces:

**Gap 1 — Tess M3 Tier 3 acceptance plan scaffold (`86c9xucuc`) NOT YET landed.** Per `m3-tier3-w1-tickets.md` recommendation, Tess scaffold was Day-1 W1 dispatch; ticket roster table above shows it as Pending. If Tess was on in-flight QA at W1 Day-1, the scaffold ticket may have slipped into W2. **Action:** verify ticket status next session; if still Pending, escalate to Day-1 W2 dispatch (Tess scaffold-from-day-1 pattern still applies). No new ticket needed — `86c9xucuc` already exists.

**Gap 2 — NO S2 pre-shape work in W2.** Per v1.1 §3 calendar, Weeks 4-5 = "Sub-track 5c S2 content authoring (zones + new mobs) WITH procedural chunk-fill inside zones via the W2 assembler." Weeks 4-5 starts at W3+ in the wave-naming convention. The W2 ticket family does NOT pre-shape any S2 content authoring tickets (Stratum2 ZoneDef authoring, 2 new mob archetypes Sunken-Scholar + Bone-Catalyst, S2 chunk authoring, S2 boss room). **Action:** this is intentional per the W2 scope (system-shape land first, then content scales against locked shape). **But:** pre-shaping a W3 ticket roster as the W2 mid-retro lands is the right cadence — Priya's next dispatch (post-W2 mid-retro) should produce a W3 ticket pre-shape doc analogous to this v1.2 amendment. Not blocking W2 dispatch; flagging for the W2 mid-retro action list.

**Gap 3 — NO ticket for HTML5 procedural-seam Sponsor-soak round in W2.** Per v1.1 §4 W6-W7 ticket pre-shape, the HTML5 procedural-seam Sponsor-soak round lands W6-W7 (Tess + Sponsor). At W2 timing this is mid-future; not a W2 gap. **Action:** none in W2; flag for W5 pre-shape doc.

**No new W2 tickets filed.** The system-shape W2 lane is complete; S2 content authoring deferred to W3+ per v1.1 §3 calendar intent.

### v1.3 — §D — Calendar honesty pass

W1 calendar shape (v1.1 §3): Week 1 = SI-8 signs + 3 spikes + Sub-track 5a PixelLab batch wave 1.

Actual W1 outcomes (post-2026-05-22 close):
- 4 of the 5 system-shape spikes landed (camera-scroll, dialogue, zone-schema, save-survey, world-map direction).
- Procgen spike `86c9xub9p` — Drew Part A pushed, Devon Parts B/C/D pending, PR not yet open. **~1-2 day slip** behind the Week 1 calendar shape.
- SI-8 NOT YET signed (gated on procgen-spike PR-merge). Calendar shape said "Week 1 — Sponsor signs SI-8" — this slips with procgen.
- Tess `86c9xucuc` acceptance plan scaffold — pending per ticket status; if Tess on in-flight QA at Day-1, slip into W2.
- Sub-track 5a PixelLab batch wave 1 — not yet visible in W1 PRs; appears to have not started or is in Sponsor-private execution. Sponsor labor capacity is the critical path; no orchestrator-side action needed unless Sponsor flags strain.
- Unplanned wins: PR #323 modal-input-gate (W1 Sponsor Option A signed mid-W1); PR #316 M3 retro mitigations; PR #325 post-W1 doc captures; PR #324 session-closure captures.

**Calendar verdict:** W1 timing is **on the floor of v1.1 §3** but not slipping below it. Tier 3 stays at 7-10 weeks honest middle. The ~1-2 day procgen spike slip is absorbed inside the W1 buffer (W1 spans Days 1-7 nominal; procgen lands Day 8-9 → still within Week 1.5). **No calendar update to v1.1 §3.** If procgen spike PR slips beyond 2026-05-25 (Day 4), update §3 to reflect 7-10 → 7.5-10.5 weeks; until then, hold.

**Honest grade on W1 velocity:** **B+**. Massive parallel landing (4 system-shape spikes + 4 orthogonal captures in 1 calendar day) is high velocity; the procgen spike not closing in the same day is the gap that prevents an A grade — that's the SI-8 gating ticket and it's the largest W1 surface (L-XL). No sandbagging; no sugar-coating.

### v1.3 — §E — Risk register state post-W1

Per v1.2 §7.1 R-PROCGEN held at med probability / high impact. Post-W1 update:

- **R-SCROLL** — DEMOTED. Camera-scroll spike #314 landed with paired Playwright spec + GUT pins + HUD-immunity preserved; Sponsor soaked. No HTML5 regression surfaced. Demote off top-5 risks.
- **R-DIALOGUE** — DEMOTED. Dialogue spike #319 landed with three GUT pin sets + Playwright boot smoke + `.claude/docs/dialogue-system.md` capture. Schema converged in one pass; modal UI shipped with the spike. Demote off top-5 risks.
- **R-MAP** — HELD. World-map direction #308 landed; impl is W2-T5; Sponsor soak gate at W2-T5 PR-merge moment.
- **R-PROCGEN** — HELD AT MED. Spike not yet closed; SI-8 still gating. v1.2 §7.1 rescore conditions unchanged.
- **R-ART** — HELD. Sub-track 5a PixelLab batch wave 1 visibility low at W1 close; sentinel watch continues.

Risk-register update lands in next Priya weekly batch (Monday cadence) — captures these demotions + R-PROCGEN re-score at end-of-W2.

### v1.3 — §F — Cross-references added

In addition to all v1.2 §8.1 references, this amendment cites:

- **PR #316** — `pm(process): land M3 retro mitigations 1+2+3` — landed the tightened-final-report contract amendment (claim-fidelity + return-timing). Sub-agent reports across W2 dispatch MUST conform.
- **PR #324** — session-closure captures (Drew unmerged-API-defer + Tess 3 finds + morning-Tess incident). Process-incident discipline pattern.
- **`team/priya-pl/m3-tier3-w1-tickets.md`** — the W1 dispatch-ready ticket roster; W2 dispatch order in v1.2 §5.3 mirrors its parallel-dispatch shape.

---

## v1.0 content — historical record below

The v1.0 content below is preserved unchanged from the initial 2026-05-22 authoring. This v1.1 amendment supersedes the v1.0 content by section (per the section list at the top of this amendment block). Read the v1.1 amendment block above first for the current shape; read v1.0 below for the reasoning chains and dependency graphs that didn't change.

---

**Owner:** Priya · **Authored:** 2026-05-22 · **Status:** v1.0 — Sponsor signed two major direction locks same-day (level-scale + Diablo-shape); milestones below shaped around them. Sponsor-input pending on seven items in §6.

This doc is the **canonical sequencing artifact** for the work the team does after M3 Tier 2 Wave 3 lands. Sponsor's ask: *"do the tasks in the order that any professional game developer team would progress."* Below is the order, with the reasoning, the milestones, the pre-shaped tickets (counts + ownership, not dispatched), the Sponsor-input items that gate each milestone, and the risk-register shifts that follow from adopting it.

The doc is **opinionated**. Where the "Priya is cautious" path and the "this is what actually ships" path diverged, I picked the second. Sponsor signs off the §6 items or redirects.

## TL;DR (6-line summary)

1. **Diablo-shape directive landed same-day** (§1). Sponsor resolved the mixed reference shelf in `game-concept.md` — *"im leaning more to the diablo genre where you have to talk to npcs, explore the levels to solve quests, being able to see the world on a map with the different areas."* Four first-class commitments: continuous-scroll camera-follow / talk-to-NPCs dialogue system / quest-driven exploration tied to geography / world-map UI. This re-shapes everything past Wave 3.
2. **Three milestones past Wave 3, in this order:** **M3 Tier 3 = Diablo-shape vertical slice** (S1 + S2 as a polished 2-stratum proof: continuous-scroll + dialogue system + per-stratum NPCs + S1 art-pass + hub-town + a-handful-of-quests + minimal map) → **M4 = scale-out and systems** (save-schema v5 + multi-character + persistent meta + bounty content + dialogue content + world-map UI) → **M5 = S3-S8 stratum-by-stratum + narrative + ship**.
3. **Vertical-slice-first is the pro-team move.** Per Sponsor's "scope-cut to 2-3 strata in M3" framing — ship Diablo-shape S1+S2 fully polished BEFORE authoring S3-S8 against the new pattern. That's the "looking forward to see the result" deliverable, and it de-risks the 6-stratum content grind in M5.
4. **The level-scale rework + dialogue system + exploration quests all land in M3 Tier 3.** Three new systems land alongside the S1 art-pass + hub-town impl. M3 Tier 3 widens from a 3-4 week visible-progress milestone to a ~6-8 week vertical-slice-fidelity milestone. That's honest; this is the milestone where the genre identity lands.
5. **Character-art beats hub-town and dialogue in dispatch order within M3 Tier 3** (§3). The PixelLab batch ships incrementally per `m3-art-pass-collaboration-shape` memory; visible progress on mobs happens before hub-town surfaces; dialogue + map UIs land after the NPCs are sprite-real (so the player isn't talking to placeholder squares).
6. **Total calendar from now to ship: ~10-14 months honest middle.** Was ~8-10 months pre-Diablo-lock; the dialogue system + world-map UI + per-stratum NPCs + quest content + level-scale rework all add multi-week implementation cost. Hex-block fallback (per `m3-design-seeds.md §4 Risks`) is the slip safety net.

---

## Source of truth

This doc extends:

- **`team/priya-pl/game-concept.md`** (v1 FROZEN 2026-05-02) — the 8-strata / T1-T6 / NG+ Paragon content contract. Diablo-lite is in the reference set; Sponsor's 2026-05-22 lock resolves the mixed reference toward the Diablo branch.
- **`team/priya-pl/mvp-scope.md` §M3** — "All 8 strata, T1-T6 gear, full affix pool (~40 affixes), crafting/reroll bench, bounty quest system, NG+ Paragon track, all bosses, all 12 mob archetypes, full music score, lore text completed." This doc splits the M3 paragraph across M3 Tier 3 + M4 + M5.
- **`team/uma-ux/visual-direction.md`** § "Internal canvas + scaling rules" + § "Camera" + § "Stratum visual progression" — current locks; §1 below plans the camera amendment.
- **`team/priya-pl/m3-design-seeds.md`** — four-axes Shape A decomposition; this doc commits to the parallel-track milestone shape.
- **`team/priya-pl/m3-tier-1-plan.md`** — Tier 1 closed (save-schema-v5 spike, hub-town direction, art-pass brief, title-screen slot-picker spec, M3 QA scaffold all merged).
- **`team/priya-pl/m3-tier2-boss-room-polish-scope.md`** — Tier 2 plan; Waves 1+2 complete, Wave 3 dispatched 2026-05-22.
- **`team/uma-ux/hub-town-direction.md`** — hub-town direction landed; "the cloister did not stay empty"; implementation queued.
- **`team/priya-pl/art-pass-ai-primary-brief.md`** — Sponsor-DIY PixelLab pipeline; commission path shelved per $100 v1 budget.
- **`team/drew-dev/level-chunks.md`** § "Why chunks" — `ports + assemble_floor` already pre-shaped for multi-chunk strata.
- **`.claude/docs/orchestration-overview.md`** — team topology + dispatch conventions.
- **`.claude/docs/html5-export.md`** — visual-verification gate that every Tier 3 + M4 + M5 PR routes through.
- **2026-05-22 Sponsor signals** (verbatim, all same day, in dispatch order):
  - *"i want the team to do the tasks in the order that any professional game developer team would progress"* — drives this doc.
  - *"right now the levels are quite small and i hope that the final levels will feel more like walking through a level not just seeing the entire level at once"* — drives §1 commitment 1.
  - *"im leaning more to the diablo genre where you have to talk to npcs, explore the levels to solve quests, being able to see the world on a map with the different areas"* — drives §1 commitments 2-4.

---

## §1 — Diablo-shape directive (four first-class commitments)

Sponsor's 2026-05-22 signals resolve the mixed reference shelf in `game-concept.md` (which carried *Hades* / *Tunic* / *Crystal Project* / *Diablo*-lite together). **Sponsor has picked the Diablo branch.** Four commitments follow, each a first-class architectural constraint for everything past Wave 3. Folded in directly because they re-shape the milestone order.

### Commitment 1 — Continuous-scroll camera-follow per stratum

> *"right now the levels are quite small and i hope that the final levels will feel more like walking through a level not just seeing the entire level at once"*

**The lock:** Diablo-style camera follows player smoothly across multi-screen chunk-stitched tilemaps. Per Sponsor's selection of option (a) from the camera-shape framing, the (b) Zelda-edge-pan and (c) Tunic-fixed-camera alternatives are dropped from consideration. Continuous-scroll is the shape.

**What changes:** rooms become wider-than-screen volumes (`assemble_floor` runtime chunk-stitching per `level-chunks.md` extension hooks); camera clamps at world edges; player feels like they're walking through a place rather than seeing each room as a tableau.

**What stays locked regardless:** 480×270 logical canvas, integer-scale (2×/3×/4×), nearest-neighbour filter, 32×32 internal tile, ember `#FF6A2A` through-line, HUD on screen-space CanvasLayer (HUD-immune to scroll per PR #293's `CameraDirector`). **Camera + level-composition change, NOT a visual-pixel-density change.** The PixelLab character art being commissioned does NOT need to be re-authored to support scroll.

**Reference architecture:** `level-chunks.md` § "Why chunks" already pre-shaped for it (`ports + assemble_floor` extension hooks); `CameraDirector` autoload already in production (PR #293) with zoom + HUD-immunity; the work is the follow-scroll API extension + bounds-clamp + `assemble_floor` runtime chunk-stitch + HTML5 visual-verification of scroll on `gl_compatibility`.

**Cost:** L-XL. The follow-scroll + bounds-clamp + chunk-stitching is the high-leverage new architecture; HTML5 scroll-rendering on `gl_compatibility` is the slip risk (z-index seams between chunks; tilemap edge rendering). See `risk-register.md` R-SCROLL addition (§7 below).

### Commitment 2 — Talk-to-NPCs dialogue system (first-class, not hub-town flavor)

> *"...where you have to talk to npcs..."*

**The lock:** dialogue is a first-class game system, not flavor text on hub-town pawns. Per-stratum NPC roster (estimated 1-3 NPCs per stratum acting as questgivers / lore-witnesses / vendors-in-zone). Text-based — per `game-concept.md` "Voice acting (text only)" out-of-scope rule, no voice acting; same lock applies.

**What's new:** the codebase has **no dialogue tree engine**. Currently there is no NPC interaction surface at all — `hub-town-direction.md` plans 3 stationary NPCs with "interact prompts" but the prompts are stubbed; clicking them does nothing yet. **The dialogue system is net-new authoring**, not an extension of an existing surface.

**System shape (recommended):** Diablo II-style dialogue. Player walks up + presses E → modal dialog box opens with NPC name, NPC sprite portrait, dialogue text, response options (sometimes branching, sometimes a quest acceptance / decline gate). Reactive based on quest state (NPC's first-meeting dialogue differs from their post-quest dialogue). NOT the full conversation-tree complexity of *Disco Elysium* or *Pillars of Eternity* — Diablo's dialogue is bounded, mostly quest-relevant + flavor exchanges.

**Data shape:** `resources/dialogue/<stratum>_<npc_id>.tres` per NPC. Each `.tres` is a `DialogueTreeDef` with branches keyed by quest state (`pre_quest_offer / quest_active / quest_completed / quest_failed`). The system reads `Player.active_bounty + Player.completed_bounties` to choose the right branch.

**Cost:** M-L. Dialogue tree engine + modal UI + `.tres` schema + content for ~9-15 dialogue trees (3 hub-town NPCs + 6 stratum NPCs across S1+S2 vertical slice + their state branches). Per `m3-design-seeds.md §2` the hub-town design already plans 3 NPCs (Hadda / Brother Voll / Sister Ennick) — those are the first dialogue consumers.

**Landing point:** M3 Tier 3, alongside hub-town impl. The dialogue system must land BEFORE hub-town impl OR concurrently (so hub-town NPCs ship with working dialogue, not stub prompts).

### Commitment 3 — Quest-driven exploration tied to geography

> *"...explore the levels to solve quests..."*

**The lock:** quests are tied to **specific zones / map locations**, not pure procedural-chunk assembly. Diablo II's "Den of Evil" + "Search for Cain" + "Tools of the Trade" pattern — each quest references a named zone the player travels to. This requires **hybrid hand-authored zones + procedural-fill within zones**, like Diablo II's "act-fixed-with-procedural-tilesets" model.

**What changes for `level-chunks.md`:** the schema extends to support **named zones** as a layer above chunks. A zone is a fixed set of chunks (hand-arranged by Drew per `level-chunks.md` ports pattern) that quest data can reference by name. Quest content reads `zone_id` to determine where in the stratum the quest objective is located.

The pure procedural-chunk shuffle stays — but only within zones, not across them. S2's "Sunken Library" stratum might have 3-4 named zones (e.g. `s2_z1_entry_hall / s2_z2_reading_chamber / s2_z3_archive_vault / s2_z4_inner_sanctum`) and the procedural assembler chooses room layouts WITHIN each zone but the zones themselves are fixed sequence.

**Bounty quest scope shift:** the bounty quest system per `mvp-scope.md §M3` reads as a "kill N of mob-X" framing; Sponsor's "explore the levels to solve quests" implies a richer surface — fetch quests, find-named-mob quests, escort quests, lore-clue quests. **The bounty system shape stays the same** (one quest active at a time, 5-8 quest archetypes per `m3-design-seeds.md §3.9`); the **archetype mix** shifts toward exploration-flavored quests.

**Cost:** M. The zone schema extension to `level-chunks.md` is a small data layer ($-time: <1 dev-week). The exploration-quest content authoring is the bigger cost (Sponsor + Uma + orchestrator collaboration on quest text + objectives + rewards) but lands in M3 Tier 3 vertical slice as a small batch (3-5 quests across S1+S2) and M5.7 fills the rest.

### Commitment 4 — World-map UI

> *"...being able to see the world on a map with the different areas"*

**The lock:** new UI surface — overworld / area-map showing stratum structure + zones within strata + waypoint travel between completed-once zones.

**System shape (recommended — see §6 SI-3 for Sponsor input):** the embryo is already in `hub-town-direction.md §4` — the descent-portal already opens a stratum-picker UI. That picker evolves into a **multi-pane world-map**: pane 1 is the overworld (8 strata as nodes; lit when discovered); pane 2 is per-stratum (the named zones from Commitment 3; lit when reached); pane 3 (deferrable to M5) is per-zone (room-tree showing where the player has been).

**Three Sponsor-input alternatives:** see §6 SI-3 below. Recommend Diablo-II-style per-act map (no global overworld; player sees current stratum's zones, navigates between waypoints via the descent-portal). Reasons: cheapest to author, matches Sponsor's "areas in strata" framing, scales naturally to 8 strata without map complexity exploding.

**Cost:** M. Map UI is screen-space CanvasLayer (HUD-immune to scroll); the data is `Player.discovered_zones: Dictionary` (additive to v4 save schema). Waypoint travel is a teleport flag on the zone-transition. Per-zone room-tree (pane 3) is deferrable to M5 polish.

**Landing point:** M3 Tier 3 ships a minimal version (stratum-picker + zone-list at descent-portal); M4 ships the full pane structure; M5 deferred per-zone room-tree.

---

## §2 — Why this is a vertical-slice-first milestone shape (Sponsor's "scope-cut" framing absorbed)

Sponsor explicitly framed the scope: *"We CAN ship a Diablo-shape 2-3-stratum vertical slice... That's the 'looking forward to see the result' deliverable... Recommend in the doc: scope-cut the 8-strata ambition INSIDE M3 to a Diablo-shape 2-3-stratum vertical slice that proves the new pattern works. Then M4/M5 scale to 8 strata once the pattern is dialed. This is what a pro team does — vertical slice first at full polish + system depth, then content-scale."*

**This is the load-bearing call in the milestone shape.** M3 Tier 3 becomes the **vertical-slice fidelity** milestone — S1 + S2 fully Diablo-shape-polished with all four §1 commitments live. M4 scales the systems (multi-character, persistent meta, save-schema v5, bounty content roster fill). M5 ramps S3-S8 against the locked pattern.

**Why this is the pro-team move:**

1. **De-risks the 6-stratum content grind.** If S2 ships with continuous-scroll + dialogue + exploration quests + a working area-map, AND Sponsor + Tess + orchestrator agree the pattern feels right, then S3-S8 inherit a known-working pattern. Re-shaping the pattern at S5 because S3 felt wrong is the killer slip class — vertical-slice-first eliminates it.
2. **Sponsor visible-progress alignment.** Sponsor's "looking forward to see the result" framing is the soak Sponsor wants in calendar weeks, not months. A 2-stratum vertical slice ships at full polish in M3 Tier 3 calendar; the 6-stratum grind in M5 is acceptable to defer because the vertical slice has already proven the experience.
3. **Honest scope.** 8 strata × full Diablo-shape × continuous-scroll × dialogue × per-stratum quests × world-map is multi-year content authoring. *Diablo II shipped with 4 acts × 6 zones × dozens of quests after a 3-year team-of-30 dev cycle* — Sponsor's framing. A single-team, part-time pace cannot ship that in 8-12 months; **the realistic ship is "Diablo-shape 8-stratum, but with the per-stratum content density of the M5 budget,"** which is more like Crystal Project's density than Diablo II's. The vertical slice proves the pattern; the content grind ships what the team can ship.
4. **System-shape iteration in the slice, content fill in the grind.** M3 Tier 3 is where dialogue system shape gets tuned (does the modal feel right? does the response-option flow work? does the area-map UI scale to 8 strata?). M5 is content authoring against locked system shape. Iterating system shape in M5 against finished S3 content is the classic indie-killer; vertical-slice-first prevents it.

---

## §3 — Milestones (M3 Tier 3 → M4 → M5)

Three milestones past Wave 3, in dispatch order. Each milestone has a tight headline, content, dependencies, calendar shape, and gates.

### M3 Tier 3 — Diablo-shape vertical slice (S1+S2 polished)

**Headline:** *Ship a 2-stratum Diablo-shape vertical slice. Sponsor downloads the build, walks through S1 with continuous-scroll camera + a few NPCs talking to him, accepts a quest from the bounty board, descends to S2 via the world-map UI, fights a Sunken Library NPC's quest objective, returns to hub-town to turn in. All of it with PixelLab character art, not squares.*

**Why this milestone first:** absorbs all four §1 commitments + the S1 art-pass + hub-town build-out + boss-room polish (Tier 2 close) + S2 content authoring against the new pattern. This is THE milestone where the genre identity lands. Sponsor's "looking forward to see the result" framing maps directly to this milestone's deliverable.

**Content (five parallel tracks, ordered by dispatch-priority within the milestone):**

**Track 1 — Camera-scroll + level-scale rework (Commitment 1).** Devon/Drew spike → `CameraDirector` follow-scroll API extension → bounds-clamp → `assemble_floor` runtime chunk-stitch → S1 light retrofit (existing 8 rooms stay, but camera follows + transitions read continuous) → docs amendment (`visual-direction.md` § Camera + `level-chunks.md` § Why chunks + new `.claude/docs/camera-scroll.md`).

**Track 2 — Dialogue system (Commitment 2).** Devon authors `DialogueTreeDef` `.tres` schema + `DialogueController` autoload + modal `DialoguePanel.tscn` UI surface. Tests: paired GUT for tree traversal + Playwright HTML5 for modal-render-and-input. Devon-Drew handoff: Drew authors the first dialogue trees (3 hub-town NPCs + 1-2 stratum NPCs as proof of pattern), Uma direction-reviews tone.

**Track 3 — Zone schema + exploration quest content (Commitment 3).** Drew extends `level-chunks.md` schema with `ZoneDef` layer (named zones containing chunk sequences); authors S1 + S2 zones (~3-4 zones per stratum). Sponsor + Uma + orchestrator collaborate on 3-5 exploration quests across S1+S2; Devon wires the quest-state-aware dialogue branching (Track 2 dep) + zone-bound quest objective tracking.

**Track 4 — World-map UI minimal (Commitment 4).** Devon authors `WorldMap.tscn` + `Player.discovered_zones` save field (additive v4); expands the descent-portal's stratum-picker into the minimal map UI (stratum-list + zone-list per stratum). Sponsor input gates the map shape (§6 SI-3). Uma direction on map visual style (parchment overlay vs floating screen-space UI vs other).

**Track 5 — S1 character art-pass + hub-town impl + S2 content + S2 boss room polish.** This is the visible-progress envelope.

- **Sub-track 5a:** S1 art-pass via Sponsor PixelLab — Player + Grunt + Charger + Shooter + Stoker (S2 retint) + PracticeDummy + Stratum1Boss + 3 hub-town NPCs. Mob-by-mob ship per `m3-art-pass-collaboration-shape` memory. ~22-31 hr Sponsor labor per `art-pass-ai-primary-brief.md`. ~10 PRs.
- **Sub-track 5b:** `HubTown.tscn` scene authoring per `hub-town-direction.md` (single-screen 480×270 by design; not a scroll room). Drew authors; Devon wires `meta.hub_town_seen` save-state + scene-routing.
- **Sub-track 5c:** S2 content — 8 chunks + 8 rooms per zone organization; 2 new S2 mob archetypes per `m3-design-seeds.md §3` taxonomy (recommended: Sunken-Scholar ranged + Bone-Catalyst melee — Sponsor input pending on names, §6 SI-4); S2 boss room + boss following the Tier 2 wave-pattern.
- **Sub-track 5d:** Per-stratum NPCs — 1 NPC in S1 (e.g. a wounded scholar near the descent), 2 NPCs in S2 (e.g. a librarian + a captive). Sponsor PixelLab + Drew integration + Uma direction.

**Dependencies (cross-track):**

- Track 1 (camera-scroll) gates Track 5c (S2 content authoring — S2 ships with the new schema). 
- Track 2 (dialogue) gates Sub-tracks 5b (hub-town NPCs need dialogue), 5d (stratum NPCs need dialogue), Track 3 (exploration quests use dialogue branching).
- Track 3 (zones) gates Sub-track 5c (S2 zones use the schema) + Track 4 (map UI references zones).
- Track 4 (world-map UI) absorbs §6 SI-3 Sponsor sign-off.
- Sub-track 5a (character art) gates 5b/5d's "feels real" — hub-town with placeholder NPC squares is a strictly-worse soak than hub-town with PixelLab NPCs; same for stratum NPCs.

**Calendar shape:**

- **Week 1** — Sponsor signs §6 SI-1 through SI-4. Track 1 spike (camera-scroll). Track 2 spike (dialogue schema design). Sub-track 5a Sponsor PixelLab batch starts (Player + Grunt + Charger + Shooter first wave).
- **Weeks 2-3** — Track 1 implementation + S1 retrofit. Track 2 implementation + first 3 dialogue trees (3 hub-town NPCs). Track 3 zone-schema extension + 2-3 exploration quests authored. Sub-track 5a continues; ~7-8 sprites delivered by end of W3.
- **Weeks 4-5** — Track 4 world-map UI minimal. Sub-track 5b hub-town impl (with real PixelLab NPC sprites). Sub-track 5d S1 + S2 NPC sprites + dialogue trees. Sub-track 5c S2 content authoring (rooms + new mobs).
- **Weeks 6-7** — S2 boss room polish (mini-Tier-2-wave); Sub-track 5d completes; Tess M3 Tier 3 acceptance plan + per-track QA omnibus.
- **Week 8** — Sponsor M3 Tier 3 soak; fix-forward absorbed.

**Total calendar:** ~6-8 weeks parallel-dispatched. Wider than the original 3-4 weeks because the dialogue system + zone schema + world-map UI are net-new work, not extensions. Honest middle is 8 weeks; floor is 6 if Sponsor's PixelLab capacity is strong.

**Gate to M4:** Sponsor sign-off on M3 Tier 3 soak. If the Diablo-shape feels right (continuous-scroll OK, dialogue flows OK, map UI navigable, ≥3 exploration quests demonstrable, S1+S2 visually shipped), the team has earned the right to scale to M4 systems. **The vertical slice gate is the load-bearing gate for the whole project.**

### M4 — Scale systems + content fill

**Headline:** *Take the proven vertical-slice pattern and add the M3 paragraph's mechanical depth: save-schema v5 + multi-character + persistent meta + bounty content roster + dialogue content fill + world-map UI expansion. No new strata; this is mechanical work.*

**Why second:** vertical slice has proven the pattern works at S1+S2. M4 ships the mechanical depth `mvp-scope.md §M3` wrote without authoring more strata. Sponsor's "M4/M5 scale to 8 strata once the pattern is dialed" framing maps M4 to systems and M5 to strata.

**Content (four tracks):**

**Track 1 — Save-schema v5 impl + multi-character UI.** Devon's `save-schema-v5-plan.md` spike landed in Tier 1; M4 implements (non-additive `data.character` → `data.characters[]`; equipped lifts; shared_stash root). Drew authors `TitleScreen.tscn` slot-picker per Tier 1 spec. v4 → v5 migration test suite.

**Track 2 — Persistent meta (ember-shard currency + Paragon).** Ember-shard drops on stratum kills; ember-shard wallet on character; vendor + anvil consume ember-shards. Paragon point allocation post-level-30 (lifts from M3's level-30 cap implementation).

**Track 3 — Bounty content roster fill + dialogue content fill.** M3 Tier 3 shipped 3-5 exploration quests (the system proof). M4 fills the roster to 5-8 archetype-tagged quests per `mvp-scope.md §M3` + ~15-20 dialogue trees (all hub-town NPCs + S1+S2 stratum NPCs at full state-branching depth).

**Track 4 — World-map UI expansion + per-zone room-tree.** M3 Tier 3 shipped minimal map (stratum-list + zone-list). M4 expands to full pane structure: per-zone room-tree (pane 3), waypoint travel between visited zones (drives mid-stratum stash chamber from M2; M3 hub-town remains canonical), discovered-zone indicators on the map.

**Dependencies:**

- Track 1 (v5 schema) is foundational; Tracks 2-4 consume v5 fields.
- Track 3 (content fill) depends on M3 Tier 3 dialogue + quest systems being proven.
- Track 4 depends on §6 SI-3 sign-off and M3 Tier 3's minimal-map shape.

**Calendar shape:**

- **Week 1** — Track 1 v5 impl.
- **Weeks 2-3** — Tracks 2-4 parallel-dispatched.
- **Week 4** — Tess M4 acceptance + Sponsor M4 soak.

**Total calendar:** ~4-5 weeks parallel-dispatched. Lighter than M3 Tier 3 because no new strata + no new systems (only system extensions).

**Gate to M5:** Sponsor sign-off on M4 soak. At this point Embergrave is a 2-stratum Diablo-shape game with all systems live + most content authored. M5 ramps S3-S8.

### M5 — S3-S8 stratum-by-stratum + narrative + ship polish

**Headline:** *Grind the remaining six strata against the locked pattern, write the lore, polish for release, deploy to itch.io.*

**Why third:** systems are done at M4 close; S3-S8 is incremental content authoring against locked schema + locked dialogue system + locked map UI. This is content grind in the Crystal Project / Stardew Valley sense — solo-team density, not Diablo-II density.

**Content (per-stratum waves + closing waves):**

**Waves M5.1 through M5.6 — One stratum per wave.** Each wave authors:

- Per-stratum palette + visual direction (Uma authors `palette-stratum-N.md`).
- Per-stratum audio (Uma audio-direction extension; placeholder synthesis).
- 2-3 named zones per stratum (per Commitment 3 schema; Drew authors).
- ~8 rooms per stratum across zones (Drew authors chunks).
- 1-2 new mob archetypes per stratum (the M3 paragraph's "12 mob archetypes" — M1 + M2 cover ~5, M3 Tier 3 S2 adds 2 = 7, M5 adds 5 across S3-S8 to hit 12). PixelLab generation + integration.
- 1-3 stratum NPCs per stratum (PixelLab + dialogue trees + exploration quests tied to the stratum).
- 1 stratum boss per stratum (mini-Tier-2-wave polish per stratum).

**Wave M5.7 — Bounty + exploration quest content extended.** M4 shipped 5-8 quest archetypes; M5.7 fills with S3-S8 quest content (typically 1-2 quests per stratum, tied to that stratum's NPCs + zones).

**Wave M5.8 — Narrative + lore pass.** ~30 min of lore text per `game-concept.md` "Story is hand-written and short (~30 min of lore text total)" — bounty quest descriptions + stratum-entry title cards + boss-defeat micro-cards + flavor text on items + NPC dialogue depth (lore-witnesses get rich state-branching). Writer: orchestrator + Sponsor + Uma.

**Wave M5.9 — Ship polish + deploy.** Performance audit (sustained 60fps target); accessibility (colorblind mode, key-rebind, subtitle option for audio cues); localization scaffolding (string externalization); itch.io page + screenshots + trailer + deploy; Steam playtest application; final M5 soak + Sponsor ship sign-off.

**Dependencies:**

- M5.1-M5.6 are independent; one wave in flight per ~3 calendar weeks.
- M5.7 depends on M5.1-M5.6 mob taxonomy + NPC roster being complete.
- M5.8 depends on all content surfaces existing; runs parallel to M5.7.
- M5.9 depends on all content authored.

**Calendar shape:**

- **18 weeks** content (6 strata × 3 weeks parallel).
- **2 weeks** bounty + dialogue extended (parallel).
- **2-3 weeks** narrative + lore pass (parallel-overlap).
- **3 weeks** ship polish + deploy.
- **Total M5:** ~5-6 calendar months part-time pace.

**Gate to ship:** Sponsor sign-off on M5 soak. Public itch.io deploy.

### Why this order over the alternatives

I considered four alternative orders and rejected each:

**Alt 1 — Mechanical systems (M4 work) before vertical-slice fidelity.** Rejected per Sponsor's "vertical slice first at full polish + system depth" framing + the visible-progress lever logic. Multi-character + currency without art + dialogue + map = invisible progress.

**Alt 2 — All 8 strata authored before locking the Diablo-shape pattern.** Rejected per the system-shape-iteration vs content-fill split — iterating the dialogue UX shape across S1-S8 content already authored is the indie-killer.

**Alt 3 — Hub-town before character art.** Rejected because hub-town with placeholder NPC squares is strictly worse than hub-town with PixelLab NPCs (visible-progress per `m3-design-seeds.md §4`). Sub-track 5a precedes Sub-track 5b in M3 Tier 3.

**Alt 4 — Dialogue + world-map UI deferred to M5 polish.** Rejected per Sponsor's "talk to npcs, explore the levels to solve quests, see the world on a map" framing — those are first-class Sponsor-stated commitments, not polish. They land in M3 Tier 3.

---

## §4 — Ticket pre-shape (per milestone)

**Not creating tickets yet** — Sponsor signs §6 first. Pre-shape only, ownership + counts. Counts are rough — actual dispatch waves will refine. Tickets follow established M3 Tier 2 wave naming (`M3-T3-W1-T1`, etc.).

### M3 Tier 3 ticket pre-shape

| Wave | Tickets | Ownership | Count | Notes |
|---|---|---|---|---|
| W1 | Camera-scroll spike + `CameraDirector` follow-scroll API extension | Devon | 1 | Gated on §6 SI-1 |
| W1 | Dialogue system spike: `DialogueTreeDef` schema + `DialogueController` autoload + `DialoguePanel.tscn` modal UI | Devon | 2 (schema + UI as separable PRs) | Gated on §6 SI-2 |
| W1 | Zone schema spike: `ZoneDef` extension to `level-chunks.md` | Drew | 1 | Gated on §6 SI-2 |
| W1 | World-map UI direction (visual style — parchment-overlay vs screen-space UI) | Uma | 1 | Gated on §6 SI-3 |
| W1 | M3 Tier 3 acceptance plan scaffold | Tess | 1 | Mirrors `m3-acceptance-plan-tier-1.md` |
| W1 | Sponsor PixelLab batch wave 1: Player + Grunt + Charger + Shooter | Sponsor + Drew (integration) | 4 sprite PRs | Mob-by-mob ship |
| W2 | Camera-scroll impl + S1 light retrofit | Drew + Devon | 2-3 | Depends on W1 spike |
| W2 | Dialogue system impl + first 3 dialogue trees (hub-town NPCs) | Devon + Drew | 2 (system + content) | Depends on W1 dialogue spike |
| W2 | World-map UI minimal (stratum-list + zone-list at descent-portal) | Devon | 1 | Depends on W1 zone schema + map UI direction |
| W2 | Sponsor PixelLab batch wave 2: Stoker + Boss + PracticeDummy + 3 hub-town NPCs | Sponsor + Drew | 6 sprite PRs | Continues mob-by-mob |
| W3 | `HubTown.tscn` scene authoring (with real PixelLab NPC sprites + dialogue trees wired) | Drew | 1 | Depends on W2 dialogue + Sub-track 5a |
| W3 | Hub-town save-state hook + scene-routing | Devon | 1 | Additive to v4 |
| W3 | S2 zone authoring + S2 rooms (3-4 zones, 8 rooms, against camera-scroll shape) | Drew | 2-3 | Depends on W1 zone schema + W2 camera-scroll |
| W3 | S2 new mob archetypes (~2) | Sponsor PixelLab + Drew | 4 PRs | Sponsor input on mob shapes pending §6 SI-4 |
| W3 | S1 + S2 stratum NPCs (~3 total) + dialogue trees | Sponsor PixelLab + Drew + Devon | 4-5 PRs | |
| W4 | Exploration quest authoring (3-5 quests across S1+S2) | Drew + Uma + Sponsor | 3-5 PRs | Depends on zone schema + dialogue system |
| W4 | S2 boss room + boss polish (mini-Tier-2 wave for S2) | Mirrors Tier 2 wave plan | 6-10 PRs | Smaller scope; surface from Tier 2 already built |
| W4 | Architectural doc updates (`visual-direction.md` § Camera + `level-chunks.md` § Why chunks + new `.claude/docs/camera-scroll.md` + new `.claude/docs/dialogue-system.md`) | Uma + Drew + Devon + Priya | 4 PRs | Priya batches |
| W4 | Tess M3 Tier 3 acceptance + per-track QA omnibus | Tess | 3-4 | |

**Total M3 Tier 3 tickets:** ~45 across 4 waves. Significant inflation vs original 25 due to dialogue system + zone schema + world-map UI + per-stratum NPCs + exploration quests + S2 content + S2 boss polish all being in scope. Honest count.

### M4 ticket pre-shape

| Wave | Tickets | Ownership | Count | Notes |
|---|---|---|---|---|
| W1 | Save-schema v5 impl + migration tests | Devon | 1-2 | |
| W2 | `TitleScreen.tscn` multi-char slot-picker impl | Drew | 1 | Spec from Tier 1 |
| W2 | Ember-shard currency + Paragon points | Devon + Drew | 3 | |
| W2 | Vendor + anvil + bounty-poster economy wiring | Devon + Drew | 3 | |
| W3 | Bounty quest roster fill (additional ~3-5 quests) | Drew + Uma + Sponsor | 3-5 | |
| W3 | Dialogue content fill (extend trees to full state-branching) | Drew + Uma | 3-4 | |
| W3 | World-map UI expansion (per-zone room-tree + waypoint travel + discovered-zone indicators) | Devon | 2 | |
| W4 | M4 Tess QA omnibus + Sponsor soak | Tess | 3-4 | |

**Total M4 tickets:** ~20-25 across 4 waves. Lighter than M3 Tier 3.

### M5 ticket pre-shape (per stratum wave + closing waves)

Each stratum wave (M5.1 through M5.6) shapes (~3 weeks):

| Wave subset | Tickets | Ownership | Count |
|---|---|---|---|
| Per-stratum direction | Stratum palette + visual + audio direction | Uma | 3 |
| Per-stratum content | 2-3 named zones + ~8 rooms + 1-2 new mobs + 1-3 NPCs + 1 boss | Drew + Sponsor PixelLab + Devon + Uma | 15-20 |
| Per-stratum QA | Tess acceptance + Sponsor soak | Tess | 2-3 |

**~20-26 tickets per stratum × 6 strata = ~120-160 tickets across M5.1-M5.6.**

Plus closing waves:
- **M5.7** Bounty content fill — ~5-8 tickets.
- **M5.8** Narrative + lore pass — ~5-7 tickets.
- **M5.9** Ship polish — ~10-15 tickets.

**Total M5 tickets:** ~150-190. Honest middle ~170; under-estimated by ~20-30% per `bandaid-retirement-scope-blowup` memory.

---

## §5 — Dependency / sequencing graph

```
                  M3 Tier 2 Wave 3 close (~5-7 calendar days from now)
                                  │
                                  ▼
          ┌──────────────── M3 Tier 3 — Diablo-shape vertical slice ──────────────────┐
          │ Track 1: Camera-scroll + level-scale rework                                │
          │ Track 2: Dialogue system (modal UI + tree schema + content)                │
          │ Track 3: Zone schema + exploration quest content                           │
          │ Track 4: World-map UI minimal                                              │
          │ Track 5: S1 art-pass + hub-town + S2 content + S2 boss + stratum NPCs      │
          │ ~6-8 calendar weeks parallel-dispatched                                    │
          └────────────────────────────────────────────────────────────────────────────┘
                                  │
                          Sponsor soak gate (the vertical-slice gate)
                                  │
                                  ▼
          ┌──────────────────── M4 — Scale systems + content fill ────────────────────┐
          │ Track 1: Save-schema v5 impl + multi-character UI                          │
          │ Track 2: Persistent meta (ember-shard currency + Paragon)                  │
          │ Track 3: Bounty + dialogue content fill                                    │
          │ Track 4: World-map UI expansion                                            │
          │ ~4-5 calendar weeks parallel                                               │
          └────────────────────────────────────────────────────────────────────────────┘
                                  │
                          Sponsor soak gate
                                  │
                                  ▼
          ┌────────────────── M5 — S3-S8 stratum-by-stratum + ship ─────────────────────┐
          │ M5.1 → M5.6: One stratum per ~3-week wave (S3-S8 against locked pattern)    │
          │ M5.7: Bounty + exploration quest content extended (~2 weeks)                │
          │ M5.8: Narrative + lore pass (~2-3 weeks parallel)                           │
          │ M5.9: Ship polish + itch.io deploy (~3 weeks)                               │
          │ Total: ~5-6 calendar months                                                  │
          └─────────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
                       Sponsor ship sign-off
                                  ▼
                              ITCH.IO PUBLIC
```

**Critical-path dependencies:**

1. **§6 SI-1 through SI-4 (camera shape + dialogue scope + map shape + S2 mob shapes)** gate M3 Tier 3 W1 dispatch.
2. **M3 Tier 3 close** is the vertical-slice gate — Sponsor sign-off on the Diablo-shape pattern is the load-bearing project-level decision. If Sponsor finds the pattern wrong at this gate, M4/M5 re-scope; that's why vertical-slice-first is the pro-team move.
3. **M4 v5 schema** gates M4 multi-character + currency expansion (consumes v5 fields).
4. **M5.1 per-stratum direction** gates M5.1 content authoring (Drew can't author against absent palette).

**Total calendar from now to ship:** ~10-14 months honest middle. Was 8-10 months pre-Diablo-lock; absorption of dialogue system + zone schema + world-map UI + per-stratum NPCs adds ~2-4 calendar months across M3 Tier 3 + M4 + M5. **Sponsor should plan against the 14-month shape; team ships as fast as quality holds.**

---

## §6 — Sponsor-input items (gated milestones)

Seven items gate dispatch past Wave 3. **Recommended-call shape per `sponsor-decision-delegation` memory.**

### Pre-M3-Tier-3 W1 (must decide before W1 spike dispatches)

1. **§6 SI-1 — Camera-scroll shape: continuous-scroll (default A) confirmed?** Per §1 Commitment 1, Sponsor's 2026-05-22 signal effectively picked (a). This SI is the formal Sponsor confirmation that the team should proceed with (a) and drop (b)/(c). **Recommended:** confirm (a). **Lockable by:** end of Tier 2 Wave 3.

2. **§6 SI-2 — Dialogue system scope: full state-branching (default) vs simple modal text (no branching) vs no system in M3 Tier 3 (defer to M4)?** Per §1 Commitment 2, the recommended shape is full state-branching (pre-quest / active / completed / failed branches). Simple modal text is the slip-floor; no system in M3 Tier 3 contradicts the Sponsor signal. **Recommended:** full state-branching. **Lockable by:** end of Tier 2 Wave 3.

3. **§6 SI-3 — World-map UI shape: (a) Diablo-II per-act map / (b) Diablo-IV persistent overworld / (c) Crystal-Project room-tree.** Per §1 Commitment 4, each has very different scope. **Recommended:** (a) Diablo-II per-act map. Reasoning: cheapest to author (no global overworld asset); matches Sponsor's "areas in strata" framing directly; scales naturally to 8 strata without per-stratum-art-burden inflation; the embryo is already in `hub-town-direction.md §4` descent-portal stratum-picker. (b) is more ambitious (overworld authoring is a significant Uma direction + art-pass cost across 8 strata); (c) is cheap but doesn't match Sponsor's "see the world on a map" framing. **Lockable by:** end of Tier 2 Wave 3.

4. **§6 SI-4 — S2 mob archetypes: 2 new (recommended) / 3 new / 1 new + 1 retint?** Per `mvp-scope.md §M3` "12 mob archetypes total" + M3 Tier 3 vertical-slice scope. **Recommended:** 2 new archetypes (Sunken-Scholar ranged + Bone-Catalyst melee — shapes only, mechanical details + names confirmed at content authoring time). **Lockable by:** end of Tier 3 W1.

5. **§6 SI-5 — Per-stratum NPC count in M3 Tier 3: 1 in S1 + 2 in S2 (default, total 3) / fewer / more?** Per §1 Commitment 2, dialogue system needs first-content consumers; 3 stratum NPCs (on top of 3 hub-town NPCs = 6 total dialogue trees in M3 Tier 3) is the recommended content baseline. **Recommended:** 3 stratum NPCs in M3 Tier 3. **Lockable by:** end of Tier 3 W1.

### Pre-M4 (must decide before M4 W2 content fill dispatch)

6. **§6 SI-6 — Multi-character slot count.** Per `m3-design-seeds.md §1.1`: 3 (default) / 1 / 6+. **Recommended:** 3. **Lockable by:** M4 W1.

### Pre-M5 (must decide before M5.1 dispatch)

7. **§6 SI-7 — M5 stratum order:** sequential per `game-concept.md` table (default) / Sponsor-prioritized order / fastest-to-author first? **Recommended:** sequential. **Lockable by:** end of M4 close.

### Cross-milestone (deferrable but flag)

- **§6 SI-Δ-1 — NG+ Paragon track shape.** Per `m3-design-seeds.md §3.7`: ship Paragon per `mvp-scope.md §M3` (default) / swap for alternative cap. **Recommended:** ship Paragon. **Lockable by:** M4 W2.
- **§6 SI-Δ-2 — Ship target.** itch.io only (default) / itch.io + Steam playtest concurrent. **Recommended:** itch.io first + Steam playtest application concurrent with itch.io public deploy. **Lockable by:** M5.9.
- **§6 SI-Δ-3 — Per-stratum NPC density in M5.** 1-3 per stratum (M3 Tier 3 baseline) / consistent 3 per stratum / variable per stratum tone. **Recommended:** 1-3 per stratum tuned to tone (S5 Bone Market populated, S7 Ember Vein sparse). **Lockable by:** M5.1.

---

## §7 — Risk register snapshot (shifts under this sequencing)

Eight material shifts to `team/priya-pl/risk-register.md` if the team adopts this sequencing. Update lands in next Priya weekly batch.

### Risks NEW (escalated to top-5)

- **R-SCROLL — Camera-scroll + level-scale rework HTML5 regression.** **Probability:** med. **Impact:** high. **Why:** `gl_compatibility` has been a historical sharp edge per `.claude/docs/html5-export.md`. Scroll-rendering across multi-chunk tilemaps surfaces a new regression class — tilemap seam z-index, follow-clamp edge behavior, HUD-immunity-during-scroll. **Mitigation:** §6 SI-1 sets the shape; W1 spike is investigation-first per `diagnostic-traces-before-hypothesized-fixes` memory; fallback option (b) edge-pan remains documented even though it's been dropped from the recommendation. **Trigger:** Tier 3 W1 spike output flags HTML5 scroll regression. **Owner:** Devon (spike), Drew (impl), Tess (HTML5 visual-verification gate).

- **R-DIALOGUE — Dialogue system net-new authoring risk.** **Probability:** med. **Impact:** med-high. **Why:** the dialogue system is the project's first net-new UI system in M3 Tier 3 (Tier 2 polished existing surfaces; Tier 3 builds new). Risks: schema design surfaces requirements late (state-branching shape requires content to validate); modal UI input + state handling has HTML5 input-event quirks (per `.claude/docs/html5-export.md` § "Godot input handling order"); per-NPC dialogue trees inflate authoring cost beyond §3 estimate. **Mitigation:** dialogue system spike (Track 2 W1) authors `.tres` schema + first 3 trees as proof of pattern BEFORE the modal UI hardens; iterate; cap M3 Tier 3 dialogue trees at 6 (3 hub-town + 3 stratum NPCs); defer dialogue content fill to M4 W3. **Trigger:** schema requires revision after first 3 trees authored. **Owner:** Devon (system), Drew + Uma (content).

- **R-MAP — World-map UI design risk.** **Probability:** med-low. **Impact:** med. **Why:** map UI is screen-space and HUD-immune (low HTML5 regression risk) but the visual design + zone-discovery state + waypoint travel UX is a Sponsor-facing surface with subjective-feel calls. §6 SI-3 sets the shape; risk is that the chosen shape (a/b/c) feels wrong post-impl. **Mitigation:** §6 SI-3 sign-off → Uma direction doc → minimal-shape impl in M3 Tier 3 → Sponsor soak gate. If wrong, course-correct in M4 W3 expansion ticket. **Trigger:** Sponsor soak on M3 Tier 3 surfaces map UX redirect. **Owner:** Uma (direction), Devon (impl).

- **R-ART — PixelLab + Aseprite Sponsor-capacity bottleneck.** **Probability:** med-high. **Impact:** med. **Why:** Sponsor labor per `art-pass-ai-primary-brief.md` is the M3 Tier 3 + M5 critical path. ~22-31 hr Phase 1 (S1 only) × ~5 stratum retints + new mobs in M5 = ~110-155 hr total Sponsor labor; multi-month part-time pace; subject to real-life calendar slip. **Mitigation:** hex-block fallback per `m3-design-seeds.md §4 Risks` (placeholder Sprite2Ds remain mechanically complete); Sponsor-capacity check at each milestone gate. **Trigger:** Sponsor signal of art-capacity-strain at any M3 Tier 3 wave or M5 stratum wave. **Owner:** Sponsor (executor), Priya (sentinel), Drew (integration cadence).

### Risks DEMOTED

- **R6 (Sponsor-found-bugs flood)** — currently top-5 active. M3 Tier 3 Diablo-shape vertical slice closes the "the game looks placeholder" Sponsor-soak class. **Demote to:** held but off top-5 once M3 Tier 3 closes. Re-escalate if M3 Tier 3 soak surfaces ≥3 P0-class findings.

- **R-AC4 (AC4 whack-a-mole)** — currently top-5. AC4 cluster is M2 RC residual; not active in M3 Tier 2 + Tier 3 + M4. **Demote to:** retired pending M5 content waves. Re-arm at M5.1 dispatch.

### Risks HELD

- **R1 (Save migration breakage)** — v5 lands in M4 W1; high-impact + med-probability. Mitigation: Devon's spike + paired migration test suite.

- **R8 (Stash UI complexity)** — held. M3 Tier 3 hub-town + M4 multi-character stash lift ride atop existing stash-UI v4 surface.

### Risks RETIRED

- **R-M3 (M3 shape undecided)** — closed; Sponsor picked Shape A 2026-05-17 + Diablo-shape lock 2026-05-22.

### New risk: R-SCOPE (this doc's adoption)

- **R-SCOPE — Sequencing-doc adoption risk.** **Probability:** low. **Impact:** high. **Why:** Sponsor signed §1 directives same-day; if Sponsor disagrees with the M3 Tier 3 milestone shape (5-track / 6-8 week / vertical-slice-first), course-correction cost is ~1-2 weeks dispatch rework. **Mitigation:** doc is design-only until Sponsor signs §6 items; per `sponsor-decision-delegation` Sponsor sign-off is the gate. **Trigger:** Sponsor reads doc + signs §6 (closes) OR redirects substantially (re-author v1.1 amendment). **Owner:** Priya (steward), orchestrator (route Sponsor escalation at PR merge).

---

## §8 — Cross-references

- **`team/priya-pl/game-concept.md`** (v1 FROZEN 2026-05-02) — Diablo-lite is in the reference set; Sponsor's 2026-05-22 lock resolves the mixed reference toward Diablo branch.
- **`team/priya-pl/mvp-scope.md` §M3** — original M3 paragraph; this doc splits across M3 Tier 3 + M4 + M5.
- **`team/uma-ux/visual-direction.md`** § "Internal canvas + scaling rules" + § "Camera" + § "Stratum visual progression" — current locks; §1 plans the camera amendment.
- **`team/priya-pl/m3-design-seeds.md`** — four-axes Shape A decomposition; this doc commits to the parallel-track milestone shape.
- **`team/priya-pl/m3-tier-1-plan.md`** — Tier 1 closed.
- **`team/priya-pl/m3-tier2-boss-room-polish-scope.md`** — Tier 2 wave plan; Wave 3 in flight.
- **`team/uma-ux/hub-town-direction.md`** — hub-town direction; M3 Tier 3 Sub-track 5b implements; descent-portal embryo for world-map UI.
- **`team/priya-pl/art-pass-ai-primary-brief.md`** — Sponsor-DIY PixelLab pipeline.
- **`team/drew-dev/level-chunks.md`** § "Why chunks" — schema pre-shaped for `assemble_floor` multi-chunk stitching; §1 Commitment 1 + 3 plan the runtime + zone extensions.
- **`team/uma-ux/palette.md`** + **`team/uma-ux/palette-stratum-2.md`** — palette doctrine.
- **`team/uma-ux/audio-direction.md`** — audio doctrine.
- **`.claude/docs/orchestration-overview.md`** — team topology + dispatch conventions.
- **`.claude/docs/html5-export.md`** — visual-verification gate; scroll-rendering is the new HTML5 risk surface.
- **`.claude/docs/pixellab-pipeline.md`** + **`.claude/docs/pixel-mcp-pipeline.md`** — PixelLab + pixel-mcp execution rules.
- **`team/priya-pl/risk-register.md`** — pre-§7 baseline; §7 plans the shifts.
- **`team/DECISIONS.md`** — Sponsor sign-off on §6 items lands as `Decision draft:` lines in Priya's next weekly batch.

**Future docs (planned to land alongside their implementing PRs):**

- `team/uma-ux/dialogue-direction.md` — Uma direction on dialogue tone + state-branching conventions + modal visual style.
- `team/uma-ux/world-map-direction.md` — Uma direction on map visual style (per §6 SI-3 sign-off).
- `team/drew-dev/zone-schema.md` — Drew schema extension to `level-chunks.md` for the zone layer.
- `.claude/docs/camera-scroll.md` — HTML5-specific scroll quirks captured post-Tier-3 spike.
- `.claude/docs/dialogue-system.md` — dialogue tree engine + modal UI architecture post-Tier-3 system landing.

---

## Caveat — sequencing plan, not sequencing lock

This doc is a **recommendation grounded in two Sponsor 2026-05-22 signals (level-scale + Diablo-shape lock)**. Sponsor signs §6 items or redirects. If Sponsor diverges substantially (e.g. dialogue system in M4 instead of M3 Tier 3, or world-map UI in M5 polish), the §3 milestone shape revises in a v1.1 amendment + DECISIONS.md entry.

**The opinionated calls in this doc:**

1. M3 Tier 3 becomes "Diablo-shape vertical slice" (5 tracks; 6-8 weeks) rather than the original "S1 art-pass + hub-town" (3-4 weeks) — per the §2 vertical-slice-first reasoning.
2. Dialogue system + zone schema + world-map UI all land in M3 Tier 3 — per §1 commitments 2/3/4 being first-class.
3. S2 ships in M3 Tier 3 (vertical slice = S1+S2), not M4 — per the vertical-slice-pattern-validation logic.
4. M4 is mechanical depth + content fill (no new strata) — per the "M4/M5 scale once pattern dialed" framing.
5. M5 is S3-S8 grind + ship — long-haul content authoring against locked pattern.

Any of these is reversible if Sponsor redirects; the sequencing risk per R-SCOPE is the explicit gate. **No M3 Tier 3 dispatch starts before Sponsor signs §6.**

---

## Hand-off

- **Sponsor:** the seven §6 items above. Recommended action: sign off (or redirect) the seven items; orchestrator routes M3 Tier 3 W1 dispatch after sign-off.
- **Priya (me):** absorb Sponsor sign-off; revise v1.1 if redirects land; file M3 Tier 3 backlog tickets per §4 ticket pre-shape; add `Decision draft:` lines for §6 sign-offs in next Monday batch.
- **Devon:** future M3 Tier 3 W1 camera-scroll spike + dialogue system spike. No action now; gated on §6 SI-1 + SI-2 sign-off.
- **Drew:** future M3 Tier 3 W1 zone schema spike + content authoring + PixelLab integration cadence. No action now.
- **Uma:** future M3 Tier 3 W1 world-map UI direction + dialogue tone direction. No action now; gated on §6 SI-3 sign-off.
- **Tess:** future M3 Tier 3 acceptance plan scaffold + per-track QA. No action now.

---

## Non-obvious findings

1. **Sponsor's two 2026-05-22 signals stack into a single architectural directive.** Level-scale (continuous-scroll) + Diablo-shape (NPCs + quests + map) are not independent; they're the same gestalt (the player walks through a place, talks to people in it, picks up tasks from those people, sees the place on a map). The doc honors that by folding them into §1 as four commitments rather than two separate sections.
2. **Dialogue system is the most-under-estimated cost in the plan.** Net-new UI system + per-NPC state-branching + content authoring + HTML5 modal-input edge cases combine to ~3-4 calendar weeks of M3 Tier 3 work. Easy to under-estimate at "Devon authors a modal panel"; the content fill + state-branching design + Sponsor-tone-review iteration is where the time goes. R-DIALOGUE captures this.
3. **The vertical-slice-first principle is what makes the plan ship-shaped.** Sponsor explicitly framed it; the doc honors it. Without the vertical-slice gate, the team risks 6 strata of content authored against an unproven Diablo-shape pattern and then re-doing it. With the gate, the pattern proves at S1+S2 and S3-S8 inherit a known-working shape.
4. **S2 lifts from M4 to M3 Tier 3 because of the vertical-slice principle.** Without Diablo-shape, S2 could ship in M4 as mechanical-depth content alongside multi-character. With Diablo-shape, S2 must ship in M3 Tier 3 to prove the multi-stratum exploration + zone schema + map UI work. This is the single biggest shift from the pre-Diablo-lock plan.
5. **Total calendar grows from ~8-10 months to ~10-14 months.** Sponsor's Diablo-shape lock is worth the additional 2-4 months because it converts "Crystal-Project-density 8-stratum game" into "Diablo-shape 8-stratum game" — substantially different commercial proposition. Honest about the cost; honest about the value.
6. **The world-map UI embryo already exists** in `hub-town-direction.md §4` (descent-portal stratum-picker). M3 Tier 3 expands the embryo into the minimal map; M4 expands to full pane structure. This is the cheapest of the four §1 commitments because the data + UI surface are partially in place.
