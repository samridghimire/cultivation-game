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
