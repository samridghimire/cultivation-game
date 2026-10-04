extends TestCase
## FAM-004: training descendants (data/family.json "training", Training).


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


## A parent and their child (age `age`) in a people dictionary.
func _family(age: int = 12) -> Dictionary:
	var parent := new_character()
	parent.inventory = {"spirit_stone": 100}
	var child := new_character(99)
	child.id = "gen_child"
	child.name = "Lin Bao"
	child.age_days = age * Calendar.DAYS_PER_YEAR
	child.spiritual_roots = {"fire": 60}
	child.realm_index = 1  # Qi Refining layer 1: far from any bottleneck
	child.home_region = data().start_region
	parent.children.append(child.id)
	child.parents = [parent.id]
	return {"parent": parent, "child": child, "people": {child.id: child}}


func test_data_has_valid_training_rules() -> void:
	assert_eq(Training.validate(data()).size(), 0)
	for id in Training.assignments(data()):
		assert_true(Training.KINDS.has(String(Training.assignment(data(), id)["kind"])), id)


func test_only_own_living_children_old_enough_can_be_assigned() -> void:
	var f := _family()
	var parent: CharacterData = f["parent"]
	var child: CharacterData = f["child"]
	var stranger := new_character(5)
	stranger.id = "gen_stranger"
	assert_true(Training.check_assign(parent, stranger, "cultivate", "", data()).contains("own children"))
	assert_true(Training.check_assign(parent, child, "nonsense", "", data()) != "")
	assert_eq(Training.check_assign(parent, child, "cultivate", "", data()), "")
	child.age_days = 3 * Calendar.DAYS_PER_YEAR
	assert_true(Training.check_assign(parent, child, "cultivate", "", data()).contains("too young"))
	child.age_days = 12 * Calendar.DAYS_PER_YEAR
	child.spiritual_roots = {}
	assert_true(Training.check_assign(parent, child, "cultivate", "", data()).contains("roots"), "rootless")
	assert_true(Training.check_assign(parent, child, "profession", "", data()) != "", "needs a profession")
	assert_true(Training.check_assign(parent, child, "technique", "", data()).contains("Teach"), "no technique yet")
	child.alive = false
	assert_true(Training.check_assign(parent, child, "profession", "alchemist", data()).contains("passed away"))


func test_monthly_cultivation_training_costs_stones_and_adds_qi() -> void:
	var f := _family()
	var parent: CharacterData = f["parent"]
	var child: CharacterData = f["child"]
	assert_true(Training.assign(parent, child, "cultivate", "", data())["ok"])
	assert_eq(Training.current(child), "cultivate")
	var qi_before := child.qi + child.stage * 100000.0
	Training.advance(parent, f["people"], data(), 2)
	assert_eq(parent.item_count("spirit_stone"), 100 - 2 * Training.monthly_cost(data(), "cultivate"))
	assert_gt(child.qi + child.stage * 100000.0, qi_before, "child gained qi")


func test_unpaid_months_are_skipped_with_a_warning() -> void:
	var f := _family()
	var parent: CharacterData = f["parent"]
	var child: CharacterData = f["child"]
	parent.inventory = {}
	Training.assign(parent, child, "cultivate", "", data())
	var qi_before := child.qi
	var events := Training.advance(parent, f["people"], data(), 1)
	assert_eq(events.size(), 1)
	assert_eq(String(events[0]["category"]), "warning")
	assert_eq(child.qi, qi_before, "no training without pay")


func test_profession_training_ranks_up_the_child() -> void:
	var f := _family()
	var parent: CharacterData = f["parent"]
	var child: CharacterData = f["child"]
	parent.inventory = {"spirit_stone": 10000}
	assert_true(Training.assign(parent, child, "profession", "alchemist", data())["ok"])
	assert_eq(String(child.training["profession"]), "alchemist")
	var events := Training.advance(parent, f["people"], data(), 24)
	assert_gt(Professions.rank_of(child, "alchemist"), 0)
	assert_true(events.any(func(e: Dictionary) -> bool: return String(e["text"]).contains("Alchemist")), "rank-up reported")


