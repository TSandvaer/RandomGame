# M3 Tier 1 Plan — Shape A (Content Track) First-Wave Breakdown

**Owner:** Priya · **Authored:** 2026-05-17 (Sponsor picked Shape A on 2026-05-17; this doc is the Tier 1 breakdown) · **Driver ticket:** `86c9ur5aq` (M3 shape exploration, now `in progress` post-pick) · **Source of truth for Sponsor decision:** `team/priya-pl/m3-shape-options.md` (Shape A — content track, default + recommended).

This doc breaks Shape A into **sub-milestones** with sequencing, dependencies, and **first-wave dispatch-ready tickets** so the team can start M3 Tier 1 work immediately. It is **NOT a redo of `m3-design-seeds.md`** — that doc details Shape A's content (15 Sponsor-input items across four tracks). This doc does the **sequencing math** and produces the **first 5 tickets** orchestrator dispatches.

## TL;DR

1. **Tier 1 = 4 sub-milestones**, mirroring Shape A's four tracks: §1 Persistent-meta + save-schema v5 spike; §2 Hub-town visual direction; §3 Character-art pass external estimate; §4 Multi-character UI scaffolding.
2. **Two spikes go first** — §1 (Devon-led persistent-meta save-schema v5 spike) and §3 (Sponsor-routed external-estimate commission for character-art) — because both gate downstream work and both have non-trivial lead times.
3. **First wave = 5 tickets**: §1-T1 (Devon save-schema v5 spike), §2-T1 (Uma hub-town visual direction), §3-T1 (Sponsor-routed external-estimate brief — Priya-authored, Sponsor-executed), §4-T1 (Drew multi-character title-screen mock + slot-picker spec), §QA-T1 (Tess M3 acceptance plan scaffold).
4. **One Sponsor-input item recommended for escalation up-front:** §3 art-pass external estimate has a **~2-3 week lead time** on artist quotes; Sponsor should be asked to greenlight the brief NOW (parallel to Tier 1 dev work) so estimates land before §3 implementation needs to start.
5. **All other Sponsor-input items from `m3-design-seeds.md` (15 items)** carry to M3 W2/W3 timing — they don't block first-wave dispatch.

---

## Source of truth

This plan extends:

- **`team/priya-pl/m3-shape-options.md`** — Shape A locked by Sponsor 2026-05-17 ("Shape A sounds great").
- **`team/priya-pl/m3-design-seeds.md`** — Shape A's four-track elaboration with 15 Sponsor-input items (6 big-shape + 9 smaller defaults).
- **`team/priya-pl/mvp-scope.md` §M3** — v1-frozen content-track paragraph (canonical scope contract).
- **`team/devon-dev/save-schema-v4-plan.md` §4.1** — v4 additive-only rule that v5 will be the first to violate (§1 multi-character is a non-additive type-change).
- **`team/priya-pl/risk-register.md`** R-M3 — risk entry activates the moment M2 RC ships.
- **`.claude/docs/orchestration-overview.md`** — team topology + per-role dispatch conventions.
- **AC4 cluster status** — Tier 1 work is **independent surface from AC4 closure**; M3 dispatches can run in parallel to Drew's Room 03/05/06/07 work without conflict.

---

## Tier 1 sub-milestone shape

Shape A has **four parallel tracks** (per `m3-design-seeds.md §4 Milestone shape — recommend "parallel track in M3"`). Tier 1 (first wave) seeds all four tracks with foundation work that **doesn't depend on Sponsor-input items being locked yet** — the 15 design-seed Sponsor-input items decide M3 W2+ ticket shape, not M3 W1 foundation.

### Sub-milestone §1 — Persistent-meta + save-schema v5 spike (Devon-led, engine lane)

**Why first:** v5 is the **first non-additive save-schema bump** (per `save-schema-v4-plan.md §4.1` rule 1 — `data.character` → `data.characters[]` is a type-change + rename). Devon needs an architectural spike PR **before** any feature ticket consumes v5: the spike defines the migration contract, the `characters[]` array shape, the `active_slot` semantic, the `shared_stash` lift, and the v4→v5 migration test contract. **Without the spike, every multi-character / persistent-meta feature ticket would re-invent the schema.** Spike-first is the pattern from `save-schema-v4-plan.md` (v4 had its own pre-spike before W1-T1).

**Scope:** Devon authors `team/devon-dev/save-schema-v5-plan.md` (mirror `save-schema-v4-plan.md` shape — sections: schema diff vs v4, migration steps, additive vs non-additive call-outs, round-trip invariants, fixture catalog, HTML5 OPFS implications). No engine code yet; this is design + plan only. Implementation lands in subsequent tickets that consume the plan.

**Dependencies:** None. Pure architectural spike. Reads `save-schema-v4-plan.md` + `m3-design-seeds.md §1 + §3` + current v4 fixtures.

**Sequencing:** **Foundation — must land before §1 implementation tickets** (multi-character slot UI, hub-town save state, ember-shard currency wiring, Paragon points). Estimated 2-4 ticks; produces a doc PR.

