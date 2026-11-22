extends TestCase
## SectCard (WU-602): opens on sect_joined with the sect name and first step, Continue has focus, close emits, blocks the HUD.

func _frames(n: int = 4) -> void:
	for i in n:
		await (Engine.get_main_loop() as SceneTree).process_frame


func test_home_line() -> void:
	assert_eq(SectCard.home_line({"home_days": 0, "home_region_name": "Azure Peak"}), "You are at the sect's home")
	assert_eq(SectCard.home_line({"home_days": 3, "home_region_name": "Azure Peak"}), "Home: Azure Peak, 3 days' walk")
	assert_eq(SectCard.home_line({"home_days": 1, "home_region_name": "Azure Peak"}), "Home: Azure Peak, 1 day's walk")


func test_hud_opens_card_on_join() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	gs.pending_event = ""
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames()
	var card: SectCard = hud.get("_sect_card")
	assert_false(card.visible)
	var blocked_before: bool = hud.call("_is_blocking")
	gs.player.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0}
	EventBus.sect_joined.emit("azure_cloud_sect")
	await _frames()
	assert_true(card.visible)
	assert_true(card.all_text().contains("Azure Cloud Sect"))
	assert_true(card.all_text().contains("First step:"))
	assert_true(card.button().has_focus(), "Continue holds focus for the gamepad")
	assert_true(hud.call("_is_blocking"), "the card blocks the HUD")
	var closed := [false]
	card.closed.connect(func() -> void: closed[0] = true)
	card.close()
	assert_true(closed[0])
	await _frames()
	assert_eq(hud.call("_is_blocking"), blocked_before, "closing the card releases only its own block")
	gs.end_session()
	root.remove_child(hud)
	hud.free()


func test_promotion_card() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	gs.pending_event = ""
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames()
	var card: SectCard = hud.get("_sect_card")
	gs.player.sect = {"id": "azure_cloud_sect", "rank": 1, "contribution": 0}
	EventBus.sect_promoted.emit("azure_cloud_sect", 1)
	await _frames()
	assert_true(card.visible)
	assert_true(card.all_text().contains("Promoted: "))
	assert_true(card.all_text().contains("Next rank:"), "a next rank is shown mid-ladder")
	assert_true(card.button().has_focus())
	card.close()
	var top: int = gs.data.sects["azure_cloud_sect"].ranks.size() - 1
	gs.player.sect = {"id": "azure_cloud_sect", "rank": top, "contribution": 0}
	EventBus.sect_promoted.emit("azure_cloud_sect", top)
	await _frames()
	assert_true(card.visible)
	assert_false(card.all_text().contains("Next rank:") or card._step.visible, "no Next rank row at the top")
	card.close()
	gs.end_session()
	root.remove_child(hud)
	hud.free()


## Review: a promotion from the mission board (which stays open) waits for it to close, then takes focus.
func test_promotion_waits_for_open_menu() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	gs.pending_event = ""
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames()
	var card: SectCard = hud.get("_sect_card")
	var menu: Control = hud.get("_choice_menu")
	gs.player.sect = {"id": "azure_cloud_sect", "rank": 1, "contribution": 0}
	menu.visible = true
	EventBus.sect_promoted.emit("azure_cloud_sect", 1)
	await _frames()
	assert_false(card.visible, "the promotion card waits while a menu is open")
	menu.visible = false
	hud.call("_update_modal")
	await _frames()
	assert_true(card.visible, "it plays once the menu closes")
	assert_true(card.button().has_focus())
	card.close()
	gs.end_session()
	root.remove_child(hud)
	hud.free()


func test_perk_line() -> void:
	assert_eq(SectCard.perk_line("gather qi x1.5"), "Gather qi 1.5x faster")
	assert_eq(SectCard.perk_line("hear Elder Feng's lecture each month"), "Hear Elder Feng's lecture each month")


func test_hall_services_for_fresh_disciple() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var c := CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male")
	assert_eq(Guidance.hall_services(c, gs.data, "azure_peak", 0).size(), 0, "rogues get no rows")
	c.alignment = 0
	c.realm_index = 1
	assert_true(Sects.join(c, gs.data, "azure_cloud_sect")["ok"])
	var rows := Guidance.hall_services(c, gs.data, "azure_peak", 0)
	assert_true(rows.size() <= 4)
	var text := "\n".join(rows)
	assert_true(text.contains("Mission board:"), text)
	assert_true(text.contains("Next rank:"), text)


func test_report_card_and_queue_behind_menu() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	gs.pending_event = ""
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames()
	var card: SectCard = hud.get("_sect_card")
	gs.player.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0}
	var menu: Control = hud.get("_choice_menu")
	menu.visible = true
	EventBus.sect_joined.emit("azure_cloud_sect")
	await _frames()
	assert_false(card.visible, "the join card waits while the hall menu is open")
	menu.visible = false
	hud.call("_update_modal")
	await _frames()
	assert_true(card.visible, "it plays once the menu closes")
	card.close()
	await _frames()
	var item_id := String(gs.data.items.keys()[0])
	gs.last_report_line = "Welcome, Lin."
	EventBus.sect_reported.emit("azure_cloud_sect", {item_id: 2})
	await _frames()
	assert_true(card.visible)
	var text := card.all_text()
	assert_true(text.contains("Welcome to the hall"), text)
	assert_true(text.contains("Welcome, Lin."), text)
	assert_true(text.contains("2 x %s" % gs.data.items[item_id].name), text)
	assert_true(card.button().has_focus())
	card.close()
	gs.end_session()
	root.remove_child(hud)
	hud.free()
