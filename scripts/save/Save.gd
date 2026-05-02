extends Node
## Save autoload — JSON-backed save/load with schema versioning and
## forward-compat migration. Highest-risk system in M1 (testing-bar
## §Devon-and-Drew), so we treat the file format as a contract:
##
##   - One JSON file per slot at `user://save_<slot>.json`.
##   - Top-level: { "schema_version": <int>, "saved_at": <iso8601 string>, "data": { ... } }
##   - `data` shape lives in `team/devon-dev/save-format.md` and migrates
##     forward via `_migrate(payload)` whenever SCHEMA_VERSION bumps.
##
## API:
##   Save.save_game(slot, data)  -> bool   write data to slot
##   Save.load_game(slot)        -> Dict    {} on miss, migrated dict on hit
##   Save.has_save(slot)         -> bool
##   Save.delete_save(slot)      -> bool
##   Save.atomic_write(path, s)  -> bool   crash-safe write helper (tmp + rename)
##
## Crash safety: writes go to `<file>.tmp` then DirAccess.rename to `<file>`,
## so a power-yank mid-write loses the *new* save but preserves the old.

const SAVE_DIR: String = "user://"
const SAVE_FILE_FMT: String = "save_%d.json"
const TMP_SUFFIX: String = ".tmp"

# Hook 3 (testability) — when save_game writes a save, also drop a one-liner
# README in the same dir explaining where saves live, the schema_version,
# and how to clear them. For Tess's manual setup per `team/tess-qa/m1-test-plan.md`
# AC3-T03 + AC6.
const README_FILENAME: String = "README.txt"
const README_PATH: String = SAVE_DIR + README_FILENAME

const SCHEMA_VERSION: int = 2

# Curve mirror used only by the v1 -> v2 migration (xp_to_next backfill).
# MUST match `scripts/progression/Levels.gd` constants of the same names.
# When Levels' curve changes, mirror it here AND bump SCHEMA_VERSION so
# saves from the old curve are explicitly migrated.
const _V2_BASE_XP: int = 100
const _V2_EXP_POWER: float = 1.5
const _V2_MAX_LEVEL: int = 5

# Default empty payload schema. Mutated by gameplay then handed back to save_game.
#
# v2 (2026-05-02): added `xp_to_next` to character so HUD has a one-shot
# read for the level-up bar. Derived from level via Levels.xp_required_for(),
# but persisting it keeps the save self-describing for tooling and future
# Levels-curve migrations.
const DEFAULT_PAYLOAD: Dictionary = {
	"character": {
		"name": "Ember-Knight",
		"level": 1,
		"xp": 0,
		"xp_to_next": 100,  # Levels.xp_required_for(1) at runtime
		"vigor": 0,
		"focus": 0,
		"edge": 0,
		"hp_current": 100,
		"hp_max": 100,
	},
	"stash": [],         # list of item dicts
	"equipped": {},      # slot -> item dict
	"meta": {
		"runs_completed": 0,
		"deepest_stratum": 1,
		"total_playtime_sec": 0.0,
	},
}


func _ready() -> void:
	# Touch a console line so Tess's smoke test can grep for it.
	print("[Save] autoload ready (schema v%d)" % SCHEMA_VERSION)


# ---- Public API ---------------------------------------------------------

func save_path(slot: int = 0) -> String:
	return SAVE_DIR + (SAVE_FILE_FMT % slot)


func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(save_path(slot))


func delete_save(slot: int = 0) -> bool:
	var path: String = save_path(slot)
	if not FileAccess.file_exists(path):
		return false
	var err: int = DirAccess.remove_absolute(path)
	return err == OK


## Save `data` (typically a deep-copy of in-memory game state) to slot.
## If `data` is empty or null, falls back to a deep-copy of DEFAULT_PAYLOAD.
## Returns true on success.
func save_game(slot: int = 0, data: Variant = null) -> bool:
	var payload_data: Dictionary = data if data is Dictionary else default_payload()
	var envelope: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true, false),
		"data": payload_data,
	}
	var json_str: String = JSON.stringify(envelope, "  ")
	var ok: bool = atomic_write(save_path(slot), json_str)
	if not ok:
		push_error("[Save] save_game(%d) failed at atomic_write" % slot)
		return false
	# Hook 3 — drop the testability README next to the save file. Idempotent;
	# overwrites a stale README on every save (cheap, single short string).
	_write_readme()
	return true


## Load slot. Returns the migrated `data` Dictionary on success, or {} on
## miss / corruption. Migration is invisible to callers — they always see
## the latest schema.
func load_game(slot: int = 0) -> Dictionary:
	var path: String = save_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[Save] load_game(%d): open failed (err %d)" % [slot, FileAccess.get_open_error()])
		return {}
	var raw: String = f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(raw)
	if parsed == null or not (parsed is Dictionary):
		push_error("[Save] load_game(%d): JSON parse failed or root not Dictionary" % slot)
		return {}
	var envelope: Dictionary = parsed
	# Defensive: missing schema_version implies pre-v1 (we shouldn't have any
	# such files in the wild, but treat as v0 -> migrate).
	var version: int = int(envelope.get("schema_version", 0))
	var data: Dictionary = envelope.get("data", {})
	if not (data is Dictionary):
		push_error("[Save] load_game(%d): envelope.data missing or wrong type" % slot)
		return {}
	return migrate(data, version)


## Returns a fresh deep-copy of the default payload. Used by new-game flow
## and as a fallback by save_game when no data is supplied.
func default_payload() -> Dictionary:
	# Manual deep-copy because Dictionary.duplicate(true) duplicates nested
	# arrays/dicts — exactly what we want.
	return DEFAULT_PAYLOAD.duplicate(true)


