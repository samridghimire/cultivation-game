extends TestCase
## ART-004: the spirit garden in the inner world.


func _gardener() -> CharacterData:
	var c := new_character()
	c.realm_index = data().realm_index_of("foundation_establishment")
	c.inventory = {"flame_lotus": 2, "spirit_herb": 6}
	return c


func test_real_def_is_valid_and_needs_the_inner_world() -> void:
	assert_eq(SpiritGarden.validate(data()).size(), 0)
	var c := _gardener()
	c.artifact_energy = 100000
	assert_true(ArtifactFunctions.check_unlock(c, data(), SpiritGarden.FUNCTION, {}).contains("must be unsealed first"))
	c.artifact_functions.append(InnerWorld.FUNCTION)
	assert_eq(ArtifactFunctions.check_unlock(c, data(), SpiritGarden.FUNCTION, {}), "")


func test_plant_grow_and_harvest() -> void:
	var c := _gardener()
	assert_true(SpiritGarden.check_plant(c, data(), "flame_lotus").contains("sealed"))
	c.artifact_functions.append(SpiritGarden.FUNCTION)
	assert_true(SpiritGarden.plant(c, data(), "flame_lotus")["ok"])
	assert_eq(c.item_count("flame_lotus"), 1)
	assert_true(SpiritGarden.check_plant(c, data(), "iron_essence") != "", "ores do not grow")
	var days := int(SpiritGarden.plant_def(data(), "flame_lotus")["days"])
	var world_days := ceili(float(days) / InnerWorld.inner_days(data(), 1))
	assert_true(SpiritGarden.advance(c, data(), world_days - 1).is_empty())
	assert_true(SpiritGarden.harvest(c, data(), seeded_rng()).is_empty(), "not ready yet")
	assert_eq(SpiritGarden.advance(c, data(), 1), ["flame_lotus"] as Array[String])
	var gained := SpiritGarden.harvest(c, data(), seeded_rng())
	assert_true(int(gained["flame_lotus"]) >= 2)
	assert_true(c.garden.is_empty())
	for i in SpiritGarden.plots(data()):
		SpiritGarden.plant(c, data(), "spirit_herb")
	assert_true(SpiritGarden.check_plant(c, data(), "spirit_herb").contains("Every plot"))
	var back := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.garden.size(), SpiritGarden.plots(data()), "saved")
	assert_true(CharacterData.from_dict({}).garden.is_empty())


func test_game_state_and_screen() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var c := _gardener()
	gs.start_session(c)
	c.realm_index = gs.data.realm_index_of("foundation_establishment")
	c.inventory = {"spirit_herb": 3}
	c.artifact_functions.append_array([InnerWorld.FUNCTION, SpiritGarden.FUNCTION])
	var screen := ArtifactScreen.new()
	screen.open()
	screen._show_page(ArtifactScreen.PAGE_GARDEN)
	var plant := screen.buttons().filter(func(b: Button) -> bool: return b.name == "plant_spirit_herb")
	assert_eq(plant.size(), 1)
	(plant[0] as Button).pressed.emit()
	assert_eq(c.garden.size(), 1)
	gs.cultivate(60)
	assert_eq(int(c.garden[0]["days_left"]), 0, "grown while time passed")
	var herbs := c.item_count("spirit_herb")
	gs.harvest_garden()
	assert_gt(c.item_count("spirit_herb"), herbs)
	screen.free()
	gs.end_session()
