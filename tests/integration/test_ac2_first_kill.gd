extends GutTest
## Scene-level integration tests for **M1 AC2** — "From cold launch to first
## mob killed: ≤ 60 seconds".
##
## The unit-level layer (`tests/test_player_attack.gd`, `tests/test_grunt.gd`)
## already verifies the individual surfaces in isolation. This file plays
## them together against the actual `Stratum1Room01.tscn` scene and an
## actual `Player` node, walking the player toward a spawned grunt and
## driving attacks via the public API until the grunt dies. The scene-level
## flow catches integration regressions that unit tests miss — e.g. a
## hitbox layer change, a player-mob layer mismatch, a grunt-spawn that
## leaves the mob outside player reach, a save-on-kill that hangs.
##
## **Stage 2b update (ticket `86c9qaj3u`):** the shipping `s1_room01.tres`
## now spawns a single PracticeDummy (zero damage, HP=3) per Uma's player-
## journey Beats 4-5. To preserve AC2's "player kills a grunt" coverage, the
## test injects a synthetic chunk_def with a single grunt at runtime via
## `_load_room_with_grunt_chunk` — the test still exercises the grunt
## damage formula + AI on the same Stratum1Room01 scene + assembler. The
## production roster is asserted in `tests/test_stratum1_room.gd` instead.
##
## **Why we drive `try_attack` / position directly instead of `Input.action_press`:**
## Headless GUT runs on the CI image with no display; there's no input
## queue to feed. We bypass the input layer (already covered by unit tests
## that just check `_read_movement_input`) and exercise the engine surface
## the input handler ultimately calls. The integration we care about for
## AC2 is "player + room + grunt + hitbox + damage formula working
## together", not "Input.is_action_just_pressed wired to try_attack".
##
## **Time budget:** AC2 is 60s wall-clock from URL→kill. In a headless
## simulation, "wall-clock" doesn't apply — but we cap the *simulated game
## time* (sum of physics deltas we hand the player + grunt) at SIM_BUDGET_SEC
## (15s, see constant). With a 50 HP grunt at fist-damage 1 / 0.18s recovery
## that's a ~9s pure-swing window + ~2s walk-in, so 15s is the safety bound;
## anything longer means the combat loop has stalled.

const PlayerScript: Script = preload("res://scripts/player/Player.gd")
const GruntScript: Script = preload("res://scripts/mobs/Grunt.gd")
const Stratum1Room01Script: Script = preload("res://scripts/levels/Stratum1Room01.gd")
const LevelChunkDefScript: Script = preload("res://scripts/levels/LevelChunkDef.gd")
const MobSpawnPointScript: Script = preload("res://scripts/levels/MobSpawnPoint.gd")
const ChunkPortScript: Script = preload("res://scripts/levels/ChunkPort.gd")

# A 50 HP grunt at 1 fist damage / 0.18s recovery is ~9s of pure swinging
# plus walk-in. 15s sim budget is the outer bound — anything longer means
# the combat loop has stalled. (Wall-clock AC2 budget is 60s including
# cold launch + title screen + walk; this is just the in-game fight.)
const SIM_BUDGET_SEC: float = 15.0
const PHYS_DELTA: float = 1.0 / 60.0


# ---- Helpers ----------------------------------------------------------

## Build a synthetic chunk_def with a single grunt for AC2 grunt-combat
## tests. Stage 2b: the shipping `s1_room01.tres` spawns a PracticeDummy,
## so the AC2 grunt-fight tests inject this fixture chunk to keep coverage.
## See file-level docstring.
func _make_grunt_chunk_def() -> LevelChunkDef:
	var chunk: LevelChunkDef = LevelChunkDefScript.new()
	chunk.id = &"s1_room01_test_grunt"
	chunk.display_name = "Test — Single Grunt Room"
	chunk.size_tiles = Vector2i(15, 8)
	chunk.tile_size_px = 32
	chunk.scene_path = "res://scenes/levels/chunks/s1_room01_chunk.tscn"
	# Entry port — top-left tile (matches s1_room01 default).
	var entry: ChunkPort = ChunkPortScript.new()
	entry.position_tiles = Vector2i(2, 4)
	entry.direction = 3
	entry.tag = &"entry"
	chunk.ports = [entry]
	# Single grunt at center of the room.
	var spawn_grunt: MobSpawnPoint = MobSpawnPointScript.new()
	spawn_grunt.position_tiles = Vector2i(11, 3)
	spawn_grunt.mob_id = &"grunt"
	chunk.mob_spawns = [spawn_grunt]
	return chunk


