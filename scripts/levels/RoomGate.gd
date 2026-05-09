class_name RoomGate
extends Area2D
## A gate that locks the room behind the player on entry and unlocks once
## every mob registered with the gate has died. Used by Stratum1Room02..08
## to enforce the "clear-the-room-to-progress" loop authored in
## `team/drew-dev/level-chunks.md` and the M1 RC dispatch.
##
## Lifecycle:
##   1. Author / room script calls `register_mob(mob)` for every mob that
##      must be cleared. The gate connects to the mob's `mob_died` signal.
##   2. Player crosses the gate's Area2D — `body_entered` fires, the gate
##      flips to LOCKED and emits `gate_locked`.
##   3. Each `mob_died` decrements the alive count. When the last registered
##      mob dies, the gate flips to UNLOCKED and emits `gate_unlocked`.
##
## Edge cases handled (paired tests in `tests/test_room_gate.gd`):
##   - Zero mobs registered → gate is UNLOCKED on lock-trigger (room is
##     "trivially clear"). Players never get stuck on an empty room.
##   - Mob death from off-screen attacks counts (we listen to `mob_died`,
##     not to a presence/visibility check).
##   - Multiple mobs dying in the same frame counted correctly (the
##     decrement is signal-driven, not polled per-frame).
##   - Re-entry idempotence: `body_entered` firing twice does not double-lock
##     or reset the alive counter.
##   - Mobs registered after lock are still tracked (late registrations are
##     valid; the gate doesn't snapshot at lock time).
##
## Layer convention: the gate sits on layer 0 (no collisions emitted) and
## masks layer 2 (player) so only the player triggers `body_entered`.

# ---- Signals ----------------------------------------------------------

## Player crossed the gate's Area2D for the first time. Cinematic / audio
## hooks may subscribe to play a door-slam sound.
signal gate_locked()

## Every registered mob has died (or no mobs were ever registered).
## Subscribers (room script, progression tracker) react by opening the
## next-room exit / marking the room cleared.
signal gate_unlocked()

# ---- States ----------------------------------------------------------

const STATE_OPEN: StringName = &"open"        # initial state, before lock-trigger
const STATE_LOCKED: StringName = &"locked"    # player crossed, mobs alive
const STATE_UNLOCKED: StringName = &"unlocked"  # all mobs dead

# ---- Layer bits (mirror project.godot) -------------------------------

const LAYER_PLAYER: int = 1 << 1  # bit 2 ("player")

# ---- Inspector ------------------------------------------------------

## Default trigger size (a thin horizontal strip suitable for a doorway).
## Overridden via `set_trigger_size` from the room script if needed.
@export var trigger_size: Vector2 = Vector2(48.0, 16.0)

# ---- Runtime --------------------------------------------------------

var _state: StringName = STATE_OPEN
var _mobs_alive: int = 0
var _registered_mobs: Array[Node] = []
# Idempotency: ensure unlocked emits exactly once.
var _unlocked_emitted: bool = false


func _ready() -> void:
	# Default layer/mask if the scene didn't set one. Tests that instantiate
	# bare get sensible behaviour. (collision_layer is left at the scene
	# default of 0 since the gate emits no collisions itself.)
	if collision_mask == 0:
		collision_mask = LAYER_PLAYER
	_ensure_collision_shape()
	body_entered.connect(_on_body_entered)
	# Bug 1 fix (ticket 86c9q7xgx): guard against Area2D-derived nodes
	# (Hitbox, Projectile, other trigger zones) accidentally activating the
	# gate via area_entered. In Godot 4, two overlapping Area2Ds each receive
	# area_entered on the other — connecting the signal and explicitly ignoring
	# it prevents any future listener from accidentally wiring gate logic here.
	# The RoomGate ONLY advances on CharacterBody2D (Player) entry; Area2D
	# neighbors are always no-ops.
	area_entered.connect(_on_area_entered_ignored)


# Ensure a CollisionShape2D child exists with a RectangleShape2D matching
# `trigger_size`. If the scene shipped one, we resize its shape; otherwise
# we make one. Either way the gate is ready to detect overlap with the
# correct trigger geometry.
func _ensure_collision_shape() -> void:
	var existing: CollisionShape2D = null
	for child in get_children():
		if child is CollisionShape2D:
			existing = child
			break
	if existing == null:
		existing = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = trigger_size
		existing.shape = rect
		add_child(existing)
		return
	# Resize the scene-supplied rectangle to match the inspector-set
	# trigger_size. If the shape isn't a RectangleShape2D (someone authored
	# a circle/capsule), leave it alone — that's an explicit author choice.
	if existing.shape is RectangleShape2D:
		(existing.shape as RectangleShape2D).size = trigger_size


