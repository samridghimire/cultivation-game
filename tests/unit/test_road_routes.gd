## TRAVEL-001: road encounters that belong to their road.
extends TestCase


func _road_data() -> GameData:
	var d := GameData.load_from_dir()
	d.road = {"chance_per_day": 1.0, "max_chance": 1.0, "encounter_tags": ["road"]}
	d.encounters = {
		"plain": {"id": "plain", "tags": ["road"], "weight": 1, "kind": "neutral", "text": "Plain."},
		"peak": {"id": "peak", "tags": ["road"], "road_regions": ["azure_peak"], "weight": 1, "kind": "neutral", "text": "Peak."},
	}
	return d


func _ids(d: GameData, from_region: String, to_region: String, runs: int) -> Dictionary:
	var out := {}
	for s in range(runs):
		var e := Exploration.road_encounter(new_character(), d, 3, {}, seeded_rng(s), "Spring", 0, from_region, to_region)
		out[String(e.get("id", ""))] = int(out.get(String(e.get("id", "")), 0)) + 1
	return out


func test_route_encounter_only_on_its_road() -> void:
	var d := _road_data()
	assert_false(_ids(d, "qingshi_village", "misty_forest", 60).has("peak"))
	assert_true(_ids(d, "qingshi_village", "azure_peak", 60).has("peak"), "to")
	assert_true(_ids(d, "azure_peak", "qingshi_village", 60).has("peak"), "from")


func test_no_regions_never_returns_route_encounter() -> void:
	var d := _road_data()
	var seen := _ids(d, "", "", 60)
	assert_false(seen.has("peak"))
	assert_true(seen.has("plain"))


func test_route_encounter_weighs_double() -> void:
	var d := _road_data()
	var seen := _ids(d, "", "azure_peak", 300)
	assert_true(int(seen.get("peak", 0)) > int(seen.get("plain", 0)) * 1.4, str(seen))


func test_destination_weather_gates_road_encounter() -> void:
	var d := _road_data()
	d.encounters = {"wisp": {"id": "wisp", "tags": ["road"], "weather": ["fog"], "weight": 1, "kind": "neutral", "text": "Wisp."}}
	var fog_day := -1
	var dry_day := -1
	for day in range(200):
		var w := Weather.of(d, "withered_bone_marsh", day)
		if w == "fog" and fog_day < 0:
			fog_day = day
		if w != "fog" and dry_day < 0:
			dry_day = day
	assert_true(fog_day >= 0 and dry_day >= 0)
	var rolled := Exploration.road_encounter(new_character(), d, 3, {}, seeded_rng(1), "Spring", fog_day, "qingshi_village", "withered_bone_marsh")
	assert_eq(rolled.get("id", ""), "wisp")
	assert_eq(Exploration.road_encounter(new_character(), d, 3, {}, seeded_rng(1), "Spring", fog_day, "qingshi_village", "withered_bone_marsh").get("id", ""), "wisp", "deterministic")
	assert_true(Exploration.road_encounter(new_character(), d, 3, {}, seeded_rng(1), "Spring", dry_day, "qingshi_village", "withered_bone_marsh").is_empty())


func test_validation_of_road_regions() -> void:
	var good := GameData.load_from_dir()
	assert_true(good.load_errors.is_empty(), str(good.load_errors))
	assert_true(good.encounters.values().any(func(e: Dictionary) -> bool: return e.has("road_regions")))


func test_bad_road_regions_are_errors() -> void:
	for bad: Dictionary in [{"tags": ["road"], "road_regions": ["nowhere"]}, {"tags": ["village"], "road_regions": ["azure_peak"]}]:
		var d := GameData.load_from_dir()
		d.encounters = {"x": {"id": "x", "weight": 1, "kind": "neutral", "text": "X.", "tags": bad["tags"], "road_regions": bad["road_regions"]}}
		d.load_errors = PackedStringArray()
		d._validate_world()
		assert_false(d.load_errors.is_empty(), str(bad))
