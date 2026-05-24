class_name SunkenScholar
extends CharacterBody2D
## Stratum-2 ranged caster mob — robed scholar transformed by ember-vein
## exposure (per `team/uma-ux/palette-stratum-2.md` §1.5 hybrid framing +
## §5.5 character archetype). Mechanically cloned from Shooter (telegraph-
## spawn-projectile kiter), tonally distinct per Uma:
##
##   - **Silhouette anchor:** tall robed humanoid with lantern-staff (vs. S1
##     Shooter's compact skeletal-archer). 32 px standing.
##   - **Telegraph anchor:** lantern-staff flare + eye-glow (vs. S1 Shooter's
##     bow-draw). `aim_started` carries the same payload — visual hooks listen
##     to the same signal to fan out into the lantern-flare-anim path.
##   - **Projectile:** slower than S1 Shooter (60 vs 90 px/s) with a longer
##     telegraph window (0.85 s vs 0.55 s). Effective sweet spot (KITE_RANGE..
##     SHOOT_RANGE) narrows accordingly — the band invariant SHOOT_RANGE =
##     PROJECTILE_SPEED * PROJECTILE_LIFETIME holds (ticket 86c9uehaq doctrine).
##   - **Same band semantics as Shooter** — kite when player too close,
##     stand-and-fire in the sweet spot, close-the-gap when too far. Cornered
##     fallback (wall-blocked + close player → AIMING with fast windup) is
##     preserved verbatim.
##
## Code structure mirrors `scripts/mobs/Shooter.gd` line-for-line where
## possible so future Shooter-family fixes can fan out by analogy. Differences
## are documented inline — search for `SunkenScholar-specific:`.
##
## Stage 2 ship state (W3-T7 ticket `86c9y7ygj`, ticket stays multi-stage):
##   - Placeholder Sprite is a flat-color ColorRect (parchment-tan
##     `Color(0.659, 0.572, 0.439)` per Uma §1.6 — distinct from S1 Shooter's
##     `Color(0.32, 0.45, 0.78)` blue rest). Hit-flash 3-branch resolver routes
##     through the ColorRect branch (M3W-3 convention).
##   - PixelLab sprite generation deferred to follow-up PR per ticket scope
##     (Sponsor + orchestrator main-session executes via `mcp__pixellab__*`).
##     Drop-in via AnimatedSprite2D scene-swap when ready; resolver branch 1
##     picks it up automatically.
##
## Cross-references:
##   - `.claude/docs/combat-architecture.md` § Shooter state machine
##   - `.claude/docs/combat-architecture.md` § Adding a new mob class
##   - `team/uma-ux/palette-stratum-2.md` § 1.5 + § 1.6 + § 5.5
##   - `scripts/mobs/Shooter.gd` (canonical pattern source)

# ---- Signals ------------------------------------------------------------

signal state_changed(from_state: StringName, to_state: StringName)
signal damaged(amount: int, hp_remaining: int, source: Node)
signal mob_died(mob: SunkenScholar, death_position: Vector2, mob_def: MobDef)

## Aim windup started — visual hooks listen for the lantern-staff flare anim.
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
## Inside this range the scholar starts kiting away from the player.
## Matches S1 Shooter — band semantics are doctrine, only projectile reach
## differs (see SHOOT_RANGE below).
const KITE_RANGE: float = 120.0
## Outer aggro band — beyond this the scholar loses interest (post-fire
## recovery drops to IDLE). NOT the close-the-gap threshold; see SHOOT_RANGE.
const AIM_RANGE: float = 300.0

## Brief "I see you" pause before aiming.
const SPOTTED_HOLD: float = 0.15
## SunkenScholar-specific: longer aim windup than S1 Shooter (0.55s → 0.85s).
## Uma §5.5: "0.6-0.8s telegraph window (longer than S1 Shooter to compensate
## for slower projectile)." Player learns to read the lantern brightness as
## the danger signal — the longer window pairs with the brighter visual cue.
const AIM_DURATION: float = 0.85
## Cooldown after firing before re-aiming.
const POST_FIRE_RECOVERY: float = 0.65

