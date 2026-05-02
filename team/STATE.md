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
- Status: idle (chunk done — all 6 week-1 Devon tasks landed)
- Working on: —
- Blocked on: nothing. Sandbox blocks `git push origin main` for this run; commits land locally on `main` and will sync on the next push window. ClickUp MCP dropped mid-run after task 3; tasks 4/5/6 status updates queued at `team/log/clickup-pending.md` (entries 001, 006, 007).
- Deliverables this run: (1) project.godot + folder skeleton + Save autoload stub + GUT install README (commit 0902922 + decisions 492be2e). (2) `.github/workflows/ci.yml` + `tests/test_smoke.gd` canary (commit 20a8688). (3) `.github/workflows/release-itch.yml` + `team/devon-dev/itch-deploy.md` (commit 139a3d2). (4) `scripts/player/Player.gd` + `scenes/player/Player.tscn` + `tests/test_player_move.gd` (commits 2fc7340 + ee1f991, 9 GUT tests). (5) `scripts/combat/Hitbox.gd` + Player attack methods + `tests/test_hitbox.gd` (7) + `tests/test_player_attack.gd` (10) (commit d5852f9). (6) `scripts/save/Save.gd` full impl + `team/devon-dev/save-format.md` + `tests/test_save.gd` (14 GUT tests including v0->v1 migration forward-compat) (commit ddad8af). 4 decisions logged in DECISIONS.md (project layout, physics layers, GDScript style, GUT install policy). Total: 47 paired GUT tests + canary smoke. Followed testing bar: every feature commit pairs tests, all feature tasks flipped to `ready for qa test` for Tess (queued via fallback while MCP is down).
- Next: When dispatched again — depending on Tess's verdicts, address bugs from her sweep of tasks 4-6; otherwise pick up week-2 work (per `team/priya-pl/week-2-backlog.md`): export_presets.cfg authoring (unblocks first real release-itch.yml run), 5 testability hooks tracked in clickup-pending entry 004 (build-SHA in main menu, debug fast-XP toggle, save-path README, stable mob spawn seed, HTML5 console error surfacing), level-up math + damage formula. Open question for orchestrator/Priya: sandbox `git push` block is repo-wide and prevents any agent from syncing — needs explicit policy from Sponsor before any commits leave local main.

## Drew (Game Dev #2)

- Last updated: 2026-05-02
- Status: working
- Working on: Run 002 — week-1 carry-overs from Priya's revised timeline. Implementing in order: (8) Grunt mob archetype + AI state machine, (9) Stratum-1 first room + chunk-based assembly POC, (10) LootRoller + 10-edge-case GUT tests. Schema implementation (`scripts/content/*.gd` + ContentFactory + seed TRES) bundled with task #8 per Priya's run-001 split decision.
- Blocked on: nothing. Devon's scaffold + physics layers + Hitbox + Player landed in run-001. ClickUp MCP disconnected — status updates queued to `team/log/clickup-pending.md`.
- Next: Per-task: feature branch → paired GUT tests in same commit → push → PR → label ready-for-qa → stop. Tess merges after sign-off.

## Tess (Tester)

- Last updated: 2026-05-01
- Status: idle (chunk done — 5 QA spec docs landed)
- Working on: —
- Blocked on: nothing. Role expanded mid-run per `team/TESTING_BAR.md` (Sponsor's "no debugging" directive): Tess is now active hammer + sole `ready for qa test → complete` gate + mandatory ≥3 edge-case probes per feature + scheduled bug bashes + soak sessions per release candidate.
- Deliverables this run: `team/tess-qa/m1-test-plan.md` (35 manual cases across 7 ACs + regression sweep + 8-probe edge-case matrix + Tess-only sign-off flow), `bug-template.md` (severity matched to TESTING_BAR.md), `automated-smoke-plan.md` (30 unit + 10 integration GUT tests inventoried), `test-environments.md` (primary = Chrome/Win11 HTML5 + Firefox + Windows native), `soak-template.md` (30-min soak per release candidate). Devon's scaffold + GUT CI + initial player scene landed during this run → Phase A GUT test code writable next tick.
- Next: Phase A GUT tests (`tu-boot-*`, `tu-autoload-*`, `tu-save-*`, `ti-save-*` — 9 unit + 2 integration). Then Phase B as combat/grunt/loot land in `ready for qa test`. Triage `ready for qa test` queue every tick.

---

## Open decisions awaiting orchestrator

(none — Uma's two pending cross-role calls resolved by orchestrator on resume 2026-05-02; see `DECISIONS.md` entries on visual-direction lock and M1 death rule.)

## Sponsor sign-off queue

(empty — next entry will be M1 First Playable build.)
