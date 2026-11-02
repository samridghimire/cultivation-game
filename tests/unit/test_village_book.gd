extends TestCase
## WU-414: the village book lists every fish, caught ones in colour, missing ones as silhouettes with hints.


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int = 2) -> void:
	for i in n:
		await _tree().process_frame


func test_order_matches_catchable() -> void:
	var order := VillageBook.fish_order(data())
	var all := Fishing.catchable(data())
	assert_eq(order.size(), all.size(), "one entry per catchable fish")
	for id in all:
		assert_true(order.has(id), "%s listed" % id)
	assert_eq(order[0], "silver_carp" if data().items["silver_carp"]["price"] <= data().items["marsh_eel"]["price"] else "marsh_eel", "start region first, cheapest first")


func test_hint_for_caught_uncaught_and_unvisited() -> void:
	var c := new_character()
	Fishing.record_catch(c, "silver_carp", 1)
	assert_true(VillageBook.hint_for("silver_carp", data(), c).contains("Bites at"), "caught shows where")
	assert_true(VillageBook.hint_for("marsh_eel", data(), c).begins_with("Try "), "start region fish gets a place")
	assert_eq(VillageBook.hint_for("mist_koi", data(), c), "Somewhere you have not been.")
	c.visited_regions.append("misty_forest")
	assert_true(VillageBook.hint_for("mist_koi", data(), c).contains("Misty Pond Jetty"), "visited region names the jetty")


func test_book_opens_focused_and_closes() -> void:
	var root := _tree().root
	var gs: Node = root.get_node("GameState")
	var c := new_character()
	Fishing.record_catch(c, "silver_carp", 2)
	gs.start_session(c)
	gs.pending_event = ""
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames()
	var journal: Control = hud.get("_screens")["toggle_journal"]
	journal.open()
	await _frames()
	var button := journal.find_child("VillageBookButton", true, false) as Button
	assert_true(button != null, "journal has the Village book button")
	if button != null:
		button.pressed.emit()
	await _frames()
	var book: VillageBook = hud.get("_village_book")
	assert_true(book.visible, "book opens")
	assert_false(journal.visible, "journal closes")
	var grid := book.get("_grid") as GridContainer
	assert_eq(grid.get_child_count(), Fishing.catchable(data()).size(), "one slot per fish")
	var carp := grid.get_node("silver_carp") as Button
	var eel := grid.get_node("marsh_eel") as Button
	assert_true(carp.get_meta("found"), "carp found")
	assert_false(eel.get_meta("found"), "eel missing")
	assert_eq(eel.text, "???")
	assert_true(carp.text.contains("caught 2"))
	assert_true(grid.get_child(0).has_focus(), "first slot focused")
	var closed := [false]
	book.closed.connect(func() -> void: closed[0] = true)
	book.close()
	assert_true(closed[0], "closed emitted")
	hud.queue_free()
	await _frames()


func test_herbs_page_lists_every_findable_herb() -> void:
	var root := _tree().root
	var gs: Node = root.get_node("GameState")
	var c := new_character()
	var herbs := HerbLore.findable(data())
	HerbLore.record_find(c, herbs[0], 3)
	gs.start_session(c)
	gs.pending_event = ""
	var book := VillageBook.new()
	root.add_child(book)
	book.open()
	book.set_page("herbs")
	await _frames()
	var grid := book.get("_grid") as GridContainer
	assert_eq(grid.get_child_count(), herbs.size(), "one slot per findable herb")
	var first := grid.get_node(herbs[0]) as Button
	var second := grid.get_node(herbs[1]) as Button
	assert_true(first.text.contains("found 3"), "found herb shows its count")
	assert_eq(second.text, "???", "unfound herb is ???")
	assert_true(VillageBook.herb_order(data()).size() == herbs.size())
	assert_true(grid.get_child(0).has_focus(), "a slot is focused after switching pages")
	book.set_page("fish")
	await _frames()
	assert_eq(grid.get_child_count(), Fishing.catchable(data()).size(), "fish page again")
	assert_true(grid.get_child(0).has_focus(), "focus kept after switching back")
	book.queue_free()
	await _frames()


func test_item_icon_fish_tints_are_stable_and_distinct() -> void:
	var a := ItemIcon.tint_for("silver_carp", data().items["silver_carp"])
	var b := ItemIcon.tint_for("marsh_eel", data().items["marsh_eel"])
	assert_true(a != b, "different fish, different tints")
	assert_eq(a, ItemIcon.tint_for("silver_carp", data().items["silver_carp"]), "same id, same tint")
	assert_eq(ItemIcon.kind_of(data().items["silver_carp"]), "fish")


