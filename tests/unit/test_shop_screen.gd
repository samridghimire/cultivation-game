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
	var cb := func(n: String, max_price: int, tags: Array): seen.append([n, max_price, tags])
	bus.shop_requested.connect(cb)
	var options: Array[Dictionary] = merchant.get_options()
	assert_eq(options.size(), 1)
	options[0]["action"].call()
	bus.shop_requested.disconnect(cb)
	merchant.free()
	assert_eq(seen, [["Herb Stall", 0, ["herb"]]])

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
