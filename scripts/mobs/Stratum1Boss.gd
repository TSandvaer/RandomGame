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

# ---- M3 Tier 2 Wave 1 T2 + T3 cinematic-feel constants ----------------
# T2 hit-pause + final-freeze (ticket 86c9wjy1t):
# T3 phase-transition world-time-slow (ticket 86c9wjy46):
# All Engine.time_scale mutations route through `TimeScaleDirector` (T11 / PR #285).
# Direct `Engine.time_scale = X` writes are prohibited outside the director per
# `.claude/docs/time-scale-director.md` "Migration policy".

## Hit-pause duration on a player → boss damage-landing light swing (Priya AC).
## Microscopic by design — 60 ms reads as "the world flinches" without
## interrupting input flow. Mirrors VD-07 budget in `combat-visual-feedback.md`.
const HIT_PAUSE_LIGHT_DURATION: float = 0.060

## Hit-pause duration on a player → boss damage-landing heavy swing (Priya AC).
## 100 ms — slightly longer than light because heavy carries more visual weight.
const HIT_PAUSE_HEAVY_DURATION: float = 0.100

## Final-freeze duration on boss `_die` (Priya AC + Uma F1). Fires AFTER
## `boss_died.emit(...)` so subscribers (MobLootSpawner, BossRoom signal chain,
## Main._on_mob_died) execute at scale=1.0 on the same frame. The 300 ms freeze
## then lands on the next frame as a true `freeze()` request (priority=FREEZE,
## scale=0.0). Real-time auto-release per the director's `ignore_time_scale=true`
## SceneTreeTimer.
const FINAL_FREEZE_DURATION: float = 0.300

## TimeScaleDirector reason keys. Stable strings — re-using a reason REPLACES the
## prior request (idempotent refresh, per the director's contract). Different
## reasons for hit-pause vs final-freeze vs phase-transition so they coexist on
## the stack cleanly (e.g. a phase-transition request can hold while a hit-pause
## auto-expires — priority resolution picks the right scale).
const TSD_REASON_HIT_PAUSE: String = "boss_hit_pause"
const TSD_REASON_FINAL_FREEZE: String = "boss_final_freeze"
const TSD_REASON_PHASE_TRANSITION: String = "boss_phase_transition"

## T3 phase-transition slow-mo (Uma BI-16, BI-17). Engine.time_scale = 0.3 for
## 0.6 s, then snaps back to 1.0 via the director's auto-release. The 0.2 s ramp
## back in Uma's spec is intentionally NOT modeled here — the director resolves
## by step-function and Priya's AC accepts the snap-back as the M3 Tier 2 shape.
## A ramp-back would require a sub-request tween that interpolates a second
## director entry; deferred to a polish follow-up if Sponsor flags the snap as
## abrupt during soak.
const PHASE_TRANSITION_SCALE: float = 0.3
const PHASE_TRANSITION_SLOW_MO_DURATION: float = 0.60

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

## Hit-flash modulate tint for the AnimatedSprite2D path (M3W-1 / M3W-4 convention).
## Mirrors `PracticeDummy.HIT_FLASH_TINT` + `Grunt.HIT_FLASH_TINT` verbatim per the
## inheritance contract in `.claude/docs/combat-architecture.md` § "M3W-1 realized
## implementation". Sub-1.0 on every channel for HTML5 HDR-clamp safety; channel-sum
## delta ≥ 0.20 vs rest white. Uniform across the M3 mob roster — every mob's
## hit-flash reads the same wash so "I hit something" is unambiguous.
const HIT_FLASH_TINT: Color = Color(1.0, 0.50, 0.50, 1.0)  # soft red wash, HTML5-safe

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

# Hit-flash target — M3W-4 3-branch resolver per `.claude/docs/combat-architecture.md`
# § "M3W-1 realized implementation":
#   1. AnimatedSprite2D child (production .tscn-loaded boss) → tween modulate
#      with HIT_FLASH_TINT red-wash (rest → tint → rest). Painted PixelLab sprite
#      frames are near-white, so a white-to-white tween would be a visible no-op
#      (PR #115 / #140 trap class); the soft-red tint avoids this while preserving
#      the rest of the sprite's painted color. Sub-1.0 channels per HTML5 HDR-clamp.
#   2. ColorRect child (legacy bare-instanced test bosses) → tween Sprite.color
#      rest → white → rest (pre-M3W-4 Bug C fix pattern, kept for back-compat).
#   3. No Sprite child (bare-instanced test bosses) → tween self.modulate
#      (preserves Tier 1 reference-change invariant in GUT).
#
# `_hit_flash_uses_sprite` is true iff branch (1) OR (2). Branch (1) vs (2) is
# discriminated by `_hit_flash_uses_animated_sprite`.
var _hit_flash_target: CanvasItem = null
var _hit_flash_uses_sprite: bool = false
var _hit_flash_uses_animated_sprite: bool = false
var _sprite_color_at_rest: Color = Color(1, 1, 1, 1)
var _sprite_modulate_at_rest: Color = Color(1, 1, 1, 1)

# AnimatedSprite2D cache (M3W-4) — resolved lazily from get_node_or_null("Sprite")
# so tests that instantiate the production scene get animation-playback hooks
# even when constructed bare. `_animated_sprite_resolved` is true once we've
# checked, so we don't repeat the cast on every state transition.
var _animated_sprite: AnimatedSprite2D = null
var _animated_sprite_resolved: bool = false

# Attack-telegraph tween — ref kept so death-during-telegraph can cancel it.
var _attack_telegraph_tween: Tween = null

# T5 slam-telegraph indicator runtime — Node2D child created at telegraph start
# and freed on slam-fire or boss-death. Held by ref so `_fire_slam_hit` and
# `_die` can drive the fade-out + cleanup. Null when no telegraph is armed.
var _slam_indicator: Node2D = null
var _slam_indicator_tween: Tween = null

## Red tint for melee/slam telegraph (player-journey.md Beat 6). Sub-1.0 all
## channels for HTML5 gl_compatibility safety (PR #137 lesson). Brighter than
## grunts to make the boss wind-up clearly readable.
const ATTACK_TELEGRAPH_TINT: Color = Color(1.0, 0.25, 0.25, 1.0)  # vivid red, HTML5 safe
const ATTACK_TELEGRAPH_TWEEN_IN: float = 0.080

