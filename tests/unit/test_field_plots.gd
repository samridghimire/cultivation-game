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


func test_harvest_survives_a_plant_removed_from_the_data() -> void:
	var c := _farmer()
	var place := _place()
	FieldPlots.rent(c, "qingshi_village", place, 0)
	FieldPlots.plant(c, data(), place, KEY, "spirit_herb", 0)
	c.field_plots[KEY]["crops"][0]["days_left"] = 0
	var edited := place.duplicate(true)
	edited["plants"] = {}
	var got := FieldPlots.harvest(c, edited, KEY, seeded_rng())
	assert_true(got["ok"])
	assert_eq(int(got["items"]["spirit_herb"]), 1)
	assert_eq(got["orphaned"], ["spirit_herb"])


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


func test_growth_stage_thresholds() -> void:
	assert_eq(FieldPlots.growth_stage(10, 10), 0, "just planted")
	assert_eq(FieldPlots.growth_stage(7, 10), 0, "0.3 grown")
	assert_eq(FieldPlots.growth_stage(6, 10), 1, "0.4 grown")
	assert_eq(FieldPlots.growth_stage(3, 10), 2, "0.7 grown")
	assert_eq(FieldPlots.growth_stage(1, 10), 2, "almost ripe")
	assert_eq(FieldPlots.growth_stage(0, 10), 3, "ripe")
	assert_eq(FieldPlots.growth_stage(5, 0), 3, "bad total counts as ripe")
	assert_eq(FieldPlots.crop_total_days(_place(), "spirit_herb"), 5)
	assert_true(FieldPlots.is_frozen(_place(), 11 * Calendar.DAYS_PER_MONTH), "month 12 is winter")
	assert_false(FieldPlots.is_frozen(_place(), 0))


func test_describe_says_ready_in() -> void:
	var c := _farmer()
	c.field_plots[KEY] = {"paid_until": 99, "crops": [{"item": "spirit_herb", "days_left": 3}]}
	var lines := FieldPlots.describe(c, GameData.new(), _place(), KEY, 1)
	assert_true("\n".join(lines).contains("ready in"), "\n".join(lines))


func _day_of(season: String) -> int:
	for day in 400:
		if Calendar.season_of(day) == season:
			return day
	return 0


func _seasonal_place() -> Dictionary:
	var p := _place()
	p["plants"]["spirit_herb"]["seasons"] = ["spring"]
	p["plants"]["dew_grass"] = {"days": 5, "yield": [1, 2]}
	return p


func test_out_of_season_plant_is_refused() -> void:
	var place := _seasonal_place()
	var c := _farmer()
	var spring := _day_of("Spring")
	var summer := _day_of("Summer")
	c.field_plots[KEY] = {"paid_until": summer + 50, "crops": []}
	assert_eq(FieldPlots.check_plant(c, data(), place, KEY, "spirit_herb", spring), "")
	assert_eq(FieldPlots.check_plant(c, data(), place, KEY, "spirit_herb", summer), "Spirit Herb is only planted in spring.")
	c.add_item("dew_grass", 1)
	assert_eq(FieldPlots.check_plant(c, data(), place, KEY, "dew_grass", summer), "", "no seasons key = any season")
	assert_eq(FieldPlots.season_note(place, "spirit_herb"), "spring only")
	place["plants"]["spirit_herb"]["seasons"] = ["spring", "summer", "autumn"]
	assert_eq(FieldPlots.season_note(place, "spirit_herb"), "spring, summer and autumn")


func test_plantable_filters_by_season_only_when_given_a_day() -> void:
	var place := _seasonal_place()
	assert_eq(FieldPlots.plantable(place).size(), 2)
	assert_eq(FieldPlots.plantable(place, _day_of("Spring")).size(), 2)
	assert_eq(FieldPlots.plantable(place, _day_of("Summer")), ["dew_grass"] as Array[String])


