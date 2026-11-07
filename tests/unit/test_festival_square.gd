extends TestCase
## GFX-085: the festival square holds the contest stall and its crowd; mortal labels drop "(Mortal)".


func test_square_validation() -> void:
	var base := {"id": "r", "map": {"size": [1000, 800]}, "places": [{"display_name": "Well", "pos": [500, 400]}]}
	var ok := base.merged({"festival_square": [200, 200]})
	assert_eq(GameData._festival_square_errors(ok).size(), 0)
	assert_eq(GameData._festival_square_errors(base.merged({"festival_square": [2000, 100]})).size(), 1)
	assert_eq(GameData._festival_square_errors(base.merged({"festival_square": [520, 410]})).size(), 1)
	assert_eq(GameData._festival_square_errors(base.merged({"festival_square": [1]})).size(), 1)
	assert_eq(GameData._festival_square_errors(base.merged({"festival_square": [100, 200]})).size(), 1)  # GFX-090: 100 px from the edge


func test_stall_and_crowd_at_the_square() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male"))
	gs.current_region = "qingshi_village"
	gs.world_events = [{"id": "lantern_festival", "region": "qingshi_village", "start_day": 0, "end_day": 99999, "done": false}]
	var world: Node = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	var square := Vector2(gs.data.regions["qingshi_village"]["festival_square"][0], gs.data.regions["qingshi_village"]["festival_square"][1])
	var stall: FestivalStall = null
	var captions := 0
	for child in world.get_children():
		if child is FestivalStall:
			if stall == null:
				stall = child
			if child.caption != "":
				captions += 1
	assert_true(stall != null)
	assert_eq(stall.position, square)
	assert_eq(captions, 1)
	for child in world.get_children():
		if child is Interactable and child.get("npc_id") != null:
			for place: Dictionary in gs.data.regions["qingshi_village"]["places"]:
				var pp := Vector2(place["pos"][0], place["pos"][1])
				assert_true(child.position.distance_to(pp) >= FestivalContest.CROWD_CLEAR or child.position.distance_to(square) > 200.0, "no villager on a place")
	world.free()
	gs.end_session()


func test_mortal_label_drops_realm() -> void:
	var npc: Variant = load("res://src/world/interactables/npc.gd").new()
	npc.display_name = "Qin Yan (Mortal)"
	npc._near = true
	assert_eq(npc.label_text(), "Qin Yan")
	npc.display_name = "Qin Yan (Qi Refining, 1st Layer)"
	assert_eq(npc.label_text(), "Qin Yan (Qi Refining, 1st Layer)")
	npc.free()


## WU-481: npc_spots keep clear of travel signposts.
func test_signpost_clearance() -> void:
	var region := {"id": "r", "npc_spots": [[100, 100], [500, 500]], "places": [{"type": "travel", "display_name": "Gate", "pos": [120, 110]}]}
	assert_eq(GameData.signpost_clearance_errors(region).size(), 1)
	region["npc_spots"] = [[300, 300]]
	assert_eq(GameData.signpost_clearance_errors(region).size(), 0)
