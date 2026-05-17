# Save schema v4 → v5 spike (M3 multi-character + persistent-meta + hub-town)

**Owner:** Devon (engine) · **Phase:** M3 Tier 1 (design-only; implementation lands in M3 Tier 2) · **Drives:** M3 multi-character slot UI (Drew `title-screen-slot-picker.md`), hub-town save state (Uma `hub-town-direction.md`), ember-shard currency + Paragon points (`m3-design-seeds.md §3`), and the first non-additive `_migrate_v4_to_v5` in `Save.gd`.

This doc is the M3-T1-1 deliverable per Priya's `team/priya-pl/m3-tier-1-plan.md §1` + ClickUp `86c9uth5h`. It specifies the v4 → v5 schema delta, migration function, the **first non-additive bump in project history**, round-trip invariants, test-fixture catalog, HTML5 / OPFS impact, and the explicit Devon-call on pointer-shadow compat. **Nothing here ships in M2.** The migration code itself lands in an M3 Tier 2 implementation ticket after M2 RC signs off.

This doc is the natural extension of `team/devon-dev/save-schema-v4-plan.md`. Read that first — every section here parallels a section there, with the v4 plan's structure preserved so reviewers can diff section-by-section.

---

## TL;DR

- **Additive-only:** **N — first non-additive schema bump in the project's history.** `data.character` (Dictionary) → `data.characters` (Array of Dictionary) is a **rename + type-change**, violating v4 plan §4.1 rule 1. Three additional non-additive moves: `data.equipped` lifts from root → `data.characters[N].equipped`; `data.character.stash` lifts from per-character → root `data.shared_stash`; `data.character.ember_bags` lifts to `data.characters[N].ember_bags` (no shape change, just path change).
- **Compat-shadow strategy:** **YES, pointer-shadow** — v5 keeps `data.character` (Dictionary, pointing at `data.characters[active_slot]`) and `data.equipped` (Dictionary, mirror of `data.characters[active_slot].equipped`) as **read-only compat shadows** for one schema generation. Deprecate at v6 (post-M3). See §4.4 for full rationale + the Devon-call.
- **New top-level keys under `data{}`:** `characters: Array` (replaces `character`), `active_slot: int` (replaces "implicit single-character" semantics), `shared_stash: Array` (replaces `character.stash`), `meta.hub_town_seen: bool` (additive; first-visit gate).
- **New per-character keys under `data.characters[N]`:** `slot_index: int`, `ember_shards: int`, `active_bounty: Dictionary | null`, `paragon_points: int`, `paragon_spent: Dictionary` (additive within the v5 multi-character structure).
- **Size delta on a typical save:** +1.5 to +3 KB per additional character slot (mostly empty character payload + level/xp/stats default block). At 3 slots × ~1 KB each + shared_stash lift (existing data, no growth), median v5 save grows from ~10–15 KB (v4 mid-stash) to ~12–18 KB. Well within IndexedDB/OPFS browser-default quotas.
- **JSON-encodable:** Y for every new field. Same primitives the v4 plan vetted — Dictionary / Array / int / float / String / bool.
- **Migration shape:** `_migrate_v4_to_v5(data)` is the first migration to **rename + lift** rather than purely backfill. The function is still idempotent on already-v5 data (guarded by `has("characters")`), but it must consume v4 data on first run rather than only add fields.
- **Open questions for Sponsor/Priya/Uma/orchestrator:** 5 (catalogued in §9). All but one are deferrable; the Devon-call (pointer-shadow) is decided in this doc (§4.4 — YES).

---

## 1. Source of truth

This plan extends and is bounded by these prior artifacts. Any conflict resolves in favor of the source listed (this doc is downstream of all of them):

1. **Priya `team/priya-pl/m3-tier-1-plan.md` §1 + M3-T1-1 ticket (`86c9uth5h`)** — the dispatch source for this spike. Locks the 7 required sections (schema diff / migration steps / additive-vs-non-additive call-outs / round-trip invariants / fixture catalog / HTML5 OPFS implications / pointer-shadow decision).
2. **Priya `team/priya-pl/m3-design-seeds.md` §1 (multi-character) + §3 (persistent meta)** — the design substrate. §1 specifies 3-slot count, shared-stash YES, class-divergence NO (deferred to M4). §3 specifies ember-shard currency, Paragon track, per-character bounty quest, persistent meta layers. The v5 schema is the data-layer expression of those decisions.
3. **`team/devon-dev/save-schema-v4-plan.md`** — model for this doc's shape + the canonical statement of the additive-only rule that v5 is the first to break. §4.1 rules 1 + 3 are the load-bearing constraints v5 must reckon with.
4. **`scripts/save/Save.gd`** — current runtime (SCHEMA_VERSION = 3 on disk at HEAD). Note: at HEAD the engine is still at v3 — v4 plan exists but the migration code itself has not shipped yet. **v5 implementation will land in M3 Tier 2 after v4 implementation lands** (or, if the Tier 2 brief sequences differently, as a combined v3→v4→v5 chain in one PR). The spike doc here is contract-only; sequencing is the implementation-PR's call.
5. **`tests/test_save_migration.gd`** — current migration test pattern (fixture-based, hand-authored on-disk JSON, verbatim round-trip check). v4 → v5 test will follow this exact idiom.
6. **Current v4 fixtures.** Per the ticket cross-reference: "current v4 fixtures under `tests/fixtures/v4/`." **Verification finding (2026-05-17):** as of this spike, no `tests/fixtures/v4/` directory exists yet. Existing fixtures are at `tests/fixtures/save_v0_*.json` (three v0 fixtures). The v4 plan §6 catalogues six v4 fixtures to be authored (`save_v3_baseline.json` … `save_v4_idempotent_baseline.json`) but these are still "to be authored by Tess in the v4 implementation PR" — they do not exist on disk yet. **Implication for this spike:** the v5 fixture catalog (§6 below) references v4 fixtures by **specification**, not by file path; when v4 implementation ships, the v4 fixture files materialize and the v5 fixture filenames here can reference them directly. Tess + the M3 Tier 2 implementer should be aware of this dependency-of-dependency.
7. **`.claude/docs/html5-export.md` § Resource enumeration on packed .pck resources + service-worker cache trap** — the HTML5-side constraints v5 must respect. v5 itself does not touch resource scanning (saves live in `user://` IndexedDB, not packed `.pck` content), but the OPFS roundtrip-cost analysis (§7) draws on the html5-export.md context.

