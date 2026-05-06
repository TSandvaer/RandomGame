class_name Shooter
extends CharacterBody2D
## Stratum-1 ranged mob — maintains distance, telegraphs and fires a slow
## projectile, kites away when the player closes. Squishier than the grunt
## (40 HP vs 50). Adds variety to combat by punishing the player who only
## brings melee tools.
##
## Decisions encoded here (Drew owns AI internals + projectile physics per
## dispatch authority):
##   - State machine: IDLE -> SPOTTED -> AIMING -> FIRING -> POST_FIRE_RECOVERY
##                    AND from any non-firing state, KITING when the player
##                    crosses the close-range threshold.
##     KITING is a transient steering state — the shooter walks away from the
##     player at base move speed; once distance is restored it drops back
##     into AIMING. KITING never blocks death or aiming-ladder progression
##     because the timers tick globally.
##   - AIMING is the projectile telegraph (windup). FIRING is a single-frame
##     spawn-the-projectile transition; we then sit in POST_FIRE_RECOVERY
##     for a beat before re-aiming. Recovery exists so the shooter can't
##     spam projectiles every frame.
##   - Distance bands: TOO_CLOSE (< KITE_RANGE) triggers KITING; SWEET_SPOT
##     (KITE_RANGE..AIM_RANGE) is "stand and shoot"; TOO_FAR (> AIM_RANGE)
##     means we walk toward the player at base speed until we hit AIM_RANGE.
##     AGGRO_RADIUS (> AIM_RANGE) is the wake-up bound.
##   - Projectile speed is intentionally slower than player walk speed so
##     a moving target can side-step. Spec calls this out explicitly.
##   - HP/damage/speed read from MobDef. MobDef.move_speed is the *kite*
##     speed (walk-while-repositioning). Projectile speed is a constant
##     here (PROJECTILE_SPEED) — different knob, different game-feel.
##   - Layer convention: identical to Grunt/Charger. The projectile carries
##     its own layer routing per Hitbox/Projectile convention.
##   - mob_died(mob, position, mob_def) — same payload as Grunt + Charger
##     so MobLootSpawner reuses without changes.
##
## Tunable timings live as constants below; balance values come from MobDef.

# ---- Signals ------------------------------------------------------------

signal state_changed(from_state: StringName, to_state: StringName)
signal damaged(amount: int, hp_remaining: int, source: Node)
signal mob_died(mob: Shooter, death_position: Vector2, mob_def: MobDef)

## Aim windup started — visual hooks listen for the telegraph anim.
signal aim_started(target_dir: Vector2)
## A projectile was spawned. Carries the projectile node for tests + audio.
signal projectile_fired(projectile: Node, dir: Vector2)

# ---- States ------------------------------------------------------------

const STATE_IDLE: StringName = &"idle"
const STATE_SPOTTED: StringName = &"spotted"
const STATE_AIMING: StringName = &"aiming"
const STATE_FIRING: StringName = &"firing"
const STATE_POST_FIRE_RECOVERY: StringName = &"post_fire_recovery"
const STATE_KITING: StringName = &"kiting"
const STATE_DEAD: StringName = &"dead"

# ---- Tuning (shape) ----------------------------------------------------

const AGGRO_RADIUS: float = 480.0
## Inside this range the shooter starts kiting away from the player.
const KITE_RANGE: float = 120.0
## Outside this range the shooter walks toward the player to close into the
## sweet spot (KITE_RANGE..AIM_RANGE).
const AIM_RANGE: float = 300.0

## Brief "I see you" pause before aiming — same UX rationale as Charger.
const SPOTTED_HOLD: float = 0.15
## Aim windup. Long enough that a paying-attention player can react.
const AIM_DURATION: float = 0.55
## Cooldown after firing before re-aiming.
const POST_FIRE_RECOVERY: float = 0.65

## Projectile speed — spec demands slower than player run speed.
## Player walks 120, sprints 120*1.6 = 192. We pick 90 px/s — even a walking
## player who side-steps clears the projectile.
const PROJECTILE_SPEED: float = 90.0
## Projectile lifetime: distance traveled = SPEED × LIFETIME = 90 × 1.6 = 144
## px, slightly past KITE_RANGE so a kited shot still threatens the player
## but doesn't fly across an entire room.
const PROJECTILE_LIFETIME: float = 1.6
const PROJECTILE_KNOCKBACK: float = 80.0

