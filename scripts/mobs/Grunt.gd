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

## Light-attack telegraph started. Visual hooks listen for this to play the
## red-glow attack-incoming signal per player-journey.md Beat 6.
signal light_telegraph_started()

# ---- States ------------------------------------------------------------

const STATE_IDLE: StringName = &"idle"
const STATE_CHASING: StringName = &"chasing"
const STATE_TELEGRAPHING_LIGHT: StringName = &"telegraphing_light"   # pre-swing windup (NEW)
const STATE_ATTACKING: StringName = &"attacking"          # mid-swing recovery
const STATE_TELEGRAPHING_HEAVY: StringName = &"telegraphing_heavy"  # low-HP windup
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

## Light-attack telegraph windup. Player has this long to dodge / get clear.
## Matches Beat 6 spec (~0.4 s). Grunt is rooted during this window.
const LIGHT_TELEGRAPH_DURATION: float = 0.40

## Speed (px/s) of the one-tick push-back velocity applied when the grunt fires
## a swing while at melee range. Gives move_and_slide() a non-zero vector to
## eject the grunt out of an overlap condition — without this the two
## CharacterBody2Ds sit at zero velocity in STATE_ATTACKING and no separation
## is generated, causing the "mob sticks to player" symptom across the general
## mob population (M1 RC re-soak 5, ticket 86c9q96kk). Mirrors
## Charger.POST_CONTACT_PUSHBACK_SPEED + Stratum1Boss.POST_CONTACT_PUSHBACK_SPEED;
## the recovery handler then re-zeroes velocity each tick so the grunt stays
## rooted for the rest of ATTACK_RECOVERY (vulnerability window).
const POST_CONTACT_PUSHBACK_SPEED: float = 60.0

## Attack-telegraph red tint for the Sprite child. All channels sub-1.0 so
## WebGL2/sRGB (HTML5 gl_compatibility) never clamps them — same rule as
## the player swing-flash (PR #137 lesson). Rest color is restored when the
## telegraph window ends or the grunt dies.
const ATTACK_TELEGRAPH_TINT: Color = Color(1.0, 0.30, 0.30, 1.0)  # vivid red, HTML5 safe
const ATTACK_TELEGRAPH_TWEEN_IN: float = 0.060   # fast ramp to red
const ATTACK_TELEGRAPH_TWEEN_OUT: float = 0.060  # fast fade back to rest on swing-fire

## Heavy telegraph windup duration. Player has this long to dodge / get clear.
const HEAVY_TELEGRAPH_DURATION: float = 0.65

## HP fraction at-or-below which the heavy telegraph fires (one-shot).
const HEAVY_TELEGRAPH_HP_FRAC: float = 0.30

## Visual-feedback timings (per `team/uma-ux/combat-visual-feedback.md` §2 + §3).
## Hit-flash: white modulate for 80ms total — 20ms tween-in, 20ms hold,
## 40ms tween-back. Death tween: 200ms scale-down + alpha-fade. Particles:
## 6 ember particles (24 for boss subclass via override).
const HIT_FLASH_IN: float = 0.020
const HIT_FLASH_HOLD: float = 0.020
const HIT_FLASH_OUT: float = 0.040
const DEATH_TWEEN_DURATION: float = 0.200
const DEATH_PARTICLE_COUNT: int = 6
const DEATH_TARGET_SCALE: float = 0.6
const EMBER_LIGHT: Color = Color(1.0, 0.690, 0.400, 1.0)   # #FFB066
const EMBER_DEEP: Color = Color(0.627, 0.180, 0.031, 1.0)  # #A02E08

## Hit-flash modulate tint for the AnimatedSprite2D path (M3W-1 / M3W-3 convention).
## Mirrors `PracticeDummy.HIT_FLASH_TINT` verbatim per the inheritance contract in
## `.claude/docs/combat-architecture.md` § "M3W-1 realized implementation". Sub-1.0
## on every channel for HTML5 HDR-clamp safety; channel-sum delta ≥ 0.20 vs rest white.
## A uniform constant across the M3 mob roster — every mob's hit-flash reads the
## same wash so "I hit something" is unambiguous (vs per-mob tints that would
## confuse the visual grammar).
const HIT_FLASH_TINT: Color = Color(1.0, 0.50, 0.50, 1.0)  # soft red wash, HTML5-safe

## Layer bits (mirror project.godot).
const LAYER_WORLD: int = 1 << 0          # bit 1
const LAYER_PLAYER: int = 1 << 1         # bit 2
const LAYER_ENEMY: int = 1 << 3          # bit 4

const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")
const DamageScript: Script = preload("res://scripts/combat/Damage.gd")

# ---- Inspector --------------------------------------------------------

## The MobDef this grunt instances. Either set in the .tscn at author time,
## or assigned by the spawner before add_child(). If left null, the grunt
## falls back to safe defaults so a bare-instantiated test node still works.
@export var mob_def: MobDef

