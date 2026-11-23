extends TestCase
## TrialCard (WU-609): the staged promotion trial. Examiner, rank, odds, never-lethal line; "Not yet" fights nothing;
## "Step into the arena" runs the trial; the hall row opens the card; focus for the gamepad.

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
	gs.player.sect["rank"] = 0
	gs.player.sect["contribution"] = 100000
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	hud_out.append(hud)
	return gs


func _teardown(gs: Node, hud: CanvasLayer) -> void:
	gs.end_session()
	hud.get_parent().remove_child(hud)
	hud.free()


func test_pure_lines() -> void:
	assert_eq(TrialCard.odds_line(0.55), "Your odds: Risky (55 in 100)")
	assert_true(TrialCard.default_to_wait(0.29))
	assert_false(TrialCard.default_to_wait(0.3))


func test_card_shows_examiner_rank_and_odds() -> void:
	var out: Array = []
	var gs := _setup(out)
	var hud: CanvasLayer = out[0]
	await _frames()
	var card: TrialCard = hud.get("_trial_card")
	assert_true(card.open(gs.player, gs.data))
	var t := card.all_text()
	assert_true(t.contains("Trial for "), t)
	assert_true(t.contains("Azure Cloud Sword Examiner"), t)
	assert_true(t.contains(" in 100)"), t)
	assert_true(t.contains("never kills"), t)
	assert_gt(card.arena.size.x, 0.0)
	await _frames()
	assert_true(card.step_button().has_focus() or card.wait_button().has_focus(), "a button holds focus")
	_teardown(gs, hud)


func test_not_yet_fights_nothing() -> void:
	var out: Array = []
	var gs := _setup(out)
	var hud: CanvasLayer = out[0]
	await _frames()
	var card: TrialCard = hud.get("_trial_card")
	var days_before: int = gs.get_node("/root/GameClock").total_days
	var stones_before: int = gs.player.item_count("spirit_stone")
	card.open(gs.player, gs.data)
	card.wait_button().pressed.emit()
	assert_false(card.visible)
	assert_eq(int(gs.player.sect["rank"]), 0)
	assert_eq(gs.get_node("/root/GameClock").total_days, days_before)
	assert_eq(gs.player.item_count("spirit_stone"), stones_before)
	_teardown(gs, hud)


func test_step_in_runs_the_trial() -> void:
	var out: Array = []
	var gs := _setup(out)
	var hud: CanvasLayer = out[0]
	await _frames()
	var card: TrialCard = hud.get("_trial_card")
	var days_before: int = gs.get_node("/root/GameClock").total_days
	card.open(gs.player, gs.data)
	card.step_button().pressed.emit()
	assert_false(card.visible)
	assert_gt(gs.get_node("/root/GameClock").total_days, days_before, "the trial took time")
	_teardown(gs, hud)


func test_offer_opens_card_and_blocked_reason_does_not() -> void:
	var out: Array = []
	var gs := _setup(out)
	var hud: CanvasLayer = out[0]
	await _frames()
	var card: TrialCard = hud.get("_trial_card")
	gs.offer_promotion_trial()
	await _frames()
	assert_true(card.visible, "the hall row opens the card")
	assert_true(hud.call("_is_blocking"))
	card.close()
	gs.player.sect["contribution"] = 0
	gs.offer_promotion_trial()
	await _frames()
	assert_false(card.visible, "no card while a requirement is unmet")
	assert_eq(card.open(gs.player, gs.data), false)
	_teardown(gs, hud)


func test_hall_row_action_is_the_offer() -> void:
	var out: Array = []
	var gs := _setup(out)
	var hall: Node = load("res://src/world/interactables/sect_hall.gd").new()
	var trial: Dictionary = hall.trial_option()
	assert_false(trial["disabled"])
	assert_eq(trial["action"], gs.offer_promotion_trial)
	hall.free()
	_teardown(gs, out[0])


## WU-612: "Not yet" from the mission board's rank tab returns to the board, focused.
func test_not_yet_returns_to_board() -> void:
	var out: Array = []
	var gs := _setup(out)
	var hud: CanvasLayer = out[0]
	await _frames()
	hud.call("_on_mission_board_requested")
	var board: MissionBoard = hud.get("_mission_board_n")
	board.open("rank")
	await _frames()
	gs.offer_promotion_trial()
	await _frames()
	var card: TrialCard = hud.get("_trial_card")
	assert_true(card.visible, "trial card up")
	assert_false(board.visible, "board closed behind the card")
	card.wait_button().pressed.emit()
	await _frames()
	assert_false(card.visible)
	assert_true(board.visible, "board reopened after Not yet")
	var f := board.get_viewport().gui_get_focus_owner()
	assert_true(f != null and board.is_ancestor_of(f), "focus inside the board")
	_teardown(gs, hud)


