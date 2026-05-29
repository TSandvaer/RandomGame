class_name ArchiveSentinel
extends CharacterBody2D
## Stratum-2 boss — stationary phase-shift construct (Archive Sentinel).
##
## Design source: `team/uma-ux/palette-stratum-2.md` §5.5 Archive Sentinel
## (Uma — binding) + W3-T7 Stage 5 dispatch brief (ticket 86c9y7ygj Part D).
## The Stratum-2 boss is a **stationary** stone-bone-book composite rooted to
## its center plinth — combat happens AROUND it (NOT mobile melee per S1
## boss precedent). Drew owns the internal HP weights + attack patterns;
## constants here are shape (timing/distance), MobDef is magnitude
## (HP/damage/speed).
##
## **Distinct-from-S1-Boss design (Uma §5.5 + .claude/docs/combat-architecture.md):**
##   - S1 Boss is mobile melee (chases player, melee + AOE slam, 3-phase 66%/33%).
##   - Archive Sentinel is stationary phase-shift (rooted to plinth, cast +
##     slam at ~50%, 2-phase). Player learns the construct's stillness IS its
##     tonal beat — movement is the rare cue (slam telegraph is the only
##     physical motion the construct makes).
##
## **State machine (per Uma §5.5):**
##   - STATE_DORMANT — pre-wake (intro fairness). Damage-immune. Book pages dim.
##   - STATE_WAKING  — ~417 ms wake-anim window (extends intro-fairness through
##                     the standup animation per S1-boss WAKE_DURATION precedent).
##                     Book pages ignite from dormant to aggro.
##   - STATE_IDLE_ACTIVE — awake, no target / out-of-range. Book aggro-active.
##                          State naming distinguishes from "idle" of mobile mobs
##                          (the Sentinel never CHASES — there is no "active idle
##                          waiting to chase" beat).
##   - STATE_CAST — ranged-attack phase (phase 1 + 2). Book flares to bright
##                  ember + projectile emerges from book toward player. Pure
##                  ranged; no movement.
##   - STATE_CAST_RECOVERY — between casts (cast cooldown window).
##   - STATE_SLAM_TELEGRAPH — phase-2-only AOE windup. Brass clamps tuck,
##                            book flares white-hot, `_draw()` + `draw_arc()`
##                            circular AOE telegraph (NEVER Polygon2D — uma
##                            hard rule + html5-export.md PR #137 precedent).
##   - STATE_SLAM_RECOVERY — between slam-fire and re-eligibility.
##   - STATE_PHASE_TRANSITION — 0.6 s damage-immune phase-change window.
##                              At ~50% HP the construct shifts: book PAGE-
##                              FLIPS visibly, ember-light intensifies, slam
##                              unlocks for phase 2 attack pattern.
##   - STATE_HIT — one-shot beat for `hit_<dir>` anim (not a true state; we use
##                 it via _play_anim only, not _set_state, so it doesn't
##                 interrupt the state machine).
##   - STATE_DEAD — death sequence.
##
## **Phase shape (2-phase, ~50% HP):**
##   Phase 1 (100% → 50% HP):  CAST only. Book ember-projectile at ranged
##                              cadence. Player learns the ranged danger.
##   Phase 2 (50% → 0% HP):    CAST + SLAM. Slam unlocks; player must manage
##                              the new circular AOE while still dodging book
##                              projectiles. Per Uma §5.5: "new attack
##                              patterns unlock" at phase transition.
##
## **HTML5 visual-verification gate constraints:**
##   - Slam AOE telegraph via Node2D + `_draw()` + `draw_arc()` (NEVER
##     Polygon2D per html5-export.md § "Shape OUTLINES" + uma persona hard
##     rules). 32-segment arc renders identically on `forward_plus` and
##     `gl_compatibility`.
##   - CPUParticles2D ember-bursts (room-parented, deferred add_child per
##     physics-flush rule + same-z occlusion lift via z_index=+1).
##   - All modulate tints sub-1.0 every channel (HDR clamp per PR #137).
##
## **Layer convention (mirrors S1 Boss):** collision_layer = enemy (bit 4),
## collision_mask = world (bit 1) + player (bit 2). Spawned hitboxes sit on
## enemy_hitbox (bit 5) and mask player (bit 2). Same iframe semantics.
##
## Stage 5 ship state (W3-T7 ticket `86c9y7ygj`):
##   - Placeholder Sprite is a flat-color ColorRect at composite-construct
##     scale (~48×48) per Uma §5.5 "stone-bone composite". Hit-flash
##     3-branch resolver routes through the ColorRect branch (M3W-3
##     convention); AnimatedSprite2D drop-in via scene-swap when ready.
##   - Archive Sentinel PixelLab character generation deferred (OOS per
##     dispatch brief; Sponsor or orchestrator main-session executes).
##
## Cross-references:
##   - `.claude/docs/combat-architecture.md` § "M3W-1 realized implementation"
##     + § "Mob `_die` death pipeline" + § Physics-flush rule
##   - `.claude/docs/html5-export.md` § "Shape OUTLINES" + § HDR modulate clamp
##   - `team/uma-ux/palette-stratum-2.md` §5.5 Archive Sentinel
##   - `team/uma-ux/boss-intro.md` BI-01 through BI-08 (intro reveal beats)
##   - `scripts/mobs/Stratum1Boss.gd` (S1 precedent — phase machine + wake +
##     hit-flash 3-branch resolver + death sequence pattern)

# ---- Signals ------------------------------------------------------------

## State transitioned. New state on the right.
signal state_changed(from_state: StringName, to_state: StringName)

## Took damage. Emitted after HP is decremented but before death is checked.
signal damaged(amount: int, hp_remaining: int, source: Node)

## Phase changed. Carries the new phase index (2 in Stage 5; phase 1 is the
## entry phase and never re-emits this signal). Fires exactly once per
## boundary even under hit-spam (idempotent latch).
signal phase_changed(new_phase: int)

## A cast/slam hitbox spawned. `kind` = &"cast", &"slam_telegraph", or
## &"slam_hit". Useful for tests + audio hooks.
signal swing_spawned(kind: StringName, hitbox: Node)

## Entry sequence completed — boss is awake and combat begins. Fired by
## `wake()` (the boss-room entry-sequence completion handler calls this).
signal boss_woke

## HP hit zero. Emitted exactly once per life. Carries (mob, position, def)
## — same payload shape as Stratum1Boss so MobLootSpawner reuses unchanged.
signal boss_died(mob: ArchiveSentinel, death_position: Vector2, mob_def: MobDef)

# ---- States ------------------------------------------------------------

const STATE_DORMANT: StringName = &"dormant"  # pre-wake (intro)
const STATE_WAKING: StringName = &"waking"  # mid-wake-anim (damage-immune)
const STATE_IDLE_ACTIVE: StringName = &"idle_active"  # awake, no in-range target
const STATE_CAST: StringName = &"cast"  # ranged-attack windup/fire
const STATE_CAST_RECOVERY: StringName = &"cast_recovery"
const STATE_SLAM_TELEGRAPH: StringName = &"slam_telegraph"  # phase 2 only
const STATE_SLAM_RECOVERY: StringName = &"slam_recovery"
const STATE_PHASE_TRANSITION: StringName = &"phase_transition"
const STATE_DEAD: StringName = &"dead"

const SWING_KIND_CAST: StringName = &"cast"
const SWING_KIND_SLAM_TELEGRAPH: StringName = &"slam_telegraph"
const SWING_KIND_SLAM_HIT: StringName = &"slam_hit"

# ---- Phases ------------------------------------------------------------

const PHASE_1: int = 1
const PHASE_2: int = 2

## Phase boundary as a fraction of max_hp. Single transition at 50% — Stage 5
## ships the 2-phase shape per Uma §5.5 (cast → cast+slam). Future Stage 6
## work could add a phase 3 at ~25% if balance review wants more transitions.
const PHASE_2_HP_FRAC: float = 0.50

# ---- Tuning (shape) ----------------------------------------------------