# ---- Runtime ----------------------------------------------------------

var hp_max: int = 50
var hp_current: int = 50
var damage_base: int = 3  # rebalanced M1 RC soak-4: was 5, now 3 (40% reduction)
var move_speed: float = 60.0

var _state: StringName = STATE_IDLE
var _attack_recovery_left: float = 0.0
var _telegraph_time_left: float = 0.0
var _light_telegraph_left: float = 0.0    # timer for STATE_TELEGRAPHING_LIGHT
var _light_telegraph_dir: Vector2 = Vector2.RIGHT  # direction locked at telegraph start
var _heavy_telegraph_fired: bool = false  # one-shot guard
var _is_dead: bool = false

# Attack-telegraph tween — ref kept so a death-during-telegraph can cancel it.
var _attack_telegraph_tween: Tween = null

# VFX runtime — paired with the hit-flash + death-tween cues from
# `team/uma-ux/combat-visual-feedback.md`. Tween refs are kept so a
# second hit during the flash kills + restarts the running tween (per §2
# edge case) and so the death tween can be queried by tests.
var _hit_flash_tween: Tween = null
var _death_tween: Tween = null
var _modulate_at_rest: Color = Color(1, 1, 1, 1)
var _captured_modulate_at_rest: bool = false

# Hit-flash target — M3W-3 swap to AnimatedSprite2D introduces a third branch:
#   1. AnimatedSprite2D child (production .tscn-loaded grunt)   → tween modulate
#      with HIT_FLASH_TINT red-wash (rest → tint → rest). The painted PixelLab
#      sprite frames are near-white, so a white-to-white tween would be a
#      visible no-op (PR #115 / #140 trap class); the soft-red tint avoids this
#      while preserving the rest of the sprite's painted color. Sub-1.0
#      channels per HTML5 HDR-clamp rule.
#   2. ColorRect child (legacy bare-instantiated tests)         → tween Sprite.color
#      rest → white → rest (pre-M3W-3 Bug C fix pattern, kept for back-compat).
#   3. No Sprite child (bare-instanced test grunts)             → tween self.modulate
#      (preserves Tier 1 reference-change invariant in GUT — the parent-modulate
#      tween is visually a no-op but produces a valid tween-ref change for tests).
#
# `_hit_flash_uses_sprite` is true iff branch (1) OR (2). Branch (1) vs (2) is
# discriminated by `_hit_flash_uses_animated_sprite`.
var _hit_flash_target: CanvasItem = null
var _hit_flash_uses_sprite: bool = false
var _hit_flash_uses_animated_sprite: bool = false
var _sprite_color_at_rest: Color = Color(1, 1, 1, 1)
var _sprite_modulate_at_rest: Color = Color(1, 1, 1, 1)

# AnimatedSprite2D cache (M3W-3) — resolved lazily from get_node_or_null("Sprite")
# so tests that instantiate the production scene get animation-playback hooks
# even when constructed bare. `_animated_sprite_resolved` is true once we've
# checked, so we don't repeat the cast on every state transition.
var _animated_sprite: AnimatedSprite2D = null
var _animated_sprite_resolved: bool = false

## NodePath (or Node ref) to the player. Optional — spawner sets this. If
## unset, the grunt looks for the first node in the "player" group at _ready.
@export var player_node_path: NodePath
var _player: Node2D = null

# Throttle accumulator for the HTML5-only `Grunt.pos` harness-observability
# trace (see `_physics_process`). The Grunt CHASES into melee, so a browser-
# driven spec *can* kill it by near-spawn click-spam when it is the only mob
# crowding the player — but in a 3-mob room (Rooms 05-08) some chasers drift
# out of the fixed-position swing wedge and the click-spam-from-spawn path
# clears the room only 0/3–2/3 of the time (ticket 86c9u05d7). The AC4
# multi-chaser clear sub-helper (tests/playwright/fixtures/kiting-mob-chase.ts)
# fixes that by position-steered pursuit — pursue whichever chaser is out of
# wedge range — and to do that it needs to know where each chaser is. This
# throttled world-coord + distance trace is that readback. Mirrors
# `Shooter.pos` / `Player.pos`; no-op on headless GUT / desktop (combat_trace
# gates on `OS.has_feature("web")`).
var _pos_trace_accum: float = 0.0
## How often the `Grunt.pos` trace emits — see `Player.POS_TRACE_INTERVAL`
## for the rationale (fine enough to steer a pursuit, cheap enough to be a
## no-op on perf; combat_trace is HTML5-only).
const POS_TRACE_INTERVAL: float = 0.25


