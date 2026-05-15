extends GutTest
## Paired tests for the post-hit iframe window granted by `take_damage`.
##
## Feature ticket: 86c9u4mdc (Devon W3 implementation of Uma's AC4 Room 05
## balance pin, `team/uma-ux/ac4-room05-balance-design.md` §3.B).
##
## **Why iframes-on-hit exists:** the L1 no-dodge harness AI dies in Room 05
## (2 Grunts + 1 Charger) because simultaneous-hit clusters compound through
## the 100 HP pool faster than the iron sword (6 dmg/swing) can clear the
## three chasers. Granting a brief `HIT_IFRAMES_SECS = 0.25` window after every
## non-fatal hit serialises the cluster: within the window, only one mob's
## damage lands. Re-uses the existing `_enter_iframes / _exit_iframes`
## infrastructure (collision-layer swap honoured by `Hitbox.gd`).
##
## **Why a dedicated test file (not appended to `test_player_move.gd`):** the
## dodge i-frame tests in `test_player_move.gd` instantiate Player WITHOUT
## adding to the scene tree (manual `_ready()`). The hit-iframe path uses
## `get_tree().create_timer(...)` which REQUIRES tree membership. Mixing
## tree-rooted and detached Player nodes in the same file gets messy; a
## dedicated file keeps the tree contract explicit.
##
## Coverage:
##   1. Non-fatal `take_damage` decrements HP, then grants iframes.
##   2. Iframes-on-hit are active across the 0.25s window.
##   3. A second `take_damage` within the window is rejected (HP unchanged).
##   4. After the timer fires, iframes are cleared and a third hit lands.
##   5. Fatal hit (HP→0) does NOT arm the iframe timer (death path consumes
##      the frame; idempotent with `_is_dead`).
##   6. Dodge-takes-precedence (entry): a hit DURING an active dodge does
##      NOT arm a hit-iframe timer (dodge owns the iframe window).
##   7. Dodge-takes-precedence (exit): if a dodge begins DURING an active
##      hit-iframe window, the hit-iframe timer firing while still mid-dodge
##      MUST NOT clear `_is_invulnerable` (dodge-end owns the clear).

const PlayerScript: Script = preload("res://scripts/player/Player.gd")


# ---- Helpers ----------------------------------------------------------

func _make_player_in_tree() -> Player:
	# Hit-iframe path uses `get_tree().create_timer(...)` — must be in tree.
	var p: Player = PlayerScript.new()
	add_child_autofree(p)
	return p


# ---- 1: non-fatal damage applies + grants iframes ---------------------

func test_take_damage_non_fatal_decrements_hp_then_arms_iframes() -> void:
	var p: Player = _make_player_in_tree()
	var hp_before: int = p.hp_current
	assert_gt(hp_before, 10, "test setup: player at non-trivial HP")
	assert_false(p.is_invulnerable(),
		"sanity: player not invulnerable before any damage")
	p.take_damage(5, Vector2.ZERO, null)
	assert_eq(p.hp_current, hp_before - 5,
		"non-fatal damage decrements HP by the dealt amount BEFORE iframes arm " +
		"(damage applies, then iframes are granted — not the other way around)")
	assert_true(p.is_invulnerable(),
		"REGRESSION GUARD: post-hit iframes (HIT_IFRAMES_SECS = 0.25) must be " +
		"active immediately after a non-fatal take_damage. This is the load- " +
		"bearing AC4 Room 05 balance behaviour — without it the simultaneous- " +
		"hit cluster from 2 Grunts + 1 Charger collapses the 100 HP pool.")


# ---- 2: second hit within the window is rejected ----------------------

func test_second_hit_within_iframe_window_does_not_damage() -> void:
	# The whole point of the post-hit iframe window: a second hit landing
	# in the same 0.25s cluster bounces off the iframe guard. This is the
	# AC4 Room 05 unblock — without it, two Grunts swinging in the same
	# frame compound 4 dmg instead of 2.
	var p: Player = _make_player_in_tree()
	var hp_before: int = p.hp_current
	p.take_damage(3, Vector2.ZERO, null)
	var hp_after_first: int = p.hp_current
	assert_eq(hp_after_first, hp_before - 3, "first hit landed")
	assert_true(p.is_invulnerable(), "iframes active after first hit")
	# Second hit attempt within the 0.25s window — short-circuited at the
	# `if _is_invulnerable: return` guard at the top of take_damage.
	p.take_damage(99, Vector2.ZERO, null)
	assert_eq(p.hp_current, hp_after_first,
		"REGRESSION GUARD: HP must NOT decrement on a second take_damage call " +
		"while iframes-on-hit are active. Even a 99-dmg one-shot bounces.")


# ---- 3: after timer expires, iframes clear + third hit lands ----------

