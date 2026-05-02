extends GutTest
## Integration: MobLootSpawner -> Pickup -> Inventory.
##
## Per Devon run-007 dispatch:
##   1. MobLootSpawner spawns pickups; Inventory ingests them.
##   2. Multiple drops in quick succession all picked up correctly.
##   3. Pickup near full inventory: graceful capacity check.

const LootRollerScript: Script = preload("res://scripts/loot/LootRoller.gd")
const MobLootSpawnerScript: Script = preload("res://scripts/loot/MobLootSpawner.gd")
const PickupScript: Script = preload("res://scripts/loot/Pickup.gd")


func _inv() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("Inventory")
	assert_not_null(n, "Inventory autoload registered")
	return n


func _make_room_root() -> Node2D:
	var n: Node2D = Node2D.new()
	add_child_autofree(n)
	return n


func _build_table_with(item: ItemDef, count: int = 1) -> LootTableDef:
	var entries: Array[LootEntry] = []
	for i in count:
		entries.append(ContentFactory.make_loot_entry(item, 1.0, 0))
	return ContentFactory.make_loot_table({"entries": entries, "roll_count": count})


func before_each() -> void:
	_inv().reset()


func after_each() -> void:
	_inv().reset()


# =======================================================================
# Test 1 — MobLootSpawner -> Inventory.add fires (via Pickup signal)
# =======================================================================

func test_spawner_drop_routes_to_inventory_via_pickup() -> void:
	var roller: LootRoller = LootRollerScript.new()
	roller.seed_rng(11)
	var spawner: MobLootSpawner = MobLootSpawnerScript.new(roller)
	var room: Node2D = _make_room_root()
	spawner.set_parent_for_pickups(room)

	var item_def: ItemDef = ContentFactory.make_item_def({"id": &"int_weapon"})
	var table: LootTableDef = _build_table_with(item_def, 1)
	var mob_def: MobDef = ContentFactory.make_mob_def({"loot_table": table})

	var spawned: Array[Node] = spawner.on_mob_died(null, Vector2.ZERO, mob_def)
	assert_eq(spawned.size(), 1, "one drop spawned")
	# Wire each pickup to Inventory's pickup hook (production path).
	_inv().auto_collect_pickups(spawned)
	# Now simulate the player walking onto the pickup -> emits picked_up.
	# Pickup.picked_up is emitted by `_on_body_entered`. We bypass physics by
	# directly emitting from the Pickup; the pickup-hook adds to inventory.
	(spawned[0] as Pickup).emit_signal("picked_up", (spawned[0] as Pickup).item, spawned[0])
	assert_eq(_inv().get_items().size(), 1, "item ingested from spawner -> pickup")
	assert_eq((_inv().get_items()[0] as ItemInstance).def.id, item_def.id)


# =======================================================================
# Test 2 — Multiple drops in quick succession all picked up correctly
# =======================================================================

func test_multiple_drops_all_picked_up() -> void:
	var roller: LootRoller = LootRollerScript.new()
	roller.seed_rng(22)
	var spawner: MobLootSpawner = MobLootSpawnerScript.new(roller)
	var room: Node2D = _make_room_root()
	spawner.set_parent_for_pickups(room)

	var item_def: ItemDef = ContentFactory.make_item_def({"id": &"int_burst"})
	var table: LootTableDef = _build_table_with(item_def, 3)
	var mob_def: MobDef = ContentFactory.make_mob_def({"loot_table": table})

	var spawned: Array[Node] = spawner.on_mob_died(null, Vector2.ZERO, mob_def)
	assert_gt(spawned.size(), 0, "at least one drop")
	_inv().auto_collect_pickups(spawned)
	for p_v in spawned:
		var p: Pickup = p_v as Pickup
		p.emit_signal("picked_up", p.item, p)
	assert_eq(_inv().get_items().size(), spawned.size(),
		"every spawned drop ended up in inventory")


# =======================================================================
# Test 3 — Pickup near full inventory: graceful capacity check
# =======================================================================

func test_pickup_near_full_inventory_gracefully_rejects() -> void:
	# Fill the inventory to the cap.
	for i in 24:
		var d: ItemDef = ContentFactory.make_item_def({
			"id": StringName("filler_%d" % i),
			"slot": ItemDef.Slot.WEAPON,
		})
		_inv().add(ItemInstance.new(d, ItemDef.Tier.T1))
	assert_true(_inv().is_full(), "inventory full")

	# Spawn one drop and try to ingest.
	var roller: LootRoller = LootRollerScript.new()
	roller.seed_rng(33)
	var spawner: MobLootSpawner = MobLootSpawnerScript.new(roller)
	var room: Node2D = _make_room_root()
	spawner.set_parent_for_pickups(room)
	var item_def: ItemDef = ContentFactory.make_item_def({"id": &"overflow_weapon"})
	var table: LootTableDef = _build_table_with(item_def, 1)
	var mob_def: MobDef = ContentFactory.make_mob_def({"loot_table": table})
	var spawned: Array[Node] = spawner.on_mob_died(null, Vector2.ZERO, mob_def)
	assert_eq(spawned.size(), 1, "spawner still spawns regardless of inventory")

	_inv().auto_collect_pickups(spawned)
	watch_signals(_inv())
	(spawned[0] as Pickup).emit_signal("picked_up", (spawned[0] as Pickup).item, spawned[0])
	# Capacity respected — inventory still 24 items.
	assert_eq(_inv().get_items().size(), 24, "full inventory does not overflow")
	assert_signal_emitted(_inv(), "add_rejected")


# =======================================================================
# Bonus probe — direct ingest_rolls helper handles batched roll arrays
# =======================================================================

func test_ingest_rolls_handles_batches() -> void:
	var rolls: Array = []
	for i in 5:
		var d: ItemDef = ContentFactory.make_item_def({
			"id": StringName("batch_%d" % i),
			"slot": ItemDef.Slot.WEAPON,
		})
		rolls.append(ItemInstance.new(d, ItemDef.Tier.T1))
	var accepted: int = _inv().ingest_rolls(rolls)
	assert_eq(accepted, 5, "all 5 rolls accepted")
	assert_eq(_inv().get_items().size(), 5)
