extends TestCase
## Merchant stock rules (Items.shop_stock / buyback_ids) and the ShopScreen helpers.


func test_general_store_stocks_only_untagged_goods_cheapest_first() -> void:
	var ids := Items.shop_stock(data(), 0, [])
	assert_true(ids.has("qi_gathering_pill"))
	assert_false(ids.has("spirit_herb"))
	assert_false(ids.has("spirit_stone"))
	for i in range(1, ids.size()):
		assert_true(int(data().items[ids[i - 1]]["price"]) <= int(data().items[ids[i]]["price"]))


func test_stock_respects_tags_and_max_price() -> void:
	var ids := Items.shop_stock(data(), 50, ["herb"])
	assert_true(ids.has("spirit_herb"))
	assert_false(ids.has("flame_lotus"))  # price 60
	assert_false(ids.has("iron_essence"))


func test_only_tagged_merchants_buy_matching_goods() -> void:
	var c := new_character()
	c.inventory = {"spirit_herb": 3, "iron_essence": 2, "qi_gathering_pill": 1}
	assert_eq(Items.buyback_ids(c, data(), []), [])
	assert_eq(Items.buyback_ids(c, data(), ["herb"]), ["spirit_herb"])


func test_wandering_merchant_buys_common_loot_without_selling_it() -> void:
	var c := new_character()
	c.inventory = {"spirit_herb": 2, "iron_essence": 1, "qi_gathering_pill": 1}
	var place := {}
	for p: Dictionary in data().regions["qingshi_village"]["places"]:
		if p.get("display_name", "") == "Wandering Merchant":
			place = p
	var buy_tags: Array = place.get("buy_tags", [])
	assert_false(buy_tags.is_empty())
	assert_eq(Items.buyback_ids(c, data(), place.get("stock_tags", []), buy_tags), ["spirit_herb", "iron_essence"])
	assert_false(Items.shop_stock(data(), 0, place.get("stock_tags", [])).has("spirit_herb"))


func test_max_quantity_limited_by_stones_or_pouch() -> void:
	var c := new_character()
	c.inventory = {"spirit_stone": 50, "spirit_herb": 3}
	assert_eq(ShopScreen.max_quantity(c, data(), "qi_gathering_pill", false), 3)  # 15 each
	assert_eq(ShopScreen.max_quantity(c, data(), "spirit_herb", true), 3)
	c.inventory["spirit_stone"] = 0
	assert_eq(ShopScreen.max_quantity(c, data(), "qi_gathering_pill", false), 0)


func test_compare_text_names_equipped_item() -> void:
	var c := new_character()
	c.equipment = {}
	assert_eq(ShopScreen.compare_text(c, data(), "qi_gathering_pill"), "")
	assert_eq(ShopScreen.compare_text(c, data(), "iron_sword"), "Your weapon slot is empty.")
	c.equipment["weapon"] = "iron_sword"
	assert_true(ShopScreen.compare_text(c, data(), "iron_sword").begins_with("Equipped: %s (" % data().items["iron_sword"]["name"]))


func test_merchant_browse_opens_shop_and_screen_trades() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var c := new_character()
	c.inventory = {"spirit_stone": 100, "spirit_herb": 2}
	gs.start_session(c)
	var merchant: Node = load("res://src/world/interactables/merchant.gd").new()
	merchant.display_name = "Herb Stall"
	merchant.stock_tags = ["herb"]
	var seen: Array = []
	var bus := root.get_node("EventBus")
	var cb := func(n: String, max_price: int, tags: Array, faction: String, buy_tags: Array): seen.append([n, max_price, tags, faction, buy_tags])
	bus.shop_requested.connect(cb)
	var options: Array[Dictionary] = merchant.get_options()
	assert_eq(options.size(), 2, "Browse wares and Ask about rumors")
	options[0]["action"].call()
	bus.shop_requested.disconnect(cb)
	merchant.free()
	assert_eq(seen, [["Herb Stall", 0, ["herb"], "", []]])

	var screen := ShopScreen.new()
	root.add_child(screen)
	screen.open("Herb Stall", 0, ["herb"])
	assert_true(screen.item_ids().has("spirit_herb"))
	screen._select("spirit_herb")
	screen._step(2)
	assert_eq(screen._quantity, 3)
	screen._trade()
	assert_eq(gs.player.item_count("spirit_herb"), 5)
	screen._set_tab(true)
	assert_eq(screen.item_ids(), ["spirit_herb"])
	screen._step(10)  # clamps to the 5 held
	screen._trade()
	assert_eq(gs.player.item_count("spirit_herb"), 0)
	screen.close()
	screen.free()
	gs.end_session()


