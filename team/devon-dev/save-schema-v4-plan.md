# Save schema v3 → v4 forward-compat plan (M2 stash + ember-bag)

**Owner:** Devon (engine) · **Phase:** M2 onset (design-only; implementation lands in M2) · **Drives:** M2 stash UI + ember-bag recovery pattern (Uma `stash-ui-v1.md`), Tess's M2 migration test fixtures, future SaveSchema autoload.

This doc is the W3-B4 deliverable per Priya's `team/priya-pl/week-2-retro-and-week-3-scope.md` row B4. It specifies the v3 → v4 schema delta, migration function, forward-compat strategy, round-trip invariants, test fixture catalog, and HTML5/OPFS impact. **Nothing here ships in M1.** The migration code itself lands in an M2 implementation PR after Sponsor's M1 soak gate clears.

---

## TL;DR

- **Additive-only:** Y. Zero existing v3 fields are renamed, retyped, removed, or re-keyed. v4 = v3 ∪ four new keys.
- **Field count delta:** +4 top-level keys under `data{}` (`character.stash`, `character.ember_bags`, `character.stash_ui_state`, plus an internal-touch on `meta` for one already-present key — net +3 distinct concepts; `meta.runs_completed` / `meta.deepest_stratum` / `meta.total_playtime_sec` already exist in v3 and are unchanged).
- **Size delta on a typical save:** +5–10 KB (72 stash slot entries with default-empty representation + up to 8 ember-bag entries). Well within OPFS browser-default quotas (~10–60 MB).
- **JSON-encodable:** Y for every new field. No Resource refs, no PackedByteArray, no Object refs — only Dictionary / Array / int / float / String primitives.
- **Migration shape:** `_migrate_v3_to_v4(data)` follows the existing v0→v1, v1→v2, v2→v3 idiom — defensive `has()` guards, default-value backfill, idempotent no-op when fields already present.
- **Open questions for Sponsor/Priya/orchestrator:** 4 (catalogued in §9).

---

## 1. Source of truth

This plan extends and is bounded by these prior artifacts. Any conflict resolves in favor of the source listed (this doc is downstream of all of them):

1. **Uma `team/uma-ux/stash-ui-v1.md` §5 — Implementation notes for Devon.** Calls for additive-only v3 → v4 with empty stash + zero bags for legacy saves. The exact field shape proposed below is grounded in Uma's §5 example JSON, with one structural deviation (see §3 — bags placed under `character.` not at root, for symmetric reset-on-fresh-character behavior with the rest of the character block).
2. **DECISIONS.md 2026-05-02 — M1 death rule.** "M1 keeps level + equipped, loses unequipped + run-progress. M2 introduces stash UI + ember-bag at the death point." This doc is the schema substrate for that promise.
3. **DECISIONS.md 2026-05-02 — Save schema v2 → v3 (level-up allocation).** Establishes the additive-shadow pattern (v2 flat fields preserved; new `stats` block lifted from them). v4 follows the same pattern: never delete, always add.
4. **`scripts/save/Save.gd`** — current v3 implementation, `SCHEMA_VERSION = 3`, three migration functions (`_migrate_v0_to_v1`, `_migrate_v1_to_v2`, `_migrate_v2_to_v3`), `DEFAULT_PAYLOAD` constant. All shapes here verified by direct read of Save.gd at SHA `c8a6b69` (M1 tip).
5. **`tests/test_save_migration.gd`** — current migration test pattern (fixture-based, hand-authored on-disk JSON, verbatim round-trip check). v3 → v4 test will follow this exact idiom.
6. **`team/devon-dev/save-format.md`** — current v1 baseline with M1 evolution notes. v4 needs a downstream update of this doc when the migration ships, but that's an M2 task; this plan-doc is the bridge.

---

## 2. Schema v3 → v4 delta

### 2.1 What v3 already has (verified from `Save.gd::DEFAULT_PAYLOAD`)