func _ready() -> void:
	_apply_mob_def()
	_apply_layers()
	_apply_motion_mode()
	_resolve_player()
	_wire_audio_cues()


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
		_combat_trace("Grunt.take_damage", "IGNORED already_dead amount=%d" % amount)
		return
	var clean_amount: int = max(0, amount)
	var hp_before: int = hp_current
	hp_current = max(0, hp_current - clean_amount)
	_combat_trace("Grunt.take_damage",
		"amount=%d hp=%d->%d" % [clean_amount, hp_before, hp_current])
	damaged.emit(clean_amount, hp_current, source)
	# Visual: red-wash hit-flash + hit anim, kicked off only when actual damage
	# was dealt (matches Uma `combat-visual-feedback.md` §2 — skip the i-frame /
	# clamped-to-zero path).
	if clean_amount > 0:
		_play_hit_flash()
		_play_anim(&"hit")
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

	# Harness-observability trace (HTML5-only via the combat_trace shim).
	# Throttled world-coord + distance readback so the AC4 multi-chaser clear
	# sub-helper can pursue this chaser when it drifts out of the player's
	# fixed-position swing wedge — see the `_pos_trace_accum` declaration above
	# and `Shooter.pos` / `Player.pos` for the full rationale. No-op on
	# headless GUT / desktop (combat_trace gates on `OS.has_feature("web")`).
	_pos_trace_accum += delta
	if _pos_trace_accum >= POS_TRACE_INTERVAL:
		_pos_trace_accum = 0.0
		var dist_to_player: float = -1.0
		if _player != null:
			dist_to_player = (_player.global_position - global_position).length()
		_combat_trace("Grunt.pos",
			"pos=(%.0f,%.0f) state=%s hp=%d dist_to_player=%.0f" % [
				global_position.x, global_position.y, _state, hp_current, dist_to_player
			])

	match _state:
		STATE_IDLE, STATE_CHASING:
			_process_chase(delta)
		STATE_TELEGRAPHING_LIGHT:
			_process_light_telegraph(delta)
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
		# In melee range — begin light-attack telegraph (M1 RC soak-4 fix).
		# Lock attack direction and root the grunt for LIGHT_TELEGRAPH_DURATION
		# so the player can see the red-glow windup and react.
		_begin_light_telegraph(to_player.normalized())
		return
	if dist > AGGRO_RADIUS:
		velocity = Vector2.ZERO
		_set_state(STATE_IDLE)
		return
	# Steer toward player.
	velocity = to_player.normalized() * move_speed
	_set_state(STATE_CHASING)


func _process_light_telegraph(_delta: float) -> void:
	# Rooted during the light-attack telegraph window.
	velocity = Vector2.ZERO
	if _light_telegraph_left <= 0.0:
		_finish_light_telegraph()


func _process_recover(_delta: float) -> void:
	# Grunt is rooted during attack recovery. Zero velocity each tick so any
	# residual velocity from the post-contact pushback (applied at swing-fire
	# time to break overlap), the swing-tick knockback, or an in-flight
	# physics impulse cannot persist and slide the grunt away for the whole
	# recovery window. Without this zero-each-tick guard the grunt was
	# observed floating / drifting after a swing — the recovery-velocity bug
	# from M1 RC re-soak (ticket 86c9q804q). Mirrors
	# Stratum1Boss._process_attack_recovery + Charger._process_recover.
	velocity = Vector2.ZERO
	if _attack_recovery_left <= 0.0:
		_set_state(STATE_CHASING)


func _process_telegraph(_delta: float) -> void:
	# During heavy telegraph the grunt is rooted (player can dodge / step out).
	velocity = Vector2.ZERO
	if _telegraph_time_left <= 0.0:
		_finish_heavy_telegraph()


# ---- Light-attack telegraph -------------------------------------------

func _begin_light_telegraph(dir: Vector2) -> void:
	# Skip if already telegraphing (re-entry from same or adjacent tick).
	if _state == STATE_TELEGRAPHING_LIGHT:
		return
	_light_telegraph_dir = dir
	_light_telegraph_left = LIGHT_TELEGRAPH_DURATION
	_set_state(STATE_TELEGRAPHING_LIGHT)
	_play_attack_telegraph()
	light_telegraph_started.emit()
	_combat_trace("Grunt._begin_light_telegraph",
		"dir=(%.2f,%.2f) duration=%.2f" % [dir.x, dir.y, LIGHT_TELEGRAPH_DURATION])


func _finish_light_telegraph() -> void:
	# Direction may have drifted if the player moved during the 0.4 s window.
	# Re-resolve toward the player so the swing hits where they are now — this
	# matches the Charger/Shooter pattern (direction resolves at fire time).
	var dir: Vector2 = _light_telegraph_dir
	if _player != null:
		var to_player: Vector2 = _player.global_position - global_position
		if to_player.length_squared() > 0.0:
			dir = to_player.normalized()
	_cancel_attack_telegraph_tween()
	_swing_light(dir)


