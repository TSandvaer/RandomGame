extends GutTest
## Paired tests for `scripts/combat/TimeScaleDirector.gd`.
##
## **Ticket 86c9wjxxd — M3 Tier 2 Wave 1 T11.**
##
## Coverage shape per Priya's T11 AC:
##   1. Autoload registration + boot-time scale (sanity pin).
##   2. Single-request lifecycle — push, scale applied, release, restore.
##   3. Multi-request stacking — lowest-scale-in-top-priority wins.
##   4. Concurrent-tween conflict — priority dominates scale.
##   5. Expiry / auto-release via SceneTreeTimer (real-time, NOT scaled).
##   6. Re-request semantics — same reason replaces prior + cancels stale timer.
##   7. Reset / abort — clears stack, restores 1.0.
##   8. freeze() sugar — 0.0 + priority=2.
##   9. WarningBus routing on misuse — empty reason, out-of-range scale.
##  10. Signal emission — scale_changed fires only on change; request_changed
##      payload op strings.
##
## These cover the bug *class* (uncoordinated `Engine.time_scale` writers
## clobbering each other) not just the bug *instance* — a future writer
## that bypasses the director by writing `Engine.time_scale = X` directly
## remains invisible to this gate (see migration policy in
## `TimeScaleDirector.gd`). That class is regression-guarded by the
## fact that T2 + T3 + T16 (this director's downstream consumers in
## Wave 1) all route through `TimeScaleDirector.request/freeze` per their
## PR-shaped AC; a future surface that bypasses is flagged in code review.
##
## ## Test-isolation hygiene
##
## `before_each` calls `TimeScaleDirector.reset()` so a leaked request
## from a prior test (or a leaked direct write to `Engine.time_scale`
## elsewhere in the GUT suite) doesn't poison this file. The director
## itself defends against scene-tree reload by remaining autoload-scoped;
## a leak surfaces as a single test-file pollution, not cross-suite.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

var _warn_guard: NoWarningGuard
var _director: Node
var _scale_changes: Array = []
var _request_changes: Array = []


func before_each() -> void:
	_director = Engine.get_main_loop().root.get_node_or_null("TimeScaleDirector")
	# Defensive reset: every test starts with an empty stack + scale 1.0.
	if _director != null and _director.has_method("reset"):
		_director.reset()
	# Belt-and-braces: even if reset failed, force Engine.time_scale to 1.0
	# so a leaked prior-test write can't poison the assertions.
	Engine.time_scale = 1.0

	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()
	_scale_changes.clear()
	_request_changes.clear()
	if _director != null:
		_director.scale_changed.connect(_on_scale_changed)
		_director.request_changed.connect(_on_request_changed)


func after_each() -> void:
	if _director != null:
		if _director.scale_changed.is_connected(_on_scale_changed):
			_director.scale_changed.disconnect(_on_scale_changed)
		if _director.request_changed.is_connected(_on_request_changed):
			_director.request_changed.disconnect(_on_request_changed)
		if _director.has_method("reset"):
			_director.reset()
	# Belt: any test that asserted a frozen scale must NOT leak it.
	Engine.time_scale = 1.0
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


func _on_scale_changed(new_scale: float) -> void:
	_scale_changes.append(new_scale)


func _on_request_changed(reason: String, op: String) -> void:
	_request_changes.append({"reason": reason, "op": op})


# ---- AC1: autoload registration + boot-time scale ----------------------

func test_autoload_registered_at_root() -> void:
	# If this fails every other test in this file silently no-ops via
	# the `_director != null` guards.
	assert_not_null(_director,
		"TimeScaleDirector must be registered as autoload at /root/TimeScaleDirector "
		+ "(project.godot [autoload] section)")
	assert_true(_director.has_method("request"), "request(reason, scale, duration, priority) API present")
	assert_true(_director.has_method("release"), "release(reason) API present")
	assert_true(_director.has_method("freeze"), "freeze(duration, reason) API present")
	assert_true(_director.has_method("reset"), "reset() API present")
	assert_true(_director.has_method("current_scale"), "current_scale() API present")
	assert_true(_director.has_method("active_reasons"), "active_reasons() API present")
	assert_true(_director.has_method("is_active"), "is_active(reason) API present")
	assert_true(_director.has_signal("scale_changed"), "scale_changed signal present")
	assert_true(_director.has_signal("request_changed"), "request_changed signal present")


func test_boot_state_is_clean_scale_1_no_requests() -> void:
	assert_almost_eq(_director.current_scale(), 1.0, 0.001,
		"empty stack → scale 1.0")
	assert_almost_eq(Engine.time_scale, 1.0, 0.001,
		"Engine.time_scale mirrors director")
	assert_eq(_director.active_reasons().size(), 0,
		"no active reasons on boot")


