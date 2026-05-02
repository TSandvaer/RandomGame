extends GutTest
## Tests for Player movement & dodge-roll state machine.
##
## Strategy: exercise the public API (`try_dodge`, `is_invulnerable`,
## `get_state`, `can_dodge`) and the state-transition signal directly.
## We don't simulate the engine's `_physics_process` here — that would
## need a real frame loop; we cover the behaviours that aren't tied to
## delta-time progression. The dodge cooldown / duration timer logic
## is covered by the cooldown-tick test that calls `_tick_timers`
## explicitly with a known delta.
##
## Edge cases covered:
##   1. Dodge with zero direction falls back to current facing.
##   2. Cannot dodge while already dodging (rapid-fire double press).
##   3. I-frames are active during dodge, off after.
##   4. Cooldown blocks immediate re-dodge.
##   5. State transitions emit `state_changed` with correct from/to.
##   6. Collision layer is restored after i-frames clear.

const PlayerScript: Script = preload("res://scripts/player/Player.gd")


func _make_player() -> Player:
	var p: Player = PlayerScript.new()
	# Force _ready() to run since we're not adding to scene tree.
	p._ready()
	return p


# --- 1. Dodge fallback to facing ---------------------------------------

func test_dodge_with_zero_dir_uses_facing() -> void:
	var p: Player = _make_player()
	# Default facing is DOWN (0, 1).
	assert_eq(p.get_facing(), Vector2.DOWN, "default facing should be DOWN")
	var ok: bool = p.try_dodge(Vector2.ZERO)
	assert_true(ok, "dodge with zero dir should succeed and use facing")
	assert_eq(p._dodge_dir, Vector2.DOWN, "dodge dir falls back to facing on zero input")
	p.free()


func test_dodge_normalises_direction() -> void:
	var p: Player = _make_player()
	# Pass an unnormalised diagonal — internal must normalise.
	p.try_dodge(Vector2(3.0, 4.0))
	assert_almost_eq(p._dodge_dir.length(), 1.0, 0.001, "dodge dir must be unit length")
	p.free()


# --- 2. Rapid-fire double-press handled --------------------------------

func test_cannot_dodge_while_dodging() -> void:
	var p: Player = _make_player()
	assert_true(p.try_dodge(Vector2.RIGHT), "first dodge must succeed")
	assert_false(p.can_dodge(), "can_dodge() must return false during a dodge")
	assert_false(p.try_dodge(Vector2.LEFT), "second dodge during active dodge must be rejected")
	# State should still reflect the first dodge.
	assert_eq(p.get_state(), Player.STATE_DODGE)
	assert_eq(p._dodge_dir, Vector2.RIGHT, "second dodge attempt must not have overwritten direction")
	p.free()


# --- 3. I-frames are active during dodge, off after --------------------

func test_iframes_active_during_dodge() -> void:
	var p: Player = _make_player()
	assert_false(p.is_invulnerable(), "i-frames off before dodge")
	p.try_dodge(Vector2.UP)
	assert_true(p.is_invulnerable(), "i-frames on during dodge")
	# Tick past dodge duration to force exit.
	p._tick_timers(Player.DODGE_DURATION + 0.01)
	p._process_dodge(0.0)
	assert_false(p.is_invulnerable(), "i-frames off after dodge ends")


func test_iframes_signals_fire_in_order() -> void:
	var p: Player = _make_player()
	watch_signals(p)
	p.try_dodge(Vector2.UP)
	assert_signal_emitted(p, "iframes_started")
	p._tick_timers(Player.DODGE_DURATION + 0.01)
	p._process_dodge(0.0)
	assert_signal_emitted(p, "iframes_ended")
	p.free()


# --- 4. Cooldown blocks immediate re-dodge -----------------------------

func test_cooldown_blocks_immediate_redodge() -> void:
	var p: Player = _make_player()
	p.try_dodge(Vector2.RIGHT)
	# Tick to end the dodge but stay inside cooldown window.
	p._tick_timers(Player.DODGE_DURATION + 0.01)
	p._process_dodge(0.0)
	# Cooldown is DODGE_COOLDOWN measured from start; remaining = COOLDOWN - DURATION - 0.01.
	assert_false(p.can_dodge(), "can't dodge again until cooldown clears")
	assert_false(p.try_dodge(Vector2.LEFT), "dodge during cooldown rejected")

	# Tick past the cooldown end.
	p._tick_timers(Player.DODGE_COOLDOWN)
	assert_true(p.can_dodge(), "can dodge again after cooldown")
	p.free()


# --- 5. state_changed signal carries from/to ---------------------------

func test_state_changed_signal_carries_from_to() -> void:
	var p: Player = _make_player()
	watch_signals(p)
	p.set_state(Player.STATE_WALK)
	assert_signal_emitted_with_parameters(p, "state_changed", [Player.STATE_IDLE, Player.STATE_WALK])
	p.set_state(Player.STATE_DODGE)
	assert_signal_emitted_with_parameters(p, "state_changed", [Player.STATE_WALK, Player.STATE_DODGE])
	p.free()


func test_set_state_to_same_does_not_emit() -> void:
	var p: Player = _make_player()
	# First transition out of idle to clear the implicit setup.
	p.set_state(Player.STATE_WALK)
	watch_signals(p)
	p.set_state(Player.STATE_WALK)  # no-op
	assert_signal_emit_count(p, "state_changed", 0)
	p.free()


# --- 6. Collision layer restoration ------------------------------------

func test_collision_layer_cleared_during_iframes_restored_after() -> void:
	var p: Player = _make_player()
	var pre_dodge_layer: int = p.collision_layer
	assert_gt(pre_dodge_layer, 0, "player must occupy at least one collision layer pre-dodge")
	p.try_dodge(Vector2.UP)
	assert_eq(p.collision_layer, 0, "player layer cleared during i-frames so enemy hitboxes miss")
	# End the dodge.
	p._tick_timers(Player.DODGE_DURATION + 0.01)
	p._process_dodge(0.0)
	assert_eq(p.collision_layer, pre_dodge_layer, "player layer restored after i-frames")
	p.free()


# --- Bonus: 8-direction normalisation invariant ------------------------

func test_movement_diagonals_are_unit_length() -> void:
	# We cannot stub Input here without a test scene, so this asserts the
	# downstream invariant: any non-zero `_dodge_dir` (which mirrors what
	# `_facing` becomes from movement) is unit length. Movement input
	# normalisation is exercised by `Input.get_vector`'s own contract; we
	# trust Godot's stdlib and verify our wrapper does not denormalise.
	var p: Player = _make_player()
	for v: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(2, 0), Vector2(0, -3)]:
		p.try_dodge(v)
		assert_almost_eq(p._dodge_dir.length(), 1.0, 0.001, "dodge direction unit length for %s" % v)
		# Reset for next iteration.
		p._tick_timers(Player.DODGE_COOLDOWN + Player.DODGE_DURATION + 0.01)
		p._process_dodge(0.0)
	p.free()
