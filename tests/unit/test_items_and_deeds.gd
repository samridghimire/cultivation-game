extends TestCase


func test_buy_requires_stones() -> void:
	var c := new_character()
	c.inventory = {}
	assert_false(Items.buy(c, data(), "qi_gathering_pill")["ok"])
	c.add_item("spirit_stone", 100)
	assert_true(Items.buy(c, data(), "qi_gathering_pill")["ok"])
	assert_eq(c.item_count("qi_gathering_pill"), 1)
	assert_eq(c.item_count("spirit_stone"), 100 - int(data().items["qi_gathering_pill"]["price"]))


func test_using_pill_applies_effects_and_consumes_it() -> void:
	var c := new_character()
	c.add_item("foundation_establishment_pill", 1)
	assert_true(Items.use(c, data(), "foundation_establishment_pill", {})["ok"])
	assert_almost_eq(c.breakthrough_bonus, 0.25)
	assert_eq(c.item_count("foundation_establishment_pill"), 0)


func test_spirit_stones_are_not_usable() -> void:
	var c := new_character()
	assert_false(Items.use(c, data(), "spirit_stone", {})["ok"])


func test_evil_deed_lowers_alignment() -> void:
	var c := new_character()
	var result := Deeds.perform(c, data(), "rob_villager", {})
	assert_true(result["ok"])
	assert_gt(0, c.alignment)


func test_deed_cost_must_be_affordable() -> void:
	var c := new_character()
	c.inventory = {}
	assert_false(Deeds.perform(c, data(), "donate_stones", {})["ok"])
	assert_eq(c.alignment, 0)


func test_killing_sets_flag_and_hides_deeds() -> void:
	var c := new_character()
	var flags := {}
	Deeds.perform(c, data(), "kill_villager", flags)
	assert_true(flags.get("villager_dead", false))
	assert_eq(Deeds.available(data(), "villager", flags).size(), 0)


func test_raw_materials_sell_at_half_price() -> void:
	assert_eq(Items.material_value(data(), "cold_iron"), -1.0)
	assert_eq(Items.sell_price(data(), "cold_iron"), int(int(data().items["cold_iron"]["price"]) * Items.SELL_RATE))


func test_crafted_goods_sell_near_material_cost() -> void:
	# Golden Bell: 1 talisman paper (3) + 1 iron essence (8) -> 2 talismans.
	assert_almost_eq(Items.material_value(data(), "golden_bell_talisman"), 5.5)
	var markup := float(data().alchemy["crafted_sell_markup"])
	assert_eq(Items.sell_price(data(), "golden_bell_talisman"), ceili(5.5 * markup))
	assert_gt(int(data().items["golden_bell_talisman"]["price"]) * Items.SELL_RATE, Items.sell_price(data(), "golden_bell_talisman"))


func test_every_crafted_item_has_capped_buyback() -> void:
	var markup := float(data().alchemy["crafted_sell_markup"])
	for item_id: String in data().items:
		var material := Items.material_value(data(), item_id)
		var half := int(int(data().items[item_id].get("price", 0)) * Items.SELL_RATE)
		if material < 0.0 or half <= 0:
			continue
		var price := Items.sell_price(data(), item_id)
		assert_gt(price, 0, item_id)
		assert_true(price <= half, "%s sells above half price" % item_id)
		assert_true(price <= ceili(material * markup), "%s sells above its material markup" % item_id)


func test_starter_talisman_trade_is_modest() -> void:
	# A rank 0 Talisman Master buying materials and selling Golden Bells back
	# should beat working (talisman work_income per day) but not by a fortune.
	var recipe: Dictionary = data().recipes["golden_bell_talisman"]
	var cost := 0
	for item_id: String in recipe["ingredients"]:
		cost += int(data().items[item_id]["price"]) * int(recipe["ingredients"][item_id])
	var income := Items.sell_price(data(), "golden_bell_talisman") * int(recipe["output"]["count"])
	var profit_per_day := float(income - cost) / int(recipe["days"])
	assert_gt(profit_per_day, 0.0)
	assert_gt(3.0, profit_per_day, "Golden Bell resale nets %.1f stones/day" % profit_per_day)


func test_selling_crafted_goods_pays_capped_price() -> void:
	var c := new_character()
	c.inventory = {"golden_bell_talisman": 2}
	var result := Items.sell(c, data(), "golden_bell_talisman", 2)
	assert_true(result["ok"])
	assert_eq(c.item_count("spirit_stone"), 2 * Items.sell_price(data(), "golden_bell_talisman"))