func test_planted_crop_keeps_growing_into_another_season() -> void:
	var place := _seasonal_place()
	var c := _farmer()
	var start := _day_of("Summer") - 2
	c.field_plots[KEY] = {"paid_until": start + 90, "crops": [{"item": "spirit_herb", "days_left": 5}]}
	var region_d := GameData.load_from_dir()
	region_d.regions["qingshi_village"]["places"].append(place)
	FieldPlots.advance(c, region_d, 5, start + 5, _weather("clear"))
	assert_eq(int(c.field_plots[KEY]["crops"][0]["days_left"]), 0)


func test_validation_rejects_bad_seasons() -> void:
	var d := GameData.load_from_dir()
	for bad: Variant in [[], ["monsoon"], "spring"]:
		var region: Dictionary = d.regions["qingshi_village"]
		var p := _seasonal_place()
		p["plants"]["spirit_herb"]["seasons"] = bad
		region["places"].append(p)
		assert_true(FieldPlots.validate(d, "qingshi_village", region).any(func(e: String) -> bool: return e.contains("season")), str(bad))
		region["places"].erase(p)


func test_real_fields_season_data() -> void:
	var place := FieldPlots.place_def(data(), "qingshi_village")
	assert_eq(FieldPlots.plant_seasons(place, "peach_blossom_petal"), ["spring"])
	assert_false(FieldPlots.plantable(place, _day_of("Winter")).has("village_mugwort"))
	assert_true(FieldPlots.plantable(place, _day_of("Winter")).has("spirit_herb"))


func _growing(days_left: int = 10) -> CharacterData:
	var c := _farmer()
	c.realm_index = 1
	c.qi = 100.0
	FieldPlots.rent(c, "qingshi_village", _place(), 10)
	FieldPlots.plant(c, data(), _place(), KEY, "spirit_herb", 10)
	c.field_plots[KEY]["crops"][0]["days_left"] = days_left
	return c


func test_nourish_advances_and_costs_qi() -> void:
	var c := _growing()
	var r := FieldPlots.nourish(c, _place(), KEY, 10)
	assert_true(r["ok"])
	assert_eq(c.field_plots[KEY]["crops"][0]["days_left"], 8)
	assert_eq(c.qi, 70.0)
	assert_eq(c.field_plots[KEY]["nourished_day"], 10)
	assert_eq(r["days_left"], 8)


func test_nourish_wood_root_and_cap_at_ripe() -> void:
	var c := _growing(2)
	c.spiritual_roots = {"wood": 60}
	FieldPlots.nourish(c, _place(), KEY, 10)
	assert_eq(c.field_plots[KEY]["crops"][0]["days_left"], 0, "never past ripe")
	var d := _growing()
	d.spiritual_roots = {"wood": 60}
	FieldPlots.nourish(d, _place(), KEY, 10)
	assert_eq(d.field_plots[KEY]["crops"][0]["days_left"], 7)


func test_nourish_refusals() -> void:
	var p := _place()
	var c := _growing()
	c.realm_index = 0
	assert_true(FieldPlots.check_nourish(c, p, KEY, 10).contains("cultivator"), "mortal")
	c.realm_index = 1
	c.qi = 5.0
	assert_true(FieldPlots.check_nourish(c, p, KEY, 10).contains("30 qi"), "no qi")
	c.qi = 100.0
	assert_eq(FieldPlots.check_nourish(c, p, KEY, 10), "")
	FieldPlots.nourish(c, p, KEY, 10)
	assert_true(FieldPlots.check_nourish(c, p, KEY, 10).contains("already"), "once a day")
	assert_eq(FieldPlots.check_nourish(c, p, KEY, 11), "", "next day is fine")
	assert_true(FieldPlots.check_nourish(_growing(0), p, KEY, 10).contains("growing"), "ripe")
	assert_true(FieldPlots.check_nourish(_growing(), p, KEY, _day_of("Winter")).contains("frozen") or FieldPlots.check_nourish(_growing(), p, KEY, _day_of("Winter")).contains("Rent"), "frozen or rent lapsed")
	assert_true(FieldPlots.check_nourish(_farmer(), p, KEY, 10).contains("Rent"), "not rented")