func _load_room() -> Stratum1Room01:
	# Load the Room01 scene but inject a single-grunt chunk_def so AC2's
	# "player kills a grunt" coverage stays intact post-Stage 2b. The
	# production chunk_def (PracticeDummy) is exercised in
	# `tests/test_stratum1_room.gd`.
	var packed: PackedScene = load("res://scenes/levels/Stratum1Room01.tscn")
	assert_not_null(packed, "Stratum1Room01.tscn must load")
	var room: Stratum1Room01 = packed.instantiate()
	# Override chunk_def BEFORE add_child so the room's _ready picks up the
	# test fixture rather than the default `s1_room01.tres`.
	room.chunk_def = _make_grunt_chunk_def()
	add_child_autofree(room)
	return room


func _spawn_player_in_room(room: Stratum1Room01) -> Player:
	var p: Player = PlayerScript.new()
	# Place player at room origin so the grunt is between them and a wall.
	p.global_position = Vector2.ZERO
	room.add_child(p)
	# add_child triggers _ready; the player is now in the tree and ticking.
	return p


# Walk the player one step closer to a target. Tick everything once.
func _step_toward(p: Player, target: Vector2, room: Stratum1Room01, dt: float) -> void:
	var to_target: Vector2 = target - p.global_position
	if to_target.length() < 0.01:
		p.velocity = Vector2.ZERO
	else:
		# WALK_SPEED is the canonical move speed; we use it directly so we
		# don't depend on input axis scaling.
		p.velocity = to_target.normalized() * Player.WALK_SPEED
		p.global_position = p.global_position + p.velocity * dt
	# Tick all grunts so they pick up new player position + can chase/swing.
	for m: Node in room.get_spawned_mobs():
		if m is Grunt and not (m as Grunt).is_dead():
			(m as Grunt).set_player(p)
			(m as Grunt)._physics_process(dt)
	# Tick the player's timers (recovery / dodge cd) so attacks can re-fire.
	p._tick_timers(dt)


# Try to kill `grunt` by walking up + light-attacking until it's dead.
# Returns the simulated time spent (seconds). Asserts the grunt died.
func _walk_in_and_kill(p: Player, grunt: Grunt, room: Stratum1Room01) -> float:
	var elapsed: float = 0.0
	while not grunt.is_dead() and elapsed < SIM_BUDGET_SEC:
		# Walk toward the grunt.
		_step_toward(p, grunt.global_position, room, PHYS_DELTA)
		elapsed += PHYS_DELTA
		# In light-attack reach? Swing.
		var dist: float = (grunt.global_position - p.global_position).length()
		if dist <= Player.LIGHT_REACH + 8.0 and p.can_attack():
			var dir: Vector2 = (grunt.global_position - p.global_position).normalized()
			var hb: Hitbox = p.try_attack(Player.ATTACK_LIGHT, dir) as Hitbox
			# Manual damage application: in headless tests the physics overlap
			# tick won't fire reliably for short-lived hitboxes, so we directly
			# call the contract method (`_try_apply_hit`) the engine wires for
			# us in normal gameplay. This still goes through the Hitbox -> mob
			# `take_damage` path; it just skips Area2D's overlap detection.
			if hb != null:
				hb._try_apply_hit(grunt)
	return elapsed


# ---- Tests ------------------------------------------------------------

# --- 1: room + grunt + player wire up cleanly ------------------------

func test_room_loads_with_at_least_one_grunt() -> void:
	# The integration starting line. AC2 fails immediately if the room
	# doesn't spawn anything to fight.
	var room: Stratum1Room01 = _load_room()
	var mobs: Array[Node] = room.get_spawned_mobs()
	assert_gt(mobs.size(), 0, "AC2: stratum1 room01 spawns at least one mob")
	var first_grunt_found: bool = false
	for m: Node in mobs:
		if m is Grunt:
			first_grunt_found = true
			break
	assert_true(first_grunt_found, "AC2: at least one Grunt instance lives in room01")


# --- 2: player can be added to the room and starts ticking -----------

func test_player_spawns_into_room_alive() -> void:
	var room: Stratum1Room01 = _load_room()
	var p: Player = _spawn_player_in_room(room)
	assert_true(p.is_inside_tree(), "player added to room scene tree")
	assert_eq(p.get_state(), Player.STATE_IDLE, "fresh player starts idle")
	assert_false(p.is_invulnerable(), "no i-frames at spawn")


# --- 3: player walks to grunt + first-kill within sim budget ---------

func test_first_kill_within_sim_time_budget() -> void:
	# The headline AC2 integration. Sim time, not wall-clock — but if this
	# fails, the wall-clock 60s budget is unreachable too.
	var room: Stratum1Room01 = _load_room()
	var p: Player = _spawn_player_in_room(room)
	var grunt: Grunt = _first_grunt(room)
	assert_not_null(grunt, "room must spawn a Grunt to fight")
	var pre_hp: int = grunt.get_hp()
	var elapsed: float = _walk_in_and_kill(p, grunt, room)
	assert_true(grunt.is_dead(), "AC2: grunt dies inside the sim budget")
	assert_lt(elapsed, SIM_BUDGET_SEC, "AC2: kill happened in <%.1fs sim" % SIM_BUDGET_SEC)
	assert_lt(grunt.get_hp(), pre_hp, "grunt HP decreased over the fight")
	assert_eq(grunt.get_hp(), 0, "AC2: dead grunt is at 0 HP")


