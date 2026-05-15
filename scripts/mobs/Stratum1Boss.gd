class_name Stratum1Boss
extends CharacterBody2D
## Stratum-1 boss — 3-phase melee+AoE encounter that is the climax of M1.
##
## Design source: `team/uma-ux/boss-intro.md` (Uma — binding) +
## `team/priya-pl/mvp-scope.md` AC #6 (boss must be defeatable). Phases
## transition at 66% and 33% of max HP; segments lie about HP-equality on
## the nameplate by design (Uma, "phases are narrative gates not literal HP
## brackets"). Drew owns the internal HP weights and attack patterns.
##
## Decisions encoded here (Drew owns AI internals per dispatch authority):
##   - Phase HP weights (lie-segments): P1 = 50%, P2 = 30%, P3 = 20% of
##     max_hp. With max_hp = 600 this gives 300/180/120 per phase. The
##     transitions still fire at 66% and 33% of max_hp so the bar's
##     visual segments line up with phase changes regardless of weight.
##   - Phase 1: signature heavy melee swing only (telegraphed, slow).
##   - Phase 2: phase-1 melee + AoE ground-slam (8-direction radial damage,
##     ~0.5 s windup, big readable telegraph).
##   - Phase 3: enraged. Both attacks remain; movement speed +50%, attack
##     recovery shortened by 30%. NO new attack mechanic per M1 scope.
##   - Phase transition (66% / 33% HP): a 0.6 s "phase break" during which
##     world-time is conceptually slowed (Uma: 30% world-time, but the
##     boss controller doesn't drive Engine.time_scale — that's Devon's
##     `BossDefeatedSequence` / cinematic layer's job). What the controller
##     DOES guarantee: the boss is **stagger-immune AND damage-immune**
##     during the transition window so the player can't double-trigger the
##     next phase by spamming hits during the slow-mo. Tests assert this.
##   - Death: only the run's true world-time-freeze (per Uma's design).
##     Again, the freeze itself is Devon's cinematic layer; the controller
##     emits `boss_died` with (mob, position, mob_def) — same payload shape
##     as Grunt/Charger so MobLootSpawner.on_mob_died works unchanged.
##   - Layer convention (DECISIONS.md 2026-05-01): collision_layer = enemy
##     (bit 4), collision_mask = world (bit 1) + player (bit 2). Spawned
##     hitboxes sit on enemy_hitbox (bit 5) and mask player (bit 2). Same
##     as Grunt/Charger — the player's i-frames work uniformly.
##   - Phase-transition guards: rapid hit spam straddling 66% or 33% must
##     emit `phase_changed` exactly once per boundary (idempotent latch).
##     Tests assert this.
##   - Entry sequence: the boss starts in STATE_DORMANT. Combat doesn't
##     begin until something calls `wake()` — typically the boss room's
##     `BossRoomTrigger` after the 1.8 s entry sequence completes. While
##     dormant, the boss takes no actions, deals no damage, and ignores
##     incoming damage (intro is fairness-protected per Uma BI-19: boss
##     does not attack during Beats 1–4).
##
## Tunable timings live as constants below; balance values come from MobDef.
## Constants are shape (timing/distance), MobDef is magnitude (HP/dmg/speed).

# ---- Signals ------------------------------------------------------------

## State transitioned. New state on the right.
signal state_changed(from_state: StringName, to_state: StringName)

## Took damage. Emitted after HP is decremented but before death is checked.
signal damaged(amount: int, hp_remaining: int, source: Node)

## Phase changed. Carries the new phase index (2 or 3 in M1; phase 1 is
## the entry phase and never re-emits this signal). Fires exactly once per
## boundary even under hit-spam (idempotent latch).
signal phase_changed(new_phase: int)

## A swing/slam hitbox spawned. `kind` = &"melee", &"slam_telegraph",
## or &"slam_hit". Useful for tests + audio hooks.
signal swing_spawned(kind: StringName, hitbox: Node)

## Entry sequence completed — boss is awake and combat begins. Fired by
## `wake()` (the BossRoomTrigger's entry-sequence completion handler calls
## this).
signal boss_woke()

## HP hit zero. Emitted exactly once per life. Carries (mob, position, def)
## — same payload shape as Grunt/Charger so MobLootSpawner reuses unchanged.
## This is the run's climax — Uma calls it "the only true world-time-freeze
## moment in M1". The cinematic layer subscribes to this to drive
## `BossDefeatedSequence`.
signal boss_died(mob: Stratum1Boss, death_position: Vector2, mob_def: MobDef)

# ---- States ------------------------------------------------------------

const STATE_DORMANT: StringName = &"dormant"            # pre-wake (intro)
const STATE_IDLE: StringName = &"idle"                  # awake, no target
const STATE_CHASING: StringName = &"chasing"
const STATE_TELEGRAPHING_MELEE: StringName = &"telegraphing_melee"
const STATE_ATTACKING: StringName = &"attacking"        # melee swing recovery
const STATE_TELEGRAPHING_SLAM: StringName = &"telegraphing_slam"
const STATE_SLAM_RECOVERY: StringName = &"slam_recovery"
const STATE_PHASE_TRANSITION: StringName = &"phase_transition"
const STATE_DEAD: StringName = &"dead"

