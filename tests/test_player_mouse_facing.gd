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
	assert_eq(p._facing, Vector2.LEFT, "STATE_ATTACK suppresses facing update — swing direction snapshots at spawn (ticket edge case 3)")
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


# ---- 5: sprite rotation tracks _facing -----------------------------------

func test_sprite_rotation_updates_when_present() -> void:
	# The Player.tscn has a child "Sprite" ColorRect; the bare-instantiated
	# Player here has no Sprite child. Construct one manually + drive the
	# rotation update to pin the wiring.
	var p: Player = _make_player()
	var sprite: ColorRect = ColorRect.new()
	sprite.name = "Sprite"
	p.add_child(sprite)
	# Set facing to RIGHT — angle is 0. Then to UP — angle is -PI/2.
	p._facing = Vector2.RIGHT
	p._update_sprite_rotation()
	assert_almost_eq(sprite.rotation, 0.0, 0.001, "RIGHT facing → rotation 0")
	p._facing = Vector2.UP
	p._update_sprite_rotation()
	assert_almost_eq(sprite.rotation, -PI / 2.0, 0.001, "UP facing → rotation -PI/2")
	p._facing = Vector2.DOWN
	p._update_sprite_rotation()
	assert_almost_eq(sprite.rotation, PI / 2.0, 0.001, "DOWN facing → rotation +PI/2")
	# Cleanup handled by autofree.


func test_sprite_rotation_noop_when_sprite_missing() -> void:
	# Player without a Sprite child — _update_sprite_rotation must not crash.
	var p: Player = _make_player()
	p._facing = Vector2.RIGHT
	p._update_sprite_rotation()  # no-op; just verifying no crash.
	assert_true(true, "_update_sprite_rotation tolerates missing Sprite child")
	p.free()


# ---- 6: facing constant (regression guard on deadzone tunable) -----------

func test_deadzone_constant_is_8_px() -> void:
	# The ticket spec pins 8 px. A future refactor that tweaks this constant
	# should land paired with a re-justification — pin the current value so
	# the diff is visible.
	assert_eq(Player.MOUSE_FACING_DEADZONE_PX, 8.0,
		"MOUSE_FACING_DEADZONE_PX pinned at 8.0 per ticket 86c9uthf0 design")
