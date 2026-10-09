extends TestCase
## WU-056: seasons derive from the calendar month and tint the world.


func test_season_of_months() -> void:
	assert_eq(Calendar.season_of(0), "Spring")
	assert_eq(Calendar.season_of(3 * 30), "Summer")
	assert_eq(Calendar.season_of(6 * 30), "Autumn")
	assert_eq(Calendar.season_of(11 * 30), "Winter")
	assert_eq(Calendar.season_of(359), "Winter")
	assert_eq(Calendar.season_of(360), "Spring")


func test_tints_differ() -> void:
	var seen := {}
	for s in ["Spring", "Summer", "Autumn", "Winter"]:
		seen[Calendar.season_tint(s)] = true
	assert_eq(seen.size(), 4)


func test_world_tint_follows_season() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var clock := root.get_node("GameClock")
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male"))
	var world: Node = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	assert_eq(world._season_tint.color, Calendar.season_tint("Spring"))
	clock.advance(120)
	# The tween is 0.6s; apply the end state directly to test the target.
	assert_eq(world._season, "Summer")
	await (Engine.get_main_loop() as SceneTree).create_timer(0.8).timeout
	assert_eq(world._season_tint.color, Calendar.season_tint("Summer"))
	world.free()
	gs.end_session()


func test_gather_seasonal_note() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var table: Array = [{"item": "spirit_herb", "weight": 4}, {"item": "spirit_herb", "weight": 3, "seasons": ["spring"]}, {"item": "", "weight": 2}]
	var spring := Exploration.seasonal_note(table, "Spring", gs.data)
	assert_true(spring.begins_with("In season: "), spring)
	assert_true(not spring.contains("Out of season"), spring)
	var autumn := Exploration.seasonal_note(table, "Autumn", gs.data)
	assert_true(autumn.begins_with("Out of season: ") and autumn.contains("(spring)"), autumn)
	assert_eq(Exploration.seasonal_note([table[0], table[2]], "Spring", gs.data), "")
