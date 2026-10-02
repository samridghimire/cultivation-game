extends Node
## Reads and writes save files as JSON under user://saves/.
## Bump SAVE_VERSION and add a migration in _migrate() whenever the save
## format changes in a way old saves can't load.

const SAVE_DIR := "user://saves"
const SAVE_VERSION := 1
const DEFAULT_SLOT := "slot1"


func save_path(slot: String) -> String:
	return SAVE_DIR.path_join(slot + ".json")


func has_save(slot: String = DEFAULT_SLOT) -> bool:
	return FileAccess.file_exists(save_path(slot))


func save_game(slot: String = DEFAULT_SLOT) -> bool:
	if not GameState.has_session():
		return false
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var payload := {"version": SAVE_VERSION, "saved_at": Time.get_datetime_string_from_system(), "game": GameState.to_save_dict()}
	var file := FileAccess.open(save_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("Could not write save %s: %s" % [slot, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	return true


func load_game(slot: String = DEFAULT_SLOT) -> bool:
	if not has_save(slot):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path(slot)))
	if not parsed is Dictionary:
		push_error("Save %s is corrupt" % slot)
		return false
	var payload := _migrate(parsed)
	GameState.load_save_dict(payload.get("game", {}))
	return true


func _migrate(payload: Dictionary) -> Dictionary:
	# Example for the future:
	# if int(payload.get("version", 1)) < 2: ...upgrade...; payload["version"] = 2
	return payload