## WU-612: pending news is the dialogue's opening line, read once; folk_news is emptied.
func test_news_opens_the_dialogue() -> void:
	var out: Array = []
	var gs := _setup(out)
	var hud: CanvasLayer = out[0]
	await _frames()
	gs.player.home_region = "qingshi_village"
	gs.current_region = "qingshi_village"
	gs.player.folk_news["elder_mo"] = "sect_join"
	gs.start_dialogue("elder_mo")
	var win: Control = hud.get("_dialogue")
	await _frames()
	assert_true(win.visible, "dialogue open")
	assert_true(win.line_text().contains("\n\n"), "news line leads the node text: " + win.line_text())
	assert_eq(gs.pending_greeting, "", "read once")
	assert_false(gs.player.folk_news.has("elder_mo"), "news consumed")
	_teardown(gs, hud)


## WU-614: a lost trial is told on the card (examiner, what you lacked, injury, odds now) with one focused Back button.
func test_lost_lines_pure() -> void:
	var lines := TrialCard.lost_lines({"examiner": "Elder Wen", "advice": "Heal first: you are injured.",
		"injuries": PackedStringArray(["Bruised ribs"]), "chance": 0.25})
	assert_eq(lines[0], "Elder Wen lowers the wooden sword.")
	assert_eq(lines[1], "Heal first: you are injured.")
	assert_true(lines[2].contains("Bruised ribs"), lines[2])
	assert_eq(lines[3], "Your odds now: Unlikely (25 in 100)".replace("Unlikely", Combat.odds_word(0.25)))
	var unhurt := TrialCard.lost_lines({"examiner": "X", "chance": 0.6})
	assert_eq(unhurt[2], "You come away unhurt.")


func test_lost_trial_opens_result_card_with_back_focus() -> void:
	var out: Array = []
	var gs := _setup(out)
	var hud: CanvasLayer = out[0]
	await _frames()
	var card: TrialCard = hud.get("_trial_card")
	EventBus.promotion_trial_lost.emit("azure_cloud_sect", {"examiner": "Elder Wen", "rank": "Outer Disciple",
		"advice": "Close: train a few more days and try again.", "injuries": PackedStringArray(), "chance": 0.4})
	await _frames()
	assert_true(card.visible)
	var t := card.all_text()
	assert_true(t.contains("lowers the wooden sword"), t)
	assert_true(t.contains("Close: train"), t)
	assert_true(t.contains("Your odds now"), t)
	assert_false(card.step_button().visible)
	assert_eq(card.wait_button().text, "Back")
	assert_true(card.wait_button().has_focus(), "Back holds focus")
	card.wait_button().pressed.emit()
	assert_false(card.visible)
	# the card goes back to trial mode on the next open
	assert_true(card.open(gs.player, gs.data))
	assert_true(card.step_button().visible)
	assert_eq(card.wait_button().text, "Not yet")
	_teardown(gs, hud)


## WU-616: the lost card names the next rank, not the current one, and the arena switches to result mode.
func test_lost_card_names_next_rank_and_arena_result() -> void:
	var out: Array = []
	var gs := _setup(out)
	var hud: CanvasLayer = out[0]
	await _frames()
	var card: TrialCard = hud.get("_trial_card")
	var sect: SectDef = gs.data.sects["azure_cloud_sect"]
	var info := {"examiner": "Elder Wen", "rank": sect.rank_name(1), "chance": 0.4}
	assert_eq(TrialCard.lost_subtitle(info), "Trial for %s: lost" % sect.rank_name(1))
	EventBus.promotion_trial_lost.emit("azure_cloud_sect", info)
	await _frames()
	var t := card.all_text()
	assert_true(t.contains("Trial for %s: lost" % sect.rank_name(1)), t)
	assert_false(t.contains("not yet"), t)
	assert_true(card.arena.result)
	card.wait_button().pressed.emit()
	assert_true(card.open(gs.player, gs.data))
	assert_false(card.arena.result)
	_teardown(gs, hud)


## WU-615: a sect-join news line reaches Xiao Ling's talk (window) and is gone afterwards, however the talk is opened.
func test_news_reaches_xiao_ling_talk() -> void:
	var out: Array = []
	var gs := _setup(out)
	var hud: CanvasLayer = out[0]
	await _frames()
	gs.end_session()
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	gs.pending_event = ""
	gs.player.alignment = 0
	gs.player.realm_index = maxi(gs.player.realm_index, 1)
	gs.current_region = "qingshi_village"
	gs.npc_favor["xiao_ling"] = 60
	gs.join_sect("azure_cloud_sect")
	assert_true(FolkNews.has_pending(gs.player, "xiao_ling"), "news pending after joining")
	var win: Control = hud.get("_dialogue")
	gs.start_dialogue("xiao_ling")
	await _frames()
	assert_true(win.visible, "dialogue open")
	assert_false(FolkNews.has_pending(gs.player, "xiao_ling"), "consumed by the talk")
	var line: String = win.line_text()
	assert_true(line.contains("\n\n"), "news leads the talk: " + line)
	assert_eq(gs.pending_greeting, "", "read once")
	_teardown(gs, hud)
