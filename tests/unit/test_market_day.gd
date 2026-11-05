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


# --- MARKET-008: wanted items ---

func test_wanted_deterministic_and_open_day_only() -> void:
	var place := _stall()
	var w := Places.wanted_today(place, DAY_10)
	assert_false(w.is_empty())
	assert_eq(Places.wanted_today(place, DAY_10), w, "same day, same want")
	assert_true((place["wanted"]["pool"] as Array).has(w["item"]))
	assert_eq(float(w["mult"]), 1.5)
	assert_true(Places.wanted_today(place, DAY_10 + 1).is_empty(), "closed day")
	assert_true(Places.wanted_today({"display_name": "x"}, DAY_10).is_empty())
	var seen := {}
	for month in 12:
		seen[Places.wanted_today(place, DAY_10 + 30 * month)["item"]] = true
	assert_true(seen.size() > 1, "the want changes between market days")


func test_wanted_validation() -> void:
	var data := _gd()
	var place := _stall().duplicate(true)
	assert_eq(Places.validate_wanted(place["wanted"], place, data.items, "x").size(), 0)
	assert_true(Places.validate_wanted({"pool": ["boar_hide"], "mult": 3.0}, place, data.items, "x").size() > 0, "mult too high")
	assert_true(Places.validate_wanted({"pool": ["nope"], "mult": 1.5}, place, data.items, "x").size() > 0, "unknown item")
	assert_true(Places.validate_wanted({"pool": [], "mult": 1.5}, place, data.items, "x").size() > 0, "empty pool")
	place.erase("rotating_stock")
	assert_true(Places.validate_wanted({"pool": ["boar_hide"], "mult": 1.5}, place, data.items, "x").size() > 0, "needs rotating_stock")


func test_hint_line_names_wanted() -> void:
	var today := Places.hint_line(_region(), DAY_10, 5, _gd())
	assert_true("; wants " in today and "(x1.5)" in today, today)


func test_wu445_market_day_marks_only_on_open_days() -> void:
	var stall := _stall()
	assert_true(Places.is_market_day_stall(stall, DAY_10))
	assert_false(Places.is_market_day_stall(stall, DAY_10 + 1))
	assert_false(Places.is_market_day_stall({"open_days": [10]}, DAY_10), "no rotating stock, no mark")
	assert_true(load("res://src/world/interactables/merchant.gd").shows_market_mark(stall["open_days"], stall["rotating_stock"], DAY_10))
	assert_false(load("res://src/world/interactables/merchant.gd").shows_market_mark(stall["open_days"], stall["rotating_stock"], DAY_10 + 1))


func test_wu445_map_line_and_shop_title_note() -> void:
	var line := Places.market_day_line(_region(), DAY_10)
	assert_true(line.contains("Travelling Market Stall") and line.contains("new wares"), line)
	assert_eq(Places.market_day_line(_region(), DAY_10 + 1), "")
	var note := Places.new_today_note(_region(), "Travelling Market Stall", DAY_10, _gd())
	assert_true(note.begins_with("  New today: "), note)
	assert_eq(note.split(", ").size(), 3, "three wares")
	assert_eq(Places.new_today_note(_region(), "Travelling Market Stall", DAY_10 + 1, _gd()), "")
	assert_eq(Places.new_today_note(_region(), "Wandering Merchant", DAY_10, _gd()), "")


## MARKET-009: regular status, the extra pick, validation.
func test_regular_extra_pick_keeps_first_picks() -> void:
	var place := _stall()
	var plain := Places.rotating_picks(place, DAY_10)
	var reg := Places.rotating_picks(place, DAY_10, true)
	assert_eq(reg.size(), plain.size() + 1)
	assert_eq(reg.slice(0, plain.size()), plain, "first picks unchanged")
	assert_eq(Places.rotating_picks(place, DAY_10 + 1, true).size(), 0, "closed day")
	assert_eq(Places.stock_tags_today(place, DAY_10, true).size(), Places.stock_tags_today(place, DAY_10).size() + 1)


func test_is_regular_threshold_and_defaults() -> void:
	var place := _stall()
	assert_eq(Places.regular_after(place), 3)
	assert_true(absf(Places.regular_discount(place) - 0.1) < 0.0001)
	assert_false(Places.is_regular(place, 2))
	assert_true(Places.is_regular(place, 3))
	assert_false(Places.is_regular({}, 9), "no wanted block")


func test_hint_line_says_regular() -> void:
	var line := Places.hint_line(_region(), DAY_10, 5, _gd(), {"travelling_market_stall": 3})
	assert_true(line.contains("you are a regular here (-10%)"), line)
	assert_false(Places.hint_line(_region(), DAY_10, 5, _gd(), {"travelling_market_stall": 2}).contains("regular"))


