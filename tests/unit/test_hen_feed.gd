extends TestCase
## CRIT-002: scatter grain at the coop; the next day's eggs are sure and may be two.


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _hens(chance: float) -> Array:
	return [{"kind": "hen", "pos": [150, 412], "lays": {"item": "hen_egg", "chance": chance, "feed": {"item_tag": "grain", "eggs_min": 1, "eggs_max": 2}}}]


func test_roll_with_and_without_feeding() -> void:
	var plain := 0
	var fed := 0
	var twos := 0
	for d in 60:
		plain += Critters.eggs_today("r", _hens(0.3), d, "spring", false).size()
		var f := Critters.eggs_today("r", _hens(0.3), d, "spring", true)
		fed += f.size()
		for e in f:
			assert_true(int(e["count"]) >= 1 and int(e["count"]) <= 2)
			twos += 1 if int(e["count"]) == 2 else 0
	assert_true(plain < 60 and plain > 0)
	assert_eq(fed, 60, "fed hens lay every day")
	assert_true(twos > 5 and twos < 55, "sometimes two")
	assert_eq(Critters.eggs_today("r", _hens(0.0), 3, "spring", false).size(), 0)
	assert_eq(Critters.eggs_today("r", _hens(0.0), 3, "winter", true).size() , 1, "winter hens lay too")


func test_validate_feed() -> void:
	var region := {"id": "r", "map": {"ambient_critters": _hens(0.5)}}
	assert_true(Critters.validate(region, _gs().data.items).is_empty())
	region["map"]["ambient_critters"][0]["lays"]["feed"]["eggs_max"] = 9
	assert_false(Critters.validate(region, _gs().data.items).is_empty())


func test_feed_action() -> void:
	var gs := _gs()
	gs.start_session(CharacterFactory.create("Feeder", gs.data, seeded_rng(5)))
	gs.current_region = "qingshi_village"
	GameClock.total_days = 20
	assert_true(gs.feed_hens_refusal() != "", "no grain")
	assert_false(gs.feed_hens())
	gs.player.add_item("millet", 2)
	assert_true(gs.feed_hens())
	assert_eq(gs.player.item_count("millet"), 1)
	assert_false(gs.feed_hens(), "once a day")
	assert_eq(gs.player.item_count("millet"), 1)
	var today := Guidance.today_lines(gs.player, gs.data, gs.world_flags, gs.world_events, 20, "qingshi_village")
	assert_true(today.has("The hens are fed"))
	GameClock.total_days = 21
	var eggs: Array[Dictionary] = gs.eggs_here()
	var season := Calendar.season_of(21).to_lower()
	assert_eq(eggs.size(), Critters.eggs_today("qingshi_village", gs.data.regions["qingshi_village"]["map"]["ambient_critters"], 21, season, true).size())
	assert_true(eggs.size() >= 1 and eggs.size() <= 3, "hens lay surely")
	# flag survives a JSON round trip
	var back: Dictionary = JSON.parse_string(JSON.stringify(gs.world_flags))
	assert_true(Critters.fed_for(back, "qingshi_village", 21))
	assert_true(gs.feed_hens(), "a new day")


func test_pick_gives_count() -> void:
	var gs := _gs()
	gs.start_session(CharacterFactory.create("Feeder", gs.data, seeded_rng(5)))
	gs.current_region = "qingshi_village"
	GameClock.total_days = 40
	gs.player.add_item("millet", 1)
	gs.feed_hens()
	GameClock.total_days = 41
	var total := 0
	for e in gs.eggs_here():
		total += int(e["count"])
		assert_true(gs.pick_egg(int(e["index"])))
	assert_eq(gs.player.item_count("hen_egg"), total)
	assert_true(total >= 1)
