class_name BoneCatalyst
extends CharacterBody2D
## Stratum-2 melee bruiser — hunched humanoid with bone-fetish forearms +
## brass skull-mask, telegraphs via a stationary channel-pose (both forearms
## cross above mask, eyes flare) before a hammer-arc slam (per Uma's
## `team/uma-ux/palette-stratum-2.md` §5.5 character archetype + ticket Part B).
##
## Mechanically cloned from `scripts/mobs/Grunt.gd` (melee chaser with telegraph
## → strike → recovery) but differentiated per Uma §5.5:
##
##   - **Silhouette anchor:** hunched bruiser humanoid (wider, shorter than
##     Grunt) — third readable melee shape vs S1 Grunt's hooded-cultist
##     silhouette and S1 Charger's bestial-quadruped silhouette.
##   - **Telegraph anchor:** stationary channel pose (NOT Grunt's 1-frame
##     raised-blade tilt, NOT Charger's rear-back + dash-line). The "I am
##     gathering pressure" reads at silhouette-distance via brass-mask center
##     + crossed forearms. `channel_started` signal fans out to the visual
##     hook (currently Sprite tween on the placeholder ColorRect).
##   - **Channel windup ~0.6s** (Uma §5.5: "0.5-0.7 s windup window — long
##     enough that player can dodge, short enough that it doesn't read as
##     'stunned'"). Mid-band vs Grunt's 0.40s light telegraph + Charger's
##     0.55s charge telegraph.
##   - **Slam strike** — hammer-arc that drops the hitbox at frame 1. Wider
##     reach + longer-lived hitbox than Grunt light, but slower windup. No
##     dash component, no projectile component — pure melee at point-blank
##     range only (KITE_RANGE separates "approach state" from "in slam
##     range").
##
## Code structure mirrors `Grunt.gd` where the state-machine shape overlaps
## (chase → telegraph → strike → recover); divergences are commented inline.
## Search for `BoneCatalyst-specific:` for the lever-by-lever differences.
##
## Stage 3 ship state (W3-T7 ticket `86c9y7ygj`, ticket stays multi-stage):
##   - Placeholder Sprite is a flat-color ColorRect (bone-corroded brown-rust
##     `Color(0.30, 0.18, 0.16, 1)` per Uma §5.5 silhouette anchor — heat-
##     corroded short tunic over hunched bruiser silhouette). Hit-flash
##     3-branch resolver routes through the ColorRect branch (M3W-3 convention).
##   - PixelLab sprite generation deferred to follow-up PR per ticket scope
##     (Sponsor + orchestrator main-session executes via `mcp__pixellab__*`).
##     Drop-in via AnimatedSprite2D scene-swap when ready; resolver branch 1
##     picks it up automatically (M3W-1 PR #271 inheritance contract).
##
## Cross-references:
##   - `.claude/docs/combat-architecture.md` § "Adding a new mob class"
##   - `team/uma-ux/palette-stratum-2.md` § 1.5 + § 1.6 + § 5.5 Bone-Catalyst
##   - `scripts/mobs/Grunt.gd` (canonical melee pattern source)

# ---- Signals ------------------------------------------------------------

signal state_changed(from_state: StringName, to_state: StringName)
signal damaged(amount: int, hp_remaining: int, source: Node)
signal mob_died(mob: BoneCatalyst, death_position: Vector2, mob_def: MobDef)

## Channel-windup started — visual hooks listen for the forearms-cross + mask-
## flare anim. Carries the player-direction so the channel pose can face the
## target.
signal channel_started(target_dir: Vector2)
## Slam swing fired (hitbox spawned). Carries the spawned hitbox node so
## tests + audio hooks can react. `kind` is always &"slam" (single attack-
## shape) — kept as StringName for parity with Grunt.swing_spawned shape.
signal swing_spawned(kind: StringName, hitbox: Node)

# ---- States ------------------------------------------------------------

const STATE_IDLE: StringName = &"idle"
const STATE_CHASING: StringName = &"chasing"
const STATE_CHANNELING: StringName = &"channeling"  # the stationary windup
const STATE_ATTACKING: StringName = &"attacking"  # mid-strike recovery
const STATE_DEAD: StringName = &"dead"

const SWING_KIND_SLAM: StringName = &"slam"

# ---- Tuning (shape) ----------------------------------------------------

const AGGRO_RADIUS: float = 480.0

