# M2 Week-1 Save Fixtures — shape catalog

**Owner:** Tess (QA) authors this index; **Devon** authors the actual JSON files when T1 (`feat(save): v3→v4 migration impl`) lands per `team/priya-pl/m2-week-1-backlog.md`. **Phase:** anticipatory — describes the fixture shapes so Devon knows exactly what to author; does NOT commit JSON content yet (that's an M2 implementation deliverable).

This catalog drives:
- INV-1..INV-8 round-trip invariants from `team/devon-dev/save-schema-v4-plan.md §5`.
- Devon's six-fixture catalog from `save-schema-v4-plan.md §6`.
- Tess's `tests/test_save_migration_v3_to_v4.gd` paired test file (see `tests/integration/M2-PAIRED-TEST-FILES.md`).

Existing v0 fixtures (`save_v0_pre_migration.json`, `save_v0_empty_inventory.json`, `save_v0_malformed_item.json`) stay unchanged — they continue to drive the v0→v1→v2→v3→v4 chain via INV-6.

---

## Naming convention + location

All fixtures live under `tests/fixtures/`. Naming pattern matches existing v0 catalog: `save_v<N>_<shape>.json`.

Six new fixtures for M2 week-1 — four v3 sources + two v4 sources:

| # | Filename | Schema | Drives invariants |
|---|---|---|---|
| 1 | `save_v3_baseline.json` | v3 | INV-1, INV-2, INV-3, INV-4, INV-5 |
| 2 | `save_v3_full_inventory.json` | v3 | INV-5 (root-stash preservation) |
| 3 | `save_v3_max_level.json` | v3 | INV-5 (level/xp survive verbatim) |
| 4 | `save_v3_partial_corruption.json` | v3 | defensive-guard branches in `_migrate_v3_to_v4` |
| 5 | `save_v4_baseline.json` | v4 | INV-7 (idempotence on already-v4 data) |
| 6 | `save_v4_with_stash.json` | v4 | INV-7 (idempotence with non-default values) |

(Devon's plan doc enumerated 6 fixtures with slightly different names — `save_v3_baseline / save_v3_empty_inventory / save_v3_max_level_capped / save_v3_full_inventory / save_v3_partial_corruption / save_v4_idempotent_baseline`. The names below are aligned with the dispatch's suggestions and the Tess-authored shape catalog. **Devon picks the canonical filenames at impl time** — both naming schemes describe the same six fixture shapes; the shape contracts below are authoritative.)

**Optional 7th fixture (deferred):** `save_v4_with_ember_bag.json` — a v4 save with `character.ember_bags["1"]` populated. Useful for INV-7 with bags + for T7 / T8 paired tests. Devon's call whether to author at T1 time or punt to T7 dispatch.

---

## Fixture 1 — `save_v3_baseline.json`

**Purpose:** the "happy path" v3 save — typical mid-game. The primary fixture for INV-1..INV-5; loaded by every backfill assertion as the canonical input.

**Schema shape (v3 envelope + character block):**

```
{
  "schema_version": 3,
  "saved_at": "<ISO-8601 timestamp>",
  "data": {
    "character": {
      "name": "Old-Knight",                  // matches v0 baseline name (per save-schema-v4-plan.md §6)
      "level": 4,                            // mid-game (range 4..5 valid for "baseline")
      "xp": 1850,                            // pinned to match v0→v3 chain projection (INV-6)
      "xp_to_next": 2200,                    // matches v3 Levels XP curve at level 4
      "vigor": 2,                            // v2 compat shadow (range 0..3 valid)
      "focus": 1,                            // v2 compat shadow
      "edge": 0,                             // v2 compat shadow
      "stats": {
        "vigor": 2,                          // mirror of compat shadow (v3 design intent)
        "focus": 1,
        "edge": 0
      },
      "unspent_stat_points": 0,              // 0 for "fully allocated" baseline
      "first_level_up_seen": true,           // baseline assumes level-up panel triggered earlier
      "hp_current": 95,                      // value range 1..hp_max
      "hp_max": 100                          // baseline; will track stat-vigor-derived in M2 if relevant
    },
    "stash": [                               // root-level v1 stub stash; v3 baseline has 2-3 entries
      { "id": "shortsword_t1", "tier": 1, "rolled_affixes": [...], "stack_count": 1 },
      { "id": "hauberk_t2", "tier": 2, "rolled_affixes": [...], "stack_count": 1 }
    ],
    "equipped": {
      "weapon": { "id": "shortsword_t2", "tier": 2, "rolled_affixes": [...], "stack_count": 1 },
      "armor":  { "id": "hauberk_t1",   "tier": 1, "rolled_affixes": [...], "stack_count": 1 }
    },
    "meta": {
      "runs_completed": 3,                   // mid-game cumulative
      "deepest_stratum": 1,                  // M1 floor; M2 saves will bump to 2 once S2 unlocks
      "total_playtime_sec": 1260.0           // 21 min — mid-game range
    }
  }
}
```

**Round-trip invariants this fixture drives:**
- INV-1: loads clean under v4 runtime; non-empty Dictionary; character block intact.
- INV-2: post-load, `character.stash` exists, is Array, `size() == 0` (NEW backfilled empty stash, separate from root-level stash).
- INV-3: post-load, `character.ember_bags` exists, is Dictionary, `is_empty() == true`.
- INV-4: post-load, `character.stash_ui_state.stash_room_seen == false`.
- INV-5: every v3 field bit-identical post-migration (level=4, xp=1850, V/F/E=2/1/0, stats.{V/F/E} same, equipped weapon/armor same, root-stash 2 entries verbatim, meta unchanged).

---

## Fixture 2 — `save_v3_full_inventory.json`

**Purpose:** edge — a v3 save with M1's 24-slot inventory packed. Drives INV-5 root-stash-preservation through the migration; rules out any "stash array mutation during v3→v4 transit" bug.

**Schema shape (delta vs. fixture 1):**

```
{
  "schema_version": 3,
  "data": {
    "character": { /* same shape as Fixture 1 */ },
    "stash": [
      // 24 entries — packed M1 stash
      { "id": "shortsword_t1", "tier": 1, ... },
      { "id": "shortsword_t2", "tier": 2, ... },
      // ... mix of T1/T2/T3 with varied affixes
      // gear-mix recommendation: ~10 weapons + ~10 armors + ~4 mixed for variety
    ],
    "equipped": {
      "weapon": { "id": "shortsword_t3", "tier": 3, ... },
      "armor":  { "id": "hauberk_t3",   "tier": 3, ... }
    },
    "meta": { /* mid-game numbers */ }
  }
}
```

**Round-trip invariants:**
- INV-5: all 24 root-stash entries survive bit-identical post-migration. Affix value floats survive (no float-precision drift). `character.stash` (NEW) is empty `[]` regardless of root-stash state.
- INV-2: `character.stash` is empty (the v4 "active" path is independent of root-stash).

---

## Fixture 3 — `save_v3_max_level.json`

**Purpose:** edge — level-cap (level 5 in M1). Drives INV-5 with level/xp at the boundary, plus `unspent_stat_points: 0` + `first_level_up_seen: true`.

**Schema shape (delta vs. fixture 1):**

```
{
  "schema_version": 3,
  "data": {
    "character": {
      "name": "Old-Knight",
      "level": 5,                            // M1 level cap
      "xp": 5000,                            // at the L5 floor (level-cap value)
      "xp_to_next": 5000,                    // boundary value (or 0 / -1 / sentinel — match Levels.gd contract)
      "vigor": 5,                            // fully allocated stats
      "focus": 3,
      "edge": 2,
      "stats": { "vigor": 5, "focus": 3, "edge": 2 },
      "unspent_stat_points": 0,
      "first_level_up_seen": true,
      "hp_current": 200,                     // higher max-hp from full-allocation
      "hp_max": 200
    },
    "stash": [],                             // empty root-stash for shape variety
    "equipped": {
      "weapon": { "id": "shortsword_t3", ... },
      "armor":  { "id": "hauberk_t3",   ... }
    },
    "meta": { "runs_completed": 8, "deepest_stratum": 1, "total_playtime_sec": 4200.0 }
  }
}
```

**Round-trip invariants:**
- INV-5: level=5, xp at L5 floor, stats fully allocated all survive bit-identical. No clamping during migration.

---

## Fixture 4 — `save_v3_partial_corruption.json`

**Purpose:** edge — a v3 save with `character.stats` present but missing `unspent_stat_points` (simulating a hand-edited or partially-rolled-back save). Drives the defensive-guard branches in `_migrate_v3_to_v4` per save-schema-v4-plan.md §3 commentary.

**Schema shape (delta vs. fixture 1):**

```
{
  "schema_version": 3,
  "data": {
    "character": {
      "name": "Old-Knight",
      "level": 3,
      "xp": 800,
      "xp_to_next": 1500,
      "vigor": 1,
      "focus": 1,
      "edge": 0,
      "stats": { "vigor": 1, "focus": 1, "edge": 0 },
      // NOTE: "unspent_stat_points" deliberately ABSENT
      "first_level_up_seen": false,
      "hp_current": 60,
      "hp_max": 80
    },
    "stash": [],
    "equipped": {},
    "meta": { /* baseline numbers */ }
  }
}
```

**Round-trip invariants:**
- migration must NOT crash on the missing key.
- migration must NOT introduce v4 fields based on missing v3 fields (only the documented v4 deltas: stash + ember_bags + stash_ui_state).
- After migration, `character.unspent_stat_points` either: (a) stays absent (defensive — let the consumer's `.get` handle it), OR (b) is backfilled to `0` per `DEFAULT_PAYLOAD["character"]["unspent_stat_points"]`. **Devon's call** — but the fixture must surface the choice for explicit pinning, not let it ride as undefined behavior.
- Post-migration, the three v4 fields (`character.stash`, `character.ember_bags`, `character.stash_ui_state`) are present at default values regardless of the corruption.

---

## Fixture 5 — `save_v4_baseline.json`

**Purpose:** a hand-authored v4 save (`schema_version: 4`, all v4 fields present at default values). Drives INV-7 idempotence — re-running migration on already-v4 data is a no-op.

**Schema shape:**

```
{
  "schema_version": 4,                       // canonical v4 envelope
  "saved_at": "<ISO-8601 timestamp>",
  "data": {
    "character": {
      "name": "Old-Knight",
      "level": 4,
      "xp": 1850,
      "xp_to_next": 2200,
      "vigor": 2,
      "focus": 1,
      "edge": 0,
      "stats": { "vigor": 2, "focus": 1, "edge": 0 },
      "unspent_stat_points": 0,
      "first_level_up_seen": true,
      "hp_current": 95,
      "hp_max": 100,
      "stash": [],                           // NEW v4 — empty default
      "ember_bags": {},                      // NEW v4 — empty default
      "stash_ui_state": { "stash_room_seen": false }   // NEW v4 — first-visit-gate default
    },
    "stash": [
      { "id": "shortsword_t1", ... },
      { "id": "hauberk_t2", ... }
    ],
    "equipped": { /* same as fixture 1 */ },
    "meta": { /* same as fixture 1 */ }
  }
}
```

**Round-trip invariants:**
- INV-7: load → save → load → save → load is bit-identical. No double-backfill on the three new v4 fields. `schema_version` stays at 4 across the round-trip.
- INV-8: after first `save_game` call on this fixture, on-disk envelope `schema_version == 4`.

---

## Fixture 6 — `save_v4_with_stash.json`

**Purpose:** a v4 save with non-default values populated (stash entries + `stash_room_seen=true`). Drives INV-7 with realistic mid-game v4 state. Also exercises the slot-index sparse-array convention from save-schema-v4-plan.md §2.3.

**Schema shape (delta vs. fixture 5):**

```
{
  "schema_version": 4,
  "data": {
    "character": {
      // ... same as fixture 5 BASE ...
      "stash": [
        // 5 occupied stash entries — sparse array, with slot_index
        { "slot_index": 0,  "id": "shortsword_t2", "tier": 2, "rolled_affixes": [...], "stack_count": 1 },
        { "slot_index": 3,  "id": "hauberk_t1",   "tier": 1, "rolled_affixes": [...], "stack_count": 1 },
        { "slot_index": 12, "id": "shortsword_t3", "tier": 3, "rolled_affixes": [...], "stack_count": 1 },
        { "slot_index": 24, "id": "consumable_potion_minor", "tier": 1, "rolled_affixes": [], "stack_count": 5 },
        { "slot_index": 71, "id": "relic_seed_t2", "tier": 2, "rolled_affixes": [...], "stack_count": 1 }
      ],
      "ember_bags": {},                      // empty for this fixture; bag-with-content fixture is the deferred 7th
      "stash_ui_state": { "stash_room_seen": true }   // mid-game (room visited)
    },
    /* root data unchanged */
  }
}
```

**Round-trip invariants:**
- INV-7: round-trip preserves the 5-entry stash with slot indices `[0, 3, 12, 24, 71]` bit-identical.
- Slot indices are not re-compacted by save/load (sparse-array contract from save-schema-v4-plan.md §2.3 holds).
- `stash_room_seen=true` survives bit-identical.

---

## Optional 7th — `save_v4_with_ember_bag.json` (deferred)

**Purpose:** a v4 save with `character.ember_bags["1"]` populated. Useful for T7 / T8 paired tests. **Devon's call** whether to author at T1 time or punt to T7 dispatch.

**Schema shape sketch:**

```
{
  "schema_version": 4,
  "data": {
    "character": {
      // ... base shape from fixture 5 ...
      "ember_bags": {
        "1": {
          "stratum": 1,
          "room_id": "s1_room04",
          "x": 184.0,
          "y": 96.0,
          "items": [
            { "id": "shortsword_t2", "tier": 2, "rolled_affixes": [...], "stack_count": 1 },
            { "id": "hauberk_t1",   "tier": 1, "rolled_affixes": [...], "stack_count": 1 },
            { "id": "consumable_potion_minor", "tier": 1, "rolled_affixes": [], "stack_count": 3 }
          ]
        },
        "2": null                            // explicit null = no pending S2 bag (forward-compat per §2.4)
      }
    }
  }
}
```

**Drives:** T7 ember-bag invariants (atomic save before run-summary, pickup recovery, edge cases); T8 run-summary EMBER BAG section rendering.

---

## Round-trip invariants summary (Devon's INV-1..INV-8)

| ID | Invariant | Fixture(s) |
|---|---|---|
| INV-1 | v3 save loads clean under v4 runtime | 1, 2, 3, 4 |
| INV-2 | `character.stash` backfilled as empty Array | 1, 2, 3, 4 |
| INV-3 | `character.ember_bags` backfilled as empty Dictionary | 1, 2, 3, 4 |
| INV-4 | `character.stash_ui_state.stash_room_seen == false` | 1, 2, 3, 4 |
| INV-5 | v3 field preservation (level / xp / V/F/E / equipped / root-stash / meta) | 1, 2, 3, 4 |
| INV-6 | v0→v1→v2→v3→v4 chain ends at same place as direct-v3 fixture | existing v0 fixtures + 1 (target) |
| INV-7 | v4 round-trip is bit-identical (no double-backfill) | 5, 6 |
| INV-8 | After save, on-disk envelope `schema_version == 4` | 5, 6 (post-mutation save tick) |

---

## JSON-purity contract (per save-schema-v4-plan.md §2.6)

Every fixture file must contain ONLY:
- `Dictionary` (object)
- `Array` (list)
- `String`
- `int`
- `float`
- `bool`
- `null` (JSON null — used in `ember_bags["N"] = null` per §2.4)

No `PackedByteArray`, no Resource refs, no Object refs. JSON-pure round-trip via `JSON.stringify` + `JSON.parse_string` is the contract Tess's W3-A5 TI-1 / TI-2 / TI-3 audit established for M1; M2 v4 keeps it (TI-10..TI-15 extend it).

---

## Hand-off

- **Devon (T1 dispatch):** author the six fixture files. The shape contracts above are authoritative. Filename choice (`save_v3_max_level_capped.json` vs `save_v3_max_level.json` etc.) is Devon's editorial call; the shape contract is Tess's. Optional 7th `save_v4_with_ember_bag.json` is Devon's call to author at T1 time or defer to T7 dispatch.
- **Tess (T1 sign-off):** verify each fixture loads cleanly via `Save.load_game(slot)`; verify INV-1..INV-8 pin via paired test in `tests/test_save_migration_v3_to_v4.gd`; verify JSON-purity (TI-1 + TI-2 + TI-3 hold for v4 schema).
- **Future v5+ migrations:** this catalog grows additively. Add new fixtures (`save_v4_with_full_stash.json`, `save_v4_max_bags.json`, etc.) when v5 dispatch happens; keep existing fixtures stable for chain-migration tests.
