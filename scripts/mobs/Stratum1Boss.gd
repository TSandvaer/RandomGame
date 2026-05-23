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
const STATE_WAKING: StringName = &"waking"              # mid-wake-anim (damage-immune)
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

## M3-T2-W1-T8 wake-anim duration (ticket 86c9wjyp9). Five PixelLab frames at
## SpriteFrames speed=12 fps = ~417 ms total. Uma BI-06 targeted ~500 ms for the
## boss-wake animation timing — 417 ms lands inside that band. During this
## window the boss is damage-immune (extends the DORMANT intro-fairness rule
## through the wake animation tail so the player can't kill the boss before it
## has stood up). `boss_woke.emit()` still fires at the START of WAKING (Beat 3
## audio stinger lands immediately on wake entry — matches BI-06).
const WAKE_DURATION: float = 0.417

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
const DEATH_TARGET_SCALE: float = 0.6
const BOSS_DEATH_HOLD: float = 0.400
const BOSS_SHAKE_MAGNITUDE: float = 4.0   # logical px (VD-09 max budget)
const BOSS_SHAKE_DURATION: float = 0.150
const EMBER_LIGHT: Color = Color(1.0, 0.690, 0.400, 1.0)   # #FFB066
const EMBER_DEEP: Color = Color(0.627, 0.180, 0.031, 1.0)  # #A02E08

## T16 climax burst — sustained 0.9 s ember-rise emitter that replaces the
## pre-T16 single-explosive 24-particle burst. Wave 3 cinematic-climax beat
## per Uma `boss-intro.md` F2 + Priya `w3-dispatch-plan.md` §3 Brief 4.
##
## **Why sustained, not explosive.** The pre-T16 shape was a one-frame
## explosive pop (`explosiveness = 1.0`) that landed in the same physics
## frame as `boss_died.emit` — perceptually a "flash + done" beat. The F2
## design intent is "embers rising for the duration of the camera ease-in"
## — the emitter sustains across the full 0.9 s window so the ember plume
## is co-present with the camera zoom + vignette deepen, NOT a single
## frame at the start of it.
##
## **Window math.** `one_shot = true, explosiveness = 0.1, lifetime = 0.9`
## spawns `amount` particles linearly across `(1 - explosiveness) × lifetime`
## = 0.81 s of active emission, each living `lifetime` = 0.9 s. The last-
## emitted particle is born at t≈0.81 and dies at t≈1.71. The PERCEIVED
## "sustained rise" matches the 0.9 s emission window the brief calls for;
## the trailing decay overlaps the BossDefeatedTitleCard's 1.2 s pre-fade
## interval and dissipates well before the card fades in.
##
## **Why 56 particles + 2.5 scale (vs PR #291 T6 aftershock's 56/2.5).**
## Same intensity reference as the v7 slam-aftershock — empirically the
## "unmissable" floor against the boss sprite's red surcoat. The brief
## "brighter + faster + more particles than the player-death-flow dissolve"
## maps to: more particles (56 vs Grunt's 12), brighter ramp (impact-frame
## white at ramp[0] vs Grunt's EMBER_LIGHT→EMBER_DEEP linear), faster
## initial velocity (220 px/s vs Grunt's 30-60).
##
## **Impact frame at ramp[0].** Per `.claude/docs/html5-export.md` §
## "Burst contrast against high-hue-saturation same-z sprites" (PR #291 v5
## finding): ember-orange ramp stops blend perceptually into the boss's
## red surcoat under WebGL2 compositing. A near-white IMPACT frame at
## ramp[0] breaks the perceptual blend and gives the burst a perceptually-
## distinct opening flash.
##
## **z_index = +1.** Per `.claude/docs/html5-export.md` § "Z-index
## sensitivity" + PR #291 T6 same-z-occlusion finding: a same-z-as-sprite
## CPUParticles2D burst may render BEHIND the emitting sprite under
## `gl_compatibility`. Explicit +1 lifts the burst above the boss sprite
## (which sits at z = 0 in the room).
const CLIMAX_BURST_PARTICLE_COUNT: int = 56
const CLIMAX_BURST_LIFETIME: float = 0.9
## Mostly-sustained emission. 0.0 would be purely linear over the window;
## 0.1 keeps the very first frame slightly weighted so the burst "starts"
## visibly rather than dripping in.
const CLIMAX_BURST_EXPLOSIVENESS: float = 0.1
const CLIMAX_BURST_SCALE_MIN: float = 2.0
const CLIMAX_BURST_SCALE_MAX: float = 2.5
const CLIMAX_BURST_VELOCITY_MIN: float = 80.0
const CLIMAX_BURST_VELOCITY_MAX: float = 220.0
## Upward gravity stronger than Grunt's `Vector2(0, -40)` — embers rise
## quickly so the plume clears the boss's collapsing sprite by ~t=0.3 s.
const CLIMAX_BURST_GRAVITY_Y: float = -120.0
## Spread (degrees) of the emission cone around the `direction` vector.
## 90° = quarter-circle upward fan. Narrower than Grunt's 180° hemisphere
## because the cinematic intent is "rising plume" not "exploding sphere".
const CLIMAX_BURST_SPREAD_DEG: float = 90.0
## z_index: lift above sprite default 0 to avoid same-z occlusion on
## gl_compatibility. PR #291 T6 precedent.
const CLIMAX_BURST_Z_INDEX: int = 1
## Impact frame at ramp[0] — perceptually-distinct near-white that breaks
## the orange-on-red blend per `.claude/docs/html5-export.md` § burst-contrast.
## Sub-1.0 every channel for HDR-clamp safety; high luminance + warm tint
## to read as "ember flash" not "white pop".
const CLIMAX_BURST_IMPACT_FLASH: Color = Color(1.0, 0.949, 0.749, 1.0)  # #FFF2BF

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
var _wake_left: float = 0.0  # M3-T2-W1-T8: wake-anim countdown

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

