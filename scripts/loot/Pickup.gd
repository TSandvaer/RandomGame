class_name Pickup
extends Area2D
## A world-spawned item pickup. Player walks over it (Area2D vs player
## layer) -> emits `picked_up` and queues itself free. The receiving
## inventory listener owns the `ItemInstance`.
##
## Layer convention: pickups sit on layer 6 (`pickups`). Mask is layer 2
## (player), so only the player triggers pickup — mobs ignore.
##
## **Encapsulated-monitoring + initial-overlap check (ticket 86c9qbb3k).**
## Pickup follows the Hitbox/Projectile `_init` monitoring-off → `_ready`
## defer-on pattern (see `.claude/docs/combat-architecture.md` § "Hitbox +
## Projectile encapsulated-monitoring rule"). `_ready` defers
## `_activate_and_check_initial_overlap()`, which re-enables monitoring AND
## collects against a player already overlapping at spawn: `Area2D.body_entered`
## only fires on the non-overlap → overlap TRANSITION, so a Pickup that spawns
## directly under the player (e.g. the Stage-2b dummy drops its iron_sword at
## its own death position — the player may be standing on that exact tile from
## the killing blow) would NEVER fire `body_entered` and could never be
## collected. The deferred initial-overlap pass walks `get_overlapping_bodies()`
## and collects against anything already inside — the same fix shape as
## `Hitbox._activate_and_check_initial_overlaps` (PR #143).

signal picked_up(item: ItemInstance, pickup: Pickup)

const LAYER_PICKUPS: int = 1 << 5  # bit 6
const LAYER_PLAYER: int = 1 << 1   # bit 2

var item: ItemInstance = null

## Idempotency latch — set true the moment the Pickup is collected so a
## body_entered and an initial-overlap pass (or two body_entered events in
## the same frame) cannot double-emit `picked_up`.
var _collected: bool = false


func _init() -> void:
	# Physics-flush safety — Pickup is an Area2D, and it is routinely added
	# via `call_deferred("add_child", ...)` from death-path callbacks that run
	# inside a physics flush (MobLootSpawner.on_mob_died, PracticeDummy._die).
	# Entering the tree with monitoring off and defer-activating in `_ready`
	# (Godot runs `_ready` after the current physics step) keeps every spawn
	# site auto-protected — same encapsulated-monitoring pattern as Hitbox /
	# Projectile (see .claude/docs/combat-architecture.md).
	monitoring = false
	monitorable = false


func _ready() -> void:
	if collision_layer == 0:
		collision_layer = LAYER_PICKUPS
	if collision_mask == 0:
		collision_mask = LAYER_PLAYER
	body_entered.connect(_on_body_entered)
	# Defer the monitoring re-enable + initial-overlap check by one more frame.
	# Two reasons (both mirror Hitbox._ready → _activate_and_check_initial_overlaps):
	#   1. Physics-flush safety — flipping `monitoring` on must land after the
	#      current flush closes (Pickup is added via call_deferred from
	#      death-path callbacks running inside a flush).
	#   2. `get_overlapping_bodies()` returns empty until the engine has
	#      computed overlaps for the just-added Area2D — the check has to wait
	#      one physics step.
	call_deferred("_activate_and_check_initial_overlap")


## Re-enable monitoring (the encapsulated-monitoring pattern's `_ready`-side
## flip) and collect against any player body already overlapping the Pickup
## at spawn. `Area2D.body_entered` only fires on the non-overlap → overlap
## transition; a Pickup spawned under the player (the killing-blow case)
## needs this explicit pass or it could never be collected. Mirrors
## `Hitbox._activate_and_check_initial_overlaps`.
func _activate_and_check_initial_overlap() -> void:
	if not is_inside_tree():
		return
	# Order is load-bearing: monitoring must be true before
	# `get_overlapping_bodies` returns anything.
	monitoring = true
	monitorable = true
	if item == null:
		return
	for body in get_overlapping_bodies():
		if body != null and body.is_in_group("player"):
			_on_body_entered(body)
			return


## Configure the pickup with its `ItemInstance`. Call before adding to
## the scene tree.
func configure(p_item: ItemInstance) -> void:
	item = p_item


func _on_body_entered(body: Node) -> void:
	if _collected:
		# Already collected this frame (initial-overlap pass + a body_entered
		# event, or two overlapping bodies) — do not double-emit.
		return
	if item == null:
		queue_free()
		return
	# Only player triggers pickup. Mobs are masked out via collision_mask
	# anyway, but belt-and-suspenders.
	if not body.is_in_group("player"):
		return
	_collected = true
	picked_up.emit(item, self)
	queue_free()
