# Save migration fixtures

Where: `tests/fixtures/save_v<N>_<flavor>.json`. Loaded by `tests/test_save_migration.gd`.

Why fixture-based, not in-line dicts: a hand-authored JSON file pinned to disk preserves the on-disk shape that an old build actually wrote — whitespace, key order, missing fields. An in-memory dict drifts away from that contract over time. When v0 saves are gone from the wild, these files are the only ground truth.

This doc tells the next dev (likely Devon, when he adds level/XP changes that bump the schema) how to author a fresh fixture.

---

## Naming and layout

Pattern: `save_v<source_version>_<flavor>.json`

- `<source_version>` = the schema version the fixture represents *before* migration. It is what Save.gd would have read if the player closed the game on that build.
- `<flavor>` = a short tag describing the test case. Keep it lowercase, kebab/underscore.

Current fixtures (as of 2026-05-02 — v0→v1 boundary):

| File                                          | Flavor                | Test cases it covers                       |
|-----------------------------------------------|-----------------------|--------------------------------------------|
| `save_v0_pre_migration.json`                  | typical mid-run save  | core migration, all-fields-preserved       |
| `save_v0_empty_inventory.json`                | brand-new character   | edge-probe #1: empty inventory migrates    |
| `save_v0_malformed_item.json`                 | garbage in stash      | edge-probe #2: loader doesn't crash        |

When `Save.SCHEMA_VERSION` bumps to v2 (level/XP additions, run state, etc), author at least one `save_v1_*` fixture **before** changing `_migrate` so the test pins what the v1-on-disk shape actually was at the boundary.

---

## Format

The file contents must be EXACTLY what `save_game()` would have written at the source version, minus any fields that didn't exist yet.

For v0 (pre-v1 schema) that means:

```json
{
  "saved_at": "<iso8601>",
  "data": {
    "character": { ... },
    "stash": [ ... ]   // optional
    // NO `equipped`, NO `meta`, NO `schema_version`
  }
}
```

Notes:

- **`schema_version` MUST be omitted** for v0 fixtures. `Save.load_game` treats a missing key as v0 and triggers `_migrate_v0_to_v1`. Authoring `schema_version: 0` would also work today, but the realistic on-disk shape was no key at all.
- **`saved_at` is decorative** — Save.gd does not validate the timestamp. Use a plausible date; helps git blame future-readers reason about when the v0 build was current.
- **Field omissions are intentional** — the fixture's job is to exercise the backfill paths in `_migrate_v0_to_v1`. Listing all fields would defeat the test.

---

## Adding a new fixture (v1 → v2 example)

When Devon adds a `run` block (depth, position, in-progress combat) for v2:

1. **Author `save_v1_pre_v2_migration.json`** — copy the current `default_payload()` shape from `Save.gd`, with `schema_version: 1` set. This locks the v1 contract for future tests, even after the runtime moves to v2.
2. **Add a new test case** to `tests/test_save_migration.gd`:
   ```gdscript
   func test_v1_to_v2_adds_run_block_with_defaults() -> void:
       _install_fixture_at_slot(FIXTURE_V1, TEST_SLOT)
       var loaded = _save().load_game(TEST_SLOT)
       assert_true(loaded.has("run"), "v1->v2 backfills run block")
       # ...defaults assertions...
   ```
3. **Update this doc** — append the new fixture to the table above; add a new "v1 fixture format" section with the v1-on-disk JSON shape.
4. **Do NOT modify the existing v0 fixture(s)** — they are still the source of truth for the v0→v1 boundary, and a future "smart migration" change MUST keep them passing.

---

## Schema-version envelope contract (current)

`Save.gd` writes:

```json
{
  "schema_version": <SCHEMA_VERSION>,
  "saved_at": "<iso8601>",
  "data": <payload>
}
```

When you load, `data` is fed through `migrate(data, from_version)` and the latest-version dict comes back. The on-disk file is **not** rewritten by load alone — only the next save call upgrades the envelope. This is intentional (read-only browsers don't mutate user data).

Tests assert this in `tests/test_save_migration.gd::test_migration_leaves_envelope_schema_version_intact_on_disk_until_save`.

---

## When CI fails on these tests

The fixture is the contract. If a test in `test_save_migration.gd` fails, **the schema regressed in a way that breaks an old save**. Before "fixing" the test by editing the fixture, ask:

- Did `_migrate_v0_to_v1` lose a backfill?
- Did `default_payload()` lose a field that the migration was supposed to backfill from?
- Did someone change the on-disk envelope shape (`schema_version` → `version`, etc)?

If any of those: revert the offending change OR add a follow-up `_migrate_v1_to_v2` step (and a fresh `save_v1_*` fixture per above). **Never** edit a vN fixture to make a vN→vN+1 test pass — that defeats the entire purpose of pinning the boundary.