# v7 slam-impact sprite-flash tween (PR #291 v7) — ref kept so a second slam
# arriving before the previous flash completes can kill+restart without
# leaving the sprite stuck mid-flash. Independent from `_hit_flash_tween`
# (which is take_damage-driven and may run simultaneously on a slam-self-hit).
var _slam_impact_flash_tween: Tween = null

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

## T6 slam aftershock burst — v7 "make it unmissable" intensity stack (PR #291,
## Sponsor 2026-05-21 v6 soak: "cannot see the sparkles you captured in your
## Playwright headless screenshots"). The v5/v6 ramp + 24 particles + 1.5 scale
## was demonstrably present in Playwright captures but perceptually invisible
## in real-browser motion — Playwright headless captures perception-subliminal
## frames that the human eye never resolves AND/OR CPUParticles2D rendering
## under `gl_compatibility` real-browser differs from headless. Documented as a
## new HTML5 divergence class in `.claude/docs/html5-export.md` (Playwright
## headless vs interactive divergence).
##
## v7 intensity stack — five changes layered to push the burst over the
## perceptibility threshold even at the periphery of vision:
##   1. Particle count 24 → 56 — more area of perceptual signal.
##   2. Initial scale 1.5 → 2.5 — bigger embers read more clearly.
##   3. Initial velocity 40-80 → 80-140 — particles escape boss-sprite
##      occlusion faster, reach screen-areas not under sprite.
##   4. Rising gravity -50 → -100 — steeper rise, clears sprite-top within
##      the first 100 ms of the 350 ms lifetime.
##   5. Ramp[0] flat hold + pure-white impact color — ramp dwells at
##      `AFTERSHOCK_FLASH_WHITE` (now pure #FFFFFF, not the warm-cream
##      #FFF2BF that blended into the boss's red hue family) for the first
##      ~30% of lifetime (~100 ms), then transitions to ember at 0.40.
##      The flat hold is the load-bearing perceptual fix — instant decay at
##      t=0 meant the bright frame never persisted long enough to register.
## Plus: brief sprite-modulate flash on the boss itself at slam-impact
## (`_play_slam_impact_flash`), giving the impact a "shake-and-flash" feel
## that's unmistakable even without seeing the particles clearly.
##
## v5/v6 history (kept for trace continuity): 12 → 24 particles + ember-only
## → ember+impact-flash ramp + lifetime 0.20 → 0.35 + rising gravity. All
## those changes were correct in direction but insufficient in magnitude.
const SLAM_AFTERSHOCK_PARTICLE_COUNT: int = 56
## Lifetime stays at 350 ms — v5 screenshot capture confirmed duration is
## sufficient, the visibility problem was magnitude not duration. Bumping
## further would risk reading as a separate effect from the slam impact.
const SLAM_AFTERSHOCK_LIFETIME: float = 0.35
## Impact-flash color for the aftershock ramp[0]. v7 BUMPED to pure white
## (#FFFFFF) from v5's warm-cream #FFF2BF — Sponsor's real-browser report
## "cannot see the sparkles" with a warm-cream start against red armor is the
## hue-family-blend failure mode. Pure white is maximally outside the boss's
## red/orange hue cone; the contrast jump on the impact frame is what makes
## the burst read at peripheral vision. All channels = 1.0 — exactly at the
## HDR clamp boundary (HTML5 `gl_compatibility` clamps to [0,1]; pure white
## is the boundary, not over it). See `.claude/docs/html5-export.md` § HDR
## modulate clamp.
const AFTERSHOCK_FLASH_WHITE: Color = Color(1.0, 1.0, 1.0, 1.0)  # #FFFFFF
## v7: ramp[0] flat-hold duration as a fraction of lifetime. The bright
## impact color dwells at this offset before transitioning to ember. 0.30 ×
## 350 ms = 105 ms — long enough for human vision to resolve (well above
## the ~16 ms flicker-fusion threshold). v5/v6 had instant decay (offset
## 0.0 only at the bright color) which meant only the t=0 frame was bright.
const AFTERSHOCK_FLASH_HOLD_OFFSET: float = 0.30
## v7: offset at which the ramp transitions from impact-flash to ember-light.
## The 0.30 → 0.40 segment is the "decay" zone — quick transition so the
## flash decays cleanly, then ember tail to lifetime end.
const AFTERSHOCK_FLASH_DECAY_OFFSET: float = 0.40
## Outward velocity range (px/s) — v7 BUMPED from 40-80 → 80-140. Faster
## initial velocity ensures particles escape the boss sprite's occlusion
## footprint (~32 px radius) within the first ~50 ms, reaching screen-areas
## not covered by the boss body where contrast against the dark floor is
## maximal.
const SLAM_AFTERSHOCK_VELOCITY_MIN: float = 80.0
const SLAM_AFTERSHOCK_VELOCITY_MAX: float = 140.0
## Spread is half-angle around `direction`. 180° + direction=UP gives uniform
## omni-radial emission — mirrors death burst.
const SLAM_AFTERSHOCK_SPREAD: float = 180.0
## Rising gravity — v7 BUMPED from -50 → -100 px/s². Steeper rise so particles
## clear the boss sprite top (~24 px above origin) within the first ~100 ms
## of the 350 ms lifetime, putting the ember tail above the sprite where it
## reads against the dark room background instead of the red armor.
const SLAM_AFTERSHOCK_GRAVITY: Vector2 = Vector2(0.0, -100.0)
## Particle scale — v7 BUMPED from 1.5 → 2.5. Bigger ember footprint gives
## each particle more screen-area of perceptual signal, which is the
## load-bearing fix-shape for the Playwright-vs-interactive divergence:
## headless captures resolve sub-pixel detail the eye in motion does not.
const SLAM_AFTERSHOCK_SCALE: float = 2.5
## z_index +1 lifts the burst draw-layer above the boss AnimatedSprite2D
## (sprite z_index=0). Per `.claude/docs/html5-export.md` § "Z-index
## sensitivity" — never rely on negative z_index in `gl_compatibility`; this
## positive lift ensures the burst draws over the boss body sprite.
const SLAM_AFTERSHOCK_Z_INDEX: int = 1

