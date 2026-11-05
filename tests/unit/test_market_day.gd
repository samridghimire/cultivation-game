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
	assert_eq(Places.hint_line(region, DAY_10 - 3), "Market day in 3 days: Travelling Market Stall (new wares each time)")
	assert_eq(Places.hint_line(region, DAY_10 - 1), "Market day in 1 day: Travelling Market Stall (new wares each time)")
	assert_eq(Places.hint_line(region, DAY_10 + 1), "", "14 days away: no hint")
	assert_eq(Places.hint_line(region, DAY_10 - 6), "", "6 days away: no hint")


func test_journal_village_card_mentions_market_day() -> void:
	var data := _gd()
	var c := CharacterFactory.create("Market", data, seeded_rng(), "male")
	var lines := Guidance.village_lines(c, data, {}, {}, "qingshi_village", DAY_10 - 2)
	assert_true("Market day in 2 days: Travelling Market Stall (new wares each time)" in lines)
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


# MARKET-003

func test_days_phrase() -> void:
	assert_eq(Places.days_phrase({"open_days": [10, 25]}), "market days 10 and 25")
	assert_eq(Places.days_phrase({"open_days": [5.0, 15.0, 25.0]}), "market days 5, 15 and 25")
	assert_eq(Places.days_phrase({"open_days": [7]}), "market day 7")
	assert_eq(Places.days_phrase({}), "")


func test_sold_at_names_market_days() -> void:
	var lines := Items.sources(_gd(), "sweet_rice_ball")
	assert_true(lines.has("Sold at Travelling Market Stall (market days 10 and 25), Qingshi Village"), str(lines))


func test_closed_stall_not_a_dependable_seller() -> void:
	assert_false(Guidance.merchant_place(_gd(), "qingshi_village", "sweet_rice_ball").has("open_days"), "never the closed stall")
	assert_false(Guidance.timed_stall(_gd(), "qingshi_village", "sweet_rice_ball").is_empty())


func test_stall_ingredient_line_counts_days() -> void:
	var recipe := {"name": "Rice Feast"}
	var stall := _stall()
	var line := Guidance._stall_ingredient_line(CharacterData.new(), _gd(), recipe, "sweet_rice_ball", stall, DAY_10 - 3)
	assert_true(line.contains("next market day in 3 days"), line)
	assert_true(line.contains("market days 10 and 25"), line)
	assert_true(Guidance._stall_ingredient_line(CharacterData.new(), _gd(), recipe, "sweet_rice_ball", stall, DAY_10).contains("open today"))


func test_close_shop_clears_seller() -> void:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	gs.shop_name = "Village Herb Seller"
	gs.close_shop()
	assert_eq(gs.shop_name, "")


# --- MARKET-007: rotating stock ---

func test_rotating_picks_deterministic_distinct_and_vary() -> void:
	var place := _stall()
	var a := Places.rotating_picks(place, DAY_10)
	assert_eq(a.size(), 3)
	assert_eq(Places.rotating_picks(place, DAY_10), a, "same day, same wares")
	var pool_ids: Array[String] = []
	for e: Dictionary in place["rotating_stock"]["pool"]:
		pool_ids.append(String(e["item"]))
	for id in a:
		assert_true(pool_ids.has(id), id)
	assert_eq(a.size(), Array(a).duplicate().filter(func(x: String) -> bool: return a.count(x) == 1).size(), "distinct")
	var differs := false
	for month in range(1, 6):
		if Places.rotating_picks(place, DAY_10 + 30 * month) != a:
			differs = true
	assert_true(differs, "other open days differ")
	assert_eq(Places.rotating_picks(place, DAY_10 + 1).size(), 0, "closed day")
	assert_eq(Places.rotating_picks({"display_name": "x"}, 3).size(), 0, "no rotating_stock")


func test_stock_tags_today_keeps_fixed_tags() -> void:
	var tags := Places.stock_tags_today(_stall(), DAY_10)
	assert_eq(tags.size(), 6)
	assert_true(tags.has("sweet_rice_ball"))


func test_rotating_validation() -> void:
	var data := _gd()
	var place := {"type": "merchant"}
	var ok := {"pool": [{"item": "qi_gathering_pill", "weight": 1}], "count": 1}
	assert_eq(Places.validate_rotating(ok, place, data.items, data.restricted_item_tags, "x").size(), 0)
	var zero := {"pool": [{"item": "qi_gathering_pill", "weight": 0}], "count": 1}
	assert_eq(Places.validate_rotating(zero, place, data.items, data.restricted_item_tags, "x").size(), 1)
	var unknown := {"pool": [{"item": "nope", "weight": 1}], "count": 1}
	assert_true(Places.validate_rotating(unknown, place, data.items, data.restricted_item_tags, "x").size() > 0)
	var big := {"pool": [{"item": "qi_gathering_pill", "weight": 1}], "count": 2}
	assert_true(Places.validate_rotating(big, place, data.items, data.restricted_item_tags, "x").size() > 0)


func test_stall_pool_is_valid_and_no_gear() -> void:
	var data := _gd()
	var place := _stall()
	assert_eq(Places.validate_rotating(place["rotating_stock"], place, data.items, data.restricted_item_tags, "x").size(), 0)
	for e: Dictionary in place["rotating_stock"]["pool"]:
		var item: Dictionary = data.items[e["item"]]
		assert_true(int(item["price"]) <= 120, e["item"])
		assert_false((item.get("tags", []) as Array).has("weapon") or (item.get("tags", []) as Array).has("armor") or (item.get("tags", []) as Array).has("equipment"), e["item"])
		assert_true(Items.merchant_sells(data, item, Places.stock_tags_today(place, DAY_10).duplicate() + [e["item"]], 0), e["item"])


func test_hint_line_rotating() -> void:
	var region := _region()
	assert_eq(Places.hint_line(region, DAY_10 - 3), "Market day in 3 days: Travelling Market Stall (new wares each time)")
	var today := Places.hint_line(region, DAY_10, 5, _gd())
	assert_true(today.begins_with("Market day today: Travelling Market Stall sells "), today)
