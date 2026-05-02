extends GutTest
## Tests for the Levels autoload (XP curve + level-up state machine).
##
## Per testing-bar: paired with feat(progression) — covers curve shape,
## level-up signal at exact threshold, multi-level overflow, edge cases
## (zero/negative gain, max-level cap), and save state round-trip.

const MIN_LEVEL: int = 1
const MAX_LEVEL: int = 5
const BASE_XP: int = 100
const EXP_POWER: float = 1.5


func _levels() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("Levels")
	assert_not_null(n, "Levels autoload must be registered in project.godot")
	return n


func before_each() -> void:
	_levels().reset()


# --- Curve shape -------------------------------------------------------

func test_curve_is_monotonic_increasing_until_cap() -> void:
	# xp_required_for(level) must be strictly increasing for 1 <= L < MAX,
	# then 0 at MAX_LEVEL (no further levels).
	var prev: int = -1
	for L: int in range(MIN_LEVEL, MAX_LEVEL):
		var cost: int = Levels.xp_required_for(L)
		assert_gt(cost, prev,
			"xp_required_for(%d) = %d must exceed previous %d" % [L, cost, prev])
		prev = cost
	assert_eq(Levels.xp_required_for(MAX_LEVEL), 0,
		"xp_required_for(MAX_LEVEL) must be 0 (no further levels)")


func test_curve_matches_expected_table() -> void:
	# Sanity-pin the curve so a silent change to BASE_XP / EXP_POWER trips
	# this test instead of leaking into a balance regression. If the curve
	# is changed deliberately, update this table AND DECISIONS.md.
	#
	# Formula: floor(100 * L^1.5)
	var expected: Dictionary = {
		1: 100,   # 100 * 1^1.5 = 100
		2: 282,   # 100 * 2^1.5 ~ 282.842 -> floor 282
		3: 519,   # 100 * 3^1.5 ~ 519.615 -> floor 519
		4: 800,   # 100 * 4^1.5 = 800.0
		5: 0,     # MAX_LEVEL — no further
	}
	for L: int in expected.keys():
		var got: int = Levels.xp_required_for(L)
		assert_eq(got, expected[L],
			"xp_required_for(%d) expected=%d got=%d" % [L, expected[L], got])


func test_curve_handles_negative_or_zero_level_input() -> void:
	# Robustness: don't crash on bogus input.
	var at_one: int = Levels.xp_required_for(1)
	assert_eq(Levels.xp_required_for(0), at_one, "L=0 clamps to L=1 cost")
	assert_eq(Levels.xp_required_for(-5), at_one, "L<0 clamps to L=1 cost")


# --- Level-up timing ---------------------------------------------------

func test_level_up_fires_at_exact_threshold() -> void:
	var sig := watch_signals(_levels())
	# At L1, need exactly 100 XP for L2.
	_levels().gain_xp(99)
	assert_eq(_levels().current_level(), 1, "99 XP doesn't level up from L1")
	assert_signal_emit_count(_levels(), "level_up", 0)
	_levels().gain_xp(1)
	assert_eq(_levels().current_level(), 2, "100th XP triggers L1->L2")
	assert_signal_emit_count(_levels(), "level_up", 1)
	# After level_up, _xp resets to 0 in the new level.
	assert_eq(_levels().current_xp(), 0)
	# Also the xp_to_next ceiling moves to L2's cost.
	assert_eq(_levels().xp_to_next(), Levels.xp_required_for(2))


func test_xp_gained_signal_emits_with_actual_amount() -> void:
	var sig := watch_signals(_levels())
	_levels().gain_xp(42)
	assert_signal_emit_count(_levels(), "xp_gained", 1)
	# Multiplier defaults to 1 in tests (DebugFlags.fast_xp_enabled is false).
	var params: Array = get_signal_parameters(_levels(), "xp_gained", 0)
	assert_eq(params[0], 42, "xp_gained payload matches the gain")


# --- Multi-level overflow ----------------------------------------------

func test_single_gain_crosses_multiple_levels() -> void:
	# Big gain at L1 — 100 + 282 = 382 brings us right to start-of-L3.
	# Going to 1000 lands at L3 + (1000 - 100 - 282) = 618 XP into L3.
	var sig := watch_signals(_levels())
	_levels().gain_xp(1000)
	assert_eq(_levels().current_level(), 3, "1000 XP from L1 ends at L3")
	assert_eq(_levels().current_xp(), 618, "overflow XP carries into next level")
	# level_up fires once per boundary — L1->L2 + L2->L3 = 2 emits.
	assert_signal_emit_count(_levels(), "level_up", 2)
	var p1: Array = get_signal_parameters(_levels(), "level_up", 0)
	var p2: Array = get_signal_parameters(_levels(), "level_up", 1)
	assert_eq(p1[0], 2, "first level_up payload = 2")
	assert_eq(p2[0], 3, "second level_up payload = 3")


func test_huge_gain_clamps_at_max_level() -> void:
	# 1_000_000 XP from L1 must land at MAX_LEVEL with 0 carried (the
	# overflow at the top of the ladder is dropped per the API contract).
	var sig := watch_signals(_levels())
	_levels().gain_xp(1_000_000)
	assert_eq(_levels().current_level(), MAX_LEVEL, "huge gain caps at MAX_LEVEL")
	assert_eq(_levels().current_xp(), 0, "no XP carries past MAX_LEVEL")
	# 4 boundaries crossed: L1->L2, L2->L3, L3->L4, L4->L5.
	assert_signal_emit_count(_levels(), "level_up", MAX_LEVEL - 1)


