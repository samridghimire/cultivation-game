extends TestCase
## MARKET-002: places with open_days (Places), the Travelling Market Stall in Qingshi, its journal hint.

const DAY_10 := 9  # total_days is 0-based, Calendar.day_of(9) == 10


func _region() -> Dictionary:
	return _gd().regions["qingshi_village"]


func _gd() -> GameData:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState").data


func _stall() -> Dictionary:
	return ShopDiscounts.place_named(_gd(), "qingshi_village", "Travelling Market Stall")


func test_is_open_edges() -> void:
	var place := {"open_days": [10, 25]}
	assert_true(Places.is_open(place, DAY_10))
	assert_false(Places.is_open(place, DAY_10 + 1), "day 11")
	assert_false(Places.is_open(place, DAY_10 - 1), "day 9")
	assert_true(Places.is_open(place, 24), "day 25")
	assert_true(Places.is_open(place, 30 + DAY_10), "day 10 of the next month")
	assert_true(Places.is_open({}, 5), "no open_days = always")


func test_json_float_days_work() -> void:
	assert_true(Places.is_open({"open_days": [10.0, 25.0]}, DAY_10))
	assert_false(Places.is_open({"open_days": [10.0, 25.0]}, DAY_10 + 1))


func test_days_until_open_wraps_the_month() -> void:
	var place := {"open_days": [10, 25]}
	assert_eq(Places.days_until_open(place, DAY_10), 0)
	assert_eq(Places.days_until_open(place, DAY_10 + 1), 14)
	assert_eq(Places.days_until_open(place, 24 + 1), 14, "day 26 -> day 10 next month")


func test_stall_data_and_stock() -> void:
	var stall := _stall()
	assert_false(stall.is_empty(), "stall exists")
	assert_eq((stall["open_days"] as Array).map(func(d): return int(d)), [10, 25])
	var stock: Array = Items.shop_stock(_gd(), int(stall.get("max_price", 0)), stall["stock_tags"])
	assert_true(stock.has("purple_cloud_mushroom"))
	assert_true(stock.has("qi_condensing_grass"))
	assert_true(stock.has("sweet_rice_ball"))
	assert_false(stock.has("spirit_herb"), "only the listed goods")
	assert_false(stock.has("qi_gathering_pill"))


func test_stall_goods_are_not_sold_by_the_village_herb_seller() -> void:
	var seller := ShopDiscounts.place_named(_gd(), "qingshi_village", "Village Herb Seller")
	var stock: Array = Items.shop_stock(_gd(), int(seller["max_price"]), seller["stock_tags"])
	assert_false(stock.has("purple_cloud_mushroom"))
	assert_false(stock.has("qi_condensing_grass"))


func test_hint_line() -> void:
	var region := _region()
	assert_eq(Places.hint_line(region, DAY_10), "Market day today: Travelling Market Stall is open")
	assert_eq(Places.hint_line(region, DAY_10 - 3), "Market day in 3 days: Travelling Market Stall")
	assert_eq(Places.hint_line(region, DAY_10 - 1), "Market day in 1 day: Travelling Market Stall")
	assert_eq(Places.hint_line(region, DAY_10 + 1), "", "14 days away: no hint")
	assert_eq(Places.hint_line(region, DAY_10 - 6), "", "6 days away: no hint")


func test_journal_village_card_mentions_market_day() -> void:
	var data := _gd()
	var c := CharacterFactory.create("Market", data, seeded_rng(), "male")
	var lines := Guidance.village_lines(c, data, {}, {}, "qingshi_village", DAY_10 - 2)
	assert_true("Market day in 2 days: Travelling Market Stall" in lines)
	lines = Guidance.village_lines(c, data, {}, {}, "qingshi_village", DAY_10 + 1)
	for line in lines:
		assert_false(line.begins_with("Market day"), line)


func test_validation_rejects_bad_open_days() -> void:
	assert_eq(Places.validate([10, 25], "x").size(), 0)
	assert_true(Places.validate([], "x").size() > 0)
	assert_true(Places.validate([0], "x").size() > 0)
	assert_true(Places.validate([31], "x").size() > 0)
	assert_true(Places.validate(["a"], "x").size() > 0)
	assert_true(Places.validate(5, "x").size() > 0)


func test_closed_merchant_has_no_menu() -> void:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var clock: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameClock")
	var c := CharacterFactory.create("Market", gs.data, seeded_rng(), "male")
	gs.start_session(c)
	var stall: Interactable = load("res://src/world/interactables/merchant.gd").new()
	stall.open_days = [10, 25]
	clock.total_days = DAY_10 + 1
	assert_eq(stall.get_options().size(), 0, "closed on day 11")
	clock.total_days = 24
	assert_true(stall.get_options().size() > 0, "open on day 25")
	stall.free()
	gs.end_session()