const SWING_KIND_MELEE: StringName = &"melee"
const SWING_KIND_SLAM_TELEGRAPH: StringName = &"slam_telegraph"
const SWING_KIND_SLAM_HIT: StringName = &"slam_hit"

# ---- Phases ------------------------------------------------------------

const PHASE_1: int = 1
const PHASE_2: int = 2
const PHASE_3: int = 3

## Phase boundaries as fractions of max_hp. The controller compares
## `hp_current` against `int(round(hp_max * frac))` so 600 HP resolves to
## clean integer thresholds (396, 198) without floating-point edge cases.
const PHASE_2_HP_FRAC: float = 0.66
const PHASE_3_HP_FRAC: float = 0.33

# ---- Tuning (shape) ----------------------------------------------------

## Aggro radius — same M1 reach as Grunt/Charger. Boss room is one screen
## (480 px wide) so the boss always engages once awake.
const AGGRO_RADIUS: float = 480.0

## Distance at which the boss commits to a melee swing rather than chasing.
const MELEE_RANGE: float = 36.0

## Recovery after a melee swing (phase 1/2 base).
const MELEE_RECOVERY: float = 0.65

## Melee telegraph windup — slow, readable. Player can dodge through it.
const MELEE_TELEGRAPH_DURATION: float = 0.55

## Melee hitbox spec.
const MELEE_HITBOX_REACH: float = 44.0
const MELEE_HITBOX_RADIUS: float = 28.0
const MELEE_HITBOX_LIFETIME: float = 0.14
const MELEE_KNOCKBACK: float = 320.0
const MELEE_DAMAGE_MULTIPLIER: float = 1.0

## AoE slam telegraph — player has this long to back off.
const SLAM_TELEGRAPH_DURATION: float = 0.50

## Slam radius and damage. Bigger than melee, slower to wind up, recovers
## longer — the trade-off for being undodgeable except by distance.
const SLAM_HITBOX_RADIUS: float = 80.0
const SLAM_HITBOX_LIFETIME: float = 0.18
const SLAM_KNOCKBACK: float = 360.0
const SLAM_DAMAGE_MULTIPLIER: float = 1.4
const SLAM_RECOVERY: float = 0.85

## Cooldown (in real seconds) the boss waits between picking the slam
## attack again. Without this the boss would stack slams back-to-back; the
## cooldown forces alternation between melee and slam in phases 2/3.
const SLAM_COOLDOWN: float = 4.0

## Phase-transition window. During this window the boss is stagger AND
## damage immune (per Uma's design: no double-triggering by hit-spam).
## Wraps the world-time-slow that Devon's cinematic layer applies.
const PHASE_TRANSITION_DURATION: float = 0.60

## Speed (px/s) of the one-tick push-back velocity applied immediately after a
## melee swing fires. Gives move_and_slide() a non-zero vector to eject the
## boss from a player-overlap condition — the root cause of Bug 2 ("mob sticks
## to player after contact-attack", M1 RC re-soak 3). The velocity is applied
## at swing-fire time and decays naturally on the next physics tick when
## _process_attack_recovery returns without setting velocity.
const POST_CONTACT_PUSHBACK_SPEED: float = 60.0

## Phase 3 enrage modifiers — applied multiplicatively on top of MobDef base.
const ENRAGE_SPEED_MULT: float = 1.5
const ENRAGE_RECOVERY_MULT: float = 0.7  # 30% shorter recoveries

## Visual-feedback timings (per `team/uma-ux/combat-visual-feedback.md` §2 + §3).
## Boss climax: same shape as grunts but bumps to 24 particles + 4-px
## screen-shake (within VD-09 budget) + an extra 400ms hold *before* the
## scale-down + fade plays. Hit-flash matches the cross-mob 80ms rule.
const HIT_FLASH_IN: float = 0.020
const HIT_FLASH_HOLD: float = 0.020
const HIT_FLASH_OUT: float = 0.040
const DEATH_TWEEN_DURATION: float = 0.200
const DEATH_PARTICLE_COUNT: int = 24
const DEATH_TARGET_SCALE: float = 0.6
const BOSS_DEATH_HOLD: float = 0.400
const BOSS_SHAKE_MAGNITUDE: float = 4.0   # logical px (VD-09 max budget)
const BOSS_SHAKE_DURATION: float = 0.150
const EMBER_LIGHT: Color = Color(1.0, 0.690, 0.400, 1.0)   # #FFB066
const EMBER_DEEP: Color = Color(0.627, 0.180, 0.031, 1.0)  # #A02E08

## Layer bits (mirror project.godot — same as Grunt/Charger).
const LAYER_WORLD: int = 1 << 0          # bit 1
const LAYER_PLAYER: int = 1 << 1         # bit 2
const LAYER_ENEMY: int = 1 << 3          # bit 4

const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")
const DamageScript: Script = preload("res://scripts/combat/Damage.gd")

# ---- Inspector --------------------------------------------------------

