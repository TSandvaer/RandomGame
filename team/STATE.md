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

- Last updated: 2026-05-01
- Status: Phase 0 complete
- Working on: Week-1 backlog dispatched. Awaiting first heartbeat to triage progress.
- Blocked on: —
- Next: Mid-week ClickUp triage; draft week-2 backlog; risk register; freeze design docs at end of week 1.

## Uma (UX Designer)

- Last updated: 2026-05-02
- Status: idle (chunk done — all 5 week-1 design docs landed)
- Working on: —
- Blocked on: nothing. Sandbox blocked `git push origin main` for this run; commits queued locally on `main` (will sync when push permission allows). ClickUp MCP not available this run; status updates queued in `team/log/clickup-pending.md`.
- Deliverables this run: `team/uma-ux/player-journey.md` (12 beats from cold-launch to first death + 32-row tester checklist), `inventory-stats-panel.md` (M1 weapon+armor active; off-hand/trinket/relic stubbed visible-but-disabled; 8x3 grid; tooltip + keymap + 24-row tester checklist), `hud.md` (4-corner layout; exact hex codes per element; 22-row tester checklist), `visual-direction.md` (pixel-art at 96 px/tile, 480x270 internal canvas, integer scaling only, 8-stratum hue progression + 15-row tester checklist), `palette.md` (S1 authoritative palette + S2-S8 indicative + color-blind notes + 12-row tester checklist), `death-restart-flow.md` (death = comma not full stop; ember-gather sequence; run summary leads with KEPT; 25-row tester checklist).
- Cross-role decisions to log in `DECISIONS.md` next dispatch (deferred this run to avoid stomping Priya's pending DECISIONS.md edits): (a) visual-direction call (pixel-art at 96 px/tile, integer scaling only — constrains Drew's mob art and Devon's UI scenes), (b) M1 inventory-on-death rule (Uma proposes all carried items persist on M1 death because stash UI is M2; awaiting Priya sign-off).
- Next: When dispatched again — formally log the two cross-role decisions; do a copy/microcopy pass on all 5 docs after Devon implements scenes (catch any spec ambiguities by reading actual UI); audio-direction one-pager (placeholder cue list informed by `death-restart-flow.md`'s audio map); reference-board v2 once strata 2+ enter scope.

## Devon (Game Dev #1, lead)

- Last updated: 2026-05-01
- Status: working
- Working on: Task 1 — Scaffold Godot 4.3 project & repo layout
- Blocked on: nothing — top of critical path. Stack is **Godot 4.3 + GDScript + JSON saves + GitHub Actions CI + itch.io HTML5 distribution**.
- Next: (2) GitHub Actions CI (headless import + GUT), (3) itch.io butler upload pipeline, (4) Player movement + dodge-roll, (5) Light/heavy attack hitboxes, (6) JSON save/load skeleton.

## Drew (Game Dev #2)

- Last updated: 2026-05-01
- Status: working
- Working on: Task 1 — TRES schema for MobDef + ItemDef + AffixDef + LootTableDef (`team/drew-dev/tres-schemas.md`).
- Blocked on: Devon's scaffold (#1) for tasks 2–4 (Grunt mob, level POC, loot drop) — those touch the Godot project tree.
- Next: After scaffold lands: (2) Grunt mob archetype, (3) Stratum-1 first room chunk-based assembly POC, (4) Gear drop on mob death (T1 weapon + T1 armor stub).

## Tess (Tester)

- Last updated: 2026-05-01
- Status: idle (chunk done — 5 QA spec docs landed)
- Working on: —
- Blocked on: nothing. Role expanded mid-run per `team/TESTING_BAR.md` (Sponsor's "no debugging" directive): Tess is now active hammer + sole `ready for qa test → complete` gate + mandatory ≥3 edge-case probes per feature + scheduled bug bashes + soak sessions per release candidate.
- Deliverables this run: `team/tess-qa/m1-test-plan.md` (35 manual cases across 7 ACs + regression sweep + 8-probe edge-case matrix + Tess-only sign-off flow), `bug-template.md` (severity matched to TESTING_BAR.md), `automated-smoke-plan.md` (30 unit + 10 integration GUT tests inventoried), `test-environments.md` (primary = Chrome/Win11 HTML5 + Firefox + Windows native), `soak-template.md` (30-min soak per release candidate). Devon's scaffold + GUT CI + initial player scene landed during this run → Phase A GUT test code writable next tick.
- Next: Phase A GUT tests (`tu-boot-*`, `tu-autoload-*`, `tu-save-*`, `ti-save-*` — 9 unit + 2 integration). Then Phase B as combat/grunt/loot land in `ready for qa test`. Triage `ready for qa test` queue every tick.

---

## Open decisions awaiting orchestrator

(none — Priya made all Phase 0 calls and logged them in `DECISIONS.md`.)

## Sponsor sign-off queue

(empty — next entry will be M1 First Playable build.)
