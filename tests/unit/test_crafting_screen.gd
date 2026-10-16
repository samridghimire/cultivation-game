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
		if option["label"].begins_with("Deliver "):
			entry = option
	assert_true(entry["disabled"], "no items yet")
	assert_true(String(entry["reason"]).begins_with("You need"))
	gs.player.add_item(order["item"], int(order["count"]))
	var stones: int = gs.player.item_count("spirit_stone")
	for option: Dictionary in shop.get_options():
		if option["label"].begins_with("Deliver "):
			assert_false(option["disabled"])
			option["action"].call()
	shop.free()
	assert_eq(gs.player.item_count("spirit_stone"), stones + int(order["reward"]))
	assert_eq(gs.player.commissions.size(), 0)


## WU-083: recipes you can make come first, in a stable order.
func test_order_recipes_puts_ready_first() -> void:
	var c := new_character()
	c.inventory = {}
	var ids := PackedStringArray(["qi_gathering_pill", "bone_setting_salve"])
	assert_eq(CraftingScreen.order_recipes(c, data(), ids), ids, "none ready keeps the order")
	for item_id in data().recipes["bone_setting_salve"]["ingredients"]:
		c.add_item(item_id, 2)
	assert_eq(CraftingScreen.order_recipes(c, data(), ids), PackedStringArray(["bone_setting_salve", "qi_gathering_pill"]))
	for item_id in data().recipes["qi_gathering_pill"]["ingredients"]:
		c.add_item(item_id, 2)
	assert_eq(CraftingScreen.order_recipes(c, data(), ids), ids, "both ready keeps the order")


func test_screen_labels_ready_recipes_and_selects_first() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var c := new_character()
	c.inventory = {}
	for item_id in data().recipes["bone_setting_salve"]["ingredients"]:
		c.add_item(item_id, 2)
	gs.start_session(c)
	var screen := CraftingScreen.new()
	root.add_child(screen)
	screen.open("alchemist")
	var salve := screen.find_child("bone_setting_salve", true, false) as Button
	var pill := screen.find_child("qi_gathering_pill", true, false) as Button
	assert_true(salve.text.ends_with("(ready)"), salve.text)
	assert_false(pill.text.contains("(ready)"))
	assert_true(salve.button_pressed, "the first ready recipe is selected")
	assert_eq(salve.get_index(), 0)
	screen.free()


func test_missing_ingredient_line_names_where_it_grows() -> void:
	var c := new_character()
	c.inventory = {}
	var ingredients: Dictionary = data().recipes["qi_gathering_pill"]["ingredients"]
	var found := false
	for item_id: String in ingredients:
		var place := Guidance.herb_place(c, data(), item_id, "qingshi_village")
		if place == "":
			continue
		found = true
		var lines := CraftingScreen.ingredient_lines(c, data(), "qi_gathering_pill", "qingshi_village")
		var any := false
		for line in lines:
			if line.ends_with(" - grows at " + place):
				any = true
		assert_true(any, "missing %s names %s" % [item_id, place])
		c.add_item(item_id, int(ingredients[item_id]))
		for line in CraftingScreen.ingredient_lines(c, data(), "qi_gathering_pill", "qingshi_village"):
			assert_false(line.contains(place) and line.contains(data().items[item_id]["name"]), "held ingredient has no place")
	assert_true(found, "some ingredient of the starter pill grows somewhere")


func test_herb_place_prefers_current_region_and_is_empty_for_unknown() -> void:
	var c := new_character()
	assert_eq(Guidance.herb_place(c, data(), "no_such_item", "qingshi_village"), "")


func test_margin_text_reads_recipe_margin() -> void:
	var margin := Alchemy.recipe_margin(data(), "qi_gathering_pill")
	var text := CraftingScreen.margin_text(data(), "qi_gathering_pill")
	assert_true(text.contains("cost about %d " % margin["cost"]))
	assert_true(text.contains("sells for about %d." % margin["value"]))
	assert_eq(text.ends_with("Gathered herbs make it pay."), margin["value"] < margin["cost"])


