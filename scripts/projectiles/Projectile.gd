class_name Projectile
extends Area2D
## Generic projectile — straight-line travel with a finite lifetime, single
## damage payload, and team-routed collision layers. Owned by the firing
## mob (or, in M2, by the player when ranged weapons land); for M1 only the
## Shooter mob uses it.
##
## Decisions encoded here (Drew owns projectile physics per dispatch authority):
##   - Area2D + manual `position += velocity * delta` (we don't need
##     CharacterBody2D's collision response — projectiles don't slide along
##     walls, they vanish on contact). Simpler than RigidBody2D, deterministic
##     under physics-tick-driven tests.
##   - Lifetime is in seconds. When it expires the node queue_frees. Tests
##     assert this so the M1 scene can't fill with stale projectiles.
##   - Team-routed layers mirror Hitbox.gd convention (DECISIONS.md
##     2026-05-01 + Devon's physics-layer decision):
##       team = enemy:  layer = enemy_hitbox (bit 5), mask = player (bit 2)
##                      AND world (bit 1) so projectiles vanish on walls.
##       team = player: layer = player_hitbox (bit 3), mask = enemy (bit 4)
##                      AND world (bit 1).
##     Projectiles do NOT collide with other projectiles or other enemies
##     (M1 keeps the matrix small). Note: this is layer separation per
##     Devon's physics-layer decision — same convention as Hitbox.
##   - Single-hit: a projectile applies damage to at most ONE target then
##     queue_frees. Mirrors a thrown spear, not a piercing arrow. Pierce
##     mechanics are M2.
##   - Self-source skip: like Hitbox, the firing source is never hit. Useful
##     when ranged player attacks land in M2 and the player runs through
##     their own projectile.

signal hit_target(target: Node, damage: int, source: Node)
## Projectile expired without hitting anyone. Useful for tests + audio.
signal expired()

# ---- Tuning -----------------------------------------------------------

const TEAM_PLAYER: StringName = &"player"
const TEAM_ENEMY: StringName = &"enemy"

# Layer bits — keep in sync with project.godot 2d_physics layers (and Hitbox).
const LAYER_WORLD: int = 1 << 0             # bit 1
const LAYER_PLAYER: int = 1 << 1            # bit 2
const LAYER_PLAYER_HITBOX: int = 1 << 2     # bit 3
const LAYER_ENEMY: int = 1 << 3             # bit 4
const LAYER_ENEMY_HITBOX: int = 1 << 4      # bit 5

# ---- Configuration (set via configure() before add_child) -------------

@export var damage: int = 6
## Velocity vector — direction × speed. Spec: speed slower than player run
## speed (player walks 120, sprints 192) so player can dodge.
@export var velocity_vec: Vector2 = Vector2.ZERO
@export var lifetime: float = 1.5
@export var team: StringName = TEAM_ENEMY
@export var knockback_strength: float = 60.0

# ---- Runtime ----------------------------------------------------------

var _life_left: float = 0.0
var _hit_already: Array[Node] = []
var _source: Node = null
var _expired_already: bool = false


func _init() -> void:
	# Physics-flush safety (run-002 P0 wave 2, ticket 86c9nx1dx — Sponsor's
	# `embergrave-html5-fcbe466` retest, sustained-spam panic).
	#
	# Projectile is an Area2D. `Shooter._spawn_projectile` runs inside
	# `_physics_process` (via `_process_firing`), so the projectile's
	# add_child can land while the engine is mid-flush of a prior tick's
	# body_entered queue — the same Godot 4 forbidden mutation as the
	# Hitbox spawn-path panic. Symptom:
	#
	#     USER ERROR: Can't change this state while flushing queries.
	#
	# Fix: enter the tree with monitoring/monitorable OFF; flip them back
	# on inside the deferred `_activate_monitoring` call from `_ready`,
	# which lands after the flush completes. Identical pattern to
	# `Hitbox.gd::_init` — see Hitbox for the full rationale.
	#
	# Pairs with PR #142's death-path Area2D-add defers and the wave-2
	# Hitbox fix in this same PR.
	monitoring = false
	monitorable = false


func _ready() -> void:
	_life_left = lifetime
	_apply_team_layers()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	# Re-enable monitoring after the physics flush. See `_init` for context.
	call_deferred("_activate_monitoring")


## Turns monitoring/monitorable back on after the spawn-tick physics flush
## has completed. Guarded by `is_inside_tree` because a projectile that
## expires (or is freed by tests) before this lands must not crash.
func _activate_monitoring() -> void:
	if not is_inside_tree():
		return
	if _expired_already:
		return
	monitoring = true
	monitorable = true


func _physics_process(delta: float) -> void:
	if _expired_already:
		return
	# Manual translation — Area2D doesn't move itself.
	position += velocity_vec * delta
	_life_left -= delta
	if _life_left <= 0.0:
		_expire()


# ---- Configuration API used by spawners -------------------------------

## Configure in one call. Call before add_child() so `_ready` reads the
## right team/lifetime/layer values.
func configure(p_damage: int, p_velocity: Vector2, p_lifetime: float, p_team: StringName, p_source: Node, p_knockback: float = 60.0) -> void:
	damage = p_damage
	velocity_vec = p_velocity
	lifetime = p_lifetime
	team = p_team
	_source = p_source
	knockback_strength = p_knockback


## True if this projectile has already damaged `target`. Single-hit only.
func has_already_hit(target: Node) -> bool:
	return target in _hit_already


# ---- Layer wiring -----------------------------------------------------

func _apply_team_layers() -> void:
	collision_layer = 0
	collision_mask = 0
	if team == TEAM_PLAYER:
		collision_layer = LAYER_PLAYER_HITBOX
		# Hits enemies AND vanishes on world geometry.
		collision_mask = LAYER_ENEMY | LAYER_WORLD
	elif team == TEAM_ENEMY:
		collision_layer = LAYER_ENEMY_HITBOX
		# Hits player AND vanishes on world geometry.
		collision_mask = LAYER_PLAYER | LAYER_WORLD
	else:
		push_warning("Projectile: unknown team '%s' — collision masks left empty" % team)


# ---- Hit handling -----------------------------------------------------

func _on_body_entered(body: Node) -> void:
	# Body could be world geometry (StaticBody / TileMap) — vanish without
	# damage. The mask already filtered to wall-bearing layers + opposing
	# team's character layer, so any body_entered means "absorbed."
	_try_apply_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_try_apply_hit(area)


func _try_apply_hit(target: Node) -> void:
	if _expired_already:
		return
	if target == _source:
		return  # never self-hit
	if target in _hit_already:
		return
	_hit_already.append(target)
	# Damage call is duck-typed — Player.gd / mob scripts must expose
	# `take_damage(amount, knockback, source)`. Targets without that
	# method (e.g., walls) just absorb the projectile.
	if target.has_method("take_damage"):
		var kb_vec: Vector2 = velocity_vec.normalized() * knockback_strength
		target.take_damage(damage, kb_vec, _source)
		hit_target.emit(target, damage, _source)
	# Single-hit by design — vanish on any contact (target or wall).
	_expire()


# ---- Expiry -----------------------------------------------------------

func _expire() -> void:
	if _expired_already:
		return
	_expired_already = true
	expired.emit()
	queue_free()