func test_restricted_goods_only_at_merchants_that_stock_them() -> void:
	var general := Items.shop_stock(data(), 0, ["equipment"])
	var black_market := Items.shop_stock(data(), 0, ["demonic"])
	for item_id in black_market:
		assert_false(general.has(item_id), "%s is restricted to its own merchants" % item_id)


func test_merchant_refuses_wrong_alignment_without_opening_the_shop() -> void:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var c := new_character()
	c.alignment = 500
	gs.start_session(c)
	var merchant: Node = load("res://src/world/interactables/merchant.gd").new()
	merchant.max_alignment = -200
	var options: Array[Dictionary] = merchant.get_options()
	assert_eq(options.size(), 1)
	assert_true(options[0]["disabled"], options[0]["label"])
	assert_true(String(options[0]["label"]).contains("righteous"), options[0]["label"])
	merchant.free()
	gs.end_session()


func test_quantity_max_and_ten_steps() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var c := new_character()
	c.inventory = {"spirit_stone": 100, "spirit_herb": 25}
	gs.start_session(c)
	var screen := ShopScreen.new()
	root.add_child(screen)
	screen.open("Herb Stall", 0, ["herb"])
	screen._set_tab(true)
	screen._select("spirit_herb")
	screen._step(ShopScreen.MAX_STEP)
	assert_eq(screen._quantity, 25, "Max on sell = held count")
	screen._step(-10)
	assert_eq(screen._quantity, 15)
	screen._step(-100)
	assert_eq(screen._quantity, 1, "clamps to 1")
	screen._step(10)
	assert_eq(screen._quantity, 11)
	screen._set_tab(false)
	screen._select("spirit_herb")
	screen._step(ShopScreen.MAX_STEP)
	assert_eq(screen._quantity, ShopScreen.max_quantity(gs.player, gs.data, "spirit_herb", false), "Max on buy is capped by stones")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_PAGEUP
	assert_true(screen._is_ten_step(key, false))
	for pair in [["toggle_techniques", false], ["toggle_artifact", true], ["ui_page_up", false], ["ui_page_down", true]]:
		var act := InputEventAction.new()
		act.action = pair[0]
		act.pressed = true
		assert_true(screen._is_ten_step(act, pair[1]), "%s steps by ten" % pair[0])
		assert_false(screen._is_ten_step(act, not pair[1]))
	screen.close()
	screen.free()
	gs.end_session()


func test_category_tabs_filter_and_reset() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var c := new_character()
	c.inventory = {"spirit_stone": 100, "spirit_herb": 2, "qi_gathering_pill": 1}
	gs.start_session(c)
	var screen := ShopScreen.new()
	root.add_child(screen)
	screen.open("General Store", 0, [], "", ["herb", "pill"])
	var cats := ShopScreen.categories_in(data(), screen.item_ids())
	assert_eq(cats[0], "All")
	assert_true(cats.has("Pills"))
	screen._set_category("Pills")
	assert_true(screen.visible_ids().size() > 0)
	for id in screen.visible_ids():
		assert_eq(Items.category(data().items[id]), "Pills")
	screen._set_tab(true)
	assert_eq(screen._category, "All", "switching Buy/Sell resets")
	screen._set_category("Herbs & Ores")
	assert_eq(screen.visible_ids(), ["spirit_herb"])
	screen._set_tab(false)
	assert_eq(screen._category, "All")
	screen.close()
	screen.free()
	gs.end_session()


