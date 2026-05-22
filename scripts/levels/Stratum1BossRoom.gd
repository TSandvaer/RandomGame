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
##   4. On `boss_died`, the controller activates the StratumExit and flips
##      `stratum_exit_unlocked = true`, emitting `stratum_exit_unlocked`.
##      **Loot is NOT spawned here — Main owns the boss-loot drop via its
##      own MobLootSpawner subscribed to `boss_died` through `_wire_mob`.**
##      See "Boss loot single-pipeline rule" below.
##
## **Boss loot single-pipeline rule (ticket `86c9uemdg` — Sponsor M2 RC soak).**
## Pre-fix, this controller owned its own `MobLootSpawner` and called
## `on_mob_died(boss, ...)` from `_on_boss_died`. Main also subscribes to the
## boss's `boss_died` signal in `_wire_mob` (boss has `boss_died` not
## `mob_died`, but Main's `_on_mob_died` forwards from both signals) — so
## **TWO `MobLootSpawner.on_mob_died` calls fired per boss death**, producing
## TWO independent roller.roll(loot_table) result sets, each spawning a full
## set of Pickup nodes.
##
## Main's set was wired via `Inventory.auto_collect_pickups(pickups)` — the
## return value of `_loot_spawner.on_mob_died(...)` is fed to
## `Inventory.auto_collect_pickups` which connects each Pickup's `picked_up`
## signal to `Inventory.on_pickup_collected`. The player walking over Main's
## Pickups triggers `body_entered → picked_up → on_pickup_collected → add()`.
##
## **The Stratum1BossRoom's set was NOT wired** — `_on_boss_died` discarded
## the return value of `_loot_spawner.on_mob_died(...)` so those Pickups had
## zero subscribers on their `picked_up` signal. The player walking over them
## fired `body_entered`, the Pickup emitted `picked_up`, the signal reached
## no one, and the Pickup stayed alive on the ground forever (the
## `_clear_collected_latch_if_alive` deferred call re-armed the latch since
## nobody called `consume_after_pickup`). Sponsor reported "boss room 8
## cannot loot dropped items" — Main's set was being collected, BossRoom's
## set was uncollectable.
##
## **Fix:** delete the Stratum1BossRoom's `_loot_spawner` entirely. Main is
## the single boss-loot pipeline. `_on_boss_died` now only activates the
## StratumExit + emits closure signals; loot is Main's responsibility.
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

## M3-T2-W3-T17 (ticket `86c9wjzjf`) — emitted when the player collapses
## the entry sequence via a movement-key press during Beats 2–4. Audio
## consumers (`_on_entry_sequence_started_audio` / `_on_entry_sequence_completed_audio`)
## subscribe to this to swap their default fade durations for the
## skip-fast values per Uma `boss-intro.md § Skip rule`:
##
##   - Nameplate slide:    0.4 s → 0.2 s   (consumer: T13 BossNameplate)
##   - Boss music fade-in: 0.6 s → 0.3 s   (consumer: AudioDirector handler)
##
## Beat 1 (door slam, 0.0 → 0.4 s) is OUTSIDE the skip window and always
## plays at full duration. The first-ever fight is unskippable — this
## signal only fires when `_skip_eligible == true` (driven by save state
## `character.first_boss_kill_seen`).
signal entry_sequence_skipped()

# ---- Tuning ------------------------------------------------------------

## Total entry-sequence duration per Uma's spec (Beats 1–4). Beat 5 begins
## immediately after this elapses.
const ENTRY_SEQUENCE_DURATION: float = 1.8

## M3-T2-W3-T17 — skip-collapse window. The skip is permitted from Beat 2
## onward (T+0.0; door slam is Beat 1 and runs in parallel with Beats 2-4
## per Uma's beat-by-beat — the door slam is OUTSIDE the skippable region
## semantically because it represents "this is a boss room", not the
## cinematic theatre. By starting the skip-window at T+0.0 we honor the
## "during Beats 2-4" spec since Beat 2 begins at T+0.0 in parallel with
## Beat 1; the door-slam audio cue is already in flight by then and not
## under this controller's tween-cancel reach.
const SKIP_WINDOW_START_S: float = 0.0

