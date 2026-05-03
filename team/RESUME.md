# Resume Note — second-pause playbook (post-M1-integration)

**Status as of authoring (2026-05-03):** M1 integrated (PR #107 landed `4484196` on 2026-05-03), Sponsor's first interactive soak surfaced 2 P0 blockers + 8 bug-bash findings, mid-fix-forward across multiple agents. **NOT "M1 complete."** This doc is the orchestrator's playbook for resuming the project — read in order, then survey live state via the linked artifacts.

The previous version of this doc claimed "M1 complete + integration-tested" and predates the M1 integration miss, the W3-A7 worktree-isolation rollout, the 5 new orchestrator-memory rules adopted today, and the M1 soak findings. Tess's run-025 doc-drift audit (`team/log/doc-drift-audit-2026-05-03.md`) called it the single biggest drift artifact in the team folder. Rewritten in this PR.

---

## 1 — Current phase + state

- **Phase:** M1 RC sign-off + bug-fix sweep — Sponsor soak ⟷ combat-fix dispatch ⟷ visual-feedback design ⟷ re-soak loop. M2 is drafted (week 1 + week 2 backlogs) but Sponsor-gated.
- **M1 integration:** **landed** in PR #107 (`feat(integration): wire M1 play loop into Main.tscn` at squash `4484196`, 2026-05-03). Before #107, `Main.tscn` was a week-1 boot stub for ~30 PRs of "feature-complete" claims; Devon's PR also surfaced + fixed an inline same-class bug (mob_def not applied in Stratum1Room01 / MultiMobRoom). Tess wrote `tests/integration/test_m1_play_loop.gd` (488 lines, 11 funcs covering AC1-AC10) as the gating contract.
- **M1 soak:** Sponsor began interactive soak on RC `embergrave-html5-4484196` and surfaced **2 P0 blockers** in <10 minutes — combat-not-landing (`86c9m36zh`) was a soak-stopper; combat-invisible (`86c9m37q9`) is fix-forward. Tess then ran a full bug-bash and surfaced 8 more bugs (`team/tess-qa/m1-bugbash-4484196.md`, BB-1..BB-8). Sponsor is paused mid-soak waiting on the next post-fix RC.
- **Combat-fix status:** PR #109 merged at `5a3c945` — defensive-only fix (`Hitbox::_check_initial_overlaps` sweep on spawn). **Root cause UNCONFIRMED** — empirical verification on a tests-only branch showed Godot 4.3 headless DOES fire `body_entered` correctly without the fix. The fix is shipped as a defensive measure; HTML5 reproduction is the next investigation if re-soak still fails. See DECISIONS.md 2026-05-03 entry.
- **Combat visual feedback:** Uma's design merged in PR #111 (`team/uma-ux/combat-visual-feedback.md`) — placeholder-fidelity ember-wedge swing + 80ms hit-flash + 200ms scale-down+fade death tween + ember-burst particles. **Implementation in flight** under Drew + Devon (separate ticket).
- **Save fix (BB-2):** Devon dispatched on the BB-2 save fix in flight (sponsor reported save-state regression in bug-bash).
- **Test inventory:** 587 passing / 1 long-standing pending on the post-fix tip (`5a3c945`). Combat-fix PR #109 brought `tests/integration/test_hitbox_overlapping_at_spawn.gd` — first coverage of the actual Hitbox signal flow.
- **Current `main` tip when this was authored:** `5a3c945` (PR #109 — combat fix). Verify live: `git fetch origin && git log origin/main --oneline -10`.

---

## 2 — Latest M1 RC artifact

- **First integrated build (Sponsor's soak target):** `embergrave-html5-4484196` — the build that surfaced the 2 P0 blockers + 8 bug-bash findings.
- **Pre-integration verified-coverage build (superseded):** `embergrave-html5-591bcc8` — the pre-integration verified-coverage RC referenced in `team/tess-qa/html5-rc-audit-591bcc8.md`. Has the Sponsor probe-target list + 9 HTML5 invariant tests but predates the M1 play-loop wiring. Use the audit doc as a probe-target reference, not as a current Sponsor-soak target.
- **Latest post-fix tip:** whatever `main` is when you read this. M1-residual fixes (PR #109 combat, plus whatever has landed since) accumulate here. **A fresh release build is required before re-soak** — the post-fix tip needs to be cut to HTML5 before Sponsor returns.
- **How to find the latest build:** `gh run list --workflow=release-github.yml --limit 1 --json databaseId,headSha,conclusion,url`. The release workflow drops `embergrave-html5-<sha>.zip` as an artifact.

---

## 3 — Roles in flight (typical)

Each role has a persistent worktree (W3-A7 option A — see `team/orchestrator/dispatch-template.md`). Worktrees are **role-persistent**, not per-dispatch. Dispatched agents check out a fresh branch off `origin/main` inside their worktree, push by refspec, do not delete branches locally (worktree-conflict pattern).

| Role | Worktree | Typical work | Run number (verify in STATE.md) |
|---|---|---|---|
| Priya | `RandomGame-priya-wt` | Backlogs (M2 w1, M2 w2, perf budget), risk register, retros, ROLES/process-incident polish | run-009+ (run-010 = perf budget; this rewrite = run-011) |
| Uma | `RandomGame-uma-wt` | Visual + UX + audio direction, palette docs, copy/microcopy. Most recent: combat visual feedback design (PR #111), audio sourcing pipeline (PR #117) | run-008+ |
| Devon | `RandomGame-devon-wt` | Engine + UI + save + integration. Most recent: PR #107 (M1 integration), PR #109 (combat fix), BB-2 save fix in flight | run-013+ |
| Drew | `RandomGame-drew-wt` | Mobs, levels, content (TRES), stratum-2 scaffolding. Mob visual-feedback impl in flight | run-007+ |
| Tess | shared main checkout (no dedicated wt yet — open W3-A7 follow-up) | Sign-offs, integration tests (Tess writes them), audits, bug-bashes, RC HTML5 audits | run-025+ (run-025 = doc-drift audit) |
| Orchestrator | `RandomGame-orch-wt` | Dispatch + heartbeat + merges + ClickUp sync | continuous |

**STATE.md** at `team/STATE.md` is the live source of truth for per-role status. Read it on resume — sections drift relative to merge state because mergers don't currently update the originating role's section (`team/log/doc-drift-audit-2026-05-03.md` S-03..S-06 systemic finding; defer-fix per audit verdict).

---

## 4 — Memory rules governing orchestrator behavior

The orchestrator's behavior is now governed by 11 memory entries at `C:/Users/538252/.claude/projects/c--Trunk-PRIVATE-RandomGame/memory/MEMORY.md`. **Read the index** (one-liners with links into per-rule docs). Five are load-bearing for orchestrator decision-making:

1. **`orchestrator-never-codes.md`** — orchestrator does not Read/Grep/trace source or edit code. Dispatches agents from symptoms, even when "I could just fix this" is faster. The Stratum1BossRoom one-line fix the orchestrator made personally is the cautionary precedent.
2. **`always-parallel-dispatch.md`** — every tick has 3-5 agents in flight. Tickets are NOT progress; dispatches are. "Half-A done, envelope exhausted" is rarely a real blocker — Half-B-design + anticipatory backlog + cross-role planning are always dispatchable.
3. **`clickup-status-as-hard-gate.md`** — every dispatch / PR-open / merge / bounce pairs with a ClickUp status flip in the **same tool round** as the workflow action. Heartbeat ticks audit the board against reality.
4. **`self-test-report-gate.md`** — UX-visible PRs (`feat(integration|ui|combat|level|audio|progression|gear)`, `fix(ui|combat|level|audio|integration)`, certain `design(spec)`) require an author-posted Self-Test Report comment **before** Tess reviews. Tess bounces immediately if missing — don't burn review budget cold-reading a UX diff.
5. **`product-vs-component-completeness.md`** — "tests pass" ≠ "product ships." A feature is not complete until instantiated in `Main.tscn` and reachable via the player's path. Adopted from the M1 Main.tscn-stub miss.

Plus: `agent-verify-evidence.md` (check actual evidence before refusing or asserting impossibility — Stratum1BossRoom incident), `dispatch-cadence-after-override.md` ("get to work" is session-durable), `testing-bar.md` (Sponsor will not debug — paired tests + green CI + edge probes + Tess sign-off), `sponsor-decision-delegation.md` (orchestrator + PL together hold all team-call authority), `team-roster.md` (Priya/Uma/Devon/Drew/Tess + scope), `git-and-workflow.md` (main is harness-protected, PR-flow + `gh pr merge --admin`), `external-resources.md` (ClickUp IDs, GitHub URLs, paths).

**Don't restate the rules; reference the memory file.** Rules update; this doc shouldn't drift again.

---

## 5 — Dispatch envelope at this resume point

| Bucket | Status | Notes |
|---|---|---|
| Half-A (M1 close-out polish) | Done | CI hardening, integration GUT, HTML5 audit (`html5-rc-audit-591bcc8.md`), worktree-isolation v3 |
| Half-B-design (M2-onset design) | Done | stash UI v1, stratum-2 palette (Cinder Vaults), save-schema-v4 plan, audio direction v1.1, combat visual feedback design, audio sourcing pipeline, S3-S8 indicative palette |
| Half-B-code (W3-B2 stratum-2 chunk scaffold) | Done | `Stratum` namespace + `MultiMobRoom` baseline on `main` |
| M1 integration finish-line (PR #107) | Done | `4484196` — Main.tscn wired |
| M1-residuals in flight | Active | combat-fix root cause (HTML5 repro investigation), combat visual feedback impl (Drew + Devon), BB-2 save fix (Devon), other bug-bash items per `m1-bugbash-4484196.md` |
| M2 week-1 backlog | Drafted (PR #97) | `team/priya-pl/m2-week-1-backlog.md` — 12 tickets, 11 P0 + 1 P1, Sponsor-gated |
| M2 week-2 backlog | Drafted (PR #114) | `team/priya-pl/m2-week-2-backlog.md` — 12 tickets, 8 P0 + 3 P1 + 1 P2, doubly-anticipatory |
| Performance budget spec | In flight (PR #119 from Priya run-010) | `team/priya-pl/performance-budget.md` — FPS / memory / draw calls / latency / artifact size / boot |
| Bug-bash (`86c9kxx7h`) | Reserved | Post-Sponsor-sign-off; will absorb deferred M1 polish |
| M2 implementation (T1-T11) | Sponsor-gated | Held until Sponsor signs off M1 |

**What's safe to dispatch now without Sponsor:** anticipatory planning (M3 design seeds), retros, doc-drift fixes (this PR is one), process-incidents log normalization, Devon performance-budget follow-ups, audio sourcing operations doc. Avoid touching M1 player-facing code surfaces while Sponsor's mid-soak.

---

## 6 — Top 5 active risks

From the refreshed risk register (`team/priya-pl/risk-register.md`, refreshed in PR #112). Read the register on resume — these may have shifted.

1. **R6 — Sponsor-found-bugs flood** (high / **high**) — actively firing; combat-not-landing was a soak-stopper. Forecast underweighted impact. Trigger lowered to ≥1 P0.
2. **R11 — Integration stub shipped as feature-complete** (high / high) — the Main.tscn-stub class of risk just realized. Mitigation new (`product-vs-component-completeness.md`); discipline needs proof across more cycles.
3. **R12 — Orchestrator-bottleneck-on-dispatch** (high / med) — actively firing; user has overridden under-dispatch multiple times today ("continue / get to work / always parallel"). Mitigation: `always-parallel-dispatch.md` + tightened cron prompt.
4. **R1 — Save migration breakage** (med / high) — held; sixth schema bump (v3→v4) lands in M2 week 1. Pattern is robust over five prior bumps but v4 is the first Dictionary-of-Dictionary shape.
5. **R8 — Stash UI complexity (M2)** (high / med-high) — pre-positioned for M2 week 1 (T3); stub-PR-then-interactive-PR split planned per R8 mitigation.

R2 + R4 dropped off top-5 (probability lowered). R3 / R5 / R7 closed. R3-M2 will re-open at M2 dispatch entry (six new HTML5 surfaces).

---

## 7 — Common operations

```bash
# Survey
cd /c/Trunk/PRIVATE/RandomGame-orch-wt
git fetch origin
git log origin/main --oneline -10
gh pr list --state open --json number,title,headRefName

# Latest release artifact
gh run list --workflow=release-github.yml --limit 1 --json databaseId,headSha,conclusion,url

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
# Use mcp__clickup__clickup_update_task to flip status (status field accepts: "to do" / "in progress" / "ready for qa test" / "complete")
# Live MCP preferred; team/log/clickup-pending.md is the queue when MCP is down

# Tess sign-off pattern (harness denies self-approval)
# Tess agents post approval via: gh pr comment <num> --body "Approved per <evidence>."
# Then orchestrator merges per category (Tess merges feat/fix; orchestrator merges chore/docs/design)
```

See `team/GIT_PROTOCOL.md` (currently has 3 P0 drift items per audit — clarification PR pending) and `team/orchestrator/dispatch-template.md` (current canonical dispatch shape) for full protocol.

---

## 8 — What gates M1 sign-off

**Single gate:** Sponsor's interactive 30-min soak on the next post-fix RC.

**Pre-conditions for cutting that next RC:**

1. **Combat-fix verified** — PR #109 merged but root cause UNCONFIRMED. If Sponsor's re-soak still shows combat not landing, the next investigation is HTML5 reproduction (Devon next dispatch — re-test under browser harness, not just headless GUT).
2. **Drew's mob visual feedback impl** lands — Uma's `team/uma-ux/combat-visual-feedback.md` is the spec. Without it, even fixed-and-landing combat looks "dead" (Sponsor's second P0).
3. **Devon's BB-2 save fix** lands — Tess's `m1-bugbash-4484196.md` is the bug catalog.
4. **Other bug-bash items triaged** — the 8-finding bug bash needs a P0/P1 trim. P0s land before re-soak; P1s can defer to post-soak fix-forward.
5. **Fresh release-build cut** — `release-github.yml` triggered against the post-fix tip; artifact downloaded; build sanity-checked (Main.tscn instantiates, player can move + attack + take damage + save + reload).

**Sponsor probe targets** carry forward from `team/tess-qa/html5-rc-audit-591bcc8.md` + `team/tess-qa/m1-bugbash-4484196.md`. Tess's HTML5 audit + bug-bash framework is the right structure; updated probe-targets for the new RC tip should be the next Tess dispatch when the post-fix RC is cut.

---

## 9 — Anti-patterns to avoid (the stuff that bit us this week)

These are codified in `team/log/process-incidents.md`, the risk register's R11/R12, and the orchestrator memory. Listing them inline because they're load-bearing on resume.

1. **Treating "tests pass" as "product ships"** — 587 passing tests + 30+ "feature-complete" claims hid the Main.tscn-stub miss for ~30 PRs. Always verify the entry-point scene file at "feature-complete" claims, not just CI green. (R11 / `product-vs-component-completeness.md`.)
2. **Treating ticket creation as progress** — orchestrator created `86c9m37n9` (Tess bug-bash) and `86c9m37q9` (Uma visual feedback) without same-tick dispatch; user had to override with "continue / get to work / always parallel." Tickets ≠ progress; dispatches = progress. (R12 / `always-parallel-dispatch.md`.)
3. **Soft-blocker "envelope exhausted" log entries when there's always Half-B design / planning work** — heartbeat tick 2026-05-02 22:03 / 22:33 logged "envelope exhausted" while Priya backlog-expansion / Tess acceptance plan / Uma S3-S8 palette were always dispatchable. (R12 / `always-parallel-dispatch.md`.)
4. **Orchestrator coding** (read source, grep, trace) instead of dispatching from symptoms — the Stratum1BossRoom one-line fix the orchestrator made directly bypassed the agent-from-symptom dispatch pattern. Even when "I could just fix this" is faster, the orchestrator is the dispatcher, not the implementer. (`orchestrator-never-codes.md`.)
5. **Skipping ClickUp status moves** — every dispatch/PR-open/merge MUST pair with a same-tool-round status flip. Heartbeat tick audits the board; drift means a future agent reads stale state. (`clickup-status-as-hard-gate.md`.)
6. **Skipping Self-Test Reports on UX-visible PRs** — Tess shouldn't be cold-reading a UI diff. Author posts a Self-Test Report comment before Tess reviews; Tess bounces if missing. (`self-test-report-gate.md`.)
7. **Refusing or asserting impossibility from priors** — fresh Drew agent confidently refused a real bug claiming the premise was fabricated; CI logs proved otherwise. Always check actual evidence (CI logs, file contents, repro output) before refusing. (`agent-verify-evidence.md`.)
8. **`chore(...)` self-merge by author** — `chore(ci|build|repo)` is exempt from Tess sign-off but **not** from orchestrator/Priya merge identity. Devs do not self-merge their own PRs in any category. (Process-incidents 2026-05-02; GIT_PROTOCOL G-01 fix pending.)

---

## 10 — Quick-resume checklist

When picking up the project after a pause, do these in order:

1. **Read live state-of-truth, in order:**
   - `team/STATE.md` (per-role status — note the systemic merger-bump drift; `git log` is more authoritative than role sections for "what merged when")
   - `team/log/heartbeats.md` (recent 5-10 ticks for trajectory)
   - `team/DECISIONS.md` (recent 5-10 entries for what's locked)
   - `team/priya-pl/risk-register.md` (top-5 + watch-list)
   - `C:/Users/538252/.claude/projects/c--Trunk-PRIVATE-RandomGame/memory/MEMORY.md` (the rules)
2. **Survey GitHub:**
   - `git fetch origin && git log origin/main --oneline -10`
   - `gh pr list --state open --json number,title,headRefName`
   - `gh run list --workflow=release-github.yml --limit 1` (current RC artifact)
3. **Check ClickUp board reality vs STATE.md:** `mcp__clickup__clickup_filter_tasks` on list `901523123922`. If MCP is down, drain `team/log/clickup-pending.md` on reconnect.
4. **Decide path** based on Sponsor signal:
   - **Sponsor signed off M1** → dispatch M2 week-1 per `m2-week-1-backlog.md`; bug-bash drains first.
   - **Sponsor bounced with bugs** → Tess triages → file as `bug(...)` ClickUp tasks → Devon/Drew fix-forward → re-soak.
   - **Sponsor still mid-soak / no signal** → 3-5 parallel dispatches in the safe-to-dispatch envelope (anticipatory planning, doc-drift fixes, design specs, M2 prep). Don't load M1 player-facing code while soak is mid-flight.
   - **Sponsor asked a question** → just answer; don't auto-dispatch.
5. **Confirm dispatch envelope on the heartbeat tick** — at least 3 agents in flight, or an explicit narrow-blocker logged (Sponsor-input-required / auto-mode-permission-denied / agent-reports-contract-conflict / user-says-stop). "Nothing to dispatch" is rarely true; default to dispatching Priya for backlog expansion if genuinely empty.

---

## Appendix — useful artifact links

- **Repo:** https://github.com/TSandvaer/RandomGame on `main`. Tip when authored: `5a3c945`. Verify current via `git fetch origin && git rev-parse origin/main`.
- **ClickUp list (M1 backlog):** `901523123922`. Recognized tags: `bug`, `chore`, `week-3`, `design`. New tag categories require Sponsor / Priya space-level addition (per `team/log/clickup-pending.md` 22:30 flush).
- **Recent load-bearing PRs:**
  - PR #107 — `feat(integration): wire M1 play loop into Main.tscn` at `4484196` (M1 finish line)
  - PR #109 — `fix(combat): Hitbox sweeps already-overlapping bodies at spawn` at `5a3c945` (M1 soak blocker — defensive fix; root cause UNCONFIRMED)
  - PR #111 — `design(spec): combat visual feedback` at `d006592`
  - PR #112 — `chore(planning): risk register refresh — M1 soak findings + R6 escalated` at `0f8fcb8`
  - PR #113 — `qa(bugbash): exploratory pass on M1 RC 4484196 — 8 bugs surfaced` at `4e0f27c`
  - PR #114 — `chore(planning): M2 week-2 backlog draft (anticipatory)` at `aa66f88`
  - PR #116 — `chore(planning): doc-drift audit — 22 findings across 8 docs (T-EXP-4)` at `838b71a`
  - PR #117 — `design(audio): M2 audio-sourcing pipeline + first-pass cue allocation` at `14ad141`
  - PR #119 — `design(spec): performance budget` (Priya run-010, in flight when this was authored)
- **Key team docs:**
  - `team/STATE.md` (per-role status)
  - `team/DECISIONS.md` (decision audit trail)
  - `team/GIT_PROTOCOL.md` (workflow rules — has 3 P0 drift items pending fix)
  - `team/ROLES.md` (role + responsibility matrix)
  - `team/TESTING_BAR.md` (Tess sign-off DoD — 2 P0 additions pending: Self-Test Report + product-completeness)
  - `team/orchestrator/dispatch-template.md` (canonical dispatch shape — 2 P0 additions pending: Self-Test block + ClickUp lifecycle block)
  - `team/log/heartbeats.md` (20-min watchdog ticks)
  - `team/log/process-incidents.md` (recurring drift patterns)
  - `team/log/doc-drift-audit-2026-05-03.md` (Tess run-025; this rewrite resolves the RESUME.md P0 from that audit)
  - `team/priya-pl/m2-week-1-backlog.md` + `m2-week-2-backlog.md` + `risk-register.md` + `performance-budget.md` (planning corpus)
  - `team/tess-qa/m1-bugbash-4484196.md` + `html5-rc-audit-591bcc8.md` (M1 soak probe-targets + bug catalog)
- **Orchestrator memory:** `C:/Users/538252/.claude/projects/c--Trunk-PRIVATE-RandomGame/memory/MEMORY.md`. Read the index, then per-rule docs as needed.

---

This doc is rewritten at every major phase boundary or whenever it drifts >1 P0 from current reality. Last rewrite: 2026-05-03 (Priya run-011, post-M1-integration). Previous version (2026-05-02 19:58, "M1 complete + soak-ready") is in git history if needed.
