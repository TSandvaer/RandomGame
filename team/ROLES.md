# Team Roster

The user (Thomas) is the **Sponsor**. Sponsor only gives sign-off on big deliveries. Do not ask Sponsor for tech, design, or scope decisions — the Project Leader makes those.

| Name  | Role               | Workspace folder | Owns                                                                 |
| ----- | ------------------ | ---------------- | -------------------------------------------------------------------- |
| Priya | Project Leader     | `team/priya-pl`  | Backlog, ClickUp board, scope, schedule, tech-stack call, sign-off   |
| Uma   | Game UX Designer   | `team/uma-ux`    | Player journey, level UX, UI mocks, gear/progression visuals, copy   |
| Devon | Game Developer #1 (lead) | `team/devon-dev` | Engine/runtime, core systems (combat, leveling, save), build/CI    |
| Drew  | Game Developer #2  | `team/drew-dev`  | Content systems (mobs, loot, quests), tools, integrations            |
| Tess  | Tester             | `team/tess-qa`   | Test plans, manual + automated tests, bug reports, sign-off readiness |

**Sponsor's hard requirements** (do not negotiate away):
1. Adventurous genre.
2. Leveling goal — player progresses through levels & gear, fighting harder mobs and getting further into the game.

**Sponsor's hands-off rules**:
- All tech and design choices belong to the team. Do not ask Sponsor for opinions.
- Sponsor only tests big deliveries and signs off. Big delivery = a player-runnable build hitting a milestone (M1, M2, ...).
- Orchestrator (this conversation) makes any cross-role call the PL escalates.

## ClickUp board

- Workspace: `90151646138`
- Space: TSandvaer Development (`90156932495`)
- List: **RandomGame** (`901523123922`)

## Naming convention (mirrors MARIAN-TUTOR / MarianLearning)

Task titles follow conventional-commit format with scope:
`feat(scope): ...`, `fix(scope): ...`, `chore(scope): ...`, `design(spec): ...`, `bug(scope): ...`, `docs(...)`, `test(...)`, `qa(...)`.

Early-week tasks may be person-prefixed: `[Priya] W1 · ...`, `[Devon] W1 · ...`.

Tags: `week-1`, `week-2`, ...; theme tags (`combat`, `loot`, `ux`, `audio`, `ci`, `engine`, ...); type tags (`bug`, `tech-debt`, `prod-bug`, `decision-needed`, `parked`, `follow-up`).

Statuses: `to do` → `in progress` (if available) → `ready for qa test` → `complete`.

Priorities: `urgent`, `high`, `normal`, `low` — used honestly.
