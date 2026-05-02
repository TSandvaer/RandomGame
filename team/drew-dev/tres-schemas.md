# TRES Content Schemas — Embergrave

**Owner:** Drew (content systems)
**Status:** v1 draft, M1-ready. Will evolve as M2 widens slot count and affix pool.
**Audience:** Devon (engine — these resources flow through combat / save / loader code), Uma (item display surfaces), Tess (test data factories), Priya (sign-off when M1 stat curve is pinned).

## Why TRES (not JSON, not CSV, not GDScript dicts)

Per `team/priya-pl/tech-stack.md`:

- **TRES** = Godot's native serialized `Resource` format. Authored in the Godot editor inspector or by hand, version-controlled as text, hot-reloadable, and the inspector auto-generates a UI for typed `@export` fields.
- **JSON** is reserved for **save files** (mutable user state). TRES is reserved for **content data** (immutable, designer-authored, shipped with the build).
- **CSV/dict** loses type safety, autocomplete, and inspector editing. Pure dicts are also painful to refactor when an enum changes.

**Hard rule:** Content TRES files never carry runtime mutable state. A `MobDef` describes *what a Grunt is*; a `Mob` node *instances* one and tracks current HP. Don't mutate the resource at runtime — copy needed values into the node.

## Reference graph (composition, not inheritance)

```
LootTableDef
  └─ entries: Array[LootEntry]            # LootEntry is a small Resource
        └─ item_def: ItemDef               # by-reference, ext_resource
        └─ weight: float
        └─ tier_modifier: int

MobDef
  └─ loot_table: LootTableDef              # by-reference
  └─ ai_behavior_tag: StringName

ItemDef
  └─ base_stats: ItemBaseStats             # small Resource (struct-shaped)
  └─ affix_pool: Array[AffixDef]           # by-reference

AffixDef
  └─ value_ranges: Array[AffixValueRange]  # length 3 — one per tier T1/T2/T3
        └─ min: float
        └─ max: float
```

**All cross-references use Godot's `ext_resource` mechanism** (the editor wires this when you drag a `.tres` into an exported `Resource` slot). This means:

- One canonical `affix_swift.tres` exists. Every `ItemDef` that allows it points to the same file. Tweaking the affix's value range tweaks every item.
- Circular references are forbidden by Godot's loader. Our graph is a strict DAG (Loot → Item → Affix; Mob → Loot).

All resource classes are registered with `class_name` so Godot's type system, autocomplete, and `is`/`as` checks work everywhere.

---

## 1. `MobDef` — `res://resources/mobs/<id>.tres`

```gdscript
class_name MobDef
extends Resource

## Stable identifier. Snake_case, unique across all MobDefs. Used as save-file
## key and content lookup. Never localize, never change after a mob ships.
@export var id: StringName = &""

## Player-visible name. Localized later via Godot tr() — keep en-source here for M1.
@export var display_name: String = ""

## res:// path to the sprite sheet (PNG). For M1 a single idle frame is fine;
## animations come in M2 with AnimatedSprite2D and a SpriteFrames sub-resource.
@export_file("*.png") var sprite_path: String = ""

## --- Combat stats ---
## Base values. Stratum scaling multipliers live elsewhere (StratumDef in M2);
## for M1 these are the literal HP/damage the Grunt spawns with.
@export_range(1, 9999, 1) var hp_base: int = 50
@export_range(0, 999, 1) var damage_base: int = 5

## Pixels per second. Player walks ~120 px/s as a reference.
@export_range(0.0, 500.0, 1.0) var move_speed: float = 60.0

## --- AI ---
## Drives which AI script the spawner attaches. M1 supports:
##   &"melee_chaser"  — walk straight at player, swing on contact
##   &"ranged_kiter"  — M2
##   &"charger"       — M2
## Using StringName (not enum) so future archetypes can be added without
## touching this script. The MobSpawner has a tag → AIBehavior mapping.
@export var ai_behavior_tag: StringName = &"melee_chaser"

## --- Drops ---
## What the mob drops on death. Nullable — bosses with hand-placed drops can
## leave this empty and use a different mechanism.
@export var loot_table: LootTableDef

## --- Progression ---
@export_range(0, 9999, 1) var xp_reward: int = 10
```

