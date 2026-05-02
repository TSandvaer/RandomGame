extends Node
## DebugFlags autoload — central home for non-shipped testability flags.
##
## Two flags live here today:
##   1. `fast_xp_enabled` (Hook 2) — toggled by Ctrl+Shift+X. When true,
##      `xp_multiplier()` returns 100, otherwise 1. Tess uses this to reach
##      level 4-5 in <2 min for AC4/AC7 testing per `m1-test-plan.md`.
##   2. `test_mode_enabled` (Hook 4) — set by the `--test-mode` CLI arg or
##      the `EMBERGRAVE_TEST_MODE` env var. When true, `mob_spawn_seed()`
##      returns a fixed seed so AC4 mob layouts are reproducible.
##
## **Release-build safety:** all flag-toggling input + flag activation is
## gated behind `OS.is_debug_build()`. In a release export, the input
## handler never connects, the chord can't be triggered, and CLI/env flags
## are ignored. `xp_multiplier()` and `mob_spawn_seed()` always return
## production-safe values in release. This is the "compile-out" requirement
## from the task spec — short of a real preprocessor, this is the
## next-best static gate.
##
## **Loot RNG isolation:** Drew's LootRoller already takes its own seeded
## RNG (`seed_rng(int)` per `team/drew-dev/level-chunks.md`). DebugFlags
## intentionally does NOT touch the global RNG or any RNG outside mob
## spawning. `mob_spawn_seed()` is purely a value to be passed into
## `RandomNumberGenerator.seed = <value>` by mob-spawning code; loot
## continues to roll deterministically per its own seed.
##
## **Configuration:**
##   - Fast-XP multiplier (`FAST_XP_MULTIPLIER = 100`) is a placeholder.
##     Priya owns the level curve; if 100x conflicts with the curve's
##     intent, swap here in one place. Flagged in the PR body.
##   - Test-mode seed (`TEST_MODE_MOB_SEED = 0x7E57C0DE`) is arbitrary
##     but stable. Reproducibility is the value, not the number.

const FAST_XP_MULTIPLIER: int = 100
const NORMAL_XP_MULTIPLIER: int = 1
# Arbitrary stable seed; reproducibility is the value, not the number.
# Spelled in hex so it's obviously a fixed test fixture, not arithmetic.
const TEST_MODE_MOB_SEED: int = 0x7E57C0DE
const TEST_MODE_CLI_FLAG: String = "--test-mode"
const TEST_MODE_ENV_VAR: String = "EMBERGRAVE_TEST_MODE"

# Public state — read by gameplay code, written only via toggle/parse functions.
var fast_xp_enabled: bool = false
var test_mode_enabled: bool = false

# Emitted when fast_xp_enabled flips, so HUD/debug overlays can reflect it.
signal fast_xp_toggled(enabled: bool)


func _ready() -> void:
	# Hook 4 — parse CLI args + env on boot, regardless of debug/release.
	# Even in release, ignoring the flag here keeps test_mode_enabled=false,
	# so mob spawn seed stays free. See `_resolve_test_mode()` for gating.
	_resolve_test_mode()
	# Single boot-time line for Tess's grep.
	print("[DebugFlags] debug_build=%s test_mode=%s fast_xp=%s" % [
		OS.is_debug_build(),
		test_mode_enabled,
		fast_xp_enabled,
	])


## Receives unhandled input. Only debug builds wire the chord — release
## ignores the event entirely. Cheap belt-and-braces: even if `_input` ran
## in release somehow, the early return is structurally guaranteed.
func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return
	# Chord: Ctrl+Shift+X. Use physical keycode so it works regardless of
	# keyboard layout (X is at the same physical location on QWERTY/AZERTY/
	# Dvorak). Avoids stomping accessibility shortcuts the OS might own.
	if key_event.physical_keycode == KEY_X and key_event.ctrl_pressed and key_event.shift_pressed:
		_toggle_fast_xp()
		# Mark handled so it doesn't fire any other action.
		get_viewport().set_input_as_handled()


## Returns the XP multiplier currently in effect. Always 1 in release
## builds (the gate at `_toggle_fast_xp` makes `fast_xp_enabled` impossible
## to set to true outside debug). The float return type is what level-up
## math will want; the constants are ints for legibility.
func xp_multiplier() -> int:
	if OS.is_debug_build() and fast_xp_enabled:
		return FAST_XP_MULTIPLIER
	return NORMAL_XP_MULTIPLIER


## Returns the seed for mob-spawn RNGs. Caller (mob spawner) does:
##   var rng := RandomNumberGenerator.new(); rng.seed = DebugFlags.mob_spawn_seed()
## Production behavior: when test mode is off, returns a freshly-randomized
## seed so each run is unique. Test mode: always the same seed, so AC4
## mob-layout tests are reproducible.
func mob_spawn_seed() -> int:
	if OS.is_debug_build() and test_mode_enabled:
		return TEST_MODE_MOB_SEED
	# Truly random per call — caller owns the RNG, we just hand them entropy.
	return randi()


## Test-only: toggle fast-XP without simulating an InputEventKey. Wraps the
## same internal path so signal emission and release-build gating both
## apply. Tests assert via `xp_multiplier()` round-trip.
func toggle_fast_xp_for_test() -> void:
	_toggle_fast_xp()


## Test-only: force test_mode_enabled state. Bypasses CLI/env parsing so
## tests don't need to relaunch the engine. Still respects
## `OS.is_debug_build()` — release-build tests would always read false.
func set_test_mode_for_test(enabled: bool) -> void:
	if not OS.is_debug_build():
		test_mode_enabled = false
		return
	test_mode_enabled = enabled


# ---- Internals ----------------------------------------------------------

func _toggle_fast_xp() -> void:
	# Defense in depth: the only writer of fast_xp_enabled, and it refuses
	# to flip on in release. Belt to `_input`'s suspenders.
	if not OS.is_debug_build():
		fast_xp_enabled = false
		return
	fast_xp_enabled = not fast_xp_enabled
	print("[DebugFlags] fast_xp_enabled=%s (multiplier now %dx)" % [
		fast_xp_enabled,
		xp_multiplier(),
	])
	fast_xp_toggled.emit(fast_xp_enabled)


func _resolve_test_mode() -> void:
	# Release builds ignore the flag entirely.
	if not OS.is_debug_build():
		test_mode_enabled = false
		return
	# CLI arg first (explicit beats environmental).
	var args: PackedStringArray = OS.get_cmdline_args()
	for a: String in args:
		if a == TEST_MODE_CLI_FLAG:
			test_mode_enabled = true
			return
	# Env var second. Any non-empty, non-"0", non-"false" value enables.
	var raw: String = OS.get_environment(TEST_MODE_ENV_VAR).strip_edges().to_lower()
	if raw != "" and raw != "0" and raw != "false":
		test_mode_enabled = true
