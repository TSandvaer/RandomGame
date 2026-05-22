# pm(m3): post-Wave-3 sequencing v1.1 amendment — randomized-maps + §6 SI-1..5 sign-off

## Summary

Amends `team/priya-pl/post-wave3-sequencing.md` to v1.1, folding in Sponsor's two same-day signals from 2026-05-22 (post-PR-#303-merge):

1. **§6 SI-1 through SI-5 signed** — locks the Diablo-shape vertical-slice scope.
2. **New §1 Commitment 5** — randomized maps per character (Diablo-II "procedurally arranged per character" pattern).

Doc-only PR. Low-risk; no engine code; no save-schema bump; no test surface.

## Doc shape

The v1.1 amendment block sits **AT THE TOP** of the doc, BEFORE the existing v1.0 content. Pre-existing v1.0 content is preserved unchanged below the new amendment block as the historical record. This shape makes the deltas visible in one place; the v1.0 reasoning chains stay accessible for context.

## Sponsor sign-off folded in (§6)

- ✅ **SI-1** — Camera-scroll: continuous-scroll (a) confirmed. (b) Zelda-edge-pan and (c) Tunic-fixed-camera dropped.
- ✅ **SI-2** — Dialogue system: full state-branching confirmed.
- ✅ **SI-3** — World-map UI: Diablo-II per-act map (a) picked.
- ✅ **SI-4** — S2 mob archetypes: 2 new confirmed — Sunken-Scholar (ranged) + Bone-Catalyst (melee).
- ✅ **SI-5** — Per-stratum NPC count in M3 Tier 3: 3 stratum NPCs (1 in S1, 2 in S2) on top of 3 hub-town NPCs.

**SI-6 + SI-7 remain deferrable** (M4 + M5 gates respectively).

## New directive folded in (§1 Commitment 5)

Sponsor verbatim 2026-05-22: *"i also want randomized maps per level, meaning tile sprites are put together randomly for each new player"*

**The lock:** per-character `world_seed` rolled at character creation + procedural chunk-fill between hand-authored anchors.

**Hand-authored (deterministic per stratum + zone, identical for all characters):**
- Zone entries + exits
- NPC placement rooms (per SI-5: 1 in S1, 2 in S2)
- Boss rooms
- Quest-target rooms
- Story-beat rooms
- Hub-town (single-screen 480×270; not procedural)

**Procedural (per-character, seeded by `world_seed`):**
- Tile-chunk arrangement WITHIN zone bounds, between hand-authored anchors
- Mob spawn point selection within procedural chunks
- Loot pickup placement within procedural chunks

**Schema pre-shape:** `level-chunks.md` § "Why ports" + the `assemble_floor` extension hook already pre-shape this. M3 Tier 3 W1 spike implements `assemble_floor(chunks, zone_def, seed)`.

## NEW SI-8 — Sponsor-input needed for procgen scope

(a) fully procedural chunk-fill between anchors / (b) partially procedural with hand-pinned set-pieces inside zones / **(c)** hybrid by stratum (S1-S2 hand-pinned, S3-S8 procedural).

**Recommended:** (b) partially procedural with hand-pinned set-pieces. Reasoning: preserves authorial control over quest objectives + NPC placements within zones while letting the rest fill procedurally. (a) risks legibility; (c) is the slip-floor if HTML5 procedural-seam regressions surface in W1.

**Lockable by:** end of M3 Tier 3 W1 (post-spike).

## Calendar shift (§3)

M3 Tier 3 widens from **6-8 weeks** (v1.0) → **7-10 weeks** honest middle (v1.1). Procgen spike + `assemble_floor` impl + HTML5 procedural-seam visual-verification adds ~1-2 calendar weeks. **Total ship calendar:** ~11-15 months honest middle (was 10-14).

## Ticket pre-shape (§4)

Three new W1/W2 tickets + one W6-W7 ticket added:

| Wave | Ticket | Owner |
|---|---|---|
| W1 | Procgen spike: `assemble_floor` + per-character `world_seed` binding | Devon + Drew |
| W2 | `assemble_floor(chunks, zone_def, seed)` impl + S1 procedural retrofit | Drew + Devon |
| W2 | Per-character `world_seed` save-write + v5 schema additive field | Devon |
| W6-W7 | HTML5 procedural-seam visual-verification + Sponsor-soak probe round | Tess + Sponsor |

