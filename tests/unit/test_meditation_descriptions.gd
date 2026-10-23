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


func test_meditate_until_bottleneck_on_last_stage() -> void:
	var gs := _gs()
	var c := new_character()
	c.realm_index = 1
	c.stage = gs.data.realms[1].stage_count() - 1
	c.qi = gs.data.realms[1].qi_required(c.stage) - 1.0
	gs.start_session(c)
	gs.current_region = "qingshi_village"
	var spot: Node = load("res://src/world/interactables/meditation_spot.gd").new()
	var options: Array = spot.get_options()
	assert_true(_find(options, "Meditate until the next layer").is_empty())
	assert_false(_find(options, "Meditate until your bottleneck").is_empty())
	spot.free()


func _tribulation_char(constitution: int) -> CharacterData:
	var gs := _gs()
	var c := new_character()
	c.realm_index = 2
	var realm: RealmDef = gs.data.realms[2]
	c.stage = realm.stage_count() - 1
	c.qi = realm.qi_required(c.stage)
	c.attributes["constitution"] = constitution
	return c


## WU-164: a close-call or deadly tribulation tints the attempt option's description; a safe one does not.
func test_tribulation_option_carries_warning_tone() -> void:
	var gs := _gs()
	var c := _tribulation_char(10)
	gs.start_session(c)
	gs.current_region = "qingshi_village"
	var spot: Node = load("res://src/world/interactables/meditation_spot.gd").new()
	var deadly := _find(spot.get_options(), "Attempt breakthrough")
	assert_eq(deadly.get("tone", ""), "warning", "would not survive")
	# Find a constitution where the share lands in the close-call band.
	var con := 10
	while con < 100000:
		c.attributes["constitution"] = con
		var p := Tribulation.preview(c, gs.data, c.realm_index + 1)
		var share := float(p["expected_damage"]) / float(int(p["max_hp"]) + int(p["shield"]))
		if share < 1.0:
			break
		con += 2
	var near := _find(spot.get_options(), "Attempt breakthrough")
	assert_true(String(near["description"]).contains("close") or near.get("tone", "") == "", "close or safe: %s" % near["description"])
	if String(near["description"]).contains("close"):
		assert_eq(near.get("tone", ""), "warning", "close call")
	c.attributes["constitution"] = 100000
	var safe := _find(spot.get_options(), "Attempt breakthrough")
	assert_eq(safe.get("tone", ""), "normal", "safe tribulation is not tinted")
	spot.free()
	gs.end_session()


func test_far_spot_line_names_the_faster_spot() -> void:
	var c := new_character()
	c.realm_index = 2
	var line: String = load("res://src/world/interactables/meditation_spot.gd").far_spot_line(c, _gs().data, "qingshi_village", {}, 1.0)
	assert_true(line.begins_with("Cloud-Sea Cliff in Azure Peak ("), line)
	assert_true(line.contains(" away): about "), line)
	assert_eq(load("res://src/world/interactables/meditation_spot.gd").far_spot_line(c, _gs().data, "azure_peak", {}, 5.0), "")
