# Git Protocol

Remote: `https://github.com/TSandvaer/RandomGame.git`. Default branch: `main`. **`main` is protected — direct push is blocked by harness policy. Every change lands via PR + `gh pr merge`.**

## Per-task workflow (mandatory for every role)

When you finish a task (or a coherent chunk of work):

1. `git status --short` to confirm what's staged.
2. `git pull --rebase origin main` so you're rebased on the latest before branching.
3. Stage only files relevant to your task (`git add <files>` — not `git add .` or `git add -A`).
4. Commit with a conventional-commit title matching the ClickUp task shape:
   - `feat(scope): ...` for new features
   - `fix(scope): ...` for bug fixes
   - `chore(scope): ...` for tooling, repo housekeeping
   - `design(spec): ...` for design docs landing
   - `docs(scope): ...` for written documentation
   - `test(scope): ...` for tests
   Body of the commit message — one short paragraph describing **why**, not **what**. Reference the ClickUp task ID if applicable (`Closes #86c9...`). Always include this trailer:
   ```
   Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
   ```
5. **Push to a feature branch**, never main: `git push origin HEAD:<role>/<task-scope-kebab>`. Examples:
   - `git push origin HEAD:devon/player-attacks`
   - `git push origin HEAD:drew/grunt-mob`
   - `git push origin HEAD:tess/m1-gut-phase-a`
   - `git push origin HEAD:uma/audio-direction-v1`
   - `git push origin HEAD:priya/week-2-backlog-promote`
   - `git push origin HEAD:orchestrator/<scope>` (orchestrator only)
6. **Open a PR** with `gh pr create --base main --head <branch> --title "<commit title>" --body "<short why + ClickUp link>"`.
7. **Merge via the GitHub API** with `gh pr merge <PR#> --squash --delete-branch --admin`. The `--admin` flag is required because `main` is protected; only the orchestrator-class identity has it. Squash-merge is the default — keeps `main` linear.
8. After merge: `git fetch origin && git reset --hard origin/main` to sync your local main back to the squashed tip.

`git push origin main` is **denied** by the harness — don't try; you'll waste a tool call. Force-pushes (`--force`, `--force-with-lease`) are also denied.

## Tess sign-off via PR

The Tess-only `ready for qa test → complete` gate (per `TESTING_BAR.md`) maps cleanly to PR review:

- Devs open PRs and label them `ready for qa test` (`gh pr edit <PR#> --add-label "ready-for-qa"` if the label exists; otherwise the ClickUp status flip is the signal).
- Devs do **NOT** merge their own feature PRs. They push, open the PR, and stop.
- **Tess** reviews via `gh pr diff <PR#>` plus `gh pr checkout <PR#>` for local exploratory testing, runs the relevant manual cases from `team/tess-qa/m1-test-plan.md`, then either:
  - **Approves and merges**: `gh pr review <PR#> --approve --body "<sign-off note>"` then `gh pr merge <PR#> --squash --delete-branch --admin`. Then flips ClickUp to `complete`.
  - **Bounces**: `gh pr review <PR#> --request-changes --body "<bug list with severity>"`. Files `bug(scope):` ClickUp tasks per `team/tess-qa/bug-template.md` and leaves the PR open until devs push fixes.

Pure docs / `chore(repo|ci|build)` / `design(spec)` PRs — Tess sign-off is **not** required. The orchestrator (or Priya for `chore(triage)` / `docs(team)`) may merge directly.

## Concurrent agents

Multiple agents may be running at once. Before pushing your branch:

1. `git pull --rebase origin main` — pick up any merges that happened during your run.
2. If rebase conflicts in your own area, resolve and continue. If conflicts are in another role's area, abort the rebase, leave a note in `team/log/<your-role>-conflict.md`, and surface via STATE.md "Open decisions awaiting orchestrator" — don't blind-resolve another role's code.
3. Push to your feature branch, then PR, then merge per the workflow above.

## CI

CI runs on every PR (`.github/workflows/ci.yml` triggers on `pull_request` to `main`). PRs that red CI cannot be merged via `gh pr merge --auto` — fix forward in the same branch with another commit, push, CI re-runs.

## What to commit, what not to commit

- **Commit**: code, design docs, test plans, asset source files (Aseprite `.aseprite`, exported `.png` only if the source isn't versioned), Godot scenes/scripts, CI configs.
- **Don't commit**: build outputs (`.godot/`, `export/`, `*.pck`, `*.exe`), AI-generated music WIPs that aren't curated, secrets, large binaries (>10 MB), `.claude/` (already gitignored).

Add to `.gitignore` before staging if in doubt.

## STATE.md and DECISIONS.md edits

These are highly contended. Conventions:

- `STATE.md` — only your own role's section. Use the Edit tool with the section header line as the unique anchor. The orchestrator may edit "Phase" and "Open decisions awaiting orchestrator" sections.
- `DECISIONS.md` — append-only. Priya appends team-level decisions; the orchestrator may append cross-role calls and Sponsor directives.
- Always `git pull --rebase` immediately before editing these files. PR title `chore(state): <role> idle` or `docs(decisions): <topic>`. Merge fast (squash + delete-branch) so contention windows are short.

## Branch naming

`<role>/<task-scope-kebab>` — kebab-case the task scope, prefix with role. Used for branch names AND for your run-log filenames in `team/log/`. Examples:

- `drew/grunt-mob`, `drew/loot-roller`
- `devon/save-load-skeleton`, `devon/export-presets`
- `tess/m1-gut-phase-a`, `tess/qa-bash-w1`
- `uma/audio-direction-v1`, `uma/microcopy-pass`
- `priya/week-2-backlog-promote`, `priya/risk-register`
- `orchestrator/decisions-<topic>`

Keep branches **short-lived** — open, merge, delete in the same agent run. Branches that linger >1 day are stale and must be rebased.
