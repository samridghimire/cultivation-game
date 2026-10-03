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


# --- Merchant stock rules (LIFE-001f) -------------------------------------------

func _merchant_places() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for region: Dictionary in data().regions.values():
		for place: Dictionary in region.get("places", []):
			if place.get("type", "") == "merchant":
				out.append(place)
	return out


func test_restricted_items_need_an_explicit_stock_tag() -> void:
	var saber: Dictionary = data().items["blood_drinker_saber"]
	assert_gt(int(saber["price"]), 0, "evil artifacts are for sale")
	assert_false(Items.merchant_sells(data(), saber, ["equipment"]), "an ordinary smithy will not sell it")
	assert_true(Items.merchant_sells(data(), saber, ["demonic"]))
	assert_true(Items.merchant_sells(data(), data().items["iron_sword"], ["equipment"]))
	assert_false(Items.merchant_sells(data(), data().items["iron_sword"], ["demonic"]))
	assert_false(Items.merchant_sells(data(), saber, ["demonic"], 100), "max_price still applies")


func test_untagged_goods_and_unpriced_items() -> void:
	assert_true(Items.merchant_sells(data(), data().items["qi_gathering_pill"], []))
	assert_false(Items.merchant_sells(data(), data().items["iron_sword"], []), "tagged goods need a tag merchant")
	assert_false(Items.merchant_sells(data(), {"id": "x", "price": 0}, []))


func test_merchant_alignment_gate() -> void:
	var c := new_character()
	c.alignment = 0
	assert_true(Items.check_merchant(c, -1000000, -200).contains("righteous"))
	c.alignment = -200
	assert_eq(Items.check_merchant(c, -1000000, -200), "")
	c.alignment = -900
	assert_true(Items.check_merchant(c, -500, 1000).contains("evil"))


func test_every_evil_artifact_has_a_black_market() -> void:
	for item: Dictionary in data().items.values():
		if not (item.get("tags", []) as Array).has("demonic"):
			continue
		var sellers := 0
		for place in _merchant_places():
			if Items.merchant_sells(data(), item, place.get("stock_tags", []), int(place.get("max_price", 0))):
				sellers += 1
				assert_true(int(place.get("max_alignment", 1000000)) < 0, "%s sells demonic goods only to the wicked" % place["display_name"])
		assert_gt(sellers, 0, "%s is sold somewhere" % item["id"])


func test_buying_an_evil_artifact_through_game_state() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var c := CharacterFactory.create("Wicked", gs.data, seeded_rng())
	gs.start_session(c)
	c.inventory["spirit_stone"] = 2000
	gs.buy_item("blood_drinker_saber")
	assert_eq(c.item_count("blood_drinker_saber"), 1)
	assert_eq(c.item_count("spirit_stone"), 2000 - int(gs.data.items["blood_drinker_saber"]["price"]))
	gs.end_session()
