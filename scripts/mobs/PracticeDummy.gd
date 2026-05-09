class_name PracticeDummy
extends CharacterBody2D
## Stratum-1 Room01 tutorial practice dummy — a non-threatening target whose
## only purpose is to teach the LMB strike beat (Uma `player-journey.md`
## Beats 4-5). HP=3, deals zero damage, no AI, no swings; on death it
## ember-poofs and drops a guaranteed iron_sword pickup so the player walks
## into Room02 already equipped (Stage 2b design-correct path that retires
## the M1 RC PR #146 boot-equip bandaid).
##
## **Why a new class (not a Grunt subclass / not a BreakableObject):**
##   - Grunt carries chase/telegraph/heavy-attack/post-contact-pushback that
##     are dead weight on a stationary target — keeping them as no-ops would
##     leak AI invariants into a "tutorial decoration" entity. A clean class
##     keeps the tutorial path easy to read.
##   - BreakableObject (StaticBody2D) wouldn't share the `mob_died` signal
##     surface that `Main._on_room01_mob_died` + `Levels.subscribe_to_mob`
##     use; we'd need to fork the room-clear plumbing or add a parallel
##     signal. Cheaper to mirror the mob-class signal contract.
##   - We adopt CharacterBody2D + `MOTION_MODE_FLOATING` from day-one per
##     `.claude/docs/combat-architecture.md` § "CharacterBody2D motion_mode
##     rule" — Stratum1Boss PR #163's lesson that GROUNDED's up_direction
##     asymmetry bites every CharacterBody2D in a top-down 2D game. Even a
##     stationary dummy adopting FLOATING avoids the latent bug class.
##
## **Signal contract (matched to Grunt):**
##   - `mob_died(mob: Node, death_position: Vector2, mob_def: MobDef)` —
##     fires once on HP=0. `mob_def` is null because this entity has no
##     loot table or XP reward; it drops the iron_sword directly from
##     `_die` instead. Subscribers that gate on `mob_def != null` (notably
##     `MobLootSpawner.on_mob_died` and `Levels.subscribe_to_mob`) silently
##     no-op when the dummy dies, which is what we want — the dummy is
##     deliberately invisible to the standard XP/loot pipelines, while
##     still triggering room-clear via Main's mob-counter.
##   - `damaged(amount: int, hp_remaining: int, source: Node)` — fired on
##     each successful hit so tutorial-side listeners (e.g. dispatch the
##     `&"rmb_heavy"` beat on dummy-poof, see `Stratum1Room01.gd`) can
##     observe progress.
##
## **Drop convention:** the dummy spawns the iron_sword pickup synchronously
## but `add_child`s it via `call_deferred` to honor the Pickup-Area2D
## physics-flush rule (see `.claude/docs/combat-architecture.md` § "Physics
## flush rule"; this exact pattern is in `MobLootSpawner.on_mob_died`).
##
## **Layer convention** mirrors Grunt: collision_layer = enemy (bit 4),
## collision_mask = world (bit 1) + player (bit 2). The Player's swing
## hitbox lives on `player_hitbox` (bit 3) masking `enemy` (bit 4) — that's
## how the dummy takes damage (existing Hitbox layer plumbing, no special
## case needed).

# ---- Signals ------------------------------------------------------------

## Took damage. Emitted after HP is decremented but before death is checked.
signal damaged(amount: int, hp_remaining: int, source: Node)

## HP hit zero. Emitted exactly once per life. Mirrors Grunt's signature so
## room-clear / Levels listeners that duck-type on `mob_died` work without
## special-case wiring. `mob_def` is intentionally null — the dummy has no
## loot table or XP reward.
signal mob_died(mob: PracticeDummy, death_position: Vector2, mob_def: MobDef)

# ---- Tuning constants --------------------------------------------------

## Dummy HP — Uma Beat 5 spec: "harmlessly poofs into ember-dust on the
## third strike." Three fist hits at FIST_DAMAGE=1 → exactly three swings
## kills. Independent of MobDef (the dummy has no MobDef by design).
const HP_MAX: int = 3

