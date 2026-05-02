extends Node
## Levels autoload — XP curve + level-up state machine for M1 character
## progression (level 1 -> 5 cap per `team/priya-pl/mvp-scope.md`).
##
## **Curve formula:** `xp_to_next(level) = floor(BASE_XP * level^EXP)` for
## `level in [1, MAX_LEVEL - 1]`. With `BASE_XP=100, EXP=1.5`:
##
##   L1 -> L2:  100  XP
##   L2 -> L3:  282  XP
##   L3 -> L4:  519  XP
##   L4 -> L5:  800  XP
##   ----------------
##   Total to cap: 1701 XP. Grunt yields xp_reward=10, so ~170 grunts to
##   cap. With DebugFlags.FAST_XP_MULTIPLIER=100 (debug only), ~1.7 grunts
##   to cap — Tess can reach L5 in well under 2 minutes per the testability
##   hook.
##
## **Why this shape (Decision logged in DECISIONS.md 2026-05-02):**
##   - Quadratic-ish (x^1.5) gives a noticeable but not punishing climb.
##     Pure linear feels grindy at the top; pure quadratic (x^2) makes L5
##     feel out of reach in M1's tiny content footprint (1 stratum, 1 mob).
##   - `BASE_XP=100` matches Drew's grunt `xp_reward=10` so L1->L2 is
##     ~10 grunts — fast enough to feel the loop in M1 playtests.
##   - MAX_LEVEL=5 mirrors the M1 cap from mvp-scope.md.
##
## **Affects:** Drew (combat balance — boss DPS targets keyed off the
## per-level player stat budget the level-up grants), Tess (acceptance
## tests against the curve), Save schema (v2 adds `xp_to_next` to character).
##
## **API:**
##   Levels.gain_xp(amount)       -> void   add XP, fires xp_gained / level_up
##   Levels.current_level()       -> int    1..MAX_LEVEL
##   Levels.current_xp()          -> int    XP into current level
##   Levels.xp_to_next()          -> int    XP needed to finish current level
##                                          (returns 0 if already at MAX_LEVEL)
##   Levels.xp_required_for(L)    -> int    static curve: L -> L+1 cost
##   Levels.set_state(level, xp)  -> void   load-from-save entry point
##   Levels.snapshot_to_save_data(d) -> Dict  write state into a save dict
##   Levels.reset()               -> void   tests + new-game flow
##
## **Signals:**
##   xp_gained(amount: int)
##   level_up(new_level: int)             — fires once per level boundary, so
##                                           a single gain_xp() call that
##                                           crosses two boundaries fires
##                                           level_up twice (carries overflow).

const MAX_LEVEL: int = 5
const MIN_LEVEL: int = 1

# Curve tunables. If you change either, update DECISIONS.md and re-run
# the table assertion in tests/test_levels.gd.
const BASE_XP: int = 100
const EXP_POWER: float = 1.5

# ---- Signals ----------------------------------------------------------

signal xp_gained(amount: int)
signal level_up(new_level: int)

# ---- Runtime state ----------------------------------------------------

var _level: int = MIN_LEVEL
var _xp: int = 0  # XP accumulated INTO the current level (resets on each
                  # level_up — overflow carries via the loop in gain_xp).


func _ready() -> void:
	# Single boot-time line so Tess can grep the smoke log.
	print("[Levels] autoload ready (curve=%d*L^%.2f, max_level=%d)" % [
		BASE_XP,
		EXP_POWER,
		MAX_LEVEL,
	])


# ---- Public API -------------------------------------------------------

