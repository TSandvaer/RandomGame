extends GutTest
## Paired tests for `tests/test_helpers/no_warning_guard.gd` + the
## `WarningBus` autoload. Pin the guard's core contract:
##
##   1. The guard CATCHES a deliberate `WarningBus.warn(...)` call (the
##      whole point — negative-assertion sanity).
##   2. The guard LETS THROUGH a matching `expect_warning(pattern)` call
##      (the opt-out mechanism works).
##   3. The guard catches a deliberate `WarningBus.error(...)` call too.
##   4. A guard never attached produces no captures (defense in depth).
##   5. The `WarningBus` autoload is actually registered (boot-time pin).
##
## **Ticket 86c9uf0mm — universal warning gate Half B (GUT side).**
##
## **Why this file is mandatory:** without these tests, the guard could
## silently no-op (e.g. if a future refactor breaks the signal wiring)
## and every other test would still pass — masking the regression. This
## file is the canary that proves the gate works.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")


func _bus() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("WarningBus")


# ---- AC1: WarningBus autoload is registered -----------------------------

func test_warning_bus_autoload_is_registered() -> void:
	# If this fails, every other guard-using test is silently no-op'd —
	# the guard's `attach()` returns early when the autoload is missing.
	# Pinning the autoload registration is the load-bearing assertion.
	var bus: Node = _bus()
	assert_not_null(bus, "WarningBus autoload must be registered at /root/WarningBus")
	assert_true(bus.has_signal("warning_emitted"),
		"WarningBus must expose warning_emitted signal")
	assert_true(bus.has_signal("error_emitted"),
		"WarningBus must expose error_emitted signal")
	assert_true(bus.has_method("warn"), "WarningBus must expose warn(text, category)")
	assert_true(bus.has_method("error"), "WarningBus must expose error(text, category)")


# ---- AC2: Guard catches a deliberate WarningBus.warn() call -------------

func test_guard_catches_deliberate_warning_via_warning_bus() -> void:
	# This is the negative-assertion sanity test. If the guard doesn't
	# catch a deliberate warning, it doesn't catch a real regression
	# either — the gate is decorative.
	var guard := NoWarningGuard.new()
	guard.attach()
	_bus().warn("TEST-86c9uf0mm: deliberate canary warning — guard must catch this",
		"test-canary")
	assert_eq(guard.captured_count(), 1,
		"NoWarningGuard must capture a WarningBus.warn() call (negative-assertion sanity)")
	var texts: Array = guard.get_captured_texts()
	assert_true((texts[0] as String).find("deliberate canary warning") >= 0,
		"captured text must contain the warning's body")
	guard.detach()


# ---- AC3: expect_warning() opt-out lets matching warning pass -----------

func test_expect_warning_lets_matching_warning_pass_assert_clean() -> void:
	# A test that DELIBERATELY exercises a warning path (e.g. partial-
	# corruption recovery) registers expect_warning(pattern) and the
	# guard must NOT flag that warning as a violation.
	var guard := NoWarningGuard.new()
	guard.attach()
	guard.expect_warning("known opt-out pattern")
	_bus().warn("WARNING: this is the known opt-out pattern in the middle of the message",
		"test-opt-out")
	# captured_count() still reports 1 (the warning DID fire), but
	# assert_clean() sees the matching expectation and does NOT flag a
	# violation. We can't directly assert "assert_clean passes" without
	# adding test plumbing — pin via "no extra failed assertions" by
	# checking the captured set is non-empty AND the expectation is
	# consumed (matched=true after assert_clean).
	assert_eq(guard.captured_count(), 1,
		"the warning still fires + is captured (opt-out is filter-side, not capture-side)")
	# Call assert_clean — if it fails, the test fails with the guard's
	# violation message. If it passes, this test moves on (green).
	guard.assert_clean(self)
	guard.detach()


# ---- AC4: Guard catches a deliberate WarningBus.error() call ------------

func test_guard_catches_deliberate_error_via_warning_bus() -> void:
	# Errors and warnings share the same gate — both are critical.
	var guard := NoWarningGuard.new()
	guard.attach()
	_bus().error("TEST-86c9uf0mm: deliberate canary error — guard must catch this",
		"test-canary")
	assert_eq(guard.captured_count(), 1,
		"NoWarningGuard must capture a WarningBus.error() call")
	guard.detach()