## Play the attack-incoming red-glow on the Sprite child for the telegraph
## window (player-journey.md Beat 6). Sub-1.0 tint on all channels for HTML5
## gl_compatibility safety (PR #137 lesson — channels clamped to [0,1] by
## WebGL2/sRGB). Tween targets the Sprite ColorRect child (visible-draw node),
## NOT the parent CharacterBody2D's modulate, to avoid cascade no-ops (PR
## #115/#140 lesson). Falls back to self.modulate for bare-instanced test mobs
## without a Sprite child.
func _play_attack_telegraph() -> void:
	if not is_inside_tree():
		return
	# Resolve the flash target (mirrors _play_hit_flash target resolution).
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
	# Cancel any prior telegraph tween before starting a new one (re-entry guard).
	if _attack_telegraph_tween != null and _attack_telegraph_tween.is_valid():
		_attack_telegraph_tween.kill()
	_attack_telegraph_tween = create_tween()
	var prop: String = "color" if uses_sprite else "modulate"
	# Ramp to red, hold for the rest of the telegraph duration, then snap back
	# at swing-fire time via _cancel_attack_telegraph_tween.
	_attack_telegraph_tween.tween_property(
		target, prop, ATTACK_TELEGRAPH_TINT, ATTACK_TELEGRAPH_TWEEN_IN)
	_attack_telegraph_tween.tween_property(
		target, prop, ATTACK_TELEGRAPH_TINT,
		max(0.0, LIGHT_TELEGRAPH_DURATION - ATTACK_TELEGRAPH_TWEEN_IN - ATTACK_TELEGRAPH_TWEEN_OUT)
	)
	_attack_telegraph_tween.tween_property(target, prop, color_at_rest, ATTACK_TELEGRAPH_TWEEN_OUT)
	_combat_trace("Grunt._play_attack_telegraph",
		"tween_valid=%s tint=(%.2f,%.2f,%.2f)" % [
			_attack_telegraph_tween.is_valid(),
			ATTACK_TELEGRAPH_TINT.r, ATTACK_TELEGRAPH_TINT.g, ATTACK_TELEGRAPH_TINT.b
		])


func _cancel_attack_telegraph_tween() -> void:
	# Kill the telegraph tween cleanly so color returns to rest.
	if _attack_telegraph_tween != null and _attack_telegraph_tween.is_valid():
		_attack_telegraph_tween.kill()
		_attack_telegraph_tween = null


# ---- Swings -----------------------------------------------------------

func _swing_light(dir: Vector2) -> void:
	# Damage routed through the formula utility. Reads MobDef.damage_base +
	# the player's Vigor mitigation. Vigor is read at swing-spawn time, not
	# hit-land time — by-design, mid-swing player stat changes (impossible
	# in M1, but rationalised) don't retroactively alter an in-flight swing.
	var hit_dmg: int = DamageScript.compute_mob_damage(mob_def, _player_vigor())
	var hb: Hitbox = _spawn_hitbox(
		dir,
		hit_dmg,
		dir * LIGHT_KNOCKBACK,
		LIGHT_HITBOX_REACH,
		LIGHT_HITBOX_RADIUS,
		LIGHT_HITBOX_LIFETIME,
	)
	_attack_recovery_left = ATTACK_RECOVERY
	_set_state(STATE_ATTACKING)
	swing_spawned.emit(SWING_KIND_LIGHT, hb)
	_apply_post_contact_pushback(dir)


func _swing_heavy(dir: Vector2) -> void:
	# Heavy = light * HEAVY_DAMAGE_MULTIPLIER on top of the formula output.
	# The formula handles base damage + Vigor mitigation; the heavy multi
	# stays here because it's a *grunt-specific* attack-shape decision (not
	# the player's light/heavy attack-type tag from Damage.gd).
	var base_hit: int = DamageScript.compute_mob_damage(mob_def, _player_vigor())
	var heavy_dmg: int = int(round(float(base_hit) * HEAVY_DAMAGE_MULTIPLIER))
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
	_apply_post_contact_pushback(dir)


