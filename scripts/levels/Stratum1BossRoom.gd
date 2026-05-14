class_name Stratum1BossRoom
extends Node2D
## Stratum-1 boss room — wires Uma's 1.8 s entry sequence to a door trigger,
## spawns the boss, and routes boss-died into the loot drop + the
## stratum-exit-unlocked state.
##
## Design source: `team/uma-ux/boss-intro.md` (Uma — binding) — the
## beat-by-beat is owned there. This controller is the **timing skeleton**:
## the actual camera zoom, ambient cut, vignette, and audio cues are
## Devon's `BossIntroSequence` cinematic layer's responsibility. What this
## controller guarantees:
##
##   1. Crossing the door trigger fires the entry-sequence start signal
##      (`entry_sequence_started`) immediately.
##   2. The sequence runs for exactly `ENTRY_SEQUENCE_DURATION` seconds,
##      then fires `entry_sequence_completed` and calls the boss's `wake()`.
##   3. The boss starts in STATE_DORMANT — it cannot attack or take damage
##      during the entry sequence (Uma BI-19: boss does NOT attack during
##      Beats 1–4).
##   4. On `boss_died`, the controller drops loot via `MobLootSpawner` and
##      flips `stratum_exit_unlocked = true`, emitting `stratum_exit_unlocked`.
##
## The camera/audio/vignette wiring is decoupled: Devon (or the test
## harness) connects to the `entry_sequence_started` and
## `entry_sequence_completed` signals to drive cinematic layers. This keeps
## the room script test-friendly (no required scene-tree dependencies).

# ---- Signals ------------------------------------------------------------

## The player crossed the boss-room threshold. Cinematic layer subscribes
## to start the door-slam, ambient-cut, camera-zoom, nameplate-slide.
signal entry_sequence_started()

## The 1.8 s entry sequence has elapsed. Boss is about to wake. Cinematic
## layer subscribes to ramp camera back to player-anchored and start boss
## music. Wake fires immediately after.
signal entry_sequence_completed()

## The boss has been defeated. Cinematic layer subscribes to drive the
## `BossDefeatedSequence` (time-freeze, ember dissolve, title card).
signal boss_defeated(boss: Stratum1Boss, death_position: Vector2)

## Stratum-exit door has unlocked — player can leave. M1 has only one
## stratum so this is the run-clear signal.
signal stratum_exit_unlocked()

# ---- Tuning ------------------------------------------------------------

## Total entry-sequence duration per Uma's spec (Beats 1–4). Beat 5 begins
## immediately after this elapses.
const ENTRY_SEQUENCE_DURATION: float = 1.8

# ---- Inspector --------------------------------------------------------

## res:// path to the boss scene. Indirected via export so tests can swap
## in a fake boss without coupling to the real scene's spec.
@export_file("*.tscn") var boss_scene_path: String = "res://scenes/mobs/Stratum1Boss.tscn"

## res:// path to the boss MobDef TRES. Applied to the spawned boss after
## instantiation so HP/damage come from authored content.
@export_file("*.tres") var boss_mob_def_path: String = "res://resources/mobs/stratum1_boss.tres"

## World-space spawn position for the boss within the room. Default is the
## center of a single-screen 480x270 boss arena. Test/level can override.
@export var boss_spawn_position: Vector2 = Vector2(240.0, 135.0)

## World-space position of the door trigger. Player crossing this Area2D
## fires the entry sequence. Default placement at the room's south edge.
@export var door_trigger_position: Vector2 = Vector2(240.0, 250.0)
@export var door_trigger_size: Vector2 = Vector2(80.0, 16.0)

## res:// path to the StratumExit scene. Spawned (inactive) at room ready
## and activated via `boss_died` plumbing. Indirected via export so tests
## can opt into the real scene without coupling to its internal shape.
@export_file("*.tscn") var stratum_exit_scene_path: String = "res://scenes/levels/StratumExit.tscn"

## World-space position of the stratum exit portal. Default places it
## near the top of the arena — opposite the door trigger, so the player
## walks "deeper" to descend.
@export var stratum_exit_position: Vector2 = Vector2(240.0, 30.0)

