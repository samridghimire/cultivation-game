extends TestCase
## FOLK-027: the player's own birthday (a celebration day; age still counts at New Year).


func _gs() -> Node:
	return Engine.get_main_loop().root.get_node("GameState")


func _npc(id: String) -> CharacterData:
	var c := CharacterData.new()
	c.id = id
	c.name = id.capitalize()
	return c


func _player(day_of_year: int) -> CharacterData:
	var p := CharacterData.new()
	p.name = "Li Wei"
	p.birthday = day_of_year
	return p


func _plain_day(npc: CharacterData, year: int = 1) -> int:
	# a day of the year that is not the villager's own birthday
	var b := Folk.birthday_day(npc, data())
	return (b + 5) % Calendar.DAYS_PER_YEAR + year * Calendar.DAYS_PER_YEAR


func test_factory_rolls_a_birthday_in_range() -> void:
	var a := CharacterFactory.create("Li Wei", data(), seeded_rng(5))
	var b := CharacterFactory.create("Li Wei", data(), seeded_rng(5))
	assert_true(a.birthday >= 0 and a.birthday < Calendar.DAYS_PER_YEAR)
	assert_eq(a.birthday, b.birthday)


func test_old_save_default_is_deterministic_and_round_trips() -> void:
	var d := _player(40).to_dict()
	d.erase("birthday")
	var old := CharacterData.from_dict(d)
	old.name = "Li Wei"
	assert_eq(old.birthday, -1)
	assert_eq(Folk.player_birthday_day(old), Folk.player_birthday_day(old))
	assert_eq(CharacterData.from_dict(_player(77).to_dict()).birthday, 77)


func test_today_only_on_the_day() -> void:
	var p := _player(40)
	assert_true(Folk.player_birthday_today(p, data(), 40 + 3 * Calendar.DAYS_PER_YEAR))
	assert_false(Folk.player_birthday_today(p, data(), 41))
	assert_eq(Folk.player_birthday_text(_player(0)), "Month 1, Day 1")


func test_greeting_once_per_villager_per_year_with_tier_gate() -> void:
	var npc := _npc("villager_a")
	var day := _plain_day(npc)
	var p := _player(day % Calendar.DAYS_PER_YEAR)
	var flags := {}
	assert_eq(Folk.player_birthday_line(npc, p, data(), day, 0, flags, true), "")  # a stranger
	var line := Folk.player_birthday_line(npc, p, data(), day, 25, flags, true)
	assert_true(line != "" and not line.contains("{player}"))
	assert_eq(Folk.player_birthday_line(npc, p, data(), day, 25, flags, true), "")
	var next_year := day + Calendar.DAYS_PER_YEAR
	assert_true(Folk.player_birthday_line(npc, p, data(), next_year, 25, flags, true) != "")


func test_npcs_own_birthday_wins() -> void:
	var npc := _npc("villager_a")
	var day := Folk.birthday_day(npc, data()) + Calendar.DAYS_PER_YEAR
	var p := _player(day % Calendar.DAYS_PER_YEAR)
	assert_eq(Folk.player_birthday_line(npc, p, data(), day, 25, {}, true), "")


func test_family_gift_once_a_year_and_needs_family() -> void:
	var p := _player(10)
	var day := 10 + Calendar.DAYS_PER_YEAR
	var flags := {}
	assert_eq(Folk.player_birthday_gift(p, data(), day, flags, true), "")
	p.spouses.append("wife_1")
	assert_eq(Folk.player_birthday_gift(p, data(), day + 1, flags, true), "")
	var item := Folk.player_birthday_gift(p, data(), day, flags, true)
	assert_true(data().items.has(item))
	assert_eq(Folk.player_birthday_gift(p, data(), day, flags, true), "")
	assert_eq(Folk.player_birthday_gift(p, data(), day + Calendar.DAYS_PER_YEAR, flags, true), item)


func test_today_line() -> void:
	var p := _player(12)
	var day := 12 + Calendar.DAYS_PER_YEAR
	assert_true("Today is your birthday." in Guidance.today_lines(p, data(), {}, [], day, "qingshi_village"))
	assert_false("Today is your birthday." in Guidance.today_lines(p, data(), {}, [], day + 1, "qingshi_village"))