## Apply a one-tick push-back velocity directed away from the player on the
## frame that a swing fires. This gives `move_and_slide()` (called at the end
## of `_physics_process`) a non-zero velocity vector to eject the grunt out
## of a player-overlap condition — the root cause of the "mob sticks to
## player" symptom (M1 RC re-soak 5, ticket 86c9q96kk). Mirrors the
## Stratum1Boss melee-swing-time pushback that already validates against
## `tests/integration/test_boss_does_not_stick_after_contact.gd`.
##
## Direction priority:
##   1. Vector from player to grunt (canonical "away from player").
##   2. Negation of the swing direction `dir` if the player ref is unset
##      (test-bare grunt) or grunt+player are at exactly the same point —
##      ensures we never produce a zero-vector pushback when overlap is
##      possible.
##
## On subsequent ticks, `_process_recover` re-zeroes velocity so the
## one-tick push-back is exactly that — one tick — and the grunt remains
## rooted for the rest of the ATTACK_RECOVERY window.
func _apply_post_contact_pushback(dir: Vector2) -> void:
	var pushback_dir: Vector2 = -dir if dir.length_squared() > 0.0 else Vector2.LEFT
	if _player != null:
		var away: Vector2 = global_position - _player.global_position
		if away.length_squared() > 0.0:
			pushback_dir = away.normalized()
	velocity = pushback_dir * POST_CONTACT_PUSHBACK_SPEED


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
	_combat_trace("Grunt._die", "starting death sequence")
	# Cancel any pending action timers so a death-during-telegraph doesn't
	# pop a heavy or light swing on a corpse.
	_telegraph_time_left = 0.0
	_light_telegraph_left = 0.0
	_attack_recovery_left = 0.0
	_cancel_attack_telegraph_tween()
	velocity = Vector2.ZERO
	_set_state(STATE_DEAD)
	# CRITICAL CONTRACT (Uma `combat-visual-feedback.md` §3a): mob_died fires
	# at the START of the death sequence, NOT after the visual tween, so loot
	# drop + room-clear logic execute on the existing frame regardless of the
	# 200ms decay animation. The death tween + ember-burst run *after* this
	# emit; queue_free is called on tween_finished, replacing the old
	# call_deferred("queue_free") that fired instantly.
	mob_died.emit(self, global_position, mob_def)
	# M3W-3 anim: play `die_<dir>` (falling-backward). Concurrent with the
	# parent CharacterBody2D's scale/alpha death-tween — the AnimatedSprite2D
	# advances its 7-frame die anim while the parent fades + scales. Loop=false
	# on `die_*` in Grunt.tres so the anim holds on the last frame until
	# queue_free.
	_play_anim(&"die")
	# Spawn the ember-burst particles, parented to the room (NOT self) so
	# the burst persists past queue_free.
	_spawn_death_particles()
	# Run the scale-down + fade tween, then queue_free on completion.
	_play_death_tween()


# ---- Visual feedback helpers (per Uma `combat-visual-feedback.md`) ---

## §2 hit-flash. M3W-3 3-branch resolver per `.claude/docs/combat-architecture.md`
## § "M3W-1 realized implementation" — production grunt is now AnimatedSprite2D,
## ColorRect path retained for back-compat with bare-instanced tests, modulate
## fallback for sprite-less test edges. See `PracticeDummy._play_hit_flash`
## for the canonical pattern; this mirror is verbatim modulo the `Grunt.` tag.
func _play_hit_flash() -> void:
	if _is_dead:
		return
	if _hit_flash_target == null:
		var sprite: Node = get_node_or_null("Sprite")
		if sprite is AnimatedSprite2D:
			# M3W-3 path — production sprite is an AnimatedSprite2D.
			_hit_flash_target = sprite
			_hit_flash_uses_sprite = true
			_hit_flash_uses_animated_sprite = true
			_sprite_modulate_at_rest = (sprite as AnimatedSprite2D).modulate
		elif sprite is ColorRect:
			# Pre-M3W-3 fallback (legacy bare-instanced test edge).
			_hit_flash_target = sprite
			_hit_flash_uses_sprite = true
			_hit_flash_uses_animated_sprite = false
			_sprite_color_at_rest = (sprite as ColorRect).color
		else:
			# Bare-instanced test grunt (no Sprite child).
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
		# Branch 1: AnimatedSprite2D modulate tween rest → HIT_FLASH_TINT → rest.
		var asprite: AnimatedSprite2D = _hit_flash_target as AnimatedSprite2D
		_hit_flash_tween.tween_property(asprite, "modulate", HIT_FLASH_TINT, HIT_FLASH_IN)
		_hit_flash_tween.tween_property(asprite, "modulate", HIT_FLASH_TINT, HIT_FLASH_HOLD)
		_hit_flash_tween.tween_property(asprite, "modulate", _sprite_modulate_at_rest, HIT_FLASH_OUT)
		_combat_trace("Grunt._play_hit_flash",
			"animated_sprite tween_valid=%s tint=(%.2f,%.2f,%.2f) rest=(%.2f,%.2f,%.2f)" % [
				_hit_flash_tween.is_valid(),
				HIT_FLASH_TINT.r, HIT_FLASH_TINT.g, HIT_FLASH_TINT.b,
				_sprite_modulate_at_rest.r, _sprite_modulate_at_rest.g, _sprite_modulate_at_rest.b
			])
	elif _hit_flash_uses_sprite:
		# Branch 2: ColorRect color tween (legacy).
		var sprite_rect: ColorRect = _hit_flash_target as ColorRect
		_hit_flash_tween.tween_property(sprite_rect, "color", Color(1, 1, 1, 1), HIT_FLASH_IN)
		_hit_flash_tween.tween_property(sprite_rect, "color", Color(1, 1, 1, 1), HIT_FLASH_HOLD)
		_hit_flash_tween.tween_property(sprite_rect, "color", _sprite_color_at_rest, HIT_FLASH_OUT)
		_combat_trace("Grunt._play_hit_flash",
			"sprite tween_valid=%s rest=(%.2f,%.2f,%.2f) target=white" % [
				_hit_flash_tween.is_valid(),
				_sprite_color_at_rest.r,
				_sprite_color_at_rest.g,
				_sprite_color_at_rest.b])
	else:
		# Branch 3: self.modulate fallback (bare-instanced tests).
		_hit_flash_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), HIT_FLASH_IN)
		_hit_flash_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), HIT_FLASH_HOLD)
		_hit_flash_tween.tween_property(self, "modulate", _modulate_at_rest, HIT_FLASH_OUT)
		_combat_trace("Grunt._play_hit_flash",
			"modulate-fallback tween_valid=%s rest=(%.2f,%.2f,%.2f)" %
			[_hit_flash_tween.is_valid(), _modulate_at_rest.r, _modulate_at_rest.g, _modulate_at_rest.b])