## Skip-window upper bound — the entry sequence completes naturally at
## ENTRY_SEQUENCE_DURATION, after which the skip is moot. We bind the
## window slightly inside the natural completion to avoid a race between
## the timer firing and a same-tick movement press.
const SKIP_WINDOW_END_S: float = ENTRY_SEQUENCE_DURATION - 0.05

## M3-T2-W3-T17 — when the skip fires, residual wall-clock time until
## `_complete_entry_sequence` runs. Sized so the door-slam audio (~0.5 s)
## isn't visually outpaced by the boss waking; this overlaps with the
## boss's `Stratum1Boss.WAKE_DURATION` (0.417 s) so the wake animation
## still plays on top of the collapsed nameplate / music fades. Per the
## brief: "read the boss's current wake-anim duration from Stratum1Boss
## — don't hard-code" — see `_skip_collapse_residual_s()` below for the
## dynamic read; this constant is the floor when the boss is absent or
## the wake constant is unreadable.
const SKIP_COLLAPSE_RESIDUAL_FLOOR_S: float = 0.1

## Save slot used for the per-character `first_boss_kill_seen` lookup.
## Mirrors `StatAllocationPanel.SAVE_SLOT` + `InventoryPanel.SAVE_SLOT`
## — M1/M2 ships a single-character single-slot save (slot 0). When
## multi-character lands (M3+), this constant indirects per-character.
const SAVE_SLOT: int = 0

## Movement actions consumed by the skip handler. Mirrors
## `Player.gd`'s `Input.get_vector("move_left", "move_right", "move_up",
## "move_down")` — the canonical movement-input surface. Any new
## movement-binding ticket should mirror its action additions here so
## the skip handler stays in sync with the player's input shape.
const SKIP_ACTIONS: PackedStringArray = ["move_up", "move_down", "move_left", "move_right"]

## M3-T2-W3-T17 — Boss BGM fade durations. The skip path uses the
## faster 300 ms ramp per Uma `boss-intro.md § Skip rule` ("boss music
## fades in 0.3 s"); the natural path uses the 600 ms default per
## `audio-direction.md §3 ducking rule 4`.
const SKIP_BGM_FADE_MS: int = 300
const DEFAULT_BGM_FADE_MS: int = 600

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
var _stratum_exit: StratumExit = null

# ---- M3-T2-W3-T17 skip-after-first-kill (ticket 86c9wjzjf) ----------

## True when this character has killed the stratum-1 boss at least once.
## Loaded from `save["character"]["first_boss_kill_seen"]` (v4 schema) on
## room `_ready`. False means the player is on their first-ever fight and
## the intro is unskippable per Uma `boss-intro.md § Skip rule`.
var _skip_eligible: bool = false

## True after the player has pressed a movement key during the skip
## window and the entry sequence has been collapsed. Guards against
## double-skip + ensures a re-fire of `trigger_entry_sequence` (idempotent
## path) doesn't undo the skip.
var _entry_sequence_skipped: bool = false

## Wall-clock time the skip fired (set by `_collapse_entry_sequence`).
## Diagnostic — surfaces in `_combat_trace` and the GUT test pinning the
## collapsed-timing budget.
var _entry_skipped_time_ms: int = 0