# ---- Crash-safe write helper -------------------------------------------

## Writes `text` to `path` atomically: write to <path>.tmp first, then
## DirAccess.rename to overwrite. A power-yank mid-write leaves the old
## file intact. Returns true on success.
func atomic_write(path: String, text: String) -> bool:
	var tmp: String = path + TMP_SUFFIX
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("[Save] atomic_write: cannot open %s (err %d)" % [tmp, FileAccess.get_open_error()])
		return false
	f.store_string(text)
	f.close()
	# DirAccess.rename overwrites the target on most platforms; if we're on a
	# platform where it doesn't (rare), explicitly remove first.
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var err: int = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_error("[Save] atomic_write: rename %s -> %s failed (err %d)" % [tmp, path, err])
		return false
	return true


# ---- Migration ----------------------------------------------------------

## Migrate `data` from `from_version` up to SCHEMA_VERSION. Each step is
## an explicit migration function. Returns the migrated dict.
##
## When schema bumps, add a new branch here AND a forward-compat test in
## tests/test_save.gd.
func migrate(data: Dictionary, from_version: int) -> Dictionary:
	if from_version > SCHEMA_VERSION:
		# Save came from a newer build. Best-effort: pass through as-is and
		# warn. Could also refuse-load and trigger a new-character flow.
		push_warning("[Save] save schema_version %d is newer than runtime %d — loading as-is" % [from_version, SCHEMA_VERSION])
		return data
	var out: Dictionary = data.duplicate(true)
	if from_version < 1:
		out = _migrate_v0_to_v1(out)
	if from_version < 2:
		out = _migrate_v1_to_v2(out)
	return out


## v0 -> v1: any pre-v1 save lacks the `meta` block. Fill from defaults.
func _migrate_v0_to_v1(data: Dictionary) -> Dictionary:
	if not data.has("meta"):
		data["meta"] = DEFAULT_PAYLOAD["meta"].duplicate(true)
	# Older saves may also lack `equipped`; backfill.
	if not data.has("equipped"):
		data["equipped"] = {}
	if not data.has("stash"):
		data["stash"] = []
	if not data.has("character"):
		data["character"] = DEFAULT_PAYLOAD["character"].duplicate(true)
	return data


## v1 -> v2: add `xp_to_next` to the character block. Derived from current
## level so a partially-leveled v1 save loads with the right ceiling
## visible in the HUD on first frame.
##
## We don't reach into the Levels autoload here (load runs before any new-
## game flow has set Levels state) — instead we re-derive the curve inline
## using the `_V2_*` constants at the top of this file (mirror of
## scripts/progression/Levels.gd).
func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
	# Defensive: a malformed v1 might have lost the character block. v0->v1
	# already backfills it from DEFAULT_PAYLOAD; if that didn't run for
	# some reason (unlikely; the migrate() chain always runs in order),
	# create it here too.
	if not data.has("character") or not (data["character"] is Dictionary):
		data["character"] = DEFAULT_PAYLOAD["character"].duplicate(true)
	var character: Dictionary = data["character"]
	if not character.has("xp_to_next"):
		var lvl: int = int(character.get("level", 1))
		character["xp_to_next"] = _v2_xp_required_for(lvl)
	# Also ensure level/xp exist (a hand-edited v1 might've stripped them).
	if not character.has("level"):
		character["level"] = 1
	if not character.has("xp"):
		character["xp"] = 0
	return data


## Curve mirror used only by the v1 -> v2 migration. See Levels.gd for the
## authoritative implementation.
static func _v2_xp_required_for(level: int) -> int:
	if level >= _V2_MAX_LEVEL:
		return 0
	var clean_level: int = max(1, level)
	return int(floor(float(_V2_BASE_XP) * pow(float(clean_level), _V2_EXP_POWER)))

# ---- Testability README -------------------------------------------------

## Writes a one-liner README to the save dir explaining where saves live,
## the schema_version, and how to clear them. Called from `save_game` after
## a successful write. Tess uses this for AC3-T03 + AC6 manual-test setup.
##
## Idempotent — re-writing on every save is cheap (string is short) and
## guarantees the schema_version line tracks the running build. Tests
## verify the README exists, mentions schema_version=N, and has a "delete"
## hint.
func _write_readme() -> void:
	var abs_path: String = ProjectSettings.globalize_path(SAVE_DIR)
	var contents: String = (
		"Embergrave save files\n"
		+ "=====================\n"
		+ "\n"
		+ "Save files: save_<slot>.json (one per slot, slot 0 is default).\n"
		+ "Location:   %s (Godot user://)\n" % abs_path
		+ "Format:     JSON, schema_version=%d (see team/devon-dev/save-format.md).\n" % SCHEMA_VERSION
		+ "\n"
		+ "To start a fresh run / clear saves:\n"
		+ "  1. Quit the game.\n"
		+ "  2. Delete save_*.json in this directory.\n"
		+ "  3. Relaunch.\n"
		+ "\n"
		+ "Do NOT delete save_*.json.tmp manually mid-write — those are crash-\n"
		+ "safe staging files used by atomic_write(). They auto-clean on the\n"
		+ "next successful save.\n"
	)
	var f: FileAccess = FileAccess.open(README_PATH, FileAccess.WRITE)
	if f == null:
		# Non-fatal: a missing README is a testability convenience, not a bug.
		push_warning("[Save] could not write README at %s (err %d)" % [README_PATH, FileAccess.get_open_error()])
		return
	f.store_string(contents)
	f.close()
