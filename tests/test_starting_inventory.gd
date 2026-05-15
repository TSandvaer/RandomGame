extends GutTest
## Paired tests for chore(inventory): retire PR #146 iron_sword boot-equip
## bandaid → auto-equip-first-weapon-on-pickup (ClickUp 86c9qbb3k).
##
## **What changed:** PR #145/#146 seeded an iron_sword into the grid at
## `Inventory._ready()` and auto-equipped it from `Main._ready()` via
## `equip_starter_weapon_if_needed`. Both `_seed_starting_inventory` and
## `equip_starter_weapon_if_needed` are RETIRED. The design-correct onboarding
## path is **auto-equip the first weapon on pickup**: the Stage-2b Room01
## PracticeDummy drops an iron_sword, the player walks onto it, and
## `Inventory.on_pickup_collected` adds it to the grid AND auto-equips it
## (first-weapon-only) so the player is never fistless.
##
## **What this guards:**
##   (a) `Inventory._ready()` no longer seeds anything — a fresh autoload has
##       an empty grid and empty equipped map (no boot-time iron_sword).
##   (b) `on_pickup_collected` with a WEAPON item, no weapon equipped →
##       auto-equips it (weapon slot populated AND grid no longer holds it).
##   (c) `on_pickup_collected` with a WEAPON item, a weapon ALREADY equipped →
##       does NOT auto-swap; the new weapon lands in the grid, the equipped
##       weapon is untouched. (Edge probe: first-weapon-only rule.)
##   (d) `on_pickup_collected` with a NON-weapon (armor) item → never
##       auto-equips; armor always just lands in the grid.
##   (e) The auto-equip wires the dual-surface state — `Player._equipped_weapon`
##       is set, not just `Inventory._equipped["weapon"]` (real Player node,
##       not a stub — the PR #145 stub-Node miss class).
##   (f) `iron_sword.tres` still loads + resolves via ContentRegistry (BB-2
##       guard — the dummy still drops it, so the resource must resolve).
##   (g) Retired-API guard: `_seed_starting_inventory` and
##       `equip_starter_weapon_if_needed` are GONE from the Inventory autoload.
##
## **Test isolation:** `before_each` / `after_each` reset the autoload so
## equipped/grid state doesn't leak across tests.

const DamageScript: Script = preload("res://scripts/combat/Damage.gd")
const PlayerScript: Script = preload("res://scripts/player/Player.gd")


# ---- Autoload accessors -------------------------------------------------

func _inv() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("Inventory")
	assert_not_null(n, "Inventory autoload must be registered in project.godot")
	return n


# ---- Helpers ------------------------------------------------------------

func _make_iron_sword_instance() -> ItemInstance:
	# The real iron_sword the PracticeDummy drops (damage=6).
	var def: ItemDef = load("res://resources/items/weapons/iron_sword.tres") as ItemDef
	assert_not_null(def, "iron_sword.tres must load")
	return ItemInstance.new(def, def.tier)


func _make_weapon_instance(id: StringName = &"test_sword", damage_override: int = 5) -> ItemInstance:
	var def: ItemDef = ContentFactory.make_item_def({
		"id": id,
		"slot": ItemDef.Slot.WEAPON,
		"base_stats": ContentFactory.make_item_base_stats({"damage": damage_override}),
	})
	return ItemInstance.new(def, ItemDef.Tier.T1)


func _make_armor_instance(id: StringName = &"test_armor") -> ItemInstance:
	var def: ItemDef = ContentFactory.make_item_def({
		"id": id,
		"slot": ItemDef.Slot.ARMOR,
		"base_stats": ContentFactory.make_item_base_stats({"damage": 0}),
	})
	return ItemInstance.new(def, ItemDef.Tier.T1)


func before_each() -> void:
	_inv().reset()


func after_each() -> void:
	_inv().reset()


# ==========================================================================
# AC (a) — Inventory._ready() no longer seeds anything
# ==========================================================================

