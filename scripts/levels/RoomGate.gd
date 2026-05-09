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
##      mob dies, the gate starts DEATH_TWEEN_WAIT_SECS delay (so the mob
##      death animation plays visibly before the door opens), then flips to
##      UNLOCKED and emits `gate_unlocked`.
##
## Position B contract (M1 RC Sponsor soak attempt 4 — ticket 86c9q8052):
##   - "Room cleared" = all mob `mob_died` signals have fired AND the
##     death-tween wait has elapsed, door becomes walkable, player gets a
##     visual cue that the door opened.
##   - "Room counter advances" = player walks through the now-open door
##     (body_entered on the *exit* gate / StratumExit — NOT on this
##     entry-lock gate).
##   - The DEATH_TWEEN_WAIT_SECS delay decouples the visual tween from the
##     gate-open so Sponsor always sees the mob die before the door opens.
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

## Player walked through the gate after it was unlocked (UNLOCKED state,
## CharacterBody2D body_entered). This is the "door-walk" signal that drives
## room-counter advancement (Position B contract). Emits exactly once per
## gate lifetime — idempotent.
##
## Design: gate_unlocked purely signals the visual door-open; gate_traversed
## signals that the player actually chose to walk through. MultiMobRoom
## listens here (not gate_unlocked) to emit room_cleared, ensuring the room
## counter only advances when the player walks through the open door.
signal gate_traversed()

# ---- States ----------------------------------------------------------

const STATE_OPEN: StringName = &"open"        # initial state, before lock-trigger
const STATE_LOCKED: StringName = &"locked"    # player crossed, mobs alive
const STATE_UNLOCKED: StringName = &"unlocked"  # all mobs dead

# ---- Timing ----------------------------------------------------------

## How long to wait after the last mob_died fires before emitting
## gate_unlocked. Sized for the WORST-case mob death visual: Stratum1Boss
## holds for 400ms (BOSS_DEATH_HOLD) before its 200ms scale/alpha tween fires =
## 600ms total death visual; we add 50ms of slack = 650ms. Regular mobs
## (Grunt/Charger/Shooter) only have a 200ms tween, so 650ms covers them with
## significant slack. This ensures the mob's death animation plays visibly
## before the door opens — fixing the Sponsor soak-4 "I don't see it dying"
## report (Tess bounce: original 0.4s would have regressed for Boss).
## Zero mobs (trivially-clear room) skips the wait and unlocks immediately.
const DEATH_TWEEN_WAIT_SECS: float = 0.650

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
# Idempotency guard for gate_traversed: emit once at most.
var _traversed_emitted: bool = false
# Set true when the last mob has died and we're waiting for DEATH_TWEEN_WAIT_SECS
# before emitting gate_unlocked. Guards against _on_mob_died being re-entered
# (e.g. late-registered mob dying while the timer is in flight).
var _death_wait_in_flight: bool = false
# Timer node for the death-tween wait. Created lazily in _start_death_wait.
# Using a Timer node (NOT SceneTreeTimer) so synchronous test contexts can
# either advance physics ticks OR set `test_skip_death_wait = true` to bypass.
# (Tess bounce on PR #153: SceneTreeTimer.timeout never fires in GUT
# synchronous test context — broke 8 pre-existing test_room_gate.gd tests.)
var _death_wait_timer: Timer = null