## Aggro radius — player must be within this to trigger any attack. Larger
## than S1 Boss (480) because the Sentinel is stationary; it can't chase
## an out-of-range player so the engage radius needs to cover the
## viewport-native 480×270 + procedural slack.
const AGGRO_RADIUS: float = 640.0

## Cast windup duration — how long between cast-decision and projectile
## fire. Slightly longer than Shooter's AIM_TIMER (0.85 s) because the
## construct's pages-flare animation takes a beat to read.
const CAST_TELEGRAPH_DURATION: float = 0.90

## Cast recovery — between cast-fire and next cast eligibility. Combined
## with CAST_COOLDOWN this is the player's "breathe" window.
const CAST_RECOVERY_DURATION: float = 0.40

## Cast cooldown — wall-clock between cast windups. The Sentinel cannot
## machine-gun projectiles; this cooldown forces pacing.
const CAST_COOLDOWN: float = 1.50

## Cast hitbox spec (the projectile). The hitbox is spawned as a one-frame
## damage event at the player's last-known position when the windup
## completes — readable as "the book just shot at where you were standing".
## Player who moved during windup dodges the cast naturally.
const CAST_HITBOX_RADIUS: float = 18.0
const CAST_HITBOX_LIFETIME: float = 0.18
const CAST_KNOCKBACK: float = 220.0
const CAST_DAMAGE_MULTIPLIER: float = 1.0

## Slam telegraph duration — phase-2-only AOE windup. Player has this long
## to back off out of SLAM_HITBOX_RADIUS. Matches S1 Boss SLAM_TELEGRAPH
## (0.50 s) for cross-boss feel consistency.
const SLAM_TELEGRAPH_DURATION: float = 0.55

## Slam hitbox spec — phase 2 AOE. Larger radius than S1 Boss slam (80 px)
## because the construct is rooted to its plinth — player has the whole
## arena to back off into, so the AOE can be wider without being unfair.
const SLAM_HITBOX_RADIUS: float = 96.0
const SLAM_HITBOX_LIFETIME: float = 0.18
const SLAM_KNOCKBACK: float = 360.0
const SLAM_DAMAGE_MULTIPLIER: float = 1.5

## Slam recovery + cooldown — slam is the riskier attack, longer recovery
## creates the player's punish window.
const SLAM_RECOVERY_DURATION: float = 0.85
const SLAM_COOLDOWN: float = 5.0

## Phase-transition window — boss is stagger + damage immune. Mirrors
## S1 Boss PHASE_TRANSITION_DURATION (0.6 s).
const PHASE_TRANSITION_DURATION: float = 0.60

## Wake-anim duration — mirrors S1 Boss WAKE_DURATION (0.417 s) for
## cross-boss timing consistency. Per Uma BI-06 (~500 ms target window).
const WAKE_DURATION: float = 0.417

# ---- Cinematic-feel constants (TimeScaleDirector composition) -----------
# Mirrors S1 Boss T2/T3 hit-pause + phase-transition slow-mo per
# `.claude/docs/time-scale-director.md` § Migration policy. Direct
# Engine.time_scale writes prohibited outside the director.

const HIT_PAUSE_LIGHT_DURATION: float = 0.060
const HIT_PAUSE_HEAVY_DURATION: float = 0.100
const FINAL_FREEZE_DURATION: float = 0.300

const TSD_REASON_HIT_PAUSE: String = "sentinel_hit_pause"
const TSD_REASON_FINAL_FREEZE: String = "sentinel_final_freeze"
const TSD_REASON_PHASE_TRANSITION: String = "sentinel_phase_transition"

const PHASE_TRANSITION_SCALE: float = 0.3
const PHASE_TRANSITION_SLOW_MO_DURATION: float = 0.60

# ---- Visual-feedback timings (mirrors S1 Boss §2 + §3) ----------------

const HIT_FLASH_IN: float = 0.020
const HIT_FLASH_HOLD: float = 0.020
const HIT_FLASH_OUT: float = 0.040

const DEATH_TWEEN_DURATION: float = 0.200
const DEATH_TARGET_SCALE: float = 0.6
const BOSS_DEATH_HOLD: float = 0.400
const BOSS_SHAKE_MAGNITUDE: float = 4.0  # logical px (VD-09 max budget)
const BOSS_SHAKE_DURATION: float = 0.150

## Ember color palette — mirrors S1 Boss EMBER_LIGHT / EMBER_DEEP for the
## cross-boss ember-language consistency. The Sentinel's book pages emit
## ember-orange in cast / slam-telegraph windups; the death-burst ramp
## reuses the same palette so the construct's death visually echoes the
## S1 boss's death (continuity of the embergrave's flame language).
const EMBER_LIGHT: Color = Color(1.0, 0.690, 0.400, 1.0)  # #FFB066
const EMBER_DEEP: Color = Color(0.627, 0.180, 0.031, 1.0)  # #A02E08

## Impact-flash white — sub-1.0 channels (HDR clamp safe). Used at ramp[0]
## of the death burst to break the orange-on-red blend per PR #291 v5/v7
## finding (`html5-export.md` § "Burst contrast against high-hue-saturation
## same-z sprites"). Slightly warm-tinted vs pure-white to read as "ember
## flash" not "white pop".
const DEATH_BURST_IMPACT_FLASH: Color = Color(1.0, 0.949, 0.749, 1.0)  # #FFF2BF

## Death burst — climax shape. Sustained ember-rise mirroring S1 Boss's
## CLIMAX_BURST_* constants (PR #291 T6 + S1 boss T16). 56 particles at
## 2.5 scale + 0.9 s sustained emission window, with the white impact
## frame at ramp[0] for perceptibility.
const DEATH_BURST_PARTICLE_COUNT: int = 56
const DEATH_BURST_LIFETIME: float = 0.9
const DEATH_BURST_EXPLOSIVENESS: float = 0.1
const DEATH_BURST_SCALE_MIN: float = 2.0
const DEATH_BURST_SCALE_MAX: float = 2.5
const DEATH_BURST_VELOCITY_MIN: float = 80.0
const DEATH_BURST_VELOCITY_MAX: float = 220.0
const DEATH_BURST_GRAVITY_Y: float = -120.0
const DEATH_BURST_SPREAD_DEG: float = 90.0
const DEATH_BURST_Z_INDEX: int = 1

## Hit-flash modulate tint — mirrors PracticeDummy / Grunt / Stratum1Boss
## HIT_FLASH_TINT verbatim per the M3W-1 inheritance contract (combat-
## architecture.md § "M3W-1 realized implementation"). Sub-1.0 every
## channel for HDR-clamp safety; channel-sum delta ≥ 0.20 vs rest white.
const HIT_FLASH_TINT: Color = Color(1.0, 0.50, 0.50, 1.0)  # soft red wash, HTML5-safe

## Attack-telegraph tint for cast + slam windup. Ember-orange flare to
## evoke the book-pages igniting, NOT the red-wash of S1 Boss
## (ATTACK_TELEGRAPH_TINT = vivid red). The Sentinel's tonal beat is
## ember-light; matching S1 boss's red would muddle the construct's
## scholarly-flame identity per Uma §5.5.
const TELEGRAPH_TINT: Color = Color(1.0, 0.65, 0.30, 1.0)  # ember-orange flare, HTML5-safe
const TELEGRAPH_TWEEN_IN: float = 0.080

## Slam-telegraph indicator color — same ember-orange as S1 Boss
## SLAM_INDICATOR_COLOR (`#FF6A2A` at α=0.5) per Uma §5.5 ("Circle outline
## in `#FF6A2A` ember-accent at radius matched to S1 boss slam"). Sub-1.0
## channels per HDR-clamp rule.
const SLAM_INDICATOR_COLOR: Color = Color(1.0, 0.416, 0.165, 0.5)
const SLAM_INDICATOR_LINE_WIDTH: float = 2.0
const SLAM_INDICATOR_FADE: float = 0.080
const SLAM_INDICATOR_ARC_POINTS: int = 32

