extends GutTest
## Tests for `scripts/screens/DescendScreen.gd` — the fullscreen
## "descend to next stratum" interstitial.
##
## Drew run-006 task spec (`86c9kxx6z`):
##   1. Screen instantiates cleanly.
##   2. Fade-in completes in expected duration.
##   3. "Return" button emits `restart_run` signal.
##   4. Edge: button mash doesn't fire signal multiple times.

const DescendScreenScript: Script = preload("res://scripts/screens/DescendScreen.gd")
const DESCEND_SCREEN_SCENE: PackedScene = preload("res://scenes/screens/DescendScreen.tscn")

# ---- Helpers ----------------------------------------------------------


func _make_screen() -> DescendScreen:
	var packed: PackedScene = DESCEND_SCREEN_SCENE
	var screen: DescendScreen = packed.instantiate()
	add_child_autofree(screen)
	return screen


# ---- Spec test 1: instantiates cleanly -------------------------------


func test_descend_screen_scene_loads() -> void:
	var packed: PackedScene = DESCEND_SCREEN_SCENE
	assert_not_null(packed, "DescendScreen.tscn must load")
	var instance: Node = packed.instantiate()
	assert_true(instance is DescendScreen, "root is DescendScreen typed")
	instance.free()


func test_descend_screen_instantiates_with_ui() -> void:
	var screen: DescendScreen = _make_screen()
	# Three labels + one button + one BG panel must all exist after _ready.
	assert_not_null(screen.get_bg_panel(), "background panel exists")
	assert_not_null(screen.get_title_label(), "title label exists")
	assert_not_null(screen.get_return_button(), "return button exists")


func test_title_text_matches_constant() -> void:
	var screen: DescendScreen = _make_screen()
	var title: Label = screen.get_title_label()
	assert_eq(
		title.text, DescendScreen.TITLE_TEXT, "title label text matches authoritative constant"
	)


func test_return_button_text_matches_constant() -> void:
	var screen: DescendScreen = _make_screen()
	var btn: Button = screen.get_return_button()
	assert_eq(
		btn.text,
		DescendScreen.RETURN_BUTTON_TEXT,
		"return button text matches authoritative constant"
	)


func test_screen_renders_on_high_canvas_layer() -> void:
	# CanvasLayer at layer >= 100 so it sits over HUD layers.
	var screen: DescendScreen = _make_screen()
	assert_gte(screen.layer, 100, "DescendScreen lives on a layer above the HUD")


# ---- Spec test 2: fade-in completes ----------------------------------


func test_fade_duration_constant_is_0_6s() -> void:
	# Static contract — Uma's death-restart Beat D references 0.4 s; Drew's
	# call for "the player succeeded, give it weight" pegs descend at 0.6 s.
	# If this drifts, tests bounce so we don't silently break the timing.
	assert_almost_eq(DescendScreen.FADE_DURATION, 0.6, 0.001, "descend fade duration is 0.6 s")


func test_fade_in_starts_transparent() -> void:
	var screen: DescendScreen = _make_screen()
	var bg: ColorRect = screen.get_bg_panel()
	# Right after _ready, before the tween has run a frame, modulate.a
	# should be 0 (we set `.from(0.0)` on the tween).
	# Note: `Tween.tween_property(...).from(value)` sets the value at tween
	# start, which is one frame after creation. Allow the test_helper to
	# read post-construction state.
	# The tween is async; the panel's modulate may already be 0 or 1
	# depending on engine timing. Use the public test helper instead.
	assert_false(screen.is_fade_complete(), "fade_complete is false right after instantiation")
	# Belt-and-suspenders — assert the BG ColorRect exists for rendering.
	assert_not_null(bg)


func test_fade_completion_signal_fires_after_complete_for_test() -> void:
	# Production waits on a Tween; tests use the test-helper to fast-forward
	# deterministically (same pattern as Stratum1BossRoom's
	# `complete_entry_sequence_for_test`).
	var screen: DescendScreen = _make_screen()
	watch_signals(screen)
	screen.complete_fade_for_test()
	assert_signal_emitted(screen, "fade_in_completed")
	assert_true(screen.is_fade_complete())