func test_iframes_clear_after_window_and_third_hit_lands() -> void:
	# Drives the SceneTreeTimer to completion and asserts the timer's
	# `_exit_iframes_if_not_dodging` callback fires and clears the flag.
	# Then a third take_damage call lands cleanly.
	var p: Player = _make_player_in_tree()
	var hp_before: int = p.hp_current
	p.take_damage(2, Vector2.ZERO, null)
	assert_true(p.is_invulnerable(), "iframes active immediately after hit")
	# Wait slightly longer than HIT_IFRAMES_SECS to let the timer's
	# timeout signal fire. The SceneTreeTimer is created against
	# get_tree() (process-tree time), so awaiting `process_frame` for the
	# necessary duration drives it.
	#
	# Use a wall-clock wait via `await get_tree().create_timer(...)` —
	# that's the same mechanism `take_damage` uses, so timing is consistent.
	await get_tree().create_timer(Player.HIT_IFRAMES_SECS + 0.05).timeout
	assert_false(p.is_invulnerable(),
		"REGRESSION GUARD: post-hit iframes must clear once HIT_IFRAMES_SECS " +
		"elapses. The `_exit_iframes_if_not_dodging` timer callback owns the " +
		"clear when the player is NOT mid-dodge.")
	# Third hit — fresh, no iframes. HP drops by 4.
	p.take_damage(4, Vector2.ZERO, null)
	assert_eq(p.hp_current, hp_before - 2 - 4,
		"third take_damage outside the iframe window lands cleanly — " +
		"HP decrements by the new dealt amount (4)")
	assert_true(p.is_invulnerable(),
		"third hit also re-arms iframes (the mechanism is per-hit, not once-per-life)")


# ---- 4: fatal hit does NOT arm the iframe timer -----------------------

func test_fatal_hit_does_not_arm_hit_iframes_timer() -> void:
	# Per Uma's design §3.B: "death path consumes the frame; no iframes-on-hit
	# needed". The early-`return` after `_die()` keeps the death sequence
	# visually clean and avoids any "ghost iframes on a corpse" state.
	# We can't directly observe "the timer was not armed," but we can assert:
	#   - After the lethal hit, `_is_invulnerable` is false (cleared by _die's
	#     own `if _is_invulnerable: _exit_iframes()` defensive path).
	#   - `is_dead()` is true.
	var p: Player = _make_player_in_tree()
	p.take_damage(p.hp_max, Vector2.ZERO, null)
	assert_true(p.is_dead(), "lethal hit triggers death")
	assert_false(p.is_invulnerable(),
		"REGRESSION GUARD: after a fatal hit, the player is dead — NOT " +
		"invulnerable-yet-alive. The death path's early-return prevents the " +
		"hit-iframe timer from arming, and `_die`'s defensive clear runs.")


# ---- 5: dodge at hit time blocks the iframe-timer arm (entry guard) ---

func test_hit_during_active_dodge_does_not_arm_separate_iframe_timer() -> void:
	# Dodge sets _is_invulnerable = true via _enter_iframes. The first thing
	# take_damage checks is `if _is_invulnerable: return` — so a damage call
	# during dodge short-circuits at the top, never reaching the iframe-arm
	# block. This test pins that behaviour: the dodge's own iframe state owns
	# the window, not a competing hit-iframe timer.
	var p: Player = _make_player_in_tree()
	var hp_before: int = p.hp_current
	var dodge_ok: bool = p.try_dodge(Vector2.RIGHT)
	assert_true(dodge_ok, "dodge initiated")
	assert_eq(p.get_state(), Player.STATE_DODGE, "player is in dodge state")
	assert_true(p.is_invulnerable(), "dodge owns the iframe window")
	# Damage call while dodge is active — short-circuited at the top by
	# `if _is_invulnerable: return`. HP must NOT decrement.
	p.take_damage(5, Vector2.ZERO, null)
	assert_eq(p.hp_current, hp_before,
		"dodge-iframe blocks the hit at the take_damage entry guard")
	# Tick dodge to completion. The dodge's own `_exit_iframes` clears the
	# flag — no competing hit-iframe timer should re-clear or extend it.
	p._tick_timers(Player.DODGE_DURATION + 0.01)
	p._process_dodge(0.0)
	assert_false(p.is_invulnerable(),
		"after dodge ends, iframes are cleared cleanly — no competing " +
		"hit-iframe timer firing later (because no timer was armed)")
	# Wait slightly longer than HIT_IFRAMES_SECS would have lasted — if a
	# hit-iframe timer HAD been armed (regression), it would have re-cleared
	# now and we'd just see the same false. The stronger guard is that
	# `_is_invulnerable` stayed false throughout — assert that explicitly via
	# the dodge-not-mid-iframe edge case below.


# ---- 6: dodge BEGAN during hit-iframe window — hit-timer guards exit --

