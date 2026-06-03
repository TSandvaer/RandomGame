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
##   http://localhost:8080/?start_room=8                 → drops into S1 boss room
##   http://localhost:8080/?start_room=9                 → drops into S2 boss room
##                                                           (W3-T7 Stage 6)
##   http://localhost:8080/?start_room=8&boss_hp_mult=0.1 → boss room + 60 HP boss
##                                                           (phase 2 in ~1 hit)
##   http://localhost:8080/                              → Room 01 (production)
##
## Use case: self-soak of boss-room visuals (slam telegraph, aftershock burst,
## phase-transition slow-mo) without needing to clear Rooms 01-07 first. The
## AC4 Playwright spec stops at Room 05 on a game-side death-physics-flush
## blocker (out of scope for boss-visual PRs); start_room bypasses that.
##
## **W3-T7 Stage 6 (ticket `86c9y7ygj`):** START_ROOM_MAX raised 8 → 9 so
## `?start_room=9` reaches the newly-wired Stratum2BossRoom terminal index
## (`Main.S2_BOSS_ROOM_INDEX`). The Stratum2BossRoom self-soak + Playwright
## spec boot via this hook — the production `_load_room_at_index(9)` path.
const START_ROOM_QUERY_PARAM: String = "start_room"
const START_ROOM_DEFAULT: int = -1
const START_ROOM_MIN: int = 0
const START_ROOM_MAX: int = 9  # S2_BOSS_ROOM_INDEX in Main.gd (Stage 6)

## Force-descend URL query param — Sponsor/Devon soak utility (W2-T5 fix
## ticket `86c9y10fv`, 2026-05-24). When set on the HTML5 URL,
## `Main._ready` calls `force_descend_for_test()` AFTER the normal Room 01
## boot path so the DescendScreen opens immediately without requiring
## boss-kill traversal. Defaults to false (no force) when missing /
## malformed / desktop. Same HTML5-only-via-bridge shape as boss_hp_mult /
## start_room — desktop / headless GUT always reads the default.
##
## Usage:
##   http://localhost:8080/?force_descend=1   → DescendScreen opens at boot
##   http://localhost:8080/?force_descend=1&start_room=0 → same
##   http://localhost:8080/                    → normal Room 01 boot
##
## Use case: Playwright spec for the W2-T5 RC fix — exercises the
## DescendScreen "Open Map" button-click → WorldMapPanel-mount → visibility
## path empirically without needing to play through 8 rooms + boss-kill.
## Closes the coverage gap that let the original Sponsor RC P0 ship
## (the render-only `world-map-panel-render.spec.ts` boots the panel by
## a direct route that bypasses the click handler entirely).
const FORCE_DESCEND_QUERY_PARAM: String = "force_descend"

## Camera-zoom soak control — Sponsor dials in the S1 perspective himself, then
## we lock the value in a follow-up (ticket 86ca3kjyg, 2026-06-02). Sponsor's
## recurring S1 soak verdict: "the zoom perspective is still much too zoomed".
## A tunable build ends the nudge-and-resoak loop — Sponsor finds the exact
## NORMALIZED zoom value empirically and reports it.
##
## `?cam_zoom=N` URL query param applied to `CameraDirector.request_zoom(N, 0.0)`
## at boot (HTML5 only). N is the NORMALIZED scale (1.0 == default pre-T9
## rendering; <1.0 zooms OUT / shows more room — what Sponsor wants; >1.0 zooms
## IN). Clamped to CameraDirector's own [MIN, MAX] normalized range [0.5, 4.0],
## mirrored here as CAM_ZOOM_MIN / CAM_ZOOM_MAX so the readout + key-step can
## clamp before reaching the director (avoids the director's own WarningBus
## clamp-warning on every key tap). Default -1.0 = "no override" (negative is
## the sentinel, same shape as start_room's -1).
##
## LIVE +/- keys (HTML5 only, soak-gated on OS.has_feature("web")): the soak
## runs against the production-shape RELEASE artifact (same posture as
## boss_hp_mult — debug-gating would make the utility unusable for its actual
## consumer). `=`/`+` steps zoom IN by CAM_ZOOM_STEP; `-`/`_` steps OUT; `0`
## resets to default 1.0×. Each press re-requests the director zoom + emits
## `cam_zoom_changed` so Main's on-screen readout reflects the live value the
## Sponsor reads off and reports back.
##
## Usage:
##   http://localhost:8080/?cam_zoom=0.7  → boot at 0.7× (wider view, smaller sprites)
##   then press -/+ in-session to fine-tune; read the on-screen "CAM ZOOM x.xx"
##   http://localhost:8080/               → no override; +/- still adjust live
##
## Desktop / headless GUT: -1.0 (no override) + keys inert (web-feature gate).
## Test injection via set_cam_zoom_for_test / step_cam_zoom_for_test below.
const CAM_ZOOM_QUERY_PARAM: String = "cam_zoom"
const CAM_ZOOM_DEFAULT: float = -1.0  # negative sentinel = no override
const CAM_ZOOM_MIN: float = 0.5  # mirror CameraDirector.MIN_NORMALIZED_ZOOM
const CAM_ZOOM_MAX: float = 4.0  # mirror CameraDirector.MAX_NORMALIZED_ZOOM
const CAM_ZOOM_STEP: float = 0.05  # per-keypress increment
const CAM_ZOOM_RESET: float = 1.0  # the default normalized zoom (== CameraDirector default)