## The MobDef this boss instances. Spawner sets it before add_child(), or
## the .tscn ships with `stratum1_boss.tres` ext-resourced. If null, safe
## defaults apply so a bare-instantiated test node works.
@export var mob_def: MobDef

## NodePath to the player. Optional — set by the spawner / boss room. If
## unset, falls back to the first node in the "player" group on _ready.
@export var player_node_path: NodePath

## If true, the boss starts in STATE_IDLE rather than STATE_DORMANT — useful
## for headless tests that don't want to manually call `wake()` on every
## construction. Production .tscn ships with this false.
@export var skip_intro_for_tests: bool = false

# ---- Runtime ----------------------------------------------------------

var hp_max: int = 600
var hp_current: int = 600
var damage_base: int = 12  # rebalanced M1 RC soak-4: was 15, now 12 (20% reduction)
var move_speed_base: float = 80.0
var move_speed: float = 80.0  # may be enrage-multiplied in phase 3

var phase: int = PHASE_1

var _state: StringName = STATE_DORMANT
var _melee_telegraph_left: float = 0.0
var _melee_recovery_left: float = 0.0
var _slam_telegraph_left: float = 0.0
var _slam_recovery_left: float = 0.0
var _slam_cooldown_left: float = 0.0
var _phase_transition_left: float = 0.0

# Idempotent phase-change latches — prevent rapid-hit-spam from re-firing
# `phase_changed` for the same boundary. Set true the moment the boundary
# is first crossed; never reset.
var _phase_2_latched: bool = false
var _phase_3_latched: bool = false

var _is_dead: bool = false

# Pending phase to enter after the current phase-transition window expires.
# Set when a transition begins; consumed when the window ends.
var _pending_phase: int = PHASE_1

var _player: Node2D = null

# VFX runtime — see `team/uma-ux/combat-visual-feedback.md` §2 + §3 climax.
var _hit_flash_tween: Tween = null
var _death_tween: Tween = null
var _shake_tween: Tween = null
var _modulate_at_rest: Color = Color(1, 1, 1, 1)
var _captured_modulate_at_rest: bool = false

# Hit-flash target — Sprite child (Bug C fix). See Grunt.gd for full rationale.
var _hit_flash_target: CanvasItem = null
var _hit_flash_uses_sprite: bool = false
var _sprite_color_at_rest: Color = Color(1, 1, 1, 1)

# Attack-telegraph tween — ref kept so death-during-telegraph can cancel it.
var _attack_telegraph_tween: Tween = null

## Red tint for melee/slam telegraph (player-journey.md Beat 6). Sub-1.0 all
## channels for HTML5 gl_compatibility safety (PR #137 lesson). Brighter than
## grunts to make the boss wind-up clearly readable.
const ATTACK_TELEGRAPH_TINT: Color = Color(1.0, 0.25, 0.25, 1.0)  # vivid red, HTML5 safe
const ATTACK_TELEGRAPH_TWEEN_IN: float = 0.080


func _ready() -> void:
	_apply_mob_def()
	_apply_layers()
	_apply_motion_mode()
	_resolve_player()
	if skip_intro_for_tests:
		_state = STATE_IDLE


# ---- Public API -------------------------------------------------------

func get_state() -> StringName:
	return _state


func get_hp() -> int:
	return hp_current


func get_max_hp() -> int:
	return hp_max


func get_phase() -> int:
	return phase


func is_dead() -> bool:
	return _is_dead


func is_dormant() -> bool:
	return _state == STATE_DORMANT


## True during the 0.6 s phase-transition window (stagger + damage immune).
func is_in_phase_transition() -> bool:
	return _state == STATE_PHASE_TRANSITION


## True during phase 3 — drives the enrage VFX hooks if any.
func is_enraged() -> bool:
	return phase == PHASE_3


## Inject the player target. Tests + spawner use this for determinism.
func set_player(p: Node2D) -> void:
	_player = p


## Force-apply a MobDef post-_ready (test convenience).
func apply_mob_def(def: MobDef) -> void:
	mob_def = def
	_apply_mob_def()


## Wake the boss — called by `BossRoomTrigger` after the 1.8 s entry
## sequence completes. From here on the boss can act, take damage, and die.
## Idempotent — calling twice has no extra effect.
func wake() -> void:
	if _state != STATE_DORMANT:
		return
	# [combat-trace] diagnostic (ticket 86c9ujq8d — finding 1): confirms the
	# boss successfully exited DORMANT and can now engage the player. If this
	# line never appears in the soak stream, the entry sequence timer did not
	# fire — look for `trigger_entry_sequence` call (auto-fire in
	# `_assemble_room_fixtures`) and the SceneTreeTimer creation path.
	_combat_trace("Stratum1Boss.wake",
		"exiting STATE_DORMANT — boss now IDLE, combat enabled")
	_set_state(STATE_IDLE)
	boss_woke.emit()


