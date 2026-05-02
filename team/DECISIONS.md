# Decision Log

Append-only. One entry per decision. The Project Leader logs all team-level decisions here. The orchestrator logs cross-role escalations here.

Format:

```
## YYYY-MM-DD — <short title>
- Decided by: <Priya | orchestrator | other>
- Decision: <one sentence>
- Why: <one or two sentences — the load-bearing reason>
- Reversibility: <reversible | one-way>
- Affects: <roles or systems>
```

---

## 2026-05-02 — Sponsor's hard requirements

- Decided by: Sponsor
- Decision: Game must be (a) adventurous and (b) have a leveling goal where player works toward better levels & gear, fights harder mobs, gets further in the game.
- Why: Sponsor's stated requirements. Everything else is the team's call.
- Reversibility: one-way (defines the project)
- Affects: all

## 2026-05-02 — Team naming convention

- Decided by: orchestrator
- Decision: Five named roles — Priya (PL), Uma (UX), Devon (Dev #1, lead), Drew (Dev #2), Tess (QA). ClickUp tasks use bracketed person prefix `[Name]` for early-week ramp tasks (mirrors MARIAN-TUTOR's `[Kevin]` / `[Kyle]` / `[Devon]` / `[Matt]` convention).
- Why: Mirrors the MARIAN-TUTOR pattern the Sponsor asked us to learn from. Distinct first letters so messages and ownership are unambiguous.
- Reversibility: reversible
- Affects: all roles, ClickUp board

## 2026-05-02 — Sponsor hands-off

- Decided by: Sponsor
- Decision: Orchestrator makes recommended decisions on Sponsor's behalf. Sponsor only tests big deliveries and signs off. PL drives team-level decisions; only escalates to orchestrator for cross-role calls.
- Why: Stated Sponsor preference.
- Reversibility: one-way
- Affects: all

## 2026-05-01 — Game concept: Embergrave

- Decided by: Priya
- Decision: Working title **Embergrave** — top-down 2D action-RPG dungeon crawler with light roguelite framing. 8 strata (vertical descent), persistent character + gear across runs, two-ladder progression (character level 1–30 + gear tiers T1–T6 with rolled affixes). Single-player, no multiplayer, no monetization in v1.
- Why: Hits both Sponsor hard requirements (adventurous; level-and-gear treadmill against harder mobs going further). Anchors against *Hades* (run feel), *Diablo II* (gear joy), *Crystal Project* (small-team scope proof). 2D scope is shippable by 2 devs in ~4 weeks part-time.
- Reversibility: one-way (defines the project)
- Affects: all
- Detail: `team/priya-pl/game-concept.md`

## 2026-05-01 — Tech stack: Godot 4.3 + GDScript

- Decided by: Priya
- Decision: **Godot 4.3** engine, **GDScript** primary, JSON save files, TRES content resources, **GitHub Actions** CI (headless import + GUT), **itch.io HTML5 + Windows/macOS/Linux** distribution, Aseprite art pipeline, AI-generated music stems curated by Uma.
- Why: Godot is free, open-source, has clean HTML5 export (Unity's WebGL is heavier), and the editor's scene composition is ideal for 2D ARPG. GDScript iterates fastest; we're nowhere near needing C# perf. itch.io accepts HTML5 with zero gatekeeping — perfect for Sponsor playtests.
- Reversibility: reversible early, sticky after week 2 once content is authored.
- Affects: Devon, Drew (tooling), Uma (export targets), Tess (build artifacts).
- Detail: `team/priya-pl/tech-stack.md`

## 2026-05-01 — MVP scope: M1 First Playable

- Decided by: Priya
- Decision: M1 = stratum-1-only playable build. 1 mob archetype (grunt), weapon+armor gear slots only, T1–T3 tiers, 3-affix pool, JSON save survives quit, character level 1–5 cap, stratum-1 boss. ~80–100 orchestrator ticks (~4 weeks part-time). 7 explicit acceptance criteria for Sponsor. Off-hand/trinket/relic slots, crafting, audio score, controller, story text — all deferred to M2/M3.
- Why: Smallest build that proves the core loop is fun. Death loses run progress but keeps character level + stash so Sponsor experiences both ladders. Cuts that hurt least are the ones we made.
- Reversibility: reversible — can pull M2 features into M1 if pace allows, or push M1 features to M2 if pace stalls.
- Affects: all roles.
- Detail: `team/priya-pl/mvp-scope.md`

## 2026-05-01 — Distribution: itch.io HTML5 first, Steam later

- Decided by: Priya
- Decision: M1 ships as a private itch.io HTML5 build (single URL for Sponsor). Steam playtest application waits until M3.
- Why: itch.io has zero gatekeeping and accepts HTML5 directly. Steam playtest has approval overhead that's wasted before we have a content spine.
- Reversibility: reversible.
- Affects: Devon (CI/butler), Tess (test environments), Sponsor (playtest channel).

## 2026-05-01 — Phase 0 → Phase 1 transition

- Decided by: Priya
- Decision: Phase 0 deliverables complete. Moved to **Phase 1 — MVP Build**. 20 week-1 tasks created in ClickUp list `901523123922`, all tagged `week-1`. Backlog at `team/priya-pl/week-1-backlog.md`.
- Why: Concept, stack, scope, and backlog are all locked. Team can start executing.
- Reversibility: one-way.
- Affects: all.
