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
##
## **Physics-flush safety (run-002 P0, ticket TBA — Sponsor's
## `embergrave-html5-4ab2813` retest):** `mob_died` is emitted from
## `mob._die`, which itself runs synchronously on the physics-step
## callback chain (`Hitbox.body_entered → mob.take_damage → mob._die →
## mob_died.emit → on_mob_died`). The `Pickup` scene root is an `Area2D`,
## so calling `parent.add_child(pickup)` here is a physics-state mutation
## DURING THE PHYSICS QUERY FLUSH — Godot 4 panics with
## "Can't change this state while flushing queries. Use call_deferred()
## or set_deferred() to change monitoring state instead." and aborts the
## remaining call chain. From the player's perspective, mobs go
## `_die → tween-armed → ...permanent-stall...`, never reaching
## `_force_queue_free`. This is hidden as long as no mob actually dies
## (e.g. the FIST_DAMAGE=1 vs HP=50 imbalance), and surfaced the moment
## a kill lands.
##
## Fix: defer the `add_child` so it lands AFTER the physics flush. We
## still construct + configure the Pickup synchronously (so the returned
## array is populated for tests / signal-emission timing contracts), and
## still parent under `parent_for_pickups`, but the actual scene-tree
## insertion is `call_deferred`. Tests that need the pickup live this
## frame can `await get_tree().process_frame` once.
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
			# Defer add_child: Pickup is an Area2D, and on_mob_died runs
			# during the physics-query flush via the Hitbox body_entered
			# chain. Synchronous Area2D add panics Godot 4. See docstring.
			parent_for_pickups.call_deferred("add_child", pickup)
		spawned.append(pickup)
	return spawned