## SunkenScholar-specific: slower projectile than S1 Shooter (90 → 60 px/s).
## Uma §5.5: "slower bullet, longer telegraph, same effective TTK per the
## Shooter band-tuning rule." Player walks 120 px/s → 60 px/s projectile is
## trivially side-steppable, but the sweet-spot threat at standstill is
## preserved.
const PROJECTILE_SPEED: float = 60.0
## Projectile lifetime: distance traveled = SPEED × LIFETIME = 60 × 2.4 = 144
## px — same effective reach as S1 Shooter (which is 90 × 1.6 = 144 px), so
## the sweet spot is the same width. SunkenScholar travels slower but lives
## longer, preserving the SHOOT_RANGE band invariant.
const PROJECTILE_LIFETIME: float = 2.4
const PROJECTILE_KNOCKBACK: float = 80.0

## Effective firing range — see Shooter.SHOOT_RANGE for full doctrine.
## SHOOT_RANGE = PROJECTILE_SPEED * PROJECTILE_LIFETIME = 60 * 2.4 = 144 px.
## Sweet spot KITE_RANGE..SHOOT_RANGE = 120..144 (same as S1 Shooter post-
## 86c9uehaq fix). Drift-detector test pins this invariant.
const SHOOT_RANGE: float = PROJECTILE_SPEED * PROJECTILE_LIFETIME  # 144 px

## "Cornered" detection — wall-blocked + close player → AIMING with fast
## windup. Same constants as Shooter (the cornered fallback is doctrine
## per ticket 86c9uehaq — Sponsor's "if back into a corner doesnt attack" was
## the bug class this prevents).
const CORNERED_KITE_TICKS_TO_FIRE: int = 2
const CORNERED_AIM_DURATION: float = 0.30  # +0.05s vs Shooter; pairs with slower bullet

## Visual-feedback timings — same as Shooter (M3W-3 hit-flash convention).
const HIT_FLASH_IN: float = 0.020
const HIT_FLASH_HOLD: float = 0.020
const HIT_FLASH_OUT: float = 0.040
const DEATH_TWEEN_DURATION: float = 0.200
const DEATH_PARTICLE_COUNT: int = 6
const DEATH_TARGET_SCALE: float = 0.6
## SunkenScholar-specific: ember-light death particles (per Uma §5.5
## "lantern-light gutters out frame-by-frame — the ember IS the soul, leaving").
## Uses the same ember accent hex `#FF6A2A` (ramp top) and `#A02E08` (ramp end)
## as Shooter — cross-stratum constant per palette-stratum-2.md §2.
const EMBER_LIGHT: Color = Color(1.0, 0.416, 0.165, 1.0)  # #FF6A2A — vein/lantern core
const EMBER_DEEP: Color = Color(0.627, 0.180, 0.031, 1.0)  # #A02E08

## Hit-flash modulate tint (M3W-1 / M3W-3 convention). Same value as Shooter
## (cross-stratum visual constant — `team/uma-ux/palette-stratum-2.md` §2:
## "Mob aggro eye-glow — cross-stratum constant" applies to hit-flash too;
## "I hit something" reads identically across the roster).
const HIT_FLASH_TINT: Color = Color(1.0, 0.50, 0.50, 1.0)  # soft red wash, HTML5-safe

## Layer bits (mirror project.godot — same as Shooter/Grunt/Charger).
const LAYER_WORLD: int = 1 << 0
const LAYER_PLAYER: int = 1 << 1
const LAYER_ENEMY: int = 1 << 3

const ProjectileScene: PackedScene = preload("res://scenes/projectiles/Projectile.tscn")
const DamageScript: Script = preload("res://scripts/combat/Damage.gd")

# ---- Inspector --------------------------------------------------------

@export var mob_def: MobDef
@export var player_node_path: NodePath

# ---- Runtime ----------------------------------------------------------

## SunkenScholar-specific: HP slightly higher than S1 Shooter (40 → 50) to
## compensate for the slower projectile (player has more time to dodge each
## shot, so longer TTK before player chips through). Damage matches S2 mob
## scaling baseline (Shooter S2-scaled would be 5 * 1.15 = 5.75 → 6); keeping
## at 6 here means MobRegistry.apply_stratum_scaling won't compound when/if
## wired into spawn. Final balance lever is Sponsor soak (per ticket scope).
var hp_max: int = 50
var hp_current: int = 50
var damage_base: int = 6
var move_speed: float = 60.0  # kite + close-the-gap speed (same as Shooter)

