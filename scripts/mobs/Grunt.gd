class_name Grunt
extends CharacterBody2D
## Stratum-1 grunt mob — melee chaser with a low-HP heavy-attack telegraph.
##
## Decisions encoded here (Drew owns AI internals per dispatch authority):
##   - State machine: IDLE -> CHASING -> ATTACKING -> RECOVERING -> CHASING
##     and from any non-dead state, the FIRST time HP drops at-or-below 30%
##     of max, transitions to TELEGRAPHING_HEAVY (one-shot) which on its own
##     timer fires a heavy swing then returns to CHASING. The telegraph fires
##     at most once per life (avoids stunlock-loops at low HP).
##   - HP/damage/speed read from MobDef at spawn; the resource is immutable.
##   - Player detection: simple radius check — M2 will swap in a vision cone
##     and a NavigationAgent2D for proper pathing. M1 reach is ~480 px (the
##     full logical canvas width) so the grunt always tracks within a room.
##   - Hitbox spawning matches the Player's pattern: configure() then
##     add_child() so _ready() reads the right team/lifetime/layers.
##   - Layer convention (DECISIONS.md 2026-05-01): collision_layer = enemy
##     (bit 4), collision_mask = world (bit 1) + player (bit 2). Hitboxes
##     spawned by the grunt sit on enemy_hitbox (bit 5) and mask player
##     (bit 2). Player attacks live on player_hitbox (bit 3) and mask enemy
##     (bit 4) — that's how player Hitbox.gd damages us.
##   - Death: emits `mob_died` once, then queue_free at end of frame. Loot
##     rolling is wired from Stratum1Room01 / spawner code in task #10
##     (LootRoller listens to `mob_died`).
##
## Tunable timings live as constants below; balance values come from the
## MobDef. Constants are shape (timing/distance), MobDef is magnitude (HP/dmg).

# ---- Signals ------------------------------------------------------------

## State transitioned. New state on the right.
signal state_changed(from_state: StringName, to_state: StringName)

## Took damage. Emitted after HP is decremented but before death is checked.
signal damaged(amount: int, hp_remaining: int, source: Node)

## HP hit zero. Emitted exactly once per life. Carries the mob node reference,
## final position, and the MobDef so spawner / loot listeners can pull
## `xp_reward` and `loot_table` without re-resolving.
signal mob_died(mob: Grunt, death_position: Vector2, mob_def: MobDef)

## Heavy-attack telegraph started (the windup). Visual hooks listen for this
## to play the rear-back / red-glow animation per Uma's visual-direction.md.
signal heavy_telegraph_started()

## A swing hitbox spawned. `kind` = &"light" or &"heavy". Useful for tests +
## audio hooks.
signal swing_spawned(kind: StringName, hitbox: Node)

# ---- States ------------------------------------------------------------

const STATE_IDLE: StringName = &"idle"
const STATE_CHASING: StringName = &"chasing"
const STATE_ATTACKING: StringName = &"attacking"          # mid-swing recovery
const STATE_TELEGRAPHING_HEAVY: StringName = &"telegraphing_heavy"  # windup
const STATE_DEAD: StringName = &"dead"

const SWING_KIND_LIGHT: StringName = &"light"
const SWING_KIND_HEAVY: StringName = &"heavy"

# ---- Tuning (shape) ----------------------------------------------------

## How close the player needs to be before the grunt aggros / chases.
## M1 = whole-room aggro because rooms are tiny.
const AGGRO_RADIUS: float = 480.0

## How close before a contact swing fires.
const ATTACK_RANGE: float = 28.0

## How long after a swing before the grunt can act again.
const ATTACK_RECOVERY: float = 0.55

## Light-attack hitbox spec.
const LIGHT_HITBOX_REACH: float = 24.0
const LIGHT_HITBOX_RADIUS: float = 16.0
const LIGHT_HITBOX_LIFETIME: float = 0.10
const LIGHT_KNOCKBACK: float = 120.0

## Heavy-attack hitbox spec — bigger reach, more damage, longer life.
const HEAVY_HITBOX_REACH: float = 36.0
const HEAVY_HITBOX_RADIUS: float = 22.0
const HEAVY_HITBOX_LIFETIME: float = 0.18
const HEAVY_KNOCKBACK: float = 240.0
const HEAVY_DAMAGE_MULTIPLIER: float = 1.8

## Telegraph windup duration. Player has this long to dodge / get clear.
const HEAVY_TELEGRAPH_DURATION: float = 0.65

## HP fraction at-or-below which the heavy telegraph fires (one-shot).
const HEAVY_TELEGRAPH_HP_FRAC: float = 0.30

