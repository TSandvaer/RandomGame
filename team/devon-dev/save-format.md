# Save format — Embergrave JSON saves

**Owner:** Devon (engine)
**Status:** v1, M1 baseline. Forward-compat migration in `scripts/save/Save.gd::migrate()`.

## File location

- Path: `user://save_<slot>.json`
- Slots: integer, currently `0` is the only slot M1 uses. Slots are reserved
  in the API so M2 multi-character isn't a refactor.
- Godot's `user://` resolves to:
  - Windows: `%APPDATA%\Godot\app_userdata\Embergrave\`
  - macOS: `~/Library/Application Support/Godot/app_userdata/Embergrave/`
  - Linux: `~/.local/share/godot/app_userdata/Embergrave/`
  - HTML5: IndexedDB under the itch.io domain (per Godot 4.3 web export).

## Envelope (top level)

```json
{
  "schema_version": 1,
  "saved_at": "2026-05-01T15:30:42",
  "data": { ... }
}
```

| Field            | Type    | Notes |
|------------------|---------|-------|
| `schema_version` | int     | Bumped whenever a non-additive change ships. Drives migration. |
| `saved_at`       | string  | ISO8601 UTC datetime, second resolution. Display-only — never logic. |
| `data`           | object  | The actual game state. Shape below. |

## `data` (v1)

```json
{
  "character": {
    "name": "Ember-Knight",
    "level": 1,
    "xp": 0,
    "vigor": 0,
    "focus": 0,
    "edge": 0,
    "hp_current": 100,
    "hp_max": 100
  },
  "stash": [],
  "equipped": {},
  "meta": {
    "runs_completed": 0,
    "deepest_stratum": 1,
    "total_playtime_sec": 0.0
  }
}
```

### `character`

| Field         | Type   | Notes |
|---------------|--------|-------|
| `name`        | string | Future M2 — multi-character. M1 always "Ember-Knight". |
| `level`       | int    | 1–5 in M1, 1–30 cap in M3. Saturation at cap is enforced by the level-up code, not here. |
| `xp`          | int    | Cumulative XP. Level boundaries computed at runtime from a curve owned by Drew. |
| `vigor`       | int    | Stat point — HP / damage taken multiplier. Allocated via level-up UI. |
| `focus`       | int    | Stat point — relic ability cooldowns / cast speed. M2-relevant; sits at 0 in M1. |
| `edge`        | int    | Stat point — crit chance + crit damage. |
| `hp_current`  | int    | Snapshot at save time. On load, clamped to `hp_max`. |
| `hp_max`      | int    | Derived value, but persisted so a balance change to derivation doesn't quietly mutate saves. |

### `stash`

Array of item dicts. Each item:

```json
{
  "id": "weapon_iron_sword",
  "tier": 2,
  "rolled_affixes": [
    { "affix_id": "swift", "value": 0.08 },
    { "affix_id": "vigor", "value": 4 }
  ],
  "stack_count": 1
}
```

Item content (base stats, affix definitions) lives in TRES under `resources/items/`,
authored by Drew (see `team/drew-dev/tres-schemas.md`). The save only references items
**by id + tier + rolled affixes**. Reroll-on-load is forbidden — saved rolls are sticky.

### `equipped`

Map of slot name -> item dict (same shape as a stash entry). M1 slots: `weapon`,
`armor`. M2 widens to `off_hand`, `trinket`, `relic`. Empty / unset slot = key absent.

### `meta`

Run-level / lifetime aggregates. Cheap to track, expensive to lose.

| Field                | Type  | Notes |
|----------------------|-------|-------|
| `runs_completed`     | int   | Number of stratum-1 boss kills (M1) or stratum-N boss kills (M2+). |
| `deepest_stratum`    | int   | Personal-best depth marker. Drives the run-summary screen. |
| `total_playtime_sec` | float | Wall-clock seconds of `_process` time logged. Cosmetic. |

## Migration policy

- **Additive changes** (new field) — no version bump required. Code that
  reads the field defaults if absent. Tests must verify "old save → new
  code → loads with default for new field".
- **Non-additive changes** (rename, type change, removed field, semantics
  change) — bump `SCHEMA_VERSION` and add a `_migrate_vN_to_vN+1` step in
  `Save.gd`. Add a forward-compat test that authors a vN payload by hand
  and asserts it loads cleanly under the new version.
- **Newer save in older runtime** — pass through as-is and `push_warning`.
  The runtime ignores fields it doesn't know about. We never refuse-load.

## Tester notes (for Tess)

- Quit-and-relaunch test: save in stratum 1 → exit → relaunch → load → confirm
  character level + stash + equipped persist exactly.
- Crash test: kill the process during a save write (mid-stroke). The
  atomic-write helper writes to `<file>.tmp` then renames, so the worst case
  is "the save you tried to make didn't happen" — the previous save file
  must remain valid.
- Schema-newer test: hand-author a save with `schema_version: 999` and load
  it. Should warn-and-pass-through, never crash.
- Schema-older test: hand-author a save with `schema_version: 0` and load
  it. Should silently migrate to v1 and add the missing `meta` block.
- Empty-data test: hand-author `{ "schema_version": 1, "data": {} }`. Load
  should return `{}` or a populated default? **Decision:** load returns
  the empty dict as-is; the gameplay code (PlayerController on new game)
  decides whether to treat that as a corrupt save or a new game. Document
  if this changes.
- HTML5 quirk: IndexedDB access is async. `Save.save_game()` schedules a
  flush; in Godot 4.3 the flush happens by next frame. For Tess's test
  matrix, "save → quit → relaunch" must include a frame between save and
  quit (not a synchronous `get_tree().quit()` immediately after save).
