# Embergrave / RandomGame

A 2D action-RPG built in **Godot 4.3** with HTML5 export as the primary distribution surface. Working title surfaced in build artifacts is `embergrave`; the repo and ClickUp board still carry the legacy name `RandomGame`.

## Context

- **Director / sole stakeholder ("Sponsor"):** Thomas. Single delegated decision-maker; orchestrator handles team coordination.
- **Engine:** Godot 4.3 stable. HTML5 export uses `gl_compatibility` renderer (WebGL2). Desktop dev uses `forward_plus` / `mobile`.
- **Distribution:** GitHub Actions release-build → HTML5 artifact (`embergrave-html5-<sha>.zip`) downloaded by Sponsor for soak. itch.io deploy planned post-M1.
- **Codebase shape:** GDScript only; `scripts/`, `scenes/`, `resources/`, `assets/`, `tests/` (GUT). M1 RC is the current milestone target.

## Architecture

**Orchestrator + named-agent team model.** The Claude Code main session is the orchestrator. Five named-role sub-agents (Priya / Uma / Devon / Drew / Tess) handle dispatched work, each in their own per-role git worktree. The orchestrator never codes — it briefs, dispatches, gates, and merges. Sponsor talks only to the orchestrator. Full topology and conventions in [`.claude/docs/orchestration-overview.md`](.claude/docs/orchestration-overview.md).

Combat runtime: Player swing → Hitbox spawn (encapsulated `_init` deferred-monitoring pattern) → mob `_die` chain → death-tween + parallel SceneTreeTimer safety-net → `_force_queue_free`. Full combat-system topology in [`.claude/docs/combat-architecture.md`](.claude/docs/combat-architecture.md).

HTML5 / WebGL2 has several load-bearing divergences from desktop (HDR clamp, Polygon2D rendering quirks, service-worker cache). Full HTML5-export rules in [`.claude/docs/html5-export.md`](.claude/docs/html5-export.md).

## Tech stack

- **Godot 4.3** — game engine; `project.godot` configures both desktop and HTML5 renderers
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
- **Tightened final-report contract.** Sub-agent reports to orchestrator are TIGHT (≤200 words, PR URL + verdict + blockers + doc-updates line). Detailed content goes in PR body + Self-Test Report. Memory: `tightened-final-report-contract`.

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

## Key references outside `.claude/docs/`

- **Team / process docs:** [`team/`](team/) — TESTING_BAR.md, GIT_PROTOCOL.md, ROLES.md, RESUME.md, STATE.md, DECISIONS.md, plus per-role subdirs (`team/devon-dev/`, `team/uma-ux/`, `team/drew-dev/`, `team/priya-pl/`, `team/tess-qa/`). These are collaboration/process artifacts (testing standards, git conventions, dispatch templates, process-incident logs); the architectural reference is in `.claude/docs/`.
- **Auto-memory** (orchestrator durable preferences across sessions, outside the repo): `~/.claude/projects/c--Trunk-PRIVATE-RandomGame/memory/` — sponsor-decision-delegation, testing-bar, team-roster, git-and-workflow, orchestrator-never-codes, html5-visual-verification-gate, godot-physics-flush-area2d-rule, diagnostic-build-pattern, etc.
- **Session state files:** `~/.claude/projects/c--Trunk-PRIVATE-RandomGame/sessions/` — written by the `save-session` skill at end-of-session, read by the next session's resume command.
- **Process-incident log:** [`team/log/process-incidents.md`](team/log/process-incidents.md) — append-only chronicle of orchestration / engineering incidents with their remediation.
