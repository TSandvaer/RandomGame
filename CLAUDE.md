# Embergrave / RandomGame

A 2D action-RPG built in **Godot 4.6** with HTML5 export as the primary distribution surface. Working title surfaced in build artifacts is `embergrave`; the repo and ClickUp board still carry the legacy name `RandomGame`.

## Context

- **Director / sole stakeholder ("Sponsor"):** Thomas. Single delegated decision-maker; orchestrator handles team coordination.
- **Engine:** Godot 4.6 stable (4.6.3.stable.official; migrated from 4.3 via 86ca65gyv 2026-06-08). HTML5 export uses `gl_compatibility` renderer (WebGL2). Desktop dev uses `forward_plus` / `mobile`.
- **Distribution:** GitHub Actions release-build → HTML5 artifact (`embergrave-html5-<sha>.zip`) downloaded by Sponsor for soak. itch.io deploy planned post-M1.
- **Codebase shape:** GDScript only; `scripts/`, `scenes/`, `resources/`, `assets/`, `tests/` (GUT). M1 RC is the current milestone target.

## Architecture

**Orchestrator + named-agent team model.** The Claude Code main session is the orchestrator. Five named-role sub-agents (Priya / Uma / Devon / Drew / Tess) handle dispatched work, each in their own per-role git worktree. The orchestrator never codes — it briefs, dispatches, gates, and merges. Sponsor talks only to the orchestrator. Full topology and conventions in [`.claude/docs/orchestration-overview.md`](.claude/docs/orchestration-overview.md).

Combat runtime: Player swing → Hitbox spawn (encapsulated `_init` deferred-monitoring pattern) → mob `_die` chain → death-tween + parallel SceneTreeTimer safety-net → `_force_queue_free`. Full combat-system topology in [`.claude/docs/combat-architecture.md`](.claude/docs/combat-architecture.md).

HTML5 / WebGL2 has several load-bearing divergences from desktop (HDR clamp, Polygon2D rendering quirks, service-worker cache). Full HTML5-export rules in [`.claude/docs/html5-export.md`](.claude/docs/html5-export.md).

## Tech stack

- **Godot 4.6** — game engine; `project.godot` configures both desktop and HTML5 renderers
- **GUT** (Godot Unit Test) — unit + integration tests under `tests/`; CI runs via headless Godot in GitHub Actions
- **GitHub Actions** — `ci.yml` (CI on every push/PR) + `release-github.yml` (HTML5 export on demand)
- **ClickUp** — single source of truth for tickets; integrated via `mcp__clickup__*` tools
- **`gh` CLI** — PR + run management; `--admin --squash --delete-branch` is the standard merge

## Team roster

Canonical roster + topology lives in [`.claude/agents/TEAM.md`](.claude/agents/TEAM.md). Per-role persona briefs at [`.claude/agents/{priya,uma,devon,drew,tess}.md`](.claude/agents/) — read by the orchestrator when dispatching and self-read by sub-agents at session start. The `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` flag is set in `.claude/settings.json` for forward-compat; currently inert in this Claude Code build (memory `agent-teams-flag-is-inert`).

## Hard rules (orchestrator + team)

These are non-negotiable. Memory rules at `~/.claude/projects/c--Trunk-PRIVATE-RandomGame/memory/` enforce them across sessions:

- **`main` is protected.** PR-flow + `gh pr merge --admin --squash --delete-branch` only.
- **Testing bar.** Paired tests + green CI + edge probes + Tess sign-off mandatory before "complete". Sponsor will not debug.
- **HTML5 visual-verification gate.** Tween / modulate / Polygon2D / CPUParticles2D / Area2D-state PRs need explicit HTML5 verification before merge.
- **Self-Test Report gate.** UX-visible PRs (feat/fix on ui/combat/integration/level/audio) need an author-posted Self-Test Report comment before Tess will review.
- **ClickUp status as hard gate.** Every dispatch / PR-open / merge pairs with a ClickUp status move in the same tool round.
- **Orchestrator never codes.** Don't read source, grep, trace bugs, or edit code. Dispatch agents from symptoms instead.
- **Always parallel dispatch.** Every tick has 3-5 agents in flight; tickets aren't progress, dispatches are.
- **Agent liveness from probe, NEVER assumption.** NEVER tell the Sponsor — or write into STATE.md — that an agent is "in flight" / "running" / "waiting-on" because you dispatched it. A returned `agentId` means *launched*, not *running*; a background agent can complete or drop in under a minute. Report liveness ONLY from a fresh `SendMessage`-by-agentId probe (`"is still running"` = alive; `"had no active task; resumed from transcript"` = already idle) + `git log` on the worktree + `gh pr view`. Sponsor escalated hard 2026-05→06-02 after twice being told "Devon in flight" when he'd been idle the whole time. Enforced mechanically by the `agent-liveness-stop.sh` Stop hook (blocks the turn when a prior-turn background dispatch is unprobed + uncompleted) and behaviorally by memory `never-report-agent-state-from-assumption` + the global background-agent-staleness-verification rule.
- **Tightened final-report contract.** Sub-agent reports to orchestrator are TIGHT (≤200 words, PR URL + verdict + blockers + doc-updates line). Detailed content goes in PR body + Self-Test Report. Memory: `tightened-final-report-contract`.
- **ALWAYS give Sponsor a direct artifact download URL for soak.** Any message that expects Sponsor to launch / install / soak a build MUST contain the fully-resolved `https://github.com/<owner>/<repo>/actions/runs/<run_id>/artifacts/<artifact_id>` URL inline — no placeholders, no "scroll to Artifacts" instructions, no run-page-only references, no `<run-id>` template strings. If the artifact ID isn't yet known (build in progress), commit explicitly to provide the resolved URL when ready and follow through. Memory: `sponsor-soak-artifact-links` — re-flagged 3 times (PR #143 May 6, PR #304 May 22, W2-T5 May 24). Sponsor has explicitly escalated this rule to hard-rule status 2026-05-24.
- **CI-status command discipline.** When checking "is CI green?" for a merge-gate decision, use `gh pr view <num> --json statusCheckRollup -q '.statusCheckRollup[] | {name, status, conclusion}'` OR `gh run view <run-id> --json status,conclusion` (both authoritative). Do NOT rely on `gh pr checks <num>` for merge decisions — it can cache "pending" for 2+ hours after the underlying run completes, burning polling cycles. Sanity check: any "pending" >30 min → drill in with the authoritative command before concluding "still waiting". Complements memory `gh-run-list-race-on-just-pushed` (query CI by HEAD SHA, not `--branch --limit 1`).
- **Never fabricate, never guess, never extrapolate** (sub-agent inheritance surface). Concrete values — URLs, IDs, SHAs, file paths, command output, ticket / run IDs, file:line refs — must be fetched from a real source, never invented or extrapolated from sibling patterns. Sub-agents do NOT inherit user-global `~/.claude/CLAUDE.md`; this project-level rule is the inheritance surface, and `team/orchestrator/dispatch-template.md` § Final-report shape enumerates the cite-able-evidence shapes.
    - **No pattern extrapolation.** PR preview URLs, artifact IDs, hashes, ticket IDs, SHAs, generated paths are NOT predictable from siblings — the hash suffix is generated; you have no way to know it without fetching it. Pattern-completion ("the slug probably follows X-Y-Z") is the failure mode this rule exists to prevent.
    - **Fetch, don't guess.** PR URL: `gh pr view <num> --json url -q .url`. Ticket state: `mcp__clickup__get_task_details` (orch-side only — sub-agents lack the MCP tool; route via `team/log/clickup-pending.md` per `team/CLICKUP_FALLBACK.md`). SHA: `git log -1 --format=%H` or `git rev-parse <ref>`. File:line: `grep -n <pattern> <file>` on the live file in your worktree. CI run ID/status: `gh run list --limit 1 --json databaseId,status,conclusion` or `gh pr view <num> --json statusCheckRollup`. If you can't fetch right now, say so explicitly.
    - **STOP-and-verify signal phrases.** "Should be at...", "probably...", "lives in...", "is the same as..." used without a concrete check = STOP and verify before stating the value. Extends beyond concrete values to claims about state (where a file lives, whether two things are the same, what scope a setting has).
    - **Observed-symptom claims need a real source in the same paragraph.** PR bodies, Self-Test Reports, ClickUp comments, `team/log/process-incidents.md` entries: every concrete value (run-id, file path, SHA, command-output snippet, error text, screenshot caption) must be quoted from a verifiable source you just generated. Phrasings like "Output was Y" / "Concrete instance: <value>" read as observed reality and create false evidence if invented.
    - **Label hypotheses explicitly.** If the symptom is inferred / predicted / not directly observed, prefix it: `Hypothesis:`, `Likely:`, `Predicted symptom (verify before patching):`, or `Speculative — no source yet`. A future reader (often a sub-agent dispatched against the ticket) cannot distinguish your observation from your invention if you don't mark which is which.