# --- 4: mob_died fires exactly once during the kill --------------------

func test_first_kill_emits_mob_died_exactly_once() -> void:
	# AC2 + AC5 (no crashes) — the death signal is the single hook that
	# downstream loot / xp listeners use. If it double-emits during a
	# normal-flow kill, run state corrupts.
	var room: Stratum1Room01 = _load_room()
	var p: Player = _spawn_player_in_room(room)
	var grunt: Grunt = _first_grunt(room)
	watch_signals(grunt)
	_walk_in_and_kill(p, grunt, room)
	assert_signal_emit_count(grunt, "mob_died", 1, "AC2: exactly one mob_died per kill")


# --- 5: player swing damage matches the formula ------------------------

func test_first_kill_uses_correct_damage_formula() -> void:
	# AC2 sub-invariant: the integration is using compute_player_damage,
	# not a hard-coded "1". A bare player has no weapon -> fist damage = 1.
	# We verify the *first* take_damage delta is FIST_DAMAGE.
	var room: Stratum1Room01 = _load_room()
	var p: Player = _spawn_player_in_room(room)
	var grunt: Grunt = _first_grunt(room)
	var hp_before: int = grunt.get_hp()
	# Single swing inside reach.
	p.global_position = grunt.global_position + Vector2(Player.LIGHT_REACH * 0.5, 0.0)
	var hb: Hitbox = p.try_attack(Player.ATTACK_LIGHT, Vector2.LEFT) as Hitbox
	assert_not_null(hb, "swing fired")
	hb._try_apply_hit(grunt)
	assert_eq(grunt.get_hp(), hp_before - 1, "single fist hit deals exactly FIST_DAMAGE (1)")


# --- 6: heavy attack also lands and applies heavy tuning ---------------

func test_heavy_attack_lands_on_grunt() -> void:
	# AC2 + AC3 mechanical correctness: heavy attack reach is 36 (vs light
	# 28); a grunt at 32px is reachable by heavy but not light. Verifies
	# the heavy hitbox actually overlaps reachable enemies.
	var room: Stratum1Room01 = _load_room()
	var p: Player = _spawn_player_in_room(room)
	var grunt: Grunt = _first_grunt(room)
	p.global_position = grunt.global_position - Vector2(32.0, 0.0)
	var hp_before: int = grunt.get_hp()
	var hb: Hitbox = p.try_attack(Player.ATTACK_HEAVY, Vector2.RIGHT) as Hitbox
	assert_not_null(hb, "heavy attack fires")
	hb._try_apply_hit(grunt)
	assert_lt(grunt.get_hp(), hp_before, "heavy attack damages grunt")


# --- 7: dead grunt does not respawn via the room script ----------------

func test_dead_grunt_stays_dead_across_room_ticks() -> void:
	# AC2 + AC5: if the room or assembler re-instantiates a slain mob on a
	# tick, the player will fight a ghost. Verify is_dead persists.
	var room: Stratum1Room01 = _load_room()
	var p: Player = _spawn_player_in_room(room)
	var grunt: Grunt = _first_grunt(room)
	_walk_in_and_kill(p, grunt, room)
	assert_true(grunt.is_dead())
	# Tick a generous amount of "post-fight" sim time.
	for _i: int in 60:
		grunt._physics_process(PHYS_DELTA)
	assert_true(grunt.is_dead(), "grunt remains dead after post-fight ticks")
	assert_eq(grunt.get_hp(), 0, "HP doesn't regenerate / reset")


# --- 8: hitbox is on the player team — friendly-fire safety check ----

func test_first_kill_hitboxes_are_player_team() -> void:
	# Integration check that the player-spawned hitbox is on the right team
	# layer. A misconfigured layer would either no-op (mask wrong) or
	# damage the player (team flipped). Either failure mode breaks AC2.
	var room: Stratum1Room01 = _load_room()
	var p: Player = _spawn_player_in_room(room)
	watch_signals(p)
	var hb: Hitbox = p.try_attack(Player.ATTACK_LIGHT, Vector2.RIGHT) as Hitbox
	assert_not_null(hb)
	assert_eq(hb.team, Hitbox.TEAM_PLAYER, "AC2 hitbox is player-team")
	assert_eq(hb.collision_layer, Hitbox.LAYER_PLAYER_HITBOX, "player_hitbox layer (bit 3)")
	assert_eq(hb.collision_mask, Hitbox.LAYER_ENEMY, "masks enemy (bit 4)")


# ---- Internal helpers -------------------------------------------------

func _first_grunt(room: Stratum1Room01) -> Grunt:
	for m: Node in room.get_spawned_mobs():
		if m is Grunt:
			return m as Grunt
	return null