func _ready() -> void:
	# Boss loot is owned by Main's MobLootSpawner (subscribed to `boss_died` via
	# `_wire_mob`) — see "Boss loot single-pipeline rule" in the docstring above.
	# Stratum1BossRoom NO LONGER owns its own loot spawner; the old dual-spawn
	# path (ticket `86c9uemdg`) produced uncollectable pickups because this
	# controller's set was never wired to `Inventory.auto_collect_pickups`.
	# `_spawn_boss()` stays synchronous: the boss is a CharacterBody2D (no
	# Area2D monitoring mutation on tree-entry), and `Main._wire_room_signals`
	# reads `get_boss()` on the SAME tick the room is added to the tree (see
	# `scenes/Main.gd::_wire_room_signals`, the `index == BOSS_ROOM_INDEX`
	# branch). Deferring the boss spawn would make `get_boss()` return null at
	# wire time and the boss would never get its XP / loot wiring.
	_spawn_boss()
	# M3-T2-W1-T1 — wire entry-sequence-completed signal to BGM crossfade.
	# Subscribed BEFORE the deferred `_assemble_room_fixtures` runs the timer,
	# so the wiring is present by the time the signal fires (T+1.8 s post-
	# trigger). Idempotent triple-wire guard is inside `_wire_audio_cues`.
	_wire_audio_cues()
	# M3-T2-W3-T17 — load the per-character `first_boss_kill_seen` flag
	# from the v4 save schema. Drives `_skip_eligible`. First-ever fight
	# is unskippable (flag=false); subsequent fights collapse on movement
	# key per Uma `boss-intro.md § Skip rule`. Defensive — a missing or
	# pre-v4 save returns false (the migrate chain backfills false, but
	# read-only / cold-boot surfaces may not have hit the migrate path).
	_skip_eligible = _load_first_boss_kill_seen()
	if _skip_eligible:
		_combat_trace("Stratum1BossRoom._ready",
			"skip_eligible=true — subsequent boss fight, intro collapsible on movement")
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
## Also fast-forwards past the boss's ~417 ms WAKE_DURATION window
## (M3-T2-W1-T8, ticket 86c9wjyp9) so existing integration tests that
## expect STATE_IDLE immediately after this call continue to pass without
## per-test wake-tick simulation. Tests that specifically need to observe
## the WAKING window should call `room._complete_entry_sequence()` directly
## and inspect `boss.is_waking()` before this helper's wake fast-forward.
func complete_entry_sequence_for_test() -> void:
	_complete_entry_sequence()
	if _boss != null and is_instance_valid(_boss) and _boss.has_method("complete_wake_for_test"):
		_boss.complete_wake_for_test()


## M3-T2-W3-T17 — read-only diagnostic for tests + Playwright traces.
## True after `_collapse_entry_sequence` fires. Useful as a Playwright
## probe target ("did the skip actually engage?") so the spec doesn't
## depend on `entry_sequence_skipped.emit` timing alone.
func is_entry_sequence_skipped() -> bool:
	return _entry_sequence_skipped


## M3-T2-W3-T17 — exposes the runtime skip-eligibility flag for tests
## and `boss-intro-skip.spec.ts` (so the spec can assert "first kill not
## skippable" without rummaging in the save file).
func is_skip_eligible() -> bool:
	return _skip_eligible


## M3-T2-W3-T17 — test-only: force-set skip eligibility. Production code
## NEVER calls this; production reads from the save in `_ready`. Tests
## that want to exercise the eligible / not-eligible branches use this
## to bypass the round-trip-through-save fixture overhead. Mirrors the
## `complete_entry_sequence_for_test` test-only escape hatch.
func set_skip_eligible_for_test(eligible: bool) -> void:
	_skip_eligible = eligible


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