## Detailed Documentation

**Always read the relevant `.claude/docs/` files at the start of a task when the work touches that area.** These docs contain essential architectural context that is not repeated elsewhere — they are auto-loaded into context at session start via `.claude/hooks/session-start-read-docs.sh`, so you typically do not need to Read them manually.

The `maintain-docs` skill (auto-triggered after every turn via the Stop hook) reviews each turn for non-obvious findings worth capturing here, and updates this index when new doc files are created. Most turns produce nothing doc-worthy; the early-exit filter is high.

### Sub-agents — read the docs at start

**If you are a sub-agent spawned via the Agent tool, you do NOT inherit the SessionStart auto-load.** Before starting any work, Read every `.claude/docs/*.md` file (in parallel). These are the canonical project-context briefs the main session sees automatically; without them you are working blind on combat architecture, HTML5 export quirks, and orchestration conventions. Sub-agents should also include a "Non-obvious findings" section in their final report so the main session can route insights into the docs via the maintain-docs Stop hook.

For deep-dive reference, see the topic files in `.claude/docs/`:

<!-- Index entries are added below as docs land. Format: `- [Title](.claude/docs/<filename>.md) — one-line hook` -->

- [Orchestration Overview](.claude/docs/orchestration-overview.md) — orchestrator + team topology, named-agent roster, worktree pattern, dispatch conventions, hard gates, cron rules, sub-agent doc-reading pointer
- [Combat Architecture](.claude/docs/combat-architecture.md) — Player swing flow, Hitbox / Projectile encapsulated-monitoring pattern, mob `_die` death pipeline, hit-flash / death-tween, `[combat-trace]` shim, Godot 4 physics-flush rule
- [HTML5 Export](.claude/docs/html5-export.md) — `gl_compatibility` quirks (HDR clamp, Polygon2D, z-index), service-worker cache trap, BuildInfo SHA verification, visual-verification gate, release-build + artifact handoff pattern, diagnostic-build pattern, Sponsor soak ritual
- [Audio Architecture](.claude/docs/audio-architecture.md) — 5-bus layout (`default_bus_layout.tres`), `AudioDirector` autoload with BGM/Ambient/crossfade players, S1→S2 entry-trigger wiring, boss-room crossfade pattern, HTML5 audio-playback gate (AudioContext user-gesture requirement)
- [Test Conventions](.claude/docs/test-conventions.md) — universal warning gate (GUT `NoWarningGuard` + `WarningBus`, Playwright `test-base.ts` fixture), Godot 4.3 logger-API limitation that shapes the wrapper design, two-surface (GUT + Playwright) complementary coverage, visual-primitive testing tiers
- [Pixel-mcp Pipeline](.claude/docs/pixel-mcp-pipeline.md) — pixel-mcp tool bugs (`draw_pixels` silently broken, `fill_area` global-replace trap), canonical RGB-first pipeline ordering, aspect-ratio two-step downsample, Windows path escape, doctrine palette lock worked example (S1 Grunt)
- [PixelLab Pipeline](.claude/docs/pixellab-pipeline.md) — PixelLab tool sequence (create_character → get_character → curl), canvas-size trap (`size` is character height not canvas), quantize dupe-slot mitigation, doctrine-compliance strategies (per-slot nearest-neighbor validated as BEST), cost model, `import_image` param trap
- [TimeScaleDirector](.claude/docs/time-scale-director.md) — stacked-request ownership of `Engine.time_scale`, priority-overlay resolution, `freeze()` sugar with `ignore_time_scale` timer, InventoryPanel migration policy
- [Dialogue System](.claude/docs/dialogue-system.md) — DialogueTreeDef / DialogueBranch / DialogueResponse Resource schema, DialogueController autoload (single-session + branch resolution + quest_action side-effect channel), DialoguePanel modal UI, Player attack-input gating convention seed
- [Camera Layer](.claude/docs/camera-layer.md) — `CameraDirector` autoload + zoom API (T9), Director-with-internal-puppet pattern (sibling to `AudioDirector` / `TimeScaleDirector`), default-zoom = viewport-stretch ratio calibration (NOT `Vector2(1,1)`)
- [Camera Scroll](.claude/docs/camera-scroll.md) — continuous-scroll `follow_target` + deadzone + `set_world_bounds` clamp on `CameraDirector` (M3 Tier 3 W1 spike PR #314), foundation for S1 retrofit / procgen `assemble_floor` / S2 consumers
- [Procgen Pipeline](.claude/docs/procgen-pipeline.md) — FloorAssembler seed-cascade (world_seed → stratum_seed → zone_seed), port-mating record-not-raise convention, port-additivity invariance, AssembledFloor output shape (M3 Tier 3 W1)
- [Save Architecture](.claude/docs/save-architecture.md) — version-gate `_upgrade_payload` for breaking changes, additive `has()`-guard reads for forward-compat fields, unconditional backfill outside the version-gate for same-version feature additions (PR #352 `_backfill_v5_tier3_quest_fields` pattern)
- [Quest System](.claude/docs/quest-system.md) — QuestDef / QuestState / QuestStateResolver schema, QuestActionRouter autoload (listener stub + bounty-state persistence via `accept_bounty` / `complete_bounty` verbs), Player.active_bounty save round-trip seam, existence ≠ invocation Main.gd wiring gotcha (PR #347 → #352 → #362), sub-track 5b TBD bounty-content surface
- [Sponsor Soak Routing](.claude/docs/sponsor-soak-routing.md) — when Playwright + Tess is sufficient (mechanical correctness) vs when Sponsor soak is the binding gate (subjective feel, first-of-class visual, tier-completion); right-sizing the Sponsor ask

## Key references outside `.claude/docs/`

- **Team / process docs:** [`team/`](team/) — TESTING_BAR.md, GIT_PROTOCOL.md, ROLES.md, RESUME.md, STATE.md, DECISIONS.md, plus per-role subdirs (`team/devon-dev/`, `team/uma-ux/`, `team/drew-dev/`, `team/priya-pl/`, `team/tess-qa/`). These are collaboration/process artifacts (testing standards, git conventions, dispatch templates, process-incident logs); the architectural reference is in `.claude/docs/`.
- **Auto-memory** (orchestrator durable preferences across sessions, outside the repo): `~/.claude/projects/c--Trunk-PRIVATE-RandomGame/memory/` — sponsor-decision-delegation, testing-bar, team-roster, git-and-workflow, orchestrator-never-codes, html5-visual-verification-gate, godot-physics-flush-area2d-rule, diagnostic-build-pattern, etc.
- **Session state files:** `~/.claude/projects/c--Trunk-PRIVATE-RandomGame/sessions/` — written by the `save-session` skill at end-of-session, read by the next session's resume command.
- **Process-incident log:** [`team/log/process-incidents.md`](team/log/process-incidents.md) — append-only chronicle of orchestration / engineering incidents with their remediation.