## Slam-indicator strobe (mirrors S1 Boss strobe per PR #291 Sponsor soak
## "circle disappears too fast, should also be blinking"). 5 Hz pulse
## across the hold window, well within feel-targets + below seizure
## thresholds for this low-contrast peripheral stimulus.
const SLAM_INDICATOR_STROBE_HZ: float = 5.0
const SLAM_INDICATOR_STROBE_HIGH: float = 1.0  # perceived peak alpha = 1.0 × 0.5 = 0.5
const SLAM_INDICATOR_STROBE_LOW: float = 0.25  # perceived trough     = 0.25 × 0.5 = 0.125

## Layer bits (mirror project.godot — same as Stratum1Boss).
const LAYER_WORLD: int = 1 << 0  # bit 1
const LAYER_PLAYER: int = 1 << 1  # bit 2
const LAYER_ENEMY: int = 1 << 3  # bit 4

const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")
const DamageScript: Script = preload("res://scripts/combat/Damage.gd")
## Sentinel-specific slam indicator — wider 96 px radius vs S1 Boss's 80 px.
## See `scripts/mobs/ArchiveSentinelSlamIndicator.gd` for why a separate
## class (sibling-class pattern; parameterizing the S1 class would risk
## silent S1-side regression).
const ArchiveSentinelSlamIndicatorScript: Script = preload(
	"res://scripts/mobs/ArchiveSentinelSlamIndicator.gd"
)
## Visible cast-bolt VFX — the cast's DAMAGE is an instantaneous Hitbox at the
## captured target (dodge model unchanged); this node is the missing VISUAL so
## the cast is no longer invisible (ticket 86c9y7ygj re-soak fix, Sponsor
## 2026-05-29). Cosmetic only — carries no damage / no collision.
const ArchiveSentinelCastBoltScript: Script = preload(
	"res://scripts/mobs/ArchiveSentinelCastBolt.gd"
)

## Cast-bolt travel window — book → captured target. Short cosmetic cue; the
## damage already fired instantaneously at the captured position. Kept just
## under CAST_HITBOX_LIFETIME so the bolt reads as "the shot that just landed".
const CAST_BOLT_TRAVEL_DURATION: float = 0.16

# ---- Inspector --------------------------------------------------------

## The MobDef this boss instances. Spawner sets it before add_child(), or
## the .tscn ships with `archive_sentinel.tres` ext-resourced. If null,
## safe defaults apply so a bare-instantiated test node works.
@export var mob_def: MobDef

## NodePath to the player. Optional — set by the spawner / boss room. If
## unset, falls back to the first node in the "player" group on _ready.
@export var player_node_path: NodePath

## If true, the boss starts in STATE_IDLE_ACTIVE rather than STATE_DORMANT —
## useful for headless tests that don't want to manually call `wake()` on
## every construction. Production .tscn ships with this false.
@export var skip_intro_for_tests: bool = false

# ---- Runtime ----------------------------------------------------------

var hp_max: int = 700
var hp_current: int = 700
var damage_base: int = 14
var move_speed_base: float = 0.0  # STATIONARY — never moves
var move_speed: float = 0.0

var phase: int = PHASE_1

var _state: StringName = STATE_DORMANT
var _cast_telegraph_left: float = 0.0
var _cast_recovery_left: float = 0.0
var _cast_cooldown_left: float = 0.0
var _slam_telegraph_left: float = 0.0
var _slam_recovery_left: float = 0.0
var _slam_cooldown_left: float = 0.0
var _phase_transition_left: float = 0.0
var _wake_left: float = 0.0

## Idempotent phase-change latch — prevents rapid hit-spam from re-firing
## `phase_changed` for the same boundary. Set true on first crossing;
## never reset.
var _phase_2_latched: bool = false

var _is_dead: bool = false

## Pending phase to enter after the current phase-transition window expires.
var _pending_phase: int = PHASE_1

## Captured cast target — set when CAST telegraph begins; the projectile
## fires AT this position on telegraph completion. Player who moves during
## the windup naturally dodges the cast.
var _cast_target_pos: Vector2 = Vector2.ZERO

var _player: Node2D = null

# VFX runtime — see Stratum1Boss for the precedent pattern.
var _hit_flash_tween: Tween = null
var _death_tween: Tween = null
var _shake_tween: Tween = null
var _modulate_at_rest: Color = Color(1, 1, 1, 1)
var _captured_modulate_at_rest: bool = false

# Hit-flash 3-branch resolver — same as PracticeDummy / Grunt / Stratum1Boss
# per .claude/docs/combat-architecture.md § "M3W-1 realized implementation":
#   1. AnimatedSprite2D child → tween modulate (production drop-in path).
#   2. ColorRect child → tween Sprite.color (Stage 5 placeholder).
#   3. No Sprite child → tween self.modulate (bare-instanced tests).
var _hit_flash_target: CanvasItem = null
var _hit_flash_uses_sprite: bool = false
var _hit_flash_uses_animated_sprite: bool = false
var _sprite_color_at_rest: Color = Color(1, 1, 1, 1)
var _sprite_modulate_at_rest: Color = Color(1, 1, 1, 1)

# AnimatedSprite2D lazy cache (mirrors S1 Boss). Resolves once on first
# `_play_anim` so a future AnimatedSprite2D scene-swap picks up the
# animation-playback hooks without per-state re-casting.
var _animated_sprite: AnimatedSprite2D = null
var _animated_sprite_resolved: bool = false

# Attack-telegraph tween — ref kept so death-during-telegraph can cancel it.
var _attack_telegraph_tween: Tween = null

# Slam-telegraph indicator runtime — Node2D child created at telegraph
# start, freed on slam-fire or boss-death. Mirrors S1 Boss pattern.
var _slam_indicator: Node2D = null
var _slam_indicator_tween: Tween = null


func _ready() -> void:
	_apply_mob_def()
	_apply_layers()
	_apply_motion_mode()
	_resolve_player()
	if skip_intro_for_tests:
		_state = STATE_IDLE_ACTIVE
	_wire_audio_cues()


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


## True during the ~417 ms wake-anim window (damage immune; the construct
## is igniting but cannot yet act or be hit). Exposed for tests + external
## observers (cinematic camera holding focus through the wake animation).
func is_waking() -> bool:
	return _state == STATE_WAKING


## True during the 0.6 s phase-transition window (stagger + damage immune).
func is_in_phase_transition() -> bool:
	return _state == STATE_PHASE_TRANSITION


## True in phase 2 — drives any phase-2-only behavior consumers want to gate.
func is_phase_2() -> bool:
	return phase == PHASE_2


## Inject the player target. Tests + spawner use this for determinism.
func set_player(p: Node2D) -> void:
	_player = p


## Force-apply a MobDef post-_ready (test convenience).
func apply_mob_def(def: MobDef) -> void:
	mob_def = def
	_apply_mob_def()


## Test-only: fast-forward through the ~417 ms WAKE_DURATION window without
## requiring physics-tick simulation. After this call the boss is in
## STATE_IDLE_ACTIVE (combat-ready, damage-eligible). Production never calls
## this — production drains `_wake_left` via `_process_waking` on real
## physics ticks. Mirrors S1 Boss precedent.
func complete_wake_for_test() -> void:
	if _state != STATE_WAKING:
		return
	_wake_left = 0.0
	_set_state(STATE_IDLE_ACTIVE)


## Wake the construct — called by `Stratum2BossRoom` after the entry
## sequence completes. Transitions DORMANT → WAKING (plays the ignite
## animation + remains damage-immune) and then auto-advances to
## IDLE_ACTIVE after `WAKE_DURATION` (~417 ms) via `_process_waking`.
## Idempotent — calling twice has no extra effect.
##
## `boss_woke.emit()` fires at the START of WAKING so the BI-06 audio
## stinger (Uma boss-intro brief, Beat 3) lands on wake entry immediately.
func wake() -> void:
	if _state != STATE_DORMANT:
		return
	_combat_trace(
		"ArchiveSentinel.wake",
		(
			"exiting STATE_DORMANT -> STATE_WAKING (damage-immune wake-anim window, %.3fs)"
			% WAKE_DURATION
		)
	)
	_wake_left = WAKE_DURATION
	_set_state(STATE_WAKING)
	boss_woke.emit()