# ---- M3 Tier 2 Wave 2 T5+T6 — slam telegraph indicator + aftershock burst --
# T5 (ticket 86c9wjyrc): visible slam-telegraph danger-zone circle outline.
# T6 (ticket 86c9wjyuv): slam aftershock ember-burst on slam-fire impact.
#
# Implementation note (T5 deviation from ticket title): the ticket says
# "Polygon2D circle" but Polygon2D natively renders filled convex polygons —
# rendering an outline ring would require either (a) a 32-vertex annulus
# polygon (32 outer + 32 inner verts), or (b) a Node2D._draw() + draw_arc()
# call. Option (b) is the canonical Godot 4 idiom for a circle outline and
# does NOT touch the html5-export.md § Polygon2D rendering quirks failure
# class (which is the PR #137 swing-wedge bug — that was a FILLED polygon).
# We use Node2D + _draw() + draw_arc(). The 32-segment arc renders identically
# on `forward_plus` and `gl_compatibility` (verified pattern via Godot 4.3
# rendering docs — `draw_arc` is part of the canvas-item draw API, not the
# Polygon2D rasterizer).

## T5 slam telegraph circle indicator — ember-orange outline at SLAM_HITBOX_RADIUS.
## Color: #FF6A2A at alpha 0.5. Sub-1.0 RGB channels per html5-export.md HDR-clamp
## rule (PR #137 lesson — gl_compatibility clamps Color channels to [0, 1]).
const SLAM_INDICATOR_COLOR: Color = Color(1.0, 0.416, 0.165, 0.5)
const SLAM_INDICATOR_LINE_WIDTH: float = 2.0
## Fade-in / fade-out duration at telegraph start / slam-fire (Priya AC).
const SLAM_INDICATOR_FADE: float = 0.080
## draw_arc segment count — 32 segments produce a smooth circle at 80 px radius.
const SLAM_INDICATOR_ARC_POINTS: int = 32
## T5 strobe parameters (Sponsor 2026-05-21 soak — "circle disappears too fast,
## should also be blinking"). After fade-in, the modulate.a strobes between a
## high and low value at ~5 Hz (one full cycle = 200 ms) across the hold window
## (~420 ms = SLAM_TELEGRAPH_DURATION - fade_in - fade_out budget). That budget
## fits ~2 full pulses, which is sufficient to read as "danger imminent."
##
## 5 Hz is well within feel-targets for boss-AoE telegraphs in shipped ARPGs
## and below the seizure-risk threshold for our class of stimulus (small,
## peripheral, low-contrast, color-only — not the high-contrast full-screen
## red-flashing pattern epilepsy guidance restricts). The base color α=0.5
## multiplies through; perceived peak = HIGH × 0.5 = 0.5, perceived trough =
## LOW × 0.5 = 0.125 — strong on/off contrast.
##
## Sponsor's "disappears too fast" complaint maps to the absence of motion
## during the 420 ms hold (a static circle reads as decoration); strobing
## restores the "imminent" read without lengthening combat-timing windows.
const SLAM_INDICATOR_STROBE_HZ: float = 5.0
const SLAM_INDICATOR_STROBE_HIGH: float = 1.0   # perceived peak alpha = 1.0 × 0.5 = 0.5
const SLAM_INDICATOR_STROBE_LOW: float = 0.25   # perceived trough     = 0.25 × 0.5 = 0.125

## T6 slam aftershock burst — was "half-volume" mirror of `_spawn_death_particles`
## (12 vs 24). v5 (PR #291 SHA `83831c4` self-soak 2026-05-21): empirical screenshot
## capture confirmed particles ARE rendering — but at 12 particles + ember ramp
## (`EMBER_LIGHT` → `EMBER_DEEP`, both warm-red) they blend with the boss's red
## armor and read as boss-sprite noise rather than a distinct impact tell. Sponsor
## "see no aftershock" on v3 is a visibility / contrast issue, not a missing-fire
## issue (trace shows `_spawn_slam_aftershock | particles=12 ... origin=(240,165)
## parent_path=/root/Main/World/Stratum1BossRoom` firing correctly). Fix shape:
## raise to 24 (matching death-burst density) + replace `EMBER_LIGHT` ramp[0] with
## a near-white-hot impact flash (`AFTERSHOCK_FLASH_WHITE`) so the burst starts
## bright and fades to ember — gives the high-contrast "impact" frame the boss's
## red armor was washing out. Death-burst keeps ember-only because the boss is
## already dead and there's no sprite to contrast against.
const SLAM_AFTERSHOCK_PARTICLE_COUNT: int = 24
## Lifetime BUMPED from 200 ms (scope-AC) → 350 ms after Sponsor 2026-05-21 soak
## report "see no aftershock" on SHA `46bdcc9`. 200 ms × 60 fps = 12 frames —
## empirically insufficient for the burst to read in HTML5 / `gl_compatibility`,
## particularly with no rising gravity (particles stayed near boss origin and
## drew behind the AnimatedSprite2D sprite child). v5 keeps 350 ms — screenshot
## capture confirmed the duration is correct; visibility is now solved via
## particle count + impact-flash ramp, not lifetime. Documented in PR #291
## Self-Test Report v5.
const SLAM_AFTERSHOCK_LIFETIME: float = 0.35
## Impact-flash color for the aftershock ramp[0]. Near-white-hot so the first
## ~50 ms of the burst flashes bright against the red boss armor before fading
## to `EMBER_DEEP`. Uma's "impact flash" visual-language pattern from death-burst
## doesn't apply (death is post-sprite-fade); aftershock fires WHILE the boss
## sprite is on-screen, so the start-color needs to contrast against red armor
## not blend with it. Channel-sum 1.0+0.95+0.75 = 2.7 vs `EMBER_LIGHT` 1.0+0.69+0.40
## = 2.09 — the +29% luminance lift is what makes the impact frame read.
## All channels < 1.05 for HTML5 HDR-clamp safety per `.claude/docs/html5-export.md`.
const AFTERSHOCK_FLASH_WHITE: Color = Color(1.0, 0.95, 0.75, 1.0)  # #FFF2BF
## Outward velocity range (px/s) — 40-80 per Priya AC. Slower than death burst's
## 30-60 because aftershock is impact-radial; death burst is upward-rising.
const SLAM_AFTERSHOCK_VELOCITY_MIN: float = 40.0
const SLAM_AFTERSHOCK_VELOCITY_MAX: float = 80.0
## Spread is half-angle around `direction`. 180° + direction=UP gives uniform
## omni-radial emission — mirrors death burst.
const SLAM_AFTERSHOCK_SPREAD: float = 180.0
## Rising gravity — pulls embers UP at -50 px/s² (mirrors death-burst's -40,
## slightly stronger so the burst clears the boss sprite faster within the
## 350 ms lifetime). Sponsor "see no aftershock" diagnosis: without rising
## gravity, omni-radial particles spread at boss chest-height and stay behind
## the AnimatedSprite2D. Rising-gravity lifts them above the sprite so the
## burst is readable as an impact tell.
const SLAM_AFTERSHOCK_GRAVITY: Vector2 = Vector2(0.0, -50.0)
## Particle scale — 1.5 px (50% larger than death-burst's 1.0). Larger ember
## footprint compensates for the smaller count (12 vs 24) and the shorter
## lifetime, so each particle reads on screen for the available frames.
const SLAM_AFTERSHOCK_SCALE: float = 1.5
## z_index +1 lifts the burst draw-layer above the boss AnimatedSprite2D
## (sprite z_index=0). Per `.claude/docs/html5-export.md` § "Z-index
## sensitivity" — never rely on negative z_index in `gl_compatibility`; this
## positive lift ensures the burst draws over the boss body sprite.
const SLAM_AFTERSHOCK_Z_INDEX: int = 1