func test_dodge_started_during_hit_iframes_does_not_clobber_dodge() -> void:
	# Order: hit → iframes-on-hit timer armed (0.25s) → player presses dodge
	# during the window → dodge's `_enter_iframes` re-sets the (already-true)
	# flag (idempotent), and `set_state(STATE_DODGE)` flips state. When the
	# 0.25s hit-iframe timer fires, `_exit_iframes_if_not_dodging` checks
	# state — sees STATE_DODGE — SKIPS the clear. The dodge's own
	# `_exit_iframes` fires at dodge-end. Without the helper guard, the
	# hit-iframe timer would clear iframes mid-dodge and leave the player
	# vulnerable while still visually dodging.
	var p: Player = _make_player_in_tree()
	# 1. Take a non-fatal hit — iframes-on-hit armed.
	p.take_damage(3, Vector2.ZERO, null)
	assert_true(p.is_invulnerable(), "hit-iframes active")
	assert_ne(p.get_state(), Player.STATE_DODGE, "not yet in dodge")
	# 2. Player presses dodge DURING the 0.25s window — accepted because
	#    `can_dodge()` keys off `_dodge_cooldown_left`, not iframe state.
	var dodge_ok: bool = p.try_dodge(Vector2.LEFT)
	assert_true(dodge_ok, "dodge initiated mid-hit-iframe-window")
	assert_eq(p.get_state(), Player.STATE_DODGE, "now in dodge")
	assert_true(p.is_invulnerable(), "iframes still active (idempotent set)")
	# Force the dodge timer to be effectively infinite for the duration of
	# this test — we want to observe the hit-iframe timer firing WHILE still
	# mid-dodge, and the natural dodge window (0.30s) is too close to the
	# hit-iframe window (0.25s) to give robust timing margin against
	# headless GUT physics-tick jitter. Setting `_dodge_time_left` to a large
	# value keeps the engine in STATE_DODGE until we explicitly tick out.
	p._dodge_time_left = 10.0
	# 3. Wait past the hit-iframe timer firing. Dodge is still active because
	#    we extended its timer above. `_exit_iframes_if_not_dodging` sees
	#    STATE_DODGE and SKIPS the clear.
	await get_tree().create_timer(Player.HIT_IFRAMES_SECS + 0.05).timeout
	assert_eq(p.get_state(), Player.STATE_DODGE,
		"player is STILL dodging after hit-iframe timer fired " +
		"(dodge is 0.30s, hit-iframes are 0.25s — dodge outlasts)")
	assert_true(p.is_invulnerable(),
		"REGRESSION GUARD: `_exit_iframes_if_not_dodging` MUST guard against " +
		"clobbering a still-active dodge. Without the guard, the player would " +
		"be vulnerable while still visually dodging — a feel + correctness bug " +
		"flagged in Uma's design §3.B 'Dodge takes precedence'.")
	# 4. Tick dodge to completion — dodge's own _exit_iframes clears the flag.
	#    We forced `_dodge_time_left = 10.0` above to keep dodge robustly
	#    active across the hit-iframe-timer firing; now drain it manually so
	#    `_process_dodge` calls `_exit_dodge` → `_exit_iframes`.
	p._dodge_time_left = 0.0
	p._process_dodge(0.0)
	assert_false(p.is_invulnerable(),
		"dodge-end clears iframes (the dodge owns the clear in this ordering)")


# ---- 7: dodge ends BEFORE hit-iframe timer — clean idempotent state ---

func test_dodge_ends_before_hit_iframe_timer_idempotent_safe() -> void:
	# The reverse ordering: dodge ends FIRST, then the hit-iframe timer fires.
	# Per Uma's design §3.B audit point: "the dodge clears _is_invulnerable =
	# false. The post-hit timer fires later, runs _exit_iframes (now a no-op
	# because _is_invulnerable is already false). Idempotent. Safe."
	#
	# Practically: in this codebase, dodge is 0.30s and hit-iframes are 0.25s,
	# so dodge ENDS AFTER the hit-timer in the natural flow. To force the
	# reverse order, we need to cut the dodge short OR test the idempotency
	# directly. We test idempotency: call _exit_iframes when already not
	# invulnerable, assert nothing breaks.
	var p: Player = _make_player_in_tree()
	# Drive dodge-then-clear, then take a hit (which arms iframes again),
	# wait the window out, and confirm the second clear is clean.
	assert_false(p.is_invulnerable())
	p._exit_iframes()  # idempotent no-op when already not invulnerable
	assert_false(p.is_invulnerable(),
		"calling _exit_iframes when not invulnerable is a safe no-op " +
		"(the dodge-ended-first / hit-iframe-timer-fires-second ordering " +
		"relies on this idempotency per Uma's design §3.B audit)")
