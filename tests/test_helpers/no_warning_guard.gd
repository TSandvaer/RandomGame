class_name NoWarningGuard
extends RefCounted
## GUT helper that captures `WarningBus.warning_emitted` / `error_emitted`
## emissions during a test scope and exposes assertions + an opt-out
## allow-list for genuine expected-warning paths.
##
## **Ticket 86c9uf0mm — universal warning gate Half B.**
##
## ## Why this exists
##
## See `scripts/debug/WarningBus.gd` for the Godot 4.3 logger-API
## investigation. Tl;dr: GDScript can't intercept native `push_warning`
## without a wrapper. The `WarningBus` autoload IS the wrapper; this
## helper is the test-side observer.
##
## ## Usage in a GUT test
##
##   const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")
##
##   var _warn_guard: NoWarningGuard
##
##   func before_each() -> void:
##       _warn_guard = NoWarningGuard.new()
##       _warn_guard.attach()
##
##   func after_each() -> void:
##       _warn_guard.assert_clean(self)
##       _warn_guard.detach()
##       _warn_guard = null
##
## ## Opt-out for tests that DELIBERATELY exercise a warning path
##
## Some tests (especially partial-corruption recovery or unknown-id
## drift detectors) MUST produce a warning to validate the failure
## handling. Mark these explicitly with `expect_warning(pattern)`:
##
##   func test_unknown_item_id_emits_warning_and_drops() -> void:
##       _warn_guard.expect_warning("unknown item id")
##       # ... exercise the code path that emits the warning ...
##       _warn_guard.assert_clean(self)   # passes — expected warning was matched
##
## `pattern` is a substring of the warning text (case-sensitive). Each
## `expect_warning` consumes ONE matching warning; if MORE warnings fire
## than were expected, the assertion still fails (the opt-out is precise,
## not blanket).
##
## ## Negative-assertion sanity test
##
## A paired test in `tests/test_no_warning_guard.gd` proves:
##   1. The guard CATCHES a deliberate `WarningBus.warn("...")` call.
##   2. The guard LETS THROUGH a matching `expect_warning(pattern)`.
##   3. The guard FAILS the test if a warning fires but no `expect_warning`
##      was registered.
##
## ## Limitations
##
## - **Only catches `WarningBus.warn/error` calls.** Direct `push_warning`
##   calls (the 60+ legacy call sites in `scripts/`) bypass the bus and
##   are INVISIBLE to this guard. Migration of the load-bearing surfaces
##   (save-load, ItemInstance, MobRegistry) is in scope for the Half B PR;
##   non-load-bearing surfaces remain on direct push_warning.
## - **Test-scope local.** Each instance captures only between `attach()`
##   and `detach()`. A test that forgets `detach()` leaks the signal
##   connection but does not affect other tests' guards (each guard's
##   `_on_warning` is a unique Callable).


# Captured warnings since `attach()`. Each entry is a Dictionary with keys
# `text` (String), `category` (String), `kind` (String — "warning" or
# "error").
var _captured: Array = []

# Expected-warning allow-list patterns set by `expect_warning(pattern)`.
# Each entry is a Dictionary with keys `pattern` (String — substring
# matcher) and `matched` (bool — set true the first time a captured
# warning contains the pattern; subsequent matching warnings fall
# through to the violation set).
var _expectations: Array = []

# Whether the guard is currently attached to the bus signals. Belt-and-
# braces check so `detach()` after `detach()` doesn't fault.
var _attached: bool = false


## Attach to `WarningBus` signals. Call from `before_each()`.
##
## If `WarningBus` is not registered as an autoload (e.g. a test runs in a
## context where the autoload didn't boot), `attach()` is a no-op and
## `assert_clean(self)` will always pass — fail-safe. The paired test
## verifies the autoload IS registered, so the silent-no-op path is
## reserved for diagnostic scenarios.
func attach() -> void:
	var bus: Node = _bus()
	if bus == null:
		# No WarningBus autoload — fail-safe no-op. Production builds register
		# the autoload via `project.godot`; only stripped-down test contexts
		# would land here.
		return
	if _attached:
		return
	bus.warning_emitted.connect(_on_warning)
	bus.error_emitted.connect(_on_error)
	_attached = true


## Detach from `WarningBus` signals. Call from `after_each()`.
##
## Idempotent — safe to call when not attached. Clears the capture buffer
## and expectation list so the guard can be re-attached cleanly in the
## next test.
func detach() -> void:
	if not _attached:
		_captured.clear()
		_expectations.clear()
		return
	var bus: Node = _bus()
	if bus != null:
		if bus.warning_emitted.is_connected(_on_warning):
			bus.warning_emitted.disconnect(_on_warning)
		if bus.error_emitted.is_connected(_on_error):
			bus.error_emitted.disconnect(_on_error)
	_attached = false
	_captured.clear()
	_expectations.clear()


