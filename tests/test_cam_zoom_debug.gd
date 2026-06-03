# gdlint:disable=max-public-methods
# GUT test class — one test per scenario IS the design.
extends GutTest
## Paired tests for the tunable camera-zoom soak control (ticket 86ca3kjyg).
##
## Sponsor's recurring S1 soak verdict — "the zoom perspective is still much too
## zoomed" — drove a TUNABLE diagnostic build: `?cam_zoom=N` URL param applied to
## CameraDirector at boot, live +/- keys to adjust in-session, and an on-screen
## readout so the Sponsor can READ the exact normalized value he settles on. This
## PR delivers the control; LOCKING the default zoom is a separate follow-up.
##
## What these cover (the bug CLASS, not just an instance):
##   1. DebugFlags.cam_zoom defaults to the no-override sentinel (-1.0) on
##      desktop / headless (no JS bridge) — production play is untouched.
##   2. `set_cam_zoom_for_test` clamps to [CAM_ZOOM_MIN, CAM_ZOOM_MAX] BEFORE
##      reaching the director (so a key tap at the range edge doesn't spam the
##      director's WarningBus clamp warning).
##   3. The clamped value is actually APPLIED to CameraDirector (current_zoom()
##      reflects it) — the integration seam, not just DebugFlags-internal state.
##   4. `cam_zoom_changed` signal fires with the clamped value (Main's HUD
##      readout subscribes to this).
##   5. The +/- step path steps from the CURRENT director zoom + clamps at edges.
##   6. Reset path returns to 1.0×.
##   7. NO USER WARNING across the in-range apply path (NoWarningGuard) — the AC
##      "no USER WARNING" gate. The clamp-warning path is exercised separately
##      with an explicit expect_warning so the guard stays meaningful.
##   8. `_unhandled_input` is web-gated — inert on desktop / headless GUT (the
##      soak keys must never fire outside the HTML5 release artifact).
##
## Why GUT can't test the URL-param parse directly: `_resolve_cam_zoom` reads
## `OS.has_feature("web")` + JavaScriptBridge, both false/absent in headless GUT.
## The test-injection helpers (`set_cam_zoom_for_test` / `step_cam_zoom_for_test`)
## drive the SAME clamp + apply + emit path the URL parser + key handler reach,
## bypassing only the unreachable bridge/input surface. The web-gate itself is
## pinned structurally in test 8.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

var _warn_guard: NoWarningGuard
var _flags: Node
var _director: Node
var _cam_zoom_signals: Array = []


func before_each() -> void:
	_flags = Engine.get_main_loop().root.get_node_or_null("DebugFlags")
	_director = Engine.get_main_loop().root.get_node_or_null("CameraDirector")
	# Defensive reset: director back to default zoom + player-follow so a leaked
	# request from a prior test doesn't poison this file.
	if _director != null and _director.has_method("reset_to_player"):
		_director.reset_to_player(0.0)
	if _flags != null and _flags.has_method("reset_cam_zoom_for_test"):
		_flags.reset_cam_zoom_for_test()
	_cam_zoom_signals.clear()
	if _flags != null and _flags.has_signal("cam_zoom_changed"):
		_flags.cam_zoom_changed.connect(_on_cam_zoom_changed)
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	if _flags != null and _flags.has_signal("cam_zoom_changed"):
		if _flags.cam_zoom_changed.is_connected(_on_cam_zoom_changed):
			_flags.cam_zoom_changed.disconnect(_on_cam_zoom_changed)
	if _flags != null and _flags.has_method("reset_cam_zoom_for_test"):
		_flags.reset_cam_zoom_for_test()
	if _director != null and _director.has_method("reset_to_player"):
		_director.reset_to_player(0.0)
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


func _on_cam_zoom_changed(normalized: float) -> void:
	_cam_zoom_signals.append(normalized)


# --- 1. Default / no-override ------------------------------------------------


func test_cam_zoom_defaults_to_no_override_sentinel() -> void:
	# On desktop / headless GUT (no JS bridge), the resolver leaves the default.
	assert_almost_eq(_flags.cam_zoom, _flags.CAM_ZOOM_DEFAULT, 0.0001)
	assert_lt(_flags.cam_zoom, _flags.CAM_ZOOM_MIN, "default sentinel is below the valid range")


func test_has_cam_zoom_override_false_at_default() -> void:
	assert_false(_flags.has_cam_zoom_override(), "no override active at the -1.0 default sentinel")


func test_has_cam_zoom_override_true_after_set() -> void:
	_flags.set_cam_zoom_for_test(0.7)
	assert_true(_flags.has_cam_zoom_override(), "override active after a valid set")


# --- 2. Clamp ----------------------------------------------------------------


func test_set_clamps_above_max() -> void:
	# Above-range clamps to MAX. expect_warning is NOT registered here because
	# set_cam_zoom_for_test clamps BEFORE the director — no director WarningBus
	# clamp fires (that's the whole point of the pre-clamp).
	_flags.set_cam_zoom_for_test(99.0)
	assert_almost_eq(_flags.cam_zoom, _flags.CAM_ZOOM_MAX, 0.0001)


func test_set_clamps_below_min() -> void:
	_flags.set_cam_zoom_for_test(0.01)
	assert_almost_eq(_flags.cam_zoom, _flags.CAM_ZOOM_MIN, 0.0001)


