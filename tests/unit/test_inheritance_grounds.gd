extends TestCase
## W-006b/W-006c: inheritance grounds places and content.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _labels(options: Array) -> Array:
	return options.map(func(o: Dictionary) -> String: return o["label"])


func test_every_region_with_an_inheritance_has_grounds() -> void:
	var d := data()
	for region_id: String in d.regions:
		var has_place: bool = (d.regions[region_id].get("places", []) as Array).any(func(p: Dictionary) -> bool: return p.get("type", "") == "inheritance")
		assert_eq(has_place, not Inheritances.in_region(d, region_id).is_empty(), region_id)
	assert_true(d.regions.keys().all(func(r: String) -> bool: return not Inheritances.in_region(d, r).is_empty()), "one inheritance per region")
	var core := d.inheritances.values().filter(func(i: Dictionary) -> bool: return (i["stages"] as Array).any(func(s: Dictionary) -> bool: return s.get("min_realm", "") == "core_formation"))
	assert_true(core.size() >= 2, "Core Formation legacies exist")


func test_trial_note_for_each_test_kind() -> void:
	var d := data()
	var c := new_character()
	var hut: Dictionary = d.inheritances["reed_hermit_hut"]
	var script: GDScript = load("res://src/world/interactables/inheritance_grounds.gd")
	var stages: Array = hut["stages"]
	var kinds := {}
	for stage: Dictionary in stages:
		kinds[String(stage["test"])] = true
		var note: String = script.test_text(c, d, stage)
		match String(stage["test"]):
			"realm":
				assert_eq(note, "needs %s" % Inheritances.realm_requirement(d, stage))
			"attribute":
				assert_true(note.begins_with("needs ") and note.contains(", yours %d" % c.attribute(String(stage["attribute"]))), note)
			"fight":
				assert_true(note.contains(": "), note)
	assert_true(not kinds.is_empty())
	assert_eq(script.trial_note(c, d, "reed_hermit_hut"), script.test_text(c, d, stages[0]))
	c.attributes["spirit"] = 3
	var attr_stage := {"test": "attribute", "attribute": "spirit", "min": 12}
	assert_eq(script.test_text(c, d, attr_stage), "needs Spirit 12, yours 3")
	assert_eq(script.trial_note(c, d, "nope"), "")


func test_grounds_list_trials_and_attempt_them() -> void:
	var gs := _root().get_node("GameState")
	var c := new_character()
	gs.start_session(c)
	gs.current_region = "misty_forest"
	var place: Node = load("res://src/world/interactables/inheritance_grounds.gd").new()
	var labels := _labels(place.get_options())
	assert_true(labels[0].begins_with("Grave of the Wandering Fist Saint: Trial 1/3"), str(labels))
	assert_true(String(labels[1]).begins_with("Attempt the Cairn Gate (needs Qi Refining"), str(labels))
	assert_true(place.get_options()[1]["disabled"], "a mortal cannot knock")
	c.realm_index = 1
	(place.get_options()[1]["action"] as Callable).call()
	assert_eq(Inheritances.stages_cleared(c, "fist_saint_grave"), 1)
	c.attributes["constitution"] = 15
	assert_true(String(_labels(place.get_options())[1]).contains("needs Constitution 11, yours 15"), str(_labels(place.get_options())))
	(place.get_options()[1]["action"] as Callable).call()
	assert_true(String(_labels(place.get_options())[1]).contains("(Grave Guardian Ape: "), "fight trials show their danger")
	gs.world_flags[Inheritances.claimed_flag("fist_saint_grave")] = true
	labels = _labels(place.get_options())
	assert_eq(labels.size(), 1, "claimed: no attempt entry")
	assert_true(labels[0].ends_with("Claimed by you"))
	gs.current_region = "fallen_star_market"
	labels = _labels(place.get_options())
	assert_true(labels[0].begins_with("Weathered stones"), "the vault stays hidden until it is found: %s" % str(labels))
	place.free()
	gs.end_session()


## C-136: a Body Integration legacy (C-122's pattern one realm up).
func test_body_integration_legacy_is_gated_and_rewarded() -> void:
	var d := data()
	var inh: Dictionary = d.inheritances["marrow_throne_hollow"]
	assert_true(Inheritances.in_region(d, String(inh["region"])).has("marrow_throne_hollow"))
	var stages: Array = inh["stages"]
	assert_eq(stages.size(), 3)
	assert_eq(String(stages[0]["test"]), "realm")
	assert_eq(String(stages[0]["min_realm"]), "body_integration")
	assert_eq(String(stages[1]["test"]), "attribute")
	assert_eq(String(stages[2]["test"]), "fight")
	assert_eq(String(d.enemies[String(stages[2]["enemy"])]["realm"]), "body_integration")
	assert_true(int(inh["deadline_years"]) > int(inh["appears_years"]))
	var door: Dictionary = d.inheritances["door_ajar_folder"]
	assert_true(int(inh["reward"]["items"]["spirit_stone"]) > int(door["reward"]["items"]["spirit_stone"]), "pays more than the Void Refinement legacy")
	for item_id: String in inh["reward"]["items"]:
		assert_true(d.items.has(item_id), item_id)


## C-152: a Mahayana legacy (C-136's pattern one realm up).
func test_mahayana_legacy_is_gated_and_rewarded() -> void:
	var d := data()
	var inh: Dictionary = d.inheritances["great_vehicle_sutra_barge"]
	assert_true(Inheritances.in_region(d, String(inh["region"])).has("great_vehicle_sutra_barge"))
	var stages: Array = inh["stages"]
	assert_eq(stages.size(), 3)
	assert_eq(String(stages[0]["test"]), "realm")
	assert_eq(String(stages[0]["min_realm"]), "mahayana")
	assert_eq(String(stages[1]["test"]), "attribute")
	assert_eq(String(stages[2]["test"]), "fight")
	assert_eq(String(d.enemies[String(stages[2]["enemy"])]["realm"]), "mahayana")
	assert_true(int(inh["deadline_years"]) > int(inh["appears_years"]))
	var hollow: Dictionary = d.inheritances["marrow_throne_hollow"]
	assert_true(int(inh["reward"]["items"]["spirit_stone"]) > int(hollow["reward"]["items"]["spirit_stone"]), "pays more than the Body Integration legacy")
	for item_id: String in inh["reward"]["items"]:
		assert_true(d.items.has(item_id), item_id)


## WU-237: stage names that start with "The" do not double the article.
func test_stage_title_drops_leading_the() -> void:
	assert_eq(Inheritances.stage_title("The Hand's-Breadth Gap"), "Hand's-Breadth Gap")
	assert_eq(Inheritances.stage_title("Cairn Gate"), "Cairn Gate")
	var d := data()
	var c := new_character()
	var script: GDScript = load("res://src/world/interactables/inheritance_grounds.gd")
	var folder: Dictionary = script.attempt_option(c, d, "door_ajar_folder", 0)
	assert_true(String(folder["label"]).begins_with("Attempt the Hand's-Breadth Gap"), folder["label"])