func test_bulk_sell_skips_worn_manuals_and_breakthrough_pills() -> void:
	var c := new_character()
	c.inventory = {"spirit_herb": 3, "iron_sword": 1, "foundation_establishment_pill": 1, "iron_essence": 2}
	c.equipment = {"weapon": "iron_sword"}
	var tags := ["herb", "ore", "equipment", "pill"]
	var ids := Items.bulk_sell_ids(c, data(), tags)
	assert_false(ids.has("spirit_herb"), "feeds cultivation")
	assert_true(ids.has("iron_essence"))
	assert_false(ids.has("iron_sword"), "worn")
	assert_false(ids.has("foundation_establishment_pill"), "breakthrough pill")
	assert_eq(Items.bulk_sell_total(c, data(), ids), 2 * Items.sell_price(data(), "iron_essence"))


func test_sell_all_button_needs_two_presses() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var c := new_character()
	c.inventory = {"iron_essence": 4}
	gs.start_session(c)
	var screen := ShopScreen.new()
	root.add_child(screen)
	screen.open("Ore Stall", 0, ["ore"])
	assert_false(screen._sell_all_button.visible, "only on the Sell tab")
	screen._set_tab(true)
	assert_true(screen._sell_all_button.visible)
	var stones_before: int = gs.player.item_count("spirit_stone")
	screen._sell_all()
	assert_eq(gs.player.item_count("iron_essence"), 4, "first press only arms")
	assert_true(screen._sell_all_button.text.begins_with("Press again"))
	screen._sell_all()
	assert_eq(gs.player.item_count("iron_essence"), 0)
	assert_eq(gs.player.item_count("spirit_stone"), stones_before + 4 * Items.sell_price(gs.data, "iron_essence"))
	screen.close()
	screen.free()
	gs.end_session()


func test_sell_all_note_names_top_stacks() -> void:
	var c := new_character()
	c.inventory = {"spirit_herb": 1, "mist_wolf_pelt": 9, "iron_sword": 1, "iron_essence": 1, "spirit_stone": 5}
	var ids: Array = []
	for id: String in ["spirit_herb", "mist_wolf_pelt", "iron_sword", "iron_essence"]:
		if data().items.has(id):
			ids.append(id)
	assert_true(ids.size() >= 4, "test items exist")
	var text := ShopScreen.sell_all_summary(c, data(), ids)
	assert_true(text.begins_with("Sells: 9 %s" % Items.item_plural(data(), "mist_wolf_pelt", 9)), text)
	assert_true(text.ends_with("and 1 more kind"), text)
	assert_false(ShopScreen.sell_all_summary(c, data(), ids.slice(0, 2)).contains("more"))


func test_sell_all_note_names_kept_herbs() -> void:
	var c := new_character()
	c.inventory = {"spirit_herb": 3, "iron_essence": 2}
	var tags := ["herb", "ore"]
	var text := ShopScreen.kept_text(c, data(), tags)
	assert_true(text.begins_with("Kept: 3 "), text)
	assert_true(text.contains("feed your cultivation"), text)
	assert_false(text.contains("Iron"), text)
	c.inventory = {"iron_essence": 2}
	assert_eq(ShopScreen.kept_text(c, data(), tags), "")


func test_shop_hint_follows_rebinds() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs: Node = root.get_node("GameState")
	var ic: Node = root.get_node("InputConfig")
	var old_path: String = ic.path
	ic.path = "user://test_controls.cfg"
	ic.reset_controls()
	gs.start_session(CharacterFactory.create("Trader", gs.data, seeded_rng()))
	var screen := ShopScreen.new()
	root.add_child(screen)
	screen.open("Shop")
	ic.rebind_joy("toggle_techniques", JOY_BUTTON_X)
	assert_true(screen._hint_label.text.contains("X/"), "live rebind: " + screen._hint_label.text)
	ic.rebind_joy("toggle_techniques", JOY_BUTTON_Y)
	screen.open("Shop")
	assert_true(screen._hint_label.text.contains("Y/"), "reopen: " + screen._hint_label.text)
	ic.reset_controls()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ic.path))
	ic.path = old_path
	ic.load_controls()
	ic.apply()
	screen.queue_free()
	gs.end_session()


