extends TestCase
## Weather (WEATHER-001): deterministic, weighted, persistent, season-aware, validated.


func _with_weather(weather: Variant, persist: float = 0.6) -> GameData:
	var d := GameData.load_from_dir()
	d.regions["qingshi_village"]["weather"] = weather
	d.weather_persist = persist
	return d


func test_deterministic_and_known_kinds() -> void:
	var d := data()
	for day in 400:
		var a := Weather.of(d, "misty_forest", day)
		assert_eq(a, Weather.of(d, "misty_forest", day))
		assert_true(Weather.KINDS.has(a), a)


func test_no_weather_is_clear() -> void:
	var d := _with_weather({})
	d.regions["qingshi_village"].erase("weather")
	assert_eq(Weather.of(d, "qingshi_village", 10), "clear")
	assert_eq(Weather.of(d, "nowhere", 10), "clear")


func test_weights_respected() -> void:
	var d := _with_weather({"any": {"rain": 3, "clear": 1}}, 0.0)
	var rain := 0
	for day in 2000:
		var w := Weather.of(d, "qingshi_village", day)
		assert_true(w == "rain" or w == "clear", w)
		if w == "rain":
			rain += 1
	assert_true(rain > 1350 and rain < 1650, "rain days %d" % rain)


func test_persistence_makes_spells() -> void:
	var flips := func(persist: float) -> int:
		var d := _with_weather({"any": {"rain": 1, "clear": 1}}, persist)
		var n := 0
		for day in range(1, 1500):
			if Weather.of(d, "qingshi_village", day) != Weather.of(d, "qingshi_village", day - 1):
				n += 1
		return n
	assert_true(flips.call(0.9) < flips.call(0.0) / 2, "persistent spells change less often")


func test_season_filtering() -> void:
	var d := _with_weather({"winter": {"snow": 1}, "any": {"clear": 1}}, 0.0)
	for day in 720:
		var expect := "snow" if Calendar.season_of(day) == "Winter" else "clear"
		assert_eq(Weather.of(d, "qingshi_village", day), expect)


func test_validation() -> void:
	for bad: Variant in [{"monsoon": {"rain": 1}}, {"any": {"hail": 1}}, {"any": {"rain": 0}}, {"any": 3}, 5]:
		var d := _with_weather(bad)
		d.load_errors.clear()
		d._validate()
		assert_true(not d.load_errors.is_empty(), str(bad))
	var ok := _with_weather({"any": {"rain": 1}})
	ok.load_errors.clear()
	ok._validate()
	assert_true(ok.load_errors.is_empty(), ", ".join(ok.load_errors))


func test_effects_helper_per_kind() -> void:
	var d := data()
	assert_eq(Weather.effect_note(d, "rain", "gather"), "(rain: herbs thrive)")
	assert_eq(Weather.effect_note(d, "snow", "travel"), "(snow: +1 day)")
	assert_eq(Weather.effect_note(d, "clear", "gather"), "")
	assert_eq(Weather.effect_note(d, "rain", "travel"), "")
	assert_eq(Weather.travel_extra_days(_with_weather({"any": {"snow": 1}}, 0.0), "qingshi_village", 5), 1)
	assert_eq(Weather.travel_extra_days(_with_weather({"any": {"clear": 1}}, 0.0), "qingshi_village", 5), 0)


func test_herb_bonus_only_for_herbs_in_rain() -> void:
	var d := data()
	var rng := seeded_rng(3)
	var found := {"spirit_herb": 1, "iron_essence": 1}
	var hits := 0
	for i in 200:
		var extra := Weather.herb_bonus(d, "rain", found, rng)
		assert_false(extra.has("iron_essence"))
		hits += extra.size()
	assert_gt(hits, 20)
	assert_true(hits < 90, "about a quarter of 200: %d" % hits)
	assert_eq(Weather.herb_bonus(d, "clear", found, rng).size(), 0)


func test_effects_validation() -> void:
	for bad: Variant in [{"hail": {}}, {"rain": {"herb_bonus_chance": 2}}, {"snow": {"travel_extra_days": 0}}, {"rain": {"travel_extra_days": 1}}, {"rain": 3}]:
		var errors: Array[String] = []
		Weather.validate_effects(bad, errors)
		assert_false(errors.is_empty(), str(bad))
	var ok: Array[String] = []
	Weather.validate_effects(data().weather_effects, ok)
	assert_true(ok.is_empty())


func test_fishing_weather_validation_and_multiplier() -> void:
	for bad: Variant in [{"hail": 1.5}, {"rain": 0}, {"rain": "x"}]:
		var errors: Array[String] = []
		Weather.validate_fishing(bad, errors)
		assert_false(errors.is_empty(), str(bad))
	var d := data()
	var ok: Array[String] = []
	Weather.validate_fishing(d.fishing_weather, ok)
	assert_true(ok.is_empty())
	assert_almost_eq(Weather.fishing_multiplier(d, "rain"), 1.5)
	assert_almost_eq(Weather.fishing_multiplier(d, "clear"), 1.0)


func test_scale_catch_moves_only_real_catches() -> void:
	var table := [{"item": "", "weight": 4}, {"item": "silver_carp", "weight": 4, "min": 1, "max": 1}]
	var scaled := Weather.scale_catch(table, 0.5)
	assert_almost_eq(float(scaled[0]["weight"]), 4.0)
	assert_almost_eq(float(scaled[1]["weight"]), 2.0)
	assert_almost_eq(float(table[1]["weight"]), 4.0, 0.001, "the source table is untouched")