# --- Edge cases -------------------------------------------------------

func test_gain_zero_xp_is_noop() -> void:
	var sig := watch_signals(_levels())
	_levels().gain_xp(0)
	assert_eq(_levels().current_level(), 1)
	assert_eq(_levels().current_xp(), 0)
	assert_signal_emit_count(_levels(), "xp_gained", 0,
		"gain_xp(0) must NOT fire xp_gained")
	assert_signal_emit_count(_levels(), "level_up", 0)


func test_gain_negative_xp_is_rejected() -> void:
	# Don't accidentally "level down" from a bug. Reject negative.
	var sig := watch_signals(_levels())
	_levels().gain_xp(50)
	_levels().gain_xp(-9999)
	assert_eq(_levels().current_xp(), 50,
		"negative gain must not subtract from current XP")
	assert_signal_emit_count(_levels(), "xp_gained", 1,
		"only the positive gain fires xp_gained")
	assert_signal_emit_count(_levels(), "level_up", 0)


func test_gain_at_max_level_is_silent_clamp() -> void:
	# Drive to MAX_LEVEL then try to add more.
	_levels().gain_xp(1_000_000)
	assert_eq(_levels().current_level(), MAX_LEVEL)
	var sig := watch_signals(_levels())
	_levels().gain_xp(500)
	assert_eq(_levels().current_level(), MAX_LEVEL)
	assert_eq(_levels().current_xp(), 0)
	# At cap, neither signal should fire (gain is silently dropped).
	assert_signal_emit_count(_levels(), "xp_gained", 0)
	assert_signal_emit_count(_levels(), "level_up", 0)


# --- Save round-trip ---------------------------------------------------

func test_set_state_round_trips_in_range() -> void:
	_levels().set_state(3, 200)
	assert_eq(_levels().current_level(), 3)
	assert_eq(_levels().current_xp(), 200)
	assert_eq(_levels().xp_to_next(), Levels.xp_required_for(3))


func test_set_state_clamps_out_of_range_level() -> void:
	_levels().set_state(99, 0)
	assert_eq(_levels().current_level(), MAX_LEVEL,
		"level > MAX clamps to MAX")
	assert_eq(_levels().current_xp(), 0,
		"max-level XP must be 0 by contract (no carry past cap)")

	_levels().set_state(-3, 50)
	assert_eq(_levels().current_level(), MIN_LEVEL,
		"level < MIN clamps to MIN")


func test_set_state_clamps_xp_to_below_threshold() -> void:
	# At L2 with cost 282, set xp=999 — must not auto-level-up on load.
	_levels().set_state(2, 999)
	assert_eq(_levels().current_level(), 2,
		"set_state must NOT auto-level-up — it's pure deserialization")
	assert_lt(_levels().current_xp(), Levels.xp_required_for(2))


func test_snapshot_writes_level_xp_xp_to_next() -> void:
	_levels().set_state(2, 50)
	var character: Dictionary = {}
	_levels().snapshot_to_character(character)
	assert_eq(character["level"], 2)
	assert_eq(character["xp"], 50)
	assert_eq(character["xp_to_next"], Levels.xp_required_for(2))


# --- mob_died subscription --------------------------------------------

func test_subscribe_to_mob_grants_xp_on_death() -> void:
	# Build a fake mob object that emits the same signal shape as Grunt.
	# We don't need a real Grunt — we just need a Node with the signal and
	# a Resource carrying xp_reward.
	var fake_mob: Node = _make_fake_mob()
	add_child_autofree(fake_mob)
	var fake_def: Resource = _make_fake_mob_def(75)

	_levels().subscribe_to_mob(fake_mob)
	assert_eq(_levels().current_xp(), 0)
	# Emit the signal as the spawner / Grunt would on death.
	fake_mob.emit_signal("mob_died", fake_mob, Vector2(10, 20), fake_def)
	assert_eq(_levels().current_xp(), 75,
		"subscribe_to_mob applies mob_def.xp_reward on mob_died")


func test_subscribe_to_mob_tolerates_null_def() -> void:
	# A mob_died with null mob_def must not crash and must not grant XP.
	var fake_mob: Node = _make_fake_mob()
	add_child_autofree(fake_mob)
	_levels().subscribe_to_mob(fake_mob)
	fake_mob.emit_signal("mob_died", fake_mob, Vector2.ZERO, null)
	assert_eq(_levels().current_xp(), 0)


# --- Test helpers -----------------------------------------------------

func _make_fake_mob() -> Node:
	# Plain Node with a user-added signal matching Grunt.mob_died's shape.
	var n: Node = Node.new()
	n.add_user_signal("mob_died", [
		{"name": "mob", "type": TYPE_OBJECT},
		{"name": "death_position", "type": TYPE_VECTOR2},
		{"name": "mob_def", "type": TYPE_OBJECT},
	])
	return n


func _make_fake_mob_def(reward: int) -> Resource:
	# Tiny stand-in for MobDef. Levels._on_mob_died duck-types via
	# `"xp_reward" in mob_def`, which works as long as the property is
	# declared via @export (script-class) or set_meta(). Inline class
	# below keeps the test independent from content/MobDef.gd.
	return _FakeMobDef.new(reward)


# Minimal stub matching the duck-typed contract Levels._on_mob_died uses.
class _FakeMobDef extends Resource:
	@export var xp_reward: int = 0
	func _init(reward: int = 0) -> void:
		xp_reward = reward
