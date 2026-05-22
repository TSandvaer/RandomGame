# M3 Tier 3 W1 — Backlog Tickets (Dispatch-Ready)

**Owner:** Priya · **Authored:** 2026-05-22 · **Status:** dispatch-ready. All 7 tickets filed in ClickUp; orchestrator dispatches per the order below.

## Source

This doc is the **dispatch-ready ticket roster** for M3 Tier 3 W1 (Diablo-shape vertical slice kickoff), authored from:

- **`team/priya-pl/post-wave3-sequencing.md` v1.1** (`3a1a3ca`) — §1 Commitments 1-5 (continuous-scroll camera / dialogue / quests-tied-to-geography / world-map UI / randomized maps per character) + §4 W1 ticket pre-shape + §6 SI-1 through SI-5 signed by Sponsor 2026-05-22.
- **`team/priya-pl/m3-tier-1-plan.md`** — precedent for spike-ticket structure (5 doc-PRs landing in Day-1 parallel dispatch).
- **`team/orchestrator/dispatch-template.md`** — ticket shape (title / source / scope / acceptance / owner / size / priority / cross-references).

Wave 3 closed at `3a1a3ca` (T13, T16, T17, T18 + T14/T15 direction docs all merged). Remaining Wave 3 work (T16b audio + T15 HUD impl) is in flight; not blocking M3 Tier 3 W1.

## TL;DR

Seven tickets filed. Six are **P0 Tier 3 W1 foundation**; one (save survey) is P1 because it can land alongside or just after the spike-cluster. **All 7 are doc / spike PRs** — no production feature impl in W1; W2 hardens against W1 findings.

The biggest delta vs Tier 1 W1 (5 tickets) is **Track 1.5 procgen** (NEW per v1.1). The procgen spike is the largest single W1 ticket (L-XL, 7-10 ticks) and the gate for SI-8 — Sponsor locks the procgen scope (a/b/c) at the procgen-spike PR-merge moment.

## Ticket roster (7 tickets, all `RandomGame` list `901523123922`)

| # | Ticket ID | Title | Owner | Size | Priority |
|---|---|---|---|---|---|
| 1 | `86c9xu9yt` | `spike(camera): continuous-scroll + CameraDirector follow-scroll API extension` | Devon | L | P0 |
| 2 | `86c9xuab3` | `spike(dialogue): DialogueTreeDef schema + DialogueController autoload + DialoguePanel modal UI` | Devon | L | P0 |
| 3 | `86c9xuap4` | `spike(level): ZoneDef schema extension — hand-authored anchors + procedural-fill slots` | Drew | M | P0 |
| 4 | `86c9xub9p` | `spike(procgen): assemble_floor + per-character world_seed binding` | Drew + Devon | L-XL | P0 |
| 5 | `86c9xubkj` | `design(ux): world-map UI direction — Diablo-II per-act map (SI-3 locked)` | Uma | M | P0 |
| 6 | `86c9xuc17` | `design(save): save-schema v5 survey doc — world_seed + multi-character lift requirements` | Devon | S-M | P1 |
| 7 | `86c9xucuc` | `qa(plan): M3 Tier 3 acceptance plan scaffold — 5-track placeholder rows` | Tess | M | P0 |

**Total estimated work:** ~28-39 ticks across 7 dispatch surfaces. Roughly 2× Tier 1 W1 (which was 5 tickets / ~15-22 ticks) — accounts for the procgen spike + the wider 5-track scope.

## Dispatch order recommendation (for next session's orch)

Tier 1 W1 successfully ran 5 tickets in Day-1 parallel because all 5 were independent doc-PRs across 5 different role worktrees. Tier 3 W1 is **almost as parallelizable** but has Devon-worktree serialization risk (3 of 7 tickets list Devon as owner: camera-scroll, dialogue, save-survey; plus Devon co-authors procgen Part B). Per `multi-dispatch-worktree-conflict` memory, Devon-wt is single-tenant.

**Recommended Day-1 dispatch (5 parallel):**