**Validation hooks** (Drew owns; M2 may move into a `_validate_property` or editor plugin):

- `id` must be non-empty and snake_case.
- `sprite_path` must point at an existing file (Godot's resource loader will yell anyway).
- `hp_base >= 1`, `damage_base >= 0`, `move_speed >= 0`.
- `ai_behavior_tag` must resolve to a registered AI behavior in `AIBehaviorRegistry`.

---

## 2. `ItemDef` — `res://resources/items/<slot>/<id>.tres`

```gdscript
class_name ItemDef
extends Resource

## Stable identifier (snake_case, unique).
@export var id: StringName = &""

@export var display_name: String = ""

## Slot enum — restricts what equipment slot the item fits.
## M1 only uses WEAPON and ARMOR. Off-hand/trinket/relic come in M2.
enum Slot { WEAPON, ARMOR, OFF_HAND, TRINKET, RELIC }
@export var slot: Slot = Slot.WEAPON

## Tier — drives drop level, base-stat magnitude, affix count, and color in UI.
## Per game-concept.md: T1 worn (0 affixes), T2 common (1), T3 fine (1–2),
## T4 rare (2–3), T5 heroic (3), T6 mythic (3 + set). M1 ships T1–T3 only.
enum Tier { T1, T2, T3, T4, T5, T6 }
@export var tier: Tier = Tier.T1

@export_file("*.png") var icon_path: String = ""

## Base stats — flat, pre-affix. Wrapped in a sub-resource so Godot inspector
## groups them and so we can extend (add armor_pen, attack_speed, ...) without
## breaking saved files. ItemBaseStats has its own class_name below.
@export var base_stats: ItemBaseStats

## Allowed affixes for this item. The roller picks N from this pool with no
## duplicates per item. Empty for T1 (which has 0 affixes by spec).
@export var affix_pool: Array[AffixDef] = []
```

### `ItemBaseStats` — sub-resource (composition)

```gdscript
class_name ItemBaseStats
extends Resource

## Weapon-relevant.
@export_range(0, 999, 1) var damage: int = 0

## Armor-relevant. M1 keeps it as a flat damage-reduction value; M2 may split
## into physical/elemental.
@export_range(0, 999, 1) var armor: int = 0

## Universal stat boosts the item grants when equipped, before any affixes.
@export_range(0, 999, 1) var max_hp_bonus: int = 0
@export_range(0.0, 1.0, 0.01) var crit_chance_bonus: float = 0.0
```

**Why a sub-resource and not flat fields on `ItemDef`?**

1. The inventory UI (Uma's surface) reads `base_stats` as one unit — passes the whole sub-resource into a stats panel widget.
2. Future slot types (relic, trinket) want different stat shapes; we'll subclass `ItemBaseStats` if needed without touching `ItemDef` callers.
3. Save serialization (Devon's surface) pickles base stats as one nested object — easier to migrate.

**Affix count by tier** (lives in `LootRoller`, not `ItemDef`, so it's tunable in one place):

| Tier | Affix count | M1? |
|------|-------------|-----|
| T1   | 0           | yes |
| T2   | 1           | yes |
| T3   | 1–2 (roll)  | yes |
| T4   | 2–3         | M2  |
| T5   | 3           | M2  |
| T6   | 3 + set     | M3  |

---

## 3. `AffixDef` — `res://resources/affixes/<id>.tres`

```gdscript
class_name AffixDef
extends Resource

## Stable identifier (snake_case, unique). E.g. &"swift", &"vital", &"keen".
@export var id: StringName = &""

## Player-visible name. Used in tooltip prefix/suffix construction —
## "Swift Iron Sword", "Iron Sword of Vitality", etc. (Prefix vs suffix
## choice is M2; M1 just appends.)
@export var name: String = ""

## Which character/item stat this affix modifies. StringName lookup in the
## stats system. Examples: &"max_hp", &"move_speed_pct", &"crit_chance",
## &"damage_flat", &"damage_pct". Devon's stat system owns the canonical list.
@export var stat_modified: StringName = &""

## Rolled value range per item-tier. Index 0 = T1, 1 = T2, 2 = T3.
## We array these instead of one range × multiplier so designers can hand-tune
## a curve that isn't strictly multiplicative (e.g. T3 jumps for crit affixes).
## Length is enforced to 3 in M1; will grow to 6 when T4–T6 ship in M2/M3.
@export var value_ranges: Array[AffixValueRange] = []

## Whether the rolled value is added to the stat or scales it.
## ADD: rolled = +12 → stat += 12
## MUL: rolled = 0.08 → stat *= (1 + 0.08)
enum ApplyMode { ADD, MUL }
@export var apply_mode: ApplyMode = ApplyMode.ADD
```

### `AffixValueRange` — sub-resource

```gdscript
class_name AffixValueRange
extends Resource

@export var min_value: float = 0.0
@export var max_value: float = 0.0
```

**Roll algorithm** (lives in `LootRoller`, documented here for clarity):

```
rolled_value = lerp(value_ranges[tier_index].min_value,
                    value_ranges[tier_index].max_value,
                    rng.randf())
```

We use `lerp` (uniform) for M1. M2 may switch to a triangular distribution to push rolls toward median for feel; that's a one-line change in the roller.

**Validation hooks:**

- `value_ranges.size() == 3` for M1 (one per shipped tier). The roller hard-asserts.
- `value_ranges[i].max_value >= value_ranges[i].min_value`.
- `value_ranges` should be monotone non-decreasing across tiers (T2 max ≥ T1 max). Soft warn in editor; not enforced — designers can break it deliberately.

---

## 4. `LootTableDef` — `res://resources/loot_tables/<id>.tres`

```gdscript
class_name LootTableDef
extends Resource

@export var id: StringName = &""

## All possible drops. Each entry is rolled independently per kill —
## a mob can drop multiple items from one table.
@export var entries: Array[LootEntry] = []

## How many entries to roll. -1 = roll all entries independently with their
## per-entry chance; otherwise pick exactly N entries weighted by `weight`.
## M1 default: -1 (independent rolls — simpler, debugs cleaner).
@export var roll_count: int = -1
```

### `LootEntry` — sub-resource

```gdscript
class_name LootEntry
extends Resource

## The item that may drop. The roller will instantiate one ItemInstance
## from this def, applying tier_modifier and affix rolls.
@export var item_def: ItemDef

## In independent-roll mode (LootTableDef.roll_count == -1):
##   weight is interpreted as 0.0–1.0 drop chance.
## In weighted-pick mode (roll_count >= 0):
##   weight is relative weight in a weighted random pick.
## We document this dual interpretation here because it's the most likely
## footgun for content authors. The inspector shows it as `weight (0–1 chance
## OR relative weight, see LootTableDef.roll_count)`.
@export_range(0.0, 100.0, 0.01) var weight: float = 1.0

## Adjusts the tier of the rolled item relative to ItemDef.tier.
## Example: ItemDef is T2, tier_modifier = 1 → rolled item is T3.
## Clamped to T1..T6 when applied. Lets one ItemDef ("Iron Sword") drop
## as T1/T2/T3 from different mobs without three separate ItemDefs.
@export_range(-2, 2, 1) var tier_modifier: int = 0
```

**Why entries as Resources, not just Dicts?**

`@export var entries: Array[Dictionary]` would parse but loses inspector validation, autocomplete, and migration safety when we add fields (e.g. `min_player_level`, `quest_only` flags) in M2. Sub-resources are 5 minutes more upfront for years of payoff.

---

## 5. Runtime instances (NOT TRES — for context only)

Content TRES → spawned **runtime objects** that DO carry mutable state. These are not in this doc's scope but we sketch them so the schema makes sense:

```gdscript
class_name ItemInstance
extends RefCounted

var def: ItemDef                         # the static template
var rolled_tier: ItemDef.Tier            # after tier_modifier applied
var rolled_affixes: Array[AffixRoll]     # what actually rolled
var unique_id: String                    # uuid for save/equip/inventory tracking

class_name AffixRoll
extends RefCounted

var def: AffixDef
var rolled_value: float
```

`ItemInstance` is what the inventory holds, what `save.json` serializes, and what equipping mutates the player's stat block from. **`ItemDef` never changes; `ItemInstance` is per-drop.**

---

## File layout (aligned with Devon's repo-root project layout decision, 2026-05-01)

```
res://
  resources/                    # TRES content (per Devon's project-layout decision)
    mobs/
      grunt.tres                # MobDef
    items/
      weapons/
        iron_sword.tres         # ItemDef (slot=WEAPON)
        rusted_dagger.tres
      armors/
        leather_vest.tres       # ItemDef (slot=ARMOR)
    affixes/
      swift.tres                # AffixDef (move_speed_pct)
      vital.tres                # AffixDef (max_hp ADD)
      keen.tres                 # AffixDef (crit_chance ADD)
    loot_tables/
      grunt_drops.tres          # LootTableDef
  scripts/
    content/                    # the class_name'd .gd files for the above
      mob_def.gd
      item_def.gd
      item_base_stats.gd
      affix_def.gd
      affix_value_range.gd
      loot_table_def.gd
      loot_entry.gd
```

M1 ships **3 affixes total** (matches `mvp-scope.md` "3 affixes total in pool"): `swift`, `vital`, `keen`. Concrete proposed values:

| Affix  | stat_modified         | apply_mode | T1 range  | T2 range  | T3 range   |
|--------|-----------------------|------------|-----------|-----------|------------|
| swift  | `move_speed_pct`      | MUL        | 0.02–0.04 | 0.04–0.08 | 0.08–0.12  |
| vital  | `max_hp`              | ADD        | 4–8       | 8–14      | 14–22      |
| keen   | `crit_chance`         | ADD        | 0.02–0.04 | 0.04–0.07 | 0.07–0.10  |

**These ranges are placeholders** — Priya owns the M1 stat curve. Logged below in "Open decisions".

---

## Open decisions (awaiting Priya / orchestrator)

1. **M1 stat curves** — the affix value ranges above are reasonable defaults but unsigned. Priya should pin them (or delegate to Drew with a balance-pass tick later). Not a blocker for schema sign-off; values can change without schema change.
2. **`stat_modified` canonical list** — Devon owns the player stat block. Drew + Devon must converge on the StringName keys (`&"max_hp"` vs `&"hp_max"` vs `&"vigor"`-derived). Tracked separately; doesn't block schema.
3. **Localization key** — `display_name` is en-source for M1 per tech-stack.md (post-M2 deferral). Schema does not change when localization lands; we'll add `display_name_key` and stop using `display_name` directly. Reversible.

## Out of scope for M1 schema (M2+)

- Set bonuses (T6 mythic) — adds `set_id: StringName` on `ItemDef`.
- Unique items with hardcoded affixes — adds `forced_affixes: Array[AffixRoll]` on `ItemDef`.
- Quest-locked drops — adds `quest_gate: StringName` on `LootEntry`.
- Stratum scaling — adds `StratumDef` resource that multiplies `MobDef` stats.
- Animations — `MobDef.sprite_path` becomes `MobDef.sprite_frames: SpriteFrames` (Godot's animation resource).

These are explicit non-changes for M1. The schema is forward-extensible via additive fields with defaults; no migration needed when they land.

---

## Test data factories (per `team/TESTING_BAR.md`)

Every Resource class above ships a paired **factory** in `tests/factories/` so Tess can build deterministic fixtures inside GUT tests without depending on authored `.tres` files (which a balance-pass might mutate). Factories live alongside production code; they are **the testing bar's hook into content**.

**Pattern:** static method per Resource type, named `make_<type>(overrides: Dictionary = {}) -> <Type>`. Sensible M1 defaults; `overrides` dictionary lets a single test customize one or two fields without rebuilding the whole object.

```gdscript
# tests/factories/content_factory.gd
class_name ContentFactory

static func make_affix_value_range(min_v: float = 1.0, max_v: float = 5.0) -> AffixValueRange:
    var r := AffixValueRange.new()
    r.min_value = min_v
    r.max_value = max_v
    return r

static func make_affix_def(overrides: Dictionary = {}) -> AffixDef:
    var a := AffixDef.new()
    a.id = overrides.get("id", &"test_swift")
    a.name = overrides.get("name", "Swift")
    a.stat_modified = overrides.get("stat_modified", &"move_speed_pct")
    a.apply_mode = overrides.get("apply_mode", AffixDef.ApplyMode.MUL)
    a.value_ranges = overrides.get("value_ranges", [
        make_affix_value_range(0.02, 0.04),  # T1
        make_affix_value_range(0.04, 0.08),  # T2
        make_affix_value_range(0.08, 0.12),  # T3
    ])
    return a

static func make_item_base_stats(overrides: Dictionary = {}) -> ItemBaseStats:
    var s := ItemBaseStats.new()
    s.damage = overrides.get("damage", 0)
    s.armor = overrides.get("armor", 0)
    s.max_hp_bonus = overrides.get("max_hp_bonus", 0)
    s.crit_chance_bonus = overrides.get("crit_chance_bonus", 0.0)
    return s

static func make_item_def(overrides: Dictionary = {}) -> ItemDef:
    var i := ItemDef.new()
    i.id = overrides.get("id", &"test_iron_sword")
    i.display_name = overrides.get("display_name", "Iron Sword")
    i.slot = overrides.get("slot", ItemDef.Slot.WEAPON)
    i.tier = overrides.get("tier", ItemDef.Tier.T1)
    i.icon_path = overrides.get("icon_path", "")
    i.base_stats = overrides.get("base_stats", make_item_base_stats({"damage": 5}))
    i.affix_pool = overrides.get("affix_pool", [])
    return i

static func make_loot_entry(item: ItemDef, weight: float = 1.0, tier_mod: int = 0) -> LootEntry:
    var e := LootEntry.new()
    e.item_def = item
    e.weight = weight
    e.tier_modifier = tier_mod
    return e

static func make_loot_table(overrides: Dictionary = {}) -> LootTableDef:
    var t := LootTableDef.new()
    t.id = overrides.get("id", &"test_loot_table")
    t.entries = overrides.get("entries", [
        make_loot_entry(make_item_def(), 1.0, 0),
    ])
    t.roll_count = overrides.get("roll_count", -1)
    return t

static func make_mob_def(overrides: Dictionary = {}) -> MobDef:
    var m := MobDef.new()
    m.id = overrides.get("id", &"test_grunt")
    m.display_name = overrides.get("display_name", "Test Grunt")
    m.sprite_path = overrides.get("sprite_path", "")
    m.hp_base = overrides.get("hp_base", 50)
    m.damage_base = overrides.get("damage_base", 5)
    m.move_speed = overrides.get("move_speed", 60.0)
    m.ai_behavior_tag = overrides.get("ai_behavior_tag", &"melee_chaser")
    m.loot_table = overrides.get("loot_table", null)
    m.xp_reward = overrides.get("xp_reward", 10)
    return m
```

**Why factories not authored TRES fixtures for tests:**

1. **Determinism** — a balance pass to `swift.tres` shouldn't break a loot-rolling test that asserts "MUL-mode affix applies as `(1 + value)`". Tests own their inputs.
2. **Override ergonomics** — tests pass `{"tier": ItemDef.Tier.T3}` to make a T3 variant; no need to maintain N test-only `.tres` files.
3. **No filesystem coupling** — factories run pure in-memory, faster CI, no `.tres` discovery hassle in headless GUT.
4. **Cross-role contract** — Tess writes assertions against factory output; if Drew changes a Resource's required fields, the factory breaks loudly in one place rather than in N test files.

**Tess's expected use** (sketch — Tess owns final test code):

```gdscript
# tests/test_loot_roller.gd  — Drew writes the implementation tests for task #10
extends GutTest

var roller: LootRoller

func before_each() -> void:
    roller = LootRoller.new()
    roller.seed_rng(42)  # determinism

func test_empty_table_drops_nothing() -> void:
    var table := ContentFactory.make_loot_table({"entries": []})
    assert_eq(roller.roll(table).size(), 0)

func test_single_entry_full_weight_always_drops() -> void:
    var table := ContentFactory.make_loot_table({
        "entries": [ContentFactory.make_loot_entry(ContentFactory.make_item_def(), 1.0, 0)]
    })
    var drops := roller.roll(table)
    assert_eq(drops.size(), 1)

func test_zero_weight_never_drops() -> void:
    var table := ContentFactory.make_loot_table({
        "entries": [ContentFactory.make_loot_entry(ContentFactory.make_item_def(), 0.0, 0)]
    })
    assert_eq(roller.roll(table).size(), 0)

func test_tier_modifier_clamps_to_t6() -> void:
    var item := ContentFactory.make_item_def({"tier": ItemDef.Tier.T5})
    var entry := ContentFactory.make_loot_entry(item, 1.0, 5)  # would push past T6
    var drops := roller.roll(ContentFactory.make_loot_table({"entries": [entry]}))
    assert_eq(drops[0].rolled_tier, ItemDef.Tier.T6)

func test_affix_value_within_tier_range() -> void:
    # 1000 rolls of a T2 affix must all land inside [T2.min, T2.max]
    var affix := ContentFactory.make_affix_def()
    for i in 1000:
        var rolled := roller.roll_affix(affix, ItemDef.Tier.T2)
        assert_between(rolled.rolled_value, 0.04, 0.08)
```

**Edge cases the loot-roller tests MUST cover (per testing bar item #6 — three failure modes):**

1. **Empty loot table** → returns empty array, no crash.
2. **Zero-weight entry in independent-roll mode** → never drops.
3. **All-zero-weight in weighted-pick mode** → returns empty array, no crash, logs warning.
4. **Single-item table with weight 1.0** → always drops in independent mode.
5. **Tier modifier overflow** (T5 + 5) → clamps to T6, doesn't error.
6. **Tier modifier underflow** (T1 - 2) → clamps to T1.
7. **Affix `value_ranges` shorter than tier index** → roller hard-asserts (loud failure better than silent zero roll).
8. **Same RNG seed → same drops** (determinism contract for CI reproducibility).
9. **Affix value distribution** — 1000 rolls of T2 affix all inside `[min, max]`.
10. **MUL apply_mode math** — rolled 0.10 → stat scales by 1.10, not 0.10.

These are the test cases Drew commits alongside `LootRoller.gd` in task #10. Tess may add more; Drew may not ship task #10 with fewer.

---

## Sign-off checklist (when scaffold lands)

- [ ] `scripts/content/*.gd` files created from snippets above, each with `class_name` registered.
- [ ] `resources/mobs/grunt.tres` authored against `MobDef` per task #8.
- [ ] `resources/affixes/{swift,vital,keen}.tres` authored.
- [ ] `resources/items/weapons/iron_sword.tres` + `resources/items/armors/leather_vest.tres` (the M1 T1 drop stubs per task #10).
- [ ] `resources/loot_tables/grunt_drops.tres` wired to drop iron_sword + leather_vest.
- [ ] One round-trip test: load `grunt.tres` in `_ready()`, print fields, confirm types resolve, no parse warnings.
- [ ] Devon reviews the `class_name` choices for collision with engine code (e.g. nothing else is grabbing `ItemDef`).
- [ ] `tests/factories/content_factory.gd` lands alongside the production scripts (M1 testing bar).
- [ ] One smoke test `tests/test_content_factory.gd` exercises every `make_*` to catch field drift early.
