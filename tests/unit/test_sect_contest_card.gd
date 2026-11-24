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


func test_rival_in_the_final_round() -> void:
	var out: Array = []
	var gs := _setup(out)
	var hud: CanvasLayer = out[0]
	await _frames()
	var rival := Rivals.spawn(gs.player, gs.npcs, gs.data, seeded_rng(6), "qingshi_village")
	rival.realm_index = gs.player.realm_index
	rival.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0}
	var card: SectContestCard = hud.get("_sect_contest_card")
	var days: int = gs.get_node("/root/GameClock").total_days
	assert_true(card.open(gs.player, gs.data, days, UIStyle.ACCENT, rival))
	var t := card.all_text()
	assert_true(t.contains("Your rival %s waits in the final round." % rival.name), t)
	var lines := SectContestCard.ladder_lines(gs.player, gs.data, 0, rival)
	assert_true(lines[lines.size() - 1].contains(rival.name), lines[lines.size() - 1])
	assert_false(lines[0].contains(rival.name))
	card.close()
	# No rival in the sect: the generic ladder and no rival line.
	rival.sect = {}
	assert_true(card.open(gs.player, gs.data, days, UIStyle.ACCENT, rival))
	assert_false(card.all_text().contains("waits in the final round"))
	card.close()
	# Result card naming the rival as the next foe.
	card.open_result("Azure", {"round": 2, "rounds": 3, "won": true, "foe": "Boxer", "prize": {}, "next_foe": rival.name, "next_rival": true, "next_chance": 0.5})
	assert_true(card.all_text().contains("Your rival %s waits in the final round." % rival.name))
	assert_true(SectContestCard.result_text({"round": 3, "won": false, "foe": rival.name, "rival": true}).contains("Your rival " + rival.name))
	card.close()
	_teardown(gs, hud)


func test_arena_mode_follows_the_bout_result() -> void:
	var out: Array = []
	var gs := _setup(out)
	var hud: CanvasLayer = out[0]
	await _frames()
	var card: SectContestCard = hud.get("_sect_contest_card")
	assert_true(card.open(gs.player, gs.data, gs.get_node("/root/GameClock").total_days))
	assert_eq(card.arena().mode, "ready")
	card.open_result("Azure", {"round": 1, "rounds": 3, "won": true, "foe": "Boxer", "prize": {}, "next_foe": "X"})
	assert_eq(card.arena().mode, "won")
	card.open_result("Azure", {"round": 2, "rounds": 3, "won": false, "foe": "Boxer"})
	assert_eq(card.arena().mode, "lost")
	assert_true(card.arena().foe_look.is_empty(), "a plain foe uses the default look")
	_teardown(gs, hud)


func test_rival_round_names_and_looks_like_the_rival() -> void:
	var out: Array = []
	var gs := _setup(out)
	var hud: CanvasLayer = out[0]
	await _frames()
	var card: SectContestCard = hud.get("_sect_contest_card")
	var rival := CharacterFactory.create("Han", gs.data, seeded_rng(9), "male")
	rival.id = "test_rival"
	gs.npcs["test_rival"] = rival
	card.open_result("Azure", {"round": 3, "rounds": 3, "won": true, "foe": "Han", "rival": true, "foe_person": "test_rival", "prize": {}, "next_foe": ""})
	assert_false(card.arena().foe_look.is_empty(), "the foe wears the rival's look")
	assert_eq(card.arena().rival_name, "Han")
	assert_true(card.all_text().to_lower().contains("your rival han"), card.all_text())
	card.open_result("Azure", {"round": 3, "rounds": 3, "won": false, "foe": "Han", "rival": true, "foe_person": "test_rival"})
	assert_true(card.all_text().contains("beats you"), card.all_text())
	_teardown(gs, hud)