## §3a death tween: 200ms parallel scale 1.0→0.6 + modulate.a 1.0→0.0,
## then queue_free on tween_finished.
##
## **HTML5 safety-net (Sponsor soak `embergrave-html5-0e77a92`):** in the
## `gl_compatibility` HTML5 export, the tween's `finished` signal has been
## observed to fire late or not at all, so mobs never queue_free → they keep
## attacking the player → combat loop hangs. To prevent the functional
## regression we ALSO arm a SceneTreeTimer for `DEATH_TWEEN_DURATION + 0.2s`
## that calls `_force_queue_free`. Whichever path triggers first frees the
## node; the second is a guarded no-op (queue_free is idempotent + we early-
## return when the node is already queued / freed). This decouples the combat
## loop from the visual layer so even a fully broken Tween still lets mobs
## die. The 0.2s slack covers HTML5 frame-budget jitter at low-fps.
func _play_death_tween() -> void:
	# Kill any active hit-flash tween — death visuals override.
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
		_hit_flash_tween = null
	if not is_inside_tree():
		# Defensive — bare-instanced test mobs may not be in the tree.
		queue_free()
		return
	_death_tween = create_tween()
	_death_tween.set_parallel(true)
	_death_tween.tween_property(
		self, "scale", Vector2(DEATH_TARGET_SCALE, DEATH_TARGET_SCALE), DEATH_TWEEN_DURATION)
	_death_tween.tween_property(self, "modulate:a", 0.0, DEATH_TWEEN_DURATION)
	_death_tween.finished.connect(_on_death_tween_finished)
	# HTML5 safety-net: parallel timer that fires queue_free even if
	# tween_finished never lands. Slack = 0.2s past the tween duration so
	# the tween (when it works) wins the race and we don't free mid-decay.
	var timer: SceneTreeTimer = get_tree().create_timer(DEATH_TWEEN_DURATION + 0.2)
	timer.timeout.connect(_force_queue_free)
	_combat_trace("Grunt._play_death_tween",
		"tween_valid=%s timer_armed=%.3fs" % [_death_tween.is_valid(), DEATH_TWEEN_DURATION + 0.2])


func _on_death_tween_finished() -> void:
	# Real queue_free now that the visual decay has played.
	_combat_trace("Grunt._on_death_tween_finished", "calling _force_queue_free via tween path")
	_force_queue_free()


## Idempotent queue_free. Safe to call from both the tween-finished path AND
## the HTML5 safety-net timer; whichever lands first wins. Guards on
## is_queued_for_deletion so the second caller is a no-op.
func _force_queue_free() -> void:
	if is_queued_for_deletion():
		_combat_trace("Grunt._force_queue_free", "already queued — second-caller no-op")
		return
	_combat_trace("Grunt._force_queue_free", "freeing now")
	queue_free()


## Combat-trace shim — routes through DebugFlags.combat_trace (HTML5-only).
func _combat_trace(tag: String, msg: String = "") -> void:
	var df: Node = null
	if is_inside_tree():
		df = get_tree().root.get_node_or_null("DebugFlags")
	if df != null and df.has_method("combat_trace"):
		df.combat_trace(tag, msg)


# ---- M3W-7 audio-cue wiring -------------------------------------------

## Connect the existing combat signals to AudioDirector SFX plays.
##   damaged(amount>0)           → SFX_MOB_HIT
##   mob_died                    → SFX_MOB_DIE
##   light_telegraph_started     → SFX_ATTACK_TELEGRAPH (Grunt's light-attack windup)
##   heavy_telegraph_started     → SFX_ATTACK_TELEGRAPH (low-HP heavy windup)
##   swing_spawned               → SFX_ATTACK_IMPACT (light + heavy share — both
##                                  fire on swing-hitbox spawn)
## Idempotent — re-`_ready` does not double-connect.
func _wire_audio_cues() -> void:
	if not damaged.is_connected(_on_damaged_audio):
		damaged.connect(_on_damaged_audio)
	if not mob_died.is_connected(_on_mob_died_audio):
		mob_died.connect(_on_mob_died_audio)
	if not light_telegraph_started.is_connected(_on_telegraph_audio):
		light_telegraph_started.connect(_on_telegraph_audio)
	if not heavy_telegraph_started.is_connected(_on_telegraph_audio):
		heavy_telegraph_started.connect(_on_telegraph_audio)
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