var _state: StringName = STATE_IDLE
var _spotted_hold_left: float = 0.0
var _aim_left: float = 0.0
var _post_fire_recovery_left: float = 0.0
var _is_dead: bool = false
var _last_aim_dir: Vector2 = Vector2.RIGHT
var _player: Node2D = null

## Cornered-kite tick counter (see Shooter.gd for full doctrine).
var _cornered_kite_ticks: int = 0

# Throttle accumulator for the HTML5-only `SunkenScholar.pos` harness-
# observability trace (mirrors Shooter's pattern). Drew's persona rule:
# "No new mob class without trace instrumentation. Add `[combat-trace]
# <Mob>.pos` and `<Mob>._set_state` lines from day one."
var _pos_trace_accum: float = 0.0
const POS_TRACE_INTERVAL: float = 0.25

# Attack-telegraph tween for the aim-state lantern-flare visual.
var _attack_telegraph_tween: Tween = null

## SunkenScholar-specific: ember-amber telegraph tint (vs S1 Shooter's vivid
## red). Uma §5.5: "lantern flares brighter, eyes ignite #D24A3C". The Sprite-
## level visual on the placeholder ColorRect approximates this via a warm
## tint while the lantern-flare anim is unrendered (the ColorRect is the
## scholar silhouette, not the lantern — lantern is a sub-frame anim that
## drops in with the PixelLab sprite). Sub-1.0 all channels for HTML5
## gl_compatibility safety (PR #137 lesson).
const ATTACK_TELEGRAPH_TINT: Color = Color(1.0, 0.55, 0.30, 1.0)  # ember-amber, HTML5 safe
const ATTACK_TELEGRAPH_TWEEN_IN: float = 0.080

# Counter for projectiles fired this life — useful for tests + future scaling.
var _shots_fired: int = 0

# VFX runtime — see Shooter for full doctrine.
var _hit_flash_tween: Tween = null
var _death_tween: Tween = null
var _modulate_at_rest: Color = Color(1, 1, 1, 1)
var _captured_modulate_at_rest: bool = false

# Hit-flash target — 3-branch resolver per M3W-3 convention.
var _hit_flash_target: CanvasItem = null
var _hit_flash_uses_sprite: bool = false
var _hit_flash_uses_animated_sprite: bool = false
var _sprite_color_at_rest: Color = Color(1, 1, 1, 1)
var _sprite_modulate_at_rest: Color = Color(1, 1, 1, 1)

# AnimatedSprite2D cache (M3W-3) — resolved lazily for the PixelLab drop-in.
var _animated_sprite: AnimatedSprite2D = null
var _animated_sprite_resolved: bool = false

## Test-only escape hatch: when true, _spawn_projectile skips the actual
## Projectile.instantiate() + parent.add_child() side-effects. See Shooter
## for full doctrine — same pattern.
@export var test_skip_projectile_spawn: bool = false


func _ready() -> void:
	_apply_mob_def()
	_apply_layers()
	_resolve_player()
	_wire_audio_cues()


# ---- Public API -------------------------------------------------------


func get_state() -> StringName:
	return _state


func get_hp() -> int:
	return hp_current


func get_max_hp() -> int:
	return hp_max


func is_dead() -> bool:
	return _is_dead


## Total projectiles fired this life. Reset only on respawn.
func get_shots_fired() -> int:
	return _shots_fired


func set_player(p: Node2D) -> void:
	_player = p


func apply_mob_def(def: MobDef) -> void:
	mob_def = def
	_apply_mob_def()


## Take damage. Mirrors Shooter/Grunt contract: clamp negative, ignore-once-
## dead, emit `damaged`, kill on 0.
func take_damage(amount: int, knockback: Vector2, source: Node) -> void:
	if _is_dead:
		_combat_trace("SunkenScholar.take_damage", "IGNORED already_dead amount=%d" % amount)
		return
	var clean_amount: int = max(0, amount)
	var hp_before: int = hp_current
	hp_current = max(0, hp_current - clean_amount)
	_combat_trace(
		"SunkenScholar.take_damage",
		"amount=%d hp=%d->%d" % [clean_amount, hp_before, hp_current]
	)
	damaged.emit(clean_amount, hp_current, source)
	if clean_amount > 0:
		_play_hit_flash()
		_play_anim(&"hit")
	if knockback.length_squared() > 0.0:
		velocity = knockback
	if hp_current == 0:
		_die()


