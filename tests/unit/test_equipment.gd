extends TestCase
## G-004: equipment (weapons/armor) and blacksmith forging.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func test_equip_moves_item_and_adds_flat_stats() -> void:
	var c := new_character()
	var before := Combat.stats(c, data())
	c.add_item("iron_sword", 1)
	assert_eq(Equipment.equip(c, data(), "iron_sword"), "")
	assert_eq(c.item_count("iron_sword"), 0)
	assert_eq(c.equipment["weapon"], "iron_sword")
	var after := Combat.stats(c, data())
	assert_eq(after["attack"], before["attack"] + 6)
	assert_eq(after["defense"], before["defense"])


func test_equip_swaps_and_unequip_returns_item() -> void:
	var c := new_character()
	c.add_item("iron_sword", 1)
	c.add_item("cold_iron_saber", 1)
	Equipment.equip(c, data(), "iron_sword")
	assert_eq(Equipment.equip(c, data(), "cold_iron_saber"), "iron_sword")
	assert_eq(c.item_count("iron_sword"), 1)
	assert_eq(Equipment.bonus(c, data(), "attack"), 15)
	assert_eq(Equipment.bonus(c, data(), "speed"), 1)
	assert_eq(Equipment.unequip(c, "weapon"), "cold_iron_saber")
	assert_eq(c.item_count("cold_iron_saber"), 1)
	assert_eq(Equipment.unequip(c, "weapon"), "")
	assert_eq(Equipment.bonus(c, data(), "attack"), 0)


func test_cannot_equip_non_equipment_or_missing() -> void:
	var c := new_character()
	assert_true(Equipment.check_equip(c, data(), "spirit_stone") != "")
	assert_true(Equipment.check_equip(c, data(), "iron_sword") != "", "none in the pack")
	assert_eq(Equipment.equip(c, data(), "iron_sword"), "")
	assert_true(c.equipment.is_empty())


func test_weapon_and_armor_stack() -> void:
	var c := new_character()
	var before := Combat.stats(c, data())
	c.add_item("iron_sword", 1)
	c.add_item("iron_scale_armor", 1)
	Equipment.equip(c, data(), "iron_sword")
	Equipment.equip(c, data(), "iron_scale_armor")
	var after := Combat.stats(c, data())
	assert_eq(after["defense"], before["defense"] + 4)
	assert_eq(after["max_hp"], before["max_hp"] + 20)
	assert_eq(after["attack"], before["attack"] + 6)


func test_equipment_round_trips_in_saves() -> void:
	var c := new_character()
	c.add_item("iron_scale_armor", 1)
	Equipment.equip(c, data(), "iron_scale_armor")
	var back := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.equipment, {"armor": "iron_scale_armor"})
	assert_true(CharacterData.from_dict({}).equipment.is_empty(), "old saves have nothing equipped")


func test_equipment_data_is_valid() -> void:
	for item: Dictionary in data().items.values():
		if item.has("equip"):
			assert_true(Equipment.SLOTS.has(item["equip"]["slot"]), item["id"])
	assert_eq(Equipment.describe_stats(data(), "cold_iron_saber"), "+15 attack, +1 speed")


func test_forging_uses_constitution() -> void:
	var c := new_character()
	c.attributes["constitution"] = 10
	c.attributes["comprehension"] = 15
	var base := Alchemy.success_chance(c, data(), "iron_scale_armor")
	c.attributes["constitution"] = 15
	assert_almost_eq(Alchemy.success_chance(c, data(), "iron_scale_armor"), base + 0.1)
	assert_true(Alchemy.known_recipes(c, data(), "blacksmith").has("iron_sword"))
	assert_false(Alchemy.known_recipes(c, data(), "alchemist").has("iron_sword"))


func test_forge_produces_equipment() -> void:
	var c := new_character()
	c.attributes["constitution"] = 15
	c.add_item("iron_essence", 3)
	var result := Alchemy.refine(c, data(), "iron_sword", seeded_rng())
	assert_true(result["ok"])
	assert_eq(c.item_count("iron_essence"), 0)
	if result["success"]:
		assert_eq(c.item_count("iron_sword"), 1)
	else:
		assert_eq(c.item_count("iron_sword"), 0)
	assert_gt(result["xp"], 0.0, "forging trains the Blacksmith profession either way")