# ---- Runtime ----------------------------------------------------------

var _boss: Stratum1Boss = null
var _door_trigger: Area2D = null
var _entry_timer: SceneTreeTimer = null
var _entry_sequence_active: bool = false
var _entry_sequence_completed: bool = false
var _entry_started_time_ms: int = 0
var _entry_completed_time_ms: int = 0
var _stratum_exit_unlocked: bool = false
var _loot_spawner: MobLootSpawner = null
var _stratum_exit: StratumExit = null


func _ready() -> void:
	_loot_spawner = MobLootSpawner.new()
	_loot_spawner.set_parent_for_pickups(self)
	# `_spawn_boss()` stays synchronous: the boss is a CharacterBody2D (no
	# Area2D monitoring mutation on tree-entry), and `Main._wire_room_signals`
	# reads `get_boss()` on the SAME tick the room is added to the tree (see
	# `scenes/Main.gd::_wire_room_signals`, the `index == BOSS_ROOM_INDEX`
	# branch). Deferring the boss spawn would make `get_boss()` return null at
	# wire time and the boss would never get its XP / loot wiring.
	_spawn_boss()
	# Defer the Area2D-fixture pass (door-trigger build + StratumExit spawn)
	# AND the entry-sequence trigger out of the physics-flush window.
	#
	# Root cause (ticket 86c9tv8uf — the follow-up flagged in PR #183): the
	# boss room is loaded by `Main._load_room_at_index(8)`, which runs inside
	# a physics-flush window — the call chain is rooted in Room 08's
	# `RoomGate.gate_traversed` → `MultiMobRoom._on_room_gate_traversed` →
	# `room_cleared` → `Main._on_room_cleared` → `_load_room_at_index` →
	# `_world.add_child(room)` → `Stratum1BossRoom._ready()`, and
	# `gate_traversed` itself emits from `RoomGate._on_body_entered` (a
	# CharacterBody2D physics callback). `_build_door_trigger()` does a
	# synchronous `add_child` of an `Area2D` (the door trigger); `_spawn_stratum_exit()`
	# adds a `StratumExit` whose own `_ready` builds an `Area2D` interaction
	# area. Adding an Area2D + activating its monitoring inside a physics flush
	# panics with `USER ERROR: Can't change this state while flushing queries`
	# (see `.claude/docs/combat-architecture.md` § "Physics-flush rule"). The
	# C++ early-returns, leaving the Area2D improperly inserted: it never
	# monitors, so `body_entered` never fires and the player can never leave
	# the boss room. This is the SAME bug class as `MultiMobRoom._spawn_room_gate`
	# (fixed in PR #183) — the old combat-architecture.md claim that the boss
	# room's `_build_door_trigger` had "zero panic risk because it spawns from
	# `_ready`, not a physics-tick path" was wrong: `_ready` of a room past
	# Room 01 IS a physics-flush context.
	#
	# Deferring lands `_assemble_room_fixtures` AFTER the physics flush closes,
	# so the Area2D `add_child` + monitoring activation run on a clean tick.
	# This mirrors the `MultiMobRoom._ready → call_deferred("_assemble_room_fixtures")`
	# and `Stratum1Room01._ready → call_deferred("_wire_tutorial_flow")`
	# precedents (same `.claude/docs` § "Room-load triggers vs body_entered
	# triggers" rule).
	#
	# The deferred call also lands AFTER `Main._load_room_at_index` re-parents
	# the player into the room, so by the time the 1.8 s entry-sequence timer
	# fires the player is correctly placed (the original M2 W1 P0 `86c9q96fv`
	# / `86c9q96ht` reason for deferring `trigger_entry_sequence`).
	call_deferred("_assemble_room_fixtures")


