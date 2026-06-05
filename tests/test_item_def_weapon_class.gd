extends GutTest
## Paired test — `ItemDef.WeaponClass` schema add (ticket 86ca56w4f, the
## visible-equipment foundation, spec `team/uma-ux/visible-equipment-system.md
## §2 / §7 step 1).
##
## Pins:
##   - The `WeaponClass` enum exists with the five M3-forward members.
##   - `@export var weapon_class` defaults to ONE_HAND_MELEE (back-compat:
##     existing weapon `.tres` files read as 1H with no edit).
##   - The shipped `iron_sword.tres` reads ONE_HAND_MELEE via the default
##     (it authors no `weapon_class` line — proves back-compat).
##   - FIST is the implicit class when no weapon is equipped (covered on the
##     Player side via `_resolve_attack_set`; here we pin the enum value).

const ItemDefScript: Script = preload("res://scripts/content/ItemDef.gd")
const IRON_SWORD_PATH: String = "res://resources/items/weapons/iron_sword.tres"

# ---- Enum shape -------------------------------------------------------


func test_weapon_class_enum_has_all_five_members() -> void:
	# The enum carries M3's two live classes (FIST, ONE_HAND_MELEE) plus the
	# three forward hooks (TWO_HAND_MELEE, STAFF, RANGED) so the rig
	# generalizes without a schema migration when those weapons ship.
	assert_eq(ItemDef.WeaponClass.FIST, 0, "FIST is enum member 0")
	assert_eq(ItemDef.WeaponClass.ONE_HAND_MELEE, 1, "ONE_HAND_MELEE is member 1")
	assert_eq(ItemDef.WeaponClass.TWO_HAND_MELEE, 2, "TWO_HAND_MELEE is member 2")
	assert_eq(ItemDef.WeaponClass.STAFF, 3, "STAFF is member 3")
	assert_eq(ItemDef.WeaponClass.RANGED, 4, "RANGED is member 4")


# ---- Default = ONE_HAND_MELEE (back-compat) ---------------------------


func test_weapon_class_defaults_to_one_hand_melee() -> void:
	# A bare ItemDef (no `weapon_class` authored) reads ONE_HAND_MELEE. This is
	# the back-compat contract: every pre-existing weapon `.tres` reads as 1H
	# without a `.tres` edit.
	var d: ItemDef = ItemDefScript.new()
	assert_eq(
		d.weapon_class,
		ItemDef.WeaponClass.ONE_HAND_MELEE,
		"weapon_class defaults to ONE_HAND_MELEE (back-compat)"
	)


func test_iron_sword_tres_reads_one_hand_melee_via_default() -> void:
	# The shipped iron_sword.tres authors NO `weapon_class` line (it predates
	# the field). Loading it must yield ONE_HAND_MELEE via the @export default
	# — proves the schema add is non-breaking for the live content.
	var iron: ItemDef = load(IRON_SWORD_PATH) as ItemDef
	assert_not_null(iron, "iron_sword.tres loads as ItemDef")
	assert_eq(
		iron.weapon_class,
		ItemDef.WeaponClass.ONE_HAND_MELEE,
		"iron_sword reads ONE_HAND_MELEE (default, no .tres edit needed)"
	)


# ---- Authored override survives a round-trip --------------------------


func test_weapon_class_override_is_settable() -> void:
	# A future weapon (the Warden two-hander) can author TWO_HAND_MELEE and it
	# survives — the field is a normal @export, not pinned to the default.
	var d: ItemDef = ItemDefScript.new()
	d.weapon_class = ItemDef.WeaponClass.TWO_HAND_MELEE
	assert_eq(
		d.weapon_class, ItemDef.WeaponClass.TWO_HAND_MELEE, "authored weapon_class override holds"
	)
