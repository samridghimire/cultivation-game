extends TestCase
## Crash-safe saves: atomic writes, .bak fallback, damaged slots (REL-007).

const SLOT := "_test_safety"


func _saves() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("SaveManager")


func _start(char_name: String) -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	gs.start_session(CharacterFactory.create(char_name, gs.data, seeded_rng()))


func _cleanup() -> void:
	_saves().delete_save(SLOT)
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


func test_second_save_keeps_backup() -> void:
	_cleanup()
	_start("First")
	assert_true(_saves().save_game(SLOT))
	_start("Second")
	assert_true(_saves().save_game(SLOT))
	var bak: String = _saves().save_path(SLOT) + ".bak"
	assert_true(FileAccess.file_exists(bak))
	assert_true(FileAccess.get_file_as_string(bak).contains("First"))
	assert_eq(_saves().read_meta(SLOT).get("name", ""), "Second")
	assert_false(FileAccess.file_exists(_saves().save_path(SLOT) + ".tmp"))
	_cleanup()


func test_corrupt_save_loads_from_backup() -> void:
	_cleanup()
	_start("First")
	_saves().save_game(SLOT)
	_start("Second")
	_saves().save_game(SLOT)
	_write(_saves().save_path(SLOT), "{garbage")
	assert_true(_saves().read_meta(SLOT).get("from_backup", false))
	assert_true(_saves().load_game(SLOT))
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	assert_eq(gs.player.name, "First")
	_cleanup()


func test_damaged_slot_listed_and_deletable() -> void:
	_cleanup()
	DirAccess.make_dir_recursive_absolute(_saves().SAVE_DIR)
	_write(_saves().save_path(SLOT), "not json")
	var meta := _find(SLOT)
	assert_true(meta.get("damaged", false))
	assert_false(_saves().is_loadable(SLOT))
	assert_false(_saves().load_game(SLOT))
	assert_false(_saves().most_recent_living_slot() == SLOT)
	assert_true(_saves().delete_save(SLOT))
	assert_true(_find(SLOT).is_empty())
	_cleanup()


func test_tmp_and_bak_files_are_not_slots() -> void:
	_cleanup()
	DirAccess.make_dir_recursive_absolute(_saves().SAVE_DIR)
	_write(_saves().save_path(SLOT) + ".tmp", "partial")
	_write(_saves().save_path(SLOT) + ".bak", "{}")
	assert_true(_find(SLOT).is_empty())
	assert_true(_find(SLOT + ".tmp").is_empty())
	_cleanup()
