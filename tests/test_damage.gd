extends GutTest
## Tests for `scripts/combat/Damage.gd` — the damage formula utility used
## by Player attacks and mob attack hits.
##
## Coverage per testing bar (`team/TESTING_BAR.md` §Devon-and-Drew):
##   1. Player damage at edge=0 vs edge=20 — formula matches the spec.
##   2. Light vs heavy attack-type multiplier (0 vs 0.6).
##   3. Mob damage at vigor=0 / 10 / 50 — cap at 50% mitigation works.
##   4. Edge: weapon=null falls back to fist (1 damage flat).
##   5. Edge: mob_def=null returns 0 damage.
##   6. Edge: negative vigor / negative edge clamped to 0.
##   7. Integration: T1 sword (3 damage) at edge=0 — light=3, heavy=4 (floor).
##   8. Integration: heavy still benefits from Edge proportionally.
##   9. Determinism: same inputs always return the same int (no RNG).
##  10. Affix-readiness: a future affix-modified weapon plugs in unchanged.
##
## Why these are paired with `feat(combat) damage formula`:
##   - The formula is a balance lever. A silent change to EDGE_PER_POINT,
##     HEAVY_MULT, VIGOR_PER_POINT, or VIGOR_CAP must trip a red test, not
##     leak into a player-facing balance regression.
##   - Drew's mob `damage_base` values and Devon's level-up curve both lean
##     on this formula; a regression here breaks AC4 (boss DPS budget) and
##     AC7 (combat balance against a level-4-5 character).

const DamageScript: Script = preload("res://scripts/combat/Damage.gd")
const ItemDefScript: Script = preload("res://scripts/content/ItemDef.gd")
const ItemBaseStatsScript: Script = preload("res://scripts/content/ItemBaseStats.gd")
const MobDefScript: Script = preload("res://scripts/content/MobDef.gd")


# ---- Helpers ------------------------------------------------------------

func _make_weapon(damage: int) -> ItemDef:
	# Build a minimal ItemDef with the requested base damage. We don't go
	# through ContentFactory because the factory's default damage is 5 and
	# we want explicit numbers per test.
	var stats: ItemBaseStats = ItemBaseStatsScript.new()
	stats.damage = damage
	var item: ItemDef = ItemDefScript.new()
	item.id = StringName("test_weapon_%d" % damage)
	item.display_name = "Test Weapon (%d dmg)" % damage
	item.slot = ItemDef.Slot.WEAPON
	item.tier = ItemDef.Tier.T1
	item.base_stats = stats
	return item


func _make_mob_def(damage_base: int) -> MobDef:
	var m: MobDef = MobDefScript.new()
	m.id = StringName("test_mob_%d" % damage_base)
	m.display_name = "Test Mob"
	m.hp_base = 100
	m.damage_base = damage_base
	m.move_speed = 60.0
	return m


# ---- 1: edge=0 vs edge=20 (4 levels of allocation) --------------------

func test_player_damage_edge_zero_vs_twenty() -> void:
	var w: ItemDef = _make_weapon(10)
	# edge=0, light: 10 * (1 + 0) * (1 + 0) = 10
	assert_eq(DamageScript.compute_player_damage(w, 0, Damage.ATTACK_LIGHT), 10,
		"weapon=10, edge=0, light -> 10")
	# edge=20, light: 10 * (1 + 20*0.05) * 1 = 10 * 2 = 20
	assert_eq(DamageScript.compute_player_damage(w, 20, Damage.ATTACK_LIGHT), 20,
		"weapon=10, edge=20, light -> 20 (Edge doubles weapon at 20 pts)")
	# edge=20, heavy: 10 * 2 * 1.6 = 32
	assert_eq(DamageScript.compute_player_damage(w, 20, Damage.ATTACK_HEAVY), 32,
		"weapon=10, edge=20, heavy -> 32 (1.6x of edge-doubled value)")


# ---- 2: light vs heavy multiplier -------------------------------------

func test_light_vs_heavy_multiplier() -> void:
	var w: ItemDef = _make_weapon(10)
	# Light multiplier is 0.0 (final = 1.0x); heavy is 0.6 (final = 1.6x).
	# Pin the spec values via the formula constants so a silent change trips.
	assert_almost_eq(Damage.LIGHT_MULT, 0.0, 0.0001, "light multiplier is 0.0")
	assert_almost_eq(Damage.HEAVY_MULT, 0.6, 0.0001, "heavy multiplier is 0.6 (1.6x final)")
	# Numeric: weapon=10, edge=0 -> light=10, heavy=floor(10*1.6)=16.
	assert_eq(DamageScript.compute_player_damage(w, 0, Damage.ATTACK_LIGHT), 10)
	assert_eq(DamageScript.compute_player_damage(w, 0, Damage.ATTACK_HEAVY), 16)


# ---- 3: mob damage at vigor=0/10/50, 50% cap --------------------------

