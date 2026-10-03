extends TestCase
## G-010: cave abodes (claim, seclusion density, storage chest, anchors).


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _cultivator(realm: String = "qi_refining") -> CharacterData:
	var c := new_character()
	c.realm_index = data().realm_index_of(realm)
	c.add_item("spirit_stone", 10000)
	return c


func test_abodes_load_with_regions_and_anchors() -> void:
	assert_true(Abodes.validate(data()).is_empty())
	assert_eq(Abodes.in_region(data(), "misty_forest"), ["waterfall_cave"] as Array[String])
	assert_eq(Abodes.get_def(data(), "waterfall_cave")["region"], "misty_forest")
	assert_true(data().anchors.has("waterfall_cave_abode"), "abode anchors are artifact anchors")


func test_claim_rules() -> void:
	var c := _cultivator("mortal")
	assert_true(Abodes.check_claim(c, data(), "waterfall_cave", "qingshi_village") != "", "wrong region")
	assert_true(Abodes.check_claim(c, data(), "waterfall_cave", "misty_forest").contains("Qi Refining"), "realm gate")
	c.realm_index = data().realm_index_of("qi_refining")
	var stones := c.item_count("spirit_stone")
	var result := Abodes.claim(c, data(), "waterfall_cave", "misty_forest")
	assert_true(result["ok"])
	assert_eq(c.abode, "waterfall_cave")
	assert_eq(c.item_count("spirit_stone"), stones - int(Abodes.get_def(data(), "waterfall_cave")["cost"]))
	assert_eq(result["anchor_id"], "waterfall_cave_abode")
	assert_false(Abodes.claim(c, data(), "waterfall_cave", "misty_forest")["ok"], "already yours")
	var poor := _cultivator()
	poor.inventory.erase("spirit_stone")
	assert_true(Abodes.check_claim(poor, data(), "waterfall_cave", "misty_forest").contains("spirit stones"))


func test_moving_needs_an_empty_chest() -> void:
	var c := _cultivator("foundation_establishment")
	assert_true(Abodes.claim(c, data(), "waterfall_cave", "misty_forest")["ok"])
	c.abode_storage = {"dew_grass": 1}
	assert_true(Abodes.check_claim(c, data(), "cloud_piercing_grotto", "azure_peak").contains("Empty"))
	c.abode_storage = {}
	var result := Abodes.claim(c, data(), "cloud_piercing_grotto", "azure_peak")
	assert_true(result["ok"])
	assert_eq(result["previous"], "waterfall_cave")


func test_seclusion_density_only_at_home() -> void:
	var c := _cultivator()
	assert_eq(Abodes.seclusion_density(c, data(), "misty_forest"), 0.0)
	Abodes.claim(c, data(), "waterfall_cave", "misty_forest")
	assert_eq(Abodes.seclusion_density(c, data(), "misty_forest"), float(Abodes.get_def(data(), "waterfall_cave")["qi_density"]))
	assert_eq(Abodes.seclusion_density(c, data(), "azure_peak"), 0.0)


func test_storage_chest() -> void:
	var c := _cultivator()
	c.add_item("dew_grass", 4)
	assert_false(Abodes.store(c, data(), "misty_forest", "dew_grass", 1)["ok"], "no abode")
	Abodes.claim(c, data(), "waterfall_cave", "misty_forest")
	assert_false(Abodes.store(c, data(), "azure_peak", "dew_grass", 1)["ok"], "not at home")
	assert_true(Abodes.store(c, data(), "misty_forest", "dew_grass", 3)["ok"])
	assert_eq(c.item_count("dew_grass"), 1)
	assert_false(Abodes.retrieve(c, data(), "azure_peak", "dew_grass", 1)["ok"], "not at home")
	assert_false(Abodes.retrieve(c, data(), "misty_forest", "dew_grass", 9)["ok"])
	assert_true(Abodes.retrieve(c, data(), "misty_forest", "dew_grass", 3)["ok"])
	assert_true(c.abode_storage.is_empty())
	for i in Abodes.storage_slots(c, data()):
		c.abode_storage["filler_%d" % i] = 1
	assert_true(Abodes.check_store(c, data(), "misty_forest", "dew_grass", 1).contains("full"))


func test_abode_round_trips_in_saves() -> void:
	var c := _cultivator()
	c.abode = "waterfall_cave"
	c.abode_storage = {"dew_grass": 2}
	var loaded := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(loaded.abode, "waterfall_cave")
	assert_eq(loaded.abode_storage, {"dew_grass": 2})
	var old := CharacterData.from_dict({"name": "Old"})
	assert_eq(old.abode, "")
	assert_true(old.abode_storage.is_empty())


func test_validation() -> void:
	var d := GameData.new()
	d.realms = data().realms
	d.abodes = {"bad": {"region": "r", "cost": -1, "qi_density": 1.0, "storage_slots": 1, "min_realm": "nowhere"}}
	assert_eq(Abodes.validate(d).size(), 2)


func test_game_state_claim_seclude_store() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Hermit", gs.data, seeded_rng())
	gs.start_session(c)
	c.realm_index = gs.data.realm_index_of("qi_refining")
	c.spiritual_roots = {"water": 70}
	c.add_item("spirit_stone", 1000)
	var clock: Node = _root().get_node("GameClock")
	var days: int = clock.total_days
	gs.cultivate_in_seclusion(30)
	assert_eq(clock.total_days, days, "no abode yet")
	gs.claim_abode("waterfall_cave")
	assert_eq(c.abode, "", "must be in the abode's region")
	gs.current_region = "misty_forest"
	gs.claim_abode("waterfall_cave")
	assert_eq(c.abode, "waterfall_cave")
	assert_true(c.anchors.has("waterfall_cave_abode"), "bound in a free anchor slot")
	var qi_before: float = c.qi + 0.0
	var stage_before := c.stage
	gs.cultivate_in_seclusion(30)
	assert_gt(clock.total_days, days, "seclusion takes time")
	assert_true(c.qi != qi_before or c.stage != stage_before, "gained qi")
	c.add_item("dew_grass", 2)
	gs.store_in_abode("dew_grass", 2)
	assert_eq(c.abode_storage.get("dew_grass", 0), 2)
	var saved: Dictionary = gs.to_save_dict()
	gs.load_save_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(gs.player.abode, "waterfall_cave")
	gs.retrieve_from_abode("dew_grass", 1)
	assert_eq(gs.player.item_count("dew_grass"), 1)
	gs.end_session()
