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
