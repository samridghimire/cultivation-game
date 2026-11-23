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
