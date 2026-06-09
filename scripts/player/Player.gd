# gdlint:disable=max-public-methods
# Central play-loop class: state-machine + equip + stat + take_damage/heal +
# try_dodge/try_attack + save round-trip form one cohesive Player surface.
# Splitting would trade method count for cross-class coupling.
class_name Player
extends CharacterBody2D
## The Ember-Knight. Top-down 8-directional movement, sprint, an
## invulnerable dodge-roll, and light/heavy melee attacks.
## State-machine driven so attack and dodge states can't interleave.
##
## Decisions encoded here:
##   - Walk speed 120 px/s; sprint multiplier 1.6x; dodge speed 360 px/s.
##   - Dodge duration 0.30s; i-frame window covers the whole dodge.
##   - Dodge cooldown 0.45s, measured from dodge start (so total lockout
##     after dodge end = 0.15s — matches Hades-feel tuning).
##   - During dodge i-frames the player's collision_layer is cleared so
##     enemy hitboxes (mask: layer 2) miss. World collision (layer 1) still
##     blocks via collision_mask, so you can't dodge through walls.
##   - Light attack: 0.18s recovery, 0.10s hitbox lifetime. Damage is
##     computed via Damage.compute_player_damage(equipped_weapon, edge,
##     ATTACK_LIGHT) — no flat constant. With no weapon equipped, fist =
##     1 damage flat (per Damage.FIST_DAMAGE).
##   - Heavy attack: 0.40s recovery, 0.14s hitbox lifetime. Damage is the
##     light-damage value scaled by Damage.HEAVY_MULT (1.6x final).
##   - Attacks cannot be initiated mid-dodge; dodge can interrupt attack
##     recovery (gives the player an out — Hades convention).
##   - Sprint costs no resource in M1; a stamina meter is parked for M2.
##   - Equipped weapon and Edge/Vigor stats live on this node — set by the
##     equipment system (M2 task) and the level-up allocation flow (Uma's
##     LevelUpPanel + Devon's stat-allocation work). Damage formula reads
##     them; setters fire `equipped_weapon_changed` / `stat_changed` for
##     HUD listeners.

# ---- Signals ------------------------------------------------------------

## Emitted when the state machine transitions. Useful for animation hooks
## and tests. New state name on the right.
signal state_changed(from_state: StringName, to_state: StringName)

## Emitted at the start of an i-frame window. Fired from BOTH `try_dodge()`
## (intentional dodge) AND `take_damage()` (post-hit invuln grant — Uma's
## AC4 Room 05 balance pin §3.B). Hitbox scripts listen to this to drop
## their owner from damage tables.
##
## **Note:** consumers that need "the player intentionally dodged" semantics
## (audio cue, tutorial beat) MUST listen to `dodge_started` instead — see
## `team/uma-ux/audio-direction.md §AD-05`. `iframes_started` covers BOTH
## the dodge i-frame window AND the post-hit invuln grant, so subscribing
## the dodge-whoosh cue here fires it on every damage taken (the bug PR #278
## shipped — ticket 86c9vbhf1).
signal iframes_started
signal iframes_ended

## Emitted ONLY from `try_dodge()` after `can_dodge()` validation passes —
## i.e. when the player intentionally rolls. Distinct from `iframes_started`
## (which also fires from `take_damage`'s post-hit invuln grant). This is
## the right signal for "player just dodged" semantics: dodge-whoosh audio
## cue (`sfx-player-dodge` per `audio-direction.md §AD-05`), tutorial LMB
## beat advancement, future dodge-VFX hooks.
##
## Ticket 86c9vbhf1 — Tess PR #278 review found dodge-whoosh fired on every
## damage taken because the audio handler subscribed to `iframes_started`,
## which also fires from `take_damage`. Split fixes that.
signal dodge_started

## Emitted whenever the player spawns an attack hitbox. Useful for VFX
## hooks and tests that want to verify an attack actually fired.
signal attack_spawned(kind: StringName, hitbox: Node)

## Emitted whenever a swing-wedge VFX node is spawned (per
## `team/uma-ux/combat-visual-feedback.md` §1). Tests subscribe to assert
## the wedge appears with correct sizing/alpha/lifetime; gameplay code can
## ignore. Carries the spawned Polygon2D and the attack kind.
signal swing_wedge_spawned(kind: StringName, wedge: Node)

## Emitted when the equipped weapon changes (equip / unequip). HUD listens
## to refresh the weapon-stat panel. New weapon (or null on unequip) on the
## right.
signal equipped_weapon_changed(new_weapon)

## Emitted when the equipped ARMOR changes (equip / unequip). The
## visible-equipment body-look swap (`_on_equipped_armor_changed`) listens to
## swap the body SpriteFrames by armor tier (`visible-equipment-system §4 / §7
## step 5`). New armor ItemDef (or null on unequip) on the right. Sibling of
## `equipped_weapon_changed` — armor and weapon are two independent reads
## (body-look reads ARMOR tier; attack-SET reads WEAPON class, §7 step 4).
signal equipped_armor_changed(new_armor)

## Emitted when a character stat (Vigor / Focus / Edge) changes from level-
## up allocation. Carries the stat name and new value so the HUD can pick
## the relevant block to refresh without a full snapshot read.
signal stat_changed(stat: StringName, new_value: int)

## Emitted when the player takes damage. Carries the damage amount, the
## remaining HP, and the source node (the hitbox owner — typically a mob).
## HUD listens for damage-flash + ghost-bar drain.
signal damaged(amount: int, hp_remaining: int, source: Node)

## Emitted when player HP changes for any reason (damage, heal, restore-from-save).
## HUD listens to refresh the HP bar.
signal hp_changed(hp_current: int, hp_max: int)

## Emitted when the player's HP hits zero. The Main controller subscribes to
## this to drive the death/respawn flow per the M1 death rule
## (level + equipped survive, unequipped + run-progress reset).
## Fires exactly once per Player lifetime — the player is then expected to be
## removed from the tree by the controller.
signal player_died(death_position: Vector2)

## Emitted when the out-of-combat regen state transitions (false -> true or
## true -> false). HUD listens to start/stop the HP-bar shimmer tween.
## M2 audio hook: a heartbeat-recovery hum can wire here without touching
## Player.gd logic — the signal fires even though no audio bus listens in M1.
signal regen_active_changed(active: bool)

# ---- Tuning constants ---------------------------------------------------

const STATE_IDLE: StringName = &"idle"
const STATE_WALK: StringName = &"walk"
const STATE_DODGE: StringName = &"dodge"
const STATE_ATTACK: StringName = &"attack"

const ATTACK_LIGHT: StringName = &"light"
const ATTACK_HEAVY: StringName = &"heavy"

const WALK_SPEED: float = 120.0
const SPRINT_MULTIPLIER: float = 1.6
const DODGE_SPEED: float = 360.0
const DODGE_DURATION: float = 0.30
const DODGE_COOLDOWN: float = 0.45  # measured from dodge START

# Post-hit invulnerability window (Uma's AC4 Room 05 balance pin,
# `team/uma-ux/ac4-room05-balance-design.md` §3.B). Granted after every
# non-fatal `take_damage` to break simultaneous-hit clusters in multi-chaser
# rooms without trivialising skilled dodge play. Strictly SHORTER than
# `DODGE_DURATION = 0.30` so the dodge mechanic remains the dominant skilled
# strategy (eat-hit-and-recover stays a safety floor, not a free crutch).
# Re-uses `_enter_iframes` / `_exit_iframes` infrastructure (collision-layer
# swap honored by `Hitbox.gd::_try_apply_hit`).
const HIT_IFRAMES_SECS: float = 0.25

# Light: short reach, fast recovery. Damage comes from Damage.gd formula
# (weapon_base + Edge + light/heavy multiplier).
const LIGHT_KNOCKBACK: float = 80.0
const LIGHT_REACH: float = 28.0
const LIGHT_HITBOX_RADIUS: float = 18.0
const LIGHT_HITBOX_LIFETIME: float = 0.10
const LIGHT_RECOVERY: float = 0.18

# Heavy: longer reach, slower recovery. Damage scaled by Damage.HEAVY_MULT.
const HEAVY_KNOCKBACK: float = 180.0
const HEAVY_REACH: float = 36.0
const HEAVY_HITBOX_RADIUS: float = 22.0
const HEAVY_HITBOX_LIFETIME: float = 0.14
const HEAVY_RECOVERY: float = 0.40

# Mouse-direction attacks (ticket 86c9uthf0). Sponsor 2026-05-17: player
# attacks fire in the direction of the mouse cursor (Hades/Diablo convention).
# `_facing` is continuously updated from the mouse vector in `_physics_process`
# (gated by state — see `_update_mouse_facing`); WASD is decoupled from
# facing entirely (player can walk one direction while aiming another).
#
# Dead-zone: if the mouse is closer to the player than MOUSE_FACING_DEADZONE_PX,
# the vector is too short to normalise stably (jitter at the cursor-on-player
# limit) — keep last `_facing` instead. The cursor leaving the canvas in HTML5
# does NOT need special handling: Godot's `get_global_mouse_position()` returns
# the LAST observed cursor position when the pointer leaves the canvas, which
# is naturally stable (the value just freezes at the boundary).
const MOUSE_FACING_DEADZONE_PX: float = 8.0

const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")
const DamageScript: Script = preload("res://scripts/combat/Damage.gd")

# ---- Out-of-combat HP regen tunables (exported for balance-pass tweaks) --
# Both cooldowns must BOTH be exceeded before regen activates — spec §"Activation rule".
# Named per Uma's spec: REGEN_DAMAGE_COOLDOWN_SECS / REGEN_ATTACK_COOLDOWN_SECS.
# REGEN_RATE_HP_PER_SEC: 2.0 HP/s — Uma's trade-math rationale in hp-regen-design.md §"Regen rate".
@export var REGEN_DAMAGE_COOLDOWN_SECS: float = 3.0
@export var REGEN_ATTACK_COOLDOWN_SECS: float = 3.0
@export var REGEN_RATE_HP_PER_SEC: float = 2.0

# ---- Visual-feedback constants (per team/uma-ux/combat-visual-feedback.md §1)
# Ember-color directional wedge spawned during the hitbox-lifetime window.
# Wedge length matches LIGHT/HEAVY_REACH; half-width matches the hitbox
# circle radius — so the placeholder cue reads where the hit actually lands.
# Color/alpha and lifetimes are locked by Uma's spec, NOT priors.
const SWING_WEDGE_COLOR_RGB: Color = Color(1.0, 0.4156862745, 0.1647058824)  # #FF6A2A
const SWING_WEDGE_ALPHA_LIGHT: float = 0.55
const SWING_WEDGE_ALPHA_HEAVY: float = 0.70

# Player ember-flash modulate — 60ms total: 30ms toward ember, 30ms back to
# white. Sub-1.0 warm-yellow tint per HTML5-safe values: GLES2/3 web canvas
# in `gl_compatibility` clamps modulate to [0,1] (HDR overbright is unavailable
# on the web target), so the previous `Color(1.4, 1.0, 0.7, 1)` clamped to
# `(1.0, 1.0, 0.7, 1)` and the flash was barely visible. Sub-1.0 values give
# a guaranteed-visible warm darkening on every renderer. Both attack types
# use the same flash duration.
# Bug B reference: Sponsor soak `embergrave-html5-f62991f` — `[combat-trace]
# Player.swing_flash | tint=(1.40,1.00,0.70)` HDR-clamped to no-op on HTML5.
const SWING_FLASH_TINT: Color = Color(1.0, 0.85, 0.6, 1.0)
const SWING_FLASH_HALF_DURATION: float = 0.030  # 30ms each way → 60ms total

# Z-index per spec: above floor, but ALSO above the player body so HTML5
# `gl_compatibility` reliably renders the wedge — under that renderer
# negative-relative z-index draw ordering has been observed to drop the
# wedge below the room background (Bug A reference: Sponsor soak
# `embergrave-html5-f62991f` — `[combat-trace] Player.swing_wedge | spawned
# kind=light lifetime=0.100 tween_valid=true alpha=0.55` fired but no visual).
# Stamping the wedge slightly *above* the player ColorRect still reads as a
# flash extending from the player at M1 placeholder fidelity.
const SWING_WEDGE_Z_INDEX: int = 1

# ---- M3W-2 AnimatedSprite2D constants ----------------------------------
# Inherits the M3W-1 (PR #271, PracticeDummy) conventions verbatim per
# `.claude/docs/combat-architecture.md §"M3W-1 realized implementation"`.

## Hit-flash modulate tint for the AnimatedSprite2D path (M3W-1 convention).
## ColorRect placeholders tweened color rest→white→rest; the painted PixelLab
## sprite frames are already near-white, so a white tween is a visible no-op
## (the PR #115 / #140 trap class). AnimatedSprite2D's `modulate` is
## multiplicative — we tween toward a soft red wash so the painted sprite
## tints visibly red on hit. All channels sub-1.0 per HTML5 HDR-clamp rule
## (PR #137 lesson, codified in `.claude/docs/html5-export.md`). Constant
## value MUST stay identical to `PracticeDummy.HIT_FLASH_TINT` so the M3 art
## roster reads with a single hit-reaction color (M3W-1 inheritance contract).
const HIT_FLASH_TINT: Color = Color(1.0, 0.50, 0.50, 1.0)  # soft red wash, HTML5-safe
## Hit-flash timing envelope — mirror PracticeDummy (20ms in, 20ms hold, 40ms
## out = 80ms total). Short enough to feel snappy; long enough that the eye
## registers the wash on a 60fps render. 3-stage tween (in → hold → out) so a
## second hit during the hold leaves a visible kill-and-restart artifact.
const HIT_FLASH_IN: float = 0.020
const HIT_FLASH_HOLD: float = 0.020
const HIT_FLASH_OUT: float = 0.040

## State-name → SpriteFrames anim-prefix map. Authored separately from
## STATE_* constants because (a) STATE_IDLE shares its anim with STATE_WALK
## (both → `walk`; idle is "walk frame 0 hold" placeholder until idle anim
## ships as M3 follow-up per Priya's brief), and (b) STATE_ATTACK splits into
## attack_light / attack_heavy at run-time based on `_current_attack_kind`.
const ANIM_PREFIX_IDLE_AND_WALK: String = "walk"
const ANIM_PREFIX_ATTACK_LIGHT: String = "attack_light"
const ANIM_PREFIX_ATTACK_HEAVY: String = "attack_heavy"
const ANIM_PREFIX_DODGE: String = "dodge"
const ANIM_PREFIX_HIT: String = "hit"
const ANIM_PREFIX_DIE: String = "die"