## Visual-feedback timings (per `team/uma-ux/combat-visual-feedback.md` §2 + §3).
## Same rule as Grunt/Charger — 80ms hit-flash, 200ms death-tween, 6 particles.
const HIT_FLASH_IN: float = 0.020
const HIT_FLASH_HOLD: float = 0.020
const HIT_FLASH_OUT: float = 0.040
const DEATH_TWEEN_DURATION: float = 0.200
const DEATH_PARTICLE_COUNT: int = 6
const DEATH_TARGET_SCALE: float = 0.6
const EMBER_LIGHT: Color = Color(1.0, 0.690, 0.400, 1.0)   # #FFB066
const EMBER_DEEP: Color = Color(0.627, 0.180, 0.031, 1.0)  # #A02E08

## Layer bits (mirror project.godot — same as Grunt/Charger).
const LAYER_WORLD: int = 1 << 0
const LAYER_PLAYER: int = 1 << 1
const LAYER_ENEMY: int = 1 << 3

const ProjectileScene: PackedScene = preload("res://scenes/projectiles/Projectile.tscn")
const DamageScript: Script = preload("res://scripts/combat/Damage.gd")

# ---- Inspector --------------------------------------------------------

@export var mob_def: MobDef
@export var player_node_path: NodePath

# ---- Runtime ----------------------------------------------------------

var hp_max: int = 40
var hp_current: int = 40
var damage_base: int = 6
var move_speed: float = 60.0  # kite speed (also close-the-gap speed)

var _state: StringName = STATE_IDLE
var _spotted_hold_left: float = 0.0
var _aim_left: float = 0.0
var _post_fire_recovery_left: float = 0.0
var _is_dead: bool = false
var _last_aim_dir: Vector2 = Vector2.RIGHT
var _player: Node2D = null

# Counter for projectiles fired this life — useful for tests + future
# stratum scaling (boss Shooter = same script, +volley logic later).
var _shots_fired: int = 0

# VFX runtime — see `team/uma-ux/combat-visual-feedback.md` §2 + §3.
var _hit_flash_tween: Tween = null
var _death_tween: Tween = null
var _modulate_at_rest: Color = Color(1, 1, 1, 1)
var _captured_modulate_at_rest: bool = false

# Hit-flash target — Sprite child (Bug C fix). See Grunt.gd for full rationale.
var _hit_flash_target: CanvasItem = null
var _hit_flash_uses_sprite: bool = false
var _sprite_color_at_rest: Color = Color(1, 1, 1, 1)


func _ready() -> void:
	_apply_mob_def()
	_apply_layers()
	_resolve_player()


# ---- Public API -------------------------------------------------------

func get_state() -> StringName:
	return _state


func get_hp() -> int:
	return hp_current


func get_max_hp() -> int:
	return hp_max


func is_dead() -> bool:
	return _is_dead


## Total projectiles fired this life. Reset only on respawn (which means
## a new node — there's no in-place revive).
func get_shots_fired() -> int:
	return _shots_fired


func set_player(p: Node2D) -> void:
	_player = p


func apply_mob_def(def: MobDef) -> void:
	mob_def = def
	_apply_mob_def()


## Take damage. Mirrors Grunt's contract: clamp negative, ignore-once-dead,
## emit `damaged`, kill on 0.
func take_damage(amount: int, knockback: Vector2, source: Node) -> void:
	if _is_dead:
		return
	var clean_amount: int = max(0, amount)
	hp_current = max(0, hp_current - clean_amount)
	damaged.emit(clean_amount, hp_current, source)
	# Visual: white hit-flash on every actual-damage take_damage (Uma §2).
	if clean_amount > 0:
		_play_hit_flash()
	if knockback.length_squared() > 0.0:
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
		STATE_AIMING:
			_process_aiming(delta)
		STATE_FIRING:
			_process_firing(delta)
		STATE_POST_FIRE_RECOVERY:
			_process_post_fire(delta)
		STATE_KITING:
			_process_kiting(delta)
		STATE_DEAD:
			pass

	move_and_slide()


