extends TestCase
## Talismans (G-005): Talisman Masters inscribe single-use talismans from
## recipes, and the `buff` effect grants a temporary combat buff when used.


func _game_state() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func test_buff_effect_adds_combat_buff() -> void:
	var c := new_character()
	var before := Combat.stats(c, data())
	var notes := Effects.apply(c, data(), data().items["golden_bell_talisman"]["effects"], {})
	assert_true(c.buffs.has("golden_bell"))
	assert_eq(int(c.buffs["golden_bell"]["days"]), 7)
	assert_eq(Combat.stats(c, data())["defense"], roundi(before["defense"] * 1.4))
	assert_eq(notes.size(), 1)
	assert_true(notes[0].begins_with("Golden Bell: +40% defense"), notes[0])


func test_using_talisman_twice_refreshes_buff() -> void:
	var c := new_character()
	c.add_item("swift_wind_talisman", 2)
	assert_true(Items.use(c, data(), "swift_wind_talisman", {})["ok"])
	Buffs.pass_days(c, 5)
	assert_true(Items.use(c, data(), "swift_wind_talisman", {})["ok"])
	assert_eq(int(c.buffs["swift_wind"]["days"]), 7)
	assert_almost_eq(Buffs.multiplier(c, "speed"), 1.4)
	assert_eq(c.item_count("swift_wind_talisman"), 0)


func test_validate_buff_effect() -> void:
	assert_eq(Buffs.validate_effect({"id": "a", "name": "A", "days": 3, "mults": {"attack": 0.2}}).size(), 0)
	assert_gt(Buffs.validate_effect({"id": "a", "name": "A", "days": 0, "mults": {"attack": 0.2}}).size(), 0)
	assert_gt(Buffs.validate_effect({"id": "a", "name": "A", "days": 3, "mults": {"luck": 0.2}}).size(), 0)
	assert_gt(Buffs.validate_effect({"name": "A", "days": 3, "mults": {"attack": 0.2}}).size(), 0)
	assert_gt(Buffs.validate_effect("golden_bell").size(), 0)


func test_every_talisman_item_has_a_recipe() -> void:
	var outputs := {}
	for recipe: Dictionary in data().recipes.values():
		if recipe["profession"] == "talisman_master":
			outputs[recipe["output"]["item"]] = true
	for item: Dictionary in data().items.values():
		if item.get("tags", []).has("talisman"):
			assert_true(outputs.has(item["id"]), item["id"])
			# Combat talismans (G-005b) are readied for fights instead of used.
			assert_true(item.get("usable", false) or item.has("combat"), item["id"])


func test_starter_talisman_recipes_are_known_by_talisman_masters() -> void:
	var c := new_character()
	var known := Alchemy.known_recipes(c, data(), "talisman_master")
	assert_true(known.has("golden_bell_talisman"))
	assert_true(known.has("swift_wind_talisman"))


func test_inscribing_uses_spirit_for_success_chance() -> void:
	var c := new_character()
	c.attributes["spirit"] = 10
	var base := Alchemy.success_chance(c, data(), "golden_bell_talisman")
	c.attributes["spirit"] = 15
	assert_gt(Alchemy.success_chance(c, data(), "golden_bell_talisman"), base)


func test_game_state_inscribe_and_use_talisman() -> void:
	var gs := _game_state()
	var c := CharacterFactory.create("Inscriber", gs.data, seeded_rng(77))
	c.attributes["spirit"] = 15
	gs.start_session(c)
	c.add_item("talisman_paper", 10)
	c.add_item("iron_essence", 10)
	for i in 10:
		gs.refine("golden_bell_talisman")
	assert_eq(c.item_count("talisman_paper"), 0)
	assert_gt(c.item_count("golden_bell_talisman"), 0)
	assert_gt(Professions.xp_of(c, "talisman_master") + Professions.rank_of(c, "talisman_master"), 0.0)
	gs.use_item("golden_bell_talisman")
	assert_true(c.buffs.has("golden_bell"))
	gs.end_session()


func test_every_learned_talisman_recipe_has_an_obtainable_manual() -> void:
	var d := data()
	for recipe: Dictionary in d.recipes.values():
		if recipe["profession"] != "talisman_master" or recipe.get("starter", false):
			continue
		var obtainable := false
		for item: Dictionary in d.items.values():
			if item.get("effects", {}).get("learn_recipe", "") != recipe["id"]:
				continue
			if int(item.get("price", 0)) > 0:
				obtainable = true
			for e: Dictionary in d.encounters.values():
				if e.get("effects", {}).get("items", {}).has(item["id"]):
					obtainable = true
		assert_true(obtainable, "no manual for the %s recipe can be bought or found" % recipe["id"])
