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
	# Defensive reset: every test starts at default zoom + player-follow.
	if _director != null and _director.has_method("reset_to_player"):
		_director.reset_to_player(0.0)

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
	assert_not_null(_director,
		"CameraDirector must be registered as autoload at /root/CameraDirector")
	assert_true(_director.has_method("request_zoom"), "request_zoom API present")
	assert_true(_director.has_method("reset_to_player"), "reset_to_player API present")
	assert_true(_director.has_method("current_zoom"), "current_zoom API present")
	assert_true(_director.has_method("current_anchor"), "current_anchor API present")
	assert_true(_director.has_method("is_following_player"), "is_following_player API present")
	assert_true(_director.has_method("get_camera"), "get_camera API present")
	assert_true(_director.has_signal("zoom_changed"), "zoom_changed signal present")
	assert_true(_director.has_signal("zoom_requested"), "zoom_requested signal present")


func test_boot_state_is_clean_default_zoom_following_player() -> void:
	assert_almost_eq(_director.current_zoom(), 1.0, 0.001,
		"boot state → normalized zoom 1.0")
	assert_true(_director.is_following_player(),
		"boot state → follow-player mode (anchor zero)")


func test_camera2d_exists_and_is_current() -> void:
	var cam: Camera2D = _director.get_camera()
	assert_not_null(cam, "Camera2D puppet created")
	assert_true(cam.is_current(), "Camera2D is current on the viewport")
	# Default zoom matches BASELINE_ZOOM exactly (the pre-Camera2D viewport-stretch
	# ratio of 1280/480 = 2.6667). Pixel-perfect parity with pre-T9 rendering.
	assert_almost_eq(cam.zoom.x, 2.6667, 0.001,
		"Camera2D.zoom.x == BASELINE_ZOOM.x (pre-T9 visual parity)")
	assert_almost_eq(cam.zoom.y, 2.6667, 0.001,
		"Camera2D.zoom.y == BASELINE_ZOOM.y")


# ---- AC2: request_zoom applies zoom -------------------------------------

func test_request_zoom_instant_applies_zoom() -> void:
	# duration=0 snaps; verifiable without await.
	_director.request_zoom(1.5, 0.0)
	assert_almost_eq(_director.current_zoom(), 1.5, 0.001,
		"current_zoom == 1.5 after instant 1.5× request")
	var cam: Camera2D = _director.get_camera()
	assert_almost_eq(cam.zoom.x, 2.6667 * 1.5, 0.001,
		"engine Camera2D.zoom.x = BASELINE * 1.5 = 4.0")


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
	assert_eq(_zoom_requests.size(), 0,
		"same-params re-request while already-at-state: zoom_requested suppressed")
	assert_eq(_zoom_changes.size(), 0,
		"same-params re-request: zoom_changed suppressed (no-op)")


func test_different_params_re_request_applies_new() -> void:
	_director.request_zoom(1.5, 0.0)
	_director.request_zoom(2.0, 0.0)
	assert_almost_eq(_director.current_zoom(), 2.0, 0.001,
		"second call's target wins")


# ---- AC4: anchor handling ---------------------------------------------

func test_default_anchor_is_player_follow() -> void:
	assert_true(_director.is_following_player(),
		"boot/default: following player")


func test_non_zero_anchor_pins_camera() -> void:
	_director.request_zoom(1.0, 0.0, Vector2(100, 80))
	assert_false(_director.is_following_player(),
		"non-zero anchor → not following player")
	var cam: Camera2D = _director.get_camera()
	# Instant snap (duration=0) — position equals anchor immediately.
	assert_eq(cam.global_position, Vector2(100, 80),
		"camera global_position pinned to anchor (instant snap)")
	assert_eq(_director.current_anchor(), Vector2(100, 80),
		"current_anchor reports pinned coord")


func test_reset_to_player_returns_to_follow_mode() -> void:
	_director.request_zoom(1.5, 0.0, Vector2(100, 80))
	assert_false(_director.is_following_player())
	_director.reset_to_player(0.0)
	assert_true(_director.is_following_player(),
		"reset_to_player → follow mode")
	assert_almost_eq(_director.current_zoom(), 1.0, 0.001,
		"reset_to_player → default normalized zoom")


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
	assert_eq(cam.global_position, Vector2(123, 456),
		"camera snaps to player's global_position in follow mode")


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
	assert_eq(cam.global_position, Vector2(300, 400),
		"camera re-resolves player target across player-swap (room cycle proxy)")


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
	assert_eq(pre_pos, post_pos,
		"CanvasLayer-child render position unchanged after 1.5× camera zoom "
		+ "(HUD-not-zoom invariant — Godot CanvasLayer immunity)")
	# Reset for next test.
	_director.reset_to_player(0.0)


# ---- AC7: WarningBus routing on misuse --------------------------------

func test_out_of_range_scale_clamps_with_warning() -> void:
	_warn_guard.expect_warning("clamped")
	_director.request_zoom(10.0, 0.0)  # max is 4.0
	assert_almost_eq(_director.current_zoom(), 4.0, 0.001,
		"scale clamped to MAX_NORMALIZED_ZOOM (4.0)")


func test_nan_scale_refused_with_warning() -> void:
	_warn_guard.expect_warning("non-finite")
	_director.request_zoom(NAN, 0.0)
	# Stays at boot default — non-finite request was refused.
	assert_almost_eq(_director.current_zoom(), 1.0, 0.001,
		"NaN scale refused — current_zoom unchanged")


func test_inf_scale_refused_with_warning() -> void:
	_warn_guard.expect_warning("non-finite")
	_director.request_zoom(INF, 0.0)
	assert_almost_eq(_director.current_zoom(), 1.0, 0.001,
		"Inf scale refused — current_zoom unchanged")


# ---- AC8: negative duration clamps to 0 (no panic) --------------------

func test_negative_duration_clamps_to_zero() -> void:
	# Negative duration should not crash; the request should still apply
	# instantly (clamped to 0).
	_director.request_zoom(1.5, -1.0)
	assert_almost_eq(_director.current_zoom(), 1.5, 0.001,
		"negative duration treated as 0 (instant apply)")


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
	assert_almost_eq(cam.global_position.x, 240.0, 0.5,
		"Camera2D.global_position.x snap-follows player (fixture cam pos)")
	assert_almost_eq(cam.global_position.y, 200.0, 0.5,
		"Camera2D.global_position.y snap-follows player (fixture cam pos)")
	assert_almost_eq(cam.zoom.x, 2.6667, 0.001,
		"Camera2D.zoom.x at BASELINE_ZOOM (fixture engine-zoom value)")
	# Cadence constant lookup. The fixture's stale-trace guard expects this
	# to be ≤ 0.5 s so a single helper call always has a fresh state datapoint.
	var interval: float = _director.STATE_TRACE_INTERVAL
	assert_true(interval > 0.0 and interval <= 0.5,
		"STATE_TRACE_INTERVAL within fixture-expected bounds (got %.3f)" % interval)


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
	assert_almost_eq(_director.current_zoom(), 1.5, 0.001,
		"zoom state intact after player freed")