func test_chat_on_your_birthday_greets_once() -> void:
	var gs: Node = _gs()
	var c := CharacterFactory.create("Suitor", gs.data, seeded_rng())
	gs.start_session(c)
	var clock: Node = Engine.get_main_loop().root.get_node("GameClock")
	var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(3), {"age_years": 30, "region": "qingshi_village", "realm": "mortal"})
	gs.current_region = "qingshi_village"
	var day: int = clock.total_days
	while Folk.birthday_today(npc, gs.data, day):
		day += 1
	c.birthday = day % Calendar.DAYS_PER_YEAR
	clock.total_days = day
	gs.npc_favor[npc.id] = 22
	gs.chat(npc.id)
	assert_true(gs.world_flags.has(Folk.PLAYER_BIRTHDAY_PREFIX + npc.id), "the villager wished you well")
	assert_gt(int(gs.npc_favor[npc.id]), 22 + Folk.PLAYER_BIRTHDAY_FAVOR - 1)
	gs.end_session()


## Review: Talk with a named villager (start_dialogue) wishes you well too, not only Chat.
func test_talk_with_a_named_friend_on_your_birthday_greets() -> void:
	var gs: Node = _gs()
	var c := CharacterFactory.create("Talker", gs.data, seeded_rng())
	gs.start_session(c)
	var clock: Node = Engine.get_main_loop().root.get_node("GameClock")
	gs.current_region = "qingshi_village"
	var day := _plain_day(gs.npcs["elder_mo"])
	c.birthday = day % Calendar.DAYS_PER_YEAR
	clock.total_days = day
	gs.npc_favor["elder_mo"] = 22
	gs.start_dialogue("elder_mo")
	assert_true(gs.world_flags.has(Folk.PLAYER_BIRTHDAY_PREFIX + "elder_mo"), "Elder Mo wished you well")
	assert_eq(int(gs.npc_favor["elder_mo"]), 22 + Folk.PLAYER_BIRTHDAY_FAVOR)
	gs.end_session()


## FOLK-028: a birthday at home.
func _home_session(name: String) -> Dictionary:
	var gs: Node = _gs()
	var c := CharacterFactory.create(name, gs.data, seeded_rng())
	gs.start_session(c)
	var clock: Node = Engine.get_main_loop().root.get_node("GameClock")
	return {"gs": gs, "c": c, "clock": clock}


func test_home_lines_are_validated_and_filled() -> void:
	assert_true(data().family.get("birthday_home_lines", []).size() >= 4)
	var line := Folk.birthday_home_line(data(), "Mei", "Herb Porridge", 3)
	assert_true(line.contains("Mei") or line.contains("Herb Porridge"))
	assert_false(line.contains("{"))
	var d := data()
	var saved: Variant = d.family.get("birthday_home_lines", [])
	d.family["birthday_home_lines"] = [""]
	assert_false(Folk.validate_greetings(d).is_empty())
	d.family["birthday_home_lines"] = saved
	assert_true(Folk.validate_greetings(d).is_empty())


func test_dish_at_home_once_a_year_and_not_on_another_day() -> void:
	var s := _home_session("Homebody")
	var gs: Node = s["gs"]
	var c: CharacterData = s["c"]
	var wife := Npcs.spawn(gs.npcs, gs.data, seeded_rng(4), {"age_years": 25, "region": "qingshi_village", "realm": "mortal"})
	c.spouses.append(wife.id)
	gs.current_region = "qingshi_village"
	var day := 50 + Calendar.DAYS_PER_YEAR
	c.birthday = day % Calendar.DAYS_PER_YEAR
	var dish := String(gs.data.family["player_birthday_gift"])
	s["clock"].total_days = day + 1
	gs.birthday_at_home()
	assert_eq(c.item_count(dish), 0, "not on another day")
	s["clock"].total_days = day
	gs.birthday_at_home()
	assert_eq(c.item_count(dish), 1)
	gs.birthday_at_home()
	assert_eq(c.item_count(dish), 1, "once a year")
	assert_eq(Folk.player_birthday_gift(c, gs.data, day, gs.world_flags, true), "", "the chat path shares the flag")
	gs.end_session()


func test_no_dish_away_from_home() -> void:
	var s := _home_session("Away")
	var gs: Node = s["gs"]
	var c: CharacterData = s["c"]
	var wife := Npcs.spawn(gs.npcs, gs.data, seeded_rng(4), {"age_years": 25, "region": "qingshi_village", "realm": "mortal"})
	c.spouses.append(wife.id)
	gs.current_region = "withered_bone_marsh"
	var day := 50 + Calendar.DAYS_PER_YEAR
	c.birthday = day % Calendar.DAYS_PER_YEAR
	s["clock"].total_days = day
	gs.birthday_at_home()
	assert_eq(c.item_count(String(gs.data.family["player_birthday_gift"])), 0)
	gs.end_session()


