class_name Player
extends CharacterBody2D
## The Ember-Knight. Top-down 8-directional movement, sprint, an
## invulnerable dodge-roll, and light/heavy melee attacks.
## State-machine driven so attack and dodge states can't interleave.
##
## Decisions encoded here:
##   - Walk speed 120 px/s; sprint multiplier 1.6x; dodge speed 360 px/s.
##   - Dodge duration 0.30s; i-frame window covers the whole dodge.
##   - Dodge cooldown 0.45s, measured from dodge start (so total lockout
##     after dodge end = 0.15s — matches Hades-feel tuning).
##   - During dodge i-frames the player's collision_layer is cleared so
##     enemy hitboxes (mask: layer 2) miss. World collision (layer 1) still
##     blocks via collision_mask, so you can't dodge through walls.
##   - Light attack: 0.18s recovery, 0.10s hitbox lifetime. Damage is
##     computed via Damage.compute_player_damage(equipped_weapon, edge,
##     ATTACK_LIGHT) — no flat constant. With no weapon equipped, fist =
##     1 damage flat (per Damage.FIST_DAMAGE).
##   - Heavy attack: 0.40s recovery, 0.14s hitbox lifetime. Damage is the
##     light-damage value scaled by Damage.HEAVY_MULT (1.6x final).
##   - Attacks cannot be initiated mid-dodge; dodge can interrupt attack
##     recovery (gives the player an out — Hades convention).
##   - Sprint costs no resource in M1; a stamina meter is parked for M2.
##   - Equipped weapon and Edge/Vigor stats live on this node — set by the
##     equipment system (M2 task) and the level-up allocation flow (Uma's
##     LevelUpPanel + Devon's stat-allocation work). Damage formula reads
##     them; setters fire `equipped_weapon_changed` / `stat_changed` for
##     HUD listeners.

# ---- Signals ------------------------------------------------------------

## Emitted when the state machine transitions. Useful for animation hooks
## and tests. New state name on the right.
signal state_changed(from_state: StringName, to_state: StringName)

## Emitted at the start of an i-frame window (fired by dodge). Hitbox
## scripts listen to this to drop their owner from damage tables.
signal iframes_started()
signal iframes_ended()

## Emitted whenever the player spawns an attack hitbox. Useful for VFX
## hooks and tests that want to verify an attack actually fired.
signal attack_spawned(kind: StringName, hitbox: Node)

## Emitted when the equipped weapon changes (equip / unequip). HUD listens
## to refresh the weapon-stat panel. New weapon (or null on unequip) on the
## right.
signal equipped_weapon_changed(new_weapon)

## Emitted when a character stat (Vigor / Focus / Edge) changes from level-
## up allocation. Carries the stat name and new value so the HUD can pick
## the relevant block to refresh without a full snapshot read.
signal stat_changed(stat: StringName, new_value: int)

# ---- Tuning constants ---------------------------------------------------

const STATE_IDLE: StringName = &"idle"
const STATE_WALK: StringName = &"walk"
const STATE_DODGE: StringName = &"dodge"
const STATE_ATTACK: StringName = &"attack"

const ATTACK_LIGHT: StringName = &"light"
const ATTACK_HEAVY: StringName = &"heavy"

const WALK_SPEED: float = 120.0
const SPRINT_MULTIPLIER: float = 1.6
const DODGE_SPEED: float = 360.0
const DODGE_DURATION: float = 0.30
const DODGE_COOLDOWN: float = 0.45  # measured from dodge START

# Light: short reach, fast recovery. Damage comes from Damage.gd formula
# (weapon_base + Edge + light/heavy multiplier).
const LIGHT_KNOCKBACK: float = 80.0
const LIGHT_REACH: float = 28.0
const LIGHT_HITBOX_RADIUS: float = 18.0
const LIGHT_HITBOX_LIFETIME: float = 0.10
const LIGHT_RECOVERY: float = 0.18

# Heavy: longer reach, slower recovery. Damage scaled by Damage.HEAVY_MULT.
const HEAVY_KNOCKBACK: float = 180.0
const HEAVY_REACH: float = 36.0
const HEAVY_HITBOX_RADIUS: float = 22.0
const HEAVY_HITBOX_LIFETIME: float = 0.14
const HEAVY_RECOVERY: float = 0.40

const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")
const DamageScript: Script = preload("res://scripts/combat/Damage.gd")

# ---- Runtime state ------------------------------------------------------

var _state: StringName = STATE_IDLE
var _facing: Vector2 = Vector2.DOWN

# Dodge bookkeeping
var _dodge_time_left: float = 0.0
var _dodge_cooldown_left: float = 0.0
var _dodge_dir: Vector2 = Vector2.ZERO
var _is_invulnerable: bool = false

# Attack bookkeeping
var _attack_recovery_left: float = 0.0

# Collision layer to restore after dodge i-frames clear it.
const PLAYER_LAYER_BIT: int = 2  # see project.godot 2d_physics/layer_2 = "player"
var _saved_collision_layer: int = 0

