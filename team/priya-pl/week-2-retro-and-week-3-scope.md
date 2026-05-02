# Week 2 Retro + Week 3 Scope

Owner: Priya. Tick: 2026-05-02 (mid-to-late week 2). Companion to `team/priya-pl/week-2-backlog.md` and `team/priya-pl/risk-register.md`. Ticket: `86c9kxx94`.

## Snapshot — where week 2 actually is

Week 2 promoted **21 tickets** (20 net new + 1 carry-over). Status as of this tick:

| Bucket | Count | Tickets |
|---|---|---|
| **Complete** | 16 | C1 butler (`86c9kwhte`), N1 level-up math (`86c9kxx2t`), N2 stat-allocation UI (`86c9kxx2y`), N3 damage formula (`86c9kxx3m`), N4 shooter (`86c9kxx3z`), N5 charger (`86c9kxx46`), N6 boss (`86c9kxx4t`), **N7 affix system T1 (`86c9kxx5p`)** — just merged via PR #55, N10 rooms 2-8 (`86c9kxx6c`), N11 stratum exit + descend (`86c9kxx6z`), N12 save migration test (`86c9kxx73`), N13 level-up panel design (`86c9kxx79`), N14 boss intro design (`86c9kxx7e`), B4 GUT backfill (`86c9kxx8h`), plus **two non-backlog adds**: secret-free RC build path (`86c9ky4fv`, `chore(ci)`) + audio direction one-pager (`86c9ky9ex`, `design(audio)`). |
| **In progress** | 3 | B6 retro (`86c9kxx94` — this doc), N9 inventory & stats panel (`86c9kxx66` — Devon in flight), B2 soak (`86c9kxx80` — held open awaiting Sponsor's interactive 30-min run). |
| **To do** | 5 | N8 affix balance T1→T3 (`86c9kxx61`), B1 bug bash (`86c9kxx7h`), B3 CI hardening (`86c9kxx8a`), B5 integration GUT tests for ACs (`86c9kxx8x`), plus **a new follow-up filed during week 2**: `86c9kyntj` `chore(gear): align affix-count to spec 1/2/3` — Tess-flagged spec deviation on N7 sign-off. |
| **Ready for QA** | 0 | (empty — Tess sign-off latency is not the constraint.) |

Throughput: **76% (16 / 21) of week-2 tickets shipped at this tick**, with three more in flight. The to-do bucket is *all* week-3-shaped work (balance, polish UI, integration coverage, CI hardening, bug bash, one targeted follow-up) — exactly the shape we want it to be heading into the M1 close.

### Recent merges (`origin/main`, last 30 commits)

```
b26f3ab feat(gear): affix system T1 — wire swift/vital/keen to V/F/E + move_speed (#55)
4e83f80 feat(progression): stat-point allocation UI (Vigor/Focus/Edge) (#52)
1a05d4b feat(level): rooms 2-8 of stratum 1 from RoomChunk lib   (#49)
9cd07cb feat(level): stratum exit + descend screen               (#47)
cbf98c5 feat(combat): damage formula — base + edge/vigor scaling (#43)
d803d3d feat(boss): stratum-1 boss encounter — 3 phases          (#40)
b423e1c design(audio): audio direction + cue list                (#37)
69a14c1 feat(progression): level-up math + XP curve              (#35)
0310120 feat(mobs): shooter mob archetype + projectile           (#33)
d58c83d feat(mobs): charger mob archetype                        (#26)
f7d60dc test(save): forward-compat v0->v1 migration test         (#31)
8d3527e fix(ci): copy Godot export templates into runner HOME    (#30)
64866f7 test(qa): backfill w1 GUT coverage gaps                  (#29)
3e591b7 design(ux): boss intro + health-bar treatment            (#28)
149f61e chore(ci): add secret-free M1 RC build path              (#27)
011389a design(ux): level-up panel + tooltip language standard   (#25)
```

(Plus heartbeat ticks and run-state PRs trimmed.)

### M1 RC build artifact trail

| Build | SHA | What it contains |
|---|---|---|
| RC1 | `69a14c1` | M1 plumbing + level-up math (no boss yet) |
| RC2 | `d803d3d` | + stratum-1 boss + 3 phases |
| RC3 | `9cd07cb` | + stratum exit + descend screen — **active Sponsor-soak target** |
| RC4 | `1a05d4b` | + rooms 2-8 + RoomGate + StratumProgression — **latest polish, Sponsor's optional choice** |
| RC5 (pending) | `b26f3ab` | + affix system T1 (live stats from gear) — not yet re-cut; deferred until inventory UI wires the panels into Main.tscn |

Sponsor is OUT, soaking. No fresh re-cut on RC5 was performed this week — the affix system's player-facing surface (live stat changes from equipped gear with rolled affixes) only matters once the inventory panel lands in the live HUD. Re-cut deferred to whichever PR wires the panels into the live scene tree.

## What went well

1. **Throughput overshot the plan.** Week-2 backlog projected 8 carry-overs + ~13 net-new shippable; reality at mid-week is 16 complete + 3 in flight. Devon and Drew both ran multiple tickets per session; Tess kept the QA queue at depth 0–1 across most ticks. The decision to **dispatch Tess back-to-back when the QA queue hits ≥3** (testing-bar §orchestrator rule) clearly worked — there is no tickets-stuck-in-QA tail.
2. **Worktree isolation paid for itself by week-2 tick 3.** Run-001 and run-002 both burned tick budget on cross-agent working-directory pollution. After the 2026-05-02 worktree-isolation decision, that class of bug effectively disappeared. Only HEAD-pinning incidents remain (Uma flagged a third occurrence in audio-direction; this run flagged a fourth — see "What didn't go well").
3. **Critical-path order held.** `C3 save → N1 level-up → N3 damage → N7 affix → N6 boss` was the planned chain. It shipped *in that order* with no rework. Schema bumps (v1→v2 for XP, v2→v3 for stat allocation) all chained cleanly, validated by Tess's forward-compat fixture test (N12, `86c9kxx73`). The save-migration risk (R1) has held without materializing.
4. **Two high-value non-backlog adds made it through without scope drama.** The secret-free RC build path (`86c9ky4fv`) was filed and shipped during the week to unblock Sponsor playtesting without the itch.io secrets — a direct response to a real constraint, not feature-creep. Uma's audio-direction one-pager (`86c9ky9ex`) extends the design lockbox without touching M1 surface code. Both were small, both DECISIONS-logged, both stayed in their lanes.
5. **Testing-bar discipline held under pressure.** Every shipped feature has paired GUT tests (33 + 22 + 28 + 30 + 35 + 42 across the major drops); CI stayed green; the v0→v1→v2→v3 migration chain is asserted end-to-end. **Zero `tech-debt(...)` reverts** were filed this week. The one spec-deviation found (affix counts on N7) was caught at sign-off and routed to a follow-up ticket (`86c9kyntj`), not absorbed silently. That's the bar working as designed.

## What didn't go well

1. **No true human soak yet.** Sponsor is OUT; Tess can't run a 30-min interactive button-mashing session because she has no local Godot. The B2 soak ticket (`86c9kxx80`) is `in progress` but really means "code-read + automated-coverage proxy + an artifact waiting for Sponsor." That's a known structural gap the testing bar acknowledges, but week-2 confirms: **automated coverage + code-read are not a substitute for a human at the controls**, and the M1 sign-off gate is fundamentally external until Sponsor returns. We should not pretend otherwise.
2. **Worktree HEAD-pinning is still leaky.** Uma flagged a third cross-worktree HEAD incident this week (cherry-pick recovery during audio-direction). I hit a fourth this run — the worktree's HEAD shifted to `tess/run-012-state-v2` mid-tool-call between two of my own commands, costing one stash-pop conflict. The 2026-05-02 worktree-isolation decision fixed working-directory pollution but the `.git/HEAD` is still shared at the orchestrator-class checkout layer. **Worktree-isolation v3** with per-worktree HEAD pinning needs to land in week 3 — this isn't theoretical anymore, it's recurring tax on every Priya-class long-form run.
3. **Affix-count spec deviation in N7.** Drew's affix-system PR #55 merged with count/tier-band values that deviated from the spec on a couple of points; Tess caught and filed the follow-up `86c9kyntj` `chore(gear): align affix-count to spec 1/2/3`. The catch worked — but the underlying issue is that **the affix system spec for counts-per-tier was looser than it needed to be**. N8 (the balance-pass ticket) needs to land with a tighter pre-pinned tier value table, not "Drew designs from the bench at fill-time." Watch-list item W2 is now an active risk (R7) for week 3.
4. **Stat-allocation UI shipped but isn't wired into a live scene.** PR #52 (`86c9kxx2y`) merged and is paired with 35 GUT tests. But `scenes/Main.tscn` is still a stub — neither the inventory panel (N9, in flight) nor the stat-allocation panel are instantiated in a runnable HUD. **The week-2 UI surface is technically complete-per-ticket but not user-visible**, which means Sponsor's soak builds (`9cd07cb` and `1a05d4b`) don't actually expose the new progression UI yet. This is a categorization issue: the ticket said "implement the panel"; it didn't say "wire it into Main." Devon's in-flight N9 should close the gap — `feat(ui): wire HUD scene tree` is implicit in N9 but should be made explicit so it can't be missed again.
5. **Some non-backlog work crept in without retro pre-approval.** The two non-backlog adds (release-github CI, audio direction) plus the just-filed `86c9kyntj` follow-up were all clearly inside scope and (where applicable) DECISIONS-logged, so no harm done — but the *pattern* is exactly the scope-creep risk R4 the register flags. Mitigation worked because all three passed the "does this unblock a tracked risk or close a known gap?" smell test (R3 HTML5 export, M1-but-deferred audio, week-2 affix spec-cleanup respectively). Week 3 should explicitly enumerate "non-backlog acceptable" categories in the retro framing so we don't drift.

## Risks heading into week 3

The risk register at `team/priya-pl/risk-register.md` gets a re-score this tick. Top 3 active risks for week 3:

1. **R6 (NEW) — Sponsor-found-bugs flood when soak resumes.** Sponsor will return at some point to soak `9cd07cb`, `1a05d4b`, or whichever RC ships next. They've not been at the controls for the full week-2 build-out. Even with our coverage discipline, a 30-min interactive session by a fresh human routinely surfaces 3–8 polish/edge-case bugs in a build with this much new content (boss + 7 rooms + stat-allocation + descend + affix system). Probability **high**, impact **med** (none of the M1 ACs are likely to fail outright; we're talking polish + edge-case bugs). Mitigation: reserve **B1 bug-bash + ~2 free dev ticks** in week 3 specifically for the post-soak fix-forward loop. Don't load week 3 to capacity assuming Sponsor finds nothing.
2. **R3 (escalated) — HTML5 export regression.** Promoted from "med probability, high impact" to **high probability, high impact** for week 3. Why: the `1a05d4b` build added rooms 2–8 + RoomGate + StratumProgression (autoload + save-key) + HealingFountain. The next RC will add the affix system + inventory UI on top. Each is a new edge surface against Godot's HTML5 quirks (tab-blur during autoload init, OPFS during stratum-progression save, audio-context state across room-gate transitions). Tess's HTML5-specific cases need a re-run on the latest RC before Sponsor next picks up. Mitigation: explicit **W3-A5 ticket** — "qa(html5): re-run testability hooks 5 (console errors) on RC5+, plus tab-blur probe on each new autoload."
3. **R7 (NEW, promoted from W2) — Affix balance hand-tuning sinkhole.** N8 (T1→T3 balance pass, `86c9kxx61`) is unstarted and is the next gate for AC #7 (two distinct visible affix drops at sane values). Plus the just-filed `86c9kyntj` count-fix follow-up. Bad balance numbers ship easily and are hard to test against (the assertion is "feels right," not a unit test). Without a pre-pinned tier value table, N8 turns into open-ended hand-tuning that swallows tick budget. Probability **high**, impact **med-high**. Mitigation: Priya pre-pins the tier value table in `team/priya-pl/affix-balance-pin.md` (NEW doc, week-3 deliverable) *before* Drew starts N8.

