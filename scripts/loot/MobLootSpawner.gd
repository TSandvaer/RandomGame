class_name MobLootSpawner
extends RefCounted
## Glue between mob death events and loot spawning. Connect a Grunt's
## `mob_died` signal to `on_mob_died`, and this helper rolls the mob's
## loot table and spawns a Pickup for each rolled item at the death
## position.
##
## The helper holds a reference to the LootRoller so determinism (CI seed)
## stays under one knob.

const PickupScene: PackedScene = preload("res://scenes/loot/Pickup.tscn")

var roller: LootRoller
var parent_for_pickups: Node = null


func _init(p_roller: LootRoller = null) -> void:
	roller = p_roller if p_roller != null else LootRoller.new()


## Set the node that newly spawned pickups parent under. Typically the
## room/stratum root so pickups don't survive a room transition.
func set_parent_for_pickups(n: Node) -> void:
	parent_for_pickups = n


## Connect to a mob's `mob_died` signal:
##   grunt.mob_died.connect(spawner.on_mob_died)
##
## Returns spawned Pickup nodes for tests/inspection.
func on_mob_died(_mob: Node, death_pos: Vector2, mob_def: MobDef) -> Array[Node]:
	var spawned: Array[Node] = []
	if mob_def == null or mob_def.loot_table == null:
		return spawned
	var rolls: Array[ItemInstance] = roller.roll(mob_def.loot_table)
	if rolls.is_empty():
		return spawned
	# Spread pickups in a small ring so they don't all stack on one pixel.
	var angle_step: float = TAU / max(1, rolls.size())
	for i in rolls.size():
		var item: ItemInstance = rolls[i]
		var offset: Vector2 = Vector2.RIGHT.rotated(angle_step * float(i)) * 12.0
		var pickup: Pickup = PickupScene.instantiate()
		pickup.configure(item)
		pickup.position = death_pos + offset
		if parent_for_pickups != null:
			parent_for_pickups.add_child(pickup)
		spawned.append(pickup)
	return spawned
