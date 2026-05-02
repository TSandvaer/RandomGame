class_name LootRoller
extends RefCounted
## Rolls 0..N `ItemInstance`s from a `LootTableDef`, applying tier modifiers
## and affix value ranges with deterministic RNG.
##
## See `team/drew-dev/tres-schemas.md` for the schema contract; this is
## the reference implementation.
##
## Algorithm summary:
##   - Independent-roll mode (`LootTableDef.roll_count == -1`): every entry
##     gets one roll. `entry.weight` is treated as a 0..1 drop chance
##     (clamped). One mob can drop 0..N items.
##   - Weighted-pick mode (`roll_count >= 0`): pick exactly N entries from
##     the table by relative `weight`. Entries with weight == 0 are never
##     picked. If all weights are zero, returns []. N may exceed
##     entries.size(); picks happen with replacement.
##
## Affix rolls: `tier_count_for_tier(rolled_tier)` affixes are picked from
## the item's `affix_pool` without duplicates. Each rolled value is
## `lerp(value_ranges[tier_index].min, .max, rng.randf())`.
##
## Determinism: `seed_rng(seed: int)` resets the RNG so two rolls with the
## same seed produce identical results. Used by tests and by the debug
## "stable mob spawn seed" hook (Tess's M1 test plan).

# ---- RNG -------------------------------------------------------------

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


## Reset RNG to a known seed. Two rollers seeded identically produce
## identical roll sequences.
func seed_rng(seed: int) -> void:
	_rng.seed = seed
	# Reset state so the first .randf() after seeding is deterministic.
	_rng.state = 0


# ---- Tier helpers ----------------------------------------------------

const TIER_MIN_INDEX: int = 0
const TIER_MAX_INDEX: int = 5  # T6 is index 5 (T1..T6)

## Affix count by tier (single tunable point per `team/drew-dev/tres-schemas.md`).
##   T1: 0 affixes (worn)
##   T2: 1 (common)
##   T3: roll 1 or 2 (fine) — uses RNG
##   T4: roll 2 or 3 (rare, M2)
##   T5: 3 (heroic, M2)
##   T6: 3 (mythic — set bonus is M3 schema add)
func affix_count_for_tier(tier: int) -> int:
	match tier:
		ItemDef.Tier.T1:
			return 0
		ItemDef.Tier.T2:
			return 1
		ItemDef.Tier.T3:
			return 1 + _rng.randi_range(0, 1)  # 1 or 2
		ItemDef.Tier.T4:
			return 2 + _rng.randi_range(0, 1)  # 2 or 3
		ItemDef.Tier.T5:
			return 3
		ItemDef.Tier.T6:
			return 3
		_:
			return 0


## Clamp a tier index into the legal Tier range. Used to apply
## `LootEntry.tier_modifier` safely.
static func clamp_tier(tier: int) -> int:
	return clampi(tier, TIER_MIN_INDEX, TIER_MAX_INDEX)


# ---- Roll a whole table ----------------------------------------------

## Returns an array of `ItemInstance`s rolled from `table`. Empty array
## means "no drops this kill", never null.
func roll(table: LootTableDef) -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	if table == null or table.entries.is_empty():
		return out
	if table.roll_count == -1:
		_roll_independent(table, out)
	else:
		_roll_weighted_pick(table, out)
	return out


# ---- Roll a single affix on an item ---------------------------------

## Roll one `AffixRoll` from `affix_def` at `tier`. Tier index resolves
## directly into `affix_def.value_ranges[i]`.
##
## Hard-asserts on shape errors (per testing bar §"value_ranges shorter
## than tier index"): a silent zero roll would mask content bugs that
## ship to players.
func roll_affix(affix_def: AffixDef, tier: int) -> AffixRoll:
	assert(affix_def != null, "LootRoller.roll_affix: affix_def is null")
	var tier_idx: int = clamp_tier(tier)
	assert(
		tier_idx < affix_def.value_ranges.size(),
		"LootRoller.roll_affix: affix '%s' has %d value_ranges but tier index %d requested" % [
			affix_def.id, affix_def.value_ranges.size(), tier_idx
		]
	)
	var rng_range: AffixValueRange = affix_def.value_ranges[tier_idx]
	var v: float = lerp(rng_range.min_value, rng_range.max_value, _rng.randf())
	return AffixRoll.new(affix_def, v)


# ---- Roll affixes for a whole item ----------------------------------

## Picks `affix_count_for_tier(tier)` affixes from `pool` without
## duplicates and rolls each. Returns an empty array if the pool is empty
## or if zero affixes are needed (T1).
func roll_affixes_for_item(pool: Array[AffixDef], tier: int) -> Array[AffixRoll]:
	var rolls: Array[AffixRoll] = []
	var want: int = affix_count_for_tier(tier)
	if want <= 0 or pool.is_empty():
		return rolls
	# Cap by pool size (we can't pick more than available).
	want = min(want, pool.size())
	# Random sample without replacement.
	var indices: Array[int] = []
	for i in pool.size():
		indices.append(i)
	# Fisher-Yates shuffle, take first `want`.
	for i in range(indices.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: int = indices[i]
		indices[i] = indices[j]
		indices[j] = tmp
	for k in want:
		var def: AffixDef = pool[indices[k]]
		rolls.append(roll_affix(def, tier))
	return rolls


# ---- Independent roll mode ------------------------------------------

func _roll_independent(table: LootTableDef, out: Array[ItemInstance]) -> void:
	for entry: LootEntry in table.entries:
		if entry == null or entry.item_def == null:
			continue
		# weight is interpreted as 0..1 drop chance, clamped.
		var chance: float = clampf(entry.weight, 0.0, 1.0)
		if chance <= 0.0:
			continue
		if _rng.randf() <= chance:
			out.append(_make_instance(entry))


# ---- Weighted pick mode ---------------------------------------------

func _roll_weighted_pick(table: LootTableDef, out: Array[ItemInstance]) -> void:
	var total_weight: float = 0.0
	for entry: LootEntry in table.entries:
		if entry == null or entry.item_def == null:
			continue
		total_weight += max(0.0, entry.weight)
	if total_weight <= 0.0:
		push_warning("LootRoller: weighted-pick table has no positive-weight entries — returning []")
		return
	var n: int = max(0, table.roll_count)
	for _i in n:
		var pick: float = _rng.randf() * total_weight
		var acc: float = 0.0
		for entry: LootEntry in table.entries:
			if entry == null or entry.item_def == null:
				continue
			var w: float = max(0.0, entry.weight)
			acc += w
			if pick <= acc:
				out.append(_make_instance(entry))
				break


# ---- Build an ItemInstance from a LootEntry -------------------------

func _make_instance(entry: LootEntry) -> ItemInstance:
	var rolled_tier_int: int = clamp_tier(int(entry.item_def.tier) + entry.tier_modifier)
	var instance: ItemInstance = ItemInstance.new(entry.item_def, rolled_tier_int)
	instance.rolled_affixes = roll_affixes_for_item(entry.item_def.affix_pool, rolled_tier_int)
	return instance