## Layer bits (mirror project.godot).
const LAYER_WORLD: int = 1 << 0          # bit 1
const LAYER_PLAYER: int = 1 << 1         # bit 2
const LAYER_ENEMY: int = 1 << 3          # bit 4

const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")

# ---- Inspector --------------------------------------------------------

## The MobDef this grunt instances. Either set in the .tscn at author time,
## or assigned by the spawner before add_child(). If left null, the grunt
## falls back to safe defaults so a bare-instantiated test node still works.
@export var mob_def: MobDef

# ---- Runtime ----------------------------------------------------------

var hp_max: int = 50
var hp_current: int = 50
var damage_base: int = 5
var move_speed: float = 60.0

var _state: StringName = STATE_IDLE
var _attack_recovery_left: float = 0.0
var _telegraph_time_left: float = 0.0
var _heavy_telegraph_fired: bool = false  # one-shot guard
var _is_dead: bool = false

## NodePath (or Node ref) to the player. Optional — spawner sets this. If
## unset, the grunt looks for the first node in the "player" group at _ready.
@export var player_node_path: NodePath
var _player: Node2D = null


func _ready() -> void:
	_apply_mob_def()
	_apply_layers()
	_resolve_player()


# ---- Public API -------------------------------------------------------

## Returns the current state. Read-only.
func get_state() -> StringName:
	return _state


func get_hp() -> int:
	return hp_current


func get_max_hp() -> int:
	return hp_max


func is_dead() -> bool:
	return _is_dead


## Heavy telegraph must fire at most once per life. Tests assert this.
func has_heavy_telegraph_fired() -> bool:
	return _heavy_telegraph_fired


## Inject the player target. Spawner uses this; tests use it for determinism.
func set_player(p: Node2D) -> void:
	_player = p


## Force-instance a MobDef after _ready (useful in tests when the node was
## constructed bare). Re-applies HP/damage/speed.
func apply_mob_def(def: MobDef) -> void:
	mob_def = def
	_apply_mob_def()


## Take damage from a hitbox. Duck-typed contract matched by `Hitbox.gd`
## (`target.take_damage(amount, knockback, source)`).
##
## - Damage during STATE_DEAD is ignored (idempotent — multi-hit collapse
##   already happens at Hitbox level, but this is belt-and-suspenders).
## - Negative amounts are clamped to 0 (no incidental healing via hitbox
##   bug; explicit healing should go through a separate API).
## - Kills the grunt and emits `mob_died` exactly once when HP hits 0.
func take_damage(amount: int, knockback: Vector2, source: Node) -> void:
	if _is_dead:
		return
	var clean_amount: int = max(0, amount)
	hp_current = max(0, hp_current - clean_amount)
	damaged.emit(clean_amount, hp_current, source)
	# Apply knockback as an instantaneous velocity bump. Decays naturally
	# next physics tick when the AI sets velocity from chase.
	if knockback.length_squared() > 0.0:
		velocity = knockback
	if hp_current == 0:
		_die()
		return
	# Maybe enter the heavy telegraph (one-shot).
	_maybe_start_heavy_telegraph()


# ---- Physics tick -----------------------------------------------------

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_tick_timers(delta)

	match _state:
		STATE_IDLE, STATE_CHASING:
			_process_chase(delta)
		STATE_ATTACKING:
			_process_recover(delta)
		STATE_TELEGRAPHING_HEAVY:
			_process_telegraph(delta)
		STATE_DEAD:
			pass

	move_and_slide()


# ---- State handlers ---------------------------------------------------

func _process_chase(_delta: float) -> void:
	if _player == null:
		velocity = Vector2.ZERO
		_set_state(STATE_IDLE)
		return
	var to_player: Vector2 = _player.global_position - global_position
	var dist: float = to_player.length()
	if dist < 0.0001:
		velocity = Vector2.ZERO
		return
	if dist <= ATTACK_RANGE:
		# In melee range — swing.
		_swing_light(to_player.normalized())
		return
	if dist > AGGRO_RADIUS:
		velocity = Vector2.ZERO
		_set_state(STATE_IDLE)
		return
	# Steer toward player.
	velocity = to_player.normalized() * move_speed
	_set_state(STATE_CHASING)


func _process_recover(_delta: float) -> void:
	# Held in place while recovering, but knockback can still slide us.
	if _attack_recovery_left <= 0.0:
		_set_state(STATE_CHASING)


func _process_telegraph(_delta: float) -> void:
	# During telegraph the grunt is rooted (player can dodge / step out).
	velocity = Vector2.ZERO
	if _telegraph_time_left <= 0.0:
		_finish_heavy_telegraph()


# ---- Swings -----------------------------------------------------------