## ONE_HAND_MELEE attack-SET prefixes (visible-equipment system §2 / §7 step 2).
## A 1H-weapon equip selects these so the body SWINGS instead of punching.
## The art does NOT exist yet (`86ca56w4f` is the gen-independent foundation) —
## `_resolve_attack_set` falls back to the FIST prefixes above when the
## `<prefix>_<dir>` key is absent from the SpriteFrames, so nothing breaks
## pre-art. idle/walk/dodge/hit/die are NOT class-suffixed (shared across
## classes — only the ATTACK animation differs by class, §2).
const ANIM_PREFIX_ATTACK_LIGHT_1H: String = "attack_light_1h"
const ANIM_PREFIX_ATTACK_HEAVY_1H: String = "attack_heavy_1h"

# ---- Runtime state ------------------------------------------------------

var _state: StringName = STATE_IDLE
var _facing: Vector2 = Vector2.DOWN

# Throttle accumulator for the HTML5-only `Player.pos` harness-observability
# trace (see `_physics_process`). The Playwright harness cannot read Godot
# world-coords without a JS bridge — this trace is how browser-driven specs
# (notably the AC4 Shooter-chase sub-helper) steer the player toward a mob.
var _pos_trace_accum: float = 0.0
## How often the `Player.pos` trace emits. 0.25 s is fine-grained enough for
## the harness to course-correct a pursuit, cheap enough to be a no-op on
## perf (one print every ~15 physics frames, HTML5-only).
const POS_TRACE_INTERVAL: float = 0.25

# Dodge bookkeeping
var _dodge_time_left: float = 0.0
var _dodge_cooldown_left: float = 0.0
var _dodge_dir: Vector2 = Vector2.ZERO
var _is_invulnerable: bool = false

# Attack bookkeeping
var _attack_recovery_left: float = 0.0
## Most-recent attack kind. The state machine uses a single STATE_ATTACK; the
## kind (light/heavy) needs to be remembered so the AnimatedSprite2D anim
## resolver can pick `attack_light_<dir>` vs `attack_heavy_<dir>` from the
## `state_changed` signal. Set in `try_attack` BEFORE `set_state(STATE_ATTACK)`
## so the signal handler sees the correct kind.
##
## Also read by receivers of the active swing's `Hitbox.take_damage` chain — the
## Hitbox passes `_source = Player` as the third arg, so a downstream receiver
## (e.g. `Stratum1Boss.take_damage` for T2 hit-pause duration selection) can
## read this via the duck-typed accessor `get_current_attack_kind()` below.
var _current_attack_kind: StringName = ATTACK_LIGHT

# ---- M3W-2 hit-flash + AnimatedSprite2D runtime ------------------------
# Hit-flash 3-branch resolver — mirrors PracticeDummy.gd shape (M3W-1
# inheritance contract per `.claude/docs/combat-architecture.md`).
# Branches:
#   1. AnimatedSprite2D child (production .tscn-loaded Player)  → tween modulate
#      to HIT_FLASH_TINT and back (soft red wash on the painted sprite).
#   2. ColorRect child (legacy / pre-M3W-2 fallback authored .tscn) → tween
#      Sprite.color rest → white → rest. Kept for back-compat with any
#      pre-M3W-2 test/scene that still authors ColorRect.
#   3. No Sprite child (bare-instanced Player.new() test contexts) → tween
#      self.modulate. Preserves Tier 1 reference-change invariant in GUT.
var _hit_flash_tween: Tween = null
var _hit_flash_target: CanvasItem = null
var _hit_flash_uses_sprite: bool = false
var _hit_flash_uses_animated_sprite: bool = false
var _sprite_color_at_rest: Color = Color(1, 1, 1, 1)
var _sprite_modulate_at_rest: Color = Color(1, 1, 1, 1)
var _hit_flash_modulate_at_rest: Color = Color(1, 1, 1, 1)
var _captured_hit_flash_rest: bool = false

# AnimatedSprite2D cache — resolved lazily on first `_play_anim_for_state`
# call so bare-instanced tests that don't have an AnimatedSprite2D child
# silently no-op rather than crash.
var _animated_sprite: AnimatedSprite2D = null
var _animated_sprite_resolved: bool = false

# ---- Visible-equipment foundation (ticket 86ca56w4f) -------------------
# §1 LAYER 2 — the weapon-overlay node. A sibling Sprite2D (NOT a child of the
# body `Sprite` AnimatedSprite2D) pinned over the body at z=1, riding the swing
# per the §3 hand-anchor convention. Hidden when unarmed. Created in `_ready`
# (no `.tscn` edit needed — keeps the foundation pure-code) and cached here.
# Texture/anchor stay EMPTY in this foundation PR — overlay art + the anchor
# table land with the swing-art pilot step (§5.3 step 2). See
# `team/uma-ux/visible-equipment-system.md §1 / §3 / §7 step 3-4`.
const WEAPON_HAND_NODE_NAME: StringName = &"WeaponHand"
## z_index for the weapon overlay — explicit per the HTML5 z-tie-break rule
## (`html5-export.md`): over the body (z=0) on most frames; behind-body
## wind-up frames set -1 explicitly via the anchor table (not authored yet).
const WEAPON_HAND_Z_INDEX: int = 1
var _weapon_hand: Sprite2D = null

# §4/§5 armor-tier body-look swap seam. Maps an `ItemDef.Tier` → the body
# SpriteFrames `.tres` for that armor tier. STUB in this foundation PR — no
# armor bodies exist yet, so the map is empty and `_apply_armor_body_look`
# is a guarded no-op. When the armor bodies land, populate this map; the swap
# path (resource-pointer swap + replay-current-state + hit-flash cache
# invalidation) is already wired and tested. §7 step 5.
var _armor_body_frames_by_tier: Dictionary = {}

# ---- M3W-2 walk-feel fix (Sponsor 2026-05-18 soak finding) -------------
# `_facing` is mouse-derived (PR #255) and correct for attack/dodge aim. But
# feeding it to `walk_<dir>` made the body pivot toward the cursor while
# strafing sideways — Sponsor's "looking at mouse cursor while walking is
# weird" finding on the M3W-2 PR #274 soak.
#
# Fix: decouple animation direction from aim direction in the anim resolver.
#   - WALK / IDLE → movement direction (velocity octant). Idle holds last.
#   - ATTACK / DODGE / HIT / DIE → mouse-derived `_facing` (unchanged).
#
# `_last_anim_dir` is the persisted movement octant. Initialized to "s" so
# the seed-anim path in `_ready` matches the default `_facing = Vector2.DOWN`
# (south) — pre-fix and post-fix produce the same first-frame rest pose.
#
# Velocity-octant threshold: 1.0 px/s is a sentinel for "not moving" that
# survives floating-point drift. `_process_grounded` writes either
# `velocity = Vector2.ZERO` (IDLE) or `velocity = input_dir * speed` (WALK,
# speed ≥ get_walk_speed() == 120 px/s); 1.0 has no collision with either
# regime. `_process_attack` writes drift velocity (input_dir * 60 px/s) but
# attack state doesn't use velocity-octant anyway.
const VELOCITY_OCTANT_THRESHOLD: float = 1.0
var _last_anim_dir: String = "s"

# Visual-feedback bookkeeping — track the active swing-wedge + flash tween
# so we can apply the kill-and-restart pattern Uma's spec calls out: a second
# attack fired during the previous attack's recovery replaces the old cue
# rather than stacking. Both fields are weakly-referenced (we null them on
# tween_finished) so we don't keep stale Node/Tween references alive.
#
# Wedge is a ColorRect (rotated rectangle) — Uma's spec lets us pick ColorRect
# OR Polygon2D; the original implementation went with Polygon2D, but Sponsor's
# HTML5 soak (Bug A) indicated Polygon2D wasn't rendering reliably under
# `gl_compatibility`. ColorRect is the simplest, most-tested 2D primitive in
# every Godot 4 renderer mode, so it's the HTML5-safe baseline.
var _active_swing_wedge: ColorRect = null
var _active_flash_tween: Tween = null

# Collision layer to restore after dodge i-frames clear it.
const PLAYER_LAYER_BIT: int = 2  # see project.godot 2d_physics/layer_2 = "player"
var _saved_collision_layer: int = 0

# ---- Equipment + character stats ---------------------------------------
# Read by Damage.compute_player_damage at attack time. Set by the equipment
# system (M2) and the level-up allocation flow (Uma's LevelUpPanel +
# Devon's stat-allocation work). Defaults match Save.DEFAULT_PAYLOAD —
# null weapon (fist-fights the first room), zero stat allocation.
var _equipped_weapon: ItemDef = null
var _vigor: int = 0
var _focus: int = 0
var _edge: int = 0

# Affix-driven move_speed bonus (flat px/s ADD on top of WALK_SPEED, per
# the swift affix). Tracked on Player (not PlayerStats) because move_speed
# is a Player-local concept; PlayerStats owns V/F/E. Per
# `team/drew-dev/affix-application.md`.
var _move_speed_bonus: float = 0.0

# Equipped ItemInstance map: slot StringName -> ItemInstance. Distinct from
# `_equipped_weapon: ItemDef` (which is the legacy/Damage-formula slot
# pointer for back-compat with existing tests). When equip_item is called
# with a weapon, both `_equipped[&"weapon"]` and `_equipped_weapon` are set.
# Affix application reads from `_equipped[*].rolled_affixes`.
var _equipped_items: Dictionary = {}

# ---- HP / death --------------------------------------------------------
# Baseline HP matches Save.DEFAULT_PAYLOAD ("hp_current": 100, "hp_max": 100).
# Vigor scaling is M2 polish — for M1 we ship a flat 100/100 so the loop is
# legible and the death rule has a deterministic threshold.
const DEFAULT_HP_MAX: int = 100

# Public-readable HP fields. Match the Save schema's character.hp_current /
# hp_max keys so save-roundtrip is mechanical.
var hp_current: int = DEFAULT_HP_MAX
var hp_max: int = DEFAULT_HP_MAX

# One-shot death latch — `player_died` fires exactly once per Player
# lifetime. Subsequent take_damage calls during the death frame are no-ops.
var _is_dead: bool = false

# ---- Out-of-combat regen state ------------------------------------------
# Both timers count UP from 0 on each reset event and are incremented by
# delta each physics frame. Regen activates when BOTH exceed their threshold.
# Reset semantics:
#   _time_since_last_damage_taken: reset to 0 in take_damage()
#   _time_since_last_hit_landed:   reset to 0 in _on_hitbox_hit_target()
var _time_since_last_damage_taken: float = 0.0
var _time_since_last_hit_landed: float = 0.0

## Public read-only regen state — tests and HUD read this. True when BOTH
## out-of-combat timers have exceeded their thresholds AND hp_current < hp_max.
var is_regenerating: bool = false
# Fractional HP accumulator so 2.0 HP/s doesn't drift to 1 HP/s under integer
# rounding across frames with variable delta.
var _regen_carry: float = 0.0

# ---- M3 Tier 3 W2 quest persistence (ticket 86c9y7ydg / W2-T6) ----------
##
## **Single-active-bounty structural lock** per W2-T7 §9 v6 trigger guard
## addendum. The player may carry at most ONE active QuestState at a time.
## QuestActionRouter rejects `accept_bounty` actions when this field is
## non-null (`WarningBus.warn(..., "quest")`); the rejection is structural,
## not a bug. Multi-concurrent-bounty is deferred to v6.
##
## **Save round-trip**: serialised via `to_save_dict()` into
## `data.character.active_bounty` (as a Dictionary, or null when no
## active bounty). Restored via `restore_from_save_dict()` on load.
## Schema is additive per `team/devon-dev/save-schema-v5-tier3-additions.md`
## §2.5 — uses `has()`-guarded backfill in `Save._migrate_v4_to_v5`.
##
## Typed as `Variant` (rather than `QuestState`) so the field can hold
## either a QuestState reference OR `null` (Godot 4 GDScript doesn't admit
## `QuestState | null` union typing). Consumers do `is QuestState` checks.
var active_bounty: Variant = null

## Append-only list of completed-quest StringName ids. Stable across
## patches per `m3-design-seeds.md §3.9` (a future rename of a shipped
## quest_id would orphan player saves; W3+ quest-content authors pin ids
## at first ship).
##
## **Save round-trip**: serialised into `data.character.completed_bounties`
## via `to_save_dict()`. JSON-serialised as Array[String]; load layer
## stringifies back via the QuestStateResolver._completed_contains helper
## (the comparison is robust to either StringName or String shapes).
var completed_bounties: Array = []

# ---- M3 Tier 3 W2-T5 world-map discovery state (ticket 86c9y10fv) -------
##
## Per-character zone-discovery dict consumed by WorldMapPanel. Keyed by
## `ZoneDef.zone_id: StringName`; value `true` = entered at least once.
## Absent / false = undiscovered (fog-of-war on map UI). Discovery is
## **monotone-grow** — once true, never reset within a character's life.
##
## **Why Dictionary[StringName, bool] not Array[StringName]:** O(1)
## membership check + supports future expansion (per-zone state sub-keys
## for entry-count / first-visited timestamp / cleared-state) without a
## non-additive schema bump. Matches the survey §2.2 shape lock in
## `team/devon-dev/save-schema-v5-tier3-additions.md`.
##
## **Why per-character:** matches Sponsor's 2026-05-17 per-character
## decision rationale for `hub_town_seen` — each character is encountering
## the world as themselves. Per-character also keeps the multi-character
## v5 surface clean (no cross-character shared state).
##
## **Save round-trip:** serialised into `data.character.discovered_zones`
## via `to_save_dict()`. JSON serialises StringName keys as String; the
## load layer normalises every key back to StringName at restore time.
## Backfill default `{}` lives in `Save._backfill_v5_tier3_quest_fields`
## (renamed to `_backfill_v5_tier3_fields` to cover both quest + world-map
## additions; both ride additively on schema v5 per §5).
## **Key-type note (Godot 4.3):** Godot 4.3 lacks typed `Dictionary[K, V]`
## syntax (added in 4.4 — verified empirically against CI parse error "Only
## arrays can specify collection element types," PR #362 fix attempt v1).
## The Dictionary is untyped at the field level; runtime stores keys as
## TYPE_STRING (StringName/String canonicalize on insert into an untyped
## Variant slot). All `.has(zone_id)` / `.get(zone_id, ...)` lookups still
## work because Godot's Dictionary lookup is StringName↔String-equivalent.
## Consumers MUST NOT branch on `typeof(k) == TYPE_STRING_NAME` — see
## `_normalise_dict_keys_to_stringname` docstring for the canonical key-shape
## contract under Godot 4.3.
var discovered_zones: Dictionary = {}

## Per-character waypoint-discovery dict. Keyed by StringName waypoint id
## (convention `<stratum>_<zone>_<waypoint_slug>`). `true` = discovered +
## available for future fast-travel (W3+ surface). M3 W2 ships the field
## with a minimal consumer (panel reads it but no waypoint UI yet —
## M4 expansion per ticket Part B).
##
## **Same shape rules as `discovered_zones`** — untyped Dictionary (Godot
## 4.3 lacks typed-Dict syntax; see `discovered_zones` for the key-shape
## contract under Godot 4.3).
var discovered_waypoints: Dictionary = {}


