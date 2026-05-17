# M2 W3 RC — Week-Ahead Plan

**Owner:** Priya · **Authored:** 2026-05-16 (end-of-session, post-PR #247 boss-room collision_layer fix merged) · **Horizon:** ~one week of dispatch starting next session · **Status:** v1.0 — dispatch-ready, revisable on Sponsor signal.

This plan replaces the implicit "what's next" from the 2026-05-16 session save with a ranked, dependency-aware sequence. It is **calendar-aware but framed as sequence + dependencies, not speculative dates** — agent throughput drifts across sessions; commitment is to ordering, not days.

The week ahead is bounded by three milestones:

1. **AC4 white whale closure** (`86c9qckrd`) — the 2-month spec blocker. Closure means Playwright `ac4-boss-clear.spec.ts` flips `test.fail()` → `test()` and stays green for ≥8 consecutive release-build runs.
2. **M2 W3 RC ship** — combined-build artifact handed off to Sponsor for the M2 sign-off soak. Sole remaining mechanical gate after AC4 closure is the Sponsor's feel-check soak under the new gates installed by PR #216 (regression-guard / cross-lane / journey-probe).
3. **M3 shape decided** — Sponsor signs off the M3 milestone-shape question (see `m3-shape-options.md`, this batch). Until shape is locked, M3-implementation tickets cannot dispatch; design-seed exploration is the only legitimate M3 work.

## TL;DR (5 lines)

1. **Critical chain:** PRs #248 + #249 merges (test-infrastructure drift fixes, in cross-author review) → class-wide drift audit (Tess, new this batch) → AC4 closure wave (Drew Rooms 05/06/07) → AC4 spec flip (Tess) → end-of-W3 journey-probe + bug-bash (Tess, new PR #216 gate) → Sponsor M2 RC soak → M2 RC sign-off.
2. **Parallel lanes:** Tess canary investigation (`86c9upfex` — instance of drift class), Tess preemptive S2 boss physics-flush smoke (`86c9uf0r5`), Devon cluster #2 triage close-out (`86c9upffv` — may consolidate into AC4), cosmetic CI cleanup (`86c9uefuz` — fire-and-forget).
3. **M3 prep runs in parallel** — Priya authors M3 shape options (this batch). No M3-implementation work dispatches until Sponsor locks shape post-M2-RC-soak.
4. **Total tickets:** 11 active (after R-DRIFT additions) + 2 conditional (Sponsor-soak-driven) + 1 admin cleanup. Throughput target ~10-12 PRs across the week, accounting for AC4 + drift-audit + canary parallel load.
5. **Top risk for the week (changed 2026-05-16 evening):** **R-DRIFT** (spec-string-vs-engine-emit silent-pass) supersedes the prior top-risk (AC4 surfacing). PRs #248 + #249 surfaced two multi-week silent-pass specs same-day; class-wide audit may surface more. The AC4 surfacing pattern is **partly downstream** of R-DRIFT — silent-pass specs masked sub-helper failures, so AC4 fixes surfaced "next bugs" that had been there all along. Until drift-pin pattern is universal, no Playwright-green run is fully trustworthy.

## Pre-conditions (state at session start)

- ✅ **Main HEAD `c3ba4fb`** — PR #247 merged. Finding 2 boss-room collision_layer fix landed. M2 W3 RC Finding 2 saga fully closed.
- ✅ **Combined build available** for Sponsor verify (`embergrave-html5-112e24c`, run 25970650493) — held for next-session Sponsor sign-off if PR #247 verification round wasn't completed.
- ✅ **3 agents finishing in flight** at session-start handoff (per dispatch brief): Drew on Room 05 player-death (`86c9uf1x8`), Tess on canary investigation (`86c9upfex`), Devon on cluster #2 mob-engagement triage (`86c9upffv`). Their outputs feed the week-ahead sequencing below; if all three close before this plan dispatches, dispatch from §"Ticket order" §1 directly.
- ⚠️ **Cluster #3 admin cleanup pending** (`86c9upfbq` Room 01 pickup-race) — empirically resolved by PR #241; needs ClickUp flip to `complete` only. ~1 min orchestrator-side; no agent dispatch needed.
- ⚠️ **AWAY-mode autonomy calibration** — 0/11 reversal this session (target 5–10%). Bar is too cautious. Ticket proposed below to recalibrate next AWAY stretch.

---

## Ticket order — ranked with rationale

Order is **dispatch-priority**, not estimated completion-time. Sequence within a tier is parallelizable; tiers must drain (mostly) before the next tier dispatches.

### Tier 1 — AC4 closure wave (P0, must drain before W3 RC ships)

These are the active AC4 blockers carrying from the 2026-05-16 session. Closure of all three flips the white whale and unblocks the M2 RC handoff.

**1. `86c9uf1x8` — Room 05 player-death recurrence (P0, Drew — in flight)**

- **Why first:** upstream blocker. PR #208's "3/3 deterministic" Self-Test was empirically a lucky-roll sample; reality is ~80% Player-death rate in release-build AC4. The white whale cannot close until Room 05 is deterministic.
- **Discipline:** instrument-first per `diagnostic-traces-before-hypothesized-fixes`. Player.hp during engage + charger AI state at death-frame. The ticket already names this in its hypothesis list — no further Priya prompting required.
- **Decision branch:** harness-side fix (kite-between-engages) preferred over game-side balance, per ticket. Game-side balance escalates only if harness can't crack it — this preserves Uma's PR #201 balance lock as the authoritative balance pin.
- **Acceptance:** ≥8 deterministic Room 05 clears in release-build AC4 runs. Self-Test Report with the 8-run evidence.
- **Cross-reference:** parent `86c9qckrd` (white whale).

**2. `86c9uh2ue` — Rooms 06/07 kiting-chase mob-trace staleness (P0, Drew — queued)**

- **Why second:** downstream of Room 05. Tess's QA pass on PR #224 surfaced `[stale — using computed]` markers proliferating at cycle 16+ in Rooms 06 + 07. Probable root cause overlap with `86c9uh2kg` (Drew's Room 07 framing).
- **Triage-on-pickup:** instrument BOTH rooms first to confirm whether `86c9uh2ue` (Room 06 trace-staleness) and `86c9uh2kg` (Room 07 2-Shooter dispersal) are the same root cause or two layers. Drew decides consolidate-vs-sequential after the instrument pass.
- **Discipline:** instrument-first again. The ticket explicitly names this; no further prompting.
- **Acceptance:** AC4 spec passes Rooms 06 + 07 deterministically ≥8 release-build runs.