## XP needed to advance from `level` to `level + 1`. Pure function — no
## runtime state. Returns 0 for `level >= MAX_LEVEL` (no further levels).
## Negative or zero levels are clamped to MIN_LEVEL for robustness.
##
## Not declared `static` because callers use the autoload instance (e.g.
## `Levels.xp_required_for(2)`) and GDScript 4.3's static-via-instance
## resolution behaves differently across editor / headless builds. Keeping
## it as an instance method is the simplest contract for both call sites.
func xp_required_for(level: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	var clean_level: int = max(MIN_LEVEL, level)
	return int(floor(float(BASE_XP) * pow(float(clean_level), EXP_POWER)))


func current_level() -> int:
	return _level


func current_xp() -> int:
	return _xp


## Returns XP needed to complete the current level. 0 at MAX_LEVEL.
func xp_to_next() -> int:
	return xp_required_for(_level)


## Apply an XP gain. Triggers `xp_gained` once (with the actual amount
## added — multiplier-applied), then `level_up` once per boundary crossed.
##
## Edge cases:
##   - `amount <= 0` is rejected (no-op, no signals fired). We don't want
##     accidental negative XP from a bug becoming a "level down".
##   - At MAX_LEVEL, XP is clamped — the gain is accepted but no XP is
##     stored and no signals fire. Callers can detect via current_level()
##     before calling.
##   - DebugFlags.fast_xp multiplier is applied here, ONCE, at the entry
##     point. This is the canonical place — gameplay code calls
##     `Levels.gain_xp(mob_def.xp_reward)` and the multiplier is applied
##     by Levels, not by the caller. (Single source of truth.)
##
## Multi-level overflow: a large gain that crosses two boundaries (e.g.
## gain 1000 XP at L1 with 100 needed for L2 and 282 needed for L3) ends
## with L3 and 618 XP into L3. `level_up` fires twice (once per boundary).
func gain_xp(amount: int) -> void:
	if amount <= 0:
		# Reject zero and negative — no signal, no state change.
		return
	if _level >= MAX_LEVEL:
		# At cap: the design says XP can't accumulate past max. Silent
		# clamp — call sites can detect via current_level() if they want
		# to gate on it.
		return

	# Apply the debug multiplier exactly once. DebugFlags is an autoload;
	# guard against the unlikely case where it isn't registered (tests
	# might construct Levels in isolation).
	var multiplier: int = 1
	var debug_flags_node: Node = _debug_flags()
	if debug_flags_node != null and debug_flags_node.has_method("xp_multiplier"):
		multiplier = int(debug_flags_node.xp_multiplier())
	var effective: int = amount * max(1, multiplier)

	xp_gained.emit(effective)

	_xp += effective
	# Drain XP across boundaries; emit level_up once per crossed level.
	while _level < MAX_LEVEL and _xp >= xp_required_for(_level):
		_xp -= xp_required_for(_level)
		_level += 1
		level_up.emit(_level)
	# If we just hit MAX_LEVEL, drop any leftover XP — there's nothing to
	# spend it on. Saves serialize cleanly with xp=0 at cap.
	if _level >= MAX_LEVEL:
		_xp = 0


## Load state from a save payload. Tolerates clamps:
##   - level outside [MIN_LEVEL, MAX_LEVEL] is clamped.
##   - xp outside [0, xp_to_next) is clamped (negative -> 0; over-cap ->
##     just below the boundary so we don't silently auto-level-up on load).
## Does NOT emit level_up — pure deserialization.
func set_state(level: int, xp: int) -> void:
	_level = clamp(level, MIN_LEVEL, MAX_LEVEL)
	if _level >= MAX_LEVEL:
		_xp = 0
	else:
		var ceiling: int = xp_required_for(_level)
		# Strict less-than the boundary so we don't silently auto-level-up.
		# If a save somehow contains xp == ceiling, we treat it as 0 of the
		# next level — but that level transition should already have
		# happened at save-time, so this is a defensive corner.
		_xp = clamp(xp, 0, max(0, ceiling - 1))


## Mutates `data` (a save payload's `character` block) in place to reflect
## current Levels state. Used at save time. Returns the same dict for
## chaining.
##
## Output keys:
##   data["level"]       int
##   data["xp"]          int   (XP into current level)
##   data["xp_to_next"]  int   (derived; written for HUD convenience)
func snapshot_to_character(data: Dictionary) -> Dictionary:
	data["level"] = _level
	data["xp"] = _xp
	data["xp_to_next"] = xp_to_next()
	return data


## Reset to a fresh L1 / 0 XP. New-game flow + tests use this.
func reset() -> void:
	_level = MIN_LEVEL
	_xp = 0


## Convenience: subscribe to a mob's `mob_died` signal so its `xp_reward`
## from the carried MobDef is applied to the player automatically. Spawner
## code calls this once per mob it spawns:
##
##   Levels.subscribe_to_mob(grunt)
##
## The signal binding uses CONNECT_ONE_SHOT — a mob fires `mob_died`
## exactly once per life by contract (Grunt.gd guard `_is_dead`), but
## we ask for one-shot anyway as a belt-and-braces against any future
## multi-emit bug.
##
## A null mob_def on the signal is tolerated (returns 0 XP). A negative
## or zero xp_reward is also tolerated (gain_xp early-returns).
func subscribe_to_mob(mob: Node) -> void:
	if mob == null:
		return
	if not mob.has_signal("mob_died"):
		return
	mob.connect("mob_died", _on_mob_died, CONNECT_ONE_SHOT)


## Internal: signal handler matching the Grunt.mob_died signature
##   mob_died(mob, death_position, mob_def)
## We only need mob_def for the xp_reward.
func _on_mob_died(_mob: Node, _death_position: Vector2, mob_def: Resource) -> void:
	if mob_def == null:
		return
	var reward: int = 0
	# Read xp_reward via dictionary-style access since MobDef is in another
	# file we don't preload here (avoids circular dep with content/).
	if "xp_reward" in mob_def:
		reward = int(mob_def.xp_reward)
	gain_xp(reward)


# ---- Internals ----------------------------------------------------------

func _debug_flags() -> Node:
	# Engine.get_main_loop() can be null during very early init; tolerate.
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null("DebugFlags")