func _ready() -> void:
	# Seed the saved layer mask from whatever the scene authored. Tests may
	# also instantiate this node bare (no scene), in which case the default
	# CharacterBody2D.collision_layer == 1 (bare-default) — explicitly set
	# the player bit. Production .tscn authors layer=2 already; this branch
	# is a no-op for the production path. Matches the BARE_DEFAULT_LAYER
	# pattern used by Grunt/Charger/Shooter/Stratum1Boss/PracticeDummy._ready.
	const BARE_DEFAULT_LAYER: int = 1
	if collision_layer == 0 or collision_layer == BARE_DEFAULT_LAYER:
		collision_layer = 1 << (PLAYER_LAYER_BIT - 1)
	_saved_collision_layer = collision_layer
	# Register in the "player" group so other systems (Pickup, Grunt's
	# `_resolve_player`, InventoryPanel `_player_node`) find this node via
	# group lookup. Idempotent: add_to_group is a no-op if already in the group.
	add_to_group("player")
	# NOTE: there is no boot-time starter-weapon auto-equip — not here, not in
	# Main._ready(). The PR #146 `equip_starter_weapon_if_needed` bandaid was
	# retired in ticket 86c9qbb3k. The player starts fistless by design; the
	# Stage-2b Room01 PracticeDummy drops an iron_sword the player picks up,
	# and `Inventory.on_pickup_collected` auto-equips the first weapon picked
	# up. A save-restored equipped weapon is re-applied by save-restore.
	# See: fix(combat|inventory) PR — iron_sword integration-surface fix.

	# M3W-2: drive AnimatedSprite2D from the existing state_changed signal.
	# The signal already exists (line 34) "useful for animation hooks and tests"
	# — wiring it here keeps the state machine untouched. Idempotent connect
	# guard: tests that bare-instance the Player and re-`_ready` don't double-
	# connect.
	if not state_changed.is_connected(_on_state_changed):
		state_changed.connect(_on_state_changed)
	# Seed the AnimatedSprite2D animation to the rest-state walk frame so the
	# scene-loaded Player shows the correct facing on first render (before any
	# state transition fires). `_on_state_changed` will re-drive on the first
	# real transition.
	_play_anim_for_state(_state)

	# M3W-7 audio-cue wiring — connect existing combat signals to AudioDirector
	# SFX plays. Each connection is idempotent guarded so tests that bare-
	# instance Player + re-`_ready` don't double-connect (which would fire the
	# cue twice per beat). Routes:
	#   attack_spawned(kind=light)  → SFX_PLAYER_ATTACK_LIGHT
	#   attack_spawned(kind=heavy)  → SFX_PLAYER_ATTACK_HEAVY
	#   damaged(amount>0)           → SFX_PLAYER_HIT
	#   dodge_started               → SFX_PLAYER_DODGE
	# `dodge_started` (NOT `iframes_started`) is the dodge-whoosh trigger —
	# ticket 86c9vbhf1. Subscribing on `iframes_started` fired the cue on
	# every `take_damage` post-hit-iframe grant (Uma's AC4 Room 05 balance
	# pin §3.B), which violates `audio-direction.md §AD-05` "dodge-whoosh
	# plays ONLY on intentional dodge". Both signals still emit per dodge;
	# only `dodge_started` is dodge-exclusive.
	# All routes fire from gameplay signals that necessarily come AFTER a user
	# gesture (keyboard/mouse input), satisfying the HTML5 audio-playback gate
	# per `.claude/docs/audio-architecture.md`.
	if not attack_spawned.is_connected(_on_attack_spawned_audio):
		attack_spawned.connect(_on_attack_spawned_audio)
	if not damaged.is_connected(_on_damaged_audio):
		damaged.connect(_on_damaged_audio)
	if not dodge_started.is_connected(_on_dodge_started_audio):
		dodge_started.connect(_on_dodge_started_audio)

	# Visible-equipment foundation (ticket 86ca56w4f). Ensure the LAYER 2
	# weapon-overlay node exists, then wire the equip-change handlers that
	# show/hide it (weapon) and swap the body look (armor). Idempotent connect
	# guards mirror the audio wiring above so bare-instance + re-`_ready` tests
	# don't double-connect. The handlers fire on the existing equip signals; no
	# state-machine change. See `team/uma-ux/visible-equipment-system.md §7`.
	_ensure_weapon_hand_overlay()
	if not equipped_weapon_changed.is_connected(_on_equipped_weapon_changed):
		equipped_weapon_changed.connect(_on_equipped_weapon_changed)
	if not equipped_armor_changed.is_connected(_on_equipped_armor_changed):
		equipped_armor_changed.connect(_on_equipped_armor_changed)
	# Seed the overlay visibility from the boot equip-state (unarmed → hidden).
	_on_equipped_weapon_changed(get_equipped_weapon())


func _physics_process(delta: float) -> void:
	_tick_timers(delta)

	# Mouse-direction facing (ticket 86c9uthf0). Sponsor 2026-05-17: player
	# attacks fire in the direction of the mouse cursor. `_update_mouse_facing`
	# gates by state so a dodge / mid-swing facing does NOT continuously shift
	# under mouse motion (edge case 3 in the ticket — facing must snapshot at
	# swing-spawn). WASD movement is decoupled from facing in `_process_grounded`.
	_update_mouse_facing()

	match _state:
		STATE_IDLE, STATE_WALK:
			_process_grounded(delta)
		STATE_DODGE:
			_process_dodge(delta)
		STATE_ATTACK:
			_process_attack(delta)

	move_and_slide()

	# M3W-2 walk-feel fix (Sponsor 2026-05-18 soak): if the player is still
	# in STATE_WALK and the velocity octant changed mid-state (e.g. WASD
	# direction change without leaving WALK), re-drive the walk_<dir> anim.
	# `state_changed` only fires on state transitions, so without this the
	# anim would lock to whatever direction triggered the WALK transition.
	_drive_walk_anim_if_moving()

	# Harness-observability trace (HTML5-only via the combat_trace shim).
	# Throttled world-coord readback so Playwright specs can steer the player
	# relative to mobs — the Playwright harness has no JS bridge into Godot,
	# so this trace is the only way browser-driven specs (the AC4 Shooter-
	# chase sub-helper, ticket 86c9tz7zg) can pursue a kiting mob. Costs one
	# print every POS_TRACE_INTERVAL seconds; combat_trace is a no-op unless
	# `OS.has_feature("web")`, so headless GUT / desktop pay nothing.
	_pos_trace_accum += delta
	if _pos_trace_accum >= POS_TRACE_INTERVAL:
		_pos_trace_accum = 0.0
		# `sprite_rot=` is the harness-observability surface for the M3W-2
		# walk-feel decouple regression (PR #274 Fix #2). The Sprite node's
		# `rotation` property MUST stay 0.0 by design — `_update_sprite_rotation`
		# pins it (see line ~1201). Browser-driven specs (see
		# `tests/playwright/specs/player-walk-feel-decouple.spec.ts`) parse this
		# field and assert ~0 across many frames; any future regression that
		# re-couples node rotation to `_facing` (cursor-aim "the character is
		# looking at the mouse" Sponsor-soak finding) is caught HTML5-side here.
		# 6 decimals so any non-zero leak is visible — a single mis-set frame
		# anywhere in the boot-or-walk window flips the spec red.
		var _sprite_rot: float = 0.0
		var _sprite_for_rot: Node = get_node_or_null("Sprite")
		if _sprite_for_rot is CanvasItem:
			_sprite_rot = (_sprite_for_rot as CanvasItem).rotation
		_combat_trace(
			"Player.pos",
			(
				"pos=(%.0f,%.0f) state=%s sprite_rot=%.6f"
				% [global_position.x, global_position.y, _state, _sprite_rot]
			)
		)
		# Diagnostic-only instrumentation (ticket `86c9uq0ky` — Finding 2 NEW
		# bug class investigation, 2026-05-16 Sponsor soak of `8e76c74`).
		# Throttled alongside `Player.pos` so Sponsor's HTML5 console always
		# has a same-tick datapoint of player collision presence — if Pickup +
		# StratumExit report `monitoring=true` AND `cs_disabled=false` AND
		# `overlapping_bodies=0` while the player is spatially adjacent, the
		# question becomes "is the PLAYER physics body actually present in the
		# world?" During dodge i-frames `collision_layer` is intentionally
		# cleared to 0 (see `_enter_iframes`) — this trace surfaces that state
		# directly so we can rule out "player invisible to Area2D queries during
		# the soak window where the player walked around the pickups." If
		# `cs_disabled=true` here, the bug is on the player side regardless of
		# any Pickup-side diagnostics.
		var pcs: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
		var pcs_disabled: String = "<no_cs>"
		if pcs != null:
			pcs_disabled = str(pcs.disabled)
		_combat_trace(
			"Player.coll_diag",
			(
				"pos=(%.0f,%.0f) layer=%d mask=%d cs_disabled=%s iframes=%s"
				% [
					global_position.x,
					global_position.y,
					collision_layer,
					collision_mask,
					pcs_disabled,
					str(_is_invulnerable),
				]
			)
		)


# ---- Public API (used by tests, hitbox scripts, save) -------------------


## Returns the current state. Read-only — transitions go through the state
## machine.
func get_state() -> StringName:
	return _state


## True while the dodge i-frame window is active. Hitbox scripts must
## consult this before applying damage.
func is_invulnerable() -> bool:
	return _is_invulnerable


## True if a dodge can be initiated *right now* (cooldown clear, not
## already dodging). Useful for UI affordances and tests.
func can_dodge() -> bool:
	return _state != STATE_DODGE and _dodge_cooldown_left <= 0.0


## True if a new attack can fire right now: not dodging, not in attack
## recovery. Idle/walk both allow attack starts.
func can_attack() -> bool:
	return _state != STATE_DODGE and _attack_recovery_left <= 0.0


## Get the unit vector the player is facing. Used by attack spawners.
func get_facing() -> Vector2:
	return _facing


## Returns the most-recent swing kind (`ATTACK_LIGHT` or `ATTACK_HEAVY`). Set
## in `try_attack` before each swing; persists between swings. Receivers of the
## active swing's `Hitbox.take_damage(amount, knockback, source=Player)` chain
## read this via duck-typed dispatch (`source.has_method("get_current_attack_kind")`)
## to pick per-kind feel responses — e.g. `Stratum1Boss.take_damage` picks the
## T2 hit-pause duration (60 ms light, 100 ms heavy per Priya's AC).
func get_current_attack_kind() -> StringName:
	return _current_attack_kind


## Returns the currently-equipped weapon ItemDef, or null if unarmed.
func get_equipped_weapon() -> ItemDef:
	return _equipped_weapon


## Equip / unequip the weapon (pass null to unequip). Fires
## `equipped_weapon_changed`. M1 contract: only one weapon slot.
##
## **Affix-naive version.** This sets the legacy `_equipped_weapon: ItemDef`
## reference used by the damage formula. For an affix-aware equip path
## (apply rolled affixes on equip, reverse on unequip), use `equip_item`
## with an `ItemInstance`.
func set_equipped_weapon(weapon: ItemDef) -> void:
	if weapon == _equipped_weapon:
		return
	_equipped_weapon = weapon
	equipped_weapon_changed.emit(weapon)


# ---- ItemInstance equip / unequip (affix-aware) -----------------------

const SLOT_WEAPON: StringName = &"weapon"
const SLOT_ARMOR: StringName = &"armor"


## Equip an `ItemInstance` into its slot. Walks the instance's rolled
## affixes and applies each one to PlayerStats (for V/F/E) or directly to
## Player-local fields (move_speed). If a different instance is already
## equipped in that slot, it's unequipped first (clean reverse).
##
## Idempotency: equipping the **same instance** that's already in its slot
## is a no-op (no double-application). Two distinct instances of the same
## ItemDef *are* distinct (each has its own rolled_affixes).
##
## See `team/drew-dev/affix-application.md` for the full math and decisions.
##
## Returns true on equip, false if the input was null.
func equip_item(instance: ItemInstance) -> bool:
	if instance == null or instance.def == null:
		return false
	var slot: StringName = _slot_for(instance.def.slot)
	if slot == &"":
		push_warning("Player.equip_item: unsupported slot %d" % instance.def.slot)
		return false
	# Idempotency: same-instance re-equip is a no-op.
	var current: ItemInstance = _equipped_items.get(slot, null) as ItemInstance
	if current == instance:
		return true
	# Unequip the existing item in this slot first (reverses its affixes).
	if current != null:
		_unequip_internal(slot, current)
	_equipped_items[slot] = instance
	_apply_item_affixes(instance)
	# Mirror to legacy weapon ref so Damage formula keeps working.
	if slot == SLOT_WEAPON:
		_equipped_weapon = instance.def
		equipped_weapon_changed.emit(instance.def)
	elif slot == SLOT_ARMOR:
		# Visible-equipment body-look seam — armor tier drives the body swap.
		equipped_armor_changed.emit(instance.def)
	return true


## Remove the item currently in `slot` (one of SLOT_WEAPON / SLOT_ARMOR).
## Reverses its affix contributions. No-op if the slot is empty.
##
## Returns the unequipped ItemInstance, or null if nothing was there.
func unequip_item(slot: StringName) -> ItemInstance:
	var current: ItemInstance = _equipped_items.get(slot, null) as ItemInstance
	if current == null:
		return null
	_unequip_internal(slot, current)
	return current


## Returns the ItemInstance currently equipped in `slot`, or null if empty.
func get_equipped_item(slot: StringName) -> ItemInstance:
	return _equipped_items.get(slot, null) as ItemInstance


## Returns the player's effective walk speed, including the swift-affix
## ADD bonus. Use this instead of `WALK_SPEED` when computing velocity.
func get_walk_speed() -> float:
	return WALK_SPEED + _move_speed_bonus


## Returns the current move-speed affix bonus (px/s ADD). Tests + HUD.
func get_move_speed_bonus() -> float:
	return _move_speed_bonus


# ---- Internal: affix apply / reverse ----------------------------------


func _slot_for(item_slot: int) -> StringName:
	match item_slot:
		ItemDef.Slot.WEAPON:
			return SLOT_WEAPON
		ItemDef.Slot.ARMOR:
			return SLOT_ARMOR
		_:
			return &""


func _apply_item_affixes(instance: ItemInstance) -> void:
	for a: AffixRoll in instance.rolled_affixes:
		if a == null or a.def == null:
			continue
		_apply_single_affix(a)


func _reverse_item_affixes(instance: ItemInstance) -> void:
	for a: AffixRoll in instance.rolled_affixes:
		if a == null or a.def == null:
			continue
		_reverse_single_affix(a)


