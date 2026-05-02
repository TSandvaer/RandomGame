# W3-A7 — Worktree-Isolation v3 Proposal

**Owner:** Orchestrator. **Status:** proposal — awaiting Sponsor / Priya call. **Filed:** 2026-05-02.
**Audience:** Sponsor (decides between options 1/2/3), Priya (PL — may want to file the chosen option as a `docs(team)` PR), Devon (potential implementer of option 2 if chosen), all five agents (consume the brief-template change in option 1).

## TL;DR

**Four occurrences** this session of agents stomping the orchestrator-class checkout's `.git/HEAD` mid-dispatch. Each cost 1-3 tool turns of recovery (stash → checkout → rebase → pop). No data loss, no production-side defect, no merged PR mistakes. **Pure friction tax** on every multi-agent tick.

Three options:

| # | Approach | Cost | Authority needed | Recommended? |
|---|---|---|---|---|
| **A** | Per-role-worktree default in every dispatch brief | 1 tick (orchestrator-side discipline) | None | **Yes — start here** |
| **B** | Harness `WorktreeCreate` hooks in `settings.local.json` | ~3-5 ticks (Devon impl + test) | User authorization (self-modification gate) | Maybe later |
| **C** | Status quo + better recovery docs | 0 (already happening organically) | None | No — doesn't prevent |

**Recommendation:** ship **option A** now. Revisit option B if friction recurs after A is in place for ~3 sessions.

---

## 1. Evidence: the four occurrences

### 1.1 Uma run-002 (audio-direction recovery via cherry-pick)

`git checkout -b` after a contended worktree state landed Uma's HEAD on `devon/levelup-math` (Devon's branch tip) instead of newly-created `uma/audio-direction`. Recovered cleanly via cherry-pick + `git branch -f` to restore Devon's branch tip without losing his work. Source: `team/STATE.md` Uma section, run-003 deliverable note.

### 1.2 Uma run-003 (cherry-pick recovery during audio-direction)

Documented same root cause: shared `.git/HEAD` between orchestrator-class checkout and worktree dispatches. Worked around without rewriting anyone else's history. Source: STATE.md Uma section.

### 1.3 Priya run-004 (HEAD shifted mid-tool-call)

Priya's HEAD shifted to `tess/run-012-state-v2` mid-tool-call between two of her own commands during the mid-week-2 retro run. One stash-pop conflict cost. Source: `team/priya-pl/week-2-retro-and-week-3-scope.md` "What didn't go well" §2.

### 1.4 Tess run-018 (stash + fast-forward rebase)

Main checkout at `c:\Trunk\PRIVATE\RandomGame` was on `uma/stash-ui-v1-design` mid-Tess-run when Uma's parallel W3-B1 dispatch landed PR #82 on `origin/main`. Tess recovered cleanly via stash → checkout `tess/w3-a5-html5-audit` → fast-forward rebase onto Uma's merged `c8a6b69` → pop with auto-merged STATE.md. Source: Tess run-018 PR #83 report.

### Pattern

In all four cases:
1. Two or more agents run in parallel (dispatch density ≥ 2)
2. At least one agent operates in the orchestrator-class checkout `c:\Trunk\PRIVATE\RandomGame` (which is shared)
3. A `git checkout` somewhere flips the shared `.git/HEAD`
4. The unsuspecting agent's next operation hits a state mismatch
5. Recovery is procedural (stash + recheckout + rebase + pop) — costs ~1-3 tool turns

The fix is to **never let two agents share a HEAD**. Each agent gets its own `.git/HEAD`, which is what `git worktree add` provides.

## 2. Option A — Per-role-worktree default in dispatch briefs

**Approach:** every Agent dispatch brief includes (a) a named target worktree path and (b) the `git worktree add` invocation for the agent to run at the start of its work.

**Two variants for the worktree:**
- **A.1 — Per-role persistent worktrees.** Each role has a single sticky worktree: `RandomGame-priya-wt`, `RandomGame-uma-wt`, `RandomGame-devon-wt`, `RandomGame-drew-wt`, `RandomGame-tess-wt`. Agents reuse them across runs (clean state at start of each run via `git fetch origin && git checkout -B <role>/<task-name> origin/main`).
- **A.2 — Per-task ephemeral worktrees.** Each dispatch creates a fresh worktree at `RandomGame-<role>-<task-slug>` and removes it after PR merge. Cleaner isolation but more disk churn.

**Recommended: A.1** — sticky-per-role. Three of five roles already have persistent worktrees (`-devon-wt`, `-drew-wt`, `-tess-wt` exist; `-uma-wt` and `-priya-wt` need creation). Adding two more is one tick. The sticky pattern is what STATE.md already implicitly assumes ("Devon's worktree at `C:/Trunk/PRIVATE/RandomGame-devon-wt`").

**Brief-template change** (insert into every Agent prompt):

```
**Worktree state — IMPORTANT:**
- Operate in `C:/Trunk/PRIVATE/RandomGame-<role>-wt` (your role-persistent worktree).
- At start: `cd C:/Trunk/PRIVATE/RandomGame-<role>-wt && git fetch origin && git checkout -B <role>/<task-name> origin/main`.
- Push by refspec: `git push origin <role>/<task-name>:<role>/<task-name>`.
- Do NOT operate in the main checkout `c:\Trunk\PRIVATE\RandomGame` — it's the orchestrator-class checkout, contended.
- Do NOT touch other agents' worktrees.
```

