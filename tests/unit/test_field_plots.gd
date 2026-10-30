extends TestCase
## FARM-001: the rented village field.

const KEY := "qingshi_village:Test Field"


func _place() -> Dictionary:
	return {"type": "field_plot", "display_name": "Test Field", "plots": 2, "rent": 6, "rent_days": 90,
		"plants": {"spirit_herb": {"days": 5, "yield": [2, 3]}}, "rain_bonus_days": 1, "frozen_seasons": ["winter"], "wood_bonus": 1}


func _farmer() -> CharacterData:
	var c := new_character()
	c.inventory = {"spirit_stone": 20, "spirit_herb": 5}
	c.spiritual_roots = {"fire": 80}
	return c


func _weather(kind: String) -> Callable:
	return func(_region: String, _day: int) -> String: return kind


func test_real_field_validates() -> void:
	assert_false(FieldPlots.place_def(data(), "qingshi_village").is_empty())
	assert_eq(FieldPlots.validate(data(), "qingshi_village", data().regions["qingshi_village"]).size(), 0)


func test_rent_pays_and_renews_only_near_expiry() -> void:
	var c := _farmer()
	var place := _place()
	assert_true(FieldPlots.rent(c, "qingshi_village", place, 100)["ok"])
	assert_eq(c.item_count("spirit_stone"), 14)
	assert_true(FieldPlots.rented(c, KEY, 100))
	assert_eq(int(c.field_plots[KEY]["paid_until"]), 190)
	assert_false(FieldPlots.rent(c, "qingshi_village", place, 101)["ok"], "too early to renew")
	assert_true(FieldPlots.rent(c, "qingshi_village", place, 185)["ok"])
	assert_eq(int(c.field_plots[KEY]["paid_until"]), 280, "extends from the end")
	c.inventory["spirit_stone"] = 5
	assert_true(FieldPlots.check_rent(c, place, KEY, 300).contains("afford"))


func test_plant_needs_rent_item_and_free_plot() -> void:
	var c := _farmer()
	var place := _place()
	assert_true(FieldPlots.check_plant(c, data(), place, KEY, "spirit_herb", 0).contains("Rent"))
	FieldPlots.rent(c, "qingshi_village", place, 0)
	assert_true(FieldPlots.check_plant(c, data(), place, KEY, "iron_essence", 0).contains("grow"))
	assert_true(FieldPlots.plant(c, data(), place, KEY, "spirit_herb", 0)["ok"])
	assert_eq(c.item_count("spirit_herb"), 4)
	assert_true(FieldPlots.plant(c, data(), place, KEY, "spirit_herb", 0)["ok"])
	assert_true(FieldPlots.check_plant(c, data(), place, KEY, "spirit_herb", 0).contains("Every plot"))
	c.inventory.erase("spirit_herb")
	assert_true(FieldPlots.check_plant(c, data(), place, KEY, "spirit_herb", 0).contains("no "))


func test_advance_clear_rain_winter_and_lapse() -> void:
	var c := _farmer()
	var place := _place()
	data().regions["qingshi_village"]["places"].append(place)
	FieldPlots.rent(c, "qingshi_village", place, 0)
	FieldPlots.plant(c, data(), place, KEY, "spirit_herb", 0)
	assert_true(FieldPlots.advance(c, data(), 2, 2, _weather("clear")).is_empty())
	assert_eq(int(c.field_plots[KEY]["crops"][0]["days_left"]), 3)
	FieldPlots.advance(c, data(), 1, 3, _weather("rain"))
	assert_eq(int(c.field_plots[KEY]["crops"][0]["days_left"]), 1, "rain grows two days")
	assert_eq(FieldPlots.advance(c, data(), 1, 4, _weather("clear")), ["qingshi_village:spirit_herb"] as Array[String])
	assert_eq(int(c.field_plots[KEY]["crops"][0]["days_left"]), 0)
	# winter freezes growth
	var c2 := _farmer()
	FieldPlots.rent(c2, "qingshi_village", place, 280)
	FieldPlots.plant(c2, data(), place, KEY, "spirit_herb", 280)
	FieldPlots.advance(c2, data(), 5, 290, _weather("clear"))
	assert_eq(int(c2.field_plots[KEY]["crops"][0]["days_left"]), 5, "frozen")
	# lapsed rent stops growth
	var c3 := _farmer()
	FieldPlots.rent(c3, "qingshi_village", place, 0)
	FieldPlots.plant(c3, data(), place, KEY, "spirit_herb", 0)
	FieldPlots.advance(c3, data(), 4, 92, _weather("clear"))
	assert_eq(int(c3.field_plots[KEY]["crops"][0]["days_left"]), 4, "only day 89 is paid")
	data().regions["qingshi_village"]["places"].erase(place)


func test_harvest_range_and_wood_bonus() -> void:
	var c := _farmer()
	var place := _place()
	FieldPlots.rent(c, "qingshi_village", place, 0)
	FieldPlots.plant(c, data(), place, KEY, "spirit_herb", 0)
	assert_false(FieldPlots.harvest(c, place, KEY, seeded_rng())["ok"], "not ready")
	c.field_plots[KEY]["crops"][0]["days_left"] = 0
	var before := c.item_count("spirit_herb")
	var got := FieldPlots.harvest(c, place, KEY, seeded_rng())
	assert_true(got["ok"])
	var n := int(got["items"]["spirit_herb"])
	assert_true(n >= 2 and n <= 3)
	assert_eq(c.item_count("spirit_herb"), before + n)
	assert_true((c.field_plots[KEY]["crops"] as Array).is_empty())
	var w := _farmer()
	w.spiritual_roots = {"wood": 60}
	FieldPlots.rent(w, "qingshi_village", place, 0)
	FieldPlots.plant(w, data(), place, KEY, "spirit_herb", 0)
	w.field_plots[KEY]["crops"][0]["days_left"] = 0
	var wn := int(FieldPlots.harvest(w, place, KEY, seeded_rng())["items"]["spirit_herb"])
	assert_eq(wn, n + 1, "same roll, one more")


func test_validation_rejects_bad_plants_and_a_second_field() -> void:
	var d := GameData.load_from_dir()
	var region: Dictionary = d.regions["qingshi_village"]
	var bad := _place()
	bad["plants"] = {"no_such_item": {"days": 5, "yield": [1, 2]}}
	region["places"].append(bad)
	assert_true(not FieldPlots.validate(d, "qingshi_village", region).is_empty())
	region["places"].erase(bad)
	region["places"].append(_place())
	region["places"].append(_place())
	assert_true(FieldPlots.validate(d, "qingshi_village", region).any(func(e: String) -> bool: return e.contains("more than one")))


func test_save_round_trip() -> void:
	var c := _farmer()
	FieldPlots.rent(c, "qingshi_village", _place(), 7)
	FieldPlots.plant(c, data(), _place(), KEY, "spirit_herb", 7)
	var back := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.field_plots, c.field_plots)
	assert_true(CharacterData.from_dict({}).field_plots.is_empty())
