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

## Boss HP multiplier — Sponsor soak-iteration dev utility (2026-05-21). Reads
## from the HTML5 URL query param `boss_hp_mult` on boot; defaults to 1.0 (no
## nerf) when missing / malformed / desktop. Clamped to [0.05, 5.0] to keep
## extreme values from breaking phase-boundary math. Applied at boss spawn-time
## by `Stratum1Boss._apply_mob_def` (see that function for the multiplication
## point).
##
## Usage:
##   http://localhost:8080/?boss_hp_mult=0.5   → 300 HP boss (50% nerf)
##   http://localhost:8080/?boss_hp_mult=0.1   → 60  HP boss (10% — fast soak)
##   http://localhost:8080/                    → 600 HP boss (production default)
##
## Desktop / headless GUT always reads 1.0 (no JavaScriptBridge available); the
## multiplier never affects production / non-web builds. Trace line emitted on
## boot lists the resolved value so Sponsor can confirm the URL param landed.
const BOSS_HP_MULT_QUERY_PARAM: String = "boss_hp_mult"
const BOSS_HP_MULT_DEFAULT: float = 1.0
const BOSS_HP_MULT_MIN: float = 0.05
const BOSS_HP_MULT_MAX: float = 5.0

## Start-room URL query param — Sponsor/Drew soak-iteration utility (2026-05-21,
## PR #291 v4 self-soak gap). When set on the HTML5 URL, `Main._ready` calls
## `load_room_index(N)` AFTER the normal Room 01 boot path so the player drops
## directly into Room N instead of having to traverse 1..N. Defaults to -1 (no
## override) when missing / malformed / desktop. Clamped to `[0, BOSS_ROOM_INDEX]`
## (0..8) so out-of-range values can't load a non-existent room. Same shape as
## `boss_hp_mult` — HTML5-only via JavaScriptBridge; desktop / headless GUT
## always reads the default. Trace line emitted on boot lists the resolved value.
##
## Usage:
##   http://localhost:8080/?start_room=8                 → drops into boss room
##   http://localhost:8080/?start_room=8&boss_hp_mult=0.1 → boss room + 60 HP boss
##                                                           (phase 2 in ~1 hit)
##   http://localhost:8080/                              → Room 01 (production)
##
## Use case: self-soak of boss-room visuals (slam telegraph, aftershock burst,
## phase-transition slow-mo) without needing to clear Rooms 01-07 first. The
## AC4 Playwright spec stops at Room 05 on a game-side death-physics-flush
## blocker (out of scope for boss-visual PRs); start_room bypasses that.
const START_ROOM_QUERY_PARAM: String = "start_room"
const START_ROOM_DEFAULT: int = -1
const START_ROOM_MIN: int = 0
const START_ROOM_MAX: int = 8  # BOSS_ROOM_INDEX in Main.gd

# Public state — read by gameplay code, written only via toggle/parse functions.
var fast_xp_enabled: bool = false
var test_mode_enabled: bool = false
var boss_hp_mult: float = BOSS_HP_MULT_DEFAULT
var start_room: int = START_ROOM_DEFAULT

# Emitted when fast_xp_enabled flips, so HUD/debug overlays can reflect it.
signal fast_xp_toggled(enabled: bool)


func _ready() -> void:
	# Hook 4 — parse CLI args + env on boot, regardless of debug/release.
	# Even in release, ignoring the flag here keeps test_mode_enabled=false,
	# so mob spawn seed stays free. See `_resolve_test_mode()` for gating.
	_resolve_test_mode()
	_resolve_boss_hp_mult()
	_resolve_start_room()
	# Single boot-time line for Tess's grep.
	print(
		(
			(
				"[DebugFlags] debug_build=%s test_mode=%s fast_xp=%s"
				+ " web=%s boss_hp_mult=%.3f start_room=%d"
			)
			% [
				OS.is_debug_build(),
				test_mode_enabled,
				fast_xp_enabled,
				OS.has_feature("web"),
				boss_hp_mult,
				start_room,
			]
		)
	)


## Combat-trace gate (Sponsor soak `embergrave-html5-0e77a92`). When running
## in the HTML5 export (`OS.has_feature("web") == true`), combat-pipeline code
## paths emit a line via `combat_trace(tag, msg)` so Sponsor can capture the
## chain via F12 DevTools console. Off everywhere else — desktop/headless GUT
## stay quiet so test logs don't fill with chatter.
##
## The diagnostic build for Sponsor's next soak relies on this trace to
## confirm WHICH step in the `try_attack → Hitbox → mob.take_damage →
## _play_hit_flash → _die → tween → _force_queue_free` chain actually fires
## (or doesn't fire) under the HTML5 web canvas + gl_compatibility renderer.
func combat_trace_enabled() -> bool:
	return OS.has_feature("web")


## Emit a combat-trace line. Tag is the source (e.g. "Player.try_attack",
## "Hitbox.hit", "Grunt.die"); msg is free-form context. No-op when
## combat_trace_enabled() is false. Centralised so the print format is
## stable and Sponsor's grep over DevTools output is reliable.
func combat_trace(tag: String, msg: String = "") -> void:
	if not combat_trace_enabled():
		return
	if msg.is_empty():
		print("[combat-trace] %s" % tag)
	else:
		print("[combat-trace] %s | %s" % [tag, msg])


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
	print(
		(
			"[DebugFlags] fast_xp_enabled=%s (multiplier now %dx)"
			% [
				fast_xp_enabled,
				xp_multiplier(),
			]
		)
	)
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


