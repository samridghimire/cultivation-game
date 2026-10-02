extends TestCase
## Alchemy: success chance, ingredient checks, refining and the GameState action.


func _alchemist(rank: int = 0, comprehension: int = 10, learn_all: bool = true) -> CharacterData:
	var c := new_character()
	c.inventory = {}
	c.attributes["comprehension"] = comprehension
	if rank > 0:
		c.professions["alchemist"] = {"rank": rank, "xp": 0.0}
	if learn_all:
		for recipe_id in data().recipes:
			Alchemy.learn(c, data(), recipe_id)
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


func test_starter_recipes_are_known_without_learning() -> void:
	var c := _alchemist(0, 10, false)
	var known := Alchemy.known_recipes(c, data())
	assert_true(known.has("qi_gathering_pill"))
	assert_true(known.has("bone_setting_salve"))
	assert_false(known.has("meridian_mending_pill"))
	assert_false(Alchemy.known_recipes(_alchemist(10, 10, false), data()).has("jade_marrow_pill"), "rank alone teaches nothing")


func test_unlearned_recipe_cannot_be_refined() -> void:
	var c := _alchemist(2, 10, false)
	_stock(c, "meridian_mending_pill")
	assert_true(Alchemy.check(c, data(), "meridian_mending_pill").begins_with("You have not learned"))
	assert_false(Alchemy.refine(c, data(), "meridian_mending_pill", seeded_rng())["ok"])
	assert_true(Alchemy.learn(c, data(), "meridian_mending_pill"))
	assert_eq(Alchemy.check(c, data(), "meridian_mending_pill"), "")


func test_learning_ignores_rank_but_refining_does_not() -> void:
	var c := _alchemist(0, 10, false)
	assert_eq(Alchemy.can_learn(c, data(), "jade_marrow_pill"), "")
	assert_true(Alchemy.learn(c, data(), "jade_marrow_pill"))
	assert_true(Alchemy.known_recipes(c, data()).has("jade_marrow_pill"))
	_stock(c, "jade_marrow_pill")
	assert_true(Alchemy.check(c, data(), "jade_marrow_pill").begins_with("Requires"))


func test_cannot_learn_twice_or_unknown() -> void:
	var c := _alchemist(0, 10, false)
	assert_true(Alchemy.can_learn(c, data(), "qi_gathering_pill").begins_with("You already know"), "starter recipe")
	assert_true(Alchemy.learn(c, data(), "meridian_mending_pill"))
	assert_false(Alchemy.learn(c, data(), "meridian_mending_pill"))
	assert_eq(c.known_recipes.size(), 1)
	assert_true(Alchemy.can_learn(c, data(), "no_such_recipe") != "")


func test_recipe_scroll_teaches_recipe() -> void:
	var c := _alchemist(0, 10, false)
	c.add_item("recipe_meridian_mending_pill", 1)
	var result := Items.use(c, data(), "recipe_meridian_mending_pill", {})
	assert_true(result["ok"], str(result))
	assert_true(Alchemy.knows(c, data(), "meridian_mending_pill"))
	assert_eq(c.item_count("recipe_meridian_mending_pill"), 0)
	c.add_item("recipe_meridian_mending_pill", 1)
	assert_false(Items.use(c, data(), "recipe_meridian_mending_pill", {})["ok"], "already known")
	assert_eq(c.item_count("recipe_meridian_mending_pill"), 1, "scroll kept when nothing to learn")


func test_every_non_starter_recipe_has_a_scroll() -> void:
	var taught := {}
	for item: Dictionary in data().items.values():
		var recipe_id: String = item.get("effects", {}).get("learn_recipe", "")
		if recipe_id != "":
			taught[recipe_id] = true
	for recipe: Dictionary in data().recipes.values():
		if not recipe.get("starter", false):
			assert_true(taught.has(recipe["id"]), "no scroll teaches %s" % recipe["id"])


func test_known_recipes_survive_save() -> void:
	var c := _alchemist(0, 10, false)
	Alchemy.learn(c, data(), "foundation_establishment_pill")
	var loaded := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_true(Alchemy.knows(loaded, data(), "foundation_establishment_pill"))
	assert_false(Alchemy.knows(loaded, data(), "jade_marrow_pill"))


func test_old_save_keeps_rank_recipes() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var gs := tree.root.get_node("GameState")
	var c := CharacterFactory.create("Elder Alchemist", gs.data, seeded_rng())
	c.professions["alchemist"] = {"rank": 2, "xp": 0.0}
	gs.start_session(c)
	var save: Dictionary = gs.to_save_dict()
	save["player"].erase("known_recipes")
	gs.load_save_dict(JSON.parse_string(JSON.stringify(save)))
	assert_true(Alchemy.knows(gs.player, gs.data, "foundation_establishment_pill"))
	assert_false(Alchemy.knows(gs.player, gs.data, "jade_marrow_pill"))
	gs.end_session()


func test_game_state_use_recipe_scroll() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var gs := tree.root.get_node("GameState")
	var c := CharacterFactory.create("Scholar", gs.data, seeded_rng())
	gs.start_session(c)
	c.add_item("recipe_foundation_establishment_pill", 1)
	gs.use_item("recipe_foundation_establishment_pill")
	assert_true(Alchemy.knows(c, gs.data, "foundation_establishment_pill"))
	assert_true(Alchemy.known_recipes(c, gs.data).has("foundation_establishment_pill"))
	gs.end_session()


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
