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

## 2026-05-01 — Project layout: Godot project at repo root

- Decided by: Devon
- Decision: `project.godot` lives at the **repo root**, not in a `/game` subdirectory. Standard folders: `scenes/`, `scripts/` (with `scripts/save/`, `scripts/player/`, etc.), `assets/`, `resources/` (TRES content), `tests/` (GUT), `addons/` (third-party plugins). Aseprite/audio sources go in `art/` and `audio/` subfolders at root, ignored from Godot import via `.gdignore` if needed later.
- Why: Tech-stack doc proposed `/game` as the Godot root, but a single-engine repo with the engine at root keeps CI commands simpler (`godot --path .`), keeps itch.io HTML5 export paths shallow, and matches Godot community convention. Scripts/scenes split by domain instead of one giant folder.
- Reversibility: reversible early, sticky once Drew lands content.
- Affects: Drew (resources/, scripts/), Tess (test paths), CI (workflow paths).

## 2026-05-01 — Physics layers reserved

- Decided by: Devon
- Decision: 2D physics layers reserved in `project.godot`: 1=world, 2=player, 3=player_hitbox, 4=enemy, 5=enemy_hitbox, 6=pickups. Player attacks live on layer 3 and mask layer 4. Enemy attacks live on layer 5 and mask layer 2. Dodge i-frames temporarily clear the player's layer-2 collision so enemy hitboxes pass through.
- Why: Layer separation is the cleanest way to express "player attack only damages enemies and vice versa" without runtime owner checks. Locked early so Drew's grunt mob (#8) can rely on these slots.
- Reversibility: reversible but cheap to leave alone.
- Affects: Drew (mob hitboxes), Devon (player hitboxes).

## 2026-05-01 — GDScript style: typed-first

- Decided by: Devon
- Decision: GDScript code uses **explicit type hints** on every var, parameter, and return. `_ready() -> void:` not `_ready():`. Project debug warnings flag untyped declarations (`gdscript/warnings/untyped_declaration=1`). Class names use `class_name` for any node intended to be referenced outside its scene. Snake_case for vars/functions, PascalCase for class/scene names, SCREAMING_SNAKE for consts.
- Why: Catches refactor breakage at parse time, gives Drew autocomplete on shared APIs, makes save schema concrete. Cost is a few extra characters per declaration.
- Reversibility: reversible, but cheap to keep.
- Affects: Devon, Drew (all GDScript).

## 2026-05-01 — GUT not vendored; CI installs at runtime

- Decided by: Devon
- Decision: We do not commit the GUT addon source to `addons/gut/`. CI clones `bitwes/Gut` at workflow time, pinned to **v9.3.0**. Local devs install via Godot AssetLib. Pin is documented in `addons/gut/README.md` and the CI workflow.
- Why: Smaller repo, fewer merge conflicts, single source of pin truth. GUT is not a runtime dependency of the shipped game.
- Reversibility: reversible — switch to a submodule if the AssetLib install becomes a friction point.
- Affects: Devon (CI), Tess (test runs), Drew (running tests locally).

## 2026-05-01 — Content schema: TRES with composition, not inheritance

- Decided by: Drew
- Decision: M1 content schema is four `Resource` types — `MobDef`, `ItemDef`, `AffixDef`, `LootTableDef` — each `class_name`'d. Cross-references go via `ext_resource` (one canonical TRES per affix/item, drag-referenced from loot tables and items). Sub-resources (`ItemBaseStats`, `AffixValueRange`, `LootEntry`) used for grouped fields instead of flat `@export`s, so Godot inspector groups them and saves migrate cleanly. Affix value ranges are an `Array[AffixValueRange]` of length 3 (T1/T2/T3), one entry per shipped tier; will grow when T4–T6 land in M2/M3. Tier-driven affix count and roll algorithm live in `LootRoller` (single tunable point), not in `ItemDef`. Runtime mutable state lives on `ItemInstance` / mob nodes — TRES resources are immutable templates.
- Why: TRES gives inspector editing, autocomplete via `class_name`, and version-controllable text-format authoring (per tech-stack.md). Composition over inheritance because slot-specific stat shapes will diverge in M2 (relics ≠ weapons) and we want to extend without breaking saved files. Matches the M1 spec exactly: weapon+armor slots only, T1–T3, 3-affix pool (`swift`, `vital`, `keen`).
- Reversibility: reversible while M1 content is still being authored; sticky once Tess starts asserting against schema in tests and saves serialize ItemInstance with affix rolls.
- Affects: Devon (engine — these resources are the contract for combat/save/loader code; needs to publish canonical stat-key StringNames for `AffixDef.stat_modified`), Uma (UI — `display_name`, `icon_path`, tier color, base_stats sub-resource shape are the inventory/tooltip surface), Tess (test data factories build off these classes), Priya (M1 affix value ranges marked as placeholders awaiting balance pin).
- Detail: `team/drew-dev/tres-schemas.md`

## 2026-05-02 — Testing bar raised — Sponsor will not debug

- Decided by: Sponsor (directive) → orchestrator (codification)
- Decision: New, binding **Definition of Done** at `team/TESTING_BAR.md`. Every feature task requires unit tests, green CI, integration check vs. M1 acceptance criteria, three edge-case probes, and **Tess sign-off** before flipping to `complete`. Devs cannot self-sign features; the `ready for qa test` → `complete` transition is Tess-only. Tess is promoted from plan-writer to active hammer; bug bashes are scheduled work; soak sessions required per release candidate. Priya owns enforcement — pushes without tests are reverted and tech-debt-tagged. Orchestrator gates Sponsor sign-off pings on zero-blocker, zero-major bug state.
- Why: Sponsor stated *"I want you to use a lot of time testing, I don't want to debug and return findings all the time."* Sponsor's role is acceptance, not bug-finding. If the Sponsor finds a bug at sign-off, the team has failed.
- Reversibility: one-way for Phase 1+.
- Affects: all roles. Major impact on Tess (workload up), Devon/Drew (tests-with-features mandatory), Priya (week-2 backlog needs ≥20% test buffer), orchestrator (heartbeat now polices `ready for qa test` queue depth and blocks Sponsor pings on open bugs).
- Detail: `team/TESTING_BAR.md`

## 2026-05-01 — Testability hooks Devon must expose for M1 test plan

- Decided by: Tess
- Decision: Five hooks the M1 build must expose so Tess's acceptance test plan is actually executable: (1) **Build SHA visible in main menu** — small "build: abcdef1" footer, sourced from CI stamp; (2) **Debug-only "fast-XP" toggle** — gated behind a hidden key combo, never shipped to Sponsor — so Tess can reach level 4–5 in <2 min for AC4/AC7 testing; (3) **Save file location documented** in a one-liner README inside the user data dir — discoverable for AC3-T03 and AC6 inspection; (4) **Stable mob spawn seed in test mode** — debug flag that fixes the seed so AC4 setup isn't 30 min of grinding to retry; (5) **HTML5 console error surfacing** — verify Godot's default GDScript-error-to-browser-console pipeline is not stripped from release builds. Tess will file these as `chore(test-hooks)` ClickUp tasks.
- Why: Without these, the M1 test plan blows out of its time budget on every run — especially AC4 (boss DPS check) and AC7 (loot affix coverage), which need a level-4+ character with specific gear. Cheap to expose, expensive to live without.
- Reversibility: reversible — hooks can be removed post-M1 if they're a footgun. Build-SHA footer stays forever.
- Affects: Devon (implements hooks 1, 2, 4, 5; documents 3), Tess (uses all five), Sponsor (must not see hook 2 — gate it).
- Detail: `team/tess-qa/m1-test-plan.md` § "Notes for Devon & Drew (testability hooks needed)"

## 2026-05-02 — Week-1 DoD threaded through ClickUp feature tasks

