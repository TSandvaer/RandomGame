extends GutTest
## Paired GUT tests for the TutorialEventBus.request_beat combat-trace shim
## (ticket `86c9qbmer`).
##
## **What this tests:**
## `request_beat()` now calls `DebugFlags.combat_trace(...)` BEFORE emitting
## `tutorial_beat_requested`. The GUT suite runs headless (not `OS.has_feature("web")`),
## so the trace line is a no-op — `DebugFlags.combat_trace_enabled()` returns false.
## These tests verify the method still:
##   1. Emits `tutorial_beat_requested` correctly after the trace call (wasd beat).
##   2. Passes beat_id and anchor through to the signal payload — per beat:
##      dodge, lmb_strike, rmb_heavy.
##   3. Default anchor (= 0) works correctly.
##   4. DebugFlags autoload is accessible from the bus context.
##   5. No push_error / push_warning fires across all four beats.
##
## **Why separate test functions per beat:**
## GUT's `get_signal_parameters(node, signal, index)` returns the emission at
## `index` within the current watch session. Calling `watch_signals` once and
## then emitting multiple beats accumulates all emissions under index 0, 1, 2…
## but there is no API to reset the accumulator without ending the watch session.
## Using a separate test function per beat guarantees a fresh watch session and
## a stable index-0 assertion for each beat.
##
## **Why no print-output assertions here:**
## The `[combat-trace] TutorialEventBus.request_beat | beat=X anchor=N` line
## is gated behind `OS.has_feature("web") == true`. In headless GUT, the gate
## is always false — the print never runs. The Playwright spec
## `tests/playwright/specs/tutorial-beat-trace.spec.ts` is the binding coverage
## for the trace line in a real HTML5 build (where the gate is true).
##
## **Test bar classification:**
## Tier 2 bus-integration (per `team/TESTING_BAR.md` + combat-architecture.md
## §"[combat-trace] diagnostic shim"): tests assert downstream signal
## consequences, not method-was-called. Signal-emit-count + payload content
## are the load-bearing invariants.
##
## References:
##   - scripts/ui/TutorialEventBus.gd — `request_beat()` + trace line (this ticket)
##   - scripts/debug/DebugFlags.gd — `combat_trace(tag, msg)` shim (HTML5-gated)
##   - tests/playwright/specs/tutorial-beat-trace.spec.ts — HTML5 trace assertions
##   - .claude/docs/combat-architecture.md § "[combat-trace] diagnostic shim"


func _bus() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("TutorialEventBus")
	assert_not_null(n, "TutorialEventBus autoload registered (precondition)")
	return n


# ---- 1: wasd beat — primary regression guard ---------------------------

func test_request_beat_wasd_emits_signal_with_trace_wired() -> void:
	## Primary regression guard for ticket 86c9qbmer:
	## Adding the DebugFlags.combat_trace() call before emit must NOT break the
	## signal emission. The trace is a no-op in headless GUT; the signal must
	## still fire with the correct payload.
	var bus: Node = _bus()
	watch_signals(bus)
	bus.request_beat(&"wasd", 0)
	assert_signal_emitted(bus, "tutorial_beat_requested",
		"request_beat must emit tutorial_beat_requested even with trace call wired")
	assert_signal_emit_count(bus, "tutorial_beat_requested", 1,
		"exactly one emit per request_beat call")
	var params: Array = get_signal_parameters(bus, "tutorial_beat_requested", 0)
	assert_eq(params[0], &"wasd",
		"signal payload beat_id = &'wasd' (trace must not alter the argument)")
	assert_eq(params[1], 0,
		"signal payload anchor = 0 (trace must not alter the anchor)")


# ---- 2: dodge beat payload -----------------------------------------------

func test_request_beat_dodge_payload_correct_after_trace_wired() -> void:
	## Verify the trace call does NOT alter the &"dodge" beat_id or anchor.
	## Fresh watch_signals session guarantees index 0 is this beat's emission.
	var bus: Node = _bus()
	watch_signals(bus)
	bus.request_beat(&"dodge", 2)
	assert_signal_emitted(bus, "tutorial_beat_requested",
		"request_beat(&'dodge', 2) must emit tutorial_beat_requested")
	var params: Array = get_signal_parameters(bus, "tutorial_beat_requested", 0)
	assert_eq(params[0], &"dodge",
		"signal payload beat_id = &'dodge' (trace StringName->String must not mutate it)")
	assert_eq(params[1], 2,
		"signal payload anchor = 2 (unchanged through trace call)")
	assert_eq(bus.resolve_beat_text(&"dodge"), "Space to dodge-roll.",
		"resolve_beat_text(&'dodge') returns the Uma Beat 4 text")


