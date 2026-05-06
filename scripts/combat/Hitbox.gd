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


func _init() -> void:
	# Physics-flush safety (run-002 P0 wave 2, ticket 86c9nx1dx — Sponsor's
	# `embergrave-html5-fcbe466` retest, ~30 rapid Player swings):
	#
	# Hitbox is an Area2D. When a hitbox is spawned during a swing whose
	# spawn site runs inside `_physics_process` (Player.try_attack +
	# every mob's `_swing_*`), and the engine is mid-flush of a prior
	# tick's body_entered queue, calling `add_child(hitbox)` mutates
	# physics-monitoring state during the flush. Godot 4 panics with:
	#
	#     USER ERROR: Can't change this state while flushing queries. Use
	#     call_deferred() or set_deferred() to change monitoring state instead.
	#
	# The panic aborts the rest of the call chain (the player's try_attack
	# returns early, the mob's swing recovery state never sets, etc.).
	#
	# Fix: enter the tree with monitoring/monitorable OFF, so add_child
	# itself does NOT touch the physics-monitoring state. We turn them
	# back on inside `_activate_and_check_initial_overlaps`, which is
	# `call_deferred`'d from `_ready` — by the time it runs, the physics
	# flush has completed and toggling monitoring is safe.
	#
	# Setting these in `_init` (not `_ready`) is load-bearing: `_ready`
	# runs DURING `add_child`, so by then the engine is already evaluating
	# the add. Properties set during `_init` are in place before the node
	# is added.
	#
	# Pairs with PR #142's MobLootSpawner / _spawn_death_particles defers
	# (death-path Area2D adds — same root cause, different sites).
	monitoring = false
	monitorable = false


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
	#
	# Wave-2 fix (ticket 86c9nx1dx): the same deferred call also flips
	# monitoring/monitorable back on. See `_init` for the panic context.
	call_deferred("_activate_and_check_initial_overlaps")


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


## Activate physics monitoring and sweep bodies/areas already overlapping
## this hitbox at spawn. Called via `call_deferred` from `_ready` so:
##   1. The engine has finished flushing prior-tick physics queries, making
##      it safe to flip `monitoring` / `monitorable` back on (run-002 P0
##      wave 2, ticket 86c9nx1dx — see `_init` for the full panic context).
##   2. `get_overlapping_bodies()` has had a physics frame to populate the
##      overlap tables for the just-added Area2D (regression 86c9m36zh —
##      pre-existing overlaps don't fire `body_entered`, hits would no-op
##      without this sweep).
##
## Guarded by `is_inside_tree` because a hitbox queue_free'd before its
## deferred call lands (e.g. tests that construct + free immediately) must
## not crash trying to query overlaps.
func _activate_and_check_initial_overlaps() -> void:
	if not is_inside_tree():
		return
	# Re-enable monitoring/monitorable now that the physics flush is over.
	# Order is load-bearing: monitoring must be true before
	# `get_overlapping_bodies` returns anything.
	monitoring = true
	monitorable = true
	for body in get_overlapping_bodies():
		_try_apply_hit(body)
	for area in get_overlapping_areas():
		_try_apply_hit(area)


## Back-compat shim — kept so any external caller (tests, future spawners)
## that explicitly invokes the previous name still works after the rename.
## Forwards to `_activate_and_check_initial_overlaps` which does the same
## sweep PLUS re-enables monitoring (the wave-2 P0 fix).
func _check_initial_overlaps() -> void:
	_activate_and_check_initial_overlaps()


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