func test_inventory_does_not_seed_on_reset() -> void:
	# reset() leaves the autoload in the same state a fresh _ready() does:
	# empty grid, empty equipped map. The retired _seed_starting_inventory
	# would have left exactly one iron_sword in the grid.
	_inv().reset()
	assert_eq(_inv().get_items().size(), 0,
		"fresh Inventory has an empty grid — no boot-time iron_sword seed " +
		"(PR #146 bandaid retired, ticket 86c9qbb3k)")
	assert_null(_inv().get_equipped(&"weapon"),
		"fresh Inventory has no equipped weapon — no boot-time auto-equip")


# ==========================================================================
# AC (b) — auto-equip-first-weapon-on-pickup: weapon + empty slot → equipped
# ==========================================================================

func test_pickup_weapon_with_empty_slot_auto_equips() -> void:
	var sword: ItemInstance = _make_iron_sword_instance()
	# Drive the production pickup hook directly (Pickup.picked_up →
	# Inventory.on_pickup_collected). No weapon equipped → must auto-equip.
	_inv().on_pickup_collected(sword)
	var equipped: ItemInstance = _inv().get_equipped(&"weapon") as ItemInstance
	assert_not_null(equipped,
		"picking up a weapon with an empty weapon slot must auto-equip it")
	assert_eq(equipped.def.id, &"iron_sword",
		"the auto-equipped weapon is the picked-up iron_sword")
	# The sword moved from grid → slot: it is NOT also sitting in the grid.
	assert_false(_inv().get_items().has(sword),
		"auto-equipped weapon is removed from the grid (moved into the slot)")
	assert_eq(_inv().get_items().size(), 0,
		"grid is empty — the only picked-up item went straight to the slot")


# ==========================================================================
# AC (c) — first-weapon-only: weapon + slot ALREADY filled → NO auto-swap
# ==========================================================================

func test_pickup_weapon_with_slot_filled_does_not_auto_swap() -> void:
	# First weapon picked up: auto-equips (AC b path).
	var first_sword: ItemInstance = _make_weapon_instance(&"first_sword", 4)
	_inv().on_pickup_collected(first_sword)
	assert_eq((_inv().get_equipped(&"weapon") as ItemInstance), first_sword,
		"precondition: first picked-up weapon auto-equipped")
	# Second weapon picked up: must NOT auto-swap — it lands in the grid.
	var second_sword: ItemInstance = _make_weapon_instance(&"second_sword", 9)
	_inv().on_pickup_collected(second_sword)
	assert_eq((_inv().get_equipped(&"weapon") as ItemInstance), first_sword,
		"second weapon pickup must NOT auto-swap — equipped weapon unchanged " +
		"(auto-equip is first-weapon-only; mid-run swaps stay user-driven)")
	assert_true(_inv().get_items().has(second_sword),
		"the second picked-up weapon lands in the grid, not the slot")
	assert_eq(_inv().get_items().size(), 1,
		"grid holds exactly the un-equipped second weapon")


# ==========================================================================
# AC (d) — non-weapon pickup never auto-equips
# ==========================================================================

func test_pickup_armor_never_auto_equips() -> void:
	var armor: ItemInstance = _make_armor_instance()
	_inv().on_pickup_collected(armor)
	assert_null(_inv().get_equipped(&"weapon"),
		"picking up armor must NOT touch the weapon slot")
	assert_null(_inv().get_equipped(&"armor"),
		"picking up armor must NOT auto-equip the armor slot either — " +
		"auto-equip-on-pickup is weapon-only")
	assert_true(_inv().get_items().has(armor),
		"armor lands in the grid like any other non-weapon pickup")


# ==========================================================================
# AC (e) — auto-equip wires the dual-surface state (real Player, not a stub)
# ==========================================================================