## In-range threshold for the channel-windup trigger. Slightly larger than
## Grunt's ATTACK_RANGE (28) — the bruiser commits to the channel from
## further out because the windup is longer (player needs time to read it).
const SLAM_RANGE: float = 32.0

## BoneCatalyst-specific: channel-windup duration. Uma §5.5: "0.5-0.7s windup
## window." Mid-band — long enough to dodge, short enough that it doesn't
## read as stunned. Compare Grunt LIGHT_TELEGRAPH_DURATION = 0.40, Charger
## TELEGRAPH_DURATION = 0.55.
const CHANNEL_DURATION: float = 0.60

## How long after the slam strike before the bruiser can act again. Slightly
## longer than Grunt ATTACK_RECOVERY (0.55) — pairs with the heavier-attack
## visual (player should feel the moment "land").
const ATTACK_RECOVERY: float = 0.70

## Slam hitbox spec. BoneCatalyst-specific: bigger reach + longer hitbox life
## than Grunt LIGHT_HITBOX (24/16/0.10) — pairs with the longer windup. NOT
## as wide as Grunt HEAVY_HITBOX (36/22/0.18) — the heavy is a one-shot
## low-HP burst, the BoneCatalyst slam is the routine attack-shape.
const SLAM_HITBOX_REACH: float = 30.0
const SLAM_HITBOX_RADIUS: float = 20.0
const SLAM_HITBOX_LIFETIME: float = 0.14
const SLAM_KNOCKBACK: float = 200.0

## Speed (px/s) of the one-tick push-back velocity applied when the bruiser
## fires a slam at melee range. Same mechanism as Grunt — gives
## move_and_slide() a non-zero vector to eject the bruiser out of overlap.
## See Grunt.POST_CONTACT_PUSHBACK_SPEED for full doctrine (ticket 86c9q96kk).
const POST_CONTACT_PUSHBACK_SPEED: float = 60.0

## Attack-telegraph tint for the channel windup. BoneCatalyst-specific:
## bone-pale shifted toward warm-rust to read as "pressure gathering" rather
## than "I'm about to swing a sword" (Grunt uses vivid red). Per Uma §5.5
## "brass mask reads as the focal point of 'pressure gathering'" — the
## tint approximates the mask flare on the placeholder ColorRect until the
## PixelLab sprite drops in. Sub-1.0 channels for HTML5 HDR-clamp safety
## (PR #137 lesson).
const ATTACK_TELEGRAPH_TINT: Color = Color(0.95, 0.80, 0.50, 1.0)  # warm bone-flare
const ATTACK_TELEGRAPH_TWEEN_IN: float = 0.080
const ATTACK_TELEGRAPH_TWEEN_OUT: float = 0.060

## Visual-feedback timings — uniform with the M3 mob roster.
const HIT_FLASH_IN: float = 0.020
const HIT_FLASH_HOLD: float = 0.020
const HIT_FLASH_OUT: float = 0.040
const DEATH_TWEEN_DURATION: float = 0.200
const DEATH_PARTICLE_COUNT: int = 6
const DEATH_TARGET_SCALE: float = 0.6
## BoneCatalyst-specific: ember-light death particles. Uses the same ember
## accent ramp as Grunt/Shooter/SunkenScholar (cross-stratum constant per
## palette-stratum-2.md §2 "ember through-line preserved" + Uma §5.5
## "bone-particles disperse via CPUParticles2D burst"). The bone-fragment
## visual layer is a future PixelLab-sprite-frame concern; for the
## placeholder burst we use the unified ember ramp.
const EMBER_LIGHT: Color = Color(1.0, 0.690, 0.400, 1.0)  # #FFB066
const EMBER_DEEP: Color = Color(0.627, 0.180, 0.031, 1.0)  # #A02E08

## Hit-flash modulate tint (M3W-1 / M3W-3 convention). Cross-stratum
## constant per `palette-stratum-2.md` §2 — every mob's "I hit something"
## reads identically (Grunt/Charger/Shooter/SunkenScholar/Stoker all use
## this same value). Sub-1.0 channels for HTML5 safety.
const HIT_FLASH_TINT: Color = Color(1.0, 0.50, 0.50, 1.0)  # soft red wash, HTML5-safe

