extends TestCase
## RealmCard (WU-137): the extra lines under the realm description.


func test_card_lines_skips_empty() -> void:
	var lines := RealmCard.card_lines("desc", "", ["", "New: Alchemy"])
	assert_eq(lines.size(), 1)
	assert_eq(lines[0], "New: Alchemy")


func test_card_lines_caps_at_three() -> void:
	var lines := RealmCard.card_lines("desc", "Lifespan +50 years", ["a", "b", "c", "d"])
	assert_eq(lines.size(), 3)
	assert_eq(lines[0], "Lifespan +50 years")
	assert_eq(lines[2], "b")


func test_card_lines_empty() -> void:
	assert_eq(RealmCard.card_lines("", "", []).size(), 0)


func test_card_waits_for_the_tribulation_screen() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Wanderer", gs.data, seeded_rng(3)))
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	var trib: TribulationScreen = hud.get("_tribulation")
	var card: RealmCard = hud.get("_realm_card")
	trib.visible = true
	hud.call("_show_realm_card", "Foundation Establishment", "Lifespan +50 years")
	assert_false(card.visible, "no realm card over the tribulation's waves")
	trib.close()
	assert_true(card.visible, "the card shows once the tribulation screen closes")
	card.close()
	hud.call("_show_realm_card", "Foundation Establishment", "")
	assert_true(card.visible, "without a tribulation the card shows at once")
	hud.free()
	gs.end_session()