# ---- AC2: single-request lifecycle -------------------------------------

func test_single_request_applies_scale_then_release_restores() -> void:
	_director.request("test_slow", 0.5, 0.0)  # 0.0 duration = no auto-release
	assert_almost_eq(_director.current_scale(), 0.5, 0.001,
		"single request at 0.5 sets effective scale to 0.5")
	assert_almost_eq(Engine.time_scale, 0.5, 0.001,
		"Engine.time_scale mirrors")
	assert_true(_director.is_active("test_slow"), "is_active reports true")

	_director.release("test_slow")
	assert_almost_eq(_director.current_scale(), 1.0, 0.001,
		"release with empty stack → 1.0")
	assert_almost_eq(Engine.time_scale, 1.0, 0.001,
		"Engine.time_scale restored")
	assert_false(_director.is_active("test_slow"), "is_active reports false after release")


func test_release_unknown_reason_is_silent_noop() -> void:
	_director.release("never_requested")
	assert_almost_eq(_director.current_scale(), 1.0, 0.001,
		"silent no-op on unknown release")
	# No warning fires (NoWarningGuard would catch via after_each).


# ---- AC3: multi-request stacking (lowest scale wins within priority) ---

func test_two_requests_same_priority_lowest_scale_wins() -> void:
	_director.request("slow_a", 0.6, 0.0)
	_director.request("slow_b", 0.3, 0.0)
	assert_almost_eq(_director.current_scale(), 0.3, 0.001,
		"two requests at default priority → most-restrictive (0.3) wins")


func test_release_lower_scale_falls_back_to_higher() -> void:
	_director.request("slow_a", 0.6, 0.0)
	_director.request("slow_b", 0.3, 0.0)
	_director.release("slow_b")
	assert_almost_eq(_director.current_scale(), 0.6, 0.001,
		"releasing lowest-scale request falls back to remaining 0.6")
	_director.release("slow_a")
	assert_almost_eq(_director.current_scale(), 1.0, 0.001,
		"releasing all → 1.0")


func test_release_higher_scale_doesnt_change_effective() -> void:
	_director.request("slow_a", 0.6, 0.0)
	_director.request("slow_b", 0.3, 0.0)
	# Releasing the 0.6 request when 0.3 is still active doesn't change
	# the effective scale (0.3 is still the most-restrictive).
	_scale_changes.clear()
	_director.release("slow_a")
	assert_almost_eq(_director.current_scale(), 0.3, 0.001,
		"releasing non-effective request leaves scale unchanged")
	assert_eq(_scale_changes.size(), 0,
		"scale_changed should NOT fire (no-op write avoided)")


# ---- AC4: priority dominates scale --------------------------------------

func test_higher_priority_wins_over_lower_priority_lower_scale() -> void:
	# Phase-transition (priority 1, scale 0.3) trumps hit-pause (priority 0, scale 0.0).
	# This is the canonical T2-vs-T3 conflict Priya's AC names explicitly.
	_director.request("hit_pause", 0.05, 0.0, 0)  # priority 0, near-freeze
	_director.request("phase_transition", 0.3, 0.0, 1)  # priority 1, narrative beat
	assert_almost_eq(_director.current_scale(), 0.3, 0.001,
		"priority 1 (phase_transition @ 0.3) trumps priority 0 (hit_pause @ 0.05)")


func test_freeze_priority_trumps_all_lower() -> void:
	_director.request("narrative", 0.3, 0.0, 1)
	_director.freeze(0.0, "final_hit")  # priority 2 default
	assert_almost_eq(_director.current_scale(), 0.0, 0.001,
		"freeze (priority 2) trumps narrative (priority 1)")


func test_top_priority_bucket_picks_lowest_scale_among_peers() -> void:
	_director.request("a", 0.3, 0.0, 1)
	_director.request("b", 0.5, 0.0, 1)
	_director.request("c", 0.8, 0.0, 0)  # lower priority, ignored
	assert_almost_eq(_director.current_scale(), 0.3, 0.001,
		"within top priority bucket, lowest scale (0.3) wins")


# ---- AC5: auto-release via real-time SceneTreeTimer --------------------

