extends GutTest
## Paired tests for the `dodge_started` / `iframes_started` signal split.
##
## Ticket 86c9vbhf1 — Tess flagged on PR #278 that dodge-whoosh fired on
## every `iframes_started` emit, but Player emits `iframes_started` from
## BOTH `try_dodge()` (intentional dodge — i-frame window opens) AND
## `take_damage()` (post-hit invuln grant — Uma's AC4 Room 05 balance pin
## §3.B). Per `team/uma-ux/audio-direction.md §AD-05` the dodge-whoosh
## plays ONLY on intentional dodge.
##
## **Fix shape (this PR):** new `dodge_started` signal fires ONLY from
## `try_dodge()` after `can_dodge()` validation passes. `iframes_started`
## keeps emitting from BOTH paths (HUD blink, Hitbox damage-table drop,
## existing tests rely on it — backward-compat preserved).
##
## **Contract this file pins:**
##   1. `try_dodge()` valid → emits BOTH `dodge_started` AND `iframes_started`.
##   2. `try_dodge()` rejected (cooldown / mid-dodge) → emits NEITHER.
##   3. `take_damage()` non-fatal → emits ONLY `iframes_started`, NEVER
##      `dodge_started`.
##   4. `take_damage()` fatal (HP→0) → emits NEITHER (death path consumes
##      the frame).
##   5. `dodge_started` fires BEFORE the i-frame window opens (audio cue
##      lands at the same instant as iframe activation, per AD-05).
##
## Companion to `tests/test_m3w7_audio_cues.gd` which pins the audio-handler
## routing (dodge_started → SFX_PLAYER_DODGE; bare iframes_started silent).
## This file pins the engine-side signal-split contract that the audio
## routing depends on.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")
const PlayerScript: Script = preload("res://scripts/player/Player.gd")

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- Helpers ----------------------------------------------------------


## The hit-iframe `_enter_iframes` path uses `get_tree().create_timer(...)`
## which requires tree membership. Use this for take_damage tests; the
## detached-instance pattern from test_player_move.gd is fine for pure
## try_dodge tests but standardising on tree-rooted keeps assertions clean
## across this file.
func _make_player_in_tree() -> Player:
	var p: Player = PlayerScript.new()
	add_child_autofree(p)
	return p


# ---- 1: try_dodge valid → BOTH signals emit ---------------------------


func test_try_dodge_valid_emits_both_dodge_started_and_iframes_started() -> void:
	var p: Player = _make_player_in_tree()
	watch_signals(p)
	var ok: bool = p.try_dodge(Vector2.RIGHT)
	assert_true(ok, "dodge accepted (no cooldown, not mid-dodge)")
	assert_signal_emit_count(
		p, "dodge_started", 1, "valid try_dodge emits dodge_started exactly once"
	)
	assert_signal_emit_count(
		p,
		"iframes_started",
		1,
		(
			"valid try_dodge ALSO emits iframes_started (backward-compat — "
			+ "HUD blink, Hitbox damage-table drop, AC4 balance test still "
			+ "depend on it)"
		)
	)


# ---- 2: try_dodge rejected → NEITHER signal emits ---------------------


func test_try_dodge_rejected_during_active_dodge_emits_no_signals() -> void:
	# can_dodge() returns false when already in STATE_DODGE → try_dodge
	# bails BEFORE either signal emits. The first dodge consumed one emit
	# each; the second (rejected) call must add zero to that count.
	var p: Player = _make_player_in_tree()
	assert_true(p.try_dodge(Vector2.RIGHT), "first dodge accepted")
	watch_signals(p)  # start watching AFTER the first emit
	var ok: bool = p.try_dodge(Vector2.LEFT)
	assert_false(ok, "second dodge during active dodge rejected")
	assert_signal_emit_count(
		p, "dodge_started", 0, "rejected try_dodge does NOT emit dodge_started (gating beats emit)"
	)
	assert_signal_emit_count(
		p, "iframes_started", 0, "rejected try_dodge does NOT emit iframes_started either"
	)


func test_try_dodge_rejected_during_cooldown_emits_no_signals() -> void:
	# Cooldown is the second gate after STATE_DODGE — drain the dodge,
	# leave cooldown active, then try again.
	var p: Player = _make_player_in_tree()
	assert_true(p.try_dodge(Vector2.RIGHT))
	p._dodge_time_left = 0.0
	p._process_dodge(0.0)  # exits STATE_DODGE; cooldown still active
	assert_false(p.can_dodge(), "cooldown still active after dodge end")
	watch_signals(p)
	var ok: bool = p.try_dodge(Vector2.LEFT)
	assert_false(ok, "dodge during cooldown rejected")
	assert_signal_emit_count(
		p,
		"dodge_started",
		0,
		(
			"REGRESSION GUARD: cooldown-rejected try_dodge does NOT emit "
			+ "dodge_started — `can_dodge()` gate runs BEFORE the emit"
		)
	)
	assert_signal_emit_count(
		p, "iframes_started", 0, "cooldown-rejected try_dodge does NOT emit iframes_started"
	)


# ---- 3: take_damage non-fatal → ONLY iframes_started emits ------------