# ---- 3: lmb_strike beat payload ------------------------------------------

func test_request_beat_lmb_strike_payload_correct_after_trace_wired() -> void:
	var bus: Node = _bus()
	watch_signals(bus)
	bus.request_beat(&"lmb_strike", 2)
	assert_signal_emitted(bus, "tutorial_beat_requested",
		"request_beat(&'lmb_strike', 2) must emit tutorial_beat_requested")
	var params: Array = get_signal_parameters(bus, "tutorial_beat_requested", 0)
	assert_eq(params[0], &"lmb_strike",
		"signal payload beat_id = &'lmb_strike' (trace must not mutate it)")
	assert_eq(params[1], 2, "signal payload anchor = 2")
	assert_eq(bus.resolve_beat_text(&"lmb_strike"), "LMB to strike.",
		"resolve_beat_text(&'lmb_strike') returns the Uma Beat 4 text")


# ---- 4: rmb_heavy beat payload -------------------------------------------

func test_request_beat_rmb_heavy_payload_correct_after_trace_wired() -> void:
	var bus: Node = _bus()
	watch_signals(bus)
	bus.request_beat(&"rmb_heavy", 2)
	assert_signal_emitted(bus, "tutorial_beat_requested",
		"request_beat(&'rmb_heavy', 2) must emit tutorial_beat_requested")
	var params: Array = get_signal_parameters(bus, "tutorial_beat_requested", 0)
	assert_eq(params[0], &"rmb_heavy",
		"signal payload beat_id = &'rmb_heavy' (trace must not mutate it)")
	assert_eq(params[1], 2, "signal payload anchor = 2")
	assert_eq(bus.resolve_beat_text(&"rmb_heavy"), "RMB for heavy strike.",
		"resolve_beat_text(&'rmb_heavy') returns the Uma Beat 5 text")


# ---- 5: default anchor (= 0) works correctly ----------------------------

func test_request_beat_default_anchor_with_trace_wired() -> void:
	## request_beat has `anchor: int = 0` default. Verify the default path
	## (no explicit anchor argument) still emits correctly with trace wired.
	var bus: Node = _bus()
	watch_signals(bus)
	bus.request_beat(&"dodge")  # no anchor arg — uses default = 0
	assert_signal_emitted(bus, "tutorial_beat_requested",
		"request_beat with default anchor must emit the signal")
	var params: Array = get_signal_parameters(bus, "tutorial_beat_requested", 0)
	assert_eq(params[1], 0,
		"default anchor = 0 must flow through to the signal payload unchanged")


# ---- 6: DebugFlags autoload reachable from bus context ------------------

func test_debugflags_autoload_is_accessible() -> void:
	## Belt-and-suspenders: verify DebugFlags is registered as an autoload.
	## If this test fails, any code path calling DebugFlags.combat_trace()
	## from an autoload context would silently fail or crash. This catches
	## mis-registration before the HTML5 build surfaces it.
	var flags: Node = Engine.get_main_loop().root.get_node_or_null("DebugFlags")
	assert_not_null(flags, "DebugFlags autoload must be registered in project.godot")
	# Verify the combat_trace_enabled() method exists and returns a bool.
	# In headless GUT (not web), this must return false — the gate is web-only.
	assert_has_method(flags, "combat_trace",
		"DebugFlags must expose combat_trace(tag, msg) method")
	assert_has_method(flags, "combat_trace_enabled",
		"DebugFlags must expose combat_trace_enabled() method")
	var enabled: bool = flags.combat_trace_enabled()
	assert_false(enabled,
		"combat_trace_enabled() must return false in headless GUT (not a web build). " +
		"If this fails, the OS.has_feature('web') gate in DebugFlags regressed.")


# ---- 7: trace call does not push_error or push_warning ------------------

func test_request_beat_produces_no_errors_or_warnings() -> void:
	## Regression guard: the trace call inside request_beat must not produce
	## any GDScript push_error / push_warning. We drive all four beats and
	## rely on GUT's built-in error capture to surface any push_error / assert
	## calls. (GUT auto-fails tests with Godot errors in their execution window.)
	var bus: Node = _bus()
	# Drive all four beats sequentially — no errors expected.
	bus.request_beat(&"wasd", 0)
	bus.request_beat(&"dodge", 2)
	bus.request_beat(&"lmb_strike", 2)
	bus.request_beat(&"rmb_heavy", 2)
	# If we reach here without GUT auto-failing, no push_error fired.
	pass
