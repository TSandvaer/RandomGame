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
- Status: triage tick complete
- Working on: Mid-week-1 triage done. Threaded the new testing-bar DoD into 10 ClickUp feature tasks (9 dev features + smoke test). Reassessed timeline — 8 features carry to week 2. Drafted week-2 backlog (`team/priya-pl/week-2-backlog.md`) with 20% buffer floor. 4 decisions appended to `DECISIONS.md`. Did not touch other roles' uncommitted in-flight work.
- Blocked on: —
- Next: At end of week 1, freeze game-concept/tech-stack/mvp-scope as v1 (#19), land risk register (#20), promote week-2 backlog to ClickUp (re-tag carry-overs + create new tickets with DoD blocks).
- Note for orchestrator: no current escalations of my own. Watch the `ready for qa test` queue — task #2 (CI) is in there awaiting Tess; if depth grows past 3 between ticks, dispatch Tess per `TESTING_BAR.md` rule. Drew's task #7 ClickUp status is `to do` even though paper doc landed — non-blocking, his next dispatch will resolve. Note Uma flagged two cross-role calls in her section (visual-direction + inventory-on-death) — I'll consume these next dispatch; orchestrator can leave them for me unless urgent.

## Uma (UX Designer)

- Last updated: 2026-05-02
- Status: idle (chunk done — all 5 week-1 design docs landed)
- Working on: —
- Blocked on: nothing. Sandbox blocked `git push origin main` for this run; commits queued locally on `main` (will sync when push permission allows). ClickUp MCP not available this run; status updates queued in `team/log/clickup-pending.md`.
- Deliverables this run: `team/uma-ux/player-journey.md` (12 beats from cold-launch to first death + 32-row tester checklist), `inventory-stats-panel.md` (M1 weapon+armor active; off-hand/trinket/relic stubbed visible-but-disabled; 8x3 grid; tooltip + keymap + 24-row tester checklist), `hud.md` (4-corner layout; exact hex codes per element; 22-row tester checklist), `visual-direction.md` (pixel-art at 96 px/tile, 480x270 internal canvas, integer scaling only, 8-stratum hue progression + 15-row tester checklist), `palette.md` (S1 authoritative palette + S2-S8 indicative + color-blind notes + 12-row tester checklist), `death-restart-flow.md` (death = comma not full stop; ember-gather sequence; run summary leads with KEPT; 25-row tester checklist).
- Cross-role decisions to log in `DECISIONS.md` next dispatch (deferred this run to avoid stomping Priya's pending DECISIONS.md edits): (a) visual-direction call (pixel-art at 96 px/tile, integer scaling only — constrains Drew's mob art and Devon's UI scenes), (b) M1 inventory-on-death rule (Uma proposes all carried items persist on M1 death because stash UI is M2; awaiting Priya sign-off).
- Next: When dispatched again — formally log the two cross-role decisions; do a copy/microcopy pass on all 5 docs after Devon implements scenes (catch any spec ambiguities by reading actual UI); audio-direction one-pager (placeholder cue list informed by `death-restart-flow.md`'s audio map); reference-board v2 once strata 2+ enter scope.

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