# ---- Physics tick -----------------------------------------------------


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_tick_timers(delta)

	# Harness-observability trace (HTML5-only).
	_pos_trace_accum += delta
	if _pos_trace_accum >= POS_TRACE_INTERVAL:
		_pos_trace_accum = 0.0
		var dist_to_player: float = -1.0
		if _player != null:
			dist_to_player = (_player.global_position - global_position).length()
		_combat_trace(
			"SunkenScholar.pos",
			(
				"pos=(%.0f,%.0f) state=%s hp=%d dist_to_player=%.0f"
				% [global_position.x, global_position.y, _state, hp_current, dist_to_player]
			)
		)

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
	# See Shooter._process_aiming for full doctrine — close-the-gap on
	# dist > SHOOT_RANGE, hold position in the sweet spot, kite if player
	# closes inside KITE_RANGE.
	if _player != null:
		var dist: float = (_player.global_position - global_position).length()
		if dist < KITE_RANGE:
			_enter_kite()
			return
		_last_aim_dir = _vec_to_player_dir()
		if dist > SHOOT_RANGE:
			velocity = _vec_to_player_dir() * move_speed
			_combat_trace(
				"SunkenScholar._process_aiming",
				(
					"dist=%.0f > SHOOT_RANGE=%.0f, velocity=(%.0f,%.0f)"
					% [dist, SHOOT_RANGE, velocity.x, velocity.y]
				)
			)
		else:
			velocity = Vector2.ZERO
	else:
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
	# Close-the-gap during recovery if dist > SHOOT_RANGE (mirrors Shooter
	# post-86c9uehaq fix). Kite interrupts apply from AIMING only.
	if _player != null:
		var dist: float = (_player.global_position - global_position).length()
		if dist > SHOOT_RANGE:
			velocity = _vec_to_player_dir() * move_speed
			_combat_trace(
				"SunkenScholar._process_post_fire",
				(
					"dist=%.0f > SHOOT_RANGE=%.0f, closing gap at move_speed=%.0f"
					% [dist, SHOOT_RANGE, move_speed]
				)
			)
		else:
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO
	if _post_fire_recovery_left <= 0.0:
		_pick_post_recovery_state()


func _process_kiting(_delta: float) -> void:
	# See Shooter._process_kiting for full doctrine — walk away, exit when
	# distance restored, cornered-fallback when wall-blocked.
	if _player == null:
		velocity = Vector2.ZERO
		_cornered_kite_ticks = 0
		_set_state(STATE_IDLE)
		return
	var to_player: Vector2 = _player.global_position - global_position
	var dist: float = to_player.length()
	if dist > KITE_RANGE + 16.0:
		_cornered_kite_ticks = 0
		_aim_left = AIM_DURATION
		_last_aim_dir = _vec_to_player_dir()
		_set_state(STATE_AIMING)
		aim_started.emit(_last_aim_dir)
		_play_attack_telegraph()
		return
	if dist < 0.0001:
		velocity = Vector2.ZERO
		_cornered_kite_ticks = 0
		return
	if is_on_wall():
		_cornered_kite_ticks += 1
		if _cornered_kite_ticks >= CORNERED_KITE_TICKS_TO_FIRE:
			_promote_cornered_to_aiming(dist)
			return
	else:
		_cornered_kite_ticks = 0
	velocity = (-to_player.normalized()) * move_speed


func _promote_cornered_to_aiming(dist: float) -> void:
	_cornered_kite_ticks = 0
	_aim_left = CORNERED_AIM_DURATION
	_last_aim_dir = _vec_to_player_dir()
	_combat_trace(
		"SunkenScholar._promote_cornered_to_aiming",
		(
			"CORNERED dist=%.0f wall-blocked, promote to AIMING (windup=%.2fs)"
			% [dist, CORNERED_AIM_DURATION]
		)
	)
	_set_state(STATE_AIMING)
	aim_started.emit(_last_aim_dir)
	_play_attack_telegraph()
	velocity = Vector2.ZERO


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
		_play_attack_telegraph()


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
		_play_attack_telegraph()


