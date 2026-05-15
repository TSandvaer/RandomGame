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

## Speed (px/s) of the one-tick push-back velocity applied when the charger
## enters recovery after a contact-attack. Gives move_and_slide() a direction
## to eject the mob out of player overlap — without this the two
## CharacterBody2Ds sit at zero-velocity and no separation is generated,
## causing the "mob sticks to player" symptom (Bug 2, M1 RC re-soak 3).
const POST_CONTACT_PUSHBACK_SPEED: float = 60.0

## When charge motion is rejected this many frames in a row, treat it as a
## wall hit and stop. move_and_slide reports `get_real_velocity()` close to
## zero when stuck; we measure post-slide displacement instead.
const WALL_STOP_DISPLACEMENT_EPSILON: float = 0.5

## Number of consecutive sub-epsilon-displacement frames required before
## treating it as a wall hit. A single-frame trigger was too aggressive: in
## headless tests `move_and_slide()` integrates over `get_physics_process_-
## delta_time()` which can be near-zero before the engine has ticked physics,
## producing sub-epsilon displacement on the first CHARGING tick even though
## velocity is set correctly. Two-frame minimum keeps the wall-stop sensitive
## in real gameplay (the second consecutive sub-epsilon tick is a real stuck
## condition) while filtering the headless-test false positive. Captured by
## CI runs 25260326711 + 25260666771 (test_killed_mid_charge +
## test_velocity_during_charge tripping the wall-stop on charge-entry tick).
const WALL_STOP_FRAMES_REQUIRED: int = 2

## Visual-feedback timings (per `team/uma-ux/combat-visual-feedback.md` §2 + §3).
## Same rule as Grunt — 80ms hit-flash, 200ms death-tween, 6 particles.
const HIT_FLASH_IN: float = 0.020
const HIT_FLASH_HOLD: float = 0.020
const HIT_FLASH_OUT: float = 0.040
const DEATH_TWEEN_DURATION: float = 0.200
const DEATH_PARTICLE_COUNT: int = 6
const DEATH_TARGET_SCALE: float = 0.6
const EMBER_LIGHT: Color = Color(1.0, 0.690, 0.400, 1.0)   # #FFB066
const EMBER_DEEP: Color = Color(0.627, 0.180, 0.031, 1.0)  # #A02E08

## Layer bits (mirror project.godot — same as Grunt).
const LAYER_WORLD: int = 1 << 0          # bit 1
const LAYER_PLAYER: int = 1 << 1         # bit 2
const LAYER_ENEMY: int = 1 << 3          # bit 4

const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")
const DamageScript: Script = preload("res://scripts/combat/Damage.gd")

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
var damage_base: int = 5  # rebalanced M1 RC soak-4: was 8, now 5 (~38% reduction)
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

# Throttle accumulator for the HTML5-only `Charger.pos` harness-observability
# trace (see `_physics_process`). The Charger CHASES (telegraph → charge), so
# a browser-driven spec *can* kill it by near-spawn click-spam when it is the
# only mob crowding the player — but in a 3-mob room (Rooms 05-08) chasers
# drift out of the fixed-position swing wedge and the click-spam-from-spawn
# path clears the room only 0/3–2/3 of the time (ticket 86c9u05d7). The AC4
# multi-chaser clear sub-helper (tests/playwright/fixtures/kiting-mob-chase.ts)
# fixes that by position-steered pursuit, which needs to know where each
# chaser is. This throttled world-coord + distance trace is that readback.
# Mirrors `Grunt.pos` / `Shooter.pos` / `Player.pos`; no-op on headless GUT /
# desktop (combat_trace gates on `OS.has_feature("web")`).
var _pos_trace_accum: float = 0.0
## How often the `Charger.pos` trace emits — see `Player.POS_TRACE_INTERVAL`
## for the rationale (fine enough to steer a pursuit, cheap enough to be a
## no-op on perf; combat_trace is HTML5-only).
const POS_TRACE_INTERVAL: float = 0.25

## Counter for consecutive sub-epsilon-displacement charging frames. Reset on
## charge start (`_begin_charge`) and on any frame where displacement clears
## the epsilon. When it reaches WALL_STOP_FRAMES_REQUIRED, _end_charge_into_wall
## fires.
var _wall_stop_frames: int = 0

# Attack-telegraph tween — ref kept so a death-during-telegraph can cancel it.
# Charger already has TELEGRAPHING state (0.55 s), this adds the red-glow visual.
var _attack_telegraph_tween: Tween = null

## Red tint for the charge telegraph (player-journey.md Beat 6). All channels
## sub-1.0 so WebGL2/sRGB (HTML5 gl_compatibility) never clamps — same rule as
## player swing-flash (PR #137). Targets Sprite child, not parent modulate.
const ATTACK_TELEGRAPH_TINT: Color = Color(1.0, 0.30, 0.30, 1.0)  # vivid red, HTML5 safe
const ATTACK_TELEGRAPH_TWEEN_IN: float = 0.080

