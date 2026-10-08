extends TestCase
## QA-013: Steam Deck layout check. Opens every HUD screen at 1280x800 (UI
## scale 1.0) for a character with long lists (many items, techniques, family,
## a sect and a clan) and asserts each screen fits inside the viewport.

const DECK := Vector2(1280, 800)

## WU-026: the "UI Scale" setting (a 75-150% slider, applied through the root
## window's content_scale_factor) must keep every screen inside the window.
var _scale := 1.0


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int = 3) -> void:
	for i in n:
		await _tree().process_frame


## A late-game character with something in every list a screen shows.
func _rich_character(gs: Node) -> CharacterData:
	var c := CharacterFactory.create("Lin Feng", gs.data, seeded_rng(5), "male")
	gs.start_session(c)
	gs.pending_event = ""
	c.realm_index = gs.data.realm_index_of("core_formation")
	c.age_days = 120 * Calendar.DAYS_PER_YEAR
	c.add_item("spirit_stone", 50000)
	for item_id: String in gs.data.items:
		c.add_item(item_id, 3)
	for tech_id: String in gs.data.techniques:
		Techniques.learn(c, gs.data, tech_id)
	for prof_id: String in gs.data.professions:
		Professions.add_xp(c, gs.data, prof_id, 300.0)
	for recipe_id: String in gs.data.recipes:
		if not c.known_recipes.has(recipe_id):
			c.known_recipes.append(recipe_id)
	for injury_id: String in gs.data.injuries:
		Injuries.inflict(c, gs.data, injury_id)
	for insight_id: String in gs.data.dao_insights:
		Dao.gain_levels(c, gs.data, insight_id, 1)
	c.alignment = 200
	gs.join_sect("azure_cloud_sect")
	for i in 4:
		var wife := Npcs.spawn(gs.npcs, gs.data, seeded_rng(40 + i), {"gender": "female", "region": gs.current_region})
		wife.age_days = 30 * Calendar.DAYS_PER_YEAR
		Family.marry(c, wife, "wife" if i == 0 else "concubine")
		for k in 3:
			var kid := Npcs.spawn(gs.npcs, gs.data, seeded_rng(100 + i * 10 + k), {"age_years": 6 + k, "region": gs.current_region})
			kid.parents = [c.id, wife.id] as Array[String]
			c.children.append(kid.id)
	c.abode = "waterfall_cave"
	gs.found_clan()
	for i in 60:
		EventBus.post("Message %d: a long line of news that wraps across the log so it takes room on the screen." % i)
	return c


func _assert_fits(screen: Control, label: String) -> void:
	await _frames()
	assert_true(screen.is_visible_in_tree(), "%s opens" % label)
	var rect := screen.get_global_rect()
	var view := Rect2(Vector2.ZERO, DECK / _scale)
	assert_true(view.encloses(rect), "%s does not fit on a Steam Deck: %s" % [label, rect])


func test_every_screen_fits_1280x800() -> void:
	await _check_all_screens(1.0)


func test_every_screen_fits_at_115_percent() -> void:
	await _check_all_screens(1.15)


func _check_all_screens(scale: float) -> void:
	_scale = scale
	var root := _tree().root
	var old_size := root.size
	root.size = Vector2i(DECK)
	Settings.set_value("ui_scale", scale)
	var gs: Node = root.get_node("GameState")
	_rich_character(gs)
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames()
	var screens: Dictionary = hud.get("_screens")
	for action: String in screens:
		var screen: Control = screens[action]
		screen.open()
		await _assert_fits(screen, action)
		screen.close()
	var crafting: Control = hud.get("_crafting")
	for prof_id: String in gs.data.professions:
		crafting.open(prof_id)
		await _assert_fits(crafting, "crafting (%s)" % prof_id)
		crafting.close()
	var shop: Control = hud.get("_shop")
	shop.open("Everything Stall", 0, ["herb", "ore", "equipment", "talisman", "inscription", "smithing", "scripture"])
	await _assert_fits(shop, "shop")
	shop._set_tab(true)
	await _assert_fits(shop, "shop (sell)")
	shop.close()
	var settings: SettingsScreen = hud.get("_settings")
	settings.open()
	settings._show_controls(true)
	await _assert_fits(settings, "settings (controls)")
	settings.close()
	var board: MissionBoard = hud.get("_mission_board")
	board.open()
	board._set_tab("rank")
	await _assert_fits(board, "mission board (rank)")
	board.close()
	for name: String in ["_mission_board", "_child_training", "_family", "_pause_menu", "_settings", "_help", "_load_screen"]:
		var screen: Control = hud.get(name)
		screen.open()
		await _assert_fits(screen, name)
		screen.close()
	var credits := CreditsScreen.new()
	hud.add_child(credits)
	credits.open()
	await _assert_fits(credits, "credits")
	credits.close()
	credits.queue_free()
	var auction: Control = hud.get("_auction")
	var clock: Node = root.get_node("GameClock")
	var day: int = clock.total_days
	clock.total_days = int(Auctions.house(gs.data, "fallen_star_auction")["offset_days"])
	auction.open("fallen_star_auction")
	await _assert_fits(auction, "auction")
	auction.close()
	clock.total_days = day
	var report: Control = hud.get("_combat_report")
	var lines := PackedStringArray()
	for i in 80:
		lines.append("Round %d: you strike the Stone Ape for 123. (Stone Ape: 4567 hp)" % i)
	report.show_fight("Stone Ape", true, lines)
	await _assert_fits(report, "combat report")
	report.close()
	hud.queue_free()
	await _frames(1)
	gs.end_session()
	Settings.set_value("ui_scale", 1.0)
	_scale = 1.0
	root.size = old_size
