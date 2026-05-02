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
## **Affix modifiers** (added 2026-05-02 by Drew, ticket `86c9kxx5p`):
##   Equipped items can apply temporary stat modifiers (ADD or MUL) on top of
##   the base allocated stats. `get_stat()` returns the modified value;
##   `get_base_stat()` returns the pre-modifier value. Modifiers are tracked
##   as running totals — apply to add, clear with the same arguments to
##   reverse. Each Player.equip_item / unequip_item call walks the item's
##   rolled affixes and pumps them through this API.
##
##   Math (matches `team/drew-dev/affix-application.md`):
##     effective = max(0, base + add_sum) * (1.0 + mul_sum)
##     int_effective = int(floor(effective))
##
##   ADD modifiers stack additively, MUL modifiers stack additively-then-
##   applied (NOT multiplicatively-stacking) — `(1 + 0.05) * (1 + 0.05)` is
##   1.1025, but `(1 + 0.10)` is 1.10. We use the latter to keep tooltip
##   math predictable in M1; multiplicative stacking is a balance-pass call.
##
## **API:**
##   PlayerStats.get_stat(stat_id)        -> int    1-stat read (V/F/E), modified
##   PlayerStats.get_base_stat(stat_id)   -> int    pre-modifier read
##   PlayerStats.add_stat(stat_id, n)     -> bool   increment base by n (n>=0)
##   PlayerStats.get_unspent_points()     -> int    banked level-up points
##   PlayerStats.add_unspent_points(n)    -> void   accumulate banked points
##   PlayerStats.spend_unspent_point()    -> bool   decrement by 1 (gate)
##   PlayerStats.apply_affix_modifier(stat_id, value, mode) -> bool  add modifier
##   PlayerStats.clear_affix_modifier(stat_id, value, mode) -> bool  reverse
##   PlayerStats.snapshot_to_character(d) -> Dict   serialize to save
##   PlayerStats.restore_from_character(d) -> void  deserialize from save
##   PlayerStats.reset()                  -> void   new-game / tests
##
## **Save schema (v3):** the `character.stats` block is `{vigor, focus, edge}`
## plus `character.unspent_stat_points`. v2 -> v3 migration in `Save.gd`
## backfills with defaults `{0, 0, 0}` and `unspent_stat_points = 0`.
## Affix modifiers are NOT persisted — they're re-derived on load from the
## equipped items' rolled affixes.
##
## **Signals:**
##   stat_changed(stat: StringName, new_value: int)         -- effective value
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

# Apply-mode tags. Match AffixDef.ApplyMode enum integer values
# (0 = ADD, 1 = MUL) so callers can pass the enum directly.
const MODE_ADD: int = 0
const MODE_MUL: int = 1

# ---- Signals ----------------------------------------------------------

signal stat_changed(stat: StringName, new_value: int)
signal unspent_points_changed(new_unspent: int)

# ---- Runtime state ----------------------------------------------------

var _vigor: int = 0
var _focus: int = 0
var _edge: int = 0
var _unspent: int = 0

# Per-stat affix modifier accumulators. Keyed by stat StringName. Reset on
# `reset()` and on `restore_from_character` (load path re-applies via
# the equipment system).
var _add_modifiers: Dictionary = {
	STAT_VIGOR: 0.0,
	STAT_FOCUS: 0.0,
	STAT_EDGE: 0.0,
}
var _mul_modifiers: Dictionary = {
	STAT_VIGOR: 0.0,
	STAT_FOCUS: 0.0,
	STAT_EDGE: 0.0,
}


func _ready() -> void:
	# Smoke line so Tess can grep boot output.
	print("[PlayerStats] autoload ready (vigor=0, focus=0, edge=0)")


# ---- Public API -------------------------------------------------------

## Read a single stat with affix modifiers applied. Unknown stat IDs return
## 0 with a warning.
##
## Effective formula (per affix-application.md):
##   effective = max(0, base + add_sum) * (1.0 + mul_sum)
##   int_effective = int(floor(effective))
func get_stat(stat_id: StringName) -> int:
	if not _add_modifiers.has(stat_id):
		push_warning("PlayerStats.get_stat: unknown stat '%s'" % stat_id)
		return 0
	var base: int = _get_base_internal(stat_id)
	var add_sum: float = float(_add_modifiers[stat_id])
	var mul_sum: float = float(_mul_modifiers[stat_id])
	var effective: float = max(0.0, float(base) + add_sum) * (1.0 + mul_sum)
	return int(floor(max(0.0, effective)))


## Read a stat's base value (pre-affix-modifier). Used by save serialization
## and the stat-allocation panel which displays allocated points.
func get_base_stat(stat_id: StringName) -> int:
	if not _add_modifiers.has(stat_id):
		push_warning("PlayerStats.get_base_stat: unknown stat '%s'" % stat_id)
		return 0
	return _get_base_internal(stat_id)


