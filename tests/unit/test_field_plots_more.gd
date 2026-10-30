extends TestCase
## FARM-002: the Misty Forest field, watering by hand and enlarging a field.


func _gs() -> Node:
	return Engine.get_main_loop().root.get_node("GameState")


func _start(region: String) -> CharacterData:
	var gs := _gs()
	var c := CharacterFactory.create("Farmer", gs.data, seeded_rng(11))
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	gs.current_region = region
	c.inventory["spirit_stone"] = 200
	c.inventory["spirit_herb"] = 6
	return c


func _weather(kind: String) -> void:
	var gs := _gs()
	gs.data.regions[gs.current_region]["weather"] = {"any": {kind: 1}}
	gs.data.weather_persist = 0.0


func test_misty_forest_has_a_field() -> void:
	var place := FieldPlots.place_def(data(), "misty_forest")
	assert_false(place.is_empty())
	assert_eq(int(place["rent"]), 10)
	assert_eq(int(place["plots"]), 2)
	assert_eq(FieldPlots.validate(data(), "misty_forest", data().regions["misty_forest"]), [] as Array[String])


func test_water_needs_a_growing_crop_and_once_a_day() -> void:
	var gs := _gs()
	var c := _start("misty_forest")
	_weather("clear")
	var place := FieldPlots.place_def(gs.data, "misty_forest")
	var k := FieldPlots.key("misty_forest", place)
	gs.rent_field()
	gs.water_field()
	assert_false(c.field_plots[k].has("watered_day") and int(c.field_plots[k]["watered_day"]) == GameClock.total_days, "nothing to water")
	gs.plant_field("spirit_herb")
	gs.water_field()
	assert_eq(int(c.field_plots[k]["watered_day"]), GameClock.total_days)
	assert_true(FieldPlots.check_water(c, place, k, GameClock.total_days, "clear") != "", "twice in a day refused")
	assert_true(FieldPlots.check_water(c, place, k, GameClock.total_days + 1, "rain") != "", "rain waters it already")
	gs.data = GameData.load_from_dir()


func test_watering_speeds_the_next_day_like_rain() -> void:
	var c := new_character()
	c.inventory["spirit_stone"] = 50
	var place := FieldPlots.place_def(data(), "misty_forest")
	var k := FieldPlots.key("misty_forest", place)
	var day := 100  # a summer-ish day; the clear Callable avoids the weather table
	FieldPlots.rent(c, "misty_forest", place, day)
	c.field_plots[k]["crops"] = [{"item": "spirit_herb", "days_left": 10}]
	var clear := func(_r: String, _d: int) -> String: return "clear"
	FieldPlots.advance(c, data(), 1, day + 1, clear)
	assert_eq(int(c.field_plots[k]["crops"][0]["days_left"]), 9)
	assert_true(FieldPlots.water(c, place, k, day + 1, "clear")["ok"])
	FieldPlots.advance(c, data(), 1, day + 2, clear)
	assert_eq(int(c.field_plots[k]["crops"][0]["days_left"]), 7, "watered day counts double (rain_bonus_days 1)")
	FieldPlots.advance(c, data(), 1, day + 3, clear)
	assert_eq(int(c.field_plots[k]["crops"][0]["days_left"]), 6, "the effect lasted one day")


func test_expand_raises_plots_once_and_needs_stones() -> void:
	var gs := _gs()
	var c := _start("misty_forest")
	var place := FieldPlots.place_def(gs.data, "misty_forest")
	var k := FieldPlots.key("misty_forest", place)
	gs.rent_field()
	c.inventory["spirit_stone"] = 5
	gs.expand_field()
	assert_eq(FieldPlots.plots_for(c, place, k), 2, "no stones, no expansion")
	c.inventory["spirit_stone"] = 100
	gs.expand_field()
	assert_eq(FieldPlots.plots_for(c, place, k), 4)
	assert_eq(c.item_count("spirit_stone"), 100 - int(place["expand_cost"]))
	gs.expand_field()
	assert_eq(c.item_count("spirit_stone"), 100 - int(place["expand_cost"]), "only once")
	for i in 4:
		gs.plant_field("spirit_herb")
	assert_eq((c.field_plots[k]["crops"] as Array).size(), 4)


func test_saves_keep_new_keys_and_old_saves_load() -> void:
	var c := new_character()
	c.field_plots["misty_forest:X"] = {"paid_until": 50, "crops": [], "watered_day": 7, "expanded": true}
	var back := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(int(back.field_plots["misty_forest:X"]["watered_day"]), 7)
	assert_true(bool(back.field_plots["misty_forest:X"]["expanded"]))
	var d := c.to_dict()
	d["field_plots"] = {"qingshi_village:Y": {"paid_until": 9, "crops": []}}
	var old := CharacterData.from_dict(d)
	assert_false(bool(old.field_plots["qingshi_village:Y"].get("expanded", false)))
	assert_eq(int(old.field_plots["qingshi_village:Y"].get("watered_day", -1)), -1)


func test_validation_rejects_bad_expansion() -> void:
	var region: Dictionary = data().regions["misty_forest"].duplicate(true)
	for p: Dictionary in region["places"]:
		if p.get("type", "") == "field_plot":
			p["max_plots"] = 1
	assert_false(FieldPlots.validate(data(), "misty_forest", region).is_empty())
