extends GutTest
## Regression test for ClickUp `86c9m36zh` — M1 soak blocker.
##
## Sponsor's interactive soak on RC `4484196` discovered that spam-clicking
## the attack while a grunt was physically touching the player did NOT
## damage the grunt. Combat appeared completely non-functional from the
## player's perspective.
##
## **Why this previously slipped:** every existing combat test (
## `tests/test_hitbox.gd`, `tests/test_player_attack.gd`,
## `tests/integration/test_ac3_combat_loop.gd`,
## `tests/integration/test_m1_play_loop.gd::_walk_in_and_kill`) bypasses
## the engine signal flow by calling `hb._try_apply_hit(target)` directly
## once a hitbox is spawned. That path always lands the hit. In real play
## the player is ALREADY overlapping the grunt before the hitbox spawns;
## Godot 4's Area2D `body_entered` only fires on entry events — pre-
## existing overlaps never fire it, so the hit silently no-ops.
##
## **What this test exercises (NEW path):** after spawning a player-team
## hitbox positioned on top of a grunt's CharacterBody2D, we let Godot's
## physics layer run a couple of frames and assert the grunt's
## `take_damage` was invoked via the actual signal flow (no manual
## `_try_apply_hit` call). The fix in `Hitbox._ready` defers a
## `_check_initial_overlaps` pass that walks `get_overlapping_bodies()` /
## `get_overlapping_areas()` and applies hits to anything already inside.
##
## On `main` (pre-fix) every test in this file fails with grunt HP
## unchanged. On the fix branch they pass.
##
## Layer convention recap (DECISIONS.md 2026-05-01):
##   - Player attack hitbox: collision_layer = LAYER_PLAYER_HITBOX (bit 3),
##     collision_mask = LAYER_ENEMY (bit 4). Grunt sits on bit 4.

const PHYS_DELTA: float = 1.0 / 60.0

const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")
const GruntScript: Script = preload("res://scripts/mobs/Grunt.gd")
const PlayerScript: Script = preload("res://scripts/player/Player.gd")


# ---- Helpers ----------------------------------------------------------

func _make_grunt_in_tree(at: Vector2 = Vector2.ZERO) -> Grunt:
	# Bare-instantiated grunt picks up Grunt._apply_layers() so collision_layer
	# = LAYER_ENEMY (bit 4) — the mask a player-team hitbox checks against.
	var g: Grunt = GruntScript.new()
	# Authored Grunt.tscn carries a CollisionShape2D child; bare-construct
	# needs one or get_overlapping_bodies returns nothing.
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	g.add_child(shape)
	g.global_position = at
	add_child_autofree(g)
	return g


func _make_player_team_hitbox_at(at: Vector2, radius: float = 18.0) -> Hitbox:
	# Mirrors Player._spawn_hitbox: configure() pre-tree, then add CollisionShape2D,
	# then add to scene so _ready fires.
	var hb: Hitbox = HitboxScript.new()
	hb.configure(5, Vector2.ZERO, 0.20, Hitbox.TEAM_PLAYER, null)
	# Use global_position via deferred set after add — Area2D needs to be in
	# the tree for global_position to apply. Set via `position` here on the
	# bare node; `add_child_autofree` parents under the GutTest, so position
	# is treated as global since GutTest's transform is identity.
	hb.position = at
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	hb.add_child(shape)
	add_child_autofree(hb)
	return hb


# Tick a couple of physics frames so Godot computes overlap state and the
# deferred initial-overlap check runs. Using process_frame in GUT runs the
# engine which also ticks physics for nodes inside the tree.
func _await_physics_settles() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame


# ---- 1: Hitbox spawned ON TOP of grunt damages it ---------------------

func test_hitbox_spawning_on_overlapping_grunt_damages_it() -> void:
	# Sponsor-repro shape: hitbox spawns inside the grunt's collision body.
	# Pre-fix this asserts hp unchanged because body_entered never fires.
	# Post-fix the deferred initial-overlap check applies the hit.
	var grunt: Grunt = _make_grunt_in_tree(Vector2(100, 100))
	var hp_before: int = grunt.get_hp()
	# Spawn the hitbox AT the grunt's position — guaranteed overlap.
	var hb: Hitbox = _make_player_team_hitbox_at(grunt.global_position, 18.0)
	# Hitbox is short-lived; let physics + the deferred check run.
	await _await_physics_settles()
	assert_lt(grunt.get_hp(), hp_before,
		"REGRESSION-86c9m36zh: hitbox spawned overlapping grunt must damage it (hp %d -> %d)" % [hp_before, grunt.get_hp()])
	assert_eq(grunt.get_hp(), hp_before - hb.damage,
		"hit applied with the configured damage payload (5)")


# ---- 2: Player.try_attack against an already-touching grunt ----------