func test_manual_note_and_compare_text() -> void:
	var c := new_character()
	var d := data()
	assert_eq(ShopScreen.manual_note(c, d, "manual_iron_fist"), " (fighting style)")
	assert_eq(ShopScreen.manual_note(c, d, "qi_gathering_pill"), "")
	assert_true(ShopScreen.is_first_combat_manual(c, d, "manual_iron_fist"))
	assert_eq(ShopScreen.compare_text(c, d, "manual_iron_fist"), "Teaches Iron Fist, a fighting style you do not know yet.")
	c.techniques["iron_fist"] = {"level": 1, "xp": 0.0}
	assert_eq(ShopScreen.manual_note(c, d, "manual_iron_fist"), " (known)")
	assert_false(ShopScreen.is_first_combat_manual(c, d, "manual_iron_fist"))
	assert_eq(ShopScreen.compare_text(c, d, "manual_iron_fist"), "Teaches Iron Fist. You already know it.")


func test_manual_row_shows_full_name_and_price() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var c := new_character()
	c.inventory = {"spirit_stone": 100}
	gs.start_session(c)
	var screen := ShopScreen.new()
	root.add_child(screen)
	screen.open("Wandering Merchant", 0, ["herb", "ore", "beast_material"])
	var b: Button = screen._list.get_node_or_null("manual_iron_fist")
	if b != null:
		var price := ShopScreen.unit_price(gs.player, data(), "manual_iron_fist", false, "", gs.buy_multiplier())
		assert_true(b.text.begins_with("Manual: Iron Fist  %d" % price), b.text)
		assert_true(ShopScreen.row_fits(b.text), b.text)
	assert_false(ShopScreen.row_fits("Manual: " + "Very ".repeat(30) + "Long Name  300 (fighting style)"))
	screen.close()
	screen.free()
	gs.end_session()


func test_upgrade_tag_marks_better_affordable_armor() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var c := new_character()
	c.inventory = {"spirit_stone": 500}
	gs.start_session(c)
	var d := data()
	c = gs.player
	c.equipment = {"armor": "boar_hide_jerkin"}
	assert_eq(ShopScreen.upgrade_tag(c, d, "wolfhide_brigandine"), "upgrade")
	assert_eq(ShopScreen.upgrade_tag(c, d, "boar_hide_jerkin"), "")  # equal, not better
	c.equipment = {"armor": "wolfhide_brigandine"}
	assert_eq(ShopScreen.upgrade_tag(c, d, "boar_hide_jerkin"), "")  # worse
	c.equipment = {"armor": "boar_hide_jerkin"}
	c.inventory = {"spirit_stone": 5}
	assert_eq(ShopScreen.upgrade_tag(c, d, "wolfhide_brigandine"), "")  # unaffordable
	c.inventory = {"spirit_stone": 140}
	c.reputation["azure_cloud_sect"] = 700  # Revered: 170 * 0.8 = 136
	assert_eq(ShopScreen.upgrade_tag(c, d, "wolfhide_brigandine"), "", "140 < 170 at full price")
	assert_eq(ShopScreen.upgrade_tag(c, d, "wolfhide_brigandine", "azure_cloud_sect"), "upgrade", "the shop's faction discount counts")