```
data:
  character:
    name: String
    level: int
    xp: int
    xp_to_next: int
    vigor: int            # v2-flat shadow, retained as compat
    focus: int            # v2-flat shadow, retained as compat
    edge: int             # v2-flat shadow, retained as compat
    stats:
      vigor: int
      focus: int
      edge: int
    unspent_stat_points: int
    first_level_up_seen: bool
    hp_current: int
    hp_max: int
  stash: Array            # already a stub (v1 backfilled it as []); v4 promotes it
  equipped: Dictionary    # slot -> item dict
  meta:
    runs_completed: int        # already present in v3 — no change in v4
    deepest_stratum: int       # already present in v3 — no change in v4
    total_playtime_sec: float  # already present in v3 — no change in v4
```

**Verification note:** The dispatch suggested `character.runs_completed`, `character.deepest_stratum`, `character.total_playtime_sec` "may already exist in v3 — verify." Confirmed by Save.gd line 76-80: these three fields exist on `meta`, not on `character`. v4 does NOT move them. They stay on `meta` because they are run/lifetime aggregates, not character-allocation state. Cross-character (M3) sharing semantics are clearer with them on `meta`.

### 2.2 v4 additive table

| Path | Type | Default on migration | JSON-encodable | Notes |
|---|---|---|---|---|
| `character.stash` | Array of (Dictionary or null) | `[]` (empty array — see §2.3) | Y | The 72-slot between-runs pool (Uma §5). Ember-bag recovery overflows into here when inventory is full. Already has a stub slot at v1+ — v4 just *populates* it with real per-slot semantics. |
| `character.ember_bags` | Dictionary keyed by stratum-id-as-String | `{}` (empty map — no pending bags) | Y | One entry per stratum. Cap = 8 entries (one per stratum). One-bag-per-stratum-replacement rule lives in M2 game code, not in the schema. Per Uma §5 the key is a stringified int (`"1"`, `"2"`) for Godot JSON Dictionary ergonomics — the Dict keys must be strings on the JSON wire even if conceptually ints. |
| `character.stash_ui_state` | Dictionary | `{ "stash_room_seen": false }` | Y | Persistent UI state for the stash room first-visit hint-strip (Uma §5). Sub-keys can grow additively in v5+ without another schema bump. |

That's the entire v4 delta. Three new top-level character keys, all JSON-pure dicts/arrays/primitives.

### 2.3 Stash slot representation — empty-slot convention

Uma's §5 shows `"stash": [ /* array of item dicts */ ]`. Two valid encodings exist for a 72-slot grid:

**Option A — sparse array, push-only:** the array contains only occupied slots. Slot index is bookkeeping, derived at load time from a separate "slot index" int per entry, OR by simple compaction (first item is "first slot," etc.).

**Option B — dense array of length-72, with `null` for empty slots:** the array is always exactly 72 long; `null` entries denote empty slots; non-null entries are item dicts.