# ---- State handlers ---------------------------------------------------

func _process_idle(_delta: float) -> void:
	velocity = Vector2.ZERO
	if _player == null:
		return
	var dist: float = (_player.global_position - global_position).length()
	if dist <= AGGRO_RADIUS:
		_set_state(STATE_SPOTTED)
		_spotted_hold_left = SPOTTED_HOLD


func _process_spotted(_delta: float) -> void:
	velocity = Vector2.ZERO
	if _spotted_hold_left <= 0.0:
		_pick_post_spotted_state()


func _process_aiming(_delta: float) -> void:
	# Hold position while aiming. Player who closes the gap forces a kite
	# *interrupt* — checked here on every aim tick.
	if _player != null:
		var dist: float = (_player.global_position - global_position).length()
		if dist < KITE_RANGE:
			_enter_kite()
			return
		# Re-track the last aim direction every tick so a player walking
		# perpendicular to the shooter still gets shot toward (the direction
		# locks at FIRING, not at aim start — projectiles aren't homing,
		# just reactive).
		_last_aim_dir = _vec_to_player_dir()
	velocity = Vector2.ZERO
	if _aim_left <= 0.0:
		_set_state(STATE_FIRING)


func _process_firing(_delta: float) -> void:
	# One-tick spawn. Lock direction at fire time.
	velocity = Vector2.ZERO
	if _player != null:
		_last_aim_dir = _vec_to_player_dir()
	_spawn_projectile(_last_aim_dir)
	_post_fire_recovery_left = POST_FIRE_RECOVERY
	_set_state(STATE_POST_FIRE_RECOVERY)


func _process_post_fire(_delta: float) -> void:
	velocity = Vector2.ZERO
	if _post_fire_recovery_left <= 0.0:
		_pick_post_recovery_state()


func _process_kiting(_delta: float) -> void:
	# Walk away from the player at base move speed. Once we're back inside
	# AIM_RANGE band, re-enter aiming.
	if _player == null:
		velocity = Vector2.ZERO
		_set_state(STATE_IDLE)
		return
	var to_player: Vector2 = _player.global_position - global_position
	var dist: float = to_player.length()
	# Exit kite when we've recovered comfortable distance — choose a value
	# slightly above KITE_RANGE so we don't oscillate on the boundary.
	if dist > KITE_RANGE + 16.0:
		_aim_left = AIM_DURATION
		_last_aim_dir = _vec_to_player_dir()
		_set_state(STATE_AIMING)
		aim_started.emit(_last_aim_dir)
		return
	if dist < 0.0001:
		velocity = Vector2.ZERO
		return
	# Walk away (negate the direction toward player).
	velocity = (-to_player.normalized()) * move_speed


# ---- Decision helpers ------------------------------------------------

func _pick_post_spotted_state() -> void:
	if _player == null:
		_set_state(STATE_IDLE)
		return
	var dist: float = (_player.global_position - global_position).length()
	if dist < KITE_RANGE:
		_enter_kite()
	else:
		_aim_left = AIM_DURATION
		_last_aim_dir = _vec_to_player_dir()
		_set_state(STATE_AIMING)
		aim_started.emit(_last_aim_dir)


func _pick_post_recovery_state() -> void:
	if _player == null:
		_set_state(STATE_IDLE)
		return
	var dist: float = (_player.global_position - global_position).length()
	if dist > AGGRO_RADIUS:
		_set_state(STATE_IDLE)
		return
	if dist < KITE_RANGE:
		_enter_kite()
	else:
		_aim_left = AIM_DURATION
		_last_aim_dir = _vec_to_player_dir()
		_set_state(STATE_AIMING)
		aim_started.emit(_last_aim_dir)


func _enter_kite() -> void:
	# Cancel any pending aim — kiting interrupts.
	_aim_left = 0.0
	_set_state(STATE_KITING)
	# Apply kite velocity immediately on the transition tick. Otherwise the
	# match block has already run the prior state's branch (e.g. AIMING) and
	# we'd ship a zero-velocity tick before _process_kiting runs next frame —
	# tests assert kite velocity within the same tick as the state change.
	if _player != null:
		var to_player: Vector2 = _player.global_position - global_position
		if to_player.length_squared() > 0.0:
			velocity = (-to_player.normalized()) * move_speed
		else:
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO


