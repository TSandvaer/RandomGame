extends GutTest
## Paired tests for fix(onboarding): iron_sword starting inventory seed
## (ClickUp 86c9pm8da, Devon run-019).
##
## **What this guards:**
##   (a) Inventory._seed_starting_inventory seeds exactly one iron_sword on a
##       fresh game-start (both _items and _equipped empty at _ready time).
##   (b) The only-if-empty rule: a non-empty inventory/equipped state is NOT
##       re-seeded — save-compat contract.
##   (c) The iron_sword.tres resource loads cleanly and resolves via
##       ContentRegistry — no repeat of the BB-2 unknown-id bug.
##   (d) Player._ready() calls Inventory.equip_starter_weapon_if_needed()
##       which routes through equip() so the weapon slot is filled, and
##       Player.equip_item() is wired (equipped_weapon != null).
##   (e) Damage.compute_player_damage() with the equipped iron_sword returns
##       weapon-scaled damage, NOT FIST_DAMAGE (1).
##   (f) Regression guard: no existing inventory, equip, or save tests broken
##       (verified by reset() before each test — the seeding is idempotent
##       when inventory is non-empty, so the _ready path doesn't re-trigger).
##
## **Note on test isolation:** Inventory._seed_starting_inventory() runs only
## in _ready() (autoload init). In the GUT test process the autoload is
## already ready before any test file runs. We therefore test the seeding
## logic by calling the private method via a test-mode helper OR by resetting
## and re-invoking the seed method directly. We expose the seed helper as a
## thin public wrapper below rather than prod-code public API.

const DamageScript: Script = preload("res://scripts/combat/Damage.gd")


# ---- Autoload accessors -------------------------------------------------

func _inv() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("Inventory")
	assert_not_null(n, "Inventory autoload must be registered in project.godot")
	return n


# ---- Helpers ------------------------------------------------------------

func _reset_and_reseed() -> void:
	# Simulate fresh game-start: wipe everything then re-invoke the seed path.
	_inv().reset()
	_inv().call("_seed_starting_inventory")


func _make_weapon_instance(damage_override: int = 5) -> ItemInstance:
	# Build a minimal weapon ItemInstance for pre-populating inventory in
	# save-compat tests — uses ContentFactory so the ItemDef has a valid slot.
	var def: ItemDef = ContentFactory.make_item_def({
		"id": &"test_sword_pre_existing",
		"slot": ItemDef.Slot.WEAPON,
		"base_stats": ContentFactory.make_item_base_stats({"damage": damage_override}),
	})
	return ItemInstance.new(def, ItemDef.Tier.T1)


# ==========================================================================
# AC (a) — fresh game-start seeds exactly one iron_sword
# ==========================================================================

func test_fresh_start_seeds_exactly_one_iron_sword() -> void:
	_reset_and_reseed()
	var items: Array = _inv().get_items()
	assert_eq(items.size(), 1, "exactly one item seeded on fresh start")
	var inst: ItemInstance = items[0] as ItemInstance
	assert_not_null(inst, "seeded item is an ItemInstance")
	assert_not_null(inst.def, "seeded ItemInstance has a non-null def")
	assert_eq(inst.def.id, &"iron_sword", "seeded item id is iron_sword")


func test_fresh_start_iron_sword_is_t1() -> void:
	_reset_and_reseed()
	var items: Array = _inv().get_items()
	assert_eq(items.size(), 1, "precondition: one item seeded")
	var inst: ItemInstance = items[0] as ItemInstance
	assert_eq(int(inst.rolled_tier), int(ItemDef.Tier.T1),
		"starting iron_sword is T1")


func test_fresh_start_iron_sword_has_nonzero_damage() -> void:
	_reset_and_reseed()
	var items: Array = _inv().get_items()
	assert_eq(items.size(), 1)
	var inst: ItemInstance = items[0] as ItemInstance
	assert_not_null(inst.def.base_stats, "iron_sword has base_stats")
	assert_gt(inst.def.base_stats.damage, 0, "iron_sword base damage > 0 (not fist)")


# ==========================================================================
# AC (b) — only-if-empty rule (save-compat)
# ==========================================================================

func test_nonempty_inventory_is_not_reseeded() -> void:
	# Pre-populate inventory with a different weapon then re-invoke seed.
	_inv().reset()
	var pre: ItemInstance = _make_weapon_instance()
	_inv().add(pre)
	assert_eq(_inv().get_items().size(), 1, "one pre-existing item")
	_inv().call("_seed_starting_inventory")
	# Inventory must still have exactly 1 item — no iron_sword injected.
	assert_eq(_inv().get_items().size(), 1,
		"seed must not add to a non-empty inventory")
	# The item must still be the pre-existing one.
	assert_eq((_inv().get_items()[0] as ItemInstance).def.id, &"test_sword_pre_existing",
		"pre-existing item preserved, iron_sword NOT injected")


