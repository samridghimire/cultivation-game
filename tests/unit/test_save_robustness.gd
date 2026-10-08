extends TestCase
## Bad save files never crash the loader; they show up as damaged slots (QA-023).

const SLOT := "_test_robust"


func _saves() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("SaveManager")


func _start(char_name: String) -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	gs.start_session(CharacterFactory.create(char_name, gs.data, seeded_rng()))


func _cleanup() -> void:
	for extra in ["", ".bak", ".tmp"]:
		var p: String = _saves().save_path(SLOT) + extra
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _find(slot: String) -> Dictionary:
	for s in _saves().list_slots():
		if s["slot"] == slot:
			return s
	return {}


func _real_save_text() -> String:
	_start("Robust")
	_saves().save_game(SLOT)
	var text := FileAccess.get_file_as_string(_saves().save_path(SLOT))
	_cleanup()
	return text


func test_bad_files_are_damaged_and_deletable() -> void:
	var real := _real_save_text()
	var cases := {
		"truncated": real.substr(0, real.length() / 2),
		"empty": "",
		"array": "[]",
		"string": "\"text\"",
		"no_version": "{\"saved_unix\": 5}",
	}
	for label in cases:
		_cleanup()
		var path: String = _saves().save_path(SLOT)
		_write(path, cases[label])
		_write(path + ".bak", cases[label] if label == "empty" else "garbage")
		var row := _find(SLOT)
		assert_false(row.is_empty(), "%s: listed" % label)
		assert_true(row.get("damaged", false), "%s: damaged" % label)
		assert_false(_saves().load_game(SLOT), "%s: load refused" % label)
		assert_true(_saves().delete_save(SLOT), "%s: deleted" % label)
		assert_false(FileAccess.file_exists(path), "%s: file gone" % label)
		assert_false(FileAccess.file_exists(path + ".bak"), "%s: bak gone" % label)
	_cleanup()


func test_damaged_main_loads_from_backup() -> void:
	_cleanup()
	_start("Backup One")
	assert_true(_saves().save_game(SLOT))
	_start("Backup Two")
	assert_true(_saves().save_game(SLOT))
	_write(_saves().save_path(SLOT), "[]")
	assert_true(_saves().load_game(SLOT))
	assert_eq(_saves().read_meta(SLOT).get("name", ""), "Backup One")
	_cleanup()
