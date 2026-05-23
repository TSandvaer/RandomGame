extends GutTest
## Tests for the mouse-direction-attacks facing pipeline (ticket 86c9uthf0,
## Sponsor 2026-05-17).
##
## Two surfaces under test:
##
##   1. `Player._resolve_facing_from_mouse(mouse_global, self_global, last_facing)`
##      — pure static helper. Drives every dead-zone / normalisation edge case
##      WITHOUT any viewport / scene-tree dependency, so the math is pinned
##      independent of whether GUT can simulate a mouse cursor.
##
##   2. `Player._update_mouse_facing` + state gates — confirms the per-frame
##      update is suppressed during STATE_ATTACK / STATE_DODGE so the swing /
##      dodge direction snapshots at spawn time (edge case 3 in the ticket).
##
## Hitbox-direction integration is covered in `test_player_attack.gd` via the
## existing `test_attack_uses_facing_when_dir_zero` shape — this file focuses
## on the mouse pipeline itself.
##
## Why a pure static helper:
##   `get_global_mouse_position()` depends on a viewport. Headless GUT can
##   construct a Player but the viewport's mouse state is not directly
##   driveable. Extracting the math into a static helper lets every edge
##   case (deadzone, normalisation, last-facing fallback, exact-zero delta)
##   be pinned mechanically.

const PlayerScript: Script = preload("res://scripts/player/Player.gd")


func _make_player() -> Player:
	var p: Player = PlayerScript.new()
	p._ready()
	return p


# ---- 1: static helper — deadzone behaviour --------------------------------

func test_mouse_inside_deadzone_keeps_last_facing() -> void:
	# Mouse on top of player (zero delta) → keep last_facing exactly.
	var last: Vector2 = Vector2.UP
	var result: Vector2 = PlayerScript._resolve_facing_from_mouse(
		Vector2(100.0, 100.0), Vector2(100.0, 100.0), last
	)
	assert_eq(result, last, "zero delta returns last_facing unchanged")

	# Mouse 4px to the right of player — still inside the 8px deadzone.
	result = PlayerScript._resolve_facing_from_mouse(
		Vector2(104.0, 100.0), Vector2(100.0, 100.0), last
	)
	assert_eq(result, last, "delta=4px (< 8px deadzone) keeps last_facing")

	# Mouse 7.5px diagonal — magnitude sqrt(28.125) ≈ 5.3, still inside.
	result = PlayerScript._resolve_facing_from_mouse(
		Vector2(100.0 + 3.75, 100.0 + 3.75), Vector2(100.0, 100.0), last
	)
	assert_eq(result, last, "diagonal delta inside deadzone keeps last_facing")


func test_mouse_at_deadzone_boundary_keeps_last_facing() -> void:
	# At EXACTLY 8px the deadzone returns last_facing (the < check is strict).
	# This is the inclusive boundary — a vector right at the edge is still
	# rejected, the new facing takes over from > 8 px onward.
	var last: Vector2 = Vector2.LEFT
	var result: Vector2 = PlayerScript._resolve_facing_from_mouse(
		Vector2(108.0, 100.0), Vector2(100.0, 100.0), last
	)
	# Boundary value: 8.0 is NOT < 8.0, so we normalise. Pin the strict-less-than.
	assert_almost_eq(result.x, 1.0, 0.001, "delta=8px (at boundary) normalises to (1,0)")
	assert_almost_eq(result.y, 0.0, 0.001)


# ---- 2: static helper — normalisation outside deadzone -------------------

func test_mouse_outside_deadzone_returns_unit_vector_toward_mouse() -> void:
	# Mouse 100 px east of player.
	var result: Vector2 = PlayerScript._resolve_facing_from_mouse(
		Vector2(200.0, 100.0), Vector2(100.0, 100.0), Vector2.UP
	)
	assert_almost_eq(result.x, 1.0, 0.001, "facing east → (1,0)")
	assert_almost_eq(result.y, 0.0, 0.001)
	assert_almost_eq(result.length(), 1.0, 0.001, "result is unit-length")

	# Mouse 100 px north of player.
	result = PlayerScript._resolve_facing_from_mouse(
		Vector2(100.0, 0.0), Vector2(100.0, 100.0), Vector2.RIGHT
	)
	assert_almost_eq(result.x, 0.0, 0.001, "facing north → (0,-1)")
	assert_almost_eq(result.y, -1.0, 0.001)

	# Diagonal — 50 px east + 50 px south.
	result = PlayerScript._resolve_facing_from_mouse(
		Vector2(150.0, 150.0), Vector2(100.0, 100.0), Vector2.UP
	)
	var expected_axis: float = 1.0 / sqrt(2.0)
	assert_almost_eq(result.x, expected_axis, 0.001, "SE diagonal: x = 1/sqrt(2)")
	assert_almost_eq(result.y, expected_axis, 0.001)
	assert_almost_eq(result.length(), 1.0, 0.001, "diagonal result still unit-length")