- Decided by: Priya
- Decision: All 9 active week-1 feature tasks (Devon's #2 CI, #3 butler, #4 movement, #5 attacks, #6 save, Drew's #7 schema, #8 grunt, #9 first room, #10 loot) plus the smoke-test task #17 had a "Done when" block appended to their ClickUp descriptions. Each block enumerates: paired GUT test path, green CI requirement, M1-AC integration check, three feature-specific edge-case probes (rapid input, mid-action interrupt, tab-blur or save-race per feature), and Tess sign-off requirement. Task #1 scaffold (already `complete`, pre-bar) was not retroactively gated. Pure docs/design tasks (Uma's 5, Tess's plan, Priya's 3) deliberately **not** bloated with the DoD block — they are exempt from #2/#4/#5 of the bar.
- Why: The testing bar is binding but only enforceable if the artifact (ClickUp task) tells each role exactly what "done" means for *their* feature. Generic checklists get ignored; feature-specific edge cases (e.g., "tab-blur mid-dodge", "kill process during save write", "rolled-RNG statistical assertion over N=10000") get probed.
- Reversibility: reversible — easy to edit task descriptions if the bar evolves.
- Affects: Devon, Drew (clearer DoD), Tess (concrete sign-off checklist), Priya (enforcement is now pointing at line items, not vibes).

## 2026-05-02 — Week-1 timeline reshuffle: 8 features carry to week 2

- Decided by: Priya
- Decision: 12 of 20 week-1 tasks remain on track for week-1 close (paper deliverables — Uma 5, Tess plan, Priya 3, plus Devon #1 done + #2 in QA queue + Drew #7 paper). 8 implementation tasks slip to week 2 — Devon's #3 (butler), #5 (attacks), #6 (save/load), and Drew's #8 (grunt), #9 (first room), #10 (loot), the schema *implementation* split out of #7, and conditionally Devon's #4 (movement) if not Tess-signed by week-1 close. M1 acceptance criteria unchanged; only week boundary moves. Detailed verdict at `team/priya-pl/week-1-revised-timeline.md`.
- Why: Tess sign-off latency from the new bar adds ~1 tick per feature. Save/load is bar-flagged as deepest-coverage system (`TESTING_BAR.md` §Devon-and-Drew) and gets +1 tick of explicit buffer rather than getting cut corners. Better to slip a feature to week 2 with full tests than ship it on schedule with `tech-debt(...)` tags.
- Reversibility: reversible — features can re-accelerate into w1 close if Tess sign-off cycles run faster than projected.
- Affects: Devon (3 features carry), Drew (4 features carry), Tess (queue depth more important to manage than calendar week), orchestrator (heartbeat queue-depth rule from TESTING_BAR.md is now load-bearing).
- Detail: `team/priya-pl/week-1-revised-timeline.md`

## 2026-05-02 — Drew Task #7 split: paper this week, implementation paired with #8

- Decided by: Priya
- Decision: Drew's week-1 Task #7 (TRES schema authoring tooling) splits cleanly into (a) the spec doc `team/drew-dev/tres-schemas.md` — week-1, already paper-complete — and (b) the implementation deliverables (`MobDef.gd`, `ItemDef.gd`, `AffixDef.gd`, `LootTableDef.gd`, `ContentFactory` static factories, GUT smoke for factories, seed TRES files for one mob + two items). The implementation portion ships paired with Drew's Task #8 (grunt mob) in week 2, because that's where the schema gets its first real consumer and the paired GUT test is most informative.
- Why: Testing bar requires paired tests. Authoring tooling without a consumer has no obvious test target; bundling implementation with #8 means the test exercises the schema *via* the grunt — closer to how it'll actually be used. Reduces test-for-test's-sake and produces stronger coverage.
- Reversibility: reversible — Drew can ship the implementation on its own if w2 capacity allows.
- Affects: Drew (split task in own ClickUp), Tess (sign-off arrives once with #8 not separately), Priya (carry-over count = 8 not 7).

## 2026-05-02 — Week-2 backlog drafted with 20% buffer floor

- Decided by: Priya
- Decision: Week-2 backlog drafted at `team/priya-pl/week-2-backlog.md`. ~25 tickets total: 8 carry-overs + 14 new feature/design tickets + 5 buffer (bug bash, soak, CI hardening, test backfill, integration tests) = **20% buffer floor met** per testing bar §Priya. New work focus: level-up math + XP curve, damage formula, 2 mobs (shooter + charger), stratum-1 boss, affix system + balance pass, level-up UI implementation, save migration test. Critical path: save (C3) → level-up math (N1) → damage (N3) → affixes (N7) → boss (N6) → bug bash + soak. Backlog will be promoted to ClickUp at end of week 1, not now.
- Why: Bar requires explicit ≥20% test buffer. Listing the buffer items (B1–B5) as named tickets — not "we'll do testing as we go" — turns the buffer into something the orchestrator can dispatch against and Priya can defend at week boundary.
- Reversibility: reversible until ClickUp promotion at end of week 1.
- Affects: all roles week 2.
- Detail: `team/priya-pl/week-2-backlog.md`

## 2026-05-02 — Visual direction locked: pixel art 96 px/tile, 480x270 canvas

- Decided by: Uma (authored) → orchestrator (formalization)
- Decision: Embergrave's visual direction is **pixel art at 96 px/tile, 480×270 internal canvas, integer scaling only, nearest-neighbor filtering**, eight-stratum hue progression per `team/uma-ux/palette.md`. Stratum 1 palette is authoritative; S2–S8 are indicative until those strata enter scope. This is a binding lock — switching art styles after content authoring begins is multi-week rework.
- Why: Uma's call as the design authority; orchestrator formalizes so Drew (mob sprite resolution and color usage) and Devon (project viewport/render settings, UI scene scaling) can implement against a fixed contract starting now. Pixel art at this resolution ships cleanly to itch.io HTML5 with no upscale artifacts and is a known shippable scope for a 2-developer team.
- Reversibility: one-way once Drew authors the first stratum-1 mob sprite and Devon configures viewport.
- Affects: Drew (all sprite/tile resolution and palette usage), Devon (project viewport, stretch mode, UI render settings, font choice), Tess (visual regression test cases keyed to palette hexes), future content authoring.
- Detail: `team/uma-ux/visual-direction.md`, `team/uma-ux/palette.md`.

## 2026-05-02 — M1 death rule: keep level + equipped, lose unequipped inventory

- Decided by: orchestrator (Uma flagged; Priya's mvp-scope said "death loses run progress, keeps level/stash" but M1 has no stash UI)
- Decision: On M1 death, the player **keeps** character level, XP earned, and currently-equipped items (weapon + armor). The player **loses** all unequipped inventory items and the run-progress (depth, position, in-progress combat resources). The run-summary screen leads with what was kept (per Uma's death-restart-flow). M2 introduces a stash UI + an "ember-bag" gear-recovery pattern at the death point.
- Why: Preserves Sponsor's two-ladder treadmill (character level + gear) with meaningful death stakes, without requiring stash UI in M1. Equipped-only persistence is the simplest rule that still carries the gear ladder forward through the sting of a wipe. Inventory loss creates a real choice ("equip the rare drop now or risk losing it") which is genuinely the loop fantasy.
- Reversibility: reversible — M2 can soften (ember-bag recovery) or harden (lose equipped on second death) the rule without breaking M1.
- Affects: Drew (loot system must distinguish equipped vs. inventory state on death), Devon (save schema needs `equipped_items` vs. `inventory_items` separation; serialize `equipped_items` and persistent character on death; reset run state), Uma (death-restart-flow run-summary copy may need to call out "equipped gear kept" explicitly), Tess (M1-AC test cases for death must verify equipped persists, inventory wipes, level kept).
- Detail: open thread in Uma's `STATE.md` section; consumed and resolved here.

## 2026-05-02 — Switch to worktree-isolated agent dispatches

- Decided by: orchestrator (Sponsor flagged the friction, asked for recommendation, accepted)
- Decision: All future agent dispatches use **`isolation: "worktree"`** by default. Each dispatched agent gets its own temporary git worktree (separate working directory + HEAD, shared `.git` and origin). The orchestrator continues to operate on the main checkout. `team/GIT_PROTOCOL.md` "Concurrent agents" section updated. Sequential dispatches with no expected parallelism may opt out per orchestrator's call.
- Why: Concurrent agents (Tess, Devon, Drew running in parallel) repeatedly polluted the orchestrator's main checkout — `git checkout` issued by one agent left the working directory on a non-main branch, so subsequent orchestrator commits landed on the wrong branch. We worked around it with defensive `git checkout main` + `git restore --source=` patterns, but the per-commit overhead added up. Worktree isolation gives every agent its own working directory without changing the branch model. Drew's untracked WIP files appearing in my queue-flush PR was the canonical example of cross-agent leakage; that won't recur.
- Reversibility: reversible at any time — flag is per-dispatch. If the orchestrator finds worktree creation slow or wasteful for a tiny task, dispatch without it.
- Affects: Orchestrator (changes the dispatch call shape going forward), all agents (their worktree path is no longer the project root — relevant only if a script hardcodes `c:\Trunk\PRIVATE\RandomGame`; none should). Disk: a few MB per concurrent agent. CI: untouched (CI runs against pushed branches, not local worktrees).
- Detail: `team/GIT_PROTOCOL.md` "Concurrent agents" section.

## 2026-05-02 — Testability hooks landed: surface, gates, and RNG ownership

- Decided by: Devon (per dispatch authority — Godot-specific implementation details)
- Decision: Five testability hooks landed in PR #19 (`devon/testability-hooks`, ClickUp `86c9kxnqx`). (1) Build-SHA stamp: CI writes `${GITHUB_SHA:0:7}` to `build_info.txt`; `BuildInfo` autoload renders it as `Main.tscn`'s `BuildLabel` footer; local fallback `dev-local`; gitignored. (2) Fast-XP toggle: Ctrl+Shift+X (physical keycode) on the new `DebugFlags` autoload; `xp_multiplier()` returns 100 vs 1; multiplier value `100x` is a placeholder and Priya owns final calibration via the level curve (week-2 N1) — single-source-of-truth in `DebugFlags.FAST_XP_MULTIPLIER`. (3) Save-dir README: `Save.save_game()` writes `user://README.txt` (location, schema_version, clear-procedure) on every save. (4) Test-mode mob seed: `--test-mode` CLI / `EMBERGRAVE_TEST_MODE` env pins `DebugFlags.mob_spawn_seed()` to `0x7E57C0DE`. (5) HTML5 console errors: verified Godot 4.3's default already routes `print`/`push_error`/`push_warning` + uncaught script errors to browser `console.log`/`console.error` — no code or export-preset change needed.
- Why: Tess's M1 acceptance plan (`team/tess-qa/m1-test-plan.md` § "Notes for Devon & Drew") blew its time budget on AC4 (boss DPS) and AC7 (loot affix coverage) without these hooks. Cheap to expose, expensive to live without.
- Reversibility: reversible — hooks can be removed post-M1; build-SHA footer stays forever (acceptance bookkeeping).
- Affects: Tess (uses all five — manual procedure documented per-OS in `team/devon-dev/debug-flags.md`), Drew (next-week mob spawner integration: `rng.seed = DebugFlags.mob_spawn_seed()`), Sponsor (must not see hook 2 — `OS.is_debug_build()` triple-gates the chord, the flag, and the multiplier read).
- Detail: `team/devon-dev/debug-flags.md`, PR #19.

## 2026-05-02 — Loot RNG ownership stays with Drew's LootRoller

- Decided by: Devon (clarification, no change to existing decision)
- Decision: `DebugFlags` (Devon, this run) does NOT touch the global RNG, `randomize()`, or any RNG outside the mob-spawn path. `mob_spawn_seed()` returns a value the mob spawner explicitly assigns to its own `RandomNumberGenerator.seed`. `LootRoller` continues to own loot determinism via its own `seed_rng(int)` API per the content-schema decision (2026-05-01) and the loot-roller landing (PR #11). Test-mode flag affects mob layouts only; loot rolling stays as Drew designed it.
- Why: Two seeded RNGs at different scopes (mob layouts; loot drops) is the right separation — testers can re-run a mob layout with consistent spawn placement *and* observe natural loot variance, or vice versa. Centralizing them under DebugFlags would couple subsystems that benefit from being independent.
- Reversibility: reversible.
- Affects: Drew (no change to LootRoller surface), Devon (DebugFlags scope contract), Tess (knows test-mode pins mobs only — loot still rolls free per pickup).

## 2026-05-02 — Week-2 backlog promoted to ClickUp; carry-over count corrected to 1

- Decided by: Priya
- Decision: Week-2 backlog drafted in `team/priya-pl/week-2-backlog.md` promoted to ClickUp list `901523123922`. **20 new tickets** created (N1–N14 from the draft + 6 buffer items B1–B6) and the **single open carry-over** (`86c9kwhte` butler) re-tagged with `week-2` while preserving `week-1`. Carry-over count is **1**, not the 8 the draft anticipated, because Devon's runs 002/003 and Drew's run 002 + Tess's run 003 closed the bulk of the carry-over set in flight (movement, attacks, save/load, grunt, first room, loot pipeline all merged + Tess-signed; schema implementation merged paired with grunt). Buffer ratio = **6 / 21 = 28.6%** — exceeds 20% floor per `TESTING_BAR.md`.
- Why: The week-2 backlog draft was authored mid-week-1 against an assumption that Drew and Devon would have ~8 features still open at week-1 close. Reality outpaced the plan. Promoting the backlog as drafted (8 carry-over tickets) would have created confusing duplicates against already-merged work. Correcting the count and noting it explicitly in DECISIONS.md keeps the heartbeat ticks honest about what's actually in flight.
- Reversibility: reversible — tickets are editable; if scope re-shifts (e.g. butler bounces back from QA with major bugs and needs a re-scope), Priya re-tags / re-titles.
- Affects: all roles week 2 — they have a real backlog to dispatch against. Orchestrator (dispatchable queue depth: ~20 fresh tickets), Devon (5 dev tickets — N1, N2, N3, N9, B3), Drew (8 dev tickets — N4, N5, N6, N7, N8, N10, N11 + carry C1 once Tess signs butler), Uma (2 design tickets — N13, N14), Tess (5 QA tickets — N12, B1, B2, B4, B5), Priya (1 — B6 mid-week retro).
- Detail: `team/priya-pl/week-2-backlog.md` (draft + tracking), `team/priya-pl/risk-register.md` (covers scope-creep risk R4).

## 2026-05-02 — Week-1 design docs frozen as v1

- Decided by: Priya
- Decision: `team/priya-pl/game-concept.md`, `team/priya-pl/tech-stack.md`, and `team/priya-pl/mvp-scope.md` are marked **v1-frozen** as of 2026-05-02. A `## v1 — frozen 2026-05-02` block at the top of each doc states the freeze contract: any change after this date lands in a `## Changes` section with date + rationale + `Decided by`, never as a silent edit.
- Why: M1 build is in week 2. Drew's content authoring, Devon's engine work, and Tess's acceptance plan all anchor on these three docs. Drift mid-build causes silent breakage (e.g. mob count changes from 3 to 4 in mvp-scope but Drew's not told). Freezing forces any change through DECISIONS.md so every role sees it.
- Reversibility: reversible — the freeze itself is a convention, not a technical lock. Easy to land a `## Changes` entry if the team agrees a v1 update is warranted.
- Affects: all roles. Specifically Priya (gatekeeper), Drew (content references mvp-scope mob list), Tess (acceptance plan keyed to mvp-scope ACs), Devon (tech-stack lock for export presets and CI).

## 2026-05-02 — Top 5 risks logged in risk register

- Decided by: Priya
- Decision: Risk register lands at `team/priya-pl/risk-register.md`. Top 5 active risks: R1 save migration breakage, R2 Tess sign-off bottleneck, R3 Godot HTML5 export regression, R4 scope creep into M1, R5 concurrent-agent merge collisions. Plus 4 watch-list items (Uma art bottleneck, affix balance sinkhole, boss state-machine complexity, Sponsor-finds-bug-at-sign-off). Each risk has probability, impact, mitigation, trigger / signal, and owner.
- Why: Closing week-1 deliverable per `mvp-scope.md` and the week-1 backlog (`86c9kwhyy`). Risk register is a heartbeat-tick artifact — orchestrator scans for `blocker`-severity bugs that pattern-match a risk and escalates the risk's probability accordingly. Watch-list keeps lower-priority risks visible without crowding the top 5.
- Reversibility: rolling document — risks added, retired, re-scored as M1 progresses.
- Affects: orchestrator (heartbeat scan target), Priya (rolling owner), all roles (each risk has a named owner).
- Detail: `team/priya-pl/risk-register.md`.

## 2026-05-02 — Secret-free M1 RC build path lands

- Decided by: Devon (per dispatch authority — CI / release tooling)
- Decision: New workflow `.github/workflows/release-github.yml` produces an HTML5 build, zips it, and either uploads it as a workflow artifact (manual dispatch) or attaches it to a GitHub Release (tag pushes matching `v*-rc*` / `v*-m1-*` / `m1-rc*`). Uses the same `barichello/godot-ci:4.3` container as `ci.yml`. Requires no secrets — works without `BUTLER_API_KEY` / `ITCH_USER` / `ITCH_GAME`. Ships alongside `release-itch.yml` (which still requires those secrets); whichever has its prerequisites met can run. `export_presets.cfg` was authored and committed (HTML5, Windows Desktop, Linux/X11, macOS — preset names matched to both workflows' matrix entries) and removed from `.gitignore` so the file actually tracks. Paired sanity test `tests/test_export_presets.gd` asserts the preset file and required preset names are present (catches workflow-vs-preset name drift at unit-test time, not in a 3-minute-failed CI run).
- Why: Sponsor hasn't set up itch.io secrets and isn't here to. M1 sign-off needs a build path that produces a Tess-downloadable artifact today. HTML5-only on purpose — Windows/macOS/Linux exports remain in `release-itch.yml` for when secrets exist; M1 sign-off only needs HTML5.
- Reversibility: reversible — workflow can be deleted once `release-itch.yml` is unblocked, or merged into it. Preset file stays either way.
- Affects: Tess (download path documented in `team/devon-dev/m1-rc-build.md`), orchestrator (gets a stable artifact URL to surface to Sponsor when M1 RC is ready), all devs (can `gh workflow run release-github.yml` from any branch to produce a smoke-build).
- Detail: `team/devon-dev/m1-rc-build.md`, ClickUp `86c9ky4fv`.

## 2026-05-02 — Level-up curve locked: 100 * level^1.5, cap L5

- Decided by: Devon (per dispatch authority — XP / level math owns the curve; flagged for Drew/Tess as combat-balance dependency)
- Decision: M1 character XP curve is **`xp_to_next(level) = floor(100 * level^1.5)`** with cap at **L5**. Per-level XP costs:
  - L1 -> L2: 100 XP
  - L2 -> L3: 282 XP
  - L3 -> L4: 519 XP
  - L4 -> L5: 800 XP
  - **Total: 1701 XP to cap**.
  Implementation lands as `Levels` autoload (`scripts/progression/Levels.gd`) with `gain_xp(amount)`, `current_level()`, `xp_to_next()`, signals `xp_gained(amount)` + `level_up(new_level)`. XP gain is wired to mob death via `Levels.subscribe_to_mob(mob)` which reads `mob_def.xp_reward` from the `Grunt.mob_died` signal payload. DebugFlags fast-XP multiplier is applied exactly once, inside `Levels.gain_xp()` — single source of truth, gameplay code stays multiplier-naive. Save schema bumps **v1 -> v2** to add `character.xp_to_next` (HUD convenience field; derived from level). Migration mirrors the curve constants in `Save.gd` so a save authored under a future curve revision is identifiable from the schema_version alone.
- Why: Quadratic-ish (`x^1.5`) gives a noticeable but not punishing climb. Pure linear feels grindy at the top; pure quadratic (`x^2`) makes L5 feel out of reach in M1's tiny content footprint (1 stratum, 1 mob — `xp_reward=10`). `BASE_XP=100` matches Drew's grunt reward so L1 -> L2 is ~10 grunts, fast enough to feel the loop in M1 playtests. With DebugFlags fast-XP `100x`, Tess can reach L5 in ~2 minutes per the `m1-test-plan.md` AC4/AC7 budget.
- Reversibility: reversible until Drew pins boss DPS targets to per-level player stat budget (week 2 N6) and Tess writes the AC4/AC7 acceptance cases against specific XP totals. Sticky after that.
- Affects: Drew (combat-balance — boss DPS and grunt scaling key off the level curve), Tess (acceptance tests assert XP totals at specific levels; M1-AC4 reaches L4-5), Uma (level-up panel HUD reads `current_xp / xp_to_next` for the bar), Save schema (v1 -> v2 migration adds `xp_to_next`; v0 -> v1 -> v2 chains cleanly).
- Detail: `scripts/progression/Levels.gd`, `tests/test_levels.gd`, ClickUp `86c9kxx2t`.

## 2026-05-02 — Stratum-1 boss numbers locked

- Decided by: Drew (per dispatch authority — boss AI internals + phase HP weights, per `86c9kxx4t` task spec).
- Decision: Stratum-1 boss (`Warden of the Outer Cloister`) ships with **600 HP, 15 base damage, 80 px/s base move speed**. Phase HP weights — segments-lie-about-HP per Uma's `boss-intro.md` design — are **P1 = 50%, P2 = 30%, P3 = 20%** of max HP, with phase transitions firing at literal **66% (HP=396)** and **33% (HP=198)** thresholds. Phase 1 = telegraphed melee swing only. Phase 2 = melee + ground-slam AoE (radius 80 px, 0.5 s windup). Phase 3 = enraged: same two attacks, **+50% movement speed**, **−30% attack recovery**; no new mechanic per M1 scope. Phase-transition window is 0.6 s during which the boss is both **stagger-immune AND damage-immune** (the `take_damage` path early-returns) — this is the load-bearing guard against rapid-hit-spam double-triggering the next phase. Boss respects `STATE_DORMANT` during the 1.8 s entry sequence (no attack, no damage taken) per Uma BI-19. Boss starts in `STATE_DORMANT` until the boss-room's door trigger fires the entry sequence; sequence-end calls `boss.wake()`. Loot table `boss_drops.tres` ships **iron_sword + tier_modifier=2 (T3)** and **leather_vest + tier_modifier=1 (T2)** with `weight = 1.0` (independent-roll mode) so the climax loot moment is guaranteed-drop. New signals: `phase_changed(new_phase)`, `boss_died(boss, position, mob_def)`, `boss_woke()`. The `boss_died` payload is shape-compatible with Grunt/Charger's `mob_died` so `MobLootSpawner.on_mob_died` reuses unchanged.
- Why: Task spec gave 600 HP / 3 phases / 66+33% transitions / phase-2 = melee+slam / phase-3 = enrage / no-new-mechanic / 0.6 s slow-mo / segments-lie. The numbers below are Drew's calls within those constraints. **Boss HP locks the M1 difficulty curve**: with player light = 8 dmg, heavy = 18 dmg (`Player.gd`), a player using only light attacks needs 75 connections; mixing in heavies brings it to ~30–40 — well inside the AC4 "10 minutes once gear-appropriate" budget. With Devon's level-up curve (2026-05-02 entry above) cap at L5 (1701 XP total) and grunt `xp_reward=10`, the player will be at L4-5 entering the boss room — the boss HP target was sized for that level budget. Phase weights non-equal because phase 3 is intentionally short and frantic per Uma's design; equal segments would make phase 3 feel like a slog instead of a desperate sprint to the kill. Stagger-immune-during-transition guard is the testing-bar §6 edge probe ("rapid input doesn't double-trigger") elevated to a spec-level invariant — without it, hit-spam past 66% could land 5 hits in the same physics tick and immediately fall through to phase 3, which contradicts Uma's beat-pacing intent.
- Reversibility: reversible — HP, damage, speeds, recovery multipliers all live in `Stratum1Boss.gd` constants and `stratum1_boss.tres`. Phase boundary fractions (66 / 33) are constants too. Balance-pass tweaks won't touch the schema. Phase HP weights (50/30/20) are documented in code comments so a future re-balance is one-line.
- Affects: Devon (level-up math N1 already locked above; boss HP target sized to that curve's L4-5 entry budget); Tess (acceptance test: AC #6 boss-defeatable validated by `tests/test_stratum1_boss.gd` + `tests/test_stratum1_boss_room.gd` — 30+ paired tests covering all 12 task-spec coverage points; soak: kill the boss after the entry sequence, verify loot drops + door unlocks); Uma (boss display name `WARDEN OF THE OUTER CLOISTER` matches `MobDef.display_name`; boss-defeated cinematic layer subscribes to `Stratum1BossRoom.boss_defeated` signal).
- Detail: `scripts/mobs/Stratum1Boss.gd`, `scripts/levels/Stratum1BossRoom.gd`, `resources/mobs/stratum1_boss.tres`, `resources/loot_tables/boss_drops.tres`, ClickUp `86c9kxx4t`.

## 2026-05-02 — Damage formula constants locked

- Decided by: Devon (per dispatch authority — combat math, per `86c9kxx3m` task spec).
- Decision: M1 damage formulas live in `scripts/combat/Damage.gd` as a pure-static utility. Player-attack damage = `floor(weapon_base * (1 + edge * 0.05) * (1 + attack_type_mult))` where `attack_type_mult` is **0.0 for light, 0.6 for heavy** (heavy is 1.6x light at the final step). Mob-attack damage = `floor(mob_base * (1 - clamp(vigor * 0.02, 0, 0.5)))` — Vigor mitigates 2% per point, capped at **50%** total mitigation (no immortality). Fist (no weapon) is **flat 1 damage** with no Edge/heavy scaling. Player.gd reads its `_equipped_weapon` + `_edge` at attack time; mobs (Grunt/Charger/Shooter/Stratum1Boss) read the player's `get_vigor()` at swing/projectile spawn time. Mob-specific multipliers (Grunt's HEAVY_DAMAGE_MULTIPLIER 1.8x, boss's MELEE_DAMAGE_MULTIPLIER 1.0x / SLAM_DAMAGE_MULTIPLIER 1.4x) stack *on top of* the formula output — they're attack-shape decisions, not part of the formula. Affix system (ticket `86c9kxx5p`) will mutate `weapon_base` upstream of the formula per `AffixDef.apply_mode` (ADD vs MUL); the formula itself stays affix-naive.
- Why: A multiplicative Edge model (`+5% per point`) keeps Edge competitive across tiers — `+1 flat per point` (the alternative tooltip-suggested model) makes Edge dominant on a T1 dagger and irrelevant on a T3 sword (a +1 to a 3-dmg dagger is +33%, a +1 to a 20-dmg sword is +5%). Heavy 1.6x is the typical ARPG ratio (Diablo II two-handed feel; pairs with Player's HEAVY_RECOVERY at 2.2x LIGHT_RECOVERY so DPS still slightly favors light chains). Vigor 2% per point with a 50% cap protects against late-game high-Vigor builds going undamageable; at M1's L5 cap (~10-15 vigor allocation realistic) that's 20-30% mitigation — meaningful but not trivializing. Floor (not round) on output matches the existing damage_base / hp_base int contract; round-half-up would silently inflate apparent damage by 1 at boundary values. Boss HP balance (Drew, 600 HP) still holds: L4-5 player with a T2/T3 weapon at edge=10-15 lands a similar combat-time budget as the old flat constants gave (8 dmg light / 18 dmg heavy), with more variance based on gear — which is the whole point of the gear ladder.
- **Reconciliation with Uma's level-up panel copy** (`team/uma-ux/level-up-panel.md`): Uma's tooltip preview line for Edge says `+1 damage per point` — that's a *display approximation* for the player. The actual derivation is multiplicative per the formula here. At Edge=10 with a 10-dmg weapon, the formula gives `+5 weapon damage` (not `+10`) for light attacks; the tooltip preview value is a Uma-design call she'll refine post-iteration as the gear curve is balanced. Flagged as a follow-up for Uma's next pass on `level-up-panel.md` — the *tooltip number* should derive from the formula at runtime once equipment + Edge are wired into the panel (week-2/M2 work). Uma is informed via the next `chore(state)` flush.
- Reversibility: reversible — all four constants (`EDGE_PER_POINT`, `HEAVY_MULT`, `VIGOR_PER_POINT`, `VIGOR_CAP`) are explicit and live at the top of `Damage.gd`; balance-pass tweaks are one-line. The *formula shape* (multiplicative on Edge / additive on Vigor) is sticky once Drew pins balance and Tess writes AC4/AC7 acceptance tests against specific damage totals.
- Affects: Drew (combat balance — mob `damage_base` values plug into the formula unchanged; the per-mob heavy/slam multipliers in Grunt/Boss stack on top), Tess (acceptance tests against the formula via `tests/test_damage.gd` + integration via `test_player_attack.gd`), Uma (level-up-panel tooltip preview math is now derivable from the formula — flagged for her next pass), affix system author (next ticket `86c9kxx5p`: weapon_base is the affix mutation target, formula stays affix-naive).
- Detail: `scripts/combat/Damage.gd`, `tests/test_damage.gd`, ClickUp `86c9kxx3m`.

## 2026-05-02 — Descend preserves full character state (distinct from M1 death rule)

- Decided by: Drew (per dispatch authority — stratum-exit + descend mechanics, per `86c9kxx6z` task spec).
- Decision: When the player chooses to descend via the **StratumExit** portal (boss defeated → portal active → walk into area + press E), the run carries over **everything**: character level, XP, equipped items, AND unequipped inventory. This is **deliberately different** from the M1 death rule (`team/uma-ux/death-restart-flow.md` + DECISIONS.md 2026-05-02 entry "M1 death rule"), which specifies *level + equipped persist; unequipped inventory virtually-stashed in M1*. **Descending is not death** — the player succeeded at this stratum and is walking through to the next. There is no "Lost With The Run" framing because nothing was lost. For M1 the descend screen is a placeholder ("Stratum 2 — Coming in M2") with a single "Return to Stratum 1" button that loops the demo with the full character intact; M2 will replace the placeholder with the actual stratum-2 first-room load. The stratum exit itself ships INACTIVE on room load and is `activate()`d by `Stratum1BossRoom._on_boss_died`. Descend mechanics: rapid-mash idempotent (`descend_triggered` is one-shot), prompt visibility tied to `is_active() && is_player_in_range()`, fade screen is a CanvasLayer at z-layer 100 with 0.6 s fade-in (slightly slower than the death screen's 0.4 s panel fade — descent is intentional, give it weight; player chose it, so the timing is gentler not punishing).
- Why: The M1 death rule's "lose unequipped inventory" framing is a teaching moment about stash UI that doesn't yet exist (Uma's M2 stash design). Applying that same penalty to a *successful* descent would be design malpractice — the player would learn "winning still costs me items," which inverts the intended reward signal. The split makes the loop coherent: **death = lose-something-meaningful (the unequipped inventory, even if M1 virtually-keeps it as a teaching grace)**, **descend = lose-nothing (you earned the floor below)**. This also keeps M1 → M2 forward-clean: when M2 lands actual stratum-2 content, the descend path's "carry everything forward" becomes the natural runtime contract — nothing has to change semantically. The 0.6 s fade timing is Drew's call within the task's "your call" authority — Uma's `death-restart-flow.md` Beat D references 0.4 s for the death-panel fade; descent gets +0.2 s because the moment is celebratory rather than corrective and the longer hold sells "you crossed a threshold." If Uma's microcopy/timing pass calls for a different value during her copy/microcopy sweep, the constant moves; nothing else has to change.
- Reversibility: reversible — `DescendScreen.FADE_DURATION` is a constant; the "carry-everything" rule is enforced by *absence* of any state-clearing code in the descend path (no test asserts a clear, because there isn't one to assert). When M2 replaces the placeholder with actual stratum-2 content, the rule still applies because there's nothing in `DescendScreen.gd` or `StratumExit.gd` that would clear state on its own.
- Affects: Devon (when game-flow code wires `DescendScreen.restart_run` to a level reload, the existing player/inventory/Levels state is implicitly preserved — `Save.save_game()` is not called as part of the descend path, but a new run via the descend loop runs against the already-in-memory state); Uma (microcopy/timing pass owns the final fade duration + button label); Tess (acceptance: paired tests `tests/test_stratum_exit.gd` + `tests/test_descend_screen.gd` cover all 9 task-spec coverage points — see ClickUp comment); Priya (forward-plan: when M2 stratum 2 lands, the same `DescendScreen` is replaced wholesale with `Stratum2Room01.tscn` load; the `StratumExit` script + scene are reusable across all 8 strata).
- Detail: `scripts/levels/StratumExit.gd`, `scenes/levels/StratumExit.tscn`, `scripts/screens/DescendScreen.gd`, `scenes/screens/DescendScreen.tscn`, `tests/test_stratum_exit.gd`, `tests/test_descend_screen.gd`, ClickUp `86c9kxx6z`.

## 2026-05-02 — Stratum-1 rooms 02..08 layout + RoomGate + StratumProgression

- Decided by: Drew (per dispatch authority — level layouts, mob mixes, gate mechanics, per `86c9kxx6c`).
- Decision: Seven new rooms ship for stratum 1, connecting Room 01 (existing tutorial) to the boss room. Mob counts per room: r02=2 grunts, r03=1 grunt + 1 charger, r04=1 shooter, r05=2 grunts + 1 charger, r06=2 chargers + 1 shooter (+ healing fountain reward), r07=2 chargers + 2 shooters, r08=1 grunt + 1 charger + 2 shooters (pre-boss density). Total: **19 mobs across rooms 2-8** (within the 14-30 dispatch-spec band). All seven rooms share one `Stratum1MultiMobRoom.gd` script (data-driven from `LevelChunkDef`); each `s1_room0N.tres` carries the mob spawn list + entry/exit ports. Each chunk uses 15x8 tiles (480x256 px, fits Uma's 480x270 canvas). Entries on WEST edge tile (0,4); generic exits on EAST edge tile (14,4) tagged `&"exit"`; r08's terminal port tagged `&"boss_door"` (level-flow controller swaps to `Stratum1BossRoom.tscn` on that handoff). New `RoomGate` scene/script locks behind the player on entry and unlocks on full clear (signal-driven via `mob_died`); zero-mob rooms auto-unlock; late mob registration tracked. New `StratumProgression` autoload tracks cleared rooms in the current run, persists via `Save.gd` envelope (`data["stratum_progression"]["cleared_rooms"]`), resets on death, preserves on descend.
- Why: One shared room script (instead of seven near-duplicate Room0N.gd files) keeps the variation in chunk TRES data — same data-driven spirit as `LevelChunkDef`. Difficulty curve increases roughly monotonically with one valley at r04 (lone shooter as ranged-threat introduction) — matches dispatch guidance and gives the player time to internalize each archetype before being mixed. Healing fountain in r06 (mid-stratum) is the standard ARPG "rest stop" before the harder back-half (r07/r08) and the boss; 40 HP restore on a 100 HP cap is meaningful but not a full-heal, so the player still feels boss-room HP pressure. RoomGate uses `mob_died` signals (not poll-based presence checks) so off-screen kills count and rapid-burst deaths are all tallied — meets the dispatch's three edge-case requirements at the test level. StratumProgression as an autoload (not embedded in `Save.gd`) keeps the save schema stable: progression tucks under a single key the migration code already tolerates as missing.
- Reversibility: reversible — mob counts/positions live entirely in TRES files; difficulty-curve tweaks are one-line edits per room. RoomGate behavior + StratumProgression API are stable shape; their internals can swap (e.g. a future "all enemies dormant on entry, wake-on-cross" variant) without touching the chunk data.
- Affects: Devon (combat scaling — the formula now has a 19-mob stratum to validate damage budgets against; if grunt+charger+shooter HP/dmg need a balance pass, the room layouts give a more realistic test bed than r01 alone). Tess (M1-AC test cases for level progression — AC2 "engages enemies in stratum 1" now exercisable across 7 rooms, not just 1; AC4 "combat math" gets a wider test surface; new test files `test_stratum1_rooms.gd` + `test_room_gate.gd` + `test_stratum_progression.gd` add coverage for the level-flow loop). Uma (no UX surface change in M1; if she wants room-specific names on the HUD, the `display_name` slots on each chunk are already authored ("Outer Cloister — Antechamber", etc.)). Save schema (`data["stratum_progression"]` is a new top-level key; backward-compatible with v1/v2 saves via `restore_from_save_data` defaulting to empty progression).
- Detail: `scripts/levels/Stratum1MultiMobRoom.gd`, `scripts/levels/RoomGate.gd`, `scripts/levels/HealingFountain.gd`, `scripts/progression/StratumProgression.gd`, `resources/level_chunks/s1_room02.tres` through `s1_room08.tres`, `scenes/levels/Stratum1Room02.tscn` through `Stratum1Room08.tscn`, `scenes/levels/RoomGate.tscn`, `scenes/levels/HealingFountain.tscn`, `tests/test_stratum1_rooms.gd`, `tests/test_room_gate.gd`, `tests/test_stratum_progression.gd`. ClickUp `86c9kxx6c`.

## 2026-05-02 — Save schema v2 -> v3: stat-allocation block + level-up gate

- Decided by: Devon (per dispatch authority — save schema bump is per task brief authority, with cross-role broadcast).
- Decision: Save schema bumps **v2 -> v3** for the stat-allocation UI (`86c9kxx2y`). New `character.stats: {vigor: int, focus: int, edge: int}` block (defaults `{0, 0, 0}`), new `character.unspent_stat_points: int` (default 0), new `character.first_level_up_seen: bool` (default false — one-shot gate per Uma's `level-up-panel.md` LU-05/LU-06 auto-open rule). The legacy v2 flat fields (`character.vigor`/`focus`/`edge`) are retained as compat shadow during the v2 -> v3 migration so older saves and the existing `test_save_roundtrip.gd` pre-existing assertions pass unchanged. Going forward `character.stats` is the canonical surface (via `PlayerStats.snapshot_to_character` / `restore_from_character`). Migration v2 -> v3 lifts existing flat values into `stats` so no data is lost. v0 -> v1 -> v2 -> v3 chain still passes existing tests.
- Why: The flat character.vigor / focus / edge fields can't carry the new `unspent_stat_points` bank that Uma's spec requires, and an autoload-per-stat (PlayerStats) needs a dedicated namespace under character to round-trip cleanly. The first_level_up_seen flag must persist across run-death (the M1 death rule keeps level + character; the auto-open beat must not repeat after a wipe), so the save is the right home — not an in-memory autoload.
- Reversibility: reversible — schema is a one-line bump; adding fields to v3 (e.g. crit allocations) is additive. Removing the v2 flat fields would be a future v3 -> v4 cleanup once no consumer reads them; doing it now would break test_save_roundtrip.gd pre-existing assertions.
- Affects: Devon (PlayerStats autoload, StatAllocationPanel writes via Save.save_game), Drew (no surface change), Tess (paired test `test_player_stats.gd` covers v0 -> v1 -> v2 -> v3 chain + fresh start defaults; `test_stat_allocation.gd` covers the panel; existing `test_save_migration.gd` and `test_save.gd` updated to assert SCHEMA_VERSION=3). New autoload `PlayerStats` registered in `project.godot`.
- Detail: `scripts/save/Save.gd` (`_migrate_v2_to_v3`), `scripts/progression/PlayerStats.gd`, `scripts/ui/StatAllocationPanel.gd`, `content/ui/stat_strings.tres`, ClickUp `86c9kxx2y`.

## 2026-05-02 — Affix system T1 wired to V/F/E + move_speed (no save-schema bump)

- Decided by: Drew (per dispatch authority — affix application internals, per `86c9kxx5p` task spec).
- Decision: Three M1 affixes wired with these stats and ranges (ADD-only — MUL-mode is M2):
  - `swift`  → `move_speed` ADD, T1 +2..+5, T2 +5..+9, T3 +9..+14 (px/s flat)
  - `vital`  → `vigor`      ADD, T1 +5..+15, T2 +15..+25, T3 +25..+40
  - `keen`   → `edge`       ADD, T1 +1..+3, T2 +3..+6, T3 +6..+10
  Affix application math (per `team/drew-dev/affix-application.md`): for V/F/E stats handled by `PlayerStats`, `effective = max(0, base + add_sum) * (1 + mul_sum)`, `int_effective = int(floor(effective))`. MUL is summed-then-applied (NOT multiplicative-stacking) for predictable tooltip math; multiplicative stacking is a balance-pass call. For Player-local `move_speed`, ADD increments a `_move_speed_bonus` field on Player; `get_walk_speed()` returns `WALK_SPEED + _move_speed_bonus`. New `Player.equip_item(ItemInstance)` / `unequip_item(slot)` API walks `rolled_affixes` and pumps `PlayerStats.apply_affix_modifier` / `clear_affix_modifier`. Re-equip same instance is idempotent (no double-application); equip a different instance into an occupied slot auto-unequips the previous one first. The legacy `Player.set_equipped_weapon(ItemDef)` is retained for back-compat with `test_player_attack.gd` etc.; `equip_item` is the affix-aware path. No save schema bump (v3 already names `rolled_affixes` in stash entries). New `ItemInstance.to_save_dict` / `from_save_dict(data, item_resolver, affix_resolver)` produce/consume the existing v3 stash shape.
- **Reconciliation with affix-count-by-tier:** ticket spec sketched "N=1 for T1, 2 for T2, 3 for T3" but the existing `team/drew-dev/tres-schemas.md` § "Affix count by tier" specifies T1=0 / T2=1 / T3=1–2 — and `LootRoller.affix_count_for_tier` plus `tests/test_loot_roller.gd` already lock that contract. Honored the existing schema (T1=0, T2=1, T3=1–2) over the ticket sketch. Tests/balance can revisit during Priya's `86c9kxx61` balance pass without code change.
- **Reconciliation with previously-authored affixes:** the swift/vital/keen .tres files Drew authored in run-002 used `move_speed_pct (MUL)` / `max_hp (ADD)` / `crit_chance (ADD)` — those stat names had no M1 hookup (PlayerStats only knows V/F/E; max_hp/crit_chance live on items, not the player). Switched to V/F/E + move_speed which makes affixes affect combat the player feels. The numeric ranges shift accordingly (flat-ADD integers calibrated to PlayerStats's allocation magnitudes, not multiplier fractions). T2 and T3 ranges scale per the schema doc's "monotone non-decreasing" guidance.
- Why: Affixes that don't affect anything in M1 are not affixes — they're TRES placeholder noise. The damage formula doc (`scripts/combat/Damage.gd`) already anticipated affixes mutating "weapon_base via stat_modified == &"damage_flat"" — but M1 doesn't ship those affixes; the V/F/E route gives the same behavioral lift (affix → +edge → multiplicative damage bump via the existing `EDGE_PER_POINT = 0.05` term) without adding a new code path in `Damage.gd`. Routing affixes through PlayerStats (not directly into Player) means save round-trip is automatic — base V/F/E is already in v3, and affix modifiers re-derive on load from the equipped items' rolled affixes (no new persisted state). PlayerStats.apply_affix_modifier with a clear_affix_modifier counterpart (vs. a single set_modifier) lets us reverse-by-arguments — no per-source bookkeeping in PlayerStats itself, and the player code (which knows what it equipped) owns the matching pair. Summed-then-applied MUL keeps tooltip math additive (two +5% = +10%) for M1 player-facing predictability; switching to multiplicative-stacking is a one-liner in `get_stat`. No save-schema bump because the v3 stash entry already specifies `rolled_affixes` — we're filling in the path between the on-disk shape and the runtime application.
- Reversibility: reversible — T1/T2/T3 ranges live entirely in `resources/affixes/*.tres` (Priya's `86c9kxx61` balance pass is a 6-number edit). Affix-count-by-tier lives in `LootRoller.affix_count_for_tier` (already there). The ApplyMode formula (additive-then-MUL) lives in 3 lines of `PlayerStats.get_stat`; switching to multiplicative-stacking is a one-line change. The `equip_item`/`unequip_item` API is back-compat (additive — `set_equipped_weapon` still works for tests that don't care about affixes).
- Affects: Devon (Damage.gd unchanged — affix bonuses ride through the existing get_edge / get_vigor reads from PlayerStats; Player.gd gains slot-aware equip API; PlayerStats gains apply/clear_affix_modifier API + get_base_stat). Tess (paired tests: `tests/test_affix_system.gd` 11 cases covering all 10 task-spec coverage points + edge cases; `tests/test_loot_affix_integration.gd` 4 cases covering loot-drop + save round-trip). Priya (balance pass `86c9kxx61` consumes the same .tres files; no code change to fold balance numbers in). Uma (`ItemInstance.get_affix_display_lines` + `get_base_stats_display_lines` produce strings the inventory hover panel will render — Devon wires the panel later).
- Detail: `scripts/loot/ItemInstance.gd`, `scripts/progression/PlayerStats.gd`, `scripts/player/Player.gd`, `resources/affixes/{swift,vital,keen}.tres`, `team/drew-dev/affix-application.md`, `tests/test_affix_system.gd`, `tests/test_loot_affix_integration.gd`. ClickUp `86c9kxx5p`.

## 2026-05-02 — Mid-week-2 retro + week-3 scope

- Decided by: Priya
- Decision: Week 2 closed conceptually with **16 / 21 tickets shipped** + 3 in flight + 2 acceptable non-backlog adds (release-github CI, audio direction) + 1 spec-deviation follow-up filed (`86c9kyntj`). Critical-path order (save → level-up → damage → affix → boss) held without rework. **Week-3 scope locked** at `team/priya-pl/week-2-retro-and-week-3-scope.md`: Half A — M1 close (7 tickets: inventory+HUD wiring N9 carry, affix balance N8 carry, integration GUT B5 carry, CI hardening B3 carry, NEW HTML5 RC re-soak W3-A5, post-Sponsor-soak bug bash B1 re-scoped, NEW worktree-isolation v3 W3-A7); Half B — M2 onset (4 design/scaffolding tickets: stash UI design, stratum-2 chunk lib scaffold, stratum-2 palette/biome direction, persistent character meta v1 schema design). **Risk register re-scored**: top 3 are now R6 (NEW — Sponsor-found-bugs flood when soak resumes), R3 (escalated — HTML5 regression on RC4/RC5+), R7 (NEW, promoted from W2 — affix balance sinkhole). R1/R2/R4/R5 demoted to watch-list rotation. **Three things didn't go well**: no true human soak yet (Sponsor OUT, Tess no local Godot), worktree HEAD-pinning is still leaky (4 incidents now), affix-count spec deviation in N7 surfaced a looser-than-needed spec habit. **What we're doing about it**: pre-pin balance tables BEFORE features ship (`team/priya-pl/affix-balance-pin.md` is a week-3 deliverable from Priya); land worktree-isolation v3 in week-3 W3-A7; reserve B1 + 2 dev ticks in week-3 capacity for Sponsor-soak fix-forward; explicit HTML5 re-soak ticket on next RC.
- Why: Week-2 throughput overshot the plan, which makes M1 close in week 3 realistic — but only if we don't load week 3 to the same capacity. R6 (Sponsor flood) is the new dominant week-3 risk: a 30-min interactive run on this much new surface routinely surfaces 3-8 bugs. Pre-pinning the affix table prevents N8 from becoming a hand-tuning sinkhole. Worktree-isolation v3 stops a recurring tax on every Priya-class long-form run (the documented 4th incident happened during this very retro PR).
- Reversibility: reversible — retro framing is rolling; week-3 scope is editable per ClickUp ticket; risk re-scores get re-scored at week-3 close.
- Affects: all roles. Devon (W3-A1 inventory+HUD wiring, W3-A4 CI hardening, possibly W3-A7 worktree-v3, W3-B4 M2 schema design); Drew (W3-A2 affix balance using Priya's pre-pinned table, W3-B2 stratum-2 chunk lib scaffold); Tess (W3-A3 integration GUT, W3-A5 HTML5 re-soak, W3-A6 post-Sponsor bug bash); Uma (W3-B1 stash UI design, W3-B3 stratum-2 palette); Priya (`affix-balance-pin.md` pre-deliverable; week-3 close retro); orchestrator (W3-A7 dispatch ownership call, capacity protection for R6 fix-forward).
- Detail: `team/priya-pl/week-2-retro-and-week-3-scope.md`, `team/priya-pl/risk-register.md` (re-scored), ClickUp `86c9kxx94`.

## 2026-05-02 — Affix balance pinned for M1 (paper-only)

- Decided by: Priya (per dispatch authority — all affix-balance numerical decisions; pre-deliverable ahead of Drew's `86c9kxx61` balance pass per the R7 mitigation logged in week-2-retro-and-week-3-scope.md).
- Decision: M1 affix balance is **pinned as currently shipped** — Drew's run-005 ranges hold (swift `move_speed ADD` 2-5/5-9/9-14, vital `vigor ADD` 5-15/15-25/25-40, keen `edge ADD` 1-3/3-6/6-10) **with no edit** to `resources/affixes/*.tres`. Affix-count-by-tier holds at **0 / 1 / 1-2** (Drew's call) — Tess's follow-up `86c9kyntj` resolves as **Option A "no change"**, ticket flips to complete with `team/priya-pl/affix-balance-pin.md` as the rationale (the ticket-spec sketch of 1/2/3 was rejected because the M1 pool size of 3 makes T3=3-affixes a no-choice tier, killing the loot-chase feel; the hybrid 0-1/1-2/2-3 was rejected because T1=0 is the design-intentional "you got loot" floor signal, and breaking 8 already-green test_loot_roller cases for theoretical T1 variance is poor ROI). Drop weights for stratum-1 common mobs **shift** from the current 2-entry independent-roll table to a **6-entry tier-varied table** (each base item × T1/T2/T3 variant via `tier_modifier`) producing a 70/25/5 T1/T2/T3 distribution conditional on a drop, with 51% any-drop / 17% T2+ / 3% T3 per kill — tunes 19 stratum-1 mobs to deliver ~9-10 drops / ~2-3 T2 / ~0-1 T3 per soak. Boss drops hold (T3 sword + T2 vest, weight 1.0 each — already correct, no edit). Player-feel acceptance targets pinned in §4 of the doc (L1 grunt ≤9 light or ≤6 mixed hits, L5 fully-geared grunt ≤4 light or ≤3 mixed hits, L5 fully-geared boss ≤60s) — these are RC-soak observations, not pre-merge gates; bug-bounce threshold = 2x deviation only. M2 hooks confirmed clean (tier-array-length, apply_mode enum, stat_modified StringName dispatch, count-by-tier match-arm, drop-weight tier-spread pattern, set-bonuses-as-item-level — all forward-extensible without M1-side rework).
- Why: Pre-pinning numbers BEFORE Drew picks up `86c9kxx61` is the explicit R7 mitigation from the mid-week-2 retro — the worry was "balance pass becomes a hand-tuning sinkhole on a fresh dev run." Pinning the existing values + writing the player-feel acceptance targets means Drew's path of least resistance is "verify against the pin during soak, edit `grunt_drops.tres` per §3, close the ticket." Most of the affix .tres values were already calibrated against the damage formula constants (`EDGE_PER_POINT=0.05`, `VIGOR_PER_POINT=0.02`, `VIGOR_CAP=0.5`) and Player.WALK_SPEED=120, so re-deriving them yielded the same numbers — the pin is documenting that derivation, not changing it. The drop-weight shift to tier-varied entries is the one actual content change the balance pass demands: the current table has no tier spread, so the dispatch's 70/25/5 target was unreachable without it. Holding to the schema's existing `tier_modifier` mechanism (vs adding a new field) keeps the change small. Resolving `86c9kyntj` here (vs leaving it open as a "balance-pass-time question") closes a follow-up loop and removes a soft commitment from the week-3 backlog.
- Reversibility: reversible — every number in the pin is a one-line TRES edit. Sticky decisions are the *shape* of the system (ADD-only affixes for M1; summed-then-applied MUL when M2 wires it; T3 = 1-or-2 affix roll, not 3) — both already documented as reversible in `affix-application.md`. The drop-weight table is a 6-line `grunt_drops.tres` rewrite if §4 soak data shows the spread is wrong. Player-feel acceptance targets are calibration signals, not contracts; they get re-scored at M1 RC sign-off.
- Affects: Drew (`86c9kxx61` balance-pass ticket — likely zero affix-tres changes, one `grunt_drops.tres` edit per §3 of the pin doc, then close the ticket; the pin doc IS the ticket's resolution). Tess (`86c9kyntj` flips to complete — Option A "no change" wins; M1 RC soak adds the §4 player-feel checks as observations, bug-bounce only on 2x deviation). Devon (no change — Damage.gd constants and PlayerStats stat keys stay; the pin operates entirely on content TRES files). Uma (no change — `ItemInstance.get_affix_display_lines` already produces the correct strings; tooltip ranges automatically reflect any future TRES edit). Priya (this is the R7 mitigation deliverable from the retro; lands ahead of Drew's `86c9kxx61` so the balance pass is paper-trivial; week-3 close retro will assess whether the pin held).
- Detail: `team/priya-pl/affix-balance-pin.md`, ClickUp `86c9kyntj` (Tess's follow-up resolved here), `86c9kxx61` (Drew's balance-pass ticket consumes this doc as input).

## 2026-05-02 — Stash UI v1 design locked: pickup-at-death-location ember-bag, 12×6 stash grid, B binding (context-sensitive in stash room). Detail: `team/uma-ux/stash-ui-v1.md`.
