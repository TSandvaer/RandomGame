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

## Emitted at the start of an i-frame window (fired by dodge). Hitbox
## scripts listen to this to drop their owner from damage tables.
signal iframes_started()
signal iframes_ended()

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

const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")
const DamageScript: Script = preload("res://scripts/combat/Damage.gd")

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

# ---- Runtime state ------------------------------------------------------

var _state: StringName = STATE_IDLE
var _facing: Vector2 = Vector2.DOWN

# Dodge bookkeeping
var _dodge_time_left: float = 0.0
var _dodge_cooldown_left: float = 0.0
var _dodge_dir: Vector2 = Vector2.ZERO
var _is_invulnerable: bool = false

# Attack bookkeeping
var _attack_recovery_left: float = 0.0

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


func _ready() -> void:
	# Seed the saved layer mask from whatever the scene authored. Tests may
	# also instantiate this node bare (no scene), in which case the default
	# CharacterBody2D.collision_layer == 1 and we explicitly set the player bit.
	if collision_layer == 0:
		collision_layer = 1 << (PLAYER_LAYER_BIT - 1)
	_saved_collision_layer = collision_layer
	# Register in the "player" group so other systems (Pickup, Grunt's
	# `_resolve_player`, InventoryPanel `_player_node`) find this node via
	# group lookup. Idempotent: add_to_group is a no-op if already in the group.
	add_to_group("player")
	# NOTE: equip_starter_weapon_if_needed() is intentionally NOT called here.
	# It must fire AFTER Main._load_save_or_defaults() so a save-restore
	# (which resets Inventory + re-applies saved equipped state) cannot clobber
	# the starter equip. Main._ready() calls it after _load_save_or_defaults().
	# See: fix(combat|inventory) PR — iron_sword integration-surface fix.


func _physics_process(delta: float) -> void:
	_tick_timers(delta)

	match _state:
		STATE_IDLE, STATE_WALK:
			_process_grounded(delta)
		STATE_DODGE:
			_process_dodge(delta)
		STATE_ATTACK:
			_process_attack(delta)

	move_and_slide()


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
	hp_current = max(0, hp_current - clean_amount)
	damaged.emit(clean_amount, hp_current, source)
	hp_changed.emit(hp_current, hp_max)
	# Knockback applied as instantaneous velocity bump. Decays naturally
	# next physics tick (the state machine resets velocity from input).
	if knockback.length_squared() > 0.0:
		velocity = knockback
	if hp_current == 0:
		_die()


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
	hp_current = hp_max
	hp_changed.emit(hp_current, hp_max)


## Returns true if the player has died (HP hit zero this lifetime).
func is_dead() -> bool:
	return _is_dead


## Internal: drive the death-transition. Idempotent — emits player_died
## exactly once even under multi-hit collapse (if two enemy hitboxes
## land in the same frame, the second is short-circuited by `_is_dead`).
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
	player_died.emit(global_position)


## Internal helper — fetch the Inventory autoload if it's registered.
## Returns null in bare-instantiated test contexts that don't register
## the autoload (most Player unit tests). Inventory.equip_starter_weapon_if_needed
## is the only caller; it is defensive when the return is null.
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
	_enter_iframes()
	set_state(STATE_DODGE)
	return true


## Fire a light or heavy attack. Returns the spawned Hitbox node, or null
## if the attack was rejected (mid-dodge or in recovery). Direction is the
## intended hit direction; if zero, uses current facing.
func try_attack(kind: StringName, dir: Vector2 = Vector2.ZERO) -> Node:
	if not can_attack():
		_combat_trace("Player.try_attack",
			"REJECTED kind=%s state=%s recovery=%.3f" % [kind, _state, _attack_recovery_left])
		return null
	if kind != ATTACK_LIGHT and kind != ATTACK_HEAVY:
		push_warning("Player.try_attack: unknown kind '%s'" % kind)
		return null
	var d: Vector2 = dir.normalized() if dir.length_squared() > 0.0 else _facing
	_facing = d
	_combat_trace("Player.try_attack",
		"FIRED kind=%s facing=(%.1f,%.1f)" % [kind, d.x, d.y])

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


# ---- State handlers -----------------------------------------------------

func _process_grounded(_delta: float) -> void:
	var input_dir: Vector2 = _read_movement_input()
	var sprinting: bool = Input.is_action_pressed("sprint")

	if input_dir.length_squared() > 0.0:
		_facing = input_dir
		var speed: float = get_walk_speed() * (SPRINT_MULTIPLIER if sprinting else 1.0)
		velocity = input_dir * speed
		set_state(STATE_WALK)
	else:
		velocity = Vector2.ZERO
		set_state(STATE_IDLE)

	if Input.is_action_just_pressed("dodge"):
		try_dodge(input_dir)
	elif Input.is_action_just_pressed("attack_light"):
		try_attack(ATTACK_LIGHT, input_dir)
	elif Input.is_action_just_pressed("attack_heavy"):
		try_attack(ATTACK_HEAVY, input_dir)


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


func _tick_timers(delta: float) -> void:
	if _dodge_time_left > 0.0:
		_dodge_time_left = max(0.0, _dodge_time_left - delta)
	if _dodge_cooldown_left > 0.0:
		_dodge_cooldown_left = max(0.0, _dodge_cooldown_left - delta)
	if _attack_recovery_left > 0.0:
		_attack_recovery_left = max(0.0, _attack_recovery_left - delta)


func _exit_dodge() -> void:
	_exit_iframes()
	set_state(STATE_IDLE)


func _enter_iframes() -> void:
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
func _spawn_swing_wedge(kind: StringName, dir: Vector2, reach: float, radius: float, lifetime: float) -> ColorRect:
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
	tween.tween_callback(Callable(self, "_on_wedge_finished").bind(wedge))
	_combat_trace("Player.swing_wedge",
		"spawned kind=%s lifetime=%.3f tween_valid=%s alpha=%.2f" % [kind, lifetime, tween.is_valid(), rgba.a])
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
	_combat_trace("Player.swing_flash",
		"tween_valid=%s tint=(%.2f,%.2f,%.2f) duration=%.3f" % [tween.is_valid(), SWING_FLASH_TINT.r, SWING_FLASH_TINT.g, SWING_FLASH_TINT.b, SWING_FLASH_HALF_DURATION * 2.0])


## Internal: tween-finished callback for the swing wedge. Frees the node and
## clears the active reference (only if this exact wedge is still the
## active one — a newer attack may have already replaced it).
func _on_wedge_finished(wedge: ColorRect) -> void:
	if not is_instance_valid(wedge):
		return
	if _active_swing_wedge == wedge:
		_active_swing_wedge = null
	wedge.queue_free()


# ---- Hitbox spawn -------------------------------------------------------

func _spawn_hitbox(dir: Vector2, damage: int, knockback: Vector2, reach: float, radius: float, lifetime: float) -> Hitbox:
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
	return hitbox


# ---- Input --------------------------------------------------------------

func _read_movement_input() -> Vector2:
	# Input.get_vector handles 8-direction normalisation cleanly.
	var v: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# get_vector already normalises diagonals to length 1.0, so the player
	# doesn't move sqrt(2)x faster diagonally. Belt-and-suspenders:
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v