func test_game_state_equip_and_use_item() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Smith", gs.data, seeded_rng())
	gs.start_session(c)
	c.add_item("iron_sword", 1)
	c.add_item("iron_scale_armor", 1)
	var clock: Node = _root().get_node("GameClock")
	var days: int = clock.total_days
	gs.use_item("iron_sword")
	gs.equip_item("iron_scale_armor")
	assert_eq(c.equipment, {"weapon": "iron_sword", "armor": "iron_scale_armor"})
	assert_eq(clock.total_days, days, "equipping takes no time")
	gs.unequip("weapon")
	assert_eq(c.item_count("iron_sword"), 1)
	assert_false(c.equipment.has("weapon"))
	c.add_item("iron_essence", 3)
	gs.refine("iron_sword")
	assert_eq(c.item_count("iron_essence"), 0)
	assert_gt(clock.total_days, days, "forging takes time")
	gs.end_session()


func test_evil_weapon_drains_lifespan_per_fight() -> void:
	var c := new_character()
	assert_eq(Equipment.drain_after_fight(c, data()), 0, "ordinary fighters lose nothing")
	assert_eq(c.lifespan_spent_years, 0)
	c.add_item("blood_drinker_saber", 1)
	Equipment.equip(c, data(), "blood_drinker_saber")
	assert_eq(Equipment.lifespan_drain(c, data()), 1)
	var before := Cultivation.lifespan_years(c, data())
	assert_eq(Equipment.drain_after_fight(c, data()), 1)
	assert_eq(Cultivation.lifespan_years(c, data()), before - 1)
	assert_true(Equipment.describe_stats(data(), "blood_drinker_saber").contains("drinks 1 year of lifespan per fight"))
	Equipment.unequip(c, "weapon")
	assert_eq(Equipment.lifespan_drain(c, data()), 0, "sheathed, it drinks nothing")


func test_negative_lifespan_drain_is_invalid() -> void:
	var d := GameData.new()
	d.items = {"bad": {"id": "bad", "equip": {"slot": "weapon", "grade": 1, "stats": {}, "lifespan_drain": -2}}}
	assert_eq(Equipment.validate(d).size(), 1)


func test_game_state_fight_with_evil_weapon_burns_lifespan() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Wielder", gs.data, seeded_rng())
	gs.start_session(c)
	c.add_item("blood_drinker_saber", 1)
	gs.equip_item("blood_drinker_saber")
	gs.fight("wild_boar")
	assert_eq(c.lifespan_spent_years, 1)
	assert_true(c.alive)
	# With only a year left, the saber drinks the last of it: final death, no respawn.
	c.lifespan_spent_years += Cultivation.years_left(c, gs.data) - 1
	var lives: int = c.artifact_lives
	gs.fight("wild_boar")
	assert_false(c.alive, "old age is never undone by the artifact")
	assert_true(c.cause_of_death.contains("weapon"))
	assert_eq(c.artifact_lives, lives)
	gs.end_session()


func test_every_learned_forging_recipe_has_an_obtainable_manual() -> void:
	var d := data()
	for recipe: Dictionary in d.recipes.values():
		if recipe.get("profession", "") != "blacksmith" or recipe.get("starter", false):
			continue
		var obtainable := false
		for item: Dictionary in d.items.values():
			if item.get("effects", {}).get("learn_recipe", "") != recipe["id"]:
				continue
			if int(item.get("price", 0)) > 0:
				obtainable = true
			for e: Dictionary in d.encounters.values():
				for effects: Dictionary in encounter_outcomes(e):
					if effects.get("items", {}).has(item["id"]):
						obtainable = true
		assert_true(obtainable, "no manual for the %s recipe can be bought or found" % recipe["id"])