func test_mob_damage_vigor_zero_ten_fifty() -> void:
	var m: MobDef = _make_mob_def(10)
	# vigor=0: 10 * (1 - 0) = 10
	assert_eq(DamageScript.compute_mob_damage(m, 0), 10, "vigor=0 -> no mitigation")
	# vigor=10: 10 * (1 - 10*0.02) = 10 * 0.8 = 8
	assert_eq(DamageScript.compute_mob_damage(m, 10), 8, "vigor=10 -> 20% mitigation")
	# vigor=25: 10 * (1 - 0.5) = 5  (cap reached at 25)
	assert_eq(DamageScript.compute_mob_damage(m, 25), 5, "vigor=25 -> cap reached, 50% mitigation")
	# vigor=50: still capped — must not be 0 (no immortality)
	assert_eq(DamageScript.compute_mob_damage(m, 50), 5,
		"vigor=50 -> stays at 50% mitigation cap (no immortality)")
	# vigor=99: also capped
	assert_eq(DamageScript.compute_mob_damage(m, 99), 5,
		"vigor=99 -> stays at 50% mitigation cap")


func test_vigor_cap_pinned_at_fifty_percent() -> void:
	# Pin VIGOR_CAP to 0.5 so a silent change to undamageable territory trips.
	assert_almost_eq(Damage.VIGOR_CAP, 0.5, 0.0001, "vigor cap is 50%")
	assert_almost_eq(Damage.VIGOR_PER_POINT, 0.02, 0.0001, "vigor per point is 2%")


# ---- 4: weapon=null falls back to fist --------------------------------

func test_null_weapon_falls_back_to_fist() -> void:
	# null weapon — light, heavy, any edge — must always be FIST_DAMAGE.
	assert_eq(DamageScript.compute_player_damage(null, 0, Damage.ATTACK_LIGHT),
		Damage.FIST_DAMAGE, "null weapon -> fist (1) flat")
	assert_eq(DamageScript.compute_player_damage(null, 99, Damage.ATTACK_HEAVY),
		Damage.FIST_DAMAGE, "fist doesn't scale with edge or attack type")
	assert_eq(Damage.FIST_DAMAGE, 1, "fist damage is 1 (pinned)")


func test_weapon_with_null_base_stats_falls_back_to_fist() -> void:
	# Degenerate authoring (item that forgot its base_stats). Should not crash;
	# falls back to fist.
	var w: ItemDef = ItemDefScript.new()
	w.id = &"broken"
	w.base_stats = null
	assert_eq(DamageScript.compute_player_damage(w, 10, Damage.ATTACK_LIGHT),
		Damage.FIST_DAMAGE, "weapon with null base_stats -> fist (defensive)")


# ---- 5: mob_def=null returns 0 ----------------------------------------

func test_null_mob_def_returns_zero() -> void:
	# A mob attack with no def can't hurt the player. Defensive: tests sometimes
	# pass null on a bare-instantiated mob.
	assert_eq(DamageScript.compute_mob_damage(null, 0), 0, "null def -> 0 damage")
	assert_eq(DamageScript.compute_mob_damage(null, 99), 0, "null def stays 0 even with vigor")


# ---- 6: negative vigor / edge clamped ---------------------------------

func test_negative_vigor_clamped_to_zero() -> void:
	var m: MobDef = _make_mob_def(10)
	# Negative vigor doesn't *amplify* damage — it clamps to 0 (no mitigation).
	assert_eq(DamageScript.compute_mob_damage(m, -5), 10,
		"negative vigor -> clamped to 0, full damage taken")
	assert_eq(DamageScript.compute_mob_damage(m, -100), 10)


func test_negative_edge_clamped_to_zero() -> void:
	var w: ItemDef = _make_weapon(10)
	# Negative edge -> no bonus (clamps to 0).
	assert_eq(DamageScript.compute_player_damage(w, -5, Damage.ATTACK_LIGHT), 10,
		"negative edge -> clamped to 0, base damage only")
	assert_eq(DamageScript.compute_player_damage(w, -1000, Damage.ATTACK_HEAVY), 16,
		"negative edge with heavy -> still 1.6x base")


# ---- 7 + 8: integration with T1 sword ---------------------------------

func test_integration_t1_sword_3_damage() -> void:
	# Per task spec: T1 sword (3 damage) at edge=0 with light = 3.
	# With heavy at edge=0 = floor(3 * 1.6) = floor(4.8) = 4.
	var sword: ItemDef = _make_weapon(3)
	assert_eq(DamageScript.compute_player_damage(sword, 0, Damage.ATTACK_LIGHT), 3,
		"T1 sword 3 dmg, edge=0, light -> 3")
	assert_eq(DamageScript.compute_player_damage(sword, 0, Damage.ATTACK_HEAVY), 4,
		"T1 sword 3 dmg, edge=0, heavy -> floor(3 * 1.6) = 4")


