extends TestCase
## RV-018: the Founder's Old Well (inheritance place) offers the daily draw once the well project is whole.

func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _start() -> CharacterData:
	var gs := _gs()
	var c := CharacterFactory.create("Drawer", gs.data, seeded_rng(5))
	gs.start_session(c)
	return c


func test_draw_lives_on_the_founder_well_only() -> void:
	_start()
	var founder := 0
	for p: Dictionary in _gs().data.regions["qingshi_village"]["places"]:
		assert_true(p["type"] != "well", "no second well place beside the Founder's Old Well")
		if p["type"] == "inheritance" and p["display_name"] == InheritanceGrounds.WELL_NAME:
			founder += 1
	assert_eq(founder, 1, "the Founder's Old Well is the inheritance place")


func test_option_disabled_then_enabled_and_drawn_once() -> void:
	var c := _start()
	var gs := _gs()
	var node := InheritanceGrounds.new()
	node.display_name = InheritanceGrounds.WELL_NAME
	var shrine_n := (SeasonTasks.restoration(gs.data).get("stages", []) as Array).size()
	var seasons: Array = []
	for i in shrine_n + 2:
		seasons.append("s%d" % i)
	c.seasons_completed.assign(seasons)
	assert_eq(node.label_text(), "Founder's Old Well (2/3)")
	assert_true(node.get_options()[0]["disabled"], "no draw before stage 3")
	seasons.append("last")
	c.seasons_completed.assign(seasons)
	assert_eq(node.label_text(), "Founder's Old Well")
	var opt: Dictionary = node.get_options()[0]
	assert_eq(opt["label"], "Draw water")
	assert_false(opt["disabled"])
	assert_true(gs.draw_well_water())
	assert_true(node.get_options()[0]["disabled"], "drawn once a day")
	assert_false(gs.draw_well_water())
	node.free()


func test_board_line_names_current_project() -> void:
	var c := _start()
	var data: GameData = _gs().data
	var n := (SeasonTasks.restoration(data).get("stages", []) as Array).size()
	var seasons: Array = []
	for i in n + 1:
		seasons.append("s%d" % i)
	c.seasons_completed.assign(seasons)
	assert_true(SeasonBoard.shrine_line(c, data).begins_with("The Founder's Old Well: 1 of 3"), SeasonBoard.shrine_line(c, data))
