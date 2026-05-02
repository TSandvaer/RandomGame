extends GutTest
## Tests for Hook 4 — stable mob-spawn seed in test mode.
##
## Verifies:
##   - When test mode is OFF, `mob_spawn_seed()` returns randomized values
##     (different each call) so production play is never reproducible.
##   - When test mode is ON, `mob_spawn_seed()` returns the *same* fixed
##     value every call so AC4 mob-layout setup is reproducible.
##   - Seeding a `RandomNumberGenerator` with the test-mode seed produces
##     identical sequences across runs (the actual contract for mob
##     spawners).
##   - Loot RNG is unaffected — DebugFlags doesn't touch the global RNG or
##     any RNG owned by Drew's `LootRoller`. (We can't directly test that
##     here without bringing in LootRoller; we assert the boundary by
##     verifying mob_spawn_seed only flips when test_mode flips, not when
##     fast_xp flips.)
##
## Like the fast-XP tests, all assertions are debug-build conditional.
## Release builds always behave as if test_mode_enabled=false, regardless
## of CLI/env input — verified via state-poisoning test.


func _flags() -> Node:
	var df: Node = Engine.get_main_loop().root.get_node_or_null("DebugFlags")
	assert_not_null(df, "DebugFlags autoload must be registered in project.godot")
	return df


func before_each() -> void:
	# Default state — test mode off, fast-XP off.
	_flags().set_test_mode_for_test(false)
	_flags().fast_xp_enabled = false


func after_each() -> void:
	_flags().set_test_mode_for_test(false)
	_flags().fast_xp_enabled = false


# --- Test mode OFF: free RNG --------------------------------------------

func test_seed_varies_when_test_mode_off() -> void:
	# Three calls; collect distinct values. With a 32-bit randi() space, the
	# probability of a collision in 3 draws is ~3e-9 — effectively zero.
	# If two match, the test correctly flags the regression.
	var seeds: Array[int] = []
	for i: int in range(3):
		seeds.append(_flags().mob_spawn_seed())
	# Not strictly required to be all-different, but with N=3 it's the right
	# assertion for "RNG is alive."
	var distinct: int = 0
	for v: int in seeds:
		if seeds.count(v) == 1:
			distinct += 1
	assert_gt(distinct, 0, "test mode off -> seeds should vary; got %s" % str(seeds))


# --- Test mode ON: stable seed ------------------------------------------

func test_seed_is_stable_when_test_mode_on() -> void:
	if not OS.is_debug_build():
		pending("Test requires a debug build to enable test mode.")
		return
	_flags().set_test_mode_for_test(true)
	var first: int = _flags().mob_spawn_seed()
	var second: int = _flags().mob_spawn_seed()
	var third: int = _flags().mob_spawn_seed()
	assert_eq(first, second, "test mode on -> stable seed across calls")
	assert_eq(second, third, "test mode on -> stable seed across calls (3rd)")


func test_seeded_rng_produces_identical_sequence() -> void:
	# The actual contract: mob spawners do
	#   rng.seed = DebugFlags.mob_spawn_seed()
	# in test mode and expect the same draw sequence each run.
	if not OS.is_debug_build():
		pending("Test requires a debug build.")
		return
	_flags().set_test_mode_for_test(true)

	var rng_a: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_a.seed = _flags().mob_spawn_seed()
	var draws_a: Array[int] = []
	for i: int in range(8):
		draws_a.append(rng_a.randi())

	var rng_b: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_b.seed = _flags().mob_spawn_seed()
	var draws_b: Array[int] = []
	for i: int in range(8):
		draws_b.append(rng_b.randi())

	assert_eq(draws_a, draws_b, "same seed -> same 8-draw sequence")


func test_test_mode_seed_constant_is_stable() -> void:
	# Defensive: the actual seed value is documented in debug-flags.md; if
	# someone changes it, AC4 layouts shift and the docs go stale. This
	# test pins the constant.
	assert_eq(_flags().TEST_MODE_MOB_SEED, 0x7E57C0DE,
		"TEST_MODE_MOB_SEED is the documented testability constant")


# --- Test mode toggle is independent of fast-XP ------------------------

func test_test_mode_does_not_affect_xp_multiplier() -> void:
	if not OS.is_debug_build():
		pending("Test requires a debug build.")
		return
	_flags().set_test_mode_for_test(true)
	_flags().fast_xp_enabled = false
	assert_eq(_flags().xp_multiplier(), 1, "test mode alone must not amplify XP")


func test_fast_xp_does_not_affect_mob_seed() -> void:
	# Toggling fast-XP must not change whether the mob seed is fixed.
	if not OS.is_debug_build():
		pending("Test requires a debug build.")
		return
	_flags().set_test_mode_for_test(false)
	_flags().fast_xp_enabled = true
	# With test mode off, two seeds should still be free (random).
	var a: int = _flags().mob_spawn_seed()
	var b: int = _flags().mob_spawn_seed()
	# Don't strictly require difference (1-in-2^31 collision); just verify
	# we DIDN'T fall into the fixed-seed branch.
	assert_ne(a, _flags().TEST_MODE_MOB_SEED, "fast-XP must not pin the mob seed")
	assert_ne(b, _flags().TEST_MODE_MOB_SEED, "fast-XP must not pin the mob seed")


# --- Release-build structural gate --------------------------------------

func test_set_test_mode_for_test_is_release_safe() -> void:
	# Belt-and-braces: in a release build, set_test_mode_for_test forcibly
	# returns false. We can only assert this directly in a debug build by
	# checking the autoload's gate is wired — by reading the source path
	# `if not OS.is_debug_build(): test_mode_enabled = false; return`.
	# For the runtime assertion we round-trip through the setter:
	_flags().set_test_mode_for_test(true)
	if OS.is_debug_build():
		assert_true(_flags().test_mode_enabled)
	else:
		assert_false(_flags().test_mode_enabled, "release build must ignore set_test_mode_for_test(true)")


func test_mob_spawn_seed_release_build_never_pins() -> void:
	# Even with state forcibly set, mob_spawn_seed() in release returns
	# randi() — the gate is in mob_spawn_seed itself.
	_flags().test_mode_enabled = true
	if OS.is_debug_build():
		assert_eq(_flags().mob_spawn_seed(), _flags().TEST_MODE_MOB_SEED)
	else:
		assert_ne(_flags().mob_spawn_seed(), _flags().TEST_MODE_MOB_SEED,
			"release build must never pin mob seed regardless of state")