# ---- v7 slam-impact sprite flash (ticket 86c9wjyuv, PR #291 v7) ------
# Brief modulate flash on the boss sprite at slam-fire moment. The particle
# burst is the primary visual tell; this flash is a secondary "shake-and-
# flash" cue that triggers peripheral-vision motion-detection even if the
# player isn't looking directly at the boss. Two-tween fire-and-restore:
# tween rest → SLAM_IMPACT_FLASH_TINT (50 ms) → rest (80 ms). Total budget
# 130 ms is well under the 200 ms SLAM_RECOVERY window so the flash always
# completes before the next state transition.
##
## Pure-white at α=1.0 with a slight blue accent (g=b=1.0, r=0.95) to break
## out of the boss's red hue family — same rationale as the particle
## AFTERSHOCK_FLASH_WHITE bump. Sub-1.0 R channel keeps the value strictly
## below the HDR clamp; G+B at 1.0 are exactly at the clamp boundary which
## `gl_compatibility` handles cleanly. Mirrors `Player.SWING_FLASH_TINT`'s
## "all channels ≤ 1.0" discipline from `html5-export.md`.
const SLAM_IMPACT_FLASH_TINT: Color = Color(1.0, 1.0, 1.0, 1.0)  # pure white pulse
const SLAM_IMPACT_FLASH_IN: float = 0.030
const SLAM_IMPACT_FLASH_HOLD: float = 0.020
const SLAM_IMPACT_FLASH_OUT: float = 0.080


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