## Register an expected-warning pattern. The next warning whose `text`
## contains `pattern` (substring match, case-sensitive) is consumed
## without counting as a violation. Subsequent matching warnings are
## NOT consumed by this expectation — register another `expect_warning`
## call if multiple matching warnings are expected.
##
## `pattern` is a plain substring. If you need regex, build a small
## helper around `RegEx.compile`; the substring matcher is intentionally
## simple to keep test intent readable.
func expect_warning(pattern: String) -> void:
	_expectations.append({"pattern": pattern, "matched": false})


## Assert that no UNEXPECTED warnings or errors were captured since
## `attach()`. Pass `gut_test` (the calling GutTest instance) so the
## helper can use the test's `assert_eq` for failure reporting — keeps
## failures attributed to the right test in the GUT report.
##
## Failure shape: the message lists every unexpected captured warning,
## prefixed with its kind ("[WARNING]" / "[ERROR]"). Expected-but-not-fired
## patterns also flag a soft warning in the message so a test that
## `expect_warning(...)`s a pattern that never fires gets a hint about
## the dead expectation.
func assert_clean(gut_test) -> void:
	# Bucket captured items by whether ANY remaining expectation matches.
	# Each expectation consumes at most one warning.
	var violations: Array = []
	for entry in _captured:
		var consumed: bool = false
		for exp in _expectations:
			if exp["matched"]:
				continue
			if (entry["text"] as String).find(exp["pattern"] as String) >= 0:
				exp["matched"] = true
				consumed = true
				break
		if not consumed:
			violations.append(entry)

	# Dead expectations — registered but never fired. Soft-warn only; the
	# test body's intent might be "no warning was expected this run, but
	# the path is allow-listed defensively." Loud-fail would over-trigger.
	var dead_expectations: Array = []
	for exp in _expectations:
		if not exp["matched"]:
			dead_expectations.append(exp["pattern"])

	if violations.size() > 0:
		var lines: Array = []
		for v in violations:
			var prefix: String = "[WARNING]" if v["kind"] == "warning" else "[ERROR]"
			var cat: String = (" {%s}" % v["category"]) if (v["category"] as String) != "" else ""
			lines.append("  %s%s %s" % [prefix, cat, v["text"]])
		var msg: String = (
			"NoWarningGuard: %d unexpected WarningBus emission(s) during this test. "
			+ "The universal-warning gate (ticket 86c9uf0mm Half B) exists to catch "
			+ "save-load unknown-id warnings, DirAccess HTML5 recursion warnings, "
			+ "save-schema migration warnings, and any analogous WarningBus.warn/error "
			+ "calls that fire during a test that wasn't expecting them.\n\n"
			+ "Captured emissions:\n%s\n\nTo opt out for a specific known warning "
			+ "shape:\n  _warn_guard.expect_warning(\"substring of warning text\")\n\n"
			+ "If this warning is a regression (NOT expected), fix the underlying "
			+ "source code path — do NOT add an expect_warning to silence it."
		) % [violations.size(), "\n".join(lines)]
		if dead_expectations.size() > 0:
			msg += (
				"\n\n(Note: %d expect_warning pattern(s) never matched — they may "
				+ "be stale: %s)"
			) % [dead_expectations.size(), str(dead_expectations)]
		gut_test.assert_eq(violations.size(), 0, msg)
	# If `violations.size() == 0`, this is the green path — no GUT assertion
	# call at all (an `assert_eq(0, 0, ...)` would just inflate the assertion
	# count for every clean test).


## Returns captured warning/error texts (snapshot, not live). Mostly for
## debugging when a test is being authored — production tests should rely
## on `assert_clean(self)` rather than poking the buffer.
func get_captured_texts() -> Array:
	var out: Array = []
	for e in _captured:
		out.append(e["text"])
	return out


## Returns the number of captured warning+error emissions. Useful for
## tests that want to assert "exactly N warnings fired" (matched by
## N `expect_warning` calls).
func captured_count() -> int:
	return _captured.size()


# ---- Internals ----------------------------------------------------------


## Looks up the `WarningBus` autoload. Returns null if the autoload is not
## registered — `attach()` no-ops in that case (see attach() docstring).
func _bus() -> Node:
	var main_loop: SceneTree = Engine.get_main_loop() as SceneTree
	if main_loop == null:
		return null
	return main_loop.root.get_node_or_null("WarningBus")


func _on_warning(text: String, category: String) -> void:
	_captured.append({"text": text, "category": category, "kind": "warning"})


func _on_error(text: String, category: String) -> void:
	_captured.append({"text": text, "category": category, "kind": "error"})
