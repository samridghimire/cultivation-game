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
