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
	assert_eq(Effects.check(c, data(), data().items["fish_stew"]["effects"]), "You have no injury that this would ease.")
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


func test_folk_ask_for_fish_exists() -> void:
	var found := false
	for ask: Dictionary in data().family["folk_requests"]["asks"]:
		found = found or String(ask["item"]) == "silver_carp"
	assert_true(found)