func test_every_evil_artifact_is_found_in_an_encounter_with_a_righteous_alternative() -> void:
	var d := data()
	for item: Dictionary in d.items.values():
		if Equipment.item_drain(d, item["id"]) <= 0:
			continue
		# The outcome (encounter or choice effects) that grants it, and its encounter.
		var taker: Dictionary = {}
		var source: Dictionary = {}
		for e: Dictionary in d.encounters.values():
			for effects: Dictionary in encounter_outcomes(e):
				if effects.get("items", {}).has(item["id"]):
					taker = effects
					source = e
		assert_false(taker.is_empty(), "%s has no encounter that grants it" % item["id"])
		if taker.is_empty():
			continue
		assert_true(int(taker.get("alignment", 0)) < 0, "taking %s is a demonic act" % item["id"])
		var flag: String = source.get("blocked_by_flag", "")
		assert_true(flag != "", "%s is found once per life" % item["id"])
		var has_alternative := false
		for e: Dictionary in d.encounters.values():
			if e.get("blocked_by_flag", "") != flag:
				continue
			for effects: Dictionary in encounter_outcomes(e):
				if effects != taker and int(effects.get("alignment", 0)) > 0:
					has_alternative = true
		assert_true(has_alternative, "%s needs a righteous way to destroy it" % item["id"])


func test_binding_an_evil_artifact_costs_alignment_once() -> void:
	var c := new_character()
	c.add_item("blood_drinker_saber", 1)
	assert_eq(Equipment.first_equip_alignment(data(), "blood_drinker_saber"), -120)
	assert_eq(Equipment.first_equip_alignment(data(), "iron_sword"), 0)
	assert_false(Equipment.is_bound(c, "blood_drinker_saber"))
	Equipment.equip(c, data(), "blood_drinker_saber")
	assert_eq(Equipment.bind_artifact(c, data(), "blood_drinker_saber"), -120)
	assert_eq(c.alignment, -120)
	assert_true(Equipment.is_bound(c, "blood_drinker_saber"))
	Equipment.unequip(c, "weapon")
	Equipment.equip(c, data(), "blood_drinker_saber")
	assert_eq(Equipment.bind_artifact(c, data(), "blood_drinker_saber"), 0, "bound only once")
	assert_eq(c.alignment, -120)
	assert_eq(Equipment.bind_artifact(c, data(), "iron_sword"), 0, "ordinary gear is free")


func test_binding_is_clamped_to_the_alignment_range() -> void:
	var c := new_character()
	c.alignment = data().alignment_min
	assert_eq(Equipment.bind_artifact(c, data(), "myriad_souls_banner"), 0, "already as demonic as it gets")
	assert_eq(c.alignment, data().alignment_min)
	assert_true(Equipment.is_bound(c, "myriad_souls_banner"), "the pact is still sealed")


func test_every_evil_artifact_costs_alignment_to_bind() -> void:
	var d := data()
	for item: Dictionary in d.items.values():
		if Equipment.item_drain(d, item["id"]) > 0:
			assert_true(Equipment.first_equip_alignment(d, item["id"]) < 0, "%s should stain its wielder when bound" % item["id"])
	assert_true(Equipment.describe_stats(d, "blood_drinker_saber").contains("alignment to bind"))
	var bad := GameData.new()
	bad.items = {"cursed": {"id": "cursed", "equip": {"slot": "weapon", "grade": 1, "alignment_on_first_equip": -9000}}}
	assert_eq(Equipment.validate(bad).size(), 1)


func test_bound_artifacts_round_trip_in_saves() -> void:
	var c := new_character()
	c.bound_artifacts.append("blood_drinker_saber")
	var loaded := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(loaded.bound_artifacts, ["blood_drinker_saber"] as Array[String])
	assert_true(CharacterData.from_dict({"name": "Old"}).bound_artifacts.is_empty())


func test_game_state_equipping_an_evil_artifact_stains_you() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Blade Fiend", gs.data, seeded_rng())
	gs.start_session(c)
	c.add_item("corpse_silk_burial_armor", 1)
	gs.equip_item("corpse_silk_burial_armor")
	assert_eq(c.equipment.get("armor", ""), "corpse_silk_burial_armor")
	assert_eq(c.alignment, -120)
	gs.unequip("armor")
	gs.equip_item("corpse_silk_burial_armor")
	assert_eq(c.alignment, -120, "re-equipping the same artifact is free")
	var saved: Dictionary = gs.to_save_dict()
	gs.load_save_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_true(gs.player.bound_artifacts.has("corpse_silk_burial_armor"))
	gs.end_session()