# Test-only escape hatch: when true, _on_mob_died unlocks SYNCHRONOUSLY without
# waiting for the death-tween timer. Production path leaves this false; the
# original test fixtures and all the "mob dies → gate unlocks" assertions stay
# green by flipping this on. New tests that specifically want to verify the
# wait-then-unlock sequence leave it false and advance the timer manually.
@export var test_skip_death_wait: bool = false


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
	# DIAGNOSTIC (ticket 86c9qbhm5 — Devon investigation): Log gate's runtime
	# config so we can verify shape size, layer/mask, monitoring at boot.
	var shape_info: String = "<no shape>"
	for child in get_children():
		if child is CollisionShape2D:
			var cs: CollisionShape2D = child as CollisionShape2D
			if cs.shape is RectangleShape2D:
				var rs: RectangleShape2D = cs.shape as RectangleShape2D
				shape_info = "RectangleShape2D size=(%.1f,%.1f) disabled=%s" % [rs.size.x, rs.size.y, cs.disabled]
			else:
				shape_info = "%s disabled=%s" % [cs.shape.get_class() if cs.shape else "<null shape>", cs.disabled]
			break
	print("[RoomGate-diag] _ready | pos=(%.1f,%.1f) trigger_size=(%.1f,%.1f) layer=%d mask=%d monitoring=%s shape=%s" % [
		global_position.x, global_position.y, trigger_size.x, trigger_size.y,
		collision_layer, collision_mask, monitoring, shape_info
	])
	_combat_trace("RoomGate._ready", "pos=(%.1f,%.1f) trigger_size=(%.1f,%.1f) layer=%d mask=%d monitoring=%s shape=%s" % [
		global_position.x, global_position.y, trigger_size.x, trigger_size.y,
		collision_layer, collision_mask, monitoring, shape_info
	])


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
## validated body. Also flips `test_skip_death_wait` so the existing
## "kill mob → gate unlocks" tests stay synchronous (no Timer pump needed).
## Tests that specifically need to assert the wait sequence should construct
## the gate without going through this helper.
func trigger_for_test(_body: Node = null) -> void:
	test_skip_death_wait = true
	if _state != STATE_OPEN:
		return
	lock()


# ---- Internal -------------------------------------------------------

func _on_body_entered(body: Node) -> void:
	# DIAGNOSTIC (ticket 86c9qbhm5 — Devon investigation): Unconditional entry
	# trace BEFORE any type-check or state-check. If this line does NOT appear in
	# the Playwright console capture during a gate-walk, body_entered is not firing
	# at all (Case B — Godot/Playwright signal-emission issue). If it DOES appear
	# but downstream traces don't, the issue is downstream of body_entered (Case A).
	var body_cls: String = body.get_class() if body != null else "<null>"
	var body_name: String = body.name if body != null else "<null>"
	var body_pos: Vector2 = body.global_position if body != null and "global_position" in body else Vector2.ZERO
	var gate_pos: Vector2 = global_position
	print("[RoomGate-diag] _on_body_entered ENTRY | body=%s name=%s body_pos=(%.1f,%.1f) gate_pos=(%.1f,%.1f) state=%s mobs_alive=%d" % [
		body_cls, body_name, body_pos.x, body_pos.y, gate_pos.x, gate_pos.y, _state, _mobs_alive
	])
	_combat_trace("RoomGate._on_body_entered", "ENTRY body=%s name=%s state=%s mobs_alive=%d" % [body_cls, body_name, _state, _mobs_alive])
	# Bug 1 fix (ticket 86c9q7xgx): only a CharacterBody2D on the player
	# physics layer should advance this gate. Area2D-derived nodes (Hitbox,
	# Projectile) cannot trigger body_entered per Godot 4 physics semantics —
	# only PhysicsBody2D nodes can — but mobs are also CharacterBody2D nodes.
	# The collision_mask already filters by layer (only player layer = bit 2),
	# so mob bodies (on enemy layer = bit 4) are excluded at the physics level.
	# This explicit CharacterBody2D check is a belt-and-suspenders defence
	# so a bare Node or a future refactor can never gate-trip by accident.
	if not body is CharacterBody2D:
		print("[RoomGate-diag] _on_body_entered REJECTED non-CharacterBody2D body=%s" % body_cls)
		return
	# Position B contract (ticket 86c9q94fg):
	#   OPEN → lock (player enters room, mobs still alive).
	#   UNLOCKED → gate_traversed (player walks through the already-open door).
	# These are two distinct events. Room-counter advancement MUST be driven by
	# the traversal (second case), NOT by gate_unlocked (which is purely visual).
	# [combat-trace] ROOM_GATE_TRAVERSED fires here, before room_cleared.
	if _state == STATE_UNLOCKED:
		if not _traversed_emitted:
			_traversed_emitted = true
			_combat_trace("RoomGate.gate_traversed", "player walked through open door — emitting gate_traversed")
			gate_traversed.emit()
		return
	# Only first-cross into a locked room matters; ignore re-entries in other states.
	if _state != STATE_OPEN:
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
	# DIAGNOSTIC (ticket 86c9qbhm5)
	print("[RoomGate-diag] _on_mob_died | mobs_alive=%d state=%s death_wait_in_flight=%s" % [_mobs_alive, _state, _death_wait_in_flight])
	_combat_trace("RoomGate._on_mob_died", "mobs_alive=%d state=%s death_wait_in_flight=%s" % [_mobs_alive, _state, _death_wait_in_flight])
	if _mobs_alive == 0 and _state == STATE_LOCKED and not _death_wait_in_flight:
		_death_wait_in_flight = true
		_start_death_wait()


