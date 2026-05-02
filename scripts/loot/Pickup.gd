class_name Pickup
extends Area2D
## A world-spawned item pickup. Player walks over it (Area2D vs player
## layer) -> emits `picked_up` and queues itself free. The receiving
## inventory listener owns the `ItemInstance`.
##
## Layer convention: pickups sit on layer 6 (`pickups`). Mask is layer 2
## (player), so only the player triggers pickup — mobs ignore.

signal picked_up(item: ItemInstance, pickup: Pickup)

const LAYER_PICKUPS: int = 1 << 5  # bit 6
const LAYER_PLAYER: int = 1 << 1   # bit 2

var item: ItemInstance = null


func _ready() -> void:
	if collision_layer == 0:
		collision_layer = LAYER_PICKUPS
	if collision_mask == 0:
		collision_mask = LAYER_PLAYER
	body_entered.connect(_on_body_entered)


## Configure the pickup with its `ItemInstance`. Call before adding to
## the scene tree.
func configure(p_item: ItemInstance) -> void:
	item = p_item


func _on_body_entered(body: Node) -> void:
	if item == null:
		queue_free()
		return
	# Only player triggers pickup. Mobs are masked out via collision_mask
	# anyway, but belt-and-suspenders.
	if not body.is_in_group("player"):
		return
	picked_up.emit(item, self)
	queue_free()