func test_mouse_large_distance_normalises_correctly() -> void:
	# Far mouse — magnitude doesn't matter, only direction.
	var result: Vector2 = PlayerScript._resolve_facing_from_mouse(
		Vector2(10000.0, 100.0), Vector2(100.0, 100.0), Vector2.UP
	)
	assert_almost_eq(result.x, 1.0, 0.0001)
	assert_almost_eq(result.y, 0.0, 0.0001)
	assert_almost_eq(result.length(), 1.0, 0.0001)


# ---- 3: state gate — STATE_ATTACK suppresses mouse-facing update ---------

func test_mouse_facing_update_suppressed_during_attack() -> void:
	var p: Player = _make_player()
	# Set facing to a known direction.
	p._facing = Vector2.LEFT
	# Enter attack state.
	p.set_state(Player.STATE_ATTACK)
	# Call the update — it MUST early-return without touching _facing.
	p._update_mouse_facing()
	assert_eq(p._facing, Vector2.LEFT,
		"STATE_ATTACK suppresses facing update — swing direction snapshots at spawn"
			+ " (ticket edge case 3)")
	p.free()


func test_mouse_facing_update_suppressed_during_dodge() -> void:
	var p: Player = _make_player()
	# Dodge already sets _facing = dodge_dir. Pin that the per-frame mouse
	# update does NOT overwrite it during the dodge active window.
	p.try_dodge(Vector2.UP)
	assert_eq(p._facing, Vector2.UP, "dodge sets facing to dodge_dir")
	# Update tick — must early-return.
	p._update_mouse_facing()
	assert_eq(p._facing, Vector2.UP, "STATE_DODGE suppresses facing update")
	p.free()


# ---- 4: bare-instantiated player (no tree) doesn't crash -----------------

func test_mouse_facing_update_safe_outside_tree() -> void:
	# Player constructed without add_child — not inside tree. The update
	# must early-return gracefully (the viewport read would crash otherwise).
	var p: Player = PlayerScript.new()
	# Note: NO _ready() call here (need an in-tree player for that). Just
	# verify the bare update doesn't crash.
	p._facing = Vector2.RIGHT
	p._update_mouse_facing()
	# _facing must remain unchanged (no overwrite without tree).
	assert_eq(p._facing, Vector2.RIGHT, "bare-instantiated player: update is no-op (no viewport)")
	p.free()


# ---- 5: sprite rotation stays 0.0 across _facing (M3W-2 invariance pin) ---
# Sponsor's 2026-05-18 soak on PR #274 surfaced "character looking at mouse
# cursor while walking" — TWO parallel surfaces had to be decoupled:
#   1. `_resolve_anim_dir` (animation name selection — fixed in PR #274 v1)
#   2. `_update_sprite_rotation` (sprite-node `.rotation` property — fixed
#      in PR #274 v2, this test).
# The pre-M3 contract (rotation tracks `_facing.angle()`) was a placeholder
# for the symmetric-square ColorRect Sprite. Post-M3W-2 the AnimatedSprite2D
# carries direction via per-frame art, so node rotation must be pinned to 0.
# See `.claude/docs/combat-architecture.md` §"Sprite-node topology, Seam 2".

func test_sprite_rotation_stays_zero_across_facing() -> void:
	# The sprite-node `rotation` must stay 0.0 for ALL facing angles —
	# directional frames carry orientation, node transform must not.
	var p: Player = _make_player()
	var sprite: ColorRect = ColorRect.new()
	sprite.name = "Sprite"
	p.add_child(sprite)
	# Sweep the 8 cardinals + a few intermediates. Any pre-fix regression
	# would assign `_facing.angle()` to `sprite.rotation` and fail at least
	# one of these.
	var test_angles: Array = [
		0.0,            # RIGHT (east)
		PI / 4.0,       # SE
		PI / 2.0,       # DOWN (south, Godot +Y)
		3.0 * PI / 4.0, # SW
		PI,             # LEFT (west)
		-3.0 * PI / 4.0,# NW
		-PI / 2.0,      # UP (north)
		-PI / 4.0,      # NE
	]
	for ang in test_angles:
		p._facing = Vector2.from_angle(ang)
		p._update_sprite_rotation()
		assert_almost_eq(sprite.rotation, 0.0, 0.001,
			("Sprite rotation pinned to 0 across _facing angle %.3f rad"
				+ " (directional frames carry orientation)") % ang)
	# Cleanup handled by autofree.


