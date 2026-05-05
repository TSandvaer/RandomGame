# Resume Note — second-pause playbook (post-fix-wave)

**Status as of authoring (2026-05-05):** M1 still gated on Sponsor's interactive sign-off soak, but the BB-1/3/4/5 fix-forward wave from Tess's run-024 bug-bash has fully landed on `origin/main` (tip `a67474d`), Drew's BB-3 work also closed a load-bearing **LevelAssembler regression** (authored chunk geometry was being silently dropped by the assembler — green CI did not catch it), and Uma's `sponsor-soak-checklist-v2` is ready for the post-wave re-soak. The release-build workflow has NOT yet been triggered for the post-wave RC; the next build (TBD, on `a67474d` or later) will supersede the prior soak target. **NOT "M1 complete."** This doc is the orchestrator's playbook for resuming the project — read in order, then survey live state via the linked artifacts.

The previous version (2026-05-03 rewrite, `4104f96` PR #123) reflected the immediately-post-integration state — combat-fix shipped but root-cause-unconfirmed, BB items open, soak-checklist v1 in flight. State has moved on. This refresh captures the post-fix-wave snapshot for the next session.

---

## 1 — Current phase + state

- **Phase:** M1 RC sign-off + post-bug-bash fix-forward — Sponsor re-soak ⟷ release-build cut ⟷ M2 design+spec readiness loop. M2 backlogs (week 1 + week 2) drafted but Sponsor-gated.
- **Bug-bash wave landed:** Tess's run-024 `m1-bugbash-4484196.md` surfaced 8 bugs against the M1 RC. Four are now fixed-forward on `main`: **BB-1** (PR #125 — `build_info.txt` actually shipped inside the HTML5 export bundle + CI regression-gate), **BB-3** (PR #129 — room boundary collision walls + LevelAssembler regression-fix; Drew also caught Tess's CI-red test-bug and fixed-forward in the same PR), **BB-4** (PR #130 — P-key reopens `StatAllocationPanel` after close), **BB-5** (PR #128 — boot banner now lists all 7 input bindings including LMB/RMB). BB-2 (save-fix) landed earlier in PR #118 (`92f7a19`). Remaining BB items (BB-6, BB-7, BB-8) await triage post-Sponsor re-soak.
- **LevelAssembler regression (load-bearing, R11 evidence):** Drew's BB-3 root-cause investigation found that `LevelChunkDef.scene_path` was authored on every `s1_roomNN.tres` but `LevelAssembler.assemble_single` never loaded it — so the chunk's authored floor + walls existed in the .tscn but never reached the running scene tree. This is a pure **product-vs-component completeness** miss: the test suite was green, the chunk-load code path didn't exist, and the runtime quietly dropped authored content. Boss arena was potentially shipping empty. PR #129 closes both the surface symptom (room walls) and the underlying loader gap; new paired tests cover the chunk-load path at runtime.
- **Combat visibility shipped:** PR #115 (mob-side hit-flash + death tween + boss particles, `ad38e04`) and PR #122 (player-side swing wedge + ember-flash, `7b80429`) merged earlier in the session. Sponsor will now perceive hits clearly. **Combat-fix root cause is STILL UNCONFIRMED** — PR #109 (`5a3c945`) was a defensive-only fix; the empirical investigation showed Godot 4.3 headless DOES fire `body_entered` correctly. If unlanded-hits regression returns under HTML5, the next investigation is browser-harness reproduction.
- **Soak-checklist v2 ready:** Uma PR #132 (`a67474d`) — `team/uma-ux/sponsor-soak-checklist-v2.md` is the post-wave re-soak playbook, co-existing with v1 (not replacing). v2 §0 captures wave-LOCAL deltas (BB-1 footer-SHA positive screen, BB-3 walls + LevelAssembler regression-watch, BB-5 7-line banner positive confirmation, BB-4 P-key handler) while v1's wave-DURABLE shape (§1..§9) inherits.
- **Process incidents normalized:** Priya PR #131 added 5 new entries to `team/log/process-incidents.md` covering the W3-A7 4-occurrence shared-HEAD pattern, N7 affix-count drift, `clickup-pending.md` parallel-edit conflict, PR-body test-count drift, and harness-identity self-approval cross-run pattern.
- **Doc-drift bundle landed:** Priya PR #127 (`fdff8c0`) tightened `GIT_PROTOCOL.md` exemption wording, added the ClickUp lifecycle hard-gate section, added the Self-Test Report (UX-visible PRs) section to `GIT_PROTOCOL.md` + `dispatch-template.md` + `TESTING_BAR.md`, and added the "product completeness ≠ component completeness" section to `TESTING_BAR.md`.
- **Charger flake postmortem:** Tess PR #133 (`c0c604e`) — `team/log/charger-flake-postmortem.md` captures the wall-stop-epsilon race root-cause + remediation as a reusable lesson (test-passes-with-overridden-speed-but-fails-on-default class).
- **Current `main` tip when this was authored:** `0e77a92` (PR #134 — Tess run-031 STATE; `a67474d` + state-bump only). Verify live: `git fetch origin && git log origin/main --oneline -10`.

---

## 2 — Latest M1 RC artifact

- **Prior soak target (now superseded):** `embergrave-html5-7b80429` from release-build run `25288018826`. This was the artifact cut after the player-visible-feedback PR #122 landed; it was the soak target before the BB-1/3/4/5 fix-forward wave landed.
- **Pre-integration verified-coverage build (older):** `embergrave-html5-591bcc8` — pre-integration RC referenced in `team/tess-qa/html5-rc-audit-591bcc8.md`. Use the audit doc as a probe-target reference, not as a current Sponsor-soak target.
- **Next post-wave RC (in flight):** Triggered against `0e77a92` (post-wave tip — Tess's PR #134 STATE bump landed before the trigger fired). Release-build run `25393528075` (https://github.com/TSandvaer/RandomGame/actions/runs/25393528075), in-flight at this rewrite (~2-3 min typical build time). Expected artifact `embergrave-html5-0e77a92` (or near-tip if `main` moves before workflow completes). New Sponsor-soak ticket `86c9nbu2u` (status `to do`, awaiting Sponsor pickup). This supersedes the prior `7b80429` build (run `25288018826`) as the Sponsor target.
- **How to find the latest build:** `gh run list --workflow=release-github.yml --limit 1 --json databaseId,headSha,conclusion,url`. The release workflow drops `embergrave-html5-<sha>.zip` as an artifact.

---

## 3 — Roles in flight (typical)

Each role has a persistent worktree (W3-A7 option A — see `team/orchestrator/dispatch-template.md`). Worktrees are **role-persistent**, not per-dispatch. Dispatched agents check out a fresh branch off `origin/main` inside their worktree, push by refspec, do not delete branches locally (worktree-conflict pattern).

| Role | Worktree | Typical work | Last run (verify in STATE.md) |
|---|---|---|---|
| Priya | `RandomGame-priya-wt` | Backlogs (M2 w1, M2 w2, perf budget), risk register, retros, ROLES/process-incident polish, RESUME refreshes | run-013 going to run-014 (this rewrite) |
| Uma | `RandomGame-uma-wt` | Visual + UX + audio direction, palette docs, copy/microcopy, Sponsor-soak checklists. Most recent: BB-5 boot banner (PR #128), soak-checklist v2 (PR #132) | run-012 |
| Devon | `RandomGame-devon-wt` | Engine + UI + save + integration. Most recent: BB-1 build_info export (PR #125), BB-4 stat-panel reopen (PR #130) | run-018 |
| Drew | `RandomGame-drew-wt` | Mobs, levels, content (TRES), stratum-2 scaffolding. Most recent: BB-3 walls + LevelAssembler regression-fix (PR #129) | run-010 |
| Tess | `RandomGame-tess-wt` | Sign-offs, integration tests (Tess writes them), audits, bug-bashes, RC HTML5 audits, postmortems. Most recent: run-028 bug-board audit (PR #126), charger flake postmortem (PR #133), run-031 post-wave state landing (PR #134) | run-031 |
| Orchestrator | `RandomGame-orch-wt` | Dispatch + heartbeat + merges + ClickUp sync | continuous |

**All 5 named roles are idle post-wave** — nothing in-flight; safe to re-dispatch on next session entry.

**STATE.md** at `team/STATE.md` is the live source of truth for per-role status. Read it on resume — sections drift relative to merge state because mergers don't currently update the originating role's section (`team/log/doc-drift-audit-2026-05-03.md` S-03..S-06 systemic finding; defer-fix per audit verdict).

---

## 4 — Memory rules governing orchestrator behavior

The orchestrator's behavior is governed by 11 memory entries at `C:/Users/538252/.claude/projects/c--Trunk-PRIVATE-RandomGame/memory/MEMORY.md`. **Read the index** (one-liners with links into per-rule docs). Five are load-bearing for orchestrator decision-making:

1. **`orchestrator-never-codes.md`** — orchestrator does not Read/Grep/trace source or edit code. Dispatches agents from symptoms, even when "I could just fix this" is faster. The Stratum1BossRoom one-line fix the orchestrator made personally is the cautionary precedent.
2. **`always-parallel-dispatch.md`** — every tick has 3-5 agents in flight. Tickets are NOT progress; dispatches are. "Half-A done, envelope exhausted" is rarely a real blocker — Half-B-design + anticipatory backlog + cross-role planning are always dispatchable.
3. **`clickup-status-as-hard-gate.md`** — every dispatch / PR-open / merge / bounce pairs with a ClickUp status flip in the **same tool round** as the workflow action. Heartbeat ticks audit the board against reality.
4. **`self-test-report-gate.md`** — UX-visible PRs (`feat(integration|ui|combat|level|audio|progression|gear)`, `fix(ui|combat|level|audio|integration)`, certain `design(spec)`) require an author-posted Self-Test Report comment **before** Tess reviews. Tess bounces immediately if missing — don't burn review budget cold-reading a UX diff.
5. **`product-vs-component-completeness.md`** — "tests pass" ≠ "product ships." A feature is not complete until instantiated in `Main.tscn` and reachable via the player's path. **Just realized again** in BB-3: LevelAssembler never loaded `chunk_def.scene_path`, so authored room geometry never reached runtime despite green CI. Verify integration surface, not just tests.

Plus: `agent-verify-evidence.md` (check actual evidence before refusing or asserting impossibility — Stratum1BossRoom incident), `dispatch-cadence-after-override.md` ("get to work" is session-durable), `testing-bar.md` (Sponsor will not debug — paired tests + green CI + edge probes + Tess sign-off), `sponsor-decision-delegation.md` (orchestrator + PL together hold all team-call authority), `team-roster.md` (Priya/Uma/Devon/Drew/Tess + scope), `git-and-workflow.md` (main is harness-protected, PR-flow + `gh pr merge --admin`), `external-resources.md` (ClickUp IDs, GitHub URLs, paths).

**Don't restate the rules; reference the memory file.** Rules update; this doc shouldn't drift again.

---

## 5 — Dispatch envelope at this resume point

| Bucket | Status | Notes |
|---|---|---|
| Half-A (M1 close-out polish) | Done | CI hardening, integration GUT, HTML5 audit, worktree-isolation v3 |
| Half-B-design (M2-onset design) | Done | stash UI v1, stratum-2 palette (Cinder Vaults), save-schema-v4 plan, audio direction v1.1, combat visual feedback design, audio sourcing pipeline, S3-S8 indicative palette, performance budget |
| Half-B-code (W3-B2 stratum-2 chunk scaffold) | Done | `Stratum` namespace + `MultiMobRoom` baseline on `main` |
| M1 integration finish-line (PR #107) | Done | `4484196` — Main.tscn wired |
| M1 fix-forward wave (BB-1/3/4/5 + combat visibility) | **Done** | PRs #115, #122, #125, #128, #129, #130. Soak-checklist v2 (#132) ready for re-soak |
| M2 week-1 backlog | Drafted (PR #97) | `team/priya-pl/m2-week-1-backlog.md` — 12 tickets, 11 P0 + 1 P1, Sponsor-gated |
| M2 week-2 backlog | Drafted (PR #114) | `team/priya-pl/m2-week-2-backlog.md` — 12 tickets, 8 P0 + 3 P1 + 1 P2, doubly-anticipatory |
| Performance budget spec | Done (PR #119) | `team/priya-pl/performance-budget.md` |
| Bug-bash (`86c9kxx7h`) | **Reserved** | Post-Sponsor-sign-off; will absorb deferred M1 polish + remaining BB-6/7/8 |
| M2 implementation (T1-T11) | Sponsor-gated | Held until Sponsor signs off M1 |
| Post-wave release-build cut | **In flight** | Run `25393528075` against `0e77a92`; awaiting green conclusion |

**What's safe to dispatch now without Sponsor:** anticipatory planning (M3 design seeds), retros, doc-drift fixes, audio sourcing operations doc follow-ups, M2 week-1 retro skeleton, RESUME refreshes (this PR is one). Avoid touching M1 player-facing code surfaces while Sponsor's mid-soak.

---

## 6 — Top 5 active risks

From the refreshed risk register (`team/priya-pl/risk-register.md`, last refreshed PR #112). Read the register on resume — these may have shifted; the BB-3 LevelAssembler regression is **strong R11 evidence to re-cite at the next refresh**.

1. **R11 — Integration-stub / silently-dropped-authored-content shipped as feature-complete** (high / high) — **just realized again** in BB-3. Authored `chunk_def.scene_path` was orphaned because `LevelAssembler.assemble_single` never loaded it; full test suite was green; runtime silently dropped the authored geometry. Boss arena was potentially shipping empty. Same risk class as the M1 Main.tscn-stub miss. Mitigation (`product-vs-component-completeness.md`) needs another evidence row + the BB-3 PR's runtime-load test as a discipline pattern.
2. **R6 — Sponsor-found-bugs flood** (high / high) — actively firing across the bug-bash wave; combat-not-landing was a soak-stopper. Fix-forward wave landed; whether re-soak surfaces a new flood is the next data point.
3. **R12 — Orchestrator-bottleneck-on-dispatch** (high / med) — has fired multiple times under user override ("continue / get to work / always parallel"). Mitigation: `always-parallel-dispatch.md` + tightened cron prompt + `dispatch-cadence-after-override.md`.
4. **R1 — Save migration breakage** (med / high) — held; sixth schema bump (v3→v4) lands in M2 week 1. Pattern is robust over five prior bumps but v4 is the first Dictionary-of-Dictionary shape.
5. **R8 — Stash UI complexity (M2)** (high / med-high) — pre-positioned for M2 week 1 (T3); stub-PR-then-interactive-PR split planned per R8 mitigation.

R2 + R4 stay off top-5 (probability lowered). R3 / R5 / R7 closed. R3-M2 will re-open at M2 dispatch entry (six new HTML5 surfaces).

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

# Trigger a fresh release build for re-soak (pending action post-wave)
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
# Use mcp__clickup__clickup_update_task to flip status (status field accepts: "to do" / "in progress" / "ready for qa test" / "complete")
# Live MCP preferred; team/log/clickup-pending.md is the queue when MCP is down

# Tess sign-off pattern (harness denies self-approval)
# Tess agents post approval via: gh pr comment <num> --body "Approved per <evidence>."
# Then orchestrator merges per category (Tess merges feat/fix; orchestrator merges chore/docs/design)
```

See `team/GIT_PROTOCOL.md` (refreshed in PR #127) and `team/orchestrator/dispatch-template.md` (Self-Test + ClickUp-lifecycle blocks landed in PR #127) for full protocol.

---

## 8 — What gates M1 sign-off

**Single gate:** Sponsor's interactive 30-min soak on the next post-wave RC.

**Pre-conditions for cutting that next RC:**

1. **BB-1 / BB-3 / BB-4 / BB-5 fixes ✓** — PRs #125, #129, #130, #128 all merged. BB-2 ✓ (PR #118 earlier).
2. **Combat visibility ✓** — PRs #115 (mob-side) + #122 (player-side) merged. Sponsor will perceive hits clearly even if the unlanded-hits regression returns; combat-fix root cause STILL UNCONFIRMED but the visibility layer makes any return diagnosable rather than soak-stopping.
3. **Soak-checklist v2 ✓** — PR #132 merged (`team/uma-ux/sponsor-soak-checklist-v2.md`).
4. **Fresh release-build cut ⏳ in flight** — `release-github.yml` run `25393528075` triggered by Tess against `0e77a92` (post-wave tip + state-bump); awaiting green conclusion + artifact download + build sanity-check (Main.tscn instantiates, footer SHA matches stamped CI SHA per BB-1 regression gate, player can move + attack + take damage + save + reload).
5. **Sponsor's interactive 30-min soak ⏳ pending** — soak ticket `86c9nbu2u` (status `to do`); execute soak-checklist-v2 §1 setup + §5 per-AC probes against the new RC; structured output per §7 template.

**Sponsor probe targets** carry forward from `team/tess-qa/html5-rc-audit-591bcc8.md` + `team/tess-qa/m1-bugbash-4484196.md` + `team/uma-ux/sponsor-soak-checklist-v2.md` §0 wave-deltas. Updated probe-targets for the new RC tip should be the next Tess dispatch when the post-wave RC is cut.

---

## 9 — Anti-patterns to avoid (the stuff that bit us this week)

These are codified in `team/log/process-incidents.md`, the risk register's R11/R12, and the orchestrator memory. Listing them inline because they're load-bearing on resume.

1. **Treating "tests pass" as "product ships"** — 587 passing tests + 30+ "feature-complete" claims hid the Main.tscn-stub miss for ~30 PRs. **Just realized again** in BB-3: LevelAssembler dropped authored chunk geometry while the test suite was green. Always verify the entry-point scene file + integration surface at "feature-complete" claims, not just CI green. (R11 / `product-vs-component-completeness.md`.)
2. **Treating ticket creation as progress** — orchestrator created `86c9m37n9` (Tess bug-bash) and `86c9m37q9` (Uma visual feedback) without same-tick dispatch; user had to override with "continue / get to work / always parallel." Tickets ≠ progress; dispatches = progress. (R12 / `always-parallel-dispatch.md`.)
3. **Soft-blocker "envelope exhausted" log entries when there's always Half-B design / planning work** — heartbeat tick 2026-05-02 22:03 / 22:33 logged "envelope exhausted" while Priya backlog-expansion / Tess acceptance plan / Uma S3-S8 palette were always dispatchable. (R12 / `always-parallel-dispatch.md`.)
4. **Orchestrator coding** (read source, grep, trace) instead of dispatching from symptoms — the Stratum1BossRoom one-line fix the orchestrator made directly bypassed the agent-from-symptom dispatch pattern. Even when "I could just fix this" is faster, the orchestrator is the dispatcher, not the implementer. (`orchestrator-never-codes.md`.)
5. **Skipping ClickUp status moves** — every dispatch/PR-open/merge MUST pair with a same-tool-round status flip. Heartbeat tick audits the board; drift means a future agent reads stale state. (`clickup-status-as-hard-gate.md`.)
6. **Skipping Self-Test Reports on UX-visible PRs** — Tess shouldn't be cold-reading a UI diff. Author posts a Self-Test Report comment before Tess reviews; Tess bounces if missing. (`self-test-report-gate.md`.)
7. **Refusing or asserting impossibility from priors** — fresh Drew agent confidently refused a real bug claiming the premise was fabricated; CI logs proved otherwise. Always check actual evidence (CI logs, file contents, repro output) before refusing. (`agent-verify-evidence.md`.)
8. **`chore(...)` self-merge by author** — `chore(ci|build|repo)` is exempt from Tess sign-off but **not** from orchestrator/Priya merge identity. Devs do not self-merge their own PRs in any category. (Process-incidents 2026-05-02; GIT_PROTOCOL G-01 fix landed in PR #127.)

---

## 10 — Quick-resume checklist

When picking up the project after a pause, do these in order:

1. **Read live state-of-truth, in order:**
   - `team/STATE.md` (per-role status — note the systemic merger-bump drift; `git log` is more authoritative than role sections for "what merged when")
   - `team/log/heartbeats.md` (recent 5-10 ticks for trajectory)
   - `team/DECISIONS.md` (recent 5-10 entries for what's locked)
   - `team/priya-pl/risk-register.md` (top-5 + watch-list)
   - `team/log/process-incidents.md` (5 new entries from PR #131)
   - `C:/Users/538252/.claude/projects/c--Trunk-PRIVATE-RandomGame/memory/MEMORY.md` (the rules)
2. **Survey GitHub:**
   - `git fetch origin && git log origin/main --oneline -10`
   - `gh pr list --state open --json number,title,headRefName`
   - `gh run list --workflow=release-github.yml --limit 1` (current RC artifact — likely still the prior `7b80429` build until post-wave trigger fires)
3. **Check ClickUp board reality vs STATE.md:** `mcp__clickup__clickup_filter_tasks` on list `901523123922`. If MCP is down, drain `team/log/clickup-pending.md` on reconnect.
4. **Decide path** based on Sponsor signal:
   - **Sponsor signed off M1** → dispatch M2 week-1 per `m2-week-1-backlog.md`; bug-bash drains first.
   - **Sponsor bounced with bugs** → Tess triages → file as `bug(...)` ClickUp tasks → Devon/Drew fix-forward → re-soak.
   - **Sponsor still mid-soak / no signal** → 3-5 parallel dispatches in the safe-to-dispatch envelope (anticipatory planning, doc-drift fixes, design specs, M2 prep). Don't load M1 player-facing code while soak is mid-flight.
   - **Post-wave RC in flight (run `25393528075`)** → wait for green conclusion; capture artifact link for soak-checklist-v2 §1 setup. If red, dispatch Devon/Tess to triage the regression.
   - **Sponsor asked a question** → just answer; don't auto-dispatch.
5. **Confirm dispatch envelope on the heartbeat tick** — at least 3 agents in flight, or an explicit narrow-blocker logged (Sponsor-input-required / auto-mode-permission-denied / agent-reports-contract-conflict / user-says-stop). "Nothing to dispatch" is rarely true; default to dispatching Priya for backlog expansion if genuinely empty.

---

## Appendix — useful artifact links

- **Repo:** https://github.com/TSandvaer/RandomGame on `main`. Tip when authored: `0e77a92` (`a67474d` + PR #134 Tess run-031 STATE refresh). Verify current via `git fetch origin && git rev-parse origin/main`.
- **ClickUp list (M1 backlog):** `901523123922`. Recognized tags: `bug`, `chore`, `week-3`, `design`, `qa`. New tag categories require Sponsor / Priya space-level addition (per `team/log/clickup-pending.md` 22:30 flush).
- **Recent load-bearing PRs (post-fix-wave):**
  - PR #125 — `fix(build): ship build_info.txt inside HTML5 export bundle (BB-1)` at `879f099`
  - PR #126 — `chore(state): tess run 028 — post-drain restoration + bug-board audit (zero drift)` at `638bd27`
  - PR #127 — `docs(team): doc-drift bundle — GIT_PROTOCOL + dispatch-template + TESTING_BAR (Tess run-025 audit P0s)` at `1136e1d`
  - PR #128 — `fix(ui): add LMB/RMB to boot banner — full control reminder (BB-5)` at `4943137`
  - PR #129 — `fix(levels): room boundary collision walls (BB-3)` at `a02bb38` — also closes the LevelAssembler regression
  - PR #130 — `fix(ui): P-key reopens StatAllocationPanel after close (BB-4)` at `9b2c7a9`
  - PR #131 — `docs(team): process-incidents normalization (T-EXP-5)` at `9f68762`
  - PR #132 — `design(ux): sponsor-soak-checklist v2 — post-fix-wave re-soak` at `a67474d`
  - PR #133 — `qa(postmortem): charger test flake — root cause + remediation` at `c0c604e`
  - PR #134 — `chore(state): tess run 031 — post-wave landing + RC1-soak retired + post-fix-wave soak cut` at `0e77a92`
- **Earlier load-bearing PRs (pre-wave):**
  - PR #107 — `feat(integration): wire M1 play loop into Main.tscn` at `4484196` (M1 finish line)
  - PR #109 — `fix(combat): Hitbox sweeps already-overlapping bodies at spawn` at `5a3c945` (combat-fix defensive; root cause UNCONFIRMED)
  - PR #115 — `feat(combat): mob-side visual feedback — hit-flash + death tween + boss particles` at `ad38e04`
  - PR #118 — `fix(save): real ItemDef + AffixDef resolvers on load (BB-2)` at `92f7a19`
  - PR #122 — `feat(combat): player-side visual feedback — swing wedge + ember-flash on attack` at `7b80429`
  - PR #119 — `design(spec): performance budget` at `dd63909`
  - PR #123 — `docs(team): RESUME.md rewrite — post-M1-integration state + MARIAN-TUTOR rules adoption` at `4104f96` (this doc's prior version)
- **Key team docs:**
  - `team/STATE.md` (per-role status)
  - `team/DECISIONS.md` (decision audit trail)
  - `team/GIT_PROTOCOL.md` (workflow rules — refreshed in PR #127)
  - `team/ROLES.md` (role + responsibility matrix)
  - `team/TESTING_BAR.md` (Tess sign-off DoD — Self-Test Report + product-completeness sections landed in PR #127)
  - `team/orchestrator/dispatch-template.md` (canonical dispatch shape — refreshed in PR #127)
  - `team/log/heartbeats.md` (20-min watchdog ticks)
  - `team/log/process-incidents.md` (recurring drift patterns — 5 new entries in PR #131)
  - `team/log/charger-flake-postmortem.md` (Tess PR #133 — reusable test-flake lesson)
  - `team/log/doc-drift-audit-2026-05-03.md` (Tess run-025; the prior RESUME rewrite resolved RE-01..RE-07 from this audit)
  - `team/priya-pl/m2-week-1-backlog.md` + `m2-week-2-backlog.md` + `risk-register.md` + `performance-budget.md` (planning corpus)
  - `team/tess-qa/m1-bugbash-4484196.md` + `html5-rc-audit-591bcc8.md` (M1 soak probe-targets + bug catalog)
  - `team/uma-ux/sponsor-soak-checklist.md` (v1) + `sponsor-soak-checklist-v2.md` (post-wave re-soak playbook)
- **Orchestrator memory:** `C:/Users/538252/.claude/projects/c--Trunk-PRIVATE-RandomGame/memory/MEMORY.md`. Read the index, then per-rule docs as needed.

---

This doc is rewritten at every major phase boundary or whenever it drifts >1 P0 from current reality. Last rewrite: 2026-05-05 (Priya run-014, post-fix-wave). Previous version (2026-05-03 PR #123, "post-M1-integration state") is in git history if needed.
