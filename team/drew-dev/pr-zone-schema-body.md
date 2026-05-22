## Summary

M3 Tier 3 W1 zone-schema spike (ticket [`86c9xuap4`](https://app.clickup.com/t/86c9xuap4)). Pure paper-design + data layer — `assemble_floor(chunks, zone_def, seed)` runtime lives in the sibling procgen spike ([`86c9xub9p`](https://app.clickup.com/t/86c9xub9p)), W2.

Lands the `ZoneDef` layer above `LevelChunkDef`: the named-geography schema that quests reference (Commitment 3), the world-map UI lists (Commitment 4), and procgen composes anchor-by-anchor with per-character `world_seed`-driven fill (Commitment 5). Drew's existing `level-chunks.md` § "Why ports, not free-form transitions" already pre-shaped this; this PR adds the layer that turns chunks into named zones.

## Scope

**A. `team/drew-dev/level-chunks.md` — new `## Zone schema` section, 6 sub-sections:**

1. **Why zones** — rationale + Diablo II "Den of Evil" / "Tools of the Trade" precedent + 3-failure-mode breakdown of why the layer is necessary (quests can't bind to chunks; map UI can't display chunk graphs; procgen has nowhere to anchor).
2. **ZoneDef shape** — Resource field list with per-field design rationale.
3. **ZoneAnchor kinds enum** — exhaustive `&"entry" / &"exit" / &"npc_room" / &"boss_room" / &"quest_target" / &"story_beat"` taxonomy with semantic + worked-example reference + notes per kind.
4. **Hand-authored vs procedural split** — restates v1.1 §1 Commitment 5 + pins `assemble_floor(chunks_by_id, zone_def, seed)` signature for the sibling procgen spike.
5. **Worked example: `s1_z1_outer_cloister.tres`** — full 5-anchor zone (entry → npc_room → quest_target → boss_room → exit) + 4-chunk procedural pool. Per-character layout shape + W2 retrofit hook documented.
6. **Cross-zone transitions** — `exit` anchor `target_zone_id` routing + port-mating reuse + W2 transitional behavior for unresolved targets + save-schema-additive-on-v5 implication.

**B. Two Resource classes:**

- `resources/level/ZoneDef.gd` — implements the §2 shape with `validate()` enforcing: exactly-one-entry / ≥1-exit / unique room_ids / slot-range sanity / non-empty pool when max_slots > 0 / exit no-self-loop.
- `resources/level/ZoneAnchor.gd` — implements the per-anchor shape with `KINDS` constant + `is_known_kind()` static + per-anchor `validate()`.

**C. Worked-example `.tres`:**

- `resources/level/zones/s1_z1_outer_cloister.tres` — 5 anchors, 4-chunk procedural pool. All chunk_ids resolve to existing `resources/level_chunks/s1_room0N.tres` files (GUT-pinned).

**D. Paired GUT test:**

- `tests/test_zone_def.gd` — 23 tests covering: `ZoneAnchor.KINDS` round-trip, anchor `validate()` happy + 4 error paths, zone `validate()` happy + 8 error paths (empty id / empty display_name / out-of-range stratum / wrong entry count / zero exits / duplicate room_ids / exit self-loop / slot-range inversion / empty-pool-with-nonzero-max), `get_anchors_of_kind` / `get_entry_anchor` / `has_anchor` helpers, plus 6 round-trip tests on the worked-example `.tres` (loads, validates, has 5 anchors of correct kinds, all anchor chunk_ids resolve, all pool chunk_ids resolve, exit declares cross-zone target into S2).

## Out of scope

- `assemble_floor(chunks, zone_def, seed)` runtime — sibling procgen spike (`86c9xub9p`).
- S1 retrofit to ZoneDef shape — W2 impl ticket.
- Quest-state binding (Commitment 3 `zone_id` references from quest `.tres`) — Track 3 W2 ticket.
- Map UI consumption (`display_name` rendering) — Track 4 W2 ticket.

## Schema review request

**Devon** + **Priya** — please review the data shape:

- **Devon** — your `assemble_floor(chunks_by_id, zone_def, seed)` consumes `ZoneDef`. Signature is documented in `level-chunks.md` § "Hand-authored vs procedural split" of this PR. Check that the fields the assembler needs are present and correctly typed: `anchors` (ordered placement), `procedural_slot_pool` (StringName ids, not Resource refs), `min/max_slots_between_anchors` (inclusive bounds), `port_mating_rules` (default empty = inherit chunk-level discipline). Flag any field you'd want renamed or restructured BEFORE you start the procgen spike — easier to rename now than after the runtime consumes them.
- **Priya** — your future quest authoring (Commitment 3 Track 3 W2) wires `zone_id` references into quest `.tres` resources. Check the StringName convention (`s{stratum}_z{ordinal}_{slug}`) and the anchor `room_id` shape (used for `quest_target_room_id` binding). The worked example demonstrates the convention with `s1_z1_threshold / s1_z1_antechamber / s1_z1_marksmans_perch / s1_z1_bossward / s1_z1_descent`.

## Self-Test Report

Posted as a follow-up comment per `self-test-report-gate`.

## Cross-references

- `team/priya-pl/post-wave3-sequencing.md` v1.1 §1 Commitment 3 + Commitment 5 + §4 W1 pre-shape + §7 R-PROCGEN
- `team/drew-dev/level-chunks.md` § "Why chunks" + § "Why ports, not free-form transitions" + the new § "Zone schema"
- `team/tess-qa/m3-acceptance-plan-tier-3.md` rows `ZQ-1` through `ZQ-8` + `TI-36` (ZoneDef schema validates required keys)
- Sibling procgen spike: ticket `86c9xub9p` (consumes ZoneDef)
- ClickUp: [`86c9xuap4`](https://app.clickup.com/t/86c9xuap4)

## Risk note

R-PROCGEN.b (chunk-port mating gaps at procedural seams) is mitigated by reusing the chunk-level port-mating code path for cross-zone seams — same code path mates intra-zone and cross-zone seams, so a single port-mating fix lands at both. Documented in § "Cross-zone transitions" of the doc extension.

## Done clause

- [x] `## Zone schema` section + 6 sub-sections landed in `level-chunks.md`
- [x] `ZoneDef.gd` + `ZoneAnchor.gd` Resource classes
- [x] `s1_z1_outer_cloister.tres` worked example (5 anchors, 4-chunk pool)
- [x] Paired GUT (`tests/test_zone_def.gd`) — Resource-load smoke + `validate()` invariants + worked-example round-trip
- [x] Cross-references to procgen-spike sibling ticket + post-Wave-3-sequencing.md §1 Commitments 3+5
- [x] Schema review request flags Devon + Priya inline
- [ ] CI green (pending)
- [ ] ClickUp `86c9xuap4` → `ready for qa test` on PR open
- **Regression guard:** no existing chunk schema fields changed; `LevelChunkDef.gd` / `MobSpawnPoint.gd` / `ChunkPort.gd` untouched. Existing `tests/test_level_chunk.gd` (28 tests) is untouched; new `tests/test_zone_def.gd` is purely additive.
