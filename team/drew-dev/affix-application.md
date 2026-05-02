# Affix application — Embergrave

**Owner:** Drew (content systems)
**Status:** v1, M1 ship. Ticket `86c9kxx5p`.
**Audience:** Devon (engine — Player + Damage formula chain), Tess (paired-tests bar), Priya (balance pass `86c9kxx61` consumes the same machinery), Uma (tooltip text consumes the display methods on `ItemInstance`).

## TL;DR

Affixes are **rolled at loot-drop time** (LootRoller) and **applied at equip time** (Player.equip_item). PlayerStats owns Vigor/Focus/Edge modifiers; Player.gd owns move_speed modifiers. Unequip reverses exactly. Re-equip is idempotent.

## The pipeline

```
mob death
  └─ MobLootSpawner.on_mob_died
        └─ LootRoller.roll(loot_table)
              └─ for each surviving entry: _make_instance
                    └─ ItemInstance.new(item_def, rolled_tier)
                    └─ rolled_affixes = roll_affixes_for_item(pool, tier)   ← seeded RNG
              ↓
        spawn Pickup nodes carrying ItemInstances
              ↓
player walks over Pickup -> picked_up signal -> inventory acquires ItemInstance
              ↓
player equips: Player.equip_item(instance)
  └─ _apply_item_affixes(instance)
        └─ for each AffixRoll: _apply_single_affix
              ↓
              dispatched by stat_modified:
                vigor / focus / edge   →  PlayerStats.apply_affix_modifier
                move_speed             →  Player._move_speed_bonus accumulator
                <other>                →  push_warning, ignore (M2 hookup)
              ↓
        Stat reads (Player.get_vigor / get_edge / get_walk_speed) return modified values
        Damage formula reads via Player.get_edge()  ←  affix bonus visible to combat
        Mob hits read via Player.get_vigor()        ←  affix mitigation visible to combat
```

Unequip is the same flow in reverse — `_reverse_item_affixes` walks the same rolled affixes and pumps `clear_affix_modifier` / `-= bonus` to undo exactly.

## ApplyMode math

Affixes have two modes (`AffixDef.ApplyMode`):

- **ADD (mode = 0):** the rolled value is added to the stat's modifier sum.
- **MUL (mode = 1):** the rolled value is added to the *multiplicative* modifier sum (which is then applied as `(1 + sum)` on the base + add side).

### PlayerStats stats (vigor / focus / edge)

```
add_sum = Σ rolled_value[r] for r in active affixes where r.def.stat_modified == stat AND r.def.apply_mode == ADD
mul_sum = Σ rolled_value[r] for r in active affixes where r.def.stat_modified == stat AND r.def.apply_mode == MUL

effective_float = max(0, base + add_sum) * (1.0 + mul_sum)
effective_int   = int(floor(effective_float))
```

`base` is the player-allocated value (level-up points). `effective_int` is what `PlayerStats.get_stat(stat_id)` returns and what the damage formula reads via `Player.get_edge()` / `Player.get_vigor()`.

**Why summed-then-applied (not multiplicative-stacking) for MUL:**

Equipping two `+5%` MUL affixes gives `(1 + 0.10) = 1.10`, not `(1 + 0.05) * (1 + 0.05) = 1.1025`. Tooltip math is then trivially predictable for the player ("two +5% MUL affixes = +10% effective"). Multiplicative stacking is a balance-pass call — change the formula in one spot when M2 wants it.

### Player-local stats (move_speed)

`move_speed` lives on Player.gd as a flat ADD bonus on top of `WALK_SPEED`:

```
walk_speed = WALK_SPEED + _move_speed_bonus
```

ADD-mode `swift` rolls (e.g. +3) increment `_move_speed_bonus` directly. MUL-mode swift (M2) folds into the bonus as `WALK_SPEED * value` so the math stays consistent with `get_walk_speed()` returning a single float.

## M1 affix table (T1 ranges per ticket `86c9kxx5p`; Priya's balance pass `86c9kxx61` may shift)

| Affix  | stat_modified | apply_mode | T1 range  | T2 range  | T3 range   |
|--------|---------------|------------|-----------|-----------|------------|
| swift  | `move_speed`  | ADD        | 2–5       | 5–9       | 9–14       |
| vital  | `vigor`       | ADD        | 5–15      | 15–25     | 25–40      |
| keen   | `edge`        | ADD        | 1–3       | 3–6       | 6–10       |

These supersede the placeholder `move_speed_pct (MUL)` / `max_hp (ADD)` / `crit_chance (ADD)` set Drew authored in run-002 — the run-002 stat names didn't have a hookup in the M1 stat system (PlayerStats only knows V/F/E; max_hp / crit_chance live on items, not the player). Switching to V/F/E + move_speed makes M1 affixes do something the player feels in combat.

