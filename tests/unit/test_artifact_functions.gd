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


func test_progress_energy_reads_data_and_caps() -> void:
	assert_eq(ArtifactFunctions.progress_energy(data(), "stage"), 15)
	assert_eq(ArtifactFunctions.progress_energy(data(), "realm", 2), 120)
	assert_eq(ArtifactFunctions.progress_energy(data(), "nope"), 0)
	var c := new_character()
	c.artifact_energy = int(data().artifact["energy"]["max_energy"]) - 4
	assert_eq(ArtifactFunctions.grant_progress(c, data(), "realm"), 4, "capped at max_energy")


func test_first_win_counts_once_per_enemy() -> void:
	var c := new_character()
	assert_eq(ArtifactFunctions.drink_first_win(c, data(), "wild_boar"), 5)
	assert_eq(ArtifactFunctions.drink_first_win(c, data(), "wild_boar"), 0)
	assert_eq(ArtifactFunctions.drink_first_win(c, data(), "wolf"), 5)
	var loaded := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_true(loaded.artifact_won.has("wild_boar"))
	assert_eq(ArtifactFunctions.drink_first_win(loaded, data(), "wild_boar"), 0)


func test_drink_progress_reads_marks() -> void:
	var c := new_character()
	assert_eq(ArtifactFunctions.drink_progress(c, data()), 0, "first call only records")
	c.stage += 2
	assert_eq(ArtifactFunctions.drink_progress(c, data()), 30)
	assert_eq(ArtifactFunctions.drink_progress(c, data()), 0)
	c.realm_index += 1
	c.stage = 0
	LifeStats.add(c, "discoveries")
	LifeStats.add(c, "realm_floors_cleared")
	assert_eq(ArtifactFunctions.drink_progress(c, data()), 60 + 5 + 10)


func test_ready_to_unseal_needs_energy_and_realm() -> void:
	var c := _qi_refiner()
	c.artifact_energy = _unlock_cost() - 1
	assert_true(ArtifactFunctions.ready_to_unseal(c, data(), {}).is_empty())
	c.artifact_energy = _unlock_cost()
	assert_eq(ArtifactFunctions.ready_to_unseal(c, data(), {}), ["storage"] as Array[String])
	var mortal := new_character()
	mortal.artifact_energy = _unlock_cost()
	assert_true(ArtifactFunctions.ready_to_unseal(mortal, data(), {}).is_empty())
	var marks := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(marks.artifact_marks, c.artifact_marks)


func test_progress_validation() -> void:
	var d := GameData.new()
	d.realms = data().realms
	d.artifact = {"energy": {"progress": {"stage": -1, "bogus": 3}}}
	d._validate_artifact()
	var text := "\n".join(d.load_errors)
	assert_true(text.contains("'stage' must be"), text)
	assert_true(text.contains("unknown key 'bogus'"), text)


## WU-524: status() gives each power's card state and the short "need" phrase.
func test_status_states_and_needs() -> void:
	var d := data()
	var c := new_character()
	c.artifact_energy = 0
	var s := ArtifactFunctions.status(c, d, "storage", {})
	assert_eq(s["state"], "sealed")
	assert_eq(s["need"], "reach %s" % d.realms[d.realm_index_of("qi_refining")].name)
	c.realm_index = d.realm_index_of("qi_refining")
	s = ArtifactFunctions.status(c, d, "storage", {})
	assert_eq(s["need"], "%d energy (you have 0)" % _unlock_cost())
	assert_eq(s["cost"], _unlock_cost())
	c.artifact_energy = _unlock_cost()
	s = ArtifactFunctions.status(c, d, "storage", {})
	assert_eq(s["state"], "ready")
	assert_eq(s["need"], "")
	ArtifactFunctions.unlock(c, d, "storage", {})
	assert_eq(ArtifactFunctions.status(c, d, "storage", {})["state"], "open")
	c.realm_index = d.realm_index_of("foundation_establishment")
	s = ArtifactFunctions.status(c, d, "spirit_garden", {})
	assert_eq(s["need"], "unseal Inner World first")


func test_artifact_taste_tag_multipliers() -> void:  # ART-013
	var d := data()
	var per_price := float(d.artifact["energy"]["item_energy_per_price"])
	assert_eq(ArtifactFunctions.energy_value(d, "eagle_talon"), floori(60 * per_price * 2.0), "beast material 2x")
	assert_eq(ArtifactFunctions.energy_value(d, "paper_moon_crown"), 0, "keepsake")
	var c := new_character()
	c.add_item("paper_moon_crown", 1)
	assert_eq(ArtifactFunctions.check_feed(c, d, "paper_moon_crown", 1), "The artifact will not take this.")
	assert_false(ArtifactFunctions.feed(c, d, "paper_moon_crown", 1)["ok"])
	assert_eq(c.item_count("paper_moon_crown"), 1)


func test_feed_choices_sorted_and_filtered() -> void:  # ART-013
	var d := data()
	var c := new_character()
	c.inventory = {"boar_hide": 3, "eagle_talon": 1, "paper_moon_crown": 1, "qi_gathering_pill": 2, "spirit_stone": 9}
	var picks := ArtifactFunctions.feed_choices(c, d)
	var ids: Array = picks.map(func(p: Dictionary) -> String: return String(p["id"]))
	assert_false(ids.has("paper_moon_crown"))
	assert_false(ids.has("spirit_stone"))
	assert_eq(ids[0], "eagle_talon")
	for i in range(1, picks.size()):
		assert_true(int(picks[i - 1]["energy_each"]) >= int(picks[i]["energy_each"]))
	var boar: Dictionary = picks[ids.find("boar_hide")]
	assert_eq(int(boar["count"]), 3)
	assert_eq(int(boar["sell_each"]), 4)


func test_tag_mult_validation() -> void:  # ART-013
	var d := data()
	var saved: Dictionary = d.artifact["energy"]["tag_mult"]
	d.artifact["energy"]["tag_mult"] = {"beast_material": -1.0}
	assert_true(ArtifactFunctions.validate(d).size() > 0, "negative")
	d.artifact["energy"]["tag_mult"] = {"no_such_tag": 1.0}
	assert_true(ArtifactFunctions.validate(d).size() > 0, "unused tag")
	d.artifact["energy"]["tag_mult"] = saved
	assert_eq(ArtifactFunctions.validate(d).size(), 0)