## Path to the iron_sword ItemDef the dummy drops. Hardcoded res:// path
## (not a LootTableDef) so the drop is deterministic — the player walks
## into Room02 already equipped on EVERY playthrough, no RNG. ItemDef path
## already enumerated in `ContentRegistry.STARTER_ITEM_PATHS` so the drop
## resolves on HTML5 (DirAccess subdirectory quirk pre-empted).
const IRON_SWORD_PATH: String = "res://resources/items/weapons/iron_sword.tres"

## Visual constants — mirror Grunt's HIT_FLASH / DEATH tween / ember-burst
## for a unified hit-reaction feel across "things that die in this game."
## Sub-1.0 channels per HTML5 HDR-clamp rule (see PR #137 lesson).
const HIT_FLASH_IN: float = 0.020
const HIT_FLASH_HOLD: float = 0.020
const HIT_FLASH_OUT: float = 0.040
const DEATH_TWEEN_DURATION: float = 0.200
const DEATH_TARGET_SCALE: float = 0.6
const DEATH_PARTICLE_COUNT: int = 12  # 2x grunt — Uma "0.4 s ember-poof" reads denser
const EMBER_LIGHT: Color = Color(1.0, 0.690, 0.400, 1.0)   # #FFB066
const EMBER_DEEP: Color = Color(0.627, 0.180, 0.031, 1.0)  # #A02E08

## Layer bits (mirror project.godot + Grunt convention).
const LAYER_WORLD: int = 1 << 0          # bit 1
const LAYER_PLAYER: int = 1 << 1         # bit 2
const LAYER_ENEMY: int = 1 << 3          # bit 4

# ---- Runtime ----------------------------------------------------------

var hp_max: int = HP_MAX
var hp_current: int = HP_MAX
## Sentinel — tutorial dummy entity does not carry a MobDef. Exposed as a
## var (not a const) so duck-typed code that does `obj.mob_def = def` (e.g.
## `MultiMobRoom._spawn_mob`) can still target this class without crashing
## — they assign null and we ignore it. Read-only contract: writes are
## accepted but silently dropped (the dummy never uses the field).
var mob_def: MobDef = null

var _is_dead: bool = false

# Hit-flash + death tween refs — kept for reference-change tests + so a
# second hit during flash can kill+restart the in-flight tween.
var _hit_flash_tween: Tween = null
var _death_tween: Tween = null

# Hit-flash target — mirrors Grunt: prefer the Sprite ColorRect child
# (visible-draw color), fall back to self.modulate for bare-instanced
# test dummies.
var _hit_flash_target: CanvasItem = null
var _hit_flash_uses_sprite: bool = false
var _sprite_color_at_rest: Color = Color(1, 1, 1, 1)
var _modulate_at_rest: Color = Color(1, 1, 1, 1)
var _captured_modulate_at_rest: bool = false


func _ready() -> void:
	_apply_layers()
	_apply_motion_mode()


# ---- Public API ------------------------------------------------------

func get_hp() -> int:
	return hp_current


func get_max_hp() -> int:
	return hp_max


func is_dead() -> bool:
	return _is_dead


## Stub for compatibility with `Main._wire_mob` / `Stratum1Room01._spawn_mob`
## which call `set_player()` on every spawned mob. Dummy ignores the player
## ref (no AI). Accepting + dropping the call keeps the duck-typed wiring
## generic.
func set_player(_p: Node2D) -> void:
	pass


## Take damage. Same signature contract as `Grunt.take_damage` — hit by a
## player-team Hitbox spawned in `Player.try_attack`. Decrements HP, emits
## `damaged`, then on HP=0 emits `mob_died`, ember-poofs, drops iron_sword,
## and queue_frees.
##
## - Damage during dead is ignored (idempotent — multi-hit collapse already
##   happens at Hitbox level, but this is belt-and-suspenders for tests).
## - Negative amounts are clamped to 0.
## - Knockback is accepted-and-ignored. The dummy is rooted by design.
func take_damage(amount: int, _knockback: Vector2, source: Node) -> void:
	if _is_dead:
		_combat_trace("PracticeDummy.take_damage", "IGNORED already_dead amount=%d" % amount)
		return
	var clean_amount: int = max(0, amount)
	var hp_before: int = hp_current
	hp_current = max(0, hp_current - clean_amount)
	_combat_trace("PracticeDummy.take_damage",
		"amount=%d hp=%d->%d" % [clean_amount, hp_before, hp_current])
	damaged.emit(clean_amount, hp_current, source)
	if clean_amount > 0:
		_play_hit_flash()
	if hp_current == 0:
		_die()