- **Devon** → `86c9xu9yt` **camera-scroll spike** (first Devon dispatch — gates W2 retrofit + Track 1.5 proof-scene)
- **Drew** → `86c9xuap4` **zone-schema spike** (Drew's first dispatch — gates procgen spike's data shape; pure paper-design, no engine code)
- **Uma** → `86c9xubkj` **world-map UI direction** (Uma's first dispatch — no spike dependencies; SI-3 already locked)
- **Tess** → `86c9xucuc` **M3 Tier 3 acceptance plan scaffold** (Tess's first dispatch — parallels dev lanes per scaffold-from-day-1 pattern; flag if Tess is on in-flight QA at dispatch time)
- **(deferred)** `86c9xuc17` **save-schema v5 survey doc** — Devon-wt single-tenancy; serialize behind camera-scroll spike. Dispatch Devon on this immediately after camera-scroll spike PR opens.

**Day-2 dispatch (2 parallel — after Day-1 spikes land or surface enough to compose against):**

- **Devon** → `86c9xuab3` **dialogue system spike** (gated on camera-scroll spike landing OR being far enough along to free Devon-wt). Dialogue is also engine + UI, Devon-led.
- **Drew + Devon** → `86c9xub9p` **procgen spike** (gated on zone-schema spike PR landing — procgen consumes `ZoneDef`). Co-authored; recommend serializing: Drew authors Part A on his worktree first, pushes to branch, Devon adds Parts B+C+D from his worktree once camera-scroll spike PR is opened. Single combined PR. **This is the SI-8 gating ticket.**

**Day-3-N — drain W1:** dispatches complete; PRs land; Tess QAs as W1 spike PRs surface (each spike PR's acceptance fold into the corresponding row in `m3-acceptance-plan-tier-3.md` scaffold). Tess flips acceptance-plan rows from `[PENDING-SPEC]` → `[ASSIGNED-TO <ticket>]` as W2 dispatches go out.

### Why this order

- **Camera-scroll first on Devon-wt** because it's the highest-leverage architecture and has no dependencies; the proof scene from this spike can be reused by the procgen spike's proof-scene scaffold.
- **Zone-schema first on Drew-wt** because procgen spike consumes `ZoneDef`; landing zone-schema first reduces procgen-spike rework risk.
- **World-map UI direction first on Uma-wt** because Uma has no other W1 dispatch (single-occupancy isn't a constraint here); direction doc can land in parallel without coupling.
- **Acceptance plan scaffold first on Tess-wt** because Tess otherwise idles in W1 until W2 dev PRs land — scaffold-from-day-1 pattern keeps Tess in parallel.
- **Save survey deferred behind camera-scroll** because Devon-wt is single-tenant; survey is P1 (W2 impl needs it, not W1) so the serialization is harmless.
- **Dialogue spike on Day 2** because it's Devon's second dispatch; needs Devon-wt free of camera-scroll. The dialogue spike's UI work doesn't overlap with camera-scroll, but worktree-occupancy does.
- **Procgen spike on Day 2** because it depends on zone-schema being far enough along to consume `ZoneDef` mock. Procgen is also the SI-8 gating decision surface — its PR-merge is the Sponsor escalation moment.

## SI-Δ items NOT yet locked (do not author tickets that depend on these)

Per `post-wave3-sequencing.md` v1.1 §6 — three items remain Sponsor-deferrable:

- **SI-6** — Multi-character slot count (recommended: 3; lockable by M4 W1)
- **SI-7** — M5 stratum order (recommended: sequential; lockable by end of M4 close)
- **SI-8** — Procgen scope (a/b/c) — **lockable by end of M3 Tier 3 W1 post-procgen-spike** (see procgen spike ticket — Sponsor signs at PR-merge based on spike findings)

The procgen spike (ticket 4 above) is the discovery surface for SI-8; orchestrator routes the Sponsor escalation at procgen-spike PR-merge time, not at procgen-spike dispatch time.

## Acceptance-plan-row coverage check

Each of the 6 spike / direction tickets corresponds to specific Tess scaffold rows (per ticket 7 `m3-acceptance-plan-tier-3.md`):

| Spike/direction ticket | Tess scaffold rows |
|---|---|
| `86c9xu9yt` camera-scroll | `CS-1` through `CS-6` |
| `86c9xuab3` dialogue | `DG-1` through `DG-10` |
| `86c9xuap4` zone-schema | `ZQ-1` through `ZQ-8` (some rows W2/W3 impl) |
| `86c9xub9p` procgen | `PG-1` through `PG-8` + `H5-1` (HTML5 procedural-seam round) |
| `86c9xubkj` world-map UI direction | `MP-1` through `MP-8` (rows W2 impl, scaffold present at spec-time) |
| `86c9xuc17` save-schema v5 survey | (cross-cutting — touches CS-/PG-/DG-/ZQ-/MP- save-state probes) |

Tess fills row content as each spike PR lands; rows flip from `[PENDING-SPEC]` → `[ASSIGNED-TO]` → `[GREEN]`/`[RED]` per the lifecycle convention in the scaffold doc.

## Risks tracked in `risk-register.md`

Per `post-wave3-sequencing.md` v1.1 §7 — risk register update lands in next Priya weekly batch. M3 Tier 3 W1 surfaces these risks:

- **R-SCROLL** (med/high) — camera-scroll spike findings flip from "expected" to "empirical."
- **R-DIALOGUE** (med/med-high) — dialogue spike validates schema-before-modal-UI mitigation.
- **R-MAP** (med-low/med) — world-map UI direction locks SI-3 shape; W2 impl + Sponsor soak gate is the next risk-watch surface.
- **R-PROCGEN** (med/high — NEW per v1.1) — procgen spike's three proof questions (seed round-trip / anchor-procgen composition / HTML5 seams) are the empirical surface that drives SI-8 sign-off.
- **R-ART** (med-high/med) — not surfaced by W1 spikes; Sponsor PixelLab batch wave 1 starts in W1 parallel but uses existing pipeline.

## Cross-references

- `team/priya-pl/post-wave3-sequencing.md` v1.1 (canonical sequencing artifact; this doc is the dispatch-ticket roster derived from §4 W1 pre-shape)
- `team/priya-pl/m3-tier-1-plan.md` (precedent for spike-ticket structure + Day-1 parallel dispatch pattern)
- `team/priya-pl/m3-design-seeds.md` (design-seed Sponsor-input items context)
- `team/orchestrator/dispatch-template.md` (ticket shape contract)
- `.claude/docs/orchestration-overview.md` (worktree single-tenancy + dispatch conventions)
- `team/priya-pl/risk-register.md` (R-SCROLL / R-DIALOGUE / R-MAP / R-PROCGEN / R-ART entries)
- `team/devon-dev/save-schema-v5-plan.md` (v5 baseline; W1 save-survey extends additively)
- `team/drew-dev/level-chunks.md` (zone-schema spike extends with `## Zone schema` section)
- `team/uma-ux/hub-town-direction.md` (descent-portal embryo for world-map UI direction)
- ClickUp list `901523123922` (RandomGame) — all 7 tickets live there

## Caveat — dispatch-order recommendation, not lock

This doc is a **recommendation** for the next orchestrator session. Final dispatch order may shift if:

- Sponsor surfaces a new SI-Δ between now and W1 kickoff (rare — SI-1..5 signed same-day as v1.1)
- Tess is on in-flight QA bigger than estimated (defer scaffold by 1 dispatch tick)
- Camera-scroll spike surfaces an HTML5 regression that materially shifts W1 dispatch priorities (camera-scroll is the W1 critical path; an unworkable HTML5 finding routes to Sponsor immediately)

Orchestrator owns the final dispatch sequence; this doc is the framework.

---

## Non-obvious findings

1. **Procgen spike is the SI-8 gating decision surface, not a feature dispatch.** Sponsor decides procgen scope (a/b/c) AT procgen-spike-PR-merge moment based on the spike's three empirical findings — not at procgen-spike-dispatch moment. Orchestrator routes the Sponsor escalation at PR merge, not earlier. This is the load-bearing reason procgen is on Day 2 not Day 1 (Drew must first land zone-schema; Devon-wt must first free of camera-scroll for Part B).
2. **Devon-wt is the W1 bottleneck — three tickets list Devon as owner.** Camera-scroll, dialogue, save-survey all need Devon-wt. The dispatch-order recommendation serializes them (Day 1: camera; Day 2: dialogue + procgen-Part-B; save-survey slots between). If Devon-wt is single-tenant for all three, W1 total wall-clock stretches by ~2-3 days vs ideal parallel. Acceptable; alternative is splitting Devon's role into two worktrees which violates the single-tenant rule.
3. **Tess scaffold lands AFTER sibling spikes for cross-reference concreteness, but DISPATCHES Day-1 in parallel.** The scaffold ticket dispatches Day-1 in parallel with the 4 spike/direction tickets, but its PR lands toward the end of W1 once sibling spike PRs have surfaced enough content for the row-cross-references to be concrete. Tess starts authoring scaffolds Day 1 and updates cross-refs as siblings land.
4. **Tier 3 W1 has no engine code in the production sense.** All 7 PRs are spike/design/QA-scaffold doc surfaces — zero shipping-feature code lands in W1. W2 hardens against W1 findings and ships feature impl. This is intentional per `m3-tier-1-plan.md` precedent: design-spike-first before content surfaces re-invent the contract.
5. **The 7-ticket roster is wider than M3 Tier 1's 5-ticket roster because v1.1 added procgen.** Per v1.1 §4 the procgen surface adds 2 NEW W1 tickets (procgen spike + save-survey absorbing world_seed) on top of the original v1.0 5-ticket pre-shape (which would have been camera, dialogue, zone-schema, map-direction, acceptance-scaffold). The save-survey ticket is the "absorbing" surface that captures all v1.1 + v1.0 additive save-state needs in one doc — without it, each W2 impl ticket re-discovers the additive fields piecemeal.