func _apply_single_affix(roll: AffixRoll) -> void:
	var stat: StringName = roll.def.stat_modified
	var v: float = roll.rolled_value
	var mode: int = int(roll.def.apply_mode)
	# Stats handled by PlayerStats: vigor, focus, edge.
	if stat == &"vigor" or stat == &"focus" or stat == &"edge":
		var ps: Node = _player_stats_autoload()
		if ps != null:
			ps.apply_affix_modifier(stat, v, mode)
		return
	# Player-local stats.
	if stat == &"move_speed":
		if mode == AffixDef.ApplyMode.ADD:
			_move_speed_bonus += v
		else:
			# MUL on move_speed scales WALK_SPEED indirectly via
			# get_walk_speed (); we fold MUL into the bonus by computing
			# the equivalent flat ADD. Keeps M1 simple.
			_move_speed_bonus += WALK_SPEED * v
		return
	# Unknown stats: warn, ignore. (max_hp, crit_chance, etc. are M2 wiring.)
	push_warning("Player.equip_item: affix stat '%s' has no M1 hookup; ignoring" % stat)


func _reverse_single_affix(roll: AffixRoll) -> void:
	var stat: StringName = roll.def.stat_modified
	var v: float = roll.rolled_value
	var mode: int = int(roll.def.apply_mode)
	if stat == &"vigor" or stat == &"focus" or stat == &"edge":
		var ps: Node = _player_stats_autoload()
		if ps != null:
			ps.clear_affix_modifier(stat, v, mode)
		return
	if stat == &"move_speed":
		if mode == AffixDef.ApplyMode.ADD:
			_move_speed_bonus -= v
		else:
			_move_speed_bonus -= WALK_SPEED * v
		return
	# Unknown stats fell through silently on apply; same on reverse.


func _unequip_internal(slot: StringName, current: ItemInstance) -> void:
	_reverse_item_affixes(current)
	_equipped_items.erase(slot)
	if slot == SLOT_WEAPON:
		_equipped_weapon = null
		equipped_weapon_changed.emit(null)
	elif slot == SLOT_ARMOR:
		# Visible-equipment body-look seam — unequip reverts to the rags body.
		equipped_armor_changed.emit(null)


## Edge stat — read by Damage.compute_player_damage to scale weapon damage.
## Reads from the PlayerStats autoload (canonical source) when available;
## falls back to the legacy local `_edge` field for tests that bare-
## instantiate a Player without the autoload (or to honor an explicit
## set_stat call from a save-restore path that pre-dates PlayerStats).
func get_edge() -> int:
	var ps: Node = _player_stats_autoload()
	if ps != null:
		return int(ps.get_stat(&"edge"))
	return _edge


## Vigor stat — read by Damage.compute_mob_damage to mitigate incoming hits.
## See get_edge for the autoload-fallback pattern.
func get_vigor() -> int:
	var ps: Node = _player_stats_autoload()
	if ps != null:
		return int(ps.get_stat(&"vigor"))
	return _vigor


## Focus stat — currently unused by the damage formula but tracked here so
## the level-up allocation flow has a single home for V/F/E.
func get_focus() -> int:
	var ps: Node = _player_stats_autoload()
	if ps != null:
		return int(ps.get_stat(&"focus"))
	return _focus


## Take damage from a hitbox. Duck-typed contract matched by `Hitbox.gd`
## (`target.take_damage(amount, knockback, source)`).
##
## - Damage during STATE_DODGE i-frames is also blocked at the physics layer
##   (Player.gd::_enter_iframes clears collision_layer), but we belt-and-
##   suspender the case here too: if a manual `_try_apply_hit` is invoked
##   during dodge (test or scripted hit), we honor the i-frame state.
## - Damage during the dead state is ignored (idempotent).
## - Negative amounts clamp to 0 (no incidental healing via hitbox bug).
## - When HP hits zero, `player_died` emits exactly once and `_is_dead`
##   latches. Owning controller (Main.gd) subscribes to player_died and
##   drives the death/respawn flow per the M1 death rule.
func take_damage(amount: int, knockback: Vector2, source: Node) -> void:
	if _is_dead:
		return
	if _is_invulnerable:
		return
	var clean_amount: int = max(0, amount)
	if clean_amount == 0:
		return
	# Regen interrupt: any damage resets the damage-quiet timer immediately.
	# This must happen BEFORE hp_current changes so the regen tick this frame
	# uses the updated timer and correctly deactivates regen (AC-2 contract).
	# Synchronously flip is_regenerating off — waiting for the next _tick_regen
	# call would leave a one-frame "shimmer visible after damage taken" gap that
	# Sponsor would notice as a visual artifact (Tess CR feedback bug 1).
	_time_since_last_damage_taken = 0.0
	_set_regenerating(false)
	var hp_before: int = hp_current
	hp_current = max(0, hp_current - clean_amount)
	# Diagnostic trace — Player HP curve under multi-chaser damage. Used by
	# investigations of mid-combat Player death (e.g. ticket 86c9uf1x8 — Room
	# 05 multi-chaser death recurrence). Format mirrors mob `<Mob>.take_damage`
	# trace so harness post-mortem can correlate Player hits with mob hits on
	# the same combat-trace timeline. `src` is the source node's class name
	# when available (Charger / Grunt / Stratum1Boss / Hitbox), so a release-
	# build trace stream can attribute the lethal hit to a specific mob class
	# without further state inspection.
	var src_name: String = "Unknown"
	if source != null:
		if source.has_method("get_class"):
			src_name = source.get_class()
		# Prefer the actual script name when the source is a Hitbox spawned
		# by a mob (Hitbox.gd attaches an `owner_mob_class` if available).
		if "name" in source and source.name != "":
			src_name = String(source.name)
	_combat_trace(
		"Player.take_damage",
		(
			"amount=%d hp=%d->%d src=%s pos=(%.0f,%.0f)"
			% [clean_amount, hp_before, hp_current, src_name, global_position.x, global_position.y]
		)
	)
	damaged.emit(clean_amount, hp_current, source)
	hp_changed.emit(hp_current, hp_max)
	# M3W-2: play the hit anim + AnimatedSprite2D-modulate hit-flash on every
	# non-fatal damage event. The hit anim is one-shot per direction (loop=false
	# in Player.tres) so it plays once and the AnimatedSprite2D holds on the last
	# frame; the next state transition (state_changed → walk/attack/etc.) will
	# overwrite it. Skipped on fatal hit — `_die` plays `die_<dir>` instead.
	# Hit-flash is a sibling of the swing-flash modulate tween — both target
	# the AnimatedSprite2D (M3W-1 3-branch resolver shape).
	if hp_current > 0:
		_play_anim(ANIM_PREFIX_HIT)
		_play_hit_flash()
	# Knockback applied as instantaneous velocity bump. Decays naturally
	# next physics tick (the state machine resets velocity from input).
	if knockback.length_squared() > 0.0:
		velocity = knockback
	if hp_current == 0:
		_die()
		return  # death path consumes the frame; no iframes-on-hit on a corpse
	# Grant brief post-hit iframes to break simultaneous-hit clusters
	# (Uma's AC4 Room 05 balance pin §3.B). Skipped if the player is already
	# in STATE_DODGE — the dodge's i-frame window (DODGE_DURATION = 0.30s) is
	# strictly larger AND owned by the dodge end-condition; layering a 0.25s
	# hit-iframe timer over a still-running dodge could fire `_exit_iframes`
	# mid-dodge and clear `_is_invulnerable` while the dodge is still active.
	# `_exit_iframes_if_not_dodging` defends against that for the
	# dodge-began-AFTER-hit case; this guard handles the dodge-already-active
	# case at the entry point. See team/uma-ux/ac4-room05-balance-design.md.
	if _state == STATE_DODGE:
		return
	_enter_iframes()
	get_tree().create_timer(HIT_IFRAMES_SECS).timeout.connect(
		_exit_iframes_if_not_dodging, CONNECT_ONE_SHOT
	)


## Heal `amount` HP, clamped at hp_max. No-op while dead. Fires `hp_changed`.
## Used by HealingFountain + the respawn flow (full-heal on death-restart).
func heal(amount: int) -> void:
	if _is_dead:
		return
	if amount <= 0:
		return
	var before: int = hp_current
	hp_current = min(hp_max, hp_current + amount)
	if hp_current != before:
		hp_changed.emit(hp_current, hp_max)


## Direct setter — used by the save-load path to restore exact HP state.
## Clamps to [0, hp_max]. Does NOT fire `player_died` even if value is 0
## (the load path is already past the death-rule application).
func set_hp(value: int) -> void:
	hp_current = clamp(value, 0, hp_max)
	hp_changed.emit(hp_current, hp_max)


## Reset HP to full + clear the dead latch. Used by the respawn flow to
## recycle the same Player node OR by tests asserting clean state. Does
## NOT fire `player_died`; emits `hp_changed` for HUD listeners.
func revive_full_hp() -> void:
	_is_dead = false
	# Reset regen timers on respawn — a dead player's timers should not carry
	# into the next life and give instant free regen. The timers restart from 0.
	_time_since_last_damage_taken = 0.0
	_time_since_last_hit_landed = 0.0
	_regen_carry = 0.0
	_set_regenerating(false)
	hp_current = hp_max
	hp_changed.emit(hp_current, hp_max)


## Returns true if the player has died (HP hit zero this lifetime).
func is_dead() -> bool:
	return _is_dead


## Internal: drive the death-transition. Idempotent — emits player_died
## exactly once even under multi-hit collapse (if two enemy hitboxes
## land in the same frame, the second is short-circuited by `_is_dead`).
##
## **Diagnostic trace (ticket 86c9u397c — Drew investigation, 2026-05-15).**
## A `[combat-trace] Player._die` line is emitted at the start of the
## death-transition. **Without this line, a Player death + M1-death-rule
## room reload presents the EXACT same trace shape as a "mob freeze"** —
## mob `.pos` traces stop (because the mobs were freed by the room reload),
## the Player keeps swinging (because they respawned in Room 01 and the
## harness keeps clicking), and the player's pos jumps to `DEFAULT_PLAYER_SPAWN
## = (240, 200)` (the room-load teleport). The 86c9u397c brief mistook
## exactly this signature for a death-path physics-flush sibling-freeze
## bug because there was no Player-died trace to disambiguate. With this
## line, any future "mobs froze in Room N" investigation can rule out
## Player death in 1 second by grepping the trace stream for `Player._die`.
func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	# Cancel in-flight attack/dodge so a death-during-dodge doesn't leak
	# i-frames into the next life. We DON'T set state to a "dead" tag
	# (Player.gd has no STATE_DEAD constant — owning controller frees the
	# node anyway).
	_attack_recovery_left = 0.0
	_dodge_time_left = 0.0
	if _is_invulnerable:
		_exit_iframes()
	velocity = Vector2.ZERO
	_combat_trace(
		"Player._die",
		(
			"hp=0 pos=(%.0f,%.0f) — emitting player_died; M1 death rule will respawn in Room 01"
			% [global_position.x, global_position.y]
		)
	)
	# M3W-2: play the die anim on the AnimatedSprite2D. `_die` runs to completion
	# in the same frame the M1 death rule reloads Room 01, so the die anim may be
	# visually short-lived in the production flow — but for harness clips and
	# Sponsor-soak slow-mo it still reads as "the player crumpled, then the room
	# reloaded." loop=false in Player.tres means it holds on the last frame.
	_play_anim(ANIM_PREFIX_DIE)
	player_died.emit(global_position)


## Internal helper — fetch the Inventory autoload if it's registered.
## Returns null in bare-instantiated test contexts that don't register
## the autoload (most Player unit tests). Defensive lookup helper; callers
## must null-check the return. (The PR #146 boot-equip path that previously
## used this was retired in ticket 86c9qbb3k.)
func _find_inventory_autoload() -> Node:
	if not is_inside_tree():
		return null
	var loop: SceneTree = get_tree()
	if loop == null:
		return null
	return loop.root.get_node_or_null("Inventory")


## Internal helper — fetch the PlayerStats autoload if it's registered.
## Returns null inside bare-instantiated test contexts where the autoload
## hasn't been wired (existing tests construct a Player via `Player.new()`
## and configure stats via set_stat).
func _player_stats_autoload() -> Node:
	if not is_inside_tree():
		return null
	var loop: SceneTree = get_tree()
	if loop == null:
		return null
	return loop.root.get_node_or_null("PlayerStats")


## Set Vigor / Focus / Edge to an absolute value (e.g. when restoring from
## save). Negative values clamp to 0. Fires `stat_changed` if the value
## actually changes.
func set_stat(stat: StringName, value: int) -> void:
	var clean: int = max(0, value)
	match stat:
		&"vigor":
			if _vigor == clean:
				return
			_vigor = clean
		&"focus":
			if _focus == clean:
				return
			_focus = clean
		&"edge":
			if _edge == clean:
				return
			_edge = clean
		_:
			push_warning("Player.set_stat: unknown stat '%s'" % stat)
			return
	stat_changed.emit(stat, clean)


## Public state transitioner. Tests use it; gameplay should let the
## physics process drive transitions.
func set_state(new_state: StringName) -> void:
	if new_state == _state:
		return
	var old: StringName = _state
	_state = new_state
	state_changed.emit(old, new_state)


## Force-start a dodge in a given direction. Returns true if accepted.
## `dir` is normalised internally; if it's zero, dodge fires forward.
## Dodge interrupts attack recovery (intentional — gives player an out).
func try_dodge(dir: Vector2) -> bool:
	if not can_dodge():
		return false
	# Cancel any in-flight attack recovery so the dodge feels responsive.
	_attack_recovery_left = 0.0
	var d: Vector2 = dir.normalized() if dir.length_squared() > 0.0 else _facing
	_dodge_dir = d
	_facing = d
	_dodge_time_left = DODGE_DURATION
	_dodge_cooldown_left = DODGE_COOLDOWN
	# `dodge_started` fires ONLY here — after `can_dodge()` gating, before
	# `_enter_iframes` so the cue lands at the same instant as the i-frame
	# window opening (matches `audio-direction.md §AD-05` "frame 2 of 6 of
	# the dodge animation"). `iframes_started` fires inside `_enter_iframes`
	# below; both signals emit per intentional dodge, but only `dodge_started`
	# fires here. `take_damage`'s post-hit `_enter_iframes` call emits ONLY
	# `iframes_started`, not `dodge_started` — that's the bug-fix contract
	# from ticket 86c9vbhf1.
	dodge_started.emit()
	_enter_iframes()
	set_state(STATE_DODGE)
	return true


