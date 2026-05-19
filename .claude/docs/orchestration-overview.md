# Orchestration Overview

What this doc covers: how Claude Code sessions on Embergrave / RandomGame are structured — the orchestrator-team-Sponsor topology, the named-agent roster, worktree layout, dispatch conventions, ClickUp/PR/CI gates, cron rules, and the conventions that govern when and how the orchestrator dispatches versus codes itself.

## Topology

```
              Sponsor (Thomas)
                  │
                  ▼
            Orchestrator  ◄── single fan-out / fan-in point
            ┌──┬──┬──┬──┬──┐
            ▼  ▼  ▼  ▼  ▼
          Priya Uma Devon Drew Tess
                          ↕
                       (peer review)
```

- **Sponsor talks to the orchestrator only.** The orchestrator routes work to the named-role agents.
- **Sponsor delegates all team decisions** — only signs off big deliveries (M1 RC, etc.). Orchestrator makes recommended calls; Sponsor redirects when they disagree. See memory: `sponsor-decision-delegation.md`.
- **The orchestrator never codes** — does not read source, grep, trace bugs, or edit code. Dispatches agents from symptoms instead. See memory: `orchestrator-never-codes.md`.
- **Always parallel dispatch** — every tick has 3-5 agents in flight; tickets aren't progress, dispatches are. See memory: `always-parallel-dispatch.md`.

## Named-agent roster

Five roles handle the build. Each has a worktree at the same level as the project root:

| Role | Lane | Worktree |
|---|---|---|
| **Priya** | PM / coordination / docs | `C:/Trunk/PRIVATE/RandomGame-priya-wt` |
| **Uma** | UX / design specs | `C:/Trunk/PRIVATE/RandomGame-uma-wt` |
| **Devon** | Combat / integration / build | `C:/Trunk/PRIVATE/RandomGame-devon-wt` |
| **Drew** | Levels / mobs / AI / balance | `C:/Trunk/PRIVATE/RandomGame-drew-wt` |
| **Tess** | QA / testing / reviews | `C:/Trunk/PRIVATE/RandomGame-tess-wt` |

The orchestrator itself uses two locations:
- **Surveys (read-only):** `c:\Trunk\PRIVATE\RandomGame` (the project root)
- **Commits:** `C:/Trunk/PRIVATE/RandomGame-orch-wt`

Per-role worktrees are **single-tenant** — never spawn two agents for the same role concurrently on the same worktree (their writes interleave and stomp each other; see memory: `multi-dispatch-worktree-conflict.md`).

## Dispatch conventions

A dispatch brief should include:

1. **Worktree setup**: explicit `git checkout -B <agent-branch> origin/main` in the role's worktree
2. **Goal / scope** — what to build, what's in/out of scope
3. **Constraints** — paired tests, CI gates, HTML5 verification gate, Self-Test Report requirement
4. **ClickUp ticket ID** if one exists; instructions to flip status as they progress
5. **Report format** — structured final report (PR #, files touched, tests added, ticket moves, artifact links)
6. **Read `.claude/docs/` at start** — sub-agents do not inherit the SessionStart auto-load (see "Sub-agent doc-reading" below)

## Hard gates

Several gates are non-negotiable per memory rules:

- **Testing bar** (memory `testing-bar.md`): paired tests + green CI + edge probes + Tess sign-off mandatory before "complete". Sponsor will not debug; the QA loop must be tight.
- **HTML5 visual-verification gate** (memory `html5-visual-verification-gate.md`): Tween / modulate / Polygon2D / CPUParticles2D / Area2D-state PRs need explicit HTML5 verification before merge. Headless tests insufficient. See `.claude/docs/html5-export.md`.
- **Self-Test Report gate** (memory `self-test-report-gate.md`): UX-visible PRs (feat/fix on ui/combat/integration/level/audio) require an author-posted Self-Test Report comment before Tess will review.
- **ClickUp status as hard gate** (memory `clickup-status-as-hard-gate.md`): every dispatch / PR-open / merge pairs with a ClickUp status move in the same tool round. Heartbeat tick audits the board against reality.
- **Product vs component completeness** (memory `product-vs-component-completeness.md`): "tests pass" ≠ "product ships"; verify integration surface (Main.tscn) at every "feature-complete" claim, not just CI green.
- **Agent-verify-evidence** (memory `agent-verify-evidence.md`): agents must check CI logs / file contents before refusing or asserting impossibility — recovery from the Stratum1BossRoom incident.
- **Playwright browser-E2E harness** (`tests/playwright/`, design at `team/tess-qa/playwright-harness-design.md`, landed PR #154): the canonical browser-driven AC verification gate. Complement to GUT — covers what headless engine tests miss (HTML5 renderer behavior, real input events, service-worker cache, canvas-to-DOM coordination). CI auto-runs against every release-build via `.github/workflows/playwright-e2e.yml`. **Sponsor-soak is no longer the only AC gate** — Sponsor's role shifted to subjective feel-check after the harness reports green. As of M2 W1 the suite covers AC1–AC4 + equip-flow + negative-assertion sweep; AC4 final flip tracked by `86c9qckrd`.
- **Roster-swap audit gate** (`team/tess-qa/playwright-harness-design.md` § "Roster-swap regression discipline"): any PR that mutates a `resources/level_chunks/*.tres` file's `mob_spawns` (count, type, or position) MUST run the full Playwright harness against the new artifact AND audit every spec whose trace assertions match on the affected mob class. PR #169's silent breakage of 6 specs is the cautionary tale — the harness went red-on-main for ~24h before being noticed. Self-Test Report must include the all-specs harness run output.
- **Playwright artifact SHA-pin contract** (`.github/workflows/playwright-e2e.yml`, W3-T11 ticket `86c9ue1xu`): manual `gh workflow run playwright-e2e.yml` invocations MUST pass either `-f artifact_run_id=<id>` (exact run) or `-f artifact_sha=<sha>` (matches a release-github.yml run by head_sha). Passing neither is a HARD FAIL — the legacy "latest successful release on main" silent-fallback bit Tess's W2 soak by pulling the W2 RC artifact for a PR-branch Playwright run. The resolve step verifies the downloaded artifact's name contains the resolved SHA before Playwright runs. `workflow_run` chain trigger (post-release-build on main) is unchanged — uses the upstream run's `id` + `head_sha` automatically.

## Git workflow

`main` is **protected**. Standard PR-flow with admin merge:

```
git checkout -B <agent-branch> origin/main
# ... edits + commits ...
git push -u origin <agent-branch>
gh pr create --title "..." --body "..."
# CI runs, Tess reviews, then orchestrator:
gh pr merge <num> --admin --squash --delete-branch
```

### Worktree cleanup before `gh pr merge --delete-branch`

`gh pr merge <N> --admin --squash --delete-branch` does **three** things:

1. Merges the PR on origin (the actual squash-merge).
2. Deletes the remote branch (`origin/<agent-branch>`).
3. Deletes the **local** branch in the cwd's repo.

Step 3 fails when an agent worktree still has `<agent-branch>` checked out (Git refuses
to delete a branch that's checked out anywhere in the repo). Steps 1 and 2 succeed —
the PR is merged and origin is clean — but **`gh` exits non-zero on the step-3 failure**,
which can short-circuit downstream tool-round steps. The most common casualty is the
ClickUp status flip that's supposed to pair with the merge (memory
`clickup-flip-paired-with-merge`): the merge happens, the ClickUp flip is skipped, and
the ticket rots in "ready for qa test" until someone notices.

**Recovery** (after a non-zero exit):

```bash
# Detach the worktree that's holding the branch:
git -C <agent-worktree-path> switch --detach HEAD

# Retry the merge — origin is already merged, so this just completes the cleanup:
gh pr merge <N> --admin --squash --delete-branch
# Expected output: "Pull request was already merged" — confirms step 1 already succeeded.

# Then run the paired ClickUp flip that was short-circuited.
```

Note: `git checkout main` in the agent worktree is **not** a valid workaround —
`main` is held by the orchestrator's own worktree and can only be checked out in one
worktree at a time.

**Prevention — agent self-detach before final report:** Agents whose work has been
merged (or is about to be) should `git -C <their-worktree> switch --detach HEAD`
before submitting their final report. This frees the branch for the orchestrator's
merge tool-round to complete cleanly without the recovery dance. Dispatch briefs that
end with "and merge" should include this step explicitly.

Validated 2026-05-18 (PR #276 Stoker merge) — supersedes the older "harmless;
auto-rotates on next dispatch" framing, which undersold the ClickUp-flip short-circuit
risk.

### Multi-line PR bodies / comments — always use `--body-file`, never heredoc or `--body "..."`

When opening a PR or posting a multi-line PR comment via `gh`, **always pass the body via `--body-file <path>`**, never inline via heredoc or `--body "..."`. Markdown special characters (`#`, backticks, `<`, `>`, `*`, `_`, `$`, `!`) collide with shell quoting (both bash and PowerShell), producing escape errors, partial bodies, or — in the worst case — silent stalls that the stream watchdog kills after 600 s.

**Correct (always-safe):**

```bash
# Write the body to a file first (or commit it under team/<role>-dev/):
gh pr create --title "feat(...)..." --body-file team/devon-dev/pr-body.md
gh pr comment <N> --body-file team/devon-dev/self-test.md
```

**Wrong (will stall on non-trivial markdown):**

```bash
# Heredoc — backtick + $ + < > all interact badly with shell parsing:
gh pr create --title "..." --body "$(cat <<'EOF'
## Summary
- did `the thing`
- fixed <bug>
EOF
)"

# Same problem with --body "..." inline:
gh pr create --title "..." --body "## Summary
- did the thing"
```

**Why:** validated 2026-05-18 — Devon's first M3W-7 dispatch literally stalled mid-heredoc trying to embed a multi-line markdown PR body. The 600 s stream watchdog killed the agent before it could recover. The recovery dispatch using `--body-file` worked first try. The same trap applies to `gh pr comment`, `gh issue create`, `gh issue comment`, and any other `gh` command that takes `--body`.

**Dispatch-brief discipline:** when authoring a dispatch brief that ends with "open a PR" or "post a Self-Test Report", include the `--body-file <path>` form in the example, not heredoc. Sub-agents copy the example shape — wrong examples burn agent cycles.

For ClickUp updates and PR transitions, the standard cadence pairs each step with a ticket status move (see `clickup-status-as-hard-gate` memory).

## Cron / heartbeat

- Cron is used during long-running waves (multi-agent fan-out + parallel work) to drive dispatch + status audits.
- **Don't run cron during Sponsor wait** (memory `cron-noise-during-sponsor-wait.md`): when waiting on Sponsor's interactive soak / retest, lower cron cadence or kill it. Don't run no-op heartbeats for hours.
- **Drain mode on session-end** (memory `drain-mode-on-session-end.md`): when Sponsor says "save session" / "drain", stop new dispatches, let in-flight finish, merge closure PRs, kill the cron.

### Auto-status toggle (on / away / off)

The `auto-status` skill drives a session-scoped orchestrator-check loop with three modes:

- **on** — 5-minute read-only status pulse (board audit, CI check, surface blockers).
- **away** — ~15-minute active orchestration tick; dispatches work, merges ready PRs, advances tickets. Never makes Sponsor-sign-off calls autonomously.
- **off** — stops the loop.

**Durability:** when the loop is running, its state is written to `.claude/auto-status.state`. The SessionStart hook (matcher: `startup|resume|clear` — explicitly excludes `compact`) reads that file and re-arms the loop automatically in the new session. Do not re-arm by hand — if auto-status is already running at session start, the hook did it.

**Scope limits:** the loop is session-scoped and machine-local; laptop sleep freezes it. Full operational detail in auto-memory `auto-status-reporting.md`.

## Diagnostic build pattern

When validation needs a tedious-to-trigger gameplay scenario, ship a temporary `diag/<short-purpose>` branch (e.g. `diag/2-swing-kill` lowering Grunt HP to 2). See memory `diagnostic-build-pattern.md`. Never merge to main; trigger release-build directly on the diag branch; cherry-pick onto fix branches when integrated verification is needed; delete from origin once the fix lands.

## Sponsor-soak link convention

When asking Sponsor to download an artifact for soak, **include the direct artifact download URL**, not just the GitHub Actions run page:

```
https://github.com/<owner>/<repo>/actions/runs/<run_id>/artifacts/<artifact_id>
```

Get the artifact ID via `gh api repos/.../actions/runs/<id>/artifacts`. See memory `sponsor-soak-artifact-links.md`.

## Sub-agent doc-reading

**If you are a sub-agent spawned via the Agent tool, you do NOT inherit the SessionStart auto-load.** Before starting any work, Read every `.claude/docs/*.md` file (in parallel). These are the canonical project-context briefs the main session sees automatically; without them you are working blind on combat architecture, HTML5 export quirks, and orchestration conventions. Sub-agents should also include a "Non-obvious findings" section in their final report so the main session can route insights into the docs via the maintain-docs Stop hook.

## Cross-references

- Team-process docs (collaboration / process / role briefs): `team/` — TESTING_BAR.md, GIT_PROTOCOL.md, ROLES.md, RESUME.md, STATE.md, DECISIONS.md, plus per-role subdirs (`team/devon-dev/`, `team/uma-ux/`, etc.)
- Architecture / system reference for Claude context: `.claude/docs/` (this folder)
- Auto-memory (orchestrator durable preferences across sessions): `~/.claude/projects/c--Trunk-PRIVATE-RandomGame/memory/` (outside the repo; user's local Claude Code state)