## Take damage. Duck-typed contract matched by `Hitbox.gd`.
##
##   - Damage during STATE_DEAD is ignored.
##   - Damage during STATE_DORMANT is ignored (intro fairness protection).
##   - Damage during STATE_PHASE_TRANSITION is ignored (Uma's stagger-
##     immune-during-transition rule + idempotent phase-change guard).
##   - Negative amounts clamped to 0.
##   - Phase boundaries (66%, 33%) latch exactly once each (idempotent).
##   - mob_died emits exactly once on the death-transition.
func take_damage(amount: int, knockback: Vector2, source: Node) -> void:
	if _is_dead:
		_combat_trace("Stratum1Boss.take_damage", "IGNORED already_dead amount=%d" % amount)
		return
	if _state == STATE_DORMANT:
		# Intro fairness — no damage during entry sequence.
		# Trace this case explicitly so soak-debugging can distinguish "hit didn't
		# register" (Hitbox layer/mask issue) from "hit was rejected" (boss still
		# dormant — the M2 W1 P0 root cause). Wired against `86c9q96fv`.
		_combat_trace("Stratum1Boss.take_damage",
			"IGNORED dormant amount=%d hp=%d (boss still in entry sequence)" % [amount, hp_current])
		return
	if _state == STATE_PHASE_TRANSITION:
		_combat_trace("Stratum1Boss.take_damage",
			"IGNORED phase_transition amount=%d hp=%d (stagger-immune window)" % [amount, hp_current])
		return  # stagger-immune during the 0.6 s phase break (Uma)
	var clean_amount: int = max(0, amount)
	var hp_before: int = hp_current
	hp_current = max(0, hp_current - clean_amount)
	_combat_trace("Stratum1Boss.take_damage",
		"amount=%d hp=%d->%d phase=%d" % [clean_amount, hp_before, hp_current, phase])
	damaged.emit(clean_amount, hp_current, source)
	# Visual: white hit-flash on every actual-damage take_damage (Uma §2 —
	# same rule across all mob types).
	if clean_amount > 0:
		_play_hit_flash()
	# Knockback applied as instantaneous velocity. Boss is a heavy unit so
	# the actual visual displacement is small; this still gives the player
	# the satisfaction of "I hit it." We skip knockback during the
	# slam-telegraph windup so the slam stays predictable for the player —
	# same rationale as Charger skipping knockback mid-charge.
	if _state != STATE_TELEGRAPHING_SLAM and knockback.length_squared() > 0.0:
		velocity = knockback
	if hp_current == 0:
		_die()
		return
	_check_phase_boundaries()


# ---- Physics tick -----------------------------------------------------

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	if _state == STATE_DORMANT:
		# Frozen during intro — no timer ticks, no movement, no AI.
		velocity = Vector2.ZERO
		move_and_slide()
		return
	_tick_timers(delta)

	# Phase-transition window — when it expires, commit the pending phase.
	if _state == STATE_PHASE_TRANSITION:
		velocity = Vector2.ZERO
		if _phase_transition_left <= 0.0:
			_finish_phase_transition()
		move_and_slide()
		return

	match _state:
		STATE_IDLE, STATE_CHASING:
			_process_chase(delta)
		STATE_TELEGRAPHING_MELEE:
			_process_melee_telegraph(delta)
		STATE_ATTACKING:
			_process_attack_recovery(delta)
		STATE_TELEGRAPHING_SLAM:
			_process_slam_telegraph(delta)
		STATE_SLAM_RECOVERY:
			_process_slam_recovery(delta)
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
	# Phase 2/3: prefer slam if cooldown is clear and player is in slam range.
	if phase >= PHASE_2 and _slam_cooldown_left <= 0.0 and dist <= SLAM_HITBOX_RADIUS:
		_begin_slam_telegraph()
		return
	if dist <= MELEE_RANGE:
		_begin_melee_telegraph(to_player.normalized())
		return
	if dist > AGGRO_RADIUS:
		velocity = Vector2.ZERO
		_set_state(STATE_IDLE)
		return
	velocity = to_player.normalized() * move_speed
	_set_state(STATE_CHASING)


func _process_melee_telegraph(_delta: float) -> void:
	# Rooted during windup — player can dodge / step out.
	velocity = Vector2.ZERO
	if _melee_telegraph_left <= 0.0:
		_fire_melee_swing()


func _process_attack_recovery(_delta: float) -> void:
	# Boss is rooted during melee recovery. Zero velocity each tick so the
	# post-contact pushback (applied at swing-fire time to break overlap) does
	# not persist and slide the boss away for the whole recovery window.
	velocity = Vector2.ZERO
	if _melee_recovery_left <= 0.0:
		_set_state(STATE_CHASING)


func _process_slam_telegraph(_delta: float) -> void:
	velocity = Vector2.ZERO
	if _slam_telegraph_left <= 0.0:
		_fire_slam_hit()


func _process_slam_recovery(_delta: float) -> void:
	velocity = Vector2.ZERO
	if _slam_recovery_left <= 0.0:
		_set_state(STATE_CHASING)


# ---- Melee attack -----------------------------------------------------

