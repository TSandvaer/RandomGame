extends GutTest
## Regression pin for the boss-room Player.collision_layer = 0 bug
## (ticket 86c9uq0ky, Sponsor 2026-05-16 soak diag `83267fd`).
##
## **Bug class summary.** `_enter_iframes` saves the current `collision_layer`
## into `_saved_collision_layer`, then clears `collision_layer = 0`. Without
## a re-entry guard, calling `_enter_iframes` twice in a row (e.g. dodge
## while still inside the post-hit iframe window) overwrites the saved
## value with 0. `_exit_iframes` then restores the player to layer=0
## PERMANENTLY — the player CharacterBody2D becomes invisible to all
## Area2D queries whose mask includes the player bit (Pickup mask=2,
## StratumExit mask=2, HealingFountain mask=2).
##
## **Empirical confirmation.** Sponsor's diag-build `83267fd` traced
## `Player.coll_diag | pos=(323,106) layer=0 mask=1 cs_disabled=false
## iframes=false` AFTER boss death and full HP regen. Pickup + StratumExit
## traces showed `mon_actual=true` + `cs_disabled=false` + `monitoring=true`
## + `overlapping_bodies=0` — the area-side was healthy; the player-side
## was at layer=0.
##
## **Fix shape.** Guard re-entry: if already invulnerable, do NOT re-save.
## See `Player.gd::_enter_iframes` doc-comment for the empirical chain.
##
## These tests are the structural canary — if a future refactor removes
## the re-entry guard, this file fails before CI green and the boss-room
## Pickup-collectability bug class re-opens.

const PlayerScript: Script = preload("res://scripts/player/Player.gd")
const EXPECTED_PLAYER_LAYER: int = 1 << (Player.PLAYER_LAYER_BIT - 1)  # bit 2 = value 2


func _make_player_in_tree() -> Player:
	# Hit-iframe path uses `get_tree().create_timer(...)` — must be in tree.
	# Same pattern as `tests/test_player_hit_iframes.gd::_make_player_in_tree`.
	var p: Player = PlayerScript.new()
	add_child_autofree(p)
	return p


# ---- Baseline: layer bit is non-zero at rest --------------------------

func test_player_collision_layer_nonzero_at_rest() -> void:
	# Pre-condition for the whole bug class. Player.gd::_ready seeds the
	# player layer bit if the bare CharacterBody2D defaults dropped to 0.
	var p: Player = _make_player_in_tree()
	assert_eq(p.collision_layer, EXPECTED_PLAYER_LAYER,
		"player must be on the player layer bit at rest (value 2 = bit 2). " +
		"This is the contract Pickup.mask=2 + StratumExit.mask=2 rely on.")
	assert_false(p.is_invulnerable(),
		"sanity: player not invulnerable at rest")


# ---- Single-cycle iframe round-trip restores layer --------------------

func test_single_enter_exit_iframes_round_trip_restores_layer() -> void:
	var p: Player = _make_player_in_tree()
	var layer_before: int = p.collision_layer
	assert_eq(layer_before, EXPECTED_PLAYER_LAYER, "sanity: starting layer is 2")
	p._enter_iframes()
	assert_true(p.is_invulnerable(), "iframes active after _enter_iframes")
	assert_eq(p.collision_layer, 0,
		"iframes clear collision_layer to 0 — enemy hitboxes (mask=2) miss us")
	p._exit_iframes()
	assert_false(p.is_invulnerable(), "iframes cleared after _exit_iframes")
	assert_eq(p.collision_layer, layer_before,
		"single cycle restores the original layer cleanly (existing contract)")


# ---- REGRESSION GUARD: re-entry must not clobber saved layer ----------