func _enter_kite() -> void:
	_aim_left = 0.0
	_cornered_kite_ticks = 0
	_set_state(STATE_KITING)
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
	if test_skip_projectile_spawn:
		_shots_fired += 1
		projectile_fired.emit(null, d)
		return
	var p: Projectile = ProjectileScene.instantiate()
	var hit_dmg: int = DamageScript.compute_mob_damage(mob_def, _player_vigor())
	p.configure(
		hit_dmg,
		d * PROJECTILE_SPEED,
		PROJECTILE_LIFETIME,
		Projectile.TEAM_ENEMY,
		self,
		PROJECTILE_KNOCKBACK
	)
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
	_combat_trace("SunkenScholar._die", "starting death sequence")
	_aim_left = 0.0
	_post_fire_recovery_left = 0.0
	_spotted_hold_left = 0.0
	_cornered_kite_ticks = 0
	velocity = Vector2.ZERO
	_cancel_attack_telegraph_tween()
	_set_state(STATE_DEAD)
	# CRITICAL CONTRACT (Uma combat-visual-feedback.md §3a): mob_died fires
	# at the START of the death sequence; the visual decay doesn't gate loot.
	mob_died.emit(self, global_position, mob_def)
	_play_anim(&"die")
	_spawn_death_particles()
	_play_death_tween()


# ---- Visual feedback helpers -----------------------------------------


## Attack-telegraph visual — Sprite-tinted lantern-flare proxy until the
## PixelLab sprite drops in. See Shooter._play_attack_telegraph for the
## same shape; only the tint differs (ember-amber vs vivid red).
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
	var hold_dur: float = max(0.0, AIM_DURATION - ATTACK_TELEGRAPH_TWEEN_IN * 2.0)
	_attack_telegraph_tween.tween_property(
		target, prop, ATTACK_TELEGRAPH_TINT, ATTACK_TELEGRAPH_TWEEN_IN
	)
	_attack_telegraph_tween.tween_property(target, prop, ATTACK_TELEGRAPH_TINT, hold_dur)
	_attack_telegraph_tween.tween_property(target, prop, color_at_rest, ATTACK_TELEGRAPH_TWEEN_IN)
	_combat_trace(
		"SunkenScholar._play_attack_telegraph",
		(
			"tween_valid=%s tint=(%.2f,%.2f,%.2f)"
			% [
				_attack_telegraph_tween.is_valid(),
				ATTACK_TELEGRAPH_TINT.r,
				ATTACK_TELEGRAPH_TINT.g,
				ATTACK_TELEGRAPH_TINT.b
			]
		)
	)


func _cancel_attack_telegraph_tween() -> void:
	if _attack_telegraph_tween != null and _attack_telegraph_tween.is_valid():
		_attack_telegraph_tween.kill()
		_attack_telegraph_tween = null


