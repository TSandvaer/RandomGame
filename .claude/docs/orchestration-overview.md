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
- **The orchestrator never codes** — does not read source, grep, trace bugs, or edit code. Dispatches agents from symptoms instead. See memory: `orchestrator-never-codes.md`. **Exception: R&D lane** — see the "R&D lane" section below for the narrow class of orchestrator-direct work that is legitimate and its mandatory harvest gate.
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

### Sponsor's design worktree — `RandomGame-design`

Sponsor's Godot editor opens `C:/Trunk/PRIVATE/RandomGame-design` (branch `sponsor/s1-design`),
**not** the main repo. It appears in `git worktree list` like the role worktrees — but it is
Sponsor-only territory: agents never commit to `sponsor/s1-design`.

**Delivery rule (verified 2026-06-10):** any scene, script, resource, or asset Sponsor must
open or paint in his editor must exist in the design worktree at the **same relative path** as
in the main repo. The main repo is canonical; design-worktree copies are untracked soak/design
artifacts. A main-repo-only write silently fails the handoff — the file simply never appears in
Sponsor's FileSystem dock (no error anywhere), costing a screenshot round-trip to diagnose.

**Delivering-agent convention:** as the final step of a dispatch — before submitting the
Self-Test Report — mirror-copy all Sponsor-facing files (including every script/resource the
scene depends on) into the design worktree:

```bash
cp "C:/Trunk/PRIVATE/RandomGame/scenes/levels/demo/iso_proof.tscn" \
   "C:/Trunk/PRIVATE/RandomGame-design/scenes/levels/demo/iso_proof.tscn"
```

**Detection fingerprint:** Sponsor's FileSystem dock shows design-worktree-only files
(`s1_yard_authored.tscn`, `s1_prop_palette.tscn`) but lacks a path you know exists in main →
his editor root is the design worktree and your file wasn't mirrored.

**Import-order wrinkle:** after copying new resources, Sponsor's editor must rescan + import
them BEFORE a scene referencing them reloads — a scene loaded before its new dependencies are
imported silently drops the reference (observed: TileMapLayer with empty `tile_set`). Fix:
**Project → Reload Current Project** in Sponsor's editor.

**Headless-script import prerequisite (agent-side sibling):** when an agent runs a `--script`
pass against a project copy that contains never-imported assets, Godot errors with "No loader
found for resource" and cascading ext_resource failures — the same root cause as the
editor-side wrinkle above, surfaced differently. Fix: run `--headless --path <project>
--import` once before any `--script` pass. Full pattern + cold-start noise guide in
[`.claude/docs/godot-headless-tooling.md`](.claude/docs/godot-headless-tooling.md).

## Dispatch conventions

A dispatch brief should include:

1. **Worktree setup**: explicit `git checkout -B <agent-branch> origin/main` in the role's worktree
2. **Goal / scope** — what to build, what's in/out of scope
3. **Constraints** — paired tests, CI gates, HTML5 verification gate, Self-Test Report requirement
4. **ClickUp ticket ID** if one exists; instructions to flip status as they progress
5. **Report format** — structured final report (PR #, files touched, tests added, ticket moves, artifact links)
6. **Read `.claude/docs/` at start** — sub-agents do not inherit the SessionStart auto-load (see "Sub-agent doc-reading" below)

### Step 0: `cd <worktree>` — naming is not enough

Sub-agent shell tools inherit the **orchestrator's** working directory, not the worktree path that the dispatch brief names. **Naming the worktree in the brief is not sufficient** — the sub-agent will happily edit files in the inherited cwd (the project root) unless its very first action is a physical `cd <worktree-path>` (or every command is prefixed with `git -C <worktree-path>`).

**Failure mode (observed 2026-05-22, Devon W1 camera-scroll spike):** Dispatch brief specified `Worktree: C:/Trunk/PRIVATE/RandomGame-devon-wt`. Devon's edits to `scripts/camera/CameraDirector.gd`, `tests/test_camera_director.gd`, `scenes/spike/`, `scripts/spike/`, and `tests/playwright/specs/camera-scroll-spike.spec.ts` all landed in `C:/Trunk/PRIVATE/RandomGame` (orchestrator's survey root). Devon-wt itself was clean at `HEAD = 82295e3` with only untracked scratch markdown. Recovery cost: SendMessage to relocate the WIP, plus a same-session re-survey to confirm devon-wt was actually being used after that. This is a recurring failure mode, not a one-off.