func _ready() -> void:
	_apply_mob_def()
	_apply_layers()
	_apply_motion_mode()
	_resolve_player()
	if skip_intro_for_tests:
		_state = STATE_IDLE
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
	# Visual: red-wash hit-flash + hit anim on every actual-damage take_damage
	# (Uma §2 — same rule across all mob types). M3W-4: also play `hit_<dir>` on
	# the AnimatedSprite2D — one-shot beat that interrupts the state anim. Same
	# shape as Grunt's M3W-3 wiring.
	if clean_amount > 0:
		_play_hit_flash()
		_play_anim(&"hit")
	# Knockback applied as instantaneous velocity. Boss is a heavy unit so
	# the actual visual displacement is small; this still gives the player
	# the satisfaction of "I hit it." We skip knockback during the
	# slam-telegraph windup so the slam stays predictable for the player —
	# same rationale as Charger skipping knockback mid-charge.
	if _state != STATE_TELEGRAPHING_SLAM and knockback.length_squared() > 0.0:
		velocity = knockback
	if hp_current == 0:
		# Fatal hit → `_die()` fires the final-freeze (after `boss_died.emit`).
		# Skip the per-hit hit-pause here: stacking a 60–100 ms micro-pause
		# directly into a 300 ms freeze would be visually identical to the
		# freeze alone but more code-paths than necessary. Final-freeze
		# subsumes the hit-pause on the lethal blow.
		_die()
		return
	# T2 hit-pause (ticket 86c9wjy1t) — non-fatal player → boss hits only.
	# Routes through `TimeScaleDirector` per `.claude/docs/time-scale-director.md`
	# § Migration policy (no direct Engine.time_scale writes).
	# Suppressed on dormant / phase-transition / dead hits — those branches
	# returned earlier in this function, so we only reach here on a real damage
	# landing.
	if clean_amount > 0:
		_request_hit_pause_for(source)
	# Phase-boundary latch + transition kick-off — runs LAST so the hit-pause
	# above lands before the phase-transition slow-mo overlays its request on
	# the director stack (PRIORITY_FREEZE on hit-pause trumps PRIORITY_NARRATIVE
	# on phase-transition anyway, so ordering is documentation, not load-bearing).
	_check_phase_boundaries()


# ---- M3 Tier 2 Wave 1 T2 — hit-pause helper ----------------------------

## Fire a hit-pause `freeze()` request on a damage-landing player swing. The
## duration depends on the swing kind (light=60 ms, heavy=100 ms per Priya AC).
## Source-kind is discovered via duck-typed dispatch on `Player.get_current_attack_kind()`
## — falls back to the light duration if the accessor is absent (test stubs).
##
## A null `source` (bare-instance GUT tests using `b.take_damage(dmg, kb, null)`)
## also falls back to the light duration. Production hits always carry a Player
## source via `Hitbox.configure(...).source`.
func _request_hit_pause_for(source: Node) -> void:
	var director: Node = _resolve_time_scale_director()
	if director == null:
		# Bare-instance tests / pre-autoload contexts — no-op.
		return
	var duration: float = HIT_PAUSE_LIGHT_DURATION
	if source != null and source.has_method("get_current_attack_kind"):
		var kind: StringName = source.get_current_attack_kind()
		if kind == &"heavy":
			duration = HIT_PAUSE_HEAVY_DURATION
	# `freeze()` is the canonical sugar for full-stop hit-pause:
	#   - scale=0.0 (PRIORITY_FREEZE so it trumps every other ordinary request)
	#   - real-time SceneTreeTimer (ignore_time_scale=true) — auto-release fires
	#     at wall-clock duration even though Engine.time_scale is 0.0.
	# Re-requesting "boss_hit_pause" REPLACES the prior request (idempotent
	# refresh — a rapid-fire hit-spam in the same window just resets the clock).
	director.freeze(duration, TSD_REASON_HIT_PAUSE)
	_combat_trace("Stratum1Boss.hit_pause",
		"freeze=%.3f reason=%s source=%s" % [duration, TSD_REASON_HIT_PAUSE,
			"player" if source != null else "null"])


