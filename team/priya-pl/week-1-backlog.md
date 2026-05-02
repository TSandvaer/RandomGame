# Week 1 Backlog — Embergrave

Goal of week 1: Project scaffolded, player can move and hit a dummy mob in stratum 1's first room, save/load works, CI green, design docs ready for week 2.

All tasks tagged `week-1`. Ramp-up tasks use `[Name] W1 · ...` person prefix; feature tasks use conventional-commit form.

| # | Title | Owner | Priority | Tags |
|---|-------|-------|----------|------|
| 1 | `[Devon] W1 · Scaffold Godot 4.3 project & repo layout` | Devon | urgent | week-1, engine, scaffold |
| 2 | `[Devon] W1 · Set up GitHub Actions CI (headless import + GUT)` | Devon | high | week-1, ci, engine |
| 3 | `chore(build): itch.io butler upload pipeline for HTML5 artifact` | Devon | high | week-1, ci, build |
| 4 | `feat(player): 8-direction movement + dodge-roll with i-frames` | Devon | high | week-1, combat, player |
| 5 | `feat(player): light attack + heavy attack hitbox prototype` | Devon | high | week-1, combat, player |
| 6 | `feat(save): JSON save/load skeleton (character level, stash)` | Devon | normal | week-1, save, engine |
| 7 | `[Drew] W1 · Authoring tooling — TRES schema for mob & item resources` | Drew | high | week-1, tools, engine |
| 8 | `feat(mobs): grunt mob archetype — pathing, melee swing, death` | Drew | high | week-1, combat, mobs |
| 9 | `feat(level): stratum-1 first room — chunk-based assembly POC` | Drew | high | week-1, level, content |
| 10 | `feat(loot): gear drop on mob death — T1 weapon, T1 armor stub` | Drew | normal | week-1, loot, content |
| 11 | `[Uma] W1 · Player journey map — title to first kill to first death` | Uma | high | week-1, ux, design |
| 12 | `design(ui): inventory & stats panel mockup (M1 surfaces)` | Uma | high | week-1, ux, ui |
| 13 | `design(ui): HUD mockup — HP, XP bar, level, gold, equipped relic` | Uma | high | week-1, ux, ui |
| 14 | `design(art): visual direction one-pager + palette + reference board` | Uma | normal | week-1, ux, design, art |
| 15 | `design(ux): death & restart-run flow — what feels fair` | Uma | normal | week-1, ux, design |
| 16 | `[Tess] W1 · M1 acceptance test plan — written cases for all 7 criteria` | Tess | high | week-1, qa, test-plan |
| 17 | `test(smoke): automated smoke test — game boots, title screen, no errors` | Tess | normal | week-1, qa, ci |
| 18 | `[Priya] W1 · ClickUp board hygiene + week-2 backlog draft` | Priya | normal | week-1, pm |
| 19 | `docs(design): freeze game-concept.md, tech-stack.md, mvp-scope.md as v1` | Priya | normal | week-1, docs |
| 20 | `[Priya] W1 · Risk register — top 5 risks with mitigation` | Priya | low | week-1, pm, follow-up |

## Critical path for week 1

`#1 (scaffold) → #4 (movement) → #8 (grunt mob) → #9 (first room) → integration check`

Devon must finish #1 within first 4 ticks to unblock everyone. Drew can start #7 (authoring tooling design) in parallel while waiting on scaffold. Uma and Tess are parallel from tick 0 — they don't need a running build to start their week-1 work.

## Week-2 preview (not in ClickUp yet)

Inventory UI implementation, level-up flow, 2 more mob archetypes (shooter, charger), affix system data model, stratum-1 mid-boss, audio placeholder pass, first Sponsor smoke build.
