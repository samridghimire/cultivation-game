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