func _begin_melee_telegraph(dir: Vector2) -> void:
	# Scale telegraph and recovery by enrage modifier in phase 3.
	var t_mult: float = ENRAGE_RECOVERY_MULT if phase == PHASE_3 else 1.0
	_melee_telegraph_left = MELEE_TELEGRAPH_DURATION * t_mult
	# Stash direction in velocity (zeroed in handler) — we re-resolve on fire.
	_set_state(STATE_TELEGRAPHING_MELEE)
	# Attack-telegraph visual: red-glow on Sprite child (player-journey.md Beat 6
	# + M1 RC soak-4 fix). Telegraph duration for tween = actual armed duration.
	_play_attack_telegraph(MELEE_TELEGRAPH_DURATION * t_mult)
	# A telegraph "tell" hitbox would emit here; we only emit the actual
	# hitbox on swing-fire so test assertions stay simple.


func _fire_melee_swing() -> void:
	var dir: Vector2 = Vector2.RIGHT
	if _player != null:
		var to_player: Vector2 = _player.global_position - global_position
		if to_player.length_squared() > 0.0:
			dir = to_player.normalized()
	# Damage routed through the formula utility. Reads MobDef.damage_base +
	# the player's Vigor mitigation at swing-fire time. The melee-multiplier
	# is a *boss-specific* attack-shape decision, applied on top of the
	# formula output — same pattern as Grunt's heavy swing.
	var formula_dmg: int = DamageScript.compute_mob_damage(mob_def, _player_vigor())
	var dmg: int = int(round(float(formula_dmg) * MELEE_DAMAGE_MULTIPLIER))
	# [combat-trace] diagnostic (ticket 86c9ujq8d — M2 W3 soak finding 1 — boss
	# can't hit player). Emits BEFORE hitbox spawn so Sponsor's DevTools stream
	# can distinguish "swing never fired" from "swing fired but hitbox didn't
	# connect." Cross-reference with `Hitbox.hit` trace: if this line appears but
	# no matching `Hitbox.hit team=enemy target=Player` line follows within ~8
	# frames (MELEE_HITBOX_LIFETIME=0.14s ≈ 8 frames at 60fps), the hitbox
	# spawned but body_entered never fired — look for wrong layer/mask or the
	# player being on iframes (collision_layer cleared to 0 during dodge).
	var player_dist: float = -1.0
	if _player != null:
		player_dist = global_position.distance_to(_player.global_position)
	_combat_trace("Stratum1Boss._fire_melee_swing",
		"dir=(%.2f,%.2f) dmg=%d reach=%.0f radius=%.0f lifetime=%.2f player_dist=%.1f phase=%d" % [
			dir.x, dir.y, dmg, MELEE_HITBOX_REACH, MELEE_HITBOX_RADIUS,
			MELEE_HITBOX_LIFETIME, player_dist, phase
		])
	var hb: Hitbox = _spawn_hitbox(
		dir,
		dmg,
		dir * MELEE_KNOCKBACK,
		MELEE_HITBOX_REACH,
		MELEE_HITBOX_RADIUS,
		MELEE_HITBOX_LIFETIME,
	)
	var rec_mult: float = ENRAGE_RECOVERY_MULT if phase == PHASE_3 else 1.0
	_melee_recovery_left = MELEE_RECOVERY * rec_mult
	_set_state(STATE_ATTACKING)
	swing_spawned.emit(SWING_KIND_MELEE, hb)
	# Apply a brief push-back velocity away from the player on swing-fire.
	# This gives move_and_slide() the non-zero vector it needs to eject the
	# boss from a player-overlap condition — the root cause of Bug 2
	# ("mob sticks to player after contact-attack", M1 RC re-soak 3).
	# _process_attack_recovery does NOT override velocity, so this survives
	# to the move_and_slide() call at the bottom of _physics_process.
	if _player != null:
		var away: Vector2 = global_position - _player.global_position
		velocity = (away.normalized() if away.length_squared() > 0.0 else -dir) * POST_CONTACT_PUSHBACK_SPEED
	else:
		velocity = -dir * POST_CONTACT_PUSHBACK_SPEED


# ---- Slam attack ------------------------------------------------------

func _begin_slam_telegraph() -> void:
	var t_mult: float = ENRAGE_RECOVERY_MULT if phase == PHASE_3 else 1.0
	_slam_telegraph_left = SLAM_TELEGRAPH_DURATION * t_mult
	_set_state(STATE_TELEGRAPHING_SLAM)
	# Attack-telegraph visual: red-glow for slam wind-up.
	_play_attack_telegraph(SLAM_TELEGRAPH_DURATION * t_mult)
	# A "telegraph" marker hitbox — zero damage, big radius, short life —
	# lets the player see the danger zone. We spawn it as a real Hitbox on
	# enemy_hitbox layer with damage=0 so it doesn't actually hurt — purely
	# for test inspection + future VFX hook.
	var marker: Hitbox = _spawn_hitbox(
		Vector2.ZERO,
		0,
		Vector2.ZERO,
		0.0,
		SLAM_HITBOX_RADIUS,
		_slam_telegraph_left,
	)
	swing_spawned.emit(SWING_KIND_SLAM_TELEGRAPH, marker)