func test_auto_release_after_duration_expires() -> void:
	# Use a short duration so the test is fast. The director's timer uses
	# `process_always = true` so it ticks in REAL seconds regardless of
	# Engine.time_scale — critical because freeze() at 0.0 would otherwise
	# never tick out.
	_director.request("short", 0.4, 0.05)  # 50 ms

	# Wait beyond the duration via real-time await on the SceneTree.
	await get_tree().create_timer(0.15, true, false, true).timeout

	assert_false(_director.is_active("short"),
		"request auto-released after duration expired")
	assert_almost_eq(_director.current_scale(), 1.0, 0.001,
		"Engine.time_scale restored after auto-release")


func test_freeze_auto_release_works_despite_scale_0() -> void:
	# The bug-class this guards: a SceneTreeTimer scheduled with default
	# `process_always = false` would never tick out under a 0.0 freeze.
	# The director uses real-time timers (process_always = true) so the
	# freeze's own auto-release works.
	_director.freeze(0.05)
	assert_almost_eq(_director.current_scale(), 0.0, 0.001, "freeze active")

	await get_tree().create_timer(0.15, true, false, true).timeout

	assert_false(_director.is_active("freeze"),
		"freeze auto-released despite scale=0.0 during the window")
	assert_almost_eq(_director.current_scale(), 1.0, 0.001,
		"Engine.time_scale restored after freeze auto-release")


# ---- AC6: re-request semantics — replace prior, cancel stale timer -----

func test_rerequest_same_reason_replaces_scale_and_priority() -> void:
	_director.request("slow", 0.5, 0.0, 0)
	assert_almost_eq(_director.current_scale(), 0.5, 0.001)
	# Re-request with different scale + priority.
	_director.request("slow", 0.3, 0.0, 1)
	assert_almost_eq(_director.current_scale(), 0.3, 0.001,
		"re-request replaces prior; new scale takes effect")
	assert_eq(_director.active_reasons().size(), 1,
		"single active entry — no stacking on re-request")


func test_rerequest_cancels_prior_auto_release_timer() -> void:
	# AC: a re-request must NOT have its OLD timer fire later and
	# erroneously release the NEW entry. This is the generation-token
	# guard inside the director.
	_director.request("renew", 0.5, 0.05)  # short timer
	# Immediately re-request with a longer (effectively indefinite) duration.
	_director.request("renew", 0.4, 0.0)

	# Wait past the ORIGINAL timer's duration.
	await get_tree().create_timer(0.15, true, false, true).timeout

	# The new entry must still be live — the stale timer no-op'd.
	assert_true(_director.is_active("renew"),
		"re-requested entry survives the old timer's fire")
	assert_almost_eq(_director.current_scale(), 0.4, 0.001,
		"effective scale reflects the NEW request")

	_director.release("renew")  # cleanup


# ---- AC7: reset() clears everything ------------------------------------

func test_reset_clears_all_requests_and_restores_1_0() -> void:
	_director.request("a", 0.3, 0.0)
	_director.request("b", 0.5, 0.0, 1)
	_director.freeze(0.0, "c")
	assert_eq(_director.active_reasons().size(), 3)

	_director.reset()
	assert_eq(_director.active_reasons().size(), 0,
		"reset clears the stack")
	assert_almost_eq(_director.current_scale(), 1.0, 0.001,
		"reset restores 1.0")


# ---- AC8: freeze() sugar -----------------------------------------------

func test_freeze_sets_0_with_priority_2_default() -> void:
	_director.freeze(0.0)  # default reason "freeze"
	assert_almost_eq(_director.current_scale(), 0.0, 0.001,
		"freeze() sets scale to 0.0")
	assert_true(_director.is_active("freeze"),
		"default reason is 'freeze'")

	# Verify priority by stacking a lower-priority request and confirming
	# freeze still wins.
	_director.request("slow", 0.3, 0.0, 1)
	assert_almost_eq(_director.current_scale(), 0.0, 0.001,
		"freeze (priority 2) still wins against narrative (priority 1)")


func test_freeze_custom_reason_allows_coexistence() -> void:
	_director.freeze(0.0, "boss_died_freeze")
	_director.freeze(0.0, "modal_freeze")
	assert_eq(_director.active_reasons().size(), 2,
		"two distinct freeze reasons can coexist")
	# Releasing one leaves the other active.
	_director.release("boss_died_freeze")
	assert_almost_eq(_director.current_scale(), 0.0, 0.001,
		"remaining freeze still pins scale at 0.0")


# ---- AC9: WarningBus routing on misuse ---------------------------------

func test_empty_reason_request_emits_warning_and_does_nothing() -> void:
	_warn_guard.expect_warning("empty reason")
	_director.request("", 0.3, 0.0)
	assert_eq(_director.active_reasons().size(), 0,
		"empty reason rejected — no entry added")
	assert_almost_eq(_director.current_scale(), 1.0, 0.001,
		"scale unchanged")