func test_set_in_range_unclamped() -> void:
	_flags.set_cam_zoom_for_test(0.7)
	assert_almost_eq(_flags.cam_zoom, 0.7, 0.0001)


# --- 3. Director integration -------------------------------------------------


func test_set_applies_to_director() -> void:
	if _director == null:
		pending("CameraDirector autoload required")
		return
	_flags.set_cam_zoom_for_test(0.7)
	assert_almost_eq(
		float(_director.current_zoom()), 0.7, 0.0001, "director normalized zoom reflects the set value"
	)


func test_clamped_set_applies_clamped_value_to_director() -> void:
	if _director == null:
		pending("CameraDirector autoload required")
		return
	_flags.set_cam_zoom_for_test(99.0)
	assert_almost_eq(
		float(_director.current_zoom()),
		_flags.CAM_ZOOM_MAX,
		0.0001,
		"director receives the CLAMPED value, never the raw out-of-range input"
	)


# --- 4. Signal ---------------------------------------------------------------


func test_set_emits_cam_zoom_changed_with_clamped_value() -> void:
	_flags.set_cam_zoom_for_test(0.65)
	assert_eq(_cam_zoom_signals.size(), 1, "exactly one cam_zoom_changed emission per set")
	assert_almost_eq(_cam_zoom_signals[0], 0.65, 0.0001)


func test_clamped_set_emits_clamped_value() -> void:
	_flags.set_cam_zoom_for_test(99.0)
	assert_eq(_cam_zoom_signals.size(), 1)
	assert_almost_eq(_cam_zoom_signals[0], _flags.CAM_ZOOM_MAX, 0.0001)


# --- 5. Step path ------------------------------------------------------------


func test_step_walks_from_current_director_zoom() -> void:
	if _director == null:
		pending("CameraDirector autoload required")
		return
	# Director starts at 1.0× (reset in before_each). First step walks from there.
	_flags.step_cam_zoom_for_test(-_flags.CAM_ZOOM_STEP)
	assert_almost_eq(
		_flags.cam_zoom,
		_flags.CAM_ZOOM_RESET - _flags.CAM_ZOOM_STEP,
		0.0001,
		"first step bases off the live 1.0x default, not the -1.0 sentinel"
	)


func test_step_clamps_at_min_edge() -> void:
	_flags.set_cam_zoom_for_test(_flags.CAM_ZOOM_MIN)
	_cam_zoom_signals.clear()
	_flags.step_cam_zoom_for_test(-_flags.CAM_ZOOM_STEP)
	assert_almost_eq(_flags.cam_zoom, _flags.CAM_ZOOM_MIN, 0.0001, "step holds at MIN, no underflow")


func test_step_clamps_at_max_edge() -> void:
	_flags.set_cam_zoom_for_test(_flags.CAM_ZOOM_MAX)
	_cam_zoom_signals.clear()
	_flags.step_cam_zoom_for_test(_flags.CAM_ZOOM_STEP)
	assert_almost_eq(_flags.cam_zoom, _flags.CAM_ZOOM_MAX, 0.0001, "step holds at MAX, no overflow")


# --- 6. Reset ----------------------------------------------------------------


func test_reset_value_returns_to_default_one() -> void:
	if _director == null:
		pending("CameraDirector autoload required")
		return
	_flags.set_cam_zoom_for_test(0.6)
	_flags.set_cam_zoom_for_test(_flags.CAM_ZOOM_RESET)
	assert_almost_eq(_flags.cam_zoom, 1.0, 0.0001)
	assert_almost_eq(float(_director.current_zoom()), 1.0, 0.0001, "director back at default 1.0x")


# --- 7. No USER WARNING on the in-range path ---------------------------------
# (The before_each/after_each NoWarningGuard already asserts zero warnings across
#  every in-range test above. This test is the explicit AC pin + documents that
#  the pre-clamp is what keeps the in-range apply path warning-free.)


func test_in_range_apply_emits_no_warning() -> void:
	# No expect_warning registered — assert_clean in after_each will fail if the
	# in-range apply emits any WarningBus warning. This is the AC's "no USER
	# WARNING" gate at the GUT surface.
	_flags.set_cam_zoom_for_test(0.75)
	_flags.set_cam_zoom_for_test(1.25)
	_flags.set_cam_zoom_for_test(_flags.CAM_ZOOM_RESET)
	assert_eq(_cam_zoom_signals.size(), 3, "three in-range sets, three emissions, zero warnings")


# --- 8. Web-gate on the live keys --------------------------------------------


func test_unhandled_input_is_web_gated_inert_on_desktop() -> void:
	# The +/- soak keys must be inert outside the HTML5 release artifact. On
	# desktop / headless GUT, OS.has_feature("web") is false, so _unhandled_input
	# returns immediately and does NOT touch cam_zoom. Feed a synthetic '+'.
	if OS.has_feature("web"):
		pending("This test pins the DESKTOP inert path; skip under a web build.")
		return
	var before: float = _flags.cam_zoom
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = KEY_EQUAL
	ev.pressed = true
	ev.echo = false
	_flags._unhandled_input(ev)
	assert_almost_eq(
		_flags.cam_zoom, before, 0.0001, "soak keys are web-gated — no effect on desktop/headless"
	)
	assert_eq(_cam_zoom_signals.size(), 0, "web-gated key emits no cam_zoom_changed on desktop")