func _on_mob_died_audio(_mob: Grunt, _pos: Vector2, _def: MobDef) -> void:
	var ad: Node = _resolve_audio_director()
	if ad == null or not ad.has_method("play_sfx"):
		return
	ad.play_sfx(&"sfx-mob-die")


func _on_telegraph_audio() -> void:
	var ad: Node = _resolve_audio_director()
	if ad == null or not ad.has_method("play_sfx"):
		return
	ad.play_sfx(&"sfx-attack-telegraph")


func _on_swing_spawned_audio(_kind: StringName, _hitbox: Node) -> void:
	var ad: Node = _resolve_audio_director()
	if ad == null or not ad.has_method("play_sfx"):
		return
	ad.play_sfx(&"sfx-attack-impact")


# ---- Animation playback (M3W-3) --------------------------------------

## Play an animation on the AnimatedSprite2D child. Resolves the child lazily
## on first call so bare-instanced test grunts (no Sprite child or ColorRect
## fallback) no-op safely. `state` is the state-key prefix (`walk`, `atk`,
## `atk_telegraph`, `hit`, `die`); the full SpriteFrames key is
## `<state>_<dir>` where `<dir>` is derived from the grunt's intent — direction
## toward the player when known, last-walk direction otherwise.
##
## M3W-3 convention — mirrors `PracticeDummy._play_anim` with a non-trivial
## `<dir>` resolver (PD is stationary → hardcoded "s"). Grunt always faces the
## player when one exists, so the chase / swing / die animations all read in
## the right direction. If no player is bound (bare-instanced tests), defaults
## to "s" so the call doesn't crash.
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
		_combat_trace("Grunt._play_anim",
			"MISS anim=%s — SpriteFrames lacks this animation key" % anim_name)
		return
	# Only restart if a different anim is queued — re-issuing the same anim
	# on every physics tick (chase loop hits _set_state(CHASING) every tick)
	# would visibly stutter at frame 0. AnimatedSprite2D.play() is idempotent
	# on the SAME animation name (it skips the reset), but we still want the
	# `_play_anim` trace to surface only on actual transitions.
	if _animated_sprite.animation == anim_name and _animated_sprite.is_playing():
		return
	_animated_sprite.play(anim_name)
	_combat_trace("Grunt._play_anim", "PLAY anim=%s" % anim_name)


## Derive the 8-octant direction suffix for the SpriteFrames anim key. Uses
## the vector toward the player when a player ref exists (Grunt chases the
## player, so "facing" = "toward player"); falls back to "s" otherwise. This
## matches the at-swing-time direction resolution already used in
## `_finish_light_telegraph` + `_finish_heavy_telegraph` (the swings re-resolve
## toward the player at fire time), so the played anim is always aimed where
## the swing is going.
func _compute_facing_dir_suffix() -> String:
	if _player == null or not is_inside_tree():
		return "s"
	var to_player: Vector2 = _player.global_position - global_position
	if to_player.length_squared() <= 0.0001:
		return "s"
	return _vec_to_dir_suffix(to_player)


## Convert a Vector2 to its nearest 8-octant compass-direction suffix.
## Uses atan2 with a 22.5° (π/8) half-width per octant. Quadrant boundary
## convention: ties resolve south-biased (top-down 2D player-facing default).
##   angle 0           = east (+x)
##   angle +π/2        = south (+y, screen-down)
##   angle -π/2        = north (-y, screen-up)
## Returns one of: "n", "ne", "e", "se", "s", "sw", "w", "nw".
static func _vec_to_dir_suffix(v: Vector2) -> String:
	var angle: float = atan2(v.y, v.x)  # radians, [-π, π]
	# Map to [0, 8) — 0=east, 1=se, 2=south, 3=sw, 4=west, 5=nw, 6=north, 7=ne.
	# +π/8 offset shifts the boundary so east-leaning vectors snap to east.
	var idx: int = int(floor((angle + PI / 8.0) / (PI / 4.0))) + 8
	idx = idx % 8
	const SUFFIXES: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
	return SUFFIXES[idx]