## Fire a light or heavy attack. Returns the spawned Hitbox node, or null
## if the attack was rejected (mid-dodge or in recovery). Direction is the
## intended hit direction; if zero, uses current facing.
func try_attack(kind: StringName, dir: Vector2 = Vector2.ZERO) -> Node:
	if not can_attack():
		_combat_trace(
			"Player.try_attack",
			"REJECTED kind=%s state=%s recovery=%.3f" % [kind, _state, _attack_recovery_left]
		)
		return null
	if kind != ATTACK_LIGHT and kind != ATTACK_HEAVY:
		push_warning("Player.try_attack: unknown kind '%s'" % kind)
		return null
	var d: Vector2 = dir.normalized() if dir.length_squared() > 0.0 else _facing
	_facing = d
	_combat_trace("Player.try_attack", "FIRED kind=%s facing=(%.1f,%.1f)" % [kind, d.x, d.y])

	# Damage routed through the formula utility. Reads equipped weapon +
	# Edge stat, returns floored int. Fist (no weapon) = 1 damage flat per
	# Damage.FIST_DAMAGE. Edge comes from the PlayerStats autoload when
	# available (falls back to the local `_edge` field for tests).
	var damage: int = DamageScript.compute_player_damage(_equipped_weapon, get_edge(), kind)
	var knockback_strength: float
	var reach: float
	var radius: float
	var lifetime: float
	var recovery: float
	if kind == ATTACK_LIGHT:
		knockback_strength = LIGHT_KNOCKBACK
		reach = LIGHT_REACH
		radius = LIGHT_HITBOX_RADIUS
		lifetime = LIGHT_HITBOX_LIFETIME
		recovery = LIGHT_RECOVERY
	else:
		knockback_strength = HEAVY_KNOCKBACK
		reach = HEAVY_REACH
		radius = HEAVY_HITBOX_RADIUS
		lifetime = HEAVY_HITBOX_LIFETIME
		recovery = HEAVY_RECOVERY

	var hitbox: Hitbox = _spawn_hitbox(d, damage, d * knockback_strength, reach, radius, lifetime)
	_attack_recovery_left = recovery
	# M3W-2: remember the attack kind BEFORE `set_state` fires `state_changed`
	# so the animation resolver picks `attack_light_<dir>` vs `attack_heavy_<dir>`.
	_current_attack_kind = kind
	set_state(STATE_ATTACK)

	# Visual-feedback cues per `team/uma-ux/combat-visual-feedback.md` §1:
	# (a) ember directional wedge sized to the actual hitbox numbers, fades
	#     out over the hitbox-lifetime window;
	# (b) 60ms ember-tint modulate flash on the player.
	# Spec §1 explicitly derives every number from the LIGHT/HEAVY tuning
	# constants above — no priors, no "typical action-game" reasoning.
	_spawn_swing_wedge(kind, d, reach, radius, lifetime)
	_play_swing_flash()

	_combat_trace("Player.try_attack", "POST damage=%d hitbox=%s" % [damage, hitbox])
	attack_spawned.emit(kind, hitbox)
	return hitbox


## Combat-trace shim — routes through DebugFlags.combat_trace (HTML5-only).
## Inlined here so the Player has no autoload-fallback footgun in tests that
## bare-instance a Player without the autoload registered.
func _combat_trace(tag: String, msg: String = "") -> void:
	var df: Node = null
	if is_inside_tree():
		df = get_tree().root.get_node_or_null("DebugFlags")
	if df != null and df.has_method("combat_trace"):
		df.combat_trace(tag, msg)


# ---- M3W-7 audio-cue handlers ----------------------------------------


## Resolve the AudioDirector autoload, or null in a bare-instanced test
## context where no autoloads are registered. Mirrors the look-up convention
## used by `_combat_trace` above — defensive against test stubs.
func _resolve_audio_director() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("AudioDirector")


## attack_spawned → SFX_PLAYER_ATTACK_LIGHT or SFX_PLAYER_ATTACK_HEAVY.
## Branches on `kind` to pick the matching cue. The `kind` arg is
## ATTACK_LIGHT or ATTACK_HEAVY — same StringName the test bar already pins.
func _on_attack_spawned_audio(kind: StringName, _hitbox: Node) -> void:
	var ad: Node = _resolve_audio_director()
	if ad == null or not ad.has_method("play_sfx"):
		return
	if kind == ATTACK_LIGHT:
		ad.play_sfx(&"sfx-player-attack-light")
	elif kind == ATTACK_HEAVY:
		ad.play_sfx(&"sfx-player-attack-heavy")


## damaged → SFX_PLAYER_HIT. Only fires when amount > 0 (i-frame absorbs,
## post-hit-iframes wholly-blocked hits, etc. emit damaged(0, ...) — those
## should NOT trigger a hit-cue, matching the visual-flash short-circuit in
## `take_damage`).
func _on_damaged_audio(amount: int, _hp_remaining: int, _source: Node) -> void:
	if amount <= 0:
		return
	var ad: Node = _resolve_audio_director()
	if ad == null or not ad.has_method("play_sfx"):
		return
	ad.play_sfx(&"sfx-player-hit")


## dodge_started → SFX_PLAYER_DODGE. Fires at dodge-roll i-frame window
## start (frame 2 of 6 per `audio-direction.md §AD-05` spec) — same instant
## the cloth-whoosh should land. **Was `iframes_started` pre-ticket
## 86c9vbhf1** — but `iframes_started` ALSO fires from `take_damage`'s
## post-hit invuln grant (Uma's AC4 Room 05 balance pin §3.B), which means
## every damage taken produced a whoosh. AD-05 is "intentional dodge ONLY";
## `dodge_started` is the dodge-exclusive signal that satisfies it.
func _on_dodge_started_audio() -> void:
	var ad: Node = _resolve_audio_director()
	if ad == null or not ad.has_method("play_sfx"):
		return
	ad.play_sfx(&"sfx-player-dodge")


# ---- State handlers -----------------------------------------------------


func _process_grounded(_delta: float) -> void:
	var input_dir: Vector2 = _read_movement_input()
	var sprinting: bool = Input.is_action_pressed("sprint")

	# Mouse-direction attacks (ticket 86c9uthf0): WASD drives velocity ONLY.
	# `_facing` is mouse-derived in `_update_mouse_facing` so the player can
	# walk one direction while aiming another (Hades/Diablo convention).
	if input_dir.length_squared() > 0.0:
		var speed: float = get_walk_speed() * (SPRINT_MULTIPLIER if sprinting else 1.0)
		velocity = input_dir * speed
		set_state(STATE_WALK)
	else:
		velocity = Vector2.ZERO
		set_state(STATE_IDLE)

	# Dodge still consumes input_dir (movement-direction dodge by design — the
	# dodge feels weird if you press W and dodge backwards toward the mouse).
	# Attacks pass Vector2.ZERO so try_attack uses the mouse-derived `_facing`.
	#
	# **Modal-input-gate** (ticket 86c9xxg0n — Sponsor's Option A; generalized
	# from the dialogue-only seed in 86c9xuab3 / PR #319). When ANY modal UI
	# surface is active (DialogueController session OR InventoryPanel open),
	# attack + dodge input must be suppressed — otherwise the player can swing
	# through a conversation or fire a swing when clicking an inventory cell
	# (Godot 4 Control event consumption does NOT block `Input.is_action_*`
	# polling in the same frame, so LMB on a Button still trips attack_light
	# from _process_grounded). Movement is intentionally NOT gated (Diablo
	# convention — player can WASD-walk while a panel is open; only attack/
	# dodge are suppressed). Future modals (Quest log, Settings) plug into the
	# `_modal_is_active()` union by adding a single check there.
	if _modal_is_active():
		return
	if Input.is_action_just_pressed("dodge"):
		try_dodge(input_dir)
	elif Input.is_action_just_pressed("attack_light"):
		try_attack(ATTACK_LIGHT, Vector2.ZERO)
	elif Input.is_action_just_pressed("attack_heavy"):
		try_attack(ATTACK_HEAVY, Vector2.ZERO)


## Returns true when ANY modal UI surface is currently active — DialogueController
## session OR InventoryPanel open. The production input-gate predicate (ticket
## 86c9xxg0n — Sponsor's Option A; generalizes the dialogue-only seed from
## ticket 86c9xuab3 / PR #319). Future modals (Quest log, Settings) plug in by
## adding a single OR clause here. Returns false when no autoload / scene-instance
## is reachable (bare-instanced test contexts) — safe default.
func _modal_is_active() -> bool:
	return _dialogue_is_active() or _inventory_is_open()


## Returns true when a DialogueController session is currently open. Component
## of `_modal_is_active()`. Kept as a named helper so `test_dialogue_panel.gd`
## can pin the dialogue-surface invariant independently. Returns false when the
## DialogueController autoload is missing (bare-instanced test contexts).
func _dialogue_is_active() -> bool:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return false
	var dc: Node = loop.root.get_node_or_null("DialogueController")
	if dc == null:
		return false
	if not dc.has_method("is_active"):
		return false
	return dc.is_active()


## Returns true when an `InventoryPanel` is registered in the "inventory_panel"
## SceneTree group AND its `is_open()` returns true. Component of
## `_modal_is_active()`. Lookup is via group (not Main.get_inventory_panel())
## so the predicate stays decoupled from `Main`'s scene shape — bare-instanced
## test contexts return false because no node is in the group. Safe default.
func _inventory_is_open() -> bool:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return false
	var panel: Node = loop.get_first_node_in_group("inventory_panel")
	if panel == null:
		return false
	if not panel.has_method("is_open"):
		return false
	return panel.is_open()


func _process_dodge(_delta: float) -> void:
	velocity = _dodge_dir * DODGE_SPEED
	if _dodge_time_left <= 0.0:
		_exit_dodge()


func _process_attack(_delta: float) -> void:
	# Player can still drift slowly during attack recovery — feels weighted
	# rather than rooted. Half walk speed (affix-modified).
	var input_dir: Vector2 = _read_movement_input()
	velocity = input_dir * (get_walk_speed() * 0.5)
	if _attack_recovery_left <= 0.0:
		set_state(STATE_IDLE)
	# Dodge can interrupt recovery.
	if Input.is_action_just_pressed("dodge"):
		try_dodge(input_dir)


# ---- Mouse-direction facing (ticket 86c9uthf0) -----------------------------


## Per-frame facing update from the mouse cursor. Gated by state so the
## facing snapshots at swing-spawn / dodge-init time and does NOT continuously
## drift during attack-active or dodge-active frames (edge case 3 in the
## ticket brief). Sprite rotation is updated in lockstep with `_facing` —
## during a swing/dodge both the hitbox direction AND the body orientation
## are frozen at spawn, then both resume tracking the cursor when the state
## drops back to IDLE/WALK. State durations are short (300ms dodge, 180-400ms
## attack recovery), so the visual "lock" reads as a swing pose rather than
## a stuck sprite.
##
## Mouse-vector behaviour:
##   - `< MOUSE_FACING_DEADZONE_PX` (8 px): vector too short to normalise
##     stably; keep last `_facing`. Prevents jitter when the cursor is on
##     top of the player.
##   - Cursor off-canvas (HTML5): Godot's `get_global_mouse_position()`
##     returns the LAST observed cursor position. No special handling
##     needed — the value freezes at the boundary, so `_facing` stays
##     stable across the off-canvas window.
##
## Bare-instantiated test contexts: `is_inside_tree()` guards the viewport
## read so tests can construct a Player without a viewport.
func _update_mouse_facing() -> void:
	# State gate: facing snapshots at swing-spawn (try_attack) and dodge-init
	# (try_dodge). Mid-swing and mid-dodge, leave `_facing` alone — the swing
	# direction must not drift as the mouse moves during the active window.
	if _state == STATE_ATTACK or _state == STATE_DODGE:
		return
	if not is_inside_tree():
		return
	var mouse_global: Vector2 = get_global_mouse_position()
	_facing = _resolve_facing_from_mouse(mouse_global, global_position, _facing)
	_update_sprite_rotation()


## Pure helper extracted for unit-testability — given the mouse and player
## world positions plus the last facing, returns the new facing vector after
## applying the dead-zone. No viewport / tree dependency, so GUT tests can
## drive every edge case directly without mocking `get_global_mouse_position`.
##
## Invariants pinned by `tests/test_player_mouse_facing.gd`:
##   - Returns unit-length vector (`|return| == 1.0`) whenever the input
##     delta exceeds the dead-zone.
##   - Returns the input `last_facing` unchanged inside the dead-zone.
##   - Exact-zero delta returns `last_facing` (no NaN from normalise(0)).
static func _resolve_facing_from_mouse(
	mouse_global: Vector2, self_global: Vector2, last_facing: Vector2
) -> Vector2:
	var delta: Vector2 = mouse_global - self_global
	if delta.length() < MOUSE_FACING_DEADZONE_PX:
		return last_facing
	return delta.normalized()


## Sprite node rotation — pinned to 0.0 by design (M3W-2 art-pass).
##
## **Rule: directional frames carry orientation; the AnimatedSprite2D node's
## `rotation` property must stay 0 across ALL states.** The Player's
## `AnimatedSprite2D` resolves a `<state>_<dir>` animation key via
## `_resolve_anim_dir` — each cardinal/diagonal direction has its own art —
## so rotating the node on top of that produces a double-rotation that reads
## as "the sprite is looking at the mouse cursor" (Sponsor's 2026-05-18 soak
## verbatim, the bounce-back finding on PR #274).
##
## Pre-M3 history: `Player.tscn`'s `Sprite` was a 16×16 ColorRect (symmetric
## square placeholder). Rotating it to `_facing.angle()` was visually a no-op
## but mechanically observable; it was kept as a forward-compat seam for an
## asymmetric sprite drop-in. The M3W-2 swap to AnimatedSprite2D + directional
## frames is that drop-in — and the answer to the seam is "per-direction
## frames", not "node rotation". This function is kept as the single
## documentation-bearing pin so a future change can't silently reintroduce
## a node-rotation source.
##
## See `.claude/docs/combat-architecture.md` §"Sprite-node topology, Seam 2:
## Player aim-rotation" — Resolution (PR #274, 2026-05-18) for the two-
## parallel-surfaces lesson: `_resolve_anim_dir` (animation name selection)
## AND this function (sprite-node rotation) had to be decoupled together.
func _update_sprite_rotation() -> void:
	var sprite: Node = get_node_or_null("Sprite")
	if sprite == null:
		return
	if not (sprite is CanvasItem):
		return
	# Pin to 0.0 — directional frames carry the orientation. The swing-wedge
	# (line 1307) rotates independently via its own `wedge.rotation = dir.angle()`
	# and is correctly scoped to `_spawn_swing_wedge`. _facing still drives
	# animation NAME selection via `_resolve_anim_dir`; the node TRANSFORM
	# must stay identity.
	(sprite as CanvasItem).rotation = 0.0


func _tick_timers(delta: float) -> void:
	if _dodge_time_left > 0.0:
		_dodge_time_left = max(0.0, _dodge_time_left - delta)
	if _dodge_cooldown_left > 0.0:
		_dodge_cooldown_left = max(0.0, _dodge_cooldown_left - delta)
	if _attack_recovery_left > 0.0:
		_attack_recovery_left = max(0.0, _attack_recovery_left - delta)
	# Regen timers always increment while alive (reset events drive them back
	# to 0 on damage-taken / hit-landed). No upper clamp needed — any value
	# above the threshold is equivalent.
	if not _is_dead:
		_time_since_last_damage_taken += delta
		_time_since_last_hit_landed += delta
	_tick_regen(delta)


