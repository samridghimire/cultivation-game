extends Node
## Reads and writes save files as JSON under user://saves/, one file per slot.
## Each save carries a small "meta" block so the Load screen can list slots
## without loading them.
## Bump SAVE_VERSION and add a migration in _migrate() whenever the save
## format changes in a way old saves can't load.

## Emitted after a successful save; the HUD shows a toast.
signal saved(slot: String, is_auto: bool)

const SAVE_DIR := "user://saves"
const SAVE_VERSION := 1
const DEFAULT_SLOT := "slot1"
const AUTOSAVE_SLOT := "autosave"

## GameClock.total_days of the last autosave; -1 = none yet this run.
var _last_autosave_day := -1
## Real-time stamp (ms) of the last suspend save; -1 = none yet.
var _last_suspend_save_msec := -1
const SUSPEND_SAVE_INTERVAL_MSEC := 60000
## The slot last saved to or loaded from; a final death overwrites it (REL-002).
var current_slot := ""
## Whether this session wrote the autosave slot (so a final death may overwrite it).
var _autosaved_this_session := false
## Simulations turn this off so balance runs never touch the player's saves.
var autosave_enabled := true


func _ready() -> void:
	EventBus.session_started.connect(_on_session_started)


## A new or loaded character: forget the previous character's slot so its death
## can't overwrite another character's save (load_game sets current_slot after).
func _on_session_started() -> void:
	current_slot = ""
	_last_autosave_day = -1
	_last_suspend_save_msec = -1
	_autosaved_this_session = false


func save_path(slot: String) -> String:
	return SAVE_DIR.path_join(slot + ".json")


## True when the slot has a save file or, after a crash mid-save, only its backup.
func has_save(slot: String = DEFAULT_SLOT) -> bool:
	if not is_valid_slot_name(slot):
		return false
	return FileAccess.file_exists(save_path(slot)) or FileAccess.file_exists(save_path(slot) + ".bak")


## The slot's main file was written by a newer build (RV-001). Such a slot is
## neither loaded, repaired from its backup, nor overwritten.
func is_newer_version(slot: String) -> bool:
	return is_valid_slot_name(slot) and _file_version(save_path(slot)) > SAVE_VERSION


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
## A slot file that can't be read (and has no backup) is listed with damaged=true.
func list_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	var seen := {}
	for file_name in DirAccess.get_files_at(SAVE_DIR):
		var slot := ""
		if file_name.ends_with(".json"):
			slot = file_name.get_basename()
		elif file_name.ends_with(".json.bak"):
			slot = file_name.trim_suffix(".json.bak")  # main lost to a crash mid-save
			if FileAccess.file_exists(save_path(slot)) or _parse_file(save_path(slot) + ".bak").is_empty():
				continue
		else:
			continue
		if seen.has(slot) or not is_valid_slot_name(slot):
			continue
		seen[slot] = true
		var meta := read_meta(slot)
		if meta.is_empty() and is_newer_version(slot):
			meta = {"slot": slot, "damaged": false, "newer_version": true, "name": slot, "saved_unix": 0, "alive": true}
		elif meta.is_empty():
			meta = {"slot": slot, "damaged": true, "name": slot, "saved_unix": 0, "alive": true}
		slots.append(meta)
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["saved_unix"] > b["saved_unix"])
	return slots


## Metadata for one slot (see list_slots), or {} if missing or corrupt.
func read_meta(slot: String) -> Dictionary:
	var parsed := _read_payload(slot)
	if parsed.is_empty():
		return {}
	var meta: Dictionary = parsed.get("meta", {})
	if meta.is_empty():
		meta = _meta_from_game(parsed.get("game", {}))  # saves from before metadata existed
	meta = meta.duplicate()
	meta["slot"] = slot
	meta["saved_at"] = String(parsed.get("saved_at", ""))
	meta["saved_unix"] = int(parsed.get("saved_unix", 0))
	if parsed.get("from_backup", false):
		meta["from_backup"] = true
	return meta


## Parses <slot>.json, falling back to <slot>.json.bak; {} if neither is usable.
## Adds "from_backup": true when the backup was used.
func _read_payload(slot: String) -> Dictionary:
	if not is_valid_slot_name(slot):
		return {}
	var main := _parse_file(save_path(slot))
	if not main.is_empty():
		return main
	if is_newer_version(slot):
		return {}  # never fall back to an older backup under a newer save
	var backup := _parse_file(save_path(slot) + ".bak")
	if not backup.is_empty():
		backup["from_backup"] = true
	return backup


