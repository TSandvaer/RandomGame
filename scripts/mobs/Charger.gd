class_name Charger
extends CharacterBody2D
## Stratum-1 charger mob — telegraphed straight-line dash with a vulnerable
## recovery window. Adds variety to combat by punishing players who try to
## stand-and-fight: the charger forces the player to move, then exposes itself
## briefly after each charge.
##
## Decisions encoded here (Drew owns AI internals per dispatch authority):
##   - State machine: IDLE -> SPOTTED -> TELEGRAPHING -> CHARGING -> RECOVERING
##                    -> SPOTTED (loop) and from any non-dead state, DEAD on hp 0.
##   - SPOTTED is the "decision" state — picks a charge direction toward the
##     player, then begins the windup. Distinct from IDLE so animation hooks
##     can tell "I see you" from "I'm about to charge."
##   - Charge direction is locked at telegraph start. Player can dodge by
##     stepping out of the line during windup OR by dodging through it.
##     Charge is NOT homing — straight line, full duration or wall-stop.
##   - Charge stops on (a) wall collision (move_and_slide rejected motion),
##     (b) player contact (single-hit hitbox spawned, transitions to recover),
##     or (c) max-distance reached.
##   - RECOVERING is the vulnerability window: charger takes 2x damage. In
##     other states the charger has armored "hide" and takes 1x damage. This
##     turns "kite the charge, hit during recovery" into the dominant strategy
##     and makes the spec's "Take damage during recovery state" meaningful.
##     (Damage is never zeroed — the charger is always hittable, just less
##     rewarding outside the window.)
##   - HP/damage/speed read from MobDef at spawn. Move-speed in MobDef is
##     used as the *charge* speed; idle drift is zero (chargers don't pace
##     in M1). Spec: 1.5x player base move speed during dash — so MobDef
##     ships move_speed = 180 (Player.WALK_SPEED 120 * 1.5).
##   - Layer convention (DECISIONS.md 2026-05-01): collision_layer = enemy
##     (bit 4), collision_mask = world (bit 1) + player (bit 2). Hitboxes
##     spawned by the charger sit on enemy_hitbox (bit 5) and mask player
##     (bit 2). Same as Grunt.
##   - Death: emits `mob_died` once with (mob, position, mob_def) — same
##     contract as Grunt so MobLootSpawner.on_mob_died works without changes.
##   - Death-mid-charge: velocity zeroed immediately, no recovery state, no
##     orphan motion. Spec edge case.
##
## Tunable timings live as constants below; balance values come from MobDef.
## Constants are shape (timing/distance), MobDef is magnitude (HP/dmg/speed).

# ---- Signals ------------------------------------------------------------

## State transitioned. New state on the right.
signal state_changed(from_state: StringName, to_state: StringName)

## Took damage. Emitted after HP is decremented but before death is checked.
## `final_amount` is the damage actually applied after the vulnerability
## multiplier; `raw_amount` is what was passed into take_damage.
signal damaged(final_amount: int, hp_remaining: int, source: Node)

## HP hit zero. Emitted exactly once per life. Same payload shape as Grunt
## so MobLootSpawner / progression listeners are reusable.
signal mob_died(mob: Charger, death_position: Vector2, mob_def: MobDef)

## Charge windup started — visual hooks listen for this to play the
## eyes-glow / ground-streak telegraph per Uma's visual-direction.md.
signal charge_telegraph_started(charge_dir: Vector2)

## Charge body-hitbox spawned (charger ran into the player). Carries the
## hitbox node so tests + audio hooks can react.
signal charge_hit_spawned(hitbox: Node)

# ---- States ------------------------------------------------------------

const STATE_IDLE: StringName = &"idle"
const STATE_SPOTTED: StringName = &"spotted"
const STATE_TELEGRAPHING: StringName = &"telegraphing"
const STATE_CHARGING: StringName = &"charging"
const STATE_RECOVERING: StringName = &"recovering"
const STATE_DEAD: StringName = &"dead"

# ---- Tuning (shape) ----------------------------------------------------

## Aggro radius — same M1 reach as the grunt so a charger always engages
## within a stratum-1 room.
const AGGRO_RADIUS: float = 480.0

## Telegraph windup duration. Player has this long to dodge / get clear
## before the charge fires. Slightly longer than the grunt's heavy
## telegraph because dodging a charge is more about repositioning.
const TELEGRAPH_DURATION: float = 0.55

