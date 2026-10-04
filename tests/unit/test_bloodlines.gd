extends TestCase
## FAM-007: bloodlines (data/bloodlines.json, Bloodlines).


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _person(gender: String, id: String, bloodline: String = "") -> CharacterData:
	var c := new_character()
	c.id = id
	c.name = id
	c.gender = gender
	c.bloodline = bloodline
	return c


func test_data_has_valid_bloodlines() -> void:
	assert_eq(Bloodlines.validate(data()).size(), 0)
	assert_gt(data().bloodlines.size(), 3)


func test_bloodline_awakens_at_its_realm_and_only_then_grants_bonuses() -> void:
	var c := _person("male", "player", "azure_dragon")
	c.realm_index = 1
	var qi_before := Cultivation.qi_per_day(c, data())
	var attack_before := int(Combat.stats(c, data())["attack"])
	assert_false(Bloodlines.update(c, data()), "dormant below Foundation")
	assert_eq(Bloodlines.bonus(c, data(), "qi_mult"), 0.0)
	assert_true(Bloodlines.describe(c, data()).contains("dormant"))
	c.realm_index = data().realm_index_of("foundation_establishment")
	assert_true(Bloodlines.update(c, data()))
	assert_false(Bloodlines.update(c, data()), "awakens once")
	assert_true(Bloodlines.describe(c, data()).contains("awakened"))
	c.realm_index = 1
	assert_almost_eq(Cultivation.qi_per_day(c, data()), qi_before * 1.15)
	assert_gt(int(Combat.stats(c, data())["attack"]), attack_before)


func test_breakthrough_bonus() -> void:
	var c := _person("female", "player", "vermilion_phoenix")
	c.realm_index = 1
	var before := Cultivation.breakthrough_chance(c, data())
	c.bloodline_awakened = true
	assert_almost_eq(Cultivation.breakthrough_chance(c, data()), minf(0.99, before + 0.08))


func test_inheritance_odds() -> void:
	var rng := seeded_rng(11)
	var counts := {"one": 0, "both": 0, "none": 0}
	for i in 1000:
		if Bloodlines.inherit(_person("female", "m", "white_tiger"), _person("male", "f"), data(), rng) == "white_tiger":
			counts["one"] += 1
		if Bloodlines.inherit(_person("female", "m", "white_tiger"), _person("male", "f", "white_tiger"), data(), rng) == "white_tiger":
			counts["both"] += 1
		if Bloodlines.inherit(_person("female", "m"), _person("male", "f"), data(), rng) != "":
			counts["none"] += 1
	assert_true(counts["one"] > 400 and counts["one"] < 600, "about half: %d" % counts["one"])
	assert_gt(counts["both"], 850)
	assert_true(counts["none"] < 40, "spontaneous bloodlines are rare: %d" % counts["none"])


func test_mixed_bloodlines_pass_one_or_the_other() -> void:
	var rng := seeded_rng(3)
	var seen := {}
	for i in 200:
		seen[Bloodlines.inherit(_person("female", "m", "white_tiger"), _person("male", "f", "black_tortoise"), data(), rng)] = true
	assert_true(seen.has("white_tiger") and seen.has("black_tortoise"))


func test_birth_passes_bloodline_and_save_keeps_it() -> void:
	var mother := _person("female", "gen_m", "black_tortoise")
	var father := _person("male", "player", "black_tortoise")
	Family.marry(father, mother, "wife")
	var npcs := {}
	var found := false
	for i in 20:
		mother.pregnancy = {"partner": "player", "days_left": 0}
		var child := Children.give_birth(mother, father, npcs, data(), seeded_rng(i), "")
		if child.bloodline == "black_tortoise":
			found = true
			child.bloodline_awakened = true
			var copy := CharacterData.from_dict(JSON.parse_string(JSON.stringify(child.to_dict())))
			assert_eq(copy.bloodline, "black_tortoise")
			assert_true(copy.bloodline_awakened)
			break
	assert_true(found, "a child of two carriers inherits within 20 births")
	assert_eq(CharacterData.from_dict({}).bloodline, "", "old saves have no bloodline")


func test_npcs_awaken_when_they_break_through() -> void:
	var npcs := {}
	var c := Npcs.spawn(npcs, data(), seeded_rng(), {"realm": "mortal", "roots": {"fire": 90}, "age_years": 20, "diligence": 1.0})
	c.bloodline = "white_tiger"
	var awakened := false
	for month in 240:
		for event in Npcs.simulate(npcs, data(), Calendar.DAYS_PER_MONTH, seeded_rng(month)):
			if String(event["text"]).contains("White Tiger"):
				awakened = true
		if awakened:
			break
	assert_true(awakened, "awakening reported")
	assert_true(c.bloodline_awakened)


func test_game_state_breakthrough_awakens_player_bloodline() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male")
	gs.start_session(c)
	c.bloodline = "white_tiger"
	for i in 50:
		if c.realm_index > 0:
			break
		c.qi = 0.0
		Cultivation.add_qi(c, gs.data, 1.0e9)
		c.breakthrough_bonus = 1.0
		gs.attempt_breakthrough()
	assert_eq(c.realm_index, 1)
	assert_true(c.bloodline_awakened)
	gs.end_session()
