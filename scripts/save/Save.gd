extends Node
## Save autoload — JSON-backed save/load.
##
## Stub implementation. Full schema and round-trip live in `team/devon-dev/save-format.md`
## and are filled in by week-1 task #6. Registered as an autoload in project.godot so
## scripts can call `Save.save_game(slot)` / `Save.load_game(slot)` from anywhere.

const SAVE_DIR: String = "user://"
const SAVE_FILE_FMT: String = "save_%d.json"
const SCHEMA_VERSION: int = 1


func _ready() -> void:
	print("[Save] autoload ready (stub — full impl in week-1 task #6)")


func _save_path(slot: int) -> String:
	return SAVE_DIR + (SAVE_FILE_FMT % slot)


func save_game(slot: int = 0) -> bool:
	# Stub: full implementation in task #6.
	push_warning("Save.save_game(%d): stub — not yet implemented" % slot)
	return false


func load_game(slot: int = 0) -> Dictionary:
	# Stub: full implementation in task #6.
	push_warning("Save.load_game(%d): stub — not yet implemented" % slot)
	return {}


func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(_save_path(slot))


func delete_save(slot: int = 0) -> bool:
	var path: String = _save_path(slot)
	if not FileAccess.file_exists(path):
		return false
	var err: int = DirAccess.remove_absolute(path)
	return err == OK
