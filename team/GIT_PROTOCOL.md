# Git Protocol

Remote: `https://github.com/TSandvaer/RandomGame.git`. Default branch: `main`. **`main` is protected — direct push is blocked by harness policy. Every change lands via PR + `gh pr merge`.**

## Per-task workflow (mandatory for every role)

**On task start — mandatory ClickUp visibility flip:**

Before doing any work on a task, flip its ClickUp status from `to do` to **`in progress`** with `mcp__clickup__clickup_update_task`. This gives the Sponsor live visibility into what's currently in flight. If MCP is disconnected, queue the flip in `team/log/clickup-pending.md` per `team/CLICKUP_FALLBACK.md` and proceed; orchestrator flushes on next reconnect. Skip this for trivial run-state PRs (e.g. your own `chore(state): <role> idle` PR — that's not a backlog task).

If you finish the task in the same run (typical for design docs, doc tasks, small fixes), the status will progress through `in progress → ready for qa test` (feature) or `in progress → complete` (docs/chore exempt) by the end of your run. The `in progress` window is meaningful for the Sponsor even if it's brief — it's the live signal of "what's being worked on right now."

**On task completion (push + PR + merge):**

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

Pure docs / `chore(repo|ci|build)` / `design(spec)` PRs — Tess sign-off is **not** required, **but the merging identity must still be the orchestrator (or Priya for `chore(triage)` / `docs(team)`). Devs do NOT self-merge their own PRs in any category.** The exemption is from Tess sign-off, not a self-merge license. (See `team/log/process-incidents.md` 2026-05-02 entry for the precipitating incident.)

## ClickUp lifecycle as hard gate

Every ticket lifecycle event has a paired ClickUp status move that fires in the **same tool round** as the action — not "remember to do later." This is a hard gate, not advisory bookkeeping. The Sponsor relies on the ClickUp board as live ground truth; a lying board destroys that trust.

| Event | ClickUp move | Who fires it |
|---|---|---|
| Orchestrator dispatches an agent on a ticket | `to do` → `in progress` | Orchestrator (or agent at run-start) |
| Agent opens PR (feat/fix) | `in progress` → `ready for qa test` | Agent in PR-open flow |
| Agent opens PR (chore/docs/design exempt) | `in progress` → `ready for qa test` (for orchestrator visibility) | Agent in PR-open flow |
| Tess merges (feat/fix) | `ready for qa test` → `complete` | Tess in merge step |
| Orchestrator merges (chore/docs/design) | `ready for qa test` → `complete` | Orchestrator in merge step |
| Tess bounces | `ready for qa test` → `in progress` | Tess in bounce comment |

**Rules:**

1. **Same tool round.** The ClickUp `update_task` call goes in the same response as the dispatch / `gh pr create` / `gh pr merge` — not a follow-up. "Queue and forget" is the failure mode.
2. **MCP down → fallback queue.** If `mcp__clickup__clickup_*` is unreachable, queue the flip in `team/log/clickup-pending.md` per `team/CLICKUP_FALLBACK.md`, and the orchestrator flushes on reconnect.
3. **Heartbeat audit sweep.** Every heartbeat tick the orchestrator runs `mcp__clickup__clickup_filter_tasks list_ids=["901523123922"] statuses=["in progress","ready for qa test"]` and reconciles each ticket against reality (agent running? PR open? merged?). Discrepancies are fixed in the same tick.
4. **Tickets created mid-flight.** If Tess (or any role) discovers a bug and files a `bug(...)` ticket, set the initial status correctly: `complete` if the fix already shipped, default if the work is upcoming.

**Mantra:** the ClickUp board is the truth. Don't lie to it.

## Self-Test Report (UX-visible PRs)

Any PR that touches a **player-visible surface** (scene tree, UI, visual feedback, audio cue, input affordance, save format, level content) MUST include a **Self-Test Report comment from the author** before Tess reviews. Tess's review starts from the report, not from a cold-read of the diff.

**Categories that REQUIRE a Self-Test Report:**

- `feat(integration)`, `feat(ui)`, `feat(combat)`, `feat(level)`, `feat(audio)`, `feat(progression)`, `feat(gear)`
- `fix(ui)`, `fix(combat)`, `fix(level)`, `fix(audio)`, `fix(integration)`
- `design(spec)` only when the spec is consumed by an in-flight `feat` PR (otherwise design is paper-only)

**Categories that do NOT require it (CI green is sufficient):**

- `chore(ci|repo|build)`
- `docs(team|scope)`
- `chore(state|orchestrator|planning)`
- `test(...)` (test-only PRs)
- `.tres`-only data refactors

**Report format (paste as a PR comment after `gh pr create`):**

```markdown
## Self-Test Report

**Build artifact:** <run ID + zip name + sha>
**Scene path:** <e.g. res://scenes/Main.tscn or test scene used for verification>
**Verification method:** <browser+local server / godot --headless / GUT integration test waypoint>

### AC walkthrough
- [x] AC1: <description> — observed: <what you saw/heard>
- [x] AC2: ...
- [ ] AC3: <if not personally verified — explain why and what's covered by automated tests>

### Side-effect inventory
- <other surface that might be affected>: <expected vs. observed>

### Cross-lane integration check
List every other role's feature that shares state with this PR (e.g. Inventory + Pickup + Room gate + Loot for any combat PR). Describe what you probed and what you observed. If you cannot probe cross-lane state (no browser, headless only), name it explicitly as a Sponsor-soak probe target so the orchestrator can route it to Tess's journey-probe (see `team/TESTING_BAR.md` § "Milestone-gate journey probe").

### Open concerns / known gaps
<anything you noticed but is out of this PR's scope>
```

