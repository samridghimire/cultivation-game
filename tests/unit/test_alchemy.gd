extends TestCase
## Alchemy: success chance, ingredient checks, refining and the GameState action.


func _alchemist(rank: int = 0, comprehension: int = 10) -> CharacterData:
	var c := new_character()
	c.inventory = {}
	c.attributes["comprehension"] = comprehension
	if rank > 0:
		c.professions["alchemist"] = {"rank": rank, "xp": 0.0}
	return c


func _stock(c: CharacterData, recipe_id: String, batches: int = 1) -> void:
	var ingredients: Dictionary = data().recipes[recipe_id]["ingredients"]
	for item_id in ingredients:
		c.add_item(item_id, int(ingredients[item_id]) * batches)


func test_recipes_load() -> void:
	assert_true(data().recipes.has("qi_gathering_pill"))
	assert_true(data().load_errors.is_empty(), ", ".join(data().load_errors))


func test_chance_grows_with_rank_and_comprehension() -> void:
	var base := Alchemy.success_chance(_alchemist(), data(), "qi_gathering_pill")
	assert_almost_eq(base, float(data().alchemy["base_chance"]))
	assert_gt(Alchemy.success_chance(_alchemist(3), data(), "qi_gathering_pill"), base)
	assert_gt(Alchemy.success_chance(_alchemist(0, 15), data(), "qi_gathering_pill"), base)
	assert_gt(base, Alchemy.success_chance(_alchemist(0, 5), data(), "qi_gathering_pill"))


func test_chance_is_clamped() -> void:
	var t := data().alchemy
	assert_almost_eq(Alchemy.success_chance(_alchemist(10, 30), data(), "qi_gathering_pill"), float(t["max_chance"]))
	assert_almost_eq(Alchemy.success_chance(_alchemist(0, 0), data(), "jade_marrow_pill"), float(t["min_chance"]))


func test_harder_recipes_are_less_likely() -> void:
	var c := _alchemist(4)
	assert_gt(Alchemy.success_chance(c, data(), "qi_gathering_pill"), Alchemy.success_chance(c, data(), "jade_marrow_pill"))


func test_check_rank_and_ingredients() -> void:
	var c := _alchemist()
	assert_true(Alchemy.check(c, data(), "qi_gathering_pill").begins_with("Missing"))
	_stock(c, "qi_gathering_pill")
	assert_eq(Alchemy.check(c, data(), "qi_gathering_pill"), "")
	_stock(c, "jade_marrow_pill")
	assert_true(Alchemy.check(c, data(), "jade_marrow_pill").begins_with("Requires"))
	assert_true(Alchemy.check(c, data(), "no_such_recipe") != "")


func test_known_recipes_follow_rank() -> void:
	var novice := Alchemy.known_recipes(_alchemist(), data())
	assert_true(novice.has("qi_gathering_pill"))
	assert_false(novice.has("jade_marrow_pill"))
	assert_true(Alchemy.known_recipes(_alchemist(10), data()).has("jade_marrow_pill"))


func test_refine_without_ingredients_changes_nothing() -> void:
	var c := _alchemist()
	var result := Alchemy.refine(c, data(), "qi_gathering_pill", seeded_rng())
	assert_false(result["ok"])
	assert_eq(Professions.xp_of(c, "alchemist"), 0.0)


func test_refine_success_and_failure() -> void:
	var recipe: Dictionary = data().recipes["qi_gathering_pill"]
	var c := _alchemist()
	_stock(c, "qi_gathering_pill", 40)
	var rng := seeded_rng()
	var successes := 0
	var failures := 0
	for i in 40:
		var pills_before := c.item_count("qi_gathering_pill")
		var xp_before := Professions.xp_of(c, "alchemist") + Professions.rank_of(c, "alchemist") * 10000.0
		var result := Alchemy.refine(c, data(), "qi_gathering_pill", rng)
		assert_true(result["ok"])
		assert_eq(result["days"], int(recipe["days"]))
		if result["success"]:
			successes += 1
			assert_eq(c.item_count("qi_gathering_pill") - pills_before, int(recipe["output"]["count"]))
			assert_almost_eq(result["xp"], float(recipe["xp"]))
		else:
			failures += 1
			assert_eq(c.item_count("qi_gathering_pill"), pills_before)
			assert_almost_eq(result["xp"], float(recipe["xp"]) * float(data().alchemy["failure_xp_fraction"]))
		assert_gt(Professions.xp_of(c, "alchemist") + Professions.rank_of(c, "alchemist") * 10000.0, xp_before)
	assert_gt(successes, 0)
	assert_gt(failures, 0)
	for item_id in recipe["ingredients"]:
		assert_eq(c.item_count(item_id), 0, "all ingredients consumed, success or not")


func test_refining_is_deterministic() -> void:
	var a := _alchemist()
	var b := _alchemist()
	_stock(a, "qi_gathering_pill", 10)
	_stock(b, "qi_gathering_pill", 10)
	var rng_a := seeded_rng(7)
	var rng_b := seeded_rng(7)
	for i in 10:
		assert_eq(Alchemy.refine(a, data(), "qi_gathering_pill", rng_a)["success"], Alchemy.refine(b, data(), "qi_gathering_pill", rng_b)["success"])


func test_game_state_refine() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var gs := tree.root.get_node("GameState")
	var clock := tree.root.get_node("GameClock")
	var c := CharacterFactory.create("Alchemist", gs.data, seeded_rng())
	gs.start_session(c)
	gs.refine("qi_gathering_pill")
	assert_eq(clock.total_days, 0, "no time passes without ingredients")
	var ingredients: Dictionary = gs.data.recipes["qi_gathering_pill"]["ingredients"]
	for item_id in ingredients:
		c.add_item(item_id, int(ingredients[item_id]))
	gs.refine("qi_gathering_pill")
	assert_eq(clock.total_days, int(gs.data.recipes["qi_gathering_pill"]["days"]))
	assert_gt(Professions.xp_of(c, "alchemist"), 0.0)
	for item_id in ingredients:
		assert_eq(c.item_count(item_id), 0)
	gs.end_session()
