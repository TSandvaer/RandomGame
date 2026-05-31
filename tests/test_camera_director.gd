# gdlint:disable=max-public-methods
# GUT test class — high test_* count IS the design (one test per scenario).
extends GutTest
## Paired tests for `scripts/camera/CameraDirector.gd`.
##
## **Ticket 86c9wjyf3 — M3 Tier 2 Wave 2 T9.**
##
## Coverage shape per Priya's T9 AC:
##   1. Autoload registration + boot-time state (sanity pin).
##   2. Default behavior matches pre-Camera2D state (Camera2D.zoom = BASELINE_ZOOM
##      at normalized 1.0×).
##   3. `request_zoom(target, duration, anchor)` API exists + applies.
##   4. Idempotence — same-params re-request is a no-op.
##   5. Different-params re-request replaces in-flight tween.
##   6. Anchor handling — Vector2.ZERO follows player; non-zero pins.
##   7. `reset_to_player` returns to default zoom + player-follow.
##   8. Player-follow snaps to player's global_position each tick.
##   9. **HUD-not-zoom invariant** — CanvasLayer children unaffected by camera zoom.
##  10. WarningBus routing on misuse — out-of-range scale, NaN/Inf.
##  11. Signal emission — zoom_requested + zoom_changed.
##
## These cover the bug *class* (camera + HUD anchoring + room-cycle leakage)
## not just the bug *instance*. The HUD-not-zoom assertion is load-bearing
## because Godot's CanvasLayer semantics could change in a future engine
## bump; if they did, the entire M1 HUD would silently zoom with the camera.
##
## ## Test-isolation hygiene
##
## `before_each` calls `CameraDirector.reset_to_player(0.0)` so a leaked
## zoom request from a prior test doesn't poison this file. The director
## itself is autoload-scoped so leaks surface as single-file pollution,
## not cross-suite.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

var _warn_guard: NoWarningGuard
var _director: Node
var _zoom_changes: Array = []
var _zoom_requests: Array = []


func before_each() -> void:
	_director = Engine.get_main_loop().root.get_node_or_null("CameraDirector")
	# Defensive reset: every test starts at default zoom + player-follow +
	# no continuous-scroll follow + no world-bounds clamp.
	if _director != null:
		if _director.has_method("reset_to_player"):
			_director.reset_to_player(0.0)
		if _director.has_method("clear_follow_target"):
			_director.clear_follow_target()
		if _director.has_method("clear_world_bounds"):
			_director.clear_world_bounds()

	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()
	_zoom_changes.clear()
	_zoom_requests.clear()
	if _director != null:
		_director.zoom_changed.connect(_on_zoom_changed)
		_director.zoom_requested.connect(_on_zoom_requested)


func after_each() -> void:
	if _director != null:
		if _director.zoom_changed.is_connected(_on_zoom_changed):
			_director.zoom_changed.disconnect(_on_zoom_changed)
		if _director.zoom_requested.is_connected(_on_zoom_requested):
			_director.zoom_requested.disconnect(_on_zoom_requested)
		if _director.has_method("clear_follow_target"):
			_director.clear_follow_target()
		if _director.has_method("clear_world_bounds"):
			_director.clear_world_bounds()
		if _director.has_method("reset_to_player"):
			_director.reset_to_player(0.0)
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


func _on_zoom_changed(new_zoom: float) -> void:
	_zoom_changes.append(new_zoom)


func _on_zoom_requested(target: float, duration: float, anchor: Vector2) -> void:
	_zoom_requests.append({"target": target, "duration": duration, "anchor": anchor})


# ---- AC1: autoload registration + API surface --------------------------


func test_autoload_registered_at_root() -> void:
	assert_not_null(
		_director, "CameraDirector must be registered as autoload at /root/CameraDirector"
	)
	assert_true(_director.has_method("request_zoom"), "request_zoom API present")
	assert_true(_director.has_method("reset_to_player"), "reset_to_player API present")
	assert_true(_director.has_method("current_zoom"), "current_zoom API present")
	assert_true(_director.has_method("current_anchor"), "current_anchor API present")
	assert_true(_director.has_method("is_following_player"), "is_following_player API present")
	assert_true(_director.has_method("get_camera"), "get_camera API present")
	assert_true(_director.has_signal("zoom_changed"), "zoom_changed signal present")
	assert_true(_director.has_signal("zoom_requested"), "zoom_requested signal present")
	# W1 spike (`86c9xu9yt`) — continuous-scroll API additive on top of T9.
	assert_true(_director.has_method("follow_target"), "follow_target API present (W1)")
	assert_true(_director.has_method("clear_follow_target"), "clear_follow_target API present (W1)")
	assert_true(_director.has_method("is_following_target"), "is_following_target API present (W1)")
	assert_true(_director.has_method("get_follow_target"), "get_follow_target API present (W1)")
	assert_true(_director.has_method("get_follow_deadzone"), "get_follow_deadzone API present (W1)")
	assert_true(_director.has_method("set_world_bounds"), "set_world_bounds API present (W1)")
	assert_true(_director.has_method("clear_world_bounds"), "clear_world_bounds API present (W1)")
	assert_true(_director.has_method("get_world_bounds"), "get_world_bounds API present (W1)")
	assert_true(
		_director.has_signal("follow_target_changed"), "follow_target_changed signal present (W1)"
	)
	assert_true(
		_director.has_signal("world_bounds_changed"), "world_bounds_changed signal present (W1)"
	)