## Take damage. Duck-typed contract matched by `Hitbox.gd`.
##
##   - Damage during STATE_DEAD is ignored.
##   - Damage during STATE_DORMANT is ignored (intro fairness).
##   - Damage during STATE_WAKING is ignored (wake-anim window — extends
##     intro-fairness through standup).
##   - Damage during STATE_PHASE_TRANSITION is ignored (stagger-immune).
##   - Negative amounts clamped to 0.
##   - Phase boundary (50%) latches exactly once (idempotent).
##   - boss_died emits exactly once on the death-transition.
##   - Knockback is rejected — the construct is rooted to its plinth and
##     does NOT move from impacts. This is a deliberate departure from
##     S1 Boss precedent (which applies knockback velocity) and matches
##     the "stillness IS its tonal beat" design (Uma §5.5).
func take_damage(amount: int, _knockback: Vector2, source: Node) -> void:
	if _is_dead:
		_combat_trace("ArchiveSentinel.take_damage", "IGNORED already_dead amount=%d" % amount)
		return
	if _state == STATE_DORMANT:
		_combat_trace(
			"ArchiveSentinel.take_damage",
			"IGNORED dormant amount=%d hp=%d (intro fairness)" % [amount, hp_current]
		)
		return
	if _state == STATE_WAKING:
		_combat_trace(
			"ArchiveSentinel.take_damage",
			(
				"IGNORED waking amount=%d hp=%d wake_left=%.3f (wake-anim window)"
				% [amount, hp_current, _wake_left]
			)
		)
		return
	if _state == STATE_PHASE_TRANSITION:
		_combat_trace(
			"ArchiveSentinel.take_damage",
			(
				"IGNORED phase_transition amount=%d hp=%d (stagger-immune window)"
				% [amount, hp_current]
			)
		)
		return
	var clean_amount: int = max(0, amount)
	var hp_before: int = hp_current
	hp_current = max(0, hp_current - clean_amount)
	_combat_trace(
		"ArchiveSentinel.take_damage",
		"amount=%d hp=%d->%d phase=%d" % [clean_amount, hp_before, hp_current, phase]
	)
	damaged.emit(clean_amount, hp_current, source)
	# Visual: red-wash hit-flash on every actual-damage take_damage (mirror
	# S1 Boss / Grunt / PracticeDummy convention).
	if clean_amount > 0:
		_play_hit_flash()
		_play_anim(&"hit")
	# NOTE: knockback intentionally NOT applied to velocity. The construct
	# is rooted to its plinth per Uma §5.5; staggers via hit-flash + anim
	# rather than physical displacement. Visual grammar: "the book is
	# reading you regardless of damage" — the construct does not flinch.
	if hp_current == 0:
		_die()
		return
	if clean_amount > 0:
		_request_hit_pause_for(source)
	_check_phase_boundary()


# ---- Hit-pause helper (mirrors S1 Boss T2) ----------------------------


func _request_hit_pause_for(source: Node) -> void:
	var director: Node = _resolve_time_scale_director()
	if director == null:
		return
	var duration: float = HIT_PAUSE_LIGHT_DURATION
	if source != null and source.has_method("get_current_attack_kind"):
		var kind: StringName = source.get_current_attack_kind()
		if kind == &"heavy":
			duration = HIT_PAUSE_HEAVY_DURATION
	director.freeze(duration, TSD_REASON_HIT_PAUSE)
	_combat_trace(
		"ArchiveSentinel.hit_pause",
		(
			"freeze=%.3f reason=%s source=%s"
			% [duration, TSD_REASON_HIT_PAUSE, "player" if source != null else "null"]
		)
	)


func _resolve_time_scale_director() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("TimeScaleDirector")


# ---- Physics tick -----------------------------------------------------


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	if _state == STATE_DORMANT:
		# Frozen during intro — no timer ticks, no AI.
		velocity = Vector2.ZERO
		return
	_tick_timers(delta)

	# Wake-anim window — rooted, damage-immune, plays `wake_<dir>` once.
	# When `_wake_left` drains we hand off to STATE_IDLE_ACTIVE.
	if _state == STATE_WAKING:
		velocity = Vector2.ZERO
		if _wake_left <= 0.0:
			_combat_trace(
				"ArchiveSentinel._process_waking",
				"wake-anim complete -> STATE_IDLE_ACTIVE (damage-immunity ends)"
			)
			_set_state(STATE_IDLE_ACTIVE)
		return

	# Phase-transition window — when it expires, commit the pending phase.
	if _state == STATE_PHASE_TRANSITION:
		velocity = Vector2.ZERO
		if _phase_transition_left <= 0.0:
			_finish_phase_transition()
		return

	# Stationary boss — velocity always zero. No move_and_slide needed; the
	# construct never moves. We skip move_and_slide entirely to be explicit
	# about the rooted-to-plinth design and avoid any collision-resolution
	# edge cases (the construct's own collision shape stays put as a
	# static obstacle the player can navigate around).
	velocity = Vector2.ZERO

	match _state:
		STATE_IDLE_ACTIVE:
			_process_idle_active(delta)
		STATE_CAST:
			_process_cast_telegraph(delta)
		STATE_CAST_RECOVERY:
			_process_cast_recovery(delta)
		STATE_SLAM_TELEGRAPH:
			_process_slam_telegraph(delta)
		STATE_SLAM_RECOVERY:
			_process_slam_recovery(delta)
		STATE_DEAD:
			pass


# ---- State handlers ---------------------------------------------------


func _process_idle_active(_delta: float) -> void:
	if _player == null:
		return
	var to_player: Vector2 = _player.global_position - global_position
	var dist: float = to_player.length()
	if dist > AGGRO_RADIUS:
		# Out of range — stay idle, no attacks. The construct never chases.
		return
	# Phase 2 only: prefer slam if cooldown is clear and player is in slam
	# radius. Otherwise (phase 1, or phase 2 with slam on cooldown, or
	# player outside slam radius) fall through to cast.
	if (
		phase >= PHASE_2
		and _slam_cooldown_left <= 0.0
		and dist <= SLAM_HITBOX_RADIUS
	):
		_begin_slam_telegraph()
		return
	# Cast is the default attack — available in both phases at any range
	# within AGGRO_RADIUS. Gated by cooldown so cast doesn't machine-gun.
	if _cast_cooldown_left <= 0.0:
		_begin_cast_telegraph()


func _process_cast_telegraph(_delta: float) -> void:
	if _cast_telegraph_left <= 0.0:
		_fire_cast()


func _process_cast_recovery(_delta: float) -> void:
	if _cast_recovery_left <= 0.0:
		_set_state(STATE_IDLE_ACTIVE)


func _process_slam_telegraph(_delta: float) -> void:
	if _slam_telegraph_left <= 0.0:
		_fire_slam_hit()


func _process_slam_recovery(_delta: float) -> void:
	if _slam_recovery_left <= 0.0:
		_set_state(STATE_IDLE_ACTIVE)


# ---- Cast attack ------------------------------------------------------


func _begin_cast_telegraph() -> void:
	_cast_telegraph_left = CAST_TELEGRAPH_DURATION
	# Capture the cast target at telegraph START. Player who moves during
	# the windup naturally dodges — the projectile lands at their previous
	# position. Readable as "the book just shot at where you were standing".
	if _player != null:
		_cast_target_pos = _player.global_position
	else:
		_cast_target_pos = global_position  # no player → fire at self (no-op damage)
	_set_state(STATE_CAST)
	_play_attack_telegraph(CAST_TELEGRAPH_DURATION)


