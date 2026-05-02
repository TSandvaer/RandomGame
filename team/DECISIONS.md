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