func _fire_slam_hit() -> void:
	# Damage routed through the formula utility, then scaled by the slam-
	# specific multiplier (boss attack-shape, separate from Damage.gd's
	# player-attack-type-mult).
	var formula_dmg: int = DamageScript.compute_mob_damage(mob_def, _player_vigor())
	var dmg: int = int(round(float(formula_dmg) * SLAM_DAMAGE_MULTIPLIER))
	# Slam is omnidirectional — knockback from boss center outward.
	var kb_dir: Vector2 = Vector2.RIGHT
	if _player != null:
		var to_player: Vector2 = _player.global_position - global_position
		if to_player.length_squared() > 0.0:
			kb_dir = to_player.normalized()
	# [combat-trace] diagnostic — same rationale as _fire_melee_swing trace.
	var player_dist: float = -1.0
	if _player != null:
		player_dist = global_position.distance_to(_player.global_position)
	_combat_trace("Stratum1Boss._fire_slam_hit",
		"dmg=%d radius=%.0f lifetime=%.2f kb_dir=(%.2f,%.2f) player_dist=%.1f phase=%d" % [
			dmg, SLAM_HITBOX_RADIUS, SLAM_HITBOX_LIFETIME,
			kb_dir.x, kb_dir.y, player_dist, phase
		])
	var hb: Hitbox = _spawn_hitbox(
		Vector2.ZERO,
		dmg,
		kb_dir * SLAM_KNOCKBACK,
		0.0,
		SLAM_HITBOX_RADIUS,
		SLAM_HITBOX_LIFETIME,
	)
	var rec_mult: float = ENRAGE_RECOVERY_MULT if phase == PHASE_3 else 1.0
	_slam_recovery_left = SLAM_RECOVERY * rec_mult
	_slam_cooldown_left = SLAM_COOLDOWN
	_set_state(STATE_SLAM_RECOVERY)
	swing_spawned.emit(SWING_KIND_SLAM_HIT, hb)


# ---- Hitbox spawn helper ---------------------------------------------

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
	# [combat-trace] diagnostic (ticket 86c9ujq8d — M2 W3 soak finding 1).
	# After add_child, Hitbox._ready has run and _apply_team_layers set the
	# layer/mask. Monitoring is still FALSE here (will be deferred-enabled by
	# Hitbox._activate_and_check_initial_overlaps next tick). This trace lets
	# the Playwright spec or Sponsor's DevTools confirm the hitbox is in the
	# tree with the correct TEAM_ENEMY layer config and that monitoring=false
	# pre-defer is intentional.
	# Expected: layer=16 (enemy_hitbox, bit 5), mask=2 (player, bit 2).
	_combat_trace("Stratum1Boss._spawn_hitbox",
		"id=%d pos=(%.0f,%.0f) layer=%d mask=%d monitoring=%s dmg=%d radius=%.0f lifetime=%.2f" % [
			hb.get_instance_id(), hb.global_position.x, hb.global_position.y,
			hb.collision_layer, hb.collision_mask, str(hb.monitoring),
			dmg, radius, lifetime
		])
	return hb


# ---- Phase transitions ------------------------------------------------

func _check_phase_boundaries() -> void:
	# Idempotent latches: once latched, never re-fire even if HP fluctuates
	# (it can't go up — but rapid hit-spam straddling the boundary in one
	# tick must still emit `phase_changed` exactly once).
	var phase_2_threshold: int = int(round(hp_max * PHASE_2_HP_FRAC))
	var phase_3_threshold: int = int(round(hp_max * PHASE_3_HP_FRAC))
	if not _phase_2_latched and hp_current <= phase_2_threshold:
		_phase_2_latched = true
		_begin_phase_transition(PHASE_2)
		return
	if not _phase_3_latched and hp_current <= phase_3_threshold:
		_phase_3_latched = true
		_begin_phase_transition(PHASE_3)


func _begin_phase_transition(target_phase: int) -> void:
	_pending_phase = target_phase
	_phase_transition_left = PHASE_TRANSITION_DURATION
	# Cancel any in-flight attack timers — the transition window resets the
	# boss's posture so the next phase opens cleanly. Without this a slam
	# fired right before 33% HP would land while the world-time-slow is
	# active, which contradicts Uma's "boss does not act during transition."
	_melee_telegraph_left = 0.0
	_melee_recovery_left = 0.0
	_slam_telegraph_left = 0.0
	_slam_recovery_left = 0.0
	velocity = Vector2.ZERO
	_set_state(STATE_PHASE_TRANSITION)


func _finish_phase_transition() -> void:
	phase = _pending_phase
	if phase == PHASE_3:
		# Enrage: speed up movement; recovery multipliers are read at
		# attack-fire time so they take effect on next swing.
		move_speed = move_speed_base * ENRAGE_SPEED_MULT
	# Slam cooldown resets going into a new phase so phase 2 can immediately
	# go for the new mechanic.
	_slam_cooldown_left = 0.0
	# Re-engage the player.
	_set_state(STATE_CHASING)
	phase_changed.emit(phase)


# ---- Death ------------------------------------------------------------