func test_take_damage_non_fatal_emits_iframes_started_not_dodge_started() -> void:
	# The headline ticket-86c9vbhf1 invariant — taking damage MUST NOT emit
	# dodge_started. Pre-fix this entire signal didn't exist; the audio
	# handler subscribed to iframes_started and fired the whoosh on every
	# damage taken (PR #278 bug). The split-signal contract guarantees:
	# take_damage emits ONLY iframes_started, never dodge_started.
	var p: Player = _make_player_in_tree()
	watch_signals(p)
	p.take_damage(3, Vector2.ZERO, null)
	assert_signal_emit_count(
		p,
		"iframes_started",
		1,
		(
			"non-fatal take_damage emits iframes_started (post-hit invuln grant — "
			+ "Uma's AC4 Room 05 balance pin §3.B, ticket 86c9u4mdc)"
		)
	)
	assert_signal_emit_count(
		p,
		"dodge_started",
		0,
		(
			"HEADLINE REGRESSION GUARD: non-fatal take_damage MUST NOT emit "
			+ "dodge_started — audio-direction.md §AD-05 dodge-whoosh fires ONLY "
			+ "on intentional dodge. Ticket 86c9vbhf1 / PR #278 bug class."
		)
	)


# ---- 4: take_damage fatal → NEITHER signal emits ----------------------


func test_take_damage_fatal_emits_neither_signal() -> void:
	# Fatal hit (HP→0) consumes the frame via _die() before the post-hit
	# iframe grant runs (early return after _die). Neither signal should
	# emit on the lethal path.
	var p: Player = _make_player_in_tree()
	watch_signals(p)
	p.take_damage(p.hp_max, Vector2.ZERO, null)
	assert_true(p.is_dead(), "lethal hit triggered death")
	assert_signal_emit_count(
		p,
		"iframes_started",
		0,
		(
			"fatal take_damage does NOT emit iframes_started — death path's "
			+ "early-return before _enter_iframes"
		)
	)
	assert_signal_emit_count(
		p,
		"dodge_started",
		0,
		"fatal take_damage does NOT emit dodge_started — death path " + "never reaches try_dodge"
	)


# ---- 5: dodge_started fires BEFORE the i-frame window opens -----------


func test_dodge_started_fires_before_invulnerable_flag_set() -> void:
	# The contract per `audio-direction.md §AD-05`: dodge-whoosh lands at
	# "frame 2 of 6 of the dodge animation" — same instant the i-frame
	# window opens. In code: dodge_started.emit() runs BEFORE
	# _enter_iframes() inside try_dodge. Pin the ordering by checking the
	# signal-handler observes is_invulnerable() == false at the moment of
	# emit (i.e. _enter_iframes hasn't flipped the flag yet).
	var p: Player = _make_player_in_tree()
	var observed_invulnerable_at_emit: Array[bool] = [true]  # boxed
	var observer: Callable = func() -> void: observed_invulnerable_at_emit[0] = p.is_invulnerable()
	p.dodge_started.connect(observer)
	assert_false(p.is_invulnerable(), "pre-condition: not invulnerable")
	assert_true(p.try_dodge(Vector2.RIGHT))
	assert_false(
		observed_invulnerable_at_emit[0],
		(
			"dodge_started fires BEFORE _enter_iframes flips is_invulnerable. "
			+ "Audio cue is sequenced FIRST so the whoosh leads the iframe window "
			+ "by ~0 ms (frame-accurate per AD-05)."
		)
	)
	# Post-condition: after try_dodge returns, the iframe window IS active.
	assert_true(p.is_invulnerable(), "post-condition: _enter_iframes ran after dodge_started emit")


# ---- 6: try_dodge emits dodge_started exactly once per dodge ----------


func test_try_dodge_emits_dodge_started_exactly_once_per_dodge() -> void:
	# Symmetric to `test_iframes_signal_count_per_dodge_is_one_each` in
	# test_player_move.gd — pins the one-per-dodge invariant for the new
	# signal. Critical for VFX/audio observers that key off counts.
	var p: Player = _make_player_in_tree()
	watch_signals(p)
	p.try_dodge(Vector2.UP)
	# Drain the dodge end-to-end.
	p._dodge_time_left = 0.0
	p._process_dodge(0.0)
	assert_signal_emit_count(
		p, "dodge_started", 1, "exactly one dodge_started per dodge — never zero, never two"
	)


# ---- 7: re-entrant _enter_iframes during dodge does NOT re-emit ------


func test_take_damage_during_active_dodge_does_not_emit_either_signal() -> void:
	# Subtle edge case: take_damage's `if _is_invulnerable: return` guard
	# short-circuits at the top while dodge is active. No iframes_started
	# emit (the guard returns before _enter_iframes), no dodge_started emit
	# (this isn't a try_dodge call). Pin the contract — if a refactor moves
	# the iframe emit before the guard, this catches it.
	var p: Player = _make_player_in_tree()
	assert_true(p.try_dodge(Vector2.RIGHT), "dodge initiated")
	assert_true(p.is_invulnerable(), "dodge owns the iframe window")
	# Reset signal watcher AFTER the dodge's own emits, so this test only
	# observes the take_damage call.
	watch_signals(p)
	p.take_damage(5, Vector2.ZERO, null)
	assert_signal_emit_count(
		p,
		"iframes_started",
		0,
		"take_damage during active dodge short-circuits before _enter_iframes"
	)
	assert_signal_emit_count(
		p, "dodge_started", 0, "take_damage NEVER emits dodge_started regardless of state"
	)