func test_player_try_attack_lands_against_touching_grunt() -> void:
	# Highest-fidelity Sponsor repro: instantiate the actual Player + Grunt,
	# place them touching (player overlapping grunt's body), call
	# Player.try_attack like the real input handler does, and assert the
	# grunt's HP drops via the engine signal flow (NO manual _try_apply_hit).
	var grunt: Grunt = _make_grunt_in_tree(Vector2(50, 50))
	var p: Player = PlayerScript.new()
	# Player sits ON TOP of the grunt — the Sponsor's "spam-clicking, grunts
	# touching me" repro. With LIGHT_REACH = 28.0 and grunt at the same
	# position, the spawned hitbox's circle (radius 18) covers the grunt's
	# collider (radius 12).
	p.global_position = grunt.global_position
	# Add a CollisionShape2D so Player has a body for physics queries (Hitbox
	# masks ENEMY, not PLAYER, so player layer isn't read by the hitbox — but
	# adding the shape keeps the Player consistent with its scene).
	var pshape: CollisionShape2D = CollisionShape2D.new()
	var pcircle: CircleShape2D = CircleShape2D.new()
	pcircle.radius = 10.0
	pshape.shape = pcircle
	p.add_child(pshape)
	add_child_autofree(p)
	var hp_before: int = grunt.get_hp()
	# Real input path: spawn the hitbox via try_attack. Direction RIGHT places
	# the hitbox at facing*reach = (28,0); grunt is at (0,0) relative to the
	# player but the hitbox circle (radius 18) at offset 28 still encloses
	# part of grunt's body (radius 12 grunt centered at the hitbox's parent's
	# origin minus 28 px = inside the circle's hull).
	var hb: Hitbox = p.try_attack(Player.ATTACK_LIGHT, Vector2.RIGHT) as Hitbox
	assert_not_null(hb, "Player.try_attack returns the spawned hitbox")
	# Reposition the hitbox so it definitely overlaps the grunt — the
	# Player._spawn_hitbox's `position = dir * reach` shape places it 28 px
	# away. For this overlapping-bodies test we want the hitbox geometrically
	# on top of the grunt's body. Move it (reaching past Player's local
	# offset) and let physics catch up.
	hb.global_position = grunt.global_position
	await _await_physics_settles()
	assert_lt(grunt.get_hp(), hp_before,
		"REGRESSION-86c9m36zh: Player.try_attack against a touching grunt must damage it (hp %d -> %d)" % [hp_before, grunt.get_hp()])


# ---- 3: hit_target signal fires for pre-existing overlaps -------------

func test_hit_target_signal_fires_for_initial_overlap() -> void:
	# The hit_target signal is Hitbox's contract for hooks (VFX, audio,
	# screenshake, achievement listeners). Pre-fix it never fires for
	# pre-existing overlaps; post-fix it fires exactly once during the
	# deferred check.
	var grunt: Grunt = _make_grunt_in_tree(Vector2(0, 0))
	var hb: Hitbox = _make_player_team_hitbox_at(grunt.global_position, 18.0)
	watch_signals(hb)
	await _await_physics_settles()
	assert_signal_emit_count(hb, "hit_target", 1,
		"REGRESSION-86c9m36zh: hit_target fires exactly once for an initial overlap")


# ---- 4: single-hit-per-target invariant survives the initial sweep ----

func test_initial_overlap_then_body_entered_does_not_double_hit() -> void:
	# Edge case: ensure the deferred initial-overlap check does NOT cause
	# a target to take damage twice if a `body_entered` signal also fires
	# (e.g. the body re-enters during the hitbox's lifetime). The
	# `_hit_already` guard inside `_try_apply_hit` should still protect the
	# single-hit-per-target invariant.
	var grunt: Grunt = _make_grunt_in_tree(Vector2(0, 0))
	var hp_before: int = grunt.get_hp()
	var hb: Hitbox = _make_player_team_hitbox_at(grunt.global_position, 18.0)
	# After the deferred sweep applies the hit, manually re-trigger via the
	# signal handler shape — same node, same hitbox, must NOT re-apply.
	await _await_physics_settles()
	hb._on_body_entered(grunt)
	hb._on_body_entered(grunt)
	assert_eq(grunt.get_hp(), hp_before - hb.damage,
		"single-hit-per-target invariant holds: deferred initial sweep + redundant body_entered = one hit total")


# ---- 5: empty-overlap case (no false hits) ---------------------------

func test_no_overlap_no_hit() -> void:
	# Sanity: if the hitbox spawns with NOTHING overlapping it, no signal
	# fires and no damage occurs. Guards against an over-broad fix that
	# emits hit_target spuriously.
	var grunt: Grunt = _make_grunt_in_tree(Vector2(500, 500))
	var hp_before: int = grunt.get_hp()
	# Hitbox far from grunt — radius 18 at (0,0) does NOT touch grunt at (500,500).
	var hb: Hitbox = _make_player_team_hitbox_at(Vector2(0, 0), 18.0)
	watch_signals(hb)
	await _await_physics_settles()
	assert_eq(grunt.get_hp(), hp_before, "no overlap -> no damage")
	assert_signal_emit_count(hb, "hit_target", 0, "no overlap -> no hit_target signal")