## Layer bits (mirror project.godot — same as Grunt/Charger/Shooter).
const LAYER_WORLD: int = 1 << 0
const LAYER_PLAYER: int = 1 << 1
const LAYER_ENEMY: int = 1 << 3

const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")
const DamageScript: Script = preload("res://scripts/combat/Damage.gd")

# ---- Inspector --------------------------------------------------------

@export var mob_def: MobDef
@export var player_node_path: NodePath

# ---- Runtime ----------------------------------------------------------

## BoneCatalyst-specific: HP higher than Grunt (50 → 70) to compensate for
## the longer windup (player has more dodge opportunity per attempt → bruiser
## eats more hits before going down). Damage matches S2 archetype baseline
## (~ S1 Grunt × 1.5 — bruiser hits hard but tells you it's coming). Final
## balance lever is Sponsor soak per ticket scope.
var hp_max: int = 70
var hp_current: int = 70
var damage_base: int = 5
var move_speed: float = 50.0  # slower than Grunt 60 — heavy gait per Uma §5.5

var _state: StringName = STATE_IDLE
var _attack_recovery_left: float = 0.0
var _channel_left: float = 0.0
var _channel_dir: Vector2 = Vector2.RIGHT  # direction locked at channel start
var _is_dead: bool = false
var _player: Node2D = null

# Throttle accumulator for the HTML5-only `BoneCatalyst.pos` harness-
# observability trace (mirrors Grunt.pos / Charger.pos / Shooter.pos /
# SunkenScholar.pos). Drew's persona rule: "No new mob class without trace
# instrumentation."
var _pos_trace_accum: float = 0.0
const POS_TRACE_INTERVAL: float = 0.25

# Attack-telegraph tween for the channel-windup visual.
var _attack_telegraph_tween: Tween = null

# VFX runtime — mirrors Grunt/Shooter/SunkenScholar pattern.
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


func _ready() -> void:
	_apply_mob_def()
	_apply_layers()
	_apply_motion_mode()
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


## True only during STATE_CHANNELING — the stationary "I am gathering
## pressure" telegraph window. Visual hooks may use this to swap the brass-
## mask sprite slot to its flared variant when the PixelLab frames drop in.
func is_channeling() -> bool:
	return _state == STATE_CHANNELING


func set_player(p: Node2D) -> void:
	_player = p


func apply_mob_def(def: MobDef) -> void:
	mob_def = def
	_apply_mob_def()