## M3-T2-W1-T8: True during the ~417 ms wake-anim window (damage immune; the
## boss is standing up but cannot yet act or be hit). Exposed for tests +
## external observers (e.g. cinematic camera that should hold focus through
## the wake animation, not just the dormant pre-wake window).
func is_waking() -> bool:
	return _state == STATE_WAKING


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


## Test-only: fast-forward through the ~417 ms WAKE_DURATION window without
## requiring physics-tick simulation. After this call the boss is in
## STATE_IDLE (combat-ready, damage-eligible). Production never calls this —
## production drains `_wake_left` via `_process_waking` on real physics ticks.
##
## Use this in GUT tests that need to skip past the wake animation to test
## downstream combat behavior (damage-eligibility, chase-loop, AI dispatch).
## The test-only `Stratum1BossRoom.complete_entry_sequence_for_test()` chains
## into this so existing room-based integration tests continue to land in
## STATE_IDLE without per-test changes.
func complete_wake_for_test() -> void:
	if _state != STATE_WAKING:
		return
	_wake_left = 0.0
	_set_state(STATE_IDLE)


## Wake the boss — called by `BossRoomTrigger` after the 1.8 s entry
## sequence completes. Transitions DORMANT → WAKING (plays the standup
## animation + remains damage-immune) and then auto-advances to IDLE after
## `WAKE_DURATION` (~417 ms) via `_process_waking`. Idempotent — calling
## twice has no extra effect.
##
## `boss_woke.emit()` fires at the START of WAKING so the BI-06 audio stinger
## (Uma boss-intro brief, Beat 3) lands on wake entry, NOT at the end of the
## wake animation. This matches the audio-direction.md cue contract.
func wake() -> void:
	if _state != STATE_DORMANT:
		return
	# [combat-trace] diagnostic (ticket 86c9ujq8d — finding 1, extended T8):
	# confirms the boss successfully exited DORMANT into the wake-anim window.
	# If this line never appears in the soak stream, the entry sequence timer
	# did not fire — look for `trigger_entry_sequence` call (auto-fire in
	# `_assemble_room_fixtures`) and the SceneTreeTimer creation path.
	_combat_trace("Stratum1Boss.wake",
		"exiting STATE_DORMANT -> STATE_WAKING (damage-immune wake-anim window, %.3fs)" % WAKE_DURATION)
	_wake_left = WAKE_DURATION
	_set_state(STATE_WAKING)
	boss_woke.emit()


