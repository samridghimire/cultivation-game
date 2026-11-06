extends TestCase
## FOLK-013: friend scenes (data/npcs.json "scenes"): ordering, seen once, one a day, gift, save round-trip.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _start() -> CharacterData:
	var gs := _root().get_node("GameState")
	var c := CharacterFactory.create("Scene", gs.data, seeded_rng(77))
	gs.start_session(c)
	return c


func test_scene_due_orders_specific_before_generic() -> void:
	var c := CharacterData.new()
	assert_true(Folk.scene_due(c, data(), "xiao_ling", 39).is_empty())
	assert_eq(String(Folk.scene_due(c, data(), "xiao_ling", 40)["id"]), "xiao_ling_old_swing")
	assert_eq(String(Folk.scene_due(c, data(), "some_villager", 40)["id"]), "villager_shared_bowl")


func test_scene_seen_once() -> void:
	var c := CharacterData.new()
	Folk.mark_scene(c, "xiao_ling_old_swing", 5)
	assert_eq(String(Folk.scene_due(c, data(), "xiao_ling", 90)["id"]), "villager_shared_bowl")
	Folk.mark_scene(c, "villager_shared_bowl", 5)
	assert_true(Folk.scene_due(c, data(), "xiao_ling", 90).is_empty())


func test_talking_plays_scene_gift_once_and_one_per_day() -> void:
	var c := _start()
	var gs := _root().get_node("GameState")
	var got: Array = []
	var cb := func(n: String, t: String) -> void: got.append(n)
	EventBus.friend_scene.connect(cb)
	gs.npc_favor["xiao_ling"] = 45
	var rice := c.item_count("sweet_rice_ball")
	gs.start_dialogue("xiao_ling")
	EventBus.friend_scene.disconnect(cb)
	assert_eq(got.size(), 1)
	assert_true(c.scenes_seen.has("xiao_ling_old_swing"))
	assert_eq(c.item_count("sweet_rice_ball"), rice + 1)
	# Same day: no second scene even though the generic one is due for another villager.
	assert_false(Folk.scene_due(c, gs.data, "xiao_ling", 45).is_empty())
	gs._friend_scene("xiao_ling")
	assert_false(c.scenes_seen.has("villager_shared_bowl"))
	gs.end_dialogue()
	# Next day the generic scene may play.
	_root().get_node("GameClock").total_days += 1
	gs._friend_scene("xiao_ling")
	assert_true(c.scenes_seen.has("villager_shared_bowl"))


func test_scenes_round_trip() -> void:
	var c := CharacterData.new()
	Folk.mark_scene(c, "xiao_ling_old_swing", 9)
	var back := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_true(back.scenes_seen.has("xiao_ling_old_swing"))
	assert_eq(back.scene_day, 9)
	assert_eq(CharacterData.from_dict({}).scene_day, -1)