## Regen tick — called from _tick_timers every physics frame.
## Activation: BOTH timers must exceed their thresholds AND hp < hp_max.
## Emits regen_active_changed on transitions (false→true, true→false).
func _tick_regen(delta: float) -> void:
	if _is_dead:
		_set_regenerating(false)
		return
	var should_regen: bool = (
		_time_since_last_damage_taken > REGEN_DAMAGE_COOLDOWN_SECS
		and _time_since_last_hit_landed > REGEN_ATTACK_COOLDOWN_SECS
		and hp_current < hp_max
	)
	if should_regen:
		_set_regenerating(true)
		var gained: float = REGEN_RATE_HP_PER_SEC * delta
		var new_hp: int = min(hp_max, hp_current + int(gained))
		# Use float accumulator to avoid losing fractional HP per frame.
		# Store the fractional carry so 2.0 HP/s isn't rounded to 1 HP/s.
		_regen_carry += gained - float(int(gained))
		if _regen_carry >= 1.0:
			new_hp = min(hp_max, new_hp + 1)
			_regen_carry -= 1.0
		if new_hp != hp_current:
			hp_current = new_hp
			hp_changed.emit(hp_current, hp_max)
			_combat_trace("Player", "regen tick (HP %d/%d)" % [hp_current, hp_max])
		# If we just hit cap, flip state off.
		if hp_current >= hp_max:
			_combat_trace("Player", "regen capped (HP %d/%d)" % [hp_current, hp_max])
			_set_regenerating(false)
	else:
		_set_regenerating(false)


func _set_regenerating(active: bool) -> void:
	if is_regenerating == active:
		return
	is_regenerating = active
	regen_active_changed.emit(active)
	if active:
		_combat_trace("Player", "regen activated (HP %d/%d)" % [hp_current, hp_max])
	else:
		_combat_trace("Player", "regen deactivated (HP %d/%d)" % [hp_current, hp_max])


func _exit_dodge() -> void:
	_exit_iframes()
	set_state(STATE_IDLE)


## **Re-entry guard (load-bearing — ticket 86c9uq0ky, Sponsor 2026-05-16 soak).**
##
## When this function runs while the player is ALREADY invulnerable, do NOT
## overwrite `_saved_collision_layer`. The current `collision_layer` at that
## point is the cleared value `0` (set by the prior `_enter_iframes` call),
## not the real player layer bit. Re-saving it would clobber the genuine
## restore value, and the subsequent `_exit_iframes` would restore the
## player to `collision_layer = 0` — permanently invisible to Pickup +
## StratumExit Area2D queries (mask=2 vs player-now-layer=0).
##
## **Empirical failure chain (without the guard)**, Sponsor diag `83267fd`:
##   1. Boss-combat hit → `take_damage` line 585 → `_enter_iframes` →
##      saves layer=2, clears to layer=0, arms HIT_IFRAMES_SECS timer
##      against `_exit_iframes_if_not_dodging`.
##   2. Player dodges DURING the hit-iframe window → `try_dodge` line 741 →
##      `_enter_iframes` AGAIN. Pre-fix this re-saved `_saved_collision_layer
##      = collision_layer = 0`. Layer-2 restore value LOST.
##   3. Hit-iframe timer fires → `_exit_iframes_if_not_dodging` → no-op
##      (state == STATE_DODGE).
##   4. Dodge ends → `_exit_dodge` → `_exit_iframes` → `collision_layer =
##      _saved_collision_layer = 0`. Trapped forever.
##
## Sponsor trace `[combat-trace] Player.coll_diag | pos=... layer=0 mask=1
## cs_disabled=false iframes=false` after boss death confirmed this exact
## end-state. Pickup (mask=2) + StratumExit body_entered never fire because
## the Player CharacterBody2D is on layer 0.
##
## Regression pin: `tests/test_player_collision_layer_restore.gd`.
func _enter_iframes() -> void:
	if _is_invulnerable:
		# Already in iframes — `_saved_collision_layer` already holds the
		# real (pre-iframe) layer; do NOT overwrite it with the cleared 0.
		# Idempotent on collision_layer too: already 0 from the prior call.
		_is_invulnerable = true  # explicit no-op for readability
		iframes_started.emit()
		return
	_is_invulnerable = true
	_saved_collision_layer = collision_layer
	# Drop the player layer bit so enemy hitboxes (mask: layer 2) miss us.
	# World collision is on collision_mask, untouched, so walls still block.
	collision_layer = 0
	iframes_started.emit()


func _exit_iframes() -> void:
	_is_invulnerable = false
	collision_layer = _saved_collision_layer
	iframes_ended.emit()


## Timer-callback companion to the post-hit iframe grant in `take_damage`
## (Uma's AC4 Room 05 balance pin §3.B). If a dodge began DURING the
## post-hit iframe window, the dodge's own `_exit_iframes` (called from
## `_exit_dodge` when `_dodge_time_left` expires in `_process`) owns the
## clear; we must not pre-empt it from the hit-iframe timer or we leave
## the player vulnerable while still visually dodging. The dodge-already-
## active-AT-hit case is handled at the entry point (`take_damage` skips
## the timer arm entirely when `_state == STATE_DODGE`).
func _exit_iframes_if_not_dodging() -> void:
	if _state == STATE_DODGE:
		return
	_exit_iframes()


# ---- Visual feedback ---------------------------------------------------


## Spawn the ember directional wedge (§1a in `combat-visual-feedback.md`).
## ColorRect parented to Player, oriented along `dir`, length = `reach`,
## width = `radius * 2` (full half-width on each side of the swing axis).
## Fade-out over `lifetime` then queue_free.
##
## Kill-and-restart: if a previous wedge from an earlier attack is still
## fading, free it before spawning the new one so the cues don't stack —
## matches Uma's hit-flash pattern in §2.
##
## **HTML5 fix (Bug A — Sponsor soak `embergrave-html5-f62991f`):** the
## original implementation used Polygon2D (3-vertex triangle) which spawned
## correctly (`tween_valid=true alpha=0.55` in the trace) but rendered
## invisible under `gl_compatibility` on the web canvas. ColorRect is the
## simplest, most-tested 2D primitive across every Godot 4 renderer mode and
## the spec explicitly allows either shape. Geometry shifted from triangle
## (single tip at +reach, base at radius half-width) to rectangle (full
## reach × full diameter). The wedge still reads as a directional sweep at
## M1 placeholder fidelity — the ColorRect mounts at the player center,
## extends `reach` px along the facing direction, and is `radius*2` px wide.
func _spawn_swing_wedge(
	kind: StringName, dir: Vector2, reach: float, radius: float, lifetime: float
) -> ColorRect:
	# Drop any in-flight wedge so the new attack's cue is the only one
	# visible. is_instance_valid covers the case where _on_wedge_finished
	# already nulled the ref but the queue_free hasn't been processed yet.
	if _active_swing_wedge != null and is_instance_valid(_active_swing_wedge):
		_active_swing_wedge.queue_free()
	_active_swing_wedge = null

	var wedge: ColorRect = ColorRect.new()
	# Layout: pivot at the player's local origin (0,0), the rectangle spans
	# from x=0 to x=reach along the facing axis, and y=-radius to y=+radius
	# perpendicular. Rotation pivots around (0,0) — the player center — so
	# the wedge always extends "out from the player" along `dir`.
	wedge.size = Vector2(reach, radius * 2.0)
	wedge.position = Vector2(0.0, -radius)
	wedge.pivot_offset = Vector2(0.0, radius)  # pivot at player local origin
	var alpha: float = SWING_WEDGE_ALPHA_HEAVY if kind == ATTACK_HEAVY else SWING_WEDGE_ALPHA_LIGHT
	var rgba: Color = SWING_WEDGE_COLOR_RGB
	rgba.a = alpha
	wedge.color = rgba
	# Rotate so the rectangle extends along `dir`. atan2(y, x) gives the
	# radian angle of the vector measured from +X.
	wedge.rotation = dir.angle()
	# Z-index per HTML5-safe contract (Bug A — see SWING_WEDGE_Z_INDEX
	# comment). +1 keeps the wedge in front of the player ColorRect so it's
	# always visible regardless of HTML5 z-stacking quirks.
	wedge.z_index = SWING_WEDGE_Z_INDEX
	# Don't intercept mouse clicks — this is a paint-only cue, not a UI element.
	wedge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Set lifetime as metadata so tests can read it back without inspecting
	# tween internals (Tween has no public elapsed-duration getter).
	wedge.set_meta("lifetime", lifetime)
	wedge.set_meta("kind", kind)
	# Geometry metadata so tests assert reach/radius like they did against
	# the old Polygon2D's `polygon` array.
	wedge.set_meta("reach", reach)
	wedge.set_meta("radius", radius)
	add_child(wedge)
	_active_swing_wedge = wedge
	swing_wedge_spawned.emit(kind, wedge)

	# Fade alpha to 0 over the hitbox-lifetime window, then queue_free. We
	# tween modulate.a (not color.a directly) so a parallel kill-and-restart
	# tween from a chained attack can swap colors mid-fade without resetting
	# the alpha-decay clock.
	var tween: Tween = create_tween()
	tween.tween_property(wedge, "modulate:a", 0.0, lifetime)
	# NOTE(86ca65gyv / Godot 4.6): bind the wedge's INSTANCE ID (an int), never
	# the node reference itself. The previous wedge is `queue_free`d the moment a
	# chained attack spawns a replacement (see `_spawn_swing_wedge` above), so by
	# the time this fade-tween's callback step runs the captured node may already
	# be freed. On 4.3 binding the freed Object marshalled fine; Godot 4.6
	# tightened both paths — a bound freed Object raises "Cannot convert argument
	# 1 from Object to Object", and a lambda-captured freed node raises "Lambda
	# capture ... was freed". An int instance-id has neither failure mode;
	# `_on_wedge_finished` resolves it via `instance_from_id` and no-ops if gone.
	tween.tween_callback(Callable(self, "_on_wedge_finished").bind(wedge.get_instance_id()))
	_combat_trace(
		"Player.swing_wedge",
		(
			"spawned kind=%s lifetime=%.3f tween_valid=%s alpha=%.2f"
			% [kind, lifetime, tween.is_valid(), rgba.a]
		)
	)
	return wedge


## Play the 60ms ember-tint modulate flash (§1b). 30ms toward
## `SWING_FLASH_TINT`, then 30ms back to white. Both attack types share
## this duration. Kill-and-restart on overlapping calls.
func _play_swing_flash() -> void:
	# Kill any in-flight flash so the new attack's tint is clean. If the
	# tween has already finished naturally, kill() is a safe no-op.
	if _active_flash_tween != null and _active_flash_tween.is_valid():
		_active_flash_tween.kill()
	# Force-snap to white so a kill-during-tint-down doesn't leave the
	# player a permanent ember color.
	modulate = Color(1.0, 1.0, 1.0, 1.0)

	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", SWING_FLASH_TINT, SWING_FLASH_HALF_DURATION)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), SWING_FLASH_HALF_DURATION)
	_active_flash_tween = tween
	_combat_trace(
		"Player.swing_flash",
		(
			"tween_valid=%s tint=(%.2f,%.2f,%.2f) duration=%.3f"
			% [
				tween.is_valid(),
				SWING_FLASH_TINT.r,
				SWING_FLASH_TINT.g,
				SWING_FLASH_TINT.b,
				SWING_FLASH_HALF_DURATION * 2.0
			]
		)
	)


## Internal: tween-finished callback for the swing wedge. Frees the node and
## clears the active reference (only if this exact wedge is still the
## active one — a newer attack may have already replaced it).
# Takes the wedge's INSTANCE ID (see `_spawn_swing_wedge` for the Godot 4.6
# marshalling rationale). Resolves via `instance_from_id` and no-ops if the
# wedge was already freed (the common chained-attack case).
func _on_wedge_finished(wedge_id: int) -> void:
	var obj: Object = instance_from_id(wedge_id)
	var rect := obj as ColorRect
	if not is_instance_valid(rect):
		return
	if _active_swing_wedge == rect:
		_active_swing_wedge = null
	rect.queue_free()


# ---- Hitbox spawn -------------------------------------------------------


func _spawn_hitbox(
	dir: Vector2, damage: int, knockback: Vector2, reach: float, radius: float, lifetime: float
) -> Hitbox:
	var hitbox: Hitbox = HitboxScript.new()
	# Configure BEFORE adding to tree so _ready() reads correct values.
	hitbox.configure(damage, knockback, lifetime, Hitbox.TEAM_PLAYER, self)
	hitbox.position = dir * reach
	# Attach a CircleShape2D collider via CollisionShape2D child.
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	hitbox.add_child(shape)
	add_child(hitbox)
	# Wire hit-landed interrupt for the regen system: any successful hit by the
	# player resets the attack-quiet timer to 0. `hit_target` fires from
	# Hitbox._try_apply_hit when a hit resolves — exactly the "hit landed"
	# moment Uma's spec defines. Per AC-3: regen cannot resume until
	# REGEN_ATTACK_COOLDOWN_SECS have passed with no successful hits.
	if not hitbox.hit_target.is_connected(_on_hitbox_hit_target):
		hitbox.hit_target.connect(_on_hitbox_hit_target)
	return hitbox


## Callback: a player-team hitbox landed a hit. Resets the attack-quiet timer
## so out-of-combat regen cannot activate while the player is still attacking.
## Per Uma's spec §"Activation rule" — "hit_landed > 3.0s means one attack burst
## is safe to finish before the regen timer starts ticking."
##
## Synchronously flips is_regenerating off — same rationale as take_damage: a
## one-frame "shimmer-after-hit" gap would be a Sponsor-visible artifact
## (Tess CR feedback bug 1).
func _on_hitbox_hit_target(_target: Node, _damage: int, _source: Node) -> void:
	_time_since_last_hit_landed = 0.0
	_set_regenerating(false)


# ---- Input --------------------------------------------------------------


func _read_movement_input() -> Vector2:
	# Input.get_vector handles 8-direction normalisation cleanly.
	var v: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# get_vector already normalises diagonals to length 1.0, so the player
	# doesn't move sqrt(2)x faster diagonally. Belt-and-suspenders:
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v


# ---- M3W-2 AnimatedSprite2D wiring -------------------------------------
# Per `team/priya-pl/m3-scene-wiring-scope.md §M3W-2` + the M3W-1 (PR #271)
# inheritance contract. Mirrors the PracticeDummy.gd 3-branch hit-flash
# resolver shape and the `_play_anim` helper shape.