## Take damage. Duck-typed contract matched by `Hitbox.gd`.
##
##   - Damage during STATE_DEAD is ignored.
##   - Damage during STATE_DORMANT is ignored (intro fairness protection).
##   - Damage during STATE_WAKING is ignored (M3-T2-W1-T8: wake-anim window
##     extends intro fairness through the boss's standup animation).
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
	if _state == STATE_WAKING:
		# M3-T2-W1-T8 (ticket 86c9wjyp9): extends the intro-fairness rule through
		# the wake animation. The boss has exited DORMANT but is still standing
		# up — combat shouldn't start landing damage until the wake-anim window
		# closes (~417 ms after `wake()`). Mirrors the DORMANT trace shape so a
		# soak diagnostician can discriminate "wake-window rejection" from
		# "dormant rejection" by a single trace-line read.
		_combat_trace("Stratum1Boss.take_damage",
			"IGNORED waking amount=%d hp=%d wake_left=%.3f (wake-anim window)"
				% [amount, hp_current, _wake_left])
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

	# Wake-anim window (M3-T2-W1-T8). Rooted, damage-immune, plays `wake_<dir>`
	# once. When `_wake_left` drains we hand off to STATE_IDLE — `_process_chase`
	# picks up on the next tick if a player is present.
	if _state == STATE_WAKING:
		velocity = Vector2.ZERO
		if _wake_left <= 0.0:
			_combat_trace("Stratum1Boss._process_waking",
				"wake-anim complete -> STATE_IDLE (damage-immunity ends)")
			_set_state(STATE_IDLE)
		move_and_slide()
		return

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
		var push_dir: Vector2 = away.normalized() if away.length_squared() > 0.0 else -dir
		velocity = push_dir * POST_CONTACT_PUSHBACK_SPEED
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
	# T6 (ticket 86c9wjyuv): aftershock ember-burst at slam origin. v7 scales
	# up to 56 particles + impact-flash ramp w/ flat hold + faster outward
	# velocity — see SLAM_AFTERSHOCK_* constants for the v7 intensity stack
	# rationale (Sponsor "cannot see sparkles" 2026-05-21 v6 soak).
	# Parented to the room (not the boss) so the burst persists past
	# slam-recovery if the boss subsequently dies and queue_frees itself.
	_spawn_slam_aftershock()
	# v7: brief pure-white sprite-modulate flash on the boss itself, paired
	# with the particle burst. Gives a "shake-and-flash" peripheral-vision
	# tell that's unmistakable even when the player isn't looking at the boss.
	# Runs in parallel with `_spawn_slam_aftershock`'s burst — combined effect
	# is the v7 "unmissable" target.
	_play_slam_impact_flash()
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
	_combat_trace(
		"Stratum1Boss._die",
		"starting death sequence at hp=%d phase=%d" % [hp_current, phase])
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
	_attack_telegraph_tween.tween_property(
		target, prop, ATTACK_TELEGRAPH_TINT, ATTACK_TELEGRAPH_TWEEN_IN)
	_attack_telegraph_tween.tween_property(target, prop, ATTACK_TELEGRAPH_TINT, hold_dur)
	_attack_telegraph_tween.tween_property(
		target, prop, color_at_rest, ATTACK_TELEGRAPH_TWEEN_IN)
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
	# v7 impact-flash ramp with FLAT HOLD on the bright color (PR #291 v7,
	# Sponsor "cannot see sparkles" report 2026-05-21). Four-stop Gradient:
	#   offset 0.00 = AFTERSHOCK_FLASH_WHITE (pure white)
	#   offset 0.30 = AFTERSHOCK_FLASH_WHITE (FLAT HOLD — load-bearing fix)
	#   offset 0.40 = EMBER_LIGHT (decay through warm orange)
	#   offset 1.00 = EMBER_DEEP (ember tail)
	# The flat hold at 0.0→0.30 means the bright frame dwells for ~105 ms
	# (30% of 350 ms lifetime) instead of decaying instantly at t=0 like the
	# v5/v6 ramp. This is the load-bearing perceptual fix — human vision needs
	# ≥~50 ms of sustained signal to register a transient at peripheral focus,
	# and v5's instant-decay impact-flash was sub-threshold despite being
	# captured perfectly by Playwright's headless frame-sampling.
	#
	# Gradient.new() starts with 2 default points at offsets 0.0 and 1.0;
	# set_color writes them, add_point inserts intermediates.
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, AFTERSHOCK_FLASH_WHITE)
	ramp.set_color(1, EMBER_DEEP)
	ramp.add_point(AFTERSHOCK_FLASH_HOLD_OFFSET, AFTERSHOCK_FLASH_WHITE)
	ramp.add_point(AFTERSHOCK_FLASH_DECAY_OFFSET, EMBER_LIGHT)
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
		 "scale=%.2f z_index=%d origin=(%.0f,%.0f) " +
		 "ramp_hold=[0..%.2f]=white decay=%.2f parent_path=%s") % [
			SLAM_AFTERSHOCK_PARTICLE_COUNT, SLAM_AFTERSHOCK_LIFETIME,
			SLAM_AFTERSHOCK_VELOCITY_MIN, SLAM_AFTERSHOCK_VELOCITY_MAX,
			SLAM_AFTERSHOCK_GRAVITY.x, SLAM_AFTERSHOCK_GRAVITY.y,
			SLAM_AFTERSHOCK_SCALE, SLAM_AFTERSHOCK_Z_INDEX,
			global_position.x, global_position.y,
			AFTERSHOCK_FLASH_HOLD_OFFSET, AFTERSHOCK_FLASH_DECAY_OFFSET,
			String(room.get_path()) if room.is_inside_tree() else "<not-in-tree>"])


