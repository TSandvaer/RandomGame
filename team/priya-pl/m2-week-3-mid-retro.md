# M2 Week-3 Mid-Week Retro

**Owner:** Priya · **Tick:** 2026-05-15 (mid-W3 — ~24h since W3 dispatch start at PR #202) · **Companion to:** `team/priya-pl/m2-week-2-retro.md`, `team/priya-pl/m2-week-3-backlog.md`, `team/priya-pl/risk-register.md`. **Not** an end-of-week retro — W3 is still in flight; this captures the inflection point.

## Verdict — mid-W3 is the inflection point, not the close

In ~24 hours since W3 dispatch start, **7 PRs merged + 4 PRs open** (11 PRs total in motion). That's a velocity number that beats W2's 22-PRs-in-7-days run on a per-day basis (~11 PRs/24h vs ~3 PRs/day in W2). But the substance of mid-W3 is not the velocity — it's the **first Sponsor M2 RC soak landing**, which surfaced 4 user-visible findings + 2 additional ALSO-found bugs from Drew's empirical work + 1 latent bug class. The team's institutional response to the soak (3 harness investments + 3 process gates installed in one PR) is the actual W3 mid-week story.

**This retro captures the meta-findings while the soak is still fresh.** The 5 M3-deferred bug classes are filed as parked watchlist tickets so they survive the M2 RC → M3 onset transition.

---

## 1 — What's changed since W3 kickoff (24h arc)

### Merged (7 PRs since PR #202 W3 kickoff)

- **#205** `feat(level): stratum-2 rooms 2-3 — s2_room02 (2 Stokers + 1 Charger) + s2_room03 (1+1+1 with boss_door port)` (Drew, W3-T2)
- **#206** `fix(combat): AC4 balance pass — chaser dmg trim + player iframes-on-hit per Uma #201` (Drew + Devon, W3-T1)
- **#207** `qa(integration): M2 W3 acceptance plan + paired GUT scaffolds` (Tess, W3-T10 Half A)
- **#208** `fix(harness|level): Room 05 gate unlock — dismiss auto-opened level-up panel + paired GUT pin` (Drew)
- **#209** `feat(content): MobRegistry autoload — stratum-aware mob lookup + scaling` (Devon, W3-T5)
- **#210** `design(audio)+source: M2 stratum-2 audio sourcing close-out — 3 cues` (Uma, W3-T9)
- **#211** `qa(infra): Playwright artifact-resolve SHA-pin — fail fast on no-match instead of silent latest-fallback` (Devon, W3-T11)

### Open at time of authoring (4 PRs)

- **#212** `fix(harness): Room 06 multi-mob return-to-spawn — extend PR #190 pattern` (Drew) — surfaces the Room 05 player-death recurrence as out-of-scope finding
- **#213** `design(m3-seeds): M3 framing — 4 sections incl. character-art pass milestone` (Priya, W3-T12 + Sponsor-promoted §4)
- **#214** `fix(level|content): boss-room loot single-pipeline + leather_vest direct-load` (Devon — Sponsor soak findings drain)
- **#216** `process(docs): three gates from M2 RC soak meta-finding — Regression-guard + Cross-lane integration + Tess RC journey-probe` (Priya — this PR's sibling)
- **#217** `qa(spec): universal console-warning zero-gate — Half A scaffold` (Tess — `86c9uf0mm`)
- **#215** `qa(spec): passive-player mob-self-engagement spec class` (Tess — `86c9uerk8`)

### Dramatic-acceleration framing

W2 shipped 22 PRs in ~7 days (~3.1 PRs/day). W3's first 24h shipped 7 merged + 4-6 open (~11 PRs in flight per 24h). The cadence is **~3-4x** W2's pace. Caveats:

1. **W3 is front-loaded.** W3-T2/T3/T5/T6/T9 were authored against an explicit dispatch-day-1 parallel-dispatch plan from the W3 backlog. The day-1 surge was expected; the velocity will moderate as L-sized tickets (W3-T4 S2 boss room) come online.
2. **Sponsor-soak drain pulled work forward.** 4 of the open PRs (#213, #214, #216, #217) are direct Sponsor-soak responses. They displaced lower-priority planned W3 work that's now deferred to W4 / M3.
3. **Some merges have shorter blast-radius.** PR #207 is a doc/scaffold (no runtime risk), PR #210 is asset-shipping (no Godot integration in this PR, deferred to W3-T9 follow-up `86c9uf6hh`), PR #211 is a CI yaml tweak. The "11 PRs" number isn't directly comparable to 11 W2-style runtime-touching PRs.

**The velocity is real, but the W3 close-state is not a function of velocity. It is a function of how Drew's Room 04 Shooter AI fix + the Room 05 player-death recurrence + Tess's 5-item queue all drain over the next 2-3 ticks.** See §7.

---

## 2 — AC4 white-whale status — per-room state table

AC4 (Playwright `ac4-boss-clear.spec.ts` cleanly clears all 8 rooms) has been the longest-running blocker in the project — **~2 months of effort across M1 close, M2 W1, M2 W2, and M2 W3**. Each iteration has surfaced a new failure shape; the current iteration is the closest the spec has been to all-green at the integration surface.

| Room | State | Last fix / blocker |
|------|-------|---------------------|
| Room 01 | ✓ deterministic | M1 close — onboarding flow gated on first-weapon pickup post-#194 |
| Room 02 | ✓ deterministic | PR #183 (W2) — MultiMobRoom gate-registration physics-flush defer |
| Room 03 | ✓ deterministic | Baseline since W2 |
| **Room 04** | ✗ **Shooter AI broken** (Sponsor finding `86c9uehaq`) | In flight — Drew |
| **Room 05** | ✗ **flaky** — Player death recurrence (`86c9uf1x8`) | Filed pending owner — PR #208's 3/3 evidence didn't reproduce; ~80% Player-death rate in release-build AC4 retest |
| Room 06 | ✓ FIXED (mid-W3) | PR #212 in flight — extends PR #190 return-to-spawn pattern |
| **Room 07** | ✗ same Shooter AI bug | Same root cause as Room 04 — Sponsor finding observed in both rooms |
| Room 08 / boss | ✗ boss-room loot broken (`86c9uemdg`) | PR #214 in flight — Devon |

**What's needed to flip AC4 to green:**

1. **`86c9uehaq`** — Drew's Room 04 Shooter AI fix. The Shooter currently only flees, never engages; cornered = idle; out-of-range = no pursuit. Affects Rooms 04 + 07 (same mob class). Diagnose-first per `diagnostic-traces-before-hypothesized-fixes` — add `[combat-trace]` instrumentation to `Shooter.gd` state transitions before applying any state-machine fix.
2. **`86c9uf1x8`** — Room 05 player-death recurrence. PR #208 (Drew, `86c9u6uhg`) reported 3/3 deterministic clears but empirical retest during PR #212 reproduction shows ~80% Player-death rate. The multi-chaser stationary-engage strategy (30 ms facing tap + 6 click-spam swings = ~1.3 s station) holds the player in melee range while concurrent chargers deal damage faster than the iron sword clears them. **PR #208's evidence was a lucky-roll sample, not a deterministic fix.**

**Two-month effort context.** The AC4 spec has gone through these epochs:

- **M1 close** — Spec authored as `test.fail()` annotated blocker after Room 02 wouldn't open.
- **M2 W1** — Room 02 unblocked via PR #183 physics-flush defer; spec advanced to Room 04.
- **M2 W2** — Room 04 chase mechanic (PR #186), chase return-to-spawn (PR #190), Room 05 mob-freeze fix (PR #191), harness position-steered multi-chaser clear (PR #198), diagnostic-trace pair (PR #200) empirically refuted the freeze framing. Spec reached Room 05 cleanly.
- **M2 W3** — Uma's #201 balance design locked; PR #206 shipped Grunt 3→2 / Charger 5→4 / Player iframes 0.25s; PR #208 attempted Room 05 panel-dismiss fix. AC4 should have closed — but the Sponsor RC soak surfaced the underlying Shooter AI bug (which the harness had been hiding by driving the player TO the Shooter) AND the Room 05 player-death recurrence (which PR #208 didn't actually fix).

**The pattern across the two-month arc:** every spec-level fix has revealed a deeper game-side bug. The AC4 spec is acting as an **empirical bug-discovery surface**, not a regression guard. The "white whale" is whether AC4 can land green and stay green for one full week without the harness drift accumulating again. **Honest framing:** AC4 has been ~3 dispatches away from green for two months; this iteration is one of them.

---

## 3 — Sponsor M2 RC soak retrospective

Sponsor performed the first M2 RC interactive soak on 2026-05-15 against `embergrave-html5-5bef197` (run 25923464662). The soak surfaced **4 user-visible findings**, **2 additional ALSO-found bugs** from Drew's empirical retest work, and **1 latent bug class** identified through cross-PR analysis.

### 4 Sponsor findings (direct surface)

| ID | Sponsor verbatim | Severity | Owner | State |
|----|-------------------|----------|-------|-------|
| `86c9uehaq` | "room4: mob only fleeing, never chasing player, shoots from distance not able to reach the player. if back into a corner, doesnt attack when user is too close and doesnt try to reach when to far to attack." | P0 (gameplay blocker) | Drew | in progress |
| `86c9uemdg` | "boss room 8 cannot loot dropped items" | P0 (M2 RC progression gate) | Devon | ready for QA (PR #214) |
| `86c9uen3z` | `USER WARNING: ItemInstance.from_save_dict: unknown item id 'leather_vest'` | P1 (unsettling, likely related to `86c9uemdg`) | Devon | ready for QA (PR #214 folded) |
| `86c9uepzm` | "when do we replace placeholder square art with actual graphics" | P1 (roadmap question — promoted W3-T12 from P2 to P1) | Priya | in progress (PR #213) |

### 2 ALSO-found bugs (Drew empirical retest)

- **`86c9uf1x8`** — Room 05 player-death recurrence (PR #208 didn't actually fix; ~80% Player-death rate in release-build AC4 retest). Surfaced during PR #212 reproduction work. Empirically falsified PR #208's "3/3 deterministic" Self-Test claim.
- **Sponsor's Room 04 Shooter AI bug ALSO observed in Room 07** — same `Shooter.gd` state-machine pattern. Single root cause affects two rooms simultaneously. Filed as part of `86c9uehaq` Acceptance.

### 1 latent bug class

- **Stale-trace `latestPos` consumers across harness helpers.** Surfaced during Drew's PR #212 investigation. See §4 below for the full diagnosis-via-trace narrative.

### Sponsor's verbatim framing

> "i want this to work without my involvement"

The directive is a structural one: the Sponsor's interactive soak should validate **feel**, not **bug existence**. When 4 user-visible bugs surface in a 30-minute soak, the soak is functioning as the bug-discovery surface — not as the sign-off surface. The team's gates were green (CI green, Tess sign-off on each individual PR), but the **journey was untested**. Sponsor became the only journey-scoped tester by default.

### investigate-skill consolidator output — 3 harness investments + 3 process gaps

The investigate-skill spawned 3 parallel Sonnet agents to dissect the soak findings from three angles (root-cause / alternative-hypotheses / broader-context); the consolidator synthesized:

**3 harness investments (filed for W3, all P0):**

1. **`86c9uf0mm`** — Universal console-warning zero-gate. `ConsoleCapture.getLinesByType("warn")` exists at `tests/playwright/fixtures/console-capture.ts:83-86` and is NEVER called for the `warn` type anywhere in the spec corpus. A 10-line Playwright `afterEach` hook would have caught `86c9uen3z` (leather_vest unknown-id warning) on the first spec post-bug. Sequencing: dispatch AFTER Devon's `86c9uen3z` fix merges, otherwise the new gate immediately turns every spec RED. **Tess Half A scaffold landed (PR #217 open).**
2. **`86c9uf0r5`** — Physics-flush smoke for `Stratum2BossRoom` (preemptive mirror of S1 `86c9tv8uf` fix). Anticipates the W3-T4 Vault-Forged Stoker room repeating the S1 boss room's latent physics-flush bug class. Ships as `test.fail()` stub ahead of W3-T4 dispatch — a guard before the code exists. Status: parked `to do` (P0, awaiting Tess capacity).
3. **`86c9uf0w8`** — Process-docs triple. **Already shipped as PR #216 open** — see §5 below.

**3 process gaps (codified as gates):**

The Sponsor-soak findings would have been caught by 3 missing gates. Each gate maps to one Sponsor finding:

1. **No Regression-guard discipline** → all 4 findings were regressions in surfaces that had previously been tested by component-scoped tests; none had system-scoped regression guards.
2. **No Cross-lane integration check in Self-Test Reports** → the Shooter AI + boss-room loot bugs are cross-PR/cross-lane failures. Each PR's Self-Test Report accurately described what THAT PR's author verified — but no report cross-checked adjacent-lane state.
3. **No Tess journey-probe at RC boundary** → no Tess gate currently runs end-to-end. Sponsor became the journey-scoped tester by default. All 4 findings would have surfaced in a 15-minute Tess probe before RC handoff.

All three gates installed via PR #216 (see §5).

---

## 4 — Drew's latent bug class finding — `latestPos` stale-trace gotcha

While reproducing the Room 06 chase-pre-pass failure, Drew identified a latent bug class spanning multiple Playwright harness helpers: **stale-trace `latestPos` / `dist_to_player` consumers**.

### The empirical observation

The Playwright harness's `chase` helper reads the mob's position trace (emitted from Godot's `_physics_process`) to decide when the player avatar is "in chase range" of the mob. Drew observed the harness asserting "Shooter chase pre-pass complete" when the Shooter was still alive — the harness was reading a **stale** `latestPos` trace from before the chase began. The trace stream was correct; the harness's read-pattern was wrong.

### **Important framing: the ticket diagnosis was empirically wrong; reproduction-with-trace overturned the framing**

Per memory `diagnostic-traces-before-hypothesized-fixes`: the original PR #212 ticket diagnosed the Room 06 stuck-pursuit as "the chase pre-pass needs a different return-to-spawn pattern." Drew's reproduction work with traces showed the actual cause: a stale `mob.dist_to_player` field that the harness was treating as live. The hypothesized fix (return-to-spawn pattern extension) would have been a **band-aid that masks the trace-staleness root cause**.

This is the second time in the M2 W2-W3 arc that diagnostic-trace reproduction has overturned a hypothesized fix:

- **PR #200 (W2)** — Empirically refuted PR #198's "Room 05 chasers must be unwinnable" framing. The actual cause was a physics-flush race between `gate_traversed` and the next-room load, fixed in PR #191 — the harness change was complementary, not corrective.
- **PR #212 (W3 mid)** — Empirically refuted PR #212-as-originally-scoped "Room 06 needs return-to-spawn extension." The actual cause was a stale `latestPos` consumer pattern that affects ALL future harness helpers reading mob position traces.

**This pattern (diagnosis-via-trace, not diagnosis-via-hypothesis) is hardening into a repeatable discipline.** It is now cited in three memory rules:

- `diagnostic-traces-before-hypothesized-fixes` — the primary rule
- `agent-verify-evidence` — the parent rule (always check actual evidence before asserting impossibility)
- `product-vs-component-completeness` — "components pass tests; products integrate" — the failure mode is the same shape (the component test was green; the integrated trace stream told a different story)

### Implications for ALL future harness helpers reading mob position traces

Any helper that reads `latestPos`, `dist_to_player`, `mob.state`, or any other position/state trace **must** establish a freshness guarantee before consuming the value. Candidates:

1. **Sentinel-event pattern** — wait for a sentinel trace ("chase_started", "pursuit_engaged", etc.) before reading downstream state.
2. **Timestamp-bracket pattern** — read the trace's emit-timestamp and reject reads older than ~50 ms (one physics frame at 60 Hz with 3× safety margin).
3. **Read-from-frame pattern** — buffer traces by physics frame number and only consume traces from the current frame or later.

The fix shape for the specific PR #212 bug is harness-side (a small read-pattern change in `chaseAndClearKitingMobs`). The broader investment — codifying the freshness-guarantee pattern in `team/tess-qa/playwright-harness-design.md` — is parked as a **M3 watchlist** ticket (see §"M3 watchlist tickets filed" below — qa(harness): mob-side AI-state trace assertions).

---

## 5 — Process changes installed — PR #216's three gates

The investigate-skill consolidator's "3 process gaps" output became one PR: **#216 `process(docs): three gates from M2 RC soak meta-finding`** (Priya, `86c9uf0w8`). The PR installs three new gates that change every future dispatch shape structurally.

### Gate 1 — Regression guard (dispatch-template.md addition)

New mandatory line in the dispatch-template "Done clause" block:

> **Regression guard:** Name at least one test (GUT or Playwright spec) that would fail if this feature broke in a future unrelated PR. If none exists, add it in this PR.

**Why this changes things:** every dispatch will now produce a named, durable regression surface — not just "paired tests for this PR's logic." All 4 Sponsor soak findings were regressions in surfaces that had previously been tested by component-scoped tests; none had system-scoped regression guards. The Regression-guard line forces dispatch authors to think "if this breaks in 3 weeks, what catches it?" instead of "what tests prove this works today?"

### Gate 2 — Cross-lane integration check (GIT_PROTOCOL.md Self-Test Report addition)

New mandatory subsection in the Self-Test Report's "Side-effect inventory":

> **Cross-lane integration check:** List every other role's feature that shares state with this PR (e.g. Inventory + Pickup + Room gate + Loot for any combat PR). Describe what you probed and what you observed. If you cannot probe cross-lane state (no browser, headless only), name it explicitly as a Sponsor-soak probe target so the orchestrator can route it to Tess's journey-probe.

**Why this changes things:** the Shooter AI + boss-room loot bugs are cross-PR/cross-lane failures. Each PR's Self-Test Report accurately described what THAT PR's author verified — but no report cross-checked adjacent-lane state. The cross-lane line forces dispatch authors to think about what other systems share state with this PR's changes, and to either probe them OR explicitly name them as Tess-journey-probe targets. **Sponsor-soak coverage** becomes a routable artifact, not an implicit catch-all.

### Gate 3 — Tess milestone-gate journey probe (TESTING_BAR.md addition)

New mandatory gate in the testing bar:

> **Milestone-gate journey probe (mandatory at RC boundary):** Before any build is handed to Sponsor for soak, Tess runs ONE complete player journey — boot → Room01 → S1 traverse → boss → loot pickup → save → quit → reload → resume — and logs the result in the soak doc. Any console push_warning is a blocker (referenced by `86c9uf0mm` universal console-warning zero-gate). Any item-id that doesn't resolve is a blocker. Any missing/un-collectable loot is a blocker.

**Why this changes things STRUCTURALLY:** no Tess gate currently runs end-to-end. Sponsor became the only journey-scoped tester by default. All 4 findings would have surfaced in this 15-minute probe.

The journey probe is the **structural complement** to the per-ticket coverage. It is the first Tess-side journey-scoped gate before Sponsor sees the build. It does NOT replace Sponsor-soak (Sponsor remains the soak-feel gate); it replaces Sponsor-as-bug-discovery-surface.

### What this changes for future Sponsor soaks

The next M2 RC handoff to Sponsor will:

1. Pass through a Tess journey-probe artifact (`team/tess-qa/journey-probe-<date>.md`) before the artifact link goes to Sponsor.
2. Carry a "Cross-lane integration check" inventory on every UX-visible PR that landed in the RC arc — making cross-lane risk visible at dispatch time, not discovery time.
3. Have a named Regression guard test for every shipped feature — so if a future PR breaks Room 04 Shooter AI again, the test fails immediately, not three weeks later when Sponsor next soaks.

**The collective effect:** Sponsor-soak shifts from bug-discovery to feel-validation. Whether that's enough to prevent the next surprise depends on how rigorously the gates land in dispatch briefs over the next 2-3 ticks.

---

## 6 — Risk register update

### R6 — Sponsor-found-bugs flood — FIRED

- **Probability:** high (held — was already high)
- **Impact:** high (held — was already high)
- **Bump:** R6 has gone from a forecast to an actively-firing risk. **6 findings in one soak** (4 direct + 2 also-found) is the largest single-soak finding density in project history. The previous calibration data point was M1 RC's 2 P0s in 10 minutes — that was 0.2 findings/minute, this is 0.2 findings/minute as well (~30 min soak), so the **density** is constant; what's different is the **breadth**: the M1 soak found 2 issues both in combat-feel; the M2 soak found issues across combat (Room 04 AI), level (boss room loot), save (leather_vest), and art-direction (placeholder squares). The risk has materialized in a wider surface than the calibration data predicted.
- **Watch signal:** continues to fire on every Sponsor soak. Sponsor's next M2 RC retest after PR #214 + PR #216 lands is the next data point.
- **Mitigation:** PR #216's three gates structurally change the next Sponsor-soak handoff. W3-T10 absorber is sized for ≥3 P0s — currently absorbing 2 P0s + 2 P1s + 1 latent class (well within sizing).

### R2 — Tess bottleneck — strained

- **Probability:** med (held — strained but not breaking)
- **Impact:** med (held)
- **W3 mid status:** Tess's queue at time of authoring is **5 items**: (1) PR #215 universal warning gate review, (2) PR #217 mob-self-engagement spec review, (3) `86c9uf0r5` S2 boss room physics-flush smoke authoring, (4) W3-T6 v4 save stress fixtures, (5) end-of-W3 bug-bash absorber + journey-probe artifact for the next M2 RC. The queue is bigger than W2's mid-week strain (which was 2-3 items). The **new** load source is PR #216's Tess RC journey-probe gate — Tess now owns a ~15-min journey-probe per RC handoff in addition to per-PR sign-offs.
- **Watch signal:** queue depth ≥6 sustained across two heartbeat ticks; QA round count per PR rising above 1.5 average. **Currently at 5/queue, 1.0 average round count.**
- **Mitigation:** PR #216's "Cross-lane integration check" routes more state-probe work to dispatch authors (rather than to Tess) — should reduce Tess's cross-lane load. PR #216's "Regression guard" line shifts test-authoring work to dispatch authors too. Net effect: Tess's role narrows toward journey-scoped probing + sign-off, away from cross-lane probing. Expected reduction in Tess load: ~20-30% per dispatch, conservatively.

### R1 — Save migration breakage — held (re-armed in W3 entry)

- **Probability:** med (held)
- **Impact:** high (held)
- **W3 mid status:** the `86c9uen3z` leather_vest unknown-id warning is a save-migration smell — fires on save-load at boot. PR #214 is folding the fix into the boss-loot pipeline work; the underlying question is whether `leather_vest` should exist (re-add to registry) or be deprecated (add old→new id mapping). If the latter, **R1 fires at the M2 RC handoff for any pre-M2 save that contained `leather_vest`.** W3-T6 v4 stress fixtures will land paired tests covering INV-1..INV-8 from `save-schema-v4-plan.md`.

### R11 — Integration-stub-shipped-as-feature-complete — HELD BUT EVOLVED

R11 is **held** in name — no new integration-stub-class incident has fired since M1. But the underlying class of risk has evolved into a broader meta-pattern: **PR-scoped vs journey-scoped failures.**

R11's original framing was "components pass tests; products integrate" — `Main.tscn` shipped as a week-1 boot stub through 30+ "feature-complete" PRs. The current shape of the failure has shifted: it's no longer about whether the component is wired into `Main.tscn`; it's about whether the component works **in the player's actual journey** alongside the other components that share state with it. PR #194's bandaid retirement was integration-correct (the equip path was wired into the play surface); the **interaction** between PR #194 and the pickup-spawn path surfaced the silent-drop bug, which only fires in mid-run play. Same shape for the Sponsor soak findings — each component (Shooter AI, boss-loot, save-load) was tested; the **journey** linking them was untested.

**Priya's call:** **keep R11 as named**, but document its evolved form in the register's "evidence" column on next risk-register refresh. The original framing still applies (Main.tscn-stub class is the load-bearing precedent); the new framing (PR-scoped vs journey-scoped) is captured by PR #216's three gates as the codified countermeasure.

Renaming would lose the M1 precedent's institutional context. Adding a new R-number (R13?) would over-specialize. The right move is: R11 = "components pass tests; products integrate; this includes journey integration, not just scene-tree integration."

### Re-promoted to watch from top-3

- **R9 — Stratum-2 content triple-stack** — held at top-5 entry; Drew's W3 load was heaviest of M2 (T2+T3+T4 stacked). Mid-W3, T2 has landed (PR #205), T3 is parked (sprite work), T4 (S2 boss room L) is parked pending T3. Drew is currently absorbed by Sponsor-soak Room 04 fix + Room 05 recurrence. The triple-stack risk has materialized as expected; the mitigation (parallel-dispatch Devon on T1/T5) held; the load is bearable.

---

## 7 — Pending work to W3 close

### In flight at time of authoring

| Owner | Work | ETA |
|-------|------|-----|
| Drew | `86c9uehaq` Room 04 Shooter AI fix (P0 — gates AC4 white whale flip) | 2-3 ticks |
| Drew (queue) | `86c9uf1x8` Room 05 player-death recurrence (P1 — gates AC4 too) | 2-3 ticks after Room 04 |
| Devon | `86c9uf6hh` S2 audio wiring (W3-T9 follow-up — `default_bus_layout.tres` + S2 entry triggers) | 2-3 ticks |
| Devon (queue) | PR #214 boss-room loot + leather_vest fix (P0) | nearing sign-off |
| Tess | Queue of 5 — PR #215/#217 reviews + `86c9uf0r5` S2 boss physics-flush smoke + W3-T6 v4 save stress fixtures + journey-probe artifact for next RC | rolling 2-4 ticks |
| Uma | Vault-Forged Stoker visual-direction prep (`86c9uf86n` just dispatched — W3-T4 design support) | 1-2 ticks |
| Priya | PR #213 M3 design seeds + PR #216 process gates + this retro (PR forthcoming) | mid-W3 closing |

### Deferred to W4 / M3

- **W3-T4 S2 boss room first impl** (Vault-Forged Stoker, L) — parked pending Drew's Room 04 + 05 drain. Likely **W4 dispatch**, not W3 close.
- **W3-T7 stash UI iteration v1.1** + **W3-T8 ember-bag tuning v2** — Sponsor-conditional; no Sponsor signal on these specific surfaces from the M2 RC soak. Defer to W4 if no signal lands.
- **5 M3 watchlist bug classes** (filed as parked ClickUp tickets — see §"M3 watchlist tickets filed").

### Deferred to M3 — the 5 watchlist classes

These 5 bug classes are deferred to M3 per the investigate-skill consolidator output. Each is filed as a parked ClickUp ticket (`status: to do`, `priority: low`, `tags: m3 + qa`). See §"M3 watchlist tickets filed" for the ticket IDs.

1. **Visual-fidelity Tier-2 — Playwright screenshot snapshot baseline** — no current visual regression coverage; would catch a future "the equipped-glyph went tofu again" before Sponsor.
2. **Audio HTML5 Web Audio decoder smoke** — once W3-T9 audio wiring lands, no harness verifies HTML5 audio playback actually works post-build; would catch decoder regressions before Sponsor.
3. **Tab-blur / browser-lifecycle Playwright probe** — current AC4 spec doesn't model the player tab-blurring mid-combat; Sponsor's actual play patterns include alt-tab.
4. **RNG drop-rate distribution test** — affix-balance pin asserts distribution shape but no test sweeps RNG to confirm; theoretical 1-in-10k bug class.
5. **Mob-side AI-state trace assertions** — the broader codification of §4's stale-trace finding. Codify the freshness-guarantee pattern in `team/tess-qa/playwright-harness-design.md` and add mob-side AI-state traces to the trace-stream (currently only player-side events are reliably traced).

---

## 8 — W3 (so far) grade

**Mid-W3 grade: B+.**

W2 closed at C+ for planning-quality. Mid-W3 grades higher on three axes:

1. **Velocity is up 3-4x per-day.** 7 merged + 6 open in 24h is the highest cadence the project has hit. Caveat: front-loaded by W3 day-1 parallel-dispatch + Sponsor-soak drain.
2. **Institutional response to Sponsor soak is unprecedented.** The investigate-skill consolidator output → 3 harness investments + 3 process gates installed → 1 PR (#216) captures all three gates → DECISIONS.md append → memory-rule alignment, all within ~6 hours of the Sponsor soak landing. This is the fastest "soak finding → codified countermeasure" cycle the project has run.
3. **AC4 white whale is not closed.** ~2 months of effort, mid-W3 has the spec ~3 dispatches away from green — same status as 2 weeks ago. The deeper issue (Shooter AI was hidden by the harness that drove the player TO the Shooter) is a **game-side** bug, not a harness bug; the W3 fix surface is on Drew's plate. **Until AC4 lands green and stays green for a week, the white whale grade is incomplete.**

**The honest grade is B+, not A-.** The velocity + soak-response are exceptional; AC4 + Tess queue depth are still bearable but straining. The W3 close grade depends on:

- Whether Drew's Room 04 Shooter AI fix lands and the Room 05 player-death recurrence resolves in the next 2-3 ticks.
- Whether PR #216's three gates land cleanly without rework — and whether the next M2 RC handoff actually carries a journey-probe artifact.
- Whether Tess's 5-item queue drains without backing up further.

**Watch signal for W3 close grade:** does AC4 land green within W3? If yes → A-. If carried to W4 → B+. If carried to M3 → B.

---

## 9 — M3 watchlist tickets filed

Per §7 "Deferred to M3 — the 5 watchlist classes," 5 ClickUp tickets are filed in this PR's dispatch round. Each is `status: to do`, `priority: low`, `tags: m3 + qa`. The ticket IDs are listed in this PR's body.

1. **`qa(spec): visual-fidelity Tier-2 — Playwright screenshot snapshot baseline (M3)`**
2. **`qa(spec): audio HTML5 Web Audio decoder smoke (M3)`**
3. **`qa(spec): tab-blur / browser-lifecycle Playwright probe (M3)`**
4. **`qa(spec): RNG drop-rate distribution test (M3)`**
5. **`qa(harness): mob-side AI-state trace assertions — harness-behavior constraint (M3, larger refactor)`**

These tickets exist as **tracker rows** so the 5 bug classes don't disappear from institutional memory between M2 RC sign-off and M3 kickoff. They are not in scope for the rest of W3 or W4.

---

## 10 — Decisions / escalations

**None requiring Sponsor escalation.** Mid-W3 retro is a Priya-authority document.

**Internal decisions captured in DECISIONS.md (one-line append per dispatch instruction):**

- M2 W3 mid-retro captures Sponsor soak meta-findings; 5 M3 watchlist tickets parked.

**Soft asks for the orchestrator:**

1. **When PR #216 lands**, audit the next 3-5 dispatch briefs for actual adoption of the Regression-guard + Cross-lane integration check lines. New rules only hold if the next dispatch enforces them; the first 3-5 dispatches post-#216 are the calibration data.
2. **When Drew's Room 04 fix lands**, parallel-dispatch the Tess regression guard for Shooter AI state transitions as a paired test, NOT a follow-up Tess dispatch. The Regression-guard rule from PR #216 requires it.
3. **Before the next M2 RC handoff to Sponsor**, ensure Tess produces a `journey-probe-<date>.md` artifact per PR #216's gate 3. If no journey-probe artifact exists, the RC is not ready for Sponsor.

---

## 11 — Cross-references

- **W2 retro:** `team/priya-pl/m2-week-2-retro.md` — the structural template for this retro + the prior W2 risk-register update
- **W3 backlog:** `team/priya-pl/m2-week-3-backlog.md` (v1.0 at W3 entry — revision pending; will document the deferral of W3-T4 to W4 + W3-T7/T8 conditional outcomes at W3 close)
- **W3 acceptance plan:** `team/tess-qa/m2-acceptance-plan-week-3.md` (PR #207)
- **Risk register (full):** `team/priya-pl/risk-register.md`
- **Process-incident log:** `team/log/process-incidents.md`
- **Sponsor M2 RC soak transcript:** captured in the 6 ClickUp tickets `86c9uehaq` / `86c9uemdg` / `86c9uen3z` / `86c9uepzm` + `86c9uf1x8` (also-found) + Drew's PR #212 body
- **investigate-skill consolidator output:** referenced in `86c9uf0mm` / `86c9uf0r5` / `86c9uf0w8` ticket bodies + PR #216 body
- **PR #216 (the process-gates installation):** `process(docs): three gates from M2 RC soak meta-finding`
- **Architecture docs (auto-loaded):** `.claude/docs/combat-architecture.md`, `.claude/docs/html5-export.md`, `.claude/docs/orchestration-overview.md`
- **Memory rules** (load-bearing for mid-W3): `diagnostic-traces-before-hypothesized-fixes`, `agent-verify-evidence`, `product-vs-component-completeness`, `self-test-report-gate`, `html5-visual-verification-gate`, `clickup-status-as-hard-gate`, `always-parallel-dispatch`
