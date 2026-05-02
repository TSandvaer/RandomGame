# Git Protocol

Remote: `https://github.com/TSandvaer/RandomGame.git`. Default branch: `main`.

## Each role commits and pushes its own work

When you finish a task (or a coherent chunk of work):

1. `git status --short` to confirm what's staged.
2. Stage only files relevant to your task (`git add <files>` — not `git add .` or `git add -A`).
3. Commit with a conventional-commit message matching the ClickUp task title shape:
   - `feat(scope): ...` for new features
   - `fix(scope): ...` for bug fixes
   - `chore(scope): ...` for tooling, repo housekeeping
   - `design(spec): ...` for design docs landing
   - `docs(scope): ...` for written documentation
   - `test(scope): ...` for tests
4. Push to `main`: `git push origin main`. (No PR review process in week 1 — the team is too small. Tess will gate via QA test plan instead.)

Body of the commit message — one short paragraph describing **why**, not **what**. Reference the ClickUp task ID if applicable (e.g. `Closes #86c9...`).

Always include this trailer:

```
Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

## Concurrent agents

Multiple agents may be running at once. Before pushing:

1. `git pull --rebase origin main` to fold in any concurrent work.
2. If rebase produces conflicts in your area, resolve them. If conflicts are in another role's area, abort the rebase, leave a note in `team/log/<your-role>-conflict.md`, and ping the orchestrator via STATE.md "Open decisions" — don't blind-resolve another role's code.
3. Push.

## What to commit, what not to commit

- **Commit**: code, design docs, test plans, asset source files (Aseprite `.aseprite`, but exported `.png` only if the source isn't versioned), Godot scenes/scripts, CI configs.
- **Don't commit**: build outputs (`.godot/`, `export/`, `*.pck`, `*.exe`), AI-generated music WIPs that aren't curated, secrets, large binaries (>10 MB).

Add to `.gitignore` before staging if in doubt.

## STATE.md and DECISIONS.md edits

These are highly contended. When editing:

- `STATE.md` — only your own role's section. Use the Edit tool with the section header line as the unique anchor.
- `DECISIONS.md` — append-only. Only Priya appends decisions; the orchestrator may append cross-role calls.
- Always `git pull --rebase` immediately before editing these files, and commit + push the change in a tight window.

## Branch strategy

Trunk-based on `main` for week 1. If a task is risky enough to need isolation (e.g. major engine refactor), open a short-lived branch named `<role>/<scope>` and fast-forward merge to `main` when done.
