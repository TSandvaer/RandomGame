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

- Last updated: 2026-05-01
- Status: working
- Working on: (1) Player journey map → (2) Inventory & stats panel → (3) HUD → (4) Visual direction + palette → (5) Death & restart flow.
- Blocked on: —
- Next: Land design docs in order; sync ClickUp on each.

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
- Status: working
- Working on: (1) M1 acceptance test plan → (2) Bug report template → (3) Automated smoke test plan (paper) → (4) Test environment matrix.
- Blocked on: nothing — MVP scope is locked at `team/priya-pl/mvp-scope.md`. GUT scaffold not yet committed (paper deliverables only this run).
- Next: Land 4 QA spec docs this run; write actual GUT smoke tests once Devon's scaffold commit lands.

---

## Open decisions awaiting orchestrator

(none — Priya made all Phase 0 calls and logged them in `DECISIONS.md`.)

## Sponsor sign-off queue

(empty — next entry will be M1 First Playable build.)
