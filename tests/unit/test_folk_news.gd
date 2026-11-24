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


## RV-FOLK047: marrying a named villager queues the news for the others, not for the new spouse.
func test_wedding_news_skips_the_spouse() -> void:
	var c := _start()
	var gs := _gs()
	gs.npc_favor["elder_mo"] = 60
	gs.npc_favor["xiao_ling"] = 60
	c.spouses.append("xiao_ling")
	FolkNews.queue(c, gs.data, gs.npc_favor, "wedding")
	assert_eq(String(c.folk_news.get("elder_mo", "")), "wedding")
	assert_false(c.folk_news.has("xiao_ling"), "the spouse is not told of their own wedding")


func test_demonic_sect_uses_demonic_keys() -> void:
	var c := _start()
	var gs := _gs()
	c.sect = {"id": "blood_lotus_sect", "rank": 0, "contribution": 0, "spent": 0, "month_earned": 0, "reported": false}
	c.folk_news["xiao_ling"] = "sect_join"
	var own := FolkNews.take(c, gs.data, "xiao_ling")
	assert_true(own.contains("bad people"), "own demonic line: " + own)
	c.folk_news["elder_mo"] = "sect_join"  # own plain line beats the shared demonic one
	var mo := FolkNews.take(c, gs.data, "elder_mo")
	assert_true(mo.contains("Walls and rules") or mo.contains("Sixty years"), "own plain line: " + mo)
	var saved_own: Variant = gs.data.npcs["elder_mo"]["news_lines"]
	gs.data.npcs["elder_mo"]["news_lines"] = {}
	c.folk_news["elder_mo"] = "sect_join"
	var shared := FolkNews.take(c, gs.data, "elder_mo")
	gs.data.npcs["elder_mo"]["news_lines"] = saved_own
	assert_true(shared.contains("sits easy") or shared.contains("Some doors"), "shared demonic line: " + shared)
	assert_true(shared != "" and not shared.contains("{"), shared)
	c.folk_news["elder_mo"] = "promotion"
	assert_true(gs.data.family["folk_news"]["lines"]["promotion_demonic"].size() > 0)
	assert_true(FolkNews.take(c, gs.data, "elder_mo") != "")


func test_demonic_falls_back_to_plain_and_righteous_unchanged() -> void:
	var c := _start()
	var gs := _gs()
	var saved: Variant = gs.data.family["folk_news"]["lines"].get("sect_join_demonic")
	gs.data.family["folk_news"]["lines"].erase("sect_join_demonic")
	c.sect = {"id": "blood_lotus_sect", "rank": 0, "contribution": 0, "spent": 0, "month_earned": 0, "reported": false}
	c.folk_news["elder_mo"] = "sect_join"
	var plain := FolkNews.take(c, gs.data, "elder_mo")
	assert_true(plain.contains("Walls and rules") or plain.contains("Sixty years"), "falls back to Mo's plain line: " + plain)
	gs.data.family["folk_news"]["lines"]["sect_join_demonic"] = saved
	c.sect["id"] = "azure_cloud_sect"
	c.folk_news["xiao_ling"] = "sect_join"
	assert_false(FolkNews.take(c, gs.data, "xiao_ling").contains("bad people"))


func test_has_pending_drops_after_leaving_sect() -> void:
	var c := _start()
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0, "spent": 0, "month_earned": 0, "reported": false}
	c.folk_news["elder_mo"] = "sect_join"
	assert_true(FolkNews.has_pending(c, "elder_mo"))
	c.sect = {}
	assert_false(FolkNews.has_pending(c, "elder_mo"))
	c.folk_news["elder_mo"] = "wedding"
	assert_true(FolkNews.has_pending(c, "elder_mo"), "non-sect news stays for rogues")


## FOLK-049: a contest champion (every round won) is cheered; a loss queues nothing.
func _contest_setup(sect_id: String, foes: Array) -> CharacterData:
	var c := _start()
	var gs := _gs()
	gs.npc_favor["elder_mo"] = 60
	gs.npc_favor["xiao_ling"] = 20
	c.sect = {"id": sect_id, "rank": 0, "contribution": 0, "spent": 0, "month_earned": 0, "reported": true}
	var def: Dictionary = (gs.data.sects[sect_id] as SectDef).contest
	def["foes"] = foes
	def["rounds"] = foes.size()
	def["power_mults"] = [1.0, 1.0]
	GameClock.total_days = (int(def["month"]) - 1) * Calendar.DAYS_PER_MONTH
	return c


func test_contest_champion_queues_news() -> void:
	var gs := _gs()
	var saved: Dictionary = (gs.data.sects["azure_cloud_sect"] as SectDef).contest.duplicate(true)
	var c := _contest_setup("azure_cloud_sect", ["wild_boar", "wild_boar"])
	gs.enter_sect_contest()
	(gs.data.sects["azure_cloud_sect"] as SectDef).contest = saved
	assert_eq(String(c.folk_news.get("elder_mo", "")), "contest")
	assert_false(c.folk_news.has("xiao_ling"), "a 20-favor villager never reacts")
	var line := FolkNews.take(c, gs.data, "elder_mo", gs.npcs)
	assert_true(line != "" and not line.contains("{"), line)
	gs.end_session()


func test_contest_loss_queues_nothing() -> void:
	var gs := _gs()
	var saved: Dictionary = (gs.data.sects["azure_cloud_sect"] as SectDef).contest.duplicate(true)
	var c := _contest_setup("azure_cloud_sect", ["wild_boar", "wild_boar"])
	(gs.data.sects["azure_cloud_sect"] as SectDef).contest["power_mults"] = [1.0, 2.0]
	(gs.data.sects["azure_cloud_sect"] as SectDef).contest["foes"] = ["wild_boar", "sect_senior_tester"]
	c.realm_index = 0
	gs.enter_sect_contest()
	(gs.data.sects["azure_cloud_sect"] as SectDef).contest = saved
	assert_false(c.folk_news.has("elder_mo"), "round 2 lost: no champion")
	gs.end_session()


func test_contest_news_uses_demonic_lines() -> void:
	var c := _start()
	var gs := _gs()
	c.sect = {"id": "blood_lotus_sect", "rank": 0, "contribution": 0, "spent": 0, "month_earned": 0, "reported": true}
	var saved: Variant = gs.data.npcs["elder_mo"].get("news_lines")
	gs.data.npcs["elder_mo"].erase("news_lines")
	c.folk_news["elder_mo"] = "contest"
	var line := FolkNews.take(c, gs.data, "elder_mo")
	if saved != null:
		gs.data.npcs["elder_mo"]["news_lines"] = saved
	assert_true(line.contains("wary"), "shared demonic line: " + line)