Total M3 Tier 3 tickets: ~45 (v1.0) → ~50 (v1.1).

## Risk register update (§7)

- **NEW R-PROCGEN** (med probability, high impact) — three sub-risks: per-character seed-binding bugs, chunk-port mating gaps at procedural seams, HTML5 `gl_compatibility` procedural-seam rendering divergence.
- **R-SCOPE demoted** — Sponsor signed milestone shape; retire pending SI-8 sign-off.

## Cross-references added (§8)

- `team/drew-dev/level-chunks.md` § "Why ports, not free-form transitions" — pinpoint the port-mating discipline that pre-shapes Commitment 5.
- `team/devon-dev/save-schema-v5-plan.md` — verified exists; Commitment 5's `world_seed` additive field rides on v5's per-character key structure without touching the non-additive lift.

## Tess QA shape

Same as v1.0 (doc-only, low-risk). Verify:
1. v1.1 amendment block sits at top of doc, before v1.0 content.
2. v1.0 content preserved unchanged below.
3. All five SI-1..5 marked ✅ in §6 (closed); SI-6, SI-7, SI-Δ-1..3 marked as deferrable.
4. SI-8 framed with three options + recommended pick.
5. New tickets in §4 table consistent with R-PROCGEN sub-risks in §7.
6. Cross-refs to `level-chunks.md` § "Why ports" + `save-schema-v5-plan.md` cite existing material.

## ClickUp

Ticket: `86c9xn5uj` — pm(m3): post-Wave-3 sequencing v1.1 amendment. Status: in progress on dispatch; flip to `ready for qa test` on PR open.

## Decision drafts (for Priya's next weekly DECISIONS.md batch)

> Decision draft: Sponsor signed Diablo-shape vertical-slice scope locks 2026-05-22 — continuous-scroll camera (SI-1), full state-branching dialogue (SI-2), Diablo-II per-act map (SI-3), 2 new S2 mob archetypes Sunken-Scholar + Bone-Catalyst (SI-4), 3 M3 Tier 3 stratum NPCs (SI-5). M3 Tier 3 W1 dispatch unblocked.

> Decision draft: Sponsor added fifth Diablo-shape directive 2026-05-22 — randomized maps per character via per-character `world_seed` + procedural chunk-fill between hand-authored anchors. Adds M3 Tier 3 procgen spike + `assemble_floor` impl + per-character-seed-save tickets to W1/W2; widens Tier 3 calendar 6-8 → 7-10 weeks honest middle.

## Sponsor-input items in this PR

1. **SI-8 — Procgen scope** (a/b/c framed in v1.1 amendment block + here). Recommended (b). Lockable post-W1-spike.

## Non-obvious findings

1. **The Diablo-II "procedurally arranged per character" pattern composes cleanly with v5 multi-character.** `world_seed` is a per-character key; different characters in the same save slot see different maps for the same stratum. This makes alt characters genuinely interesting (not just "re-do the same content with different stats") and ratifies the §2 vertical-slice-first reasoning (M3 Tier 3's vertical slice now proves four orthogonal patterns at once: continuous-scroll camera, dialogue system, world-map UI, per-character procgen — each a first-class architectural commitment).
2. **The `level-chunks.md` schema pre-shape is genuinely load-bearing.** v1.0 §1 Commitment 1 cited `assemble_floor` as M2/M3 extension; v1.1 Commitment 5 promotes it to M3 Tier 3 W1 spike. Without the v1 schema's `ports + assemble_floor` pre-shape, Commitment 5 would be a multi-week schema-design lift on top of a multi-week procgen-impl lift. With the pre-shape, the impl drops onto a known-discipline foundation.
3. **The HTML5 procedural-seam risk is the dominant new risk class.** R-PROCGEN.c is the one that could force SI-8 option (c) as the slip-floor. The `gl_compatibility` z-index sharp edge per `html5-export.md` has bitten three times in M3 (PR #137 wedge, PR #291 burst occlusion, PR #291 burst contrast); procedural seams across multi-chunk tilemaps are the next plausible bite class.
