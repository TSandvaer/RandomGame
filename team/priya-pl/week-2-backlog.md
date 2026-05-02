# Week 2 Backlog — Embergrave (Draft)

Owner: Priya. Drafted: 2026-05-02. **Not yet in ClickUp** — week-2 tasks are created at end of week-1, after the actual carry-over set is final.

## Goal of week 2

Close M1's combat-and-loot plumbing (the carry-overs from week 1), then layer on the progression loop (level-up math, XP curve), the boss encounter, and gear depth (affixes). End of week 2: a stratum-1 vertical slice — fight, level, loot, save, fight harder.

## Composition

Per `team/TESTING_BAR.md`, week-2 budget includes **≥20% test/CI/bugbash buffer**. Targets:

- Total tickets: ~25.
- Buffer (test/CI/bugbash): **≥5 tickets** = 20% floor. Listed explicitly under "Buffer" below.

## Carry-over from week 1

Per `team/priya-pl/week-1-revised-timeline.md`. These are existing ClickUp tasks; reset their tag from `week-1` → `week-2` when w1 closes.

| # | Task | Owner | Why slipping |
|---|------|-------|--------------|
| C1 | `chore(build): itch.io butler upload pipeline for HTML5 artifact` (86c9kwhte) | Devon | Depends on stable artifact + green CI; ships once CI #2 signs off |
| C2 | `feat(player): light attack + heavy attack hitbox prototype` (86c9kwhu7) | Devon | Sequential after #4 (movement) |
| C3 | `feat(save): JSON save/load skeleton` (86c9kwhuq) | Devon | Highest-risk; bar requires deepest test pass — extra tick budgeted |
| C4 | `feat(mobs): grunt mob archetype` (86c9kwhvw) | Drew | Depends on TRES schema implementation |
| C5 | `feat(level): stratum-1 first room — chunk-based assembly POC` (86c9kwhw7) | Drew | Depends on grunt |
| C6 | `feat(loot): gear drop on mob death` (86c9kwhwn) | Drew | Depends on grunt + schema impl |
| C7 | `[Drew] Schema implementation — ContentFactory + Resource scripts paired with grunt` | Drew | Splits out of TRES #7 paper task; paired test gate per testing bar |
| C8 (conditional) | `feat(player): 8-direction movement + dodge-roll` (86c9kwhtt) | Devon | Slips only if w1 close finds it not yet Tess-signed |

## New week-2 work

### Combat & progression

| # | Task | Owner | Priority | Tags | Notes |
|---|------|-------|----------|------|-------|
| N1 | `feat(progression): level-up math + XP curve (1→5)` | Devon | high | week-2, progression, combat | XP table, on-level-up flow, paired GUT for curve formula. Touches save schema → coordinate with C3. |
| N2 | `feat(progression): stat-point allocation UI (Vigor/Focus/Edge)` | Devon | high | week-2, progression, ui | Hooked into Uma's level-up screen mockup. |
| N3 | `feat(combat): damage formula pass — base + scaling` | Devon | high | week-2, combat | First real combat math. Paired GUT covers stat-driven damage, crit, armor reduction. |
| N4 | `feat(mobs): shooter mob archetype` | Drew | high | week-2, mobs, combat | Second M1 mob (per mvp-scope §M1). |
| N5 | `feat(mobs): charger mob archetype` | Drew | high | week-2, mobs, combat | Third M1 mob — closes mob roster for M1. |
| N6 | `feat(boss): stratum-1 boss encounter` | Drew | high | week-2, boss, combat | Headline M1 fight. AC #4 (clear in <10min when gear-appropriate) testable here. Paired GUT for boss state machine; manual case in Tess plan. |

### Gear & loot

| # | Task | Owner | Priority | Tags | Notes |
|---|------|-------|----------|------|-------|
| N7 | `feat(gear): affix system (swift, vital, keen) — T1 ranges` | Drew | high | week-2, loot, gear | Lands real affixes on top of C6's flat-stat stub. Paired GUT for AffixDef rolls + tier ranges. AC #7 (two distinct visible affix drops) gated here. |
| N8 | `feat(gear): affix balance pass — T1→T3 value ranges` | Drew | normal | week-2, loot, gear | Spreadsheet → TRES values. Tess validates via stat-driven combat (depends N3). |
| N9 | `feat(ui): inventory & stats panel implementation` | Devon (or Drew) | high | week-2, ui | Implements Uma's mockup from w1 #12. Paired GUT covers equip/unequip → stat update path. |

