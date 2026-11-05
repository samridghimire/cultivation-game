extends TestCase
## WU-443: the road card text, timing and clean-up.

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func test_text_for() -> void:
	assert_eq(RoadCard.text_for("Qingshi Village", "Misty Forest", 3, 0), "Qingshi Village -> Misty Forest · 3 days")
	assert_eq(RoadCard.text_for("A", "B", 1, 0), "A -> B · 1 day")
	assert_true(RoadCard.text_for("A", "B", 4, 1).contains("+1 day, snow"))


func test_line_fills_over_a_second() -> void:
	assert_eq(RoadCard.dots_filled(0.0, 24), 0)
	assert_eq(RoadCard.dots_filled(RoadCard.FADE_IN + RoadCard.LINE_SECONDS, 24), 24)
	assert_true(RoadCard.dots_filled(0.8, 24) > 0 and RoadCard.dots_filled(0.8, 24) < 24)


func test_total_time_within_budget() -> void:
	assert_true(RoadCard.FADE_IN + RoadCard.LINE_SECONDS + RoadCard.FADE_OUT <= RoadCard.TOTAL_SECONDS)
	assert_true(RoadCard.TOTAL_SECONDS <= 1.8)


func test_dim_alpha_fades_in_and_out() -> void:
	assert_eq(RoadCard.dim_alpha(0.0, 1.8, 0.3, 0.3), 0.0)
	assert_eq(RoadCard.dim_alpha(0.9, 1.8, 0.3, 0.3), 1.0)
	assert_eq(RoadCard.dim_alpha(1.8, 1.8, 0.3, 0.3), 0.0)


func test_card_frees_itself_and_input_works_after() -> void:
	var card := RoadCard.show_over(_tree(), "A -> B · 1 day", true)
	assert_true(card != null)
	for i in 30:
		await _tree().process_frame
		if not is_instance_valid(card):
			break
	await _tree().process_frame
	assert_false(is_instance_valid(card))


func test_any_key_skips() -> void:
	var card := RoadCard.show_over(_tree(), "A -> B · 1 day", false)
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	card._input(ev)
	await _tree().process_frame
	await _tree().process_frame
	assert_false(is_instance_valid(card))



func test_detail_line_text() -> void:
	assert_eq(RoadCard.detail_for(""), "")
	assert_eq(RoadCard.detail_for("Rain Shelter"), "On the way: Rain Shelter")
	assert_eq(RoadCard.encounter_name(null, "road_rain_shelter"), "")
	var data := GameData.load_from_dir()
	assert_eq(RoadCard.encounter_name(data, "road_rain_shelter"), "Rain Shelter")
	assert_eq(RoadCard.encounter_name(data, ""), "")


func test_finished_fires_on_skip_and_sets_current() -> void:
	var card := RoadCard.show_over(_tree(), "A -> B · 1 day", false, "On the way: X")
	assert_true(RoadCard.current == card)
	var state := {"n": 0}
	card.finished.connect(func(): state["n"] += 1)
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	card._input(ev)
	card._input(ev)
	assert_eq(state["n"], 1)
	assert_true(RoadCard.current == null)
	await _tree().process_frame


func test_finished_fires_with_reduce_motion() -> void:
	var card := RoadCard.show_over(_tree(), "A -> B · 1 day", true)
	var state := {"n": 0}
	card.finished.connect(func(): state["n"] += 1)
	for i in 40:
		await _tree().process_frame
		if state["n"] > 0:
			break
	assert_eq(state["n"], 1)
	assert_true(RoadCard.current == null)