func test_empty_reason_freeze_emits_warning_and_does_nothing() -> void:
	_warn_guard.expect_warning("empty reason")
	_director.freeze(0.0, "")
	assert_eq(_director.active_reasons().size(), 0,
		"empty reason rejected — no entry added")
	assert_almost_eq(_director.current_scale(), 1.0, 0.001,
		"scale unchanged")


func test_scale_below_min_clamps_and_warns() -> void:
	# request() at scale 0.0 is a misuse — true freezes go through freeze().
	# The director clamps to MIN_NON_FREEZE_SCALE (0.01) and emits a warning.
	_warn_guard.expect_warning("clamped")
	_director.request("near_zero", 0.0, 0.0)
	# Effective scale is the clamped MIN_NON_FREEZE_SCALE.
	assert_almost_eq(_director.current_scale(), 0.01, 0.001,
		"scale 0.0 clamped to 0.01 (use freeze() for true 0.0)")
	_director.release("near_zero")


func test_scale_above_max_clamps_and_warns() -> void:
	_warn_guard.expect_warning("clamped")
	_director.request("over_one", 2.0, 0.0)
	assert_almost_eq(_director.current_scale(), 1.0, 0.001,
		"scale > 1.0 clamped to 1.0")
	_director.release("over_one")


# ---- AC10: signal emission shape ---------------------------------------

func test_scale_changed_fires_only_on_actual_change() -> void:
	# Initial state scale=1.0; recompute_and_apply must NOT emit
	# scale_changed when the new value equals the current value.
	_scale_changes.clear()
	_director.request("slow", 0.5, 0.0)
	assert_eq(_scale_changes.size(), 1, "fires once on add")
	assert_almost_eq(_scale_changes[0], 0.5, 0.001, "payload is 0.5")

	# Adding a request with HIGHER scale (less restrictive) → no scale change.
	_scale_changes.clear()
	_director.request("slower_b", 0.6, 0.0)  # 0.6 > 0.5 → 0.5 still wins
	assert_eq(_scale_changes.size(), 0,
		"no-op scale write does not fire scale_changed")

	_director.release("slow")
	_director.release("slower_b")


func test_request_changed_payload_uses_documented_op_strings() -> void:
	_request_changes.clear()
	_director.request("x", 0.5, 0.0)
	_director.request("x", 0.3, 0.0)  # replace
	_director.release("x")
	assert_eq(_request_changes.size(), 3, "three events fired")
	assert_eq(_request_changes[0]["op"], "added")
	assert_eq(_request_changes[1]["op"], "replaced")
	assert_eq(_request_changes[2]["op"], "released")


func test_request_changed_expired_op_fires_on_auto_release() -> void:
	_request_changes.clear()
	_director.request("transient", 0.5, 0.05)
	await get_tree().create_timer(0.15, true, false, true).timeout

	# Find the "expired" event (there may be other "added" events in between).
	var saw_expired: bool = false
	for ev in _request_changes:
		if ev["reason"] == "transient" and ev["op"] == "expired":
			saw_expired = true
			break
	assert_true(saw_expired, "auto-release emits request_changed(op='expired')")


# ---- AC11: integration sanity — T2/T3 conflict scenario ----------------

func test_t2_t3_conflict_phase_transition_wins_over_hit_pause() -> void:
	# Concrete instance of Priya's documented contract from T3 AC:
	# "Hit-pause (T2) is suppressed during phase-transition window
	# (T11 stack resolution: phase-transition request wins over
	# hit-pause request)."
	#
	# This test pins the contract structurally — if a future refactor
	# inverts priority resolution, this fails loud + describes the
	# product-level intent it broke.
	_director.request("phase_transition_2", 0.3, 0.6,
		_director.PRIORITY_NARRATIVE)
	# Mid-phase-transition, a hit lands and asks for a hit-pause.
	_director.request("hit_pause", 0.05, 0.06,
		_director.PRIORITY_DEFAULT)
	# The hit-pause is INVISIBLE while phase-transition is active.
	assert_almost_eq(_director.current_scale(), 0.3, 0.001,
		"hit_pause suppressed by active phase_transition (priority dominance)")
	# Release phase-transition; hit-pause becomes effective.
	_director.release("phase_transition_2")
	assert_almost_eq(_director.current_scale(), 0.05, 0.001,
		"after phase_transition releases, hit_pause is now the top of stack")
	_director.release("hit_pause")


