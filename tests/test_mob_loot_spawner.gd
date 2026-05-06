extends GutTest
## Integration: connecting `Grunt.mob_died` to `MobLootSpawner.on_mob_died`
## produces Pickup nodes parented under the room, each carrying a rolled
## ItemInstance.

const LootRollerScript: Script = preload("res://scripts/loot/LootRoller.gd")
const MobLootSpawnerScript: Script = preload("res://scripts/loot/MobLootSpawner.gd")
const PickupScript: Script = preload("res://scripts/loot/Pickup.gd")
const GruntScript: Script = preload("res://scripts/mobs/Grunt.gd")


func _make_room_root() -> Node2D:
	var n: Node2D = Node2D.new()
	add_child_autofree(n)
	return n


func test_spawner_returns_empty_when_mob_def_has_no_loot_table() -> void:
	var roller: LootRoller = LootRollerScript.new()
	roller.seed_rng(1)
	var spawner: MobLootSpawner = MobLootSpawnerScript.new(roller)
	var room: Node2D = _make_room_root()
	spawner.set_parent_for_pickups(room)
	var def: MobDef = ContentFactory.make_mob_def({"loot_table": null})
	var spawned: Array[Node] = spawner.on_mob_died(null, Vector2.ZERO, def)
	assert_eq(spawned.size(), 0, "no loot_table -> no pickups, no crash")


func test_spawner_spawns_pickups_for_each_rolled_drop() -> void:
	var roller: LootRoller = LootRollerScript.new()
	roller.seed_rng(7)
	var spawner: MobLootSpawner = MobLootSpawnerScript.new(roller)
	var room: Node2D = _make_room_root()
	spawner.set_parent_for_pickups(room)

	# Build a 100% drop table.
	var item: ItemDef = ContentFactory.make_item_def()
	var entry: LootEntry = ContentFactory.make_loot_entry(item, 1.0, 0)
	var table: LootTableDef = ContentFactory.make_loot_table({"entries": [entry]})
	var def: MobDef = ContentFactory.make_mob_def({"loot_table": table})

	var spawned: Array[Node] = spawner.on_mob_died(null, Vector2(40.0, 60.0), def)
	assert_eq(spawned.size(), 1, "one rolled drop -> one pickup")
	var pickup: Pickup = spawned[0]
	assert_not_null(pickup.item, "pickup carries an ItemInstance")
	assert_eq(pickup.item.def, item, "pickup item references the same ItemDef")
	# add_child is deferred (physics-flush safety per `_die` P0 fix run-002).
	await get_tree().process_frame
	assert_eq(pickup.get_parent(), room, "pickup parented under the room root")


func test_spawner_position_respects_death_pos() -> void:
	var roller: LootRoller = LootRollerScript.new()
	roller.seed_rng(4)
	var spawner: MobLootSpawner = MobLootSpawnerScript.new(roller)
	var room: Node2D = _make_room_root()
	spawner.set_parent_for_pickups(room)

	var item: ItemDef = ContentFactory.make_item_def()
	var entry: LootEntry = ContentFactory.make_loot_entry(item, 1.0, 0)
	var table: LootTableDef = ContentFactory.make_loot_table({"entries": [entry]})
	var def: MobDef = ContentFactory.make_mob_def({"loot_table": table})

	var death_pos: Vector2 = Vector2(123.0, 456.0)
	var spawned: Array[Node] = spawner.on_mob_died(null, death_pos, def)
	# One drop -> ring offset is at angle 0 -> +x by 12.
	assert_almost_eq((spawned[0] as Pickup).position.x, death_pos.x + 12.0, 0.001)
	assert_almost_eq((spawned[0] as Pickup).position.y, death_pos.y, 0.001)


func test_grunt_death_through_signal_wires_to_spawner() -> void:
	# Wire it up exactly like the production code will:
	#   grunt.mob_died.connect(spawner.on_mob_died)
	# Then kill the grunt and verify pickups appear.
	var roller: LootRoller = LootRollerScript.new()
	roller.seed_rng(2)
	var spawner: MobLootSpawner = MobLootSpawnerScript.new(roller)
	var room: Node2D = _make_room_root()
	spawner.set_parent_for_pickups(room)

	var item: ItemDef = ContentFactory.make_item_def()
	var entry: LootEntry = ContentFactory.make_loot_entry(item, 1.0, 0)
	var table: LootTableDef = ContentFactory.make_loot_table({"entries": [entry]})
	var def: MobDef = ContentFactory.make_mob_def({"hp_base": 20, "loot_table": table})

	var g: Grunt = GruntScript.new()
	g.mob_def = def
	add_child_autofree(g)
	# Connect — the spawner returns an array but signal handlers ignore
	# return values; the side effect (pickups parented under room) is
	# what matters.
	g.mob_died.connect(spawner.on_mob_died)
	g.global_position = Vector2(80.0, 80.0)
	# Kill.
	g.take_damage(20, Vector2.ZERO, null)
	assert_true(g.is_dead())
	# Pickup add_child is deferred (physics-flush safety per `_die` P0 fix
	# run-002 — Pickup is an Area2D and can't be added during physics
	# query flush). Await one frame for the deferred call to land.
	await get_tree().process_frame
	# Verify pickups parented under room.
	var pickups: Array[Pickup] = []
	for child: Node in room.get_children():
		if child is Pickup:
			pickups.append(child)
	assert_gt(pickups.size(), 0, "grunt's death rolled at least one pickup via signal wiring")