func test_boot_state_is_clean_default_zoom_following_player() -> void:
	assert_almost_eq(_director.current_zoom(), 1.0, 0.001, "boot state → normalized zoom 1.0")
	assert_true(_director.is_following_player(), "boot state → follow-player mode (anchor zero)")


func test_camera2d_exists_and_is_current() -> void:
	var cam: Camera2D = _director.get_camera()
	assert_not_null(cam, "Camera2D puppet created")
	assert_true(cam.is_current(), "Camera2D is current on the viewport")
	# Default zoom matches BASELINE_ZOOM exactly (the pre-Camera2D viewport-stretch
	# ratio of 1280/480 = 2.6667). Pixel-perfect parity with pre-T9 rendering.
	assert_almost_eq(
		cam.zoom.x, 2.6667, 0.001, "Camera2D.zoom.x == BASELINE_ZOOM.x (pre-T9 visual parity)"
	)
	assert_almost_eq(cam.zoom.y, 2.6667, 0.001, "Camera2D.zoom.y == BASELINE_ZOOM.y")


# ---- AC2: request_zoom applies zoom -------------------------------------


func test_request_zoom_instant_applies_zoom() -> void:
	# duration=0 snaps; verifiable without await.
	_director.request_zoom(1.5, 0.0)
	assert_almost_eq(
		_director.current_zoom(), 1.5, 0.001, "current_zoom == 1.5 after instant 1.5× request"
	)
	var cam: Camera2D = _director.get_camera()
	assert_almost_eq(
		cam.zoom.x, 2.6667 * 1.5, 0.001, "engine Camera2D.zoom.x = BASELINE * 1.5 = 4.0"
	)


func test_zoom_changed_signal_fires_on_change() -> void:
	_director.request_zoom(1.25, 0.0)
	assert_eq(_zoom_changes.size(), 1, "one zoom_changed emission")
	assert_almost_eq(float(_zoom_changes[0]), 1.25, 0.001, "payload == 1.25")


func test_zoom_requested_signal_fires_with_payload() -> void:
	_director.request_zoom(1.5, 0.3, Vector2(100, 50))
	assert_eq(_zoom_requests.size(), 1, "one zoom_requested emission")
	var p: Dictionary = _zoom_requests[0]
	assert_almost_eq(float(p["target"]), 1.5, 0.001, "target == 1.5")
	assert_almost_eq(float(p["duration"]), 0.3, 0.001, "duration == 0.3")
	assert_eq(p["anchor"], Vector2(100, 50), "anchor == requested")


# ---- AC3: idempotence + replacement -----------------------------------


func test_same_params_re_request_is_noop() -> void:
	_director.request_zoom(1.5, 0.0)
	_zoom_requests.clear()
	_zoom_changes.clear()
	# Second call with same params + already-at-state → no-op.
	_director.request_zoom(1.5, 0.0)
	assert_eq(
		_zoom_requests.size(),
		0,
		"same-params re-request while already-at-state: zoom_requested suppressed"
	)
	assert_eq(_zoom_changes.size(), 0, "same-params re-request: zoom_changed suppressed (no-op)")


func test_different_params_re_request_applies_new() -> void:
	_director.request_zoom(1.5, 0.0)
	_director.request_zoom(2.0, 0.0)
	assert_almost_eq(_director.current_zoom(), 2.0, 0.001, "second call's target wins")


# ---- AC4: anchor handling ---------------------------------------------


func test_default_anchor_is_player_follow() -> void:
	assert_true(_director.is_following_player(), "boot/default: following player")


func test_non_zero_anchor_pins_camera() -> void:
	_director.request_zoom(1.0, 0.0, Vector2(100, 80))
	assert_false(_director.is_following_player(), "non-zero anchor → not following player")
	var cam: Camera2D = _director.get_camera()
	# Instant snap (duration=0) — position equals anchor immediately.
	assert_eq(
		cam.global_position,
		Vector2(100, 80),
		"camera global_position pinned to anchor (instant snap)"
	)
	assert_eq(_director.current_anchor(), Vector2(100, 80), "current_anchor reports pinned coord")


func test_reset_to_player_returns_to_follow_mode() -> void:
	_director.request_zoom(1.5, 0.0, Vector2(100, 80))
	assert_false(_director.is_following_player())
	_director.reset_to_player(0.0)
	assert_true(_director.is_following_player(), "reset_to_player → follow mode")
	assert_almost_eq(
		_director.current_zoom(), 1.0, 0.001, "reset_to_player → default normalized zoom"
	)


# ---- AC5: player-follow snaps to player's global_position ---------------


func test_player_follow_snaps_to_player_position() -> void:
	# Create a stand-in player Node2D in the "player" group; verify the
	# camera tracks it after one tick.
	var fake_player: Node2D = Node2D.new()
	fake_player.global_position = Vector2(123, 456)
	fake_player.add_to_group("player")
	add_child_autofree(fake_player)
	# Wait one process frame so _process() runs and the director resolves
	# the new player + writes the camera position.
	await get_tree().process_frame
	await get_tree().process_frame
	var cam: Camera2D = _director.get_camera()
	assert_eq(
		cam.global_position,
		Vector2(123, 456),
		"camera snaps to player's global_position in follow mode"
	)