func test_reentry_into_iframes_does_not_clobber_saved_layer() -> void:
	# THE CORE PIN. Two back-to-back `_enter_iframes` calls without an
	# intervening `_exit_iframes` MUST NOT overwrite `_saved_collision_layer`
	# with the cleared value (0). The second call must be effectively
	# idempotent w.r.t. the saved restore value.
	var p: Player = _make_player_in_tree()
	assert_eq(p.collision_layer, EXPECTED_PLAYER_LAYER, "sanity: starting layer 2")
	p._enter_iframes()
	# At this point: collision_layer == 0, _saved_collision_layer == 2.
	assert_eq(p.collision_layer, 0, "first enter cleared layer")
	# Re-entry — pre-fix this would have saved layer=0, destroying the
	# restore value.
	p._enter_iframes()
	assert_true(p.is_invulnerable(), "still invulnerable after re-entry")
	assert_eq(p.collision_layer, 0, "still cleared after re-entry (idempotent)")
	# The proof: a single `_exit_iframes` must restore the genuine layer,
	# not 0. Pre-fix this assertion FAILS — restored to 0.
	p._exit_iframes()
	assert_false(p.is_invulnerable(), "iframes cleared after exit")
	assert_eq(p.collision_layer, EXPECTED_PLAYER_LAYER,
		"REGRESSION GUARD (ticket 86c9uq0ky): after re-entry → exit, the player " +
		"MUST be restored to the ORIGINAL layer (2), NOT the cleared value (0). " +
		"If this fails, the boss-room Pickup-collectability bug class has " +
		"re-opened — Pickup.mask=2 + StratumExit.mask=2 will not detect the " +
		"Player CharacterBody2D at layer=0.")


# ---- Realistic chain: hit → dodge-during-iframes → dodge-end restores --

func test_take_damage_then_dodge_during_iframes_then_dodge_end_restores_layer() -> void:
	# Reproduces the exact Sponsor-soak failure chain (`83267fd` diag).
	#   1. Player takes non-fatal damage → take_damage line 585 calls
	#      _enter_iframes (saves layer=2, clears to 0, arms 0.25s timer).
	#   2. Player dodges DURING that window → try_dodge line 741 calls
	#      _enter_iframes again. Pre-fix clobbered the saved value.
	#   3. Dodge ends → _exit_dodge → _exit_iframes → restores layer.
	#   4. After the chain, the player must be back on layer=2.
	var p: Player = _make_player_in_tree()
	var layer_before: int = p.collision_layer
	assert_eq(layer_before, EXPECTED_PLAYER_LAYER, "sanity: starting layer 2")

	# 1. Non-fatal hit — arms iframes-on-hit timer.
	p.take_damage(3, Vector2.ZERO, null)
	assert_true(p.is_invulnerable(), "post-hit iframes active")
	assert_eq(p.collision_layer, 0, "layer cleared by hit iframes")

	# 2. Dodge DURING the hit-iframe window (try_dodge keys off
	#    _dodge_cooldown_left, not iframe state, so it is accepted).
	var dodge_ok: bool = p.try_dodge(Vector2.LEFT)
	assert_true(dodge_ok, "dodge accepted mid-hit-iframe-window")
	assert_eq(p.get_state(), Player.STATE_DODGE, "now in dodge state")
	assert_true(p.is_invulnerable(), "still invulnerable (dodge owns the window)")
	assert_eq(p.collision_layer, 0, "still cleared (idempotent on re-entry)")

	# 3. Tick dodge to completion — _exit_dodge → _exit_iframes restores layer.
	p._dodge_time_left = 0.0
	p._process_dodge(0.0)
	assert_false(p.is_invulnerable(), "dodge-end cleared iframes")

	# 4. The proof. Pre-fix this assertion FAILS with collision_layer == 0
	#    because the second _enter_iframes (in try_dodge) saved 0.
	assert_eq(p.collision_layer, layer_before,
		"REGRESSION GUARD (ticket 86c9uq0ky, Sponsor 2026-05-16 boss-room): " +
		"after the chain `take_damage → dodge-during-iframes → dodge-end`, " +
		"Player.collision_layer MUST be restored to the original value (2). " +
		"This is the EXACT chain Sponsor's diag-build `83267fd` traced ending " +
		"at `layer=0 mask=1` — the root cause of Pickup + StratumExit " +
		"body_entered never firing in the boss room.")


# ---- Realistic chain — N=3 nested re-entries (paranoia pin) -----------

func test_triple_reentry_then_exit_restores_layer() -> void:
	# Three back-to-back _enter_iframes calls (e.g. hit → dodge → another
	# hit during dodge-iframe blocked at take_damage entry; but synthesise
	# the worst-case to pin idempotency past N=2). One _exit must restore.
	var p: Player = _make_player_in_tree()
	var layer_before: int = p.collision_layer
	p._enter_iframes()
	p._enter_iframes()
	p._enter_iframes()
	assert_eq(p.collision_layer, 0, "still cleared after triple re-entry")
	p._exit_iframes()
	assert_eq(p.collision_layer, layer_before,
		"N=3 re-entries followed by a single exit must restore the " +
		"original layer — idempotency is general, not just N=2.")
