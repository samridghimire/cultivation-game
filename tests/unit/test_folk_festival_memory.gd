extends TestCase
## FOLK-026: the friend you went to a festival with recalls it on their first chat within 10 days (+2 favor, once).

const LANTERN_START := 270  # day 1 of month 10, year 1


func _root() -> Node:
	return Engine.get_main_loop().root


func _npc(id: String) -> CharacterData:
	var c := CharacterData.new()
	c.id = id
	c.name = id.capitalize()
	return c


func test_line_is_due_for_ten_days_and_told_once() -> void:
	var d := data()
	var flags := {}
	var npc := _npc("n1")
	assert_eq(Folk.festival_memory_line(npc, d, flags, 100, true), "", "nothing remembered yet")
	Folk.note_festival_company(flags, "n1", "lantern_festival", 100)
	assert_eq(Folk.festival_memory_line(npc, d, flags, 111, true), "", "after 10 days it fades")
	var line := Folk.festival_memory_line(npc, d, flags, 110, false)
	assert_true(line.contains("N1") or line.contains("Lantern"), "filled: " + line)
	assert_eq(Folk.festival_memory_line(npc, d, flags, 110, true), line, "peek did not consume")
	assert_eq(Folk.festival_memory_line(npc, d, flags, 110, true), "", "told once")


func test_validation() -> void:
	var d := data()
	assert_true(Folk.validate_festival_memory(d).is_empty())
	d.npcs["elder_mo"]["festival_memory_line"] = "x".repeat(161)
	assert_false(Folk.validate_festival_memory(d).is_empty())
	d.npcs["elder_mo"].erase("festival_memory_line")
	d.family["folk_greetings"]["festival_memory"] = [""]
	assert_false(Folk.validate_festival_memory(d).is_empty())


func test_attended_with_friend_then_chat_once() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	gs.current_region = "qingshi_village"
	var friend: CharacterData = Folk.candidates(gs.npcs, gs.data, gs.player, "qingshi_village")[0]
	gs.npc_favor[friend.id] = 80
	GameClock.total_days = LANTERN_START
	gs.world_events = [{"id": "lantern_festival", "region": "qingshi_village", "start_day": LANTERN_START, "end_day": LANTERN_START + 8}]
	gs.festival_contest("lantern_festival")
	assert_true(gs.world_flags["festival_memory"].has(friend.id), "company remembered")
	var before := int(gs.npc_favor[friend.id])
	var posts: Array = []
	var sink := func(text: String, _cat: String = "") -> void: posts.append(text)
	EventBus.message_posted.connect(sink)
	gs._named_remembers(friend.id)
	assert_true(posts.any(func(p: String) -> bool: return p.contains("Lantern")), "line posted: %s" % str(posts))
	assert_eq(int(gs.npc_favor[friend.id]), before + 2)
	posts.clear()
	gs._named_remembers(friend.id)
	assert_eq(int(gs.npc_favor[friend.id]), before + 2, "favor once")
	EventBus.message_posted.disconnect(sink)
	gs.end_session()


func test_not_attended_says_nothing() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	gs.current_region = "qingshi_village"
	var friend: CharacterData = Folk.candidates(gs.npcs, gs.data, gs.player, "qingshi_village")[0]
	gs.npc_favor[friend.id] = 30
	GameClock.total_days = LANTERN_START
	gs.world_events = [{"id": "lantern_festival", "region": "qingshi_village", "start_day": LANTERN_START, "end_day": LANTERN_START + 8}]
	gs.festival_contest("lantern_festival")
	assert_false(gs.world_flags.get("festival_memory", {}).has(friend.id))
	var before := int(gs.npc_favor[friend.id])
	gs._named_remembers(friend.id)
	assert_eq(int(gs.npc_favor[friend.id]), before)
	gs.end_session()
