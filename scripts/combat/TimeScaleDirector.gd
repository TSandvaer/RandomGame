extends Node
## TimeScaleDirector autoload — single owner of `Engine.time_scale` mutations
## via a reason-keyed stack with priority + most-restrictive-wins resolution.
##
## **Ticket 86c9wjxxd — M3 Tier 2 Wave 1 T11.**
##
## ## Why this exists
##
## Multiple Tier-2 surfaces want to slow / freeze game time concurrently:
##
##   - **T2 hit-pause** — 60 ms `Engine.time_scale = 0.0` on player-hits-boss
##     (and a 300 ms freeze on boss-died).
##   - **T3 phase-transition slow** — 0.6 s of `Engine.time_scale = 0.3`
##     on each boss phase boundary, then 0.2 s ramp back to 1.0.
##   - **T16 boss-defeated cinematic** — sustained 0.9 s ember-rise window
##     coordinated with the F1 freeze.
##   - **Future inventory pause / level-up time-slow** — InventoryPanel
##     already pokes `Engine.time_scale` directly today (TIME_SLOW_FACTOR
##     = 0.10); migrating that to this director is in scope for a follow-up
##     ticket. See "Migration policy" below.
##
## Without a single owner, these surfaces race: hit-pause restoring during
## a phase-transition slow would slam time-scale back to 1.0 mid-window;
## the InventoryPanel snapshot-and-restore pattern only works because it's
## the sole writer today (and it leaks if a second writer slips in between
## snapshot and restore). The director makes the resolution explicit:
## every writer states its reason + priority + scale + duration, and the
## director computes the effective `Engine.time_scale` from the live stack.
##
## ## API
##
##   request(reason, scale, duration, priority := 0) -> void
##       Push a time-scale request onto the stack. `reason` is a unique
##       key (re-requesting the same reason REPLACES the prior request —
##       idempotent refresh). `scale` in (0.0, 1.0]; values outside the
##       range are clamped and a WarningBus warning is emitted. `duration`
##       in seconds; <= 0 means "no auto-release" (caller must release()).
##       `priority` (default 0) is the tie-breaker; see "Resolution".
##
##   release(reason) -> void
##       Remove the named request from the stack and recompute. Idempotent
##       (releasing a missing reason is silent).
##
##   freeze(duration, reason := "freeze") -> void
##       Sugar for `request(reason, 0.0, duration, priority=2)`. Default
##       reason "freeze" — pass a custom reason if you need multiple
##       concurrent freezes (rare; T2 boss-died-freeze does, T3 does NOT).
##
##   reset() -> void
##       Clear all active requests, restore `Engine.time_scale = 1.0`.
##       For test teardown + the scene-tree-reload safety net.
##
##   current_scale() -> float
##       Returns the live computed scale (mirror of Engine.time_scale; the
##       director is the single writer).
##
##   active_reasons() -> Array[String]
##       Snapshot of the live stack's reason keys; for test introspection.
##
## ## Resolution rule (the contract)
##
## When multiple requests are active simultaneously:
##
##   1. **Highest priority wins.** A request with priority=2 (e.g. `freeze`)
##      beats every request with priority=0 (e.g. `hit_pause`, `phase_slow`),
##      regardless of scale.
##
##   2. **Within a priority bucket, most-restrictive (lowest scale) wins.**
##      Two requests at priority=0 with scales 0.3 and 0.5 → effective
##      scale 0.3.
##
##   3. **Empty stack → scale 1.0.**
##
## ### Why priority + most-restrictive (and not just lowest-scale)
##
## The naive "lowest-scale wins" rule has a conflict that Priya's
## T3 AC calls out explicitly: hit-pause at scale 0.0 would dominate a
## phase-transition at scale 0.3, but the design intent is the OPPOSITE
## — phase-transition is a wider window that should suppress hit-pauses
## inside it (the boss is damage-immune during phase-transition anyway,
## so no hit lands to trigger a hit-pause, but the contract should hold
## structurally). Priority lets callers express "this request is wider
## intent" without forcing every caller to coordinate scales.
##
## ### Recommended priority assignments
##
##   priority 0 — hit-pause, melee/swing pauses, ephemeral combat feels
##   priority 1 — phase-transition, level-up time-slow, narrative beats
##   priority 2 — freeze() (true 0.0 stop; final-hit, modal-pause)
##   priority 3+ — reserved for future modal UI that MUST trump everything
##
## ## Idempotence + lifecycle
##
##   - `request(reason, ...)` called twice with the same `reason` REPLACES
##     the prior request (refreshes scale + duration + priority + timer).
##     A long-duration "freeze" that needs extension can re-request itself.
##   - `release(reason)` after the auto-timer already fired is a silent
##     no-op (the request was already removed).
##   - `release(reason)` for a reason that never requested is a silent
##     no-op (defensive).
##   - Scene-tree reload (death-restart / room transition) does NOT clear
##     the stack automatically. Callers are responsible for `release(reason)`
##     in their `_exit_tree` handler. Future hardening: subscribe to
##     `tree_changed` and auto-release stale requests; not in scope for T11.
##
## ## Migration policy
##
## Existing direct `Engine.time_scale = X` writes remain valid AND
## INVISIBLE to this director. The two known direct writers today:
##
##   - `scripts/ui/InventoryPanel.gd::open()/close()/_exit_tree` —
##     snapshot/restore pattern around 0.10. Migration is in scope for a
##     follow-up; the snapshot-and-restore approach works today because
##     InventoryPanel is the sole non-director writer.
##   - GUT integration tests (`tests/integration/*.gd`) — defensive
##     `Engine.time_scale = 1.0` resets in `before_each`. These are
##     test plumbing; they reset the director by writing past it. Acceptable
##     because tests own their own world reset; production code must not.
##
## Once T11 lands, future writers MUST route through this director —
## adding a new direct `Engine.time_scale = ...` write should be flagged
## in PR review.
##
## ## References
##
##   - ClickUp 86c9wjxxd — this ticket (T11)
##   - `team/priya-pl/m3-tier2-boss-room-polish-scope.md` §3 T11 AC
##   - `team/uma-ux/boss-intro.md` BI-16, BI-17, F1 (T11's downstream consumers)
##   - `scripts/ui/InventoryPanel.gd` — example legacy direct writer
##   - `.claude/docs/time-scale-director.md` (to be created by maintain-docs
##     when this PR lands per Priya's doc-flag)