# Tracks which targets the current charge has already body-hit so a single
# charge can't multi-tick the player. Reset at the start of each charge.
var _charge_already_hit: Array[Node] = []

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
	_apply_motion_mode()
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
		_combat_trace("Charger.take_damage", "IGNORED already_dead amount=%d" % amount)
		return
	var clean_amount: int = max(0, amount)
	var multiplier: float = RECOVERY_DAMAGE_MULTIPLIER if _state == STATE_RECOVERING else ARMORED_DAMAGE_MULTIPLIER
	var final_amount: int = int(round(clean_amount * multiplier))
	var hp_before: int = hp_current
	hp_current = max(0, hp_current - final_amount)
	_combat_trace("Charger.take_damage",
		"amount=%d hp=%d->%d" % [final_amount, hp_before, hp_current])
	damaged.emit(final_amount, hp_current, source)
	# Visual: white hit-flash on every actual-damage take_damage (Uma §2).
	if final_amount > 0:
		_play_hit_flash()
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

	# Harness-observability trace (HTML5-only via the combat_trace shim).
	# Throttled world-coord + distance readback so the AC4 multi-chaser clear
	# sub-helper can pursue this chaser when it drifts out of the player's
	# fixed-position swing wedge — see the `_pos_trace_accum` declaration above
	# and `Grunt.pos` / `Shooter.pos` / `Player.pos` for the full rationale.
	# No-op on headless GUT / desktop (combat_trace gates on
	# `OS.has_feature("web")`).
	_pos_trace_accum += delta
	if _pos_trace_accum >= POS_TRACE_INTERVAL:
		_pos_trace_accum = 0.0
		var dist_to_player: float = -1.0
		if _player != null:
			dist_to_player = (_player.global_position - global_position).length()
		_combat_trace("Charger.pos",
			"pos=(%.0f,%.0f) state=%s hp=%d dist_to_player=%.0f" % [
				global_position.x, global_position.y, _state, hp_current, dist_to_player
			])

	# Snapshot the entry state so we know whether CHARGING was already active
	# coming into this tick. Same-tick transitions (telegraph -> charging) must
	# not trip the wall-stop check on the first charge tick before motion has
	# even been attempted.
	var entry_state: StringName = _state

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
	# After the slide, check for wall stop during charge. Only fire when we
	# were already CHARGING at tick start AND are still CHARGING after the
	# state handler — otherwise transitions in/out of charge in the same tick
	# would fire spurious wall-stops.
	# Require WALL_STOP_FRAMES_REQUIRED consecutive sub-epsilon ticks to
	# tolerate a single-tick zero-displacement glitch (headless test envs
	# where `get_physics_process_delta_time()` returns ~0 on the first
	# CHARGING tick before the engine has stepped physics — see
	# WALL_STOP_FRAMES_REQUIRED comment for the captured CI repro).
	if entry_state == STATE_CHARGING and _state == STATE_CHARGING:
		var moved: float = (global_position - pre).length()
		if moved < WALL_STOP_DISPLACEMENT_EPSILON:
			_wall_stop_frames += 1
			if _wall_stop_frames >= WALL_STOP_FRAMES_REQUIRED:
				_end_charge_into_wall()
		else:
			_wall_stop_frames = 0
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
	# Attack-telegraph visual: red-glow on Sprite child for the windup window
	# (player-journey.md Beat 6, M1 RC soak-4 fix). Targets visible-draw node.
	_play_attack_telegraph()


func _begin_charge() -> void:
	_charge_time_left = CHARGE_MAX_DURATION
	_charge_already_hit.clear()
	# Apply charge velocity immediately on the transition tick. Otherwise the
	# wall-stop check fires below because velocity was zero during the prior
	# telegraph branch's move_and_slide and post-slide displacement is 0.
	velocity = _charge_dir * charge_speed
	_wall_stop_frames = 0
	_set_state(STATE_CHARGING)


func _enter_recovery() -> void:
	# Apply a brief push-back velocity away from the player before zeroing out.
	# This gives move_and_slide() the non-zero vector it needs to eject the
	# charger from a player-overlap condition on the next physics step — the
	# root cause of Bug 2 (mob "sticks" to player after contact-attack).
	# Only applied when we have a player reference and are close enough that
	# overlap is plausible (within the charge hitbox envelope).
	if _player != null:
		var away: Vector2 = global_position - _player.global_position
		if away.length_squared() < (CHARGE_HITBOX_RADIUS + CHARGE_HITBOX_REACH) * (CHARGE_HITBOX_RADIUS + CHARGE_HITBOX_REACH) * 4.0:
			velocity = (away.normalized() if away.length_squared() > 0.0 else -_charge_dir) * POST_CONTACT_PUSHBACK_SPEED
		else:
			velocity = Vector2.ZERO
	else:
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
	# Damage routed through the formula utility. Reads MobDef.damage_base +
	# the player's Vigor mitigation at hit-spawn time.
	var hit_dmg: int = DamageScript.compute_mob_damage(mob_def, _player_vigor())
	var hb: Hitbox = HitboxScript.new()
	hb.configure(hit_dmg, _charge_dir * CHARGE_KNOCKBACK, CHARGE_HITBOX_LIFETIME, Hitbox.TEAM_ENEMY, self)
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
	_combat_trace("Charger._die", "starting death sequence")
	# Cancel every pending action so a death-during-charge doesn't slide the
	# corpse forward, and so a death-during-telegraph doesn't fire the
	# charge from a dead body. Spec edge probe.
	_telegraph_left = 0.0
	_charge_time_left = 0.0
	_recovery_left = 0.0
	_spotted_hold_left = 0.0
	velocity = Vector2.ZERO
	_cancel_attack_telegraph_tween()
	_set_state(STATE_DEAD)
	# CRITICAL CONTRACT (Uma `combat-visual-feedback.md` §3a): mob_died fires
	# at the START of the death sequence, not after the visual tween. Loot +
	# room-clear logic still execute on this frame; the 200ms visual decay
	# does not gate progression.
	mob_died.emit(self, global_position, mob_def)
	_spawn_death_particles()
	_play_death_tween()


