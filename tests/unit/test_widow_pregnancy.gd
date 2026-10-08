extends TestCase
## QA-20261003-5: a widowed NPC still carrying her late husband's child can
## marry the player (Family.check_partner only counts living spouses). Her
## pregnancy must progress once per day, not twice (NpcFamilies and GameState
## both used to advance it), and she must give birth exactly once.


func _game_state() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _pregnant_widow(gs: Node) -> CharacterData:
	var region: String = gs.current_region
	var husband := Npcs.spawn(gs.npcs, gs.data, seeded_rng(11), {"region": region, "age_years": 30, "gender": "male"})
	var widow := Npcs.spawn(gs.npcs, gs.data, seeded_rng(12), {"region": region, "age_years": 25, "gender": "female"})
	husband.gender = "male"
	widow.gender = "female"
	Family.marry(widow, husband, "wife")
	widow.pregnancy = {"partner": husband.id, "days_left": 200}
	husband.alive = false
	return widow


func test_widow_pregnancy_advances_once_after_remarrying_player() -> void:
	var gs := _game_state()
	var c := CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male")
	gs.start_session(c)
	var widow := _pregnant_widow(gs)
	Family.marry(c, widow, "wife")
	gs._pass_time(Calendar.DAYS_PER_MONTH)
	var left := int(widow.pregnancy.get("days_left", -1))
	gs.end_session()
	assert_eq(left, 200 - Calendar.DAYS_PER_MONTH, "one month of pregnancy per month of time")


func test_widow_gives_birth_once_after_remarrying_player() -> void:
	var gs := _game_state()
	var c := CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male")
	gs.start_session(c)
	var widow := _pregnant_widow(gs)
	Family.marry(c, widow, "wife")
	gs._pass_time(Calendar.DAYS_PER_YEAR)
	var children := widow.children.size()
	var pregnant := Children.is_pregnant(widow)
	var players_children := c.children.size()
	gs.end_session()
	assert_eq(children, 1, "the late husband's child is born exactly once")
	assert_false(pregnant, "no longer pregnant after the birth")
	assert_eq(players_children, 0, "the child is the late husband's, not the player's")