## Increment a stat's *base* by `n`. Negative `n` is rejected (returns
## false; stats never decrement during a run). `n == 0` is a silent no-op
## (no signal). Unknown stat IDs return false with a warning. Returns true
## on success. Emits `stat_changed` with the *effective* value (base +
## modifiers) so HUD listeners see the same number tooltip-side.
func add_stat(stat_id: StringName, n: int) -> bool:
	if n < 0:
		push_warning("PlayerStats.add_stat: negative value rejected (%d)" % n)
		return false
	if n == 0:
		return true
	match stat_id:
		STAT_VIGOR:
			_vigor += n
		STAT_FOCUS:
			_focus += n
		STAT_EDGE:
			_edge += n
		_:
			push_warning("PlayerStats.add_stat: unknown stat '%s'" % stat_id)
			return false
	stat_changed.emit(stat_id, get_stat(stat_id))
	return true


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


# ---- Affix modifier API -----------------------------------------------

## Apply an affix-driven modifier to a stat. `mode` is `MODE_ADD` (0) or
## `MODE_MUL` (1) — matches `AffixDef.ApplyMode`. Returns true on success;
## false if the stat is unknown or the mode is unrecognised.
##
## The modifier is added to a running per-stat sum. Clear with the same
## arguments to reverse exactly. ADD: stat += value. MUL: stat *= (1 +
## value). Negative values are accepted (M2 debuff support).
##
## Emits `stat_changed` with the new effective value so HUD/Damage chain
## reads the modified stat next tick.
func apply_affix_modifier(stat_id: StringName, value: float, mode: int) -> bool:
	if not _add_modifiers.has(stat_id):
		push_warning("PlayerStats.apply_affix_modifier: unknown stat '%s'" % stat_id)
		return false
	match mode:
		MODE_ADD:
			_add_modifiers[stat_id] = float(_add_modifiers[stat_id]) + value
		MODE_MUL:
			_mul_modifiers[stat_id] = float(_mul_modifiers[stat_id]) + value
		_:
			push_warning("PlayerStats.apply_affix_modifier: unknown mode %d" % mode)
			return false
	stat_changed.emit(stat_id, get_stat(stat_id))
	return true


## Reverse a previously-applied modifier. Pass the same `value` and `mode`
## that were applied; the running sum is decremented. Returns true on
## success.
##
## Idempotency note: callers (Player.unequip_item) must track which
## modifiers they applied. Pumping clear without a matching apply will
## decrement past zero — that's a caller bug, but we don't refuse it
## (clamping would mask the bug; a negative-trending stat surfaces it
## visibly in tests / HUD).
func clear_affix_modifier(stat_id: StringName, value: float, mode: int) -> bool:
	if not _add_modifiers.has(stat_id):
		push_warning("PlayerStats.clear_affix_modifier: unknown stat '%s'" % stat_id)
		return false
	match mode:
		MODE_ADD:
			_add_modifiers[stat_id] = float(_add_modifiers[stat_id]) - value
		MODE_MUL:
			_mul_modifiers[stat_id] = float(_mul_modifiers[stat_id]) - value
		_:
			push_warning("PlayerStats.clear_affix_modifier: unknown mode %d" % mode)
			return false
	stat_changed.emit(stat_id, get_stat(stat_id))
	return true


## Returns the current ADD-modifier accumulator for a stat (sum of all
## active ADD-mode affix contributions). For tests + HUD diagnostics.
func get_add_modifier(stat_id: StringName) -> float:
	if not _add_modifiers.has(stat_id):
		return 0.0
	return float(_add_modifiers[stat_id])


## Returns the current MUL-modifier accumulator for a stat. Tests + HUD.
func get_mul_modifier(stat_id: StringName) -> float:
	if not _mul_modifiers.has(stat_id):
		return 0.0
	return float(_mul_modifiers[stat_id])


# ---- Save / load ------------------------------------------------------

## Convenience snapshot for save-time. Mutates the passed `character`
## dict in place; returns it for chaining (mirrors Levels.snapshot_to_character).
##
## Saves base values only — affix modifiers are derived from equipped
## items on load and applied by the equipment system.
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
## deserialization, mirrors Levels.set_state(). Clears any in-flight affix
## modifiers (the equipment system re-applies on load).
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
	_clear_all_modifiers()


## Reset to a fresh 0/0/0 + 0 unspent. Used by new-game flow and tests.
## Does not emit signals (matches Levels.reset()). Also clears affix
## modifiers.
func reset() -> void:
	_vigor = 0
	_focus = 0
	_edge = 0
	_unspent = 0
	_clear_all_modifiers()


# ---- Internal ---------------------------------------------------------

func _get_base_internal(stat_id: StringName) -> int:
	match stat_id:
		STAT_VIGOR:
			return _vigor
		STAT_FOCUS:
			return _focus
		STAT_EDGE:
			return _edge
		_:
			return 0


func _clear_all_modifiers() -> void:
	for k in _add_modifiers.keys():
		_add_modifiers[k] = 0.0
	for k in _mul_modifiers.keys():
		_mul_modifiers[k] = 0.0