func test_nourish_cost_validation() -> void:
	var d := data()
	var region: Dictionary = d.regions["qingshi_village"].duplicate(true)
	for place: Dictionary in region["places"]:
		if place.get("type", "") == "field_plot":
			place["nourish_qi"] = 0
	assert_gt(FieldPlots.validate(d, "qingshi_village", region).size(), 0)


## FARM-005: tending pays at harvest.
func test_care_counts_from_water_and_nourish_once_a_day() -> void:
	var c := _growing()
	var p := _place()
	assert_true(FieldPlots.water(c, p, KEY, 10, "clear")["ok"])
	assert_false(FieldPlots.water(c, p, KEY, 10, "clear")["ok"], "not twice a day")
	assert_eq(int(c.field_plots[KEY]["crops"][0]["care"]), 1)
	FieldPlots.nourish(c, p, KEY, 10)
	assert_eq(int(c.field_plots[KEY]["crops"][0]["care"]), 2, "nourish adds its own day")
	FieldPlots.nourish(c, p, KEY, 10)
	assert_eq(int(c.field_plots[KEY]["crops"][0]["care"]), 2, "refused nourish adds nothing")


func test_tended_threshold_edge_and_stacking() -> void:
	var p := _place()	# 5 days * 0.25 -> ceil 2
	assert_eq(FieldPlots.care_needed(p, "spirit_herb"), 2)
	var under := _farmer()
	FieldPlots.rent(under, "qingshi_village", p, 0)
	FieldPlots.plant(under, data(), p, KEY, "spirit_herb", 0)
	under.field_plots[KEY]["crops"][0]["days_left"] = 0
	under.field_plots[KEY]["crops"][0]["care"] = 1
	var base := FieldPlots.harvest(under, p, KEY, seeded_rng())
	assert_false(base["tended"].has("spirit_herb"))
	var at := _farmer()
	FieldPlots.rent(at, "qingshi_village", p, 0)
	FieldPlots.plant(at, data(), p, KEY, "spirit_herb", 0)
	at.field_plots[KEY]["crops"][0]["days_left"] = 0
	at.field_plots[KEY]["crops"][0]["care"] = 2
	var got := FieldPlots.harvest(at, p, KEY, seeded_rng())
	assert_true(got["tended"].has("spirit_herb"))
	assert_eq(int(got["items"]["spirit_herb"]), int(base["items"]["spirit_herb"]) + 1)
	var w := _farmer()
	w.spiritual_roots = {"wood": 60}
	FieldPlots.rent(w, "qingshi_village", p, 0)
	FieldPlots.plant(w, data(), p, KEY, "spirit_herb", 0)
	w.field_plots[KEY]["crops"][0]["days_left"] = 0
	w.field_plots[KEY]["crops"][0]["care"] = 5
	assert_eq(int(FieldPlots.harvest(w, p, KEY, seeded_rng())["items"]["spirit_herb"]), int(base["items"]["spirit_herb"]) + 2, "wood and tended stack")


func test_old_crop_without_care_and_describe() -> void:
	var c := _growing(3)
	assert_false(c.field_plots[KEY]["crops"][0].has("care"))
	var lines := FieldPlots.describe(c, data(), _place(), KEY, 10)
	assert_true("Tended 0 of 2 days needed for a richer harvest." in lines)
	c.field_plots[KEY]["crops"][0]["days_left"] = 0
	var got := FieldPlots.harvest(c, _place(), KEY, seeded_rng())
	assert_true(got["ok"] and got["tended"].is_empty())


func test_tended_validation() -> void:
	var bad := {"qingshi_village": {"places": [_place()]}}
	for kv: Array in [["tended_share", 0.0], ["tended_share", 1.5], ["tended_bonus", 4], ["tended_bonus", -1]]:
		var place := _place()
		place[kv[0]] = kv[1]
		assert_true(FieldPlots.validate(data(), "qingshi_village", {"places": [place]}).size() > 0, "%s=%s" % kv)
	assert_eq(FieldPlots.validate(data(), "qingshi_village", bad["qingshi_village"]).size(), 0)