**Sponsor-input items needed at spike-time:** ONE — the v5 migration shadow question (`m3-design-seeds.md §1` Devon-call: should v5 keep `data.character` as a compat shadow for one schema generation OR fully remove?). Recommended in the design seeds is pointer-shadow for one generation then delete at v6. **Devon's call within his lane** — no Sponsor escalation needed.

### Sub-milestone §2 — Hub-town visual direction (Uma-led, UX lane)

**Why first:** Hub-town is the **between-runs venue** that anchors Shape A's player experience. Uma needs to author the visual-direction doc (mirror of `team/uma-ux/visual-direction.md` shape, scoped to hub-town) **before** Drew can author the hub-town scene (single-screen layout, 3 NPC placements, anvil + vendor stall + bounty-board props, descent portal). Uma's direction also determines whether hub-town reuses S1 Outer Cloister tiles (recommended default per `m3-design-seeds.md §2.6`) or commissions new biome tiles (rejected default).

**Scope:** Uma authors `team/uma-ux/hub-town-direction.md` — visual layout (single-screen 480×270 internal), tile-reuse strategy (Outer Cloister evolution per `m3-design-seeds.md §2.6` default), 3 NPC placement coordinates with personality framing (vendor / anvil / bounty-poster — recommended names + visual descriptors), descent-portal positioning, ambient-music + ambient-lighting recommendation, B-key + Tab + Esc behaviors.

**Dependencies:** None for first draft. Reads `m3-design-seeds.md §2` + `palette.md` (S1 Outer Cloister authoritative) + `stash-ui-v1.md` (M2 stash-room pattern this evolves from) + `visual-direction.md` (480×270 canvas + zero-scrolling rule).

**Sequencing:** **Foundation — must land before §2 implementation tickets** (Drew authors `HubTown.tscn` + NPC scenes; Devon wires `meta.hub_town_seen` save state). Estimated 3-5 ticks; produces a doc PR (mirror W2-T11 audio-direction doc shape).

**Sponsor-input items needed at direction-time:** ZERO at first-draft. Uma authors against the `m3-design-seeds.md §2` defaults (single-screen, 3 NPCs, Outer Cloister evolution). The 3 §2 Sponsor-input items (hub-town size, NPC count, visual approach) become **review-the-direction-doc** items when the doc lands — not pre-authoring gates.

### Sub-milestone §3 — Character-art pass external estimate (Sponsor-routed, Priya-supported)

**Why first:** Per `m3-design-seeds.md §4` cost-bracket section, character-art pass cost is **not defensibly internally-estimable** — Sponsor must commission 2-3 external pixel-art artist quotes. **Lead-time on a 3-artist estimate is ~2-3 weeks** assuming standard reply cadences. **If we wait for M3 W2 to start the estimate, the quotes don't land until M3 W4-W5** — and by then §1+§2+§4 tracks have shipped a vertical slice and §3 art-pass is the bottleneck. **Start the estimate clock NOW** during Tier 1.

**Scope:** Priya authors the artist-brief doc (`team/priya-pl/art-pass-commission-brief.md` — to be drafted in §3-T1 below), Sponsor commissions the estimates. Brief includes: top-down ARPG framing, ~32-pixel character sprites, palette locked to `palette.md` hex codes, anim states per mob (idle 4f / walk 8f / attack-telegraph 4f / attack 6f / hit-react 3f / die 8f, 4-directional cardinal), mob roster (6 archetypes — Grunt / Charger / Shooter / PracticeDummy / Stoker / Stratum1Boss; Stoker is a retint of Grunt), Player + 3 hub-town NPCs + pickup/chest/ember-bag retint pass, per-stratum retint variants (S1-S8 at +10-20% per stratum), Aseprite-compatible source files, timeline 8-16 weeks segment-able by stratum.

**Dependencies:** None for the brief authoring. Reads `m3-design-seeds.md §4` + `palette.md` + `palette-stratum-2.md` + `.claude/docs/combat-architecture.md` § "Mob hit-flash" (integration surface artists must preserve).

**Sequencing:** **Brief authoring is M3 Tier 1 (this wave). Sponsor commissioning is parallel to ALL of M3 Tier 1 + Tier 2 dev work.** Estimates land mid-M3; locked artist + cost-bracket is the dispatch-gating moment for §3 implementation. **No M3 dev work blocks on estimate landing** — the hex-block fallback per `m3-design-seeds.md §4 Risks` is the safety net.

**Sponsor-input items needed at brief-time:** TWO from `m3-design-seeds.md §4` — §4.10 (primary style: 32-bit pixel-art commissioned — recommended default) and §4.11 (external estimate go-ahead). **Both are Sponsor-must-decide before brief sends to artists.** The brief draft can be authored without these decisions; sending it requires them.

### Sub-milestone §4 — Multi-character UI scaffolding (Drew-led, content lane)

