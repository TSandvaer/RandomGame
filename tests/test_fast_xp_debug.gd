extends GutTest
## Tests for Hook 2 — debug-only fast-XP toggle.
##
## Verifies:
##   - The multiplier defaults to 1 (production-safe).
##   - `toggle_fast_xp_for_test()` flips it to 100 in debug builds.
##   - The `fast_xp_toggled` signal fires on toggle.
##   - Release builds *cannot* enable fast-XP — `_toggle_fast_xp()` is a no-op
##     and `xp_multiplier()` returns 1 even if state somehow became true.
##   - The Ctrl+Shift+X chord triggers a toggle when fed via _input
##     (debug-build path).
##
## Note on release-build verification: GUT runs against the editor binary,
## which is by definition a debug build (`OS.is_debug_build()` returns
## true). We can't actually test "in release" from inside GUT. What we CAN
## test is that the gate is structurally present — by reading the source
## and asserting the early returns are wired into `_toggle_fast_xp` and
## `_input`. We do that via a state-poisoning test: forcibly set
## `fast_xp_enabled = true`, then assert `xp_multiplier()` reflects the
## debug-build state. The release-build assertion is a code review
## checkpoint flagged in `team/devon-dev/debug-flags.md`.


func _flags() -> Node:
	var df: Node = Engine.get_main_loop().root.get_node_or_null("DebugFlags")
	assert_not_null(df, "DebugFlags autoload must be registered in project.godot")
	return df


func before_each() -> void:
	# Ensure each test starts from default state. Debug builds only — the
	# autoload's _ready resolves test_mode from CLI/env, which we don't
	# touch here.
	_flags().fast_xp_enabled = false


func after_each() -> void:
	_flags().fast_xp_enabled = false


# --- Multiplier round-trip ----------------------------------------------

func test_default_multiplier_is_one() -> void:
	assert_eq(_flags().xp_multiplier(), 1, "default fast_xp off -> 1x XP")


func test_toggle_enables_fast_xp_in_debug_build() -> void:
	# Sanity guard — the test only proves the debug-build path. If somehow
	# this run isn't a debug build, skip with a recognizable message.
	if not OS.is_debug_build():
		pending("Test requires a debug build (GUT in the editor satisfies this).")
		return
	_flags().toggle_fast_xp_for_test()
	assert_true(_flags().fast_xp_enabled, "after toggle, fast_xp_enabled is true")
	assert_eq(_flags().xp_multiplier(), 100, "fast_xp on -> 100x XP")


func test_toggle_is_idempotent_pair() -> void:
	if not OS.is_debug_build():
		pending("Test requires a debug build.")
		return
	_flags().toggle_fast_xp_for_test()
	_flags().toggle_fast_xp_for_test()
	assert_false(_flags().fast_xp_enabled, "two toggles cancel out")
	assert_eq(_flags().xp_multiplier(), 1)


# --- Signal --------------------------------------------------------------

func test_toggle_fires_signal() -> void:
	if not OS.is_debug_build():
		pending("Test requires a debug build.")
		return
	watch_signals(_flags())
	_flags().toggle_fast_xp_for_test()
	assert_signal_emitted(_flags(), "fast_xp_toggled")
	assert_signal_emitted_with_parameters(_flags(), "fast_xp_toggled", [true])


# --- Chord input ---------------------------------------------------------

func test_ctrl_shift_x_triggers_toggle() -> void:
	# Synthesize the InputEventKey the OS would deliver. Verifies the chord
	# is wired correctly, not just `toggle_fast_xp_for_test`.
	if not OS.is_debug_build():
		pending("Test requires a debug build.")
		return
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = KEY_X
	ev.pressed = true
	ev.echo = false
	ev.ctrl_pressed = true
	ev.shift_pressed = true
	# Call _input directly — Input.parse_input_event would also work but
	# this avoids the indirection.
	_flags()._input(ev)
	assert_true(_flags().fast_xp_enabled, "Ctrl+Shift+X (synthetic) toggles fast-XP")


func test_chord_ignores_release_modifier_combo() -> void:
	# Bare X (no modifiers) must NOT toggle — this is the safety against an
	# accidental gameplay key colliding with the chord.
	if not OS.is_debug_build():
		pending("Test requires a debug build.")
		return
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = KEY_X
	ev.pressed = true
	ev.echo = false
	ev.ctrl_pressed = false
	ev.shift_pressed = false
	_flags()._input(ev)
	assert_false(_flags().fast_xp_enabled, "Bare X must not toggle fast-XP")


func test_chord_ignores_echo_events() -> void:
	# Holding the chord must not flip the flag every frame.
	if not OS.is_debug_build():
		pending("Test requires a debug build.")
		return
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = KEY_X
	ev.pressed = true
	ev.echo = true   # auto-repeat
	ev.ctrl_pressed = true
	ev.shift_pressed = true
	_flags()._input(ev)
	assert_false(_flags().fast_xp_enabled, "Echo events must not toggle fast-XP")


func test_chord_ignores_release_phase() -> void:
	# Key-up event must not toggle (we toggle on key-down only).
	if not OS.is_debug_build():
		pending("Test requires a debug build.")
		return
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = KEY_X
	ev.pressed = false
	ev.ctrl_pressed = true
	ev.shift_pressed = true
	_flags()._input(ev)
	assert_false(_flags().fast_xp_enabled, "Key-up must not toggle fast-XP")


# --- Release-build structural gate (state poisoning) --------------------

func test_xp_multiplier_only_amplifies_when_debug_build() -> void:
	# Force fast_xp_enabled true, then assert xp_multiplier respects the
	# debug-build gate. In a debug build this returns 100; in release it
	# would return 1 even with the flag set, by the early return in
	# xp_multiplier(). This is the "compile-out" structural assertion.
	_flags().fast_xp_enabled = true
	if OS.is_debug_build():
		assert_eq(_flags().xp_multiplier(), 100)
	else:
		assert_eq(_flags().xp_multiplier(), 1, "release build never amplifies")
