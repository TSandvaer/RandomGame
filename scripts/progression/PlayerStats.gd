extends Node
## PlayerStats autoload — single source of truth for the V/F/E character
## stats player allocates from level-up points. Sits alongside Levels.gd as
## the player-progression layer.
##
## **Why an autoload (not a node on Player)**: stats persist across run-
## death (per `team/uma-ux/death-restart-flow.md` + DECISIONS.md 2026-05-02
## "M1 death rule") — they are character-scoped, not run-scoped. Putting
## them on the Player node would mean re-reading from save into the new
## Player on every restart; an autoload owns the canonical values for the
## character's lifetime.
##
## **Stats** (per Uma's `team/uma-ux/level-up-panel.md`):
##   - vigor — toughness, health pool, stamina (mob-damage mitigation)
##   - focus — dodge, cooldowns, steady hands (M1: tracked, no derived;
##             M2 wires dodge i-frame + cooldown reduction)
##   - edge  — damage, crit, bite (player-damage scaling)
##
## **Banked points** — Uma's BI-22: pressing Esc on the level-up panel
## banks the unspent point(s). Banked points carry across save -> quit ->
## reload via the save schema.
##
## **API:**
##   PlayerStats.get_stat(stat_id)        -> int    1-stat read (vigor/focus/edge)
##   PlayerStats.add_stat(stat_id, n)     -> bool   increment by n (n>=0)
##   PlayerStats.get_unspent_points()     -> int    banked level-up points
##   PlayerStats.add_unspent_points(n)    -> void   accumulate banked points
##   PlayerStats.spend_unspent_point()    -> bool   decrement by 1 (gate)
##   PlayerStats.snapshot_to_character(d) -> Dict   serialize to save
##   PlayerStats.restore_from_character(d) -> void  deserialize from save
##   PlayerStats.reset()                  -> void   new-game / tests
##
## **Save schema (v3):** the `character.stats` block is `{vigor, focus, edge}`
## plus `character.unspent_stat_points`. v2 -> v3 migration in `Save.gd`
## backfills with defaults `{0, 0, 0}` and `unspent_stat_points = 0`.
##
## **Signals:**
##   stat_changed(stat: StringName, new_value: int)
##   unspent_points_changed(new_unspent: int)
##
## **Defaults (fresh start):** all V/F/E at 0; 0 unspent. The first level-up
## from Levels.gd grants +1 unspent (wired by the level-up panel
## controller).

# ---- Stat ID constants -------------------------------------------------

const STAT_VIGOR: StringName = &"vigor"
const STAT_FOCUS: StringName = &"focus"
const STAT_EDGE: StringName = &"edge"

const ALL_STATS: Array[StringName] = [STAT_VIGOR, STAT_FOCUS, STAT_EDGE]

# ---- Signals ----------------------------------------------------------

signal stat_changed(stat: StringName, new_value: int)
signal unspent_points_changed(new_unspent: int)

# ---- Runtime state ----------------------------------------------------

var _vigor: int = 0
var _focus: int = 0
var _edge: int = 0
var _unspent: int = 0


func _ready() -> void:
	# Smoke line so Tess can grep boot output.
	print("[PlayerStats] autoload ready (vigor=0, focus=0, edge=0)")


# ---- Public API -------------------------------------------------------

## Read a single stat. Unknown stat IDs return 0 with a warning.
func get_stat(stat_id: StringName) -> int:
	match stat_id:
		STAT_VIGOR:
			return _vigor
		STAT_FOCUS:
			return _focus
		STAT_EDGE:
			return _edge
		_:
			push_warning("PlayerStats.get_stat: unknown stat '%s'" % stat_id)
			return 0


## Increment a stat by `n`. Negative `n` is rejected (returns false; stats
## never decrement during a run). `n == 0` is a silent no-op (no signal).
## Unknown stat IDs return false with a warning. Returns true on success.
func add_stat(stat_id: StringName, n: int) -> bool:
	if n < 0:
		push_warning("PlayerStats.add_stat: negative value rejected (%d)" % n)
		return false
	if n == 0:
		return true
	match stat_id:
		STAT_VIGOR:
			_vigor += n
			stat_changed.emit(STAT_VIGOR, _vigor)
			return true
		STAT_FOCUS:
			_focus += n
			stat_changed.emit(STAT_FOCUS, _focus)
			return true
		STAT_EDGE:
			_edge += n
			stat_changed.emit(STAT_EDGE, _edge)
			return true
		_:
			push_warning("PlayerStats.add_stat: unknown stat '%s'" % stat_id)
			return false


## Banked / unspent stat points awaiting allocation. Read-only outside this
## script.
func get_unspent_points() -> int:
	return _unspent


## Add `n` unspent points to the bank. Negative `n` is rejected with a
## warning.
func add_unspent_points(n: int) -> void:
	if n <= 0:
		if n < 0:
			push_warning("PlayerStats.add_unspent_points: negative rejected (%d)" % n)
		return
	_unspent += n
	unspent_points_changed.emit(_unspent)


## Decrement the unspent bank by 1 — typically called by the panel right
## before applying the chosen stat increment. Returns false if the bank is
## empty (caller must gate `add_stat` on this).
func spend_unspent_point() -> bool:
	if _unspent <= 0:
		return false
	_unspent -= 1
	unspent_points_changed.emit(_unspent)
	return true


## Convenience snapshot for save-time. Mutates the passed `character`
## dict in place; returns it for chaining (mirrors Levels.snapshot_to_character).
##
## Output keys:
##   character["stats"] = {"vigor": int, "focus": int, "edge": int}
##   character["unspent_stat_points"] = int
func snapshot_to_character(data: Dictionary) -> Dictionary:
	data["stats"] = {
		"vigor": _vigor,
		"focus": _focus,
		"edge": _edge,
	}
	data["unspent_stat_points"] = _unspent
	return data


## Load state from a save's `character` block. Tolerates missing or
## malformed sub-fields (defaults to 0). Does NOT emit signals — pure
## deserialization, mirrors Levels.set_state().
func restore_from_character(data: Dictionary) -> void:
	var stats_block: Variant = data.get("stats", {})
	if stats_block is Dictionary:
		_vigor = max(0, int(stats_block.get("vigor", 0)))
		_focus = max(0, int(stats_block.get("focus", 0)))
		_edge = max(0, int(stats_block.get("edge", 0)))
	else:
		_vigor = 0
		_focus = 0
		_edge = 0
	_unspent = max(0, int(data.get("unspent_stat_points", 0)))


## Reset to a fresh 0/0/0 + 0 unspent. Used by new-game flow and tests.
## Does not emit signals (matches Levels.reset()).
func reset() -> void:
	_vigor = 0
	_focus = 0
	_edge = 0
	_unspent = 0