func test_pickup_auto_equip_drives_both_surfaces() -> void:
	# Real Player node so _apply_equip_to_player can call Player.equip_item and
	# wire Player._equipped_weapon. A stub Node would silently skip the Player
	# surface (the PR #145 stub-Node miss class — see combat-architecture.md
	# §"Equipped-weapon dual-surface rule").
	var player: Player = PlayerScript.new()
	add_child_autofree(player)
	# Player._ready adds it to the "player" group so Inventory._find_player resolves it.
	var sword: ItemInstance = _make_iron_sword_instance()
	_inv().on_pickup_collected(sword)
	# Inventory surface.
	var inv_equipped: ItemInstance = _inv().get_equipped(&"weapon") as ItemInstance
	assert_not_null(inv_equipped, "Inventory surface: weapon slot populated")
	assert_eq(inv_equipped.def.id, &"iron_sword", "Inventory surface: iron_sword equipped")
	# Player surface — the dual-surface invariant.
	var weapon_on_player: ItemDef = player.get_equipped_weapon() as ItemDef
	assert_not_null(weapon_on_player,
		"Player.get_equipped_weapon() must be non-null after auto-equip-on-pickup — " +
		"if null, _apply_equip_to_player short-circuited (stub-Node miss class)")
	assert_eq(weapon_on_player.id, &"iron_sword",
		"Player._equipped_weapon points at the iron_sword")


func test_pickup_auto_equip_produces_weapon_scaled_damage() -> void:
	# Tier 3 — the auto-equip must flow through to the combat surface: the
	# equipped iron_sword produces weapon-scaled damage, NOT FIST_DAMAGE.
	var player: Player = PlayerScript.new()
	add_child_autofree(player)
	var sword: ItemInstance = _make_iron_sword_instance()
	_inv().on_pickup_collected(sword)
	var weapon: ItemDef = player.get_equipped_weapon() as ItemDef
	assert_not_null(weapon, "precondition: iron_sword auto-equipped onto Player")
	var light_dmg: int = DamageScript.compute_player_damage(weapon, 0, &"light")
	assert_gt(light_dmg, DamageScript.FIST_DAMAGE,
		"auto-equipped iron_sword light damage (%d) must exceed FIST_DAMAGE (%d)" %
		[light_dmg, DamageScript.FIST_DAMAGE])


# ==========================================================================
# AC (f) — iron_sword.tres still loads + resolves (BB-2 guard)
# ==========================================================================

func test_iron_sword_tres_loads_and_resolves() -> void:
	var def: ItemDef = load("res://resources/items/weapons/iron_sword.tres") as ItemDef
	assert_not_null(def, "iron_sword.tres loads as ItemDef")
	assert_eq(def.id, &"iron_sword")
	assert_eq(int(def.slot), int(ItemDef.Slot.WEAPON), "iron_sword slot is WEAPON")
	assert_not_null(def.base_stats, "iron_sword has base_stats sub-resource")
	assert_gt(def.base_stats.damage, 0, "iron_sword base damage > 0")
	# ContentRegistry must still resolve it — the dummy drop depends on it.
	var reg: ContentRegistry = ContentRegistry.new()
	reg.load_all()
	var resolved: ItemDef = reg.resolve_item(&"iron_sword")
	assert_not_null(resolved,
		"ContentRegistry must resolve iron_sword — null means BB-2 repeat")
	assert_eq(resolved.id, &"iron_sword", "resolved id matches")


# ==========================================================================
# AC (g) — retired-API guard: the bandaid methods are gone
# ==========================================================================

func test_retired_bandaid_methods_are_gone() -> void:
	# The PR #146 bandaid surfaces must NOT exist on the Inventory autoload.
	# If a future change re-introduces them, this test fails loudly so the
	# decision is deliberate (ticket 86c9qbb3k retired them on purpose).
	assert_false(_inv().has_method("equip_starter_weapon_if_needed"),
		"equip_starter_weapon_if_needed must be retired (PR #146 bandaid, " +
		"ticket 86c9qbb3k) — onboarding now auto-equips on pickup")
	assert_false(_inv().has_method("_seed_starting_inventory"),
		"_seed_starting_inventory must be retired — the Stage-2b dummy drop " +
		"is the single source of the starter iron_sword (no boot-time seed)")


# ==========================================================================
# Regression guard — reset() clears equipped + grid cleanly
# ==========================================================================

func test_reset_clears_equipped_and_grid() -> void:
	var sword: ItemInstance = _make_iron_sword_instance()
	_inv().on_pickup_collected(sword)
	assert_not_null(_inv().get_equipped(&"weapon"), "precondition: weapon equipped")
	_inv().reset()
	assert_eq(_inv().get_items().size(), 0, "reset() clears the grid")
	assert_null(_inv().get_equipped(&"weapon"), "reset() clears the equipped slot")