**Recommendation: Option A (sparse array).** Three reasons:
- **Save size:** Option B forces ~72 × 4-byte `null` writes for a fresh character. Option A writes `[]` until the player actually puts something in. Median save (early game) is ~3 KB on Option A vs ~3.5 KB on Option B — small per-save but matters for OPFS quota over many slots.
- **Forward-compat:** if M3 wants 96 slots or 120 slots (per Uma §1's stash-size lever), Option A doesn't need a re-pad migration. Option B does.
- **Mirrors current `stash` stub.** v1+ already has `stash: []` — the existing `_migrate_v0_to_v1` line 220 backfills it as an empty array, not a 72-null array. Option A preserves this. Switching to Option B would require either retroactively padding existing v3 saves to 72-null on `_migrate_v3_to_v4` (a small but non-zero migration cost) or accepting an asymmetry where v3 saves load as `[]` and only get padded after a write. Sparse stays sparse.

**Slot-index-on-entry:** with Option A, each populated stash entry needs an explicit `slot_index: int` field so the UI knows where to render it. Slot indices are 0-71. The M2 stash code is responsible for keeping indices unique within the array; the schema doesn't enforce it (the UI reading the array can dedup with last-write-wins on collision).

**Stash entry shape (M2 will author the formal contract; sketched here for completeness):**

```
{
  "slot_index": int,           # 0 .. 71
  "id": String,                # ItemDef id, same as inventory entries
  "tier": int,
  "rolled_affixes": Array,     # same shape as inventory[].rolled_affixes
  "stack_count": int           # 1 for gear, 1..99 for stackables
}
```

### 2.4 Ember-bag entry shape

Per Uma §2 + §5 — keyed by stratum int (string-encoded for JSON):

```
"character": {
  "ember_bags": {
    "1": {
      "stratum": int,             # redundant with key; canonical for in-memory access
      "room_id": String,          # "s1_room04" — matches Drew's chunk-id namespace
      "x": float,                 # death tile world-px
      "y": float,
      "items": Array              # array of item dicts (stash-entry shape minus slot_index)
    },
    "2": null                     # explicit null = no pending bag (preferred over key-absent
                                  # for forward-compat: v5+ might add per-stratum metadata
                                  # like "scorched" tier even when no bag is pending)
  }
}
```

**Cap of 8** (one per stratum) is enforced at write time by M2 game code, not at schema level. The schema permits arbitrary keys; the game layer rejects insertions beyond 8 unique strata.

**Why under `character.` not at root?** Uma §5 sketched `pending_ember_bags` at the root of `data{}`. I'm placing it under `character.` for two reasons:
- **Reset-on-new-character symmetry.** All character-scoped state (level, XP, stats, equipped, stash, bags) resets when a new character is created. Putting bags under `character.` means a single `character = default_payload().character` reset clears bags. Putting them at root means M2 has to remember a separate "also clear bags" step.
- **M3 multi-character readiness.** `team/devon-dev/save-format.md` already reserves slot for multi-character. Multi-character means each character has their own stash + bags. `character.stash` + `character.ember_bags` align cleanly; `pending_ember_bags` at root would force a refactor when M3 lands.

This is the **one structural deviation from Uma's §5**. I'll flag it in DECISIONS.md and confirm with Uma in the M2 implementation PR.

### 2.5 Renamed: `pending_ember_bags` → `ember_bags`

Uma §5 wrote `pending_ember_bags`. I'm renaming to `ember_bags` because:
- Every bag in this dict is by definition pending — there's no concept of a "settled" or "recovered" bag in the dict (recovered bags are deleted from the dict). The "pending_" prefix is redundant.
- Shorter wire-format (small but adds up across 8 entries).

Both are valid; this is editorial. If Uma prefers the original, swap on the way to implementation — both are JSON-pure and the migration code would be a one-character change.

### 2.6 JSON-encodable verdict

Each v4 field, audited for JSON-purity (the constraint Tess is auditing in W3-A5 HTML5 work):

| Field | Type | Resource ref? | PackedByteArray? | Object ref? | Verdict |
|---|---|---|---|---|---|
| `character.stash` (array) | Array of Dict | N | N | N | **JSON-pure** |
| `character.stash[].id` | String | N | N | N | **JSON-pure** |
| `character.stash[].tier` | int | N | N | N | **JSON-pure** |
| `character.stash[].rolled_affixes` | Array of Dict | N | N | N | **JSON-pure** (same as inventory) |
| `character.stash[].slot_index` | int | N | N | N | **JSON-pure** |
| `character.stash[].stack_count` | int | N | N | N | **JSON-pure** |
| `character.ember_bags` (dict) | Dictionary[String, Dict\|null] | N | N | N | **JSON-pure** |
| `character.ember_bags["N"].stratum` | int | N | N | N | **JSON-pure** |
| `character.ember_bags["N"].room_id` | String | N | N | N | **JSON-pure** |
| `character.ember_bags["N"].x/y` | float | N | N | N | **JSON-pure** |
| `character.ember_bags["N"].items` | Array of Dict | N | N | N | **JSON-pure** |
| `character.stash_ui_state` (dict) | Dictionary | N | N | N | **JSON-pure** |
| `character.stash_ui_state.stash_room_seen` | bool | N | N | N | **JSON-pure** |

All Y for JSON-encodable. No types that would trip Tess's TI-1 (Save.default_payload JSON round-trip) check.

---

## 3. Migration function spec

Pseudo-code (NOT GDScript; GDScript implementation lands in M2). Follows the idiom of the existing `_migrate_v2_to_v3` in `Save.gd:266-293`.

```
function migrate_v3_to_v4(data: Dictionary) -> Dictionary:
    # Defensive: a malformed v3 might lack the character block. The
    # earlier migrations (v0->v1, v1->v2, v2->v3) all backfill character
    # if missing, so by the time we run this we should have it. Mirror
    # their guard pattern anyway — costs nothing and matches existing code.
    if not data.has("character") or not (data["character"] is Dictionary):
        data["character"] = DEFAULT_PAYLOAD["character"].duplicate(true)

    var character = data["character"]

    # Backfill stash. Note: v1+ already has top-level data["stash"] as
    # an empty array. v4 introduces character.stash as the M2-active path.
    # The legacy data["stash"] array is RETAINED as a compat shadow (same
    # pattern as v3 retaining v2's flat vigor/focus/edge while introducing
    # character.stats). M2 code reads character.stash; legacy tooling that
    # reads data["stash"] still gets the empty stub. Future v5 may delete
    # the root-level stash if no consumer remains.
    if not character.has("stash") or not (character["stash"] is Array):
        character["stash"] = []

    # Backfill ember_bags. Empty dict on first migration — no legacy v3
    # save can have pending bags (the concept didn't exist).
    if not character.has("ember_bags") or not (character["ember_bags"] is Dictionary):
        character["ember_bags"] = {}

    # Backfill stash_ui_state. First-visit gate defaults to false so
    # migrating players see the tutorial hint-strip on their first stash
    # room entry — same UX as a fresh character.
    if not character.has("stash_ui_state") or not (character["stash_ui_state"] is Dictionary):
        character["stash_ui_state"] = { "stash_room_seen": false }
    else:
        # Defensive: dict exists but the inner key may be missing
        # (e.g., a hand-edited or partially-corrupted save).
        if not character["stash_ui_state"].has("stash_room_seen"):
            character["stash_ui_state"]["stash_room_seen"] = false

    return data
```

### 3.1 Idempotence — running on an already-v4 save

By inspection of the function above: every mutation is gated by a `has()` check. If `character.stash` is already present and is an Array, the gate fails and the line is skipped. Same for `ember_bags` and `stash_ui_state`. **The function is a no-op on already-v4 data.** This matches the pattern of `_migrate_v2_to_v3` (Save.gd:266-293) — every backfill is `if not character.has(...): character[...] = default`, so re-running has no effect.

This is enforced by the existing `migrate(data, from_version)` chain in `Save.gd:196-209`: if `from_version >= 4`, none of the `_migrate_vN_to_vN+1` branches execute. The function is only ever reached for `from_version < 4`. But even if a defensive caller re-runs it on v4 data, no double-write occurs.

### 3.2 What `_migrate_v3_to_v4` does NOT change

- **No change to `character.level`, `xp`, `xp_to_next`, `stats`, `unspent_stat_points`, `first_level_up_seen`, `hp_current`, `hp_max`.** All v3 character fields pass through bit-identical.
- **No change to `character.vigor`, `character.focus`, `character.edge` (the v2 compat shadows).** They survive into v4 unchanged.
- **No change to `equipped` map.** Equipped items are character state but live on `data["equipped"]` (root-level v1 contract); v4 leaves them there.
- **No change to root-level `stash` array.** The v1 stub array stays where it is; v4 introduces `character.stash` alongside it. (See §3 commentary on the compat-shadow rationale.)
- **No change to `meta.runs_completed`, `meta.deepest_stratum`, `meta.total_playtime_sec`.** All three already exist in v3 and remain on `meta` in v4.
- **No change to envelope fields** (`schema_version`, `saved_at`). The envelope `schema_version` flip from `3` to `4` happens by virtue of `Save.SCHEMA_VERSION` being bumped to `4` and the next `save_game` call writing the new value. The migration function itself never touches `schema_version` — that's the envelope's job.

### 3.3 Wire-up in `Save.gd::migrate()`

Single one-line addition to the existing chain (Save.gd:196-209):

```
if from_version < 4:
    out = _migrate_v3_to_v4(out)
```

Plus the constant bump:

```
const SCHEMA_VERSION: int = 4
```

That's the entire engine-side change. No new helpers, no curve-mirror state (unlike v1→v2 which had to mirror the Levels XP curve), no read-modify-write of existing fields.

---

## 4. Forward-compat strategy

### 4.1 The "never remove or rename, only add" rule

Codified for v4 onward. Any future schema bump (v4 → v5, v5 → v6, etc.) follows these rules:

1. **Never rename a field.** A rename is two operations (delete old + add new) and breaks every consumer. If a name needs to change, add the new field and treat the old one as a compat shadow read-only.
2. **Never change a field's type.** int stays int; float stays float; Dictionary stays Dictionary. If semantics change requires a new type, use a new field name.
3. **Never delete a field while any version-N reader exists.** Compat shadows live until N+2 schema bumps after their replacement (so v2 flat vigor persists through v3, v4 — could potentially deprecate at v5 or v6 once no test fixture or runtime path reads them).
4. **Always allowed: add a new field.** Defaults from the schema map (§4.2). No version bump required for purely additive changes per `team/devon-dev/save-format.md` "Migration policy."
5. **Always allowed: bump SCHEMA_VERSION.** Even for additive changes, bumping is fine — it just means the migrate chain has a no-op step. The cost is one branch in `migrate()` and one fixture in the test suite.

### 4.2 SaveSchema.gd autoload sketch (DESIGN ONLY — not for this PR)

To replace the scattered `if not character.has("xyz")` pattern with a single source of truth for default values, M2+ should add a lightweight `SaveSchema` autoload. **This is not part of v4's migration code; it's a structural cleanup that would land alongside or after v4.**

**Sketch (NOT real code — illustrative pseudo):**

```
# scripts/save/SaveSchema.gd (autoload, future)
# Source of truth for "what default value should I read when a key is absent?"
# Replaces scattered `if "x" in dict` checks across runtime consumers.

class_name SaveSchema
extends Node

# Map of dot-path -> default value. Keyed by the canonical path under data{}.
# Updated whenever a schema bump adds a field.
const DEFAULTS = {
    "character.level": 1,
    "character.xp": 0,
    "character.xp_to_next": 100,
    "character.stats.vigor": 0,
    "character.stats.focus": 0,
    "character.stats.edge": 0,
    "character.unspent_stat_points": 0,
    "character.first_level_up_seen": false,
    "character.hp_current": 100,
    "character.hp_max": 100,
    "character.stash": [],
    "character.ember_bags": {},
    "character.stash_ui_state": { "stash_room_seen": false },
    "character.stash_ui_state.stash_room_seen": false,
    "equipped": {},
    "meta.runs_completed": 0,
    "meta.deepest_stratum": 1,
    "meta.total_playtime_sec": 0.0,
}

# Returns the default value for a given dot-path, or null if the path is unknown.
func default_value(key_path: String) -> Variant:
    return DEFAULTS.get(key_path, null)

# Returns true if the key_path is part of the canonical schema.
func is_canonical(key_path: String) -> bool:
    return DEFAULTS.has(key_path)
```

**Consumer pattern (M2 code reading a possibly-absent field):**

```
var seen = character.get("stash_ui_state", {}).get("stash_room_seen", SaveSchema.default_value("character.stash_ui_state.stash_room_seen"))
```

**Why this matters:** without a source of truth, every consumer hand-codes its own default. When the canonical default changes (e.g., M3 wants new characters to start with `stash_room_seen=true` because the tutorial moves elsewhere), every consumer must be hunted down. With SaveSchema, one constant edits and every consumer picks up the new default.

**Out of scope for this PR.** Spec'd here so M2 + M3 implementers know it's the planned shape.

### 4.3 Consumer rule for missing keys

Until SaveSchema lands, M2 consumers reading v4 fields should follow this pattern:

```
# YES — single-call .get with a literal default:
var stash = character.get("stash", [])

# NO — scattered membership checks that will drift:
if "stash" in character:
    var stash = character["stash"]
else:
    var stash = []
```

The M2 implementation PR adds these reads into `Inventory.gd` (stash methods), `StratumProgression.gd` (ember_bags methods), and the new `StashPanel.gd` UI.

---

## 5. Round-trip invariants

These are the assertions the v3 → v4 migration test will pin. Tess will author the test; this is the contract those assertions must satisfy. Each invariant is named (test-method-friendly) and described.

| ID | Invariant | Description |
|---|---|---|
| **INV-1** | `v3_save_loads_clean_under_v4_runtime` | A hand-authored v3 fixture loads via `Save.load_game(slot)` without throwing; returned Dictionary is non-empty; `character` block intact. |
| **INV-2** | `v3_to_v4_backfills_empty_stash` | After loading a v3 fixture, `loaded["character"]["stash"]` exists, is an Array, and `size() == 0`. |
| **INV-3** | `v3_to_v4_backfills_empty_ember_bags` | After loading a v3 fixture, `loaded["character"]["ember_bags"]` exists, is a Dictionary, and `is_empty()` returns true. |
| **INV-4** | `v3_to_v4_backfills_stash_ui_state_with_room_unseen` | After loading a v3 fixture, `loaded["character"]["stash_ui_state"]["stash_room_seen"]` exists and equals `false`. |
| **INV-5** | `v3_field_preservation` | Every field that existed in v3 (level, xp, xp_to_next, stats.{vigor,focus,edge}, unspent_stat_points, first_level_up_seen, hp_current, hp_max, equipped, root-stash, meta.{runs_completed,deepest_stratum,total_playtime_sec}) is preserved bit-identical from the v3 fixture into the migrated v4 dict. |
| **INV-6** | `v3_to_v4_chain_through_full_history` | A v0 fixture migrates v0→v1→v2→v3→v4 and ends with the same level + xp + V/F/E values as a hand-authored v4 fixture with the equivalent character state, plus empty stash/bags/ui-state. (Catches drift in the migration chain.) |
| **INV-7** | `v3_to_v4_idempotent_on_already_v4` | A v4 save round-tripped through `save → load → save → load` is bit-identical (no double-backfill, no field drift, schema_version stays at 4). |
| **INV-8** | `v4_envelope_schema_version_on_disk` | After migrating a v3 save and calling `save_game`, the on-disk envelope has `schema_version == 4`. |

These eight invariants together are the M2 acceptance gate for the migration. Tess can layer additional probes (corrupt-bag-data tolerance, schema_version-future tolerance, etc.) but these are the floor.

---

## 6. Test fixture catalog

Tess will author these as `tests/fixtures/save_v3_*.json` files in the M2 PR. **Don't author them now** — listing them so the dispatch is precise when M2 starts.

| Fixture filename | Purpose | Distinguishing field values |
|---|---|---|
| `save_v3_baseline.json` | The "happy path" v3 save — typical mid-game. Drives INV-1, INV-2, INV-3, INV-4, INV-5. | Level 4, xp 1850, all stats > 0, equipped slots populated, root `stash` non-empty (M1 stash-as-storage pattern), meta progressed. |
| `save_v3_empty_inventory.json` | Edge: a v3 save with no equipped items, no stash, fresh-character stats. Drives INV-1 + INV-2 (the empty-source case — backfill must still happen). | Level 1, xp 0, V/F/E all 0, `equipped: {}`, root `stash: []`. |
| `save_v3_max_level_capped.json` | Edge: level-cap save (level 5 in M1). Drives INV-5 (level/xp survive verbatim — no clamping during migration). | Level 5, xp at the L5 floor, stats fully allocated, `unspent_stat_points: 0`, `first_level_up_seen: true`. |
| `save_v3_full_inventory.json` | Edge: a v3 save with the M1 24-slot inventory full (root-level `stash` packed). Drives INV-5 (root-stash preservation through the migration). | 24 entries in root `stash`, mix of T1/T2/T3 with affixes, equipped `weapon` + `armor`. |
| `save_v3_partial_corruption.json` | Edge: a v3 save with `character.stats` present but missing `unspent_stat_points` (simulating a hand-edited or partially-rolled-back save). Drives the defensive-guard branches in `_migrate_v3_to_v4`. | All v3 fields present except `unspent_stat_points`; migration must NOT crash, must NOT introduce v4 fields based on missing v3 fields. |
| `save_v4_idempotent_baseline.json` | A hand-authored v4 save (schema_version=4, all v4 fields present with non-default values like a populated stash). Drives INV-7. | Stash with 5 occupied slot_indices, `ember_bags["1"]` with 3 items, `stash_room_seen: true`. |

**Six fixtures.** Existing v0 fixtures (`save_v0_pre_migration.json`, `save_v0_empty_inventory.json`, `save_v0_malformed_item.json`) stay unchanged — they continue to drive the v0→v1→v2→v3→v4 chain via INV-6.

**Fixture authoring note for Tess:** the v3 baseline's character state should match the v0 baseline's after migration. That means `Old-Knight`, level 4, xp 1850, V=2/F=1/E=0 (from `test_v0_to_v1_preserves_all_v0_data` lines 87-93). Aligning the two means INV-6's "chain to v4 ends at same place as direct-v3 fixture" check is meaningful, not vacuous.

---

## 7. HTML5 / OPFS impact

### 7.1 Size delta quantification

Per-save size impact, broken down:

| Element | v3 size (typical) | v4 size (typical) | Delta |
|---|---|---|---|
| `character.stash` (sparse array) | n/a (empty stub at root, ~20 B) | empty `[]` early game (20 B) → ~5 KB at full 72-slot stash | +0 to +5 KB |
| `character.ember_bags` (dict) | n/a | `{}` (5 B) → ~3 KB at 8 strata × ~10-item bags | +0 to +3 KB |
| `character.stash_ui_state` | n/a | ~50 B (single bool key) | +50 B |
| **Total v4 delta** | — | — | **+50 B (fresh) to +8 KB (mid-stash) to +10 KB (worst case)** |

A typical mid-game save grows from ~5 KB (v3) to ~10–15 KB (v4 mid-stash). Worst case (full stash + 8 packed bags + max items) is ~25 KB.

### 7.2 OPFS quota check

Godot 4.3 web export uses IndexedDB-backed `user://` storage (NOT OPFS directly per the current Godot 4.3 docs; OPFS is the eventual target via FS-API but Godot 4.3 ships IndexedDB). Either way:

- **IndexedDB browser default quota:** ~6% of free disk per origin (Chrome), 50 MB initial soft (Firefox), unlimited with prompt (Safari). **At 25 KB per save × 100 hypothetical save slots = 2.5 MB**, well under any browser quota.
- **OPFS quota (when Godot upgrades):** comparable defaults, larger ceilings. v4's growth doesn't approach the threshold.

**Verdict: no quota concern.** v4 uses ~5x the storage of v3 in the worst case but still rounds to "single-digit megabytes" across realistic save counts. Tess's W3-A5 audit should add a TI-N invariant asserting that a fully-populated v4 save serializes to under 100 KB (a safety upper bound), which will catch any inadvertent size explosion in M2 implementation.

### 7.3 Save-write-frequency change M2 needs

Yes, one. **Bag-spawn-on-death must trigger an immediate save, not deferred.**

Reason: M1's save points are typically end-of-stratum and quit-time. M2 ember-bag means "die at room R3 of stratum 2 → bag must be persisted before the run-summary screen is shown" because the player will see "Stratum 2 · Room 3 / 8" on the summary, and a deferred save means a process kill between death and the next save point would silently drop the bag.

**M2 implementation requirement (carry into the M2 dispatch):** `StratumProgression.pack_bag_on_death(...)` must call `Save.save_game()` synchronously after updating `character.ember_bags`. The atomic-write (Save.gd:170-186) makes this safe — a power-yank during the save leaves the prior save intact, so worst case is "the bag wasn't saved" (same as the M1 contract for any unsaved state).

This is a frequency change from M1 (where deaths typically didn't trigger a save — the run-summary appeared, and the next save was on quit). **No schema change** — just a frequency change. Documented here so M2 doesn't accidentally defer it.

---

## 8. DECISIONS log entry (one-line append)

To be added to `team/DECISIONS.md` by orchestrator on merge:

```
## 2026-05-02 — Save schema v3 -> v4: stash + ember-bag (M2 design)
- Decided by: Devon (W3-B4 design ticket)
- Decision: Save schema v4 spec'd at `team/devon-dev/save-schema-v4-plan.md` — additive-only bump adding `character.stash` (sparse array of 72-cap slot entries), `character.ember_bags` (Dictionary keyed by stratum-id-as-String, cap 8), `character.stash_ui_state.stash_room_seen` (bool). All JSON-pure. `_migrate_v3_to_v4` follows the existing has()-guarded backfill pattern, idempotent on already-v4 data. Eight round-trip invariants pinned (INV-1..INV-8) for Tess's M2 migration test. Six new test fixtures catalogued for Tess. HTML5/OPFS size delta +5–10 KB typical, well within quota. **One structural deviation from Uma's stash-ui-v1.md §5**: ember-bags placed under `character.` (not at root) for multi-character (M3) symmetry — to be confirmed with Uma in M2 implementation PR. Implementation lands in M2 after Sponsor's M1 soak gate clears.
- Why: Honors M1 death rule's M2 promise (stash UI + ember-bag at death point). Additive-only keeps every legacy save loadable. Pinning the invariants and fixture catalog now means M2 implementation has a contract to write against rather than discovering edge cases in PR review.
- Reversibility: reversible — schema is design-only at this point; M2 implementation can revise fields before the migration code lands. Once the migrate function ships and saves are written at v4, fields are sticky (never delete or rename, only add).
```

---

## 9. Open questions

For Sponsor / Priya / Uma / orchestrator. Not all need resolution before M2 implementation begins, but each affects either the schema shape or the migration semantics.

1. **`ember_bags` at root vs. under `character.`** — I've placed it under `character.` for multi-character (M3) symmetry. Uma's §5 placed it at root. The structural deviation is explicit in §2.5 + DECISIONS entry. **Owner:** Uma — confirm in M2 implementation PR review. Either choice is JSON-pure and migrates the same way; choice impacts ergonomics, not safety.
2. **Compat-shadow lifetime for root-level `stash`** — v4 keeps `data["stash"]` (the v1 stub) alongside `character.stash`. Should v5 (some future schema bump) delete the root-level stash, or keep it forever? Suggest: delete at v5 if no consumer reads it by then; the deletion is an additive-rule violation but acceptable for confirmed-dead fields. **Owner:** Devon (decide at v5 dispatch); flagging now so we don't forget.
3. **`stash_ui_state` future growth** — the dict starts with one key. Likely M2/M3 additions: `stash_sort_preference: String`, `last_seen_stratum: int`, `tutorial_dismissed_keys: Array`. Should each of these bump the schema version (paranoid), or be additive within `stash_ui_state` (per the additive rule)? Suggest: additive within the dict, no schema bump per added sub-key. **Owner:** Priya — schema-policy call at the next field add.
4. **One-bag-vs-N-bags-per-stratum** — Uma §1 lists this as the open lever. Schema design above supports both: `ember_bags["1"]` is a single dict; switching to N-bags would change the value to an Array. That IS a non-additive change (type change), so it would need a v4→v5 migration. Alternative: design the schema as `ember_bags["1"]` always being an Array of length 1 in v4, leaving room for length>1 in v5 with no migration. Cost: every M2 read needs to write `ember_bags["1"][0]` instead of `ember_bags["1"]`. **Recommendation:** keep the simpler single-dict shape now; pay the migration cost only if Sponsor playtest demands N-bags. **Owner:** Sponsor — first M2 soak feedback decides.

---

## Hand-off

- **M2 implementation dispatch (Devon, future):** turn this spec into a real `_migrate_v3_to_v4` in `Save.gd`, bump `SCHEMA_VERSION` to 4, update `DEFAULT_PAYLOAD` with the three new character keys, update `team/devon-dev/save-format.md` with the v4 shape table.
- **Tess (M2 acceptance):** author the six fixtures in §6, pin the eight INV-* invariants in `tests/test_save_migration.gd`, add a v4-specific test file (`tests/test_save_migration_v4.gd`) following the existing v0→v1 idiom.
- **Uma (review):** confirm the `ember_bags` placement (root vs. under character) and rename (`pending_ember_bags` vs `ember_bags`) in M2 implementation PR review. Either choice is fine — flagging because it's a deviation from `stash-ui-v1.md` §5.
- **Priya (M2 backlog):** schedule the M2 implementation ticket after Sponsor's M1 soak gate clears.
