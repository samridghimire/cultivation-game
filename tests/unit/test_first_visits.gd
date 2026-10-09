extends TestCase
## QA-047: first sights (TRAV-001..003) survive save/load round trips and old saves.

const FIXTURE_DIR := "res://tests/fixtures/saves"
const SLOT := "_first_visits_"


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _game_state() -> Node:
	return _root().get_node("GameState")


func _count_messages(text: String) -> int:
	var n := 0
	for m: Dictionary in _root().get_node("EventBus").history:
		if m["text"] == text:
			n += 1
	return n


func _start() -> CharacterData:
	var c := CharacterFactory.create("Visitor", _game_state().data, seeded_rng(4242))
	c.spiritual_roots = {"fire": 80}
	_game_state().start_session(c)
	return c


func _round_trip(gs: Node) -> void:
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	gs.load_save_dict(saved)


func test_first_sight_survives_save_and_load() -> void:
	var gs := _game_state()
	_start().realm_index = 1
	var line := String(gs.data.regions["misty_forest"]["first_visit"])
	gs.travel("misty_forest")
	assert_true(gs.last_arrival_first_visit)
	assert_eq(_count_messages(line), 1)
	_round_trip(gs)
	assert_false(gs.last_arrival_first_visit, "loading is not an arrival")
	assert_true(gs.player.visited_regions.has("misty_forest"))
	gs.travel(gs.data.start_region)
	var before := _count_messages(line)  # loading may reset the message log
	gs.travel("misty_forest")
	assert_false(gs.last_arrival_first_visit)
	assert_eq(_count_messages(line), before, "no second first-visit line after a reload")
	_round_trip(gs)
	before = _count_messages(line)
	gs.travel(gs.data.start_region)
	gs.travel("misty_forest")
	assert_eq(_count_messages(line), before)
	gs.end_session()


func test_new_game_start_region_is_visited_after_reload() -> void:
	var gs := _game_state()
	_start()
	_round_trip(gs)
	assert_true(gs.player.visited_regions.has(gs.data.start_region))
	gs.end_session()


func test_old_fixture_backfills_and_unvisited_region_still_greets() -> void:
	var gs := _game_state()
	var sm := _root().get_node("SaveManager")
	DirAccess.make_dir_recursive_absolute(sm.SAVE_DIR)
	var file := FileAccess.open(sm.save_path(SLOT), FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(FIXTURE_DIR.path_join("v1_oldest.json")))
	file.close()
	var ok: bool = sm.load_game(SLOT)
	sm.delete_save(SLOT)
	assert_true(ok)
	var v: Array[String] = gs.player.visited_regions
	assert_true(v.has(gs.current_region), "current region marked visited")
	assert_true(v.has(gs.data.start_region), "start region marked visited")
	var target := ""
	for route: Dictionary in gs.data.regions[gs.current_region].get("routes", []):
		var rid := String(route.get("to", ""))
		if rid != "" and not v.has(rid) and String(gs.data.regions[rid].get("first_visit", "")) != "":
			target = rid
			break
	if target == "":
		gs.end_session()
		return
	gs.player.realm_index = maxi(gs.player.realm_index, 3)
	var line := String(gs.data.regions[target]["first_visit"])
	gs.travel(target)
	if gs.current_region == target:
		assert_true(gs.last_arrival_first_visit)
		assert_eq(_count_messages(line), 1)
	gs.end_session()