## The "version" of a parseable save file, or 0 if missing or unreadable.
func _file_version(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return 0
	var parsed: Variant = json.data
	if parsed is Dictionary and (parsed as Dictionary).has("game"):
		return int((parsed as Dictionary).get("version", 1))
	return 0


func _parse_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()  # parse() reports errors quietly, unlike parse_string
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var parsed: Variant = json.data
	if parsed is Dictionary and (parsed as Dictionary).has("game"):
		if int((parsed as Dictionary).get("version", 1)) > SAVE_VERSION:
			return {}  # written by a newer build; loading it could corrupt it
		return parsed
	return {}


## The newest save's slot name, or "" if there are no saves.
func most_recent_slot() -> String:
	var slots := list_slots()
	return "" if slots.is_empty() else String(slots[0]["slot"])


## The newest save with a living character, or "" (what Continue loads).
func most_recent_living_slot() -> String:
	for meta in list_slots():
		if bool(meta.get("alive", true)) and not bool(meta.get("damaged", false)) and not bool(meta.get("newer_version", false)):
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
	for extra in [".bak", ".tmp"]:
		if FileAccess.file_exists(save_path(slot) + extra):
			DirAccess.remove_absolute(save_path(slot) + extra)
	if not FileAccess.file_exists(save_path(slot)):
		return true  # only the backup was left
	return DirAccess.remove_absolute(save_path(slot)) == OK


func save_game(slot: String = DEFAULT_SLOT, is_auto: bool = false) -> bool:
	if not GameState.has_session() or not is_valid_slot_name(slot):
		return false
	if is_newer_version(slot):
		push_warning("Save %s was made by a newer version; not overwriting it" % slot)
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
	if not _write_atomic(save_path(slot), JSON.stringify(payload, "\t")):
		push_error("Could not write save %s" % slot)
		return false
	current_slot = slot
	saved.emit(slot, is_auto)
	return true


## Writes to <path>.tmp, copies the previous file to <path>.bak, then renames the
## .tmp over it, so a crash mid-write never destroys the existing save.
func _write_atomic(path: String, text: String) -> bool:
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	var ok := file.get_error() == OK
	file.close()
	if not ok:
		DirAccess.remove_absolute(tmp)
		return false
	if FileAccess.file_exists(path):
		var bak := path + ".bak"
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		# Copy (not rename) so the main file never vanishes between the two steps.
		if DirAccess.copy_absolute(path, bak) != OK:
			DirAccess.remove_absolute(tmp)
			return false
	if DirAccess.rename_absolute(tmp, path) != OK:
		DirAccess.remove_absolute(tmp)
		return false
	return true


## Silent save to the autosave slot. Skipped when the setting is off, the player
## is dead, an encounter is pending, or it already ran today (unless `force`,
## used when the window closes). Returns whether it saved.
func autosave(force: bool = false) -> bool:
	if not autosave_enabled or not GameState.has_session() or not GameState.player.alive:
		return false
	if not bool(Settings.get_value("autosave")) or GameState.pending_encounter != "":
		return false
	if not force and _last_autosave_day == GameClock.total_days:
		return false
	var keep := current_slot
	var ok := save_game(AUTOSAVE_SLOT, true)
	current_slot = keep
	if not ok:
		return false
	_last_autosave_day = GameClock.total_days
	_autosaved_this_session = true
	return true


## The app was suspended or lost focus (Steam Deck sleep, alt-tab): force an
## autosave, at most once per 60 s of real time. Returns true if it saved.
func autosave_on_suspend() -> bool:
	var now := Time.get_ticks_msec()
	if _last_suspend_save_msec >= 0 and now - _last_suspend_save_msec < SUSPEND_SAVE_INTERVAL_MSEC:
		return false
	if not autosave(true):
		return false
	_last_suspend_save_msec = now
	return true


## The player died for good: overwrite the slot being played (and the autosave,
## if there is one) with the dead character, so reloading can't undo the death.
func record_final_death() -> void:
	if not GameState.has_session() or GameState.player.alive:
		return
	var slots: Array[String] = []
	if current_slot != "":
		slots.append(current_slot)
	if _autosave_is_ours() and not slots.has(AUTOSAVE_SLOT):
		slots.append(AUTOSAVE_SLOT)
	var keep := current_slot
	for slot in slots:
		save_game(slot)
	current_slot = keep


## The autosave slot holds this character: written this session, or saved under
## the same name (an older run of the character loaded from another slot).
func _autosave_is_ours() -> bool:
	if not has_save(AUTOSAVE_SLOT):
		return false
	return _autosaved_this_session or String(read_meta(AUTOSAVE_SLOT).get("name", "")) == GameState.player.name


## Whether the slot holds a living character (a fallen one can't be loaded).
func is_loadable(slot: String) -> bool:
	var meta := read_meta(slot)
	return not meta.is_empty() and bool(meta.get("alive", true))


func load_game(slot: String = DEFAULT_SLOT) -> bool:
	var parsed := _read_payload(slot)
	if parsed.is_empty() or not is_loadable(slot):
		return false
	var from_backup := bool(parsed.get("from_backup", false))
	var payload := _migrate(parsed)
	GameState.load_save_dict(payload.get("game", {}))
	current_slot = slot
	if from_backup:
		EventBus.post("Your last save was damaged; loaded the one before it.", "warning")
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