## Resolve the `TimeScaleDirector` autoload, or null in a bare-instanced test
## context where no autoloads are registered. Mirrors the lookup pattern of
## `_combat_trace` / `_resolve_audio_director`.
func _resolve_time_scale_director() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("TimeScaleDirector")


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
	# Null-def fallback: when mob_def is null (bare-instantiated in tests),
	# compute_mob_damage returns 0. Use damage_base directly instead —
	# _apply_mob_def seeds it to 12 for null-def, so the hitbox carries
	# non-zero damage even in the no-def test path.
	var formula_dmg: int
	if mob_def == null:
		formula_dmg = damage_base
	else:
		formula_dmg = DamageScript.compute_mob_damage(mob_def, _player_vigor())
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
	# T5 (ticket 86c9wjyrc): visible danger-zone circle indicator at slam outer
	# radius. Parent-relative to the boss so it tracks any boss displacement
	# during the telegraph window. Spawn BEFORE the marker hitbox so headless
	# tests inspecting children see both in deterministic order.
	_spawn_slam_indicator(_slam_telegraph_left)
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
	# Null-def fallback: mirrors _fire_melee_swing — use damage_base when
	# mob_def is null so headless tests get non-zero slam damage.
	var formula_dmg: int
	if mob_def == null:
		formula_dmg = damage_base
	else:
		formula_dmg = DamageScript.compute_mob_damage(mob_def, _player_vigor())
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
	# T5 (ticket 86c9wjyrc): fade out the danger-zone indicator on slam-fire.
	# The fade-out tween auto-frees the indicator on completion.
	_fade_out_slam_indicator()
	# T6 (ticket 86c9wjyuv): 12-particle ember aftershock at slam origin.
	# Parented to the room (not the boss) so the burst persists past
	# slam-recovery if the boss subsequently dies and queue_frees itself.
	_spawn_slam_aftershock()
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
	# T3 phase-transition world-time-slow (ticket 86c9wjy46 / Uma BI-16, BI-17).
	# Routes through `TimeScaleDirector` per `.claude/docs/time-scale-director.md`
	# § Migration policy. Engine.time_scale = 0.3 for 0.6 s, auto-released via
	# real-time SceneTreeTimer so the slow-mo doesn't compound itself by
	# slowing its own release timer (ignore_time_scale=true).
	#
	# PRIORITY_NARRATIVE so a concurrent T2 hit-pause (PRIORITY_FREEZE, scale=0.0)
	# still trumps this — but no hit can land during phase-transition anyway
	# (the take_damage early-return on STATE_PHASE_TRANSITION upstream), so the
	# concurrent-resolution path is structural-correctness only.
	#
	# Idempotent on rapid hit-spam straddling the boundary in one tick: the
	# `_phase_2_latched` / `_phase_3_latched` guards upstream in
	# `_check_phase_boundaries` ensure `_begin_phase_transition` fires exactly
	# once per boundary, so this request is also single-fire.
	var director: Node = _resolve_time_scale_director()
	if director != null:
		director.request(
			TSD_REASON_PHASE_TRANSITION,
			PHASE_TRANSITION_SCALE,
			PHASE_TRANSITION_SLOW_MO_DURATION,
			director.PRIORITY_NARRATIVE)
		_combat_trace("Stratum1Boss.phase_transition_slow_mo",
			"scale=%.2f duration=%.2f reason=%s target_phase=%d" % [
				PHASE_TRANSITION_SCALE, PHASE_TRANSITION_SLOW_MO_DURATION,
				TSD_REASON_PHASE_TRANSITION, target_phase])


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
	# T5 (ticket 86c9wjyrc): if boss dies mid-slam-telegraph, free the danger-
	# zone indicator immediately — no fade-out, the climax burst should not
	# share the screen with a stale telegraph circle.
	_force_free_slam_indicator()
	_set_state(STATE_DEAD)
	# CRITICAL CONTRACT (Uma `combat-visual-feedback.md` §3a): boss_died
	# fires at the START of the death sequence (this frame), NOT after the
	# climax decay. The cinematic layer + MobLootSpawner.on_mob_died run on
	# this frame regardless of the +400ms hold + 200ms tween below.
	boss_died.emit(self, global_position, mob_def)
	# T2 final-freeze (ticket 86c9wjy1t / Uma BI-23 / F1) — 300 ms full-stop
	# AFTER `boss_died.emit(...)` returns so every subscriber (MobLootSpawner,
	# BossRoom signal chain, Main._on_mob_died → auto_collect_pickups) runs at
	# scale=1.0 on the same frame. Real-time auto-release via the director's
	# `ignore_time_scale=true` SceneTreeTimer — the freeze cannot strand
	# because the auto-release fires on wall-clock regardless of scale.
	# Re-using `TSD_REASON_FINAL_FREEZE` so a hypothetical second `_die` call
	# (defensively guarded by `_is_dead`, but belt-and-suspenders) idempotently
	# refreshes the freeze rather than stacking two entries.
	var director: Node = _resolve_time_scale_director()
	if director != null:
		director.freeze(FINAL_FREEZE_DURATION, TSD_REASON_FINAL_FREEZE)
		_combat_trace("Stratum1Boss.final_freeze",
			"freeze=%.3f reason=%s" % [FINAL_FREEZE_DURATION, TSD_REASON_FINAL_FREEZE])
	# M3W-4 anim: play `die_<dir>` (falling-backward). Plays concurrently with
	# the boss-climax scale/alpha death tween — the AnimatedSprite2D advances its
	# 7-frame die anim while the parent fades + scales. Loop=false on `die_*` in
	# Stratum1Boss.tres so the anim holds on the last frame until queue_free.
	_play_anim(&"die")
	# Climax burst: 24 ember particles parented to the room.
	_spawn_death_particles()
	# Climax shake: 4-logical-px screen-shake within VD-09 budget.
	_play_climax_shake()
	# Climax tween: extra 400ms hold *then* the standard 200ms decay.
	_play_boss_death_sequence()


# ---- Visual feedback helpers (per Uma `combat-visual-feedback.md`) ---

