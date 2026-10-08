extends TestCase
## Final-death epilogue (WU-004).


func test_epilogue_has_realm_and_fights_won() -> void:
	var c := new_character()
	LifeStats.add(c, "fights_won", 3)
	var text := "\n".join(LifeStats.epilogue(c, data()))
	assert_true(text.contains(Cultivation.realm_label(c, data())), text)
	assert_true(text.contains("Fights won: 3"), text)


func test_epilogue_rogue_mortal_has_no_clan_or_children() -> void:
	var c := new_character()
	var lines := LifeStats.epilogue(c, data())
	var text := "\n".join(lines)
	assert_true(lines[0].contains("fallen at age"), text)
	assert_true(text.contains("A rogue cultivator"), text)
	assert_false(text.contains("Clan:"), text)
	assert_false(text.contains("Children:"), text)
	assert_false(text.contains("%") or text.contains("<null>"), text)


func test_epilogue_sect_clan_children_and_stats() -> void:
	var c := new_character()
	c.sect = {"id": data().sects.keys()[0], "rank": 0}
	c.children.append("a")
	c.children.append("b")
	LifeStats.add(c, "fights_won", 3)
	var clan := ClanData.new()
	clan.name = "Zhao"
	clan.members["x"] = {}
	var text := "\n".join(LifeStats.epilogue(c, data(), clan))
	assert_true(text.contains("Sect: " + Sects.describe(c, data())), text)
	assert_true(text.contains("Clan: Zhao, 1 members"), text)
	assert_true(text.contains("Children: 2"), text)
	assert_true(text.contains("Fights won: 3"), text)
	assert_false(text.contains("%") or text.contains("<null>"), text)


func test_epilogue_caps_stat_lines() -> void:
	var c := new_character()
	for key in LifeStats.KEYS:
		LifeStats.add(c, key)
	assert_true(LifeStats.epilogue(c, data(), null, 3).size() <= 7)


func test_death_screen_shows_epilogue_and_focuses_menu_button() -> void:
	var root: Node = Engine.get_main_loop().root
	var gs: Node = root.get_node("GameState")
	var c := new_character()
	LifeStats.add(c, "fights_won")
	gs.start_session(c)
	gs.pending_event = ""
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await root.get_tree().process_frame
	hud.call("_on_player_died", "Slain by a boar.")
	var screen: Control = hud.get("_death_screen")
	var text := (screen.find_child("Epilogue", true, false) as Label).text
	assert_true(text.contains("Fights won"), text)
	assert_true(text.contains(Cultivation.realm_label(c, gs.data)), text)
	await root.get_tree().process_frame
	assert_true(screen.find_children("*", "Button", true, false)[0].has_focus())
	hud.queue_free()
