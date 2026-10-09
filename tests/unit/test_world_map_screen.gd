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
	for region_id in d.regions:
		Exploration.visit(c, region_id)  # unexplored regions show no marks (WU-061)
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


func test_discovery_mark_until_found() -> void:
	var d := data()
	var c := new_character()
	var marks := func(region_id: String, flags: Dictionary) -> Array:
		return WorldMapScreen.region_marks(c, d, {}, [], 0, region_id, "", flags).map(func(m: Dictionary) -> String: return m["kind"])
	assert_false(marks.call("misty_forest", {}).has("discovery"), "unvisited: nothing")
	Exploration.visit(c, "misty_forest")
	assert_true(marks.call("misty_forest", {}).has("discovery"))
	assert_false(marks.call("misty_forest", {"discovered_misty_forest": true}).has("discovery"))
	# A discovery the character does not qualify for yet is not hinted (exploring would not find it).
	var enc: Dictionary = d.encounters[String(d.regions["misty_forest"]["discovery"])]
	enc["min_realm"] = "nascent_soul"
	var gated: bool = marks.call("misty_forest", {}).has("discovery")
	enc.erase("min_realm")
	assert_false(gated, "realm-gated discovery not hinted")
	Exploration.visit(c, "qingshi_village")
	assert_false(marks.call("qingshi_village", {}).has("discovery"), "no discovery defined")
	assert_true(WorldMapScreen.MARK_COLORS.has("discovery"))


## WU-011: the current region's joinable events say so on the map.
func test_region_marks_joinable_event() -> void:
	var d := data()
	var events: Array = [{"id": "sect_tournament", "region": "fallen_star_market", "start_day": 0, "end_day": 40}]
	var c := new_character()
	c.realm_index = 1
	var here := WorldMapScreen.region_marks(c, d, {}, events, 0, "fallen_star_market", "fallen_star_market")
	assert_true(String(_event_text(here)).contains("(you can enter)"), _event_text(here))
	var away := WorldMapScreen.region_marks(c, d, {}, events, 0, "fallen_star_market", "qingshi_village")
	assert_false(String(_event_text(away)).contains("(you can enter)"))
	c.realm_index = 0
	var mortal := WorldMapScreen.region_marks(c, d, {}, events, 0, "fallen_star_market", "fallen_star_market")
	assert_false(String(_event_text(mortal)).contains("(you can enter)"))


func _event_text(marks: Array[Dictionary]) -> String:
	for m in marks:
		if m["kind"] == "event":
			return String(m["text"])
	return ""


## WU-030: explore entries carry the outlook; the map lists foes with danger colors.
func test_explore_options_describe_foes_in_misty_forest() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var c := new_character(11)
	c.realm_index = 1  # mortals meet no forced foes in the forest
	gs.start_session(c)
	gs.current_region = "misty_forest"
	var site: Node = load("res://src/world/interactables/explore_site.gd").new()
	var options: Array[Dictionary] = site.get_options()
	site.free()
	assert_eq(options[0]["label"], "Explore")
	var desc := String(options[0]["description"])
	assert_true(desc.contains("Fights"), desc)
	assert_eq(options[1]["description"], desc)
	gs.end_session()


func test_foes_bbcode_colors_each_danger() -> void:
	var text := WorldMapScreen.foes_bbcode([{"name": "Wolf", "danger": "Weak"}, {"name": "Tiger", "danger": "Deadly"}])
	assert_true(text.contains("Wolf (Weak)") and text.contains("Tiger (Deadly)"))
	assert_true(text.contains("[color=#%s]" % UIStyle.danger_color("Deadly").to_html(false)))
	assert_eq(WorldMapScreen.foes_bbcode([]), "")


## WU-061: regions never visited are dim and show no marks.
func test_unexplored_regions_are_dimmed() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(new_character())
	var screen := WorldMapScreen.new()
	root.add_child(screen)
	screen.open()
	var forest := screen._canvas.get_node("misty_forest") as Button
	assert_true(forest.text.contains("Unexplored"))
	assert_true(forest.modulate.a < 0.6)
	var here := screen._canvas.get_node(NodePath(gs.current_region)) as Button
	assert_false(here.text.contains("Unexplored"))
	assert_true(WorldMapScreen.region_marks(gs.player, data(), gs.npcs, gs.world_events, 0, "misty_forest", gs.current_region).is_empty())
	screen.close()
	screen.free()
	gs.current_region = "qingshi_village"
	Exploration.visit(gs.player, "qingshi_village")
	var point = load("res://src/world/interactables/travel_point.gd").new()
	var found := false
	for o: Dictionary in point.get_options():
		if String(o["label"]).contains(Exploration.region_name(data(), "misty_forest")):
			found = true
			assert_eq(o.get("description", ""), "(never visited)")
	assert_true(found)
	gs.travel("misty_forest")
	gs.travel("qingshi_village")
	for o: Dictionary in point.get_options():
		if String(o["label"]).contains(Exploration.region_name(data(), "misty_forest")):
			assert_false(o.has("description"))
	point.free()
	gs.end_session()
