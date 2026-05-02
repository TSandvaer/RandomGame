# Orchestrator dispatch template

Standard snippets the orchestrator pastes into every Agent brief. Centralizing them here keeps individual briefs short and uniform, and makes future protocol updates a one-file change instead of N-brief change.

**Reference order:** orchestrator authors a task-specific brief, then appends or inlines the snippets below as needed. Don't quote the whole template — pick the relevant blocks.

---

## Worktree state (mandatory in every dispatch)

```markdown
**Worktree state — IMPORTANT (W3-A7 option A):**
- Operate ONLY in `C:/Trunk/PRIVATE/RandomGame-<your-role>-wt` (your role-persistent worktree). Do NOT touch other agents' worktrees. Do NOT operate in the main checkout `c:\Trunk\PRIVATE\RandomGame` — that's the orchestrator's surveys, contended.
- Run-start invocation:
  ```bash
  cd C:/Trunk/PRIVATE/RandomGame-<your-role>-wt
  git fetch origin
  git checkout -B <your-role>/<task-name> origin/main
  ```
- Push by refspec: `git push origin <your-role>/<task-name>:<your-role>/<task-name>`.
- The `git checkout -B` always force-creates from `origin/main`. Don't try to recover prior in-flight work — every dispatch starts fresh.
- Other agents may be in flight in parallel; their worktrees + file scopes are documented in your task-specific brief above. No file overlap is expected; if you find one, surface it (don't blind-resolve).
```

Replace `<your-role>` with the literal role name (priya / uma / devon / drew / tess) and `<task-name>` with a kebab-case task slug.

## Lesson reminder (mandatory in every dispatch)

```markdown
**Lesson reminder (load-bearing this session):** `agent-verify-evidence.md` — pull actual file contents and CI evidence before refusing or asserting impossibility. The earlier-this-session `Stratum1BossRoom.gd:204` incident — a Drew agent confidently refused to fix a real GDScript parse error citing language-design priors, while CI logs proved the bug was real — is the cautionary tale. **Verify, don't reason from priors.**
```

## Merge identity (mandatory in every dispatch)

```markdown
**Merge identity (per `team/log/process-incidents.md`):**
- `feat(...)`, `fix(...)`, `test(...)` — Tess sign-off REQUIRED. Don't self-merge. Tess will pick up.
- `chore(ci|build|repo)`, `design(spec)`, `docs(team|scope)` — Tess sign-off NOT required, BUT merge identity must be the orchestrator (or Priya for `chore(triage)` / `docs(team)`). Devs do NOT self-merge in any category.
- Open the PR and stop. Orchestrator picks up.
```

## STATE.md update (mandatory in every dispatch that does material work)

```markdown
**STATE.md update:**
- Update ONLY your `## <Role> (<role-title>)` section in `team/STATE.md`. Don't touch other roles' sections.
- Bump your run number to the next integer (read your section to find the current run; increment by 1).
- Include the update in the same PR as your task work — don't open a separate `chore(state)` PR per task. (Idle-tick state PRs are still allowed; this rule is about per-task efficiency.)
```

## Done clause (mandatory in every dispatch)

```markdown
**Done = PR open with: <list of artifacts> + STATE.md <role> section bump + any required ClickUp queue updates (one PR). Brief report (<NNN words): <list of facts to surface>.**

Report back when done.
```

Replace `<list of artifacts>`, `<NNN>`, and `<list of facts>` with task-specific values.

## ClickUp queue (when MCP is down)

```markdown
**ClickUp state:**
- MCP server is intermittent this session. If you can't reach `mcp__clickup__clickup_*` tools, queue your status updates in `team/log/clickup-pending.md` per `team/CLICKUP_FALLBACK.md`.
- Queue ENTRY format: `ENTRY NNN: <ticket_id> -> <new_status> (reason: <one-line>)`.
- Check the file's last entry number and increment.
- Orchestrator replays the queue when MCP reconnects.
```

## Self-merge denials (rare cases)

The harness denies self-merge of one's own PR via `gh pr review --approve` (returns "can not approve your own pull request" — harness identity matches author). Workaround:
- For test PRs Tess approves: deliver approval via `gh pr comment <PR#> --body "LGTM, signing off"` then merge via `gh api PUT repos/.../pulls/<PR#>/merge -f merge_method=squash`. Tess has authority for this on test PRs.
- For other roles: don't try to self-merge. Open the PR and stop.

## Worktree cleanup (orchestrator-side, post-merge)

After a PR merges, the local-branch-delete may fail with `cannot delete branch '<role>/<task>' used by worktree at '<path>'`. This is cosmetic — the GitHub-side state is clean (remote branch deleted via `--delete-branch` admin merge), only the local branch ref lingers. Two options:

- Leave it — next time the agent for that role runs, `git checkout -B <new-task>` overwrites the stale local branch.
- Force-overwrite via `cd <worktree-path> && git fetch origin && git checkout -B <new-branch> origin/main` (the `-B` does both create-or-reset).

Per-task ephemeral worktrees can be removed via `git worktree remove --force <path>` after the PR merges.