# ---- Projectile spawn ------------------------------------------------

func _spawn_projectile(dir: Vector2) -> void:
	var d: Vector2 = dir
	if d.length_squared() <= 0.0:
		d = Vector2.RIGHT
	d = d.normalized()
	var p: Projectile = ProjectileScene.instantiate()
	# Damage routed through the formula utility. Reads MobDef.damage_base +
	# the player's Vigor mitigation at projectile-spawn time. Projectile is
	# in-flight after this point — mid-flight stat changes don't retro-edit
	# the damage payload (matches Grunt's swing-time policy).
	var hit_dmg: int = DamageScript.compute_mob_damage(mob_def, _player_vigor())
	# Configure BEFORE add_child so _ready picks up team/lifetime/layers.
	p.configure(hit_dmg, d * PROJECTILE_SPEED, PROJECTILE_LIFETIME, Projectile.TEAM_ENEMY, self, PROJECTILE_KNOCKBACK)
	# Spawn at the shooter's position. Parent under the shooter's parent so
	# the projectile outlives the shooter (player should still take the hit
	# of an in-flight projectile from a corpse — the projectile is its own
	# entity once spawned). If we don't yet have a parent (test edge case),
	# add to self as a fallback so the test can observe the node.
	var parent: Node = get_parent()
	if parent == null:
		parent = self
	parent.add_child(p)
	p.global_position = global_position
	_shots_fired += 1
	projectile_fired.emit(p, d)


# ---- Death ------------------------------------------------------------

func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	_aim_left = 0.0
	_post_fire_recovery_left = 0.0
	_spotted_hold_left = 0.0
	velocity = Vector2.ZERO
	_set_state(STATE_DEAD)
	# CRITICAL CONTRACT (Uma `combat-visual-feedback.md` §3a): mob_died fires
	# at the START of the death sequence; the 200ms visual decay does not
	# gate loot drop or room-clear logic.
	mob_died.emit(self, global_position, mob_def)
	_spawn_death_particles()
	_play_death_tween()


# ---- Visual feedback helpers (per Uma `combat-visual-feedback.md`) ---

## §2 hit-flash. Bug C fix: tween Sprite child's `color` so the flash is
## actually visible. See Grunt._play_hit_flash for full rationale.
func _play_hit_flash() -> void:
	if _is_dead:
		return
	if _hit_flash_target == null:
		var sprite: Node = get_node_or_null("Sprite")
		if sprite is ColorRect:
			_hit_flash_target = sprite
			_hit_flash_uses_sprite = true
			_sprite_color_at_rest = (sprite as ColorRect).color
		else:
			_hit_flash_target = self
			_hit_flash_uses_sprite = false
	if not _captured_modulate_at_rest:
		_modulate_at_rest = modulate
		_captured_modulate_at_rest = true
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	if not is_inside_tree():
		modulate = _modulate_at_rest
		return
	_hit_flash_tween = create_tween()
	if _hit_flash_uses_sprite:
		var sprite_rect: ColorRect = _hit_flash_target as ColorRect
		_hit_flash_tween.tween_property(sprite_rect, "color", Color(1, 1, 1, 1), HIT_FLASH_IN)
		_hit_flash_tween.tween_property(sprite_rect, "color", Color(1, 1, 1, 1), HIT_FLASH_HOLD)
		_hit_flash_tween.tween_property(sprite_rect, "color", _sprite_color_at_rest, HIT_FLASH_OUT)
	else:
		_hit_flash_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), HIT_FLASH_IN)
		_hit_flash_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), HIT_FLASH_HOLD)
		_hit_flash_tween.tween_property(self, "modulate", _modulate_at_rest, HIT_FLASH_OUT)


