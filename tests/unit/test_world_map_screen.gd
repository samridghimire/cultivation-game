extends TestCase
## WorldMapScreen helpers and a smoke test of the screen itself.


func test_layout_places_every_region_inside_the_map() -> void:
	var positions := WorldMapScreen.layout(data())
	assert_eq(positions.size(), data().regions.size())
	for region_id in positions:
		var p: Vector2 = positions[region_id]
		assert_true(p.x >= 0.0 and p.x <= 1.0 and p.y >= 0.0 and p.y <= 1.0, "%s off the map" % region_id)
	assert_eq(positions["qingshi_village"], Vector2(0.08, 0.72))


func test_route_lines_show_here_and_realm_gates() -> void:
	var c := new_character()
	c.realm_index = 0
	var here := WorldMapScreen.route_lines(c, data(), "misty_forest", "misty_forest")
	assert_eq(here[0], "You are here.")
	var gated := false
	for line in here:
		if line.contains(Exploration.region_name(data(), "azure_peak")) and line.contains("too perilous"):
			gated = true
	assert_true(gated)
	var far := WorldMapScreen.route_lines(c, data(), "qingshi_village", "azure_peak")
	assert_true(far[0].begins_with("There is no road"))
	var near := WorldMapScreen.route_lines(c, data(), "qingshi_village", "misty_forest")
	assert_true(near[0].begins_with("Direct road from here"))


func test_place_names_skip_travel_points() -> void:
	var names := WorldMapScreen.place_names(data(), "qingshi_village")
	assert_true(names.has("Wandering Merchant"))
	assert_false(names.has("Village Gate"))


func test_map_pos_is_validated() -> void:
	var d := data()
	var region: Dictionary = d.regions["qingshi_village"]
	var saved: Variant = region["map_pos"]
	var before := d.load_errors.size()
	region["map_pos"] = [2, 0.5]
	d._validate_world()
	assert_gt(d.load_errors.size(), before)
	region["map_pos"] = saved
	d.load_errors.resize(before)


func test_screen_opens_on_current_region() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(new_character())
	var screen := WorldMapScreen.new()
	root.add_child(screen)
	screen.open()
	assert_eq(screen._selected, gs.current_region)
	assert_eq(screen._canvas.get_child_count(), data().regions.size())
	screen._select("misty_forest")
	assert_eq(screen._name.text, Exploration.region_name(data(), "misty_forest"))
	screen.close()
	screen.free()
	gs.end_session()


## UI-008b: the map marks your sect hall, abode, family, anchors, secret
## realms and world events.
func test_region_marks() -> void:
	var d := data()
	var c := new_character()
	var people := {}
	var kinds := func(region_id: String, events: Array = []) -> Array:
		return WorldMapScreen.region_marks(c, d, people, events, 0, region_id).map(func(m: Dictionary) -> String: return m["kind"])
	c.anchors = []
	assert_false(kinds.call("misty_forest").has("abode"))
	c.abode = "waterfall_cave"
	assert_true(kinds.call(String(d.abodes["waterfall_cave"]["region"])).has("abode"))
	c.anchors = ["qingshi_rock"]
	var anchor_marks := WorldMapScreen.region_marks(c, d, people, [], 0, "qingshi_village").filter(func(m: Dictionary) -> bool: return m["kind"] == "anchor")
	assert_true(String(anchor_marks[0]["text"]).ends_with("(respawn point)"))
	assert_false(kinds.call("qingshi_village").has("sect"), "rogues have no sect hall mark")
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0}
	assert_true(kinds.call("qingshi_village").has("sect"))
	var wife := Npcs.spawn(people, d, seeded_rng(), {"gender": "female", "region": "fallen_star_market"})
	c.spouses.append(wife.id)
	assert_true(kinds.call("fallen_star_market").has("family"))
	assert_true(kinds.call("misty_forest").has("secret_realm"), "the Verdant Remnant lies in Misty Forest")
	var events: Array = [{"id": "beast_tide", "region": "azure_peak", "start_day": 0, "end_day": 30}]
	assert_true(kinds.call("azure_peak", events).has("event"))
	for kind in ["sect", "abode", "family", "anchor", "secret_realm", "event"]:
		assert_true(WorldMapScreen.MARK_COLORS.has(kind), kind)
