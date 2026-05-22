# pm(process): land the 3 mitigations from M3 retrospective (PR #315)

Sponsor approved 2026-05-22 ("do recommended") the three prioritized mitigations from the M3 retrospective (PR #315, merged at commit `0ca8381`). This is the single coord-doc PR landing all three. No engine code touched.

## Lineage

- **Retro PR:** #315 — `pm(m3): M3 retrospective pass 1 — Tier 2 closed + Tier 3 W1 in-flight` (merged at `0ca8381`).
- **Retro doc:** `team/priya-pl/m3-retrospective.md` § §5 (top-3 mitigations for this week).
- **Sponsor approval:** 2026-05-22 "do recommended" on the §5 priorities.

## Mitigation 1 — orch-side merge-gate verification for HTML5-visual-gated PRs

**Where it landed:** `team/GIT_PROTOCOL.md` — new section "Orchestrator merge-gate verification (HTML5-visual-gated PRs)" inserted before § "Self-Test Report (UX-visible PRs)".

**Shape:** Before `gh pr merge --admin` on any PR matching the HTML5-visual-gated class (Tween / modulate / Polygon2D / CPUParticles2D / Area2D state mutations / ColorRect with HDR / tilemap-scroll / z-index changes), the orchestrator MUST verify against actual evidence:

1. CI run-id of the latest green build for THIS commit (not "should be green") — fetched via `gh pr view <N> --json statusCheckRollup` against HEAD SHA. Per memory `gh-run-list-race-on-just-pushed`: query by `--commit` not `--branch --limit 1`.
2. Build SHA in the release-build artifact name matches PR HEAD.
3. Self-Test Report comment includes either (a) real-browser screenshot/video of the probe target OR (b) explicit Sponsor-soak deferral with concrete probe targets enumerated. Headless Playwright captures alone are NOT acceptable for visibility-of-effect on this class.
4. For ineligible-surface PRs (escape-clause does NOT apply): pre-merge Sponsor-soak required, NOT post-merge.

If any check fails, the orchestrator bounces back to Tess (not the author) with a one-line note naming which check failed. Tess routes the recovery (request missing evidence from author OR route to Sponsor escape clause). The orchestrator does not substitute itself for Tess's lane.

**Why:** PR #291 (M3 Tier 2 W3, 2026-05-21) consumed ~12-15 agent-cycles across 7 author iterations. Tess APPROVED twice on GUT-green + CI-green; Sponsor overturned both. The merge happened on weak evidence because no orchestrator-side check verified "the Self-Test Report's HTML5-self-soak section is concretely present and includes a real-browser screenshot, not just a headless Playwright capture." Gate existed in dispatch-brief discipline but not in merge-time discipline.

**Mirror into dispatch-template:** `team/orchestrator/dispatch-template.md` — new section "HTML5-visual-gated merge-gate verification (orchestrator-side, paste when dispatching gated PRs)". Dispatch briefs for gated PRs paste this so authors know the verification happens at merge time and satisfy it up-front.

## Mitigation 2 — `tightened-final-report-contract` amendment requiring cite-able evidence

**Where it landed (memory body):** `~/.claude/projects/c--Trunk-PRIVATE-RandomGame/memory/tightened-final-report-contract.md` — two new amendment sections appended:

**Amendment A — claim-fidelity.** Any final-report claim about CI / test / soak / artifact state MUST cite verifiable evidence. Bare assertions ("CI passes", "GUT clean", "Soak fine") are not acceptable. Required citation shapes:

- **CI state:** `CI: <run-id URL>` or `CI: pass on <commit SHA>`. NOT "CI passes" / "CI green" / "CI should be green".
- **GUT results:** `GUT: <N>/<M> on <commit SHA>`. NOT "GUT clean" / "GUT passes".
- **Playwright results:** `Playwright: <run-id URL>` or `Playwright: <N>/<M> on <commit SHA>`. NOT "Playwright green".
- **Soak verification:** `Soak: <screenshot/video URL>` or `Soak: deferred to Sponsor with probes: <enumerated list>`. NOT "soak fine" / "Sponsor will check".
- **Paired tests:** `Tests added: <file path>:<line range>`. NOT "paired tests added".
- **In-flight state:** if a check is genuinely still running at report time, cite the run-id URL with pending status. NOT "CI in flight" with no link.

Orchestrator-side enforcement: sub-agents whose final reports lack cite-able evidence on a state claim get a SendMessage bounce-back asking for the cite BEFORE the orchestrator processes the report or dispatches the next agent.

**Amendment B — return timing.** Submit final report at `ready for qa test` (PR open + Self-Test Report posted + ClickUp flipped) and EXIT. Do NOT wait for Tess QA or orchestrator merge before reporting. Concrete tell: if your final report describes events that happened AFTER your work was done (merge, Tess approval, ClickUp `→ complete` flip), you waited too long. Submit at PR-open + ClickUp `ready for qa test` and exit.

Cost evidence (B): Drew's PR #312 agent ran 42 minutes on a paper-design spike that should have been ~15-20 min wall clock; the ~22-min delta = agent waiting for events outside its scope.

**Mirror into dispatch-template:** `team/orchestrator/dispatch-template.md` — § "Final-report shape — TIGHT" rewritten to include cite-able-evidence required shapes (each citation form spelled out) + return-timing paragraph. Sub-agents read this at brief time per Finding 1 of the retro (auto-memory invisible to sub-agents).

**MEMORY.md index updated** to note both amendments in the existing `tightened-final-report-contract` entry (not a new entry).

## Mitigation 3 — port load-bearing memory rules into `team/TESTING_BAR.md`

**Where it landed:** `team/TESTING_BAR.md` — new section "Load-bearing memory rules ported here for sub-agent visibility" inserted before § "Final-report shape — TIGHT (orchestrator-bound reports)".

**Rules ported (each starts with `Auto-memory: <memory-name>` so lineage is preserved):**

- `html5-visual-verification-gate` — full memory body content as a section. The Tween/modulate/Polygon2D/CPUParticles2D HTML5-runtime verification rule from the PR #115/#122 cautionary tale.
- `html5-visual-gated-author-self-soak` — full memory body content as a section. The PR #291 anti-pattern + author-self-soak burden-of-proof + Playwright-headless ≠ real-browser-perception caveat.
- `self-test-report-gate` — full memory body content as a section. UX-visible-PR categories + report format pointer.
- `testing-bar` — short back-pointer to the existing § "Definition of Done (DoD)" anchor; the full rule already lives at the top of TESTING_BAR.md. The back-pointer exists so sub-agents searching for "testing-bar" land at the right anchor.
- `product-vs-component-completeness` — full memory body content as a section. M1 Main.tscn-stub miss cautionary tale + "components pass tests, products integrate" mantra.
- `agent-verify-evidence` — full memory body content as a section. Stratum1BossRoom GDScript parse-error incident + "pull the actual artifact before refusing" rule.

The auto-memory entries continue to exist as the orchestrator's reference; this is the sub-agent-facing mirror. **Why:** memory P3 root-cause #1 from the retro — memory rules are read-by-orch, not by sub-agents. The fix is to surface the rules where sub-agents actually read them at dispatch time (`team/` corpus is auto-read by personas).

## Other artifacts

- **`team/STATE.md`** — Priya section bumped run 018 → run 019; previous status preserved.
- **3 follow-up ClickUp tickets filed** under list `901523123922`, class `process-improvement`:
  - Mitigation 1 tracking ticket
  - Mitigation 2 tracking ticket
  - Mitigation 3 tracking ticket

  Each ticket cites this PR (#316) + retro PR #315 + the relevant memory entry. These are tracking tickets so the mitigation lands have a board surface; no pre-dispatched work.

## Constraints honored

- **Single PR for all 3 mitigations + MEMORY.md index update.** Not split.
- **PR class: orch-docs** — no Tess QA gate per `team/GIT_PROTOCOL.md` exemption table for `chore`/`docs`/coord work. CI green is the only gate.
- **No source code touched.** Coord docs + memory + templates only.
- **Pure-docs testing-bar exemption applies.** No paired tests needed; CI green is the only gate per § "Definition of Done (DoD)" exemption clause.
- **Cross-references retro PR #315** (commit `0ca8381`) throughout so lineage is clear.
- **Step-0 cd convention honored:** worktree session opened with `cd C:/Trunk/PRIVATE/RandomGame-priya-wt && git fetch origin && git checkout -B priya/m3-retro-mitigations-1-2-3 origin/main && pwd`.

## Non-obvious findings

1. **The retro itself surfaced a 4th P2-family incident mid-flight** — Drew's PR #312 zone-schema spike agent ran 42 min because it waited for the orchestrator merge before reporting. The coordinator flagged this during this PR's drafting; folded into Mitigation 2 as the return-timing amendment paragraph. This is consistent with retro P2 (author optimism / final-report quality) — the pattern keeps surfacing in fresh ways.

2. **The auto-memory mirror discipline (`Auto-memory: <name>`) is a new convention.** This PR introduces it: each ported memory section in TESTING_BAR.md begins with the `Auto-memory: <name>` lineage line. Future memory ports should follow the same shape so the auto-memory ↔ team-doc relationship is inspectable. Watch signal: do agents reference rules by `Auto-memory: ...` anchor in future PRs?

3. **The mitigation cost was low (1 docs PR, ~30 min Priya time).** This validates the retro's §5 framing — Priority 1 (Mitigation 1) is "pure orch-behavior change, can land this week." Confirmed.

## Cross-references

- `team/priya-pl/m3-retrospective.md` § §5 (top-3 mitigations) — the source.
- PR #315 (`0ca8381`) — the retro PR.
- `team/GIT_PROTOCOL.md` § "Orchestrator merge-gate verification (HTML5-visual-gated PRs)" — Mitigation 1 landing site.
- `team/orchestrator/dispatch-template.md` § "HTML5-visual-gated merge-gate verification" — Mitigation 1 dispatch mirror.
- `team/orchestrator/dispatch-template.md` § "Final-report shape — TIGHT + cite-able evidence" — Mitigation 2 dispatch mirror.
- `team/TESTING_BAR.md` § "Load-bearing memory rules ported here for sub-agent visibility" — Mitigation 3 landing site.
- Auto-memory `tightened-final-report-contract.md` — Mitigation 2 source-of-truth (amended 2026-05-22).
- Auto-memory `html5-visual-verification-gate`, `html5-visual-gated-author-self-soak`, `self-test-report-gate`, `testing-bar`, `product-vs-component-completeness`, `agent-verify-evidence` — Mitigation 3 sources.
- Memory `agent-lifecycle-vs-sendmessage` — referenced by Mitigation 2 return-timing amendment.
- Memory `gh-run-list-race-on-just-pushed` — referenced by Mitigation 1 CI-cite query.
- Memory `clickup-flip-paired-with-merge` — referenced by Mitigation 2 return-timing amendment.

## Decision draft (for next Priya weekly batch into team/DECISIONS.md)

- **Decision draft:** M3 retrospective Mitigations 1+2+3 landed 2026-05-22 (PR #316) per Sponsor "do recommended". Mitigation 1: orch-side merge-gate verification for HTML5-visual-gated PRs in `team/GIT_PROTOCOL.md`. Mitigation 2: `tightened-final-report-contract` amended with cite-able-evidence + return-timing rules; memory + dispatch-template + MEMORY.md updated. Mitigation 3: `html5-visual-verification-gate` + `html5-visual-gated-author-self-soak` + `self-test-report-gate` + `testing-bar` (back-pointer) + `product-vs-component-completeness` + `agent-verify-evidence` ported into `team/TESTING_BAR.md` for sub-agent visibility. 3 process-improvement tracking tickets filed.