## Max charge time before the charger gives up and recovers. A wall stop
## or player hit cuts this short.
const CHARGE_MAX_DURATION: float = 0.85

## Recovery (vulnerability) window. Long enough for a player light + heavy
## combo. Spec calls this out as the easy-damage window.
const RECOVERY_DURATION: float = 0.85

## Brief "I saw you" pause before the telegraph. Makes the SPOTTED state
## visible to the player — anti-cheese against instant turnaround.
const SPOTTED_HOLD: float = 0.15

## Damage multiplier applied in RECOVERING vs every other state. Outside
## of recovery the charger is armored (1.0x); during recovery it takes 2x.
const RECOVERY_DAMAGE_MULTIPLIER: float = 2.0
const ARMORED_DAMAGE_MULTIPLIER: float = 1.0

## Charge contact hitbox spec.
const CHARGE_HITBOX_RADIUS: float = 20.0
const CHARGE_HITBOX_LIFETIME: float = 0.10
const CHARGE_KNOCKBACK: float = 280.0
## Distance ahead of the charger the contact-hitbox spawns at when it lands
## on the player. Just enough to register the overlap.
const CHARGE_HITBOX_REACH: float = 12.0

## When charge motion is rejected this many frames in a row, treat it as a
## wall hit and stop. move_and_slide reports `get_real_velocity()` close to
## zero when stuck; we measure post-slide displacement instead.
const WALL_STOP_DISPLACEMENT_EPSILON: float = 0.5

## Layer bits (mirror project.godot — same as Grunt).
const LAYER_WORLD: int = 1 << 0          # bit 1
const LAYER_PLAYER: int = 1 << 1         # bit 2
const LAYER_ENEMY: int = 1 << 3          # bit 4

const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")

# ---- Inspector --------------------------------------------------------

## The MobDef this charger instances. Spawner sets it before add_child(),
## or set in the .tscn at author time. If null, safe defaults apply so a
## bare-instantiated test node works.
@export var mob_def: MobDef

## NodePath (or assigned via set_player). Resolved in _ready from group
## "player" if neither is set.
@export var player_node_path: NodePath

# ---- Runtime ----------------------------------------------------------

var hp_max: int = 70
var hp_current: int = 70
var damage_base: int = 8
var charge_speed: float = 180.0  # 1.5x player WALK_SPEED (120) per spec

var _state: StringName = STATE_IDLE
var _spotted_hold_left: float = 0.0
var _telegraph_left: float = 0.0
var _charge_time_left: float = 0.0
var _recovery_left: float = 0.0
var _charge_dir: Vector2 = Vector2.RIGHT
var _is_dead: bool = false
var _last_position: Vector2 = Vector2.ZERO
var _player: Node2D = null

# Tracks which targets the current charge has already body-hit so a single
# charge can't multi-tick the player. Reset at the start of each charge.
var _charge_already_hit: Array[Node] = []


func _ready() -> void:
	_apply_mob_def()
	_apply_layers()
	_resolve_player()
	_last_position = global_position


# ---- Public API -------------------------------------------------------

func get_state() -> StringName:
	return _state


func get_hp() -> int:
	return hp_current


func get_max_hp() -> int:
	return hp_max


func is_dead() -> bool:
	return _is_dead


## Direction the charger is currently locked into for the active charge.
## Stable from telegraph start through charge end.
func get_charge_dir() -> Vector2:
	return _charge_dir


## True only during STATE_RECOVERING — the spec's "vulnerable" window.
## Useful for VFX hooks and the test suite.
func is_vulnerable() -> bool:
	return _state == STATE_RECOVERING


## Inject the player target. Spawner uses this; tests use it for determinism.
func set_player(p: Node2D) -> void:
	_player = p


## Force-apply a MobDef post-_ready (test convenience).
func apply_mob_def(def: MobDef) -> void:
	mob_def = def
	_apply_mob_def()


