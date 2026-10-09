## EXPL-001: encounters that only open after exploring a region for a while.
extends TestCase


func _ids(c: CharacterData, region_id: String) -> Array:
	return Exploration.eligible_encounters(c, data(), ["forest"], {}, null, 1.0, "", region_id).map(func(e: Dictionary) -> String: return e["encounter"]["id"])


func test_familiarity_is_per_region() -> void:
	var c := new_character()
	Exploration.add_explore_day(c, "misty_forest")
	Exploration.add_explore_day(c, "misty_forest")
	Exploration.add_explore_day(c, "qingshi_village")
	Exploration.add_explore_day(c, "")
	assert_eq(Exploration.familiarity(c, "misty_forest"), 2)
	assert_eq(Exploration.familiarity(c, "qingshi_village"), 1)
	assert_eq(c.explore_days.size(), 2)


func test_min_explores_gates_the_encounter() -> void:
	var c := new_character()
	c.realm_index = 1
	c.explore_days["misty_forest"] = 19
	assert_false(_ids(c, "misty_forest").has("misty_forest_hidden_valley"))
	c.explore_days["misty_forest"] = 20
	assert_true(_ids(c, "misty_forest").has("misty_forest_hidden_valley"))
	assert_false(_ids(c, "").has("misty_forest_hidden_valley"), "no region, no deep paths")
	assert_false(_ids(c, "qingshi_village").has("misty_forest_hidden_valley"))


func test_next_deep_path() -> void:
	var c := new_character()
	c.realm_index = 1
	assert_eq(Exploration.next_deep_path(c, data(), "misty_forest"), 20)
	c.explore_days["misty_forest"] = 20
	assert_eq(Exploration.next_deep_path(c, data(), "misty_forest"), -1)


func test_journal_line_until_the_path_opens() -> void:
	var c := new_character()
	c.realm_index = 1
	c.explore_days["misty_forest"] = 5
	var rows := Guidance.journal(c, data(), {}, 0, "misty_forest")
	assert_true(rows.any(func(r: Dictionary) -> bool: return String(r.get("text", "")).contains("explored 5 days. Something deeper waits after 20")), str(rows))
	c.explore_days["misty_forest"] = 20
	rows = Guidance.journal(c, data(), {}, 0, "misty_forest")
	assert_false(rows.any(func(r: Dictionary) -> bool: return String(r.get("text", "")).contains("Something deeper")))


func test_validator_rejects_bad_min_explores() -> void:
	for bad: Variant in [0, "ten", 2.5]:
		var d := data()
		var saved: Variant = d.encounters["misty_forest_hidden_valley"]["min_explores"]
		d.encounters["misty_forest_hidden_valley"]["min_explores"] = bad
		d.load_errors.clear()
		d._validate()
		assert_true(Array(d.load_errors).any(func(m: String) -> bool: return m.contains("min_explores")), str(bad))
		d.encounters["misty_forest_hidden_valley"]["min_explores"] = saved
		d.load_errors.clear()


func test_explore_days_round_trip() -> void:
	var c := new_character()
	c.explore_days["misty_forest"] = 7
	assert_eq(CharacterData.from_dict(c.to_dict()).explore_days, {"misty_forest": 7})
	var d := c.to_dict()
	d.erase("explore_days")
	assert_eq(CharacterData.from_dict(d).explore_days, {})


## GUIDE-016: a deeper path announces itself and is found.
func test_open_deep_paths_follow_familiarity_and_flag() -> void:
	var c := new_character()
	c.realm_index = 1
	c.explore_days["misty_forest"] = 19
	assert_eq(Exploration.open_deep_paths(c, data(), "misty_forest", {}), [])
	assert_true(Exploration.deep_path_for(c, data(), "misty_forest", {}).is_empty())
	c.explore_days["misty_forest"] = 20
	assert_eq(Exploration.open_deep_paths(c, data(), "misty_forest", {}), ["misty_forest_hidden_valley"])
	assert_eq(Exploration.deep_path_for(c, data(), "misty_forest", {})["id"], "misty_forest_hidden_valley")
	assert_eq(Exploration.open_deep_paths(c, data(), "misty_forest", {"found_hidden_valley": true}), [])
	c.realm_index = 0
	assert_eq(Exploration.open_deep_paths(c, data(), "misty_forest", {}), [], "waits for the realm")


func test_notice_appears_once_at_the_threshold() -> void:
	var c := new_character()
	c.realm_index = 1
	c.visited_regions = ["misty_forest"]
	c.explore_days["misty_forest"] = 19
	var has := func(n: Dictionary) -> bool: return String(n["id"]) == "deep_path_misty_forest_hidden_valley"
	assert_false(Guidance.unlock_notices(c, data(), {}).any(has))
	c.explore_days["misty_forest"] = 20
	assert_true(Guidance.unlock_notices(c, data(), {}).any(has))
	assert_false(Guidance.unlock_notices(c, data(), {"notice_deep_path_misty_forest_hidden_valley": true}).any(has))


func test_explore_meets_the_hidden_path_once() -> void:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var c := new_character(31)
	c.realm_index = 1
	gs.start_session(c)
	gs.travel("misty_forest")
	gs.world_flags["discovered_misty_forest"] = true
	gs.player.explore_days["misty_forest"] = 19
	gs.explore()
	assert_true(gs.last_explore_deep_path, "day 20 meets the path")
	assert_true(gs.world_flags.get("found_hidden_valley", false))
	for i in 15:
		gs.player.alive = true
		gs.explore()
		assert_false(gs.last_explore_deep_path)
		if gs.pending_encounter != "":
			gs.choose_encounter(0)
	gs.end_session()


## A deeper path is not the region's discovery: it must not set discovered_<region>
## (that would use up a discovery the player never met).
func test_deep_path_does_not_mark_the_region_discovered() -> void:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var c := new_character(32)
	c.realm_index = 1
	gs.start_session(c)
	var region := String(gs.current_region)
	# The region's discovery is out of reach for now (as when it is realm- or alignment-gated).
	var old_discovery: Variant = gs.data.regions[region].get("discovery", "")
	gs.data.regions[region]["discovery"] = ""
	var at := Exploration.next_deep_path(gs.player, gs.data, region)
	assert_true(at >= 0, "%s has a deeper path" % region)
	gs.player.explore_days[region] = at - 1
	gs.explore()
	gs.data.regions[region]["discovery"] = old_discovery
	assert_true(gs.last_explore_deep_path)
	assert_false(gs.last_explore_discovery)
	assert_false(gs.world_flags.get("discovered_" + region, false))
	gs.end_session()


func test_every_region_has_a_deeper_path_sharing_its_tags() -> void:
	for rid: String in data().regions:
		var tags: Array = data().regions[rid].get("encounter_tags", [])
		var found := false
		for eid: String in data().encounters:
			var e: Dictionary = data().encounters[eid]
			if not e.has("min_explores") or not e.has("blocked_by_flag"):
				continue
			for t: Variant in e.get("tags", []):
				if tags.has(t):
					found = true
		assert_true(found, "%s has no deeper path" % rid)