func test_regular_note_newcomer_and_regular() -> void:
	var place := _stall()
	var wants := Places.wanted_phrase(place, DAY_10, _gd())
	var zero := Places.regular_note(place, 0, DAY_10, _gd())
	assert_true(zero.contains("Wanted today: " + wants), zero)
	assert_true(zero.contains("Sold on 0 of 3 market days to become a regular."), zero)
	assert_true(Places.regular_note(place, 1, DAY_10, _gd()).contains("Sold on 1 of 3"))
	assert_true(Places.regular_note(place, 2, DAY_10, _gd()).contains("Sold on 2 of 3"))
	var reg := Places.regular_note(place, 3, DAY_10, _gd())
	assert_eq(reg, "  Regular here: 10%% off new wares, %d on the table" % Places.rotating_picks(place, DAY_10, true).size())
	assert_true(reg.contains("4 on the table"), reg)
	assert_eq(Places.regular_note({"rotating_stock": {}}, 5, DAY_10, _gd()), "", "no wanted block")


func test_hint_line_regular_tag_on_name() -> void:
	var reg := {"travelling_market_stall": 3}
	assert_true(Places.hint_line(_region(), DAY_10, 5, _gd(), reg).contains("Travelling Market Stall (regular) sells"))
	assert_true(Places.hint_line(_region(), DAY_10 - 3, 5, _gd(), reg).contains("Travelling Market Stall (regular) (new wares"))
	assert_false(Places.hint_line(_region(), DAY_10 - 3, 5, _gd(), {}).contains("(regular)"))


func test_validate_wanted_regular_fields() -> void:
	var place := _stall()
	var good: Dictionary = (place["wanted"] as Dictionary).duplicate()
	good["regular_after"] = 2
	good["regular_discount"] = 0.3
	assert_eq(Places.validate_wanted(good, place, _gd().items, "x").size(), 0)
	good["regular_after"] = 0
	assert_eq(Places.validate_wanted(good, place, _gd().items, "x").size(), 1)
	good["regular_after"] = 3
	good["regular_discount"] = 0.5
	assert_eq(Places.validate_wanted(good, place, _gd().items, "x").size(), 1)


func test_market_regular_save_round_trip_and_default() -> void:
	var c := CharacterData.new()
	c.market_regular = {"travelling_market_stall": 2}
	assert_eq(CharacterData.from_dict(c.to_dict()).market_regular, {"travelling_market_stall": 2})
	var d := c.to_dict()
	d.erase("market_regular")
	assert_eq(CharacterData.from_dict(d).market_regular, {})


## C-299: every wanted pool pays (sell price x mult) below the item's buy price, so there is no buy-here-sell-there loop.
func test_c299_wanted_never_beats_buy_price() -> void:
	var data := _gd()
	var seen := 0
	for rid: String in data.regions:
		for place: Dictionary in data.regions[rid].get("places", []):
			if not place.has("wanted"):
				continue
			seen += 1
			var mult := float(place["wanted"]["mult"])
			for id: Variant in place["wanted"]["pool"]:
				var buy := int(data.items[String(id)]["price"])
				for season: String in ["spring", "summer", "autumn", "winter"]:
					assert_true(float(Items.sell_price(data, String(id), season)) * mult < float(buy) * Items.seasonal_mult(data, String(id), season) + 0.001 or buy <= 2, "%s at %s" % [id, place["display_name"]])
	assert_true(seen >= 3, "three stalls want things")


## C-299: the night stall and the marsh skiff run rotating carts with valid pools; the skiff opens twice a month.
func test_c299_new_carts() -> void:
	var data := _gd()
	var night := ShopDiscounts.place_named(data, "fallen_star_market", "Night Market Stall")
	var skiff := ShopDiscounts.place_named(data, "withered_bone_marsh", "Corpse Peddler's Skiff")
	for place: Dictionary in [night, skiff]:
		assert_false(place.is_empty())
		assert_eq(Places.validate_rotating(place["rotating_stock"], place, data.items, data.restricted_item_tags, "x").size(), 0)
		assert_true((place["rotating_stock"]["pool"] as Array).size() >= 8)
	assert_eq((skiff["open_days"] as Array).size(), 2)


## MARKET-010: a rotating stall without stock_tags keeps selling plain untagged goods beside its picks.
func test_night_stall_keeps_untagged_wares() -> void:
	var data := _gd()
	var place := ShopDiscounts.place_named(data, "fallen_star_market", "Night Market Stall")
	var max_price := int(place.get("max_price", 0))
	var tags := Places.stock_tags_today(place, DAY_10)
	assert_true(tags.has("untagged"))
	var picks := Places.rotating_picks(place, DAY_10)
	assert_true(picks.size() > 0)
	assert_true(Items.merchant_sells(data, data.items["paper_lantern"], tags, max_price), "plain cheap item")
	assert_true(Items.merchant_sells(data, data.items[picks[0]], tags, max_price), "a pick")
	var rich: Dictionary = data.items["foundation_establishment_pill"]
	assert_false(Items.merchant_sells(data, rich, tags, max_price), "over max_price")
	# Guidance-style call with the plain (empty) stock_tags agrees on the untagged item.
	assert_true(Items.merchant_sells(data, data.items["paper_lantern"], place.get("stock_tags", []), max_price))
	# The Travelling Market Stall has stock_tags: no untagged added.
	assert_false(Places.stock_tags_today(_stall(), DAY_10).has("untagged"))
	assert_false(Items.merchant_sells(data, data.items["paper_lantern"], ["herb"], max_price), "tagged stall unchanged")