# ---- Constants -------------------------------------------------------

## Floor for any non-freeze request scale. Scales below this clamp UP to
## this value with a WarningBus warning. Prevents callers from accidentally
## requesting near-zero scales that aren't true freezes (a true 0.0 freeze
## should go through `freeze(...)` so its intent is structural).
const MIN_NON_FREEZE_SCALE: float = 0.01

## Hard ceiling. Engine accepts > 1.0 but Embergrave has no design
## language for time acceleration; clamp + warn.
const MAX_SCALE: float = 1.0

## Default priorities for documented use sites. Callers may pass any int;
## these constants document the recommended values.
const PRIORITY_DEFAULT: int = 0       # hit-pause, swing-pause, ephemeral
const PRIORITY_NARRATIVE: int = 1     # phase-transition, level-up slow
const PRIORITY_FREEZE: int = 2        # freeze(); modal-stop


# ---- Signals ---------------------------------------------------------

## Emitted whenever the effective scale changes. Payload is the new scale.
## Subscribers: HUD pause indicators, debug overlays, integration tests.
signal scale_changed(new_scale: float)

## Emitted whenever a request is added / replaced / removed. Payload is
## the affected reason key and the operation ("added", "replaced",
## "released", "expired"). Subscribers: tests + debug overlay; production
## code rarely needs this.
signal request_changed(reason: String, op: String)


# ---- State -----------------------------------------------------------

## Active requests, keyed by `reason`. Each value is a Dictionary with
## keys `scale: float`, `priority: int`, `timer: SceneTreeTimer` (or null
## for no-auto-release).
##
## Dictionary (not Array) so re-requesting the same reason is structurally
## a replace + the resolution computation reads keys without scanning.
var _requests: Dictionary = {}

## Memoized effective scale (mirrors `Engine.time_scale`; the director is
## the single writer). Stored so signal-emit can compare against the
## previous value without re-reading the engine.
var _current_scale: float = 1.0


# ---- Lifecycle -------------------------------------------------------

func _ready() -> void:
	# Boot-time pin: the director writes 1.0 explicitly so any pre-boot
	# residual scale (e.g. from a test harness that leaked state) is
	# normalized. Single boot-time line so Tess's grep over autoload
	# init logs has a stable token.
	Engine.time_scale = 1.0
	_current_scale = 1.0
	print("[TimeScaleDirector] ready scale=1.0 requests=0")


