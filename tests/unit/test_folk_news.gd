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


func test_qingshi_friends_have_own_voices() -> void:
	var data: GameData = _gs().data
	var first_lines: Array = []
	for id: String in ["elder_mo", "xiao_ling", "hunter_ma"]:
		var nl: Dictionary = data.npcs[id].get("news_lines", {})
		assert_true((nl.get("sect_join", []) as Array).size() >= 2, id + " sect_join lines")
		assert_true((nl.get("promotion", []) as Array).size() >= 1, id + " promotion line")
		first_lines.append(String(nl["sect_join"][0]))
	assert_eq(first_lines.size(), 3)
	assert_true(first_lines[0] != first_lines[1] and first_lines[1] != first_lines[2], "each villager sounds different")


## RV-FOLK046: in play a named villager's reaction arrives when you speak with them (_greet_renowned), not the bubble greeting.
func test_chat_delivers_the_reaction() -> void:
	var c := _start()
	var gs := _gs()
	gs.npc_favor["elder_mo"] = 60
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0, "spent": 0, "month_earned": 0, "reported": false}
	EventBus.sect_joined.emit("azure_cloud_sect")
	assert_true(c.folk_news.has("elder_mo"))
	gs.start_dialogue("elder_mo")
	gs.end_dialogue()
	assert_false(c.folk_news.has("elder_mo"), "talking used the reaction")


## RV-FOLK046: news of a sect you have since left is dropped, never "joined the ." with an empty name.
func test_stale_news_after_leaving_is_dropped() -> void:
	var c := _start()
	var gs := _gs()
	c.sect = {}
	c.folk_news["elder_mo"] = "sect_join"
	assert_eq(FolkNews.take(c, gs.data, "elder_mo"), "")
	assert_false(c.folk_news.has("elder_mo"))


func test_breakthrough_news_major_realm_only() -> void:
	var c := _start()
	var gs := _gs()
	gs.npc_favor["elder_mo"] = 60
	c.realm_index = 2
	FolkNews.queue(c, gs.data, gs.npc_favor, "breakthrough")
	assert_eq(String(c.folk_news.get("elder_mo", "")), "breakthrough")
	var line := FolkNews.take(c, gs.data, "elder_mo", gs.npcs)
	assert_true(line != "", "a rogue still hears breakthrough news")
	assert_true(line.find("Foundation Establishment") >= 0 and line.find("{") < 0, line)


func test_wedding_news_uses_spouse_name_and_replaces_older_kind() -> void:
	var c := _start()
	var gs := _gs()
	gs.npc_favor["elder_mo"] = 60
	var mate := CharacterFactory.create("Lian Hua", gs.data, seeded_rng(5))
	gs.npcs[mate.id] = mate
	c.spouses.append(mate.id)
	c.folk_news["elder_mo"] = "breakthrough"
	FolkNews.queue(c, gs.data, gs.npc_favor, "wedding")
	assert_eq(String(c.folk_news["elder_mo"]), "wedding", "newer kind replaces an unheard older one")
	var line := FolkNews.take(c, gs.data, "elder_mo", gs.npcs)
	assert_true(line.find("Lian Hua") >= 0 and line.find("{") < 0, line)


func test_stale_sect_news_still_dropped_for_rogue() -> void:
	var c := _start()
	var gs := _gs()
	c.folk_news["elder_mo"] = "promotion"
	assert_eq(FolkNews.take(c, gs.data, "elder_mo", gs.npcs), "")


func test_propose_queues_wedding_news() -> void:
	var gs := _gs()
	var c := _start()
	c.gender = "male"
	c.alignment = 0
	gs.npc_favor["elder_mo"] = 60
	var mate := CharacterFactory.create("Lian Hua", gs.data, seeded_rng(6))
	mate.gender = "female"
	mate.realm_index = c.realm_index
	mate.age_days = 20 * Calendar.DAYS_PER_YEAR
	gs.npcs[mate.id] = mate
	gs.npc_favor[mate.id] = 100
	gs.propose(mate.id, "wife")
	if c.spouses.has(mate.id):
		assert_eq(String(c.folk_news.get("elder_mo", "")), "wedding")
	else:
		assert_false(c.folk_news.has("elder_mo"), "no marriage, no news")