## Deferred fixture pass — runs one frame after `_ready`, OUTSIDE the
## physics-flush window that `Main._load_room_at_index` invokes `_ready`
## inside. Builds the door-trigger Area2D, spawns the StratumExit (which
## builds its own Area2D interaction area), then auto-fires the boss entry
## sequence. Idempotent-safe: if the room is freed before the deferred call
## lands, the `is_inside_tree` guard bails cleanly.
func _assemble_room_fixtures() -> void:
	if not is_inside_tree():
		return
	_build_door_trigger()
	_spawn_stratum_exit()
	# HTML5-only datapoint (ticket 86c9tv8uf): confirms the deferred fixture
	# pass actually ran and the door-trigger Area2D is now in the tree +
	# monitoring. If a physics-flush regression ever re-breaks the Area2D
	# insertion, `monitoring` reads false here and Sponsor / the Playwright
	# harness can see it in the console without a native build.
	if _door_trigger != null:
		_combat_trace("Stratum1BossRoom._assemble_room_fixtures",
			"door_trigger built — inside_tree=%s monitoring=%s" % [
				str(_door_trigger.is_inside_tree()), str(_door_trigger.monitoring)])
	# M2 W1 P0 fix (`86c9q96fv` + `86c9q96ht`): the boss starts STATE_DORMANT
	# and only wakes via `trigger_entry_sequence()` → 1.8 s timer → `wake()`.
	# The original wake-gate was the door-trigger Area2D at (240, 250) — but
	# in production the player enters the boss room via `Main._load_room_at_index`,
	# which TELEPORTS the player to (240, 200) without any physics overlap event.
	# Player Y=200 sits ABOVE the trigger Y=250, so `body_entered` never fires.
	# Result: boss stays dormant indefinitely → `take_damage` is rejected during
	# DORMANT AND `_physics_process` skips all AI. Both Sponsor-reported P0s
	# ("boss does not take damage" + "boss does not attack") collapse to this
	# single root cause.
	#
	# `trigger_entry_sequence` is idempotent (guards on `_entry_sequence_active`
	# / `_entry_sequence_completed`), so the door-trigger fallback path remains
	# safe — if a future code path teleports the player onto the trigger, the
	# `body_entered` handler is a no-op rather than re-firing the sequence.
	#
	# The 1.8 s narrative beat (Uma boss-intro.md Beats 1-4) is preserved: the
	# entry sequence still runs end-to-end. Tests still call
	# `trigger_entry_sequence()` + `complete_entry_sequence_for_test()` directly;
	# their idempotent-guard chain makes the deferred auto-fire harmless in tests.
	#
	# Gated on `_boss != null`: tests that construct the room with empty
	# `boss_scene_path` (e.g. `test_room_advance_only_on_door_walk.gd` — door-
	# trigger isolation tests) should NOT auto-fire the entry sequence — they
	# build the room only to inspect the trigger Area2D's properties. The
	# production scene always has `boss_scene_path` set, so production gets the
	# auto-fire as designed.
	if _boss != null:
		trigger_entry_sequence()


# ---- Public API -------------------------------------------------------

func get_boss() -> Stratum1Boss:
	return _boss


func get_door_trigger() -> Area2D:
	return _door_trigger


func get_stratum_exit() -> StratumExit:
	return _stratum_exit


func is_entry_sequence_active() -> bool:
	return _entry_sequence_active


func is_entry_sequence_completed() -> bool:
	return _entry_sequence_completed


func is_stratum_exit_unlocked() -> bool:
	return _stratum_exit_unlocked


## Force-fire the entry sequence (used by tests that don't simulate physics
## overlap). The Area2D body_entered handler also calls this in production.
func trigger_entry_sequence() -> void:
	if _entry_sequence_active or _entry_sequence_completed:
		return
	_entry_sequence_active = true
	_entry_started_time_ms = Time.get_ticks_msec()
	entry_sequence_started.emit()
	# Use a SceneTreeTimer so we don't need an explicit Timer node — keeps
	# the scene shape simple and the test code can substitute a deterministic
	# fast-forward via `_complete_entry_sequence_for_test()`.
	if is_inside_tree():
		_entry_timer = get_tree().create_timer(ENTRY_SEQUENCE_DURATION)
		_entry_timer.timeout.connect(_complete_entry_sequence)