## v7 slam-impact sprite flash (PR #291 v7, ticket 86c9wjyuv) — secondary
## visual cue for the slam impact that complements the particle aftershock.
## Brief pure-white modulate flash on the boss's AnimatedSprite2D for the
## ~130 ms IN+HOLD+OUT budget, then restores the sprite's rest modulate.
## Runs in PARALLEL with the particle burst — together they give a
## "shake-and-flash" tell that triggers peripheral-vision motion-detection
## even when the player isn't looking directly at the boss.
##
## Distinct from `_play_hit_flash`:
##   - `_play_hit_flash` is take_damage-driven (boss took a hit, soft-red
##     tint, mirrors Grunt/PracticeDummy hit-flash convention).
##   - `_play_slam_impact_flash` is slam-fire-driven (boss DEALT a hit,
##     pure-white pulse, mirrors PR #137 Player.SWING_FLASH discipline).
## They use separate tween refs so a slam-self-hit (boss damaged by player
## counter while boss is mid-slam) doesn't have one tween cancelling the
## other mid-flash.
##
## 3-branch sprite resolver mirrors `_play_hit_flash` — branches discriminated
## by the same `_hit_flash_target` resolution. This means the resolver runs
## once across both flash types (whichever fires first wires the target).
func _play_slam_impact_flash() -> void:
	if _is_dead:
		return
	# Resolve the flash target (idempotent — `_play_hit_flash` uses the same
	# branch resolution, so we share the cached _hit_flash_target ref).
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
	if _slam_impact_flash_tween != null and _slam_impact_flash_tween.is_valid():
		_slam_impact_flash_tween.kill()
	if not is_inside_tree():
		return
	_slam_impact_flash_tween = create_tween()
	if _hit_flash_uses_animated_sprite:
		var asprite: AnimatedSprite2D = _hit_flash_target as AnimatedSprite2D
		_slam_impact_flash_tween.tween_property(
			asprite, "modulate", SLAM_IMPACT_FLASH_TINT, SLAM_IMPACT_FLASH_IN)
		_slam_impact_flash_tween.tween_property(
			asprite, "modulate", SLAM_IMPACT_FLASH_TINT, SLAM_IMPACT_FLASH_HOLD)
		_slam_impact_flash_tween.tween_property(
			asprite, "modulate", _sprite_modulate_at_rest, SLAM_IMPACT_FLASH_OUT)
	elif _hit_flash_uses_sprite:
		var sprite_rect: ColorRect = _hit_flash_target as ColorRect
		_slam_impact_flash_tween.tween_property(
			sprite_rect, "color", SLAM_IMPACT_FLASH_TINT, SLAM_IMPACT_FLASH_IN)
		_slam_impact_flash_tween.tween_property(
			sprite_rect, "color", SLAM_IMPACT_FLASH_TINT, SLAM_IMPACT_FLASH_HOLD)
		_slam_impact_flash_tween.tween_property(
			sprite_rect, "color", _sprite_color_at_rest, SLAM_IMPACT_FLASH_OUT)
	else:
		_slam_impact_flash_tween.tween_property(
			self, "modulate", SLAM_IMPACT_FLASH_TINT, SLAM_IMPACT_FLASH_IN)
		_slam_impact_flash_tween.tween_property(
			self, "modulate", SLAM_IMPACT_FLASH_TINT, SLAM_IMPACT_FLASH_HOLD)
		_slam_impact_flash_tween.tween_property(
			self, "modulate", _modulate_at_rest, SLAM_IMPACT_FLASH_OUT)
	# Diagnostic trace — distinct tag from _play_hit_flash so the trace stream
	# can discriminate "boss got hit" (hit_flash) vs "boss dealt slam" (slam_impact_flash).
	var _branch_tag: String = "self_modulate"
	if _hit_flash_uses_animated_sprite:
		_branch_tag = "animated_sprite"
	elif _hit_flash_uses_sprite:
		_branch_tag = "color_rect"
	_combat_trace("Stratum1Boss._play_slam_impact_flash",
		"tint=(%.2f,%.2f,%.2f) budget_ms=%.0f branch=%s" % [
			SLAM_IMPACT_FLASH_TINT.r, SLAM_IMPACT_FLASH_TINT.g, SLAM_IMPACT_FLASH_TINT.b,
			(SLAM_IMPACT_FLASH_IN + SLAM_IMPACT_FLASH_HOLD + SLAM_IMPACT_FLASH_OUT) * 1000.0,
			_branch_tag
		])


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
	_death_tween.tween_property(
		self, "scale", Vector2(DEATH_TARGET_SCALE, DEATH_TARGET_SCALE), DEATH_TWEEN_DURATION)
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
## Fires once on boss wake (STATE_DORMANT → STATE_WAKING transition — at the
## START of the wake-anim window, so the audio stinger lands on Beat 3
## immediately rather than at the tail of the ~417 ms standup animation).
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
	_shake_tween.tween_property(
		self, "position", rest_offset + Vector2(BOSS_SHAKE_MAGNITUDE, 0.0), leg)
	_shake_tween.tween_property(
		self, "position", rest_offset + Vector2(-BOSS_SHAKE_MAGNITUDE, 0.0), leg)
	_shake_tween.tween_property(self, "position", rest_offset, leg)


