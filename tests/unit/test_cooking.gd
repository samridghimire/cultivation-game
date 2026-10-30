extends TestCase
## FISH-002: home meals (Cooking) and the shorten_injury effect.


func test_cook_takes_ingredients_and_gives_the_dish() -> void:
	var c := new_character()
	assert_true(Cooking.check(c, data(), "fish_stew") != "", "no fish, no stew")
	c.add_item("silver_carp", 3)
	var result := Cooking.cook(c, data(), "fish_stew")
	assert_true(result["ok"])
	assert_eq(c.item_count("silver_carp"), 1)
	assert_eq(c.item_count("fish_stew"), 1)
	assert_false(Cooking.cook(c, data(), "fish_stew")["ok"], "one carp is not enough")
	assert_true(Cooking.check(c, data(), "nonsense") != "")


func test_stew_shortens_injuries_and_needs_one() -> void:
	var c := new_character()
	c.add_item("fish_stew", 2)
	assert_eq(Effects.check(c, data(), data().items["fish_stew"]["effects"]), "", "the warm belly buff needs no injury")
	assert_eq(Effects.check(c, data(), {"shorten_injury": 3}), "You have no injury that this would ease.")
	Injuries.inflict(c, data(), "broken_bones")
	var days := int(c.injuries["broken_bones"])
	var result := Items.use(c, data(), "fish_stew", {})
	assert_true(result["ok"])
	assert_eq(int(c.injuries["broken_bones"]), days - 3)
	assert_eq(c.item_count("fish_stew"), 1)


func test_shorten_can_finish_an_injury() -> void:
	var c := new_character()
	Injuries.inflict(c, data(), "broken_bones")
	var healed := Injuries.shorten(c, 9999)
	assert_eq(healed.size(), 1)
	assert_false(Injuries.has_any(c))


func test_shorten_validation_rejects_bad_days() -> void:
	assert_eq(Effects.validate(data(), {"shorten_injury": 5}, "x").size(), 0)
	assert_gt(Effects.validate(data(), {"shorten_injury": 0}, "x").size(), 0)
	assert_gt(Effects.validate(data(), {"shorten_injury": 99}, "x").size(), 0)


func test_meals_give_buffs() -> void:
	var c := new_character()
	c.add_item("fish_stew", 1)
	var result := Items.use(c, data(), "fish_stew", {})
	assert_true(result["ok"], "a healthy cook can eat the stew for the buff")
	assert_eq(int(c.buffs["warm_belly"]["days"]), 3)
	assert_eq(Buffs.multiplier(c, "defense"), 1.1)
	Buffs.pass_days(c, 3)
	assert_false(c.buffs.has("warm_belly"))
	c.add_item("eel_congee", 1)
	Injuries.inflict(c, data(), "broken_bones")
	var days := int(c.injuries["broken_bones"])
	Items.use(c, data(), "eel_congee", {})
	assert_eq(int(c.injuries["broken_bones"]), days - 5, "still eases the injury")
	assert_true(c.buffs.has("eels_vigour"))


func test_herb_porridge_and_description() -> void:
	var c := new_character()
	c.add_item("spirit_herb", 1)
	c.add_item("sweet_rice_ball", 1)
	assert_true(Cooking.cook(c, data(), "herb_porridge")["ok"])
	Items.use(c, data(), "herb_porridge", {})
	assert_gt(Buffs.multiplier(c, "max_hp"), 1.0)
	assert_true(Cooking.describe(data(), "fish_stew").contains("defense"), Cooking.describe(data(), "fish_stew"))


func test_meal_buff_validation() -> void:
	var d := GameData.load_from_dir()
	assert_eq(d.load_errors.size(), 0)
	d.items["fish_stew"]["effects"]["buff"]["mults"]["defense"] = 0.3
	d._validate_home_meals()
	assert_gt(d.load_errors.size(), 0)
	d.load_errors.clear()
	d.items["fish_stew"]["effects"]["buff"]["mults"]["defense"] = 0.1
	d.items["fish_stew"]["effects"]["buff"]["days"] = 8
	d._validate_home_meals()
	assert_gt(d.load_errors.size(), 0)


func test_cook_options_list_every_meal_with_its_effect() -> void:
	var c := new_character()
	var options := Workshop.cook_options(c, data())
	assert_eq(options.size(), data().home_meals.size())
	for option in options:
		assert_true(option["disabled"], "no ingredients yet")
		assert_true(String(option["description"]).contains("for 3 days"), option["description"])
	c.add_item("silver_carp", 2)
	assert_false(Workshop.cook_options(c, data())[0]["disabled"])


func test_folk_ask_for_fish_exists() -> void:
	var found := false
	for ask: Dictionary in data().family["folk_requests"]["asks"]:
		found = found or String(ask["item"]) == "silver_carp"
	assert_true(found)