func _on_boss_died(boss: Stratum1Boss, death_position: Vector2, _mob_def: MobDef) -> void:
	# Loot is dropped by Main's `MobLootSpawner` (subscribed to `boss_died` via
	# `_wire_mob` in `scenes/Main.gd`). Main also wires the dropped Pickups via
	# `Inventory.auto_collect_pickups` so the player can collect them.
	# Stratum1BossRoom NO LONGER spawns its own loot — the pre-fix dual-spawn
	# (ticket `86c9uemdg`) produced uncollectable pickups because this
	# controller's set was never wired to `picked_up` listeners. See the
	# "Boss loot single-pipeline rule" in the class docstring above.
	# Flip the exit-unlocked state and emit. Cinematic layer subscribes
	# separately to the boss's own `boss_died` signal for the time-freeze
	# + ember dissolve; we don't drive those visuals from here.
	_stratum_exit_unlocked = true
	# Activate the StratumExit so the player can walk to it and descend.
	# The exit was spawned INACTIVE in `_spawn_stratum_exit` — this is the
	# moment it lights up.
	#
	# **Physics-flush safety (ticket 86c9ujq8d — M2 W3 soak P0 finding 3):**
	# `_on_boss_died` is connected to `Stratum1Boss.boss_died`, which fires
	# from `Stratum1Boss._die()`. `_die` is called from `take_damage` which
	# is reached via `Hitbox._on_body_entered` — a physics-query-flush callback.
	# `StratumExit.activate()` calls `_apply_active_state(true)` which sets
	# `_interaction_area.monitoring = true`. Mutating Area2D monitoring DURING
	# a physics flush triggers Godot 4's ERR_FAIL_COND guard:
	#
	#     USER ERROR: Can't change this state while flushing queries. Use
	#     call_deferred() or set_deferred() to change monitoring state instead.
	#
	# The C++ guard returns early; monitoring stays false; the player can never
	# walk into the interaction area; `descend_triggered` never fires; player
	# is trapped in the boss room forever.
	#
	# Fix: defer `activate()` to land AFTER the physics flush closes. The
	# BOSS_DEATH_HOLD (400ms hold + 200ms tween) means the exit won't visually
	# activate until ~600ms post-death regardless; deferring by one physics
	# tick (~16ms) is imperceptible and preserves the signal ordering:
	# `stratum_exit_unlocked.emit()` fires synchronously (Main._on_stratum_exit_unlocked
	# subscribes here to wire the descend signal — that wiring must happen before
	# the player can reach the portal, but the portal area monitoring itself
	# need not be on the same frame as the signal emission).
	#
	# Same root-cause class as `Stratum1BossRoom._build_door_trigger` (ticket
	# 86c9tv8uf) and `MobLootSpawner.on_mob_died` (PR #142) — all fixed by
	# deferring the Area2D monitoring mutation out of the physics-flush window.
	_combat_trace("Stratum1BossRoom._on_boss_died",
		"boss_died received — deferring StratumExit.activate() to clear physics flush")
	if _stratum_exit != null:
		_stratum_exit.call_deferred("activate")
	# M3-T2-W3-T17 — promote the character to "skip-eligible" on first kill.
	# Snapshotted to the v4 save schema (`character.first_boss_kill_seen`).
	# Subsequent boss rooms read this flag in `_ready` and allow the
	# collapse-on-movement path. Idempotent (no-op if already true).
	# Save write happens BEFORE the signal emits so consumers of
	# `boss_defeated` (Main._on_boss_defeated → title card) can rely on
	# the flag being persisted by the time they receive the event.
	_mark_first_boss_kill_seen()
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


# ---- M3-T2-W1-T1 + M3-T2-W2-T10 audio wiring -------------------------

## Wire `entry_sequence_completed` to the BGM crossfade so the boss-room
## music kicks in at T+1.8 s post-trigger (Uma `boss-intro.md` Beat 5).
## Idempotent on triple-wire — `Signal.is_connected` guard mirrors the
## pattern used in `Stratum1Boss._wire_audio_cues`. Production wires once
## from `_ready`; tests can call `_wire_audio_cues()` repeatedly without
## stacking handlers.
##
## **M3-T2-W2-T10 (`86c9wjyke`):** also wire `entry_sequence_started` →
## `AudioDirector.stop_stratum1_ambient(600)` so the S1 ambient bed fades
## to silence with the 600 ms ease-out cubic curve Uma's brief
## (`team/uma-ux/s1-ambient.md §"BI-03 — fade-out on boss-room entry"`)
## locks. Subscribing on `entry_sequence_started` (not `_completed`) is
## intentional — BI-03 is Beat 2 (T+0.6 hard-mute), BI-05 (boss BGM
## crossfade) is Beat 5 (T+1.8). Two different beats; the ambient duck
## must precede the BGM kick, not coincide.
func _wire_audio_cues() -> void:
	if not entry_sequence_completed.is_connected(_on_entry_sequence_completed_audio):
		entry_sequence_completed.connect(_on_entry_sequence_completed_audio)
	if not entry_sequence_started.is_connected(_on_entry_sequence_started_audio):
		entry_sequence_started.connect(_on_entry_sequence_started_audio)