**Dispatch-brief rule — every brief that targets a role worktree MUST begin with an explicit Step 0:**

```
Step 0 (DO THIS FIRST, before any other tool call):
  cd C:/Trunk/PRIVATE/RandomGame-<role>-wt
  git fetch origin
  git checkout -B <agent-branch> origin/main
  pwd  # verify
```

Alternative when only one or two git operations are needed: prefix every command with `git -C <worktree-path>` so cwd is irrelevant. For multi-step work (edits, GUT runs, builds, `gh` invocations), `cd`-once is more reliable than per-command `-C` because it also captures non-git tools (Read/Edit/Write/Grep when run without absolute paths).

**Recovery when WIP lands in root:** `git -C <root> diff` to capture the patch, apply in the target worktree via `git -C <target-wt> apply`, then `git -C <root> checkout -- .` and clean untracked files. The orchestrator's survey root should always be clean — any `M` or untracked artifacts there are a worktree-inheritance bug, not legitimate work.

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
- **Outcome over motion — surface structural gaps, don't polish surfaces** (memory `orchestration-outcome-over-motion.md`; S1-yard 8-bounce incident 2026-06-08). Non-negotiable orchestration disciplines: (1) **≥2 Sponsor rejections of the same surface = wrong layer/tool → escalate the APPROACH, not another tweak** (the S1 yard got 8 tile-tweak rounds while the real gap — no map was ever DESIGNED — went unnamed). (2) **Every deliverable needs a QUALITY-owner + internal gate**; a green CI / Tess-mechanical-APPROVE means "it runs," NOT "it's good" — if no role owns "is this actually good," that judgment wrongly falls to the Sponsor. (3) **Direction ≠ design ≠ done**: vision-prose built literally comes out mechanical; validate the substance of a deliverable, not that a PR/asset exists. (4) **Never present work to the Sponsor as "ready / bless it" unless the orchestrator genuinely believes it's good** — overstating completion is the trust-killer. (5) **A problem the SPONSOR catches = a broken internal gate** → fix the gate, don't just fix the one bug and keep forwarding (Sponsor-as-QA-loop violates `testing-bar`). (6) **Verify against the running game, not a proxy** that can diverge (the render-tool false-approval, `art-direction.md` Execution lessons).

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

### False-failure: `gh pr merge` from a detached-HEAD cwd

Running `gh pr merge <N> --admin --squash --delete-branch` with the **cwd inside a
detached-HEAD worktree** (e.g. after `git switch --detach HEAD`) prints:

```
could not determine current branch: failed to run git: not on any branch
```

This looks like a total failure, but it is **not**. The server-side squash-merge (step 1)
and remote-branch deletion (step 2) both succeeded on the first call. Only the local
post-merge context lookup failed. The board may appear to lie — ClickUp still shows
"ready for qa test" if the paired flip was queued after the merge call — but the PR
itself is already closed.

**Ground-truth check:**

```bash
gh pr view <N> --json state,mergedAt -q '"\(.state) | mergedAt: \(.mergedAt)"'
# → MERGED | mergedAt: 2026-06-11T22:15:00Z  → already done, take no further merge action
# → OPEN   | mergedAt: null                  → genuinely failed; retry from repo root
```

**Recovery:** If the state is `MERGED`, the ClickUp flip that was short-circuited is the
only remaining action — fire it immediately. If you retry the merge it will return
"Pull request was already merged" (harmless), completing local cleanup; then run the
paired ClickUp flip.

