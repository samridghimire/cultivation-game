extends TestCase
## RUMOR-001: merchant gossip from data/rumors.json.


func _rd(rows: Array, max_per_visit: int = 2) -> GameData:
	var d := GameData.load_from_dir()
	d.rumors.clear()
	for r: Dictionary in rows:
		d.rumors[r["id"]] = r
	d.rumor_rules["max_per_visit"] = max_per_visit
	return d


func _qi() -> CharacterData:
	var c := new_character()
	c.realm_index = 1
	return c


func test_region_and_realm_filters() -> void:
	var d := _rd([
		{"id": "a", "text": "A", "region": "qingshi_village"},
		{"id": "b", "text": "B", "min_realm": "foundation_establishment"},
		{"id": "c", "text": "C"},
	])
	assert_eq(Rumors.eligible(_qi(), d, {}, "qingshi_village") as Array, ["a", "c"])
	assert_eq(Rumors.eligible(_qi(), d, {}, "azure_peak") as Array, ["c"])
	var f := _qi()
	f.realm_index = 2
	assert_eq(Rumors.eligible(f, d, {}, "azure_peak") as Array, ["b", "c"])


func test_flags() -> void:
	var d := _rd([
		{"id": "a", "text": "A", "requires_flag": "x"},
		{"id": "b", "text": "B", "blocked_by_flag": "y"},
	])
	assert_eq(Rumors.eligible(_qi(), d, {}, "") as Array, ["b"])
	assert_eq(Rumors.eligible(_qi(), d, {"x": true, "y": true}, "") as Array, ["a"])


func test_rotation_by_day() -> void:
	var d := _rd([{"id": "a", "text": "A"}, {"id": "b", "text": "B"}, {"id": "c", "text": "C"}])
	assert_eq(Rumors.lines(_qi(), d, {}, "", 0), PackedStringArray(["A", "B"]))
	assert_eq(Rumors.lines(_qi(), d, {}, "", 1), PackedStringArray(["B", "C"]))
	assert_eq(Rumors.lines(_qi(), d, {}, "", 2), PackedStringArray(["C", "A"]))


func test_empty_and_single() -> void:
	assert_eq(Rumors.lines(_qi(), _rd([]), {}, "", 5).size(), 0)
	assert_eq(Rumors.lines(_qi(), _rd([{"id": "a", "text": "A"}]), {}, "", 5), PackedStringArray(["A"]))


func test_validation() -> void:
	var d := _rd([{"id": "a", "text": "", "region": "nowhere", "min_realm": "nope"}], 0)
	d.load_errors.clear()
	d._validate_rumors()
	assert_eq(d.load_errors.size(), 4, str(d.load_errors))
	var ok := GameData.load_from_dir()
	assert_eq(ok.load_errors.size(), 0, str(ok.load_errors))
	assert_gt(ok.rumors.size(), 2)


func test_hear_rumors_posts_region_rumor() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	gs.start_session(new_character())
	gs.data.rumors = {
		"here": {"id": "here", "text": "Gossip here.", "region": gs.current_region},
		"there": {"id": "there", "text": "Gossip there.", "region": "azure_peak"},
	}
	var bus := (Engine.get_main_loop() as SceneTree).root.get_node("EventBus")
	var posted: Array = []
	var cb := func(text: String, _category: String) -> void: posted.append(text)
	bus.message_posted.connect(cb)
	gs.hear_rumors()
	bus.message_posted.disconnect(cb)
	assert_true(posted.has("Gossip here."), str(posted))
	assert_false(posted.has("Gossip there."))
	gs.end_session()


func test_every_region_has_a_data_rumor() -> void:
	var d := GameData.load_from_dir()
	var covered := {}
	for r: Dictionary in d.rumors.values():
		covered[String(r.get("region", ""))] = true
	for region_id: String in d.regions:
		assert_true(covered.has(region_id), "%s has no rumor" % region_id)


func test_shrug_only_when_nothing_else() -> void:
	var d := _rd([])
	var none := PackedStringArray()
	assert_eq(WorldEvents.rumors(d, [], none, 0).size(), 1)
	assert_true(WorldEvents.rumors(d, [], none, 0)[0].contains("shrugs"))
	var one := WorldEvents.rumors(d, [], PackedStringArray(["Auction soon."]), 0)
	assert_eq(one as Array, ["Auction soon."])


func test_duplicate_rumor_id_reported() -> void:
	var d := _rd([])
	d.load_errors.clear()
	d._load_rumors({"rumors": [{"id": "x", "text": "A"}, {"id": "x", "text": "B"}]})
	assert_true(d.load_errors.has("rumors.json has a duplicate rumor id 'x'"), str(d.load_errors))
