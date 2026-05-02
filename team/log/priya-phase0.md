# Priya — Phase 0 completion log

## 2026-05-01

Phase 0 complete. Deliverables:

- `team/priya-pl/game-concept.md` — **Embergrave**, top-down 2D action-RPG dungeon crawler, 8 strata, two-ladder progression (char level 1–30 + gear T1–T6 with rolled affixes), single-player.
- `team/priya-pl/tech-stack.md` — Godot 4.3 / GDScript / JSON saves / TRES content / GitHub Actions CI / itch.io HTML5 + native desktop.
- `team/priya-pl/mvp-scope.md` — M1: stratum 1 playable, 1 mob, weapon+armor slots, save/load, ~80–100 orchestrator ticks, 7 acceptance criteria.
- `team/priya-pl/week-1-backlog.md` — 20 tasks across Devon (6), Drew (4), Uma (5), Tess (2), Priya (3).

ClickUp tasks created (all in list `901523123922`, all tagged `week-1`):

| # | Task ID | Title |
|---|---------|-------|
| 1 | 86c9kwhrx | [Devon] W1 · Scaffold Godot 4.3 project & repo layout |
| 2 | 86c9kwht5 | [Devon] W1 · Set up GitHub Actions CI (headless import + GUT) |
| 3 | 86c9kwhte | chore(build): itch.io butler upload pipeline for HTML5 artifact |
| 4 | 86c9kwhtt | feat(player): 8-direction movement + dodge-roll with i-frames |
| 5 | 86c9kwhu7 | feat(player): light attack + heavy attack hitbox prototype |
| 6 | 86c9kwhuq | feat(save): JSON save/load skeleton (character level, stash) |
| 7 | 86c9kwhvd | [Drew] W1 · Authoring tooling — TRES schema for mob & item resources |
| 8 | 86c9kwhvw | feat(mobs): grunt mob archetype — pathing, melee swing, death |
| 9 | 86c9kwhw7 | feat(level): stratum-1 first room — chunk-based assembly POC |
| 10 | 86c9kwhwn | feat(loot): gear drop on mob death — T1 weapon, T1 armor stub |
| 11 | 86c9kwhxf | [Uma] W1 · Player journey map — title to first kill to first death |
| 12 | 86c9kwhxp | design(ui): inventory & stats panel mockup (M1 surfaces) |
| 13 | 86c9kwhxu | design(ui): HUD mockup — HP, XP bar, level, gold, equipped relic |
| 14 | 86c9kwhy3 | design(art): visual direction one-pager + palette + reference board |
| 15 | 86c9kwhy5 | design(ux): death & restart-run flow — what feels fair |
| 16 | 86c9kwhy9 | [Tess] W1 · M1 acceptance test plan — written cases for all 7 criteria |
| 17 | 86c9kwhye | test(smoke): automated smoke test — game boots, title screen, no errors |
| 18 | 86c9kwhyp | [Priya] W1 · ClickUp board hygiene + week-2 backlog draft |
| 19 | 86c9kwhyv | docs(design): freeze game-concept.md, tech-stack.md, mvp-scope.md as v1 |
| 20 | 86c9kwhyy | [Priya] W1 · Risk register — top 5 risks with mitigation |

ClickUp was responsive — 0 fallback queue entries needed.

STATE.md moved Phase 0 → Phase 1. All four roles have Next-line guidance pointing at specific ClickUp tasks. Critical path: Devon #1 (scaffold) unblocks Devon #4–#6 and Drew #8–#10. Uma and Tess can start immediately in parallel.