func test_teaching_and_technique_drills() -> void:
	var f := _family()
	var parent: CharacterData = f["parent"]
	var child: CharacterData = f["child"]
	assert_true(Training.check_teach(parent, child, "basic_breathing", data()).contains("You do not know"))
	Techniques.learn(parent, data(), "basic_breathing")
	var result := Training.teach(parent, child, "basic_breathing", data())
	assert_true(result["ok"], str(result["reason"]))
	assert_gt(int(result["days"]), 0)
	assert_true(Techniques.knows(child, "basic_breathing"))
	assert_true(Training.check_teach(parent, child, "basic_breathing", data()).contains("already"))
	child.age_days = 5 * Calendar.DAYS_PER_YEAR
	child.techniques = {}
	assert_true(Training.check_teach(parent, child, "basic_breathing", data()).contains("too young"))
	child.age_days = 12 * Calendar.DAYS_PER_YEAR
	Training.teach(parent, child, "basic_breathing", data())
	assert_true(Training.assign(parent, child, "technique", "", data())["ok"])
	parent.inventory = {"spirit_stone": 1000}
	Training.advance(parent, f["people"], data(), 6)
	assert_gt(Techniques.level(child, "basic_breathing"), 1, "drills level the technique")


func test_giving_a_pill_to_a_child() -> void:
	var f := _family()
	var parent: CharacterData = f["parent"]
	var child: CharacterData = f["child"]
	assert_true(Training.check_give(parent, child, "qi_gathering_pill", data()).contains("none left"))
	parent.add_item("qi_gathering_pill", 1)
	var qi_before := child.qi + child.stage * 100000.0
	var result := Training.give(parent, child, "qi_gathering_pill", data(), {})
	assert_true(result["ok"], str(result["reason"]))
	assert_eq(parent.item_count("qi_gathering_pill"), 0)
	assert_eq(child.item_count("qi_gathering_pill"), 0, "used at once, not stored")
	assert_gt(child.qi + child.stage * 100000.0, qi_before)


func test_qi_pills_are_not_wasted_on_children_who_cannot_cultivate() -> void:
	var f := _family()
	var parent: CharacterData = f["parent"]
	var child: CharacterData = f["child"]
	parent.add_item("qi_gathering_pill", 1)
	child.spiritual_roots = {}
	assert_true(Training.check_give(parent, child, "qi_gathering_pill", data()).contains("spiritual roots"))
	assert_false(Training.give(parent, child, "qi_gathering_pill", data(), {})["ok"])
	assert_eq(parent.item_count("qi_gathering_pill"), 1, "the pill is kept")
	child.spiritual_roots = {"fire": 60}
	child.age_days = (Children.cultivation_start_age(data()) - 1) * Calendar.DAYS_PER_YEAR
	assert_true(Training.check_give(parent, child, "qi_gathering_pill", data()).contains("too young"))
	parent.add_item("bone_setting_salve", 1)
	child.injuries = {"broken_bones": 30}
	assert_eq(Training.check_give(parent, child, "bone_setting_salve", data()), "", "healing pills still work for any child")


func test_training_survives_save_round_trip() -> void:
	var f := _family()
	Training.assign(f["parent"], f["child"], "profession", "doctor", data())
	var copy := CharacterData.from_dict(JSON.parse_string(JSON.stringify((f["child"] as CharacterData).to_dict())))
	assert_eq(copy.training, {"assignment": "profession", "profession": "doctor"})
	assert_eq(CharacterData.from_dict({}).training, {}, "old saves have no training")


func test_game_state_training_actions() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male")
	gs.start_session(c)
	var child := Npcs.spawn(gs.npcs, gs.data, seeded_rng(3), {"age_years": 10, "region": gs.current_region, "roots": {"water": 50}})
	child.parents = [c.id]
	c.children.append(child.id)
	c.inventory["spirit_stone"] = 50
	c.add_item("qi_gathering_pill", 1)
	Techniques.learn(c, gs.data, "basic_breathing")
	var clock: Node = _root().get_node("GameClock")
	var days: int = clock.total_days
	gs.assign_training(child.id, "cultivate")
	assert_eq(Training.current(child), "cultivate")
	assert_eq(clock.total_days, days, "assigning takes no time")
	gs.give_to_child(child.id, "qi_gathering_pill")
	assert_eq(c.item_count("qi_gathering_pill"), 0)
	gs.teach_technique(child.id, "basic_breathing")
	assert_true(Techniques.knows(child, "basic_breathing"))
	assert_gt(clock.total_days, days, "teaching takes time")
	var stones: int = c.item_count("spirit_stone")
	clock.advance(Calendar.DAYS_PER_MONTH * 2)
	assert_eq(c.item_count("spirit_stone"), stones - 2 * Training.monthly_cost(gs.data, "cultivate"), "paid monthly")
	var saved: Dictionary = gs.to_save_dict()
	gs.load_save_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(Training.current(gs.npcs[child.id]), "cultivate", "assignment survives a save")
	gs.clear_training(child.id)
	assert_eq(Training.current(gs.npcs[child.id]), "")
	gs.npcs[child.id].home_region = "nowhere"
	gs.teach_technique(child.id, "basic_breathing")
	gs.end_session()