## Character-scale soak control — Sponsor dials in the player/mob sprite size on
## the widened S1 build himself, then we lock the value in a follow-up (ticket
## 86ca3kpzz Stage-1 soak iteration). Sibling of `?cam_zoom`: that dial controls
## the CAMERA perspective; this one controls how BIG the characters render
## inside that perspective. On the 2x-wider scrolling room the default-size
## sprites can read too large; the Sponsor finds the right NORMALIZED scale
## empirically and reports it.
##
## `?char_scale=N` URL query param. N is the NORMALIZED scale applied to the
## PLAYER + every NON-BOSS mob's ROOT node (1.0 == ship size; <1.0 = smaller
## sprite+collision; >1.0 = larger). Scaling the ROOT means the sprite AND the
## CollisionShape2D / Hitbox shrink together (no big-hitbox-on-small-sprite
## mismatch). **BOSSES are EXCLUDED** — `Stratum1Boss` / `ArchiveSentinel` stay
## full size (Sponsor's explicit choice). The boss discriminator is the
## `boss_died` signal (every boss has it; no regular mob does) — see
## `Main._char_scale_is_boss`. Clamped to [CHAR_SCALE_MIN, CHAR_SCALE_MAX].
## Default -1.0 = "no override" (negative sentinel, same shape as cam_zoom).
##
## LIVE keys (HTML5 only, soak-gated on OS.has_feature("web"), same posture as
## cam_zoom — the soak runs the RELEASE artifact): `[` steps DOWN by
## CHAR_SCALE_STEP; `]` steps UP; `\` resets to 1.0. Keys chosen to NOT collide
## with cam_zoom's `-`/`+`/`0`. Each step re-applies to live characters + emits
## `char_scale_changed` so Main's on-screen readout reflects the live value.
##
## Usage:
##   http://localhost:8080/?start_room=1&char_scale=0.8  → widened Room02, 0.8x chars
##   then press [ / ] in-session to fine-tune; read "CHAR SCALE x.xx"
##   http://localhost:8080/?start_room=1                 → no override; [ ] still adjust live
##
## Desktop / headless GUT: -1.0 (no override) + keys inert (web-feature gate).
## Test injection via set_char_scale_for_test / step_char_scale_for_test below.
const CHAR_SCALE_QUERY_PARAM: String = "char_scale"
const CHAR_SCALE_DEFAULT: float = -1.0  # negative sentinel = no override
const CHAR_SCALE_MIN: float = 0.3
const CHAR_SCALE_MAX: float = 2.0
const CHAR_SCALE_STEP: float = 0.05  # per-keypress increment
const CHAR_SCALE_RESET: float = 1.0  # ship size (no scaling)

# Public state — read by gameplay code, written only via toggle/parse functions.
var fast_xp_enabled: bool = false
var test_mode_enabled: bool = false
var boss_hp_mult: float = BOSS_HP_MULT_DEFAULT
var start_room: int = START_ROOM_DEFAULT
var force_descend: bool = false
var cam_zoom: float = CAM_ZOOM_DEFAULT
var char_scale: float = CHAR_SCALE_DEFAULT

# Emitted when fast_xp_enabled flips, so HUD/debug overlays can reflect it.
signal fast_xp_toggled(enabled: bool)

## Emitted whenever the live soak cam-zoom value changes (URL-param boot apply,
## or a +/- key step). Payload is the new NORMALIZED zoom. Main's HUD readout
## subscribes so the Sponsor can read the exact value he settles on.
signal cam_zoom_changed(normalized: float)

