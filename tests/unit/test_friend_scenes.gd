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
	var v := _villager("qingshi_village")
	assert_eq(String(Folk.scene_due(c, data(), v.id, 40, v, "qingshi_village")["id"]), "villager_shared_bowl")
	assert_true(Folk.scene_due(c, data(), "some_villager", 40).is_empty(), "no npc given: not a villager")


func test_scene_seen_once() -> void:
	var c := CharacterData.new()
	Folk.mark_scene(c, "xiao_ling_old_swing", 5)
	var v := _villager("qingshi_village")
	assert_true(Folk.scene_due(c, data(), "xiao_ling", 90).is_empty())
	assert_eq(String(Folk.scene_due(c, data(), v.id, 90, v, "qingshi_village")["id"]), "villager_shared_bowl")
	Folk.mark_scene(c, "villager_shared_bowl", 5)
	assert_true(Folk.scene_due(c, data(), v.id, 90, v, "qingshi_village").is_empty())


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
	var v := _villager("qingshi_village", gs)
	gs.npc_favor[v.id] = 45
	gs.current_region = "qingshi_village"
	gs._friend_scene(v.id)
	assert_false(c.scenes_seen.has("villager_shared_bowl"))
	gs.end_dialogue()
	# Next day the generic scene may play.
	_root().get_node("GameClock").total_days += 1
	gs._friend_scene(v.id)
	assert_true(c.scenes_seen.has("villager_shared_bowl"))


func test_scenes_round_trip() -> void:
	var c := CharacterData.new()
	Folk.mark_scene(c, "xiao_ling_old_swing", 9)
	var back := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_true(back.scenes_seen.has("xiao_ling_old_swing"))
	assert_eq(back.scene_day, 9)
	assert_eq(CharacterData.from_dict({}).scene_day, -1)


func _villager(region: String, gs: Node = null) -> CharacterData:
	var d: GameData = data() if gs == null else gs.data
	var v := CharacterData.new()
	v.id = "gen_test_villager"
	v.home_region = region
	if gs != null:
		gs.npcs[v.id] = v
	return v


func test_any_villager_scene_needs_a_real_villager() -> void:
	var c := CharacterData.new()
	var v := _villager("qingshi_village")
	assert_true(Folk.is_villager(v, data(), "qingshi_village"))
	assert_false(Folk.is_villager(v, data(), "misty_forest"), "another region")
	var sect_member := _villager("qingshi_village")
	sect_member.sect = {"id": "x", "rank": 0, "contribution": 0}
	assert_false(Folk.is_villager(sect_member, data(), "qingshi_village"))
	var elder := CharacterData.new()
	elder.id = "elder_mo"
	elder.home_region = "qingshi_village"
	assert_false(Folk.is_villager(elder, data(), "qingshi_village"))
	assert_true(Folk.scene_due(c, data(), "elder_mo", 90, elder, "qingshi_village").is_empty())
	assert_true(Folk.scene_due(c, data(), v.id, 90, v, "misty_forest").is_empty())


func test_scene_posts_in_people_category() -> void:
	var c := _start()
	var gs := _root().get_node("GameState")
	var v := _villager("qingshi_village", gs)
	gs.npc_favor[v.id] = 45
	gs.current_region = "qingshi_village"
	var cats: Array = []
	var cb := func(_t: String, cat: String) -> void: cats.append(cat)
	EventBus.message_posted.connect(cb)
	gs._friend_scene(v.id)
	EventBus.message_posted.disconnect(cb)
	assert_true(cats.has("people"))
	assert_true(c.scenes_seen.has("villager_shared_bowl"))