## M3W-3 3-branch hit-flash resolver — mirror of Shooter._play_hit_flash.
func _play_hit_flash() -> void:
	if _is_dead:
		return
	if _hit_flash_target == null:
		var sprite: Node = get_node_or_null("Sprite")
		if sprite is AnimatedSprite2D:
			_hit_flash_target = sprite
			_hit_flash_uses_sprite = true
			_hit_flash_uses_animated_sprite = true
			_sprite_modulate_at_rest = (sprite as AnimatedSprite2D).modulate
		elif sprite is ColorRect:
			_hit_flash_target = sprite
			_hit_flash_uses_sprite = true
			_hit_flash_uses_animated_sprite = false
			_sprite_color_at_rest = (sprite as ColorRect).color
		else:
			_hit_flash_target = self
			_hit_flash_uses_sprite = false
			_hit_flash_uses_animated_sprite = false
	if not _captured_modulate_at_rest:
		_modulate_at_rest = modulate
		_captured_modulate_at_rest = true
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	if not is_inside_tree():
		modulate = _modulate_at_rest
		return
	_hit_flash_tween = create_tween()
	if _hit_flash_uses_animated_sprite:
		var asprite: AnimatedSprite2D = _hit_flash_target as AnimatedSprite2D
		_hit_flash_tween.tween_property(asprite, "modulate", HIT_FLASH_TINT, HIT_FLASH_IN)
		_hit_flash_tween.tween_property(asprite, "modulate", HIT_FLASH_TINT, HIT_FLASH_HOLD)
		_hit_flash_tween.tween_property(
			asprite, "modulate", _sprite_modulate_at_rest, HIT_FLASH_OUT
		)
	elif _hit_flash_uses_sprite:
		var sprite_rect: ColorRect = _hit_flash_target as ColorRect
		# Tween via HIT_FLASH_TINT-modulated color so the ColorRect placeholder
		# actually flashes red (vs Shooter's path which tweens through pure
		# white). Sub-1.0 channels for HTML5 safety.
		var flash_color: Color = HIT_FLASH_TINT
		_hit_flash_tween.tween_property(sprite_rect, "color", flash_color, HIT_FLASH_IN)
		_hit_flash_tween.tween_property(sprite_rect, "color", flash_color, HIT_FLASH_HOLD)
		_hit_flash_tween.tween_property(sprite_rect, "color", _sprite_color_at_rest, HIT_FLASH_OUT)
	else:
		_hit_flash_tween.tween_property(self, "modulate", HIT_FLASH_TINT, HIT_FLASH_IN)
		_hit_flash_tween.tween_property(self, "modulate", HIT_FLASH_TINT, HIT_FLASH_HOLD)
		_hit_flash_tween.tween_property(self, "modulate", _modulate_at_rest, HIT_FLASH_OUT)


## HTML5 safety-net death tween — see Shooter._play_death_tween for rationale.
func _play_death_tween() -> void:
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
		_hit_flash_tween = null
	if not is_inside_tree():
		queue_free()
		return
	_death_tween = create_tween()
	_death_tween.set_parallel(true)
	_death_tween.tween_property(
		self, "scale", Vector2(DEATH_TARGET_SCALE, DEATH_TARGET_SCALE), DEATH_TWEEN_DURATION
	)
	_death_tween.tween_property(self, "modulate:a", 0.0, DEATH_TWEEN_DURATION)
	_death_tween.finished.connect(_on_death_tween_finished)
	var timer: SceneTreeTimer = get_tree().create_timer(DEATH_TWEEN_DURATION + 0.2)
	timer.timeout.connect(_force_queue_free)


func _on_death_tween_finished() -> void:
	_force_queue_free()


## Idempotent queue_free.
func _force_queue_free() -> void:
	if is_queued_for_deletion():
		_combat_trace("SunkenScholar._force_queue_free", "already queued — second-caller no-op")
		return
	_combat_trace("SunkenScholar._force_queue_free", "freeing now")
	queue_free()


## Combat-trace shim — routes through DebugFlags.combat_trace (HTML5-only).
func _combat_trace(tag: String, msg: String = "") -> void:
	var df: Node = null
	if is_inside_tree():
		df = get_tree().root.get_node_or_null("DebugFlags")
	if df != null and df.has_method("combat_trace"):
		df.combat_trace(tag, msg)


# ---- Audio cue wiring -------------------------------------------------


## Connect combat signals to AudioDirector SFX plays. Reuses S1 Shooter SFX
## ids in Stage 2 — S2-distinct SFX (per audio-direction.md cross-stratum
## ambient pattern) lands in a follow-up audio PR when the S2 mob-cue palette
## ships. The wiring shape is identical to Shooter so the follow-up is a
## per-cue rename, not a structural change.
func _wire_audio_cues() -> void:
	if not damaged.is_connected(_on_damaged_audio):
		damaged.connect(_on_damaged_audio)
	if not mob_died.is_connected(_on_mob_died_audio):
		mob_died.connect(_on_mob_died_audio)
	if not aim_started.is_connected(_on_aim_started_audio):
		aim_started.connect(_on_aim_started_audio)
	if not projectile_fired.is_connected(_on_projectile_fired_audio):
		projectile_fired.connect(_on_projectile_fired_audio)


func _resolve_audio_director() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("AudioDirector")


func _on_damaged_audio(amount: int, _hp_remaining: int, _source: Node) -> void:
	if amount <= 0:
		return
	var ad: Node = _resolve_audio_director()
	if ad == null or not ad.has_method("play_sfx"):
		return
	ad.play_sfx(&"sfx-mob-hit")