## Handler — fires when the 1.8 s entry sequence elapses. Crossfades the
## BGM bus to `mus-boss-stratum1.ogg` over the AudioDirector's default
## 600 ms (Uma `boss-intro.md` Beat 5 / `audio-direction.md §3 ducking rule 4`).
##
## **M3-T2-W3-T17 skip-collapse:** if the player triggered the skip via
## movement-key press (Uma `boss-intro.md § Skip rule`), the crossfade
## uses the SKIP_BGM_FADE_MS (300 ms) instead of the default 600 ms.
## The fast fade is the audible signature of the skip — same audio
## content (`mus-boss-stratum1.ogg`), faster ramp. The 0.3 s value
## comes from Uma's brief: "boss music fades in (0.3 s)".
##
## Pre-fight there's no S1 BGM playing (M1 ships without S1 ambient/BGM —
## only the S2 entry + boss-room crossfade are wired). The crossfade
## degenerates to a fade-in from silence; the role-swap inside AudioDirector
## ensures future calls (e.g. boss-died `stop_all_music`) operate on the
## right player. Same shape as S2's pattern.
##
## Resolves AudioDirector lazily via the scene tree so headless tests that
## construct the room without an AudioDirector autoload don't crash —
## handler is a soft no-op when AudioDirector is absent. The autoload is
## present in production via `project.godot` so this branch never fires at
## runtime; the resolver is defensive against the bare-test surface.
func _on_entry_sequence_completed_audio() -> void:
	var ad: Node = _resolve_audio_director()
	if ad == null or not ad.has_method("crossfade_to_boss_stratum1"):
		return
	var fade_ms: int = SKIP_BGM_FADE_MS if _entry_sequence_skipped else DEFAULT_BGM_FADE_MS
	ad.crossfade_to_boss_stratum1(fade_ms)


## M3-T2-W2-T10 — BI-03 handler. Fires on `entry_sequence_started`
## (Beat 2 of Uma's boss-intro spec). Hard-mutes the S1 ambient bed
## over 600 ms with the ease-out cubic curve.
##
## Soft no-op when AudioDirector is absent (bare-test surface) — mirrors
## the `_on_entry_sequence_completed_audio` resolver pattern.
func _on_entry_sequence_started_audio() -> void:
	var ad: Node = _resolve_audio_director()
	if ad == null or not ad.has_method("stop_stratum1_ambient"):
		return
	ad.stop_stratum1_ambient()


func _resolve_audio_director() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("AudioDirector")


# ---- M3-T2-W3-T17 skip-after-first-kill (ticket 86c9wjzjf) ----------
#
# The boss intro is 1.8 s of theatre that ALL players see on their first
# kill. After that first kill, subsequent intros become repetitive; the
# Skip rule lets veterans collapse the cinematic with a movement-key
# press during Beats 2–4. Beat 1 (door slam, 0.0 → 0.4 s) always plays
# at full duration — it's the irreducible "this is a boss room" cue.
#
# Per Uma `boss-intro.md § Skip rule`:
#   "After the first boss kill of the player's lifetime (per-character
#    flag, saves to disk), the boss intro can be skipped by pressing any
#    movement key during Beats 2–4. The skip collapses to: door slam
#    (always plays), nameplate slides in (0.2 s, faster), boss music
#    fades in (0.3 s). Skip is not advertised — it's discovered, like
#    Esc-skip on the death sequence."
#
# Implementation shape:
#   1. `_load_first_boss_kill_seen()` on `_ready` → `_skip_eligible`.
#   2. `_unhandled_input` consumes movement actions ONLY during the
#      eligible + active + not-yet-skipped + not-yet-completed window.
#   3. `_collapse_entry_sequence()` cancels the natural 1.8 s timer and
#      schedules `_complete_entry_sequence` after a short residual
#      (`SKIP_COLLAPSE_RESIDUAL_FLOOR_S` floor; dynamically read from
#      `Stratum1Boss.WAKE_DURATION` per the brief — so the visual wake
#      animation still has its natural runway).
#   4. `_on_boss_died` calls `_mark_first_boss_kill_seen()` to promote
#      future fights to eligible-state via the v4 save schema.
#
# Reading + writing the flag uses the same idiom as
# `StatAllocationPanel._has_seen_first_level_up` / `_mark_first_level_up_seen`
# — load_game / mutate the character dict / save_game. Snapshots
# adjacent runtime state via `_snapshot_into_save` so the flag write
# doesn't clobber Player HP / Levels / Inventory.

