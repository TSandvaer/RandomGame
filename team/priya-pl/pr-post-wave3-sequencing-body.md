## Summary

Authors `team/priya-pl/post-wave3-sequencing.md` — the canonical sequencing artifact for everything past M3 Tier 2 Wave 3. Doc-only PR; no engine code.

Absorbs both Sponsor 2026-05-22 direction signals:

1. **Level-scale signal** — "right now the levels are quite small and i hope that the final levels will feel more like walking through a level not just seeing the entire level at once" → continuous-scroll camera-follow per stratum.
2. **Diablo-shape lock** — "im leaning more to the diablo genre where you have to talk to npcs, explore the levels to solve quests, being able to see the world on a map with the different areas" → four first-class commitments: continuous-scroll / dialogue system / quest-driven exploration tied to geography / world-map UI.

## Doc shape (single new file, 6 sections + caveat + hand-off + findings)

- **TL;DR** (6-line summary).
- **§1** — Diablo-shape directive: four first-class commitments folded in foregrounded.
- **§2** — Why vertical-slice-first is the pro-team move (Sponsor's own framing absorbed).
- **§3** — Milestones (M3 Tier 3 / M4 / M5) with content tracks, dependencies, calendar shape.
- **§4** — Ticket pre-shape (counts + ownership; NO tickets created — awaiting Sponsor sign-off on §6).
- **§5** — Dependency / sequencing graph.
- **§6** — Sponsor-input items (seven required for M3 Tier 3 dispatch + three deferrable).
- **§7** — Risk-register snapshot (5 new / 2 demoted / 2 held / 1 retired).
- **§8** — Cross-references.

## Milestone summary

| Milestone | Headline | Calendar |
|---|---|---|
| **M3 Tier 3** | Diablo-shape vertical slice (S1+S2 polished: continuous-scroll + dialogue + per-stratum NPCs + S1 art-pass + hub-town + minimal map + 3-5 exploration quests + S2 content + S2 boss polish) | ~6-8 weeks parallel |
| **M4** | Scale systems + content fill (save-schema v5 impl + multi-character + persistent meta + bounty/dialogue content roster + map UI expansion; no new strata) | ~4-5 weeks parallel |
| **M5** | S3-S8 stratum-by-stratum + narrative pass + ship polish | ~5-6 months |
| **Total to ship** | | **~10-14 months honest middle** |

## Sponsor-input items (seven gating M3 Tier 3)

1. **§6 SI-1** — Camera-scroll shape: confirm continuous-scroll (recommended).
2. **§6 SI-2** — Dialogue system scope: full state-branching (recommended).
3. **§6 SI-3** — World-map UI shape: Diablo-II per-act / Diablo-IV overworld / Crystal-Project room-tree. Recommended Diablo-II per-act.
4. **§6 SI-4** — S2 mob archetypes: 2 new (recommended).
5. **§6 SI-5** — Per-stratum NPC count in M3 Tier 3: 3 stratum NPCs (recommended).
6. **§6 SI-6** — Multi-character slot count for M4: 3 (recommended).
7. **§6 SI-7** — M5 stratum order: sequential per `game-concept.md` (recommended).

Plus three deferrable: NG+ Paragon shape, ship target, per-stratum NPC density in M5.

## Opinionated calls (where alternatives were rejected — see §3 "Why this order over the alternatives")

- M3 Tier 3 becomes "Diablo-shape vertical slice" (5 tracks; 6-8 weeks) rather than "S1 art-pass + hub-town only" (3-4 weeks).
- Dialogue + zone schema + world-map UI land in M3 Tier 3 — first-class commitments, not polish.
- S2 lifts to M3 Tier 3 (was M4 in pre-Diablo-lock plan) — vertical-slice principle requires multi-stratum proof.
- M4 is mechanical depth + content fill (no new strata) — pattern dialed before scale.
- M5 is S3-S8 grind + ship — long-haul against locked pattern.

## Risk register shifts (full detail in §7)

- **NEW top-5:** R-SCROLL (camera-scroll HTML5 regression) / R-DIALOGUE (net-new system risk) / R-MAP (UI design risk) / R-ART (PixelLab capacity bottleneck) / R-SCOPE (doc adoption).
- **Demoted:** R6 (Sponsor-found-bugs) once M3 Tier 3 closes / R-AC4 (re-arms at M5.1).
- **Held:** R1 (save migration), R8 (stash complexity).
- **Retired:** R-M3 (M3 shape) — closed by 2026-05-17 Shape A + 2026-05-22 Diablo lock.

## Files

- `team/priya-pl/post-wave3-sequencing.md` (new, 506 lines)

## Sponsor-input items per section

- **§1** — Two 2026-05-22 Sponsor signals folded in directly (no new Sponsor-input items at §1 — directives are locked).
- **§3** — Five Sponsor-input items at M3 Tier 3 gate; two at M4/M5 gates.
- **§6** — Seven Sponsor-input items consolidated; three deferrable flagged.

## Decision drafts (for Priya's next weekly DECISIONS.md batch)

1. **2026-05-22 — M3 Tier 3 absorbs the Diablo-shape direction-lock.** Sponsor's 2026-05-22 signals (level-scale + Diablo-shape) re-shape M3 Tier 3 into a Diablo-shape vertical slice covering S1+S2 polished. Continuous-scroll camera-follow + dialogue system + per-stratum NPCs + quest-driven exploration tied to geography + world-map UI all land in M3 Tier 3 (~6-8 weeks). Affects: `post-wave3-sequencing.md`, future M3 Tier 3 backlog tickets. Decided by: Sponsor 2026-05-22.
2. **2026-05-22 — Vertical-slice-first principle adopted for M3 Tier 3 → M4 → M5 shape.** Per Sponsor framing: "vertical slice first at full polish + system depth, then content-scale." Two-stratum (S1+S2) Diablo-shape proof in M3 Tier 3 gates M4 (systems scale) and M5 (S3-S8 grind). Affects: milestone shape, ticket sequencing. Decided by: Sponsor 2026-05-22 + Priya recommendation.

## QA notes

- Doc-only PR.
- No Self-Test Report needed (doc-only per `self-test-report-gate` exception).
- No HTML5 verification gate needed (doc-only).
- Tess review: clarity + cross-reference correctness only.
- No tickets created from this doc — `§4 ticket pre-shape` is pre-shape only, NOT dispatch. Tickets get created post-Sponsor-sign-off on §6.

## ClickUp

- Ticket `86c9xm7b1` — `pm(m3): post-Wave-3 sequencing plan` (in progress).
- Flips to `ready for qa test` on PR open; `complete` on merge per `clickup-status-as-hard-gate` memory.
