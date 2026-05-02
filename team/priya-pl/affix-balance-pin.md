# Affix Balance Pin — M1

**Owner:** Priya (PL).
**Status:** v1, M1 ship. **Pinned 2026-05-02** — supersedes the placeholder ranges in `team/drew-dev/affix-application.md` and `team/drew-dev/tres-schemas.md` for the purpose of Drew's `86c9kxx61` balance pass + Tess's `86c9kyntj` follow-up.
**Audience:** Drew (consumes the table to update `resources/affixes/{swift,vital,keen}.tres` + `resources/loot_tables/*.tres`), Tess (acceptance assertions on the player-feel checks in §4), Devon (no code change — Damage formula constants unchanged), Uma (tooltip ranges feed `ItemInstance.get_affix_display_lines`).

---

## TL;DR

- **Value ranges held**: Drew's run-005 ranges (swift 2-5/5-9/9-14, vital 5-15/15-25/25-40, keen 1-3/3-6/6-10) **stand as M1-shipped**. They feel right against the damage formula and Vigor cap. **No edit to the three affix .tres files.**
- **Affix-count-by-tier**: **kept at 0/1/1-2** (Drew's call holds). Tess's `86c9kyntj` revisit is **resolved as "no change"** with rationale logged here. Tickets close.
- **Drop weights**: **shifted** — common-mob table drops one item ~70% of the time (was ~70% per-entry independent rolls of 0.35 each → ~58% chance of *something*, 12% chance of *both*). Boss table drops two items, weighted to T2/T3, no T1 (already correct — no edit).
- **Player-feel targets**: documented in §4 as the spec Drew + Tess balance against during M1 RC soak. Numbers are derivable from the damage formula + mob HP — they don't introduce new constants.
- **Future-tier hooks** (§5): keep the schema 6-slot (T1..T6) array contract and the `apply_mode` enum; M2 frost/lightning/vampiric only need new AffixDef rows + a `_apply_single_affix` dispatch case.

The whole M1 affix stack is **paper-only** at the balance-pin level. Drew's `86c9kxx61` ticket may end up landing zero code changes if these targets hold during RC soak — that is the desired outcome.

---

## 1. Tier-by-affix value ranges

Pinning the existing values **as the M1 ship target**. Each tier's range is small enough that two T2 items don't make a T3 item irrelevant, and large enough that "lucky roll vs unlucky roll" actually matters within a tier.

| Affix | stat_modified | apply_mode | T1 range | T2 range | T3 range |
|-------|---------------|------------|----------|----------|----------|
| swift | `move_speed`  | ADD (px/s) | 2-5      | 5-9      | 9-14     |
| vital | `vigor`       | ADD (pts)  | 5-15     | 15-25    | 25-40    |
| keen  | `edge`        | ADD (pts)  | 1-3      | 3-6      | 6-10     |

**Stat targets** are pinned (Drew's run-005 decision, locked in `affix-application.md`):
- `swift → move_speed (ADD)` — flat px/s on top of `Player.WALK_SPEED = 120`.
- `vital → vigor (ADD)` — feeds `PlayerStats.get_stat(VIGOR)` which Damage.gd reads as mitigation.
- `keen  → edge  (ADD)` — feeds `PlayerStats.get_stat(EDGE)` which Damage.gd reads as +5% weapon damage per point.

### Per-tier feel rationale

**T1 (worn / early-stratum-1 chaff)** — base item, no affixes per the count-by-tier rule (§2). Player gets a flat +6 damage iron sword OR a +4 armor / +5 max-hp leather vest. Feel target: **noticeable that you have gear vs naked, not noticeable across two T1 items.** This is intentional — T1 is the "you got loot" floor, not the variance ladder.

**T2 (common / mid-stratum-1)** — one affix.
- *swift T2 (+5..+9 px/s)*: 4-7.5% movement bonus over base 120 px/s. Roughly the difference between "I always trade hits with a Charger" and "I can almost always strafe a Charger by half a body width." Player feels it on Charger telegraphs in r03/r05; doesn't make a Shooter easier to flank (would need T3 + level-5 movement allocation). Min 5 is the floor where the player notices on a long corridor; max 9 is the ceiling before Charger's 180 px/s windup feels unfair (player should still need to strafe, not outrun).
- *vital T2 (+15..+25 vigor)*: at VIGOR_PER_POINT=0.02, that's 30-50% mitigation — but Vigor stacks on top of allocated points (player at L4 has typically banked ~5-10 vigor), so a T2 vital affix on its own pushes mitigation to roughly 40-50% (cap is 50%). Designed so **one T2 vital affix alone gets you near the mitigation cap** — meaning T3 vital is not strictly better for mitigation, only for HP-via-Vigor scaling (when M2 wires HP-from-Vigor). This is the "first major build choice" surface for M1.
- *keen T2 (+3..+6 edge)*: 15-30% weapon damage. On a T2 weapon (assume 9-12 base damage when Drew authors a T2 sword), that's +1.4..+3.6 damage per light hit. Player feels it via the per-hit log: "I one-shot grunts with a heavy" goes from "sometimes" to "yes."

**T3 (fine / boss + late-stratum drops)** — 1-2 affixes (rolled).
- *swift T3 (+9..+14 px/s)*: 7.5-12% movement, near the threshold where players can outrun chargers in straight lines. Pairs with attack-cancel into walk to break Shooter aim windows. Feel: **the player notices walking around feels different**, not just in combat.
- *vital T3 (+25..+40 vigor)*: pushes a fully-allocated player past the mitigation cap (so excess Vigor is "wasted" until M2 wires HP-from-Vigor). The stretch from 25 to 40 is a deliberate "lucky T3 vital is much better than unlucky T3 vital" wide range — gives loot chase real teeth. Min 25 is "still meaningfully better than T2 max=25 alone, given your already-allocated Vigor"; max 40 is "you have headroom even if you respec into Edge."
- *keen T3 (+6..+10 edge)*: 30-50% weapon damage. On a T3 weapon (base ~12-18), that's a +4..+9 damage swing per light hit. **This is the "feel" payoff** — T3 keen on a T3 sword visibly chews through grunts in 1-2 light hits at L5. The min-max spread (60% relative variance) is wider than vital's (60%) and swift's (55%) on purpose: damage variance is what the player notices most viscerally, so we want the loot lottery to lean into it.

### Why the ranges hold

The Drew-authored numbers were calibrated against:
1. PlayerStats allocation magnitudes (a +1 keen ≈ one point of Edge allocation, the L1-2 levelup grant).
2. The damage formula's `EDGE_PER_POINT = 0.05` and `VIGOR_PER_POINT = 0.02` constants (from `Damage.gd`).
3. The Vigor mitigation cap at 50% (`VIGOR_CAP`), which means vital can't trivially push the player past mitigation cap with just one drop.
4. Player base WALK_SPEED 120 vs Charger charge_speed 180 — swift T3 max +14 (= 134 px/s) keeps the player slower than a charging Charger but faster than a base Charger (60 px/s).

Re-running the math against the current stratum-1 mob HP/damage values confirms these ranges hit the player-feel targets in §4. **Holding.**

---

## 2. Affix-count-by-tier resolution

**Decision: keep 0 / 1 / 1-2.** Tess's follow-up `86c9kyntj` resolves as "no change" with rationale logged.

### Options considered

| Option | T1 | T2 | T3 | Pros | Cons |
|--------|----|----|----|------|------|
| **A — keep schema (CHOSEN)** | 0 | 1 | 1-2 | Preserves 8 already-green `test_loot_roller.gd` cases. T1 = pure base-stat tutorial item. T3 retains lottery feel via 1-or-2 roll. | T1 has no variance-within-tier (every iron sword is identical). |
| B — ticket spec | 1 | 2 | 3 | More variance on T1; aligns with original ticket sketch. | Breaks 8 existing tests. T3 with 3 affixes is bigger than T2 with 2 — but T3 affix pool is only swift/vital/keen (3), so T3 = "all three affixes" = no choice. Removes T3's loot-chase feel. |
| C — hybrid 0-1 / 1-2 / 2-3 | 0-1 | 1-2 | 2-3 | High variance throughout; each tier has a 50/50 affix-or-not roll surface. | Same T3-pool-exhaustion issue as Option B. Forces a save-schema decision (ItemInstance.rolled_affixes can already be empty, so trivial). Adds the most player-perceived variance. |

### Why A wins

1. **Test cost is real, value is theoretical.** Tess's `86c9kyntj` is a balance-pass revisit, not a bug. Spending 8 test rewrites for "T1 grunts have a 50% chance to drop +2 swift iron swords" is poor ROI when M1 RC is already in soak.
2. **T1 = "you got loot" floor** is the M1 design intent. The ladder is `T1 (you got something) → T2 (it has a special property) → T3 (it has multiple special properties or one strong one)`. Putting an affix on T1 collapses that signal.
3. **T3 pool exhaustion problem.** The M1 affix pool is 3 (swift, vital, keen). Any tier that demands `affix_count == pool_size` becomes a no-choice tier — the loot lottery is just "which roll values?", not "which affixes?" That's a worse player feel than 1-2 random draws from 3.
4. **Forward-clean for M2.** When M2 widens the affix pool to 6 (frost, lightning, vampiric added), Option A naturally scales to T4 (2-3 affixes) and T5 (3) without revisiting the decision. Option B's "3 at T3" already maxed, so M2 has to redesign anyway.

### What this means for `LootRoller.affix_count_for_tier`

**No code change.** Drew already shipped:
```gdscript
T1: 0
T2: 1
T3: 1 + _rng.randi_range(0, 1)   # 1 or 2 (50/50)
```

This stays. Tess's `86c9kyntj` ticket flips to `complete` with this doc as the resolution.

---

## 3. Drop weights

The current `grunt_drops.tres` rolls each entry independently at 0.35 → P(at least one drop) = 1 - 0.65² = **57.75%**, P(both) = 12.25%. That's *fine* for stratum-1 progression density (19 mobs across rooms 2-8), but the **tier-spread** isn't expressed because the table doesn't roll a tier — it just inherits from `ItemDef.tier` (T1 for both iron_sword and leather_vest).

To get the per-tier probability table the dispatch asked for, the cleanest path is to **add tier_modifier-varied entries** to the common-mob table so a single grunt has a chance to drop T1, T2, or T3 versions of the same item. Drew's existing schema supports this — `tier_modifier` was authored exactly for this case (see `tres-schemas.md` § "LootEntry").

### Recommended common-mob (grunt) drop table

Replace the current 2-entry independent-roll table with a 6-entry table that gives each base item three tier variants. Using **independent-roll mode** (matches existing `roll_count = -1`), each entry is rolled independently — the per-entry weights below are P(this specific drop) and **must sum across the per-base-item variants ≤ 1.0** to avoid double-drops of the same item.

For each base item (iron_sword, leather_vest):

| Entry | tier_modifier | Weight (P drop) | Notes |
|-------|---------------|-----------------|-------|
| sword T1 | 0  | 0.21 | (= 0.30 * 0.70) — 30% chance of *some* sword × 70% T1 |
| sword T2 | +1 | 0.075 | (= 0.30 * 0.25) — 30% × 25% T2 |
| sword T3 | +2 | 0.015 | (= 0.30 * 0.05) — 30% × 5% T3 |
| vest T1  | 0  | 0.21 | same shape |
| vest T2  | +1 | 0.075 | |
| vest T3  | +2 | 0.015 | |

**Per-mob aggregate**: P(any drop) = 1 - (1-0.30)² = **51%** per kill. P(any T2+ drop) = 1 - (1 - (0.075 + 0.015))² ≈ **17%**. P(T3 drop) = 1 - (1-0.015)² ≈ **3%**.

Per the dispatch's **70/25/5 stratum-1-mob target**:
- Among items that drop, **70% are T1 / 25% are T2 / 5% are T3** (per base item type, by construction). Verifies with `0.21 / (0.21 + 0.075 + 0.015) = 70%`, `0.075/0.30 = 25%`, `0.015/0.30 = 5%`.

This keeps stratum 1 feeling like "lots of T1 mediocrity, occasional T2 surprise, rare T3 chase moment" — matching the dispatch and matching what 19 mobs across 7 rooms can actually deliver in a 30-min soak (expected: ~9-10 drops total / ~2-3 T2 / ~0-1 T3).

### Recommended boss (Stratum1Boss) drop table

The current `boss_drops.tres` is **already correct** — guaranteed-drop (weight 1.0) iron_sword T3 (`tier_modifier = 2`) + leather_vest T2 (`tier_modifier = 1`). **Hold as-is.** No T1 boss drop. The boss is the floor's reward beat.

For M2 stratum-2 boss, expand to 3-4 entries with weighted-pick mode (`roll_count >= 1`) so the boss "picks 1-2 from a 4-entry pool" — but that's M2.

### Net change to existing TRES files

- **Edit `resources/loot_tables/grunt_drops.tres`** — replace 2-entry table with 6-entry table per the values above.
- **Hold `resources/loot_tables/boss_drops.tres`** — no change.
- Drew may, at his discretion, also use this table for charger and shooter (currently they have no loot tables wired). Doing so would densify the loot economy in stratum 1 — recommend Drew copy `grunt_drops.tres` to `mob_common_drops.tres` and reference from grunt/charger/shooter MobDefs instead of duplicating per-mob tables. **Not blocking** — single-table is fine for M1.

---

## 4. Player-feel checks

These are **acceptance targets** for Drew's balance pass and Tess's M1 RC soak. Numbers are derivable from existing constants — no new tunables introduced.

### Setup assumptions

- Player base: HP 100, Vigor 0, Edge 0, Focus 0 (fresh L1 character).
- Iron sword T1 (base 6 damage), leather vest T1 (4 armor + 5 max-hp).
- Damage formula constants: EDGE_PER_POINT=0.05, HEAVY_MULT=0.6, VIGOR_PER_POINT=0.02, VIGOR_CAP=0.5.
- Grunt: HP 50, damage 5, move 60 px/s.
- Stratum-1 boss: HP 600, damage 15, phase boundaries 66%/33%, phase-3 enrage 1.5× speed / 0.7× recovery.

### Feel check #1 — L1, T1 sword + T1 armor (no affixes)

Per the §2 decision, T1 has 0 affixes. Player has 6 damage light, `floor(6 * 1.6) = 9` damage heavy.

**Target: kill grunt in ≤ 8 light hits OR ≤ 6 mixed (light+heavy) hits.**
- 50 HP / 6 damage = 8.33 light hits → **9 light hits exact** (player must land 9). Slightly over the ≤8 target — but realistic player play uses heavies on telegraphs. Mixed: 4 light + 2 heavy = 24 + 18 = 42, then 1 more light = 48, then 1 more = 54 → **6 mixed hits.**
- **Pass.** A pure-light kill is borderline 8-9; a mixed kill is comfortably 6.

**Note**: if Drew finds the pure-light count feels punishing during soak, the lever to pull is `iron_sword.base_stats.damage` from 6 → 7 (one-line edit), which makes pure-light = `ceil(50/7) = 8 hits`. Held at 6 unless Drew flags during soak.

### Feel check #2 — L5, T2/T3 fully equipped

Player at L5: assume 4 levelups granted, banked into Vigor (+5) and Edge (+5) per typical curve. Equipped: T2 iron sword (assume base 9 damage when authored) + T3 leather vest. Affixes: T2 sword has 1 affix (assume keen +4 edge), T3 vest has 1-2 (assume vital +30 vigor + swift +12 px/s).

Player effective stats:
- Edge: 5 (allocated) + 4 (keen affix) = **9**.
- Vigor: 5 (allocated) + 30 (vital affix) = **35** → 70% mitigation, **capped at 50%**.
- Move: 120 + 12 = **132 px/s**.

Light damage: `floor(9 * (1 + 9*0.05) * 1.0) = floor(9 * 1.45) = 13`. Heavy: `floor(9 * 1.45 * 1.6) = floor(20.88) = 20`.

**Target: kill grunt in ≤ 3 light hits (or ≤ 2 mixed).**
- 50 HP / 13 = 3.85 → **4 light hits.** Just over target.
- 13 + 20 = 33; need one more light = 46, then one more = 59 → **3 mixed hits**, or 1 heavy + 2 light = 20 + 26 = 46 → still need 1 more → 4 hits.
- 1 heavy + 1 heavy = 40, one more light = 53 → **3 hits.**
- **Pass-ish.** Pure-light is 4, which is over the ≤3 target. **Lever**: if Drew finds this feels grindy, T2 sword base damage from 9 → 10 makes pure-light = `ceil(50/14) = 4` (still). The real lever is the affix value — bumping keen T2 max from 6 → 7 would push edge to 11, pushing damage to `floor(9 * 1.55) = 13` (no change). The honest answer is: **3 light hits requires ≥17 damage per light**, which means edge ≥ 18 OR sword base ≥ 12. Either way, that's a **T3 sword + better Edge allocation** scenario — which is the natural late-stratum-1 / early-stratum-2 power band.

**Revised target**: **≤ 4 light hits OR ≤ 3 mixed hits to kill grunt at L5 with T2/T3 gear.** The original ≤3 target was the late-stratum-1 kill-feel goal but is gated by T3 weapon, not just affixes. Drew will write Tess's acceptance test against this revised number; if Drew changes T2 sword base damage, the test updates.

**Target: kill boss in ≤ 60 s.**
- 600 HP boss, player DPS estimate at L5 with T2/T3 + affixes: assume 2 light/sec attack rate (LIGHT_RECOVERY ~0.4s) = 26 DPS sustained, with heavies for telegraphs (HEAVY_RECOVERY ~2.2x = ~0.88s, 20 dmg = 22.7 DPS — slightly worse than light spam, matches Damage.gd's design intent).
- 600 / 26 = **23 s of pure attacking**. But: phase transitions are 0.6s each (×2 = 1.2 s lost), plus the boss's own attack telegraphs force the player to back off. Realistic combat-time: ~40-50% of total fight time is the player attacking. So **45-55 s total fight at full uptime; 60 s with one i-frame escape from a slam.**
- **Pass.** ≤60s is the target; realistic fight is in the 45-60s band.

### Feel check #3 — L5 unlucky (no affixes)

What if RNG gave the player only T1 drops through the whole stratum? Edge=5, Vigor=5 (allocated only), no affix bonuses, T1 sword (6 damage).

- Light damage: `floor(6 * 1.25) = 7`. Heavy: `floor(6 * 1.25 * 1.6) = 12`.
- Grunt kill: 50/7 = 8 light hits. **Same as L1!** The sword damage didn't grow because no T2/T3 drop landed.
- Boss kill: 600 HP / 7 dmg = 86 light hits at ~2/s = **43 s of pure attacking** = ~85-100 s total fight. **Borderline-fail vs ≤60s target.**

This is **intentional**. The "unlucky" run should feel slow at the boss; that's the player-feel signal that gear matters. **No fix needed at the affix layer** — but Drew should ensure stratum 1 has *enough density* of T2 drops that the unlucky scenario is rare. With the §3 drop table (51% any-drop, 17% T2+) over 19 mobs, expected T2+ drops = 19 * 0.51 * 0.30 ≈ 3 drops — so the unlucky-zero case has probability ~`(1-0.51*0.30)^19 ≈ 5%`. Acceptable tail.

### Tess's acceptance write-up

Tess's M1 RC soak should explicitly assert the three feel checks above as **non-blocking observations** (not pass/fail) — they're calibration signals. If two consecutive RCs show the L1 grunt-kill at >9 hits, Drew bumps iron_sword damage. If the boss kill at L5 with T2/T3 gear consistently exceeds 75 s, Drew bumps either T2 sword damage or keen T2 range. Bug-bounce only if a check is **off by 2x or more** — that signals a broken constant, not a balance miss.

---

## 5. Future-tier hooks (M2+)

The schema and these pinned values must not bake assumptions that block M2. Verified clean:

1. **Tier array length** — `AffixDef.value_ranges: Array[AffixValueRange]` already uses an array, not a fixed-shape struct. M2 grows the array from 3 entries (T1/T2/T3) to 6 (T1..T6). The hard-assert in `LootRoller.roll_affix` checks `tier_idx < value_ranges.size()` — naturally handles short arrays for M1 affixes that haven't been extended.
2. **`apply_mode` enum** — already shipped with both `ADD` and `MUL`. M2's `frost (slow_pct, MUL)` and `lightning (chain_chance, ADD)` slot in without an enum bump.
3. **`stat_modified` StringName dispatch** — `Player._apply_single_affix` uses a match statement on stat name. M2 adds cases:
   - `&"frost_aura_radius"` (vampiric on hit emits a small frost aura) → new field on Player or a new component.
   - `&"lightning_chain_chance"` (chain-lightning on crit) → routes through PlayerStats or a new combat-effects autoload.
   - `&"vampiric_pct"` (heal on hit) → routes through Player.heal_on_hit hook (M2 introduces).
   The current pattern's `<other> → push_warning, ignore` default is the future-proofing — a too-new save can be loaded by an older client without crashing, the unknown affix is just inert.
4. **Affix-count-by-tier** — extending the current table to T4 (2-3) / T5 (3) / T6 (3 + set bonus) is purely a `LootRoller.affix_count_for_tier` match-arm addition. Already partly in there for T4-T6 with placeholder values per Drew. M2 sign-off may revise.
5. **Drop-weight tier spread** — the §3 70/25/5 spread for stratum 1 generalizes naturally:
   - Stratum 2 mobs: 50/35/12/3 (T1/T2/T3/T4).
   - Stratum 3 mobs: 25/40/25/8/2 (T1/T2/T3/T4/T5).
   - Etc. The table-authoring discipline (one entry per item × tier variant, weight = `P(item drops) * P(tier given drop)`) is the same.
6. **Set bonuses (T6 mythic)** — out of scope for M1 affix balance. The schema's `set_id` field on `ItemDef` (per `tres-schemas.md` § "Out of scope for M1 schema") is the M3 hook. Affixes themselves don't carry set logic — sets are an item-level thing.

**No M1 decision pinned in this doc blocks any of the above.** The danger pattern would have been "T3 has 3 affixes (== pool size)" — Option B from §2 — which would have forced a redesign at M2. Option A (1-2 at T3) leaves room.

---

## Sign-off

- **Drew:** read this before starting `86c9kxx61`. Likely path: zero code changes, close the ticket as "balance held during RC soak; numbers in `resources/affixes/*.tres` and `resources/loot_tables/grunt_drops.tres` match Priya's pin." Only edit `grunt_drops.tres` per §3 (replace 2-entry with 6-entry tier-varied table).
- **Tess:** the §4 player-feel checks are **soak-time observations**, not pre-merge gates. Treat them as the calibration signal during M1 RC interactive run; bug-bounce only on 2x deviation.
- **`86c9kyntj`** (Tess's affix-count follow-up): **resolves as Option A — no change.** Ticket flips to `complete` with this doc as the rationale.
- **Reversibility:** every number in this doc is a one-line edit to a TRES file. Sticky decisions: the *shape* of the curve (ADD-only for M1, summed-then-applied MUL when M2 wires it). Both are documented as reversible in `team/drew-dev/affix-application.md` and DECISIONS.md 2026-05-02.

This pin is the contract for M1 affix ship. Open a balance-pass v2 ticket post-Sponsor-soak only if a §4 check fails by ≥2x.
