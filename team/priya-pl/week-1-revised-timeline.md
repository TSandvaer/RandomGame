# Week 1 — Revised Timeline (Post Testing-Bar)

Owner: Priya. Tick: 2026-05-02 (mid-week-1 triage).

## Why this exists

Sponsor raised the testing bar (`team/TESTING_BAR.md`): paired tests, green CI, M1-AC integration check, three edge-case probes, and Tess sign-off before any feature task flips to `complete`. Devs cannot self-sign. This adds a Tess gate at the end of every feature, which adds latency.

Original week-1 plan in `week-1-backlog.md` assumed devs could close their own work. With Tess in the loop on every feature, week-1 close on the **6 Devon-features + 4 Drew-features + 2 Tess-tests** path becomes optimistic. A few features will straddle the week-1/week-2 boundary.

This is acceptable — and intentional, per the bar. The cost of one extra tick of QA latency per feature is far smaller than a Sponsor-found bug at sign-off.

## Snapshot (from ClickUp + commit log + role logs)

| # | Task | Owner | Status (ClickUp) | Reality | Verdict |
|---|------|-------|------------------|---------|---------|
| 1 | Scaffold Godot project | Devon | complete | landed pre-bar; `0902922` | **w1 ✓** |
| 2 | GitHub Actions CI | Devon | ready for qa test | awaiting Tess | **w1 ✓** if Tess signs this tick |
| 3 | itch.io butler | Devon | to do | not started | **slip to w2** (depends on stable artifact + green CI #2) |
| 4 | Player movement + dodge | Devon | to do | local WIP exists (Player.tscn + tests/test_player_move.gd in dev's working tree, uncommitted) | **w1 if** dev pushes + Tess signs by w1 close; else slip to w2 |
| 5 | Light/heavy attack | Devon | to do | not started; depends on #4 | **slip to w2** |
| 6 | JSON save/load | Devon | to do | not started; highest-risk system per testing bar | **slip to w2** (deserves the deeper test pass — don't rush) |
| 7 | TRES schema | Drew | to do (note: schema doc landed but Drew didn't flip status before stopping) | doc complete; factories pattern documented; `class ContentFactory` not yet implemented | **w1 ✓** (paper) — flip to `ready for qa test` when Drew lands the actual `.gd` Resource scripts + factories + GUT smoke. **Action item:** Drew's next dispatch must land the implementation, not just the spec. |
| 8 | Grunt mob | Drew | to do | blocked on #7 implementation | **slip to w2** |
| 9 | Stratum-1 first room | Drew | to do | blocked on #8 (needs grunt to spawn) | **slip to w2** |
| 10 | Gear drop / LootRoller | Drew | to do | blocked on #7, #8 | **slip to w2** |
| 11 | Player journey map | Uma | to do (paper) | check if Uma landed | **w1 ✓** (paper docs only; exempt from bar #2/#4/#5) |
| 12 | Inventory & stats panel mockup | Uma | to do | paper | **w1 ✓** |
| 13 | HUD mockup | Uma | to do | paper | **w1 ✓** |
| 14 | Visual direction one-pager | Uma | to do | paper | **w1 ✓** |
| 15 | Death & restart flow | Uma | to do | paper | **w1 ✓** |
| 16 | M1 acceptance test plan | Tess | to do (note: paper doc landed in working tree per tess log, uncommitted) | `team/tess-qa/m1-test-plan.md` exists locally | **w1 ✓** once Tess pushes |
| 17 | Smoke test (GUT) | Tess | to do | paper plan exists; actual `.gd` test blocked on Devon's #1 scaffold (now landed) + GUT plugin install | **w1 ✓** if Tess writes it this tick once GUT plugin is installed in CI by Devon's #2 |
| 18 | ClickUp hygiene + w2 backlog draft | Priya | to do | this tick | **w1 ✓** (in flight — this file + `week-2-backlog.md`) |
| 19 | Freeze v1 design docs | Priya | to do | not started | **w1 ✓** at end of week |
| 20 | Risk register | Priya | to do | not started | **w1 ✓** at end of week (next Priya tick) |

## Verdict

- **Week-1 close on schedule for: 12 of 20 tasks** — all paper deliverables (Uma 5, Tess 1, Priya 3) plus Devon's #1 (done), #2 (in QA queue), and Drew's #7 (paper portion).
- **Slipping to week 2 (carry-over): 8 of 20 tasks** — Devon's #3, #5, #6 + Drew's #8, #9, #10. #4 (Devon movement) is borderline-w1 if his local WIP lands and Tess signs this week; otherwise slip.
- **Critical path** has shifted. Original was `#1 → #4 → #8 → #9`. New critical path is `#1 ✓ → #2 (in QA) → #7-impl → #4-Tess → #6-Tess` because save/load is testing-bar-flagged as deepest coverage and Drew can't land #8 until #7 implementation (not just spec) is on disk.

## What this means for week 2

- Week-2 backlog (`week-2-backlog.md`) **must include the 8 carry-overs** plus new work.
- ≥20% buffer per the bar — explicit slots for bug bash, soak, CI hardening, save migration test.
- Boss + level-up + XP curve are the headline w2 features but not the critical path; the critical path is closing M1's plumbing (combat depth + save robustness) before adding gameplay loops on top.

## Decisions made this tick

Logged in `team/DECISIONS.md`:

1. **Drew's Task #7 split:** the paper doc (schema spec) is week-1 work; the implementation (Resource scripts + ContentFactory + GUT smoke) ships paired with #8 (grunt mob) in week 2. Reasoning: testing bar requires the paired test, and the right place for it is alongside the first consumer of the schema, not in isolation.
2. **Devon's Task #6 (save/load) gets +1 tick of buffer** because the bar explicitly calls it out as highest-risk: forward-compat fixture, kill-during-write probe, and OPFS/localStorage tab-blur probe all need to land. No shortcuts.
3. **No tasks bumped out of M1 entirely.** M1 acceptance criteria (the 7 in `mvp-scope.md`) are unchanged. We're shifting effort, not cutting scope.

## Risk flag for orchestrator

If by end of week 1 the `ready for qa test` queue depth exceeds 4 items, dispatch Tess in back-to-back ticks rather than her normal cadence. Per `TESTING_BAR.md` orchestrator rules.