---

## 2. Schema v4 → v5 delta

### 2.1 What v4 has (per `save-schema-v4-plan.md §2.1` + §2.2)

```
data:
  character:
    name: String
    level: int
    xp: int
    xp_to_next: int
    vigor / focus / edge: int           # v2 compat shadow
    stats: { vigor, focus, edge }       # v3 canonical
    unspent_stat_points: int
    first_level_up_seen: bool
    hp_current: int
    hp_max: int
    stash: Array                        # v4 — 72-slot sparse per-character pool
    ember_bags: Dictionary              # v4 — per-stratum pending bags
    stash_ui_state: { stash_room_seen } # v4 — first-visit gate
  stash: Array                          # v1 legacy root stub (compat-shadow of character.stash)
  equipped: Dictionary                  # root — slot -> item dict
  meta:
    runs_completed: int
    deepest_stratum: int
    total_playtime_sec: float
```

### 2.2 v5 delta — non-additive moves (the load-bearing changes)

| Path | v4 location | v5 location | Operation |
|---|---|---|---|
| Single-character block | `data.character` (Dict) | `data.characters[0]` (Array entry of Dict) | **Rename + type-change** (the new top-level is `characters: Array`; `character: Dict` becomes a compat pointer-shadow per §4.4) |
| Equipped slots | `data.equipped` (root Dict) | `data.characters[N].equipped` (per-character Dict) | **Lift root → per-character.** Root `data.equipped` retained as compat pointer-shadow of `data.characters[active_slot].equipped` for one schema gen. |
| Per-character stash | `data.character.stash` (per-character 72-slot pool) | `data.shared_stash` (root, shared across all characters) | **Lift per-character → root.** Single existing v4 character's stash becomes the shared pool on first migration. No collisions (stash items have stable IDs). |
| Ember-bags | `data.character.ember_bags` | `data.characters[N].ember_bags` | **Path move only; shape unchanged.** Per-character semantics preserved (each character has their own pending bags). |
| Stash UI state | `data.character.stash_ui_state` | `data.characters[N].stash_ui_state` | **Path move only; shape unchanged.** |

### 2.3 v5 additive table (new fields, all additive within the v5 multi-character structure)

| Path | Type | Default on migration | JSON-encodable | Notes |
|---|---|---|---|---|
| `data.characters` | Array of Dictionary | `[v4_character_dict]` (single existing v4 character lifted as `slot_index: 0`) | Y | The multi-character pool. Recommended cap is 3 (per `m3-design-seeds.md §1.1` default); schema permits N entries (M3 dispatch may extend to 6+ if Sponsor signs off). |
| `data.characters[N].slot_index` | int | `0` for migrated v4 character; subsequent slots get 1, 2, ... | Y | Stable per-character identifier. Title-screen slot-picker UI reads this to render slot rows. |
| `data.active_slot` | int | `0` (the only existing character) | Y | Which character is currently being played. Subsequent loads pick this slot to resume. Recommended range 0..2 for 3-slot M3; schema permits any int (validated against `characters[].slot_index` at load time). |
| `data.shared_stash` | Array of Dictionary | `data.character.stash` from v4 (i.e., the existing per-character stash lifts to the shared pool) | Y | Shared across all character slots. Same sparse-array shape as v4 `character.stash` (per v4 plan §2.3) — entries have `slot_index: int`, `id: String`, `tier: int`, `rolled_affixes: Array`, `stack_count: int`. |
| `data.meta.hub_town_seen` | bool | `false` | Y | First-visit hint-strip gate per `m3-design-seeds.md §2 Save-schema implications`. **Account-scoped** (on `meta`, not on character) — once any character has visited the hub-town, subsequent characters skip the hint. |
| `data.characters[N].ember_shards` | int | `0` | Y | Ember-shard currency per `m3-design-seeds.md §3`. Per-character (each character earns + spends their own). |
| `data.characters[N].active_bounty` | `Dictionary` or `null` | `null` | Y | Active bounty quest state per `m3-design-seeds.md §2 + §3`. Per-character. Shape: `{ quest_id: String, target: String, progress: int }`. Null when no quest is active (default for migrated v4 characters; first character to talk to bounty-poster gets a real Dict). |
| `data.characters[N].paragon_points` | int | `0` | Y | Earned Paragon points (Diablo-III shape per `m3-design-seeds.md §3 NG+ Paragon track`). Per-character. Caps at 100 in M3 (M4+ may raise). |
| `data.characters[N].paragon_spent` | Dictionary | `{}` (empty map) | Y | Map of paragon-buff-id → ranks-spent. Per-character. Schema permits arbitrary keys; M3 game code validates against the locked Paragon-buff registry. |

That's the v5 delta. **One non-additive structural change** (character: Dict → characters: Array) plus three path-lifts (equipped, stash, ember-bags) plus six purely additive fields.

### 2.4 v5 schema (compact)

```
data:
  characters: [                              # NEW (replaces `character`; type-changed)
    {
      slot_index: int,                       # NEW per-character (0..2 in M3)
      name: String
      level / xp / xp_to_next: int
      vigor / focus / edge: int              # v2 compat shadow (preserved bit-identical)
      stats: { vigor, focus, edge }
      unspent_stat_points: int
      first_level_up_seen: bool
      hp_current / hp_max: int
      equipped: Dictionary                   # MOVED from root
      ember_bags: Dictionary                 # MOVED from data.character (path-only)
      stash_ui_state: { stash_room_seen }    # MOVED from data.character (path-only)
      ember_shards: int                      # NEW
      active_bounty: Dictionary | null       # NEW
      paragon_points: int                    # NEW
      paragon_spent: Dictionary              # NEW
    },
    # ... up to characters[2] in M3 (Sponsor may sign off N>3 in future) ...
  ]
  active_slot: int                           # NEW (0..2)
  shared_stash: Array                        # NEW (lifted from data.character.stash)
  character: Dictionary                      # COMPAT POINTER-SHADOW (read-only mirror of characters[active_slot])
  equipped: Dictionary                       # COMPAT POINTER-SHADOW (read-only mirror of characters[active_slot].equipped)
  stash: Array                               # COMPAT POINTER-SHADOW (v1 stub retained; also mirrors shared_stash)
  meta:
    runs_completed: int
    deepest_stratum: int
    total_playtime_sec: float
    hub_town_seen: bool                      # NEW (account-scoped)
```

