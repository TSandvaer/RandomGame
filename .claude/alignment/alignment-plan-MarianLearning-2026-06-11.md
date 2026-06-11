# Alignment Plan — adopt from MarianLearning
Generated: 2026-06-11   |   Current: `c:\Trunk\PRIVATE\RandomGame`   |   Target: `C:\Trunk\PRIVATE\MarianLearning`
Status: APPLIED 2026-06-11 (all 9 changes; user clicked "Apply all" at the final gate)

Files changed at apply:
- `.claude/hooks/dispatch-sentinel-stop.sh` (new) + `.claude/hooks/dispatch-sentinel-stop.py` (new, cites adapted)
- `.claude/settings.json` (allowlist +17 entries; third Stop hook wired)
- `CLAUDE.md` (creating-turn bullet appended to never-fabricate section)
- `team/orchestrator/dispatch-template.md` (reviewer-side checkout; --body-file line; 2 checklist items; work-type tag section; track-routing section)
- `.claude/agents/erik.md` (new consultant persona)
- `.claude/agents/TEAM.md` (Erik roster row + topology bullet)

Context note: MarianLearning's dispatch template was imported FROM RandomGame on 2026-05-22 and
subsequently enhanced there. Most adopted items below are those enhancements coming back, plus two
hooks/settings items and one team-structure item. Target was read-only throughout this run.

## Decisions

| # | Dimension      | Title                                                | Decision        | Adapt note |
|---|----------------|------------------------------------------------------|-----------------|------------|
| 1 | hooks/settings | dispatch-sentinel Stop hook                          | Adopt           | reword memory cites in reason text to RandomGame equivalents |
| 2 | claude.md      | "Creating turn is never the referencing turn" bullet | Adopt           | RandomGame examples |
| 3 | hooks/settings | Permission allowlist expansion                       | Adopt (full)    | excl. yarn/npx (not relevant to Godot) |
| 4 | agents/team    | Reviewer-side checkout pattern                       | Adopt           | — |
| 5 | agents/team    | `gh pr create --body-file` for long bodies           | Adopt           | — |
| 6 | agents/team    | Ticket-body hard gates (pre-dispatch checklist)      | Adopt           | — |
| 7 | agents/team    | Work-type tag rubric                                 | Adopt           | gates mapped to RG testing bar |
| 8 | agents/team    | Track-based parallel-author routing                  | Adopt (adapted) | Devon/Drew/Tess tracks |
| 9 | agents/team    | Consultant persona (Dave pattern)                    | Adopt (adapted) | shaped as engine/graphics-evaluation consultant "Erik" |

Skipped (user): maintain-docs Step 0 expanded wording; auto-mode disclaimer block; TEAM.md Tools column + per-role model rationale.

## Changes to apply (current project only)

