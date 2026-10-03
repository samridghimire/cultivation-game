extends TestCase
## ART-002: artifact energy, function unlocking and the Storage Space.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _unlock_cost() -> int:
	return int(ArtifactFunctions.get_def(data(), "storage")["unlock"]["energy"])


func _qi_refiner() -> CharacterData:
	var c := new_character()
	c.realm_index = data().realm_index_of("qi_refining")
	return c


func test_feeding_converts_items_to_energy() -> void:
	var c := new_character()
	var stones := c.item_count("spirit_stone")
	c.add_item("spirit_stone", 50)
	var result := ArtifactFunctions.feed(c, data(), "spirit_stone", 50)
	assert_true(result["ok"])
	assert_eq(c.artifact_energy, 50 * int(data().artifact["energy"]["stone_energy"]))
	assert_eq(c.item_count("spirit_stone"), stones)
	c.add_item("qi_gathering_pill", 2)
	assert_eq(ArtifactFunctions.energy_value(data(), "qi_gathering_pill"), floori(15 * float(data().artifact["energy"]["item_energy_per_price"])))
	assert_true(ArtifactFunctions.feed(c, data(), "qi_gathering_pill", 2)["ok"])
	assert_eq(c.item_count("qi_gathering_pill"), 0)


func test_feeding_refusals_and_cap() -> void:
	var c := new_character()
	assert_false(ArtifactFunctions.feed(c, data(), "core_forming_pill", 1)["ok"], "not carried")
	c.add_item("ancient_jade_slip", 1)
	assert_false(ArtifactFunctions.feed(c, data(), "ancient_jade_slip", 1)["ok"], "worthless")
	assert_eq(c.item_count("ancient_jade_slip"), 1)
	var cap := int(data().artifact["energy"]["max_energy"])
	c.artifact_energy = cap - 5
	c.add_item("spirit_stone", 100)
	assert_eq(ArtifactFunctions.feed(c, data(), "spirit_stone", 100)["energy"], 5, "capped")
	assert_eq(c.artifact_energy, cap)
	assert_false(ArtifactFunctions.feed(c, data(), "spirit_stone", 1)["ok"], "sated")


func test_unlock_needs_realm_energy_and_flags() -> void:
	var c := new_character()
	c.artifact_energy = _unlock_cost()
	assert_true(ArtifactFunctions.check_unlock(c, data(), "storage", {}).contains("Qi Refining"), "realm gate")
	c.realm_index = data().realm_index_of("qi_refining")
	c.artifact_energy = _unlock_cost() - 1
	assert_true(ArtifactFunctions.check_unlock(c, data(), "storage", {}).contains("energy"))
	c.artifact_energy = _unlock_cost() + 7
	assert_true(ArtifactFunctions.unlock(c, data(), "storage", {})["ok"])
	assert_eq(c.artifact_energy, 7, "energy spent")
	assert_true(ArtifactFunctions.is_unlocked(c, "storage"))
	assert_false(ArtifactFunctions.unlock(c, data(), "storage", {})["ok"], "already unsealed")
	assert_false(ArtifactFunctions.unlock(c, data(), "nonexistent", {})["ok"])
	var d := GameData.new()
	d.realms = data().realms
	d.artifact = {"functions": [{"id": "storage", "unlock": {"flag": "found_key"}, "storage_slots": 1}]}
	var other := new_character()
	assert_true(ArtifactFunctions.check_unlock(other, d, "storage", {}) != "", "flag missing")
	assert_eq(ArtifactFunctions.check_unlock(other, d, "storage", {"found_key": true}), "")


