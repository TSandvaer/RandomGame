# Team State

This file is the orchestrator's source of truth between heartbeat ticks. Each role updates its own section; the orchestrator reads the whole file at every 20-min tick to spot stalls.

**Conventions:**
- Each section is owned by one role. Don't edit other roles' sections.
- Last-updated timestamp uses ISO date `YYYY-MM-DD`.
- "Stale" = no update for 2+ heartbeat ticks (~40 min) **while a tick was active**. Long gaps when the user is asleep / paused are not stale.

---

## Phase

`Phase 1 — MVP Build` (Week 1 of M1. Project is **Embergrave** — top-down 2D action-RPG dungeon crawler in Godot 4.3, browser-playable. Week-1 backlog of 20 tasks is live in ClickUp.)

---

## Priya (Project Leader)

- Last updated: 2026-05-02
- Status: idle (chunk done — run 003: week-1 close-out + week-2 promotion landed)
- Working on: —
- Blocked on: —
- Deliverables this run: (a) **Week-2 backlog promoted to ClickUp**: 20 new tickets created in list `901523123922` (N1–N14 + B1–B6) — IDs `86c9kxx2t` through `86c9kxx94`. Single carry-over `86c9kwhte` (butler) re-tagged with `week-2` while preserving `week-1`. Buffer ratio 6/21 = 28.6% (exceeds 20% floor per `TESTING_BAR.md`). Reality-correction logged: only 1 carry-over not 8 — Devon and Drew closed most of the draft's anticipated carry-over set in run 002/003. (b) **Risk register** at `team/priya-pl/risk-register.md` — top 5 (save migration, Tess bottleneck, HTML5 regression, scope creep, agent merge collisions) + 4 watch-list. (c) **v1 freeze** of `game-concept.md`, `tech-stack.md`, `mvp-scope.md` — `## v1 — frozen 2026-05-02` heading + change-policy stub on each. (d) Three DECISIONS.md entries appended: week-2 promotion, v1 freeze, risk register landing.
- Next: When dispatched again — week-2 mid-week retro (B6 ticket `86c9kxx94`) when week-2 has run a few ticks; consume any new cross-role calls from STATE.md; refresh risk register if any risks materialize. Once butler PR merges, drop `week-1` tag from `86c9kwhte` so it cleanly reads as `week-2` only.
- Note for orchestrator: no escalations from PL. Week-2 backlog is now dispatchable. Suggested first dispatches off the new tickets: Devon → N1 (`86c9kxx2t` level-up curve, anchor for progression chain), Drew → N4 or N5 (`86c9kxx3z` shooter / `86c9kxx46` charger — independent of save/loot, clean parallel). Tess → N12 save-migration test (`86c9kxx73`) once Devon's save schema is stable post-test-hooks merge. Uma → N13 / N14 design specs (`86c9kxx79` / `86c9kxx7e`) — both feed dev tickets so prioritize before mid-week.

## Uma (UX Designer)

