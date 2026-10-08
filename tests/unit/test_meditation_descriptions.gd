extends TestCase
## WU-029: meditation spot and abode entries explain themselves with a description.


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _find(options: Array, prefix: String) -> Dictionary:
	for o: Dictionary in options:
		if String(o["label"]).begins_with(prefix):
			return o
	return {}


func test_meditation_entries_have_previews() -> void:
	var gs := _gs()
	gs.start_session(new_character())
	gs.current_region = "qingshi_village"
	var spot: Node = load("res://src/world/interactables/meditation_spot.gd").new()
	var options: Array = spot.get_options()
	for prefix in ["Meditate", "Closed-door"]:
		var d := String(_find(options, prefix).get("description", ""))
		assert_true(d != "" and d.to_lower().contains("qi"), "%s: %s" % [prefix, d])
	spot.free()


func test_breakthrough_entry_shows_odds() -> void:
	var gs := _gs()
	var c := new_character()
	var realm: RealmDef = gs.data.realms[c.realm_index]
	c.stage = realm.stage_count() - 1
	c.qi = realm.qi_required(c.stage)
	gs.start_session(c)
	gs.current_region = "qingshi_village"
	var spot: Node = load("res://src/world/interactables/meditation_spot.gd").new()
	var entry := _find(spot.get_options(), "Attempt breakthrough")
	assert_false(entry.is_empty())
	assert_true(String(entry.get("description", "")).contains("%"), String(entry.get("description", "")))
	spot.free()


func test_meditate_until_next_layer() -> void:
	var gs := _gs()
	var c := new_character()
	c.realm_index = 1
	c.stage = 0
	c.qi = 0.0
	gs.start_session(c)
	gs.current_region = "qingshi_village"
	var spot: Node = load("res://src/world/interactables/meditation_spot.gd").new()
	var entry := _find(spot.get_options(), "Meditate until the next layer")
	assert_false(entry.is_empty())
	var days: int = gs.days_to_next_stage(1.0)
	var stage_before: int = gs.player.stage
	var clock: Node = gs.get_node("/root/GameClock")
	var start: int = clock.total_days
	entry["action"].call()
	assert_true(absi(int(clock.total_days) - start - days) <= 1, "days passed")
	assert_eq(gs.player.stage, stage_before + 1)
	spot.free()