### 2.5 JSON-encodable verdict

Same audit as v4 plan §2.6 — every new field is Dictionary / Array / int / float / String / bool primitives. No Resource refs, no PackedByteArray, no Object refs. **All JSON-pure.** The compat-shadow pointer fields (`data.character`, `data.equipped`, `data.stash`) are themselves Dictionary / Array references, which serialize as **duplicated copies** in JSON (JSON has no pointer-aliasing semantic). This duplication is intentional — see §4.4 for the disk-cost discussion.

---

## 3. Migration function spec

Pseudo-code (NOT GDScript; GDScript implementation lands in M3 Tier 2). Follows the idiom of `_migrate_v3_to_v4` from the v4 plan, with the addition of **lift operations** that v0..v4 never had.

```
function migrate_v4_to_v5(data: Dictionary) -> Dictionary:
    # Defensive: v0..v4 migrations all backfill character if absent.
    # If we're here and character is somehow missing, default it up.
    if not data.has("character") or not (data["character"] is Dictionary):
        data["character"] = DEFAULT_PAYLOAD["character"].duplicate(true)

    # --- Step 1: Wrap the existing single character into the new array ---
    var existing_character: Dictionary = data["character"].duplicate(true)
    existing_character["slot_index"] = 0

    # Lift root-level equipped into the character (will pointer-shadow at root).
    var existing_equipped: Dictionary = data.get("equipped", {})
    existing_character["equipped"] = existing_equipped.duplicate(true)

    # Lift per-character stash into the shared pool (drop from character).
    var existing_stash: Array = existing_character.get("stash", [])
    existing_character.erase("stash")

    # Backfill the six new per-character fields.
    if not existing_character.has("ember_shards"):
        existing_character["ember_shards"] = 0
    if not existing_character.has("active_bounty"):
        existing_character["active_bounty"] = null
    if not existing_character.has("paragon_points"):
        existing_character["paragon_points"] = 0
    if not existing_character.has("paragon_spent"):
        existing_character["paragon_spent"] = {}

    # --- Step 2: Build the new top-level structure ---
    data["characters"] = [existing_character]
    data["active_slot"] = 0
    data["shared_stash"] = existing_stash

    # --- Step 3: Pointer-shadow legacy fields (per §4.4 Devon-call: YES) ---
    # data.character mirrors characters[active_slot]. JSON has no pointer
    # aliasing, so on disk this is a duplicated dict. The runtime can refresh
    # the mirror on every save_game call.
    data["character"] = existing_character.duplicate(true)
    # data.equipped mirrors characters[active_slot].equipped.
    data["equipped"] = existing_character["equipped"].duplicate(true)
    # data.stash retains the v1 stub; also mirror shared_stash for v3-and-prior
    # tooling. v6 deletes data.stash entirely.
    data["stash"] = existing_stash.duplicate(true)

    # --- Step 4: Backfill the meta.hub_town_seen gate ---
    if not data.has("meta") or not (data["meta"] is Dictionary):
        data["meta"] = DEFAULT_PAYLOAD["meta"].duplicate(true)
    if not data["meta"].has("hub_town_seen"):
        data["meta"]["hub_town_seen"] = false

    return data
```

### 3.1 Idempotence — running on already-v5 data

The function above is **NOT trivially idempotent on already-v5 data** in the same way v3→v4 was, because step 1 reads `data["character"]` (which is the compat-shadow on v5, not the canonical data source). Running the migration twice on a v5 save would re-wrap the shadow as `characters[0]`, **overwriting `characters[0]` from the shadow's stale data**.

**The fix:** guard the entry of the function on `if from_version >= 5: return data`. The existing `migrate(data, from_version)` chain in `Save.gd` already does this — see `Save.gd:218-234` for the pattern. The `if from_version < N: out = _migrate_vN-1_to_vN(out)` ladder only executes the migration when `from_version < N`. So `_migrate_v4_to_v5` is only ever called when `from_version < 5`; once SCHEMA_VERSION is bumped to 5 and a v5 save is loaded, the migration is skipped entirely.

**Belt-and-suspenders idempotence check** (recommended for the M3 Tier 2 implementation): add a `has("characters")` early-return at the top of `_migrate_v4_to_v5` to short-circuit if the data is already v5-shaped (e.g., a hand-edited save where someone manually set `schema_version: 4` but the payload is v5). One line:

```
if data.has("characters") and (data["characters"] is Array):
    return data
```

This makes the function robust to malformed envelope/payload mismatches and matches the defensive `has()` guards in the earlier migrations.

### 3.2 What `_migrate_v4_to_v5` does NOT change

- **No change to character payload fields** (level, xp, xp_to_next, stats, unspent_stat_points, first_level_up_seen, hp_current, hp_max, vigor/focus/edge compat shadow). All v4 character fields pass through bit-identical into `characters[0]`.
- **No change to `meta.runs_completed`, `meta.deepest_stratum`, `meta.total_playtime_sec`.** These remain on `meta` (per v4 plan §3.2 — meta is account-scoped). `meta.hub_town_seen` is the only new meta field.
- **No change to envelope fields** (`schema_version`, `saved_at`). The envelope `schema_version` flip from `4` to `5` happens by virtue of `Save.SCHEMA_VERSION` being bumped to `5` and the next `save_game` call writing the new value. The migration function itself never touches `schema_version`.
- **No deletions** — every v4 field is preserved either at its v4 path (as a pointer-shadow) or at its lifted path (as the canonical). The first deletion happens at v6 (post-M3) when the compat shadows retire.