func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	_combat_trace("Stratum1Boss._die", "starting death sequence at hp=%d phase=%d" % [hp_current, phase])
	# Cancel every pending action so a death-mid-attack doesn't fire from
	# the corpse. Same defensive pattern as Grunt/Charger.
	_melee_telegraph_left = 0.0
	_melee_recovery_left = 0.0
	_slam_telegraph_left = 0.0
	_slam_recovery_left = 0.0
	_phase_transition_left = 0.0
	velocity = Vector2.ZERO
	_cancel_attack_telegraph_tween()
	_set_state(STATE_DEAD)
	# CRITICAL CONTRACT (Uma `combat-visual-feedback.md` §3a): boss_died
	# fires at the START of the death sequence (this frame), NOT after the
	# climax decay. The cinematic layer + MobLootSpawner.on_mob_died run on
	# this frame regardless of the +400ms hold + 200ms tween below.
	boss_died.emit(self, global_position, mob_def)
	# Climax burst: 24 ember particles parented to the room.
	_spawn_death_particles()
	# Climax shake: 4-logical-px screen-shake within VD-09 budget.
	_play_climax_shake()
	# Climax tween: extra 400ms hold *then* the standard 200ms decay.
	_play_boss_death_sequence()


# ---- Visual feedback helpers (per Uma `combat-visual-feedback.md`) ---

## Attack-telegraph visual (player-journey.md Beat 6 + M1 RC soak-4):
## tween Sprite child's color to red for the melee/slam telegraph window.
## `telegraph_duration` is the actual armed duration (varies with phase 3 enrage).
## Sub-1.0 all channels for HTML5 gl_compatibility safety (PR #137 lesson).
## Targets Sprite child (visible-draw node) not parent modulate (PR #115 lesson).
func _play_attack_telegraph(telegraph_duration: float) -> void:
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
	var hold_dur: float = max(0.0, telegraph_duration - ATTACK_TELEGRAPH_TWEEN_IN * 2.0)
	_attack_telegraph_tween.tween_property(target, prop, ATTACK_TELEGRAPH_TINT, ATTACK_TELEGRAPH_TWEEN_IN)
	_attack_telegraph_tween.tween_property(target, prop, ATTACK_TELEGRAPH_TINT, hold_dur)
	_attack_telegraph_tween.tween_property(target, prop, color_at_rest, ATTACK_TELEGRAPH_TWEEN_IN)
	_combat_trace("Stratum1Boss._play_attack_telegraph",
		"tween_valid=%s duration=%.2f tint=(%.2f,%.2f,%.2f)" % [
			_attack_telegraph_tween.is_valid(), telegraph_duration,
			ATTACK_TELEGRAPH_TINT.r, ATTACK_TELEGRAPH_TINT.g, ATTACK_TELEGRAPH_TINT.b
		])


func _cancel_attack_telegraph_tween() -> void:
	if _attack_telegraph_tween != null and _attack_telegraph_tween.is_valid():
		_attack_telegraph_tween.kill()
		_attack_telegraph_tween = null


## §2 hit-flash. Identical rule across all mob types.
## Bug C fix: tween Sprite child's `color` so the flash is actually visible.
## See Grunt._play_hit_flash for full rationale.
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


## §3 boss-death: 400ms hold + 200ms scale-down/fade tween, then queue_free.
## Hold leverages tween_interval so timeline + finished signal still fire.
##
## **HTML5 safety-net** (Sponsor soak `embergrave-html5-0e77a92`): see Grunt
## `_play_death_tween` for the full rationale. Boss timer uses
## BOSS_DEATH_HOLD + DEATH_TWEEN_DURATION + 0.2s slack so the climax hold +
## decay both fit under the safety budget.
func _play_boss_death_sequence() -> void:
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
		_hit_flash_tween = null
	if not is_inside_tree():
		queue_free()
		return
	_death_tween = create_tween()
	# Sequential by default — first the hold, then a parallel scale+fade.
	_death_tween.tween_interval(BOSS_DEATH_HOLD)
	_death_tween.tween_property(self, "scale", Vector2(DEATH_TARGET_SCALE, DEATH_TARGET_SCALE), DEATH_TWEEN_DURATION)
	# Run the modulate fade in parallel with the scale tween (set_parallel
	# only flips the *next* step, so use parallel() chained from this step).
	_death_tween.parallel().tween_property(self, "modulate:a", 0.0, DEATH_TWEEN_DURATION)
	_death_tween.finished.connect(_on_death_tween_finished)
	# Safety-net: parallel timer fires queue_free even if tween_finished hangs.
	var timer: SceneTreeTimer = get_tree().create_timer(BOSS_DEATH_HOLD + DEATH_TWEEN_DURATION + 0.2)
	timer.timeout.connect(_force_queue_free)


func _on_death_tween_finished() -> void:
	_force_queue_free()


## Idempotent queue_free. See Grunt._force_queue_free for the contract.
func _force_queue_free() -> void:
	if is_queued_for_deletion():
		_combat_trace("Stratum1Boss._force_queue_free", "already queued — second-caller no-op")
		return
	_combat_trace("Stratum1Boss._force_queue_free", "freeing now")
	queue_free()