# ---- Public API ------------------------------------------------------

## Request a time-scale change. See class docstring for semantics.
##
## `reason` MUST be unique to the requester's intent — re-requesting the
## same reason replaces the prior request (idempotent refresh). Use a
## stable string like "hit_pause" or "phase_transition_2"; do NOT use
## ephemeral values like UUIDs unless you intend to leave the stack with
## one entry per call.
##
## `scale` is clamped to [MIN_NON_FREEZE_SCALE, MAX_SCALE]. Values outside
## emit a WarningBus warning so misuse is loud. For a true 0.0 stop, call
## `freeze(...)` instead.
##
## `duration` in seconds. If > 0, auto-release fires via SceneTreeTimer.
## If <= 0, the request persists until `release(reason)` is called. Use
## <= 0 for indeterminate-duration windows (e.g. modal UI open until
## explicit close); use > 0 for everything time-bounded.
##
## `priority` controls multi-request resolution; see class docstring.
func request(reason: String, scale: float, duration: float, priority: int = PRIORITY_DEFAULT) -> void:
	if reason == "":
		_warn("TimeScaleDirector.request: empty reason — refusing", "time_scale_director")
		return

	var clamped_scale: float = clampf(scale, MIN_NON_FREEZE_SCALE, MAX_SCALE)
	if not is_equal_approx(clamped_scale, scale):
		var msg: String = (
			"TimeScaleDirector.request: scale %.3f for reason '%s' clamped to %.3f "
			+ "(range [%.3f, %.3f]; for a true freeze use freeze(...))"
		) % [scale, reason, clamped_scale, MIN_NON_FREEZE_SCALE, MAX_SCALE]
		_warn(msg, "time_scale_director")

	# Cancel any prior timer for this reason — re-request resets the clock.
	var prior_existed: bool = _requests.has(reason)
	if prior_existed:
		_cancel_timer_for(reason)

	var entry: Dictionary = {
		"scale": clamped_scale,
		"priority": priority,
		"timer_active": false,
	}
	_requests[reason] = entry

	if duration > 0.0:
		_schedule_auto_release(reason, duration)

	request_changed.emit(reason, "replaced" if prior_existed else "added")
	_recompute_and_apply()


## Bypasses the non-freeze scale floor + uses PRIORITY_FREEZE by default,
## so a 0.0 stop trumps every ordinary request. `reason` defaults to
## "freeze" — pass a unique reason when two freezes need to coexist
## (e.g. boss-died-freeze stacking on a modal freeze; rare).
func freeze(duration: float, reason: String = "freeze") -> void:
	if reason == "":
		_warn("TimeScaleDirector.freeze: empty reason — refusing", "time_scale_director")
		return

	# Cancel any prior timer for this reason.
	var prior_existed: bool = _requests.has(reason)
	if prior_existed:
		_cancel_timer_for(reason)

	var entry: Dictionary = {
		"scale": 0.0,
		"priority": PRIORITY_FREEZE,
		"timer_active": false,
	}
	_requests[reason] = entry

	if duration > 0.0:
		_schedule_auto_release(reason, duration)

	request_changed.emit(reason, "replaced" if prior_existed else "added")
	_recompute_and_apply()


## Remove a request from the stack. Idempotent — releasing a missing
## reason is a silent no-op. Cancels the auto-release timer if one was
## still pending.
func release(reason: String) -> void:
	if not _requests.has(reason):
		return
	_cancel_timer_for(reason)
	_requests.erase(reason)
	request_changed.emit(reason, "released")
	_recompute_and_apply()


## Test/scene-reload safety: clear every active request, restore 1.0.
## Production code should NOT call this — it side-steps the per-reason
## release contract and may strand a legitimate concurrent slow-mo.
## Reserved for GUT before_each/after_each + the scene-tree-reload safety
## net.
func reset() -> void:
	# Cancel any in-flight timers before clearing so they can't fire late
	# and re-release a reason that no longer exists.
	for r in _requests.keys():
		_cancel_timer_for(String(r))
	_requests.clear()
	_recompute_and_apply()


## Live effective scale (== Engine.time_scale; the director is the
## single writer). For test introspection + HUD overlays.
func current_scale() -> float:
	return _current_scale


## Snapshot of the live stack's reason keys. For test introspection.
## Returned in arbitrary (Dictionary key) order; tests should not depend
## on ordering.
func active_reasons() -> Array:
	return _requests.keys()