func test_friend_gift_needs_two_close_friends_and_no_family() -> void:
	var s := _home_session("Lonely")
	var gs: Node = s["gs"]
	var c: CharacterData = s["c"]
	var day := 50 + Calendar.DAYS_PER_YEAR
	c.birthday = day % Calendar.DAYS_PER_YEAR
	s["clock"].total_days = day
	gs.npc_favor["elder_mo"] = 70
	assert_true(Folk.birthday_friend_gift(c, gs.npcs, gs.npc_favor, gs.data, day, {}, false).is_empty(), "one friend is not enough")
	gs.npc_favor["xiao_ling"] = 65
	var flags := {}
	var gift := Folk.birthday_friend_gift(c, gs.npcs, gs.npc_favor, gs.data, day, flags, true)
	assert_false(gift.is_empty())
	assert_true(gs.data.items.has(gift["item"]))
	assert_true(Folk.birthday_friend_gift(c, gs.npcs, gs.npc_favor, gs.data, day, flags, true).is_empty(), "once a year")
	assert_true(Folk.birthday_friend_gift(c, gs.npcs, gs.npc_favor, gs.data, day + 1, {}, true).is_empty(), "only on the day")
	gs.birthday_at_home()
	assert_eq(c.item_count(String(gift["item"])), 1)
	c.spouses.append("someone")
	assert_true(Folk.birthday_friend_gift(c, gs.npcs, gs.npc_favor, gs.data, day, {}, false).is_empty(), "family takes the dish path")
	gs.end_session()


## FOLK-029: a villager's own player_birthday_line wins; others use the shared pool; validation caps it.
func test_own_birthday_line_and_fallback() -> void:
	var npc := _npc("hunter_ma")
	npc.name = "Hunter Ma"
	var day := _plain_day(npc)
	var p := _player(day % Calendar.DAYS_PER_YEAR)
	p.name = "Lin"
	var own := String(data().npcs["hunter_ma"]["player_birthday_line"])
	assert_eq(Folk.player_birthday_line(npc, p, data(), day, 25, {}, true), own.replace("{player}", "Lin"))
	var plain := _npc("villager_a")
	var pool: Array = data().family["folk_greetings"]["player_birthday"]
	var got := Folk.player_birthday_line(plain, p, data(), _plain_day(plain), 25, {}, true)
	assert_true(got == "" or pool.any(func(t: String) -> bool: return t.replace("{player}", "Lin") == got))
	var p2 := _player(_plain_day(plain) % Calendar.DAYS_PER_YEAR)
	p2.name = "Lin"
	var got2 := Folk.player_birthday_line(plain, p2, data(), _plain_day(plain), 25, {}, true)
	assert_true(pool.any(func(t: String) -> bool: return t.replace("{player}", "Lin") == got2), "fallback to the shared pool")


func test_own_birthday_line_validation() -> void:
	var d := data()
	for id in ["elder_mo", "xiao_ling", "hunter_ma"]:
		assert_true(String(d.npcs[id].get("player_birthday_line", "")) != "", id)
	var saved: Variant = d.npcs["hunter_ma"].get("player_birthday_line")
	d.npcs["hunter_ma"]["player_birthday_line"] = "x".repeat(161)
	d.load_errors.clear()
	d._validate()
	var found := false
	for e in d.load_errors:
		found = found or "player_birthday_line" in e
	d.npcs["hunter_ma"]["player_birthday_line"] = saved
	d.load_errors.clear()
	assert_true(found, "161 chars rejected")


## FOLK-030: a villager's birthday gift rides their own line, once a year.
func test_villager_gift_helper_and_validation() -> void:
	var d := data()
	assert_eq(Folk.player_birthday_gift_of("hunter_ma", d), {"item": "venison", "count": 2})
	assert_true(Folk.player_birthday_gift_of("elder_mo", d).is_empty())
	assert_true(Folk.validate_player_birthday_gifts(d).is_empty())
	var saved: Variant = d.npcs["hunter_ma"]["player_birthday_gift"]
	for bad: Dictionary in [{"item": "nope", "count": 1}, {"item": "venison", "count": 0}, {"item": "venison", "count": 4}]:
		d.npcs["hunter_ma"]["player_birthday_gift"] = bad
		assert_false(Folk.validate_player_birthday_gifts(d).is_empty(), str(bad))
	d.npcs["hunter_ma"]["player_birthday_gift"] = saved