func test_player_follow_re_resolves_on_player_swap() -> void:
	# First "player" → camera follows
	var first: Node2D = Node2D.new()
	first.global_position = Vector2(100, 100)
	first.add_to_group("player")
	add_child_autofree(first)
	await get_tree().process_frame
	# Free the first player + spawn a new one (mirrors room-swap)
	first.remove_from_group("player")
	first.queue_free()
	var second: Node2D = Node2D.new()
	second.global_position = Vector2(300, 400)
	second.add_to_group("player")
	add_child_autofree(second)
	await get_tree().process_frame
	await get_tree().process_frame
	var cam: Camera2D = _director.get_camera()
	assert_eq(
		cam.global_position,
		Vector2(300, 400),
		"camera re-resolves player target across player-swap (room cycle proxy)"
	)


# ---- AC6: HUD-not-zoom invariant (load-bearing) -----------------------


func test_hud_canvaslayer_unaffected_by_camera_zoom() -> void:
	# Mount a CanvasLayer with a child Control at a known screen position.
	# Apply a large zoom and assert the Control's render position is
	# unchanged. This is the architectural lock — CanvasLayer is by
	# definition immune to Camera2D, so the assertion is structural.
	var hud_layer: CanvasLayer = CanvasLayer.new()
	hud_layer.layer = 10
	add_child_autofree(hud_layer)
	var hud_label: Control = Control.new()
	hud_label.position = Vector2(16, 16)  # top-left at 16px in
	hud_label.size = Vector2(120, 20)
	hud_layer.add_child(hud_label)
	# Capture rendered position pre-zoom.
	await get_tree().process_frame
	var pre_pos: Vector2 = hud_label.get_global_transform_with_canvas().origin
	# Apply 1.5× zoom; the world should zoom but HUD should NOT move.
	_director.request_zoom(1.5, 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var post_pos: Vector2 = hud_label.get_global_transform_with_canvas().origin
	assert_eq(
		pre_pos,
		post_pos,
		(
			"CanvasLayer-child render position unchanged after 1.5× camera zoom "
			+ "(HUD-not-zoom invariant — Godot CanvasLayer immunity)"
		)
	)
	# Reset for next test.
	_director.reset_to_player(0.0)


# ---- AC7: WarningBus routing on misuse --------------------------------


func test_out_of_range_scale_clamps_with_warning() -> void:
	_warn_guard.expect_warning("clamped")
	_director.request_zoom(10.0, 0.0)  # max is 4.0
	assert_almost_eq(
		_director.current_zoom(), 4.0, 0.001, "scale clamped to MAX_NORMALIZED_ZOOM (4.0)"
	)


func test_nan_scale_refused_with_warning() -> void:
	_warn_guard.expect_warning("non-finite")
	_director.request_zoom(NAN, 0.0)
	# Stays at boot default — non-finite request was refused.
	assert_almost_eq(
		_director.current_zoom(), 1.0, 0.001, "NaN scale refused — current_zoom unchanged"
	)


func test_inf_scale_refused_with_warning() -> void:
	_warn_guard.expect_warning("non-finite")
	_director.request_zoom(INF, 0.0)
	assert_almost_eq(
		_director.current_zoom(), 1.0, 0.001, "Inf scale refused — current_zoom unchanged"
	)


# ---- AC8: negative duration clamps to 0 (no panic) --------------------


func test_negative_duration_clamps_to_zero() -> void:
	# Negative duration should not crash; the request should still apply
	# instantly (clamped to 0).
	_director.request_zoom(1.5, -1.0)
	assert_almost_eq(
		_director.current_zoom(), 1.5, 0.001, "negative duration treated as 0 (instant apply)"
	)


# ---- AC9: zoom request preserves across room-cycle proxy ---------------

# ---- AC10: Playwright-fixture observability contract -------------------


func test_camera_state_observable_for_playwright_fixture() -> void:
	# The Playwright fixture (`tests/playwright/fixtures/mouse-facing.ts`)
	# depends on a `[combat-trace] CameraDirector.state | zoom=<v> pos=(<x>,<y>)`
	# line to translate world coords to canvas-pixel coords via the live
	# camera transform. The trace itself is HTML5-only (gated on
	# DebugFlags.combat_trace_enabled), but the GUT-side contract is that:
	#
	#   1. The director exposes camera engine state (zoom + global_position)
	#      via `get_camera()`.
	#   2. The values reflect the current snap-follow state immediately
	#      after a `_process` tick.
	#   3. The `STATE_TRACE_INTERVAL` cadence constant exists at the value
	#      the fixture's stale-trace guard expects (0.25 s; longer than
	#      a single physics frame at 60Hz).
	#
	# If any of these contract surfaces drifts, the Playwright fixture
	# silently breaks — this GUT test fails first.
	var p: Node2D = Node2D.new()
	p.global_position = Vector2(240, 200)
	p.add_to_group("player")
	add_child_autofree(p)
	await get_tree().process_frame
	await get_tree().process_frame
	var cam: Camera2D = _director.get_camera()
	assert_not_null(cam, "get_camera() returns the Camera2D puppet")
	assert_almost_eq(
		cam.global_position.x,
		240.0,
		0.5,
		"Camera2D.global_position.x snap-follows player (fixture cam pos)"
	)
	assert_almost_eq(
		cam.global_position.y,
		200.0,
		0.5,
		"Camera2D.global_position.y snap-follows player (fixture cam pos)"
	)
	assert_almost_eq(
		cam.zoom.x, 2.6667, 0.001, "Camera2D.zoom.x at BASELINE_ZOOM (fixture engine-zoom value)"
	)
	# Cadence constant lookup. The fixture's stale-trace guard expects this
	# to be ≤ 0.5 s so a single helper call always has a fresh state datapoint.
	var interval: float = _director.STATE_TRACE_INTERVAL
	assert_true(
		interval > 0.0 and interval <= 0.5,
		"STATE_TRACE_INTERVAL within fixture-expected bounds (got %.3f)" % interval
	)


func test_in_flight_zoom_survives_player_node_freed() -> void:
	# Simulate: zoom in motion, player gets freed (room-cycle), camera
	# should not crash on the next tick and should hold its position via
	# the is_instance_valid guard.
	var p: Node2D = Node2D.new()
	p.global_position = Vector2(50, 50)
	p.add_to_group("player")
	add_child_autofree(p)
	await get_tree().process_frame
	_director.request_zoom(1.5, 0.0)
	# Free the player.
	p.remove_from_group("player")
	p.queue_free()
	# Tick a couple frames — no panic, camera holds last position until
	# a new player resolves.
	await get_tree().process_frame
	await get_tree().process_frame
	# Director didn't crash + state intact.
	assert_almost_eq(_director.current_zoom(), 1.5, 0.001, "zoom state intact after player freed")


# ---- M3 Tier 3 W1 — continuous-scroll follow + bounds-clamp -----------
#
# Ticket `86c9xu9yt`. The new API is additive on top of T9's snap-follow.
# Tests below cover:
#   - `follow_target` / `clear_follow_target` lifecycle + signals
#   - Deadzone math (pure-function pin via _compute_deadzone_follow_position)
#   - World-bounds clamp math (pure-function pin via _clamp_to_world_bounds)
#   - Integration: follow + bounds in _process tick
#   - HUD-immunity preserved through continuous-scroll path
#   - WarningBus routing on misuse


func _setup_follow_target_at(world_pos: Vector2) -> Node2D:
	var t: Node2D = Node2D.new()
	t.name = "FollowTarget"
	t.global_position = world_pos
	add_child_autofree(t)
	return t


# ---- Deadzone math (pure-function pins) -------------------------------


func test_deadzone_inside_box_camera_holds_x_and_y() -> void:
	# Target inside deadzone box → camera holds.
	var cam: Vector2 = Vector2(100, 100)
	var target: Vector2 = Vector2(120, 110)  # dx=20, dy=10 both inside dz=(40,24)
	var deadzone: Vector2 = Vector2(40, 24)
	var result: Vector2 = _director._compute_deadzone_follow_position(cam, target, deadzone)
	assert_eq(result, cam, "target inside deadzone → camera holds")


func test_deadzone_target_at_edge_camera_holds() -> void:
	# Target exactly AT deadzone edge → camera holds (strict > comparison).
	var cam: Vector2 = Vector2(100, 100)
	var deadzone: Vector2 = Vector2(40, 24)
	# dx = 40 exactly; dy = 24 exactly. Both at-edge.
	var target: Vector2 = Vector2(140, 124)
	var result: Vector2 = _director._compute_deadzone_follow_position(cam, target, deadzone)
	assert_eq(result, cam, "target AT deadzone edge → camera holds (strict-greater)")


func test_deadzone_target_crosses_x_camera_shifts_to_pin_target_at_edge() -> void:
	# Target crosses RIGHT edge → camera shifts right so target sits on edge.
	var cam: Vector2 = Vector2(100, 100)
	var deadzone: Vector2 = Vector2(40, 24)
	# dx = 60 (> 40); dy = 0 (inside).
	var target: Vector2 = Vector2(160, 100)
	var result: Vector2 = _director._compute_deadzone_follow_position(cam, target, deadzone)
	# Camera shifts so target sits at +deadzone.x: cam.x = target.x - 40 = 120.
	assert_eq(
		result.x,
		120.0,
		"target crossed +X edge → camera moves so target lands at right deadzone edge"
	)
	assert_eq(result.y, 100.0, "Y unchanged when target inside deadzone on Y")
	# Post-condition: target is now exactly AT deadzone edge in X.
	assert_eq(target.x - result.x, deadzone.x, "post-condition: target.x - cam.x == deadzone.x")


func test_deadzone_target_crosses_negative_x_camera_shifts_left() -> void:
	var cam: Vector2 = Vector2(100, 100)
	var deadzone: Vector2 = Vector2(40, 24)
	# dx = -60 (target to LEFT, outside deadzone).
	var target: Vector2 = Vector2(40, 100)
	var result: Vector2 = _director._compute_deadzone_follow_position(cam, target, deadzone)
	# Camera shifts so target sits at -deadzone.x: cam.x = target.x + 40 = 80.
	assert_eq(
		result.x,
		80.0,
		"target crossed -X edge → camera moves so target lands at left deadzone edge"
	)
	assert_eq(target.x - result.x, -deadzone.x, "post-condition: target.x - cam.x == -deadzone.x")


func test_deadzone_axes_independent_x_only_y_held() -> void:
	# Target crosses X edge but stays inside Y deadzone → only X axis moves.
	var cam: Vector2 = Vector2(100, 100)
	var deadzone: Vector2 = Vector2(40, 24)
	var target: Vector2 = Vector2(200, 105)  # dx=100 out; dy=5 in
	var result: Vector2 = _director._compute_deadzone_follow_position(cam, target, deadzone)
	assert_eq(result.x, 160.0, "X shifts (target.x - dz.x)")
	assert_eq(result.y, 100.0, "Y holds (target inside Y deadzone)")


func test_deadzone_zero_collapses_to_snap_follow() -> void:
	# Vector2.ZERO deadzone → any movement immediately translates to camera
	# movement (target.x > cam.x means dx > 0 > 0 → shifts).
	var cam: Vector2 = Vector2(100, 100)
	var target: Vector2 = Vector2(150, 200)
	var result: Vector2 = _director._compute_deadzone_follow_position(cam, target, Vector2.ZERO)
	assert_eq(result, target, "zero deadzone → camera snaps to target")


# ---- World-bounds clamp math (pure-function pins) ----------------------


func test_clamp_inside_bounds_position_unchanged() -> void:
	# Camera well inside bounds, viewport fits → position unchanged.
	# At BASELINE_ZOOM, visible viewport is 480×270.
	# Bounds 1440×270 wide; camera at (720, 135) (center of bounds).
	var bounds: Rect2 = Rect2(0, 0, 1440, 270)
	var cam: Vector2 = Vector2(720, 135)
	var result: Vector2 = _director._clamp_to_world_bounds(cam, bounds)
	assert_almost_eq(result.x, 720.0, 0.5, "X centered inside bounds — unchanged")
	# Y: bounds.y == viewport_world.y (270 == 270), so the centering branch
	# fires (the `<=` comparison). Camera centers on bounds.y center = 135.
	assert_almost_eq(result.y, 135.0, 0.5, "Y centered on bounds (== viewport size)")


func test_clamp_pushes_camera_off_left_edge() -> void:
	# Camera at world x=10 (way past left edge). At BASELINE_ZOOM viewport
	# is 480 wide → half = 240. Min allowed cam.x = bounds.x + 240 = 240.
	var bounds: Rect2 = Rect2(0, 0, 1440, 270)
	var cam: Vector2 = Vector2(10, 135)
	var result: Vector2 = _director._clamp_to_world_bounds(cam, bounds)
	assert_almost_eq(
		result.x, 240.0, 0.5, "clamped to left-edge: cam.x = bounds.x + viewport_world.x/2"
	)


func test_clamp_pushes_camera_off_right_edge() -> void:
	# Camera at world x=2000 (past right edge). bounds.end.x = 1440.
	# Max allowed cam.x = 1440 - 240 = 1200.
	var bounds: Rect2 = Rect2(0, 0, 1440, 270)
	var cam: Vector2 = Vector2(2000, 135)
	var result: Vector2 = _director._clamp_to_world_bounds(cam, bounds)
	assert_almost_eq(
		result.x, 1200.0, 0.5, "clamped to right-edge: cam.x = bounds.end.x - viewport_world.x/2"
	)


func test_clamp_bounds_narrower_than_viewport_centers_camera() -> void:
	# Bounds 200×270 < viewport 480×270 on X → center camera on bounds.x.
	var bounds: Rect2 = Rect2(0, 0, 200, 270)
	var cam: Vector2 = Vector2(0, 135)  # way left
	var result: Vector2 = _director._clamp_to_world_bounds(cam, bounds)
	assert_almost_eq(
		result.x,
		100.0,
		0.5,
		"bounds narrower than viewport on X → camera centers on bounds.x center"
	)


func test_clamp_bounds_with_non_zero_origin() -> void:
	# Bounds origin (100, 50), size 1440×400. Camera at (50, 0) → clamps in.
	# Min cam.x = 100 + 240 = 340.  Min cam.y = 50 + 135 = 185.
	var bounds: Rect2 = Rect2(100, 50, 1440, 400)
	var cam: Vector2 = Vector2(50, 0)
	var result: Vector2 = _director._clamp_to_world_bounds(cam, bounds)
	assert_almost_eq(result.x, 340.0, 0.5, "non-zero-origin bounds: clamp to bounds.x + half_vp")
	assert_almost_eq(result.y, 185.0, 0.5, "non-zero-origin bounds: clamp to bounds.y + half_vp")


# ---- follow_target API lifecycle --------------------------------------


func test_follow_target_engages_and_clear_disengages() -> void:
	var t: Node2D = _setup_follow_target_at(Vector2(0, 0))
	assert_false(_director.is_following_target(), "boot state: not following")
	_director.follow_target(t, Vector2(40, 24))
	assert_true(_director.is_following_target(), "engaged after follow_target()")
	assert_eq(_director.get_follow_target(), t, "follow target reference exposed")
	assert_eq(_director.get_follow_deadzone(), Vector2(40, 24), "deadzone exposed via getter")
	_director.clear_follow_target()
	assert_false(_director.is_following_target(), "disengaged after clear_follow_target()")
	assert_null(_director.get_follow_target(), "follow target reference cleared")


func test_follow_target_null_treated_as_clear() -> void:
	var t: Node2D = _setup_follow_target_at(Vector2(0, 0))
	_director.follow_target(t, Vector2(40, 24))
	_director.follow_target(null)  # null → clear
	assert_false(
		_director.is_following_target(), "follow_target(null) treated as clear_follow_target()"
	)


func test_follow_target_negative_deadzone_clamps_with_warning() -> void:
	_warn_guard.expect_warning("clamped")
	var t: Node2D = _setup_follow_target_at(Vector2(0, 0))
	_director.follow_target(t, Vector2(-10, 24))
	# Negative X component clamped to 0.
	assert_eq(
		_director.get_follow_deadzone(),
		Vector2(0, 24),
		"negative deadzone component clamped to 0 with warning"
	)


func test_follow_target_nan_deadzone_refused_with_warning() -> void:
	_warn_guard.expect_warning("non-finite")
	var t: Node2D = _setup_follow_target_at(Vector2(0, 0))
	_director.follow_target(t, Vector2(NAN, 24))
	# Refused — follow not engaged.
	assert_false(
		_director.is_following_target(), "non-finite deadzone refused — follow not engaged"
	)


# ---- follow_target_changed signal -------------------------------------


func test_follow_target_changed_emits_on_engage_and_clear() -> void:
	var events: Array = []
	var cb := func(engaged: bool) -> void: events.append(engaged)
	_director.follow_target_changed.connect(cb)
	var t: Node2D = _setup_follow_target_at(Vector2(0, 0))
	_director.follow_target(t, Vector2(40, 24))
	_director.clear_follow_target()
	assert_eq(events, [true, false], "follow_target_changed fires (true, false) on engage + clear")
	_director.follow_target_changed.disconnect(cb)


func test_follow_target_same_params_re_engage_no_spam_signal() -> void:
	var events: Array = []
	var cb := func(engaged: bool) -> void: events.append(engaged)
	_director.follow_target_changed.connect(cb)
	var t: Node2D = _setup_follow_target_at(Vector2(0, 0))
	_director.follow_target(t, Vector2(40, 24))
	_director.follow_target(t, Vector2(40, 24))  # same params
	assert_eq(events, [true], "re-engaging with identical params → no duplicate signal")
	_director.follow_target_changed.disconnect(cb)


# ---- _process integration: deadzone + clamp work together --------------


func test_process_follow_with_deadzone_holds_camera_inside_box() -> void:
	# Test the "target moves inside deadzone → camera holds" invariant.
	#
	# Setup challenge: after `follow_target` engages with a non-zero deadzone,
	# the camera converges to the deadzone EDGE relative to the target (NOT
	# to the target itself). So a naive "move target by 30 px" test asserts
	# against the wrong baseline — the camera-to-target distance after
	# convergence is exactly `deadzone`, not zero.
	#
	# Two-step engage ensures determinism regardless of prior camera position:
	#   1. Engage with zero deadzone → camera snap-follows target to (100, 100).
	#   2. Re-engage with the real deadzone → camera holds at (100, 100) since
	#      it's already inside.
	# Then move target by a known offset BELOW deadzone and verify hold.
	var t: Node2D = _setup_follow_target_at(Vector2(100, 100))
	# Step 1: zero-deadzone engage to deterministically place camera at (100, 100).
	_director.follow_target(t, Vector2.ZERO)
	await get_tree().process_frame
	await get_tree().process_frame
	var cam: Camera2D = _director.get_camera()
	assert_eq(
		cam.global_position,
		Vector2(100, 100),
		"step 1: zero-deadzone engage snap-followed camera to target (100, 100)"
	)
	# Step 2: switch to the real deadzone — camera already inside, holds.
	_director.follow_target(t, Vector2(40, 24))
	await get_tree().process_frame
	var pos_before: Vector2 = cam.global_position
	assert_eq(
		pos_before,
		Vector2(100, 100),
		"step 2: re-engage with non-zero deadzone holds camera (target inside dz)"
	)
	# Step 3: move target by 30 in X (< deadzone half-extent 40) → camera holds.
	t.global_position = Vector2(130, 100)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(
		cam.global_position,
		pos_before,
		"camera holds while target moves +30 in X (inside ±40 deadzone)"
	)


func test_process_follow_with_deadzone_shifts_camera_on_edge_cross() -> void:
	# Same two-step engage as the "holds" test — see that test for rationale.
	# Step 1: zero-deadzone snap-follow places camera at target (100, 100).
	# Step 2: real deadzone engage holds the camera at (100, 100).
	# Step 3: target moves to (160, 100); dx = 60 > deadzone.x = 40 → camera
	#         shifts so target lands at right deadzone edge: cam.x = 160 - 40 = 120.
	var t: Node2D = _setup_follow_target_at(Vector2(100, 100))
	_director.follow_target(t, Vector2.ZERO)
	await get_tree().process_frame
	await get_tree().process_frame
	_director.follow_target(t, Vector2(40, 24))
	await get_tree().process_frame
	var cam: Camera2D = _director.get_camera()
	# Move target by 60 px (outside deadzone) → camera shifts to (target - 40, ...).
	t.global_position = Vector2(160, 100)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(
		cam.global_position.x,
		120.0,
		"camera shifts so target sits at right deadzone edge after edge-cross"
	)


func test_process_follow_with_bounds_clamps_at_world_edge() -> void:
	# 3-chunk bounds 1440×270; engage follow on a target that walks to
	# the right edge. Camera should clamp at bounds.end.x - half_viewport.
	var t: Node2D = _setup_follow_target_at(Vector2(100, 135))
	_director.follow_target(t, Vector2.ZERO)  # zero deadzone = snap on follow
	_director.set_world_bounds(Rect2(0, 0, 1440, 270))
	await get_tree().process_frame
	await get_tree().process_frame
	# Walk target way past right edge of bounds.
	t.global_position = Vector2(1400, 135)
	await get_tree().process_frame
	await get_tree().process_frame
	var cam: Camera2D = _director.get_camera()
	# Bounds 1440 wide; viewport at zoom 2.6667 is 480 wide; half = 240.
	# Max cam.x = 1440 - 240 = 1200.
	assert_almost_eq(
		cam.global_position.x,
		1200.0,
		1.0,
		"camera clamps at right world edge — does not scroll past bounds"
	)
	_director.clear_world_bounds()


func test_process_snap_follow_with_bounds_also_clamps() -> void:
	# Backward-compat: the T9 snap-follow path also respects bounds when set.
	var p: Node2D = Node2D.new()
	p.global_position = Vector2(1400, 135)  # past right edge
	p.add_to_group("player")
	add_child_autofree(p)
	_director.set_world_bounds(Rect2(0, 0, 1440, 270))
	await get_tree().process_frame
	await get_tree().process_frame
	var cam: Camera2D = _director.get_camera()
	assert_almost_eq(
		cam.global_position.x,
		1200.0,
		1.0,
		"snap-follow path also bounds-clamps (back-compat preservation)"
	)
	_director.clear_world_bounds()


# ---- HUD-immunity preserved through continuous-scroll path ------------


func test_hud_canvaslayer_unaffected_by_continuous_scroll() -> void:
	# Equivalent of test_hud_canvaslayer_unaffected_by_camera_zoom but
	# exercises the follow_target+bounds path instead of the zoom path.
	# If a future refactor reaches up to mutate CanvasLayer transforms via
	# the camera, this catches it.
	var hud_layer: CanvasLayer = CanvasLayer.new()
	hud_layer.layer = 10
	add_child_autofree(hud_layer)
	var hud_label: Control = Control.new()
	hud_label.position = Vector2(16, 16)
	hud_label.size = Vector2(120, 20)
	hud_layer.add_child(hud_label)
	await get_tree().process_frame
	var pre_pos: Vector2 = hud_label.get_global_transform_with_canvas().origin
	# Engage continuous-scroll follow; shift the camera far to the right.
	var t: Node2D = _setup_follow_target_at(Vector2(1200, 135))
	_director.follow_target(t, Vector2.ZERO)
	_director.set_world_bounds(Rect2(0, 0, 1440, 270))
	await get_tree().process_frame
	await get_tree().process_frame
	var post_pos: Vector2 = hud_label.get_global_transform_with_canvas().origin
	assert_eq(
		pre_pos,
		post_pos,
		(
			"CanvasLayer-child render position unchanged after continuous-scroll "
			+ "(HUD-immunity preserved through W1 spike path)"
		)
	)
	_director.clear_world_bounds()
	_director.clear_follow_target()


# ---- follow_target survives target-freed (defensive) -------------------


func test_follow_target_freed_target_falls_back_safely() -> void:
	var t: Node2D = _setup_follow_target_at(Vector2(100, 100))
	_director.follow_target(t, Vector2(40, 24))
	await get_tree().process_frame
	# Free the target mid-follow.
	t.queue_free()
	# Tick — should NOT panic + should fall through to T9 snap-follow path
	# (no player in "player" group in this test → camera holds last position).
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(
		_director.is_following_target(), "freed target → is_following_target returns false"
	)


# ---- set_world_bounds API + signal ------------------------------------


func test_set_world_bounds_emits_signal_and_exposes_value() -> void:
	var events: Array = []
	var cb := func(b: Rect2) -> void: events.append(b)
	_director.world_bounds_changed.connect(cb)
	var bounds: Rect2 = Rect2(0, 0, 1440, 270)
	_director.set_world_bounds(bounds)
	assert_eq(_director.get_world_bounds(), bounds, "get_world_bounds reflects set value")
	assert_eq(events.size(), 1, "world_bounds_changed fired once on set")
	assert_eq(events[0], bounds, "signal payload == set bounds")
	# Setting same value again → idempotent (no spam).
	_director.set_world_bounds(bounds)
	assert_eq(events.size(), 1, "re-setting same bounds → no spam")
	# Clearing fires with zero-size Rect2.
	_director.clear_world_bounds()
	assert_eq(events.size(), 2, "clear_world_bounds fires signal")
	assert_eq(events[1].size, Vector2.ZERO, "clear payload is zero-size Rect2")
	_director.world_bounds_changed.disconnect(cb)


func test_set_world_bounds_negative_size_refused_with_warning() -> void:
	_warn_guard.expect_warning("negative size")
	_director.set_world_bounds(Rect2(0, 0, -100, 270))
	assert_eq(
		_director.get_world_bounds(),
		Rect2(),
		"negative-size bounds refused — clamp remains disabled"
	)


# ---- HTML5 minimize/restore zoom re-assert ----------------------------
#
# Bug class: HTML5 `canvas_resize_policy=2` (adaptive) re-runs the
# `canvas_items` stretch on minimize→restore, clobbering `_camera.zoom` back
# to the scene default WITHOUT updating the GDScript mirror
# (`_current_normalized_zoom`). A naive `request_zoom` re-fire no-ops against
# the idempotence guard (`CameraDirector.gd` ~ idempotence block in
# `request_zoom`) because the mirror still reads the correct value. Fix:
# `_on_window_size_changed` (connected to viewport `size_changed` in `_ready`)
# defers `_reassert_owned_camera_state`, which re-projects the mirror onto the
# engine camera directly. These tests pin the re-assert path so a regression
# (lost connection / removed re-write / accidental request_zoom routing) fails
# CI. Source: `scripts/camera/CameraDirector.gd` `_on_window_size_changed` +
# `_reassert_owned_camera_state`.


func test_size_changed_reasserts_clobbered_zoom() -> void:
	# Put the director at a non-default zoom (the S2-arena class: 0.5×).
	_director.request_zoom(0.5, 0.0)
	assert_almost_eq(_director.current_zoom(), 0.5, 0.001, "precondition: mirror at 0.5×")
	var cam: Camera2D = _director.get_camera()
	# Simulate the HTML5 stretch reset clobbering the engine zoom behind the
	# director's back — the mirror (_current_normalized_zoom) stays correct.
	cam.zoom = CameraDirector.BASELINE_ZOOM
	assert_almost_eq(
		cam.zoom.x, 2.6667, 0.001, "precondition: engine zoom clobbered to baseline (2.6667)"
	)
	# Emit the same signal the viewport fires on minimize→restore.
	get_viewport().size_changed.emit()
	# The handler defers one frame (lets the stretch recompute settle); await it.
	await get_tree().process_frame
	await get_tree().process_frame
	# Engine zoom re-projected from the (still-correct) mirror: BASELINE * 0.5.
	assert_almost_eq(
		cam.zoom.x,
		2.6667 * 0.5,
		0.001,
		"size_changed re-asserts engine zoom from mirror (BASELINE * 0.5 = 1.3333)"
	)
	assert_almost_eq(
		_director.current_zoom(), 0.5, 0.001, "mirror unchanged by re-assert (still 0.5)"
	)


func test_size_changed_reassert_holds_non_default_death_zoom() -> void:
	# The S1 death-cinematic zoom (1.5×) must also survive a restore.
	_director.request_zoom(1.5, 0.0)
	var cam: Camera2D = _director.get_camera()
	cam.zoom = CameraDirector.BASELINE_ZOOM  # clobber
	get_viewport().size_changed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_almost_eq(
		cam.zoom.x, 2.6667 * 1.5, 0.001, "1.5× death-zoom restored (BASELINE * 1.5 = 4.0)"
	)


func test_size_changed_reassert_holds_pinned_anchor() -> void:
	# A pinned anchor (non-zero) must be re-held after a restore when no
	# position tween is in flight.
	_director.request_zoom(1.0, 0.0, Vector2(300, 120))
	var cam: Camera2D = _director.get_camera()
	# Clobber both zoom and position behind the director's back.
	cam.zoom = CameraDirector.BASELINE_ZOOM * 2.0
	cam.global_position = Vector2(999, 999)
	get_viewport().size_changed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_almost_eq(cam.zoom.x, 2.6667, 0.001, "pinned-anchor case: zoom re-asserted to 1.0×")
	assert_eq(cam.global_position, Vector2(300, 120), "pinned anchor re-held after restore")
	# Cleanup: release the pin so after_each's reset_to_player leaves clean state.
	_director.reset_to_player(0.0)


func test_size_changed_reassert_preserves_follow_and_bounds_state() -> void:
	# follow_target + world_bounds are read live by _process every tick; the
	# stretch reset doesn't touch those members. Assert they survive a restore
	# (the re-assert must not clear them) and the clamp re-applies against the
	# restored zoom on the next tick.
	var t: Node2D = Node2D.new()
	add_child_autofree(t)
	t.global_position = Vector2(5000, 100)  # far outside any bounds
	_director.request_zoom(0.5, 0.0)
	_director.follow_target(t, Vector2(40, 24))
	_director.set_world_bounds(Rect2(0, 0, 1440, 270))
	var cam: Camera2D = _director.get_camera()
	cam.zoom = CameraDirector.BASELINE_ZOOM  # clobber zoom
	get_viewport().size_changed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_almost_eq(cam.zoom.x, 2.6667 * 0.5, 0.001, "zoom restored under active follow/bounds")
	assert_true(_director.is_following_target(), "follow_target survives restore")
	assert_eq(_director.get_world_bounds(), Rect2(0, 0, 1440, 270), "world_bounds survives restore")
	# Cleanup.
	_director.clear_follow_target()
	_director.clear_world_bounds()
	_director.reset_to_player(0.0)


func test_viewport_size_changed_is_connected_after_ready() -> void:
	# Regression guard: if the _ready connection is dropped, the re-assert
	# never fires and the bug returns silently. Pin the wiring directly.
	assert_true(
		get_viewport().size_changed.is_connected(_director._on_window_size_changed),
		"CameraDirector subscribes to viewport size_changed (minimize/restore re-assert wiring)"
	)
