extends Node
## StratumProgression autoload — tracks which rooms in the current run have
## been cleared. Persists across save/load via the `Save` autoload's
## `data["stratum_progression"]` dictionary; resets on player death; carries
## forward on stratum descend.
##
## Design: minimal POC for M1 — the only thing we need to record is "has
## this room been cleared in the current run?" so:
##   - Re-entering a room doesn't re-spawn its mobs (handled by the room
##     script consulting `is_cleared(room_id)`).
##   - The Sponsor's stratum-1 RC build can show progress in QA logs.
##   - Save/load round-trips correctly across quit-relaunch (M1 AC6).
##
## Not in M1 scope (deliberate): per-run timestamps, per-mob kill counts,
## seed snapshots. Add in M2 if any of those become observable.
##
## API:
##   StratumProgression.mark_cleared(room_id: StringName) -> void
##   StratumProgression.is_cleared(room_id: StringName) -> bool
##   StratumProgression.cleared_count() -> int
##   StratumProgression.cleared_room_ids() -> Array[StringName]
##   StratumProgression.reset() -> void          # called on player death
##   StratumProgression.preserve_for_descend()   # no-op (carries forward)
##   StratumProgression.snapshot_to_save_data(data: Dictionary) -> void
##   StratumProgression.restore_from_save_data(data: Dictionary) -> void
##
## Signals:
##   room_cleared(room_id: StringName)
##   progression_reset()

# ---- Signals --------------------------------------------------------

signal room_cleared(room_id: StringName)
signal progression_reset()

# ---- State ----------------------------------------------------------

# StringName -> bool. We use a Dictionary instead of a Set (Godot has none)
# and treat `true` as "cleared". Absence == not-yet-cleared.
var _cleared: Dictionary = {}


# ---- Public API -----------------------------------------------------

func mark_cleared(room_id: StringName) -> void:
	if room_id == &"":
		push_warning("StratumProgression.mark_cleared: empty room_id rejected")
		return
	if _cleared.get(room_id, false):
		# Idempotent; don't re-emit if already cleared this run.
		return
	_cleared[room_id] = true
	room_cleared.emit(room_id)


func is_cleared(room_id: StringName) -> bool:
	return _cleared.get(room_id, false)


func cleared_count() -> int:
	return _cleared.size()


func cleared_room_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: Variant in _cleared.keys():
		out.append(StringName(k))
	return out


## Wipe progression (called on player death — death loses run progress per
## M1 mvp-scope.md). Emits `progression_reset`.
func reset() -> void:
	if _cleared.is_empty():
		# Still emit so listeners can refresh UI. Reset is rare so an extra
		# emit is cheap; the alternative (silent no-op) is more confusing.
		progression_reset.emit()
		return
	_cleared.clear()
	progression_reset.emit()


## Marker for code clarity — descending to the next stratum keeps room
## clears (in case the player back-tracks via stairs in M2). M1 has only
## one stratum so this is a no-op today, but the call site documents intent.
func preserve_for_descend() -> void:
	pass


# ---- Save integration ----------------------------------------------

## Write progression state into the save payload's
## `data["stratum_progression"]` slot. The shape is a simple list of
## StringName-as-string keys so JSON survives the round-trip.
##
## Save schema doesn't yet declare this slot — until it does, we tuck it
## under `data["stratum_progression"]` and load only fires off it. When
## the schema bumps to add it formally, this call still works because
## Dictionary.get() returns {} on miss.
func snapshot_to_save_data(data: Dictionary) -> void:
	if data == null:
		return
	var room_ids: Array[String] = []
	for k: Variant in _cleared.keys():
		# Persist as String so JSON is human-friendly (StringName serializes
		# as String in Godot's JSON anyway, but being explicit is clearer
		# for the save-format doc).
		room_ids.append(String(k))
	data["stratum_progression"] = {
		"cleared_rooms": room_ids,
	}


## Read progression state back from a loaded save payload. Tolerant of
## missing keys (older saves) — defaults to empty progression.
func restore_from_save_data(data: Dictionary) -> void:
	_cleared.clear()
	if data == null:
		return
	var sub: Variant = data.get("stratum_progression", {})
	if not (sub is Dictionary):
		return
	var rooms: Variant = (sub as Dictionary).get("cleared_rooms", [])
	if not (rooms is Array):
		return
	for r: Variant in rooms:
		var sn: StringName = StringName(String(r))
		if sn != &"":
			_cleared[sn] = true