R1 (save migration), R2 (Tess bottleneck), R4 (scope creep), R5 (concurrent-agent collisions) all hold but **don't make the top 3 anymore** — R1 has held five schema bumps without breakage; R2 is currently inverted (queue is empty); R4 has a clean record this week (three acceptable adds, all DECISIONS-logged or self-explanatory follow-ups); R5 is constrained to the residual HEAD-pinning leak which has a scoped fix planned for week 3. They drop to watch-list rotation; the register update reflects this.

## Week-3 scope draft

Goal: **close M1, ship the M1 RC for Sponsor sign-off, set up M2 tooling for the multi-stratum jump.**

Two halves:

### Half A — M1 close (priority order)

| # | Task | Owner | Notes |
|---|---|---|---|
| W3-A1 | `feat(ui): inventory & stats panel implementation + HUD wiring` (`86c9kxx66`, N9 carry; in flight) | Devon | **Make the wiring explicit on the ticket.** Inventory panel + stat-allocation panel must both be instantiated in `Main.tscn` (or its replacement) with a visible HUD pip per Uma LU-06. Not done = ticket not done. Devon already in flight. |
| W3-A2 | `feat(gear): affix balance pass — T1→T3 value ranges` (`86c9kxx61`, N8 carry) | Drew | **Priya pre-pins the tier value table** in `team/priya-pl/affix-balance-pin.md` (NEW doc, week-3 deliverable) before Drew starts. Drew fills the TRES values and adds GUT range-clamp tests. Folds in `86c9kyntj` count-fix as the same PR. |
| W3-A3 | `qa(integration): GUT scene tests for ACs #2/#3/#6` (`86c9kxx8x`, B5 carry) | Tess | First integration-tier tests beyond unit. Speed-to-first-kill (AC#2), death-keeps-progress (AC#3), save-survives (AC#6). Closes the integration-coverage gap surfaced in week-2 retro. |
| W3-A4 | `chore(ci): hardening — flake quarantine, cache, runtime budget` (`86c9kxx8a`, B3 carry) | Devon | Cap CI under 5min, add cache, document any quarantined tests. |
| W3-A5 | `qa(html5): RC re-soak on RC5+ — console errors + tab-blur + OPFS` (NEW) | Tess | Explicit HTML5-tab-blur + console-error + OPFS save round-trip on latest RC. R3 escalation mitigation. |
| W3-A6 | `qa(bugbash): end-of-week-3 exploratory pass` (`86c9kxx7h`, B1 carry — re-scope to **post-Sponsor-soak fix-forward**) | Tess | Folds in whatever Sponsor's soak surfaces. Don't run this until Sponsor's bugs are in. |
| W3-A7 | `chore(infra): worktree isolation v3 — per-worktree HEAD pinning` (NEW) | orchestrator (or Devon) | Closes the four-incident loop Uma + Priya have flagged. Quick fix, ~1 tick. |

### Half B — M2 onset

The week-3 leftover capacity (after the M1 close) is M2 setup work. Don't pull M2 *features* in — pull M2 *tooling and design* in.

| # | Task | Owner | Notes |
|---|---|---|---|
| W3-B1 | `design(ux): stash UI v1 — death-recovery flow + ember-bag pattern` (NEW) | Uma | Per the M1 death rule decision (2026-05-02), M2 introduces a stash UI + an ember-bag gear-recovery pattern. Uma scopes the design here. |
| W3-B2 | `chore(content): multi-stratum tooling — stratum-2 chunk lib scaffold` (NEW) | Drew | Generalize the stratum-1 RoomChunk lib so stratum-2 reuses the same data-driven flow. No content yet — just the scaffold + `LevelChunkDef` namespace cleanup so stratum-N references are unambiguous. |
| W3-B3 | `design(spec): stratum-2 palette + biome direction` (NEW) | Uma | Extends `team/uma-ux/palette.md` from "indicative" to "authoritative" for S2. Drew uses for stratum-2 sprite authoring in M2. |
| W3-B4 | `feat(progression): persistent character meta-data v1` (NEW, M2 ramp) | Devon | M2 needs a stash inventory + per-stratum unlock state in the save schema. Devon scopes the schema bump (v3→v4) with a forward-compat doc. **Implementation lands in M2; design + migration plan lands in week 3.** |

### Capacity check

If week 2 actually shipped 16 + 2 (non-backlog) = 18 tickets, the "comfortable" week-3 ceiling is around 14 (allow some buffer). 7 close items + 4 M2-setup items = 11 tickets. **Plenty of headroom for Sponsor-soak-fix-forward (R6) and for any other reactive work.** No need to compress.

## Decisions / escalations for orchestrator

**None.** The week-2 retro is a Priya-authority document; week-3 scope is well within the project leader's mandate per `ROLES.md`. No cross-role calls require Sponsor input. Orchestrator is informed, not asked.

Two soft asks:

- When dispatching W3-A7 (worktree-isolation v3), the orchestrator can pick the owner — Devon if the fix is engine-level, the orchestrator itself if it's harness-level. Either is fine.
- When Sponsor returns and files bugs, the **first dispatch** should be Tess running her own bug-bash on the same build to confirm/disprove each Sponsor-filed issue, *then* Devon/Drew fix-forward. Don't go straight to fix without confirmation — protects against false-positives during the human soak.

## What week 3 looks like at the end

Definition of "week-3 closed":
- All 7 M1 ACs from `mvp-scope.md` provably green via integration tests (W3-A3) + Sponsor's interactive soak.
- **Zero blockers, zero majors** in the bug queue.
- M1 RC artifact tagged `v1.0.0-rc1` (or whatever the release-tag convention lands as) and uploaded as a GitHub Release per the secret-free CI path.
- M2 tooling scaffold ready so week-4 can start shipping stratum-2 content immediately.
- Risk register top 5 re-scored at week-3 close.

If Sponsor's soak returns clean against the latest RC, the week-3 close *is* the M1 close, and the M1 sign-off ping fires. If it doesn't, week 3 absorbs the fix-forward and week 4 absorbs the M2 ramp instead.
