class_name Damage
extends RefCounted
## Damage formula utility — single source of truth for player<->mob damage
## math in M1. Pure-static API; no node, no autoload, no state. Callers
## (Player.gd attacks, mob attack hits) pass in everything they need to
## compute a final integer damage value.
##
## **Player damage formula:**
##
##     player_damage = floor(weapon_base * (1 + edge_bonus * EDGE_PER_POINT) * (1 + attack_type_mult))
##
##     - weapon_base: from equipped weapon's `ItemBaseStats.damage` (per Drew's
##       content schema). Falls back to FIST_DAMAGE (1) when weapon == null.
##     - edge_bonus: player's Edge stat from level-up allocation. Negative
##       values clamp to 0 (defensive — Edge is an allocation count, never
##       negative). Default 0 = unallocated.
##     - attack_type_mult: 0.0 for light attacks, 0.6 for heavy. Heavy is
##       1.6x light at the *final* damage step (multiplicative on the post-
##       edge value, not on weapon_base — so Edge bonus benefits heavy
##       proportionally).
##
## **Mob damage formula:**
##
##     mob_damage = floor(mob_base * (1 - clamp(vigor * VIGOR_PER_POINT, 0, VIGOR_CAP)))
##
##     - mob_base: from `MobDef.damage_base`. Null mob_def -> 0 damage
##       (defensive — a corpse without a def can't hurt the player).
##     - vigor: player's Vigor stat. Negative values clamp to 0.
##     - VIGOR_CAP = 0.5 — mitigation maxes at 50% so Vigor stacking never
##       reaches immortality. At VIGOR_PER_POINT = 0.02 per point, the cap
##       is reached at vigor = 25.
##
## **Affix system (future, ticket 86c9kxx5p):** when affixes land, they will
## modify the *weapon_base* input to compute_player_damage, not the formula
## itself. Per AffixDef.apply_mode:
##     - ADD: weapon_base += sum(rolled values where stat_modified == &"damage_flat")
##     - MUL: weapon_base *= product(1 + rolled values where stat_modified == &"damage_pct")
## Computed weapon_base is then handed to this utility unchanged. Damage.gd
## is *deliberately* affix-naive to keep the formula pinnable and testable.
##
## **Why these constants (Decision logged in DECISIONS.md 2026-05-02):**
##   - EDGE_PER_POINT = 0.05 (5% weapon damage per Edge point). At Edge=20
##     (4 levels at +5/level), weapon damage doubles. Caps the per-level
##     damage gain at a noticeable-but-not-broken value vs. flat +1 per
##     point (which would scale poorly across tiers — a +1 to a T1 dagger
##     is +33%; a +1 to a T3 sword is +5%).
##   - HEAVY_MULT = 0.6 (final damage 1.6x light) — typical ARPG ratio
##     (Diablo II two-handed, Hades special). Pairs with Player.HEAVY_RECOVERY
##     being 2.2x LIGHT_RECOVERY so DPS is still slightly favored toward
##     light attack chains, but heavies hit hard enough to matter.
##   - VIGOR_PER_POINT = 0.02 (2% mitigation per point). Vigor cap at L5
##     in M1 is realistically ~10-15; that's 20-30% mitigation — meaningful
##     but not trivializing. The 50% cap protects late-M2/M3 high-Vigor
##     builds from becoming undamageable as point pools grow past 25.
##
## **Why floor (not round):** consistent integer truncation matches the
## existing damage_base / hp_base int contract; round-half-up at boundary
## values would inflate apparent damage by 1. Tests assert floor semantics.

# ---- Constants (formula-load-bearing) ----------------------------------

## Edge bonus per point (multiplicative on weapon_base).
const EDGE_PER_POINT: float = 0.05

## Heavy attack final-damage multiplier — applied as `(1 + HEAVY_MULT)` on
## the post-edge weapon damage value. Light = 1.0x final; heavy = 1.6x final.
const HEAVY_MULT: float = 0.6
const LIGHT_MULT: float = 0.0

## Vigor mitigation per point (subtracts from the multiplier on incoming
## mob damage).
const VIGOR_PER_POINT: float = 0.02

## Mitigation cap — vigor cannot reduce incoming damage below this fraction
## of the original value. 0.5 = 50% damage taken at minimum.
const VIGOR_CAP: float = 0.5

## Fallback weapon damage when the player has no weapon equipped (bare
## fists). Flat int per spec — does not scale with Edge (Edge benefits
## "the swing"; a fist isn't a swing). Tests pin this.
const FIST_DAMAGE: int = 1

## Attack-type tags. Match Player.gd's ATTACK_LIGHT / ATTACK_HEAVY values.
const ATTACK_LIGHT: StringName = &"light"
const ATTACK_HEAVY: StringName = &"heavy"


# ---- Public API --------------------------------------------------------

## Compute the integer damage a player attack deals.
##
## - `weapon`: an `ItemDef` whose `base_stats.damage` is the weapon's base
##   damage. Null -> falls back to FIST_DAMAGE (1) flat with no scaling.
##   A weapon with null `base_stats` (degenerate authoring) also falls back.
## - `edge`: the player's allocated Edge stat. Negative values clamp to 0.
## - `attack_type`: ATTACK_LIGHT or ATTACK_HEAVY. Unknown tags treated as
##   light (defensive — wrong tag in a hot path shouldn't crash combat;
##   tests assert this).
##
## Returns a non-negative integer.
static func compute_player_damage(weapon: ItemDef, edge: int, attack_type: StringName) -> int:
	# Fist fallback: no weapon, no scaling, flat 1.
	if weapon == null:
		return FIST_DAMAGE
	# A weapon without base_stats (degenerate test/author state) also degrades
	# to fist. We don't crash — combat keeps working with rounded-down output.
	var base_stats: ItemBaseStats = weapon.base_stats
	if base_stats == null:
		return FIST_DAMAGE
	var weapon_base: int = max(0, int(base_stats.damage))
	# Defensive clamp: edge is an allocation count, never negative.
	var clean_edge: int = max(0, edge)

	var attack_mult: float = LIGHT_MULT
	if attack_type == ATTACK_HEAVY:
		attack_mult = HEAVY_MULT
	# Unknown tags fall through as light. Tests pin this.

	var raw: float = float(weapon_base) * (1.0 + float(clean_edge) * EDGE_PER_POINT) * (1.0 + attack_mult)
	# Floor — consistent with damage_base / hp_base int contract.
	return int(floor(raw))


## Compute the integer damage a mob attack deals to the player.
##
## - `mob_def`: the mob's `MobDef`. Null -> 0 damage (defensive: a mob
##   without a def can't hurt the player; this happens in tests where a
##   bare-instantiated mob has its mob_def left null on purpose).
## - `vigor`: the player's allocated Vigor stat. Negative values clamp to 0.
##
## Returns a non-negative integer. Mitigation is capped at VIGOR_CAP (50%).
static func compute_mob_damage(mob_def: MobDef, vigor: int) -> int:
	if mob_def == null:
		return 0
	# Defensive: damage_base is exported as range(0, 999) so it shouldn't be
	# negative, but clamp anyway.
	var mob_base: int = max(0, int(mob_def.damage_base))
	var clean_vigor: int = max(0, vigor)

	var reduction: float = clamp(float(clean_vigor) * VIGOR_PER_POINT, 0.0, VIGOR_CAP)
	var raw: float = float(mob_base) * (1.0 - reduction)
	return int(floor(raw))