## Take damage from a hitbox. Duck-typed contract matched by Hitbox.gd
## (`target.take_damage(amount, knockback, source)`).
##
##   - Damage during STATE_DEAD is ignored (idempotent).
##   - Negative amounts are clamped to 0.
##   - Amount is multiplied by ARMORED_DAMAGE_MULTIPLIER outside recovery
##     and RECOVERY_DAMAGE_MULTIPLIER during STATE_RECOVERING.
##   - Knockback is applied as instantaneous velocity bump only when the
##     charger is NOT mid-charge — a charging charger plows through it.
##     This keeps the dash predictable for the player.
##   - mob_died emits exactly once on the death-transition.
func take_damage(amount: int, knockback: Vector2, source: Node) -> void:
	if _is_dead:
		return
	var clean_amount: int = max(0, amount)
	var multiplier: float = RECOVERY_DAMAGE_MULTIPLIER if _state == STATE_RECOVERING else ARMORED_DAMAGE_MULTIPLIER
	var final_amount: int = int(round(clean_amount * multiplier))
	hp_current = max(0, hp_current - final_amount)
	damaged.emit(final_amount, hp_current, source)
	# Skip knockback during charge — a dashing charger's momentum is
	# load-bearing; punting it sideways breaks the silhouette of the attack.
	if _state != STATE_CHARGING and knockback.length_squared() > 0.0:
		velocity = knockback
	if hp_current == 0:
		_die()


# ---- Physics tick -----------------------------------------------------

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_tick_timers(delta)

	match _state:
		STATE_IDLE:
			_process_idle(delta)
		STATE_SPOTTED:
			_process_spotted(delta)
		STATE_TELEGRAPHING:
			_process_telegraph(delta)
		STATE_CHARGING:
			_process_charge(delta)
		STATE_RECOVERING:
			_process_recover(delta)
		STATE_DEAD:
			pass

	var pre: Vector2 = global_position
	move_and_slide()
	# After the slide, check for wall stop during charge. We do this AFTER
	# move_and_slide so wall geometry is already resolved.
	if _state == STATE_CHARGING:
		var moved: float = (global_position - pre).length()
		if moved < WALL_STOP_DISPLACEMENT_EPSILON:
			_end_charge_into_wall()
	_last_position = global_position


# ---- State handlers ---------------------------------------------------

func _process_idle(_delta: float) -> void:
	velocity = Vector2.ZERO
	if _player == null:
		return
	var to_player: Vector2 = _player.global_position - global_position
	if to_player.length() <= AGGRO_RADIUS:
		_enter_spotted()


func _process_spotted(_delta: float) -> void:
	# Brief hold so the player sees us "lock on" before the windup.
	velocity = Vector2.ZERO
	if _spotted_hold_left <= 0.0:
		_enter_telegraph()


func _process_telegraph(_delta: float) -> void:
	# Rooted during windup so player can dodge / step out.
	velocity = Vector2.ZERO
	if _telegraph_left <= 0.0:
		_begin_charge()


func _process_charge(_delta: float) -> void:
	# Locked direction, full charge speed.
	velocity = _charge_dir * charge_speed
	# Player-contact check via cheap distance (mirror the grunt's reach
	# pattern — physics-collision routing handles the canonical case in
	# scene play; this is a deterministic test-friendly fallback).
	_maybe_charge_hit_player()
	if _charge_time_left <= 0.0:
		_enter_recovery()


func _process_recover(_delta: float) -> void:
	velocity = Vector2.ZERO
	if _recovery_left <= 0.0:
		# Decide what's next: re-engage if player's still in range, else idle.
		if _player == null:
			_set_state(STATE_IDLE)
			return
		var to_player: Vector2 = _player.global_position - global_position
		if to_player.length() <= AGGRO_RADIUS:
			_enter_spotted()
		else:
			_set_state(STATE_IDLE)


# ---- State entry helpers ---------------------------------------------

func _enter_spotted() -> void:
	_spotted_hold_left = SPOTTED_HOLD
	_set_state(STATE_SPOTTED)


func _enter_telegraph() -> void:
	# Lock charge direction toward the player at telegraph start. Once locked,
	# moving the player out of the line dodges the charge.
	if _player != null:
		var to_player: Vector2 = _player.global_position - global_position
		if to_player.length_squared() > 0.0:
			_charge_dir = to_player.normalized()
	_telegraph_left = TELEGRAPH_DURATION
	_set_state(STATE_TELEGRAPHING)
	charge_telegraph_started.emit(_charge_dir)


func _begin_charge() -> void:
	_charge_time_left = CHARGE_MAX_DURATION
	_charge_already_hit.clear()
	_set_state(STATE_CHARGING)