## 8-octant facing quantizer. Returns one of `n / ne / e / se / s / sw / w / nw`
## from a Vector2 facing direction. Uses the angle in radians from +X axis
## (Vector2.RIGHT), where angles wrap [-PI, PI]. In Godot's screen-space
## coordinate system, +Y is DOWN — so an angle of 0 = right (east), PI/2 =
## down (south), PI = left (west), -PI/2 = up (north). The 8 octants split
## the circle into PI/4 (45°) wedges; threshold edges chosen so each cardinal
## sits dead-center of its wedge (north = angle in (-5PI/8, -3PI/8], etc.).
##
## Pure helper (static) for unit-testability — GUT tests drive arbitrary
## facing vectors and assert the returned suffix without touching the
## scene-tree state. Returns lowercase to match the SpriteFrames anim-key
## convention (`walk_s`, `attack_light_ne`, ...).
##
## Invariants pinned by `tests/test_player_animation_wire.gd`:
##   - 8 cardinal vectors (Vector2.RIGHT, RIGHT+DOWN normalized, DOWN, ...)
##     return the matching suffix exactly (no spillover into adjacent octants).
##   - Zero vector returns the default "s" (south — Godot's UP convention).
##   - The 8 returned suffixes form a permutation of the canonical set.
static func dir_suffix_for_facing(facing: Vector2) -> String:
	if facing.length_squared() < 0.0001:
		return "s"  # default — caller should pre-filter, but defensive
	# atan2(y, x) gives angle from +X (east) measured counter-clockwise in
	# math-space — but Godot's +Y is DOWN (screen-space) so the geometric
	# orientation is flipped. Practical interpretation:
	#   angle ==  0       → +X (east)
	#   angle == +PI/2    → +Y (south, because Godot Y-down)
	#   angle == ±PI      → -X (west)
	#   angle == -PI/2    → -Y (north)
	var angle: float = facing.angle()  # [-PI, PI]
	# Discretise to 8 octants. Each octant spans PI/4 (45°). To center each
	# cardinal/diagonal at its octant midpoint, shift by PI/8 then divide.
	# Result is an int in [0, 7] indexing the canonical N→NE→E→SE→S→SW→W→NW
	# rotation around the compass.
	#
	# Compass mapping (Godot screen-space):
	#   bucket 0: east   (angle ≈ 0)
	#   bucket 1: south-east  (angle ≈ +PI/4)
	#   bucket 2: south  (angle ≈ +PI/2)
	#   bucket 3: south-west  (angle ≈ +3PI/4)
	#   bucket 4: west   (angle ≈ ±PI)
	#   bucket 5: north-west  (angle ≈ -3PI/4)
	#   bucket 6: north  (angle ≈ -PI/2)
	#   bucket 7: north-east  (angle ≈ -PI/4)
	var shifted: float = angle + PI / 8.0
	# fposmod over 2*PI keeps us in [0, 2*PI); divide by PI/4 = bucket size.
	var bucket: int = int(fposmod(shifted, TAU) / (PI / 4.0))
	match bucket:
		0:
			return "e"
		1:
			return "se"
		2:
			return "s"
		3:
			return "sw"
		4:
			return "w"
		5:
			return "nw"
		6:
			return "n"
		7:
			return "ne"
		_:
			return "s"  # unreachable; defensive


## State → anim-prefix resolver. STATE_IDLE + STATE_WALK both → `walk` (idle
## is "walk frame 0 hold" placeholder per Priya's brief — no dedicated idle
## anim in the #265 PixelLab batch). STATE_ATTACK splits on `_current_attack_kind`
## AND on the equipped weapon class (fist-punch vs 1H-swing) via
## `_resolve_attack_set` (visible-equipment-system §2 / §7 step 2).
func _anim_prefix_for_state(s: StringName) -> String:
	if s == STATE_IDLE or s == STATE_WALK:
		return ANIM_PREFIX_IDLE_AND_WALK
	if s == STATE_DODGE:
		return ANIM_PREFIX_DODGE
	if s == STATE_ATTACK:
		return _resolve_attack_set(_current_attack_kind)
	# Unknown state — defensive fallback to walk; downstream code never
	# transitions into a state outside the {idle,walk,dodge,attack} set.
	return ANIM_PREFIX_IDLE_AND_WALK


## Attack-SET selection by weapon class (visible-equipment-system §2 / §7 step 2).
## Reads the equipped weapon's `weapon_class`:
##   - FIST (no weapon equipped) → `attack_light` / `attack_heavy` (the existing
##     bare-fist punch set; M1/M2 behavior, unchanged).
##   - ONE_HAND_MELEE (`iron_sword`, censer-blade, …) → `attack_light_1h` /
##     `attack_heavy_1h` (the NEW 1H-swing set).
## Forward classes (2H/staff/ranged) fall through to the 1H prefixes for now —
## they have neither art nor a distinct prefix yet; when their swing sets ship,
## add their cases here. idle/walk/dodge/hit/die are NOT class-suffixed (§2).
##
## **Pre-art STUB fallback (load-bearing for `86ca56w4f`).** The `_1h` swing art
## does NOT exist yet — this is the gen-independent foundation. `_play_anim`
## detects a missing `<prefix>_<dir>` key and falls back to the FIST set (see
## `_fist_fallback_prefix`) so equipping a 1H weapon pre-art still plays the
## punch animation rather than no-op'ing the sprite. Once the swing art lands,
## the keys resolve and the swing plays with zero code change here.
func _resolve_attack_set(kind: StringName) -> String:
	var heavy: bool = kind == ATTACK_HEAVY
	var weapon: ItemDef = get_equipped_weapon()
	# FIST: no weapon equipped → the existing punch set.
	if weapon == null:
		return ANIM_PREFIX_ATTACK_HEAVY if heavy else ANIM_PREFIX_ATTACK_LIGHT
	# Any armed class → the 1H swing prefixes for M3 (the only authored armed
	# set). 2H/staff/ranged reuse these until their own sets ship.
	if weapon.weapon_class == ItemDef.WeaponClass.FIST:
		# Defensive: a `.tres` should never author FIST, but honor it if it does.
		return ANIM_PREFIX_ATTACK_HEAVY if heavy else ANIM_PREFIX_ATTACK_LIGHT
	return ANIM_PREFIX_ATTACK_HEAVY_1H if heavy else ANIM_PREFIX_ATTACK_LIGHT_1H


## Maps a 1H-swing attack prefix back to its FIST-set equivalent — the pre-art
## fallback target. Returns the input unchanged for any non-`_1h` prefix.
func _fist_fallback_prefix(prefix: String) -> String:
	if prefix == ANIM_PREFIX_ATTACK_LIGHT_1H:
		return ANIM_PREFIX_ATTACK_LIGHT
	if prefix == ANIM_PREFIX_ATTACK_HEAVY_1H:
		return ANIM_PREFIX_ATTACK_HEAVY
	return prefix


## state_changed signal handler — drive the AnimatedSprite2D into the right
## anim for the new state. Direction is resolved by `_resolve_anim_dir`:
## movement-states (WALK / IDLE) use the velocity octant (or last-held for
## IDLE); action-states (ATTACK / DODGE) use mouse-derived `_facing`.
##
## IDLE-vs-WALK detail: both prefixes resolve to `walk`, but for IDLE we want
## frame 0 to hold (no motion); for WALK we want the loop. Player.tres marks
## `walk_<dir>` with loop=true, so calling `play()` runs the cycle; for IDLE
## we additionally call `stop()` + set `frame=0` so the sprite freezes on the
## rest pose. The next state transition (IDLE → WALK) calls `play()` again
## which resumes the cycle from frame 0.
func _on_state_changed(_from_state: StringName, to_state: StringName) -> void:
	_play_anim_for_state(to_state)


## Public surface for state-driven anim playback. Resolves prefix from state
## + appends 8-octant dir suffix via `_resolve_anim_dir`. Used by
## `_on_state_changed` AND by `_ready` to seed the initial animation.
func _play_anim_for_state(s: StringName) -> void:
	var prefix: String = _anim_prefix_for_state(s)
	_play_anim(prefix)
	# IDLE special-case: freeze on frame 0 of `walk_<dir>` so the sprite shows
	# the rest pose rather than animating in place.
	if s == STATE_IDLE:
		if not _animated_sprite_resolved:
			_resolve_animated_sprite()
		if _animated_sprite != null:
			_animated_sprite.stop()
			_animated_sprite.frame = 0


## Play an animation on the AnimatedSprite2D child. Lazy-resolves the child
## so bare-instanced test players (no scene-tree, no AnimatedSprite2D child)
## silently no-op. Animation key is `<prefix>_<dir>` where `<dir>` is
## resolved via `_resolve_anim_dir` (velocity octant for WALK/IDLE, `_facing`
## octant for ATTACK/DODGE/HIT/DIE — see Sponsor 2026-05-18 soak finding).
## No-op if the resolved key isn't in the SpriteFrames resource (e.g. tests
## that swap in their own AnimatedSprite2D without SpriteFrames).
##
## Mirrors `PracticeDummy._play_anim` shape (M3W-1 inheritance contract).
func _play_anim(prefix: String) -> void:
	if not _animated_sprite_resolved:
		_resolve_animated_sprite()
	if _animated_sprite == null:
		return
	if _animated_sprite.sprite_frames == null:
		return
	var dir_suffix: String = _resolve_anim_dir(prefix)
	var anim_name: StringName = StringName("%s_%s" % [prefix, dir_suffix])
	if not _animated_sprite.sprite_frames.has_animation(anim_name):
		# Pre-art STUB fallback (visible-equipment-system §7 step 2, ticket
		# 86ca56w4f). The 1H swing art does not exist yet — when a `_1h` key is
		# absent, fall back to the FIST set so equipping a 1H weapon still plays
		# the punch animation rather than leaving the sprite on a stale frame.
		var fist_prefix: String = _fist_fallback_prefix(prefix)
		if fist_prefix != prefix:
			var fb_name: StringName = StringName("%s_%s" % [fist_prefix, dir_suffix])
			if _animated_sprite.sprite_frames.has_animation(fb_name):
				_animated_sprite.play(fb_name)
				_combat_trace(
					"Player._play_anim",
					(
						"PLAY anim=%s (1H-stub fallback from %s — swing art absent)"
						% [fb_name, anim_name]
					)
				)
				return
		_combat_trace(
			"Player._play_anim", "MISS anim=%s — SpriteFrames lacks this animation key" % anim_name
		)
		return
	_animated_sprite.play(anim_name)
	_combat_trace("Player._play_anim", "PLAY anim=%s" % anim_name)


## Resolve animation direction suffix for the given anim prefix.
##
## **Decouple animation direction from aim direction** (Sponsor 2026-05-18
## soak finding on PR #274). `_facing` is mouse-derived (PR #255) — correct
## for attack/dodge aim, wrong for walk feel. Pre-fix the body pivoted toward
## the cursor while strafing sideways ("looking at the mouse cursor while
## walking is weird").
##
## Resolution table:
##   - `walk` (STATE_WALK or STATE_IDLE) → velocity octant if moving, else
##     `_last_anim_dir` (held-from-last-WALK). At IDLE entry velocity is
##     `Vector2.ZERO` (set by `_process_grounded`), so this is the held case.
##   - `attack_light` / `attack_heavy` / `dodge` / `hit` / `die` → `_facing`
##     octant (mouse-derived, preserves PR #255 attack-aim contract AND the
##     hit/die threat-direction wash).
##
## `_last_anim_dir` is mutated by this function as a side effect — every WALK
## resolution that produces a fresh octant updates the held value so the next
## IDLE entry sees the correct direction. Walk-then-stop holds the last walk
## direction (not the cursor); walk-then-turn-while-walking re-resolves
## per-frame via `_drive_walk_anim_if_moving`.
##
## Pure-ish: depends on `velocity` + `_facing` + `_last_anim_dir`; mutates
## `_last_anim_dir`. Static-helper extraction is not viable here because the
## mutation is load-bearing for the IDLE-holds-last semantics. The math
## (`dir_suffix_for_facing`) is the static-helper surface and remains
## unit-testable independently.
func _resolve_anim_dir(prefix: String) -> String:
	if prefix == ANIM_PREFIX_IDLE_AND_WALK:
		# WALK/IDLE share the `walk` prefix. Use velocity if moving; else hold
		# the last walk direction (don't snap to cursor on idle).
		if velocity.length() > VELOCITY_OCTANT_THRESHOLD:
			var v_dir: String = dir_suffix_for_facing(velocity)
			_last_anim_dir = v_dir
			return v_dir
		return _last_anim_dir
	# ATTACK / DODGE / HIT / DIE — face the cursor (PR #255 contract).
	return dir_suffix_for_facing(_facing)


## Re-drive the WALK animation when the velocity octant changes mid-state.
## Called from `_physics_process` after the state-dispatch + `move_and_slide`.
##
## Why this is needed: `state_changed` fires only on STATE transitions, so a
## player who stays in STATE_WALK while changing WASD direction (W → D) would
## otherwise keep playing `walk_n` forever because no transition would fire.
## This function re-resolves the anim direction each physics frame and calls
## `play()` only when the resolved anim_name DIFFERS from the currently-
## playing anim — avoiding a per-frame `play()` restart that would freeze
## the sprite on frame 0 of the loop.
##
## STATE_WALK only. STATE_IDLE / ATTACK / DODGE all hold their direction by
## design (idle keeps last walk dir; attack/dodge snapshot facing at entry).
func _drive_walk_anim_if_moving() -> void:
	if _state != STATE_WALK:
		return
	if not _animated_sprite_resolved:
		_resolve_animated_sprite()
	if _animated_sprite == null:
		return
	if _animated_sprite.sprite_frames == null:
		return
	if velocity.length() <= VELOCITY_OCTANT_THRESHOLD:
		return
	var v_dir: String = dir_suffix_for_facing(velocity)
	if v_dir == _last_anim_dir:
		# Same octant — animation is already correct. Do NOT re-play (would
		# restart the loop and freeze the cycle on frame 0 every physics tick).
		return
	_last_anim_dir = v_dir
	var anim_name: StringName = StringName("%s_%s" % [ANIM_PREFIX_IDLE_AND_WALK, v_dir])
	if not _animated_sprite.sprite_frames.has_animation(anim_name):
		return
	_animated_sprite.play(anim_name)
	_combat_trace("Player._play_anim", "PLAY anim=%s (walk-dir-change)" % anim_name)


## Lazy AnimatedSprite2D resolver. Idempotent; subsequent calls are no-ops
## after the first.
func _resolve_animated_sprite() -> void:
	if _animated_sprite_resolved:
		return
	var sprite: Node = get_node_or_null("Sprite")
	if sprite is AnimatedSprite2D:
		_animated_sprite = sprite
	_animated_sprite_resolved = true