- Last updated: 2026-05-02
- Status: idle (chunk done — run 003: audio direction one-pager + cue list landed)
- Working on: —
- Blocked on: nothing. One worktree branch-isolation incident this run (cherry-pick of audio-direction commit onto correct branch — `git checkout -b` after a contended worktree state landed me on `devon/levelup-math` HEAD instead of newly-created `uma/audio-direction`; recovered cleanly via cherry-pick + `git branch -f` to restore Devon's branch tip without losing his work). Same root cause as run-002's two incidents — shared `.git/HEAD` between the orchestrator-class checkout and worktree dispatches. Worked around without rewriting anyone else's history. Surfaced for orchestrator (third occurrence) — worktree-isolation v3 should pin HEAD per worktree.
- Deliverables this run: **PR #37 `design(audio): audio direction + cue list (M1 + M2 baseline)`** — `team/uma-ux/audio-direction.md` (234 lines). Locks aesthetic to **dark-folk chamber** (acoustic, sparse, small-ensemble — cellos + frame drum + felted piano + bronze bell + hurdy-gurdy drone + warm horn for climax; no synths, no orchestral, no chiptune; references Dark Souls 1 Firelink ambient, Hellblade chant-and-drone, Inside's almost-no-music discipline, Witcher 3 Skellige folk ensemble). Anchored against pixel-art house style — cello drone is audio cousin of vignette, bell is audio cousin of ember accent. Cue list table covers every M1+M2 audio event (60+ rows): SFX combat/player + mobs + items/world/UI, Music, Ambient — each with cue ID, type, trigger, mood, length, source plan (procedural / freesound / hand-Foley / hand-composed / AI-curated), priority (M1 must / M1 nice / M2). 5-bus structure (Master / BGM / Ambient / SFX / UI; Voice reserved M2+) with sidechain ducking spec (SFX→BGM -6 dB, SFX→Ambient -3 dB, hard-mute on death+boss-intro, soft duck on inventory open). Source-of-truth flow: `audio/<sfx|music|ambient>/<scope>/`, OGG Vorbis q5 SFX / q7 music+ambient, kebab-case `<bus>-<role>-<descriptor>.ogg` filename = cue ID. Matches the resolution+format discipline locked in `visual-direction.md`. 37-row tester checklist for Tess. Closes `86c9ky9ex`. PR self-merged per testing-bar exempt-design rule.
- Cross-role decisions to log in `DECISIONS.md` next dispatch (deferred this run to avoid contention on DECISIONS.md): (a) **audio aesthetic lock** (dark-folk chamber — constrains M3 scoring contract); (b) **5-bus + sidechain spec** (constrains Devon's eventual `AudioServer` setup); (c) **OGG Vorbis sole shipped format** with quality discipline (constrains every sourcing dispatch); (d) **cue-ID == filename** discipline (constrains Devon's audio-loader design — flat `cue_id → AudioStream` dict, no per-scene authoring).
- Next: When dispatched again — formally append the four audio cross-role decisions to `DECISIONS.md` (also still owe the run-002 visual-direction + M1-death-rule append, though orchestrator may have already handled). Copy/microcopy pass on all 8 docs after Devon implements scenes. Reference-board v2 once strata 2+ enter scope. M2 stash-UI design once M2 backlog promotes. Source-pass dispatch shape (single dispatcher vs split-by-source-type) is a question awaiting Priya's call — flagged in audio-direction.md "Open questions".

## Devon (Game Dev #1, lead)

- Last updated: 2026-05-02
- Status: idle (chunk done — run 003)
- Working on: —
- Blocked on: PR #19 (`feat(test-hooks)`) awaiting Tess sign-off + merge per `GIT_PROTOCOL.md`. ClickUp `86c9kxnqx` flipped to `ready for qa test`.
- Deliverables this run: PR #19 (`devon/testability-hooks`) — 5 testability hooks paired with 4 GUT test files (33 new tests). (1) Build SHA — `BuildInfo` autoload + CI stamp step in `ci.yml` and `release-itch.yml` writing `${GITHUB_SHA:0:7}` to `build_info.txt` (gitignored); rendered as `BuildLabel` footer in `Main.tscn` with `dev-local` fallback. `tests/test_build_sha.gd` (8 tests). (2) Fast-XP toggle — `DebugFlags` autoload listens for Ctrl+Shift+X (physical keycode); `xp_multiplier()` returns 100 vs 1; triple-gated by `OS.is_debug_build()`. 100x is a placeholder per task spec — flagged in PR body for Priya curve calibration. `tests/test_fast_xp_debug.gd` (9 tests). (3) Save-dir README — `Save.save_game()` writes `user://README.txt` (location, schema_version, clear-procedure) on every save. `tests/test_save_readme.gd` (6 tests). (4) Test-mode mob seed — `--test-mode` CLI / `EMBERGRAVE_TEST_MODE` env pins `DebugFlags.mob_spawn_seed()` to `0x7E57C0DE`; loot RNG (Drew's LootRoller) untouched. `tests/test_test_mode_seed.gd` (10 tests). (5) HTML5 console errors — verified Godot 4.3's default routes `print`/`push_error`/`push_warning` + uncaught script errors to browser `console.log`/`console.error`; no code change. Verification procedure for Tess in `team/devon-dev/debug-flags.md`. Plus `chore(decisions)` PR #20 — two appendix entries (testability-hooks decision + loot-RNG scope clarification), self-merged.
- Next: When dispatched again — Tess bounce-list (if any). Otherwise week-2 backlog per `team/priya-pl/week-2-backlog.md`: `export_presets.cfg` authoring (unblocks first real `release-itch.yml` run), level-up math + XP curve (Priya N1), damage formula (N3).

## Drew (Game Dev #2)

- Last updated: 2026-05-02
- Status: idle (chunk done — week-1 carry-overs all in `ready for qa test`)
- Working on: —
- Blocked on: nothing. Three PRs awaiting Tess sign-off; once #6 merges, #8 and #11 are unblocked. ClickUp MCP was reconnected mid-run by orchestrator (entries flushed); my new entries (drew/loot-roller commit) are still pending and will land alongside that PR's merge.
- Deliverables run-002:
  - **Task #8 — feat(mobs): grunt mob** (PR #6, `drew/grunt-mob`, CI green): `scripts/mobs/Grunt.gd` + `scenes/mobs/Grunt.tscn` + TRES schema implementation paired in per Priya's run-001 split (`scripts/content/{MobDef,ItemDef,ItemBaseStats,AffixDef,AffixValueRange,LootEntry,LootTableDef}.gd` + `tests/factories/content_factory.gd` + 7 authored seed TRES files: grunt, swift/vital/keen, iron sword, leather vest, grunt drops). 32 paired GUT tests across `test_grunt.gd` (18) and `test_content_factory.gd` (14) covering full state machine, all 3 required edge cases (rapid hit spam, death-mid-telegraph, death-while-pathing), heavy-telegraph one-shot, layer wiring, MobDef hot-swap, every factory + every authored TRES round-trip. CI failure (typed-array assignment + bare collision_layer) caught and fixed in same PR.
  - **Task #9 — feat(levels): stratum-1 first room + chunk POC** (PR #8, `drew/stratum1-first-room` stacked on grunt-mob, CI green): `scripts/levels/{LevelChunkDef,MobSpawnPoint,ChunkPort,LevelAssembler,Stratum1Room01}.gd` + `scenes/levels/Stratum1Room01.tscn` + `scenes/levels/chunks/s1_room01_chunk.tscn` + `resources/level_chunks/s1_room01.tres`. Architecture supports many chunks; M1 ships one. Mobs referenced by `mob_id: StringName` (decoupled from MobDef tree). 22 paired GUT tests across `test_level_chunk.gd` (16 unit) and `test_stratum1_room.gd` (6 integration). New design doc `team/drew-dev/level-chunks.md`.
  - **Task #10 — feat(loot): LootRoller + flagship coverage** (PR #11, `drew/loot-roller` stacked on grunt-mob): `scripts/loot/{LootRoller,AffixRoll,ItemInstance,Pickup,MobLootSpawner}.gd` + `scenes/loot/Pickup.tscn`. Both roll modes (independent + weighted-pick), determinism via `seed_rng(int)`, tier modifier clamping, Fisher-Yates affix pick without duplicates, ADD/MUL apply_mode. 28 paired GUT tests covering ALL 10 edge cases from the schema doc + 4000-roll weight-distribution band + tier-respect catch + T1/T2/T3 affix counts + duplicate-free + authored grunt drops integration + full Grunt.mob_died → spawner signal wiring.
- Decisions logged: none new in `DECISIONS.md` this run (all decisions Drew made are AI/level/loot internals per dispatch authority — captured in code comments + design doc `team/drew-dev/level-chunks.md`).
- Next: Tess sign-off + merge of PRs #6/#8/#11 in order. Once `drew/grunt-mob` merges, the stacked PRs (#8 #11) will need to retarget if they don't auto-clean — Drew will rebase on next dispatch if needed. Then week-2 backlog per `team/priya-pl/week-2-backlog.md`: 2 more mob archetypes (shooter, charger), stratum-1 boss, balance pass on affix value ranges (placeholders awaiting Priya pin).

## Tess (Tester)

- Last updated: 2026-05-02
- Status: idle (chunk done — run 005)
- Working on: —
- Blocked on: nothing. Worktree contention with concurrent agents was rough this run — the shared `C:/Trunk/PRIVATE/RandomGame` worktree had its HEAD bouncing across 5+ branches mid-run (drew/shooter-mob, drew/charger-mob, uma/level-up-panel, uma/boss-intro, devon/m1-rc-build) due to other-agent checkouts in the same directory. My commit `9ae9167` initially landed on `drew/shooter-mob` HEAD; recovered by re-pointing a fresh `tess/m1-w1-test-backfill` branch at the commit hash and pushing that. Both PRs landed clean. **Suggestion for orchestrator:** consider per-agent worktrees being mandatory (not opt-out) for the parallelism profile we're now hitting — the dispatch protocol already mentions this in `GIT_PROTOCOL.md`, but at least one of this run's concurrent agents was on the shared main checkout.
- Deliverables this run (run 005, 2026-05-02 PM): Two test PRs merged + two QA bounce reviews. (a) **PR #29 (`tess/m1-w1-test-backfill`) MERGED** — `tests/test_w1_backfill.gd` (16 backfill tests across Save multi-slot, LootRoller T4/T5/T6 + pool-cap, Grunt telegraph re-entry guard + dead no-op + zero-damage event, Hitbox multi-target + duck-type contract + unknown-team layer-empty, Player i-frame idempotence, LevelAssembler multi-port + mob-id verbatim + zero-spawn). Audit pass per `TESTING_BAR.md` §Priya found ~140 paired tests across w1 features — coverage was already strong, this PR closed residual edge probes only. ClickUp `86c9kxx8h` flipped `to do → in progress → complete`. (b) **PR #31 (`tess/save-migration-fixture`) MERGED** — `tests/test_save_migration.gd` (9 tests) + 3 hand-authored v0 JSON fixtures (`tests/fixtures/save_v0_*.json`) + author guide `team/tess-qa/save-migration-fixtures.md`. Pins the v0→v1 boundary with all 3 ticket-required edge probes (empty inventory, malformed item, double-migration no-op) plus envelope contract (load-only doesn't rewrite v0 on disk) and AC #6 integration (simulated quit-and-relaunch on a v0 save). ClickUp `86c9kxx73` flipped `to do → in progress → complete`. (c) **PR #26 (Drew charger) BOUNCED** — 9 failing tests on CI, severity **blocker**. State machine never enters `STATE_CHARGING`: telegraph end goes straight to `recovering`, charge velocity stays 0, no contact hitbox spawns, knockback isn't skipped during charge. Detailed root-cause hypothesis in PR comment. ClickUp `86c9kxx46` flipped back to `in progress`. (d) **PR #33 (Drew shooter) BOUNCED** — 1 failing test on CI, severity **major**. `test_aiming_interrupts_to_kiting_when_player_closes` — kiting velocity stays 0 (state probably stuck in aiming). 250/251 tests passing including all 3 required edge probes; single bug to swat. ClickUp `86c9kxx3z` flipped back to `in progress`. (e) **PR #30 (Devon CI fix)** — `chore(ci|build)`, Tess sign-off NOT required per protocol; merged by Devon directly. Verified.
- Next: When dispatched again — re-review charger PR #26 and shooter PR #33 once Drew pushes fixes (CI re-runs auto on push). Bug-bash tick before M1 RC. Soak run as soon as Devon's M1 RC build artifact lands. The save-migration test framework + author guide is in place for when Devon bumps the schema to v2; he should author a `save_v1_*.json` fixture alongside that change per the doc.

---

## Open decisions awaiting orchestrator

(none — Uma's two pending cross-role calls resolved by orchestrator on resume 2026-05-02; see `DECISIONS.md` entries on visual-direction lock and M1 death rule.)

## Sponsor sign-off queue

(empty — next entry will be M1 First Playable build.)