## T16 boss-climax burst — sustained 0.9 s ember-rise emitter (replaces the
## pre-T16 single-explosive 24-particle burst). Composed with the F2 camera
## zoom + Vignette deepen orchestrated from `Stratum1BossRoom._on_boss_died`.
##
## Constants block above (`CLIMAX_BURST_*`) carries the full design rationale;
## this function is the wiring. Returns the burst node so the boss-room
## orchestrator (and tests) can introspect the emitter shape without
## re-traversing the room's child list.
##
## Physics-flush safety: see Grunt._spawn_death_particles for full rationale.
## `_die` runs during the physics-step body_entered chain; deferred add_child
## avoids Godot 4's "Can't change this state while flushing queries" panic.
func _spawn_death_particles() -> CPUParticles2D:
	var room: Node = get_parent()
	if room == null:
		return null
	var burst: CPUParticles2D = CPUParticles2D.new()
	burst.global_position = global_position
	# z_index lifts the burst above the boss sprite (z=0) per PR #291 T6
	# same-z occlusion lesson — keep this BEFORE deferred add_child so the
	# property is set when the engine first reads the canvas-item draw order.
	burst.z_index = CLIMAX_BURST_Z_INDEX
	burst.amount = CLIMAX_BURST_PARTICLE_COUNT
	burst.one_shot = true
	burst.explosiveness = CLIMAX_BURST_EXPLOSIVENESS
	burst.lifetime = CLIMAX_BURST_LIFETIME
	burst.emitting = true
	burst.direction = Vector2.UP
	burst.spread = CLIMAX_BURST_SPREAD_DEG
	burst.initial_velocity_min = CLIMAX_BURST_VELOCITY_MIN
	burst.initial_velocity_max = CLIMAX_BURST_VELOCITY_MAX
	burst.gravity = Vector2(0.0, CLIMAX_BURST_GRAVITY_Y)
	burst.scale_amount_min = CLIMAX_BURST_SCALE_MIN
	burst.scale_amount_max = CLIMAX_BURST_SCALE_MAX
	# 3-stop color ramp: impact flash → ember-light → ember-deep. The
	# impact-flash at ramp[0] is the perceptually-distinct near-white frame
	# that breaks the orange-on-red blend per PR #291 v5/v7 finding; the
	# mid-stop sustains the warm orange through the rise; the deep stop is
	# the cooling-ember tail. Offsets shifted slightly so the flash is
	# concentrated in the first ~12% of each particle's life.
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, CLIMAX_BURST_IMPACT_FLASH)
	ramp.set_color(1, EMBER_DEEP)
	ramp.add_point(0.12, EMBER_LIGHT)
	burst.color_ramp = ramp
	room.call_deferred("add_child", burst)
	burst.finished.connect(burst.queue_free)
	_combat_trace("Stratum1Boss._spawn_death_particles",
		"climax sustained burst — amount=%d lifetime=%.2f explosiveness=%.2f scale=[%.1f,%.1f] z=%d" % [
			burst.amount, burst.lifetime, burst.explosiveness,
			burst.scale_amount_min, burst.scale_amount_max, burst.z_index
		])
	return burst


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
	if _wake_left > 0.0:
		_wake_left = max(0.0, _wake_left - delta)