func test_sheet_button_opens_book() -> void:
	var root := _tree().root
	var gs: Node = root.get_node("GameState")
	var c := new_character()
	c.fishing_xp = 5
	gs.start_session(c)
	gs.pending_event = ""
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames()
	var sheet: Control = hud.get("_screens")["toggle_character_sheet"]
	sheet.open()
	await _frames(3)
	var button := sheet.find_child("VillageBookButton", true, false) as Button
	assert_true(button != null, "sheet has the Open village book button")
	if button != null:
		button.pressed.emit()
	await _frames()
	var book: VillageBook = hud.get("_village_book")
	assert_true(book.visible, "book opens")
	assert_false(sheet.visible, "sheet hides")
	book.close()
	await _frames()
	assert_true(sheet.visible, "closing returns to the sheet")
	hud.queue_free()
	await _frames()


func test_people_page_cards_and_unknown_tastes() -> void:
	var root := _tree().root
	var gs: Node = root.get_node("GameState")
	gs.start_session(new_character())
	gs.pending_event = ""
	var book := VillageBook.new()
	root.add_child(book)
	book.open()
	book.set_page("people")
	await _frames()
	assert_eq(VillageBook.PAGES.size(), 4, "four pages")
	var grid := book.get("_grid") as GridContainer
	assert_eq(grid.get_child_count(), 0, "nobody known yet")
	assert_eq(book.get("_detail").text, "You have not got to know anyone here yet.")
	var people := Npcs.in_region(gs.npcs, gs.data, gs.current_region)
	assert_true(people.size() >= 2, "region has villagers")
	gs.npc_favor[people[0].id] = 40
	gs.npc_favor[people[1].id] = 20
	book.set_page("people")
	await _frames()
	assert_eq(grid.get_child_count(), 2, "cards for two known villagers")
	assert_true(grid.get_child(0).has_focus(), "first card focused")
	var entry: Dictionary = gs.people_entries()[0]
	var row := VillageBook.taste_row(gs.data, [], 2)
	assert_eq(row.get_child_count(), 2, "unknown tastes are two ?")
	assert_eq((row.get_child(0) as Label).text, "?")
	assert_true(VillageBook.people_detail(entry, gs.data).contains("not yet learned"), "unknown likes worded")
	book.queue_free()
	await _frames()


func test_hunts_page_shows_hunted_and_hides_unhunted() -> void:
	var c := new_character()
	var all := Wildlife.huntable(data())
	assert_true(all.size() >= 2)
	Wildlife.record_hunt(c, all[0])
	Wildlife.record_hunt(c, all[0])
	var name0 := String(data().enemies[all[0]]["name"])
	assert_true(VillageBook.hunt_text(data(), c, all[0]).contains(name0))
	assert_true(VillageBook.hunt_text(data(), c, all[0]).contains("hunted 2"))
	var hidden := VillageBook.hunt_text(data(), c, all[1])
	assert_true(hidden.begins_with("???"), hidden)
	assert_false(hidden.contains(String(data().enemies[all[1]]["name"])))
	assert_true(hidden.contains("roams"))
	assert_true(VillageBook.hunt_detail(data(), c, all[0]).contains("spoils unknown"), "old save: no spoils recorded")
	Wildlife.record_spoils(c, all[0], {"spirit_herb": 2})
	assert_true(VillageBook.hunt_detail(data(), c, all[0]).contains("Spoils:"))


func test_trophy_rows_list_great_beasts_in_region_order() -> void:
	var c := CharacterFactory.create("T", data(), seeded_rng(), "male")
	var rows := VillageBook.trophy_rows(c, data())
	assert_eq(rows.size(), 4, "four great beasts")
	assert_eq(String(rows[0]["enemy"]), "old_tusker_boar", "regions.json order")
	assert_false(bool(rows[0]["won"]))
	assert_true(String(rows[0]["text"]).begins_with("???"), "unwon is a mystery")
	assert_true(String(rows[0]["text"]).contains("Misty Forest"), "says where")
	Wildlife.record_great(c, data(), "old_tusker_boar", "misty_forest", 9)
	rows = VillageBook.trophy_rows(c, data())
	assert_true(bool(rows[0]["won"]))
	assert_true(String(rows[0]["text"]).contains("Great Old Tusker"))
	assert_true(String(rows[0]["detail"]).contains("slain day 10"))
	assert_true(String(rows[0]["detail"]).contains("tusk"), "the trophy's description")
	assert_false(bool(rows[1]["won"]), "others stay unwon")
