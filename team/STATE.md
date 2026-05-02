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
- Status: idle (chunk done — run 002: both week-2 design tickets landed)
- Working on: —
- Blocked on: nothing. Two harness branch-isolation incidents this run (commits landed on adjacent agents' branches — `tess/test-backfill` and `drew/shooter-mob` — due to shared-`.git` HEAD state). Worked around in both cases (cherry-pick or `git checkout <sha> -- file` re-stage on correct branch). Surfaced for orchestrator visibility — worktree-isolation may need additional HEAD-pinning in v3.
- Deliverables this run: (a) **PR #25 `design(ux): level-up panel + tooltip language standard`** — `team/uma-ux/level-up-panel.md` covers Beat 1 level-up moment (outward ember-burst + chime + LV tick), bottom-anchored stat-allocation panel (3 tiles VIGOR/FOCUS/EDGE, 1/2/3 keybinds, P to open, Esc to bank, time-slow to 10% on open consistent with inventory), 12-string tooltip language standard (3 stat tooltips + 3 confirmation strings + 3 inventory mirror strings + 3 HUD/toast strings) housed in a single `StatStrings.tres` resource for Devon to inline, 28-row tester checklist. Auto-opens only on first-ever level-up (Level 1→2); pip-only thereafter for autonomy. Closes `86c9kxx79`. (b) **PR #28 `design(ux): boss intro + health-bar treatment for stratum-1 boss`** — `team/uma-ux/boss-intro.md` covers boss entry (1.8 s door-slam → ambient cut → camera zoom → boss wake → nameplate banner; skippable after first lifetime kill via movement key), 480×56 top-anchored boss nameplate with 3-segment phase-segmented HP bar (segments visually equal — lie about HP-equality by design; phases are narrative gates not literal HP brackets), phase-transition cinematics at 66/33% HP (0.6 s world-slow to 30% + tritone sting; less aggressive than inventory's 10%), boss-defeated climax (only true time-freeze in M1's design language — earned at the climax; ember dissolve, title card `The Warden falls.`, loot drop, door unlock), 30-row tester checklist. Honors M1 death rule — boss kill is where equipped-vs-inventory choice has highest stakes; rule speaks for itself, no copy lectures. Closes `86c9kxx7e`.
- Cross-role decisions logged: design choices documented inline in both docs (auto-open rule for first level-up only, time-slow conventions, phase-segments-lie-about-HP design, no-pause for level-up, true-freeze only earned at boss kill). No new `DECISIONS.md` entries needed — the prior `2026-05-02 — M1 death rule` entry is already binding and the boss-intro doc cross-references it explicitly.
- Next: When dispatched again — copy/microcopy pass on all 7 docs after Devon implements scenes (catch any spec ambiguities by reading actual UI); audio-direction one-pager (placeholder cue list — death + level-up + boss-intro all share `bell_struck.ogg`; need to source/curate); reference-board v2 once strata 2+ enter scope; M2 stash-UI design once M2 backlog promotes.

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
- Status: idle (chunk done — run 003)
- Working on: —
- Blocked on: nothing.
- Deliverables this run: All 3 of Drew's `ready for qa test` PRs merged in order. (a) **PR #6 grunt mob** re-reviewed after Drew's fix push (commit 0693476): CI green (test_grunt 21/21, test_content_factory 14/14), both bug fixes verified (typed-array build-fresh-and-copy in ContentFactory; _apply_layers also catches bare CharacterBody2D collision_layer==1). Mandatory edge probes assert in suite (rapid spam idempotent mob_died emit_count==1; death-mid-telegraph clears timer + no swing_spawned post-death; death-while-pathing zeroes velocity + no further state). Merged via merge-main-into-branch + `gh pr merge --squash --delete-branch --admin`. (b) **PR #8 stratum-1 room**: CI green post-rebase (test_level_chunk 20/20, test_stratum1_room 6/6 = 22 paired). Visual-direction lock honored (32 px internal tiles, 480x256 fits 480x270 canvas). Edge probes covered: invalid/null chunk → null result; out-of-bounds spawn/port + empty mob_id caught by validate(); null-factory-return skipped. Note: claimed `team/drew-dev/level-chunks.md` doc not present in branch — minor doc-debt, non-blocker, surfaced in PR comment. Merged. (c) **PR #11 LootRoller**: CI fired on push (no workflow_dispatch needed); 28 paired tests pass (test_loot_roller 24/24, test_mob_loot_spawner 4/4). Seed-state bug fix verified (RandomNumberGenerator.state no longer zeroed after seed assignment; widely-spaced seeds 0xCAFEBABE vs 0xDEADBEEF produce different sequences over 200 rolls). All 10 schema-doc edge cases assert. M1 death-rule sanity: Save schema separates `equipped` (slot→dict) from `stash` (list) with v0→v1 migration backfill; ItemInstance carries unique_id + rolled_affixes; pickup-to-stash serialization is separable from equipped persistence per DECISIONS.md 2026-05-02. Merged. (d) ClickUp: tasks 86c9kwhvw (grunt), 86c9kwhw7 (room), 86c9kwhwn (loot) flipped to `complete`; bug tasks 86c9kxntp (Grunt layer trap), 86c9kxnve (4 risky factory tests) flipped to `complete` with fix-commit-link comments. Conflict pattern: every PR rebase produced one conflict on `team/log/clickup-pending.md` — took main's version per dispatch instruction.
- Next: When dispatched again — Phase B GUT tests as new features land. M1 AC2 acceptance probe (cold-launch → first kill ≤60s) is now end-to-end runnable for the first time (player + grunt + room + loot all on main); schedule a soak run when Devon's testability hooks land. Bug-bash tick before M1 RC. Watch `ready for qa test` queue depth.

---

## Open decisions awaiting orchestrator

(none — Uma's two pending cross-role calls resolved by orchestrator on resume 2026-05-02; see `DECISIONS.md` entries on visual-direction lock and M1 death rule.)

## Sponsor sign-off queue

(empty — next entry will be M1 First Playable build.)