## §3b ember burst: spawn a CPUParticles2D at this mob's global position,
## parented to the room (get_parent()) so the burst outlives the mob's
## queue_free. 6 particles for normal mobs (24 for the boss subclass).
func _spawn_death_particles() -> void:
	var room: Node = get_parent()
	if room == null:
		# No parent = no room (test edge). Skip the burst — visual-only.
		return
	var burst: CPUParticles2D = CPUParticles2D.new()
	burst.global_position = global_position
	burst.amount = DEATH_PARTICLE_COUNT
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.lifetime = 0.30
	burst.emitting = true
	# 360° spread; 30–60 px/s initial speed; slight upward gravity (embers rise).
	burst.direction = Vector2.UP
	burst.spread = 180.0
	burst.initial_velocity_min = 30.0
	burst.initial_velocity_max = 60.0
	burst.gravity = Vector2(0.0, -40.0)
	# 2×2 logical-px particles per Uma §3b (stays inside the 4-px shake budget).
	burst.scale_amount_min = 1.0
	burst.scale_amount_max = 1.0
	# Color ramp: ember light → ember deep across the particle's lifetime.
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, EMBER_LIGHT)
	ramp.set_color(1, EMBER_DEEP)
	burst.color_ramp = ramp
	# Physics-flush safety: this method is called from `_die`, which itself
	# runs during the physics-step body_entered chain. Adding a Node2D-derived
	# burst node synchronously can trigger Godot 4's "Can't change this state
	# while flushing queries" panic and abort the rest of the death sequence
	# (run-002 P0, ticket TBA — Sponsor's `embergrave-html5-4ab2813` retest).
	# `call_deferred` lands the add_child after the physics flush completes,
	# letting `_play_death_tween` + the `_force_queue_free` safety-net both
	# run cleanly.
	room.call_deferred("add_child", burst)
	burst.finished.connect(burst.queue_free)


# ---- Helpers ----------------------------------------------------------

func _tick_timers(delta: float) -> void:
	if _attack_recovery_left > 0.0:
		_attack_recovery_left = max(0.0, _attack_recovery_left - delta)
	if _telegraph_time_left > 0.0:
		_telegraph_time_left = max(0.0, _telegraph_time_left - delta)
	if _light_telegraph_left > 0.0:
		_light_telegraph_left = max(0.0, _light_telegraph_left - delta)


func _set_state(new_state: StringName) -> void:
	if new_state == _state:
		return
	var old: StringName = _state
	_state = new_state
	# M3W-3 animation playback — map state → SpriteFrames anim key. `hit_<dir>`
	# and `die_<dir>` are driven directly from `take_damage` / `_die` (one-shot
	# beats that interrupt the state-anim); the state-driven mapping covers
	# walk/atk_telegraph/atk. STATE_DEAD intentionally has no entry here — `_die`
	# plays `die_<dir>` explicitly before transitioning (so the play() call
	# survives the state transition's potential re-resolve).
	match new_state:
		STATE_IDLE, STATE_CHASING:
			_play_anim(&"walk")
		STATE_TELEGRAPHING_LIGHT, STATE_TELEGRAPHING_HEAVY:
			_play_anim(&"atk_telegraph")
		STATE_ATTACKING:
			_play_anim(&"atk")
	state_changed.emit(old, new_state)


func _apply_mob_def() -> void:
	if mob_def == null:
		# Bare-instantiated grunt (tests). Use schema defaults already on
		# this node's vars. damage_base = 3 (rebalanced M1 RC soak-4).
		hp_max = 50
		hp_current = 50
		damage_base = 3
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


## Force `motion_mode = MOTION_MODE_FLOATING` so `move_and_slide()` treats
## every axis equally during collision resolution. Without this, the engine
## defaults to `MOTION_MODE_GROUNDED` with `up_direction = (0, -1)`, and
## collisions whose normal aligns with up_direction (player-from-south
## approach) engage floor-snap / floor-stop behavior that suppresses the
## grunt's POST_CONTACT_PUSHBACK velocity along the +up axis.
##
## Universal-bug-class generalization (M2 W1, ticket 86c9qanu1): Stratum1Boss
## surfaced this first because its larger collision radius (24 px) made the
## south-approach asymmetry observable as visible "sticking" (PR #163). The
## same bug class is latent on every CharacterBody2D in the project — Grunt
## (12 px radius) keeps it below the observability threshold but the floor-
## snap on +up-axis pushback still happens. Per the canonical Godot 4 top-
## down 2D pattern, every CharacterBody2D in this project adopts FLOATING.
##
## Documented in `.claude/docs/combat-architecture.md` § "CharacterBody2D
## motion_mode rule".
func _apply_motion_mode() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


## Read the player's Vigor stat for the damage formula. Returns 0 if the
## player ref is unset (test-bare grunt) or the player node doesn't expose
## get_vigor (defensive: no crash if a non-Player target sneaks in).
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
	# Fallback: first node in "player" group.
	var players: Array[Node] = get_tree().get_nodes_in_group("player") if is_inside_tree() else []
	if players.size() > 0 and players[0] is Node2D:
		_player = players[0]