func test_storage_moves_items_with_slot_limit() -> void:
	var c := _qi_refiner()
	c.add_item("dew_grass", 5)
	assert_false(ArtifactFunctions.store(c, data(), "dew_grass", 1)["ok"], "sealed")
	c.artifact_functions.append("storage")
	assert_true(ArtifactFunctions.store(c, data(), "dew_grass", 3)["ok"])
	assert_eq(c.item_count("dew_grass"), 2)
	assert_eq(c.artifact_storage["dew_grass"], 3)
	assert_false(ArtifactFunctions.store(c, data(), "dew_grass", 9)["ok"], "not enough carried")
	assert_false(ArtifactFunctions.retrieve(c, "dew_grass", 4)["ok"], "not enough stored")
	assert_true(ArtifactFunctions.retrieve(c, "dew_grass", 3)["ok"])
	assert_false(c.artifact_storage.has("dew_grass"), "empty stacks are removed")
	assert_eq(c.item_count("dew_grass"), 5)
	var slots := ArtifactFunctions.storage_slots(c, data())
	for i in slots:
		c.artifact_storage["filler_%d" % i] = 1
	assert_true(ArtifactFunctions.check_store(c, data(), "dew_grass", 1).contains("full"))
	c.artifact_storage.erase("filler_0")
	c.artifact_storage["dew_grass"] = 1
	assert_true(ArtifactFunctions.store(c, data(), "dew_grass", 1)["ok"], "existing stacks still grow")


func test_artifact_state_round_trips_in_saves() -> void:
	var c := _qi_refiner()
	c.artifact_energy = 42
	c.artifact_functions.append("storage")
	c.artifact_storage = {"dew_grass": 3}
	var loaded := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(loaded.artifact_energy, 42)
	assert_eq(loaded.artifact_functions, ["storage"] as Array[String])
	assert_eq(loaded.artifact_storage, {"dew_grass": 3})
	var old := CharacterData.from_dict({"name": "Old"})
	assert_eq(old.artifact_energy, 0, "old saves default")
	assert_true(old.artifact_functions.is_empty() and old.artifact_storage.is_empty())


func test_validation() -> void:
	assert_true(ArtifactFunctions.validate(data()).is_empty())
	var d := GameData.new()
	d.realms = data().realms
	d.artifact = {"energy": {"stone_energy": 1, "max_energy": 10, "item_energy_per_price": 0.5}, "functions": [
		{"id": "storage", "unlock": {"realm": "nowhere"}},
		{"id": "storage"},
		{"id": "teleport"},
	]}
	assert_eq(ArtifactFunctions.validate(d).size(), 5, "bad realm, two missing storage_slots, duplicate, unknown function")


func test_describe_lists_functions_and_storage() -> void:
	var c := _qi_refiner()
	var lines := ArtifactFunctions.describe(c, data(), {})
	assert_true(lines[1].contains("sealed"))
	c.artifact_functions.append("storage")
	c.artifact_storage = {"dew_grass": 2}
	lines = ArtifactFunctions.describe(c, data(), {})
	assert_true(lines[1].contains("unsealed"))
	assert_true(lines[-1].contains("x2"))


func test_game_state_feed_unlock_store_and_keep_through_death() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Bearer", gs.data, seeded_rng())
	gs.start_session(c)
	c.realm_index = gs.data.realm_index_of("qi_refining")
	c.add_item("spirit_stone", _unlock_cost())
	gs.unlock_artifact_function("storage")
	assert_false(ArtifactFunctions.is_unlocked(c, "storage"), "no energy yet")
	gs.feed_artifact("spirit_stone", _unlock_cost())
	assert_eq(c.artifact_energy, _unlock_cost())
	gs.unlock_artifact_function("storage")
	assert_true(ArtifactFunctions.is_unlocked(c, "storage"))
	c.add_item("qi_gathering_pill", 3)
	gs.store_in_artifact("qi_gathering_pill", 3)
	assert_eq(c.item_count("qi_gathering_pill"), 0)
	gs._die_violently("A test bandit strikes you down.")
	assert_true(c.alive, "respawned")
	assert_eq(c.artifact_storage.get("qi_gathering_pill", 0), 3, "storage survives death")
	var saved: Dictionary = gs.to_save_dict()
	gs.load_save_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(gs.player.artifact_storage.get("qi_gathering_pill", 0), 3)
	gs.retrieve_from_artifact("qi_gathering_pill", 2)
	assert_eq(gs.player.item_count("qi_gathering_pill"), 2)
	gs.end_session()
