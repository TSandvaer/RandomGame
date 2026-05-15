# M2 Week-2 Retro

**Owner:** Priya · **Tick:** 2026-05-15 (M2 W2 closes CLEAN) · **Companion to:** `team/priya-pl/m2-week-2-backlog.md`, `team/priya-pl/risk-register.md`. Feeds `team/priya-pl/m2-week-3-backlog.md`.

## Verdict — W2 closes clean

Tess's end-of-week-2 exploratory bug-bash (`team/tess-qa/soak-2026-05-15.md`, ticket `86c9kxx7h`) against `embergrave-html5-d9cc159` returned **0 blockers, 0 majors, 2 minors**. Both minors are already addressed: `86c9u33h1` (pickup silent-drop on full grid) shipped in PR #199, and `86c9u33hh` (stale AC4 `test.fail()` annotation) is the next-tick AC4 Room-05 balance-pass work (already authorized; Uma in flight on the design).

Throughput: **22 PRs merged on `main`** between the W2 dispatch start (post-PR #175 housekeeping) and the close-out tip at `3d614a6` (PR #200). Against the W2 backlog target of 12 tickets, this is a **+10 over** in absolute PR count — though the shape was different from what the W2 backlog anticipated (more AC4-progression and combat-trace coverage; less stratum-2 content). See §"Capacity check actual vs target" for the alignment.

The team shipped the largest M2 batch to date with no soak-stopper findings. The W2 RC (`d9cc159`) is the Sponsor-soak target for W3 entry.

---

## What shipped — PR arc by track

The 22 PRs grouped by track. Numbers in parens are the merge order; the full list is `git log --merges origin/main` between the W2 dispatch start and `3d614a6`.

### Track 1 — AC4 boss-clear progression (6 PRs)

The bulk of the AC4 work: getting the Playwright spec from `test.fail()` to a deterministic green clear of all multi-mob rooms.

- **#183** `fix(level): MultiMobRoom gate-registration` — Room 02 Area2D physics-flush defer; the load-bearing first-room blocker.
- **#186** `fix(harness): clearRoomMobs Shooter-aware chase-then-return sub-helper` — Room 04 chase mechanic the harness needed to clear the kiting Shooter.
- **#190** `fix(harness): chaseAndClearKitingMobs return-to-spawn` — Room 04 determinism; the chase helper needed to leave the player at a known position so subsequent walks (post-combat gate-traversal) hit reliable geometry.
- **#191** `fix(level): Room 05 3-concurrent-chaser mob-freeze` — `CONNECT_DEFERRED` on `gate_traversed → next-room load` defers room-transition out of the physics-flush window. **The highest-leverage physics-flush fix this week.**
- **#198** `fix(harness): clearRoomMobs position-steered multi-chaser clear` — Room 05+ deterministic via position-steered aim sweeps. Allowed AC4 spec to reach Room 06 cleanly.
- **#200** `fix(diag): Player._die + Main.apply_death_rule combat-trace lines` — diagnostic-trace pair pattern that empirically refuted #198's "Room 05 chasers must be unwinnable" framing. See "Lessons learned" §3.

### Track 2 — Inventory bandaid retirement (2 PRs)

- **#194** `chore(inventory): retire PR #146 iron_sword bandaid — auto-equip first weapon on pickup` — **23-file coordinated change**. Removed the `equip_starter_weapon_if_needed` boot-time auto-equip and replaced it with pickup-driven auto-equip. The largest behavioural change in W2: cold-boot is now genuinely fistless, equip happens via gameplay, Room01 onboarding flow gates room-advance on the first-weapon pickup.
- **#199** `fix(inventory): Pickup no silent-drop when grid is full` — patched a latent item-loss bug surfaced by Tess's bug-bash on #194. `Pickup.queue_free` ran before `Inventory.add()` could fail; now waits for `add()` success.

### Track 3 — Combat-trace coverage (4 PRs)

Closes long-standing diagnostic gaps so future negative-assertion specs have the traces they need:

- **#177** `infra(combat-trace): TutorialEventBus.request_beat trace line`
- **#182** `infra(combat-trace): Charger._die + Shooter._die trace lines`
- **#192** `infra(combat-trace): Charger.take_damage + Shooter.take_damage trace lines`
- **#195** `infra(combat-trace): Charger/Shooter take_damage IGNORED already_dead trace` — the rejection-path coverage that completes the per-mob death-event trace family.

### Track 4 — Polish / UX (2 PRs)

- **#176** `design(ux): color-blind secondary cue for equipped distinction` (Uma design spec)
- **#179** `feat(ui): color-blind secondary cue for equipped distinction — ✓ EQUIPPED glyph` (Devon impl). Caught and fixed the `gl_compatibility` U+2713 tofu-rendering bug during Self-Test Report — final ship draws the glyph as `ColorRect` geometry, not a Unicode codepoint. See "Lessons learned" §4.

### Track 5 — Infra / CI / harness (5 PRs)

- **#178** `bug(ci): playwright-e2e.yml artifact extract — handle both zip + pre-unzipped formats`
- **#180** `bug(e2e): negative-assertion-sweep Test 2 — scope RoomGate check to Room01 window` — buffer-scoping discipline for negative assertions; codified the sentinel-event sub-buffer pattern (see `.claude/docs/combat-architecture.md` § "Negative-assertion buffer-scoping rule").
- **#181** `chore(harness): durable auto-status — SessionStart re-arm hook` — harness durability across session restarts.
- **#187** `fix(harness): equip-flow Phase 2.5 swing-after-Tab race` — focus-consumption discovery (see "Lessons learned" §5).
- **#188** `chore(repo): gitignore hygiene — diag-build/ + untrack committed-then-ignored test artifacts`
- **#196** `fix(ci): fail GUT job on parse-failed test files` — closes a testing-bar integrity hole (see "Lessons learned" §2).

### Track 6 — Level / physics-flush family (3 PRs)

Continuing harmonization of the physics-flush rule across the codebase:

- **#184** `fix(level): Stratum1BossRoom door-trigger — defer Area2D insert out of physics-flush window` — closes the harmonization gap called out in `.claude/docs/combat-architecture.md` § "Hitbox + Projectile encapsulated-monitoring rule" (ticket `86c9p1fgf`).
- **#193** `docs(level): Stratum1Room01 death-reload flush path — audited safe` — proactive audit; documented why this path doesn't need a defer fix.
- **#197** `qa(test): per-swing Hitbox monitoring assertion in sustained-swing-spam test` — regression guard for the encapsulated-monitoring pattern.

### Track 7 — AC4 spec annotation (1 PR)

- **#185** `qa(e2e): AC4 spec re-arm — re-point test.fail() blocker comment post-#183` — annotation maintenance.

### Tracks not represented in W2 actuals

- **Stratum-2 content** (W2-T1 / W2-T2 / W2-T3 from the W2 backlog) — **0 PRs shipped**. The work shifted into W3 (see W3 backlog).
- **MobRegistry refactor** (W2-T4) — **0 PRs shipped**. Carried to W3.
- **v4 save stress fixtures** (W2-T5) — **0 PRs shipped**. Carried to W3.
- **Stash UI iteration** (W2-T7) / **Ember-bag tuning** (W2-T8) / **Audio sourcing close-out** (W2-T9) — **0 PRs shipped**. Carried to W3 (audio) or de-scoped pending Sponsor signal (stash / ember-bag — no Sponsor soak has fired yet against M2).
- **M3 design seeds** (W2-T12) — **0 PRs shipped**. Carried to W3.

The W2 actual shape was **playability close-out and harness completion**, not stratum-2 content authoring. AC4 progression + inventory + combat-trace coverage + infra hardening absorbed the full week. See §"Capacity check actual vs target" for the implications.

---

## What bounced or slipped — the patterns, not just the events

### Pattern 1 — Bandaid retirement exposes latent bugs the bandaid was masking

PR #194 (`feat(inventory): retire PR #146 iron_sword bandaid → auto-equip first weapon on pickup`) **bounced once on CI** with a parse-failed test file that GUT's green exit code masked (see §"Lessons learned" §2). On the retest after Tess's full bug-bash, it surfaced **two latent bugs** the bandaid had been hiding:

1. **Unreachable dummy-drop pickup** — the PracticeDummy in Room01 didn't actually drop the iron_sword Pickup correctly; the bandaid had been auto-equipping the sword before the dummy-drop path could run. PR #194 fixed this in the same coordinated 23-file change.
2. **Pickup silent-drop on full grid** — `Pickup` `queue_free`d before `Inventory.add()` could fail/succeed; with the bandaid in place this never mattered because the grid was empty at boot. With pickup-driven equip, mid-run pickups with a full grid silently destroyed items. **Filed `86c9u33h1` → shipped as PR #199.**

**Generalization:** when retiring a bandaid that masks a class of behaviour, the bug-bash *after* the retirement is the load-bearing safety net. The bandaid's existence implies a known-fragile path; removing it surfaces every adjacent assumption. **Recommend** treating bandaid-retirement PRs as "high-blast-radius" by default, paired with a Tess focused-review pass before merge (not after).

### Pattern 2 — PR #194 bounced once on CI — but the CI was lying

PR #194 first ran green on CI, then on rerun (after Tess started reviewing) one of the new test files showed up as parse-failed. GUT exits 0 on parse-failed tests — they just don't run. **This was a real testing-bar integrity hole**: the gate said green when the test was actually never executed. Closed by PR #196 (`fix(ci): fail GUT job on parse-failed test files`). The discipline is now: any parse error in a `tests/*.gd` file fails the job loudly, before any "tests passed: N" line.

### Pattern 3 — Empirical refutation beats forensic framing (#198 vs #200)

PR #198 framed Room 05's chaser-mob-freeze as "the harness can't clear three concurrent chasers — the multi-chaser clearer needs a position-steered sweep." The harness change shipped. But the symptom (chasers freezing mid-room) **persisted in some runs** even with the new clearer, and the framing left an unresolved question: why did chasers freeze AT ALL when not being chased?

PR #200's diagnostic-trace pair (`Player._die` action-side + `Main.apply_death_rule` consequence-side) **empirically refuted** the "chasers must be cleared by chase or they freeze" framing — the actual root cause was the physics-flush race between `gate_traversed` and the next-room load, fixed in PR #191. The chasers weren't "frozen" — they were being killed but their death-emit was racing the room transition. The harness-side fix was complementary, not corrective.

**Generalization:** when a fix lands and the symptom *partially* persists, the framing is suspect. The diagnostic-trace pair pattern (action-side + consequence-side traces, paired in the same PR) makes cause-effect chains observable in the trace stream; future "X happened invisibly and looked like Y" investigations have a documented disambiguation method. Codified into the testing bar as the **diagnostic-trace pair pattern** — surface the cause-side event AND the consequence-side event so the gap (or absence of gap) between them is visible. PR #200's trace lines are the canonical reference.

### Pattern 4 — Tess QA strain on coordinated changes (#194 took 2 rounds)

PR #194's 23-file coordinated change required **two QA rounds** from Tess (initial parse-error catch + post-fix re-review with item-loss bug surfaced). This isn't a Tess capacity problem — it's a **review-cost-scales-with-blast-radius** signal. Coordinated changes that touch the inventory / boot-order / equip-state surfaces are expensive to QA-review; they should be paired with a focused-review pass framed as "this PR retires a load-bearing bandaid, expect 2 rounds" so capacity is reserved up front. R2 (Tess bottleneck) was strained — not breaking, but a structural signal.

### Pattern 5 — Self-Test Report catches HTML5-only divergences early (#179)

PR #179's `✓ EQUIPPED` glyph rendered as tofu in HTML5 only — desktop and headless GUT both passed silently because OS fallback fonts cover U+2713. Devon caught this in their own Self-Test Report before Tess review (the gate did its job). The fix shipped in the same PR. **The Self-Test Report gate is the load-bearing surface for HTML5-default-font divergences** — primitives-safety analysis alone would not have flagged a Unicode codepoint. This is a precedent for the `html5-visual-verification-gate` memory rule.

---

## Lessons learned

### 1. Physics-flush rule generalizes BEYOND Area2D — `CollisionShape2D`-on-`PhysicsBody2D` adds are also unsafe in `flush_queries()` (#191 finding)

Prior framing (memory rule `godot-physics-flush-area2d-rule.md`) scoped the panic class to **Area2D** add / monitor-state mutation. PR #191 surfaced a broader case: the next-room load in `Main._load_room_at_index` (triggered by `gate_traversed → _on_room_gate_traversed → room_cleared → _on_room_cleared`) adds `CharacterBody2D` mob nodes with `CollisionShape2D` children. **These adds also panic when they land inside the prior room's physics-flush window** — not just Area2D-derived nodes.

The fix shape — `CONNECT_DEFERRED` on the cross-frame signal that bridges flush-rooted callbacks — is the highest-leverage pattern. Receiver-side `_init` encapsulation (the Hitbox/Projectile pattern) works for nodes you author; `CONNECT_DEFERRED` on the signal works for the bridge between unrelated callbacks.

**Codified:** `.claude/docs/combat-architecture.md` § "Cross-tree signal-connection discipline (load-bearing)" already captures this from PR #173 (gate-registration). PR #191 reinforces the rule with a second canonical example (room-load). **Future audit:** any signal handler whose connection point is reachable from a physics-flush callback (`body_entered`, `area_entered`, the cascade of synchronously-emitted signals from those) must use `CONNECT_DEFERRED` if the handler mutates state the receiver inspects.

### 2. GUT's green exit code MASKED parse-failed test files until #196's gate

This was a real testing-bar integrity hole — the test gate said green when test files were actually un-executed due to parse errors. Caught and fixed by PR #196. The discipline going forward: any `parse failed` line in GUT output fails the CI job loudly, before "N tests passed" is reported. **Generalization:** trust your gate's *reasons*, not just its *result*. Green-from-skip and green-from-pass look identical from outside; a gate that doesn't distinguish them is partially blind. Add explicit non-skip assertions when adding any new test discovery / runner / fixture-loading mechanism.

### 3. Diagnostic-trace pair pattern (#200) — pair action-side + consequence-side traces so cause-effect chains are visible

PR #200 codified the **diagnostic-trace pair** pattern: when a death-rule (or equivalent state machine transition) has an *action* side (`Player._die`) and a *consequence* side (`Main.apply_death_rule`), trace BOTH and emit them with synchronized formatting so the time gap (or absence of gap) is observable in the console buffer. Future "X happened invisibly and looked like Y" investigations have a documented disambiguation method:

- Action trace fired, consequence trace did NOT → the consequence side dropped (race, signal-not-connected, deferred call swallowed).
- Action trace did NOT fire, consequence trace did → the consequence side fired from a different action path (e.g. a save-restore equivalent, a debug call).
- Both fired with a >100ms gap → physics-flush deferral landed; root cause is timing, not connectivity.
- Both fired same-tick → behavior matches expectation; misdiagnosis is on the symptom side.

**Codification candidate:** add to `.claude/docs/combat-architecture.md` § "State-change signals vs. progression triggers" as a sibling rule. Future state-machine PRs that add new transition signals (mob_died, pickup_collected, save_completed) should ship paired action+consequence traces from day 1.

### 4. Godot HTML5 `gl_compatibility` default font has no glyph for many non-ASCII chars (#179)

U+2713 `✓` (checkmark), arrows (U+2190 etc.), box-drawing characters — all render as the notdef "tofu" box in HTML5. Headless GUT + desktop both use wider OS fallback fonts and pass silently. **Rule (codified in `.claude/docs/html5-export.md` § "Default-font glyph coverage"):** draw cue glyphs as geometry — two rotated `ColorRect` strokes for a checkmark, etc. — NOT as font characters. Plain ASCII text in `Label` nodes is unaffected. If a Unicode glyph is essential, import a custom `.ttf` covering the codepoint.

This divergence is **invisible to headless GUT and desktop** — only an HTML5 smoke test catches it. Self-Test Report screenshot evidence is the load-bearing surface; primitives-safety analysis is insufficient.

### 5. Godot UI focus-consumption is broader than `Tab` — `Escape`/`ui_cancel` is also swallowed when a Control holds focus (#187)

The Playwright equip-flow Phase 2.5 spec hit a race where pressing `Tab` to open the inventory and then a swing-key in close succession caused the swing to be consumed by the inventory panel's focus. Initial diagnosis (Devon): "use a different close-key like Escape." That diagnosis was wrong — `Escape` is *also* swallowed by Godot's `ui_cancel` action when any Control holds focus, including the inventory panel itself.

**Reliable Playwright close = test-only direct-close hook, not "pick another key."** PR #187 added an `Inventory.close_for_test()` method exposed to Playwright that bypasses the focus-input layer entirely. **Generalization:** any Playwright spec that needs to toggle a focus-consuming Control needs a test-only direct-toggle hook. Trying to drive focus-consuming UI through keyboard simulation alone is fragile against Godot's input-action hierarchy. **Codification candidate:** add to `team/tess-qa/playwright-harness-design.md` as a sibling to the "single-event continuous-walk" rule.

### 6. Bandaid retirement is a high-blast-radius operation; pair it with a focused QA pass (#194)

Already covered in §"What bounced or slipped" Pattern 1. The retirement of `equip_starter_weapon_if_needed` exposed two latent bugs (unreachable dummy-drop; full-grid silent-drop) and required two Tess rounds. Bandaid-retirement PRs should be flagged "high-blast-radius" in the dispatch brief so QA capacity is reserved up front.

---

## Risk-register update — top 3 active risks for W3 entry

Re-score of the risk register for M2 W3 entry. Full register at `team/priya-pl/risk-register.md` — this is the working summary.

### R6 — Sponsor-found-bugs flood (re-promoted)

- **Probability:** high (held)
- **Impact:** high (held)
- **W3 context:** the W2 RC (`d9cc159`) is the next Sponsor-soak target. Sponsor has NOT yet soaked anything from M2 — last soak was the M1 RC at `4484196`. W2 introduced 22 PRs of new surface (AC4 progression, inventory bandaid retirement, combat-trace coverage, polish/UX, harness hardening). Sponsor's first M2 soak is **certain to surface findings**; the buffer ticks in W3 are reserved for fix-forward.
- **Mitigation:** W3 has a Sponsor-soak fix-forward absorber ticket (W3-T10 from the W3 backlog); buffer reserved at ~2-3 dev ticks; if Sponsor surfaces ≥3 P0s, the W3-T10 ticket promotes from M to L per the R6 trigger threshold.
- **Watch signal:** Sponsor's first M2-RC soak report. Specifically: any AC4 finding, any Room01-onboarding finding (new path post-#194), any equipped-glyph regression on HTML5.
- **Owner:** Tess (triage), Devon / Drew (fix-forward), Priya (severity calls).

### R2 — Tess bottleneck (strained but not breaking)

- **Probability:** med (held; was lowered in M1 close-out, held in M2 W1, held in W2)
- **Impact:** med (held)
- **W3 context:** PR #194 took two QA rounds; the coordinated-change review cost is structural. W3 has multiple high-blast-radius tickets pending: stratum-2 content (3 tickets, including L-sized boss room), AC4 Room 05 balance pass (gameplay-balance review). Tess's load in W3 is heavier than W2 because *more* tickets land with gameplay-visible surfaces.
- **Mitigation:** flag high-blast-radius PRs in the dispatch brief; parallel scaffold pattern continues (Tess co-owns paired-test stubs from W3 day 1); QA capacity reservation up front for #194-class retirements.
- **Watch signal:** ≥2 PRs in "ready for QA" state simultaneously for >5 ticks; QA round count per PR rising above 1.5 average.
- **Owner:** Tess (capacity), Priya (size-sentinel + dispatch framing).

### R1 — Save migration breakage (re-armed — was inactive in W2)

- **Probability:** med (held)
- **Impact:** high (held)
- **W3 context:** R1 was **inactive in W2** — no save-schema-touching PRs shipped (the bandaid-retirement #194 did NOT touch the save shape; pickup-driven equip writes the same `_equipped[slot]` surface as the prior `equip_starter_weapon_if_needed` path). W3 RE-OPENS R1 because the v4 save stress fixtures (W2-T5 carry-over → W3 ticket) lands in W3, AND the AC4 Room 05 balance pass may require new TRES fields if Uma's design calls for player iframes-on-hit. Any TRES change that affects equip-state propagation is migration-adjacent.
- **Mitigation:** W3 stress-fixture ticket (8 new fixtures per W2-T5 §Scope) lands paired tests covering INV-1..INV-8 from `save-schema-v4-plan.md` §5. Any TRES additions in the balance pass get a migration note in the PR body even if no schema bump is technically required (forward-compat discipline).
- **Watch signal:** any save-touching PR that ships without a migration note; any new player-state field added by the balance pass.
- **Owner:** Devon (implement), Tess (validate), Priya (gate).

### Demoted from top-3

- **R11** (Integration-stub-shipped-as-feature-complete) — held; M1 close discipline survived M2 W1 + W2; Main.tscn integration surface is verified per ticket. Demote to watch-list.
- **R8** (Stash UI complexity) — held; no stash UI work shipped in W2 (deferred pending Sponsor signal). Re-promote when W2-T7 / W2-T8 carry-overs dispatch.
- **R9** (Stratum-2 content triple-stack) — held; **will RE-PROMOTE at W3 entry** when stratum-2 content tickets dispatch. Drew's load in W3 is heaviest of M2 (3 content tickets including L-sized boss room).

---

## Capacity check actual vs target

**W2 target (per `m2-week-2-backlog.md` §"Capacity check"):** 12 tickets — 8 P0 + 3 P1 + 1 P2.

**W2 actual:** 22 PRs merged, against ~14 distinct ClickUp tickets (some PRs were dispatched outside the W2 backlog — fix-forward / harness hardening / Tess-flagged latent bugs).

| Bucket | Target | Actual | Delta |
|---|---|---|---|
| W2 backlog tickets shipped (W2-T1..W2-T12) | 12 | **0** of the planned 12 (none of the stratum-2 / MobRegistry / stress-fixtures / iteration / audio tickets shipped) | **-12** |
| W2 backlog tickets carried to W3 | 0 (target) | **9** carries (T1, T2, T3, T4, T5, T7-conditional, T8-conditional, T9, T11-Half-B, T12) | **+9** |
| Non-backlog PRs (AC4 / inventory / combat-trace / infra / harness) | 0 (none anticipated) | **22** | **+22** |

**Honest framing.** W2 did not ship the backlog. **The actual shape was playability close-out and harness completion.** The decision-call that shaped W2 was the AC4 Playwright-spec close-out — the M1-RC AC4 spec had a `test.fail()` annotation on Room 02, then Room 05, that the harness couldn't drive past. Closing that consumed Devon + Drew's bandwidth via the physics-flush family (#183 / #184 / #191), the harness family (#186 / #190 / #198), and the inventory bandaid retirement (#194, which was prerequisite to the Room01 onboarding flow under #169).

**Was W2 a planning miss or a re-prioritization?** A re-prioritization. The W2 backlog was anticipatory and explicitly revisable; the team identified the AC4 close-out + bandaid-retirement work as higher-priority than stratum-2 content authoring (which is W3-W4 work anyway from the M2 timeline). The W2 backlog's TL;DR §5 noted "Sponsor-input items: zero blocking pre-conditions" — but the actual W2 work was Tess+harness-flagged blockers from M2 W1's incomplete close, which the W2 backlog didn't anticipate explicitly.

**Planning-quality grade for the W2 backlog:** **C+**. The anticipatory framing was correct; the specific ticket-mix anticipated for W2 was wrong; the team was self-directing toward the actual blockers, which is the right behavior. **Recommendation for W3 backlog:** explicitly enumerate the **carry-over absorption tickets** first (W3-T1..W3-T5 are W2 carries), then the new content tickets (stratum-2 family). Don't pretend a backlog can ship if it ignores the carry-over queue.

**Actual W2 PR-count throughput:** 22 PRs in ~7 days = **~3 PRs/day, single-team-of-5 cadence**. This is the highest weekly throughput of M1+M2 to date (M1 W2 was 16, M1 W3 close-out was ~12-14). The team's velocity is genuinely up; the planning mismatch is *what* was shipped vs *what was planned*, not *how much*.

---

## Decisions / escalations

**None.** W2 retro is a Priya-authority document. The W3 backlog absorbs all carry-overs and the user-locked AC4 Room 05 balance-pass design (Path A — balance, not Path B — harness dodge); both are within PL mandate.

**Soft asks for the orchestrator:**

1. **When dispatching the W3 stratum-2 content family (W3-T1, W3-T2, W3-T3 from the W3 backlog)**, parallel-dispatch Drew on T1+T2 first; T3 (boss room L) cascades after T1 lands. Don't stack all three on Drew simultaneously (the W2 R9 mitigation framing applies).
2. **When Sponsor returns to soak the W2 RC (`d9cc159`)**, ask for the boot-line `BuildInfo SHA` first per memory `html5-service-worker-cache-trap.md` — cached-build noise is the most common false-positive in soak feedback.

---

## Cross-references

- **W2 backlog (planned):** `team/priya-pl/m2-week-2-backlog.md`
- **W3 backlog (next):** `team/priya-pl/m2-week-3-backlog.md`
- **Bug-bash that closed W2:** `team/tess-qa/soak-2026-05-15.md`
- **Risk register (full):** `team/priya-pl/risk-register.md`
- **Process-incident log:** `team/log/process-incidents.md`
- **Architecture docs (auto-loaded):** `.claude/docs/combat-architecture.md`, `.claude/docs/html5-export.md`, `.claude/docs/orchestration-overview.md`