func test_integration_t1_sword_with_edge() -> void:
	var sword: ItemDef = _make_weapon(3)
	# edge=10: 3 * (1 + 10*0.05) = 3 * 1.5 = 4.5 -> floor 4 (light).
	assert_eq(DamageScript.compute_player_damage(sword, 10, Damage.ATTACK_LIGHT), 4,
		"T1 sword 3 dmg, edge=10, light -> floor(4.5) = 4")
	# heavy: 3 * 1.5 * 1.6 = 7.2 -> floor 7.
	assert_eq(DamageScript.compute_player_damage(sword, 10, Damage.ATTACK_HEAVY), 7,
		"T1 sword 3 dmg, edge=10, heavy -> floor(7.2) = 7")


# ---- 9: determinism (no RNG) ------------------------------------------

func test_compute_player_damage_is_deterministic() -> void:
	var w: ItemDef = _make_weapon(7)
	var first: int = DamageScript.compute_player_damage(w, 12, Damage.ATTACK_HEAVY)
	for i in 100:
		var got: int = DamageScript.compute_player_damage(w, 12, Damage.ATTACK_HEAVY)
		assert_eq(got, first, "Damage formula is pure — same inputs always same output")


func test_compute_mob_damage_is_deterministic() -> void:
	var m: MobDef = _make_mob_def(13)
	var first: int = DamageScript.compute_mob_damage(m, 7)
	for i in 100:
		var got: int = DamageScript.compute_mob_damage(m, 7)
		assert_eq(got, first, "Damage formula is pure — same inputs always same output")


# ---- 10: floor semantics (not round) ----------------------------------

func test_floor_not_round_on_player_damage() -> void:
	var w: ItemDef = _make_weapon(5)
	# edge=3: 5 * (1 + 0.15) = 5.75. floor=5, NOT round=6. This pins the
	# truncation choice so half-up rounding doesn't silently inflate damage.
	assert_eq(DamageScript.compute_player_damage(w, 3, Damage.ATTACK_LIGHT), 5,
		"floor(5.75) = 5; round-half-up would be 6 (rejected)")


func test_floor_not_round_on_mob_damage() -> void:
	var m: MobDef = _make_mob_def(7)
	# vigor=3: 7 * (1 - 0.06) = 7 * 0.94 = 6.58. floor=6, NOT round=7.
	assert_eq(DamageScript.compute_mob_damage(m, 3), 6,
		"floor(6.58) = 6; round would be 7 (rejected)")


# ---- 11: unknown attack-type tag falls through as light ---------------

func test_unknown_attack_type_treated_as_light() -> void:
	var w: ItemDef = _make_weapon(10)
	# A typo'd or unexpected tag must NOT crash the hot combat path.
	# Defensive default = light multiplier (0.0).
	var got: int = DamageScript.compute_player_damage(w, 0, &"poke")
	assert_eq(got, 10, "unknown attack-type -> light multiplier (no crash, no inflation)")


# ---- 12: zero-damage weapon (degenerate) ------------------------------

func test_zero_damage_weapon() -> void:
	var w: ItemDef = _make_weapon(0)
	assert_eq(DamageScript.compute_player_damage(w, 0, Damage.ATTACK_LIGHT), 0,
		"weapon damage 0 stays 0 — Edge doesn't conjure damage from nothing")
	assert_eq(DamageScript.compute_player_damage(w, 100, Damage.ATTACK_HEAVY), 0,
		"100 edge on a 0-damage weapon is still 0 (multiplicative)")


# ---- 13: zero-damage mob (peaceful?) ----------------------------------

func test_zero_damage_mob() -> void:
	var m: MobDef = _make_mob_def(0)
	assert_eq(DamageScript.compute_mob_damage(m, 0), 0, "0-damage mob with 0 vigor -> 0")
	assert_eq(DamageScript.compute_mob_damage(m, 50), 0, "0-damage mob with high vigor -> 0")


# ---- 14: edge constant pinned -----------------------------------------

func test_edge_per_point_constant() -> void:
	# Pin EDGE_PER_POINT so a silent change to combat balance trips this test.
	assert_almost_eq(Damage.EDGE_PER_POINT, 0.05, 0.0001, "Edge per point is 5%")


# ---- 15: affix-readiness (forward-looking sanity) ---------------------

func test_compute_player_damage_accepts_modified_weapon_base() -> void:
	# When the affix system lands (ticket 86c9kxx5p), affixes will mutate
	# the weapon's base_stats.damage value before the formula runs. Verify
	# that path: caller mutates ItemBaseStats.damage, formula picks it up.
	# This test pins the contract so future affix code can rely on it.
	var w: ItemDef = _make_weapon(5)
	var base_dmg: int = DamageScript.compute_player_damage(w, 0, Damage.ATTACK_LIGHT)
	assert_eq(base_dmg, 5)
	# Simulate an affix that adds +3 flat damage (ApplyMode.ADD).
	w.base_stats.damage = 5 + 3
	var with_affix: int = DamageScript.compute_player_damage(w, 0, Damage.ATTACK_LIGHT)
	assert_eq(with_affix, 8, "affix-modified weapon_base flows through unchanged")