func test_villager_gift_in_game() -> void:
	var gs := _gs()
	gs.start_session(CharacterFactory.create("Li Wei", gs.data, seeded_rng(3)))
	var npc: CharacterData = gs.npcs["hunter_ma"]
	var day := _plain_day(npc)
	gs.player.birthday = day % Calendar.DAYS_PER_YEAR
	Engine.get_main_loop().root.get_node("GameClock").total_days = day
	gs.npc_favor["hunter_ma"] = 25
	var before: int = gs.player.item_count("venison")
	assert_true(gs._player_birthday_words("hunter_ma"))
	assert_eq(gs.player.item_count("venison"), before + 2)
	gs._player_birthday_words("hunter_ma")
	assert_eq(gs.player.item_count("venison"), before + 2, "not twice the same year")
	Engine.get_main_loop().root.get_node("GameClock").total_days = day + Calendar.DAYS_PER_YEAR
	gs._player_birthday_words("hunter_ma")
	assert_eq(gs.player.item_count("venison"), before + 4, "again next year")
	gs.npc_favor["elder_mo"] = -50
	var mo: int = gs.player.item_count("venison")
	gs._player_birthday_words("elder_mo")
	assert_eq(gs.player.item_count("venison"), mo, "stranger gives nothing")
	gs.end_session()


## CAL-009: the calendar lists your own and your living family's birthdays; family chat on their day gives favor once a year.
func _family(kids: int = 1) -> Dictionary:
	var npcs := {}
	var p := _player(100)
	var out := {"npcs": npcs, "player": p, "ids": []}
	for i in kids:
		var n := Npcs.spawn(npcs, data(), seeded_rng(30 + i), {"age_years": 8, "region": "qingshi_village", "realm": "mortal"})
		p.children.append(n.id)
		out["ids"].append(n.id)
	return out


func test_calendar_lists_player_and_family_birthdays() -> void:
	var f := _family()
	var p: CharacterData = f["player"]
	var npcs: Dictionary = f["npcs"]
	var kid: CharacterData = npcs[f["ids"][0]]
	var e := VillageCalendar.upcoming(data(), npcs, {}, [], "misty_forest", 0, Calendar.DAYS_PER_YEAR, p, {})
	var texts: Array = e.filter(func(x: Dictionary) -> bool: return x["kind"] == "birthday").map(func(x: Dictionary) -> String: return String(x["text"]))
	assert_true(texts.has("Your birthday"))
	assert_true(texts.has("%s's birthday" % kid.name), "child listed with no favor, in another region")
	var own: Dictionary = e.filter(func(x: Dictionary) -> bool: return x["text"] == "Your birthday")[0]
	assert_eq(int(own["day"]) % Calendar.DAYS_PER_YEAR, 100)


func test_dead_family_never_listed() -> void:
	var f := _family()
	var npcs: Dictionary = f["npcs"]
	var kid: CharacterData = npcs[f["ids"][0]]
	kid.alive = false
	var e := VillageCalendar.upcoming(data(), npcs, {}, [], "misty_forest", 0, Calendar.DAYS_PER_YEAR, f["player"], {})
	assert_false(e.any(func(x: Dictionary) -> bool: return x.get("npc_id", "") == kid.id))


func test_family_birthday_line_once_a_year() -> void:
	var f := _family()
	var p: CharacterData = f["player"]
	var kid: CharacterData = f["npcs"][f["ids"][0]]
	var day := Folk.birthday_day(kid, data()) + Calendar.DAYS_PER_YEAR
	var flags := {}
	assert_true(Folk.family_birthday_line(kid, p, data(), day, flags, true) != "")
	assert_eq(Folk.family_birthday_line(kid, p, data(), day, flags, true), "", "once")
	assert_true(Folk.family_birthday_line(kid, p, data(), day + Calendar.DAYS_PER_YEAR, flags, true) != "", "next year again")
	assert_eq(Folk.family_birthday_line(kid, p, data(), day + 1 + 2 * Calendar.DAYS_PER_YEAR, {}, true), "", "not their day")


func test_chat_with_child_on_their_birthday_gives_favor() -> void:
	var gs: Node = _gs()
	var c := CharacterFactory.create("Parent", gs.data, seeded_rng())
	gs.start_session(c)
	var clock: Node = Engine.get_main_loop().root.get_node("GameClock")
	var kid := Npcs.spawn(gs.npcs, gs.data, seeded_rng(4), {"age_years": 8, "region": "qingshi_village", "realm": "mortal"})
	c.children.append(kid.id)
	gs.current_region = "qingshi_village"
	var day: int = Folk.birthday_day(kid, gs.data) + 5 * Calendar.DAYS_PER_YEAR
	c.birthday = (day + 7) % Calendar.DAYS_PER_YEAR
	clock.total_days = day
	gs.npc_favor[kid.id] = 22
	gs.chat(kid.id)
	assert_true(gs.world_flags.has(Folk.FAMILY_BIRTHDAY_PREFIX + kid.id))
	assert_gt(int(gs.npc_favor[kid.id]), 22 + Folk.FAMILY_BIRTHDAY_FAVOR - 1)
	gs.end_session()