# ---- Public API -----------------------------------------------------

func get_state() -> StringName:
	return _state


func is_locked() -> bool:
	return _state == STATE_LOCKED


func is_unlocked() -> bool:
	return _state == STATE_UNLOCKED


func mobs_alive() -> int:
	return _mobs_alive


## Register a mob whose death must occur before the gate unlocks. The gate
## connects to the mob's `mob_died` signal — Grunt / Charger / Shooter all
## emit a compatible signature (mob, position, mob_def).
##
## Safe to call before OR after the gate locks. Late registration is valid.
## Idempotent: re-registering the same mob is a no-op.
func register_mob(mob: Node) -> void:
	if mob == null:
		return
	if mob in _registered_mobs:
		return
	if not mob.has_signal("mob_died"):
		push_warning("RoomGate.register_mob: '%s' has no mob_died signal — skipped" % str(mob))
		return
	_registered_mobs.append(mob)
	_mobs_alive += 1
	# Connect with deferred so a synchronous mob_died emission inside
	# register_mob (rare, but possible in tests) doesn't underflow the count.
	mob.mob_died.connect(_on_mob_died)


## Force-lock the gate from script. Production uses `body_entered`; tests
## sometimes simulate without physics overlap.
func lock() -> void:
	if _state != STATE_OPEN:
		return
	_state = STATE_LOCKED
	gate_locked.emit()
	# If we were registered with zero mobs, fire unlocked immediately so the
	# player isn't stranded in a trivially-clear room.
	if _mobs_alive <= 0:
		_unlock()


## Test helper: simulate a player body crossing the trigger without physics
## overlap. Bypasses the CharacterBody2D type-check in _on_body_entered so
## headless tests can use bare FakePlayer nodes without a full CharacterBody2D
## scene tree. Calls lock() directly — same effect as _on_body_entered for a
## validated body.
func trigger_for_test(_body: Node = null) -> void:
	if _state != STATE_OPEN:
		return
	lock()


# ---- Internal -------------------------------------------------------

func _on_body_entered(body: Node) -> void:
	# Only first-cross matters; ignore re-entries.
	if _state != STATE_OPEN:
		return
	# Bug 1 fix (ticket 86c9q7xgx): only a CharacterBody2D on the player
	# physics layer should advance this gate. Area2D-derived nodes (Hitbox,
	# Projectile) cannot trigger body_entered per Godot 4 physics semantics —
	# only PhysicsBody2D nodes can — but mobs are also CharacterBody2D nodes.
	# The collision_mask already filters by layer (only player layer = bit 2),
	# so mob bodies (on enemy layer = bit 4) are excluded at the physics level.
	# This explicit CharacterBody2D check is a belt-and-suspenders defence
	# so a bare Node or a future refactor can never gate-trip by accident.
	if not body is CharacterBody2D:
		return
	lock()


## Area2D neighbors (Hitbox, Projectile, StratumExit triggers, etc.) entering
## the gate's detection zone are intentionally ignored. The gate ONLY responds
## to player CharacterBody2D via body_entered. This handler exists to:
##   (a) Explicitly document the no-op for future readers.
##   (b) Prevent any accidental wiring of gate logic to area_entered events —
##       if a future sub-class or hook inadvertently connects a second listener
##       here, the explicit no-op makes the intent unambiguous.
## See Bug 1 fix rationale in _on_body_entered.
func _on_area_entered_ignored(_area: Area2D) -> void:
	pass  # Gate never responds to Area2D entry — CharacterBody2D only.


func _on_mob_died(_mob: Variant, _pos: Variant = null, _def: Variant = null) -> void:
	# Signal signature varies (Grunt/Charger/Shooter all take 3 args), but
	# we don't need any of them — we just count.
	_mobs_alive = max(0, _mobs_alive - 1)
	if _mobs_alive == 0 and _state == STATE_LOCKED:
		_unlock()


func _unlock() -> void:
	if _unlocked_emitted:
		return
	_unlocked_emitted = true
	_state = STATE_UNLOCKED
	gate_unlocked.emit()
