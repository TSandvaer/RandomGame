class_name HealingFountain
extends Area2D
## A pre-placed healing element that restores the player's HP when stepped
## into. Single-use per room visit (consumed on activation), regenerates on
## a fresh run. Used in Stratum1Room06 as a mid-stratum reward per the
## difficulty-curve guidance in the rooms-2-to-8 dispatch.
##
## Contract:
##   - Player overlap fires `body_entered`.
##   - If not yet consumed, calls `body.heal(amount)` if the body has a
##     `heal` method, OR sets `body.hp_current` directly as a fallback for
##     simpler test fakes.
##   - Emits `consumed(amount, recipient)` and disables further triggers.
##
## Design note: I picked Area2D + duck-typed `heal()` rather than coupling
## to Devon's Player class so this scene remains test-friendly (we can drop
## a CharacterBody2D fake into the test and assert via signals).

# ---- Signals --------------------------------------------------------

signal consumed(amount: int, recipient: Node)

# ---- Layer bits -----------------------------------------------------

const LAYER_PICKUPS: int = 1 << 5  # bit 6 (reuse pickups layer)
const LAYER_PLAYER: int = 1 << 1   # bit 2

# ---- Inspector -----------------------------------------------------

## How much HP this fountain restores. M1 placement (Room 06 reward)
## restores a meaningful chunk — 40 HP on a 100 HP cap = 40%.
@export var heal_amount: int = 40

## If true, the fountain queue_frees itself after consumption (cleaner
## scene tree). If false, it stays as an inert visual marker. M1 default
## is to free.
@export var free_after_consume: bool = true

# ---- Runtime --------------------------------------------------------

var _consumed: bool = false


func _ready() -> void:
	if collision_layer == 0:
		collision_layer = LAYER_PICKUPS
	if collision_mask == 0:
		collision_mask = LAYER_PLAYER
	body_entered.connect(_on_body_entered)


# ---- Public API ----------------------------------------------------

func is_consumed() -> bool:
	return _consumed


# ---- Internal ------------------------------------------------------

func _on_body_entered(body: Node) -> void:
	if _consumed:
		return
	if body == null:
		return
	# Player group check — same convention as Pickup.gd. Mobs are masked
	# out anyway, but defensive.
	if not body.is_in_group("player"):
		return
	_apply_heal(body)


func _apply_heal(recipient: Node) -> void:
	_consumed = true
	# Prefer a `heal(amount)` API if the recipient defines one.
	if recipient.has_method("heal"):
		recipient.call("heal", heal_amount)
	elif recipient.get("hp_current") != null and recipient.get("hp_max") != null:
		# Fallback: clamp into hp_max. Used by simpler test fakes.
		var current: int = int(recipient.get("hp_current"))
		var maxhp: int = int(recipient.get("hp_max"))
		recipient.set("hp_current", min(maxhp, current + heal_amount))
	consumed.emit(heal_amount, recipient)
	if free_after_consume:
		queue_free()