## Take damage. Mirrors Grunt contract: clamp negative, ignore-once-dead,
## emit `damaged`, kill on 0. BoneCatalyst-specific: NO armored / vulnerable
## damage multiplier — every hit lands at face value (the channel-windup IS
## the player's window, not a separate vulnerability state).
func take_damage(amount: int, knockback: Vector2, source: Node) -> void:
	if _is_dead:
		_combat_trace("BoneCatalyst.take_damage", "IGNORED already_dead amount=%d" % amount)
		return
	var clean_amount: int = max(0, amount)
	var hp_before: int = hp_current
	hp_current = max(0, hp_current - clean_amount)
	_combat_trace(
		"BoneCatalyst.take_damage",
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

	# Harness-observability trace (HTML5-only via the combat_trace shim).
	# Mirrors Grunt.pos / Charger.pos / Shooter.pos / SunkenScholar.pos shape
	# so the existing AC4 multi-chaser clear sub-helper greps map 1:1.
	_pos_trace_accum += delta
	if _pos_trace_accum >= POS_TRACE_INTERVAL:
		_pos_trace_accum = 0.0
		var dist_to_player: float = -1.0
		if _player != null:
			dist_to_player = (_player.global_position - global_position).length()
		_combat_trace(
			"BoneCatalyst.pos",
			(
				"pos=(%.0f,%.0f) state=%s hp=%d dist_to_player=%.0f"
				% [global_position.x, global_position.y, _state, hp_current, dist_to_player]
			)
		)

	match _state:
		STATE_IDLE, STATE_CHASING:
			_process_chase(delta)
		STATE_CHANNELING:
			_process_channel(delta)
		STATE_ATTACKING:
			_process_recover(delta)
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
	if dist <= SLAM_RANGE:
		# In slam range — begin the channel-windup. Direction locked at start;
		# the channel-pose faces this direction for the duration of the windup.
		_begin_channel(to_player.normalized())
		return
	if dist > AGGRO_RADIUS:
		velocity = Vector2.ZERO
		_set_state(STATE_IDLE)
		return
	# Plodding-bruiser approach — slower than Grunt to read as heavy.
	velocity = to_player.normalized() * move_speed
	_set_state(STATE_CHASING)


func _process_channel(_delta: float) -> void:
	# Rooted during the channel-windup. The stationary-pose IS the telegraph
	# (Uma §5.5) — moving during the windup would dilute the read.
	velocity = Vector2.ZERO
	if _channel_left <= 0.0:
		_finish_channel()


func _process_recover(_delta: float) -> void:
	# Bruiser rooted during attack recovery. Zero velocity each tick so the
	# post-contact pushback applied at slam-fire time doesn't persist beyond
	# its single-tick eject — same recovery-velocity-bug guard as
	# Grunt._process_recover (M1 RC re-soak ticket 86c9q804q).
	velocity = Vector2.ZERO
	if _attack_recovery_left <= 0.0:
		_set_state(STATE_CHASING)


# ---- Channel-windup --------------------------------------------------


func _begin_channel(dir: Vector2) -> void:
	# Skip if already channeling (re-entry guard).
	if _state == STATE_CHANNELING:
		return
	_channel_dir = dir
	_channel_left = CHANNEL_DURATION
	_set_state(STATE_CHANNELING)
	_play_attack_telegraph()
	channel_started.emit(dir)
	_combat_trace(
		"BoneCatalyst._begin_channel",
		"dir=(%.2f,%.2f) duration=%.2f" % [dir.x, dir.y, CHANNEL_DURATION]
	)


func _finish_channel() -> void:
	# Direction may have drifted if the player moved during the 0.6 s window.
	# Re-resolve toward the player at strike time so the slam hits where they
	# are NOW — matches the Grunt/Charger pattern (direction at fire time).
	var dir: Vector2 = _channel_dir
	if _player != null:
		var to_player: Vector2 = _player.global_position - global_position
		if to_player.length_squared() > 0.0:
			dir = to_player.normalized()
	_cancel_attack_telegraph_tween()
	_swing_slam(dir)


# ---- Slam strike ------------------------------------------------------


func _swing_slam(dir: Vector2) -> void:
	# Damage routed through the formula utility. Reads MobDef.damage_base +
	# the player's Vigor mitigation. Vigor is read at swing-spawn time, not
	# hit-land time (matches Grunt._swing_light).
	var hit_dmg: int = DamageScript.compute_mob_damage(mob_def, _player_vigor())
	var hb: Hitbox = _spawn_hitbox(
		dir,
		hit_dmg,
		dir * SLAM_KNOCKBACK,
		SLAM_HITBOX_REACH,
		SLAM_HITBOX_RADIUS,
		SLAM_HITBOX_LIFETIME,
	)
	_attack_recovery_left = ATTACK_RECOVERY
	_set_state(STATE_ATTACKING)
	swing_spawned.emit(SWING_KIND_SLAM, hb)
	_apply_post_contact_pushback(dir)


## Apply a one-tick push-back velocity directed away from the player on the
## frame that the slam fires. Same shape as Grunt._apply_post_contact_pushback
## (and Charger._enter_recovery's pushback) — the universal melee-mob
## "don't stick to player" guard (ticket 86c9q96kk).
func _apply_post_contact_pushback(dir: Vector2) -> void:
	var pushback_dir: Vector2 = -dir if dir.length_squared() > 0.0 else Vector2.LEFT
	if _player != null:
		var away: Vector2 = global_position - _player.global_position
		if away.length_squared() > 0.0:
			pushback_dir = away.normalized()
	velocity = pushback_dir * POST_CONTACT_PUSHBACK_SPEED


func _spawn_hitbox(
	dir: Vector2, dmg: int, knockback: Vector2, reach: float, radius: float, lifetime: float
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


# ---- Death ------------------------------------------------------------


func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	_combat_trace("BoneCatalyst._die", "starting death sequence")
	# Cancel any pending action timers so death-during-channel doesn't pop a
	# slam swing on a corpse.
	_channel_left = 0.0
	_attack_recovery_left = 0.0
	_cancel_attack_telegraph_tween()
	velocity = Vector2.ZERO
	_set_state(STATE_DEAD)
	# CRITICAL CONTRACT (Uma combat-visual-feedback.md §3a): mob_died fires
	# at the START of the death sequence; the visual decay doesn't gate loot.
	mob_died.emit(self, global_position, mob_def)
	_play_anim(&"die")
	_spawn_death_particles()
	_play_death_tween()


# ---- Visual feedback helpers -----------------------------------------


## Channel-windup visual — Sprite-tinted brass-flare proxy until the
## PixelLab sprite drops in. Mirrors Grunt._play_attack_telegraph shape; only
## the tint (warm bone-flare vs vivid red) and the hold duration (CHANNEL_-
## DURATION vs LIGHT_TELEGRAPH_DURATION) differ.
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
	var hold_dur: float = max(
		0.0, CHANNEL_DURATION - ATTACK_TELEGRAPH_TWEEN_IN - ATTACK_TELEGRAPH_TWEEN_OUT
	)
	_attack_telegraph_tween.tween_property(
		target, prop, ATTACK_TELEGRAPH_TINT, ATTACK_TELEGRAPH_TWEEN_IN
	)
	_attack_telegraph_tween.tween_property(target, prop, ATTACK_TELEGRAPH_TINT, hold_dur)
	_attack_telegraph_tween.tween_property(
		target, prop, color_at_rest, ATTACK_TELEGRAPH_TWEEN_OUT
	)
	_combat_trace(
		"BoneCatalyst._play_attack_telegraph",
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


## M3W-3 3-branch hit-flash resolver — mirror of Grunt._play_hit_flash.
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
		# actually flashes red (vs Grunt's legacy branch which tweens through
		# pure white). Same shape as SunkenScholar — soft red wash, HTML5 safe.
		var flash_color: Color = HIT_FLASH_TINT
		_hit_flash_tween.tween_property(sprite_rect, "color", flash_color, HIT_FLASH_IN)
		_hit_flash_tween.tween_property(sprite_rect, "color", flash_color, HIT_FLASH_HOLD)
		_hit_flash_tween.tween_property(
			sprite_rect, "color", _sprite_color_at_rest, HIT_FLASH_OUT
		)
	else:
		_hit_flash_tween.tween_property(self, "modulate", HIT_FLASH_TINT, HIT_FLASH_IN)
		_hit_flash_tween.tween_property(self, "modulate", HIT_FLASH_TINT, HIT_FLASH_HOLD)
		_hit_flash_tween.tween_property(self, "modulate", _modulate_at_rest, HIT_FLASH_OUT)


## HTML5 safety-net death tween — see Grunt._play_death_tween for rationale.
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
		_combat_trace("BoneCatalyst._force_queue_free", "already queued — second-caller no-op")
		return
	_combat_trace("BoneCatalyst._force_queue_free", "freeing now")
	queue_free()


## Combat-trace shim — routes through DebugFlags.combat_trace (HTML5-only).
func _combat_trace(tag: String, msg: String = "") -> void:
	var df: Node = null
	if is_inside_tree():
		df = get_tree().root.get_node_or_null("DebugFlags")
	if df != null and df.has_method("combat_trace"):
		df.combat_trace(tag, msg)


# ---- Audio cue wiring -------------------------------------------------


## Connect combat signals to AudioDirector SFX plays. Reuses S1 melee SFX
## ids in Stage 3 — S2-distinct SFX (per audio-direction.md cross-stratum
## ambient pattern) lands in a follow-up audio PR when the S2 mob-cue palette
## ships. Same shape as Grunt — per-cue rename will land alongside the audio
## follow-up, not a structural change.
func _wire_audio_cues() -> void:
	if not damaged.is_connected(_on_damaged_audio):
		damaged.connect(_on_damaged_audio)
	if not mob_died.is_connected(_on_mob_died_audio):
		mob_died.connect(_on_mob_died_audio)
	if not channel_started.is_connected(_on_channel_started_audio):
		channel_started.connect(_on_channel_started_audio)
	if not swing_spawned.is_connected(_on_swing_spawned_audio):
		swing_spawned.connect(_on_swing_spawned_audio)


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


func _on_mob_died_audio(_mob: BoneCatalyst, _pos: Vector2, _def: MobDef) -> void:
	var ad: Node = _resolve_audio_director()
	if ad == null or not ad.has_method("play_sfx"):
		return
	ad.play_sfx(&"sfx-mob-die")


func _on_channel_started_audio(_dir: Vector2) -> void:
	var ad: Node = _resolve_audio_director()
	if ad == null or not ad.has_method("play_sfx"):
		return
	ad.play_sfx(&"sfx-attack-telegraph")


func _on_swing_spawned_audio(_kind: StringName, _hitbox: Node) -> void:
	var ad: Node = _resolve_audio_director()
	if ad == null or not ad.has_method("play_sfx"):
		return
	ad.play_sfx(&"sfx-attack-impact")


# ---- Animation playback (M3W-3 — fires only when AnimatedSprite2D drops in) ---


## Play an animation on the AnimatedSprite2D child. No-op while the
## placeholder ColorRect is in place. Mirrors Grunt._play_anim shape so the
## PixelLab-sprite drop-in is a Sprite-node swap with no Script edit. Anim
## key shape: `<state>_<dir>` per M3W-1 PR #271 SpriteFrames-layout contract.
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
			"BoneCatalyst._play_anim",
			"MISS anim=%s — SpriteFrames lacks this animation key" % anim_name
		)
		return
	if _animated_sprite.animation == anim_name and _animated_sprite.is_playing():
		return
	_animated_sprite.play(anim_name)
	_combat_trace("BoneCatalyst._play_anim", "PLAY anim=%s" % anim_name)


## Direction-suffix resolver: face the player when known, "s" as fallback.
## Same shape as Grunt._compute_facing_dir_suffix.
func _compute_facing_dir_suffix() -> String:
	if _player == null or not is_inside_tree():
		return "s"
	var to_player: Vector2 = _player.global_position - global_position
	if to_player.length_squared() <= 0.0001:
		return "s"
	return _vec_to_dir_suffix(to_player)


static func _vec_to_dir_suffix(v: Vector2) -> String:
	var angle: float = atan2(v.y, v.x)
	var idx: int = int(floor((angle + PI / 8.0) / (PI / 4.0))) + 8
	idx = idx % 8
	const SUFFIXES: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
	return SUFFIXES[idx]


## Spawn an ember burst at the death position. Parented to the room (NOT
## self) so the burst outlives the bruiser's queue_free. Same shape as
## Grunt._spawn_death_particles + SunkenScholar._spawn_death_particles —
## physics-flush safety via call_deferred (per
## `.claude/docs/combat-architecture.md` § "Room-parented CPUParticles2D burst").
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
	# Physics-flush safety: see Grunt._spawn_death_particles + combat-
	# architecture.md § "Room-parented CPUParticles2D burst — reusable idiom".
	room.call_deferred("add_child", burst)
	burst.finished.connect(burst.queue_free)


# ---- Helpers ----------------------------------------------------------


func _tick_timers(delta: float) -> void:
	if _attack_recovery_left > 0.0:
		_attack_recovery_left = max(0.0, _attack_recovery_left - delta)
	if _channel_left > 0.0:
		_channel_left = max(0.0, _channel_left - delta)


func _set_state(new_state: StringName) -> void:
	if new_state == _state:
		return
	var old: StringName = _state
	_state = new_state
	# Diagnostic trace — every transition. Drew persona rule: "No new mob
	# class without trace instrumentation."
	var dist: float = -1.0
	if _player != null and is_inside_tree():
		dist = (_player.global_position - global_position).length()
	_combat_trace(
		"BoneCatalyst._set_state",
		(
			"%s -> %s dist=%.0f pos=(%.0f,%.0f)"
			% [old, new_state, dist, global_position.x, global_position.y]
		)
	)
	# Animation state→anim mapping. STATE_DEAD intentionally omitted — `_die`
	# plays `die_<dir>` explicitly before transitioning.
	match new_state:
		STATE_IDLE, STATE_CHASING:
			_play_anim(&"walk")
		STATE_CHANNELING:
			_play_anim(&"channel")
		STATE_ATTACKING:
			_play_anim(&"slam")
	state_changed.emit(old, new_state)


func _apply_mob_def() -> void:
	if mob_def == null:
		# BoneCatalyst defaults — see runtime declarations above for rationale.
		hp_max = 70
		hp_current = 70
		damage_base = 5
		move_speed = 50.0
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


## Force `motion_mode = MOTION_MODE_FLOATING` — see Grunt._apply_motion_mode
## for full doctrine (M2 W1 ticket 86c9qanu1, universal-bug-class). Every
## CharacterBody2D in this project adopts FLOATING for top-down 2D.
func _apply_motion_mode() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


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
