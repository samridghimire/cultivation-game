extends TestCase
## WU-652: the "Travel home (N days)" button on a home-news letter.


func test_button_hidden_by_default_and_shown_with_travel_to() -> void:
	var card := LetterCard.new()
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	root.add_child(card)
	card.open("xiao_ling", "Xiao Ling", "Hello.")
	assert_false(card.travel_button().visible)
	card.close()
	card.open("xiao_ling", "Xiao Ling", "Hello.", {}, 0, "qingshi_village", 10)
	assert_true(card.travel_button().visible)
	assert_eq(card.travel_button().text, "Travel home (10 days)")
	card.close()
	card.open("xiao_ling", "Xiao Ling", "Hello.", {}, 0, "qingshi_village", 1)
	assert_eq(card.travel_button().text, "Travel home (1 day)")
	card.queue_free()


func test_pressing_travels() -> void:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Walker", gs.data, seeded_rng()))
	var card := LetterCard.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(card)
	var from: String = gs.current_region
	var target := "qingshi_village"
	if from == target:
		for rid: String in gs.data.regions:
			if rid != target and Exploration.check_travel(gs.player, gs.data, target, rid)["ok"]:
				gs.current_region = rid
				break
	var away: String = gs.current_region
	if away == target:
		card.queue_free()
		return
	card.open("xiao_ling", "Xiao Ling", "Hello.", {}, 0, target, 3)
	card.travel_button().pressed.emit()
	assert_false(card.visible)
	assert_eq(gs.current_region, target)
	card.queue_free()


func test_is_home_news() -> void:
	var d := data()
	var c := new_character()
	var id := "xiao_ling"
	var npcs := {id: new_character(5)}
	npcs[id].name = "Xiao Ling"
	assert_false(Letters.is_home_news(c, d, npcs, id, "anything"))
	c.friend_news[id] = {"kind": "qi_start", "day": 3}
	var text: String = Letters._home_news_text(d, id, "Xiao Ling", c.friend_news[id])
	assert_true(Letters.is_home_news(c, d, npcs, id, text))
	assert_false(Letters.is_home_news(c, d, npcs, id, "A different letter."))
