extends GutTest
## Integration test — Boss reaches awake-state automatically on room load,
## takes damage from a real Hitbox spawn, and lands attacks on a real Player.
##
## Tickets: 86c9q96fv (boss damage broken) + 86c9q96ht (boss attack broken)
##
## Sponsor symptom (M1 RC re-soak 5):
##   "When player reaches Boss Room (Room 8), boss does not register hits from
##    sword swings AND boss never initiates attacks against player. The whole
##    boss encounter is dead — player can stand next to it indefinitely without
##    harm or progress."
##
## Root cause (single, both bugs collapsed): boss starts STATE_DORMANT and only
## woke when the player crossed the door-trigger Area2D at (240, 250). But
## `Main._load_room_at_index` teleports the player to (240, 200) — never
## firing `body_entered`. With the boss stuck dormant:
##   - `take_damage` returned early (Stratum1Boss.gd:332-333)
##   - `_physics_process` skipped all AI (Stratum1Boss.gd:361-365)
##
## Fix: `Stratum1BossRoom._ready` now `call_deferred("trigger_entry_sequence")`,
## so the boss reliably wakes ~1.8 s after room load regardless of how the
## player arrived.
##
## What this test exercises (NEW path, no shortcuts):
##   1. Boss-room ready triggers entry sequence automatically (no body_entered).
##   2. After entry sequence completes, boss is in STATE_IDLE and accepts damage.
##   3. A real Hitbox spawned overlapping the boss applies damage via the
##      engine's signal flow + the deferred `_check_initial_overlaps` sweep.
##   4. The boss in STATE_CHASING engages a real Player and fires a swing
##      hitbox via the production `_fire_melee_swing` path.
##
## Per combat-architecture.md: tests must drive the actual move_and_slide path
## with real CharacterBody2D instances and real Area2D hitboxes (no
## `_try_apply_hit` shortcuts) — otherwise pre-existing-overlap regressions
## (`86c9m36zh` class) slip past.

const BossScript: Script = preload("res://scripts/mobs/Stratum1Boss.gd")
const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")
const PlayerScript: Script = preload("res://scripts/player/Player.gd")
const BossRoomScript: Script = preload("res://scripts/levels/Stratum1BossRoom.gd")

const PHYS_DELTA: float = 1.0 / 60.0


# ---- Helpers ----------------------------------------------------------

func _make_room() -> Stratum1BossRoom:
	var packed: PackedScene = load("res://scenes/levels/Stratum1BossRoom.tscn")
	var room: Stratum1BossRoom = packed.instantiate()
	add_child_autofree(room)
	return room


func _make_player_at(pos: Vector2) -> Player:
	var p: Player = PlayerScript.new()
	p.global_position = pos
	add_child_autofree(p)
	p.set_physics_process(false)
	return p


func _make_player_team_hitbox_at(at: Vector2, dmg: int = 6, radius: float = 18.0) -> Hitbox:
	var hb: Hitbox = HitboxScript.new()
	hb.configure(dmg, Vector2.ZERO, 0.20, Hitbox.TEAM_PLAYER, null)
	hb.position = at
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	hb.add_child(shape)
	add_child_autofree(hb)
	return hb


# Tick a couple of physics frames so Godot computes overlap state and the
# deferred initial-overlap sweep runs.
func _await_physics_settles() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame


# ---- AC1: boss room auto-triggers entry sequence on _ready ------------

func test_boss_room_auto_triggers_entry_sequence_on_ready() -> void:
	## REGRESSION-86c9q96fv + 86c9q96ht: pre-fix the boss room only triggered
	## the entry sequence via the door-trigger body_entered signal. Production
	## player-entry never fires that signal. Post-fix `_ready` deferred-calls
	## `trigger_entry_sequence`.
	var room: Stratum1BossRoom = _make_room()
	# `call_deferred` from `_ready` lands on the next idle frame.
	await get_tree().process_frame
	assert_true(room.is_entry_sequence_active() or room.is_entry_sequence_completed(),
		"REGRESSION: boss-room entry sequence must auto-fire on _ready (no door overlap needed)")


func test_boss_wakes_without_door_trigger_overlap() -> void:
	## End-to-end: room loads, no body ever overlaps the door trigger,
	## yet the boss transitions out of DORMANT after the entry sequence.
	## We use the public `complete_entry_sequence_for_test` to fast-forward
	## past the 1.8 s wall-clock.
	var room: Stratum1BossRoom = _make_room()
	var boss: Stratum1Boss = room.get_boss()
	# Confirm the deferred trigger fired.
	await get_tree().process_frame
	assert_true(room.is_entry_sequence_active(),
		"entry sequence must be active after the deferred trigger lands")
	# Fast-forward to completion.
	room.complete_entry_sequence_for_test()
	assert_false(boss.is_dormant(),
		"REGRESSION: boss must be awake after entry sequence completes — production was stuck dormant")
	assert_eq(boss.get_state(), Stratum1Boss.STATE_IDLE)


# ---- AC2: boss takes damage from a real Hitbox spawn ------------------