func test_pond_places_validate_and_fish_exist() -> void:
	var d := data()
	assert_true(d.load_errors.is_empty(), str(d.load_errors))
	var ponds := 0
	for region: Dictionary in d.regions.values():
		for place: Dictionary in region.get("places", []):
			if place.get("type", "") == "fishing":
				ponds += 1
	assert_eq(ponds, 2)
	for id in ["silver_carp", "mist_koi", "marsh_eel"]:
		assert_true((d.items[id]["tags"] as Array).has("fish"), id)


func test_qi_mult_needs_a_matching_root_of_50_plus() -> void:
	var d := GameData.load_from_dir()
	var c := CharacterData.new()
	c.spiritual_roots = {"water": 60}
	assert_almost_eq(Weather.qi_mult(d, "rain", c), 1.1)
	c.spiritual_roots = {"water": 49}
	assert_eq(Weather.qi_mult(d, "rain", c), 1.0)
	c.spiritual_roots = {"fire": 90}
	assert_eq(Weather.qi_mult(d, "rain", c), 1.0)
	assert_eq(Weather.qi_mult(d, "cloudy", c), 1.0)
	d.weather_effects = {}
	c.spiritual_roots = {"water": 90}
	assert_eq(Weather.qi_mult(d, "rain", c), 1.0, "no data, no effect")


func test_qi_element_validation_and_note() -> void:
	for bad: Variant in [{"rain": {"qi_element": {"element": "ice", "mult": 1.1}}}, {"rain": {"qi_element": {"element": "water", "mult": 1.5}}}, {"rain": {"qi_element": {"element": "water", "mult": 0.9}}}, {"rain": {"qi_element": 3}}]:
		var errors: Array[String] = []
		Weather.validate_effects(bad, errors)
		assert_false(errors.is_empty(), str(bad))
	assert_eq(Weather.effect_note(data(), "rain", "meditate"), "(rain: water qi stirs)")
	assert_eq(Weather.effect_note(data(), "cloudy", "meditate"), "")


## WU-405: the fishing option words the weather like the gather note.
func test_fish_effect_note() -> void:
	var d := data()
	assert_eq(Weather.effect_note(d, "rain", "fish"), "(rain: fish bite more)")
	assert_eq(Weather.effect_note(d, "snow", "fish"), "(snow: fish are shy)")
	assert_eq(Weather.effect_note(d, "clear", "fish"), "")


func test_mean_qi_mult_averages_the_span() -> void:
	var d := GameData.load_from_dir()
	d.regions["qingshi_village"]["weather"] = {"any": {"rain": 1, "clear": 1}}
	d.weather_persist = 0.0
	var c := CharacterData.new()
	c.spiritual_roots = {"water": 80}
	var start := 0
	while Weather.of(d, "qingshi_village", start) != "rain":
		start += 1
	assert_almost_eq(Weather.mean_qi_mult(d, "qingshi_village", c, start, 1), 1.1)
	var expect := 0.0
	for i in 30:
		expect += Weather.qi_mult(d, Weather.of(d, "qingshi_village", start + i), c)
	var mean := Weather.mean_qi_mult(d, "qingshi_village", c, start, 30)
	assert_almost_eq(mean, expect / 30.0)
	assert_true(mean > 1.0 and mean < 1.1, "a mix of rain and clear days is between the two")
	var year := Weather.mean_qi_mult(d, "qingshi_village", c, start, 2000)
	assert_true(year > 1.0 and year < 1.1, "long spans are sampled, not walked day by day")


func test_storm_is_rare_and_only_in_two_regions() -> void:
	var d := data()
	assert_true(d.load_errors.is_empty(), str(d.load_errors))
	var storms := 0
	for day in range(0, 4 * Calendar.DAYS_PER_YEAR):
		for region_id: String in d.regions:
			if Weather.of(d, region_id, day) == "storm":
				storms += 1
				assert_true(region_id in ["qingshi_village", "myriad_peaks_ridge"], region_id)
	assert_gt(storms, 0, "summer storms happen")


func test_storm_effects_validate() -> void:
	for bad: Dictionary in [{"herb_yield_penalty": 0}, {"herb_yield_penalty": 1.5}, {"dao_boost": {"mult": 2}}, {"dao_boost": {"insight": "thunder_dao", "mult": 9}}]:
		var errors: Array[String] = []
		Weather.validate_effects({"storm": bad}, errors)
		assert_false(errors.is_empty(), str(bad))
	var ok: Array[String] = []
	Weather.validate_effects(data().weather_effects, ok)
	assert_true(ok.is_empty(), str(ok))


func test_storm_cuts_herbs_boosts_thunder_dao_and_metal_qi() -> void:
	var d := data()
	var found := {"spirit_herb": 1, "dew_grass": 3, "iron_ore": 2}
	var hit := Weather.herb_penalty(d, "storm", found)
	assert_false(found.has("spirit_herb"), "a one-herb stack is emptied (min 0)")
	assert_eq(int(found["dew_grass"]), 2)
	assert_eq(int(found["iron_ore"]), 2, "ore is not a herb")
	assert_true(hit.has("dew_grass"))
	var clear := {"dew_grass": 3}
	assert_true(Weather.herb_penalty(d, "clear", clear).is_empty())
	assert_eq(int(clear["dew_grass"]), 3)
	assert_almost_eq(Weather.dao_mult(d, "storm", "thunder_dao"), 2.0)
	assert_almost_eq(Weather.dao_mult(d, "storm", "fire_dao"), 1.0)
	assert_almost_eq(Weather.dao_mult(d, "clear", "thunder_dao"), 1.0)
	assert_almost_eq(Weather.fishing_multiplier(d, "storm"), 0.5)
	var c := CharacterData.new()
	c.spiritual_roots = {"metal": 60}
	assert_almost_eq(Weather.qi_mult(d, "storm", c), 1.1)
	assert_true(Weather.effect_note(d, "storm", "meditate").contains("thunder speaks"))