func _fire_cast() -> void:
	# Damage routed through the formula utility — reads MobDef.damage_base +
	# the player's Vigor mitigation at fire time.
	var formula_dmg: int
	if mob_def == null:
		formula_dmg = damage_base
	else:
		formula_dmg = DamageScript.compute_mob_damage(mob_def, _player_vigor())
	var dmg: int = int(round(float(formula_dmg) * CAST_DAMAGE_MULTIPLIER))

	# Direction from the construct toward the captured cast target.
	var dir: Vector2 = (_cast_target_pos - global_position)
	var dir_norm: Vector2 = dir.normalized() if dir.length_squared() > 0.0 else Vector2.RIGHT

	# Distance from construct to captured target — the hitbox is positioned
	# at the captured target, not at the construct. This is the "spawn the
	# damage event where the cast lands" pattern — player at original
	# position takes the hit; player who moved during the windup escapes.
	var to_target_dist: float = (_cast_target_pos - global_position).length()

	var player_dist: float = -1.0
	if _player != null:
		player_dist = global_position.distance_to(_player.global_position)
	_combat_trace(
		"ArchiveSentinel._fire_cast",
		(
			"dir=(%.2f,%.2f) dmg=%d radius=%.0f lifetime=%.2f target_pos=(%.0f,%.0f) player_dist=%.1f phase=%d"
			% [
				dir_norm.x,
				dir_norm.y,
				dmg,
				CAST_HITBOX_RADIUS,
				CAST_HITBOX_LIFETIME,
				_cast_target_pos.x,
				_cast_target_pos.y,
				player_dist,
				phase
			]
		)
	)
	var hb: Hitbox = _spawn_hitbox(
		dir_norm,
		dmg,
		dir_norm * CAST_KNOCKBACK,
		to_target_dist,
		CAST_HITBOX_RADIUS,
		CAST_HITBOX_LIFETIME,
	)
	# Visible cast bolt — the damage hitbox above is invisible (bare Area2D);
	# this cosmetic ember bolt travels book → captured target so the cast is
	# perceptible. Without it the cast was invisible damage (Sponsor 2026-05-29
	# re-soak: "HP just drops, nothing visible"). Cosmetic only — the dodge
	# model + the GUT hitbox-position contract are unchanged.
	_spawn_cast_bolt(global_position, _cast_target_pos)
	_cast_recovery_left = CAST_RECOVERY_DURATION
	_cast_cooldown_left = CAST_COOLDOWN
	_set_state(STATE_CAST_RECOVERY)
	swing_spawned.emit(SWING_KIND_CAST, hb)


# ---- Cast bolt VFX (cosmetic — no damage) -----------------------------


## Spawn the visible ember bolt that travels from the construct's book to the
## captured cast target. Room-parented + deferred add_child per the physics-
## flush rule (`_fire_cast` runs inside `_physics_process`; the bolt root is a
## Node2D, not an Area2D, so it's not strictly subject to the monitoring-mutation
## panic — but the deferred add keeps the spawn block uniform with the
## death-particle / hitbox sites per `.claude/docs/combat-architecture.md`
## § "Why call_deferred even though CPUParticles2D is not an Area2D").
##
## The bolt parents to the construct's parent (the room) so it survives the
## construct's own death-tween + outlives the cast-recovery state. Returns the
## bolt for test inspection.
func _spawn_cast_bolt(spawn_pos: Vector2, target_pos: Vector2) -> Node2D:
	var room: Node = get_parent()
	if room == null:
		return null
	var bolt: Node2D = ArchiveSentinelCastBoltScript.new()
	bolt.configure(spawn_pos, target_pos, CAST_BOLT_TRAVEL_DURATION)
	room.call_deferred("add_child", bolt)
	_combat_trace(
		"ArchiveSentinel._spawn_cast_bolt",
		(
			"visible cast bolt spawn=(%.0f,%.0f) target=(%.0f,%.0f) travel=%.2f z=%d"
			% [
				spawn_pos.x,
				spawn_pos.y,
				target_pos.x,
				target_pos.y,
				CAST_BOLT_TRAVEL_DURATION,
				ArchiveSentinelCastBoltScript.BOLT_Z_INDEX
			]
		)
	)
	return bolt


# ---- Slam attack (phase 2 only) ---------------------------------------


func _begin_slam_telegraph() -> void:
	_slam_telegraph_left = SLAM_TELEGRAPH_DURATION
	_set_state(STATE_SLAM_TELEGRAPH)
	_play_attack_telegraph(SLAM_TELEGRAPH_DURATION)
	_spawn_slam_indicator(_slam_telegraph_left)
	# Spawn a telegraph marker hitbox (zero damage, big radius, short life)
	# for test inspection + future VFX hook. Mirrors S1 Boss precedent.
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
	var formula_dmg: int
	if mob_def == null:
		formula_dmg = damage_base
	else:
		formula_dmg = DamageScript.compute_mob_damage(mob_def, _player_vigor())
	var dmg: int = int(round(float(formula_dmg) * SLAM_DAMAGE_MULTIPLIER))
	# Slam is omnidirectional — knockback from construct center outward.
	var kb_dir: Vector2 = Vector2.RIGHT
	if _player != null:
		var to_player: Vector2 = _player.global_position - global_position
		if to_player.length_squared() > 0.0:
			kb_dir = to_player.normalized()
	var player_dist: float = -1.0
	if _player != null:
		player_dist = global_position.distance_to(_player.global_position)
	_combat_trace(
		"ArchiveSentinel._fire_slam_hit",
		(
			"dmg=%d radius=%.0f lifetime=%.2f kb_dir=(%.2f,%.2f) player_dist=%.1f phase=%d"
			% [
				dmg,
				SLAM_HITBOX_RADIUS,
				SLAM_HITBOX_LIFETIME,
				kb_dir.x,
				kb_dir.y,
				player_dist,
				phase
			]
		)
	)
	var hb: Hitbox = _spawn_hitbox(
		Vector2.ZERO,
		dmg,
		kb_dir * SLAM_KNOCKBACK,
		0.0,
		SLAM_HITBOX_RADIUS,
		SLAM_HITBOX_LIFETIME,
	)
	_slam_recovery_left = SLAM_RECOVERY_DURATION
	_slam_cooldown_left = SLAM_COOLDOWN
	_set_state(STATE_SLAM_RECOVERY)
	_fade_out_slam_indicator()
	swing_spawned.emit(SWING_KIND_SLAM_HIT, hb)


# ---- Hitbox spawn helper ---------------------------------------------


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
	_combat_trace(
		"ArchiveSentinel._spawn_hitbox",
		(
			"id=%d pos=(%.0f,%.0f) layer=%d mask=%d monitoring=%s dmg=%d radius=%.0f lifetime=%.2f"
			% [
				hb.get_instance_id(),
				hb.global_position.x,
				hb.global_position.y,
				hb.collision_layer,
				hb.collision_mask,
				str(hb.monitoring),
				dmg,
				radius,
				lifetime
			]
		)
	)
	return hb


# ---- Phase transitions ------------------------------------------------


func _check_phase_boundary() -> void:
	var phase_2_threshold: int = int(round(hp_max * PHASE_2_HP_FRAC))
	if not _phase_2_latched and hp_current <= phase_2_threshold:
		_phase_2_latched = true
		_begin_phase_transition(PHASE_2)


func _begin_phase_transition(target_phase: int) -> void:
	_pending_phase = target_phase
	_phase_transition_left = PHASE_TRANSITION_DURATION
	# Cancel every pending attack timer — the transition window resets the
	# construct's posture so phase 2 opens cleanly with slam armed.
	_cast_telegraph_left = 0.0
	_cast_recovery_left = 0.0
	_slam_telegraph_left = 0.0
	_slam_recovery_left = 0.0
	# Cooldowns intentionally NOT cleared — phase 2 should respect that
	# the last cast / slam happened recently. The cast_cooldown remains so
	# the construct doesn't double-cast at the phase boundary.
	_set_state(STATE_PHASE_TRANSITION)
	# Phase-transition slow-mo (mirrors S1 Boss T3 — Uma BI-16, BI-17).
	# Routes through `TimeScaleDirector` per the migration policy.
	var director: Node = _resolve_time_scale_director()
	if director != null:
		director.request(
			TSD_REASON_PHASE_TRANSITION,
			PHASE_TRANSITION_SCALE,
			PHASE_TRANSITION_SLOW_MO_DURATION,
			director.PRIORITY_NARRATIVE
		)
		_combat_trace(
			"ArchiveSentinel.phase_transition_slow_mo",
			(
				"scale=%.2f duration=%.2f reason=%s target_phase=%d"
				% [
					PHASE_TRANSITION_SCALE,
					PHASE_TRANSITION_SLOW_MO_DURATION,
					TSD_REASON_PHASE_TRANSITION,
					target_phase
				]
			)
		)


