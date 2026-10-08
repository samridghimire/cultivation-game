extends TestCase


func test_ingredient_lines_show_have_over_need() -> void:
	var c := new_character()
	c.inventory = {}
	var recipe: Dictionary = data().recipes["qi_gathering_pill"]
	var item_id: String = recipe["ingredients"].keys()[0]
	c.add_item(item_id, 1)
	var lines := CraftingScreen.ingredient_lines(c, data(), "qi_gathering_pill")
	assert_eq(lines.size(), recipe["ingredients"].size())
	assert_true(lines[0].begins_with("1 / %d " % int(recipe["ingredients"][item_id])))


func test_output_text_uses_item_name() -> void:
	var out: Dictionary = data().recipes["qi_gathering_pill"]["output"]
	var text := CraftingScreen.output_text(data(), out)
	assert_true(text.contains(data().items[out["item"]]["name"]))


func test_workshop_offers_crafting_screens() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(new_character())
	var shop: Node = load("res://src/world/interactables/workshop.gd").new()
	var seen: Array = []
	var bus := root.get_node("EventBus")
	var cb := func(prof_id: String): seen.append(prof_id)
	bus.crafting_requested.connect(cb)
	for option: Dictionary in shop.get_options():
		if option["label"].begins_with("Alchemy"):
			option["action"].call()
	bus.crafting_requested.disconnect(cb)
	shop.free()
	assert_eq(seen, ["alchemist"])


func test_refine_batch_crafts_until_ingredients_run_out() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var c := new_character()
	c.inventory = {}
	var recipe: Dictionary = data().recipes["qi_gathering_pill"]
	for item_id in recipe["ingredients"]:
		c.add_item(item_id, int(recipe["ingredients"][item_id]) * 2)
	gs.start_session(c)
	var before: int = gs.player.age_days
	gs.refine_batch("qi_gathering_pill", 5)
	assert_eq(gs.player.age_days, before + 2 * int(recipe["days"]))
	for item_id in recipe["ingredients"]:
		assert_eq(gs.player.item_count(item_id), 0)


func test_missing_ingredients_list_sources() -> void:
	var c := new_character()
	c.inventory = {}
	var text := CraftingScreen.missing_sources_text(c, data(), "qi_gathering_pill")
	assert_true(text.contains("Sold at") or text.contains("Gathered at"), text)
	var recipe: Dictionary = data().recipes["qi_gathering_pill"]
	for item_id in recipe["ingredients"]:
		c.add_item(item_id, int(recipe["ingredients"][item_id]))
	assert_eq(CraftingScreen.missing_sources_text(c, data(), "qi_gathering_pill"), "")


func test_items_sources_names_places_and_regions() -> void:
	var lines := Items.sources(data(), "spirit_herb")
	assert_true(lines.any(func(l: String) -> bool: return l.begins_with("Gathered at Village Herb Slope (Qingshi Village)")), str(lines))
	assert_true(lines.any(func(l: String) -> bool: return l.begins_with("Sold at Village Herb Seller")), str(lines))
	assert_eq(Items.sources(data(), "no_such_item"), ["Found exploring"] as Array[String])


func test_workshop_deliver_commission_entries() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var c := new_character()
	c.professions["alchemist"] = {"rank": 0, "xp": 0.0}
	gs.start_session(c)
	var order := Commissions.roll(gs.player, data(), seeded_rng(7), 0)[0]
	var shop: Node = load("res://src/world/interactables/workshop.gd").new()
	var entry: Dictionary = {}
	for option: Dictionary in shop.get_options():
		if option["label"].begins_with("Deliver:"):
			entry = option
	assert_true(entry["disabled"], "no items yet")
	assert_true(entry["label"].contains("You need"))
	gs.player.add_item(order["item"], int(order["count"]))
	var stones: int = gs.player.item_count("spirit_stone")
	for option: Dictionary in shop.get_options():
		if option["label"].begins_with("Deliver:"):
			assert_false(option["disabled"])
			option["action"].call()
	shop.free()
	assert_eq(gs.player.item_count("spirit_stone"), stones + int(order["reward"]))
	assert_eq(gs.player.commissions.size(), 0)
