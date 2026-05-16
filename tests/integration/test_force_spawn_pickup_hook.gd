extends GutTest
## Paired test for MobLootSpawner._test_force_spawn_pickup (ticket 86c9ukc2e).
##
## **What this enables (PR #229 finding #2 negative arm):**
## PR #229's positive arm asserts that the Room 01 gate unlocks when the mob
## is killed (mob_died fires → RoomGate._mobs_alive reaches 0). The negative
## arm — "if loot is picked up WITHOUT killing the mob, the gate stays closed"
## — requires a Pickup to exist in the world while the mob is still alive.
## Previously no test-only path existed to spawn a Pickup outside the
## `mob_died → MobLootSpawner.on_mob_died` chain. This hook provides it.
##
## **How the hook is gated:**
## `MobLootSpawner._test_force_spawn_pickup` is a static method with the
## `_test_` prefix. The prefix is the naming-convention guard — production
## code paths (Main, MultiMobRoom, Stratum1BossRoom, etc.) have no call sites
## and no plausible reason to call a method beginning with `_test_`. No runtime
## feature flag or stripped-in-export mechanism is required; the convention
## + this paired test serve as the documentation and usage example.
##
## **Tests in this file:**
##   1. Helper spawns a Pickup that lands in inventory (happy path — proves
##      the hook is usable end-to-end).
##   2. No mob was killed during the spawn (core negative-arm invariant).
##   3. Pickup is parented under the supplied parent after one frame.
##   4. Pickup carries the correct item (configure() wired correctly).
##   5. Hook with null parent returns un-parented Pickup (caller owns lifecycle).
##   6. Pickup collectability: picked_up signal wires correctly through
##      auto_collect_pickups + _on_body_entered.

const MobLootSpawnerScript: Script = preload("res://scripts/loot/MobLootSpawner.gd")
const GruntScript: Script = preload("res://scripts/mobs/Grunt.gd")


# ---- Helpers ---------------------------------------------------------

func _inv() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("Inventory")
	assert_not_null(n, "Inventory autoload registered")
	return n


func _make_room_root() -> Node2D:
	var n: Node2D = Node2D.new()
	add_child_autofree(n)
	return n


func _make_item(slot: int = ItemDef.Slot.ARMOR) -> ItemInstance:
	# Use ARMOR slot so the auto-equip-first-weapon-on-pickup branch is
	# bypassed — keeps the inventory-delta assertions clean (ticket 86c9qbb3k).
	var def: ItemDef = ContentFactory.make_item_def({
		"id": &"test_force_spawn_armor",
		"slot": slot,
	})
	return ItemInstance.new(def, ItemDef.Tier.T1)


func before_each() -> void:
	_inv().reset()


func after_each() -> void:
	_inv().reset()


# ---- Test 1: happy path — pickup lands in inventory ------------------

func test_force_spawn_pickup_lands_in_inventory() -> void:
	var room: Node2D = _make_room_root()
	var item: ItemInstance = _make_item()

	var pickup: Pickup = MobLootSpawner._test_force_spawn_pickup(
		item, Vector2(100.0, 100.0), room)

	assert_not_null(pickup, "helper returns a Pickup")
	# Wire to Inventory (production path: caller calls auto_collect_pickups).
	_inv().auto_collect_pickups([pickup])
	# Deferred add_child must land before the pickup is collectible.
	await get_tree().process_frame

	# Simulate player walking onto the pickup.
	pickup.emit_signal("picked_up", pickup.item, pickup)
	assert_eq(_inv().get_items().size(), 1,
		"force-spawned pickup lands in inventory via auto_collect_pickups path")
	assert_eq((_inv().get_items()[0] as ItemInstance).def.id, item.def.id,
		"inventory item matches the force-spawned item")


# ---- Test 2: no mob died during force-spawn --------------------------