## Test-only: skip the wall-clock wait and complete the sequence now.
## Production code never calls this — production waits the real 1.8 s.
func complete_entry_sequence_for_test() -> void:
	_complete_entry_sequence()


# ---- Internal --------------------------------------------------------

func _build_door_trigger() -> void:
	_door_trigger = Area2D.new()
	_door_trigger.name = "BossRoomDoorTrigger"
	_door_trigger.position = door_trigger_position
	# Player is on layer 2 (player). The trigger sits on no layer (it doesn't
	# emit collisions itself) and masks player so player overlap fires the
	# body_entered signal.
	_door_trigger.collision_layer = 0
	_door_trigger.collision_mask = 1 << 1  # bit 2 = player
	# Bug 1 harmonization (ticket 86c9p1fgf + 86c9q7xgx): set monitorable=false
	# so no other Area2D (Hitbox, Projectile, StratumExit) can receive
	# area_entered FROM this trigger. The trigger only needs to DETECT bodies
	# (monitoring=true, which is Area2D's default), not to BE detected.
	# This is the same receiver-side encapsulation pattern used for Hitbox and
	# Projectile (_init: monitorable=false) — see combat-architecture.md.
	# Physics-flush safety (ticket 86c9tv8uf): this Area2D `add_child` is NOT
	# called directly from `_ready` — `_ready` defers it via
	# `call_deferred("_assemble_room_fixtures")`, which lands AFTER the
	# physics-flush window that `Main._load_room_at_index` invokes `_ready`
	# inside. Mutating monitoring state here is therefore on a clean tick.
	_door_trigger.monitorable = false
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = door_trigger_size
	shape.shape = rect
	_door_trigger.add_child(shape)
	_door_trigger.body_entered.connect(_on_door_trigger_body_entered)
	# Area2D-derived nodes (Hitbox, Projectile) cannot trigger body_entered per
	# Godot 4 physics semantics, but connecting area_entered as an explicit no-op
	# documents the intent and guards against future accidental wiring.
	_door_trigger.area_entered.connect(_on_door_trigger_area_entered_ignored)
	add_child(_door_trigger)


func _spawn_boss() -> void:
	var packed: PackedScene = load(boss_scene_path) as PackedScene
	if packed == null:
		push_error("Stratum1BossRoom: failed to load boss scene at '%s'" % boss_scene_path)
		return
	var node: Node = packed.instantiate()
	if not node is Stratum1Boss:
		push_error("Stratum1BossRoom: boss scene root is not Stratum1Boss")
		node.free()
		return
	_boss = node
	_boss.position = boss_spawn_position
	# Apply the authored MobDef after instantiation so HP/dmg/speed reflect
	# stratum1_boss.tres rather than the default fallback.
	if boss_mob_def_path != "":
		var def: MobDef = load(boss_mob_def_path) as MobDef
		if def != null:
			_boss.mob_def = def
	add_child(_boss)
	# After add_child, _ready ran; re-apply the def in case the export-path
	# load completed late or to overwrite any test-default state.
	if _boss.mob_def != null:
		_boss.apply_mob_def(_boss.mob_def)
	# Wire boss death to loot drop + exit-unlock.
	_boss.boss_died.connect(_on_boss_died)


func _on_door_trigger_body_entered(body: Node) -> void:
	# Bug 1 harmonization (ticket 86c9p1fgf + 86c9q7xgx): only a
	# CharacterBody2D on the player physics layer should fire the entry
	# sequence. The collision_mask (bit 2 = player) already filters mob bodies
	# (enemy layer = bit 4) at the physics level, so this CharacterBody2D
	# guard is belt-and-suspenders — it prevents a future bare-Node or wrong-
	# class body from entering the mask (e.g. during tests) from triggering the
	# cinematic sequence by mistake.
	# HTML5-only datapoint (ticket 86c9tv8uf): proves the door-trigger Area2D
	# is monitoring and actually saw a body. Logged BEFORE the CharacterBody2D
	# filter so "trigger saw something" vs "trigger saw nothing" is always
	# distinguishable in the console — the same Case A / Case B distinction
	# `RoomGate._on_body_entered` uses. This is the trace the Playwright
	# boss-room spec asserts on to confirm the physics-flush fix landed.
	_combat_trace("Stratum1BossRoom._on_door_trigger_body_entered",
		"body=%s is_character_body=%s" % [str(body), str(body is CharacterBody2D)])
	if not body is CharacterBody2D:
		return
	trigger_entry_sequence()


