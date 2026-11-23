extends TestCase
## SectContestCard (WU-611): the outer-sect contest as a moment. Ladder, odds, offer from the hall, a result card per bout.

func _frames(n: int = 4) -> void:
	for i in n:
		await (Engine.get_main_loop() as SceneTree).process_frame


func _setup(hud_out: Array) -> Node:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	gs.pending_event = ""
	gs.player.alignment = 0
	gs.player.realm_index = maxi(gs.player.realm_index, 1)
	gs.join_sect("azure_cloud_sect")
	gs.player.sect["reported"] = true
	var contest: Dictionary = gs.data.sects["azure_cloud_sect"].contest
	root.get_node("GameClock").total_days = (int(contest["month"]) - 1) * Calendar.DAYS_PER_MONTH
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	hud_out.append(hud)
	return gs


func _teardown(gs: Node, hud: CanvasLayer) -> void:
	gs.end_session()
	hud.get_parent().remove_child(hud)
	hud.free()


func test_pure_text() -> void:
	assert_eq(SectContestCard.prize_text({"contribution": 10, "spirit_stones": 15}), "10 contribution, 15 spirit stones")
	assert_eq(SectContestCard.prize_text({}), "no prize")
	assert_eq(SectContestCard.result_subtitle({"round": 2, "rounds": 3, "won": true}), "Round 2 of 3: won")
	assert_true(SectContestCard.result_text({"round": 2, "won": false, "foe": "Boxer"}).contains("You placed in round 2"))
	assert_true(SectContestCard.result_text({"round": 3, "won": true, "foe": "Boxer", "prize": {"contribution": 40}, "next_foe": ""}).contains("every round"))


func test_card_lists_the_ladder_and_odds() -> void:
	var out: Array = []
	var gs := _setup(out)
	var hud: CanvasLayer = out[0]
	await _frames()
	var card: SectContestCard = hud.get("_sect_contest_card")
	assert_true(card.open(gs.player, gs.data, gs.get_node("/root/GameClock").total_days))
	var t := card.all_text()
	assert_true(t.contains("outer-sect contest"), t)
	assert_true(t.contains("Round 1:") and t.contains("Round 3:"), t)
	assert_true(t.contains(" in 100)"), t)
	await _frames()
	assert_true(card.enter_button().has_focus() or card.back_button().has_focus(), "a button holds focus")
	_teardown(gs, hud)


func test_offer_opens_card_and_wrong_month_does_not() -> void:
	var out: Array = []
	var gs := _setup(out)
	var hud: CanvasLayer = out[0]
	await _frames()
	var card: SectContestCard = hud.get("_sect_contest_card")
	gs.offer_sect_contest()
	await _frames()
	assert_true(card.visible)
	assert_true(hud.call("_is_blocking"))
	card.close()
	assert_false(gs.player.sect.has("contest_year"), "Not yet enters nothing")
	gs.get_node("/root/GameClock").total_days = 0
	gs.offer_sect_contest()
	await _frames()
	assert_false(card.visible, "no card outside the contest month")
	_teardown(gs, hud)


func test_enter_queues_a_result_card_per_bout() -> void:
	var out: Array = []
	var gs := _setup(out)
	var hud: CanvasLayer = out[0]
	await _frames()
	var card: SectContestCard = hud.get("_sect_contest_card")
	gs.offer_sect_contest()
	await _frames()
	card.enter_button().pressed.emit()
	await _frames(6)
	assert_eq(int(gs.player.sect["contest_year"]), Calendar.year_of(gs.get_node("/root/GameClock").total_days))
	# Dismiss whatever cards open (combat report, results) until the queue is empty; at least one result card shows.
	var saw_result := false
	var report: Control = hud.get("_combat_report")
	for i in 20:
		if report.visible:
			report.call("_finish")  # skip the fight animation
			report.close()
		elif (hud.get("_dialogue") as Control).visible:  # an unrelated story talk can open after the fight
			hud.get("_dialogue").close()
		elif card.visible:
			saw_result = saw_result or card.all_text().contains("Round ")
			card.back_button().pressed.emit()
		await _frames(3)
	assert_true(saw_result, "a bout result card was shown")
	_teardown(gs, hud)


func test_hall_row_action_is_the_offer() -> void:
	var out: Array = []
	var gs := _setup(out)
	var hall: Node = load("res://src/world/interactables/sect_hall.gd").new()
	var found := false
	for o: Dictionary in hall.get_options():
		if String(o.get("label", "")).contains("contest"):
			found = true
			assert_eq(o["action"], gs.offer_sect_contest)
	assert_true(found)
	hall.free()
	_teardown(gs, out[0])
