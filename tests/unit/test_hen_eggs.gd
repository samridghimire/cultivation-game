extends TestCase
## CRIT-001: hens may leave an egg each day.

func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _hens(chance: float) -> Array:
	return [{"kind": "hen", "pos": [150, 412], "lays": {"item": "hen_egg", "chance": chance}},
		{"kind": "duck", "pos": [640, 225]},
		{"kind": "hen", "pos": [205, 418], "lays": {"item": "hen_egg", "chance": chance}}]


func test_deterministic_and_chance_bounds() -> void:
	var a := Critters.eggs_today("r", _hens(0.5), 40)
	assert_eq(a, Critters.eggs_today("r", _hens(0.5), 40), "same day, same eggs")
	assert_eq(Critters.eggs_today("r", _hens(0.0), 40).size(), 0, "chance 0 lays none")
	var all := Critters.eggs_today("r", _hens(1.0), 40)
	assert_eq(all.size(), 2, "one per hen, never the duck")
	assert_true((all[0]["pos"] as Vector2).distance_to(Vector2(150, 412)) < 40.0)
	var days_with_egg := 0
	for d in 40:
		days_with_egg += 1 if Critters.eggs_today("r", _hens(0.5), d).size() > 0 else 0
	assert_true(days_with_egg > 10 and days_with_egg < 40, "chance 0.5 varies by day")


func test_pick_egg_gone_today_back_tomorrow() -> void:
	var gs := _gs()
	gs.start_session(CharacterFactory.create("Egger", gs.data, seeded_rng(5)))
	gs.data.regions["qingshi_village"]["map"]["ambient_critters"][0]["lays"]["chance"] = 1.0
	GameClock.total_days = 10
	var eggs: Array[Dictionary] = gs.eggs_here()
	assert_true(eggs.size() >= 1)
	var idx := int(eggs[0]["index"])
	var before := eggs.size()
	assert_true(gs.pick_egg(idx))
	assert_eq(gs.player.item_count("hen_egg"), 1)
	assert_eq(gs.eggs_here().size(), before - 1)
	assert_false(gs.pick_egg(idx), "gone the same day")
	GameClock.total_days = 11
	assert_true(gs.eggs_here().any(func(e: Dictionary) -> bool: return int(e["index"]) == idx), "back the next day")
	assert_true(gs.pick_egg(idx))
	assert_eq(gs.player.item_count("hen_egg"), 2)


func test_egg_flag_round_trip_and_validation() -> void:
	var flags := {}
	Critters.mark_egg(flags, "r", 2, 7)
	var back: Dictionary = JSON.parse_string(JSON.stringify(flags))
	assert_eq(Critters.eggs_left("r", _hens(1.0), 7, back).size(), 1)
	assert_eq(Critters.eggs_left("r", _hens(1.0), 8, back).size(), 2, "a new day resets")
	var region := {"id": "r", "map": {"ambient_critters": [{"kind": "hen", "pos": [1, 1], "lays": {"item": "hen_egg", "chance": 1.5}}]}}
	assert_false(Critters.validate(region).is_empty(), "chance range")
	region["map"]["ambient_critters"][0]["lays"] = {"item": "nope", "chance": 0.5}
	assert_false(Critters.validate(region, _gs().data.items).is_empty(), "unknown item")
	region["map"]["ambient_critters"][0] = {"kind": "duck", "pos": [1, 1], "lays": {"item": "hen_egg", "chance": 0.5}}
	assert_false(Critters.validate(region, _gs().data.items).is_empty(), "only hens lay")