func _finish_phase_transition() -> void:
	phase = _pending_phase
	# Re-engage with the player.
	_set_state(STATE_IDLE_ACTIVE)
	phase_changed.emit(phase)


# ---- Death ------------------------------------------------------------


func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	_combat_trace(
		"ArchiveSentinel._die", "starting death sequence at hp=%d phase=%d" % [hp_current, phase]
	)
	# Cancel every pending action so a death-mid-attack doesn't fire from
	# the corpse. Same defensive pattern as Stratum1Boss.
	_cast_telegraph_left = 0.0
	_cast_recovery_left = 0.0
	_slam_telegraph_left = 0.0
	_slam_recovery_left = 0.0
	_phase_transition_left = 0.0
	velocity = Vector2.ZERO
	_cancel_attack_telegraph_tween()
	_force_free_slam_indicator()
	_set_state(STATE_DEAD)
	# boss_died fires at the START of the death sequence (same contract as
	# Stratum1Boss per Uma `combat-visual-feedback.md` §3a). Subscribers
	# (MobLootSpawner, BossRoom signal chain, Main._on_mob_died) run on
	# this frame regardless of the death-tween hold + decay below.
	boss_died.emit(self, global_position, mob_def)
	# Final-freeze (mirrors S1 Boss T2 — 300 ms full-stop AFTER boss_died
	# emit so every subscriber runs at scale=1.0 on the same frame).
	var director: Node = _resolve_time_scale_director()
	if director != null:
		director.freeze(FINAL_FREEZE_DURATION, TSD_REASON_FINAL_FREEZE)
		_combat_trace(
			"ArchiveSentinel.final_freeze",
			"freeze=%.3f reason=%s" % [FINAL_FREEZE_DURATION, TSD_REASON_FINAL_FREEZE]
		)
	# Play die anim (M3W-4 inheritance — drops cleanly when AnimatedSprite2D
	# scene-swap lands).
	_play_anim(&"die")
	# Climax burst — sustained ember-rise (mirrors S1 Boss CLIMAX_BURST_*).
	_spawn_death_particles()
	# Climax shake — 4-logical-px (VD-09 budget).
	_play_climax_shake()
	# Climax tween — extra 400ms hold then 200ms decay.
	_play_boss_death_sequence()


# ---- Visual feedback helpers ------------------------------------------


## Attack-telegraph visual — ember-orange flare on the Sprite child.
## Mirrors S1 Boss `_play_attack_telegraph` 3-branch resolver. The
## construct's tonal beat is ember-light (book pages igniting) so the
## tint is TELEGRAPH_TINT (ember-orange), NOT the S1 Boss vivid-red
## ATTACK_TELEGRAPH_TINT.
func _play_attack_telegraph(telegraph_duration: float) -> void:
	if not is_inside_tree():
		return
	var target: CanvasItem = null
	var prop: String = "modulate"
	var color_at_rest: Color = Color(1, 1, 1, 1)
	var sprite: Node = get_node_or_null("Sprite")
	if sprite is AnimatedSprite2D:
		target = sprite as AnimatedSprite2D
		prop = "modulate"
		color_at_rest = (sprite as AnimatedSprite2D).modulate
	elif sprite is ColorRect:
		target = sprite as ColorRect
		prop = "color"
		color_at_rest = (sprite as ColorRect).color
	else:
		target = self
		prop = "modulate"
		color_at_rest = modulate
	if _attack_telegraph_tween != null and _attack_telegraph_tween.is_valid():
		_attack_telegraph_tween.kill()
	_attack_telegraph_tween = create_tween()
	var hold_dur: float = max(0.0, telegraph_duration - TELEGRAPH_TWEEN_IN * 2.0)
	_attack_telegraph_tween.tween_property(target, prop, TELEGRAPH_TINT, TELEGRAPH_TWEEN_IN)
	_attack_telegraph_tween.tween_property(target, prop, TELEGRAPH_TINT, hold_dur)
	_attack_telegraph_tween.tween_property(target, prop, color_at_rest, TELEGRAPH_TWEEN_IN)
	_combat_trace(
		"ArchiveSentinel._play_attack_telegraph",
		(
			"tween_valid=%s duration=%.2f tint=(%.2f,%.2f,%.2f) prop=%s"
			% [
				_attack_telegraph_tween.is_valid(),
				telegraph_duration,
				TELEGRAPH_TINT.r,
				TELEGRAPH_TINT.g,
				TELEGRAPH_TINT.b,
				prop
			]
		)
	)


func _cancel_attack_telegraph_tween() -> void:
	if _attack_telegraph_tween != null and _attack_telegraph_tween.is_valid():
		_attack_telegraph_tween.kill()
		_attack_telegraph_tween = null


# ---- Slam-telegraph indicator (mirrors S1 Boss SlamTelegraphIndicator) -


func _spawn_slam_indicator(telegraph_duration: float) -> void:
	if not is_inside_tree():
		return
	_force_free_slam_indicator()
	# Sentinel-specific indicator class — wider 96 px draw vs S1 Boss's 80 px.
	# Constants are baked into the indicator class (`ArchiveSentinelSlamIndicator.gd`)
	# rather than passed per-instance to keep the draw path allocation-free
	# and the constant-mirroring auditable via the test pin
	# `test_archive_sentinel_slam_indicator_radius_matches_hitbox`.
	var indicator: Node2D = ArchiveSentinelSlamIndicatorScript.new()
	indicator.position = Vector2.ZERO  # construct-centered (parent-relative)
	indicator.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(indicator)
	_slam_indicator = indicator
	if _slam_indicator_tween != null and _slam_indicator_tween.is_valid():
		_slam_indicator_tween.kill()
	_slam_indicator_tween = create_tween()
	_slam_indicator_tween.tween_property(
		indicator, "modulate:a", SLAM_INDICATOR_STROBE_HIGH, SLAM_INDICATOR_FADE
	)
	var hold_dur: float = max(0.0, telegraph_duration - SLAM_INDICATOR_FADE)
	if hold_dur > 0.0:
		var strobe_cb: Callable = func(t: float) -> void:
			if not is_instance_valid(indicator):
				return
			var phase_t: float = t * SLAM_INDICATOR_STROBE_HZ * TAU
			var s: float = (sin(phase_t) + 1.0) * 0.5  # [0, 1]
			indicator.modulate.a = lerp(SLAM_INDICATOR_STROBE_LOW, SLAM_INDICATOR_STROBE_HIGH, s)
		_slam_indicator_tween.tween_method(strobe_cb, 0.0, hold_dur, hold_dur)
	_combat_trace(
		"ArchiveSentinel._spawn_slam_indicator",
		(
			(
				"radius=%.0f color=(%.2f,%.2f,%.2f,%.2f) telegraph_duration=%.2f "
				+ "fade=%.3f strobe_hz=%.1f strobe=[%.2f..%.2f]"
			)
			% [
				SLAM_HITBOX_RADIUS,
				SLAM_INDICATOR_COLOR.r,
				SLAM_INDICATOR_COLOR.g,
				SLAM_INDICATOR_COLOR.b,
				SLAM_INDICATOR_COLOR.a,
				telegraph_duration,
				SLAM_INDICATOR_FADE,
				SLAM_INDICATOR_STROBE_HZ,
				SLAM_INDICATOR_STROBE_LOW,
				SLAM_INDICATOR_STROBE_HIGH
			]
		)
	)


func _fade_out_slam_indicator() -> void:
	if _slam_indicator == null:
		return
	if not is_instance_valid(_slam_indicator):
		_slam_indicator = null
		return
	if _slam_indicator_tween != null and _slam_indicator_tween.is_valid():
		_slam_indicator_tween.kill()
	var indicator: Node2D = _slam_indicator
	_slam_indicator = null
	_slam_indicator_tween = create_tween()
	_slam_indicator_tween.tween_property(indicator, "modulate:a", 0.0, SLAM_INDICATOR_FADE)
	_slam_indicator_tween.finished.connect(
		func() -> void:
			if is_instance_valid(indicator):
				indicator.queue_free()
	)