The previous T1 numeric ranges (`0.02–0.04` MUL, `4–8` ADD, `0.02–0.04` ADD) were calibrated to fractions/multipliers; the new ranges are flat-ADD integers calibrated to PlayerStats's allocation magnitudes (Edge ≈ 1 point per level → +1 affix is on-par with one allocation; Vigor cap at 25 → +5–15 is meaningful at L1 but not trivializing).

## Affix-count-by-tier

Per `team/drew-dev/tres-schemas.md` § "Affix count by tier":

| Tier | Affix count | M1? |
|------|-------------|-----|
| T1   | 0           | yes |
| T2   | 1           | yes |
| T3   | 1–2 (roll)  | yes |
| T4+  | M2          |     |

The ticket's "N=1 for T1, 2 for T2, 3 for T3" sketch was reconciled to the schema doc's existing values (T1=0, T2=1, T3=1–2). The schema values are what shipped in `LootRoller.affix_count_for_tier` and what `tests/test_loot_roller.gd` already covers; aligning the new M1 rollout to that contract avoids breaking 8 already-green tests on the loot-roller side. Logged as a DECISIONS.md entry.

## Determinism contract

`LootRoller` owns the seeded RNG. `seed_rng(seed: int)` resets it; the same seed produces identical drop sequences AND identical rolled affix values (same `lerp(min, max, rng.randf())` chain). This contract is asserted by `test_loot_roller.gd::test_same_seed_produces_same_drops` and reaffirmed in the affix-system test suite.

`Player.equip_item` is deterministic — no RNG. Two saves with identical equipped instances (post-load) reach identical PlayerStats values.

## Save round-trip

Per `team/devon-dev/save-format.md` §"stash":

```json
{ "id": "iron_sword", "tier": 2, "rolled_affixes": [{"affix_id": "swift", "value": 3.5}] }
```

`ItemInstance.to_save_dict()` produces this shape. `ItemInstance.from_save_dict(dict, item_resolver, affix_resolver)` rebuilds the instance — resolvers map ids to `ItemDef` / `AffixDef`. Affix rolls survive load with float fidelity (JSON round-trip is exact for the magnitudes M1 uses).

**No save schema bump needed** — the v3 stash entry already names `rolled_affixes`, and Devon's existing `test_save_roundtrip.gd::test_save_load_preserves_stash_items` verifies the round-trip. We did NOT bump v3 → v4; the on-disk shape is unchanged.

## Edge cases handled

1. **Re-equipping the same instance twice** — no-op (`_equipped_items[slot] == instance` early-returns; affixes don't double-apply).
2. **Unequipping a slot that was never equipped** — no-op; returns null.
3. **Equipping a different instance into an occupied slot** — auto-unequip the previous instance (reverse its affixes) before applying the new one.
4. **Negative affix value** (M2 debuff) — flows through `apply_affix_modifier` unchanged; the `_add_modifiers[stat]` accumulator can go negative; effective stat is `max(0, base + add_sum)` so the player never reads a negative stat.
5. **Affix with unknown `stat_modified`** — `push_warning`, ignore on apply AND reverse (consistent — what we ignore on apply we ignore on reverse, no leaks).
6. **PlayerStats autoload missing** (bare-instantiated Player in tests) — Player.gd's `_player_stats_autoload()` returns null; affix application for V/F/E silently no-ops. This is acceptable for unit tests that don't care about V/F/E; tests that do care must run inside a SceneTree with the autoload registered.
7. **Multiple items with overlapping affixes** — both contribute; sum stacks per the formula above. Tested in the paired suite.

## Cross-role impacts

- **Devon (engine):** No change to the Damage formula. `Damage.compute_player_damage` reads `weapon.base_stats.damage` unchanged; affix-driven `+edge` bumps the multiplier via the existing `(1 + edge * EDGE_PER_POINT)` term. The damage formula doc anticipated affix integration — it landed on the *upstream* side (PlayerStats), not in `Damage.gd`.
- **Tess (QA):** Paired tests cover all 10 task-spec coverage points + 2 integration points (loot drop → affix; save round-trip). See `tests/test_affix_system.gd` and `tests/test_loot_affix_integration.gd`.
- **Priya (balance):** Ticket `86c9kxx61` tweaks the T1/T2/T3 numeric ranges. Schema is unchanged; balance-pass is a 6-number edit across 3 .tres files.
- **Uma (UI):** `ItemInstance.get_affix_display_lines()` and `get_base_stats_display_lines()` produce the strings the inventory hover panel will display. Devon wires the panel.

## Out of scope for M1 (future)

- **Multiplicative-stacking MUL** — currently summed-then-applied. Switch in `PlayerStats.get_stat`'s formula one-liner.
- **Affixes on player-derived stats (max_hp, crit_chance)** — M2 work; the dispatch table in `Player._apply_single_affix` adds a case.
- **Set bonuses** — T6 mythic; needs `set_id` on `ItemDef` and a registry node listening for "all 4 set pieces equipped".
- **Affix re-roll bench** — M3 crafting.
- **Tooltip prefix/suffix word-position** — currently appends affix names; M2 may distinguish prefix vs suffix per affix.