func test_upgrade_tag_weighs_every_stat() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var c := new_character()
	c.inventory = {"spirit_stone": 500}
	gs.start_session(c)
	var d := data()
	c = gs.player
	c.equipment = {"armor": "boar_hide_jerkin"}
	assert_eq(ShopScreen.upgrade_tag(c, d, "iron_scale_armor"), "upgrade", "equal defense, more max_hp")
	c.equipment = {"armor": "wolf_pelt_cloak"}
	assert_eq(ShopScreen.upgrade_tag(c, d, "stone_ape_bracers"), "", "more defense but less speed")
	assert_eq(ShopScreen.upgrade_tag(c, d, "boar_hide_jerkin"), "", "more max_hp but less speed")
	c.equipment = {}
	assert_eq(ShopScreen.upgrade_tag(c, d, "stone_ape_bracers"), "upgrade", "nothing worn")


func test_upgrade_tag_marks_body_manual_at_foundation() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var c := new_character()
	gs.start_session(c)
	var d := data()
	c = gs.player
	assert_eq(ShopScreen.upgrade_tag(c, d, "manual_stone_skin"), "")  # Mortal
	c.realm_index = d.realm_index_of("foundation_establishment")
	assert_eq(ShopScreen.upgrade_tag(c, d, "manual_stone_skin"), "defence")
	c.techniques["stone_skin"] = {"level": 1, "xp": 0.0}
	assert_eq(ShopScreen.upgrade_tag(c, d, "manual_stone_skin"), "")


func test_upgrade_tag_row_fits_for_longest_armor() -> void:
	var d := data()
	for id: String in d.items:
		if Equipment.is_equipment(d, id) and Equipment.slot_of(d, id) == "armor":
			var label := "%s  %d" % [d.items[id]["name"], int(d.items[id]["price"])]
			if ShopScreen.row_fits(label):
				assert_true(ShopScreen.row_fits(label + ShopScreen.tag_note("upgrade")), id)


func test_tag_note_names_defence_and_upgrade() -> void:
	assert_eq(ShopScreen.tag_note("upgrade"), " (upgrade)")
	assert_true(ShopScreen.tag_note("defence") != "")
	assert_true(ShopScreen.tag_note("defence").contains("(defence)"))
	assert_eq(ShopScreen.tag_note(""), "")


func test_stone_skin_row_says_defence_only_for_foundation() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var c := new_character()
	c.inventory = {"spirit_stone": 500}
	gs.start_session(c)
	var d := data()
	for foundation: bool in [true, false]:
		gs.player.realm_index = d.realm_index_of("foundation_establishment") if foundation else 0
		var screen := ShopScreen.new()
		root.add_child(screen)
		screen.open("Wandering Merchant", 0, ["herb", "ore", "beast_material"])
		var b: Button = screen._list.get_node_or_null("manual_stone_skin")
		if b != null:
			assert_eq(b.text.contains("(defence)"), foundation, b.text)
		screen.close()
		screen.free()
	gs.end_session()


func test_buy_tab_says_where_gear_is_when_region_sells_none() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(new_character())
	var screen := ShopScreen.new()
	root.add_child(screen)
	gs.current_region = "qingshi_village"
	screen.open("Herb Stall", 0, ["herb"])
	var note: Label = screen._gear_note
	assert_true(note.visible)
	assert_true(note.text.contains("Heavenforge Smithy"), note.text)
	assert_eq(note.focus_mode, Control.FOCUS_NONE)
	screen._set_tab(true)
	assert_false(screen._gear_note.visible)
	gs.current_region = "fallen_star_market"
	screen.open("Heavenforge Smithy", 0, ["equipment", "ore", "smithing"])
	assert_false(screen._gear_note.visible)
	screen.close()
	screen.free()
	gs.end_session()


func test_sell_wanted_line_names_the_sect_mission() -> void:
	var c := new_character()
	assert_eq(ShopScreen.sell_wanted_line(c, data(), "spirit_herb", true), "", "rogues are not asked")
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0}
	c.inventory = {"spirit_herb": 3}
	assert_true(ShopScreen.sell_wanted_line(c, data(), "spirit_herb", true).begins_with("Wanted by the sect: "))
	assert_eq(ShopScreen.sell_wanted_line(c, data(), "spirit_herb", false), "", "not shown when buying")
