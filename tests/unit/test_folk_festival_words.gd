extends TestCase
## FOLK-025: villagers say a festival line when you chat during a festival in their region, once per festival per year.

const FEST := "dragon_boat_festival"


func _events(day: int, region: String = "qingshi_village") -> Array:
	return [{"id": FEST, "region": region, "start_day": day, "end_day": day + 6}]


func _gs() -> Node:
	return Engine.get_main_loop().root.get_node("GameState")


func _npc(id: String) -> CharacterData:
	var c := CharacterData.new()
	c.id = id
	c.name = id.capitalize()
	return c


func _non_birthday_day() -> int:
	var d := data()
	var day := 5 * Calendar.DAYS_PER_MONTH + 3  # month 6: no named birthday
	while Folk.birthday_today(_npc("elder_mo"), d, day) or Folk.birthday_today(_npc("xiao_ling"), d, day):
		day += 1
	return day


func test_named_villager_uses_their_own_line() -> void:
	var day := _non_birthday_day()
	var said := Folk.festival_line(_npc("elder_mo"), data(), _events(day), "qingshi_village", day, {})
	assert_eq(said["event"], FEST)
	assert_eq(said["line"], data().npcs["elder_mo"]["festival_lines"][FEST])


func test_no_line_outside_a_festival_or_region() -> void:
	var day := _non_birthday_day()
	assert_true(Folk.festival_line(_npc("elder_mo"), data(), [], "qingshi_village", day, {}).is_empty())
	assert_true(Folk.festival_line(_npc("elder_mo"), data(), _events(day, "elsewhere"), "qingshi_village", day, {}).is_empty())


func test_generated_villager_gets_shared_pool_with_name_filled() -> void:
	var day := _non_birthday_day()
	var npc := _npc("gen_villager_zz")
	var said := Folk.festival_line(npc, data(), _events(day), "qingshi_village", day, {})
	assert_false(said.is_empty())
	assert_false(String(said["line"]).contains("{name}"))
	assert_false(String(said["line"]).contains("{festival}"))


func test_told_once_per_festival_per_year() -> void:
	var day := _non_birthday_day()
	var flags := {}
	var npc := _npc("elder_mo")
	Folk.mark_festival_told(flags, npc.id, FEST, day)
	assert_true(Folk.festival_line(npc, data(), _events(day), "qingshi_village", day + 1, flags).is_empty())
	var next_year := day + Calendar.DAYS_PER_YEAR
	assert_false(Folk.festival_line(npc, data(), _events(next_year), "qingshi_village", next_year, flags).is_empty())


func test_birthday_wins() -> void:
	var d := data()
	var npc := _npc("elder_mo")
	var bday := Folk.birthday_day(npc, d)
	assert_true(Folk.festival_line(npc, d, _events(bday), "qingshi_village", bday, {}).is_empty())


func test_validation_rejects_bad_festival_lines() -> void:
	var d := data()
	assert_true(Folk.validate_festival_lines(d).is_empty())
	var saved: Variant = d.npcs["elder_mo"].get("festival_lines")
	d.npcs["elder_mo"]["festival_lines"] = {"market_day_nonsense": "hi"}
	assert_false(Folk.validate_festival_lines(d).is_empty(), "not a festival event id")
	d.npcs["elder_mo"]["festival_lines"] = {FEST: "x".repeat(161)}
	assert_false(Folk.validate_festival_lines(d).is_empty(), "over-long line")
	d.npcs["elder_mo"]["festival_lines"] = saved


func test_dialogue_posts_the_line_once() -> void:
	var gs := _gs()
	var c := CharacterFactory.create("Fest", gs.data, seeded_rng(11))
	gs.start_session(c)
	var day := _non_birthday_day()
	GameClock.total_days = day
	gs.world_events = _events(day)
	gs.current_region = "qingshi_village"
	var posts: Array = []
	var sink := func(text: String, _cat: String = "") -> void: posts.append(text)
	EventBus.message_posted.connect(sink)
	gs.start_dialogue("elder_mo")
	var line := String(gs.data.npcs["elder_mo"]["festival_lines"][FEST]).replace("{player}", c.name)
	assert_true(posts.any(func(p: String) -> bool: return p.contains(line)), "festival line posted: %s" % str(posts))
	posts.clear()
	GameClock.total_days = day + 1
	gs.start_dialogue("elder_mo")
	assert_false(posts.any(func(p: String) -> bool: return p.contains(line)), "not told twice")
	EventBus.message_posted.disconnect(sink)


## C-328: every named villager with a region has their own line for each festival held there, none repeating a birthday line.
func test_named_villagers_have_a_line_for_every_festival_in_their_region() -> void:
	var d := data()
	var birthday_lines := {}
	for id: String in d.npcs:
		birthday_lines[String(d.npcs[id].get("birthday_line", ""))] = true
	for b: String in d.family["folk_greetings"].get("birthday", []):
		birthday_lines[b] = true
	var checked := 0
	for id: String in d.npcs:
		var region := String(d.npcs[id].get("region", ""))
		if region == "":
			continue
		for fid: String in d.world_events:
			if not WorldEvents.is_festival(d, fid) or not (d.world_events[fid].get("regions", []) as Array).has(region):
				continue
			var own: Dictionary = d.npcs[id].get("festival_lines", {})
			assert_true(own.has(fid), "%s has a %s line" % [id, fid])
			assert_false(birthday_lines.has(String(own.get(fid, "x"))), "%s: %s is not a birthday line" % [id, fid])
			checked += 1
	assert_true(checked >= 10, "checked %d villager-festival pairs" % checked)
	assert_true((d.family["folk_greetings"]["festival"] as Array).size() >= 8, "shared festival pool")