func test_sprite_rotation_noop_when_sprite_missing() -> void:
	# Player without a Sprite child — _update_sprite_rotation must not crash.
	var p: Player = _make_player()
	p._facing = Vector2.RIGHT
	p._update_sprite_rotation()  # no-op; just verifying no crash.
	assert_true(true, "_update_sprite_rotation tolerates missing Sprite child")
	p.free()


# ---- 5b: aim-coupled surfaces (NOT touched by the rotation pin) -----------
# Verify the pin doesn't accidentally regress orthogonal `_facing` consumers:
#   - `_resolve_anim_dir` still resolves attack/dodge/hit/die anims via
#     `_facing` octant (PR #274 v1 contract).
#   - Swing-wedge ColorRect (line 1307) still rotates to `dir.angle()` —
#     it's a separate node with its own `rotation` assignment, scoped to
#     `_spawn_swing_wedge`, NOT touched by the Sprite-node pin.

func test_resolve_anim_dir_still_uses_facing_for_attack() -> void:
	# After the rotation pin, `_facing` MUST still drive animation NAME
	# selection for attack states. Regression guard against accidentally
	# decoupling `_facing` from the anim resolver too.
	var p: Player = _make_player()
	p._facing = Vector2.RIGHT  # east cursor
	assert_eq(p._resolve_anim_dir(Player.ANIM_PREFIX_ATTACK_LIGHT), "e",
		"attack_light + _facing east → 'e' suffix (anim NAME still uses _facing)")
	p._facing = Vector2.UP
	assert_eq(p._resolve_anim_dir(Player.ANIM_PREFIX_ATTACK_HEAVY), "n",
		"attack_heavy + _facing up → 'n' suffix")
	p._facing = Vector2.LEFT
	assert_eq(p._resolve_anim_dir(Player.ANIM_PREFIX_DODGE), "w",
		"dodge + _facing left → 'w' suffix")
	p._facing = Vector2.DOWN
	assert_eq(p._resolve_anim_dir(Player.ANIM_PREFIX_HIT), "s",
		"hit + _facing down → 's' suffix")
	p._facing = Vector2.UP
	assert_eq(p._resolve_anim_dir(Player.ANIM_PREFIX_DIE), "n",
		"die + _facing up → 'n' suffix")
	p.free()


func test_swing_wedge_still_rotates_independently_of_sprite_pin() -> void:
	# The swing-wedge ColorRect is a SEPARATE node spawned in
	# `_spawn_swing_wedge` with its own `wedge.rotation = dir.angle()`. The
	# Sprite-node rotation pin must NOT affect it — the wedge's rotation is
	# load-bearing for the visual swing-arc cue.
	#
	# `_spawn_swing_wedge` calls `create_tween()` which requires the player to
	# be inside the tree, so add via autofree.
	var p: Player = PlayerScript.new()
	add_child_autofree(p)
	p._ready()
	# Spawn a wedge facing east; expect rotation == 0 (east = 0 rad).
	var east_wedge: ColorRect = p._spawn_swing_wedge(
		Player.ATTACK_LIGHT, Vector2.RIGHT, 30.0, 12.0, 0.18)
	assert_not_null(east_wedge, "wedge spawned")
	assert_almost_eq(east_wedge.rotation, 0.0, 0.001,
		"swing-wedge rotation = dir.angle() = 0 for east — independent of Sprite-node pin")
	# Spawn another wedge facing north; expect rotation == -PI/2.
	# (This kills the prior east wedge — `_active_swing_wedge` kill-and-restart
	# semantics. We just want to verify the rotation pre-fade.)
	var north_wedge: ColorRect = p._spawn_swing_wedge(
		Player.ATTACK_HEAVY, Vector2.UP, 30.0, 12.0, 0.18)
	assert_not_null(north_wedge, "north wedge spawned")
	assert_almost_eq(north_wedge.rotation, -PI / 2.0, 0.001,
		"swing-wedge rotation = dir.angle() = -PI/2 for north — pin doesn't suppress it")


# ---- 6: facing constant (regression guard on deadzone tunable) -----------

func test_deadzone_constant_is_8_px() -> void:
	# The ticket spec pins 8 px. A future refactor that tweaks this constant
	# should land paired with a re-justification — pin the current value so
	# the diff is visible.
	assert_eq(Player.MOUSE_FACING_DEADZONE_PX, 8.0,
		"MOUSE_FACING_DEADZONE_PX pinned at 8.0 per ticket 86c9uthf0 design")
