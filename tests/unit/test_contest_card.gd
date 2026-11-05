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
