class_name Player
extends CharacterBody2D
## The Ember-Knight. Top-down 8-directional movement, sprint, and an
## invulnerable dodge-roll. State-machine driven so attack states can
## later inherit the same exclusivity guarantees.
##
## Decisions encoded here:
##   - Walk speed 120 px/s; sprint multiplier 1.6×; dodge speed 360 px/s.
##   - Dodge duration 0.30s; i-frame window covers the whole dodge.
##   - Dodge cooldown 0.45s, measured from dodge start (so total lockout
##     after dodge end = 0.15s — matches Hades-feel tuning).
##   - During dodge i-frames the player's collision_layer is cleared so
##     enemy hitboxes (mask: layer 2) miss. World collision (layer 1) still
##     blocks via collision_mask, so you can't dodge through walls.
##   - Sprint costs no resource in M1; a stamina meter is parked for M2.

# ---- Signals ------------------------------------------------------------

## Emitted when the state machine transitions. Useful for animation hooks
## and tests. New state name on the right.
signal state_changed(from_state: StringName, to_state: StringName)

## Emitted at the start of an i-frame window (fired by dodge). Hitbox
## scripts listen to this to drop their owner from damage tables.
signal iframes_started()
signal iframes_ended()

# ---- Tuning constants ---------------------------------------------------

const STATE_IDLE: StringName = &"idle"
const STATE_WALK: StringName = &"walk"
const STATE_DODGE: StringName = &"dodge"

const WALK_SPEED: float = 120.0
const SPRINT_MULTIPLIER: float = 1.6
const DODGE_SPEED: float = 360.0
const DODGE_DURATION: float = 0.30
const DODGE_COOLDOWN: float = 0.45  # measured from dodge START

# ---- Runtime state ------------------------------------------------------

var _state: StringName = STATE_IDLE
var _facing: Vector2 = Vector2.DOWN

# Dodge bookkeeping
var _dodge_time_left: float = 0.0
var _dodge_cooldown_left: float = 0.0
var _dodge_dir: Vector2 = Vector2.ZERO
var _is_invulnerable: bool = false

# Collision layer to restore after dodge i-frames clear it.
const PLAYER_LAYER_BIT: int = 2  # see project.godot 2d_physics/layer_2 = "player"
var _saved_collision_layer: int = 0


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


## Get the unit vector the player is facing. Used by attack spawners.
func get_facing() -> Vector2:
	return _facing


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
func try_dodge(dir: Vector2) -> bool:
	if not can_dodge():
		return false
	var d: Vector2 = dir.normalized() if dir.length_squared() > 0.0 else _facing
	_dodge_dir = d
	_facing = d
	_dodge_time_left = DODGE_DURATION
	_dodge_cooldown_left = DODGE_COOLDOWN
	_enter_iframes()
	set_state(STATE_DODGE)
	return true


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


func _process_dodge(_delta: float) -> void:
	velocity = _dodge_dir * DODGE_SPEED
	if _dodge_time_left <= 0.0:
		_exit_dodge()


func _tick_timers(delta: float) -> void:
	if _dodge_time_left > 0.0:
		_dodge_time_left = max(0.0, _dodge_time_left - delta)
	if _dodge_cooldown_left > 0.0:
		_dodge_cooldown_left = max(0.0, _dodge_cooldown_left - delta)


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


# ---- Input --------------------------------------------------------------

func _read_movement_input() -> Vector2:
	# Input.get_vector handles 8-direction normalisation cleanly.
	var v: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# get_vector already normalises diagonals to length 1.0, so the player
	# doesn't move √2× faster diagonally. Belt-and-suspenders:
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v