## Returns true if any request with the given reason is currently active.
## Useful for callers wanting to coordinate without computing the full
## scale (e.g. "is a freeze active?" → `is_active("freeze")`).
func is_active(reason: String) -> bool:
	return _requests.has(reason)


# ---- Internals --------------------------------------------------------

## Compute the effective scale from the live stack + apply to engine.
## Emits `scale_changed` only when the value actually changes (within
## float-equality tolerance) so subscribers don't churn on no-op writes.
func _recompute_and_apply() -> void:
	var effective: float = _compute_effective_scale()
	if is_equal_approx(effective, _current_scale):
		return
	_current_scale = effective
	Engine.time_scale = effective
	scale_changed.emit(effective)


## Resolution: highest priority wins; within priority bucket, lowest
## scale wins; empty stack → 1.0.
func _compute_effective_scale() -> float:
	if _requests.is_empty():
		return 1.0

	var top_priority: int = -2147483648  # int min
	for r in _requests.values():
		var p: int = int(r["priority"])
		if p > top_priority:
			top_priority = p

	var lowest_scale_in_top: float = 1.0
	for r in _requests.values():
		if int(r["priority"]) != top_priority:
			continue
		var s: float = float(r["scale"])
		if s < lowest_scale_in_top:
			lowest_scale_in_top = s

	return lowest_scale_in_top


## Schedule the auto-release SceneTreeTimer for a reason. Marks the entry
## so a subsequent re-request can cancel cleanly. We rely on the timer's
## timeout signal carrying the reason via a bound argument so a re-request
## that already replaced the entry doesn't accidentally release the NEW
## request when the OLD timer fires.
func _schedule_auto_release(reason: String, duration: float) -> void:
	var entry: Dictionary = _requests[reason]
	entry["timer_active"] = true
	# Bind reason + a "generation" token so a stale timer (from a prior
	# request that has since been replaced) can no-op on fire. The token
	# is the current entry Dictionary itself — if the entry has been
	# replaced, the new entry is a DIFFERENT Dictionary instance.
	var generation: Dictionary = entry
	# `process_always = false` so the timer respects time-scale itself.
	# CAREFUL: a timer scheduled while we're frozen at 0.0 would NEVER
	# fire (timer is scaled by engine time). So we explicitly request the
	# REAL-TIME timer behavior via `process_always = true` (timer ticks
	# in real seconds regardless of `Engine.time_scale`).
	var timer: SceneTreeTimer = get_tree().create_timer(duration, true, false, true)
	timer.timeout.connect(_on_auto_release.bind(reason, generation))


## Auto-release handler. Bound with the reason + the entry-Dictionary
## generation token. If the live entry is a DIFFERENT Dictionary (because
## a re-request replaced it), this timer is stale and no-ops.
func _on_auto_release(reason: String, generation: Dictionary) -> void:
	if not _requests.has(reason):
		# Already released manually.
		return
	var live: Dictionary = _requests[reason]
	if live != generation:
		# Stale timer — a re-request replaced the entry; the new entry
		# has its own (or no) timer. Drop this one silently.
		return
	# Live + matching generation — auto-expire.
	_requests.erase(reason)
	request_changed.emit(reason, "expired")
	_recompute_and_apply()


## Cancel any in-flight timer for `reason`. We don't store the timer
## reference directly (SceneTreeTimer doesn't expose a cancel method
## anyway); we rely on the generation-token mismatch in `_on_auto_release`
## to no-op the stale fire. This helper exists for symmetry + future-
## proofing if Godot adds explicit timer cancellation.
func _cancel_timer_for(reason: String) -> void:
	# Currently a no-op (see comment). The generation-token guard in
	# `_on_auto_release` is the actual cancellation mechanism. Kept as a
	# named hook so callers don't need to know the implementation detail.
	pass


## Internal warning helper. Routes through WarningBus when available
## (so NoWarningGuard catches misuse in tests) and falls back to
## push_warning when the autoload isn't booted (e.g. some test contexts).
func _warn(text: String, category: String) -> void:
	var main_loop: MainLoop = Engine.get_main_loop()
	var bus: Node = null
	if main_loop is SceneTree:
		bus = (main_loop as SceneTree).root.get_node_or_null("WarningBus")
	if bus != null and bus.has_method("warn"):
		bus.warn(text, category)
	else:
		push_warning(text)
