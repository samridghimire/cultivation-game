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