func _enter_recovery() -> void:
	velocity = Vector2.ZERO
	_recovery_left = RECOVERY_DURATION
	_set_state(STATE_RECOVERING)


func _end_charge_into_wall() -> void:
	# Wall hit: stop cleanly, transition to recovery. No corpse-sliding,
	# no continued motion. Spec edge probe.
	velocity = Vector2.ZERO
	_charge_time_left = 0.0
	_enter_recovery()


# ---- Charge body-contact ---------------------------------------------

func _maybe_charge_hit_player() -> void:
	if _player == null:
		return
	if _player in _charge_already_hit:
		return
	var dist: float = (_player.global_position - global_position).length()
	# Body-hitbox is roughly the charger's radius + small reach. Use the
	# same scale as the contact hitbox we'd spawn.
	if dist > CHARGE_HITBOX_RADIUS + CHARGE_HITBOX_REACH:
		return
	# Spawn the contact hitbox and stop charge.
	var hb: Hitbox = _spawn_charge_hitbox()
	_charge_already_hit.append(_player)
	charge_hit_spawned.emit(hb)
	# End the charge — wall or hit, same outcome: transition to recovery.
	_charge_time_left = 0.0
	_enter_recovery()


func _spawn_charge_hitbox() -> Hitbox:
	var hb: Hitbox = HitboxScript.new()
	hb.configure(damage_base, _charge_dir * CHARGE_KNOCKBACK, CHARGE_HITBOX_LIFETIME, Hitbox.TEAM_ENEMY, self)
	hb.position = _charge_dir * CHARGE_HITBOX_REACH
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = CHARGE_HITBOX_RADIUS
	shape.shape = circle
	hb.add_child(shape)
	add_child(hb)
	return hb


# ---- Death ------------------------------------------------------------

func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	# Cancel every pending action so a death-during-charge doesn't slide the
	# corpse forward, and so a death-during-telegraph doesn't fire the
	# charge from a dead body. Spec edge probe.
	_telegraph_left = 0.0
	_charge_time_left = 0.0
	_recovery_left = 0.0
	_spotted_hold_left = 0.0
	velocity = Vector2.ZERO
	_set_state(STATE_DEAD)
	mob_died.emit(self, global_position, mob_def)
	# Defer free so any signal listeners running this tick still see state.
	call_deferred("queue_free")


# ---- Helpers ----------------------------------------------------------

func _tick_timers(delta: float) -> void:
	if _spotted_hold_left > 0.0:
		_spotted_hold_left = max(0.0, _spotted_hold_left - delta)
	if _telegraph_left > 0.0:
		_telegraph_left = max(0.0, _telegraph_left - delta)
	if _charge_time_left > 0.0:
		_charge_time_left = max(0.0, _charge_time_left - delta)
	if _recovery_left > 0.0:
		_recovery_left = max(0.0, _recovery_left - delta)


func _set_state(new_state: StringName) -> void:
	if new_state == _state:
		return
	var old: StringName = _state
	_state = new_state
	state_changed.emit(old, new_state)


func _apply_mob_def() -> void:
	if mob_def == null:
		# Bare-instantiated charger (tests). Use spec defaults.
		hp_max = 70
		hp_current = 70
		damage_base = 8
		charge_speed = 180.0
		return
	hp_max = mob_def.hp_base
	hp_current = mob_def.hp_base
	damage_base = mob_def.damage_base
	charge_speed = mob_def.move_speed


func _apply_layers() -> void:
	# Same layer-fix-up pattern as Grunt: bare-instantiated CharacterBody2D
	# defaults to layer 1 / mask 1; we override to enemy / world+player so
	# Grunt.new() and Charger.new() in tests behave the same as scene-loaded.
	const BARE_DEFAULT_LAYER: int = 1
	if collision_layer == 0 or collision_layer == BARE_DEFAULT_LAYER:
		collision_layer = LAYER_ENEMY
	if collision_mask == 0 or collision_mask == BARE_DEFAULT_LAYER:
		collision_mask = LAYER_WORLD | LAYER_PLAYER


func _resolve_player() -> void:
	if _player != null:
		return
	if not player_node_path.is_empty():
		var n: Node = get_node_or_null(player_node_path)
		if n is Node2D:
			_player = n
			return
	var players: Array[Node] = get_tree().get_nodes_in_group("player") if is_inside_tree() else []
	if players.size() > 0 and players[0] is Node2D:
		_player = players[0]