func _set_state(new_state: StringName) -> void:
	if new_state == _state:
		return
	var old: StringName = _state
	_state = new_state
	# M3W-4 animation playback — map state → SpriteFrames anim key. `hit_<dir>`
	# and `die_<dir>` are driven directly from `take_damage` / `_die` (one-shot
	# beats that interrupt the state-anim); the state-driven mapping covers
	# wake/walk/atk/atk_telegraph/slam/slam_telegraph. STATE_DEAD has no entry —
	# `_die` plays `die_<dir>` explicitly. STATE_DORMANT and STATE_PHASE_TRANSITION
	# are also no-op here — boss anim is frozen in those states (dormant uses the
	# .tscn-assigned default `walk_s` frame-0; phase transition holds whatever
	# anim was last playing as the 0.6 s damage-immune window expires).
	# STATE_WAKING (M3-T2-W1-T8, ticket 86c9wjyp9) plays `wake_<dir>` once — the
	# one-shot stand-up animation that bridges DORMANT and IDLE, ~417 ms long.
	match new_state:
		STATE_WAKING:
			_play_anim(&"wake")
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
## `atk_telegraph`, `slam`, `slam_telegraph`, `hit`, `die`, `wake`); the full
## SpriteFrames key is `<state>_<dir>` where `<dir>` is derived from the boss's
## intent — direction toward the player when known, "s" otherwise.
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