## Hit-flash modulate tween — fires from `take_damage` on every non-fatal
## hit. 3-branch resolver mirrors PracticeDummy.gd (M3W-1 inheritance):
##
##   1. AnimatedSprite2D — tween Sprite.modulate to HIT_FLASH_TINT and back
##      (soft red wash on the painted sprite frames).
##   2. ColorRect — tween Sprite.color rest → white → rest (legacy fallback;
##      pre-M3W-2 Player.tscn used this — kept for back-compat with any
##      test that swaps in a ColorRect Sprite).
##   3. No Sprite child — tween self.modulate (bare-instanced test fallback;
##      preserves Tier 1 reference-change invariant in GUT).
##
## Kill-and-restart on overlapping calls. Tier 1 reference-change invariant
## (per `.claude/docs/test-conventions.md`) — a second hit during the flash
## kills the in-flight tween and creates a fresh one with a new reference.
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
	if not _captured_hit_flash_rest:
		_hit_flash_modulate_at_rest = modulate
		_captured_hit_flash_rest = true
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	if not is_inside_tree():
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
			"Player._play_hit_flash",
			(
				"animated_sprite tween_valid=%s tint=(%.2f,%.2f,%.2f)"
				% [
					_hit_flash_tween.is_valid(),
					HIT_FLASH_TINT.r,
					HIT_FLASH_TINT.g,
					HIT_FLASH_TINT.b,
				]
			)
		)
	elif _hit_flash_uses_sprite:
		var sprite_rect: ColorRect = _hit_flash_target as ColorRect
		_hit_flash_tween.tween_property(sprite_rect, "color", Color(1, 1, 1, 1), HIT_FLASH_IN)
		_hit_flash_tween.tween_property(sprite_rect, "color", Color(1, 1, 1, 1), HIT_FLASH_HOLD)
		_hit_flash_tween.tween_property(sprite_rect, "color", _sprite_color_at_rest, HIT_FLASH_OUT)
		_combat_trace(
			"Player._play_hit_flash", "sprite tween_valid=%s" % _hit_flash_tween.is_valid()
		)
	else:
		_hit_flash_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), HIT_FLASH_IN)
		_hit_flash_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), HIT_FLASH_HOLD)
		_hit_flash_tween.tween_property(
			self, "modulate", _hit_flash_modulate_at_rest, HIT_FLASH_OUT
		)
		_combat_trace(
			"Player._play_hit_flash",
			"modulate-fallback tween_valid=%s" % _hit_flash_tween.is_valid()
		)


# ---- Visible-equipment foundation (ticket 86ca56w4f) -------------------
# §7 steps 3-5: weapon-overlay node lifecycle + show/hide-on-equip + the
# armor-tier body-look SpriteFrames swap seam. All STUB-level: the overlay
# carries no texture and the armor-body map is empty until the pilot art lands
# (§5.3 steps 2-3). The WIRING is complete + tested here so the art drop is a
# data-only change. Cross-ref `team/uma-ux/visible-equipment-system.md`.


## Create the LAYER 2 weapon-overlay Sprite2D as a sibling of the body
## `Sprite` (child of Player, NOT child of the AnimatedSprite2D), z=1, hidden.
## Idempotent — resolves an existing scene-authored "WeaponHand" first, only
## creating one when absent (so a future `.tscn` that authors it wins). No-op
## texture/anchor: those land with the swing-art pilot (§3 anchor table).
func _ensure_weapon_hand_overlay() -> void:
	if _weapon_hand != null:
		return
	var existing: Node = get_node_or_null(NodePath(String(WEAPON_HAND_NODE_NAME)))
	if existing is Sprite2D:
		_weapon_hand = existing
	else:
		_weapon_hand = Sprite2D.new()
		_weapon_hand.name = WEAPON_HAND_NODE_NAME
		_weapon_hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_weapon_hand)
	_weapon_hand.z_index = WEAPON_HAND_Z_INDEX
	# Unarmed at boot — overlay starts hidden; `_on_equipped_weapon_changed`
	# (seeded in `_ready`) is the authority for visibility thereafter.
	_weapon_hand.visible = false


## Returns the weapon-overlay node (creating it if needed). Test surface.
func get_weapon_hand_overlay() -> Sprite2D:
	if _weapon_hand == null:
		_ensure_weapon_hand_overlay()
	return _weapon_hand


## equipped_weapon_changed handler (§7 step 4). Shows/hides the WeaponHand
## overlay (null weapon → hidden = unarmed) and stub-reads the overlay sprite
## + anchor for the equipped weapon's class/id. The texture set + anchor-table
## read are STUBBED to no-ops (no overlay art yet); the show/hide + the
## attack-SET selection (which reads the weapon class on the NEXT attack via
## `_resolve_attack_set`) are the live wiring.
func _on_equipped_weapon_changed(weapon) -> void:
	if _weapon_hand == null:
		_ensure_weapon_hand_overlay()
	if _weapon_hand == null:
		return
	if weapon == null:
		_weapon_hand.visible = false
		_combat_trace("Player.equip_overlay", "hide WeaponHand (unarmed)")
		return
	# Armed: reveal the overlay. Texture + per-direction anchor (Mechanism B,
	# §3) are read-STUBS here — populated when the weapon-overlay art + anchor
	# table ship (§5.3 step 2). The overlay stays a positioned-but-empty node
	# until then, which is intentional: nothing renders, nothing breaks.
	_weapon_hand.visible = true
	var wclass: int = -1
	if weapon is ItemDef:
		wclass = int((weapon as ItemDef).weapon_class)
	_combat_trace(
		"Player.equip_overlay",
		"show WeaponHand class=%d (overlay art + anchor stubbed — pre-art)" % wclass
	)


## equipped_armor_changed handler (§7 step 5). Swaps the body SpriteFrames to
## the equipped armor tier's body look. STUB: `_armor_body_frames_by_tier` is
## empty (no armor bodies yet), so this resolves to a no-op for every tier in
## the foundation PR — but the swap MECHANISM (resolve frames → swap → replay
## state → invalidate hit-flash cache) is wired + tested so the art drop is a
## map-population-only change.
func _on_equipped_armor_changed(armor) -> void:
	var tier: int = -1  # -1 = rags (no armor / unequipped)
	if armor is ItemDef:
		tier = int((armor as ItemDef).tier)
	_apply_armor_body_look(tier)


## Apply the armor-tier body look by swapping the body AnimatedSprite2D's
## SpriteFrames resource. `tier == -1` means rags (no armor). Guarded no-op
## when the tier has no registered body frames (the current STUB state — every
## tier is unregistered). When a tier's frames ARE registered, the swap:
##   1. points `Sprite.sprite_frames` at the tier body (silhouette change),
##   2. invalidates the cached `_hit_flash_target` so the next hit re-resolves
##      against the new SpriteFrames node (Drew-flagged edge, §5 #5 — the
##      cache holds the NODE, which survives a frames swap, but the rest-color
##      snapshot must be re-captured against the new resource),
##   3. replays the current state's animation so the new body shows the right
##      pose immediately instead of holding a stale frame.
func _apply_armor_body_look(tier: int) -> void:
	if not _armor_body_frames_by_tier.has(tier):
		# STUB / rags / unregistered tier — nothing to swap. No-op.
		return
	var frames: SpriteFrames = _armor_body_frames_by_tier[tier] as SpriteFrames
	if frames == null:
		return
	if not _animated_sprite_resolved:
		_resolve_animated_sprite()
	if _animated_sprite == null:
		return
	_animated_sprite.sprite_frames = frames
	# Invalidate the hit-flash target cache so the next hit re-resolves the
	# rest-color snapshot against the swapped SpriteFrames (the cache pins the
	# NODE — which is unchanged — but `_sprite_modulate_at_rest` was captured
	# from the OLD frames' modulate and must be re-read).
	_invalidate_hit_flash_target_cache()
	# Replay the current state so the new body shows the correct pose now.
	_play_anim_for_state(_state)
	_combat_trace("Player.armor_body", "swapped body SpriteFrames for tier=%d" % tier)


## Clear the cached hit-flash target so the next `_play_hit_flash` re-resolves
## it (used after a body SpriteFrames swap — §5 #5 Drew-flagged edge). The
## cache normally resolves once on first hit; a mid-life body swap requires a
## re-resolve so the rest-color snapshot matches the live frames.
func _invalidate_hit_flash_target_cache() -> void:
	_hit_flash_target = null
	_hit_flash_uses_sprite = false
	_hit_flash_uses_animated_sprite = false


# ---- M3 Tier 3 W2 quest persistence I/O (ticket 86c9y7ydg / W2-T6) --------
##
## Symmetric `to_save_dict` / `restore_from_save_dict` for the `active_bounty`
## + `completed_bounties` fields. Save.gd writes/reads these into
## `data.character.active_bounty` (Dictionary or null) and
## `data.character.completed_bounties` (Array[String]).
##
## **Why on Player.gd (not PlayerStats.gd)** — these are quest-system state,
## not stat-allocation state. PlayerStats owns V/F/E + unspent points; the
## bounty fields are conceptually closer to inventory/run-state. Adding the
## methods here matches the `restore_full_hp` / inventory restore precedent
## (Main reads `data.character.*` + dispatches to the right consumer).


## Serialise the player's quest state into a partial Dictionary for the
## save's `data.character` block. Caller (Save.gd / Main) merges the
## returned keys into the character payload alongside `stats` /
## `unspent_stat_points` / etc.
##
## Shape:
##   {
##     "active_bounty": <QuestState.to_dict()> or null,
##     "completed_bounties": Array[String],
##   }
##
## **`active_bounty` is null when no bounty is active** — the save layer
## persists the null verbatim (JSON nulls round-trip cleanly).
func to_save_dict() -> Dictionary:
	var out: Dictionary = {}
	if active_bounty is QuestState:
		out["active_bounty"] = (active_bounty as QuestState).to_dict()
	else:
		out["active_bounty"] = null
	# Stringify the completed_bounties array for JSON round-trip. The on-disk
	# shape is Array[String]; in-memory we accept either StringName or String
	# entries (QuestStateResolver._completed_contains normalises). Stringify
	# defensively so a save written from in-memory StringName entries round-
	# trips identically.
	var completed_strings: Array = []
	for entry in completed_bounties:
		completed_strings.append(String(entry))
	out["completed_bounties"] = completed_strings
	# W2-T5: world-map discovery state. JSON serialises StringName keys as
	# String; we stringify defensively at write time so the on-disk shape is
	# unambiguous (Dictionary[String, bool]). restore_from_save_dict() converts
	# back to StringName keys at read time.
	out["discovered_zones"] = _stringify_dict_keys(discovered_zones)
	out["discovered_waypoints"] = _stringify_dict_keys(discovered_waypoints)
	return out


## Coerce every key of a StringName-keyed Dict[bool] to plain String for
## JSON serialisation. The runtime accepts either StringName or String
## keys (Godot's Dictionary lookup is permissive), but the on-disk shape
## must be JSON-safe — JSON has no StringName, so unstringified keys would
## round-trip via the engine's StringName→String coercion non-explicitly.
## Explicit stringification keeps the on-disk shape diagnosable + matches
## the active_bounty / completed_bounties serialisation convention.
static func _stringify_dict_keys(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		out[String(k)] = d[k]
	return out


## Restore quest state from a `data.character` block. Tolerates missing
## sub-keys (Tier-3-naive saves backfilled by `Save._migrate_v4_to_v5`
## already supply defaults; this method's tolerance is belt-and-suspenders
## for hand-edited or partial-payload restore paths).
##
## Idempotent — calling twice with the same payload yields the same in-
## memory state. Does NOT emit signals (matches PlayerStats.restore_from_character
## convention — pure deserialisation).
func restore_from_save_dict(character: Dictionary) -> void:
	# active_bounty — null OR Dictionary (per QuestState.from_dict contract).
	# Missing key defaults to null (no active bounty).
	if character.has("active_bounty"):
		var ab_payload: Variant = character["active_bounty"]
		if ab_payload == null:
			active_bounty = null
		else:
			active_bounty = QuestState.from_dict(ab_payload)
			# QuestState.from_dict returns null on malformed payload; that's
			# the same shape as "no active bounty" so we treat it identically.
	else:
		active_bounty = null
	# completed_bounties — Array, defaults to empty. Defensive: convert
	# every entry to StringName for in-memory canonicalisation (matches
	# QuestStateResolver's comparison shape).
	completed_bounties = []
	if character.has("completed_bounties"):
		var arr: Variant = character["completed_bounties"]
		if arr is Array:
			for entry in arr as Array:
				completed_bounties.append(StringName(String(entry)))
	# W2-T5: world-map discovery state. JSON round-trips StringName keys as
	# String, so we normalise back to StringName at read time. Missing key
	# (tier-3-naive saves) defaults to empty {} — consumed by WorldMapPanel
	# rendering as "all zones undiscovered."
	discovered_zones = _normalise_dict_keys_to_stringname(character.get("discovered_zones", {}))
	discovered_waypoints = _normalise_dict_keys_to_stringname(
		character.get("discovered_waypoints", {})
	)


## Mirror of `_stringify_dict_keys` for the load side. Normalises keys so the
## in-memory dict is reachable via StringName lookups (the production access
## shape).
##
## **Godot 4.3 key-canonicalization note.** Godot 4.3 lacks typed `Dictionary[
## K, V]` syntax (verified via CI parse error "Only arrays can specify
## collection element types" — PR #362 fix attempt v1). An untyped Dictionary
## stores keys as TYPE_STRING when either a String or a StringName is inserted
## — the engine canonicalizes the two equivalent hash classes. Consequence:
## the in-memory key-type CANNOT be enforced as TYPE_STRING_NAME under Godot
## 4.3. **The contract is "lookup-equivalence," not "typeof-equivalence":**
## `out.has(&"x")` and `out.has("x")` both return true after this helper
## normalises a String-keyed JSON payload, even though `typeof(key)` reads
## back as TYPE_STRING for either insert path. Captured in `.claude/docs/
## test-conventions.md § "Godot 4.3 untyped-Dictionary key canonicalization"`.
## Tolerates missing entries (returns empty dict on non-Dictionary input).
static func _normalise_dict_keys_to_stringname(d: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (d is Dictionary):
		return out
	var src: Dictionary = d as Dictionary
	for k in src.keys():
		# Wrap as StringName at insert time so consumers reading the key via
		# `dict.keys()` see a value derived from the StringName path. Note:
		# under Godot 4.3 the dict canonicalises this to TYPE_STRING anyway
		# (no typed-Dict syntax to enforce StringName slot), but the wrap
		# matches the canonical access shape (production reads via
		# StringName-keyed lookups).
		out[StringName(String(k))] = bool(src[k])
	return out


## W2-T5: discovery write hook. Idempotent — re-entering an already-
## discovered zone is a no-op. The boolean return tells callers whether
## this was a NEW discovery (true) vs a re-entry (false), so Main.gd can
## fire the discovery `[combat-trace]` line only on transitions.
func mark_zone_discovered(zone_id: StringName) -> bool:
	if zone_id == &"":
		return false
	if discovered_zones.has(zone_id):
		return false
	discovered_zones[zone_id] = true
	return true


## Same shape as mark_zone_discovered, applied to waypoints. M3 W2 has no
## production caller (no waypoint surface yet); shipped now so W3+ /
## M4 waypoint surface has the hook in place without a save-schema bump.
func mark_waypoint_discovered(waypoint_id: StringName) -> bool:
	if waypoint_id == &"":
		return false
	if discovered_waypoints.has(waypoint_id):
		return false
	discovered_waypoints[waypoint_id] = true
	return true