**Why first:** Multi-character (per `m3-design-seeds.md §1`) is the **most player-visible M3 feature** — title-screen slot picker is the first thing the player sees when launching M3. Drew can author the **title-screen mock + slot-picker spec** in parallel to §1 (Devon's v5 spike) **without** depending on v5 landing. The mock is a `team/drew-dev/title-screen-slot-picker.md` spec + a wireframe of the title-screen states (no characters → "New Game" only; ≥1 character → "Continue" + "New Game" + per-slot status). Implementation in M3 W2+ ticket consumes both the spec (Drew) and v5 schema (Devon).

**Scope:** Drew authors `team/drew-dev/title-screen-slot-picker.md` — title-screen state diagram (no-characters / 1-character / 2-character / 3-character full / mid-game-load), slot-picker UI shape (3 slot rows with name + level + stratum + last-played-relative-time + delete-confirm), New Game flow (slot picker → character name input → confirm → load into hub-town), Continue flow (slot picker → confirm → load into wherever character was saved). Wireframe sketches (text-art or Aseprite mock) for each state.

**Dependencies:** None for the spec. Reads `m3-design-seeds.md §1` + existing title-screen scene (`scenes/TitleScreen.tscn` if it exists; else flag as new authoring). Coordinates with §1 (v5 schema for slot data shape).

**Sequencing:** **Foundation — must land before §4 implementation tickets** (Drew authors `TitleScreen.tscn` slot-picker; Devon wires v5 `active_slot` semantics). Estimated 2-4 ticks; produces a doc PR.

**Sponsor-input items needed at spec-time:** ONE from `m3-design-seeds.md §1.1` — slot count (default 3, alternatives 1 or 6+). **Defer to Sponsor at design-review time, NOT at spec authoring** — Drew specs the 3-slot default per `m3-design-seeds.md` recommendation; Sponsor redirects in design review if they want different count.

### Sub-milestone §QA — M3 acceptance plan scaffold (Tess-led, QA lane)

**Why first:** Tess's acceptance plan pattern (per `team/tess-qa/m2-acceptance-plan-week-3.md`) is **scaffold-from-day-1** — Tess authors the M3 acceptance-plan structure with placeholder rows for each Tier 1 sub-milestone, then fills rows as feature tickets dispatch. This parallels Tess's M2 W2-T10 omnibus pattern — runs alongside dev work, absorbing acceptance criteria as features land.

**Scope:** Tess authors `team/tess-qa/m3-acceptance-plan-tier-1.md` — placeholder rows for §1 (save v5 round-trip / migration test from v4 fixture / additive-vs-non-additive contract test), §2 (hub-town scene load / 3-NPC interactability / descent-portal stratum-selection), §3 (NO rows — external-estimate is Sponsor-routed, not engineering), §4 (title-screen slot-picker UI behavior / new-game flow / continue flow / 3-slot-full state). Each row: ID prefix + acceptance criterion + test surface (GUT / Playwright / Sponsor-probe).

**Dependencies:** None for scaffold. Reads `m2-acceptance-plan-week-3.md` for structure pattern + `m3-design-seeds.md` for feature surface + this doc for sub-milestone shape.

**Sequencing:** **Parallel to all Tier 1 dev tickets.** Acceptance rows lock as features dispatch — same pattern as M2 W3-T10 Half A. Estimated 2-3 ticks for scaffold; ongoing fill-in across Tier 1.

**Sponsor-input items needed at scaffold-time:** NONE.

---

## Dependency / sequencing graph

```
                          M2 W3 RC sign-off
                                  │
                                  ▼
                         ┌────────────────────┐
                         │  M3 TIER 1 KICKOFF │
                         └────────────────────┘
                                  │
        ┌─────────────────┬───────┴───────┬─────────────────┬─────────────────┐
        ▼                 ▼               ▼                 ▼                 ▼
   §1-T1 Devon       §2-T1 Uma       §3-T1 Priya       §4-T1 Drew       §QA-T1 Tess
   v5 schema spike   hub-town dir    art commission    title slot       M3 accept plan
   (doc only)        doc             brief doc         picker spec      scaffold doc
        │                 │               │                 │                 │
        │                 │               │                 │                 │
        │ Sponsor signs   │ Sponsor       │ Sponsor         │ Sponsor         │ (no Sponsor
        │ NOTHING (Devon  │ reviews       │ signs §4.10 +   │ confirms §1.1   │  block)
        │ -call shadow    │ direction;    │ §4.11; sends    │ slot-count at   │
        │ choice)         │ §2.4-6        │ brief to        │ design review   │
        │                 │ defaults OK   │ 2-3 artists     │ (3 default)     │
        │                 │               │ (2-3 wk lead)   │                 │
        ▼                 ▼               ▼                 ▼                 ▼
   §1-T2..N           §2-T2..N        (M3 W3+ when      §4-T2..N         (M3 ongoing)
   Devon impl         Drew authors    estimates land)   Drew impl + 
   (multi-character   HubTown.tscn    Sponsor picks     Devon wires v5
   v5 migration +     consuming       artist; §3 dev    active_slot
   shared_stash +     Uma's doc       work starts
   ember-shards +
   Paragon)
        │                 │                                 │
        └─────────┬───────┘                                 │
                  │                                         │
                  └─────────────────┬───────────────────────┘
                                    │
                                    ▼
                      M3 Tier 1 vertical slice
                      (multi-character + hub-town + meta basic;
                      art-pass deferred to estimate-land moment)
```

**Critical dependencies:**

1. **§1-T1 (v5 spike) must land before §1-T2..N (multi-character impl)** — v5 schema design is the engineering contract for slot data, shared stash, ember-shards, Paragon. Any §1 impl ticket dispatched before the spike lands re-invents the contract.
2. **§2-T1 (hub-town direction) must land before §2-T2..N (hub-town scene impl)** — Uma's direction tells Drew what to author. Drew authoring before direction lands is wasted work.
3. **§3-T1 (commission brief) must land before Sponsor sends to artists** — Sponsor needs the brief to send. Sponsor can read the doc as it lands; commission action is post-Sponsor-greenlight.
4. **§4-T1 (slot-picker spec) does NOT block on §1-T1** — spec is UI-shape work; v5 schema is data-shape work. They converge at §4-T2 (impl), not at spec-time. **Both can dispatch in parallel from day 1.**
5. **§QA-T1 (acceptance scaffold) does NOT block on any other Tier 1 ticket** — scaffold authors against the Shape A roadmap, fills rows as features land.

**Parallelism:** **All 5 first-wave tickets can dispatch on Day 1.** No inter-ticket dependencies in Tier 1. The parallelism matches Shape A's "parallel track in M3" recommendation per `m3-design-seeds.md §4 Milestone shape`.

---

## Tech-spike call-outs

Three tech-spikes are flagged for M3 Tier 1+2; one ships as the first wave (§1-T1 — save-schema v5). The other two are M3 W2-W3 timing.

### Spike S1 — Save-schema v5 (FIRST WAVE — §1-T1)

**What:** v4 → v5 migration with non-additive type-change (`data.character` → `data.characters[]`). First time the project violates the additive-only rule.

**Why a spike:** the migration shape decides every downstream M3 feature ticket's save-state code. Authoring features against an undefined v5 = rework cost when v5 finalizes. Spike-first = features consume the locked contract.

**Owner:** Devon. Lead author of `save-schema-v4-plan.md`; v5 is the natural extension.

**Output:** `team/devon-dev/save-schema-v5-plan.md` doc PR — schema diff, migration step pseudo-code, round-trip invariants, fixture catalog, HTML5 OPFS implications. No engine code; pure design.

### Spike S2 — Hub-town engine architecture (M3 W2 timing)

**What:** Hub-town is a **non-combat scene** (per `m3-design-seeds.md §2`) with `Engine.time_scale = 1.0`, no mobs, no hazards. Existing M2 stash-room is per-stratum; M3 hub-town is **persistent across run-attempts**. Engine question: does HubTown.tscn replace the per-stratum stash chamber as `meta.last_scene` OR coexist? Devon's call.

**Why a spike:** the persistence model decides save state shape (`data.meta.hub_town_seen` per `m3-design-seeds.md §2` is one bit; but the **scene-routing logic** — "after Player.die in S3 R4 boss, load HubTown.tscn not Stratum3Room01.tscn" — is the engineering surface).

**Owner:** Devon. Authored after §1-T1 (v5 spike) lands so engine work can sequence against locked schema.

**Output:** `team/devon-dev/hub-town-scene-routing.md` — scene-routing flowchart + save-state implications + integration with v5 active_slot.

### Spike S3 — Sprite swap pipeline (M3 W3+ timing — gated on art estimate landing)

**What:** Per `m3-design-seeds.md §4 Asset pipeline`, character-art swap is **mechanically lightweight** (~1-2 dev-hours per mob to swap ColorRect → Sprite2D + texture-load + paired-test update). 6 mobs × 2 hours = ~12 dev-hours total. The pipeline question: do we ship a single all-or-nothing PR per stratum (e.g., "S1 sprite-swap" lands all 6 mobs simultaneously) OR mob-by-mob (incremental visual change Sponsor can soak)?

**Why a spike:** the answer is small (~5 ticks) but the choice affects Sponsor's soak experience. Mob-by-mob = visible incremental progress per dispatch; per-stratum = single "S1 art-pass complete" moment for marketing. Aligns with `m3-design-seeds.md §4 Milestone shape` Option B (parallel track, incremental).

**Owner:** Drew (sprite-swap is content authoring) + Devon (sprite-load contract).

**Output:** `team/drew-dev/sprite-swap-pipeline.md` doc — authoring → export → load → swap-in-Sprite2D-node → paired-test-update steps. Includes hex-block fallback contract (if Aseprite source missing, default ColorRect renders).

---

## Risk / uncertainty markers (Sponsor-input later)

These items are flagged for **Sponsor escalation later in M3** (NOT first-wave Tier 1 blockers). Pre-positioned here so they don't surprise at sub-milestone gate.

1. **§1.1 slot count: 3 default vs 1 vs 6+.** Per `m3-design-seeds.md §1.1`. Confirm at Drew's title-screen-slot-picker design-review (`§4-T1`).
2. **§1.2 class divergence in M3 vs M4.** Per `m3-design-seeds.md §1.2`. Default M4 — flagged at M3 Tier 2 if Sponsor wants class-divergence as M3 headline.
3. **§2.4 hub-town size: single-screen vs multi-room.** Per `m3-design-seeds.md §2.4`. Default single-screen — Uma's direction doc proposes single-screen; Sponsor redirects at direction-review if multi-room wanted.
4. **§3.7 NG+ Paragon track vs alternative.** Per `m3-design-seeds.md §3.7`. Defer to M3 Tier 2 — `mvp-scope.md §M3` v1-frozen at Paragon; redirect window is open until first Paragon-ticket dispatches.
5. **§4.10 primary art style: 32-bit pixel-art commissioned vs AI-hybrid vs other.** Per `m3-design-seeds.md §4.10`. Defer to commission-brief-review (`§3-T1`).
6. **§4.11 external cost-bracket greenlight.** Per `m3-design-seeds.md §4.11`. **Pre-position Sponsor question:** "greenlight the brief — Sponsor sends to 2-3 artists, ~2-3 wk lead time?" This is the **first M3 Sponsor escalation** orchestrator should route, ideally as Sponsor reviews §3-T1 commission brief.
7. **§4.12 art-pass milestone shape: parallel track vs own milestone.** Per `m3-design-seeds.md §4.12`. Default parallel track — `m3-design-seeds.md §4 Milestone shape` recommends Option B; redirect if Sponsor wants art-pass as M3 flag-planting headline.

**One Sponsor-input item is borderline-strategic for first-wave timing:** §4.11 (external-estimate greenlight). The escalation is "do you want me to send the brief to artists NOW so estimates land in 2-3 weeks, or wait?" **Recommend orchestrator route this question to Sponsor at §3-T1 PR-merge time** — the brief doc gives Sponsor concrete content to react to. Pre-emptive Sponsor-escalation per `away-autonomy-calibration-baseline` calibration target (5-10% Sponsor-escalation rate; this is one of the few strategic escalations Tier 1 produces).

All other Sponsor-input items (1-5, 7) are **deferrable to later sub-milestones** — they shape M3 W2-W3 ticket dispatch, not first-wave.

---

## First-wave tickets (5 — dispatch-ready)

All 5 tickets target the `RandomGame` ClickUp list (`901523123922`). Standard ticket format mirroring W3 backlog shape: title (conventional-commit) / source / scope / acceptance / owner / size / priority / cross-references.

### M3-T1-1 — `design(save-schema): v5 spike — multi-character + persistent-meta migration plan` (ClickUp `86c9uth5h`)

- **Owner:** Devon (lead author; mirrors `save-schema-v4-plan.md` ownership)
- **Source:** `m3-design-seeds.md §1 + §3` + `save-schema-v4-plan.md §4.1`
- **Scope:** Author `team/devon-dev/save-schema-v5-plan.md` — schema diff vs v4 (focus on non-additive `data.character` → `data.characters[]` type-change + rename), migration step pseudo-code (v4 → v5: wrap existing character into characters[0] with slot_index 0; lift equipped from root to per-character; lift `data.character.stash` to root `shared_stash`), round-trip invariants (8 INV-* style entries mirror v4 plan), fixture catalog (5-8 fixture file specs for v4→v5 round-trip + v5 round-trip), HTML5 OPFS implications (Dict-of-Dict roundtrip cost; current v4 is mostly flat — v5's nested `characters[]` array may trip size limits). One Devon-call: pointer-shadow `data.character` for one schema generation (default YES per `m3-design-seeds.md §1`) OR remove immediately (Devon's call).
- **Acceptance:** Doc PR (200-400 lines) on `main`. Sections: schema diff / migration steps / additive-vs-non-additive call-outs / round-trip invariants / fixture catalog / HTML5 OPFS implications / pointer-shadow decision logged. Cross-references `save-schema-v4-plan.md`, `m3-design-seeds.md §1+§3`, current v4 fixtures under `tests/fixtures/v4/`. No engine code; design only.
- **Size:** **M (3-5 ticks)** — paper-spike, sized to match `save-schema-v4-plan.md`'s original authoring effort.
- **Priority:** **P0** (Tier 1 foundation — gates §1-T2..N multi-character + meta-progression impl)
- **Tags:** `m3`, `tier-1`, `design`, `save`
- **Cross-references:** `team/priya-pl/m3-tier-1-plan.md §1`, `team/priya-pl/m3-design-seeds.md §1+§3`, `team/devon-dev/save-schema-v4-plan.md`, `team/priya-pl/risk-register.md` R1 (save migration breakage — first non-additive bump escalates this)
- **Risk note:** R1 (save migration breakage) re-arms — v5 is the **first non-additive schema bump**; Devon's spike doc is the mitigation surface where the migration contract gets nailed down before features consume it.

### M3-T1-2 — `design(ux): hub-town visual direction — single-screen Outer Cloister evolution with 3 NPCs` (ClickUp `86c9uth6a`)

- **Owner:** Uma (lead author; mirrors `visual-direction.md` ownership)
- **Source:** `m3-design-seeds.md §2` + `palette.md` (Outer Cloister S1 authoritative) + `visual-direction.md` (480×270 canvas + zero-scrolling rule)
- **Scope:** Author `team/uma-ux/hub-town-direction.md` — visual shape (single-screen 480×270 internal per `visual-direction.md` lock), tile-reuse strategy (Outer Cloister evolution per `m3-design-seeds.md §2.6` default; reuses S1 brazier sprite, sandstone floor, cloister masonry walls), 3 NPC placement coordinates + personality framing (vendor at west / anvil center / bounty-poster east — recommended names + visual descriptors; "monks tending braziers" diegetic framing per design-seeds), descent-portal positioning (south edge; replaces M2 "Down to descend" door), ambient-music + ambient-lighting recommendation (menu-pad volume per `stash-ui-v1.md §1` rule; 20% vignette), B-key + Tab + Esc behaviors (consistent with `stash-ui-v1.md` patterns).
- **Acceptance:** Doc PR (200-400 lines) on `main`. Sections: visual shape / tile-reuse strategy / 3 NPC placement + framing / descent-portal positioning / ambient-music + lighting / input-binding behaviors / save-state implications (`meta.hub_town_seen` first-visit gate per `m3-design-seeds.md §2 Save-schema`). Cross-references `m3-design-seeds.md §2`, `palette.md`, `visual-direction.md`, `stash-ui-v1.md` (M2 stash-room evolution source).
- **Size:** **M (3-5 ticks)** — design-spec doc, mirror of Uma's `audio-direction.md` + `visual-direction.md` shape.
- **Priority:** **P0** (Tier 1 foundation — gates Drew's `HubTown.tscn` authoring in §2-T2)
- **Tags:** `m3`, `tier-1`, `design`, `ux`
- **Cross-references:** `team/priya-pl/m3-tier-1-plan.md §2`, `team/priya-pl/m3-design-seeds.md §2`, `team/uma-ux/visual-direction.md`, `team/uma-ux/palette.md`, `team/uma-ux/stash-ui-v1.md`
- **Risk note:** None new. Uses defaults from `m3-design-seeds.md §2.4-§2.6` (single-screen, 3 NPCs, Outer Cloister evolution); Sponsor reviews direction doc at PR-merge time — redirect window open then if multi-room wanted.

### M3-T1-3 — `design(commission): character-art pass external-estimate brief — 2-3 pixel-art artist quotes` (ClickUp `86c9uth7g`)

- **Owner:** Priya (drafts brief); Sponsor (commissions) — **dual-owner; orchestrator routes Sponsor-action at PR merge**
- **Source:** `m3-design-seeds.md §4 Cost-and-time bracket` + `palette.md` + `palette-stratum-2.md` + `.claude/docs/combat-architecture.md` § "Mob hit-flash"
- **Scope:** Author `team/priya-pl/art-pass-commission-brief.md` — artist-facing brief content for Sponsor to forward. Includes: project framing (top-down ARPG, Embergrave working title, ember-descent tonal anchors), sprite spec (32-pixel character sprites, palette locked to `palette.md` + `palette-stratum-2.md` hex codes, Aseprite-compatible source files), anim states per mob (idle 4f / walk 8f / attack-telegraph 4f / attack 6f / hit-react 3f / die 8f, 4-directional cardinal), mob roster (6 archetypes — Grunt / Charger / Shooter / PracticeDummy / Stoker / Stratum1Boss; Stoker is a retint of Grunt per `palette-stratum-2.md §5`), Player + 3 hub-town NPCs (per `m3-design-seeds.md §2`), pickup/chest/ember-bag retint pass (cheap), per-stratum retint variants (S1-S8 at +10-20% per stratum per Aseprite palette-swap pattern), timeline ask (8-16 weeks for full M3 set; segment-able by stratum so artist can deliver S1 first), integration constraint (existing `_play_hit_flash` modulate-cascade in combat-architecture preserves the sprite — artists provide the rest-color base, hit-flash logic doesn't change).
- **Acceptance:** Doc PR (~300 lines) on `main`. Sponsor receives orchestrator-routed escalation at PR-merge: "ready to send brief to 2-3 artists?" Three Sponsor-input items in the brief itself: §4.10 primary style confirmation (default 32-bit commissioned), §4.11 external estimate greenlight (default YES), suggested per-cell-rate ranges Sponsor can negotiate. Cross-references `m3-design-seeds.md §4`, `palette.md`, `palette-stratum-2.md`, `.claude/docs/combat-architecture.md`.
- **Size:** **M (3-5 ticks)** — Priya draft. Sponsor commission action is hours of Sponsor time (post-PR-merge).
- **Priority:** **P1** (Tier 1 foundation — gates §3 implementation eventually, but Tier 1 dev work is independent; brief is on the critical path for §3-impl only)
- **Tags:** `m3`, `tier-1`, `design`, `art`, `sponsor-action`
- **Cross-references:** `team/priya-pl/m3-tier-1-plan.md §3`, `team/priya-pl/m3-design-seeds.md §4`, `team/uma-ux/palette.md`, `team/uma-ux/palette-stratum-2.md`, `.claude/docs/combat-architecture.md`
- **Risk note:** Lead-time ~2-3 weeks on artist quotes per `m3-design-seeds.md §4`. **Starting the clock now is the load-bearing reason this is Tier 1, not Tier 2.** Hex-block fallback per `m3-design-seeds.md §4 Risks` is the safety net if estimates don't land in time.

### M3-T1-4 — `design(ui): title-screen slot-picker spec — multi-character new-game + continue flows` (ClickUp `86c9uth85`)

- **Owner:** Drew (lead author)
- **Source:** `m3-design-seeds.md §1` + existing `scenes/TitleScreen.tscn` (if exists; else flag as new authoring) + `inventory-stats-panel.md` (cell-render pattern for slot rows)
- **Scope:** Author `team/drew-dev/title-screen-slot-picker.md` — title-screen state diagram (no-characters / 1-character-saved / 2-characters / 3-characters-full / mid-game-load), slot-picker UI shape (3 slot rows with name + level + stratum-deepest + last-played-relative-time + delete-confirm hover-affordance), New Game flow (slot picker → name input → confirm → load into hub-town for the first time → `meta.hub_town_seen=true`), Continue flow (slot picker → confirm → load wherever last save was), delete-slot flow (hold-to-confirm 1.5s per `m3-design-seeds.md §1` safety pattern), keyboard navigation (arrow keys + Enter; mouse-click supported but secondary per visual-direction's keyboard-first rule), default-state when launched-with-no-save (3 empty slot rows + "New Game" button focused). Wireframe sketches (text-art or referenced Aseprite mock) for each state.
- **Acceptance:** Doc PR (~250 lines) on `main`. Sections: state diagram / slot-picker UI / New Game + Continue + Delete flows / keyboard nav / default-state / wireframes. Cross-references `m3-design-seeds.md §1`, current title-screen scene state. **One Sponsor-input item:** §1.1 slot count default 3 (Sponsor redirect window at PR-merge if 1 or 6+ wanted).
- **Size:** **S-M (2-4 ticks)** — UI-spec doc, slightly smaller than save-schema spike.
- **Priority:** **P0** (Tier 1 foundation — gates §4-T2 Drew impl of `TitleScreen.tscn` slot picker)
- **Tags:** `m3`, `tier-1`, `design`, `ui`
- **Cross-references:** `team/priya-pl/m3-tier-1-plan.md §4`, `team/priya-pl/m3-design-seeds.md §1`, `team/uma-ux/visual-direction.md` (keyboard-first input rule)
- **Risk note:** None new. Spec authored against `m3-design-seeds.md §1.1` 3-slot default; Sponsor redirect at PR-merge time if different count wanted.

### M3-T1-5 — `qa(plan): M3 Tier 1 acceptance plan scaffold — placeholder rows for §1-§4 sub-milestones` (ClickUp `86c9uth9q`)

- **Owner:** Tess (lead author; mirrors `m2-acceptance-plan-week-3.md` shape)
- **Source:** `m2-acceptance-plan-week-3.md` + `m3-tier-1-plan.md` (this doc) + `m3-design-seeds.md`
- **Scope:** Author `team/tess-qa/m3-acceptance-plan-tier-1.md` — placeholder acceptance rows for each Tier 1 sub-milestone (Shape A's four tracks): §1 (save v5 round-trip / v4→v5 migration from fixture / additive-vs-non-additive contract test / shared-stash lift correctness / pointer-shadow behavior), §2 (HubTown.tscn loads / 3-NPC interactability / descent-portal stratum-selection / `meta.hub_town_seen` first-visit / B-key Tab Esc behaviors), §3 (NO test rows — external-estimate is Sponsor-routed, not engineering), §4 (title-screen state per save-count / slot-picker UI behavior / New Game flow / Continue flow / Delete flow / 3-slot-full edge / keyboard nav). Each row: ID prefix (e.g., `SV5-1`, `HT-1`, `TS-1`) + acceptance criterion text + test surface (GUT / Playwright / Sponsor-probe). Mark rows as `[PENDING-SPEC]` where they depend on Tier 1 design doc landing (e.g., row references Devon's v5 spike, not yet finalized). Rows lock as design docs land — same pattern as W3-T10 Half A.
- **Acceptance:** Doc PR (~200-300 lines) on `main`. Placeholder rows present for §1, §2, §4 (and one omitted-row block for §3 explaining "external estimate is non-engineering"). Cross-references `m3-tier-1-plan.md`, `m3-design-seeds.md`, `m2-acceptance-plan-week-3.md`.
- **Size:** **S-M (2-3 ticks)** — scaffold doc; ongoing fill-in as features dispatch.
- **Priority:** **P0** (Tier 1 foundation — Tess capacity scaffold; M2 pattern proved value of parallel acceptance-plan authoring)
- **Tags:** `m3`, `tier-1`, `qa`, `plan`
- **Cross-references:** `team/priya-pl/m3-tier-1-plan.md`, `team/priya-pl/m3-design-seeds.md`, `team/tess-qa/m2-acceptance-plan-week-3.md`
- **Risk note:** R2 (Tess bottleneck) mitigation — scaffold-from-day-1 keeps Tess in parallel with dev lanes rather than blocking on dev landing.

---

## Sequencing recommendation for orchestrator

**Day 1 dispatch (all 5 in parallel — single tool round):**
- §1-T1 → Devon
- §2-T1 → Uma
- §3-T1 → Priya (then Sponsor escalation at PR-merge)
- §4-T1 → Drew
- §QA-T1 → Tess

All 5 are doc-PRs (no engine code). Devon/Uma/Drew worktrees are idle per dispatch brief. Tess is on AC4 #253 QA at brief-time; **dispatch §QA-T1 to Tess when #253 QA closes** (likely same day or next dispatch tick).

**Day 5-10 dispatch (Tier 2 — once Tier 1 docs land):**
- §1-T2 (Devon v5 migration impl + GUT migration test) — gated on §1-T1 merge
- §2-T2 (Drew `HubTown.tscn` authoring) — gated on §2-T1 merge
- §3-T2 (none until artist estimates land, ~3 weeks)
- §4-T2 (Drew `TitleScreen.tscn` slot-picker impl) — gated on §4-T1 + §1-T1 both merged (Drew authors UI; Devon's v5 wires the data shape)
- §QA-T2 (Tess fills acceptance rows as design docs land — ongoing)

**M3 W2 cadence target:** ~10-15 PRs across the 5 lanes, mirror of M2 W2 throughput (22 PRs at peak). Conservative because Tier 1 is foundation-heavy.

---

## Cross-references

- **`team/priya-pl/m3-shape-options.md`** — Sponsor picked Shape A 2026-05-17.
- **`team/priya-pl/m3-design-seeds.md`** — Shape A's four-track elaboration (15 Sponsor-input items detailed).
- **`team/priya-pl/mvp-scope.md` §M3** — canonical content-track scope contract.
- **`team/devon-dev/save-schema-v4-plan.md`** — current v4 schema; v5 extends per §1-T1.
- **`team/priya-pl/risk-register.md`** R-M3 — risk activated by Shape A lock; this plan is the Tier 1 mitigation.
- **`team/priya-pl/decisions-batch-pr-template.md`** — `Decision draft` line for Sponsor's Shape A pick will land in next Monday batch.
- **`.claude/docs/orchestration-overview.md`** — team topology + dispatch conventions.
- **`.claude/docs/combat-architecture.md`** § "Mob hit-flash" — integration surface §3 art-pass must preserve.

---

## Caveat — Tier 1 plan, not Tier 1+ lock

This doc is the **first-wave dispatch breakdown** based on Sponsor's 2026-05-17 Shape A pick. Tier 2+ work is gated on Tier 1 docs landing and Sponsor-input items resolving. The 15 Sponsor-input items from `m3-design-seeds.md` decide M3 W2-W3 ticket dispatch shape — they are **not** Tier 1 blockers.

**The plan is revisable** as Tier 1 docs land and surface new questions. Expected revision points:
- §1-T1 (Devon v5 spike) may surface migration costs that promote v5-impl size from M to L.
- §2-T1 (Uma hub-town direction) may flag that single-screen size is too constraining for 3 NPCs + props; if so, §2.4 escalates to Sponsor.
- §3-T1 (commission brief) may need iteration based on Sponsor feedback before sending to artists.
- §4-T1 (Drew title-screen spec) may surface that the existing `scenes/TitleScreen.tscn` is non-trivial and needs Devon engine-side work to wire slot data — flag as Devon-side §1 dependency.

Updates land as v1.1 amendment + DECISIONS.md entry per `team/DECISIONS.md` cadence (Priya weekly batch).

---

## Non-obvious findings

1. **Tier 1's load-bearing decision is starting the art-pass commission clock NOW, not at M3 W2-W3.** Per `m3-design-seeds.md §4`, lead-time on 3 artist quotes is ~2-3 weeks; if §3-T1 dispatches as Tier 1, estimates land before §3-impl needs to start. Defer §3-T1 to Tier 2 and the art-pass becomes the M3 bottleneck.
2. **v5 is the first non-additive save-schema bump in the project's history.** `save-schema-v4-plan.md §4.1` rule 1 forbids renames; v5's `data.character` → `data.characters[]` is a rename + type-change. Spike-first per §1-T1 codifies the migration contract before features consume it.
3. **All 5 Tier 1 tickets are doc-PRs.** No engine code in first wave. Mirrors M2 W3-T12 (M3 design seeds) and M2 W2-T11 (audio direction) cadence — Sponsor visible progress happens through design doc landing, not through code.
4. **Tess scaffold parallels dev from Day 1.** Without §QA-T1 in first wave, Tess is idle while Devon/Uma/Drew/Priya ship design docs — wastes a lane. The acceptance-plan-scaffold pattern from M2 W3-T10 Half A is the answer; M3 Tier 1 ports it forward.
5. **Drew can author §4-T1 (slot-picker spec) without waiting on Devon's v5 spike.** UI-shape work and data-shape work converge at implementation (§4-T2), not at spec-time. This unlocks parallel Day 1 dispatch for all 5 tickets.
