extends TestCase
## GFX-093: festival decor poles around the square keep clear of stalls, landmarks and the map edge.


func test_layout_counts_and_clearance() -> void:
	var blockers: Array[Rect2] = [Rect2(700, 780, 70, 60)]
	var size := Vector2(2000, 1600)
	for id in ["dragon_boat_festival", "lantern_festival", "mid_autumn_festival", "qingming_festival"]:
		var poles := FestivalDecor.layout(Vector2(1000, 800), id, blockers, size)
		assert_true(poles.size() >= 6 and poles.size() <= 8, "%s pole count %d" % [id, poles.size()])
		for p in poles:
			assert_true(not blockers[0].grow(FestivalDecor.CLEAR).has_point(p), "pole off the stall")
			assert_true(p.distance_to(Vector2(1000, 800)) >= 140.0, "outside the crowd ring")
		assert_eq(poles, FestivalDecor.layout(Vector2(1000, 800), id, blockers, size))


func test_layout_respects_map_edge() -> void:
	var poles := FestivalDecor.layout(Vector2(200, 200), "lantern_festival", [], Vector2(600, 600))
	for p in poles:
		assert_true(p.x >= FestivalDecor.EDGE and p.y >= FestivalDecor.EDGE, "160 px from the edge")


func test_glows() -> void:
	assert_true(FestivalDecor.glows("lanterns"))
	assert_true(FestivalDecor.glows("moon"))
	assert_true(not FestivalDecor.glows("willow"))


func test_qingshi_decor_in_world() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male"))
	gs.current_region = "qingshi_village"
	gs.world_events = [{"id": "lantern_festival", "region": "qingshi_village", "start_day": 0, "end_day": 99999, "done": false}]
	var world: Node = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	var found: FestivalDecor = null
	for child in world.get_children():
		if child is FestivalDecor:
			found = child
	assert_true(found != null)
	assert_true(found.poles.size() >= 4)
	world.free()
	gs.end_session()


## GFX-097: every festival names a decor look and colours in data; the look lists agree.
func test_every_festival_has_decor() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	assert_eq(WorldEvents.DECOR_LOOKS.size(), FestivalStall.LOOK_DRAW.size())
	for look: String in WorldEvents.DECOR_LOOKS:
		assert_true(FestivalStall.LOOK_DRAW.has(look), look)
	for id: String in gs.data.world_events:
		if gs.data.world_events[id].get("festival", false):
			assert_true(gs.data.world_events[id].has("decor"), id)
			assert_true(FestivalStall.colors_for(id).size() >= 1)


func test_decor_validation_catches_bad_look() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var def: Dictionary = gs.data.world_events["lantern_festival"]
	var saved: Variant = def["decor"]
	def["decor"] = {"look": "fireworks", "colors": ["#fff"]}
	assert_true(not WorldEvents.validate(gs.data).is_empty())
	def["decor"] = {"look": "drum", "colors": ["nope"]}
	assert_true(not WorldEvents.validate(gs.data).is_empty())
	def["decor"] = saved
	assert_true(WorldEvents.validate(gs.data).is_empty())