## Attack-telegraph visual (player-journey.md Beat 6 + M1 RC soak-4):
## tween the Sprite child to red for the melee/slam telegraph window.
## `telegraph_duration` is the actual armed duration (varies with phase 3 enrage).
## Sub-1.0 all channels for HTML5 gl_compatibility safety (PR #137 lesson).
##
## M3W-4 3-branch resolver — parallel to `_play_hit_flash`:
##   1. AnimatedSprite2D child (production) → tween modulate (`modulate` property).
##      Painted PixelLab frames are near-white, so the red tint reads visibly.
##   2. ColorRect child (legacy bare-instanced test) → tween `color`.
##   3. No Sprite child (bare-instanced test edge) → tween self.modulate.
## Targets Sprite child (visible-draw node) not parent modulate (PR #115 lesson).
func _play_attack_telegraph(telegraph_duration: float) -> void:
	if not is_inside_tree():
		return
	var target: CanvasItem = null
	var prop: String = "modulate"
	var color_at_rest: Color = Color(1, 1, 1, 1)
	var sprite: Node = get_node_or_null("Sprite")
	if sprite is AnimatedSprite2D:
		# Branch 1 (M3W-4 production): tween AnimatedSprite2D.modulate.
		target = sprite as AnimatedSprite2D
		prop = "modulate"
		color_at_rest = (sprite as AnimatedSprite2D).modulate
	elif sprite is ColorRect:
		# Branch 2 (legacy): tween ColorRect.color.
		target = sprite as ColorRect
		prop = "color"
		color_at_rest = (sprite as ColorRect).color
	else:
		# Branch 3 (bare test): tween self.modulate.
		target = self
		prop = "modulate"
		color_at_rest = modulate
	if _attack_telegraph_tween != null and _attack_telegraph_tween.is_valid():
		_attack_telegraph_tween.kill()
	_attack_telegraph_tween = create_tween()
	var hold_dur: float = max(0.0, telegraph_duration - ATTACK_TELEGRAPH_TWEEN_IN * 2.0)
	_attack_telegraph_tween.tween_property(target, prop, ATTACK_TELEGRAPH_TINT, ATTACK_TELEGRAPH_TWEEN_IN)
	_attack_telegraph_tween.tween_property(target, prop, ATTACK_TELEGRAPH_TINT, hold_dur)
	_attack_telegraph_tween.tween_property(target, prop, color_at_rest, ATTACK_TELEGRAPH_TWEEN_IN)
	_combat_trace("Stratum1Boss._play_attack_telegraph",
		"tween_valid=%s duration=%.2f tint=(%.2f,%.2f,%.2f) prop=%s" % [
			_attack_telegraph_tween.is_valid(), telegraph_duration,
			ATTACK_TELEGRAPH_TINT.r, ATTACK_TELEGRAPH_TINT.g, ATTACK_TELEGRAPH_TINT.b,
			prop
		])


func _cancel_attack_telegraph_tween() -> void:
	if _attack_telegraph_tween != null and _attack_telegraph_tween.is_valid():
		_attack_telegraph_tween.kill()
		_attack_telegraph_tween = null


# ---- T5 slam-telegraph indicator (ticket 86c9wjyrc) -------------------

## Spawn the slam-telegraph danger-zone circle indicator as a child of the boss.
## Parent-relative so the indicator follows the boss if it moves during telegraph.
## Uses a Node2D + `_draw()` + `draw_arc()` (NOT Polygon2D — see header comment
## under "Implementation note (T5 deviation from ticket title)" for rationale).
## `telegraph_duration` is the actual armed duration (varies with phase-3 enrage).
## Fade-in over SLAM_INDICATOR_FADE, hold for the rest, fade-out triggered
## externally by `_fade_out_slam_indicator()` on slam-fire.
func _spawn_slam_indicator(telegraph_duration: float) -> void:
	if not is_inside_tree():
		return
	# Defensive: if a prior indicator still exists (shouldn't under nominal
	# state-machine flow, but rapid telegraph re-entry would stack them),
	# free it before spawning the new one.
	_force_free_slam_indicator()
	var indicator: Node2D = SlamTelegraphIndicator.new()
	indicator.position = Vector2.ZERO  # boss-centered (parent-relative)
	# Start fully transparent — fade-in tween drives the reveal.
	indicator.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(indicator)
	_slam_indicator = indicator
	if _slam_indicator_tween != null and _slam_indicator_tween.is_valid():
		_slam_indicator_tween.kill()
	# Fade-in then strobe (Sponsor 2026-05-21 — "should also be blinking").
	# Replaces the prior flat-hold with a `tween_method`-driven sine-wave pulse
	# at SLAM_INDICATOR_STROBE_HZ between LOW and HIGH alpha for the hold
	# duration. The underlying draw color stays at α=0.5; the multiplied
	# modulate.a strobes the perceived alpha between 0.125 (trough) and 0.5
	# (peak). Slam-fire fade-out is still triggered externally by
	# `_fade_out_slam_indicator()` — it kills this tween and owns the channel.
	_slam_indicator_tween = create_tween()
	_slam_indicator_tween.tween_property(
		indicator, "modulate:a", SLAM_INDICATOR_STROBE_HIGH, SLAM_INDICATOR_FADE)
	# Strobe across the remaining window. tween_method drives a custom callback
	# every frame across `hold_dur` seconds; the callback writes modulate.a
	# from a sine wave. tween_interval would only delay; we want continuous
	# motion during the hold.
	var hold_dur: float = max(0.0, telegraph_duration - SLAM_INDICATOR_FADE)
	if hold_dur > 0.0:
		var strobe_cb: Callable = func(t: float) -> void:
			if not is_instance_valid(indicator):
				return
			# Sine wave 0 → 1 → 0 → 1 across `t` seconds. `t` is elapsed tween
			# time (0 → hold_dur). Map to phase via STROBE_HZ.
			# sin() output is [-1, 1]; remap to [LOW, HIGH].
			var phase: float = t * SLAM_INDICATOR_STROBE_HZ * TAU
			var s: float = (sin(phase) + 1.0) * 0.5  # [0, 1]
			indicator.modulate.a = lerp(
				SLAM_INDICATOR_STROBE_LOW, SLAM_INDICATOR_STROBE_HIGH, s)
		_slam_indicator_tween.tween_method(strobe_cb, 0.0, hold_dur, hold_dur)
	_combat_trace("Stratum1Boss._spawn_slam_indicator",
		("radius=%.0f color=(%.2f,%.2f,%.2f,%.2f) telegraph_duration=%.2f " +
		 "fade=%.3f strobe_hz=%.1f strobe=[%.2f..%.2f]") % [
			SLAM_HITBOX_RADIUS,
			SLAM_INDICATOR_COLOR.r, SLAM_INDICATOR_COLOR.g,
			SLAM_INDICATOR_COLOR.b, SLAM_INDICATOR_COLOR.a,
			telegraph_duration, SLAM_INDICATOR_FADE,
			SLAM_INDICATOR_STROBE_HZ,
			SLAM_INDICATOR_STROBE_LOW, SLAM_INDICATOR_STROBE_HIGH])