**Prevention:** Run `gh pr merge` from the **repo root** (`C:/Trunk/PRIVATE/RandomGame`),
not from a role worktree. The detach step (`git -C <worktree> switch --detach HEAD`)
still happens in the agent worktree before the orchestrator fires the merge — that
detach prevents the branch-hold failure described in the section above. Only the *cwd*
of the merge call itself matters; use the repo root.

**Contrast with the branch-hold failure above:** the branch-hold failure emits
`error: Cannot delete branch '<name>' checked out at '<path>'`; this false-failure emits
`could not determine current branch: not on any branch`. Both are verified by
`gh pr view <N> --json state,mergedAt`; if `state=MERGED` the merge succeeded and only
cleanup/ClickUp remains.

Validated 2026-06-12 (PR #436 merge, timestamp 2026-06-11T22:15Z).

### Orchestrator survey root silently drifts behind `origin/main` after server-side merges

The orchestrator merges PRs via `gh pr merge --admin --squash --delete-branch` — a **server-side**
operation that advances `origin/main` on GitHub but does **NOT** advance the local `main` checkout
in the survey root (`C:/Trunk/PRIVATE/RandomGame`). After several merge rounds the local working
tree can sit multiple commits behind `origin/main` while every `git fetch` correctly updates the
`origin/main` ref (confirmed in practice at **7 commits behind**, 2026-06-07).

**Symptom:** files committed by merged PRs are **invisible** to local `Read` / `Grep` / `Glob` /
`find` — `git status` shows a clean tree, but the files simply aren't in the checkout.
`git show <sha>:<path>` proves they're in history. Sub-agents who `cd` into the survey root see the
same stale state.

**Detection:** `git rev-list --left-right --count HEAD...origin/main` — a right-side count > 0
means origin is ahead and local needs updating.

**Fix:**

```bash
git -C C:/Trunk/PRIVATE/RandomGame stash            # preserve any doc-WIP (maintain-docs edits)
git -C C:/Trunk/PRIVATE/RandomGame merge --ff-only origin/main
git -C C:/Trunk/PRIVATE/RandomGame stash pop        # restore WIP
```

**Watch for untracked collisions:** if a merged PR now *tracks* a file that existed locally as
*untracked* (e.g. a scope doc authored locally then committed via a PR from a role worktree), the
`--ff-only` errors with "untracked working tree files would be overwritten." Back up + remove the
local copy, run the ff, then diff the backup against the now-merged version to confirm no loss.

**When it matters most:** whenever the orchestrator needs to read merged-PR content locally — e.g.
judging a newly-merged asset against a just-merged base, or reading a script a sub-agent landed.
A `git fetch` alone is NOT sufficient; the checkout must also advance. Role worktrees are unaffected
(they `git fetch && git checkout main && git pull` explicitly in Step 0) — only the survey root drifts.

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

## R&D lane

This section codifies conventions that have been practiced but never documented. Source: R&D investigation 2026-06-11 (3-agent investigation of R&D capability gaps).

### What the R&D lane is

R&D bursts — rapid art generation, procedural math experiments, headless engine wiring, proof-of-concept scenes — have historically run orchestrator-direct. The "orchestrator never codes" rule was never formally adjusted for this, creating ambiguity and, more importantly, a recurring absorption gap: R&D generation ran fine; R&D *absorption* (peer review, harvest PRs, productionization tickets) did not. The iso sprint of 2026-06-08..11 is the clearest example: PRs #421/#423 + ~405 untracked entries (scripts, atlases, scenes, docs) with zero peer review of orchestrator-authored code and zero productionization tickets filed.

### Legitimate orchestrator-direct R&D

Two classes are legitimately orchestrator-direct. Everything else dispatches to Devon or Drew.

**Class A — MCP-bound generation.** PixelLab (`create_character`, `animate_character`, `create_isometric_tile`, etc.) and pixel-mcp tools are user-scope MCP servers that do not inherit to sub-agents (memory: `sub-agent-mcp-tool-surface-scope`). Generation against these tools runs in the main orchestrator session. Integration of generated assets into the codebase (wiring `.tres` files, writing GDScript) dispatches to Devon or Drew.

**Class B — Sponsor-interactive style/feel iteration.** When Sponsor is live and iterating on visual style or feel in real time — reviewing a generated sprite, asking for a palette tweak, comparing two tile variants — the latency of a sub-agent dispatch cycle (5-15 min per round) makes the loop unworkable. Orchestrator handles the live interactive slice; the resulting implementation dispatches to the team. The 2026-06-08 Sponsor review session (8 style-bounce rounds in one day) is the canonical example of this class.

### MCP-free R&D dispatches to Devon or Drew

Procedural math (numpy/PIL tile pipelines), headless Godot engine wiring, `.tscn` scene authoring, GDScript tool scripts, atlas generation logic — none of these require MCP tools and all are dispatchable. The ~60-70% of the 2026-06-08..11 iso sprint work that fell into this class should have dispatched to Devon (engine/headless surface) or Drew (game-side/content surface) per normal routing. Orchestrator running it directly was a process error, not a deliberate policy.

**Default routing:**
- Engine wiring, headless tooling, `_check_*.gd` scripts → Devon
- Scene authoring, level content, game-side scripts → Drew

### Harvest gate (mandatory after every R&D burst)

Every R&D burst — however small — closes with all three of the following. Skipping any one is a process error.

1. **Harvest PR.** An orchestrator-authored PR committing all generated artifacts and docs: scripts, atlases, `.tres` files, `.tscn` scenes, `.md` docs, and any `.claude/docs/` updates. The PR body states what each artifact is and where it came from (generation tool + parameters for art; authoring notes for code). No artifacts remain untracked after the burst.

2. **Peer review of orchestrator-authored code.** Any GDScript, `.tscn`, or tool script authored by the orchestrator during the burst requires a Devon or Drew peer review before it enters `main`. Surface routing follows the `tess-cant-self-qa-peer-review` convention: engine/harness surface → Devon; game-side surface → Drew. Art assets (sprites, atlases, tilesets) do not require code peer review but must still land via the harvest PR.

3. **Productionization tickets.** Priya files tickets for anything the R&D output enables but does not complete: wiring into the production play loop, integration tests, UX polish, Sponsor soak gates. These tickets are dispatch-ready at filing — not placeholders. The iso sprint productionization tickets (H1–H4 below, ENTRY 2026-06-11-001 through 2026-06-11-004) are the first instance of this rule being applied retroactively.

### Precedent trail

This rule is codification, not invention. All three precedents ran orchestrator-direct under the "R&D is different" implicit understanding; this section makes the understanding explicit and adds the harvest gate that was missing.

| Precedent | Date | What ran orch-direct | Absorption gap |
|---|---|---|---|
| Camera-scroll spike (PR #314) | 2026-05-22 | CameraDirector API + spike scene | Spike doc written; W2 retrofit ticket filed. Harvest gate close-to-met (spike was scoped for absorption from the start) |
| Procgen FloorAssembler spike (PR #328) | 2026-05-23 | FloorAssembler math + AssembledFloor shape | Spike doc written; W2 impl tickets filed. Same pattern — intentionally spike-shaped |
| Iso sprint (PRs #421, #423 + untracked) | 2026-06-08..11 | numpy/PIL tile pipelines, headless engine wiring, 11 building scenes, iso proof atlases, godot-headless-tooling.md, art-direction.md, pixellab-pipeline.md delta | ~405 untracked entries; zero peer review of orch-authored code; zero productionization tickets; RESUME.md stale. The gap this rule closes. |

## Cross-references

- Team-process docs (collaboration / process / role briefs): `team/` — TESTING_BAR.md, GIT_PROTOCOL.md, ROLES.md, RESUME.md, STATE.md, DECISIONS.md, plus per-role subdirs (`team/devon-dev/`, `team/uma-ux/`, etc.)
- Architecture / system reference for Claude context: `.claude/docs/` (this folder)
- Auto-memory (orchestrator durable preferences across sessions): `~/.claude/projects/c--Trunk-PRIVATE-RandomGame/memory/` (outside the repo; user's local Claude Code state)