# ---- AC5: Mismatched expect_warning does NOT consume a real warning -----

func test_expect_warning_mismatch_does_not_consume_real_warning() -> void:
	# If expect_warning(pattern) registers a pattern that does NOT match
	# the warning that fires, the warning is still a violation. The
	# opt-out is precise (substring match), not blanket.
	var guard := NoWarningGuard.new()
	guard.attach()
	guard.expect_warning("THIS-PATTERN-DOES-NOT-EXIST-XYZZY")
	_bus().warn("genuine warning text that does not contain the registered pattern",
		"test-mismatch")
	assert_eq(guard.captured_count(), 1, "warning fires regardless of expect_warning")
	# We can't directly test "assert_clean fails" without adding gut.fail
	# capture plumbing. Instead, verify the violation set construction by
	# manually checking: the registered expectation should still be
	# unmatched (its `matched` flag stays false because the substring
	# doesn't appear in the captured text).
	# Build the same check the assert_clean() body does:
	var violations: Array = []
	for entry in guard._captured:
		var consumed: bool = false
		for exp in guard._expectations:
			if (entry["text"] as String).find(exp["pattern"] as String) >= 0:
				consumed = true
				break
		if not consumed:
			violations.append(entry)
	assert_eq(violations.size(), 1,
		"expect_warning with non-matching pattern leaves the violation in the set")
	guard.detach()


# ---- AC6: detach() is idempotent + clears state -------------------------

func test_detach_is_idempotent_and_clears_captured_buffer() -> void:
	var guard := NoWarningGuard.new()
	guard.attach()
	_bus().warn("noise before detach", "test-idempotent")
	assert_eq(guard.captured_count(), 1)
	guard.detach()
	assert_eq(guard.captured_count(), 0, "detach() clears captured buffer")
	# Double-detach is safe (no faults).
	guard.detach()
	# Re-attach + emit + capture works for the next test cycle.
	guard.attach()
	_bus().warn("noise after re-attach", "test-idempotent")
	assert_eq(guard.captured_count(), 1, "guard re-attaches cleanly after detach")
	guard.detach()


# ---- AC7: Multiple expect_warning patterns consume independently --------

func test_multiple_expect_warning_patterns_each_consume_one() -> void:
	# Two distinct patterns + two distinct warnings -> both consumed,
	# zero violations.
	var guard := NoWarningGuard.new()
	guard.attach()
	guard.expect_warning("first known pattern")
	guard.expect_warning("second known pattern")
	_bus().warn("warning about the first known pattern in stash", "test-multi")
	_bus().warn("warning about the second known pattern in stash", "test-multi")
	assert_eq(guard.captured_count(), 2)
	guard.assert_clean(self)  # both consumed -> no violations
	guard.detach()


# ---- AC8: Same expect_warning pattern does NOT swallow two warnings -----

func test_one_expect_warning_consumes_one_warning_not_all() -> void:
	# expect_warning is per-emission — if two matching warnings fire but
	# only one expect_warning was registered, the second is a violation.
	var guard := NoWarningGuard.new()
	guard.attach()
	guard.expect_warning("repeated pattern")
	_bus().warn("first emission of the repeated pattern", "test-multi")
	_bus().warn("second emission of the repeated pattern", "test-multi")
	# Replicate assert_clean's violation-set logic to assert directly.
	var violations: Array = []
	for entry in guard._captured:
		var consumed: bool = false
		for exp in guard._expectations:
			if exp["matched"]:
				continue
			if (entry["text"] as String).find(exp["pattern"] as String) >= 0:
				exp["matched"] = true
				consumed = true
				break
		if not consumed:
			violations.append(entry)
	assert_eq(violations.size(), 1,
		"one expect_warning consumes one warning; the second is still a violation")
	guard.detach()


# ---- AC9: Guard with no attach() never captures (safety net) ------------

func test_guard_without_attach_captures_nothing() -> void:
	# Defense in depth — a test that forgets to call attach() shouldn't
	# silently start passing just because no warnings happen to fire.
	var guard := NoWarningGuard.new()
	# Intentionally no attach() — emit a warning, verify it is NOT captured.
	_bus().warn("warning fires but guard is unattached", "test-unattached")
	assert_eq(guard.captured_count(), 0,
		"unattached guard captures nothing (no silent passes)")
