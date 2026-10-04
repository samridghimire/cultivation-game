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
	assert_true(String(_labels(place.get_options())[1]).contains("needs Constitution 11"), str(_labels(place.get_options())))
	(place.get_options()[1]["action"] as Callable).call()
	assert_true(String(_labels(place.get_options())[1]).contains("fight: Stone Ape, "), "fight trials show their danger")
	gs.world_flags[Inheritances.claimed_flag("fist_saint_grave")] = true
	labels = _labels(place.get_options())
	assert_eq(labels.size(), 1, "claimed: no attempt entry")
	assert_true(labels[0].ends_with("Claimed by you"))
	gs.current_region = "fallen_star_market"
	labels = _labels(place.get_options())
	assert_true(labels[0].begins_with("Weathered stones"), "the vault stays hidden until it is found: %s" % str(labels))
	place.free()
	gs.end_session()