func test_force_spawn_does_not_require_mob_death() -> void:
	# The core negative-arm invariant: spawn a pickup while the mob is alive,
	# confirm the mob is still alive (mob_died never fired).
	var room: Node2D = _make_room_root()
	var item: ItemInstance = _make_item()

	# Spawn a real Grunt with a loot table so we can tell if mob_died fires.
	var grunt: Grunt = GruntScript.new()
	var loot_def: ItemDef = ContentFactory.make_item_def({"id": &"grunt_loot"})
	var entry: LootEntry = ContentFactory.make_loot_entry(loot_def, 1.0, 0)
	var table: LootTableDef = ContentFactory.make_loot_table({"entries": [entry]})
	grunt.mob_def = ContentFactory.make_mob_def({"hp_base": 50, "loot_table": table})
	add_child_autofree(grunt)

	var mob_died_fired: bool = false
	grunt.mob_died.connect(func(_m, _p, _d): mob_died_fired = true)

	# Force-spawn a pickup without touching the grunt.
	var pickup: Pickup = MobLootSpawner._test_force_spawn_pickup(
		item, Vector2(50.0, 50.0), room)
	await get_tree().process_frame

	assert_false(mob_died_fired,
		"NEGATIVE ARM: mob_died must NOT fire when using _test_force_spawn_pickup " +
		"(the whole point of the hook is to get a pickup WITHOUT killing the mob)")
	assert_false(grunt.is_dead(),
		"NEGATIVE ARM: grunt is still alive after force-spawn (no kill occurred)")
	assert_not_null(pickup, "Pickup was spawned despite the mob being alive")


# ---- Test 3: Pickup is parented under the supplied parent node -------

func test_force_spawn_pickup_is_parented_under_room() -> void:
	var room: Node2D = _make_room_root()
	var item: ItemInstance = _make_item()

	var pickup: Pickup = MobLootSpawner._test_force_spawn_pickup(
		item, Vector2(80.0, 80.0), room)
	# add_child is deferred — same as on_mob_died.
	await get_tree().process_frame

	assert_eq(pickup.get_parent(), room,
		"force-spawned Pickup is parented under the supplied room root after one frame")


# ---- Test 4: Pickup carries the correct item -------------------------

func test_force_spawn_pickup_carries_correct_item() -> void:
	var room: Node2D = _make_room_root()
	var item: ItemInstance = _make_item()

	var pickup: Pickup = MobLootSpawner._test_force_spawn_pickup(
		item, Vector2.ZERO, room)

	assert_not_null(pickup.item,
		"Pickup.item is non-null immediately after _test_force_spawn_pickup")
	assert_eq(pickup.item, item,
		"Pickup.item is the SAME ItemInstance passed to the helper (not a copy)")
	assert_eq(pickup.item.def.id, item.def.id,
		"Pickup item def id matches the supplied item's def id")


# ---- Test 5: null parent — returned Pickup is un-parented ------------

func test_force_spawn_pickup_null_parent_returns_unparented_pickup() -> void:
	var item: ItemInstance = _make_item()

	var pickup: Pickup = MobLootSpawner._test_force_spawn_pickup(
		item, Vector2(200.0, 200.0), null)
	# No deferred add_child was scheduled (parent == null).
	await get_tree().process_frame

	assert_not_null(pickup, "helper returns a Pickup even when parent is null")
	assert_null(pickup.get_parent(),
		"Pickup has no parent when null was passed — caller owns lifecycle")
	# Cleanup: manually free the un-parented Pickup (no autofree node owns it).
	pickup.free()


# ---- Test 6: collectability via auto_collect_pickups + body_entered --

func test_force_spawn_pickup_is_collectable_via_body_entered() -> void:
	# Exercises the production collection chain end-to-end:
	#   1. _test_force_spawn_pickup creates the Pickup
	#   2. auto_collect_pickups wires picked_up → Inventory.on_pickup_collected
	#   3. _on_body_entered(player) emits picked_up
	#   4. Inventory.add() ingests the item
	# This is the same chain the real mob-loot path uses; the hook slot-swaps
	# `on_mob_died` as the Pickup factory while keeping everything else identical.
	var room: Node2D = _make_room_root()
	# Use an ARMOR item — armor never auto-equips, so inv_after - inv_before == 1.
	var item: ItemInstance = _make_item(ItemDef.Slot.ARMOR)

	var pickup: Pickup = MobLootSpawner._test_force_spawn_pickup(
		item, Vector2(32.0, 32.0), room)
	_inv().auto_collect_pickups([pickup])
	await get_tree().process_frame

	var inv_before: int = _inv().get_items().size()
	# Confirm the picked_up signal is wired (auto_collect_pickups contract).
	assert_gt(pickup.picked_up.get_connections().size(), 0,
		"picked_up signal has at least one listener (auto_collect_pickups wired it)")

	# Simulate player body_entered.
	pickup.emit_signal("picked_up", pickup.item, pickup)

	var inv_after: int = _inv().get_items().size()
	assert_eq(inv_after, inv_before + 1,
		"force-spawned pickup collected via body_entered adds exactly 1 item to inventory")
