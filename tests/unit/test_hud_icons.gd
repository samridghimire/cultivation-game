extends TestCase
## GFX-031: the HUD status card draws lamps, a stone icon, a styled qi bar and season/weather icons.

const HudScript := preload("res://src/ui/hud.gd")
## Status card height at day 0 before GFX-031 was 4 px under this bound; the card must not grow past it.
const MAX_CARD_HEIGHT := 170.0


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _hud(lives: int) -> CanvasLayer:
	var root := _tree().root
	root.size = Vector2i(1280, 800)
	var gs: Node = root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	gs.pending_event = ""
	gs.player.artifact_lives = lives
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	return hud


func _lamps(hud: CanvasLayer) -> Array[TextureRect]:
	var out: Array[TextureRect] = []
	for c in (hud.get("_lives") as Control).get_children():
		if c is TextureRect:
			out.append(c)
	return out


func test_icon_textures() -> void:
	assert_eq(HudIcons.lamp(true).get_size(), Vector2(HudIcons.LAMP_SIZE))
	assert_eq(HudIcons.lamp(false).get_size(), Vector2(HudIcons.LAMP_SIZE))
	assert_true(HudIcons.lamp(true) != HudIcons.lamp(false))
	for s in ["Spring", "Summer", "Autumn", "Winter"]:
		assert_eq(HudIcons.season(s).get_size(), Vector2(12, 12), s)
	for k in Weather.KINDS:
		assert_eq(HudIcons.weather(k).get_size(), Vector2(12, 12), k)
	assert_true(HudIcons.weather("meteors") == null)
	assert_true(HudIcons.season("Monsoon") == null)


func test_lamps_for_lives() -> void:
	var hud := _hud(3)
	await _tree().process_frame
	assert_eq(_lamps(hud).size(), 3)
	assert_true(_lamps(hud)[0].texture == HudIcons.lamp(true))
	assert_eq((hud.get("_lives_extra") as Label).text, "")
	GameState.player.artifact_lives = 7
	hud.call("_refresh")
	assert_eq(_lamps(hud).size(), 5)
	assert_eq((hud.get("_lives_extra") as Label).text, "x 2")
	GameState.player.artifact_lives = 0
	hud.call("_refresh")
	assert_eq(_lamps(hud).size(), 1)
	assert_true(_lamps(hud)[0].texture == HudIcons.lamp(false))
	assert_eq((hud.get("_lives_extra") as Label).text, "Final life")
	GameState.player.artifact_lives = -1
	hud.call("_refresh")
	assert_false((hud.get("_lives") as Control).visible)
	hud.queue_free()
	GameState.end_session()


func test_stones_and_date_icons() -> void:
	var hud := _hud(3)
	await _tree().process_frame
	assert_eq((hud.get("_currency") as Label).text.split(" ")[0], str(GameState.player.item_count("spirit_stone")))
	assert_true((hud.get("_stone_icon") as TextureRect).texture != null)
	assert_true((hud.get("_season_icon") as TextureRect).texture != null)
	assert_true((hud.get("_weather_icon") as TextureRect).texture != null)
	assert_true((hud.get("_date_row") as Control).tooltip_text.contains("tomorrow"))
	var bar := hud.get("_qi_bar") as ProgressBar
	assert_true(bar.has_theme_stylebox_override("background"), "the trough exists even at 0 qi")
	hud.queue_free()
	GameState.end_session()


func test_status_card_height_at_day_zero() -> void:
	var hud := _hud(3)
	for i in 4:
		await _tree().process_frame
	var h := (hud.get("_status_panel") as Control).size.y
	assert_true(h <= MAX_CARD_HEIGHT, "status card %.0f px" % h)
	hud.queue_free()
	GameState.end_session()


func test_lamp_counts() -> void:
	assert_eq(HudScript.lamp_count(0), 1)
	assert_eq(HudScript.lamp_count(9), 5)
	assert_eq(HudScript.lives_extra_text(5), "")
	assert_eq(HudScript.lives_extra_text(6), "x 1")