## Emitted whenever the live soak char-scale value changes (URL-param boot apply,
## or a `[` / `]` / `\` key step). Payload is the new NORMALIZED scale. Main
## subscribes to (a) re-apply the scale to the live player + non-boss mobs and
## (b) update its HUD readout so the Sponsor can read the value he settles on.
signal char_scale_changed(normalized: float)


func _ready() -> void:
	# Hook 4 — parse CLI args + env on boot, regardless of debug/release.
	# Even in release, ignoring the flag here keeps test_mode_enabled=false,
	# so mob spawn seed stays free. See `_resolve_test_mode()` for gating.
	_resolve_test_mode()
	_resolve_boss_hp_mult()
	_resolve_start_room()
	_resolve_force_descend()
	_resolve_cam_zoom()
	_resolve_char_scale()
	# Single boot-time line for Tess's grep.
	print(
		(
			(
				"[DebugFlags] debug_build=%s test_mode=%s fast_xp=%s"
				+ " web=%s boss_hp_mult=%.3f start_room=%d force_descend=%s cam_zoom=%.3f char_scale=%.3f"
			)
			% [
				OS.is_debug_build(),
				test_mode_enabled,
				fast_xp_enabled,
				OS.has_feature("web"),
				boss_hp_mult,
				start_room,
				force_descend,
				cam_zoom,
				char_scale,
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


## Live cam-zoom soak keys. Gated on `OS.has_feature("web")` (NOT
## `OS.is_debug_build()`) because the Sponsor soaks the production-shape HTML5
## RELEASE artifact — same posture as the `?cam_zoom` URL param. Desktop /
## headless GUT never enter this handler (the feature gate is false), so the
## keys are fully inert outside the web soak build. Uses `_unhandled_input` so
## a focused UI Control (inventory, dialogue) still consumes its own keys first.
##
## Keys (no modifier — the soak player has a free hand): `=`/`+` zoom IN by
## CAM_ZOOM_STEP; `-`/`_` zoom OUT; `0` reset to default 1.0×. Each step clamps
## to [CAM_ZOOM_MIN, CAM_ZOOM_MAX] BEFORE reaching the director so a key tap at
## the range edge doesn't spam the director's own WarningBus clamp warning.
func _unhandled_input(event: InputEvent) -> void:
	if not OS.has_feature("web"):
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			_step_cam_zoom(CAM_ZOOM_STEP)
			get_viewport().set_input_as_handled()
		KEY_MINUS, KEY_KP_SUBTRACT:
			_step_cam_zoom(-CAM_ZOOM_STEP)
			get_viewport().set_input_as_handled()
		KEY_0, KEY_KP_0:
			_set_cam_zoom(CAM_ZOOM_RESET)
			get_viewport().set_input_as_handled()
		# Char-scale dial — keys chosen to NOT collide with cam_zoom's -/+/0.
		# `[` smaller, `]` bigger, `\` reset to ship size.
		KEY_BRACKETLEFT:
			_step_char_scale(-CHAR_SCALE_STEP)
			get_viewport().set_input_as_handled()
		KEY_BRACKETRIGHT:
			_step_char_scale(CHAR_SCALE_STEP)
			get_viewport().set_input_as_handled()
		KEY_BACKSLASH:
			_set_char_scale(CHAR_SCALE_RESET)
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


## Read the `force_descend` URL query param via JavaScriptBridge on HTML5;
## no-op on desktop / headless GUT. Defaults to false (no force) when
## absent / malformed. Same HTML5-only-via-bridge shape as boss_hp_mult /
## start_room. Accepts any non-empty, non-"0", non-"false" value as truthy
## (matches the test-mode env-var convention).
func _resolve_force_descend() -> void:
	force_descend = false
	if not OS.has_feature("web"):
		return
	if not Engine.has_singleton("JavaScriptBridge"):
		return
	var bridge: Object = Engine.get_singleton("JavaScriptBridge")
	var raw_value: Variant = (
		bridge
		. eval(
			"new URLSearchParams(window.location.search).get('%s')" % FORCE_DESCEND_QUERY_PARAM,
			true,
		)
	)
	if raw_value == null:
		return
	var raw_str: String = str(raw_value).strip_edges().to_lower()
	if raw_str.is_empty() or raw_str == "null":
		return
	if raw_str == "0" or raw_str == "false":
		return
	force_descend = true


## Test-only: inject force_descend without going through the JS bridge.
func set_force_descend_for_test(enabled: bool) -> void:
	force_descend = enabled


## Test-only: reset to production default.
func reset_force_descend_for_test() -> void:
	force_descend = false


## Read the `cam_zoom` URL query param via JavaScriptBridge on HTML5; no-op on
## desktop / headless GUT. Defaults to -1.0 (no override) when absent / malformed.
## Clamps a valid float to [CAM_ZOOM_MIN, CAM_ZOOM_MAX] so an out-of-range value
## can never reach `CameraDirector.request_zoom` with a scale that trips the
## director's own WarningBus clamp on boot. Same HTML5-only-via-bridge shape as
## boss_hp_mult / start_room — desktop / headless GUT always reads the default.
##
## NOTE: this only PARSES the param into `cam_zoom`. The actual apply to the
## CameraDirector happens in `Main._ready` AFTER the room loads (so the director
## + player are wired) — mirrors how start_room / force_descend are applied from
## Main, not from DebugFlags. The director isn't necessarily up at autoload-_ready
## ordering time, so applying here would be fragile.
func _resolve_cam_zoom() -> void:
	cam_zoom = CAM_ZOOM_DEFAULT
	if not OS.has_feature("web"):
		return
	if not Engine.has_singleton("JavaScriptBridge"):
		return
	var bridge: Object = Engine.get_singleton("JavaScriptBridge")
	var raw_value: Variant = bridge.eval(
		"new URLSearchParams(window.location.search).get('%s')" % CAM_ZOOM_QUERY_PARAM, true
	)
	if raw_value == null:
		return
	var raw_str: String = str(raw_value).strip_edges()
	if raw_str.is_empty() or raw_str == "null":
		return
	if not raw_str.is_valid_float():
		push_warning("[DebugFlags] cam_zoom URL param invalid float: %s" % raw_str)
		return
	var parsed: float = raw_str.to_float()
	var clamped: float = clampf(parsed, CAM_ZOOM_MIN, CAM_ZOOM_MAX)
	cam_zoom = clamped
	if not is_equal_approx(parsed, clamped):
		push_warning(
			(
				("[DebugFlags] cam_zoom clamped from %.3f to %.3f " + "(range [%.2f..%.2f])")
				% [parsed, clamped, CAM_ZOOM_MIN, CAM_ZOOM_MAX]
			)
		)


## True iff a cam_zoom URL override was successfully parsed (>= MIN means a real
## value landed; the -1.0 default sentinel reads false). Main uses this to decide
## whether to apply the boot-time override.
func has_cam_zoom_override() -> bool:
	return cam_zoom >= CAM_ZOOM_MIN


## Set the live soak cam-zoom to an absolute NORMALIZED value, clamp it, push it
## to the CameraDirector (instant), and emit `cam_zoom_changed`. Internal — the
## key handler + reset path call this. Clamps BEFORE the director so a clamp at
## the range edge doesn't emit the director's own WarningBus warning per keypress.
func _set_cam_zoom(normalized: float) -> void:
	var clamped: float = clampf(normalized, CAM_ZOOM_MIN, CAM_ZOOM_MAX)
	cam_zoom = clamped
	_apply_cam_zoom_to_director(clamped)
	cam_zoom_changed.emit(clamped)


## Step the live soak cam-zoom by `delta` from the CURRENT director zoom (so the
## first keypress with no prior override walks from the live 1.0× default rather
## than from the -1.0 sentinel). Internal — the +/- key handler calls this.
func _step_cam_zoom(delta: float) -> void:
	var base: float = CAM_ZOOM_RESET
	var director: Node = _get_camera_director()
	if director != null and director.has_method("current_zoom"):
		base = float(director.current_zoom())
	elif cam_zoom >= CAM_ZOOM_MIN:
		base = cam_zoom
	_set_cam_zoom(base + delta)


## Push a normalized zoom to the CameraDirector instantly. No-op if the director
## isn't in the tree (headless GUT stripped contexts). Routed through the
## director's public API — never writes Camera2D.zoom directly (per camera-layer.md
## migration policy "future writers MUST route through CameraDirector").
func _apply_cam_zoom_to_director(normalized: float) -> void:
	var director: Node = _get_camera_director()
	if director != null and director.has_method("request_zoom"):
		director.request_zoom(normalized, 0.0)


func _get_camera_director() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("CameraDirector")


## Test-only: set the live cam-zoom to an absolute normalized value without the
## JS bridge / key events. Drives the full apply + emit path so GUT can assert
## the director receives the clamped value + the signal fires.
func set_cam_zoom_for_test(normalized: float) -> void:
	_set_cam_zoom(normalized)


## Test-only: step the live cam-zoom (exercises the +/- key path's clamp +
## current-zoom-base behavior without an InputEventKey).
func step_cam_zoom_for_test(delta: float) -> void:
	_step_cam_zoom(delta)


## Test-only: reset cam_zoom state to the no-override default. Does NOT touch the
## director (pair with CameraDirector.reset_to_player in the test's teardown).
func reset_cam_zoom_for_test() -> void:
	cam_zoom = CAM_ZOOM_DEFAULT


## Read the `char_scale` URL query param via JavaScriptBridge on HTML5; no-op on
## desktop / headless GUT. Defaults to -1.0 (no override) when absent / malformed.
## Clamps a valid float to [CHAR_SCALE_MIN, CHAR_SCALE_MAX] so an extreme value
## can't shrink characters to invisibility or balloon them off-screen. Same
## HTML5-only-via-bridge shape as cam_zoom — desktop / headless GUT always reads
## the default.
##
## NOTE: this only PARSES the param into `char_scale`. The actual apply to the
## live player + non-boss mobs happens in `Main` (boot apply after the room
## loads + re-apply on every room load so freshly-spawned mobs inherit the
## scale) — mirrors how cam_zoom is applied from Main, not from DebugFlags.
func _resolve_char_scale() -> void:
	char_scale = CHAR_SCALE_DEFAULT
	if not OS.has_feature("web"):
		return
	if not Engine.has_singleton("JavaScriptBridge"):
		return
	var bridge: Object = Engine.get_singleton("JavaScriptBridge")
	var raw_value: Variant = bridge.eval(
		"new URLSearchParams(window.location.search).get('%s')" % CHAR_SCALE_QUERY_PARAM, true
	)
	if raw_value == null:
		return
	var raw_str: String = str(raw_value).strip_edges()
	if raw_str.is_empty() or raw_str == "null":
		return
	if not raw_str.is_valid_float():
		push_warning("[DebugFlags] char_scale URL param invalid float: %s" % raw_str)
		return
	var parsed: float = raw_str.to_float()
	var clamped: float = clampf(parsed, CHAR_SCALE_MIN, CHAR_SCALE_MAX)
	char_scale = clamped
	if not is_equal_approx(parsed, clamped):
		push_warning(
			(
				("[DebugFlags] char_scale clamped from %.3f to %.3f " + "(range [%.2f..%.2f])")
				% [parsed, clamped, CHAR_SCALE_MIN, CHAR_SCALE_MAX]
			)
		)


## True iff a char_scale URL override was successfully parsed (>= MIN means a
## real value landed; the -1.0 default sentinel reads false). Main uses this to
## decide whether to apply the boot-time override.
func has_char_scale_override() -> bool:
	return char_scale >= CHAR_SCALE_MIN


## The NORMALIZED scale to apply to characters right now: the live override if one
## is set, else 1.0 (ship size). Main reads this on every room load so mobs
## spawned in a freshly-loaded room pick up the Sponsor's current dial value even
## when the override was set via a `[`/`]` key step rather than the URL param.
func effective_char_scale() -> float:
	if char_scale >= CHAR_SCALE_MIN:
		return char_scale
	return CHAR_SCALE_RESET


## Set the live soak char-scale to an absolute NORMALIZED value, clamp it, and
## emit `char_scale_changed` (Main re-applies to live characters + updates the
## readout). Internal — the key handler + reset path call this.
func _set_char_scale(normalized: float) -> void:
	var clamped: float = clampf(normalized, CHAR_SCALE_MIN, CHAR_SCALE_MAX)
	char_scale = clamped
	char_scale_changed.emit(clamped)


## Step the live soak char-scale by `delta` from the CURRENT value (so the first
## keypress with no prior override walks from the 1.0 ship size rather than from
## the -1.0 sentinel). Internal — the `[` / `]` key handler calls this.
func _step_char_scale(delta: float) -> void:
	var base: float = effective_char_scale()
	_set_char_scale(base + delta)


## Test-only: set the live char-scale to an absolute normalized value without the
## JS bridge / key events. Drives the full clamp + emit path so GUT can assert
## the signal fires with the clamped value.
func set_char_scale_for_test(normalized: float) -> void:
	_set_char_scale(normalized)


## Test-only: step the live char-scale (exercises the `[` / `]` key path's clamp +
## current-value-base behavior without an InputEventKey).
func step_char_scale_for_test(delta: float) -> void:
	_step_char_scale(delta)


## Test-only: reset char_scale state to the no-override default.
func reset_char_scale_for_test() -> void:
	char_scale = CHAR_SCALE_DEFAULT