**3. `86c9uh2kg` — Room 07 2-Shooter dispersal (P0, Drew — queued, likely consolidates with #2)**

- **Why third:** sibling of #2. Drew's framing differs from Tess's, but PR #224's deepest-progression sweep showed both surfaces failing on the same run. Single owner, single fix likely.
- **Acceptance:** AC4 spec advances past Room 07 deterministically ≥8 release-build runs.

**4. AC4 spec flip (`86c9qckrd` — Tess, gated on #1+#2+#3)**

- **Why fourth:** the white whale itself. Closure mechanic is "flip `test.fail()` → `test()` on `ac4-boss-clear.spec.ts`" after Rooms 05/06/07 land green. Tess owns the flip + the 8-run regression evidence.
- **Tess-can't-self-QA carve-out:** per memory `tess-cant-self-qa-peer-review`, the flip PR needs a Drew peer review (game-side adjacent — Drew is the kiting-mob-chase author and validated the room-by-room state). Devon is the harness-fixture co-author and an acceptable alternate.
- **Acceptance:** AC4 spec runs as `test()` for ≥8 consecutive release-build runs; ticket `86c9qckrd` flips to `complete`; `team/log/process-incidents.md` gets a one-line entry recording the white whale closure.

### Tier 2 — Parallel test-infrastructure-drift + canary + preemptive (P0/P1, independent of Tier 1)

These dispatch in parallel with Tier 1; no dependencies. Use them to keep parallel-dispatch ≥3 agents while Drew works the AC4 lane.

**Tier 2 priority bumped 2026-05-16 evening:** PRs #248 + #249 surfaced a new structural class — **spec-string-vs-engine-emit drift** (R-DRIFT in risk register; §3.5 Gap 4 in AC4 retro). Both merged at session-end (PR #248 at `84451f5`, PR #249 at `a885d56`). Class-wide scan of existing Playwright specs is now Tier 2's most-load-bearing follow-up. **Promotes ahead of the canary investigation** because R-DRIFT is the parent class; the canary issue (R-CANARY) is one instance of it.

**4.5. PRs #248 + #249 merged at session-end (`84451f5`, `a885d56` on main)**

- **Status:** complete. PR #248 (Tess) fixed the universal-warning-gate `"warn"` vs `"warning"` type mismatch — every existing spec that wraps with the gate is now ACTUALLY-ASSERTING for the first time in ~10 days. PR #249 (Devon) fixed `mob-self-engagement.spec.ts` `team=mob` regex (engine emits `team=enemy`). Both shipped `.claude/docs/test-conventions.md` doc updates naming the drift class.
- **Implication:** every CI run pre-`84451f5` on main may have been hiding warnings or test failures the drift-affected specs would have caught. **Next CI run on this PR is the first one that fully asserts** for warning emissions across the migrated spec corpus. Watch for new failures from previously-silent assertions.

**4.6. `86c9ur5wf` — class-wide Playwright drift-pin audit (Urgent, Tess, dispatches AFTER #248 + #249 merge, created this batch)**

- **Why now:** the two same-day drift findings are unlikely to be the only instances. Pattern: any Playwright spec asserting on a free-form `[combat-trace]` / engine-emit string without a paired GUT drift-pin is latent silent-pass. ~10-20 specs to scan against current engine constants; ~30 min per spec; ~5-10 hours total work.
- **Output:** audit report at `team/tess-qa/playwright-drift-audit-2026-05-16.md` enumerating each spec's assertion-strings + drift-pin status. 0-N follow-up tickets for silent-pass specs found.
- **Acceptance:** all existing Playwright specs either have drift-pin GUT pairings OR have a follow-up ticket filed. `team/tess-qa/playwright-harness-design.md` updated with drift-pin convention as mandatory.
- **Devon peer reviews** the audit doc; the convention update is a `Decision draft:` line for next Priya batch.

**5. `86c9upfex` — Universal-warning-gate canary failure investigation (P0-impact / high-priority, Tess — in flight)**

- **Why P0-impact:** the canary is the regression-pin for the universal warning gate itself. If broken, every "green CI" may be hiding warnings the gate silently misses — the gate becomes a green-by-default rubber stamp rather than a real assertion. This is high-leverage; mis-calibration here propagates across all future spec runs.
- **Owner:** Tess (she shipped the canary + fixture, knows the spec internals).
- **Tess-can't-self-QA carve-out:** small fix-PR likely (1-3 lines); Devon peer-reviews per memory pattern.
- **Acceptance:** canary correctly fails-then-passes the inverted `test.fail()` semantics; documented `playwright-harness-design.md` § how to write canary tests that survive `test.fail` inversion.

**6. `86c9uf0r5` — S2 boss physics-flush smoke (P0, Tess — queued)**

- **Why preemptive:** W3-T4 (Vault-Forged Stoker S2 boss room) is parked but anticipated for the M3 backlog. The smoke test ships as a `test.fail()` stub ahead of the room's authoring — a guard that closes the moment Drew authors S2BossRoom. Same shape as S1 boss-room's PR #232 / PR #241 / PR #247 saga, except this time the regression-pin precedes the bug class instead of trailing it.
- **Owner:** Tess.
- **Acceptance:** spec exists in `tests/playwright/specs/`, fails with a clear "S2 boss room not yet implemented" message, opens green the day W3-T4 lands.

### Tier 3 — Cluster close-out + admin cleanup (P0-mixed, parallel with Tier 1/2)

**7. `86c9upffv` — Cluster #2 mob-engagement Rooms 02-08+Boss (Urgent, Devon — in flight)**

- **Why parallel:** Devon's triage may reveal this is pre-existing mob-engagement scope (overlaps `86c9uh2ue` + `86c9uh2kg`) OR migration-induced by Phase 2A migration. Output is either a consolidation note ("absorbed into Drew's AC4 lane") or a separate dispatch. Independent of Drew's Tier-1 work until consolidation is known.
- **Decision branch:** if Devon's triage shows overlap with AC4 cluster, close as duplicate-of-`86c9uh2ue`. If genuinely separate, dispatch as its own ticket after Drew drains Tier 1.

**8. `86c9upfbq` — Room 01 pickup-race admin close (admin, no agent)**

- **Why fire-and-forget:** Tess's audit confirmed PR #241 empirically resolved this. No PR needed; orchestrator-side ClickUp flip to `complete` only. ~1 min.

**9. `86c9uefuz` — GitHub Actions `download-artifact@v4` wildcard fix (P2, Devon — small)**

- **Why now:** the AWAY queue is shallow during AC4 closure; small cosmetic-but-recurring CI fix; ~30 min dev work + Tess review. Slot for Devon if the cluster #2 triage closes fast.
- **Decision branch:** explicitly skip-or-defer if Devon is loaded on cluster #2 or sucked into AC4-cluster consolidation.

### Tier 4 — M2 RC handoff (gated on Tier 1 closure + new PR #216 gates)

**10. Tess journey-probe artifact (per PR #216 gate, mandatory at RC boundary)**

- **Why:** PR #216 installed a new TESTING_BAR.md gate — Tess runs ONE complete player journey (boot → Room01 → S1 traverse → boss → loot pickup → save → quit → reload → resume) and logs the result before any build hands to Sponsor. The M2 RC must carry this artifact. **This was the "Sponsor became journey-scoped tester by default" structural fix.**
- **Owner:** Tess.
- **Output:** `team/tess-qa/journey-probe-<date>.md` filed alongside the M2 RC artifact link.
- **Acceptance:** zero `USER WARNING:` / `USER ERROR:` lines, zero item-id resolution failures, zero missing/un-collectable loot. Any blocker re-opens AC4 closure or feeds back into Drew/Devon fix-forward.

**11. M2 RC build + Sponsor handoff (orchestrator-authored, gated on Tier 1+10)**

- **Why:** combined-build pattern (per session save §"Key decisions" #6). Single artifact contains AC4 closure + journey-probe pass + all Tier 1/2/3 closures since `c3ba4fb`. Direct-artifact-link convention per memory `sponsor-soak-artifact-links`.
- **Owner:** orchestrator authors the handoff message; Sponsor performs the interactive soak.
- **Acceptance:** Sponsor's M2 sign-off on the soak (feel-check, not bug-discovery — PR #216's structural fix is now in force).

### Tier 5 — M3 shape decision (parallel design work, Sponsor-input gated)

**12. `86c9ur5aq` — M3 shape options exploration (P1, Priya — design-only, created this batch)**

- **Why:** post-M2-RC-soak, M3 shape is undecided. Existing `m3-design-seeds.md` (PR #213 area) frames M3 as "content + multi-character + hub-town + meta + art-pass" — but that's ONE possible M3 shape. Sponsor needs the question framed as "which M3 shape ships first?" not "implement everything in the design-seeds doc." See `m3-shape-options.md` (this batch) for the three alternatives + Priya recommendation.
- **Owner:** Priya (this PR delivers the framing); Sponsor signs the shape at M2 sign-off conversation.
- **Acceptance:** Sponsor picks the M3 shape; orchestrator dispatches the M3 W1 backlog against the locked shape.

**13. `86c9ur5j7` — AWAY autonomy bar recalibration (P2, orchestrator-meta, created this batch)**

- **Why:** session reversal-rate was 0/11 (8 from prior session + 3 from this one's autonomy gate). Target is 5–10%. Bar is too cautious — every gate the orchestrator surfaced was accepted, meaning the orchestrator paid round-trip cost on decisions that didn't need surfacing. See `m2-week-3-mid-retro.md` shape and risk-register R-AUTO entry below.
- **Owner:** orchestrator (memory update — `away-mode-autonomy-bar-recalibration`); no agent dispatch.
- **Acceptance:** next AWAY stretch lands 1–3 reversals across ~10-15 entries (5–15% rate); confirms the bar is now in calibration range.

---

## Conditional add-ons — Sponsor-soak driven (only dispatch if Sponsor surfaces signal)

- **W3-T7 stash UI iteration v1.1** — Sponsor-conditional. No signal from current state; defer to W4 if no signal lands.
- **W3-T8 ember-bag tuning v2** — Sponsor-conditional. Same shape.

If Sponsor's M2 sign-off soak surfaces ≥3 P0s, the post-soak fix-forward wave displaces Tier 5 and the M3 shape decision punts one week.

---

## Capacity check

**Total tickets:** 9 active + 2 conditional (Sponsor-driven) + 2 admin/meta = **13 items**. Of these, ~6-7 are dispatch-ready agent-PR tickets; the rest are admin (cluster #3 close, AWAY recalibration memo) or gated on Sponsor signal.

**Throughput target:** ~8-10 PRs across the week. Below M2 W2's 22 PR mark by design — the AC4 closure wave is the load-bearing work and each Drew dispatch carries empirical surfacing risk (see `ac4-white-whale-retro.md`).

**Per-role load:**

- **Drew:** Tier 1 entirely (Rooms 05/06/07). 3 PRs. Same load shape as M2 W3 mid (where Drew shipped 4 PRs in 24h).
- **Tess:** Tier 2 (canary + S2 boss smoke) + Tier 4 (journey-probe + AC4 spec flip). 4 PRs. Heavier than W2's average; in line with the new PR #216 RC journey-probe gate which routes more work to her.
- **Devon:** Tier 3 (cluster #2 triage + admin CI fix). 1-2 PRs. Light load — appropriate. He's the AC4 closure spec peer reviewer too.
- **Uma:** no tickets this week. Light load is appropriate while AC4 closure absorbs Drew/Tess.
- **Priya:** Tier 5 (M3 shape options — this batch) + AWAY recalibration memo + risk-register update (this batch) + AC4 retro (this batch). 1 batch PR.

**Buffer:** 2-3 free dev ticks for reactive work (cluster #2 triage outcome surprises, Sponsor-soak fix-forward).

---

## Hand-off (per `team/orchestrator/dispatch-template.md` shape)

When this plan merges + Drew finishes Room 05:

- **Orchestrator:** dispatch Drew on `86c9uh2ue` / `86c9uh2kg` instrument-first round (parallel with Drew's Room 05 closure); Tess on `86c9upfex` canary investigation (already in flight, monitor); Devon on cluster #2 close-out (already in flight, monitor); admin close on `86c9upfbq`.
- **Drew:** picks up Rooms 06/07 instrument pass after Room 05 lands. Diagnostic-trace pair pattern (per `diagnostic-traces-before-hypothesized-fixes`). Reports consolidation decision in his Room 05 final report.
- **Tess:** finishes canary investigation; queues S2 boss physics-flush smoke; gates journey-probe + AC4 spec flip on Drew's Tier 1 closure.
- **Devon:** cluster #2 triage report; peer-reviews Tess canary PR (small); slot for cosmetic CI fix if capacity allows.
- **Priya:** authors this batch (week-ahead plan + M3 shape options + risk-register + AC4 retro). After Sponsor M2 sign-off: drafts M3 W1 backlog against locked shape.

---

## Caveat — v1.0 dispatch-ready, revisable

Revision triggers (per the W3 backlog caveat shape, same convention):

- **Drew's Room 05 instrument pass surfaces a fourth blocker** (Room 08 or Boss room) — escalates to a structural pause (see AC4 retro §"What to do if AC4 keeps surfacing rooms").
- **Sponsor surfaces M2 RC blockers in the post-AC4 soak** — Tier 5 punts; W4 absorber dispatches.
- **Cluster #2 triage consolidates Drew's lane** — Tier 3 partially absorbs into Tier 1; no separate dispatch needed.
- **Sponsor picks an M3 shape other than the content-track recommendation** — M3 W1 backlog dispatches against the picked shape; this doc updates to reflect.

Revisions land as a v1.x of this doc with the changed sections diff-highlighted and a one-line DECISIONS.md append in the next Priya weekly batch.

**This v1.0 is the path of least resistance from M2 W3 RC Finding 2 closure → M2 RC sign-off → M3 W1 onset.** It is not the only path.