func _swing_light(dir: Vector2) -> void:
	var hb: Hitbox = _spawn_hitbox(
		dir,
		damage_base,
		dir * LIGHT_KNOCKBACK,
		LIGHT_HITBOX_REACH,
		LIGHT_HITBOX_RADIUS,
		LIGHT_HITBOX_LIFETIME,
	)
	_attack_recovery_left = ATTACK_RECOVERY
	_set_state(STATE_ATTACKING)
	swing_spawned.emit(SWING_KIND_LIGHT, hb)


func _swing_heavy(dir: Vector2) -> void:
	var heavy_dmg: int = int(round(damage_base * HEAVY_DAMAGE_MULTIPLIER))
	var hb: Hitbox = _spawn_hitbox(
		dir,
		heavy_dmg,
		dir * HEAVY_KNOCKBACK,
		HEAVY_HITBOX_REACH,
		HEAVY_HITBOX_RADIUS,
		HEAVY_HITBOX_LIFETIME,
	)
	_attack_recovery_left = ATTACK_RECOVERY
	_set_state(STATE_ATTACKING)
	swing_spawned.emit(SWING_KIND_HEAVY, hb)


func _spawn_hitbox(
	dir: Vector2,
	dmg: int,
	knockback: Vector2,
	reach: float,
	radius: float,
	lifetime: float
) -> Hitbox:
	var hb: Hitbox = HitboxScript.new()
	hb.configure(dmg, knockback, lifetime, Hitbox.TEAM_ENEMY, self)
	hb.position = dir * reach
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	hb.add_child(shape)
	add_child(hb)
	return hb


# ---- Heavy telegraph --------------------------------------------------

func _maybe_start_heavy_telegraph() -> void:
	if _heavy_telegraph_fired:
		return
	if _is_dead:
		return
	if _state == STATE_TELEGRAPHING_HEAVY:
		return
	if hp_current <= 0:
		return
	if hp_current > int(ceil(hp_max * HEAVY_TELEGRAPH_HP_FRAC)):
		return
	_heavy_telegraph_fired = true
	_telegraph_time_left = HEAVY_TELEGRAPH_DURATION
	_set_state(STATE_TELEGRAPHING_HEAVY)
	heavy_telegraph_started.emit()


func _finish_heavy_telegraph() -> void:
	# Direction at swing time (player may have moved during windup).
	var dir: Vector2 = Vector2.RIGHT
	if _player != null:
		var to_player: Vector2 = _player.global_position - global_position
		if to_player.length_squared() > 0.0:
			dir = to_player.normalized()
	_swing_heavy(dir)


# ---- Death ------------------------------------------------------------

func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	# Cancel any pending action timers so a death-during-telegraph doesn't
	# pop a heavy swing on a corpse.
	_telegraph_time_left = 0.0
	_attack_recovery_left = 0.0
	velocity = Vector2.ZERO
	_set_state(STATE_DEAD)
	mob_died.emit(self, global_position, mob_def)
	# Defer free so any signal listeners running inside the same tick can
	# read state before the node is gone.
	call_deferred("queue_free")


# ---- Helpers ----------------------------------------------------------

func _tick_timers(delta: float) -> void:
	if _attack_recovery_left > 0.0:
		_attack_recovery_left = max(0.0, _attack_recovery_left - delta)
	if _telegraph_time_left > 0.0:
		_telegraph_time_left = max(0.0, _telegraph_time_left - delta)


func _set_state(new_state: StringName) -> void:
	if new_state == _state:
		return
	var old: StringName = _state
	_state = new_state
	state_changed.emit(old, new_state)


func _apply_mob_def() -> void:
	if mob_def == null:
		# Bare-instantiated grunt (tests). Use schema defaults already on
		# this node's vars.
		hp_max = 50
		hp_current = 50
		damage_base = 5
		move_speed = 60.0
		return
	hp_max = mob_def.hp_base
	hp_current = mob_def.hp_base
	damage_base = mob_def.damage_base
	move_speed = mob_def.move_speed


func _apply_layers() -> void:
	# Bare-instantiated CharacterBody2D defaults to collision_layer = 1
	# (world) and collision_mask = 1 (world). Authored .tscn nodes carry
	# the right values already (layer 8 = enemy bit 4, mask 3 = world+player).
	# We detect the bare-default state and fix it up so tests that construct
	# a Grunt via `Grunt.new()` end up on the enemy layer just like a
	# scene-loaded grunt.
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
	# Fallback: first node in "player" group.
	var players: Array[Node] = get_tree().get_nodes_in_group("player") if is_inside_tree() else []
	if players.size() > 0 and players[0] is Node2D:
		_player = players[0]
