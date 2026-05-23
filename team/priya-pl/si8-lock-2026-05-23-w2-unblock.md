# SI-8 lock — 2026-05-23 — W2 dispatch unblock

**Owner:** Priya · **Authored:** 2026-05-23 (post-PR-#328 merge) · **Status:** dispatch-ready for orchestrator. SI-8 locked to **option (b) — partially procedural with hand-pinned set-pieces**. W2 procgen + W2 stale-body tickets unblocked.

## TL;DR

1. Sponsor locked SI-8 to **(b) partially procedural with hand-pinned set-pieces** at 2026-05-23 10:08 UTC on PR #328 (procgen spike, merged).
2. **W2-T3** (`86c9y1045` — `assemble_floor` + S1 procgen retrofit) is now **dispatch-ready**: SI-8 option-neutral pre-shape from `post-wave3-sequencing.md` v1.2 §5.2 collapses to the (b) scope branch. Size locks at **L-XL** (5-7 ticks per v1.2 §5.2 (b) row).
3. **W2-T2** (`86c9y0zyv` — dialogue impl) and **W2-T4** (`86c9y108t` — world_seed save-write) had stale ticket bodies blocked by the prior session's ClickUp MCP outage; per v1.3 §5.1 / §B verdict they need Part D inlined. **MCP outage persisted into this dispatch** — three ticket-body updates are queued in `team/log/clickup-pending.md` per `team/CLICKUP_FALLBACK.md`. Orchestrator flushes after MCP reconnects.

## What (b) means — scope shape

Per PR #328 SI-8 recommendation section (Devon Part D) and the spike's empirical findings:

- **Hand-authored anchors are necessary.** Quest-driven exploration (SI-1 commitment) requires stable `room_id` slots that quest `.tres` files can bind to. Pure procedural placement (option a) breaks quest reachability — there is no stable surface for a quest to target.
- **Procedural fill between anchors is safe and adds the per-character variance the Diablo-shape directive promises.** Same seed → same map; different characters → different layouts. The spike's `[procgen-spike] assemble | placement=...` line proves the seed → placement determinism end-to-end.
- **Per-stratum hybridity is NOT the default.** Option (c) "hybrid by stratum" introduces per-stratum variance in the assembly model itself (S1 hand-authored, S2 procedural) — a 2x doctrine maintenance cost without a corresponding payoff. The (b) shape scales across strata: every zone declares its own anchor set + procedural pool.
- **R-PROCGEN.b is contained.** The port-mating diagnostic surfaces seam violations at assemble-time without raising; the W2 retrofit fixes the one known instance (`s1_room01` east seam) with a single-file edit.

**Reversibility:** the schema (per `team/drew-dev/level-chunks.md` § "Zone schema (M3 Tier 3 W1 spike)") permits any anchor density — zero anchors = pure procedural; all anchors with empty pool = pure hand-authored. Option (b) is the doctrine commitment, not a hard structural cage. `ZoneDef.stratum_id` permits per-zone divergence if a specific design demands it.

## W2 tickets unblocked

| Ticket | ID | Status before SI-8 lock | Status after lock |
|---|---|---|---|
| W2-T1 camera-scroll integration | `86c9y0zmg` | Ready (independent of SI-8) | Ready (unchanged) |
| **W2-T2** dialogue impl | `86c9y0zyv` | Ready, body amended in v1.3 §5.1 (Part D Drew nits 1+2) | **Ticket body update queued** (queue entry 029) |
| **W2-T3** procgen retrofit | `86c9y1045` | SI-8-blocked; option-neutral pre-shape | **SI-8 (b) scope locked; ticket body update queued** (queue entry 030) |
| **W2-T4** world_seed save-write | `86c9y108t` | Ready, body amended in v1.3 §5.1 (Part D Drew nit 3) | **Ticket body update queued** (queue entry 031) |
| W2-T5 world-map UI | `86c9y10ag` | Ready | Ready (unchanged) |
| W2-T6 quest authoring | `86c9y10nu` | Ready | Ready (unchanged) |
| W2-T7 survey-doc cleanup | `86c9y10x3` | Ready | Ready (unchanged) |

## W2-T3 — (b) scope target

Per `post-wave3-sequencing.md` v1.2 §5.2 SI-8 (b) branch, locked to:

**Acceptance gates ((b)-specific):**
- `resources/level_chunks/s1_room01.tres` east-seam port fix — add EAST `&"exit"` port at `position_tiles=(14, 4)` per `tests/test_floor_assembler.gd:496` docstring + spike-finding fix-shape; mating-count drift drops from 1 → 0; sibling pin updated in same PR.
- Existing S1 8 rooms retrofitted to ZoneDef-driven assembly. Each room declares anchor type per the (b) lock; smaller `procedural_slot_pool` than (a) would require — the 8 rooms become the anchor set with light procedural fill between.
- HTML5 visual-verification round: Sponsor / author HTML5 soak per `.claude/docs/html5-export.md` HTML5 visual-verification gate. Z-index sensitivity at chunk seams + procedural-seam rendering divergence are the R-PROCGEN.c surfaces.
- GUT pin updates per PR #328's port-mating diagnostic — the `test_assemble_authored_s1_z1_records_s1_room01_east_seam_finding` pin updates in the same PR as the port fix; new pins land for the retrofitted S1 zones.

**Out-of-scope:**
- Pure-procedural fallback paths (locked OUT by (b)).
- Per-stratum hybridity (locked OUT by (b)) — no S1/S2/S3 divergence in the assembly model.
- Any S2 retrofit work — W2-T3 is S1-only; S2 ZoneDef authoring lands in W3.
- The `Main._load_room_at_index → set_world_bounds(assembled_bounds)` wiring (that's W2-T1's surface).

**Files in play:**
- `scripts/levels/FloorAssembler.gd` — extend per S1 retrofit needs (no shape change vs spike).
- `resources/level_chunks/s1_room01.tres` + the other 7 S1 rooms — anchor metadata extension per ZoneDef-driven assembly.
- `resources/level/` new S1 `ZoneDef` resources (anchor set + smaller procedural_slot_pool per (b) lock).
- `tests/test_floor_assembler.gd` — W2 pin extensions; the spike's 18 pins extend with S1-zone-specific coverage.

**Cross-references:**
- PR #328 SI-8 recommendation section (Devon Part D) — foundation.
- `m3-diablo-shape-directive` (memory entry) — Diablo-shape directive seed.
- `team/tess-qa/m3-acceptance-plan-tier-3.md` Track 1.5 PG-1..PG-8 + AC-C5 rows — Tess acceptance scaffold.
- `.claude/docs/procgen-pipeline.md` — runtime API + port-mating discipline.
- `team/drew-dev/level-chunks.md` § "Zone schema (M3 Tier 3 W1 spike)" — ZoneDef / ZoneAnchor / procedural_slot_pool schema.

**Size:** L-XL (locked per v1.2 §5.2 (b) row sizing — 5-7 ticks).

**Status:** TO DO (dispatch-ready).

## Ticket-update log (queued via fallback per CLICKUP_FALLBACK.md)

ClickUp MCP failed to connect at this dispatch (same outage class as the W1 procgen-spike Self-Test Report flip — `clickup-mcp-three-occurrence-structural`). Per `team/CLICKUP_FALLBACK.md`, three `update_task` ops queued in `team/log/clickup-pending.md`:

| Queue entry | Ticket | Op | Update mode |
|---|---|---|---|
| ENTRY 2026-05-23-029 | `86c9y0zyv` (W2-T2) | update_task | queued-fallback |
| ENTRY 2026-05-23-030 | `86c9y1045` (W2-T3) | update_task | queued-fallback |
| ENTRY 2026-05-23-031 | `86c9y108t` (W2-T4) | update_task | queued-fallback |

Each queue entry contains the full target ticket-body text. Orchestrator flushes via `mcp__clickup__update_task` after MCP reconnects.

## Decision draft (for next DECISIONS.md batch)

```
Decision draft: SI-8 — M3 Tier 3 procgen shape locked to (b) partially procedural with hand-pinned set-pieces. Foundation: PR #328 SI-8 recommendation section + 2026-05-23 Sponsor sign-off on this orch turn. Reversibility: ZoneDef.stratum_id permits any anchor density per-zone if specific design demands.
```

Included in this PR body for the weekly `team/DECISIONS.md` batch (Priya-only batch-PR cadence).

## Cross-references

- PR #328 — procgen spike (merged). SI-8 recommendation section is the foundation citation.
- `team/priya-pl/post-wave3-sequencing.md` v1.2 §5.2 — SI-8 scope branches; v1.3 §5.1 / §B — W2 ticket-shape verdict (5 keep / 2 amend / 0 new).
- `team/priya-pl/m3-tier3-w1-tickets.md` — W1 dispatch-order precedent (Devon-wt single-tenancy).
- `.claude/docs/procgen-pipeline.md` — FloorAssembler runtime conventions (seed-cascade, port-mating record-not-raise).
- `team/tess-qa/m3-acceptance-plan-tier-3.md` Track 1.5 PG-1..PG-8 — Tess acceptance scaffold for AC-S4 / AC-C5.
- `team/drew-dev/level-chunks.md` § "Zone schema (M3 Tier 3 W1 spike)" — ZoneDef schema source.
- `m3-diablo-shape-directive` (memory entry) — Diablo-shape directive seed (5 Sponsor commitments).
- `team/log/clickup-pending.md` ENTRY 2026-05-23-029 / -030 / -031 — queued ticket-body updates.

## Non-obvious findings

1. **SI-8 lock collapses the ticket pre-shape — does NOT re-shape it.** v1.2 §5.2 deliberately filed W2-T3 as option-neutral so SI-8 sign-off would collapse to the locked branch's scope at dispatch time. (b) lock = the (b) scope branch goes into the ticket body verbatim; the (a) and (c) branches drop out. This is cheaper than authoring three separate tickets and discarding two.
2. **MCP-outage-into-this-dispatch is the same structural pattern as PR #328 author session.** Per memory `clickup-mcp-three-occurrence-structural`, three MCP disconnects across sub-sessions in one orch round = structural. This is occurrence #4+ in the same week. The CLICKUP_FALLBACK queue-and-flush flow handled it cleanly; no work blocked.
3. **W2-T3 ticket update is content-additive, not a re-author.** The pre-shaped ticket already contains the common scope (FloorAssembler.gd runtime, Main.gd integration, paired tests, HTML5 verification). The (b) lock adds the specific acceptance gates (s1_room01 east-seam fix + 8-room retrofit + (b)-locked OOS) without changing the existing common scope.