### 3.3 Wire-up in `Save.gd::migrate()`

Two-line addition to the existing chain (will land alongside the v4 wire-up):

```
if from_version < 4:
    out = _migrate_v3_to_v4(out)
if from_version < 5:
    out = _migrate_v4_to_v5(out)
```

Plus the constant bump:

```
const SCHEMA_VERSION: int = 5
```

If v4 implementation has not landed by M3 Tier 2 start, the v5 implementation PR can ship `_migrate_v3_to_v4` + `_migrate_v4_to_v5` together. The migration chain is order-stable; running v3→v4→v5 on a v3 save produces the same result as running v3→v5 directly would (because each step is fixture-pinned per §5/§6).

---

## 4. Non-additive call-outs (the load-bearing v5 deviations)

This is the section that distinguishes v5 from every prior schema bump. v0→v1, v1→v2, v2→v3, v3→v4 were all purely additive — every new field was a `has()`-guarded backfill, every existing field was preserved bit-identical. **v5 breaks that rule for the first time** along the four dimensions catalogued in §2.2.

### 4.1 The rule v5 breaks

Per `save-schema-v4-plan.md §4.1` rule 1: **"Never rename a field. A rename is two operations (delete old + add new) and breaks every consumer."** v5's `data.character` → `data.characters` is structurally a rename (the key changes) AND a type-change (Dictionary → Array). Both are forbidden under the v4 rule.

Per rule 2: **"Never change a field's type. int stays int; float stays float; Dictionary stays Dictionary."** v5 violates rule 2 for the `data.character` slot (Dict → Array; though the new top-level is named differently, the semantic owner of "the player character data" moves from a Dictionary container to an Array container).

Per rule 3: **"Never delete a field while any version-N reader exists."** v5 does NOT immediately delete `data.character` — that would compound the violation. The pointer-shadow strategy (§4.4) preserves the v4 readers' contract.

### 4.2 Why v5 breaks the rule

The rules in v4 plan §4.1 were authored for **additive schema growth** — fields appearing alongside existing ones. They reflect the project's intent: "saves should always load; old tooling should always work."

Multi-character is **a fundamentally non-additive feature.** The "one character per save" assumption is baked into the type of `data.character` (single Dictionary, not Array). No purely-additive extension of v4 can express "the player has 3 characters and chooses which to play" without contortions (e.g., `data.character` becomes a phantom-slot pointing at one of `data.alt_characters[0..N]`, with a magic flag for "is this the active one" — uglier than the lift).

The right call is **break the additive rule once**, with a clear migration contract, full pointer-shadow compat for one schema generation, and a deprecation plan for v6. Every downstream feature ticket (multi-character slot UI, hub-town save state, ember-shard wiring, Paragon points) builds on this. **The alternative is decades of v4-shaped contortions that read worse than one clean break.**

### 4.3 The forward-compat rule, updated

For v6 and beyond, the rules in `save-schema-v4-plan.md §4.1` continue to apply **with one addition** captured here:

**Rule 6 (new in v5):** **Non-additive bumps are permitted when no additive expression exists for the feature.** The author must:
1. **Document the violation explicitly** (this §4 is the v5 instance).
2. **Pointer-shadow the old fields for at least one schema generation** so prior-version readers continue to function. Shadows are read-only; writes flow through the new canonical path.
3. **Schedule the shadow's deletion** at the version-after-next bump (v5's shadows delete at v6; a v7 non-additive change's shadows would delete at v8).
4. **Pin a fixture that exercises the shadow.** If the shadow stops working silently, the test catches it.

Additive bumps remain the default. Non-additive is the exception, taken when (and only when) the feature shape genuinely can't be expressed additively. The maintainer's burden is to **justify in writing** that no additive path exists — a brief paragraph in the spike doc, like this one.

### 4.4 Pointer-shadow Devon-call — YES, pointer-shadow `data.character` + `data.equipped` for one schema generation

**The question (per M3-T1-1 ticket scope):** should v5 keep `data.character` as a compat shadow for one schema generation (default YES per `m3-design-seeds.md §1`) OR remove immediately?

**My call: YES, pointer-shadow.** Specifically:

- **v5 writes `data.character` and `data.equipped` as duplicated copies of `data.characters[active_slot]` and `data.characters[active_slot].equipped`** on every save. The migration function (§3) initializes them; subsequent `save_game` calls refresh them.
- **v5 readers of `data.character` and `data.equipped` get correct values** — they're the active-slot character at every save-time snapshot.
- **The shadows are read-only by contract.** Any v5 code that wants to mutate the active character mutates `data.characters[active_slot]`, not `data.character`. The shadow is regenerated at next save_game. **This is the load-bearing discipline** — failure to honor it produces drift between the shadow and the canonical.
- **v6 (post-M3) deletes `data.character` and `data.equipped`.** By v6 timing, all M3 code consumes the canonical path (`data.characters[N]`); the only remaining shadow-consumers are legacy v4 tooling and hypothetical hand-edited saves. Both are acceptable casualties at v6 cut.

**Rationale (four reasons):**

1. **Rule-consistent with v4's existing compat-shadow doctrine.** v4 already keeps `data["stash"]` (v1 stub) alongside `character.stash` per v4 plan §3.2; v3 keeps flat `vigor/focus/edge` alongside `stats.{vigor,focus,edge}` per `_migrate_v2_to_v3`. The project's pattern for "rename without breaking" is the compat shadow. v5's `data.character` → `data.characters[active_slot]` shadow extends this pattern, not invents a new one.
2. **Minimizes blast radius at v5 cut.** Every runtime reader of `data.character` keeps working through v5 without modification. The HUD code, the inventory code, the player-progression code, any test fixture — all continue to read the v4 path correctly. The cleanup happens at v6 once we know what consumers remain.
3. **The disk-cost is bounded and small.** Duplicating the active character's payload into `data.character` costs ~1 KB on a typical save (median character payload size). Over 100 saves × 1 KB = 100 KB total — well under any quota concern (see §7). The pointer-shadow's marginal cost is a rounding error.
4. **The drift discipline is enforceable in tests.** INV-7 (§5) pins `data.character == data.characters[active_slot]` at every save. If a v5 runtime path mutates `data.character` directly (the failure mode this discipline guards against), the test fails immediately. The shadow's read-only contract is enforced empirically.

