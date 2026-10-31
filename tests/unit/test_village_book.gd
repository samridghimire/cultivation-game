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