func test_workshop_work_option_describes_pay() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var c := new_character()
	gs.start_session(c)
	var shop: Node = load("res://src/world/interactables/workshop.gd").new()
	var found := false
	for option: Dictionary in shop.get_options():
		if option["label"].begins_with("Work as Doctor"):
			found = true
			var pay := Professions.work_preview(c, data(), "doctor", Calendar.DAYS_PER_MONTH)
			assert_true(option["description"].contains("About %d spirit stones" % pay["income"]))
			assert_true(option["description"].contains("%d xp" % roundi(pay["xp"])))
	shop.free()
	assert_true(found)


func test_workshop_odd_jobs_only_for_practised_crafts() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var c := new_character()
	c.professions = {"alchemist": {"rank": 0, "xp": 0.0}}
	gs.start_session(c)
	var shop: Node = load("res://src/world/interactables/workshop.gd").new()
	var labels: Array = []
	for option: Dictionary in shop.get_options():
		labels.append(option["label"])
	shop.free()
	var has := func(prefix: String) -> bool:
		return labels.any(func(l: String) -> bool: return l.begins_with(prefix))
	assert_true(has.call("Odd jobs as Alchemist"))
	assert_false(has.call("Odd jobs as Blacksmith"))
	assert_true(has.call("Work as Doctor"))


func test_work_profession_pays_the_preview_for_a_craft() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var c := new_character()
	c.professions = {"alchemist": {"rank": 0, "xp": 0.0}}
	gs.start_session(c)
	var p: CharacterData = gs.player
	var pay := Professions.work_preview(p, data(), "alchemist", 30)
	var stones := p.item_count("spirit_stone")
	var xp := Professions.xp_of(p, "alchemist")
	gs.work_profession("alchemist", 30)
	assert_eq(p.item_count("spirit_stone") - stones, int(pay["income"]))
	assert_true(absf(Professions.xp_of(p, "alchemist") - xp - float(pay["xp"])) < 0.01)
func test_ingredient_lines_respect_the_season() -> void:
	var c := new_character()
	c.inventory = {}
	var winter := CraftingScreen.ingredient_lines(c, data(), "bog_lily_qi_pill", "qingshi_village", 280)
	assert_true(winter[0].ends_with("(in Autumn)"), winter[0])
	var autumn := CraftingScreen.ingredient_lines(c, data(), "bog_lily_qi_pill", "qingshi_village", 200)
	assert_false(autumn[0].contains("(in Autumn)"), autumn[0])


## WU-201: the where block drops a gather place the ingredient line already names.
func test_where_block_does_not_repeat_the_gather_place() -> void:
	var c := new_character()
	c.inventory = {}
	var ingredients: Dictionary = data().recipes["qi_gathering_pill"]["ingredients"]
	var checked := false
	for item_id: String in ingredients:
		var place := Guidance.herb_place(c, data(), item_id, "qingshi_village")
		if place == "":
			continue
		checked = true
		var where := CraftingScreen.missing_sources_text(c, data(), "qi_gathering_pill", "qingshi_village")
		assert_false(where.contains("Gathered at " + place.split(" in ")[0].split(" (")[0] + " ("), where)
	assert_true(checked)


## WU-201: ores are "found at", herbs "grow at".
func test_non_herb_ingredient_says_found_at() -> void:
	var c := new_character()
	c.inventory = {}
	var checked := false
	for recipe_id: String in data().recipes:
		for item_id: String in data().recipes[recipe_id]["ingredients"]:
			var tags: Array = data().items[item_id].get("tags", [])
			var place := Guidance.herb_place(c, data(), item_id, "")
			if place == "" or tags.has("herb"):
				continue
			checked = true
			var lines := CraftingScreen.ingredient_lines(c, data(), recipe_id)
			assert_true(Array(lines).any(func(l: String) -> bool: return l.ends_with(" - found at " + place)), str(lines))
	if not checked:
		print("  (no non-herb ingredient has a gather place; verb branch untested)")