## Trigger fade-out on the slam-telegraph indicator (called from `_fire_slam_hit`).
## Frees the indicator on tween completion. Idempotent — null-checked.
func _fade_out_slam_indicator() -> void:
	if _slam_indicator == null:
		return
	if not is_instance_valid(_slam_indicator):
		_slam_indicator = null
		return
	# Kill the fade-in/hold tween so the fade-out animation owns the modulate
	# channel cleanly without a race against the hold step.
	if _slam_indicator_tween != null and _slam_indicator_tween.is_valid():
		_slam_indicator_tween.kill()
	# Capture local ref so the lambda's free-on-finished closure works even
	# if `_slam_indicator` is reassigned mid-tween (rapid re-telegraph corner).
	var indicator: Node2D = _slam_indicator
	_slam_indicator = null
	_slam_indicator_tween = create_tween()
	_slam_indicator_tween.tween_property(
		indicator, "modulate:a", 0.0, SLAM_INDICATOR_FADE)
	_slam_indicator_tween.finished.connect(func() -> void:
		if is_instance_valid(indicator):
			indicator.queue_free())


## Immediate free of the slam-telegraph indicator without fade-out. Used by
## `_die` (death-mid-telegraph) and as a defensive double-spawn guard in
## `_spawn_slam_indicator`. Idempotent — null-checked + queued-for-deletion check.
func _force_free_slam_indicator() -> void:
	if _slam_indicator_tween != null and _slam_indicator_tween.is_valid():
		_slam_indicator_tween.kill()
		_slam_indicator_tween = null
	if _slam_indicator == null:
		return
	if is_instance_valid(_slam_indicator) and not _slam_indicator.is_queued_for_deletion():
		_slam_indicator.queue_free()
	_slam_indicator = null


# ---- T6 slam aftershock burst (ticket 86c9wjyuv) ---------------------

## Spawn a 12-particle ember aftershock at the slam origin. Half-volume mirror
## of `_spawn_death_particles` (12 vs 24 particles), parented to the room (not
## the boss) so the burst persists past slam-recovery + boss death.
##
## Physics-flush safety: see `_spawn_death_particles` for the full rationale —
## `_fire_slam_hit` runs during the physics step's slam-telegraph countdown
## path, and a direct `add_child` from that callstack risks Godot 4's
## "Can't change this state while flushing queries" panic if any Area2D state
## downstream of the new particle node mutates. Deferred add_child sidesteps
## the class entirely. Mirror of the death-burst pattern.
func _spawn_slam_aftershock() -> void:
	var room: Node = get_parent()
	if room == null:
		return
	var burst: CPUParticles2D = CPUParticles2D.new()
	burst.global_position = global_position
	burst.amount = SLAM_AFTERSHOCK_PARTICLE_COUNT
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.lifetime = SLAM_AFTERSHOCK_LIFETIME
	burst.emitting = true
	# Omni-radial: direction=UP + spread=180 → uniform 360° emission. Same
	# shape as the death burst.
	burst.direction = Vector2.UP
	burst.spread = SLAM_AFTERSHOCK_SPREAD
	burst.initial_velocity_min = SLAM_AFTERSHOCK_VELOCITY_MIN
	burst.initial_velocity_max = SLAM_AFTERSHOCK_VELOCITY_MAX
	# Impact-flash ramp (v5 visibility fix): start near-white-hot then fade through
	# ember-light to ember-deep. The white-hot start gives a high-contrast "impact"
	# frame against the boss's red armor — pure ember-only ramp washed out against
	# the boss sprite in v3 (screenshot evidence: PR #291 v5 self-soak). Three-stop
	# Gradient: 0.0=flash, 0.25=ember-light, 1.0=ember-deep so the flash decays
	# within the first ~85 ms of the 350 ms lifetime.
	# Gradient.new() starts with 2 default points at offsets 0.0 and 1.0;
	# set_color writes them, add_point inserts a third in the middle.
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, AFTERSHOCK_FLASH_WHITE)
	ramp.set_color(1, EMBER_DEEP)
	ramp.add_point(0.25, EMBER_LIGHT)
	burst.color_ramp = ramp
	# T6 visibility-fix (Sponsor soak 2026-05-21 — "see no aftershock"): rise +
	# z_index +1 so the burst climbs above the boss sprite during its short
	# lifetime instead of staying behind it. Mirrors `SlamTelegraphIndicator`
	# z_index=1 (see html5-export.md § Z-index sensitivity) and the death-burst
	# rising-gravity pattern below.
	burst.gravity = SLAM_AFTERSHOCK_GRAVITY
	burst.z_index = SLAM_AFTERSHOCK_Z_INDEX
	burst.scale_amount_min = SLAM_AFTERSHOCK_SCALE
	burst.scale_amount_max = SLAM_AFTERSHOCK_SCALE
	# Physics-flush safety: `_fire_slam_hit` runs in the slam-telegraph countdown
	# path inside `_physics_process`. Deferred add_child avoids the 4.x panic
	# class — same rationale as `_spawn_death_particles`.
	room.call_deferred("add_child", burst)
	burst.finished.connect(burst.queue_free)
	# Diagnostic trace (T6 visibility hunt — Sponsor soak 2026-05-21). Captures
	# parent-path + z-index + scale alongside the existing particle/lifetime/
	# velocity/origin fields so a future "still invisible" report can rule out
	# scene-tree-parent / z-order / scale regressions without re-instrumenting.
	# Per `diagnostic-traces-before-hypothesized-fixes` — these stay in the code
	# permanently so the next regression diagnoses itself.
	_combat_trace("Stratum1Boss._spawn_slam_aftershock",
		("particles=%d lifetime=%.2f vel=[%.0f..%.0f] gravity=(%.0f,%.0f) " +
		 "scale=%.2f z_index=%d origin=(%.0f,%.0f) parent_path=%s") % [
			SLAM_AFTERSHOCK_PARTICLE_COUNT, SLAM_AFTERSHOCK_LIFETIME,
			SLAM_AFTERSHOCK_VELOCITY_MIN, SLAM_AFTERSHOCK_VELOCITY_MAX,
			SLAM_AFTERSHOCK_GRAVITY.x, SLAM_AFTERSHOCK_GRAVITY.y,
			SLAM_AFTERSHOCK_SCALE, SLAM_AFTERSHOCK_Z_INDEX,
			global_position.x, global_position.y,
			String(room.get_path()) if room.is_inside_tree() else "<not-in-tree>"])


