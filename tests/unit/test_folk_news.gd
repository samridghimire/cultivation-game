extends TestCase
## FOLK-046: friends hear your sect news (a one-time reaction, favor >= 40, stable lines, save round-trip).


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _start() -> CharacterData:
	var gs := _gs()
	var c := CharacterFactory.create("Newsy", gs.data, seeded_rng(77))
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	c.home_region = "qingshi_village"
	gs.current_region = "qingshi_village"
	return c


func test_friend_reacts_once_after_join() -> void:
	var c := _start()
	var gs := _gs()
	gs.npc_favor["elder_mo"] = 60
	gs.npc_favor["xiao_ling"] = 20
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0, "spent": 0, "month_earned": 0, "reported": false}
	EventBus.sect_joined.emit("azure_cloud_sect")
	assert_true(c.folk_news.has("elder_mo"))
	assert_false(c.folk_news.has("xiao_ling"), "a 20-favor villager never reacts")
	var line: String = gs.greeting_for("elder_mo")
	assert_true(line.contains("Azure") or line.contains("Newsy") or line != "", "reaction line")
	assert_false(line.contains("{"), "tokens filled: " + line)
	assert_false(c.folk_news.has("elder_mo"), "cleared after use")
	assert_false(FolkNews.take(c, gs.data, "elder_mo") != "", "not again")


func test_promotion_queues_and_fills_rank() -> void:
	var c := _start()
	var gs := _gs()
	gs.npc_favor["elder_mo"] = 50
	c.sect = {"id": "azure_cloud_sect", "rank": 1, "contribution": 0, "spent": 0, "month_earned": 0, "reported": true}
	EventBus.sect_promoted.emit("azure_cloud_sect", 1)
	assert_eq(String(c.folk_news.get("elder_mo", "")), "promotion")
	var line := FolkNews.take(c, gs.data, "elder_mo")
	assert_true(line != "" and not line.contains("{"), line)


func test_line_is_stable_and_rng_free() -> void:
	var c := _start()
	var gs := _gs()
	c.folk_news["elder_mo"] = "sect_join"
	var a := FolkNews.take(c, gs.data, "elder_mo")
	c.folk_news["elder_mo"] = "sect_join"
	var b := FolkNews.take(c, gs.data, "elder_mo")
	assert_eq(a, b)


func test_save_round_trip() -> void:
	var c := _start()
	c.folk_news["elder_mo"] = "promotion"
	var d := CharacterData.from_dict(c.to_dict())
	assert_eq(d.folk_news, {"elder_mo": "promotion"})
	var old := c.to_dict()
	old.erase("folk_news")
	assert_eq(CharacterData.from_dict(old).folk_news, {})