**Headless-environment fallback:** if the agent has no browser binary (GUT-only environment), the Self-Test Report uses `godot --headless` to load the actual entry scene + drive the play loop programmatically (Devon PR #107 pattern). The verification section notes "verified via headless integration test, no browser repro available — Sponsor's interactive soak is the final gate."

**Cross-lane discipline.** The Cross-lane integration check subsection is non-negotiable for every UX-visible PR. Author-side verification accurately describes what THAT PR's author probed — but the M2 RC Sponsor-soak findings (2026-05-15) showed that cross-PR / cross-lane failures slip through when no report cross-checks adjacent-lane state. A combat PR that doesn't touch Inventory code can still break loot pickup if the boss-room exit gate races a loot-drop callback. The check is "what adjacent surface shares state with this PR's mutation, and what did you observe when you exercised it?" Honest "I couldn't probe — please route to Tess's journey-probe" is acceptable and expected for headless authors; silent omission is not.

**Tess's review path:** read the Self-Test Report first; spot-check ≥1 AC + ≥1 side-effect against the report; then sign off or bounce. **If the report is missing on a UX-visible PR, bounce it back immediately with "Self-Test Report missing" — don't burn review budget cold-reading the diff.**

**Why:** the M1 Main.tscn-stub miss (~30 PRs of "feature-complete" claims while the runnable build was a week-1 boot stub) would have been caught on the first PR if every author had to point at the actual playable surface. See `team/log/process-incidents.md` and orchestrator memory `self-test-report-gate.md` + `product-vs-component-completeness.md`.

## Concurrent agents — role-persistent worktrees (W3-A7 option A)

The harness `isolation: "worktree"` Agent flag is **inactive in our setup** — it requires `WorktreeCreate` hooks the harness doesn't have. Without it, agents share the main checkout's `.git/HEAD`, which has produced four shared-HEAD-stomp incidents (Uma run-002 and run-003, Priya run-004, Tess run-018). See `team/log/w3-a7-worktree-isolation-proposal.md` for the full evidence and the option-A decision.

**Operative pattern: each role owns a persistent worktree.** Agents work in their role's sticky worktree; the orchestrator-class checkout `c:\Trunk\PRIVATE\RandomGame` is reserved for orchestrator surveys.

| Role | Worktree path |
|------|---------------|
| Priya | `C:/Trunk/PRIVATE/RandomGame-priya-wt` |
| Uma | `C:/Trunk/PRIVATE/RandomGame-uma-wt` |
| Devon | `C:/Trunk/PRIVATE/RandomGame-devon-wt` |
| Drew | `C:/Trunk/PRIVATE/RandomGame-drew-wt` |
| Tess | `C:/Trunk/PRIVATE/RandomGame-tess-wt` |
| Orchestrator (own commits) | `C:/Trunk/PRIVATE/RandomGame-orch-wt` |
| Orchestrator (surveys) | `c:\Trunk\PRIVATE\RandomGame` |

**Standard run-start invocation** in every dispatch (orchestrator pastes this into briefs from `team/orchestrator/dispatch-template.md`):

```bash
cd C:/Trunk/PRIVATE/RandomGame-<your-role>-wt
git fetch origin
git checkout -B <your-role>/<task-name> origin/main
# ... do work ...
git push origin <your-role>/<task-name>:<your-role>/<task-name>
```

**Rules:**

1. **Operate ONLY in your role's worktree.** Don't `cd` into another agent's worktree. Don't operate in the main checkout `c:\Trunk\PRIVATE\RandomGame` — that's the orchestrator's surveys and is contended.
2. **Reset cleanly at run start.** `git checkout -B` always force-creates the new branch from `origin/main`. Don't try to recover prior in-flight work — every dispatch starts fresh.
3. **Push by refspec.** `git push origin <branch>:<branch>` is robust against the worktree's local-tracking state.
4. **Don't try to delete your sticky worktree on cleanup.** It's role-persistent; the orchestrator manages worktree lifecycle.
5. **One agent per worktree at a time.** If the orchestrator needs to dispatch two agents from the same role concurrently (rare), the orchestrator creates an ephemeral second worktree and includes its path in the second brief.

What you can rely on:

- Your `git checkout`, `git commit`, branch state, and untracked files are isolated.
- `git fetch origin` always works — `origin` is shared.
- Pushes, PRs, and merges work normally.

Conflict resolution on rebase is unchanged:

1. If rebase conflicts in your own area, resolve and continue.
2. If conflicts are in another role's area, abort the rebase, leave a note in `team/log/<your-role>-conflict.md`, and surface via STATE.md "Open decisions awaiting orchestrator" — don't blind-resolve another role's code.

> Per-task ephemeral worktrees (`RandomGame-<role>-<task-slug>`) are also valid for one-off long-form work and may be created at the orchestrator's discretion. They are removed post-merge. The sticky-per-role pattern is the default.

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
