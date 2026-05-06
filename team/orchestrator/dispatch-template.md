# Orchestrator dispatch template

Standard snippets the orchestrator pastes into every Agent brief. Centralizing them here keeps individual briefs short and uniform, and makes future protocol updates a one-file change instead of N-brief change.

**Reference order:** orchestrator authors a task-specific brief, then appends or inlines the snippets below as needed. Don't quote the whole template — pick the relevant blocks.

---

## Scoped contract (mandatory in every dispatch)

Pin the agent's allowed file scope + role boundary so they don't blind-resolve into another agent's lane on conflict. Block goes near the top of the brief, after the task-specific summary and before the worktree state.

```markdown
**Scoped contract:**
- **Owned files / directories (you may edit):** <list — e.g. `team/uma-ux/<your-doc>.md`, `scripts/player/Player.gd`, `tests/test_player_*.gd`>.
- **Read-only references (read but do NOT edit):** <list — e.g. `scripts/combat/Hitbox.gd`, `team/uma-ux/combat-visual-feedback.md`>.
- **Out of scope (do NOT touch — surface a flag instead):** other roles' design docs, other agents' in-flight branches, `team/STATE.md` sections that aren't your role's.
- **Conflict rule:** if your work would require touching a file outside this scope, STOP and surface a one-line note in your run-log + `team/STATE.md` "Open decisions awaiting orchestrator." Don't blind-resolve into another role's area.
```

Replace placeholders with the task-specific scope. Skip the block only for trivial idle-tick state PRs.

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

## Visual-primitive test bar (paste when dispatch touches tweens / modulate / color-anim / particles)

Per `team/TESTING_BAR.md` § "Visual primitives — observable delta required" (added post-PR-#115/#122 white-on-white incident).

```markdown
**Visual-primitive test bar (load-bearing for tween / modulate / color-anim / particle PRs):**
- Tier 1 (mandatory): paired test asserts `target ≠ rest` for any tweened visual property. `assert_ne(target_color, rest_color)`. White-on-white tweens are the cautionary tale — `tween.is_valid() == true` is necessary but **insufficient**.
- Tier 2 (mandatory for cascading modulate on parented nodes): paired test asserts the modulate is applied to the **visible-draw node** (Sprite2D / ColorRect / Polygon2D), not to a parent CharacterBody2D / Node2D whose child has its own non-white modulate. Modulate cascades multiplicatively; flashing the parent body is a no-op for any child whose own modulate is non-white.
- Tier 3 (aspirational): framebuffer pixel-delta sample at the affected region. Deferred until a `--rendering-driver opengl3` headed CI lane lands; today, Tier 1 + Tier 2 are the binding floor.
- HTML5 verification: tween / modulate / Polygon2D / CPUParticles2D PRs are subject to the HTML5 visual-verification gate per `html5-visual-verification-gate.md`. Headless GUT green is not enough; the Self-Test Report must capture an HTML5 export soak before Tess approves.
- Reference: `team/log/2026-05-html5-visual-feedback-no-op-postmortem.md` for the cautionary tale (PR #115 + #122 shipped tween-based feedback that asserted "tween fires" without asserting "visual changes"; bug shipped to production for ~3 days before Sponsor's `[combat-trace]` soak caught it).
```

The block is mandatory for `feat(combat|ui|level|integration|gear|progression)` and `fix(...)` on the same scopes when the PR introduces or modifies a visual primitive. Skip when the PR is `chore(...)` / `docs(...)` / `test(...)` or touches no visual primitives.

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

## ClickUp lifecycle (paired flips, same tool round as the action)

Every ticket lifecycle event is a paired ClickUp status move that fires in the SAME tool round as the corresponding action. Per `team/GIT_PROTOCOL.md` § "ClickUp lifecycle as hard gate" + orchestrator memory `clickup-status-as-hard-gate.md`.

```markdown
**ClickUp lifecycle (paired flips, NOT advisory):**
- **At run-start** (if orchestrator hasn't already flipped): `mcp__clickup__clickup_update_task task_id=<ticket> status="in progress"`. Same tool round as your first work.
- **On PR open** (`gh pr create`): immediately fire `mcp__clickup__clickup_update_task task_id=<ticket> status="ready for qa test"` in the same response. The orchestrator-side dispatch flip + your PR-open flip = two complementary safeguards.
- **MCP unreachable:** queue the flip in `team/log/clickup-pending.md` per `team/CLICKUP_FALLBACK.md` (`ENTRY NNN: <ticket_id> -> <new_status> (reason: <one-line>)`). Orchestrator flushes on reconnect.
- **Don't lie to the board.** If you can't open the PR (ran into a blocker), don't flip to `ready for qa test` — keep it at `in progress` and surface the blocker.
```

## Self-Test Report (UX-visible PRs only)

Required for `feat(integration|ui|combat|level|audio|progression|gear)`, `fix(ui|combat|level|audio|integration)`, and `design(spec)` when the spec is consumed by an in-flight `feat` PR. NOT required for `chore(ci|repo|build|state|orchestrator|planning)`, `docs(team|scope)`, `test(...)`, or `.tres`-only data refactors.

Per `team/GIT_PROTOCOL.md` § "Self-Test Report (UX-visible PRs)" + orchestrator memory `self-test-report-gate.md`.

```markdown
**Self-Test Report (REQUIRED before Tess review):**

After `gh pr create`, post a PR comment with the Self-Test Report. Tess's review starts from this report, not from a cold-read of the diff. If you skip it, Tess bounces immediately.

Comment template:

## Self-Test Report

**Build artifact:** <run ID + zip name + sha>
**Scene path:** <res://scenes/Main.tscn or test scene used for verification>
**Verification method:** <browser+local server / godot --headless / GUT integration test waypoint>

### AC walkthrough
- [x] AC1: <description> — observed: <what you saw/heard>
- [x] AC2: ...
- [ ] AC3: <if not personally verified — explain why + what's covered by automated tests>

### Side-effect inventory
- <other surface that might be affected>: <expected vs. observed>

### Open concerns / known gaps
<anything noticed but out of this PR's scope>

**Headless fallback:** if your environment has no browser, drive `godot --headless` against the actual entry scene (Devon PR #107 pattern), capture the GUT integration-test output, and note: "verified via headless integration test, no browser repro available — Sponsor's interactive soak is the final gate."
```

For `chore`/`docs`/`test`/data PRs that don't need a Self-Test Report, replace the block with: `**Self-Test:** <one-line confirmation of what was checked — e.g. "diffed sections against memory rules; no contradictions with sibling docs">.`

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