func test_nonempty_equipped_is_not_reseeded() -> void:
	# Pre-equip a weapon (equipped map non-empty) then invoke seed.
	_inv().reset()
	var pre: ItemInstance = _make_weapon_instance()
	_inv().add(pre)
	_inv().equip(pre, &"weapon")
	assert_eq(_inv().get_items().size(), 0, "precondition: inventory grid empty after equip")
	_inv().call("_seed_starting_inventory")
	# Inventory must still be empty — no iron_sword seeded because equipped != empty.
	assert_eq(_inv().get_items().size(), 0,
		"seed must not fire when equipped map is non-empty")


func test_double_seed_is_idempotent() -> void:
	_inv().reset()
	_inv().call("_seed_starting_inventory")
	assert_eq(_inv().get_items().size(), 1, "first seed: 1 item")
	# Second seed on same (now non-empty) inventory must not add another.
	_inv().call("_seed_starting_inventory")
	assert_eq(_inv().get_items().size(), 1,
		"second seed call with non-empty inventory is a no-op")


# ==========================================================================
# AC (c) — iron_sword.tres resolves via ContentRegistry (BB-2 guard)
# ==========================================================================

func test_iron_sword_tres_resolves_via_content_registry() -> void:
	var reg: ContentRegistry = ContentRegistry.new()
	reg.load_all()
	var def: ItemDef = reg.resolve_item(&"iron_sword")
	assert_not_null(def,
		"ContentRegistry must resolve iron_sword — null means BB-2 repeat (unknown-id bug)")
	assert_eq(def.id, &"iron_sword", "resolved id matches")
	assert_eq(int(def.slot), int(ItemDef.Slot.WEAPON), "iron_sword slot is WEAPON")
	assert_gt(def.base_stats.damage if def.base_stats != null else 0, 0,
		"resolved iron_sword has base damage > 0")


func test_iron_sword_tres_loads_directly() -> void:
	var def: ItemDef = load("res://resources/items/weapons/iron_sword.tres") as ItemDef
	assert_not_null(def, "iron_sword.tres loads as ItemDef")
	assert_eq(def.id, &"iron_sword")
	assert_not_null(def.base_stats, "iron_sword has base_stats sub-resource")
	assert_eq(int(def.slot), int(ItemDef.Slot.WEAPON))
	assert_eq(int(def.tier), int(ItemDef.Tier.T1))


# ==========================================================================
# AC (d) — equip_starter_weapon_if_needed wires the weapon slot
# ==========================================================================

func test_equip_starter_sets_weapon_slot() -> void:
	_reset_and_reseed()
	# Verify Inventory's side of the equip contract: after equip_starter,
	# Inventory.get_equipped("weapon") returns the iron_sword instance.
	# We use a real Player node (not a stub) so _apply_equip_to_player can call
	# Player.equip_item and wire Player._equipped_weapon correctly.
	# A stub Node (non-Player) was used in the original PR #145 test — but
	# because stub.has_method("equip_item") is false, _apply_equip_to_player
	# silently fell back to set_equipped_weapon which is also absent on a stub,
	# meaning Player._equipped_weapon was NEVER set. The test passed on
	# Inventory state alone; the player-side surface was untested. This is the
	# product-vs-component miss class (memory: product-vs-component-completeness).
	# Use a real Player so equip_item wires through.
	var PlayerScript: Script = preload("res://scripts/player/Player.gd")
	var player: Player = PlayerScript.new()
	add_child_autofree(player)
	# Player._ready runs, adds to "player" group. Now equip_starter can find it.
	_inv().call("equip_starter_weapon_if_needed")
	var equipped: ItemInstance = _inv().get_equipped(&"weapon") as ItemInstance
	assert_not_null(equipped, "weapon slot must be filled after equip_starter")
	assert_eq(equipped.def.id, &"iron_sword", "equipped item is the iron_sword")
	# Also assert the Player-side surface: Player._equipped_weapon must be set.
	var weapon_on_player: ItemDef = player.get_equipped_weapon() as ItemDef
	assert_not_null(weapon_on_player,
		"Player.get_equipped_weapon() must be non-null — stub-Node gap (PR #145 miss): " +
		"Inventory._apply_equip_to_player calls equip_item; if player is a stub Node " +
		"equip_item is absent and Player._equipped_weapon stays null (silent miss)")
	assert_eq(weapon_on_player.id, &"iron_sword",
		"Player._equipped_weapon must be the iron_sword")