**Counter-arguments considered (and rejected):**

- **"Pointer-shadow doubles save size."** No — it adds the active character's payload once, not every character. At 3 slots × ~1 KB each + 1 KB shadow = ~4 KB total character footprint. Not a problem.
- **"Pointer-shadow risks drift."** Mitigated by INV-7 (drift detector) + the read-only convention. The same risk exists for `data.stash` ↔ `character.stash` in v4; v4 plan §3.2 acknowledges this and accepts it as the cost of compat. v5 is in-pattern.
- **"Just delete `data.character` immediately and force callers to migrate."** This is the cleaner-on-paper approach but it **forces every v4 reader to update simultaneously**, including code paths I may not have audited (UI, telemetry, dev-tooling, test fixtures, hand-edited diagnostic saves). The pointer-shadow gives one schema generation of buffer for that audit + migration, without sacrificing v5's clean canonical path. **One schema generation costs ~1 KB per save; rushing the cleanup costs unknown debug time.** The trade is asymmetric in favor of the shadow.

**Logged as Decision-draft (for Priya's weekly DECISIONS.md batch):**

> **Decision draft (2026-05-17 — Devon):** v5 save-schema spike commits to **pointer-shadow `data.character` + `data.equipped` for one schema generation** (deprecate at v6). The shadows are duplicated copies of `data.characters[active_slot]` and its `equipped` sub-dict, refreshed at every `save_game` call. Read-only by contract — v5 code mutates `data.characters[active_slot]`, not the shadow. Drift detector pinned as INV-7. Disk cost ~1 KB per save; well under quota. Rationale: rule-consistent with v4's stash/vigor/focus/edge compat-shadow pattern; minimizes blast radius at v5 cut; enables M3 feature dispatches without forcing a v4-reader audit on Day 1. Reversibility: the migration emits both v4-shaped and v5-shaped data; rolling back v5 reverts to v4 with no data loss (the shadow IS the v4 payload).

---

## 5. Round-trip invariants

These are the assertions the v4 → v5 migration test will pin. Tess will author the test in the M3 Tier 2 implementation PR; this is the contract those assertions must satisfy. Eight invariants, mirroring the v4 plan §5 shape:

| ID | Invariant | Description |
|---|---|---|
| **INV-1** | `v4_save_loads_clean_under_v5_runtime` | A hand-authored v4 fixture loads via `Save.load_game(slot)` without throwing; returned Dictionary is non-empty; `characters` array exists with `size() == 1`; `active_slot == 0`. |
| **INV-2** | `v4_character_lifts_to_characters_zero` | After loading a v4 fixture, `loaded["characters"][0]` contains every v4 character field bit-identical (level, xp, xp_to_next, stats, unspent_stat_points, first_level_up_seen, hp_current, hp_max, vigor/focus/edge compat shadows). `slot_index == 0` is present. |
| **INV-3** | `v4_equipped_lifts_to_per_character` | After loading a v4 fixture, `loaded["characters"][0]["equipped"]` equals the v4 fixture's root `data.equipped` map bit-identically. |
| **INV-4** | `v4_stash_lifts_to_shared_stash` | After loading a v4 fixture, `loaded["shared_stash"]` equals the v4 fixture's `data.character.stash` array bit-identically. `loaded["characters"][0]` has NO `stash` key (it lifted out). |
| **INV-5** | `v5_pointer_shadow_active_slot` | After loading a v4 fixture and re-saving, `loaded["character"] == loaded["characters"][loaded["active_slot"]]` (deep-equal). Same for `loaded["equipped"]` and `loaded["characters"][active_slot]["equipped"]`. (Drift detector.) |
| **INV-6** | `v5_new_field_defaults` | After loading a v4 fixture, `loaded["characters"][0]["ember_shards"] == 0`, `loaded["characters"][0]["active_bounty"] == null`, `loaded["characters"][0]["paragon_points"] == 0`, `loaded["characters"][0]["paragon_spent"] == {}`, `loaded["meta"]["hub_town_seen"] == false`. |
| **INV-7** | `v5_idempotent_double_migration` | A v5 save round-tripped through `save → load → save → load` is bit-identical (no double-lift, no field drift, schema_version stays at 5, `characters[].slot_index` unchanged, pointer-shadows still match). |
| **INV-8** | `v0_to_v5_chain_through_full_history` | A v0 fixture migrates v0→v1→v2→v3→v4→v5 and ends with the same character data + empty new-fields + correct `shared_stash` lift as a hand-authored v5 fixture with equivalent state. (Catches chain drift.) |

These eight invariants are the M3 Tier 2 acceptance gate for the v5 migration. Tess may layer additional probes (corrupt-array tolerance, schema_version-future tolerance, malformed slot_index handling, etc.) but these eight are the floor.

**Note on INV-5 (drift detector).** This is the load-bearing test for the pointer-shadow Devon-call. If any v5 code path mutates `data.character` directly without also mutating `data.characters[active_slot]` (or vice versa without refreshing the shadow at save), INV-5 fails on the next save+load round-trip. **The test catches the discipline violation immediately**, before it ships and produces silent save-corruption.

---

## 6. Test fixture catalog

Tess will author these as `tests/fixtures/save_v4_*.json` and `tests/fixtures/save_v5_*.json` files in the M3 Tier 2 PR. **Don't author them now** — listing them so the dispatch is precise when M3 Tier 2 starts.

**Eight fixtures total** (per the M3-T1-1 ticket's "5-8 fixture file specs" range — I'm taking the upper end because v5 is the first non-additive bump and the test coverage budget should be generous):

| Fixture filename | Purpose | Distinguishing field values |
|---|---|---|
| `save_v4_baseline.json` | The "happy path" v4 source for v4→v5 migration. Drives INV-1, INV-2, INV-3, INV-4, INV-6. | Level 4, xp 1850, all stats > 0, equipped weapon+armor, `character.stash` with 5 occupied slots, `character.ember_bags["1"]` empty, `stash_room_seen: true`. |
| `save_v4_full_inventory_and_bags.json` | Edge: a v4 save with 24 stash entries + ember-bags pending in 3 strata. Drives INV-4 (full stash lift) + INV-3 (equipped with full slot loadout). | 24 stash entries (mix of T1/T2/T3 with affixes), `ember_bags["1","2","3"]` each with 3-5 items, equipped weapon+armor+ring+amulet. |
| `save_v4_fresh_character.json` | Edge: a v4 save matching a fresh character (level 1, no stash, no bags). Drives INV-6 (new-field-default backfill on minimal source). | Level 1, xp 0, V/F/E all 0, `equipped: {}`, `character.stash: []`, `character.ember_bags: {}`, `stash_room_seen: false`. |
| `save_v5_baseline.json` | A hand-authored v5 save (`schema_version: 5`, full v5 structure). Drives INV-5 (pointer-shadow correctness) + INV-7 (idempotent double-migration). | 3 characters at varying levels (L5/L3/L1), `active_slot: 1`, `shared_stash` with 10 entries, ember_shards on each character, one with `active_bounty` populated, Paragon points on the L5 character. |
| `save_v5_three_slots_one_active.json` | The canonical M3 multi-character state — 3 fully-populated character slots, one active. Drives INV-5 + INV-7 + multi-character UI test surface. | All 3 characters populated, `active_slot: 0`, each character has their own ember_bags + ember_shards + active_bounty + Paragon state; `shared_stash` lightly populated. |
| `save_v5_shared_stash_full.json` | Edge: shared_stash at max practical capacity (~72 entries). Drives shared_stash serialization-cost test surface + OPFS roundtrip-cost probe (§7). | 1 character at L8 (deepest_stratum_run), 72-entry shared_stash, equipped full loadout, ember_bags in all visited strata. |
| `save_v5_ember_shards_and_paragon.json` | Edge: a character with high ember-shard count + half-spent Paragon track. Drives §3 persistent-meta serialization surface. | 1 character at L30 (M3 cap), 5,000 ember_shards, paragon_points: 47, paragon_spent: 12 entries across various buff IDs. |
| `save_v5_html5_opfs_max.json` | Edge: the worst-case v5 save (3 full characters + 72 shared_stash + full ember_bags + full Paragon spent). Drives OPFS roundtrip-cost upper bound (§7). | 3 characters at L20+ each, fully populated everything. **Used to pin TI-N "v5 worst-case serializes under 150 KB" upper bound.** |

**Eight fixtures.** Existing v0 fixtures stay unchanged. The v3 → v4 → v5 chain is exercised by INV-8 against an existing v0 fixture; no new v0/v1/v2/v3 fixtures are needed.

**Fixture-authoring note for Tess (M3 Tier 2):** keep `save_v4_baseline.json` aligned with `save_v0_pre_migration.json`'s character-state-after-migration. That alignment makes INV-8's "v0→v5 chain ends at same place as direct-v5 fixture" check meaningful, not vacuous. The v4 plan §6 expressed the same idiom for v3↔v0 alignment; v5 extends it one step.

---

## 7. HTML5 / OPFS impact

### 7.1 Size delta quantification

Per-save size impact, broken down for the v4→v5 transition:

| Element | v4 size (typical) | v5 size (typical) | Delta |
|---|---|---|---|
| `data.characters` (Array of N character dicts) | n/a (single character at ~1 KB) | 3 × ~1 KB = ~3 KB | +2 KB |
| `data.shared_stash` (lifted from character.stash) | n/a (under character) | same content, root path | 0 (path-move only) |
| `data.active_slot` | n/a | 4 B (single int) | +4 B |
| `data.meta.hub_town_seen` | n/a | 25 B (bool key) | +25 B |
| Per-character new fields (ember_shards, active_bounty, paragon_points, paragon_spent) × N slots | n/a | ~200 B per character × 3 = ~600 B | +600 B |
| Pointer-shadows (`data.character`, `data.equipped`, `data.stash`) | already present in v4 | regenerated at save_game (deep-copy of active slot) | ~1 KB (active-character payload duplicated) |
| **Total v5 delta** | — | — | **+2 KB (single-slot v5) to +4 KB (full 3-slot v5)** |

A typical mid-game v5 save grows from ~10–15 KB (v4 mid-stash) to ~12–18 KB (v5 with 3 slots + meta + shadows). Worst case (3 full characters + 72 shared_stash + full ember_bags across all visited strata + max Paragon spent) is ~50–80 KB. **Still well under any quota.**

### 7.2 OPFS roundtrip-cost analysis

The M3-T1-1 ticket flags concern about "OPFS Dict-of-Dict roundtrip cost" — v4 is mostly flat; v5's nested `characters[]` array of character Dicts is the first save schema with **two levels of nesting** beyond the existing per-character stash/bags. Concretely:

- **Godot 4.3 web export uses IndexedDB-backed `user://` storage** (not OPFS directly — see `.claude/docs/html5-export.md` §"Service-worker cache trap" for the broader HTML5 storage context). The `JSON.stringify` + `FileAccess.store_string` path round-trips the entire envelope as one string write. **Nesting depth is irrelevant to the storage layer** — IndexedDB stores the string blob whole, not field-by-field.
- **The OPFS migration (when Godot upgrades)** is also blob-oriented for `user://` files; the file-system-API uses `WritableStream` for whole-file writes. Same conclusion: nesting depth is invisible to the storage layer.
- **The cost concern surfaces in two places:**
  1. **GDScript JSON.stringify cost** at save time. Nested dicts cost more CPU than flat dicts; for a 50-KB worst-case v5 save, the stringify cost is ~10-20 ms on a mid-range desktop (extrapolated from `JSON.stringify` benchmarks on similarly-shaped Godot 4.3 dicts). On low-end HTML5 (mobile / Chromebook), ~50-100 ms. **Acceptable for a save operation** (saves happen at room-cleared / quit / stratum-exit events, not per-frame).
  2. **GDScript JSON.parse_string cost** at load time. Same shape: ~10-20 ms desktop, ~50-100 ms low-end HTML5. Acceptable for load (one-shot at boot or character-swap).
- **Chunking is NOT needed.** The worst-case v5 save is ~80 KB; IndexedDB / OPFS quota is in megabytes. Chunking would be premature optimization. The "Dict-of-Dict roundtrip cost" risk catalogued in the ticket is **not load-bearing for v5 sizes**.
- **Re-evaluate at v6 / v7** if a future schema bump pushes saves past ~500 KB (e.g., a "full history log" feature). At that scale, JSON parse cost on low-end HTML5 could approach 1-2 sec, which would be felt by players. v5 is nowhere near that threshold.

### 7.3 Browser-quota check (same as v4 plan §7.2)

- **IndexedDB browser default quota:** ~6% of free disk per origin (Chrome), 50 MB initial soft (Firefox), unlimited with prompt (Safari).
- **v5 worst-case per save:** ~80 KB.
- **Save slots × hypothetical save count:** 3 slots × ~100 saves over a playthrough = ~24 MB peak. **Still under Firefox's 50 MB soft cap** (worst-case browser); comfortably under Chrome/Safari.

**Verdict: no quota concern for v5.** Tess's TI-N invariant (see §6 fixture `save_v5_html5_opfs_max.json`) should pin worst-case at <150 KB to catch any inadvertent size explosion in M3 Tier 2 implementation; that's the safety upper bound.

### 7.4 Save-write-frequency change M3 needs

Per `m3-design-seeds.md §3` plus the v4 plan's bag-spawn-on-death frequency change (v4 plan §7.3), M3 introduces three new save-write triggers:

1. **Character-switch (multi-character)** — when the player switches slots from the title-screen, the previously-active character's state is already saved; the new slot's load is a `Save.load_game()` call with the new slot's data. **No new write trigger** — the slot-switch is read-only on the save layer.
2. **Hub-town first-visit** — `meta.hub_town_seen = true` is set on first entry. Must trigger `Save.save_game()` synchronously so a process-kill before next save doesn't replay the first-visit hint. **One-shot per account** (it never flips back to false). Trivial frequency change.
3. **Ember-shard pickup** — currency drops accumulate in-run. Persisting per-shard-pickup is overkill; the right cadence is `room_cleared` (same as inventory updates). **No new trigger; folds into existing `room_cleared` save.**

Total frequency change vs v4: +1 trigger (hub-town first-visit). Negligible.

---

## 8. DECISIONS log entry (one-line append for Priya's weekly batch)

To be batched into `team/DECISIONS.md` by Priya on merge — drafted here per `same-day-decisions-rebase-pattern` (avoid same-day direct DECISIONS.md edits):

```
## 2026-05-17 — Save schema v4 -> v5: multi-character + persistent-meta + hub-town (M3 design)
- Decided by: Devon (M3-T1-1 spike `86c9uth5h`)
- Decision: Save schema v5 spec'd at `team/devon-dev/save-schema-v5-plan.md` — first non-additive schema bump in project history. `data.character` (Dict) -> `data.characters` (Array of Dict); `data.equipped` lifts to per-character; `data.character.stash` lifts to `data.shared_stash`. Six new additive per-character fields (slot_index, ember_shards, active_bounty, paragon_points, paragon_spent) + two new top-level (active_slot, shared_stash) + one new meta field (hub_town_seen). Pointer-shadow `data.character` + `data.equipped` for one schema generation; deprecate at v6. Eight round-trip invariants (INV-1..INV-8) pinned for Tess's M3 Tier 2 migration test, including INV-5 (pointer-shadow drift detector) and INV-8 (v0->v5 chain). Eight test fixtures catalogued. HTML5/OPFS size delta +2-4 KB typical, well within quota; no chunking needed. Updated rule 6 added to v4 plan's additive-only doctrine ("non-additive permitted when no additive expression exists; must pointer-shadow + document + schedule deprecation"). Implementation lands in M3 Tier 2.
- Why: Multi-character is fundamentally non-additive (the "one character per save" assumption is baked into the type of `data.character`). One clean break + pointer-shadow + documented deprecation > decades of v4-shaped contortions. Pointer-shadow doctrine is rule-consistent with v4's existing stash/vigor/focus/edge compat-shadow patterns.
- Reversibility: reversible — schema is design-only at this point; M3 Tier 2 implementation can revise fields before the migration code lands. Once the migrate function ships and saves are written at v5, fields are sticky (per v4 §4.1 rules 1-3 + this doc's rule 6). The pointer-shadow lets v5 saves remain v4-readable for one schema generation, so rolling back v5 reverts to v4 with no data loss.
```

---

## 9. Open questions

For Sponsor / Priya / Uma / orchestrator. Not all need resolution before M3 Tier 2 implementation begins, but each affects either the schema shape or the migration semantics.

1. **Pointer-shadow lifetime confirmation.** This doc commits to one schema generation (deprecate at v6). Open: does v6 actually arrive in M3 (e.g., if a class-divergence feature or hub-town-routing change forces another schema bump)? If yes, retire shadows at v6. If v6 doesn't materialize in M3, extend shadows to v7. **Owner:** Devon (decide at next schema-bump dispatch). Default: deprecate at v6.
2. **Slot-count cap enforcement.** Schema permits arbitrary `data.characters[]` length; M3 design defaults to 3 slots (`m3-design-seeds.md §1.1`). Should the schema validate `characters.size() <= 3` at load time, or accept any int and let the title-screen UI enforce the cap? Suggest: schema accepts any int (forward-compat for M4 class-divergence + slot-count increase); UI enforces M3 cap of 3. **Owner:** Drew (title-screen-slot-picker spec — confirm at `86c9uth85` design review).
3. **`active_slot` out-of-range handling.** If `active_slot` indexes past `characters.size()` (e.g., `active_slot: 2` but only 2 characters present), what happens? Suggest: clamp to `characters.size() - 1` at load + emit `WarningBus.warn(...)`. **Owner:** Devon (implement at M3 Tier 2; clamp + warn matches existing v3-newer-than-runtime warning idiom).
4. **Shared-stash item-UID collision policy.** v4 stash entries are per-character; collision wasn't possible. v5 shared_stash is global; two characters might (in theory) drop into the stash items with the same `slot_index` if the per-character stash UI doesn't sequence indices through a shared counter. Suggest: shared_stash slot_indices are assigned by the stash-management code at insert-time using `shared_stash.size()` as the next index, not by the character. Schema is unaffected; the discipline lives in the UI/inventory code. **Owner:** Drew (stash UI dispatch, when authored).
5. **`stash_ui_state` rename to `hub_town_ui_state` in v5?** v4's `stash_ui_state` is per-character. In v5 the hub-town generalizes the stash-room (`m3-design-seeds.md §2`). Should `stash_ui_state` rename to `hub_town_ui_state`, with `stash_room_seen` becoming `hub_town_seen` (but per-character vs the account-scoped meta `hub_town_seen`)? Suggest: keep `stash_ui_state` for v5 (rename is its own non-additive bump; not worth piggy-backing here). M4 may rename. **Owner:** Uma + Devon at M3 Tier 2 implementation review.

---

## 10. Hand-off

- **M3 Tier 2 implementation dispatch (Devon, future):** turn this spec into real `_migrate_v4_to_v5` in `Save.gd`, bump `SCHEMA_VERSION` to 5, update `DEFAULT_PAYLOAD` with the v5 multi-character structure, update `team/devon-dev/save-format.md` with the v5 shape table.
- **Tess (M3 Tier 2 acceptance):** author the eight fixtures in §6, pin the eight INV-* invariants in `tests/test_save_migration_v5.gd` following the v0→v1 idiom + v3→v4 (when it lands) pattern. Add `NoWarningGuard` per `.claude/docs/test-conventions.md` (every save-load / content-resolution test must route warnings through `WarningBus`).
- **Drew (parallel M3 Tier 2):** consume `data.characters[]` + `active_slot` in the title-screen slot-picker scene. Read shape from this spec; no engine work needed by Drew (Devon owns the migration + Save autoload changes).
- **Uma (no immediate action):** the `meta.hub_town_seen` first-visit gate is the only audio/visual-direction-adjacent v5 field. Confirm at hub-town visual-direction PR (`86c9uth6a`).
- **Priya (M3 Tier 2 backlog):** sequence the M3 Tier 2 implementation tickets — v5 migration, multi-character UI, hub-town save-state, ember-shard wiring, Paragon points — against this spike's contract. Tier 2 dispatches gate on this PR's merge.

---

## Cross-references

- `team/devon-dev/save-schema-v4-plan.md` — model for this doc; rule 1/2/3 of §4.1 that v5 is the first to break.
- `team/priya-pl/m3-tier-1-plan.md §1` — the dispatch source.
- `team/priya-pl/m3-design-seeds.md §1 + §3` — multi-character + persistent-meta design context.
- `team/priya-pl/m3-shape-options.md` — Shape A locked by Sponsor 2026-05-17.
- `team/priya-pl/risk-register.md` R1 — save-migration breakage risk; this spike is the v5 mitigation surface.
- `scripts/save/Save.gd` — current v3 implementation; v4 + v5 implementation lands in M3 Tier 2.
- `tests/test_save_migration.gd` — existing migration-test idiom; v5 test mirrors it.
- `tests/fixtures/save_v0_*.json` — existing v0 fixtures; INV-8 chains through them.
- `.claude/docs/test-conventions.md` — universal warning gate; v5 migration test must use `NoWarningGuard` for all non-expected warning paths.
- `.claude/docs/html5-export.md` — HTML5 storage context for §7 OPFS analysis.
- `team/decisions/DECISIONS.md` — v5 decision draft batched into Priya's weekly DECISIONS roll-up.

---

## 11. Non-obvious findings

1. **v4 isn't actually shipped yet.** The current runtime `Save.gd` is at `SCHEMA_VERSION = 3`; the v4 plan exists as paper. M3 Tier 2 implementation may bundle the v3→v4 migration and the v4→v5 migration into a single PR. The migration chain is order-stable, so v3→v4→v5 on a v3 save produces the same outcome as v3→v5 directly. Implementation sequencing is the M3 Tier 2 PR author's call; this spike is contract-only.
2. **The pointer-shadow doctrine is the project's "soft-rename" pattern.** v3 keeps flat `vigor/focus/edge` alongside `stats.{vigor,focus,edge}`; v4 keeps `data.stash` (root) alongside `character.stash`; v5 extends the pattern to `data.character` ↔ `data.characters[active_slot]`. The pattern is "rename without breaking" — the new canonical lives next to the old shadow for one schema generation. Recognizing this as the project's emergent doctrine (not a per-bump improvisation) is the most useful framing for future schema-bump authors.
3. **INV-5 (pointer-shadow drift detector) is the most-novel test of the v5 PR.** Every other invariant has a v4-plan analog. INV-5 is new because it tests a runtime discipline (shadow read-only-ness), not just a migration shape. The test fails the moment any code path mutates `data.character` directly without refreshing the canonical — the discipline is enforced empirically rather than by code-review vigilance.
4. **Save-schema bumps are doc-PRs first, code-PRs second.** v4 was authored as a spike doc; v5 follows the same pattern. The spike-first cadence catches design errors at the cheapest review cost (paper review) before any feature ticket consumes the schema. The team should canonize this — every non-trivial schema bump gets a spike-first doc PR, even when the bump is purely additive. The cost is ~3-5 ticks of design effort; the savings are "no feature-ticket rework when the schema turns out wrong."
5. **The "non-additive permitted with discipline" rule (§4.3 rule 6) is the v5 contribution to the project's schema doctrine.** v4's additive-only rule is correct for additive growth but offers no playbook for a feature that genuinely can't be additive. The five-step discipline (document violation / pointer-shadow / schedule deprecation / pin fixture / justify-in-writing) is the playbook v6+ inherits. This is the most-durable thing this spike doc adds, beyond v5 itself.