**Cost:**
- 1 tick to create `RandomGame-uma-wt` and `RandomGame-priya-wt` worktrees and add the brief-template snippet to a `team/orchestrator/dispatch-template.md` doc the orchestrator references on every dispatch.
- Ongoing: orchestrator pastes the snippet into every brief. Already doing this informally; this codifies it.

**Coverage:** **eliminates the four-occurrence pattern entirely** as long as no agent disobeys the brief. Agents that read `agent-verify-evidence.md` know to follow briefs literally.

**Limitation:** the orchestrator itself still operates in two worktrees (`c:\Trunk\PRIVATE\RandomGame` for surveys, `RandomGame-orch-wt` for own commits). Orchestrator-class worktree contention with agent-class worktrees CAN'T happen if agents stay out of `c:\Trunk\PRIVATE\RandomGame`. So this option fully closes the loop.

**Authority needed:** none. Pure orchestrator discipline + a doc add. No harness changes.

## 3. Option B — Harness `WorktreeCreate` hooks

**Approach:** wire a hook into `.claude/settings.local.json` that fires on a `WorktreeCreate` lifecycle event (the schema lists this as a recognized event). When the orchestrator dispatches an Agent with an `isolation: "worktree"` flag, the hook creates a fresh worktree and rewrites the agent's working directory before tool calls run.

**Cost:**
- ~2 ticks: spec the hook script + write it (PowerShell or Python)
- ~1 tick: pipe-test it
- ~2 ticks: prove it fires correctly across 2-3 dispatches
- Ongoing: zero — once installed, agents inherit isolation transparently

**Authority needed:** **user authorization required**. The Stop-hook discussion this session showed auto-mode treats `.claude/` configuration changes as self-modification and gates them on explicit user yes/no. Same gate applies here.

**Why I'm not recommending this NOW:**
- Option A solves the same problem with zero authorization friction
- The user just rejected a similar self-modification proposal (option 3 picked, option 1 rejected)
- If A doesn't fully cover the case after ~3 sessions, B becomes more attractive

## 4. Option C — Status quo + better recovery docs

**Approach:** accept the shared-HEAD pattern, document the stash+rebase recovery procedure in `team/RESUME.md` so every agent reads it on dispatch.

**Cost:** 1 tick to write the doc. Friction tax remains permanent.

**Why I'm not recommending this:** the friction tax is real, growing, and visible. Tess's W3-A5 run was the most expensive recovery yet (rebase across two parallel-merged PRs). Option A solves the problem; option C only treats the symptom.

## 5. Recommendation

Ship **option A**. Concretely:

1. Orchestrator creates `RandomGame-priya-wt` and `RandomGame-uma-wt` worktrees (~2 min, one bash call)
2. Orchestrator drafts `team/orchestrator/dispatch-template.md` with the standard brief snippets (worktree + lesson reminders + done-clause + report-format)
3. Orchestrator updates `team/GIT_PROTOCOL.md` with a one-line addition: "Agents MUST operate in their role-persistent worktree (`RandomGame-<role>-wt`); operating in the orchestrator-class checkout (`c:\Trunk\PRIVATE\RandomGame`) is reserved for the orchestrator's surveys."
4. Future briefs include the snippet by reference

**This is a `docs(team)` change.** Per `team/log/process-incidents.md`, `docs(team)` is exempt from Tess sign-off but the merge identity is orchestrator/Priya. Orchestrator can author + push + merge directly.

## 6. Open questions for Sponsor / Priya

- **Sponsor decision needed?** No — this is operational, within orchestrator's mandate per `ROLES.md`. Filing as a `docs(team)` PR is non-controversial.
- **Priya call?** Worth a heads-up so Priya can fold this into the week-3 close retro as "what we shipped to reduce friction." She might also want to add a row to her risk register (R5: concurrent-agent collisions — currently watch-list, would drop fully).
- **Should orchestrator dispatch this OR self-implement?** Self-implement. Total work is ~5 small file changes; dispatching adds overhead (brief authoring, agent context-load) that exceeds the work itself.

## 7. Decision rule for the orchestrator

- **Today:** ship option A as a self-implemented `docs(team)` PR. No user input required unless the user wants to override.
- **After 3 more sessions (~30 ticks)** with option A in place: if friction occurrences hit 2 in a session OR the same agent repeats the pattern after reading the brief, escalate to option B and request user authorization for the harness hook.
- **Never:** option C (status quo). The pattern is cheap to fix; sitting on it is expensive in compound tax.

---

## Appendix: brief-template snippet (proposed)

For every Agent dispatch, insert verbatim:

```markdown
**Worktree state — IMPORTANT:**
- Operate in `C:/Trunk/PRIVATE/RandomGame-<your-role>-wt` (your role-persistent worktree).
- At start of run: `cd C:/Trunk/PRIVATE/RandomGame-<your-role>-wt && git fetch origin && git checkout -B <your-role>/<task-name> origin/main`.
- Push by refspec: `git push origin <your-role>/<task-name>:<your-role>/<task-name>`.
- Do NOT operate in the main checkout `c:\Trunk\PRIVATE\RandomGame` — that's the orchestrator-class checkout, contended.
- Do NOT touch other agents' worktrees (e.g., don't `cd` into `-tess-wt` unless you ARE Tess).
- If your worktree's branch state is unclean at start of run, reset to `origin/main` cleanly with `-B`. Don't try to recover prior in-flight work — every dispatch starts fresh.
```

This standardizes what's currently ad-hoc. Briefs become shorter (less per-dispatch boilerplate) and more uniform.
