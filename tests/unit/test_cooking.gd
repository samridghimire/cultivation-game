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
	assert_eq(options.size(), Cooking.known_meals(c, data()).size())
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


## C-302: each weather herb cooks into a dish with an effect, and its description hints the use.
func test_c302_weather_herb_dishes() -> void:
	for pair: Array in [["rain_cap_mushroom", "rain_cap_broth"], ["fogbloom_moss", "fogbloom_tonic"], ["frostbell_herb", "frostbell_tea"]]:
		var c := new_character()
		c.add_item(pair[0], 2)
		Cooking.learn(c, data(), pair[1])
		assert_true(Cooking.cook(c, data(), pair[1])["ok"], pair[1])
		assert_eq(c.item_count(pair[1]), 1)
		assert_true(String(data().items[pair[0]]["description"]).contains("cook") or String(data().items[pair[0]]["description"]).contains("brew") or String(data().items[pair[0]]["description"]).contains("steep"), pair[0])
	var c2 := new_character()
	c2.add_item("rain_cap_mushroom", 2)
	Cooking.cook(c2, data(), "rain_cap_broth")
	Items.use(c2, data(), "rain_cap_broth", {})
	assert_gt(Buffs.multiplier(c2, "max_hp"), 1.0)


## COOK-001: dishes friends teach.
func test_taught_meal_hidden_until_learned() -> void:
	var c := new_character()
	assert_false(Cooking.is_known(c, data(), "honey_egg_cake"))
	assert_true(Cooking.is_known(c, data(), "fish_stew"))
	assert_eq(Cooking.known_meals(c, data()).size(), data().home_meals.size() - 4)
	assert_eq(Workshop.cook_options(c, data()).size(), data().home_meals.size() - 4)
	for item_id: Variant in Cooking.meal(data(), "honey_egg_cake")["ingredients"]:
		c.add_item(String(item_id), 9)
	assert_eq(Cooking.check(c, data(), "honey_egg_cake"), "You have not learned to cook that.")
	assert_true(Cooking.learn(c, data(), "honey_egg_cake"))
	assert_false(Cooking.learn(c, data(), "honey_egg_cake"), "twice")
	assert_false(Cooking.learn(c, data(), "fish_stew"), "not taught")
	assert_false(Cooking.learn(c, data(), "nonsense"))
	assert_eq(Workshop.cook_options(c, data()).size(), data().home_meals.size() - 3)
	assert_true(Cooking.cook(c, data(), "honey_egg_cake")["ok"])


func test_known_dishes_round_trip() -> void:
	var c := new_character()
	Cooking.learn(c, data(), "egg_custard")
	var back := CharacterData.from_dict(c.to_dict())
	assert_eq(back.known_dishes, ["egg_custard"] as Array[String])
	var d := c.to_dict()
	d.erase("known_dishes")
	assert_eq(CharacterData.from_dict(d).known_dishes.size(), 0)


func test_learn_dish_effect() -> void:
	var c := new_character()
	var fx := {"learn_dish": "boar_roast"}
	assert_eq(Effects.check(c, data(), fx), "")
	var notes := Effects.apply(c, data(), fx, {})
	assert_true(", ".join(notes).contains("Learned to cook Boar Roast"), str(notes))
	assert_true(Effects.check(c, data(), fx).contains("already know"))
	assert_eq(Effects.validate(data(), fx, "t").size(), 0)
	assert_gt(Effects.validate(data(), {"learn_dish": "nope"}, "t").size(), 0)
	assert_gt(Effects.validate(data(), {"learn_dish": "fish_stew"}, "t").size(), 0)


func test_shorten_injury_note_only_when_injured() -> void:
	var c := new_character()
	var notes := Effects.apply(c, data(), {"shorten_injury": 3}, {})
	assert_false(", ".join(notes).contains("injuries ease"), str(notes))


## REVIEW: a save from before COOK-001 that already cooked a now-taught dish keeps it.
func test_cooked_dish_from_old_save_stays_known() -> void:
	var c := new_character()
	var d := c.to_dict()
	d.erase("known_dishes")
	d["cooked_meals"] = {"boar_roast": 2}
	var old := CharacterData.from_dict(d)
	assert_true(Cooking.is_known(old, data(), "boar_roast"))
	assert_false(Cooking.is_known(old, data(), "egg_custard"))
	assert_false(Cooking.learn(old, data(), "boar_roast"), "already known")
	assert_true(Effects.check(old, data(), {"learn_dish": "boar_roast"}) != "")