# ---- Equipment + character stats ---------------------------------------
# Read by Damage.compute_player_damage at attack time. Set by the equipment
# system (M2) and the level-up allocation flow (Uma's LevelUpPanel +
# Devon's stat-allocation work). Defaults match Save.DEFAULT_PAYLOAD —
# null weapon (fist-fights the first room), zero stat allocation.
var _equipped_weapon: ItemDef = null
var _vigor: int = 0
var _focus: int = 0
var _edge: int = 0


func _ready() -> void:
	# Seed the saved layer mask from whatever the scene authored. Tests may
	# also instantiate this node bare (no scene), in which case the default
	# CharacterBody2D.collision_layer == 1 and we explicitly set the player bit.
	if collision_layer == 0:
		collision_layer = 1 << (PLAYER_LAYER_BIT - 1)
	_saved_collision_layer = collision_layer


func _physics_process(delta: float) -> void:
	_tick_timers(delta)

	match _state:
		STATE_IDLE, STATE_WALK:
			_process_grounded(delta)
		STATE_DODGE:
			_process_dodge(delta)
		STATE_ATTACK:
			_process_attack(delta)

	move_and_slide()


# ---- Public API (used by tests, hitbox scripts, save) -------------------

## Returns the current state. Read-only — transitions go through the state
## machine.
func get_state() -> StringName:
	return _state


## True while the dodge i-frame window is active. Hitbox scripts must
## consult this before applying damage.
func is_invulnerable() -> bool:
	return _is_invulnerable


## True if a dodge can be initiated *right now* (cooldown clear, not
## already dodging). Useful for UI affordances and tests.
func can_dodge() -> bool:
	return _state != STATE_DODGE and _dodge_cooldown_left <= 0.0


## True if a new attack can fire right now: not dodging, not in attack
## recovery. Idle/walk both allow attack starts.
func can_attack() -> bool:
	return _state != STATE_DODGE and _attack_recovery_left <= 0.0


## Get the unit vector the player is facing. Used by attack spawners.
func get_facing() -> Vector2:
	return _facing


## Returns the currently-equipped weapon ItemDef, or null if unarmed.
func get_equipped_weapon() -> ItemDef:
	return _equipped_weapon


## Equip / unequip the weapon (pass null to unequip). Fires
## `equipped_weapon_changed`. M1 contract: only one weapon slot.
func set_equipped_weapon(weapon: ItemDef) -> void:
	if weapon == _equipped_weapon:
		return
	_equipped_weapon = weapon
	equipped_weapon_changed.emit(weapon)


## Edge stat — read by Damage.compute_player_damage to scale weapon damage.
func get_edge() -> int:
	return _edge


## Vigor stat — read by Damage.compute_mob_damage to mitigate incoming hits.
func get_vigor() -> int:
	return _vigor


## Focus stat — currently unused by the damage formula but tracked here so
## the level-up allocation flow has a single home for V/F/E.
func get_focus() -> int:
	return _focus


## Set Vigor / Focus / Edge to an absolute value (e.g. when restoring from
## save). Negative values clamp to 0. Fires `stat_changed` if the value
## actually changes.
func set_stat(stat: StringName, value: int) -> void:
	var clean: int = max(0, value)
	match stat:
		&"vigor":
			if _vigor == clean:
				return
			_vigor = clean
		&"focus":
			if _focus == clean:
				return
			_focus = clean
		&"edge":
			if _edge == clean:
				return
			_edge = clean
		_:
			push_warning("Player.set_stat: unknown stat '%s'" % stat)
			return
	stat_changed.emit(stat, clean)


## Public state transitioner. Tests use it; gameplay should let the
## physics process drive transitions.
func set_state(new_state: StringName) -> void:
	if new_state == _state:
		return
	var old: StringName = _state
	_state = new_state
	state_changed.emit(old, new_state)


## Force-start a dodge in a given direction. Returns true if accepted.
## `dir` is normalised internally; if it's zero, dodge fires forward.
## Dodge interrupts attack recovery (intentional — gives player an out).
func try_dodge(dir: Vector2) -> bool:
	if not can_dodge():
		return false
	# Cancel any in-flight attack recovery so the dodge feels responsive.
	_attack_recovery_left = 0.0
	var d: Vector2 = dir.normalized() if dir.length_squared() > 0.0 else _facing
	_dodge_dir = d
	_facing = d
	_dodge_time_left = DODGE_DURATION
	_dodge_cooldown_left = DODGE_COOLDOWN
	_enter_iframes()
	set_state(STATE_DODGE)
	return true