## §2 hit-flash. M3W-4 3-branch resolver per `.claude/docs/combat-architecture.md`
## § "M3W-1 realized implementation" — production boss is now AnimatedSprite2D,
## ColorRect path retained for back-compat with bare-instanced tests, modulate
## fallback for sprite-less test edges. Mirrors `Grunt._play_hit_flash` /
## `PracticeDummy._play_hit_flash` verbatim modulo the `Stratum1Boss.` tag.
func _play_hit_flash() -> void:
	if _is_dead:
		return
	if _hit_flash_target == null:
		var sprite: Node = get_node_or_null("Sprite")
		if sprite is AnimatedSprite2D:
			# M3W-4 path — production sprite is an AnimatedSprite2D.
			_hit_flash_target = sprite
			_hit_flash_uses_sprite = true
			_hit_flash_uses_animated_sprite = true
			_sprite_modulate_at_rest = (sprite as AnimatedSprite2D).modulate
		elif sprite is ColorRect:
			# Pre-M3W-4 fallback (legacy bare-instanced test edge).
			_hit_flash_target = sprite
			_hit_flash_uses_sprite = true
			_hit_flash_uses_animated_sprite = false
			_sprite_color_at_rest = (sprite as ColorRect).color
		else:
			# Bare-instanced test boss (no Sprite child).
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
		_combat_trace("Stratum1Boss._play_hit_flash",
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
		_combat_trace("Stratum1Boss._play_hit_flash",
			"sprite tween_valid=%s rest=(%.2f,%.2f,%.2f) target=white" %
			[_hit_flash_tween.is_valid(), _sprite_color_at_rest.r, _sprite_color_at_rest.g, _sprite_color_at_rest.b])
	else:
		# Branch 3: self.modulate fallback (bare-instanced tests).
		_hit_flash_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), HIT_FLASH_IN)
		_hit_flash_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), HIT_FLASH_HOLD)
		_hit_flash_tween.tween_property(self, "modulate", _modulate_at_rest, HIT_FLASH_OUT)
		_combat_trace("Stratum1Boss._play_hit_flash",
			"modulate-fallback tween_valid=%s rest=(%.2f,%.2f,%.2f)" %
			[_hit_flash_tween.is_valid(), _modulate_at_rest.r, _modulate_at_rest.g, _modulate_at_rest.b])


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


# ---- M3W-7 audio-cue wiring -------------------------------------------

## Connect existing combat signals to AudioDirector SFX plays.
##   damaged(amount>0)            → SFX_MOB_HIT
##   boss_died                    → SFX_BOSS_DIE (heavier than mob-die)
##   swing_spawned                → SFX_ATTACK_TELEGRAPH for slam_telegraph,
##                                   SFX_ATTACK_IMPACT for melee + slam_hit
##                                   (branches on `kind` per swing_spawned
##                                   contract — telegraph vs impact map cleanly)
##
## M3-T2-W1-T7 additions (ClickUp 86c9wjyak):
##   boss_woke                    → SFX_BOSS_WAKE   (Uma BI-06 — Beat 3 stinger)
##   phase_changed                → SFX_PHASE_BREAK (Uma BI-18 — tritone sting)
##
## The `phase_changed` signal already has an idempotent latch in the controller
## (`_check_phase_boundaries`) — it emits exactly once per HP boundary even
## under hit-spam — so the sting naturally fires once per boundary without
## audio-side dedupe. Same for `boss_woke`: the boss starts in STATE_DORMANT
## and `wake()` is guarded by the `STATE_DORMANT` state-check (idempotent).
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


func _on_boss_died_audio(_mob: Stratum1Boss, _pos: Vector2, _def: MobDef) -> void:
	var ad: Node = _resolve_audio_director()
	if ad == null or not ad.has_method("play_sfx"):
		return
	ad.play_sfx(&"sfx-boss-die")


func _on_swing_spawned_audio(kind: StringName, _hitbox: Node) -> void:
	var ad: Node = _resolve_audio_director()
	if ad == null or not ad.has_method("play_sfx"):
		return
	# Boss swing_spawned fires with three kinds — split by semantic:
	#   melee + slam_hit → impact-shaped cue (contact beat).
	#   slam_telegraph   → telegraph-shaped cue (windup marker spawn).
	# The constants are defined elsewhere in this file (SWING_KIND_MELEE,
	# SWING_KIND_SLAM_TELEGRAPH, SWING_KIND_SLAM_HIT).
	if kind == SWING_KIND_SLAM_TELEGRAPH:
		ad.play_sfx(&"sfx-attack-telegraph")
	else:
		ad.play_sfx(&"sfx-attack-impact")


## M3-T2-W1-T7 — Uma `boss-intro.md` BI-06 (boss-wake stinger).
## Fires once on boss wake (STATE_DORMANT → STATE_IDLE transition).
func _on_boss_woke_audio() -> void:
	var ad: Node = _resolve_audio_director()
	if ad == null or not ad.has_method("play_sfx"):
		return
	ad.play_sfx(&"sfx-boss-wake")