## Combat-trace shim — routes through DebugFlags.combat_trace (HTML5-only).
func _combat_trace(tag: String, msg: String = "") -> void:
	var df: Node = null
	if is_inside_tree():
		df = get_tree().root.get_node_or_null("DebugFlags")
	if df != null and df.has_method("combat_trace"):
		df.combat_trace(tag, msg)


## §3 boss-climax shake: jiggle the boss's Sprite child by ±4 logical px on
## a short tween. We shake the boss's own visual (not a Camera2D) because
## the M1 play loop has no in-tree Camera2D yet — this still reads as a
## "screen-jolt" against the static background and stays inside VD-09's
## 4-logical-px budget. When Devon adds a real Camera2D in M2 the boss can
## subscribe a CameraShake autoload here without changing the cue's shape.
func _play_climax_shake() -> void:
	if not is_inside_tree():
		return
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	# Shake the boss's own position (the CharacterBody2D itself). M1 play
	# loop has no in-tree Camera2D yet, so a self-shake reads as the
	# "screen-jolt" cue against the static background, staying inside
	# VD-09's 4-logical-px budget. When Devon adds a real Camera2D in M2,
	# this can be re-routed to a CameraShake autoload without changing the
	# cue shape — the tween magnitude + duration are the load-bearing
	# numbers, not the target node.
	var rest_offset: Vector2 = position
	_shake_tween = create_tween()
	# Quick three-step jiggle: +x, -x, back to rest. Each leg is 1/3 of the
	# total so the whole shake fits inside BOSS_SHAKE_DURATION.
	var leg: float = BOSS_SHAKE_DURATION / 3.0
	_shake_tween.tween_property(self, "position", rest_offset + Vector2(BOSS_SHAKE_MAGNITUDE, 0.0), leg)
	_shake_tween.tween_property(self, "position", rest_offset + Vector2(-BOSS_SHAKE_MAGNITUDE, 0.0), leg)
	_shake_tween.tween_property(self, "position", rest_offset, leg)


## §3 boss-climax burst: 24 ember particles parented to the room (so they
## persist past queue_free). Same shape as grunt burst, 4× the volume.
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
	if _melee_telegraph_left > 0.0:
		_melee_telegraph_left = max(0.0, _melee_telegraph_left - delta)
	if _melee_recovery_left > 0.0:
		_melee_recovery_left = max(0.0, _melee_recovery_left - delta)
	if _slam_telegraph_left > 0.0:
		_slam_telegraph_left = max(0.0, _slam_telegraph_left - delta)
	if _slam_recovery_left > 0.0:
		_slam_recovery_left = max(0.0, _slam_recovery_left - delta)
	if _slam_cooldown_left > 0.0:
		_slam_cooldown_left = max(0.0, _slam_cooldown_left - delta)
	if _phase_transition_left > 0.0:
		_phase_transition_left = max(0.0, _phase_transition_left - delta)


func _set_state(new_state: StringName) -> void:
	if new_state == _state:
		return
	var old: StringName = _state
	_state = new_state
	state_changed.emit(old, new_state)


func _apply_mob_def() -> void:
	if mob_def == null:
		# Bare-instantiated boss (tests). Use spec defaults — 600 HP, 12 dmg
		# (rebalanced M1 RC soak-4, was 15), 80 px/s.
		# Phase-2 and phase-3 thresholds resolve to 396 and 198.
		hp_max = 600
		hp_current = 600
		damage_base = 12
		move_speed_base = 80.0
		move_speed = move_speed_base
		return
	hp_max = mob_def.hp_base
	hp_current = mob_def.hp_base
	damage_base = mob_def.damage_base
	move_speed_base = mob_def.move_speed
	move_speed = move_speed_base


func _apply_layers() -> void:
	# Same fix-up pattern as Grunt/Charger: bare CharacterBody2D defaults to
	# layer 1 / mask 1; we override to enemy / world+player so Boss.new() in
	# tests behaves the same as scene-loaded.
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
## boss's POST_CONTACT_PUSHBACK_SPEED velocity along the +up axis.
##
## Symptom this fixes (M1 RC re-soak 5, ticket 86c9q96jv): boss sticks to
## player on south-edge approach only — north / east / west approaches work
## because their collision normals don't align with up_direction so the
## GROUNDED-mode floor-detection branch never engages. Boss's larger
## collision radius (24 px vs Grunt's 12 px) made the asymmetry observable
## as sticking; smaller mobs are less affected for the same reason.
##
## Top-down 2D best practice — boss has no floor / gravity / jump concept,
## so MOTION_MODE_FLOATING is the canonical motion mode. Mirrors the same
## consideration future top-down mobs should adopt; documented in
## `.claude/docs/combat-architecture.md` § "CharacterBody2D motion_mode
## rule".
func _apply_motion_mode() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


## Read the player's Vigor stat for the damage formula. Returns 0 if the
## player ref is unset (test-bare boss) or doesn't expose get_vigor
## (defensive: no crash if a non-Player target sneaks in).
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