## **HTML5 safety-net** (Sponsor soak `embergrave-html5-0e77a92`): see Grunt
## `_play_death_tween` for the full rationale. Mirror of the same pattern.
func _play_death_tween() -> void:
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
		_hit_flash_tween = null
	if not is_inside_tree():
		queue_free()
		return
	_death_tween = create_tween()
	_death_tween.set_parallel(true)
	_death_tween.tween_property(self, "scale", Vector2(DEATH_TARGET_SCALE, DEATH_TARGET_SCALE), DEATH_TWEEN_DURATION)
	_death_tween.tween_property(self, "modulate:a", 0.0, DEATH_TWEEN_DURATION)
	_death_tween.finished.connect(_on_death_tween_finished)
	# Safety-net: parallel timer fires queue_free even if tween_finished hangs.
	var timer: SceneTreeTimer = get_tree().create_timer(DEATH_TWEEN_DURATION + 0.2)
	timer.timeout.connect(_force_queue_free)


func _on_death_tween_finished() -> void:
	_force_queue_free()


## Idempotent queue_free. See Grunt._force_queue_free for the contract.
func _force_queue_free() -> void:
	if is_queued_for_deletion():
		_combat_trace("Shooter._force_queue_free", "already queued — second-caller no-op")
		return
	_combat_trace("Shooter._force_queue_free", "freeing now")
	queue_free()


## Combat-trace shim — routes through DebugFlags.combat_trace (HTML5-only).
func _combat_trace(tag: String, msg: String = "") -> void:
	var df: Node = null
	if is_inside_tree():
		df = get_tree().root.get_node_or_null("DebugFlags")
	if df != null and df.has_method("combat_trace"):
		df.combat_trace(tag, msg)


func _spawn_death_particles() -> void:
	var room: Node = get_parent()
	if room == null:
		return
	var burst: CPUParticles2D = CPUParticles2D.new()
	burst.global_position = global_position
	burst.amount = DEATH_PARTICLE_COUNT
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.lifetime = 0.30
	burst.emitting = true
	burst.direction = Vector2.UP
	burst.spread = 180.0
	burst.initial_velocity_min = 30.0
	burst.initial_velocity_max = 60.0
	burst.gravity = Vector2(0.0, -40.0)
	burst.scale_amount_min = 1.0
	burst.scale_amount_max = 1.0
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, EMBER_LIGHT)
	ramp.set_color(1, EMBER_DEEP)
	burst.color_ramp = ramp
	# Physics-flush safety: see Grunt._spawn_death_particles for full rationale.
	# `_die` runs during the physics-step body_entered chain; deferred add_child
	# avoids Godot 4's "Can't change this state while flushing queries" panic.
	room.call_deferred("add_child", burst)
	burst.finished.connect(burst.queue_free)


# ---- Helpers ----------------------------------------------------------

func _vec_to_player_dir() -> Vector2:
	if _player == null:
		return Vector2.RIGHT
	var to_player: Vector2 = _player.global_position - global_position
	if to_player.length_squared() <= 0.0:
		return Vector2.RIGHT
	return to_player.normalized()


func _tick_timers(delta: float) -> void:
	if _spotted_hold_left > 0.0:
		_spotted_hold_left = max(0.0, _spotted_hold_left - delta)
	if _aim_left > 0.0:
		_aim_left = max(0.0, _aim_left - delta)
	if _post_fire_recovery_left > 0.0:
		_post_fire_recovery_left = max(0.0, _post_fire_recovery_left - delta)


func _set_state(new_state: StringName) -> void:
	if new_state == _state:
		return
	var old: StringName = _state
	_state = new_state
	state_changed.emit(old, new_state)


func _apply_mob_def() -> void:
	if mob_def == null:
		hp_max = 40
		hp_current = 40
		damage_base = 6
		move_speed = 60.0
		return
	hp_max = mob_def.hp_base
	hp_current = mob_def.hp_base
	damage_base = mob_def.damage_base
	move_speed = mob_def.move_speed


func _apply_layers() -> void:
	const BARE_DEFAULT_LAYER: int = 1
	if collision_layer == 0 or collision_layer == BARE_DEFAULT_LAYER:
		collision_layer = LAYER_ENEMY
	if collision_mask == 0 or collision_mask == BARE_DEFAULT_LAYER:
		collision_mask = LAYER_WORLD | LAYER_PLAYER


## Read the player's Vigor stat for the damage formula. Returns 0 if the
## player ref is unset or doesn't expose get_vigor (defensive).
func _player_vigor() -> int:
	if _player == null:
		return 0
	if not _player.has_method("get_vigor"):
		return 0
	return int(_player.get_vigor())


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