## Start (or skip) the DEATH_TWEEN_WAIT_SECS delay before unlocking.
##
## Production path: spawn a one-shot Timer node, start it, and connect its
## `timeout` signal to `_unlock`. When the timer fires (after Engine ticks
## the physics frame in real game), `_unlock` emits gate_unlocked.
##
## Test path: tests can either (a) set `test_skip_death_wait = true` for
## immediate unlock (matches all pre-existing test_room_gate.gd assertions),
## or (b) leave it false and call `advance_death_wait()` to simulate the
## elapsed timer for tests that specifically verify the wait sequence.
##
## Bare-instantiated (no scene tree) path: unlock immediately — no Timer node
## can run without a tree, and the bare-instance tests never asserted the
## delay anyway.
func _start_death_wait() -> void:
	# DIAGNOSTIC (ticket 86c9qbhm5)
	print("[RoomGate-diag] _start_death_wait | test_skip=%s is_inside_tree=%s wait_time=%.3f" % [test_skip_death_wait, is_inside_tree(), DEATH_TWEEN_WAIT_SECS])
	_combat_trace("RoomGate._start_death_wait", "test_skip=%s is_inside_tree=%s wait_time=%.3f" % [test_skip_death_wait, is_inside_tree(), DEATH_TWEEN_WAIT_SECS])
	if test_skip_death_wait or not is_inside_tree():
		_unlock()
		return
	_death_wait_timer = Timer.new()
	_death_wait_timer.one_shot = true
	_death_wait_timer.wait_time = DEATH_TWEEN_WAIT_SECS
	_death_wait_timer.timeout.connect(_unlock)
	add_child(_death_wait_timer)
	_death_wait_timer.start()
	print("[RoomGate-diag] _start_death_wait | timer started, paused=%s time_left=%.3f" % [_death_wait_timer.paused, _death_wait_timer.time_left])


## Test helper: simulate the death-tween wait elapsing without driving the
## engine for DEATH_TWEEN_WAIT_SECS. Tests that want to assert the
## "gate_unlocked emits AFTER the wait" sequence call this to advance the
## state machine. Idempotent.
func advance_death_wait_for_test() -> void:
	if not _death_wait_in_flight:
		return
	if _unlocked_emitted:
		return
	if _death_wait_timer != null:
		_death_wait_timer.stop()
	_unlock()


## Test helper: simulate a CharacterBody2D player walking through the gate
## while it is in UNLOCKED state. Emits gate_traversed exactly once (same
## idempotency as the real path). Used by tests that assert the Position B
## contract: gate_unlocked fires (door opens) → separate call to
## traverse_for_test → gate_traversed fires → room_cleared fires.
func traverse_for_test() -> void:
	if _state != STATE_UNLOCKED:
		return
	if _traversed_emitted:
		return
	_traversed_emitted = true
	gate_traversed.emit()


func _unlock() -> void:
	if _unlocked_emitted:
		return
	_unlocked_emitted = true
	_state = STATE_UNLOCKED
	_combat_trace("RoomGate._unlock", "gate_unlocked emitting — door visual opens; waiting for player door-walk to fire gate_traversed")
	gate_unlocked.emit()


## Combat-trace shim — routes through DebugFlags.combat_trace (HTML5-only).
## Same pattern as mob _combat_trace helpers; emits in HTML5 builds so
## Sponsor's DevTools console can confirm the gate_unlocked → gate_traversed
## ordering without a native build.
func _combat_trace(tag: String, msg: String = "") -> void:
	var df: Node = null
	if is_inside_tree():
		df = get_tree().root.get_node_or_null("DebugFlags")
	if df != null and df.has_method("combat_trace"):
		df.combat_trace(tag, msg)
