# Save Architecture — version-gate, additive reads, backfill patterns

What this doc covers: the load-bearing patterns used by `scripts/save/Save.gd` to handle save-data evolution across schema versions. The system shipped incrementally — `_upgrade_payload` version-gate (v0→v1→v2→v3→v4), `has()`-guard additive reads for forward-compat fields (W2-T6 era), and unconditional-backfill outside the version-gate for tier-3 quest fields (PR #352). Each pattern has a distinct when-to-use and when-not-to-use.

## Version-gate pattern — `_upgrade_payload(payload, from_version)`

The canonical migration path: when `Save.gd::migrate()` sees a save-file whose `schema_version` is older than the runtime's `CURRENT_SCHEMA_VERSION`, it calls `_upgrade_payload(payload, from_version)` which dispatches per-version transformer functions (`_migrate_v0_to_v1`, `_migrate_v1_to_v2`, ...) in sequence. Each transformer is a pure function: take a payload at version `N`, return a payload shaped for version `N+1`.

**When to use:** when a save-schema change is non-backward-compatible — a field rename, a type change, a structure flattening, a removed field that needs translation. The version-gate guarantees old saves get explicit handling; the per-version chain is straightforward to test (one fixture per version, assert each step).

**When NOT to use:** for additive fields where the read-site can default cleanly (see `has()`-guard pattern below). Bumping the schema-version every time you add a field is high-cost — every migration step has to be authored, paired with a test fixture, and verified end-to-end. Reserve version-bumps for genuinely breaking changes.

**Cite:** `scripts/save/Save.gd::_upgrade_payload` (line varies — grep for the function). Test fixtures live at `tests/test_save_migration.gd` with one test per version-step.

## Additive `has()`-guard read pattern — same-version forward-compat

When adding a NEW optional field to an existing schema without bumping the version, the read site must guard against the field's absence on saves written before the field existed:

```gdscript
# inside Save.gd::restore() or per-system from_save_dict()
var new_field = payload.get("new_field_id", default_value)
# OR:
if payload.has("new_field_id"):
    obj.new_field = payload["new_field_id"]
# else: obj.new_field already has its constructor default
```

The constructor default on the receiving object is the authoritative source of truth for "what the field looks like when absent from save." Old saves get the constructor default; new saves get the persisted value; both code paths read the same field after `restore()`.

**When to use:** purely-additive features where a missing field can be filled with a sensible default at read time. Single-NPC questgivers, optional cosmetic flags, late-added telemetry counters. The vast majority of M2/M3-era field additions fit this pattern.

**When NOT to use:** when the absence of the field is itself semantically meaningful (e.g. "this save is from a build before the feature shipped, so we need to backfill against current-build defaults," see below).

**Cite:** widespread in `Save.gd::restore()` and per-system `from_save_dict` methods. The pattern was formalized by W2-T6 (PR #352) as the right shape for active_bounty + completed_bounties — but the pattern predates W2-T6 in spirit.

## Backfill outside the version-gate — `_backfill_<scope>_<fields>()` (PR #352 / W2-T6 pattern)

The pattern shipped with PR #352 (`scripts/save/Save.gd::migrate()` calls `_backfill_v5_tier3_quest_fields(payload)` unconditionally, NOT inside the version-gate). The backfill runs **on every load**, not just on version-bumps — including same-version reloads of a save that lacks the field because the build that wrote it didn't yet know about the field.

```gdscript
# scripts/save/Save.gd::migrate (simplified)
func migrate(payload: Dictionary) -> Dictionary:
    var from_version = payload.get("schema_version", 0)
    if from_version < CURRENT_SCHEMA_VERSION:
        payload = _upgrade_payload(payload, from_version)
    # backfill runs AFTER the version-gate, on every load
    _backfill_v5_tier3_quest_fields(payload)
    return payload
```

**Why the unconditional placement (outside the version-gate):** Tier-3 quest fields were added inside the v5 era — the build that introduced them was already on `schema_version = 5`. A save written by an earlier v5 build (before the quest fields landed) reads as `schema_version = 5` too — but it lacks the fields. The version-gate sees `from_version == CURRENT_SCHEMA_VERSION` and skips `_upgrade_payload` entirely; without the unconditional backfill, the missing-field state propagates to the read sites.

**The trap this avoids:** treating "save is on the current schema version" as equivalent to "save has every field the current build expects." That equivalence holds across version-bumps (because the migration chain enforces it) but NOT across feature additions within a version (because nothing enforces it). The unconditional backfill is the feature-addition counterpart of the version-gate's version-bump enforcement.

**When to use:** when adding a new field that must have a real value (not just a read-site default) at runtime — e.g. typed Resource references, Player fields that downstream signals rely on. The unconditional backfill writes a defaulted instance into the payload so subsequent `restore()` reads see a non-null shape.

**When NOT to use:** when the read-site's `has()`-guard + constructor default is sufficient. Most fields don't need backfill; reserve the pattern for cases where downstream code would crash on missing-field rather than gracefully default.

**Cite:** `scripts/save/Save.gd::_backfill_v5_tier3_quest_fields` (PR #352, merge commit `8a0cc76`, ticket `86c9y7ydg`). Paired GUT test: `tests/test_save_migrate_quest_fields_backfill.gd` — asserts v3 / v4 / v5-pre-tier3 saves all backfill correctly to v5-with-tier3 shape on load.

## Combining patterns — additive read + backfill on the same field

Some fields warrant BOTH a `has()`-guard read AND an unconditional backfill. Example: `active_bounty` (PR #352). The read site uses `has()`-guard for defensive null-safety, AND the migration step unconditionally writes a `null` default into the payload. The two layers handle different failure modes:

- **`has()`-guard at read site** — covers code paths that bypass `migrate()` (in-memory payload construction, direct test fixture loads, mid-session round-trips that don't re-migrate).
- **Unconditional backfill in `migrate()`** — covers the "load a save written before the field existed" case explicitly so the read sites can simplify post-migrate.

Belt-and-braces is acceptable for high-stakes fields (anything Player or Save depends on). For low-stakes fields, pick one pattern based on the access surface.

## Cross-references

- `team/devon-dev/save-schema-v5-tier3-additions.md` — additive surface authoring notes; §2.1 + §2.5 cover the active_bounty / completed_bounties case-study
- `team/devon-dev/save-schema-v5-plan.md` — original v5 schema-bump plan (pre-tier3 surface)
- `tests/test_save_migration.gd` — version-gate test fixtures (one per version-step)
- `tests/test_save_migrate_quest_fields_backfill.gd` — backfill-outside-version-gate test fixtures (PR #352)
- `tests/test_quest_state_save_roundtrip.gd` — combined round-trip pin (write → save → migrate → restore → read)
- `.claude/docs/test-conventions.md` § "Universal warning gate" — `Save.migrate` is a load-bearing surface for `WarningBus.warn` per the migration policy section
