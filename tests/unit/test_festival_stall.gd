extends TestCase
## WU-097: festival stalls beside merchants while a festival runs in the region.


func _count_stalls(world: Node) -> int:
	var n := 0
	for child in world.get_children():
		if child is FestivalStall:
			n += 1
	return n


func test_stall_decor_by_festival() -> void:
	assert_eq(FestivalStall.decor_for("qingming_festival"), "willow")
	assert_eq(FestivalStall.decor_for("lantern_festival"), "lanterns")
	assert_eq(FestivalStall.decor_for("mystery_festival"), "lanterns")


## GFX-083: each festival has its own look, and every festival_only stall's festival is a known one.
func test_festival_looks_distinct() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var seen := {}
	for id: String in gs.data.world_events:
		if gs.data.world_events[id].get("festival", false):
			var look := FestivalStall.decor_for(id)
			assert_false(seen.has(look), "look %s reused by %s" % [look, id])
			seen[look] = id
	assert_eq(seen.size(), 4)
	for region: Dictionary in gs.data.regions.values():
		for place: Dictionary in region["places"]:
			if place.has("festival_only"):
				assert_true(FestivalStall.LOOKS.has(String(place["festival_only"])))


func test_festival_only_merchant_has_decor() -> void:
	var m: Interactable = load("res://src/world/interactables/merchant.gd").new()
	m.festival_only = "mid_autumn_festival"
	m.size = Vector2(70, 60)
	m._ready()
	var found: FestivalStall = null
	for c in m.get_children():
		if c is FestivalStall:
			found = c
	assert_true(found != null and found.decor_only)
	assert_eq(FestivalStall.decor_for(found.event_id), "moon")
	m.free()


func test_stalls_follow_active_festival() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male"))
	gs.current_region = "qingshi_village"
	gs.world_events = []
	var world: Node = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	assert_eq(_count_stalls(world), 0)
	gs.world_events = [{"id": "lantern_festival", "region": "qingshi_village", "start_day": 0, "end_day": 99999, "done": false}]
	world._on_days_advanced(1)
	var merchants := 0
	for place: Dictionary in gs.data.regions["qingshi_village"]["places"]:
		if place["type"] == "merchant" and not place.has("open_days") and not place.has("festival_only"):
			merchants += 1
	assert_true(merchants > 0)
	assert_eq(_count_stalls(world), merchants)
	gs.world_events = [{"id": "lantern_festival", "region": "elsewhere", "start_day": 0, "end_day": 99999, "done": false}]
	world._on_days_advanced(1)
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_eq(_count_stalls(world), 0)
	world.free()
	gs.end_session()


## FEST-012: festival-only stalls.
func test_festival_open_follows_event() -> void:
	var place := {"festival_only": "lantern_festival"}
	var ev := [{"id": "lantern_festival", "region": "qingshi_village", "start_day": 100, "end_day": 108, "done": false}]
	assert_true(Places.festival_open(place, ev, "qingshi_village", 100))
	assert_true(Places.festival_open(place, ev, "qingshi_village", 108))
	assert_false(Places.festival_open(place, ev, "qingshi_village", 99))
	assert_false(Places.festival_open(place, ev, "qingshi_village", 109))
	assert_false(Places.festival_open(place, ev, "azure_peak", 101))
	assert_true(Places.festival_open({}, [], "qingshi_village", 5))


func test_festival_stall_data_valid() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var found := 0
	for region: Dictionary in gs.data.regions.values():
		for place: Dictionary in region["places"]:
			if place.has("festival_only"):
				found += 1
				assert_eq(Places.validate_festival_only(place["festival_only"], String(region["id"]), gs.data, "x").size(), 0)
	assert_true(found >= 4)
	assert_true(Places.validate_festival_only("nope", "qingshi_village", gs.data, "x").size() > 0)
	assert_true(Places.validate_festival_only("lantern_festival", "azure_peak", gs.data, "x").size() > 0)


func test_festival_stall_world_and_today() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male"))
	gs.current_region = "qingshi_village"
	gs.world_events = []
	var today: int = GameClock.total_days
	assert_eq(Places.festival_stalls_open(gs.data, gs.world_events, "qingshi_village", today).size(), 0)
	gs.world_events = [{"id": "lantern_festival", "region": "qingshi_village", "start_day": today, "end_day": today + 5, "done": false}]
	assert_eq(Places.festival_stalls_open(gs.data, gs.world_events, "qingshi_village", today).size(), 1)
	var lines: PackedStringArray = gs.today_lines()
	assert_true(lines.size() > 0 and "festival stall open" in lines[0])
	var world: Node = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	assert_true(world._timed_places.has("Lantern Sweets Stall"))
	gs.world_events = []
	world._on_days_advanced(1)
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_false(world._timed_places.has("Lantern Sweets Stall"))
	world.free()
