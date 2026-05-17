# AC4 White Whale Retro — Surfacing Pattern + Structural Gaps

**Owner:** Priya · **Authored:** 2026-05-16 (post-PR #247, M2 W3 RC Finding 2 saga closed; AC4 cluster still has 3 open P0 blockers Rooms 05/06/07) · **Status:** v1.0 — honest retro, not victory lap.

## Verdict

**MIXED — leaning STRUCTURAL_GAP after 2026-05-16 test-infrastructure-drift surface.**

The AC4 spec has surfaced a new blocker on roughly every Drew dispatch since M1 close — Room 02 → Room 04 chase → Room 05 freeze → Room 05 balance → Room 05 panel-dismiss → Room 05 player-death recurrence → Rooms 06/07 trace-staleness → Room 07 2-Shooter dispersal → Boss-room loot pickup → Boss-room collision_layer (Finding 2 Class B). Nine empirically-distinct blockers across ~12 dispatches over ~2 months.

A naive surfacing-pattern retro would say "each room reveals the next — that's how integration works." That framing is **partially correct but incomplete.** Three of the nine blockers (PR #198 "chasers must be unwinnable," PR #208 "deterministic 3/3 Self-Test sample," PR #241 "Finding 2 is silent ERR_FAIL_COND") were **empirically falsified by subsequent diagnostic-trace passes** — meaning the fix shipped against a misdiagnosed cause. The team's diagnostic discipline has gotten better (`diagnostic-traces-before-hypothesized-fixes` memory validated twice in the last session alone), but the AC4 cluster has paid more agent-cycles than necessary on hypothesized fixes that traces later refuted.

**The 2026-05-16 test-infrastructure-drift finding shifts the grade further toward STRUCTURAL_GAP.** Two multi-week silent test-infrastructure regressions surfaced same-day during this session:

- **PR #248 (Tess)** — universal warning gate has been a NO-OP for warnings since PR #217. Playwright `ConsoleMessage.type()` returns `"warning"`; the fixture only checked `"warn"`. Every `USER WARNING:` line silently swallowed for multi-weeks.
- **PR #249 (Devon)** — `mob-self-engagement.spec.ts` regex `team=mob` never matched since PR #215. Engine emits `team=enemy` (constants are `TEAM_ENEMY="enemy"`); no `"mob"` string was ever produced.

**The class:** **Spec-string-vs-engine-emit drift** (Devon's framing in `.claude/docs/test-conventions.md`). Playwright specs assert on free-form trace strings without verifying the engine actually emits that string. When the engine emit drifts or the spec was wrong from inception, the spec silently passes/fails for the wrong reason. Tests are decorative until something forces empirical re-verification.

This **directly amplifies the AC4 cluster's surfacing-pattern cost.** Several of the "each fix surfaces a deeper room" iterations are downstream of this class: AC4 sub-specs were asserting against strings the engine may or may not have been emitting; when a fix landed, the spec's NEXT assertion was the next-untested-string, which then surfaced as a "new blocker" — but the blocker had been there all along, hidden behind a silent-pass assertion.

**Honest grade:** STRUCTURAL_GAP with incremental-discovery component. The 9-iteration history is partly the AC4 spec doing its job (integration probing) and partly the cumulative weight of three structural gaps (§3 Gaps 1+2+3) PLUS a fourth gap revealed today (§3.5 below — test-infrastructure-drift). The team CAN close all four gaps; the current session is the inflection point.

## §1 — The surfacing pattern, mapped

### Per-iteration history (M1 close → now)

| Iteration | Dispatch | Blocker surfaced | Cause-framing | Retroactive verdict |
|-----------|----------|-------------------|----------------|---------------------|
| M1 close | Spec authored as `test.fail()` | Room 02 wouldn't open | Mob-spawn timing race | Correct (game-side; PR #173 fix) |
| M2 W1 | PR #173 (Devon) | Room 02 game-side mob_alive race | physics-flush defer | Correct |
| M2 W1 | PR #174 (Tess) | 6 spec failures from PR #169 roster swap | spec-side mob class mismatch | Correct (mechanical migration) |
| M2 W2 | PR #186 (Drew) | Room 04 Shooter chase | helper logic | Partially correct — helper was right; Room 04 also had Shooter AI bug discovered later (`86c9uehaq`) |
| M2 W2 | PR #190 (Drew) | Room 04 return-to-spawn | chase-helper extension | Correct |
| M2 W2 | PR #191 (Drew) | Room 05 mob-freeze | physics-flush race | Correct (load-bearing physics-flush fix) |
| M2 W2 | PR #198 (Drew) | Room 05 multi-chaser unwinnable | position-steered harness sweep | **EMPIRICALLY REFUTED** by PR #200 diagnostic-trace pair — actual cause was Player death + harness misreporting freeze |
| M2 W2 | PR #200 (Drew) | Player._die + Main.apply_death_rule trace pair | empirical refutation | Correct — diag-only PR, the discovery |
| M2 W3 | PR #201/#206 (Uma + Drew + Devon) | Balance pass (Grunt 3→2, Charger 5→4, iframes 0.25s) | balance | Correct |
| M2 W3 | PR #208 (Drew) | Room 05 panel-dismiss | Escape-press in Self-Test | **EMPIRICALLY REFUTED** by PR #212 reproduction — 3/3 sample was lucky-roll; actual rate ~80% Player death |
| M2 W3 | PR #212 (Drew) | Room 06 stuck-pursuit | return-to-spawn pattern extension (proposed) | **REFRAMED** during reproduction — actual cause was stale `mob.dist_to_player` trace consumer; harness-side read-pattern bug |
| M2 W3 mid | (in flight) | Room 05 player-death recurrence (`86c9uf1x8`) | balance or harness strategy | Pending |
| M2 W3 mid | (queued) | Rooms 06/07 mob-trace staleness (`86c9uh2ue`) | trace-buffer freshness | Pending |
| M2 W3 mid | (queued) | Room 07 2-Shooter dispersal (`86c9uh2kg`) | helper kiter-priority | Pending |
| M2 W3 RC | PR #241 (Drew) | Boss-room Finding 2 Class A silent ERR_FAIL_COND | Pickup + StratumExit double-defer | Correct for Class A — but turned out to be partial fix only |
| M2 W3 RC | PR #247 (Drew) | Boss-room Finding 2 Class B Player.collision_layer=0 | iframe re-entry guard | Correct (the actual root cause; needed diag instrumentation triad to find) |

### The pattern in summary

- **Game-side bugs surfaced incrementally as the harness's progression depth increased.** Each dispatched fix exposed the next-deeper room or interaction state. That part is **unavoidable** — the AC4 spec is acting as a depth-first empirical integration probe; bugs at depth-N are invisible until depth-(N-1) clears.
- **Harness-side misdiagnoses happened 3 times** (PR #198, #208, #212-as-originally-framed). Each was a hypothesized fix that diagnostic-trace empirical work later refuted. The fix shipped (with some real benefit, like a regression-pin or a partial improvement) but the root cause was elsewhere.
- **The current 3-room cluster (Rooms 05/06/07)** is mid-iteration. Whether they're a true depth-frontier (unavoidable) or yet-more misdiagnosis (structural gap) won't be known until Drew's next instrument-first pass closes them.

---

## §2 — Why surfacing pattern is partly unavoidable

There's a real and irreducible component to the cost. Three contributors:

1. **The AC4 spec IS the integration probe.** Per `product-vs-component-completeness` memory: "tests pass" ≠ "product ships." AC4 deliberately exercises the full M1 play loop end-to-end. By design, it surfaces bugs that component-tests can't. The 4 Sponsor M2 RC soak findings (per `m2-week-3-mid-retro.md §3`) were the same shape — system-integration bugs invisible to per-component tests. AC4 is finding bugs that AC4 was authored to find. **That's a feature, not a failure.**

2. **HTML5 release-build divergence costs are real.** Per `.claude/docs/html5-export.md`, the `gl_compatibility` renderer has six load-bearing divergences from desktop / headless (HDR clamp, Polygon2D rendering, z-index, default-font glyphs, browser-event leakage, DirAccess on packed `.pck`). Several of the AC4 blockers (PR #137 swing-wedge tint, PR #166 ContentRegistry leather_vest, PR #179 equipped-glyph tofu) were HTML5-only divergences invisible to headless GUT and desktop. **The cost of HTML5-specific surfacing is irreducible** — the renderer divergence is real; the only way to catch the bug is to run the HTML5 release-build.

3. **Two-month elapsed time is mostly compressed iteration cost, not throughput failure.** Within the 2-month elapsed window, the team shipped:
   - 587 paired GUT tests (per `m2-week-2-retro.md`).
   - 247 PRs merged (per `git log origin/main`).
   - 5 save-schema migrations.
   - M1 RC + M2 W1 + M2 W2 + M2 W3 (3 full milestones).
   The AC4 white whale is **one of many threads** — not the dominant work surface. Counting elapsed weeks misweights it; counting agent-cycles spent specifically on AC4 is closer to 8-12 ticks across the whole period, which is proportional to the bug class's complexity.

**Conclusion for §2:** if all 9 iterations had been correctly-diagnosed-first-time, the cost would still be 6-7 iterations (depth-first integration probing surfaces things). The structural gap is **not** "AC4 should have been one dispatch instead of nine" — it's "AC4 should have been six dispatches instead of nine."

---

## §3 — Structural gaps the team can close

Three identifiable gaps in the AC4 history. Each amplified the incremental cost.

### Gap 1 — Self-Test Reports asserted reproducibility from too-small samples

**Pattern:** PR #198 claimed "Room 05 freezes are unwinnable" from a small repro sample; PR #208 claimed "3/3 deterministic Room 05 clear" from 3 runs; PR #241 claimed Finding 2 was Class A based on the pattern matching the prior PR #232 Class A case. All three were **partially or fully refuted by subsequent diagnostic-trace passes that used larger sample counts + instrumented traces**.

**Root cause:** the Self-Test Report gate (`self-test-report-gate.md` memory) is structurally good — it forces the author to verify before Tess reviews — but the **statistical bar** for the verification was implicit. "I ran it 3 times, it worked 3 times, deterministic" is not a statistically defensible claim for a stochastic-cost-of-iteration test like AC4. PR #208's 3/3 → reality 1/5 (80% Player-death rate) is the precedent.

**Mitigation (structural fix):** for any AC4 spec retest, the Self-Test Report MUST cite ≥8 release-build runs (matches the `86c9uh2ue` / `86c9uf1x8` acceptance criteria language). Smaller samples are not acceptance evidence; they're hypothesis-generation evidence. Codify in `TESTING_BAR.md` § "Statistical bar for stochastic-cost specs" (one-line addition).

**Cost so far:** 2 PRs of false-positive Self-Test (PR #198, PR #208) + 2 subsequent diagnostic-trace dispatches (PR #200, PR #212-reproduction) to refute them. ~4 wasted agent-cycles.

### Gap 2 — Hypothesized-fix-before-instrument was the default mode, not the exception

**Pattern:** PR #198 shipped a "chasers must be unwinnable" theory + the position-steered harness sweep without instrumenting Player.hp + charger AI state first. PR #212 was originally scoped as "Room 06 needs return-to-spawn pattern extension" without instrumenting `mob.dist_to_player` trace freshness first. PR #241's Class A fix shipped without Player.coll_diag trace — and turned out to be insufficient for Class B.

The memory rule `diagnostic-traces-before-hypothesized-fixes` was authored 2026-05-15 against this exact pattern. **It was validated TWICE last session (PR #241 → Finding 2 boss-room collision_layer; PR #246 → diag-only PR that found the iframe re-entry guard cause).** The rule works when followed. But it was authored AFTER ~5 misdiagnosis-cost iterations, not before.

**Mitigation (already partly in place):**
- `diagnostic-traces-before-hypothesized-fixes` memory rule exists.
- PR #216 process gates (regression-guard, cross-lane integration, Tess journey-probe) now codify some of the discipline structurally.
- Pending: dispatch-brief template should require an explicit "instrument plan" line for any AC4-cluster ticket (current dispatch-template.md doesn't enforce this — the discipline is via memory rule + author judgment).

**Cost so far:** estimate ~3-4 PRs that would not have been authored under instrument-first discipline. PR #198 + PR #208 + PR #212-as-originally-framed are the clearest examples. ~3-4 wasted agent-cycles.

### Gap 3 — No AC4-spec retrospective gate after N consecutive surfacing iterations

**Pattern:** at no point during the AC4 saga did the team explicitly pause to ask "is the AC4 spec the right test surface, or are we burning agent-cycles on a misshapen probe?" The white whale framing developed organically — but the framing was **status-quo, not retrospective.** The team kept dispatching the next AC4 fix the moment the previous one cleared, never auditing whether the spec itself needed restructuring.

In contrast, PR #216's three new gates (regression-guard / cross-lane / journey-probe) — installed mid-W3 in response to the Sponsor M2 RC soak — were a **deliberate retrospective pause** after a meta-finding. The team CAN do this kind of structural pause; AC4 just never triggered one because no single iteration was bad enough to surface the meta-pattern.

**Mitigation (new):** after N=3 consecutive AC4-cluster dispatches without spec-closure, **mandatory retrospective pause** before dispatch N+1. Priya owns the pause-trigger. Output: either "AC4 spec is correctly-shaped and we keep going" OR "AC4 spec needs restructuring; here's a smaller / different probe that would catch the same bug class with less cost." Codify in `risk-register.md` as a new entry (R-AC4 — see risk-register update this batch).

**Cost so far:** unmeasurable — the retro pause might have caught the misdiagnosis pattern (Gap 2) earlier and saved 2-4 iterations. Speculative.

### Gap 4 — Spec-string-vs-engine-emit drift: tests were decorative for multi-weeks (NEW 2026-05-16)

**Pattern:** Surfaced this session via PRs #248 + #249 (cross-author review at session-end). Two specs were silently no-op for multi-weeks despite passing CI green every run:

- **PR #248** — universal-warning-gate fixture checked `console.type === "warn"` but Playwright's `ConsoleMessage.type()` returns `"warning"` for `console.warn(...)` calls. The gate scaffolded by Tess in PR #217 was a no-op for warnings from the moment it shipped. Every `USER WARNING:` line that should have failed CI was silently swallowed.
- **PR #249** — `mob-self-engagement.spec.ts` (PR #215) regex matched `team=mob`. The engine's constants are `TEAM_ENEMY="enemy"` and `TEAM_FRIENDLY="friendly"` — the string `"mob"` is never emitted. The spec was wrong from inception; it has matched zero engine events since it shipped.

**Root cause:** Playwright specs assert on free-form trace strings without verifying the engine actually emits that exact string. No drift-pin mechanism exists to catch the mismatch. When a spec's regex never matches, the spec ASSERTS NOTHING — but Playwright reports it as green because no assertion failed. Silent-pass is indistinguishable from real-pass in CI output.

**Why this amplifies the AC4 cluster's cost:**

The AC4 spec is a meta-assertion built on top of sub-helper assertions (kiting-chase, mob-self-engagement, gate-traversal, clearRoomMobs). Each sub-helper has its own free-form trace assertions. **If any sub-helper has the same drift bug, AC4 was silently passing past it for weeks** — and the "next blocker" surfaced in each Drew dispatch was the next-real-bug after the silent-pass spec finally tripped on something it COULD see. Some of the surfacing-iteration cost is genuinely incremental discovery; some is the spec finally catching up to bugs that were always there but hidden behind drift-pass.

**Mitigation (new — Devon authored the doc § already):**

- **`.claude/docs/test-conventions.md` § "Spec-string-vs-engine-emit drift"** — Devon's doc update names the class and proposes a **drift-pin GUT pattern**. The GUT side asserts that the engine actually emits the string the spec depends on; if the engine constant changes (e.g., `"mob"` → `"enemy"`), the GUT test fails BEFORE Playwright silently passes.
- **Class-wide scan ticket** (new this session) — scan ALL existing Playwright specs against current engine constants. Estimated ~10-20 specs to audit; each ~30 min to verify the assertion-strings exist in engine code. Output: 0-N follow-up tickets for any silent-pass specs found.
- **Universal harness convention:** drift-pin GUT tests are mandatory for any Playwright spec asserting on a free-form engine-emit string. Codified in `team/tess-qa/playwright-harness-design.md`.

**Cost so far:** **multi-week test-infrastructure no-op.** Both PR #248's universal-warning-gate (since PR #217 — ~10 days) and PR #249's mob-self-engagement spec (since PR #215 — ~10 days) were green-by-default for ~2 weeks. Counted as agent-cycle waste: somewhat-difficult to estimate; ~2-4 PRs across the AC4 cluster may have been authored against the wrong "next blocker" because the spec was masking real bugs. The signal-cost is also material: every "green CI" during those weeks may have been hiding actual warnings + actual mob-engagement failures.

**This is the most concerning gap of the four** because it inverts the team's trust in CI. The other three gaps (sample-size, instrument-first, retrospective-pause) are mitigations against author judgment errors. Gap 4 is a mitigation against **CI itself silently lying**. Until the drift-pin pattern is universal across the spec corpus, no Playwright-green run is fully trustworthy — every untested-against-engine assertion-string is a latent silent-pass.

**Decision draft:** the class-wide scan is the load-bearing follow-up; ship as next Tess dispatch after the canary fix (which is itself a drift-pin-class fix). Add R-DRIFT to the risk register (this batch).

---

## §4 — What's NOT a gap (avoid victory-laundering these)

For honesty's sake — three things I considered as gaps but rejected on examination:

1. **"AC4 was scoped too aggressively."** Considered. Rejected. AC4 spec authoring was correctly scoped to "boss-clear from cold-boot through 8 rooms" — that's the M1 play-loop end-to-end test the project NEEDED. Scoping it smaller (e.g., "Room 03-clear only") would have hidden the very bugs AC4 caught. The spec is correctly-shaped.

2. **"Drew is the wrong owner."** Considered. Rejected. Drew has shipped 15+ kiting-mob-chase / room-traversal / position-steered-helper PRs (PR #186 / #190 / #198 / #212 / #221 / #224 etc.) — he is empirically the right owner. The misdiagnosis pattern is not Drew-specific; it's a team-wide discipline gap that any owner would hit without instrument-first discipline.

3. **"Tess should have caught the misdiagnoses in QA."** Considered. Rejected partially. Tess DID catch some (her PR #200 instrument work refuted PR #198; her PR #224 cross-room sweep surfaced `86c9uh2ue` / `86c9uh2kg`). She also missed some (Phase 2A migration shipped with red Playwright per PR #244, though that was the deliberate "casualties become tickets" decision). Net: Tess's QA discipline is good; the discipline gap is upstream (Self-Test Report sample size + instrument-first), not in the QA pass.

---

## §5 — What to do if AC4 keeps surfacing rooms

Forward-looking. The risk that worries me most:

**If Drew's instrument-first pass on Rooms 05/06/07 surfaces a fourth open blocker (Room 08 or Boss-room AC4 path), DO NOT dispatch the fourth iteration immediately.** Trigger the §3 Gap 3 retrospective pause:

- Priya authors a one-page audit of the AC4 spec: what surface is it probing, what bug classes has it caught, what bug classes is it now revealing, is the surface still well-shaped for the bug classes it's revealing.
- Possible outputs:
  - **"Keep going" verdict** — if the new blocker is qualitatively similar to prior ones (e.g., another physics-flush class or another harness-staleness class), continue dispatching. The probe is shaped correctly.
  - **"Restructure" verdict** — if the new blocker is in qualitatively different territory (e.g., Boss-room AI-state machine integration class), recommend a NEW spec scoped to that bug class instead of pushing AC4 deeper. AC4 might flip to `test()` at Room 07; the new bug class gets its own spec. The AC4 white whale "closes" by a scope-cut + a fresh-spec-for-the-rest pattern. **This is legitimate; it's not failure.**
  - **"Pause + harness redesign" verdict** — if the bug class reveals a deeper harness-side problem (e.g., the `latestPos` stale-trace pattern is more pervasive than the §4 mid-retro captured), trigger a harness-redesign ticket as the next dispatch, not another AC4 room fix.

The point of the §5 forward look is: **don't let the AC4 saga keep grinding past the point where the team should pause.** The current 3-open-blocker cluster is the natural test of this discipline. If Drew closes Rooms 05/06/07 cleanly with instrument-first and no further surprises, the discipline is working. If a fourth blocker surfaces, trigger the pause.

---

## §6 — Decision drafts (for next Priya weekly batch)

Per the new decisions-batching protocol (`team/priya-pl/decisions-batch-pr-template.md`):

- **Decision draft:** AC4 white-whale retro grades STRUCTURAL_GAP-leaning-MIXED (incremental discovery component is real; four structural gaps amplified it). Gap 1 (Self-Test sample size ≥8 for stochastic specs) codifies in `TESTING_BAR.md`. Gap 3 (mandatory retrospective pause after N=3 consecutive cluster dispatches) opens as risk-register entry R-AC4. Gap 4 (spec-string-vs-engine-emit drift) opens as risk-register entry R-DRIFT and is the most concerning of the four.
- **Decision draft:** `diagnostic-traces-before-hypothesized-fixes` memory rule is validated; pending dispatch-template.md addition to require explicit "instrument plan" line for AC4-cluster tickets.
- **Decision draft:** Drift-pin GUT pattern (per Devon's `.claude/docs/test-conventions.md` § addition in PR #249) is mandatory universal harness convention for any Playwright spec asserting on a free-form engine-emit string. Class-wide scan of existing Playwright specs against current engine constants is the next Tess dispatch after the canary fix.

These get batched into Priya's weekly Monday batch (per `team/DECISIONS.md` Append protocol).

---

## Cross-references

- `team/priya-pl/m2-week-3-mid-retro.md` § "Drew's latent bug class finding — `latestPos` stale-trace gotcha" (sibling pattern documented mid-W3).
- `team/priya-pl/risk-register.md` (R6 fired, R-AC4 to be added this batch).
- Memory `diagnostic-traces-before-hypothesized-fixes` (validated twice last session).
- Memory `product-vs-component-completeness` (AC4 spec is the integration probe — by design).
- `.claude/docs/combat-architecture.md` § "Third Known Case" (Class A vs Class B taxonomy from PR #247 saga).
- `team/tess-qa/playwright-harness-design.md` § 14 (staleness-bounded latestPos convention — PR #222).
