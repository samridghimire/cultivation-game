extends TestCase
## ContestCard (WU-454): the contest podium text, tint and focus.

func _result() -> Dictionary:
	return {"event_id": "lantern_festival", "name": "Lantern Riddles", "place": 2, "total": 3,
		"scores": [{"name": "Mei Lan", "score": 14, "you": false}, {"name": "You", "score": 12, "you": true}, {"name": "a stranger", "score": 7, "you": false}],
		"prize": {"renown": 1, "items": {}}, "text": "Mei Lan took it."}


func test_place_and_prize_lines() -> void:
	assert_eq(ContestCard.place_line(_result()), "You place 2nd of 3.")
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	assert_eq(ContestCard.prize_line(_result(), gs.data), "Prize: +1 renown.")
	var none := _result()
	none["prize"] = {}
	assert_eq(ContestCard.prize_line(none, gs.data), "")


func test_tints_differ_per_festival() -> void:
	assert_true(ContestCard.tint_for("lantern_festival") != ContestCard.tint_for("qingming_festival"))
	assert_eq(ContestCard.tint_for("unknown"), ContestCard.DEFAULT_TINT)


func test_card_shows_standings_and_takes_focus() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var card := ContestCard.new()
	root.add_child(card)
	card.open(_result(), gs.data)
	assert_true(card.visible)
	var rows := card.rows_text()
	assert_eq(rows.size(), 3)
	assert_true(rows[1].begins_with("> ") and rows[1].contains("You"), "the player's row is marked")
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_true(card.button().has_focus(), "the button holds focus for the gamepad")
	card.close()
	assert_false(card.visible)
	card.queue_free()


func test_hud_opens_card_on_contest_finished() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Wanderer", gs.data, seeded_rng(3)))
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	gs.get_node("/root/EventBus").contest_finished.emit(_result())
	await (Engine.get_main_loop() as SceneTree).process_frame
	var card: ContestCard = hud.get("_contest_card")
	assert_true(card.visible)
	card.close()
	hud.queue_free()


func test_cheer_and_remark_text() -> void:
	assert_eq(ContestCard.cheer_text({}), "")
	assert_eq(ContestCard.cheer_text({"cheerers": []}), "")
	assert_eq(ContestCard.cheer_text({"cheerers": ["Lan"]}), "Lan cheered you on (+1).")
	assert_eq(ContestCard.cheer_text({"cheerers": ["Lan", "Wei"]}), "Lan and Wei cheered you on (+2).")
	assert_eq(ContestCard.cheer_text({"cheerers": ["A", "B", "C"]}), "A, B and C cheered you on (+3).")
	assert_eq(ContestCard.remark_text({}), "")
	assert_eq(ContestCard.remark_text({"rival_remark": "Next year."}), "\"Next year.\"")


func test_card_shows_cheer_rival_row_and_remark() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var r := _result()
	r["cheerers"] = ["Lan", "Wei"]
	r["rival_remark"] = "Not bad."
	(r["scores"][0] as Dictionary)["rival"] = true
	var card := ContestCard.new()
	root.add_child(card)
	card.open(r, gs.data)
	assert_true(card.rows_text()[0].contains("(your rival)"))
	assert_true(card.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.visible and l.text == "Lan and Wei cheered you on (+2)."))
	assert_true(card.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.visible and l.text == "\"Not bad.\""))
	card.open(_result(), gs.data)
	assert_false(card.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.visible and l.text.contains("cheered")))
	card.queue_free()


func test_keepsakes_have_distinct_icons() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var kinds := {}
	for id in ["ribbon_of_the_ridge_kite", "champions_drumstick", "paper_moon_crown", "riddle_masters_lantern"]:
		var k := ItemIcon.kind_of(gs.data.items[id])
		assert_false(kinds.has(k), id)
		kinds[k] = true
		assert_true(ItemIcon.for_id(gs.data, id) != null)
		var grey := ItemIcon.greyscale(ItemIcon.for_id(gs.data, id))
	assert_eq(kinds.size(), 4)