## Fire a light or heavy attack. Returns the spawned Hitbox node, or null
## if the attack was rejected (mid-dodge or in recovery). Direction is the
## intended hit direction; if zero, uses current facing.
func try_attack(kind: StringName, dir: Vector2 = Vector2.ZERO) -> Node:
	if not can_attack():
		return null
	if kind != ATTACK_LIGHT and kind != ATTACK_HEAVY:
		push_warning("Player.try_attack: unknown kind '%s'" % kind)
		return null
	var d: Vector2 = dir.normalized() if dir.length_squared() > 0.0 else _facing
	_facing = d

	# Damage routed through the formula utility. Reads equipped weapon +
	# Edge stat, returns floored int. Fist (no weapon) = 1 damage flat per
	# Damage.FIST_DAMAGE.
	var damage: int = DamageScript.compute_player_damage(_equipped_weapon, _edge, kind)
	var knockback_strength: float
	var reach: float
	var radius: float
	var lifetime: float
	var recovery: float
	if kind == ATTACK_LIGHT:
		knockback_strength = LIGHT_KNOCKBACK
		reach = LIGHT_REACH
		radius = LIGHT_HITBOX_RADIUS
		lifetime = LIGHT_HITBOX_LIFETIME
		recovery = LIGHT_RECOVERY
	else:
		knockback_strength = HEAVY_KNOCKBACK
		reach = HEAVY_REACH
		radius = HEAVY_HITBOX_RADIUS
		lifetime = HEAVY_HITBOX_LIFETIME
		recovery = HEAVY_RECOVERY

	var hitbox: Hitbox = _spawn_hitbox(d, damage, d * knockback_strength, reach, radius, lifetime)
	_attack_recovery_left = recovery
	set_state(STATE_ATTACK)
	attack_spawned.emit(kind, hitbox)
	return hitbox


# ---- State handlers -----------------------------------------------------

func _process_grounded(_delta: float) -> void:
	var input_dir: Vector2 = _read_movement_input()
	var sprinting: bool = Input.is_action_pressed("sprint")

	if input_dir.length_squared() > 0.0:
		_facing = input_dir
		var speed: float = WALK_SPEED * (SPRINT_MULTIPLIER if sprinting else 1.0)
		velocity = input_dir * speed
		set_state(STATE_WALK)
	else:
		velocity = Vector2.ZERO
		set_state(STATE_IDLE)

	if Input.is_action_just_pressed("dodge"):
		try_dodge(input_dir)
	elif Input.is_action_just_pressed("attack_light"):
		try_attack(ATTACK_LIGHT, input_dir)
	elif Input.is_action_just_pressed("attack_heavy"):
		try_attack(ATTACK_HEAVY, input_dir)


func _process_dodge(_delta: float) -> void:
	velocity = _dodge_dir * DODGE_SPEED
	if _dodge_time_left <= 0.0:
		_exit_dodge()


func _process_attack(_delta: float) -> void:
	# Player can still drift slowly during attack recovery — feels weighted
	# rather than rooted. Half walk speed.
	var input_dir: Vector2 = _read_movement_input()
	velocity = input_dir * (WALK_SPEED * 0.5)
	if _attack_recovery_left <= 0.0:
		set_state(STATE_IDLE)
	# Dodge can interrupt recovery.
	if Input.is_action_just_pressed("dodge"):
		try_dodge(input_dir)


func _tick_timers(delta: float) -> void:
	if _dodge_time_left > 0.0:
		_dodge_time_left = max(0.0, _dodge_time_left - delta)
	if _dodge_cooldown_left > 0.0:
		_dodge_cooldown_left = max(0.0, _dodge_cooldown_left - delta)
	if _attack_recovery_left > 0.0:
		_attack_recovery_left = max(0.0, _attack_recovery_left - delta)


func _exit_dodge() -> void:
	_exit_iframes()
	set_state(STATE_IDLE)


func _enter_iframes() -> void:
	_is_invulnerable = true
	_saved_collision_layer = collision_layer
	# Drop the player layer bit so enemy hitboxes (mask: layer 2) miss us.
	# World collision is on collision_mask, untouched, so walls still block.
	collision_layer = 0
	iframes_started.emit()


func _exit_iframes() -> void:
	_is_invulnerable = false
	collision_layer = _saved_collision_layer
	iframes_ended.emit()


# ---- Hitbox spawn -------------------------------------------------------

func _spawn_hitbox(dir: Vector2, damage: int, knockback: Vector2, reach: float, radius: float, lifetime: float) -> Hitbox:
	var hitbox: Hitbox = HitboxScript.new()
	# Configure BEFORE adding to tree so _ready() reads correct values.
	hitbox.configure(damage, knockback, lifetime, Hitbox.TEAM_PLAYER, self)
	hitbox.position = dir * reach
	# Attach a CircleShape2D collider via CollisionShape2D child.
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	hitbox.add_child(shape)
	add_child(hitbox)
	return hitbox


# ---- Input --------------------------------------------------------------

func _read_movement_input() -> Vector2:
	# Input.get_vector handles 8-direction normalisation cleanly.
	var v: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# get_vector already normalises diagonals to length 1.0, so the player
	# doesn't move sqrt(2)x faster diagonally. Belt-and-suspenders:
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v