### Levels & content

| # | Task | Owner | Priority | Tags | Notes |
|---|------|-------|----------|------|-------|
| N10 | `feat(level): rooms 2–8 of stratum 1 from RoomChunk lib` | Drew | high | week-2, level, content | Builds on C5. Targets the full 8-room stratum 1 per mvp-scope. |
| N11 | `feat(level): stratum exit + descend screen` | Drew | normal | week-2, level | AC #6-adjacent — save trigger lives here. |

### Save / migration

| # | Task | Owner | Priority | Tags | Notes |
|---|------|-------|----------|------|-------|
| N12 | `test(save): forward-compat migration test from v0 → v1 fixture` | Tess | high | week-2, qa, save | Per testing bar §save-load — *every* save-shape change needs a forward-compat test. Tess writes this against C3's emerging schema. |

### UX surfaces

| # | Task | Owner | Priority | Tags | Notes |
|---|------|-------|----------|------|-------|
| N13 | `design(ux): level-up panel + tooltip language` | Uma | normal | week-2, ux, design | Spec for N2's UI — what does +1 Vigor *say* on the panel? |
| N14 | `design(ux): boss intro / health-bar treatment` | Uma | normal | week-2, ux, design | Spec for N6. |

## Buffer (≥20% per testing bar)

| # | Task | Owner | Priority | Tags | Notes |
|---|------|-------|----------|------|-------|
| B1 | `qa(bugbash): end-of-week-2 exploratory pass` | Tess | high | week-2, qa, bugbash | One full tick of nothing-but-exploratory testing on the latest build. Files everything found per `team/tess-qa/bug-template.md`. |
| B2 | `qa(soak): 30-min uninterrupted play session — RC1` | Tess | high | week-2, qa, soak | First soak session. Documents in `team/tess-qa/soak-<date>.md` per testing bar. |
| B3 | `chore(ci): hardening — flake quarantine, cache, runtime budget` | Devon | normal | week-2, ci, infra | Reserve a tick for CI maintenance: flake quarantining (per testing bar — no skip-without-followup), cache speedup, keep job under 5min budget. |
| B4 | `qa(tests): backfill GUT coverage for any w1-shipped feature missing tests` | Tess | high | week-2, qa | Catches any feature that snuck through without paired tests; if any are found, Priya files `tech-debt(...)` and reverts per the bar. |
| B5 | `qa(integration): GUT scene tests for M1 ACs #2, #3, #6` | Tess | normal | week-2, qa | First integration-tier tests beyond unit. Targets the speed-to-first-kill, death-keeps-progress, and save-survives ACs. |

**Buffer count: 5 / 25 tickets = 20% floor met.**

## Critical path for week 2

`C3 (save) ⇒ N1 (level-up math) ⇒ N3 (damage formula) ⇒ N7 (affixes) ⇒ N6 (boss) ⇒ B1 (bug bash) ⇒ B2 (soak)`

Save/load is the critical-path anchor because level-up math, gear stats, and affix rolls all need to round-trip through it. Land C3 with deep tests *first*, then layer progression on top.

## Risks for week 2

1. **Carry-over crowds out new work.** If 8 of 20 w1 tasks slip, week-2 effective new-work capacity is ~17 tickets, not 25. Mitigation: prioritise C3 (save), C4 (grunt), C6 (loot pipeline) — those unblock new work. Defer C1 (butler) to back-half of week 2.
2. **Tess becomes the bottleneck.** Sign-off latency compounds. Mitigation: orchestrator polices `ready for qa test` queue depth (testing bar §orchestrator rule); dispatch Tess back-to-back when queue ≥3.
3. **Affix balance is hand-tuning territory.** N8 might want more than 1 tick. Mitigation: ship stub T1 values, balance pass is reversible until M1 sign-off.
4. **Boss state machine is the most complex single piece of week-2 content.** Mitigation: Drew's paired GUT for state transitions (per testing-bar) catches regressions early; Tess's edge-case probes target combat edge cases the state machine surfaces.

## Promotion to ClickUp

End of week 1, Priya:
1. Re-tags carry-overs C1–C8 from `week-1` → `week-2` (existing task IDs preserved).
2. Creates N1–N14 + B1–B5 as new ClickUp tasks with `week-2` tag, descriptions including the **same DoD block** appended this tick to w1 features.
3. Posts week-2 summary into `STATE.md` Priya section.