## Input handler — consumes movement-key press events during the skip
## window and dispatches to `_collapse_entry_sequence`. Uses
## `_unhandled_input` (not `_input`) because movement keys do NOT
## overlap with Godot's built-in GUI input semantics (Tab focus, Space
## button-activate, etc.) — the `_input` exception documented in
## `.claude/docs/html5-export.md § "Godot input handling order"` does
## not apply here. `_unhandled_input` is the right surface because it
## lets the InventoryPanel / StatAllocationPanel modal `_input` handlers
## consume their shortcuts first; the boss-room skip is gameplay, not
## modal UI.
##
## Gates checked in order (early-return on any miss to keep the hot
## path lean — `_unhandled_input` fires for every keypress in the
## scene tree):
##
##   1. `_skip_eligible`        — character has killed the boss before
##   2. `_entry_sequence_active`— intro is currently running
##   3. NOT `_entry_sequence_completed` — intro has not naturally ended
##   4. NOT `_entry_sequence_skipped`   — guard against double-fire
##   5. event.is_action_pressed for any SKIP_ACTIONS member
##
## All five gates ensure the skip can ONLY fire during the intended
## window: post-trigger, pre-completion, on a movement keypress, by an
## eligible character.
func _unhandled_input(event: InputEvent) -> void:
	if not _skip_eligible:
		return
	if not _entry_sequence_active:
		return
	if _entry_sequence_completed or _entry_sequence_skipped:
		return
	# Gate the skip window — the `_entry_sequence_active && !_completed`
	# pair already brackets it tightly, but the explicit time-bound
	# guard adds a safety net against a same-tick race between the
	# natural-timer firing and a movement keypress arriving on the
	# same frame. SKIP_WINDOW_END_S = ENTRY_SEQUENCE_DURATION - 0.05.
	var elapsed_s: float = (Time.get_ticks_msec() - _entry_started_time_ms) / 1000.0
	if elapsed_s < SKIP_WINDOW_START_S or elapsed_s > SKIP_WINDOW_END_S:
		return
	for action in SKIP_ACTIONS:
		if event.is_action_pressed(action):
			_collapse_entry_sequence()
			# Consume the event so the same press isn't double-handled
			# downstream (Player's _physics_process reads Input directly,
			# not via _unhandled_input, so this consume is mostly defensive
			# against any future UI that might claim the keypress next).
			# Defensive viewport-null guard for the bare-test surface where
			# the room is constructed outside a normal scene-tree input
			# pipeline (the test may invoke _unhandled_input directly).
			var vp: Viewport = get_viewport()
			if vp != null:
				vp.set_input_as_handled()
			return


## Collapse the entry sequence — cancel the natural timer, schedule a
## short residual delay, then fire `_complete_entry_sequence`. Per Uma's
## brief, the residual is sized to overlap with the boss's wake-anim
## duration so the visual transition (boss-wake) still has its full
## runway against the collapsed music + nameplate fades.
##
## Dynamic wake-duration read: per the dispatch brief, "read the boss's
## current wake-anim duration from `Stratum1Boss` — don't hard-code."
## The boss exposes `WAKE_DURATION` as a class constant; we look it up
## via the live `_boss` instance. If the boss is absent (test surface)
## or doesn't expose the constant (future class refactor), fall back to
## SKIP_COLLAPSE_RESIDUAL_FLOOR_S (0.1 s).
##
## Total collapsed intro budget: ~0.5 s — door slam already in flight
## (0.4 s, started at T+0.0), boss music fast-fade (0.3 s, starts at
## skip + residual), nameplate fast-slide (0.2 s, when T13 nameplate
## ships). Acceptance: "skip collapses intro timing to ~0.5 s".
func _collapse_entry_sequence() -> void:
	if _entry_sequence_skipped or _entry_sequence_completed:
		return
	_entry_sequence_skipped = true
	_entry_skipped_time_ms = Time.get_ticks_msec()
	# Tween-cancel via timer disconnect — the original `_entry_timer`
	# (created in `trigger_entry_sequence`) is still in flight on its
	# natural 1.8 s schedule. Disconnect its callback so the natural
	# completion path doesn't double-fire `_complete_entry_sequence`
	# after our collapsed residual. The SceneTreeTimer itself can't be
	# canceled in Godot 4.3 — its `timeout` signal will still emit at
	# its scheduled wall-clock time, but with no subscriber it's a no-op.
	if _entry_timer != null:
		if _entry_timer.timeout.is_connected(_complete_entry_sequence):
			_entry_timer.timeout.disconnect(_complete_entry_sequence)
	_combat_trace("Stratum1BossRoom._collapse_entry_sequence",
		"skip fired at t=%dms — residual=%.3fs" % [
			_entry_skipped_time_ms - _entry_started_time_ms,
			_skip_collapse_residual_s()])
	# Emit the skip signal AHEAD of the residual delay so audio + nameplate
	# consumers can begin their fast-fade tweens immediately. The
	# `_complete_entry_sequence` call (which fires entry_sequence_completed
	# + boss.wake) lands after the residual delay so the wake-anim has
	# its visual lead-in.
	entry_sequence_skipped.emit()
	# Schedule the deferred completion. ignore_time_scale=false intentional
	# — if a future T2 hit-pause overlaps (unlikely during a boss INTRO,
	# but compose-safe), the residual delay should pause with game-time.
	# The wake-anim itself runs on game-time too; keeping the residual
	# scaled keeps the two synchronized.
	if is_inside_tree():
		var residual: float = _skip_collapse_residual_s()
		var skip_timer: SceneTreeTimer = get_tree().create_timer(residual)
		skip_timer.timeout.connect(_complete_entry_sequence)