# ---- AC12: generation-token identity (PR #285 Tess CHANGES_REQUESTED) ----
#
# These tests pin the bug *class* that motivated the gen-token fix:
# value-equality on the generation token would let a stale auto-release
# timer treat itself as live + erase the freshly-refreshed entry.
#
# `test_rerequest_cancels_prior_auto_release_timer` (AC6) only exercises
# the value-DISTINCT case (0.5 → 0.4); these probes pin the value-EQUAL
# boundary explicitly. Per Tess: these tests MUST fail against the prior
# `live != generation` Dict-comparison guard and PASS against the
# monotonic-int gen-counter fix.

func test_rerequest_with_identical_scale_priority_does_not_self_erase() -> void:
	# Re-request with IDENTICAL scale/priority/duration>0 to exercise the
	# generation-token's value-vs-reference equality boundary. Under the
	# prior Dict-comparison guard, the OLD entry and NEW entry would be
	# value-equal Dicts (same scale, same priority, same {extra-field}),
	# so the stale OLD timer's fire would compute `live != generation` as
	# false → erase the LIVE entry. Fix: monotonic int gen counter — each
	# schedule call gets a unique int, stale-vs-live always distinguishable.
	_director.request("renew_same", 0.5, 0.05, 0)  # OLD: scale=0.5 prio=0
	_director.request("renew_same", 0.5, 0.2, 0)   # NEW: same shape, longer timer
	# Wait past the OLD timer's duration but BEFORE the new one expires.
	await get_tree().create_timer(0.12, true, false, true).timeout
	assert_true(_director.is_active("renew_same"),
		"same-content re-request must survive stale OLD timer firing")
	assert_almost_eq(_director.current_scale(), 0.5, 0.001,
		"scale still pinned at 0.5; live entry was NOT erroneously erased")
	_director.release("renew_same")


func test_freeze_self_extension_via_rerequest_does_not_self_erase() -> void:
	# Docstring contract (TimeScaleDirector.gd line 95-96):
	# "A long-duration 'freeze' that needs extension can re-request itself."
	#
	# This must hold even when the extension uses identical
	# reason/priority — both freeze entries are {scale=0.0, priority=2},
	# i.e. value-equal Dicts. Pre-fix, the OLD timer's fire would erase
	# the extended freeze. Post-fix (monotonic gen counter), the stale
	# OLD timer's bound `gen` is strictly less than the LIVE entry's
	# `gen`, so the stale fire no-ops cleanly.
	_director.freeze(0.05, "extending_freeze")
	_director.freeze(0.2, "extending_freeze")  # extend
	await get_tree().create_timer(0.12, true, false, true).timeout
	assert_true(_director.is_active("extending_freeze"),
		"extended freeze must survive the original timer's stale fire")
	assert_almost_eq(_director.current_scale(), 0.0, 0.001,
		"freeze still active after extension")
	_director.release("extending_freeze")


# ---- AC13: NaN / Inf adversarial-probe rejection -----------------------
#
# Non-blocking Tess finding from PR #285 review: `request("x", NAN, ...)`
# pre-fix would pass `clampf(NaN, ...)` → NaN, store entry with NaN
# scale → write `Engine.time_scale = NaN` → catastrophic downstream.
# Fix: explicit is_nan / is_inf reject + WarningBus warn. Cheap to add
# while touching request().

func test_nan_scale_is_rejected_with_warning() -> void:
	_warn_guard.expect_warning("non-finite scale")
	_director.request("nan_probe", NAN, 0.0)
	assert_eq(_director.active_reasons().size(), 0,
		"NaN scale rejected — no entry added")
	assert_almost_eq(_director.current_scale(), 1.0, 0.001,
		"Engine.time_scale untouched")
	# Belt: the engine itself must not have been polluted with NaN.
	assert_false(is_nan(Engine.time_scale),
		"Engine.time_scale is NOT NaN")


func test_positive_inf_scale_is_rejected_with_warning() -> void:
	_warn_guard.expect_warning("non-finite scale")
	_director.request("inf_probe", INF, 0.0)
	assert_eq(_director.active_reasons().size(), 0,
		"+Inf scale rejected — no entry added")
	assert_almost_eq(_director.current_scale(), 1.0, 0.001,
		"Engine.time_scale untouched")


func test_negative_inf_scale_is_rejected_with_warning() -> void:
	_warn_guard.expect_warning("non-finite scale")
	_director.request("neg_inf_probe", -INF, 0.0)
	assert_eq(_director.active_reasons().size(), 0,
		"-Inf scale rejected — no entry added")
	assert_almost_eq(_director.current_scale(), 1.0, 0.001,
		"Engine.time_scale untouched")