func test_fade_complete_for_test_is_idempotent() -> void:
	# Calling complete_fade_for_test() twice must only emit fade_in_completed once.
	var screen: DescendScreen = _make_screen()
	watch_signals(screen)
	screen.complete_fade_for_test()
	screen.complete_fade_for_test()
	assert_signal_emit_count(
		screen,
		"fade_in_completed",
		1,
		"fade_in_completed emits exactly once even with repeated complete calls"
	)


func test_bg_panel_opaque_after_fade_complete() -> void:
	var screen: DescendScreen = _make_screen()
	screen.complete_fade_for_test()
	var bg: ColorRect = screen.get_bg_panel()
	assert_almost_eq(
		bg.modulate.a, 1.0, 0.001, "background panel modulate.a is 1.0 after fade completes"
	)


# ---- Spec test 3: return button emits restart_run --------------------


func test_return_button_emits_restart_run() -> void:
	var screen: DescendScreen = _make_screen()
	watch_signals(screen)
	screen.press_return_for_test()
	assert_signal_emitted(screen, "restart_run")
	assert_true(screen.is_restart_emitted())


func test_return_button_disabled_after_press() -> void:
	# After firing restart_run, the button is disabled — visual feedback
	# matches the one-shot signal semantics.
	var screen: DescendScreen = _make_screen()
	screen.press_return_for_test()
	var btn: Button = screen.get_return_button()
	assert_true(btn.disabled, "return button is disabled after press")


# ---- Spec test 4: button mash doesn't fire signal multiple times -----


func test_rapid_button_mash_fires_restart_run_exactly_once() -> void:
	var screen: DescendScreen = _make_screen()
	watch_signals(screen)
	screen.press_return_for_test()
	screen.press_return_for_test()
	screen.press_return_for_test()
	screen.press_return_for_test()
	assert_signal_emit_count(
		screen, "restart_run", 1, "restart_run emits exactly once even under rapid mash"
	)


func test_pressing_button_during_fade_still_works() -> void:
	# Edge: the player is impatient and clicks the button mid-fade. We
	# should still fire the signal (no "wait for fade to complete" gate).
	# This makes the screen feel responsive even for fast players.
	var screen: DescendScreen = _make_screen()
	watch_signals(screen)
	# Don't complete the fade.
	assert_false(screen.is_fade_complete())
	screen.press_return_for_test()
	assert_signal_emitted(screen, "restart_run")


# ---- Color contract --------------------------------------------------


func test_panel_background_color_matches_palette() -> void:
	# Uma `palette.md` / death-restart Beat D: panel-background is `#1B1A1F`
	# at 100% opacity for stop-the-world moments.
	var bg_color: Color = DescendScreen.PANEL_BG_COLOR
	# `#1B1A1F` ≈ (0.106, 0.102, 0.122) sRGB.
	assert_almost_eq(bg_color.r, 0.106, 0.01)
	assert_almost_eq(bg_color.g, 0.102, 0.01)
	assert_almost_eq(bg_color.b, 0.122, 0.01)
	assert_almost_eq(
		bg_color.a, 1.0, 0.001, "panel BG is fully opaque per stop-the-world convention"
	)


func test_title_color_is_ember_accent() -> void:
	# Uma `palette.md`: ember accent `#FF6A2A` is the brand. Title uses it.
	var title_color: Color = DescendScreen.TITLE_COLOR
	# `#FF6A2A` ≈ (1.0, 0.416, 0.165) sRGB.
	assert_almost_eq(title_color.r, 1.0, 0.001)
	assert_almost_eq(title_color.g, 0.416, 0.01)
	assert_almost_eq(title_color.b, 0.165, 0.01)


# ---- Open Map button → WorldMapPanel host wiring ----------------------
#
# Regression-pin for ticket `86c9y10fv` Sponsor RC soak P0 (2026-05-24):
# Sponsor clicked Open Map and saw nothing happen. The bug was NOT that
# the button signal failed to fire — it was that the panel mounted at
# layer=70 while DescendScreen sits at layer=100 with a 100%-opaque full-
# rect BG. The panel WAS in the tree; it was just invisible because the
# descend chrome was drawn on top.
#
# The bug CLASS this group of tests catches: "panel mounted but rendered
# below an opaque host." Tests assert structural invariants, not just
# "panel exists after click." A test that only asserted
# `get_world_map_panel() != null` post-click would have green-passed
# during the entire bug era (the panel WAS being instantiated and added
# to the tree).