## Dynamic wake-duration lookup. Per the dispatch brief: "read the boss's
## current wake-anim duration from `Stratum1Boss` — don't hard-code."
## Returns the floor (0.1 s) if the boss is absent or doesn't expose
## WAKE_DURATION. Tests can verify the dynamic-read shape by mutating
## the constant via a test-only setter (not yet exposed; manual constant
## edit + recompile is the current surface).
func _skip_collapse_residual_s() -> float:
	var residual: float = SKIP_COLLAPSE_RESIDUAL_FLOOR_S
	if _boss != null and is_instance_valid(_boss):
		# Class-constant access via the script — `Stratum1Boss.WAKE_DURATION`
		# is the canonical surface. Look it up defensively in case a future
		# refactor renames the constant.
		var wake_duration: float = float(Stratum1Boss.WAKE_DURATION)
		if wake_duration > residual:
			residual = wake_duration
	return residual


## Save-side helpers — mirror `StatAllocationPanel._has_seen_first_level_up`
## / `_mark_first_level_up_seen` (`scripts/ui/StatAllocationPanel.gd:569`).
## Same Save autoload, same character-block path, same defensive guards.
## Per `.claude/docs/test-conventions.md § "Universal warning gate"` — no
## new push_warning sites; Save.gd's own load path already routes through
## WarningBus for schema-newer-than-runtime, which is the only failure
## mode we'd surface through this lookup.

## Reads `character.first_boss_kill_seen` from the v4 save. Returns
## false on any miss (no save, empty data, missing character block,
## missing field). The migrate chain backfills the field on read; this
## function never sees a pre-v4 shape in practice, but guards against
## the cold-boot / no-save path defensively.
func _load_first_boss_kill_seen() -> bool:
	var save_node: Node = _save_autoload()
	if save_node == null:
		return false
	var data: Dictionary = save_node.load_game(SAVE_SLOT)
	if data.is_empty():
		return false
	var character: Variant = data.get("character", null)
	if not (character is Dictionary):
		return false
	return bool((character as Dictionary).get("first_boss_kill_seen", false))


## Promotes the character to skip-eligible by setting
## `character.first_boss_kill_seen = true` and writing back to disk.
## Idempotent — calling on an already-seen character no-ops at the
## bool level (the write still happens to keep the save consistent
## with the in-memory state, but the flag stays true).
##
## Side-effect: runs through Save.save_game's full envelope rewrite,
## which means the on-disk schema_version bumps to 4 if loaded from a
## v3 save. This is the natural migration-on-write path documented in
## `test_save_migration.gd::test_migration_leaves_envelope_schema_version_intact_on_disk_until_save`
## — load-only doesn't bump, but the boss-death write DOES.
func _mark_first_boss_kill_seen() -> void:
	var save_node: Node = _save_autoload()
	if save_node == null:
		return
	var data: Dictionary = save_node.load_game(SAVE_SLOT)
	if data.is_empty():
		data = save_node.default_payload()
	if not (data.get("character", null) is Dictionary):
		data["character"] = save_node.default_payload()["character"]
	(data["character"] as Dictionary)["first_boss_kill_seen"] = true
	save_node.save_game(SAVE_SLOT, data)


func _save_autoload() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("Save")