func test_equip_starter_noop_when_weapon_already_equipped() -> void:
	_inv().reset()
	# Manually add and equip a different weapon first. Use a real Player node
	# so the equip path (equip_item) actually wires Player._equipped_weapon.
	var other: ItemInstance = _make_weapon_instance(10)
	_inv().add(other)
	var PlayerScript: Script = preload("res://scripts/player/Player.gd")
	var player: Player = PlayerScript.new()
	add_child_autofree(player)
	_inv().equip(other, &"weapon")
	# Now seed and re-invoke equip_starter.
	_inv().call("_seed_starting_inventory")  # will no-op (equipped non-empty)
	_inv().call("equip_starter_weapon_if_needed")
	# The pre-existing weapon must still be equipped.
	var equipped: ItemInstance = _inv().get_equipped(&"weapon") as ItemInstance
	assert_not_null(equipped)
	assert_eq(equipped.def.id, &"test_sword_pre_existing",
		"pre-existing equipped weapon must not be replaced by starter equip")


# ==========================================================================
# AC (e) — Damage.compute_player_damage with equipped iron_sword != FIST_DAMAGE
# ==========================================================================

func test_equipped_iron_sword_damage_exceeds_fist_damage() -> void:
	# Load the iron_sword def and verify the Damage formula returns > 1.
	var def: ItemDef = load("res://resources/items/weapons/iron_sword.tres") as ItemDef
	assert_not_null(def)
	# At edge=0, damage = floor(weapon_base * 1.0 * 1.0) = weapon_base.
	var light_dmg: int = DamageScript.compute_player_damage(def, 0, &"light")
	assert_gt(light_dmg, DamageScript.FIST_DAMAGE,
		"iron_sword light attack damage (%d) must be > FIST_DAMAGE (%d)" % [light_dmg, DamageScript.FIST_DAMAGE])


func test_iron_sword_light_damage_equals_base_stats_damage() -> void:
	var def: ItemDef = load("res://resources/items/weapons/iron_sword.tres") as ItemDef
	assert_not_null(def)
	assert_not_null(def.base_stats)
	var expected: int = def.base_stats.damage  # floor(base * 1.0 * (1+0.0)) = base
	var light_dmg: int = DamageScript.compute_player_damage(def, 0, &"light")
	assert_eq(light_dmg, expected,
		"light attack at edge=0 == weapon_base (%d)" % expected)


func test_iron_sword_heavy_damage_is_160pct_of_light() -> void:
	var def: ItemDef = load("res://resources/items/weapons/iron_sword.tres") as ItemDef
	assert_not_null(def)
	assert_not_null(def.base_stats)
	var base: int = def.base_stats.damage
	var light_dmg: int = DamageScript.compute_player_damage(def, 0, &"light")
	var heavy_dmg: int = DamageScript.compute_player_damage(def, 0, &"heavy")
	# heavy = floor(base * 1.6); light = base. Heavy must be > light.
	assert_gt(heavy_dmg, light_dmg,
		"heavy attack (%d) must exceed light attack (%d) for iron_sword" % [heavy_dmg, light_dmg])
	# Concrete: floor(6 * 1.6) = 9 for the authored damage=6 value.
	var expected_heavy: int = int(floor(float(base) * (1.0 + DamageScript.HEAVY_MULT)))
	assert_eq(heavy_dmg, expected_heavy,
		"heavy damage == floor(base * 1.6) = %d" % expected_heavy)


func test_fist_damage_is_still_1_without_weapon() -> void:
	# Regression guard: the Damage formula's FIST_DAMAGE constant must not
	# have been accidentally changed. This is the guard rail from DECISIONS.md
	# 2026-05-02 "Damage formula constants locked".
	assert_eq(DamageScript.FIST_DAMAGE, 1,
		"FIST_DAMAGE must remain 1 — do NOT touch Damage.gd constants (DECISIONS.md)")
	var fist_dmg: int = DamageScript.compute_player_damage(null, 0, &"light")
	assert_eq(fist_dmg, 1, "null weapon -> FIST_DAMAGE = 1 flat")


# ==========================================================================
# (f) Regression guard — reset() clears seed state cleanly
# ==========================================================================

func test_reset_clears_seeded_iron_sword() -> void:
	_reset_and_reseed()
	assert_eq(_inv().get_items().size(), 1, "precondition: seed present")
	_inv().reset()
	assert_eq(_inv().get_items().size(), 0, "reset() clears seeded item")
	assert_null(_inv().get_equipped(&"weapon"), "reset() clears equipped slot too")


func before_each() -> void:
	# Always start tests from a clean slate. Prevents signal leakage between
	# tests when the Inventory autoload persists across the GUT run.
	_inv().reset()


func after_each() -> void:
	_inv().reset()