func _force_free_slam_indicator() -> void:
	if _slam_indicator_tween != null and _slam_indicator_tween.is_valid():
		_slam_indicator_tween.kill()
		_slam_indicator_tween = null
	if _slam_indicator == null:
		return
	if is_instance_valid(_slam_indicator) and not _slam_indicator.is_queued_for_deletion():
		_slam_indicator.queue_free()
	_slam_indicator = null


# ---- Hit-flash 3-branch resolver (mirrors S1 Boss / Grunt) ----------


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
		_combat_trace(
			"ArchiveSentinel._play_hit_flash",
			(
				"animated_sprite tween_valid=%s tint=(%.2f,%.2f,%.2f) rest=(%.2f,%.2f,%.2f)"
				% [
					_hit_flash_tween.is_valid(),
					HIT_FLASH_TINT.r,
					HIT_FLASH_TINT.g,
					HIT_FLASH_TINT.b,
					_sprite_modulate_at_rest.r,
					_sprite_modulate_at_rest.g,
					_sprite_modulate_at_rest.b
				]
			)
		)
	elif _hit_flash_uses_sprite:
		var sprite_rect: ColorRect = _hit_flash_target as ColorRect
		# Branch 2 — ColorRect placeholder. The base color is the
		# stone-bone-brown stage 5 placeholder Color(0.32, 0.20, 0.18, 1);
		# tween to soft-red HIT_FLASH_TINT and back to rest. The color
		# attribute (NOT modulate) hits the visible-draw on ColorRect.
		_hit_flash_tween.tween_property(sprite_rect, "color", HIT_FLASH_TINT, HIT_FLASH_IN)
		_hit_flash_tween.tween_property(sprite_rect, "color", HIT_FLASH_TINT, HIT_FLASH_HOLD)
		_hit_flash_tween.tween_property(sprite_rect, "color", _sprite_color_at_rest, HIT_FLASH_OUT)
		_combat_trace(
			"ArchiveSentinel._play_hit_flash",
			(
				"color_rect tween_valid=%s rest=(%.2f,%.2f,%.2f) target=(%.2f,%.2f,%.2f)"
				% [
					_hit_flash_tween.is_valid(),
					_sprite_color_at_rest.r,
					_sprite_color_at_rest.g,
					_sprite_color_at_rest.b,
					HIT_FLASH_TINT.r,
					HIT_FLASH_TINT.g,
					HIT_FLASH_TINT.b
				]
			)
		)
	else:
		_hit_flash_tween.tween_property(self, "modulate", HIT_FLASH_TINT, HIT_FLASH_IN)
		_hit_flash_tween.tween_property(self, "modulate", HIT_FLASH_TINT, HIT_FLASH_HOLD)
		_hit_flash_tween.tween_property(self, "modulate", _modulate_at_rest, HIT_FLASH_OUT)
		_combat_trace(
			"ArchiveSentinel._play_hit_flash",
			(
				"modulate-fallback tween_valid=%s rest=(%.2f,%.2f,%.2f)"
				% [
					_hit_flash_tween.is_valid(),
					_modulate_at_rest.r,
					_modulate_at_rest.g,
					_modulate_at_rest.b
				]
			)
		)


## Death sequence — 400ms hold + 200ms scale/fade tween, then queue_free.
## Mirrors S1 Boss `_play_boss_death_sequence` with safety-net timer.
func _play_boss_death_sequence() -> void:
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
		_hit_flash_tween = null
	if not is_inside_tree():
		queue_free()
		return
	_death_tween = create_tween()
	_death_tween.tween_interval(BOSS_DEATH_HOLD)
	_death_tween.tween_property(
		self, "scale", Vector2(DEATH_TARGET_SCALE, DEATH_TARGET_SCALE), DEATH_TWEEN_DURATION
	)
	_death_tween.parallel().tween_property(self, "modulate:a", 0.0, DEATH_TWEEN_DURATION)
	_death_tween.finished.connect(_on_death_tween_finished)
	# Safety-net: parallel timer fires queue_free even if tween_finished
	# hangs. Same shape as S1 Boss safety-net.
	var timer: SceneTreeTimer = get_tree().create_timer(
		BOSS_DEATH_HOLD + DEATH_TWEEN_DURATION + 0.2
	)
	timer.timeout.connect(_force_queue_free)


func _on_death_tween_finished() -> void:
	_force_queue_free()


func _force_queue_free() -> void:
	if is_queued_for_deletion():
		_combat_trace("ArchiveSentinel._force_queue_free", "already queued — second-caller no-op")
		return
	_combat_trace("ArchiveSentinel._force_queue_free", "freeing now")
	queue_free()


## Climax shake — jiggle the construct's own position by ±4 logical px.
## Subtler than S1 Boss because the construct is supposed to feel rooted;
## the shake reads as "the plinth cracks" not "the construct stumbles".
func _play_climax_shake() -> void:
	if not is_inside_tree():
		return
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	var rest_offset: Vector2 = position
	_shake_tween = create_tween()
	var leg: float = BOSS_SHAKE_DURATION / 3.0
	_shake_tween.tween_property(
		self, "position", rest_offset + Vector2(BOSS_SHAKE_MAGNITUDE, 0.0), leg
	)
	_shake_tween.tween_property(
		self, "position", rest_offset + Vector2(-BOSS_SHAKE_MAGNITUDE, 0.0), leg
	)
	_shake_tween.tween_property(self, "position", rest_offset, leg)


## Death particles — sustained ember-rise mirroring S1 Boss CLIMAX_BURST_*.
## Room-parented + deferred add_child per physics-flush rule. z_index +1 so
## the burst draws above the construct sprite (PR #291 T6 same-z occlusion
## lesson). White impact frame at ramp[0] breaks the orange-on-red blend
## per PR #291 v5/v7 finding.
func _spawn_death_particles() -> CPUParticles2D:
	var room: Node = get_parent()
	if room == null:
		return null
	var burst: CPUParticles2D = CPUParticles2D.new()
	burst.global_position = global_position
	burst.z_index = DEATH_BURST_Z_INDEX
	burst.amount = DEATH_BURST_PARTICLE_COUNT
	burst.one_shot = true
	burst.explosiveness = DEATH_BURST_EXPLOSIVENESS
	burst.lifetime = DEATH_BURST_LIFETIME
	burst.emitting = true
	burst.direction = Vector2.UP
	burst.spread = DEATH_BURST_SPREAD_DEG
	burst.initial_velocity_min = DEATH_BURST_VELOCITY_MIN
	burst.initial_velocity_max = DEATH_BURST_VELOCITY_MAX
	burst.gravity = Vector2(0.0, DEATH_BURST_GRAVITY_Y)
	burst.scale_amount_min = DEATH_BURST_SCALE_MIN
	burst.scale_amount_max = DEATH_BURST_SCALE_MAX
	# 3-stop color ramp: impact flash → ember-light → ember-deep.
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, DEATH_BURST_IMPACT_FLASH)
	ramp.set_color(1, EMBER_DEEP)
	ramp.add_point(0.12, EMBER_LIGHT)
	burst.color_ramp = ramp
	room.call_deferred("add_child", burst)
	burst.finished.connect(burst.queue_free)
	_combat_trace(
		"ArchiveSentinel._spawn_death_particles",
		(
			"climax sustained burst — amount=%d lifetime=%.2f explosiveness=%.2f scale=[%.1f,%.1f] z=%d"
			% [
				burst.amount,
				burst.lifetime,
				burst.explosiveness,
				burst.scale_amount_min,
				burst.scale_amount_max,
				burst.z_index
			]
		)
	)
	return burst


# ---- Helpers ----------------------------------------------------------


func _tick_timers(delta: float) -> void:
	if _cast_telegraph_left > 0.0:
		_cast_telegraph_left = max(0.0, _cast_telegraph_left - delta)
	if _cast_recovery_left > 0.0:
		_cast_recovery_left = max(0.0, _cast_recovery_left - delta)
	if _cast_cooldown_left > 0.0:
		_cast_cooldown_left = max(0.0, _cast_cooldown_left - delta)
	if _slam_telegraph_left > 0.0:
		_slam_telegraph_left = max(0.0, _slam_telegraph_left - delta)
	if _slam_recovery_left > 0.0:
		_slam_recovery_left = max(0.0, _slam_recovery_left - delta)
	if _slam_cooldown_left > 0.0:
		_slam_cooldown_left = max(0.0, _slam_cooldown_left - delta)
	if _phase_transition_left > 0.0:
		_phase_transition_left = max(0.0, _phase_transition_left - delta)
	if _wake_left > 0.0:
		_wake_left = max(0.0, _wake_left - delta)


