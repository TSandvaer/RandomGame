class_name Hitbox
extends Area2D
## Damage-dealing hitbox. Short-lived Area2D spawned by attacks.
## Carries a damage payload, knockback vector, and a lifetime; emits
## `hit_target` once per overlapping body it actually damages.
##
## Layer convention (locked in DECISIONS.md 2026-05-01):
##   - Player attack hitbox: collision_layer = layer 3 (player_hitbox),
##     collision_mask = layer 4 (enemy).
##   - Enemy attack hitbox: collision_layer = layer 5 (enemy_hitbox),
##     collision_mask = layer 2 (player).
##
## I-frame interaction: when a player is mid-dodge, the player's
## collision_layer is cleared (see Player.gd::_enter_iframes). Therefore
## an enemy hitbox masking layer 2 simply finds no targets — i-frames
## are enforced at the physics layer level, not by per-hit code.

signal hit_target(target: Node, damage: int, source: Node)

# ---- Tuning -------------------------------------------------------------

const TEAM_PLAYER: StringName = &"player"
const TEAM_ENEMY: StringName = &"enemy"

# Layer bits — keep in sync with project.godot 2d_physics layers.
const LAYER_PLAYER: int = 1 << 1            # bit 2 = "player"
const LAYER_PLAYER_HITBOX: int = 1 << 2     # bit 3 = "player_hitbox"
const LAYER_ENEMY: int = 1 << 3             # bit 4 = "enemy"
const LAYER_ENEMY_HITBOX: int = 1 << 4      # bit 5 = "enemy_hitbox"

# ---- Configuration (set by spawner) -------------------------------------

@export var damage: int = 1
@export var knockback: Vector2 = Vector2.ZERO
@export var lifetime: float = 0.10
@export var team: StringName = TEAM_PLAYER

# ---- Runtime ------------------------------------------------------------

var _life_left: float = 0.0
var _hit_already: Array[Node] = []
# Owner of the attack — typically the player or mob that spawned the hitbox.
# Used to skip self-hits and as the `source` argument on the hit signal.
var _source: Node = null


func _ready() -> void:
	_life_left = lifetime
	_apply_team_layers()
	# Connect Area2D body/area entered to a unified handler.
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	# Catch bodies/areas already overlapping the hitbox the moment it spawns.
	# Godot 4 Area2D quirk (regression `86c9m36zh`, M1 soak): `body_entered`
	# only fires on entry events. When the player attacks a mob that is
	# already in melee range, the hitbox spawns ALREADY overlapping the mob —
	# `body_entered` never fires and the hit silently no-ops. We defer the
	# check by one physics frame because `get_overlapping_bodies()` returns
	# empty until the engine has computed overlaps for the just-added Area2D.
	# `_try_apply_hit` is single-hit-per-target via `_hit_already`, so a
	# legitimate `body_entered` later in the lifetime won't double-hit.
	call_deferred("_check_initial_overlaps")


func _physics_process(delta: float) -> void:
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()


# ---- Configuration API used by spawners ---------------------------------

## Configure the hitbox in one call. Call before adding to the scene tree
## so `_ready` reads the right team/lifetime.
func configure(p_damage: int, p_knockback: Vector2, p_lifetime: float, p_team: StringName, p_source: Node) -> void:
	damage = p_damage
	knockback = p_knockback
	lifetime = p_lifetime
	team = p_team
	_source = p_source


## True if this hitbox has already damaged `target`. Hitboxes are
## single-hit-per-target by design (no multi-tick fountains in M1).
func has_already_hit(target: Node) -> bool:
	return target in _hit_already


# ---- Layer wiring -------------------------------------------------------

func _apply_team_layers() -> void:
	# Reset both, then set per team.
	collision_layer = 0
	collision_mask = 0
	if team == TEAM_PLAYER:
		collision_layer = LAYER_PLAYER_HITBOX
		collision_mask = LAYER_ENEMY
	elif team == TEAM_ENEMY:
		collision_layer = LAYER_ENEMY_HITBOX
		collision_mask = LAYER_PLAYER
	else:
		push_warning("Hitbox: unknown team '%s' — collision masks left empty" % team)


# ---- Hit handling -------------------------------------------------------

func _on_body_entered(body: Node) -> void:
	_try_apply_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_try_apply_hit(area)


## Sweep bodies/areas already overlapping this hitbox at spawn. Called
## via `call_deferred` from `_ready` so the engine has had a physics frame
## to populate the overlap tables. Guarded by `is_inside_tree` because a
## hitbox queue_free'd before its deferred call lands (e.g. tests that
## construct + free immediately) must not crash trying to query overlaps.
func _check_initial_overlaps() -> void:
	if not is_inside_tree():
		return
	for body in get_overlapping_bodies():
		_try_apply_hit(body)
	for area in get_overlapping_areas():
		_try_apply_hit(area)


func _try_apply_hit(target: Node) -> void:
	if target == _source:
		return  # never self-hit
	if target in _hit_already:
		return
	_hit_already.append(target)
	# The damage call is duck-typed — Drew's Mob.gd and Player.gd will
	# both expose `take_damage(amount: int, knockback: Vector2, source: Node)`.
	if target.has_method("take_damage"):
		target.take_damage(damage, knockback, _source)
	_combat_trace("Hitbox.hit",
		"team=%s target=%s damage=%d" % [team, target.name, damage])
	hit_target.emit(target, damage, _source)


## Combat-trace shim — routes through DebugFlags.combat_trace (HTML5-only).
func _combat_trace(tag: String, msg: String = "") -> void:
	var df: Node = null
	if is_inside_tree():
		df = get_tree().root.get_node_or_null("DebugFlags")
	if df != null and df.has_method("combat_trace"):
		df.combat_trace(tag, msg)
