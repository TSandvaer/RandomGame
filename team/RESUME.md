# Resume Note — M2 W3 dispatching (post-W2-close)

**Status as of authoring (2026-05-15):** M2 Week 2 closed CLEAN, M2 Week 3 dispatching. The W2 RC is the next Sponsor-soak target (still pending Sponsor pickup — first M2 soak hasn't fired yet). AC4 Room 05 is in a **balance-implementation phase** (Uma's #201 design locked; Drew + Devon implement in W3-T1). There are **no live blockers**. `origin/main` tip is `5e471f0` (PR #202 — W2 retro + W3 backlog v1.0). This doc is the orchestrator's playbook for resuming the project; read in order, then survey live state via the linked artifacts.

The previous version (2026-05-05 rewrite, PR #134-era) reflected the **M1 RC post-fix-wave** state — pre-Sponsor M1 sign-off, BB-1/3/4/5 bug-bash fixes just landed. State has moved on dramatically: M1 is signed off, M2 W1 + W2 both closed clean, AC4 boss-clear progression went from `test.fail()` blocker to balance-design-locked. This refresh captures the post-W2-close / W3-dispatching snapshot.

---

## 1 — Current phase + state

- **Phase:** **M2 Week 3 dispatching.** M2 W2 closed CLEAN per Priya's `team/priya-pl/m2-week-2-retro.md` (PR #202). M2 W3 backlog v1.0 is live at `team/priya-pl/m2-week-3-backlog.md` (12 tickets — 8 P0 + 3 P1 + 1 P2). The W3 backlog explicitly absorbs the W2 carry-over queue (stratum-2 content authoring, MobRegistry, v4 stress fixtures, audio sourcing close-out, M3 design seeds) PLUS the AC4 Room 05 balance pass per Uma's #201 design.
- **M2 W2 closed clean:** **22 PRs merged** in the W2 arc (Sept dispatch start post-PR #175 → close-out tip `3d614a6` at PR #200; the close-out itself was PR #202 at `5e471f0`). **Tess's end-of-week bug-bash** (`team/tess-qa/soak-2026-05-15.md`, ticket `86c9kxx7h`) against `embergrave-html5-d9cc159` returned **0 blockers / 0 majors / 2 minors**. Both minors addressed: `86c9u33h1` (Pickup silent-drop on full grid) shipped in PR #199; `86c9u33hh` (stale AC4 `test.fail()` annotation) is folded into W3-T1 (Room 05 balance pass implementation). The team shipped the largest M2 batch to date with no soak-stopper findings.
- **AC4 progression (`86c9qckrd`):** Rooms 01–04 are deterministic post-PR #186 (Room 04 chase helper) / #190 (chase return-to-spawn) / #191 (Room 05 mob-freeze fix via `CONNECT_DEFERRED` on `gate_traversed → next-room load`) / #198 (harness position-steered multi-chaser clear). **Room 05 was found to be a balance issue, not a freeze bug** — PR #200's diagnostic-trace pair (`Player._die` action-side + `Main.apply_death_rule` consequence-side) empirically refuted PR #198's "chasers must be unwinnable" framing. The Player was being killed by the chaser-triangle and respawned in Room 01; the harness reported a freeze because mob deaths raced room transitions. **PR #201 (Uma) locked the balance pass design:** Grunt `damage_base 3→2`, Charger `damage_base 5→4`, new player iframes-on-hit constant `HIT_IFRAMES_SECS = 0.25` (auto-granted inside `Player.take_damage`). The implementation lands in W3-T1 (Drew on TRES, Devon on `Player.gd` iframes, Tess on paired tests + Playwright deterministic clear without the position-steered harness dodge).
- **Inventory bandaid retirement landed:** PR #194 (`chore(inventory): retire PR #146 iron_sword bandaid → auto-equip first weapon on pickup`) — a 23-file coordinated change. Cold-boot is now genuinely fistless; equip happens via gameplay; Room01 onboarding gates room-advance on first-weapon pickup. The retirement surfaced two latent bugs (unreachable dummy-drop pickup; full-grid silent-drop) both fixed in-arc (PR #199). PR #194 is the load-bearing UX change of the M2 arc to date — it ships the "play your way into the loop" experience.
- **Combat-trace coverage closed:** 4 PRs in the W2 arc — #177 (`TutorialEventBus.request_beat`), #182 (Charger/Shooter `_die`), #192 (Charger/Shooter `take_damage`), #195 (Charger/Shooter `take_damage IGNORED already_dead`). Future negative-assertion specs have the diagnostic surface they need; the per-mob death-event trace family is now complete.
- **Physics-flush harmonization:** PR #184 closed the `Stratum1BossRoom._build_door_trigger` harmonization gap called out in `.claude/docs/combat-architecture.md` (ticket `86c9p1fgf`); PR #193 audited `Stratum1Room01` death-reload flush path as safe; PR #197 added per-swing Hitbox monitoring assertion to the sustained-swing-spam regression. PR #191's W2-leveraging fix generalized the physics-flush rule **beyond Area2D** — `CollisionShape2D`-on-`PhysicsBody2D` adds inside `flush_queries()` also panic; the load-bearing pattern is `CONNECT_DEFERRED` on cross-frame signals that bridge flush-rooted callbacks (codified in `.claude/docs/combat-architecture.md` § "Cross-tree signal-connection discipline").
- **Polish / UX:** PR #176 (Uma design — color-blind secondary cue for equipped distinction) + PR #179 (Devon impl — `✓ EQUIPPED` glyph). Devon caught the `gl_compatibility` U+2713 tofu-rendering bug during Self-Test Report and shipped the fix in the same PR (final draws the glyph as `ColorRect` geometry, not a Unicode codepoint). Codified into `.claude/docs/html5-export.md` § "Default-font glyph coverage" — Self-Test Report gate is the load-bearing surface for HTML5-default-font divergences.
- **Auto-memory rules that landed this arc:**
  - **Physics-flush rule generalized** to `CollisionShape2D`-on-`PhysicsBody2D` (PR #191 — combat-architecture.md update).
  - **GUT parse-failed test files now fail CI loudly** (PR #196 — closes a testing-bar integrity hole where GUT's green exit code masked parse errors).
  - **Iron-sword auto-equip-at-boot bandaid retired** (PR #194 — replaced by pickup-driven equip).
  - **Diagnostic-trace pair pattern codified** (PR #200 — action-side + consequence-side traces paired in the same PR; combat-architecture.md update candidate per Priya's retro §"Lessons learned" §3).
  - **Negative-assertion buffer-scoping discipline codified** (PR #180 — `.claude/docs/combat-architecture.md` § "Negative-assertion buffer-scoping rule").
  - **Auto-status SessionStart re-arm hook** (PR #181 — harness durability across session restarts).
- **No live blockers.** All five named roles are idle post-W2-close; safe to dispatch the W3 backlog at full parallel cadence (W3-T2/T3/T5 + Tess T9 acceptance plan are dispatch-ready without further blockers; W3-T1 waits on Uma's #201 design merge, which already landed at `dd4fed2`).
- **Current `main` tip when this was authored:** `5e471f0` (PR #202 — W2 retro + W3 backlog v1.0). Verify live: `git fetch origin && git log origin/main --oneline -10`.

---

## 2 — Latest M2 RC artifact

- **W2 RC (Sponsor-soak target):** `embergrave-html5-d9cc159` from release-build run `25895056935` (https://github.com/TSandvaer/RandomGame/actions/runs/25895056935). This was the artifact cut after PR #194 (the bandaid-retirement coordinated change) landed; it's the current Sponsor-soak target for M2 W3 entry. Sponsor has NOT yet soaked M2 — last Sponsor soak was M1 RC. **The first M2 soak findings are expected to surface in W3** and will feed the W3-T10 fix-forward absorber.
- **Post-W2-close builds:** several release-build runs fired after `d9cc159` (latest at the time of authoring is run `25900025812` on `212ecd3`). These are not the canonical Sponsor-soak target — `d9cc159` is what Tess soaked and signed off. Use them as smoke-check references only.
- **How to find the latest build:** `gh run list --workflow=release-github.yml --limit 5 --json databaseId,headSha,conclusion,url,createdAt`. The release workflow drops `embergrave-html5-<short-sha>.zip` as an artifact.
- **Artifact download URL pattern** (use this in Sponsor handoff per memory `sponsor-soak-artifact-links.md`):
  ```
  https://github.com/TSandvaer/RandomGame/actions/runs/<run_id>/artifacts/<artifact_id>
  ```
  Get the artifact ID via `gh api repos/TSandvaer/RandomGame/actions/runs/<run_id>/artifacts --jq '.artifacts[]|"\(.id) \(.name)"'`.

---

## 3 — Roles in flight (typical)

Each role has a persistent worktree at the same level as the project root. Worktrees are role-persistent, not per-dispatch. Dispatched agents check out a fresh branch off `origin/main` inside their worktree, push by refspec, do not delete branches locally (worktree-conflict pattern).

| Role | Worktree | Typical work | Last run focus |
|---|---|---|---|
| Priya | `RandomGame-priya-wt` | Backlogs, risk register, retros, ROLES/process-incident polish, RESUME refreshes. **W2 deliverables: retro + W3 backlog (PR #202).** | This refresh — RESUME + STATE for 2026-05-15 |
| Uma | `RandomGame-uma-wt` | UX/design specs, palette docs, copy/microcopy, Sponsor-soak checklists. **W2 deliverables: AC4 Room 05 balance design (PR #201), color-blind equipped-distinction design (PR #176).** | W3-T9 audio sourcing close-out + W3-T1 design hand-off |
| Devon | `RandomGame-devon-wt` | Engine + UI + save + integration. **W2 deliverables: equipped-glyph impl (PR #179), Pickup silent-drop fix (PR #199), inventory bandaid retirement (PR #194), focus-consumption equip-flow fix (PR #187).** | W3-T1 (Player iframes-on-hit), W3-T5 (MobRegistry), W3-T9 (audio wiring) |
| Drew | `RandomGame-drew-wt` | Mobs, levels, content (TRES), stratum-2 scaffolding. **W2 deliverables: MultiMobRoom gate-registration fix (PR #183), Room 05 3-concurrent-chaser fix (PR #191), Stratum1BossRoom door-trigger defer (PR #184), diagnostic-trace pair (PR #200).** | W3-T1 (TRES edits), W3-T2/T3 (S2 rooms 2-3 + soft-retint sprites), W3-T4 (S2 boss room first impl — heaviest of M2) |
| Tess | `RandomGame-tess-wt` | Sign-offs, integration tests, audits, bug-bashes, postmortems. **W2 deliverables: end-of-W2 bug-bash (`soak-2026-05-15.md`), harness fixes (PRs #186/#190/#198), per-swing Hitbox regression (PR #197), Playwright artifact-extract fix (PR #178), negative-assertion buffer-scoping (PR #180), CI parse-fail gate (PR #196).** | W3-T6 (v4 save stress fixtures), W3-T9 (acceptance plan + bug-bash), W3-T10 absorber |
| Orchestrator | `RandomGame-orch-wt` | Dispatch + heartbeat + merges + ClickUp sync | continuous |

**All 5 named roles are idle post-W2-close** — nothing in-flight; safe to dispatch the W3 backlog at full parallel cadence (≥3 agents in flight per heartbeat tick).

**STATE.md** at `team/STATE.md` is the live source of truth for per-role status. Read it on resume — note the per-role sections are append-only history; the "Current state — 2026-05-15" header at the top is the canonical "what's going on right now" entry.

---

## 4 — Memory rules governing orchestrator behavior

The orchestrator's behavior is governed by ~25 memory entries at `C:/Users/538252/.claude/projects/c--Trunk-PRIVATE-RandomGame/memory/MEMORY.md`. **Read the index** (one-liners with links into per-rule docs). Six are load-bearing for current orchestrator decision-making:

1. **`orchestrator-never-codes.md`** — orchestrator does not Read/Grep/trace source or edit code. Dispatches agents from symptoms, even when "I could just fix this" is faster.
2. **`always-parallel-dispatch.md`** — every tick has 3-5 agents in flight. Tickets are NOT progress; dispatches are.
3. **`clickup-status-as-hard-gate.md`** — every dispatch / PR-open / merge / bounce pairs with a ClickUp status flip in the **same tool round** as the workflow action.
4. **`self-test-report-gate.md`** — UX-visible PRs require an author-posted Self-Test Report comment **before** Tess reviews. Tess bounces immediately if missing.
5. **`html5-visual-verification-gate.md`** — Tween / modulate / Polygon2D / CPUParticles2D / Area2D-state / glyph-rendering PRs need explicit HTML5 verification before merge. PR #179 is the latest precedent — the `gl_compatibility` U+2713 tofu would have shipped without the gate.
6. **`product-vs-component-completeness.md`** — "tests pass" ≠ "product ships." Verify integration surface (Main.tscn) at every "feature-complete" claim, not just CI green. PR #196's GUT parse-fail gate is the latest precedent — green CI can lie when test files are silently un-executed.

Plus: `godot-physics-flush-area2d-rule.md` (generalized post-#191 to non-Area2D `CollisionShape2D`-on-`PhysicsBody2D` adds; CONNECT_DEFERRED on cross-frame signals is the load-bearing pattern), `agent-verify-evidence.md`, `dispatch-cadence-after-override.md`, `testing-bar.md`, `sponsor-decision-delegation.md`, `team-roster.md`, `git-and-workflow.md`, `external-resources.md`, `cron-noise-during-sponsor-wait.md`, `sponsor-soak-artifact-links.md`, `diagnostic-build-pattern.md`, `multi-dispatch-worktree-conflict.md`, `manual-soak-failure-invest-in-automation.md`, `sub-agent-doc-update-reporting.md`, `sub-agent-context-load-discipline.md`, `auto-status-reporting.md`, `orphaned-agent-recovery-on-restart.md`, `html5-service-worker-cache-trap.md`, `drain-mode-on-session-end.md`.

**Don't restate the rules; reference the memory file.** Rules update; this doc shouldn't drift again.

---

## 5 — Dispatch envelope at this resume point

| Bucket | Status | Notes |
|---|---|---|
| M1 RC + sign-off | Done (historic) | Sponsor signed off M1; team transitioned to M2 W1 |
| M2 Week-1 | Done | Closed clean; 12 tickets shipped |
| M2 Week-2 | **Done (closed CLEAN)** | 22 PRs merged in arc; Tess bug-bash 0 blockers / 0 majors / 2 minors (both addressed). See `m2-week-2-retro.md` (PR #202) |
| M2 Week-3 | **Dispatching** | 12 tickets — 8 P0 + 3 P1 + 1 P2. See `m2-week-3-backlog.md` (PR #202). Drew heaviest (4 tickets — T1 TRES + T2 S2 rooms 2-3 + T3 soft-retint sprites + T4 S2 boss room first impl). Devon on T1 iframes + T5 MobRegistry + T9 audio wiring. Tess on T6 v4 stress + T9 acceptance plan + T10 bug-bash absorber. Uma on T9 audio sourcing + T1 design support. Priya on T12 M3 design seeds + retro. |
| AC4 boss-clear progression | Design-locked → implementation in W3-T1 | Uma's PR #201 locked Grunt 3→2 dmg, Charger 5→4 dmg, Player iframes-on-hit 0.25s. Drew + Devon impl. Tess paired tests + Playwright deterministic clear. |
| Sponsor M2 RC soak | **Pending** | W2 RC `embergrave-html5-d9cc159` is the Sponsor target; first M2 soak hasn't fired yet. W3-T10 absorbs fix-forward findings. |
| M3 design seeds (W3-T12) | Dispatch-ready (P2) | Pure design / scoping work; defer-acceptable. Priya assist. |

**What's safe to dispatch now without Sponsor:** the full W3 P0 + P1 backlog (T1 through T11). T7 (stash UI iteration) + T8 (ember-bag tuning) are Sponsor-conditional and close paper-trivial if no soak feedback fires. T12 (M3 design seeds) is P2-deferrable.

**Dispatch order recommendation:** T2 (Drew, S2 rooms 2-3) + T3 (Drew, soft-retint sprites) + T5 (Devon, MobRegistry) + T6 (Tess, v4 save stress) + T9 (Tess, acceptance plan) all parallel from day 1 — none depend on Uma's design which is already merged (PR #201). T1 (Drew TRES + Devon Player.gd) dispatches as soon as the brief is written. T4 (S2 boss room first impl, L) starts after T2 lands.

---

## 6 — Top 3 active risks

From the W2 retro risk-register update (`m2-week-2-retro.md` §"Risk-register update"). Full register at `team/priya-pl/risk-register.md`.

1. **R6 — Sponsor-found-bugs flood** (high / high — re-promoted) — W2 RC is Sponsor's first M2 soak target. 22 PRs of new surface (AC4 progression, inventory bandaid retirement, combat-trace coverage, polish/UX, harness hardening). Sponsor's first M2 soak findings are certain. Mitigation: W3-T10 Half B absorber + buffer reserved at ~2-3 dev ticks; promotes M→L if Sponsor surfaces ≥3 P0s.
2. **R2 — Tess bottleneck** (med / med — strained but not breaking) — PR #194's 23-file coordinated change required two QA rounds. W3 has heavier sign-off load than W2 (AC4 balance + stratum-2 content + S2 boss room). Mitigation: flag high-blast-radius PRs in dispatch brief; parallel scaffold from day 1; QA capacity reservation up front for #194-class retirements.
3. **R1 — Save migration breakage** (med / high — re-armed) — was inactive in W2 (no save-schema-touching PRs shipped). RE-OPENS in W3 because the v4 stress fixtures (W3-T6) lands AND the AC4 balance pass adds player iframe state (technically not a schema change but migration-adjacent). Mitigation: 8 new stress fixtures land paired tests covering INV-1..INV-8; any TRES additions get a migration note in PR body even if no schema bump.

**Re-promoted to top-5 at W3 entry:** R9 (Stratum-2 content triple-stack — Drew's W3 load is heaviest of M2 with 3 content tickets including L-sized boss room).

**Demoted from top-3:** R11 (Integration-stub-shipped-as-feature-complete) — held; M1 close discipline survived M2 W1 + W2; Main.tscn integration surface is verified per ticket. R8 (Stash UI complexity) — held; no stash UI work shipped in W2 (deferred pending Sponsor signal); re-promotes when W3-T7 carry dispatches.

---

## 7 — Common operations

```bash
# Survey
cd /c/Trunk/PRIVATE/RandomGame-orch-wt
git fetch origin
git log origin/main --oneline -10
gh pr list --state open --json number,title,headRefName

# Latest release artifact
gh run list --workflow=release-github.yml --limit 5 --json databaseId,headSha,conclusion,url,createdAt

# Trigger a fresh release build
gh workflow run release-github.yml --ref main

# CI status of a specific PR / branch
gh pr checks <num>
gh workflow run ci.yml --ref <branch>

# Merge after Tess sign-off (orchestrator merges per merge-identity protocol)
gh pr merge <num> --squash --delete-branch --admin

# Worktree-isolated dispatch
# - Each role has a persistent worktree at C:/Trunk/PRIVATE/RandomGame-<role>-wt
# - Agents check out a fresh branch off origin/main inside their worktree
# - Push by refspec: git push origin HEAD:<branch>
# - Do not delete local branches (worktree-conflict pattern)

# ClickUp audit sweep
# Use mcp__clickup__clickup_filter_tasks (list 901523123922) to compare board state vs reality
# Use mcp__clickup__clickup_update_task to flip status

# Tess sign-off pattern (harness denies self-approval)
# Tess agents post approval via: gh pr comment <num> --body "Approved per <evidence>."
# Then orchestrator merges per category
```

See `team/GIT_PROTOCOL.md` and `team/orchestrator/dispatch-template.md` for full protocol.

---

## 8 — What gates M2 sign-off

**Single gate:** Sponsor's interactive M2 RC soak. The W2 RC (`embergrave-html5-d9cc159`) is the current Sponsor target. Sponsor has not yet soaked M2 — last soak was M1 RC.

**Pre-conditions for cutting the M2 RC (status at this resume point):**

1. ✅ **M2 W1 closed clean** — historic.
2. ✅ **M2 W2 closed clean** — verified by `m2-week-2-retro.md` (PR #202) + Tess soak `soak-2026-05-15.md` (0 blockers / 0 majors / 2 minors both addressed).
3. ⏳ **M2 W3 close clean** — in flight; W3-T9 acceptance plan + W3-T10 bug-bash absorb fix-forward.
4. ⏳ **AC4 balance pass shipped + Playwright deterministic clear** — W3-T1 implementation (Uma's #201 design merged at `dd4fed2`).
5. ⏳ **Stratum-2 content authored** — W3-T2 (rooms 2-3) + W3-T3 (sprites) + W3-T4 (boss room first impl).
6. ⏳ **MobRegistry refactor** — W3-T5; verify whether M2 W1's Stoker PR folded it; if so, retire ticket.
7. ⏳ **v4 save stress fixtures** — W3-T6.
8. ⏳ **M2 audio sourcing close-out** — W3-T9.
9. ⏳ **Sponsor's interactive M2 RC soak** — pending; W3-T10 absorbs fix-forward findings.

**Sponsor probe targets** carry forward from `team/uma-ux/sponsor-soak-checklist-v2.md`. Updated probe-targets for the M2 RC should be the next Tess dispatch when the M2 RC is cut.

---

## 9 — Anti-patterns to avoid (the stuff that bit us recently)

These are codified in `team/log/process-incidents.md`, the risk register's R6/R2, and the orchestrator memory. Listing them inline because they're load-bearing on resume.

1. **Forensic framing without empirical refutation** (PR #198 vs #200) — PR #198 framed Room 05's chaser-mob-freeze as a harness shortcoming and shipped a position-steered sweep. The symptom partially persisted; the actual root cause was a physics-flush race fixed in PR #191. **Generalization:** when a fix lands and the symptom partially persists, the framing is suspect. Use the diagnostic-trace pair pattern (action-side + consequence-side traces paired in the same PR) to make cause-effect chains observable.
2. **Bandaid retirement without high-blast-radius framing** — PR #194's 23-file coordinated change exposed two latent bugs the bandaid had been masking (unreachable dummy-drop; full-grid silent-drop). Bandaid-retirement PRs should be flagged "high-blast-radius" in the dispatch brief so QA capacity is reserved up front.
3. **Trusting CI green without trusting the gate's *reasons*** — GUT exits 0 on parse-failed test files. PR #194 first ran "green" with a test silently un-executed. Fixed by PR #196's CI parse-fail gate. Generalization: trust the gate's *reasons*, not just its *result*.
4. **Treating "tests pass" as "product ships"** — the M1 LevelAssembler regression precedent + the PR #194 parse-fail miss are siblings. Always verify the entry-point scene file + integration surface at "feature-complete" claims, not just CI green.
5. **Treating ticket creation as progress** — Tickets ≠ progress; dispatches = progress. (R12 / `always-parallel-dispatch.md`.)
6. **Orchestrator coding** instead of dispatching from symptoms. Even when "I could just fix this" is faster, the orchestrator is the dispatcher, not the implementer. (`orchestrator-never-codes.md`.)
7. **Skipping ClickUp status moves** — every dispatch/PR-open/merge MUST pair with a same-tool-round status flip. (`clickup-status-as-hard-gate.md`.)
8. **Skipping Self-Test Reports on UX-visible PRs** — Tess shouldn't be cold-reading a UI diff. Author posts a Self-Test Report comment before Tess reviews; Tess bounces if missing. PR #179's `✓ EQUIPPED` glyph caught the U+2713 HTML5 tofu bug DURING Self-Test, before Tess. (`self-test-report-gate.md`.)
9. **Skipping the HTML5 visual-verification gate** for Tween / modulate / Polygon2D / CPUParticles2D / Area2D-state / glyph PRs — primitives-safety analysis is insufficient. Screenshot/video evidence is the load-bearing surface. (`html5-visual-verification-gate.md`.)
10. **Refusing or asserting impossibility from priors** — check actual evidence (CI logs, file contents, repro output) before refusing. (`agent-verify-evidence.md`.)
11. **Driving focus-consuming UI through keyboard simulation alone** — Godot UI focus consumption is broader than `Tab`; `Escape`/`ui_cancel` is also swallowed. Use test-only direct-toggle hooks (e.g. `Inventory.close_for_test()` per PR #187).

---

## 10 — Quick-resume checklist

When picking up the project after a pause, do these in order:

1. **Read live state-of-truth, in order:**
   - `team/STATE.md` (the "Current state — 2026-05-15" header at top; per-role sections below are append-only history)
   - `team/priya-pl/m2-week-2-retro.md` (W2 close-out; pattern catalog + lessons)
   - `team/priya-pl/m2-week-3-backlog.md` (live W3 dispatch corpus — 12 tickets)
   - `team/uma-ux/ac4-room05-balance-design.md` (Uma's #201 design — the balance levers Drew + Devon implement in W3-T1)
   - `team/tess-qa/soak-2026-05-15.md` (Tess's end-of-W2 bug-bash report)
   - `team/log/heartbeats.md` (recent 5-10 ticks for trajectory)
   - `team/DECISIONS.md` (recent 5-10 entries for what's locked)
   - `team/priya-pl/risk-register.md` (top-5 + watch-list)
   - `team/log/process-incidents.md`
   - `C:/Users/538252/.claude/projects/c--Trunk-PRIVATE-RandomGame/memory/MEMORY.md` (the rules)
2. **Survey GitHub:**
   - `git fetch origin && git log origin/main --oneline -10` (verify tip; expect `5e471f0` or newer)
   - `gh pr list --state open --json number,title,headRefName`
   - `gh run list --workflow=release-github.yml --limit 5` (latest release-build; W2 RC `d9cc159` is the canonical Sponsor target)
3. **Check ClickUp board reality vs STATE.md:** `mcp__clickup__clickup_filter_tasks` on list `901523123922`. If MCP is down, drain `team/log/clickup-pending.md` on reconnect.
4. **Decide path** based on signal:
   - **Sponsor has soaked M2** → triage findings → file as `bug(...)` ClickUp tasks → W3-T10 fix-forward absorber. If ≥3 P0s, W3-T10 promotes from M to L per R6 trigger threshold.
   - **Sponsor still pre-soak / no signal** → dispatch the W3 backlog at full parallel cadence. T2 + T3 + T5 + T6 + T9 are all dispatch-ready day 1. T1 dispatches as soon as the brief is written (Uma's design is merged). T4 (S2 boss room L) starts after T2 lands.
   - **Sponsor asked a question** → just answer; don't auto-dispatch.
5. **Confirm dispatch envelope on the heartbeat tick** — at least 3 agents in flight, or an explicit narrow-blocker logged. "Nothing to dispatch" is rarely true at W3 entry — 12 tickets are live.

---

## Appendix — useful artifact links

- **Repo:** https://github.com/TSandvaer/RandomGame on `main`. Tip when authored: `5e471f0` (PR #202 — W2 retro + W3 backlog v1.0). Verify current via `git fetch origin && git rev-parse origin/main`.
- **ClickUp list:** `901523123922`. Recognized tags: `bug`, `chore`, `week-3`, `design`, `qa`, plus per-milestone tags.
- **W2 close-out PRs (the load-bearing arc):**
  - PR #176 — `design(ux): color-blind secondary cue for equipped distinction` (Uma)
  - PR #177 — `infra(combat-trace): TutorialEventBus.request_beat trace line`
  - PR #178 — `bug(ci): playwright-e2e.yml artifact extract — handle both zip + pre-unzipped formats`
  - PR #179 — `feat(ui): color-blind secondary cue — ✓ EQUIPPED glyph` (Devon — caught U+2713 HTML5 tofu in Self-Test)
  - PR #180 — `bug(e2e): negative-assertion-sweep Test 2 — scope RoomGate check to Room01 window`
  - PR #181 — `chore(harness): durable auto-status — SessionStart re-arm hook`
  - PR #182 — `infra(combat-trace): Charger._die + Shooter._die trace lines`
  - PR #183 — `fix(level): MultiMobRoom gate-registration` (Drew — load-bearing first-room blocker)
  - PR #184 — `fix(level): Stratum1BossRoom door-trigger — defer Area2D insert out of physics-flush window`
  - PR #185 — `qa(e2e): AC4 spec re-arm — re-point test.fail() blocker comment post-#183`
  - PR #186 — `fix(harness): clearRoomMobs Shooter-aware chase-then-return sub-helper`
  - PR #187 — `fix(harness): equip-flow Phase 2.5 swing-after-Tab race`
  - PR #188 — `chore(repo): gitignore hygiene — diag-build/ + untrack committed-then-ignored test artifacts`
  - PR #190 — `fix(harness): chaseAndClearKitingMobs return-to-spawn — Room 04 determinism`
  - PR #191 — `fix(level): Room 05 3-concurrent-chaser mob-freeze — CONNECT_DEFERRED on gate_traversed defers next-room load out of physics-flush window` (highest-leverage physics-flush fix of W2)
  - PR #192 — `infra(combat-trace): Charger.take_damage + Shooter.take_damage trace lines`
  - PR #193 — `docs(level): Stratum1Room01 death-reload flush path — audited safe`
  - PR #194 — `chore(inventory): retire PR #146 iron_sword bandaid — auto-equip first weapon on pickup` (23-file coordinated change; the largest behavioural change in W2)
  - PR #195 — `infra(combat-trace): Charger/Shooter take_damage IGNORED already_dead trace`
  - PR #196 — `fix(ci): fail GUT job on parse-failed test files` (testing-bar integrity hole closure)
  - PR #197 — `qa(test): per-swing Hitbox monitoring assertion in sustained-swing-spam test`
  - PR #198 — `fix(harness): clearRoomMobs position-steered multi-chaser clear — Room 05+ deterministic`
  - PR #199 — `fix(inventory): Pickup no silent-drop when grid is full — wait for add() success before queue_free`
  - PR #200 — `fix(diag): Player._die + Main.apply_death_rule combat-trace lines` (diagnostic-trace pair pattern that empirically refuted #198's framing)
  - PR #201 — `design(combat): AC4 Room 05 balance proposal — chaser lethality + iron-sword feel` (Uma — the balance design W3-T1 implements)
  - PR #202 — `pm(m2): week-2 close + week-3 backlog v1.0` (Priya — the retro + W3 dispatch corpus)
- **Key team docs:**
  - `team/STATE.md` (per-role status with "Current state — 2026-05-15" header at top)
  - `team/DECISIONS.md` (decision audit trail)
  - `team/GIT_PROTOCOL.md` (workflow rules)
  - `team/ROLES.md` (role + responsibility matrix)
  - `team/TESTING_BAR.md` (Tess sign-off DoD)
  - `team/orchestrator/dispatch-template.md` (canonical dispatch shape)
  - `team/log/heartbeats.md` (20-min watchdog ticks)
  - `team/log/process-incidents.md` (recurring drift patterns)
  - `team/priya-pl/m2-week-2-retro.md` (W2 close-out — pattern catalog + lessons + risk-register update)
  - `team/priya-pl/m2-week-3-backlog.md` (W3 dispatch corpus — 12 tickets)
  - `team/priya-pl/risk-register.md` (top-5 + watch-list)
  - `team/uma-ux/ac4-room05-balance-design.md` (Uma's #201 design — W3-T1 implementation source-of-truth)
  - `team/tess-qa/soak-2026-05-15.md` (Tess's end-of-W2 bug-bash report)
  - `team/uma-ux/sponsor-soak-checklist-v2.md` (soak playbook — feeds Sponsor's first M2 soak)
- **Architecture briefs (auto-loaded at SessionStart for the main session; sub-agents must Read manually):**
  - `.claude/docs/combat-architecture.md` — Player swing flow, Hitbox/Projectile encapsulated-monitoring, mob `_die` death pipeline, physics-flush rule (generalized post-#191 to non-Area2D), CharacterBody2D motion_mode rule, equipped-weapon dual-surface rule, save autoload signal contract, ContentRegistry.items_resolved, body_entered single-event continuous-walk, negative-assertion buffer-scoping
  - `.claude/docs/html5-export.md` — `gl_compatibility` renderer divergences, HDR clamp, Polygon2D quirks, default-font glyph coverage, service-worker cache trap, BuildInfo SHA verification, visual-verification gate, release-build + artifact handoff, diagnostic-build pattern, Sponsor soak ritual
  - `.claude/docs/orchestration-overview.md` — topology, named-agent roster, worktree layout, dispatch conventions, hard gates, cron rules, sub-agent doc-reading pointer
- **Orchestrator memory:** `C:/Users/538252/.claude/projects/c--Trunk-PRIVATE-RandomGame/memory/MEMORY.md`. Read the index, then per-rule docs as needed.

---

This doc is rewritten at every major phase boundary or whenever it drifts >1 P0 from current reality. **Last rewrite: 2026-05-15** (Priya — RESUME + STATE refresh against post-W2-close / W3-dispatching reality, against `origin/main` tip `5e471f0` / PR #202). Previous version (2026-05-05, M1 RC post-fix-wave) is in git history if needed.
