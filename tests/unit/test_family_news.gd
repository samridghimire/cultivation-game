extends TestCase
## QA-20261003-2: news about the player's own family (children, parents,
## spouses) must reach the message log even when they are generated NPCs the
## player never built favor with.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _game_state() -> Node:
	return _root().get_node("GameState")


func test_is_newsworthy_strangers_vs_family() -> void:
	var player := new_character()
	player.spouses = ["gen_1"]
	player.children = ["gen_2"]
	player.parents = ["gen_3"]
	var favor := {"gen_4": 5}
	assert_true(Npcs.is_newsworthy("gen_1", player, favor), "spouse")
	assert_true(Npcs.is_newsworthy("gen_2", player, favor), "child")
	assert_true(Npcs.is_newsworthy("gen_3", player, favor), "parent")
	assert_true(Npcs.is_newsworthy("gen_4", player, favor), "someone the player knows")
	assert_false(Npcs.is_newsworthy("gen_5", player, favor), "a generated stranger is noise")
	assert_true(Npcs.is_newsworthy("elder_mo", player, favor), "named NPCs are always news")


func test_death_of_generated_child_is_reported() -> void:
	var gs := _game_state()
	var c := CharacterFactory.create("Parent", gs.data, seeded_rng(77))
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	var child := Npcs.spawn(gs.npcs, gs.data, seeded_rng(5), {"region": gs.current_region, "cultivates": false})
	child.spiritual_roots = {}
	child.age_days = (Cultivation.lifespan_years(child, gs.data) - 1) * Calendar.DAYS_PER_YEAR
	child.parents = [c.id]
	c.children.append(child.id)
	var log: Array[String] = []
	var on_post := func(text: String, _category: String) -> void: log.append(text)
	EventBus.message_posted.connect(on_post)
	gs._pass_time(Calendar.DAYS_PER_YEAR)
	EventBus.message_posted.disconnect(on_post)
	gs.end_session()
	assert_false(child.alive, "the child should have died of old age")
	var reported := false
	for line in log:
		if line.contains(child.name) and line.contains("died"):
			reported = true
	assert_true(reported, "the player hears that their child died")
