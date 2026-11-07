extends TestCase
## FOLK-017: named villagers keep their own days (Folk.spot_for, npcs.json spots).

const MARKET_DAY := 9  # day of month 10, a Fireday: nobody rests
const PLAIN_DAY := 1  # Moonday, no market


func _def(id: String = "elder_mo") -> Dictionary:
	return data().npcs[id]


func _festival() -> Array:
	return [{"id": "lantern_festival", "region": "qingshi_village", "start_day": 0, "end_day": 99, "done": false}]


func test_market_day_returns_market_spot() -> void:
	var r := Folk.spot_for(data(), _def(), MARKET_DAY, "clear", [])
	assert_eq(r["why"], "market")
	assert_eq(r["pos"], Vector2(660, 420))


func test_plain_day_works_and_rain_beats_market() -> void:
	assert_eq(Folk.spot_for(data(), _def(), PLAIN_DAY, "clear", [])["why"], "work")
	assert_eq(Folk.spot_for(data(), _def(), MARKET_DAY, "rain", [])["why"], "rain")
	assert_eq(Folk.spot_for(data(), _def(), PLAIN_DAY, "storm", [])["why"], "rain")


func test_festival_beats_rain() -> void:
	var r := Folk.spot_for(data(), _def(), MARKET_DAY, "rain", _festival())
	assert_eq(r["why"], "festival")
	var square := Vector2(1100, 900)
	assert_true((r["pos"] as Vector2).distance_to(square) <= 90.0)


func test_festival_offset_is_deterministic() -> void:
	var a := Folk.spot_for(data(), _def(), 5, "clear", _festival())
	var b := Folk.spot_for(data(), _def(), 5, "clear", _festival())
	assert_eq(a["pos"], b["pos"])


func test_rest_weekday_stays_home() -> void:
	# Day 6 is an Earthday (6 % 7), not a market day.
	var r := Folk.spot_for(data(), _def(), 6, "clear", [])
	assert_eq(r["why"], "rest")
	assert_eq(r["pos"], Vector2(450, 240))


func test_villager_without_spots_is_home() -> void:
	var r := Folk.spot_for(data(), _def("herbalist_lan"), MARKET_DAY, "rain", _festival())
	assert_eq(r["why"], "home")
	assert_eq(r["pos"], Vector2(640, 720))


func test_validation_rejects_bad_spots() -> void:
	var bad := {"id": "x", "region": "qingshi_village", "pos": [0, 0], "spots": {"work": [5000, 5], "rest_weekday": "Funday", "nap": [1, 1]}}
	assert_eq(Folk.validate_spots(bad, data()).size(), 3)
	assert_eq(Folk.validate_spots({"id": "x", "pos": [0, 0], "spots": {}}, data()).size(), 1)
	assert_eq(data().load_errors.size(), 0)


func test_qingshi_spots_keep_40px_from_places() -> void:
	var places: Array = data().regions["qingshi_village"]["places"]
	for npc: Dictionary in data().npcs.values():
		for key: String in npc.get("spots", {}):
			if key == "rest_weekday":
				continue
			var p := Vector2(float(npc["spots"][key][0]), float(npc["spots"][key][1]))
			for place: Dictionary in places:
				var pp := Vector2(float(place["pos"][0]), float(place["pos"][1]))
				assert_true(p.distance_to(pp) >= 40.0, "%s %s is near %s" % [npc["id"], key, place.get("display_name", "")])


func test_game_state_places_villager_by_the_day() -> void:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Spots", gs.data, seeded_rng(4242)))
	GameClock.total_days = MARKET_DAY
	gs.world_events = []
	var spot: Dictionary = gs.npc_spot("elder_mo")
	if Weather.of(gs.data, "qingshi_village", MARKET_DAY) in ["rain", "storm"]:
		assert_eq(spot["why"], "rain")
	else:
		assert_eq(spot["why"], "market")
	assert_eq(gs.npc_spot("nobody")["why"], "home")