## M3-T2-W1-T7 — Uma `boss-intro.md` BI-18 (phase-break tritone sting).
## The signal already has an idempotent latch in `_check_phase_boundaries`
## so this handler is called exactly once per HP boundary (66% / 33%),
## even under hit-spam.
func _on_phase_changed_audio(_new_phase: int) -> void:
	var ad: Node = _resolve_audio_director()
	if ad == null or not ad.has_method("play_sfx"):
		return
	ad.play_sfx(&"sfx-phase-break")


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
	# M3W-4 animation playback — map state → SpriteFrames anim key. `hit_<dir>`
	# and `die_<dir>` are driven directly from `take_damage` / `_die` (one-shot
	# beats that interrupt the state-anim); the state-driven mapping covers
	# walk/atk/atk_telegraph/slam/slam_telegraph. STATE_DEAD has no entry — `_die`
	# plays `die_<dir>` explicitly. STATE_DORMANT and STATE_PHASE_TRANSITION are
	# also no-op here — boss anim is frozen in those states (dormant uses the
	# .tscn-assigned default `walk_s` frame-0; phase transition holds whatever
	# anim was last playing as the 0.6 s damage-immune window expires).
	match new_state:
		STATE_IDLE, STATE_CHASING:
			_play_anim(&"walk")
		STATE_TELEGRAPHING_MELEE:
			_play_anim(&"atk_telegraph")
		STATE_ATTACKING:
			_play_anim(&"atk")
		STATE_TELEGRAPHING_SLAM:
			_play_anim(&"slam_telegraph")
		STATE_SLAM_RECOVERY:
			_play_anim(&"slam")
	state_changed.emit(old, new_state)


# ---- Animation playback (M3W-4) --------------------------------------

## Play an animation on the AnimatedSprite2D child. Resolves the child lazily
## on first call so bare-instanced test bosses (no Sprite child or ColorRect
## fallback) no-op safely. `state` is the state-key prefix (`walk`, `atk`,
## `atk_telegraph`, `slam`, `slam_telegraph`, `hit`, `die`); the full SpriteFrames
## key is `<state>_<dir>` where `<dir>` is derived from the boss's intent —
## direction toward the player when known, "s" otherwise.
##
## M3W-4 convention — mirrors `Grunt._play_anim` / `Shooter._play_anim` /
## `Charger._play_anim` from M3W-3 with a non-trivial `<dir>` resolver. Boss
## always faces the player when one exists (it chases the player), so the
## chase / swing / die animations all read in the right direction. If no
## player is bound (bare-instanced tests), defaults to "s".
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
		_combat_trace("Stratum1Boss._play_anim",
			"MISS anim=%s — SpriteFrames lacks this animation key" % anim_name)
		return
	# Only restart if a different anim is queued — re-issuing the same anim
	# on every physics tick (chase loop hits _set_state(CHASING) every tick)
	# would visibly stutter at frame 0. AnimatedSprite2D.play() is idempotent
	# on the SAME animation name, but we still want the `_play_anim` trace to
	# surface only on actual transitions.
	if _animated_sprite.animation == anim_name and _animated_sprite.is_playing():
		return
	_animated_sprite.play(anim_name)
	_combat_trace("Stratum1Boss._play_anim", "PLAY anim=%s" % anim_name)


## Derive the 8-octant direction suffix for the SpriteFrames anim key. Uses
## the vector toward the player when a player ref exists; falls back to "s"
## otherwise. Matches the at-swing-time direction resolution already used in
## `_fire_melee_swing` (which re-resolves toward the player at fire time), so
## the played anim is always aimed where the swing is going.
func _compute_facing_dir_suffix() -> String:
	if _player == null or not is_inside_tree():
		return "s"
	var to_player: Vector2 = _player.global_position - global_position
	if to_player.length_squared() <= 0.0001:
		return "s"
	return _vec_to_dir_suffix(to_player)


## Convert a Vector2 to its nearest 8-octant compass-direction suffix.
## Uses atan2 with a 22.5° (π/8) half-width per octant. Quadrant boundary
## convention: matches `Grunt._vec_to_dir_suffix` (PR #275, M3W-3 baseline)
## so every M3 mob shares one facing-derivation contract.
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


func _apply_mob_def() -> void:
	# Boss HP multiplier (Sponsor 2026-05-21 soak-iteration utility). Resolves
	# to 1.0 (no-op) outside HTML5 and when the `boss_hp_mult` URL param is
	# absent. Multiplied IN even on the bare-instance fallback path so headless
	# GUT tests using `DebugFlags.set_boss_hp_mult_for_test(0.5)` can exercise
	# the nerf without supplying a MobDef.
	var hp_mult: float = _resolve_boss_hp_mult()
	if mob_def == null:
		# Bare-instantiated boss (tests). Use spec defaults — 600 HP, 12 dmg
		# (rebalanced M1 RC soak-4, was 15), 80 px/s.
		# Phase-2 and phase-3 thresholds resolve to 396 and 198.
		var bare_hp: int = max(1, int(round(600.0 * hp_mult)))
		hp_max = bare_hp
		hp_current = bare_hp
		damage_base = 12
		move_speed_base = 80.0
		move_speed = move_speed_base
		return
	var scaled_hp: int = max(1, int(round(float(mob_def.hp_base) * hp_mult)))
	hp_max = scaled_hp
	hp_current = scaled_hp
	damage_base = mob_def.damage_base
	move_speed_base = mob_def.move_speed
	move_speed = move_speed_base


## Resolve the boss HP multiplier from the DebugFlags autoload (defaults to 1.0
## when the autoload is missing — bare-instance unit-test edge). Centralised so
## both branches of `_apply_mob_def` share the same gate + the multiplier value
## is testable without re-instantiating the boss.
func _resolve_boss_hp_mult() -> float:
	if not is_inside_tree():
		# Bare unit-test edge: instantiate-then-set-fields without scene tree.
		# Use the autoload via `Engine.get_main_loop()` so we still get the test
		# injection value if the test wrote one before adding the boss.
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