# ---- Death -----------------------------------------------------------

func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	_combat_trace("PracticeDummy._die", "starting death sequence")
	velocity = Vector2.ZERO
	# Critical contract (mirrors Grunt._die): mob_died emits at the START of
	# the death sequence so room-clear listeners + iron_sword drop fire on
	# this frame. The 200ms death tween + ember-burst run AFTER, decoupled
	# from the gameplay surface.
	mob_died.emit(self, global_position, null)
	_spawn_iron_sword_pickup()
	_spawn_death_particles()
	_play_death_tween()


## Drop a guaranteed iron_sword pickup at the dummy's death position. Per
## Uma's design preference (Stage 2b dispatch) the dummy is the deterministic
## starter-equip drop — Room02's grunt is no longer "biased loot," the
## player has the iron_sword equipped before they meet grunt #1. This is
## the design-correct path that retires PR #146's boot-equip bandaid (which
## stays in main this PR; cleanup is a separate ticket).
##
## **Physics-flush safety:** Pickup is an Area2D, and `_die` runs from the
## physics-step Hitbox.body_entered chain. Synchronous add_child would
## panic Godot 4 on the Area2D monitoring mutation (see
## `.claude/docs/combat-architecture.md` § "Physics flush rule" + memory
## `godot-physics-flush-area2d-rule.md`). `call_deferred("add_child", ...)`
## lands the insertion after the physics flush completes — exact pattern
## from `MobLootSpawner.on_mob_died`.
##
## The Pickup is parented under the room (this dummy's parent), so it
## persists past our queue_free and is freed cleanly when the room
## transitions out.
func _spawn_iron_sword_pickup() -> void:
	var room: Node = get_parent()
	if room == null:
		# Bare-instanced dummy (test edge) — skip drop. Tests that need to
		# assert the drop fire pass an explicit parent before HP=0.
		return
	var sword_def: ItemDef = load(IRON_SWORD_PATH) as ItemDef
	if sword_def == null:
		push_warning("PracticeDummy: failed to load iron_sword at %s" % IRON_SWORD_PATH)
		return
	var instance: ItemInstance = ItemInstance.new(sword_def, sword_def.tier)
	var pickup_scene: PackedScene = load("res://scenes/loot/Pickup.tscn") as PackedScene
	if pickup_scene == null:
		push_warning("PracticeDummy: Pickup scene failed to load")
		return
	var pickup: Pickup = pickup_scene.instantiate() as Pickup
	pickup.configure(instance)
	pickup.position = global_position
	# Defer add_child — Pickup root is Area2D; sync add panics during physics flush.
	room.call_deferred("add_child", pickup)
	_combat_trace("PracticeDummy._spawn_iron_sword_pickup",
		"deferred-add iron_sword at (%.1f,%.1f)" % [global_position.x, global_position.y])


## Ember-poof on death. Mirrors Grunt's burst with 2x particle count for
## Uma's "0.4 s ember-poof" feel (denser cloud reads as "this thing was
## made of embers all along"). Parented to the room (NOT self) so the
## burst persists past queue_free.
##
## Same physics-flush safety as Grunt._spawn_death_particles: `call_deferred`
## the add_child since `_die` runs from the physics-step body_entered chain
## and CPUParticles2D add still touches the active scene state.
func _spawn_death_particles() -> void:
	var room: Node = get_parent()
	if room == null:
		return
	var burst: CPUParticles2D = CPUParticles2D.new()
	burst.global_position = global_position
	burst.amount = DEATH_PARTICLE_COUNT
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.lifetime = 0.40
	burst.emitting = true
	burst.direction = Vector2.UP
	burst.spread = 180.0
	burst.initial_velocity_min = 30.0
	burst.initial_velocity_max = 70.0
	burst.gravity = Vector2(0.0, -40.0)
	burst.scale_amount_min = 1.0
	burst.scale_amount_max = 1.0
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, EMBER_LIGHT)
	ramp.set_color(1, EMBER_DEEP)
	burst.color_ramp = ramp
	room.call_deferred("add_child", burst)
	burst.finished.connect(burst.queue_free)