func _set_state(new_state: StringName) -> void:
	if new_state == _state:
		return
	var old: StringName = _state
	_state = new_state
	# M3W-4 animation playback — map state → SpriteFrames anim key. Drops
	# in cleanly when AnimatedSprite2D scene-swap lands. `hit_<dir>` and
	# `die_<dir>` are driven directly from `take_damage` / `_die` as one-
	# shot beats.
	match new_state:
		STATE_WAKING:
			_play_anim(&"wake")
		STATE_IDLE_ACTIVE:
			_play_anim(&"idle_active")
		STATE_CAST:
			_play_anim(&"cast")
		STATE_CAST_RECOVERY:
			_play_anim(&"cast_recovery")
		STATE_SLAM_TELEGRAPH:
			_play_anim(&"slam_telegraph")
		STATE_SLAM_RECOVERY:
			_play_anim(&"slam_recovery")
	state_changed.emit(old, new_state)


# ---- Animation playback ----------------------------------------------


## Play an animation on the AnimatedSprite2D child. Resolves the child
## lazily on first call so bare-instanced test sentinels (no Sprite child
## or ColorRect fallback) no-op safely. Mirrors S1 Boss `_play_anim` /
## Grunt `_play_anim` from M3W-3.
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
			"ArchiveSentinel._play_anim",
			"MISS anim=%s — SpriteFrames lacks this animation key" % anim_name
		)
		return
	if _animated_sprite.animation == anim_name and _animated_sprite.is_playing():
		return
	_animated_sprite.play(anim_name)
	_combat_trace("ArchiveSentinel._play_anim", "PLAY anim=%s" % anim_name)


## Derive the 8-octant direction suffix for the SpriteFrames anim key.
## Sentinel is stationary so the facing-vector comes from the player when
## one exists; defaults to "s" otherwise. The construct rotates its book
## (not its body) to track the player — so the dir-suffix is informational
## for the anim key only; production sprite frames may collapse all
## directions into a single front-facing pose if Uma's authoring stays
## frontal per §5.5 "head-on facing camera".
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


func _apply_mob_def() -> void:
	# Boss HP multiplier (Sponsor 2026-05-21 soak-iteration utility). Resolves
	# to 1.0 (no-op) outside HTML5 and when the `boss_hp_mult` URL param is
	# absent. Mirrors Stratum1Boss._apply_mob_def so `?boss_hp_mult=N` nerfs
	# the Sentinel for phase-2 soak acceleration — closes the parity gap
	# documented in `.claude/docs/html5-export.md` § "New-boss soak
	# acceleration — boss_hp_mult parity gap". Multiplied IN on the bare-
	# instance fallback path too so headless GUT using
	# `DebugFlags.set_boss_hp_mult_for_test(0.2)` can exercise the nerf
	# without supplying a MobDef.
	var hp_mult: float = _resolve_boss_hp_mult()
	if mob_def == null:
		# Bare-instantiated boss (tests). Use spec defaults.
		var bare_hp: int = max(1, int(round(700.0 * hp_mult)))
		hp_max = bare_hp
		hp_current = bare_hp
		damage_base = 14
		move_speed_base = 0.0
		move_speed = 0.0
		return
	var scaled_hp: int = max(1, int(round(float(mob_def.hp_base) * hp_mult)))
	hp_max = scaled_hp
	hp_current = scaled_hp
	damage_base = mob_def.damage_base
	move_speed_base = mob_def.move_speed
	move_speed = move_speed_base


## Resolve the boss HP multiplier from the DebugFlags autoload (defaults to 1.0
## when the autoload is missing — bare-instance unit-test edge). Mirrors
## Stratum1Boss._resolve_boss_hp_mult verbatim: handles the not-inside-tree
## bare-instance edge via Engine.get_main_loop() so a test that writes the
## multiplier BEFORE adding the boss still gets the injected value.
func _resolve_boss_hp_mult() -> float:
	if not is_inside_tree():
		var ml: SceneTree = Engine.get_main_loop() as SceneTree
		if ml == null:
			return 1.0
		var df: Node = ml.root.get_node_or_null("DebugFlags")
		if df == null:
			return 1.0
		return df.boss_hp_mult
	var df_in: Node = get_node_or_null("/root/DebugFlags")
	if df_in == null:
		return 1.0
	return df_in.boss_hp_mult


func _apply_layers() -> void:
	const BARE_DEFAULT_LAYER: int = 1
	if collision_layer == 0 or collision_layer == BARE_DEFAULT_LAYER:
		collision_layer = LAYER_ENEMY
	if collision_mask == 0 or collision_mask == BARE_DEFAULT_LAYER:
		collision_mask = LAYER_WORLD | LAYER_PLAYER


## Force `motion_mode = MOTION_MODE_FLOATING` — same rationale as S1 Boss
## (top-down 2D best practice). The construct is stationary so motion_mode
## is moot in practice, but the canonical floating mode is the right
## default for any new top-down CharacterBody2D mob.
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


# ---- Combat-trace shim ------------------------------------------------


func _combat_trace(tag: String, msg: String = "") -> void:
	var df: Node = null
	if is_inside_tree():
		df = get_tree().root.get_node_or_null("DebugFlags")
	if df != null and df.has_method("combat_trace"):
		df.combat_trace(tag, msg)


# ---- Audio cue wiring -------------------------------------------------


## Connect existing combat signals to AudioDirector SFX plays. Mirrors S1
## Boss `_wire_audio_cues` shape:
##   damaged(amount>0)   → SFX_MOB_HIT
##   boss_died           → SFX_BOSS_DIE
##   swing_spawned       → SFX_ATTACK_TELEGRAPH for slam_telegraph,
##                          SFX_ATTACK_IMPACT for cast + slam_hit
##   boss_woke           → SFX_BOSS_WAKE (Uma BI-06)
##   phase_changed       → SFX_PHASE_BREAK (Uma BI-18)
func _wire_audio_cues() -> void:
	if not damaged.is_connected(_on_damaged_audio):
		damaged.connect(_on_damaged_audio)
	if not boss_died.is_connected(_on_boss_died_audio):
		boss_died.connect(_on_boss_died_audio)
	if not swing_spawned.is_connected(_on_swing_spawned_audio):
		swing_spawned.connect(_on_swing_spawned_audio)
	if not boss_woke.is_connected(_on_boss_woke_audio):
		boss_woke.connect(_on_boss_woke_audio)
	if not phase_changed.is_connected(_on_phase_changed_audio):
		phase_changed.connect(_on_phase_changed_audio)


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


func _on_boss_died_audio(_mob: ArchiveSentinel, _pos: Vector2, _def: MobDef) -> void:
	var ad: Node = _resolve_audio_director()
	if ad == null or not ad.has_method("play_sfx"):
		return
	ad.play_sfx(&"sfx-boss-die")


func _on_swing_spawned_audio(kind: StringName, _hitbox: Node) -> void:
	var ad: Node = _resolve_audio_director()
	if ad == null or not ad.has_method("play_sfx"):
		return
	if kind == SWING_KIND_SLAM_TELEGRAPH:
		ad.play_sfx(&"sfx-attack-telegraph")
	else:
		ad.play_sfx(&"sfx-attack-impact")


func _on_boss_woke_audio() -> void:
	var ad: Node = _resolve_audio_director()
	if ad == null or not ad.has_method("play_sfx"):
		return
	ad.play_sfx(&"sfx-boss-wake")


func _on_phase_changed_audio(_new_phase: int) -> void:
	var ad: Node = _resolve_audio_director()
	if ad == null or not ad.has_method("play_sfx"):
		return
	ad.play_sfx(&"sfx-phase-break")