# ---- Visual feedback helpers (per Uma `combat-visual-feedback.md`) ---

## Attack-telegraph visual (player-journey.md Beat 6 + M1 RC soak-4):
## tween the Sprite child's color from rest → red for the charge telegraph
## window, then back to rest when the charge fires. All channels sub-1.0
## for HTML5 gl_compatibility safety (PR #137 lesson).
## Targets Sprite child (visible-draw node) not parent modulate (PR #115 lesson).
func _play_attack_telegraph() -> void:
	if not is_inside_tree():
		return
	var target: CanvasItem = null
	var uses_sprite: bool = false
	var color_at_rest: Color = Color(1, 1, 1, 1)
	var sprite: Node = get_node_or_null("Sprite")
	if sprite is ColorRect:
		target = sprite as ColorRect
		uses_sprite = true
		color_at_rest = (sprite as ColorRect).color
	else:
		target = self
		color_at_rest = modulate
	if _attack_telegraph_tween != null and _attack_telegraph_tween.is_valid():
		_attack_telegraph_tween.kill()
	_attack_telegraph_tween = create_tween()
	var prop: String = "color" if uses_sprite else "modulate"
	var hold_dur: float = max(0.0, TELEGRAPH_DURATION - ATTACK_TELEGRAPH_TWEEN_IN * 2.0)
	_attack_telegraph_tween.tween_property(target, prop, ATTACK_TELEGRAPH_TINT, ATTACK_TELEGRAPH_TWEEN_IN)
	_attack_telegraph_tween.tween_property(target, prop, ATTACK_TELEGRAPH_TINT, hold_dur)
	_attack_telegraph_tween.tween_property(target, prop, color_at_rest, ATTACK_TELEGRAPH_TWEEN_IN)
	_combat_trace("Charger._play_attack_telegraph",
		"tween_valid=%s tint=(%.2f,%.2f,%.2f)" % [
			_attack_telegraph_tween.is_valid(),
			ATTACK_TELEGRAPH_TINT.r, ATTACK_TELEGRAPH_TINT.g, ATTACK_TELEGRAPH_TINT.b
		])


func _cancel_attack_telegraph_tween() -> void:
	if _attack_telegraph_tween != null and _attack_telegraph_tween.is_valid():
		_attack_telegraph_tween.kill()
		_attack_telegraph_tween = null


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


## Idempotent queue_free. Both the tween-finished path AND the HTML5 safety-
## net timer call this; whichever lands first wins, the second is a no-op.
func _force_queue_free() -> void:
	if is_queued_for_deletion():
		_combat_trace("Charger._force_queue_free", "already queued — second-caller no-op")
		return
	_combat_trace("Charger._force_queue_free", "freeing now")
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
		# damage_base = 5 (rebalanced M1 RC soak-4, was 8).
		hp_max = 70
		hp_current = 70
		damage_base = 5
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


## Force `motion_mode = MOTION_MODE_FLOATING` so `move_and_slide()` treats
## every axis equally during collision resolution. Without this, the engine
## defaults to `MOTION_MODE_GROUNDED` with `up_direction = (0, -1)`, and
## collisions whose normal aligns with up_direction (player-from-south
## approach) engage floor-snap / floor-stop behavior that suppresses the
## charger's POST_CONTACT_PUSHBACK velocity along the +up axis.
##
## Universal-bug-class generalization (M2 W1, ticket 86c9qanu1): Stratum1Boss
## surfaced this first because its larger collision radius made the south-
## approach asymmetry observable as visible "sticking" (PR #163). The same
## bug class is latent on every CharacterBody2D in the project — Charger
## (CHARGE_HITBOX_RADIUS 20 px envelope) keeps it below the observability
## threshold but the floor-snap on +up-axis pushback still happens. Per
## the canonical Godot 4 top-down 2D pattern, every CharacterBody2D in
## this project adopts FLOATING.
##
## Documented in `.claude/docs/combat-architecture.md` § "CharacterBody2D
## motion_mode rule".
func _apply_motion_mode() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


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
