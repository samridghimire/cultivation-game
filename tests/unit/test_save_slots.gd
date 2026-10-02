extends TestCase
## Multiple save slots and their metadata (SaveManager autoload).

const SLOT_A := "_test_slots_a"
const SLOT_B := "_test_slots_b"


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _saves() -> Node:
	return _root().get_node("SaveManager")


func _start(char_name: String) -> CharacterData:
	var gs := _root().get_node("GameState")
	var c := CharacterFactory.create(char_name, gs.data, seeded_rng())
	gs.start_session(c)
	return c


func _cleanup() -> void:
	for slot in [SLOT_A, SLOT_B]:
		_saves().delete_save(slot)


func _find(slots: Array[Dictionary], slot: String) -> Dictionary:
	for s in slots:
		if s["slot"] == slot:
			return s
	return {}


func test_list_slots_reports_metadata() -> void:
	_cleanup()
	_start("Slot Tester")
	assert_true(_saves().save_game(SLOT_A))
	var meta := _find(_saves().list_slots(), SLOT_A)
	assert_eq(meta.get("name", ""), "Slot Tester")
	assert_eq(meta.get("realm_label", ""), "Mortal")
	assert_eq(meta.get("game_date", ""), Calendar.format_date(0))
	assert_true(meta.get("alive", false))
	assert_gt(int(meta.get("saved_unix", 0)), 0)
	_cleanup()


func test_slots_are_independent() -> void:
	_cleanup()
	_start("First")
	_saves().save_game(SLOT_A)
	_start("Second")
	_saves().save_game(SLOT_B)
	assert_true(_saves().load_game(SLOT_A))
	assert_eq(_root().get_node("GameState").player.name, "First")
	assert_true(_saves().load_game(SLOT_B))
	assert_eq(_root().get_node("GameState").player.name, "Second")
	_cleanup()


func test_delete_save() -> void:
	_cleanup()
	_start("Doomed")
	_saves().save_game(SLOT_A)
	assert_true(_saves().delete_save(SLOT_A))
	assert_false(_saves().has_save(SLOT_A))
	assert_eq(_find(_saves().list_slots(), SLOT_A), {})
	assert_false(_saves().delete_save(SLOT_A))


func test_rejects_unsafe_slot_names() -> void:
	_start("Sneaky")
	assert_false(_saves().is_valid_slot_name("../evil"))
	assert_false(_saves().is_valid_slot_name(""))
	assert_false(_saves().save_game("a/b"))
	assert_true(_saves().is_valid_slot_name("slot_1-b"))


func test_next_free_slot_skips_used_names() -> void:
	var name: String = _saves().next_free_slot()
	assert_false(_saves().has_save(name))
	assert_true(name.begins_with("slot"))


func test_saves_without_meta_still_list() -> void:
	_cleanup()
	_start("Legacy")
	_saves().save_game(SLOT_A)
	var path: String = _saves().save_path(SLOT_A)
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	payload.erase("meta")
	payload.erase("saved_unix")
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(payload))
	assert_eq(_find(_saves().list_slots(), SLOT_A).get("name", ""), "Legacy")
	_cleanup()