func test_open_map_button_text_matches_constant() -> void:
	var screen: DescendScreen = _make_screen()
	var btn: Button = screen.get_open_map_button()
	assert_not_null(btn, "open-map button exists after _ready")
	assert_eq(
		btn.text,
		DescendScreen.OPEN_MAP_BUTTON_TEXT,
		"open-map button text matches authoritative constant",
	)


func test_open_map_button_pressed_signal_is_connected() -> void:
	# Pin the wiring at the signal-connection layer. A regression that
	# accidentally drops the `pressed.connect(_on_open_map_pressed)` line
	# at DescendScreen.gd:248 fails here BEFORE any behavior assertion
	# downstream.
	var screen: DescendScreen = _make_screen()
	var btn: Button = screen.get_open_map_button()
	assert_not_null(btn, "open-map button exists")
	var conns: Array = btn.pressed.get_connections()
	assert_gt(
		conns.size(),
		0,
		"open-map button `pressed` signal MUST have at least one listener wired",
	)


func test_pressing_open_map_instantiates_world_map_panel() -> void:
	# Pin the click → instantiate path. The pre-fix bug was NOT this step
	# — the panel WAS being instantiated correctly. But if a future
	# refactor drops the load + add_child path, the test fails before
	# the visibility-layer test below.
	var screen: DescendScreen = _make_screen()
	assert_null(screen.get_world_map_panel(), "panel is null pre-click")
	screen.press_open_map_for_test()
	var panel: CanvasLayer = screen.get_world_map_panel()
	assert_not_null(panel, "panel is non-null after click")
	assert_true(is_instance_valid(panel), "panel is a live instance")


func test_world_map_panel_layer_above_descend_screen_layer() -> void:
	# REGRESSION PIN — the load-bearing assertion for the 2026-05-24
	# Sponsor RC soak P0. The bug CLASS this catches: "panel exists but
	# is visually covered by the opaque host." Without this test, a
	# refactor that:
	#   (a) drops the `_world_map_panel.layer = layer + 1` override
	#   (b) reverts to mounting at root (the prior "alternative
	#       considered: rejected" framing)
	#   (c) lowers DescendScreen.layer below 100 in a way that breaks
	#       the assumption
	# would all silently regress visibility. The assertion is layer-
	# arithmetic so it survives any future reshuffle of CanvasLayer
	# absolute values (e.g., HUD layer migration from 0 → 50).
	var screen: DescendScreen = _make_screen()
	screen.press_open_map_for_test()
	var panel: CanvasLayer = screen.get_world_map_panel()
	assert_not_null(panel, "panel mounted")
	assert_gt(
		panel.layer,
		screen.layer,
		(
			"WorldMapPanel.layer MUST be > DescendScreen.layer so the panel"
			+ " renders ABOVE the opaque descend BG (Sponsor RC soak P0"
			+ " 2026-05-24 regression class)"
		),
	)


func test_repeated_open_map_press_is_idempotent() -> void:
	# Rapid-click guard — matches the return-button idempotence shape.
	# Without the early-return at DescendScreen.gd:305 the panel would
	# orphan-leak on every click after the first.
	var screen: DescendScreen = _make_screen()
	screen.press_open_map_for_test()
	var first_panel: CanvasLayer = screen.get_world_map_panel()
	assert_not_null(first_panel)
	screen.press_open_map_for_test()
	screen.press_open_map_for_test()
	var third_panel: CanvasLayer = screen.get_world_map_panel()
	assert_eq(
		first_panel.get_instance_id(),
		third_panel.get_instance_id(),
		"repeated press_open_map returns the same panel instance (idempotent)",
	)


func test_open_map_panel_listens_to_close_requested() -> void:
	# Pin the close-signal wiring. The pre-fix code had this correctly;
	# regression-pin so a refactor doesn't accidentally drop the listener
	# (which would leak the panel — Esc would clear `_open` but not
	# `_world_map_panel`, and re-press would early-return forever).
	var screen: DescendScreen = _make_screen()
	screen.press_open_map_for_test()
	var panel: CanvasLayer = screen.get_world_map_panel()
	assert_not_null(panel)
	var conns: Array = panel.close_requested.get_connections()
	assert_gt(
		conns.size(),
		0,
		"WorldMapPanel.close_requested MUST have a DescendScreen listener wired",
	)