## Area2D neighbors are never allowed to fire the boss entry sequence.
## See RoomGate._on_area_entered_ignored for the full rationale.
func _on_door_trigger_area_entered_ignored(_area: Area2D) -> void:
	pass  # Boss entry sequence fires on player CharacterBody2D only.


func _complete_entry_sequence() -> void:
	if _entry_sequence_completed:
		return
	_entry_sequence_completed = true
	_entry_sequence_active = false
	_entry_completed_time_ms = Time.get_ticks_msec()
	entry_sequence_completed.emit()
	# Wake the boss now that Beats 1–4 are over.
	if _boss != null and not _boss.is_dead():
		_boss.wake()


func _on_boss_died(boss: Stratum1Boss, death_position: Vector2, mob_def: MobDef) -> void:
	# Drop loot via the standard spawner so the boss reuses the same
	# pipeline as Grunt's drops. boss_drops.tres ships with guaranteed-drop
	# entries (weight = 1.0 with T2/T3 tier modifiers per Uma's "climax
	# loot moment").
	if _loot_spawner != null and mob_def != null:
		_loot_spawner.on_mob_died(boss, death_position, mob_def)
	# Flip the exit-unlocked state and emit. Cinematic layer subscribes
	# separately to the boss's own `boss_died` signal for the time-freeze
	# + ember dissolve; we don't drive those visuals from here.
	_stratum_exit_unlocked = true
	# Activate the StratumExit so the player can walk to it and descend.
	# The exit was spawned INACTIVE in `_spawn_stratum_exit` — this is the
	# moment it lights up.
	if _stratum_exit != null:
		_stratum_exit.activate()
	stratum_exit_unlocked.emit()
	boss_defeated.emit(boss, death_position)


func _spawn_stratum_exit() -> void:
	if stratum_exit_scene_path == "":
		return
	var packed: PackedScene = load(stratum_exit_scene_path) as PackedScene
	if packed == null:
		push_error("Stratum1BossRoom: failed to load StratumExit scene at '%s'" % stratum_exit_scene_path)
		return
	var node: Node = packed.instantiate()
	if not node is StratumExit:
		push_error("Stratum1BossRoom: StratumExit scene root is not StratumExit")
		node.free()
		return
	_stratum_exit = node
	# Override the exit's authored portal_position so it sits where this
	# room wants it. The exit's own _ready will apply this on add_child.
	_stratum_exit.portal_position = stratum_exit_position
	add_child(_stratum_exit)


# ---- Diagnostics ------------------------------------------------------

## Returns the actual measured duration (ms) of the entry sequence.
## Tests use this to assert the 1.8 s ± tolerance budget.
func entry_sequence_elapsed_ms() -> int:
	if _entry_completed_time_ms == 0 or _entry_started_time_ms == 0:
		return -1
	return _entry_completed_time_ms - _entry_started_time_ms


## Combat-trace shim — routes through DebugFlags.combat_trace (HTML5-only).
## Same pattern as `RoomGate._combat_trace` and the mob `_combat_trace`
## helpers; emits in HTML5 builds so Sponsor's DevTools console (and the
## Playwright harness) can confirm the boss-room door-trigger Area2D is
## monitoring + sees bodies — the observable surface for the ticket
## 86c9tv8uf physics-flush fix, which otherwise produces no GDScript
## exception (Godot's `USER ERROR` macros log + return-early in C++).
func _combat_trace(tag: String, msg: String = "") -> void:
	var df: Node = null
	if is_inside_tree():
		df = get_tree().root.get_node_or_null("DebugFlags")
	if df != null and df.has_method("combat_trace"):
		df.combat_trace(tag, msg)