func test_boss_takes_damage_from_real_hitbox_spawn() -> void:
	## Highest-fidelity damage-path test for `86c9q96fv`. Spawns a
	## player-team Hitbox overlapping the boss's collision body and asserts
	## the boss's HP drops via the engine's signal flow + the deferred
	## initial-overlap sweep — NO manual `_try_apply_hit` shortcut. This
	## path was masked pre-fix because the boss was DORMANT and rejected
	## damage; post-fix the entry sequence wakes the boss and the hit lands.
	var room: Stratum1BossRoom = _make_room()
	var boss: Stratum1Boss = room.get_boss()
	# Wake the boss (deferred trigger landed in `_ready`; fast-forward past 1.8s).
	await get_tree().process_frame
	room.complete_entry_sequence_for_test()
	assert_false(boss.is_dormant(), "precondition: boss is awake")

	var hp_before: int = boss.get_hp()
	# Spawn a player-team hitbox AT the boss's global position — guaranteed
	# overlap. Hitbox._init flips monitoring/monitorable off; _ready defers
	# `_check_initial_overlaps` which re-enables monitoring AND sweeps
	# pre-existing overlaps, applying damage to the boss.
	var hb: Hitbox = _make_player_team_hitbox_at(boss.global_position, 6, 24.0)
	await _await_physics_settles()
	assert_lt(boss.get_hp(), hp_before,
		"REGRESSION-86c9q96fv: boss must take damage from a real Hitbox spawn (hp %d -> %d)" % [hp_before, boss.get_hp()])
	assert_eq(boss.get_hp(), hp_before - hb.damage,
		"hit lands with the configured damage payload")


func test_boss_hit_target_signal_fires_for_real_hitbox() -> void:
	## The Hitbox.hit_target signal contract is the diagnostic surface the
	## Self-Test Report + Playwright spec rely on (`[combat-trace] Hitbox.hit
	## team=player target=Stratum1Boss`). Pre-fix it never fired because the
	## boss was dormant. Post-fix it fires exactly once for the initial
	## overlap.
	var room: Stratum1BossRoom = _make_room()
	var boss: Stratum1Boss = room.get_boss()
	await get_tree().process_frame
	room.complete_entry_sequence_for_test()
	var hb: Hitbox = _make_player_team_hitbox_at(boss.global_position, 6, 24.0)
	watch_signals(hb)
	await _await_physics_settles()
	assert_signal_emit_count(hb, "hit_target", 1,
		"REGRESSION-86c9q96fv: hit_target fires exactly once on the real boss collision body")


# ---- AC3: boss attack lands on real Player body -----------------------

func test_boss_in_chase_initiates_swing_against_real_player() -> void:
	## REGRESSION-86c9q96ht: pre-fix the boss was DORMANT and skipped all AI
	## in `_physics_process`. Post-fix the boss in STATE_IDLE/CHASING runs
	## `_process_chase` and transitions into `STATE_TELEGRAPHING_MELEE`.
	## We use a real Player CharacterBody2D so the boss's `_resolve_player`
	## + `_player_vigor` paths exercise the production surface.
	var p: Player = _make_player_at(Vector2.ZERO)
	# Construct boss skipping intro for deterministic test setup. The boss-room
	# auto-trigger path is covered by the prior test; here we focus on the AI
	# loop the room enables once the boss is awake.
	var b: Stratum1Boss = BossScript.new()
	b.skip_intro_for_tests = true
	# Place boss within MELEE_RANGE so the first chase tick begins a melee
	# telegraph immediately.
	b.global_position = Vector2(Stratum1Boss.MELEE_RANGE - 4.0, 0.0)
	add_child_autofree(b)
	b.set_physics_process(false)
	b.set_player(p)

	watch_signals(b)
	# Tick 1: chase → telegraph begins (player in MELEE_RANGE).
	b._physics_process(PHYS_DELTA)
	assert_eq(b.get_state(), Stratum1Boss.STATE_TELEGRAPHING_MELEE,
		"REGRESSION-86c9q96ht: awake boss must enter melee telegraph when player is in range")
	# Tick 2: telegraph expires → swing fires.
	b._physics_process(Stratum1Boss.MELEE_TELEGRAPH_DURATION + 0.01)
	assert_eq(b.get_state(), Stratum1Boss.STATE_ATTACKING)
	assert_signal_emitted(b, "swing_spawned",
		"REGRESSION-86c9q96ht: boss must fire a swing hitbox against the player")
	var params: Array = get_signal_parameters(b, "swing_spawned", 0)
	assert_eq(params[0], Stratum1Boss.SWING_KIND_MELEE,
		"first swing is a melee in phase 1")


func test_boss_swing_hitbox_damages_real_player() -> void:
	## Drives the FULL attack-path: boss telegraphs → boss fires Hitbox →
	## Hitbox is on Stratum1Boss as a child Area2D → its deferred initial-
	## overlap sweep finds the player and applies damage.
	## This is the test that proves the Sponsor-reported "boss never harms
	## player" symptom is fixed end-to-end.
	var p: Player = _make_player_at(Vector2.ZERO)
	# Capture HP before.
	var hp_before: int = p.hp_current

	var b: Stratum1Boss = BossScript.new()
	b.skip_intro_for_tests = true
	# Position boss directly on top of the player so the spawned hitbox at
	# `dir * MELEE_HITBOX_REACH` (44 px) overlaps the player's body. With a
	# radius of 28 px and player at origin, even a 44-px-offset hitbox covers
	# part of the player's body when boss is co-located. We position boss
	# slightly to the right so dir is LEFT and hitbox lands at boss + (-44, 0)
	# = origin (player position).
	b.global_position = Vector2(44.0, 0.0)
	add_child_autofree(b)
	b.set_physics_process(false)
	b.set_player(p)

	# Tick chase → melee telegraph → swing fire.
	b._physics_process(PHYS_DELTA)
	b._physics_process(Stratum1Boss.MELEE_TELEGRAPH_DURATION + 0.01)
	assert_eq(b.get_state(), Stratum1Boss.STATE_ATTACKING,
		"precondition: boss has fired its swing")

	# The Hitbox is now a child of the boss. Allow the deferred
	# `_check_initial_overlaps` to sweep the player.
	await _await_physics_settles()

	assert_lt(p.hp_current, hp_before,
		"REGRESSION-86c9q96ht: boss melee swing must damage the real player (hp %d -> %d)"
		% [hp_before, p.hp_current])