## Sponsor 2026-05-21 soak-iteration utility. Reads the `boss_hp_mult` URL
## query param via JavaScriptBridge on HTML5; no-op on desktop / headless GUT.
## Defaults to 1.0 (production HP); clamps parsed values to [MIN, MAX] so
## extreme inputs don't break phase-boundary math (a 0.01 mult on 600 HP would
## leave 6 HP, below the 198 phase-3 threshold and below the 396 phase-2
## threshold — phase boundaries would never latch). Applied at boss spawn-time
## in `Stratum1Boss._apply_mob_def`.
##
## Why no debug-build gate (unlike fast_xp / test_mode): Sponsor's iteration
## workflow runs against the same HTML5 release-build artifact as production
## soak. Debug-gating here would make the utility unusable for its actual
## consumer. Mitigations: (a) default is always 1.0 — no behavior change
## without an explicit URL param, (b) clamped range, (c) HTML5-only via
## JavaScriptBridge — desktop / headless tests never touch it. If Tess wants
## to exercise the mult path in GUT, `set_boss_hp_mult_for_test()` below
## provides a clean injection surface that bypasses the bridge.
func _resolve_boss_hp_mult() -> void:
	# Default unless we successfully read a valid float from the URL.
	boss_hp_mult = BOSS_HP_MULT_DEFAULT
	if not OS.has_feature("web"):
		return
	if not Engine.has_singleton("JavaScriptBridge"):
		return
	var bridge: Object = Engine.get_singleton("JavaScriptBridge")
	# Read the query param. `URLSearchParams.get(key)` returns null when absent,
	# string otherwise. We coerce via String() and bail if empty/null.
	var raw_value: Variant = bridge.eval(
		"new URLSearchParams(window.location.search).get('%s')" % BOSS_HP_MULT_QUERY_PARAM, true
	)
	if raw_value == null:
		return
	var raw_str: String = str(raw_value).strip_edges()
	if raw_str.is_empty() or raw_str == "null":
		return
	if not raw_str.is_valid_float():
		push_warning("[DebugFlags] boss_hp_mult URL param invalid float: %s" % raw_str)
		return
	var parsed: float = raw_str.to_float()
	# Clamp to safe range so extreme inputs don't break phase-boundary math.
	var clamped: float = clamp(parsed, BOSS_HP_MULT_MIN, BOSS_HP_MULT_MAX)
	boss_hp_mult = clamped
	if not is_equal_approx(parsed, clamped):
		push_warning(
			(
				("[DebugFlags] boss_hp_mult clamped from %.3f to %.3f " + "(range [%.2f..%.2f])")
				% [parsed, clamped, BOSS_HP_MULT_MIN, BOSS_HP_MULT_MAX]
			)
		)


## Test-only: inject a boss HP multiplier without going through the JS bridge.
## Tests can call this in `before_each` to exercise the nerf path in headless
## GUT (the production bridge path is unreachable from GUT — `OS.has_feature("web")`
## is always false). Clamps to the production range to keep test inputs
## self-consistent with what the URL parser would accept.
func set_boss_hp_mult_for_test(mult: float) -> void:
	boss_hp_mult = clamp(mult, BOSS_HP_MULT_MIN, BOSS_HP_MULT_MAX)


## Test-only: reset to production default. Pair with `set_boss_hp_mult_for_test`
## in `after_each` so leaked state can't cascade across the test file.
func reset_boss_hp_mult_for_test() -> void:
	boss_hp_mult = BOSS_HP_MULT_DEFAULT


## Read the `start_room` URL query param via JavaScriptBridge on HTML5; no-op on
## desktop / headless GUT. Defaults to -1 (no override) when absent / malformed.
## Clamps parsed values to [START_ROOM_MIN, START_ROOM_MAX] (0..8) so an
## out-of-range value can never reach `Main.load_room_index` with a bad index.
##
## Same rationale as `_resolve_boss_hp_mult` for the no-debug-gate posture:
## Sponsor / Drew run this against the production-shape HTML5 release artifact.
## Mitigations: (a) default = -1 means "no override" — zero behavior change
## without an explicit URL param, (b) clamped range, (c) HTML5-only via bridge.
func _resolve_start_room() -> void:
	start_room = START_ROOM_DEFAULT
	if not OS.has_feature("web"):
		return
	if not Engine.has_singleton("JavaScriptBridge"):
		return
	var bridge: Object = Engine.get_singleton("JavaScriptBridge")
	var raw_value: Variant = bridge.eval(
		"new URLSearchParams(window.location.search).get('%s')" % START_ROOM_QUERY_PARAM, true
	)
	if raw_value == null:
		return
	var raw_str: String = str(raw_value).strip_edges()
	if raw_str.is_empty() or raw_str == "null":
		return
	if not raw_str.is_valid_int():
		push_warning("[DebugFlags] start_room URL param invalid int: %s" % raw_str)
		return
	var parsed: int = raw_str.to_int()
	var clamped: int = clamp(parsed, START_ROOM_MIN, START_ROOM_MAX)
	start_room = clamped
	if parsed != clamped:
		push_warning(
			(
				("[DebugFlags] start_room clamped from %d to %d " + "(range [%d..%d])")
				% [parsed, clamped, START_ROOM_MIN, START_ROOM_MAX]
			)
		)


## Test-only: inject a start-room override without the JS bridge. Tests can
## set this in `before_each` to drive Main._ready into a non-Room01 boot path
## (or use the default -1 to disable). Clamps inputs the same way the URL parser
## does so test inputs match production semantics.
func set_start_room_for_test(index: int) -> void:
	if index < 0:
		start_room = START_ROOM_DEFAULT
		return
	start_room = clamp(index, START_ROOM_MIN, START_ROOM_MAX)


## Test-only: reset to production default. Pair with `set_start_room_for_test`
## in `after_each` so leaked state can't cascade across the test file.
func reset_start_room_for_test() -> void:
	start_room = START_ROOM_DEFAULT