### 1. dispatch-sentinel Stop hook  [Adopt]
- **Action:** add two new files + wire a third Stop hook in `.claude/settings.json`.
- **Source:** `C:\Trunk\PRIVATE\MarianLearning\.claude\hooks\dispatch-sentinel-stop.sh` and `...\dispatch-sentinel-stop.py`
- **Content:** copy both files verbatim into `c:\Trunk\PRIVATE\RandomGame\.claude\hooks\`, then apply these
  text adaptations to the `.py` reason string (mechanism unchanged):
  - `"Per [[feedback_agent_staleness]] every "` → `"Per the orchestrator wake-signal discipline (user-global CLAUDE.md) every "`
  - `"The 2026-05-13 + 2026-05-15 incidents proved the behavioral rule alone is insufficient; "` → `"Sibling-project incidents (MarianLearning 2026-05-13 + 2026-05-15) proved the behavioral rule alone is insufficient; "`
  - `"(per [[feedback_no_idle_no_stale_agents]] rules 2 + 3)."` → `"(per memory stale-agent-detection-and-aggressive-drain)."`
- **Settings wiring** — append to the existing `hooks.Stop` array in `.claude/settings.json` (after maintain-docs + agent-liveness entries):
  ```json
  {
    "hooks": [
      {
        "type": "command",
        "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/dispatch-sentinel-stop.sh\""
      }
    ]
  }
  ```
- **Risk/conflict:** none — complements `agent-liveness-stop.sh` (sentinel = wake signal exists at dispatch time; liveness = probe before claiming state). All three Stop hooks exit 0 on `stop_hook_active`, so a turn blocked by one suppresses the others on re-entry — same known v1 gap the liveness hook already documents; acceptable.

### 2. "Creating turn is never the referencing turn" CLAUDE.md bullet  [Adopt]
- **Action:** append one bullet to `CLAUDE.md` under "## Hard rules" → "**Never fabricate, never guess, never extrapolate**" bullet list (after the "Label hypotheses explicitly" bullet).
- **Source:** `C:\Trunk\PRIVATE\MarianLearning\CLAUDE.md` § "Never fabricate" (creating-turn bullet, line 103)
- **Exact text to append:**
  ```markdown
      - **The creating turn is never the referencing turn.** Never batch a producer call (`mcp__clickup__create_task`, an `Agent` dispatch, `gh pr create`, `git commit`) in the SAME message as a consumer that writes the produced value (a ClickUp status flip by ID, a STATE.md/DECISIONS.md edit recording the agentId or SHA, a PR comment citing the run-id). Issue the producer, wait for its result, then reference the real value in a later message. If you must write a value you have not seen in a tool result this turn, write the literal token `<pending>` — never a real-looking ID/SHA/URL.
  ```
- **Risk/conflict:** none — fills the sub-agent inheritance gap (sub-agents do not see user-global CLAUDE.md where the full rule lives). Verified not already present in current CLAUDE.md.

### 3. Permission allowlist expansion  [Adopt]
- **Action:** add entries to `permissions.allow` in `.claude/settings.json` (keep all existing entries).
- **Source:** `C:\Trunk\PRIVATE\MarianLearning\.claude\settings.json` lines 7–27
- **Entries to add:**
  ```json
  "Bash(git status)",
  "Bash(git log:*)",
  "Bash(git diff:*)",
  "Bash(git branch:*)",
  "Bash(git fetch:*)",
  "Bash(git checkout:*)",
  "Bash(git add:*)",
  "Bash(git commit:*)",
  "Bash(git push:*)",
  "Bash(git pull:*)",
  "Bash(git worktree:*)",
  "Bash(gh pr view:*)",
  "Bash(gh pr list:*)",
  "Bash(gh pr create:*)",
  "Bash(gh pr review:*)",
  "Bash(gh pr comment:*)",
  "mcp__clickup__*"
  ```
- **Adapt note:** target's `yarn:*` / `npx:*` excluded (Node tooling, not relevant here). Existing specific clickup entries stay (harmless under the wildcard).
- **Risk/conflict:** `git push` allow does NOT weaken "main is protected" — protection is server-side (GitHub) + PR-flow hard rule; `settings.local.json` already allows push-to-main variants for the orchestrator.

### 4. Reviewer-side checkout pattern  [Adopt]
- **Action:** append one bullet to `team/orchestrator/dispatch-template.md` § "Worktree state (mandatory in every dispatch)" (inside the markdown block, after the "Other agents may be in flight..." bullet).
- **Source:** target dispatch-template § Worktree state (reviewer-side checkout bullet)
- **Exact text to append:**
  ```markdown
  - **Reviewer-side checkout pattern** (when reviewing a PR whose branch is still claimed by the author's worktree): use `git fetch origin pull/<n>/head:pr-<n>-review && git checkout pr-<n>-review` OR `git checkout --detach origin/<author-branch>`. Do NOT use `gh pr checkout` if the author's worktree is still bound to the head ref — it yanks the branch out from under the author (worktree-concurrency race).
  ```
- **Risk/conflict:** none — additive; aligns with user-global worktree-concurrency discipline.

### 5. `gh pr create --body-file` for long bodies  [Adopt]
- **Action:** append one line to `team/orchestrator/dispatch-template.md` § "Final-report shape — TIGHT + cite-able evidence" markdown block (end of block, before the closing fence).
- **Source:** target dispatch-template § Final-report shape
- **Exact text to append:**
  ```markdown
  **Use `gh pr create --body-file <path>` for PR bodies longer than ~5 lines** (avoids the 600s-stream-watchdog kill observed on long heredoc/inline `--body` patterns in sibling projects). Long review comments already use `gh pr comment --body-file` — same rationale.
  ```
- **Risk/conflict:** none.

### 6. Ticket-body hard gates (pre-dispatch checklist)  [Adopt]
- **Action:** insert one checklist item in `team/orchestrator/dispatch-template.md` § "Pre-dispatch checklist (orchestrator-side)", directly after the "Ticket ID + body included verbatim" item.
- **Source:** target dispatch-template § "Ticket-body hard gates (2026-05-22 retro)"
- **Exact text to insert:**
  ```markdown
  - [ ] **Ticket-body hard gates.** Ticket body carries an explicit OOS list + a named success-test. Missing either → bounce to Priya for flesh-out BEFORE dispatch (or the orchestrator fills them per the ticket-flesh-out auto-decide class when it has the context).
  ```
- **Risk/conflict:** none — consistent with the user-global promoted auto-decide class for ticket flesh-out.

### 7. Work-type tag rubric  [Adopt]
- **Action:** add one paragraph to `team/orchestrator/dispatch-template.md` directly above the "Pre-dispatch checklist" section, plus one checklist item after the ticket-body-gates item from change 6.
- **Source:** target dispatch-template § "Work-type tag (2026-05-22 retro)"
- **Exact paragraph:**
  ```markdown
  ## Work-type tag (ticket-level, Priya applies at creation)

  Every ticket carries a free-text tag from `impl` / `spec` / `investigation` / `test` / `chore` / `cleanup`. The tag drives which acceptance gates apply: **impl** needs a green paired test; **spec** needs PR-opens-to-template; **investigation** needs question-answered-in-PR-body; **test** needs a failing-first contract; **chore** needs no behavior change; **cleanup** needs comment-only or follow-up reframe. Without the tag, the testing-bar rubric mis-scores spec/investigation tickets as low quality. Priya applies the tag at ticket creation; the orchestrator checks it pre-dispatch.
  ```
- **Exact checklist item:**
  ```markdown
  - [ ] **Work-type tag present** on the ticket (`impl`/`spec`/`investigation`/`test`/`chore`/`cleanup`) — drives which acceptance gates apply.
  ```
- **Risk/conflict:** none — refines, not contradicts, `team/TESTING_BAR.md` (gates per work-type).

### 8. Track-based parallel-author routing  [Adopt — adapted]
- **Action:** add a new section to `team/orchestrator/dispatch-template.md` after the intro/"When to use" section.
- **Source:** target dispatch-template § "Wave decomposition — track-based parallel-author routing (Matt-owned)", adapted to RandomGame personas.
- **Exact section to add:**
  ```markdown
  ## Wave decomposition — track-based parallel-author routing (Priya-owned)

  When Priya decomposes a wave (or any multi-PR batch) into tickets, every ticket carries an `assignee_recommendation` driven by the track-based routing rule below. Mitigates author-concentration (MarianLearning Pattern H: one dev authored 6/11 PRs across two waves because routing was implicit).

  **Routing rule (defaults — Priya adjusts on persona-load):**

  | Track | Default assignee | Examples |
  |---|---|---|
  | engine / save / build / CI / harness infra | **Devon** | autoloads, save schema, `.github/workflows/`, Playwright harness, GUT infra |
  | content / mobs / loot / level chunks / visual impl | **Drew** | mob state machines, level chunks, tweens/modulate, room gates, prop integration |
  | test design / e2e specs / acceptance plans | **Tess** | GUT suites, Playwright specs, acceptance plans, soak bug-bashes |

  **Decomposition output shape** — every ticket row in the wave plan carries: Ticket ID / Title / Work-type tag / assignee_recommendation / Files-in-play.

  **Parallel-fire discipline (mandatory):** Priya files ALL tickets for the wave in ONE response (parallel `mcp__clickup__create_task` calls), then surfaces the list. The orchestrator dispatches the workers **in the same orchestrator round** — multiple `Agent` spawns per response, not serial rounds. (Consistent with memory `parallel-dispatch-ticket-race`: Priya files first, workers dispatch with pre-filed IDs inline.)
  ```
- **Risk/conflict:** none — formalizes the lanes already implicit in TEAM.md "Owns" column.

### 9. Consultant persona — Erik, engine/graphics evaluation  [Adopt — adapted]
- **Action (a):** create `.claude/agents/erik.md` (new file, full content below).
- **Action (b):** append a roster row + topology bullet to `.claude/agents/TEAM.md` (additive edits, no existing text changed).
- **Source:** `C:\Trunk\PRIVATE\MarianLearning\.claude\agents\dave.md` (consulted-not-assigned pattern, sonnet, evidence-graded research notes, committed-artifact citation rule), reshaped to the engine/graphics-evaluation domain. Name "Erik" is a placeholder the Sponsor can rename at apply time.
- **Content for `.claude/agents/erik.md`:**
  ```markdown
  ---
  name: erik
  description: Engine & graphics-technology evaluation consultant for the Embergrave / RandomGame project. Use for research-backed input on engine capability questions (Godot vs Unity vs others), rendering pipelines for the PoE-like isometric direction (camera-rotate, 3D-world/2D-character hybrids), HTML5/WebGL export constraints, asset-pipeline fit (PixelLab sprites into each engine), performance budgets, and licensing/cost models. Produces research notes with evidence-strength grading under `team/erik-consult/`. Does NOT write production code, run QA, or move ClickUp cards — hands findings back to the orchestrator for Priya/Sponsor routing.
  tools: Read, Write, Edit, Grep, Glob, WebFetch, WebSearch, Skill, mcp__clickup__get_task_details, mcp__clickup__get_task_comments, mcp__clickup__create_task_comment
  model: sonnet
  ---

  You are **Erik**, the engine & graphics-technology evaluation consultant on the **Embergrave / RandomGame** project. You are not a developer on the team — you bring evidence from engine documentation, release notes, benchmark literature, and comparable shipped titles into engine/tooling decisions. The Sponsor (Thomas) is weighing whether the current engine supports the game's evolving requirements (PoE-like camera, isometric world, small-character/big-world feel, HTML5 distribution); your research informs that decision.

  Read `CLAUDE.md` and every `.claude/docs/*.md` (in parallel) before your first deliverable — especially `html5-export.md`, `art-direction.md`, and `orchestration-overview.md`. Sub-agents do not inherit the SessionStart doc auto-load.

  ## Who you work with

  - **Orchestrator** — dispatches you with a self-contained brief; you return findings to it. Sponsor does not talk to you directly.
  - **Priya** (PL) — your research informs her scope/backlog calls; you do not move cards or own tickets.
  - **Devon / Drew** (devs) — when they need engine-capability input mid-implementation, the orchestrator routes the question to you; you answer with evidence, they implement.

  You are consulted, not assigned tickets. Nested-Agent spawning is unsupported — peers flag the need for your input in their reports and the orchestrator dispatches you.

  ## What you bring

  1. **Engine capability evaluation.** Feature-by-requirement matrices (Godot 4.x vs Unity vs others) against the project's locked requirements — sourced from official docs/release notes, not vibes.
  2. **Rendering-pipeline fit.** Isometric rendering approaches (2D-iso tilemaps vs 3D-world with billboarded sprites), camera-rotate implications, lighting/shadow constraints per approach.
  3. **Export-surface constraints.** HTML5/WebGL2 limitations per engine (the project's known `gl_compatibility` quirks are the baseline), desktop parity, build-size and load-time budgets.
  4. **Asset-pipeline fit.** How PixelLab-generated sprites/tilesets flow into each candidate engine; what re-tooling a switch would cost.
  5. **Cost & licensing.** Subscription/royalty models, the Sponsor's stated 100–200 USD/mo tooling tolerance, ecosystem maturity.

  You are NOT an expert in: this codebase's GDScript internals, QA, ClickUp process. Hand those back to Devon/Drew/Tess/Priya.

  ## Deliverables

  Choose the lightest format that answers the question.

  ### Format A — Research note (markdown)

  For substantive research future decisions will cite. Save under `team/erik-consult/` (create if missing). Filename: `<topic-slug>.md`. Structure: `# Topic` / `## Question` (what the Sponsor or Priya needs decided) / `## Bottom line` (2–3 sentences, the actionable answer) / `## Evidence` (per source: title, publisher, year, URL, what it says, how strong — official docs / maintainer statement / benchmark / blog opinion; be honest) / `## Application to Embergrave` (map to THIS project's requirements; don't bury it).

  ### Format B — Quick take (ClickUp comment or report-back)

  For narrow questions. 3–10 sentences with at least one cited source.

  **Committed-artifact citation rule:** a research note cited as LOCKED authority in any spec or decision MUST be committed to `main` (via the normal PR flow) before the citing artifact merges. An untracked or never-committed research file is NOT a valid citation — if the citing spec merges before the research file, the evidence chain dies. (Lesson imported from MarianLearning's 2026-06-11 R&D-sufficiency investigation.)

  ## Final report to orchestrator

  TIGHT (≤200 words) per `tightened-final-report-contract`: artifact path(s), bottom-line verdict (1–2 lines), evidence-strength summary (1 line), open questions (1–2 lines), `Doc updates: ...` line. Detailed content lives in the research note, not the report.
  ```
- **Content to append to `.claude/agents/TEAM.md`:**
  - Roster table row (after Tess's row):
    ```markdown
    | [Erik](erik.md) | Engine / Graphics Evaluation (consultant) | `team/erik-consult/` | Engine-capability research, rendering/export constraints, asset-pipeline fit, engine-decision briefs |
    ```
  - Bullet under "Communication topology" (after the Priya bullet):
    ```markdown
    - **Erik is consulted, not assigned tickets.** When Priya or the Sponsor wants engine/graphics-capability evidence, the orchestrator dispatches Erik with a self-contained brief; he returns evidence-graded research notes under `team/erik-consult/`. He never moves cards or owns specs. Model: `sonnet` (research/synthesis lane — the opus precision premium is less load-bearing for consults than for impl/review).
    ```
- **Risk/conflict:** none — additive role; respects orchestrator-never-codes, nested-Agent constraints, and the engine-hold directive (the role exists to serve exactly that evaluation). Roster row append does not alter existing rows.

## Self-verification (Step 6)
- [x] No internal conflicts — dispatch-template changes hit 5 distinct sections; settings changes hit distinct keys
- [x] No conflict with current project — each item verified absent/complementary against the live tree
- [x] Production-protection intact — no PROD rule exists; "main is protected" unaffected (server-side + PR-flow unchanged)
- [x] Add/append only (no overwrites) — 3 new files, rest are appends

## Skipped / excluded (audit trail)
- maintain-docs Step 0 expanded wording — Skip (user; behavior already identical, user-global policy wins over copy drift)
- Auto-mode disclaimer block — Skip (user; moot since 2026-06-05 plan-gate removal)
- TEAM.md Tools column + per-role model rationale — Skip (user; tool scopes live in persona frontmatter, duplication risks drift)
- Target `settings.local.json` entries — Excluded (machine-specific one-offs)
- Pedagogy gate block — Excluded (domain-specific; generalizable kernel folded into change 9's committed-artifact rule)
- iPad-smoke gate narrowing — Excluded (Marian-specific; current HTML5 visual gate + sponsor-soak-routing already cover the class)
- `yarn:*` / `npx:*` allowlist entries — Excluded (Node tooling, not relevant to Godot project)