## Death tween — 200 ms parallel scale 1.0→0.6 + modulate.a 1.0→0.0, then
## queue_free. Mirrors Grunt's tween pattern + the HTML5 safety-net
## SceneTreeTimer that fires queue_free even if the tween's `finished` signal
## stalls (HTML5 gl_compatibility timing jitter, see Grunt._play_death_tween
## docstring + ticket M1 RC P0 wave 2).
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
	# HTML5 safety-net per Grunt._play_death_tween — parallel SceneTreeTimer
	# that calls _force_queue_free if the tween's finished signal never lands.
	var timer: SceneTreeTimer = get_tree().create_timer(DEATH_TWEEN_DURATION + 0.2)
	timer.timeout.connect(_force_queue_free)
	_combat_trace("PracticeDummy._play_death_tween",
		"tween_valid=%s timer_armed=%.3fs" % [_death_tween.is_valid(), DEATH_TWEEN_DURATION + 0.2])


func _on_death_tween_finished() -> void:
	_combat_trace("PracticeDummy._on_death_tween_finished", "calling _force_queue_free via tween path")
	_force_queue_free()


## Idempotent queue_free guard. Mirrors Grunt._force_queue_free.
func _force_queue_free() -> void:
	if is_queued_for_deletion():
		_combat_trace("PracticeDummy._force_queue_free", "already queued — second-caller no-op")
		return
	_combat_trace("PracticeDummy._force_queue_free", "freeing now")
	queue_free()


# ---- Hit flash --------------------------------------------------------

## White hit-flash on the Sprite ColorRect child (visible-draw target);
## fallback to self.modulate for bare-instanced test dummies. Tween-shape
## mirrors Grunt._play_hit_flash exactly (PR #140 fix — visible-draw node
## tween, NOT cascading parent modulate).
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
		_combat_trace("PracticeDummy._play_hit_flash",
			"sprite tween_valid=%s rest=(%.2f,%.2f,%.2f)" %
			[_hit_flash_tween.is_valid(), _sprite_color_at_rest.r, _sprite_color_at_rest.g, _sprite_color_at_rest.b])
	else:
		_hit_flash_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), HIT_FLASH_IN)
		_hit_flash_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), HIT_FLASH_HOLD)
		_hit_flash_tween.tween_property(self, "modulate", _modulate_at_rest, HIT_FLASH_OUT)
		_combat_trace("PracticeDummy._play_hit_flash",
			"modulate-fallback tween_valid=%s" % _hit_flash_tween.is_valid())


# ---- Helpers ---------------------------------------------------------

## CharacterBody2D motion_mode = FLOATING per `.claude/docs/combat-architecture.md`
## § "CharacterBody2D motion_mode rule" — adopt the standard top-down 2D
## pattern from day one (Stratum1Boss PR #163's universal-bug-class fix).
## Even for a stationary entity, FLOATING avoids the latent direction-
## asymmetric collision-resolution bug that bites every CharacterBody2D
## in this project's top-down 2D world.
func _apply_motion_mode() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


## Mirrors Grunt._apply_layers — bare-instantiated dummy ends up on the
## enemy layer just like a scene-loaded one. Bare default = 1 (world); we
## detect that and replace with the enemy bit so the player's hitbox can
## damage the dummy (player_hitbox masks LAYER_ENEMY).
func _apply_layers() -> void:
	const BARE_DEFAULT_LAYER: int = 1
	if collision_layer == 0 or collision_layer == BARE_DEFAULT_LAYER:
		collision_layer = LAYER_ENEMY
	if collision_mask == 0 or collision_mask == BARE_DEFAULT_LAYER:
		collision_mask = LAYER_WORLD | LAYER_PLAYER


## Combat-trace shim — routes through DebugFlags.combat_trace (HTML5-only),
## same shape as Grunt._combat_trace. Used by tutorial-flow soak diagnostics.
func _combat_trace(tag: String, msg: String = "") -> void:
	var df: Node = null
	if is_inside_tree():
		df = get_tree().root.get_node_or_null("DebugFlags")
	if df != null and df.has_method("combat_trace"):
		df.combat_trace(tag, msg)
