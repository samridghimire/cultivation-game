extends Node
## Reads and writes save files as JSON under user://saves/, one file per slot.
## Each save carries a small "meta" block so the Load screen can list slots
## without loading them.
## Bump SAVE_VERSION and add a migration in _migrate() whenever the save
## format changes in a way old saves can't load.

const SAVE_DIR := "user://saves"
const SAVE_VERSION := 1
const DEFAULT_SLOT := "slot1"
const AUTOSAVE_SLOT := "autosave"

## GameClock.total_days of the last autosave; -1 = none yet this run.
var _last_autosave_day := -1
## The slot last saved to or loaded from; a final death overwrites it (REL-002).
var current_slot := ""


func save_path(slot: String) -> String:
	return SAVE_DIR.path_join(slot + ".json")


func has_save(slot: String = DEFAULT_SLOT) -> bool:
	return is_valid_slot_name(slot) and FileAccess.file_exists(save_path(slot))


## Slot names become file names, so only letters, digits, '_' and '-' are allowed.
func is_valid_slot_name(slot: String) -> bool:
	if slot.is_empty() or slot.length() > 64:
		return false
	for ch in slot:
		if not (ch == "_" or ch == "-" or (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9")):
			return false
	return true


## Every save on disk, newest first:
## [{slot, name, realm_label, game_date, age, alive, saved_at, saved_unix}].
## Corrupt files are skipped.
func list_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for file_name in DirAccess.get_files_at(SAVE_DIR):
		if not file_name.ends_with(".json"):
			continue
		var slot := file_name.get_basename()
		var meta := read_meta(slot)
		if not meta.is_empty():
			slots.append(meta)
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["saved_unix"] > b["saved_unix"])
	return slots


## Metadata for one slot (see list_slots), or {} if missing or corrupt.
func read_meta(slot: String) -> Dictionary:
	if not has_save(slot):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path(slot)))
	if not parsed is Dictionary:
		return {}
	var meta: Dictionary = parsed.get("meta", {})
	if meta.is_empty():
		meta = _meta_from_game(parsed.get("game", {}))  # saves from before metadata existed
	meta = meta.duplicate()
	meta["slot"] = slot
	meta["saved_at"] = String(parsed.get("saved_at", ""))
	meta["saved_unix"] = int(parsed.get("saved_unix", 0))
	return meta


## The newest save's slot name, or "" if there are no saves.
func most_recent_slot() -> String:
	var slots := list_slots()
	return "" if slots.is_empty() else String(slots[0]["slot"])


## The newest save with a living character, or "" (what Continue loads).
func most_recent_living_slot() -> String:
	for meta in list_slots():
		if bool(meta.get("alive", true)):
			return String(meta["slot"])
	return ""


## First unused name of the form "slotN", for a "New save" button.
func next_free_slot() -> String:
	var n := 1
	while has_save("slot%d" % n):
		n += 1
	return "slot%d" % n


func delete_save(slot: String) -> bool:
	if not has_save(slot):
		return false
	return DirAccess.remove_absolute(save_path(slot)) == OK


func save_game(slot: String = DEFAULT_SLOT) -> bool:
	if not GameState.has_session() or not is_valid_slot_name(slot):
		return false
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var game := GameState.to_save_dict()
	var payload := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"saved_unix": int(Time.get_unix_time_from_system()),
		"meta": _meta_from_game(game),
		"game": game,
	}
	var file := FileAccess.open(save_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("Could not write save %s: %s" % [slot, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	current_slot = slot
	return true


## Silent save to the autosave slot. Skipped when the setting is off, the player
## is dead, an encounter is pending, or it already ran today (unless `force`,
## used when the window closes). Returns whether it saved.
func autosave(force: bool = false) -> bool:
	if not GameState.has_session() or not GameState.player.alive:
		return false
	if not bool(Settings.get_value("autosave")) or GameState.pending_encounter != "":
		return false
	if not force and _last_autosave_day == GameClock.total_days:
		return false
	var keep := current_slot
	var saved := save_game(AUTOSAVE_SLOT)
	current_slot = keep
	if not saved:
		return false
	_last_autosave_day = GameClock.total_days
	return true


## The player died for good: overwrite the slot being played (and the autosave,
## if there is one) with the dead character, so reloading can't undo the death.
func record_final_death() -> void:
	if not GameState.has_session() or GameState.player.alive:
		return
	var slots: Array[String] = []
	if current_slot != "":
		slots.append(current_slot)
	if has_save(AUTOSAVE_SLOT) and not slots.has(AUTOSAVE_SLOT):
		slots.append(AUTOSAVE_SLOT)
	var keep := current_slot
	for slot in slots:
		save_game(slot)
	current_slot = keep


## Whether the slot holds a living character (a fallen one can't be loaded).
func is_loadable(slot: String) -> bool:
	var meta := read_meta(slot)
	return not meta.is_empty() and bool(meta.get("alive", true))


func load_game(slot: String = DEFAULT_SLOT) -> bool:
	if not has_save(slot):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path(slot)))
	if not parsed is Dictionary:
		push_error("Save %s is corrupt" % slot)
		return false
	if not is_loadable(slot):
		return false
	var payload := _migrate(parsed)
	GameState.load_save_dict(payload.get("game", {}))
	current_slot = slot
	return true


func _meta_from_game(game: Dictionary) -> Dictionary:
	var c := CharacterData.from_dict(game.get("player", {}))
	var realm_label := ""
	if GameState.data != null and c.realm_index < GameState.data.realms.size():
		realm_label = Cultivation.realm_label(c, GameState.data)
	return {
		"name": c.name,
		"realm_label": realm_label,
		"game_date": Calendar.format_date(int(game.get("clock", {}).get("total_days", 0))),
		"age": c.age_years(),
		"alive": c.alive,
	}


func _migrate(payload: Dictionary) -> Dictionary:
	# Example for the future:
	# if int(payload.get("version", 1)) < 2: ...upgrade...; payload["version"] = 2
	return payload