func _on_mob_died_audio(_mob: SunkenScholar, _pos: Vector2, _def: MobDef) -> void:
	var ad: Node = _resolve_audio_director()
	if ad == null or not ad.has_method("play_sfx"):
		return
	ad.play_sfx(&"sfx-mob-die")


func _on_aim_started_audio(_dir: Vector2) -> void:
	var ad: Node = _resolve_audio_director()
	if ad == null or not ad.has_method("play_sfx"):
		return
	ad.play_sfx(&"sfx-attack-telegraph")


func _on_projectile_fired_audio(_projectile: Node, _dir: Vector2) -> void:
	var ad: Node = _resolve_audio_director()
	if ad == null or not ad.has_method("play_sfx"):
		return
	ad.play_sfx(&"sfx-attack-impact")


# ---- Animation playback (M3W-3 — fires only when AnimatedSprite2D drops in) ---


## Play an animation on the AnimatedSprite2D child. No-op while the
## placeholder ColorRect is in place. Same shape as Shooter._play_anim so
## the PixelLab-sprite drop-in is a Sprite-node swap with no Script edit.
func _play_anim(state: StringName) -> void:
	if not _animated_sprite_resolved:
		var sprite: Node = get_node_or_null("Sprite")
		if sprite is AnimatedSprite2D:
			_animated_sprite = sprite
		_animated_sprite_resolved = true
	if _animated_sprite == null:
		return
	if _animated_sprite.sprite_frames == null:
		return
	var dir_suffix: String = _compute_facing_dir_suffix()
	var anim_name: StringName = StringName("%s_%s" % [state, dir_suffix])
	if not _animated_sprite.sprite_frames.has_animation(anim_name):
		_combat_trace(
			"SunkenScholar._play_anim",
			"MISS anim=%s — SpriteFrames lacks this animation key" % anim_name
		)
		return
	if _animated_sprite.animation == anim_name and _animated_sprite.is_playing():
		return
	_animated_sprite.play(anim_name)
	_combat_trace("SunkenScholar._play_anim", "PLAY anim=%s" % anim_name)


func _compute_facing_dir_suffix() -> String:
	if _state == STATE_AIMING or _state == STATE_FIRING or _state == STATE_POST_FIRE_RECOVERY:
		if _last_aim_dir.length_squared() > 0.0001:
			return _vec_to_dir_suffix(_last_aim_dir)
	if _state == STATE_KITING and _player != null and is_inside_tree():
		var away: Vector2 = global_position - _player.global_position
		if away.length_squared() > 0.0001:
			return _vec_to_dir_suffix(away)
	if _player != null and is_inside_tree():
		var to_player: Vector2 = _player.global_position - global_position
		if to_player.length_squared() > 0.0001:
			return _vec_to_dir_suffix(to_player)
	return "s"


static func _vec_to_dir_suffix(v: Vector2) -> String:
	var angle: float = atan2(v.y, v.x)
	var idx: int = int(floor((angle + PI / 8.0) / (PI / 4.0))) + 8
	idx = idx % 8
	const SUFFIXES: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
	return SUFFIXES[idx]


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
	# Physics-flush safety: see Shooter._spawn_death_particles.
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
	# Diagnostic trace — every transition (band, distance, position). Drew's
	# persona rule: "No new mob class without trace instrumentation."
	var dist: float = -1.0
	if _player != null and is_inside_tree():
		dist = (_player.global_position - global_position).length()
	_combat_trace(
		"SunkenScholar._set_state",
		(
			"%s -> %s dist=%.0f pos=(%.0f,%.0f)"
			% [old, new_state, dist, global_position.x, global_position.y]
		)
	)
	# Animation state→anim mapping per Shooter precedent.
	match new_state:
		STATE_SPOTTED, STATE_KITING:
			_play_anim(&"walk")
		STATE_AIMING:
			_play_anim(&"telegraph")
		STATE_FIRING, STATE_POST_FIRE_RECOVERY:
			_play_anim(&"atk")
	state_changed.emit(old, new_state)


func _apply_mob_def() -> void:
	if mob_def == null:
		# SunkenScholar defaults — see runtime declarations above for rationale.
		hp_max = 50
		hp_current = 50
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
